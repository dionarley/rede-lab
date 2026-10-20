# Exercício — Casa de praia via WireGuard

> **Exercício somente documentado.** Este roteiro não cria nada automaticamente.
> Ele descreve, passo a passo, como construir uma instância **“casa de praia”**
> fora da rede do lab e conectá-la ao servidor por WireGuard.

## Objetivo

Criar um site remoto isolado, a **casa de praia**, que:

- fica em uma rede própria (`praia-net`, `10.0.50.0/24`);
- **não** tem interface na `lab-net` (`10.0.0.0/24`);
- alcança o lab apenas pelo endpoint WireGuard publicado pelo host;
- usa uma segunda instância WireGuard no servidor (`wg2`, `10.0.100.0/24`);
- consegue fazer SSH em `labuser@10.0.100.1` pelo túnel.

Nada é executado por este documento. Os arquivos e comandos abaixo são o
roteiro para você reproduzir o exercício.

## O que você vai praticar

- Rede bridge isolada.
- Publicação de porta UDP no host.
- Segunda interface WireGuard sem mexer na VPN existente.
- `AllowedIPs` mínimo e `PersistentKeepalive`.
- Endpoint via gateway da bridge (`10.0.50.254`) em vez de IP público.
- Diagnóstico de handshake, rota e SSH.

## Cenário

```text
Casa de praia — praia-net 10.0.50.0/24
┌──────────────────────────────────────────────┐
│  casa-praia 10.0.50.10                       │
│  wg0 10.0.100.10/24                          │
└───────────────────┬──────────────────────────┘
                    │ UDP 51821/udp
                    │ endpoint 10.0.50.254:51821
                    ▼
┌──────────────────────────────────────────────┐
│ Host                                         │
│ publica 51821/udp -> servidor:51821          │
└───────────────────┬──────────────────────────┘
                    │ DNAT
                    ▼
Lab — lab-net 10.0.0.0/24
┌──────────────────────────────────────────────┐
│  servidor 10.0.0.20                          │
│  wg2 10.0.100.1/24  listen 51821/udp         │
│  wg0 10.0.99.1/24   listen 51820/udp (lab)   │
│                                              │
│  casa 10.0.0.10                              │
│  wg1 10.0.99.10/24 (VPN existente)           │
└──────────────────────────────────────────────┘
```

O host faz o papel de “internet” entre as duas redes. A casa de praia não
enxerga `10.0.0.20` por rota direta; o caminho documentado é o túnel até
`10.0.100.1`.

## Endereçamento

| Elemento | Rede | IP | WireGuard | Porta |
|----------|------|----|-----------|-------|
| Casa de praia | `praia-net 10.0.50.0/24` | `10.0.50.10` | `wg0 10.0.100.10/24` | — |
| Gateway da praia | `praia-net` | `10.0.50.254` | — | — |
| Servidor — wg2 | `lab-net 10.0.0.0/24` | `10.0.0.20` | `wg2 10.0.100.1/24` | `51821/udp` |
| Servidor — wg0 do lab | `lab-net` | `10.0.0.20` | `wg0 10.0.99.1/24` | `51820/udp` |
| Casa do lab | `lab-net` | `10.0.0.10` | `wg1 10.0.99.10/24` | — |

**Por que uma segunda interface (`wg2`)?**

- Não altera o `wg0` existente; o `vpn.sh` recria `wg0`/`wg1` e não mexe em `wg2`.
- Usa uma porta separada (`51821`), fácil de liberar/bloquear.
- Permite remover a casa de praia sem afetar a VPN do lab.
- Evita misturar os peers e sub-redes `10.0.99.0/24` e `10.0.100.0/24`.

## Pré-requisitos

- Lab rodando via Compose:

  ```bash
  ./scripts/compose.sh ps
  ./scripts/vpn.sh status
  podman exec servidor wg show wg0
  ```

  Troque `podman` por `docker` se for o caso.

- `podman-compose` ou `docker compose`.
- Porta **51821/udp** livre no host.
- `wireguard-tools` nas imagens do servidor e da casa de praia.
- Credenciais de laboratório `labuser` / `labpass` (já existentes no servidor).
- Acesso à internet apenas para o build da imagem (`dnf`). O WireGuard usa
  o host como endpoint e não depende de DNS externo.

