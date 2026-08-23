#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ROS_SETUP="/opt/ros/noetic/setup.bash"
WS_SETUP="${REPO_ROOT}/devel/setup.bash"
RUNTIME_DIR="${REPO_ROOT}/.runtime"
GLOBAL_CAMERA_STATE_PATH="${RUNTIME_DIR}/current_global_camera.env"

ORBBEC_SCRIPT="${SCRIPT_DIR}/start_orbbec_rgbd_pointcloud.sh"
D405_SCRIPT="${SCRIPT_DIR}/start_d405_rgbd_pointcloud.sh"

D405_START_DELAY_SEC="${D405_START_DELAY_SEC:-5}"

D435I_SERIAL_NO="${D435I_SERIAL_NO:-109622073783}"
D435I_COLOR_WIDTH="${D435I_COLOR_WIDTH:-640}"
D435I_COLOR_HEIGHT="${D435I_COLOR_HEIGHT:-480}"
D435I_COLOR_FPS="${D435I_COLOR_FPS:-30}"
D435I_DEPTH_WIDTH="${D435I_DEPTH_WIDTH:-640}"
D435I_DEPTH_HEIGHT="${D435I_DEPTH_HEIGHT:-480}"
D435I_DEPTH_FPS="${D435I_DEPTH_FPS:-30}"
D435I_ENABLE_POINTCLOUD="${D435I_ENABLE_POINTCLOUD:-true}"
D435I_ALIGN_DEPTH="${D435I_ALIGN_DEPTH:-true}"
D435I_ENABLE_SYNC="${D435I_ENABLE_SYNC:-true}"

GLOBAL_CAMERA_TYPE="${1:-${GLOBAL_CAMERA_TYPE:-orbbec}}"
GLOBAL_CAMERA_PID=""
D405_PID=""

log() {
    printf '[start_dual_rgbd_cameras] %s\n' "$*"
}

die() {
    printf '[start_dual_rgbd_cameras][error] %s\n' "$*" >&2
    exit 1
}

is_alive() {
    local pid="$1"
    [[ -n "${pid}" ]] && kill -0 "${pid}" >/dev/null 2>&1
}

cleanup() {
    log "Stopping camera processes..."
    if is_alive "${D405_PID}"; then
        kill "${D405_PID}" >/dev/null 2>&1 || true
    fi
    if is_alive "${GLOBAL_CAMERA_PID}"; then
        kill "${GLOBAL_CAMERA_PID}" >/dev/null 2>&1 || true
    fi
    wait >/dev/null 2>&1 || true
}

validate_args() {
    if [[ "$#" -gt 1 ]]; then
        die "Usage: bash ${BASH_SOURCE[0]} [orbbec|d435i]"
    fi

    case "${GLOBAL_CAMERA_TYPE}" in
        orbbec|d435i)
            ;;
        *)
            die "Unsupported GLOBAL_CAMERA_TYPE: ${GLOBAL_CAMERA_TYPE}. Expected one of: orbbec, d435i."
            ;;
    esac
}

set_global_topics() {
    case "${GLOBAL_CAMERA_TYPE}" in
        orbbec)
            GLOBAL_RGB_TOPIC="/camera/color/image_raw"
            GLOBAL_DEPTH_TOPIC="/camera/depth/image_raw"
            GLOBAL_COLOR_INFO_TOPIC="/camera/color/camera_info"
            GLOBAL_DEPTH_INFO_TOPIC="/camera/depth/camera_info"
            GLOBAL_POINTS_TOPIC="/camera/depth/points"
            ;;
        d435i)
            GLOBAL_RGB_TOPIC="/camera/color/image_raw"
            GLOBAL_DEPTH_TOPIC="/camera/aligned_depth_to_color/image_raw"
            GLOBAL_COLOR_INFO_TOPIC="/camera/color/camera_info"
            GLOBAL_DEPTH_INFO_TOPIC="/camera/aligned_depth_to_color/camera_info"
            GLOBAL_POINTS_TOPIC="/camera/depth/color/points"
            ;;
    esac
}

