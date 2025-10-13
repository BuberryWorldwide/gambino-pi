#!/bin/bash
# Gambino Pi Reports Generator

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

APP_DIR="$HOME/gambino-pi-app"
DB="$APP_DIR/data/gambino-pi.db"
LOG="$APP_DIR/logs/combined.log"

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}                        📊 GAMBINO PI REPORTS 📊${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

while true; do
    echo -e "${YELLOW}What report do you want to see?${NC}"
    echo ""
    echo -e "${CYAN}DATABASE REPORTS:${NC}"
    echo "  1. 📊 Today's Summary (all machines)"
    echo "  2. 🎰 By Machine (pick a machine)"
    echo "  3. 🎫 All Vouchers Today"
    echo "  4. 💰 Money In/Out Today"
    echo "  5. 📈 Hourly Breakdown Today"
    echo ""
    echo -e "${CYAN}LOG REPORTS:${NC}"
    echo "  6. 📜 Recent Activity (last 50 events)"
    echo "  7. 🔥 Busiest Machines Today"
    echo "  8. ⚠️  Errors & Warnings Today"
    echo "  9. 🕐 Activity Timeline Today"
    echo ""
    echo -e "${CYAN}EXPORT:${NC}"
    echo "  10. 💾 Export Today's Data to CSV"
    echo "  11. 📄 Generate Full Report (text file)"
    echo ""
    echo "  12. 🚪 Exit"
    echo ""
    read -p "Choose (1-12): " choice
    echo ""
    
    case $choice in
        1)
            echo -e "${GREEN}📊 TODAY'S SUMMARY${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            TODAY=$(date +%Y-%m-%d)
            
            echo -e "${CYAN}Total Events Today:${NC}"
            sqlite3 "$DB" "SELECT COUNT(*) FROM events WHERE date(timestamp) = '$TODAY';"
            echo ""
            
            echo -e "${CYAN}Money In Today:${NC}"
            sqlite3 "$DB" "SELECT COALESCE(SUM(amount), 0) FROM events WHERE event_type = 'money_in' AND date(timestamp) = '$TODAY';" | awk '{printf "$%.2f\n", $1}'
            echo ""
            
            echo -e "${CYAN}Vouchers Printed Today:${NC}"
            VOUCHER_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM events WHERE event_type = 'voucher' AND date(timestamp) = '$TODAY';")
            VOUCHER_TOTAL=$(sqlite3 "$DB" "SELECT COALESCE(SUM(amount), 0) FROM events WHERE event_type = 'voucher' AND date(timestamp) = '$TODAY';")
            echo "$VOUCHER_COUNT vouchers totaling \$$(printf '%.2f' $VOUCHER_TOTAL)"
            echo ""
            
            echo -e "${CYAN}Active Machines Today:${NC}"
            sqlite3 "$DB" "SELECT DISTINCT machine_id FROM events WHERE date(timestamp) = '$TODAY' ORDER BY machine_id;"
            echo ""
            
            echo -e "${CYAN}Events by Machine:${NC}"
            echo -e "${MAGENTA}Machine ID       | Events | Money In  | Vouchers${NC}"
            echo "─────────────────┼────────┼───────────┼─────────"
            sqlite3 "$DB" <<EOF
SELECT 
    machine_id,
    COUNT(*) as events,
    printf('\$%.2f', COALESCE(SUM(CASE WHEN event_type = 'money_in' THEN amount ELSE 0 END), 0)) as money_in,
    COUNT(CASE WHEN event_type = 'voucher' THEN 1 END) as vouchers
