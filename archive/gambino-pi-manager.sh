#!/bin/bash

# Gambino Pi Manager - Complete Management Tool
# Version 1.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="gambino-pi"
ENV_FILE=".env"
LOG_FILE="/var/log/syslog"

# Helper functions
print_header() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                                                                              ║
    ║      ██████╗  █████╗ ███╗   ███╗██████╗ ██╗███╗   ██╗ ██████╗                ║
    ║     ██╔════╝ ██╔══██╗████╗ ████║██╔══██╗██║████╗  ██║██╔═══██╗               ║
    ║     ██║  ███╗███████║██╔████╔██║██████╔╝██║██╔██╗ ██║██║   ██║               ║
    ║     ██║   ██║██╔══██║██║╚██╔╝██║██╔══██╗██║██║╚██╗██║██║   ██║               ║
    ║     ╚██████╔╝██║  ██║██║ ╚═╝ ██║██████╔╝██║██║ ╚████║╚██████╔╝               ║
    ║      ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═════╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝                ║
    ║                                                                              ║
    ║            ██████╗ ██╗    ███╗   ███╗ ██████╗ ███╗   ███╗████████╗           ║
    ║            ██╔══██╗██║    ████╗ ████║██╔════╝ ████╗ ████║╚══██╔══╝           ║
    ║            ██████╔╝██║    ██╔████╔██║██║  ███╗██╔████╔██║   ██║              ║
    ║            ██╔═══╝ ██║    ██║╚██╔╝██║██║   ██║██║╚██╔╝██║   ██║              ║
    ║            ██║     ██║    ██║ ╚═╝ ██║╚██████╔╝██║ ╚═╝ ██║   ██║              ║
    ║            ╚═╝     ╚═╝    ╚═╝     ╚═╝ ╚═════╝ ╚═╝     ╚═╝   ╚═╝              ║
    ║                                                                              ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║                          RASPBERRY PI EDGE DEVICE                            ║
    ║                             MANAGEMENT SUITE                                 ║  
    ║                                                                              ║
    ║                              VERSION 1.0                                     ║
    ║                                                                              ║
    ║                      MUTHA GOOSE SERIAL INTERFACE                            ║
    ║                      REAL-TIME DATA PROCESSING                               ║
    ║                      OFFLINE SYNC CAPABILITY                                 ║
    ║                      QR CODE USER ATTRIBUTION                                ║
    ║                                                                              ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  CODED BY: GAMBINO DEVELOPMENT TEAM    │  SYSTEM: RASPBERRY PI 4B            ║
    ║  RELEASE:  SEPTEMBER 2025              │  STACK:  NODE.JS + EXPRESS          ║
    ║  BUILD:    PRODUCTION STABLE           │  PROTO:  SERIAL RS-485/RS-232       ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
}

print_status() {
    local status=$(systemctl is-active $SERVICE_NAME 2>/dev/null || echo "inactive")
    local mode=$(grep NODE_ENV $ENV_FILE 2>/dev/null | cut -d'=' -f2 || echo "unknown")
    local port=$(grep SERIAL_PORT $ENV_FILE 2>/dev/null | cut -d'=' -f2 || echo "unknown")
    local machine_id=$(grep MACHINE_ID $ENV_FILE 2>/dev/null | cut -d'=' -f2 || echo "unknown")
    
    echo -e "Current Status: ${status^^} | Mode: ${mode^^} | Port: $port | Machine: $machine_id"
    echo ""
}

get_service_status() {
    systemctl is-active $SERVICE_NAME 2>/dev/null || echo "inactive"
}

confirm_action() {
    local message="$1"
    echo -e "${YELLOW}$message${NC}"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Action cancelled."
        return 1
    fi
    return 0
}

