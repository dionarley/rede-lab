# 🛡️ Rede Lab - SSH + WireGuard com Podman/Docker

Lab de rede pequena simulando:

- **ISP (Provedor de Serviço)** com NAT e IP forwarding
- **PC de Casa** (cliente SSH + cliente WireGuard)
- **Servidor** (servidor SSH + servidor WireGuard)

Suporta **Podman** e **Docker** (detecção automática via `.env`).

## 📁 Estrutura

```
rede-lab/
├── .env.example              # template público (versionado)
├── .env                      # configuração local (ignorada pelo git)
├── .githooks/
│   └── pre-commit            # bloqueia .env/segredos antes do commit
├── .github/workflows/ci.yml  # CI: shellcheck + guard + compose
├── docker-compose.yml        # Docker Compose / Podman Compose
├── README.md
├── docs/
│   ├── topologia.md          # rede, diagrama e endereçamento
│   ├── ssh.md                # implementação e testes de SSH
│   ├── wireguard.md          # implementação e testes de WireGuard
│   ├── vpn-operacao.md       # operação da VPN
│   ├── engines.md            # suporte Podman/Docker
│   ├── compose.md            # uso do Docker/Podman Compose
│   ├── nat.html              # explicação visual da camada de NAT
│   ├── containers.html       # como entrar em cada container
│   ├── exercicio-casa-de-praia.md # exercício: site remoto via WireGuard
│   └── seguranca.md          # política de segredos
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
│   ├── doctor.sh             # diagnóstico
│   ├── guard.sh              # bloqueia .env/segredos
│   ├── compose.sh            # wrapper Docker/Podman Compose
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
# IP reservado da bridge; o gateway lógico é o ISP 10.0.0.1.
GATEWAY=10.0.0.254

COMPOSE_PROJECT_NAME=rede-lab

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

O `.env` é **local e ignorado pelo git**. Se ele não existir, os scripts o
criam automaticamente a partir do `.env.example`. Nunca commite o `.env`.

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

### 0. Configurar ambiente

```bash
cp .env.example .env   # opcional: os scripts criam automaticamente
make hooks             # instala o hook de pre-commit
```

### 1. Subir o lab

```bash
chmod +x network/lab-network.sh scripts/*.sh
./scripts/deploy.sh
```

### 1b. Alternativa: Docker/Podman Compose

```bash
./scripts/compose.sh up      # constrói, sobe e configura a VPN
./scripts/compose.sh ps      # lista os serviços
./scripts/compose.sh logs    # logs
./scripts/compose.sh down    # derruba containers e rede
./scripts/compose.sh reset   # down + remove volumes (chaves WG)
```

O wrapper detecta `docker compose`, `podman compose` ou `podman-compose`.
Também disponível via `make compose-up`, `make compose-down`, etc.
Detalhes em [`docs/compose.md`](docs/compose.md).

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
./scripts/destroy.sh        # lab criado via scripts
./scripts/compose.sh down   # lab criado via Compose
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

## 🗺️ Topologia

![Topologia do Rede Lab](docs/topologia.svg)

- [`docs/topologia.svg`](docs/topologia.svg) — diagrama vetorial
- [`docs/topologia.mmd`](docs/topologia.mmd) — fonte Mermaid
- [`docs/topologia.md`](docs/topologia.md) — detalhes e diagrama ASCII
- [`docs/nat.html`](docs/nat.html) — camada de NAT explicada visualmente

## 📄 Documentação

- [`docs/topologia.md`](docs/topologia.md)
- [`docs/ssh.md`](docs/ssh.md)
- [`docs/wireguard.md`](docs/wireguard.md)
- [`docs/vpn-operacao.md`](docs/vpn-operacao.md)
- [`docs/engines.md`](docs/engines.md)
- [`docs/nat.html`](docs/nat.html) — explicação visual da camada de NAT
- [`docs/containers.html`](docs/containers.html) — como entrar em cada container

## 🧪 Exercício

- [`docs/exercicio-casa-de-praia.md`](docs/exercicio-casa-de-praia.md) — conecte uma casa fora da rede ao lab via WireGuard.

## 🔐 Segurança

Este é um lab educacional. As credenciais (`labuser/labpass`) e a opção
`StrictHostKeyChecking no` são intencionais para testes e **não devem** ser
usadas em produção.

Proteções contra vazamento:

- `.env` **nunca** é versionado; o template público é `.env.example`.
- `scripts/guard.sh` bloqueia `.env`, chaves privadas e padrões de segredo.
- Hook de pre-commit: instale com `make hooks`.
- CI executa o guard em todo push/PR.
- Chaves WireGuard são geradas em tempo de execução e ignoradas pelo Git.
- Se um segredo real for commitado, rotacione-o e purgue o histórico
  (`git filter-repo`). Veja [`docs/seguranca.md`](docs/seguranca.md).
