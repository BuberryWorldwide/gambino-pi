#!/bin/bash

echo "=========================================="
echo "Mutha Goose Data Format Analysis"
echo "=========================================="
echo ""

echo "📋 Format 1: Single-line (WORKING)"
echo "----------------------------------------"
sudo journalctl -u gambino-pi --since "2025-10-01" --no-pager | \
  grep "rawData" | tail -n 5
echo ""

echo "📋 Format 2: Multi-line vouchers (DETECTED)"
echo "----------------------------------------"
sudo journalctl -u gambino-pi --since "2025-10-01" --no-pager | \
  grep -A 2 "Voucher #" | head -n 20
echo ""

echo "🔍 Looking for machine numbers in multi-line format..."
echo "----------------------------------------"
sudo journalctl -u gambino-pi --since "2025-10-01" --no-pager | \
  grep -B 5 -A 5 "Voucher #" | grep -i "machine" | head -n 10
echo ""

echo "📊 Summary of what's being parsed:"
echo "----------------------------------------"
echo "Successfully parsed events:"
sudo journalctl -u gambino-pi --since "2025-10-01" --no-pager | \
  grep "Event sent successfully" | tail -n 5
echo ""

echo "Unrecognized formats:"
sudo journalctl -u gambino-pi --since "2025-10-01" --no-pager | \
  grep "Unrecognized data format" | tail -n 5
echo ""

echo "🎯 Recommendation:"
echo "----------------------------------------"
echo "Your parser handles single-line format perfectly:"
echo '  "Voucher #16310 - 10 plays - 10 points - Machine 35"'
echo ""
echo "Multi-line vouchers need additional handling or may be"
echo "print-only (no machine data) or require different parsing."
echo ""
echo "Next steps:"
echo "1. Check if multi-line vouchers appear on specific machines only"
echo "2. Determine if multi-line format includes machine info elsewhere"
echo "3. Possibly ignore multi-line printouts if they're duplicates"
