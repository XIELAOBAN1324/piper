#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import bisect
import json
import math
import sys
import traceback
from pathlib import Path

h5py = None
np = None
rosbag = None
CvBridge = None


ACTION_FORMAT = [
    "timestamp_sec",
    "slave_joint_1_deg",
    "slave_joint_2_deg",
    "slave_joint_3_deg",
    "slave_joint_4_deg",
    "slave_joint_5_deg",
    "slave_joint_6_deg",
    "slave_ee_x_mm",
    "slave_ee_y_mm",
    "slave_ee_z_mm",
    "slave_ee_rx_deg",
    "slave_ee_ry_deg",
    "slave_ee_rz_deg",
    "slave_gripper_mm",
]


DEFAULT_OUTPUT_NAME = "episode.hdf5"

TOPIC_ARG_SPECS = [
    (
        "global_rgb_topic",
        "--global-rgb-topic",
        "/camera/color/image_raw",
        ("cameras", "global_camera", "rgb_topic"),
    ),
    (
        "global_depth_topic",
        "--global-depth-topic",
        "/camera/depth/image_raw",
        ("cameras", "global_camera", "depth_topic"),
    ),
    (
        "wrist_rgb_topic",
        "--wrist-rgb-topic",
        "/d405/color/image_raw",
        ("cameras", "wrist_camera", "rgb_topic"),
    ),
    (
        "wrist_depth_topic",
        "--wrist-depth-topic",
        "/d405/depth/image_rect_raw",
        ("cameras", "wrist_camera", "depth_topic"),
    ),
    (
        "global_points_topic",
        "--global-points-topic",
        "/camera/depth/points",
        ("cameras", "global_camera", "pointcloud_topic"),
    ),
    (
        "wrist_points_topic",
        "--wrist-points-topic",
        "/d405/depth/points",
        ("cameras", "wrist_camera", "pointcloud_topic"),
    ),
]


def parse_args():
    argv = sys.argv[1:]
    parser = argparse.ArgumentParser(
        description=(
            "Convert Piper teleoperation raw.bag into synchronized HDF5 episode. "
            "Supports single-bag mode and dataset-root batch mode."
        )
    )

    # 单文件模式：保持原来的 --bag --out 用法。
    parser.add_argument("--bag", default=None, help="Input raw.bag path for single-file mode.")
    parser.add_argument("--out", default=None, help="Output episode.hdf5 path for single-file mode.")

    # 批处理模式：新增功能。
    parser.add_argument(
        "--data-root",
        default=None,
        help=(
            "Dataset root to scan recursively. The script will find all raw.bag files "
            "and convert unprocessed ones."
        ),
    )
    parser.add_argument(
        "--output-name",
        default=DEFAULT_OUTPUT_NAME,
        help="Output HDF5 file name used in batch mode. Default: episode.hdf5.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing output HDF5 files in batch mode or single-file mode.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Only list what would be converted in batch mode, without writing files.",
    )
    parser.add_argument(
        "--batch-report-name",
        default="batch_convert_report.json",
        help="Batch summary JSON name written under data-root. Default: batch_convert_report.json.",
    )

    for attr, flag, default, _ in TOPIC_ARG_SPECS:
        parser.add_argument(flag, dest=attr, default=default)

    parser.add_argument("--action-topic", default="/piper_dataset/slave_pose_action")
    parser.add_argument("--target-hz", type=float, default=30.0)
    parser.add_argument("--max-dt-ms", type=float, default=35.0)
    parser.add_argument("--save-pointcloud-placeholder", action="store_true")
    args = parser.parse_args()
    args._explicit_topic_args = detect_explicit_topic_args(argv)
    return args


def detect_explicit_topic_args(argv):
    explicit = set()
    for attr, flag, _, _ in TOPIC_ARG_SPECS:
        flag_with_value = "{}=".format(flag)
        for token in argv:
            if token == flag or token.startswith(flag_with_value):
                explicit.add(attr)
                break
    return explicit


def log(message):
    print("[bag_to_piper_hdf5] {}".format(message))


def warn(message):
    print("[bag_to_piper_hdf5][warn] {}".format(message), file=sys.stderr)


def die(message):
    print("[bag_to_piper_hdf5][error] {}".format(message), file=sys.stderr)
    raise SystemExit(1)


def infer_episode_dir(bag_path):
    if bag_path.name == "raw.bag" and bag_path.parent.name == "raw":
        return bag_path.parent.parent
    return bag_path.parent


