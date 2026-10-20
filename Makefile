# Atalhos do Rede Lab
SHELL := /bin/bash

.PHONY: help network deploy vpn vpn-status vpn-test ssh destroy clean

help:
	@echo "Rede Lab - alvos disponíveis:"
	@echo "  make network     - cria a rede bridge"
	@echo "  make deploy      - sobe o lab completo (containers + VPN)"
	@echo "  make vpn         - sobe o túnel WireGuard"
	@echo "  make vpn-status  - mostra o status da VPN"
	@echo "  make vpn-test    - testa ping/SSH pelo túnel"
	@echo "  make ssh         - testa SSH casa -> servidor"
	@echo "  make destroy     - derruba o lab"
	@echo "  make clean       - derruba e remove imagens locais"

network:
	./network/lab-network.sh

deploy:
	./scripts/deploy.sh

vpn:
	./scripts/vpn.sh start

vpn-status:
	./scripts/vpn.sh status

vpn-test:
	./scripts/vpn.sh test

ssh:
	./scripts/test-ssh.sh

destroy:
	./scripts/destroy.sh

clean: destroy
	@source scripts/common.sh && "$$ENGINE" rmi -f lab-isp lab-casa lab-servidor 2>/dev/null || true
