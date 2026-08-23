
(cl:in-package :asdf)

(defsystem "piper_msgs-msg"
  :depends-on (:roslisp-msg-protocol :roslisp-utils :std_msgs-msg
)
  :components ((:file "_package")
    (:file "PiperEulerPose" :depends-on ("_package_PiperEulerPose"))
    (:file "_package_PiperEulerPose" :depends-on ("_package"))
    (:file "PiperStatusMsg" :depends-on ("_package_PiperStatusMsg"))
    (:file "_package_PiperStatusMsg" :depends-on ("_package"))
    (:file "PosCmd" :depends-on ("_package_PosCmd"))
    (:file "_package_PosCmd" :depends-on ("_package"))
  ))