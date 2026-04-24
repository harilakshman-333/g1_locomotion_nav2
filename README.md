# G1 UnifoLM Demo — Implementation Plan

Run a manipulation demo on a Unitree G1 robot using a **UnifoLM pre-trained checkpoint**.
Two model families are available; pick the one that matches your hardware:

| Model | Repo | Best for |
|-------|------|----------|
| **UnifoLM-WMA-0** | [unifolm-world-model-action](https://github.com/unitreerobotics/unifolm-world-model-action) | World-model + action head, uses DynamiCrafter-style video prediction |
| **UnifoLM-VLA-0** | [unifolm-vla](https://github.com/unitreerobotics/unifolm-vla) | Vision-Language-Action (Qwen2.5-VL backbone), simpler deployment |

> **Recommended for first demo:** UnifoLM-VLA-0 — newer (Jan 2026), lighter server requirements, and the `UnifoLM-VLA-Base` checkpoint is already fine-tuned on 12 G1 tasks.

---

## Hardware Requirements

| Component | Your setup | Notes |
|-----------|-----------|-------|
| G1 (EDU version) | ✅ | 23 DOF base or higher |
| End-effector | Dex3-1 (7-DOF hand) | ⚠️ See compatibility note below |
| Wrist camera | None | ✅ Head D435i is sufficient; deploy code only uses head cam |
| G1 on-board PC | Jetson Orin NX 16 GB | Already present in G1 EDU |
| **Inference server** | ≥ 1× NVIDIA GPU | 24 GB VRAM recommended for VLA; WMA needs more |
| Network | Same LAN (Ethernet preferred) | |
| Host dev PC | Ubuntu 20.04/22.04, Python 3.10, conda | |

### ⚠️ Dex3-1 Compatibility Note

The `unifolm-world-model-action` deploy code (`robot_configs.py`) only defines a
`g1_dex1` robot type. You need to add a `g1_dex3` config. The good news:
**Unitree has already published 13 official G1 + Dex3-1 training datasets on
Hugging Face** — so you do not need to collect your own data from scratch.

The one real blocker: **every dataset was recorded with wrist cameras**
(`cam_left_wrist` + `cam_right_wrist`) that you don't have. You must either:
- (a) train without those camera streams (drop them from the data loader), or
- (b) add wrist cameras to your G1 before training.

### Official Dex3-1 Datasets (action space: 28 DOF)

State/action vector — both are shape `[28]`:
```
# Arm joints (14 total, 7 per side)
kLeft/RightShoulderPitch, Roll, Yaw | Elbow | WristRoll, Pitch, Yaw
# Dex3-1 hand joints (14 total, 7 per side)
kLeft/RightHandThumb0-2 | Middle0-1 | Index0-1
```

Camera streams per episode: `cam_left_high`, `cam_right_high` (head), `cam_left_wrist`, `cam_right_wrist` (wrist).

| Dataset | Episodes | Task |
|---------|----------|------|
| `G1_Dex3_BlockStacking_Dataset` | 301 | Stack 3 blocks (red→yellow→blue) |
| `G1_Dex3_CameraPackaging_Dataset` | 201 | Place RealSense D405 into case & close lid |
| `G1_Dex3_GraspSquare_Dataset` | — | Grasp square object |
| `G1_Dex3_ObjectPlacement_Dataset` | — | Place object at target |
| `G1_Dex3_PickApple_Dataset` | — | Pick apple |
| `G1_Dex3_PickBottle_Dataset` | — | Pick bottle |
| `G1_Dex3_PickCharger_Dataset` | — | Pick charger |
| `G1_Dex3_PickDoll_Dataset` | — | Pick doll |
| `G1_Dex3_PickGum_Dataset` | — | Pick gum |
| `G1_Dex3_PickSnack_Dataset` | — | Pick snack |
| `G1_Dex3_PickTissue_Dataset` | — | Pick tissue |
| `G1_Dex3_Pouring_Dataset` | — | Pouring |
| `G1_Dex3_ToastedBread_Dataset` | — | Toasted bread task |

All are LeRobot v2.0 format, Apache-2.0 license.
Collection: https://huggingface.co/collections/unitreerobotics/unifolm-g1-dex3-dataset

**Recommended paths given your hardware:**

| Path | Effort | What you get |
|------|--------|--------------|
| **A — Locomotion demo** | Low — 30 min | G1 walks/runs via `unitree_rl_gym` pre-trained checkpoint. Dex3-1 stays passive. |
| **B — Manipulation with Dex3-1** | Medium — 1–2 days | Unitree official Dex3-1 data already exists. Need to: add `g1_dex3` deploy config, fine-tune VLA on head-cam-only subset of the datasets (no wrist cameras), deploy. |

**Path A** works today with zero code changes. **Path B** is now realistic in 1–2 days
because the training data already exists — the main work is the deploy config extension
and dropping wrist-camera streams from the data loader.

---

## Architecture Overview

```
┌─────────────────────────────────┐          ┌────────────────────────────┐
│  Inference Server (GPU machine) │   HTTP   │  G1 Robot (client)         │
│                                 │◄────────►│                            │
│  scripts/run_real_eval_server   │ :8000    │  unitree_deploy/robot_client│
│  ├── UnifoLM checkpoint         │          │  ├── camera images          │
│  ├── Action prediction          │          │  ├── proprioception state   │
│  └── HTTP action server         │          │  └── arm/gripper control    │
└─────────────────────────────────┘          └────────────────────────────┘
```

---

## Phase 0 — Pre-flight Checklist

- [ ] G1 is in good mechanical condition; joints move freely
- [ ] G1 WiFi/Ethernet connects to the same LAN as the inference server / dev PC
- [ ] You can `ssh unitree@192.168.123.164` (G1 on-board Jetson, password: `123`)
- [ ] Inference server has CUDA ≥ 12.4 drivers installed (manipulation only)
- [ ] `conda` is available on both the server and your dev PC
- [ ] **Locomotion demo:** Dex3-1 can remain attached; it will not be commanded
- [ ] **Manipulation demo:** read the Dex3-1 compatibility note above before proceeding

---

---

## Path A — Locomotion Demo (Recommended First Demo)

Uses the `unitree_rl_gym` pre-trained G1 locomotion checkpoint. **No gripper
commands, no camera, no inference server required.**

```bash
# 1. Clone
git clone https://github.com/unitreerobotics/unitree_rl_gym.git
cd unitree_rl_gym

# 2. Install (no GPU server needed — runs on dev PC)
conda create -n rl_gym python=3.10 -y && conda activate rl_gym
pip install -e .

# 3. Verify Mujoco sim (sim2sim) first
python deploy/deploy_mujoco/deploy_mujoco.py g1.yaml

# 4. Connect to physical G1
#    - Ethernet cable from dev PC to G1
#    - sudo ifconfig → note the interface name (e.g. eth0, enp3s0)
#    - Start robot in hoisting harness
#    - Remote: L2+R2 → enter debug/damping mode
python deploy/deploy_real/deploy_real.py <net_interface> g1.yaml

# 5. Controls (remote controller)
#    start  → move to default joint position
#    A      → start walking (step in place)
#    left joystick → x/y velocity
#    right joystick → yaw rate
#    select → exit (robot goes limp)
```

The pre-trained checkpoint is already at `deploy/pre_train/g1/motion.pt`.
No download needed.

---

## Path B — Manipulation Demo (requires Dex3-1 custom config + retraining)

The phases below cover the full manipulation pipeline. Because the deploy code
only supports Dex1-1 today, you must also complete the **Phase 4e** extension
step (add `g1_dex3` robot config) before Phase 5 will work.

---

## Phase 1 — Clone the Repositories

```bash
# On the inference server (and/or your dev PC)
git clone --recurse-submodules \
    https://github.com/unitreerobotics/unifolm-world-model-action.git

git clone \
    https://github.com/unitreerobotics/unifolm-vla.git

git clone \
    https://github.com/unitreerobotics/unitree_sdk2_python.git
```

---

## Phase 2 — Server Environment Setup

See `scripts/setup_server_vla.sh` (VLA) or `scripts/setup_server_wma.sh` (WMA)
for the one-shot install scripts. Manual steps below.

### 2a — UnifoLM-VLA-0 (recommended)

```bash
conda create -n unifolm-vla python=3.10.18 -y
conda activate unifolm-vla

cd unifolm-vla
pip install --no-deps "lerobot @ git+https://github.com/huggingface/lerobot.git@0878c68"
pip install -e .
pip install "flash-attn==2.5.6" --no-build-isolation
```

### 2b — UnifoLM-WMA-0 (heavier)

```bash
conda create -n unifolm-wma python=3.10.18 -y
conda activate unifolm-wma

conda install pinocchio=3.2.0 -c conda-forge -y
conda install ffmpeg=7.1.1 -c conda-forge -y

cd unifolm-world-model-action
git submodule update --init --recursive
pip install -e .
cd external/dlimp && pip install -e . && cd ../..
```

---

## Phase 3 — Download Pre-trained Checkpoints

All checkpoints are on Hugging Face. Download with `huggingface-cli` or the
helper script `scripts/download_checkpoints.sh`.

### VLA checkpoints

| Checkpoint | HF path | Use |
|-----------|---------|-----|
| `UnifoLM-VLM-Base` | `unitreerobotics/UnifoLM-VLM-Base` | VLM backbone (required) |
| `UnifoLM-VLA-Base` | `unitreerobotics/UnifoLM-VLA-Base` | Fine-tuned on G1 (use this) |

```bash
huggingface-cli download unitreerobotics/UnifoLM-VLM-Base \
    --local-dir ./checkpoints/UnifoLM-VLM-Base

huggingface-cli download unitreerobotics/UnifoLM-VLA-Base \
    --local-dir ./checkpoints/UnifoLM-VLA-Base
```

### WMA checkpoints

| Checkpoint | Use |
|-----------|-----|
| `UnifoLM-WMA-0-Base` | Pre-trained on Open-X |
| `UnifoLM-WMA-0-Dual` | Fine-tuned on 5 Unitree datasets (use this) |

```bash
huggingface-cli download unitreerobotics/UnifoLM-WMA-0-Dual \
    --local-dir ./checkpoints/UnifoLM-WMA-0-Dual
```

---

## Phase 4 — Robot-Side Setup (G1 On-Board & Dev PC)

See `scripts/setup_robot_client.sh` for the automated version.

### 4a — Image server on G1 Jetson

```bash
ssh unitree@192.168.123.164   # password: 123

conda activate tv             # pre-installed on EDU board
cd ~/image_server
python image_server.py        # streams camera feed over LAN
```

### 4b — Dex3-1 gripper service on Dev PC

> The Dex3-1 uses a different service than Dex1-1. The canonical reference is
> Part 5 of the AVP Teleoperation docs: https://github.com/unitreerobotics/avp_teleoperate
> The `dex1_1_service` repo does NOT cover Dex3-1.

```bash
# Follow the AVP teleoperation guide for Dex3-1 hardware bring-up.
# Confirm the correct binary and network interface name with Unitree support.
sudo ./<dex3_service_binary> --network <interface>
```

### 4c — Deploy client environment on Dev PC

```bash
conda create -n unitree_deploy python=3.10 -y
conda activate unitree_deploy

conda install pinocchio -c conda-forge -y

cd unifolm-world-model-action/unitree_deploy
pip install -e .
pip install -e ".[lerobot]"

cd ../../unitree_sdk2_python && pip install -e . && cd ..
```

### 4d — Smoke tests

```bash
conda activate unitree_deploy
cd unifolm-world-model-action/unitree_deploy

# Head camera only (no wrist camera needed)
python test/camera/test_image_client_camera.py

# Arm kinematics
python test/arm/g1/test_g1_arm.py

# Skip test_dex1.py — that test is for Dex1-1, not Dex3-1
```

### 4e — Add `g1_dex3` robot config (**required for Dex3-1**)

The deploy code has no built-in Dex3-1 config. Extend it using the exact joint
names from the official datasets (verified from `meta/info.json`):

1. **Add end-effector config** — edit
   `unitree_deploy/unitree_deploy/robot_devices/endeffector/configs.py`:

```python
@EndEffectorConfig.register_subclass("dex_3")
@dataclass
class Dex3_GripperConfig(EndEffectorConfig):
    # Dex3-1 has 7 DOF per hand (14 total); joint names from official datasets:
    # kLeft/RightHandThumb0, Thumb1, Thumb2, Middle0, Middle1, Index0, Index1
    # Fill motor indices and DDS topic names from the Dex3-1 SDK / avp_teleoperate guide.
    motors: dict[str, tuple[int, str]] = field(default_factory=dict)
    unit_test: bool = False
    init_pose: list | None = None
    control_dt: float = 1 / 200
    mock: bool = False
```

2. **Add robot config** — edit
   `unitree_deploy/unitree_deploy/robot/robot_configs.py`:

```python
def dex3_default_factory():
    return {"dex_3": Dex3_GripperConfig(motors={...})}  # fill from Dex3-1 SDK

@RobotConfig.register_subclass("g1_dex3")
@dataclass
class G1_Dex3_Imageclint_RobotConfig(UnitreeRobotConfig):
    cameras: dict[str, CameraConfig] = field(
        default_factory=g1_image_client_default_factory  # cam_left_high, cam_right_high only
    )
    arm: dict[str, ArmConfig] = field(default_factory=g1_dual_arm_default_factory)  # 14 arm joints
    endeffector: dict[str, EndEffectorConfig] = field(
        default_factory=dex3_default_factory  # 14 Dex3-1 hand joints
    )
```

3. **Download Dex3-1 datasets** (no data collection needed):

```bash
# Pick one task to start — BlockStacking is best documented
huggingface-cli download unitreerobotics/G1_Dex3_BlockStacking_Dataset \
    --repo-type dataset --local-dir ./data/G1_Dex3_BlockStacking_Dataset
```

4. **Drop wrist cameras from the data loader** before fine-tuning (no wrist cameras
   on your robot). In the VLA training config, remove `cam_left_wrist` and
   `cam_right_wrist` from the camera keys. The head cameras (`cam_left_high`,
   `cam_right_high`) are sufficient to start.

5. **Fine-tune `UnifoLM-VLA-Base`** on the Dex3-1 dataset following the VLA
   training steps in Phase 2a, using the Dex3-1 dataset instead of Dex1-1 data.

---

## Phase 5 — Run the Demo (VLA)

### 5a — Start the inference server

```bash
# On GPU server
conda activate unifolm-vla
cd unifolm-vla

# Edit scripts/eval_scripts/run_real_eval_server.sh:
#   ckpt_path   → ./checkpoints/UnifoLM-VLA-Base
#   vlm_pretrained_path → ./checkpoints/UnifoLM-VLM-Base
#   port        → 8000

bash scripts/eval_scripts/run_real_eval_server.sh
```

### 5b — Open SSH tunnel from dev PC to server

```bash
ssh YOUR_GPU_SERVER_USER@YOUR_SERVER_IP -CNg -L 8000:127.0.0.1:8000
```

### 5c — Run robot client

> Replace `g1_dex1` with `g1_dex3` **only after** completing Phase 4e.
> Using `g1_dex1` with a Dex3-1 physically attached will send incorrect
> gripper commands.

```bash
conda activate unitree_deploy
cd unifolm-world-model-action/unitree_deploy

python scripts/robot_client.py \
    --robot_type "g1_dex3" \
    --action_horizon 16 \
    --exe_steps 16 \
    --observation_horizon 2 \
    --language_instruction "stack the block" \
    --output_dir ./results \
    --control_freq 15
```

---

## Phase 5 (alt) — Run the Demo (WMA)

### 5a — Start the inference server

```bash
conda activate unifolm-wma
cd unifolm-world-model-action

# Edit scripts/run_real_eval_server.sh:
#   ckpt     → ./checkpoints/UnifoLM-WMA-0-Dual/model.pt
#   datasets → (G1_Pack_Camera or matching task)

bash scripts/run_real_eval_server.sh
```

### 5b-5c — Same SSH tunnel + robot client as above (WMA uses same client code)

---

## Phase 6 — Safety Checklist Before Every Run

- [ ] Robot is in hoisting harness for first test
- [ ] Emergency stop button is within reach
- [ ] Working area is clear (≥ 1 m around the robot)
- [ ] Run at reduced `control_freq` (e.g., 5 Hz) for the very first trial
- [ ] Start with one of the pre-trained task scenarios matching checkpoint training data
- [ ] Monitor server GPU memory and inference latency; re-run at lower `exe_steps` if latency > 100 ms

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Connection refused :8000` | Check server firewall; use SSH tunnel |
| `pinocchio` import error | `conda install pinocchio=3.2.0 -c conda-forge` |
| `flash-attn` build fails | Must use CUDA 12.4; check `nvcc --version` |
| `KeyError: 'g1_dex3'` in robot_configs | Phase 4e not done; `g1_dex3` is not built-in — add it manually |
| Dex3-1 not responding | Follow AVP teleoperation guide Part 5; verify service binary and `--network` interface |
| `cam_left_wrist`/`cam_right_wrist` missing at inference | Remove wrist cam keys from robot config cameras dict and retrain without them |
| Camera frames dropped | Lower image resolution in `image_server.py` config |
| G1 arm hits joint limits | Reduce `action_horizon`; verify task matches checkpoint |
| Locomotion demo: robot falls immediately | Run in harness first; verify `g1.yaml` policy path is correct |

---

## Repository Layout

```
g1_checkpoint_based_demo/
├── README.md                      ← this file (master plan)
├── scripts/
│   ├── setup_server_vla.sh        ← one-shot VLA server env setup
│   ├── setup_server_wma.sh        ← one-shot WMA server env setup
│   ├── setup_robot_client.sh      ← robot-side client env setup
│   ├── download_checkpoints.sh    ← checkpoint download helper
│   ├── run_server_vla.sh          ← launch VLA inference server
│   ├── run_server_wma.sh          ← launch WMA inference server
│   └── run_robot_client.sh        ← launch robot client
└── configs/
    ├── vla_server.env             ← path variables for VLA server
    └── wma_server.env             ← path variables for WMA server
```

---

## References

- UnifoLM-WMA-0: https://github.com/unitreerobotics/unifolm-world-model-action
- UnifoLM-VLA-0: https://github.com/unitreerobotics/unifolm-vla
- Unitree Deploy client: https://github.com/unitreerobotics/unifolm-world-model-action/blob/main/unitree_deploy/README.md
- unitree_rl_gym (locomotion only): https://github.com/unitreerobotics/unitree_rl_gym
- G1 hardware docs: https://support.unitree.com/home/en/G1_developer/about_G1
- **G1 Dex3-1 datasets (13 tasks):** https://huggingface.co/collections/unitreerobotics/unifolm-g1-dex3-dataset
- AVP teleoperation guide (Dex3-1 setup): https://github.com/unitreerobotics/avp_teleoperate
