#!/usr/bin/env bash
set -euo pipefail

# Genera requirements.txt con versiones exactas + hashes de TODAS las
# dependencias (incluidas transitivas). --generate-hashes es lo que da
# la garantia de integridad: pip rechazara cualquier paquete cuyo hash
# no coincida.
pip-compile --generate-hashes --output-file=requirements.txt requirements.in
pip-compile --generate-hashes --output-file=requirements-dev.txt requirements-dev.in

echo "Dependencias pinneadas con hashes:"
echo "  requirements.txt     -> $(grep -c '^[a-zA-Z]' requirements.txt) paquetes directos + transitivas"
echo "  requirements-dev.txt -> desarrollo (no va en la imagen)"
