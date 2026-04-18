#!/bin/bash
# ============================================================================
# Build and push the devcontainer image to DockerHub
# 
# This script builds the Docker image with ALL dependencies pre-installed
# (Python packages, Azure CLI, GitHub CLI, azd) so that devcontainer
# launch time is near-instant (no feature installs at startup).
#
# Usage:
#   ./build-and-push.sh                    # build and push :latest
#   ./build-and-push.sh v1.2               # build and push :v1.2 + :latest
#   DRY_RUN=1 ./build-and-push.sh          # build only, no push
#
# Prerequisites:
#   - Docker (or Docker Desktop) running
#   - Logged into DockerHub: docker login
# ============================================================================

set -euo pipefail

IMAGE="aimconsulting/agentic-ai-immersion"
TAG="${1:-latest}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Building image: ${IMAGE}:${TAG}"
echo "    Context: ${SCRIPT_DIR}"
echo "    Dockerfile: ${SCRIPT_DIR}/.devcontainer/Dockerfile"

# Build from repo root so COPY requirements.txt works
docker build \
    -f "${SCRIPT_DIR}/.devcontainer/Dockerfile" \
    -t "${IMAGE}:${TAG}" \
    "${SCRIPT_DIR}"

# Also tag as latest if a version tag was provided
if [ "${TAG}" != "latest" ]; then
    docker tag "${IMAGE}:${TAG}" "${IMAGE}:latest"
fi

if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "==> DRY_RUN set, skipping push"
    exit 0
fi

echo "==> Pushing ${IMAGE}:${TAG}"
docker push "${IMAGE}:${TAG}"

if [ "${TAG}" != "latest" ]; then
    echo "==> Pushing ${IMAGE}:latest"
    docker push "${IMAGE}:latest"
fi

echo "==> Done! Image pushed: ${IMAGE}:${TAG}"
