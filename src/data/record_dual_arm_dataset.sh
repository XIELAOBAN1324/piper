#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ROS_SETUP="/opt/ros/noetic/setup.bash"
WS_SETUP="${REPO_ROOT}/devel/setup.bash"
GLOBAL_CAMERA_STATE_PATH="${REPO_ROOT}/.runtime/current_global_camera.env"

DATASET_ROOT="${DATASET_ROOT:-${REPO_ROOT}/dataset/piper_teleop}"
TASK_NAME="${TASK_NAME:-default_task}"
EPISODE_NAME="${EPISODE_NAME:-episode_000001}"
RECORD_RATE_HZ="${RECORD_RATE_HZ:-30}"
RECORD_POINTCLOUD="${RECORD_POINTCLOUD:-false}"
WAIT_TOPIC_TIMEOUT_SEC="${WAIT_TOPIC_TIMEOUT_SEC:-10}"

D405_RGB_TOPIC="${D405_RGB_TOPIC:-/d405/color/image_raw}"
D405_DEPTH_TOPIC="${D405_DEPTH_TOPIC:-/d405/depth/image_rect_raw}"
D405_COLOR_INFO_TOPIC="${D405_COLOR_INFO_TOPIC:-/d405/color/camera_info}"
D405_DEPTH_INFO_TOPIC="${D405_DEPTH_INFO_TOPIC:-/d405/depth/camera_info}"
D405_POINTS_TOPIC="${D405_POINTS_TOPIC:-/d405/depth/points}"

# Fixed episode path without adding a timestamp directory.
# If the same TASK_NAME and EPISODE_NAME are used again, the script will ask
# for confirmation before deleting old data in this episode directory.
TIMESTAMP="${TIMESTAMP:-manual_fixed_path}"
EPISODE_DIR="${DATASET_ROOT}/${TASK_NAME}/${EPISODE_NAME}"
RAW_DIR="${EPISODE_DIR}/raw"
PROCESSED_DIR="${EPISODE_DIR}/processed"
BAG_PATH="${RAW_DIR}/raw.bag"
META_PATH="${EPISODE_DIR}/episode_meta.yaml"
SYNC_REPORT_PATH="${EPISODE_DIR}/sync_report.json"

log() {
    printf '[record_dual_arm_dataset] %s\n' "$*"
}

die() {
    printf '[record_dual_arm_dataset][error] %s\n' "$*" >&2
    exit 1
}

read_bool_env() {
    local value
    value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    case "${value}" in
        true|1|yes|y|on)
            printf 'true'
            ;;
        false|0|no|n|off)
            printf 'false'
            ;;
        *)
            die "RECORD_POINTCLOUD must be true or false, got: $1"
            ;;
    esac
}

load_global_camera_state() {
    if [[ ! -f "${GLOBAL_CAMERA_STATE_PATH}" ]]; then
        printf '[record_dual_arm_dataset][error] No active global camera state found.\n' >&2
        printf 'Please start one global camera first:\n' >&2
        printf '  bash scripts/data/start_dual_rgbd_cameras.sh orbbec\n' >&2
        printf 'or:\n' >&2
        printf '  bash scripts/data/start_dual_rgbd_cameras.sh d435i\n' >&2
        exit 1
    fi

    local user_global_camera_type="${GLOBAL_CAMERA_TYPE:-}"
    local user_global_rgb_topic="${GLOBAL_RGB_TOPIC:-}"
    local user_global_depth_topic="${GLOBAL_DEPTH_TOPIC:-}"
    local user_global_color_info_topic="${GLOBAL_COLOR_INFO_TOPIC:-}"
    local user_global_depth_info_topic="${GLOBAL_DEPTH_INFO_TOPIC:-}"
    local user_global_points_topic="${GLOBAL_POINTS_TOPIC:-}"

    # shellcheck disable=SC1090
    source "${GLOBAL_CAMERA_STATE_PATH}"

    [[ -n "${user_global_camera_type}" ]] && GLOBAL_CAMERA_TYPE="${user_global_camera_type}"
    [[ -n "${user_global_rgb_topic}" ]] && GLOBAL_RGB_TOPIC="${user_global_rgb_topic}"
    [[ -n "${user_global_depth_topic}" ]] && GLOBAL_DEPTH_TOPIC="${user_global_depth_topic}"
    [[ -n "${user_global_color_info_topic}" ]] && GLOBAL_COLOR_INFO_TOPIC="${user_global_color_info_topic}"
    [[ -n "${user_global_depth_info_topic}" ]] && GLOBAL_DEPTH_INFO_TOPIC="${user_global_depth_info_topic}"
    [[ -n "${user_global_points_topic}" ]] && GLOBAL_POINTS_TOPIC="${user_global_points_topic}"

    local required_var
    for required_var in \
        GLOBAL_CAMERA_TYPE \
        GLOBAL_RGB_TOPIC \
        GLOBAL_DEPTH_TOPIC \
        GLOBAL_COLOR_INFO_TOPIC \
        GLOBAL_DEPTH_INFO_TOPIC \
        GLOBAL_POINTS_TOPIC
    do
        [[ -n "${!required_var:-}" ]] || die "Missing ${required_var} in ${GLOBAL_CAMERA_STATE_PATH}."
    done
}

