# GUIDELINES

## Position

The AI Crowd will be a **single internal AI workbench container** for personal homelab.

It will be:

- **terminal-first**
- **Claude Code–led**
- **persistent**
- **curated in filesystem scope**
- **high-trust but not careless**
- **usable with or without Docker access**

It will **not** be turned into a distributed platform, a browser-first IDE product, or a zero-trust multi-tenant system.

The design goal is simple: **one durable operator environment that behaves like a real workstation shell and runs the three AI CLIs cleanly.**

---

## Core decisions

### 1. Base image

The workbench will use **Ubuntu 24.04 LTS** as its base image.

That choice wins for one reason: **compatibility without drama**.

This project depends on mainstream Linux behavior, glibc compatibility, current packages, and low-friction support for Node-based tooling, Python tooling, and normal developer utilities. Ubuntu 24.04 LTS is the clearest fit for that requirement. It is modern enough for fast-moving AI CLI tooling, stable enough for a long-lived homelab container, and ordinary enough that troubleshooting remains straightforward.

**Alpine is out.** musl-related breakage is not an acceptable risk for this project.

### 2. Runtime and tool installation

The workbench will standardize on **Node.js 20 LTS** and install the AI CLIs as part of the image build.

The installation model is:

- **Claude Code**: install in-image using the container-friendly package path used in Anthropic’s own devcontainer pattern
- **Gemini CLI**: install in-image via npm
- **Codex CLI**: install in-image via npm
- pin versions explicitly in the image build

This project will **not** install tools at container startup and will **not** rely on floating `latest` behavior inside the running container.

The image is the product. The running container is not allowed to mutate its core toolchain on its own.

### 3. Authentication model

Authentication will be **container-friendly with OAuth as the primary interactive path**.

The default interactive model is:

- **Claude Code**: browser login
- **Gemini CLI**: browser login
- **Codex CLI**: browser login

The default non-interactive model is:

- **Anthropic API key** for Claude Code
- **Gemini API key** for Gemini CLI
- **OpenAI API key** for Codex CLI

Browser login is the primary operator path. API keys remain the secondary path for headless use, CI, or cases where browser login is not desirable.

Secrets do **not** belong in the image. They are injected at runtime and their cached state lives in persistent user storage.

### 4. Update model

Updates will happen through **controlled image rebuilds**, not runtime self-update behavior.

That means:

- pin the base image tag
- pin the Node major version
- pin the AI CLI versions
- rebuild deliberately
- test changes in the image, not ad hoc inside the live container

This project values **predictable behavior over novelty**. A toolbox that changes itself is a liability.

### 5. Persistence model

The workbench is a **long-lived environment**, so user state must persist.

The default persistent model is:

- persistent home directory for user identity and configuration
- persistent CLI state for Claude, Gemini, and Codex
- persistent Git identity and shell configuration
- persistent SSH material when needed
- optional separate cache volume for disposable caches

Durable state includes:

- shell config and history
- Git config and credentials
- SSH config and keys
- CLI config and auth caches
- user preferences and dotfiles

Disposable state includes:

- package caches
- temporary files
- large transient downloads
- rebuildable tool caches

This workbench should restart and feel exactly like the same operator environment.

### 6. Workspace mount model

The workbench will use **curated mounts only**.

It will not be given blind access to the entire host filesystem.

The mount model is:

- **active project repositories** mounted read-write
- **reference material** mounted read-only
- **temporary scratch space** mounted separately
- **persistent user state** mounted separately from project workspaces

This is not only a safety choice. It is also a quality choice. AI tools behave better when the visible filesystem is shaped to the task instead of being a noisy dump of the host.

Broad root-share mounts are rejected. Convenience is not worth degraded context quality and accidental blast radius.

### 7. Delegation model

**Claude Code is the orchestrator.**

**Gemini CLI and Codex CLI are delegated local workers and direct fallback tools.**

The standard delegation architecture will be:

- Claude Code as the top-level control surface
- delegated workers exposed locally through **stdio MCP where structured tool integration helps**
- direct CLI fallback always available inside the same runtime
- shared filesystem as the handoff boundary

The project does not need internal network services for delegation. Everything lives in one container, on one filesystem, under one operator.

The correct model is **local-first orchestration**, not service sprawl.

### 8. Access model

The workbench will be **CLI-first**.

Primary access:

- SSH into the environment, or
- direct container shell access

Optional later layer:

- a lightweight web terminal behind access control

Deferred layer:

- full browser IDE

The day-one product is a serious shell environment. That is the best fit for AI CLIs, the lowest operational complexity, and the cleanest security story.

### 9. Docker capability

Docker access is **optional** and **not part of the core identity** of the workbench.

The architecture must remain fully valid without Docker integration.

When Docker access is enabled, it is an **explicit high-trust mode** for operator workflows that genuinely need it.

That means:

- Docker integration is documented as optional
- the default workbench remains useful without it
- enabling host Docker control is treated as a trust boundary change, not a casual toggle

