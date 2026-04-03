#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"

dockerfile="${repo_root}/Dockerfile"
compose_build="${repo_root}/compose.build.yaml"
env_example="${repo_root}/.env.example"
publish_workflow="${repo_root}/.github/workflows/publish-dockerhub.yml"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

dockerfile_arg_default() {
  local arg_name="$1"

  awk -v arg_name="${arg_name}" '
    index($0, "ARG " arg_name) == 1 {
      line = $0
      sub("^ARG " arg_name, "", line)
      sub("^=", "", line)
      print line
      found = 1
      exit
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "${dockerfile}" || fail "Dockerfile ARG ${arg_name} not found"
}

require_exact_line() {
  local file_path="$1"
  local expected_line="$2"
  local description="$3"

  grep -Fqx "${expected_line}" "${file_path}" || fail "${description}: expected line '${expected_line}' in ${file_path}"
}

workflow_line_number() {
  local pattern="$1"
  local file_path="$2"
  local line_number

  line_number="$(grep -nF "${pattern}" "${file_path}" | head -1 | cut -d: -f1)"
  [[ -n "${line_number}" ]] || fail "Workflow pattern not found: ${pattern}"
  printf '%s\n' "${line_number}"
}

node_major="$(dockerfile_arg_default NODE_MAJOR)"
node_version="$(dockerfile_arg_default NODE_VERSION)"
username="$(dockerfile_arg_default USERNAME)"
user_uid="$(dockerfile_arg_default USER_UID)"
user_gid="$(dockerfile_arg_default USER_GID)"
claude_code_version="$(dockerfile_arg_default CLAUDE_CODE_VERSION)"
gemini_cli_version="$(dockerfile_arg_default GEMINI_CLI_VERSION)"
codex_cli_version="$(dockerfile_arg_default CODEX_CLI_VERSION)"
claude_delegator_commit="$(dockerfile_arg_default CLAUDE_DELEGATOR_COMMIT)"
claude_delegator_sha256="$(dockerfile_arg_default CLAUDE_DELEGATOR_SHA256)"
docker_ce_cli_version="$(dockerfile_arg_default DOCKER_CE_CLI_VERSION)"

require_exact_line "${compose_build}" "        NODE_MAJOR: \${NODE_MAJOR:-${node_major}}" "compose.build.yaml NODE_MAJOR fallback drift"
require_exact_line "${compose_build}" "        NODE_VERSION: \${NODE_VERSION:-${node_version}}" "compose.build.yaml NODE_VERSION fallback drift"
require_exact_line "${compose_build}" "        USERNAME: \${WORKBENCH_USER:-${username}}" "compose.build.yaml USERNAME fallback drift"
require_exact_line "${compose_build}" "        USER_UID: \${WORKBENCH_UID:-${user_uid}}" "compose.build.yaml USER_UID fallback drift"
require_exact_line "${compose_build}" "        USER_GID: \${WORKBENCH_GID:-${user_gid}}" "compose.build.yaml USER_GID fallback drift"
require_exact_line "${compose_build}" "        CLAUDE_CODE_VERSION: \${CLAUDE_CODE_VERSION:-${claude_code_version}}" "compose.build.yaml CLAUDE_CODE_VERSION fallback drift"
require_exact_line "${compose_build}" "        GEMINI_CLI_VERSION: \${GEMINI_CLI_VERSION:-${gemini_cli_version}}" "compose.build.yaml GEMINI_CLI_VERSION fallback drift"
require_exact_line "${compose_build}" "        CODEX_CLI_VERSION: \${CODEX_CLI_VERSION:-${codex_cli_version}}" "compose.build.yaml CODEX_CLI_VERSION fallback drift"
require_exact_line "${compose_build}" "        CLAUDE_DELEGATOR_COMMIT: \${CLAUDE_DELEGATOR_COMMIT:-${claude_delegator_commit}}" "compose.build.yaml CLAUDE_DELEGATOR_COMMIT fallback drift"
require_exact_line "${compose_build}" "        CLAUDE_DELEGATOR_SHA256: \${CLAUDE_DELEGATOR_SHA256:-${claude_delegator_sha256}}" "compose.build.yaml CLAUDE_DELEGATOR_SHA256 fallback drift"
require_exact_line "${compose_build}" "        DOCKER_CE_CLI_VERSION: \${DOCKER_CE_CLI_VERSION:-${docker_ce_cli_version}}" "compose.build.yaml DOCKER_CE_CLI_VERSION fallback drift"

require_exact_line "${env_example}" "WORKBENCH_USER=${username}" ".env.example WORKBENCH_USER drift"
require_exact_line "${env_example}" "WORKBENCH_UID=${user_uid}" ".env.example WORKBENCH_UID drift"
require_exact_line "${env_example}" "WORKBENCH_GID=${user_gid}" ".env.example WORKBENCH_GID drift"
require_exact_line "${env_example}" "# NODE_MAJOR=${node_major}" ".env.example NODE_MAJOR override drift"
require_exact_line "${env_example}" "# NODE_VERSION=${node_version}" ".env.example NODE_VERSION override drift"
require_exact_line "${env_example}" "# CLAUDE_CODE_VERSION=${claude_code_version}" ".env.example CLAUDE_CODE_VERSION override drift"
require_exact_line "${env_example}" "# GEMINI_CLI_VERSION=${gemini_cli_version}" ".env.example GEMINI_CLI_VERSION override drift"
require_exact_line "${env_example}" "# CODEX_CLI_VERSION=${codex_cli_version}" ".env.example CODEX_CLI_VERSION override drift"
require_exact_line "${env_example}" "# CLAUDE_DELEGATOR_COMMIT=${claude_delegator_commit}" ".env.example CLAUDE_DELEGATOR_COMMIT override drift"
require_exact_line "${env_example}" "# CLAUDE_DELEGATOR_SHA256=${claude_delegator_sha256}" ".env.example CLAUDE_DELEGATOR_SHA256 override drift"
require_exact_line "${env_example}" "# DOCKER_CE_CLI_VERSION=${docker_ce_cli_version}" ".env.example DOCKER_CE_CLI_VERSION override drift"

require_exact_line "${publish_workflow}" "        run: bash scripts/ci/check-config-consistency.sh" "publish-dockerhub.yml must run the consistency check"

publish_check_line="$(workflow_line_number "        run: bash scripts/ci/check-config-consistency.sh" "${publish_workflow}")"
publish_build_line="$(workflow_line_number "        uses: docker/build-push-action@v7" "${publish_workflow}")"

(( publish_check_line < publish_build_line )) || fail "publish-dockerhub.yml must run config consistency validation before build-push-action"

if grep -Fq "Extract build args from Dockerfile" "${publish_workflow}"; then
  fail "publish-dockerhub.yml still duplicates Dockerfile ARG extraction; rely on Dockerfile defaults instead"
fi

printf 'Configuration consistency check passed.\n'
