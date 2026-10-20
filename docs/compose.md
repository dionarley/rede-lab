# Docker Compose / Podman Compose

O lab pode ser executado inteiramente via Compose, sem os scripts de
`run`/`network` individuais.

## Pré-requisitos

Um dos seguintes:

- Docker + `docker compose`
- Podman + `podman compose`
- Podman + `podman-compose`

O wrapper `scripts/compose.sh` detecta automaticamente, nesta ordem:

| Engine | Ordem de preferência |
|--------|----------------------|
| Podman | `podman-compose` → `podman compose` |
| Docker | `docker compose` → `docker-compose` |

Para forçar:

```bash
COMPOSE_BIN=podman-compose ./scripts/compose.sh up
# ou no .env:
# COMPOSE_BIN=docker compose
```

## Subir

```bash
./scripts/compose.sh up
# ou
make compose-up
```

O comando:

1. Executa `compose up -d --build`.
2. Aguarda os containers.
3. Executa `./scripts/vpn.sh start` para configurar o WireGuard.

## Comandos

```bash
./scripts/compose.sh up        # sobe + VPN
./scripts/compose.sh down      # para e remove containers/rede
./scripts/compose.sh reset     # down -v (remove volumes/chaves WG)
./scripts/compose.sh ps        # status
./scripts/compose.sh logs      # logs (ou: logs servidor)
./scripts/compose.sh config    # valida e mostra a config final
./scripts/compose.sh restart   # reinicia
./scripts/compose.sh stop      # para
./scripts/compose.sh start     # inicia containers existentes
./scripts/compose.sh exec casa bash
```

Atalhos `make`:

```bash
make compose-up
make compose-down
make compose-ps
make compose-logs
make compose-config
make compose-reset
```

## Serviços

| Serviço | Container | IP | Função |
|---------|-----------|----|--------|
| `isp` | `isp` | `10.0.0.1` | NAT + forwarding |
| `servidor` | `servidor` | `10.0.0.20` | sshd :22 + wg0 :51820/udp |
| `casa` | `casa` | `10.0.0.10` | cliente SSH/WG |

## Rede e volumes

- **Rede:** `lab-net` (`10.0.0.0/24`), gateway da bridge `10.0.0.254`.
  O gateway lógico é o container `isp` em `10.0.0.1`.
- **Volumes:**
  - `rede-lab-wg-servidor` → `/etc/wireguard` no servidor
  - `rede-lab-wg-casa` → `/etc/wireguard` na casa

Os volumes preservam as chaves WireGuard entre recriações de containers.
Use `./scripts/compose.sh reset` para apagá-las e gerar novas.

## Diferenças em relação ao deploy por scripts

| Item | Scripts (`deploy.sh`) | Compose |
|------|-----------------------|---------|
| Criação de rede | `lab-network.sh` | `docker-compose.yml` |
| Containers | `podman/docker run` | Compose |
| Chaves WG | dentro dos containers | volumes nomeados |
| VPN | `vpn.sh start` | `compose.sh up` chama `vpn.sh` |
| Reset de chaves | `destroy.sh` + remover containers | `compose.sh reset` |

Os dois modos usam os mesmos nomes de containers (`isp`, `casa`,
`servidor`), então `vpn.sh`, `test-ssh.sh` e `doctor.sh` funcionam em
ambos.

## Troubleshooting

### IP `10.0.0.1` reservado

O Docker reserva o IP do gateway da rede. Por isso a bridge usa
`10.0.0.254` e o ISP usa `10.0.0.1`. Não troque o `GATEWAY` para
`10.0.0.1` ao usar Compose.

### Conflito de nome de container

Se existirem containers antigos com os mesmos nomes:

```bash
./scripts/destroy.sh
./scripts/compose.sh up
```

### `ping: Operation not permitted`

Podman rootless sem `CAP_NET_RAW`. Não afeta SSH (TCP). Para liberar,
adicione `cap_add: [NET_RAW]` ao serviço `casa`.

### Validar sem subir

```bash
./scripts/compose.sh config
# ou
docker compose config -q
```
