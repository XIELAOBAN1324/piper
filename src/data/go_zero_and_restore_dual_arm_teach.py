#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CAN zero + restore dual-arm teach mode for Piper master/slave teleoperation.

Use case:
  During continuous dataset collection, after one episode is stopped by Ctrl-C,
  call this script to drive the master arm to zero through CAN JointCtrl. The
  slave arm follows through the existing bridge/master-slave link. Then the
  script rewrites master/slave roles, sends ReqMasterArmMoveToHome(0) to restore
  master-slave mode, enables the slave arm, and verifies teach readiness.

Important:
  - Do NOT call /finish_teach_and_go_zero_srv between episodes.
  - Keep the prepare_dual_arm_teach.sh / bridge terminal alive.
  - Make sure the arm workspace is clear before running this script.
"""

from __future__ import annotations

import argparse
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional


def _insert_sdk_path() -> None:
    candidates = []
    try:
        repo_root = Path(__file__).resolve().parents[2]
        candidates.append(repo_root / "src" / "piper_sdk")
    except Exception:
        pass
    candidates.append(Path.home() / "piper" / "src" / "piper_sdk")

    for path in candidates:
        if path.is_dir():
            sys.path.insert(0, str(path))
            return


_insert_sdk_path()

try:
    from piper_sdk import C_PiperInterface_V2
except Exception as exc:  # pragma: no cover - runtime environment dependent
    print(
        "ERROR: failed to import piper_sdk. Put this script under ~/piper/src/data "
        "or make sure ~/piper/src/piper_sdk exists.",
        file=sys.stderr,
    )
    raise SystemExit(1) from exc


MASTER_ROLE = 0xFA
SLAVE_ROLE = 0xFC
CTRL_MODE_CAN = 0x01
MOVE_J = 0x01
MIT_DISABLED = 0x00
TEACH_CTRL_MODE = 0x06


@dataclass
class ArmSnapshot:
    name: str
    ctrl_mode: Optional[int] = None
    mode_feed: Optional[int] = None
    teach_status: Optional[int] = None
    motion_status: Optional[int] = None
    err_code: Optional[int] = None
    enable_status: Optional[List[bool]] = None
    joints_deg: Optional[List[float]] = None


def positive_float(value: str) -> float:
    try:
        parsed = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a number") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than 0")
    return parsed


def nonnegative_float(value: str) -> float:
    try:
        parsed = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a number") from exc
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be greater than or equal to 0")
    return parsed


def positive_int(value: str) -> int:
    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be an integer") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than 0")
    return parsed


def speed_value(value: str) -> int:
    parsed = positive_int(value)
    if parsed > 100:
        raise argparse.ArgumentTypeError("must be in range 1-100")
    return parsed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Drive Piper dual-arm master to zero by CAN, then restore master/slave teach mode.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--master-can", default="can_piper_left", help="Master/input arm CAN interface.")
    parser.add_argument("--slave-can", default="can_piper_right", help="Slave/output arm CAN interface.")

    parser.add_argument("--restore-only", action="store_true", help="Skip CAN zero and only restore teach mode.")
    parser.add_argument("--zero-speed", type=speed_value, default=20, help="MOVE_J speed percentage for zeroing.")
    parser.add_argument("--zero-duration", type=positive_float, default=5.0, help="How long to keep sending zero JointCtrl, in seconds.")
    parser.add_argument("--zero-rate-hz", type=positive_float, default=50.0, help="Zero command send frequency.")
    parser.add_argument(
        "--zero-slave-direct",
        action="store_true",
        help="Also send CAN zero commands directly to the slave. Default is master-only; slave follows via bridge.",
    )
    parser.add_argument(
        "--enable-master-before-zero",
        dest="enable_master_before_zero",
        action="store_true",
        default=True,
        help="Call master.EnableArm(7) before CAN zero. Enabled by default.",
    )
    parser.add_argument(
        "--no-enable-master-before-zero",
        dest="enable_master_before_zero",
        action="store_false",
        help="Do not call master.EnableArm(7) before CAN zero.",
    )

    parser.add_argument("--role-send-count", type=positive_int, default=8, help="MasterSlaveConfig send rounds.")
    parser.add_argument("--role-send-interval", type=positive_float, default=0.1, help="Interval between MasterSlaveConfig rounds.")
    parser.add_argument("--restore-request-count", type=positive_int, default=5, help="ReqMasterArmMoveToHome(0) send count.")
    parser.add_argument("--restore-request-interval", type=positive_float, default=0.2, help="Interval between ReqMasterArmMoveToHome(0) calls.")
    parser.add_argument("--enable-slave-count", type=positive_int, default=10, help="Slave EnableArm(7) send count.")
    parser.add_argument("--enable-slave-interval", type=positive_float, default=0.1, help="Interval between slave EnableArm(7) calls.")
    parser.add_argument("--settle-sec", type=nonnegative_float, default=1.0, help="Extra wait after restore commands.")

    parser.add_argument("--verify-timeout", type=positive_float, default=5.0, help="Teach-ready verification timeout.")
    parser.add_argument("--verify-interval", type=positive_float, default=0.2, help="Verification polling interval.")
    parser.add_argument("--no-verify", action="store_true", help="Skip final teach-ready verification.")
    return parser


def safe_int(value) -> Optional[int]:
    try:
        return int(value)
    except Exception:
        return None


def read_joints_deg(interface) -> Optional[List[float]]:
    try:
        wrapper = interface.GetArmJointMsgs()
        if getattr(wrapper, "time_stamp", 0) <= 0:
            return None
        joint_state = getattr(wrapper, "joint_state", None)
        if joint_state is None:
            return None
        return [
            float(getattr(joint_state, "joint_1")) / 1000.0,
            float(getattr(joint_state, "joint_2")) / 1000.0,
            float(getattr(joint_state, "joint_3")) / 1000.0,
            float(getattr(joint_state, "joint_4")) / 1000.0,
            float(getattr(joint_state, "joint_5")) / 1000.0,
            float(getattr(joint_state, "joint_6")) / 1000.0,
        ]
    except Exception:
        return None


def snapshot(name: str, interface) -> ArmSnapshot:
    snap = ArmSnapshot(name=name)
    try:
        status_wrapper = interface.GetArmStatus()
        status = status_wrapper.arm_status
        snap.ctrl_mode = safe_int(getattr(status, "ctrl_mode", None))
        snap.mode_feed = safe_int(getattr(status, "mode_feed", None))
        snap.teach_status = safe_int(getattr(status, "teach_status", None))
        snap.motion_status = safe_int(getattr(status, "motion_status", None))
        snap.err_code = safe_int(getattr(status, "err_code", None))
    except Exception:
        pass

    try:
        enable_status = interface.GetArmEnableStatus()
        snap.enable_status = [bool(v) for v in enable_status]
    except Exception:
        pass

    snap.joints_deg = read_joints_deg(interface)
    return snap


def format_joints(joints: Optional[List[float]]) -> str:
    if joints is None:
        return "unavailable"
    return "[" + ", ".join(f"{v:.3f}" for v in joints) + "]"


def print_snapshot(snap: ArmSnapshot) -> None:
    print(
        f"[{snap.name}] ctrl_mode={snap.ctrl_mode} "
        f"mode_feed={snap.mode_feed} "
        f"teach_status={snap.teach_status} "
        f"motion_status={snap.motion_status} "
        f"err_code={snap.err_code} "
        f"enable={snap.enable_status} "
        f"joints_deg={format_joints(snap.joints_deg)}"
    )


def slave_enabled(snapshot_value: ArmSnapshot) -> bool:
    return bool(snapshot_value.enable_status) and all(snapshot_value.enable_status)


def teach_ready(master_snap: ArmSnapshot, slave_snap: ArmSnapshot) -> bool:
    return master_snap.ctrl_mode == TEACH_CTRL_MODE and slave_enabled(slave_snap)


def connect(can_name: str):
    interface = C_PiperInterface_V2(can_name)
    interface.ConnectPort(piper_init=False)
    return interface


def send_master_can_zero(master, slave, args: argparse.Namespace) -> None:
    print(
        f"[zero] Sending master CAN MOVE_J zero: speed={args.zero_speed}, "
        f"duration={args.zero_duration:.3f}s, rate={args.zero_rate_hz:.1f}Hz"
    )
    if args.zero_slave_direct:
        print("[zero] zero_slave_direct=true; slave will also receive direct zero JointCtrl.")
    else:
        print("[zero] zero_slave_direct=false; slave is expected to follow master through bridge/master-slave link.")

    if args.enable_master_before_zero:
        try:
            print("[zero] Enabling master arm before zero: EnableArm(7)")
            master.EnableArm(7)
        except Exception as exc:
            print(f"[zero][warn] master.EnableArm(7) failed: {exc}")

    period = 1.0 / args.zero_rate_hz
    deadline = time.time() + args.zero_duration
    send_count = 0
    while time.time() < deadline:
        master.MotionCtrl_2(CTRL_MODE_CAN, MOVE_J, args.zero_speed, MIT_DISABLED)
        master.JointCtrl(0, 0, 0, 0, 0, 0)
        if args.zero_slave_direct:
            slave.MotionCtrl_2(CTRL_MODE_CAN, MOVE_J, args.zero_speed, MIT_DISABLED)
            slave.JointCtrl(0, 0, 0, 0, 0, 0)
        send_count += 1
        time.sleep(period)
    print(f"[zero] Finished CAN zero command stream. send_count={send_count}")


def restore_teach_mode(master, slave, args: argparse.Namespace) -> None:
    print("[restore] Step 1/3: rewrite master/slave role config.")
    for _ in range(args.role_send_count):
        master.MasterSlaveConfig(MASTER_ROLE, 0, 0, 0)
        slave.MasterSlaveConfig(SLAVE_ROLE, 0, 0, 0)
        time.sleep(args.role_send_interval)

    print("[restore] Step 2/3: request restore master-slave mode: master.ReqMasterArmMoveToHome(0).")
    for _ in range(args.restore_request_count):
        master.ReqMasterArmMoveToHome(0)
        time.sleep(args.restore_request_interval)

    print("[restore] Step 3/3: enable slave arm: slave.EnableArm(7).")
    for _ in range(args.enable_slave_count):
        slave.EnableArm(7)
        time.sleep(args.enable_slave_interval)

    if args.settle_sec > 0:
        print(f"[restore] Settling for {args.settle_sec:.3f}s.")
        time.sleep(args.settle_sec)


def verify_teach_ready(master, slave, args: argparse.Namespace) -> bool:
    print("[verify] Waiting for teach-ready state: master ctrl_mode=6 and slave fully enabled.")
    deadline = time.time() + args.verify_timeout
    latest_master = snapshot("master", master)
    latest_slave = snapshot("slave", slave)

    while time.time() <= deadline:
        latest_master = snapshot("master", master)
        latest_slave = snapshot("slave", slave)
        if teach_ready(latest_master, latest_slave):
            print("[verify] SUCCESS: teach mode restored.")
            print_snapshot(latest_master)
            print_snapshot(latest_slave)
            return True
        time.sleep(args.verify_interval)

    print("[verify] FAILED: teach-ready state was not reached before timeout.")
    print_snapshot(latest_master)
    print_snapshot(latest_slave)
    return False


def main() -> int:
    args = build_parser().parse_args()

    if args.master_can == args.slave_can:
        print("ERROR: --master-can and --slave-can must be different.", file=sys.stderr)
        return 1

    master = None
    slave = None
    try:
        print("[config] master_can=", args.master_can)
        print("[config] slave_can=", args.slave_can)
        print("[safety] Make sure both arms have a clear path before zeroing.")

        master = connect(args.master_can)
        slave = connect(args.slave_can)
        time.sleep(0.3)

        print("[state] Before operation:")
        print_snapshot(snapshot("master", master))
        print_snapshot(snapshot("slave", slave))

        if not args.restore_only:
            send_master_can_zero(master, slave, args)
            print("[state] After CAN zero, before restore:")
            print_snapshot(snapshot("master", master))
            print_snapshot(snapshot("slave", slave))
        else:
            print("[zero] restore_only=true; skip CAN zero.")

        restore_teach_mode(master, slave, args)

        print("[state] After restore commands:")
        print_snapshot(snapshot("master", master))
        print_snapshot(snapshot("slave", slave))

        if args.no_verify:
            print("[verify] no_verify=true; skip final verification.")
            return 0

        return 0 if verify_teach_ready(master, slave, args) else 1

    except KeyboardInterrupt:
        print("\nInterrupted by user.", file=sys.stderr)
        return 130
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    finally:
        for interface in (master, slave):
            if interface is not None:
                try:
                    interface.DisconnectPort()
                except Exception:
                    pass


if __name__ == "__main__":
    raise SystemExit(main())