# Main menu functions
service_management() {
    while true; do
        print_header
        print_status
        echo -e "${WHITE}Service Management${NC}"
        echo "=================="
        echo "1. Start service"
        echo "2. Stop service"  
        echo "3. Restart service"
        echo "4. Service status (detailed)"
        echo "5. Enable auto-start on boot"
        echo "6. Disable auto-start on boot"
        echo "7. Force kill service"
        echo "8. Back to main menu"
        echo ""
        
        read -p "Select option (1-8): " choice
        
        case $choice in
            1)
                echo "Starting Gambino Pi service..."
                sudo systemctl start $SERVICE_NAME
                echo -e "${GREEN}Service started.${NC}"
                ;;
            2)
                if confirm_action "Stop the Gambino Pi service?"; then
                    sudo systemctl stop $SERVICE_NAME
                    echo -e "${GREEN}Service stopped.${NC}"
                fi
                ;;
            3)
                echo "Restarting Gambino Pi service..."
                sudo systemctl restart $SERVICE_NAME
                echo -e "${GREEN}Service restarted.${NC}"
                ;;
            4)
                sudo systemctl status $SERVICE_NAME --no-pager
                ;;
            5)
                sudo systemctl enable $SERVICE_NAME
                echo -e "${GREEN}Auto-start enabled.${NC}"
                ;;
            6)
                sudo systemctl disable $SERVICE_NAME
                echo -e "${GREEN}Auto-start disabled.${NC}"
                ;;
            7)
                if confirm_action "Force kill all Gambino Pi processes?"; then
                    sudo pkill -f "gambino-pi" || echo "No processes found"
                    echo -e "${GREEN}Force kill completed.${NC}"
                fi
                ;;
            8)
                break
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
        read -p "Press Enter to continue..."
    done
}

configuration_management() {
    while true; do
        print_header
        print_status
        echo -e "${WHITE}Configuration Management${NC}"
        echo "========================"
        echo "1. Switch to Development mode (mock data)"
        echo "2. Switch to Production mode (real hardware)"
        echo "3. Update machine credentials"
        echo "4. Change serial port"
        echo "5. Edit .env file directly"
        echo "6. View current configuration"
        echo "7. Backup configuration"
        echo "8. Restore configuration"
        echo "9. Back to main menu"
        echo ""
        
        read -p "Select option (1-9): " choice
        
        case $choice in
            1)
                sed -i 's/NODE_ENV=.*/NODE_ENV=development/' $ENV_FILE
                sed -i 's/SERIAL_PORT=.*/SERIAL_PORT=\/dev\/mock/' $ENV_FILE
                echo -e "${GREEN}Switched to development mode (mock data)${NC}"
                echo "Restart the service to apply changes."
                ;;
            2)
                echo "Available serial devices:"
                ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "No USB serial devices found"
                read -p "Serial port (default: /dev/ttyUSB0): " port
                port=${port:-/dev/ttyUSB0}
                sed -i 's/NODE_ENV=.*/NODE_ENV=production/' $ENV_FILE
                sed -i "s|SERIAL_PORT=.*|SERIAL_PORT=$port|" $ENV_FILE
                echo -e "${GREEN}Switched to production mode ($port)${NC}"
                echo "Restart the service to apply changes."
                ;;
            3)
                echo "Current credentials:"
                grep -E "(MACHINE_ID|STORE_ID|MACHINE_TOKEN)" $ENV_FILE
                echo ""
                read -p "New Machine ID (enter to skip): " machine_id
                read -p "New Store ID (enter to skip): " store_id
                read -p "New Machine Token (enter to skip): " token
                
                if [ ! -z "$machine_id" ]; then
                    sed -i "s/MACHINE_ID=.*/MACHINE_ID=$machine_id/" $ENV_FILE
                fi
                if [ ! -z "$store_id" ]; then
                    sed -i "s/STORE_ID=.*/STORE_ID=$store_id/" $ENV_FILE
                fi
                if [ ! -z "$token" ]; then
                    sed -i "s/MACHINE_TOKEN=.*/MACHINE_TOKEN=$token/" $ENV_FILE
                fi
                echo -e "${GREEN}Credentials updated.${NC}"
                ;;
            4)
                echo "Current serial port: $(grep SERIAL_PORT $ENV_FILE | cut -d'=' -f2)"
                echo "Available serial devices:"
                ls /dev/ttyUSB* /dev/ttyACM* /dev/mock 2>/dev/null || echo "No devices found"
                read -p "New serial port: " port
                if [ ! -z "$port" ]; then
                    sed -i "s|SERIAL_PORT=.*|SERIAL_PORT=$port|" $ENV_FILE
                    echo -e "${GREEN}Serial port updated to $port${NC}"
                fi
                ;;
            5)
                nano $ENV_FILE
                echo -e "${GREEN}Configuration file edited.${NC}"
                ;;
            6)
                echo -e "${CYAN}Current Configuration:${NC}"
                cat $ENV_FILE
                ;;
            7)
                cp $ENV_FILE ".env.backup.$(date +%Y%m%d_%H%M%S)"
                echo -e "${GREEN}Configuration backed up.${NC}"
                ;;
            8)
                ls -la .env.backup.* 2>/dev/null || echo "No backups found"
                read -p "Enter backup file name to restore: " backup_file
                if [ -f "$backup_file" ]; then
                    cp "$backup_file" $ENV_FILE
                    echo -e "${GREEN}Configuration restored from $backup_file${NC}"
                else
                    echo "Backup file not found"
                fi
                ;;
            9)
                break
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
        read -p "Press Enter to continue..."
    done
}

