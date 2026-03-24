#!/usr/bin/env bash

# Maximum seconds to wait for container readiness or cleanup
CI_WAIT_TIMEOUT=90

set_workbench_ids() {
  export WORKBENCH_UID="${WORKBENCH_UID:-$(id -u)}"
  export WORKBENCH_GID="${WORKBENCH_GID:-$(id -g)}"
}

prepare_temp_repo_fixture() {
  local temp_repo="$1"

  mkdir -p "${temp_repo}"
  cp compose.yaml compose.docker.yaml Dockerfile README.md "${temp_repo}/"
  cp -r docs "${temp_repo}/"
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
