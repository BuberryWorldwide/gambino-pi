#!/bin/bash

# Gambino Pi Main Launcher - Clean TUI Edition
# Enterprise-grade interface for mining infrastructure management

set -e

# Enhanced color palette
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Special characters
CHECK='✓'
CROSS='✗'
WARNING='⚠'
BULLET='●'
ARROW='▶'

# Get terminal dimensions
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)

print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                              ║${NC}"
    echo -e "${CYAN}║${NC}      ${YELLOW}██████╗  █████╗ ███╗   ███╗██████╗ ██╗███╗   ██╗ ██████╗${NC}      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}     ${YELLOW}██╔════╝ ██╔══██╗████╗ ████║██╔══██╗██║████╗  ██║██╔═══██╗${NC}     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}     ${YELLOW}██║  ███╗███████║██╔████╔██║██████╔╝██║██╔██╗ ██║██║   ██║${NC}     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}     ${YELLOW}██║   ██║██╔══██║██║╚██╔╝██║██╔══██╗██║██║╚██╗██║██║   ██║${NC}     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}     ${YELLOW}╚██████╔╝██║  ██║██║ ╚═╝ ██║██████╔╝██║██║ ╚████║╚██████╔╝${NC}     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}      ${YELLOW}╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═════╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝${NC}      ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                              ║${NC}"
    echo -e "${CYAN}║${NC}        ${WHITE}${BOLD}⛏️  DISTRIBUTED MINING INFRASTRUCTURE CONTROL CENTER  ⛏️${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                   ${DIM}Edge Device Management System v1.0${NC}                   ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
}

get_status_indicator() {
    local status="$1"
    case "$status" in
        "running"|"connected"|"active")
            echo -e "${GREEN}${BULLET}${NC}"
            ;;
        "stopped"|"disconnected"|"inactive")
            echo -e "${RED}${BULLET}${NC}"
            ;;
        "warning"|"partial")
            echo -e "${YELLOW}${WARNING}${NC}"
            ;;
        *)
            echo -e "${GRAY}${BULLET}${NC}"
            ;;
    esac
}

show_system_status() {
    # Get status data
    local hostname=$(hostname)
    local gambino_status="unknown"
    local gambino_text="Not installed"
    local tailscale_status="unknown"
    local tailscale_text="Not installed"
    local wifi_status="unknown"
    local wifi_text="Not connected"
    
    # Check Gambino Pi service
    if systemctl is-active --quiet gambino-pi 2>/dev/null; then
        gambino_status="running"
        gambino_text="Mining service active"
    elif systemctl is-enabled --quiet gambino-pi 2>/dev/null; then
        gambino_status="stopped"
        gambino_text="Service stopped"
    else
        gambino_status="unknown"
        gambino_text="Not installed"
    fi
    
    # Check Tailscale
    if command -v tailscale >/dev/null 2>&1; then
        if tailscale status >/dev/null 2>&1; then
            local tailscale_ip=$(tailscale ip -4 2>/dev/null | cut -c1-15 || echo "unknown")
            tailscale_status="connected"
            tailscale_text="Connected ($tailscale_ip)"
        else
            tailscale_status="warning"
            tailscale_text="Not connected"
        fi
    else
        tailscale_status="unknown"
        tailscale_text="Not installed"
    fi
    
    # Check WiFi
    if iwconfig wlan0 2>/dev/null | grep -q "ESSID:"; then
        local current_ssid=$(iwconfig wlan0 | grep ESSID | cut -d'"' -f2 | cut -c1-20)
        if [ -n "$current_ssid" ] && [ "$current_ssid" != "off/any" ]; then
            wifi_status="connected"
            wifi_text="Connected to $current_ssid"
        else
            wifi_status="warning"
            wifi_text="WiFi enabled"
        fi
    else
        wifi_status="unknown"
        wifi_text="Not connected"
    fi
    
    # Get system metrics
    local uptime=$(uptime -p 2>/dev/null | sed 's/up //' | cut -c1-20 || echo "unknown")
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}' 2>/dev/null || echo "unknown")
    local disk_usage=$(df / | tail -1 | awk '{print $5}' 2>/dev/null || echo "unknown")
    local temp=$(vcgencmd measure_temp 2>/dev/null | cut -d'=' -f2 || echo "N/A")
    
    # Display status box
    echo ""
    echo -e "${CYAN}┌────────────────────────────── SYSTEM STATUS ─────────────────────────────┐${NC}"
    echo -e "${CYAN}│                                                                          │${NC}"
    printf "${CYAN}│${NC}  ${WHITE}Device:${NC} %-25s ${WHITE}Uptime:${NC} %-25s ${CYAN}│${NC}\n" "$hostname" "$uptime"
    printf "${CYAN}│${NC}  $(get_status_indicator $gambino_status) ${WHITE}Mining Service:${NC} %-16s ${WHITE}Memory:${NC} %-25s ${CYAN}│${NC}\n" "$gambino_text" "$memory_usage"
    printf "${CYAN}│${NC}  $(get_status_indicator $tailscale_status) ${WHITE}Remote Access:${NC} %-17s ${WHITE}Disk:${NC} %-27s ${CYAN}│${NC}\n" "$tailscale_text" "$disk_usage"
    printf "${CYAN}│${NC}  $(get_status_indicator $wifi_status) ${WHITE}Network:${NC} %-22s ${WHITE}Temp:${NC} %-27s ${CYAN}│${NC}\n" "$wifi_text" "$temp"
    echo -e "${CYAN}│                                                                          │${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────┘${NC}"
}

