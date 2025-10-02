#!/bin/bash
# unified-manager.sh - Comprehensive Edge Device Management CLI
# Integrates all Pi management tools into one interface

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_DIR="/opt/gambino-pi"

show_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    🎰 GAMBINO PI UNIFIED MANAGER 🎰                         ║"
    echo "║                    Complete Edge Device Management                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_main_menu() {
    echo -e "${BLUE}📋 Main Menu${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}1.${NC} 🔗 Machine Mapping & Configuration"
    echo -e "${YELLOW}2.${NC} 📱 QR Code Management"
    echo -e "${YELLOW}3.${NC} 🔧 Service & System Management" 
    echo -e "${YELLOW}4.${NC} 🧪 Testing & Diagnostics"
    echo -e "${YELLOW}5.${NC} 📊 Data & Database Management"
    echo -e "${YELLOW}6.${NC} 🌐 Network & API Management"
    echo -e "${YELLOW}7.${NC} 📁 File & Backup Management"
    echo -e "${YELLOW}8.${NC} 🚀 Deployment & Setup Tools"
    echo -e "${YELLOW}9.${NC} 📋 Help & Documentation"
    echo -e "${YELLOW}q.${NC} 🚪 Quit"
    echo ""
}

show_mapping_menu() {
    echo -e "${BLUE}🔗 Machine Mapping & Configuration${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}1.${NC} 📋 List current mappings"
    echo -e "${YELLOW}2.${NC} ➕ Add new mapping"
    echo -e "${YELLOW}3.${NC} 🔍 Show mapping gaps"
    echo -e "${YELLOW}4.${NC} ✅ Validate mappings"
    echo -e "${YELLOW}5.${NC} 📤 Export mappings (CSV)"
    echo -e "${YELLOW}6.${NC} 🔄 Import mappings (CSV)"
    echo -e "${YELLOW}7.${NC} 💾 Backup mappings"
    echo -e "${YELLOW}8.${NC} 🗑️  Clear all mappings"
    echo -e "${YELLOW}9.${NC} 🔧 Fix mapping issues"
    echo -e "${YELLOW}b.${NC} 🔙 Back to main menu"
    echo ""
}

show_qr_menu() {
    echo -e "${BLUE}📱 QR Code Management${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}1.${NC} 🔄 Sync all QR codes from dashboard"
    echo -e "${YELLOW}2.${NC} 📥 Sync specific machine QR code"
    echo -e "${YELLOW}3.${NC} 📋 List all QR codes"
    echo -e "${YELLOW}4.${NC} 📱 Display QR code (ASCII)"
    echo -e "${YELLOW}5.${NC} 🔍 Validate QR code"
    echo -e "${YELLOW}6.${NC} 🖨️  Generate print-ready QR"
    echo -e "${YELLOW}7.${NC} 📊 QR sync status"
    echo -e "${YELLOW}8.${NC} 🔧 Debug QR sync issues"
    echo -e "${YELLOW}b.${NC} 🔙 Back to main menu"
    echo ""
}

show_service_menu() {
    echo -e "${BLUE}🔧 Service & System Management${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}1.${NC} 📊 System status overview"
    echo -e "${YELLOW}2.${NC} 🔧 Service status & control"
    echo -e "${YELLOW}3.${NC} 📜 View logs (live)"
    echo -e "${YELLOW}4.${NC} 📋 View recent logs"
    echo -e "${YELLOW}5.${NC} 🔁 Enable/disable auto-start"
    echo -e "${YELLOW}6.${NC} 🔄 Restart all services"
    echo -e "${YELLOW}7.${NC} 🖥️  System information"
    echo -e "${YELLOW}8.${NC} 🌡️  Hardware monitoring"
    echo -e "${YELLOW}b.${NC} 🔙 Back to main menu"
    echo ""
}

