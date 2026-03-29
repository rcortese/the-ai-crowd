# The AI Crowd

The AI Crowd is a persistent AI workbench: one container, one shared shell, and three CLIs in the same runtime.

- Claude Code is the primary orchestrator
- Gemini CLI and Codex CLI are local delegated workers or direct fallbacks
- State, auth, shell history, Git config, and SSH material persist across restarts
- Filesystem access is curated instead of exposing the whole host

This project is for operator-supervised development work. It is not a multi-tenant sandbox or browser-first IDE.

## Components

- `compose.yaml`: base runtime, persistent state, and curated mounts
- `compose.docker.yaml`: optional Docker-aware overlay
- `Dockerfile`: pinned AI CLI and toolchain versions
- `scripts/runtime/entrypoint.sh`: runtime setup, Git defaults, SSH permissions, and best-effort MCP bootstrap

Default workspace paths inside the container:

- `/workspace/projects`
- `/workspace/references`
- `/workspace/scratch`

## Quick Start

```bash
cp .env.example .env
mkdir -p data/home data/projects data/references data/scratch data/ssh
chown -R "$(id -u):$(id -g)" data
docker pull rcortese/the-ai-crowd:latest
docker compose up -d
docker exec -it the-ai-crowd bash -l
```

Interactive auth inside the container:

```bash
claude auth login
gemini auth
codex
```

## Docs

- [Setup](docs/SETUP.md): first boot and `.env`
- [Operations](docs/OPERATIONS.md): daily commands, auth, Git/SSH, troubleshooting
- [Workspace](docs/WORKSPACE.md): mounts, persistence, and runtime behavior
- [Architecture](docs/ARCHITECTURE.md): system boundaries and design intent
- [Guidelines](docs/GUIDELINES.md): project rules and constraints

## Notes

- `data/` must be writable by `WORKBENCH_UID:WORKBENCH_GID` or startup fails
- Docker-aware mode is optional; the image already includes the `docker` CLI, and the overlay adds socket and group access
- Local builds are opt-in through `compose.build.yaml`; plain `docker compose up -d` stays pull-first
- Existing local-build workflows must switch from `compose.override.yaml` to `compose.build.yaml`
- AI CLI versions are pinned in the image (see `Dockerfile` ARG defaults); `docker-ce-cli` can also be pinned explicitly through `DOCKER_CE_CLI_VERSION` when building locally
