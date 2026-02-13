#!/usr/bin/env bash
set -euo pipefail

defaults_config_path="${DEFAULTS_CONFIG_PATH:-/defaults/config.toml}"
codex_home="${CODEX_HOME:-/codex-home}"

if [ -f "${defaults_config_path}" ]; then
  mkdir -p "${codex_home}"
  cp "${defaults_config_path}" "${codex_home}/config.toml"
fi

if [ -n "${HOST_UID:-}" ] && [ -n "${HOST_GID:-}" ]; then
  chown -R "${HOST_UID}:${HOST_GID}" "${codex_home}"
fi

dockerd &
while ! docker info >/dev/null 2>&1; do
  sleep 1
done

exec tail -f /dev/null
