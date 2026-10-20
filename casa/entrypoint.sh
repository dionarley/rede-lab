#!/usr/bin/env bash
# Entrypoint do PC de casa
set -euo pipefail

echo "[casa] Configurando gateway padrão via ISP (10.0.0.1)..."
ip route replace default via 10.0.0.1 || true

echo "[casa] PC de casa pronto."
echo "[casa] IPs:"
ip -brief addr

# Mantém o container vivo
exec tail -f /dev/null
