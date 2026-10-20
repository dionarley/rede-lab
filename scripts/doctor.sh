#!/usr/bin/env bash
# doctor.sh - verifica dependências e saúde do lab (podman ou docker)
set -uo pipefail

source "$(dirname "$0")/common.sh"

echo "=================================================="
echo "  DOCTOR - Rede Lab"
echo "=================================================="

echo "[+] Engine detectado: $ENGINE"
"$ENGINE" --version 2>/dev/null || echo "    ERRO: engine não respondeu"

echo ""
echo "[+] Containers esperados:"
for c in isp casa servidor; do
    status="$("$ENGINE" inspect -f '{{.State.Status}}' "$c" 2>/dev/null || echo "ausente")"
    printf '    %-10s %s\n' "$c" "$status"
done

echo ""
echo "[+] Rede $NETWORK_NAME:"
if engine_network_exists "$NETWORK_NAME"; then
    echo "    OK"
else
    echo "    AUSENTE (rode ./network/lab-network.sh)"
fi

echo ""
echo "[+] VPN WireGuard:"
if "$ENGINE" exec servidor wg show wg0 >/dev/null 2>&1; then
    echo "    wg0 (servidor): ativo"
else
    echo "    wg0 (servidor): inativo"
fi
if "$ENGINE" exec casa wg show wg1 >/dev/null 2>&1; then
    echo "    wg1 (casa): ativo"
else
    echo "    wg1 (casa): inativo"
fi

echo ""
echo "[+] SSH no servidor:"
if "$ENGINE" exec servidor pgrep -x sshd >/dev/null 2>&1; then
    echo "    sshd: rodando"
else
    echo "    sshd: parado"
fi

echo ""
echo "[+] Ferramentas no host:"
for t in git bash; do
    if command -v "$t" >/dev/null 2>&1; then
        printf '    %-8s OK\n' "$t"
    else
        printf '    %-8s AUSENTE\n' "$t"
    fi
done
