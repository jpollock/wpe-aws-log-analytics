# WPE AWS Log Analytics

A user-friendly solution for analyzing AWS S3 logs with OpenSearch dashboards.

## Overview

This tool helps you:
- Process logs from S3 automatically
- View logs in easy-to-use dashboards
- Get alerts for important events
- Track trends and patterns

## Quick Start

### Prerequisites

Before starting, make sure you have the required tools installed:
1. [Install prerequisites](docs/user-guide/prerequisites.md)
2. Verify your AWS credentials are configured
3. Have your S3 bucket information ready

### Installation

1. Clone this repository
2. Navigate to the project directory:
```bash
cd /Users/jeremy.pollock/Documents/Working/product_ideas/LogOffloadingToS3/wpe-aws-log-analytics
```

3. Run the setup wizard:
```bash
./setup/wizard.sh
```

The wizard will guide you through:
- Installing any missing dependencies
- Configuring AWS credentials
- Setting up your S3 bucket
- Deploying the infrastructure
- Importing dashboards

### Verification

After setup completes:
```bash
./verify-deployment.sh
```

Note: OpenSearch domain creation takes about 15-20 minutes. If verification shows "OpenSearch domain not found", wait and run the verification script again.

## Features

- 📊 Pre-built dashboards for common use cases
- 🔔 Configurable alerts
- 📈 Traffic and error analysis
- 💰 Cost monitoring and optimization

## Components

- AWS Lambda for log processing
- OpenSearch for storage and visualization
- SNS for notifications
- S3 event triggers

## Documentation

- [User Guide](docs/user-guide/)
- [Technical Documentation](docs/technical/)
- [Contributing Guidelines](docs/CONTRIBUTING.md)

## Verification

After deployment, the verification script will check:
1. AWS resource creation
2. Log processing pipeline
3. Dashboard accessibility
4. Alert configuration

## Estimated Costs

Monthly costs typically range from:
- OpenSearch: $50-100
- Lambda processing: $5-20
- S3 storage: Varies by log volume

## Support

- Check [FAQ](docs/user-guide/faq.md)
- Open an issue
- Review troubleshooting guide

## License

MIT License - See LICENSE file for details
