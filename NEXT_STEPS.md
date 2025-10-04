# Next Steps - Wazuh Docker Repository Setup

## ✅ Completed

1. **Repository Restructured**
   - Moved `build-docker-images/` content to repository root
   - Removed unnecessary directories (single-node, multi-node, docs, tools, etc.)
   - Cleaned up old workflows and test scripts

2. **Version Updated**
   - Set to Wazuh 4.13.1 (stable)
   - Updated `VERSION.json`, `build-images.sh`, and `.env`

3. **CI/CD Created**
   - New GitHub Actions workflow: `.github/workflows/build-and-push.yml`
   - Automatically builds and pushes to GitHub Container Registry (GHCR)
   - Triggers on push to main or manual workflow dispatch

## 🚀 What You Need to Do Now

### 1. Delete Remote Branches (Optional but Recommended)

All the old version branches from upstream are still in your fork. To clean them up:

```bash
# Review what will be deleted
git branch -r | grep -v 'HEAD' | grep -v 'main'

# If you're sure, run the cleanup (this will delete them from GitHub)
# Note: This is destructive! Make sure you want to do this.
git branch -r | grep -v 'HEAD' | grep -v 'main' | sed 's/origin\///' | xargs -I {} git push origin --delete {}

# Clean up local tracking branches
git fetch --prune
```

### 2. Commit and Push Changes

```bash
# Stage all changes
git add -A

# Commit
git commit -m "Restructure repository for Anki Security - Wazuh 4.13.1

- Move build-docker-images to root
- Remove deployment examples and docs
- Update to version 4.13.1
- Add GitHub Actions workflow for GHCR
- Update README with new structure"

# Push to your fork
git push origin main
```

### 3. Manually Trigger GitHub Actions

After pushing:

1. Go to https://github.com/anki-security/wazuh-docker/actions
2. Click on "Build and Push Wazuh Docker Images"
3. Click "Run workflow" button
4. Optionally change the version (default: 4.13.1)
5. Click "Run workflow" to start the build
6. It will build 3 images (manager, indexer, dashboard) and push them to GHCR

### 4. Make Images Public (Important!)

By default, GHCR packages are private. To make them public:

1. Go to https://github.com/orgs/anki-security/packages
2. Find each package:
   - `wazuh-manager`
   - `wazuh-indexer`
   - `wazuh-dashboard`
3. Click on each package → Settings → Change visibility → Public

### 5. Test Pulling Images

Once the workflow completes and images are public:

```bash
docker pull ghcr.io/anki-security/wazuh-manager:4.13.1
docker pull ghcr.io/anki-security/wazuh-indexer:4.13.1
docker pull ghcr.io/anki-security/wazuh-dashboard:4.13.1
```

## 📝 Repository Structure

```
wazuh-docker/
├── .github/
│   └── workflows/
│       └── build-and-push.yml    # CI/CD workflow (manual trigger only)
├── wazuh-manager/                # Manager Dockerfile + config
├── wazuh-indexer/                # Indexer Dockerfile + config (with S3 plugin)
├── wazuh-dashboard/              # Dashboard Dockerfile + config
├── build-images.sh               # Build script
├── build-images.yml              # Docker Compose build config (3 images)
├── VERSION.json                  # Version tracking
├── .env                          # Environment variables
└── README.md                     # Documentation
```

## 🔧 Making Changes

To customize the images:

1. Edit Dockerfiles in `wazuh-*/Dockerfile`
2. Modify configs in `wazuh-*/config/`
3. Test locally: `./build-images.sh`
4. Commit and push - CI/CD will rebuild automatically

## 🎯 Manual Workflow Trigger

You can also manually trigger builds:

1. Go to https://github.com/anki-security/wazuh-docker/actions
2. Select "Build and Push Wazuh Docker Images"
3. Click "Run workflow"
4. Optionally specify a different version

## 📦 Published Images

After the first successful run, images will be available at:

- `ghcr.io/anki-security/wazuh-manager:4.13.1` (and `:latest`)
- `ghcr.io/anki-security/wazuh-indexer:4.13.1` (and `:latest`) - **includes S3 plugin**
- `ghcr.io/anki-security/wazuh-dashboard:4.13.1` (and `:latest`)

## ⚠️ Important Notes

- The workflow uses `GITHUB_TOKEN` which is automatically provided by GitHub Actions
- No additional secrets needed for GHCR
- **Images are built ONLY via manual workflow trigger** (not automatic on push)
- Build takes ~15-30 minutes depending on GitHub Actions runners
- The `wazuh-indexer` image includes the S3 plugin pre-installed for snapshot backups
