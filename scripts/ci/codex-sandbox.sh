#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ci/lib.sh
source "${script_dir}/lib.sh"

service="the-ai-crowd"
repo_root="$(pwd)"
setup_ci_compose_fixture "${repo_root}" "the-ai-crowd-ci"
set_compose_files compose.yaml compose.build.yaml docker-compose.ci.override.yml

cleanup() {
  cleanup_ci_compose_fixture "${compose_project}" "${temp_root}" "${compose_files[@]}"
}

trap cleanup EXIT

cd "${temp_repo}"

seed_test_volumes "${compose_project}" "${temp_repo}"
docker compose "${compose_files[@]}" up -d --no-build "${service}"
wait_for_service_ready "${service}" "${compose_files[@]}"

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
