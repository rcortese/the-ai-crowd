#!/usr/bin/env bash
# smoke-upgrade.sh — persisted-state recovery and recreation scenario test
#
# Verifies that user-scoped updates and Claude MCP state survive restart and
# container recreation without an image rebuild.
#
# Usage:
#   docker compose -f compose.yaml -f compose.build.yaml build the-ai-crowd
#   bash scripts/ci/smoke-upgrade.sh
#
# Wired into the default CI path for persisted-state recovery verification.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ci/lib.sh
# shellcheck disable=SC1091
source "${script_dir}/lib.sh"

set_workbench_ids
export DOCKER_ENABLE=false

service="the-ai-crowd"
repo_root="$(pwd)"
temp_root="$(create_temp_repo_root "${repo_root}")"
temp_repo="${temp_root}/repo"
compose_project="the-ai-crowd-upgrade-${RANDOM}${RANDOM}"
container_name="${compose_project}-the-ai-crowd"
override_file="${temp_repo}/docker-compose.ci.override.yml"
path_shadow_fixture_dir="${temp_repo}/data/projects/path-shadow-codex-persist"
path_shadow_marker="path-shadow-codex-persisted"

prepare_temp_repo_fixture "${temp_repo}"
write_compose_override "${override_file}" "${container_name}" "${compose_project}"
write_local_npm_cli_fixture \
  "${path_shadow_fixture_dir}" \
  "the-ai-crowd-codex-persist" \
  "codex" \
  "${path_shadow_marker}"
seed_test_volumes "${compose_project}" "${temp_repo}"

compose_files=(
  -f compose.yaml
  -f compose.build.yaml
  -f docker-compose.ci.override.yml
)

export COMPOSE_PROJECT_NAME="${compose_project}"

cleanup() {
  docker compose "${compose_files[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  remove_test_volumes "${compose_project}"
  chmod -R u+rwx "${temp_root}" >/dev/null 2>&1 || true
  rm -rf "${temp_root}"
}

trap cleanup EXIT

restart_and_wait() {
  docker compose "${compose_files[@]}" restart "${service}" >/dev/null
  wait_for_service_ready
}

recreate_and_wait() {
  docker compose "${compose_files[@]}" down --remove-orphans >/dev/null
  docker compose "${compose_files[@]}" up -d --no-build "${service}"
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

assert_user_codex_override() {
  docker exec "${container_name}" bash -lc '
    set -euo pipefail
    [[ "$(command -v codex)" == "${HOME}/.local/share/the-ai-crowd/npm-global/bin/codex" ]]
    [[ "$(codex)" == "path-shadow-codex-persisted" ]]
  ' || {
    printf '[smoke-upgrade] FAIL: user-installed codex override did not persist\n' >&2
    exit 1
  }
}

cd "${temp_repo}"
docker compose "${compose_files[@]}" up -d --no-build "${service}"
wait_for_service_ready

printf '[smoke-upgrade] === Persisted-state recovery scenarios ===\n'

# Guard: container must be running with a valid ~/.claude.json
docker exec "${container_name}" bash -lc 'test -f ~/.claude.json' \
  || { printf '[smoke-upgrade] FAIL: ~/.claude.json not found after bootstrap\n' >&2; exit 1; }

# Scenario 0: user-scoped CLI override must survive container recreation

docker exec "${container_name}" bash -lc '
  set -euo pipefail
  [[ "$(command -v codex)" == "/opt/the-ai-crowd/npm-global-seed/bin/codex" ]]
  npm install -g /workspace/projects/path-shadow-codex-persist >/dev/null 2>&1
  [[ "$(command -v codex)" == "${HOME}/.local/share/the-ai-crowd/npm-global/bin/codex" ]]
  [[ "$(codex)" == "path-shadow-codex-persisted" ]]
'
printf '[smoke-upgrade] Installed user-scoped codex override\n'
recreate_and_wait
assert_user_codex_override
printf '[smoke-upgrade] PASS: user-scoped codex override survived recreation\n'

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
