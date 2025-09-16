#!/bin/bash
# unified-manager.sh - One CLI tool to rule them all

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
    echo "║                            🎰 GAMBINO PI MANAGER 🎰                         ║"
    echo "║                         Edge Device Management CLI                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_main_menu() {
    echo -e "${BLUE}📋 Main Menu${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}1.${NC} 🔗 Machine Mapping"
    echo -e "${YELLOW}2.${NC} 🔧 Service Management"
    echo -e "${YELLOW}3.${NC} 📊 System Status"
    echo -e "${YELLOW}4.${NC} 🧪 Testing & Diagnostics"
    echo -e "${YELLOW}5.${NC} 📁 File Management"
    echo -e "${YELLOW}6.${NC} ⚙️  Configuration"
    echo -e "${YELLOW}7.${NC} 📋 Help & Documentation"
    echo -e "${YELLOW}q.${NC} 🚪 Quit"
    echo ""
}

show_mapping_menu() {
    echo -e "${BLUE}🔗 Machine Mapping Menu${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}1.${NC} 📋 List current mappings"
    echo -e "${YELLOW}2.${NC} ➕ Add new mapping"
    echo -e "${YELLOW}3.${NC} 🔍 Show mapping gaps"
    echo -e "${YELLOW}4.${NC} ✅ Validate mappings"
    echo -e "${YELLOW}5.${NC} 📤 Export mappings (CSV)"
    echo -e "${YELLOW}6.${NC} 🔄 Import mappings (CSV)"
    echo -e "${YELLOW}7.${NC} 💾 Backup mappings"
    echo -e "${YELLOW}8.${NC} 🗑️  Clear all mappings"
    echo -e "${YELLOW}b.${NC} 🔙 Back to main menu"
    echo ""
}

show_service_menu() {
    echo -e "${BLUE}🔧 Service Management Menu${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}1.${NC} 📊 Service status"
    echo -e "${YELLOW}2.${NC} ▶️  Start service"
    echo -e "${YELLOW}3.${NC} ⏹️  Stop service"
    echo -e "${YELLOW}4.${NC} 🔄 Restart service"
    echo -e "${YELLOW}5.${NC} 📜 View logs (live)"
    echo -e "${YELLOW}6.${NC} 📋 View recent logs"
    echo -e "${YELLOW}7.${NC} 🔁 Enable auto-start"
    echo -e "${YELLOW}8.${NC} ❌ Disable auto-start"
    echo -e "${YELLOW}b.${NC} 🔙 Back to main menu"
    echo ""
}

wait_for_enter() {
    echo ""
    read -p "Press Enter to continue..."
}

handle_mapping_menu() {
    while true; do
        show_header
        ./list-mappings.sh 2>/dev/null || echo -e "${YELLOW}No mappings found${NC}"
        echo ""
        show_mapping_menu
        
        read -p "Choose an option: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}📋 Current Mappings:${NC}"
                ./list-mappings.sh
                wait_for_enter
                ;;
            2)
                echo -e "${BLUE}➕ Add New Mapping${NC}"
                read -p "Fledgling number (1-63): " fledgling
                read -p "Machine ID: " machine_id
                if [ -n "$fledgling" ] && [ -n "$machine_id" ]; then
                    ./map-machine.sh "$fledgling" "$machine_id"
                else
                    echo -e "${RED}❌ Both fledgling number and machine ID are required${NC}"
                fi
                wait_for_enter
                ;;
            3)
                echo -e "${BLUE}🔍 Mapping Gaps:${NC}"
                ./list-mappings.sh --gaps
                wait_for_enter
                ;;
            4)
                echo -e "${BLUE}✅ Validation Report:${NC}"
                ./list-mappings.sh --validate
                wait_for_enter
                ;;
            5)
                echo -e "${BLUE}📤 Exporting Mappings:${NC}"
                ./list-mappings.sh --export > mappings_export_$(date +%Y%m%d_%H%M%S).csv
                echo -e "${GREEN}✅ Exported to mappings_export_$(date +%Y%m%d_%H%M%S).csv${NC}"
                wait_for_enter
                ;;
            6)
                echo -e "${BLUE}🔄 Import Mappings${NC}"
                read -p "CSV file path: " csv_file
                if [ -f "$csv_file" ]; then
                    echo "Import functionality would go here"
                    # TODO: Implement CSV import
                else
                    echo -e "${RED}❌ File not found${NC}"
                fi
                wait_for_enter
                ;;
            7)
                echo -e "${BLUE}💾 Creating Backup...${NC}"
                ./map-machine.sh --backup
                wait_for_enter
                ;;
            8)
                echo -e "${RED}🗑️  Clear All Mappings${NC}"
                echo -e "${YELLOW}⚠️  This will delete ALL machine mappings!${NC}"
                read -p "Type 'DELETE' to confirm: " confirm
                if [ "$confirm" = "DELETE" ]; then
                    rm -f "$PI_DIR/data/machine-mapping.json"
                    echo -e "${GREEN}✅ All mappings cleared${NC}"
                else
                    echo -e "${BLUE}Operation cancelled${NC}"
                fi
                wait_for_enter
                ;;
            b)
                break
                ;;
            *)
                echo -e "${RED}❌ Invalid option${NC}"
                wait_for_enter
                ;;
        esac
    done
}

