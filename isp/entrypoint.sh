#!/usr/bin/env bash
# Entrypoint do ISP: ativa IP forwarding e NAT (MASQUERADE)
set -euo pipefail

echo "[isp] Ativando IP forwarding..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.all.forwarding=1 >/dev/null 2>&1 || true

echo "[isp] Configurando NAT (MASQUERADE) na interface de saída..."
# Tenta iptables (pode falhar em rootless sem módulos do kernel; o lab SSH+WG funciona pela bridge direta)
iptables -t nat -F POSTROUTING 2>/dev/null || true
iptables -F FORWARD 2>/dev/null || true
iptables -A FORWARD -j ACCEPT 2>/dev/null || true
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
iptables-nft -t nat -A POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
echo "[isp] ISP pronto. (NAT via iptables depende de módulos do kernel no host; em rootless pode ser simulado.)"
echo "[isp] Mantendo container em execução..."

# Mantém o container vivo
exec tail -f /dev/null
