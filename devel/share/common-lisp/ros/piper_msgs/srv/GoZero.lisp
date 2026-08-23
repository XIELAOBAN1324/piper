; Auto-generated. Do not edit!


(cl:in-package piper_msgs-srv)


;//! \htmlinclude GoZero-request.msg.html

(cl:defclass <GoZero-request> (roslisp-msg-protocol:ros-message)
  ((is_mit_mode
    :reader is_mit_mode
    :initarg :is_mit_mode
    :type cl:boolean
    :initform cl:nil))
)

(cl:defclass GoZero-request (<GoZero-request>)
  ())

(cl:defmethod cl:initialize-instance :after ((m <GoZero-request>) cl:&rest args)
  (cl:declare (cl:ignorable args))
  (cl:unless (cl:typep m 'GoZero-request)
    (roslisp-msg-protocol:msg-deprecation-warning "using old message class name piper_msgs-srv:<GoZero-request> is deprecated: use piper_msgs-srv:GoZero-request instead.")))

(cl:ensure-generic-function 'is_mit_mode-val :lambda-list '(m))
(cl:defmethod is_mit_mode-val ((m <GoZero-request>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader piper_msgs-srv:is_mit_mode-val is deprecated.  Use piper_msgs-srv:is_mit_mode instead.")
  (is_mit_mode m))
(cl:defmethod roslisp-msg-protocol:serialize ((msg <GoZero-request>) ostream)
  "Serializes a message object of type '<GoZero-request>"
  (cl:write-byte (cl:ldb (cl:byte 8 0) (cl:if (cl:slot-value msg 'is_mit_mode) 1 0)) ostream)
)
(cl:defmethod roslisp-msg-protocol:deserialize ((msg <GoZero-request>) istream)
  "Deserializes a message object of type '<GoZero-request>"
    (cl:setf (cl:slot-value msg 'is_mit_mode) (cl:not (cl:zerop (cl:read-byte istream))))
  msg
)
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql '<GoZero-request>)))
  "Returns string type for a service object of type '<GoZero-request>"
  "piper_msgs/GoZeroRequest")
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql 'GoZero-request)))
  "Returns string type for a service object of type 'GoZero-request"
  "piper_msgs/GoZeroRequest")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql '<GoZero-request>)))
  "Returns md5sum for a message object of type '<GoZero-request>"
  "d8cded8be1d1727ecab27b0820b4be6f")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql 'GoZero-request)))
  "Returns md5sum for a message object of type 'GoZero-request"
  "d8cded8be1d1727ecab27b0820b4be6f")
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql '<GoZero-request>)))
  "Returns full string definition for message of type '<GoZero-request>"
  (cl:format cl:nil "bool is_mit_mode~%~%~%"))
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql 'GoZero-request)))
  "Returns full string definition for message of type 'GoZero-request"
  (cl:format cl:nil "bool is_mit_mode~%~%~%"))
(cl:defmethod roslisp-msg-protocol:serialization-length ((msg <GoZero-request>))
  (cl:+ 0
     1
))
(cl:defmethod roslisp-msg-protocol:ros-message-to-list ((msg <GoZero-request>))
  "Converts a ROS message object to a list"
  (cl:list 'GoZero-request
    (cl:cons ':is_mit_mode (is_mit_mode msg))
))
;//! \htmlinclude GoZero-response.msg.html

(cl:defclass <GoZero-response> (roslisp-msg-protocol:ros-message)
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

(cl:defclass GoZero-response (<GoZero-response>)
  ())

(cl:defmethod cl:initialize-instance :after ((m <GoZero-response>) cl:&rest args)
  (cl:declare (cl:ignorable args))
  (cl:unless (cl:typep m 'GoZero-response)
    (roslisp-msg-protocol:msg-deprecation-warning "using old message class name piper_msgs-srv:<GoZero-response> is deprecated: use piper_msgs-srv:GoZero-response instead.")))

(cl:ensure-generic-function 'code-val :lambda-list '(m))
(cl:defmethod code-val ((m <GoZero-response>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader piper_msgs-srv:code-val is deprecated.  Use piper_msgs-srv:code instead.")
  (code m))

(cl:ensure-generic-function 'status-val :lambda-list '(m))
(cl:defmethod status-val ((m <GoZero-response>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader piper_msgs-srv:status-val is deprecated.  Use piper_msgs-srv:status instead.")
  (status m))
(cl:defmethod roslisp-msg-protocol:serialize ((msg <GoZero-response>) ostream)
  "Serializes a message object of type '<GoZero-response>"
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
(cl:defmethod roslisp-msg-protocol:deserialize ((msg <GoZero-response>) istream)
  "Deserializes a message object of type '<GoZero-response>"
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
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql '<GoZero-response>)))
  "Returns string type for a service object of type '<GoZero-response>"
  "piper_msgs/GoZeroResponse")
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql 'GoZero-response)))
  "Returns string type for a service object of type 'GoZero-response"
  "piper_msgs/GoZeroResponse")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql '<GoZero-response>)))
  "Returns md5sum for a message object of type '<GoZero-response>"
  "d8cded8be1d1727ecab27b0820b4be6f")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql 'GoZero-response)))
  "Returns md5sum for a message object of type 'GoZero-response"
  "d8cded8be1d1727ecab27b0820b4be6f")
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql '<GoZero-response>)))
  "Returns full string definition for message of type '<GoZero-response>"
  (cl:format cl:nil "int64 code~%bool status  # 响应消息类型为bool~%~%~%"))
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql 'GoZero-response)))
  "Returns full string definition for message of type 'GoZero-response"
  (cl:format cl:nil "int64 code~%bool status  # 响应消息类型为bool~%~%~%"))
(cl:defmethod roslisp-msg-protocol:serialization-length ((msg <GoZero-response>))
  (cl:+ 0
     8
     1
))
(cl:defmethod roslisp-msg-protocol:ros-message-to-list ((msg <GoZero-response>))
  "Converts a ROS message object to a list"
  (cl:list 'GoZero-response
    (cl:cons ':code (code msg))
    (cl:cons ':status (status msg))
))
(cl:defmethod roslisp-msg-protocol:service-request-type ((msg (cl:eql 'GoZero)))
  'GoZero-request)
(cl:defmethod roslisp-msg-protocol:service-response-type ((msg (cl:eql 'GoZero)))
  'GoZero-response)
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql 'GoZero)))
  "Returns string type for a service object of type '<GoZero>"
  "piper_msgs/GoZero")