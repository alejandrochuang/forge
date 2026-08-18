#!/usr/bin/env bash
set -euo pipefail
: "${ACR_LOGIN_SERVER:?debe estar definido}"

IMAGE_NAME="${ACR_LOGIN_SERVER}/forge-app"
VERSION="${VERSION:-0.1.0}"

echo "=== Vulnerabilidades (bloqueante: HIGH/CRITICAL con fix) ==="
# --ignore-unfixed: no fallamos por CVEs sin parche (no accionables).
# --exit-code 1: rompe el pipeline si hay HIGH/CRITICAL CON fix.
trivy image \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  --ignorefile .trivyignore \
  "${IMAGE_NAME}:${VERSION}"

echo "=== SBOM de la app (CycloneDX) ==="
syft "${IMAGE_NAME}:${VERSION}" -o cyclonedx-json=sbom-app.cdx.json
echo "SBOM: sbom-app.cdx.json"

echo "=== Componentes Python detectados en el SBOM ==="
grep -o '"name":"[^"]*"' sbom-app.cdx.json | head -20 || true
