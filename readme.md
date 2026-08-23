## 双臂示教准备脚本

当前只保留完整初始化流程：

```bash
cd /home/test/piper
bash src/data/prepare_dual_arm_teach.sh --full
```

`--full` 会提示你按顺序断电、上电、写 role、再次断电，再按“从臂先上电、主臂后上电”的顺序恢复，然后启动双 `CAN` 主从桥接。无参数启动也会执行同一个完整初始化流程，并在日志中明确提示。

等价启动方式：

```bash
cd /home/test/piper
bash src/data/prepare_dual_arm_teach.sh
```

## 当前回零结论

实机诊断显示：`ReqMasterArmMoveToHome(2)` 后，当前软件恢复序列无法让 master 回到 `ctrl_mode=0x06`。

因此本工程暂时不支持 mode2 回零后自动恢复下一轮示教。`/finish_teach_and_go_zero_srv` 当前定义为“结束本轮示教并回零”，回零后 bridge 自动退出。

## 结束示教并双臂回零

推荐启动：

```bash
cd /home/test/piper

SHUTDOWN_AFTER_FINISH=true \
GO_HOME_MODE2_FORWARD_AFTER_REQUEST_SEC=2.5 \
GO_HOME_MODE2_STOP_FORWARD_ON_MASTER_STANDBY=true \
bash src/data/prepare_dual_arm_teach.sh --full
```

示教结束后，另开一个终端调用正式服务：

```bash
source /opt/ros/noetic/setup.bash
source /home/test/piper/devel/setup.bash
rosservice call /finish_teach_and_go_zero_srv "{}"
```

该服务只发送官方 SDK mode=2 请求：

```python
master.ReqMasterArmMoveToHome(2)
```

预期行为：

1. 双臂回零。
2. bridge 继续转发有限时间。
3. 检测到 master `ctrl_mode=0` 或时间窗口结束。
4. 第一个终端自动退出。

正式回零路径不会执行 slave `JointCtrl`、`ModeCtrl`、`MotionCtrl_2`、`DisableArm`、`ResetPiper`、`EmergencyStop(0x01)` 或 `ReqMasterArmMoveToHome(1)`。

## 常用环境变量

如果默认“左主右从”不符合当前接线，可以在执行前覆盖这些变量：

```bash
MASTER_ARM_CAN=can_piper_left
SLAVE_ARM_CAN=can_piper_right
LEFT_CAN_NAME=can_piper_left
RIGHT_CAN_NAME=can_piper_right
LEFT_USB_BUS=1-2:1.0
RIGHT_USB_BUS=1-1:1.0
```

桥接和 mode2 回零窗口参数：

```bash
BRIDGE_RATE_HZ=200
COMMAND_TIMEOUT_SEC=0.5
AUTO_ENABLE_SLAVE=true
FOLLOW_GRIPPER=true
HOLD_LAST_JOINT_ON_TIMEOUT=true
GO_HOME_MODE2_RECOVER_SLAVE_BEFORE_REQUEST=false
GO_HOME_MODE2_REQUEST_COUNT=1
GO_HOME_MODE2_REQUEST_INTERVAL_SEC=0.2
GO_HOME_MODE2_FORWARD_AFTER_REQUEST_SEC=2.5
GO_HOME_MODE2_OBSERVE_INTERVAL_SEC=0.2
GO_HOME_MODE2_STOP_FORWARD_ON_MASTER_STANDBY=true
SHUTDOWN_AFTER_FINISH=true
```

## 调参建议

如果 slave 回零不完整：

```bash
GO_HOME_MODE2_FORWARD_AFTER_REQUEST_SEC=3.0
```

如果回零后仍然下坠明显：

```bash
GO_HOME_MODE2_FORWARD_AFTER_REQUEST_SEC=1.5
```

目标是找到一个窗口：足够长，让 mode2 回零控制帧能转发到 slave；足够短，不继续转发 master 进入 `ctrl_mode=0` 后的 standby/disable 状态。

