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

# Clean up
echo "Cleaning up..."
rm -rf node_modules package-lock.json log_processor.zip dist

# Install production dependencies
echo "Installing dependencies..."
npm install --omit=dev

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to install dependencies${NC}"
    exit 1
fi

# Create a temporary directory for the package
echo "Creating deployment package..."
mkdir -p dist
cp index.js dist/
cp package.json dist/

# Copy all production node_modules
cp -r node_modules dist/

# Create deployment package
cd dist
zip -r ../log_processor.zip .
cd ..

# Clean up
rm -rf dist

if [ -f log_processor.zip ]; then
    echo -e "${GREEN}Successfully created log_processor.zip${NC}"
    echo "Package location: log_processor.zip"
    
    # Move to lambda directory
    mkdir -p ../lambda
    mv log_processor.zip ../lambda/
else
    echo -e "${RED}Failed to create deployment package${NC}"
    exit 1
fi
