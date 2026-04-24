#!/usr/bin/env bash
# download_checkpoints.sh
# Downloads UnifoLM VLA and/or WMA pre-trained checkpoints from Hugging Face.
# Usage: bash scripts/download_checkpoints.sh [vla|wma|all]
# Usage: bash scripts/download_checkpoints.sh [vla|wma|dex3|all]

set -euo pipefail

MODE="${1:-vla}"
# Dex3-1 task to download (used with 'dex3' mode). Defaults to BlockStacking.
DEX3_TASK="${2:-G1_Dex3_BlockStacking_Dataset}"
CKPT_DIR="$(pwd)/checkpoints"
mkdir -p "$CKPT_DIR"

download_vla() {
  echo "=== Downloading UnifoLM-VLM-Base (VLM backbone) ==="
  huggingface-cli download unitreerobotics/UnifoLM-VLM-Base \
    --local-dir "$CKPT_DIR/UnifoLM-VLM-Base"

  echo "=== Downloading UnifoLM-VLA-Base (fine-tuned on G1 tasks) ==="
  huggingface-cli download unitreerobotics/UnifoLM-VLA-Base \
    --local-dir "$CKPT_DIR/UnifoLM-VLA-Base"

  echo "VLA checkpoints saved to: $CKPT_DIR"
}

download_wma() {
  echo "=== Downloading UnifoLM-WMA-0-Dual (fine-tuned on 5 Unitree datasets) ==="
  huggingface-cli download unitreerobotics/UnifoLM-WMA-0-Dual \
    --local-dir "$CKPT_DIR/UnifoLM-WMA-0-Dual"

  echo "WMA checkpoints saved to: $CKPT_DIR"
}

case "$MODE" in
  vla)  download_vla ;;
  wma)  download_wma ;;
  dex3)
    echo "=== Downloading Dex3-1 dataset: $DEX3_TASK ==="
    huggingface-cli download "unitreerobotics/$DEX3_TASK" \
      --repo-type dataset \
      --local-dir "$CKPT_DIR/../data/$DEX3_TASK"
    echo "Dataset saved to: $(pwd)/data/$DEX3_TASK"
    ;;
  all)  download_vla; download_wma ;;
  *)
    echo "Unknown mode: $MODE"
    echo "Usage: $0 [vla|wma|all]"
    exit 1
    ;;
esac

echo ""
echo "Done. Update configs/vla_server.env or configs/wma_server.env"
echo "to point CKPT_PATH at the downloaded directories."