episode_has_existing_data() {
    [[ -e "${BAG_PATH}" ]] && return 0
    [[ -e "${BAG_PATH}.active" ]] && return 0
    [[ -e "${META_PATH}" ]] && return 0
    [[ -e "${SYNC_REPORT_PATH}" ]] && return 0

    if [[ -d "${RAW_DIR}" ]] && [[ -n "$(find "${RAW_DIR}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        return 0
    fi

    if [[ -d "${PROCESSED_DIR}" ]] && [[ -n "$(find "${PROCESSED_DIR}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        return 0
    fi

    return 1
}

confirm_overwrite_if_needed() {
    if ! episode_has_existing_data; then
        return 0
    fi

    printf '\n' >&2
    printf '[record_dual_arm_dataset][warn] Target episode path already contains data.\n' >&2
    printf '[record_dual_arm_dataset][warn] EPISODE_DIR: %s\n' "${EPISODE_DIR}" >&2
    printf '[record_dual_arm_dataset][warn] RAW_DIR    : %s\n' "${RAW_DIR}" >&2
    printf '[record_dual_arm_dataset][warn] BAG_PATH   : %s\n' "${BAG_PATH}" >&2
    printf '[record_dual_arm_dataset][warn] META_PATH  : %s\n' "${META_PATH}" >&2
    printf '[record_dual_arm_dataset][warn] PROCESSED  : %s\n' "${PROCESSED_DIR}" >&2
    printf '\n' >&2
    printf '[record_dual_arm_dataset][warn] Continuing will delete the old raw/, processed/, episode_meta.yaml and sync_report.json for this episode.\n' >&2
    printf '[record_dual_arm_dataset][warn] This prevents old processed HDF5 files from being reused by mistake.\n' >&2
    printf '\n' >&2

    if [[ ! -t 0 ]]; then
        die "Refusing to overwrite existing episode data because stdin is not an interactive terminal."
    fi

    local answer
    printf 'Type OVERWRITE to delete old episode data and start recording, or press Enter to cancel: ' >&2
    read -r answer

    if [[ "${answer}" != "OVERWRITE" ]]; then
        die "User cancelled to avoid overwriting existing episode data."
    fi

    log "Overwrite confirmed. Removing old episode data under: ${EPISODE_DIR}"
    rm -rf -- "${RAW_DIR}" "${PROCESSED_DIR}" "${META_PATH}" "${SYNC_REPORT_PATH}"
}

ensure_prerequisites() {
    [[ -f "${ROS_SETUP}" ]] || die "Missing ROS setup file: ${ROS_SETUP}"
    [[ -f "${WS_SETUP}" ]] || die "Missing workspace setup file: ${WS_SETUP}"
    # shellcheck disable=SC1090
    source "${ROS_SETUP}"
    # shellcheck disable=SC1090
    source "${WS_SETUP}"
    command -v rosbag >/dev/null 2>&1 || die "rosbag not found after sourcing ROS environment."
    command -v rostopic >/dev/null 2>&1 || die "rostopic not found after sourcing ROS environment."
    command -v timeout >/dev/null 2>&1 || die "timeout command is required."
}

wait_for_topic() {
    local topic="$1"
    local label="$2"
    local timeout_arg="${WAIT_TOPIC_TIMEOUT_SEC}"
    if [[ "${timeout_arg}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        timeout_arg="${timeout_arg}s"
    fi
    log "Waiting for ${label}: ${topic}"
    if ! timeout "${timeout_arg}" rostopic echo -n 1 "${topic}" >/dev/null; then
        die "Timed out waiting for ${label} on ${topic} after ${WAIT_TOPIC_TIMEOUT_SEC}s."
    fi
}

wait_for_required_topics() {
    local pointcloud_recorded="$1"
    wait_for_topic /piper_dataset/slave_pose_action "slave pose action"
    wait_for_topic "${GLOBAL_RGB_TOPIC}" "global RGB"
    wait_for_topic "${GLOBAL_DEPTH_TOPIC}" "global depth"
    wait_for_topic "${D405_RGB_TOPIC}" "D405 RGB"
    wait_for_topic "${D405_DEPTH_TOPIC}" "D405 depth"

    if [[ "${pointcloud_recorded}" == "true" ]]; then
        wait_for_topic "${GLOBAL_POINTS_TOPIC}" "global point cloud"
        wait_for_topic "${D405_POINTS_TOPIC}" "D405 point cloud"
    fi
}

write_meta() {
    local pointcloud_recorded="$1"
    cat >"${META_PATH}" <<EOF
task_name: "${TASK_NAME}"
episode_name: "${EPISODE_NAME}"
timestamp: "${TIMESTAMP}"
record_rate_hz: ${RECORD_RATE_HZ}
action_source: slave_feedback_pose
action_format:
  - timestamp_sec
  - slave_joint_1_deg
  - slave_joint_2_deg
  - slave_joint_3_deg
  - slave_joint_4_deg
  - slave_joint_5_deg
  - slave_joint_6_deg
  - slave_ee_x_mm
  - slave_ee_y_mm
  - slave_ee_z_mm
  - slave_ee_rx_deg
  - slave_ee_ry_deg
  - slave_ee_rz_deg
  - slave_gripper_mm
cameras:
  global_camera:
    type: "${GLOBAL_CAMERA_TYPE}"
    rgb_topic: "${GLOBAL_RGB_TOPIC}"
    depth_topic: "${GLOBAL_DEPTH_TOPIC}"
    color_camera_info_topic: "${GLOBAL_COLOR_INFO_TOPIC}"
    depth_camera_info_topic: "${GLOBAL_DEPTH_INFO_TOPIC}"
    pointcloud_topic: "${GLOBAL_POINTS_TOPIC}"
  wrist_camera:
    type: realsense_d405
    rgb_topic: "${D405_RGB_TOPIC}"
    depth_topic: "${D405_DEPTH_TOPIC}"
    color_camera_info_topic: "${D405_COLOR_INFO_TOPIC}"
    depth_camera_info_topic: "${D405_DEPTH_INFO_TOPIC}"
    pointcloud_topic: "${D405_POINTS_TOPIC}"
pointcloud_recorded: ${pointcloud_recorded}
notes: ""
EOF
}

main() {
    local pointcloud_recorded
    pointcloud_recorded="$(read_bool_env "${RECORD_POINTCLOUD}")"

    load_global_camera_state
    ensure_prerequisites
    confirm_overwrite_if_needed
    wait_for_required_topics "${pointcloud_recorded}"
    mkdir -p "${RAW_DIR}" "${PROCESSED_DIR}"
    write_meta "${pointcloud_recorded}"

    local topics=(
        /piper_dataset/slave_pose_action
        /piper_dataset/record_event
        "${GLOBAL_RGB_TOPIC}"
        "${GLOBAL_DEPTH_TOPIC}"
        "${GLOBAL_COLOR_INFO_TOPIC}"
        "${GLOBAL_DEPTH_INFO_TOPIC}"
        "${D405_RGB_TOPIC}"
        "${D405_DEPTH_TOPIC}"
        "${D405_COLOR_INFO_TOPIC}"
        "${D405_DEPTH_INFO_TOPIC}"
        /tf
        /tf_static
    )

    if [[ "${pointcloud_recorded}" == "true" ]]; then
        topics+=("${GLOBAL_POINTS_TOPIC}" "${D405_POINTS_TOPIC}")
    fi

    log "Active global camera: ${GLOBAL_CAMERA_TYPE}"
    log "Global RGB topic: ${GLOBAL_RGB_TOPIC}"
    log "Global depth topic: ${GLOBAL_DEPTH_TOPIC}"
    log "Global color info topic: ${GLOBAL_COLOR_INFO_TOPIC}"
    log "Global depth info topic: ${GLOBAL_DEPTH_INFO_TOPIC}"
    log "Global pointcloud topic: ${GLOBAL_POINTS_TOPIC}"
    log "Dataset episode directory: ${EPISODE_DIR}"
    log "Writing raw bag: ${BAG_PATH}"
    log "Writing metadata: ${META_PATH}"
    log "Recording ${#topics[@]} topics. Stop with Ctrl-C after calling finish_teach_and_go_zero_srv."

    exec rosbag record --output-name="${BAG_PATH}" "${topics[@]}"
}

main "$@"
