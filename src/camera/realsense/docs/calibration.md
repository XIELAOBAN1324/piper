# Fixed-Mount Calibration Notes

This package assumes a fixed external camera mount for the first phase. That means the wrapper only needs one extra transform:

- parent frame: `mount_parent_frame`
- child frame: `<camera_name>_link`

## Quick workflow

1. Start the camera without a mount TF and verify image/depth topics.
2. Measure an initial `xyz` and `rpy` guess from the workcell or robot base.
3. Relaunch with `publish_mount_tf:=true`.
4. Refine the numbers in RViz until the point cloud is aligned with the workcell.
5. Replace the hand-measured values later with calibrated extrinsics if needed.

## Parameter meaning

- `mount_xyz`: translation in meters, `x y z`
- `mount_rpy`: rotation in radians, `roll pitch yaw`

Example:

```bash
roslaunch piper_realsense realsense_bringup.launch \
  camera_name:=camera \
  publish_mount_tf:=true \
  mount_parent_frame:=world \
  mount_xyz:="0.50 0.10 1.20" \
  mount_rpy:="0.00 0.00 1.57"
```

## Validation

Check the frame is present:

```bash
rosrun tf tf_echo world camera_link
```

Visual validation in RViz:

- Fixed Frame: `world`
- PointCloud2 topic: `/camera/depth_registered/points`

If the point cloud orientation is wrong, double-check that `mount_rpy` is still being entered in `roll pitch yaw` order. The launch file converts it for ROS static TF tooling internally.
