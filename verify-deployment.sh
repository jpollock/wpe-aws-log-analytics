#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Log Analytics Deployment Verification${NC}"
echo "======================================="

# Check environment variables
check_env_vars() {
    echo -e "\n${BLUE}Checking environment variables...${NC}"
    local missing=0
    
    if [ -z "$AWS_REGION" ]; then
        echo -e "${RED}✗ AWS_REGION not set${NC}"
        missing=1
    else
        echo -e "${GREEN}✓ AWS_REGION set to: $AWS_REGION${NC}"
    fi
    
    if [ -z "$LOG_BUCKET_NAME" ]; then
        echo -e "${RED}✗ LOG_BUCKET_NAME not set${NC}"
        missing=1
    else
        echo -e "${GREEN}✓ LOG_BUCKET_NAME set to: $LOG_BUCKET_NAME${NC}"
    fi
    
    return $missing
}

# Check AWS resources
check_aws_resources() {
    echo -e "\n${BLUE}Checking AWS resources...${NC}"
    
    # Check S3 bucket
    echo "Checking S3 bucket..."
    if aws s3 ls "s3://$LOG_BUCKET_NAME" &>/dev/null; then
        echo -e "${GREEN}✓ S3 bucket exists and is accessible${NC}"
    else
        echo -e "${RED}✗ Cannot access S3 bucket${NC}"
        return 1
    fi
    
    # Check OpenSearch domain
    echo "Checking OpenSearch domain..."
    local domain_name="wpe-log-analytics-prod-logs"
    if aws opensearch describe-domain --domain-name "$domain_name" &>/dev/null; then
        echo -e "${GREEN}✓ OpenSearch domain is running${NC}"
        # Get endpoint
        local endpoint=$(aws opensearch describe-domain --domain-name "$domain_name" --query 'DomainStatus.Endpoint' --output text)
        echo -e "${GREEN}  Domain endpoint: $endpoint${NC}"
    else
        echo -e "${RED}✗ OpenSearch domain not found${NC}"
        return 1
    fi
    
    # Check Lambda function
    echo "Checking Lambda function..."
    local function_name="wpe-log-analytics-prod-log-processor"
    if aws lambda get-function --function-name "$function_name" &>/dev/null; then
        echo -e "${GREEN}✓ Lambda function exists${NC}"
    else
        echo -e "${RED}✗ Lambda function not found${NC}"
        return 1
    fi
    
    # Check SNS topic
    echo "Checking SNS topic..."
    local topic_name="wpe-log-analytics-prod-alerts"
    if aws sns list-topics | grep -q "$topic_name"; then
        echo -e "${GREEN}✓ SNS topic exists${NC}"
    else
        echo -e "${RED}✗ SNS topic not found${NC}"
        return 1
    fi
}

# Test log processing
test_log_processing() {
    echo -e "\n${BLUE}Testing log processing...${NC}"
    
    # Create test log file
    echo "Creating test log file..."
    local test_log="test-$(date +%s).log"
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")] test log entry" > "$test_log"
    
    # Upload to S3
    echo "Uploading to S3..."
    if aws s3 cp "$test_log" "s3://$LOG_BUCKET_NAME/test/$test_log"; then
        echo -e "${GREEN}✓ Test log uploaded successfully${NC}"
    else
        echo -e "${RED}✗ Failed to upload test log${NC}"
        rm "$test_log"
        return 1
    fi
    
    # Clean up
    rm "$test_log"
    
    # Wait for processing
    echo "Waiting for log processing (30 seconds)..."
    sleep 30
    
    # Check Lambda logs
    echo "Checking Lambda logs..."
    local log_group="/aws/lambda/wpe-log-analytics-prod-log-processor"
    
    # Wait a bit for log group creation
    sleep 5
    
    # Check if log group exists
    if aws logs describe-log-groups --log-group-name-prefix "$log_group" | grep -q "$log_group"; then
        # Wait a bit more for logs to be written
        sleep 5
        if aws logs get-log-events --log-group-name "$log_group" --limit 10 | grep -q "test log entry"; then
            echo -e "${GREEN}✓ Log processing confirmed${NC}"
        else
            echo -e "${YELLOW}! Could not find test log entry - check OpenSearch directly${NC}"
        fi
    else
        echo -e "${YELLOW}! Log group not found yet - check OpenSearch directly${NC}"
    fi
}

# Check OpenSearch dashboards
check_dashboards() {
    echo -e "\n${BLUE}Checking OpenSearch dashboards...${NC}"
    
    local domain_name="wpe-log-analytics-prod-logs"
    local endpoint=$(aws opensearch describe-domain --domain-name "$domain_name" --query 'DomainStatus.Endpoint' --output text)
    
    if [ -n "$endpoint" ]; then
        echo -e "${GREEN}OpenSearch dashboard is available at:${NC}"
        echo -e "${BLUE}https://$endpoint/_dashboards${NC}"
        echo
        echo "Login credentials:"
        echo "Username: admin"
        
        # Get password from terraform output if we're in the project directory
        if [[ $PWD == */wpe-aws-log-analytics ]]; then
            cd infrastructure/terraform
            local password=$(terraform output -raw opensearch_password 2>/dev/null)
            cd ../..
            
            if [ -n "$password" ]; then
                echo "Password: $password"
            else
                echo "Password: (run 'cd infrastructure/terraform && terraform output opensearch_password' to get the password)"
            fi
        else
            echo "Password: (run 'cd /path/to/wpe-aws-log-analytics/infrastructure/terraform && terraform output opensearch_password' to get the password)"
        fi
        echo
        echo "After logging in:"
        echo "1. Navigate to 'Dashboards' in the left menu"
        echo "2. Look for 'Log Analytics Overview' dashboard"
    else
        echo -e "${RED}✗ Could not retrieve OpenSearch endpoint${NC}"
        return 1
    fi
}

# Main verification process
main() {
    local exit_code=0
    
    # Check environment
    check_env_vars
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}Environment verification failed${NC}"
        echo "Please set the required environment variables and try again"
        exit 1
    fi
    
    # Check AWS resources
    check_aws_resources
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}Resource verification failed${NC}"
        echo "Please check the error messages above and verify your deployment"
        exit_code=1
    fi
    
    # Test log processing if resources are OK
    if [ $exit_code -eq 0 ]; then
        test_log_processing
        if [ $? -ne 0 ]; then
            echo -e "\n${YELLOW}Log processing test failed${NC}"
            echo "This might indicate configuration issues"
            exit_code=1
        fi
    fi
    
    # Check dashboards
    check_dashboards
    if [ $? -ne 0 ]; then
        echo -e "\n${YELLOW}Dashboard verification needs manual check${NC}"
        exit_code=1
    fi
    
    if [ $exit_code -eq 0 ]; then
        echo -e "\n${GREEN}Deployment verification completed successfully!${NC}"
    else
        echo -e "\n${YELLOW}Deployment verification completed with warnings${NC}"
        echo "Please review the messages above and take necessary actions"
    fi
    
    return $exit_code
}

# Run main function
main
