#!/bin/bash

# WiFi Setup Script for Gambino Pi Devices
# Configures multiple WiFi networks for deployment across different locations

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

print_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                                                                              ║
    ║                 📶 GAMBINO PI WIFI CONFIGURATION UTILITY 📶                  ║
    ║                                                                              ║
    ║                    Configure Multiple WiFi Networks for                     ║
    ║                     Multi-Location Mining Deployments                       ║
    ║                                                                              ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo -e "${RED}Please run as regular user (not root)${NC}"
        exit 1
    fi
}

check_wifi_interface() {
    if ! iwconfig wlan0 >/dev/null 2>&1; then
        echo -e "${RED}WiFi interface (wlan0) not found!${NC}"
        echo "This script requires a WiFi-capable Pi."
        exit 1
    fi
    echo -e "${GREEN}WiFi interface detected${NC}"
}

show_current_status() {
    echo -e "${WHITE}Current WiFi Status:${NC}"
    echo "==================="
    
    if iwconfig wlan0 2>/dev/null | grep -q "ESSID:"; then
        current_ssid=$(iwconfig wlan0 | grep ESSID | cut -d'"' -f2)
        if [ -n "$current_ssid" ] && [ "$current_ssid" != "off/any" ]; then
            echo -e "📶 Connected to: ${GREEN}$current_ssid${NC}"
            ip_addr=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "unknown")
            echo -e "🌐 IP Address: ${GREEN}$ip_addr${NC}"
        else
            echo -e "📶 Status: ${YELLOW}WiFi enabled but not connected${NC}"
        fi
    else
        echo -e "📶 Status: ${RED}Not connected${NC}"
    fi
    
    echo ""
}

scan_networks() {
    echo -e "${BLUE}Scanning for available networks...${NC}"
    echo ""
    
    # Scan and format results
    sudo iwlist wlan0 scan 2>/dev/null | grep -E "(ESSID|Signal level)" | \
    while read line; do
        if echo "$line" | grep -q "ESSID"; then
            ssid=$(echo "$line" | cut -d'"' -f2)
            if [ -n "$ssid" ]; then
                printf "📡 %-30s" "$ssid"
            fi
        elif echo "$line" | grep -q "Signal level"; then
            signal=$(echo "$line" | grep -o "\-[0-9]*" | head -1)
            if [ -n "$signal" ]; then
                if [ "$signal" -gt -50 ]; then
                    echo -e " ${GREEN}Strong${NC}"
                elif [ "$signal" -gt -70 ]; then
                    echo -e " ${YELLOW}Medium${NC}"
                else
                    echo -e " ${RED}Weak${NC}"
                fi
            fi
        fi
    done
    echo ""
}

backup_config() {
    if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]; then
        sudo cp /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf.backup.$(date +%Y%m%d_%H%M%S)
        echo -e "${GREEN}✅ Existing configuration backed up${NC}"
    fi
}

get_country_code() {
    echo -e "${CYAN}Country Configuration:${NC}"
    echo "Enter your country code for regulatory compliance"
    echo "Common codes: US, CA, GB, DE, FR, AU, JP"
    echo ""
    
    read -p "Country code (default: US): " country_code
    country_code=${country_code:-US}
    echo -e "Selected: ${GREEN}$country_code${NC}"
    echo ""
}

create_base_config() {
    cat > /tmp/wpa_supplicant.conf << EOF
country=$country_code
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

EOF
}

add_network() {
    local network_num=$1
    local priority=$((20 - network_num))
    
    echo -e "${CYAN}Network #$network_num Configuration:${NC}"
    echo "=================================="
    
    # Show available networks
    echo -e "${YELLOW}Available networks (recent scan):${NC}"
    scan_networks
    
    echo ""
    read -p "📶 Network name (SSID): " ssid
    if [ -z "$ssid" ]; then
        return 1
    fi
    
    read -s -p "🔐 Password: " password
    echo ""
    
    read -p "📝 Description (e.g., 'Home', 'Office', 'Facility-North'): " description
    description=${description:-"Network $network_num"}
    
    # Validate inputs
    if [ -z "$password" ]; then
        echo -e "${RED}Password cannot be empty!${NC}"
        return 1
    fi
    
    # Add to config file
    cat >> /tmp/wpa_supplicant.conf << EOF
# $description (Priority: $priority)
network={
    ssid="$ssid"
    psk="$password"
    priority=$priority
}

EOF
    
    echo -e "${GREEN}✅ Network '$ssid' added with priority $priority${NC}"
    echo -e "${BLUE}💡 Higher priority = preferred connection${NC}"
    echo ""
    
    return 0
}

