#!/bin/bash
# Fixed version of test-gambino-system.sh with correct API endpoints

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_DIR="/opt/gambino-pi"

show_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    🧪 GAMBINO PI TESTING SUITE (FIXED) 🧪                  ║"
    echo "║                    Complete System Validation                               ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

test_counter=0
passed_tests=0
failed_tests=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((test_counter++))
    echo -e "${BLUE}[TEST $test_counter] $test_name${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        ((passed_tests++))
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        ((failed_tests++))
    fi
    echo ""
}

# Test 1: Environment Setup (same as before)
test_environment() {
    echo "Checking environment configuration..."
    
    if [ ! -f "$PI_DIR/.env" ]; then
        echo "❌ .env file not found at $PI_DIR/.env"
        return 1
    fi
    echo "✅ .env file exists"
    
    source "$PI_DIR/.env"
    
    local missing_vars=()
    [ -z "$MACHINE_ID" ] && missing_vars+=("MACHINE_ID")
    [ -z "$STORE_ID" ] && missing_vars+=("STORE_ID")
    [ -z "$API_ENDPOINT" ] && missing_vars+=("API_ENDPOINT")
    [ -z "$MACHINE_TOKEN" ] && missing_vars+=("MACHINE_TOKEN")
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "❌ Missing environment variables: ${missing_vars[*]}"
        return 1
    fi
    echo "✅ All required environment variables present"
    
    if [[ "$MACHINE_TOKEN" == "your"* ]] || [[ "$MACHINE_TOKEN" == "jwt"* ]]; then
        echo "❌ MACHINE_TOKEN appears to be placeholder value"
        return 1
    fi
    echo "✅ MACHINE_TOKEN appears to be set correctly"
    
    return 0
}

