# Setup Guide

This guide covers first-time setup. Keep architecture questions in [ARCHITECTURE.md](ARCHITECTURE.md) and project rules in [GUIDELINES.md](GUIDELINES.md).

## Host Layout

Prepare these paths:

- `data/home`
- `data/projects`
- `data/references`
- `data/scratch`
- `data/ssh`

Inside the container, they appear under `/home/$WORKBENCH_USER` and `/workspace/*`.

## Path A: Pull-first (recommended)

Use this path to run the published image without triggering a local build.

**1. Create the data directories:**

```bash
mkdir -p data/home data/projects data/references data/scratch data/ssh
chown -R "$(id -u):$(id -g)" data
cp .env.example .env
```

**2. Edit `.env`:**

Set `WORKBENCH_UID` and `WORKBENCH_GID` to match the owner of the `data/` tree, or container startup will fail (exit 70).

Keep `WORKBENCH_USER=operator`. The published image has `USERNAME=operator` baked in; changing this value requires a local build (Path B).

**3. Pull and start:**

```bash
docker pull rcortese/the-ai-crowd:latest
docker compose up -d
docker exec -it the-ai-crowd bash -l
```

The container runs as the configured non-root user and starts in `/workspace/projects`.

Build override variables (`NODE_VERSION`, `CLAUDE_CODE_VERSION`, etc.) in `.env` are ignored in this path.

## Path B: Build from source (maintainers / custom builds)

Use this path to modify the image, change pinned CLI versions, or change `WORKBENCH_USER`. Requires `compose.build.yaml` in the project root (included in the repository).

Migration note: if you previously used `compose.override.yaml`, replace it with `compose.build.yaml` in local build commands.

**1.** Complete steps 1–3 from Path A.

**2.** Uncomment the relevant build override variables in `.env`.

**3.** Build and start:

```bash
docker compose -f compose.yaml -f compose.build.yaml up -d --build
docker exec -it the-ai-crowd bash -l
```

## Required `.env` Values

The minimum settings for first boot are:

- `TZ`
- `WORKBENCH_USER`
- `WORKBENCH_UID`
- `WORKBENCH_GID`

Optional API keys (required for the respective CLI to function):

- `ANTHROPIC_API_KEY`
- `GEMINI_API_KEY`
- `OPENAI_API_KEY`

## Optional Docker-Aware Overlay

```bash
docker compose -f compose.yaml -f compose.docker.yaml up -d
```

This overlay enables Docker-aware mode by setting `AI_CROWD_ENABLE_DOCKER=true`, passing `DOCKER_GID`, and mounting `/var/run/docker.sock`.

Keep the wording precise: the image already installs the `docker` CLI. The Compose overlay adds access to the host daemon by mounting `/var/run/docker.sock` and adding the matching Docker group.
