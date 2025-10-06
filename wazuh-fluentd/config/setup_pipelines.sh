#!/bin/bash
# Wazuh Fluentd Docker - Pipeline Setup Script
# Creates ingest pipelines in OpenSearch/Wazuh Indexer

set -e

INDEXER_URL="https://${INDEXER_HOST}:${INDEXER_PORT}"
PIPELINE_DIR="/fluentd/pipelines"

echo "=========================================="
echo "Setting up OpenSearch Ingest Pipelines"
echo "=========================================="

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "❌ ERROR: curl is not installed"
    echo "Please install curl in your Dockerfile:"
    echo "  RUN apt-get update && apt-get install -y curl"
    echo ""
    echo "⚠️  Skipping pipeline setup - Fluentd will continue without pipelines"
    echo "⚠️  Pipelines can be setup manually later"
    exit 0  # Don't fail, allow Fluentd to start
fi

# Wait for indexer to be ready
echo "Waiting for indexer to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0
RETRY_DELAY=5

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # Try to connect to indexer with timeout
    if curl -k -s -f -m 5 \
        -u "${INDEXER_USERNAME}:${INDEXER_PASSWORD}" \
        "${INDEXER_URL}/_cluster/health?wait_for_status=yellow&timeout=5s" \
        > /dev/null 2>&1; then
        echo "✅ Indexer is ready!"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo "⏳ Waiting for indexer... (${RETRY_COUNT}/${MAX_RETRIES})"
        sleep $RETRY_DELAY
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "⚠️  WARNING: Indexer not ready after ${MAX_RETRIES} attempts"
    echo "⚠️  Continuing anyway - pipelines may need manual setup"
    echo ""
    echo "To setup pipelines manually, run:"
    echo "  docker exec <container> /usr/local/bin/setup_pipelines.sh"
    echo ""
    exit 0  # Don't fail, allow Fluentd to start
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
    
    # Create pipeline with proper error handling
    response=$(curl -k -s -w "\n%{http_code}" -X PUT \
        -u "${INDEXER_USERNAME}:${INDEXER_PASSWORD}" \
        -H "Content-Type: application/json" \
        "${INDEXER_URL}/_ingest/pipeline/${pipeline_name}" \
        -d @"${pipeline_file}" 2>&1)
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo "✅ Pipeline created: $pipeline_name"
        return 0
    else
        echo "⚠️  Failed to create pipeline: $pipeline_name (HTTP $http_code)"
        if [ -n "$body" ]; then
            echo "Response: $body" | head -n 5
        fi
        return 1
    fi
}

# Create pipelines
echo ""
echo "Creating pipelines..."
echo ""

# Track success/failure
TOTAL=0
SUCCESS=0
FAILED=0

# Create all available pipelines
if create_pipeline "mikrotik-routeros" "${PIPELINE_DIR}/mikrotik-pipeline.json"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))

if create_pipeline "fortigate-cef" "${PIPELINE_DIR}/fortigate-cef-pipeline.json"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))

if create_pipeline "fortigate-syslog" "${PIPELINE_DIR}/fortigate-syslog-pipeline.json"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))

if create_pipeline "cisco-asa" "${PIPELINE_DIR}/cisco-asa-pipeline.json"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))

if create_pipeline "paloalto" "${PIPELINE_DIR}/paloalto-pipeline.json"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))

if create_pipeline "generic-syslog" "${PIPELINE_DIR}/generic-syslog-pipeline.json"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))

# Note: Add pipeline JSON files for these integrations if needed
if create_pipeline "generic-cef" "${PIPELINE_DIR}/generic-cef-pipeline.json"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))

if create_pipeline "ruckus" "${PIPELINE_DIR}/ruckus-pipeline.json"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))

if create_pipeline "checkpoint" "${PIPELINE_DIR}/checkpoint-pipeline.json"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))

if create_pipeline "netflow" "${PIPELINE_DIR}/netflow-pipeline.json"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))

if create_pipeline "sflow" "${PIPELINE_DIR}/sflow-pipeline.json"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))

echo ""
echo "=========================================="
echo "Pipeline setup complete!"
echo "=========================================="
echo "Total: $TOTAL | Success: $SUCCESS | Failed: $FAILED"
echo ""

# Return success even if some pipelines failed
# This allows Fluentd to start
exit 0
