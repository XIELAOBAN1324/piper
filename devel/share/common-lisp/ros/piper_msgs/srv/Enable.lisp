; Auto-generated. Do not edit!


(cl:in-package piper_msgs-srv)


;//! \htmlinclude Enable-request.msg.html

(cl:defclass <Enable-request> (roslisp-msg-protocol:ros-message)
  ((enable_request
    :reader enable_request
    :initarg :enable_request
    :type cl:boolean
    :initform cl:nil))
)

(cl:defclass Enable-request (<Enable-request>)
  ())

(cl:defmethod cl:initialize-instance :after ((m <Enable-request>) cl:&rest args)
  (cl:declare (cl:ignorable args))
  (cl:unless (cl:typep m 'Enable-request)
    (roslisp-msg-protocol:msg-deprecation-warning "using old message class name piper_msgs-srv:<Enable-request> is deprecated: use piper_msgs-srv:Enable-request instead.")))

(cl:ensure-generic-function 'enable_request-val :lambda-list '(m))
(cl:defmethod enable_request-val ((m <Enable-request>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader piper_msgs-srv:enable_request-val is deprecated.  Use piper_msgs-srv:enable_request instead.")
  (enable_request m))
(cl:defmethod roslisp-msg-protocol:serialize ((msg <Enable-request>) ostream)
  "Serializes a message object of type '<Enable-request>"
  (cl:write-byte (cl:ldb (cl:byte 8 0) (cl:if (cl:slot-value msg 'enable_request) 1 0)) ostream)
)
(cl:defmethod roslisp-msg-protocol:deserialize ((msg <Enable-request>) istream)
  "Deserializes a message object of type '<Enable-request>"
    (cl:setf (cl:slot-value msg 'enable_request) (cl:not (cl:zerop (cl:read-byte istream))))
  msg
)
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql '<Enable-request>)))
  "Returns string type for a service object of type '<Enable-request>"
  "piper_msgs/EnableRequest")
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql 'Enable-request)))
  "Returns string type for a service object of type 'Enable-request"
  "piper_msgs/EnableRequest")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql '<Enable-request>)))
  "Returns md5sum for a message object of type '<Enable-request>"
  "ab5da25e2334681fe9da4d5fb9858409")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql 'Enable-request)))
  "Returns md5sum for a message object of type 'Enable-request"
  "ab5da25e2334681fe9da4d5fb9858409")
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql '<Enable-request>)))
  "Returns full string definition for message of type '<Enable-request>"
  (cl:format cl:nil "bool enable_request  # 请求消息类型为bool~%~%~%"))
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql 'Enable-request)))
  "Returns full string definition for message of type 'Enable-request"
  (cl:format cl:nil "bool enable_request  # 请求消息类型为bool~%~%~%"))
(cl:defmethod roslisp-msg-protocol:serialization-length ((msg <Enable-request>))
  (cl:+ 0
     1
))
(cl:defmethod roslisp-msg-protocol:ros-message-to-list ((msg <Enable-request>))
  "Converts a ROS message object to a list"
  (cl:list 'Enable-request
    (cl:cons ':enable_request (enable_request msg))
))
;//! \htmlinclude Enable-response.msg.html

(cl:defclass <Enable-response> (roslisp-msg-protocol:ros-message)
  ((enable_response
    :reader enable_response
    :initarg :enable_response
    :type cl:boolean
    :initform cl:nil))
)

(cl:defclass Enable-response (<Enable-response>)
  ())

(cl:defmethod cl:initialize-instance :after ((m <Enable-response>) cl:&rest args)
  (cl:declare (cl:ignorable args))
  (cl:unless (cl:typep m 'Enable-response)
    (roslisp-msg-protocol:msg-deprecation-warning "using old message class name piper_msgs-srv:<Enable-response> is deprecated: use piper_msgs-srv:Enable-response instead.")))

(cl:ensure-generic-function 'enable_response-val :lambda-list '(m))
(cl:defmethod enable_response-val ((m <Enable-response>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader piper_msgs-srv:enable_response-val is deprecated.  Use piper_msgs-srv:enable_response instead.")
  (enable_response m))
(cl:defmethod roslisp-msg-protocol:serialize ((msg <Enable-response>) ostream)
  "Serializes a message object of type '<Enable-response>"
  (cl:write-byte (cl:ldb (cl:byte 8 0) (cl:if (cl:slot-value msg 'enable_response) 1 0)) ostream)
)
(cl:defmethod roslisp-msg-protocol:deserialize ((msg <Enable-response>) istream)
  "Deserializes a message object of type '<Enable-response>"
    (cl:setf (cl:slot-value msg 'enable_response) (cl:not (cl:zerop (cl:read-byte istream))))
  msg
)
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql '<Enable-response>)))
  "Returns string type for a service object of type '<Enable-response>"
  "piper_msgs/EnableResponse")
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql 'Enable-response)))
  "Returns string type for a service object of type 'Enable-response"
  "piper_msgs/EnableResponse")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql '<Enable-response>)))
  "Returns md5sum for a message object of type '<Enable-response>"
  "ab5da25e2334681fe9da4d5fb9858409")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql 'Enable-response)))
  "Returns md5sum for a message object of type 'Enable-response"
  "ab5da25e2334681fe9da4d5fb9858409")
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql '<Enable-response>)))
  "Returns full string definition for message of type '<Enable-response>"
  (cl:format cl:nil "bool enable_response  # 响应消息类型为bool~%~%~%~%"))
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql 'Enable-response)))
  "Returns full string definition for message of type 'Enable-response"
  (cl:format cl:nil "bool enable_response  # 响应消息类型为bool~%~%~%~%"))
(cl:defmethod roslisp-msg-protocol:serialization-length ((msg <Enable-response>))
  (cl:+ 0
     1
))
(cl:defmethod roslisp-msg-protocol:ros-message-to-list ((msg <Enable-response>))
  "Converts a ROS message object to a list"
  (cl:list 'Enable-response
    (cl:cons ':enable_response (enable_response msg))
))
(cl:defmethod roslisp-msg-protocol:service-request-type ((msg (cl:eql 'Enable)))
  'Enable-request)
(cl:defmethod roslisp-msg-protocol:service-response-type ((msg (cl:eql 'Enable)))
  'Enable-response)
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql 'Enable)))
  "Returns string type for a service object of type '<Enable>"
  "piper_msgs/Enable")