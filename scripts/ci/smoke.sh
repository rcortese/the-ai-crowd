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
  -f compose.build.yaml
  -f docker-compose.ci.override.yml
)

export COMPOSE_PROJECT_NAME="${compose_project}"

dockerfile_arg_default() {
  local arg_name="$1"
  awk -F= -v arg_name="${arg_name}" '
    $1 == "ARG " arg_name {
      print $2
      exit
    }
  ' Dockerfile
}

cleanup() {
  docker compose "${compose_files[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  chmod -R u+rwx "${temp_root}" >/dev/null 2>&1 || true
  rm -rf "${temp_root}"
}

trap cleanup EXIT

cd "${temp_repo}"

compose_config_json="$(docker compose "${compose_files[@]}" config --format json)"
config_user="$(jq -r '.services["the-ai-crowd"].user' <<< "${compose_config_json}")"
expected_uid="${config_user%%:*}"
expected_gid="${config_user##*:}"
expected_gemini_version="$(dockerfile_arg_default GEMINI_CLI_VERSION)"
expected_claude_version="$(dockerfile_arg_default CLAUDE_CODE_VERSION)"
expected_codex_version="$(dockerfile_arg_default CODEX_CLI_VERSION)"
path_shadow_fixture_dir="${temp_repo}/data/projects/path-shadow-codex"
path_shadow_marker="path-shadow-codex-user-install"

[[ -z "${expected_claude_version}" || "${expected_claude_version}" == "null" ]] \
  && { printf 'ERROR: CLAUDE_CODE_VERSION missing from Dockerfile ARG defaults\n' >&2; exit 1; }
[[ -z "${expected_codex_version}"  || "${expected_codex_version}"  == "null" ]] \
  && { printf 'ERROR: CODEX_CLI_VERSION missing from Dockerfile ARG defaults\n' >&2; exit 1; }

write_local_npm_cli_fixture \
  "${path_shadow_fixture_dir}" \
  "the-ai-crowd-codex-shadow" \
  "codex" \
  "${path_shadow_marker}"

docker compose "${compose_files[@]}" up -d --no-build "${service}"

container_id="$(docker compose "${compose_files[@]}" ps -q "${service}")"
[[ -n "${container_id}" ]]

docker inspect --format '{{.State.Running}}' "${container_id}" | grep -qx true

wait_for_service_ready

run_exec_cli_check() {
  local version_cmd="$1"
  local version_pattern="$2"
  local help_cmd="${3:-}"
  local help_pattern="${4:-}"
  local version_output
  local help_output

  version_output="$(
    docker compose "${compose_files[@]}" exec -T "${service}" \
      bash -lc "${version_cmd}" 2>&1 \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
  )"
  printf '%s\n' "${version_output}" | grep -q "${version_pattern}"

  if [[ -n "${help_cmd}" ]] && [[ -n "${help_pattern}" ]]; then
    help_output="$(
      docker compose "${compose_files[@]}" exec -T "${service}" \
        bash -lc "${help_cmd}" 2>&1
    )"
    printf '%s\n' "${help_output}" | grep -q "${help_pattern}"
  fi
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
  [[ "${NPM_CONFIG_PREFIX}" == "${HOME}/.local/share/the-ai-crowd/npm-global" ]]
  [[ -d "${NPM_CONFIG_PREFIX}" ]]
  [[ -w "${NPM_CONFIG_PREFIX}" ]]

  command -v claude >/dev/null
  command -v gemini >/dev/null
  command -v codex >/dev/null
  [[ "$(npm config get prefix)" == "${NPM_CONFIG_PREFIX}" ]]
  [[ "$(command -v codex)" == "/opt/the-ai-crowd/npm-global-seed/bin/codex" ]]


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

  npm install -g "${PATH_SHADOW_FIXTURE_DIR}" >/dev/null 2>&1
  [[ "$(command -v codex)" == "${NPM_CONFIG_PREFIX}/bin/codex" ]]
  [[ -x "/opt/the-ai-crowd/npm-global-seed/bin/codex" ]]
  [[ "$(codex)" == "${PATH_SHADOW_MARKER}" ]]

  status_file="${HOME}/.local/share/the-ai-crowd/claude-mcp-bootstrap.status"
  [[ ! -s "${status_file}" ]]
'

run_exec_cli_check \
  "gemini --version" \
  "^${expected_gemini_version}$"

# Exact version checks for claude and codex (dots escaped — they are regex metacharacters)
escaped_claude_version="${expected_claude_version//./\\.}"
escaped_codex_version="${expected_codex_version//./\\.}"
run_exec_cli_check \
  "claude --version" \
  "^${escaped_claude_version}$"
run_exec_cli_check \
  "codex --version" \
  "^${escaped_codex_version}$"

cd "${repo_root}"
