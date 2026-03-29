# Setup Guide

Use this document for first-time bootstrap and configuration. For daily usage after the container exists, read [OPERATIONS.md](OPERATIONS.md). For runtime design and boundaries, read [ARCHITECTURE.md](ARCHITECTURE.md).

## What You Need

- Docker Engine with Compose
- A host directory where `./data` can persist
- Ownership of `./data` aligned with the UID and GID you plan to run inside the container

## Host Layout

Create these paths before first boot:

- `data/home`
- `data/projects`
- `data/references`
- `data/scratch`
- `data/ssh`

Inside the container they map to `/home/$WORKBENCH_USER`, `/workspace/projects`, `/workspace/references`, `/workspace/scratch`, and `/home/$WORKBENCH_USER/.ssh`.

## Path A: Pull-First

This is the default path for users who want the published image.

### 1. Prepare bind mounts and `.env`

```bash
mkdir -p data/home data/projects data/references data/scratch data/ssh
chown -R "$(id -u):$(id -g)" data
cp .env.example .env
```

Edit `.env` and set:

- `TZ`
- `WORKBENCH_UID`
- `WORKBENCH_GID`

Keep `WORKBENCH_USER=operator` in pull-first mode. The published image is built with `USERNAME=operator`; changing that name requires a local build.

### 2. Optional: seed a Git config

If you want your preferred Git identity available on first login, copy the sample config into the persistent home mount:

```bash
cp docs/gitconfig.example data/home/.gitconfig
```

If you skip this step, the entrypoint still applies default values for `init.defaultBranch`, `pull.rebase`, and `core.editor` when they are unset.

### 3. Start the workbench

```bash
docker pull rcortese/the-ai-crowd:latest
docker compose up -d
docker exec -it the-ai-crowd bash -l
```

The container starts in `/workspace/projects` as the configured non-root user.

## Path B: Build From Source

Use this path if you maintain the image, want to pin different tool versions, or need a different `WORKBENCH_USER`.

### 1. Complete the pull-first preparation

Run the same directory and `.env` setup from Path A.

### 2. Adjust build overrides if needed

Uncomment only the overrides you actually want in `.env`, such as:

- `NODE_VERSION`
- `CLAUDE_CODE_VERSION`
- `GEMINI_CLI_VERSION`
- `CODEX_CLI_VERSION`
- `DOCKER_CE_CLI_VERSION`

### 3. Build and start

```bash
docker compose -f compose.yaml -f compose.build.yaml up -d --build
docker exec -it the-ai-crowd bash -l
```

`compose.build.yaml` is the supported local-build override. If you previously used `compose.override.yaml`, migrate those commands to `compose.build.yaml`.

## Optional Docker-Aware Mode

Use this only when the workbench must talk to the host Docker daemon.

```bash
docker compose -f compose.yaml -f compose.docker.yaml up -d
```

This overlay:

- sets `AI_CROWD_ENABLE_DOCKER=true`
- mounts `/var/run/docker.sock`
- adds the host Docker group via `DOCKER_GID`

The image already includes the `docker` CLI. The overlay grants daemon access; it does not install Docker tooling.

## Required Environment Variables

| Variable | Required in pull-first | Required in local build | Notes |
| --- | --- | --- | --- |
| `TZ` | yes | yes | Container timezone |
| `WORKBENCH_UID` | yes | yes | Must match the owner of `./data` |
| `WORKBENCH_GID` | yes | yes | Must match the owner of `./data` |
| `WORKBENCH_USER` | keep default | optional override | Only change for local builds |
| `DOCKER_GID` | no | no | Used only with `compose.docker.yaml` |

Optional API keys:

- `ANTHROPIC_API_KEY`
- `GEMINI_API_KEY`
- `OPENAI_API_KEY`

These are runtime secrets for headless flows. Interactive OAuth remains the default path.

## First Login Checklist

From inside the container:

```bash
claude auth login
gemini auth
codex
```

Then confirm the basics:

```bash
git config --global --get init.defaultBranch
git config --global --get pull.rebase
git config --global --get core.editor
```

If startup fails immediately, the most likely issue is ownership mismatch between `WORKBENCH_UID:WORKBENCH_GID` and the `./data` tree.
