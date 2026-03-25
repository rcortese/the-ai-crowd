# Setup Guide

This guide covers the first-time host setup for The AI Crowd. Keep architecture questions in [ARCHITECTURE.md](ARCHITECTURE.md) and project-level rules in [GUIDELINES.md](GUIDELINES.md).

## What you are preparing

The base runtime expects:

- a persistent home under `state/home`
- active repositories under `state/projects`
- reference material mounted read-only inside the container from `state/references`
- disposable work under `state/scratch`
- SSH material under `state/ssh`
- static operator config under `config`

Inside the container those mounts appear under `/home/$WORKBENCH_USER` and `/workspace/*`.

## First-Time Setup

Create the host directories:

```bash
mkdir -p state/home state/projects state/references state/scratch state/ssh config
```

Make sure the state tree is owned by the same UID and GID you will run inside the container:

```bash
chown -R "$(id -u):$(id -g)" state
```

Create your local config files:

```bash
cp .env.example .env
cp config/gitconfig.example config/gitconfig
```

Then edit:

- `.env`
- `config/gitconfig`

## Required `.env` values

The defaults live in [`.env.example`](../.env.example). The most important settings for first boot are:

- `TZ`
- `WORKBENCH_USER`
- `WORKBENCH_UID`
- `WORKBENCH_GID`

The UID and GID must match the owner of the bind-mounted `state/` directories. If they do not, the runtime entrypoint will fail when it tries to create or update state.

The same file also carries the pinned build values for:

- `NODE_MAJOR`
- `NODE_VERSION`
- `CLAUDE_CODE_VERSION`
- `GEMINI_CLI_VERSION`
- `CODEX_CLI_VERSION`
- `CLAUDE_DELEGATOR_COMMIT`
- `CLAUDE_DELEGATOR_SHA256`

And optional non-interactive auth values:

- `ANTHROPIC_API_KEY`
- `GEMINI_API_KEY`
- `OPENAI_API_KEY`

## Build And Start

Start the base workbench:

```bash
docker compose up -d --build
```

Enter the container shell:

```bash
docker exec -it the-ai-crowd bash -l
```

The image runs as the configured non-root user, starts in `/workspace/projects`, and uses `/usr/local/bin/ai-crowd-entrypoint` as its entrypoint.

## Optional Docker-Aware Overlay

If you want the Docker-aware overlay defined by the repository:

```bash
docker compose -f compose.yaml -f compose.docker.yaml up -d
```

That overlay:

- sets `AI_CROWD_ENABLE_DOCKER=true`
- adds the host Docker group from `DOCKER_GID`
- mounts `/var/run/docker.sock`

Keep the wording precise: the overlay is wired in the Compose files, but the image does not currently install the `docker` CLI. Treat it as an optional capability boundary, not as a fully documented in-container Docker workflow.
