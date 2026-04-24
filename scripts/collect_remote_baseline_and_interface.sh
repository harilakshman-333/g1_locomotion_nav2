#!/usr/bin/env bash
# Collect exact software baseline and robot control interface details from a remote workstation.
#
# Usage:
#   bash scripts/collect_remote_baseline_and_interface.sh [ssh_host] [robot_ip]
#
# Example:
#   bash scripts/collect_remote_baseline_and_interface.sh nr@10.15.146.156 192.168.123.164

set -euo pipefail

SSH_HOST="${1:-nr@10.15.146.156}"
ROBOT_IP="${2:-192.168.123.164}"
TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="$(pwd)/reports"
OUT_FILE="$OUT_DIR/baseline_and_interface_${TS}.txt"

mkdir -p "$OUT_DIR"

echo "Collecting baseline and interface details from $SSH_HOST ..."
echo "Output file: $OUT_FILE"

ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH_HOST" "ROBOT_IP='$ROBOT_IP' bash -s" <<'REMOTE' | tee "$OUT_FILE"
set -euo pipefail

print_cmd_if_exists() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "yes"
  else
    echo "no"
  fi
}

echo "============================================================"
echo "SECTION: MACHINE"
echo "============================================================"
echo "timestamp_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "hostname: $(hostname)"
if [[ -f /etc/os-release ]]; then
  echo "os_release:"
  cat /etc/os-release
fi
echo "kernel: $(uname -a)"

echo ""
echo "============================================================"
echo "SECTION: GPU / CUDA"
echo "============================================================"
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia_smi_version:"
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
else
  echo "nvidia-smi not found"
fi

if command -v nvcc >/dev/null 2>&1; then
  echo "nvcc_version:"
  nvcc --version
else
  echo "nvcc not found"
fi

echo ""
echo "============================================================"
echo "SECTION: PYTHON / CONDA / PIP"
echo "============================================================"
echo "python3_exists: $(print_cmd_if_exists python3)"
if command -v python3 >/dev/null 2>&1; then
  echo "python3_version: $(python3 --version 2>&1)"
fi

echo "pip3_exists: $(print_cmd_if_exists pip3)"
if command -v pip3 >/dev/null 2>&1; then
  echo "pip3_version: $(pip3 --version 2>&1)"
fi

echo "conda_exists: $(print_cmd_if_exists conda)"
if command -v conda >/dev/null 2>&1; then
  echo "conda_version: $(conda --version 2>&1)"
  echo "conda_envs:"
  conda info --envs || true
fi

echo ""
echo "============================================================"
echo "SECTION: REPO BASELINE"
echo "============================================================"
for repo in "$HOME/unifolm-vla" "$HOME/unifolm-world-model-action" "$HOME/unitree_sdk2_python"; do
  echo "repo_path: $repo"
  if [[ -d "$repo/.git" ]]; then
    (
      cd "$repo"
      echo "  branch: $(git rev-parse --abbrev-ref HEAD)"
      echo "  commit: $(git rev-parse HEAD)"
      echo "  status_short:"
      git status --short || true
    )
  else
    echo "  not_found"
  fi
done

echo ""
echo "============================================================"
echo "SECTION: ROBOT CONTROL INTERFACE"
echo "============================================================"
echo "target_robot_ip: ${ROBOT_IP}"

echo "network_interfaces:"
if command -v ip >/dev/null 2>&1; then
  ip -br addr || true
else
  ifconfig -a || true
fi

echo "route_to_robot:"
if command -v ip >/dev/null 2>&1; then
  ip route get "$ROBOT_IP" || true
fi

echo "ping_robot:"
if command -v ping >/dev/null 2>&1; then
  ping -c 2 -W 1 "$ROBOT_IP" || true
fi

echo "dds_related_env:"
env | grep -E 'CYCLONEDDS|RMW_IMPLEMENTATION|ROS_DOMAIN_ID|FASTRTPS' || true

echo "running_processes_related:"
ps -ef | grep -Ei 'dex|gripper|unitree|cyclonedds|robot_client|image_server' | grep -v grep || true

echo "candidate_dex3_binaries:"
find "$HOME" -maxdepth 5 -type f \( -iname '*dex3*' -o -iname '*gripper*' \) 2>/dev/null | head -n 50 || true

echo ""
echo "============================================================"
echo "SECTION: SAFETY / EVAL POLICY"
echo "============================================================"
echo "first_eval_in_harness: REQUIRED"
echo "primary_metric: task_success_rate_on_robot"
echo "planned_dataset: G1_Dex3_ObjectPlacement_Dataset"
echo "planned_checkpoint: UnifoLM-VLA-Base"
echo "camera_mode: head_camera_only"
REMOTE

echo "Done. Collected report: $OUT_FILE"
