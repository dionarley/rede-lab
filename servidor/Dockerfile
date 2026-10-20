# Servidor interno - servidor SSH + servidor WireGuard
FROM fedora:latest

RUN dnf -y install \
        openssh-server \
        wireguard-tools \
        iproute \
        iputils \
        procps-ng \
        nano \
    && dnf clean all && \
    ssh-keygen -A

COPY sshd_config /etc/ssh/sshd_config
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh && \
    useradd -m -s /bin/bash labuser && \
    echo 'labuser:labpass' | chpasswd && \
    mkdir -p /run/sshd

EXPOSE 22 51820/udp

ENTRYPOINT ["/entrypoint.sh"]