show_menu() {
    echo ""
    echo -e "${CYAN}┌─────────────────────────────── CONTROL PANEL ──────────────────────────────┐${NC}"
    echo -e "${CYAN}│                                                                            │${NC}"
    echo -e "${CYAN}│${NC}  ${BLUE}${BOLD}📡 NETWORK SETUP${NC}                    ${PURPLE}${BOLD}🧪 DIAGNOSTICS${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}1.${NC} Configure WiFi networks         ${WHITE}5.${NC} Run quick system tests         ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}2.${NC} Setup Tailscale remote access   ${WHITE}6.${NC} View detailed system info      ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                      ${WHITE}7.${NC} View application logs           ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}${BOLD}⚙️  APPLICATION CONTROL${NC}             ${RED}${BOLD}📦 DEPLOYMENT${NC}                     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}3.${NC} Initial Pi setup                ${WHITE}8.${NC} Create deployment package      ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}4.${NC} Gambino Pi service manager      ${WHITE}9.${NC} Show deployment checklist      ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                                           ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GRAY}${BOLD}🔧 ADVANCED${NC}                     ${GREEN}${BOLD}📊 MONITORING${NC}                     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}10.${NC} Open system shell              ${WHITE}11.${NC} Live monitoring dashboard      ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}12.${NC} Documentation & help           ${WHITE}13.${NC} Exit program                   ${CYAN}│${NC}"
    echo -e "${CYAN}│                                                                            │${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -ne "${WHITE}${BOLD}${ARROW} Select option (1-13): ${NC}"
}

check_script_exists() {
    local script_name=$1
    
    if [ -f "$script_name" ] && [ -x "$script_name" ]; then
        return 0
    elif [ -f "$script_name" ]; then
        chmod +x "$script_name" 2>/dev/null || true
        return 0
    else
        return 1
    fi
}

loading_message() {
    local message="$1"
    echo ""
    echo -e "${CYAN}${message}...${NC}"
    sleep 1
}

