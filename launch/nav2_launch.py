"""
launch/nav2_launch.py
=============================================================================
ROS 2 launch file for the ros2-nav container.

Starts:
  1. depthimage_to_laserscan  — /depth/image_raw → /scan
  2. slam_toolbox             — /scan + /odom → /map (mapping mode)
  3. nav2_bringup             — full Nav2 stack using G1-tuned params
  4. rviz2                    — visualisation with Nav2 plugin panel

All nodes configured for sim_time=true so they sync with Isaac Sim clock.
=============================================================================
"""

import os
from launch import LaunchDescription
from launch.actions import (
    DeclareLaunchArgument,
    GroupAction,
    IncludeLaunchDescription,
    LogInfo,
)
from launch.conditions import IfCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node, SetRemap
from launch_ros.substitutions import FindPackageShare


def generate_launch_description() -> LaunchDescription:

    # ── Arguments ────────────────────────────────────────────────────────────
    use_rviz_arg = DeclareLaunchArgument(
        "use_rviz",
        default_value="true",
        description="Launch RViz2 for visualisation and goal setting",
    )
    use_rviz = LaunchConfiguration("use_rviz")

    params_file = "/nav2_config/nav2_params.yaml"
    rviz_config = "/nav2_config/g1_nav.rviz"

    # ── 1. Depth image → LaserScan ────────────────────────────────────────────
    depth_to_scan = Node(
        package="depthimage_to_laserscan",
        executable="depthimage_to_laserscan_node",
        name="depth_to_scan",
        output="screen",
        parameters=["/nav2_config/depth_to_scan.yaml", {"use_sim_time": True}],
        remappings=[
            # Input: depth image from Isaac Lab sim bridge / real D435i driver
            ("image",       "/depth/image_raw"),
            ("camera_info", "/depth/camera_info"),
            # Output: LaserScan consumed by SLAM Toolbox
            ("scan",        "/scan"),
        ],
    )

    # ── 2. SLAM Toolbox (async, mapping mode) ─────────────────────────────────
    slam_toolbox = Node(
        package="slam_toolbox",
        executable="async_slam_toolbox_node",
        name="slam_toolbox",
        output="screen",
        parameters=[params_file, {"use_sim_time": True}],
    )

    # ── 3. Nav2 bringup — planner + controller + costmaps + BT navigator ─────
    nav2_bringup = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            PathJoinSubstitution(
                [FindPackageShare("nav2_bringup"), "launch", "navigation_launch.py"]
            )
        ),
        launch_arguments={
            "params_file": params_file,
            "use_sim_time": "true",
            "use_lifecycle_mgr": "true",
            "autostart": "true",
        }.items(),
    )

    # ── 4. RViz2 ─────────────────────────────────────────────────────────────
    rviz2 = Node(
        package="rviz2",
        executable="rviz2",
        name="rviz2",
        arguments=["-d", rviz_config],
        output="screen",
        condition=IfCondition(use_rviz),
    )

    # ── Static TF: map → odom is provided by SLAM Toolbox.
    #    We still need odom → base_link (from Isaac Lab sim bridge).
    #    This transform is published by g1_locomotion_ros2.py directly.

    return LaunchDescription(
        [
            use_rviz_arg,
            LogInfo(msg="Starting G1 Nav2 stack…"),
            depth_to_scan,
            slam_toolbox,
            nav2_bringup,
            rviz2,
        ]
    )
