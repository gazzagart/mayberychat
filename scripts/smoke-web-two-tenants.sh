#!/usr/bin/env bash
set -euo pipefail

# Starts the backend two-tenant smoke stacks, then runs a Chrome Flutter
# integration test against them from the web runtime.

app_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspace_root="$(cd "$app_root/.." && pwd)"
server_root="$workspace_root/letsyak-server"

project_prefix="${LETSYAK_WEB_SMOKE_PROJECT_PREFIX:-letsyak-web-smoke}"
smoke_root="${LETSYAK_WEB_SMOKE_ROOT:-${TMPDIR:-/tmp}/${project_prefix}}"
control_plane_port="${LETSYAK_SMOKE_CONTROL_PLANE_PORT:-18085}"

cleanup() {
    local exit_code=$?
    if [[ "${KEEP_LETSYAK_WEB_SMOKE:-0}" != "1" ]]; then
        if [[ -d "$smoke_root/local-a" ]]; then
            (cd "$smoke_root/local-a" && docker compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.tenant-data-plane.yml -p "${project_prefix}-a" down -v --remove-orphans >/dev/null 2>&1 || true)
        fi
        if [[ -d "$smoke_root/local-b" ]]; then
            (cd "$smoke_root/local-b" && docker compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.tenant-data-plane.yml -p "${project_prefix}-b" down -v --remove-orphans >/dev/null 2>&1 || true)
        fi
        if [[ -d "$smoke_root/control-plane" ]]; then
            (cd "$smoke_root/control-plane" && set -a && . ./.env.smoke && set +a && docker compose -f docker-compose.control-plane.yml -p "${project_prefix}-control-plane" down -v --remove-orphans >/dev/null 2>&1 || true)
        fi
        docker network rm "${project_prefix}-proxy-network" >/dev/null 2>&1 || true
        rm -rf "$smoke_root"
    else
        echo "Keeping web smoke backend stacks under $smoke_root"
    fi
    exit "$exit_code"
}
trap cleanup EXIT

if ! command -v flutter >/dev/null 2>&1; then
    echo "Error: flutter is required to run the web smoke test." >&2
    exit 1
fi

if [[ ! -x "$server_root/scripts/smoke-two-tenants.sh" ]]; then
    echo "Error: backend smoke script is missing or not executable." >&2
    echo "Expected: $server_root/scripts/smoke-two-tenants.sh" >&2
    exit 1
fi

rm -rf "$smoke_root"

echo "Starting backend smoke stacks for web test..."
KEEP_LETSYAK_SMOKE=1 \
LETSYAK_SMOKE_PROJECT_PREFIX="$project_prefix" \
LETSYAK_SMOKE_ROOT="$smoke_root" \
    "$server_root/scripts/smoke-two-tenants.sh"

echo "Running Flutter Chrome network smoke test..."
cd "$app_root"
flutter test \
    -d chrome \
    --dart-define=CONTROL_PLANE_URL=http://127.0.0.1:${control_plane_port} \
    --dart-define=TENANT_A_USER=smoke_alice \
    --dart-define=TENANT_B_USER=smoke_bob \
    --dart-define=TENANT_PASSWORD='SmokePassw0rd!' \
    test/workspace/workspace_network_smoke_web_test.dart