## Passo 0 — Baseline

Confirme que a VPN existente está saudável antes de adicionar o novo site:

```bash
./scripts/vpn.sh status
podman exec servidor wg show wg0
podman exec casa wg show wg1
```

Resultado esperado: `wg0` com o peer da casa e handshake recente.

## Passo 1 — Criar os arquivos do exercício

Crie a pasta `casa-praia/` com os dois arquivos abaixo.

### `casa-praia/Dockerfile`

```dockerfile
FROM fedora:latest

RUN dnf -y install \
        wireguard-tools \
        iproute \
        iputils \
        openssh-clients \
        sshpass \
        procps-ng \
        nano \
    && dnf clean all

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
```

### `casa-praia/entrypoint.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[casa-praia] rede isolada pronta"
ip -brief addr

exec tail -f /dev/null
```

O entrypoint **não** altera a rota padrão. A rota da casa de praia continua
sendo a da bridge `praia-net`, via `10.0.50.254`.

### `compose.praia.yaml`

Arquivo de override do Compose. Ele adiciona a porta publicada no servidor,
o serviço `casa-praia`, a rede `praia-net` e um volume para as chaves.

```yaml
services:
  servidor:
    ports:
      - "51821:51821/udp"

  casa-praia:
    build:
      context: ./casa-praia
      dockerfile: Dockerfile
    image: lab-casa-praia
    container_name: casa-praia
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - wg-praia:/etc/wireguard
    networks:
      praia-net:
        ipv4_address: 10.0.50.10
    depends_on:
      - servidor

networks:
  praia-net:
    name: praia-net
    driver: bridge
    ipam:
      config:
        - subnet: 10.0.50.0/24
          gateway: 10.0.50.254

volumes:
  wg-praia:
    name: rede-lab-wg-praia
```

Pontos importantes:

- `casa-praia` só entra em `praia-net`; não tem endereço em `lab-net`.
- `NET_ADMIN` é necessário para criar o `wg0`.
- `NET_RAW` é opcional e serve para liberar `ping` em Podman rootless.
- O volume `rede-lab-wg-praia` preserva as chaves entre recriações.
- A porta `51821/udp` é publicada no host e encaminhada ao container
  `servidor`.

## Passo 2 — Subir a casa de praia

```bash
# Podman
podman-compose -f docker-compose.yml -f compose.praia.yaml up -d --build

# Docker
docker compose -f docker-compose.yml -f compose.praia.yaml up -d --build
```

O Compose vai recriar o `servidor` para aplicar a porta `51821/udp`. Por isso,
reconfigure a VPN existente:

```bash
./scripts/vpn.sh start
```

Se o Compose não detectar a mudança de porta, force a recriação:

```bash
# Podman
podman-compose -f docker-compose.yml -f compose.praia.yaml up -d --build --force-recreate

# Docker
docker compose -f docker-compose.yml -f compose.praia.yaml up -d --build --force-recreate
```

Depois rode `./scripts/vpn.sh start` novamente.

Confira:

```bash
podman ps --format 'table {{.Names}}\t{{.Status}}'
podman port servidor 51821/udp
podman exec casa-praia ip -brief addr
```

Resultado esperado (algo como):

```text
eth0@if... UP 10.0.50.10/24
```

E a porta publicada deve aparecer como algo do tipo:

```text
0.0.0.0:51821
```

Se estiver usando Docker, troque `podman` por `docker`.

## Passo 3 — Gerar as chaves

Use o mesmo terminal para os próximos passos, porque as variáveis são
reaproveitadas.

```bash
ENGINE=podman   # ou: ENGINE=docker

# Servidor (interface wg2)
$ENGINE exec servidor bash -c '
  mkdir -p /etc/wireguard
  umask 077
  { [ -f /etc/wireguard/praia-servidor.key ] && [ -f /etc/wireguard/praia-servidor.pub ]; } || (
    wg genkey | tee /etc/wireguard/praia-servidor.key | wg pubkey > /etc/wireguard/praia-servidor.pub
  )
  chmod 600 /etc/wireguard/praia-servidor.key