show_config_preview() {
    echo -e "${WHITE}📋 Configuration Preview:${NC}"
    echo "=========================="
    echo ""
    
    # Show networks with hidden passwords
    local network_count=0
    while IFS= read -r line; do
        if [[ $line =~ ^#.*\(Priority:.*\) ]]; then
            network_count=$((network_count + 1))
            echo -e "${CYAN}$network_count. $line${NC}"
        elif [[ $line =~ ^[[:space:]]*ssid= ]]; then
            echo "   📶 SSID: $(echo "$line" | cut -d'"' -f2)"
        elif [[ $line =~ ^[[:space:]]*priority= ]]; then
            echo "   🏆 Priority: $(echo "$line" | cut -d'=' -f2)"
            echo ""
        fi
    done < /tmp/wpa_supplicant.conf
    
    if [ $network_count -eq 0 ]; then
        echo -e "${YELLOW}No networks configured yet${NC}"
        return 1
    fi
    
    echo -e "${BLUE}💡 Pi will automatically connect to the highest priority available network${NC}"
    echo ""
    return 0
}

apply_configuration() {
    echo -e "${YELLOW}Applying WiFi configuration...${NC}"
    
    # Apply new configuration
    sudo cp /tmp/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf
    sudo chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
    sudo chown root:root /etc/wpa_supplicant/wpa_supplicant.conf
    
    echo "✅ Configuration file updated"
    
    # Restart WiFi services
    echo "🔄 Restarting WiFi services..."
    sudo wpa_cli -i wlan0 reconfigure >/dev/null 2>&1 || true
    sudo systemctl restart dhcpcd
    
    echo -e "${GREEN}✅ WiFi configuration applied successfully!${NC}"
    echo ""
}

test_connection() {
    echo -e "${BLUE}Testing WiFi connection...${NC}"
    echo ""
    
    # Wait for connection
    for i in {1..10}; do
        if iwconfig wlan0 2>/dev/null | grep -q "ESSID:"; then
            current_ssid=$(iwconfig wlan0 | grep ESSID | cut -d'"' -f2)
            if [ -n "$current_ssid" ] && [ "$current_ssid" != "off/any" ]; then
                echo -e "✅ ${GREEN}Successfully connected to: $current_ssid${NC}"
                
                # Get IP address
                ip_addr=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "unknown")
                echo -e "🌐 IP Address: ${GREEN}$ip_addr${NC}"
                
                # Test internet
                if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
                    echo -e "🌍 ${GREEN}Internet connection: Working${NC}"
                else
                    echo -e "🌍 ${YELLOW}Internet connection: Limited${NC}"
                fi
                return 0
            fi
        fi
        
        echo -n "."
        sleep 2
    done
    
    echo ""
    echo -e "${YELLOW}⚠️  No connection established yet${NC}"
    echo "This may be normal - some networks take longer to connect"
    echo "Check status with: iwconfig wlan0"
    return 1
}

export_config() {
    echo -e "${CYAN}Export Configuration:${NC}"
    echo "===================="
    echo ""
    
    local export_file="wifi-config-$(hostname)-$(date +%Y%m%d_%H%M%S).conf"
    
    # Create sanitized export (no passwords)
    cat /etc/wpa_supplicant/wpa_supplicant.conf | \
    sed 's/psk=".*"/psk="***HIDDEN***"/g' > "$export_file"
    
    echo "📁 Configuration exported to: $export_file"
    echo "🔐 Passwords are hidden for security"
    echo ""
    echo "To use on another Pi:"
    echo "1. Copy this file to the new Pi"
    echo "2. Edit and add real passwords"
    echo "3. Run: sudo cp $export_file /etc/wpa_supplicant/wpa_supplicant.conf"
    echo ""
}

cleanup() {
    rm -f /tmp/wpa_supplicant.conf
}

main_menu() {
    while true; do
        print_banner
        show_current_status
        
        echo -e "${WHITE}WiFi Configuration Options:${NC}"
        echo "=========================="
        echo "1. 📶 Scan for available networks"
        echo "2. ➕ Add WiFi networks (multi-location setup)"
        echo "3. 📋 View current configuration"
        echo "4. 🔄 Restart WiFi connection"
        echo "5. 📁 Export configuration"
        echo "6. 🧪 Test internet connection"
        echo "7. 🚪 Exit"
        echo ""
        
        read -p "Select option (1-7): " choice
        
        case $choice in
            1)
                scan_networks
                read -p "Press Enter to continue..."
                ;;
            2)
                configure_multiple_networks
                ;;
            3)
                view_current_config
                ;;
            4)
                restart_wifi
                ;;
            5)
                export_config
                read -p "Press Enter to continue..."
                ;;
            6)
                test_internet_only
                ;;
            7)
                echo "Goodbye!"
                cleanup
                exit 0
                ;;
            *)
                echo "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

