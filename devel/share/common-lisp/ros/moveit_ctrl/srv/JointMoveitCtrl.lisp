; Auto-generated. Do not edit!


(cl:in-package moveit_ctrl-srv)


;//! \htmlinclude JointMoveitCtrl-request.msg.html

(cl:defclass <JointMoveitCtrl-request> (roslisp-msg-protocol:ros-message)
  ((joint_states
    :reader joint_states
    :initarg :joint_states
    :type (cl:vector cl:float)
   :initform (cl:make-array 6 :element-type 'cl:float :initial-element 0.0))
   (gripper
    :reader gripper
    :initarg :gripper
    :type cl:float
    :initform 0.0)
   (joint_endpose
    :reader joint_endpose
    :initarg :joint_endpose
    :type (cl:vector cl:float)
   :initform (cl:make-array 7 :element-type 'cl:float :initial-element 0.0))
   (max_velocity
    :reader max_velocity
    :initarg :max_velocity
    :type cl:float
    :initform 0.0)
   (max_acceleration
    :reader max_acceleration
    :initarg :max_acceleration
    :type cl:float
    :initform 0.0))
)

(cl:defclass JointMoveitCtrl-request (<JointMoveitCtrl-request>)
  ())

(cl:defmethod cl:initialize-instance :after ((m <JointMoveitCtrl-request>) cl:&rest args)
  (cl:declare (cl:ignorable args))
  (cl:unless (cl:typep m 'JointMoveitCtrl-request)
    (roslisp-msg-protocol:msg-deprecation-warning "using old message class name moveit_ctrl-srv:<JointMoveitCtrl-request> is deprecated: use moveit_ctrl-srv:JointMoveitCtrl-request instead.")))

(cl:ensure-generic-function 'joint_states-val :lambda-list '(m))
(cl:defmethod joint_states-val ((m <JointMoveitCtrl-request>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader moveit_ctrl-srv:joint_states-val is deprecated.  Use moveit_ctrl-srv:joint_states instead.")
  (joint_states m))

(cl:ensure-generic-function 'gripper-val :lambda-list '(m))
(cl:defmethod gripper-val ((m <JointMoveitCtrl-request>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader moveit_ctrl-srv:gripper-val is deprecated.  Use moveit_ctrl-srv:gripper instead.")
  (gripper m))

(cl:ensure-generic-function 'joint_endpose-val :lambda-list '(m))
(cl:defmethod joint_endpose-val ((m <JointMoveitCtrl-request>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader moveit_ctrl-srv:joint_endpose-val is deprecated.  Use moveit_ctrl-srv:joint_endpose instead.")
  (joint_endpose m))

(cl:ensure-generic-function 'max_velocity-val :lambda-list '(m))
(cl:defmethod max_velocity-val ((m <JointMoveitCtrl-request>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader moveit_ctrl-srv:max_velocity-val is deprecated.  Use moveit_ctrl-srv:max_velocity instead.")
  (max_velocity m))

(cl:ensure-generic-function 'max_acceleration-val :lambda-list '(m))
(cl:defmethod max_acceleration-val ((m <JointMoveitCtrl-request>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader moveit_ctrl-srv:max_acceleration-val is deprecated.  Use moveit_ctrl-srv:max_acceleration instead.")
  (max_acceleration m))
(cl:defmethod roslisp-msg-protocol:serialize ((msg <JointMoveitCtrl-request>) ostream)
  "Serializes a message object of type '<JointMoveitCtrl-request>"
  (cl:map cl:nil #'(cl:lambda (ele) (cl:let ((bits (roslisp-utils:encode-double-float-bits ele)))
    (cl:write-byte (cl:ldb (cl:byte 8 0) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 8) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 16) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 24) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 32) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 40) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 48) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 56) bits) ostream)))
   (cl:slot-value msg 'joint_states))
  (cl:let ((bits (roslisp-utils:encode-double-float-bits (cl:slot-value msg 'gripper))))
    (cl:write-byte (cl:ldb (cl:byte 8 0) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 8) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 16) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 24) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 32) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 40) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 48) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 56) bits) ostream))
  (cl:map cl:nil #'(cl:lambda (ele) (cl:let ((bits (roslisp-utils:encode-double-float-bits ele)))
    (cl:write-byte (cl:ldb (cl:byte 8 0) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 8) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 16) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 24) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 32) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 40) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 48) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 56) bits) ostream)))
   (cl:slot-value msg 'joint_endpose))
  (cl:let ((bits (roslisp-utils:encode-double-float-bits (cl:slot-value msg 'max_velocity))))
    (cl:write-byte (cl:ldb (cl:byte 8 0) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 8) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 16) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 24) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 32) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 40) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 48) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 56) bits) ostream))
  (cl:let ((bits (roslisp-utils:encode-double-float-bits (cl:slot-value msg 'max_acceleration))))
    (cl:write-byte (cl:ldb (cl:byte 8 0) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 8) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 16) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 24) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 32) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 40) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 48) bits) ostream)
    (cl:write-byte (cl:ldb (cl:byte 8 56) bits) ostream))
)
(cl:defmethod roslisp-msg-protocol:deserialize ((msg <JointMoveitCtrl-request>) istream)
  "Deserializes a message object of type '<JointMoveitCtrl-request>"
  (cl:setf (cl:slot-value msg 'joint_states) (cl:make-array 6))
  (cl:let ((vals (cl:slot-value msg 'joint_states)))
    (cl:dotimes (i 6)
    (cl:let ((bits 0))
      (cl:setf (cl:ldb (cl:byte 8 0) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 8) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 16) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 24) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 32) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 40) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 48) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 56) bits) (cl:read-byte istream))
    (cl:setf (cl:aref vals i) (roslisp-utils:decode-double-float-bits bits)))))
    (cl:let ((bits 0))
      (cl:setf (cl:ldb (cl:byte 8 0) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 8) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 16) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 24) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 32) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 40) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 48) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 56) bits) (cl:read-byte istream))
    (cl:setf (cl:slot-value msg 'gripper) (roslisp-utils:decode-double-float-bits bits)))
  (cl:setf (cl:slot-value msg 'joint_endpose) (cl:make-array 7))
  (cl:let ((vals (cl:slot-value msg 'joint_endpose)))
    (cl:dotimes (i 7)
    (cl:let ((bits 0))
      (cl:setf (cl:ldb (cl:byte 8 0) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 8) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 16) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 24) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 32) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 40) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 48) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 56) bits) (cl:read-byte istream))
    (cl:setf (cl:aref vals i) (roslisp-utils:decode-double-float-bits bits)))))
    (cl:let ((bits 0))
      (cl:setf (cl:ldb (cl:byte 8 0) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 8) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 16) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 24) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 32) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 40) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 48) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 56) bits) (cl:read-byte istream))
    (cl:setf (cl:slot-value msg 'max_velocity) (roslisp-utils:decode-double-float-bits bits)))
    (cl:let ((bits 0))
      (cl:setf (cl:ldb (cl:byte 8 0) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 8) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 16) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 24) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 32) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 40) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 48) bits) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 56) bits) (cl:read-byte istream))
    (cl:setf (cl:slot-value msg 'max_acceleration) (roslisp-utils:decode-double-float-bits bits)))
  msg
)
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql '<JointMoveitCtrl-request>)))
  "Returns string type for a service object of type '<JointMoveitCtrl-request>"
  "moveit_ctrl/JointMoveitCtrlRequest")
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql 'JointMoveitCtrl-request)))
  "Returns string type for a service object of type 'JointMoveitCtrl-request"
  "moveit_ctrl/JointMoveitCtrlRequest")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql '<JointMoveitCtrl-request>)))
  "Returns md5sum for a message object of type '<JointMoveitCtrl-request>"
  "51cb988f5ae355fbe239bcbc18431f99")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql 'JointMoveitCtrl-request)))
  "Returns md5sum for a message object of type 'JointMoveitCtrl-request"
  "51cb988f5ae355fbe239bcbc18431f99")
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql '<JointMoveitCtrl-request>)))
  "Returns full string definition for message of type '<JointMoveitCtrl-request>"
  (cl:format cl:nil "# JointMoveitCtrl.srv~%float64[6] joint_states  # 关节弧度~%float64 gripper # 夹爪张开宽度~%float64[7] joint_endpose # 末端执行器位置控制(四元数)~%float64 max_velocity # 最大速度~%float64 max_acceleration # 最大加速度~%~%~%"))
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql 'JointMoveitCtrl-request)))
  "Returns full string definition for message of type 'JointMoveitCtrl-request"
  (cl:format cl:nil "# JointMoveitCtrl.srv~%float64[6] joint_states  # 关节弧度~%float64 gripper # 夹爪张开宽度~%float64[7] joint_endpose # 末端执行器位置控制(四元数)~%float64 max_velocity # 最大速度~%float64 max_acceleration # 最大加速度~%~%~%"))
