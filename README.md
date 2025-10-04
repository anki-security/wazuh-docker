# Wazuh Docker Images - Anki Security

Custom Wazuh Docker images for Anki Security infrastructure, based on the official [wazuh-docker](https://github.com/wazuh/wazuh-docker) repository.

## Current Version

**Wazuh 4.13.1** (Stable)

## Repository Structure

```
.
├── wazuh-manager/      # Wazuh Manager Dockerfile and config
├── wazuh-indexer/      # Wazuh Indexer Dockerfile and config (with S3 plugin)
├── wazuh-dashboard/    # Wazuh Dashboard Dockerfile and config
├── build-images.sh     # Build script for all images
├── build-images.yml    # Docker Compose build configuration
└── .github/workflows/  # CI/CD workflows
```

## Building Images

### Local Build

Build all images locally:

```bash
./build-images.sh
```

Build specific version:

```bash
./build-images.sh -v 4.13.1
```

Build with custom revision:

```bash
./build-images.sh -v 4.13.1 -r 2
```

### Available Options

- `-v, --version <ver>` - Wazuh version to build (default: 4.13.1)
- `-r, --revision <rev>` - Package revision (default: 1)
- `-f, --filebeat-module <ref>` - Filebeat module version (default: 0.4)
- `-d, --dev <ref>` - Development stage (e.g., rc1, beta1)
- `-h, --help` - Show help

## CI/CD

Images are built and pushed to GitHub Container Registry (GHCR) via **manual workflow trigger only**.

To trigger a build:
1. Go to https://github.com/anki-security/wazuh-docker/actions
2. Select "Build and Push Wazuh Docker Images"
3. Click "Run workflow"
4. Optionally specify a different version (default: 4.13.1)

### Published Images

All images are available at `ghcr.io/anki-security/`:

- `ghcr.io/anki-security/wazuh-manager:4.13.1`
- `ghcr.io/anki-security/wazuh-indexer:4.13.1` (includes S3 plugin)
- `ghcr.io/anki-security/wazuh-dashboard:4.13.1`

Each image is also tagged as `:latest`.

### Pulling Images

```bash
docker pull ghcr.io/anki-security/wazuh-manager:4.13.1
docker pull ghcr.io/anki-security/wazuh-indexer:4.13.1
docker pull ghcr.io/anki-security/wazuh-dashboard:4.13.1
```

## Making Changes

1. Modify Dockerfiles in respective directories (`wazuh-manager/`, `wazuh-indexer/`, etc.)
2. Update configuration files in `config/` subdirectories
3. Test locally with `./build-images.sh`
4. Commit and push changes
5. Manually trigger the GitHub Actions workflow to build and push new images

## Custom Features

### S3 Plugin for Wazuh Indexer

The `wazuh-indexer` image includes the `repository-s3` plugin pre-installed, allowing you to use S3-compatible storage for snapshots.

To configure S3 credentials at runtime, set these environment variables:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## Documentation

- [Official Wazuh Documentation](https://documentation.wazuh.com/current/)
- [Wazuh Docker Deployment Guide](https://documentation.wazuh.com/current/deployment-options/docker/index.html)

## License

Wazuh Docker Copyright (C) 2017, Wazuh Inc. (License GPLv2)

Forked and maintained by Anki Security.
