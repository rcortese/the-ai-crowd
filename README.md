# The AI Crowd

A homelab AI workbench for Claude-led, multi-model development workflows.

## What it is

The AI Crowd is a single internal toolbox container where Claude acts as the primary orchestrator and Gemini CLI plus Codex CLI are available as local delegated workers or direct fallback tools.

## MVP

This repository now includes a runnable phase-one scaffold:

- `Dockerfile` for an Ubuntu 24.04-based workbench image
- `docker-compose.yml` for a persistent, terminal-first runtime
- pinned build args for Node 20 and the three AI CLIs
- curated mounts for projects, references, scratch space, and persistent home
- a non-root entrypoint that initializes operator state cleanly

## Quick Start

1. Copy `.env.example` to `.env`.
2. Set API keys and adjust UID, GID, and paths for your host.
   - for Git identity and other shell defaults, prefer files under `./config/` instead of adding more variables to `.env`
3. Create the local mount targets:
   - `mkdir -p state/home state/projects state/references state/scratch state/ssh config`
   - `chown -R "$(id -u):$(id -g)" state`
   - `cp config/gitconfig.example config/gitconfig` and edit as needed
4. Build and start the container:
   - `docker compose up -d --build`
5. Enter the shell:
   - `docker exec -it the-ai-crowd bash -l`
6. Enable Docker-aware mode only when needed:
   - `docker compose -f docker-compose.yml -f docker-compose.docker.yml up -d`
   - set `DOCKER_GID` in `.env` to the host group that owns `docker.sock`

## Filesystem Model

- `/workspace/projects`: active repositories, read-write
- `/workspace/references`: read-only reference material
- `/workspace/scratch`: disposable working area
- `/home/$WORKBENCH_USER`: persistent user state

## Static Config

The workbench now mounts `./config` read-only at `/workspace/config`.

- Use `./config/gitconfig` for persistent Git identity and aliases that should be injected into the container as static configuration.
- Keep `.env` focused on runtime secrets, UID/GID alignment, and capability toggles.

## Docker Access

The base compose stack does not mount `docker.sock`. When you need container inspection or control, start the workbench with `docker-compose.docker.yml` layered on top and set `DOCKER_GID` to the host Docker group so access remains explicit and usable.

## Notes

The CLI npm package names and versions are pinned as build args in the image. If upstream package names or auth flows change, update those args rather than mutating a running container by hand. The image also exposes `fd` and `bat` under the expected command names for Ubuntu-based shells.
The bind-mounted directories under `state/` must be writable by `WORKBENCH_UID:WORKBENCH_GID` from `.env` or startup will fail.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) and [GUIDELINES.md](GUIDELINES.md).
