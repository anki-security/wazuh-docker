# Architecture Summary: Custom Indices + Wazuh Rules

Complete setup for custom index names (`anki-*`) with Wazuh rule engine.

## Final Architecture

```
┌─────────────────┐
│   Log Sources   │
│  (MikroTik,     │
│   ESXi, etc.)   │
└────────┬────────┘
         │ Syslog (UDP)
         ▼
┌─────────────────────────────────┐
│         Fluentd                 │
│                                 │
│  • Parse with Grok/Regex        │
│  • Extract fields               │
│  • Format as JSON               │
└────────┬────────────────────────┘
         │
         ├──────────────────────────┐
         │                          │
         ▼                          ▼
┌─────────────────┐      ┌──────────────────┐
│ Wazuh Manager   │      │ Wazuh Indexer    │
│ (Port 1514)     │      │ (Port 9200)      │
│                 │      │                  │
│ • JSON Decoder  │      │ • Raw logs       │
│ • Security Rules│      │ • No processing  │
│ • MITRE ATT&CK  │      │                  │
│ • Enrichment    │      │ Index:           │
└────────┬────────┘      │ anki-mikrotik-*  │
         │               └──────────────────┘
         │ Alerts
         ▼
┌─────────────────┐
│ Wazuh Indexer   │
│                 │
│ Index:          │
│ wazuh-alerts-*  │
│ (or custom)     │
└─────────────────┘
```

## Index Strategy

### Recommended: Dual Indices

| Index | Purpose | Source | Content |
|-------|---------|--------|---------|
| `anki-mikrotik-*` | Raw logs | Fluentd → Indexer | All logs, parsed fields, no rules |
| `wazuh-alerts-*` | Security alerts | Wazuh Manager → Indexer | Only alerts, rule enriched |

**Benefits:**
- ✅ Custom naming for raw logs
- ✅ Wazuh rule engine for alerts
- ✅ Complete audit trail
- ✅ Separate retention policies

### Alternative: Custom Alert Index

Change Wazuh Manager to use custom index name:

| Index | Purpose | Source | Content |
|-------|---------|--------|---------|
| `anki-mikrotik-raw-*` | Raw logs | Fluentd → Indexer | All logs |
| `anki-mikrotik-alerts-*` | Security alerts | Wazuh Manager → Indexer | Alerts only |

## Configuration Files

### 1. Fluentd: Hybrid Output

**File:** `wazuh-fluentd/config/conf.d/10-mikrotik.conf`

```ruby
<source>
  @type udp
  port 30514
  bind 0.0.0.0
  tag mikrotik.syslog
  source_address_key source_ip
  <parse>
    @type none
  </parse>
</source>

<filter mikrotik.**>
  @type record_transformer
  enable_ruby true
  <record>
    log_source mikrotik
    vendor mikrotik
    product routeros
    hostname ${record["source_ip"] || "unknown"}
    timestamp ${time.strftime('%Y-%m-%dT%H:%M:%S.%LZ')}
    full_message ${record["message"]}
  </record>
</filter>

# Parse specific patterns
<filter mikrotik.**>
  @type parser
  key_name message
  reserve_data true
  inject_key_prefix parsed.
  <parse>
    @type multi_format
    
    <pattern>
      format regexp
      expression /login failure for user (?<user>\S+) from (?<src_ip>\S+) via (?<protocol>\S+)/
    </pattern>
    
    <pattern>
      format regexp
      expression /user (?<user>\S+) logged in from (?<src_ip>\S+) via (?<protocol>\S+)/
    </pattern>
    
    # Add more patterns as needed
  </parse>
</filter>

# Dual output
<match mikrotik.**>
  @type copy
  
  # To Wazuh Manager (for rules)
  <store>
    @type forward
    <server>
      host wazuh-manager
      port 1514
    </server>
    <format>
      @type json
    </format>
    <buffer>
      @type file
      path /fluentd/buffer/mikrotik-wazuh
      flush_interval 5s
    </buffer>
  </store>
  
  # To Indexer (for raw logs)
  <store>
    @type opensearch
    host wazuh-indexer
    port 9200
    scheme https
    ssl_verify false
    user "#{ENV['INDEXER_USERNAME']}"
    password "#{ENV['INDEXER_PASSWORD']}"
    
    # Custom index name
    index_name anki-mikrotik-%Y.%m.%d
    
    <buffer tag, time>
      @type file
      path /fluentd/buffer/mikrotik-indexer
      timekey 60s
      flush_interval 10s
    </buffer>
  </store>
</match>
```

### 2. Wazuh Manager: JSON Decoder

**File:** `wazuh-manager/config/decoders/mikrotik-json-decoder.xml`

```xml
<decoder name="mikrotik-json">
  <prematch>^{.*"log_source"\s*:\s*"mikrotik"</prematch>
</decoder>

<decoder name="mikrotik-json-child">
  <parent>mikrotik-json</parent>
  <plugin_decoder>JSON_Decoder</plugin_decoder>
</decoder>
```

### 3. Wazuh Manager: Security Rules

**File:** `wazuh-manager/config/rules/mikrotik-rules.xml`

