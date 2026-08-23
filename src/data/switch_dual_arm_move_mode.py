#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
双臂 0x151 控制/ MOVE 模式切换脚本

通过 CAN 向 Piper 左右机械臂发送 0x151 指令，切换控制模式和/或 MOVE 模式。
本脚本只做模式切换和回读校验，不做使能、不发送关节运动或末端运动指令。

示例:
    python3 src/data/switch_dual_arm_move_mode.py --mode j
    python3 src/data/switch_dual_arm_move_mode.py --ctrl-mode standby
    python3 src/data/switch_dual_arm_move_mode.py --left-mode l --right-ctrl-mode offline
    python3 src/data/switch_dual_arm_move_mode.py --mode mit --ctrl-mode can --speed 50

参数：
    --mode
    p   -> MOVE_P   位置/末端位姿模式
    j   -> MOVE_J   关节运动模式
    l   -> MOVE_L   直线运动模式
    c   -> MOVE_C   圆弧/圆周运动模式
    mit -> MOVE_M   MIT 控制模式

    --ctrl-mode
    standby -> 待机
    can     -> CAN 控制
    eth     -> 以太网控制
    wifi    -> WIFI 控制
    offline -> 离线轨迹模式

规则:
    1. 至少要提供一项模式参数:
       --mode / --left-mode / --right-mode / --ctrl-mode / --left-ctrl-mode / --right-ctrl-mode
    2. 只指定 MOVE 模式时，控制模式默认切到 CAN。
    3. 只指定控制模式时，会优先保留当前机械臂的 MOVE 模式；如果读取不到，则回退为 MOVE_J。
    4. 如果同时给了共享参数和单臂参数，则单臂参数优先。
    5. 默认禁止改写当前处于联动示教输入模式(ctrl_mode=0x06)的机械臂，
       以避免破坏双臂主从示教/重力补偿。若确有需要，必须显式传 --force。

返回码:
    0: 所有目标机械臂都完成回读校验
    1: 参数非法、CAN 连接失败、或校验超时
