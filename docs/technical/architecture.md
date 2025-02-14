# Technical Architecture

This document describes the technical architecture of the log analytics solution.

## Overview

The solution uses AWS services to create a scalable, serverless log analytics pipeline:

```
S3 Bucket → Lambda → OpenSearch → Dashboards
     ↓
    SNS (Alerts)
```

## Components

### 1. AWS Infrastructure (Terraform)

All infrastructure is defined as code using Terraform in `infrastructure/terraform/`:

- `provider.tf`: AWS provider configuration
- `variables.tf`: Configurable parameters
- `main.tf`: Core infrastructure resources
- `iam.tf`: IAM roles and policies

### 2. Log Processor (Lambda)

Located in `infrastructure/terraform/lambda/`:

```javascript
S3 Event → Lambda → Parse Logs → Index in OpenSearch
                 ↓
              Send Alerts
```

Key files:
- `index.js`: Main Lambda function
- `package.json`: Dependencies
- `build.sh`: Build script
- `index.test.js`: Unit tests

#### Log Parsing

The Lambda function handles two log formats:

1. Error Logs:
```
[timestamp] message
[timestamp] message repeated N times: [repeated_message]
```

2. Access Logs:
```
timestamp|version|ip|domain|status|bytes|server|response_time|total_time|request|...
```

### 3. OpenSearch

- Domain: `${project_name}-${environment}-logs`
- Indices:
  * `error-logs-YYYY-MM-DD`
  * `access-logs-YYYY-MM-DD`

#### Index Mappings

Error Logs:
```json
{
  "mappings": {
    "properties": {
      "timestamp": { "type": "date" },
      "message": { "type": "text" },
      "repeat_count": { "type": "integer" },
      "type": { "type": "keyword" }
    }
  }
}
```

Access Logs:
```json
{
  "mappings": {
    "properties": {
      "timestamp": { "type": "date" },
      "version": { "type": "keyword" },
      "ip": { "type": "ip" },
      "domain": { "type": "keyword" },
      "status": { "type": "integer" },
      "bytes": { "type": "long" },
      "server": { "type": "keyword" },
      "response_time": { "type": "float" },
      "total_time": { "type": "float" },
      "request": { "type": "text" },
      "type": { "type": "keyword" }
    }
  }
}
```

## Security

### IAM Roles

1. Lambda Role:
   - Read from S3
   - Write to OpenSearch
   - Publish to SNS

2. Dashboard Access Role:
   - Read from OpenSearch
   - Limited to specific IP ranges

### Data Protection

- All data encrypted at rest (S3 and OpenSearch)
- HTTPS enforced for all API calls
- OpenSearch in VPC (optional)
- IAM authentication for OpenSearch

## Scaling & Performance

### Lambda Configuration

- Memory: 128 MB (configurable)
- Timeout: 60 seconds
- Concurrent executions: Unlimited

### OpenSearch Sizing

Default configuration:
- Instance Type: t3.small.search
- Instance Count: 1
- Volume Size: 10 GB

Can be scaled up through variables:
```hcl
opensearch_instance_type  = "t3.medium.search"
opensearch_instance_count = 2
opensearch_volume_size    = 20
```

## Monitoring & Alerting

### CloudWatch Metrics

Key metrics monitored:
- Lambda execution time
- Lambda errors
- OpenSearch cluster health
- OpenSearch disk usage
- Processing lag

### Cost Monitoring

Budget alerts configured for:
- Monthly total cost
- Per-service thresholds
- Unusual spending patterns

## Development

### Local Development

1. Install dependencies:
```bash
cd infrastructure/terraform/lambda
npm install
```

2. Run tests:
```bash
npm test
```

3. Build Lambda package:
```bash
./build.sh
```

### Adding New Features

1. Log Parsing:
   - Add new parser in `lambda/index.js`
   - Add corresponding test cases
   - Update OpenSearch mappings if needed

2. Dashboards:
   - Add dashboard definition in OpenSearch
   - Update documentation
   - Test with sample data

3. Infrastructure:
   - Update Terraform configurations
   - Test in staging environment
   - Update technical documentation

## Troubleshooting

### Common Issues

1. Lambda Timeouts:
   - Check log file size
   - Increase memory allocation
   - Optimize parsing logic

2. OpenSearch Errors:
   - Verify IAM permissions
   - Check disk space
   - Review index lifecycle policies

3. Missing Logs:
   - Verify S3 event triggers
   - Check Lambda CloudWatch logs
   - Validate log file format

### Debug Process

1. Check CloudWatch Logs:
   - Lambda function logs
   - OpenSearch error logs
   - S3 data events

2. Verify Infrastructure:
   - Run `terraform plan` to check state
   - Validate IAM permissions
   - Test network connectivity

3. Data Validation:
   - Use test Lambda events
   - Query OpenSearch directly
   - Verify index mappings

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new features
4. Update documentation
5. Submit pull request

See [CONTRIBUTING.md](../CONTRIBUTING.md) for detailed guidelines.
