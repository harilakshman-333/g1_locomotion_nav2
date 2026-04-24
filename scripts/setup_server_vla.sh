#!/usr/bin/env bash
# setup_server_vla.sh
# One-shot setup for the UnifoLM-VLA-0 inference server environment.
# Run on the GPU machine (requires CUDA 12.4, conda).
# Usage: bash scripts/setup_server_vla.sh [/path/to/unifolm-vla]

set -euo pipefail

REPO_DIR="${1:-$HOME/unifolm-vla}"

echo "=== Cloning UnifoLM-VLA-0 (if not already present) ==="
if [[ ! -d "$REPO_DIR" ]]; then
  git clone https://github.com/unitreerobotics/unifolm-vla.git "$REPO_DIR"
fi

echo "=== Creating conda environment: unifolm-vla ==="
if ! conda info --envs | grep -q "^unifolm-vla "; then
  conda create -n unifolm-vla python=3.10.18 -y
fi

# Run the rest inside the activated env
CONDA_BASE=$(conda info --base)
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate unifolm-vla

echo "=== Installing lerobot (pinned commit) ==="
pip install --no-deps \
  "lerobot @ git+https://github.com/huggingface/lerobot.git@0878c68"

echo "=== Installing unifolm-vla package ==="
cd "$REPO_DIR"
pip install -e .

echo "=== Installing FlashAttention2 (requires CUDA 12.4) ==="
pip install "flash-attn==2.5.6" --no-build-isolation

echo "=== Installing huggingface-cli ==="
pip install huggingface_hub[cli]

echo ""
echo "Done! Activate with:  conda activate unifolm-vla"
