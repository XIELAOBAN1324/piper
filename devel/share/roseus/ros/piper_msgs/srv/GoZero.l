;; Auto-generated. Do not edit!


(when (boundp 'piper_msgs::GoZero)
  (if (not (find-package "PIPER_MSGS"))
    (make-package "PIPER_MSGS"))
  (shadow 'GoZero (find-package "PIPER_MSGS")))
(unless (find-package "PIPER_MSGS::GOZERO")
  (make-package "PIPER_MSGS::GOZERO"))
(unless (find-package "PIPER_MSGS::GOZEROREQUEST")
  (make-package "PIPER_MSGS::GOZEROREQUEST"))
(unless (find-package "PIPER_MSGS::GOZERORESPONSE")
  (make-package "PIPER_MSGS::GOZERORESPONSE"))

(in-package "ROS")





(defclass piper_msgs::GoZeroRequest
  :super ros::object
  :slots (_is_mit_mode ))

(defmethod piper_msgs::GoZeroRequest
  (:init
   (&key
    ((:is_mit_mode __is_mit_mode) nil)
    )
   (send-super :init)
   (setq _is_mit_mode __is_mit_mode)
   self)
  (:is_mit_mode
   (&optional (__is_mit_mode :null))
   (if (not (eq __is_mit_mode :null)) (setq _is_mit_mode __is_mit_mode)) _is_mit_mode)
  (:serialization-length
   ()
   (+
    ;; bool _is_mit_mode
    1
    ))
  (:serialize
   (&optional strm)
   (let ((s (if strm strm
              (make-string-output-stream (send self :serialization-length)))))
     ;; bool _is_mit_mode
       (if _is_mit_mode (write-byte -1 s) (write-byte 0 s))
     ;;
     (if (null strm) (get-output-stream-string s))))
  (:deserialize
   (buf &optional (ptr- 0))
   ;; bool _is_mit_mode
     (setq _is_mit_mode (not (= 0 (sys::peek buf ptr- :char)))) (incf ptr- 1)
   ;;
   self)
  )

(defclass piper_msgs::GoZeroResponse
  :super ros::object
  :slots (_code _status ))

(defmethod piper_msgs::GoZeroResponse
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

(defclass piper_msgs::GoZero
  :super ros::object
  :slots ())

(setf (get piper_msgs::GoZero :md5sum-) "d8cded8be1d1727ecab27b0820b4be6f")
(setf (get piper_msgs::GoZero :datatype-) "piper_msgs/GoZero")
(setf (get piper_msgs::GoZero :request) piper_msgs::GoZeroRequest)
(setf (get piper_msgs::GoZero :response) piper_msgs::GoZeroResponse)

(defmethod piper_msgs::GoZeroRequest
  (:response () (instance piper_msgs::GoZeroResponse :init)))

(setf (get piper_msgs::GoZeroRequest :md5sum-) "d8cded8be1d1727ecab27b0820b4be6f")
(setf (get piper_msgs::GoZeroRequest :datatype-) "piper_msgs/GoZeroRequest")
(setf (get piper_msgs::GoZeroRequest :definition-)
      "bool is_mit_mode
---
int64 code
bool status  # 响应消息类型为bool
")

(setf (get piper_msgs::GoZeroResponse :md5sum-) "d8cded8be1d1727ecab27b0820b4be6f")
(setf (get piper_msgs::GoZeroResponse :datatype-) "piper_msgs/GoZeroResponse")
(setf (get piper_msgs::GoZeroResponse :definition-)
      "bool is_mit_mode
---
int64 code
bool status  # 响应消息类型为bool
")



(provide :piper_msgs/GoZero "d8cded8be1d1727ecab27b0820b4be6f")


