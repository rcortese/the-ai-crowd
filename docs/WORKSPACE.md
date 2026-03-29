# Workspace Guide

Use this document when you need exact host and container paths, persistence boundaries, or read-write semantics.

## Container Layout

| Path | Purpose | Access |
| --- | --- | --- |
| `/workspace/projects` | Active repositories | read-write |
| `/workspace/references` | Reference material | read-only |
| `/workspace/scratch` | Durable scratch area | read-write |
| `/home/$WORKBENCH_USER` | Persistent operator state | read-write |
| `/home/$WORKBENCH_USER/.ssh` | SSH material | read-write |

The default working directory is `/workspace/projects`.

## Host Layout

| Host path | Container path | Notes |
| --- | --- | --- |
| `data/home` | `/home/$WORKBENCH_USER` | CLI auth, shell history, Git config, Claude state |
| `data/projects` | `/workspace/projects` | Repositories you actively edit |
| `data/references` | `/workspace/references` | Mounted read-only by `compose.yaml` |
| `data/scratch` | `/workspace/scratch` | Scratch files that must survive restarts |
| `data/ssh` | `/home/$WORKBENCH_USER/.ssh` | SSH keys, config, and known hosts overrides |

These mounts are defined by [compose.yaml](../compose.yaml).

## Persistence Boundary

Persistent state includes:

- `~/.config`
- `~/.cache`
- `~/.local/share`
- `~/.gitconfig`
- shell history and user dotfiles
- SSH material under `data/ssh`

Ephemeral runtime state includes:

- `/tmp`
- `/run`

Both are backed by `tmpfs` in the default Compose service.

## Writable Versus Read-Only

- `projects` is for repositories that the workbench is allowed to modify
- `references` is for material the workbench can inspect but should not mutate
- `scratch` is for throwaway work that still needs to survive restarts

That split is part of the trust boundary. It keeps project work, reference context, and disposable artifacts separate.

## Boot Behavior

Before handing control to the shell, the entrypoint ensures the expected home and workspace paths exist. If any mounted path is not writable by the configured runtime user, startup fails with a UID:GID mismatch error instead of continuing in a partially broken state.

Git config lives at `~/.gitconfig` inside `data/home` and persists across restarts.

## Security Shape

The base runtime keeps the workspace narrow:

- non-root user
- all Linux capabilities dropped
- `no-new-privileges`
- explicit writable mounts
- `tmpfs` for transient paths
