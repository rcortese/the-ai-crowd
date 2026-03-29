# Guidelines

This document records maintainer rules and project invariants. It is not the primary onboarding document. Start with [README.md](../README.md) or [SETUP.md](SETUP.md) if you are using the workbench; read this file when changing the image, runtime shape, or project policy.

## Product Invariants

- The project remains `The AI Crowd`
- The baseline stays single-container
- Claude Code remains the orchestrator
- Gemini CLI and Codex CLI remain local supporting workers
- Persistent operator state remains outside the image
- Docker support stays optional
- The runtime stays terminal-first

## Base Runtime Rules

- Use `Ubuntu 24.04 LTS`
- Do not switch to Alpine
- Install core CLIs during image build, not at container startup
- Pin tool versions explicitly
- Treat the image as the source of truth for the runtime toolchain

## Authentication And Secrets

- OAuth is the default interactive path
- API keys are the non-interactive fallback
- Inject secrets at runtime
- Do not bake secrets into the image

## Update Model

- Upgrade through deliberate image pulls or rebuilds
- Do not rely on in-container self-mutation
- Do not let the running container become the source of truth
- Keep reproducible build inputs for pinned components such as `claude-delegator`

`latest` may exist as a convenience distribution tag, but maintainers should preserve a path to reproducible, intentional version pinning.

## Workspace And Mount Policy

- Use curated mounts only
- Keep active repositories read-write
- Keep reference material read-only
- Keep scratch separate from durable state
- Do not mount the whole host for convenience

## Delegation Policy

- Claude Code is the primary orchestrator
- Gemini CLI and Codex CLI are local workers and fallbacks
- Prefer local-first delegation through shared filesystem context and stdio MCP
- Do not add internal service sprawl without a clear operational benefit

## Security Posture

- Run as a non-root user
- Drop unnecessary Linux capabilities
- Enable `no-new-privileges`
- Keep writable paths explicit
- Use `tmpfs` for transient areas

Aim for practical containment, not hardening theater that breaks the workstation model.

## Recoverability

- Prefer Git as the main recovery boundary
- Keep persistent operator state outside the image
- Rebuild containers instead of mutating them ad hoc
- Use frequent checkpoints during AI-assisted work

## CI Conventions

- `scripts/ci/lib.sh`: shared helpers
- `scripts/ci/smoke.sh`: runtime and delegation smoke coverage
- `scripts/ci/healthcheck.sh`: healthcheck validation

Keep workflow responsibilities narrow:

- `lint.yml`: static checks only
- `ci.yml`: image build, smoke coverage, and healthcheck coverage
- `publish-dockerhub.yml`: publication only

## Non-Negotiables

- Do not use Alpine
- Do not install or update core tools at startup
- Do not mount the whole host
- Do not make Docker foundational
- Do not store secrets in the image
- Do not treat the live container as the canonical runtime definition
