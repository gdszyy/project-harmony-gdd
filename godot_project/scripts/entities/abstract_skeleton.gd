## abstract_skeleton.gd
## 抽象"指挥家"骨骼系统 (Issue #59)
##
## 实现一个不可见的 Skeleton3D 骨架，用于驱动程序化角色化身的施法动画。
## 骨骼层级：root -> torso -> shoulder_l/r -> arm_l/r -> hand_l/r
##
## 核心职责：
##   1. 程序化创建 Skeleton3D 及其骨骼层级
##   2. 创建 AnimationPlayer 和基础动画基元（姿态、手势）
##   3. 提供 BoneAttachment3D 锚点供几何体附着
##   4. 响应 BPM 同步和施法事件驱动骨骼动画
extends Node3D

class_name AbstractSkeleton

# ============================================================
# 信号
# ============================================================
signal gesture_started(gesture_name: String)
signal gesture_finished(gesture_name: String)
signal stance_changed(new_stance: String)

# ============================================================
# 配置
# ============================================================
## BPM 同步倍率（不同调式可调整）
@export var bpm_sync_multiplier: float = 1.0
## 动画速度倍率
@export var animation_speed_multiplier: float = 1.0
## 动作幅度倍率
@export var motion_amplitude: float = 1.0
## 手势混合时间
@export var gesture_blend_time: float = 0.15

# ============================================================
# 骨骼索引常量
# ============================================================
enum BoneID {
	ROOT = 0,
	TORSO = 1,
	SHOULDER_L = 2,
	ARM_L = 3,
	HAND_L = 4,
	SHOULDER_R = 5,
	ARM_R = 6,
	HAND_R = 7,
}

# 骨骼名称映射
const BONE_NAMES: Dictionary = {
	BoneID.ROOT: "root",
	BoneID.TORSO: "torso",
	BoneID.SHOULDER_L: "shoulder_l",
	BoneID.ARM_L: "arm_l",
	BoneID.HAND_L: "hand_l",
	BoneID.SHOULDER_R: "shoulder_r",
	BoneID.ARM_R: "arm_r",
	BoneID.HAND_R: "hand_r",
}

# ============================================================
# 节点引用
# ============================================================
var skeleton: Skeleton3D = null
var animation_player: AnimationPlayer = null

## BoneAttachment3D 锚点字典 {骨骼名称: BoneAttachment3D}
var bone_attachments: Dictionary = {}

# ============================================================
# 状态
# ============================================================
var _current_stance: String = "idle"
var _is_gesture_playing: bool = false
var _current_gesture: String = ""
var _time: float = 0.0
var _beat_pulse: float = 0.0

## 程序化修改器叠加
var _modifier_glitch_intensity: float = 0.0
var _modifier_impact_offset: Vector3 = Vector3.ZERO
var _modifier_impact_decay: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_create_skeleton()
	_create_bone_attachments()
	_create_animation_player()
	_create_animations()
	_connect_signals()

func _process(delta: float) -> void:
	_time += delta
	_update_bpm_breathing(delta)
	_update_modifiers(delta)

# ============================================================
# 骨骼创建
# ============================================================

## 程序化创建 Skeleton3D 及其骨骼层级
func _create_skeleton() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "ConductorSkeleton"
	add_child(skeleton)

	# 添加骨骼
	# root (索引 0)
	skeleton.add_bone("root")

	# torso (索引 1, 父: root)
	skeleton.add_bone("torso")
	skeleton.set_bone_parent(BoneID.TORSO, BoneID.ROOT)

	# shoulder_l (索引 2, 父: torso)
	skeleton.add_bone("shoulder_l")
	skeleton.set_bone_parent(BoneID.SHOULDER_L, BoneID.TORSO)

	# arm_l (索引 3, 父: shoulder_l)
	skeleton.add_bone("arm_l")
	skeleton.set_bone_parent(BoneID.ARM_L, BoneID.SHOULDER_L)

	# hand_l (索引 4, 父: arm_l)
	skeleton.add_bone("hand_l")
	skeleton.set_bone_parent(BoneID.HAND_L, BoneID.ARM_L)

	# shoulder_r (索引 5, 父: torso)
	skeleton.add_bone("shoulder_r")
	skeleton.set_bone_parent(BoneID.SHOULDER_R, BoneID.TORSO)

	# arm_r (索引 6, 父: shoulder_r)
	skeleton.add_bone("arm_r")
	skeleton.set_bone_parent(BoneID.ARM_R, BoneID.SHOULDER_R)

	# hand_r (索引 7, 父: arm_r)
	skeleton.add_bone("hand_r")
	skeleton.set_bone_parent(BoneID.HAND_R, BoneID.ARM_R)

	# 设置骨骼静息姿态（Rest Pose）
	_setup_rest_poses()

