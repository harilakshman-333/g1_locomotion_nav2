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

# ── ROS 2 Repository ──────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg2 lsb-release software-properties-common git \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && rm -rf /var/lib/apt/lists/*

# ── Install system ROS 2 Humble (needed for AMENT_PREFIX_PATH by bridge) ────
SHELL ["/bin/bash", "-c"]
RUN SUCCESS=0; for i in {1..10}; do \
      apt-get update --fix-missing && \
      apt-get install -y --no-install-recommends --fix-missing \
        ros-humble-ros-base \
        ros-humble-rmw-fastrtps-cpp \
      && SUCCESS=1 && break || (echo "Attempt $i failed, retrying in 10s..." && sleep 10); \
    done; [ "$SUCCESS" = "1" ] || exit 1; rm -rf /var/lib/apt/lists/*

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
# NOTE: No system ROS install — isaacsim.ros2.bridge provides rclpy at runtime.
COPY sim/ /workspace/g1_sim/
RUN chmod +x /workspace/g1_sim/launch_sim.sh

# ── Isaac Sim EULA must be accepted at runtime ────────────────────────────────
ENV ACCEPT_EULA=Y

WORKDIR /workspace

ENTRYPOINT ["/workspace/g1_sim/launch_sim.sh"]
