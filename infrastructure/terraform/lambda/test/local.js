const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

// Mock AWS SDK clients
jest.mock('@aws-sdk/client-s3', () => ({
    S3Client: jest.fn().mockImplementation(() => ({
        send: jest.fn().mockImplementation(async (command) => {
            if (command.constructor.name === 'GetObjectCommand') {
                const logContent = fs.readFileSync(path.join(__dirname, 'sample-error.log'));
                return {
                    Body: {
                        transformToByteArray: async () => zlib.gzipSync(logContent)
                    }
                };
            }
        })
    })),
    GetObjectCommand: jest.fn()
}));

jest.mock('@aws-sdk/client-sns', () => ({
    SNSClient: jest.fn().mockImplementation(() => ({
        send: jest.fn().mockImplementation(async () => {
            console.log('SNS alert would be sent');
            return {};
        })
    })),
    PublishCommand: jest.fn()
}));

// Mock OpenSearch client
jest.mock('@opensearch-project/opensearch', () => ({
    Client: jest.fn().mockImplementation(() => ({
        index: jest.fn().mockImplementation(async (params) => {
            console.log('Would index to OpenSearch:', params);
            return {};
        })
    }))
}));

describe('Lambda Function Tests', () => {
    let handler;
    let mockEvent;
    let consoleSpy;

    beforeEach(() => {
        // Clear module cache to ensure fresh imports
        jest.resetModules();
        
        // Import handler
        handler = require('../index').handler;
        
        // Setup mock event
        mockEvent = {
            "Records": [
                {
                    "s3": {
                        "bucket": {
                            "name": process.env.TEST_BUCKET_NAME || "test-bucket"
                        },
                        "object": {
                            "key": "wpe_logs/error/test.log.gz"
                        }
                    }
                }
            ]
        };

        // Spy on console.log
        consoleSpy = jest.spyOn(console, 'log').mockImplementation();
    });

    afterEach(() => {
        consoleSpy.mockRestore();
    });

    test('should process error log file successfully', async () => {
        const result = await handler(mockEvent);
        
        expect(result.statusCode).toBe(200);
        expect(JSON.parse(result.body)).toHaveProperty('message', 'Logs processed successfully');
        expect(JSON.parse(result.body)).toHaveProperty('linesProcessed');
        
        // Verify console output for OpenSearch indexing
        expect(consoleSpy).toHaveBeenCalledWith(
            expect.stringContaining('Would index to OpenSearch')
        );
    });

    test('should detect critical errors and send alerts', async () => {
        // Update ERROR_PATTERNS to include 'critical'
        process.env.ERROR_PATTERNS = JSON.stringify(['critical']);
        
        const result = await handler(mockEvent);
        
        expect(result.statusCode).toBe(200);
        
        // Verify SNS alert was triggered
        expect(consoleSpy).toHaveBeenCalledWith('SNS alert would be sent');
    });
});
