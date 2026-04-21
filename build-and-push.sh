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

# Collect tags
TAGS=("-t" "${IMAGE}:${TAG}")
if [ "${TAG}" != "latest" ]; then
    TAGS+=("-t" "${IMAGE}:latest")
fi

# Determine push flag
PUSH_FLAG=""
if [ "${DRY_RUN:-0}" != "1" ]; then
    PUSH_FLAG="--push"
fi

# Build from repo root so COPY requirements.txt works
# Use buildx to produce a multi-arch image (amd64 + arm64)
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -f "${SCRIPT_DIR}/.devcontainer/Dockerfile" \
    "${TAGS[@]}" \
    ${PUSH_FLAG} \
    "${SCRIPT_DIR}"

if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "==> DRY_RUN set, built but did not push"
else
    echo "==> Done! Image pushed: ${IMAGE}:${TAG}"
fi
