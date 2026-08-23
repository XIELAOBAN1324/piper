#!/usr/bin/env python3
# -*-coding:utf8-*-
# 双 CAN 主从遥操桥接节点
import sys
import time

import rosnode
import rospy
from std_msgs.msg import Float64MultiArray, String
from std_srvs.srv import Trigger, TriggerResponse

from piper_sdk import C_PiperInterface_V2


def check_ros_master():
    try:
        rosnode.rosnode_ping("rosout", max_count=1, verbose=False)
    except rosnode.ROSNodeIOException as exc:
        raise RuntimeError("ROS Master is not running.") from exc


def read_bool_param(name, default):
    value = rospy.get_param(name, default)
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in ("true", "1", "yes", "y", "on"):
            return True
        if normalized in ("false", "0", "no", "n", "off"):
            return False
    raise rospy.ROSInitException(f"{name} must be a boolean value.")


class CPiperMasterSlaveBridgeNode:
    ENABLE_TIMEOUT_SEC = 5.0
    ENABLE_RETRY_SEC = 0.5

    def __init__(self):
        check_ros_master()
        rospy.init_node("piper_master_slave_bridge_node", anonymous=False)

        self.master_can_port = rospy.get_param("~master_can_port", "can0")
        self.slave_can_port = rospy.get_param("~slave_can_port", "can1")
        self.bridge_rate_hz = float(rospy.get_param("~bridge_rate_hz", 200))
        self.command_timeout_sec = float(rospy.get_param("~command_timeout_sec", 0.5))
        self.auto_enable_slave = read_bool_param("~auto_enable_slave", True)
        self.follow_gripper = read_bool_param("~follow_gripper", True)
        self.hold_last_joint_on_timeout = read_bool_param("~hold_last_joint_on_timeout", True)
        self.shutdown_after_finish = read_bool_param("~shutdown_after_finish", True)
        self.go_home_mode2_recover_slave_before_request = read_bool_param(
            "~go_home_mode2_recover_slave_before_request",
            False,
        )
        self.go_home_mode2_request_count = int(rospy.get_param("~go_home_mode2_request_count", 1))
        self.go_home_mode2_request_interval_sec = float(
            rospy.get_param("~go_home_mode2_request_interval_sec", 0.2)
        )
        self.go_home_mode2_forward_after_request_sec = float(
            rospy.get_param("~go_home_mode2_forward_after_request_sec", 2.5)
        )
        self.go_home_mode2_observe_interval_sec = float(
            rospy.get_param("~go_home_mode2_observe_interval_sec", 0.2)
        )
        self.go_home_mode2_stop_forward_on_master_standby = read_bool_param(
            "~go_home_mode2_stop_forward_on_master_standby",
            True,
        )
        self.record_enable = read_bool_param("~record_enable", False)
        self.record_rate_hz = float(rospy.get_param("~record_rate_hz", 30.0))
        self.record_slave_pose_topic = rospy.get_param(
            "~record_slave_pose_topic",
            "/piper_dataset/slave_pose_action",
        )
        self.record_event_topic = rospy.get_param(
            "~record_event_topic",
            "/piper_dataset/record_event",
        )

        self._validate_params()

        self.bridge_armed = False
        self.bridge_paused = False
        self.bridge_forwarding_stopped = False
        self.fault_latched = False
        self.last_forwarded_motion_ctrl_1_ts = 0.0
        self.last_forwarded_joint_ts = 0.0
        self.last_forwarded_gripper_ts = 0.0
        self.last_motion_ctrl_1 = None
        self.last_motion_ctrl_1_ts = 0.0
        self.last_mode_ctrl = None
        self.last_mode_ts = 0.0
        self.last_joint_ctrl = None
        self.last_joint_ts = 0.0
        self.last_gripper_ctrl = None
        self.last_gripper_ts = 0.0
        self.accept_master_frames_after_ts = 0.0
        self.holding_stale_joint_target = False
        self.recording_stopped = False
        self.last_record_publish_time = None

        self.master = None
        self.slave = None
        self.rate = rospy.Rate(self.bridge_rate_hz)
        self.record_period = (
            rospy.Duration(1.0 / self.record_rate_hz)
            if self.record_enable
            else rospy.Duration(0.0)
        )
        self.record_slave_pose_pub = None
        self.record_event_pub = None
        if self.record_enable:
            self.record_slave_pose_pub = rospy.Publisher(
                self.record_slave_pose_topic,
                Float64MultiArray,
                queue_size=10,
            )
            self.record_event_pub = rospy.Publisher(
                self.record_event_topic,
                String,
                queue_size=10,
                latch=True,
            )
        self.finish_teach_service = rospy.Service(
            "finish_teach_and_go_zero_srv",
            Trigger,
            self.handle_finish_teach_and_go_zero_service,
        )

        self._connect_interfaces()
        rospy.on_shutdown(self._on_shutdown)
        self._publish_record_event("record_start")
        self._log_config()

    def _validate_params(self):
        if self.master_can_port == self.slave_can_port:
            raise rospy.ROSInitException("master_can_port and slave_can_port must be different CAN interfaces.")
        if self.bridge_rate_hz <= 0:
            raise rospy.ROSInitException("bridge_rate_hz must be greater than 0.")
        if self.command_timeout_sec <= 0:
            raise rospy.ROSInitException("command_timeout_sec must be greater than 0.")
        if self.go_home_mode2_request_count <= 0:
            raise rospy.ROSInitException("go_home_mode2_request_count must be greater than 0.")
        if self.go_home_mode2_request_interval_sec < 0:
            raise rospy.ROSInitException(
                "go_home_mode2_request_interval_sec must be greater than or equal to 0."
            )
        if self.go_home_mode2_forward_after_request_sec <= 0:
            raise rospy.ROSInitException(
                "go_home_mode2_forward_after_request_sec must be greater than 0."
            )
        if self.go_home_mode2_observe_interval_sec <= 0:
            raise rospy.ROSInitException(
                "go_home_mode2_observe_interval_sec must be greater than 0."
            )
        if not self.record_enable:
            return
        if self.record_rate_hz <= 0:
            raise rospy.ROSInitException("record_rate_hz must be greater than 0.")
        if not self.record_slave_pose_topic:
            raise rospy.ROSInitException("record_slave_pose_topic must not be empty.")
        if not self.record_event_topic:
            raise rospy.ROSInitException("record_event_topic must not be empty.")

    def _connect_interfaces(self):
        try:
            self.master = C_PiperInterface_V2(can_name=self.master_can_port)
            self.master.ConnectPort(piper_init=False)
            self.slave = C_PiperInterface_V2(can_name=self.slave_can_port)
            self.slave.ConnectPort(piper_init=False)
        except Exception as exc:
            self._safe_disconnect(self.master, "master")
            self._safe_disconnect(self.slave, "slave")
            rospy.logerr("Failed to connect CAN interfaces: %s", exc)
            raise

    def _log_config(self):
        rospy.loginfo("Master-slave bridge config:")
        rospy.loginfo("master_can_port: %s", self.master_can_port)
        rospy.loginfo("slave_can_port: %s", self.slave_can_port)
        rospy.loginfo("bridge_rate_hz: %.2f", self.bridge_rate_hz)
        rospy.loginfo("command_timeout_sec: %.3f", self.command_timeout_sec)
        rospy.loginfo("auto_enable_slave: %s", self.auto_enable_slave)
        rospy.loginfo("follow_gripper: %s", self.follow_gripper)
        rospy.loginfo("hold_last_joint_on_timeout: %s", self.hold_last_joint_on_timeout)
        rospy.loginfo(
            "go_home_mode2_recover_slave_before_request: %s",
            self.go_home_mode2_recover_slave_before_request,
        )
        rospy.loginfo("go_home_mode2_request_count: %d", self.go_home_mode2_request_count)
        rospy.loginfo("go_home_mode2_request_interval_sec: %.3f", self.go_home_mode2_request_interval_sec)
        rospy.loginfo(
            "go_home_mode2_forward_after_request_sec: %.3f",
            self.go_home_mode2_forward_after_request_sec,
        )
        rospy.loginfo("go_home_mode2_observe_interval_sec: %.3f", self.go_home_mode2_observe_interval_sec)
        rospy.loginfo(
            "go_home_mode2_stop_forward_on_master_standby: %s",
            self.go_home_mode2_stop_forward_on_master_standby,
        )
        rospy.loginfo("record_enable: %s", self.record_enable)
        rospy.loginfo("record_rate_hz: %.2f", self.record_rate_hz)
        rospy.loginfo("record_slave_pose_topic: %s", self.record_slave_pose_topic)
        rospy.loginfo("record_event_topic: %s", self.record_event_topic)
        rospy.loginfo("shutdown_after_finish: %s", self.shutdown_after_finish)

    def _safe_disconnect(self, interface, interface_name):
        if interface is None:
            return
        try:
            interface.DisconnectPort()
        except Exception as exc:
            rospy.logwarn("Failed to disconnect %s interface cleanly: %s", interface_name, exc)

    def _on_shutdown(self):
        self._publish_record_event("record_shutdown")
        self._safe_disconnect(self.master, "master")
        self._safe_disconnect(self.slave, "slave")

    def _publish_record_event(self, event):
        if not self.record_enable or self.record_event_pub is None:
            return
        try:
            self.record_event_pub.publish(String(data=event))
        except Exception as exc:
            rospy.logwarn_throttle(2.0, "Failed to publish record event %s: %s", event, exc)

    def _is_fresh(self, msg_timestamp):
        if msg_timestamp <= 0:
            return False
        if self.accept_master_frames_after_ts > 0 and msg_timestamp <= self.accept_master_frames_after_ts:
            return False
        return (time.time() - msg_timestamp) <= self.command_timeout_sec

    def _enable_slave_if_needed(self):
        if not self.auto_enable_slave:
            return True

        if all(self.slave.GetArmEnableStatus()):
            if self.follow_gripper:
                self.slave.GripperCtrl(0, 1000, 0x01, 0x00)
            return True

        rospy.loginfo("Fresh master control frames detected. Enabling slave arm...")
        start_time = time.time()
        while not rospy.is_shutdown() and (time.time() - start_time) <= self.ENABLE_TIMEOUT_SEC:
            self.slave.EnableArm(7)
            if self.follow_gripper:
                self.slave.GripperCtrl(0, 1000, 0x01, 0x00)
            rospy.sleep(self.ENABLE_RETRY_SEC)
            if all(self.slave.GetArmEnableStatus()):
                rospy.loginfo("Slave arm enabled successfully.")
                return True

        return all(self.slave.GetArmEnableStatus())

    def _forward_motion_ctrl(self, motion_ctrl):
        self.slave.MotionCtrl_2(
            motion_ctrl.ctrl_mode,
            motion_ctrl.move_mode,
            motion_ctrl.move_spd_rate_ctrl,
            motion_ctrl.mit_mode,
            motion_ctrl.residence_time,
            motion_ctrl.installation_pos,
        )

    def _forward_motion_ctrl_1(self, motion_ctrl_1):
        self.slave.MotionCtrl_1(
            motion_ctrl_1.emergency_stop,
            motion_ctrl_1.track_ctrl,
            motion_ctrl_1.grag_teach_ctrl,
        )

    def _forward_joint_ctrl(self, joint_ctrl):
        self.slave.JointCtrl(
            joint_ctrl.joint_1,
            joint_ctrl.joint_2,
            joint_ctrl.joint_3,
            joint_ctrl.joint_4,
            joint_ctrl.joint_5,
            joint_ctrl.joint_6,
        )

    def _forward_gripper_ctrl(self, gripper_ctrl):
        self.slave.GripperCtrl(
            abs(gripper_ctrl.grippers_angle),
            gripper_ctrl.grippers_effort,
            gripper_ctrl.status_code,
            gripper_ctrl.set_zero,
        )

    def _get_master_motion_ctrl_1(self):
        for getter_name in ("GetArmCtrlCode150", "GetArmMotionCtrl1", "GetArmMotionCtrl_1"):
            getter = getattr(self.master, getter_name, None)
            if callable(getter):
                return getter()
        return None

    def _cache_motion_ctrl_1(self, motion_ctrl_1_msg):
        if motion_ctrl_1_msg is None or motion_ctrl_1_msg.time_stamp <= 0:
            return
        if motion_ctrl_1_msg.time_stamp >= self.last_motion_ctrl_1_ts:
            motion_ctrl_1 = getattr(motion_ctrl_1_msg, "ctrl_150", None)
            if motion_ctrl_1 is None:
                motion_ctrl_1 = getattr(motion_ctrl_1_msg, "motion_ctrl_1", None)
            if motion_ctrl_1 is None:
                return
            self.last_motion_ctrl_1 = motion_ctrl_1
            self.last_motion_ctrl_1_ts = motion_ctrl_1_msg.time_stamp

    def _cache_mode_ctrl(self, mode_msg):
        if mode_msg.time_stamp <= 0:
            return
        if mode_msg.time_stamp >= self.last_mode_ts:
            self.last_mode_ctrl = mode_msg.ctrl_151
            self.last_mode_ts = mode_msg.time_stamp

    def _cache_joint_ctrl(self, joint_msg):
        if joint_msg.time_stamp <= 0:
            return
        if joint_msg.time_stamp >= self.last_joint_ts:
            self.last_joint_ctrl = joint_msg.joint_ctrl
            self.last_joint_ts = joint_msg.time_stamp

    def _cache_gripper_ctrl(self, gripper_msg):
        if gripper_msg is None or gripper_msg.time_stamp <= 0:
            return
        if gripper_msg.time_stamp >= self.last_gripper_ts:
            self.last_gripper_ctrl = gripper_msg.gripper_ctrl
            self.last_gripper_ts = gripper_msg.time_stamp

    def _send_emergency_stop(self, interface, name):
        try:
            emergency_stop = getattr(interface, "EmergencyStop", None)
            if callable(emergency_stop):
                rospy.logerr("[SAFETY][DANGEROUS] Sending EmergencyStop(0x01) to %s arm. Fault path only.", name)
                emergency_stop(0x01)
                rospy.logerr("Sent emergency stop to %s arm via EmergencyStop(0x01).", name)
            else:
                # Older SDKs do not expose EmergencyStop(); 0x150 emergency_stop=0x01 is the legacy equivalent.
                rospy.logerr(
                    "[SAFETY][DANGEROUS] Sending MotionCtrl_1(0x01, 0x00, 0x00) to %s arm. Fault path only.",
                    name,
                )
                interface.MotionCtrl_1(0x01, 0x00, 0x00)
                rospy.logerr("Sent emergency stop to %s arm via legacy MotionCtrl_1(0x01, 0x00, 0x00).", name)
            return True
        except Exception as exc:
            rospy.logerr("Failed to send emergency stop to %s arm: %s", name, exc)
            return False

    def _send_slave_emergency_stop(self):
        return self._send_emergency_stop(self.slave, "slave")

    def _pause_slave_motion_safely(self):
        current = self._joint_values_from_interface(self.slave)
        if current is None:
            rospy.logerr("[bridge][slave] cannot read current joints; refusing safe pause")
            return False
        try:
            self.slave.JointCtrl(*[int(round(value)) for value in current])
        except Exception as exc:
            rospy.logwarn_throttle(2.0, "Failed to send slave hold-current JointCtrl during safe pause: %s", exc)
            return False
        rospy.loginfo_throttle(
            1.0,
            "Paused slave motion by continuously holding current joints: %s",
            self._format_joint_values_deg(current),
        )
        return True

    def _hold_slave_position(self):
        return self._pause_slave_motion_safely()

    def _latch_fault(self, reason):
        if self.fault_latched:
            return

        self.fault_latched = True
        rospy.logerr(
            "[SAFETY][DANGEROUS] %s Emergency-stopping slave arm and latching fault until node restart.",
            reason,
        )
        # Fault-only path. The finish service must never call EmergencyStop(0x01).
        self._send_slave_emergency_stop()

    def _pause_bridge(self, reason):
        if not self.bridge_paused:
            self.bridge_paused = True
            rospy.logwarn("%s Pausing slave motion safely and waiting for master joint frames to resume.", reason)
        self._hold_slave_position()

    def _joint_values_from_interface(self, interface):
        try:
            joint_wrapper = interface.GetArmJointMsgs()
            if joint_wrapper.time_stamp <= 0:
                return None
            joint_state = joint_wrapper.joint_state
            return [
                joint_state.joint_1,
                joint_state.joint_2,
                joint_state.joint_3,
                joint_state.joint_4,
                joint_state.joint_5,
                joint_state.joint_6,
            ]
        except Exception as exc:
            rospy.logwarn_throttle(2.0, "Failed to read arm joint feedback: %s", exc)
            return None

    def _call_first_available_getter(self, interface, getter_names, label):
        for getter_name in getter_names:
            getter = getattr(interface, getter_name, None)
            if callable(getter):
                try:
                    return getter()
                except Exception as exc:
                    rospy.logwarn_throttle(2.0, "Failed to read %s via %s: %s", label, getter_name, exc)
                    return None
        rospy.logwarn_throttle(5.0, "No compatible Piper SDK getter found for %s.", label)
        return None

    def _read_slave_joint_deg(self):
        wrapper = self._call_first_available_getter(
            self.slave,
            ("GetArmJointMsgs", "GetArmJointFeedbackMsgs", "GetArmJointFeedback"),
            "slave joint feedback",
        )
        if wrapper is None or getattr(wrapper, "time_stamp", 0) <= 0:
            return None

        joint_state = getattr(wrapper, "joint_state", None)
        if joint_state is None:
            joint_state = getattr(wrapper, "arm_joint_feedback", None)
        if joint_state is None:
            rospy.logwarn_throttle(2.0, "Slave joint feedback has no joint_state field.")
            return None

        try:
            return [
                float(getattr(joint_state, "joint_1")) / 1000.0,
                float(getattr(joint_state, "joint_2")) / 1000.0,
                float(getattr(joint_state, "joint_3")) / 1000.0,
                float(getattr(joint_state, "joint_4")) / 1000.0,
                float(getattr(joint_state, "joint_5")) / 1000.0,
                float(getattr(joint_state, "joint_6")) / 1000.0,
            ]
        except Exception as exc:
            rospy.logwarn_throttle(2.0, "Failed to parse slave joint feedback: %s", exc)
            return None

    def _read_slave_end_pose(self):
        # Getter names vary across Piper SDK snapshots; keep this read-only compatibility list local.
        wrapper = self._call_first_available_getter(
            self.slave,
            ("GetArmEndPoseMsgs", "GetArmEndPoseMsg", "GetArmEndPoseFeedback"),
            "slave end pose feedback",
        )
        if wrapper is None or getattr(wrapper, "time_stamp", 0) <= 0:
            return None

        end_pose = getattr(wrapper, "end_pose", None)
        if end_pose is None:
            end_pose = getattr(wrapper, "arm_end_pose", None)
        if end_pose is None:
            rospy.logwarn_throttle(2.0, "Slave end pose feedback has no end_pose field.")
            return None

        try:
            return [
                float(getattr(end_pose, "X_axis")) / 1000.0,
                float(getattr(end_pose, "Y_axis")) / 1000.0,
                float(getattr(end_pose, "Z_axis")) / 1000.0,
                float(getattr(end_pose, "RX_axis")) / 1000.0,
                float(getattr(end_pose, "RY_axis")) / 1000.0,
                float(getattr(end_pose, "RZ_axis")) / 1000.0,
            ]
        except Exception as exc:
            rospy.logwarn_throttle(2.0, "Failed to parse slave end pose feedback: %s", exc)
            return None

    def _read_slave_gripper_mm(self):
        # Some SDK versions expose gripper feedback under slightly different names.
        wrapper = self._call_first_available_getter(
            self.slave,
            ("GetArmGripperMsgs", "GetArmGripperMsg", "GetArmGripperFeedback"),
            "slave gripper feedback",
        )
        if wrapper is None or getattr(wrapper, "time_stamp", 0) <= 0:
            return float("nan")

        gripper_state = getattr(wrapper, "gripper_state", None)
        if gripper_state is None:
            gripper_state = getattr(wrapper, "gripper_feedback", None)
        if gripper_state is None:
            rospy.logwarn_throttle(2.0, "Slave gripper feedback has no gripper_state field.")
            return float("nan")

        try:
            return float(getattr(gripper_state, "grippers_angle")) / 1000.0
        except Exception as exc:
            rospy.logwarn_throttle(2.0, "Failed to parse slave gripper feedback: %s", exc)
            return float("nan")

    def _publish_slave_pose_action(self):
        timestamp_sec = rospy.Time.now().to_sec()
        joint_deg = self._read_slave_joint_deg()
        end_pose = self._read_slave_end_pose()
        if joint_deg is None:
            rospy.logwarn_throttle(2.0, "Skipping record frame because slave joint feedback is unavailable.")
            return False
        if end_pose is None:
            rospy.logwarn_throttle(2.0, "Skipping record frame because slave end pose feedback is unavailable.")
            return False

        msg = Float64MultiArray()
        msg.data = [timestamp_sec] + joint_deg + end_pose + [self._read_slave_gripper_mm()]
        if self.record_slave_pose_pub is None:
            return False
        self.record_slave_pose_pub.publish(msg)
        return True

    def _maybe_publish_record_frame(self):
        if not self.record_enable or self.recording_stopped:
            return

        now = rospy.Time.now()
        if self.last_record_publish_time is not None and now - self.last_record_publish_time < self.record_period:
            return

        if self._publish_slave_pose_action():
            self.last_record_publish_time = now

    def _status_from_interface(self, interface):
        try:
            status_wrapper = interface.GetArmStatus()
            if status_wrapper.time_stamp <= 0:
                return None
            return status_wrapper.arm_status
        except Exception as exc:
            rospy.logwarn_throttle(2.0, "Failed to read arm status feedback: %s", exc)
            return None

    def _arm_enable_status(self, interface):
        try:
            return interface.GetArmEnableStatus()
        except Exception:
            return None

    def _safe_int(self, value):
        try:
            return int(value)
        except Exception:
            return None

    def _status_value(self, status, field_name):
        if status is None:
            return None
        return self._safe_int(getattr(status, field_name, None))

    def _format_joint_values_deg(self, joint_values):
        if joint_values is None:
            return "unavailable"
        return "[" + ", ".join(f"{value / 1000.0:.3f}" for value in joint_values) + "]"

    def _snapshot_arm_state(self, interface, name):
        joint_values = self._joint_values_from_interface(interface)
        status = self._status_from_interface(interface)
        return {
            "name": name,
            "joint_values": joint_values,
            "joint_values_deg": self._format_joint_values_deg(joint_values),
            "ctrl_mode": self._status_value(status, "ctrl_mode"),
            "arm_status": self._status_value(status, "arm_status"),
            "mode_feed": self._status_value(status, "mode_feed"),
            "teach_status": self._status_value(status, "teach_status"),
            "motion_status": self._status_value(status, "motion_status"),
            "err_code": self._safe_int(getattr(status, "err_code", None)) if status is not None else None,
            "enable_status": self._arm_enable_status(interface),
        }

    def _log_go_home_mode2_bridge_state(self):
        rospy.loginfo(
            "[go_home_mode2] bridge_armed=%s bridge_paused=%s fault_latched=%s",
            self.bridge_armed,
            self.bridge_paused,
            self.fault_latched,
        )

    def _log_go_home_mode2_arm_snapshot(self, interface, name, label):
        snapshot = self._snapshot_arm_state(interface, name)
        rospy.loginfo(
            "[go_home_mode2] %s %s ctrl_mode=%s mode_feed=%s teach_status=%s motion_status=%s "
            "enable_status=%s joints=%s err_code=%s",
            label,
            snapshot["name"],
            snapshot["ctrl_mode"],
            snapshot["mode_feed"],
            snapshot["teach_status"],
            snapshot["motion_status"],
            snapshot["enable_status"],
            snapshot["joint_values_deg"],
            snapshot["err_code"],
        )

    def _log_arm_snapshot(self, snapshot, level=rospy.loginfo):
        level(
            "[go_home_mode2] %s ctrl_mode=%s arm_status=%s motion_status=%s enable_status=%s joints=%s "
            "mode_feed=%s teach_status=%s err_code=%s",
            snapshot["name"],
            snapshot["ctrl_mode"],
            snapshot["arm_status"],
            snapshot["motion_status"],
            snapshot["enable_status"],
            snapshot["joint_values_deg"],
            snapshot["mode_feed"],
            snapshot["teach_status"],
            snapshot["err_code"],
        )

    def _request_shutdown_soon(self, reason):
        def _shutdown(_event):
            rospy.signal_shutdown(reason)

        rospy.Timer(rospy.Duration(0.2), _shutdown, oneshot=True)

    def _bridge_master_commands(self):
        if self.bridge_forwarding_stopped:
            return

        motion_ctrl_1_msg = self._get_master_motion_ctrl_1()
        mode_msg = self.master.GetArmCtrlCode151()
        joint_msg = self.master.GetArmJointCtrl()
        gripper_msg = self.master.GetArmGripperCtrl() if self.follow_gripper else None

        motion_ctrl_1_fresh = motion_ctrl_1_msg is not None and self._is_fresh(motion_ctrl_1_msg.time_stamp)
        mode_fresh = self._is_fresh(mode_msg.time_stamp)
        joint_fresh = self._is_fresh(joint_msg.time_stamp)

        if motion_ctrl_1_fresh:
            self._cache_motion_ctrl_1(motion_ctrl_1_msg)
        if mode_fresh:
            self._cache_mode_ctrl(mode_msg)
        if joint_fresh:
            self._cache_joint_ctrl(joint_msg)
        if self.follow_gripper and gripper_msg is not None and self._is_fresh(gripper_msg.time_stamp):
            self._cache_gripper_ctrl(gripper_msg)

        if not self.bridge_armed:
            mode_ready = self.last_mode_ctrl is not None
            if not joint_fresh or not mode_ready:
                mode_state = "ready" if mode_ready else "missing"
                joint_state = "fresh" if joint_fresh else "waiting"
                rospy.logwarn_throttle(
                    5.0,
                    "Waiting for initial master control frames. "
                    f"mode={mode_state}, joint={joint_state}. "
                    "If the master arm is already in teaching mode, move it slightly to generate fresh joint frames.",
                )
                return

            if not self._enable_slave_if_needed():
                self._latch_fault("Failed to auto-enable slave arm.")
                return

            self.bridge_armed = True
            self.bridge_paused = False
            rospy.loginfo("Master control frames are valid. Bridge is armed.")
        elif not joint_fresh:
            joint_age = "n/a" if joint_msg.time_stamp <= 0 else f"{time.time() - joint_msg.time_stamp:.3f}"
            if self.hold_last_joint_on_timeout:
                if not self.holding_stale_joint_target:
                    self.holding_stale_joint_target = True
                    rospy.loginfo(
                        "Master joint control frames paused/stale (age=%ss). Holding the last cached joint target. "
                        "This is expected while the master arm is stationary." % joint_age
                    )
            else:
                self._pause_bridge(
                    "Timed out waiting for fresh master joint control frames. "
                    f"joint_age={joint_age}s."
                )
                return
        else:
            if self.holding_stale_joint_target:
                self.holding_stale_joint_target = False
                rospy.loginfo("Fresh master joint control frames resumed. Bridge forwarding resumed from live targets.")
            if self.bridge_paused:
                self.bridge_paused = False
                rospy.loginfo("Master joint control frames resumed. Bridge forwarding resumed.")

        if self.last_mode_ctrl is None:
            self._latch_fault("No cached 0x151 mode control frame is available.")
            return
        if self.last_joint_ctrl is None:
            self._latch_fault("No cached joint control frame is available.")
            return

        if (
            self.last_motion_ctrl_1 is not None
            and self.last_motion_ctrl_1_ts > self.last_forwarded_motion_ctrl_1_ts
        ):
            self._forward_motion_ctrl_1(self.last_motion_ctrl_1)
            self.last_forwarded_motion_ctrl_1_ts = self.last_motion_ctrl_1_ts

        self._forward_motion_ctrl(self.last_mode_ctrl)
        self._forward_joint_ctrl(self.last_joint_ctrl)
        self.last_forwarded_joint_ts = self.last_joint_ts

        if (
            self.follow_gripper
            and self.last_gripper_ctrl is not None
            and self.last_gripper_ts > self.last_forwarded_gripper_ts
        ):
            self._forward_gripper_ctrl(self.last_gripper_ctrl)
            self.last_forwarded_gripper_ts = self.last_gripper_ts

    def handle_finish_teach_and_go_zero_service(self, _request):
        response = TriggerResponse()
        rospy.loginfo("[go_home_mode2] received finish_teach_and_go_zero request")
        rospy.loginfo("[go_home_mode2] this service ends the current teach session")
        rospy.loginfo("[go_home_mode2] no auto software restore will be attempted after go-home")
        self._log_go_home_mode2_bridge_state()
        self._log_go_home_mode2_arm_snapshot(self.master, "master", "before request")
        self._log_go_home_mode2_arm_snapshot(self.slave, "slave", "before request")
        rospy.loginfo(
            "[go_home_mode2] no slave JointCtrl, no ModeCtrl, no MotionCtrl_2, no DisableArm, "
            "no ResetPiper, no EmergencyStop(0x01)"
        )

        self._publish_record_event("record_stop_before_go_home")
        self.recording_stopped = True

        try:
            if self.go_home_mode2_recover_slave_before_request:
                rospy.loginfo("[go_home_mode2] optional slave recovery enabled: EmergencyStop(0x02), EnableArm(7)")
                emergency_stop = getattr(self.slave, "EmergencyStop", None)
                if callable(emergency_stop):
                    emergency_stop(0x02)
                else:
                    rospy.logwarn("[go_home_mode2] slave EmergencyStop() is unavailable; skip EmergencyStop(0x02)")
                self.slave.EnableArm(7)

            for index in range(self.go_home_mode2_request_count):
                rospy.loginfo(
                    "[go_home_mode2] sending master.ReqMasterArmMoveToHome(2), count=%d/%d",
                    index + 1,
                    self.go_home_mode2_request_count,
                )
                self.master.ReqMasterArmMoveToHome(2)
                if (
                    index + 1 < self.go_home_mode2_request_count
                    and self.go_home_mode2_request_interval_sec > 0
                ):
                    rospy.sleep(self.go_home_mode2_request_interval_sec)
        except Exception as exc:
            rospy.logerr("[go_home_mode2] failed to send master.ReqMasterArmMoveToHome(2): %s", exc)
            response.success = False
            response.message = f"Failed to send ReqMasterArmMoveToHome(2): {exc}"
            return response

        rospy.loginfo(
            "[go_home_mode2] request sent; bridge will keep forwarding for at most %.3fs",
            self.go_home_mode2_forward_after_request_sec,
        )
        self._log_go_home_mode2_bridge_state()
        observe_start = time.time()
        observe_index = 0
        stopped_on_master_standby = False
        while (
            not rospy.is_shutdown()
            and (time.time() - observe_start) < self.go_home_mode2_forward_after_request_sec
        ):
            observe_index += 1
            elapsed = time.time() - observe_start
            master_snapshot = self._snapshot_arm_state(self.master, "master")
            slave_snapshot = self._snapshot_arm_state(self.slave, "slave")
            self._log_arm_snapshot(master_snapshot)
            self._log_arm_snapshot(slave_snapshot)
            if (
                self.go_home_mode2_stop_forward_on_master_standby
                and elapsed >= 0.5
                and master_snapshot["ctrl_mode"] == 0
            ):
                rospy.loginfo(
                    "[go_home_mode2] master ctrl_mode=0 detected; stop forwarding to avoid "
                    "standby/disable propagation"
                )
                stopped_on_master_standby = True
                break
            rospy.sleep(self.go_home_mode2_observe_interval_sec)

        self.bridge_forwarding_stopped = True
        if stopped_on_master_standby:
            rospy.loginfo("[go_home_mode2] stopping bridge forwarding after master standby detection")
        else:
            rospy.loginfo("[go_home_mode2] forward window elapsed; stopping bridge")

        if self.shutdown_after_finish:
            self._request_shutdown_soon("finish_teach_and_go_zero completed")
        else:
            rospy.logwarn(
                "[go_home_mode2] shutdown_after_finish=false; bridge forwarding is stopped, "
                "but node will remain alive"
            )

        response.success = True
        response.message = "Sent ReqMasterArmMoveToHome(2); bridge will shut down after bounded forwarding window."
        return response

    def run(self):
        rospy.loginfo("Master-slave bridge node started. Waiting for fresh master control frames...")
        while not rospy.is_shutdown():
            if self.fault_latched:
                self.rate.sleep()
                continue

            self._bridge_master_commands()
            self._maybe_publish_record_frame()
            self.rate.sleep()


if __name__ == "__main__":
    try:
        node = CPiperMasterSlaveBridgeNode()
        node.run()
    except (rospy.ROSException, rospy.ROSInitException, RuntimeError, ValueError) as exc:
        if rospy.core.is_initialized():
            rospy.logerr("piper_master_slave_bridge_node failed to start: %s", exc)
        else:
            print(f"piper_master_slave_bridge_node failed to start: {exc}", file=sys.stderr)
        raise SystemExit(1)
