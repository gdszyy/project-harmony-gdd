## enemy_screech.gd
## Screech (尖啸) — 反馈音 (Feedback)
## 快速接近，死亡时爆发出小范围的"不和谐"区域，造成伤害。
## 音乐隐喻：刺耳的麦克风反馈音，短暂但极具破坏力。
## 视觉：尖锐的三角碎片，高频闪烁，颜色偏向刺眼的黄/白。
## 高帧率量化（快速抽搐感），极快速度。
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Screech 专属配置
# ============================================================
## 冲刺速度倍率
@export var dash_speed_multiplier: float = 3.0
## 冲刺持续时间
@export var dash_duration: float = 0.2
## 冲刺冷却时间
@export var dash_cooldown: float = 2.0
## 冲刺触发距离（靠近玩家时冲刺）
@export var dash_trigger_distance: float = 200.0

## 死亡爆发半径
@export var death_burst_radius: float = 80.0
## 死亡爆发伤害
@export var death_burst_damage: float = 15.0
## 死亡爆发不和谐度增加
@export var death_burst_dissonance: float = 0.12

## 视觉闪烁速度（比基类更快）
@export var screech_flicker_speed: float = 0.08

# ============================================================
# 内部状态
# ============================================================
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _pre_dash_speed: float = 0.0

## 相位变体 (0=normal, 1=high_pass, 2=low_pass)
enum PhaseShiftType { NORMAL, HIGH_PASS, LOW_PASS }
var phase_shift_type: PhaseShiftType = PhaseShiftType.NORMAL

## 蓄力进度，用于 shader
var _charge_progress: float = 0.0

## 缓存原始多边形数据
var _original_polygon: PackedVector2Array

## 缓存 shader 资源
var _screech_glitch_shader: Shader = preload("res://shaders/enemy_screech_glitch.gdshader")
var _oscilloscope_shader: Shader = preload("res://shaders/screech_oscilloscope.gdshader")

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.SCREECH
	quantized_fps = 20.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.0
	move_on_offbeat = true
	base_color = Color(1.0, 0.9, 0.2)
	base_glitch_intensity = 0.25
	max_glitch_intensity = 1.0
	glitch_flicker_speed = screech_flicker_speed

	if _sprite and _sprite is Polygon2D:
		_original_polygon = (_sprite as Polygon2D).polygon

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	_update_dash(delta)

	# 更新 shader 的蓄力参数
	if _charge_progress > 0.0:
		_charge_progress = max(0.0, _charge_progress - delta * 2.0)
		_set_shader_param("charge_progress", _charge_progress)

func _update_dash(delta: float) -> void:
	if phase_shift_type == PhaseShiftType.LOW_PASS:
		return # 低通模式下不移动

	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta

	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_end_dash()
		return

	if _target and _dash_cooldown_timer <= 0.0:
		var dist := global_position.distance_to(_target.global_position)
		if dist < dash_trigger_distance and dist > 40.0:
			_start_dash()

func _start_dash() -> void:
	if _target == null or phase_shift_type == PhaseShiftType.LOW_PASS:
		return

	_is_dashing = true
	_dash_timer = dash_duration
	_pre_dash_speed = move_speed
	_dash_direction = (_target.global_position - global_position).normalized()

	# 设置蓄力 shader 参数
	_charge_progress = 1.0
	_set_shader_param("charge_progress", _charge_progress)

	# 高通模式：留下残影
	if phase_shift_type == PhaseShiftType.HIGH_PASS:
		_create_afterimage()

	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(0.5, 2.0), 0.05)

