# DockerImage

Docker image of the PLaTOn sandbox.

## Overview

This repository is meant to separate the Docker Image from the Sanbox repository [PlatonOrg/sandbox](https://github.com/PlatonOrg/sandbox). The image is published to GitHub Container Registry (ghcr.io).

## Pulling the Image

```bash
docker pull ghcr.io/platonorg/sandbox-image:latest
```

### Available Tags

- `latest` - Always points to the most recent stable build from the `main` branch
- `dev` - Points to the most recent development build from the `develop` branch
- `YYYYMMDD` - Date-based tags (e.g., `20241201`)
- `<sha>` - Git commit SHA from when the image was built

