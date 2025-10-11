# Wazuh Manager Dependencies

This directory contains external dependencies that are bundled with the Docker image to avoid relying on external APIs during build time.

## Files

### s6-overlay-amd64.tar.gz
- **Version**: v2.2.0.3
- **Source**: https://github.com/just-containers/s6-overlay/releases/tag/v2.2.0.3
- **Size**: ~1.8 MB
- **Purpose**: Process supervisor for Docker containers
- **License**: ISC License

## Why Local Dependencies?

**Problem**: GitHub releases API can be unreliable during CI/CD builds:
- Rate limiting
- Temporary outages
- Network issues
- Returns HTML error pages instead of files

**Solution**: Bundle dependencies in the repository for:
- ✅ Reliable builds
- ✅ Faster build times (no external downloads)
- ✅ Reproducible builds
- ✅ Works in air-gapped environments

## Updating Dependencies

To update s6-overlay to a new version:

```bash
# Download new version
VERSION=v2.2.0.3
curl -L https://github.com/just-containers/s6-overlay/releases/download/${VERSION}/s6-overlay-amd64.tar.gz \
  -o wazuh-manager/dependencies/s6-overlay-amd64.tar.gz

# Verify it's a valid gzip
file wazuh-manager/dependencies/s6-overlay-amd64.tar.gz

# Update Dockerfile ARG if version changed
# ARG S6_VERSION=v2.2.0.3

# Commit
git add wazuh-manager/dependencies/s6-overlay-amd64.tar.gz
git commit -m "chore: update s6-overlay to ${VERSION}"
```

## Size Considerations

The s6-overlay tarball is ~1.8 MB. This is acceptable because:
- Only affects repository size, not image size (extracted during build)
- Significantly improves build reliability
- Eliminates external dependency during builds
- Standard practice for production Docker images

## Alternative Approaches

If repository size becomes a concern:
1. **Git LFS**: Use Git Large File Storage
2. **Artifact Registry**: Store in GitHub Packages or similar
3. **Multi-stage build**: Download in builder stage, copy to final image

For now, direct inclusion is the simplest and most reliable approach.
