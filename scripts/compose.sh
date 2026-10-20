#!/usr/bin/env bash
# compose.sh - wrapper para Docker Compose / Podman Compose
set -euo pipefail

source "$(dirname "$0")/common.sh"

COMPOSE_CMD=()

detect_compose() {
    if [ -n "${COMPOSE_BIN:-}" ]; then
        read -r -a COMPOSE_CMD <<< "$COMPOSE_BIN"
        return
    fi

    if [ "$ENGINE" = "podman" ]; then
        # podman-compose nativo primeiro; depois o wrapper oficial "podman compose"
        if command -v podman-compose >/dev/null 2>&1; then
            COMPOSE_CMD=(podman-compose)
            return
        fi
        if command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
            COMPOSE_CMD=(podman compose)
            return
        fi
    else
        if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
            COMPOSE_CMD=(docker compose)
            return
        fi
        if command -v docker-compose >/dev/null 2>&1; then
            COMPOSE_CMD=(docker-compose)
            return
        fi
    fi

    echo "ERRO: nenhum Compose encontrado." >&2
    echo "      Instale docker compose, podman compose ou podman-compose," >&2
    echo "      ou defina COMPOSE_BIN no .env (ex.: COMPOSE_BIN=podman-compose)." >&2
    exit 1
}

detect_compose
echo "[compose] engine=$ENGINE | comando=${COMPOSE_CMD[*]}" >&2

cmd="${1:-}"
shift || true

case "$cmd" in
    up)
        "${COMPOSE_CMD[@]}" up -d --build "$@"
        echo "[compose] aguardando containers..." >&2
        sleep 2
        ./scripts/vpn.sh start
        ;;
    down)
        "${COMPOSE_CMD[@]}" down "$@"
        ;;
    reset)
        "${COMPOSE_CMD[@]}" down -v "$@"
        ;;
    ps|logs|config|restart|stop|start|exec)
        "${COMPOSE_CMD[@]}" "$cmd" "$@"
        ;;
    *)
        cat >&2 <<EOF
Uso: $0 {up|down|reset|ps|logs|config|restart|stop|start|exec} [args...]

  up       Sobe containers, constrói imagens e configura a VPN
  down     Para e remove containers/rede
  reset    Como down, mas remove volumes (chaves WireGuard)
  ps       Lista os serviços
  logs     Mostra logs (ex.: $0 logs servidor)
  config   Valida e mostra a configuração final
  restart  Reinicia os serviços
  stop     Para os serviços
  start    Inicia serviços já criados
  exec     Executa comando (ex.: $0 exec casa bash)
EOF
        exit 1
        ;;
esac
