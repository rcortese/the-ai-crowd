#!/usr/bin/env bash
set -euo pipefail

home_dir="${HOME:-/home/operator}"
workbench_uid="$(id -u)"
workbench_gid="$(id -g)"
config_dir="/workspace/config"
gitconfig_path="${config_dir}/gitconfig"

ensure_directory() {
  local dir_path="$1"

  if mkdir -p "${dir_path}" 2>/dev/null; then
    return 0
  fi

  cat >&2 <<EOF
The AI Crowd workbench could not write to '${dir_path}'.
The container is running as UID:GID ${workbench_uid}:${workbench_gid}, but the bind-mounted host path does not allow writes.
Fix the owner/permissions of the mounted directory or align WORKBENCH_UID and WORKBENCH_GID in .env with the host path owner, then restart the container.
EOF
  exit 70
}

ensure_directory "${home_dir}/.config"
ensure_directory "${home_dir}/.cache"
ensure_directory "${home_dir}/.local/share"
ensure_directory /workspace/projects
ensure_directory /workspace/references
ensure_directory /workspace/scratch

claude_mcp_list_has() {
  local mcp_name="$1"

  claude mcp list 2>/dev/null | awk -v target="${mcp_name}" '$1 == target { found = 1 } END { exit(found ? 0 : 1) }'
}

fail_claude_mcp_bootstrap() {
  local mcp_name="$1"

  cat >&2 <<EOF
The AI Crowd could not register the '${mcp_name}' MCP server.
This prevents delegated Claude workflows from working correctly.
Check the Claude CLI installation, the claude-delegator files in '${CLAUDE_PLUGIN_ROOT}', and the current user config under '${home_dir}/.claude'.
EOF
  exit 70
}

register_claude_mcp() {
  local mcp_name="$1"
  shift
  local -a mcp_command=("$@")

  if claude_mcp_list_has "${mcp_name}"; then
    return 0
  fi

  if ! claude mcp add --transport stdio --scope user "${mcp_name}" -- "${mcp_command[@]}" >/dev/null 2>&1; then
    fail_claude_mcp_bootstrap "${mcp_name}"
  fi

  if ! claude_mcp_list_has "${mcp_name}"; then
    fail_claude_mcp_bootstrap "${mcp_name}"
  fi
}

if [[ -d "${home_dir}/.ssh" ]]; then
  if ! chmod 700 "${home_dir}/.ssh" 2>/dev/null; then
    cat >&2 <<EOF
The AI Crowd workbench could not update permissions for '${home_dir}/.ssh'.
The mounted SSH directory must be writable by UID:GID ${workbench_uid}:${workbench_gid}.
EOF
    exit 70
  fi
  find "${home_dir}/.ssh" -type f \( -name "*.pub" -o -name "known_hosts" -o -name "config" \) -exec chmod 644 {} +
  find "${home_dir}/.ssh" -type f ! \( -name "*.pub" -o -name "known_hosts" -o -name "config" \) -exec chmod 600 {} +
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

# claude-delegator: register MCP servers (idempotent, fail-fast)
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  if ! command -v claude >/dev/null 2>&1; then
    cat >&2 <<EOF
The AI Crowd cannot register delegated MCP servers because the Claude CLI is missing.
This container image is expected to provide the claude command.
EOF
    exit 70
  fi

  register_claude_mcp codex codex -m gpt-5.3-codex mcp-server
  register_claude_mcp gemini node "${CLAUDE_PLUGIN_ROOT}/server/gemini/index.js"
fi

cat <<'EOF'
The AI Crowd workbench is ready.
Projects:   /workspace/projects
References: /workspace/references
Scratch:    /workspace/scratch
EOF

exec "$@"
