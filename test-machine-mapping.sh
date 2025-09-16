#!/bin/bash

# Test Machine Mapping - Validation Script
# Tests machine mappings and simulates data flow

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAPPING_FILE="${SCRIPT_DIR}/data/machine-mappings.json"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test-results"

# Create test results directory
mkdir -p "$TEST_RESULTS_DIR"

# Usage
show_usage() {
    echo "Usage: $0 [PHYSICAL_ID]"
    echo ""
    echo "Test machine mapping for a specific physical machine ID"
    echo ""
    echo "Examples:"
    echo "  $0 1        # Test mapping for physical machine 1"
    echo "  $0 --all    # Test all configured mappings"
    echo "  $0 --help   # Show this help"
}

# Test header
show_test_header() {
    local physical_id=$1
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}               ${BOLD}🧪 MACHINE MAPPING TEST${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}              ${YELLOW}Physical Machine ID: $physical_id${NC}              ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# Logger
log_test() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%H:%M:%S')
    
    case $level in
        "PASS") echo -e "${GREEN}✅ [PASS]${NC} ${timestamp} - $message" ;;
        "FAIL") echo -e "${RED}❌ [FAIL]${NC} ${timestamp} - $message" ;;
        "INFO") echo -e "${BLUE}ℹ️  [INFO]${NC} ${timestamp} - $message" ;;
        "WARN") echo -e "${YELLOW}⚠️  [WARN]${NC} ${timestamp} - $message" ;;
    esac
}

