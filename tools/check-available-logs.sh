#!/bin/bash
# Check what logs are actually available

echo "════════════════════════════════════════════════════════════"
echo "🔍 CHECKING AVAILABLE LOGS"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "1️⃣ Journalctl date range:"
OLDEST=$(sudo journalctl -u gambino-pi --no-pager | head -1 | awk '{print $1, $2, $3}')
NEWEST=$(sudo journalctl -u gambino-pi --no-pager | tail -1 | awk '{print $1, $2, $3}')
echo "   Oldest: $OLDEST"
echo "   Newest: $NEWEST"
echo ""

echo "2️⃣ Total log lines:"
TOTAL_LINES=$(sudo journalctl -u gambino-pi --no-pager | wc -l)
echo "   $TOTAL_LINES lines"
echo ""

echo "3️⃣ Searching for different log markers..."
echo ""

echo "   Looking for '📥 Line:'"
COUNT1=$(sudo journalctl -u gambino-pi --since "2025-10-14" --no-pager | grep -c "📥 Line:" || echo 0)
echo "   Found: $COUNT1"

echo ""
echo "   Looking for 'debug.*Line:'"
COUNT2=$(sudo journalctl -u gambino-pi --since "2025-10-14" --no-pager | grep -c "Line:" || echo 0)
echo "   Found: $COUNT2"

echo ""
echo "   Looking for 'Daily'"
COUNT3=$(sudo journalctl -u gambino-pi --since "2025-10-14" --no-pager | grep -c "Daily" || echo 0)
echo "   Found: $COUNT3"

echo ""
echo "   Looking for 'Parsed event'"
COUNT4=$(sudo journalctl -u gambino-pi --since "2025-10-14" --no-pager | grep -c "Parsed event" || echo 0)
echo "   Found: $COUNT4"

echo ""
echo "4️⃣ Sample of recent logs (last 20 lines):"
sudo journalctl -u gambino-pi --no-pager | tail -20
echo ""

echo "5️⃣ October 17 around 18:07 (when we saw the report):"
sudo journalctl -u gambino-pi --since "2025-10-17 18:07:00" --until "2025-10-17 18:08:00" --no-pager | head -30
echo ""

echo "════════════════════════════════════════════════════════════"
echo "💡 RECOMMENDATIONS"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "If we found 'Daily' lines but no '📥 Line:' markers, then:"
echo "  → The log format changed or debug logging is off"
echo "  → We can modify backfill tool to use different markers"
echo ""
echo "If we found 'Parsed event' lines:"
echo "  → We can extract events from those instead"
echo ""
echo "If logs are empty:"
echo "  → Journalctl retention is short or logs were rotated"
echo "  → We'll need to use current data going forward"
