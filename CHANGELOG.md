# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.1] - 2026-04-04

### Added
- Runtime bootstrap check script to improve container startup reliability and validation
- Configuration consistency check for release inputs to ensure deployment stability
- Release gating for tag pushes to ensure CI success before deployment

### Changed
- Standardized binary and project names with the `the-ai-crowd` prefix across the repository
- Implemented Docker-aware Codex sandbox behavior and decoupled sandbox logic from Docker host mode
- Split bootstrap validation from runtime health checks to tighten container startup verification
- Enhanced documentation regarding onboarding defaults, bootstrap flow, seccomp tradeoffs, and runtime baselines

### Security
- Restored default-deny security posture by migrating from relaxed `unconfined` seccomp overlays to a centralized tracked profile (`seccomp/the-ai-crowd.json`) in the primary `compose.yaml` while maintaining Codex sandbox compatibility

## [0.4.0] - 2026-04-02

### Changed
- Allowed non-root npm CLI upgrades through a persisted user prefix
- Split Dockerfile system bootstrap from user setup and tightened Docker-aware runtime validation

### Fixed
- Fixed Docker-aware Compose setup by requiring explicit `DOCKER_GID` mapping and Compose availability checks
- Fixed smoke and healthcheck coverage for path shadowing, persisted CLI overrides, and fixture roots
- Excluded local data from the Docker build context

## [0.3.1] - 2026-03-31

### Changed
- Updated Node.js to 20.20.2 and Codex CLI to 0.118.0
- Upgraded GitHub Actions to major releases
- Removed git SHA tags from Docker Hub metadata

### Fixed
- Replaced deprecated docker inspect flags
- Fixed keychain initialization on Linux Gemini warning

## [0.3.0] - 2026-03-29

### Added
- Added MIT License

### Changed
- Required Claude delegation for health status
- Updated README.md and visual assets
- Updated Claude bootstrap
- Synced recovery tests with MCP health checks

## [0.2.1] - 2026-03-29

### Added
- Added pull-first deployment to Docker Compose
- Extracted Dockerfile arguments to publish pipeline

### Changed
- Updated setup to pull-first workflow

### Fixed
- Pinned Node.js to 20.20.0
- Fixed CI fixture copy
- Updated Docker CLI guides
- Added delegator rule pruning

## [0.2.0] - 2026-03-25

### Added
- Added Gemini and Codex delegation
- Added docker-ce-cli
- Added CODEX_MCP_MODEL variable
- Pinned GitHub SSH keys and claude-delegator SHA256
- Added ShellCheck workflow
- Added smoke-upgrade.sh tests

### Changed
- Updated Git authentication to SSH
- Updated MCP initialization path
- Split CI workflows

### Fixed
- Updated CI readiness timeout to 90s
- Removed string-matching from Gemini tests
- Forced delegation rule sync

## [0.1.0] - 2026-03-21

### Added
- Initial release

[Unreleased]: https://github.com/the-ai-crowd/the-ai-crowd/compare/v0.4.1...HEAD
[0.4.1]: https://github.com/the-ai-crowd/the-ai-crowd/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/the-ai-crowd/the-ai-crowd/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/the-ai-crowd/the-ai-crowd/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/the-ai-crowd/the-ai-crowd/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/the-ai-crowd/the-ai-crowd/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/the-ai-crowd/the-ai-crowd/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/the-ai-crowd/the-ai-crowd/releases/tag/v0.1.0
