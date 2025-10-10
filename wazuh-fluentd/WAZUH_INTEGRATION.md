# Fluentd → Wazuh Manager Integration

## Architecture: Parse in Fluentd, Rules in Wazuh

```
┌─────────────┐
│ Log Sources │
│ (MikroTik,  │
│  ESXi)      │
└──────┬──────┘
       │ Raw Syslog
       ▼
┌─────────────────────────────────────┐
│          Fluentd                    │
│                                     │
│  • Receive syslog                   │
│  • Parse with Grok/Regex            │
│  • Extract fields                   │
│  • Enrich metadata                  │
│  • Format as JSON                   │
└──────┬──────────────────────────────┘
       │ Structured JSON
       │ {
       │   "log_source": "mikrotik",
       │   "user": "admin",
       │   "srcip": "192.168.1.100",
       │   "full_message": "login failure..."
       │ }
       ▼
┌─────────────────────────────────────┐
│       Wazuh Manager                 │
│                                     │
│  • JSON Decoder (simple mapping)    │
│  • Security Rules                   │
│  • MITRE ATT&CK tagging             │
│  • Threat Intelligence              │
│  • Active Response                  │
│  • Compliance mapping               │
└──────┬──────────────────────────────┘
       │ Alerts
       ▼
┌─────────────┐
│   Wazuh     │
│  Indexer    │
│             │
│ wazuh-      │
│ alerts-*    │
└─────────────┘
```

## Why This Approach?

### ✅ Advantages

1. **Best of Both Worlds**
   - Fluentd: Fast, efficient parsing (Grok patterns)
   - Wazuh: Security rules, threat intel, compliance

2. **Simple Wazuh Decoders**
   - No complex regex in Wazuh
   - Just JSON field mapping
   - Easy to maintain

3. **Centralized Security**
   - All alerts in Wazuh dashboard
   - MITRE ATT&CK framework
   - Compliance reporting (PCI-DSS, HIPAA)
   - Active Response capabilities

4. **Flexible Parsing**
   - Fluentd handles complex formats
   - Easy to add new log sources
   - Reuse existing Grok patterns

5. **Performance**
   - Fluentd does heavy lifting
   - Wazuh focuses on security logic
   - Better resource utilization

### ⚠️ Considerations

1. **Additional Component**
   - Wazuh Manager must be running
   - Network connectivity required
   - Fluentd → Manager (port 1514)

2. **Resource Usage**
   - Wazuh Manager processes all logs
   - Consider volume and scaling

3. **Latency**
   - Extra hop adds ~100-500ms
   - Acceptable for security use cases

## Setup Instructions

### Step 1: Configure Fluentd

Copy example config and customize:

```bash
cd /path/to/wazuh-fluentd/config/conf.d

# MikroTik
cp 10-mikrotik-wazuh.conf.example 10-mikrotik-wazuh.conf

# Edit and customize parsing rules
vi 10-mikrotik-wazuh.conf
```

Key configuration:

```ruby
<match mikrotik.**>
  @type forward
  
  <server>
    host wazuh-manager
    port 1514
  </server>
  
  <format>
    @type json  # Send as JSON
  </format>
</match>
```

### Step 2: Deploy Wazuh Decoders

Copy decoders to Wazuh Manager:

```bash
# MikroTik decoder
docker cp wazuh-manager/config/decoders/mikrotik-json-decoder.xml \
  wazuh-manager:/var/ossec/etc/decoders/

# ESXi decoder
docker cp wazuh-manager/config/decoders/esxi-json-decoder.xml \
  wazuh-manager:/var/ossec/etc/decoders/
```

Or mount as volume in docker-compose:

```yaml
services:
  wazuh-manager:
    volumes:
      - ./wazuh-manager/config/decoders:/var/ossec/etc/decoders:ro
```

### Step 3: Deploy Wazuh Rules

```bash
# MikroTik rules
docker cp wazuh-manager/config/rules/mikrotik-rules.xml \
  wazuh-manager:/var/ossec/etc/rules/

# ESXi rules
docker cp wazuh-manager/config/rules/esxi-rules.xml \
  wazuh-manager:/var/ossec/etc/rules/
```

Or mount as volume:

