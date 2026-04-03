# Operations Guide

Use this document after the container already exists. For initial bootstrap, read [SETUP.md](SETUP.md). For runtime internals and trust boundaries, read [ARCHITECTURE.md](ARCHITECTURE.md).

## Daily Commands

```bash
docker compose up -d
docker ps --filter name=the-ai-crowd --format 'table {{.Names}}\t{{.Status}}'
docker exec -it the-ai-crowd bash -l
docker compose down
docker compose -f compose.yaml -f compose.build.yaml up -d --build
docker compose -f compose.yaml -f compose.docker.yaml up -d
bash scripts/ci/smoke.sh
bash scripts/ci/healthcheck.sh
```

For the first boot of the published image, follow [SETUP.md](SETUP.md#path-a-pull-first): pull the image explicitly, start it, and wait for `healthy` before opening a shell. After that initial bootstrap, `docker compose up -d` is the normal day-to-day start command for the already-pulled image.

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

Bootstrap status is recorded in `data/home/.local/share/the-ai-crowd/claude-mcp-bootstrap.status`.

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
- bootstrap validation completed successfully at startup
- delegated MCP rules, bridge files, and registrations are still present
- delegated MCP bootstrap status is clean

At startup, the entrypoint also runs a one-time bootstrap validation that covers the heavier invariants:

- Codex sandbox validation passes when enabled
- delegated MCP rules, bridge files, and registrations are present

Bootstrap validation state is recorded in:

- `data/home/.local/share/the-ai-crowd/bootstrap-validation.complete`
- `data/home/.local/share/the-ai-crowd/bootstrap-validation.status`
- `data/home/.local/share/the-ai-crowd/claude-mcp-bootstrap.status`

## Upgrades

### Pull-first workflow

```bash
docker pull rcortese/the-ai-crowd:latest
docker compose up -d
docker ps --filter name=the-ai-crowd --format 'table {{.Names}}\t{{.Status}}'
```

Use this when you want the latest published image. Wait for the status to show `healthy` before treating the recreate as complete.

### Local-build workflow

```bash
docker compose -f compose.yaml -f compose.build.yaml up -d --build
```

### Manual CLI updates inside the container

The bundled npm CLIs now use a user-scoped global prefix:

```bash
npm config get prefix
```

Expected output:

```text
/home/operator/.local/share/the-ai-crowd/npm-global
```

That path lives under the persisted home mount, so non-root updates survive container restarts and recreations:

```bash
npm install -g @anthropic-ai/claude-code@latest
npm install -g @google/gemini-cli@latest
npm install -g @openai/codex@latest
```

The image still carries pinned seed versions as the default runtime baseline, but once a CLI is updated in the user prefix, that operator-scoped override takes precedence on `PATH`.

Use an image pull or rebuild when you want updated base OS packages or a new default tool baseline. Use manual `npm install -g` when you only need a newer CLI release for that persisted operator environment rather than a new maintainer baseline.

## Troubleshooting

### Container exits with status `70`

`WORKBENCH_UID` or `WORKBENCH_GID` does not match the owner of the `./data` tree. Fix host ownership and start again.

### Claude does not show delegated workers

Check:

- `data/home/.local/share/the-ai-crowd/claude-mcp-bootstrap.status`
- `data/home/.local/share/the-ai-crowd/bootstrap-validation.complete`
- `data/home/.local/share/the-ai-crowd/bootstrap-validation.status`
- `~/.claude.json` inside the container
- whether `claude`, `codex`, `gemini`, and `node` are available on `PATH`
- whether `docker ps` shows the container as `healthy`, not just `Up`

### Docker commands fail inside the workbench

The base image includes the `docker` CLI and `docker compose` plugin, but host Docker daemon access only exists when you start with `compose.docker.yaml` and pass the correct `DOCKER_GID` for the host socket.

### Codex sandbox fails with namespace errors

If Codex reports `bwrap` or namespace creation failures in the default runtime, confirm that your container was recreated after pulling the updated compose configuration and then run `timeout 10 codex sandbox linux -- true` inside the workbench. In this project, sandbox support is part of the baseline runtime, so `compose.docker.yaml` is not the fix unless you also need host Docker access.

### Git identity looks wrong

Inspect `data/home/.gitconfig`. If you want a clean baseline, copy `docs/gitconfig.example` over it and re-enter the container.
