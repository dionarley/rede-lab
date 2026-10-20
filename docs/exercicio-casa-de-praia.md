# Exercício — PC na casa de praia via WireGuard

> **Exercício somente documentado.** Este roteiro não cria nada automaticamente.
> Ele descreve como conectar **um PC físico na casa de praia** ao servidor do
> lab por WireGuard.
>
> A casa de praia é **literalmente um PC** (notebook ou desktop), fora da rede
> do lab. Ela **não** é um container do lab. A versão anterior deste exercício
> simulava a casa com um container em `praia-net`; este roteiro substitui
> aquela abordagem.

## Objetivo

Conectar um PC que está na casa de praia, atrás do NAT do roteador doméstico,
ao servidor do lab:

- o PC navega na internet normalmente;
- o PC não tem porta pública nem precisa de port forward em casa;
- o PC inicia o túnel WireGuard para o endpoint público do lab;
- o servidor usa uma interface dedicada (`wg2`, `10.0.100.0/24`);
- o PC recebe `10.0.100.10/24` e o servidor `10.0.100.1/24`;
- o teste final é `ssh labuser@10.0.100.1` a partir do PC.

A VPN existente do lab (`wg0`/`wg1`, `10.0.99.0/24`) não é alterada.

## Cenário real

```text
Casa de praia (fora do lab)
┌─────────────────────────────────────────────────────┐
│  PC físico (Windows/Linux/macOS)                    │
│  wg0 10.0.100.10/24                                 │
│  rede local da casa: DHCP, atrás do NAT do roteador │
└───────────────────────┬─────────────────────────────┘
                        │ UDP 51821 de saída
                        │ endpoint: IP público do lab:51821
                        ▼
                    Internet
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│  Host do lab                                        │
│  publica 51821/udp -> servidor:51821                │
│  (equivalente ao port forward do roteador)          │
└───────────────────────┬─────────────────────────────┘
                        │ DNAT
                        ▼
Lab — lab-net 10.0.0.0/24
┌─────────────────────────────────────────────────────┐
│  servidor 10.0.0.20                                 │
│  wg2 10.0.100.1/24  listen 51821/udp                │
│  wg0 10.0.99.1/24   listen 51820/udp (VPN do lab)   │
│                                                     │
│  casa 10.0.0.10 / wg1 10.0.99.10                    │
└─────────────────────────────────────────────────────┘
```

O PC da casa de praia não tem endereço na `lab-net`. Ele só alcança o
`servidor` pelo túnel até `10.0.100.1`.

### Nota sobre o NAT simulado do lab

No lab, o `servidor` está atrás do container `isp` (`10.0.0.1`). Neste
exercício, o **host publica** `51821/udp` diretamente para o `servidor`; isso
representa o port forward do roteador/cloud do lab. O NAT do container `isp`
continua sendo o NAT interno do lab e **não** é usado nesse caminho.

Para o tráfego atravessar o `isp`, seriam necessárias regras de DNAT no `isp`
e rotas no host. Isso é um desafio extra, não o foco do exercício.

## Endereçamento

| Elemento | Rede | Endereço | WireGuard | Porta |
|----------|------|----------|-----------|-------|
| PC da casa de praia | rede da casa (DHCP) | fornecido pelo roteador | `wg0 10.0.100.10/24` | — |
| Roteador da casa | NAT de saída | IP público da operadora | — | — |
| Host do lab | IP público ou LAN | `<IP_PUBLICO_DO_LAB>` | — | publica `51821/udp` |
| Servidor — wg2 | `lab-net 10.0.0.0/24` | `10.0.0.20` | `wg2 10.0.100.1/24` | `51821/udp` |
| Servidor — wg0 do lab | `lab-net` | `10.0.0.20` | `wg0 10.0.99.1/24` | `51820/udp` |
| Casa do lab | `lab-net` | `10.0.0.10` | `wg1 10.0.99.10/24` | — |

## Pré-requisitos

- Um PC na casa de praia com internet:
  - Windows 10/11, Linux ou macOS;
  - cliente WireGuard instalado;
  - cliente SSH (no Windows 10/11, o OpenSSH Client opcional).
- O PC pode ser um notebook ou desktop. Para testar sem hardware, use uma VM
  na rede da casa; o importante é ser um host **fora do lab**, não um
  container na `lab-net`.
