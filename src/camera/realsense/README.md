# Piper RealSense ROS1 Wrapper

`piper_realsense` is a lightweight bringup package for Intel RealSense cameras in the top-level `/home/test/piper` catkin workspace.

It does not vendor `realsense2_camera`. Instead, it wraps the system-installed ROS1 package and standardizes:

- a single launch entrypoint
- a fixed-mount static TF option
- a `depth_registered/points` topic alias that matches the existing Orbbec convention in this repo

The RealSense driver defaults come from `config/generic_rgbd.yaml`. Launch arguments and the wrapper script can selectively override those defaults when needed.

## Prerequisites

- Ubuntu 20.04 + ROS Noetic
- `realsense2_camera` already installed under `/opt/ros/noetic`
- The top-level workspace built at least once:

```bash
cd /home/test/piper
source /opt/ros/noetic/setup.bash
catkin_make
```

## Main entrypoints

Direct ROS launch:

```bash
source /opt/ros/noetic/setup.bash
source /home/test/piper/devel/setup.bash
roslaunch piper_realsense realsense_bringup.launch
```

Recommended wrapper script:

```bash
bash /home/test/piper/scripts/launch_realsense.sh
```

Supported environment overrides:

- `CAMERA_NAME`
- `SERIAL_NO`
- `ENABLE_POINTCLOUD`
- `PUBLISH_MOUNT_TF`
- `MOUNT_PARENT_FRAME`
- `MOUNT_XYZ`
- `MOUNT_RPY`

Example: bring up a fixed camera under `/front_camera`

```bash
CAMERA_NAME=front_camera \
PUBLISH_MOUNT_TF=true \
MOUNT_PARENT_FRAME=world \
MOUNT_XYZ="0.50 0.10 1.20" \
MOUNT_RPY="0.00 0.00 1.57" \
bash /home/test/piper/scripts/launch_realsense.sh
```

## Topics

Default topics for `camera_name:=camera`:

- `/camera/color/image_raw`
- `/camera/depth/image_rect_raw`
- `/camera/depth/color/points`
- `/camera/depth_registered/points`

The last topic is provided by a `topic_tools/relay` wrapper so downstream code can share the same point cloud name as the existing Orbbec package.

## TF

When `publish_mount_tf:=true`, the wrapper publishes:

- `mount_parent_frame -> <camera_name>_link`

The RealSense driver continues to publish the internal camera frame tree below `<camera_name>_link`.

`MOUNT_RPY` uses `roll pitch yaw` order in radians in this wrapper. The launch file converts it to the `yaw pitch roll` order expected by ROS static TF tooling.

## Verification

After startup:

```bash
rostopic list | grep '^/camera/'
rosrun tf tf_echo world camera_link
```

If you use a different `CAMERA_NAME`, replace `camera` in the commands above.

## Troubleshooting

- If startup fails with `RS2_USB_STATUS_ACCESS` or `failed to open usb interface`, fix RealSense USB permissions and udev rules first.
- If startup fails with `requested device ... is NOT found`, check the cable, USB port, and `SERIAL_NO`.
