#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}WPE AWS Log Analytics Setup Wizard${NC}"
echo "======================================="

# Check prerequisites
check_prerequisites() {
    echo -e "\n${BLUE}Checking prerequisites...${NC}"
    
    local REQUIRED_COMMANDS="aws terraform jq curl"
    for cmd in $REQUIRED_COMMANDS; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}✗ $cmd is required but not installed${NC}"
            case $cmd in
                "aws")
                    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
                    ;;
                "terraform")
                    echo "Please install Terraform: https://www.terraform.io/downloads.html"
                    ;;
                *)
                    echo "Please install $cmd using your package manager"
                    ;;
            esac
            exit 1
        fi
    done
    echo -e "${GREEN}✓ All prerequisites met${NC}"
}

# Configure AWS
configure_aws() {
    echo -e "\n${BLUE}Configuring AWS...${NC}"
    
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}AWS credentials not configured${NC}"
        echo "Would you like to:"
        echo "1. Enter AWS credentials manually"
        echo "2. Create a new AWS account"
        read -p "Choose an option (1-2): " aws_option
        
        case $aws_option in
            1)
                read -p "Enter AWS Access Key ID: " aws_access_key
                read -s -p "Enter AWS Secret Access Key: " aws_secret_key
                echo
                read -p "Enter AWS region (e.g., us-west-2): " aws_region
                
                # Configure AWS CLI
                aws configure set aws_access_key_id "$aws_access_key"
                aws configure set aws_secret_access_key "$aws_secret_key"
                aws configure set region "$aws_region"
                aws configure set output "json"
                ;;
            2)
                echo "Opening AWS account creation page..."
                open "https://portal.aws.amazon.com/billing/signup"
                echo "After creating your account, please run this wizard again"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                exit 1
                ;;
        esac
    else
        echo -e "${GREEN}✓ AWS credentials already configured${NC}"
    fi
}

# Configure alert email
configure_alerts() {
    echo -e "\n${BLUE}Configuring Alerts...${NC}"
    
    read -p "Enter email address for alerts (or press Enter to skip): " email
    if [ -n "$email" ]; then
        export ALERT_EMAIL="$email"
        echo -e "${GREEN}✓ Alert email configured${NC}"
    else
        echo -e "${YELLOW}! Skipping alert configuration${NC}"
        echo "Note: Lambda processing and alerts will be disabled"
    fi
}

# Configure S3 bucket
configure_s3() {
    echo -e "\n${BLUE}Configuring S3 bucket...${NC}"
    
    read -p "Enter your S3 bucket name: " bucket_name
    export LOG_BUCKET_NAME="$bucket_name"
    
    # Check if bucket exists
    if aws s3 ls "s3://$bucket_name" &>/dev/null; then
        echo -e "${GREEN}✓ Bucket exists and is accessible${NC}"
        create_new_bucket="false"
    else
        echo -e "${YELLOW}Bucket does not exist${NC}"
        read -p "Would you like to create it? (y/N): " create_bucket
        if [[ $create_bucket =~ ^[Yy] ]]; then
            create_new_bucket="true"
        else
            echo -e "${RED}Cannot proceed without a valid S3 bucket${NC}"
            exit 1
        fi
    fi
    
    # Update tfvars
    sed -i '' "s/create_new_bucket.*=.*/create_new_bucket = $create_new_bucket/" infrastructure/terraform/terraform.tfvars
}

# Initialize Terraform
init_terraform() {
    echo -e "\n${BLUE}Initializing Terraform...${NC}"
    
    cd infrastructure/terraform
    
    echo "Using local state storage for Terraform configuration"
    echo "This means state will be stored in your project directory"
    echo
    
    # Initialize Terraform with local state
    if terraform init -input=false; then
        echo -e "${GREEN}✓ Terraform initialized${NC}"
    else
        echo -e "${RED}Failed to initialize Terraform${NC}"
        echo "Common issues:"
        echo "1. AWS credentials not properly configured"
        echo "2. Missing permissions"
        echo "3. Network connectivity issues"
        echo
        echo "Please check the error message above and try again"
        exit 1
    fi
    
    cd ../..
}

