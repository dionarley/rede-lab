#!/usr/bin/env bash
# guard.sh - impede versionamento de configuração local e segredos.
# Roda no pre-commit (.githooks/pre-commit) e no CI.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail=0
erro() { echo "ERRO: $*" >&2; fail=1; }

echo "[guard] Verificando o índice do git..."

# 1. Arquivos de configuração local (.env, .env.local, .env.production, ...)
tracked_env="$(git ls-files \
    | grep -E '(^|/)\.env(\.[A-Za-z0-9_-]+)?$' \
    | grep -v '\.env\.example$' || true)"
if [ -n "$tracked_env" ]; then
    erro "arquivo de configuração local rastreado:"
    echo "$tracked_env" | sed 's/^/       /' >&2
fi

# 2. Chaves e material sensível
tracked_keys="$(git ls-files \
    'wireguard/keys/*' '*.pem' '*.p12' '*.key' 'id_rsa' 'id_ed25519' \
    2>/dev/null || true)"
if [ -n "$tracked_keys" ]; then
    erro "material de chave rastreado:"
    echo "$tracked_keys" | sed 's/^/       /' >&2
fi

# 3. Padrões de segredo no conteúdo (tokens GitHub, AWS e chaves privadas)
secret_re='ghp_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (OPENSSH|RSA|EC|DSA|ED25519) PRIVATE KEY-----'
secret_hits="$(git grep --cached -I -n -E "$secret_re" -- . \
    ':!.env.example' ':!docs/*' ':!testes/*' 2>/dev/null || true)"
if [ -n "$secret_hits" ]; then
    erro "possível segredo encontrado no conteúdo rastreado:"
    echo "$secret_hits" | sed 's/^/       /' >&2
fi

if [ "$fail" -ne 0 ]; then
    echo "" >&2
    echo "[guard] FALHOU: remova o item do índice antes de commitar." >&2
    echo "        Exemplo: git rm --cached <arquivo>" >&2
    exit 1
fi

echo "[guard] OK: nenhum .env, chave privada ou segredo conhecido rastreado."