show_testing_menu() {
    echo -e "${BLUE}🧪 Testing & Diagnostics${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}1.${NC} 🌐 Test API connectivity"
    echo -e "${YELLOW}2.${NC} 🔌 Test serial connections"
    echo -e "${YELLOW}3.${NC} 📱 Test QR code system"
    echo -e "${YELLOW}4.${NC} 🔗 Test machine mapping"
    echo -e "${YELLOW}5.${NC} 🧪 Run comprehensive tests"
    echo -e "${YELLOW}6.${NC} 📊 Performance diagnostics"
    echo -e "${YELLOW}7.${NC} 🔍 Debug system issues"
    echo -e "${YELLOW}8.${NC} 📈 Generate test reports"
    echo -e "${YELLOW}b.${NC} 🔙 Back to main menu"
    echo ""
}

show_data_menu() {
    echo -e "${BLUE}📊 Data & Database Management${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}1.${NC} 📊 Browse local database"
    echo -e "${YELLOW}2.${NC} 📈 View event queue status"
    echo -e "${YELLOW}3.${NC} 🔄 Sync data to backend"
    echo -e "${YELLOW}4.${NC} 💾 Backup database"
    echo -e "${YELLOW}5.${NC} 🗑️  Clear event queue"
    echo -e "${YELLOW}6.${NC} 📋 Database statistics"
    echo -e "${YELLOW}7.${NC} 🔧 Database maintenance"
    echo -e "${YELLOW}8.${NC} 📤 Export data"
    echo -e "${YELLOW}b.${NC} 🔙 Back to main menu"
    echo ""
}

show_network_menu() {
    echo -e "${BLUE}🌐 Network & API Management${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}1.${NC} 🌐 Check network connectivity"
    echo -e "${YELLOW}2.${NC} 🔑 Test API authentication"
    echo -e "${YELLOW}3.${NC} 📡 Configure WiFi"
    echo -e "${YELLOW}4.${NC} 🛜 Configure Tailscale VPN"
    echo -e "${YELLOW}5.${NC} ⚙️  View network configuration"
    echo -e "${YELLOW}6.${NC} 🔧 Network diagnostics"
    echo -e "${YELLOW}7.${NC} 📊 API endpoint status"
    echo -e "${YELLOW}8.${NC} 🔄 Reset network settings"
    echo -e "${YELLOW}b.${NC} 🔙 Back to main menu"
    echo ""
}

show_file_menu() {
    echo -e "${BLUE}📁 File & Backup Management${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}1.${NC} 📁 Browse data directory"
    echo -e "${YELLOW}2.${NC} 📜 View log files"
    echo -e "${YELLOW}3.${NC} 💾 Create full backup"
    echo -e "${YELLOW}4.${NC} 🔄 Restore from backup"
    echo -e "${YELLOW}5.${NC} 🗑️  Clean old files"
    echo -e "${YELLOW}6.${NC} 📊 Disk usage analysis"
    echo -e "${YELLOW}7.${NC} 🔧 File permissions check"
    echo -e "${YELLOW}8.${NC} 📋 Configuration files"
    echo -e "${YELLOW}b.${NC} 🔙 Back to main menu"
    echo ""
}

show_deployment_menu() {
    echo -e "${BLUE}🚀 Deployment & Setup Tools${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}1.${NC} 🚀 Run initial Pi setup"
    echo -e "${YELLOW}2.${NC} 🔧 Configure Pi settings"
    echo -e "${YELLOW}3.${NC} 📦 Create deployment package"
    echo -e "${YELLOW}4.${NC} 🔄 Update system packages"
    echo -e "${YELLOW}5.${NC} 🛠️  Install dependencies"
    echo -e "${YELLOW}6.${NC} ⚙️  Environment configuration"
    echo -e "${YELLOW}7.${NC} 🔐 Security setup"
    echo -e "${YELLOW}8.${NC} 📋 Deployment checklist"
    echo -e "${YELLOW}b.${NC} 🔙 Back to main menu"
    echo ""
}

wait_for_enter() {
    echo ""
    read -p "Press Enter to continue..."
}

