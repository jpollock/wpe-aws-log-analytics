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
    local timestamp=$(date -u +"%Y%m%d-%H%M")
    local test_dir=$(mktemp -d)
    local exit_code=0

    # Create test error log
    echo "Creating test error log..."
    local error_log="$test_dir/error.log"
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")] test error log entry" > "$error_log"
    gzip "$error_log"
    
    # Create test standard access log
    echo "Creating test standard access log..."
    local access_log="$test_dir/$timestamp-test.access.log"
    echo "$(date -u +"%d/%b/%Y:%H:%M:%S +0000")|v1|192.168.1.1|example.com|200|1234|server1|0.001|0.002|GET /test HTTP/1.1" > "$access_log"
    gzip "$access_log"
    
    # Create test Apache-style access log
    echo "Creating test Apache-style access log..."
    local apache_log="$test_dir/$timestamp-test.apachestyle.log"
    echo "192.168.1.1 - - [$(date -u +"%d/%b/%Y:%H:%M:%S +0000")] \"GET /test HTTP/1.1\" 200 1234 \"-\" \"Mozilla/5.0\"" > "$apache_log"
    gzip "$apache_log"
    
    # Upload to S3
    echo "Uploading test logs to S3..."
    if aws s3 cp "$error_log.gz" "s3://$LOG_BUCKET_NAME/wpe_logs/error/$(basename "$error_log.gz")"; then
        echo -e "${GREEN}✓ Test error log uploaded successfully${NC}"
    else
        echo -e "${RED}✗ Failed to upload test error log${NC}"
        exit_code=1
    fi
    
    if aws s3 cp "$access_log.gz" "s3://$LOG_BUCKET_NAME/wpe_logs/nginx/$(basename "$access_log.gz")"; then
        echo -e "${GREEN}✓ Test access log uploaded successfully${NC}"
    else
        echo -e "${RED}✗ Failed to upload test access log${NC}"
        exit_code=1
    fi
    
    if aws s3 cp "$apache_log.gz" "s3://$LOG_BUCKET_NAME/wpe_logs/nginx/$(basename "$apache_log.gz")"; then
        echo -e "${GREEN}✓ Test Apache-style log uploaded successfully${NC}"
    else
        echo -e "${RED}✗ Failed to upload test Apache-style log${NC}"
        exit_code=1
    fi
    
    # Clean up
    rm -rf "$test_dir"
    
    # Wait for processing
    echo "Waiting for log processing (5 seconds)..."
    sleep 5
    
    # Wait for processing
    echo "Waiting for log processing (5 seconds)..."
    sleep 5
    
    # Check Lambda logs
    echo "Checking Lambda logs..."
    local log_group="/aws/lambda/wpe-log-analytics-prod-log-processor"
    
    # Check if log group exists
    if aws logs describe-log-groups --log-group-name-prefix "$log_group" | grep -q "$log_group"; then
        # Get most recent log stream
        local log_stream=$(aws logs describe-log-streams --log-group-name "$log_group" --order-by LastEventTime --descending --limit 1 --query 'logStreams[0].logStreamName' --output text)
        
        # Get recent log events from that stream
        local log_events=$(aws logs get-log-events --log-group-name "$log_group" --log-stream-name "$log_stream" --limit 100)
        
        # Check for each log type
        if echo "$log_events" | grep -q "test error log entry"; then
            echo -e "${GREEN}✓ Error log processing confirmed${NC}"
        else
            echo -e "${YELLOW}! Could not find error log entry${NC}"
            exit_code=1
        fi
        
        if echo "$log_events" | grep -q "example.com.*GET /test"; then
            echo -e "${GREEN}✓ Standard access log processing confirmed${NC}"
        else
            echo -e "${YELLOW}! Could not find standard access log entry${NC}"
            exit_code=1
        fi
        
        if echo "$log_events" | grep -q "Mozilla/5.0.*GET /test"; then
            echo -e "${GREEN}✓ Apache-style log processing confirmed${NC}"
        else
            echo -e "${YELLOW}! Could not find Apache-style log entry${NC}"
            exit_code=1
        fi
    else
        echo -e "${YELLOW}! Log group not found yet - check OpenSearch directly${NC}"
        exit_code=1
    fi
    
    return $exit_code
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