## 设置骨骼静息姿态
func _setup_rest_poses() -> void:
	# root: 原点
	skeleton.set_bone_rest(BoneID.ROOT, Transform3D.IDENTITY)

	# torso: 略高于 root
	skeleton.set_bone_rest(BoneID.TORSO, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)))

	# shoulder_l: 向左偏移
	skeleton.set_bone_rest(BoneID.SHOULDER_L, Transform3D(Basis.IDENTITY, Vector3(-0.3, 0.3, 0)))

	# arm_l: 向下延伸
	skeleton.set_bone_rest(BoneID.ARM_L, Transform3D(Basis.IDENTITY, Vector3(-0.2, -0.2, 0)))

	# hand_l: 继续向下
	skeleton.set_bone_rest(BoneID.HAND_L, Transform3D(Basis.IDENTITY, Vector3(-0.1, -0.2, 0)))

	# shoulder_r: 向右偏移
	skeleton.set_bone_rest(BoneID.SHOULDER_R, Transform3D(Basis.IDENTITY, Vector3(0.3, 0.3, 0)))

	# arm_r: 向下延伸
	skeleton.set_bone_rest(BoneID.ARM_R, Transform3D(Basis.IDENTITY, Vector3(0.2, -0.2, 0)))

	# hand_r: 继续向下
	skeleton.set_bone_rest(BoneID.HAND_R, Transform3D(Basis.IDENTITY, Vector3(0.1, -0.2, 0)))

# ============================================================
# BoneAttachment3D 创建
# ============================================================

## 为每个骨骼创建 BoneAttachment3D 锚点
func _create_bone_attachments() -> void:
	for bone_id in BONE_NAMES:
		var bone_name: String = BONE_NAMES[bone_id]
		var attachment := BoneAttachment3D.new()
		attachment.name = "Attach_" + bone_name
		attachment.bone_name = bone_name
		skeleton.add_child(attachment)
		bone_attachments[bone_name] = attachment

## 获取指定骨骼的附着点
func get_attachment(bone_name: String) -> BoneAttachment3D:
	return bone_attachments.get(bone_name, null)

## 获取核心附着点（torso）
func get_core_attachment() -> BoneAttachment3D:
	return bone_attachments.get("torso", null)

## 获取左手附着点
func get_hand_l_attachment() -> BoneAttachment3D:
	return bone_attachments.get("hand_l", null)

## 获取右手附着点
func get_hand_r_attachment() -> BoneAttachment3D:
	return bone_attachments.get("hand_r", null)

# ============================================================
# AnimationPlayer 创建
# ============================================================

func _create_animation_player() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)

	# 连接动画完成信号
	animation_player.animation_finished.connect(_on_animation_finished)

# ============================================================
# 动画基元创建
# ============================================================

func _create_animations() -> void:
	_create_stance_idle()
	_create_stance_combat()
	_create_stance_channeling()
	_create_gesture_point()
	_create_gesture_draw_circle()
	_create_gesture_raise()
	_create_gesture_push()
	_create_gesture_flick()

## 姿态：待机 - 双手自然垂于身体两侧，随BPM轻微起伏
func _create_stance_idle() -> void:
	var anim := Animation.new()
	anim.length = 2.0
	anim.loop_mode = Animation.LOOP_LINEAR

	# torso 上下微动（呼吸感）
	var torso_track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(torso_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.TORSO])
	anim.track_insert_key(torso_track, 0.0, Vector3(0, 0.5, 0))
	anim.track_insert_key(torso_track, 1.0, Vector3(0, 0.52, 0))
	anim.track_insert_key(torso_track, 2.0, Vector3(0, 0.5, 0))

	# arm_l 小幅摆动
	var arm_l_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(arm_l_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.ARM_L])
	anim.track_insert_key(arm_l_track, 0.0, Quaternion.from_euler(Vector3(0, 0, 0.02)))
	anim.track_insert_key(arm_l_track, 1.0, Quaternion.from_euler(Vector3(0, 0, -0.02)))
	anim.track_insert_key(arm_l_track, 2.0, Quaternion.from_euler(Vector3(0, 0, 0.02)))

	# arm_r 小幅摆动（反相）
	var arm_r_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(arm_r_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.ARM_R])
	anim.track_insert_key(arm_r_track, 0.0, Quaternion.from_euler(Vector3(0, 0, -0.02)))
	anim.track_insert_key(arm_r_track, 1.0, Quaternion.from_euler(Vector3(0, 0, 0.02)))
	anim.track_insert_key(arm_r_track, 2.0, Quaternion.from_euler(Vector3(0, 0, -0.02)))

	var lib := AnimationLibrary.new()
	lib.add_animation("Stance_Idle", anim)
	animation_player.add_animation_library("stances", lib)