- Lab rodando via Compose.
- Porta **51821/udp** livre no host do lab.
- O host do lab precisa ser alcançável pelo PC:
  - IP público + port forward no roteador; ou
  - VM/cloud com UDP `51821` liberado no security group; ou
  - VPS/relay público, caso o lab esteja atrás de CGNAT.
- Credenciais de laboratório `labuser` / `labpass`.
- Um canal para copiar a chave **pública** do PC para o servidor (a privada
  nunca sai do PC).

## Passo 0 — Baseline do lab

```bash
./scripts/compose.sh ps
./scripts/vpn.sh status
podman exec servidor wg show wg0
```

Troque `podman` por `docker` se for o caso. Resultado esperado: `wg0` com o
peer da casa e handshake recente.

## Passo 1 — Publicar o endpoint do lab

O servidor escuta WireGuard em `51821/udp`. Para um PC externo, essa porta
precisa chegar ao container `servidor`.

### 1.1 Override do Compose

Crie `compose.praia.yaml` apenas com a publicação da porta. Não há serviço de
container para a casa de praia; o PC é externo.

```yaml
services:
  servidor:
    ports:
      - "51821:51821/udp"
```

Se você criou o `compose.praia.yaml` da versão anterior (com o serviço
`casa-praia`), substitua-o por este. O PC não é um container.

### 1.2 Subir o servidor com a porta

```bash
# Podman
podman-compose -f docker-compose.yml -f compose.praia.yaml up -d --force-recreate servidor

# Docker
docker compose -f docker-compose.yml -f compose.praia.yaml up -d --force-recreate servidor
```

O `servidor` foi recriado; restaure a VPN existente do lab:

```bash
./scripts/vpn.sh start
```

Confira:

```bash
podman port servidor 51821/udp
# ou: docker port servidor 51821/udp
```

Resultado esperado (algo como):

```text
0.0.0.0:51821
```

### 1.3 Liberar no roteador/cloud

- **Lab em casa:** faça port forward de **UDP 51821** para o IP LAN do host
  que roda Podman/Docker. Libere também a porta no firewall do host.
- **Lab em cloud:** libere **UDP 51821** no security group/firewall da VM.
- **Teste local:** se o PC estiver na mesma LAN do host, use o IP LAN do host
  como endpoint. Isso valida a configuração, mas não prova a travessia pela
  internet.

Descubra o IP público do lab:

```bash
curl -4 ifconfig.me
```

Se o IP público retornado for diferente do IP WAN mostrado no roteador, você
pode estar atrás de **CGNAT**. Nesse caso, port forward no roteador não
funciona; use um VPS/relay ou uma VPN de malha (veja os desafios).

## Passo 2 — Gerar a chave do servidor (`wg2`)

```bash
ENGINE=podman   # ou: ENGINE=docker

$ENGINE exec servidor bash -c '
  mkdir -p /etc/wireguard
  umask 077
  { [ -f /etc/wireguard/praia-servidor.key ] && [ -f /etc/wireguard/praia-servidor.pub ]; } || (
    wg genkey | tee /etc/wireguard/praia-servidor.key | wg pubkey > /etc/wireguard/praia-servidor.pub
  )
  chmod 600 /etc/wireguard/praia-servidor.key
'

SERVIDOR_PRAIA_PUB=$($ENGINE exec servidor cat /etc/wireguard/praia-servidor.pub)
echo "Chave pública do servidor wg2: $SERVIDOR_PRAIA_PUB"
```

A chave privada fica no volume `rede-lab-wg-servidor` e nunca deve ser
copiada para o PC. O PC só precisa da chave **pública** acima.

## Passo 3 — Gerar a chave e a configuração no PC

A chave privada do PC fica no PC. O servidor só precisa da chave **pública**.

### Windows 10/11

1. Instale o cliente oficial: <https://www.wireguard.com/install/>.
2. Abra o WireGuard e escolha **Add Tunnel → Add empty tunnel...**.
3. Dê o nome `praia`. O app gera um par de chaves e mostra a **public key**.
4. Copie essa chave pública; ela será usada no servidor.
5. Substitua o conteúdo pelo modelo abaixo, mantendo a `PrivateKey` gerada
   pelo app:

```ini
[Interface]
PrivateKey = <chave-privada-gerada-pelo-app>
Address = 10.0.100.10/24

[Peer]
PublicKey = <SERVIDOR_PRAIA_PUB>
Endpoint = <IP_PUBLICO_DO_LAB>:51821
AllowedIPs = 10.0.100.1/32
PersistentKeepalive = 25
```

