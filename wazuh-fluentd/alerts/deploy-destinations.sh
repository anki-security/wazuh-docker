#!/bin/bash
# Deploy OpenSearch Alerting Destinations
# Creates notification channels for alerts

set -e

INDEXER_URL="https://${INDEXER_HOST:-wazuh-indexer}:${INDEXER_PORT:-9200}"
DESTINATIONS_DIR="$(dirname "$0")/destinations"

echo "=========================================="
echo "Deploying OpenSearch Alerting Destinations"
echo "=========================================="

# Check required environment variables
if [ -z "$INDEXER_USERNAME" ] || [ -z "$INDEXER_PASSWORD" ]; then
    echo "❌ ERROR: INDEXER_USERNAME and INDEXER_PASSWORD must be set"
    exit 1
fi

# Function to create destination
create_destination() {
    local dest_file=$1
    local dest_name=$(basename "$dest_file" .json | sed 's/-example//')
    
    if [ ! -f "$dest_file" ]; then
        echo "⚠️  Destination file not found: $dest_file"
        return 1
    fi
    
    # Skip example files
    if [[ "$dest_file" == *"-example.json" ]]; then
        echo "⏭️  Skipping example file: $(basename "$dest_file")"
        return 0
    fi
    
    echo "📋 Creating destination: $dest_name"
    
    # Create destination
    response=$(curl -k -s -w "\n%{http_code}" -X POST \
        -u "${INDEXER_USERNAME}:${INDEXER_PASSWORD}" \
        -H "Content-Type: application/json" \
        "${INDEXER_URL}/_plugins/_alerting/destinations" \
        -d @"${dest_file}" 2>&1)
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        destination_id=$(echo "$body" | grep -o '"_id":"[^"]*"' | cut -d'"' -f4)
        echo "✅ Destination created: $dest_name (ID: $destination_id)"
        echo "$destination_id" > "${DESTINATIONS_DIR}/.${dest_name}.id"
        return 0
    else
        echo "⚠️  Failed to create destination: $dest_name (HTTP $http_code)"
        if [ -n "$body" ]; then
            echo "Response: $body" | head -n 3
        fi
        return 1
    fi
}

# Track success/failure
TOTAL=0
SUCCESS=0
FAILED=0

# Create all destinations
if [ -d "$DESTINATIONS_DIR" ]; then
    for dest_file in "$DESTINATIONS_DIR"/*.json; do
        if [ -f "$dest_file" ]; then
            if create_destination "$dest_file"; then
                SUCCESS=$((SUCCESS + 1))
            else
                FAILED=$((FAILED + 1))
            fi
            TOTAL=$((TOTAL + 1))
        fi
    done
else
    echo "⚠️  Destinations directory not found: $DESTINATIONS_DIR"
fi

echo ""
echo "=========================================="
echo "Destination deployment complete!"
echo "=========================================="
echo "Total: $TOTAL | Success: $SUCCESS | Failed: $FAILED"
echo ""

if [ $SUCCESS -gt 0 ]; then
    echo "✅ Destinations created successfully"
    echo ""
    echo "Next steps:"
    echo "1. Update alert definitions with destination IDs"
    echo "2. Run ./deploy-alerts.sh to deploy monitors"
    echo ""
fi

exit 0