```xml
<group name="mikrotik,syslog,authentication,">
  
  <rule id="100001" level="0">
    <decoded_as>mikrotik-json</decoded_as>
    <description>MikroTik RouterOS log.</description>
  </rule>

  <rule id="100011" level="5">
    <if_sid>100001</if_sid>
    <field name="mikrotik.full_message">login failure</field>
    <description>MikroTik: Login failure for user $(mikrotik.parsed.user) from $(mikrotik.parsed.src_ip)</description>
    <mitre>
      <id>T1110</id>
    </mitre>
  </rule>
  
  <!-- More rules... -->
</group>
```

## Query Examples

### Query Raw Logs (All Events)

**Index:** `anki-mikrotik-*`

```json
GET anki-mikrotik-*/_search
{
  "query": {
    "bool": {
      "must": [
        { "match": { "log_source": "mikrotik" }},
        { "range": { "timestamp": { "gte": "now-1h" }}}
      ]
    }
  }
}
```

### Query Security Alerts (Rules Matched)

**Index:** `wazuh-alerts-*`

```json
GET wazuh-alerts-*/_search
{
  "query": {
    "bool": {
      "must": [
        { "match": { "data.mikrotik.log_source": "mikrotik" }},
        { "range": { "rule.level": { "gte": 5 }}}
      ]
    }
  }
}
```

### Query by MITRE ATT&CK

```json
GET wazuh-alerts-*/_search
{
  "query": {
    "match": { "rule.mitre.id": "T1110" }
  }
}
```

## Dashboard Configuration

### Index Patterns

Create two index patterns in Wazuh Dashboard:

1. **`anki-mikrotik-*`**
   - Time field: `timestamp`
   - Purpose: Raw log analysis

2. **`wazuh-alerts-*`**
   - Time field: `timestamp`
   - Purpose: Security alerts (already exists)

### Visualizations

**Raw Logs Dashboard:**
- Top source IPs
- Event types over time
- Failed vs successful logins
- Network traffic patterns

**Security Alerts Dashboard:**
- Alerts by severity
- MITRE ATT&CK heatmap
- Top triggered rules
- Alert trends

## Storage & Retention

### Recommended Settings

| Index | Retention | Daily Size | Purpose |
|-------|-----------|------------|---------|
| `anki-mikrotik-*` | 30 days | ~500MB | Forensics, troubleshooting |
| `wazuh-alerts-*` | 90 days | ~100MB | Security alerts, compliance |

### Index Lifecycle Management (ILM)

```json
PUT _ilm/policy/anki-mikrotik-policy
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_age": "1d",
            "max_size": "50gb"
          }
        }
      },
      "delete": {
        "min_age": "30d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
```

## Deployment Steps

### 1. Deploy Fluentd Config

```bash
# Copy hybrid config
cp wazuh-fluentd/config/conf.d/10-mikrotik-hybrid.conf.example \
   wazuh-fluentd/config/conf.d/10-mikrotik.conf

# Restart Fluentd
docker restart wazuh-fluentd
```

### 2. Deploy Wazuh Decoders & Rules

```bash
# Copy to Wazuh Manager
docker cp wazuh-manager/config/decoders/mikrotik-json-decoder.xml \
  wazuh-manager:/var/ossec/etc/decoders/

docker cp wazuh-manager/config/rules/mikrotik-rules.xml \
  wazuh-manager:/var/ossec/etc/rules/

# Restart Wazuh Manager
docker exec wazuh-manager /var/ossec/bin/wazuh-control restart
```

### 3. Test

```bash
# Test rules locally
cd wazuh-manager
./test-rules.sh validate
./test-rules.sh test-all

# Send test log
echo '<134>Oct 10 19:00:00 192.168.1.1 system,error login failure for user admin from 192.168.1.100 via ssh' | \
  nc -u -w1 fluentd-host 30514

# Check indices
curl -k -u admin:password https://wazuh-indexer:9200/_cat/indices/anki-*
curl -k -u admin:password https://wazuh-indexer:9200/_cat/indices/wazuh-alerts-*
```

### 4. Verify

**Check Raw Logs:**
```bash
curl -k -u admin:password \
  "https://wazuh-indexer:9200/anki-mikrotik-*/_search?size=1&pretty"
```

**Check Alerts:**
```bash
curl -k -u admin:password \
  "https://wazuh-indexer:9200/wazuh-alerts-*/_search?q=mikrotik&size=1&pretty"
```

## Benefits Summary

✅ **Custom Index Names** - `anki-mikrotik-*` for your organization
✅ **Wazuh Rule Engine** - Full security rule processing
✅ **MITRE ATT&CK** - Automatic threat framework mapping
✅ **Complete Audit Trail** - Raw logs + alerts
✅ **Flexible Retention** - Different policies per index
✅ **Compliance Ready** - PCI-DSS, HIPAA, GDPR tags
✅ **Active Response** - Automated threat response
✅ **Forensics** - Full raw log history

## Next Steps

1. ✅ Deploy hybrid Fluentd config
2. ✅ Deploy Wazuh decoders and rules
3. ✅ Test with sample logs
4. 📊 Create dashboards
5. 🔔 Configure alert notifications
6. 📝 Document custom rules
7. 🧪 Regular testing and tuning

## Resources

- [Hybrid Config Example](wazuh-fluentd/config/conf.d/10-mikrotik-hybrid.conf.example)
- [Testing Guide](wazuh-manager/README-TESTING.md)
- [Wazuh Integration Guide](wazuh-fluentd/WAZUH_INTEGRATION.md)
- [Alerting Setup](wazuh-fluentd/ALERTING_SETUP.md)