write_global_camera_state() {
    mkdir -p "${RUNTIME_DIR}"
    cat >"${GLOBAL_CAMERA_STATE_PATH}" <<EOF
export GLOBAL_CAMERA_TYPE="${GLOBAL_CAMERA_TYPE}"
export GLOBAL_RGB_TOPIC="${GLOBAL_RGB_TOPIC}"
export GLOBAL_DEPTH_TOPIC="${GLOBAL_DEPTH_TOPIC}"
export GLOBAL_COLOR_INFO_TOPIC="${GLOBAL_COLOR_INFO_TOPIC}"
export GLOBAL_DEPTH_INFO_TOPIC="${GLOBAL_DEPTH_INFO_TOPIC}"
export GLOBAL_POINTS_TOPIC="${GLOBAL_POINTS_TOPIC}"
EOF
}

ensure_d435i_prerequisites() {
    [[ -f "${ROS_SETUP}" ]] || die "Missing ROS setup file: ${ROS_SETUP}"
    [[ -f "${WS_SETUP}" ]] || die "Missing workspace setup file: ${WS_SETUP}"
    # shellcheck disable=SC1090
    source "${ROS_SETUP}"
    # shellcheck disable=SC1090
    source "${WS_SETUP}"
    command -v roslaunch >/dev/null 2>&1 || die "roslaunch not found after sourcing ROS environment."
}

start_d435i_global_camera() {
    ensure_d435i_prerequisites
    exec roslaunch realsense2_camera rs_camera.launch \
        camera:=camera \
        serial_no:="${D435I_SERIAL_NO}" \
        enable_color:=true \
        enable_depth:=true \
        enable_pointcloud:="${D435I_ENABLE_POINTCLOUD}" \
        align_depth:="${D435I_ALIGN_DEPTH}" \
        enable_sync:="${D435I_ENABLE_SYNC}" \
        color_width:="${D435I_COLOR_WIDTH}" \
        color_height:="${D435I_COLOR_HEIGHT}" \
        color_fps:="${D435I_COLOR_FPS}" \
        depth_width:="${D435I_DEPTH_WIDTH}" \
        depth_height:="${D435I_DEPTH_HEIGHT}" \
        depth_fps:="${D435I_DEPTH_FPS}"
}

start_global_camera() {
    case "${GLOBAL_CAMERA_TYPE}" in
        orbbec)
            log "Starting Orbbec global camera."
            bash "${ORBBEC_SCRIPT}" &
            ;;
        d435i)
            log "Starting RealSense D435i global camera serial_no=${D435I_SERIAL_NO}."
            start_d435i_global_camera &
            ;;
    esac
    GLOBAL_CAMERA_PID="$!"
}

validate_args "$@"
set_global_topics

[[ -x "${D405_SCRIPT}" ]] || die "Missing executable D405 launcher: ${D405_SCRIPT}"
if [[ "${GLOBAL_CAMERA_TYPE}" == "orbbec" ]]; then
    [[ -x "${ORBBEC_SCRIPT}" ]] || die "Missing executable Orbbec launcher: ${ORBBEC_SCRIPT}"
fi

write_global_camera_state

log "Selected global camera: ${GLOBAL_CAMERA_TYPE}"
log "State file: ${GLOBAL_CAMERA_STATE_PATH}"
log "Global RGB topic: ${GLOBAL_RGB_TOPIC}"
log "Global depth topic: ${GLOBAL_DEPTH_TOPIC}"
log "Global pointcloud topic: ${GLOBAL_POINTS_TOPIC}"

trap cleanup EXIT INT TERM

start_global_camera

sleep 2

if ! is_alive "${GLOBAL_CAMERA_PID}"; then
    die "${GLOBAL_CAMERA_TYPE} launcher exited early. Check the global camera launch error above."
fi

log "Starting D405 wrist camera after ${D405_START_DELAY_SEC}s delay."
sleep "${D405_START_DELAY_SEC}"

bash "${D405_SCRIPT}" &
D405_PID="$!"

sleep 2

if ! is_alive "${D405_PID}"; then
    die "D405 launcher exited early. Check the D405 publisher error above."
fi

log "Both camera launchers are running."
log "Global camera PID: ${GLOBAL_CAMERA_PID}"
log "D405 PID: ${D405_PID}"
log "Press Ctrl-C to stop both."

wait -n "${GLOBAL_CAMERA_PID}" "${D405_PID}"

die "One camera process exited. The other camera process has been stopped by cleanup."
