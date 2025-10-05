#!/bin/bash
# Wazuh Fluentd Docker - Pipeline Setup Script
# Creates ingest pipelines in OpenSearch/Wazuh Indexer

set -e

INDEXER_URL="https://${INDEXER_HOST}:${INDEXER_PORT}"
PIPELINE_DIR="/fluentd/pipelines"

echo "=========================================="
echo "Setting up OpenSearch Ingest Pipelines"
echo "=========================================="

# Wait for indexer to be ready
echo "Waiting for indexer to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -k -s -u "${INDEXER_USERNAME}:${INDEXER_PASSWORD}" \
        "${INDEXER_URL}/_cluster/health?wait_for_status=yellow&timeout=5s" > /dev/null 2>&1; then
        echo "✅ Indexer is ready!"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "⏳ Waiting for indexer... (${RETRY_COUNT}/${MAX_RETRIES})"
    sleep 5
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ ERROR: Indexer not ready after ${MAX_RETRIES} attempts"
    exit 1
fi

# Function to create pipeline
create_pipeline() {
    local pipeline_name=$1
    local pipeline_file=$2
    
    if [ ! -f "$pipeline_file" ]; then
        echo "⚠️  Pipeline file not found: $pipeline_file"
        return 1
    fi
    
    echo "📋 Creating pipeline: $pipeline_name"
    
    response=$(curl -k -s -w "\n%{http_code}" -X PUT \
        -u "${INDEXER_USERNAME}:${INDEXER_PASSWORD}" \
        -H "Content-Type: application/json" \
        "${INDEXER_URL}/_ingest/pipeline/${pipeline_name}" \
        -d @"${pipeline_file}")
    
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo "✅ Pipeline created: $pipeline_name"
        return 0
    else
        echo "❌ Failed to create pipeline: $pipeline_name (HTTP $http_code)"
        echo "$response" | head -n-1
        return 1
    fi
}

# Create pipelines
echo ""
echo "Creating pipelines..."
echo ""

create_pipeline "mikrotik-routeros" "${PIPELINE_DIR}/mikrotik-pipeline.json"
create_pipeline "fortigate-cef" "${PIPELINE_DIR}/fortigate-cef-pipeline.json"
create_pipeline "fortigate-syslog" "${PIPELINE_DIR}/fortigate-syslog-pipeline.json"

# Add more pipelines as they are created
# create_pipeline "cisco-asa" "${PIPELINE_DIR}/cisco-asa-pipeline.json"
# create_pipeline "paloalto" "${PIPELINE_DIR}/paloalto-pipeline.json"
# create_pipeline "generic-syslog" "${PIPELINE_DIR}/generic-syslog-pipeline.json"

echo ""
echo "=========================================="
echo "Pipeline setup complete!"
echo "=========================================="
echo ""
