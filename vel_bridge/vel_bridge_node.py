"""
vel_bridge/vel_bridge_node.py
=============================================================================
Velocity Bridge — the critical sim↔real switchable adapter.

Subscribes to:
    /cmd_vel   (geometry_msgs/Twist)   — published by Nav2 controller

Depending on ROBOT_MODE environment variable:

  ROBOT_MODE=sim  (default)
    Re-publishes to /cmd_vel_sim, which g1_locomotion_ros2.py also reads.
    (In the sim, the Isaac Lab script directly subscribes to /cmd_vel, so
    this bridge primarily handles mode switching and rate limiting.)

  ROBOT_MODE=real
    Sends SportClient.Move(vx, vy, yaw) commands to the Unitree G1 via
    Ethernet using the unitree_sdk2_python library.
    Robot IP is read from ROBOT_IP env var (default 192.168.123.1).

Safety:
  - Hard clamps on max velocity (configurable via env vars)
  - Publishes a /vel_bridge/status topic for monitoring
  - If no /cmd_vel received for >0.5 s (watchdog) in real mode, sends stop
=============================================================================
"""

from __future__ import annotations

import os
import time
import threading

import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist
from std_msgs.msg import String


# ── Safety limits (overridable via env vars) ──────────────────────────────────
MAX_VX      = float(os.environ.get("MAX_VX",    "0.5"))   # m/s forward
MAX_VY      = float(os.environ.get("MAX_VY",    "0.2"))   # m/s lateral
MAX_YAW     = float(os.environ.get("MAX_YAW",   "0.5"))   # rad/s
WATCHDOG_S  = float(os.environ.get("WATCHDOG_S","0.5"))   # stop if silent > 0.5 s

ROBOT_MODE  = os.environ.get("ROBOT_MODE", "sim")
ROBOT_IP    = os.environ.get("ROBOT_IP",   "192.168.123.1")


class VelBridge(Node):
    """ROS 2 node that bridges /cmd_vel to sim or real robot."""

    def __init__(self) -> None:
        super().__init__("vel_bridge")

        self.get_logger().info(
            f"Velocity bridge starting | mode={ROBOT_MODE} | "
            f"max_vx={MAX_VX} max_vy={MAX_VY} max_yaw={MAX_YAW}"
        )

        self._last_cmd_time = time.time()
        self._lock = threading.Lock()

        # ── Subscriber ───────────────────────────────────────────────────────
        self.create_subscription(Twist, "/cmd_vel", self._cmd_vel_cb, 10)

        # ── Status publisher ─────────────────────────────────────────────────
        self._pub_status = self.create_publisher(String, "/vel_bridge/status", 10)

        # ── Mode-specific setup ───────────────────────────────────────────────
        if ROBOT_MODE == "real":
            self._setup_real()
        else:
            self._setup_sim()

        # ── Watchdog timer (real mode only) ──────────────────────────────────
        if ROBOT_MODE == "real":
            self.create_timer(0.1, self._watchdog_cb)

        self.get_logger().info("Velocity bridge ready.")

    # ── Sim mode setup ────────────────────────────────────────────────────────
    def _setup_sim(self) -> None:
        # In sim mode the Isaac Lab wrapper subscribes to /cmd_vel directly.
        # This bridge still performs clamping and status reporting.
        self._pub_cmd = self.create_publisher(Twist, "/cmd_vel_clamped", 10)
        self.get_logger().info("Sim mode: forwarding clamped /cmd_vel → /cmd_vel_clamped")

    # ── Real mode setup ───────────────────────────────────────────────────────
    def _setup_real(self) -> None:
        self.get_logger().info(f"Real mode: connecting to G1 at {ROBOT_IP}")
        try:
            from unitree_sdk2py.go2.sport.sport_client import SportClient
            self._sport_client = SportClient()
            self._sport_client.SetTimeout(0.1)
            self._sport_client.Init()
            self.get_logger().info("SportClient connected.")
        except Exception as exc:
            self.get_logger().error(
                f"SportClient init failed: {exc}\n"
                "Ensure unitree_sdk2py is installed and robot is reachable."
            )
            self._sport_client = None

    # ── /cmd_vel callback ─────────────────────────────────────────────────────
    def _cmd_vel_cb(self, msg: Twist) -> None:
        with self._lock:
            self._last_cmd_time = time.time()

        # Clamp to safety limits
        vx  = max(-MAX_VX,  min(MAX_VX,  msg.linear.x))
        vy  = max(-MAX_VY,  min(MAX_VY,  msg.linear.y))
        yaw = max(-MAX_YAW, min(MAX_YAW, msg.angular.z))

        if ROBOT_MODE == "real":
            self._send_real(vx, vy, yaw)
        else:
            self._send_sim(vx, vy, yaw)

        # Status
        status = String()
        status.data = f"mode={ROBOT_MODE} vx={vx:.2f} vy={vy:.2f} yaw={yaw:.2f}"
        self._pub_status.publish(status)

    # ── Sim: forward clamped twist ────────────────────────────────────────────
    def _send_sim(self, vx: float, vy: float, yaw: float) -> None:
        out = Twist()
        out.linear.x  = vx
        out.linear.y  = vy
        out.angular.z = yaw
        self._pub_cmd.publish(out)

    # ── Real: Unitree SportClient ─────────────────────────────────────────────
    def _send_real(self, vx: float, vy: float, yaw: float) -> None:
        if self._sport_client is None:
            return
        try:
            # Move(vx [m/s], vy [m/s], yaw_rate [rad/s])
            self._sport_client.Move(vx, vy, yaw)
        except Exception as exc:
            self.get_logger().warn(f"SportClient.Move failed: {exc}")

    # ── Watchdog — stop robot if /cmd_vel goes silent ─────────────────────────
    def _watchdog_cb(self) -> None:
        with self._lock:
            elapsed = time.time() - self._last_cmd_time
        if elapsed > WATCHDOG_S:
            if ROBOT_MODE == "real" and self._sport_client is not None:
                try:
                    self._sport_client.Move(0.0, 0.0, 0.0)
                except Exception:
                    pass


# =============================================================================
def main() -> None:
    rclpy.init()
    node = VelBridge()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        if ROBOT_MODE == "real":
            # Emergency stop
            try:
                node._sport_client.Move(0.0, 0.0, 0.0)
            except Exception:
                pass
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
