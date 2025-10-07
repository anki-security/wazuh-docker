# Wazuh Fluentd Docker

Multi-source syslog collector with OpenSearch/Wazuh Indexer integration.

## Version 2.0 - Refactored Architecture

This version features a completely refactored modular architecture with:
- **Self-contained integrations** - Each vendor/product has its own configuration file
- **Shared components** - Common filters and outputs for consistency
- **ECS compliance** - Full Elastic Common Schema field mapping
- **Extensible design** - Easy to add new integrations using templates
- **Enhanced parsing** - Improved log parsing with better error handling

## Features

- **Multiple Syslog Sources**: Support for various network devices and security appliances
- **Modular Integrations**: Self-contained, easy-to-manage integration files
- **Custom Parsers**: Pre-configured Grok patterns for each vendor
- **OpenSearch Integration**: Direct integration with Wazuh Indexer
- **ECS Compliant**: Full Elastic Common Schema (ECS) field mapping
- **Buffering & Reliability**: File-based buffering with retry logic
- **Additional Plugins**: Extended plugin support for advanced use cases

## Supported Integrations

| Integration | Port(s) | Protocol | Index Pattern | Status |
|-------------|---------|----------|---------------|--------|
| **NetFlow/IPFIX** | 2055 | UDP | `anki-netflow-*` | ✅ Active |
| **sFlow** | 6343 | UDP | `anki-sflow-*` | ✅ Active |
| **MikroTik RouterOS** | 30514 | UDP | `anki-mikrotik-*` | ✅ Active |
| **Fortinet FortiGate** | 30515, 30516 | TCP, UDP | `anki-fortigate-*` | ✅ Active |
| **Cisco ASA** | 30517 | UDP | `anki-cisco-asa-*` | ✅ Active |
| **Palo Alto PAN-OS** | 30518 | TCP | `anki-paloalto-*` | ✅ Active |
| **Generic Syslog** | 30519, 30520 | UDP, TCP | `anki-generic-syslog-*` | ✅ Active |
| **Generic CEF** | 30521, 30522 | TCP, UDP | `anki-generic-cef-*` | ✅ Active |
| **Ruckus Wireless** | 30523, 30524 | UDP, TCP | `anki-ruckus-*` | ✅ Active |
| **Check Point** | 30525, 30526 | TCP, UDP | `anki-checkpoint-*` | ✅ Active |

> **Note**: MikroTik integration is optional (disabled by default). See [INTEGRATIONS.md](INTEGRATIONS.md) for detailed configuration guides.

For detailed integration documentation, see **[INTEGRATIONS.md](INTEGRATIONS.md)**.

## Index Naming Convention

All indices use the `anki-` prefix for easy management:

```
anki-mikrotik-2025.01.15
anki-fortigate-cef-2025.01.15
anki-netflow-2025.01.15
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
