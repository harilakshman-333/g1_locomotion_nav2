#!/usr/bin/env bash
# run_server_vla.sh
# Launch the UnifoLM-VLA-0 inference server.
# Run on the GPU machine after sourcing configs/vla_server.env.
# Usage: source configs/vla_server.env && bash scripts/run_server_vla.sh

set -euo pipefail

: "${VLA_REPO_DIR:?Set VLA_REPO_DIR (source configs/vla_server.env)}"
: "${CKPT_PATH:?Set CKPT_PATH}"
: "${VLM_PRETRAINED_PATH:?Set VLM_PRETRAINED_PATH}"
: "${SERVER_PORT:=8000}"
: "${UNNORM_KEY:=unitree_g1}"

CONDA_BASE=$(conda info --base)
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate unifolm-vla

# Write a temporary server config so we don't have to edit the repo's shell scripts
EVAL_SCRIPT="$VLA_REPO_DIR/scripts/eval_scripts/run_real_eval_server.sh"

if [[ ! -f "$EVAL_SCRIPT" ]]; then
  echo "ERROR: $EVAL_SCRIPT not found. Is VLA_REPO_DIR correct?"
  exit 1
fi

echo "=== Starting UnifoLM-VLA-0 inference server on port $SERVER_PORT ==="
echo "    checkpoint : $CKPT_PATH"
echo "    vlm path   : $VLM_PRETRAINED_PATH"
echo "    unnorm_key : $UNNORM_KEY"
echo ""

cd "$VLA_REPO_DIR"
ckpt_path="$CKPT_PATH" \
  vlm_pretrained_path="$VLM_PRETRAINED_PATH" \
  port="$SERVER_PORT" \
  unnorm_key="$UNNORM_KEY" \
  bash "$EVAL_SCRIPT"
