#!/usr/bin/env bash
# deploy.sh - Sobe todo o lab: rede, imagens, containers e VPN WireGuard
# Funciona com Podman ou Docker (defina CONTAINER_ENGINE no .env).
set -euo pipefail

source "$(dirname "$0")/common.sh"

echo "=================================================="
echo "  DEPLOY - Rede Lab ($ENGINE)"
echo "  SSH + WireGuard + NAT"
echo "=================================================="

# 1. Rede
echo "[1/6] Criando rede..."
./network/lab-network.sh

# 2. Build das imagens
echo "[2/6] Construindo imagens..."
"$ENGINE" build -t lab-isp -f isp/Dockerfile isp
"$ENGINE" build -t lab-casa -f casa/Dockerfile casa
"$ENGINE" build -t lab-servidor -f servidor/Dockerfile servidor

# 3. Remover containers antigos
echo "[3/6] Removendo containers antigos..."
"$ENGINE" rm -f isp casa servidor >/dev/null 2>&1 || true

# 4. Subir containers
echo "[4/6] Iniciando containers..."

"$ENGINE" run -d --name isp \
    --network "$NETWORK_NAME" \
    --ip "$ISP_IP" \
    --cap-add NET_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --sysctl net.ipv4.conf.all.forwarding=1 \
    lab-isp >/dev/null

"$ENGINE" run -d --name servidor \
    --network "$NETWORK_NAME" \
    --ip "$SERVIDOR_IP" \
    --cap-add NET_ADMIN \
    lab-servidor >/dev/null

"$ENGINE" run -d --name casa \
    --network "$NETWORK_NAME" \
    --ip "$CASA_IP" \
    --cap-add NET_ADMIN \
    lab-casa >/dev/null

echo "[4/6] Aguardando containers..."
sleep 3

# 5. VPN WireGuard (instância)
echo "[5/6] Subindo instância VPN (WireGuard)..."
./scripts/vpn.sh start

# 6. Teste rápido
echo "[6/6] Teste de conectividade SSH via túnel..."
if "$ENGINE" exec casa bash -c 'command -v sshpass >/dev/null 2>&1 || dnf -y install sshpass >/dev/null 2>&1; sshpass -p '"$SSH_PASS"' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 '"$SSH_USER"'@'"$WG_SERVIDOR_IP"' "echo SSH_OK" 2>/dev/null' | grep -q SSH_OK; then
    echo "    [OK] SSH via WireGuard funcionando."
else
    echo "    [AVISO] Teste SSH não confirmou. Veja ./scripts/test-ssh.sh"
fi

echo ""
echo "=================================================="
echo "  DEPLOY CONCLUÍDO ($ENGINE)"
echo "=================================================="
"$ENGINE" ps --format "{{.Names}}\t{{.Status}}" | grep -E '^(isp|casa|servidor)\b' || true
echo ""
echo "  ISP:      $ISP_IP (NAT/gateway)"
echo "  Servidor: $SERVIDOR_IP | WG $WG_SERVIDOR_IP:$WG_PORT/udp"
echo "  Casa:     $CASA_IP | WG $WG_CASA_IP"
echo ""
echo "  VPN:    ./scripts/vpn.sh {start|stop|status}"
echo "  SSH:    ./scripts/test-ssh.sh"
echo "  Derrubar: ./scripts/destroy.sh"
