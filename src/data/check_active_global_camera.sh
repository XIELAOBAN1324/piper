#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ROS_SETUP="/opt/ros/noetic/setup.bash"
WS_SETUP="${REPO_ROOT}/devel/setup.bash"
GLOBAL_CAMERA_STATE_PATH="${REPO_ROOT}/.runtime/current_global_camera.env"

HZ_WINDOW_SEC="${HZ_WINDOW_SEC:-5}"
MIN_IMAGE_HZ="${MIN_IMAGE_HZ:-25}"
RECORD_POINTCLOUD="${RECORD_POINTCLOUD:-false}"

declare -a ROS_TOPICS=()

log() {
    printf '[check_active_global_camera] %s\n' "$*"
}

warn() {
    printf '[check_active_global_camera][warn] %s\n' "$*" >&2
}

die() {
    printf '[check_active_global_camera][error] %s\n' "$*" >&2
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

ensure_prerequisites() {
    [[ -f "${ROS_SETUP}" ]] || die "Missing ROS setup file: ${ROS_SETUP}"
    [[ -f "${WS_SETUP}" ]] || die "Missing workspace setup file: ${WS_SETUP}"
    [[ -f "${GLOBAL_CAMERA_STATE_PATH}" ]] || die "No active global camera state found: ${GLOBAL_CAMERA_STATE_PATH}"

    # shellcheck disable=SC1090
    source "${ROS_SETUP}"
    # shellcheck disable=SC1090
    source "${WS_SETUP}"

    command -v rostopic >/dev/null 2>&1 || die "rostopic not found after sourcing ROS environment."
    command -v timeout >/dev/null 2>&1 || die "timeout command is required."
    command -v awk >/dev/null 2>&1 || die "awk command is required."
}

load_global_camera_state() {
    # shellcheck disable=SC1090
    source "${GLOBAL_CAMERA_STATE_PATH}"

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

refresh_topic_list() {
    local topic_output
    if ! topic_output="$(rostopic list)"; then
        die "Failed to query ROS topics with rostopic list."
    fi
    mapfile -t ROS_TOPICS <<<"${topic_output}"
}

topic_exists() {
    local topic="$1"
    local existing_topic
    for existing_topic in "${ROS_TOPICS[@]}"; do
        if [[ "${existing_topic}" == "${topic}" ]]; then
            return 0
        fi
    done
    return 1
}

check_topic_exists() {
    local topic="$1"
    if topic_exists "${topic}"; then
        log "Check topic exists: ${topic} ... OK"
        return 0
    fi
    printf '[check_active_global_camera][error] Check topic exists: %s ... MISSING\n' "${topic}" >&2
    return 1
}

measure_topic_hz() {
    local topic="$1"
    local timeout_arg="${HZ_WINDOW_SEC}"
    if [[ "${timeout_arg}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        timeout_arg="${timeout_arg}s"
    fi

    local hz_output
    hz_output="$(timeout "${timeout_arg}" rostopic hz "${topic}" 2>&1 || true)"

    local hz
    hz="$(awk '/average rate:/ { rate=$3 } END { if (rate != "") print rate }' <<<"${hz_output}")"
    if [[ -z "${hz}" ]]; then
        warn "Hz ${topic}: unable to measure within ${HZ_WINDOW_SEC}s"
        return 0
    fi

    if awk -v hz="${hz}" -v min_hz="${MIN_IMAGE_HZ}" 'BEGIN { exit !(hz < min_hz) }'; then
        warn "Hz ${topic}: ${hz} below ${MIN_IMAGE_HZ}"
    else
        log "Hz ${topic}: ${hz} OK"
    fi
}

main() {
    local pointcloud_required
    pointcloud_required="$(read_bool_env "${RECORD_POINTCLOUD}")"

    ensure_prerequisites
    load_global_camera_state

    log "Active global camera: ${GLOBAL_CAMERA_TYPE}"
    log "RGB topic: ${GLOBAL_RGB_TOPIC}"
    log "Depth topic: ${GLOBAL_DEPTH_TOPIC}"
    log "Color info topic: ${GLOBAL_COLOR_INFO_TOPIC}"
    log "Depth info topic: ${GLOBAL_DEPTH_INFO_TOPIC}"
    log "Pointcloud topic: ${GLOBAL_POINTS_TOPIC}"

    refresh_topic_list

    local missing=0
    check_topic_exists "${GLOBAL_RGB_TOPIC}" || missing=1
    check_topic_exists "${GLOBAL_DEPTH_TOPIC}" || missing=1
    check_topic_exists "${GLOBAL_COLOR_INFO_TOPIC}" || missing=1
    check_topic_exists "${GLOBAL_DEPTH_INFO_TOPIC}" || missing=1
    if [[ "${pointcloud_required}" == "true" ]]; then
        check_topic_exists "${GLOBAL_POINTS_TOPIC}" || missing=1
    fi

    if [[ "${missing}" -ne 0 ]]; then
        die "One or more required global camera topics are missing."
    fi

    measure_topic_hz "${GLOBAL_RGB_TOPIC}"
    measure_topic_hz "${GLOBAL_DEPTH_TOPIC}"
}

main "$@"
