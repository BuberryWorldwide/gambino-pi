#!/bin/bash

# Gambino Pi Service Log Analyzer
# Analyzes logs from systemd journal

SERVICE_NAME="gambino-pi"

echo "=========================================="
echo "Gambino Pi Service Log Analyzer"
echo "=========================================="
echo ""

# Check if service exists
if ! systemctl list-units --full -all | grep -q "$SERVICE_NAME.service"; then
    echo "❌ Service '$SERVICE_NAME' not found"
    exit 1
fi

# Service status
echo "🔧 Service Status:"
echo "----------------------------------------"
systemctl status gambino-pi --no-pager | head -n 5
echo ""

# Log statistics
echo "📊 Log Statistics (Today):"
echo "----------------------------------------"
total_lines=$(sudo journalctl -u gambino-pi --since today | wc -l)
raw_data=$(sudo journalctl -u gambino-pi --since today | grep -c "Raw serial data" || echo "0")
parsed=$(sudo journalctl -u gambino-pi --since today | grep -c "Parsed event" || echo "0")
errors=$(sudo journalctl -u gambino-pi --since today | grep -c -i "error" || echo "0")

echo "Total log entries: $total_lines"
echo "Raw serial data: $raw_data"
echo "Parsed events: $parsed"
echo "Errors: $errors"
echo ""

# Machine activity
echo "🎰 Machine Activity (Today):"
echo "----------------------------------------"
for machine in 29 30 31 32 33 34 35 36; do
    count=$(sudo journalctl -u gambino-pi --since today | grep -c "MACHINE $machine" || echo "0")
    if [ "$count" -gt 0 ]; then
        printf "Machine %2d: %4d events\n" "$machine" "$count"
    fi
done
echo ""

# Event types
echo "💰 Event Types (Today):"
echo "----------------------------------------"
vouchers=$(sudo journalctl -u gambino-pi --since today | grep -c "VOUCHER" || echo "0")
money_in=$(sudo journalctl -u gambino-pi --since today | grep -c "MONEY IN" || echo "0")
collect=$(sudo journalctl -u gambino-pi --since today | grep -c "COLLECT" || echo "0")
session_start=$(sudo journalctl -u gambino-pi --since today | grep -c "SESSION START" || echo "0")
session_end=$(sudo journalctl -u gambino-pi --since today | grep -c "SESSION END" || echo "0")

echo "Vouchers:      $vouchers"
echo "Money In:      $money_in"
echo "Collect:       $collect"
echo "Session Start: $session_start"
echo "Session End:   $session_end"
echo ""

# Recent activity
echo "📅 Last 10 Raw Data Entries:"
echo "----------------------------------------"
sudo journalctl -u gambino-pi | grep "Raw serial data:" | tail -n 10 | sed 's/.*Raw serial data: /  /'
echo ""

# Connection status
echo "📡 Connection Status:"
echo "----------------------------------------"
if sudo journalctl -u gambino-pi --since "5 minutes ago" | grep -q "Serial port.*opened successfully"; then
    echo "✅ Serial connection active"
elif sudo journalctl -u gambino-pi --since "5 minutes ago" | grep -q "development mode"; then
    echo "🔧 Running in development mode (mock data)"
else
    last_connection=$(sudo journalctl -u gambino-pi | grep "Serial port.*opened" | tail -n 1)
    if [ -n "$last_connection" ]; then
        echo "⚠️  Last connection: $last_connection"
    else
        echo "❌ No recent connection detected"
    fi
fi
echo ""

# Error summary
if [ "$errors" -gt 0 ]; then
    echo "⚠️  Recent Errors:"
    echo "----------------------------------------"
    sudo journalctl -u gambino-pi --since today | grep -i "error" | tail -n 5
    echo ""
fi

# Useful commands
echo "🔍 Useful Commands:"
echo "----------------------------------------"
echo "Live monitoring:           sudo journalctl -u gambino-pi -f"
echo "Filter raw data:           sudo journalctl -u gambino-pi | grep 'Raw serial'"
echo "Last 100 entries:          sudo journalctl -u gambino-pi -n 100"
echo "Export today's logs:       sudo journalctl -u gambino-pi --since today > logs.txt"
echo "Watch specific machine:    sudo journalctl -u gambino-pi -f | grep 'MACHINE 31'"
echo "Restart service:           sudo systemctl restart gambino-pi"
echo "Service status:            sudo systemctl status gambino-pi"
echo ""