FROM events 
WHERE date(timestamp) = '$TODAY'
GROUP BY machine_id
ORDER BY machine_id;
EOF
            echo ""
            read -p "Press Enter to continue..."
            ;;
            
        2)
            echo -e "${CYAN}🎰 Enter machine ID (e.g., machine_03, machine_29):${NC}"
            read -p "> " machine_id
            echo ""
            echo -e "${GREEN}📊 MACHINE REPORT: ${machine_id}${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            TODAY=$(date +%Y-%m-%d)
            
            echo -e "${CYAN}Total Events Today:${NC}"
            sqlite3 "$DB" "SELECT COUNT(*) FROM events WHERE machine_id = '$machine_id' AND date(timestamp) = '$TODAY';"
            echo ""
            
            echo -e "${CYAN}Money In Today:${NC}"
            sqlite3 "$DB" "SELECT COALESCE(SUM(amount), 0) FROM events WHERE machine_id = '$machine_id' AND event_type = 'money_in' AND date(timestamp) = '$TODAY';" | awk '{printf "$%.2f\n", $1}'
            echo ""
            
            echo -e "${CYAN}Vouchers Today:${NC}"
            VOUCHERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM events WHERE machine_id = '$machine_id' AND event_type = 'voucher' AND date(timestamp) = '$TODAY';")
            VOUCHER_AMT=$(sqlite3 "$DB" "SELECT COALESCE(SUM(amount), 0) FROM events WHERE machine_id = '$machine_id' AND event_type = 'voucher' AND date(timestamp) = '$TODAY';")
            echo "$VOUCHERS vouchers totaling \$$(printf '%.2f' $VOUCHER_AMT)"
            echo ""
            
            echo -e "${CYAN}Recent Events (last 10):${NC}"
            sqlite3 -header -column "$DB" "SELECT datetime(timestamp, 'localtime') as time, event_type, amount FROM events WHERE machine_id = '$machine_id' ORDER BY timestamp DESC LIMIT 10;"
            echo ""
            read -p "Press Enter to continue..."
            ;;
            
        3)
            echo -e "${GREEN}🎫 ALL VOUCHERS TODAY${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            TODAY=$(date +%Y-%m-%d)
            
            echo -e "${CYAN}Vouchers Printed Today:${NC}"
            sqlite3 -header -column "$DB" <<EOF
SELECT 
    datetime(timestamp, 'localtime') as Time,
    machine_id as Machine,
    printf('\$%.2f', amount) as Amount
FROM events 
WHERE event_type = 'voucher' AND date(timestamp) = '$TODAY'
ORDER BY timestamp DESC;
EOF
            echo ""
            
            TOTAL=$(sqlite3 "$DB" "SELECT COALESCE(SUM(amount), 0) FROM events WHERE event_type = 'voucher' AND date(timestamp) = '$TODAY';")
            COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM events WHERE event_type = 'voucher' AND date(timestamp) = '$TODAY';")
            echo -e "${MAGENTA}Total: $COUNT vouchers = \$$(printf '%.2f' $TOTAL)${NC}"
            echo ""
            read -p "Press Enter to continue..."
            ;;
            
        4)
            echo -e "${GREEN}💰 MONEY IN/OUT TODAY${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            TODAY=$(date +%Y-%m-%d)
            
            echo -e "${CYAN}Money In Events:${NC}"
            sqlite3 -header -column "$DB" <<EOF
SELECT 
    datetime(timestamp, 'localtime') as Time,
    machine_id as Machine,
    printf('\$%.2f', amount) as Amount
FROM events 
WHERE event_type = 'money_in' AND date(timestamp) = '$TODAY'
ORDER BY timestamp DESC
LIMIT 20;
EOF
            echo ""
            read -p "Press Enter to continue..."
            ;;
            
        5)
            echo -e "${GREEN}📈 HOURLY BREAKDOWN TODAY${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            TODAY=$(date +%Y-%m-%d)
            
            echo -e "${CYAN}Activity by Hour:${NC}"
            echo -e "${MAGENTA}Hour | Events | Money In  | Vouchers${NC}"
            echo "─────┼────────┼───────────┼─────────"
            sqlite3 "$DB" <<EOF
SELECT 
    strftime('%H:00', timestamp) as hour,
    COUNT(*) as events,
    printf('\$%.2f', COALESCE(SUM(CASE WHEN event_type = 'money_in' THEN amount ELSE 0 END), 0)) as money_in,
    COUNT(CASE WHEN event_type = 'voucher' THEN 1 END) as vouchers
FROM events 
WHERE date(timestamp) = '$TODAY'
GROUP BY strftime('%H', timestamp)
ORDER BY hour;
EOF
            echo ""
            read -p "Press Enter to continue..."
            ;;
            
        6)
            echo -e "${GREEN}📜 RECENT ACTIVITY (Last 50 Events)${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            sqlite3 -header -column "$DB" "SELECT datetime(timestamp, 'localtime') as Time, event_type as Type, machine_id as Machine, printf('\$%.2f', amount) as Amount FROM events ORDER BY timestamp DESC LIMIT 50;" | less
            ;;
            
        7)
            echo -e "${GREEN}🔥 BUSIEST MACHINES TODAY${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            TODAY=$(date +%Y-%m-%d)
            
            echo -e "${CYAN}Machines by Activity:${NC}"
            echo -e "${MAGENTA}Machine ID       | Total Events | Money In  ${NC}"
            echo "─────────────────┼──────────────┼───────────"
            sqlite3 "$DB" <<EOF