## 姿态：战斗准备 - 双手抬起至胸前
func _create_stance_combat() -> void:
	var anim := Animation.new()
	anim.length = 1.5
	anim.loop_mode = Animation.LOOP_LINEAR

	# 双臂抬起
	var arm_l_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(arm_l_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.ARM_L])
	anim.track_insert_key(arm_l_track, 0.0, Quaternion.from_euler(Vector3(-0.3, 0, 0.1)))
	anim.track_insert_key(arm_l_track, 0.75, Quaternion.from_euler(Vector3(-0.32, 0, 0.08)))
	anim.track_insert_key(arm_l_track, 1.5, Quaternion.from_euler(Vector3(-0.3, 0, 0.1)))

	var arm_r_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(arm_r_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.ARM_R])
	anim.track_insert_key(arm_r_track, 0.0, Quaternion.from_euler(Vector3(-0.3, 0, -0.1)))
	anim.track_insert_key(arm_r_track, 0.75, Quaternion.from_euler(Vector3(-0.32, 0, -0.08)))
	anim.track_insert_key(arm_r_track, 1.5, Quaternion.from_euler(Vector3(-0.3, 0, -0.1)))

	# 手悬停
	var hand_l_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(hand_l_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.HAND_L])
	anim.track_insert_key(hand_l_track, 0.0, Quaternion.from_euler(Vector3(0.1, 0, 0)))
	anim.track_insert_key(hand_l_track, 0.75, Quaternion.from_euler(Vector3(0.12, 0.02, 0)))
	anim.track_insert_key(hand_l_track, 1.5, Quaternion.from_euler(Vector3(0.1, 0, 0)))

	if animation_player.has_animation_library("stances"):
		animation_player.get_animation_library("stances").add_animation("Stance_Combat", anim)

## 姿态：持续施法/引导 - 双手向前举起，有能量集中的抖动
func _create_stance_channeling() -> void:
	var anim := Animation.new()
	anim.length = 1.0
	anim.loop_mode = Animation.LOOP_LINEAR

	# 双臂前伸并锁定
	var arm_l_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(arm_l_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.ARM_L])
	anim.track_insert_key(arm_l_track, 0.0, Quaternion.from_euler(Vector3(-0.5, 0.1, 0.2)))
	anim.track_insert_key(arm_l_track, 0.5, Quaternion.from_euler(Vector3(-0.52, 0.08, 0.22)))
	anim.track_insert_key(arm_l_track, 1.0, Quaternion.from_euler(Vector3(-0.5, 0.1, 0.2)))

	var arm_r_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(arm_r_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.ARM_R])
	anim.track_insert_key(arm_r_track, 0.0, Quaternion.from_euler(Vector3(-0.5, -0.1, -0.2)))
	anim.track_insert_key(arm_r_track, 0.5, Quaternion.from_euler(Vector3(-0.52, -0.08, -0.22)))
	anim.track_insert_key(arm_r_track, 1.0, Quaternion.from_euler(Vector3(-0.5, -0.1, -0.2)))

	# 高频抖动通过修改器叠加，此处只设基础姿势
	if animation_player.has_animation_library("stances"):
		animation_player.get_animation_library("stances").add_animation("Stance_Channeling", anim)

## 手势：指向 - 单手或双手快速向前直指
func _create_gesture_point() -> void:
	var anim := Animation.new()
	anim.length = 0.4
	anim.loop_mode = Animation.LOOP_NONE

	# 双臂快速前伸
	var arm_r_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(arm_r_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.ARM_R])
	anim.track_insert_key(arm_r_track, 0.0, Quaternion.from_euler(Vector3(-0.3, 0, -0.1)))
	anim.track_insert_key(arm_r_track, 0.15, Quaternion.from_euler(Vector3(-0.8, 0, -0.05)))
	anim.track_insert_key(arm_r_track, 0.25, Quaternion.from_euler(Vector3(-0.75, 0, -0.07)))
	anim.track_insert_key(arm_r_track, 0.4, Quaternion.from_euler(Vector3(-0.3, 0, -0.1)))

	# 手指向前
	var hand_r_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(hand_r_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.HAND_R])
	anim.track_insert_key(hand_r_track, 0.0, Quaternion.from_euler(Vector3(0, 0, 0)))
	anim.track_insert_key(hand_r_track, 0.15, Quaternion.from_euler(Vector3(-0.3, 0, 0)))
	anim.track_insert_key(hand_r_track, 0.4, Quaternion.from_euler(Vector3(0, 0, 0)))

	var lib := AnimationLibrary.new()
	lib.add_animation("Gesture_Point", anim)
	animation_player.add_animation_library("gestures", lib)

