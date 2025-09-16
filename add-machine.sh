#!/bin/bash

# Clean Machine Manager CLI - No fancy colors, just clean output
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
MACHINE_MAPPING_FILE="${DATA_DIR}/machine-mappings.json"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Simple banner
show_banner() {
    clear
    echo "==============================================="
    echo "      GAMBINO PI MACHINE MANAGER"
    echo "        Add & Configure Machines"
    echo "==============================================="
    echo ""
}

# Simple logger
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%H:%M:%S')
    echo "[$level] $timestamp - $message"
}

# Load environment
load_config() {
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        source "${SCRIPT_DIR}/.env"
        log "INFO" "Configuration loaded"
    fi
    
    MACHINE_ID=${MACHINE_ID:-"gambino-pi-$(hostname)"}
    STORE_ID=${STORE_ID:-"store_1755939573684"}
    API_ENDPOINT=${API_ENDPOINT:-"http://localhost:3000"}
}

# Check if mapping file exists
check_mapping_file() {
    if [ ! -f "$MACHINE_MAPPING_FILE" ]; then
        log "INFO" "Creating machine mapping file"
        echo '{}' > "$MACHINE_MAPPING_FILE"
    fi
}

# Add machine mapping using Node.js
add_machine_mapping() {
    local physical_id=$1
    local logical_id=$2
    local machine_name=$3
    local game_type=$4
    local location=$5
    
    echo "Adding mapping: Physical $physical_id -> $logical_id"
    
    node -e "
    const fs = require('fs');
    const path = '$MACHINE_MAPPING_FILE';
    
    let mappings = {};
    try {
        if (fs.existsSync(path)) {
            mappings = JSON.parse(fs.readFileSync(path, 'utf8'));
        }
    } catch (e) {
        console.error('Error reading mapping file:', e.message);
        mappings = {};
    }
    
    const entry = {
        physicalId: $physical_id,
        logicalId: '$logical_id',
        name: '$machine_name',
        gameType: '$game_type',
        location: '$location',
        storeId: '$STORE_ID',
        status: 'active',
        addedAt: new Date().toISOString(),
        lastSeen: null
    };
    
    mappings[$physical_id] = entry;
    
    fs.writeFileSync(path, JSON.stringify(mappings, null, 2));
    console.log('SUCCESS: Machine mapping added');
    "
    
    if [ $? -eq 0 ]; then
        log "INFO" "Machine mapping added successfully"
        return 0
    else
        log "ERROR" "Failed to add machine mapping"
        return 1
    fi
}

# Interactive machine configuration
configure_machine() {
    echo "Machine Configuration"
    echo "===================="
    echo ""
    
    # Physical machine number
    echo -n "Physical machine number (1-63): "
    read -r PHYSICAL_ID
    
    if [[ ! "$PHYSICAL_ID" =~ ^[1-9][0-9]?$|^6[0-3]$ ]]; then
        log "ERROR" "Invalid physical machine number. Must be 1-63."
        return 1
    fi
    
    # Check if already exists
    if node -e "
        const fs = require('fs');
        try {
            const mappings = JSON.parse(fs.readFileSync('$MACHINE_MAPPING_FILE', 'utf8'));
            if (mappings['$PHYSICAL_ID']) {
                console.log('EXISTS');
                process.exit(1);
            }
        } catch (e) {}
    " 2>/dev/null; then
        log "ERROR" "Physical ID $PHYSICAL_ID already exists"
        return 1
    fi
    
    # Logical machine ID
    echo -n "Logical machine ID (e.g., machine_01): "
    read -r LOGICAL_ID
    
    if [ -z "$LOGICAL_ID" ]; then
        log "ERROR" "Logical machine ID cannot be empty"
        return 1
    fi
    
    # Machine name
    echo -n "Machine name (optional): "
    read -r MACHINE_NAME
    MACHINE_NAME=${MACHINE_NAME:-"Machine $PHYSICAL_ID"}
    
    # Game type
    echo ""
    echo "Game types:"
    echo "1) slot"
    echo "2) poker" 
    echo "3) roulette"
    echo "4) edge (Pi device)"
    echo -n "Select game type (1-4): "
    read -r GAME_TYPE_CHOICE
    
    case $GAME_TYPE_CHOICE in
        1) GAME_TYPE="slot" ;;
        2) GAME_TYPE="poker" ;;
        3) GAME_TYPE="roulette" ;;
        4) GAME_TYPE="edge" ;;
        *) GAME_TYPE="slot" ;;
    esac
    
    # Location
    echo -n "Location (optional): "
    read -r LOCATION
    LOCATION=${LOCATION:-"Floor"}
    
    echo ""
    echo "Configuration Summary"
    echo "===================="
    echo "Physical ID: $PHYSICAL_ID"
    echo "Logical ID:  $LOGICAL_ID"
    echo "Name:        $MACHINE_NAME"
    echo "Game Type:   $GAME_TYPE"
    echo "Location:    $LOCATION"
    echo "Store ID:    $STORE_ID"
    echo ""
    
    echo -n "Confirm configuration? (y/N): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        return 0
    else
        log "INFO" "Configuration cancelled"
        return 1
    fi
}

