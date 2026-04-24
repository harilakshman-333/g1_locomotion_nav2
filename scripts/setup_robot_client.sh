#!/usr/bin/env bash
# setup_robot_client.sh
# Sets up the unitree_deploy client environment on your dev PC.
# Run on the PC connected to the G1 (not on the Jetson).
# Usage: bash scripts/setup_robot_client.sh [/path/to/unifolm-world-model-action]

set -euo pipefail

WMA_DIR="${1:-$HOME/unifolm-world-model-action}"
SDK_DIR="$HOME/unitree_sdk2_python"

echo "=== Cloning repos (if not already present) ==="
if [[ ! -d "$WMA_DIR" ]]; then
  git clone --recurse-submodules \
    https://github.com/unitreerobotics/unifolm-world-model-action.git "$WMA_DIR"
fi

if [[ ! -d "$SDK_DIR" ]]; then
  git clone https://github.com/unitreerobotics/unitree_sdk2_python.git "$SDK_DIR"
fi

echo "=== Creating conda environment: unitree_deploy ==="
if ! conda info --envs | grep -q "^unitree_deploy "; then
  conda create -n unitree_deploy python=3.10 -y
fi

CONDA_BASE=$(conda info --base)
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate unitree_deploy

echo "=== Installing pinocchio ==="
conda install pinocchio -c conda-forge -y

echo "=== Installing unitree_deploy package ==="
cd "$WMA_DIR/unitree_deploy"
pip install -e .
pip install -e ".[lerobot]"

echo "=== Installing unitree_sdk2_python ==="
cd "$SDK_DIR"
pip install -e .

echo ""
echo "=== Smoke test — check connectivity to G1 ==="
echo "Make sure the G1 is powered on and connected to the same LAN."
echo "Run:  ssh unitree@192.168.123.164    (password: 123)"
echo ""
echo "Head camera test (no wrist camera needed):"
echo "  conda activate unitree_deploy"
echo "  cd $WMA_DIR/unitree_deploy"
echo "  python test/camera/test_image_client_camera.py"
echo ""
echo "IMPORTANT: Dex3-1 is not natively supported by robot_configs.py."
echo "You must complete Phase 4e (add g1_dex3 config) before running the"
echo "manipulation demo. See README.md Phase 4e for instructions."
