# Implementação e Testes de SSH

## Objetivo

Permitir que o **PC de Casa** acesse o **Servidor** via SSH através do túnel WireGuard, simulando acesso remoto seguro a um servidor doméstico através de um provedor de internet.

## Configuração do Servidor (`servidor/sshd_config`)

- Porta: `22`
- Autenticação por senha habilitada para fins de teste (`usuário: labuser / senha: labpass`)
- Permitir login do root: desabilitado
- Acesso apenas pela rede interna / túnel WG

## Configuração do Cliente (`casa/ssh_config`)

- Host `servidor-wg`
  - HostName `10.0.99.1` (IP do servidor dentro do túnel WireGuard)
  - User `labuser`
  - Port `22`
  - StrictHostKeyChecking `no` (apenas para lab)

## Passo a passo de teste

1. Suba o lab:
   ```bash
   ./scripts/deploy.sh
   ```

2. Acesse o container casa:
   ```bash
   podman exec -it casa bash
   ```

3. Teste o SSH diretamente pelo IP do túnel:
   ```bash
   ssh labuser@10.0.99.1
   ```
   Senha: `labpass`

4. Ou use o alias configurado:
   ```bash
   ssh servidor-wg
   ```

5. Do lado do servidor, verifique quem está conectado:
   ```bash
   podman exec -it servidor who
   ```

## Resultado esperado

- Conexão SSH estabelecida com sucesso.
- Prompt do servidor exibido a partir do container casa.
- Todo o tráfego SSH trafega dentro do túnel WireGuard (UDP 51820).

## Arquivo de registro

Veja `testes/resultado-ssh.txt` após executar `./scripts/test-ssh.sh`.
