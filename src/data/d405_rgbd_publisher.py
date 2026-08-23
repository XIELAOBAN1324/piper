#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import sys
import threading

import numpy as np
import rospy
from sensor_msgs.msg import Image, CameraInfo, PointCloud2, PointField
from std_msgs.msg import Header
from cv_bridge import CvBridge

try:
    import pyrealsense2 as rs
except ImportError as exc:
    print("[d405_rgbd_publisher][error] missing pyrealsense2:", exc, file=sys.stderr)
    raise


def parse_args():
    parser = argparse.ArgumentParser(description="Publish Intel RealSense D405 RGB-D as ROS topics.")
    parser.add_argument("--serial", default="", help="D405 serial number. Empty means first available device.")
    parser.add_argument("--camera-name", default="d405", help="ROS namespace prefix.")
    parser.add_argument("--color-width", type=int, default=640)
    parser.add_argument("--color-height", type=int, default=480)
    parser.add_argument("--depth-width", type=int, default=640)
    parser.add_argument("--depth-height", type=int, default=480)
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--enable-pointcloud", action="store_true")
    return parser.parse_args(rospy.myargv(argv=sys.argv)[1:])


def make_camera_info(width, height, intr, frame_id, stamp):
    msg = CameraInfo()
    msg.header.stamp = stamp
    msg.header.frame_id = frame_id
    msg.width = width
    msg.height = height

    msg.K = [
        intr.fx, 0.0, intr.ppx,
        0.0, intr.fy, intr.ppy,
        0.0, 0.0, 1.0,
    ]

    msg.P = [
        intr.fx, 0.0, intr.ppx, 0.0,
        0.0, intr.fy, intr.ppy, 0.0,
        0.0, 0.0, 1.0, 0.0,
    ]

    msg.R = [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
    ]

    if intr.model == rs.distortion.brown_conrady:
        msg.distortion_model = "plumb_bob"
    else:
        msg.distortion_model = "plumb_bob"

    msg.D = list(intr.coeffs)
    return msg


def make_pointcloud2(points_xyz, frame_id, stamp):
    """
    points_xyz: [N, 3] float32, unit: meter
    """
    points_xyz = np.asarray(points_xyz, dtype=np.float32)
    msg = PointCloud2()
    msg.header = Header(stamp=stamp, frame_id=frame_id)
    msg.height = 1
    msg.width = points_xyz.shape[0]
    msg.fields = [
        PointField(name="x", offset=0, datatype=PointField.FLOAT32, count=1),
        PointField(name="y", offset=4, datatype=PointField.FLOAT32, count=1),
        PointField(name="z", offset=8, datatype=PointField.FLOAT32, count=1),
    ]
    msg.is_bigendian = False
    msg.point_step = 12
    msg.row_step = msg.point_step * points_xyz.shape[0]
    msg.is_dense = False
    msg.data = points_xyz.tobytes()
    return msg