run_quick_tests() {
    clear
    echo -e "${WHITE}${BOLD}🧪 SYSTEM DIAGNOSTICS${NC}"
    echo -e "${CYAN}═════════════════════${NC}"
    echo ""
    
    # Test 1: API Connectivity
    echo -ne "${WHITE}Testing API connectivity...${NC} "
    if [ -f "package.json" ] && [ -f "tests/testAPI.js" ] && command -v npm >/dev/null; then
        # Run the test from the current directory (where package.json is)
        local test_output
        local test_exit_code
        
        # Change to the directory containing package.json and run test
        pushd "$(pwd)" > /dev/null
        test_output=$(timeout 20 npm run test-api 2>&1)
        test_exit_code=$?
        popd > /dev/null
        
        # Check for success indicators in the output
        if [ $test_exit_code -eq 0 ] && echo "$test_output" | grep -q "All API tests passed"; then
            echo -e "${GREEN}${CHECK} PASSED${NC}"
        elif echo "$test_output" | grep -q "Config endpoint working\|Events endpoint working\|Heartbeat endpoint working"; then
            echo -e "${GREEN}${CHECK} PASSED${NC}"
        else
            echo -e "${RED}${CROSS} FAILED${NC}"
            echo -e "${DIM}  Exit code: $test_exit_code${NC}"
            echo -e "${DIM}  Try: npm run test-api${NC}"
        fi
    else
        echo -e "${YELLOW}${WARNING} SKIPPED (missing files)${NC}"
    fi
    
    # Test 2: Serial Hardware
    echo -ne "${WHITE}Testing serial hardware...${NC} "
    if [ -f "package.json" ] && [ -f "tests/testSerial.js" ] && command -v npm >/dev/null; then
        if timeout 8 npm run test-serial >/dev/null 2>&1; then
            echo -e "${GREEN}${CHECK} PASSED${NC}"
        else
            echo -e "${YELLOW}${WARNING} NO HARDWARE${NC}"
        fi
    else
        echo -e "${YELLOW}${WARNING} SKIPPED (missing files)${NC}"
    fi
    
    # Test 3: Internet Connection
    echo -ne "${WHITE}Testing internet connection...${NC} "
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}${CHECK} CONNECTED${NC}"
    else
        echo -e "${RED}${CROSS} OFFLINE${NC}"
    fi
    
    # Test 4: Service Status
    echo -ne "${WHITE}Checking service status...${NC} "
    if systemctl is-active --quiet gambino-pi 2>/dev/null; then
        echo -e "${GREEN}${CHECK} RUNNING${NC}"
    else
        echo -e "${YELLOW}${WARNING} STOPPED${NC}"
    fi
    
    # Test 5: Check .env configuration
    echo -ne "${WHITE}Checking configuration...${NC} "
    if [ -f ".env" ]; then
        local has_token=$(grep -c "MACHINE_TOKEN=" .env 2>/dev/null || echo 0)
        local has_endpoint=$(grep -c "API_ENDPOINT=" .env 2>/dev/null || echo 0)
        
        if [ $has_token -gt 0 ] && [ $has_endpoint -gt 0 ]; then
            local token_value=$(grep "MACHINE_TOKEN=" .env | cut -d'=' -f2)
            if [ "$token_value" != "your_jwt_token_here" ] && [ -n "$token_value" ]; then
                echo -e "${GREEN}${CHECK} CONFIGURED${NC}"
            else
                echo -e "${YELLOW}${WARNING} TOKEN NOT SET${NC}"
            fi
        else
            echo -e "${RED}${CROSS} INCOMPLETE${NC}"
        fi
    else
        echo -e "${RED}${CROSS} MISSING .env${NC}"
    fi
    
    echo ""
    echo -e "${DIM}Press any key to continue...${NC}"
    read -n 1 -s
}

show_system_info() {
    clear
    echo -e "${WHITE}${BOLD}📊 DETAILED SYSTEM INFORMATION${NC}"
    echo -e "${CYAN}═══════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}Hardware:${NC}"
    echo "  Pi Model: $(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo 'Unknown')"
    echo "  Memory: $(free -h | grep Mem | awk '{print $2}') total, $(free -h | grep Mem | awk '{print $7}') available"
    echo "  Storage: $(df -h / | tail -1 | awk '{print $2}') total, $(df -h / | tail -1 | awk '{print $4}') free"
    echo "  Temperature: $(vcgencmd measure_temp 2>/dev/null || echo 'N/A')"
    echo ""
    
    echo -e "${CYAN}Network:${NC}"
    echo "  Hostname: $(hostname)"
    echo "  Local IP: $(ip route get 8.8.8.8 | grep -oP 'src \K\S+' 2>/dev/null || echo 'Unknown')"
    if command -v tailscale >/dev/null 2>&1; then
        echo "  Tailscale IP: $(tailscale ip -4 2>/dev/null || echo 'Not connected')"
    fi
    echo ""
    
    echo -e "${CYAN}Software:${NC}"
    echo "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "  Kernel: $(uname -r)"
    echo "  Uptime: $(uptime -p)"
    echo "  Node.js: $(node --version 2>/dev/null || echo 'Not installed')"
    if systemctl is-active --quiet gambino-pi 2>/dev/null; then
        echo "  Gambino Service: Active (running)"
    else
        echo "  Gambino Service: $(systemctl is-active gambino-pi 2>/dev/null || echo 'Not running')"
    fi
    echo ""
    echo -e "${DIM}Press any key to continue...${NC}"
    read -n 1 -s
}

