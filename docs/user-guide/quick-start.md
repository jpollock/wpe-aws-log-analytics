# Quick Start Guide

This guide will help you get up and running with Log Analytics in just a few minutes. No technical expertise required!

## Before You Start

You'll need:
- An AWS account (if you don't have one, we'll help you create it)
- Your S3 bucket name where logs are stored
- 5-10 minutes of your time

## Step 1: Run the Setup Wizard

1. Download this tool (instructions coming soon)
2. Open your terminal
3. Run:
```bash
./setup/wizard.sh
```

## Step 2: Answer Simple Questions

The wizard will ask you a few questions in plain English. Here's what to expect:

### AWS Setup
- "Do you have an AWS account?" (We'll help create one if needed)
- "What's your S3 bucket name?" (Where your logs are stored)

### Log Settings
- "How long do you want to keep your logs?" (Example: 30 days, 6 months, etc.)
- "What time zone should we use for dashboards?" (Your local time zone)

### Alerts
- "Who should receive alerts?" (Email addresses)
- "What kind of events should trigger alerts?"
  * Critical errors
  * Security events
  * High traffic spikes
  * Etc.

## Step 3: Access Your Dashboards

Once setup is complete, you'll get:
1. A URL to access your dashboards
2. Login credentials
3. A test alert to confirm everything's working

## What's Next?

- [Learn about your dashboards](dashboards.md)
- [Set up more alerts](alerts.md)
- [Search through your logs](viewing-logs.md)

## Need Help?

- Check our [FAQ](faq.md)
- Open an issue on GitHub
- Email support (coming soon)

## Common Questions

**Q: How much will this cost?**
A: We'll show you estimated costs before anything is set up, and you can set budget alerts.

**Q: Can I change settings later?**
A: Yes! Everything can be adjusted through an easy-to-use settings page.

**Q: What if something goes wrong?**
A: The wizard checks each step and can automatically fix common issues. If something unexpected happens, it will guide you through the solution.

**Q: Is my data secure?**
A: Yes! We use your own AWS account and follow security best practices. Your data never leaves your control.