(cl:defmethod roslisp-msg-protocol:serialization-length ((msg <JointMoveitCtrl-request>))
  (cl:+ 0
     0 (cl:reduce #'cl:+ (cl:slot-value msg 'joint_states) :key #'(cl:lambda (ele) (cl:declare (cl:ignorable ele)) (cl:+ 8)))
     8
     0 (cl:reduce #'cl:+ (cl:slot-value msg 'joint_endpose) :key #'(cl:lambda (ele) (cl:declare (cl:ignorable ele)) (cl:+ 8)))
     8
     8
))
(cl:defmethod roslisp-msg-protocol:ros-message-to-list ((msg <JointMoveitCtrl-request>))
  "Converts a ROS message object to a list"
  (cl:list 'JointMoveitCtrl-request
    (cl:cons ':joint_states (joint_states msg))
    (cl:cons ':gripper (gripper msg))
    (cl:cons ':joint_endpose (joint_endpose msg))
    (cl:cons ':max_velocity (max_velocity msg))
    (cl:cons ':max_acceleration (max_acceleration msg))
))
;//! \htmlinclude JointMoveitCtrl-response.msg.html

(cl:defclass <JointMoveitCtrl-response> (roslisp-msg-protocol:ros-message)
  ((error_code
    :reader error_code
    :initarg :error_code
    :type cl:integer
    :initform 0)
   (status
    :reader status
    :initarg :status
    :type cl:boolean
    :initform cl:nil))
)

(cl:defclass JointMoveitCtrl-response (<JointMoveitCtrl-response>)
  ())

(cl:defmethod cl:initialize-instance :after ((m <JointMoveitCtrl-response>) cl:&rest args)
  (cl:declare (cl:ignorable args))
  (cl:unless (cl:typep m 'JointMoveitCtrl-response)
    (roslisp-msg-protocol:msg-deprecation-warning "using old message class name moveit_ctrl-srv:<JointMoveitCtrl-response> is deprecated: use moveit_ctrl-srv:JointMoveitCtrl-response instead.")))

(cl:ensure-generic-function 'error_code-val :lambda-list '(m))
(cl:defmethod error_code-val ((m <JointMoveitCtrl-response>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader moveit_ctrl-srv:error_code-val is deprecated.  Use moveit_ctrl-srv:error_code instead.")
  (error_code m))

(cl:ensure-generic-function 'status-val :lambda-list '(m))
(cl:defmethod status-val ((m <JointMoveitCtrl-response>))
  (roslisp-msg-protocol:msg-deprecation-warning "Using old-style slot reader moveit_ctrl-srv:status-val is deprecated.  Use moveit_ctrl-srv:status instead.")
  (status m))
(cl:defmethod roslisp-msg-protocol:serialize ((msg <JointMoveitCtrl-response>) ostream)
  "Serializes a message object of type '<JointMoveitCtrl-response>"
  (cl:let* ((signed (cl:slot-value msg 'error_code)) (unsigned (cl:if (cl:< signed 0) (cl:+ signed 18446744073709551616) signed)))
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
(cl:defmethod roslisp-msg-protocol:deserialize ((msg <JointMoveitCtrl-response>) istream)
  "Deserializes a message object of type '<JointMoveitCtrl-response>"
    (cl:let ((unsigned 0))
      (cl:setf (cl:ldb (cl:byte 8 0) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 8) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 16) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 24) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 32) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 40) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 48) unsigned) (cl:read-byte istream))
      (cl:setf (cl:ldb (cl:byte 8 56) unsigned) (cl:read-byte istream))
      (cl:setf (cl:slot-value msg 'error_code) (cl:if (cl:< unsigned 9223372036854775808) unsigned (cl:- unsigned 18446744073709551616))))
    (cl:setf (cl:slot-value msg 'status) (cl:not (cl:zerop (cl:read-byte istream))))
  msg
)
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql '<JointMoveitCtrl-response>)))
  "Returns string type for a service object of type '<JointMoveitCtrl-response>"
  "moveit_ctrl/JointMoveitCtrlResponse")
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql 'JointMoveitCtrl-response)))
  "Returns string type for a service object of type 'JointMoveitCtrl-response"
  "moveit_ctrl/JointMoveitCtrlResponse")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql '<JointMoveitCtrl-response>)))
  "Returns md5sum for a message object of type '<JointMoveitCtrl-response>"
  "51cb988f5ae355fbe239bcbc18431f99")
(cl:defmethod roslisp-msg-protocol:md5sum ((type (cl:eql 'JointMoveitCtrl-response)))
  "Returns md5sum for a message object of type 'JointMoveitCtrl-response"
  "51cb988f5ae355fbe239bcbc18431f99")
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql '<JointMoveitCtrl-response>)))
  "Returns full string definition for message of type '<JointMoveitCtrl-response>"
  (cl:format cl:nil "int64 error_code~%bool status~%~%~%"))
(cl:defmethod roslisp-msg-protocol:message-definition ((type (cl:eql 'JointMoveitCtrl-response)))
  "Returns full string definition for message of type 'JointMoveitCtrl-response"
  (cl:format cl:nil "int64 error_code~%bool status~%~%~%"))
(cl:defmethod roslisp-msg-protocol:serialization-length ((msg <JointMoveitCtrl-response>))
  (cl:+ 0
     8
     1
))
(cl:defmethod roslisp-msg-protocol:ros-message-to-list ((msg <JointMoveitCtrl-response>))
  "Converts a ROS message object to a list"
  (cl:list 'JointMoveitCtrl-response
    (cl:cons ':error_code (error_code msg))
    (cl:cons ':status (status msg))
))
(cl:defmethod roslisp-msg-protocol:service-request-type ((msg (cl:eql 'JointMoveitCtrl)))
  'JointMoveitCtrl-request)
(cl:defmethod roslisp-msg-protocol:service-response-type ((msg (cl:eql 'JointMoveitCtrl)))
  'JointMoveitCtrl-response)
(cl:defmethod roslisp-msg-protocol:ros-datatype ((msg (cl:eql 'JointMoveitCtrl)))
  "Returns string type for a service object of type '<JointMoveitCtrl>"
  "moveit_ctrl/JointMoveitCtrl")