FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_MAJOR=20
ARG NODE_VERSION=20.20.1
ARG USERNAME=operator
ARG USER_UID=1000
ARG USER_GID=1000
ARG CLAUDE_CODE_PACKAGE=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=1.0.43
ARG GEMINI_CLI_PACKAGE=@google/gemini-cli
ARG GEMINI_CLI_VERSION=0.1.18
ARG CODEX_CLI_PACKAGE=@openai/codex
ARG CODEX_CLI_VERSION=0.26.0
ARG CLAUDE_DELEGATOR_COMMIT
ARG CLAUDE_DELEGATOR_SHA256=087d8f4254fadb607360df8f04a21ffb2cee042d2b6a355a7f99d44c53aef27f
ARG DOCKER_CE_CLI_VERSION

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    SHELL=/bin/bash \
    HOME=/home/${USERNAME}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get -o Acquire::Retries=3 update && \
    apt-get install -y --no-install-recommends \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg \
      lsb-release && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
      gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
      gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    . /etc/os-release && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      zsh \
      tmux \
      fzf \
      git \
      git-lfs \
      gh \
      ripgrep \
      fd-find \
      bat \
      less \
      tree \
      jq \
      yq \
      gawk \
      sed \
      vim \
      nano \
      zip \
      unzip \
      tar \
      rsync \
      wget \
      dnsutils \
      iputils-ping \
      htop \
      nodejs=${NODE_VERSION}-1nodesource1 \
      python3 \
      python3-pip \
      pipx \
      build-essential \
      make \
      pkg-config \
      openssh-client \
      docker-ce-cli${DOCKER_CE_CLI_VERSION:+=${DOCKER_CE_CLI_VERSION}} && \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd && \
    ln -sf /usr/bin/batcat /usr/local/bin/bat && \
    if ! getent group "${USER_GID}" >/dev/null; then \
      groupadd --gid "${USER_GID}" "${USERNAME}"; \
    fi && \
    if id -u "${USERNAME}" >/dev/null 2>&1; then \
      usermod --gid "${USER_GID}" --home "/home/${USERNAME}" --shell /bin/bash "${USERNAME}"; \
    elif getent passwd "${USER_UID}" >/dev/null; then \
      existing_user="$(getent passwd "${USER_UID}" | cut -d: -f1)" && \
      usermod --login "${USERNAME}" --home "/home/${USERNAME}" --move-home --shell /bin/bash "${existing_user}" && \
      usermod --gid "${USER_GID}" "${USERNAME}"; \
    else \
      useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/bash "${USERNAME}"; \
    fi && \
    mkdir -p /workspace/projects /workspace/references /workspace/scratch /var/tmp/ai-crowd && \
    mkdir -p /home/${USERNAME} && \
    chown -R "${USER_UID}:${USER_GID}" /home/${USERNAME} /workspace /var/tmp/ai-crowd && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN npm install -g "${CLAUDE_CODE_PACKAGE}@${CLAUDE_CODE_VERSION}"
RUN npm install -g "${GEMINI_CLI_PACKAGE}@${GEMINI_CLI_VERSION}"
RUN npm install -g "${CODEX_CLI_PACKAGE}@${CODEX_CLI_VERSION}"

RUN mkdir -p /opt/claude-delegator \
    && tmp_archive="$(mktemp)" \
    && curl -fsSL --retry 5 --retry-all-errors --connect-timeout 10 \
      "https://codeload.github.com/jarrodwatts/claude-delegator/tar.gz/${CLAUDE_DELEGATOR_COMMIT}" \
      -o "${tmp_archive}" \
    && printf '%s  %s\n' "${CLAUDE_DELEGATOR_SHA256}" "${tmp_archive}" | sha256sum --check - \
    && tar -xz -C /opt/claude-delegator --strip-components=1 -f "${tmp_archive}" \
    && rm -f "${tmp_archive}" \
    && chown -R "${USER_UID}:${USER_GID}" /opt/claude-delegator

ENV CLAUDE_PLUGIN_ROOT=/opt/claude-delegator

COPY scripts/runtime/entrypoint.sh /usr/local/bin/ai-crowd-entrypoint
COPY scripts/runtime/healthcheck.sh /usr/local/bin/ai-crowd-healthcheck
COPY scripts/runtime/github.com.known_hosts /etc/ssh/ssh_known_hosts

RUN chmod 0755 /usr/local/bin/ai-crowd-entrypoint
RUN chmod 0755 /usr/local/bin/ai-crowd-healthcheck
RUN chmod 0644 /etc/ssh/ssh_known_hosts

USER ${USERNAME}
WORKDIR /workspace/projects

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 CMD ["/usr/local/bin/ai-crowd-healthcheck"]

ENTRYPOINT ["/usr/local/bin/ai-crowd-entrypoint"]
CMD ["bash", "-l"]