'

# Casa de praia (interface wg0)
$ENGINE exec casa-praia bash -c '
  mkdir -p /etc/wireguard
  umask 077
  { [ -f /etc/wireguard/praia.key ] && [ -f /etc/wireguard/praia.pub ]; } || (
    wg genkey | tee /etc/wireguard/praia.key | wg pubkey > /etc/wireguard/praia.pub
  )
  chmod 600 /etc/wireguard/praia.key
'
```

Leia as chaves públicas:

```bash
PRAIA_PUB=$($ENGINE exec casa-praia cat /etc/wireguard/praia.pub)
SERVIDOR_PRAIA_PUB=$($ENGINE exec servidor cat /etc/wireguard/praia-servidor.pub)

echo "casa de praia: $PRAIA_PUB"
echo "servidor wg2:  $SERVIDOR_PRAIA_PUB"
```

> Não regenere as chaves depois de configurar os peers. As chaves privadas
> ficam nos volumes `rede-lab-wg-praia` e `rede-lab-wg-servidor`.

## Passo 4 — Configurar o `wg2` no servidor

```bash
$ENGINE exec servidor bash -c "
  ip link del wg2 2>/dev/null || true
  ip link add wg2 type wireguard
  ip address add 10.0.100.1/24 dev wg2
  wg set wg2 private-key /etc/wireguard/praia-servidor.key listen-port 51821
  wg set wg2 peer '$PRAIA_PUB' allowed-ips 10.0.100.10/32
  ip link set wg2 up
"
```

Por que `allowed-ips 10.0.100.10/32`?

- É o menor escopo possível: o servidor só aceita o IP WireGuard da casa
  de praia.
- Não libera, por padrão, acesso à `lab-net` (`10.0.0.0/24`).
- Para liberar outros destinos, veja os desafios no final.

Confira:

```bash
$ENGINE exec servidor wg show wg2
```

Resultado esperado:

```text
interface: wg2
  listening port: 51821

peer: <chave-publica-da-praia>
  allowed ips: 10.0.100.10/32
```

## Passo 5 — Configurar o `wg0` na casa de praia

```bash
$ENGINE exec casa-praia bash -c "
  ip link del wg0 2>/dev/null || true
  ip link add wg0 type wireguard
  ip address add 10.0.100.10/24 dev wg0
  wg set wg0 private-key /etc/wireguard/praia.key
  wg set wg0 peer '$SERVIDOR_PRAIA_PUB' allowed-ips 10.0.100.1/32 endpoint 10.0.50.254:51821 persistent-keepalive 15
  ip link set wg0 up
"
```

O endpoint `10.0.50.254:51821` é o gateway da `praia-net` mais a porta
publicada no host. Alternativas:

- Podman: `host.containers.internal:51821`
- Docker: `host.docker.internal:51821` (no Linux, adicione
  `extra_hosts: ["host.docker.internal:host-gateway"]`)
- Docker Desktop: prefira `host.docker.internal:51821`; o gateway da bridge
  pode não encaminhar para portas publicadas no host.

Confira:

```bash
$ENGINE exec casa-praia wg show wg0
```

Resultado esperado:

```text
interface: wg0
  public key: <chave-publica-da-praia>
  private key: (hidden)
  listening port: <porta-efemera>

peer: <chave-publica-do-servidor>
  endpoint: 10.0.50.254:51821
  allowed ips: 10.0.100.1/32
  latest handshake: <há poucos segundos>
  transfer: <bytes> received, <bytes> sent
  persistent keepalive: every 15 seconds
```

## Passo 6 — Testar

### Handshake dos dois lados

```bash
$ENGINE exec servidor wg show wg2
$ENGINE exec casa-praia wg show wg0
```

### Ping pelo túnel

```bash
$ENGINE exec casa-praia ping -c 3 10.0.100.1
```

Se o ping falhar em Podman rootless mesmo com `NET_RAW`, use o teste SSH
(TCP), que é o critério principal do exercício.

### SSH pelo túnel

```bash
$ENGINE exec casa-praia sshpass -p labpass ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=8 \
  labuser@10.0.100.1 'echo PRAIA_OK; id -un'
