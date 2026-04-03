#!/usr/bin/env bash
set -euo pipefail

if ! unshare --user --mount true >/dev/null 2>&1; then
  printf '%s\n' "Codex sandbox validation enabled but unshare for user and mount namespaces is unavailable" >&2
  exit 1
fi

if ! timeout 10 codex sandbox linux -- true >/dev/null 2>&1; then
  printf '%s\n' "Codex sandbox validation enabled but Codex Linux sandbox is unavailable" >&2
  exit 1
fi
