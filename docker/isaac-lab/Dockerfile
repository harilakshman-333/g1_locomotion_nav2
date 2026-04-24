# =============================================================================
# Isaac Lab Container — G1 locomotion sim + ROS 2 sensor bridge
# =============================================================================
# Base: NVIDIA's official Isaac Lab image (includes Isaac Sim 4.x + Isaac Lab 2.x)
# EULA: https://docs.omniverse.nvidia.com/isaacsim/latest/common/NVIDIA_Omniverse_License_Agreement.html
# =============================================================================
FROM nvcr.io/nvidia/isaac-lab:2.0.0

# ── System packages ──────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg2 lsb-release \
    && rm -rf /var/lib/apt/lists/*

# ── ROS 2 Humble (minimal — only what the bridge needs) ─────────────────────
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    | gpg --dearmor -o /usr/share/keyrings/ros-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
    http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/ros2.list \
 && apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-ros-base \
    ros-humble-sensor-msgs \
    ros-humble-nav-msgs \
    ros-humble-geometry-msgs \
    ros-humble-tf2-ros \
    ros-humble-tf2-geometry-msgs \
    python3-colcon-common-extensions \
 && rm -rf /var/lib/apt/lists/*

# ── Python deps for the ROS 2 / Isaac Lab bridge wrapper ────────────────────
RUN /isaac-lab/.venv/bin/pip install \
    rclpy \
    numpy \
    transforms3d

# ── unitree_sim_isaaclab — G1 assets, DDS config, task environments ─────────
RUN /isaac-lab/.venv/bin/pip install \
    "unitree_sim_isaaclab @ git+https://github.com/unitreerobotics/unitree_sim_isaaclab.git"

# ── Copy sim wrapper scripts ─────────────────────────────────────────────────
COPY sim/ /workspace/g1_sim/
RUN chmod +x /workspace/g1_sim/launch_sim.sh

# ── ROS 2 setup sourced on every shell ──────────────────────────────────────
RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc

WORKDIR /workspace

ENTRYPOINT ["/workspace/g1_sim/launch_sim.sh"]
