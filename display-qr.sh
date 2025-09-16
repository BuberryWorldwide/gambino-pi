#!/bin/bash
# display-qr.sh - Display and manage QR codes on the Pi

QR_DIR="/opt/gambino-pi/data/qr-codes"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_usage() {
    echo -e "${YELLOW}Usage:${NC} ./display-qr.sh [options]"
    echo -e "${BLUE}Options:${NC}"
    echo "  --show <machine_id>     Display QR code in terminal"
    echo "  --url <machine_id>      Show bind URL for machine"
    echo "  --fledgling <number>    Display QR by fledgling number"
    echo "  --ascii <machine_id>    Show ASCII QR code"
    echo "  --info <machine_id>     Show QR code information"
    echo "  --validate <machine_id> Validate QR code"
    echo "  --all                   Show all QR codes info"
    echo "  --help                  Show this help"
    exit 1
}

# Convert machine ID to fledgling lookup
machine_to_fledgling() {
    local machine_id="$1"
    local mapping_file="/opt/gambino-pi/data/machine-mapping.json"
    
    if [ ! -f "$mapping_file" ]; then
        echo ""
        return 1
    fi
    
    node -e "
    const fs = require('fs');
    try {
        const mapping = JSON.parse(fs.readFileSync('$mapping_file', 'utf8'));
        const mappings = mapping.machineMapping || {};
        const fledgling = Object.keys(mappings).find(k => mappings[k] === '$machine_id');
        if (fledgling) {
            console.log(fledgling);
        }
    } catch (e) {
        // Silent fail
    }
    "
}

# Convert fledgling to machine ID lookup
fledgling_to_machine() {
    local fledgling="$1"
    local mapping_file="/opt/gambino-pi/data/machine-mapping.json"
    
    if [ ! -f "$mapping_file" ]; then
        echo ""
        return 1
    fi
    
    node -e "
    const fs = require('fs');
    try {
        const mapping = JSON.parse(fs.readFileSync('$mapping_file', 'utf8'));
        const mappings = mapping.machineMapping || {};
        if (mappings['$fledgling']) {
            console.log(mappings['$fledgling']);
        }
    } catch (e) {
        // Silent fail
    }
    "
}

