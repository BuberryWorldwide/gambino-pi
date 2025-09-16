#!/bin/bash
# debug-qr-sync.sh - Debug the QR sync issue

source /opt/gambino-pi/.env

echo "🔍 Debugging QR Sync for machine_04"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "1. Environment check:"
echo "   API Endpoint: $API_ENDPOINT"
echo "   Store ID: $STORE_ID"
echo "   Token set: $([ -n "$MACHINE_TOKEN" ] && echo "Yes" || echo "No")"

echo ""
echo "2. Testing API endpoint that sync-qr-codes.sh uses:"
echo "   Trying: $API_ENDPOINT/api/machines/by-id/machine_04/qr-code"

# Test the exact API call that sync-qr-codes.sh makes
response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
    -H "Authorization: Bearer $MACHINE_TOKEN" \
    -H "Content-Type: application/json" \
    "$API_ENDPOINT/api/machines/by-id/machine_04/qr-code")

http_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
body=$(echo "$response" | sed -e 's/HTTPSTATUS\:.*//g')

echo "   HTTP Status: $http_code"
echo "   Response: $body"

echo ""
echo "3. Let's try different API endpoints to find the machine:"

# Try the store machines endpoint (might not work due to permissions)
echo "   Trying store machines endpoint..."
store_response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
    -H "Authorization: Bearer $MACHINE_TOKEN" \
    -H "Content-Type: application/json" \
    "$API_ENDPOINT/api/machines/stores/$STORE_ID" 2>/dev/null)

store_http_code=$(echo "$store_response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
store_body=$(echo "$store_response" | sed -e 's/HTTPSTATUS\:.*//g')

echo "   Store endpoint status: $store_http_code"
if [ "$store_http_code" = "200" ]; then
    echo "   Store machines found!"
    echo "$store_body" | node -e "
    try {
        const data = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8'));
        console.log('   Machines in store:');
        (data.machines || []).forEach(m => {
            console.log('     - ' + m.machineId + ' (' + m.name + ')');
        });
    } catch (e) {
        console.log('   Could not parse response');
    }
    "
else
    echo "   Store endpoint error: $store_body"
fi

echo ""
echo "4. Alternative API endpoints to try:"
echo "   Option A: $API_ENDPOINT/api/machines/machine_04/qr-code"
echo "   Option B: $API_ENDPOINT/api/machines/qr-code/machine_04"

# Test alternative endpoints
echo ""
echo "   Testing Option A..."
alt_a_response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
    -H "Authorization: Bearer $MACHINE_TOKEN" \
    -H "Content-Type: application/json" \
    "$API_ENDPOINT/api/machines/machine_04/qr-code")

alt_a_http_code=$(echo "$alt_a_response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
echo "   Option A status: $alt_a_http_code"

echo ""
echo "5. Database ID vs Machine ID issue:"
echo "   The admin dashboard might be using MongoDB _id instead of machineId"
echo "   Or there might be a URL encoding issue"

echo ""
echo "6. Recommendations:"
echo "   - Check the exact machine ID in the database"
echo "   - Verify the API endpoint in sync-qr-codes.sh"
echo "   - Check if the machine was created with a different ID"
echo "   - Look at the admin dashboard network tab to see what API calls it makes"