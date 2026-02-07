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

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.SCREECH
	# Screech 使用高量化帧率（快速抽搐）
	quantized_fps = 20.0
	_quantize_interval = 1.0 / quantized_fps
	# 低击退抗性（轻量级）
	knockback_resistance = 0.0
	# 弱拍移动（但冲刺时无视节拍限制）
	move_on_offbeat = true
	# 刺眼的黄白色
	base_color = Color(1.0, 0.9, 0.2)
	# 高基础故障（本身就是不稳定的信号）
	base_glitch_intensity = 0.25
	max_glitch_intensity = 1.0
	glitch_flicker_speed = screech_flicker_speed

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	_update_dash(delta)

func _update_dash(delta: float) -> void:
	# 冷却计时
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta

	# 冲刺中
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_end_dash()
		return

	# 检查是否应该冲刺
	if _target and _dash_cooldown_timer <= 0.0:
		var dist := global_position.distance_to(_target.global_position)
		if dist < dash_trigger_distance and dist > 40.0:
			_start_dash()

func _start_dash() -> void:
	if _target == null:
		return

	_is_dashing = true
	_dash_timer = dash_duration
	_pre_dash_speed = move_speed
	_dash_direction = (_target.global_position - global_position).normalized()

	# 冲刺视觉：拉伸 + 颜色变亮
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(0.5, 2.0), 0.05)

func _end_dash() -> void:
	_is_dashing = false
	_dash_cooldown_timer = dash_cooldown

	# 恢复视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

# ============================================================
# 移动逻辑：快速追踪 + 冲刺
# ============================================================

func _calculate_movement_direction() -> Vector2:
	# 冲刺中：沿冲刺方向高速移动
	if _is_dashing:
		velocity = _dash_direction * move_speed * dash_speed_multiplier
		move_and_slide()
		return Vector2.ZERO

	if _target == null:
		return Vector2.ZERO

	# 正常移动：直线追踪，略带随机抖动
	var dir := (_target.global_position - global_position).normalized()
	var jitter := Vector2(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
	return (dir + jitter).normalized()

# ============================================================
# 节拍响应：在强拍时发出"尖叫"脉冲
# ============================================================

func _on_beat(_beat_index: int) -> void:
	# 强拍时视觉闪烁加剧
	if _sprite:
		_sprite.modulate = Color.WHITE
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", base_color, 0.15)

	# 每 4 拍（每小节）尝试一次冲刺
	if _beat_index % 4 == 0 and _dash_cooldown_timer <= 0.0:
		if _target:
			var dist := global_position.distance_to(_target.global_position)
			if dist < dash_trigger_distance * 1.5:
				_start_dash()

# ============================================================
# 死亡效果：不和谐爆发 — 刺耳的反馈音波
# ============================================================

func _on_death_effect() -> void:
	# 对爆发范围内的玩家造成伤害和不和谐度增加
	if _target and is_instance_valid(_target):
		var dist := global_position.distance_to(_target.global_position)
		if dist < death_burst_radius:
			# 距离衰减
			var falloff := 1.0 - (dist / death_burst_radius)
			var actual_damage := death_burst_damage * falloff

			if _target.has_method("take_damage"):
				_target.take_damage(actual_damage)

			# 增加不和谐度/疲劳
			if FatigueManager and FatigueManager.has_method("add_external_fatigue"):
				FatigueManager.add_external_fatigue(death_burst_dissonance * falloff)

	# 生成不和谐区域（短暂存在的伤害场）
	_spawn_dissonance_field()

func _spawn_dissonance_field() -> void:
	# 创建一个短暂的视觉+伤害区域
	var field := Area2D.new()
	field.add_to_group("dissonance_field")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = death_burst_radius
	col.shape = shape
	field.add_child(col)

	# 视觉：扩散的红色环
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

	# 扩散动画 + 淡出
	var tween := field.create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2(3.0, 3.0), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "modulate:a", 0.0, 0.5)
	tween.chain()
	tween.tween_callback(field.queue_free)
