#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ROS_SETUP="/opt/ros/noetic/setup.bash"
WS_SETUP="${REPO_ROOT}/devel/setup.bash"
CAN_ACTIVATE_SCRIPT="${REPO_ROOT}/src/piper_ros/can_activate.sh"
BRIDGE_LAUNCH_FILE="${REPO_ROOT}/src/piper_ros/src/piper/launch/start_master_slave_bridge.launch"

LEFT_CAN_NAME="${LEFT_CAN_NAME:-can_piper_left}"
RIGHT_CAN_NAME="${RIGHT_CAN_NAME:-can_piper_right}"
LEFT_USB_BUS="${LEFT_USB_BUS:-1-2:1.0}"
RIGHT_USB_BUS="${RIGHT_USB_BUS:-1-1:1.0}"
MASTER_ARM_CAN="${MASTER_ARM_CAN:-${LEFT_CAN_NAME}}"
SLAVE_ARM_CAN="${SLAVE_ARM_CAN:-${RIGHT_CAN_NAME}}"

CAN_BITRATE="${CAN_BITRATE:-1000000}"
INITIAL_POWER_WAIT_SEC="${INITIAL_POWER_WAIT_SEC:-0.5}"
SEQUENTIAL_POWER_WAIT_SEC="${SEQUENTIAL_POWER_WAIT_SEC:-0.5}"
ROLE_WRITE_SEND_COUNT="${ROLE_WRITE_SEND_COUNT:-5}"
ROLE_CONNECT_WARMUP_SEC="${ROLE_CONNECT_WARMUP_SEC:-0.05}"
ROLE_SEND_INTERVAL_SEC="${ROLE_SEND_INTERVAL_SEC:-0.1}"

BRIDGE_RATE_HZ="${BRIDGE_RATE_HZ:-200}"
COMMAND_TIMEOUT_SEC="${COMMAND_TIMEOUT_SEC:-0.5}"
AUTO_ENABLE_SLAVE="${AUTO_ENABLE_SLAVE:-true}"
FOLLOW_GRIPPER="${FOLLOW_GRIPPER:-true}"
HOLD_LAST_JOINT_ON_TIMEOUT="${HOLD_LAST_JOINT_ON_TIMEOUT:-true}"
GO_HOME_MODE2_RECOVER_SLAVE_BEFORE_REQUEST="${GO_HOME_MODE2_RECOVER_SLAVE_BEFORE_REQUEST:-false}"
GO_HOME_MODE2_REQUEST_COUNT="${GO_HOME_MODE2_REQUEST_COUNT:-1}"
GO_HOME_MODE2_REQUEST_INTERVAL_SEC="${GO_HOME_MODE2_REQUEST_INTERVAL_SEC:-0.2}"
GO_HOME_MODE2_FORWARD_AFTER_REQUEST_SEC="${GO_HOME_MODE2_FORWARD_AFTER_REQUEST_SEC:-2.5}"
GO_HOME_MODE2_OBSERVE_INTERVAL_SEC="${GO_HOME_MODE2_OBSERVE_INTERVAL_SEC:-0.2}"
GO_HOME_MODE2_STOP_FORWARD_ON_MASTER_STANDBY="${GO_HOME_MODE2_STOP_FORWARD_ON_MASTER_STANDBY:-true}"
SHUTDOWN_AFTER_FINISH="${SHUTDOWN_AFTER_FINISH:-true}"
RECORD_ENABLE="${RECORD_ENABLE:-false}"
RECORD_RATE_HZ="${RECORD_RATE_HZ:-30}"

LOG_DIR="${REPO_ROOT}/log/ros"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOG_DIR}/prepare_dual_arm_teach_${TIMESTAMP}.log"

mkdir -p "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

