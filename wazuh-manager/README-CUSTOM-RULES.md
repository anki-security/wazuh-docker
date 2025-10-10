# Custom Rules and Decoders

## Overview

This Wazuh Manager image includes custom rules and decoders for network devices that send logs via Fluentd in JSON format.

## Location in Container

- **Rules**: `/var/ossec/etc/rules/*.xml`
- **Decoders**: `/var/ossec/etc/decoders/*.xml`

These files are automatically loaded by Wazuh Manager on startup.

## Included Custom Rules

### MikroTik RouterOS (`mikrotik-rules.xml`)

**Rule Range**: 100001-100099

#### Authentication Events
- `100010` (Level 3): User logged in
- `100011` (Level 5): Login failure
- `100012` (Level 10): Multiple login failures (5 in 120s)
- `100013` (Level 12): Brute force attack (10 in 300s)
- `100014` (Level 3): User logged out

#### User Management - CRITICAL
- `100020` (Level 10): User account created
- `100021` (Level 12): **CRITICAL** - Admin user with FULL privileges created
- `100022` (Level 10): User account deleted
- `100023` (Level 9): User account modified
- `100024` (Level 11): **CRITICAL** - User account DISABLED
- `100025` (Level 10): User account ENABLED
- `100026` (Level 11): **CRITICAL** - User promoted to FULL admin
- `100027` (Level 9): Password changed
- `100028` (Level 8): Privileges downgraded to read-only
- `100029` (Level 8): Privileges changed to write

#### Firewall Rules
- `100030` (Level 8): Firewall filter rule modified
- `100031` (Level 8): Firewall raw rule modified
- `100032` (Level 10): Multiple firewall rule changes (3 in 60s)

#### VPN Events
- `100040` (Level 3): WireGuard VPN activity
- `100041` (Level 3): OpenVPN activity
- `100042` (Level 3): L2TP VPN activity
- `100043` (Level 3): IPsec VPN activity

#### Network Events
- `100050` (Level 2): Network interface link up
- `100051` (Level 4): Network interface link down
- `100052` (Level 5): Multiple interface link down events (10 in 60s)

#### DHCP Events
- `100060` (Level 3): Rogue DHCP server detected
- `100061` (Level 2): DHCP address assigned

### VMware ESXi (`esxi-rules.xml`)

**Rule Range**: 100100-100199

#### Authentication
- `100110` (Level 3): User logged in
- `100111` (Level 5): Login failure
- `100112` (Level 10): Multiple login failures (5 in 120s)
- `100113` (Level 12): Brute force attack (10 in 300s)

#### User Management
- `100120` (Level 8): User account created
- `100121` (Level 8): User account deleted
- `100122` (Level 7): User account modified
- `100123` (Level 7): Password changed

#### VM Operations
- `100130` (Level 3): VM powered on
- `100131` (Level 3): VM powered off
- `100132` (Level 4): VM suspended
- `100133` (Level 4): VM deleted
- `100134` (Level 3): VM created
- `100135` (Level 3): VM migrated

#### Host Operations
- `100140` (Level 4): Host entered maintenance mode
- `100141` (Level 3): Host exited maintenance mode
- `100142` (Level 5): Host disconnected
- `100143` (Level 3): Host connected
- `100144` (Level 6): Host rebooted

#### Storage
- `100150` (Level 5): Datastore low space warning
- `100151` (Level 7): Datastore critically low space
- `100152` (Level 4): Datastore disconnected

#### Network
- `100160` (Level 4): Network adapter disconnected
- `100161` (Level 3): Network adapter connected

### NetFlow (`netflow-rules.xml`)

**Rule Range**: 100200-100299

#### Base Rule
- `100200` (Level 0): Base NetFlow event

#### High Volume Traffic
- `100210` (Level 5): High volume traffic (100+ flows in 60s)
- `100211` (Level 7): Very high volume traffic (500+ flows in 60s)

#### Port Scanning
- `100220` (Level 7): Port scanning detected (50+ unique ports in 60s)
- `100221` (Level 9): Aggressive port scanning (100+ unique ports in 60s)

