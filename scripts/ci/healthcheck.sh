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
network_name="${compose_project}_default"
override_file="${temp_repo}/docker-compose.ci.override.yml"

fail() {
  printf 'The AI Crowd CI healthcheck failed: %s\n' "$*" >&2
  exit 1
}

set_workbench_ids
prepare_temp_repo_fixture "${temp_repo}"
write_compose_override "${override_file}" "${container_name}"

compose_base=(
  -f compose.yaml
  -f docker-compose.ci.override.yml
)

compose_docker=(
  -f compose.yaml
  -f compose.docker.yaml
  -f docker-compose.ci.override.yml
)

export COMPOSE_PROJECT_NAME="${compose_project}"

cleanup() {
  docker compose "${compose_base[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  docker compose "${compose_docker[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
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

wait_for_service_ready() {
  local -a compose_files=("$@")
  local attempts=0

  while true; do
    if docker compose "${compose_files[@]}" exec -T "${service}" /usr/local/bin/ai-crowd-healthcheck >/dev/null 2>&1; then
      return 0
    fi

    attempts=$((attempts + 1))
    if (( attempts > CI_WAIT_TIMEOUT )); then
      printf 'Timed out waiting for %s readiness.\n' "${service}" >&2
      docker compose "${compose_files[@]}" logs --no-color --tail=80 "${service}" >&2 || true
      exit 1
    fi

    sleep 1
  done
}

run_healthcheck() {
  local -a compose_files=("$@")

  docker compose "${compose_files[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  wait_for_cleanup
  docker compose "${compose_files[@]}" up -d --no-build "${service}"
  wait_for_service_ready "${compose_files[@]}"
  docker compose "${compose_files[@]}" exec -T "${service}" /usr/local/bin/ai-crowd-healthcheck
  docker compose "${compose_files[@]}" down -v --remove-orphans >/dev/null
  wait_for_cleanup
}

run_healthcheck "${compose_base[@]}"

[[ -S /var/run/docker.sock ]] || fail "docker-enabled healthcheck requires /var/run/docker.sock"
docker_gid="$(stat -c '%g' /var/run/docker.sock)"
export DOCKER_GID="${docker_gid}"
run_healthcheck "${compose_docker[@]}"

cd "${repo_root}"
