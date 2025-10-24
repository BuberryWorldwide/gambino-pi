#!/bin/bash
# backfill.sh - Easy wrapper for backfill tool

cd ~/gambino-pi-app

# Show usage if --help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "════════════════════════════════════════════════════════════"
    echo "🔄 BACKFILL TOOL"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Re-parse historical logs and insert missing events into database"
    echo ""
    echo "Usage:"
    echo "  ./backfill.sh [date]"
    echo ""
    echo "Examples:"
    echo "  ./backfill.sh                    # Today"
    echo "  ./backfill.sh 2025-10-15         # Specific date"
    echo "  ./backfill.sh yesterday          # Yesterday"
    echo ""
    echo "What it does:"
    echo "  1. Extracts raw serial data from journalctl logs"
    echo "  2. Re-parses with current (working) parser"
    echo "  3. Compares to existing database events"
    echo "  4. Shows diff of what's missing"
    echo "  5. Asks permission to insert"
    echo "  6. Inserts and syncs to backend"
    echo ""
    exit 0
fi

DATE_ARG=${1:-$(date +%Y-%m-%d)}

# Convert "yesterday" to actual date
if [ "$DATE_ARG" = "yesterday" ]; then
    DATE_ARG=$(date -d "yesterday" +%Y-%m-%d)
fi

echo "🔄 Running backfill for: $DATE_ARG"
echo ""

node tools/backfill-from-logs.js "$DATE_ARG"