```yaml
services:
  wazuh-manager:
    volumes:
      - ./wazuh-manager/config/rules:/var/ossec/etc/rules:ro
```

### Step 4: Restart Services

```bash
# Restart Wazuh Manager to load new decoders/rules
docker exec wazuh-manager /var/ossec/bin/wazuh-control restart

# Restart Fluentd to apply new config
docker restart wazuh-fluentd
```

### Step 5: Verify

Check Wazuh Manager logs:

```bash
# Watch for incoming logs
docker exec wazuh-manager tail -f /var/ossec/logs/ossec.log

# Check if decoder is working
docker exec wazuh-manager /var/ossec/bin/wazuh-logtest
```

Test with sample JSON:

```json
{
  "log_source": "mikrotik",
  "vendor": "mikrotik",
  "product": "routeros",
  "hostname": "192.168.1.1",
  "timestamp": "2025-10-10T18:55:00.000Z",
  "full_message": "login failure for user admin from 192.168.1.100 via ssh",
  "parsed": {
    "user": "admin",
    "src_ip": "192.168.1.100",
    "protocol": "ssh"
  }
}
```

## JSON Field Mapping

### MikroTik Fields

| Fluentd JSON Field | Wazuh Field | Description |
|--------------------|-------------|-------------|
| `log_source` | `log_source` | Always "mikrotik" |
| `hostname` | `hostname` | Router IP/hostname |
| `full_message` | `full_message` | Original syslog message |
| `parsed.user` | `user` | Username |
| `parsed.src_ip` | `srcip` | Source IP address |
| `parsed.dst_ip` | `dstip` | Destination IP |
| `parsed.protocol` | `protocol` | Protocol (ssh, telnet, etc.) |
| `parsed.src_port` | `srcport` | Source port |
| `parsed.dst_port` | `dstport` | Destination port |

### ESXi Fields

| Fluentd JSON Field | Wazuh Field | Description |
|--------------------|-------------|-------------|
| `log_source` | `log_source` | Always "vmware-esxi" |
| `parsed.esxi_host` | `esxi_host` | ESXi hostname |
| `parsed.user` | `user` | Username |
| `parsed.srcip` | `srcip` | Source IP |
| `parsed.vm` | `vm_name` | VM name |
| `parsed.event_id` | `event_id` | ESXi event ID |
| `parsed.command` | `command` | Executed command |
| `parsed.path` | `file_path` | File path |

## Wazuh Rules Overview

### MikroTik Rules (100001-100099)

| Rule ID | Level | Description | MITRE ATT&CK |
|---------|-------|-------------|--------------|
| 100010 | 3 | User logged in | T1078 |
| 100011 | 5 | Login failure | T1110 |
| 100012 | 10 | Multiple login failures (5 in 2min) | T1110 |
| 100013 | 12 | Brute force (10 in 5min) | T1110.001 |
| 100020 | 8 | User added | T1136 |
| 100021 | 8 | User removed | T1531 |
| 100030 | 8 | Firewall rule changed | T1562.004 |
| 100060 | 3 | Rogue DHCP server | T1557.002 |

### ESXi Rules (100100-100199)

| Rule ID | Level | Description | MITRE ATT&CK |
|---------|-------|-------------|--------------|
| 100110 | 3 | SSH session opened | T1078 |
| 100111 | 5 | SSH login failed | T1110 |
| 100112 | 10 | Multiple SSH failures (3 in 2min) | T1110 |
| 100134 | 5 | VM created | T1578.002 |
| 100135 | 7 | VM removed | T1578.003 |
| 100140 | 8 | Account created | T1136 |
| 100150 | 4 | File upload | T1105 |
| 100151 | 6 | File deletion | T1485 |
| 100170 | 10 | Multiple VMs created (cryptomining) | T1578.002 |

## Alert Levels

| Level | Severity | Action | Examples |
|-------|----------|--------|----------|
| 0-3 | Info | Log only | Successful login, routine events |
| 4-7 | Low-Medium | Review | Failed login, config change |
| 8-11 | High | Alert | Account creation, firewall change |
| 12-15 | Critical | Immediate | Brute force, multiple violations |

## Testing

### Generate Test Events

**MikroTik Login Failure:**

