# OpenSearch Alerting Setup for Wazuh

Complete guide for setting up security alerting with OpenSearch Alerting plugin in Wazuh 4.13.1.

## Overview

This setup provides **security event detection and alerting** for:
- ✅ MikroTik RouterOS logs
- ✅ VMware ESXi logs
- ✅ Extensible to other log sources

**Key Features:**
- Real-time security event detection
- Customizable alert thresholds
- Multiple notification channels (Slack, Email, Webhooks)
- ECS-compliant field mapping
- Infrastructure as Code approach

## Architecture

```
┌─────────────────┐
│  Log Sources    │
│  (MikroTik,     │
│   ESXi, etc.)   │
└────────┬────────┘
         │ Syslog
         ▼
┌─────────────────┐
│    Fluentd      │
│  (Port 30514+)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   OpenSearch    │
│    Pipeline     │ ◄── Grok parsing, ECS mapping
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Wazuh Indexer   │
│  (OpenSearch)   │ ◄── Indexed logs
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Alerting     │
│     Plugin      │ ◄── Query-based monitors
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Notifications   │
│ (Slack, Email)  │
└─────────────────┘
```

## What's Included

### Alert Definitions

**MikroTik (4 alerts):**
- `login-failure.json` - Detects multiple failed login attempts
- `firewall-rule-change.json` - Monitors firewall rule modifications
- `user-change.json` - Tracks user account changes
- `vpn-connection.json` - Logs VPN connection activity

**ESXi (4 alerts):**
- `ssh-login-failure.json` - Detects SSH authentication failures
- `vm-operations.json` - Monitors VM power state changes
- `account-management.json` - Tracks account creation/deletion
- `file-operations.json` - Logs file upload/deletion events

### Deployment Scripts

- `deploy-destinations.sh` - Creates notification channels
- `deploy-alerts.sh` - Deploys alert monitors
- Automatic destination ID substitution
- Error handling and rollback

### Documentation

- `README.md` - Comprehensive documentation
- `QUICKSTART.md` - 5-minute setup guide
- Example destination configurations
- Troubleshooting guides

## Quick Start

### 1. Prerequisites

```bash
# Verify Wazuh version (must be 4.13.1+)
curl -k -u admin:password https://wazuh-indexer:9200

# Check data is flowing
curl -k -u admin:password \
  "https://wazuh-indexer:9200/anki-mikrotik-*/_count?pretty"
```

### 2. Set Environment Variables

```bash
export INDEXER_HOST=wazuh-indexer
export INDEXER_PORT=9200
export INDEXER_USERNAME=admin
export INDEXER_PASSWORD=YourPassword
```

### 3. Configure Slack Webhook

```bash
cd alerts/destinations

# Create Slack destination
cat > slack-security.json << 'EOF'
{
  "name": "slack-security",
  "type": "slack",
  "slack": {
    "url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
  }
}
EOF
```

### 4. Deploy

```bash
# Deploy notification destination
./deploy-destinations.sh

# Get destination ID
export DESTINATION_ID=$(cat destinations/.slack-security.id)

# Deploy all alerts
./deploy-alerts.sh all
```

### 5. Verify

Open Wazuh Dashboard → **OpenSearch Dashboards → Alerting → Monitors**

## Alert Configuration

### Alert Structure

Each alert monitor consists of:

1. **Schedule** - How often to check (1-5 minutes)
2. **Query** - What data to search for
3. **Trigger** - When to fire alert (threshold)
4. **Action** - What to do (send notification)

### Example: MikroTik Login Failure

```json
{
  "name": "MikroTik - Login Failure",
  "schedule": {
    "period": {
      "interval": 1,
      "unit": "MINUTES"
    }
  },
  "inputs": [{
    "search": {
      "indices": ["anki-mikrotik-*"],
      "query": {
        "bool": {
          "must": [
            { "match": { "log_source": "mikrotik" }},
            { "match_phrase": { "message": "login failure" }}
          ]
        }
      }
    }
  }],
  "triggers": [{
    "condition": {
      "script": {
        "source": "ctx.results[0].hits.total.value > 5"
      }
    },
    "actions": [{
      "destination_id": "slack-security",
      "message_template": {
        "source": "🚨 Login Failures: {{ctx.results.0.hits.total.value}}"
      }
    }]
  }]
}
```

## Notification Channels

### Slack

Best for real-time team notifications.

**Setup:**
1. Create Slack app at https://api.slack.com/apps
2. Enable Incoming Webhooks
3. Add webhook URL to destination config

**Message Format:**
```
🚨 MikroTik Login Failures Detected

Count: 12
Time: 2025-10-10T14:30:00Z
Monitor: MikroTik - Login Failure

Top Source IPs:
- 192.168.1.100: 8 attempts
- 10.0.0.50: 4 attempts
```

### Email

Best for formal notifications and audit trails.

**Setup:**
1. Configure SMTP in OpenSearch Dashboards
2. Create email account: **Alerting → Email accounts**
3. Add recipients to destination config

### Custom Webhook

Best for SOAR/SIEM integration.

**Setup:**
```json
{
  "name": "webhook-siem",
  "type": "custom_webhook",
  "custom_webhook": {
    "url": "https://your-siem.com/api/alerts",
    "method": "POST",
    "header_params": {
      "Content-Type": "application/json",
      "Authorization": "Bearer YOUR_TOKEN"
    }
  }
}
```

**Payload:**
```json
{
  "alert_name": "MikroTik - Login Failure",
  "severity": "high",
  "count": 12,
  "timestamp": "2025-10-10T14:30:00Z",
  "source_ips": ["192.168.1.100", "10.0.0.50"]
}
```

## Customization

### Adjust Alert Thresholds

Edit the alert JSON file:

