#!/bin/bash
# Check what the parser is doing

echo "═══════════════════════════════════════════"
echo "🔍 PARSER ACTIVITY CHECK"
echo "═══════════════════════════════════════════"
echo ""

echo "📊 Recent parsed events (last 10):"
sudo journalctl -u gambino-pi --since "1 hour ago" | grep "🎯 Parsed" | tail -10
echo ""

echo "⚠️  Lines being skipped/unrecognized:"
sudo journalctl -u gambino-pi --since "1 hour ago" | grep -E "Unrecognized|No pattern" | tail -10
echo ""

echo "📥 Raw lines received:"
sudo journalctl -u gambino-pi --since "1 hour ago" | grep "📥 Line:" | tail -10
echo ""

echo "🎫 Voucher-related lines:"
sudo journalctl -u gambino-pi --since "1 hour ago" | grep -i "voucher" | tail -10
echo ""

echo "💰 Money events:"
sudo journalctl -u gambino-pi --since "1 hour ago" | grep -E "money|Daily In|Daily.*Paid" | tail -10
echo ""

echo "📊 Events in SQLite (last 20):"
sqlite3 ~/gambino-pi-app/data/gambino-pi.db \
  "SELECT id, event_type, machine_id, amount, datetime(created_at, 'localtime') as created 
   FROM events 
   ORDER BY id DESC 
   LIMIT 20;"
echo ""

echo "🔢 Event counts by type:"
sqlite3 ~/gambino-pi-app/data/gambino-pi.db \
  "SELECT event_type, COUNT(*) as count 
   FROM events 
   GROUP BY event_type;"
