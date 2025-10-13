#!/bin/bash
# Gambino Pi Log Viewer
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}                           🔍 GAMBINO PI LOG VIEWER 🔍${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

APP_DIR="$HOME/gambino-pi-app"

while true; do
    echo -e "${YELLOW}What logs do you want to see?${NC}"
    echo ""
    echo -e "  ${CYAN}LIVE LOGS:${NC}"
    echo "    1. 📡 Live Service Logs (systemd journal)"
    echo "    2. 🎫 Live Voucher Events Only"
    echo "    3. 📊 Live Daily Reports Only"
    echo "    4. 📄 Live Combined Log File"
    echo "    5. ⚠️  Live Errors Only"
    echo ""
    echo -e "  ${CYAN}RECENT LOGS:${NC}"
    echo "    6. 📜 Last 50 Lines (service)"
    echo "    7. 📜 Last 100 Lines (combined log)"
    echo "    8. 📜 Last 200 Lines (combined log)"
    echo ""
    echo -e "  ${CYAN}SEARCH & FILTER:${NC}"
    echo "    9. 🔍 Search for specific text"
    echo "   10. 🎰 Show Machine Events (by machine number)"
    echo "   11. 💰 Show All Money Events"
    echo "   12. ❌ Show All Errors"
    echo ""
    echo -e "  ${CYAN}SERVICE MANAGEMENT:${NC}"
    echo "   13. 📊 Service Status"
    echo "   14. 🔄 Restart Service"
    echo ""
    echo "   15. 🚪 Exit"
    echo ""
    read -p "Choose (1-15): " choice
    echo ""
    
    case $choice in
        1)
            echo -e "${GREEN}📡 Showing live service logs... (Ctrl+C to stop)${NC}"
            echo ""
            sleep 1
            sudo journalctl -u gambino-pi.service -f
            ;;
        2)
            echo -e "${GREEN}🎫 Showing live voucher events... (Ctrl+C to stop)${NC}"
            echo ""
            sleep 1
            tail -f "$APP_DIR/logs/combined.log" | grep --line-buffered -i "voucher\|🎫"
            ;;
        3)
            echo -e "${GREEN}📊 Showing live daily reports... (Ctrl+C to stop)${NC}"
            echo ""
            sleep 1
            tail -f "$APP_DIR/logs/combined.log" | grep --line-buffered -i "daily\|📊"
            ;;
        4)
            echo -e "${GREEN}📄 Showing live combined log... (Ctrl+C to stop)${NC}"
            echo ""
            sleep 1
            tail -f "$APP_DIR/logs/combined.log"
            ;;
        5)
            echo -e "${GREEN}⚠️  Showing live errors... (Ctrl+C to stop)${NC}"
            echo ""
            sleep 1
            tail -f "$APP_DIR/logs/error.log"
            ;;
        6)
            echo -e "${GREEN}📜 Last 50 lines from service:${NC}"
            echo ""
            sudo journalctl -u gambino-pi.service -n 50 --no-pager
            echo ""
            read -p "Press Enter to continue..."
            ;;
        7)
            echo -e "${GREEN}📜 Last 100 lines from combined log:${NC}"
            echo ""
            tail -100 "$APP_DIR/logs/combined.log"
            echo ""
            read -p "Press Enter to continue..."
            ;;
        8)
            echo -e "${GREEN}📜 Last 200 lines from combined log:${NC}"
            echo ""
            tail -200 "$APP_DIR/logs/combined.log" | less
            ;;
        9)
            echo -e "${CYAN}🔍 Enter search term:${NC}"
            read -p "> " search_term
            echo ""
            echo -e "${GREEN}Searching combined log for: ${search_term}${NC}"
            echo ""
            grep -i "$search_term" "$APP_DIR/logs/combined.log" | tail -50
            echo ""
            read -p "Press Enter to continue..."
            ;;
        10)
            echo -e "${CYAN}🎰 Enter machine number (e.g., 3, 06, 29):${NC}"
            read -p "> " machine_num
            echo ""
            echo -e "${GREEN}Showing events for machine ${machine_num}:${NC}"
            echo ""
            grep -i "machine.*${machine_num}\|machine_${machine_num}" "$APP_DIR/logs/combined.log" | tail -50
            echo ""
            read -p "Press Enter to continue..."
            ;;
        11)
            echo -e "${GREEN}💰 Showing all money events (last 50):${NC}"
            echo ""
            grep -i "money_in\|voucher\|collect\|\$[0-9]" "$APP_DIR/logs/combined.log" | tail -50
            echo ""
            read -p "Press Enter to continue..."
            ;;
        12)
            echo -e "${GREEN}❌ Showing all errors (last 50):${NC}"
            echo ""
            grep -i "error\|fail\|⚠" "$APP_DIR/logs/combined.log" | tail -50
            echo ""
            read -p "Press Enter to continue..."
            ;;
        13)
            echo -e "${GREEN}📊 Service Status:${NC}"
            echo ""
            sudo systemctl status gambino-pi.service --no-pager
            echo ""
            read -p "Press Enter to continue..."
            ;;
        14)
            echo -e "${YELLOW}🔄 Restarting service... (This will interrupt players!)${NC}"
            read -p "Are you sure? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                sudo systemctl restart gambino-pi.service
                echo -e "${GREEN}✅ Service restarted${NC}"
                sleep 2
            else
                echo "Cancelled."
            fi
            ;;
        15)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${NC}"
            sleep 1
            ;;
    esac
    
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}                           🔍 GAMBINO PI LOG VIEWER 🔍${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
done
