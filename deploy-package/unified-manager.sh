#!/bin/bash

# Unified Gambino Pi Management System
# Combines all setup, configuration, and management tools

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

print_main_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                                                                              ║
    ║      ██████╗  █████╗ ███╗   ███╗██████╗ ██╗███╗   ██╗ ██████╗               ║
    ║     ██╔════╝ ██╔══██╗████╗ ████║██╔══██╗██║████╗  ██║██╔═══██╗              ║
    ║     ██║  ███╗███████║██╔████╔██║██████╔╝██║██╔██╗ ██║██║   ██║              ║
    ║     ██║   ██║██╔══██║██║╚██╔╝██║██╔══██╗██║██║╚██╗██║██║   ██║              ║
    ║     ╚██████╔╝██║  ██║██║ ╚═╝ ██║██████╔╝██║██║ ╚████║╚██████╔╝              ║
    ║      ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═════╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝               ║
    ║                                                                              ║
    ║              ██╗   ██╗███╗   ██╗██╗███████╗██╗███████╗██████╗               ║
    ║              ██║   ██║████╗  ██║██║██╔════╝██║██╔════╝██╔══██╗              ║
    ║              ██║   ██║██╔██╗ ██║██║█████╗  ██║█████╗  ██║  ██║              ║
    ║              ██║   ██║██║╚██╗██║██║██╔══╝  ██║██╔══╝  ██║  ██║              ║
    ║              ╚██████╔╝██║ ╚████║██║██║     ██║███████╗██████╔╝              ║
    ║               ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝     ╚═╝╚══════╝╚═════╝               ║
    ║                                                                              ║
    ║                           ███╗   ███╗ ██████╗ ███╗   ███╗████████╗          ║
    ║                           ████╗ ████║██╔════╝ ████╗ ████║╚══██╔══╝          ║
    ║                           ██╔████╔██║██║  ███╗██╔████╔██║   ██║             ║
    ║                           ██║╚██╔╝██║██║   ██║██║╚██╔╝██║   ██║             ║
    ║                           ██║ ╚═╝ ██║╚██████╔╝██║ ╚═╝ ██║   ██║             ║
    ║                           ╚═╝     ╚═╝ ╚═════╝ ╚═╝     ╚═╝   ╚═╝             ║
    ║                                                                              ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║                          UNIFIED MANAGEMENT SYSTEM                          ║
    ║                      SETUP • CONFIGURE • MONITOR • MAINTAIN                 ║  
    ║                                                                              ║
    ║                              VERSION 1.0                                    ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
}

print_status() {
    local tailscale_status="Unknown"
    local tailscale_ip="Not connected"
    local gambino_status="Not installed"
    local hostname=$(hostname)
    
    # Check Tailscale
    if command -v tailscale >/dev/null 2>&1; then
        if tailscale status >/dev/null 2>&1; then
            tailscale_status="Connected"
            tailscale_ip=$(tailscale ip -4 2>/dev/null || echo "Unknown")
        else
            tailscale_status="Installed but not connected"
        fi
    else
        tailscale_status="Not installed"
    fi
    
    # Check Gambino Pi service
    if [ -f "/etc/systemd/system/gambino-pi.service" ]; then
        local service_status=$(systemctl is-active gambino-pi 2>/dev/null || echo "inactive")
        gambino_status="Installed ($service_status)"
    fi
    
    echo -e "${WHITE}System Status:${NC}"
    echo -e "Hostname: ${CYAN}$hostname${NC} | Tailscale: ${CYAN}$tailscale_status${NC} | Gambino Pi: ${CYAN}$gambino_status${NC}"
    if [ "$tailscale_ip" != "Not connected" ] && [ "$tailscale_ip" != "Unknown" ]; then
        echo -e "Remote Access: ${GREEN}ssh $(whoami)@$tailscale_ip${NC}"
    fi
    echo ""
}

detect_setup_stage() {
    local stage=""
    
    if ! command -v tailscale >/dev/null 2>&1; then
        stage="fresh"
    elif ! tailscale status >/dev/null 2>&1; then
        stage="tailscale_installed"  
    elif [ ! -f ".env" ] && [ ! -f "package.json" ]; then
        stage="tailscale_ready"
    elif [ ! -f "/etc/systemd/system/gambino-pi.service" ]; then
        stage="app_extracted"
    else
        stage="fully_setup"
    fi
    
    echo $stage
}

