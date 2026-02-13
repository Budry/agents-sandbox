#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="docker-registry.zaruba-ondrej.dev/codex-sandbox"
NETWORK_NAME="sandnet"

usage() {
  cat <<'EOF'
Usage: ./agent-sandbox.sh [--help]
       ./agent-sandbox.sh start <config.toml> <ssh_key>
       ./agent-sandbox.sh stop
       ./agent-sandbox.sh exec <cmd>...

Starts or stops a DinD sandbox for the current directory. The exec form
executes <cmd> inside the sandbox (sandbox must already be running).

Examples:
  ./agent-sandbox.sh start ~/.codex/config.toml ~/.ssh/id_ed25519
  ./agent-sandbox.sh exec codex --model gpt-4.1
  ./agent-sandbox.sh exec bash
  ./agent-sandbox.sh stop
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

COMMAND="${1:-}"
if [ "$#" -gt 0 ]; then
  shift
fi
CMD_ARGS=("$@")

PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "${PROJECT_DIR}")"
SANDBOX_NAME="sbx-${PROJECT_NAME}"
VOL_DOCKER="${SANDBOX_NAME}-docker"
VOL_CODEX="codex-shared"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

# Build image if missing.
if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  docker pull "${IMAGE_NAME}"
fi

# Create network if missing.
if ! docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
  docker network create "${NETWORK_NAME}"
fi

start_sandbox() {
  local config_path="$1"
  local ssh_key_path="$2"
  local ssh_mounts=()
  local ssh_env=()

  if [ ! -f "${ssh_key_path}" ]; then
    echo "SSH key not found: ${ssh_key_path}" >&2
    exit 1
  fi

  ssh_mounts+=(-v "${ssh_key_path}:/run/secrets/ro_key:ro")
  ssh_env+=(-e "GIT_SSH_COMMAND=ssh -i /run/secrets/ro_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new")
  docker run -d --rm --name "${SANDBOX_NAME}" \
    --privileged \
    --network "${NETWORK_NAME}" \
    -v "${VOL_DOCKER}:/var/lib/docker" \
    -v "${VOL_CODEX}:/root/.codex" \
    -v "${PROJECT_DIR}:/work" \
    -w /work \
    "${ssh_env[@]}" \
    "${ssh_mounts[@]}" \
    -v "${config_path}:/defaults/config.toml:ro" \
    "${IMAGE_NAME}" sh -c "if [ -f /defaults/config.toml ]; then \
      mkdir -p /root/.codex && cp /defaults/config.toml /root/.codex/config.toml; \
    fi; \
    dockerd & \
    while ! docker info >/dev/null 2>&1; do sleep 1; done; \
    tail -f /dev/null" >/dev/null
}

is_running() {
  docker ps --format '{{.Names}}' | grep -qx "${SANDBOX_NAME}"
}

case "${COMMAND}" in
  "")
    usage
    exit 1
    ;;
  start)
    if [ "${#CMD_ARGS[@]}" -ne 2 ]; then
      echo "Missing required config.toml path or ssh key for start."
      usage
      exit 1
    fi
    if [ ! -f "${CMD_ARGS[0]}" ]; then
      echo "Config file not found: ${CMD_ARGS[0]}"
      exit 1
    fi
    if [ ! -f "${CMD_ARGS[1]}" ]; then
      echo "SSH key not found: ${CMD_ARGS[1]}"
      exit 1
    fi
    if is_running; then
      echo "Sandbox already running: ${SANDBOX_NAME}"
      exit 1
    fi
    start_sandbox "${CMD_ARGS[0]}" "${CMD_ARGS[1]}"
    echo "Sandbox started: ${SANDBOX_NAME}"
    echo "Project mounted from: ${PROJECT_DIR}"
    ;;
  stop)
    if ! is_running; then
      echo "Sandbox not running: ${SANDBOX_NAME}"
      exit 1
    fi
    docker rm -f "${SANDBOX_NAME}" >/dev/null
    echo "Sandbox stopped: ${SANDBOX_NAME}"
    ;;
  exec)
    if [ "${#CMD_ARGS[@]}" -eq 0 ]; then
      echo "Missing command for exec."
      usage
      exit 1
    fi
    if ! is_running; then
      echo "Sandbox not running: ${SANDBOX_NAME}"
      exit 1
    fi
    exec docker exec -it -u "${HOST_UID}:${HOST_GID}" -w /work "${SANDBOX_NAME}" "${CMD_ARGS[@]}"
    ;;
  *)
    echo "Unknown command: ${COMMAND}"
    usage
    exit 1
    ;;
esac
