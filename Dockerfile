FROM debian:13

ENV DEBIAN_FRONTEND=noninteractive\
    CODEX_HOME=/codex-home
WORKDIR /work

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    iproute2 \
    iptables \
    lsb-release \
    nodejs \
    npm \
    openssh-client \
  && install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
  && chmod a+r /etc/apt/keyrings/docker.asc \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo ${VERSION_CODENAME}) stable" \
    > /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
  && npm i -g @openai/codex \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /codex-home
COPY scripts/sandbox-entrypoint.sh /usr/local/bin/sandbox-entrypoint.sh
RUN chmod +x /usr/local/bin/sandbox-entrypoint.sh

HEALTHCHECK --interval=10s --timeout=3s --retries=5 CMD docker info >/dev/null 2>&1 || exit 1

CMD ["/usr/local/bin/sandbox-entrypoint.sh"]
