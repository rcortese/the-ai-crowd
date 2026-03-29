[![Docker Pulls](https://img.shields.io/docker/pulls/rcortese/the-ai-crowd)](https://hub.docker.com/r/rcortese/the-ai-crowd)
[![CI](https://github.com/rcortese/the-ai-crowd/actions/workflows/ci.yml/badge.svg)](https://github.com/rcortese/the-ai-crowd/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/rcortese/the-ai-crowd)](LICENSE)

# The AI Crowd

The AI Crowd is a single-container AI workbench for terminal-first development. It bundles Claude Code, Gemini CLI, and Codex CLI into one persistent operator environment so you can keep auth, shell history, SSH material, and project state across restarts.

It is designed for technical users who want Claude to remain the primary orchestrator while Gemini and Codex stay available as local workers and fallbacks.

<p align="center">
  <img src="docs/the-it-crowd.png" alt="The AI Crowd" width="480">
</p>

## What You Get

- One container with Claude Code, Gemini CLI, Codex CLI, Git, SSH, and daily shell tooling already installed
- Persistent state through host bind mounts instead of mutable container snowflakes
- Local-first delegation through `claude-delegator`, which registers Gemini and Codex as stdio MCP workers for Claude
- An optional Docker-aware overlay when the workbench needs to talk to the host Docker daemon

## Good Fit

- You spend most of the day in a terminal and want multiple coding CLIs ready in one place
- You want a persistent operator workspace instead of reinstalling tools on each machine
- You want local delegation and shared filesystem context, not a browser IDE or multi-service platform

## How It Works

| Layer | What happens |
| --- | --- |
| Runtime | One Ubuntu 24.04 container runs all bundled CLIs |
| State | `data/home`, `data/projects`, `data/references`, `data/scratch`, and `data/ssh` persist on the host |
| Delegation | Claude can register Codex and Gemini as local stdio MCP workers at startup |
| Security shape | Non-root user, all Linux capabilities dropped, `no-new-privileges`, and `tmpfs` for `/tmp` and `/run` |
| Docker mode | Optional Compose overlay mounts `/var/run/docker.sock` and adds the Docker group |

## Quick Start

Prepare the bind mounts and copy the sample environment file:

```bash
mkdir -p data/home data/projects data/references data/scratch data/ssh
chown -R "$(id -u):$(id -g)" data
cp .env.example .env
```

Edit `.env` and set at least:

- `TZ`
- `WORKBENCH_UID`
- `WORKBENCH_GID`

If you want a pre-seeded Git config before first boot, copy the sample into the persistent home mount:

```bash
cp docs/gitconfig.example data/home/.gitconfig
```

Start the published image and open a login shell:

```bash
docker compose up -d
docker exec -it the-ai-crowd bash -l
```

Authenticate the bundled CLIs from inside the container:

```bash
claude auth login
gemini auth
codex
```

If you need Docker access from inside the workbench, restart with the Docker-aware overlay:

```bash
docker compose -f compose.yaml -f compose.docker.yaml up -d
```

## Modes

| Mode | When to use it | Command |
| --- | --- | --- |
| Pull-first | Default path for normal users | `docker compose up -d` |
| Build from source | Maintain the image, change pinned versions, or change `WORKBENCH_USER` | `docker compose -f compose.yaml -f compose.build.yaml up -d --build` |
| Docker-aware | Let the container talk to the host Docker daemon | `docker compose -f compose.yaml -f compose.docker.yaml up -d` |

## Persistence At A Glance

| Host path | Container path | Purpose |
| --- | --- | --- |
| `data/home` | `/home/${WORKBENCH_USER}` | Shell history, CLI auth, Git config, and user state |
| `data/projects` | `/workspace/projects` | Active repositories |
| `data/references` | `/workspace/references` | Reference material mounted read-only |
| `data/scratch` | `/workspace/scratch` | Durable scratch space |
| `data/ssh` | `/home/${WORKBENCH_USER}/.ssh` | SSH keys and SSH config |

If the owner of `data/` does not match `WORKBENCH_UID:WORKBENCH_GID`, startup fails with exit `70`.

## Trust Boundary

The AI Crowd is a high-trust operator environment, not a sandbox for untrusted workloads. The base runtime narrows the container with non-root execution, dropped capabilities, and explicit writable paths, but the container can still read and edit the repositories you mount. Enabling Docker-aware mode intentionally expands that trust boundary to the host Docker daemon.

## Documentation Map

Read in this order if you are onboarding:

1. [Setup](docs/SETUP.md) for bootstrap, `.env`, published-image flow, local builds, and Docker-aware mode
2. [Operations](docs/OPERATIONS.md) for authentication, daily commands, upgrades, validation, and troubleshooting
3. [Architecture](docs/ARCHITECTURE.md) for runtime model, delegation, trust boundaries, and startup behavior
4. [Workspace](docs/WORKSPACE.md) for host/container paths and persistence boundaries
5. [Guidelines](docs/GUIDELINES.md) for maintainer rules and project invariants
