# Parallel vs Sequential Build Workflows

## Overview

We have two workflow options for building Docker images:

1. **`build-and-push.yml`** - Sequential (current)
2. **`build-and-push-parallel.yml`** - Parallel (NEW, faster)

## Performance Comparison

### Sequential Build (Current)
```
┌─────────────────────────────────────────┐
│ Version Management (30s)                │
├─────────────────────────────────────────┤
│ Build wazuh-manager (8-10 min)         │
├─────────────────────────────────────────┤
│ Build wazuh-indexer (5-7 min)          │
├─────────────────────────────────────────┤
│ Build wazuh-dashboard (5-7 min)        │
├─────────────────────────────────────────┤
│ Tag & Push (2-3 min)                    │
├─────────────────────────────────────────┤
│ Commit & Summary (30s)                  │
└─────────────────────────────────────────┘
Total: ~20-25 minutes
```

### Parallel Build (NEW)
```
┌─────────────────────────────────────────┐
│ Version Management (30s)                │
├─────────────────────────────────────────┤
│ ┌─────────────────┐ ┌─────────────────┐│
│ │ wazuh-manager   │ │ wazuh-indexer   ││
│ │ (8-10 min)      │ │ (5-7 min)       ││
│ │                 │ │                 ││
│ │                 │ │ wazuh-dashboard ││
│ │                 │ │ (5-7 min)       ││
│ └─────────────────┘ └─────────────────┘│
├─────────────────────────────────────────┤
│ Commit & Summary (30s)                  │
└─────────────────────────────────────────┘
Total: ~10-12 minutes (60% faster!)
```

## Key Differences

### Sequential (`build-and-push.yml`)
- ✅ Simple, single job
- ✅ Easy to debug
- ❌ Slow (20-25 minutes)
- ❌ Wastes GitHub Actions minutes
- Uses: `./build-images.sh` script

### Parallel (`build-and-push-parallel.yml`)
- ✅ **60-70% faster** (10-12 minutes)
- ✅ 3 runners build simultaneously
- ✅ GitHub Actions cache optimization
- ✅ Better resource utilization
- ❌ Slightly more complex
- Uses: `docker/build-push-action@v5` with matrix

## Architecture

### Parallel Workflow Structure

```yaml
jobs:
  1. version:          # Runs first (30s)
     - Read VERSION.json
     - Bump version if needed
     - Output versions for other jobs
     
  2. build:            # Runs in parallel (10 min)
     strategy:
       matrix:
         - wazuh-manager    ⚡ Runner 1
         - wazuh-indexer    ⚡ Runner 2
         - wazuh-dashboard  ⚡ Runner 3
     - Build & push each image
     - Use GitHub Actions cache
     
  3. finalize:         # Runs after build (30s)
     - Commit VERSION.json
     - Create git tag
     
  4. summary:          # Runs after build (10s)
     - Generate summary
```

## Features

### Both Workflows Support:
- ✅ Version bumping (major/minor/patch/none)
- ✅ Push to GHCR
- ✅ Git tagging
- ✅ Build summaries

### Parallel Workflow Adds:
- ✅ **GitHub Actions cache** (faster rebuilds)
- ✅ **Matrix strategy** (3 parallel runners)
- ✅ **Artifact sharing** (VERSION.json between jobs)
- ✅ **Dependency graph** (proper job ordering)

## Usage

### Sequential Build
```bash
# GitHub Actions UI
Actions → Build and Push Wazuh Docker Images → Run workflow
```

### Parallel Build
```bash
# GitHub Actions UI
Actions → Build and Push Wazuh Docker Images (Parallel) → Run workflow
```

## Migration Guide

### Option 1: Replace Current Workflow
```bash
# Backup old workflow
mv .github/workflows/build-and-push.yml .github/workflows/build-and-push.yml.backup

# Rename parallel to main
mv .github/workflows/build-and-push-parallel.yml .github/workflows/build-and-push.yml

# Commit
git add .github/workflows/
git commit -m "feat: switch to parallel build workflow (60% faster)"
git push
```

### Option 2: Keep Both (Recommended)
- Keep both workflows
- Use **parallel** for regular builds
- Use **sequential** for debugging/troubleshooting

## Cost Savings

### GitHub Actions Minutes

**Sequential:**
- 25 minutes × 1 runner = **25 minutes**

**Parallel:**
- 30s (version) × 1 runner = 0.5 min
- 10 min (build) × 3 runners = 30 min
- 30s (finalize) × 1 runner = 0.5 min
- **Total: 31 minutes** (but completes in 11 minutes wall-clock time)

**Trade-off:**
- Uses 6 more runner-minutes
- But saves 14 minutes of **your time**
- Better for CI/CD pipelines (faster feedback)

### For Free Tier (2000 min/month):
- Sequential: ~80 builds/month
- Parallel: ~64 builds/month
- **Worth it for the speed!**

## Cache Benefits

The parallel workflow uses GitHub Actions cache:

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

**First build:** 10-12 minutes
**Subsequent builds (with cache):** 3-5 minutes ⚡

## Recommendations

### Use Parallel Workflow When:
- ✅ Building for production
- ✅ CI/CD pipelines
- ✅ Regular releases
- ✅ Time is critical

### Use Sequential Workflow When:
- ✅ Debugging build issues
- ✅ Testing build script changes
- ✅ Learning/understanding the build process

## Testing

Test the parallel workflow:

```bash
# Trigger via GitHub Actions UI
# Select: bump_type = "none"
# Check: push_images = false (for testing)

# Monitor:
# - All 3 build jobs start simultaneously
# - Check logs for each image
# - Verify timing improvements
```

## Troubleshooting

### If Parallel Build Fails:

1. **Check individual job logs** (each image has separate log)
2. **Verify build-args** are passed correctly
3. **Test with sequential workflow** to isolate issue
4. **Check cache** - clear if corrupted:
   ```bash
   # In GitHub Actions UI:
   # Settings → Actions → Caches → Delete all caches
   ```

## Future Improvements

Potential optimizations:

1. **Add Fluentd to matrix** (4 parallel builds)
2. **Multi-platform builds** (amd64 + arm64)
3. **Build only changed images** (detect changes)
4. **Separate workflows** per image (ultimate parallelization)

## Conclusion

**Recommendation: Use the parallel workflow!**

- ⚡ **60% faster** (10 min vs 25 min)
- 🎯 Better for CI/CD
- 💰 Slightly more runner-minutes but worth it
- 🚀 Includes cache optimization

The sequential workflow remains available for debugging.
