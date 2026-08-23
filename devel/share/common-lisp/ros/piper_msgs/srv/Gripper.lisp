; Auto-generated. Do not edit!


(cl:in-package piper_msgs-srv)


;//! \htmlinclude Gripper-request.msg.html

(cl:defclass <Gripper-request> (roslisp-msg-protocol:ros-message)
  ((gripper_angle
    :reader gripper_angle
    :initarg :gripper_angle
    :type cl:float
    :initform 0.0)
   (gripper_effort
    :reader gripper_effort
    :initarg :gripper_effort
    :type cl:float
    :initform 0.0)
   (gripper_code
    :reader gripper_code
    :initarg :gripper_code
    :type cl:integer
    :initform 0)
   (set_zero
    :reader set_zero
    :initarg :set_zero
    :type cl:integer
    :initform 0))
)

(cl:defclass Gripper-request (<Gripper-request>)
  ())

(cl:defmethod cl:initialize-instance :after ((m <Gripper-request>) cl:&rest args)
  (cl:declare (cl:ignorable args))
  (cl:unless (cl:typep m 'Gripper-request)
    (roslisp-msg-protocol:msg-deprecation-warning "using old message class name piper_msgs-srv:<Gripper-request> is deprecated: use piper_msgs-srv:Gripper-request instead.")))

(cl:ensure-generic-function 'gripper_angle-val :lambda-list '(m))
(cl:defmethod gripper_angle-val ((m <Gripper-request>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader piper_msgs-srv:gripper_angle-val is deprecated.  Use piper_msgs-srv:gripper_angle instead.")
  (gripper_angle m))

(cl:ensure-generic-function 'gripper_effort-val :lambda-list '(m))
(cl:defmethod gripper_effort-val ((m <Gripper-request>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader piper_msgs-srv:gripper_effort-val is deprecated.  Use piper_msgs-srv:gripper_effort instead.")
  (gripper_effort m))

(cl:ensure-generic-function 'gripper_code-val :lambda-list '(m))
(cl:defmethod gripper_code-val ((m <Gripper-request>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader piper_msgs-srv:gripper_code-val is deprecated.  Use piper_msgs-srv:gripper_code instead.")
  (gripper_code m))

(cl:ensure-generic-function 'set_zero-val :lambda-list '(m))
(cl:defmethod set_zero-val ((m <Gripper-request>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader piper_msgs-srv:set_zero-val is deprecated.  Use piper_msgs-srv:set_zero instead.")
  (set_zero m))
(cl:defmethod roslisp-msg-protocol:serialize ((msg <Gripper-request>) ostream)
  "Serializes a message object of type '<Gripper-request>"
  (cl:let ((bits (roslisp-utils:encode-double-float-bits (cl:slot-value msg 'gripper_angle))))
    (cl:write-byte (cl:ldb (cl:byte 8 0) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 8) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 16) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 24) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 32) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 40) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 48) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 56) bits) ostream))
  (cl:let ((bits (roslisp-utils:encode-double-float-bits (cl:slot-value msg 'gripper_effort))))
    (cl:write-byte (cl:ldb (cl:byte 8 0) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 8) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 16) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 24) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 32) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 40) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 48) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 56) bits) ostream))
  (cl:let* ((signed (cl:slot-value msg 'gripper_code)) (unsigned (cl:if (cl:< signed 0) (cl:+ signed 18446744073709551616) signed)))
    (cl:write-byte (cl:ldb (cl:byte 8 0) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 8) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 16) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 24) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 32) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 40) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 48) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 56) unsigned) ostream)
    )
  (cl:let* ((signed (cl:slot-value msg 'set_zero)) (unsigned (cl:if (cl:< signed 0) (cl:+ signed 18446744073709551616) signed)))
    (cl:write-byte (cl:ldb (cl:byte 8 0) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 8) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 16) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 24) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 32) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 40) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 48) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 56) unsigned) ostream)
    )
)
(cl:defmethod roslisp-msg-protocol:deserialize ((msg <Gripper-request>) istream)
  "Deserializes a message object of type '<Gripper-request>"
    (cl:let ((bits 0))
      (cl:setf (cl:ldb (cl:byte 8 0) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 8) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 16) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 24) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 32) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 40) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 48) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 56) bits) (cl:read-byte istream))
    (cl:setf (cl:slot-value msg 'gripper_angle) (roslisp-utils:decode-double-float-bits bits)))
    (cl:let ((bits 0))
      (cl:setf (cl:ldb (cl:byte 8 0) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 8) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 16) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 24) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 32) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 40) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 48) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 56) bits) (cl:read-byte istream))
    (cl:setf (cl:slot-value msg 'gripper_effort) (roslisp-utils:decode-double-float-bits bits)))
    (cl:let ((unsigned 0))
      (cl:setf (cl:ldb (cl:byte 8 0) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 8) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 16) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 24) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 32) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 40) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 48) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 56) unsigned) (cl:read-byte istream))
      (cl:setf (cl:slot-value msg 'gripper_code) (cl:if (cl:< unsigned 9223372036854775808) unsigned (cl:- unsigned 18446744073709551616))))
    (cl:let ((unsigned 0))
      (cl:setf (cl:ldb (cl:byte 8 0) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 8) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 16) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 24) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 32) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 40) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 48) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 56) unsigned) (cl:read-byte istream))
      (cl:setf (cl:slot-value msg 'set_zero) (cl:if (cl:< unsigned 9223372036854775808) unsigned (cl:- unsigned 18446744073709551616))))
  msg
)
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql '<Gripper-request>)))
  "Returns string type for a service object of type '<Gripper-request>"
  "piper_msgs/GripperRequest")
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql 'Gripper-request)))
  "Returns string type for a service object of type 'Gripper-request"
  "piper_msgs/GripperRequest")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql '<Gripper-request>)))
  "Returns md5sum for a message object of type '<Gripper-request>"
  "fca0ae84ccaed9dee57e974f132f6119")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql 'Gripper-request)))
  "Returns md5sum for a message object of type 'Gripper-request"
  "fca0ae84ccaed9dee57e974f132f6119")
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql '<Gripper-request>)))
  "Returns full string definition for message of type '<Gripper-request>"
  (cl:format cl:nil "float64 gripper_angle~%float64 gripper_effort~%int64 gripper_code~%int64 set_zero~%~%~%"))
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql 'Gripper-request)))
  "Returns full string definition for message of type 'Gripper-request"
  (cl:format cl:nil "float64 gripper_angle~%float64 gripper_effort~%int64 gripper_code~%int64 set_zero~%~%~%"))