show_setup_guidance() {
    local stage=$1
    
    echo -e "${YELLOW}Setup Guidance:${NC}"
    echo "=============="
    
    case $stage in
        "fresh")
            echo "🔸 This appears to be a fresh Pi installation"
            echo "🔸 Recommended: Start with Tailscale setup for remote access"
            ;;
        "tailscale_installed")
            echo "🔸 Tailscale is installed but not connected"
            echo "🔸 Recommended: Connect to Tailscale network"
            ;;
        "tailscale_ready")
            echo "🔸 Tailscale is connected, ready for Gambino Pi installation"
            echo "🔸 Recommended: Extract application and run setup"
            ;;
        "app_extracted")
            echo "🔸 Application files are present but service not configured"
            echo "🔸 Recommended: Run Gambino Pi setup"
            ;;
        "fully_setup")
            echo "🔸 System appears fully configured"
            echo "🔸 Use management tools for configuration and monitoring"
            ;;
    esac
    echo ""
}

# Main menu options based on setup stage
main_menu() {
    while true; do
        local stage=$(detect_setup_stage)
        
        print_main_banner
        print_status
        show_setup_guidance $stage
        
        echo -e "${WHITE}Available Actions:${NC}"
        echo "=================="
        
        # Core setup options (always available)
        echo "1.  🌐 Tailscale Network Setup"
        echo "2.  🎰 Gambino Pi Application Setup" 
        echo "3.  🔧 Gambino Pi Management Console"
        
        # Configuration and maintenance
        echo ""
        echo "4.  📊 System Information & Status"
        echo "5.  🔄 Update & Maintenance Tools"
        echo "6.  📋 View Setup Logs & Diagnostics"
        echo "7.  💾 Backup & Recovery Tools"
        
        # Advanced options
        echo ""
        echo "8.  🔒 Security & Network Tools"
        echo "9.  🛠️  Developer Tools"
        echo "10. ❓ Help & Documentation"
        
        echo ""
        echo "0.  🚪 Exit"
        echo ""
        
        read -p "Select option (0-10): " choice
        
        case $choice in
            1) setup_tailscale ;;
            2) setup_gambino_pi ;;
            3) run_gambino_manager ;;
            4) show_system_info ;;
            5) run_maintenance ;;
            6) show_diagnostics ;;
            7) backup_recovery ;;
            8) security_tools ;;
            9) developer_tools ;;
            10) show_help ;;
            0) 
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid option"
                sleep 1
                ;;
        esac
    done
}

setup_tailscale() {
    if [ -f "./tailscale-setup.sh" ]; then
        echo -e "${GREEN}Running Tailscale setup...${NC}"
        ./tailscale-setup.sh
    else
        echo -e "${RED}Tailscale setup script not found!${NC}"
        echo "Please ensure tailscale-setup.sh is in the current directory."
    fi
    read -p "Press Enter to continue..."
}

setup_gambino_pi() {
    if [ -f "./setup-pi.sh" ]; then
        echo -e "${GREEN}Running Gambino Pi setup...${NC}"
        ./setup-pi.sh
    else
        echo -e "${YELLOW}Setup script not found. Looking for application archive...${NC}"
        
        if ls gambino-pi-production.tar.gz >/dev/null 2>&1; then
            echo "Found production archive. Extracting..."
            tar -xzf gambino-pi-production.tar.gz
            echo "Running setup..."
            ./setup-pi.sh
        else
            echo -e "${RED}No setup script or production archive found!${NC}"
            echo "Please ensure you have either:"
            echo "• setup-pi.sh script in current directory, OR"
            echo "• gambino-pi-production.tar.gz archive"
        fi
    fi
    read -p "Press Enter to continue..."
}

run_gambino_manager() {
    if [ -f "./gambino-pi-manager.sh" ]; then
        ./gambino-pi-manager.sh
    else
        echo -e "${RED}Gambino Pi Manager not found!${NC}"
        echo "Please ensure gambino-pi-manager.sh is available."
        read -p "Press Enter to continue..."
    fi
}