class D405Publisher:
    def __init__(self, args):
        self.args = args
        self.bridge = CvBridge()

        self.ns = "/" + args.camera_name.strip("/")
        self.color_frame_id = args.camera_name + "_color_optical_frame"
        self.depth_frame_id = args.camera_name + "_depth_optical_frame"

        self.color_pub = rospy.Publisher(
            self.ns + "/color/image_raw", Image, queue_size=2
        )
        self.depth_pub = rospy.Publisher(
            self.ns + "/depth/image_rect_raw", Image, queue_size=2
        )
        self.color_info_pub = rospy.Publisher(
            self.ns + "/color/camera_info", CameraInfo, queue_size=2
        )
        self.depth_info_pub = rospy.Publisher(
            self.ns + "/depth/camera_info", CameraInfo, queue_size=2
        )

        self.points_pub = None
        if args.enable_pointcloud:
            self.points_pub = rospy.Publisher(
                self.ns + "/depth/points", PointCloud2, queue_size=1
            )

        self.pipeline = rs.pipeline()
        self.config = rs.config()

        if args.serial:
            self.config.enable_device(args.serial)

        self.config.enable_stream(
            rs.stream.color,
            args.color_width,
            args.color_height,
            rs.format.rgb8,
            args.fps,
        )
        self.config.enable_stream(
            rs.stream.depth,
            args.depth_width,
            args.depth_height,
            rs.format.z16,
            args.fps,
        )

        self.align = rs.align(rs.stream.color)
        self.pc = rs.pointcloud() if args.enable_pointcloud else None

        self.profile = None
        self.running = False
        self.lock = threading.Lock()

    def start(self):
        self.profile = self.pipeline.start(self.config)
        self.running = True

        color_stream = self.profile.get_stream(rs.stream.color).as_video_stream_profile()
        depth_stream = self.profile.get_stream(rs.stream.depth).as_video_stream_profile()

        self.color_intr = color_stream.get_intrinsics()
        self.depth_intr = depth_stream.get_intrinsics()

        rospy.loginfo("[d405] started.")
        rospy.loginfo("[d405] publishing color: %s/color/image_raw", self.ns)
        rospy.loginfo("[d405] publishing depth: %s/depth/image_rect_raw", self.ns)
        if self.points_pub is not None:
            rospy.loginfo("[d405] publishing pointcloud: %s/depth/points", self.ns)

    def stop(self):
        with self.lock:
            if self.running:
                self.running = False
                self.pipeline.stop()

    def spin(self):
        rate = rospy.Rate(self.args.fps)

        while not rospy.is_shutdown():
            try:
                frames = self.pipeline.wait_for_frames(timeout_ms=1000)
                aligned = self.align.process(frames)

                color_frame = aligned.get_color_frame()
                depth_frame = aligned.get_depth_frame()

                if not color_frame or not depth_frame:
                    rospy.logwarn_throttle(2.0, "[d405] missing color or depth frame.")
                    continue

                stamp = rospy.Time.now()

                color_np = np.asanyarray(color_frame.get_data())
                depth_np = np.asanyarray(depth_frame.get_data())

                color_msg = self.bridge.cv2_to_imgmsg(color_np, encoding="rgb8")
                color_msg.header.stamp = stamp
                color_msg.header.frame_id = self.color_frame_id

                depth_msg = self.bridge.cv2_to_imgmsg(depth_np, encoding="16UC1")
                depth_msg.header.stamp = stamp
                depth_msg.header.frame_id = self.depth_frame_id

                self.color_pub.publish(color_msg)
                self.depth_pub.publish(depth_msg)

                self.color_info_pub.publish(
                    make_camera_info(
                        self.args.color_width,
                        self.args.color_height,
                        self.color_intr,
                        self.color_frame_id,
                        stamp,
                    )
                )

                self.depth_info_pub.publish(
                    make_camera_info(
                        self.args.depth_width,
                        self.args.depth_height,
                        self.depth_intr,
                        self.depth_frame_id,
                        stamp,
                    )
                )

                if self.points_pub is not None and self.points_pub.get_num_connections() > 0:
                    points = self.pc.calculate(depth_frame)
                    verts = np.asanyarray(points.get_vertices()).view(np.float32).reshape(-1, 3)
                    valid = np.isfinite(verts).all(axis=1) & (verts[:, 2] > 0)
                    verts = verts[valid]
                    self.points_pub.publish(
                        make_pointcloud2(verts, self.depth_frame_id, stamp)
                    )

                rate.sleep()

            except Exception as exc:
                rospy.logwarn_throttle(2.0, "[d405] frame loop error: %s", exc)


def main():
    rospy.init_node("d405_rgbd_publisher", anonymous=False)
    args = parse_args()

    node = D405Publisher(args)
    rospy.on_shutdown(node.stop)

    try:
        node.start()
        node.spin()
    finally:
        node.stop()


if __name__ == "__main__":
    main()