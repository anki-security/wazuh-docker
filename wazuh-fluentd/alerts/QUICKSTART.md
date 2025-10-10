# OpenSearch Alerting - Quick Start Guide

This guide will help you set up security alerting for MikroTik and ESXi logs in 5 minutes.

## Prerequisites

✅ Wazuh 4.13.1 (includes OpenSearch Alerting plugin by default)
✅ Fluentd collecting logs from MikroTik and/or ESXi
✅ Data flowing into OpenSearch indices

## Step 1: Verify Data is Flowing

Check that logs are being indexed:

```bash
# Check MikroTik logs
curl -k -u admin:password \
  "https://wazuh-indexer:9200/anki-mikrotik-*/_count?pretty"

# Check ESXi logs
curl -k -u admin:password \
  "https://wazuh-indexer:9200/anki-vmware-esxi-*/_count?pretty"
```

You should see a count > 0 for indices with data.

## Step 2: Set Environment Variables

```bash
export INDEXER_HOST=wazuh-indexer
export INDEXER_PORT=9200
export INDEXER_USERNAME=admin
export INDEXER_PASSWORD=YourSecretPassword
```

## Step 3: Configure Notification Destination

### Option A: Slack (Recommended)

1. Create a Slack webhook:
   - Go to https://api.slack.com/apps
   - Create new app → Incoming Webhooks
   - Copy webhook URL

2. Create destination file:

```bash
cat > destinations/slack-security.json << 'EOF'
{
  "name": "slack-security",
  "type": "slack",
  "slack": {
    "url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
  }
}
EOF
```

3. Deploy destination:

```bash
./deploy-destinations.sh
```

4. Save the destination ID:

```bash
export DESTINATION_ID=$(cat destinations/.slack-security.id)
```

### Option B: Email

1. Configure email account in OpenSearch Dashboards:
   - Go to: **OpenSearch Dashboards → Alerting → Email accounts**
   - Create email account (SMTP settings)

2. Create destination file:

```bash
cat > destinations/email-soc.json << 'EOF'
{
  "name": "email-soc",
  "type": "email",
  "email": {
    "email_account_id": "default_email",
    "recipients": [
      {
        "type": "email",
        "email": "soc@company.com"
      }
    ]
  }
}
EOF
```

3. Deploy:

```bash
./deploy-destinations.sh
export DESTINATION_ID=$(cat destinations/.email-soc.id)
```

### Option C: Custom Webhook

```bash
cat > destinations/webhook-custom.json << 'EOF'
{
  "name": "webhook-custom",
  "type": "custom_webhook",
  "custom_webhook": {
    "url": "https://your-endpoint.com/api/alerts",
    "method": "POST",
    "header_params": {
      "Content-Type": "application/json",
      "Authorization": "Bearer YOUR_TOKEN"
    }
  }
}
EOF

./deploy-destinations.sh
export DESTINATION_ID=$(cat destinations/.webhook-custom.id)
```

## Step 4: Deploy Alerts

### Deploy All Alerts

```bash
./deploy-alerts.sh all
```

### Deploy Specific Category

```bash
# MikroTik only
./deploy-alerts.sh mikrotik

# ESXi only
./deploy-alerts.sh esxi
```

## Step 5: Verify Deployment

### Via Dashboard

1. Open Wazuh Dashboard
2. Navigate to: **OpenSearch Dashboards → Alerting → Monitors**
3. You should see your monitors listed

### Via API

```bash
# List all monitors
curl -k -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/_search?pretty"

# Check specific monitor
curl -k -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/_search?pretty" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "match": {
        "monitor.name": "MikroTik - Login Failure"
      }
    }
  }'
```

## Step 6: Test Alerts

### Generate Test Event

**MikroTik Login Failure:**

```bash
curl -k -X POST \
  "https://wazuh-indexer:9200/anki-mikrotik-$(date +%Y.%m.%d)/_doc" \
  -u admin:password \
  -H "Content-Type: application/json" \
  -d '{
    "message": "login failure for user admin from 192.168.1.100 via ssh",
    "log_source": "mikrotik",
    "source": {
      "ip": "192.168.1.100"
    },
    "user": {
      "name": "admin"
    },
    "@timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.000Z)'"
  }'
```

**ESXi SSH Login Failure:**

```bash
curl -k -X POST \
  "https://wazuh-indexer:9200/anki-vmware-esxi-$(date +%Y.%m.%d)/_doc" \
  -u admin:password \
  -H "Content-Type: application/json" \
  -d '{
    "message": "SSH login has failed for root@10.0.0.50",
    "log_source": "vmware-esxi",
    "event": {
      "action": "ssh-login-failed"
    },
    "source": {
      "ip": "10.0.0.50"
    },
    "user": {
      "name": "root"
    },
    "esxi": {
      "host": "esxi-host01"
    },
    "@timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.000Z)'"
  }'
```

