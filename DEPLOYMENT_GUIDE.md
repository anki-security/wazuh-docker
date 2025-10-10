# Production Deployment Guide

Complete step-by-step guide to deploy the final architecture.

## What Will Be Deployed

### Log Sources
1. **MikroTik RouterOS** (Port 30514 UDP)
2. **VMware ESXi** (Port 30527 UDP)
3. **Generic Syslog** (Port 514 UDP)

### Architecture
```
Logs → Fluentd (parse) → Smart Routing:
                          ├─ Security → Wazuh Manager → wazuh-alerts-*
                          └─ All logs → Indexer → anki-{source}-*
```

### Indices Created
- `anki-mikrotik-*` - All MikroTik logs
- `anki-esxi-*` - All ESXi logs  
- `anki-syslog-*` - Generic syslog
- `wazuh-alerts-*` - Security alerts (enriched)

## Pre-Deployment Checklist

- [ ] Docker and Docker Compose installed
- [ ] Wazuh stack running (Manager, Indexer, Dashboard)
- [ ] Network ports available (30514, 30527, 514)
- [ ] Sufficient storage (estimate: 1GB/day per 100k logs)

## Step 1: Verify Fluentd Configurations

### 1.1 Check Active Configs

```bash
cd /Users/rolandsbirons/Development/anki-wazuh-docker/wazuh-fluentd/config/conf.d

# List active configs
ls -la *.conf

# Should show:
# 10-mikrotik.conf       - MikroTik RouterOS (Smart routing)
# 15-vmware-esxi.conf    - VMware ESXi (Smart routing)
# 99-generic-syslog.conf - Generic syslog handler
```

**Note:** All configs are production-ready and will be loaded by Fluentd on startup.

### 1.2 Verify Configurations

```bash
# Check syntax
docker run --rm -v "$(pwd)/conf.d:/fluentd/etc/conf.d" \
  fluent/fluentd:latest fluentd --dry-run -c /fluentd/etc/fluent.conf
```

### 1.3 Restart Fluentd

```bash
cd /Users/rolandsbirons/Development/anki-wazuh-docker
docker-compose restart wazuh-fluentd

# Check logs
docker logs -f wazuh-fluentd
```

## Step 2: Deploy Wazuh Decoders

### 2.1 Copy Decoders to Wazuh Manager

```bash
cd /Users/rolandsbirons/Development/anki-wazuh-docker

# MikroTik decoder
docker cp wazuh-manager/config/decoders/mikrotik-json-decoder.xml \
  wazuh-manager:/var/ossec/etc/decoders/

# ESXi decoder
docker cp wazuh-manager/config/decoders/esxi-json-decoder.xml \
  wazuh-manager:/var/ossec/etc/decoders/
```

### 2.2 Verify Decoders

```bash
# Check decoder files
docker exec wazuh-manager ls -la /var/ossec/etc/decoders/ | grep -E "(mikrotik|esxi)"

# Test decoder syntax
docker exec wazuh-manager /var/ossec/bin/wazuh-logtest -t
```

## Step 3: Deploy Wazuh Rules

### 3.1 Copy Rules to Wazuh Manager

```bash
# MikroTik rules
docker cp wazuh-manager/config/rules/mikrotik-rules.xml \
  wazuh-manager:/var/ossec/etc/rules/

# ESXi rules
docker cp wazuh-manager/config/rules/esxi-rules.xml \
  wazuh-manager:/var/ossec/etc/rules/
```

### 3.2 Verify Rules

```bash
# Check rule files
docker exec wazuh-manager ls -la /var/ossec/etc/rules/ | grep -E "(mikrotik|esxi)"
```

### 3.3 Restart Wazuh Manager

```bash
docker exec wazuh-manager /var/ossec/bin/wazuh-control restart

# Wait for restart (30 seconds)
sleep 30

# Check status
docker exec wazuh-manager /var/ossec/bin/wazuh-control status
```

## Step 4: Deploy Enrichment Pipelines

### 4.1 Run Pipeline Setup Script

```bash
cd /Users/rolandsbirons/Development/anki-wazuh-docker/wazuh-fluentd/config

# Make executable
chmod +x setup_pipelines.sh

# Run setup
./setup_pipelines.sh
```

Expected output:
```
🔍 Validating decoder and rule syntax...
✅ Syntax validation passed

📋 Creating pipeline: mikrotik-enrichment
✅ Pipeline created: mikrotik-enrichment

📋 Creating pipeline: esxi-enrichment
✅ Pipeline created: esxi-enrichment

✅ Successfully created 2 pipelines
```

### 4.2 Verify Pipelines

