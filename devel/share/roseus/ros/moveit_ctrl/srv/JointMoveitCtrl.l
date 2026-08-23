;; Auto-generated. Do not edit!


(when (boundp 'moveit_ctrl::JointMoveitCtrl)
  (if (not (find-package "MOVEIT_CTRL"))
    (make-package "MOVEIT_CTRL"))
  (shadow 'JointMoveitCtrl (find-package "MOVEIT_CTRL")))
(unless (find-package "MOVEIT_CTRL::JOINTMOVEITCTRL")
  (make-package "MOVEIT_CTRL::JOINTMOVEITCTRL"))
(unless (find-package "MOVEIT_CTRL::JOINTMOVEITCTRLREQUEST")
  (make-package "MOVEIT_CTRL::JOINTMOVEITCTRLREQUEST"))
(unless (find-package "MOVEIT_CTRL::JOINTMOVEITCTRLRESPONSE")
  (make-package "MOVEIT_CTRL::JOINTMOVEITCTRLRESPONSE"))

(in-package "ROS")





(defclass moveit_ctrl::JointMoveitCtrlRequest
  :super ros::object
  :slots (_joint_states _gripper _joint_endpose _max_velocity _max_acceleration ))

(defmethod moveit_ctrl::JointMoveitCtrlRequest
  (:init
   (&key
    ((:joint_states __joint_states) (make-array 6 :initial-element 0.0 :element-type :float))
    ((:gripper __gripper) 0.0)
    ((:joint_endpose __joint_endpose) (make-array 7 :initial-element 0.0 :element-type :float))
    ((:max_velocity __max_velocity) 0.0)
    ((:max_acceleration __max_acceleration) 0.0)
    )
   (send-super :init)
   (setq _joint_states __joint_states)
   (setq _gripper (float __gripper))
   (setq _joint_endpose __joint_endpose)
   (setq _max_velocity (float __max_velocity))
   (setq _max_acceleration (float __max_acceleration))
   self)
  (:joint_states
   (&optional __joint_states)
   (if __joint_states (setq _joint_states __joint_states)) _joint_states)
  (:gripper
   (&optional __gripper)
   (if __gripper (setq _gripper __gripper)) _gripper)
  (:joint_endpose
   (&optional __joint_endpose)
   (if __joint_endpose (setq _joint_endpose __joint_endpose)) _joint_endpose)
  (:max_velocity
   (&optional __max_velocity)
   (if __max_velocity (setq _max_velocity __max_velocity)) _max_velocity)
  (:max_acceleration
   (&optional __max_acceleration)
   (if __max_acceleration (setq _max_acceleration __max_acceleration)) _max_acceleration)
  (:serialization-length
   ()
   (+
    ;; float64[6] _joint_states
    (* 8    6)
    ;; float64 _gripper
    8
    ;; float64[7] _joint_endpose
    (* 8    7)
    ;; float64 _max_velocity
    8
    ;; float64 _max_acceleration
    8
    ))
  (:serialize
   (&optional strm)
   (let ((s (if strm strm
              (make-string-output-stream (send self :serialization-length)))))
     ;; float64[6] _joint_states
     (dotimes (i 6)
       (sys::poke (elt _joint_states i) (send s :buffer) (send s :count) :double) (incf (stream-count s) 8)
       )
     ;; float64 _gripper
       (sys::poke _gripper (send s :buffer) (send s :count) :double) (incf (stream-count s) 8)
     ;; float64[7] _joint_endpose
     (dotimes (i 7)
       (sys::poke (elt _joint_endpose i) (send s :buffer) (send s :count) :double) (incf (stream-count s) 8)
       )
     ;; float64 _max_velocity
       (sys::poke _max_velocity (send s :buffer) (send s :count) :double) (incf (stream-count s) 8)
     ;; float64 _max_acceleration
       (sys::poke _max_acceleration (send s :buffer) (send s :count) :double) (incf (stream-count s) 8)
     ;;
     (if (null strm) (get-output-stream-string s))))
  (:deserialize
   (buf &optional (ptr- 0))
   ;; float64[6] _joint_states
   (dotimes (i (length _joint_states))
     (setf (elt _joint_states i) (sys::peek buf ptr- :double)) (incf ptr- 8)
     )
   ;; float64 _gripper
     (setq _gripper (sys::peek buf ptr- :double)) (incf ptr- 8)
   ;; float64[7] _joint_endpose
   (dotimes (i (length _joint_endpose))
     (setf (elt _joint_endpose i) (sys::peek buf ptr- :double)) (incf ptr- 8)
     )
   ;; float64 _max_velocity
     (setq _max_velocity (sys::peek buf ptr- :double)) (incf ptr- 8)
   ;; float64 _max_acceleration
     (setq _max_acceleration (sys::peek buf ptr- :double)) (incf ptr- 8)
   ;;
   self)
  )

(defclass moveit_ctrl::JointMoveitCtrlResponse
  :super ros::object
  :slots (_error_code _status ))

(defmethod moveit_ctrl::JointMoveitCtrlResponse
  (:init
   (&key
    ((:error_code __error_code) 0)
    ((:status __status) nil)
    )
   (send-super :init)
   (setq _error_code (round __error_code))
   (setq _status __status)
   self)
  (:error_code
   (&optional __error_code)
   (if __error_code (setq _error_code __error_code)) _error_code)
  (:status
   (&optional (__status :null))
   (if (not (eq __status :null)) (setq _status __status)) _status)
  (:serialization-length
   ()
   (+
    ;; int64 _error_code
    8
    ;; bool _status
    1
    ))
  (:serialize
   (&optional strm)
   (let ((s (if strm strm
              (make-string-output-stream (send self :serialization-length)))))
     ;; int64 _error_code
#+(or :alpha :irix6 :x86_64)
       (progn (sys::poke _error_code (send s :buffer) (send s :count) :long) (incf (stream-count s) 8))
#-(or :alpha :irix6 :x86_64)
       (cond ((and (class _error_code) (= (length (_error_code . bv)) 2)) ;; bignum
              (write-long (ash (elt (_error_code . bv) 0) 0) s)
              (write-long (ash (elt (_error_code . bv) 1) -1) s))
             ((and (class _error_code) (= (length (_error_code . bv)) 1)) ;; big1
              (write-long (elt (_error_code . bv) 0) s)
              (write-long (if (>= _error_code 0) 0 #xffffffff) s))
             (t                                         ;; integer
              (write-long _error_code s)(write-long (if (>= _error_code 0) 0 #xffffffff) s)))
     ;; bool _status
       (if _status (write-byte -1 s) (write-byte 0 s))
     ;;
     (if (null strm) (get-output-stream-string s))))
  (:deserialize
   (buf &optional (ptr- 0))
   ;; int64 _error_code
#+(or :alpha :irix6 :x86_64)
      (setf _error_code (prog1 (sys::peek buf ptr- :long) (incf ptr- 8)))
#-(or :alpha :irix6 :x86_64)
      (setf _error_code (let ((b0 (prog1 (sys::peek buf ptr- :integer) (incf ptr- 4)))
                  (b1 (prog1 (sys::peek buf ptr- :integer) (incf ptr- 4))))
              (cond ((= b1 -1) b0)
                     ((and (= b1  0)
                           (<= lisp::most-negative-fixnum b0 lisp::most-positive-fixnum))
                      b0)
                    ((= b1  0) (make-instance bignum :size 1 :bv (integer-vector b0)))
                    (t (make-instance bignum :size 2 :bv (integer-vector b0 (ash b1 1)))))))
   ;; bool _status
     (setq _status (not (= 0 (sys::peek buf ptr- :char)))) (incf ptr- 1)
   ;;
   self)
  )

(defclass moveit_ctrl::JointMoveitCtrl
  :super ros::object
  :slots ())

(setf (get moveit_ctrl::JointMoveitCtrl :md5sum-) "51cb988f5ae355fbe239bcbc18431f99")
(setf (get moveit_ctrl::JointMoveitCtrl :datatype-) "moveit_ctrl/JointMoveitCtrl")
(setf (get moveit_ctrl::JointMoveitCtrl :request) moveit_ctrl::JointMoveitCtrlRequest)
(setf (get moveit_ctrl::JointMoveitCtrl :response) moveit_ctrl::JointMoveitCtrlResponse)

(defmethod moveit_ctrl::JointMoveitCtrlRequest
  (:response () (instance moveit_ctrl::JointMoveitCtrlResponse :init)))

(setf (get moveit_ctrl::JointMoveitCtrlRequest :md5sum-) "51cb988f5ae355fbe239bcbc18431f99")
(setf (get moveit_ctrl::JointMoveitCtrlRequest :datatype-) "moveit_ctrl/JointMoveitCtrlRequest")
(setf (get moveit_ctrl::JointMoveitCtrlRequest :definition-)
      "# JointMoveitCtrl.srv
float64[6] joint_states  # 关节弧度
float64 gripper # 夹爪张开宽度
float64[7] joint_endpose # 末端执行器位置控制(四元数)
float64 max_velocity # 最大速度
float64 max_acceleration # 最大加速度
---
int64 error_code
bool status
")

(setf (get moveit_ctrl::JointMoveitCtrlResponse :md5sum-) "51cb988f5ae355fbe239bcbc18431f99")
(setf (get moveit_ctrl::JointMoveitCtrlResponse :datatype-) "moveit_ctrl/JointMoveitCtrlResponse")
(setf (get moveit_ctrl::JointMoveitCtrlResponse :definition-)
      "# JointMoveitCtrl.srv
float64[6] joint_states  # 关节弧度
float64 gripper # 夹爪张开宽度
float64[7] joint_endpose # 末端执行器位置控制(四元数)
float64 max_velocity # 最大速度
float64 max_acceleration # 最大加速度
---
int64 error_code
bool status
")



(provide :moveit_ctrl/JointMoveitCtrl "51cb988f5ae355fbe239bcbc18431f99")