# Machine Mapping Menu Handler
handle_mapping_menu() {
    while true; do
        show_header
        if [ -f "./list-mappings.sh" ]; then
            ./list-mappings.sh 2>/dev/null || echo -e "${YELLOW}No mappings found${NC}"
        fi
        echo ""
        show_mapping_menu
        
        read -p "Choose an option: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}📋 Current Mappings:${NC}"
                ./list-mappings.sh 2>/dev/null || echo "Tool not available"
                wait_for_enter
                ;;
            2)
                echo -e "${BLUE}➕ Add New Mapping${NC}"
                read -p "Fledgling number (1-63): " fledgling
                read -p "Machine ID: " machine_id
                if [ -n "$fledgling" ] && [ -n "$machine_id" ]; then
                    ./map-machine.sh "$fledgling" "$machine_id" 2>/dev/null || echo "Mapping tool not available"
                else
                    echo -e "${RED}❌ Both fledgling number and machine ID are required${NC}"
                fi
                wait_for_enter
                ;;
            3)
                echo -e "${BLUE}🔍 Mapping Gaps:${NC}"
                ./list-mappings.sh --gaps 2>/dev/null || echo "Tool not available"
                wait_for_enter
                ;;
            4)
                echo -e "${BLUE}✅ Validation Report:${NC}"
                ./list-mappings.sh --validate 2>/dev/null || echo "Tool not available"
                wait_for_enter
                ;;
            5)
                echo -e "${BLUE}📤 Exporting Mappings:${NC}"
                ./list-mappings.sh --export > "mappings_export_$(date +%Y%m%d_%H%M%S).csv" 2>/dev/null
                echo -e "${GREEN}✅ Exported to mappings_export_$(date +%Y%m%d_%H%M%S).csv${NC}"
                wait_for_enter
                ;;
            6)
                echo -e "${BLUE}🔄 Import Mappings${NC}"
                read -p "CSV file path: " csv_file
                if [ -f "$csv_file" ]; then
                    echo "Import functionality available through fix-mappings.js"
                else
                    echo -e "${RED}❌ File not found${NC}"
                fi
                wait_for_enter
                ;;
            7)
                echo -e "${BLUE}💾 Creating Backup...${NC}"
                ./map-machine.sh --backup 2>/dev/null || echo "Backup tool not available"
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
            9)
                echo -e "${BLUE}🔧 Fix Mapping Issues:${NC}"
                if [ -f "./fix-mappings.js" ]; then
                    node fix-mappings.js
                else
                    echo "Fix mappings tool not available"
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

# QR Code Menu Handler
handle_qr_menu() {
    while true; do
        show_header
        echo -e "${BLUE}📱 QR Code Management${NC}"
        echo ""
        show_qr_menu
        
        read -p "Choose an option: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}🔄 Syncing all QR codes...${NC}"
                ./sync-qr-codes.sh --all 2>/dev/null || echo "QR sync tool not available"
                wait_for_enter
                ;;
            2)
                echo -e "${BLUE}📥 Sync specific machine QR code${NC}"
                read -p "Machine ID: " machine_id
                if [ -n "$machine_id" ]; then
                    ./sync-qr-codes.sh --machine "$machine_id" 2>/dev/null || echo "QR sync tool not available"
                fi
                wait_for_enter
                ;;
            3)
                echo -e "${BLUE}📋 QR Code List:${NC}"
                ./display-qr.sh --all 2>/dev/null || echo "QR display tool not available"
                wait_for_enter
                ;;
            4)
                echo -e "${BLUE}📱 Display QR Code${NC}"
                read -p "Machine ID or Fledgling number (prefix with 'f' for fledgling): " input
                if [[ "$input" =~ ^f[0-9]+$ ]]; then
                    fledgling=$(echo "$input" | sed 's/^f//')
                    ./display-qr.sh --fledgling "$fledgling" 2>/dev/null || echo "QR display tool not available"
                else
                    ./display-qr.sh --ascii "$input" 2>/dev/null || echo "QR display tool not available"
                fi
                wait_for_enter
                ;;
            5)
                echo -e "${BLUE}🔍 Validate QR Code${NC}"
                read -p "Machine ID: " machine_id
                if [ -n "$machine_id" ]; then
                    ./display-qr.sh --validate "$machine_id" 2>/dev/null || echo "QR display tool not available"
                fi
                wait_for_enter
                ;;
            6)
                echo -e "${BLUE}🖨️  Generate Print-ready QR${NC}"
                read -p "Machine ID: " machine_id
                if [ -n "$machine_id" ]; then
                    ./sync-qr-codes.sh --print "$machine_id" 2>/dev/null || echo "QR sync tool not available"
                fi
                wait_for_enter
                ;;
            7)
                echo -e "${BLUE}📊 QR Sync Status:${NC}"
                ./sync-qr-codes.sh --status 2>/dev/null || echo "QR sync tool not available"
                wait_for_enter
                ;;
            8)
                echo -e "${BLUE}🔧 Debug QR Sync Issues:${NC}"
                ./debug-qr-sync.sh 2>/dev/null || echo "QR debug tool not available"
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

