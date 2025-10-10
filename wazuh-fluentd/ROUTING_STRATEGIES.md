# Log Routing Strategies Comparison

Complete comparison of different approaches to route logs with custom indices and Wazuh rules.

## The Problem

You want:
- ✅ Custom index names (`anki-mikrotik-*`)
- ✅ Wazuh rule engine (MITRE ATT&CK, compliance)
- ✅ Minimal duplication

## Solutions Comparison

### Strategy 1: Smart Fluentd Routing (Recommended)

**Config:** `10-mikrotik-smart.conf.example`

```
Fluentd filters:
├─ Security events → Wazuh Manager + Indexer
└─ Operational events → Indexer only
```

**Indices:**
- `anki-mikrotik-*` - ALL logs (100%)
- `wazuh-alerts-*` - Security alerts only (~5%)

**Pros:**
- ✅ Custom index name
- ✅ Wazuh rules work
- ✅ Minimal duplication (only 5% of logs)
- ✅ Simple to understand
- ✅ Efficient (filtering at source)

**Cons:**
- ⚠️ All logs in one index (mixed security + operational)

**Storage:**
```
anki-mikrotik-*:   500MB/day (all logs)
wazuh-alerts-*:    25MB/day  (security alerts)
Duplication:       25MB/day  (5%)
```

---

### Strategy 2: Pipeline-Based Routing

**Config:** `10-mikrotik-pipeline.conf.example`
**Pipeline:** `mikrotik-router-pipeline.json`

```
Fluentd filters:
├─ Security events → Wazuh Manager + Indexer (pipeline routes)
└─ Operational events → Indexer (pipeline routes)

Pipeline in Indexer:
├─ Security → anki-mikrotik-security-*
└─ Operational → anki-mikrotik-operational-*
```

**Indices:**
- `anki-mikrotik-security-*` - Security logs only (~5%)
- `anki-mikrotik-operational-*` - Operational logs (~95%)
- `wazuh-alerts-*` - Security alerts (~5%)

**Pros:**
- ✅ Custom index names
- ✅ Wazuh rules work
- ✅ Separated security/operational indices
- ✅ Better retention policies per type
- ✅ Minimal duplication (only 5%)

**Cons:**
- ⚠️ More complex (Fluentd + Pipeline)
- ⚠️ Two places to configure routing logic

**Storage:**
```
anki-mikrotik-security-*:     25MB/day  (security logs)
anki-mikrotik-operational-*:  475MB/day (operational logs)
wazuh-alerts-*:               25MB/day  (security alerts)
Duplication:                  25MB/day  (5%)
```

---

### Strategy 3: Full Hybrid (Not Recommended)

**Config:** `10-mikrotik-hybrid.conf.example`

```
Fluentd sends ALL logs to:
├─ Wazuh Manager
└─ Indexer
```

**Indices:**
- `anki-mikrotik-raw-*` - ALL logs (100%)
- `wazuh-alerts-*` - Alerts only (~5%)

**Pros:**
- ✅ Custom index name
- ✅ Wazuh rules work
- ✅ Simple config

**Cons:**
- ❌ 100% duplication of security events
- ❌ Wazuh Manager processes ALL logs (overhead)

**Storage:**
```
anki-mikrotik-raw-*:  500MB/day (all logs)
wazuh-alerts-*:       25MB/day  (alerts)
Duplication:          500MB/day (100%)
```

---

### Strategy 4: Manager Only

**Config:** `10-mikrotik-wazuh.conf.example`

```
Fluentd → Wazuh Manager only
```

**Indices:**
- `wazuh-alerts-*` - Alerts only (~5%)
- `wazuh-archives-*` - ALL logs (if enabled)

**Pros:**
- ✅ No duplication
- ✅ Wazuh rules work
- ✅ Simple config

**Cons:**
- ❌ No custom index name
- ❌ Archives use standard Wazuh naming

**Storage:**
```
wazuh-alerts-*:    25MB/day  (alerts)
wazuh-archives-*:  500MB/day (if enabled)
Duplication:       None
```

---

## Detailed Comparison Table

| Feature | Smart Routing | Pipeline Routing | Full Hybrid | Manager Only |
|---------|---------------|------------------|-------------|--------------|
| **Custom Index Name** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| **Wazuh Rules** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Separate Indices** | ❌ No | ✅ Yes | ❌ No | ❌ No |
| **Duplication** | 5% | 5% | 100% | 0% |
| **Complexity** | Low | Medium | Low | Low |
| **Config Files** | 1 | 2 | 1 | 1 |
| **Indexer Load** | Low | Low | High | Low |
| **Manager Load** | Low | Low | High | High |

## Recommendations by Use Case

### Small Environment (<10k logs/day)
**Use: Smart Routing** (`10-mikrotik-smart.conf.example`)
- Simple, efficient, minimal duplication
- One index is fine for this volume

### Medium Environment (10k-100k logs/day)
**Use: Pipeline Routing** (`10-mikrotik-pipeline.conf.example`)
- Separate indices for better management
- Different retention policies
- Better query performance

### Large Environment (>100k logs/day)
**Use: Pipeline Routing** + Consider:
- Separate Fluentd instances per log type
- Index sharding
- Hot/warm/cold architecture

