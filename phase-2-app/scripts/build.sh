#!/usr/bin/env bash
set -euo pipefail
: "${ACR_LOGIN_SERVER:?debe estar definido}"

IMAGE_NAME="${ACR_LOGIN_SERVER}/forge-app"
VERSION="${VERSION:-0.1.0}"
BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
VCS_REF="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"

echo "Construyendo ${IMAGE_NAME}:${VERSION}"

docker buildx build \
  --file Dockerfile \
  --build-arg ACR_LOGIN_SERVER="${ACR_LOGIN_SERVER}" \
  --build-arg BUILD_DATE="${BUILD_DATE}" \
  --build-arg VCS_REF="${VCS_REF}" \
  --build-arg VERSION="${VERSION}" \
  --tag "${IMAGE_NAME}:${VERSION}" \
  --tag "${IMAGE_NAME}:latest" \
  --provenance=true \
  --load \
  .

echo "Imagen de app construida: ${IMAGE_NAME}:${VERSION}"
