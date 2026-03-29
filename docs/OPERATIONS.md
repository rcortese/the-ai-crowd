# Operations Guide

Use this document after the container already exists. For initial bootstrap, read [SETUP.md](SETUP.md). For runtime internals and trust boundaries, read [ARCHITECTURE.md](ARCHITECTURE.md).

## Daily Commands

```bash
docker compose up -d
docker exec -it the-ai-crowd bash -l
docker compose down
docker compose -f compose.yaml -f compose.build.yaml up -d --build
docker compose -f compose.yaml -f compose.docker.yaml up -d
bash scripts/ci/smoke.sh
bash scripts/ci/healthcheck.sh
```

## Authentication

OAuth is the default interactive path. API keys from `.env` are the non-interactive fallback.

| CLI | Interactive command | API key fallback |
| --- | --- | --- |
| Claude Code | `claude auth login` | `ANTHROPIC_API_KEY` |
| Gemini CLI | `gemini auth` | `GEMINI_API_KEY` |
| Codex CLI | `codex` | `OPENAI_API_KEY` |

Auth state normally persists under `data/home`, usually below `~/.config`.

## Git And SSH

- Put SSH keys and SSH config under `data/ssh`
- Verify GitHub SSH access with `ssh -T git@github.com`
- The image ships pinned GitHub host keys in `/etc/ssh/ssh_known_hosts`

At startup, the entrypoint normalizes SSH permissions:

- `~/.ssh` -> `700`
- `*.pub`, `known_hosts`, `config` -> `644`
- other SSH files -> `600`

If you prefer GitHub CLI for Git auth:

```bash
gh auth login
gh auth setup-git
```

## Startup Behavior That Affects Operations

On each boot the entrypoint:

1. Ensures the expected home and workspace paths exist and are writable
2. Fails with exit `70` if mounted paths do not match the runtime UID and GID
3. Applies default Git settings when they are missing
4. Syncs `claude-delegator` rule files into the persisted Claude rules directory
5. Attempts Claude MCP registration for Codex and Gemini and records any bootstrap degradation

Bootstrap status is recorded in `data/home/.local/share/ai-crowd/claude-mcp-bootstrap.status`.

## Delegation

Claude MCP registration is non-fatal at boot, but required for a healthy runtime.

- Codex registers through `codex -m "${CODEX_MCP_MODEL:-gpt-5.3-codex}" mcp-server`
- Gemini registers through `/opt/claude-delegator/server/gemini/index.js`

If registration fails, shell access and direct CLI usage still work, but the container remains unhealthy until the MCP state is repaired.

## Validation And Health Checks

For a quick runtime validation:

```bash
docker compose -f compose.yaml -f compose.build.yaml build the-ai-crowd
bash scripts/ci/smoke.sh
bash scripts/ci/healthcheck.sh
bash scripts/ci/smoke-upgrade.sh
```

The container healthcheck verifies:

- expected directories exist
- bundled CLIs are on `PATH`
- Git defaults are present
- Docker mode matches the runtime socket state
- delegated MCP rules, bridge files, and registrations are present
- the bootstrap status file is empty

## Upgrades

### Pull-first workflow

```bash
docker pull rcortese/the-ai-crowd:latest
docker compose up -d
```

### Local-build workflow

```bash
docker compose -f compose.yaml -f compose.build.yaml up -d --build
```

The running container is not meant to self-update. Upgrade through a fresh image pull or rebuild.

## Troubleshooting

### Container exits with status `70`

`WORKBENCH_UID` or `WORKBENCH_GID` does not match the owner of the `./data` tree. Fix host ownership and start again.

### Claude does not show delegated workers

Check:

- `data/home/.local/share/ai-crowd/claude-mcp-bootstrap.status`
- `~/.claude.json` inside the container
- whether `claude`, `codex`, `gemini`, and `node` are available on `PATH`
- whether `docker ps` shows the container as `healthy`, not just `Up`

### Docker commands fail inside the workbench

The base image includes the `docker` CLI, but Docker daemon access only exists when you start with `compose.docker.yaml` and pass the correct `DOCKER_GID`.

### Git identity looks wrong

Inspect `data/home/.gitconfig`. If you want a clean baseline, copy `docs/gitconfig.example` over it and re-enter the container.