## 手势：画圆 - 双手在胸前画一个圆
func _create_gesture_draw_circle() -> void:
	var anim := Animation.new()
	anim.length = 0.6
	anim.loop_mode = Animation.LOOP_NONE

	# 左手沿圆形轨迹
	var hand_l_track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hand_l_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.HAND_L])
	var circle_steps := 8
	for i in range(circle_steps + 1):
		var t: float = float(i) / float(circle_steps)
		var angle: float = t * TAU
		var offset := Vector3(cos(angle) * 0.15, sin(angle) * 0.15, 0)
		anim.track_insert_key(hand_l_track, t * 0.6, Vector3(-0.1, -0.2, 0) + offset)

	# 右手沿反向圆形轨迹
	var hand_r_track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hand_r_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.HAND_R])
	for i in range(circle_steps + 1):
		var t: float = float(i) / float(circle_steps)
		var angle: float = -t * TAU
		var offset := Vector3(cos(angle) * 0.15, sin(angle) * 0.15, 0)
		anim.track_insert_key(hand_r_track, t * 0.6, Vector3(0.1, -0.2, 0) + offset)

	if animation_player.has_animation_library("gestures"):
		animation_player.get_animation_library("gestures").add_animation("Gesture_DrawCircle", anim)

## 手势：高举 - 双手从下向上高举
func _create_gesture_raise() -> void:
	var anim := Animation.new()
	anim.length = 0.5
	anim.loop_mode = Animation.LOOP_NONE

	# 双臂向上抬升
	var arm_l_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(arm_l_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.ARM_L])
	anim.track_insert_key(arm_l_track, 0.0, Quaternion.from_euler(Vector3(-0.3, 0, 0.1)))
	anim.track_insert_key(arm_l_track, 0.3, Quaternion.from_euler(Vector3(-1.2, 0, 0.3)))
	anim.track_insert_key(arm_l_track, 0.5, Quaternion.from_euler(Vector3(-0.3, 0, 0.1)))

	var arm_r_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(arm_r_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.ARM_R])
	anim.track_insert_key(arm_r_track, 0.0, Quaternion.from_euler(Vector3(-0.3, 0, -0.1)))
	anim.track_insert_key(arm_r_track, 0.3, Quaternion.from_euler(Vector3(-1.2, 0, -0.3)))
	anim.track_insert_key(arm_r_track, 0.5, Quaternion.from_euler(Vector3(-0.3, 0, -0.1)))

	if animation_player.has_animation_library("gestures"):
		animation_player.get_animation_library("gestures").add_animation("Gesture_Raise", anim)

## 手势：前推 - 双手从胸前猛力前推
func _create_gesture_push() -> void:
	var anim := Animation.new()
	anim.length = 0.35
	anim.loop_mode = Animation.LOOP_NONE

	# 双臂猛力前推
	var arm_l_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(arm_l_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.ARM_L])
	anim.track_insert_key(arm_l_track, 0.0, Quaternion.from_euler(Vector3(-0.3, 0, 0.1)))
	anim.track_insert_key(arm_l_track, 0.1, Quaternion.from_euler(Vector3(-0.9, 0.2, 0.05)))
	anim.track_insert_key(arm_l_track, 0.35, Quaternion.from_euler(Vector3(-0.3, 0, 0.1)))

	var arm_r_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(arm_r_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.ARM_R])
	anim.track_insert_key(arm_r_track, 0.0, Quaternion.from_euler(Vector3(-0.3, 0, -0.1)))
	anim.track_insert_key(arm_r_track, 0.1, Quaternion.from_euler(Vector3(-0.9, -0.2, -0.05)))
	anim.track_insert_key(arm_r_track, 0.35, Quaternion.from_euler(Vector3(-0.3, 0, -0.1)))

	if animation_player.has_animation_library("gestures"):
		animation_player.get_animation_library("gestures").add_animation("Gesture_Push", anim)

