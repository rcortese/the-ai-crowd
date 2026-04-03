#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ci/lib.sh
source "${script_dir}/lib.sh"

service="the-ai-crowd"
repo_root="$(pwd)"
temp_root="$(create_temp_repo_root "${repo_root}")"
temp_repo="${temp_root}/repo"
compose_project="the-ai-crowd-ci-${RANDOM}${RANDOM}"
container_name="${compose_project}-the-ai-crowd"
override_file="${temp_repo}/docker-compose.ci.override.yml"

set_workbench_ids
set_ci_runtime_env
prepare_temp_repo_fixture "${temp_repo}"
write_compose_override "${override_file}" "${container_name}" "${compose_project}"

compose_files=(
  -f compose.yaml
  -f compose.build.yaml
  -f docker-compose.ci.override.yml
)

export COMPOSE_PROJECT_NAME="${compose_project}"

cleanup() {
  docker compose "${compose_files[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  remove_test_volumes "${compose_project}"
  chmod -R u+rwx "${temp_root}" >/dev/null 2>&1 || true
  rm -rf "${temp_root}"
}

trap cleanup EXIT

cd "${temp_repo}"

seed_test_volumes "${compose_project}" "${temp_repo}"
docker compose "${compose_files[@]}" up -d --no-build "${service}"
wait_for_service_ready

codex_sandbox_check_cmd="$(container_codex_sandbox_check_command)"
output_file="${temp_root}/codex-sandbox-check.log"

if docker compose "${compose_files[@]}" exec -T \
  -e THE_AI_CROWD_VALIDATE_CODEX_SANDBOX=true \
  "${service}" bash -lc "${codex_sandbox_check_cmd}" >"${output_file}" 2>&1; then
  :
elif [[ "${CI_ALLOW_UNSUPPORTED_CODEX_SANDBOX:-false}" == "true" ]] && \
  grep -Fq "Codex sandbox validation enabled but unshare for user and mount namespaces is unavailable" "${output_file}"; then
  printf '%s\n' "Skipping Codex sandbox capability check: runner host does not provide user/mount namespace unshare support."
else
  cat "${output_file}" >&2
  exit 1
fi

cd "${repo_root}"
