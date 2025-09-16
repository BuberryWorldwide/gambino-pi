# Fixed download_qr_code function for sync-qr-codes.sh

download_qr_code() {
    local machine_id="$1"
    local fledgling="$2"
    
    echo -e "${BLUE}📥 Downloading QR code for machine: ${machine_id}${NC}"
    
    # First, we need to find the MongoDB _id for this machine
    # Since we can't query the store machines endpoint (permission denied),
    # we'll need to try the correct endpoint pattern
    
    # The API expects MongoDB _id, but we only have machineId
    # Let's try a different approach - use the machineId directly in case the API supports it
    
    echo "Trying to find machine and get QR code..."
    
    # Option 1: Try to get machine by machineId (if such endpoint exists)
    local machine_lookup_response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -H "Authorization: Bearer ${MACHINE_TOKEN}" \
        -H "Content-Type: application/json" \
        "${API_ENDPOINT}/api/machines/find/${machine_id}")
    
    local lookup_http_code=$(echo "$machine_lookup_response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    local lookup_body=$(echo "$machine_lookup_response" | sed -e 's/HTTPSTATUS\:.*//g')
    
    if [ "$lookup_http_code" -eq 200 ]; then
        # Extract the MongoDB _id from the response
        local mongo_id=$(echo "$lookup_body" | node -e "
        try {
            const data = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8'));
            console.log(data._id || data.id || '');
        } catch (e) {
            console.log('');
        }
        " 2>/dev/null)
        
        if [ -n "$mongo_id" ]; then
            echo "Found machine MongoDB ID: $mongo_id"
            
            # Now get the QR code using the MongoDB ID
            local qr_response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
                -H "Authorization: Bearer ${MACHINE_TOKEN}" \
                -H "Content-Type: application/json" \
                "${API_ENDPOINT}/api/machines/${mongo_id}/qr-code")
            
            local qr_http_code=$(echo "$qr_response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
            local qr_body=$(echo "$qr_response" | sed -e 's/HTTPSTATUS\:.*//g')
            
            if [ "$qr_http_code" -eq 200 ]; then
                # Process the QR code response (same as before)
                local qr_data=$(echo "$qr_body" | node -e "
                try {
                    const data = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8'));
                    if (data.success && data.qrCode) {
                        console.log(data.qrCode);
                    } else {
                        process.exit(1);
                    }
                } catch (e) {
                    process.exit(1);
                }
                " 2>/dev/null)
                
                if [ $? -eq 0 ] && [ -n "$qr_data" ]; then
                    # Save QR code data URL to file
                    echo "$qr_data" > "$QR_DIR/${machine_id}.qr"
                    
                    # Extract base64 data and save as PNG
                    echo "$qr_data" | sed 's/data:image\/png;base64,//' | base64 -d > "$QR_DIR/${machine_id}.png"
                    
                    # Create metadata file
                    echo "$qr_body" | node -e "
                    try {
                        const data = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8'));
                        const metadata = {
                            machineId: data.machineId,
                            fledgling: '$fledgling',
                            bindUrl: data.bindUrl,
                            generated: data.generated,
                            downloaded: new Date().toISOString(),
                            mongoId: '$mongo_id'
                        };
                        console.log(JSON.stringify(metadata, null, 2));
                    } catch (e) {
                        console.log('{}');
                    }
                    " > "$QR_DIR/${machine_id}.json"
                    
                    echo -e "${GREEN}✅ QR code saved for ${machine_id} (Fledgling ${fledgling})${NC}"
                    return 0
                else
                    echo -e "${RED}❌ Failed to parse QR code data${NC}"
                    return 1
                fi
            else
                echo -e "${RED}❌ QR code API error (HTTP ${qr_http_code}): ${qr_body}${NC}"
                return 1
            fi
        else
            echo -e "${RED}❌ Could not extract MongoDB ID from machine lookup${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  Machine lookup failed (HTTP ${lookup_http_code})${NC}"
        echo "Response: $lookup_body"
        
        # Fallback: Since we know the pattern from the admin dashboard,
        # let's try to construct a request that might work
        echo "Trying fallback approach..."
        
        # The admin dashboard uses: /api/machines/{mongoId}/qr-code
        # But we need the mongoId. Let's see if we can deduce it or if there's another way
        
        echo -e "${YELLOW}💡 Manual workaround needed:${NC}"
        echo "1. In admin dashboard, right-click 'QR' button and 'Inspect Element'"
        echo "2. Look for the MongoDB _id in the API call (something like: 507f1f77bcf86cd799439011)"
        echo "3. Run: ./sync-qr-codes.sh --manual-sync {mongoId} ${machine_id}"
        
        return 1
    fi
}