handle_service_menu() {
    while true; do
        show_header
        echo -e "${BLUE}🔧 Service Management${NC}"
        echo ""
        
        # Show current service status
        if systemctl is-active --quiet gambino-pi; then
            echo -e "${GREEN}✅ Service is running${NC}"
        else
            echo -e "${RED}❌ Service is stopped${NC}"
        fi
        
        if systemctl is-enabled --quiet gambino-pi; then
            echo -e "${GREEN}✅ Auto-start enabled${NC}"
        else
            echo -e "${YELLOW}⚠️  Auto-start disabled${NC}"
        fi
        
        echo ""
        show_service_menu
        
        read -p "Choose an option: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}📊 Service Status:${NC}"
                sudo systemctl status gambino-pi --no-pager -l
                wait_for_enter
                ;;
            2)
                echo -e "${BLUE}▶️  Starting Service...${NC}"
                sudo systemctl start gambino-pi
                echo -e "${GREEN}✅ Service start command sent${NC}"
                wait_for_enter
                ;;
            3)
                echo -e "${BLUE}⏹️  Stopping Service...${NC}"
                sudo systemctl stop gambino-pi
                echo -e "${GREEN}✅ Service stop command sent${NC}"
                wait_for_enter
                ;;
            4)
                echo -e "${BLUE}🔄 Restarting Service...${NC}"
                sudo systemctl restart gambino-pi
                echo -e "${GREEN}✅ Service restart command sent${NC}"
                wait_for_enter
                ;;
            5)
                echo -e "${BLUE}📜 Live Logs (Ctrl+C to exit):${NC}"
                sudo journalctl -u gambino-pi -f
                ;;
            6)
                echo -e "${BLUE}📋 Recent Logs:${NC}"
                sudo journalctl -u gambino-pi -n 50 --no-pager
                wait_for_enter
                ;;
            7)
                echo -e "${BLUE}🔁 Enabling Auto-start...${NC}"
                sudo systemctl enable gambino-pi
                echo -e "${GREEN}✅ Auto-start enabled${NC}"
                wait_for_enter
                ;;
            8)
                echo -e "${BLUE}❌ Disabling Auto-start...${NC}"
                sudo systemctl disable gambino-pi
                echo -e "${GREEN}✅ Auto-start disabled${NC}"
                wait_for_enter
                ;;
            b)
                break
                ;;
            *)
                echo -e "${RED}❌ Invalid option${NC}"
                wait_for_enter
                ;;
        esac
    done
}

