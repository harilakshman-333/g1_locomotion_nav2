#!/usr/bin/env bash
# setup_server_wma.sh
# One-shot setup for the UnifoLM-WMA-0 inference server environment.
# Run on the GPU machine (requires CUDA 12.4, conda).
# Usage: bash scripts/setup_server_wma.sh [/path/to/unifolm-world-model-action]

set -euo pipefail

REPO_DIR="${1:-$HOME/unifolm-world-model-action}"

echo "=== Cloning UnifoLM-WMA-0 (if not already present) ==="
if [[ ! -d "$REPO_DIR" ]]; then
  git clone --recurse-submodules \
    https://github.com/unitreerobotics/unifolm-world-model-action.git "$REPO_DIR"
else
  echo "Repo already cloned; updating submodules..."
  cd "$REPO_DIR"
  git submodule update --init --recursive
fi

echo "=== Creating conda environment: unifolm-wma ==="
if ! conda info --envs | grep -q "^unifolm-wma "; then
  conda create -n unifolm-wma python=3.10.18 -y
fi

CONDA_BASE=$(conda info --base)
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate unifolm-wma

echo "=== Installing conda dependencies ==="
conda install pinocchio=3.2.0 -c conda-forge -y
conda install ffmpeg=7.1.1 -c conda-forge -y

echo "=== Installing unifolm-wma package ==="
cd "$REPO_DIR"
pip install -e .

echo "=== Installing dlimp submodule ==="
cd external/dlimp
pip install -e .
cd ../..

echo "=== Installing huggingface-cli ==="
pip install huggingface_hub[cli]

echo ""
echo "Done! Activate with:  conda activate unifolm-wma"
