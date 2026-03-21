#!/usr/bin/env bash
set -euo pipefail

compose_files=(
  -f docker-compose.yml
)

service="workbench"
temp_root="$(mktemp -d)"

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
  docker compose "${compose_files[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "${temp_root}"
}

trap cleanup EXIT

config_user="$(docker compose "${compose_files[@]}" config --format json | jq -r '.services.workbench.user')"
expected_uid="${config_user%%:*}"
expected_gid="${config_user##*:}"

docker compose "${compose_files[@]}" up -d --no-build "${service}"

container_id="$(docker compose "${compose_files[@]}" ps -q "${service}")"
[[ -n "${container_id}" ]]

docker inspect -f '{{.State.Running}}' "${container_id}" | grep -qx true

docker compose "${compose_files[@]}" exec -T \
  -e EXPECTED_UID="${expected_uid}" \
  -e EXPECTED_GID="${expected_gid}" \
  "${service}" bash -lc '
  set -euo pipefail

  [[ "$(id -u)" == "${EXPECTED_UID}" ]]
  [[ "$(id -g)" == "${EXPECTED_GID}" ]]
  [[ "$(id -un)" == "operator" ]]
  [[ -d /workspace/projects ]]
  [[ -d /workspace/references ]]
  [[ -d /workspace/scratch ]]

  command -v claude >/dev/null
  command -v gemini >/dev/null
  command -v codex >/dev/null

  claude --version >/dev/null
  gemini --version >/dev/null
  codex --version >/dev/null

  claude --help >/dev/null
  gemini --help >/dev/null
  codex --help >/dev/null
'