```bash
# List all pipelines
curl -k -u admin:SecretPassword \
  "https://wazuh-indexer:9200/_ingest/pipeline?pretty" | \
  grep -E "(mikrotik|esxi)"

# Test MikroTik pipeline
curl -k -X POST \
  -u admin:SecretPassword \
  "https://wazuh-indexer:9200/_ingest/pipeline/mikrotik-enrichment/_simulate?pretty" \
  -H "Content-Type: application/json" \
  -d '{
    "docs": [{
      "_source": {
        "data": {
          "mikrotik": {
            "parsed": { "src_ip": "8.8.8.8" }
          }
        },
        "rule": { "level": 8 }
      }
    }]
  }'
```

## Step 5: Configure Filebeat (Optional)

To apply enrichment pipelines to Wazuh alerts, configure Filebeat in Wazuh Manager.

### 5.1 Edit Filebeat Config

```bash
docker exec -it wazuh-manager vi /etc/filebeat/filebeat.yml
```

Add pipeline configuration:

```yaml
output.elasticsearch:
  hosts: ["wazuh-indexer:9200"]
  protocol: https
  username: admin
  password: ${INDEXER_PASSWORD}
  ssl.verification_mode: none
  
  # Apply pipelines conditionally
  pipelines:
    - pipeline: "mikrotik-enrichment"
      when.contains:
        data.mikrotik.log_source: "mikrotik"
    
    - pipeline: "esxi-enrichment"
      when.contains:
        data.esxi.log_source: "vmware-esxi"
```

### 5.2 Restart Filebeat

```bash
docker exec wazuh-manager systemctl restart filebeat

# Check status
docker exec wazuh-manager systemctl status filebeat
```

## Step 6: Test End-to-End

### 6.1 Send Test Logs

**MikroTik Test:**
```bash
echo '<134>Oct 10 21:00:00 192.168.1.1 system,error login failure for user admin from 192.168.1.100 via ssh' | \
  nc -u -w1 localhost 30514
```

**ESXi Test:**
```bash
echo '<134>Oct 10 21:00:00 192.168.1.10 Hostd: SSH login has failed for '\''root@10.0.0.50'\''' | \
  nc -u -w1 localhost 30527
```

### 6.2 Verify Logs in Indices

Wait 10-15 seconds, then check:

**Check Raw Logs:**
```bash
# MikroTik
curl -k -u admin:SecretPassword \
  "https://wazuh-indexer:9200/anki-mikrotik-*/_search?size=1&pretty"

# ESXi
curl -k -u admin:SecretPassword \
  "https://wazuh-indexer:9200/anki-esxi-*/_search?size=1&pretty"
```

**Check Alerts:**
```bash
# MikroTik alerts
curl -k -u admin:SecretPassword \
  "https://wazuh-indexer:9200/wazuh-alerts-*/_search?q=mikrotik&size=1&pretty"

# ESXi alerts
curl -k -u admin:SecretPassword \
  "https://wazuh-indexer:9200/wazuh-alerts-*/_search?q=esxi&size=1&pretty"
```

### 6.3 Verify Enrichment

Check if GeoIP and risk scores are present:

```bash
curl -k -u admin:SecretPassword \
  "https://wazuh-indexer:9200/wazuh-alerts-*/_search?size=1&pretty" | \
  grep -A10 "source_geo\|risk_score\|event.severity"
```

## Step 7: Configure Log Sources

### 7.1 MikroTik RouterOS

```
/system logging action
add name=fluentd target=remote remote=<FLUENTD_IP> remote-port=30514 src-address=<MIKROTIK_IP>

/system logging
add action=fluentd topics=system,error,warning,info
add action=fluentd topics=firewall
add action=fluentd topics=account
```

### 7.2 VMware ESXi

**Via vSphere Client:**
1. Select ESXi host
2. Configure → System → Advanced Settings
3. Search for `Syslog.global.logHost`
4. Set value: `udp://<FLUENTD_IP>:30527`
5. Restart syslog: `esxcli system syslog reload`

**Via SSH:**
```bash
esxcli system syslog config set --loghost='udp://<FLUENTD_IP>:30527'
esxcli system syslog reload
```

### 7.3 Generic Syslog Devices

Configure devices to send syslog to:
- **Host:** `<FLUENTD_IP>`
- **Port:** `514` (UDP)
- **Protocol:** Syslog (RFC3164 or RFC5424)

## Step 8: Create Dashboards

### 8.1 Create Index Patterns

In Wazuh Dashboard:

1. **Stack Management → Index Patterns**
2. Create patterns:
   - `anki-mikrotik-*` (time field: `timestamp`)
   - `anki-esxi-*` (time field: `timestamp`)
   - `anki-syslog-*` (time field: `timestamp`)
   - `wazuh-alerts-*` (already exists)

### 8.2 Import Visualizations

