# Operação da VPN WireGuard

Guia prático para operar a instância VPN do lab.

## Comandos

```bash
./scripts/vpn.sh start     # cria/ativa as interfaces wg0 e wg1
./scripts/vpn.sh status    # handshake, peers e transferência
./scripts/vpn.sh test      # ping + SSH pelo túnel
./scripts/vpn.sh stop      # remove as interfaces
./scripts/vpn.sh restart   # stop + start
```

## O que o `start` faz

1. Gera chaves se ainda não existirem (dentro dos containers).
2. Configura `wg0` no servidor:
   - IP `${WG_SERVIDOR_IP}/24`
   - `listen-port ${WG_PORT}`
   - peer = casa
3. Configura `wg1` na casa:
   - IP `${WG_CASA_IP}/24`
   - endpoint `${SERVIDOR_IP}:${WG_PORT}`
   - peer = servidor
4. Ativa as interfaces e mostra o status.

## Verificação de saúde

Um túnel saudável mostra, nos dois lados:

```
latest handshake: <há poucos segundos>
transfer: <bytes> received, <bytes> sent
```

E, na casa, o endpoint apontando para o servidor:

```
endpoint: 10.0.0.20:51820
```

## Troubleshooting

### `Connection timed out` no SSH

- Confirme que o servidor escuta na porta esperada:
  ```bash
  ./scripts/vpn.sh status | grep "listening port"
  ```
- Confira se o endpoint da casa usa a mesma porta:
  ```bash
  ./scripts/vpn.sh status | grep endpoint
  ```
- Se a porta divergir, rode `./scripts/vpn.sh restart`.

### `ping: socket: Operation not permitted`

Acontece em Podman rootless por falta de `CAP_NET_RAW`. Não afeta o SSH
(TCP). Para habilitar ping, rode o container da casa com `--cap-add NET_RAW`.

### Handshake não aparece

- Verifique se os containers estão de pé:
  ```bash
  podman ps   # ou docker ps
  ```
- Confirme que as chaves públicas de cada lado batem com o peer configurado.
- Verifique se o IP do servidor está correto no endpoint (`10.0.0.20`).

### NAT do ISP

O `iptables` pode falhar em rootless sem módulos do kernel. O lab de
SSH+WireGuard continua funcionando porque casa e servidor estão na mesma
bridge e se comunicam diretamente. O ISP existe para simular o papel de
gateway/provedor.
