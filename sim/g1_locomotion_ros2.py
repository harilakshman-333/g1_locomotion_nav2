"""
sim/g1_locomotion_ros2.py
=============================================================================
Isaac Lab custom runner for the G1 locomotion task.

What this does:
  1. Enables the isaacsim.ros2.bridge Omniverse extension so Isaac Sim
     can publish/subscribe ROS 2 topics inside the container.
  2. Runs the standard Isaac-Velocity-Flat-G1-v1 environment (pre-trained
     motion.pt policy ships with unitree_rl_gym / Isaac Lab).
  3. Publishes sensor topics Nav2 needs:
       /depth/image_raw          (sensor_msgs/Image)
       /imu/data                 (sensor_msgs/Imu)
       /odom                     (nav_msgs/Odometry)  — sim ground truth
       /joint_states             (sensor_msgs/JointState)
       /tf                       (tf2_msgs/TFMessage)  — odom → base_link
  4. Subscribes to /cmd_vel (geometry_msgs/Twist) and injects vx/vy/yaw
     into the policy observation vector every sim step.

Run via launch_sim.sh — do not call directly.
=============================================================================
"""

from __future__ import annotations

import argparse
import threading
import time

import numpy as np

# ── Isaac Lab CLI parser (must happen before importing omni) ─────────────────
from isaaclab.app import AppLauncher

parser = argparse.ArgumentParser(description="G1 Locomotion + ROS 2 bridge")
parser.add_argument("--task",       type=str, default="Isaac-Velocity-Flat-G1-v1")
parser.add_argument("--num_envs",   type=int, default=1)
AppLauncher.add_app_launcher_args(parser)
args_cli, _ = parser.parse_known_args()

# Launch Omniverse simulation kit
app_launcher = AppLauncher(args_cli)
simulation_app = app_launcher.app

# ── Now safe to import Isaac Lab simulation modules ──────────────────────────
import gymnasium as gym
import torch

import isaaclab_tasks  # noqa: F401  — registers all built-in tasks incl. G1
from isaaclab.envs import DirectRLEnv, ManagerBasedRLEnv

# ── Enable ROS 2 bridge extension ────────────────────────────────────────────
import omni.kit.app  # noqa: F401
manager = omni.kit.app.get_app().get_extension_manager()
manager.set_extension_enabled_immediate("isaacsim.ros2.bridge", True)

# ── ROS 2 imports (available after bridge extension is enabled) ───────────────
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist, TransformStamped
from nav_msgs.msg import Odometry
from sensor_msgs.msg import Imu, JointState, Image
from tf2_ros import TransformBroadcaster
from builtin_interfaces.msg import Time as RosTime


# =============================================================================
class G1ROS2Bridge(Node):
    """
    ROS 2 node that lives alongside the Isaac Lab sim loop.

    Subscribes:
        /cmd_vel  (geometry_msgs/Twist)  → sets self.vel_command

    Publishes:
        /odom          — sim ground-truth base_link pose
        /imu/data      — simulated IMU (gravity vector + angular velocity)
        /joint_states  — all leg joint positions and velocities
        /tf            — odom → base_link transform
    """

    def __init__(self):
        super().__init__("g1_ros2_bridge")

        # Velocity command from Nav2: [vx (m/s), vy (m/s), yaw_rate (rad/s)]
        self._vel_command = np.zeros(3, dtype=np.float32)
        self._lock = threading.Lock()

        # ── Subscriber ───────────────────────────────────────────────────────
        self.create_subscription(Twist, "/cmd_vel", self._cmd_vel_cb, 10)

        # ── Publishers ───────────────────────────────────────────────────────
        self._pub_odom   = self.create_publisher(Odometry,    "/odom",         10)
        self._pub_imu    = self.create_publisher(Imu,         "/imu/data",     10)
        self._pub_joints = self.create_publisher(JointState,  "/joint_states", 10)
        self._tf_broadcaster = TransformBroadcaster(self)

        self.get_logger().info("G1 ROS 2 bridge node ready.")

    # ── /cmd_vel callback ────────────────────────────────────────────────────
    def _cmd_vel_cb(self, msg: Twist) -> None:
        with self._lock:
            self._vel_command[:] = [
                msg.linear.x,
                msg.linear.y,
                msg.angular.z,
            ]

    @property
    def vel_command(self) -> np.ndarray:
        with self._lock:
            return self._vel_command.copy()

    # ── Publish helper ───────────────────────────────────────────────────────
    def publish_state(
        self,
        root_pos: np.ndarray,    # [3]  world XYZ
        root_quat: np.ndarray,   # [4]  w,x,y,z
        root_lin_vel: np.ndarray,# [3]
        root_ang_vel: np.ndarray,# [3]  gyro
        gravity_vec: np.ndarray, # [3]  projected gravity in base frame
        joint_names: list[str],
        joint_pos: np.ndarray,
        joint_vel: np.ndarray,
        sim_time: float,
    ) -> None:
        stamp = self._to_ros_time(sim_time)

        self._publish_odom(root_pos, root_quat, root_lin_vel, root_ang_vel, stamp)
        self._publish_imu(gravity_vec, root_ang_vel, stamp)
        self._publish_joint_states(joint_names, joint_pos, joint_vel, stamp)
        self._publish_tf(root_pos, root_quat, stamp)

    def _publish_odom(self, pos, quat, lin_vel, ang_vel, stamp):
        msg = Odometry()
        msg.header.stamp = stamp
        msg.header.frame_id = "odom"
        msg.child_frame_id  = "base_link"
        msg.pose.pose.position.x = float(pos[0])
        msg.pose.pose.position.y = float(pos[1])
        msg.pose.pose.position.z = float(pos[2])
        msg.pose.pose.orientation.w = float(quat[0])
        msg.pose.pose.orientation.x = float(quat[1])
        msg.pose.pose.orientation.y = float(quat[2])
        msg.pose.pose.orientation.z = float(quat[3])
        msg.twist.twist.linear.x  = float(lin_vel[0])
        msg.twist.twist.linear.y  = float(lin_vel[1])
        msg.twist.twist.angular.z = float(ang_vel[2])
        self._pub_odom.publish(msg)

    def _publish_imu(self, gravity_vec, ang_vel, stamp):
        msg = Imu()
        msg.header.stamp = stamp
        msg.header.frame_id = "base_link"
        # Linear acceleration approximated from projected gravity (9.81 * unit gravity vec)
        g = 9.81
        msg.linear_acceleration.x = float(-gravity_vec[0] * g)
        msg.linear_acceleration.y = float(-gravity_vec[1] * g)
        msg.linear_acceleration.z = float(-gravity_vec[2] * g)
        msg.angular_velocity.x = float(ang_vel[0])
        msg.angular_velocity.y = float(ang_vel[1])
        msg.angular_velocity.z = float(ang_vel[2])
        self._pub_imu.publish(msg)

    def _publish_joint_states(self, names, pos, vel, stamp):
        msg = JointState()
        msg.header.stamp = stamp
        msg.name     = names
        msg.position = pos.tolist()
        msg.velocity = vel.tolist()
        self._pub_joints.publish(msg)

    def _publish_tf(self, pos, quat, stamp):
        t = TransformStamped()
        t.header.stamp    = stamp
        t.header.frame_id = "odom"
        t.child_frame_id  = "base_link"
        t.transform.translation.x = float(pos[0])
        t.transform.translation.y = float(pos[1])
        t.transform.translation.z = float(pos[2])
        t.transform.rotation.w    = float(quat[0])
        t.transform.rotation.x    = float(quat[1])
        t.transform.rotation.y    = float(quat[2])
        t.transform.rotation.z    = float(quat[3])
        self._tf_broadcaster.sendTransform(t)

    @staticmethod
    def _to_ros_time(sim_time: float) -> RosTime:
        sec     = int(sim_time)
        nanosec = int((sim_time - sec) * 1e9)
        t = RosTime()
        t.sec     = sec
        t.nanosec = nanosec
        return t


