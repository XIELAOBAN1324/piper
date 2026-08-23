#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ROS_SETUP="/opt/ros/noetic/setup.bash"
WS_SETUP="${REPO_ROOT}/devel/setup.bash"
CAN_ACTIVATE_SCRIPT="${REPO_ROOT}/src/piper_ros/can_activate.sh"
MODE_SWITCH_SCRIPT="${REPO_ROOT}/src/data/switch_dual_arm_move_mode.py"

# Default configuration. Override with environment variables when needed, e.g.
# LEFT_USB_BUS=1-3:1.0 RIGHT_USB_BUS=1-4:1.0 GO_ZERO_ON_START=false bash scripts/launch_init.sh
LEFT_CAN_NAME="${LEFT_CAN_NAME:-can_piper_left}"
RIGHT_CAN_NAME="${RIGHT_CAN_NAME:-can_piper_right}"
LEFT_USB_BUS="${LEFT_USB_BUS:-1-2:1.0}"
RIGHT_USB_BUS="${RIGHT_USB_BUS:-1-1:1.0}"
LEFT_NS="${LEFT_NS:-/piper_left}"
RIGHT_NS="${RIGHT_NS:-/piper_right}"

AUTO_ENABLE="${AUTO_ENABLE:-true}"
FORCE_ENABLE_ON_START="${FORCE_ENABLE_ON_START:-true}"
GO_ZERO_ON_START="${GO_ZERO_ON_START:-true}"
GO_ZERO_MIT_MODE="${GO_ZERO_MIT_MODE:-false}"
# TODO: 夹爪到了改成true
GRIPPER_EXIST="${GRIPPER_EXIST:-false}"
# Set to 2 when sending gripper commands from RViz/MoveIt to compensate for the 0.035m model range.
GRIPPER_VALUE_MULTIPLE="${GRIPPER_VALUE_MULTIPLE:-1}"

SWITCH_MODE_ON_START="${SWITCH_MODE_ON_START:-true}"
MOVE_MODE="${MOVE_MODE:-j}"
CTRL_MODE="${CTRL_MODE:-can}"

START_ROSCORE="${START_ROSCORE:-true}"
SERVICE_WAIT_TIMEOUT_SEC="${SERVICE_WAIT_TIMEOUT_SEC:-20}"
POST_ENABLE_SLEEP_SEC="${POST_ENABLE_SLEEP_SEC:-1}"

export ROS_HOME="${ROS_HOME:-${REPO_ROOT}/.ros}"
export ROS_LOG_DIR="${ROS_LOG_DIR:-${ROS_HOME}/log}"
LOG_DIR="${LOG_DIR:-${ROS_HOME}/launch_init}"
ROSCORE_LOG="${LOG_DIR}/roscore.log"
LEFT_NODE_LOG="${LOG_DIR}/piper_left.log"
RIGHT_NODE_LOG="${LOG_DIR}/piper_right.log"

NODE_PIDS=()
NODE_LOGS=()
ROSCORE_PID=""
ROSCORE_STARTED_BY_SCRIPT="false"

usage() {
    cat <<EOF
Usage: bash scripts/launch_init.sh

This script brings up both Piper arms with isolated ROS namespaces:
  ${LEFT_NS}  -> command topic ${LEFT_NS}/joint_states
  ${RIGHT_NS} -> command topic ${RIGHT_NS}/joint_states

Useful environment overrides:
  LEFT_USB_BUS / RIGHT_USB_BUS       USB bus-info for each CAN adapter
  LEFT_CAN_NAME / RIGHT_CAN_NAME     Target CAN interface names
  LEFT_NS / RIGHT_NS                 ROS namespaces for each arm
  AUTO_ENABLE=true|false             Pass through to piper_ctrl_single_node.py
  FORCE_ENABLE_ON_START=true|false   Explicitly call enable_srv after startup
  GO_ZERO_ON_START=true|false        Call go_zero_srv after both arms are ready
  GO_ZERO_MIT_MODE=true|false        Use MIT mode when calling go_zero_srv
  SWITCH_MODE_ON_START=true|false    Call switch_dual_arm_move_mode.py before ROS bringup
  MOVE_MODE=j|p|l|c|mit              Target move mode when switching mode
  CTRL_MODE=can|standby|eth|wifi|offline
  GRIPPER_VALUE_MULTIPLE=1|2         Set 2 for RViz/MoveIt gripper control

Example:
  GO_ZERO_ON_START=false GRIPPER_VALUE_MULTIPLE=2 bash scripts/launch_init.sh
EOF
}

