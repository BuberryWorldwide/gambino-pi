#!/bin/bash
# Enhanced map-machine.sh - More robust with validation and rollback

FLEDGLING_NUMBER=$1
MACHINE_ID=$2
MAPPING_FILE="/opt/gambino-pi/data/machine-mapping.json"
BACKUP_FILE="${MAPPING_FILE}.backup"

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_usage() {
    echo -e "${YELLOW}Usage:${NC} ./map-machine.sh <fledgling_number> <machine_id>"
    echo -e "${BLUE}Examples:${NC}"
    echo "  ./map-machine.sh 38 machine_38"
    echo "  ./map-machine.sh 5 cherry_master_05"
    echo "  ./map-machine.sh 12 slot_machine_12"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo "  --list    Show current mappings"
    echo "  --help    Show this help"
    echo "  --backup  Create backup before changes"
    exit 1
}

# Handle options
case "$1" in
    --list)
        exec ./list-mappings.sh
        ;;
    --help)
        show_usage
        ;;
    --backup)
        if [ -f "$MAPPING_FILE" ]; then
            cp "$MAPPING_FILE" "$BACKUP_FILE"
            echo -e "${GREEN}✅ Backup created:${NC} $BACKUP_FILE"
        else
            echo -e "${YELLOW}⚠️  No mapping file exists to backup${NC}"
        fi
        exit 0
        ;;
esac

# Validate input
if [ -z "$FLEDGLING_NUMBER" ] || [ -z "$MACHINE_ID" ]; then
    echo -e "${RED}❌ Error: Missing required parameters${NC}"
    show_usage
fi

# Validate fledgling number is numeric and in range
if ! [[ "$FLEDGLING_NUMBER" =~ ^[0-9]+$ ]] || [ "$FLEDGLING_NUMBER" -lt 1 ] || [ "$FLEDGLING_NUMBER" -gt 63 ]; then
    echo -e "${RED}❌ Error: Fledgling number must be between 1-63${NC}"
    exit 1
fi

# Validate machine ID format (basic alphanumeric with underscores/dashes)
if ! [[ "$MACHINE_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "${RED}❌ Error: Machine ID can only contain letters, numbers, underscores, and dashes${NC}"
    exit 1
fi

FLEDGLING_PADDED=$(printf "%02d" "$FLEDGLING_NUMBER")

echo -e "${BLUE}🔗 Mapping Fledgling #${FLEDGLING_PADDED} to Machine ID: ${MACHINE_ID}${NC}"

# Create backup before making changes
if [ -f "$MAPPING_FILE" ]; then
    cp "$MAPPING_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✅ Backup created automatically${NC}"
fi

# Load environment
if [ -f "/opt/gambino-pi/.env" ]; then
    source /opt/gambino-pi/.env
    echo -e "${GREEN}✅ Environment loaded${NC}"
else
    echo -e "${YELLOW}⚠️  No .env file found, using defaults${NC}"
fi

# Create directories if they don't exist
mkdir -p "$(dirname "$MAPPING_FILE")"

# Create or update mapping with validation
node -e "
const fs = require('fs');
let mapping = {};
let isUpdate = false;

try {
    if (fs.existsSync('$MAPPING_FILE')) {
        mapping = JSON.parse(fs.readFileSync('$MAPPING_FILE', 'utf8'));
        isUpdate = true;
        console.log('📖 Loaded existing mappings');
    } else {
        mapping = {
            storeId: process.env.STORE_ID || '',
            hubId: process.env.MACHINE_ID || '',
            version: '1.0.0',
            machineMapping: {},
            created: new Date().toISOString()
        };
        console.log('📝 Creating new mapping file');
    }

    // Check for existing mapping
    const existingMapping = mapping.machineMapping && mapping.machineMapping['$FLEDGLING_PADDED'];
    if (existingMapping && existingMapping !== '$MACHINE_ID') {
        console.log('⚠️  Warning: Fledgling $FLEDGLING_PADDED was previously mapped to: ' + existingMapping);
        console.log('🔄 Updating to new mapping: $MACHINE_ID');
    }

    // Check for duplicate machine IDs
    const duplicateKey = Object.keys(mapping.machineMapping || {}).find(key => 
        mapping.machineMapping[key] === '$MACHINE_ID' && key !== '$FLEDGLING_PADDED'
    );
    
    if (duplicateKey) {
        console.log('⚠️  Warning: Machine ID \"$MACHINE_ID\" was previously assigned to Fledgling ' + duplicateKey);
        console.log('🔄 This will create a duplicate mapping');
    }

    // Update mapping
    if (!mapping.machineMapping) mapping.machineMapping = {};
    mapping.machineMapping['$FLEDGLING_PADDED'] = '$MACHINE_ID';
    mapping.lastUpdated = new Date().toISOString();
    mapping.totalMappings = Object.keys(mapping.machineMapping).length;

    // Write atomically
    fs.writeFileSync('$MAPPING_FILE.tmp', JSON.stringify(mapping, null, 2));
    fs.renameSync('$MAPPING_FILE.tmp', '$MAPPING_FILE');
    
    console.log('✅ Mapping saved: $FLEDGLING_PADDED → $MACHINE_ID');
    console.log('📊 Total mappings: ' + mapping.totalMappings);
    
} catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
}
" || {
    echo -e "${RED}❌ Failed to update mapping file${NC}"
    if [ -f "$BACKUP_FILE" ]; then
        echo -e "${YELLOW}🔄 Restoring from backup...${NC}"
        cp "$BACKUP_FILE" "$MAPPING_FILE"
    fi
    exit 1
}

echo ""
echo -e "${BLUE}📋 Current Status:${NC}"
./list-mappings.sh

echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Restart service: ${BLUE}sudo systemctl restart gambino-pi${NC}"
echo "2. Check logs: ${BLUE}sudo journalctl -u gambino-pi -f${NC}"
echo "3. Test mapping: ${BLUE}npm run test-serial${NC}"

# Offer to restart service
read -p "Restart gambino-pi service now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🔄 Restarting service...${NC}"
    sudo systemctl restart gambino-pi
    sleep 2
    echo -e "${GREEN}✅ Service restarted${NC}"
    echo -e "${BLUE}📊 Service status:${NC}"
    sudo systemctl status gambino-pi --no-pager -l
fi