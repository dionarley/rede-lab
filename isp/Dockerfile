# ISP / Gateway com NAT e IP forwarding
FROM fedora:latest

RUN dnf -y install iptables iptables-nft iproute iputils procps-ng openssh-clients coreutils && \
    dnf clean all

# Permite IP forwarding no container (precisa de --sysctl net.ipv4.ip_forward=1 ao rodar)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
