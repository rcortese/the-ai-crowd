#!/usr/bin/env bash
set -euo pipefail

home_dir="${HOME:-/home/operator}"
runtime_uid="$(id -u)"
runtime_gid="$(id -g)"
ssh_dir="${home_dir}/.ssh"
claude_config_path="${home_dir}/.claude.json"
claude_config_backup_path="${home_dir}/.claude.json.backup"
the_ai_crowd_state_dir="${home_dir}/.local/share/the-ai-crowd"
claude_mcp_status_path="${the_ai_crowd_state_dir}/claude-mcp-bootstrap.status"
bootstrap_validation_status_path="${the_ai_crowd_state_dir}/bootstrap-validation.status"
bootstrap_validation_complete_path="${the_ai_crowd_state_dir}/bootstrap-validation.complete"
the_ai_crowd_npm_global_prefix="${THE_AI_CROWD_NPM_GLOBAL_PREFIX:-${home_dir}/.local/share/the-ai-crowd/npm-global}"

ensure_directory() {
  local dir_path="$1"

  if mkdir -p "${dir_path}" 2>/dev/null; then
    return 0
  fi

  cat >&2 <<EOF2
The AI Crowd container could not write to '${dir_path}'.
The container is running as UID:GID ${runtime_uid}:${runtime_gid}, but the bind-mounted host path does not allow writes.
Fix the owner/permissions of the mounted directory or align WORKBENCH_UID and WORKBENCH_GID in .env with the host path owner, then restart the container.
EOF2
  exit 70
}

ensure_directory "${home_dir}/.config"
ensure_directory "${home_dir}/.cache"
ensure_directory "${home_dir}/.local/share"
ensure_directory "${the_ai_crowd_state_dir}"
ensure_directory "${the_ai_crowd_npm_global_prefix}"
ensure_directory "${ssh_dir}"
ensure_directory /workspace/projects
ensure_directory /workspace/references
ensure_directory /workspace/scratch

claude_config_has_mcp() {
  local mcp_name="$1"

  jq -e --arg mcp_name "${mcp_name}" '.mcpServers[$mcp_name] != null' "${claude_config_path}" >/dev/null 2>&1
}

write_claude_config_json() {
  local jq_filter="$1"
  local source_path="${2:-}"
  local tmp_config

  tmp_config="$(mktemp)"

  if [[ -n "${source_path}" ]]; then
    jq "${jq_filter}" "${source_path}" > "${tmp_config}"
  else
    jq -n "${jq_filter}" > "${tmp_config}"
  fi

  mv "${tmp_config}" "${claude_config_path}"
}

normalize_claude_config_filter='
  if type == "object" then . else {} end |
  .mcpServers = (
    if (.mcpServers | type) == "object" then
      .mcpServers
    else
      {}
    end
  )'

bootstrap_claude_config() {
  mkdir -p "${home_dir}"

  if [[ -s "${claude_config_path}" ]] && jq -e . "${claude_config_path}" >/dev/null 2>&1; then
    write_claude_config_json "${normalize_claude_config_filter}" "${claude_config_path}"
    return 0
  fi

  if [[ -s "${claude_config_backup_path}" ]] && jq -e . "${claude_config_backup_path}" >/dev/null 2>&1; then
    write_claude_config_json "${normalize_claude_config_filter}" "${claude_config_backup_path}"
    return 0
  fi

  write_claude_config_json '{mcpServers: {}}'
}

write_claude_mcp_config() {
  local mcp_name="$1"
  local command_name="$2"
  shift 2
  local tmp_config

  tmp_config="$(mktemp)"
  jq \
    --arg mcp_name "${mcp_name}" \
    --arg command_name "${command_name}" \
    --argjson args "$(printf '%s\n' "$@" | jq -R . | jq -s .)" \
    '.mcpServers = (.mcpServers // {}) |
     .mcpServers[$mcp_name] = {
       type: "stdio",
       command: $command_name,
       args: $args,
       env: {}
     }' \
    "${claude_config_path}" > "${tmp_config}"
  mv "${tmp_config}" "${claude_config_path}"
}

reset_claude_mcp_status() {
  : > "${claude_mcp_status_path}"
}

record_claude_mcp_status() {
  printf '%s\n' "$1" >> "${claude_mcp_status_path}"
}

warn_claude_mcp_bootstrap() {
  local issue="$1"

  record_claude_mcp_status "${issue}"
  printf 'WARNING: %s\n' "${issue}" >&2
}

reset_bootstrap_validation_status() {
  : > "${bootstrap_validation_status_path}"
  rm -f "${bootstrap_validation_complete_path}"
}

mark_bootstrap_validation_complete() {
  : > "${bootstrap_validation_complete_path}"
}