This project is not a “Docker control plane in disguise.” Docker awareness is an extension, not the foundation.

### 10. Security posture

The security posture is **practical containment**.

The baseline is:

- run as a **non-root user**
- drop unnecessary capabilities
- set **no-new-privileges**
- avoid privileged mode
- keep writable paths explicit
- use curated mounts
- keep default seccomp/AppArmor style protections in place
- use tmpfs for obviously transient writable areas where appropriate

This project will **not** chase hardening theater that breaks the workbench.

Read-only root filesystems, extreme seccomp tuning, or enterprise-style isolation layers are not the baseline here. They add friction faster than they add value in a personal, human-supervised homelab toolbox.

### 11. Host fit

The workbench must fit normal host operations cleanly.

That means:

- persistent state stored in a standard appdata-style location
- active data kept on cache-backed storage where appropriate
- clear, stable volume mappings
- straightforward backup and restore

### 12. Toolchain baseline

This is an operator workbench, not a minimal runtime image.

The day-one toolchain will include:

- **shells and navigation**: bash, zsh, fzf
- **version control**: git, git-lfs, gh
- **search and inspection**: ripgrep, fd, bat, less, tree
- **data tools**: jq, yq, awk, sed
- **editors**: vim, nano
- **archive and sync tools**: zip, unzip, tar, rsync
- **network and diagnostics**: curl, wget, dig or equivalent DNS tools, htop
- **language/runtime baseline**: Node.js 20 LTS, Python 3, pipx
- **build baseline**: build-essential, make, pkg-config, and common compilation support
- **session tooling**: tmux

That is enough to make the container genuinely useful every day without turning it into a junk drawer.

Cloud-specific CLIs and niche platform tooling should be added later only when they are actually needed.

### 13. Recoverability model

Recoverability will be built around **Git first**, not around heavyweight infrastructure.

The recovery boundary is:

- source control for project state
- persistent home for operator state
- container/image rebuilds for runtime reproducibility
- normal Unraid backups for persistent storage

For AI-driven coding sessions, the workbench should support **frequent local checkpoints**. Long sessions without recovery points are avoidable operator error.

The goal is simple: when an agent makes a mess, recovery should be fast, local, and obvious.

---

## The architecture as one system

The AI Crowd is a **single-container, persistent, terminal-first AI workbench** running on Unraid.

It uses **Ubuntu 24.04 LTS** as a glibc-based base, ships a **pinned Node 20 LTS runtime**, and installs **Claude Code, Gemini CLI, and Codex CLI** directly into the image. Claude Code acts as the primary orchestrator. Gemini and Codex act as delegated workers and direct fallback tools in the same shared runtime.

The container runs as a **non-root user** and keeps its **durable operator identity** in persistent storage. That includes shell setup, Git identity, SSH material, and CLI auth/config state. Disposable caches remain separate in spirit and may be separated physically when useful, but the user experience remains that of one durable workstation.

Filesystem access is intentionally narrow. The workbench sees **the projects it is meant to work on**, not the entire host. Active repositories are mounted read-write. Reference sources are mounted read-only. Temporary scratch paths are isolated. This keeps context quality high and limits the consequences of mistakes.

The container is accessed primarily through **shell-based workflows**. SSH or equivalent shell entry is the default. A web terminal may be added later as a convenience layer. A browser IDE is not a phase-one requirement.

Docker access is optional. The workbench remains a complete product without it. If Docker control is enabled, that is treated as a deliberate expansion of trust, not as baseline plumbing.

Operationally, the project stays aligned with standard Unraid expectations: appdata-style persistence, cache-aware placement for active data, simple backup/restore, and a lifecycle driven by deliberate image rebuilds rather than runtime drift.

---

## Non-negotiable rules

- **Do not use Alpine.**
- **Do not update tool versions at container startup.**
- **Do not mount the whole host just because it is convenient.**
- **Do not make Docker access foundational to the design.**
- **Do not turn a personal workbench into a pseudo-platform.**
- **Do not over-harden the container until the shell stops feeling like a workstation.**
- **Do not put secrets into the image.**
- **Do not let the live container become the source of truth. The image build is the source of truth.**

---

## What this project is

The AI Crowd is a **private operator workbench** for a personal homelab.

It is a durable shell environment where one person can:

- run Claude Code as the main orchestration surface
- delegate locally to Gemini CLI and Codex CLI
- work across curated repositories and references
- preserve auth, preferences, and operator state across restarts
- optionally use Docker-aware workflows when explicitly enabled

## What this project is not

The AI Crowd is **not**:

- a browser-first coding environment
- a multi-container AI platform
- a zero-trust sandbox system
- a self-updating mutable pet container
- a host-wide omniscient agent with unrestricted filesystem scope

---

## Final directive

Build The AI Crowd as a **single, persistent, terminal-first, Ubuntu-based AI workbench container** with **pinned tool versions, curated mounts, non-root execution, Claude-led orchestration, optional Docker capability, and Git-centered recoverability**.

That is the architecture.
