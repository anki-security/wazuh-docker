# Quick Start Guide

Get up and running in 5 minutes.

## Prerequisites

- ✅ Docker & Docker Compose running
- ✅ Wazuh stack deployed (Manager, Indexer, Dashboard)
- ✅ Ports available: 514, 30514, 30527

## 5-Minute Deployment

### Step 1: Verify Fluentd Configs (10 seconds)

```bash
cd wazuh-fluentd/config/conf.d

# Check configs are present
ls -la *.conf

# Should show:
# 10-mikrotik.conf       ✅
# 15-vmware-esxi.conf    ✅
# 99-generic-syslog.conf ✅
```

**Note:** All configs are production-ready and active.

### Step 2: Deploy Wazuh Decoders & Rules (1 minute)

```bash
cd ../../

# Deploy decoders
docker cp wazuh-manager/config/decoders/mikrotik-json-decoder.xml \
  wazuh-manager:/var/ossec/etc/decoders/

docker cp wazuh-manager/config/decoders/esxi-json-decoder.xml \
  wazuh-manager:/var/ossec/etc/decoders/

# Deploy rules
docker cp wazuh-manager/config/rules/mikrotik-rules.xml \
  wazuh-manager:/var/ossec/etc/rules/

docker cp wazuh-manager/config/rules/esxi-rules.xml \
  wazuh-manager:/var/ossec/etc/rules/

# Restart Wazuh Manager
docker exec wazuh-manager /var/ossec/bin/wazuh-control restart
```

### Step 3: Deploy Enrichment Pipelines (1 minute)

```bash
cd wazuh-fluentd/config
./setup_pipelines.sh
```

Expected output:
```
✅ Pipeline created: mikrotik-enrichment
✅ Pipeline created: esxi-enrichment
```

### Step 4: Restart Fluentd (30 seconds)

```bash
cd ../../
docker-compose restart wazuh-fluentd

# Wait 10 seconds
sleep 10

# Check logs
docker logs --tail=20 wazuh-fluentd
```

### Step 5: Test (2 minutes)

**Send test logs:**

```bash
# MikroTik test
echo '<134>Oct 10 21:00:00 192.168.1.1 system,error login failure for user admin from 192.168.1.100 via ssh' | \
  nc -u localhost 30514

# ESXi test
echo '<134>Oct 10 21:00:00 192.168.1.10 Hostd: SSH login has failed for '\''root@10.0.0.50'\''' | \
  nc -u localhost 30527

# Wait 15 seconds for processing
sleep 15
```

**Verify indices:**

```bash
# Check if indices exist
curl -k -u admin:SecretPassword \
  "https://wazuh-indexer:9200/_cat/indices/anki-*,wazuh-alerts-*?v"

# Should show:
# anki-mikrotik-YYYY.MM.DD
# anki-esxi-YYYY.MM.DD
# wazuh-alerts-4.x-YYYY.MM.DD
```

**Check logs arrived:**

```bash
# Check MikroTik raw logs
curl -k -u admin:SecretPassword \
  "https://wazuh-indexer:9200/anki-mikrotik-*/_count?pretty"

# Check ESXi raw logs
curl -k -u admin:SecretPassword \
  "https://wazuh-indexer:9200/anki-esxi-*/_count?pretty"

# Check alerts
curl -k -u admin:SecretPassword \
  "https://wazuh-indexer:9200/wazuh-alerts-*/_search?q=mikrotik&size=1&pretty"
```

## ✅ Success Criteria

You're done when:

- ✅ No errors in `docker logs wazuh-fluentd`
- ✅ Indices `anki-mikrotik-*` and `anki-esxi-*` exist
- ✅ Alerts in `wazuh-alerts-*` with rule IDs
- ✅ GeoIP data present in alerts (`source_geo` field)
- ✅ Risk scores calculated

## 🎯 What's Next?

### Configure Log Sources

**MikroTik:**
```
/system logging action
add name=fluentd target=remote remote=<FLUENTD_IP> remote-port=30514

/system logging
add action=fluentd topics=system,error,warning,info
add action=fluentd topics=firewall
add action=fluentd topics=account
```

**ESXi:**
```bash
esxcli system syslog config set --loghost='udp://<FLUENTD_IP>:30527'
esxcli system syslog reload
```

**Generic Syslog:**
Point any device to `<FLUENTD_IP>:514/udp`

### Create Dashboards

1. Open Wazuh Dashboard
2. Stack Management → Index Patterns
3. Create patterns:
   - `anki-mikrotik-*`
   - `anki-esxi-*`
4. Create visualizations

### Set Up Alerting

Configure notifications in Wazuh Dashboard or use OpenSearch Alerting.

## 🆘 Troubleshooting

### Logs not appearing?

```bash
# Check Fluentd logs
docker logs wazuh-fluentd | grep -i error

# Check Wazuh Manager logs
docker exec wazuh-manager tail -f /var/ossec/logs/ossec.log

# Test connectivity
nc -zv wazuh-indexer 9200
nc -zv wazuh-manager 1514
```

### Rules not matching?

```bash
# Test decoders and rules locally
cd wazuh-manager
./test-rules.sh validate
./test-rules.sh quick
```

### Enrichment not working?

```bash
# Verify pipelines exist
curl -k -u admin:SecretPassword \
  "https://wazuh-indexer:9200/_ingest/pipeline?pretty" | \
  grep -E "(mikrotik|esxi)"
```

## 📚 Full Documentation

- **Complete Guide:** `DEPLOYMENT_GUIDE.md`
- **Architecture:** `FINAL_ARCHITECTURE.md`
- **Testing:** `README-TESTING.md`
- **Production:** `README_PRODUCTION.md`

## 🎉 You're Live!

Your log management system is now:
- ✅ Collecting logs from MikroTik, ESXi, and generic syslog
- ✅ Applying security rules with MITRE ATT&CK mapping
- ✅ Enriching with GeoIP and risk scores
- ✅ Storing in custom indices with minimal duplication

**Total deployment time: ~5 minutes** ⚡