register_claude_mcp() {
  local mcp_name="$1"
  local command_name="$2"
  shift 2
  local -a command_args=("$@")

  if ! bootstrap_claude_config; then
    warn_claude_mcp_bootstrap "The AI Crowd could not bootstrap Claude config for MCP '${mcp_name}'. Shell access and direct CLI usage remain available, but the container will stay unhealthy until delegated MCP registration is repaired."
    return 1
  fi

  write_claude_mcp_config "${mcp_name}" "${command_name}" "${command_args[@]}"

  if ! claude_config_has_mcp "${mcp_name}"; then
    warn_claude_mcp_bootstrap "The AI Crowd could not register MCP '${mcp_name}' in '${claude_config_path}'. Shell access and direct CLI usage remain available, but the container will stay unhealthy until delegated MCP registration is repaired."
    return 1
  fi

  return 0
}

if [[ -d "${ssh_dir}" ]]; then
  if ! chmod 700 "${ssh_dir}" 2>/dev/null; then
    cat >&2 <<EOF2
The AI Crowd container could not update permissions for '${ssh_dir}'.
The mounted SSH directory must be writable by UID:GID ${runtime_uid}:${runtime_gid}.
EOF2
    exit 70
  fi
  find "${ssh_dir}" -type f \( -name "*.pub" -o -name "known_hosts" -o -name "config" \) -exec chmod 644 {} +
  find "${ssh_dir}" -type f ! \( -name "*.pub" -o -name "known_hosts" -o -name "config" \) -exec chmod 600 {} +
fi

if ! git config --global --get init.defaultBranch >/dev/null; then
  git config --global init.defaultBranch main
fi

if ! git config --global --get pull.rebase >/dev/null; then
  git config --global pull.rebase false
fi

if ! git config --global --get core.editor >/dev/null; then
  git config --global core.editor vim
fi

if [[ "${DOCKER_ENABLE:-false}" != "true" ]]; then
  export DOCKER_HOST=""
else
  if ! command -v docker >/dev/null 2>&1; then
    cat >&2 <<'EOF2'
The AI Crowd Docker-aware mode is enabled, but the docker CLI is missing.
Rebuild the image with Docker tooling support or start without compose.docker.yaml.
EOF2
    exit 70
  fi

  if ! docker compose version >/dev/null 2>&1; then
    cat >&2 <<'EOF2'
The AI Crowd Docker-aware mode is enabled, but docker compose is unavailable inside the container.
Install the docker-compose-plugin in the image or start without compose.docker.yaml.
EOF2
    exit 70
  fi

  if [[ ! -S /var/run/docker.sock ]]; then
    cat >&2 <<'EOF2'
The AI Crowd Docker-aware mode is enabled, but /var/run/docker.sock is not mounted.
Start the container with compose.docker.yaml or disable DOCKER_ENABLE.
EOF2
    exit 70
  fi

  socket_gid="$(stat -c '%g' /var/run/docker.sock)"
  if ! id -G | tr ' ' '\n' | grep -qx "${socket_gid}"; then
    cat >&2 <<EOF2
The AI Crowd Docker-aware mode is enabled, but the current process cannot access /var/run/docker.sock.
Expected supplemental group GID: ${socket_gid}
Current groups: $(id -G)
Set DOCKER_GID=${socket_gid} when starting with compose.docker.yaml, then recreate the container.
EOF2
    exit 70
  fi
fi

if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]] && [[ -d "${CLAUDE_PLUGIN_ROOT}/rules" ]]; then
  delegator_rules_dst="${home_dir}/.claude/rules/delegator"
  mkdir -p "${delegator_rules_dst}"
  find "${delegator_rules_dst}" -maxdepth 1 -name "*.md" -type f -delete
  shopt -s nullglob
  delegator_md_files=( "${CLAUDE_PLUGIN_ROOT}/rules/"*.md )
  if (( ${#delegator_md_files[@]} > 0 )); then
    cp "${delegator_md_files[@]}" "${delegator_rules_dst}/"
  fi
  shopt -u nullglob
fi

reset_claude_mcp_status
reset_bootstrap_validation_status
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  if ! command -v claude >/dev/null 2>&1; then
    warn_claude_mcp_bootstrap "The AI Crowd could not register delegated MCP servers because the Claude CLI is missing. Shell access and direct Gemini/Codex CLI usage remain available, but the container will stay unhealthy until Claude MCP registration can succeed."
  else
    codex_mcp_model="${CODEX_MCP_MODEL:-gpt-5.3-codex}"
    register_claude_mcp codex codex -m "${codex_mcp_model}" mcp-server || true
    register_claude_mcp gemini node "${CLAUDE_PLUGIN_ROOT}/server/gemini/index.js" || true
  fi
fi

if ! /usr/local/bin/the-ai-crowd-bootstrap-check 2>"${bootstrap_validation_status_path}"; then
  while IFS= read -r bootstrap_issue; do
    [[ -n "${bootstrap_issue}" ]] || continue
    printf 'WARNING: %s\n' "${bootstrap_issue}" >&2
  done < "${bootstrap_validation_status_path}"
fi
mark_bootstrap_validation_complete

cat <<'EOF2'
The AI Crowd container is ready.
Projects:   /workspace/projects
References: /workspace/references
Scratch:    /workspace/scratch
EOF2

exec "$@"
