const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3');
const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');
const { Client } = require('@opensearch-project/opensearch');
const { NodeHttpHandler } = require('@aws-sdk/node-http-handler');
const zlib = require('zlib');

// Export index mappings for local development setup
exports.indexMappings = {
    'access-logs': {
        mappings: {
            properties: {
                timestamp: { type: 'date' },
                version: { type: 'keyword' },
                ip: { type: 'ip' },
                domain: { type: 'keyword' },
                status: { type: 'integer' },
                bytes: { type: 'long' },
                server: { type: 'keyword' },
                response_time: { type: 'float' },
                total_time: { type: 'float' },
                request: { type: 'text' },
                type: { type: 'keyword' }
            }
        }
    },
    'error-logs': {
        mappings: {
            properties: {
                timestamp: { type: 'date' },
                message: { type: 'text' },
                repeat_count: { type: 'integer' },
                type: { type: 'keyword' }
            }
        }
    },
    'apache-access-logs': {
        mappings: {
            properties: {
                timestamp: { type: 'date' },
                ip: { type: 'ip' },
                request: { type: 'text' },
                status: { type: 'integer' },
                bytes: { type: 'long' },
                referer: { type: 'keyword' },
                user_agent: { type: 'keyword' },
                type: { type: 'keyword' }
            }
        }
    }
};

// Initialize clients with LocalStack support
function createClients() {
    const s3Client = new S3Client({
        ...(process.env.AWS_ENDPOINT_URL ? {
            endpoint: process.env.AWS_ENDPOINT_URL,
            region: process.env.AWS_REGION || 'us-west-2',
            credentials: {
                accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
                secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test'
            },
            forcePathStyle: true,
            tls: false,
            requestHandler: new NodeHttpHandler({
                connectionTimeout: 5000,
                socketTimeout: 5000
            })
        } : {})
    });

    const snsClient = new SNSClient({
        ...(process.env.AWS_ENDPOINT_URL ? {
            endpoint: process.env.AWS_ENDPOINT_URL,
            region: process.env.AWS_REGION || 'us-west-2',
            credentials: {
                accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
                secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test'
            },
            forcePathStyle: true,
            tls: false,
            requestHandler: new NodeHttpHandler({
                connectionTimeout: 5000,
                socketTimeout: 5000
            })
        } : {})
    });

    const opensearchClient = new Client({
        node: process.env.OPENSEARCH_ENDPOINT?.startsWith('localhost') 
            ? `http://${process.env.OPENSEARCH_ENDPOINT}`
            : `https://${process.env.OPENSEARCH_ENDPOINT}`,
        auth: {
            username: 'admin',
            password: process.env.OPENSEARCH_PASSWORD
        },
        ssl: {
            rejectUnauthorized: !process.env.OPENSEARCH_ENDPOINT?.startsWith('localhost')
        }
    });

    return { s3Client, snsClient, opensearchClient };
}

// Initialize clients after environment variables are loaded
const { s3Client, snsClient, opensearchClient } = createClients();

// Export clients for local development
exports.s3Client = s3Client;
exports.snsClient = snsClient;
exports.opensearchClient = opensearchClient;

// Ensure index exists with mapping
const ensureIndex = async (indexName) => {
    try {
        // Check if index exists
        console.log(`Checking for index ${indexName}`);
        const exists = await opensearchClient.indices.exists({ index: indexName });
        console.log(`Index ${indexName} exists: ${exists.body}`);
        if (!exists.body) {
            console.log(`Creating index ${indexName} with mapping`);
            await opensearchClient.indices.create({
                index: indexName,
                body: exports.indexMappings[indexName]
            });
            console.log(`Successfully created index ${indexName}`);
        }
    } catch (error) {
        console.error(`Error ensuring index ${indexName}:`, error);
        throw error;
    }
};

// Parse error log line
const parseErrorLog = (line) => {
    try {
        // Updated regex to handle ISO8601 timestamps with timezone
        const match = line.match(/\[([0-9T:.+-]+)\] (.+)/);
        if (!match) return null;

        const [, timestamp, message] = match;
        // Parse the ISO8601 timestamp
        const date = new Date(timestamp);
        if (isNaN(date.getTime())) return null;

        const repeatedMatch = message.match(/message repeated (\d+) times: \[(.*)\]/);

        if (repeatedMatch) {
            const [, count, repeatedMessage] = repeatedMatch;
            return {
                timestamp: date.toISOString(),
                message: repeatedMessage.trim(),
                repeat_count: parseInt(count, 10),
                type: 'error'
            };
        }

        return {
            timestamp: date.toISOString(),
            message: message.trim(),
            repeat_count: 1,
            type: 'error'
        };
    } catch (error) {
        return null;
    }
};

// Parse date in format "DD/MMM/YYYY:HH:mm:ss +ZZZZ"
const parseLogDate = (dateStr) => {
    // Extract components from the date string
    const match = dateStr.match(/(\d{2})\/(\w{3})\/(\d{4}):(\d{2}:\d{2}:\d{2})/);
    if (!match) return null;

    const [, day, month, year, time] = match;
    const months = {
        Jan: '01', Feb: '02', Mar: '03', Apr: '04', May: '05', Jun: '06',
        Jul: '07', Aug: '08', Sep: '09', Oct: '10', Nov: '11', Dec: '12'
    };

    // Construct ISO date string
    return `${year}-${months[month]}-${day}T${time}.000Z`;
};

