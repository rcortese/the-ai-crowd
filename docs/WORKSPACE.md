# Workspace Guide

This guide describes the filesystem layout and persistence model.

## Container Layout

| Path | Purpose | Access |
| --- | --- | --- |
| `/workspace/projects` | Active repositories | read-write |
| `/workspace/references` | Reference material | read-only |
| `/workspace/scratch` | Disposable work | read-write |
| `/workspace/config` | Host-managed config | read-only |
| `/home/$WORKBENCH_USER` | Persistent operator state | read-write |
| `/home/$WORKBENCH_USER/.ssh` | SSH material | read-write |

The default working directory is `/workspace/projects`.

## Host Layout

The standard host layout is:

- `data/home`
- `data/projects`
- `data/references`
- `data/scratch`
- `data/ssh`
- `data/config`

These paths are mounted by [compose.yaml](../compose.yaml).

## Persistence

Persistent state includes shell history, CLI auth, Git config, SSH material, and other operator state under `data/home`.

Disposable work belongs in:

- `data/scratch`
- `/workspace/scratch`
- tmpfs-backed runtime paths such as `/tmp` and `/run`

## Boot Behavior

Before handing control to the shell, the entrypoint ensures the expected home and workspace paths exist. If a mounted path is not writable by the configured runtime user, startup fails with a clear UID:GID mismatch error.

If `/workspace/config/gitconfig` exists, it is added to the global Git config through `include.path`.

## Security Shape

The base runtime is intentionally narrow:

- non-root user
- `no-new-privileges`
- all Linux capabilities dropped
- tmpfs for `/tmp` and `/run`