### Compliance-Heavy Environment
**Use: Manager Only** + Archives
- Standard Wazuh indices
- Built-in compliance reporting
- Easier auditing

## Configuration Examples

### Smart Routing Setup

```bash
# 1. Copy config
cp wazuh-fluentd/config/conf.d/10-mikrotik-smart.conf.example \
   wazuh-fluentd/config/conf.d/10-mikrotik.conf

# 2. Deploy decoders/rules
docker cp wazuh-manager/config/decoders/* wazuh-manager:/var/ossec/etc/decoders/
docker cp wazuh-manager/config/rules/* wazuh-manager:/var/ossec/etc/rules/

# 3. Restart
docker restart wazuh-fluentd
docker exec wazuh-manager /var/ossec/bin/wazuh-control restart
```

### Pipeline Routing Setup

```bash
# 1. Copy config
cp wazuh-fluentd/config/conf.d/10-mikrotik-pipeline.conf.example \
   wazuh-fluentd/config/conf.d/10-mikrotik.conf

# 2. Deploy pipeline
cd wazuh-fluentd/config
./setup_pipelines.sh

# 3. Deploy decoders/rules
docker cp wazuh-manager/config/decoders/* wazuh-manager:/var/ossec/etc/decoders/
docker cp wazuh-manager/config/rules/* wazuh-manager:/var/ossec/etc/rules/

# 4. Restart
docker restart wazuh-fluentd
docker exec wazuh-manager /var/ossec/bin/wazuh-control restart
```

## Query Examples

### Smart Routing Queries

```json
// All logs
GET anki-mikrotik-*/_search

// Security alerts (from Wazuh)
GET wazuh-alerts-*/_search
{
  "query": {
    "match": { "data.mikrotik.log_source": "mikrotik" }
  }
}
```

### Pipeline Routing Queries

```json
// Security logs only
GET anki-mikrotik-security-*/_search

// Operational logs only
GET anki-mikrotik-operational-*/_search

// Security alerts (from Wazuh)
GET wazuh-alerts-*/_search
{
  "query": {
    "match": { "data.mikrotik.log_source": "mikrotik" }
  }
}
```

## Retention Policies

### Smart Routing

```json
// Single policy for all logs
PUT _ilm/policy/anki-mikrotik-policy
{
  "policy": {
    "phases": {
      "hot": { "actions": { "rollover": { "max_age": "1d" }}},
      "delete": { "min_age": "30d", "actions": { "delete": {}}}
    }
  }
}
```

### Pipeline Routing

```json
// Different policies per type

// Security: Keep 90 days
PUT _ilm/policy/anki-mikrotik-security-policy
{
  "policy": {
    "phases": {
      "hot": { "actions": { "rollover": { "max_age": "1d" }}},
      "delete": { "min_age": "90d", "actions": { "delete": {}}}
    }
  }
}

// Operational: Keep 30 days
PUT _ilm/policy/anki-mikrotik-operational-policy
{
  "policy": {
    "phases": {
      "hot": { "actions": { "rollover": { "max_age": "1d" }}},
      "delete": { "min_age": "30d", "actions": { "delete": {}}}
    }
  }
}
```

## Performance Impact

### Smart Routing
- **Fluentd CPU**: Low (simple regex filtering)
- **Indexer CPU**: Low (single index)
- **Manager CPU**: Low (only security events)
- **Network**: Minimal duplication

### Pipeline Routing
- **Fluentd CPU**: Low (simple regex filtering)
- **Indexer CPU**: Low (pipeline is fast)
- **Manager CPU**: Low (only security events)
- **Network**: Minimal duplication

### Full Hybrid
- **Fluentd CPU**: Low
- **Indexer CPU**: Medium (duplicate writes)
- **Manager CPU**: High (processes all logs)
- **Network**: High duplication

## My Recommendation

**For most use cases: Smart Routing** (`10-mikrotik-smart.conf.example`)

**Reasons:**
1. ✅ Simplest to understand and maintain
2. ✅ Minimal duplication (only 5%)
3. ✅ Custom index name
4. ✅ Wazuh rules work
5. ✅ One config file
6. ✅ Easy to troubleshoot

**Upgrade to Pipeline Routing if:**
- You need separate indices for security/operational
- You want different retention policies
- You have >50k logs/day
- You need better query performance

## Migration Path

Start with **Smart Routing**, migrate to **Pipeline Routing** later if needed:

```bash
# Step 1: Start with smart routing
cp 10-mikrotik-smart.conf.example 10-mikrotik.conf

# Step 2: Later, migrate to pipeline routing
cp 10-mikrotik-pipeline.conf.example 10-mikrotik.conf
./setup_pipelines.sh

# No changes needed to decoders/rules!
```

## Summary

| Strategy | Best For | Complexity | Duplication | Custom Index |
|----------|----------|------------|-------------|--------------|
| **Smart Routing** | Most users | ⭐ Low | 5% | ✅ Yes |
| **Pipeline Routing** | Large deployments | ⭐⭐ Medium | 5% | ✅ Yes |
| **Full Hybrid** | Not recommended | ⭐ Low | 100% | ✅ Yes |
| **Manager Only** | Compliance-focused | ⭐ Low | 0% | ❌ No |

**Winner: Smart Routing** for 90% of use cases! 🏆
