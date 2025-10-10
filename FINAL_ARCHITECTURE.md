# Final Architecture - Simplified Hybrid with Filebeat Filtering

Implementation of the optimal log processing architecture with custom indices and Wazuh rules.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
{{ ... }}
│                    Layer 1: Fluentd                         │
│                                                             │
│  • Receives raw syslog                                      │
│  • Basic parsing (extract fields)                           │
│  • Format as JSON                                           │
│  • Smart routing (security vs operational)                  │
└────────────┬────────────────────────────┬───────────────────┘
             │                            │
             │ Security Events (10%)      │ All Logs (100%)
             ▼                            ▼
┌─────────────────────────┐    ┌──────────────────────────┐
│   Layer 2: Wazuh        │    │  Direct to Indexer       │
│   Manager               │    │                          │
│                         │    │  Index:                  │
│  • JSON Decoder         │    │  anki-mikrotik-*         │
│  • Security Rules       │    │                          │
│  • MITRE ATT&CK         │    │  (No pipeline needed)    │
│  • Compliance Tags      │    └──────────────────────────┘
│  • Active Response      │
└────────────┬────────────┘
             │ Alerts
             ▼
┌─────────────────────────┐
│   Filebeat              │
│   (Built into Wazuh)    │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│              Layer 3: OpenSearch Ingest Pipeline            │
│                                                             │
│  • GeoIP enrichment                                         │
│  • ECS field mapping                                        │
│  • Risk score calculation                                   │
│  • Event categorization                                     │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────┐
│   Wazuh Indexer         │
│                         │
│   Index:                │
│   wazuh-alerts-*        │
│                         │
│   (Enriched alerts)     │
└─────────────────────────┘
```

## Complete Data Flow

### 1. Raw Log → Fluentd

**Input:**
```
<134>Oct 10 21:00:00 192.168.1.1 system,error login failure for user admin from 192.168.1.100 via ssh
```

**Fluentd Processing:**
- Parse syslog format
- Extract: user, src_ip, protocol
- Add metadata: log_source, vendor, timestamp
- Format as JSON

**Output:**
```json
{
  "log_source": "mikrotik",
  "vendor": "mikrotik",
  "hostname": "192.168.1.1",
  "timestamp": "2025-10-10T21:00:00.000Z",
  "full_message": "login failure for user admin from 192.168.1.100 via ssh",
  "parsed": {
    "user": "admin",
    "src_ip": "192.168.1.100",
    "protocol": "ssh"
  }
}
```

### 2. JSON → Wazuh Manager

**Wazuh Decoder:**
```xml
<decoder name="mikrotik-json">
  <prematch>^{.*"log_source"\s*:\s*"mikrotik"</prematch>
</decoder>

<decoder name="mikrotik-json-child">
  <parent>mikrotik-json</parent>
  <plugin_decoder>JSON_Decoder</plugin_decoder>
</decoder>
```

**Extracted Fields:**
- `mikrotik.log_source`
- `mikrotik.parsed.user`
- `mikrotik.parsed.src_ip`
- `mikrotik.full_message`

**Wazuh Rule Matches:**
```xml
<rule id="100011" level="5">
  <if_sid>100001</if_sid>
  <field name="mikrotik.full_message">login failure</field>
  <description>MikroTik: Login failure</description>
  <mitre>
    <id>T1110</id>
  </mitre>
</rule>
```

**Alert Generated:**
```json
{
  "rule": {
    "id": "100011",
    "level": 5,
    "description": "MikroTik: Login failure for user admin from 192.168.1.100",
    "mitre": {
      "id": ["T1110"],
      "tactic": ["Credential Access"],
      "technique": ["Brute Force"]
    }
  },
  "data": {
    "mikrotik": {
      "log_source": "mikrotik",
      "parsed": {
        "user": "admin",
        "src_ip": "192.168.1.100",
        "protocol": "ssh"
      }
    }
  }
}
```

### 3. Alert → Filebeat → Ingest Pipeline

**Filebeat** (built into Wazuh Manager) sends alert to Indexer.

**Ingest Pipeline Processing:**
```json
{
  "processors": [
    {
      "geoip": {
        "field": "data.mikrotik.parsed.src_ip",
        "target_field": "source_geo"
      }
    },
    {
      "set": {
        "field": "event.category",
        "value": "authentication"
      }
    },
    {
      "script": {
        "source": "ctx.risk_score = ctx.rule.level >= 12 ? 90 : ctx.rule.level >= 8 ? 70 : 50"
      }
    }
  ]
}
```

### 4. Final Document in Indexer

**Index:** `wazuh-alerts-4.x-2025.10.10`

```json
{
  "_index": "wazuh-alerts-4.x-2025.10.10",
  "_source": {
    "timestamp": "2025-10-10T21:00:00.000Z",
    "rule": {
      "id": "100011",
      "level": 5,
      "description": "MikroTik: Login failure for user admin from 192.168.1.100",
      "groups": ["mikrotik", "authentication"],
      "mitre": {
        "id": ["T1110"],
        "tactic": ["Credential Access"],
        "technique": ["Brute Force"]
      }
    },
    "data": {
      "mikrotik": {
        "log_source": "mikrotik",
        "vendor": "mikrotik",
        "hostname": "192.168.1.1",
        "parsed": {
          "user": "admin",
          "src_ip": "192.168.1.100",
          "protocol": "ssh"
        }
      }
    },
    "source_geo": {
      "country_name": "Latvia",
      "city_name": "Riga",
      "location": {
        "lat": 56.95,
        "lon": 24.1
      }
    },
    "event": {
      "category": "authentication",
      "type": "authentication",
      "severity": "medium"
    },
    "observer": {
      "vendor": "MikroTik",
      "product": "RouterOS",
      "hostname": "192.168.1.1"
    },
    "risk_score": 50
  }
}
```

## Implementation Steps

### Step 1: Deploy Fluentd Config

```bash
# Use smart routing config
cp wazuh-fluentd/config/conf.d/10-mikrotik-smart.conf.example \
   wazuh-fluentd/config/conf.d/10-mikrotik.conf

# Restart Fluentd
docker restart wazuh-fluentd
```

### Step 2: Deploy Wazuh Decoders & Rules

```bash
# Copy decoders
docker cp wazuh-manager/config/decoders/mikrotik-json-decoder.xml \
  wazuh-manager:/var/ossec/etc/decoders/

# Copy rules
docker cp wazuh-manager/config/rules/mikrotik-rules.xml \
  wazuh-manager:/var/ossec/etc/rules/

# Restart Wazuh Manager
docker exec wazuh-manager /var/ossec/bin/wazuh-control restart
```

### Step 3: Configure Filebeat Pipeline (in Wazuh Manager)

Edit `/var/ossec/etc/filebeat/filebeat.yml`:

```yaml
output.elasticsearch:
  hosts: ["wazuh-indexer:9200"]
  protocol: https
  username: admin
  password: ${INDEXER_PASSWORD}
  ssl.verification_mode: none
  
  # Add pipeline for MikroTik enrichment
  pipeline: "mikrotik-enrichment"
  
  # Or use conditional pipeline
  pipelines:
    - pipeline: "mikrotik-enrichment"
      when.contains:
        data.mikrotik.log_source: "mikrotik"
```

### Step 4: Deploy Enrichment Pipeline

```bash
# Create the enrichment pipeline
curl -k -X PUT \
  -u admin:password \
  "https://wazuh-indexer:9200/_ingest/pipeline/mikrotik-enrichment" \
  -H "Content-Type: application/json" \
  -d @wazuh-fluentd/config/pipelines/mikrotik-enrichment-pipeline.json
```

Or add to `setup_pipelines.sh`:

```bash
if create_pipeline "mikrotik-enrichment" "${PIPELINE_DIR}/mikrotik-enrichment-pipeline.json"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi
```

### Step 5: Test End-to-End

```bash
# Send test log
echo '<134>Oct 10 21:00:00 192.168.1.1 system,error login failure for user admin from 192.168.1.100 via ssh' | \
  nc -u -w1 fluentd-host 30514

# Wait 10 seconds, then check indices

# Check raw logs
curl -k -u admin:password \
  "https://wazuh-indexer:9200/anki-mikrotik-*/_search?size=1&pretty"

# Check alerts (with enrichment)
curl -k -u admin:password \
  "https://wazuh-indexer:9200/wazuh-alerts-*/_search?q=mikrotik&size=1&pretty"
```

## Benefits of This Architecture

### ✅ Layer 1 (Fluentd)
- **Fast parsing** at the edge
- **Smart routing** reduces duplication
- **Flexible** - easy to add new log sources
- **Buffering** - handles bursts

### ✅ Layer 2 (Wazuh Manager)
- **Security rules** - detect threats
- **MITRE ATT&CK** - automatic mapping
- **Compliance** - PCI-DSS, HIPAA tags
- **Active Response** - automated actions
- **Correlation** - multi-event detection

### ✅ Layer 3 (Ingest Pipeline)
- **GeoIP** - location data
- **ECS compliance** - standard fields
- **Risk scoring** - prioritization
- **Additional enrichment** - without restarting Wazuh

## Storage Breakdown

### Indices Created

| Index | Content | Size/Day | Retention |
|-------|---------|----------|-----------|
| `anki-mikrotik-*` | All raw logs | 500MB | 30 days |
| `wazuh-alerts-*` | Enriched alerts | 25MB | 90 days |

**Total Storage:** ~525MB/day
**Duplication:** Only 5% (security events)

## Query Examples

### Query Raw Logs

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

### Query Enriched Alerts

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
  },
  "aggs": {
    "by_country": {
      "terms": {
        "field": "source_geo.country_name"
      }
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

### Query High Risk Events

```json
GET wazuh-alerts-*/_search
{
  "query": {
    "range": { "risk_score": { "gte": 70 }}
  },
  "sort": [
    { "risk_score": "desc" }
  ]
}
```

## Dashboards

### Create Index Patterns

1. **Raw Logs:** `anki-mikrotik-*`
2. **Alerts:** `wazuh-alerts-*` (already exists)

### Visualizations

**Raw Logs Dashboard:**
- Top source IPs
- Event types over time
- Protocol distribution
- Failed vs successful logins

**Security Alerts Dashboard:**
- Alerts by severity
- MITRE ATT&CK heatmap
- Geographic distribution (GeoIP)
- Risk score trends
- Top triggered rules

**Example Visualization (Geographic Map):**
```json
{
  "title": "Login Failures by Country",
  "visState": {
    "type": "region_map",
    "params": {
      "field": "source_geo.country_name",
      "metric": {
        "type": "count"
      }
    }
  }
}
```

## Performance Optimization

### Fluentd
```ruby
<buffer>
  flush_interval 5s        # Adjust based on volume
  chunk_limit_size 8MB
  total_limit_size 1GB
  compress gzip            # Reduce network traffic
</buffer>
```

### Wazuh Manager
```xml
<global>
  <logall>no</logall>           <!-- Don't archive all logs -->
  <logall_json>no</logall_json>
</global>

<alerts>
  <log_alert_level>3</log_alert_level>  <!-- Only alert on level 3+ -->
</alerts>
```

### Ingest Pipeline
- Keep processors minimal
- Use `ignore_failure: true` for non-critical enrichments
- Test with `_simulate` before deploying

## Troubleshooting

### Logs Not Reaching Wazuh Manager

```bash
# Check Fluentd logs
docker logs wazuh-fluentd | grep -i error

# Check Wazuh Manager is listening
docker exec wazuh-manager netstat -tuln | grep 1514

# Test connectivity
docker exec wazuh-fluentd nc -zv wazuh-manager 1514
```

### Rules Not Matching

```bash
# Test decoder and rules
docker exec -it wazuh-manager /var/ossec/bin/wazuh-logtest

# Paste your JSON log
```

### Pipeline Not Enriching

```bash
# Test pipeline
curl -k -X POST \
  -u admin:password \
  "https://wazuh-indexer:9200/_ingest/pipeline/mikrotik-enrichment/_simulate?pretty" \
  -H "Content-Type: application/json" \
  -d '{
    "docs": [
      {
        "_source": {
          "data": {
            "mikrotik": {
              "parsed": {
                "src_ip": "8.8.8.8"
              }
            }
          },
          "rule": {
            "level": 8
          }
        }
      }
    ]
  }'

# Check if pipeline is applied
curl -k -u admin:password \
  "https://wazuh-indexer:9200/wazuh-alerts-*/_search?size=1&pretty" | \
  grep -A5 "source_geo"
```

## Summary

This architecture gives you:

✅ **Custom index names** (`anki-mikrotik-*`)
✅ **Wazuh rule engine** (security detection)
✅ **MITRE ATT&CK** (threat framework)
✅ **GeoIP enrichment** (location data)
✅ **ECS compliance** (standard fields)
✅ **Minimal duplication** (only 5%)
✅ **High performance** (distributed processing)
✅ **Flexible** (easy to extend)

**This is the final, production-ready architecture!** 🎉

## Files Reference

- **Fluentd Config:** `10-mikrotik-smart.conf.example`
- **Wazuh Decoder:** `mikrotik-json-decoder.xml`
- **Wazuh Rules:** `mikrotik-rules.xml`
- **Enrichment Pipeline:** `mikrotik-enrichment-pipeline.json`
- **Testing:** `test-rules.sh`, `README-TESTING.md`
- **Documentation:** This file + `ROUTING_STRATEGIES.md`
