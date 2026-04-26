# =============================================================================
# Isaac Lab Container — G1 locomotion sim + ROS 2 sensor bridge
# =============================================================================
# Base: NVIDIA's official Isaac Lab image (includes Isaac Sim 4.x + Isaac Lab 2.x)
# EULA: https://docs.omniverse.nvidia.com/isaacsim/latest/common/NVIDIA_Omniverse_License_Agreement.html
#
# KEY DESIGN DECISION:
# Isaac Sim bundles its own ROS 2 Humble environment inside the
# isaacsim.ros2.bridge extension (located at
# /isaac-sim/exts/isaacsim.ros2.bridge/). We do NOT install ROS 2 via apt —
# that avoids the flaky packages.ros.org mirror entirely.
# rclpy and all ROS 2 Python bindings are available through the Isaac Sim
# Python environment once the bridge extension is enabled at runtime.
# =============================================================================
FROM nvcr.io/nvidia/isaac-lab:2.0.0

# ── Minimal system packages (Ubuntu repos only — no ROS repo needed) ─────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# ── Python packages via Isaac Sim's bundled Python ──────────────────────────
# Isaac Sim's Python is at /isaac-sim/kit/python/bin/python3
# rclpy is NOT installed here — Isaac Sim provides it via isaacsim.ros2.bridge.
# We only add pure-Python utilities that Isaac Sim doesn't bundle.
RUN /isaac-sim/kit/python/bin/python3 -m pip install --no-cache-dir \
    numpy \
    transforms3d

# ── unitree_sim_isaaclab — G1 assets + DDS config + task envs ───────────────
RUN /isaac-sim/kit/python/bin/python3 -m pip install --no-cache-dir \
    "unitree_sim_isaaclab @ git+https://github.com/unitreerobotics/unitree_sim_isaaclab.git" \
    || echo "WARNING: unitree_sim_isaaclab pip install failed — falling back to built-in tasks"

# ── Copy our sim wrapper scripts into the container ──────────────────────────
COPY sim/ /workspace/g1_sim/
RUN chmod +x /workspace/g1_sim/launch_sim.sh

WORKDIR /workspace

# The launch script enables isaacsim.ros2.bridge and starts the G1 task.
ENTRYPOINT ["/workspace/g1_sim/launch_sim.sh"]