```bash
# Send to Fluentd
echo '<134>Oct 10 18:55:00 192.168.1.1 system,error,critical login failure for user admin from 192.168.1.100 via ssh' | \
  nc -u -w1 fluentd-host 30514
```

**ESXi SSH Failure:**

```bash
# Send to Fluentd
echo '<134>Oct 10 18:55:00 esxi01 Hostd[12345]: Event 1001 : SSH login has failed for '\''root@10.0.0.50'\''' | \
  nc -u -w1 fluentd-host 30527
```

### Check Wazuh Alerts

```bash
# View recent alerts
docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.log

# Query alerts in Wazuh Dashboard
# Go to: Security Events → Events
# Filter: rule.id:100011 (MikroTik login failure)
```

## Customization

### Add New Parsing Rules in Fluentd

Edit Fluentd config:

```ruby
<filter mikrotik.**>
  @type parser
  key_name message
  <parse>
    @type regexp
    expression /your custom pattern (?<field>\S+)/
  </parse>
</filter>
```

### Add New Wazuh Rules

Edit `mikrotik-rules.xml`:

```xml
<rule id="100099" level="8">
  <if_sid>100001</if_sid>
  <field name="full_message">your pattern</field>
  <description>Your custom rule</description>
  <mitre>
    <id>T1234</id>
  </mitre>
</rule>
```

Restart Wazuh Manager:

```bash
docker exec wazuh-manager /var/ossec/bin/wazuh-control restart
```

## Troubleshooting

### Logs Not Reaching Wazuh Manager

1. **Check Fluentd connectivity:**
   ```bash
   docker exec wazuh-fluentd nc -zv wazuh-manager 1514
   ```

2. **Check Fluentd logs:**
   ```bash
   docker logs wazuh-fluentd | grep -i error
   ```

3. **Verify Fluentd buffer:**
   ```bash
   docker exec wazuh-fluentd ls -lh /fluentd/buffer/
   ```

### Decoder Not Working

1. **Test decoder:**
   ```bash
   docker exec -it wazuh-manager /var/ossec/bin/wazuh-logtest
   # Paste your JSON
   ```

2. **Check decoder syntax:**
   ```bash
   docker exec wazuh-manager /var/ossec/bin/wazuh-logtest -t
   ```

3. **View decoder logs:**
   ```bash
   docker exec wazuh-manager tail -f /var/ossec/logs/ossec.log | grep decoder
   ```

### Rules Not Triggering

1. **Check rule syntax:**
   ```bash
   docker exec wazuh-manager /var/ossec/bin/wazuh-logtest -t
   ```

2. **View rule debugging:**
   ```bash
   docker exec wazuh-manager tail -f /var/ossec/logs/ossec.log | grep rule
   ```

3. **Verify rule level:**
   - Rules level 0-3 don't generate alerts by default
   - Check `/var/ossec/etc/ossec.conf` for `<log_alert_level>`

## Performance Tuning

### Fluentd

```ruby
<match mikrotik.**>
  <buffer>
    flush_interval 5s      # Adjust based on volume
    chunk_limit_size 8MB   # Increase for high volume
    total_limit_size 1GB   # Adjust based on disk
  </buffer>
</match>
```

### Wazuh Manager

Edit `/var/ossec/etc/ossec.conf`:

```xml
<global>
  <logall>no</logall>              <!-- Disable if high volume -->
  <logall_json>no</logall_json>
</global>

<alerts>
  <log_alert_level>3</log_alert_level>  <!-- Minimum alert level -->
</alerts>
```

## Next Steps

1. ✅ Deploy Fluentd configs
2. ✅ Deploy Wazuh decoders and rules
3. 🔄 Test with sample events
4. 📊 Create Wazuh dashboards
5. 🔔 Configure alert notifications
6. 📝 Document custom rules
7. 🧪 Regular testing and tuning

## Resources

- [Wazuh JSON Decoder Documentation](https://documentation.wazuh.com/current/user-manual/ruleset/decoders/json-decoder.html)
- [Wazuh Rule Syntax](https://documentation.wazuh.com/current/user-manual/ruleset/rules/index.html)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [Fluentd Forward Protocol](https://docs.fluentd.org/output/forward)
