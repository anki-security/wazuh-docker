# Wazuh Vector Docker

**High-performance syslog and NetFlow collector powered by Vector.dev**

Multi-source data pipeline with OpenSearch/Wazuh Indexer integration, built on Vector.dev for superior performance and reliability.

## Version 3.0 - Migrated to Vector.dev

**Why Vector?**
- 🚀 **10x faster** than Fluentd (Rust vs Ruby)
- 💾 **10x lower memory** (~50MB vs 500MB)
- ✅ **Native NetFlow support** that actually works
- 🔒 **Production-ready** reliability
- 📊 **Better observability** with built-in metrics

### Migration from Fluentd
This version replaces Fluentd with Vector.dev due to:
- Broken NetFlow plugins in Fluentd
- Poor performance and high memory usage
- Limited multi-worker support
- Better ecosystem and active development in Vector

## Features

- **Native NetFlow Support**: Built-in NetFlow v5/v9 parsing
- **High Performance**: Rust-based pipeline with minimal overhead
- **Low Resource Usage**: Typically uses ~50MB RAM
- **Syslog Collection**: UDP and TCP syslog with automatic parsing
- **OpenSearch Integration**: Direct integration with Wazuh Indexer
- **Pipeline Support**: Uses existing OpenSearch ingest pipelines
- **Disk Buffering**: Reliable 512MB disk-based buffers per sink
- **TLS/SSL**: Secure connections to OpenSearch

## Active Sources

| Source | Port(s) | Protocol | Index Pattern | Status |
|--------|---------|----------|---------------|--------|
| **NetFlow v5/v9** | 2055 | UDP | `anki-netflow-*` | ✅ Native |
| **MikroTik RouterOS** | 40514 | UDP | `anki-mikrotik-*` | ✅ Active |
| **Generic Syslog** | 40519, 40520 | UDP, TCP | `anki-generic-syslog-*` | ✅ Active |

> **Note**: Additional sources (Fortigate, Cisco, Palo Alto, etc.) can be easily added by extending the `vector.toml` configuration.

## Quick Start

### Docker Compose

```bash
# Copy example configuration
cp docker-compose.example.yml docker-compose.yml

# Edit credentials
vi docker-compose.yml  # Change INDEXER_PASSWORD

# Start
docker-compose up -d
```

### Kubernetes/K3s

```bash
# Apply the example manifest
kubectl apply -f k8s-example.yml

# Update credentials
kubectl edit secret indexer-credentials -n wazuh-vector

# Check status
kubectl get pods -n wazuh-vector
kubectl logs -f wazuh-vector-0 -n wazuh-vector
```

## Index Naming Convention

All indices use the `anki-` prefix for easy management:

```
anki-netflow-2025.01.15
anki-mikrotik-2025.01.15
anki-generic-syslog-2025.01.15
...
```

### Benefits:
- **Easy identification**: All Anki Security indices grouped together
- **Simple retention policies**: Apply policies to `anki-*` pattern
- **Access control**: Grant permissions to `anki-*` indices
- **Index lifecycle management**: Manage all indices with single policy

### Query Examples:
```bash
# View all Anki indices
GET _cat/indices/anki-*?v

# Search across all sources
GET anki-*/_search

# Search specific source
GET anki-mikrotik-*/_search
```

## Environment Variables

### Required
- `INDEXER_USERNAME` - Wazuh Indexer username
- `INDEXER_PASSWORD` - Wazuh Indexer password

### Optional
- `INDEXER_HOST` - Indexer hostname (default: `wazuh-indexer`)
- `INDEXER_PORT` - Indexer port (default: `9200`)
- `FLUENTD_LOG_LEVEL` - Log level (default: `info`)
- `FLUENTD_WORKERS` - Number of workers (default: `1`)
- `SETUP_PIPELINES` - Auto-setup pipelines (default: `false`, set to `true` to enable)

## Usage

### Docker Run

```bash
docker run -d \
  --name wazuh-fluentd \
  -p 2055:2055/udp \
  -p 6343:6343/udp \
  -p 30514:30514/udp \
  -p 30515:30515/tcp \
  -p 30516:30516/udp \
  -p 30517:30517/udp \
  -p 30518:30518/tcp \
  -p 30519:30519/udp \
  -p 30520:30520/tcp \
  -p 30521:30521/tcp \
  -p 30522:30522/udp \
  -p 30523:30523/udp \
  -p 30524:30524/tcp \
  -p 30525:30525/tcp \
  -p 30526:30526/udp \
  -e INDEXER_HOST=wazuh-indexer \
  -e INDEXER_USERNAME=admin \
  -e INDEXER_PASSWORD=SecretPassword \
  -e SETUP_PIPELINES=true \
  -v fluentd-buffer:/fluentd/buffer \
  -v fluentd-logs:/fluentd/log \
  wazuh-fluentd:latest
```

### Docker Compose

