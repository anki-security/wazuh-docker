# Fluentd Configuration Notes - What Actually Worked

## Original Working Configuration (Before Migration)

### Docker Image
- **Image**: Custom Fluentd image with configs baked in
- **Base**: `fluent/fluentd:v1.19-debian-1`
- **Plugins Installed**:
  - fluent-plugin-opensearch (1.1.4)
  - fluent-plugin-netflowipfix
  - fluent-plugin-rewrite-tag-filter
  - fluent-plugin-record-modifier
  - fluent-plugin-grok-parser

### Port Configuration (Original - WORKING)
- **MikroTik**: 30514 UDP
- **Status**: ✅ Data flowing successfully

### Port Configuration (New - NOT WORKING)
- **MikroTik**: 40514 UDP  
- **Status**: ❌ Fluentd receives packets but doesn't emit events

### Worker Configuration

**Original (WORKING)**:
```yaml
<system>
  workers 7
</system>

<worker 3>
  <source>
    @type udp
    port 30514
    bind 0.0.0.0
    tag mikrotik.syslog
    <parse>
      @type regexp
      expression /^(?<message>.*)$/
    </parse>
    source_address_key source_ip
  </source>
</worker>
```

**Problem Discovered**: When we changed to port 40514 and restructured workers, the input plugins stopped emitting events even though packets were received (confirmed via tcpdump).

### MikroTik Source Configuration

**Parser Type**: `@type regexp` with pattern `/^(?<message>.*)$/`
- This passes the raw message through without parsing
- All parsing is done in OpenSearch via the mikrotik-routeros pipeline

**Key Fields**:
- `tag`: mikrotik.syslog
- `source_address_key`: source_ip (captures source IP from UDP packet)
- `bind`: 0.0.0.0 (listen on all interfaces)

### Filter Configuration

```yaml
<filter mikrotik.**>
  @type record_transformer
  enable_ruby true
  <record>
    log_source mikrotik
    vendor mikrotik
    product routeros
    hostname ${record["source_ip"] || "unknown"}
    @timestamp ${time.strftime('%Y-%m-%dT%H:%M:%S.%LZ')}
  </record>
</filter>
```

### Output Configuration

```yaml
<match mikrotik.**>
  @type opensearch
  host wazuh-indexer.client1.svc.cluster.local
  port 9200
  scheme https
  ssl_verify false
  user admin
  password <from-secret>
  index_name anki-mikrotik-%Y.%m.%d
  pipeline mikrotik-routeros  # ← OpenSearch pipeline does the parsing!
  
  <buffer tag, time>
    @type file
    path /fluentd/buffer/mikrotik
    timekey 60s
    flush_interval 10s
  </buffer>
</match>
```

## OpenSearch Pipeline (STILL WORKING)

The `mikrotik-routeros` pipeline in OpenSearch handles all the Grok parsing:
- Firewall logs
- DHCP logs
- DNS logs
- IPsec logs
- Login/logout events
- Network interface events

**Pipeline Name**: `mikrotik-routeros` (note: different from index name)
**Index Pattern**: `anki-mikrotik-*`

## What We Learned

### Issue #1: Multi-Worker Port Binding
When using `workers N`, sources inside `<worker X>` blocks sometimes don't bind properly or don't emit events. This is a known Fluentd limitation.

### Issue #2: Single-Worker Mode
Setting `workers 1` or removing workers entirely caused different issues - sources would bind but still not emit events.

### Issue #3: Port Changes
Changing from 30514 to 40514 seemed to trigger the event emission bug. The exact cause is unclear.

### Issue #4: UDP Input Plugin Reliability
Both Fluentd's `@type udp` and Vector's `syslog` source have issues with event emission in certain configurations.

## What Actually Worked

1. **Multi-worker mode with workers 7**
2. **Sources in specific worker blocks**
3. **Original port 30514**
4. **Custom Docker image with all configs baked in**
5. **Simple regexp parser that passes raw messages**
6. **OpenSearch pipeline for all parsing**

## Migration Attempts

### Attempt 1: Port Change (40514)
- Result: ❌ Failed - no events emitted
- Packets received: ✅ (confirmed via tcpdump)
- Port listening: ✅
- Events emitted: ❌

### Attempt 2: Remove Worker Blocks
- Result: ❌ Failed - sources didn't bind
- Only 2 out of 16 ports listening

### Attempt 3: Single Worker Mode
- Result: ❌ Failed - sources bound but no events
- All ports listening: ✅
- Events emitted: ❌

### Attempt 4: Vector Migration
- Result: ⏳ In Progress
- Vector running: ✅
- Ports listening: ✅
- Events emitted: ❌ (same issue!)

## Recommendations

### Option 1: Rollback to Working Config
- Use port 30514
- Use workers 7 with worker blocks
- Use original Docker image
- **Pros**: We know it works
- **Cons**: Doesn't solve the underlying issue

### Option 2: External Collector Approach
- Use goflow2 for NetFlow → JSON files
- Use rsyslog/syslog-ng for syslog → JSON files
- Vector/Fluentd tail the JSON files
- **Pros**: Proven reliable, separates concerns
- **Cons**: More components to manage

### Option 3: Different Tool
- Try Logstash (heavier but more reliable)
- Try Filebeat with modules
- Try Telegraf
- **Pros**: Battle-tested solutions
- **Cons**: Different learning curve

### Option 4: Debug Vector Further
- Enable Vector debug logging
- Test with socket source instead of syslog
- Try different Vector versions
- **Pros**: Modern tool, good for long-term
- **Cons**: Time investment, may hit same issues

## Files in This Folder

- `README.md` - Overview and rollback instructions
- `CONFIGURATION_NOTES.md` - This file - detailed technical notes
- `fluentd-statefulset-current.yml` - Current Fluentd StatefulSet (for reference)
- `mikrotik-pipeline.json` - OpenSearch pipeline (still in use)
- `fluentd-statefulset-changes.diff` - Git diff of changes made

## Important: What to Preserve

If starting fresh or migrating again:
1. ✅ Keep the OpenSearch pipelines - they work perfectly
2. ✅ Keep the index naming pattern (anki-mikrotik-YYYY.MM.DD)
3. ✅ Keep the simple parser approach (pass raw, parse in OpenSearch)
4. ⚠️  Test incrementally - one change at a time
5. ⚠️  Always verify with tcpdump AND event emission
6. ⚠️  Don't assume port listening = data flowing
