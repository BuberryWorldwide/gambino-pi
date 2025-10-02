#!/bin/bash
# Simple Gambino Pi Manager - One script that actually works

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}                           🎰 GAMBINO PI MANAGER 🎰${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Find our working directory
if [ -f "./src/main.js" ]; then
    APP_DIR="$(pwd)"
elif [ -f "./gambino-pi-app/src/main.js" ]; then
    APP_DIR="$(pwd)/gambino-pi-app"
    cd "$APP_DIR"
else
    echo -e "${RED}❌ Error: Can't find Gambino Pi app directory${NC}"
    exit 1
fi

echo -e "${GREEN}📂 Working in: $APP_DIR${NC}"
echo ""

while true; do
    echo -e "${YELLOW}What do you want to do?${NC}"
    echo ""
    echo "  1. 🔧 Service Management (start/stop/restart/status)"
    echo "  2. 🗺️  Machine Mapping (add/list machines)"
    echo "  3. 📊 System Status & Logs"
    echo "  4. 🧪 Run Tests"
    echo "  5. ⚙️  Configuration"
    echo "  6. 🚪 Exit"
    echo ""
    
    read -p "Choose (1-6): " choice
    echo ""
    
    case $choice in
        1)
            echo -e "${BLUE}🔧 SERVICE MANAGEMENT${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "Current service status:"
            if systemctl is-active --quiet gambino-pi 2>/dev/null; then
                echo -e "${GREEN}✅ Service is running${NC}"
            else
                echo -e "${RED}❌ Service is not running${NC}"
            fi
            echo ""
            echo "What do you want to do?"
            echo "  a) 📊 Check status"
            echo "  b) ▶️  Start service"
            echo "  c) ⏹️  Stop service" 
            echo "  d) 🔄 Restart service"
            echo "  e) 📜 View live logs"
            echo "  f) 🔙 Back to main menu"
            echo ""
            read -p "Choose (a-f): " service_choice
            
            case $service_choice in
                a) sudo systemctl status gambino-pi || echo "Service not installed" ;;
                b) sudo systemctl start gambino-pi && echo -e "${GREEN}✅ Service started${NC}" ;;
                c) sudo systemctl stop gambino-pi && echo -e "${YELLOW}⏹️ Service stopped${NC}" ;;
                d) sudo systemctl restart gambino-pi && echo -e "${GREEN}🔄 Service restarted${NC}" ;;
                e) echo "Press Ctrl+C to exit logs"; journalctl -u gambino-pi -f ;;
                f) continue ;;
                *) echo "Invalid choice" ;;
            esac
            ;;
            
        2)
            echo -e "${BLUE}🗺️ MACHINE MAPPING${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "What do you want to do?"
            echo "  a) 📋 List current mappings"
            echo "  b) ➕ Add new machine mapping"
            echo "  c) 📱 Display QR code for machine"
            echo "  d) 🔄 Sync QR codes"
            echo "  e) 🔙 Back to main menu"
            echo ""
            read -p "Choose (a-e): " mapping_choice
            
            case $mapping_choice in
                a) 
                    if [ -f "./list-mappings.sh" ]; then
                        ./list-mappings.sh
                    else
                        echo -e "${RED}❌ list-mappings.sh not found${NC}"
                    fi
                    ;;
                b)
                    if [ -f "./map-machine.sh" ]; then
                        read -p "Enter Mutha Goose number (1-63): " goose_num
                        read -p "Enter Machine ID: " machine_id
                        if [ -n "$goose_num" ] && [ -n "$machine_id" ]; then
                            ./map-machine.sh "$goose_num" "$machine_id"
                        else
                            echo -e "${RED}❌ Both values required${NC}"
                        fi
                    else
                        echo -e "${RED}❌ map-machine.sh not found${NC}"
                    fi
                    ;;
                c)
                    if [ -f "./display-qr.sh" ]; then
                        read -p "Enter Machine ID for QR display: " machine_id
                        ./display-qr.sh "$machine_id"
                    else
                        echo -e "${RED}❌ display-qr.sh not found${NC}"
                    fi
                    ;;
                d)
                    if [ -f "./sync-qr-codes.sh" ]; then
                        ./sync-qr-codes.sh
                    else
                        echo -e "${RED}❌ sync-qr-codes.sh not found${NC}"
                    fi
                    ;;
                e) continue ;;
                *) echo "Invalid choice" ;;
            esac
            ;;
            
        3)
            echo -e "${BLUE}📊 SYSTEM STATUS${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "System Information:"
            echo "  Hostname: $(hostname)"
            echo "  Uptime: $(uptime -p)"
            echo "  Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
            echo "  Disk: $(df -h . | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"
            echo ""
            
            echo "Gambino Pi Status:"
            if systemctl is-active --quiet gambino-pi 2>/dev/null; then
                echo -e "  Service: ${GREEN}Running${NC}"
            else
                echo -e "  Service: ${RED}Stopped${NC}"
            fi
            
            if [ -f "./data/gambino-pi.db" ]; then
                db_size=$(ls -lh ./data/gambino-pi.db | awk '{print $5}')
                echo "  Database: $db_size"
            fi
            
            if [ -f "./logs/combined.log" ]; then
                echo "  Latest logs:"
                tail -5 ./logs/combined.log | sed 's/^/    /'
            fi
            echo ""
            echo "Press Enter to continue..."
            read
            ;;
            
        4)
            echo -e "${BLUE}🧪 TESTING${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "Available tests:"
            echo "  a) 🌐 Test API connection"
            echo "  b) 📡 Test serial port"
            echo "  c) 🗃️  Browse database"
            echo "  d) 🎭 Run mock Mutha Goose"
            echo "  e) 🔙 Back to main menu"
            echo ""
            read -p "Choose (a-e): " test_choice
            
            case $test_choice in
                a) 
                    if [ -f "./tests/testAPI.js" ]; then
                        node ./tests/testAPI.js
                    else
                        echo -e "${RED}❌ testAPI.js not found${NC}"
                    fi
                    ;;
                b)
                    if [ -f "./tests/testSerial.js" ]; then
                        node ./tests/testSerial.js
                    else
                        echo -e "${RED}❌ testSerial.js not found${NC}"
                    fi
                    ;;
                c)
                    if [ -f "./tests/browseDatabase.js" ]; then
                        node ./tests/browseDatabase.js
                    else
                        echo -e "${RED}❌ browseDatabase.js not found${NC}"
                    fi
                    ;;
                d)
                    if [ -f "./tests/mockMuthaGoose.js" ]; then
                        echo "Starting mock Mutha Goose (Press Ctrl+C to stop)"
                        node ./tests/mockMuthaGoose.js
                    else
                        echo -e "${RED}❌ mockMuthaGoose.js not found${NC}"
                    fi
                    ;;
                e) continue ;;
                *) echo "Invalid choice" ;;
            esac
            ;;
            
        5)
            echo -e "${BLUE}⚙️ CONFIGURATION${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "Configuration options:"
            echo "  a) 📝 Edit main config (.env)"
            echo "  b) 📋 View current config"
            echo "  c) 🏗️  Run setup scripts"
            echo "  d) 🔙 Back to main menu"
            echo ""
            read -p "Choose (a-d): " config_choice
            
            case $config_choice in
                a)
                    if [ -f ".env" ]; then
                        nano .env
                    else
                        echo -e "${YELLOW}⚠️ .env file doesn't exist. Creating from template...${NC}"
                        if [ -f ".env.template" ]; then
                            cp .env.template .env
                            nano .env
                        else
                            echo -e "${RED}❌ No .env template found${NC}"
                        fi
                    fi
                    ;;
                b)
                    echo "Current configuration:"
                    if [ -f ".env" ]; then
                        grep -v "TOKEN\|PASSWORD" .env || echo "No safe config to display"
                    else
                        echo -e "${RED}❌ No .env file found${NC}"
                    fi
                    echo ""
                    echo "Press Enter to continue..."
                    read
                    ;;
                c)
                    echo "Available setup scripts:"
                    if [ -f "./setup/setup-pi.sh" ]; then
                        echo "  1) Main Pi setup"
                        echo "  2) WiFi setup"
                        echo "  3) Configure Pi"
                        read -p "Which setup? (1-3): " setup_choice
                        case $setup_choice in
                            1) ./setup/setup-pi.sh ;;
                            2) ./setup/wifi-setup.sh ;;
                            3) ./setup/configure-pi.sh ;;
                        esac
                    else
                        echo -e "${RED}❌ No setup scripts found${NC}"
                    fi
                    ;;
                d) continue ;;
                *) echo "Invalid choice" ;;
            esac
            ;;
            
        6)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
            
        *)
            echo -e "${RED}❌ Invalid choice. Please choose 1-6.${NC}"
            ;;
    esac
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
done
