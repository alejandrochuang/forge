#!/usr/bin/env bash
set -euo pipefail
: "${ACR_LOGIN_SERVER:?debe estar definido}"

IMAGE_NAME="${ACR_LOGIN_SERVER}/forge-base"
VERSION="${VERSION:-0.1.0}"

echo "=== Escaneo de vulnerabilidades (bloqueante: HIGH/CRITICAL fixables) ==="
# --ignore-unfixed: no fallamos por CVEs sin parche disponible (no accionables).
# Falla el pipeline solo si hay HIGH/CRITICAL CON fix.
trivy image \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  --ignorefile .trivyignore \
  "${IMAGE_NAME}:${VERSION}"

echo "=== Generacion de SBOM (CycloneDX) ==="
syft "${IMAGE_NAME}:${VERSION}" -o cyclonedx-json=sbom.cdx.json
echo "SBOM escrito en sbom.cdx.json ($(wc -l < sbom.cdx.json) lineas)"