```

Resultado esperado:

```text
PRAIA_OK
labuser
```

Isso prova que a casa de praia chegou ao `servidor` pelo `wg2`, e não por
uma rota direta na `lab-net`.

> `sshpass` e `StrictHostKeyChecking=no` são apenas para o lab. Em produção,
> use chave SSH e verificação de host.

## Passo 7 — Provar o isolamento

```bash
# Deve sair por wg0
$ENGINE exec casa-praia ip route get 10.0.100.1

# Não deve existir rota direta para o lab; deve cair no default da praia
$ENGINE exec casa-praia ip route get 10.0.0.20

# A casa de praia só tem IP da praia e do túnel
$ENGINE exec casa-praia ip -brief addr

# A rede praia-net é separada da lab-net
$ENGINE network inspect praia-net | grep -iE 'subnet|gateway'
```

Interpretação:

- `10.0.100.1` deve aparecer como `dev wg0`.
- `10.0.0.20` deve aparecer como `via 10.0.50.254 dev eth0` (ou equivalente),
  não como uma interface do lab.
- A casa de praia não tem `10.0.0.x` em `eth0`.

O host pode encaminhar pacotes entre bridges dependendo da configuração de
firewall do engine. O objetivo do exercício é que o **caminho documentado**
para o lab seja o túnel; para garantir isolamento rígido, use regras de
firewall no host ou um roteador dedicado.

## Passo 8 — Limpeza

Remova as interfaces de runtime:

```bash
$ENGINE exec casa-praia bash -c 'ip link del wg0 2>/dev/null || true'
$ENGINE exec servidor bash -c 'ip link del wg2 2>/dev/null || true'
```

Remova o container e a rede da praia:

```bash
$ENGINE rm -f casa-praia
$ENGINE network rm praia-net 2>/dev/null || true
```

Restaure o servidor sem a porta `51821/udp`:

```bash
./scripts/compose.sh up --force-recreate servidor
```

O wrapper `compose.sh up` já executa `./scripts/vpn.sh start` no final. Se
você recriar o servidor por outro caminho, rode o `vpn.sh start` manualmente.

Os arquivos `casa-praia/` e `compose.praia.yaml` são de exemplo; apague-os
se não quiser manter o exercício no repositório.

Se quiser apagar também as chaves da casa de praia:

```bash
$ENGINE volume rm rede-lab-wg-praia 2>/dev/null || true
$ENGINE exec servidor rm -f /etc/wireguard/praia-servidor.key /etc/wireguard/praia-servidor.pub
```

Não remova o volume `rede-lab-wg-servidor` inteiro: ele também guarda as
chaves da VPN existente do lab.

## Troubleshooting

### O handshake não aparece

1. Confirme que a porta foi publicada:

   ```bash
   podman port servidor 51821/udp
   # ou: docker port servidor 51821/udp
   ```

2. Confirme o `listen-port` no servidor:

   ```bash
   $ENGINE exec servidor wg show wg2
   ```

3. Confirme o endpoint na casa de praia:

   ```bash
   $ENGINE exec casa-praia wg show wg0
   ```

4. Verifique se as chaves públicas batem:

   ```bash
   $ENGINE exec casa-praia cat /etc/wireguard/praia.pub
   $ENGINE exec servidor cat /etc/wireguard/praia-servidor.pub
   ```

5. Verifique firewall do host para UDP `51821`. Em rootless, a publicação
   de portas depende do `rootlessport`/`pasta`.

### `Operation not permitted` ao criar `wg2`/`wg0`

Falta `NET_ADMIN`. Confirme o override:

```yaml
cap_add:
  - NET_ADMIN
