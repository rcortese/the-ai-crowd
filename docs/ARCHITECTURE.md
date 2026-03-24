# The AI Crowd

## Architecture Brief

## Purpose

This document is descriptive rather than procedural. It captures architectural intent, boundaries, assumptions, and tradeoffs.

Project-level decisions and operational guidance live elsewhere:

- [docs/GUIDELINES.md](GUIDELINES.md): normative design decisions
- [README.md](../README.md): setup and day-to-day usage

---

## Project Identity

**Project name:** The AI Crowd  
**Project type:** internal AI environment for a personal homelab  
**Environment model:** personal, shared, high-trust

The name intentionally references *The IT Crowd*. The tone may be light; the project itself is not.

---

## Executive Summary

The AI Crowd is a **single internal engineering environment** hosted on the main homelab server.

Its purpose is to provide one coherent runtime for:

- **Claude Code** as the primary orchestrator,
- **Gemini CLI** as a delegated worker,
- **Codex CLI** as a delegated worker,
- shared developer and ops tooling,
- curated access to project files,
- persistent user state,
- and **optional Docker integration**.

The design favors simplicity, compatibility, local delegation, and low operator friction. It is optimized for a personal homelab, not for strict privilege separation, distributed agent infrastructure, or multi-tenant isolation.

---

## Environment Context

The architecture assumes a homelab with:

- one primary server acting as the main container host,
- a secondary lower-power node for lighter or always-on workloads,
- established internal administrative access patterns,
- separate handling for internal management surfaces and published web interfaces,
- and existing self-hosted infrastructure and AI-adjacent services.

This makes the primary host the natural place for an internal AI environment with curated project mounts and optional container awareness.

---

## Architectural Statement

The AI Crowd is defined as:

> A single internal engineering environment on the main homelab server that centralizes Claude Code, Gemini CLI, and Codex CLI in one shared runtime, with persistent state, curated project access, and optional Docker integration, for interactive human-supervised use.

---

## Core Architecture

### Runtime model

The project uses a **single-container model** with:

- Claude Code
- Gemini CLI
- Codex CLI
- delegation tooling
- a shared shell environment
- shared dev and ops utilities
- one persistent user home
- one shared workspace view

### AI roles

- **Claude** is the default operator-facing AI.
- **Gemini** and **Codex** act as subordinate or specialist workers.
- Delegation is expected to happen locally inside the same runtime whenever practical.
- Direct use of Gemini or Codex remains available when limits or workflow preferences require it.

### Multi-model delegation

The image bakes in **claude-delegator** at build time from a pinned upstream commit. The download is verified with a SHA-256 checksum before extraction so the delegation layer stays reproducible and supply-chain tampering is easier to detect.

At runtime, claude-delegator registers **Gemini** and **Codex** as local **stdio MCP workers**. Claude can therefore delegate work inside the same container without standing up separate network services. The delegation model stays local-first: shared filesystem, shared shell context, one operator, no internal service mesh.

### Filesystem and state model

The container has:

- a **persistent home directory**,
- **curated mounts** for project repositories and relevant shares,
- and a shared operating context across all included tools.

This is an operator workspace, not a disposable stateless worker.

### Docker integration model

Docker integration is **optional**.

The architecture must remain valid in two modes:

1. **Standard mode**, where the container operates only on files, repositories, shell tools, and AI delegation.
2. **Docker-aware mode**, where the container is additionally allowed to inspect or control Docker.

Docker access is therefore a **capability that may be added**, not a defining requirement of the project.

When Docker integration is enabled, direct `docker.sock` access is acceptable in this context because the environment is personal, shared, and operator-supervised.

### Git authentication model

Git authentication defaults to **SSH**, not HTTPS tokens.

**Rationale**

- SSH keys do not expire like personal access tokens.
- SSH works cleanly with hardware-backed keys and agent forwarding.
- SSH avoids accidental HTTPS token exposure in shell history, process listings, or container logs.

For GitHub access, the image also pre-pins GitHub SSH host keys in `/etc/ssh/ssh_known_hosts`. That gives the container a stable trust anchor for Git operations and reduces supply-chain risk from first-connect host key prompts or spoofed endpoints.

---

## Key Decisions and Rationale

### 1. The system belongs on the primary host

The system belongs on the main homelab server rather than a lighter secondary node.

**Rationale**

- The primary host already carries the main container and infrastructure workloads.
- It is the most natural place for project-oriented tooling.
- It offers the most practical resource envelope for this environment.

### 2. One container contains all three AI CLIs

Claude, Gemini, and Codex run in the same container.

**Rationale**

- The intended operating model is one main AI with supporting AIs in the same working context.
- Shared runtime and shared filesystem reduce complexity.
- Local delegation is easier to reason about than networked cross-container delegation.
- The same container can also be used to run Gemini or Codex directly.

### 3. Claude is the primary orchestrator

Claude is the default control point; Gemini and Codex are supporting workers.

