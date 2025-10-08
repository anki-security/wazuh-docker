# Fluentd Legacy Working Configuration - File Index

This folder contains the **complete original Fluentd configuration** that was working before the Vector migration.

## Files Preserved

### Documentation
- **`README.md`** - Overview, rollback instructions, and lessons learned
- **`CONFIGURATION_NOTES.md`** - Detailed technical configuration notes
- **`FILE_INDEX.md`** - This file - index of all preserved files

### Original Working Configuration (from git commit 02fc69e)
These files represent the **last known working state**:

1. **`fluentd.conf.j2`** (ORIGINAL - from git)
   - Main Fluentd configuration template
   - Jinja2 template with variables
   - Defines workers, log level, includes
   - **Status**: ✅ This was working with port 30514

2. **`fluentd-statefulset-original.yml`** (ORIGINAL - from git)
   - Kubernetes StatefulSet definition
   - Port mappings, resource limits, volumes
   - Service configuration
   - **Status**: ✅ This was the working deployment

3. **`fluentd-deployment-original.yml`** (ORIGINAL - from git)
   - Alternative deployment configuration
   - **Note**: May be empty or minimal

### Current State (before Vector migration)
These files show the state right before Vector replaced Fluentd:

4. **`fluentd-statefulset-current.yml`**
   - Current StatefulSet with port changes (40514)
   - Modified worker configuration
   - **Status**: ❌ Not working - events not emitting

5. **`fluentd-deployment-current.yml`**
   - Current deployment configuration
   - **Status**: Reference only

6. **`fluentd-statefulset-changes.diff`**
   - Git diff showing all changes made
   - Useful for understanding what broke

### OpenSearch Configuration (STILL IN USE)

7. **`mikrotik-pipeline.json`**
   - OpenSearch ingest pipeline for MikroTik logs
   - Grok patterns for parsing
   - **Status**: ✅ Still working, used by Vector too
   - **Location**: Also at `roles/wazuh/files/pipelines/mikrotik-pipeline.json`

## Key Differences: Original vs Current

### Port Configuration
- **Original (WORKING)**: 30514 UDP
- **Current (BROKEN)**: 40514 UDP
- **Issue**: Port change seemed to trigger event emission bug

### Worker Configuration
- **Original (WORKING)**: 7 workers with sources in worker blocks
- **Current (BROKEN)**: Attempted single worker, no workers, various configs
- **Issue**: Input plugins stopped emitting events

### Image Configuration
- **Original (WORKING)**: Custom Docker image with configs baked in
- **Current (BROKEN)**: Same image but with config changes
- **Issue**: Configuration changes broke event emission

## How to Use These Files

### To Rollback to Working Fluentd

1. **Delete Vector**:
   ```bash
   kubectl delete statefulset vector -n client1
   kubectl delete svc vector -n client1
   ```

2. **Deploy Original Fluentd**:
   ```bash
   # Use the original StatefulSet
   kubectl apply -f fluentd-legacy-working/fluentd-statefulset-original.yml
   ```

3. **Configure MikroTik**:
   - Send syslog to port **30514** (original port)
   - Target: 192.168.61.20:30514

### To Debug Current Issues

1. **Compare Configurations**:
   ```bash
   diff fluentd-statefulset-original.yml fluentd-statefulset-current.yml
   ```

2. **Review Changes**:
   ```bash
   cat fluentd-statefulset-changes.diff
   ```

3. **Check Original Config**:
   ```bash
   cat fluentd.conf.j2
   ```

## Important Notes

### What Definitely Worked
- ✅ Port 30514 UDP
- ✅ 7 workers with worker blocks
- ✅ Custom Docker image
- ✅ OpenSearch pipeline parsing
- ✅ Index pattern: anki-mikrotik-YYYY.MM.DD

### What Broke Things
- ❌ Changing port to 40514
- ❌ Modifying worker configuration
- ❌ Removing worker blocks
- ❌ Single worker mode

### What Still Works
- ✅ OpenSearch pipelines (mikrotik-routeros)
- ✅ OpenSearch indexing (when data arrives)
- ✅ Kubernetes infrastructure
- ✅ Network connectivity

## Related Files in Main Repo

These files are still in the main repository:

- `roles/wazuh/files/pipelines/mikrotik-pipeline.json` - Pipeline (in use)
- `roles/wazuh/tasks/resources/fluentd-statefulset.yml` - Current StatefulSet
- `roles/wazuh/tasks/resources/fluentd-deployment.yml` - Current Deployment
- `inventory/development/group_vars/client1.yml` - Resource configs

## Git History

To see full history of Fluentd files:
```bash
git log --all --full-history -- roles/wazuh/templates/fluentd.conf.j2
git log --all --full-history -- roles/wazuh/tasks/resources/fluentd-statefulset.yml
```

To restore a specific version:
```bash
git show 02fc69e:roles/wazuh/templates/fluentd.conf.j2
```

## Last Updated
2025-10-08 23:03 - Preserved original Fluentd configuration before Vector migration