### Manually Execute Monitor

```bash
# Get monitor ID
MONITOR_ID="your-monitor-id"

# Execute monitor
curl -k -X POST \
  -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/${MONITOR_ID}/_execute?pretty"
```

## Deployed Alerts Summary

### MikroTik Alerts (4 monitors)

| Alert | Severity | Threshold | Check Interval |
|-------|----------|-----------|----------------|
| Login Failure | High | > 5 failures | 1 minute |
| Firewall Rule Change | High | Any change | 1 minute |
| User Account Change | High | Any change | 1 minute |
| VPN Connection | Medium | Any activity | 5 minutes |

### ESXi Alerts (4 monitors)

| Alert | Severity | Threshold | Check Interval |
|-------|----------|-----------|----------------|
| SSH Login Failure | High | > 3 failures | 1 minute |
| VM Operations | Medium | Any operation | 5 minutes |
| Account Management | High | Any change | 1 minute |
| File Operations | Medium | Any operation | 5 minutes |

## Customization

### Adjust Thresholds

Edit the JSON file and change the condition:

```json
{
  "condition": {
    "script": {
      "source": "ctx.results[0].hits.total.value > 10",  // Change from 5 to 10
      "lang": "painless"
    }
  }
}
```

### Change Check Frequency

```json
{
  "schedule": {
    "period": {
      "interval": 5,      // Change from 1 to 5
      "unit": "MINUTES"
    }
  }
}
```

### Modify Notification Message

```json
{
  "message_template": {
    "source": "🚨 Custom Alert Message\n\nCount: {{ctx.results.0.hits.total.value}}\nTime: {{ctx.periodEnd}}",
    "lang": "mustache"
  }
}
```

After making changes, redeploy:

```bash
# Delete old monitor first
curl -k -X DELETE \
  -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/${MONITOR_ID}"

# Deploy updated monitor
./deploy-alerts.sh
```

## Troubleshooting

### No Alerts Triggering

1. **Check monitor is enabled:**
   ```bash
   curl -k -u admin:password \
     "https://wazuh-indexer:9200/_plugins/_alerting/monitors/${MONITOR_ID}?pretty"
   ```

2. **Verify data exists:**
   ```bash
   curl -k -u admin:password \
     "https://wazuh-indexer:9200/anki-mikrotik-*/_search?pretty&size=1"
   ```

3. **Test query manually:**
   - Go to **Dev Tools** in OpenSearch Dashboards
   - Paste the query from the alert JSON
   - Run and verify results

4. **Check alert history:**
   ```bash
   curl -k -u admin:password \
     "https://wazuh-indexer:9200/.opendistro-alerting-alert-history-*/_search?pretty" \
     -H "Content-Type: application/json" \
     -d '{
       "query": {
         "match": {
           "monitor_name": "MikroTik - Login Failure"
         }
       },
       "size": 10,
       "sort": [{"execution_start_time": "desc"}]
     }'
   ```

### Notifications Not Sending

1. **Test destination:**
   - Go to **Alerting → Destinations**
   - Click destination → **Send test message**

2. **Check destination ID:**
   ```bash
   # List all destinations
   curl -k -u admin:password \
     "https://wazuh-indexer:9200/_plugins/_alerting/destinations?pretty"
   ```

3. **Verify webhook/Slack URL is accessible:**
   ```bash
   curl -X POST "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
     -H "Content-Type: application/json" \
     -d '{"text": "Test message"}'
   ```

### Permission Errors

Ensure the user has alerting permissions:

```bash
# Check user roles
curl -k -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_security/api/internalusers/admin?pretty"
```

## Maintenance

### List All Monitors

```bash
curl -k -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/_search?pretty&size=100"
```

### Delete Monitor

```bash
curl -k -X DELETE \
  -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/${MONITOR_ID}"
```

### Disable Monitor

```bash
curl -k -X PUT \
  -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/${MONITOR_ID}" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": false
  }'
```

### Export All Monitors

```bash
curl -k -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/_search?size=100&pretty" \
  > monitors-backup.json
```

## Next Steps

1. **Fine-tune thresholds** based on your environment
2. **Add more destinations** (email, PagerDuty, etc.)
3. **Create custom alerts** for specific use cases
4. **Set up alert aggregation** to reduce noise
5. **Integrate with SOAR** for automated response

## Resources

- [Full Documentation](./README.md)
- [Wazuh Alerting Blog](https://wazuh.com/blog/exploring-security-alerting-options-for-improved-threat-detection-in-wazuh-part-1/)
- [OpenSearch Alerting Docs](https://opensearch.org/docs/latest/monitoring-plugins/alerting/)
- [Alert Examples](./mikrotik/) and [ESXi Examples](./esxi/)