```

Recrie o container depois de alterar.

### `ping` falha, mas o SSH funciona

Comportamento comum em Podman rootless. O `NET_RAW` ajuda, mas o SSH (TCP)
é o teste definitivo. Não bloqueie o exercício por causa do ping.

### SSH com `Permission denied`

- Use `labuser`, não `root` (o sshd tem `AllowUsers labuser`).
- A senha do lab é `labpass`.
- Teste o IP do túnel: `10.0.100.1`.
- Confirme que o `sshd` está de pé:

  ```bash
  $ENGINE exec servidor pgrep -x sshd
  ```

### `Connection timed out` no SSH

- O endpoint pode estar errado. Tente `10.0.50.254:51821`.
- Se estiver no Docker, teste `host.docker.internal:51821` com
  `extra_hosts`.
- Confirme que a porta publicada existe e que o firewall não bloqueia UDP.

### A porta `51821` já está em uso

Escolha outra porta no override e no `listen-port`:

```yaml
ports:
  - "51822:51822/udp"
```

E ajuste:

```bash
wg set wg2 listen-port 51822
# endpoint da casa de praia: 10.0.50.254:51822
```

### `vpn.sh start` derrubou o `wg2`?

Ele não mexe em `wg2`; ele recria `wg0` e `wg1`. O que derruba o `wg2` é a
**recriação do container `servidor`**. Nesse caso, repita os passos 4 e 5.

### `casa-praia` não resolve nomes

O exercício usa IP no endpoint; DNS não é necessário. Se quiser DNS,
configure `dns:` no serviço ou use o resolvedor do host.

## Desafios

1. **Acessar `10.0.0.20` a partir da casa de praia.**
   Adicione `10.0.0.0/24` aos `AllowedIPs` da casa de praia, habilite
   forwarding no servidor e trate a chain `FORWARD`/NAT. Documente o caminho
   e os riscos de ampliar o escopo.

2. **Acessar a casa de praia a partir da `casa` do lab.**
   O servidor precisa encaminhar entre `wg0` (lab) e `wg2` (praia), e os
   `AllowedIPs` dos dois peers precisam incluir as rotas necessárias.

3. **Persistir a configuração.**
   Crie `scripts/vpn-praia.sh` com `start|stop|status|test` e chame-o depois
   do `compose up`. Guarde as chaves nos volumes e não no repositório.

4. **Trocar senha por chave SSH.**
   Gere um par de chaves na casa de praia, adicione a pública em
   `/home/labuser/.ssh/authorized_keys` no servidor e remova o `sshpass`.

5. **Usar `wg-quick`.**
   Monte `wg2.conf` no servidor e `wg0.conf` na casa de praia. Evite
   `DNS =` para não depender de `resolvconf` no container.

6. **Restringir o firewall.**
   Em vez de expor `51821/udp` para o mundo, permita apenas o IP público da
   casa de praia. Documente a regra e o rollback.

## Checklist

- [ ] `praia-net` criada em `10.0.50.0/24`.
- [ ] `casa-praia` em `10.0.50.10`, sem interface na `lab-net`.
- [ ] `servidor` publica `51821/udp`.
- [ ] `wg2` no servidor em `10.0.100.1/24`.
- [ ] `wg0` na casa de praia em `10.0.100.10/24`.
- [ ] Handshake recente nos dois lados.
- [ ] `ip route get 10.0.100.1` usa `wg0`.
- [ ] SSH em `labuser@10.0.100.1` retorna `PRAIA_OK`.
- [ ] `10.0.0.20` não tem rota direta pela interface da praia.
- [ ] Limpeza executada.

## Segurança

- Este é um lab: `labpass` e `StrictHostKeyChecking=no` são intencionais.
- Não exponha `51821/udp` para a internet sem firewall.
- Não versione chaves privadas; o `.gitignore` já bloqueia chaves e o
  `scripts/guard.sh` ajuda a evitar segredos no índice.
- Use `AllowedIPs` mínimo. Evite `0.0.0.0/0` sem necessidade.
- Em produção, use chaves SSH, endpoint com nome DNS e monitoramento.

## Referências

- [`wireguard.md`](wireguard.md) — configuração e testes da VPN do lab.
- [`vpn-operacao.md`](vpn-operacao.md) — operação do `vpn.sh`.
- [`compose.md`](compose.md) — uso do Compose.
- [`containers.html`](containers.html) — como entrar nos containers.
- [`nat.html`](nat.html) — camada de NAT do lab.
