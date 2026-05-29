FROM debian:bookworm-slim

ARG USERNAME=sshbox
ARG UID=1000
ARG GID=100

ENV USERNAME=${USERNAME}
ENV HOME_DIR=/home/${USERNAME}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-server \
        git \
        iputils-ping \
        netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Extra tools for interactive usage
# RUN apt-get update && apt-get install -y --no-install-recommends \
#     sudo \
#     curl \
#     wget \
#     nano \
#     less \
#     procps \
#     iproute2 \
#     && rm -rf /var/lib/apt/lists/*

RUN useradd -u "${UID}" -g "${GID}" -m -d "${HOME_DIR}" -s /bin/bash "${USERNAME}" \
    && mkdir -p /run/sshd \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && echo "PrintMotd no" >> /etc/ssh/sshd_config \
    && echo "PrintLastLog no" >> /etc/ssh/sshd_config \
    && sed -i '/pam_motd.so/s/^/#/' /etc/pam.d/sshd

COPY entry-point.sh /entry-point.sh
RUN chmod +x /entry-point.sh

EXPOSE 22

# Note: Files created in /home/remote during image build are hidden when
# /home/remote is bind-mounted from the host. Docker never copies image
# contents into bind mounts. The entrypoint therefore initializes an empty
# mounted home directory by copying the default files from /etc/skel, when needed.
# This Dockerfile is only executed on build; we need to check on each start.

ENTRYPOINT ["/entry-point.sh"]
