
(cl:in-package :asdf)

(defsystem "moveit_ctrl-srv"
  :depends-on (:roslisp-msg-protocol :roslisp-utils )
  :components ((:file "_package")
    (:file "JointMoveitCtrl" :depends-on ("_package_JointMoveitCtrl"))
    (:file "_package_JointMoveitCtrl" :depends-on ("_package"))
  ))