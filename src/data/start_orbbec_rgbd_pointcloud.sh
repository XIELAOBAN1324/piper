#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ROS_SETUP="/opt/ros/noetic/setup.bash"
WS_SETUP="${REPO_ROOT}/devel/setup.bash"

log() {
    printf '[start_orbbec_rgbd_pointcloud] %s\n' "$*"
}

die() {
    printf '[start_orbbec_rgbd_pointcloud][error] %s\n' "$*" >&2
    exit 1
}

[[ -f "${ROS_SETUP}" ]] || die "Missing ROS setup file: ${ROS_SETUP}"
[[ -f "${WS_SETUP}" ]] || die "Missing workspace setup file: ${WS_SETUP}"

# shellcheck disable=SC1090
source "${ROS_SETUP}"
# shellcheck disable=SC1090
source "${WS_SETUP}"

command -v roslaunch >/dev/null 2>&1 || die "roslaunch not found after sourcing ROS environment."
command -v rospack >/dev/null 2>&1 || die "rospack not found after sourcing ROS environment."

ORBBEC_PKG="$(rospack find orbbec_camera 2>/dev/null || true)"
[[ -n "${ORBBEC_PKG}" ]] || die "Cannot find ROS package: orbbec_camera. Check source ${WS_SETUP}."

ORBBEC_LAUNCH="${ORBBEC_PKG}/launch/gemini.launch"
[[ -f "${ORBBEC_LAUNCH}" ]] || die "Missing Orbbec launch file: ${ORBBEC_LAUNCH}"

log "Using Orbbec package: ${ORBBEC_PKG}"
log "Using launch file: ${ORBBEC_LAUNCH}"
log "Starting Orbbec Gemini 2 RGBD with Y16 depth and depth point cloud."

exec roslaunch "${ORBBEC_LAUNCH}" \
    depth_format:=Y16 \
    depth_width:=640 \
    depth_height:=400 \
    depth_fps:=30 \
    ir_format:=Y8 \
    enable_ir:=false \
    enable_point_cloud:=true \
    enable_colored_point_cloud:=false \
    depth_registration:=false
