# Revert Instructions for Fluentd Changes

## Current State (main branch)
- Using `remote_syslog` with improved buffer configuration
- Added `ignore_error`, better retry logic, and interval flushing

## To Revert to Original remote_syslog Configuration

### Option 1: Use backup branch
```bash
cd /Users/rolandsbirons/Development/anki-wazuh-docker
git checkout backup/remote-syslog-original
git push origin main --force  # WARNING: Force push!
```

### Option 2: Revert the commit
```bash
cd /Users/rolandsbirons/Development/anki-wazuh-docker
git revert HEAD
git push
```

### Option 3: Cherry-pick from backup
```bash
cd /Users/rolandsbirons/Development/anki-wazuh-docker
git checkout main
git checkout backup/remote-syslog-original -- wazuh-fluentd/config/conf.d/10-mikrotik.conf
git commit -m "revert: restore original remote_syslog config"
git push
```

## Backup Branch
- Branch name: `backup/remote-syslog-original`
- Contains: Original `remote_syslog` configuration before reliability improvements
- File: `wazuh-fluentd/config/conf.d/10-mikrotik.conf`

## Changes Made
1. Added `ignore_error` to store block
2. Changed `flush_mode` from `immediate` to `interval` (5s)
3. Added `flush_at_shutdown true`
4. Added `retry_max_times 10` (prevents infinite retries)
5. Kept `@log_level debug` for troubleshooting

## After Reverting
Remember to rebuild and redeploy:
```bash
gh workflow run build-and-push-parallel.yml --repo anki-security/wazuh-docker
# Wait for build
kubectl delete pod fluentd-0 -n client1
```
