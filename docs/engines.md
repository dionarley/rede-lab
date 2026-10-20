# Suporte a Podman e Docker

O lab é agnóstico de engine. A detecção é feita por `scripts/common.sh`:

1. Lê `CONTAINER_ENGINE` do `.env`.
2. Se for `auto`, usa **podman** se disponível; senão **docker**.
3. Se for `podman` ou `docker`, valida que o binário existe.

## Forçar um engine

Edite o `.env`:

```bash
CONTAINER_ENGINE=docker   # ou podman
```

Ou passe por variável de ambiente, que tem **precedência** sobre o `.env`:

```bash
CONTAINER_ENGINE=docker ./scripts/deploy.sh
```

## Diferenças tratadas

| Recurso | Podman | Docker |
|---------|--------|--------|
| Checar rede | `podman network exists` | `docker network inspect` |
| IP fixo na rede | `--ip` | `--ip` (rede definida pelo usuário) |
| `NET_ADMIN` | `--cap-add NET_ADMIN` | `--cap-add NET_ADMIN` |
| `ip_forward` | `--sysctl` | `--sysctl` (com suporte do daemon) |

O helper `engine_network_exists()` em `scripts/common.sh` encapsula a
diferença de checagem de rede.

## Exemplos

```bash
# Podman
CONTAINER_ENGINE=podman ./scripts/deploy.sh

# Docker (quando instalado)
CONTAINER_ENGINE=docker ./scripts/deploy.sh
```

## Compose

Além dos scripts nativos, o lab tem `docker-compose.yml` e o wrapper
`scripts/compose.sh`, que funciona com Docker Compose, `podman compose`
e `podman-compose`. Veja [`compose.md`](compose.md).

## Observação sobre rootless

Em Podman rootless, `ping` pode falhar com `Operation not permitted`
(falta `CAP_NET_RAW`). Isso **não** afeta o SSH, que usa TCP. Para liberar
ping, adicione `--cap-add NET_RAW` ao container da casa.
