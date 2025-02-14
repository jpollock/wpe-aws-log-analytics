const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const sns = new AWS.SNS();
const { Client } = require('@opensearch-project/opensearch');
const zlib = require('zlib');

// Initialize OpenSearch client
const client = new Client({
    node: process.env.OPENSEARCH_ENDPOINT,
    auth: {
        type: 'aws_iam'
    },
    awsRegion: process.env.AWS_REGION
});

// Parse error log line
const parseErrorLog = (line) => {
    const match = line.match(/\[(.*?)\] (.+)/);
    if (!match) return null;

    const [, timestamp, message] = match;
    const repeatedMatch = message.match(/message repeated (\d+) times: \[(.*)\]/);

    if (repeatedMatch) {
        const [, count, repeatedMessage] = repeatedMatch;
        return {
            timestamp: new Date(timestamp).toISOString(),
            message: repeatedMessage.trim(),
            repeat_count: parseInt(count, 10),
            type: 'error'
        };
    }

    return {
        timestamp: new Date(timestamp).toISOString(),
        message: message.trim(),
        repeat_count: 1,
        type: 'error'
    };
};

// Parse access log line
const parseAccessLog = (line) => {
    const parts = line.split('|');
    if (parts.length < 10) return null;

    return {
        timestamp: new Date(parts[0].replace(/(\d{2})\/(\w{3})\/(\d{4}):(\d{2}:\d{2}:\d{2})/, '$3-$2-$1T$4')).toISOString(),
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

// Check for critical patterns
const isCriticalError = (message) => {
    const criticalPatterns = JSON.parse(process.env.ERROR_PATTERNS || '[]');
    return criticalPatterns.some(pattern => 
        message.toLowerCase().includes(pattern.toLowerCase())
    );
};

// Send alert
const sendAlert = async (message, severity = 'INFO') => {
    const params = {
        Message: JSON.stringify({
            severity,
            message,
            timestamp: new Date().toISOString()
        }),
        TopicArn: process.env.SNS_TOPIC_ARN
    };

    await sns.publish(params).promise();
};

// Index log entry in OpenSearch
const indexLog = async (entry, index) => {
    await client.index({
        index,
        body: entry
    });
};

// Main handler
exports.handler = async (event) => {
    try {
        // Get the S3 object
        const s3Record = event.Records[0].s3;
        const bucket = s3Record.bucket.name;
        const key = decodeURIComponent(s3Record.object.key);
        
        const response = await s3.getObject({ Bucket: bucket, Key: key }).promise();
        let content = response.Body;

        // Handle gzip compression
        if (key.endsWith('.gz')) {
            content = zlib.gunzipSync(content);
        }

        const lines = content.toString('utf-8').split('\n').filter(line => line.trim());
        
        // Determine log type from filename
        const isErrorLog = key.toLowerCase().includes('error');
        const indexName = isErrorLog ? 'error-logs' : 'access-logs';
        
        // Process each line
        for (const line of lines) {
            const entry = isErrorLog ? parseErrorLog(line) : parseAccessLog(line);
            if (!entry) continue;

            // Index the log entry
            await indexLog(entry, indexName);

            // Check for critical errors
            if (isErrorLog && isCriticalError(entry.message)) {
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