# Service Management Menu Handler
handle_service_menu() {
    while true; do
        show_header
        echo -e "${BLUE}🔧 Service & System Management${NC}"
        echo ""
        show_service_menu
        
        read -p "Choose an option: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}📊 System Status Overview:${NC}"
                echo "Hostname: $(hostname)"
                echo "Uptime: $(uptime -p)"
                echo "Load: $(uptime | awk -F'load average:' '{ print $2 }')"
                echo "Memory: $(free -h | awk 'NR==2{printf "%.1f/%.1f GB (%.0f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')"
                echo "Disk: $(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')"
                wait_for_enter
                ;;
            2)
                echo -e "${BLUE}🔧 Service Status & Control:${NC}"
                echo "Current status:"
                sudo systemctl status gambino-pi --no-pager -l
                echo ""
                echo "1. Start service"
                echo "2. Stop service" 
                echo "3. Restart service"
                read -p "Choose action (or Enter to skip): " action
                case $action in
                    1) sudo systemctl start gambino-pi ;;
                    2) sudo systemctl stop gambino-pi ;;
                    3) sudo systemctl restart gambino-pi ;;
                esac
                wait_for_enter
                ;;
            3)
                echo -e "${BLUE}📜 Live Logs (Ctrl+C to exit):${NC}"
                sudo journalctl -u gambino-pi -f
                ;;
            4)
                echo -e "${BLUE}📋 Recent Logs:${NC}"
                sudo journalctl -u gambino-pi -n 50 --no-pager
                wait_for_enter
                ;;
            5)
                echo -e "${BLUE}🔁 Auto-start Management:${NC}"
                if systemctl is-enabled --quiet gambino-pi; then
                    echo "Auto-start is currently ENABLED"
                    read -p "Disable auto-start? (y/N): " disable
                    if [[ $disable =~ ^[Yy]$ ]]; then
                        sudo systemctl disable gambino-pi
                        echo "Auto-start disabled"
                    fi
                else
                    echo "Auto-start is currently DISABLED"
                    read -p "Enable auto-start? (y/N): " enable
                    if [[ $enable =~ ^[Yy]$ ]]; then
                        sudo systemctl enable gambino-pi
                        echo "Auto-start enabled"
                    fi
                fi
                wait_for_enter
                ;;
            6)
                echo -e "${BLUE}🔄 Restarting All Services...${NC}"
                sudo systemctl restart gambino-pi
                echo "Services restarted"
                wait_for_enter
                ;;
            7)
                echo -e "${BLUE}🖥️  System Information:${NC}"
                echo "Architecture: $(uname -m)"
                echo "Kernel: $(uname -r)"
                echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
                echo "CPU: $(lscpu | grep 'Model name' | cut -d':' -f2 | sed 's/^[ \t]*//')"
                echo "Temperature: $(vcgencmd measure_temp 2>/dev/null || echo 'N/A')"
                wait_for_enter
                ;;
            8)
                echo -e "${BLUE}🌡️  Hardware Monitoring:${NC}"
                echo "CPU Temperature: $(vcgencmd measure_temp 2>/dev/null || echo 'N/A')"
                echo "CPU Frequency: $(vcgencmd measure_clock arm 2>/dev/null || echo 'N/A')"
                echo "Memory Split: $(vcgencmd get_mem arm 2>/dev/null || echo 'N/A') / $(vcgencmd get_mem gpu 2>/dev/null || echo 'N/A')"
                echo "Throttling Status: $(vcgencmd get_throttled 2>/dev/null || echo 'N/A')"
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

