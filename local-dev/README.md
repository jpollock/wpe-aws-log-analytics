# Local Development Environment

This directory contains everything needed to run and test the log analytics solution locally.

## Prerequisites

- Docker and Docker Compose
- Node.js 16+
- npm

## Setup

1. Install dependencies:
```bash
npm install
```

2. Start the local infrastructure:
```bash
docker-compose up -d
```

3. Initialize the local environment:
```bash
npm run setup
```

This will:
- Create a local S3 bucket in LocalStack
- Create a local SNS topic in LocalStack
- Set up OpenSearch indices
- Create necessary environment variables

## Development Workflow

1. Start the development server:
```bash
npm start
```

2. Place log files in the appropriate directory:
- Error logs: `logs/error/`
- Access logs: `logs/access/`

The development server will automatically:
- Watch for new or modified log files
- Process them using the Lambda function
- Index them in local OpenSearch
- Send notifications to local SNS (if configured)

## Testing

You can use the existing test files from the Lambda directory:
```bash
cd ../infrastructure/terraform/lambda
npm test
```

## Local Services

- OpenSearch Dashboard: http://localhost:9200
- LocalStack (S3, SNS): http://localhost:4566

## Directory Structure

```
local-dev/
├── docker-compose.yml    # Local infrastructure configuration
├── package.json         # Dependencies and scripts
├── dev-server.js       # Local development server
├── setup-local.js      # Environment setup script
└── logs/               # Directory for log files
    ├── error/          # Error log files
    └── access/         # Access log files
```

## Environment Variables

The following environment variables are automatically configured in `.env`:

- `OPENSEARCH_ENDPOINT`: Local OpenSearch endpoint
- `OPENSEARCH_PASSWORD`: OpenSearch admin password
- `SNS_TOPIC_ARN`: Local SNS topic ARN
- `ERROR_PATTERNS`: Patterns to trigger alerts

## Deployment

When ready to deploy to AWS:

1. Stop the local development environment:
```bash
docker-compose down
```

2. Use the existing Terraform configuration in `../infrastructure/terraform/`:
```bash
cd ../infrastructure/terraform
terraform init
terraform plan
terraform apply
