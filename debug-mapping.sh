#!/bin/bash
# debug-mapping.sh - Debug the mapping issue

PI_DIR="/opt/gambino-pi"
MAPPING_FILE="$PI_DIR/data/machine-mapping.json"

echo "🔍 Debugging Machine Mapping Issue"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "1. Current mapping file contents:"
if [ -f "$MAPPING_FILE" ]; then
    echo "File exists at: $MAPPING_FILE"
    echo "Raw JSON content:"
    cat "$MAPPING_FILE" | jq . 2>/dev/null || cat "$MAPPING_FILE"
else
    echo "❌ Mapping file does not exist!"
fi

echo ""
echo "2. Testing map-machine.sh behavior:"
test_machine="debug_test_$(date +%s)"
echo "Creating test mapping: 97 → $test_machine"

# Run map-machine.sh with verbose output
./map-machine.sh 97 "$test_machine"

echo ""
echo "3. Checking what was actually written:"
if [ -f "$MAPPING_FILE" ]; then
    echo "Fledgling 97 maps to:"
    node -e "
    const fs = require('fs');
    try {
        const mapping = JSON.parse(fs.readFileSync('$MAPPING_FILE', 'utf8'));
        console.log('Raw mapping object:');
        console.log(JSON.stringify(mapping.machineMapping, null, 2));
        console.log('');
        console.log('Value for key \"97\":', mapping.machineMapping['97']);
        console.log('Type of key \"97\":', typeof mapping.machineMapping['97']);
    } catch (e) {
        console.log('Error:', e.message);
    }
    "
fi

echo ""
echo "4. List mappings output:"
./list-mappings.sh

echo ""
echo "5. Manual cleanup of test mapping..."
if [ -f "$MAPPING_FILE" ]; then
    node -e "
    const fs = require('fs');
    try {
        const mapping = JSON.parse(fs.readFileSync('$MAPPING_FILE', 'utf8'));
        if (mapping.machineMapping && mapping.machineMapping['97']) {
            console.log('Found test mapping, removing...');
            delete mapping.machineMapping['97'];
            mapping.lastUpdated = new Date().toISOString();
            fs.writeFileSync('$MAPPING_FILE', JSON.stringify(mapping, null, 2));
            console.log('✅ Test mapping cleaned up');
        } else {
            console.log('No test mapping found to clean up');
        }
    } catch (e) {
        console.log('Cleanup error:', e.message);
    }
    "
fi

echo ""
echo "6. Analysis:"
echo "   Look at the output above to see if:"
echo "   - The machine ID we passed in matches what was written"
echo "   - There are any string formatting issues"
echo "   - The JSON structure is correct"