Create visualizations for:
- Top source IPs
- Event types over time
- Geographic distribution (using GeoIP)
- MITRE ATT&CK heatmap
- Risk score trends

## Verification Checklist

After deployment, verify:

- [ ] Fluentd receiving logs (check `docker logs wazuh-fluentd`)
- [ ] Raw logs in `anki-*` indices
- [ ] Alerts in `wazuh-alerts-*` index
- [ ] Wazuh rules matching (check rule IDs in alerts)
- [ ] GeoIP data present in alerts
- [ ] Risk scores calculated
- [ ] Event categories set
- [ ] No errors in Wazuh Manager logs
- [ ] No errors in Fluentd logs

## Monitoring

### Check Fluentd Status

```bash
# View logs
docker logs -f --tail=100 wazuh-fluentd

# Check buffer usage
docker exec wazuh-fluentd ls -lh /fluentd/buffer/

# Check failed records
docker exec wazuh-fluentd ls -lh /fluentd/failed_records/
```

### Check Wazuh Manager Status

```bash
# Check status
docker exec wazuh-manager /var/ossec/bin/wazuh-control status

# View logs
docker exec wazuh-manager tail -f /var/ossec/logs/ossec.log

# Check alerts
docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.log
```

### Check Index Health

```bash
# List indices
curl -k -u admin:SecretPassword \
  "https://wazuh-indexer:9200/_cat/indices/anki-*,wazuh-alerts-*?v"

# Check index stats
curl -k -u admin:SecretPassword \
  "https://wazuh-indexer:9200/_cat/indices/anki-*?v&h=index,docs.count,store.size&s=index"
```

## Troubleshooting

### Logs Not Appearing in Raw Indices

1. Check Fluentd logs: `docker logs wazuh-fluentd | grep -i error`
2. Verify network connectivity: `nc -zv wazuh-indexer 9200`
3. Check Indexer credentials in `.env` file
4. Test manual log send: `echo '<134>test' | nc -u localhost 30514`

### Alerts Not Generated

1. Test decoders: `docker exec -it wazuh-manager /var/ossec/bin/wazuh-logtest`
2. Check rule files: `docker exec wazuh-manager ls -la /var/ossec/etc/rules/`
3. View Wazuh logs: `docker exec wazuh-manager tail -f /var/ossec/logs/ossec.log`
4. Verify Manager is receiving logs: `docker exec wazuh-manager netstat -tuln | grep 1514`

### Enrichment Not Working

1. Verify pipelines exist: `curl -k -u admin:SecretPassword "https://wazuh-indexer:9200/_ingest/pipeline?pretty"`
2. Test pipeline: Use `_simulate` endpoint (see Step 4.2)
3. Check Filebeat config: `docker exec wazuh-manager cat /etc/filebeat/filebeat.yml`
4. Restart Filebeat: `docker exec wazuh-manager systemctl restart filebeat`

## Rollback Procedure

If issues occur:

```bash
# Stop Fluentd
docker-compose stop wazuh-fluentd

# Remove custom configs
cd wazuh-fluentd/config/conf.d
mv 10-mikrotik.conf 10-mikrotik.conf.backup
mv 15-vmware-esxi.conf 15-vmware-esxi.conf.backup

# Restart
docker-compose start wazuh-fluentd
```

## Performance Tuning

### For High Volume (>100k logs/day)

**Fluentd:**
```ruby
<buffer>
  flush_interval 30s      # Increase batch size
  chunk_limit_size 16MB   # Larger chunks
  total_limit_size 2GB    # More buffer space
</buffer>
```

**Wazuh Manager:**
```xml
<global>
  <logall_json>no</logall_json>  <!-- Disable archives -->
</global>
```

**Indexer:**
- Increase heap size
- Add more shards for high-volume indices
- Enable ILM for automatic retention

## Next Steps

1. ✅ Set up alerting (OpenSearch Alerting or Wazuh notifications)
2. ✅ Configure retention policies (ILM)
3. ✅ Create custom dashboards
4. ✅ Set up backups
5. ✅ Document custom rules
6. ✅ Train team on dashboard usage

## Support Files

- **Testing:** `wazuh-manager/test-rules.sh`
- **Test Logs:** `wazuh-manager/test-logs/`
- **Architecture:** `FINAL_ARCHITECTURE.md`
- **Routing Guide:** `wazuh-fluentd/ROUTING_STRATEGIES.md`

## Success Criteria

Deployment is successful when:

✅ Logs flowing from sources to Fluentd
✅ Raw logs visible in `anki-*` indices
✅ Security alerts in `wazuh-alerts-*`
✅ Rules matching correctly (check rule IDs)
✅ GeoIP enrichment working
✅ Risk scores calculated
✅ No errors in logs
✅ Dashboards showing data

**You're ready for production!** 🎉
