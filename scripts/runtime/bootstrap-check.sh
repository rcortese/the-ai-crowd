#!/usr/bin/env bash
set -euo pipefail

issue_count=0

issue() {
  printf 'The AI Crowd bootstrap validation failed: %s\n' "$*" >&2
  issue_count=$((issue_count + 1))
}

check_claude_mcp_registered() {
  local mcp_name="$1"
  local home_dir="$2"

  jq -e --arg mcp_name "${mcp_name}" '.mcpServers[$mcp_name] != null' "${home_dir}/.claude.json" >/dev/null 2>&1 ||
    return 1
}

home_dir="${HOME:-/home/operator}"

if [[ "${THE_AI_CROWD_VALIDATE_CODEX_SANDBOX:-true}" == "true" ]]; then
  if ! unshare --user --mount true >/dev/null 2>&1; then
    issue "Codex sandbox validation enabled but unshare for user and mount namespaces is unavailable"
  fi

  if ! timeout 10 codex sandbox linux -- true >/dev/null 2>&1; then
    issue "Codex sandbox validation enabled but Codex Linux sandbox is unavailable"
  fi
fi

if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  if [[ ! -f "${home_dir}/.claude/rules/delegator/orchestration.md" ]]; then
    issue "claude-delegator rules not installed"
  fi

  if [[ ! -f "${CLAUDE_PLUGIN_ROOT}/server/gemini/index.js" ]]; then
    issue "gemini MCP bridge missing"
  elif ! node --check "${CLAUDE_PLUGIN_ROOT}/server/gemini/index.js" >/dev/null 2>&1; then
    issue "gemini MCP bridge syntax error"
  fi

  if ! check_claude_mcp_registered codex "${home_dir}"; then
    issue "claude MCP is not registered: codex"
  fi

  if ! check_claude_mcp_registered gemini "${home_dir}"; then
    issue "claude MCP is not registered: gemini"
  fi
fi

if (( issue_count > 0 )); then
  exit 1
fi
