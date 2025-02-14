#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if required environment variables are set
if [ -z "$OPENSEARCH_ENDPOINT" ]; then
    echo -e "${RED}Error: OPENSEARCH_ENDPOINT environment variable is not set${NC}"
    echo "Please set it to your OpenSearch domain endpoint"
    echo "Example: export OPENSEARCH_ENDPOINT=https://your-domain.region.es.amazonaws.com"
    exit 1
fi

if [ -z "$AWS_REGION" ]; then
    echo -e "${YELLOW}Warning: AWS_REGION not set, using us-west-2${NC}"
    AWS_REGION="us-west-2"
fi

echo "Importing dashboards to OpenSearch..."

# Function to wait for OpenSearch to be ready
wait_for_opensearch() {
    echo "Checking OpenSearch availability..."
    while true; do
        if curl -s -o /dev/null -w "%{http_code}" --aws-sigv4 "aws:amz:${AWS_REGION}:es" "${OPENSEARCH_ENDPOINT}/_cluster/health" | grep -q "200"; then
            echo -e "${GREEN}OpenSearch is ready${NC}"
            break
        else
            echo "Waiting for OpenSearch to be ready..."
            sleep 10
        fi
    done
}

# Function to create index template
create_index_template() {
    local template_name=$1
    local template_file=$2
    
    echo "Creating index template: ${template_name}"
    curl -XPUT --aws-sigv4 "aws:amz:${AWS_REGION}:es" \
         -H "Content-Type: application/json" \
         "${OPENSEARCH_ENDPOINT}/_template/${template_name}" \
         -d @"${template_file}"
}

# Function to import dashboard
import_dashboard() {
    local dashboard_file=$1
    
    echo "Importing dashboard configuration..."
    curl -XPOST --aws-sigv4 "aws:amz:${AWS_REGION}:es" \
         -H "Content-Type: application/json" \
         "${OPENSEARCH_ENDPOINT}/_dashboards/api/saved_objects/_bulk_create" \
         -d @"${dashboard_file}"
}

# Wait for OpenSearch to be ready
wait_for_opensearch

# Create index templates
echo "Creating index templates..."
create_index_template "error-logs" "templates/error-logs.json"
create_index_template "access-logs" "templates/access-logs.json"

# Import dashboards
echo "Importing dashboards..."
import_dashboard "dashboards/overview.json"

# Verify import
echo "Verifying dashboard import..."
response=$(curl -s --aws-sigv4 "aws:amz:${AWS_REGION}:es" \
     "${OPENSEARCH_ENDPOINT}/_dashboards/api/saved_objects/_find?type=dashboard")

if echo "$response" | grep -q "overview-dashboard"; then
    echo -e "${GREEN}Dashboard imported successfully!${NC}"
    echo
    echo "You can now access your dashboards at:"
    echo "${OPENSEARCH_ENDPOINT}/_dashboards"
    echo
    echo "Default credentials:"
    echo "Username: admin"
    echo "Password: (check AWS Secrets Manager or the Terraform output)"
else
    echo -e "${RED}Failed to verify dashboard import${NC}"
    echo "Please check the OpenSearch error logs"
    exit 1
fi

# Print usage instructions
echo
echo "To create a new visualization:"
echo "1. Go to ${OPENSEARCH_ENDPOINT}/_dashboards"
echo "2. Click 'Visualize' in the left menu"
echo "3. Click 'Create visualization'"
echo
echo "To modify the overview dashboard:"
echo "1. Go to ${OPENSEARCH_ENDPOINT}/_dashboards"
echo "2. Click 'Dashboard' in the left menu"
echo "3. Select 'Log Analytics Overview'"
echo "4. Click 'Edit' in the top menu"
