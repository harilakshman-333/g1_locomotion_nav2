#!/usr/bin/env bash
# run_robot_client.sh
# Launches the robot client on your dev PC to communicate with the G1.
# Prerequisites:
#   1. image_server.py is running on the G1 Jetson (192.168.123.164)
#   2. dex1_1_gripper_server is running on the dev PC
#   3. SSH tunnel to inference server is open (see README Phase 5b)
#   4. conda env unitree_deploy is set up
#
# Usage: bash scripts/run_robot_client.sh [language_instruction]

set -euo pipefail

INSTRUCTION="${1:-stack the block}"
WMA_DIR="${WMA_DIR:-$HOME/unifolm-world-model-action}"
OUTPUT_DIR="$(pwd)/results/robot_runs/$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OUTPUT_DIR"

CONDA_BASE=$(conda info --base)
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate unitree_deploy

echo "=== Robot client starting ==="
echo "    instruction   : $INSTRUCTION"
echo "    output dir    : $OUTPUT_DIR"
echo "    server        : localhost:8000 (via SSH tunnel)"
echo ""
echo "SAFETY: Ensure the G1 is in a harness for first runs."
echo "Press Ctrl-C within 5 seconds to abort..."
sleep 5

cd "$WMA_DIR/unitree_deploy"
# NOTE: "g1_dex3" is a custom robot type you must add to robot_configs.py (Phase 4e).
# Do NOT use "g1_dex1" with a Dex3-1 attached — it will send wrong gripper commands.
python scripts/robot_client.py \
  --robot_type "g1_dex3" \
  --action_horizon 16 \
  --exe_steps 16 \
  --observation_horizon 2 \
  --language_instruction "$INSTRUCTION" \
  --output_dir "$OUTPUT_DIR" \
  --control_freq 15