```json
{
  "condition": {
    "script": {
      "source": "ctx.results[0].hits.total.value > 10"  // Change threshold
    }
  }
}
```

### Change Check Frequency

```json
{
  "schedule": {
    "period": {
      "interval": 5,      // Check every 5 minutes
      "unit": "MINUTES"
    }
  }
}
```

### Add Aggregations

Group alerts by field:

```json
{
  "aggs": {
    "by_source_ip": {
      "terms": {
        "field": "source.ip",
        "size": 10
      }
    }
  }
}
```

### Throttle Notifications

Prevent alert fatigue:

```json
{
  "throttle_enabled": true,
  "throttle": {
    "value": 10,
    "unit": "MINUTES"
  }
}
```

## Alert Severity Levels

| Level | Severity | Use Case | Example |
|-------|----------|----------|---------|
| 1 | Critical | Immediate action required | Active breach, system down |
| 2 | High | Prompt attention needed | Multiple login failures, config changes |
| 3 | Medium | Should be reviewed | VPN connections, VM operations |
| 4 | Low | Informational | Routine events |
| 5 | Info | Audit/logging | Successful logins |

## Best Practices

### 1. Start Small
- Deploy high-severity alerts first
- Test with one notification channel
- Gradually add more alerts

### 2. Tune Thresholds
- Monitor false positive rate
- Adjust based on environment baseline
- Use aggregations to reduce noise

### 3. Use Throttling
- Prevent alert storms
- Set appropriate time windows
- Group related alerts

### 4. Test Regularly
- Generate test events
- Verify notifications arrive
- Check alert history

### 5. Version Control
- Keep alert definitions in Git
- Document all changes
- Use CI/CD for deployment

### 6. Monitor Performance
- Check query execution time
- Optimize slow queries
- Balance frequency vs. load

## Troubleshooting

### Alerts Not Triggering

**Check monitor status:**
```bash
curl -k -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/${MONITOR_ID}?pretty"
```

**Verify data exists:**
```bash
curl -k -u admin:password \
  "https://wazuh-indexer:9200/anki-mikrotik-*/_search?size=1&pretty"
```

**Test query manually:**
- Open **Dev Tools** in OpenSearch Dashboards
- Paste query from alert JSON
- Verify results

### Notifications Not Sending

**Test destination:**
- Go to **Alerting → Destinations**
- Click destination → **Send test message**

**Check webhook:**
```bash
curl -X POST "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
  -H "Content-Type: application/json" \
  -d '{"text": "Test"}'
```

### High False Positive Rate

1. Increase threshold
2. Add more specific filters
3. Use aggregations
4. Adjust time window

## Maintenance

### List All Monitors

```bash
curl -k -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/_search?size=100&pretty"
```

### Update Monitor

```bash
curl -k -X PUT \
  -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/${MONITOR_ID}" \
  -H "Content-Type: application/json" \
  -d @updated-monitor.json
```

### Delete Monitor

```bash
curl -k -X DELETE \
  -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/${MONITOR_ID}"
```

### Backup Monitors

```bash
curl -k -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/_search?size=100" \
  > monitors-backup-$(date +%Y%m%d).json
```

## Integration Examples

### SOAR Integration

Send alerts to SOAR platform for automated response:

```json
{
  "destination_id": "soar-webhook",
  "message_template": {
    "source": "{\n  \"alert\": \"{{ctx.monitor.name}}\",\n  \"severity\": \"{{ctx.trigger.severity}}\",\n  \"count\": {{ctx.results.0.hits.total.value}},\n  \"ips\": {{ctx.results.0.aggregations.by_source_ip.buckets}}\n}"
  }
}
```

### Ticketing System

Create tickets automatically:

```json
{
  "custom_webhook": {
    "url": "https://jira.company.com/rest/api/2/issue",
    "method": "POST",
    "header_params": {
      "Authorization": "Bearer TOKEN",
      "Content-Type": "application/json"
    }
  }
}
```

### PagerDuty

For on-call escalation:

```json
{
  "custom_webhook": {
    "url": "https://events.pagerduty.com/v2/enqueue",
    "method": "POST",
    "header_params": {
      "Content-Type": "application/json"
    }
  }
}
```

## Performance Considerations

### Query Optimization

- Use specific index patterns
- Limit aggregation size
- Add field filters early
- Use `size: 0` when only counting

### Resource Usage

- Monitor CPU/memory on indexer
- Adjust check intervals
- Limit concurrent monitors
- Use throttling

### Scaling

- Distribute monitors across nodes
- Use index lifecycle management
- Archive old alert history
- Optimize index mappings

## Security

### Access Control

- Use dedicated alerting user
- Limit destination access
- Encrypt webhook URLs
- Rotate API keys regularly

### Audit Trail

- Enable audit logging
- Monitor alert modifications
- Track destination changes
- Review alert history

## Next Steps

1. ✅ Deploy basic alerts (completed)
2. 🔄 Monitor and tune thresholds
3. 📊 Create dashboards for alert metrics
4. 🔗 Integrate with SOAR/ticketing
5. 📝 Document runbooks for each alert
6. 🧪 Regular testing and drills

## Resources

- [Quick Start Guide](./alerts/QUICKSTART.md)
- [Alert Examples](./alerts/)
- [Wazuh Alerting Blog](https://wazuh.com/blog/exploring-security-alerting-options-for-improved-threat-detection-in-wazuh-part-1/)
- [OpenSearch Alerting Docs](https://opensearch.org/docs/latest/monitoring-plugins/alerting/)
- [ECS Field Reference](https://www.elastic.co/guide/en/ecs/current/ecs-field-reference.html)

## Support

For issues or questions:
1. Check troubleshooting section
2. Review OpenSearch logs
3. Test queries in Dev Tools
4. Verify data is indexed correctly
