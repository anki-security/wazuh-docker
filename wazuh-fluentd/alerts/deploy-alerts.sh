#!/bin/bash
# Deploy OpenSearch Alerting Monitors
# Creates security alert monitors from JSON definitions

set -e

INDEXER_URL="https://${INDEXER_HOST:-wazuh-indexer}:${INDEXER_PORT:-9200}"
ALERTS_DIR="$(dirname "$0")"
CATEGORY="${1:-all}"

echo "=========================================="
echo "Deploying OpenSearch Alerting Monitors"
echo "=========================================="

# Check required environment variables
if [ -z "$INDEXER_USERNAME" ] || [ -z "$INDEXER_PASSWORD" ]; then
    echo "❌ ERROR: INDEXER_USERNAME and INDEXER_PASSWORD must be set"
    exit 1
fi

# Get destination ID (if available)
DESTINATION_ID="${DESTINATION_ID:-}"
if [ -z "$DESTINATION_ID" ]; then
    echo "⚠️  WARNING: DESTINATION_ID not set. Alerts will be created but won't send notifications."
    echo "   Set DESTINATION_ID environment variable or update alert JSON files manually."
    echo ""
fi

# Function to create monitor
create_monitor() {
    local monitor_file=$1
    local monitor_name=$(basename "$monitor_file" .json)
    
    if [ ! -f "$monitor_file" ]; then
        echo "⚠️  Monitor file not found: $monitor_file"
        return 1
    fi
    
    echo "📋 Creating monitor: $monitor_name"
    
    # Replace placeholder destination ID if set
    local temp_file="/tmp/monitor_${monitor_name}.json"
    if [ -n "$DESTINATION_ID" ]; then
        sed "s/{{DESTINATION_ID}}/$DESTINATION_ID/g" "$monitor_file" > "$temp_file"
    else
        cp "$monitor_file" "$temp_file"
    fi
    
    # Create monitor
    response=$(curl -k -s -w "\n%{http_code}" -X POST \
        -u "${INDEXER_USERNAME}:${INDEXER_PASSWORD}" \
        -H "Content-Type: application/json" \
        "${INDEXER_URL}/_plugins/_alerting/monitors" \
        -d @"${temp_file}" 2>&1)
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    rm -f "$temp_file"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        monitor_id=$(echo "$body" | grep -o '"_id":"[^"]*"' | cut -d'"' -f4)
        echo "✅ Monitor created: $monitor_name (ID: $monitor_id)"
        return 0
    else
        echo "⚠️  Failed to create monitor: $monitor_name (HTTP $http_code)"
        if [ -n "$body" ]; then
            echo "Response: $body" | head -n 5
        fi
        return 1
    fi
}

# Track success/failure
TOTAL=0
SUCCESS=0
FAILED=0

# Deploy monitors based on category
case "$CATEGORY" in
    "mikrotik")
        echo "Deploying MikroTik alerts..."
        for monitor_file in "$ALERTS_DIR/mikrotik"/*.json; do
            if [ -f "$monitor_file" ]; then
                if create_monitor "$monitor_file"; then
                    SUCCESS=$((SUCCESS + 1))
                else
                    FAILED=$((FAILED + 1))
                fi
                TOTAL=$((TOTAL + 1))
            fi
        done
        ;;
    
    "esxi")
        echo "Deploying ESXi alerts..."
        for monitor_file in "$ALERTS_DIR/esxi"/*.json; do
            if [ -f "$monitor_file" ]; then
                if create_monitor "$monitor_file"; then
                    SUCCESS=$((SUCCESS + 1))
                else
                    FAILED=$((FAILED + 1))
                fi
                TOTAL=$((TOTAL + 1))
            fi
        done
        ;;
    
    "all")
        echo "Deploying all alerts..."
        
        # MikroTik alerts
        if [ -d "$ALERTS_DIR/mikrotik" ]; then
            for monitor_file in "$ALERTS_DIR/mikrotik"/*.json; do
                if [ -f "$monitor_file" ]; then
                    if create_monitor "$monitor_file"; then
                        SUCCESS=$((SUCCESS + 1))
                    else
                        FAILED=$((FAILED + 1))
                    fi
                    TOTAL=$((TOTAL + 1))
                fi
            done
        fi
        
        # ESXi alerts
        if [ -d "$ALERTS_DIR/esxi" ]; then
            for monitor_file in "$ALERTS_DIR/esxi"/*.json; do
                if [ -f "$monitor_file" ]; then
                    if create_monitor "$monitor_file"; then
                        SUCCESS=$((SUCCESS + 1))
                    else
                        FAILED=$((FAILED + 1))
                    fi
                    TOTAL=$((TOTAL + 1))
                fi
            done
        fi
        ;;
    
    *)
        echo "❌ ERROR: Unknown category: $CATEGORY"
        echo "Usage: $0 [all|mikrotik|esxi]"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "Monitor deployment complete!"
echo "=========================================="
echo "Total: $TOTAL | Success: $SUCCESS | Failed: $FAILED"
echo ""

if [ $SUCCESS -gt 0 ]; then
    echo "✅ Monitors created successfully"
    echo ""
    echo "View monitors in Wazuh Dashboard:"
    echo "  OpenSearch Dashboards → Alerting → Monitors"
    echo ""
    echo "Or via API:"
    echo "  curl -k -u admin:password \\"
    echo "    \"${INDEXER_URL}/_plugins/_alerting/monitors/_search?pretty\""
    echo ""
fi

exit 0
