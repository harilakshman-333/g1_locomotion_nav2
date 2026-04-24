#!/usr/bin/env bash
# =============================================================================
# scripts/sim_up.sh
# One-shot launcher for the full simulation stack.
#
# Usage:
#   ./scripts/sim_up.sh            # start (interactive, ctrl+c to stop)
#   ./scripts/sim_up.sh --detach   # start in background
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/docker/docker-compose.yml"

# ── X11 permission ──────────────────────────────────────────────────────────
echo "Granting X11 access to Docker containers…"
xhost +local:docker

# ── Export DISPLAY so compose picks it up ────────────────────────────────────
export DISPLAY="${DISPLAY:-:1}"

# ── Parse args ───────────────────────────────────────────────────────────────
DETACH_FLAG=""
if [[ "${1:-}" == "--detach" ]]; then
    DETACH_FLAG="--detach"
    echo "Starting in background (detached)…"
fi

echo ""
echo "============================================================"
echo "  Starting G1 Navigation Stack"
echo "  Compose: ${COMPOSE_FILE}"
echo "  DISPLAY: ${DISPLAY}"
echo "  ROBOT_MODE: ${ROBOT_MODE:-sim}"
echo "============================================================"
echo ""

# ── Build + start ────────────────────────────────────────────────────────────
docker compose \
    --file "${COMPOSE_FILE}" \
    --env-file "${PROJECT_ROOT}/docker/.env" \
    up --build ${DETACH_FLAG}
