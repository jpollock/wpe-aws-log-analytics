#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Running build tests..."

# Get script directory and lambda directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LAMBDA_DIR="$(dirname "$SCRIPT_DIR")"

# Build the package
echo "Building Lambda package..."
"$LAMBDA_DIR/build.sh"

if [ ! -f "$LAMBDA_DIR/log_processor.zip" ]; then
    echo -e "${RED}Build failed: log_processor.zip not found${NC}"
    exit 1
fi

# Create a test directory
echo "Creating test environment..."
TEST_DIR="test-env"
rm -rf $TEST_DIR
mkdir -p $TEST_DIR

# Extract the package
cd "$LAMBDA_DIR/$TEST_DIR"
unzip "$LAMBDA_DIR/log_processor.zip" > /dev/null

# Create a simple test file to verify module loading
echo "Creating module test..."
cat > test-modules.js << 'EOL'
// Test importing required modules
const modules = [
    '@aws-sdk/client-s3',
    '@aws-sdk/client-sns',
    '@opensearch-project/opensearch',
    '@smithy/protocol-http',
    '@smithy/middleware-retry',
    '@smithy/smithy-client',
    '@smithy/types',
    '@smithy/util-retry',
    'tslib'
];

console.log('Testing module imports...');

modules.forEach(module => {
    try {
        require(module);
        console.log(`✓ Successfully loaded ${module}`);
    } catch (error) {
        console.error(`✗ Failed to load ${module}: ${error.message}`);
        process.exit(1);
    }
});

// Test the main handler
try {
    const { handler } = require('./index.js');
    console.log('✓ Successfully loaded main handler');
} catch (error) {
    console.error(`✗ Failed to load main handler: ${error.message}`);
    process.exit(1);
}

console.log('All modules loaded successfully!');
EOL

# Run the module test
echo "Testing module loading..."
node test-modules.js

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Build test passed: All modules loaded successfully${NC}"
    # Clean up
    cd "$LAMBDA_DIR"
    rm -rf "$TEST_DIR"
    exit 0
else
    echo -e "${RED}Build test failed: Module loading errors detected${NC}"
    cd "$ORIGINAL_DIR"
    exit 1
fi
