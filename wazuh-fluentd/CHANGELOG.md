# Changelog

## [3.0.10] - 2025-10-11

### Changed
- Version bump to 3.0.10


## [3.0.9] - 2025-10-11

### Changed
- Version bump to 3.0.9


## [3.0.8] - 2025-10-10

### Changed
- Version bump to 3.0.8


## [3.0.7] - 2025-10-10

### Changed
- Version bump to 3.0.7


## [3.0.6] - 2025-10-10

### Changed
- Version bump to 3.0.6


## [3.0.5] - 2025-10-10

### Changed
- Version bump to 3.0.5


## [3.0.4] - 2025-10-10

### Changed
- Version bump to 3.0.4


## [3.0.3] - 2025-10-10

### Changed
- Version bump to 3.0.3


## [3.0.2] - 2025-10-10

### Changed
- Version bump to 3.0.2


## [3.0.0] - 2025-10-10

### Changed
- Version bump to 3.0.0


## [2.10.11] - 2025-10-08

### Changed
- Version bump to 2.10.11


## [2.10.10] - 2025-10-08

### Changed
- Version bump to 2.10.10


## [2.10.9] - 2025-10-07

### Changed
- Version bump to 2.10.9


## [2.10.8] - 2025-10-07

### Changed
- Version bump to 2.10.8


## [2.10.7] - 2025-10-07

### Changed
- Version bump to 2.10.7


## [2.10.6] - 2025-10-07

### Changed
- Version bump to 2.10.6


## [2.10.5] - 2025-10-07

### Changed
- Version bump to 2.10.5


## [2.10.4] - 2025-10-07

### Changed
- Version bump to 2.10.4


## [2.10.3] - 2025-10-07

### Changed
- Version bump to 2.10.3


## [2.10.2] - 2025-10-07

### Changed
- Version bump to 2.10.2


## [2.10.1] - 2025-10-06

### Changed
- Version bump to 2.10.1


## [2.10.0] - 2025-10-06

### Changed
- Version bump to 2.10.0


## [2.9.2] - 2025-10-06

### Changed
- Version bump to 2.9.2


## [2.9.1] - 2025-10-06

### Changed
- Version bump to 2.9.1


## [2.9.0] - 2025-10-06

### Changed
- Version bump to 2.9.0


## [2.8.0] - 2025-10-06

### Changed
- Version bump to 2.8.0


## [2.7.0] - 2025-10-06

### Changed
- Version bump to 2.7.0


## [2.6.0] - 2025-10-06

### Changed
- Version bump to 2.6.0


## [2.5.0] - 2025-10-06

### Changed
- Version bump to 2.5.0


## [2.4.0] - 2025-10-06

### Changed
- Version bump to 2.4.0


## [2.3.0] - 2025-10-06

### Changed
- Version bump to 2.3.0


## [2.2.0] - 2025-10-06

### Changed
- Version bump to 2.2.0


## [2.1.0] - 2025-10-05

### Changed
- Version bump to 2.1.0


## [2.0.1] - 2025-10-05

### Changed
- Version bump to 2.0.1


All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-10-05

### Major Refactoring - Modular Architecture

This release represents a complete refactoring of the Fluentd configuration with a focus on modularity, extensibility, and ECS compliance.

### Added

#### New Integrations
- **Palo Alto networks PAN-OS** (port 30518/TCP)
  - Support for all log types: TRAFFIC, THREAT, SYSTEM, CONFIG, USERID, AUTHENTICATION, GLOBALPROTECT
  - CSV parsing with automatic type detection
  - Comprehensive ECS field mapping
  - VPN/GlobalProtect event detection

- **Generic Syslog** (ports 30519/UDP, 30520/TCP)
  - RFC3164/RFC5424 compliant
  - Automatic format detection
  - Severity and facility extraction
  - Suitable for any syslog-compatible device

- **Generic CEF (Common Event Format)** (ports 30521/TCP, 30522/UDP)
  - ArcSight-compatible format
  - Support for Check Point, Imperva, Symantec, McAfee
  - CEF header and extension parsing
  - Automatic ECS field mapping

#### New Architecture
- **Modular integrations**: Each vendor/product has self-contained configuration
- **Shared components**: Common filters and outputs for consistency
- **Integration template**: Easy-to-use template for adding new integrations
- **Patterns directory**: Centralized location for custom grok patterns

#### Documentation
- **INTEGRATIONS.md**: Comprehensive integration guide with examples
- **MIGRATION.md**: Detailed migration guide from v1.0 to v2.0
- **TEMPLATE.conf.example**: Fully documented template for new integrations

#### Plugins
- `fluent-plugin-parser-cri` - CRI log parsing support
- `fluent-plugin-multi-format-parser` - Multiple format parsing
- `fluent-plugin-detect-exceptions` - Exception detection and grouping
- `fluent-plugin-prometheus` - Metrics export for monitoring
- `fluent-plugin-elasticsearch` - Elasticsearch compatibility layer

### Changed

#### Refactored Integrations
- **Fortigate**: Combined CEF and Syslog into single file with improved parsing
  - Better key-value extraction
  - Enhanced VPN event detection
  - Improved error handling
  