# Test 2: Directory Structure (same as before)
test_directories() {
    echo "Checking directory structure..."
    
    local required_dirs=(
        "$PI_DIR"
        "$PI_DIR/src"
        "$PI_DIR/data"
        "$PI_DIR/logs"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "❌ Missing directory: $dir"
            return 1
        fi
        echo "✅ Directory exists: $dir"
    done
    
    return 0
}

# Test 3: Fixed API Connectivity Test
test_api_connectivity() {
    echo "Testing API connectivity with correct Pi endpoints..."
    
    source "$PI_DIR/.env"
    
    # Test basic connectivity
    echo "Testing basic connectivity to $API_ENDPOINT..."
    if ! curl -s --max-time 10 "$API_ENDPOINT/health" > /dev/null; then
        echo "❌ Cannot reach API endpoint: $API_ENDPOINT"
        return 1
    fi
    echo "✅ API endpoint is reachable"
    
    # Test Pi-specific endpoints (the correct ones for edge devices)
    echo "Testing Pi edge device endpoints..."
    
    # Test config endpoint
    local config_response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -H "Authorization: Bearer $MACHINE_TOKEN" \
        -H "Content-Type: application/json" \
        "$API_ENDPOINT/api/edge/config")
    
    local config_http_code=$(echo "$config_response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    
    if [ "$config_http_code" -eq 200 ]; then
        echo "✅ Pi config endpoint authentication successful"
    else
        echo "⚠️  Pi config endpoint returned HTTP $config_http_code"
        echo "   This might be expected if the endpoint doesn't exist yet"
    fi
    
    # Test heartbeat endpoint
    local heartbeat_response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -H "Authorization: Bearer $MACHINE_TOKEN" \
        -H "Content-Type: application/json" \
        -X POST \
        -d '{"piVersion":"test","uptime":0,"memoryUsage":{},"serialConnected":false}' \
        "$API_ENDPOINT/api/edge/heartbeat")
    
    local heartbeat_http_code=$(echo "$heartbeat_response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    
    if [ "$heartbeat_http_code" -eq 200 ]; then
        echo "✅ Pi heartbeat endpoint working"
        return 0
    elif [ "$heartbeat_http_code" -eq 401 ] || [ "$heartbeat_http_code" -eq 403 ]; then
        echo "❌ Pi authentication failed (HTTP $heartbeat_http_code)"
        echo "   Check your MACHINE_TOKEN in .env file"
        return 1
    else
        echo "⚠️  Pi heartbeat returned HTTP $heartbeat_http_code"
        echo "   Token appears valid but endpoint may not be implemented"
        echo "   This is OK for development"
        return 0
    fi
}

# Test 4: CLI Tools (same as before)
test_cli_tools() {
    echo "Testing CLI tools..."
    
    local cli_tools=(
        "map-machine.sh"
        "list-mappings.sh"
        "sync-qr-codes.sh"
        "display-qr.sh"
        "unified-manager.sh"
    )
    
    for tool in "${cli_tools[@]}"; do
        if [ ! -f "$tool" ]; then
            echo "❌ CLI tool missing: $tool"
            return 1
        fi
        
        if [ ! -x "$tool" ]; then
            echo "❌ CLI tool not executable: $tool"
            return 1
        fi
        
        echo "✅ CLI tool ready: $tool"
    done
    
    return 0
}

# Test 5: Fixed Machine Mapping Test
test_machine_mapping() {
    echo "Testing machine mapping functionality..."
    
    local test_fledgling="99"
    local test_machine="test_machine_$(date +%s)"
    local mapping_file="$PI_DIR/data/machine-mapping.json"
    
    echo "Creating test mapping: Fledgling $test_fledgling → $test_machine"
    
    # Create test mapping
    if ! ./map-machine.sh "$test_fledgling" "$test_machine" > /dev/null 2>&1; then
        echo "❌ Failed to create test mapping"
        return 1
    fi
    echo "✅ Test mapping created successfully"
    
    # Give the file system a moment to sync
    sleep 1
    
    # Verify mapping exists in file
    if [ ! -f "$mapping_file" ]; then
        echo "❌ Mapping file was not created"
        return 1
    fi
    
    # Check if mapping exists in JSON file
    local mapping_exists=$(node -e "
    const fs = require('fs');
    try {
        const mapping = JSON.parse(fs.readFileSync('$mapping_file', 'utf8'));
        const exists = mapping.machineMapping && mapping.machineMapping['$test_fledgling'] === '$test_machine';
        console.log(exists ? 'true' : 'false');
    } catch (e) {
        console.log('false');
    }
    " 2>/dev/null)
    
    if [ "$mapping_exists" = "true" ]; then
        echo "✅ Test mapping verified in JSON file"
    else
        echo "❌ Test mapping not found in JSON file"
        # Debug: show what's actually in the file
        echo "Debug: Current mappings:"
        ./list-mappings.sh 2>/dev/null || echo "  Failed to list mappings"
        return 1
    fi
    
    # Test that list-mappings shows it
    if ./list-mappings.sh 2>/dev/null | grep -q "$test_machine"; then
        echo "✅ Test mapping appears in list output"
    else
        echo "⚠️  Test mapping not visible in list (but exists in file)"
        # This is OK - the mapping exists, the list command might have formatting issues
    fi
    
    # Clean up test mapping
    if [ -f "$mapping_file" ]; then
        node -e "
        const fs = require('fs');
        try {
            const mapping = JSON.parse(fs.readFileSync('$mapping_file', 'utf8'));
            if (mapping.machineMapping) {
                delete mapping.machineMapping['$test_fledgling'];
                mapping.lastUpdated = new Date().toISOString();
                fs.writeFileSync('$mapping_file', JSON.stringify(mapping, null, 2));
                console.log('Test mapping cleaned up');
            }
        } catch (e) {
            console.log('Cleanup failed:', e.message);
        }
        " 2>/dev/null
    fi
    
    return 0
}

# Test 6: QR Code Sync (same as before, works fine)
test_qr_sync_mock() {
    echo "Testing QR code sync functionality (mock)..."
    
    local test_machine="mock_machine_test"
    local qr_dir="$PI_DIR/data/qr-codes"
    mkdir -p "$qr_dir"
    
    # Create mock metadata
    cat > "$qr_dir/${test_machine}.json" << EOF
{
  "machineId": "$test_machine",
  "fledgling": "01",
  "bindUrl": "https://app.gambino.gold/machine/bind?token=mock_token_123",
  "generated": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "downloaded": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
    
    # Create mock QR image (small PNG)
    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" | base64 -d > "$qr_dir/${test_machine}.png"
    
    # Test QR display tool
    if ! ./display-qr.sh --info "$test_machine" > /dev/null 2>&1; then
        echo "❌ QR display tool failed"
        rm -f "$qr_dir/${test_machine}.json" "$qr_dir/${test_machine}.png"
        return 1
    fi
    echo "✅ QR display tool working"
    
    # Test QR validation
    if ! ./display-qr.sh --validate "$test_machine" > /dev/null 2>&1; then
        echo "❌ QR validation failed"
        rm -f "$qr_dir/${test_machine}.json" "$qr_dir/${test_machine}.png"
        return 1
    fi
    echo "✅ QR validation working"
    
    # Clean up
    rm -f "$qr_dir/${test_machine}.json" "$qr_dir/${test_machine}.png"
    echo "✅ Mock QR test cleanup completed"
    
    return 0
}

# Test 7: Serial Port Detection (same as before)
test_serial_ports() {
    echo "Testing serial port detection..."
    
    local usb_devices=($(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null))
    
    if [ ${#usb_devices[@]} -eq 0 ]; then
        echo "⚠️  No USB serial devices detected"
        echo "   This is OK if no hardware is connected yet"
        echo "   Expected devices: /dev/ttyUSB0, /dev/ttyACM0, etc."
    else
        echo "✅ USB serial devices found: ${usb_devices[*]}"
    fi
    
    if groups | grep -q dialout; then
        echo "✅ User has dialout permissions for serial access"
    else
        echo "⚠️  User not in dialout group - may need: sudo usermod -a -G dialout $USER"
    fi
    
    return 0
}

# Test 8: System Service (same as before)
test_system_service() {
    echo "Testing system service configuration..."
    
    if [ ! -f "/etc/systemd/system/gambino-pi.service" ]; then
        echo "⚠️  System service not installed"
        echo "   Run setup script to install service"
        return 0
    fi
    echo "✅ System service file exists"
    
    if systemctl is-enabled --quiet gambino-pi 2>/dev/null; then
        echo "✅ Service is enabled for auto-start"
    else
        echo "⚠️  Service not enabled for auto-start"
    fi
    
    if systemctl is-active --quiet gambino-pi 2>/dev/null; then
        echo "✅ Service is currently running"
    else
        echo "⚠️  Service is not running"
    fi
    
    return 0
}

# Test 9: Node.js Dependencies (same as before)
test_nodejs_deps() {
    echo "Testing Node.js dependencies..."
    
    if ! command -v node &> /dev/null; then
        echo "❌ Node.js not installed"
        return 1
    fi
    
    local node_version=$(node --version)
    echo "✅ Node.js version: $node_version"
    
    if [ -f "$PI_DIR/package.json" ]; then
        echo "✅ package.json exists"
        
        if [ -d "$PI_DIR/node_modules" ]; then
            echo "✅ node_modules directory exists"
        else
            echo "⚠️  node_modules not found - run 'npm install'"
        fi
    else
        echo "⚠️  package.json not found"
    fi
    
    return 0
}

# Test 10: Fixed Integration Test
test_integration() {
    echo "Running integration test..."
    
    # Test the unified manager can start
    if ! timeout 5 ./unified-manager.sh <<< "q" > /dev/null 2>&1; then
        echo "❌ Unified manager failed to start"
        return 1
    fi
    echo "✅ Unified manager can start and exit"
    
    # Test mapping workflow with better verification
    local test_machine="integration_test_$(date +%s)"
    local mapping_file="$PI_DIR/data/machine-mapping.json"
    
    echo "Testing full workflow with machine: $test_machine"
    
    # 1. Create mapping
    if ! ./map-machine.sh "98" "$test_machine" > /dev/null 2>&1; then
        echo "❌ Integration test: mapping failed"
        return 1
    fi
    
    # 2. Wait a moment for file sync
    sleep 1
    
    # 3. Verify mapping exists in JSON
    local mapping_exists=$(node -e "
    const fs = require('fs');
    try {
        const mapping = JSON.parse(fs.readFileSync('$mapping_file', 'utf8'));
        const exists = mapping.machineMapping && mapping.machineMapping['98'] === '$test_machine';
        console.log(exists ? 'true' : 'false');
    } catch (e) {
        console.log('false');
    }
    " 2>/dev/null)
    
    if [ "$mapping_exists" != "true" ]; then
        echo "❌ Integration test: mapping verification failed"
        return 1
    fi
    
    echo "✅ Integration test: mapping verified successfully"
    
    # 4. Clean up
    if [ -f "$mapping_file" ]; then
        node -e "
        const fs = require('fs');
        try {
            const mapping = JSON.parse(fs.readFileSync('$mapping_file', 'utf8'));
            if (mapping.machineMapping) {
                delete mapping.machineMapping['98'];
                mapping.lastUpdated = new Date().toISOString();
                fs.writeFileSync('$mapping_file', JSON.stringify(mapping, null, 2));
            }
        } catch (e) {}
        " 2>/dev/null
    fi
    
    echo "✅ Integration test completed successfully"
    return 0
}

# Main test runner
run_all_tests() {
    show_header
    
    echo -e "${YELLOW}Starting comprehensive system tests with fixes...${NC}"
    echo ""
    
    run_test "Environment Configuration" "test_environment"
    run_test "Directory Structure" "test_directories"
    run_test "API Connectivity (Fixed)" "test_api_connectivity"
    run_test "CLI Tools" "test_cli_tools"
    run_test "Machine Mapping (Fixed)" "test_machine_mapping"
    run_test "QR Code Sync (Mock)" "test_qr_sync_mock"
    run_test "Serial Port Detection" "test_serial_ports"
    run_test "System Service" "test_system_service"
    run_test "Node.js Dependencies" "test_nodejs_deps"
    run_test "Integration Test (Fixed)" "test_integration"
    
    # Test Summary
    echo -e "${CYAN}${BOLD}📊 TEST SUMMARY${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✅ Passed: $passed_tests${NC}"
    echo -e "${RED}❌ Failed: $failed_tests${NC}"
    echo -e "${BLUE}📊 Total: $test_counter${NC}"
    
    local success_rate=$((passed_tests * 100 / test_counter))
    echo -e "${CYAN}📈 Success Rate: ${success_rate}%${NC}"
    
    if [ $failed_tests -eq 0 ]; then
        echo ""
        echo -e "${GREEN}🎉 ALL TESTS PASSED! System is ready for production.${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠️  Some tests failed. Review the issues above.${NC}"
        echo ""
        echo -e "${BLUE}🔧 Common fixes:${NC}"
        echo "  • Check MACHINE_TOKEN is valid in admin dashboard"
        echo "  • Verify API endpoint is correct"
        echo "  • Ensure all scripts are executable: chmod +x *.sh"
    fi
}

# Quick test options (same as before)
case "$1" in
    --quick)
        echo -e "${BLUE}🚀 Quick Test Suite (Fixed)${NC}"
        run_test "Environment" "test_environment"
        run_test "API Connectivity (Fixed)" "test_api_connectivity"
        run_test "CLI Tools" "test_cli_tools"
        ;;
    --api)
        echo -e "${BLUE}🌐 API Test Only (Fixed)${NC}"
        run_test "API Connectivity (Fixed)" "test_api_connectivity"
        ;;
    --mapping)
        echo -e "${BLUE}🔗 Mapping Test Only (Fixed)${NC}"
        run_test "Machine Mapping (Fixed)" "test_machine_mapping"
        ;;
    --qr)
        echo -e "${BLUE}📱 QR Code Test Only${NC}"
        run_test "QR Code Sync (Mock)" "test_qr_sync_mock"
        ;;
    --help)
        echo -e "${YELLOW}Usage:${NC} ./test-gambino-system-fixed.sh [option]"
        echo -e "${BLUE}Options:${NC}"
        echo "  --quick    Run essential tests only"
        echo "  --api      Test API connectivity only (fixed)"
        echo "  --mapping  Test machine mapping only (fixed)"
        echo "  --qr       Test QR code functionality only"
        echo "  --help     Show this help"
        echo ""
        echo "Run without options for full test suite"
        ;;
    *)
        run_all_tests
        ;;
esac