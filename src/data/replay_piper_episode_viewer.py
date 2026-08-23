#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Replay a Piper teleoperation episode.

Modes:
1. Offline viewer only: show recorded global/wrist RGB-D and recorded slave trajectory.
2. Live-camera comparison: additionally show current live Orbbec/D405 RGB-D while replaying.
3. Physical slave replay: optionally send recorded slave joint trajectory back to the slave arm.

Safety:
- The script never moves the robot unless --execute-robot is explicitly provided.
- Physical replay uses recorded slave joint feedback as the command source.
- Before moving, the script checks that current slave joints are close to the first recorded frame.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Optional, Tuple

import cv2
import h5py
import numpy as np


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Replay Piper episode HDF5. It can display recorded RGB-D, display live "
            "camera views during replay, and optionally execute the recorded slave trajectory."
        )
    )
    parser.add_argument("--hdf5", required=True, help="Path to episode.hdf5")
    parser.add_argument(
        "--speed",
        type=float,
        default=1.0,
        help="Replay speed multiplier. 1.0 means real time, 0.5 slower, 2.0 faster.",
    )
    parser.add_argument(
        "--fps",
        type=float,
        default=0.0,
        help="Force playback FPS. If <=0, use timestamps in HDF5.",
    )
    parser.add_argument("--width", type=int, default=320, help="Display width for each panel.")
    parser.add_argument("--height", type=int, default=240, help="Display height for each panel.")
    parser.add_argument("--start-index", type=int, default=0, help="Start frame index.")
    parser.add_argument("--end-index", type=int, default=-1, help="End frame index, -1 means until end.")
    parser.add_argument("--loop", action="store_true", help="Loop playback. Ignored when --execute-robot is used unless --allow-robot-loop is also set.")
    parser.add_argument(
        "--rgbd-only",
        "--images-only",
        dest="rgbd_only",
        action="store_true",
        help=(
            "Only show RGB-D image panels. Hide the frame/status panel, "
            "trajectory panels, and key-help panel. Works with or without --show-live-cameras."
        ),
    )

    # Live camera display.
    parser.add_argument(
        "--show-live-cameras",
        action="store_true",
        help="Subscribe to live ROS camera topics and show replay-process camera views.",
    )
    parser.add_argument("--global-camera-type", choices=("orbbec", "d435i", "custom"), default="orbbec")
    parser.add_argument("--live-global-rgb-topic", default="")
    parser.add_argument("--live-global-depth-topic", default="")
    parser.add_argument("--live-wrist-rgb-topic", default="/d405/color/image_raw")
    parser.add_argument("--live-wrist-depth-topic", default="/d405/depth/image_rect_raw")

    # Video recording.
    parser.add_argument("--record-video", action="store_true", help="Record the final stitched viewer canvas to a video file.")
    parser.add_argument("--video-dir", default="", help="Directory for recorded videos. Defaults to <repo>/video when empty.")
    parser.add_argument("--video-path", default="", help="Full output video path. Overrides --video-dir auto naming when set.")
    parser.add_argument("--video-fps", type=float, default=30.0, help="Output video FPS.")
    parser.add_argument(
        "--video-codec",
        default="h264",
        help=(
            "Video codec. Default h264 writes VSCode-friendly H.264 MP4 through ffmpeg when available. "
            "You can still pass OpenCV fourcc values such as mp4v, avc1, or MJPG."
        ),
    )
    parser.add_argument(
        "--video-backend",
        choices=("auto", "ffmpeg", "opencv"),
        default="auto",
        help="Video writing backend. auto prefers ffmpeg for H.264 MP4 and falls back to OpenCV.",
    )
    parser.add_argument("--video-crf", type=int, default=23, help="H.264 quality for ffmpeg backend, lower is higher quality.")
    parser.add_argument("--video-preset", default="veryfast", help="H.264 preset for ffmpeg backend.")

    # Physical robot replay.
    parser.add_argument(
        "--execute-robot",
        action="store_true",
        help="DANGEROUS: send recorded slave joint trajectory to the physical slave arm.",
    )
    parser.add_argument("--slave-can", default="can_piper_right", help="Slave arm CAN interface.")
    parser.add_argument("--repo-root", default="", help="Repository root. Auto-detected from script path when empty.")
    parser.add_argument("--robot-speed", type=int, default=30, help="Piper 0x151 speed percentage for MOVE_J, range 0-100.")
    parser.add_argument("--auto-enable", action="store_true", help="Call EnableArm(7) before physical replay.")
    parser.add_argument("--set-move-j", action="store_true", help="Send CAN/MOVE_J mode before physical replay.")
    parser.add_argument("--replay-gripper", action="store_true", help="Also replay gripper position from slave_pose[12].")
    parser.add_argument("--gripper-effort", type=int, default=1000, help="Gripper effort used when --replay-gripper is enabled.")
    parser.add_argument(
        "--go-home-on-exit",
        action="store_true",
        default=True,
        help="Go home when replay finishes or is interrupted. Enabled by default.",
    )
    parser.add_argument(
        "--no-go-home-on-exit",
        dest="go_home_on_exit",
        action="store_false",
        help="Disable automatic go-home on exit.",
    )
    parser.add_argument(
        "--start-tolerance-deg",
        type=float,
        default=15.0,
        help="Abort physical replay if any current joint differs from first recorded joint by more than this value.",
    )
    parser.add_argument(
        "--skip-start-check",
        action="store_true",
        help="Skip current-joint vs first-frame safety check. Use with caution.",
    )
    parser.add_argument(
        "--max-step-deg",
        type=float,
        default=8.0,
        help="Abort physical replay if adjacent recorded frames have a joint jump larger than this value.",
    )
    parser.add_argument(
        "--allow-large-jumps",
        action="store_true",
        help="Do not abort when recorded adjacent-frame joint jumps exceed --max-step-deg.",
    )
    parser.add_argument(
        "--allow-robot-loop",
        action="store_true",
        help="Allow looping while physically moving the robot. Default is disabled for safety.",
    )
    args = parser.parse_args()

    if args.global_camera_type == "orbbec":
        if not args.live_global_rgb_topic:
            args.live_global_rgb_topic = "/camera/color/image_raw"
        if not args.live_global_depth_topic:
            args.live_global_depth_topic = "/camera/depth/image_raw"
    elif args.global_camera_type == "d435i":
        if not args.live_global_rgb_topic:
            args.live_global_rgb_topic = "/camera/color/image_raw"
        if not args.live_global_depth_topic:
            args.live_global_depth_topic = "/camera/depth/image_rect_raw"
    elif args.global_camera_type == "custom":
        if not args.live_global_rgb_topic or not args.live_global_depth_topic:
            parser.error("--global-camera-type custom requires --live-global-rgb-topic and --live-global-depth-topic")

    return args


