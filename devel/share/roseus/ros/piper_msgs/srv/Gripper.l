;; Auto-generated. Do not edit!


(when (boundp 'piper_msgs::Gripper)
  (if (not (find-package "PIPER_MSGS"))
    (make-package "PIPER_MSGS"))
  (shadow 'Gripper (find-package "PIPER_MSGS")))
(unless (find-package "PIPER_MSGS::GRIPPER")
  (make-package "PIPER_MSGS::GRIPPER"))
(unless (find-package "PIPER_MSGS::GRIPPERREQUEST")
  (make-package "PIPER_MSGS::GRIPPERREQUEST"))
(unless (find-package "PIPER_MSGS::GRIPPERRESPONSE")
  (make-package "PIPER_MSGS::GRIPPERRESPONSE"))

(in-package "ROS")





(defclass piper_msgs::GripperRequest
  :super ros::object
  :slots (_gripper_angle _gripper_effort _gripper_code _set_zero ))

(defmethod piper_msgs::GripperRequest
  (:init
   (&key
    ((:gripper_angle __gripper_angle) 0.0)
    ((:gripper_effort __gripper_effort) 0.0)
    ((:gripper_code __gripper_code) 0)
    ((:set_zero __set_zero) 0)
    )
   (send-super :init)
   (setq _gripper_angle (float __gripper_angle))
   (setq _gripper_effort (float __gripper_effort))
   (setq _gripper_code (round __gripper_code))
   (setq _set_zero (round __set_zero))
   self)
  (:gripper_angle
   (&optional __gripper_angle)
   (if __gripper_angle (setq _gripper_angle __gripper_angle)) _gripper_angle)
  (:gripper_effort
   (&optional __gripper_effort)
   (if __gripper_effort (setq _gripper_effort __gripper_effort)) _gripper_effort)
  (:gripper_code
   (&optional __gripper_code)
   (if __gripper_code (setq _gripper_code __gripper_code)) _gripper_code)
  (:set_zero
   (&optional __set_zero)
   (if __set_zero (setq _set_zero __set_zero)) _set_zero)
  (:serialization-length
   ()
   (+
    ;; float64 _gripper_angle
    8
    ;; float64 _gripper_effort
    8
    ;; int64 _gripper_code
    8
    ;; int64 _set_zero
    8
    ))
  (:serialize
   (&optional strm)
   (let ((s (if strm strm
              (make-string-output-stream (send self :serialization-length)))))
     ;; float64 _gripper_angle
       (sys::poke _gripper_angle (send s :buffer) (send s :count) :double) (incf (stream-count s) 8)
     ;; float64 _gripper_effort
       (sys::poke _gripper_effort (send s :buffer) (send s :count) :double) (incf (stream-count s) 8)
     ;; int64 _gripper_code
#+(or :alpha :irix6 :x86_64)
       (progn (sys::poke _gripper_code (send s :buffer) (send s :count) :long) (incf (stream-count s) 8))
#-(or :alpha :irix6 :x86_64)
       (cond ((and (class _gripper_code) (= (length (_gripper_code . bv)) 2)) ;; bignum
              (write-long (ash (elt (_gripper_code . bv) 0) 0) s)
              (write-long (ash (elt (_gripper_code . bv) 1) -1) s))
             ((and (class _gripper_code) (= (length (_gripper_code . bv)) 1)) ;; big1
              (write-long (elt (_gripper_code . bv) 0) s)
              (write-long (if (>= _gripper_code 0) 0 #xffffffff) s))
             (t                                         ;; integer
              (write-long _gripper_code s)(write-long (if (>= _gripper_code 0) 0 #xffffffff) s)))
     ;; int64 _set_zero
#+(or :alpha :irix6 :x86_64)
       (progn (sys::poke _set_zero (send s :buffer) (send s :count) :long) (incf (stream-count s) 8))
#-(or :alpha :irix6 :x86_64)
       (cond ((and (class _set_zero) (= (length (_set_zero . bv)) 2)) ;; bignum
              (write-long (ash (elt (_set_zero . bv) 0) 0) s)
              (write-long (ash (elt (_set_zero . bv) 1) -1) s))
             ((and (class _set_zero) (= (length (_set_zero . bv)) 1)) ;; big1
              (write-long (elt (_set_zero . bv) 0) s)
              (write-long (if (>= _set_zero 0) 0 #xffffffff) s))
             (t                                         ;; integer
              (write-long _set_zero s)(write-long (if (>= _set_zero 0) 0 #xffffffff) s)))
     ;;
     (if (null strm) (get-output-stream-string s))))
  (:deserialize
   (buf &optional (ptr- 0))
   ;; float64 _gripper_angle
     (setq _gripper_angle (sys::peek buf ptr- :double)) (incf ptr- 8)
   ;; float64 _gripper_effort
     (setq _gripper_effort (sys::peek buf ptr- :double)) (incf ptr- 8)
   ;; int64 _gripper_code
#+(or :alpha :irix6 :x86_64)
      (setf _gripper_code (prog1 (sys::peek buf ptr- :long) (incf ptr- 8)))
#-(or :alpha :irix6 :x86_64)
      (setf _gripper_code (let ((b0 (prog1 (sys::peek buf ptr- :integer) (incf ptr- 4)))
                  (b1 (prog1 (sys::peek buf ptr- :integer) (incf ptr- 4))))
              (cond ((= b1 -1) b0)
                     ((and (= b1  0)
                           (<= lisp::most-negative-fixnum b0 lisp::most-positive-fixnum))
                      b0)
                    ((= b1  0) (make-instance bignum :size 1 :bv (integer-vector b0)))
                    (t (make-instance bignum :size 2 :bv (integer-vector b0 (ash b1 1)))))))
   ;; int64 _set_zero
#+(or :alpha :irix6 :x86_64)
      (setf _set_zero (prog1 (sys::peek buf ptr- :long) (incf ptr- 8)))
#-(or :alpha :irix6 :x86_64)
      (setf _set_zero (let ((b0 (prog1 (sys::peek buf ptr- :integer) (incf ptr- 4)))
                  (b1 (prog1 (sys::peek buf ptr- :integer) (incf ptr- 4))))
              (cond ((= b1 -1) b0)
                     ((and (= b1  0)
                           (<= lisp::most-negative-fixnum b0 lisp::most-positive-fixnum))
                      b0)
                    ((= b1  0) (make-instance bignum :size 1 :bv (integer-vector b0)))
                    (t (make-instance bignum :size 2 :bv (integer-vector b0 (ash b1 1)))))))
   ;;
   self)
  )

(defclass piper_msgs::GripperResponse
  :super ros::object
  :slots (_code _status ))

(defmethod piper_msgs::GripperResponse
  (:init
   (&key
    ((:code __code) 0)
    ((:status __status) nil)
    )
   (send-super :init)
   (setq _code (round __code))
   (setq _status __status)
   self)
  (:code
   (&optional __code)
   (if __code (setq _code __code)) _code)
  (:status
   (&optional (__status :null))
   (if (not (eq __status :null)) (setq _status __status)) _status)
  (:serialization-length
   ()
   (+
    ;; int64 _code
    8
    ;; bool _status
    1
    ))
  (:serialize
   (&optional strm)
   (let ((s (if strm strm
              (make-string-output-stream (send self :serialization-length)))))
     ;; int64 _code
#+(or :alpha :irix6 :x86_64)
       (progn (sys::poke _code (send s :buffer) (send s :count) :long) (incf (stream-count s) 8))
#-(or :alpha :irix6 :x86_64)
       (cond ((and (class _code) (= (length (_code . bv)) 2)) ;; bignum
              (write-long (ash (elt (_code . bv) 0) 0) s)
              (write-long (ash (elt (_code . bv) 1) -1) s))
             ((and (class _code) (= (length (_code . bv)) 1)) ;; big1
              (write-long (elt (_code . bv) 0) s)
              (write-long (if (>= _code 0) 0 #xffffffff) s))
             (t                                         ;; integer
              (write-long _code s)(write-long (if (>= _code 0) 0 #xffffffff) s)))
     ;; bool _status
       (if _status (write-byte -1 s) (write-byte 0 s))
     ;;
     (if (null strm) (get-output-stream-string s))))
  (:deserialize
   (buf &optional (ptr- 0))
   ;; int64 _code
#+(or :alpha :irix6 :x86_64)
      (setf _code (prog1 (sys::peek buf ptr- :long) (incf ptr- 8)))
#-(or :alpha :irix6 :x86_64)
      (setf _code (let ((b0 (prog1 (sys::peek buf ptr- :integer) (incf ptr- 4)))
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

(defclass piper_msgs::Gripper
  :super ros::object
  :slots ())

(setf (get piper_msgs::Gripper :md5sum-) "fca0ae84ccaed9dee57e974f132f6119")
(setf (get piper_msgs::Gripper :datatype-) "piper_msgs/Gripper")
(setf (get piper_msgs::Gripper :request) piper_msgs::GripperRequest)
(setf (get piper_msgs::Gripper :response) piper_msgs::GripperResponse)

(defmethod piper_msgs::GripperRequest
  (:response () (instance piper_msgs::GripperResponse :init)))

(setf (get piper_msgs::GripperRequest :md5sum-) "fca0ae84ccaed9dee57e974f132f6119")
(setf (get piper_msgs::GripperRequest :datatype-) "piper_msgs/GripperRequest")
(setf (get piper_msgs::GripperRequest :definition-)
      "float64 gripper_angle
float64 gripper_effort
int64 gripper_code
int64 set_zero
---
int64 code
bool status  # 响应消息类型为bool
")

(setf (get piper_msgs::GripperResponse :md5sum-) "fca0ae84ccaed9dee57e974f132f6119")
(setf (get piper_msgs::GripperResponse :datatype-) "piper_msgs/GripperResponse")
(setf (get piper_msgs::GripperResponse :definition-)
      "float64 gripper_angle
float64 gripper_effort
int64 gripper_code
int64 set_zero
---
int64 code
bool status  # 响应消息类型为bool
")



(provide :piper_msgs/Gripper "fca0ae84ccaed9dee57e974f132f6119")


