#!/usr/bin/env bash
set -euo pipefail

home_dir="${HOME:-/home/operator}"
runtime_uid="$(id -u)"
runtime_gid="$(id -g)"
config_dir="/workspace/config"
gitconfig_path="${config_dir}/gitconfig"
ssh_dir="${home_dir}/.ssh"
claude_config_path="${home_dir}/.claude.json"
claude_config_backup_path="${home_dir}/.claude.json.backup"
ai_crowd_state_dir="${home_dir}/.local/share/ai-crowd"
claude_mcp_status_path="${ai_crowd_state_dir}/claude-mcp-bootstrap.status"

ensure_directory() {
  local dir_path="$1"

  if mkdir -p "${dir_path}" 2>/dev/null; then
    return 0
  fi

  cat >&2 <<EOF
The AI Crowd container could not write to '${dir_path}'.
The container is running as UID:GID ${runtime_uid}:${runtime_gid}, but the bind-mounted host path does not allow writes.
Fix the owner/permissions of the mounted directory or align WORKBENCH_UID and WORKBENCH_GID in .env with the host path owner, then restart the container.
EOF
  exit 70
}

ensure_directory "${home_dir}/.config"
ensure_directory "${home_dir}/.cache"
ensure_directory "${home_dir}/.local/share"
ensure_directory "${ai_crowd_state_dir}"
ensure_directory "${ssh_dir}"
ensure_directory /workspace/projects
ensure_directory /workspace/references
ensure_directory /workspace/scratch

claude_config_has_mcp() {
  local mcp_name="$1"

  jq -e --arg mcp_name "${mcp_name}" '.mcpServers[$mcp_name] != null' "${claude_config_path}" >/dev/null 2>&1
}

bootstrap_claude_config() {
  mkdir -p "${home_dir}"

  if [[ -s "${claude_config_path}" ]] && jq -e . "${claude_config_path}" >/dev/null 2>&1; then
    return 0
  fi

  if [[ -s "${claude_config_backup_path}" ]] && jq -e . "${claude_config_backup_path}" >/dev/null 2>&1; then
    cp "${claude_config_backup_path}" "${claude_config_path}"
    return 0
  fi

  rm -f "${claude_config_path}"
  if ! timeout 15 claude --version >/dev/null 2>&1; then
    return 1
  fi

  [[ -s "${claude_config_path}" ]] && jq -e . "${claude_config_path}" >/dev/null 2>&1
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

register_claude_mcp() {
  local mcp_name="$1"
  local command_name="$2"
  shift 2
  local -a command_args=("$@")

  if claude_config_has_mcp "${mcp_name}"; then
    return 0
  fi

  if ! bootstrap_claude_config; then
    warn_claude_mcp_bootstrap "The AI Crowd could not bootstrap Claude config for MCP '${mcp_name}'. Delegated Claude workflows are unavailable, but shell access and direct CLI usage remain available."
    return 1
  fi

  write_claude_mcp_config "${mcp_name}" "${command_name}" "${command_args[@]}"

  if ! claude_config_has_mcp "${mcp_name}"; then
    warn_claude_mcp_bootstrap "The AI Crowd could not register MCP '${mcp_name}' in '${claude_config_path}'. Delegated Claude workflows are unavailable, but shell access and direct CLI usage remain available."
    return 1
  fi

  return 0
}

if [[ -d "${ssh_dir}" ]]; then
  if ! chmod 700 "${ssh_dir}" 2>/dev/null; then
    cat >&2 <<EOF
The AI Crowd container could not update permissions for '${ssh_dir}'.
The mounted SSH directory must be writable by UID:GID ${runtime_uid}:${runtime_gid}.
EOF
    exit 70
  fi
  find "${ssh_dir}" -type f \( -name "*.pub" -o -name "known_hosts" -o -name "config" \) -exec chmod 644 {} +
  find "${ssh_dir}" -type f ! \( -name "*.pub" -o -name "known_hosts" -o -name "config" \) -exec chmod 600 {} +
fi

if [[ -f "${gitconfig_path}" ]] && ! git config --global --get-all include.path | grep -Fx "${gitconfig_path}" >/dev/null; then
  git config --global --add include.path "${gitconfig_path}"
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

if [[ "${AI_CROWD_ENABLE_DOCKER:-false}" != "true" ]]; then
  export DOCKER_HOST=""
fi

# claude-delegator: copy orchestration rules on first boot
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]] && [[ -d "${CLAUDE_PLUGIN_ROOT}/rules" ]]; then
  delegator_rules_dst="${home_dir}/.claude/rules/delegator"
  if [[ ! -d "${delegator_rules_dst}" ]]; then
    mkdir -p "${delegator_rules_dst}"
    cp "${CLAUDE_PLUGIN_ROOT}/rules/"*.md "${delegator_rules_dst}/"
  fi
fi

# claude-delegator: register MCP servers (idempotent, non-fatal)
reset_claude_mcp_status
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  if ! command -v claude >/dev/null 2>&1; then
    warn_claude_mcp_bootstrap "The AI Crowd could not register delegated MCP servers because the Claude CLI is missing. Delegated Claude workflows and Claude CLI usage are unavailable, but shell access and direct Gemini/Codex CLI usage remain available."
  else
    register_claude_mcp codex codex -m gpt-5.3-codex mcp-server || true
    register_claude_mcp gemini node "${CLAUDE_PLUGIN_ROOT}/server/gemini/index.js" || true
  fi
fi

cat <<'EOF'
The AI Crowd container is ready.
Projects:   /workspace/projects
References: /workspace/references
Scratch:    /workspace/scratch
EOF

exec "$@"
