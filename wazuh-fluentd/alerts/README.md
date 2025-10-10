# OpenSearch Alerting Configuration

This directory contains OpenSearch alerting monitors and destinations for security event detection.

## Structure

```
alerts/
├── destinations/          # Notification channels (Slack, email, webhooks)
├── mikrotik/             # MikroTik-specific alerts
├── esxi/                 # VMware ESXi-specific alerts
├── deploy-alerts.sh      # Deployment script
└── README.md             # This file
```

## Prerequisites

The OpenSearch Alerting plugin is **already included** in Wazuh 4.13.1 by default. No additional installation needed.

## Quick Start

### 1. Configure Destinations

First, create notification destinations (Slack, email, etc.):

```bash
# Deploy destinations
./deploy-destinations.sh
```

### 2. Deploy Alerts

Deploy all alert monitors:

```bash
# Deploy all alerts
./deploy-alerts.sh

# Deploy specific category
./deploy-alerts.sh mikrotik
./deploy-alerts.sh esxi
```

### 3. Verify Deployment

Check deployed monitors in Wazuh Dashboard:
- Navigate to: **OpenSearch Dashboards → Alerting → Monitors**

Or via API:
```bash
curl -k -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/_search?pretty"
```

## Alert Definitions

### MikroTik Alerts

| Alert | Severity | Description |
|-------|----------|-------------|
| `mikrotik-login-failure` | High | Multiple login failures detected |
| `mikrotik-firewall-rule-change` | High | Firewall rule modifications |
| `mikrotik-vpn-connection` | Medium | VPN connection events |
| `mikrotik-user-change` | High | User account modifications |

### ESXi Alerts

| Alert | Severity | Description |
|-------|----------|-------------|
| `esxi-ssh-login-failure` | High | SSH authentication failures |
| `esxi-vm-operations` | Medium | VM power state changes |
| `esxi-account-management` | High | Account creation/deletion |
| `esxi-file-operations` | Medium | File upload/deletion events |

## Alert Severity Levels

- **1 (Critical)**: Immediate action required
- **2 (High)**: Requires prompt attention
- **3 (Medium)**: Should be reviewed
- **4 (Low)**: Informational
- **5 (Info)**: Audit/logging

## Notification Destinations

### Slack

```json
{
  "name": "slack-security",
  "type": "slack",
  "slack": {
    "url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
  }
}
```

### Email

```json
{
  "name": "email-soc",
  "type": "email",
  "email": {
    "email_account_id": "default_email",
    "recipients": ["soc@company.com"]
  }
}
```

### Custom Webhook

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

## Environment Variables

Set these in your environment or `.env` file:

```bash
# Required
INDEXER_HOST=wazuh-indexer
INDEXER_PORT=9200
INDEXER_USERNAME=admin
INDEXER_PASSWORD=SecretPassword

# Optional - Notification channels
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
EMAIL_RECIPIENTS=soc@company.com,security@company.com
WEBHOOK_URL=https://your-webhook.com/api
```

## Customization

### Modify Alert Thresholds

Edit the JSON files and adjust the trigger conditions:

```json
{
  "condition": {
    "script": {
      "source": "ctx.results[0].hits.total.value > 5",  // Change threshold
      "lang": "painless"
    }
  }
}
```

### Change Alert Frequency

Modify the schedule period:

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

### Add Custom Actions

Add multiple actions to a trigger:

```json
{
  "actions": [
    {
      "name": "Notify Slack",
      "destination_id": "slack-security",
      "message_template": {
        "source": "Alert: {{ctx.monitor.name}}",
        "lang": "mustache"
      }
    },
    {
      "name": "Email SOC",
      "destination_id": "email-soc",
      "message_template": {
        "source": "Critical alert detected",
        "lang": "mustache"
      }
    }
  ]
}
```

## Testing Alerts

### Trigger Test Alert

```bash
# Create test event
curl -k -X POST "https://wazuh-indexer:9200/anki-mikrotik-$(date +%Y.%m.%d)/_doc" \
  -u admin:password \
  -H "Content-Type: application/json" \
  -d '{
    "message": "login failure for user admin from 192.168.1.100",
    "log_source": "mikrotik",
    "@timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.000Z)'"
  }'
```

### Check Alert Status

```bash
# List all monitors
curl -k -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors?pretty"

# Get specific monitor
curl -k -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/<monitor_id>?pretty"

# View alert history
curl -k -u admin:password \
  "https://wazuh-indexer:9200/_plugins/_alerting/monitors/<monitor_id>/_execute?pretty"
```

## Troubleshooting

### Alerts Not Triggering

1. **Check monitor status**: Ensure monitor is enabled
2. **Verify index pattern**: Confirm data is being indexed
3. **Test query manually**: Run the search query in Dev Tools
4. **Check logs**: Review OpenSearch logs for errors

```bash
# Check if data exists
curl -k -u admin:password \
  "https://wazuh-indexer:9200/anki-mikrotik-*/_search?pretty&size=1"

# Test alert query
curl -k -u admin:password \
  "https://wazuh-indexer:9200/anki-mikrotik-*/_search?pretty" \
  -H "Content-Type: application/json" \
  -d @alerts/mikrotik/login-failure.json
```

### Notification Not Sending

1. **Verify destination**: Check destination configuration
2. **Test destination**: Use the "Send test message" feature
3. **Check webhook URL**: Ensure endpoint is accessible
4. **Review permissions**: Verify API keys/tokens are valid

## Best Practices

1. **Start with high-severity alerts** - Focus on critical security events first
2. **Tune thresholds** - Adjust based on your environment's baseline
3. **Use aggregations** - Group by source IP, user, etc. to reduce noise
4. **Set appropriate schedules** - Balance detection speed vs. resource usage
5. **Test before production** - Validate alerts in a test environment
6. **Document changes** - Keep alert definitions in version control
7. **Regular review** - Audit and update alerts quarterly

## Integration with SOAR

Alerts can trigger automated responses via webhooks:

```json
{
  "destination_id": "soar-webhook",
  "message_template": {
    "source": "{\n  \"alert_name\": \"{{ctx.monitor.name}}\",\n  \"severity\": \"{{ctx.trigger.severity}}\",\n  \"count\": {{ctx.results.0.hits.total.value}},\n  \"timestamp\": \"{{ctx.periodEnd}}\",\n  \"source_ips\": {{ctx.results.0.aggregations.by_source_ip.buckets}}\n}",
    "lang": "mustache"
  }
}
```

## References

- [Wazuh Alerting Blog](https://wazuh.com/blog/exploring-security-alerting-options-for-improved-threat-detection-in-wazuh-part-1/)
- [OpenSearch Alerting Documentation](https://opensearch.org/docs/latest/monitoring-plugins/alerting/)
- [Elastic Common Schema (ECS)](https://www.elastic.co/guide/en/ecs/current/index.html)
