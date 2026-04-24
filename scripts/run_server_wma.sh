#!/usr/bin/env bash
# run_server_wma.sh
# Launch the UnifoLM-WMA-0 inference server.
# Run on the GPU machine after sourcing configs/wma_server.env.
# Usage: source configs/wma_server.env && bash scripts/run_server_wma.sh

set -euo pipefail

: "${WMA_REPO_DIR:?Set WMA_REPO_DIR (source configs/wma_server.env)}"
: "${CKPT_PATH:?Set CKPT_PATH}"
: "${RES_DIR:=$(pwd)/results/wma}"
: "${DATASETS:=G1_Pack_Camera}"
: "${SERVER_PORT:=8000}"

CONDA_BASE=$(conda info --base)
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate unifolm-wma

EVAL_SCRIPT="$WMA_REPO_DIR/scripts/run_real_eval_server.sh"

if [[ ! -f "$EVAL_SCRIPT" ]]; then
  echo "ERROR: $EVAL_SCRIPT not found. Is WMA_REPO_DIR correct?"
  exit 1
fi

mkdir -p "$RES_DIR"

echo "=== Starting UnifoLM-WMA-0 inference server on port $SERVER_PORT ==="
echo "    checkpoint : $CKPT_PATH"
echo "    datasets   : $DATASETS"
echo "    results    : $RES_DIR"
echo ""

cd "$WMA_REPO_DIR"
ckpt="$CKPT_PATH" \
  res_dir="$RES_DIR" \
  datasets="($DATASETS)" \
  bash "$EVAL_SCRIPT"
