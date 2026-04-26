# =============================================================================
# ROS 2 Nav2 Container — SLAM Toolbox + Nav2 + RViz2 + depth→scan converter
# =============================================================================
# Base: osrf/ros:humble-desktop already includes ros-base, rviz2, tf2, etc.
# We only need to add Nav2, SLAM Toolbox, and sensor tools on top.
# The apt install is split into two layers and wrapped in a retry loop to handle
# the intermittent 400 Bad Request errors from packages.ros.org CDN.
# =============================================================================
FROM osrf/ros:humble-desktop

# ── Helper: retry apt install up to 5 times on failure ───────────────────────
SHELL ["/bin/bash", "-c"]

# ── Layer 1: Core Nav2 stack ──────────────────────────────────────────────────
RUN for i in 1 2 3 4 5; do \
      apt-get update && \
      apt-get install -y --no-install-recommends \
        ros-humble-nav2-bringup \
        ros-humble-nav2-map-server \
        ros-humble-nav2-lifecycle-manager \
        ros-humble-nav2-planner \
        ros-humble-nav2-controller \
        ros-humble-nav2-costmap-2d \
        ros-humble-nav2-behaviors \
        ros-humble-nav2-bt-navigator \
      && break || (echo "Attempt $i failed, retrying in 10s…" && sleep 10); \
    done && rm -rf /var/lib/apt/lists/*

# ── Layer 2: SLAM + sensors + localization ────────────────────────────────────
RUN for i in 1 2 3 4 5; do \
      apt-get update && \
      apt-get install -y --no-install-recommends \
        ros-humble-slam-toolbox \
        ros-humble-depthimage-to-laserscan \
        ros-humble-robot-localization \
        ros-humble-tf2-tools \
        ros-humble-nav2-rviz-plugins \
        python3-colcon-common-extensions \
        python3-vcstool \
      && break || (echo "Attempt $i failed, retrying in 10s…" && sleep 10); \
    done && rm -rf /var/lib/apt/lists/*

# ── Source ROS 2 on every shell ───────────────────────────────────────────────
RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc

# ── Copy configs and launch files ─────────────────────────────────────────────
COPY nav2_config/ /nav2_config/
COPY launch/ /launch/

WORKDIR /

ENTRYPOINT ["bash", "-c", \
    "source /opt/ros/humble/setup.bash && ros2 launch /launch/nav2_launch.py"]
