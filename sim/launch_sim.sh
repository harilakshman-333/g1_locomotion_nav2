#!/usr/bin/env bash
# =============================================================================
# sim/launch_sim.sh
# Entry point for the isaac-lab container.
# Starts Isaac Lab with the G1 locomotion task + ROS 2 bridge wrapper.
#
# NOTE: Isaac Sim bundles its own Python and ROS 2 environment.
# There is NO system /opt/ros/humble — do not source it here.
# The isaacsim.ros2.bridge extension activates ROS 2 at runtime inside Isaac Sim.
# =============================================================================
set -euo pipefail

# ── Config (from docker-compose .env / environment vars) ─────────────────────
NUM_ENVS="${NUM_ENVS:-1}"
ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-42}"
ACCEPT_EULA="${ACCEPT_EULA:-Y}"

echo "============================================================"
echo "  G1 Isaac Lab Locomotion Sim"
echo "  NUM_ENVS     : ${NUM_ENVS}"
echo "  ROS_DOMAIN_ID: ${ROS_DOMAIN_ID}"
echo "  DISPLAY      : ${DISPLAY:-:1}"
echo "============================================================"

export DISPLAY="${DISPLAY:-:1}"
export ACCEPT_EULA="${ACCEPT_EULA}"

# ── Locate the Isaac Lab / Isaac Sim runner ───────────────────────────────────
# In the official nvcr.io/nvidia/isaac-lab image the runner is at:
#   /isaac-sim/runheadless.native.sh  (headless)
#   /workspace/isaaclab.sh            (if Isaac Lab overlay is present)
# We use the Isaac Sim Python directly for maximum compatibility.
ISAAC_PYTHON="/isaac-sim/kit/python/bin/python3"

if [[ ! -f "${ISAAC_PYTHON}" ]]; then
    echo "ERROR: Isaac Sim Python not found at ${ISAAC_PYTHON}"
    echo "Available python binaries:"
    find /isaac-sim -name "python*" -type f 2>/dev/null | head -5 || true
    exit 1
fi

echo "Using Python: ${ISAAC_PYTHON}"
echo "Starting G1 locomotion + ROS 2 bridge…"

# ── Run the sim wrapper ───────────────────────────────────────────────────────
exec "${ISAAC_PYTHON}" /workspace/g1_sim/g1_locomotion_ros2.py \
    --task "Isaac-Velocity-Flat-G1-v1" \
    --num_envs "${NUM_ENVS}" \
    --headless false \
    --enable_cameras true
