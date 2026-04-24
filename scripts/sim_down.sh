#!/usr/bin/env bash
# =============================================================================
# scripts/sim_down.sh
# Tears down the simulation stack cleanly.
#
# Usage:
#   ./scripts/sim_down.sh           # stop containers, keep volumes
#   ./scripts/sim_down.sh --clean   # stop + remove volumes (wipes saved maps)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/docker/docker-compose.yml"

VOLUMES_FLAG=""
if [[ "${1:-}" == "--clean" ]]; then
    VOLUMES_FLAG="--volumes"
    echo "WARNING: --clean will remove saved SLAM maps and Isaac logs."
    read -rp "Continue? [y/N] " confirm
    [[ "${confirm}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

echo "Stopping G1 navigation stack…"
docker compose \
    --file "${COMPOSE_FILE}" \
    --env-file "${PROJECT_ROOT}/docker/.env" \
    down ${VOLUMES_FLAG}

# Revoke X11 docker access
xhost -local:docker 2>/dev/null || true

echo "Done."
