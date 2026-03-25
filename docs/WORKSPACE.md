# Workspace Guide

This guide describes the filesystem shape and persistence model of The AI Crowd.

## Container Layout

| Path | Purpose | Access |
| --- | --- | --- |
| `/workspace/projects` | Active repositories | read-write |
| `/workspace/references` | Reference material | read-only |
| `/workspace/scratch` | Disposable work area | read-write |
| `/workspace/config` | Host-managed config files | read-only |
| `/home/$WORKBENCH_USER` | Persistent operator state | read-write |
| `/home/$WORKBENCH_USER/.ssh` | SSH material from `state/ssh` | read-write |

The default working directory is `/workspace/projects`.

## Host Layout

The standard host layout is:

- `state/home`
- `state/projects`
- `state/references`
- `state/scratch`
- `state/ssh`
- `config`

Those paths are bind-mounted by [compose.yaml](../compose.yaml).

## Persistence Model

Persistent state includes:

- shell history and shell configuration
- CLI auth and config state
- Git configuration
- SSH material
- Claude-related local state under `state/home`

Disposable work belongs in:

- `state/scratch`
- `/workspace/scratch`
- tmpfs-backed runtime paths such as `/tmp` and `/run`

## Runtime Behavior On Boot

The entrypoint ensures these paths exist before handing control to the shell:

- `$HOME/.config`
- `$HOME/.cache`
- `$HOME/.local/share`
- `$HOME/.local/share/ai-crowd`
- `$HOME/.ssh`
- `/workspace/projects`
- `/workspace/references`
- `/workspace/scratch`

If one of those mounted paths is not writable by the configured runtime user, startup fails with an explicit error explaining the UID:GID mismatch.

## Configuration Mounts

`config` is mounted read-only at `/workspace/config`.

If `/workspace/config/gitconfig` exists, the entrypoint adds it to the global Git configuration as an include path. This lets the repository keep the operator Git config outside the image while still loading it automatically at runtime.

## Security Shape

The base runtime is intentionally narrow:

- the container runs as the configured non-root user
- `no-new-privileges` is enabled
- all Linux capabilities are dropped
- `/tmp` and `/run` use tmpfs

That shape supports a practical operator environment without pretending to be a zero-trust sandbox.
