## ch1_metronome_pulse.gd
## 第一章特色敌人：节拍器脉冲 (Metronome Pulse)
## 基于 Pulse 的变体，攻击严格遵循四分音符节拍。
## 音乐隐喻：精确的节拍器，是玩家学习"节奏同步"战斗的第一个动态教具。
## 视觉：菱形，带有稳定的"摆锤"动画，金色/琥珀色调。
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Metronome Pulse 专属配置
# ============================================================
## 每几拍发射一次弹幕（严格遵循四分音符）
@export var attack_every_n_beats: int = 4
## 弹幕数量
@export var projectile_count: int = 4
## 弹幕速度
@export var projectile_speed: float = 220.0
## 弹幕伤害
@export var projectile_damage: float = 10.0
## 弹幕存活时间
@export var projectile_lifetime: float = 2.5
## 冲刺速度倍率（每 8 拍冲刺一次）
@export var dash_speed_multiplier: float = 3.5
## 冲刺持续时间
@export var dash_duration: float = 0.25
## 冲刺间隔（节拍数）
@export var dash_every_n_beats: int = 8
## 摆锤摆动幅度（视觉）
@export var pendulum_amplitude: float = 15.0

# ============================================================
# 内部状态
# ============================================================
var _beat_counter: int = 0
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
## 蓄力视觉
var _charge_progress: float = 0.0
## 摆锤相位
var _pendulum_phase: float = 0.0
## 攻击预警闪烁
var _pre_attack_flash: bool = false

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.PULSE
	# 中等量化帧率
	quantized_fps = 10.0
	_quantize_interval = 1.0 / quantized_fps
	# 中等击退抗性
	knockback_resistance = 0.3
	# 不使用弱拍移动（有自己的严格节拍模式）
	move_on_offbeat = false
	# 金色/琥珀色调（节拍器的温暖金属感）
	base_color = Color(0.9, 0.7, 0.2)
	# 中等故障
	base_glitch_intensity = 0.08
	max_glitch_intensity = 0.7

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 冲刺更新
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_end_dash()
	
	# 蓄力进度
	_charge_progress = float(_beat_counter % attack_every_n_beats) / float(attack_every_n_beats)
	
	# 摆锤视觉
	_pendulum_phase += delta * (2.0 + _charge_progress * 4.0)
	if _sprite:
		var pendulum_offset := sin(_pendulum_phase) * pendulum_amplitude * (0.3 + _charge_progress * 0.7)
		_sprite.rotation = deg_to_rad(pendulum_offset)
		
		# 蓄力时颜色变亮
		var charge_color := base_color.lerp(Color.WHITE, _charge_progress * 0.4)
		if not _pre_attack_flash:
			_sprite.modulate = charge_color
		
		# 蓄力时缩放
		var charge_scale := 1.0 + _charge_progress * 0.25
		_sprite.scale = Vector2(charge_scale, charge_scale)
	
	# 预警闪烁（攻击前 1 拍）
	if _beat_counter % attack_every_n_beats == attack_every_n_beats - 1:
		_pre_attack_flash = true
		if _sprite:
			var flash := sin(Time.get_ticks_msec() * 0.02) > 0.0
			_sprite.modulate = Color.WHITE if flash else base_color
	else:
		_pre_attack_flash = false

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _is_dashing:
		velocity = _dash_direction * move_speed * dash_speed_multiplier
		move_and_slide()
		return Vector2.ZERO
	
	if _target == null:
		return Vector2.ZERO
	
	# 蓄力时减速
	var speed_mult := max(0.3, 1.0 - _charge_progress * 0.7)
	var dir := (_target.global_position - global_position).normalized()
	velocity = dir * move_speed * speed_mult
	move_and_slide()
	return Vector2.ZERO

# ============================================================
# 节拍响应：严格的四分音符攻击
# ============================================================

func _on_beat(_beat_index: int) -> void:
	if _is_dashing:
		return
	
	_beat_counter += 1
	
	# 摆锤节拍脉冲
	if _sprite:
		var tween := create_tween()
		var pulse_scale := 1.0 + _charge_progress * 0.25
		tween.tween_property(_sprite, "scale", Vector2(pulse_scale * 1.1, pulse_scale * 1.1), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(pulse_scale, pulse_scale), 0.1)
	
	# 每 N 拍发射弹幕（严格四分音符）
	if _beat_counter % attack_every_n_beats == 0:
		_fire_metronome_burst()
	
	# 每 M 拍冲刺
	if _beat_counter % dash_every_n_beats == 0:
		_start_dash()

# ============================================================
# 弹幕发射：精确的定向弹幕
# ============================================================

func _fire_metronome_burst() -> void:
	if _target == null:
		return
	
	# 向玩家方向发射扇形弹幕
	var base_angle := (global_position.direction_to(_target.global_position)).angle()
	var spread := PI / 6.0  # 30度扇形
	
	for i in range(projectile_count):
		var t := float(i) / float(max(1, projectile_count - 1))
		var angle := base_angle - spread / 2.0 + spread * t
		if projectile_count == 1:
			angle = base_angle
		_spawn_metronome_projectile(angle)
	
	# 发射视觉反馈
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.5, 1.5), 0.05)
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.15)
		tween.tween_property(_sprite, "modulate", base_color, 0.2)

func _spawn_metronome_projectile(angle: float) -> void:
	var projectile := Area2D.new()
	projectile.add_to_group("enemy_projectiles")
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	projectile.add_child(col)
	
	# 视觉：菱形弹体（节拍器风格）
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)
	])
	visual.color = Color(1.0, 0.85, 0.3, 0.9)
	visual.rotation = angle
	projectile.add_child(visual)
	
	projectile.global_position = global_position
	get_parent().add_child(projectile)
	
	# 移动
	var vel := Vector2.from_angle(angle) * projectile_speed
	var tween := projectile.create_tween()
	tween.tween_property(
		projectile, "global_position",
		projectile.global_position + vel * projectile_lifetime,
		projectile_lifetime
	)
	tween.tween_callback(projectile.queue_free)
	
	# 碰撞检测
	projectile.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(projectile_damage)
			projectile.queue_free()
	)

# ============================================================
# 冲刺
# ============================================================

func _start_dash() -> void:
	if _target == null:
		return
	_is_dashing = true
	_dash_timer = dash_duration
	_dash_direction = (_target.global_position - global_position).normalized()
	
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(0.6, 2.0), 0.05)

func _end_dash() -> void:
	_is_dashing = false
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.15)
		tween.tween_property(_sprite, "modulate", base_color, 0.2)

# ============================================================
# 死亡效果：最后一次节拍脉冲
# ============================================================

func _on_death_effect() -> void:
	# 死亡时释放一圈弱弹幕（最后的节拍）
	for i in range(projectile_count):
		var angle := (TAU / projectile_count) * i
		_spawn_metronome_projectile(angle)
