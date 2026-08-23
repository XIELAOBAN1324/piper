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

class GoZeroRequest {
  constructor(initObj={}) {
    if (initObj === null) {
      // initObj === null is a special case for deserialization where we don't initialize fields
      this.is_mit_mode = null;
    }
    else {
      if (initObj.hasOwnProperty('is_mit_mode')) {
        this.is_mit_mode = initObj.is_mit_mode
      }
      else {
        this.is_mit_mode = false;
      }
    }
  }

  static serialize(obj, buffer, bufferOffset) {
    // Serializes a message object of type GoZeroRequest
    // Serialize message field [is_mit_mode]
    bufferOffset = _serializer.bool(obj.is_mit_mode, buffer, bufferOffset);
    return bufferOffset;
  }

  static deserialize(buffer, bufferOffset=[0]) {
    //deserializes a message object of type GoZeroRequest
    let len;
    let data = new GoZeroRequest(null);
    // Deserialize message field [is_mit_mode]
    data.is_mit_mode = _deserializer.bool(buffer, bufferOffset);
    return data;
  }

  static getMessageSize(object) {
    return 1;
  }

  static datatype() {
    // Returns string type for a service object
    return 'piper_msgs/GoZeroRequest';
  }

  static md5sum() {
    //Returns md5sum for a message object
    return '30ebeb9eeb641141e70d6beb2a7c36ee';
  }

  static messageDefinition() {
    // Returns full string definition for message
    return `
    bool is_mit_mode
    
    `;
  }

  static Resolve(msg) {
    // deep-construct a valid message object instance of whatever was passed in
    if (typeof msg !== 'object' || msg === null) {
      msg = {};
    }
    const resolved = new GoZeroRequest(null);
    if (msg.is_mit_mode !== undefined) {
      resolved.is_mit_mode = msg.is_mit_mode;
    }
    else {
      resolved.is_mit_mode = false
    }

    return resolved;
    }
};

class GoZeroResponse {
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
    // Serializes a message object of type GoZeroResponse
    // Serialize message field [code]
    bufferOffset = _serializer.int64(obj.code, buffer, bufferOffset);
    // Serialize message field [status]
    bufferOffset = _serializer.bool(obj.status, buffer, bufferOffset);
    return bufferOffset;
  }

  static deserialize(buffer, bufferOffset=[0]) {
    //deserializes a message object of type GoZeroResponse
    let len;
    let data = new GoZeroResponse(null);
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
    return 'piper_msgs/GoZeroResponse';
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
    const resolved = new GoZeroResponse(null);
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
  Request: GoZeroRequest,
  Response: GoZeroResponse,
  md5sum() { return 'd8cded8be1d1727ecab27b0820b4be6f'; },
  datatype() { return 'piper_msgs/GoZero'; }
};
