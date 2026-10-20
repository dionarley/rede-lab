#!/usr/bin/env bash
# Cria a rede bridge usada pelo lab (funciona com podman ou docker)
set -euo pipefail

source "$(dirname "$0")/../scripts/common.sh"

echo "[+] Engine: $ENGINE"
echo "[+] Criando rede: $NETWORK_NAME ($SUBNET, gw $GATEWAY)"

if engine_network_exists "$NETWORK_NAME"; then
    echo "[!] Rede $NETWORK_NAME já existe. Removendo..."
    "$ENGINE" network rm "$NETWORK_NAME" >/dev/null 2>&1 || true
fi

"$ENGINE" network create \
    --driver bridge \
    --subnet "$SUBNET" \
    --gateway "$GATEWAY" \
    "$NETWORK_NAME"

echo "[+] Rede $NETWORK_NAME criada com sucesso."
