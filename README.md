# 🛡️ Rede Lab - SSH + WireGuard com Podman/Docker

Lab de rede pequena simulando:

- **ISP (Provedor de Serviço)** com NAT e IP forwarding
- **PC de Casa** (cliente SSH + cliente WireGuard)
- **Servidor** (servidor SSH + servidor WireGuard)

Suporta **Podman** e **Docker** (detecção automática via `.env`).

## 📁 Estrutura

```
rede-lab/
├── .env                      # configuração (engine, IPs, portas)
├── .env.example              # modelo de configuração
├── README.md
├── docs/
│   ├── topologia.md          # rede e endereçamento
│   ├── ssh.md                # implementação e testes de SSH
│   └── wireguard.md          # implementação e testes de WireGuard
├── network/
│   └── lab-network.sh        # criação da rede bridge
├── isp/                      # gateway / provedor (NAT)
│   ├── Dockerfile
│   └── entrypoint.sh
├── casa/                     # PC de casa (cliente)
│   ├── Dockerfile
│   ├── entrypoint.sh
│   └── ssh_config
├── servidor/                 # servidor interno
│   ├── Dockerfile
│   ├── entrypoint.sh
│   └── sshd_config
├── wireguard/                # configs de referência
│   ├── wg0.conf
│   ├── wg1.conf
│   └── keys/                 # chaves geradas (ignoradas pelo git)
├── scripts/
│   ├── common.sh             # carrega .env + detecta engine
│   ├── deploy.sh             # sobe todo o lab
│   ├── destroy.sh            # derruba todo o lab
│   ├── vpn.sh                # gerencia a instância VPN
│   └── test-ssh.sh           # testa SSH pelo túnel
└── testes/
    ├── resultado-ssh.txt
    └── resultado-wireguard.txt
```

## ⚙️ Configuração (`.env`)

```bash
# engine: auto | podman | docker
CONTAINER_ENGINE=auto

NETWORK_NAME=lab-net
SUBNET=10.0.0.0/24
GATEWAY=10.0.0.1

ISP_IP=10.0.0.1
CASA_IP=10.0.0.10
SERVIDOR_IP=10.0.0.20

WG_SERVIDOR_IP=10.0.99.1
WG_CASA_IP=10.0.99.10
WG_PORT=51820
WG_KEEPALIVE=15

SSH_USER=labuser
SSH_PASS=labpass
SSH_PORT=22
```

Copie o modelo e ajuste se necessário:

```bash
cp .env.example .env
```

Para forçar um engine específico:

```bash
CONTAINER_ENGINE=docker ./scripts/deploy.sh
# ou
CONTAINER_ENGINE=podman ./scripts/deploy.sh
```

## 🚀 Como usar

### Pré-requisitos
- [Podman](https://podman.io/) **ou** [Docker](https://www.docker.com/)
- `bash`

### 1. Subir o lab

```bash
chmod +x network/lab-network.sh scripts/*.sh
./scripts/deploy.sh
```

### 2. Gerenciar a VPN

```bash
./scripts/vpn.sh start    # sobe o túnel WireGuard
./scripts/vpn.sh status   # mostra handshake/peers
./scripts/vpn.sh stop     # derruba o túnel
./scripts/vpn.sh restart  # reinicia o túnel
```

### 3. Testar SSH

```bash
./scripts/test-ssh.sh
```

Saída esperada:

```
SSH_VIA_WG_OK
labuser
```

### 4. Diagnóstico

```bash
./scripts/doctor.sh
```

### 5. Derrubar tudo

```bash
./scripts/destroy.sh
```

## 📋 Endereçamento

| Host | WAN/ISP (10.0.0.0/24) | WireGuard (10.0.99.0/24) | Papel |
|------|-----------------------|--------------------------|-------|
| ISP  | 10.0.0.1 (gateway NAT) | - | Provedor, NAT, forwarding |
| Casa | 10.0.0.10 | 10.0.99.10 | PC de casa, cliente SSH/WG |
| Servidor | 10.0.0.20 | 10.0.99.1 | Servidor SSH/WG (51820/udp) |

## ✅ Resultados dos testes

- **WireGuard**: handshake concluído nos dois lados, túnel ativo com keepalive.
- **SSH**: `ssh labuser@10.0.99.1` autenticado com sucesso via túnel.

Detalhes em [`testes/resultado-ssh.txt`](testes/resultado-ssh.txt) e
[`testes/resultado-wireguard.txt`](testes/resultado-wireguard.txt).

## 📄 Documentação

- [`docs/topologia.md`](docs/topologia.md)
- [`docs/ssh.md`](docs/ssh.md)
- [`docs/wireguard.md`](docs/wireguard.md)
- [`docs/vpn-operacao.md`](docs/vpn-operacao.md)
- [`docs/engines.md`](docs/engines.md)

## 🔐 Segurança

Este é um lab educacional. As credenciais (`labuser/labpass`) e a opção
`StrictHostKeyChecking no` são intencionais para testes e **não devem** ser
usadas em produção. As chaves WireGuard são geradas em tempo de execução e
ignoradas pelo Git.
