#!/bin/bash

# Tailscale Setup Script for Gambino Pi Devices
# Run this FIRST on a fresh Pi installation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                                                                              ║
    ║            ████████╗ █████╗ ██╗██╗     ███████╗ ██████╗ █████╗ ██╗          ║
    ║            ╚══██╔══╝██╔══██╗██║██║     ██╔════╝██╔════╝██╔══██╗██║          ║
    ║               ██║   ███████║██║██║     ███████╗██║     ███████║██║          ║
    ║               ██║   ██╔══██║██║██║     ╚════██║██║     ██╔══██║██║          ║
    ║               ██║   ██║  ██║██║███████╗███████║╚██████╗██║  ██║███████╗     ║
    ║               ╚═╝   ╚═╝  ╚═╝╚═╝╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚══════╝     ║
    ║                                                                              ║
    ║                    GAMBINO PI NETWORK SETUP UTILITY                         ║
    ║                                                                              ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║                     SECURE REMOTE ACCESS CONFIGURATION                      ║
    ║                          MESH NETWORK DEPLOYMENT                            ║
    ║                                                                              ║
    ║                            VERSION 1.0                                      ║
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

check_internet() {
    echo -e "${BLUE}Checking internet connectivity...${NC}"
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        echo -e "${RED}No internet connection. Please check network settings.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Internet connectivity: OK${NC}"
}

update_system() {
    echo -e "${BLUE}Updating system packages...${NC}"
    sudo apt update && sudo apt upgrade -y
    echo -e "${GREEN}System updated successfully${NC}"
}

install_essentials() {
    echo -e "${BLUE}Installing essential packages...${NC}"
    sudo apt install -y curl wget git vim htop iotop screen fail2ban ufw
    echo -e "${GREEN}Essential packages installed${NC}"
}

configure_firewall() {
    echo -e "${BLUE}Configuring basic firewall...${NC}"
    
    # Enable UFW
    sudo ufw --force enable
    
    # Allow SSH
    sudo ufw allow ssh
    
    # Allow Tailscale
    sudo ufw allow in on tailscale0
    
    # Allow common development ports (can be locked down later)
    sudo ufw allow 3000  # Node.js dev
    sudo ufw allow 3001  # API
    
    echo -e "${GREEN}Firewall configured${NC}"
}

install_tailscale() {
    echo -e "${BLUE}Installing Tailscale...${NC}"
    
    # Add Tailscale's package signing key and repository
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
    
    # Install Tailscale
    sudo apt update
    sudo apt install -y tailscale
    
    echo -e "${GREEN}Tailscale installed successfully${NC}"
}

configure_hostname() {
    echo ""
    echo -e "${YELLOW}Current hostname: $(hostname)${NC}"
    echo ""
    read -p "Enter descriptive hostname for this Pi (e.g., 'pi-casino1-floor2'): " new_hostname
    
    if [ ! -z "$new_hostname" ]; then
        echo -e "${BLUE}Setting hostname to: $new_hostname${NC}"
        sudo hostnamectl set-hostname "$new_hostname"
        
        # Update /etc/hosts
        sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts
        
        echo -e "${GREEN}Hostname updated to: $new_hostname${NC}"
        echo -e "${YELLOW}Reboot required for hostname change to fully take effect${NC}"
    fi
}

setup_tailscale_auth() {
    echo ""
    echo -e "${CYAN}Tailscale Authentication Setup${NC}"
    echo "============================================"
    echo ""
    echo "You have two options for authenticating this device:"
    echo ""
    echo "1. Interactive authentication (requires web browser)"
    echo "2. Auth key authentication (for automated setup)"
    echo ""
    
    read -p "Select authentication method (1-2): " auth_method
    
    case $auth_method in
        1)
            echo -e "${BLUE}Starting interactive authentication...${NC}"
            echo ""
            echo -e "${YELLOW}IMPORTANT: You'll need to visit the URL shown and authenticate${NC}"
            echo "Press Enter when ready..."
            read
            
            sudo tailscale up
            ;;
        2)
            echo ""
            echo "To use auth key authentication:"
            echo "1. Go to https://login.tailscale.com/admin/settings/keys"
            echo "2. Generate a reusable auth key"
            echo "3. Copy the key and paste it below"
            echo ""
            read -p "Enter Tailscale auth key: " auth_key
            
            if [ ! -z "$auth_key" ]; then
                echo -e "${BLUE}Authenticating with auth key...${NC}"
                sudo tailscale up --authkey="$auth_key"
            else
                echo -e "${RED}No auth key provided. Falling back to interactive auth.${NC}"
                sudo tailscale up
            fi
            ;;
        *)
            echo -e "${YELLOW}Invalid option. Using interactive authentication.${NC}"
            sudo tailscale up
            ;;
    esac
}

