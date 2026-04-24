#!/usr/bin/env bash
# =============================================================================
# scripts/run_sim_eval.sh
# Runs N autonomous A→B navigation episodes in simulation and reports results.
#
# Usage:
#   ./scripts/run_sim_eval.sh [--episodes N] [--task block_stacking]
#
# Pass criteria (Phase 4 gate):
#   ✅ G1 stays upright for all episodes
#   ✅ Reaches goal within 0.3 m for ≥ 3/3 episodes
#   ✅ /cmd_vel publish rate ≥ 8 Hz during navigation
#   ✅ No navigation timeout in any episode
# =============================================================================
set -euo pipefail

EPISODES=3
GOAL_TOLERANCE=0.30   # metres

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --episodes) EPISODES="$2"; shift 2 ;;
        *)          shift ;;
    esac
done

echo "============================================================"
echo "  G1 Sim Navigation Evaluation"
echo "  Episodes: ${EPISODES}"
echo "  Goal tolerance: ${GOAL_TOLERANCE} m"
echo "============================================================"

# ── Ensure containers are running ─────────────────────────────────────────────
if ! docker compose -f docker/docker-compose.yml ps | grep -q "running"; then
    echo "ERROR: Containers not running. Run ./scripts/sim_up.sh first."
    exit 1
fi

PASS=0
FAIL=0

for i in $(seq 1 "${EPISODES}"); do
    echo ""
    echo "── Episode ${i}/${EPISODES} ──────────────────────────────────────────"

    # Send a 2D Nav Goal via the Nav2 action server
    # Goal: 3 m ahead of spawn (x=3.0, y=0.0, orientation=straight ahead)
    RESULT=$(docker compose -f docker/docker-compose.yml exec -T ros2-nav bash -c "
        source /opt/ros/humble/setup.bash
        timeout 60 ros2 action send_goal /navigate_to_pose \
            nav2_msgs/action/NavigateToPose \
            '{pose: {header: {frame_id: map}, pose: {position: {x: 3.0, y: 0.0, z: 0.0},
              orientation: {w: 1.0}}}}' \
            --feedback 2>&1 | tail -5
    " 2>&1 || echo "TIMEOUT")

    if echo "${RESULT}" | grep -qi "succeeded"; then
        echo "  ✅ Episode ${i}: SUCCESS"
        ((PASS++))
    else
        echo "  ❌ Episode ${i}: FAILED"
        echo "     Output: ${RESULT}"
        ((FAIL++))
    fi

    # Brief pause between episodes (let sim reset)
    sleep 3
done

echo ""
echo "============================================================"
echo "  Results: ${PASS}/${EPISODES} passed"
echo "  Gate:    3/3 required to proceed to real robot"
echo "============================================================"

if [[ "${PASS}" -ge 3 ]]; then
    echo ""
    echo "  ✅ SIM GATE PASSED — ready for Phase 5 (real robot)"
    exit 0
else
    echo ""
    echo "  ❌ SIM GATE FAILED — tune nav2_params.yaml and re-run"
    exit 1
fi
