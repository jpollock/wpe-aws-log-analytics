# OpenSearch Configuration

This directory contains the OpenSearch configuration for the log analytics solution, including index templates, dashboard definitions, and import scripts.

## Directory Structure

```
opensearch/
├── dashboards/           # Dashboard definitions
│   └── overview.json    # Main overview dashboard
├── templates/           # Index templates
│   ├── access-logs.json # Access logs mapping
│   └── error-logs.json  # Error logs mapping
├── import-dashboards.sh # Dashboard import script
└── README.md           # This file
```

## Pre-built Dashboards

### Overview Dashboard
The main dashboard provides a high-level view of your logs:

1. Error Rate Graph
   - Shows error frequency over time
   - Color-coded by severity
   - Clickable for detailed view

2. Traffic Overview
   - Current traffic levels
   - Average response times
   - Request volume metrics

3. Recent Errors Table
   - Latest error messages
   - Grouped by type
   - Frequency counts

## Index Templates

### Error Logs Template
Optimized for error log format:
- Timestamp parsing
- Message analysis
- Error categorization
- Repeat count tracking

### Access Logs Template
Structured for web access logs:
- IP geolocation support
- Response time metrics
- Status code analysis
- Request path indexing

## Customizing Dashboards

### Adding New Visualizations

1. Log into OpenSearch Dashboards
2. Go to Visualize → Create Visualization
3. Choose visualization type:
   - Line graph for trends
   - Pie chart for distributions
   - Data table for details
   - Metrics for key numbers

### Example Visualizations

#### Error Distribution
```json
{
  "type": "pie",
  "aggs": {
    "error_types": {
      "terms": {
        "field": "error_type",
        "size": 10
      }
    }
  }
}
```

#### Response Time Histogram
```json
{
  "type": "histogram",
  "aggs": {
    "response_times": {
      "histogram": {
        "field": "response_time",
        "interval": 0.1
      }
    }
  }
}
```

## Using the Import Script

1. Set environment variables:
```bash
export OPENSEARCH_ENDPOINT="your-domain-endpoint"
export AWS_REGION="your-region"
```

2. Run the import script:
```bash
./import-dashboards.sh
```

3. Verify in OpenSearch Dashboards:
   - Check Overview dashboard
   - Verify visualizations
   - Test filters

## Index Lifecycle Management

Default retention policies:
- Error logs: 30 days
- Access logs: 90 days

To modify retention:
1. Go to OpenSearch Dashboards
2. Stack Management → Index Lifecycle Policies
3. Edit policy settings

## Advanced Features

### 1. Custom Queries

Example: Find high-latency requests
```json
{
  "query": {
    "range": {
      "response_time": {
        "gt": 1.0
      }
    }
  }
}
```

### 2. Alerts

Create alerts for:
- Error spikes
- High latency
- Failed requests
- Security events

### 3. Dashboard Sharing

Options:
- Public URLs (time-limited)
- PDF exports
- Embedded views
- CSV downloads

## Troubleshooting

### Common Issues

1. Missing Data
   - Check index patterns
   - Verify log format
   - Check Lambda processing

2. Visualization Errors
   - Refresh field list
   - Verify mapping
   - Check date ranges

3. Performance Issues
   - Adjust time range
   - Optimize queries
   - Check shard count

### Getting Help

1. Check logs:
   - OpenSearch error logs
   - Lambda function logs
   - Import script output

2. Common solutions:
   - Refresh browser
   - Clear cache
   - Rerun import script

## Best Practices

1. Dashboards
   - Keep it simple
   - Group related metrics
   - Use clear titles
   - Add descriptions

2. Queries
   - Use filters
   - Limit time ranges
   - Cache results
   - Use aggregations

3. Management
   - Regular backups
   - Monitor disk space
   - Update mappings
   - Review permissions

## Contributing

To add new dashboards:

1. Create JSON definition
2. Add to dashboards/
3. Update import script
4. Test locally
5. Submit PR

See [CONTRIBUTING.md](../../../docs/CONTRIBUTING.md) for more details.