def repo_root_from_script(args) -> Path:
    if hasattr(args, "repo_root") and args.repo_root:
        return Path(args.repo_root).expanduser().resolve()
    return Path(__file__).resolve().parents[2]


def require_dataset(h5: h5py.File, name: str):
    if name not in h5:
        raise KeyError(f"Missing dataset: {name}")
    return h5[name]


def normalize_to_uint8(arr: np.ndarray) -> np.ndarray:
    arr = np.asarray(arr)
    if arr.dtype == np.uint8:
        return arr
    finite = np.isfinite(arr)
    if not np.any(finite):
        return np.zeros(arr.shape, dtype=np.uint8)
    valid = arr[finite]
    vmin = np.percentile(valid, 1)
    vmax = np.percentile(valid, 99)
    if vmax <= vmin:
        return np.zeros(arr.shape, dtype=np.uint8)
    out = (arr.astype(np.float32) - float(vmin)) / (float(vmax) - float(vmin))
    out = np.clip(out, 0.0, 1.0)
    return (out * 255.0).astype(np.uint8)


def depth_to_bgr(depth: np.ndarray) -> np.ndarray:
    depth = np.asarray(depth)
    finite = np.isfinite(depth)
    positive = depth > 0
    mask = finite & positive
    if not np.any(mask):
        gray = np.zeros(depth.shape[:2], dtype=np.uint8)
    else:
        valid = depth[mask].astype(np.float32)
        dmin = np.percentile(valid, 1)
        dmax = np.percentile(valid, 99)
        if dmax <= dmin:
            gray = np.zeros(depth.shape[:2], dtype=np.uint8)
        else:
            normalized = (depth.astype(np.float32) - float(dmin)) / (float(dmax) - float(dmin))
            normalized = np.clip(normalized, 0.0, 1.0)
            gray = (normalized * 255.0).astype(np.uint8)
            gray[~mask] = 0
    return cv2.applyColorMap(gray, cv2.COLORMAP_JET)


def to_bgr_image(img: np.ndarray, assume_rgb: bool = True) -> np.ndarray:
    img = np.asarray(img)
    if img.ndim == 2:
        # For HDF5 recorded depth, display as pseudo-color.
        return depth_to_bgr(img)
    if img.ndim == 3 and img.shape[2] == 1:
        return depth_to_bgr(img[:, :, 0])
    if img.ndim == 3 and img.shape[2] == 3:
        if img.dtype != np.uint8:
            img = normalize_to_uint8(img)
        if assume_rgb:
            return cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
        return img.copy()
    if img.ndim == 3 and img.shape[2] == 4:
        if img.dtype != np.uint8:
            img = normalize_to_uint8(img)
        return cv2.cvtColor(img, cv2.COLOR_RGBA2BGR)
    raise ValueError(f"Unsupported image shape: {img.shape}, dtype={img.dtype}")


def resize_panel(img: np.ndarray, width: int, height: int) -> np.ndarray:
    return cv2.resize(img, (width, height), interpolation=cv2.INTER_AREA)


