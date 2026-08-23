// Auto-generated. Do not edit!

// (in-package moveit_ctrl.srv)


"use strict";

const _serializer = _ros_msg_utils.Serialize;
const _arraySerializer = _serializer.Array;
const _deserializer = _ros_msg_utils.Deserialize;
const _arrayDeserializer = _deserializer.Array;
const _finder = _ros_msg_utils.Find;
const _getByteLength = _ros_msg_utils.getByteLength;

//-----------------------------------------------------------


//-----------------------------------------------------------

class JointMoveitCtrlRequest {
  constructor(initObj={}) {
    if (initObj === null) {
      // initObj === null is a special case for deserialization where we don't initialize fields
      this.joint_states = null;
      this.gripper = null;
      this.joint_endpose = null;
      this.max_velocity = null;
      this.max_acceleration = null;
    }
    else {
      if (initObj.hasOwnProperty('joint_states')) {
        this.joint_states = initObj.joint_states
      }
      else {
        this.joint_states = new Array(6).fill(0);
      }
      if (initObj.hasOwnProperty('gripper')) {
        this.gripper = initObj.gripper
      }
      else {
        this.gripper = 0.0;
      }
      if (initObj.hasOwnProperty('joint_endpose')) {
        this.joint_endpose = initObj.joint_endpose
      }
      else {
        this.joint_endpose = new Array(7).fill(0);
      }
      if (initObj.hasOwnProperty('max_velocity')) {
        this.max_velocity = initObj.max_velocity
      }
      else {
        this.max_velocity = 0.0;
      }
      if (initObj.hasOwnProperty('max_acceleration')) {
        this.max_acceleration = initObj.max_acceleration
      }
      else {
        this.max_acceleration = 0.0;
      }
    }
  }

  static serialize(obj, buffer, bufferOffset) {
    // Serializes a message object of type JointMoveitCtrlRequest
    // Check that the constant length array field [joint_states] has the right length
    if (obj.joint_states.length !== 6) {
      throw new Error('Unable to serialize array field joint_states - length must be 6')
    }
    // Serialize message field [joint_states]
    bufferOffset = _arraySerializer.float64(obj.joint_states, buffer, bufferOffset, 6);
    // Serialize message field [gripper]
    bufferOffset = _serializer.float64(obj.gripper, buffer, bufferOffset);
    // Check that the constant length array field [joint_endpose] has the right length
    if (obj.joint_endpose.length !== 7) {
      throw new Error('Unable to serialize array field joint_endpose - length must be 7')
    }
    // Serialize message field [joint_endpose]
    bufferOffset = _arraySerializer.float64(obj.joint_endpose, buffer, bufferOffset, 7);
    // Serialize message field [max_velocity]
    bufferOffset = _serializer.float64(obj.max_velocity, buffer, bufferOffset);
    // Serialize message field [max_acceleration]
    bufferOffset = _serializer.float64(obj.max_acceleration, buffer, bufferOffset);
    return bufferOffset;
  }

  static deserialize(buffer, bufferOffset=[0]) {
    //deserializes a message object of type JointMoveitCtrlRequest
    let len;
    let data = new JointMoveitCtrlRequest(null);
    // Deserialize message field [joint_states]
    data.joint_states = _arrayDeserializer.float64(buffer, bufferOffset, 6)
    // Deserialize message field [gripper]
    data.gripper = _deserializer.float64(buffer, bufferOffset);
    // Deserialize message field [joint_endpose]
    data.joint_endpose = _arrayDeserializer.float64(buffer, bufferOffset, 7)
    // Deserialize message field [max_velocity]
    data.max_velocity = _deserializer.float64(buffer, bufferOffset);
    // Deserialize message field [max_acceleration]
    data.max_acceleration = _deserializer.float64(buffer, bufferOffset);
    return data;
  }

  static getMessageSize(object) {
    return 128;
  }

  static datatype() {
    // Returns string type for a service object
    return 'moveit_ctrl/JointMoveitCtrlRequest';
  }

  static md5sum() {
    //Returns md5sum for a message object
    return 'a9687e2d218d71b19ceba55344df7891';
  }

