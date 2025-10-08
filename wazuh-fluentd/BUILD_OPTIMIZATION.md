# Build Optimization Guide

## Current Optimizations Applied ✅

### 1. **GitHub Actions Cache** (Already enabled)
- Uses `cache-from: type=gha` and `cache-to: type=gha,mode=max`
- Caches Docker layers between builds
- **Savings**: ~5-7 minutes on subsequent builds

### 2. **Disable Provenance & SBOM** (NEW)
```yaml
provenance: false
sbom: false
```
- Skips attestation generation
- **Savings**: ~1-2 minutes

### 3. **BuildKit Cache Mounts** (NEW)
```dockerfile
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked
RUN --mount=type=cache,target=/root/.gem
```
- Caches apt packages and gem downloads
- **Savings**: ~2-3 minutes on gem installs

## Expected Build Times

| Build Type | Before | After | Savings |
|------------|--------|-------|---------|
| **First build** | 14 min | 12 min | 2 min |
| **Cached build** | 14 min | 4-6 min | 8-10 min |
| **Config change only** | 14 min | 2-3 min | 11-12 min |

## Additional Optimizations (Optional)

### Option 1: Build Single Platform First
Build only `linux/amd64` first, then multi-arch later:

```yaml
# Fast build (amd64 only)
platforms: linux/amd64

# Full build (both platforms)
# platforms: linux/amd64,linux/arm64
```
**Savings**: ~6-7 minutes (ARM build is slower)

### Option 2: Parallel Gem Installation
```dockerfile
# Install gems in parallel
RUN --mount=type=cache,target=/root/.gem \
    gem install --jobs 4 \
    fluent-plugin-opensearch:1.1.4 \
    fluent-plugin-rewrite-tag-filter \
    fluent-plugin-record-modifier \
    ...
```
**Savings**: ~1-2 minutes

### Option 3: Use Pre-built Base Image
Create a custom base image with all dependencies:

```dockerfile
# Base image (build once, use many times)
FROM fluent/fluentd:v1.19-debian-1 as base
RUN apt-get update && apt-get install -y curl netcat-openbsd
RUN gem install fluent-plugin-opensearch -v 1.1.4

# Your image (fast builds)
FROM your-registry/fluentd-base:latest
COPY config/ /fluentd/etc/
```
**Savings**: ~8-10 minutes (only copy configs)

### Option 4: Reduce Multi-Arch Builds
Only build ARM when releasing:

```yaml
# On PR: amd64 only
platforms: ${{ github.event_name == 'pull_request' && 'linux/amd64' || 'linux/amd64,linux/arm64' }}
```
**Savings**: ~6-7 minutes on PRs

### Option 5: Use Larger GitHub Runners
Upgrade to larger runners (requires GitHub Team/Enterprise):

```yaml
runs-on: ubuntu-latest-8-cores  # 8 cores instead of 2
```
**Savings**: ~4-5 minutes

## Recommended Strategy

### For Development (Fast Iteration)
```yaml
platforms: linux/amd64
provenance: false
sbom: false
```
**Build time**: ~4-6 minutes

### For Production (Full Release)
```yaml
platforms: linux/amd64,linux/arm64
provenance: true  # For supply chain security
sbom: true        # For vulnerability scanning
```
**Build time**: ~8-10 minutes (with cache)

## Monitoring Build Times

Check build performance:

```bash
# View workflow runs
gh run list --workflow=build-wazuh-fluentd.yml

# View specific run details
gh run view <run-id> --log

# Check cache usage
gh cache list
```

## Cache Management

GitHub Actions cache has a 10GB limit per repository:

```bash
# List caches
gh cache list

# Delete old caches
gh cache delete <cache-id>

# Clear all caches (if needed)
gh cache delete --all
```

## Troubleshooting

### Cache Not Working?
1. Check if cache key changed
2. Verify `cache-from` and `cache-to` are set
3. Check GitHub Actions cache storage limit

### Build Still Slow?
1. Check if gem sources are slow (use mirrors)
2. Verify BuildKit is enabled
3. Check runner performance (GitHub status page)

### Out of Cache Space?
1. Delete old workflow caches
2. Use `cache-to: type=gha,mode=min` (smaller cache)
3. Reduce number of cached layers

## Best Practices

1. **Don't change base image frequently** - Invalidates all caches
2. **Group related RUN commands** - Fewer layers = better cache
3. **Put frequently changing files last** - COPY configs at the end
4. **Use .dockerignore** - Exclude unnecessary files
5. **Monitor cache hit rate** - Aim for >80% cache hits

## Current .dockerignore

```
# Exclude from build context
*.md
.git
.github
tmp-*
docs/
*.log
```

## Summary

**Current optimizations save ~8-10 minutes** on cached builds.

**Total possible savings**: Up to 12 minutes with all optimizations.

**Recommended**: Keep current setup, it's well-optimized! 🚀