def infer_episode_meta_path(bag_path):
    return infer_episode_dir(bag_path) / "episode_meta.yaml"


def parse_scalar_yaml_value(value):
    value = value.strip()
    if not value:
        return ""
    if value[0:1] == '"' and value[-1:] == '"':
        return value[1:-1]
    if value[0:1] == "'" and value[-1:] == "'":
        return value[1:-1]
    return value


def load_simple_episode_meta_yaml(meta_path):
    root = {}
    stack = [(-1, root)]
    with meta_path.open("r", encoding="utf-8") as meta_file:
        for raw_line in meta_file:
            line = raw_line.rstrip("\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or stripped.startswith("- "):
                continue
            if ":" not in stripped:
                continue

            key, value = stripped.split(":", 1)
            key = key.strip()
            value = value.strip()
            indent = len(line) - len(line.lstrip(" "))

            while stack and indent <= stack[-1][0]:
                stack.pop()
            parent = stack[-1][1]

            if value == "":
                child = {}
                parent[key] = child
                stack.append((indent, child))
            else:
                parent[key] = parse_scalar_yaml_value(value)
    return root


def load_episode_meta(meta_path):
    try:
        import yaml
    except ImportError:
        return load_simple_episode_meta_yaml(meta_path)

    with meta_path.open("r", encoding="utf-8") as meta_file:
        loaded = yaml.safe_load(meta_file) or {}
    if not isinstance(loaded, dict):
        return {}
    return loaded


def nested_get(mapping, path):
    current = mapping
    for key in path:
        if not isinstance(current, dict) or key not in current:
            return None
        current = current[key]
    return current


def clone_args_with_episode_topics(args, bag_path):
    episode_args = argparse.Namespace(**vars(args))
    meta_path = infer_episode_meta_path(bag_path)
    episode_args._episode_meta_path = str(meta_path)
    episode_args._episode_meta_loaded = False
    episode_args._episode_meta_topic_overrides = {}

    if not meta_path.is_file():
        return episode_args

    try:
        metadata = load_episode_meta(meta_path)
    except Exception as exc:
        warn("Failed to read episode metadata {}: {}. Using command-line/default topics.".format(meta_path, exc))
        return episode_args

    explicit_topic_args = getattr(args, "_explicit_topic_args", set())
    for attr, _, _, metadata_path in TOPIC_ARG_SPECS:
        if attr in explicit_topic_args:
            continue
        value = nested_get(metadata, metadata_path)
        if value is None or value == "":
            continue
        value = str(value)
        setattr(episode_args, attr, value)
        episode_args._episode_meta_topic_overrides[attr] = value

    episode_args._episode_meta_loaded = True
    return episode_args


def load_runtime_dependencies():
    global h5py, np, rosbag, CvBridge
    try:
        import h5py as h5py_module
        import numpy as np_module
        import rosbag as rosbag_module
        from cv_bridge import CvBridge as CvBridgeClass
    except ImportError as exc:
        print(
            "[bag_to_piper_hdf5][error] Missing dependency: {}. "
            "Source ROS Noetic and the workspace setup before running this script.".format(exc),
            file=sys.stderr,
        )
        raise SystemExit(2)

    h5py = h5py_module
    np = np_module
    rosbag = rosbag_module
    CvBridge = CvBridgeClass


def validate_common_args(args):
    if args.target_hz <= 0:
        die("--target-hz must be greater than 0.")
    if args.max_dt_ms < 0:
        die("--max-dt-ms must be greater than or equal to 0.")
    if not args.output_name.endswith((".hdf5", ".h5")):
        die("--output-name must end with .hdf5 or .h5, got: {}".format(args.output_name))


def validate_single_args(args):
    if args.bag is None or args.out is None:
        die("Single-file mode requires both --bag and --out. Batch mode requires --data-root.")

    bag_path = Path(args.bag)
    out_path = Path(args.out)

    if not bag_path.is_file():
        die("Input bag does not exist: {}".format(bag_path))
    if out_path.suffix.lower() not in [".hdf5", ".h5"]:
        die("--out must end with .hdf5 or .h5, got: {}".format(out_path))
    if out_path.exists() and not args.force:
        die("Output already exists: {}. Use --force to overwrite.".format(out_path))

    return bag_path, out_path


def validate_batch_args(args):
    data_root = Path(args.data_root)
    if not data_root.is_dir():
        die("--data-root does not exist or is not a directory: {}".format(data_root))
    return data_root


def ros_time_to_sec(stamp):
    try:
        return float(stamp.to_sec())
    except Exception:
        return float(stamp)


def message_time_sec(msg, bag_time):
    stamp = None
    header = getattr(msg, "header", None)
    if header is not None:
        stamp = getattr(header, "stamp", None)
    if stamp is not None:
        try:
            stamp_sec = ros_time_to_sec(stamp)
            if stamp_sec > 0:
                return stamp_sec
        except Exception:
            pass
    return ros_time_to_sec(bag_time)


def read_bag(args, bag_path):
    action_topic = args.action_topic
    image_topics = {
        args.global_rgb_topic: "global_rgb",
        args.global_depth_topic: "global_depth",
        args.wrist_rgb_topic: "wrist_rgb",
        args.wrist_depth_topic: "wrist_depth",
    }
    topics = sorted(set([action_topic] + list(image_topics.keys())))

    actions = []
    images = {name: [] for name in image_topics.values()}
    skipped_actions = 0

    try:
        with rosbag.Bag(str(bag_path), "r") as bag:
            for topic, msg, bag_time in bag.read_messages(topics=topics):
                if topic == action_topic:
                    data = list(getattr(msg, "data", []))
                    if len(data) < len(ACTION_FORMAT):
                        skipped_actions += 1
                        continue
                    try:
                        timestamp_sec = float(data[0])
                        if not math.isfinite(timestamp_sec) or timestamp_sec <= 0:
                            timestamp_sec = ros_time_to_sec(bag_time)
                        action = np.asarray(data[1:14], dtype=np.float64)
                    except Exception:
                        skipped_actions += 1
                        continue
                    if action.shape != (13,):
                        skipped_actions += 1
                        continue
                    actions.append((timestamp_sec, action))
                elif topic in image_topics:
                    name = image_topics[topic]
                    images[name].append((message_time_sec(msg, bag_time), msg))
    except rosbag.ROSBagException as exc:
        die("Failed to read bag {}: {}".format(bag_path, exc))

    if skipped_actions:
        warn("Skipped {} malformed action messages in {}.".format(skipped_actions, bag_path))

    actions.sort(key=lambda item: item[0])
    for frames in images.values():
        frames.sort(key=lambda item: item[0])
    return actions, images


def require_streams(actions, images, topics):
    if not actions:
        die("No valid action messages found on {}.".format(topics["action"]))
    for name, frames in images.items():
        if not frames:
            die("No image messages found for {} on {}.".format(name, topics[name]))


def nearest_index(times, target):
    pos = bisect.bisect_left(times, target)
    if pos == 0:
        return 0
    if pos >= len(times):
        return len(times) - 1
    before = pos - 1
    after = pos
    if abs(times[after] - target) < abs(target - times[before]):
        return after
    return before


def convert_rgb(bridge, msg, label):
    try:
        image = bridge.imgmsg_to_cv2(msg, desired_encoding="rgb8")
    except Exception as exc:
        die("Failed to convert {} as rgb8: {}".format(label, exc))
    array = np.asarray(image)
    if array.ndim != 3 or array.shape[2] != 3:
        die("{} must convert to an HxWx3 RGB image, got shape {}.".format(label, array.shape))
    if array.dtype != np.uint8:
        array = array.astype(np.uint8)
    return array


def convert_depth(bridge, msg, label):
    try:
        image = bridge.imgmsg_to_cv2(msg, desired_encoding="passthrough")
    except Exception as exc:
        die("Failed to convert {} depth image: {}".format(label, exc))
    array = np.asarray(image)
    if array.ndim == 3 and array.shape[2] == 1:
        array = array[:, :, 0]
    if array.ndim != 2:
        die("{} must convert to an HxW depth image, got shape {}.".format(label, array.shape))
    return array


def infer_sync_report_path(out_path):
    if out_path.parent.name == "processed":
        return out_path.parent.parent / "sync_report.json"
    return out_path.parent / "sync_report.json"


def ensure_dataset_shape(array, expected_shape, expected_dtype, label):
    if array.shape != expected_shape:
        die("{} image shape changed from {} to {}.".format(label, expected_shape, array.shape))
    if array.dtype != expected_dtype:
        die("{} image dtype changed from {} to {}.".format(label, expected_dtype, array.dtype))


def create_image_dataset(group, name, frame_count, sample):
    return group.create_dataset(
        name,
        shape=(frame_count,) + sample.shape,
        dtype=sample.dtype,
    )


def write_hdf5(args, out_path, actions, images):
    bridge = CvBridge()
    frame_times = np.asarray([timestamp for timestamp, _ in actions], dtype=np.float64)
    action_values = np.asarray([action for _, action in actions], dtype=np.float64)
    frame_count = len(frame_times)

    stream_times = {
        name: np.asarray([timestamp for timestamp, _ in frames], dtype=np.float64)
        for name, frames in images.items()
    }

    nearest = {"action": np.arange(frame_count, dtype=np.int64)}
    dt_ms = {"action": np.zeros(frame_count, dtype=np.float64)}
    for name, times in stream_times.items():
        indices = np.asarray([nearest_index(times, target) for target in frame_times], dtype=np.int64)
        nearest[name] = indices
        dt_ms[name] = np.abs(times[indices] - frame_times) * 1000.0

    valid = (
        (dt_ms["action"] <= args.max_dt_ms)
        & (dt_ms["global_rgb"] <= args.max_dt_ms)
        & (dt_ms["global_depth"] <= args.max_dt_ms)
        & (dt_ms["wrist_rgb"] <= args.max_dt_ms)
        & (dt_ms["wrist_depth"] <= args.max_dt_ms)
    )

    samples = {
        "global_rgb": convert_rgb(bridge, images["global_rgb"][nearest["global_rgb"][0]][1], "global_rgb"),
        "global_depth": convert_depth(
            bridge,
            images["global_depth"][nearest["global_depth"][0]][1],
            "global_depth",
        ),
        "wrist_rgb": convert_rgb(bridge, images["wrist_rgb"][nearest["wrist_rgb"][0]][1], "wrist_rgb"),
        "wrist_depth": convert_depth(
            bridge,
            images["wrist_depth"][nearest["wrist_depth"][0]][1],
            "wrist_depth",
        ),
    }

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with h5py.File(str(out_path), "w") as h5:
        h5.attrs["action_source"] = "slave_feedback_pose"
        h5.attrs["sync_method"] = "software_timestamp_nearest"
        h5.attrs["target_hz"] = float(args.target_hz)
        h5.attrs["max_dt_ms"] = float(args.max_dt_ms)
        h5.attrs["global_camera_depth_format"] = "Y16"
        h5.attrs["global_pointcloud_topic"] = args.global_points_topic
        h5.attrs["wrist_pointcloud_topic"] = args.wrist_points_topic
        h5.attrs["pointcloud_saved_in_hdf5"] = False
        h5.attrs["pointcloud_raw_bag_only"] = True
        h5.attrs.create(
            "action_format",
            np.asarray(ACTION_FORMAT[1:], dtype=object),
            dtype=h5py.string_dtype("utf-8"),
        )

        h5.require_group("timestamps").create_dataset("frame_timestamp_sec", data=frame_times)
        h5.require_group("actions").create_dataset("slave_pose", data=action_values)

        image_group = h5.require_group("observations").require_group("images")
        ds_global_rgb = create_image_dataset(image_group, "global_rgb", frame_count, samples["global_rgb"])
        ds_global_depth = create_image_dataset(image_group, "global_depth", frame_count, samples["global_depth"])
        ds_wrist_rgb = create_image_dataset(image_group, "wrist_rgb", frame_count, samples["wrist_rgb"])
        ds_wrist_depth = create_image_dataset(image_group, "wrist_depth", frame_count, samples["wrist_depth"])

        for i in range(frame_count):
            global_rgb = convert_rgb(bridge, images["global_rgb"][nearest["global_rgb"][i]][1], "global_rgb")
            global_depth = convert_depth(
                bridge,
                images["global_depth"][nearest["global_depth"][i]][1],
                "global_depth",
            )
            wrist_rgb = convert_rgb(bridge, images["wrist_rgb"][nearest["wrist_rgb"][i]][1], "wrist_rgb")
            wrist_depth = convert_depth(
                bridge,
                images["wrist_depth"][nearest["wrist_depth"][i]][1],
                "wrist_depth",
            )

            ensure_dataset_shape(global_rgb, samples["global_rgb"].shape, samples["global_rgb"].dtype, "global_rgb")
            ensure_dataset_shape(
                global_depth,
                samples["global_depth"].shape,
                samples["global_depth"].dtype,
                "global_depth",
            )
            ensure_dataset_shape(wrist_rgb, samples["wrist_rgb"].shape, samples["wrist_rgb"].dtype, "wrist_rgb")
            ensure_dataset_shape(
                wrist_depth,
                samples["wrist_depth"].shape,
                samples["wrist_depth"].dtype,
                "wrist_depth",
            )

            ds_global_rgb[i] = global_rgb
            ds_global_depth[i] = global_depth
            ds_wrist_rgb[i] = wrist_rgb
            ds_wrist_depth[i] = wrist_depth

        sync_group = h5.require_group("sync")
        sync_group.create_dataset("dt_action_ms", data=dt_ms["action"])
        sync_group.create_dataset("dt_global_rgb_ms", data=dt_ms["global_rgb"])
        sync_group.create_dataset("dt_global_depth_ms", data=dt_ms["global_depth"])
        sync_group.create_dataset("dt_wrist_rgb_ms", data=dt_ms["wrist_rgb"])
        sync_group.create_dataset("dt_wrist_depth_ms", data=dt_ms["wrist_depth"])
        sync_group.create_dataset("valid", data=valid)

        pointcloud_group = h5.require_group("observations").require_group("pointcloud")
        pointcloud_group.require_group("global")
        pointcloud_group.require_group("wrist")
        if args.save_pointcloud_placeholder:
            pointcloud_group.attrs["placeholder"] = True

    report = {
        "total_frames": int(frame_count),
        "valid_frames": int(np.count_nonzero(valid)),
        "invalid_frames": int(frame_count - np.count_nonzero(valid)),
        "valid_ratio": float(np.count_nonzero(valid) / float(frame_count)),
        "max_dt_ms": float(args.max_dt_ms),
        "mean_dt_action_ms": float(np.mean(dt_ms["action"])),
        "mean_dt_global_rgb_ms": float(np.mean(dt_ms["global_rgb"])),
        "mean_dt_global_depth_ms": float(np.mean(dt_ms["global_depth"])),
        "mean_dt_wrist_rgb_ms": float(np.mean(dt_ms["wrist_rgb"])),
        "mean_dt_wrist_depth_ms": float(np.mean(dt_ms["wrist_depth"])),
    }
    report_path = infer_sync_report_path(out_path)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open("w", encoding="utf-8") as report_file:
        json.dump(report, report_file, indent=2, sort_keys=True)
        report_file.write("\n")
    return report_path, report


def topic_map(args):
    return {
        "action": args.action_topic,
        "global_rgb": args.global_rgb_topic,
        "global_depth": args.global_depth_topic,
        "wrist_rgb": args.wrist_rgb_topic,
        "wrist_depth": args.wrist_depth_topic,
    }


def infer_batch_output_path(args, bag_path):
    """
    默认适配 record_dual_arm_dataset.sh 的目录：

        episode_xxx/raw/raw.bag
        episode_xxx/processed/episode.hdf5

    如果 raw.bag 不在 raw/ 目录下，则退化为：

        raw.bag 所在目录 / processed / episode.hdf5
    """
    if bag_path.name == "raw.bag" and bag_path.parent.name == "raw":
        return bag_path.parent.parent / "processed" / args.output_name
    return bag_path.parent / "processed" / args.output_name


def discover_raw_bags(data_root):
    return sorted(path for path in data_root.rglob("raw.bag") if path.is_file())


def convert_one(args, bag_path, out_path):
    if out_path.exists():
        if args.force:
            out_path.unlink()
        else:
            raise FileExistsError("Output already exists: {}".format(out_path))

    episode_args = clone_args_with_episode_topics(args, bag_path)
    topics = topic_map(episode_args)
    log("global depth topic: {}".format(episode_args.global_depth_topic))
    if episode_args._episode_meta_loaded:
        log("episode metadata: {}".format(episode_args._episode_meta_path))
    else:
        log("episode metadata: not found, using command-line/default topics")

    actions, images = read_bag(episode_args, bag_path)
    require_streams(actions, images, topics)
    report_path, report = write_hdf5(episode_args, out_path, actions, images)
    return report_path, report, episode_args


def run_single(args):
    bag_path, out_path = validate_single_args(args)
    report_path, report, episode_args = convert_one(args, bag_path, out_path)
    log("wrote HDF5: {}".format(out_path))
    log("wrote sync report: {}".format(report_path))
    log("used global depth topic: {}".format(episode_args.global_depth_topic))
    log(
        "valid frames: {}/{} ({:.2%})".format(
            report["valid_frames"],
            report["total_frames"],
            report["valid_ratio"],
        )
    )


def run_batch(args):
    data_root = validate_batch_args(args)
    raw_bags = discover_raw_bags(data_root)

    summary = {
        "data_root": str(data_root),
        "output_name": args.output_name,
        "force": bool(args.force),
        "dry_run": bool(args.dry_run),
        "total_raw_bag_found": len(raw_bags),
        "converted": 0,
        "skipped_existing": 0,
        "failed": 0,
        "items": [],
    }

    log("scan data root: {}".format(data_root))
    log("found raw.bag files: {}".format(len(raw_bags)))

    for index, bag_path in enumerate(raw_bags, start=1):
        out_path = infer_batch_output_path(args, bag_path)
        episode_args_for_plan = clone_args_with_episode_topics(args, bag_path)

        item = {
            "index": index,
            "bag": str(bag_path),
            "out": str(out_path),
            "status": None,
            "message": "",
            "episode_meta": episode_args_for_plan._episode_meta_path,
            "episode_meta_loaded": bool(episode_args_for_plan._episode_meta_loaded),
            "global_depth_topic": episode_args_for_plan.global_depth_topic,
        }

        if out_path.exists() and not args.force:
            item["status"] = "skipped_existing"
            item["message"] = "Output already exists."
            summary["skipped_existing"] += 1
            summary["items"].append(item)
            log(
                "[{}/{}] skip existing: {} | global depth topic: {}".format(
                    index,
                    len(raw_bags),
                    out_path,
                    episode_args_for_plan.global_depth_topic,
                )
            )
            continue

        if args.dry_run:
            item["status"] = "dry_run"
            item["message"] = "Would convert."
            summary["items"].append(item)
            log(
                "[{}/{}] would convert: {} -> {} | global depth topic: {}".format(
                    index,
                    len(raw_bags),
                    bag_path,
                    out_path,
                    episode_args_for_plan.global_depth_topic,
                )
            )
            continue

        log("[{}/{}] convert: {}".format(index, len(raw_bags), bag_path))
        try:
            report_path, report, episode_args = convert_one(args, bag_path, out_path)
            item["status"] = "converted"
            item["message"] = "OK"
            item["sync_report"] = str(report_path)
            item["episode_meta"] = episode_args._episode_meta_path
            item["episode_meta_loaded"] = bool(episode_args._episode_meta_loaded)
            item["global_depth_topic"] = episode_args.global_depth_topic
            item["total_frames"] = int(report["total_frames"])
            item["valid_frames"] = int(report["valid_frames"])
            item["valid_ratio"] = float(report["valid_ratio"])
            summary["converted"] += 1
            log(
                "[{}/{}] wrote: {} | valid {}/{} ({:.2%})".format(
                    index,
                    len(raw_bags),
                    out_path,
                    report["valid_frames"],
                    report["total_frames"],
                    report["valid_ratio"],
                )
            )
        except SystemExit as exc:
            item["status"] = "failed"
            item["message"] = "SystemExit({})".format(exc.code)
            item["traceback"] = traceback.format_exc()
            summary["failed"] += 1
            warn("[{}/{}] failed: {}".format(index, len(raw_bags), bag_path))
        except Exception as exc:
            item["status"] = "failed"
            item["message"] = "{}: {}".format(type(exc).__name__, exc)
            item["traceback"] = traceback.format_exc()
            summary["failed"] += 1
            warn("[{}/{}] failed: {} | {}".format(index, len(raw_bags), bag_path, exc))

        summary["items"].append(item)

    report_path = data_root / args.batch_report_name
    with report_path.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, sort_keys=True)
        f.write("\n")

    log("batch report: {}".format(report_path))
    log(
        "batch done: found={}, converted={}, skipped_existing={}, failed={}".format(
            summary["total_raw_bag_found"],
            summary["converted"],
            summary["skipped_existing"],
            summary["failed"],
        )
    )

    if summary["failed"] > 0:
        raise SystemExit(1)


def main():
    args = parse_args()
    validate_common_args(args)

    if args.data_root and (args.bag or args.out):
        die("Use either single-file mode (--bag --out) or batch mode (--data-root), not both.")

    if not args.data_root and not (args.bag and args.out):
        die("Please provide either --bag --out or --data-root.")

    if args.data_root:
        if not args.dry_run:
            load_runtime_dependencies()
        run_batch(args)
    else:
        load_runtime_dependencies()
        run_single(args)


if __name__ == "__main__":
    main()
