#!/usr/bin/env bash
# vpn.sh - gerencia a instância VPN WireGuard do lab
# Uso: ./scripts/vpn.sh {start|stop|restart|status}
set -euo pipefail

source "$(dirname "$0")/common.sh"

SERVIDOR_CT="servidor"
CASA_CT="casa"

ensure_keys() {
    "$ENGINE" exec "$SERVIDOR_CT" bash -c 'mkdir -p /etc/wireguard; [ -f /etc/wireguard/servidor.key ] || (wg genkey | tee /etc/wireguard/servidor.key | wg pubkey > /etc/wireguard/servidor.pub)'
    "$ENGINE" exec "$CASA_CT" bash -c 'mkdir -p /etc/wireguard; [ -f /etc/wireguard/casa.key ] || (wg genkey | tee /etc/wireguard/casa.key | wg pubkey > /etc/wireguard/casa.pub)'
    mkdir -p wireguard/keys
    "$ENGINE" exec "$SERVIDOR_CT" cat /etc/wireguard/servidor.key > wireguard/keys/servidor.key 2>/dev/null || true
    "$ENGINE" exec "$SERVIDOR_CT" cat /etc/wireguard/servidor.pub > wireguard/keys/servidor.pub 2>/dev/null || true
    "$ENGINE" exec "$CASA_CT" cat /etc/wireguard/casa.key > wireguard/keys/casa.key 2>/dev/null || true
    "$ENGINE" exec "$CASA_CT" cat /etc/wireguard/casa.pub > wireguard/keys/casa.pub 2>/dev/null || true
}

vpn_start() {
    echo "[vpn] Garantindo chaves..."
    ensure_keys

    local SERVIDOR_PUB CASA_PUB
    SERVIDOR_PUB="$("$ENGINE" exec "$SERVIDOR_CT" cat /etc/wireguard/servidor.pub)"
    CASA_PUB="$("$ENGINE" exec "$CASA_CT" cat /etc/wireguard/casa.pub)"

    echo "[vpn] Subindo túnel no servidor (${WG_SERVIDOR_IP}:${WG_PORT})..."
    "$ENGINE" exec "$SERVIDOR_CT" bash -c "
        ip link del wg0 2>/dev/null || true
        ip link add wg0 type wireguard
        ip address add ${WG_SERVIDOR_IP}/24 dev wg0
        wg set wg0 private-key /etc/wireguard/servidor.key listen-port ${WG_PORT}
        wg set wg0 peer '${CASA_PUB}' allowed-ips ${WG_CASA_IP}/32 persistent-keepalive ${WG_KEEPALIVE}
        ip link set wg0 up
    "

    echo "[vpn] Subindo túnel na casa (${WG_CASA_IP})..."
    "$ENGINE" exec "$CASA_CT" bash -c "
        ip link del wg1 2>/dev/null || true
        ip link add wg1 type wireguard
        ip address add ${WG_CASA_IP}/24 dev wg1
        wg set wg1 private-key /etc/wireguard/casa.key
        wg set wg1 peer '${SERVIDOR_PUB}' allowed-ips ${WG_SERVIDOR_IP}/32 endpoint ${SERVIDOR_IP}:${WG_PORT} persistent-keepalive ${WG_KEEPALIVE}
        ip link set wg1 up
    "

    echo "[vpn] VPN ativa."
    vpn_status
}

vpn_stop() {
    echo "[vpn] Derrubando túneis..."
    "$ENGINE" exec "$CASA_CT" bash -c 'ip link del wg1 2>/dev/null || true' || true
    "$ENGINE" exec "$SERVIDOR_CT" bash -c 'ip link del wg0 2>/dev/null || true' || true
    echo "[vpn] VPN parada."
}

vpn_status() {
    echo "=================================================="
    echo "  STATUS DA VPN - WireGuard"
    echo "=================================================="
    echo "--- Servidor (wg0) ---"
    "$ENGINE" exec "$SERVIDOR_CT" wg show wg0 2>/dev/null || echo "wg0 não configurado"
    echo ""
    echo "--- Casa (wg1) ---"
    "$ENGINE" exec "$CASA_CT" wg show wg1 2>/dev/null || echo "wg1 não configurado"
}

vpn_test() {
    echo "[vpn] Testando conectividade pelo túnel..."
    echo "--- Ping ${WG_SERVIDOR_IP} a partir da casa ---"
    "$ENGINE" exec "$CASA_CT" ping -c 4 -W 2 "$WG_SERVIDOR_IP" \
        || echo "(ping pode falhar em rootless sem CAP_NET_RAW; SSH usa TCP e deve funcionar)"
    echo "--- SSH ${SSH_USER}@${WG_SERVIDOR_IP} ---"
    "$ENGINE" exec "$CASA_CT" bash -c "command -v sshpass >/dev/null 2>&1 || dnf -y install sshpass >/dev/null 2>&1; sshpass -p '${SSH_PASS}' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 '${SSH_USER}'@'${WG_SERVIDOR_IP}' 'echo SSH_VIA_WG_OK'"
}

case "${1:-}" in
    start)   vpn_start ;;
    stop)    vpn_stop ;;
    restart) vpn_stop; vpn_start ;;
    status)  vpn_status ;;
    test)    vpn_test ;;
    *)
        echo "Uso: $0 {start|stop|restart|status|test}"
        exit 1
        ;;
esac