monitoring_logs() {
    while true; do
        print_header
        print_status
        echo -e "${WHITE}Monitoring & Logs${NC}"
        echo "=================="
        echo "1. Live log viewing (press Ctrl+C to stop)"
        echo "2. View last 50 log entries"
        echo "3. View last 100 log entries"
        echo "4. Search logs for errors"
        echo "5. Service health check"
        echo "6. Connection status check"
        echo "7. Clear old logs"
        echo "8. Back to main menu"
        echo ""
        
        read -p "Select option (1-8): " choice
        
        case $choice in
            1)
                echo "Starting live log view... (Press Ctrl+C to stop)"
                sleep 2
                sudo journalctl -u $SERVICE_NAME -f
                ;;
            2)
                sudo journalctl -u $SERVICE_NAME -n 50 --no-pager
                ;;
            3)
                sudo journalctl -u $SERVICE_NAME -n 100 --no-pager
                ;;
            4)
                echo "Searching for errors in the last 24 hours..."
                sudo journalctl -u $SERVICE_NAME --since "24 hours ago" | grep -i error
                ;;
            5)
                echo -e "${CYAN}Service Health Check:${NC}"
                echo "Service Status: $(systemctl is-active $SERVICE_NAME)"
                echo "Service Enabled: $(systemctl is-enabled $SERVICE_NAME)"
                echo "Uptime: $(systemctl show $SERVICE_NAME --property=ActiveEnterTimestamp --value)"
                echo "Memory Usage: $(systemctl show $SERVICE_NAME --property=MemoryCurrent --value)"
                ;;
            6)
                if [ -f "tests/testAPI.js" ]; then
                    echo "Testing API connection..."
                    node tests/testAPI.js
                else
                    echo "API test script not found"
                fi
                ;;
            7)
                if confirm_action "Clear old log entries (keeps last 1000 entries)?"; then
                    sudo journalctl --vacuum-size=10M
                    echo -e "${GREEN}Log cleanup completed.${NC}"
                fi
                ;;
            8)
                break
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
        read -p "Press Enter to continue..."
    done
}

testing_diagnostics() {
    while true; do
        print_header
        print_status
        echo -e "${WHITE}Testing & Diagnostics${NC}"
        echo "====================="
        echo "1. Test API connectivity"
        echo "2. Test serial port detection"
        echo "3. Send test event to backend"
        echo "4. Network connectivity check"
        echo "5. Mock data generator (standalone)"
        echo "6. Full system diagnostic"
        echo "7. Back to main menu"
        echo ""
        
        read -p "Select option (1-7): " choice
        
        case $choice in
            1)
                if [ -f "tests/testAPI.js" ]; then
                    node tests/testAPI.js
                else
                    echo "API test script not found"
                fi
                ;;
            2)
                if [ -f "tests/testSerial.js" ]; then
                    node tests/testSerial.js
                else
                    echo "Serial test script not found"
                fi
                ;;
            3)
                echo "Sending test event..."
                curl -X POST "$(grep API_ENDPOINT $ENV_FILE | cut -d'=' -f2)/api/edge/events" \
                     -H "Authorization: Bearer $(grep MACHINE_TOKEN $ENV_FILE | cut -d'=' -f2)" \
                     -H "Content-Type: application/json" \
                     -d '{"eventType":"voucher","amount":"10.00","timestamp":"'$(date -Iseconds)'","gamingMachineId":"test_machine"}' \
                     2>/dev/null && echo -e "${GREEN}Test event sent successfully${NC}" || echo -e "${RED}Test event failed${NC}"
                ;;
            4)
                echo "Testing network connectivity..."
                ping -c 3 8.8.8.8 > /dev/null && echo -e "${GREEN}Internet: OK${NC}" || echo -e "${RED}Internet: FAILED${NC}"
                API_HOST=$(grep API_ENDPOINT $ENV_FILE | cut -d'=' -f2 | sed 's|https\?://||' | cut -d'/' -f1)
                ping -c 3 $API_HOST > /dev/null && echo -e "${GREEN}API Server: OK${NC}" || echo -e "${RED}API Server: FAILED${NC}"
                ;;
            5)
                if [ -f "tests/mockMuthaGoose.js" ]; then
                    echo "Starting standalone mock data generator..."
                    node tests/mockMuthaGoose.js
                else
                    echo "Mock data generator not found"
                fi
                ;;
            6)
                echo -e "${CYAN}Full System Diagnostic:${NC}"
                echo "================================"
                echo "Service Status: $(systemctl is-active $SERVICE_NAME 2>/dev/null || echo 'inactive')"
                echo "Node.js Version: $(node --version 2>/dev/null || echo 'not found')"
                echo "NPM Version: $(npm --version 2>/dev/null || echo 'not found')"
                echo "Disk Space: $(df -h . | tail -1 | awk '{print $4}') available"
                echo "Memory Usage: $(free -h | grep Mem | awk '{print $3"/"$2}')"
                echo "USB Devices: $(lsusb | wc -l) devices found"
                echo "Serial Ports: $(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | wc -l) ports found"
                echo "Network: $(ip route get 8.8.8.8 | grep -oP 'src \K\S+' 2>/dev/null || echo 'unknown')"
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