show_logs() {
    clear
    echo -e "${WHITE}${BOLD}📝 APPLICATION LOGS${NC}"
    echo -e "${CYAN}═══════════════════${NC}"
    echo ""
    echo -e "${WHITE}1.${NC} Live service logs (Ctrl+C to stop)"
    echo -e "${WHITE}2.${NC} Recent log entries"
    echo -e "${WHITE}3.${NC} Error logs only"
    echo -e "${WHITE}4.${NC} Return to main menu"
    echo ""
    echo -ne "${WHITE}${BOLD}Select option: ${NC}"
    
    read choice
    
    case $choice in
        1)
            clear
            echo -e "${CYAN}${BOLD}Live Service Logs (Press Ctrl+C to stop)${NC}"
            echo -e "${GRAY}========================================${NC}"
            sudo journalctl -u gambino-pi -f
            ;;
        2)
            clear
            echo -e "${CYAN}${BOLD}Recent Log Entries${NC}"
            echo -e "${GRAY}==================${NC}"
            sudo journalctl -u gambino-pi -n 30 --no-pager
            echo ""
            echo -e "${DIM}Press any key to continue...${NC}"
            read -n 1 -s
            ;;
        3)
            clear
            echo -e "${CYAN}${BOLD}Error Logs${NC}"
            echo -e "${GRAY}===========${NC}"
            sudo journalctl -u gambino-pi -p err --no-pager
            echo ""
            echo -e "${DIM}Press any key to continue...${NC}"
            read -n 1 -s
            ;;
        4)
            return
            ;;
    esac
}

show_deployment_checklist() {
    clear
    echo -e "${WHITE}${BOLD}📋 MINING FACILITY DEPLOYMENT CHECKLIST${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}🏗️ Pre-Deployment (Office):${NC}"
    echo "  □ Hardware tested and configured"
    echo "  □ Machine credentials from admin dashboard"
    echo "  □ WiFi networks configured for facilities"
    echo "  □ Tailscale remote access configured"
    echo "  □ All software tests passing"
    echo ""
    
    echo -e "${CYAN}📦 On-Site Installation:${NC}"
    echo "  □ Pi connected to facility network"
    echo "  □ USB-to-Serial adapter connected"
    echo "  □ DB-9 cable to Mutha Goose Port B"
    echo "  □ Service running and active"
    echo "  □ API connectivity verified"
    echo "  □ Live mining data flowing"
    echo ""
    
    echo -e "${CYAN}✅ Post-Deployment:${NC}"
    echo "  □ Dashboard shows device online"
    echo "  □ Mining events in real-time"
    echo "  □ Remote access working"
    echo "  □ On-site team trained"
    echo ""
    
    echo -e "${YELLOW}Quick Commands:${NC}"
    echo "  • Check status: sudo systemctl status gambino-pi"
    echo "  • View logs: sudo journalctl -u gambino-pi -f"
    echo "  • Test API: npm run test-api"
    echo ""
    echo -e "${DIM}Press any key to continue...${NC}"
    read -n 1 -s
}

