# Zabbix MCP Server - OpenShift friendly
# Arranque: 1) corre test_server.py  2) si pasa, levanta start_server.py y se queda corriendo

FROM python:3.13-slim

WORKDIR /app

# Dependencias mínimas (por si alguna lib requiere compilar wheels)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Instala uv
RUN pip install --no-cache-dir uv

# Copia metadata primero para aprovechar cache de build
COPY pyproject.toml uv.lock ./

# Instala dependencias con uv (crea .venv)
RUN uv sync --no-editable

# Copia código
COPY src/ ./src/
COPY scripts/ ./scripts/
COPY config/ ./config/

# Crea entrypoint sin heredoc (compatible con buildah/podman)
RUN printf '%s\n' \
  '#!/usr/bin/env sh' \
  'set -eu' \
  '' \
  'echo "==> (1/2) Running preflight test: scripts/test_server.py"' \
  'uv run python scripts/test_server.py' \
  '' \
  'echo "==> (2/2) Starting server: scripts/start_server.py"' \
  'exec uv run python scripts/start_server.py' \
  > /app/entrypoint.sh \
  && chmod +x /app/entrypoint.sh

# OpenShift: UID arbitrario (grupo 0) y permisos compatibles
RUN chgrp -R 0 /app && chmod -R g=u /app

# Evita escrituras en /root en runtime
ENV HOME=/tmp \
    XDG_CACHE_HOME=/tmp/.cache \
    UV_CACHE_DIR=/tmp/uv-cache \
    PYTHONUNBUFFERED=1

EXPOSE 8000

CMD ["/app/entrypoint.sh"]