  static messageDefinition() {
    // Returns full string definition for message
    return `
    # JointMoveitCtrl.srv
    float64[6] joint_states  # 关节弧度
    float64 gripper # 夹爪张开宽度
    float64[7] joint_endpose # 末端执行器位置控制(四元数)
    float64 max_velocity # 最大速度
    float64 max_acceleration # 最大加速度
    
    `;
  }

  static Resolve(msg) {
    // deep-construct a valid message object instance of whatever was passed in
    if (typeof msg !== 'object' || msg === null) {
      msg = {};
    }
    const resolved = new JointMoveitCtrlRequest(null);
    if (msg.joint_states !== undefined) {
      resolved.joint_states = msg.joint_states;
    }
    else {
      resolved.joint_states = new Array(6).fill(0)
    }

    if (msg.gripper !== undefined) {
      resolved.gripper = msg.gripper;
    }
    else {
      resolved.gripper = 0.0
    }

    if (msg.joint_endpose !== undefined) {
      resolved.joint_endpose = msg.joint_endpose;
    }
    else {
      resolved.joint_endpose = new Array(7).fill(0)
    }

    if (msg.max_velocity !== undefined) {
      resolved.max_velocity = msg.max_velocity;
    }
    else {
      resolved.max_velocity = 0.0
    }

    if (msg.max_acceleration !== undefined) {
      resolved.max_acceleration = msg.max_acceleration;
    }
    else {
      resolved.max_acceleration = 0.0
    }

    return resolved;
    }
};

class JointMoveitCtrlResponse {
  constructor(initObj={}) {
    if (initObj === null) {
      // initObj === null is a special case for deserialization where we don't initialize fields
      this.error_code = null;
      this.status = null;
    }
    else {
      if (initObj.hasOwnProperty('error_code')) {
        this.error_code = initObj.error_code
      }
      else {
        this.error_code = 0;
      }
      if (initObj.hasOwnProperty('status')) {
        this.status = initObj.status
      }
      else {
        this.status = false;
      }
    }
  }

  static serialize(obj, buffer, bufferOffset) {
    // Serializes a message object of type JointMoveitCtrlResponse
    // Serialize message field [error_code]
    bufferOffset = _serializer.int64(obj.error_code, buffer, bufferOffset);
    // Serialize message field [status]
    bufferOffset = _serializer.bool(obj.status, buffer, bufferOffset);
    return bufferOffset;
  }

  static deserialize(buffer, bufferOffset=[0]) {
    //deserializes a message object of type JointMoveitCtrlResponse
    let len;
    let data = new JointMoveitCtrlResponse(null);
    // Deserialize message field [error_code]
    data.error_code = _deserializer.int64(buffer, bufferOffset);
    // Deserialize message field [status]
    data.status = _deserializer.bool(buffer, bufferOffset);
    return data;
  }

  static getMessageSize(object) {
    return 9;
  }

  static datatype() {
    // Returns string type for a service object
    return 'moveit_ctrl/JointMoveitCtrlResponse';
  }

  static md5sum() {
    //Returns md5sum for a message object
    return '9d34df8e5b41682097c5aaf352d8349f';
  }

  static messageDefinition() {
    // Returns full string definition for message
    return `
    int64 error_code
    bool status
    
    `;
  }

  static Resolve(msg) {
    // deep-construct a valid message object instance of whatever was passed in
    if (typeof msg !== 'object' || msg === null) {
      msg = {};
    }
    const resolved = new JointMoveitCtrlResponse(null);
    if (msg.error_code !== undefined) {
      resolved.error_code = msg.error_code;
    }
    else {
      resolved.error_code = 0
    }

    if (msg.status !== undefined) {
      resolved.status = msg.status;
    }
    else {
      resolved.status = false
    }

    return resolved;
    }
};

module.exports = {
  Request: JointMoveitCtrlRequest,
  Response: JointMoveitCtrlResponse,
  md5sum() { return '51cb988f5ae355fbe239bcbc18431f99'; },
  datatype() { return 'moveit_ctrl/JointMoveitCtrl'; }
};
