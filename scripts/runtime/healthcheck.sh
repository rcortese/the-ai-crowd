#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'The AI Crowd healthcheck failed: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'The AI Crowd healthcheck warning: %s\n' "$*" >&2
}

require_dir() {
  local path="$1"
  [[ -d "${path}" ]] || fail "missing directory: ${path}"
}

require_command() {
  local command_name="$1"
  command -v "${command_name}" >/dev/null 2>&1 || fail "missing command: ${command_name}"
}

check_git_config() {
  local key="$1"
  local expected="$2"
  local actual

  actual="$(git config --global --get "${key}" 2>/dev/null || true)"
  [[ "${actual}" == "${expected}" ]] || fail "git config ${key} expected ${expected}, got ${actual:-<unset>}"
}

check_git_include_path() {
  local include_path="$1"

  git config --global --get-all include.path | grep -Fx "${include_path}" >/dev/null ||
    fail "git config include.path is missing ${include_path}"
}

check_claude_mcp_registered() {
  local mcp_name="$1"

  jq -e --arg mcp_name "${mcp_name}" '.mcpServers[$mcp_name] != null' "${home_dir}/.claude.json" >/dev/null 2>&1 ||
    return 1
}

home_dir="${HOME:-/home/operator}"
gitconfig_path="/workspace/config/gitconfig"
ai_crowd_state_dir="${home_dir}/.local/share/ai-crowd"
claude_mcp_status_path="${ai_crowd_state_dir}/claude-mcp-bootstrap.status"

require_dir "${home_dir}"
require_dir "${home_dir}/.config"
require_dir "${home_dir}/.cache"
require_dir "${home_dir}/.local/share"
require_dir /workspace/projects
require_dir /workspace/references
require_dir /workspace/scratch

require_command git
require_command claude
require_command gemini
require_command codex

check_git_config init.defaultBranch main
check_git_config pull.rebase false
check_git_config core.editor vim

if [[ -f "${gitconfig_path}" ]]; then
  check_git_include_path "${gitconfig_path}"
fi

if [[ "${AI_CROWD_ENABLE_DOCKER:-false}" == "true" ]]; then
  [[ -S /var/run/docker.sock ]] || fail "docker mode enabled but /var/run/docker.sock is not available"
else
  [[ -z "${DOCKER_HOST:-}" ]] || fail "docker mode disabled but DOCKER_HOST is set"
fi

# claude-delegator: rules and MCP registration are best-effort.
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  if [[ ! -f "${home_dir}/.claude/rules/delegator/orchestration.md" ]]; then
    warn "claude-delegator rules not installed"
  fi

  if [[ ! -f "${CLAUDE_PLUGIN_ROOT}/server/gemini/index.js" ]]; then
    warn "gemini MCP bridge missing"
  elif ! node --check "${CLAUDE_PLUGIN_ROOT}/server/gemini/index.js" >/dev/null 2>&1; then
    warn "gemini MCP bridge syntax error"
  fi

  if ! check_claude_mcp_registered codex; then
    warn "claude MCP is not registered: codex"
  fi

  if ! check_claude_mcp_registered gemini; then
    warn "claude MCP is not registered: gemini"
  fi
fi

if [[ -s "${claude_mcp_status_path}" ]]; then
  while IFS= read -r warning_message; do
    [[ -n "${warning_message}" ]] || continue
    warn "${warning_message}"
  done < "${claude_mcp_status_path}"
fi

printf 'The AI Crowd healthcheck passed.\n'
