# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.2.0] - 2026-03-24

### Added

- Multi-model delegation via `claude-delegator` baked into the image for zero-config MCP delegation to Gemini and Codex.
- GitHub SSH host keys pinned in the image for stronger supply-chain safety during Git operations.
- SHA256 integrity verification of the `claude-delegator` tarball at build time.
- A dedicated lint workflow that enforces `shellcheck` across project scripts.

### Changed

- SSH is now the default Git authentication path, avoiding token expiry and working cleanly with hardware-backed keys.
- MCP bootstrap is decoupled from the boot critical path so startup degrades with warnings instead of failing fast.
- CI workflows are split into distinct lint, CI, and publish scopes.
- Shared CI fixtures were extracted into `scripts/ci/lib.sh`.
- Node.js is pinned to the exact `20.20.1` release instead of a major-only pin.

### Fixed

- CI readiness polling timeout increased to 90 seconds.
- Gemini CLI smoke coverage no longer depends on a brittle help-string match.
- `claude-delegator` rules now sync on every boot instead of only on first run.
- `CLAUDE_DELEGATOR_COMMIT` now has a safe build-time default for CI environments without `.env`.

## [0.1.0]

### Added

- Initial release of The AI Crowd as a single-container, persistent AI workstation for Claude, Gemini, and Codex in a homelab environment.