6. Salve. Ainda não ative se o peer do servidor não existir; o app pode ficar
   tentando o handshake até o passo 4.
7. Deixe **Block untunneled traffic** desmarcado neste exercício; não queremos
   bloquear a internet normal do PC.

> Não configure `DNS = 10.0.100.1` a menos que o servidor tenha um DNS
> escutando nesse IP. Para este exercício, omita `DNS` ou use um DNS público.

### Linux

```bash
sudo apt install wireguard-tools openssh-client   # Debian/Ubuntu
# ou: sudo dnf install wireguard-tools openssh-clients

sudo mkdir -p /etc/wireguard
sudo sh -c 'umask 077; wg genkey > /etc/wireguard/praia.key; wg pubkey < /etc/wireguard/praia.key > /etc/wireguard/praia.pub'
sudo cat /etc/wireguard/praia.pub
```

Copie o conteúdo de `/etc/wireguard/praia.pub` para cadastrar no servidor.
Crie `/etc/wireguard/wg0.conf`:

```ini
[Interface]
PrivateKey = <conteúdo-do-arquivo-/etc/wireguard/praia.key>
Address = 10.0.100.10/24

[Peer]
PublicKey = <SERVIDOR_PRAIA_PUB>
Endpoint = <IP_PUBLICO_DO_LAB>:51821
AllowedIPs = 10.0.100.1/32
PersistentKeepalive = 25
```

Proteja o arquivo:

```bash
sudo chmod 600 /etc/wireguard/wg0.conf
```

Ative depois de cadastrar o peer no servidor:

```bash
sudo wg-quick up wg0
sudo wg show
```

### macOS

Use o app oficial WireGuard, como no Windows: **Add empty tunnel**, copie a
chave pública, cole a configuração e salve. O `ssh` já vem no sistema.

## Passo 4 — Cadastrar o PC no `wg2` do servidor

Use a chave pública que o PC gerou:

```bash
PRAIA_PUB='<CHAVE_PUBLICA_DO_PC>'

$ENGINE exec servidor bash -c "
  ip link del wg2 2>/dev/null || true
  ip link add wg2 type wireguard
  ip address add 10.0.100.1/24 dev wg2
  wg set wg2 private-key /etc/wireguard/praia-servidor.key listen-port 51821
  wg set wg2 peer '$PRAIA_PUB' allowed-ips 10.0.100.10/32
  ip link set wg2 up
"
```

Confira:

```bash
$ENGINE exec servidor wg show wg2
```

Resultado esperado:

```text
interface: wg2
  listening port: 51821

peer: <chave-publica-do-pc>
  allowed ips: 10.0.100.10/32
```

`AllowedIPs = 10.0.100.10/32` é o menor escopo: o servidor aceita apenas o IP
WireGuard do PC e não libera a `lab-net` por padrão.

> A configuração de `wg2` acima é de runtime. Se o container `servidor` for
> recriado, ela desaparece. Para persistir, veja o desafio 4.

## Passo 5 — Ativar o túnel e testar

### Windows

Ative a tunnel `praia` no app e abra o PowerShell:

```powershell
ping 10.0.100.1
ssh -o StrictHostKeyChecking=no labuser@10.0.100.1 "echo PRAIA_OK; whoami"
```

Se `ssh` não existir, instale o recurso opcional **OpenSSH Client** em
Configurações → Aplicativos → Recursos opcionais. A senha do lab é `labpass`.

### Linux

```bash
sudo wg-quick up wg0
ping -c 3 10.0.100.1
ssh -o StrictHostKeyChecking=no labuser@10.0.100.1 'echo PRAIA_OK; id -un'
```

### Handshake dos dois lados

```bash
# Servidor
$ENGINE exec servidor wg show wg2

# PC Linux
sudo wg show

# PC Windows: veja o status no app WireGuard
```

Resultado esperado:

- `latest handshake` recente nos dois lados;
- `PRAIA_OK`;
- `labuser` (ou o usuário equivalente no Windows).

Se o `ping` falhar mas o SSH funcionar, o túnel está OK; alguns firewalls
bloqueiam ICMP. O SSH em TCP é o teste definitivo.

## Passo 6 — Conferir rotas e isolamento

### PC Linux

```bash
# Deve sair por wg0
ip route get 10.0.100.1

# Não deve sair por wg0; é a rota normal da internet
ip route get 10.0.0.20

# Mostra o endereço do PC na rede da casa e no túnel
ip -brief addr
```

