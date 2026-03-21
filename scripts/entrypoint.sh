#!/usr/bin/env bash
set -euo pipefail

home_dir="${HOME:-/home/operator}"

mkdir -p \
  "${home_dir}/.config" \
  "${home_dir}/.cache" \
  "${home_dir}/.local/share" \
  /workspace/projects \
  /workspace/references \
  /workspace/scratch

if [[ -d "${home_dir}/.ssh" ]]; then
  chmod 700 "${home_dir}/.ssh"
  find "${home_dir}/.ssh" -type f \( -name "*.pub" -o -name "known_hosts" -o -name "config" \) -exec chmod 644 {} +
  find "${home_dir}/.ssh" -type f ! \( -name "*.pub" -o -name "known_hosts" -o -name "config" \) -exec chmod 600 {} +
fi

if [[ -n "${GIT_AUTHOR_NAME:-}" ]]; then
  git config --global user.name "${GIT_AUTHOR_NAME}"
fi

if [[ -n "${GIT_AUTHOR_EMAIL:-}" ]]; then
  git config --global user.email "${GIT_AUTHOR_EMAIL}"
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

cat <<'EOF'
The AI Crowd workbench is ready.
Projects:   /workspace/projects
References: /workspace/references
Scratch:    /workspace/scratch
EOF

exec "$@"