hardware_management() {
    while true; do
        print_header
        print_status
        echo -e "${WHITE}Hardware Management${NC}"
        echo "==================="
        echo "1. Scan for serial devices"
        echo "2. USB device information"
        echo "3. Check serial port permissions"
        echo "4. Fix serial port permissions"
        echo "5. Hardware diagnostic"
        echo "6. Back to main menu"
        echo ""
        
        read -p "Select option (1-6): " choice
        
        case $choice in
            1)
                echo -e "${CYAN}Serial Device Scan:${NC}"
                ls -la /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "No serial devices found"
                echo ""
                ls -la /dev/serial/by-id/* 2>/dev/null || echo "No devices in /dev/serial/by-id/"
                ;;
            2)
                echo -e "${CYAN}USB Device Information:${NC}"
                lsusb
                ;;
            3)
                echo -e "${CYAN}Serial Port Permissions:${NC}"
                groups $USER | grep -q dialout && echo -e "${GREEN}User is in dialout group${NC}" || echo -e "${RED}User NOT in dialout group${NC}"
                ls -la /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "No serial devices to check"
                ;;
            4)
                echo "Adding user to dialout group..."
                sudo usermod -a -G dialout $USER
                echo -e "${GREEN}User added to dialout group. Logout and login again for changes to take effect.${NC}"
                ;;
            5)
                echo -e "${CYAN}Hardware Diagnostic:${NC}"
                echo "CPU: $(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)"
                echo "Memory: $(free -h | grep Mem | awk '{print $2}') total"
                echo "Storage: $(df -h / | tail -1 | awk '{print $2}') total, $(df -h / | tail -1 | awk '{print $4}') available"
                echo "Temperature: $(vcgencmd measure_temp 2>/dev/null || echo 'N/A')"
                echo "USB Ports: $(lsusb | wc -l) devices connected"
                echo "Network Interfaces: $(ip link show | grep -E '^[0-9]+:' | wc -l) interfaces"
                ;;
            6)
                break
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
        read -p "Press Enter to continue..."
    done
}

# Main menu
main_menu() {
    while true; do
        print_header
        print_status
        echo -e "${WHITE}Main Menu${NC}"
        echo "========="
        echo "1.  Service Management"
        echo "2.  Configuration"
        echo "3.  Monitoring & Logs"
        echo "4.  Testing & Diagnostics"
        echo "5.  Hardware Management"
        echo "6.  System Information"
        echo "7.  Exit"
        echo ""
        
        read -p "Select option (1-7): " choice
        
        case $choice in
            1) service_management ;;
            2) configuration_management ;;
            3) monitoring_logs ;;
            4) testing_diagnostics ;;
            5) hardware_management ;;
            6)
                print_header
                echo -e "${CYAN}System Information:${NC}"
                echo "=================="
                echo "Hostname: $(hostname)"
                echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
                echo "Kernel: $(uname -r)"
                echo "Uptime: $(uptime -p)"
                echo "Load: $(uptime | grep -oP 'load average: \K.*')"
                echo "IP Address: $(ip route get 8.8.8.8 | grep -oP 'src \K\S+' 2>/dev/null)"
                echo "Pi Model: $(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo 'Unknown')"
                read -p "Press Enter to continue..."
                ;;
            7)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Please run as regular user (not root)${NC}"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found. Please run from your gambino-pi directory.${NC}"
    exit 1
fi

# Start main menu
main_menu
