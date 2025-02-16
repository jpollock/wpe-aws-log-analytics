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
4. Install pre-commit hooks for security scanning

## Security Best Practices

### Credential Management
1. Never commit AWS credentials or sensitive information to the repository
2. Use environment variables or AWS profiles for local development
3. Store production credentials securely (e.g., AWS Secrets Manager)

### Configuration Files
1. Copy `.env.example` to `.env` for local development
2. Copy `terraform.tfvars.example` to `terraform.tfvars` for infrastructure
3. Add your specific values to these files but DO NOT commit them

### Pre-commit Hooks
The repository includes pre-commit hooks to prevent accidental credential leaks:
```bash
# Install pre-commit
brew install pre-commit

# Install the hooks
pre-commit install
```

### AWS Credentials
1. For local development:
   - Use AWS profiles or environment variables
   - LocalStack is configured by default for testing
2. For production:
   - Use IAM roles with minimal required permissions
   - Enable AWS CloudTrail for audit logging
   - Regularly rotate access keys

### Repository Security
1. All sensitive files are listed in .gitignore
2. Pre-commit hooks scan for:
   - AWS credentials
   - Private keys
   - Large files
   - Merge conflicts
3. Use gitleaks for additional secret scanning

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

## Log File Structure

Logs are organized in the S3 bucket as follows:

```
<bucket>/
  wpe_logs/
    error/              # Error logs directory
      *.log.gz         # Gzipped error log files
    nginx/             # Web access logs directory
      *-access.log.gz         # Standard access log format
      *-apachestyle.log.gz    # Apache-style access log format
```

### Log Formats

1. Error Logs (`/wpe_logs/error/*.log.gz`):
   ```
   [2025-02-09T06:13:54.773313+00:00] message content here
   ```
   - Timestamp in ISO 8601 format
   - Message content following timestamp
   - Supports "message repeated X times" format

2. Standard Access Logs (`/wpe_logs/nginx/*-access.log.gz`):
   ```
   timestamp|version|ip|domain|status|bytes|server|response_time|total_time|request
   ```
   - Pipe-delimited format
   - Contains request timing and server details

3. Apache-Style Access Logs (`/wpe_logs/nginx/*-apachestyle.log.gz`):
   ```
   %h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"
   ```
   - Standard Apache combined log format
   - Contains IP, timestamp, request, status, bytes, referer, and user agent

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