def put_label(img: np.ndarray, text: str) -> np.ndarray:
    out = img.copy()
    cv2.rectangle(out, (0, 0), (out.shape[1], 30), (0, 0, 0), -1)
    cv2.putText(out, text, (8, 21), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1, cv2.LINE_AA)
    return out


def placeholder_panel(width: int, height: int, label: str, detail: str = "waiting") -> np.ndarray:
    panel = np.zeros((height, width, 3), dtype=np.uint8)
    panel = put_label(panel, label)
    cv2.putText(panel, detail, (15, height // 2), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (180, 180, 180), 1, cv2.LINE_AA)
    return panel


def make_text_panel(
    pose: np.ndarray,
    index: int,
    total: int,
    timestamp: float,
    width: int,
    height: int,
    execute_robot: bool,
    robot_status: str,
) -> np.ndarray:
    panel = np.zeros((height, width, 3), dtype=np.uint8)
    mode = "PHYSICAL ROBOT REPLAY" if execute_robot else "DRY-RUN VIEWER"
    lines = [
        f"Frame: {index + 1}/{total}",
        f"Time: {timestamp:.3f} s",
        f"Mode: {mode}",
        f"Robot: {robot_status}",
        "",
        "Slave joints deg:",
        f"J1 {pose[0]: .2f}  J2 {pose[1]: .2f}",
        f"J3 {pose[2]: .2f}  J4 {pose[3]: .2f}",
        f"J5 {pose[4]: .2f}  J6 {pose[5]: .2f}",
        "",
        "Slave EE pose:",
        f"x  {pose[6]: .2f} mm",
        f"y  {pose[7]: .2f} mm",
        f"z  {pose[8]: .2f} mm",
        f"rx {pose[9]: .2f} deg",
        f"ry {pose[10]: .2f} deg",
        f"rz {pose[11]: .2f} deg",
        f"gripper {pose[12]: .2f} mm",
    ]
    y = 23
    for line in lines:
        cv2.putText(panel, line, (10, y), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (255, 255, 255), 1, cv2.LINE_AA)
        y += 20
        if y > height - 5:
            break
    return panel


def make_trajectory_panel(actions: np.ndarray, current_index: int, width: int, height: int, axes: Tuple[int, int], title: str) -> np.ndarray:
    panel = np.zeros((height, width, 3), dtype=np.uint8)
    if actions.shape[0] == 0:
        return panel
    a, b = axes
    x = actions[:, a].astype(np.float32)
    y = actions[:, b].astype(np.float32)
    valid = np.isfinite(x) & np.isfinite(y)
    if not np.any(valid):
        return placeholder_panel(width, height, title, "No valid trajectory")

    xv = x[valid]
    yv = y[valid]
    xmin, xmax = float(np.min(xv)), float(np.max(xv))
    ymin, ymax = float(np.min(yv)), float(np.max(yv))
    if xmax <= xmin:
        xmax = xmin + 1.0
    if ymax <= ymin:
        ymax = ymin + 1.0

    margin = 30

    def map_point(px, py) -> Tuple[int, int]:
        u = margin + (px - xmin) / (xmax - xmin) * (width - 2 * margin)
        v = height - margin - (py - ymin) / (ymax - ymin) * (height - 2 * margin)
        return int(u), int(v)

    points = [map_point(float(x[i]), float(y[i])) for i in range(actions.shape[0]) if np.isfinite(x[i]) and np.isfinite(y[i])]
    for p1, p2 in zip(points[:-1], points[1:]):
        cv2.line(panel, p1, p2, (100, 100, 100), 1)

    current_index = max(0, min(current_index, actions.shape[0] - 1))
    passed = [map_point(float(x[i]), float(y[i])) for i in range(current_index + 1) if np.isfinite(x[i]) and np.isfinite(y[i])]
    for p1, p2 in zip(passed[:-1], passed[1:]):
        cv2.line(panel, p1, p2, (0, 255, 0), 2)
    if np.isfinite(x[current_index]) and np.isfinite(y[current_index]):
        cv2.circle(panel, map_point(float(x[current_index]), float(y[current_index])), 6, (0, 0, 255), -1)

    cv2.putText(panel, title, (10, 24), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1, cv2.LINE_AA)
    cv2.putText(panel, f"range x[{xmin:.1f},{xmax:.1f}] y[{ymin:.1f},{ymax:.1f}]", (10, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.38, (255, 255, 255), 1, cv2.LINE_AA)
    return panel


def compute_delay_sec(timestamps: np.ndarray, i: int, fps: float, speed: float) -> float:
    speed = max(speed, 1e-6)
    if fps > 0:
        return 1.0 / fps / speed
    if timestamps is None or len(timestamps) < 2 or i <= 0:
        return 0.0
    dt = float(timestamps[i] - timestamps[i - 1])
    if not np.isfinite(dt) or dt <= 0 or dt > 1.0:
        dt = 1.0 / 30.0
    return dt / speed


class VideoRecorder:
    def __init__(self, args):
        self.args = args
        self.writer = None
        self.ffmpeg_process = None
        self.output_path = None
        self.backend = ""
        self.codec_used = ""
        self.frame_size = None

    def _resolve_output_path(self) -> Path:
        repo_root = repo_root_from_script(self.args)
        if self.args.video_path:
            output_path = Path(self.args.video_path).expanduser()
            if not output_path.is_absolute():
                output_path = repo_root / output_path
            return output_path.resolve()

        if self.args.video_dir:
            output_dir = Path(self.args.video_dir).expanduser()
            if not output_dir.is_absolute():
                output_dir = repo_root / output_dir
        else:
            output_dir = repo_root / "video"
        stem = Path(self.args.hdf5).stem
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        return (output_dir / f"replay_{stem}_{timestamp}.mp4").resolve()

    @staticmethod
    def _even_sized_frame(canvas: np.ndarray) -> np.ndarray:
        """
        H.264 yuv420p needs even width/height. Default panel sizes are already even,
        but this keeps custom odd sizes safe.
        """
        if canvas.ndim != 3 or canvas.shape[2] != 3:
            raise RuntimeError(f"Video canvas must be a BGR image with 3 channels, got shape={canvas.shape}")

        height, width = canvas.shape[:2]
        pad_bottom = height % 2
        pad_right = width % 2
        if pad_bottom == 0 and pad_right == 0:
            return canvas
        return cv2.copyMakeBorder(
            canvas,
            0,
            pad_bottom,
            0,
            pad_right,
            borderType=cv2.BORDER_CONSTANT,
            value=(0, 0, 0),
        )

    def _open_ffmpeg(self, frame: np.ndarray, fps: float) -> bool:
        ffmpeg_path = shutil.which("ffmpeg")
        if not ffmpeg_path:
            return False

        height, width = frame.shape[:2]
        cmd = [
            ffmpeg_path,
            "-y",
            "-f",
            "rawvideo",
            "-vcodec",
            "rawvideo",
            "-pix_fmt",
            "bgr24",
            "-s",
            f"{width}x{height}",
            "-r",
            f"{fps}",
            "-i",
            "-",
            "-an",
            "-vcodec",
            "libx264",
            "-preset",
            str(self.args.video_preset),
            "-crf",
            str(int(self.args.video_crf)),
            "-pix_fmt",
            "yuv420p",
            "-movflags",
            "+faststart",
            str(self.output_path),
        ]

        self.ffmpeg_process = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self.backend = "ffmpeg"
        self.codec_used = "libx264"
        self.frame_size = (width, height)
        return True

    def _opencv_codec_candidates(self) -> list:
        codec = str(self.args.video_codec).strip()
        codec_lower = codec.lower()

        if codec_lower in ("auto", "h264", "libx264", "x264"):
            return ["avc1", "H264", "X264", "mp4v"]
        if len(codec) == 4:
            return [codec]
        return ["avc1", "H264", "X264", "mp4v"]

    def _open_opencv(self, frame: np.ndarray, fps: float) -> bool:
        height, width = frame.shape[:2]
        for codec in self._opencv_codec_candidates():
            fourcc = cv2.VideoWriter_fourcc(*codec)
            writer = cv2.VideoWriter(str(self.output_path), fourcc, fps, (width, height))
            if writer.isOpened():
                self.writer = writer
                self.backend = "opencv"
                self.codec_used = codec
                self.frame_size = (width, height)
                if codec.lower() == "mp4v":
                    print(
                        "[video][warn] OpenCV selected mp4v. Some VSCode builds cannot decode this codec. "
                        "Install ffmpeg and use the default h264 backend for best compatibility."
                    )
                return True
            writer.release()
        return False

    def open(self, canvas):
        if self.writer is not None or self.ffmpeg_process is not None:
            return

        fps = float(self.args.video_fps)
        if fps <= 0:
            raise RuntimeError(f"--video-fps must be > 0, got {self.args.video_fps}")

        frame = self._even_sized_frame(canvas)
        self.output_path = self._resolve_output_path()
        self.output_path.parent.mkdir(parents=True, exist_ok=True)

        codec_lower = str(self.args.video_codec).lower()
        prefer_ffmpeg = self.args.video_backend in ("auto", "ffmpeg") and codec_lower in (
            "auto",
            "h264",
            "libx264",
            "x264",
            "avc1",
        )

        opened = False
        if prefer_ffmpeg:
            opened = self._open_ffmpeg(frame, fps)
            if not opened and self.args.video_backend == "ffmpeg":
                raise RuntimeError(
                    "ffmpeg backend requested but ffmpeg was not found. Install ffmpeg or use --video-backend opencv."
                )
            if not opened:
                print(
                    "[video][warn] ffmpeg was not found; falling back to OpenCV VideoWriter. "
                    "The resulting MP4 may not be playable in VSCode."
                )

        if not opened:
            opened = self._open_opencv(frame, fps)

        if not opened:
            raise RuntimeError(f"Failed to open video writer: {self.output_path}")

        print("[video] recording enabled")
        print(f"[video] output: {self.output_path}")
        print(f"[video] fps: {fps}")
        print(f"[video] backend: {self.backend}")
        print(f"[video] codec: {self.codec_used}")

    def write(self, canvas):
        frame = self._even_sized_frame(canvas)
        if self.writer is None and self.ffmpeg_process is None:
            self.open(frame)

        if self.frame_size is not None:
            expected_width, expected_height = self.frame_size
            height, width = frame.shape[:2]
            if (width, height) != (expected_width, expected_height):
                frame = cv2.resize(frame, (expected_width, expected_height), interpolation=cv2.INTER_AREA)

        if self.ffmpeg_process is not None:
            if self.ffmpeg_process.stdin is None:
                raise RuntimeError("ffmpeg stdin is closed.")
            self.ffmpeg_process.stdin.write(frame.tobytes())
            return

        if self.writer is not None:
            self.writer.write(frame)

    def close(self):
        if self.ffmpeg_process is not None:
            if self.ffmpeg_process.stdin is not None:
                try:
                    self.ffmpeg_process.stdin.close()
                except BrokenPipeError:
                    pass
            return_code = self.ffmpeg_process.wait()
            self.ffmpeg_process = None
            if return_code != 0:
                print(f"[video][warn] ffmpeg exited with code {return_code}. Video may be incomplete.")
            print(f"[video] saved: {self.output_path}")
            return

        if self.writer is not None:
            self.writer.release()
            self.writer = None
            print(f"[video] saved: {self.output_path}")

class LiveImageBuffer:
    def __init__(self, topic: str, is_depth: bool):
        self.topic = topic
        self.is_depth = is_depth
        self.lock = threading.Lock()
        self.image_bgr: Optional[np.ndarray] = None
        self.stamp_sec: Optional[float] = None
        self.error: Optional[str] = None

    def callback(self, msg):
        try:
            import cv_bridge

            bridge = cv_bridge.CvBridge()
            arr = bridge.imgmsg_to_cv2(msg, desired_encoding="passthrough")
            if self.is_depth:
                bgr = depth_to_bgr(arr)
            else:
                if arr.ndim == 2:
                    bgr = cv2.cvtColor(normalize_to_uint8(arr), cv2.COLOR_GRAY2BGR)
                elif arr.ndim == 3 and arr.shape[2] == 3:
                    encoding = getattr(msg, "encoding", "").lower()
                    if encoding == "rgb8":
                        bgr = cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)
                    elif encoding == "bgr8":
                        bgr = arr.copy()
                    else:
                        # Most custom D405 publishers use rgb8. If unknown, assume RGB.
                        bgr = cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)
                elif arr.ndim == 3 and arr.shape[2] == 4:
                    bgr = cv2.cvtColor(arr, cv2.COLOR_RGBA2BGR)
                else:
                    raise ValueError(f"unsupported live image shape {arr.shape}")
            with self.lock:
                self.image_bgr = bgr
                self.stamp_sec = msg.header.stamp.to_sec() if getattr(msg, "header", None) is not None else time.time()
                self.error = None
        except Exception as exc:  # noqa: BLE001
            with self.lock:
                self.error = str(exc)

    def panel(self, width: int, height: int, label: str) -> np.ndarray:
        with self.lock:
            img = None if self.image_bgr is None else self.image_bgr.copy()
            stamp = self.stamp_sec
            err = self.error
        if img is None:
            detail = "waiting live frame"
            if err:
                detail = f"error: {err[:45]}"
            return placeholder_panel(width, height, label, detail)
        panel = resize_panel(img, width, height)
        age_text = ""
        if stamp is not None:
            age_text = f" age={max(0.0, time.time() - stamp):.2f}s"
        return put_label(panel, label + age_text)


class LiveCameraViewer:
    def __init__(self, args):
        try:
            import rospy
            from sensor_msgs.msg import Image
        except ImportError as exc:
            raise RuntimeError("ROS Python packages are required for --show-live-cameras. Source ROS Noetic first.") from exc

        self.rospy = rospy
        self.Image = Image
        if not rospy.core.is_initialized():
            rospy.init_node("piper_episode_replay_viewer", anonymous=True, disable_signals=True)

        self.global_rgb = LiveImageBuffer(args.live_global_rgb_topic, is_depth=False)
        self.global_depth = LiveImageBuffer(args.live_global_depth_topic, is_depth=True)
        self.wrist_rgb = LiveImageBuffer(args.live_wrist_rgb_topic, is_depth=False)
        self.wrist_depth = LiveImageBuffer(args.live_wrist_depth_topic, is_depth=True)

        self.subscribers = [
            rospy.Subscriber(args.live_global_rgb_topic, Image, self.global_rgb.callback, queue_size=1, buff_size=2**24),
            rospy.Subscriber(args.live_global_depth_topic, Image, self.global_depth.callback, queue_size=1, buff_size=2**24),
            rospy.Subscriber(args.live_wrist_rgb_topic, Image, self.wrist_rgb.callback, queue_size=1, buff_size=2**24),
            rospy.Subscriber(args.live_wrist_depth_topic, Image, self.wrist_depth.callback, queue_size=1, buff_size=2**24),
        ]

    def panels(self, width: int, height: int):
        return [
            self.global_rgb.panel(width, height, "LIVE Global RGB"),
            self.global_depth.panel(width, height, "LIVE Global Depth"),
            self.wrist_rgb.panel(width, height, "LIVE Wrist RGB"),
            self.wrist_depth.panel(width, height, "LIVE Wrist Depth"),
        ]


class PiperSlaveReplayer:
    CTRL_MODE_CAN = 0x01
    MOVE_J = 0x01
    MIT_DISABLED = 0x00

    def __init__(self, args):
        self.args = args
        self.interface = None
        self.status = "not connected"

        repo_root = Path(args.repo_root).expanduser().resolve() if args.repo_root else Path(__file__).resolve().parents[2]
        sdk_root = repo_root / "src" / "piper_sdk"
        if sdk_root.is_dir():
            sys.path.insert(0, str(sdk_root))
        try:
            from piper_sdk import C_PiperInterface_V2
        except ImportError as exc:
            raise RuntimeError(
                "Cannot import piper_sdk. Run from the piper repo or pass --repo-root /path/to/piper."
            ) from exc
        self.C_PiperInterface_V2 = C_PiperInterface_V2

    def connect(self):
        self.interface = self.C_PiperInterface_V2(can_name=self.args.slave_can)
        self.interface.ConnectPort(piper_init=False)
        time.sleep(0.2)
        self.status = f"connected {self.args.slave_can}"

    def close(self):
        if self.interface is not None:
            try:
                self.interface.DisconnectPort()
            except Exception:
                pass
            self.interface = None
            self.status = "disconnected"

    def enable_if_requested(self):
        if not self.args.auto_enable:
            return
        self.status = "enabling slave"
        deadline = time.time() + 5.0
        while time.time() <= deadline:
            self.interface.EnableArm(7)
            time.sleep(0.2)
            try:
                if all(self.interface.GetArmEnableStatus()):
                    self.status = "enabled"
                    return
            except Exception:
                pass
        self.status = "enable timeout"
        raise RuntimeError("Slave arm did not report all motors enabled within 5s.")

    def set_move_j_if_requested(self):
        if not self.args.set_move_j:
            return
        speed = int(max(0, min(100, self.args.robot_speed)))
        self.status = f"set MOVE_J speed={speed}"
        for _ in range(5):
            self.interface.MotionCtrl_2(self.CTRL_MODE_CAN, self.MOVE_J, speed, self.MIT_DISABLED)
            time.sleep(0.05)

    def read_current_joints_deg(self) -> Optional[np.ndarray]:
        try:
            wrapper = self.interface.GetArmJointMsgs()
            if wrapper.time_stamp <= 0:
                return None
            js = wrapper.joint_state
            raw = np.array(
                [js.joint_1, js.joint_2, js.joint_3, js.joint_4, js.joint_5, js.joint_6],
                dtype=np.float64,
            )
            return raw / 1000.0
        except Exception:
            return None

    def check_start_pose(self, first_pose: np.ndarray):
        if self.args.skip_start_check:
            self.status = "start check skipped"
            return
        current = self.read_current_joints_deg()
        if current is None:
            raise RuntimeError("Cannot read current slave joints for safety start check.")
        target = np.asarray(first_pose[:6], dtype=np.float64)
        diff = np.abs(current - target)
        max_diff = float(np.max(diff))
        if max_diff > self.args.start_tolerance_deg:
            raise RuntimeError(
                "Current slave joints are too far from first recorded frame. "
                f"max_diff={max_diff:.2f} deg, tolerance={self.args.start_tolerance_deg:.2f} deg. "
                "Move the slave near the first frame or use --skip-start-check with caution."
            )
        self.status = f"start check ok max={max_diff:.2f}deg"

    def send_pose(self, pose: np.ndarray):
        joints_raw = [int(round(float(v) * 1000.0)) for v in pose[:6]]
        self.interface.JointCtrl(*joints_raw)
        if self.args.replay_gripper and len(pose) >= 13 and np.isfinite(pose[12]):
            gripper_raw = int(round(abs(float(pose[12])) * 1000.0))
            self.interface.GripperCtrl(gripper_raw, int(self.args.gripper_effort), 0x01, 0x00)
        self.status = "sending joint trajectory"

    def go_home(self):
        """
        Return the physical slave arm to joint zero once when replay exits.

        This method is intentionally not called inside the --loop branch, so loop
        playback behavior remains unchanged. It is only called from main()'s
        finally block before DisconnectPort().
        """
        if self.interface is None:
            return

        self.status = "going home"
        print("[replay][home] returning slave arm and gripper to zero...")

        try:
            self.interface.EnableArm(7)
        except Exception as exc:  # noqa: BLE001
            print(f"[replay][home][warn] EnableArm(7) failed: {exc}")

        try:
            speed = int(max(0, min(100, self.args.robot_speed)))
            self.interface.MotionCtrl_2(self.CTRL_MODE_CAN, self.MOVE_J, speed, self.MIT_DISABLED)
            time.sleep(0.1)
        except Exception as exc:  # noqa: BLE001
            print(f"[replay][home][warn] set MOVE_J before homing failed: {exc}")

        duration_sec = 5.0
        rate_hz = 50.0
        interval_sec = 1.0 / rate_hz
        deadline = time.time() + duration_sec

        joint_count = 0
        gripper_count = 0
        joint_warned = False
        gripper_warned = False
        gripper_effort = int(self.args.gripper_effort)

        while time.time() < deadline:
            try:
                self.interface.JointCtrl(0, 0, 0, 0, 0, 0)
                joint_count += 1
            except Exception as exc:  # noqa: BLE001
                if not joint_warned:
                    print(f"[replay][home][warn] JointCtrl zero failed: {exc}")
                    joint_warned = True

            try:
                self.interface.GripperCtrl(0, gripper_effort, 0x01, 0x00)
                gripper_count += 1
            except Exception as exc:  # noqa: BLE001
                if not gripper_warned:
                    print(f"[replay][home][warn] GripperCtrl zero failed: {exc}")
                    gripper_warned = True

            time.sleep(interval_sec)

        self.status = "home done"
        print(
            "[replay][home] homing finished, "
            f"sent {joint_count} zero-joint commands and {gripper_count} zero-gripper commands."
        )


def validate_recorded_trajectory(actions: np.ndarray, start: int, end: int, max_step_deg: float, allow_large_jumps: bool):
    segment = np.asarray(actions[start:end, :6], dtype=np.float64)
    if segment.shape[0] < 2:
        return
    diffs = np.abs(np.diff(segment, axis=0))
    max_jump = float(np.nanmax(diffs))
    if max_jump > max_step_deg and not allow_large_jumps:
        raise RuntimeError(
            "Recorded trajectory contains a large adjacent-frame joint jump. "
            f"max_jump={max_jump:.2f} deg, threshold={max_step_deg:.2f} deg. "
            "Check the dataset or rerun with --allow-large-jumps."
        )


def build_canvas(
    recorded_panels,
    live_panels,
    text_panel,
    xy_panel,
    xz_panel,
    width: int,
    height: int,
    show_live_cameras: bool,
    rgbd_only: bool,
):
    if rgbd_only:
        if show_live_cameras:
            # RGB-D only with live comparison, 4 columns x 2 rows:
            # row 1: recorded global rgb/depth + live global rgb/depth
            # row 2: recorded wrist rgb/depth + live wrist rgb/depth
            row1 = np.hstack([recorded_panels[0], recorded_panels[1], live_panels[0], live_panels[1]])
            row2 = np.hstack([recorded_panels[2], recorded_panels[3], live_panels[2], live_panels[3]])
            return np.vstack([row1, row2])

        # RGB-D only without live camera placeholders, 4 columns x 1 row:
        # recorded global rgb/depth + recorded wrist rgb/depth
        return np.hstack(recorded_panels)

    help_panel = placeholder_panel(width, height, "Keys", "SPACE pause | a/d step | q quit")

    if show_live_cameras:
        # 4 columns x 3 rows:
        # row 1: recorded global rgb/depth + live global rgb/depth
        # row 2: recorded wrist rgb/depth + live wrist rgb/depth
        # row 3: info + XY trajectory + XZ trajectory + help
        row1 = np.hstack([recorded_panels[0], recorded_panels[1], live_panels[0], live_panels[1]])
        row2 = np.hstack([recorded_panels[2], recorded_panels[3], live_panels[2], live_panels[3]])
        row3 = np.hstack([text_panel, xy_panel, xz_panel, help_panel])
        return np.vstack([row1, row2, row3])

    # Offline layout without live camera placeholders:
    # 4 columns x 2 rows:
    # row 1: recorded global rgb/depth + recorded wrist rgb/depth
    # row 2: info + XY trajectory + XZ trajectory + help
    row1 = np.hstack(recorded_panels)
    row2 = np.hstack([text_panel, xy_panel, xz_panel, help_panel])
    return np.vstack([row1, row2])

def main():
    args = parse_args()
    if args.execute_robot and args.loop and not args.allow_robot_loop:
        print("[replay][warn] --loop ignored because --execute-robot is set. Use --allow-robot-loop to override.")
        args.loop = False
    if not os.path.exists(args.hdf5):
        raise FileNotFoundError(args.hdf5)

    live_viewer = LiveCameraViewer(args) if args.show_live_cameras else None
    video_recorder = VideoRecorder(args) if args.record_video else None
    robot = None

    with h5py.File(args.hdf5, "r") as h5:
        timestamps = require_dataset(h5, "/timestamps/frame_timestamp_sec")[:]
        actions = require_dataset(h5, "/actions/slave_pose")[:]
        global_rgb = require_dataset(h5, "/observations/images/global_rgb")
        global_depth = require_dataset(h5, "/observations/images/global_depth")
        wrist_rgb = require_dataset(h5, "/observations/images/wrist_rgb")
        wrist_depth = require_dataset(h5, "/observations/images/wrist_depth")

        total = min(
            len(timestamps),
            actions.shape[0],
            global_rgb.shape[0],
            global_depth.shape[0],
            wrist_rgb.shape[0],
            wrist_depth.shape[0],
        )
        if total <= 0:
            raise RuntimeError("No frames found in HDF5.")
        start = max(0, args.start_index)
        end = total if args.end_index < 0 else min(args.end_index, total)
        if start >= end:
            raise RuntimeError(f"Invalid frame range: start={start}, end={end}, total={total}")

        validate_recorded_trajectory(actions, start, end, args.max_step_deg, args.allow_large_jumps)

        if args.execute_robot:
            robot = PiperSlaveReplayer(args)
            robot.connect()
            robot.enable_if_requested()
            robot.set_move_j_if_requested()
            robot.check_start_pose(actions[start])

        print(f"[replay] file: {args.hdf5}")
        print(f"[replay] frames: {total}, range: {start} -> {end - 1}")
        print(f"[replay] live cameras: {args.show_live_cameras}")
        print(f"[replay] rgbd only layout: {args.rgbd_only}")
        print(f"[replay] execute robot: {args.execute_robot}")
        print("[replay] keys: q/ESC quit | SPACE pause/resume | a/d previous/next while paused")

        window_name = "Piper Episode Replay + Physical Replay Monitor"
        cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
        paused = False
        i = start

        try:
            while True:
                frame_start = time.time()
                pose = actions[i]
                ts = float(timestamps[i])

                if robot is not None and not paused:
                    robot.send_pose(pose)

                recorded_panels = [
                    put_label(resize_panel(to_bgr_image(global_rgb[i]), args.width, args.height), "REC Global RGB"),
                    put_label(resize_panel(to_bgr_image(global_depth[i]), args.width, args.height), "REC Global Depth"),
                    put_label(resize_panel(to_bgr_image(wrist_rgb[i]), args.width, args.height), "REC Wrist RGB"),
                    put_label(resize_panel(to_bgr_image(wrist_depth[i]), args.width, args.height), "REC Wrist Depth"),
                ]
                if live_viewer is not None:
                    live_panels = live_viewer.panels(args.width, args.height)
                else:
                    live_panels = []

                robot_status = robot.status if robot is not None else "dry-run"
                text_panel = make_text_panel(pose, i, total, ts, args.width, args.height, args.execute_robot, robot_status)
                xy_panel = make_trajectory_panel(actions, i, args.width, args.height, axes=(6, 7), title="Slave EE XY trajectory")
                xz_panel = make_trajectory_panel(actions, i, args.width, args.height, axes=(6, 8), title="Slave EE XZ trajectory")

                canvas = build_canvas(
                    recorded_panels,
                    live_panels,
                    text_panel,
                    xy_panel,
                    xz_panel,
                    args.width,
                    args.height,
                    args.show_live_cameras,
                    args.rgbd_only,
                )
                if video_recorder is not None:
                    video_recorder.write(canvas)
                cv2.imshow(window_name, canvas)

                if paused:
                    key = cv2.waitKey(0) & 0xFF
                else:
                    delay = compute_delay_sec(timestamps, i, args.fps, args.speed)
                    elapsed = time.time() - frame_start
                    wait_ms = max(1, int(max(0.0, delay - elapsed) * 1000.0))
                    key = cv2.waitKey(wait_ms) & 0xFF

                if key in (ord("q"), 27):
                    break
                if key == ord(" "):
                    paused = not paused
                elif paused and key == ord("a"):
                    i = max(start, i - 1)
                    continue
                elif paused and key == ord("d"):
                    i = min(end - 1, i + 1)
                    continue

                if not paused:
                    i += 1
                    if i >= end:
                        if args.loop:
                            i = start
                        else:
                            break
        finally:
            if video_recorder is not None:
                video_recorder.close()
            if robot is not None:
                if args.go_home_on_exit:
                    try:
                        robot.go_home()
                    except Exception as exc:  # noqa: BLE001
                        print(f"[replay][home][error] failed to go home on exit: {exc}")
                else:
                    print("[replay][home] automatic go-home disabled by --no-go-home-on-exit")
                robot.close()
            cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
