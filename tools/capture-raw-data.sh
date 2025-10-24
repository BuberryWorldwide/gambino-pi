#!/bin/bash
# capture-raw-data.sh
# Wrapper script to safely capture raw serial data
# Place in: ~/gambino-pi-app/tools/capture-raw-data.sh
# Run: ./tools/capture-raw-data.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}🎯 SAFE RAW SERIAL CAPTURE${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if running as regular user
if [ "$EUID" -eq 0 ]; then 
   echo -e "${RED}❌ Do NOT run this as root/sudo${NC}"
   echo -e "${YELLOW}Run as: ./tools/capture-raw-data.sh${NC}"
   exit 1
fi

# Check if service is running
SERVICE_STATUS=$(systemctl is-active gambino-pi 2>/dev/null || echo "inactive")

if [ "$SERVICE_STATUS" = "active" ]; then
    echo -e "${YELLOW}⚠️  gambino-pi service is running${NC}"
    echo -e "${BLUE}📍 We need to stop it temporarily to access the serial port${NC}"
    echo ""
    echo -e "${YELLOW}This will:${NC}"
    echo "   1. Stop the gambino-pi service"
    echo "   2. Capture raw data from Mutha Goose"
    echo "   3. Restart the service when done"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Cancelled${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${YELLOW}🛑 Stopping gambino-pi service...${NC}"
    sudo systemctl stop gambino-pi
    
    # Give it a moment to release the port
    sleep 2
    
    NEED_RESTART=true
else
    echo -e "${GREEN}✅ Service is not running, port should be free${NC}"
    NEED_RESTART=false
fi

# Cleanup function
cleanup() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🧹 CLEANUP${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    
    if [ "$NEED_RESTART" = true ]; then
        echo -e "${YELLOW}🔄 Restarting gambino-pi service...${NC}"
        sudo systemctl start gambino-pi
        sleep 2
        
        # Check if it started successfully
        if systemctl is-active --quiet gambino-pi; then
            echo -e "${GREEN}✅ Service restarted successfully${NC}"
        else
            echo -e "${RED}❌ Service failed to restart${NC}"
            echo -e "${YELLOW}Run: sudo systemctl status gambino-pi${NC}"
        fi
    fi
    
    echo ""
}

# Set trap to always restart service
trap cleanup EXIT INT TERM

# Run the capture tool
echo ""
echo -e "${GREEN}✅ Port is free, starting capture...${NC}"
echo ""

node tools/raw-serial-capture.js

# cleanup() will run automatically due to trap
