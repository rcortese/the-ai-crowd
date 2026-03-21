#!/usr/bin/env bash
set -euo pipefail

compose_base=(
  -f docker-compose.yml
)

compose_docker=(
  -f docker-compose.yml
  -f docker-compose.docker.yml
)

service="workbench"
temp_root="$(mktemp -d)"

fail() {
  printf 'The AI Crowd CI healthcheck failed: %s\n' "$*" >&2
  exit 1
}

export STATE_DIR="${temp_root}/state/home"
export PROJECTS_DIR="${temp_root}/state/projects"
export REFERENCES_DIR="${temp_root}/state/references"
export SCRATCH_DIR="${temp_root}/state/scratch"
export SSH_DIR="${temp_root}/state/ssh"

mkdir -p \
  "${STATE_DIR}" \
  "${PROJECTS_DIR}" \
  "${REFERENCES_DIR}" \
  "${SCRATCH_DIR}" \
  "${SSH_DIR}"

chmod 0777 \
  "${STATE_DIR}" \
  "${PROJECTS_DIR}" \
  "${REFERENCES_DIR}" \
  "${SCRATCH_DIR}" \
  "${SSH_DIR}"

cleanup() {
  docker compose "${compose_base[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  docker compose "${compose_docker[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "${temp_root}"
}

trap cleanup EXIT

run_healthcheck() {
  local -a compose_files=("$@")

  docker compose "${compose_files[@]}" up -d --no-build "${service}"
  docker compose "${compose_files[@]}" exec -T "${service}" /usr/local/bin/ai-crowd-healthcheck
  docker compose "${compose_files[@]}" down -v --remove-orphans >/dev/null
}

run_healthcheck "${compose_base[@]}"

[[ -S /var/run/docker.sock ]] || fail "docker-enabled healthcheck requires /var/run/docker.sock"
docker_gid="$(stat -c '%g' /var/run/docker.sock)"
export DOCKER_GID="${docker_gid}"
run_healthcheck "${compose_docker[@]}"
