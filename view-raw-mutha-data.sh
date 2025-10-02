#!/bin/bash

# Quick script to see raw Mutha Goose data format

echo "=========================================="
echo "Raw Mutha Goose Data Viewer"
echo "=========================================="
echo ""

echo "📋 Complete log output from today:"
echo "----------------------------------------"
sudo journalctl -u gambino-pi --since today --no-pager | tail -n 50

echo ""
echo "📊 Unique data patterns detected:"
echo "----------------------------------------"
sudo journalctl -u gambino-pi --since "2025-10-01" --no-pager | \
  grep -v "systemd\|Loaded:\|Active:\|Main PID\|Tasks:\|Memory:\|CPU:" | \
  grep -E "VOUCHER|MACHINE|COLLECT|MONEY|SESSION|Confidence|SERIAL #|DATE|TIME" | \
  sort -u | head -n 30

echo ""
echo "💾 Full export available:"
echo "Run: sudo journalctl -u gambino-pi --since '2025-10-01' --no-pager > ~/mutha-data-export.txt"