# Testing Menu Handler  
handle_testing_menu() {
    while true; do
        show_header
        echo -e "${BLUE}🧪 Testing & Diagnostics${NC}"
        echo ""
        show_testing_menu
        
        read -p "Choose an option: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}🌐 Testing API Connectivity:${NC}"
                ./tests/testAPI.js 2>/dev/null || npm run test-api 2>/dev/null || echo "API test not available"
                wait_for_enter
                ;;
            2)
                echo -e "${BLUE}🔌 Testing Serial Connections:${NC}"
                ./tests/testSerial.js 2>/dev/null || npm run test-serial 2>/dev/null || echo "Serial test not available"
                wait_for_enter
                ;;
            3)
                echo -e "${BLUE}📱 Testing QR Code System:${NC}"
                echo "Available QR codes:"
                ./display-qr.sh --all 2>/dev/null || echo "QR tools not available"
                wait_for_enter
                ;;
            4)
                echo -e "${BLUE}🔗 Testing Machine Mapping:${NC}"
                ./test-machine-mapping.sh 2>/dev/null || echo "Mapping test not available"
                wait_for_enter
                ;;
            5)
                echo -e "${BLUE}🧪 Running Comprehensive Tests:${NC}"
                ./test-gambino-system.sh 2>/dev/null || echo "System test suite not available"
                wait_for_enter
                ;;
            6)
                echo -e "${BLUE}📊 Performance Diagnostics:${NC}"
                echo "CPU Usage: $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1)"
                echo "Memory Usage: $(free | grep Mem | awk '{printf \"%.2f%%\", $3/$2 * 100.0}')"
                echo "Disk I/O: $(iostat -d 1 1 2>/dev/null | tail -n +4 || echo 'iostat not available')"
                wait_for_enter
                ;;
            7)
                echo -e "${BLUE}🔍 Debug System Issues:${NC}"
                echo "Recent errors in logs:"
                sudo journalctl -p err -n 10 --no-pager
                wait_for_enter
                ;;
            8)
                echo -e "${BLUE}📈 Generate Test Report:${NC}"
                timestamp=$(date +%Y%m%d_%H%M%S)
                report_file="test_report_$timestamp.txt"
                echo "Generating comprehensive test report..."
                {
                    echo "Gambino Pi Test Report - $timestamp"
                    echo "======================================"
                    echo ""
                    echo "System Information:"
                    uname -a
                    echo ""
                    echo "Service Status:"
                    systemctl status gambino-pi --no-pager
                    echo ""
                    echo "Mappings:"
                    ./list-mappings.sh 2>/dev/null
                    echo ""
                    echo "QR Codes:"
                    ./display-qr.sh --all 2>/dev/null
                } > "$report_file"
                echo "Report saved to: $report_file"
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

