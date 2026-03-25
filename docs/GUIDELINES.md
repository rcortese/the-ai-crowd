# GUIDELINES

This document records the project rules. Keep setup in [README.md](../README.md) and [SETUP.md](SETUP.md). Keep architectural framing in [ARCHITECTURE.md](ARCHITECTURE.md).

## Position

The AI Crowd is a single internal AI environment. It is:

- terminal-first
- Claude-led
- persistent
- limited to curated mounts
- high-trust, but not careless
- usable with or without Docker access

It is not a distributed platform, browser-first IDE, zero-trust sandbox, or mutable pet container.

## Core Rules

### Base image

- Use `Ubuntu 24.04 LTS`
- Do not use Alpine

### Tool installation

- Install Claude Code, Gemini CLI, and Codex CLI in the image build
- Standardize on pinned Node.js 20 LTS in the image
- Pin versions explicitly
- Do not install or update core tools at container startup
- The image is the source of truth for the runtime

### Authentication

- OAuth is the default interactive path
- API keys are the non-interactive fallback
- Secrets are injected at runtime
- Secrets do not belong in the image

### Updates

- Update through deliberate image rebuilds
- Do not rely on floating `latest`
- Do not self-update inside the running container

### Persistence

Persistent state includes:

- shell config and history
- Git config and credentials
- SSH material
- CLI auth and config state
- user preferences and dotfiles

Disposable state includes caches, temp files, and rebuildable downloads.

### Workspace shape

- Use curated mounts only
- Mount active repositories read-write
- Mount reference material read-only
- Keep scratch separate from durable state
- Do not mount the whole host for convenience

### Delegation

- Claude Code is the orchestrator
- Gemini CLI and Codex CLI are local workers and fallbacks
- Prefer local-first orchestration through shared filesystem and stdio MCP
- Do not add internal service sprawl without a clear need

### Access model

- CLI-first is the baseline
- Shell access is the primary interface
- A web terminal is optional later
- A browser IDE is not a phase-one requirement

### Docker capability

- Docker access is optional
- The system must remain valid without Docker integration
- If enabled, treat Docker as an explicit trust expansion

### Security posture

- Run as a non-root user
- Drop unnecessary Linux capabilities
- Enable `no-new-privileges`
- Keep writable paths explicit
- Use curated mounts and tmpfs for transient areas

Aim for practical containment, not hardening theater that breaks the workstation feel.

### Toolchain baseline

The base environment should include the normal shell, Git, search, editing, archive, diagnostics, and build tools needed for daily operator work. Add niche tooling only when it is actually needed.

### Recoverability

- Prefer Git as the main recovery boundary
- Keep persistent operator state outside the image
- Rebuild containers instead of mutating them ad hoc
- Use frequent checkpoints during AI-driven work

### CI conventions

- `scripts/ci/lib.sh`: shared helpers
- `scripts/ci/smoke.sh`: runtime and delegation smoke coverage
- `scripts/ci/healthcheck.sh`: healthcheck validation

Keep workflow responsibilities narrow:

- `lint.yml`: static checks only
- `ci.yml`: image build, smoke coverage, and healthcheck coverage
- `publish-dockerhub.yml`: tag-triggered publication only

## Non-Negotiable Rules

- Do not use Alpine
- Do not update tool versions at startup
- Do not mount the whole host
- Do not make Docker foundational
- Do not put secrets in the image
- Do not let the live container become the source of truth

## Final Directive

Build The AI Crowd as a single, persistent, terminal-first, Ubuntu-based operator environment with pinned tool versions, curated mounts, non-root execution, Claude-led orchestration, optional Docker capability, and Git-centered recoverability.
