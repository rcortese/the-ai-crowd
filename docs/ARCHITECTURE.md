# Architecture

Use this document to understand the runtime model and design boundaries. For setup steps, read [SETUP.md](SETUP.md). For day-to-day use, read [OPERATIONS.md](OPERATIONS.md). For maintainer doctrine, read [GUIDELINES.md](GUIDELINES.md).

## Core Model

The AI Crowd is a single, persistent operator environment:

- one Ubuntu 24.04 container
- one shared shell and filesystem context
- one persistent home directory for operator state
- one curated workspace split across projects, references, and scratch
- one Claude-led delegation path to Gemini CLI and Codex CLI

The design prefers local-first coordination over service sprawl, browser IDE flows, or multi-container orchestration.

## Runtime Shape

### One container, shared context

All bundled CLIs run inside the same container and see the same mounted files. That shared filesystem is the handoff boundary between tools.

### Persistent operator state

`data/home` persists shell history, CLI auth, Git configuration, Claude config, and other user-level state. This is a durable workbench, not a disposable task runner.

### Curated workspace mounts

- `/workspace/projects` is for active repositories
- `/workspace/references` is for read-only reference material
- `/workspace/scratch` is for durable but disposable working files

The model is intentionally narrower than mounting the entire host.

## Delegation Model

Claude Code remains the primary orchestrator. At startup, `claude-delegator` is used to register:

- Codex through `codex ... mcp-server`
- Gemini through the delegator Node bridge

This keeps delegation local:

- no extra internal services
- no separate worker containers
- no additional network boundary for normal handoffs

If bootstrap fails, the environment degrades to direct CLI usage instead of failing to start.

## Startup Contract

The entrypoint is responsible for the operational baseline:

1. ensure required directories exist and are writable
2. fail fast on UID:GID mismatches for mounted paths
3. normalize SSH permissions
4. apply default Git settings when they are unset
5. sync delegated Claude rules into persisted state
6. attempt best-effort MCP registration for Codex and Gemini

That startup contract explains why the image is the source of truth for tooling while state stays outside the image.

## Docker Capability

Docker support is optional and additive.

- Standard mode exposes files, repos, shell tools, and local delegation only
- Docker-aware mode mounts `/var/run/docker.sock` and adds the host Docker group

The `docker` CLI can exist in the image without making host daemon access mandatory. The overlay is the capability switch.

## Trust And Security Boundary

The AI Crowd is not a zero-trust sandbox.

- It runs as a non-root user
- It drops all Linux capabilities
- It enables `no-new-privileges`
- It uses `tmpfs` for `/tmp` and `/run`
- It keeps writable paths explicit

Those controls narrow the runtime, but they do not change the trust model: the container can still access the repositories and state you mount. Docker-aware mode expands trust further because the host Docker daemon becomes reachable.

## Scope

The AI Crowd is meant for:

- AI-assisted coding sessions
- repository analysis and modification
- terminal-first operator work
- local delegated worker flows
- optional Docker-aware maintenance tasks

It is not meant to be:

- a distributed AI platform
- a browser-first IDE
- a multi-tenant sandbox
- a host-wide administration replacement
