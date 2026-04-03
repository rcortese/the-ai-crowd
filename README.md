[![Docker Pulls](https://img.shields.io/docker/pulls/rcortese/the-ai-crowd)](https://hub.docker.com/r/rcortese/the-ai-crowd)
[![CI](https://github.com/rcortese/the-ai-crowd/actions/workflows/ci.yml/badge.svg)](https://github.com/rcortese/the-ai-crowd/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/rcortese/the-ai-crowd)](LICENSE)

# The AI Crowd

Claude Code hits rate limits fast when it does everything alone. Give it a crew!

The AI Crowd is a persistent AI workbench for terminal-first development. It integrates Claude Code, Gemini CLI, and Codex CLI into a single container so your authentication, shell history, SSH material, and project state survive restarts.

<p align="center">
  <img src="docs/the-it-crowd.png" alt="The AI Crowd" width="480">
</p>

## Why Use It?

- **Repeatable Workspace:** Maintain a single, consistent environment instead of rebuilding AI tooling on every machine.
- **Unified Context:** Run Claude, Gemini, and Codex in the same persistent environment with shared filesystem context.
- **Simplified Delegation:** Keep local delegation available via `claude-delegator` without complex manual setup.
- **Flexible Deployment:** Start from a published image, then opt into build or Docker-aware modes only when needed.

## Who It Is For

The AI Crowd is a great fit if you:

- Want a stable operator workspace instead of reinstalling tools per host.
- Prefer Claude as your primary orchestrator, with Gemini and Codex as local workers or fallbacks.

This project might not be for you if you:

- Require a browser-based IDE or a multi-service AI platform.
- Need a sandbox for running untrusted workloads.

## How It Works

Think of it as a durable workbench with three specialists already at the table:

1. **Environment:** A single Ubuntu 24.04 container runs all bundled CLIs.
2. **Persistence:** Host bind mounts preserve your home directory, projects, references, scratch space, and SSH state across restarts.
3. **Integration:** Claude can register Gemini and Codex as local stdio MCP workers through `claude-delegator`, with the Codex Linux sandbox available in the default runtime.

An optional overlay provides host Docker access from inside the workbench, though it is intentionally disabled by default.

## Quick Start

Prepare the bind mounts and copy the sample environment file:

```bash
mkdir -p data/home data/projects data/references data/scratch data/ssh
chown -R "$(id -u):$(id -g)" data
cp .env.example .env
```

Edit `.env` and configure at least:

- `TZ`
- `WORKBENCH_UID`
- `WORKBENCH_GID`

Pull the published image, start it, confirm it reached `healthy`, and then open a login shell:

```bash
docker pull rcortese/the-ai-crowd:latest
docker compose up -d
docker ps --filter name=the-ai-crowd --format 'table {{.Names}}\t{{.Status}}'
docker exec -it the-ai-crowd bash -l
```

On first boot, wait for the container status to show `healthy`, not only `Up`, before entering the shell. The full pull-first bootstrap path lives in [Setup](docs/SETUP.md#path-a-pull-first).

Authenticate the bundled CLIs from inside the container:

```bash
claude auth login
gemini auth
codex
```

Your persistent terminal workspace is now ready to use.

## Modes

| Mode | When to use it | Command |
| --- | --- | --- |
| **Pull-first** | Standard path for most users, including Codex sandbox support | `docker pull rcortese/the-ai-crowd:latest` then `docker compose up -d` |
| **Build from source** | Maintain the image or change pinned versions | `docker compose -f compose.yaml -f compose.build.yaml up -d --build` |
| **Docker-aware** | Allow the container to communicate with the host Docker daemon | `DOCKER_GID="$(stat -c %g /var/run/docker.sock)" docker compose -f compose.yaml -f compose.docker.yaml up -d` |

## What's Included

- A single container with Claude Code, Gemini CLI, Codex CLI, Git, SSH, and daily shell tools pre-installed.
- Persistent state through host bind mounts.
- Local-first delegation via `claude-delegator`.
- Codex Linux sandbox compatibility in the default runtime.
- Optional Docker-aware overlay for host Docker daemon access and explicit `DOCKER_GID` mapping.
- User-scoped npm global prefix under `~/.local/share/the-ai-crowd/npm-global`, so `npm install -g` can update bundled CLIs without `root`.

## Persistence at a Glance

| Host Path | Container Path | Purpose |
| --- | --- | --- |
| `data/home` | `/home/${WORKBENCH_USER}` | Shell history, CLI auth, Git config, and user state |
| `data/projects` | `/workspace/projects` | Active repositories |
| `data/references` | `/workspace/references` | Reference material (mounted read-only) |
| `data/scratch` | `/workspace/scratch` | Durable scratch space |
| `data/ssh` | `/home/${WORKBENCH_USER}/.ssh` | SSH keys and configuration |

*Note: If the owner of `data/` does not match `WORKBENCH_UID:WORKBENCH_GID`, startup will fail with exit code `70`.*

## Docker Mode and Trust Boundary

The AI Crowd is a high-trust operator environment, not a sandbox for untrusted workloads.

The base runtime secures the container by:

- Using non-root execution.
- Dropping all Linux capabilities.
- Enabling `no-new-privileges`.
- Using `tmpfs` for `/tmp` and `/run`.
- Defining explicit writable paths through bind mounts.

The default runtime also relaxes seccomp enough for `unshare` and `codex sandbox linux`, because Codex delegation depends on sandbox support being available without an extra overlay. The project now ships a repo-local seccomp profile for that baseline instead of using `seccomp:unconfined`; it is an intentional fork of Docker's default-deny profile with the extra namespace, mount, and process syscalls validated for Codex sandboxing. See [Architecture](docs/ARCHITECTURE.md#trust-and-security-boundary) for the trust-boundary impact and why `compose.docker.yaml` is not part of that requirement.

The Docker-aware mode intentionally expands this trust boundary further by mounting `/var/run/docker.sock` and adding the host socket group selected through `DOCKER_GID`. Use this mode only when necessary.

## Documentation Map

1. [Setup](docs/SETUP.md): Bootstrap, `.env` configuration, and deployment modes.
2. [Operations](docs/OPERATIONS.md): Authentication, updates, and troubleshooting.
3. [Architecture](docs/ARCHITECTURE.md): Runtime model, delegation, and trust boundaries.
4. [Workspace](docs/WORKSPACE.md): Path mapping and persistence boundaries.
5. [Guidelines](docs/GUIDELINES.md): Maintainer rules and project invariants.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