// Parse Apache-style access log line
const parseApacheStyleLog = (line) => {
    // Example Apache format: %h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"
    const match = line.match(/^(\S+) \S+ \S+ \[([^\]]+)\] "([^"]*)" (\d+) (\d+|-) "([^"]*)" "([^"]*)"$/);
    if (!match) return null;

    const [, ip, timestamp, request, status, bytes, referer, userAgent] = match;
    const isoTimestamp = parseLogDate(timestamp);
    if (!isoTimestamp) return null;

    return {
        timestamp: isoTimestamp,
        ip,
        request,
        status: parseInt(status, 10),
        bytes: bytes === '-' ? 0 : parseInt(bytes, 10),
        referer,
        user_agent: userAgent,
        type: 'apache_access'
    };
};

// Parse standard access log line
const parseAccessLog = (line) => {
    const parts = line.split('|');
    if (parts.length < 10) return null;

    const timestamp = parseLogDate(parts[0]);
    if (!timestamp) return null;

    return {
        timestamp,
        version: parts[1],
        ip: parts[2],
        domain: parts[3],
        status: parseInt(parts[4], 10),
        bytes: parseInt(parts[5], 10),
        server: parts[6],
        response_time: parseFloat(parts[7]),
        total_time: parseFloat(parts[8]),
        request: parts[9],
        type: 'access'
    };
};

// Helper functions for log processing
exports.processLogLine = (line, type) => {
    if (type === 'error') {
        return parseErrorLog(line);
    } else if (type === 'apache') {
        return parseApacheStyleLog(line);
    } else {
        return parseAccessLog(line);
    }
};

exports.formatLogForVerification = (entry, type) => {
    if (type === 'error') {
        return entry.message;
    } else if (type === 'apache') {
        const [method, path] = entry.request.split(' ');
        return `${entry.user_agent.replace(/"/g, '')} ${method} ${path}`;
    } else {
        // For standard access logs, include the full request to match verify script's grep pattern
        return `${entry.domain} ${entry.request}`;
    }
};

// Export for local development
exports.isCriticalError = (message) => {
    const criticalPatterns = JSON.parse(process.env.ERROR_PATTERNS || '[]');
    return criticalPatterns.some(pattern => 
        message.toLowerCase().includes(pattern.toLowerCase())
    );
};

// Send alert
const sendAlert = async (message, severity = 'INFO') => {
    const command = new PublishCommand({
        Message: JSON.stringify({
            severity,
            message,
            timestamp: new Date().toISOString()
        }),
        TopicArn: process.env.SNS_TOPIC_ARN
    });

    await snsClient.send(command);
};

// Index log entry in OpenSearch
const indexLog = async (entry, index) => {
    console.log(`Attempting to index entry to ${index}:`, JSON.stringify(entry, null, 2));
    try {
        const response = await opensearchClient.index({
            index,
            body: entry
        });
        console.log(`Successfully indexed to ${index}. Response:`, JSON.stringify(response, null, 2));
    } catch (error) {
        console.error(`Failed to index to ${index}:`, error);
        console.error('Entry that failed:', JSON.stringify(entry, null, 2));
        console.error('OpenSearch endpoint:', process.env.OPENSEARCH_ENDPOINT);
        throw error; // Re-throw to handle in main handler
    }
};

// Main handler
exports.handler = async (event) => {
    try {
        // Get the S3 object
        const s3Record = event.Records[0].s3;
        const bucket = s3Record.bucket.name;
        const key = decodeURIComponent(s3Record.object.key);
        
        const command = new GetObjectCommand({ Bucket: bucket, Key: key });
        const response = await s3Client.send(command);
        let content = await response.Body.transformToByteArray();

        // Handle gzip compression
        if (key.endsWith('.gz')) {
            content = zlib.gunzipSync(content);
        }

        const lines = content.toString('utf-8').split('\n').filter(line => line.trim());
        console.log(`Processing ${lines.length} lines from ${key}`);
        // Determine log type and index from path and filename
        const isErrorLog = key.includes('wpe_logs/error/');
        const isApacheStyle = key.includes('apachestyle.log.gz');
        const logType = isErrorLog ? 'error' : (isApacheStyle ? 'apache' : 'standard');
        const indexName = isErrorLog ? 'error-logs' : (isApacheStyle ? 'apache-access-logs' : 'access-logs');
        
        console.log(`Processing ${logType} log file, using index: ${indexName}`);
        
        // Ensure the correct index exists before processing
        await ensureIndex(indexName);
        
        // Process each line
        for (const line of lines) {
            // Log the raw line for verification
            console.log('Processing raw log line:', line);

            const entry = exports.processLogLine(line, logType);
            if (!entry) continue;

            // Debug log the type and format
            console.log('Log type:', logType);
            console.log('Formatted output:', exports.formatLogForVerification(entry, logType));
            
            try {
                // Index the log entry
                await indexLog(entry, indexName);
            } catch (error) {
                console.error('Error indexing log entry:', error);
                // Continue processing other entries even if one fails
                continue;
            }

            // Check for critical errors
            if (isErrorLog && exports.isCriticalError(entry.message)) {
                await sendAlert(
                    `Critical Error Detected: ${entry.message}`,
                    'CRITICAL'
                );
            }

            // Check for high error rates or suspicious patterns
            if (!isErrorLog && entry.status >= 500) {
                await sendAlert(
                    `High number of 5xx errors detected for ${entry.domain}`,
                    'WARNING'
                );
            }
        }

        return {
            statusCode: 200,
            body: JSON.stringify({
                message: 'Logs processed successfully',
                linesProcessed: lines.length
            })
        };
    } catch (error) {
        console.error('Error processing logs:', error);
        
        await sendAlert(
            `Error processing log file: ${error.message}`,
            'ERROR'
        );

        throw error;
    }
};