show_system_info() {
    print_main_banner
    echo -e "${WHITE}System Information${NC}"
    echo "=================="
    
    echo -e "${CYAN}Hardware:${NC}"
    echo "Pi Model: $(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo 'Unknown')"
    echo "Serial: $(cat /proc/cpuinfo | grep Serial | cut -d' ' -f2)"
    echo "Memory: $(free -h | grep Mem | awk '{print $2}') total"
    echo "Storage: $(df -h / | tail -1 | awk '{print $2}') total, $(df -h / | tail -1 | awk '{print $4}') available"
    echo "Temperature: $(vcgencmd measure_temp 2>/dev/null || echo 'N/A')"
    
    echo ""
    echo -e "${CYAN}Network:${NC}"
    echo "Hostname: $(hostname)"
    echo "Local IP: $(ip route get 8.8.8.8 | grep -oP 'src \K\S+' 2>/dev/null || echo 'Unknown')"
    
    if command -v tailscale >/dev/null 2>&1; then
        echo "Tailscale IP: $(tailscale ip -4 2>/dev/null || echo 'Not connected')"
        echo "Tailscale Status: $(tailscale status --json 2>/dev/null | grep -o '"Online":[^,]*' | cut -d':' -f2 || echo 'Unknown')"
    else
        echo "Tailscale: Not installed"
    fi
    
    echo ""
    echo -e "${CYAN}Software:${NC}"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo "Node.js: $(node --version 2>/dev/null || echo 'Not installed')"
    
    if [ -f "/etc/systemd/system/gambino-pi.service" ]; then
        echo "Gambino Pi Service: $(systemctl is-active gambino-pi 2>/dev/null)"
    else
        echo "Gambino Pi Service: Not installed"
    fi
    
    read -p "Press Enter to continue..."
}

run_maintenance() {
    while true; do
        print_main_banner
        echo -e "${WHITE}Update & Maintenance Tools${NC}"
        echo "=========================="
        echo ""
        echo "1. Update system packages"
        echo "2. Update Gambino Pi application"
        echo "3. Restart all services"
        echo "4. Clean temporary files"
        echo "5. Check disk space"
        echo "6. View system logs"
        echo "7. Back to main menu"
        echo ""
        
        read -p "Select option (1-7): " choice
        
        case $choice in
            1)
                echo "Updating system packages..."
                sudo apt update && sudo apt upgrade -y
                echo -e "${GREEN}System updated${NC}"
                ;;
            2)
                echo "Checking for Gambino Pi updates..."
                echo "(Update mechanism would go here)"
                ;;
            3)
                echo "Restarting services..."
                sudo systemctl daemon-reload
                [ -f "/etc/systemd/system/gambino-pi.service" ] && sudo systemctl restart gambino-pi
                command -v tailscale >/dev/null && sudo systemctl restart tailscaled
                echo -e "${GREEN}Services restarted${NC}"
                ;;
            4)
                echo "Cleaning temporary files..."
                sudo apt autoremove -y
                sudo apt autoclean
                sudo journalctl --vacuum-time=30d
                echo -e "${GREEN}Cleanup completed${NC}"
                ;;
            5)
                echo -e "${CYAN}Disk Space Usage:${NC}"
                df -h
                ;;
            6)
                echo "Recent system logs:"
                sudo journalctl --since "1 hour ago" -n 50
                ;;
            7)
                break
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
        read -p "Press Enter to continue..."
    done
}

show_diagnostics() {
    print_main_banner
    echo -e "${WHITE}Setup Logs & Diagnostics${NC}"
    echo "========================"
    
    echo -e "${CYAN}Running comprehensive diagnostic...${NC}"
    echo ""
    
    # Network connectivity
    echo -e "${YELLOW}Network Connectivity:${NC}"
    ping -c 1 google.com >/dev/null && echo "✓ Internet: OK" || echo "✗ Internet: Failed"
    
    if command -v tailscale >/dev/null; then
        tailscale status >/dev/null && echo "✓ Tailscale: Connected" || echo "✗ Tailscale: Not connected"
    fi
    
    # Services
    echo ""
    echo -e "${YELLOW}Service Status:${NC}"
    if [ -f "/etc/systemd/system/gambino-pi.service" ]; then
        systemctl is-active gambino-pi >/dev/null && echo "✓ Gambino Pi: Running" || echo "✗ Gambino Pi: Stopped"
    else
        echo "- Gambino Pi: Not installed"
    fi
    
    # Ports and processes
    echo ""
    echo -e "${YELLOW}System Health:${NC}"
    echo "Load average: $(uptime | grep -oP 'load average: \K.*')"
    echo "Memory usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
    echo "Disk usage: $(df / | tail -1 | awk '{print $5}')"
    
    # Recent errors
    echo ""
    echo -e "${YELLOW}Recent Errors (last 24h):${NC}"
    sudo journalctl --since "24 hours ago" --priority=err -n 5 --no-pager || echo "No recent errors"
    
    read -p "Press Enter to continue..."
}

