#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: docker-push-session.sh <image> [docker push args...]

Session-only registry login for a single push.
Registry host is resolved from REGISTRY_HOST or image reference.
Login and password are prompted interactively.

Example:
  ./scripts/docker-push-session.sh docker-registry.zaruba-ondrej.dev/my/image:tag
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 1 ]; then
  echo "Missing image reference." >&2
  usage
  exit 1
fi

image="$1"
shift

registry_host="${REGISTRY_HOST:-}"
if [ -z "${registry_host}" ]; then
  first_segment="${image%%/*}"
  if [ "${first_segment}" != "${image}" ] && { [[ "${first_segment}" == *.* ]] || [[ "${first_segment}" == *:* ]] || [ "${first_segment}" = "localhost" ]; }; then
    registry_host="${first_segment}"
  else
    registry_host="docker.io"
  fi
fi

read -r -p "Registry login for ${registry_host}: " registry_user
if [ -z "${registry_user}" ]; then
  echo "Missing registry login." >&2
  exit 1
fi

read -r -s -p "Registry password for ${registry_user}: " registry_pass
echo
if [ -z "${registry_pass}" ]; then
  echo "Missing registry password." >&2
  exit 1
fi

tmp_config="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_config}"
}
trap cleanup EXIT

export DOCKER_CONFIG="${tmp_config}"

echo "${registry_pass}" | docker login "${registry_host}" -u "${registry_user}" --password-stdin >/dev/null
docker push "${image}" "$@"