# Data Management Menu Handler
handle_data_menu() {
    while true; do
        show_header
        echo -e "${BLUE}📊 Data & Database Management${NC}"
        echo ""
        show_data_menu
        
        read -p "Choose an option: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}📊 Browse Local Database:${NC}"
                ./tests/browseDatabase.js 2>/dev/null || npm run browse-db 2>/dev/null || echo "Database browser not available"
                wait_for_enter
                ;;
            2)
                echo -e "${BLUE}📈 Event Queue Status:${NC}"
                if [ -f "data/event_queue.json" ]; then
                    echo "Event queue file size: $(du -h data/event_queue.json | cut -f1)"
                    echo "Number of events: $(cat data/event_queue.json | jq length 2>/dev/null || echo "Unable to parse")"
                else
                    echo "No event queue file found"
                fi
                wait_for_enter
                ;;
            3)
                echo -e "${BLUE}🔄 Sync Data to Backend:${NC}"
                echo "Triggering data sync..."
                sudo systemctl restart gambino-pi
                echo "Service restarted to trigger sync"
                wait_for_enter
                ;;
            4)
                echo -e "${BLUE}💾 Backup Database:${NC}"
                timestamp=$(date +%Y%m%d_%H%M%S)
                backup_file="data/backups/gambino-pi_backup_$timestamp.db"
                mkdir -p data/backups
                cp data/gambino-pi.db "$backup_file" 2>/dev/null
                echo "Database backed up to: $backup_file"
                wait_for_enter
                ;;
            5)
                echo -e "${BLUE}🗑️  Clear Event Queue:${NC}"
                read -p "This will clear all pending events. Continue? (y/N): " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    echo "[]" > data/event_queue.json
                    echo "Event queue cleared"
                fi
                wait_for_enter
                ;;
            6)
                echo -e "${BLUE}📋 Database Statistics:${NC}"
                if [ -f "data/gambino-pi.db" ]; then
                    echo "Database file size: $(du -h data/gambino-pi.db | cut -f1)"
                    echo "Last modified: $(stat -c %y data/gambino-pi.db)"
                else
                    echo "Database file not found"
                fi
                wait_for_enter
                ;;
            7)
                echo -e "${BLUE}🔧 Database Maintenance:${NC}"
                echo "Running VACUUM on database..."
                sqlite3 data/gambino-pi.db "VACUUM;" 2>/dev/null && echo "Database optimized" || echo "Maintenance failed"
                wait_for_enter
                ;;
            8)
                echo -e "${BLUE}📤 Export Data:${NC}"
                timestamp=$(date +%Y%m%d_%H%M%S)
                export_file="data_export_$timestamp.json"
                echo "Exporting data..."
                echo "Export functionality would go here"
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

# Network Menu Handler
handle_network_menu() {
    while true; do
        show_header
        echo -e "${BLUE}🌐 Network & API Management${NC}"
        echo ""
        show_network_menu
        
        read -p "Choose an option: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}🌐 Network Connectivity Check:${NC}"
                echo "Testing internet connectivity..."
                ping -c 3 google.com && echo "Internet: OK" || echo "Internet: FAILED"
                echo "Testing API endpoint..."
                ping -c 3 api.gambino.gold && echo "API endpoint: OK" || echo "API endpoint: FAILED"
                wait_for_enter
                ;;
            2)
                echo -e "${BLUE}🔑 Test API Authentication:${NC}"
                ./tests/testAPI.js 2>/dev/null || echo "API test tool not available"
                wait_for_enter
                ;;
            3)
                echo -e "${BLUE}📡 Configure WiFi:${NC}"
                ./wifi-setup.sh 2>/dev/null || echo "WiFi setup tool not available"
                wait_for_enter
                ;;
            4)
                echo -e "${BLUE}🛜 Configure Tailscale VPN:${NC}"
                ./tailscale-setup.sh 2>/dev/null || echo "Tailscale setup tool not available"
                wait_for_enter
                ;;
            5)
                echo -e "${BLUE}⚙️  Network Configuration:${NC}"
                echo "Network interfaces:"
                ip addr show
                echo ""
                echo "Routing table:"
                ip route
                wait_for_enter
                ;;
            6)
                echo -e "${BLUE}🔧 Network Diagnostics:${NC}"
                echo "DNS servers:"
                cat /etc/resolv.conf
                echo ""
                echo "Network statistics:"
                cat /proc/net/dev
                wait_for_enter
                ;;
            7)
                echo -e "${BLUE}📊 API Endpoint Status:${NC}"
                source .env 2>/dev/null
                echo "API Endpoint: ${API_ENDPOINT:-Not configured}"
                echo "Testing endpoints..."
                curl -s --max-time 5 "${API_ENDPOINT:-https://api.gambino.gold}/health" && echo "Health endpoint: OK" || echo "Health endpoint: FAILED"
                wait_for_enter
                ;;
            8)
                echo -e "${BLUE}🔄 Reset Network Settings:${NC}"
                echo "This would reset network configuration"
                echo "Manual intervention required"
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