## 手势：甩动 - 单手手腕快速向外甩动
func _create_gesture_flick() -> void:
	var anim := Animation.new()
	anim.length = 0.3
	anim.loop_mode = Animation.LOOP_NONE

	# 右手快速旋转甩动
	var hand_r_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(hand_r_track, "ConductorSkeleton:" + BONE_NAMES[BoneID.HAND_R])
	anim.track_insert_key(hand_r_track, 0.0, Quaternion.from_euler(Vector3(0, 0, 0)))
	anim.track_insert_key(hand_r_track, 0.1, Quaternion.from_euler(Vector3(0, 0.5, -0.3)))
	anim.track_insert_key(hand_r_track, 0.2, Quaternion.from_euler(Vector3(0, 0.8, -0.5)))
	anim.track_insert_key(hand_r_track, 0.3, Quaternion.from_euler(Vector3(0, 0, 0)))

	if animation_player.has_animation_library("gestures"):
		animation_player.get_animation_library("gestures").add_animation("Gesture_Flick", anim)

# ============================================================
# 动画播放接口
# ============================================================

## 切换姿态
func set_stance(stance_name: String) -> void:
	var anim_name := "stances/Stance_" + stance_name.capitalize()
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name, gesture_blend_time)
		_current_stance = stance_name
		stance_changed.emit(stance_name)

## 播放手势（叠加在当前姿态上）
func play_gesture(gesture_name: String) -> void:
	var anim_name := "gestures/Gesture_" + gesture_name
	if animation_player.has_animation(anim_name):
		_is_gesture_playing = true
		_current_gesture = gesture_name
		animation_player.play(anim_name, gesture_blend_time)
		animation_player.speed_scale = animation_speed_multiplier
		gesture_started.emit(gesture_name)

## 获取当前姿态
func get_current_stance() -> String:
	return _current_stance

## 手势是否正在播放
func is_gesture_playing() -> bool:
	return _is_gesture_playing

# ============================================================
# BPM 同步呼吸
# ============================================================

func _update_bpm_breathing(delta: float) -> void:
	if skeleton == null:
		return

	# BPM 同步的呼吸效果 - torso 上下微动
	var breath_offset := sin(_time * 2.0 * bpm_sync_multiplier) * 0.02 * motion_amplitude
	var torso_rest := skeleton.get_bone_rest(BoneID.TORSO)
	var torso_pose := Transform3D(torso_rest.basis, torso_rest.origin + Vector3(0, breath_offset, 0))

	# 叠加受击修改器
	if _modifier_impact_decay > 0.0:
		torso_pose.origin += _modifier_impact_offset * _modifier_impact_decay
	
	skeleton.set_bone_pose_position(BoneID.TORSO, torso_pose.origin)

	# 节拍脉冲衰减
	_beat_pulse = max(0.0, _beat_pulse - delta * 3.0)

# ============================================================
# 动态修改器
# ============================================================

func _update_modifiers(delta: float) -> void:
	# 受击偏移衰减
	if _modifier_impact_decay > 0.0:
		_modifier_impact_decay = max(0.0, _modifier_impact_decay - delta * 5.0)

	# 毛刺效果（洛克里亚式专用）
	if _modifier_glitch_intensity > 0.0:
		_apply_glitch_modifier()

## 应用受击修改器
func apply_impact(direction: Vector3 = Vector3.BACK) -> void:
	_modifier_impact_offset = direction * 0.1
	_modifier_impact_decay = 1.0

## 设置毛刺强度（洛克里亚式专用）
func set_glitch_intensity(intensity: float) -> void:
	_modifier_glitch_intensity = clamp(intensity, 0.0, 1.0)

## 应用毛刺修改器 - 随机偏移手臂和手部骨骼
func _apply_glitch_modifier() -> void:
	if skeleton == null:
		return

	# 以随机频率触发跳帧
	if randf() < _modifier_glitch_intensity * 0.3:
		var glitch_bones := [BoneID.HAND_L, BoneID.HAND_R, BoneID.ARM_L, BoneID.ARM_R]
		var target_bone: int = glitch_bones[randi() % glitch_bones.size()]
		var glitch_rotation := Vector3(
			randf_range(-0.1, 0.1) * _modifier_glitch_intensity,
			randf_range(-0.1, 0.1) * _modifier_glitch_intensity,
			randf_range(-0.1, 0.1) * _modifier_glitch_intensity
		)
		skeleton.set_bone_pose_rotation(target_bone,
			Quaternion.from_euler(glitch_rotation))

## 触发节拍脉冲
func trigger_beat_pulse() -> void:
	_beat_pulse = 1.0

# ============================================================
# 信号连接
# ============================================================

func _connect_signals() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("beat_tick"):
		gm.beat_tick.connect(_on_beat_tick)

func _on_beat_tick(_beat_index: int = 0) -> void:
	trigger_beat_pulse()

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name.begins_with("gestures/"):
		_is_gesture_playing = false
		gesture_finished.emit(_current_gesture)
		_current_gesture = ""
		# 回到当前姿态
		set_stance(_current_stance)
