[![Docker Pulls](https://img.shields.io/docker/pulls/rcortese/the-ai-crowd)](https://hub.docker.com/r/rcortese/the-ai-crowd)
[![CI](https://github.com/rcortese/the-ai-crowd/actions/workflows/ci.yml/badge.svg)](https://github.com/rcortese/the-ai-crowd/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/rcortese/the-ai-crowd)](LICENSE)

# The AI Crowd

<p align="center">
  <img src="docs/the-it-crowd.png" alt="The IT Crowd" width="600">
</p>

**Claude Code hits rate limits faster when it does everything alone. Give it a crew.**

The AI Crowd is a Docker container with Claude Code, Gemini CLI, and Codex CLI already wired together for delegation — Claude orchestrates, the others execute. You get more done per session because the token-heavy work is distributed, not piled onto one model.

*The name is a nod to* The IT Crowd: *same terminal energy, fewer outages.*

- Claude Code orchestrates — Gemini CLI and Codex CLI handle delegated tasks
- Burn fewer Claude tokens per session by routing heavy work to the right model
- Everything pre-configured: MCP registration, pinned CLI versions, curated filesystem mounts
- Persistent shell: auth, SSH keys, Git config, and history survive restarts
- Runs on hosts where native CLI installation is impractical — Unraid, NAS devices, any Docker host
- Stays on your infrastructure: local container, your data, no hosted environment required

```bash
docker pull rcortese/the-ai-crowd:latest && docker compose up -d
```

Built for homelabbers and developers who use Claude Code as their main driver and want Gemini and Codex available as delegated workers in the same runtime.

**Who this is for:** developers who hit Claude's rate limits and want to distribute work across models without wiring it themselves.
**Who this is not for:** teams looking for a browser IDE, a multi-tenant sandbox, or a single-CLI setup.

## Quick Start
```bash
mkdir -p data/home data/projects data/references data/scratch data/ssh data/config
chown -R "$(id -u):$(id -g)" data
```
```bash
cp .env.example .env
```
Edit `.env` and set:
- `TZ`
- `WORKBENCH_UID`
- `WORKBENCH_GID`
```bash
cp config/gitconfig.example config/gitconfig
```
Edit `config/gitconfig` to match the Git identity you want inside the workbench, then start it:
```bash
docker compose up -d
docker exec -it the-ai-crowd bash -l
```
Inside the container, authenticate the CLIs you intend to use:
```bash
claude auth login
gemini auth
codex
```
If you want the Docker-aware overlay, use:
```bash
docker compose -f compose.yaml -f compose.docker.yaml up -d
```
## The Workbench
One container, one persistent shell environment, and three AI CLIs in the same runtime:
- Claude Code is the primary orchestrator.
- Gemini CLI works as a delegated worker or a direct fallback.
- Codex CLI works as a delegated worker or a direct fallback.
That is the arrangement: one tool can drive the session while the others remain available without separate containers or auth flows.
For pull-first users, `WORKBENCH_USER` is fixed as `operator`.
## Persistence
These directories are bind-mounted, so they survive restarts because they live on the host:
| Host path | Container path | What persists |
| --- | --- | --- |
| `data/home` | user home inside the container | auth state, shell history, and user-level CLI state |
| `data/projects` | `/workspace/projects` | working repositories and project files |
| `data/references` | `/workspace/references` | reference material |
| `data/scratch` | `/workspace/scratch` | disposable working files that still need to survive restarts |
| `data/ssh` | SSH material inside the container | SSH keys and related config |
| `data/config` | `/workspace/config` | workbench-side configuration |
If the `data/` directories are not owned by `WORKBENCH_UID:WORKBENCH_GID`, startup fails with exit `70`. Computers are picky like that.
## Configuration
The main knobs live in `.env`. At minimum, set `TZ`, `WORKBENCH_UID`, and `WORKBENCH_GID` so the container user lines up with host ownership on `data/`.
`WORKBENCH_USER` is fixed as `operator` for pull-first use, so user mapping is done through UID and GID rather than a renamed account.
`config/gitconfig` controls the Git identity and defaults used inside the container. Copy it from `config/gitconfig.example`, then edit it before first use.
If you need the Docker CLI in the workbench, set `DOCKER_CE_CLI_VERSION` and start with the Docker-aware overlay:
```bash
docker compose -f compose.yaml -f compose.docker.yaml up -d
```
That mode is optional. It is not enabled unless you ask for it explicitly.
## Docs
- [Setup guide](docs/SETUP.md)
- [Operations guide](docs/OPERATIONS.md)
- [Workspace guide](docs/WORKSPACE.md)
## Important Considerations
- `data/` ownership is not advisory. If those directories are not owned by `WORKBENCH_UID:WORKBENCH_GID`, the container exits with status `70`.
- Docker-aware mode is opt-in. Use the overlay only if you actually need Docker access from inside the workbench.
- This setup preserves your state because it bind-mounts host directories. That also means the data remains yours to back up, secure, and clean up.
- The container runs as a non-root user, drops capabilities, sets `no-new-privileges`, and uses `tmpfs` for `/tmp` and `/run`. Sensible precautions, not magic.
