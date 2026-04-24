# =============================================================================
# Velocity Bridge Container — converts ROS 2 /cmd_vel to:
#   ROBOT_MODE=sim  → Isaac Lab policy velocity input (ROS 2 topic relay)
#   ROBOT_MODE=real → Unitree SDK SportClient.Move(vx, vy, yaw)
# =============================================================================
FROM osrf/ros:humble-ros-base

# ── Dependencies ─────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-geometry-msgs \
    ros-humble-std-msgs \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# ── Unitree SDK (needed for ROBOT_MODE=real) ─────────────────────────────────
# Installed but only imported when ROBOT_MODE=real to avoid bloating sim runs
RUN pip3 install \
    "unitree_sdk2py @ git+https://github.com/unitreerobotics/unitree_sdk2_python.git" \
    || echo "WARNING: unitree_sdk2py install failed — real mode will not work"

# ── Copy bridge source ───────────────────────────────────────────────────────
COPY vel_bridge/ /vel_bridge/

# ── Source ROS 2 on every shell ──────────────────────────────────────────────
RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc

WORKDIR /vel_bridge

ENTRYPOINT ["bash", "-c", \
    "source /opt/ros/humble/setup.bash && python3 vel_bridge_node.py"]