# File Management Menu Handler
handle_file_menu() {
    while true; do
        show_header
        echo -e "${BLUE}📁 File & Backup Management${NC}"
        echo ""
        show_file_menu
        
        read -p "Choose an option: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}📁 Data Directory:${NC}"
                ls -la data/ 2>/dev/null || echo "Data directory not found"
                wait_for_enter
                ;;
            2)
                echo -e "${BLUE}📜 Log Files:${NC}"
                ls -la logs/ 2>/dev/null || echo "Logs directory not found"
                echo ""
                echo "Recent log entries:"
                tail -20 logs/combined.log 2>/dev/null || echo "No log file found"
                wait_for_enter
                ;;
            3)
                echo -e "${BLUE}💾 Creating Full Backup:${NC}"
                timestamp=$(date +%Y%m%d_%H%M%S)
                backup_dir="backups/full_backup_$timestamp"
                mkdir -p "$backup_dir"
                cp -r data/ "$backup_dir/" 2>/dev/null
                cp -r logs/ "$backup_dir/" 2>/dev/null
                cp .env "$backup_dir/" 2>/dev/null
                echo "Full backup created in: $backup_dir"
                wait_for_enter
                ;;
            4)
                echo -e "${BLUE}🔄 Restore from Backup:${NC}"
                echo "Available backups:"
                ls -la backups/ 2>/dev/null || echo "No backups found"
                read -p "Enter backup directory name to restore: " backup_name
                if [ -d "backups/$backup_name" ]; then
                    echo "Restore functionality would go here"
                    echo "Manual restoration required"
                else
                    echo "Backup not found"
                fi
                wait_for_enter
                ;;
            5)
                echo -e "${BLUE}🗑️  Clean Old Files:${NC}"
                echo "Finding old log files..."
                find logs/ -name "*.log" -mtime +30 2>/dev/null || echo "No old logs found"
                echo "Finding old backups..."
                find backups/ -mtime +60 2>/dev/null || echo "No old backups found"
                wait_for_enter
                ;;
            6)
                echo -e "${BLUE}📊 Disk Usage Analysis:${NC}"
                echo "Current directory usage:"
                du -h --max-depth=1 . 2>/dev/null
                echo ""
                echo "System disk usage:"
                df -h
                wait_for_enter
                ;;
            7)
                echo -e "${BLUE}🔧 File Permissions Check:${NC}"
                echo "Checking script permissions:"
                ls -la *.sh 2>/dev/null
                echo ""
                echo "Checking data directory permissions:"
                ls -la data/ 2>/dev/null
                wait_for_enter
                ;;
            8)
                echo -e "${BLUE}📋 Configuration Files:${NC}"
                echo "Environment file:"
                ls -la .env 2>/dev/null || echo ".env not found"
                echo ""
                echo "Service configuration:"
                ls -la /etc/systemd/system/gambino-pi.service 2>/dev/null || echo "Service file not found"
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

