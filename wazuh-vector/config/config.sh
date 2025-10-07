#!/bin/bash
# Wazuh Vector Docker - Configuration Script
# Runs before Vector starts to set up the environment

set -e

echo "=========================================="
echo "Wazuh Vector Configuration"
echo "=========================================="

# Check required environment variables
if [ -z "$INDEXER_USERNAME" ] || [ -z "$INDEXER_PASSWORD" ]; then
    echo "ERROR: INDEXER_USERNAME and INDEXER_PASSWORD must be set"
    exit 1
fi

# Set defaults
export INDEXER_HOST="${INDEXER_HOST:-wazuh-indexer}"
export INDEXER_PORT="${INDEXER_PORT:-9200}"

echo "Configuration:"
echo "  Indexer: https://${INDEXER_HOST}:${INDEXER_PORT}"
echo "  User: ${INDEXER_USERNAME}"
echo ""

# Create data directory for Vector buffers
mkdir -p /vector/data

echo "Vector data directory created"

# Setup pipelines in OpenSearch/Wazuh Indexer
if [ "${SETUP_PIPELINES}" = "true" ]; then
    echo "Setting up ingest pipelines..."
    /usr/local/bin/setup_pipelines.sh
else
    echo "Pipeline setup skipped (set SETUP_PIPELINES=true to enable)"
fi

echo ""
echo "=========================================="
echo "Configuration complete - Starting Vector"
echo "=========================================="
echo ""

# Execute the command passed as arguments (from CMD)
exec "$@"