show_system_status() {
    show_header
    echo -e "${BLUE}📊 System Status${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # System info
    echo -e "${YELLOW}💻 System Information:${NC}"
    echo "  Hostname: $(hostname)"
    echo "  Uptime: $(uptime -p)"
    echo "  Load: $(uptime | awk -F'load average:' '{ print $2 }')"
    echo "  Memory: $(free -h | awk 'NR==2{printf "%.1f/%.1f GB (%.0f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')"
    echo "  Disk: $(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')"
    echo ""
    
    # Service status
    echo -e "${YELLOW}🔧 Service Status:${NC}"
    if systemctl is-active --quiet gambino-pi; then
        echo -e "  Status: ${GREEN}Running${NC}"
    else
        echo -e "  Status: ${RED}Stopped${NC}"
    fi
    
    if systemctl is-enabled --quiet gambino-pi; then
        echo -e "  Auto-start: ${GREEN}Enabled${NC}"
    else
        echo -e "  Auto-start: ${YELLOW}Disabled${NC}"
    fi
    echo ""
    
    # Mapping summary
    echo -e "${YELLOW}🔗 Mapping Summary:${NC}"
    if [ -f "$PI_DIR/data/machine-mapping.json" ]; then
        local count=$(./list-mappings.sh --count 2>/dev/null || echo "0")
        echo "  Configured machines: $count"
        
        # Show last update
        local last_update=$(node -e "
        try {
            const mapping = JSON.parse(require('fs').readFileSync('$PI_DIR/data/machine-mapping.json', 'utf8'));
            if (mapping.lastUpdated) {
                console.log(new Date(mapping.lastUpdated).toLocaleString());
            } else {
                console.log('Unknown');
            }
        } catch (e) {
            console.log('Unknown');
        }
        " 2>/dev/null)
        echo "  Last updated: $last_update"
    else
        echo "  Configured machines: 0"
    fi
    echo ""
    
    # Network status
    echo -e "${YELLOW}🌐 Network Status:${NC}"
    if ping -c 1 -W 2 api.gambino.gold &>/dev/null; then
        echo -e "  API connectivity: ${GREEN}OK${NC}"
    else
        echo -e "  API connectivity: ${RED}Failed${NC}"
    fi
    
    # Serial port status
    echo -e "${YELLOW}🔌 Serial Ports:${NC}"
    if ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null; then
        echo -e "  USB serial devices: ${GREEN}Found${NC}"
    else
        echo -e "  USB serial devices: ${YELLOW}None detected${NC}"
    fi
    
    wait_for_enter
}

# Main execution
main() {
    # Check if running in the right environment
    if [ ! -d "$PI_DIR" ] && [ ! -f "./map-machine.sh" ]; then
        echo -e "${RED}❌ Error: Gambino Pi environment not detected${NC}"
        echo "Please run this from the Pi installation directory or ensure system is set up"
        exit 1
    fi
    
    while true; do
        show_header
        show_main_menu
        
        read -p "Choose an option: " choice
        
        case $choice in
            1)
                handle_mapping_menu
                ;;
            2)
                handle_service_menu
                ;;
            3)
                show_system_status
                ;;
            4)
                echo -e "${BLUE}🧪 Testing & Diagnostics${NC}"
                echo "1. Test API connection"
                echo "2. Test serial port"
                echo "3. Run all tests"
                read -p "Choose test: " test_choice
                case $test_choice in
                    1) npm run test-api 2>/dev/null || echo "API test not available" ;;
                    2) npm run test-serial 2>/dev/null || echo "Serial test not available" ;;
                    3) npm run test 2>/dev/null || echo "Tests not available" ;;
                esac
                wait_for_enter
                ;;
            5)
                echo -e "${BLUE}📁 File Management${NC}"
                echo "Application directory: $PI_DIR"
                echo "Data files:"
                ls -la "$PI_DIR/data/" 2>/dev/null || echo "No data directory"
                echo "Log files:"
                ls -la "$PI_DIR/logs/" 2>/dev/null || echo "No logs directory"
                wait_for_enter
                ;;
            6)
                echo -e "${BLUE}⚙️  Configuration${NC}"
                if [ -f "$PI_DIR/.env" ]; then
                    echo "Current configuration:"
                    grep -v "TOKEN" "$PI_DIR/.env" 2>/dev/null || echo "Error reading .env"
                else
                    echo "No .env file found"
                fi
                wait_for_enter
                ;;
            7)
                echo -e "${BLUE}📋 Help & Documentation${NC}"
                echo ""
                echo -e "${YELLOW}Key Commands:${NC}"
                echo "  ./map-machine.sh <fledgling> <machine_id>  - Map a machine"
                echo "  ./list-mappings.sh                        - Show mappings"
                echo "  sudo systemctl status gambino-pi          - Check service"
                echo "  npm run test-serial                       - Test hardware"
                echo ""
                echo -e "${YELLOW}Important Files:${NC}"
                echo "  $PI_DIR/.env                              - Configuration"
                echo "  $PI_DIR/data/machine-mapping.json         - Machine mappings"
                echo "  $PI_DIR/logs/                             - Application logs"
                echo ""
                echo -e "${YELLOW}Documentation:${NC}"
                echo "  README.md in the application directory"
                wait_for_enter
                ;;
            q|Q)
                echo -e "${BLUE}👋 Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please try again.${NC}"
                wait_for_enter
                ;;
        esac
    done
}

# Run the main function
main "$@"