**Rationale**

- This matches the intended interaction model.
- It keeps the operator workflow simple.
- It preserves direct fallback to other providers without changing environment or context.
- claude-delegator provides the local stdio MCP bridge Claude uses to hand work to Gemini and Codex without leaving the container.

### 4. Persistent state is required

The system is expected to retain operator and tool state across restarts.

**Rationale**

The system is expected to preserve:

- authentication and session material,
- tool configuration,
- shell history,
- Git configuration,
- SSH material,
- local preferences,
- and delegation-related state.

### 5. Workspace access is curated

The container should see only the repositories and shares relevant to its role.

**Rationale**

Even in a high-trust design, curated mounts improve focus, context quality, clarity, and blast-radius control.

### 6. Docker access is optional and capability-based

Docker access is not a baseline requirement of the architecture.

**Rationale**

- Many valid workflows need only code, files, and shell tools.
- Some workflows benefit from container inspection or control.
- The project should support both cases without changing its core identity.
- If enabled, Docker access should be treated as an intentional elevation of capability.

---

## Access Model

The AI Crowd is an **internal component**, not a default public application.

It belongs to the internal and administrative side of the homelab unless a distinct UI layer is intentionally defined later.

---

## Trust Model

The AI Crowd is a **trusted operator workspace**.

It should be assumed capable of:

- executing arbitrary shell commands,
- reading and editing mounted project files,
- affecting local state broadly,
- and, when Docker access is enabled, interacting with Docker with high privilege.

This trust model is acceptable only because the system is personal, the operator remains in the loop, and the project is not intended for untrusted workloads.

---

## Scope

The AI Crowd is meant to support:

- repository analysis and modification,
- AI-assisted coding sessions,
- delegated sub-agent workflows,
- project-oriented shell work,
- and optional Docker-aware operational work.

It is not intended to be a generic replacement for all host administration.

---

## Relationship to Existing Services

The AI Crowd is additive to the current homelab setup.

It is not intended to replace the existing proxying, networking, observability, media, or local AI services already present in the homelab.

It introduces a new internal capability: an agent-centric engineering runtime co-located with the main container host.

---

## Constraints

Treat the following as architectural constraints:

1. **The project name is `The AI Crowd`.**
2. **The baseline model is one shared environment, implemented as a single container.**
3. **Claude is the primary orchestrator.**
4. **Gemini and Codex are local subordinate workers.**
5. **Persistent home and state are required.**
6. **Workspace access should be curated.**
7. **Docker access is optional.**
8. **If Docker access is enabled, it should be treated as an intentional capability, not an architectural constant.**
9. **The system is internal-first and operator-facing.**
10. **The project is optimized for a personal homelab, not for zero-trust isolation.**

---

## Tradeoffs

### Benefits

- low orchestration complexity
- strong tool interoperability
- one coherent runtime
- simple delegation model
- easier direct provider fallback
- lower cognitive load for the operator
- flexibility to operate with or without Docker integration

### Costs

- weak isolation between AI tools
- tighter coupling inside one runtime
- a larger toolbox
- risk from mistakes, bad prompts, or unsafe commands
- high effective privilege if Docker access is enabled

---

## Limitations

### Security limitation

If Docker access is enabled, especially through raw socket access, the container should be treated as highly privileged.

### Isolation limitation

Claude, Gemini, and Codex do not have separate runtime boundaries in the chosen model.

### Operational coupling limitation

Dependency, package, and runtime changes affect one shared runtime.

### Autonomy limitation

The architecture is optimized for **interactive, human-supervised use**, not unattended autonomous operation at scale.

---

## Non-Goals

The AI Crowd is not intended to provide:

- multi-tenant hosting,
- hard privilege separation,
- internet-facing agent execution by default,
- a distributed service mesh of AI workers,
- or hardened isolation between AI providers.

---

## Implementation Interpretation Guidance

Interpret this document as a requirement to design a project that is:

- coherent,
- minimal in architectural layers,
- explicit about trust boundaries,
- aligned with the current homelab shape,
- and centered on one internal AI environment.

Avoid reinterpreting the project into a fragmented multi-container or microservice design unless there is a strong, explicit reason.

Optimize for:

- maintainability,
- readability,
- predictability,
- and alignment with the chosen operating model.

---

## Expected Project Character

The AI Crowd should feel like:

- a technical workspace,
- an internal AI operations desk,
- a practical homelab workspace,
- and a shared runtime where one primary AI can direct other specialist AIs.

It should not feel like:

- a public SaaS,
- a cluster platform,
- a security product,
- or a generic containerized desktop.

---

## Final Position

The AI Crowd is a **single-container, high-trust, internal engineering environment** on the main homelab server.

It deliberately chooses:

- one shared runtime,
- Claude-led orchestration,
- Gemini and Codex as local workers,
- persistent state,
- curated project access,
- and optional Docker integration.