SELECT 
    machine_id,
    COUNT(*) as events,
    printf('\$%.2f', COALESCE(SUM(CASE WHEN event_type = 'money_in' THEN amount ELSE 0 END), 0)) as money_in
FROM events 
WHERE date(timestamp) = '$TODAY'
GROUP BY machine_id
ORDER BY events DESC;
EOF
            echo ""
            read -p "Press Enter to continue..."
            ;;
            
        8)
            echo -e "${GREEN}⚠️  ERRORS & WARNINGS TODAY${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            TODAY=$(date +%Y-%m-%d)
            strings "$LOG" | grep "$TODAY" | grep -i "error\|warn" | tail -50
            echo ""
            read -p "Press Enter to continue..."
            ;;
            
        9)
            echo -e "${GREEN}🕐 ACTIVITY TIMELINE TODAY${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            TODAY=$(date +%Y-%m-%d)
            
            sqlite3 "$DB" <<EOF
SELECT 
    datetime(timestamp, 'localtime') as Time,
    event_type,
    machine_id,
    printf('\$%.2f', amount) as Amount
FROM events 
WHERE date(timestamp) = '$TODAY'
ORDER BY timestamp DESC
LIMIT 100;
EOF
            echo ""
            read -p "Press Enter to continue..."
            ;;
            
        10)
            TODAY=$(date +%Y-%m-%d)
            OUTPUT="$APP_DIR/reports/report_$TODAY.csv"
            mkdir -p "$APP_DIR/reports"
            
            echo -e "${GREEN}💾 Exporting data to CSV...${NC}"
            echo ""
            
            sqlite3 -header -csv "$DB" "SELECT * FROM events WHERE date(timestamp) = '$TODAY' ORDER BY timestamp;" > "$OUTPUT"
            
            echo -e "${CYAN}Exported to: ${OUTPUT}${NC}"
            echo -e "${CYAN}Rows exported: $(wc -l < "$OUTPUT")${NC}"
            echo ""
            read -p "Press Enter to continue..."
            ;;
            
        11)
            TODAY=$(date +%Y-%m-%d)
            OUTPUT="$APP_DIR/reports/full_report_$TODAY.txt"
            mkdir -p "$APP_DIR/reports"
            
            echo -e "${GREEN}📄 Generating full report...${NC}"
            
            {
                echo "═══════════════════════════════════════════════════════════"
                echo "           GAMBINO PI DAILY REPORT"
                echo "           Date: $TODAY"
                echo "           Generated: $(date)"
                echo "═══════════════════════════════════════════════════════════"
                echo ""
                echo "SUMMARY"
                echo "───────────────────────────────────────────────────────────"
                echo "Total Events: $(sqlite3 "$DB" "SELECT COUNT(*) FROM events WHERE date(timestamp) = '$TODAY';")"
                echo "Money In: \$$(sqlite3 "$DB" "SELECT COALESCE(SUM(amount), 0) FROM events WHERE event_type = 'money_in' AND date(timestamp) = '$TODAY';")"
                echo "Vouchers: $(sqlite3 "$DB" "SELECT COUNT(*) FROM events WHERE event_type = 'voucher' AND date(timestamp) = '$TODAY';")"
                echo ""
                echo "BY MACHINE"
                echo "───────────────────────────────────────────────────────────"
                sqlite3 -column "$DB" "SELECT machine_id, COUNT(*) as events, COALESCE(SUM(amount), 0) as total FROM events WHERE date(timestamp) = '$TODAY' GROUP BY machine_id;"
                echo ""
                echo "HOURLY BREAKDOWN"
                echo "───────────────────────────────────────────────────────────"
                sqlite3 -column "$DB" "SELECT strftime('%H:00', timestamp) as hour, COUNT(*) as events FROM events WHERE date(timestamp) = '$TODAY' GROUP BY strftime('%H', timestamp);"
                echo ""
                echo "RECENT EVENTS"
                echo "───────────────────────────────────────────────────────────"
                sqlite3 -column "$DB" "SELECT datetime(timestamp, 'localtime'), event_type, machine_id, amount FROM events WHERE date(timestamp) = '$TODAY' ORDER BY timestamp DESC LIMIT 50;"
            } > "$OUTPUT"
            
            echo -e "${CYAN}Report saved to: ${OUTPUT}${NC}"
            echo ""
            read -p "Press Enter to continue..."
            ;;
            
        12)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
            
        *)
            echo -e "${RED}Invalid choice${NC}"
            sleep 1
            ;;
    esac
    
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}                        📊 GAMBINO PI REPORTS 📊${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
done
