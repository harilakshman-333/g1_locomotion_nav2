# =============================================================================
# ROS 2 Nav2 Container — SLAM Toolbox + Nav2 + RViz2 + depth→scan converter
# =============================================================================
FROM osrf/ros:humble-desktop

# ── Nav2 full stack ──────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Navigation stack
    ros-humble-nav2-bringup \
    ros-humble-nav2-map-server \
    ros-humble-nav2-lifecycle-manager \
    ros-humble-nav2-planner \
    ros-humble-nav2-controller \
    ros-humble-nav2-costmap-2d \
    ros-humble-nav2-behaviors \
    ros-humble-nav2-bt-navigator \
    # SLAM
    ros-humble-slam-toolbox \
    # Sensor conversion
    ros-humble-depthimage-to-laserscan \
    # Localization / TF
    ros-humble-robot-localization \
    ros-humble-tf2-tools \
    ros-humble-tf2-ros \
    # Visualisation
    ros-humble-rviz2 \
    ros-humble-nav2-rviz-plugins \
    ros-humble-rviz-common \
    # Utilities
    python3-colcon-common-extensions \
    python3-vcstool \
    && rm -rf /var/lib/apt/lists/*

# ── Source ROS 2 on every shell ──────────────────────────────────────────────
RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc

# ── Copy configs and launch files ────────────────────────────────────────────
COPY nav2_config/ /nav2_config/
COPY launch/ /launch/

WORKDIR /

ENTRYPOINT ["bash", "-c", \
    "source /opt/ros/humble/setup.bash && ros2 launch /launch/nav2_launch.py"]
