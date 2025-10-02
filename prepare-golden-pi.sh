#!/bin/bash

# Prepare Golden Pi for Cloning Script
# This script cleans up device-specific data and prepares the Pi for SD card imaging
# Run this from your ~/gambino-pi-app/ directory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Directory paths based on your actual structure
PI_APP_DIR="$(pwd)"
HOME_DIR="/home/$(whoami)"

print_banner() {
    echo -e "${CYAN}"
    echo "=========================================="
    echo "  Gambino Pi Golden Image Preparation"
    echo "=========================================="
    echo -e "${NC}"
    echo "Working directory: $PI_APP_DIR"
    echo ""
}

confirm_action() {
    echo -e "${YELLOW}$1${NC}"
    read -p "Continue? (y/N): " response
    [[ $response =~ ^[Yy]$ ]]
}

backup_current_config() {
    echo -e "${BLUE}📦 Creating backup of current configuration...${NC}"
    
    BACKUP_DIR="$HOME_DIR/golden-pi-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup critical files that exist
    [ -f ".env" ] && cp ".env" "$BACKUP_DIR/"
    [ -f "data/machine-mappings.json" ] && cp "data/machine-mappings.json" "$BACKUP_DIR/"
    [ -f "data/machine-mappings-simple.json" ] && cp "data/machine-mappings-simple.json" "$BACKUP_DIR/"
    [ -f "data/gambino-pi.db" ] && cp "data/gambino-pi.db" "$BACKUP_DIR/"
    
    # Copy entire logs directory if it exists
    [ -d "logs" ] && cp -r "logs" "$BACKUP_DIR/"
    
    # Save current system info
    cat > "$BACKUP_DIR/system-info.txt" << EOF
Golden Pi System Info - $(date)
===============================
Hostname: $(hostname)
IP Address: $(ip route get 1 | awk '{print $7}' | head -1 2>/dev/null || echo "Unknown")
Tailscale IP: $(tailscale ip -4 2>/dev/null || echo "Not configured")
Working Directory: $PI_APP_DIR
Machine ID: $(grep MACHINE_ID .env 2>/dev/null | cut -d'=' -f2 || echo "Not set")
Store ID: $(grep STORE_ID .env 2>/dev/null | cut -d'=' -f2 || echo "Not set")
Serial Port: $(grep SERIAL_PORT .env 2>/dev/null | cut -d'=' -f2 || echo "Not set")
Service Status: $(systemctl is-active gambino-pi 2>/dev/null || echo "Not installed")
Node.js Version: $(node --version 2>/dev/null || echo "Not installed")
NPM Version: $(npm --version 2>/dev/null || echo "Not installed")
Database Size: $(du -h data/gambino-pi.db 2>/dev/null || echo "Not found")
EOF
    
    echo -e "${GREEN}✅ Backup created at: $BACKUP_DIR${NC}"
    echo "Keep this backup to restore your Golden Pi if needed!"
    echo ""
}

stop_services() {
    echo -e "${BLUE}🛑 Stopping services...${NC}"
    
    # Check if it's running as a system service
    if systemctl is-active gambino-pi >/dev/null 2>&1; then
        sudo systemctl stop gambino-pi
        echo "  - Stopped gambino-pi system service"
    else
        echo "  - No gambino-pi system service found"
    fi
    
    # Kill any running Node.js processes in this directory
    PIDS=$(ps aux | grep "node.*$PI_APP_DIR" | grep -v grep | awk '{print $2}' || true)
    if [ ! -z "$PIDS" ]; then
        echo "  - Stopping Node.js processes: $PIDS"
        kill $PIDS 2>/dev/null || true
        sleep 2
    fi
    
    echo -e "${GREEN}✅ Services stopped${NC}"
    echo ""
}