# Display QR code as ASCII art (requires qrencode)
show_ascii_qr() {
    local machine_id="$1"
    local metadata_file="$QR_DIR/${machine_id}.json"
    
    if [ ! -f "$metadata_file" ]; then
        echo -e "${RED}❌ QR code not found for ${machine_id}${NC}"
        echo -e "${BLUE}💡 Run ./sync-qr-codes.sh --machine ${machine_id} first${NC}"
        return 1
    fi
    
    # Extract bind URL from metadata
    local bind_url=$(node -e "
    const data = JSON.parse(require('fs').readFileSync('$metadata_file', 'utf8'));
    console.log(data.bindUrl || '');
    " 2>/dev/null)
    
    if [ -n "$bind_url" ] && command -v qrencode &> /dev/null; then
        echo -e "${CYAN}📱 QR Code for Machine: ${machine_id}${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        qrencode -t ANSIUTF8 "$bind_url"
        echo ""
        echo -e "${BLUE}Bind URL:${NC} $bind_url"
    else
        echo -e "${YELLOW}⚠️  Cannot display ASCII QR code${NC}"
        if [ -z "$bind_url" ]; then
            echo "  Missing bind URL in metadata"
        fi
        if ! command -v qrencode &> /dev/null; then
            echo "  Install qrencode: sudo apt install qrencode"
        fi
    fi
}

# Show QR code information
show_qr_info() {
    local machine_id="$1"
    local metadata_file="$QR_DIR/${machine_id}.json"
    local png_file="$QR_DIR/${machine_id}.png"
    
    if [ ! -f "$metadata_file" ]; then
        echo -e "${RED}❌ QR code not found for ${machine_id}${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📋 QR Code Information: ${machine_id}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    node -e "
    const fs = require('fs');
    try {
        const data = JSON.parse(fs.readFileSync('$metadata_file', 'utf8'));
        
        console.log('📱 Machine Details:');
        console.log('  Machine ID: ' + (data.machineId || 'Unknown'));
        console.log('  Fledgling #: ' + (data.fledgling || 'Unknown'));
        console.log('');
        
        console.log('🔗 Binding Information:');
        console.log('  Bind URL: ' + (data.bindUrl || 'Not available'));
        console.log('');
        
        console.log('📅 Timestamps:');
        if (data.generated) {
            console.log('  Generated: ' + new Date(data.generated).toLocaleString());
        }
        if (data.downloaded) {
            console.log('  Downloaded: ' + new Date(data.downloaded).toLocaleString());
        }
        
    } catch (e) {
        console.log('❌ Error reading QR code metadata');
    }
    "
    
    # Show file information
    echo ""
    echo -e "${YELLOW}📁 File Information:${NC}"
    echo "  Metadata: $metadata_file"
    if [ -f "$png_file" ]; then
        echo "  QR Image: $png_file"
        local file_size=$(du -h "$png_file" | cut -f1)
        echo "  Size: $file_size"
    else
        echo "  QR Image: Not found"
    fi
    
    # Check for print-ready version
    local print_file="$QR_DIR/print-ready/${machine_id}_printable.png"
    if [ -f "$print_file" ]; then
        echo "  Print-ready: $print_file"
    fi
}

# Validate QR code
validate_qr() {
    local machine_id="$1"
    local metadata_file="$QR_DIR/${machine_id}.json"
    local png_file="$QR_DIR/${machine_id}.png"
    
    echo -e "${CYAN}🔍 Validating QR Code: ${machine_id}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local errors=0
    local warnings=0
    
    # Check if files exist
    if [ ! -f "$metadata_file" ]; then
        echo -e "${RED}❌ Metadata file missing${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✅ Metadata file exists${NC}"
    fi
    
    if [ ! -f "$png_file" ]; then
        echo -e "${RED}❌ QR image file missing${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✅ QR image file exists${NC}"
    fi
    
    # Validate metadata structure
    if [ -f "$metadata_file" ]; then
        local validation_result=$(node -e "
        const fs = require('fs');
        try {
            const data = JSON.parse(fs.readFileSync('$metadata_file', 'utf8'));
            
            const required = ['machineId', 'bindUrl', 'downloaded'];
            const missing = required.filter(field => !data[field]);
            
            if (missing.length > 0) {
                console.log('MISSING:' + missing.join(','));
            } else {
                console.log('VALID');
            }
            
            // Check URL format
            if (data.bindUrl && !data.bindUrl.startsWith('http')) {
                console.log('INVALID_URL');
            }
            
        } catch (e) {
            console.log('PARSE_ERROR');
        }
        ")
        
        if [[ "$validation_result" == *"MISSING:"* ]]; then
            local missing_fields=$(echo "$validation_result" | grep "MISSING:" | sed 's/MISSING://')
            echo -e "${RED}❌ Missing required fields: ${missing_fields}${NC}"
            ((errors++))
        elif [[ "$validation_result" == "PARSE_ERROR" ]]; then
            echo -e "${RED}❌ Invalid JSON in metadata file${NC}"
            ((errors++))
        elif [[ "$validation_result" == *"INVALID_URL"* ]]; then
            echo -e "${YELLOW}⚠️  Invalid bind URL format${NC}"
            ((warnings++))
        elif [[ "$validation_result" == "VALID" ]]; then
            echo -e "${GREEN}✅ Metadata structure is valid${NC}"
        fi
    fi
    
    # Check if machine is in mappings
    local fledgling=$(machine_to_fledgling "$machine_id")
    if [ -n "$fledgling" ]; then
        echo -e "${GREEN}✅ Machine found in mappings (Fledgling ${fledgling})${NC}"
    else
        echo -e "${YELLOW}⚠️  Machine not found in current mappings${NC}"
        ((warnings++))
    fi
    
    # Summary
    echo ""
    echo -e "${CYAN}📊 Validation Summary:${NC}"
    if [ "$errors" -eq 0 ] && [ "$warnings" -eq 0 ]; then
        echo -e "${GREEN}✅ QR code is valid and ready to use${NC}"
    elif [ "$errors" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  QR code is usable but has ${warnings} warning(s)${NC}"
    else
        echo -e "${RED}❌ QR code has ${errors} error(s) and ${warnings} warning(s)${NC}"
        echo -e "${BLUE}💡 Run ./sync-qr-codes.sh --machine ${machine_id} to re-download${NC}"
    fi
}

# Show all QR codes
show_all_qr_info() {
    echo -e "${CYAN}📋 All QR Codes Overview${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ ! -d "$QR_DIR" ] || [ -z "$(ls -A $QR_DIR/*.json 2>/dev/null)" ]; then
        echo -e "${YELLOW}📋 No QR codes found${NC}"
        echo -e "${BLUE}💡 Run ./sync-qr-codes.sh --all to download QR codes${NC}"
        return
    fi
    
    printf "%-15s %-20s %-10s %-12s\n" "Machine ID" "Bind URL" "Fledgling" "Status"
    printf "%-15s %-20s %-10s %-12s\n" "----------" "--------" "---------" "------"
    
    for metadata_file in "$QR_DIR"/*.json; do
        if [ -f "$metadata_file" ]; then
            local machine_id=$(basename "$metadata_file" .json)
            local png_file="$QR_DIR/${machine_id}.png"
            
            node -e "
            const fs = require('fs');
            try {
                const data = JSON.parse(fs.readFileSync('$metadata_file', 'utf8'));
                const machineId = data.machineId || 'Unknown';
                const fledgling = data.fledgling || 'N/A';
                const bindUrl = data.bindUrl || 'Missing';
                const hasImage = fs.existsSync('$png_file') ? 'OK' : 'Missing';
                
                const shortUrl = bindUrl.length > 20 ? bindUrl.substring(0, 17) + '...' : bindUrl;
                
                console.log(\`\${machineId.padEnd(15)} \${shortUrl.padEnd(20)} \${fledgling.padEnd(10)} \${hasImage}\`);
            } catch (e) {
                console.log(\`\${machine_id.padEnd(15)} Error reading file\`);
            }
            " machine_id="$machine_id"
        fi
    done
}

# Main execution
main() {
    case "$1" in
        --help)
            show_usage
            ;;
        --show|--ascii)
            if [ -z "$2" ]; then
                echo -e "${RED}❌ Machine ID required${NC}"
                exit 1
            fi
            show_ascii_qr "$2"
            ;;
        --url)
            if [ -z "$2" ]; then
                echo -e "${RED}❌ Machine ID required${NC}"
                exit 1
            fi
            local metadata_file="$QR_DIR/$2.json"
            if [ -f "$metadata_file" ]; then
                node -e "
                const data = JSON.parse(require('fs').readFileSync('$metadata_file', 'utf8'));
                console.log(data.bindUrl || 'URL not found');
                "
            else
                echo -e "${RED}❌ QR code not found for $2${NC}"
            fi
            ;;
        --fledgling)
            if [ -z "$2" ]; then
                echo -e "${RED}❌ Fledgling number required${NC}"
                exit 1
            fi
            local machine_id=$(fledgling_to_machine "$2")
            if [ -n "$machine_id" ]; then
                show_ascii_qr "$machine_id"
            else
                echo -e "${RED}❌ No machine mapped to fledgling $2${NC}"
            fi
            ;;
        --info)
            if [ -z "$2" ]; then
                echo -e "${RED}❌ Machine ID required${NC}"
                exit 1
            fi
            show_qr_info "$2"
            ;;
        --validate)
            if [ -z "$2" ]; then
                echo -e "${RED}❌ Machine ID required${NC}"
                exit 1
            fi
            validate_qr "$2"
            ;;
        --all)
            show_all_qr_info
            ;;
        "")
            show_usage
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_usage
            ;;
    esac
}

main "$@"