### PC Windows

```powershell
route print
tracert 10.0.100.1
```

O `AllowedIPs` do PC cobre apenas `10.0.100.1/32`; a `lab-net`
(`10.0.0.0/24`) não está no túnel. Para acessar `10.0.0.20`, veja o desafio 1.

Isso é o esperado: a casa de praia é um host externo e só alcança o IP do
túnel. O PC não envia a `lab-net` pelo túnel, e o servidor não configura
forwarding/NAT para o peer por padrão.

## Passo 7 — Limpeza

No PC:

- Windows/macOS: desative e remova a tunnel `praia` no app.
- Linux:

  ```bash
  sudo wg-quick down wg0
  sudo rm -f /etc/wireguard/wg0.conf /etc/wireguard/praia.key /etc/wireguard/praia.pub
  ```

No servidor:

```bash
PRAIA_PUB='<CHAVE_PUBLICA_DO_PC>'
$ENGINE exec servidor bash -c "
  wg set wg2 peer '$PRAIA_PUB' remove 2>/dev/null || true
  ip link del wg2 2>/dev/null || true
  rm -f /etc/wireguard/praia-servidor.key /etc/wireguard/praia-servidor.pub
"
```

Remova a publicação da porta e restaure o servidor sem o override:

```bash
./scripts/compose.sh up --force-recreate servidor
```

O wrapper `compose.sh up` já executa `./scripts/vpn.sh start` no final. Se
recriar o servidor por outro caminho, rode `./scripts/vpn.sh start`
manualmente.

Remova o port forward/regra de firewall do roteador ou cloud. Apague
`compose.praia.yaml` se não quiser manter o exercício.

Não remova o volume `rede-lab-wg-servidor`: ele também guarda as chaves da VPN
existente do lab.

## Troubleshooting

### O handshake não acontece

1. Confirme que o PC alcança o endpoint:

   ```bash
   # No PC (Linux/macOS) ou PowerShell com Test-NetConnection para TCP;
   # para UDP, o teste real é o handshake do WireGuard.
   ping <IP_PUBLICO_DO_LAB>
   ```

2. Confirme a publicação no host:

   ```bash
   podman port servidor 51821/udp
   # ou: docker port servidor 51821/udp
   ```

3. Confirme o `listen-port` no servidor:

   ```bash
   $ENGINE exec servidor wg show wg2
   ```

4. Confirme o endpoint no PC:

   - Windows: status da tunnel no app;
   - Linux: `sudo wg show`.

5. Verifique o port forward/security group para **UDP 51821** e o firewall
   do host.

6. Confirme que a chave pública do PC foi copiada exatamente e que o peer
   existe no `wg2`.

7. Se o IP público do lab for CGNAT, o port forward não funciona. Use VPS ou
   relay.

### A porta aparece só em `127.0.0.1`

Se `podman port servidor 51821/udp` mostrar `127.0.0.1:51821`, o PC externo
não conseguirá chegar. Confirme que a publicação está em `0.0.0.0` e que o
firewall do host permite UDP `51821`. Em Podman rootless, revise a
configuração de portas do engine; se necessário, use um proxy/relay.

### Handshake OK, mas SSH não conecta

- Confirme `AllowedIPs = 10.0.100.1/32` no PC.
- Confirme `Address = 10.0.100.1/24` no `wg2` do servidor.
- Confirme que o `sshd` está de pé:

  ```bash
  $ENGINE exec servidor pgrep -x sshd
  ```

- Use `labuser`, não `root` (o sshd tem `AllowUsers labuser`).
- No Windows, confirme que o **OpenSSH Client** está instalado.
- Teste `ssh -v labuser@10.0.100.1` para ver onde para.

### `ssh: command not found` no Windows

Instale **OpenSSH Client** em Configurações → Aplicativos → Recursos
opcionais, ou use PuTTY.

### O túnel ativa, mas a internet para de funcionar

Provavelmente há `AllowedIPs = 0.0.0.0/0` ou um `DNS` inválido. Para este
exercício, use `AllowedIPs = 10.0.100.1/32` e não configure `DNS` para
`10.0.100.1`. Se quiser túnel total, veja o desafio 3.

### `Endpoint` não resolve ou tenta IPv6

Use o IP público IPv4 diretamente. Para IPv6, o formato é
`[2001:db8::1]:51821`, e o firewall/port forward precisa permitir UDP.

### `wg-quick` retorna `Operation not permitted`