#### External SSH/FTP - HIGH PRIORITY
- `100230` (Level 8): **HIGH** - External SSH connection to internet
- `100231` (Level 8): **HIGH** - External FTP connection to internet

#### Data Exfiltration
- `100232` (Level 7): Large data transfer (>100MB in 60s)
- `100233` (Level 9): Massive data transfer (>1GB in 60s)
- `100234` (Level 8): High packet rate (>10000 packets in 60s)

#### Suspicious Ports
- `100240` (Level 5): Traffic to suspicious high port (>49152)
- `100241` (Level 6): Traffic to known backdoor port (31337, 12345, 54321)

#### Lateral Movement
- `100260` (Level 5): Multiple SMB connections (20+ in 60s)
- `100261` (Level 5): Multiple RDP connections (10+ in 60s)

#### Cryptocurrency Mining
- `100270` (Level 7): Cryptocurrency mining pool connection

#### Anonymization
- `100280` (Level 6): Tor network connection
- `100281` (Level 5): VPN/Proxy connection

#### Internal Scanning
- `100290` (Level 4): Internal network scanning

## Included Custom Decoders

### MikroTik JSON Decoder (`mikrotik-json-decoder.xml`)

Decodes JSON logs from Fluentd with MikroTik data:
- Extracts: `log_source`, `vendor`, `product`, `hostname`, `full_message`
- Nested fields: `mikrotik.parsed.*` (user, src_ip, protocol, etc.)

### VMware ESXi JSON Decoder (`esxi-json-decoder.xml`)

Decodes JSON logs from Fluentd with ESXi data:
- Extracts: `log_source`, `vendor`, `product`, `hostname`, `full_message`
- Nested fields: `esxi.parsed.*` (user, vm_name, host_name, etc.)

### NetFlow JSON Decoder (`netflow-json-decoder.xml`)

Decodes JSON logs from Fluentd with NetFlow data:
- Extracts: `log_source`, `vendor`, `product`, `src_ip`, `dst_ip`, `src_port`, `dst_port`
- Flow metadata: `bytes`, `packets`, `protocol`

## MITRE ATT&CK Mappings

All rules include MITRE ATT&CK technique mappings for threat intelligence correlation:

- **T1078**: Valid Accounts
- **T1110**: Brute Force
- **T1136**: Create Account
- **T1098**: Account Manipulation
- **T1531**: Account Access Removal
- **T1562.004**: Disable or Modify System Firewall
- **T1021.002**: SMB/Windows Admin Shares
- **T1021.001**: Remote Desktop Protocol
- **T1498**: Network Denial of Service
- **T1071.001**: Web Protocols
- **T1090**: Proxy
- And more...

## Testing

Test rules with sample logs:
```bash
cd wazuh-manager
./test-rules.sh validate
```

Sample logs are in `test-logs/`:
- `mikrotik-samples.txt`
- `esxi-samples.txt`
- `netflow-samples.txt`

## Adding New Rules

1. Create or edit XML file in `config/rules/`
2. Follow Wazuh rule syntax
3. Use unique rule IDs:
   - 100000-100099: MikroTik
   - 100100-100199: ESXi
   - 100200-100299: NetFlow
   - 100300+: Reserved for future devices
4. Test with `./test-rules.sh validate`
5. Rebuild Docker image

## Adding New Decoders

1. Create or edit XML file in `config/decoders/`
2. Follow Wazuh decoder syntax
3. Match the JSON structure from Fluentd
4. Test with sample logs
5. Rebuild Docker image

## Automatic Loading

Custom rules and decoders are automatically loaded because:
1. Dockerfile copies them to `/var/ossec/etc/rules/` and `/var/ossec/etc/decoders/`
2. Wazuh Manager scans these directories on startup
3. No additional configuration needed in `ossec.conf`

## Version

Current version: **1.1.0**

## References

- [Wazuh Rules Documentation](https://documentation.wazuh.com/current/user-manual/ruleset/rules-classification.html)
- [Wazuh Decoders Documentation](https://documentation.wazuh.com/current/user-manual/ruleset/decoders.html)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