# Apply Terraform configuration
apply_terraform() {
    echo -e "\n${BLUE}Deploying Infrastructure${NC}"
    
    cd infrastructure/terraform
    
    # Show plan first
    echo "Generating deployment plan..."
    if ! terraform plan \
        -var "log_bucket_name=$LOG_BUCKET_NAME" \
        -var "alert_email=${ALERT_EMAIL:-}" \
        -var "project_name=wpe-log-analytics"; then
        echo -e "${RED}Failed to generate deployment plan${NC}"
        exit 1
    fi
    
    echo -e "\n${YELLOW}Resource Creation Summary:${NC}"
    echo "This will create:"
    echo "- OpenSearch domain for log storage and visualization"
    echo "- Lambda function for log processing"
    echo "- SNS topic for alerts"
    echo "- IAM roles and policies"
    echo
    echo "Estimated monthly costs:"
    echo "- OpenSearch: ~\$50-100"
    echo "- Lambda processing: ~\$5-20"
    echo "- S3 storage: Varies by log volume"
    echo
    echo -e "${YELLOW}Important Notes:${NC}"
    echo "1. OpenSearch domain takes ~15-20 minutes to deploy"
    echo "2. You can monitor progress in AWS Console"
    echo "3. Run verify-deployment.sh to check status"
    echo
    
    read -p "Would you like to proceed with deployment? (y/N): " proceed
    
    if [[ ! $proceed =~ ^[Yy] ]]; then
        echo -e "${YELLOW}Deployment cancelled${NC}"
        exit 0
    fi
    
    echo "Deploying resources..."
    
    # Apply Terraform configuration
    if terraform apply -auto-approve \
        -var "log_bucket_name=$LOG_BUCKET_NAME" \
        -var "alert_email=${ALERT_EMAIL:-}" \
        -var "project_name=wpe-log-analytics"; then
        echo -e "${GREEN}✓ Deployment initiated${NC}"
        echo
        echo "Next steps:"
        echo "1. Wait ~15-20 minutes for OpenSearch domain creation"
        echo "2. Run ./verify-deployment.sh to check status"
        echo "3. Access your dashboards using the URL provided"
    else
        echo -e "${RED}Deployment failed${NC}"
        echo "Please check the error messages above"
        exit 1
    fi
    
    cd ../..
}

# Wait for OpenSearch domain to be ready
wait_for_opensearch() {
    echo -e "\n${BLUE}Waiting for OpenSearch domain to be ready...${NC}"
    echo "This typically takes 15-20 minutes. Please be patient."
    
    cd infrastructure/terraform
    local domain_name=$(terraform output -raw opensearch_endpoint | cut -d'.' -f1)
    cd ../..
    
    local start_time=$(date +%s)
    local timeout=1800  # 30 minutes timeout
    local spinner=( "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" )
    local spin_idx=0
    
    while true; do
        # Check if timeout exceeded
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        if [ $elapsed -gt $timeout ]; then
            echo -e "\n${RED}Timeout waiting for OpenSearch domain${NC}"
            return 1
        fi
        
        # Get domain status
        local status=$(aws opensearch describe-domain --domain-name "$domain_name" --query 'DomainStatus.Processing' --output text 2>/dev/null)
        if [ "$status" = "false" ]; then
            echo -e "\n${GREEN}✓ OpenSearch domain is ready${NC}"
            return 0
        fi
        
        # Show spinner and elapsed time
        printf "\r${spinner[$spin_idx]} Waiting for OpenSearch domain... (${elapsed}s elapsed) "
        spin_idx=$(( (spin_idx + 1) % 10 ))
        sleep 10
    done
}

