# VMware ESXi Log Integration

## Overview
This integration captures and parses VMware ESXi syslog events, including SSH sessions, VM operations, user management, and file operations.

## Configuration

### Fluentd Configuration
- **File**: `15-vmware-esxi.conf`
- **Port**: 30527 UDP
- **Tag**: `esxi.syslog`
- **Index**: `anki-vmware-esxi-YYYY.MM.DD`
- **Pipeline**: `vmware-esxi`

### Pipeline Configuration
- **File**: `vmware-esxi-pipeline.json`
- **Location**: `/fluentd/pipelines/`

## Supported Events

### Authentication Events
- SSH session opened/closed
- SSH login failures
- User login/logout
- Login failures

### VM Operations
- VM powered on/off
- Guest OS shutdown/reboot
- VM creation/removal/registration

### User Management
- Account creation
- Password changes
- Account removal

### File Operations
- File uploads
- File/directory deletions

### Command Execution
- Shell commands executed by users

## ESXi Configuration

To send logs from ESXi to Fluentd:

1. **SSH into your ESXi host**

2. **Configure syslog forwarding**:
   ```bash
   esxcli system syslog config set --loghost='udp://<FLUENTD_HOST>:30527'
   esxcli system syslog reload
   ```

3. **Verify configuration**:
   ```bash
   esxcli system syslog config get
   ```

4. **Test logging**:
   ```bash
   esxcli system syslog mark --message="Test message from ESXi"
   ```

## Log Format

ESXi logs are expected in the format:
```
vmware-esxi: <priority> <timestamp> <hostname> <process>[<pid>]: <message>
```

Examples:
```
vmware-esxi: 2024-10-10T14:29:25.123Z esxi-host01 Hostd[12345]: Event 1234 : User root@192.168.1.100 logged in
vmware-esxi: Oct 10 14:29:25 esxi-host01 Hostd[12345]: Event 5678 : SSH session was opened for 'admin@10.0.0.50'
```

## ECS Field Mapping

The pipeline maps ESXi fields to Elastic Common Schema (ECS):

| ESXi Field | ECS Field | Description |
|------------|-----------|-------------|
| event_id | event.id | Event identifier |
| user | user.name | Username |
| srcip | source.ip | Source IP address |
| esxi_host | esxi.host | ESXi hostname |
| vm | vm.name | Virtual machine name |
| process_name | process.name | Process name |
| process_id | process.pid | Process ID |
| datacenter | esxi.datacenter | Datacenter name |
| command | esxi.command | Executed command |
| path | file.path | File path |

## Event Categories

Events are categorized using ECS event taxonomy:

- **authentication**: Login/logout events
- **iam**: User and account management
- **file**: File operations
- **host**: VM operations

## Deployment

The pipeline is automatically deployed when the Fluentd container starts via the `setup_pipelines.sh` script.

To manually deploy:
```bash
docker exec <fluentd-container> /usr/local/bin/setup_pipelines.sh
```

## Troubleshooting

### No logs appearing
1. Check ESXi syslog configuration: `esxcli system syslog config get`
2. Verify network connectivity: `nc -zvu <FLUENTD_HOST> 30527`
3. Check Fluentd logs: `docker logs <fluentd-container>`

### Parsing errors
Check the OpenSearch index for documents with `event.kind: pipeline_error` and review the `error.message` field.

### View pipeline
```bash
curl -k -u admin:password https://<indexer>:9200/_ingest/pipeline/vmware-esxi?pretty
```

## Security Considerations

- Use TLS for syslog forwarding in production (requires additional configuration)
- Restrict access to port 30527 using firewall rules
- Rotate ESXi credentials regularly
- Monitor for failed authentication attempts

## References

- [VMware ESXi Syslog Documentation](https://docs.vmware.com/en/VMware-vSphere/index.html)
- [Elastic Common Schema (ECS)](https://www.elastic.co/guide/en/ecs/current/index.html)
- [Wazuh ESXi Decoder](https://documentation.wazuh.com/current/user-manual/ruleset/decoders.html)
