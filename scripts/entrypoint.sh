#!/usr/bin/env bash
set -euo pipefail

home_dir="${HOME:-/home/operator}"
workbench_uid="$(id -u)"
workbench_gid="$(id -g)"

author_name="${GIT_AUTHOR_NAME:-}"
author_email="${GIT_AUTHOR_EMAIL:-}"
committer_name="${GIT_COMMITTER_NAME:-}"
committer_email="${GIT_COMMITTER_EMAIL:-}"

if [[ -n "${author_name}" && -z "${committer_name}" ]]; then
  export GIT_COMMITTER_NAME="${author_name}"
fi

if [[ -n "${author_email}" && -z "${committer_email}" ]]; then
  export GIT_COMMITTER_EMAIL="${author_email}"
fi

if [[ -z "${author_name}" && -n "${committer_name}" ]]; then
  export GIT_AUTHOR_NAME="${committer_name}"
fi

if [[ -z "${author_email}" && -n "${committer_email}" ]]; then
  export GIT_AUTHOR_EMAIL="${committer_email}"
fi

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