usage() {
    cat <<EOF
Usage: bash src/data/prepare_dual_arm_teach.sh [--full]
       bash src/data/prepare_dual_arm_teach.sh -h|--help

This script only supports the full dual-arm teach initialization flow.
It performs CAN activation, role writing, required power-cycle prompts,
sequential slave-first/master-second power-on, and then launches the bridge.

Full initialization mode:
  --full
    Run the full initialization flow explicitly. With no mode argument, this
    same full initialization flow is used.

Default role assignment:
  master arm -> ${MASTER_ARM_CAN}
  slave arm  -> ${SLAVE_ARM_CAN}

Useful environment overrides:
  LEFT_CAN_NAME / RIGHT_CAN_NAME
  LEFT_USB_BUS / RIGHT_USB_BUS
  MASTER_ARM_CAN / SLAVE_ARM_CAN
  CAN_BITRATE
  INITIAL_POWER_WAIT_SEC / SEQUENTIAL_POWER_WAIT_SEC
  ROLE_WRITE_SEND_COUNT / ROLE_SEND_INTERVAL_SEC
  BRIDGE_RATE_HZ / COMMAND_TIMEOUT_SEC
  AUTO_ENABLE_SLAVE / FOLLOW_GRIPPER / HOLD_LAST_JOINT_ON_TIMEOUT
  GO_HOME_MODE2_RECOVER_SLAVE_BEFORE_REQUEST
  GO_HOME_MODE2_REQUEST_COUNT / GO_HOME_MODE2_REQUEST_INTERVAL_SEC
  GO_HOME_MODE2_FORWARD_AFTER_REQUEST_SEC
  GO_HOME_MODE2_OBSERVE_INTERVAL_SEC
  GO_HOME_MODE2_STOP_FORWARD_ON_MASTER_STANDBY
  SHUTDOWN_AFTER_FINISH
  RECORD_ENABLE / RECORD_RATE_HZ

Example:
  MASTER_ARM_CAN=can_piper_left SLAVE_ARM_CAN=can_piper_right \\
  bash src/data/prepare_dual_arm_teach.sh --full

  bash src/data/prepare_dual_arm_teach.sh
EOF
}

log() {
    printf '[prepare_dual_arm_teach] %s\n' "$*"
}

die() {
    printf '[prepare_dual_arm_teach][error] %s\n' "$*" >&2
    exit 1
}

pause_for_user() {
    local message="$1"
    printf '\n'
    log "${message}"
    read -r -p "[prepare_dual_arm_teach] Press Enter to continue... " _
}

wait_with_log() {
    local seconds="$1"
    log "Waiting ${seconds}s..."
    sleep "${seconds}"
}

can_interface_exists() {
    ip link show "$1" >/dev/null 2>&1
}

can_interface_is_up() {
    ip link show "$1" 2>/dev/null | grep -q "UP"
}

can_interface_bitrate() {
    ip -details link show "$1" 2>/dev/null | awk '
        {
            for (i = 1; i <= NF; ++i) {
                if ($i == "bitrate") {
                    print $(i + 1)
                    exit
                }
            }
        }
    '
}

ensure_prerequisites() {
    [[ -t 0 ]] || die "This script requires an interactive terminal because it includes manual power-cycle steps."
    [[ -f "${ROS_SETUP}" ]] || die "Missing ROS setup file: ${ROS_SETUP}"
    [[ -f "${WS_SETUP}" ]] || die "Missing workspace setup file: ${WS_SETUP}"
    [[ -f "${CAN_ACTIVATE_SCRIPT}" ]] || die "Missing CAN activation script: ${CAN_ACTIVATE_SCRIPT}"
    [[ -f "${BRIDGE_LAUNCH_FILE}" ]] || die "Missing launch file: ${BRIDGE_LAUNCH_FILE}"
    command -v python3 >/dev/null 2>&1 || die "python3 is required."
    [[ "${LEFT_CAN_NAME}" != "${RIGHT_CAN_NAME}" ]] || die "LEFT_CAN_NAME and RIGHT_CAN_NAME must be different."
    [[ "${MASTER_ARM_CAN}" != "${SLAVE_ARM_CAN}" ]] || die "MASTER_ARM_CAN and SLAVE_ARM_CAN must be different."
}

activate_can_interfaces() {
    log "Activating CAN interface ${RIGHT_CAN_NAME} on USB bus ${RIGHT_USB_BUS}..."
    bash "${CAN_ACTIVATE_SCRIPT}" "${RIGHT_CAN_NAME}" "${CAN_BITRATE}" "${RIGHT_USB_BUS}"
    log "Activating CAN interface ${LEFT_CAN_NAME} on USB bus ${LEFT_USB_BUS}..."
    bash "${CAN_ACTIVATE_SCRIPT}" "${LEFT_CAN_NAME}" "${CAN_BITRATE}" "${LEFT_USB_BUS}"
}

