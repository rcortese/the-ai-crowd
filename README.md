# The AI Crowd

A homelab AI workbench for Claude-led, multi-model development workflows.

## What it is

The AI Crowd is a single internal toolbox container where Claude acts as the primary orchestrator and Gemini CLI plus Codex CLI are available as local delegated workers or direct fallback tools.

## MVP

This repository now includes a runnable phase-one scaffold:

- `Dockerfile` for an Ubuntu 24.04-based workbench image
- `compose.yaml` for a persistent, terminal-first runtime
- pinned build args for Node 20 and the three AI CLIs
- curated mounts for projects, references, scratch space, and persistent home
- a non-root entrypoint that initializes operator state cleanly

## Quick Start

1. Copy `.env.example` to `.env`.
2. Adjust UID/GID for your host and decide how you want to authenticate.
   - OAuth is the default operator path for interactive use
   - API keys remain available for headless, CI, or explicit preference
   - for Git identity and other shell defaults, prefer files under `./config/` instead of adding more variables to `.env`
   - Git authentication should use SSH by default; do not put Git credentials in `.env`, `./config`, or text files in the repo
3. Create the local mount targets:
   - `mkdir -p state/home state/projects state/references state/scratch state/ssh config`
   - `chown -R "$(id -u):$(id -g)" state`
   - `cp config/gitconfig.example config/gitconfig` and edit as needed
   - place your SSH keypair under `state/ssh` if you want the default Git workflow
4. Build and start the container:
   - `docker compose up -d --build`
5. Enter the shell:
   - `docker exec -it the-ai-crowd bash -l`
6. Enable Docker-aware mode only when needed:
   - `docker compose -f compose.yaml -f compose.docker.yaml up -d`
   - set `DOCKER_GID` in `.env` to the host group that owns `docker.sock`

## Filesystem Model

- `/workspace/projects`: active repositories, read-write
- `/workspace/references`: read-only reference material
- `/workspace/scratch`: disposable working area
- `/home/$WORKBENCH_USER`: persistent user state

## Static Config

The workbench now mounts `./config` read-only at `/workspace/config`.

- Use `./config/gitconfig` for persistent Git identity and aliases that should be injected into the container as static configuration.
- The standard host layout is fixed in compose: `./state/{home,projects,references,scratch,ssh}` plus `./config`.
- Keep `.env` focused on runtime secrets, UID/GID alignment, tool versions, and capability toggles.
- Never store Git credentials in `./config`, `.env`, `.env.example`, or ad-hoc text files in the repository.

## Git Authentication

Use SSH as the default interactive Git path.

1. Put your SSH keypair in `state/ssh`.
2. Start the workbench.
3. Inside the container, verify access with `ssh -T git@github.com`.
4. Use Git remotes in SSH form such as `git@github.com:org/repo.git`.

The container bootstraps `~/.ssh` permissions and pre-populates `github.com` in `known_hosts` when possible, so the standard SSH path works with minimal setup.

If you prefer GitHub CLI login instead of SSH, use an explicit interactive flow inside the container:

```bash
gh auth login
gh auth setup-git
```

This stores GitHub authentication under the persistent home mount in `state/home`, not in repository-managed config.

## Docker Access

The base compose stack does not mount `docker.sock`. When you need container inspection or control, start the workbench with `compose.docker.yaml` layered on top and set `DOCKER_GID` to the host Docker group so access remains explicit and usable. The socket path is fixed to `/var/run/docker.sock`.

## Authentication

Each CLI supports two auth modes. OAuth is the default operator path for interactive use. API keys are injected via `.env` and remain available for headless, CI, and cases where browser-based login is not the right fit. OAuth tokens are stored in `$HOME/.config/` and persist across container restarts via the `state/home` bind mount.

| CLI | OAuth (browser) | API key |
|-----|----------------|---------|
| **Claude Code** | `claude auth login` | `ANTHROPIC_API_KEY` in `.env` |
| **Gemini CLI** | `gemini auth` | `GEMINI_API_KEY` in `.env` |
| **Codex CLI** | `codex` → Sign in with ChatGPT | `OPENAI_API_KEY` in `.env` |

For interactive sessions, OAuth is the default recommendation. For headless or CI environments, API keys are the practical path.

### First-time OAuth setup

```bash
docker exec -it the-ai-crowd bash -l
claude auth login   # opens browser
gemini auth         # opens browser
codex               # select "Sign in with ChatGPT"
```

Tokens are written to `state/home/.config/{claude,gemini,codex}/`. Subsequent `docker compose up -d` invocations reuse them automatically.

### Mixing modes

You can mix modes across CLIs. The default recommendation is OAuth for interactive workflows, with API keys used selectively where automation, headless operation, or local key management are the better fit.

For Git automation or CI, inject tokens through a secret file or an env file stored outside this repository. Do not persist Git credentials in project files.

## Dependencies

| Dependency | Purpose |
|------------|---------|
| [jarrodwatts/claude-delegator](https://github.com/jarrodwatts/claude-delegator) | MCP bridge for Gemini CLI and orchestration rules for multi-model delegation |

The image downloads a pinned `claude-delegator` snapshot from upstream at build time using the configured commit, then extracts only the contents needed at runtime. The Gemini MCP bridge (`server/gemini/index.js`) and orchestration rules (`rules/*.md`) are the components used at runtime.

## Notes

The CLI npm package names and versions are pinned as build args in the image. If upstream package names or auth flows change, update those args rather than mutating a running container by hand. The image also exposes `fd` and `bat` under the expected command names for Ubuntu-based shells.
The bind-mounted directories under `state/` must be writable by `WORKBENCH_UID:WORKBENCH_GID` from `.env` or startup will fail.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/GUIDELINES.md](docs/GUIDELINES.md).
