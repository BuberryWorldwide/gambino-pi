#!/bin/bash

# Gambino Pi - Add Machine Shell Wrapper
# Makes the add-machine tool easier to run

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
NODE_SCRIPT="$SCRIPT_DIR/add-machine.js"

echo -e "${BLUE}🎰 Gambino Pi - Add Machine Tool${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js is not installed${NC}"
    exit 1
fi

# Check if the Node.js script exists
if [ ! -f "$NODE_SCRIPT" ]; then
    echo -e "${RED}❌ add-machine.js not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Check if .env file exists
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${YELLOW}⚠️  .env file not found${NC}"
    echo "Creating .env template..."
    cat > "$SCRIPT_DIR/.env" << 'EOF'
# Gambino Pi Configuration
MACHINE_ID=gambino-pi-001
STORE_ID=store_your_store_id_here
API_ENDPOINT=https://api.gambino.gold
MACHINE_TOKEN=your_jwt_token_here
SERIAL_PORT=/dev/ttyUSB0
LOG_LEVEL=info
NODE_ENV=production
EOF
    echo -e "${YELLOW}📝 Please edit .env file with your actual configuration${NC}"
    echo -e "${YELLOW}   Then run this script again${NC}"
    exit 1
fi

# Check if npm dependencies are installed
if [ ! -d "$SCRIPT_DIR/node_modules" ]; then
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    cd "$SCRIPT_DIR"
    npm install --silent
fi

# Run the Node.js script
echo -e "${GREEN}🚀 Starting Add Machine Tool...${NC}"
echo ""
cd "$SCRIPT_DIR"
node add-machine.js "$@"