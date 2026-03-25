# Operations Guide

This guide covers normal use after the container exists.

## Common Commands

```bash
docker compose up -d --build
docker exec -it the-ai-crowd bash -l
docker compose -f compose.yaml -f compose.docker.yaml up -d
bash scripts/ci/smoke.sh
bash scripts/ci/healthcheck.sh
```

## Authentication

OAuth is the default interactive path. API keys from `.env` are the headless fallback.

| CLI | Interactive command | API key |
| --- | --- | --- |
| Claude Code | `claude auth login` | `ANTHROPIC_API_KEY` |
| Gemini CLI | `gemini auth` | `GEMINI_API_KEY` |
| Codex CLI | `codex` | `OPENAI_API_KEY` |

Auth state persists under `state/home`, usually in `~/.config`.

## Git And SSH

- SSH is the preferred Git path
- Put key material under `state/ssh`
- Verify access with `ssh -T git@github.com`
- The image ships pinned GitHub host keys in `/etc/ssh/ssh_known_hosts`

On startup, the entrypoint normalizes SSH permissions:

- `~/.ssh` -> `700`
- `*.pub`, `known_hosts`, `config` -> `644`
- other SSH files -> `600`

If you prefer GitHub CLI:

```bash
gh auth login
gh auth setup-git
```

## Runtime Defaults

When unset, the entrypoint applies:

- `init.defaultBranch=main`
- `pull.rebase=false`
- `core.editor=vim`

If `/workspace/config/gitconfig` exists, it is added through `include.path`.

## Delegation

Claude MCP bootstrap is best-effort:

- `codex` registers through `codex -m gpt-5.3-codex mcp-server`
- `gemini` registers through `/opt/claude-delegator/server/gemini/index.js`

Bootstrap status is written to `state/home/.local/share/ai-crowd/claude-mcp-bootstrap.status`.

## Troubleshooting

- Startup fails with a permissions error:
  `WORKBENCH_UID` or `WORKBENCH_GID` does not match the owner of `state/`
- Delegated MCP workflows are missing:
  check `state/home/.local/share/ai-crowd/claude-mcp-bootstrap.status`
- Docker-aware mode is confusing:
  the image already includes the `docker` CLI; the overlay mounts the socket and group so the container can talk to the host daemon
