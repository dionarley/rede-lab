# Atalhos do Rede Lab
SHELL := /bin/bash

.PHONY: help network deploy compose-up compose-down compose-ps compose-logs compose-config compose-reset vpn vpn-status vpn-test ssh doctor guard hooks destroy clean

help:
	@echo "Rede Lab - alvos disponíveis:"
	@echo "  make network     - cria a rede bridge"
	@echo "  make deploy      - sobe o lab via scripts (containers + VPN)"
	@echo "  make compose-up  - sobe o lab via Docker/Podman Compose"
	@echo "  make compose-down- derruba o lab via Compose"
	@echo "  make compose-ps  - lista os serviços Compose"
	@echo "  make compose-logs- logs do Compose"
	@echo "  make compose-config - valida o docker-compose.yml"
	@echo "  make compose-reset - derruba e remove volumes (chaves WG)"
	@echo "  make vpn         - sobe o túnel WireGuard"
	@echo "  make vpn-status  - mostra o status da VPN"
	@echo "  make vpn-test    - testa ping/SSH pelo túnel"
	@echo "  make ssh         - testa SSH casa -> servidor"
	@echo "  make doctor      - diagnostica dependências e saúde"
	@echo "  make guard       - verifica se há .env/segredos rastreados"
	@echo "  make hooks       - instala o hook de pre-commit"
	@echo "  make destroy     - derruba o lab"
	@echo "  make clean       - derruba e remove imagens locais"

network:
	./network/lab-network.sh

deploy:
	./scripts/deploy.sh

compose-up:
	./scripts/compose.sh up

compose-down:
	./scripts/compose.sh down

compose-ps:
	./scripts/compose.sh ps

compose-logs:
	./scripts/compose.sh logs

compose-config:
	./scripts/compose.sh config

compose-reset:
	./scripts/compose.sh reset

vpn:
	./scripts/vpn.sh start

vpn-status:
	./scripts/vpn.sh status

vpn-test:
	./scripts/vpn.sh test

ssh:
	./scripts/test-ssh.sh

doctor:
	./scripts/doctor.sh

guard:
	./scripts/guard.sh

hooks:
	chmod +x .githooks/pre-commit scripts/guard.sh
	git config core.hooksPath .githooks
	@echo "Hook de pre-commit instalado (core.hooksPath=.githooks)."

destroy:
	./scripts/destroy.sh

clean: destroy
	@source scripts/common.sh && "$$ENGINE" rmi -f lab-isp lab-casa lab-servidor 2>/dev/null || true