show_documentation() {
    clear
    echo -e "${WHITE}${BOLD}📚 DOCUMENTATION & SUPPORT${NC}"
    echo -e "${CYAN}══════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}🌐 Online Resources:${NC}"
    echo "  • Main Site: https://gambino.gold"
    echo "  • Admin Dashboard: https://app.gambino.gold/admin"
    echo "  • Tailscale Admin: https://login.tailscale.com/admin"
    echo ""
    
    echo -e "${CYAN}🛠️ Management Scripts:${NC}"
    echo "  • ./gambino-main.sh - Main control center"
    echo "  • ./wifi-setup.sh - WiFi configuration"
    echo "  • ./tailscale-setup.sh - Remote access"
    echo "  • ./gambino-pi-manager.sh - App management"
    echo ""
    
    echo -e "${CYAN}🧪 Testing Commands:${NC}"
    echo "  • npm run test-api - Backend connectivity"
    echo "  • npm run test-serial - Hardware connection"
    echo "  • tailscale status - Remote access status"
    echo ""
    
    echo -e "${CYAN}📞 Support:${NC}"
    echo "  • Level 1: On-site IT support"
    echo "  • Level 2: Gambino development team"
    echo "  • Hardware: RKS Support (800) 360-1960"
    echo ""
    echo -e "${DIM}Press any key to continue...${NC}"
    read -n 1 -s
}

