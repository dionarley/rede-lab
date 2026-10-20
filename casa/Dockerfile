# PC de Casa - cliente SSH + cliente WireGuard
FROM fedora:latest

RUN dnf -y install \
        openssh-clients \
        wireguard-tools \
        iproute \
        iputils \
        procps-ng \
        nano \
        curl \
    && dnf clean all

COPY ssh_config /home/labuser/.ssh/config
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh && \
    mkdir -p /home/labuser/.ssh && chmod 700 /home/labuser/.ssh && \
    chmod 600 /home/labuser/.ssh/config 2>/dev/null || true

ENTRYPOINT ["/entrypoint.sh"]
