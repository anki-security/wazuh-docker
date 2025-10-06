# Fluentd Debugging Guide

## Current Status
- ✅ All 14 sources added
- ✅ workers=1 configured
- ✅ All matches configured
- ✅ Ports listening (verified with tcpdump)
- ❌ NO events being output (not even to catch-all)

## The Real Issue

Events are arriving at ports but **not being emitted by the input plugins**. This means the UDP/TCP plugins aren't creating events.

## Diagnosis Steps

### 1. Check if ANY events are being processed

```bash
# Watch for ANY output (should show events if they're being processed)
kubectl logs -n client1 fluentd-0 -f | grep -v "info\|warn\|error"

# Send test packet
echo "test message" | nc -u <fluentd-ip> 30514

# Should see output if working
```

### 2. Check Fluentd debug logs

```bash
# Enable debug logging
kubectl set env statefulset/fluentd -n client1 FLUENTD_LOG_LEVEL=debug

# Watch logs
kubectl logs -n client1 fluentd-0 -f | grep -E "received|emit|tag"
```

### 3. Test with simple config

Create a minimal test config to isolate the issue:

```ruby
<source>
  @type udp
  port 30514
  bind 0.0.0.0
  tag test.udp
  <parse>
    @type none
  </parse>
</source>

<match test.**>
  @type stdout
</match>
```

### 4. Check if it's a parsing issue

The `<parse> @type none</parse>` should pass raw data, but let's verify:

```bash
# Inside pod
kubectl exec -n client1 fluentd-0 -- sh -c 'echo "test" | nc -u localhost 30514'

# Check logs immediately
kubectl logs -n client1 fluentd-0 --tail=20
```

## Likely Root Causes

### 1. **UDP Buffer Size Issue**
The UDP plugin might be dropping packets due to buffer size.

**Fix**: Add to source config:
```ruby
<source>
  @type udp
  port 30514
  bind 0.0.0.0
  tag mikrotik.syslog
  message_length_limit 65536  # ← Add this
  <parse>
    @type none
  </parse>
</source>
```

### 2. **Parse Plugin Issue**
The `@type none` parser might not be working as expected.

**Fix**: Try without parse block:
```ruby
<source>
  @type udp
  port 30514
  bind 0.0.0.0
  tag mikrotik.syslog
  # Remove <parse> block entirely
</source>
```

### 3. **Tag Pattern Mismatch**
Tags might not match the patterns.

**Current tags**:
- `mikrotik.syslog` → matches `mikrotik.**` ✅
- `fortigate.cef.event` → matches `fortigate.cef.**` ✅
- `netflow.event` → matches `netflow.**` ✅

These should work...

### 4. **Worker Thread Issue (Most Likely)**

Even with `workers 1`, the sources might be in the supervisor, not the worker.

**Fix**: Wrap ALL sources in `<worker 0>` block:

```ruby
<worker 0>
  <source>
    @type udp
    port 30514
    bind 0.0.0.0
    tag mikrotik.syslog
    <parse>
      @type none
    </parse>
  </source>
</worker>
```

## Quick Test Script

Run this from your local machine:

```bash
#!/bin/bash
FLUENTD_IP="<your-fluentd-service-ip>"

# Test each port
echo "Testing MikroTik (30514)..."
echo "<14>$(date '+%b %d %H:%M:%S') test-host mikrotik test message" | nc -u $FLUENTD_IP 30514
sleep 2

echo "Testing Generic Syslog (30519)..."
echo "<14>$(date '+%b %d %H:%M:%S') test-host generic test message" | nc -u $FLUENTD_IP 30519
sleep 2

# Check logs
kubectl logs -n client1 fluentd-0 --tail=50 | grep -E "test message|test-host"
```

## Recommended Fix

Based on the symptoms, I believe the issue is **worker context**. Even with `workers 1`, sources might need explicit worker wrapper.

### Update ALL conf.d/*.conf files:

```bash
# Wrap each <source> block
<worker 0>
  <source>
    @type udp
    port 30514
    bind 0.0.0.0
    tag mikrotik.syslog
    <parse>
      @type none
    </parse>
  </source>
</worker>
```

### Or simpler: Remove parse block

The `<parse> @type none </parse>` might be causing issues. Try removing it:

```ruby
<source>
  @type udp
  port 30514
  bind 0.0.0.0
  tag mikrotik.syslog
  # No parse block - let Fluentd handle raw data
</source>
```

## Next Steps

1. **Enable debug logging**: `FLUENTD_LOG_LEVEL=debug`
2. **Send test packet**: `echo "test" | nc -u <ip> 30514`
3. **Check for "received" in logs**: Should see UDP receive messages
4. **If no "received"**: Sources aren't in worker (need `<worker 0>` wrapper)
5. **If "received" but no output**: Parse issue (remove `<parse>` block)

## Expected Debug Output

When working correctly, you should see:

```
[debug]: #0 received packet from 10.0.0.1:12345
[debug]: #0 emit tag="mikrotik.syslog" time=... record={...}
[debug]: #0 match pattern="mikrotik.**" matched
[debug]: #0 writing to opensearch...
```

If you only see "received" but no "emit", the parse plugin is failing.
