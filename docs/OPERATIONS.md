# Operations Guide

This guide covers the normal day-to-day flow after the container exists.

## Common Commands

Build and start:

```bash
docker compose up -d --build
```

Enter the shell:

```bash
docker exec -it the-ai-crowd bash -l
```

Start with the Docker-aware overlay:

```bash
docker compose -f compose.yaml -f compose.docker.yaml up -d
```

Run the repository checks from the host:

```bash
bash scripts/ci/smoke.sh
bash scripts/ci/healthcheck.sh
```

## Authentication

OAuth is the default interactive path. API keys from `.env` remain available for headless and CI-style use.

| CLI | Interactive command | API key |
| --- | --- | --- |
| Claude Code | `claude auth login` | `ANTHROPIC_API_KEY` |
| Gemini CLI | `gemini auth` | `GEMINI_API_KEY` |
| Codex CLI | `codex` | `OPENAI_API_KEY` |

OAuth and CLI state persist under `state/home`, typically under `~/.config`.

## Git And SSH

SSH is the preferred interactive Git path.

Recommended flow:

1. Put your keypair under `state/ssh`.
2. Start the container.
3. Verify connectivity with `ssh -T git@github.com`.
4. Use SSH remotes such as `git@github.com:org/repo.git`.

The runtime entrypoint enforces SSH permissions on startup:

- `~/.ssh` becomes `700`
- `*.pub`, `known_hosts`, and `config` become `644`
- other SSH files become `600`

The image also ships pinned GitHub host keys through `/etc/ssh/ssh_known_hosts`.

If you prefer GitHub CLI:

```bash
gh auth login
gh auth setup-git
```

## Runtime Defaults

On startup, the entrypoint applies these Git defaults when they are unset:

- `init.defaultBranch=main`
- `pull.rebase=false`
- `core.editor=vim`

If `/workspace/config/gitconfig` exists, it is added to the global Git config as an `include.path`.

## Delegation Notes

The runtime bootstraps Claude MCP registration on a best-effort basis:

- `codex` is registered through `codex -m gpt-5.3-codex mcp-server`
- `gemini` is registered through the delegator bridge under `/opt/claude-delegator/server/gemini/index.js`

If that bootstrap fails, shell access and direct CLI use still work.

## Troubleshooting

UID or GID mismatch on startup:

- Symptom: the entrypoint exits with a write-permissions error.
- Cause: `WORKBENCH_UID` or `WORKBENCH_GID` does not match the owner of the bind-mounted `state/` paths.
- Fix: align `.env` with the host path owner, then restart the container.

Delegated MCP workflows not available:

- Check `state/home/.local/share/ai-crowd/claude-mcp-bootstrap.status`
- Warnings are recorded there during startup

Docker-aware mode confusion:

- The overlay mounts the socket and group membership
- The current image does not install the `docker` CLI
- Do not assume full Docker commands are available inside the container without further image work