```yaml
version: '3.8'

services:
  wazuh-fluentd:
    image: wazuh-fluentd:latest
    container_name: wazuh-fluentd
    ports:
      - "2055:2055/udp"    # NetFlow/IPFIX
      - "6343:6343/udp"    # sFlow
      - "30514:30514/udp"  # MikroTik
      - "30515:30515/tcp"  # Fortigate CEF
      - "30516:30516/udp"  # Fortigate Syslog
      - "30517:30517/udp"  # Cisco ASA
      - "30518:30518/tcp"  # Palo Alto
      - "30519:30519/udp"  # Generic Syslog UDP
      - "30520:30520/tcp"  # Generic Syslog TCP
      - "30521:30521/tcp"  # Generic CEF TCP
      - "30522:30522/udp"  # Generic CEF UDP
      - "30523:30523/udp"  # Ruckus UDP
      - "30524:30524/tcp"  # Ruckus TCP
      - "30525:30525/tcp"  # Check Point CEF
      - "30526:30526/udp"  # Check Point Syslog
    environment:
      - INDEXER_HOST=wazuh-indexer
      - INDEXER_PORT=9200
      - INDEXER_USERNAME=admin
      - INDEXER_PASSWORD=SecretPassword
      - SETUP_PIPELINES=true
      - FLUENTD_LOG_LEVEL=info
    volumes:
      - fluentd-buffer:/fluentd/buffer
      - fluentd-logs:/fluentd/log
    networks:
      - wazuh

volumes:
  fluentd-buffer:
  fluentd-logs:

networks:
  wazuh:
    external: true
```

## Configuration

### Adding New Integrations

Simple approach - just copy an existing config:

1. **Copy an existing config:**
   ```bash
   cp config/conf.d/99-generic-syslog.conf config/conf.d/80-myvendor.conf
   ```

2. **Customize:**
   - Change port number (30528+)
   - Update tag, vendor, product
   - Set index name and pipeline

3. **Create OpenSearch pipeline:**
   ```bash
   cp config/pipelines/generic-syslog-pipeline.json config/pipelines/myvendor-pipeline.json
   ```

4. **Update Dockerfile:**
   - Add your port to EXPOSE

5. **Rebuild:**
   ```bash
   docker build -t wazuh-fluentd:latest .
   ```

**Note:** Parsing logic goes in OpenSearch pipelines, not Fluentd configs!

### Pipeline Management

Pipelines can be managed in two ways:

1. **Automatic Setup** (recommended for initial deployment):
   - Set `SETUP_PIPELINES=true`
   - Pipelines are created on container startup

2. **Manual Setup**:
   - Use the `setup_pipelines.sh` script
   - Or create pipelines via OpenSearch API

## Directory Structure

```
wazuh-fluentd/
├── Dockerfile
├── README.md
├── VERSION                      # Version file
└── config/
    ├── fluent.conf              # Main configuration
    ├── config.sh                # Startup configuration
    ├── setup_pipelines.sh       # Pipeline setup script
    ├── conf.d/                  # Source configurations
    │   ├── 10-mikrotik.conf
    │   ├── 20-fortigate-cef.conf
    │   ├── 21-fortigate-syslog.conf
    │   ├── 30-cisco-asa.conf
    │   ├── 40-paloalto.conf
    │   ├── 50-ruckus.conf
    │   ├── 60-checkpoint.conf
    │   ├── 70-generic-cef.conf
    │   └── 99-generic-syslog.conf
    └── pipelines/               # OpenSearch ingest pipelines
        ├── mikrotik-routeros-pipeline.json
        ├── fortigate-cef-pipeline.json
        ├── fortigate-syslog-pipeline.json
        ├── cisco-asa-pipeline.json
        ├── paloalto-pipeline.json
        ├── ruckus-pipeline.json
        ├── checkpoint-pipeline.json
        ├── generic-cef-pipeline.json
        └── generic-syslog-pipeline.json
```

## Troubleshooting

### Check Fluentd Logs
```bash
docker logs wazuh-fluentd
```

### Verify Pipeline Creation
```bash
curl -k -u admin:password https://wazuh-indexer:9200/_ingest/pipeline/mikrotik-routeros
```

### Test Syslog Reception
```bash
# Test MikroTik port
echo "test message" | nc -u localhost 30514

# Check failed records
docker exec wazuh-fluentd ls -la /fluentd/failed_records/
```

### Buffer Issues
```bash
# Check buffer size
docker exec wazuh-fluentd du -sh /fluentd/buffer/*

# Clear buffer (if needed)
docker exec wazuh-fluentd rm -rf /fluentd/buffer/*
```

## Performance Tuning

### Increase Workers
For high-volume environments:
```yaml
environment:
  - FLUENTD_WORKERS=4
```

### Adjust Buffer Settings
Edit the buffer configuration in each source file:
```conf
<buffer tag, time>
  chunk_limit_size 16MB      # Increase chunk size
  total_limit_size 1GB       # Increase total buffer
  flush_interval 5s          # Decrease flush interval
</buffer>
```

## License

GPLv2 - See LICENSE file for details
