# The AI Crowd

## Purpose

This document describes the architecture and boundaries of the project. For setup and day-to-day use, see [README.md](../README.md). For project rules, see [GUIDELINES.md](GUIDELINES.md).

## Summary

The AI Crowd is a single internal engineering environment. It centralizes:

- Claude Code as the primary orchestrator
- Gemini CLI and Codex CLI as local workers
- a shared shell and toolchain
- persistent operator state
- curated project access
- optional Docker awareness

The design favors a simple, local-first runtime over multi-container orchestration or browser-based workflows.

## Runtime Model

- One container contains all three AI CLIs
- One shared filesystem and shell context is the handoff boundary
- One persistent home directory stores auth, config, shell history, and operator state
- One workspace view exposes only the projects and references relevant to the task

Local delegation is preferred. `claude-delegator` registers Gemini and Codex as stdio MCP workers, so Claude can delegate work without separate network services.

## Filesystem And State

The container uses:

- persistent user state
- curated mounts for active projects
- read-only mounts for references
- scratch space for disposable work

This is a durable operator workspace, not a stateless worker.

## Docker Capability

Docker integration is optional.

- Standard mode: files, repos, shell tools, and local delegation only
- Docker-aware mode: adds Docker socket and group access

Docker is an extra capability, not the core identity of the project.

## Git And Trust Model

- SSH is the default Git path
- GitHub SSH host keys are pinned in the image
- The environment is high-trust and operator-supervised
- The container can read and edit mounted files broadly
- Docker access, when enabled, is an intentional trust expansion

This project is not intended for untrusted workloads or multi-tenant isolation.

## Scope

The AI Crowd is meant for:

- AI-assisted coding sessions
- repository analysis and modification
- delegated local worker flows
- project-oriented shell work
- optional Docker-aware operator tasks

It is not meant to be:

- a distributed AI platform
- a browser-first IDE
- a zero-trust sandbox
- a host-wide administration replacement

## Constraints

- Project name: `The AI Crowd`
- Single-container baseline
- Claude-led orchestration
- Gemini and Codex as local supporting workers
- Persistent state is required
- Filesystem access stays curated
- Docker access stays optional
