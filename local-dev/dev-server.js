// Load environment variables first
require('dotenv').config();

const chokidar = require('chokidar');
const path = require('path');
const fs = require('fs');
const lambda = require('../infrastructure/terraform/lambda/index.js');

// Directory to watch for new log files
const WATCH_DIR = path.join(__dirname, 'logs');

// Ensure logs directory exists
if (!fs.existsSync(WATCH_DIR)) {
    fs.mkdirSync(WATCH_DIR, { recursive: true });
}

// Create subdirectories for different log types
const ERROR_LOGS_DIR = path.join(WATCH_DIR, 'error');
const ACCESS_LOGS_DIR = path.join(WATCH_DIR, 'access');
fs.mkdirSync(ERROR_LOGS_DIR, { recursive: true });
fs.mkdirSync(ACCESS_LOGS_DIR, { recursive: true });

// Initialize OpenSearch indices
async function initializeIndices() {
    try {
        const { indexMappings, opensearchClient } = lambda;
        
        for (const [indexName, mapping] of Object.entries(indexMappings)) {
            const exists = await opensearchClient.indices.exists({ index: indexName });
            if (!exists.body) {
                console.log(`Creating index ${indexName}`);
                await opensearchClient.indices.create({
                    index: indexName,
                    body: mapping
                });
                console.log(`Successfully created index ${indexName}`);
            }
        }
    } catch (error) {
        console.error('Error initializing indices:', error);
        process.exit(1);
    }
}

// Initialize watcher
const watcher = chokidar.watch(WATCH_DIR, {
    ignored: /(^|[\/\\])\../, // ignore dotfiles
    persistent: true
});

// Initialize environment
console.log('Initializing OpenSearch indices...');
initializeIndices().then(() => {
    console.log('OpenSearch indices initialized');
    console.log(`Watching for log files in ${WATCH_DIR}`);
    console.log('Place your log files in the following directories:');
    console.log(`- Error logs: ${ERROR_LOGS_DIR}`);
    console.log(`- Access logs: ${ACCESS_LOGS_DIR}`);
}).catch(error => {
    console.error('Failed to initialize environment:', error);
    process.exit(1);
});

// Process a log file
async function processLogFile(filepath) {
    console.log(`Processing file: ${filepath}`);
    
    try {
        // Read file content directly
        let content = fs.readFileSync(filepath);
        
        // Handle gzip compression
        if (filepath.endsWith('.gz')) {
            content = require('zlib').gunzipSync(content);
        }

        // Convert content to string and process each line
        const lines = content.toString('utf-8').split('\n').filter(line => line.trim());
        
        // Determine log type and index from path
        const isErrorLog = filepath.includes('/error/');
        const isApacheStyle = filepath.includes('apachestyle.log.gz');
        const logType = isErrorLog ? 'error' : (isApacheStyle ? 'apache' : 'standard');
        const indexName = isErrorLog ? 'error-logs' : (isApacheStyle ? 'apache-access-logs' : 'access-logs');
        
        console.log(`Processing ${logType} log file, using index: ${indexName}`);
        
        // Process each line
        for (const line of lines) {
            const entry = lambda.processLogLine(line, logType);
            if (!entry) continue;

            try {
                // Index the log entry
                await lambda.opensearchClient.index({
                    index: indexName,
                    body: entry
                });
                console.log('Index target:', indexName);
                console.log('Indexed log entry:', entry);

                // Check for critical errors
                if (isErrorLog && lambda.isCriticalError?.(entry.message)) {
                    console.log('Critical error detected:', entry.message);
                }

                // Check for high error rates
                if (!isErrorLog && entry.status >= 500) {
                    console.log('High error rate detected:', entry);
                }
            } catch (error) {
                console.error('Error indexing log entry:', error);
                continue;
            }
        }

        console.log(`Successfully processed ${lines.length} lines from ${filepath}`);
    } catch (error) {
        console.error('Error processing file:', error);
    }
}

// Watch for new files
watcher
    .on('add', filepath => {
        console.log(`New file detected: ${filepath}`);
        processLogFile(filepath);
    })
    .on('change', filepath => {
        console.log(`File changed: ${filepath}`);
        processLogFile(filepath);
    })
    .on('error', error => console.error(`Watcher error: ${error}`));

console.log(`Watching for log files in ${WATCH_DIR}`);
console.log('Place your log files in the following directories:');
console.log(`- Error logs: ${ERROR_LOGS_DIR}`);
console.log(`- Access logs: ${ACCESS_LOGS_DIR}`);
