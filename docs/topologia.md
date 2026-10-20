# Topologia de Rede

## Cenário simulado

Provedor de Serviço (ISP) ---- NAT ---- Internet pública simulada ---- PC de Casa
                                                |
                                            Servidor (SSH + WireGuard)

## Componentes

### ISP (container `isp`)
- Função: gateway, NAT (MASQUERADE) e IP forwarding.
- Interface WAN: `10.0.0.1/24`
- Encaminha tráfego entre `casa`, `servidor` e a rede externa simulada.
- Faz SNAT dos pacotes que saem dos clientes.

### PC de Casa (container `casa`)
- Função: cliente final.
- Interface LAN: `192.168.10.10/24` (gateway `10.0.0.1`)
- Interface WAN: `10.0.0.10/24`
- Cliente WireGuard: `10.0.99.10`
- Cliente SSH: conecta ao servidor via túnel WG.

### Servidor (container `servidor`)
- Função: servidor de serviços.
- Interface LAN: `192.168.10.20/24` (gateway `10.0.0.1`)
- Interface WAN: `10.0.0.20/24`
- Servidor WireGuard: `10.0.99.1` (escuta na porta UDP 51820)
- Servidor SSH: porta 22 (acessível via IP do túnel `10.0.99.1`)

## Fluxo de tráfego esperado

1. Casa gera pacote SSH com destino `10.0.99.1` (servidor via WG).
2. Pacote é encapsulado pelo WireGuard (UDP 51820) e enviado para `10.0.0.20`.
3. ISP faz NAT/forwarding se necessário e entrega ao servidor.
4. Servidor decapsula o WG, recebe o SSH na porta 22 e responde.
5. Resposta volta pelo mesmo caminho até a casa.

## Portas

| Serviço | Container | Porta | Protocolo |
|---------|-----------|-------|-----------|
| SSH     | servidor  | 22    | TCP       |
| WireGuard | servidor | 51820 | UDP       |
| WireGuard | casa     | 51821 | UDP       |
