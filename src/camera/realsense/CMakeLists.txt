cmake_minimum_required(VERSION 3.0.2)
project(piper_realsense)

find_package(catkin REQUIRED COMPONENTS
  realsense2_camera
  rospy
  tf2_ros
  topic_tools
)

catkin_package(
  CATKIN_DEPENDS realsense2_camera rospy tf2_ros topic_tools
)

if(CATKIN_ENABLE_TESTING)
  find_package(roslaunch REQUIRED)
  roslaunch_add_file_check(
    launch/realsense_node.launch
    launch/realsense_static_tf.launch
    launch/realsense_bringup.launch
  )
endif()

install(DIRECTORY launch config rviz docs
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)

install(FILES README.md
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