# Add machine workflow
add_machine_workflow() {
    show_banner
    
    if configure_machine; then
        if add_machine_mapping "$PHYSICAL_ID" "$LOGICAL_ID" "$MACHINE_NAME" "$GAME_TYPE" "$LOCATION"; then
            echo ""
            echo "SUCCESS: Machine Added!"
            echo "Physical ID $PHYSICAL_ID is now mapped to $LOGICAL_ID"
            echo ""
            echo "Next Steps:"
            echo "1. Restart Pi app: npm run dev"
            echo "2. Test machine: Physical machine $PHYSICAL_ID should now work"
            echo "3. Check dashboard for events"
        fi
    fi
    
    echo ""
    echo -n "Press Enter to continue..."
    read -r
}

# List machines
list_machines() {
    show_banner
    echo "Configured Machines"
    echo "=================="
    echo ""
    
    if [ -f "$MACHINE_MAPPING_FILE" ] && [ -s "$MACHINE_MAPPING_FILE" ]; then
        node -e "
        const fs = require('fs');
        try {
            const mappings = JSON.parse(fs.readFileSync('$MACHINE_MAPPING_FILE', 'utf8'));
            
            console.log('Physical | Logical ID      | Name                 | Game Type | Location');
            console.log('---------|-----------------|----------------------|-----------|------------------');
            
            Object.values(mappings).forEach(m => {
                const physical = String(m.physicalId).padEnd(8);
                const logical = String(m.logicalId).substring(0, 15).padEnd(15);
                const name = String(m.name).substring(0, 20).padEnd(20);
                const gameType = String(m.gameType).padEnd(9);
                const location = String(m.location || '').substring(0, 18).padEnd(18);
                console.log(\`\${physical} | \${logical} | \${name} | \${gameType} | \${location}\`);
            });
        } catch (e) {
            console.log('Error reading mappings:', e.message);
        }
        "
    else
        echo "No machines configured yet."
        echo "Use option 1 to add your first machine."
    fi
    
    echo ""
    echo -n "Press Enter to continue..."
    read -r
}

# Remove machine
remove_machine() {
    show_banner
    echo "Remove Machine"
    echo "============="
    echo ""
    
    # Show current machines first
    echo "Current machines:"
    node -e "
    const fs = require('fs');
    try {
        const mappings = JSON.parse(fs.readFileSync('$MACHINE_MAPPING_FILE', 'utf8'));
        Object.values(mappings).forEach(m => {
            console.log(\`Physical \${m.physicalId}: \${m.logicalId} (\${m.name})\`);
        });
    } catch (e) {
        console.log('No machines found');
    }
    "
    
    echo ""
    echo -n "Enter physical machine ID to remove: "
    read -r PHYSICAL_ID
    
    # Remove using Node.js
    if node -e "
        const fs = require('fs');
        try {
            const mappings = JSON.parse(fs.readFileSync('$MACHINE_MAPPING_FILE', 'utf8'));
            if (mappings['$PHYSICAL_ID']) {
                console.log('Machine to remove:', mappings['$PHYSICAL_ID'].name);
                process.exit(0);
            } else {
                console.log('Machine not found');
                process.exit(1);
            }
        } catch (e) {
            console.log('Error:', e.message);
            process.exit(1);
        }
    "; then
        echo -n "Confirm removal? (y/N): "
        read -r confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            node -e "
            const fs = require('fs');
            try {
                const mappings = JSON.parse(fs.readFileSync('$MACHINE_MAPPING_FILE', 'utf8'));
                delete mappings['$PHYSICAL_ID'];
                fs.writeFileSync('$MACHINE_MAPPING_FILE', JSON.stringify(mappings, null, 2));
                console.log('Machine removed successfully');
            } catch (e) {
                console.log('Error removing machine:', e.message);
            }
            "
        else
            log "INFO" "Removal cancelled"
        fi
    fi
    
    echo ""
    echo -n "Press Enter to continue..."
    read -r
}

# Test mapping
test_mapping() {
    show_banner
    echo "Test Machine Mapping"
    echo "==================="
    echo ""
    
    echo -n "Enter physical machine ID to test: "
    read -r PHYSICAL_ID
    
    node -e "
    const fs = require('fs');
    try {
        const mappings = JSON.parse(fs.readFileSync('$MACHINE_MAPPING_FILE', 'utf8'));
        const machine = mappings['$PHYSICAL_ID'];
        if (machine) {
            console.log('FOUND:');
            console.log('Physical ID:', machine.physicalId);
            console.log('Logical ID:', machine.logicalId);
            console.log('Name:', machine.name);
            console.log('Game Type:', machine.gameType);
            console.log('Location:', machine.location);
            console.log('Status:', machine.status);
        } else {
            console.log('Machine not found');
        }
    } catch (e) {
        console.log('Error:', e.message);
    }
    "
    
    echo ""
    echo -n "Press Enter to continue..."
    read -r
}

# System info
system_info() {
    show_banner
    echo "System Information"
    echo "================="
    echo ""
    
    echo "Configuration:"
    echo "- Machine ID: $MACHINE_ID"
    echo "- Store ID: $STORE_ID" 
    echo "- API Endpoint: $API_ENDPOINT"
    echo ""
    
    echo "Files:"
    if [ -f "$MACHINE_MAPPING_FILE" ]; then
        echo "- Mapping file: EXISTS"
        MACHINE_COUNT=$(node -e "
            const fs = require('fs');
            try {
                const mappings = JSON.parse(fs.readFileSync('$MACHINE_MAPPING_FILE', 'utf8'));
                console.log(Object.keys(mappings).length);
            } catch (e) { console.log(0); }
        ")
        echo "- Configured machines: $MACHINE_COUNT"
    else
        echo "- Mapping file: MISSING"
    fi
    
    echo ""
    echo -n "Press Enter to continue..."
    read -r
}

# Main menu
main_menu() {
    while true; do
        show_banner
        
        echo "Select an option:"
        echo ""
        echo "  1. Add new machine"
        echo "  2. List configured machines"  
        echo "  3. Remove machine"
        echo "  4. Test machine mapping"
        echo "  5. System information"
        echo "  6. Exit"
        echo ""
        echo -n "Choice (1-6): "
        read -r choice
        
        case $choice in
            1) add_machine_workflow ;;
            2) list_machines ;;
            3) remove_machine ;;
            4) test_mapping ;;
            5) system_info ;;
            6) 
                echo "Goodbye!"
                exit 0
                ;;
            *) 
                echo "Invalid choice. Please select 1-6."
                sleep 2
                ;;
        esac
    done
}

# Main execution
main() {
    load_config
    check_mapping_file
    main_menu
}

# Handle arguments
case "${1:-}" in
    --help|-h)
        echo "Gambino Pi Machine Manager"
        echo "Usage: $0 [--help]"
        exit 0
        ;;
    *)
        main
        ;;
esac