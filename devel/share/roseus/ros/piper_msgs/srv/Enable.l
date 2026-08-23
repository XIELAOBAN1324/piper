;; Auto-generated. Do not edit!


(when (boundp 'piper_msgs::Enable)
  (if (not (find-package "PIPER_MSGS"))
    (make-package "PIPER_MSGS"))
  (shadow 'Enable (find-package "PIPER_MSGS")))
(unless (find-package "PIPER_MSGS::ENABLE")
  (make-package "PIPER_MSGS::ENABLE"))
(unless (find-package "PIPER_MSGS::ENABLEREQUEST")
  (make-package "PIPER_MSGS::ENABLEREQUEST"))
(unless (find-package "PIPER_MSGS::ENABLERESPONSE")
  (make-package "PIPER_MSGS::ENABLERESPONSE"))

(in-package "ROS")





(defclass piper_msgs::EnableRequest
  :super ros::object
  :slots (_enable_request ))

(defmethod piper_msgs::EnableRequest
  (:init
   (&key
    ((:enable_request __enable_request) nil)
    )
   (send-super :init)
   (setq _enable_request __enable_request)
   self)
  (:enable_request
   (&optional (__enable_request :null))
   (if (not (eq __enable_request :null)) (setq _enable_request __enable_request)) _enable_request)
  (:serialization-length
   ()
   (+
    ;; bool _enable_request
    1
    ))
  (:serialize
   (&optional strm)
   (let ((s (if strm strm
              (make-string-output-stream (send self :serialization-length)))))
     ;; bool _enable_request
       (if _enable_request (write-byte -1 s) (write-byte 0 s))
     ;;
     (if (null strm) (get-output-stream-string s))))
  (:deserialize
   (buf &optional (ptr- 0))
   ;; bool _enable_request
     (setq _enable_request (not (= 0 (sys::peek buf ptr- :char)))) (incf ptr- 1)
   ;;
   self)
  )

(defclass piper_msgs::EnableResponse
  :super ros::object
  :slots (_enable_response ))

(defmethod piper_msgs::EnableResponse
  (:init
   (&key
    ((:enable_response __enable_response) nil)
    )
   (send-super :init)
   (setq _enable_response __enable_response)
   self)
  (:enable_response
   (&optional (__enable_response :null))
   (if (not (eq __enable_response :null)) (setq _enable_response __enable_response)) _enable_response)
  (:serialization-length
   ()
   (+
    ;; bool _enable_response
    1
    ))
  (:serialize
   (&optional strm)
   (let ((s (if strm strm
              (make-string-output-stream (send self :serialization-length)))))
     ;; bool _enable_response
       (if _enable_response (write-byte -1 s) (write-byte 0 s))
     ;;
     (if (null strm) (get-output-stream-string s))))
  (:deserialize
   (buf &optional (ptr- 0))
   ;; bool _enable_response
     (setq _enable_response (not (= 0 (sys::peek buf ptr- :char)))) (incf ptr- 1)
   ;;
   self)
  )

(defclass piper_msgs::Enable
  :super ros::object
  :slots ())

(setf (get piper_msgs::Enable :md5sum-) "ab5da25e2334681fe9da4d5fb9858409")
(setf (get piper_msgs::Enable :datatype-) "piper_msgs/Enable")
(setf (get piper_msgs::Enable :request) piper_msgs::EnableRequest)
(setf (get piper_msgs::Enable :response) piper_msgs::EnableResponse)

(defmethod piper_msgs::EnableRequest
  (:response () (instance piper_msgs::EnableResponse :init)))

(setf (get piper_msgs::EnableRequest :md5sum-) "ab5da25e2334681fe9da4d5fb9858409")
(setf (get piper_msgs::EnableRequest :datatype-) "piper_msgs/EnableRequest")
(setf (get piper_msgs::EnableRequest :definition-)
      "bool enable_request  # 请求消息类型为bool
---
bool enable_response  # 响应消息类型为bool

")

(setf (get piper_msgs::EnableResponse :md5sum-) "ab5da25e2334681fe9da4d5fb9858409")
(setf (get piper_msgs::EnableResponse :datatype-) "piper_msgs/EnableResponse")
(setf (get piper_msgs::EnableResponse :definition-)
      "bool enable_request  # 请求消息类型为bool
---
bool enable_response  # 响应消息类型为bool

")



(provide :piper_msgs/Enable "ab5da25e2334681fe9da4d5fb9858409")


