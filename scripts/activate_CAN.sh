#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${REPO_ROOT}/log/ros"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOG_DIR}/activate_CAN_${TIMESTAMP}.log"

mkdir -p "${LOG_DIR}"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[activate_CAN] Start: $(date '+%F %T')"
echo "[activate_CAN] Log file: ${LOG_FILE}"

bash "${REPO_ROOT}/src/piper_ros/can_activate.sh" can_piper_right 1000000 1-1:1.0
bash "${REPO_ROOT}/src/piper_ros/can_activate.sh" can_piper_left 1000000 1-2:1.0
# bash "${REPO_ROOT}/src/piper_ros/can_activate.sh" can_arm 1000000 3-1.3:1.0
bash "${REPO_ROOT}/src/piper_ros/can_activate.sh" can_arm1 1000000 3-1.5:1.0
# bash "${REPO_ROOT}/src/piper_ros/can_activate.sh" can_trace 500000 1-4:1.0


echo "[activate_CAN] Done: $(date '+%F %T')"