"""

from __future__ import annotations

import argparse
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Optional


REPO_ROOT = Path(__file__).resolve().parents[2]
SDK_SOURCE_ROOT = REPO_ROOT / "src" / "piper_sdk"
if SDK_SOURCE_ROOT.is_dir():
    sys.path.insert(0, str(SDK_SOURCE_ROOT))

from piper_sdk import ArmMsgFeedbackStatusEnum, C_PiperInterface_V2


CTRL_MODE_CAN = 0x01
MIT_DISABLED = 0x00
MIT_ENABLED = 0xAD
CONNECT_WARMUP_SEC = 0.2
VERIFY_POLL_INTERVAL_SEC = 0.05


@dataclass(frozen=True)
class ModeConfig:
    cli_name: str
    display_name: str
    move_mode: int
    mit_mode: int
    expected_mode_feed: int


@dataclass(frozen=True)
class CtrlModeConfig:
    cli_name: str
    display_name: str
    ctrl_mode: int


@dataclass(frozen=True)
class ArmSelection:
    label: str
    can_name: str
    requested_mode: Optional[ModeConfig] = None
    requested_ctrl_mode: Optional[CtrlModeConfig] = None


@dataclass(frozen=True)
class ArmTarget:
    label: str
    can_name: str
    mode: ModeConfig
    ctrl_mode: CtrlModeConfig
    verify_move_mode: bool
    mode_source: str
    ctrl_mode_source: str


@dataclass
class ArmObservation:
    ctrl_mode: Optional[int] = None
    mode_feed: Optional[int] = None
    mit_mode: Optional[int] = None
    commanded_ctrl_mode: Optional[int] = None
    commanded_move_mode: Optional[int] = None
    status_time_stamp: float = 0.0
    mode_ctrl_time_stamp: float = 0.0


MODE_MAP: Dict[str, ModeConfig] = {
    "p": ModeConfig("p", "MOVE_P", 0x00, MIT_DISABLED, 0x00),
    "j": ModeConfig("j", "MOVE_J", 0x01, MIT_DISABLED, 0x01),
    "l": ModeConfig("l", "MOVE_L", 0x02, MIT_DISABLED, 0x02),
    "c": ModeConfig("c", "MOVE_C", 0x03, MIT_DISABLED, 0x03),
    "mit": ModeConfig("mit", "MOVE_M", 0x04, MIT_ENABLED, 0x04),
    "cpv": ModeConfig("cpv", "MOVE_CPV", 0x05, MIT_DISABLED, 0x05),
}
MODE_CLI_CHOICES = ("p", "j", "l", "c", "mit")

CTRL_MODE_MAP: Dict[str, CtrlModeConfig] = {
    "standby": CtrlModeConfig("standby", "STANDBY", 0x00),
    "can": CtrlModeConfig("can", "CAN_CTRL", 0x01),
    "eth": CtrlModeConfig("eth", "ETHERNET_CTRL", 0x03),
    "wifi": CtrlModeConfig("wifi", "WIFI_CTRL", 0x04),
    "offline": CtrlModeConfig("offline", "OFFLINE_TRAJECTORY", 0x07),
}
CTRL_MODE_CLI_CHOICES = tuple(CTRL_MODE_MAP.keys())


class ExitCodeArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> None:
        self.print_usage(sys.stderr)
        self.exit(1, f"{self.prog}: error: {message}\n")


def speed_type(value: str) -> int:
    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be an integer") from exc
    if not 0 <= parsed <= 100:
        raise argparse.ArgumentTypeError("must be in range 0-100")
    return parsed


def positive_int_type(value: str) -> int:
    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be an integer") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than 0")
    return parsed


def positive_float_type(value: str) -> float:
    try:
        parsed = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a number") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than 0")
    return parsed


def build_parser() -> argparse.ArgumentParser:
    parser = ExitCodeArgumentParser(
        description="Switch 0x151 control mode and MOVE mode for Piper dual-arm CAN interfaces.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--left-can",
        default="can_piper_left",
        help="Left arm CAN interface name.",
    )
    parser.add_argument(
        "--right-can",
        default="can_piper_right",
        help="Right arm CAN interface name.",
    )
    parser.add_argument(
        "--mode",
        choices=MODE_CLI_CHOICES,
        help="Apply the same target MOVE mode to both arms.",
    )
    parser.add_argument(
        "--left-mode",
        choices=MODE_CLI_CHOICES,
        help="Override the target MOVE mode for the left arm.",
    )
    parser.add_argument(
        "--right-mode",
        choices=MODE_CLI_CHOICES,
        help="Override the target MOVE mode for the right arm.",
    )
    parser.add_argument(
        "--ctrl-mode",
        choices=CTRL_MODE_CLI_CHOICES,
        help="Apply the same target control mode to both arms.",
    )
    parser.add_argument(
        "--left-ctrl-mode",
        choices=CTRL_MODE_CLI_CHOICES,
        help="Override the target control mode for the left arm.",
    )
    parser.add_argument(
        "--right-ctrl-mode",
        choices=CTRL_MODE_CLI_CHOICES,
        help="Override the target control mode for the right arm.",
    )
    parser.add_argument(
        "--speed",
        type=speed_type,
        default=30,
        help="Motion speed percentage sent in 0x151.",
    )
    parser.add_argument(
        "--send-count",
        type=positive_int_type,
        default=5,
        help="How many rounds of 0x151 mode command to broadcast.",
    )
    parser.add_argument(
        "--send-interval",
        type=positive_float_type,
        default=0.1,
        help="Sleep interval between send rounds in seconds.",
    )
    parser.add_argument(
        "--verify-timeout",
        type=positive_float_type,
        default=2.0,
        help="Maximum time to wait for verification feedback in seconds.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Allow overwriting arms that are currently in linkage teaching input mode (ctrl_mode=0x06).",
    )
    return parser


def parse_args() -> argparse.Namespace:
    parser = build_parser()
    args = parser.parse_args()
    if (
        args.mode is None
        and args.left_mode is None
        and args.right_mode is None
        and args.ctrl_mode is None
        and args.left_ctrl_mode is None
        and args.right_ctrl_mode is None
    ):
        parser.error(
            "at least one of --mode, --left-mode, --right-mode, "
            "--ctrl-mode, --left-ctrl-mode, or --right-ctrl-mode must be provided"
        )
    return args


def resolve_selections(args: argparse.Namespace) -> Dict[str, ArmSelection]:
    selections: Dict[str, ArmSelection] = {}

    if args.mode is not None or args.ctrl_mode is not None:
        selections["left"] = ArmSelection(
            "left",
            args.left_can,
            MODE_MAP[args.mode] if args.mode is not None else None,
            CTRL_MODE_MAP[args.ctrl_mode] if args.ctrl_mode is not None else None,
        )
        selections["right"] = ArmSelection(
            "right",
            args.right_can,
            MODE_MAP[args.mode] if args.mode is not None else None,
            CTRL_MODE_MAP[args.ctrl_mode] if args.ctrl_mode is not None else None,
        )

    if args.left_mode is not None or args.left_ctrl_mode is not None:
        current = selections.get("left", ArmSelection("left", args.left_can))
        selections["left"] = ArmSelection(
            "left",
            args.left_can,
            MODE_MAP[args.left_mode] if args.left_mode is not None else current.requested_mode,
            CTRL_MODE_MAP[args.left_ctrl_mode]
            if args.left_ctrl_mode is not None
            else current.requested_ctrl_mode,
        )

    if args.right_mode is not None or args.right_ctrl_mode is not None:
        current = selections.get("right", ArmSelection("right", args.right_can))
        selections["right"] = ArmSelection(
            "right",
            args.right_can,
            MODE_MAP[args.right_mode] if args.right_mode is not None else current.requested_mode,
            CTRL_MODE_MAP[args.right_ctrl_mode]
            if args.right_ctrl_mode is not None
            else current.requested_ctrl_mode,
        )

    return selections


def format_ctrl_mode(value: Optional[int]) -> str:
    if value is None:
        return "UNKNOWN"
    try:
        matched = ArmMsgFeedbackStatusEnum.CtrlMode.match_value(int(value))
        return f"{matched.name}(0x{int(matched):02X})"
    except ValueError:
        return f"UNKNOWN(0x{int(value):02X})"


def format_mode_feed(value: Optional[int]) -> str:
    if value is None:
        return "UNKNOWN"
    try:
        matched = ArmMsgFeedbackStatusEnum.ModeFeed.match_value(int(value))
        return f"{matched.name}(0x{int(matched):02X})"
    except ValueError:
        return f"UNKNOWN(0x{int(value):02X})"


def format_mit_mode(value: Optional[int]) -> str:
    if value is None:
        return "N/A"
    return f"0x{int(value):02X}"


def format_mode_config(mode: ModeConfig) -> str:
    return f"{mode.display_name}(0x{mode.move_mode:02X})"


def format_ctrl_config(ctrl_mode: CtrlModeConfig) -> str:
    return f"{ctrl_mode.display_name}(0x{ctrl_mode.ctrl_mode:02X})"


def connect_interfaces(selections: Dict[str, ArmSelection]) -> Dict[str, C_PiperInterface_V2]:
    interfaces: Dict[str, C_PiperInterface_V2] = {}
    for label, selection in selections.items():
        try:
            interface = C_PiperInterface_V2(selection.can_name)
            interface.ConnectPort(piper_init=False)
            interfaces[label] = interface
        except Exception as exc:
            raise ConnectionError(
                f"[{label}] failed to connect CAN interface '{selection.can_name}': {exc}"
            ) from exc
    return interfaces


def send_mode_commands(
    targets: Dict[str, ArmTarget],
    interfaces: Dict[str, C_PiperInterface_V2],
    speed: int,
    send_count: int,
    send_interval: float,
) -> None:
    for _ in range(send_count):
        for label, target in targets.items():
            interface = interfaces[label]
            interface.MotionCtrl_2(
                target.ctrl_mode.ctrl_mode,
                target.mode.move_mode,
                speed,
                target.mode.mit_mode,
            )
        time.sleep(send_interval)


def read_observation(interface: C_PiperInterface_V2) -> ArmObservation:
    observation = ArmObservation()

    try:
        status_wrapper = interface.GetArmStatus()
        status = status_wrapper.arm_status
        observation.ctrl_mode = int(status.ctrl_mode)
        observation.mode_feed = int(status.mode_feed)
        observation.status_time_stamp = float(status_wrapper.time_stamp)
    except Exception:
        pass

    try:
        mode_ctrl_wrapper = interface.GetArmModeCtrl()
        if float(mode_ctrl_wrapper.time_stamp) > 0:
            observation.commanded_ctrl_mode = int(mode_ctrl_wrapper.mode_ctrl.ctrl_mode)
            observation.commanded_move_mode = int(mode_ctrl_wrapper.mode_ctrl.move_mode)
            observation.mit_mode = int(mode_ctrl_wrapper.mode_ctrl.mit_mode)
            observation.mode_ctrl_time_stamp = float(mode_ctrl_wrapper.time_stamp)
    except Exception:
        pass

    if observation.commanded_move_mode is None:
        try:
            ctrl_code_wrapper = interface.GetArmCtrlCode151()
            if float(ctrl_code_wrapper.time_stamp) > 0:
                observation.commanded_ctrl_mode = int(ctrl_code_wrapper.ctrl_151.ctrl_mode)
                observation.commanded_move_mode = int(ctrl_code_wrapper.ctrl_151.move_mode)
                observation.mit_mode = int(ctrl_code_wrapper.ctrl_151.mit_mode)
                observation.mode_ctrl_time_stamp = float(ctrl_code_wrapper.time_stamp)
        except Exception:
            pass

    return observation


def mode_config_from_observation(observation: ArmObservation) -> Optional[ModeConfig]:
    move_mode = observation.commanded_move_mode
    if move_mode is None:
        move_mode = observation.mode_feed

    if move_mode == 0x00:
        return MODE_MAP["p"]
    if move_mode == 0x01:
        return MODE_MAP["j"]
    if move_mode == 0x02:
        return MODE_MAP["l"]
    if move_mode == 0x03:
        return MODE_MAP["c"]
    if move_mode == 0x04:
        mit_mode = observation.mit_mode if observation.mit_mode is not None else MIT_ENABLED
        return ModeConfig("mit", "MOVE_M", 0x04, mit_mode, 0x04)
    if move_mode == 0x05:
        return MODE_MAP["cpv"]
    return None


def resolve_runtime_targets(
    selections: Dict[str, ArmSelection],
    interfaces: Dict[str, C_PiperInterface_V2],
    allow_linkage_teach_override: bool,
) -> Dict[str, ArmTarget]:
    targets: Dict[str, ArmTarget] = {}
    for label, selection in selections.items():
        observation = read_observation(interfaces[label])

        if observation.ctrl_mode == 0x06 and not allow_linkage_teach_override:
            raise RuntimeError(
                f"[{label}] arm is currently in linkage teaching input mode (ctrl_mode=0x06). "
                "Refusing to overwrite it because this usually disables dual-arm teaching/gravity compensation. "
                "If you really want to do this, rerun with --force."
            )

        if selection.requested_mode is not None:
            mode = selection.requested_mode
            mode_source = "requested"
            verify_move_mode = True
        else:
            preserved_mode = mode_config_from_observation(observation)
            if preserved_mode is not None:
                mode = preserved_mode
                mode_source = "preserved"
            else:
                mode = MODE_MAP["j"]
                mode_source = "defaulted"
            verify_move_mode = False

        if selection.requested_ctrl_mode is not None:
            ctrl_mode = selection.requested_ctrl_mode
            ctrl_mode_source = "requested"
        else:
            ctrl_mode = CTRL_MODE_MAP["can"]
            ctrl_mode_source = "defaulted"

        targets[label] = ArmTarget(
            label=label,
            can_name=selection.can_name,
            mode=mode,
            ctrl_mode=ctrl_mode,
            verify_move_mode=verify_move_mode,
            mode_source=mode_source,
            ctrl_mode_source=ctrl_mode_source,
        )

    return targets


def is_target_satisfied(target: ArmTarget, observation: ArmObservation) -> bool:
    ctrl_ok = observation.ctrl_mode == target.ctrl_mode.ctrl_mode
    if not ctrl_ok:
        return False
    if not target.verify_move_mode:
        return True
    return observation.mode_feed == target.mode.expected_mode_feed


def verify_targets(
    targets: Dict[str, ArmTarget],
    interfaces: Dict[str, C_PiperInterface_V2],
    verify_timeout: float,
) -> tuple[bool, Dict[str, ArmObservation]]:
    deadline = time.time() + verify_timeout
    latest: Dict[str, ArmObservation] = {label: ArmObservation() for label in targets}

    while time.time() <= deadline:
        all_success = True
        for label, target in targets.items():
            observation = read_observation(interfaces[label])
            latest[label] = observation
            if not is_target_satisfied(target, observation):
                all_success = False
        if all_success:
            return True, latest
        time.sleep(VERIFY_POLL_INTERVAL_SEC)

    return False, latest


def print_plan(targets: Dict[str, ArmTarget], speed: int) -> None:
    print("Target 0x151 switch plan:")
    for label, target in targets.items():
        print(
            f"  [{label}] can={target.can_name} "
            f"target_ctrl={format_ctrl_config(target.ctrl_mode)}[{target.ctrl_mode_source}] "
            f"target_move={format_mode_config(target.mode)}[{target.mode_source}] "
            f"mit_mode=0x{target.mode.mit_mode:02X} "
            f"speed={speed}"
        )


def print_results(
    targets: Dict[str, ArmTarget],
    observations: Dict[str, ArmObservation],
    success_map: Dict[str, bool],
) -> None:
    print("Verification results:")
    for label, target in targets.items():
        observation = observations.get(label, ArmObservation())
        result_text = "SUCCESS" if success_map.get(label, False) else "FAILED"
        print(
            f"  [{label}] can={target.can_name} "
            f"target_ctrl={format_ctrl_config(target.ctrl_mode)} "
            f"target_move={format_mode_config(target.mode)} "
            f"ctrl_mode={format_ctrl_mode(observation.ctrl_mode)} "
            f"mode_feed={format_mode_feed(observation.mode_feed)} "
            f"mit_mode={format_mit_mode(observation.mit_mode)} "
            f"move_check={'ON' if target.verify_move_mode else 'OFF'} "
            f"result={result_text}"
        )


def disconnect_interfaces(interfaces: Dict[str, C_PiperInterface_V2]) -> None:
    for interface in interfaces.values():
        try:
            interface.DisconnectPort()
        except Exception:
            pass


def main() -> int:
    args = parse_args()
    selections = resolve_selections(args)
    interfaces: Dict[str, C_PiperInterface_V2] = {}

    try:
        interfaces = connect_interfaces(selections)
        time.sleep(CONNECT_WARMUP_SEC)
        targets = resolve_runtime_targets(selections, interfaces, args.force)
        print_plan(targets, args.speed)
        send_mode_commands(targets, interfaces, args.speed, args.send_count, args.send_interval)
        verified, observations = verify_targets(targets, interfaces, args.verify_timeout)
        success_map = {
            label: is_target_satisfied(target, observations[label])
            for label, target in targets.items()
        }
        print_results(targets, observations, success_map)
        if not verified:
            print("Verification timed out before all target arms matched the requested 0x151 settings.")
        return 0 if verified else 1
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    finally:
        disconnect_interfaces(interfaces)


if __name__ == "__main__":
    sys.exit(main())
