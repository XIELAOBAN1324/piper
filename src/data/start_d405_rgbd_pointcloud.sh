#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ROS_SETUP="/opt/ros/noetic/setup.bash"
WS_SETUP="${REPO_ROOT}/devel/setup.bash"
D405_PUBLISHER="${SCRIPT_DIR}/d405_rgbd_publisher.py"

D405_SERIAL="${D405_SERIAL:-260422275047}"
D405_CAMERA_NAME="${D405_CAMERA_NAME:-d405}"
D405_COLOR_WIDTH="${D405_COLOR_WIDTH:-640}"
D405_COLOR_HEIGHT="${D405_COLOR_HEIGHT:-480}"
D405_DEPTH_WIDTH="${D405_DEPTH_WIDTH:-640}"
D405_DEPTH_HEIGHT="${D405_DEPTH_HEIGHT:-480}"
D405_FPS="${D405_FPS:-30}"

log() {
    printf '[start_d405_rgbd_pointcloud] %s\n' "$*"
}

die() {
    printf '[start_d405_rgbd_pointcloud][error] %s\n' "$*" >&2
    exit 1
}

[[ -f "${ROS_SETUP}" ]] || die "Missing ROS setup file: ${ROS_SETUP}"
[[ -f "${WS_SETUP}" ]] || die "Missing workspace setup file: ${WS_SETUP}"
[[ -f "${D405_PUBLISHER}" ]] || die "Missing D405 publisher: ${D405_PUBLISHER}"

# shellcheck disable=SC1090
source "${ROS_SETUP}"
# shellcheck disable=SC1090
source "${WS_SETUP}"

log "Starting D405 RGBD pointcloud publisher."
exec python3 "${D405_PUBLISHER}" \
    --serial "${D405_SERIAL}" \
    --camera-name "${D405_CAMERA_NAME}" \
    --color-width "${D405_COLOR_WIDTH}" \
    --color-height "${D405_COLOR_HEIGHT}" \
    --depth-width "${D405_DEPTH_WIDTH}" \
    --depth-height "${D405_DEPTH_HEIGHT}" \
    --fps "${D405_FPS}" \
    --enable-pointcloud
