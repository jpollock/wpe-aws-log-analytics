#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

OLD_DIR="product_ideas/LogOffloadingToS3/log-analytics"
NEW_DIR="product_ideas/LogOffloadingToS3/wpe-aws-log-analytics"

echo -e "${BLUE}Moving files to new location...${NC}"

# Create necessary directories
mkdir -p "$NEW_DIR"/{docs/{user-guide,technical},infrastructure/terraform/{lambda,opensearch/{dashboards,templates}},setup}

# Move files preserving directory structure
echo "Moving infrastructure files..."
cp -r "$OLD_DIR/infrastructure/terraform"/* "$NEW_DIR/infrastructure/terraform/"

echo "Moving documentation..."
cp -r "$OLD_DIR/docs"/* "$NEW_DIR/docs/"

echo "Moving setup files..."
cp -r "$OLD_DIR/setup"/* "$NEW_DIR/setup/"

echo "Moving configuration files..."
cp "$OLD_DIR/.gitignore" "$NEW_DIR/"
mkdir -p "$NEW_DIR/.github/workflows"
cp "$OLD_DIR/.github/workflows/ci.yml" "$NEW_DIR/.github/workflows/"

# Make scripts executable
chmod +x "$NEW_DIR/setup/wizard.sh"
chmod +x "$NEW_DIR/verify-deployment.sh"
chmod +x "$NEW_DIR/infrastructure/terraform/lambda/build.sh"
chmod +x "$NEW_DIR/infrastructure/terraform/opensearch/import-dashboards.sh"

echo -e "${GREEN}Files moved successfully!${NC}"
echo
echo "Next steps:"
echo "1. Verify all files are in place"
echo "2. Update any paths in configuration files"
echo "3. Test the deployment"
echo
echo "To verify deployment:"
echo "./verify-deployment.sh"
