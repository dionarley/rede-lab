# Política de Segurança e Segredos

## Princípio

**Configuração local não é código.** O que é específico da máquina fica no
`.env`, que é ignorado pelo Git. O que é compartilhável fica no
`.env.example`.

| Arquivo | Versionado? | Conteúdo |
|---------|-------------|----------|
| `.env.example` | ✅ sim | Template com valores de laboratório |
| `.env` | ❌ não | Configuração local (IPs, engine, senha) |
| `wireguard/keys/*` | ❌ não | Chaves geradas em tempo de execução |
| `*.pem`, `*.p12`, `id_rsa`, `id_ed25519` | ❌ não | Material de chave |

## Guardrails implementados

### 1. `scripts/guard.sh`

Verifica o índice do Git e falha se encontrar:

- `.env`, `.env.local`, `.env.production`, `.env.staging` etc. (exceto `.env.example`)
- chaves em `wireguard/keys/`, `*.pem`, `*.p12`, `*.key`, `id_rsa`, `id_ed25519`
- padrões conhecidos de segredo no conteúdo:
  - tokens GitHub (`ghp_`, `gho_`, `github_pat_`)
  - chaves AWS (`AKIA...`)
  - cabeçalhos de chave privada (`BEGIN ... PRIVATE KEY`)

Execução manual:

```bash
./scripts/guard.sh
# ou
make guard
```

### 2. Hook de pre-commit

O hook roda o guard antes de cada commit e aborta se houver violação.

```bash
make hooks
# equivale a:
#   chmod +x .githooks/pre-commit scripts/guard.sh
#   git config core.hooksPath .githooks
```

> O `core.hooksPath` é configuração local do clone. Cada pessoa precisa
> rodar `make hooks` uma vez após clonar.

### 3. CI

O job `Guard - sem .env ou segredos` em `.github/workflows/ci.yml` executa
o guard em todo push e pull request para `main` e `develop`.

## Fluxo seguro

```bash
# 1. Clonar
git clone https://github.com/dionarley/rede-lab.git
cd rede-lab

# 2. Instalar hook
make hooks

# 3. Criar config local (ou deixar os scripts criarem)
cp .env.example .env

# 4. Editar apenas o .env
$EDITOR .env
```

## Se um segredo real vazar

1. **Rotacione imediatamente** o segredo (token, senha, chave).
2. Remova do índice:
   ```bash
   git rm --cached <arquivo>
   ```
3. Adicione ao `.gitignore`.
4. Se o segredo já foi para o remoto, **purge o histórico**:
   ```bash
   git filter-repo --path <arquivo> --invert-paths
   git push --force --all
   git push --force --tags
   ```
5. Avise colaboradores para re-clonarem (o histórico foi reescrito).

## Histórico deste repositório

O `.env` foi incluído no commit inicial `8eb8911` (v1.0.0) com **apenas
valores de laboratório** (`labpass`, IPs privados), sem segredo real. A
partir da v1.0.1 ele deixou de ser rastreado e passou a ser ignorado. Como
o conteúdo não é sensível, o histórico não foi reescrito; se necessário,
o procedimento acima pode ser aplicado.
