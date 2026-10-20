#!/usr/bin/env bash
# destroy.sh - Derruba todo o lab (podman ou docker)
set -euo pipefail

source "$(dirname "$0")/common.sh"

echo "[!] Parando e removendo containers..."
"$ENGINE" rm -f isp casa servidor >/dev/null 2>&1 || true

echo "[!] Removendo rede $NETWORK_NAME..."
"$ENGINE" network rm "$NETWORK_NAME" >/dev/null 2>&1 || true

echo "[+] Lab derrubado com sucesso ($ENGINE)."
