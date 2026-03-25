#!/usr/bin/env bash
# smoke-upgrade.sh — persisted-state upgrade scenario test
#
# Verifies that entrypoint.sh self-heals stale MCP configuration on restart.
# Depends on Task 1.2 (always-overwrite MCP registration) being in place.
#
# Usage: run AFTER smoke.sh passes against a live container.
#   bash scripts/ci/smoke.sh && bash scripts/ci/smoke-upgrade.sh
#
# Not wired into the default CI path. Required for pre-release verification.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ci/lib.sh
# shellcheck disable=SC1091
source "${script_dir}/lib.sh"

set_workbench_ids

service="the-ai-crowd"
compose_project="${COMPOSE_PROJECT_NAME:-ai-crowd-ci}"
container_name="${compose_project}-${service}"
compose_files=(-f compose.yaml)

printf '[smoke-upgrade] === Upgrade scenario: stale MCP config ===\n'

# Guard: container must be running with a valid ~/.claude.json
docker exec "${container_name}" bash -lc 'test -f ~/.claude.json' \
  || { printf '[smoke-upgrade] FAIL: ~/.claude.json not found — run smoke.sh first\n' >&2; exit 1; }

# Step 1: Corrupt .claude.json inside the container
docker exec "${container_name}" sh -c '
  jq ".mcpServers.codex.command = \"wrong\"" ~/.claude.json > /tmp/bad.json \
  && cp /tmp/bad.json ~/.claude.json
'
printf '[smoke-upgrade] Injected stale MCP config (codex.command = "wrong")\n'

# Step 2: Restart and wait for healthy
docker compose -p "${compose_project}" "${compose_files[@]}" restart "${service}"
wait_for_service_ready

# Step 3: Assert self-healing — command must be restored to correct value
docker exec -T "${container_name}" bash -lc \
  'jq -e ".mcpServers.codex.command == \"codex\"" ~/.claude.json' >/dev/null \
  || { printf '[smoke-upgrade] FAIL: MCP self-healing failed — codex.command not restored\n' >&2; exit 1; }

printf '[smoke-upgrade] PASS: MCP self-healing verified\n'
printf '[smoke-upgrade] === Upgrade scenario PASSED ===\n'
