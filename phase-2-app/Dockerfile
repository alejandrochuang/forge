# ---- Hereda de la base endurecida (Fase 1) ----
# En produccion se fija por DIGEST para inmutabilidad total; usamos tag aqui
# por legibilidad y lo endurecemos a digest en la Seccion 9.
ARG ACR_LOGIN_SERVER
FROM ${ACR_LOGIN_SERVER}/forge-base@sha256:3696a2a780259230aad052eeb19a0b8d72a53863029479e932c823b5ef8626d2

# ---- Metadatos OCI de la app (trazabilidad) ----
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION="0.1.0"
LABEL org.opencontainers.image.title="securityscanservice" \
      org.opencontainers.image.description="FastAPI service running nmap and trivy scans" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.base.name="forge-base:0.1.0" \
      org.opencontainers.image.base.digest="sha256:3696a2a780259230aad052eeb19a0b8d72a53863029479e932c823b5ef8626d2"

WORKDIR /app

# ---- Instala SOLO deps de produccion, con verificacion de hash ----
# --require-hashes obliga a que CADA paquete tenga hash (falla si falta alguno).
COPY requirements.txt .
RUN pip install --no-cache-dir --require-hashes -r requirements.txt

# ---- Copia el codigo de la app ----
COPY app/ ./app/

EXPOSE 8000

# ---- Healthcheck: sondea el endpoint raiz usando urllib (sin deps extra) ----
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python3.11", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/').status==200 else 1)"]

# ---- La base ya define USER nonroot (uid 65532). NO reintroducimos root. ----
ENTRYPOINT ["python3.11", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
