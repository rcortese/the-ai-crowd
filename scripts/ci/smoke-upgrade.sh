#!/usr/bin/env bash
# smoke-upgrade.sh — persisted-state recovery scenario test
#
# Verifies that entrypoint.sh recovers persisted Claude MCP state on restart.
#
# Usage:
#   docker compose -f compose.yaml -f compose.build.yaml build the-ai-crowd
#   bash scripts/ci/smoke-upgrade.sh
#
# Not wired into the default CI path. Required for pre-release verification.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ci/lib.sh
# shellcheck disable=SC1091
source "${script_dir}/lib.sh"

set_workbench_ids

service="the-ai-crowd"
temp_root="$(mktemp -d)"
repo_root="$(pwd)"
temp_repo="${temp_root}/repo"
compose_project="ai-crowd-upgrade-${RANDOM}${RANDOM}"
container_name="${compose_project}-the-ai-crowd"
override_file="${temp_repo}/docker-compose.ci.override.yml"

prepare_temp_repo_fixture "${temp_repo}"
write_compose_override "${override_file}" "${container_name}"

compose_files=(
  -f compose.yaml
  -f compose.build.yaml
  -f docker-compose.ci.override.yml
)

export COMPOSE_PROJECT_NAME="${compose_project}"

cleanup() {
  docker compose "${compose_files[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  chmod -R u+rwx "${temp_root}" >/dev/null 2>&1 || true
  rm -rf "${temp_root}"
}

trap cleanup EXIT

restart_and_wait() {
  docker compose "${compose_files[@]}" restart "${service}" >/dev/null
  wait_for_service_ready
}

assert_registered() {
  local mcp_name="$1"

  docker exec "${container_name}" bash -lc \
    "jq -e '.mcpServers.${mcp_name} != null' ~/.claude.json" >/dev/null \
    || { printf '[smoke-upgrade] FAIL: MCP missing after restart: %s\n' "${mcp_name}" >&2; exit 1; }
}

assert_codex_command() {
  docker exec "${container_name}" bash -lc \
    'jq -e ".mcpServers.codex.command == \"codex\"" ~/.claude.json' >/dev/null \
    || { printf '[smoke-upgrade] FAIL: codex MCP command not restored\n' >&2; exit 1; }
}

cd "${temp_repo}"
docker compose "${compose_files[@]}" up -d --no-build "${service}"
wait_for_service_ready

printf '[smoke-upgrade] === Persisted-state recovery scenarios ===\n'

# Guard: container must be running with a valid ~/.claude.json
docker exec "${container_name}" bash -lc 'test -f ~/.claude.json' \
  || { printf '[smoke-upgrade] FAIL: ~/.claude.json not found after bootstrap\n' >&2; exit 1; }

# Scenario 1: stale MCP command must be overwritten
docker exec "${container_name}" sh -c '
  jq ".mcpServers.codex.command = \"wrong\"" ~/.claude.json > /tmp/bad.json \
  && cp /tmp/bad.json ~/.claude.json
'
printf '[smoke-upgrade] Injected stale MCP config (codex.command = "wrong")\n'
restart_and_wait
assert_codex_command
assert_registered codex
assert_registered gemini
printf '[smoke-upgrade] PASS: stale MCP command repaired\n'

# Scenario 2: missing config should be restored from valid backup
docker exec "${container_name}" bash -lc '
  cp ~/.claude.json ~/.claude.json.backup
  rm -f ~/.claude.json
'
printf '[smoke-upgrade] Removed ~/.claude.json with valid backup present\n'
restart_and_wait
assert_registered codex
assert_registered gemini
assert_codex_command
printf '[smoke-upgrade] PASS: missing config restored from backup\n'

# Scenario 3: valid JSON with wrong top-level type should normalize
docker exec "${container_name}" bash -lc '
  rm -f ~/.claude.json.backup
  printf "[]\n" > ~/.claude.json
'
printf '[smoke-upgrade] Replaced ~/.claude.json with a JSON array\n'
restart_and_wait
assert_registered codex
assert_registered gemini
printf '[smoke-upgrade] PASS: non-object config normalized\n'

# Scenario 4: invalid mcpServers type should normalize
docker exec "${container_name}" bash -lc '
  jq ".mcpServers = []" ~/.claude.json > /tmp/bad.json
  cp /tmp/bad.json ~/.claude.json
'
printf '[smoke-upgrade] Replaced mcpServers with an array\n'
restart_and_wait
assert_registered codex
assert_registered gemini
printf '[smoke-upgrade] PASS: invalid mcpServers type normalized\n'

# Scenario 5: missing MCP entries should be re-registered
docker exec "${container_name}" bash -lc '
  jq "del(.mcpServers.codex, .mcpServers.gemini)" ~/.claude.json > /tmp/bad.json
  cp /tmp/bad.json ~/.claude.json
'
printf '[smoke-upgrade] Deleted codex and gemini MCP entries\n'
restart_and_wait
assert_registered codex
assert_registered gemini
assert_codex_command
printf '[smoke-upgrade] PASS: missing MCP entries re-registered\n'

printf '[smoke-upgrade] === Persisted-state recovery scenarios PASSED ===\n'

cd "${repo_root}"
