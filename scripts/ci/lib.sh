#!/usr/bin/env bash

# Maximum seconds to wait for container readiness or cleanup
export CI_WAIT_TIMEOUT=90

set_workbench_ids() {
  export WORKBENCH_UID="${WORKBENCH_UID:-$(id -u)}"
  export WORKBENCH_GID="${WORKBENCH_GID:-$(id -g)}"
}

create_temp_repo_root() {
  local repo_root="$1"
  local temp_parent="${CI_FIXTURE_ROOT:-${repo_root}/tmp}"

  mkdir -p "${temp_parent}"
  mktemp -d "${temp_parent}/ci-fixture.XXXXXX"
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

fixture_volume_name() {
  local compose_project="$1"
  local volume_suffix="$2"

  printf '%s_%s\n' "${compose_project}" "${volume_suffix}"
}

container_healthcheck_command() {
  cat <<'EOF'
if [[ -x /usr/local/bin/the-ai-crowd-healthcheck ]]; then
  exec /usr/local/bin/the-ai-crowd-healthcheck
else
  exec /usr/local/bin/ai-crowd-healthcheck
fi
EOF
}

# compose_files and service are caller-set globals
# shellcheck disable=SC2154
wait_for_service_ready() {
  local attempts=0
  local healthcheck_cmd

  healthcheck_cmd="$(container_healthcheck_command)"

  while true; do
    if docker compose "${compose_files[@]}" exec -T "${service}" bash -lc "${healthcheck_cmd}" >/dev/null 2>&1; then
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
  local compose_project="$3"
  local home_volume projects_volume references_volume scratch_volume ssh_volume

  home_volume="$(fixture_volume_name "${compose_project}" ci-home)"
  projects_volume="$(fixture_volume_name "${compose_project}" ci-projects)"
  references_volume="$(fixture_volume_name "${compose_project}" ci-references)"
  scratch_volume="$(fixture_volume_name "${compose_project}" ci-scratch)"
  ssh_volume="$(fixture_volume_name "${compose_project}" ci-ssh)"

  cat > "${override_file}" <<EOF
services:
  the-ai-crowd:
    container_name: ${container_name}
    volumes:
      - ci-home:/home/\${WORKBENCH_USER:-operator}
      - ci-projects:/workspace/projects
      - ci-references:/workspace/references:ro
      - ci-scratch:/workspace/scratch
      - ci-ssh:/home/\${WORKBENCH_USER:-operator}/.ssh
volumes:
  ci-home:
    name: ${home_volume}
    external: true
  ci-projects:
    name: ${projects_volume}
    external: true
  ci-references:
    name: ${references_volume}
    external: true
  ci-scratch:
    name: ${scratch_volume}
    external: true
  ci-ssh:
    name: ${ssh_volume}
    external: true
EOF
}

remove_test_volumes() {
  local compose_project="$1"

  docker volume rm -f \
    "$(fixture_volume_name "${compose_project}" ci-home)" \
    "$(fixture_volume_name "${compose_project}" ci-projects)" \
    "$(fixture_volume_name "${compose_project}" ci-references)" \
    "$(fixture_volume_name "${compose_project}" ci-scratch)" \
    "$(fixture_volume_name "${compose_project}" ci-ssh)" \
    >/dev/null 2>&1 || true
}

seed_volume_from_fixture() {
  local volume_name="$1"
  local fixture_dir="$2"

  [[ -d "${fixture_dir}" ]]
  docker volume create "${volume_name}" >/dev/null

  if find "${fixture_dir}" -mindepth 1 -print -quit | grep -q .; then
    tar -C "${fixture_dir}" -cf - . | docker run --rm -i --user 0:0 --entrypoint bash \
      -e EXPECTED_UID="${WORKBENCH_UID}" \
      -e EXPECTED_GID="${WORKBENCH_GID}" \
      -v "${volume_name}:/seed" \
      the-ai-crowd:local \
      -lc 'set -euo pipefail; mkdir -p /seed; tar -xf - -C /seed; chown -R "${EXPECTED_UID}:${EXPECTED_GID}" /seed'
  else
    docker run --rm --user 0:0 --entrypoint bash \
      -e EXPECTED_UID="${WORKBENCH_UID}" \
      -e EXPECTED_GID="${WORKBENCH_GID}" \
      -v "${volume_name}:/seed" \
      the-ai-crowd:local \
      -lc 'set -euo pipefail; mkdir -p /seed; chown -R "${EXPECTED_UID}:${EXPECTED_GID}" /seed'
  fi
}

seed_test_volumes() {
  local compose_project="$1"
  local temp_repo="$2"

  remove_test_volumes "${compose_project}"
  seed_volume_from_fixture "$(fixture_volume_name "${compose_project}" ci-home)" "${temp_repo}/data/home"
  seed_volume_from_fixture "$(fixture_volume_name "${compose_project}" ci-projects)" "${temp_repo}/data/projects"
  seed_volume_from_fixture "$(fixture_volume_name "${compose_project}" ci-references)" "${temp_repo}/data/references"
  seed_volume_from_fixture "$(fixture_volume_name "${compose_project}" ci-scratch)" "${temp_repo}/data/scratch"
  seed_volume_from_fixture "$(fixture_volume_name "${compose_project}" ci-ssh)" "${temp_repo}/data/ssh"
}

write_local_npm_cli_fixture() {
  local package_dir="$1"
  local package_name="$2"
  local bin_name="$3"
  local marker="$4"

  mkdir -p "${package_dir}/bin"
  cat > "${package_dir}/package.json" <<EOF
{
  "name": "${package_name}",
  "version": "1.0.0",
  "bin": {
    "${bin_name}": "bin/${bin_name}"
  }
}
EOF

  cat > "${package_dir}/bin/${bin_name}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '${marker}'
EOF

  chmod 0755 "${package_dir}/bin/${bin_name}"
}