- **Cisco ASA**: Enhanced parsing and field extraction
  - ASA message ID and severity extraction
  - VPN event classification by event ID
  - Network field extraction from message text
  - Timestamp parsing improvements

#### Configuration Structure
- Moved from `conf.d/*.conf` to `integrations/*.conf`
- Added `shared/` directory for common components
- Improved main `fluent.conf` with better organization
- Added support for legacy configs (backward compatibility)

#### Field Mapping
- **Full ECS compliance**: All fields now use Elastic Common Schema names
- **Related fields**: Added `related.ip`, `related.user`, `related.hosts` for correlation
- **Observer fields**: Proper `observer.vendor`, `observer.product`, `observer.type`
- **Event classification**: Added `event.category`, `event.type`, `event.kind`

#### Docker Image
- Added system dependencies for plugin compilation
- Improved directory structure with separate paths for integrations and shared configs
- Better error handling in COPY directives
- Updated port exposure to reflect new integrations

### Removed

- **MikroTik integration**: Removed from default integrations
  - Can be re-added using template
  - Use generic syslog as alternative
  - Legacy config still supported in `conf.d/`

### Fixed

- Improved error handling in parsers (no data loss on parse failures)
- Better buffer management with separate failed_records buffer
- Fixed timestamp parsing for various formats
- Improved grok pattern matching with fallback patterns

### Security

- Environment variables properly used for credentials
- No hardcoded passwords or sensitive data
- SSL/TLS properly configured for OpenSearch connections

### Performance

- Optimized buffer settings for better throughput
- Improved parsing efficiency with better pattern matching
- Reduced memory footprint with selective field retention

### Deprecated

- **conf.d/ directory**: Legacy support maintained but deprecated
  - Will be removed in v3.0
  - Migrate to `integrations/` directory
  - See MIGRATION.md for details

## [1.0.0] - 2024-XX-XX

### Added
- Initial release with multi-source syslog support
- OpenSearch/Wazuh Indexer integration
- Automatic ingest pipeline creation
- ECS-compliant field mapping
- GeoIP enrichment for network sources
- File-based buffering with retry logic
- Failed record storage
- Modular configuration system
- Environment variable support
- Docker Compose integration
- Comprehensive documentation:
  - README.md - Full usage guide
  - QUICKSTART.md - Quick start guide
  - PORTS.md - Port reference and device configs
  - SUMMARY.md - Implementation overview
  - CHANGELOG.md - This file

### Pipelines
- MikroTik RouterOS pipeline with comprehensive Grok patterns
- Fortigate CEF pipeline with key-value parsing
- Fortigate Syslog pipeline with session tracking
- Cisco ASA basic pipeline template
- Palo Alto PAN-OS CSV parsing pipeline
- Generic Syslog RFC3164/RFC5424 pipeline

### Scripts
- `config.sh` - Startup configuration and validation
- `setup_pipelines.sh` - Automatic pipeline deployment
- `check_repository.sh` - Repository validation

### Integration
- Added to `build-images.yml` for unified building
- Volume definitions for persistent storage
- Network integration with Wazuh stack

### Documentation
- Device configuration examples for all sources
- Troubleshooting guide
- Performance tuning recommendations
- Migration guide from k3s deployment

## Future Enhancements

### Planned for v1.1.0
- [ ] Additional vendor support (Sophos, pfSense, etc.)
- [ ] Enhanced Cisco ASA pipeline with detailed parsing
- [ ] Improved Palo Alto pipeline with threat intelligence
- [ ] Custom field mapping templates
- [ ] Prometheus metrics exporter
- [ ] Health check endpoint

### Planned for v1.2.0
- [ ] Multi-tenancy support
- [ ] Rate limiting per source
- [ ] Advanced filtering rules
- [ ] Custom enrichment plugins
- [ ] Automated index lifecycle management
- [ ] Dashboard templates

### Under Consideration
- [ ] Kafka output support
- [ ] S3 backup integration
- [ ] Real-time alerting
- [ ] Machine learning anomaly detection
- [ ] IPv6 support
- [ ] TLS encryption for TCP sources

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | 2025-10-05 | Initial release with 6 sources |

## Upgrade Notes

### From k3s Fluentd
If migrating from the k3s deployment:
1. MikroTik configuration remains unchanged (same port 30514)
2. Pipeline is identical to your production version
3. Environment variables replace ConfigMap values
4. Buffer paths are standardized to `/fluentd/buffer/`
5. No device reconfiguration required

## Breaking Changes

None - Initial release

## Known Issues

None reported

## Contributing

To add a new source:
1. Create configuration in `config/conf.d/`
2. Create pipeline in `config/pipelines/`
3. Update Dockerfile EXPOSE directive
4. Update documentation
5. Test thoroughly
6. Submit pull request

## Support

For issues and questions:
- Review documentation in this directory
- Check container logs: `docker logs wazuh-fluentd`
- Verify pipeline creation in OpenSearch
- Test connectivity with netcat

## License

GPLv2 - See LICENSE file in repository root