clean_logs_and_data() {
    echo -e "${BLUE}🧹 Cleaning logs and temporary data...${NC}"
    
    # Clear application logs but keep directory structure
    if [ -d "logs" ]; then
        > logs/combined.log 2>/dev/null || true
        > logs/error.log 2>/dev/null || true
        echo "  - Cleared application logs"
    fi
    
    # Clear database events but keep structure
    if [ -f "data/gambino-pi.db" ]; then
        if command -v sqlite3 >/dev/null; then
            sqlite3 data/gambino-pi.db "DELETE FROM events WHERE 1=1;" 2>/dev/null || true
            sqlite3 data/gambino-pi.db "DELETE FROM sync_queue WHERE 1=1;" 2>/dev/null || true
            sqlite3 data/gambino-pi.db "VACUUM;" 2>/dev/null || true
            echo "  - Cleared database events and sync queue"
        else
            echo "  - Skipped database cleanup (sqlite3 not available)"
        fi
    fi
    
    # Clear event queue file
    if [ -f "data/event_queue.json" ]; then
        echo "[]" > data/event_queue.json
        echo "  - Cleared event queue file"
    fi
    
    # Clear test results
    if [ -d "test-results" ]; then
        rm -rf test-results/*
        echo "  - Cleared test results"
    fi
    
    # Clear any backup files in data directory
    if [ -d "data/backups" ]; then
        rm -rf data/backups/*
        echo "  - Cleared data backups"
    fi
    
    # Clear system logs
    sudo journalctl --rotate 2>/dev/null || true
    sudo journalctl --vacuum-time=1s 2>/dev/null || true
    echo "  - Cleared system logs"
    
    # Clear temporary files
    sudo rm -rf /tmp/* 2>/dev/null || true
    sudo rm -rf /var/tmp/* 2>/dev/null || true
    echo "  - Cleared temporary files"
    
    # Clear bash history for current user
    history -c 2>/dev/null || true
    > ~/.bash_history 2>/dev/null || true
    echo "  - Cleared bash history"
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
    echo ""
}

generalize_configuration() {
    echo -e "${BLUE}⚙️  Generalizing configuration...${NC}"
    
    # Create template .env file
    if [ -f ".env" ]; then
        cat > ".env.template" << 'EOF'
# Gambino Pi Configuration Template
# Copy this to .env and customize for each device

MACHINE_ID=CHANGE_ME
STORE_ID=CHANGE_ME
API_ENDPOINT=https://api.gambino.gold
MACHINE_TOKEN=CHANGE_ME

# Serial Configuration
SERIAL_PORT=/dev/ttyUSB0

# Logging
LOG_LEVEL=info

# Environment
NODE_ENV=production
EOF
        echo "  - Created .env template"
        
        # Remove the actual .env to prevent conflicts
        rm ".env"
        echo "  - Removed device-specific .env"
    fi
    
    # Remove device-specific mappings
    if [ -f "data/machine-mappings.json" ]; then
        rm "data/machine-mappings.json"
        echo "  - Removed device-specific machine mappings"
    fi
    
    if [ -f "data/machine-mappings-simple.json" ]; then
        rm "data/machine-mappings-simple.json"
        echo "  - Removed device-specific simple mappings"
    fi
    
    # Create first-boot setup script
    cat > "first-boot-setup.sh" << 'EOF'
#!/bin/bash

# First Boot Setup for Cloned Pi
# Run this script on first boot of a cloned Pi device

set -e

echo "🚀 Gambino Pi First Boot Setup"
echo "============================="

# Check if already configured
if [ -f ".env" ]; then
    echo "❌ Pi appears to be already configured."
    echo "Delete .env file to reconfigure, or run:"
    echo "rm .env && ./first-boot-setup.sh"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f ".env.template" ] || [ ! -d "src" ]; then
    echo "❌ Please run this script from the gambino-pi-app directory"
    exit 1
fi

echo ""
echo "📋 Configuration Setup"
echo "---------------------"

# Copy template to active config
cp .env.template .env

echo ""
read -p "Machine ID (e.g., hub-casino1-floor2): " MACHINE_ID
read -p "Store ID: " STORE_ID
echo ""
echo "🔐 Get your machine token from the admin dashboard:"
echo "   1. Login to admin dashboard"
echo "   2. Find or create machine: $MACHINE_ID"
echo "   3. Copy the connection token"
echo ""
read -p "Machine Token: " MACHINE_TOKEN

# Update configuration
sed -i "s/MACHINE_ID=CHANGE_ME/MACHINE_ID=$MACHINE_ID/" .env
sed -i "s/STORE_ID=CHANGE_ME/STORE_ID=$STORE_ID/" .env
sed -i "s/MACHINE_TOKEN=CHANGE_ME/MACHINE_TOKEN=$MACHINE_TOKEN/" .env

echo ""
echo "✅ Configuration saved!"
echo ""
echo "🔧 Installing dependencies..."
npm install

echo ""
echo "🧪 Testing configuration..."
npm run test-api

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Set up WiFi: sudo raspi-config (if needed)"
echo "2. Set up Tailscale: curl -fsSL https://tailscale.com/install.sh | sh"
echo "3. Test serial connection: npm run test-serial"
echo "4. Start service: npm start"
echo ""
echo "For management, use: ./manager.sh"
EOF
    
    chmod +x "first-boot-setup.sh"
    echo "  - Created first-boot setup script"
    
    echo -e "${GREEN}✅ Configuration generalized${NC}"
    echo ""
}

reset_hostname() {
    echo -e "${BLUE}🏷️  Resetting hostname to generic...${NC}"
    
    CURRENT_HOSTNAME=$(hostname)
    NEW_HOSTNAME="gambino-pi-template"
    
    if [ "$CURRENT_HOSTNAME" != "$NEW_HOSTNAME" ]; then
        if confirm_action "Change hostname from '$CURRENT_HOSTNAME' to '$NEW_HOSTNAME'?"; then
            sudo hostnamectl set-hostname "$NEW_HOSTNAME"
            
            # Update /etc/hosts
            sudo sed -i "s/$CURRENT_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
            
            echo "  - Hostname changed to $NEW_HOSTNAME"
        else
            echo "  - Keeping current hostname: $CURRENT_HOSTNAME"
        fi
    else
        echo "  - Hostname already generic"
    fi
    
    echo -e "${GREEN}✅ Hostname step completed${NC}"
    echo ""
}

reset_network_config() {
    echo -e "${BLUE}🌐 Resetting network configuration...${NC}"
    
    # Remove Tailscale if installed
    if command -v tailscale >/dev/null; then
        if confirm_action "Remove Tailscale configuration? (You'll need to re-setup on each cloned Pi)"; then
            sudo tailscale logout 2>/dev/null || true
            echo "  - Tailscale logged out"
        fi
    fi
    
    # Clear WiFi saved networks (be careful with this)
    if confirm_action "Clear saved WiFi networks? (Recommended for different deployment locations)"; then
        # Backup current wifi config
        sudo cp /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf.backup 2>/dev/null || true
        echo "  - WiFi config backed up"
        echo "  - Note: Current connection will remain until reboot"
    fi
    
    # Clear SSH host keys (will be regenerated on boot)
    if confirm_action "Regenerate SSH host keys? (Recommended for security)"; then
        sudo rm -f /etc/ssh/ssh_host_*
        sudo systemctl enable ssh
        echo "  - SSH host keys will be regenerated on next boot"
    fi
    
    echo -e "${GREEN}✅ Network configuration reset${NC}"
    echo ""
}

create_cloning_instructions() {
    echo -e "${BLUE}📋 Creating cloning instructions...${NC}"
    
    cat > "$HOME_DIR/CLONING_INSTRUCTIONS.md" << 'EOF'
# Gambino Pi Cloning Instructions

## Overview
Your Golden Pi is now prepared for cloning. The setup creates identical Pi devices that can be quickly configured with unique settings.

## SD Card Cloning Process

### 1. Create the Master Image
```bash
# Power down the Golden Pi
sudo shutdown -h now

# Remove SD card and create image using a card reader on your computer
sudo dd if=/dev/sdX of=gambino-pi-golden.img bs=4M status=progress
# Replace /dev/sdX with your actual SD card device (check with 'lsblk')

# Optional: Compress the image to save space
gzip gambino-pi-golden.img
```

### 2. Deploy to New Pi Devices
```bash
# Flash image to new SD cards
sudo dd if=gambino-pi-golden.img of=/dev/sdX bs=4M status=progress
# Or if compressed: gunzip -c gambino-pi-golden.img.gz | sudo dd of=/dev/sdX bs=4M status=progress

# Safely eject the SD card
sync && sudo eject /dev/sdX
```

### 3. First Boot Setup on Each New Pi

1. **Insert SD card and boot the new Pi**
2. **SSH into the new Pi** (default credentials still apply)
3. **Navigate to the app directory:**
   ```bash
   cd ~/gambino-pi-app
   ```
4. **Run the first-boot setup:**
   ```bash
   ./first-boot-setup.sh
   ```
5. **Follow the prompts** to enter unique configuration

### 4. Complete Setup on Each Pi

After running first-boot-setup.sh, also configure:

#### WiFi Setup (if needed):
```bash
sudo raspi-config
# Navigate to Network Options > Wi-Fi
```

#### Tailscale Setup:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

#### Verify Everything:
```bash
# Check API connection
npm run test-api

# Test serial (if hardware connected)
npm run test-serial

# Start the application
npm start

# Or use the manager interface
./manager.sh
```

## Device Configuration Checklist

For each new Pi, you'll need:

- [ ] **Unique Machine ID** (e.g., hub-casino1-floor2)
- [ ] **Store ID** (from admin dashboard)
- [ ] **Machine Token** (generate in admin dashboard)
- [ ] **WiFi credentials** (if using WiFi)
- [ ] **Tailscale setup** (for remote access)
- [ ] **Serial port verification** (/dev/ttyUSB0 typically)

## Quick Device Info Template

Document each Pi:
```
Pi #1:
- Machine ID: ________________________
- Store ID: __________________________
- Location: __________________________
- Tailscale IP: _______________________
- Local IP: ___________________________
- Serial Port: _______________________
- Notes: _____________________________

Pi #2:
- Machine ID: ________________________
- Store ID: __________________________
- Location: __________________________
- Tailscale IP: _______________________
- Local IP: ___________________________
- Serial Port: _______________________
- Notes: _____________________________

Pi #3:
- Machine ID: ________________________
- Store ID: __________________________
- Location: __________________________
- Tailscale IP: _______________________
- Local IP: ___________________________
- Serial Port: _______________________
- Notes: _____________________________
```

## Troubleshooting

### If first-boot-setup.sh fails:
1. Check you're in the right directory (`~/gambino-pi-app`)
2. Verify `.env.template` exists
3. Check internet connectivity
4. Run `npm install` manually if needed

### If API test fails:
1. Verify machine token from admin dashboard
2. Check API endpoint is reachable
3. Confirm machine is created in admin dashboard

### If SSH doesn't work on new Pi:
1. SSH host keys regenerate on first boot (may take extra time)
2. Clear your SSH known_hosts: `ssh-keygen -R [pi-ip-address]`
3. Default credentials should still work initially

## Important Notes

- Each Pi needs a unique Machine ID and Token
- Machine tokens must be generated in the admin dashboard
- First boot takes longer due to SSH key generation
- Keep your device info documented for troubleshooting
- Test everything before deploying to production locations
EOF
    
    echo -e "${GREEN}✅ Cloning instructions created at: $HOME_DIR/CLONING_INSTRUCTIONS.md${NC}"
    echo ""
}

final_verification() {
    echo -e "${BLUE}✅ Final verification...${NC}"
    
    echo "Checking preparation status:"
    
    # Check if .env is removed
    if [ ! -f ".env" ]; then
        echo "  ✅ Device-specific .env removed"
    else
        echo "  ❌ .env file still exists"
    fi
    
    # Check if template exists
    if [ -f ".env.template" ]; then
        echo "  ✅ .env template created"
    else
        echo "  ❌ .env template missing"
    fi
    
    # Check if first-boot script exists
    if [ -f "first-boot-setup.sh" ] && [ -x "first-boot-setup.sh" ]; then
        echo "  ✅ First-boot setup script ready"
    else
        echo "  ❌ First-boot setup script missing or not executable"
    fi
    
    # Check database
    if [ -f "data/gambino-pi.db" ]; then
        echo "  ✅ Database structure preserved"
    else
        echo "  ❌ Database missing"
    fi
    
    # Check deployment package
    if [ -d "deploy-package" ]; then
        echo "  ✅ Deployment package available"
    else
        echo "  ❌ Deployment package missing"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 Golden Pi preparation complete!${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Power down: sudo shutdown -h now"
    echo "2. Remove SD card and create image with dd command"
    echo "3. Flash image to 3 new SD cards"
    echo "4. Boot new Pis and run ~/gambino-pi-app/first-boot-setup.sh"
    echo ""
    echo "📖 See $HOME_DIR/CLONING_INSTRUCTIONS.md for detailed instructions"
    echo ""
    echo -e "${CYAN}💾 Your backup is safely stored at:${NC}"
    ls -la "$HOME_DIR"/golden-pi-backup-* 2>/dev/null | tail -1 || echo "No backup found"
}

main() {
    print_banner
    
    # Verify we're in the right directory
    if [ ! -d "src" ] || [ ! -f "package.json" ]; then
        echo -e "${RED}❌ Error: Please run this script from your gambino-pi-app directory${NC}"
        echo "Expected to find 'src' directory and 'package.json'"
        echo "Current directory: $(pwd)"
        exit 1
    fi
    
    echo "This script will prepare your Golden Pi for cloning by:"
    echo "• Creating a backup of current configuration"
    echo "• Stopping any running services"
    echo "• Cleaning logs and temporary data"
    echo "• Removing device-specific settings"
    echo "• Creating setup templates for new devices"
    echo "• Optionally resetting network configuration"
    echo ""
    
    if ! confirm_action "Prepare this Pi for cloning?"; then
        echo "Preparation cancelled."
        exit 0
    fi
    
    echo ""
    backup_current_config
    stop_services
    clean_logs_and_data
    generalize_configuration
    reset_hostname
    reset_network_config
    create_cloning_instructions
    final_verification
    
    echo -e "${CYAN}🎉 Golden Pi is ready for cloning!${NC}"
}

# Check if running as correct user
if [ "$EUID" -eq 0 ]; then
    echo "Please run as regular user (not root)"
    exit 1
fi

main "$@"
