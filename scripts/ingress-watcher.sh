#!/usr/bin/env bash
set -euo pipefail

base_domain="${INGRESS_BASE_DOMAIN:-agents-sandbox.zaruba-ondrej.dev}"
codex_home="${CODEX_HOME:-/codex-home}"
state_dir="${INGRESS_STATE_DIR:-${codex_home}/ingress}"
dynamic_dir="${state_dir}/dynamic"
routes_file="${dynamic_dir}/routes.yml"
map_file="${state_dir}/public-urls.json"
traefik_container="${INGRESS_TRAEFIK_CONTAINER:-sandbox-ingress-traefik}"
poll_seconds=10

mkdir -p "${dynamic_dir}"
if [ ! -f "${map_file}" ]; then
  echo '{}' > "${map_file}"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ingress-watcher: jq is required" >&2
  exit 1
fi

random_slug() {
  head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c 1-10
}

ensure_traefik_network() {
  local network_name="$1"

  if ! docker inspect "${traefik_container}" >/dev/null 2>&1; then
    return
  fi

  if docker inspect "${traefik_container}" | jq -e --arg net "${network_name}" '.[0].NetworkSettings.Networks[$net]' >/dev/null; then
    return
  fi

  docker network connect "${network_name}" "${traefik_container}" >/dev/null 2>&1 || true
}

is_disabled() {
  local label_value="$1"
  case "${label_value}" in
    false|False|FALSE|0|no|No|NO)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

build_routes() {
  local map_json="$1"
  local tmp_file
  tmp_file="$(mktemp)"

  {
    echo "http:"

    if [ "$(jq 'length' <<< "${map_json}")" -eq 0 ]; then
      echo "  routers: {}"
      echo "  services: {}"
    else
      echo "  routers:"
      while IFS= read -r item; do
        slug="$(jq -r '.value.slug' <<< "${item}")"
        host="$(jq -r '.value.host' <<< "${item}")"
        echo "    router-${slug}:"
        echo "      entryPoints:"
        echo "        - web"
        echo "      rule: \"Host(\`${host}\`)\""
        echo "      service: \"service-${slug}\""
      done < <(jq -c 'to_entries[]' <<< "${map_json}")

      echo "  services:"
      while IFS= read -r item; do
        slug="$(jq -r '.value.slug' <<< "${item}")"
        ip_addr="$(jq -r '.value.ip' <<< "${item}")"
        port="$(jq -r '.value.port' <<< "${item}")"
        echo "    service-${slug}:"
        echo "      loadBalancer:"
        echo "        servers:"
        echo "          - url: \"http://${ip_addr}:${port}\""
      done < <(jq -c 'to_entries[]' <<< "${map_json}")
    fi
  } > "${tmp_file}"

  mv "${tmp_file}" "${routes_file}"
}

sync_once() {
  local existing_map_json
  local new_records_file
  local new_map_file

  existing_map_json="$(cat "${map_file}" 2>/dev/null || echo '{}')"
  if ! jq -e . >/dev/null 2>&1 <<< "${existing_map_json}"; then
    existing_map_json='{}'
  fi

  new_records_file="$(mktemp)"
  : > "${new_records_file}"

  while IFS= read -r container_id; do
    inspect_json="$(docker inspect "${container_id}" 2>/dev/null)" || continue
    name="$(jq -r '.[0].Name | ltrimstr("/")' <<< "${inspect_json}")"
    publish_label="$(jq -r '.[0].Config.Labels["agents-sandbox.public"] // empty' <<< "${inspect_json}")"
    manual_port="$(jq -r '.[0].Config.Labels["agents-sandbox.port"] // empty' <<< "${inspect_json}")"
    preferred_network="$(jq -r '.[0].Config.Labels["agents-sandbox.network"] // empty' <<< "${inspect_json}")"

    if [ -z "${name}" ]; then
      continue
    fi
    if [ "${name}" = "${traefik_container}" ] || [[ "${name}" == sandbox-ingress-* ]]; then
      continue
    fi
    if [ -n "${publish_label}" ] && is_disabled "${publish_label}"; then
      continue
    fi

    if [ -n "${manual_port}" ]; then
      port="${manual_port}"
    else
      port_key="$(jq -r '.[0].NetworkSettings.Ports // {} | keys | map(select(test("^[0-9]+/"))) | sort_by((split("/")[0] | tonumber)) | .[0] // empty' <<< "${inspect_json}")"
      if [ -z "${port_key}" ]; then
        port_key="$(jq -r '.[0].Config.ExposedPorts // {} | keys | map(select(test("^[0-9]+/"))) | sort_by((split("/")[0] | tonumber)) | .[0] // empty' <<< "${inspect_json}")"
      fi
      if [ -z "${port_key}" ]; then
        continue
      fi
      port="${port_key%%/*}"
    fi

    if ! [[ "${port}" =~ ^[0-9]+$ ]]; then
      continue
    fi

    network_name="${preferred_network}"
    if [ -n "${network_name}" ]; then
      ip_addr="$(jq -r --arg net "${network_name}" '.[0].NetworkSettings.Networks[$net].IPAddress // empty' <<< "${inspect_json}")"
    else
      network_name=""
      ip_addr=""
    fi

    if [ -z "${ip_addr}" ]; then
      network_name="$(jq -r '.[0].NetworkSettings.Networks | keys | sort | .[0] // empty' <<< "${inspect_json}")"
      if [ -z "${network_name}" ]; then
        continue
      fi
      ip_addr="$(jq -r --arg net "${network_name}" '.[0].NetworkSettings.Networks[$net].IPAddress // empty' <<< "${inspect_json}")"
      if [ -z "${ip_addr}" ]; then
        continue
      fi
    fi

    ensure_traefik_network "${network_name}"

    slug="$(jq -r --arg id "${container_id}" '.[$id].slug // empty' <<< "${existing_map_json}")"
    if [ -z "${slug}" ]; then
      slug="$(random_slug)"
      while jq -e --arg s "${slug}" 'to_entries[]? | select(.value.slug == $s)' <<< "${existing_map_json}" >/dev/null; do
        slug="$(random_slug)"
      done
    fi

    host="${slug}.${base_domain}"
    url="http://${host}"
    target="http://${ip_addr}:${port}"

    jq -nc \
      --arg id "${container_id}" \
      --arg slug "${slug}" \
      --arg host "${host}" \
      --arg url "${url}" \
      --arg name "${name}" \
      --arg network "${network_name}" \
      --arg ip "${ip_addr}" \
      --arg target "${target}" \
      --argjson port "${port}" \
      '{id: $id, slug: $slug, host: $host, url: $url, name: $name, network: $network, ip: $ip, target: $target, port: $port}' \
      >> "${new_records_file}"
  done < <(docker ps -q)

  new_map_file="$(mktemp)"
  if [ -s "${new_records_file}" ]; then
    jq -s 'map({(.id): (del(.id))}) | add // {}' "${new_records_file}" > "${new_map_file}"
  else
    echo '{}' > "${new_map_file}"
  fi

  mv "${new_map_file}" "${map_file}"
  build_routes "$(cat "${map_file}")"

  rm -f "${new_records_file}"
}

while true; do
  sync_once || true
  sleep "${poll_seconds}"
done
