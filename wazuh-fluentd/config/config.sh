#!/bin/bash
# Wazuh Fluentd Docker - Configuration Script
# Runs before fluentd starts to set up the environment

set -e

echo "=========================================="
echo "Wazuh Fluentd Configuration"
echo "=========================================="

# Check required environment variables
if [ -z "$INDEXER_USERNAME" ] || [ -z "$INDEXER_PASSWORD" ]; then
    echo "ERROR: INDEXER_USERNAME and INDEXER_PASSWORD must be set"
    exit 1
fi

# Set defaults
export INDEXER_HOST="${INDEXER_HOST:-wazuh-indexer}"
export INDEXER_PORT="${INDEXER_PORT:-9200}"
export FLUENTD_LOG_LEVEL="${FLUENTD_LOG_LEVEL:-info}"
export FLUENTD_WORKERS="${FLUENTD_WORKERS:-1}"

echo "Configuration:"
echo "  Indexer Host: ${INDEXER_HOST}:${INDEXER_PORT}"
echo "  Log Level: ${FLUENTD_LOG_LEVEL}"
echo "  Workers: ${FLUENTD_WORKERS}"
echo ""

# Create buffer directories if they don't exist
mkdir -p /fluentd/buffer/mikrotik
mkdir -p /fluentd/buffer/fortigate-cef
mkdir -p /fluentd/buffer/fortigate-syslog
mkdir -p /fluentd/buffer/cisco-asa
mkdir -p /fluentd/buffer/paloalto
mkdir -p /fluentd/buffer/ruckus
mkdir -p /fluentd/buffer/checkpoint
mkdir -p /fluentd/buffer/generic-syslog
mkdir -p /fluentd/buffer/generic-cef
mkdir -p /fluentd/buffer/netflow
mkdir -p /fluentd/buffer/sflow
mkdir -p /fluentd/failed_records

echo "Buffer directories created"

# Setup pipelines in OpenSearch/Wazuh Indexer
if [ "${SETUP_PIPELINES}" = "true" ]; then
    echo "Setting up ingest pipelines..."
    /usr/local/bin/setup_pipelines.sh
else
    echo "Pipeline setup skipped (set SETUP_PIPELINES=true to enable)"
fi

echo ""
echo "=========================================="
echo "Configuration complete - Starting Fluentd"
echo "=========================================="
echo ""
