# Fluentd Legacy Working Configuration

This folder contains the **original working Fluentd configuration** that successfully processed MikroTik logs before the migration to Vector.

## What Was Working

- ✅ MikroTik syslog ingestion on port 30514 (old port)
- ✅ Parsing with MikroTik pipeline in OpenSearch
- ✅ Data successfully indexed to OpenSearch
- ✅ Multi-worker configuration (7 workers)

## Configuration Details

### Original Setup
- **Image**: Custom Fluentd image with built-in configs
- **Port**: 30514 UDP (MikroTik)
- **Workers**: 7 workers with per-worker source assignments
- **Pipeline**: mikrotik-routeros pipeline in OpenSearch
- **Index**: anki-mikrotik-YYYY.MM.DD

### Files Preserved
1. `fluentd-statefulset-original.yml` - Working StatefulSet configuration
2. `mikrotik-pipeline.json` - OpenSearch ingest pipeline (still in use)
3. `fluentd-config-notes.md` - Configuration notes and lessons learned

## Why It Worked

The original Fluentd setup worked because:
1. **Proper worker configuration** - Sources were correctly assigned to specific workers
2. **Correct parser** - Used `@type none` to pass raw messages to OpenSearch pipeline
3. **Pipeline in OpenSearch** - All parsing done server-side via Grok patterns
4. **Stable image** - Custom Docker image with all dependencies pre-installed

## Migration Issues Discovered

When migrating to new ports (40514) and eventually to Vector:
1. **Fluentd Issue**: Multi-worker mode caused input plugins to stop emitting events
2. **Single-worker Issue**: Without workers, UDP/TCP sources didn't bind properly
3. **Vector Issue**: Same problem - syslog sources receive packets but don't emit events

## Current Status (as of 2025-10-08)

- ❌ Fluentd removed (replaced by Vector)
- ✅ Vector deployed and running
- ❌ Vector not processing syslog messages (same issue as Fluentd)
- ✅ OpenSearch pipelines still working and ready
- ⏳ Need to debug Vector syslog source configuration

## Rollback Instructions

If needed to rollback to working Fluentd:

```bash
# 1. Delete Vector
kubectl delete statefulset vector -n client1
kubectl delete svc vector -n client1

# 2. Restore Fluentd with original configuration
# Use the StatefulSet from this folder
kubectl apply -f fluentd-legacy-working/fluentd-statefulset-original.yml

# 3. Configure MikroTik to send to port 30514 (original port)
```

## Lessons Learned

1. **Don't change too many things at once** - Port change + image change + worker config change = hard to debug
2. **Test incrementally** - Should have tested port change first, then worker config, then image
3. **Keep working configs** - Always preserve what works before major changes
4. **UDP/TCP input plugins are tricky** - Both Fluentd and Vector have issues with event emission
5. **OpenSearch pipelines are solid** - The parsing pipeline works great, it's the ingestion that's problematic

## Next Steps

1. Debug Vector syslog source configuration
2. Consider alternative approaches (socket source, external collector)
3. If Vector doesn't work, consider other options (Logstash, Filebeat + external collector)
4. Document working solution for future reference