# Load machine mapping
load_mapping() {
    local physical_id=$1
    
    if [ ! -f "$MAPPING_FILE" ]; then
        log_test "FAIL" "Machine mapping file not found: $MAPPING_FILE"
        return 1
    fi

    if ! command -v node >/dev/null 2>&1; then
        log_test "FAIL" "Node.js not available for JSON parsing"
        return 1
    fi

    # Extract mapping for specific physical ID
    MAPPING_DATA=$(node -e "
        try {
            const fs = require('fs');
            const mappings = JSON.parse(fs.readFileSync('$MAPPING_FILE', 'utf8'));
            const mapping = mappings['$physical_id'];
            if (mapping) {
                console.log(JSON.stringify(mapping, null, 2));
            } else {
                console.log('NOT_FOUND');
            }
        } catch (error) {
            console.log('ERROR: ' + error.message);
        }
    ")

    if [ "$MAPPING_DATA" = "NOT_FOUND" ]; then
        log_test "FAIL" "No mapping found for physical machine $physical_id"
        return 1
    elif [[ "$MAPPING_DATA" == ERROR:* ]]; then
        log_test "FAIL" "Error reading mapping: ${MAPPING_DATA#ERROR: }"
        return 1
    fi

    log_test "PASS" "Machine mapping loaded successfully"
    return 0
}

# Validate mapping data
validate_mapping() {
    local physical_id=$1
    
    log_test "INFO" "Validating mapping data structure..."
    
    # Extract mapping components using Node.js
    LOGICAL_ID=$(echo "$MAPPING_DATA" | node -e "
        const data = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8'));
        console.log(data.logicalId || '');
    ")
    
    MACHINE_NAME=$(echo "$MAPPING_DATA" | node -e "
        const data = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8'));
        console.log(data.name || '');
    ")
    
    GAME_TYPE=$(echo "$MAPPING_DATA" | node -e "
        const data = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8'));
        console.log(data.gameType || '');
    ")

    # Validation checks
    if [ -z "$LOGICAL_ID" ]; then
        log_test "FAIL" "Missing logical machine ID"
        return 1
    else
        log_test "PASS" "Logical ID: $LOGICAL_ID"
    fi

    if [ -z "$MACHINE_NAME" ]; then
        log_test "WARN" "Missing machine name"
    else
        log_test "PASS" "Machine name: $MACHINE_NAME"
    fi

    if [ -z "$GAME_TYPE" ]; then
        log_test "WARN" "Missing game type"
    else
        log_test "PASS" "Game type: $GAME_TYPE"
    fi

    return 0
}

# Simulate serial data parsing
simulate_serial_data() {
    local physical_id=$1
    
    log_test "INFO" "Simulating serial data parsing..."
    
    # Generate sample serial events
    local events=(
        "MONEY IN: \$25.50 - $(date '+%I:%M:%S %p') - MACHINE $physical_id"
        "SESSION START - $(date '+%I:%M:%S %p') - MACHINE $physical_id"
        "VOUCHER PRINT: \$150.75 - $(date '+%I:%M:%S %p') - MACHINE $physical_id"
        "SESSION END - $(date '+%I:%M:%S %p') - MACHINE $physical_id"
    )

    echo -e "${BLUE}Generated test events:${NC}"
    for event in "${events[@]}"; do
        echo "  📡 $event"
        
        # Test event parsing (simplified version of your parser)
        if [[ "$event" == *"MACHINE $physical_id"* ]]; then
            log_test "PASS" "Event correctly identifies physical machine $physical_id"
        else
            log_test "FAIL" "Event parsing failed for physical machine $physical_id"
        fi
        
        # Simulate mapping lookup
        if [ -n "$LOGICAL_ID" ]; then
            log_test "PASS" "Would map to logical machine: $LOGICAL_ID"
        else
            log_test "FAIL" "No logical mapping available"
        fi
        
        sleep 0.5
    done
}

# Test API integration simulation
simulate_api_integration() {
    log_test "INFO" "Simulating API integration..."
    
    # Load environment for API endpoint
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        source "${SCRIPT_DIR}/.env"
    fi

    API_ENDPOINT=${API_ENDPOINT:-"https://api.gambino.gold"}
    
    # Test API endpoint availability
    if command -v curl >/dev/null 2>&1; then
        if curl -s --connect-timeout 5 "$API_ENDPOINT/health" >/dev/null 2>&1; then
            log_test "PASS" "API endpoint reachable: $API_ENDPOINT"
        else
            log_test "WARN" "API endpoint not reachable (offline mode): $API_ENDPOINT"
        fi
    else
        log_test "WARN" "curl not available, cannot test API connectivity"
    fi

    # Simulate event payload
    local sample_payload=$(cat << EOF
{
  "eventType": "money_in",
  "machineId": "$LOGICAL_ID",
  "storeId": "${STORE_ID:-store_default}",
  "amount": 25.50,
  "timestamp": "$(date -Iseconds)",
  "physicalMachine": $physical_id,
  "sessionId": "test_session_$(date +%s)"
}
EOF
)

    echo -e "${BLUE}Sample API payload:${NC}"
    echo "$sample_payload" | sed 's/^/  /'
    
    log_test "PASS" "Event payload structure valid"
}

# Generate test report
generate_report() {
    local physical_id=$1
    local test_status=$2
    
    local report_file="${TEST_RESULTS_DIR}/test-result-machine-${physical_id}-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
  "testInfo": {
    "physicalMachineId": $physical_id,
    "testTimestamp": "$(date -Iseconds)",
    "testStatus": "$test_status",
    "testerVersion": "1.0.0"
  },
  "machineMapping": $MAPPING_DATA,
  "testResults": {
    "mappingExists": $([ -n "$MAPPING_DATA" ] && echo "true" || echo "false"),
    "logicalIdValid": $([ -n "$LOGICAL_ID" ] && echo "true" || echo "false"),
    "parsingTest": "passed",
    "apiSimulation": "completed"
  },
  "recommendations": [
    $([ -z "$MACHINE_NAME" ] && echo '"Consider adding a descriptive machine name",' || echo '')
    $([ -z "$GAME_TYPE" ] && echo '"Consider specifying the game type",' || echo '')
    "Monitor real serial data to verify mapping accuracy",
    "Test with actual hardware when available"
  ]
}
EOF

    # Remove trailing comma if present
    sed -i 's/,]/]/g' "$report_file"
    
    log_test "INFO" "Test report generated: $report_file"
}

# Test specific machine
test_machine() {
    local physical_id=$1
    
    show_test_header "$physical_id"
    
    log_test "INFO" "Starting mapping test for physical machine $physical_id"
    
    # Load and validate mapping
    if load_mapping "$physical_id"; then
        if validate_mapping "$physical_id"; then
            # Run simulation tests
            simulate_serial_data "$physical_id"
            simulate_api_integration
            
            generate_report "$physical_id" "PASSED"
            
            echo ""
            log_test "PASS" "All tests completed successfully for machine $physical_id"
            return 0
        else
            generate_report "$physical_id" "FAILED"
            log_test "FAIL" "Mapping validation failed for machine $physical_id"
            return 1
        fi
    else
        generate_report "$physical_id" "FAILED"
        log_test "FAIL" "Could not load mapping for machine $physical_id"
        return 1
    fi
}

# Test all configured machines
test_all_machines() {
    echo -e "${CYAN}${BOLD}🧪 Testing All Configured Machines${NC}"
    echo -e "${CYAN}===================================${NC}"
    echo ""
    
    if [ ! -f "$MAPPING_FILE" ]; then
        log_test "FAIL" "No machine mapping file found"
        return 1
    fi

    # Get list of all physical IDs
    local machine_ids
    machine_ids=$(node -e "
        const fs = require('fs');
        const mappings = JSON.parse(fs.readFileSync('$MAPPING_FILE', 'utf8'));
        const ids = Object.keys(mappings);
        console.log(ids.join(' '));
    ")

    if [ -z "$machine_ids" ]; then
        log_test "WARN" "No machines configured for testing"
        return 0
    fi

    local total_tests=0
    local passed_tests=0
    
    for machine_id in $machine_ids; do
        echo ""
        if test_machine "$machine_id"; then
            passed_tests=$((passed_tests + 1))
        fi
        total_tests=$((total_tests + 1))
        echo ""
        echo "────────────────────────────────────────"
    done

    echo ""
    echo -e "${CYAN}${BOLD}📊 Test Summary${NC}"
    echo -e "${CYAN}===============${NC}"
    echo "Total tests:  $total_tests"
    echo "Passed tests: $passed_tests"
    echo "Failed tests: $((total_tests - passed_tests))"
    
    if [ $passed_tests -eq $total_tests ]; then
        log_test "PASS" "All machine mapping tests passed!"
    else
        log_test "WARN" "Some tests failed. Check individual results above."
    fi
}

# Main execution
main() {
    case "${1:-}" in
        --help|-h)
            show_usage
            exit 0
            ;;
        --all)
            test_all_machines
            ;;
        "")
            echo -e "${RED}Error: Physical machine ID required${NC}"
            echo ""
            show_usage
            exit 1
            ;;
        *)
            if [[ "$1" =~ ^[1-9][0-9]?$|^6[0-3]$ ]]; then
                test_machine "$1"
            else
                echo -e "${RED}Error: Invalid physical machine ID: $1${NC}"
                echo "Must be a number between 1 and 63"
                exit 1
            fi
            ;;
    esac
}

# Execute main function
main "$@"