live_monitoring_dashboard() {
    local update_interval=3
    
    # Hide cursor for cleaner display
    tput civis
    
    # Trap to ensure cursor is restored on exit
    trap 'tput cnorm; exit' INT TERM EXIT
    
    echo -e "${CYAN}Starting live dashboard... Press Ctrl+C to quit${NC}"
    sleep 1
    
    while true; do
        clear
        
        # Header
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                    ${WHITE}${BOLD}📊 LIVE MINING OPERATIONS DASHBOARD 📊${NC}                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                         ${DIM}Press Ctrl+C to quit dashboard${NC}                         ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        
        # Live system status
        show_system_status
        
        # Additional real-time metrics
        echo ""
        echo -e "${CYAN}┌─────────────────────────── LIVE SYSTEM METRICS ───────────────────────────┐${NC}"
        echo -e "${CYAN}│                                                                          │${NC}"
        
        # CPU and load info
        local cpu_temp=$(vcgencmd measure_temp 2>/dev/null | cut -d'=' -f2 || echo "N/A")
        local load_avg=$(uptime | grep -oP 'load average: \K.*' || echo "unknown")
        local processes=$(ps aux | wc -l)
        local cpu_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null | awk '{printf "%.0f MHz", $1/1000}' || echo "unknown")
        
        printf "${CYAN}│${NC}  ${WHITE}CPU Temp:${NC} %-12s ${WHITE}Load Average:${NC} %-25s ${CYAN}│${NC}\n" "$cpu_temp" "$load_avg"
        printf "${CYAN}│${NC}  ${WHITE}CPU Freq:${NC} %-12s ${WHITE}Processes:${NC} %-15s ${CYAN}│${NC}\n" "$cpu_freq" "$processes"
        
        # Network stats
        local ip_addr=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "unknown")
        local tailscale_status_text="Offline"
        if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
            tailscale_status_text="Online"
        fi
        
        printf "${CYAN}│${NC}  ${WHITE}Local IP:${NC} %-13s ${WHITE}Tailscale:${NC} %-15s ${CYAN}│${NC}\n" "$ip_addr" "$tailscale_status_text"
        
        # Service status details
        if systemctl is-active --quiet gambino-pi 2>/dev/null; then
            local service_uptime=$(systemctl show -p ActiveEnterTimestamp gambino-pi 2>/dev/null | cut -d'=' -f2 | cut -d' ' -f2-3 || echo "unknown")
            printf "${CYAN}│${NC}  ${WHITE}Service:${NC} Active        ${WHITE}Started:${NC} %-15s ${CYAN}│${NC}\n" "$service_uptime"
        else
            printf "${CYAN}│${NC}  ${WHITE}Service:${NC} Inactive      ${WHITE}Status:${NC} Stopped       ${CYAN}│${NC}\n"
        fi
        
        echo -e "${CYAN}│                                                                          │${NC}"
        echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────┘${NC}"
        
        # Recent activity (if service is running)
        if systemctl is-active --quiet gambino-pi 2>/dev/null; then
            echo ""
            echo -e "${CYAN}┌────────────────────────── RECENT MINING ACTIVITY ─────────────────────────┐${NC}"
            echo -e "${CYAN}│                                                                          │${NC}"
            
            # Get last 4 log entries and format them nicely
            local log_count=0
            sudo journalctl -u gambino-pi -n 4 --no-pager -o cat 2>/dev/null | while IFS= read -r line; do
                if [ -n "$line" ] && [ $log_count -lt 4 ]; then
                    # Clean up the line and truncate if needed
                    local clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | cut -c1-70)
                    if [ -n "$clean_line" ]; then
                        printf "${CYAN}│${NC} ${WHITE}%s${NC}%*s${CYAN}│${NC}\n" "$clean_line" $((70-${#clean_line})) ""
                        log_count=$((log_count + 1))
                    fi
                fi
            done
            
            # Fill remaining lines if we have less than 4 log entries
            for ((i=log_count; i<4; i++)); do
                printf "${CYAN}│${NC}%72s${CYAN}│${NC}\n" ""
            done
            
            echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────┘${NC}"
        fi
        
        # Update timestamp and status
        local last_update=$(date '+%Y-%m-%d %H:%M:%S')
        echo ""
        echo -e "${DIM}Last updated: $last_update | Auto-refreshing every ${update_interval} seconds${NC}"
        echo -e "${DIM}Mining operations dashboard - Press Ctrl+C to return to main menu${NC}"
        
        # Simple sleep without trying to read input
        sleep $update_interval
    done
}

main_menu() {
    while true; do
        print_header
        show_system_status
        show_menu
        
        read choice
        
        case $choice in
            1)
                if check_script_exists "./wifi-setup.sh"; then
                    loading_message "Loading WiFi Configuration"
                    ./wifi-setup.sh
                else
                    echo -e "${RED}WiFi setup script not found${NC}"
                    sleep 2
                fi
                ;;
            2)
                if check_script_exists "./tailscale-setup.sh"; then
                    loading_message "Loading Tailscale Setup"
                    ./tailscale-setup.sh
                else
                    echo -e "${RED}Tailscale setup script not found${NC}"
                    sleep 2
                fi
                ;;
            3)
                if check_script_exists "./setup-pi.sh"; then
                    loading_message "Loading Pi Setup"
                    ./setup-pi.sh
                else
                    echo -e "${RED}Pi setup script not found${NC}"
                    sleep 2
                fi
                ;;
            4)
                if check_script_exists "./gambino-pi-manager.sh"; then
                    loading_message "Loading Application Manager"
                    ./gambino-pi-manager.sh
                else
                    echo -e "${RED}Application manager not found${NC}"
                    sleep 2
                fi
                ;;
            5)
                run_quick_tests
                ;;
            6)
                show_system_info
                ;;
            7)
                show_logs
                ;;
            8)
                if check_script_exists "./create-deployment-package.sh"; then
                    loading_message "Creating deployment package"
                    ./create-deployment-package.sh
                    echo ""
                    echo -e "${DIM}Press any key to continue...${NC}"
                    read -n 1 -s
                else
                    echo -e "${RED}Package creator not found${NC}"
                    sleep 2
                fi
                ;;
            9)
                show_deployment_checklist
                ;;
            10)
                clear
                echo -e "${YELLOW}${BOLD}Opening system shell...${NC}"
                echo -e "${DIM}Type 'exit' to return to Gambino control panel${NC}"
                echo ""
                bash
                ;;
            11)
                live_monitoring_dashboard
                ;;
            12)
                show_documentation
                ;;
            13)
                clear
                echo -e "${YELLOW}${BOLD}Thank you for using Gambino Gold! 🎉${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-13.${NC}"
                sleep 1
                ;;
        esac
    done
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        clear
        echo -e "${RED}${BOLD}⚠️  Security Notice${NC}"
        echo "Please run as regular user (not root)"
        echo ""
        exit 1
    fi
}

# Check terminal size
if [ "$TERM_WIDTH" -lt 80 ] || [ "$TERM_HEIGHT" -lt 24 ]; then
    clear
    echo -e "${RED}${BOLD}Terminal too small!${NC}"
    echo "Minimum required: 80x24 characters"
    echo "Current size: ${TERM_WIDTH}x${TERM_HEIGHT}"
    echo ""
    echo "Please resize your terminal window and try again."
    exit 1
fi

# Main execution
check_root
main_menu