## 测试命令

启动：

```bash
cd /home/test/piper

SHUTDOWN_AFTER_FINISH=true \
GO_HOME_MODE2_FORWARD_AFTER_REQUEST_SEC=2.5 \
GO_HOME_MODE2_STOP_FORWARD_ON_MASTER_STANDBY=true \
bash src/data/prepare_dual_arm_teach.sh --full
```

调用：

```bash
source /opt/ros/noetic/setup.bash
source /home/test/piper/devel/setup.bash
rosservice call /finish_teach_and_go_zero_srv "{}"
```

查看日志：

```bash
grep -R "go_home_mode2\|ReqMasterArmMoveToHome(2)\|master ctrl_mode=0\|forward window elapsed\|shutdown_after_finish" \
  -n ~/.ros/log/latest /home/test/piper/log/ros 2>/dev/null | tail -n 300
```

脚本运行日志会写到：

```bash
/home/test/piper/log/ros/prepare_dual_arm_teach_*.log
```
### 控制模式初始化流程

```bash
cd /home/test/piper
source /opt/ros/noetic/setup.bash
source devel/setup.bash
roscore
```

## 启动piper单臂控制节点

```bash
source /opt/ros/noetic/setup.bash
source devel/setup.bash
roslaunch piper start_single_piper.launch \
    can_port:=can_piper_right \
    auto_enable:=true
```


### 启动示教流程

```bash
roscore
```

## 打开全局相机和碗部相机

```bash
cd ~/piper
bash src/data/start_dual_rgbd_cameras.sh orbbec
bash src/data/start_dual_rgbd_cameras.sh d435i
GLOBAL_CAMERA_TYPE=d435i bash src/data/start_dual_rgbd_cameras.sh
```

## 也可以单独打开某个相机

```bash
cd ~/piper
bash src/data/start_orbbec_rgbd_pointcloud.sh
bash src/data/start_d405_rgbd_pointcloud.sh
```

# 启动相机后打开图像

```bash
rqt_image_view
```

# 检查当前全局相机

```bash
bash src/data/check_active_global_camera.sh
```
# 检查点云

```bash
RECORD_POINTCLOUD=true bash src/data/check_active_global_camera.sh
```

## 启动遥操作

```bash
RECORD_ENABLE=true RECORD_RATE_HZ=30 bash src/data/prepare_dual_arm_teach.sh --full
```
## 打开另一个终端录包，使用ctrl+c终止采集

```bash
TASK_NAME=pick_block EPISODE_NAME=episode_001 bash src/data/record_dual_arm_dataset.sh
```
## 结束采集并归零机械臂

# 每次采集结束后，将机械臂归零，准备下一次的采集

```bash
python3 src/data/go_zero_and_restore_dual_arm_teach.py \
  --master-can can_piper_left \
  --slave-can can_piper_right \
  --zero-speed 20 \
  --zero-duration 5
```

# 全部采集结束后，结束bridge

```bash
rosservice call /finish_teach_and_go_zero_srv "{}"
```

### 转 HDF5

```bash
python3 src/data/bag_to_piper_hdf5.py \
  --bag dataset/piper_teleop/pick_block/20260706_115444/episode_000001/raw/raw.bag \
  --out dataset/piper_teleop/pick_block/20260706_115444/episode_000001/processed/episode.hdf5
```

或者

```bash
python3 src/data/bag_to_piper_hdf5.py \
  --data-root dataset/piper_teleop
```

## 复现 HDF5

```bash
python3 src/data/replay_piper_episode_viewer.py \
   --hdf5 dataset/piper_teleop/pick_block/episode_001/processed/episode.hdf5 \
   --speed 1 \
   --record-video \
   --rgbd-only \
   --show-live-cameras \
   --execute-robot \
   --replay-gripper \
   --fps 30 \
   --loop 
```