backup_recovery() {
    while true; do
        print_main_banner
        echo -e "${WHITE}Backup & Recovery Tools${NC}"
        echo "======================="
        echo ""
        echo "1. Backup configuration files"
        echo "2. Create system snapshot info"
        echo "3. Export device information"
        echo "4. View backup files"
        echo "5. Back to main menu"
        echo ""
        
        read -p "Select option (1-5): " choice
        
        case $choice in
            1)
                echo "Creating configuration backup..."
                mkdir -p ~/backups
                [ -f ".env" ] && cp .env ~/backups/.env.backup.$(date +%Y%m%d_%H%M%S)
                [ -f "/etc/systemd/system/gambino-pi.service" ] && sudo cp /etc/systemd/system/gambino-pi.service ~/backups/
                echo -e "${GREEN}Configuration backed up to ~/backups/${NC}"
                ;;
            2)
                echo "Creating system snapshot..."
                cat > ~/system-snapshot.$(date +%Y%m%d_%H%M%S).txt << EOF
System Snapshot - $(date)
========================
Hostname: $(hostname)
IP Addresses: $(ip addr show | grep "inet " | awk '{print $2}')
Tailscale IP: $(tailscale ip -4 2>/dev/null || echo "Not available")
Services: $(systemctl list-unit-files --state=enabled | grep gambino || echo "None")
Installed Packages: $(dpkg -l | grep -E "(tailscale|nodejs|npm)" || echo "None")
EOF
                echo -e "${GREEN}System snapshot created${NC}"
                ;;
            3)
                if [ -f "~/pi-device-info.txt" ]; then
                    cat ~/pi-device-info.txt
                else
                    echo "No device info file found. Run Tailscale setup first."
                fi
                ;;
            4)
                echo "Available backup files:"
                ls -la ~/backups/ 2>/dev/null || echo "No backups found"
                ls -la ~/system-snapshot.*.txt 2>/dev/null || echo "No snapshots found"
                ;;
            5)
                break
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
        read -p "Press Enter to continue..."
    done
}

security_tools() {
    echo -e "${BLUE}Security & Network Tools${NC}"
    echo "========================"
    echo ""
    echo "Current security status:"
    
    # Firewall status
    if command -v ufw >/dev/null; then
        echo "Firewall: $(sudo ufw status | head -1)"
    else
        echo "Firewall: Not configured"
    fi
    
    # Fail2ban status
    if command -v fail2ban-client >/dev/null; then
        echo "Fail2ban: Installed"
    else
        echo "Fail2ban: Not installed"
    fi
    
    # SSH config
    echo "SSH status: $(systemctl is-active ssh)"
    
    read -p "Press Enter to continue..."
}

developer_tools() {
    echo -e "${PURPLE}Developer Tools${NC}"
    echo "==============="
    echo ""
    echo "Available development utilities:"
    echo "• Node.js version: $(node --version 2>/dev/null || echo 'Not installed')"
    echo "• NPM version: $(npm --version 2>/dev/null || echo 'Not installed')"
    echo "• Git version: $(git --version 2>/dev/null || echo 'Not installed')"
    echo ""
    echo "Development scripts available:"
    [ -f "tests/testAPI.js" ] && echo "✓ API connectivity test"
    [ -f "tests/testSerial.js" ] && echo "✓ Serial port test"  
    [ -f "tests/mockMuthaGoose.js" ] && echo "✓ Mock data generator"
    
    read -p "Press Enter to continue..."
}

show_help() {
    print_main_banner
    echo -e "${WHITE}Help & Documentation${NC}"
    echo "===================="
    echo ""
    echo -e "${CYAN}Setup Process:${NC}"
    echo "1. Fresh Pi → Run Tailscale setup for remote access"
    echo "2. Extract gambino-pi-production.tar.gz if needed"
    echo "3. Run Gambino Pi application setup"
    echo "4. Use management console for daily operations"
    echo ""
    echo -e "${CYAN}Remote Access:${NC}"
    echo "• Once Tailscale is configured, you can SSH from anywhere"
    echo "• Use: ssh $(whoami)@TAILSCALE_IP"
    echo "• Tailscale provides secure mesh networking"
    echo ""
    echo -e "${CYAN}File Locations:${NC}"
    echo "• Configuration: .env"
    echo "• Service: /etc/systemd/system/gambino-pi.service"
    echo "• Device info: ~/pi-device-info.txt"
    echo "• Backups: ~/backups/"
    echo ""
    echo -e "${CYAN}Support:${NC}"
    echo "• System logs: sudo journalctl -u gambino-pi"
    echo "• Network logs: sudo journalctl -u tailscaled"
    echo "• Diagnostics: Option 6 in main menu"
    
    read -p "Press Enter to continue..."
}

# Main execution
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Please run as regular user (not root)${NC}"
    exit 1
fi

main_menu
