#!/usr/bin/env bash

# Maximum seconds to wait for container readiness or cleanup
export CI_WAIT_TIMEOUT=90

set_workbench_ids() {
  export WORKBENCH_UID="${WORKBENCH_UID:-$(id -u)}"
  export WORKBENCH_GID="${WORKBENCH_GID:-$(id -g)}"
}

prepare_temp_repo_fixture() {
  local temp_repo="$1"

  mkdir -p "${temp_repo}"
  cp compose.yaml compose.build.yaml compose.docker.yaml Dockerfile README.md "${temp_repo}/"
  cp -r docs scripts .dockerignore .gitignore .github "${temp_repo}/"
  mkdir -p \
    "${temp_repo}/data/home" \
    "${temp_repo}/data/projects" \
    "${temp_repo}/data/references" \
    "${temp_repo}/data/scratch" \
    "${temp_repo}/data/ssh"

  chmod 0777 \
    "${temp_repo}/data/home" \
    "${temp_repo}/data/projects" \
    "${temp_repo}/data/references" \
    "${temp_repo}/data/scratch" \
    "${temp_repo}/data/ssh"
}

# compose_files and service are caller-set globals
# shellcheck disable=SC2154
wait_for_service_ready() {
  local attempts=0

  while true; do
    if docker compose "${compose_files[@]}" exec -T "${service}" /usr/local/bin/ai-crowd-healthcheck >/dev/null 2>&1; then
      return 0
    fi

    attempts=$((attempts + 1))
    if (( attempts > CI_WAIT_TIMEOUT )); then
      printf 'Timed out waiting for %s readiness.\n' "${service}" >&2
      docker compose "${compose_files[@]}" logs --no-color --tail=80 "${service}" >&2 || true
      return 1
    fi

    sleep 1
  done
}

write_compose_override() {
  local override_file="$1"
  local container_name="$2"

  cat > "${override_file}" <<EOF
services:
  the-ai-crowd:
    container_name: ${container_name}
EOF
}