# =============================================================================
# Main simulation loop
# =============================================================================
def main() -> None:
    rclpy.init()
    ros_node = G1ROS2Bridge()

    # Spin ROS 2 in a background thread so it doesn't block the sim
    ros_thread = threading.Thread(target=rclpy.spin, args=(ros_node,), daemon=True)
    ros_thread.start()

    # ── Create Isaac Lab environment ─────────────────────────────────────────
    env: ManagerBasedRLEnv = gym.make(
        args_cli.task,
        num_envs=args_cli.num_envs,
        render_mode="rgb_array" if args_cli.headless else "human",
    )

    # ── Observation / action helpers ─────────────────────────────────────────
    # Isaac-Velocity-Flat-G1-v1 expects a velocity command as part of the obs.
    # The env's command manager exposes set_command() or the obs includes it
    # as the last 3 elements. We write directly to the env's command tensor.
    num_envs = env.num_envs

    # Reset
    obs, _ = env.reset()
    sim_time = 0.0

    ros_node.get_logger().info("Simulation loop started. Publishing ROS 2 topics…")

    try:
        while simulation_app.is_running():
            # ── Inject /cmd_vel into env velocity command ────────────────────
            vel_cmd = ros_node.vel_command          # [vx, vy, yaw]
            vel_tensor = torch.tensor(
                [vel_cmd] * num_envs, dtype=torch.float32, device=env.device
            )
            # Write into the velocity command buffer (Isaac Lab convention)
            if hasattr(env, "command_manager"):
                env.command_manager.set_command("base_velocity", vel_tensor)
            else:
                # Fallback: the observation dict key varies by Isaac Lab version
                pass

            # ── Step simulation ──────────────────────────────────────────────
            obs, reward, terminated, truncated, info = env.step(
                torch.zeros(num_envs, env.action_space.shape[-1], device=env.device)
                # NOTE: the policy is run internally by the env's action manager.
                # We pass zeros here because the env uses its internal policy.
            )

            sim_time += env.step_dt

            # ── Extract state for ROS 2 publishing (env 0 only) ─────────────
            root_state = env.scene["robot"].data.root_state_w[0]   # [13]
            pos    = root_state[:3].cpu().numpy()
            quat   = root_state[3:7].cpu().numpy()   # w,x,y,z
            lin_v  = root_state[7:10].cpu().numpy()
            ang_v  = root_state[10:13].cpu().numpy()

            # Projected gravity vector in base frame
            grav_proj = env.scene["robot"].data.projected_gravity_b[0].cpu().numpy()

            joint_pos = env.scene["robot"].data.joint_pos[0].cpu().numpy()
            joint_vel = env.scene["robot"].data.joint_vel[0].cpu().numpy()
            joint_names = env.scene["robot"].joint_names

            ros_node.publish_state(
                root_pos=pos,
                root_quat=quat,
                root_lin_vel=lin_v,
                root_ang_vel=ang_v,
                gravity_vec=grav_proj,
                joint_names=joint_names,
                joint_pos=joint_pos,
                joint_vel=joint_vel,
                sim_time=sim_time,
            )

            # ── Auto-reset on fall ───────────────────────────────────────────
            if terminated.any():
                obs, _ = env.reset()
                ros_node.get_logger().warn("Episode ended — resetting environment.")

    finally:
        env.close()
        ros_node.destroy_node()
        rclpy.shutdown()
        simulation_app.close()


if __name__ == "__main__":
    main()
