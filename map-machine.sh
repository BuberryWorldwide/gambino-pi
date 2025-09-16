#!/bin/bash
FLEDGLING_NUMBER=$1
MACHINE_ID=$2
MAPPING_FILE="/opt/gambino-pi/data/machine-mapping.json"

if [ -z "$FLEDGLING_NUMBER" ] || [ -z "$MACHINE_ID" ]; then
    echo "❌ Usage: ./map-machine.sh <fledgling_number> <machine_id>"
    echo "   Example: ./map-machine.sh 38 machine_38"
    exit 1
fi

FLEDGLING_PADDED=$(printf "%02d" "$FLEDGLING_NUMBER")
echo "🔗 Mapping Fledgling #${FLEDGLING_PADDED} to Machine ID: ${MACHINE_ID}"

# Load environment
if [ -f "/opt/gambino-pi/.env" ]; then
    source /opt/gambino-pi/.env
fi

# Create or update mapping
node -e "
const fs = require('fs');
let mapping = {};

if (fs.existsSync('$MAPPING_FILE')) {
    mapping = JSON.parse(fs.readFileSync('$MAPPING_FILE', 'utf8'));
} else {
    mapping = {
        storeId: process.env.STORE_ID || '',
        hubId: process.env.MACHINE_ID || '',
        version: '1.0.0',
        machineMapping: {}
    };
}

mapping.machineMapping['$FLEDGLING_PADDED'] = '$MACHINE_ID';
mapping.lastUpdated = new Date().toISOString();

fs.writeFileSync('$MAPPING_FILE', JSON.stringify(mapping, null, 2));
console.log('✅ Mapping created: $FLEDGLING_PADDED → $MACHINE_ID');
"

echo "🔄 Restart service: sudo systemctl restart gambino-pi"
