#!/bin/bash
# Enhanced list-mappings.sh - Better formatting and analysis

MAPPING_FILE="/opt/gambino-pi/data/machine-mapping.json"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_usage() {
    echo -e "${YELLOW}Usage:${NC} ./list-mappings.sh [options]"
    echo -e "${BLUE}Options:${NC}"
    echo "  --json     Output raw JSON"
    echo "  --count    Show count only"
    echo "  --gaps     Show missing fledgling numbers"
    echo "  --export   Export to CSV format"
    echo "  --validate Check for issues"
    exit 1
}

# Handle options
case "$1" in
    --help)
        show_usage
        ;;
    --json)
        if [ -f "$MAPPING_FILE" ]; then
            cat "$MAPPING_FILE" | jq . 2>/dev/null || cat "$MAPPING_FILE"
        else
            echo "{}"
        fi
        exit 0
        ;;
    --count)
        if [ -f "$MAPPING_FILE" ]; then
            node -e "
            const mapping = JSON.parse(require('fs').readFileSync('$MAPPING_FILE', 'utf8'));
            console.log(Object.keys(mapping.machineMapping || {}).length);
            " 2>/dev/null || echo "0"
        else
            echo "0"
        fi
        exit 0
        ;;
    --gaps)
        SHOW_GAPS=true
        ;;
    --export)
        EXPORT_CSV=true
        ;;
    --validate)
        VALIDATE=true
        ;;
esac

if [ ! -f "$MAPPING_FILE" ]; then
    echo -e "${YELLOW}📋 No mappings found.${NC}"
    echo -e "${BLUE}💡 Create your first mapping with:${NC} ./map-machine.sh <fledgling> <machine_id>"
    exit 0
fi

echo -e "${CYAN}📋 Current Machine Mappings${NC}"
echo -e "${CYAN}============================${NC}"

# Show metadata
node -e "
const fs = require('fs');
try {
    const mapping = JSON.parse(fs.readFileSync('$MAPPING_FILE', 'utf8'));
    
    console.log('');
    console.log('\x1b[34m📍 Configuration:\x1b[0m');
    console.log('  Store ID: ' + (mapping.storeId || 'Not set'));
    console.log('  Hub ID: ' + (mapping.hubId || 'Not set'));
    console.log('  Version: ' + (mapping.version || '1.0.0'));
    console.log('  Created: ' + (mapping.created ? new Date(mapping.created).toLocaleString() : 'Unknown'));
    console.log('  Last Updated: ' + (mapping.lastUpdated ? new Date(mapping.lastUpdated).toLocaleString() : 'Unknown'));
    console.log('');
    
    const mappings = mapping.machineMapping || {};
    const entries = Object.entries(mappings);
    
    if (entries.length === 0) {
        console.log('\x1b[33m📋 No machine mappings configured.\x1b[0m');
        process.exit(0);
    }
    
    console.log('\x1b[32m🔗 Machine Mappings (' + entries.length + ' total):\x1b[0m');
    console.log('  Fledgling → Machine ID');
    console.log('  ─────────────────────────');
    
    // Sort by fledgling number (numeric sort)
    entries
        .sort(([a], [b]) => parseInt(a) - parseInt(b))
        .forEach(([fledgling, machineId]) => {
            console.log('  ' + fledgling.padStart(2, '0') + '        → ' + machineId);
        });
    
    // Show gaps if requested
    if (process.env.SHOW_GAPS === 'true') {
        console.log('');
        console.log('\x1b[34m🔍 Gap Analysis:\x1b[0m');
        
        const usedNumbers = new Set(entries.map(([f]) => parseInt(f)));
        const maxNumber = Math.max(...usedNumbers);
        const gaps = [];
        
        for (let i = 1; i <= Math.max(maxNumber, 20); i++) {
            if (!usedNumbers.has(i)) {
                gaps.push(i.toString().padStart(2, '0'));
            }
        }
        
        if (gaps.length > 0) {
            console.log('  Available: ' + gaps.join(', '));
        } else {
            console.log('  All numbers 1-' + maxNumber + ' are assigned');
        }
    }
    
    // Export CSV if requested
    if (process.env.EXPORT_CSV === 'true') {
        console.log('');
        console.log('\x1b[34m📤 CSV Export:\x1b[0m');
        console.log('Fledgling,MachineID');
        entries
            .sort(([a], [b]) => parseInt(a) - parseInt(b))
            .forEach(([fledgling, machineId]) => {
                console.log(fledgling + ',' + machineId);
            });
    }
    
    // Validation if requested
    if (process.env.VALIDATE === 'true') {
        console.log('');
        console.log('\x1b[34m🔍 Validation Report:\x1b[0m');
        
        // Check for duplicates
        const machineIds = Object.values(mappings);
        const duplicates = machineIds.filter((id, index) => machineIds.indexOf(id) !== index);
        
        if (duplicates.length > 0) {
            console.log('\x1b[31m  ❌ Duplicate machine IDs found: ' + [...new Set(duplicates)].join(', ') + '\x1b[0m');
        } else {
            console.log('\x1b[32m  ✅ No duplicate machine IDs\x1b[0m');
        }
        
        // Check for invalid fledgling numbers
        const invalidFledglings = entries.filter(([f]) => {
            const num = parseInt(f);
            return isNaN(num) || num < 1 || num > 63;
        });
        
        if (invalidFledglings.length > 0) {
            console.log('\x1b[31m  ❌ Invalid fledgling numbers: ' + invalidFledglings.map(([f]) => f).join(', ') + '\x1b[0m');
        } else {
            console.log('\x1b[32m  ✅ All fledgling numbers valid (1-63)\x1b[0m');
        }
        
        // Check for empty machine IDs
        const emptyMachineIds = entries.filter(([_, id]) => !id || id.trim() === '');
        
        if (emptyMachineIds.length > 0) {
            console.log('\x1b[31m  ❌ Empty machine IDs for fledglings: ' + emptyMachineIds.map(([f]) => f).join(', ') + '\x1b[0m');
        } else {
            console.log('\x1b[32m  ✅ All machine IDs populated\x1b[0m');
        }
    }
    
} catch (error) {
    console.error('\x1b[31m❌ Error reading mapping file:\x1b[0m', error.message);
    process.exit(1);
}
" SHOW_GAPS="$SHOW_GAPS" EXPORT_CSV="$EXPORT_CSV" VALIDATE="$VALIDATE"

echo ""
echo -e "${BLUE}💡 Quick Commands:${NC}"
echo -e "  Map new machine: ${YELLOW}./map-machine.sh <fledgling> <machine_id>${NC}"
echo -e "  Show gaps: ${YELLOW}./list-mappings.sh --gaps${NC}"
echo -e "  Validate config: ${YELLOW}./list-mappings.sh --validate${NC}"
echo -e "  Export CSV: ${YELLOW}./list-mappings.sh --export${NC}"