No Linux, rode com `sudo`. Em containers, seria `NET_ADMIN`; aqui o PC é um
host real.

### O container `servidor` foi recriado e o `wg2` sumiu

A interface `wg2` é criada em runtime. Repita o passo 4. O `vpn.sh start`
recria apenas `wg0`/`wg1`; ele não gerencia `wg2`.

### A porta `51821` já está em uso

Escolha outra porta no override, no `listen-port` e no endpoint:

```yaml
ports:
  - "51822:51822/udp"
```

```bash
wg set wg2 listen-port 51822
# Endpoint no PC: <IP_PUBLICO_DO_LAB>:51822
```

Atualize também o port forward do roteador/cloud.

### O lab está atrás de CGNAT

O PC não conseguirá iniciar o túnel para um IP que não é roteável. Opções:

- VPS com IP público fazendo relay/port forward para o lab;
- VPN de malha (Tailscale/Netbird) como transporte até um endpoint público;
- usar um túnel reverso para um VPS.

Documente a opção escolhida e o rollback.

## Desafios

1. **Acessar `10.0.0.20` a partir do PC.**
   Adicione `10.0.0.20/32` (ou `10.0.0.0/24`) ao `AllowedIPs` do PC. Para
   alcançar outros hosts da `lab-net`, habilite `net.ipv4.ip_forward=1` no
   servidor, permita a chain `FORWARD` e trate NAT/rotas de retorno. Teste e
   documente os riscos de ampliar o escopo.

2. **Acessar o PC a partir da `casa` do lab.**
   O servidor precisa encaminhar entre `wg2` e `wg0`/`lab-net`; a `casa`
   precisa de rota para `10.0.100.0/24` via servidor. Ajuste `AllowedIPs` dos
   dois lados.

3. **Túnel total (`0.0.0.0/0`).**
   Faça o PC enviar todo o tráfego pelo lab, configure NAT no servidor e DNS.
   Cuidado com kill switch, MTU e perda de conectividade.

4. **Persistir o `wg2`.**
   Crie `wg2.conf` no servidor e um script/systemd para subir após o
   `compose up`. Guarde as chaves no volume e não no repositório.

5. **Endpoint público sem IP público.**
   Use um VPS como relay: o lab conecta ao VPS e o PC conecta ao VPS, ou o
   VPS faz DNAT para o lab por um túnel.

6. **Restringir o firewall.**
   Em vez de expor `51821/udp` para o mundo, permita apenas o IP público da
   casa de praia. Documente a regra e o rollback.

7. **Trocar senha por chave SSH.**
   Gere uma chave no PC, adicione a pública em
   `/home/labuser/.ssh/authorized_keys` no servidor e remova o uso de
   `labpass`.

## Checklist

- [ ] PC físico (ou VM) na rede da casa de praia, fora do lab.
- [ ] `servidor` publica `51821/udp`.
- [ ] Port forward/security group libera UDP `51821`.
- [ ] `wg2` no servidor em `10.0.100.1/24`.
- [ ] PC com `wg0 10.0.100.10/24`.
- [ ] Chave pública do PC cadastrada no `wg2`.
- [ ] Handshake recente nos dois lados.
- [ ] `ssh labuser@10.0.100.1` retorna `PRAIA_OK`.
- [ ] `AllowedIPs` mínimo (`10.0.100.1/32` no PC).
- [ ] Port forward removido e `wg2` limpo ao final.

## Segurança

- Este é um lab: `labpass` e `StrictHostKeyChecking=no` são intencionais.
- A chave privada do PC nunca sai do PC; a do servidor nunca sai do volume.
- Não versione chaves privadas; o `.gitignore` e o `scripts/guard.sh` ajudam.
- Exponha apenas UDP `51821`; não publique SSH do servidor para a internet.
- Restrinja o firewall ao IP da casa de praia quando possível.
- Use `AllowedIPs` mínimo. Evite `0.0.0.0/0` sem necessidade.
- Em produção, use chaves SSH, endpoint com nome DNS, MFA/gestão de chaves e
  monitoramento.

## Referências

- [`wireguard.md`](wireguard.md) — configuração e testes da VPN do lab.
- [`vpn-operacao.md`](vpn-operacao.md) — operação do `vpn.sh`.
- [`compose.md`](compose.md) — uso do Compose.
- [`containers.html`](containers.html) — como entrar nos containers.
- [`nat.html`](nat.html) — camada de NAT do lab.
