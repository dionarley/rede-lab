#!/usr/bin/env bash
# test-ssh.sh - Testa SSH da casa para o servidor pelo túnel WireGuard
set -euo pipefail

source "$(dirname "$0")/common.sh"

RESULT_FILE="testes/resultado-ssh.txt"

echo "=================================================="
echo "  TESTE SSH - Casa -> Servidor (via WireGuard)"
echo "  Engine: $ENGINE"
echo "=================================================="

{
    echo "Data: $(date)"
    echo "Engine: $ENGINE"
    echo "Origem: casa ($WG_CASA_IP)"
    echo "Destino: servidor ($WG_SERVIDOR_IP)"
    echo ""
} | tee "$RESULT_FILE"

echo "[1/3] Verificando containers..."
for c in isp casa servidor; do
    if ! "$ENGINE" ps --format '{{.Names}}' | grep -qx "$c"; then
        echo "ERRO: container '$c' não está rodando. Rode ./scripts/deploy.sh primeiro."
        echo "ERRO: container '$c' não está rodando." | tee -a "$RESULT_FILE"
        exit 1
    fi
done

echo "[2/3] Garantindo túnel WireGuard..."
./scripts/vpn.sh start 2>&1 | tee -a "$RESULT_FILE"

echo "[3/3] Testando SSH ($SSH_USER@$WG_SERVIDOR_IP:$SSH_PORT)..."
"$ENGINE" exec casa bash -c "command -v sshpass >/dev/null 2>&1 || dnf -y install sshpass >/dev/null 2>&1"
SSH_OUT=$("$ENGINE" exec casa bash -c "sshpass -p '$SSH_PASS' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -p '$SSH_PORT' '$SSH_USER'@'$WG_SERVIDOR_IP' 'echo SSH_VIA_WG_OK; whoami; uname -n' 2>&1" || true)
echo "$SSH_OUT" | tee -a "$RESULT_FILE"

echo ""
if echo "$SSH_OUT" | grep -q "SSH_VIA_WG_OK"; then
    echo "[OK] SSH via WireGuard funcionando."
    echo "RESULTADO: SUCESSO" | tee -a "$RESULT_FILE"
else
    echo "[FALHA] SSH não conectou."
    echo "RESULTADO: FALHA" | tee -a "$RESULT_FILE"
    exit 1
fi

echo ""
echo "Log salvo em: $RESULT_FILE"
