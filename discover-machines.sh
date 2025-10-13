#!/bin/bash
# Discover all machines by capturing daily report

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
echo -e "${BLUE}                        🔍 MACHINE DISCOVERY 🔍${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}This will discover all machines by monitoring the daily report.${NC}"
echo ""

# Show current known machines first
echo -e "${GREEN}Currently Known Machines:${NC}"
echo ""

CURRENT_COUNT=$(sqlite3 "$DB" "SELECT COUNT(DISTINCT machine_id) FROM events;")

if [ "$CURRENT_COUNT" -gt 0 ]; then
    echo -e "${CYAN}Machine ID | Total Events | Last Activity${NC}"
    echo "───────────┼──────────────┼──────────────────────"
    
    sqlite3 "$DB" <<EOF
SELECT 
    machine_id,
    COUNT(*) as events,
    datetime(MAX(timestamp), 'localtime') as last_seen
FROM events
GROUP BY machine_id
ORDER BY machine_id;
EOF
    echo ""
    echo -e "${MAGENTA}Total discovered: ${CURRENT_COUNT} machines${NC}"
else
    echo -e "${YELLOW}No machines discovered yet.${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Instructions
echo -e "${GREEN}📋 INSTRUCTIONS:${NC}"
echo ""
echo -e "${YELLOW}1. Go to the Mutha Goose controller${NC}"
echo -e "${YELLOW}2. Press the DAILY REPORT button/menu option${NC}"
echo -e "${YELLOW}3. This script will automatically capture all machines${NC}"
echo ""

# Get baseline before starting
BASELINE_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM events;")
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

echo -e "${CYAN}Monitoring for daily report... (Press Ctrl+C to cancel)${NC}"
echo -e "${CYAN}Watching database for new machine entries...${NC}"
echo ""

# Monitor for changes
DOTS=0
DISCOVERED_NEW=0

while true; do
    # Check for new entries
    NEW_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM events WHERE timestamp > datetime('$START_TIME');")
    
    if [ "$NEW_COUNT" -gt 0 ]; then
        # Get new machines discovered
        NEW_MACHINES=$(sqlite3 "$DB" <<EOF
SELECT DISTINCT machine_id
FROM events 
WHERE timestamp > datetime('$START_TIME')
AND raw_data LIKE '%Daily Summary%'
ORDER BY machine_id;
EOF
        )
        
        if [ ! -z "$NEW_MACHINES" ]; then
            echo -e "\n${GREEN}✅ Daily report detected! Capturing machines...${NC}\n"
            
            DISCOVERED_NEW=$(echo "$NEW_MACHINES" | wc -l)
            
            echo -e "${CYAN}Machines found in this report:${NC}"
            echo ""
            echo -e "${MAGENTA}Machine ID | Money In Today${NC}"
            echo "───────────┼───────────────"
            
            for machine in $NEW_MACHINES; do
                amount=$(sqlite3 "$DB" "SELECT amount FROM events WHERE machine_id = '$machine' AND raw_data LIKE '%Daily Summary%' ORDER BY timestamp DESC LIMIT 1;")
                printf "${GREEN}%-10s${NC} | ${CYAN}\$%.2f${NC}\n" "$machine" "$amount"
            done
            
            break
        fi
    fi
    
    # Animate waiting
    DOTS=$((DOTS + 1))
    if [ $DOTS -gt 3 ]; then
        DOTS=0
    fi
    
    printf "\r${CYAN}Waiting for daily report"
    for i in $(seq 1 $DOTS); do printf "."; done
    printf "   ${NC}"
    
    sleep 1
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Show updated totals
TOTAL_NOW=$(sqlite3 "$DB" "SELECT COUNT(DISTINCT machine_id) FROM events;")
echo -e "${GREEN}✅ Discovery Complete!${NC}"
echo ""
echo -e "${CYAN}Machines discovered this session: ${GREEN}${DISCOVERED_NEW}${NC}"
echo -e "${CYAN}Total machines now known: ${GREEN}${TOTAL_NOW}${NC}"
echo ""

# Show full machine list
echo -e "${MAGENTA}Complete Machine List:${NC}"
echo ""
echo -e "${CYAN}Machine ID | Total Events | Money In (All Time) | Vouchers${NC}"
echo "───────────┼──────────────┼────────────────────┼─────────"

sqlite3 "$DB" <<EOF
SELECT 
    machine_id,
    COUNT(*) as events,
    printf('\$%.2f', COALESCE(SUM(CASE WHEN event_type = 'money_in' THEN amount ELSE 0 END), 0)) as total_money_in,
    COUNT(CASE WHEN event_type = 'voucher' THEN 1 END) as vouchers
FROM events
GROUP BY machine_id
ORDER BY machine_id;
EOF

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "  1. ${CYAN}Go to admin panel:${NC} https://app.gambino.gold/admin"
echo "  2. ${CYAN}Navigate to:${NC} Stores → Gallatin Nimbus → Machines"
echo "  3. ${CYAN}Create mappings:${NC}"
echo ""

# Show example mappings
FIRST_THREE=$(sqlite3 "$DB" "SELECT machine_id FROM events GROUP BY machine_id ORDER BY machine_id LIMIT 3;")
for machine in $FIRST_THREE; do
    echo -e "     ${BLUE}${machine}${NC} → ${YELLOW}[Enter friendly name, location, etc.]${NC}"
done

echo "     ..."
echo ""

# Export option
read -p "Export machine list to file? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    OUTPUT="$APP_DIR/discovered_machines_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "DISCOVERED MACHINES - $(date)"
        echo "================================"
        echo ""
        echo "Total Machines: $TOTAL_NOW"
        echo ""
        echo "Machine List:"
        echo "-------------"
        sqlite3 "$DB" "SELECT machine_id FROM events GROUP BY machine_id ORDER BY machine_id;"
        echo ""
        echo "Detailed Stats:"
        echo "---------------"
        sqlite3 -column -header "$DB" <<EOF
SELECT 
    machine_id as "ID",
    COUNT(*) as "Events",
    printf('\$%.2f', COALESCE(SUM(CASE WHEN event_type = 'money_in' THEN amount ELSE 0 END), 0)) as "Money In",
    COUNT(CASE WHEN event_type = 'voucher' THEN 1 END) as "Vouchers"
FROM events
GROUP BY machine_id
ORDER BY machine_id;
EOF
    } > "$OUTPUT"
    
    echo -e "${GREEN}✅ Exported to: ${OUTPUT}${NC}"
    echo ""
fi

echo -e "${CYAN}Tip: To watch live voucher events:${NC}"
echo "  ${BLUE}./view-logs.sh${NC} → Choose option 2"
echo ""

