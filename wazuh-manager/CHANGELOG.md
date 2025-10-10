# Changelog

## [1.0.0] - 2025-10-10

### Added
- Initial release of Wazuh Manager configurations
- MikroTik JSON decoder with dynamic field extraction
- ESXi JSON decoder with dynamic field extraction
- 20+ MikroTik security rules (authentication, user management, firewall, VPN)
- 20+ ESXi security rules (SSH, VM operations, account management, file operations)
- MITRE ATT&CK mappings for all rules
- Compliance tags (PCI-DSS, GDPR, HIPAA, NIST 800-53)
- Local testing tools (test-rules.sh)
- Sample log files for testing
- Filebeat configuration for sensor log filtering
- Comprehensive documentation

### Features
- JSON-based log processing with automatic field extraction
- Frequency-based rules for brute force detection
- Cryptomining detection for ESXi
- Rogue DHCP detection for MikroTik
- VPN activity monitoring
- Firewall rule change detection