write_master_slave_roles() {
    log "Writing master/slave roles: master=${MASTER_ARM_CAN}, slave=${SLAVE_ARM_CAN}..."
    REPO_ROOT="${REPO_ROOT}" \
    MASTER_ARM_CAN="${MASTER_ARM_CAN}" \
    SLAVE_ARM_CAN="${SLAVE_ARM_CAN}" \
    ROLE_WRITE_SEND_COUNT="${ROLE_WRITE_SEND_COUNT}" \
    ROLE_CONNECT_WARMUP_SEC="${ROLE_CONNECT_WARMUP_SEC}" \
    ROLE_SEND_INTERVAL_SEC="${ROLE_SEND_INTERVAL_SEC}" \
    python3 - <<'PY'
import os
import sys
import time

repo_root = os.environ["REPO_ROOT"]
sys.path.insert(0, os.path.join(repo_root, "src", "piper_sdk"))

from piper_sdk import C_PiperInterface_V2


def set_role(can_name: str, role: int, label: str) -> None:
    send_count = int(os.environ["ROLE_WRITE_SEND_COUNT"])
    connect_warmup = float(os.environ["ROLE_CONNECT_WARMUP_SEC"])
    send_interval = float(os.environ["ROLE_SEND_INTERVAL_SEC"])
    interface = C_PiperInterface_V2(can_name)
    interface.ConnectPort(piper_init=False)
    try:
        time.sleep(connect_warmup)
        for _ in range(send_count):
            interface.MasterSlaveConfig(role, 0, 0, 0)
            time.sleep(send_interval)
        print(f"[prepare_dual_arm_teach] set {label} on {can_name} (0x{role:02X})")
    finally:
        interface.DisconnectPort()


set_role(os.environ["MASTER_ARM_CAN"], 0xFA, "master role")
set_role(os.environ["SLAVE_ARM_CAN"], 0xFC, "slave role")
PY
}

source_ros_env() {
    # shellcheck disable=SC1090
    source "${ROS_SETUP}"
    # shellcheck disable=SC1090
    source "${WS_SETUP}"
    command -v roslaunch >/dev/null 2>&1 || die "roslaunch not found after sourcing ROS environment."
}

launch_bridge() {
    log "Launching master-slave bridge..."
    log "Log file: ${LOG_FILE}"
    log "After teleoperation ends, call:"
    log "  rosservice call /finish_teach_and_go_zero_srv \"{}\""
    log "This will send master.ReqMasterArmMoveToHome(2), forward briefly, then shut down the bridge."
    exec roslaunch piper start_master_slave_bridge.launch \
        master_can_port:="${MASTER_ARM_CAN}" \
        slave_can_port:="${SLAVE_ARM_CAN}" \
        bridge_rate_hz:="${BRIDGE_RATE_HZ}" \
        command_timeout_sec:="${COMMAND_TIMEOUT_SEC}" \
        auto_enable_slave:="${AUTO_ENABLE_SLAVE}" \
        follow_gripper:="${FOLLOW_GRIPPER}" \
        hold_last_joint_on_timeout:="${HOLD_LAST_JOINT_ON_TIMEOUT}" \
        go_home_mode2_recover_slave_before_request:="${GO_HOME_MODE2_RECOVER_SLAVE_BEFORE_REQUEST}" \
        go_home_mode2_request_count:="${GO_HOME_MODE2_REQUEST_COUNT}" \
        go_home_mode2_request_interval_sec:="${GO_HOME_MODE2_REQUEST_INTERVAL_SEC}" \
        go_home_mode2_forward_after_request_sec:="${GO_HOME_MODE2_FORWARD_AFTER_REQUEST_SEC}" \
        go_home_mode2_observe_interval_sec:="${GO_HOME_MODE2_OBSERVE_INTERVAL_SEC}" \
        go_home_mode2_stop_forward_on_master_standby:="${GO_HOME_MODE2_STOP_FORWARD_ON_MASTER_STANDBY}" \
        shutdown_after_finish:="${SHUTDOWN_AFTER_FINISH}" \
        record_enable:="${RECORD_ENABLE}" \
        record_rate_hz:="${RECORD_RATE_HZ}"
}

main() {
    if (( $# == 0 )); then
        log "No mode argument provided. Running full initialization flow."
    fi

    while (( $# > 0 )); do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --quick|--fast)
                die "Quick/software restore has been removed. Use --full."
                ;;
            --full)
                ;;
            *)
                usage
                die "Quick/software restore has been removed. Use --full."
                ;;
        esac
        shift
    done

    ensure_prerequisites

    log "Start: $(date '+%F %T')"
    pause_for_user "Step 1/6: Disconnect power from both arms."

    log "Step 2/6: Activating CAN adapters."
    activate_can_interfaces

    pause_for_user "Step 3/6: Power on both arms now."
    wait_with_log "${INITIAL_POWER_WAIT_SEC}"

    log "Step 4/6: Setting roles."
    write_master_slave_roles

    pause_for_user "Step 5/6: Power off both arms now."
    pause_for_user "Step 5/6: Power on the slave arm first."
    wait_with_log "${SEQUENTIAL_POWER_WAIT_SEC}"
    pause_for_user "Step 5/6: Power on the master arm now."
    wait_with_log "${SEQUENTIAL_POWER_WAIT_SEC}"

    log "Step 6/6: Launching bridge."
    source_ros_env
    launch_bridge
}

main "$@"
