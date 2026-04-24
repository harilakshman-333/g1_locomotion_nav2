#!/usr/bin/env bash
# =============================================================================
# sim/launch_sim.sh
# Entry point for the isaac-lab container.
# Starts Isaac Lab with the G1 locomotion task + ROS 2 bridge wrapper.
# =============================================================================
set -euo pipefail

# ── Source ROS 2 ─────────────────────────────────────────────────────────────
source /opt/ros/humble/setup.bash

# ── Config (from docker-compose .env / environment vars) ─────────────────────
NUM_ENVS="${NUM_ENVS:-1}"
ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-42}"

echo "============================================================"
echo "  G1 Isaac Lab Locomotion Sim"
echo "  NUM_ENVS     : ${NUM_ENVS}"
echo "  ROS_DOMAIN_ID: ${ROS_DOMAIN_ID}"
echo "  DISPLAY      : ${DISPLAY:-:1}"
echo "============================================================"

# ── Allow Isaac Sim to connect to the X11 server (already set by sim_up.sh) ──
export DISPLAY="${DISPLAY:-:1}"

# ── Launch Isaac Lab with the G1 locomotion + ROS 2 bridge script ────────────
# The -p flag runs a custom Python script instead of the default CLI.
# Our script (g1_locomotion_ros2.py) wraps the task env and wires /cmd_vel.
/isaac-lab/isaaclab.sh \
    -p /workspace/g1_sim/g1_locomotion_ros2.py \
    --task "Isaac-Velocity-Flat-G1-v1" \
    --num_envs "${NUM_ENVS}" \
    --headless false \
    --video false
