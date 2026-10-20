#!/usr/bin/env bash
# Entrypoint do Servidor: inicia SSHD e mantém vivo
set -euo pipefail

echo "[servidor] Iniciando SSH..."
/usr/sbin/sshd

echo "[servidor] Configurando gateway padrão via ISP (10.0.0.1)..."
ip route replace default via 10.0.0.1 || true

echo "[servidor] Servidor pronto."
echo "[servidor] IPs:"
ip -brief addr

# Mantém o container vivo
exec tail -f /dev/null
