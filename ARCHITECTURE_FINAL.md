# Final Architecture - Simplified Hybrid with Filebeat Filtering

## Overview

This architecture achieves:
- ✅ Separate indices per device type (`anki-mikrotik-*`, `anki-esxi-*`)
- ✅ All logs stored (100% retention)
- ✅ Wazuh rule engine for security detection
- ✅ Easy rule management (no Fluentd changes needed)
- ✅ No duplication (Filebeat filters sensor logs from archives)
- ✅ Agent logs preserved in `wazuh-archives-*`

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Log Sources                          │
│  Wazuh Agents | MikroTik | ESXi | Generic Syslog       │
└────────┬────────────────────────────┬───────────────────┘
         │                            │
    Agents (no tag)              Fluentd (data_source=sensor)
         │                            │
         │                            ├─ Parse vendor formats
         │                            ├─ Extract fields
         │                            └─ Add data_source: sensor
         │                            │
         ▼                            ▼
┌──────────────────────────────────────────────────────────┐
│              Wazuh Manager (logall=yes)                  │
│                                                          │
│  Receives:                                              │
│  • Agent logs (no data_source tag)                     │
│  • Sensor logs (data_source=sensor)                    │
│                                                          │
│  Processing:                                            │
│  • JSON Decoder extracts fields                         │
│  • Rules engine checks all logs                         │
│  • Generates alerts for matches                         │
│  • Archives ALL logs locally                            │
└────────┬─────────────────────────────────────────────────┘
         │
         ├─→ /var/ossec/logs/alerts/alerts.json
         └─→ /var/ossec/logs/archives/archives.json
                    │
                    ▼
┌──────────────────────────────────────────────────────────┐
│                    Filebeat                              │
│                                                          │
│  Processors:                                            │
│  • Drop if data.data_source = "sensor"                  │
│  • Drop if data.log_source = "mikrotik"                │
│  • Drop if data.log_source = "vmware-esxi"             │
│                                                          │
│  Result:                                                │
│  • Alerts: ALL (agents + sensors)                      │
│  • Archives: Agents ONLY (sensors filtered out)        │
└────────┬─────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────┐
│              Wazuh Indexer (OpenSearch)                  │
│                                                          │
│  From Filebeat:                                         │
│  • wazuh-alerts-* (all security alerts)                │
│  • wazuh-archives-* (agent logs only)                  │
│                                                          │
│  From Fluentd (direct):                                 │
│  • anki-mikrotik-* (all MikroTik logs)                 │
│  • anki-esxi-* (all ESXi logs)                         │
│  • anki-syslog-* (all generic syslog)                  │
└──────────────────────────────────────────────────────────┘
```

## Data Flow

### Wazuh Agents
```
Agent → Wazuh Manager
  ↓
  ├─ Decoder + Rules
  ├─ Alerts → Filebeat → wazuh-alerts-*
  └─ Archives → Filebeat → wazuh-archives-* ✅
```

### Sensor Logs (Fluentd)
```
Device → Fluentd (parse + tag: data_source=sensor)
  ↓
  ├─→ Wazuh Manager
  │   ├─ Decoder + Rules
  │   ├─ Alerts → Filebeat → wazuh-alerts-* ✅
  │   └─ Archives → Filebeat → DROPPED ❌
  │
  └─→ Indexer → anki-mikrotik-*, anki-esxi-* ✅
```

## Configuration Files

### 1. Fluentd - MikroTik (`10-mikrotik.conf`)

```ruby
<filter mikrotik.**>
  @type record_transformer
  <record>
    log_source mikrotik
    data_source sensor    # ← Tag for Filebeat filtering
    # ... other fields
  </record>
</filter>

# Send ALL logs to BOTH Manager and Indexer
<match mikrotik.**>
  @type copy
  
  <store>
    @type forward
    host wazuh-manager
    port 1514
  </store>
  
  <store>
    @type opensearch
    index_name anki-mikrotik-%Y.%m.%d
  </store>
</match>
```

### 2. Fluentd - ESXi (`15-vmware-esxi.conf`)

```ruby
<filter esxi.**>
  @type record_transformer
  <record>
    log_source vmware-esxi
    data_source sensor    # ← Tag for Filebeat filtering
    # ... other fields
  </record>
</filter>

# Send ALL logs to BOTH Manager and Indexer
<match esxi.**>
  @type copy
  
  <store>
    @type forward
    host wazuh-manager
    port 1514
  </store>
  
  <store>
    @type opensearch
    index_name anki-esxi-%Y.%m.%d
  </store>
</match>
```

### 3. Wazuh Manager (`ossec.conf`)

```xml
<global>
  <jsonout_output>yes</jsonout_output>
  <alerts_log>no</alerts_log>
  <logall>yes</logall>              <!-- Store all logs -->
  <logall_json>yes</logall_json>    <!-- JSON format -->
</global>
```

### 4. Filebeat (`filebeat.yml`)

```yaml
filebeat.modules:
  - module: wazuh
    alerts:
      enabled: true
    archives:
      enabled: true
      
      # Filter OUT sensor logs from archives
      processors:
        - drop_event:
            when:
              or:
                - equals:
                    data.data_source: "sensor"
                - contains:
                    data.log_source: "mikrotik"
                - contains:
                    data.log_source: "vmware-esxi"

