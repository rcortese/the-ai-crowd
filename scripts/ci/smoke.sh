#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ci/lib.sh
source "${script_dir}/lib.sh"

service="the-ai-crowd"
temp_root="$(mktemp -d)"
repo_root="$(pwd)"
temp_repo="${temp_root}/repo"
compose_project="ai-crowd-ci-${RANDOM}${RANDOM}"
container_name="${compose_project}-the-ai-crowd"
override_file="${temp_repo}/docker-compose.ci.override.yml"

set_workbench_ids
prepare_temp_repo_fixture "${temp_repo}"
write_compose_override "${override_file}" "${container_name}"

compose_files=(
  -f compose.yaml
  -f docker-compose.ci.override.yml
)

export COMPOSE_PROJECT_NAME="${compose_project}"

cleanup() {
  docker compose "${compose_files[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  chmod -R u+rwx "${temp_root}" >/dev/null 2>&1 || true
  rm -rf "${temp_root}"
}

trap cleanup EXIT

cd "${temp_repo}"

config_user="$(docker compose "${compose_files[@]}" config --format json | jq -r '.services["the-ai-crowd"].user')"
expected_uid="${config_user%%:*}"
expected_gid="${config_user##*:}"
expected_gemini_version="$(
  docker compose "${compose_files[@]}" config --format json |
    jq -r '.services["the-ai-crowd"].build.args.GEMINI_CLI_VERSION'
)"

docker compose "${compose_files[@]}" up -d --no-build "${service}"

container_id="$(docker compose "${compose_files[@]}" ps -q "${service}")"
[[ -n "${container_id}" ]]

docker inspect -f '{{.State.Running}}' "${container_id}" | grep -qx true

wait_for_service_ready() {
  local attempts=0

  while true; do
    if docker compose "${compose_files[@]}" exec -T "${service}" /usr/local/bin/ai-crowd-healthcheck >/dev/null 2>&1; then
      return 0
    fi

    attempts=$((attempts + 1))
    if (( attempts > 30 )); then
      printf 'Timed out waiting for %s readiness.\n' "${service}" >&2
      docker compose "${compose_files[@]}" logs --no-color --tail=80 "${service}" >&2 || true
      return 1
    fi

    sleep 1
  done
}

wait_for_service_ready

run_exec_cli_check() {
  local version_cmd="$1"
  local version_pattern="$2"
  local help_cmd="$3"
  local help_pattern="$4"
  local version_output
  local help_output

  version_output="$(
    docker compose "${compose_files[@]}" exec -T "${service}" \
      bash -lc "${version_cmd}" 2>&1
  )"
  help_output="$(
    docker compose "${compose_files[@]}" exec -T "${service}" \
      bash -lc "${help_cmd}" 2>&1
  )"

  printf '%s\n' "${version_output}" | grep -q "${version_pattern}"
  printf '%s\n' "${help_output}" | grep -q "${help_pattern}"
}

docker compose "${compose_files[@]}" exec -T \
  -e EXPECTED_UID="${expected_uid}" \
  -e EXPECTED_GID="${expected_gid}" \
  "${service}" bash -lc '
  set -euo pipefail

  run_cli_check() {
    local version_cmd="$1"
    local help_cmd="$2"
    local expect_timeout="${3:-false}"

    local version_status=0
    local help_status=0

    timeout 10 bash -lc "${version_cmd}" >/dev/null 2>&1 || version_status=$?
    timeout 10 bash -lc "${help_cmd}" >/dev/null 2>&1 || help_status=$?

    if [[ "${expect_timeout}" == "true" ]]; then
      [[ "${version_status}" == "0" || "${version_status}" == "124" ]]
      [[ "${help_status}" == "0" || "${help_status}" == "124" ]]
    else
      [[ "${version_status}" == "0" ]]
      [[ "${help_status}" == "0" ]]
    fi
  }

  [[ "$(id -u)" == "${EXPECTED_UID}" ]]
  [[ "$(id -g)" == "${EXPECTED_GID}" ]]
  [[ -d /workspace/projects ]]
  [[ -d /workspace/references ]]
  [[ -d /workspace/scratch ]]

  command -v claude >/dev/null
  command -v gemini >/dev/null
  command -v codex >/dev/null

  [[ -f "${HOME}/.claude/rules/delegator/orchestration.md" ]]
  [[ -f "${CLAUDE_PLUGIN_ROOT}/server/gemini/index.js" ]]
  node --check "${CLAUDE_PLUGIN_ROOT}/server/gemini/index.js" >/dev/null 2>&1

  run_cli_check "claude --version" "claude --help"
  run_cli_check "codex --version" "codex --help"

  check_claude_mcp_registered() {
    local mcp_name="$1"

    jq -e --arg mcp_name "${mcp_name}" ".mcpServers[\$mcp_name] != null" "${HOME}/.claude.json" >/dev/null 2>&1
  }

  check_claude_mcp_registered codex
  check_claude_mcp_registered gemini

  status_file="${HOME}/.local/share/ai-crowd/claude-mcp-bootstrap.status"
  [[ ! -s "${status_file}" ]]
'

run_exec_cli_check \
  "gemini --version" \
  "^${expected_gemini_version}$" \
  "gemini --help" \
  "Gemini CLI - Launch an interactive CLI"

cd "${repo_root}"
