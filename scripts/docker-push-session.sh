#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: docker-push-session.sh <image> [docker push args...]

Session-only registry login for a single push. Credentials are read from:
  REGISTRY_HOST  (e.g. docker-registry.zaruba-ondrej.dev)
  REGISTRY_USER
  REGISTRY_PASS

Example:
  REGISTRY_HOST=docker-registry.zaruba-ondrej.dev \
  REGISTRY_USER=alice \
  REGISTRY_PASS=secret \
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

if [ -z "${REGISTRY_HOST:-}" ] || [ -z "${REGISTRY_USER:-}" ] || [ -z "${REGISTRY_PASS:-}" ]; then
  echo "Missing REGISTRY_HOST/REGISTRY_USER/REGISTRY_PASS." >&2
  exit 1
fi

image="$1"
shift

tmp_config="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_config}"
}
trap cleanup EXIT

export DOCKER_CONFIG="${tmp_config}"

echo "${REGISTRY_PASS}" | docker login "${REGISTRY_HOST}" -u "${REGISTRY_USER}" --password-stdin >/dev/null
docker push "${image}" "$@"
