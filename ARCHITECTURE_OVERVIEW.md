# Architecture Overview - Complete Data Flow

## Table of Contents
1. [High-Level Architecture](#high-level-architecture)
2. [Component Details](#component-details)
3. [Data Flow](#data-flow)
4. [Storage Strategy](#storage-strategy)
5. [Configuration Files](#configuration-files)
6. [Deployment](#deployment)

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         LOG SOURCES                                 │
│  • Wazuh Agents (servers, endpoints)                               │
│  • MikroTik Routers (syslog → UDP 30514)                          │
│  • VMware ESXi Hosts (syslog → UDP 30527)                         │
│  • Generic Syslog Devices (syslog → UDP 514)                      │
└────────────┬────────────────────────────┬──────────────────────────┘
             │                            │
        Agents (1514)              Fluentd (30514, 30527, 514)
             │                            │
             ▼                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      PROCESSING LAYER                               │
│                                                                     │
│  ┌──────────────────────┐         ┌──────────────────────────┐    │
│  │   Wazuh Manager      │         │      Fluentd             │    │
│  │   (Port 1514)        │◄────────│   (Log Collector)        │    │
│  │                      │         │                          │    │
│  │  • Receives all logs │         │  • Parse syslog          │    │
│  │  • JSON Decoders     │         │  • Extract fields        │    │
│  │  • Security Rules    │         │  • Add metadata          │    │
│  │  • MITRE ATT&CK      │         │  • Tag: data_source=sensor│   │
│  │  • Generates Alerts  │         │  • Forward to Manager    │    │
│  │  • Archives logs     │         │  • Send to Indexer       │    │
│  └──────────┬───────────┘         └──────────────┬───────────┘    │
│             │                                    │                 │
│             ├─ alerts.json                       │                 │
│             └─ archives.json                     │                 │
│                      │                           │                 │
└──────────────────────┼───────────────────────────┼─────────────────┘
                       │                           │
                       ▼                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    FILEBEAT (Filtering)                             │
│                                                                     │
│  Reads:                                                             │
│  • /var/ossec/logs/alerts/alerts.json    → wazuh-alerts-*         │
│  • /var/ossec/logs/archives/archives.json → wazuh-archives-*       │
│                                                                     │
│  Processors (drop_event):                                          │
│  • IF data.data_source = "sensor" → DROP from archives            │
│  • IF data.log_source = "mikrotik" → DROP from archives           │
│  • IF data.log_source = "vmware-esxi" → DROP from archives        │
│                                                                     │
│  Result:                                                            │
│  • Alerts: ALL (agents + sensors)                                  │
│  • Archives: Agents ONLY (sensors filtered out)                    │
└──────────────────────┬──────────────────────────┬───────────────────┘
                       │                          │
                       ▼                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│              WAZUH INDEXER (OpenSearch)                             │
│                                                                     │
│  Indices:                                                           │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ wazuh-alerts-4.x-*        │ All security alerts              │  │
│  │                           │ Source: Filebeat                 │  │
│  │                           │ Contains: Agent + Sensor alerts  │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │ wazuh-archives-4.x-*      │ Agent logs only                  │  │
│  │                           │ Source: Filebeat (filtered)      │  │
│  │                           │ Contains: Agent logs             │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │ anki-mikrotik-*           │ All MikroTik logs                │  │
│  │                           │ Source: Fluentd (direct)         │  │
│  │                           │ Contains: Parsed syslog          │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │ anki-esxi-*               │ All ESXi logs                    │  │
│  │                           │ Source: Fluentd (direct)         │  │
│  │                           │ Contains: Parsed syslog          │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │ anki-syslog-*             │ Generic syslog                   │  │
│  │                           │ Source: Fluentd (direct)         │  │
│  │                           │ Contains: Parsed syslog          │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. Fluentd (Log Collector & Parser)

**Purpose:** Receive, parse, enrich, and route syslog from network devices

**Ports:**
- `514/UDP` - Generic syslog
- `30514/UDP` - MikroTik RouterOS
- `30527/UDP` - VMware ESXi

**Processing Pipeline:**

```ruby
# Example: MikroTik Log Processing
Source (UDP:30514)
  ↓
Parse (extract fields from syslog)
  ↓
Transform (add metadata)
  • log_source: mikrotik
  • vendor: mikrotik
  • product: routeros
  • data_source: sensor  ← KEY TAG for Filebeat filtering
  • timestamp: ISO8601
  • hostname: source IP
  ↓
Copy (dual destination)
  ├─→ Wazuh Manager (port 1514, JSON format)
  └─→ Indexer (anki-mikrotik-*, HTTPS)
```

**Key Features:**
- Parses vendor-specific syslog formats
- Extracts structured fields (user, src_ip, action, etc.)
- Adds enrichment metadata
- Buffers to disk for reliability
- Retries with exponential backoff

**Configuration Files:**
- `wazuh-fluentd/config/conf.d/10-mikrotik.conf`
- `wazuh-fluentd/config/conf.d/15-vmware-esxi.conf`
- `wazuh-fluentd/config/conf.d/99-generic-syslog.conf`

---

### 2. Wazuh Manager (Security Analysis Engine)

**Purpose:** Apply security rules, detect threats, generate alerts

**Receives From:**
- Wazuh Agents (port 1514) - Direct connection
- Fluentd (port 1514) - Forwarded sensor logs

**Processing Pipeline:**

```
Receive Log (JSON format)
  ↓
Decoder (extract fields)
  • JSON_Decoder plugin
  • Automatic field extraction
  • Dynamic field mapping
  ↓
Rules Engine
  • Match against 40+ custom rules
  • Check MITRE ATT&CK patterns
  • Frequency-based detection
  • Correlation rules
  ↓
Output
  ├─→ alerts.json (if rule matched)
  └─→ archives.json (all logs, if logall=yes)
```

**Decoders:**
- `wazuh-manager/config/decoders/mikrotik-json-decoder.xml`
- `wazuh-manager/config/decoders/esxi-json-decoder.xml`

**Rules:**
- `wazuh-manager/config/rules/mikrotik-rules.xml` (20+ rules)
- `wazuh-manager/config/rules/esxi-rules.xml` (20+ rules)

**Key Configuration:**
```xml
<ossec_config>
  <global>
    <logall>yes</logall>              <!-- Archive ALL logs -->
    <logall_json>yes</logall_json>    <!-- JSON format -->
  </global>
</ossec_config>
```

---

### 3. Filebeat (Log Shipper with Filtering)

**Purpose:** Ship Wazuh logs to Indexer with selective filtering

**Reads:**
- `/var/ossec/logs/alerts/alerts.json`
- `/var/ossec/logs/archives/archives.json`

**Filtering Logic:**

```yaml
processors:
  - drop_event:
      when:
        or:
          - equals:
              data.data_source: "sensor"      # Drop Fluentd logs
          - contains:
              data.log_source: "mikrotik"     # Drop MikroTik
          - contains:
              data.log_source: "vmware-esxi"  # Drop ESXi
```

**Why Filter?**
- Sensor logs already stored in `anki-*` indices (via Fluentd)
- Prevents duplication
- Keeps `wazuh-archives-*` for agent logs only

**Configuration:**
- `wazuh-manager/config/filebeat-config.yml`

---

### 4. Wazuh Indexer (OpenSearch)

**Purpose:** Store, search, and analyze all logs

**Index Strategy:**

| Index Pattern | Content | Source | Retention | Size (est.) |
|---------------|---------|--------|-----------|-------------|
| `wazuh-alerts-4.x-*` | Security alerts from all sources | Filebeat | 90 days | 10MB/day |
| `wazuh-archives-4.x-*` | Agent logs only (no sensors) | Filebeat | 30 days | 25MB/day |
| `anki-mikrotik-*` | All MikroTik logs | Fluentd | 60 days | 50MB/day |
| `anki-esxi-*` | All ESXi logs | Fluentd | 60 days | 50MB/day |
| `anki-syslog-*` | Generic syslog | Fluentd | 30 days | 50MB/day |

**Ingest Pipelines:**
- `mikrotik-enrichment-pipeline` - GeoIP, risk scoring
- `esxi-enrichment-pipeline` - GeoIP, risk scoring

---

## Data Flow

### Scenario 1: Wazuh Agent Log

```
Agent → Wazuh Manager (1514)
  ↓
  Decoder: agent-json
  Rules: Check security patterns
  ↓
  ├─→ alerts.json (if matched)
  └─→ archives.json (all logs)
  ↓
Filebeat reads both files
  ↓
  Processors: NO FILTER (no data_source tag)
  ↓
  ├─→ wazuh-alerts-* (if alert)
  └─→ wazuh-archives-* (all agent logs) ✅
```

**Result:** Agent logs in `wazuh-archives-*` ✅

---

### Scenario 2: MikroTik Log

```
MikroTik Router → Fluentd (30514/UDP)
  ↓
  Parse syslog
  Extract: user, src_ip, action
  Add: data_source=sensor, log_source=mikrotik
  ↓
  Copy to TWO destinations:
  
  Path 1: Wazuh Manager (1514)
    ↓
    Decoder: mikrotik-json
    Rules: Check for attacks, policy violations
    ↓
    ├─→ alerts.json (if matched)
    └─→ archives.json (all logs)
    ↓
    Filebeat reads both files
    ↓
    Processors: DROP (data_source=sensor) ❌
    ↓
    └─→ wazuh-alerts-* (alerts only) ✅
  
  Path 2: Indexer (direct)
    ↓
    └─→ anki-mikrotik-* (all logs) ✅
```

**Result:** 
- MikroTik logs in `anki-mikrotik-*` ✅
- Security alerts in `wazuh-alerts-*` ✅
- NOT in `wazuh-archives-*` (filtered) ✅

---

### Scenario 3: ESXi Log

```
ESXi Host → Fluentd (30527/UDP)
  ↓
  Parse syslog
  Extract: vm, user, srcip, action
  Add: data_source=sensor, log_source=vmware-esxi
  ↓
  Copy to TWO destinations:
  
  Path 1: Wazuh Manager (1514)
    ↓
    Decoder: esxi-json
    Rules: Check for VM operations, SSH attacks
    ↓
    ├─→ alerts.json (if matched)
    └─→ archives.json (all logs)
    ↓
    Filebeat reads both files
    ↓
    Processors: DROP (data_source=sensor) ❌
    ↓
    └─→ wazuh-alerts-* (alerts only) ✅
  
  Path 2: Indexer (direct)
    ↓
    └─→ anki-esxi-* (all logs) ✅
```

**Result:**
- ESXi logs in `anki-esxi-*` ✅
- Security alerts in `wazuh-alerts-*` ✅
- NOT in `wazuh-archives-*` (filtered) ✅

---

## Storage Strategy

### No Duplication

**Problem Solved:**
- Before: Sensor logs stored in BOTH `anki-*` AND `wazuh-archives-*`
- After: Sensor logs ONLY in `anki-*`, agents ONLY in `wazuh-archives-*`

**How:**
- Fluentd adds `data_source: sensor` tag
- Filebeat filters out sensor logs from archives
- Result: Each log stored once (except alerts)

### Storage Breakdown (100k logs/day)

```
Index                    | Logs/Day | Size/Day | Purpose
-------------------------|----------|----------|---------------------------
anki-mikrotik-*          | 40k      | 50MB     | MikroTik operations
anki-esxi-*              | 30k      | 50MB     | ESXi operations
anki-syslog-*            | 10k      | 50MB     | Generic devices
wazuh-archives-*         | 20k      | 25MB     | Agent logs (no sensors)
wazuh-alerts-*           | 5k       | 10MB     | Security alerts (all)
-------------------------|----------|----------|---------------------------
TOTAL                    | 105k     | 185MB    | No duplication!
```

### Index Lifecycle Management

**Recommended Policies:**

```json
{
  "wazuh-alerts-*": {
    "hot": "7 days",
    "warm": "30 days",
    "cold": "60 days",
    "delete": "90 days"
  },
  "wazuh-archives-*": {
    "hot": "3 days",
    "warm": "7 days",
    "delete": "30 days"
  },
  "anki-mikrotik-*": {
    "hot": "7 days",
    "warm": "30 days",
    "delete": "60 days"
  },
  "anki-esxi-*": {
    "hot": "7 days",
    "warm": "30 days",
    "delete": "60 days"
  }
}
```

---

## Configuration Files

### Fluentd Configuration

**Location:** `wazuh-fluentd/config/conf.d/`

**10-mikrotik.conf:**
```ruby
<source>
  @type udp
  port 30514
  tag mikrotik.syslog
</source>

<filter mikrotik.**>
  @type record_transformer
  <record>
    log_source mikrotik
    data_source sensor        # ← KEY TAG
    # ... other fields
  </record>
</filter>

<match mikrotik.**>
  @type copy
  
  # To Wazuh Manager
  <store>
    @type forward
    host wazuh-manager
    port 1514
  </store>
  
  # To Indexer
  <store>
    @type opensearch
    index_name anki-mikrotik-%Y.%m.%d
  </store>
</match>
```

### Wazuh Manager Configuration

**Decoders:** `wazuh-manager/config/decoders/mikrotik-json-decoder.xml`
```xml
<decoder name="mikrotik-json">
  <plugin_decoder>JSON_Decoder</plugin_decoder>
</decoder>
```

**Rules:** `wazuh-manager/config/rules/mikrotik-rules.xml`
```xml
<rule id="100001" level="0">
  <decoded_as>mikrotik-json</decoded_as>
  <description>MikroTik log</description>
</rule>

<rule id="100010" level="5">
  <if_sid>100001</if_sid>
  <field name="full_message">login failure</field>
  <description>MikroTik: Login failure</description>
  <mitre>
    <id>T1110</id>
  </mitre>
</rule>
```

**Global Config:** Add to `ossec.conf`
```xml
<global>
  <logall>yes</logall>
  <logall_json>yes</logall_json>
</global>
```

### Filebeat Configuration

**Location:** `wazuh-manager/config/filebeat-config.yml`

```yaml
filebeat.modules:
  - module: wazuh
    alerts:
      enabled: true
    archives:
      enabled: true
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
```

---

## Deployment

### 1. Deploy Wazuh Stack

```bash
# Clone repository
git clone https://github.com/anki-security/wazuh-docker.git
cd wazuh-docker

# Generate certificates
docker compose -f generate-indexer-certs.yml run --rm generator

# Start Wazuh stack
docker compose up -d
```

### 2. Deploy Fluentd

```bash
cd wazuh-fluentd

# Copy example config
cp docker-compose.example.yml docker-compose.yml

# Edit environment variables
nano docker-compose.yml
# Set:
# - INDEXER_HOST=wazuh-indexer
# - INDEXER_USERNAME=admin
# - INDEXER_PASSWORD=SecretPassword
# - WAZUH_MANAGER_HOST=wazuh-manager
# - WAZUH_MANAGER_PORT=1514

# Start Fluentd
docker compose up -d
```

### 3. Configure Wazuh Manager

```bash
# Copy decoders
docker cp wazuh-manager/config/decoders/*.xml wazuh-manager:/var/ossec/etc/decoders/

# Copy rules
docker cp wazuh-manager/config/rules/*.xml wazuh-manager:/var/ossec/etc/rules/

# Enable logall in ossec.conf
docker exec wazuh-manager vi /var/ossec/etc/ossec.conf
# Add:
# <global>
#   <logall>yes</logall>
#   <logall_json>yes</logall_json>
# </global>

# Restart Wazuh Manager
docker exec wazuh-manager /var/ossec/bin/wazuh-control restart
```

### 4. Configure Filebeat

```bash
# Update Filebeat config
docker exec wazuh-manager vi /etc/filebeat/filebeat.yml
# Add processors to archives section (see filebeat-config.yml)

# Restart Filebeat
docker exec wazuh-manager systemctl restart filebeat
```

### 5. Configure Devices

**MikroTik:**
```
/system logging action
add name=remote-fluentd remote=<FLUENTD_IP> remote-port=30514 target=remote

/system logging
add action=remote-fluentd topics=system,error,warning,info
```

**ESXi:**
```
esxcli system syslog config set --loghost=udp://<FLUENTD_IP>:30527
esxcli system syslog reload
```

---

## Verification

### 1. Check Fluentd

```bash
# View Fluentd logs
docker logs -f wazuh-fluentd

# Should see:
# "fluent.info: starting fluentd worker"
# "listening port port=30514"
# "listening port port=30527"
```

### 2. Check Wazuh Manager

```bash
# Test decoder
docker exec wazuh-manager /var/ossec/bin/wazuh-logtest
# Paste test log, should see decoder match

# View alerts
docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.json
```

### 3. Check Indices

```bash
# List indices
curl -k -u admin:password \
  "https://wazuh-indexer:9200/_cat/indices/anki-*,wazuh-*?v"

# Search MikroTik logs
curl -k -u admin:password \
  "https://wazuh-indexer:9200/anki-mikrotik-*/_search?size=1&pretty"

# Verify NO sensor logs in archives
curl -k -u admin:password \
  "https://wazuh-indexer:9200/wazuh-archives-*/_search?q=data_source:sensor&pretty"
# Should return 0 results!
```

### 4. Send Test Logs

```bash
# Test MikroTik
echo '<134>Oct 10 21:00:00 192.168.1.1 system,error login failure for user admin from 192.168.1.100 via ssh' | \
  nc -u <FLUENTD_IP> 30514

# Wait 15 seconds, then check:
# - anki-mikrotik-* (should have log)
# - wazuh-alerts-* (should have alert if rule matched)
# - wazuh-archives-* (should NOT have log)
```

---

## Troubleshooting

### Fluentd not receiving logs

```bash
# Check Fluentd is listening
docker exec wazuh-fluentd netstat -uln | grep -E "30514|30527|514"

# Check firewall
sudo ufw status
sudo ufw allow 30514/udp
sudo ufw allow 30527/udp

# Test connectivity
nc -u <FLUENTD_IP> 30514 < test.log
```

### Logs not in Indexer

```bash
# Check Fluentd buffer
docker exec wazuh-fluentd ls -lh /fluentd/buffer/

# Check Fluentd errors
docker logs wazuh-fluentd | grep -i error

# Check Indexer connectivity
docker exec wazuh-fluentd curl -k https://wazuh-indexer:9200
```

### Rules not matching

```bash
# Test locally
cd wazuh-manager
./test-rules.sh quick

# Check decoder
docker exec wazuh-manager /var/ossec/bin/wazuh-logtest
# Paste JSON log, verify decoder extracts fields

# Check rule syntax
docker exec wazuh-manager /var/ossec/bin/wazuh-logtest -t
```

### Sensor logs in archives

```bash
# Check Filebeat processors
docker exec wazuh-manager cat /etc/filebeat/filebeat.yml | grep -A10 processors

# Check Filebeat logs
docker exec wazuh-manager tail -f /var/log/filebeat/filebeat

# Verify data_source tag
docker exec wazuh-manager tail /var/ossec/logs/archives/archives.json | jq '.data.data_source'
```

---

## Summary

### Architecture Benefits

✅ **No Duplication**
- Sensor logs: `anki-*` only
- Agent logs: `wazuh-archives-*` only
- Alerts: `wazuh-alerts-*` (all sources)

✅ **Centralized Security**
- All logs analyzed by Wazuh Manager
- Consistent rule engine
- MITRE ATT&CK mappings

✅ **Flexible Storage**
- Device-specific indices for operations
- Separate retention policies
- Efficient searching

✅ **Easy Maintenance**
- Add rules without Fluentd changes
- Test rules locally
- Version-controlled configs

✅ **Production Ready**
- Disk buffering
- Automatic retries
- Health monitoring
- Scalable architecture

### Key Files

```
wazuh-docker/
├── VERSION.json                          # Versions (custom + Wazuh)
├── wazuh-fluentd/
│   ├── config/conf.d/
│   │   ├── 10-mikrotik.conf             # MikroTik parser
│   │   ├── 15-vmware-esxi.conf          # ESXi parser
│   │   └── 99-generic-syslog.conf       # Generic syslog
│   └── docker-compose.example.yml        # Fluentd deployment
├── wazuh-manager/
│   ├── config/
│   │   ├── decoders/
│   │   │   ├── mikrotik-json-decoder.xml
│   │   │   └── esxi-json-decoder.xml
│   │   ├── rules/
│   │   │   ├── mikrotik-rules.xml       # 20+ rules
│   │   │   └── esxi-rules.xml           # 20+ rules
│   │   └── filebeat-config.yml          # Filtering config
│   └── test-rules.sh                     # Local testing
└── ARCHITECTURE_OVERVIEW.md              # This file
```

**Your logs are now flowing efficiently with no duplication!** 🎉
