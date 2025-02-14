const { handler } = require('./index');

// Mock AWS SDK
jest.mock('aws-sdk', () => ({
    S3: jest.fn(() => ({
        getObject: jest.fn().mockReturnValue({
            promise: () => Promise.resolve({
                Body: Buffer.from('test content')
            })
        })
    })),
    SNS: jest.fn(() => ({
        publish: jest.fn().mockReturnValue({
            promise: () => Promise.resolve()
        })
    }))
}));

// Mock OpenSearch client
jest.mock('@opensearch-project/opensearch', () => ({
    Client: jest.fn(() => ({
        index: jest.fn().mockResolvedValue({})
    }))
}));

describe('Log Processor Lambda', () => {
    // Sample logs for testing
    const errorLog = `[2025-02-09T06:13:54.773313+00:00] enforcing rate limit [wpe_rate_limits_login_failed_5796938_user_jpollock911gmail-com]
[2025-02-09T06:14:09.326787+00:00] message repeated 4 times: [ enforcing rate limit [wpe_rate_limits_login_failed_5796938_user_jpollock911gmail-com]]`;

    const accessLog = `06/Feb/2025:00:39:17 +0000|v1|91.242.95.38|jeremypollock.me|200|56701|127.0.0.1:9002|0.001|0.001|GET / HTTP/1.0|0|0|90d7150f19e93b5a-IAD
06/Feb/2025:00:39:18 +0000|v1|176.103.242.216|jeremypollock.me|301|0|127.0.0.1:9002|0.001|0.002|HEAD / HTTP/1.0|0|0|90d715122f484295-EWR`;

    beforeEach(() => {
        // Reset environment variables
        process.env.OPENSEARCH_ENDPOINT = 'https://test-endpoint';
        process.env.AWS_REGION = 'us-west-2';
        process.env.ERROR_PATTERNS = JSON.stringify(['error', 'critical', 'failed']);
        process.env.SNS_TOPIC_ARN = 'test-topic-arn';
    });

    test('processes error logs correctly', async () => {
        const event = {
            Records: [{
                s3: {
                    bucket: { name: 'test-bucket' },
                    object: { key: 'error.log' }
                }
            }]
        };

        const mockGetObject = require('aws-sdk').S3().getObject;
        mockGetObject.mockReturnValueOnce({
            promise: () => Promise.resolve({ Body: Buffer.from(errorLog) })
        });

        const result = await handler(event);
        expect(result.statusCode).toBe(200);
        expect(JSON.parse(result.body).linesProcessed).toBe(2);
    });

    test('processes access logs correctly', async () => {
        const event = {
            Records: [{
                s3: {
                    bucket: { name: 'test-bucket' },
                    object: { key: 'access.log' }
                }
            }]
        };

        const mockGetObject = require('aws-sdk').S3().getObject;
        mockGetObject.mockReturnValueOnce({
            promise: () => Promise.resolve({ Body: Buffer.from(accessLog) })
        });

        const result = await handler(event);
        expect(result.statusCode).toBe(200);
        expect(JSON.parse(result.body).linesProcessed).toBe(2);
    });

    test('handles gzipped logs', async () => {
        const event = {
            Records: [{
                s3: {
                    bucket: { name: 'test-bucket' },
                    object: { key: 'logs.gz' }
                }
            }]
        };

        const zlib = require('zlib');
        const gzippedContent = zlib.gzipSync(Buffer.from(accessLog));

        const mockGetObject = require('aws-sdk').S3().getObject;
        mockGetObject.mockReturnValueOnce({
            promise: () => Promise.resolve({ Body: gzippedContent })
        });

        const result = await handler(event);
        expect(result.statusCode).toBe(200);
    });

    test('sends alerts for critical errors', async () => {
        const criticalErrorLog = '[2025-02-09T06:13:54.773313+00:00] critical error: database connection failed';
        
        const event = {
            Records: [{
                s3: {
                    bucket: { name: 'test-bucket' },
                    object: { key: 'error.log' }
                }
            }]
        };

        const mockGetObject = require('aws-sdk').S3().getObject;
        mockGetObject.mockReturnValueOnce({
            promise: () => Promise.resolve({ Body: Buffer.from(criticalErrorLog) })
        });

        const mockSNSPublish = require('aws-sdk').SNS().publish;
        
        await handler(event);
        expect(mockSNSPublish).toHaveBeenCalled();
    });

    test('handles empty logs gracefully', async () => {
        const event = {
            Records: [{
                s3: {
                    bucket: { name: 'test-bucket' },
                    object: { key: 'empty.log' }
                }
            }]
        };

        const mockGetObject = require('aws-sdk').S3().getObject;
        mockGetObject.mockReturnValueOnce({
            promise: () => Promise.resolve({ Body: Buffer.from('') })
        });

        const result = await handler(event);
        expect(result.statusCode).toBe(200);
        expect(JSON.parse(result.body).linesProcessed).toBe(0);
    });

    test('handles malformed logs gracefully', async () => {
        const malformedLog = 'This is not a valid log line\nNeither is this';
        
        const event = {
            Records: [{
                s3: {
                    bucket: { name: 'test-bucket' },
                    object: { key: 'malformed.log' }
                }
            }]
        };

        const mockGetObject = require('aws-sdk').S3().getObject;
        mockGetObject.mockReturnValueOnce({
            promise: () => Promise.resolve({ Body: Buffer.from(malformedLog) })
        });

        const result = await handler(event);
        expect(result.statusCode).toBe(200);
    });
});