output.elasticsearch:
  hosts:
    - "https://wazuh-indexer:9200"
  indices:
    - index: "wazuh-alerts-4.x-%{+yyyy.MM.dd}"
      when.equals:
        event.dataset: "wazuh.alerts"
    - index: "wazuh-archives-4.x-%{+yyyy.MM.dd}"
      when.equals:
        event.dataset: "wazuh.archives"
```

## Indices

| Index | Content | Source | Size (100k logs/day) |
|-------|---------|--------|----------------------|
| `anki-mikrotik-*` | All MikroTik logs | Fluentd direct | 50MB |
| `anki-esxi-*` | All ESXi logs | Fluentd direct | 50MB |
| `anki-syslog-*` | Generic syslog | Fluentd direct | 50MB |
| `wazuh-alerts-*` | Security alerts | Filebeat (all sources) | 10MB |
| `wazuh-archives-*` | Agent logs only | Filebeat (filtered) | 25MB |

**Total: 185MB/day (no duplication!)**

## Benefits

### 1. No Duplication
- ✅ Sensor logs only in `anki-*` (not in archives)
- ✅ Agent logs only in `wazuh-archives-*`
- ✅ Alerts from all sources in `wazuh-alerts-*`

### 2. Separate Indices
- ✅ Device-specific dashboards (`anki-mikrotik-*`, `anki-esxi-*`)
- ✅ Better filtering and search performance
- ✅ Custom retention policies per device type

### 3. Easy Maintenance
- ✅ Add Wazuh rules without touching Fluentd
- ✅ All security logic in one place (Wazuh Manager)
- ✅ Simple Fluentd config (no smart routing)

### 4. Complete Visibility
- ✅ All logs stored (100%)
- ✅ Agent logs safe in Indexer
- ✅ Sensor logs in device-specific indices
- ✅ Security alerts from all sources

### 5. Optimal Performance
- ✅ Wazuh Manager processes all logs (necessary for rules)
- ✅ Filebeat filters efficiently (drop_event processor)
- ✅ No duplicate storage

## Dashboard Usage

### MikroTik Dashboard
```
Index Pattern: anki-mikrotik-*
Use Case: Network operations, traffic analysis, user activity
Fields: src_ip, user, protocol, full_message
```

### ESXi Dashboard
```
Index Pattern: anki-esxi-*
Use Case: VM operations, host management, storage
Fields: vm, esxi_host, user, srcip, action
```

### Security Dashboard
```
Index Pattern: wazuh-alerts-*
Use Case: Security monitoring, threat detection, compliance
Fields: rule.id, rule.level, rule.mitre.id, agent.name, data.*
```

### Agent Forensics
```
Index Pattern: wazuh-archives-*
Use Case: Agent log forensics, troubleshooting
Fields: agent.name, data.*, full_log
```

## Adding New Rules

**No Fluentd changes needed!**

1. Edit `wazuh-manager/config/rules/mikrotik-rules.xml`
2. Add new rule:
```xml
<rule id="100020" level="8">
  <if_sid>100001</if_sid>
  <field name="mikrotik.parsed.action">brute force detected</field>
  <description>MikroTik: Brute force attack detected</description>
  <mitre>
    <id>T1110</id>
  </mitre>
</rule>
```
3. Deploy: `docker cp mikrotik-rules.xml wazuh-manager:/var/ossec/etc/rules/`
4. Restart: `docker exec wazuh-manager /var/ossec/bin/wazuh-control restart`

**Done!** Rule applies to all logs automatically.

## Testing

### Test End-to-End

```bash
# Send test log
echo '<134>Oct 10 21:00:00 192.168.1.1 system,error login failure for user admin from 192.168.1.100 via ssh' | \
  nc -u localhost 30514

# Wait 15 seconds

# Check device-specific index
curl -k -u admin:password \
  "https://wazuh-indexer:9200/anki-mikrotik-*/_search?size=1&pretty"

# Check alerts
curl -k -u admin:password \
  "https://wazuh-indexer:9200/wazuh-alerts-*/_search?q=mikrotik&size=1&pretty"

# Verify NO sensor logs in archives
curl -k -u admin:password \
  "https://wazuh-indexer:9200/wazuh-archives-*/_search?q=data_source:sensor&pretty"
# Should return 0 results!
```

## Monitoring

### Check Filebeat Filtering

```bash
# View Filebeat logs
docker exec wazuh-manager tail -f /var/log/filebeat/filebeat

# Should see dropped events:
# "drop_event processor: event dropped"
```

### Check Storage

```bash
# Index sizes
curl -k -u admin:password \
  "https://wazuh-indexer:9200/_cat/indices/anki-*,wazuh-*?v&h=index,docs.count,store.size&s=index"
```

## Troubleshooting

### Sensor logs appearing in archives?

Check Filebeat processors:
```bash
docker exec wazuh-manager cat /etc/filebeat/filebeat.yml | grep -A10 processors
```

### Agent logs not in archives?

Check Wazuh Manager config:
```bash
docker exec wazuh-manager grep -A5 "<global>" /var/ossec/etc/ossec.conf
# Should show logall=yes
```

### Rules not matching?

Test locally:
```bash
cd wazuh-manager
./test-rules.sh quick
```

## Summary

**This architecture provides:**
- ✅ Separate indices per device type
- ✅ All logs stored (no data loss)
- ✅ Wazuh rules for security detection
- ✅ Easy rule management
- ✅ No duplication
- ✅ Agent logs safe in Indexer
- ✅ Optimal performance

**Perfect for production!** 🎉
