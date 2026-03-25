# Setup Guide

This guide covers first-time setup. Keep architecture questions in [ARCHITECTURE.md](ARCHITECTURE.md) and project rules in [GUIDELINES.md](GUIDELINES.md).

## Host Layout

Prepare these paths:

- `state/home`
- `state/projects`
- `state/references`
- `state/scratch`
- `state/ssh`
- `config`

Inside the container, they appear under `/home/$WORKBENCH_USER` and `/workspace/*`.

## First-Time Setup

```bash
mkdir -p state/home state/projects state/references state/scratch state/ssh config
chown -R "$(id -u):$(id -g)" state
cp .env.example .env
cp config/gitconfig.example config/gitconfig
```

Edit:

- `.env`
- `config/gitconfig`

## Required `.env` Values

The minimum settings for first boot are:

- `TZ`
- `WORKBENCH_USER`
- `WORKBENCH_UID`
- `WORKBENCH_GID`

The UID and GID must match the owner of the bind-mounted `state/` tree or startup will fail.

The same file also carries pinned build values for Node, the three AI CLIs, and `claude-delegator`, plus optional API keys:

- `ANTHROPIC_API_KEY`
- `GEMINI_API_KEY`
- `OPENAI_API_KEY`

## Build And Start

```bash
docker compose up -d --build
docker exec -it the-ai-crowd bash -l
```

The container runs as the configured non-root user and starts in `/workspace/projects`.

## Optional Docker-Aware Overlay

```bash
docker compose -f compose.yaml -f compose.docker.yaml up -d
```

This overlay enables Docker-aware mode by setting `AI_CROWD_ENABLE_DOCKER=true`, passing `DOCKER_GID`, and mounting `/var/run/docker.sock`.

Keep the wording precise: the Compose overlay exists, but the image does not currently install the `docker` CLI.