log() {
    printf '[launch_init] %s\n' "$*"
}

warn() {
    printf '[launch_init][warn] %s\n' "$*" >&2
}

die() {
    printf '[launch_init][error] %s\n' "$*" >&2
    exit 1
}

normalize_ns() {
    local ns="$1"
    [[ -n "${ns}" ]] || die "Namespace must not be empty."
    [[ "${ns}" == /* ]] || ns="/${ns}"
    printf '%s\n' "${ns%/}"
}

service_name() {
    local ns="$1"
    local name="$2"
    printf '%s/%s\n' "${ns}" "${name}"
}

ensure_prerequisites() {
    [[ -f "${ROS_SETUP}" ]] || die "Missing ROS setup file: ${ROS_SETUP}"
    [[ -f "${WS_SETUP}" ]] || die "Missing workspace setup file: ${WS_SETUP}"
    [[ -f "${CAN_ACTIVATE_SCRIPT}" ]] || die "Missing CAN activation script: ${CAN_ACTIVATE_SCRIPT}"
    if [[ "${SWITCH_MODE_ON_START}" == "true" ]]; then
        [[ -f "${MODE_SWITCH_SCRIPT}" ]] || die "Missing mode switch script: ${MODE_SWITCH_SCRIPT}"
    fi

    mkdir -p "${ROS_HOME}" "${ROS_LOG_DIR}" "${LOG_DIR}"

    # shellcheck disable=SC1090
    source "${ROS_SETUP}"
    # shellcheck disable=SC1090
    source "${WS_SETUP}"

    command -v roscore >/dev/null 2>&1 || die "roscore not found after sourcing ROS environment."
    command -v rosrun >/dev/null 2>&1 || die "rosrun not found after sourcing ROS environment."
    command -v rosservice >/dev/null 2>&1 || die "rosservice not found after sourcing ROS environment."
    command -v rosparam >/dev/null 2>&1 || die "rosparam not found after sourcing ROS environment."
    command -v python3 >/dev/null 2>&1 || die "python3 is required."
}

ros_master_running() {
    rosparam list >/dev/null 2>&1
}

wait_for_ros_master() {
    local timeout="$1"
    local start_time="$SECONDS"
    while (( SECONDS - start_time < timeout )); do
        if ros_master_running; then
            return 0
        fi
        sleep 0.2
    done
    return 1
}

start_roscore_if_needed() {
    if ros_master_running; then
        log "ROS master already running."
        return
    fi

    [[ "${START_ROSCORE}" == "true" ]] || die "ROS master is not running and START_ROSCORE=false."

    log "Starting roscore..."
    roscore >"${ROSCORE_LOG}" 2>&1 &
    ROSCORE_PID="$!"
    ROSCORE_STARTED_BY_SCRIPT="true"

    wait_for_ros_master 15 || die "roscore did not become ready. Check ${ROSCORE_LOG}"
    log "roscore is ready."
}

activate_can() {
    local can_name="$1"
    local usb_bus="$2"
    log "Activating CAN interface ${can_name} on USB bus ${usb_bus}..."
    bash "${CAN_ACTIVATE_SCRIPT}" "${can_name}" 1000000 "${usb_bus}"
}

switch_move_mode_if_needed() {
    [[ "${SWITCH_MODE_ON_START}" == "true" ]] || return 0

    log "Switching both arms to ctrl_mode=${CTRL_MODE}, move_mode=${MOVE_MODE}..."
    python3 "${MODE_SWITCH_SCRIPT}" \
        --left-can "${LEFT_CAN_NAME}" \
        --right-can "${RIGHT_CAN_NAME}" \
        --ctrl-mode "${CTRL_MODE}" \
        --mode "${MOVE_MODE}"
}

ensure_namespace_available() {
    local ns="$1"
    local enable_srv
    local zero_srv

    enable_srv="$(service_name "${ns}" "enable_srv")"
    zero_srv="$(service_name "${ns}" "go_zero_srv")"

    if rosservice info "${enable_srv}" >/dev/null 2>&1; then
        die "Namespace ${ns} is already in use (${enable_srv} exists). Stop the old node before running launch_init again."
    fi

    if rosservice info "${zero_srv}" >/dev/null 2>&1; then
        die "Namespace ${ns} is already in use (${zero_srv} exists). Stop the old node before running launch_init again."
    fi
}

start_arm_node() {
    local arm_label="$1"
    local can_name="$2"
    local ns="$3"
    local node_name="$4"
    local log_file="$5"

    log "Starting ${arm_label} arm node in namespace ${ns}..."
    : >"${log_file}"

    rosrun piper piper_ctrl_single_node.py \
        __ns:="${ns}" \
        __name:="${node_name}" \
        _can_port:="${can_name}" \
        _auto_enable:="${AUTO_ENABLE}" \
        _gripper_exist:="${GRIPPER_EXIST}" \
        _gripper_val_mutiple:="${GRIPPER_VALUE_MULTIPLE}" \
        joint_ctrl_single:=joint_states \
        >"${log_file}" 2>&1 &

    local pid="$!"
    NODE_PIDS+=("${pid}")
    NODE_LOGS+=("${log_file}")
    log "${arm_label} arm PID=${pid}, log=${log_file}"
}

wait_for_service_ready() {
    local service="$1"
    local pid="$2"
    local log_file="$3"
    local start_time="$SECONDS"

    while (( SECONDS - start_time < SERVICE_WAIT_TIMEOUT_SEC )); do
        if rosservice info "${service}" >/dev/null 2>&1; then
            log "Service ready: ${service}"
            return 0
        fi
        if ! kill -0 "${pid}" >/dev/null 2>&1; then
            warn "Node PID ${pid} exited before ${service} became ready."
            tail -n 40 "${log_file}" >&2 || true
            return 1
        fi
        sleep 0.2
    done

    warn "Timed out waiting for ${service}. Recent log:"
    tail -n 40 "${log_file}" >&2 || true
    return 1
}

call_enable_service() {
    local service="$1"
    local output

    log "Calling ${service}..."
    if ! output="$(rosservice call "${service}" "enable_request: true" 2>&1)"; then
        die "Failed to call ${service}: ${output}"
    fi

    if ! grep -Eiq 'enable_response:[[:space:]]*true' <<<"${output}"; then
        die "${service} returned failure: ${output}"
    fi

    log "${service} returned success."
}

call_go_zero_service() {
    local service="$1"
    local output

    log "Calling ${service} with is_mit_mode=${GO_ZERO_MIT_MODE}..."
    if ! output="$(rosservice call "${service}" "is_mit_mode: ${GO_ZERO_MIT_MODE}" 2>&1)"; then
        die "Failed to call ${service}: ${output}"
    fi

    if ! grep -Eiq 'status:[[:space:]]*true' <<<"${output}"; then
        die "${service} returned failure: ${output}"
    fi

    log "${service} returned success."
}

print_summary() {
    cat <<EOF

[launch_init] Dual-arm bringup complete.
[launch_init] Command topics:
[launch_init]   ${LEFT_NS}/joint_states
[launch_init]   ${RIGHT_NS}/joint_states
[launch_init] Feedback topics:
[launch_init]   ${LEFT_NS}/joint_states_single
[launch_init]   ${RIGHT_NS}/joint_states_single
[launch_init] Services:
[launch_init]   $(service_name "${LEFT_NS}" "enable_srv")
[launch_init]   $(service_name "${RIGHT_NS}" "enable_srv")
[launch_init]   $(service_name "${LEFT_NS}" "go_zero_srv")
[launch_init]   $(service_name "${RIGHT_NS}" "go_zero_srv")
[launch_init] Logs:
[launch_init]   ${LEFT_NODE_LOG}
[launch_init]   ${RIGHT_NODE_LOG}
[launch_init] Press Ctrl-C to stop both arm nodes$( [[ "${ROSCORE_STARTED_BY_SCRIPT}" == "true" ]] && printf ' and roscore' ).
EOF
}

cleanup() {
    local exit_code=$?
    trap - EXIT INT TERM

    for pid in "${NODE_PIDS[@]:-}"; do
        if kill -0 "${pid}" >/dev/null 2>&1; then
            kill "${pid}" >/dev/null 2>&1 || true
        fi
    done

    if [[ "${ROSCORE_STARTED_BY_SCRIPT}" == "true" ]] && [[ -n "${ROSCORE_PID}" ]]; then
        if kill -0 "${ROSCORE_PID}" >/dev/null 2>&1; then
            kill "${ROSCORE_PID}" >/dev/null 2>&1 || true
        fi
    fi

    wait >/dev/null 2>&1 || true
    exit "${exit_code}"
}

monitor_nodes() {
    while true; do
        local idx
        for idx in "${!NODE_PIDS[@]}"; do
            if ! kill -0 "${NODE_PIDS[$idx]}" >/dev/null 2>&1; then
                warn "Node process ${NODE_PIDS[$idx]} exited unexpectedly. Recent log:"
                tail -n 60 "${NODE_LOGS[$idx]}" >&2 || true
                return 1
            fi
        done
        sleep 1
    done
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi

    if (( $# > 0 )); then
        usage
        die "Unknown arguments: $*"
    fi

    LEFT_NS="$(normalize_ns "${LEFT_NS}")"
    RIGHT_NS="$(normalize_ns "${RIGHT_NS}")"

    [[ "${LEFT_NS}" != "${RIGHT_NS}" ]] || die "LEFT_NS and RIGHT_NS must be different."
    [[ "${LEFT_CAN_NAME}" != "${RIGHT_CAN_NAME}" ]] || die "LEFT_CAN_NAME and RIGHT_CAN_NAME must be different."
    [[ "${LEFT_USB_BUS}" != "${RIGHT_USB_BUS}" ]] || die "LEFT_USB_BUS and RIGHT_USB_BUS must be different."
    if [[ "${GO_ZERO_ON_START}" == "true" && "${AUTO_ENABLE}" != "true" && "${FORCE_ENABLE_ON_START}" != "true" ]]; then
        warn "GO_ZERO_ON_START=true while AUTO_ENABLE=false and FORCE_ENABLE_ON_START=false. Go-zero may fail if the arms are not already enabled."
    fi

    ensure_prerequisites
    trap cleanup EXIT INT TERM

    activate_can "${RIGHT_CAN_NAME}" "${RIGHT_USB_BUS}"
    activate_can "${LEFT_CAN_NAME}" "${LEFT_USB_BUS}"
    switch_move_mode_if_needed

    start_roscore_if_needed
    ensure_namespace_available "${RIGHT_NS}"
    ensure_namespace_available "${LEFT_NS}"

    start_arm_node "right" "${RIGHT_CAN_NAME}" "${RIGHT_NS}" "piper_ctrl_right_node" "${RIGHT_NODE_LOG}"
    local right_pid="${NODE_PIDS[0]}"
    start_arm_node "left" "${LEFT_CAN_NAME}" "${LEFT_NS}" "piper_ctrl_left_node" "${LEFT_NODE_LOG}"
    local left_pid="${NODE_PIDS[1]}"

    local right_enable_srv
    local left_enable_srv
    local right_zero_srv
    local left_zero_srv

    right_enable_srv="$(service_name "${RIGHT_NS}" "enable_srv")"
    left_enable_srv="$(service_name "${LEFT_NS}" "enable_srv")"
    right_zero_srv="$(service_name "${RIGHT_NS}" "go_zero_srv")"
    left_zero_srv="$(service_name "${LEFT_NS}" "go_zero_srv")"

    wait_for_service_ready "${right_enable_srv}" "${right_pid}" "${RIGHT_NODE_LOG}" || die "Right arm service startup failed."
    wait_for_service_ready "${left_enable_srv}" "${left_pid}" "${LEFT_NODE_LOG}" || die "Left arm service startup failed."

    if [[ "${FORCE_ENABLE_ON_START}" == "true" ]]; then
        call_enable_service "${right_enable_srv}"
        call_enable_service "${left_enable_srv}"
        sleep "${POST_ENABLE_SLEEP_SEC}"
    fi

    if [[ "${GO_ZERO_ON_START}" == "true" ]]; then
        call_go_zero_service "${right_zero_srv}"
        call_go_zero_service "${left_zero_srv}"
    fi

    print_summary
    monitor_nodes
}

main "$@"
