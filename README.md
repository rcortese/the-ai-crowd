# The AI Crowd

A homelab AI environment for Claude-led, multi-model development workflows.

## What it is

The AI Crowd is a single internal containerized environment where Claude acts as the primary orchestrator and Gemini CLI plus Codex CLI are available as local delegated workers or direct fallback tools.

The repository is organized around a runnable container image, a persistent compose stack, and a small set of supporting scripts.

- `compose.yaml`: base runtime
- `compose.docker.yaml`: optional Docker-aware overlay
- `Dockerfile`: image build
- `scripts/runtime/entrypoint.sh`: container bootstrap
- `scripts/runtime/healthcheck.sh`: runtime validation

For project decisions and architecture boundaries, see [docs/GUIDELINES.md](docs/GUIDELINES.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Quick Start

1. Copy `.env.example` to `.env`.
2. Adjust `WORKBENCH_UID` and `WORKBENCH_GID` for your host.
3. Create the local mount targets:
   - `mkdir -p state/home state/projects state/references state/scratch state/ssh config`
   - `chown -R "$(id -u):$(id -g)" state`
   - `cp config/gitconfig.example config/gitconfig`
4. Edit `config/gitconfig` as needed.
5. If you want SSH-based Git access, place your keypair under `state/ssh`.
6. Build and start the container:
   - `docker compose up -d --build`
7. Enter the shell:
   - `docker exec -it the-ai-crowd bash -l`

Enable Docker-aware mode only when needed:

- `docker compose -f compose.yaml -f compose.docker.yaml up -d`
- set `DOCKER_GID` in `.env` to the host group that owns `/var/run/docker.sock`

## Filesystem Layout

- `/workspace/projects`: active repositories, read-write
- `/workspace/references`: reference material, read-only
- `/workspace/scratch`: disposable working area
- `/home/$WORKBENCH_USER`: persistent user state
- `/workspace/config`: read-only mount of `./config`

The standard host layout is `./state/{home,projects,references,scratch,ssh}` plus `./config`.

## Authentication

OAuth is the default interactive path. API keys from `.env` remain available for headless or CI use.

| CLI | OAuth (browser) | API key |
|-----|----------------|---------|
| **Claude Code** | `claude auth login` | `ANTHROPIC_API_KEY` |
| **Gemini CLI** | `gemini auth` | `GEMINI_API_KEY` |
| **Codex CLI** | `codex` | `OPENAI_API_KEY` |

First-time interactive setup:

```bash
docker exec -it the-ai-crowd bash -l
claude auth login
gemini auth
codex
```

OAuth state persists under `state/home/.config/`.

## Git

Use SSH as the default interactive Git path.

1. Put your SSH keypair in `state/ssh`.
2. Start the container.
3. Verify access with `ssh -T git@github.com`.
4. Use SSH remotes such as `git@github.com:org/repo.git`.

The container bootstraps `~/.ssh` permissions and attempts to pre-populate `github.com` in `known_hosts`.

On startup it also attempts to register Claude MCP entries for delegated Gemini/Codex workflows. If that MCP bootstrap fails, the container still comes up for shell access and direct CLI use, and the warning is recorded under `state/home/.local/share/ai-crowd/claude-mcp-bootstrap.status`.

If you prefer GitHub CLI login:

```bash
gh auth login
gh auth setup-git
```

Do not store Git credentials in `.env`, `./config`, or repository-managed text files.

## Notes

- Keep exact CLI versions and build pins authoritative in `compose.yaml` and `Dockerfile`.
- The bind-mounted directories under `state/` must be writable by `WORKBENCH_UID:WORKBENCH_GID` from `.env` or startup will fail.
- Optional Docker access is an overlay capability, not the baseline runtime mode.
