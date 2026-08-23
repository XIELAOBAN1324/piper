// Auto-generated. Do not edit!

// (in-package piper_msgs.srv)


"use strict";

const _serializer = _ros_msg_utils.Serialize;
const _arraySerializer = _serializer.Array;
const _deserializer = _ros_msg_utils.Deserialize;
const _arrayDeserializer = _deserializer.Array;
const _finder = _ros_msg_utils.Find;
const _getByteLength = _ros_msg_utils.getByteLength;

//-----------------------------------------------------------


//-----------------------------------------------------------

class GripperRequest {
  constructor(initObj={}) {
    if (initObj === null) {
      // initObj === null is a special case for deserialization where we don't initialize fields
      this.gripper_angle = null;
      this.gripper_effort = null;
      this.gripper_code = null;
      this.set_zero = null;
    }
    else {
      if (initObj.hasOwnProperty('gripper_angle')) {
        this.gripper_angle = initObj.gripper_angle
      }
      else {
        this.gripper_angle = 0.0;
      }
      if (initObj.hasOwnProperty('gripper_effort')) {
        this.gripper_effort = initObj.gripper_effort
      }
      else {
        this.gripper_effort = 0.0;
      }
      if (initObj.hasOwnProperty('gripper_code')) {
        this.gripper_code = initObj.gripper_code
      }
      else {
        this.gripper_code = 0;
      }
      if (initObj.hasOwnProperty('set_zero')) {
        this.set_zero = initObj.set_zero
      }
      else {
        this.set_zero = 0;
      }
    }
  }

  static serialize(obj, buffer, bufferOffset) {
    // Serializes a message object of type GripperRequest
    // Serialize message field [gripper_angle]
    bufferOffset = _serializer.float64(obj.gripper_angle, buffer, bufferOffset);
    // Serialize message field [gripper_effort]
    bufferOffset = _serializer.float64(obj.gripper_effort, buffer, bufferOffset);
    // Serialize message field [gripper_code]
    bufferOffset = _serializer.int64(obj.gripper_code, buffer, bufferOffset);
    // Serialize message field [set_zero]
    bufferOffset = _serializer.int64(obj.set_zero, buffer, bufferOffset);
    return bufferOffset;
  }

  static deserialize(buffer, bufferOffset=[0]) {
    //deserializes a message object of type GripperRequest
    let len;
    let data = new GripperRequest(null);
    // Deserialize message field [gripper_angle]
    data.gripper_angle = _deserializer.float64(buffer, bufferOffset);
    // Deserialize message field [gripper_effort]
    data.gripper_effort = _deserializer.float64(buffer, bufferOffset);
    // Deserialize message field [gripper_code]
    data.gripper_code = _deserializer.int64(buffer, bufferOffset);
    // Deserialize message field [set_zero]
    data.set_zero = _deserializer.int64(buffer, bufferOffset);
    return data;
  }

  static getMessageSize(object) {
    return 32;
  }

  static datatype() {
    // Returns string type for a service object
    return 'piper_msgs/GripperRequest';
  }

  static md5sum() {
    //Returns md5sum for a message object
    return '7ca678d5b432300b1e4e715e302cbc4d';
  }

  static messageDefinition() {
    // Returns full string definition for message
    return `
    float64 gripper_angle
    float64 gripper_effort
    int64 gripper_code
    int64 set_zero
    
    `;
  }

  static Resolve(msg) {
    // deep-construct a valid message object instance of whatever was passed in
    if (typeof msg !== 'object' || msg === null) {
      msg = {};
    }
    const resolved = new GripperRequest(null);
    if (msg.gripper_angle !== undefined) {
      resolved.gripper_angle = msg.gripper_angle;
    }
    else {
      resolved.gripper_angle = 0.0
    }

    if (msg.gripper_effort !== undefined) {
      resolved.gripper_effort = msg.gripper_effort;
    }
    else {
      resolved.gripper_effort = 0.0
    }

    if (msg.gripper_code !== undefined) {
      resolved.gripper_code = msg.gripper_code;
    }
    else {
      resolved.gripper_code = 0
    }

    if (msg.set_zero !== undefined) {
      resolved.set_zero = msg.set_zero;
    }
    else {
      resolved.set_zero = 0
    }

    return resolved;
    }
};

class GripperResponse {
  constructor(initObj={}) {
    if (initObj === null) {
      // initObj === null is a special case for deserialization where we don't initialize fields
      this.code = null;
      this.status = null;
    }
    else {
      if (initObj.hasOwnProperty('code')) {
        this.code = initObj.code
      }
      else {
        this.code = 0;
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
    // Serializes a message object of type GripperResponse
    // Serialize message field [code]
    bufferOffset = _serializer.int64(obj.code, buffer, bufferOffset);
    // Serialize message field [status]
    bufferOffset = _serializer.bool(obj.status, buffer, bufferOffset);
    return bufferOffset;
  }

  static deserialize(buffer, bufferOffset=[0]) {
    //deserializes a message object of type GripperResponse
    let len;
    let data = new GripperResponse(null);
    // Deserialize message field [code]
    data.code = _deserializer.int64(buffer, bufferOffset);
    // Deserialize message field [status]
    data.status = _deserializer.bool(buffer, bufferOffset);
    return data;
  }

  static getMessageSize(object) {
    return 9;
  }

  static datatype() {
    // Returns string type for a service object
    return 'piper_msgs/GripperResponse';
  }

  static md5sum() {
    //Returns md5sum for a message object
    return '34441fad838c25a9993eed8255bd6e41';
  }

  static messageDefinition() {
    // Returns full string definition for message
    return `
    int64 code
    bool status  # 响应消息类型为bool
    
    `;
  }

  static Resolve(msg) {
    // deep-construct a valid message object instance of whatever was passed in
    if (typeof msg !== 'object' || msg === null) {
      msg = {};
    }
    const resolved = new GripperResponse(null);
    if (msg.code !== undefined) {
      resolved.code = msg.code;
    }
    else {
      resolved.code = 0
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
  Request: GripperRequest,
  Response: GripperResponse,
  md5sum() { return 'fca0ae84ccaed9dee57e974f132f6119'; },
  datatype() { return 'piper_msgs/Gripper'; }
};