(cl:defmethod roslisp-msg-protocol:serialization-length ((msg <Gripper-request>))
  (cl:+ 0
     8
     8
     8
     8
))
(cl:defmethod roslisp-msg-protocol:ros-message-to-list ((msg <Gripper-request>))
  "Converts a ROS message object to a list"
  (cl:list 'Gripper-request
    (cl:cons ':gripper_angle (gripper_angle msg))
    (cl:cons ':gripper_effort (gripper_effort msg))
    (cl:cons ':gripper_code (gripper_code msg))
    (cl:cons ':set_zero (set_zero msg))
))
;//! \htmlinclude Gripper-response.msg.html

(cl:defclass <Gripper-response> (roslisp-msg-protocol:ros-message)
  ((code
    :reader code
    :initarg :code
    :type cl:integer
    :initform 0)
   (status
    :reader status
    :initarg :status
    :type cl:boolean
    :initform cl:nil))
)

(cl:defclass Gripper-response (<Gripper-response>)
  ())

(cl:defmethod cl:initialize-instance :after ((m <Gripper-response>) cl:&rest args)
  (cl:declare (cl:ignorable args))
  (cl:unless (cl:typep m 'Gripper-response)
    (roslisp-msg-protocol:msg-deprecation-warning "using old message class name piper_msgs-srv:<Gripper-response> is deprecated: use piper_msgs-srv:Gripper-response instead.")))

(cl:ensure-generic-function 'code-val :lambda-list '(m))
(cl:defmethod code-val ((m <Gripper-response>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader piper_msgs-srv:code-val is deprecated.  Use piper_msgs-srv:code instead.")
  (code m))

(cl:ensure-generic-function 'status-val :lambda-list '(m))
(cl:defmethod status-val ((m <Gripper-response>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader piper_msgs-srv:status-val is deprecated.  Use piper_msgs-srv:status instead.")
  (status m))
(cl:defmethod roslisp-msg-protocol:serialize ((msg <Gripper-response>) ostream)
  "Serializes a message object of type '<Gripper-response>"
  (cl:let* ((signed (cl:slot-value msg 'code)) (unsigned (cl:if (cl:< signed 0) (cl:+ signed 18446744073709551616) signed)))
    (cl:write-byte (cl:ldb (cl:byte 8 0) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 8) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 16) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 24) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 32) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 40) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 48) unsigned) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 56) unsigned) ostream)
    )
  (cl:write-byte (cl:ldb (cl:byte 8 0) (cl:if (cl:slot-value msg 'status) 1 0)) ostream)
)
(cl:defmethod roslisp-msg-protocol:deserialize ((msg <Gripper-response>) istream)
  "Deserializes a message object of type '<Gripper-response>"
    (cl:let ((unsigned 0))
      (cl:setf (cl:ldb (cl:byte 8 0) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 8) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 16) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 24) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 32) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 40) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 48) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 56) unsigned) (cl:read-byte istream))
      (cl:setf (cl:slot-value msg 'code) (cl:if (cl:< unsigned 9223372036854775808) unsigned (cl:- unsigned 18446744073709551616))))
    (cl:setf (cl:slot-value msg 'status) (cl:not (cl:zerop (cl:read-byte istream))))
  msg
)
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql '<Gripper-response>)))
  "Returns string type for a service object of type '<Gripper-response>"
  "piper_msgs/GripperResponse")
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql 'Gripper-response)))
  "Returns string type for a service object of type 'Gripper-response"
  "piper_msgs/GripperResponse")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql '<Gripper-response>)))
  "Returns md5sum for a message object of type '<Gripper-response>"
  "fca0ae84ccaed9dee57e974f132f6119")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql 'Gripper-response)))
  "Returns md5sum for a message object of type 'Gripper-response"
  "fca0ae84ccaed9dee57e974f132f6119")
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql '<Gripper-response>)))
  "Returns full string definition for message of type '<Gripper-response>"
  (cl:format cl:nil "int64 code~%bool status  # 响应消息类型为bool~%~%~%"))
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql 'Gripper-response)))
  "Returns full string definition for message of type 'Gripper-response"
  (cl:format cl:nil "int64 code~%bool status  # 响应消息类型为bool~%~%~%"))
(cl:defmethod roslisp-msg-protocol:serialization-length ((msg <Gripper-response>))
  (cl:+ 0
     8
     1
))
(cl:defmethod roslisp-msg-protocol:ros-message-to-list ((msg <Gripper-response>))
  "Converts a ROS message object to a list"
  (cl:list 'Gripper-response
    (cl:cons ':code (code msg))
    (cl:cons ':status (status msg))
))
(cl:defmethod roslisp-msg-protocol:service-request-type ((msg (cl:eql 'Gripper)))
  'Gripper-request)
(cl:defmethod roslisp-msg-protocol:service-response-type ((msg (cl:eql 'Gripper)))
  'Gripper-response)
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql 'Gripper)))
  "Returns string type for a service object of type '<Gripper>"
  "piper_msgs/Gripper")