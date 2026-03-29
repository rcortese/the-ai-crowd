[![Docker Pulls](https://img.shields.io/docker/pulls/rcortese/the-ai-crowd)](https://hub.docker.com/r/rcortese/the-ai-crowd)
[![CI](https://github.com/rcortese/the-ai-crowd/actions/workflows/ci.yml/badge.svg)](https://github.com/rcortese/the-ai-crowd/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/rcortese/the-ai-crowd)](LICENSE)

# The AI Crowd

<p align="center">
  <img src="docs/the-it-crowd.png" alt="The AI Crowd" width="600">
</p>

**Boost Claude Code. Delegate to Gemini & Codex.**

Your terminal-first AI workbench, pre-configured so Claude Code orchestrates while Gemini CLI and Codex CLI handle delegated tasks — all in one persistent Docker container.

*Inspired by The IT Crowd, this is your desktop support for AI: always on, always ready.*

**Best for**
- Developers who use Claude Code all day and hit usage limits
- AI users who want one terminal with multiple coding CLIs already wired together
- Homelabbers who would rather run one container than install and maintain each tool separately

**Not for**
- Single-model workflows
- Hosted IDE users
- Anyone who does not want to manage Docker or local CLI auth

**Why use The AI Crowd?**
- **Slash token costs:** Route heavy tasks to Gemini or Codex, reducing your Claude token spend.
- **Persistent environment:** Your auth, SSH keys, Git config, and history survive container restarts.
- **Instant setup:** Everything's pre-configured, from MCP registration to pinned CLI versions.
- **Run anywhere:** Seamlessly deploy on Unraid, NAS, or any Docker-compatible host.
- **Own your data:** Keep your AI interactions and data strictly on your infrastructure.

## Quick Start
Create the bind-mount directories first and ensure they are owned by the same UID and GID you plan to run inside the container.

```bash
mkdir -p data/home data/projects data/references data/scratch data/ssh data/config
chown -R "$(id -u):$(id -g)" data
```

Copy the environment file, then edit `.env` and set `TZ`, `WORKBENCH_UID`, and `WORKBENCH_GID`.

```bash
cp .env.example .env
```

Copy the Git config template, edit `config/gitconfig` to match your Git identity, then start the workbench and open a login shell inside the container.

```bash
cp config/gitconfig.example config/gitconfig
```

```bash
docker compose up -d
docker exec -it the-ai-crowd bash -l
```

Authenticate the installed CLIs from inside the container.

```bash
claude auth login
gemini auth
codex
```

If you need Docker access from inside the workbench, start it with the Docker-aware overlay instead.

```bash
docker compose -f compose.yaml -f compose.docker.yaml up -d
```

## Configuration
At minimum, `.env` must define `TZ`, `WORKBENCH_UID`, and `WORKBENCH_GID`. The container user name is fixed as `operator` for pull-first use, so host alignment is handled through UID and GID mapping rather than by changing the account name.

Before first use, copy `config/gitconfig.example` to `config/gitconfig` and edit it to match the Git identity you want available inside the workbench.

Docker-aware mode is optional. To use it, set `DOCKER_CE_CLI_VERSION` in `.env` and start the stack with the Docker overlay:

```bash
docker compose -f compose.yaml -f compose.docker.yaml up -d
```

## Persistence
The workbench keeps state through bind mounts on the host.

| Host path | Container path | What persists |
|---|---|---|
| `data/home` | user home inside the container | auth state, shell history, and user-level CLI state |
| `data/projects` | `/workspace/projects` | working repositories and project files |
| `data/references` | `/workspace/references` | reference material |
| `data/scratch` | `/workspace/scratch` | disposable working files that still need to survive restarts |
| `data/ssh` | SSH material inside the container | SSH keys and related config |
| `data/config` | `/workspace/config` | workbench-side configuration |

## Important Considerations
- `data/` ownership is not optional: if directories are not owned by `WORKBENCH_UID:WORKBENCH_GID`, the container exits with status `70`
- Docker-aware mode is opt-in — use overlay only if you need Docker access from inside the workbench
- Container runs as non-root user, drops capabilities, sets `no-new-privileges`, uses `tmpfs` for `/tmp` and `/run`

## Docs
- [Setup guide](docs/SETUP.md)
- [Operations guide](docs/OPERATIONS.md)
- [Workspace guide](docs/WORKSPACE.md)