# Import dashboards
import_dashboards() {
    echo -e "\n${BLUE}Importing dashboards...${NC}"
    
    # Get OpenSearch endpoint
    cd infrastructure/terraform
    local OPENSEARCH_ENDPOINT="https://$(terraform output -raw opensearch_endpoint)"
    cd ../..
    
    if [ -n "$OPENSEARCH_ENDPOINT" ]; then
        # Get current AWS region
        local aws_region=$(aws configure get region)
        export OPENSEARCH_ENDPOINT
        export AWS_REGION="$aws_region"
        cd infrastructure/terraform/opensearch
        if ./import-dashboards.sh; then
            echo -e "${GREEN}✓ Dashboards imported${NC}"
        else
            echo -e "${RED}Failed to import dashboards${NC}"
            echo "This is likely because the OpenSearch domain is still initializing."
            echo "Please wait a few minutes and run ./verify-deployment.sh to try again."
            cd ../../..
            return 1
        fi
        cd ../../..
    else
        echo -e "${RED}Could not get OpenSearch endpoint${NC}"
        return 1
    fi
}

# Verify deployment
verify_deployment() {
    echo -e "\n${BLUE}Verifying deployment...${NC}"
    
    if ./verify-deployment.sh; then
        echo -e "${GREEN}✓ Deployment verified${NC}"
    else
        echo -e "${YELLOW}Deployment verification completed with warnings${NC}"
        echo "Please check the messages above"
    fi
}

# Build Lambda package
build_lambda() {
    echo -e "\n${BLUE}Building Lambda package...${NC}"
    
    if [ -n "$ALERT_EMAIL" ]; then
        LAMBDA_DIR="infrastructure/terraform/lambda"
        
        # Ensure we're in the project root
        if [[ $PWD != *"wpe-aws-log-analytics" ]]; then
            echo -e "${RED}Must be run from project root${NC}"
            exit 1
        fi
        
        # Make build script executable
        chmod +x "$LAMBDA_DIR/build.sh"
        
        echo "Installing dependencies..."
        cd "$LAMBDA_DIR"
        
        # Clean any existing node_modules
        rm -rf node_modules
        
        # Install dependencies and build package
        if npm install && ./build.sh; then
            echo -e "${GREEN}✓ Lambda package built successfully${NC}"
            
            # Verify the zip file was created
            if [ ! -f "../log_processor.zip" ]; then
                echo -e "${RED}Failed to create Lambda package${NC}"
                cd ../../..
                exit 1
            fi
        else
            echo -e "${RED}Failed to build Lambda package${NC}"
            cd ../../..
            exit 1
        fi
        
        cd ../../..
    else
        echo -e "${YELLOW}! Skipping Lambda build (no alert email configured)${NC}"
        echo "Note: Lambda processing and alerts will be disabled"
    fi
}

# Main setup process
main() {
    check_prerequisites
    configure_aws
    configure_alerts
    configure_s3
    build_lambda
    init_terraform
    apply_terraform
    
    echo -e "\n${YELLOW}Infrastructure deployment initiated.${NC}"
    echo "OpenSearch domain creation is in progress..."
    
    if wait_for_opensearch; then
        import_dashboards
        verify_deployment
        
        # Get dashboard access information
        cd infrastructure/terraform
        local endpoint=$(terraform output -raw opensearch_endpoint)
        local password=$(terraform output -raw opensearch_password)
        cd ../..
        
        echo -e "\n${GREEN}Setup complete!${NC}"
        echo -e "\n${BLUE}OpenSearch Dashboard Access:${NC}"
        echo -e "URL: https://$endpoint/_dashboards"
        echo "Username: admin"
        echo "Password: $password"
        echo
        echo "Important: Save these credentials in a secure location!"
        echo
        echo "Next steps:"
        echo "1. Open the dashboard URL in your browser"
        echo "2. Log in with the credentials above"
        echo "3. Navigate to 'Dashboards' in the left menu"
        echo "4. Look for 'Log Analytics Overview' dashboard"
        echo
        echo "You can run ./verify-deployment.sh anytime to check the system status"
    else
        echo -e "\n${YELLOW}Setup partially complete.${NC}"
        echo "The infrastructure is deployed but OpenSearch is still initializing."
        echo "Please wait a few more minutes, then run:"
        echo "1. ./verify-deployment.sh to check the status"
        echo "2. cd infrastructure/terraform && terraform output to get access information"
    fi
}

# Run main setup
main
