#!/usr/bin/env bash
# common.sh - carrega .env e detecta o container engine (podman/docker)
# Uso: source "$(dirname "$0")/common.sh"

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Preserva CONTAINER_ENGINE definido no ambiente (tem precedência sobre o .env)
_ENV_ENGINE="${CONTAINER_ENGINE-}"

# Carrega variáveis do .env (se existir)
if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

if [ -n "${_ENV_ENGINE:-}" ]; then
    CONTAINER_ENGINE="$_ENV_ENGINE"
fi

# Detecta engine
choose_engine() {
    local requested="${CONTAINER_ENGINE:-auto}"
    if [ "$requested" = "auto" ]; then
        if command -v podman >/dev/null 2>&1; then
            echo "podman"
        elif command -v docker >/dev/null 2>&1; then
            echo "docker"
        else
            echo "ERRO: nem podman nem docker encontrados no PATH." >&2
            exit 1
        fi
    else
        if ! command -v "$requested" >/dev/null 2>&1; then
            echo "ERRO: engine '$requested' não encontrado no PATH." >&2
            exit 1
        fi
        echo "$requested"
    fi
}

ENGINE="$(choose_engine)"
export ENGINE

# Compatibilidade: no Docker, "podman network exists" não existe
engine_network_exists() {
    local name="$1"
    if [ "$ENGINE" = "podman" ]; then
        "$ENGINE" network exists "$name" 2>/dev/null
    else
        "$ENGINE" network inspect "$name" >/dev/null 2>&1
    fi
}
