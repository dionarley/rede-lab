# Implementação e Testes de WireGuard

## Objetivo

Criar um túnel VPN criptografado entre o **PC de Casa** e o **Servidor**, simulando acesso remoto seguro através da rede do provedor (ISP) com NAT.

## Endereçamento WireGuard

| Host | IP WG | Chave Privada | Chave Pública | Porta |
|------|-------|---------------|---------------|-------|
| Servidor | 10.0.99.1/24 | `wg0` | pública do servidor | 51820 |
| Casa | 10.0.99.10/24 | `wg1` | pública da casa | 51821 |

## Configuração do Servidor (`wireguard/wg0.conf`)

```ini
[Interface]
Address = 10.0.99.1/24
ListenPort = 51820
PrivateKey = <chave-privada-servidor>

[Peer]
# Casa
PublicKey = <chave-publica-casa>
AllowedIPs = 10.0.99.10/32
PersistentKeepalive = 15
```

## Configuração do Cliente Casa (`wireguard/wg1.conf`)

```ini
[Interface]
Address = 10.0.99.10/24
PrivateKey = <chave-privada-casa>

[Peer]
# Servidor
PublicKey = <chave-publica-servidor>
Endpoint = 10.0.0.20:51820
AllowedIPs = 10.0.99.1/32
PersistentKeepalive = 15
```

## Como gerar as chaves

```bash
cd wireguard/keys

# Servidor
wg genkey | tee servidor.key | wg pubkey > servidor.pub

# Casa
wg genkey | tee casa.key | wg pubkey > casa.pub
```

Substitua os placeholders nos arquivos `.conf` pelas chaves geradas.

## Passo a passo de teste

1. Suba o lab (o deploy gera chaves automaticamente):
   ```bash
   ./scripts/deploy.sh
   ```

2. Verifique a interface WG no servidor:
   ```bash
   podman exec -it servidor wg
   ```

3. Verifique a interface WG na casa:
   ```bash
   podman exec -it casa wg
   ```

4. Teste ping através do túnel (a partir da casa):
   ```bash
   podman exec -it casa ping -c 4 10.0.99.1
   ```

5. Teste SSH através do túnel:
   ```bash
   ./scripts/test-ssh.sh
   ```

## Resultado esperado

- `podman exec -it servidor wg` mostra o peer `casa` com handshake recente.
- `ping 10.0.99.1` a partir da casa recebe resposta.
- Handshake WireGuard troca chaves e mantém o túnel ativo (PersistentKeepalive).

## Arquivo de registro

Veja `testes/resultado-wireguard.txt` após os testes.
