#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ci/lib.sh
source "${script_dir}/lib.sh"

service="the-ai-crowd"
repo_root="$(pwd)"
setup_ci_compose_fixture "${repo_root}" "the-ai-crowd-ci"
network_name="${compose_project}_default"

fail() {
  printf 'The AI Crowd CI healthcheck failed: %s\n' "$*" >&2
  exit 1
}

compose_base=(
  -f compose.yaml
  -f compose.build.yaml
  -f docker-compose.ci.override.yml
)

compose_docker=(
  -f compose.yaml
  -f compose.build.yaml
  -f compose.docker.yaml
  -f docker-compose.ci.override.yml
)
cleanup() {
  compose_down_quiet "${compose_base[@]}"
  compose_down_quiet "${compose_docker[@]}"
  remove_test_volumes "${compose_project}"
  wait_for_cleanup
  chmod -R u+rwx "${temp_root}" >/dev/null 2>&1 || true
  rm -rf "${temp_root}"
}

trap cleanup EXIT

cd "${temp_repo}"

wait_for_cleanup() {
  local attempts=0

  while docker ps -a --filter "name=^/${container_name}$" -q | grep -q .; do
    attempts=$((attempts + 1))
    if (( attempts > CI_WAIT_TIMEOUT )); then
      printf 'Timed out waiting for container cleanup.\n' >&2
      exit 1
    fi
    sleep 1
  done

  attempts=0
  while docker network ls --format '{{.Name}}' | grep -qx "${network_name}"; do
    attempts=$((attempts + 1))
    if (( attempts > CI_WAIT_TIMEOUT )); then
      printf 'Timed out waiting for network cleanup.\n' >&2
      exit 1
    fi
    sleep 1
  done
}

assert_missing_docker_gid_fails_fast() {
  local output_file

  output_file="$(mktemp)"
  if env -u DOCKER_GID docker compose "${compose_docker[@]}" config >"${output_file}" 2>&1; then
    cat "${output_file}" >&2
    rm -f "${output_file}"
    fail "compose.docker.yaml unexpectedly rendered without DOCKER_GID"
  fi

  grep -q 'DOCKER_GID' "${output_file}" \
    || { cat "${output_file}" >&2; rm -f "${output_file}"; fail "missing-variable failure did not mention DOCKER_GID"; }
  grep -q 'Set DOCKER_GID to the GID of /var/run/docker.sock on the host' "${output_file}" \
    || { cat "${output_file}" >&2; rm -f "${output_file}"; fail "missing-variable failure did not include the explicit remediation message"; }

  rm -f "${output_file}"
}

run_healthcheck() {
  local -a compose_files=("$@")
  local bootstrap_check_cmd
  local healthcheck_cmd
  local output_file

  bootstrap_check_cmd="$(container_bootstrap_check_command)"
  healthcheck_cmd="$(container_healthcheck_command)"

  compose_down_quiet "${compose_files[@]}"
  wait_for_cleanup
  seed_test_volumes "${compose_project}" "${temp_repo}"
  docker compose "${compose_files[@]}" up -d --no-build "${service}"
  wait_for_service_ready "${service}" "${compose_files[@]}"
  docker compose "${compose_files[@]}" exec -T "${service}" bash -lc "${healthcheck_cmd}"
  docker compose "${compose_files[@]}" exec -T "${service}" bash -lc "${bootstrap_check_cmd}"
  # bootstrap status assertions
  docker compose "${compose_files[@]}" exec -T "${service}" bash -lc '
    set -euo pipefail
    complete_file="${HOME}/.local/share/the-ai-crowd/bootstrap-validation.complete"
    [[ -f "${complete_file}" ]] || { printf "bootstrap validation did not complete\n" >&2; exit 1; }
    status_file="${HOME}/.local/share/the-ai-crowd/bootstrap-validation.status"
    if [[ -s "${status_file}" ]]; then
      printf "bootstrap validation degraded: %s\n" "$(cat "${status_file}")" >&2
      exit 1
    fi
    status_file="${HOME}/.local/share/the-ai-crowd/claude-mcp-bootstrap.status"
    if [[ -s "${status_file}" ]]; then
      printf "claude MCP bootstrap degraded: %s\n" "$(cat "${status_file}")" >&2
      exit 1
    fi
  '
  output_file="$(mktemp)"
  docker compose "${compose_files[@]}" exec -T "${service}" bash -lc \
    'printf "%s\n" "forced bootstrap validation failure" > "${HOME}/.local/share/the-ai-crowd/bootstrap-validation.status"'
  if docker compose "${compose_files[@]}" exec -T "${service}" bash -lc "${healthcheck_cmd}" >"${output_file}" 2>&1; then
    cat "${output_file}" >&2
    rm -f "${output_file}"
    fail "healthcheck unexpectedly passed with degraded bootstrap validation status"
  fi
  grep -q 'bootstrap validation degraded' "${output_file}" \
    || { cat "${output_file}" >&2; rm -f "${output_file}"; fail "healthcheck failure did not mention degraded bootstrap validation"; }
  rm -f "${output_file}"
  docker compose "${compose_files[@]}" exec -T "${service}" bash -lc \
    ': > "${HOME}/.local/share/the-ai-crowd/bootstrap-validation.status"'
  docker compose "${compose_files[@]}" down -v --remove-orphans >/dev/null
  wait_for_cleanup
}

run_healthcheck "${compose_base[@]}"
assert_missing_docker_gid_fails_fast

[[ -S /var/run/docker.sock ]] || fail "docker-enabled healthcheck requires /var/run/docker.sock"
docker_gid="$(stat -c '%g' /var/run/docker.sock)"
export DOCKER_GID="${docker_gid}"
run_healthcheck "${compose_docker[@]}"

cd "${repo_root}"