verify_tailscale() {
    echo -e "${BLUE}Verifying Tailscale connection...${NC}"
    
    # Check if Tailscale is running
    if sudo tailscale status >/dev/null 2>&1; then
        echo -e "${GREEN}Tailscale is running${NC}"
        
        # Show status
        echo ""
        echo -e "${CYAN}Tailscale Status:${NC}"
        sudo tailscale status
        
        # Get Tailscale IP
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not available")
        echo ""
        echo -e "${GREEN}Tailscale IP: $TAILSCALE_IP${NC}"
        
        return 0
    else
        echo -e "${RED}Tailscale is not running properly${NC}"
        return 1
    fi
}

setup_ssh_hardening() {
    echo -e "${BLUE}Hardening SSH configuration...${NC}"
    
    # Backup original config
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Create hardened SSH config
    sudo tee /etc/ssh/sshd_config.d/99-tailscale-hardening.conf > /dev/null << 'EOF'
# Hardened SSH configuration for Tailscale-connected Pis
Protocol 2
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
X11Forwarding no
AllowTcpForwarding yes
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10

# Allow access only from Tailscale network (100.x.x.x range)
# Comment out the next line if you need access from other networks
#ListenAddress 100.0.0.0/8
EOF
    
    # Restart SSH
    sudo systemctl restart ssh
    
    echo -e "${GREEN}SSH hardened for Tailscale access${NC}"
}

create_info_file() {
    echo -e "${BLUE}Creating device information file...${NC}"
    
    cat > ~/pi-device-info.txt << EOF
Gambino Pi Device Information
============================
Setup Date: $(date)
Hostname: $(hostname)
Tailscale IP: $(tailscale ip -4 2>/dev/null || echo "Not available")
Local IP: $(ip route get 8.8.8.8 | grep -oP 'src \K\S+' 2>/dev/null)
MAC Address: $(cat /sys/class/net/eth0/address 2>/dev/null || cat /sys/class/net/wlan0/address 2>/dev/null)
Serial Number: $(cat /proc/cpuinfo | grep Serial | cut -d' ' -f2)

Next Steps:
1. Run Gambino Pi setup: ./setup-pi.sh
2. Configure application: ./gambino-pi-manager.sh

Remote Access:
SSH: ssh $(whoami)@$(tailscale ip -4 2>/dev/null || echo "TAILSCALE_IP")
Web: (application will be available after setup)

Tailscale Network: $(sudo tailscale status --json 2>/dev/null | grep -o '"MagicDNSSuffix":"[^"]*"' | cut -d'"' -f4 || echo "Check with: sudo tailscale status")
EOF
    
    echo -e "${GREEN}Device info saved to ~/pi-device-info.txt${NC}"
}

main_setup() {
    print_banner
    
    echo "This script will:"
    echo "• Update the system"
    echo "• Install essential security tools"
    echo "• Configure firewall"
    echo "• Install and configure Tailscale"
    echo "• Harden SSH access"
    echo ""
    
    read -p "Continue with Tailscale setup? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    check_root
    check_internet
    update_system
    install_essentials
    configure_firewall
    install_tailscale
    configure_hostname
    setup_tailscale_auth
    
    if verify_tailscale; then
        setup_ssh_hardening
        create_info_file
        
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                    TAILSCALE SETUP COMPLETED!                       ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}Next Steps:${NC}"
        echo "1. ${YELLOW}Reboot the Pi${NC} (for hostname changes): sudo reboot"
        echo "2. ${YELLOW}Install Gambino Pi app${NC}: ./setup-pi.sh"
        echo "3. ${YELLOW}Remote management${NC}: ssh $(whoami)@$(tailscale ip -4 2>/dev/null)"
        echo ""
        echo -e "${CYAN}Device Information:${NC}"
        echo "Tailscale IP: ${GREEN}$(tailscale ip -4 2>/dev/null)${NC}"
        echo "Hostname: ${GREEN}$(hostname)${NC}"
        echo "Info file: ${GREEN}~/pi-device-info.txt${NC}"
        echo ""
        echo "You can now access this Pi remotely from any device on your Tailscale network!"
        
    else
        echo -e "${RED}Tailscale setup failed. Check the logs and try again.${NC}"
        exit 1
    fi
}

# Run main setup
main_setup