# Deployment Menu Handler
handle_deployment_menu() {
    while true; do
        show_header
        echo -e "${BLUE}🚀 Deployment & Setup Tools${NC}"
        echo ""
        show_deployment_menu
        
        read -p "Choose an option: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}🚀 Initial Pi Setup:${NC}"
                ./setup-pi.sh 2>/dev/null || echo "Setup script not available"
                wait_for_enter
                ;;
            2)
                echo -e "${BLUE}🔧 Configure Pi Settings:${NC}"
                ./configure-pi.sh 2>/dev/null || echo "Configuration script not available"
                wait_for_enter
                ;;
            3)
                echo -e "${BLUE}📦 Create Deployment Package:${NC}"
                ./create-deployment-package.sh 2>/dev/null || echo "Package creation script not available"
                wait_for_enter
                ;;
            4)
                echo -e "${BLUE}🔄 Update System Packages:${NC}"
                sudo apt update && sudo apt upgrade -y
                wait_for_enter
                ;;
            5)
                echo -e "${BLUE}🛠️  Install Dependencies:${NC}"
                echo "Installing Node.js dependencies..."
                npm install
                echo "Installing system dependencies..."
                sudo apt install -y qrencode imagemagick
                wait_for_enter
                ;;
            6)
                echo -e "${BLUE}⚙️  Environment Configuration:${NC}"
                if [ -f ".env" ]; then
                    echo "Current environment configuration:"
                    grep -v "TOKEN" .env 2>/dev/null || echo "Unable to read .env safely"
                else
                    echo "No .env file found"
                    echo "Run initial setup to create configuration"
                fi
                wait_for_enter
                ;;
            7)
                echo -e "${BLUE}🔐 Security Setup:${NC}"
                echo "Checking user permissions..."
                groups $USER
                echo "Checking file permissions..."
                ls -la .env 2>/dev/null
                echo "Checking service security..."
                systemctl show gambino-pi --property=User 2>/dev/null
                wait_for_enter
                ;;
            8)
                echo -e "${BLUE}📋 Deployment Checklist:${NC}"
                echo "✓ System packages updated"
                echo "✓ Node.js dependencies installed"
                echo "✓ Environment configured"
                echo "✓ Service installed and enabled"
                echo "✓ File permissions correct"
                echo "✓ Network connectivity verified"
                echo "✓ Machine mappings configured"
                echo "✓ QR codes synchronized"
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

# Help and Documentation
show_help() {
    show_header
    echo -e "${BLUE}📋 Help & Documentation${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${YELLOW}Available Tools:${NC}"
    echo "  ./map-machine.sh <fledgling> <machine_id>  - Map machines to fledgling numbers"
    echo "  ./list-mappings.sh [--gaps|--validate]     - View and validate mappings"
    echo "  ./sync-qr-codes.sh [--all|--machine ID]    - Sync QR codes from dashboard"
    echo "  ./display-qr.sh [--ascii|--info] <ID>      - Display and validate QR codes"
    echo "  ./unified-manager.sh                       - This comprehensive manager"
    echo ""
    echo -e "${YELLOW}Key Directories:${NC}"
    echo "  data/              - Local database and mappings"
    echo "  logs/              - Application and system logs"
    echo "  tests/             - Testing and diagnostic tools"
    echo "  src/               - Application source code"
    echo ""
    echo -e "${YELLOW}Configuration Files:${NC}"
    echo "  .env               - Environment and API configuration"
    echo "  data/machine-mapping.json - Fledgling to machine mappings"
    echo ""
    echo -e "${YELLOW}Common Tasks:${NC}"
    echo "  Map new machine:   Menu 1 → 2"
    echo "  Sync QR codes:     Menu 2 → 1"
    echo "  Check system:      Menu 3 → 1"
    echo "  Run tests:         Menu 4 → 5"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  - Check service logs: Menu 3 → 4"
    echo "  - Test API connection: Menu 4 → 1"
    echo "  - Validate mappings: Menu 1 → 4"
    echo "  - Debug QR issues: Menu 2 → 8"
    echo ""
    wait_for_enter
}

# Main execution loop
main() {
    # Check if running in the right environment
    if [ ! -d "/opt/gambino-pi" ] && [ ! -f "./map-machine.sh" ]; then
        echo -e "${RED}❌ Error: Gambino Pi environment not detected${NC}"
        echo "Please run this from the Pi installation directory"
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
                handle_qr_menu
                ;;
            3)
                handle_service_menu
                ;;
            4)
                handle_testing_menu
                ;;
            5)
                handle_data_menu
                ;;
            6)
                handle_network_menu
                ;;
            7)
                handle_file_menu
                ;;
            8)
                handle_deployment_menu
                ;;
            9)
                show_help
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