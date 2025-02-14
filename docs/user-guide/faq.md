# Frequently Asked Questions

## General Questions

### What exactly does this tool do?
This tool takes your log files from AWS S3 and turns them into easy-to-understand dashboards and alerts. Instead of looking through raw text files, you get:
- Visual graphs showing traffic patterns
- Instant alerts for important events
- Easy search across all your logs
- Automatic summaries of what's happening

### Do I need to be technical to use this?
No! We've designed this tool specifically for non-technical users. Our setup wizard walks you through everything step-by-step in plain English.

## Setup & Configuration

### How long does setup take?
About 5-10 minutes if you already have an AWS account. If you need to create an AWS account, add another 5-10 minutes for that process.

### What do I need to get started?
- An AWS account (we'll help you create one if needed)
- The name of your S3 bucket where logs are stored
- An email address for receiving alerts

### Can I change settings after initial setup?
Yes! Everything can be adjusted at any time through our simple settings page. Nothing is permanent.

## Costs & Billing

### How much does it cost?
Costs vary based on your usage, but typically range from $50-150 per month. This includes:
- Log storage and processing
- Real-time dashboards
- Alert system
- Automatic backups

We show you estimated costs before anything is set up, and you can set budget alerts to avoid surprises.

### Can I control costs?
Yes! You have several options:
- Set log retention periods (shorter = lower cost)
- Choose which logs to process
- Set up cost alerts
- See cost breakdowns in real-time

### Is there a free trial?
We're working on implementing a free trial period. For now, you can test the setup process without any charges, and you'll see cost estimates before committing to the deployment.

## Security & Privacy

### Is my data secure?
Yes! Your data stays in your own AWS account. We never store or access your logs directly. Everything runs within your own secure environment.

### Who can access my dashboards?
Only people you specifically grant access to. You control:
- Who can view dashboards
- Who receives alerts
- What level of access each person has

### What permissions do you need in my AWS account?
We require minimal permissions to:
- Read logs from your S3 bucket
- Process logs for dashboards
- Send email alerts
- Manage the dashboard infrastructure

## Troubleshooting

### What if I see "Connection Failed"?
Usually this means either:
1. AWS credentials need to be updated
2. Your S3 bucket permissions need adjustment
3. Network connectivity issue

The wizard will help diagnose and fix these automatically.

### Why aren't my alerts working?
Common reasons:
1. Email address hasn't been verified (check your inbox for verification email)
2. Alert settings need adjustment
3. Network or permission issues

Try running the test alert from the settings page to troubleshoot.

### How do I reset everything?
You can:
1. Use the "Reset Configuration" option in settings
2. Run the setup wizard again
3. Contact support for help

## Support & Help

### Where can I get help?
Several options:
1. Check this FAQ
2. Use the built-in help system in the dashboard
3. Open an issue on GitHub
4. Email support (coming soon)

### Can I request new features?
Yes! We love feedback. You can:
- Open a feature request on GitHub
- Use the feedback form in the dashboard
- Email your suggestions

### What if I find a bug?
Please report it! You can:
1. Open an issue on GitHub
2. Use the "Report Problem" button in the dashboard
3. Email support with details

## Updates & Maintenance

### How often do you update the tool?
We regularly release updates with:
- New features
- Security improvements
- Bug fixes
- Performance enhancements

Updates are automatic and don't require any action from you.

### Will updates interrupt my service?
No! Updates are deployed seamlessly without any downtime. Your dashboards and alerts continue working during updates.

### Can I roll back an update?
Yes, if you encounter any issues after an update, you can:
1. Use the rollback option in settings
2. Contact support for immediate assistance
3. Wait for an automatic rollback if problems are detected

## Getting More Help

Still have questions? We're here to help!
- Check our [Quick Start Guide](quick-start.md)
- Review [Dashboard Documentation](dashboards.md)
- Learn about [Alert Configuration](alerts.md)
- Open an issue on GitHub
- Email support (coming soon)
