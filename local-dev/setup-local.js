// Load environment variables first
require('dotenv').config();

const { S3Client, CreateBucketCommand, ListBucketsCommand } = require('@aws-sdk/client-s3');
const { SNSClient, CreateTopicCommand } = require('@aws-sdk/client-sns');
const { Client } = require('@opensearch-project/opensearch');
const fs = require('fs');
const path = require('path');

// LocalStack endpoint
const LOCALSTACK_ENDPOINT = 'http://localhost:4566';

// Create initial .env file with base configuration
const createEnvFile = (topicArn) => {
    const envContent = `
# OpenSearch Configuration
OPENSEARCH_ENDPOINT=localhost:9200
OPENSEARCH_PASSWORD=admin

# AWS Configuration (LocalStack)
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_REGION=us-west-2
AWS_ENDPOINT_URL=http://localhost:4566

# SNS Configuration
SNS_TOPIC_ARN=${topicArn || 'arn:aws:sns:us-west-2:000000000000:local-log-alerts'}

# Log Processing Configuration
ERROR_PATTERNS=["critical", "emergency", "fatal"]

# Local Development
NODE_TLS_REJECT_UNAUTHORIZED=0
    `.trim();

    fs.writeFileSync(path.join(__dirname, '.env'), envContent);
    console.log('Created .env file');
};

// Create initial .env file before initializing clients
createEnvFile();

// Initialize clients (will use env vars)
const s3Client = new S3Client({
    endpoint: LOCALSTACK_ENDPOINT,
    region: process.env.AWS_REGION || 'us-west-2',
    credentials: { 
        accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test', 
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test' 
    },
    forcePathStyle: true
});

const snsClient = new SNSClient({
    endpoint: LOCALSTACK_ENDPOINT,
    region: process.env.AWS_REGION || 'us-west-2',
    credentials: { 
        accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test', 
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test' 
    }
});

const opensearchClient = new Client({
    node: `http://${process.env.OPENSEARCH_ENDPOINT}`,
    ssl: {
        rejectUnauthorized: false
    }
});

async function waitForService(name, checkFn, maxAttempts = 30, interval = 1000) {
    console.log(`Waiting for ${name} to be ready...`);
    for (let i = 0; i < maxAttempts; i++) {
        try {
            await checkFn();
            console.log(`${name} is ready!`);
            return;
        } catch (error) {
            console.log(`${name} not ready yet (attempt ${i + 1}/${maxAttempts}): ${error.message}`);
            if (i === maxAttempts - 1) {
                throw new Error(`Timeout waiting for ${name}: ${error.message}`);
            }
            await new Promise(resolve => setTimeout(resolve, interval));
        }
    }
}

async function setupLocalEnvironment() {
    try {
        // Wait for LocalStack
        await waitForService('LocalStack', async () => {
            // Just check if we can list buckets
            await s3Client.send(new ListBucketsCommand({}));
        });

        // Create S3 bucket if it doesn't exist
        console.log('Creating S3 bucket...');
        try {
            await s3Client.send(new CreateBucketCommand({
                Bucket: 'local-bucket'
            }));
            console.log('S3 bucket created');
        } catch (error) {
            if (error.name === 'BucketAlreadyExists' || error.message.includes('BucketAlreadyOwnedByYou')) {
                console.log('S3 bucket already exists');
            } else {
                throw error;
            }
        }

        // Create SNS topic
        console.log('Creating SNS topic...');
        const topicResponse = await snsClient.send(new CreateTopicCommand({
            Name: 'local-log-alerts'
        }));
        console.log('SNS topic created:', topicResponse.TopicArn);

        // Update .env with actual SNS topic ARN
        createEnvFile(topicResponse.TopicArn);

        // Wait for OpenSearch
        await waitForService('OpenSearch', async () => {
            const health = await opensearchClient.cluster.health();
            if (health.body.status === 'red') {
                throw new Error('OpenSearch cluster health is red');
            }
        });

        // Import index mappings from Lambda function
        const { indexMappings } = require('../infrastructure/terraform/lambda/index.js');
        
        // Create OpenSearch indices with proper mappings
        console.log('Creating OpenSearch indices...');
        for (const [indexName, mapping] of Object.entries(indexMappings)) {
            try {
                const exists = await opensearchClient.indices.exists({ index: indexName });
                if (!exists.body) {
                    console.log(`Creating index ${indexName}`);
                    await opensearchClient.indices.create({
                        index: indexName,
                        body: mapping
                    });
                    console.log(`Successfully created index ${indexName}`);
                } else {
                    console.log(`Index ${indexName} already exists`);
                }
            } catch (error) {
                console.error(`Error creating index ${indexName}:`, error);
                throw error;
            }
        }

        console.log('Local environment setup complete!');
        console.log('You can now:');
        console.log('1. Start the development server: npm start');
        console.log('2. Place log files in the logs/error or logs/access directories');
        
    } catch (error) {
        console.error('Error setting up local environment:', error);
        process.exit(1);
    }
}

// Run setup
setupLocalEnvironment();