configure_multiple_networks() {
    print_banner
    echo -e "${WHITE}Multi-Location WiFi Setup:${NC}"
    echo "=========================="
    echo ""
    echo "This will configure multiple WiFi networks for deployment"
    echo "across different mining facilities or locations."
    echo ""
    echo "The Pi will automatically connect to the highest priority"
    echo "network that's available at each location."
    echo ""
    
    read -p "Continue with network configuration? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 0
    fi
    
    backup_config
    get_country_code
    create_base_config
    
    echo -e "${CYAN}Adding WiFi Networks:${NC}"
    echo "===================="
    echo ""
    
    local network_count=0
    while true; do
        network_count=$((network_count + 1))
        
        echo -e "${YELLOW}➕ Adding Network #$network_count${NC}"
        
        if ! add_network $network_count; then
            network_count=$((network_count - 1))
            break
        fi
        
        if [ $network_count -ge 5 ]; then
            echo -e "${YELLOW}⚠️  Maximum of 5 networks recommended${NC}"
            break
        fi
        
        read -p "Add another network? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            break
        fi
        echo ""
    done
    
    if [ $network_count -eq 0 ]; then
        echo -e "${YELLOW}No networks configured.${NC}"
        cleanup
        return 0
    fi
    
    echo ""
    if show_config_preview; then
        read -p "Apply this configuration? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            apply_configuration
            test_connection
            
            echo ""
            echo -e "${GREEN}🎉 WiFi setup complete!${NC}"
            echo ""
            echo -e "${CYAN}Next steps:${NC}"
            echo "• Pi will auto-connect to available networks"
            echo "• Use 'iwconfig wlan0' to check connection status"
            echo "• Configure Tailscale for remote access"
            echo ""
        else
            echo -e "${YELLOW}Configuration not applied.${NC}"
        fi
    fi
    
    cleanup
    read -p "Press Enter to continue..."
}

view_current_config() {
    echo -e "${CYAN}Current WiFi Configuration:${NC}"
    echo "=========================="
    echo ""
    
    if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]; then
        # Show configuration with hidden passwords
        cat /etc/wpa_supplicant/wpa_supplicant.conf | \
        sed 's/psk=".*"/psk="***HIDDEN***"/g'
    else
        echo -e "${RED}No WiFi configuration found${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

restart_wifi() {
    echo -e "${BLUE}Restarting WiFi services...${NC}"
    
    sudo wpa_cli -i wlan0 reconfigure >/dev/null 2>&1 || true
    sudo systemctl restart dhcpcd
    
    echo -e "${GREEN}✅ WiFi services restarted${NC}"
    sleep 2
    test_connection
    read -p "Press Enter to continue..."
}

test_internet_only() {
    echo -e "${BLUE}Testing Internet Connection:${NC}"
    echo "=========================="
    echo ""
    
    # Test connectivity
    if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        echo -e "🌍 ${GREEN}Internet: Working${NC}"
        
        # Test DNS
        if ping -c 1 google.com >/dev/null 2>&1; then
            echo -e "🔍 ${GREEN}DNS: Working${NC}"
        else
            echo -e "🔍 ${YELLOW}DNS: Issues detected${NC}"
        fi
        
        # Show speed test suggestion
        echo ""
        echo -e "${CYAN}💡 For speed test, run: curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3${NC}"
        
    else
        echo -e "🌍 ${RED}Internet: No connection${NC}"
        echo ""
        echo -e "${YELLOW}Troubleshooting suggestions:${NC}"
        echo "• Check WiFi connection: iwconfig wlan0"
        echo "• Restart WiFi: option 4 in main menu"
        echo "• Verify network credentials"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main execution
trap cleanup EXIT

check_root
check_wifi_interface
main_menu