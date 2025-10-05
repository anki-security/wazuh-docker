# Build and Release Guide

## GitHub Actions Workflow

### Manual Trigger

The build workflow can be triggered manually from GitHub Actions:

1. Go to **Actions** tab in GitHub
2. Select **"Build and Push Wazuh Fluentd"** workflow
3. Click **"Run workflow"**
4. Select version bump type:
   - **patch** - Bug fixes (2.0.0 → 2.0.1)
   - **minor** - New features (2.0.0 → 2.1.0)
   - **major** - Breaking changes (2.0.0 → 3.0.0)

### What Happens on Success

1. ✅ **Version Bump** - Updates `VERSION` file
2. ✅ **Changelog Update** - Adds entry to `CHANGELOG.md`
3. ✅ **Docker Build** - Builds multi-arch image (amd64, arm64)
4. ✅ **Push to Registry** - Pushes to GitHub Container Registry
5. ✅ **Git Commit** - Commits version changes
6. ✅ **Git Tag** - Creates version tag (e.g., `v2.0.1`)
7. ✅ **GitHub Release** - Creates release with notes

### Docker Images

After successful build, images are available at:

```bash
# Specific version
docker pull ghcr.io/YOUR_USERNAME/wazuh-fluentd:2.0.0

# Latest
docker pull ghcr.io/YOUR_USERNAME/wazuh-fluentd:latest
```

## Local Build

### Build Image

```bash
docker build -t wazuh-fluentd:local .
```

### Test Locally

```bash
docker run -d \
  --name wazuh-fluentd-test \
  -p 2055:2055/udp \
  -p 30514:30514/udp \
  -e INDEXER_HOST=wazuh-indexer \
  -e INDEXER_USERNAME=admin \
  -e INDEXER_PASSWORD=SecretPassword \
  wazuh-fluentd:local
```

### Check Logs

```bash
docker logs wazuh-fluentd-test
```

## Version Management

### Current Version

```bash
cat VERSION
```

### Manual Version Bump

```bash
# Edit VERSION file
echo "2.1.0" > VERSION

# Update CHANGELOG.md manually
# Commit changes
git add VERSION CHANGELOG.md
git commit -m "chore: bump version to 2.1.0"
git tag -a v2.1.0 -m "Release v2.1.0"
git push origin main --tags
```

## Required Files

### Essential Files
- ✅ `Dockerfile` - Container build instructions
- ✅ `VERSION` - Version number (e.g., 2.0.0)
- ✅ `config/fluent.conf` - Main Fluentd configuration
- ✅ `config/conf.d/*.conf` - Integration configs
- ✅ `config/config.sh` - Startup script
- ✅ `config/setup_pipelines.sh` - Pipeline setup script
- ✅ `config/pipelines/*.json` - OpenSearch pipelines

### Documentation
- ✅ `README.md` - Main documentation
- ✅ `CHANGELOG.md` - Version history
- ✅ `BUILD.md` - This file

### CI/CD
- ✅ `../.github/workflows/build-wazuh-fluentd.yml` - GitHub Actions workflow (in parent repo)

### Optional
- ✅ `.dockerignore` - Docker build exclusions
- ✅ `docker-compose.example.yml` - Example compose file

## Removed Files

The following files were removed as they were unnecessary:

- ❌ `config/check_repository.sh` - Unused placeholder
- ❌ `config/integrations/` - Over-engineered configs
- ❌ `config/shared/` - Unnecessary shared components
- ❌ `config/patterns/` - Unused patterns directory
- ❌ `INTEGRATIONS.md` - Outdated documentation
- ❌ `MIGRATION.md` - Outdated migration guide
- ❌ `NEW_INTEGRATIONS.md` - Outdated summary
- ❌ `REFACTORING_SUMMARY.md` - Outdated summary
- ❌ `SUMMARY.md` - Outdated summary
- ❌ `PORTS.md` - Redundant port info
- ❌ `QUICKSTART.md` - Outdated quick start

## Troubleshooting

### Build Fails

Check Docker build logs:
```bash
docker build -t wazuh-fluentd:debug . --progress=plain
```

### Workflow Fails

1. Check GitHub Actions logs
2. Verify `VERSION` file exists
3. Ensure `CHANGELOG.md` exists
4. Check GitHub token permissions

### Version Conflicts

If version already exists:
```bash
# Delete local tag
git tag -d v2.0.0

# Delete remote tag
git push origin :refs/tags/v2.0.0

# Re-run workflow
```

## Best Practices

1. **Always use workflow** for releases (ensures consistency)
2. **Test locally** before triggering workflow
3. **Update CHANGELOG** with meaningful changes
4. **Use semantic versioning**:
   - MAJOR: Breaking changes
   - MINOR: New features (backward compatible)
   - PATCH: Bug fixes
5. **Tag releases** for easy rollback

## Integration Testing

After build, test each integration:

```bash
# MikroTik
echo "test" | nc -u localhost 30514

# Fortigate
echo "test" | nc localhost 30515

# NetFlow
# Configure router to send to port 2055

# Check indices
curl -k -u admin:password https://wazuh-indexer:9200/_cat/indices?v
```
