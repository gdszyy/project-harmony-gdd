## hit_visual_feedback.gd
## 受击视觉反馈管理器
##
## 职责：
## 1. 管理全局的受击视觉反馈（屏幕震动、闪光）
## 2. 实现伤害数字的弹出效果
## 3. 处理暴击和特殊命中的增强视觉
class_name HitVisualFeedback
extends Node

# ============================================================
# 配置
# ============================================================

## 屏幕震动配置
@export var shake_enabled: bool = true
@export var shake_intensity: float = 3.0
@export var shake_duration: float = 0.15
@export var crit_shake_multiplier: float = 2.5

## 命中暂停（Hitstop）配置
@export var hitstop_enabled: bool = true
@export var hitstop_duration: float = 0.05
@export var crit_hitstop_duration: float = 0.1

# ============================================================
# 状态
# ============================================================
var _shake_timer: float = 0.0
var _shake_strength: float = 0.0
var _camera_ref: Camera2D = null
var _original_offset: Vector2 = Vector2.ZERO

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_connect_signals()

func _process(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		if _camera_ref:
			var shake_amount := _shake_strength * (_shake_timer / shake_duration)
			_camera_ref.offset = _original_offset + Vector2(
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount, shake_amount)
			)
		if _shake_timer <= 0.0 and _camera_ref:
			_camera_ref.offset = _original_offset

func _connect_signals() -> void:
	# 连接受击反馈管理器信号
	var hfm = get_node_or_null("/root/HitFeedbackManager")
	if hfm:
		if hfm.has_signal("hit_confirmed"):
			hfm.hit_confirmed.connect(_on_hit_confirmed)
		if hfm.has_signal("critical_hit"):
			hfm.critical_hit.connect(_on_critical_hit)

# ============================================================
# 受击反馈
# ============================================================

func _on_hit_confirmed(hit_data: Dictionary) -> void:
	if shake_enabled:
		_trigger_shake(shake_intensity, shake_duration)
	if hitstop_enabled:
		_trigger_hitstop(hitstop_duration)

func _on_critical_hit(hit_data: Dictionary) -> void:
	if shake_enabled:
		_trigger_shake(shake_intensity * crit_shake_multiplier, shake_duration * 1.5)
	if hitstop_enabled:
		_trigger_hitstop(crit_hitstop_duration)

func _trigger_shake(intensity: float, duration: float) -> void:
	_shake_strength = intensity
	_shake_timer = duration
	
	if _camera_ref == null:
		# 尝试查找相机
		_camera_ref = get_viewport().get_camera_2d()
		if _camera_ref:
			_original_offset = _camera_ref.offset

func _trigger_hitstop(duration: float) -> void:
	# 短暂暂停游戏引擎
	get_tree().paused = true
	get_tree().create_timer(duration, true, false, true).timeout.connect(func():
		get_tree().paused = false
	)

# ============================================================
# 公共接口
# ============================================================

## 手动触发屏幕震动
func shake(intensity: float = -1.0, duration: float = -1.0) -> void:
	var i := intensity if intensity > 0 else shake_intensity
	var d := duration if duration > 0 else shake_duration
	_trigger_shake(i, d)

## 设置相机引用
func set_camera(camera: Camera2D) -> void:
	_camera_ref = camera
	_original_offset = camera.offset
