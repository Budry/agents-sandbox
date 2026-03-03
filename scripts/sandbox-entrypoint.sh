#!/usr/bin/env bash
set -euo pipefail

defaults_config_path="${DEFAULTS_CONFIG_PATH:-/defaults/config.toml}"
codex_home="${CODEX_HOME:-/codex-home}"
ingress_state_dir="${INGRESS_STATE_DIR:-${codex_home}/ingress}"
ingress_dynamic_dir="${ingress_state_dir}/dynamic"
ingress_static_config="${ingress_state_dir}/traefik.yml"
ingress_routes_config="${ingress_dynamic_dir}/routes.yml"
ingress_traefik_container="${INGRESS_TRAEFIK_CONTAINER:-sandbox-ingress-traefik}"

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

start_ingress() {
  mkdir -p "${ingress_dynamic_dir}"

  cat > "${ingress_static_config}" <<EOF
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"
providers:
  file:
    directory: /etc/traefik/dynamic
    watch: true
log:
  level: INFO
EOF

  if [ ! -f "${ingress_routes_config}" ]; then
    cat > "${ingress_routes_config}" <<'EOF'
http:
  routers: {}
  services: {}
EOF
  fi

  docker rm -f "${ingress_traefik_container}" >/dev/null 2>&1 || true
  docker run -d --restart unless-stopped --name "${ingress_traefik_container}" \
    -p 80:80 \
    -p 443:443 \
    -v "${ingress_static_config}:/etc/traefik/traefik.yml:ro" \
    -v "${ingress_dynamic_dir}:/etc/traefik/dynamic:ro" \
    traefik:v3.3 >/dev/null
}

start_ingress
/usr/local/bin/ingress-watcher.sh &

exec tail -f /dev/null
