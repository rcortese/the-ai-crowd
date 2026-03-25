# The AI Crowd

The AI Crowd is a persistent AI workbench: one container, one shared shell environment, and three CLIs available in the same runtime. Claude is the primary orchestrator. Gemini CLI and Codex CLI stay local as delegated workers or direct fallbacks.

It is built for operator-supervised development work, not for multi-tenant isolation or browser-first IDE workflows. The goal is simple: make AI-assisted coding sessions feel like working from a real, durable workstation shell.

## Why it exists

- Keep Claude, Gemini, and Codex in the same filesystem and shell context.
- Preserve auth state, shell history, Git config, and SSH material across restarts.
- Give the container access only to the project, reference, and scratch paths it actually needs.
- Keep Docker awareness optional instead of making it the core identity of the environment.

## How it works

- `compose.yaml` defines the base workbench with persistent state and curated mounts.
- `Dockerfile` builds the image with pinned versions of Claude Code, Gemini CLI, Codex CLI, and the supporting toolchain.
- `scripts/runtime/entrypoint.sh` prepares the runtime, applies Git defaults, fixes SSH permissions, and bootstraps Claude MCP wiring on a best-effort basis.

The default container workspace is:

- `/workspace/projects` for active repositories
- `/workspace/references` for read-only reference material
- `/workspace/scratch` for disposable work

## Quick Start

1. Copy the environment template and prepare the host directories.
2. Set the UID and GID in `.env` to match the owner of `./state`.
3. Copy `config/gitconfig.example` to `config/gitconfig` and edit it for your identity.
4. Build and start the container.
5. Enter the shell and authenticate the CLIs you want to use.

```bash
cp .env.example .env
mkdir -p state/home state/projects state/references state/scratch state/ssh config
chown -R "$(id -u):$(id -g)" state
cp config/gitconfig.example config/gitconfig
docker compose up -d --build
docker exec -it the-ai-crowd bash -l
```

Interactive auth inside the container:

```bash
claude auth login
gemini auth
codex
```

If you want the detailed setup flow, environment variable breakdown, or troubleshooting, start with the docs below.

## Documentation

- [Setup Guide](docs/SETUP.md): first-time setup, `.env`, host directory prep, and startup flow
- [Operations Guide](docs/OPERATIONS.md): daily commands, authentication, Git/SSH, and troubleshooting
- [Workspace Guide](docs/WORKSPACE.md): filesystem layout, persistence model, and runtime behavior
- [Architecture](docs/ARCHITECTURE.md): system boundaries, trust model, and design intent
- [Guidelines](docs/GUIDELINES.md): normative project decisions and constraints

## Notes

- The bind-mounted directories under `state/` must be writable by `WORKBENCH_UID:WORKBENCH_GID` or the entrypoint exits with an explicit permissions error.
- Docker-aware mode is an optional overlay defined in `compose.docker.yaml`. The repository wires the socket and group membership, but the image does not currently install the `docker` CLI, so do not document it as a full in-container Docker workflow.
- Exact tool versions stay pinned in `Dockerfile`, `compose.yaml`, and `.env.example`.
