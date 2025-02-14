#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Building Lambda package..."

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo -e "${RED}Error: npm is required but not installed${NC}"
    exit 1
fi

# Clean up any existing build
rm -f ../log_processor.zip

# Install production dependencies
echo "Installing dependencies..."
npm ci --production

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to install dependencies${NC}"
    exit 1
fi

# Create deployment package
echo "Creating deployment package..."
zip -r ../log_processor.zip . -x "*.test.js" "*.md" "build.sh" "package*.json"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully created log_processor.zip${NC}"
    echo "Package location: ../log_processor.zip"
else
    echo -e "${RED}Failed to create deployment package${NC}"
    exit 1
fi