func _end_dash() -> void:
	_is_dashing = false
	_dash_cooldown_timer = dash_cooldown

	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if phase_shift_type == PhaseShiftType.LOW_PASS:
		velocity = Vector2.ZERO
		return Vector2.ZERO

	if _is_dashing:
		velocity = _dash_direction * move_speed * dash_speed_multiplier
		move_and_slide()
		return Vector2.ZERO

	if _target == null:
		return Vector2.ZERO

	var dir := (_target.global_position - global_position).normalized()
	var jitter := Vector2(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
	return (dir + jitter).normalized()

# ============================================================
# 相位变体逻辑
# ============================================================

## 应用相位变体
func apply_phase_shift(type: int) -> void:
	phase_shift_type = type

	match phase_shift_type:
		PhaseShiftType.NORMAL:
			_to_normal_phase()
		PhaseShiftType.HIGH_PASS:
			_to_high_pass_phase()
		PhaseShiftType.LOW_PASS:
			_to_low_pass_phase()

func _to_normal_phase() -> void:
	# 恢复正常移动和视觉
	move_speed = _stats.move_speed
	if _sprite and _sprite is Polygon2D:
		var poly = _sprite as Polygon2D
		poly.polygon = _original_polygon
		(poly.material as ShaderMaterial).shader = _screech_glitch_shader

func _to_high_pass_phase() -> void:
	# 视觉不变，行为可能在其他地方调整（例如冲刺留下残影）
	pass

func _to_low_pass_phase() -> void:
	# 变为静止球体，切换 shader
	move_speed = 0
	if _sprite and _sprite is Polygon2D:
		var poly = _sprite as Polygon2D
		poly.polygon = _create_circle_polygon(30, 32) # 创建一个圆形多边形
		(poly.material as ShaderMaterial).shader = _oscilloscope_shader

## 创建圆形多边形数据
func _create_circle_polygon(radius: float, num_segments: int) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(num_segments):
		var angle = (TAU / num_segments) * i
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

## 创建高通模式下的残影
func _create_afterimage() -> void:
	if not (_sprite is Polygon2D):
		return

	var afterimage = Polygon2D.new()
	afterimage.polygon = (_sprite as Polygon2D).polygon
	afterimage.color = Color(1.0, 0.9, 0.2, 0.4)
	afterimage.material = _sprite.material
	afterimage.global_position = global_position
	afterimage.rotation = rotation
	afterimage.scale = scale
	get_parent().add_child(afterimage)

	var tween = create_tween()
	tween.tween_property(afterimage, "modulate:a", 0.0, 0.5).set_delay(0.1)
	tween.tween_callback(afterimage.queue_free)

# ============================================================
# 节拍响应
# ============================================================

func _on_beat(_beat_index: int) -> void:
	if phase_shift_type == PhaseShiftType.LOW_PASS:
		return

	if _sprite:
		_sprite.modulate = Color.WHITE
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", base_color, 0.15)

	if _beat_index % 4 == 0 and _dash_cooldown_timer <= 0.0:
		if _target:
			var dist := global_position.distance_to(_target.global_position)
			if dist < dash_trigger_distance * 1.5:
				_start_dash()

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	if _target and is_instance_valid(_target):
		var dist := global_position.distance_to(_target.global_position)
		if dist < death_burst_radius:
			var falloff := 1.0 - (dist / death_burst_radius)
			var actual_damage := death_burst_damage * falloff

			if _target.has_method("take_damage"):
				_target.take_damage(actual_damage)

			if FatigueManager and FatigueManager.has_method("add_external_fatigue"):
				FatigueManager.add_external_fatigue(death_burst_dissonance * falloff)

	_spawn_dissonance_field()

func _spawn_dissonance_field() -> void:
	var field := Area2D.new()
	field.add_to_group("dissonance_field")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = death_burst_radius
	col.shape = shape
	field.add_child(col)

	var visual := Polygon2D.new()
	var points := PackedVector2Array()
	var segments := 16
	for i in range(segments):
		var angle := (TAU / segments) * i
		points.append(Vector2.from_angle(angle) * death_burst_radius * 0.3)
	visual.polygon = points
	visual.color = Color(1.0, 0.2, 0.0, 0.5)
	field.add_child(visual)

	field.global_position = global_position
	get_parent().add_child(field)

	var tween := field.create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2(3.0, 3.0), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "modulate:a", 0.0, 0.5)
	tween.chain()
	tween.tween_callback(field.queue_free)
