#!/usr/bin/env bash
set -euo pipefail

service="the-ai-crowd"
temp_root="$(mktemp -d)"
repo_root="$(pwd)"
temp_repo="${temp_root}/repo"
compose_project="ai-crowd-ci-${RANDOM}${RANDOM}"
container_name="${compose_project}-the-ai-crowd"
override_file="${temp_repo}/docker-compose.ci.override.yml"

export WORKBENCH_UID="$(id -u)"
export WORKBENCH_GID="$(id -g)"

mkdir -p "${temp_repo}"
cp docker-compose.yml docker-compose.docker.yml Dockerfile README.md ARCHITECTURE.md GUIDELINES.md "${temp_repo}/"
cp -r scripts config .dockerignore .gitignore .github "${temp_repo}/"
mkdir -p \
  "${temp_repo}/state/home" \
  "${temp_repo}/state/projects" \
  "${temp_repo}/state/references" \
  "${temp_repo}/state/scratch" \
  "${temp_repo}/state/ssh"

chmod 0777 \
  "${temp_repo}/state/home" \
  "${temp_repo}/state/projects" \
  "${temp_repo}/state/references" \
  "${temp_repo}/state/scratch" \
  "${temp_repo}/state/ssh"

cat > "${override_file}" <<EOF
services:
  the-ai-crowd:
    container_name: ${container_name}
EOF

compose_files=(
  -f docker-compose.yml
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

wait_for_exec_ready() {
  local attempts=0

  while true; do
    if docker compose "${compose_files[@]}" exec -T "${service}" true >/dev/null 2>&1; then
      return 0
    fi

    attempts=$((attempts + 1))
    if (( attempts > 30 )); then
      printf 'Timed out waiting for %s exec readiness.\n' "${service}" >&2
      docker compose "${compose_files[@]}" logs --no-color --tail=80 "${service}" >&2 || true
      return 1
    fi

    sleep 1
  done
}

wait_for_exec_ready

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

  run_cli_check "claude --version" "claude --help"
  run_cli_check "codex --version" "codex --help"
'

run_exec_cli_check \
  "gemini --version" \
  "^${expected_gemini_version}$" \
  "gemini --help" \
  "Gemini CLI - Launch an interactive CLI"

cd "${repo_root}"
