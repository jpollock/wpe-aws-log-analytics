# Prerequisites

Before running the setup wizard, you'll need to install a few tools. This guide will help you get everything set up on your system.

## Required Tools

### 1. Homebrew (Package Manager)

If you don't have Homebrew installed, install it first:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Terraform

Install Terraform using Homebrew:

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

Verify installation:
```bash
terraform --version
```

### 3. AWS CLI

Install the AWS CLI using Homebrew:

```bash
brew install awscli
```

Verify installation:
```bash
aws --version
```

### 4. Other Required Tools

Install additional required tools:

```bash
brew install jq curl
```

## AWS Account Setup

1. Create an AWS account if you don't have one:
   - Visit [AWS Console](https://aws.amazon.com)
   - Click "Create an AWS Account"
   - Follow the signup process

2. Create AWS access keys:
   - Go to AWS Console
   - Click your name in top right
   - Select "Security credentials"
   - Under "Access keys", create new key
   - Save both Access Key ID and Secret Access Key

3. Configure AWS CLI:
```bash
aws configure
```
Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., us-west-2)
- Default output format (json)

## Verify Prerequisites

After installing all tools, you can verify your setup:

```bash
# Check Terraform
terraform --version

# Check AWS CLI
aws --version

# Check jq
jq --version

# Check curl
curl --version
```

## Next Steps

Once all prerequisites are installed:

1. Navigate to the project directory:
```bash
cd /Users/jeremy.pollock/Documents/Working/product_ideas/LogOffloadingToS3/wpe-aws-log-analytics
```

2. Run the setup wizard:
```bash
./setup/wizard.sh
```

## Troubleshooting

### Common Issues

1. Terraform not found:
```bash
brew doctor
brew update
brew install hashicorp/tap/terraform
```

2. AWS CLI configuration issues:
```bash
aws configure
aws sts get-caller-identity  # Test configuration
```

3. Permission issues:
```bash
chmod +x setup/wizard.sh
```

### Need Help?

If you encounter any issues:
1. Check error messages
2. Verify tool versions
3. Ensure AWS credentials are correct
4. Contact support team
