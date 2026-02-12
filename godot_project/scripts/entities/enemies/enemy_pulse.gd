## enemy_pulse.gd
## Pulse (脉冲) — 错误的节拍
## 每隔固定小节（如 4 拍）进行一次冲刺或发射弹幕。
## 音乐隐喻：错误的节拍器，在不该出现的时间点爆发，打乱玩家的节奏感。
## 视觉：菱形/方波形状，有规律地膨胀-收缩（模拟脉冲波形）。
## 中等帧率量化，行为呈现明显的"蓄力-释放"周期。
extends "res://scripts/entities/enemy_base.gd"

## 相位变体类型
enum PhaseShiftType { NORMAL, HIGH_PASS, LOW_PASS }

# ============================================================
# Pulse 专属配置
# ============================================================
## 蓄力所需的节拍数
@export var charge_beats: int = 4
## 冲刺速度倍率
@export var burst_speed_multiplier: float = 4.0
## 相位变体类型
@export var phase_shift_type: PhaseShiftType = PhaseShiftType.NORMAL
## 冲刺持续时间
@export var burst_duration: float = 0.3
## 弹幕发射数量
@export var burst_projectile_count: int = 8
## 弹幕伤害
@export var burst_projectile_damage: float = 8.0
## 弹幕速度
@export var burst_projectile_speed: float = 250.0
## 弹幕存活时间
@export var burst_projectile_lifetime: float = 2.0
## 攻击模式：true = 冲刺，false = 弹幕（交替）
@export var alternate_attacks: bool = true

# ============================================================
# 内部状态
# ============================================================
var _beat_counter: int = 0
var _is_charging: bool = false
var _is_bursting: bool = false
var _burst_timer: float = 0.0
var _burst_direction: Vector2 = Vector2.ZERO
var _charge_visual_scale: float = 1.0
var _next_attack_is_dash: bool = true
var _shockwave_layer: CanvasLayer
var _shockwave_rect: ColorRect
var _high_pass_laser: Line2D

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.PULSE
	# Pulse 使用中等量化帧率
	quantized_fps = 10.0
	_quantize_interval = 1.0 / quantized_fps
	# 中等击退抗性
	knockback_resistance = 0.3
	# 不使用弱拍移动（有自己的节奏模式）
	move_on_offbeat = false
	# 电蓝色（脉冲/电子感）
	base_color = Color(0.2, 0.6, 1.0)
	# 中等故障基础值
	base_glitch_intensity = 0.1
	max_glitch_intensity = 0.8

	# 根据相位变体应用不同设置
	apply_phase_shift(phase_shift_type)

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	_update_burst(delta)
	_update_charge_visual(delta)

func _update_burst(delta: float) -> void:
	if _is_bursting:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_end_burst()

func _update_charge_visual(delta: float) -> void:
	if _sprite == null:
		return

	if _is_charging:
		# 蓄力时的脉冲膨胀效果
			var charge_progress := float(_beat_counter) / float(charge_beats)
			# 更新 LED Shader
			if _sprite.material and _sprite.material.has_param("countdown_progress"):
				_sprite.material.set("countdown_progress", charge_progress)
			_charge_visual_scale = 1.0 + charge_progress * 0.4
		# 蓄力时颜色逐渐变亮
		var charge_color := base_color.lerp(Color.WHITE, charge_progress * 0.5)
		_sprite.modulate = charge_color
		# 蓄力时的呼吸缩放
		var breath := sin(Time.get_ticks_msec() * 0.01 * (1.0 + charge_progress * 3.0))
		_sprite.scale = Vector2(_charge_visual_scale, _charge_visual_scale) * (1.0 + breath * 0.05)
	elif not _is_bursting:
		_charge_visual_scale = 1.0

# ============================================================
# 移动逻辑：蓄力时减速，爆发时冲刺
# ============================================================

func _calculate_movement_direction() -> Vector2:
	# 爆发冲刺中
	if _is_bursting and _next_attack_is_dash:
		velocity = _burst_direction * move_speed * burst_speed_multiplier
		move_and_slide()
		return Vector2.ZERO

	if _target == null:
		return Vector2.ZERO

	# 蓄力时减速
	var speed_mult := 1.0
	if _is_charging:
		var charge_progress := float(_beat_counter) / float(charge_beats)
		speed_mult = max(0.2, 1.0 - charge_progress * 0.8)

	var dir := (_target.global_position - global_position).normalized()
	velocity = dir * move_speed * speed_mult
	move_and_slide()
	return Vector2.ZERO

# ============================================================
# 节拍响应：蓄力-释放周期
# ============================================================

func _on_beat(_beat_index: int) -> void:
	if _is_bursting:
		return

	_beat_counter += 1
	_is_charging = true

	# 每次蓄力节拍的视觉脉冲
	if _sprite:
		var tween := create_tween()
		var target_scale := _charge_visual_scale * 1.15
		tween.tween_property(_sprite, "scale", Vector2(target_scale, target_scale), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(_charge_visual_scale, _charge_visual_scale), 0.1)

	# 达到蓄力节拍数时释放
	if _beat_counter >= charge_beats:
		_trigger_burst()

func _trigger_burst() -> void:
	_beat_counter = 0
	_is_charging = false
	if _sprite and _sprite.material and _sprite.material.has_param("countdown_progress"):
		_sprite.material.set("countdown_progress", 0.0)
	_is_bursting = true
	_burst_timer = burst_duration

	# OPT03: 爆发时触发攻击音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")

	if _target:
		_burst_direction = (_target.global_position - global_position).normalized()

	# 根据攻击模式选择行为
	if alternate_attacks:
		if _next_attack_is_dash:
			_execute_dash_burst()
		else:
			_execute_projectile_burst()
		_next_attack_is_dash = not _next_attack_is_dash
	else:
		_execute_projectile_burst()





func _end_burst() -> void:
	_is_bursting = false

	# 恢复视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.15)
		tween.tween_property(_sprite, "modulate", base_color, 0.2)

# ============================================================
# 敌人弹体生成
# ============================================================

func _spawn_enemy_projectile(direction: Vector2) -> void:
	# 创建简单的敌人弹体
	var projectile := Area2D.new()
	projectile.add_to_group("enemy_projectiles")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	col.shape = shape
	projectile.add_child(col)

	# 视觉：小型方块（脉冲波形碎片）
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
	])
	visual.color = Color(0.3, 0.7, 1.0, 0.8)
	projectile.add_child(visual)

	projectile.global_position = global_position
	get_parent().add_child(projectile)

	# 移动弹体
	var vel := direction * burst_projectile_speed
	var lifetime := burst_projectile_lifetime

	# 使用 Tween 移动（简化版，避免需要额外脚本）
	var tween := projectile.create_tween()
	tween.tween_property(
		projectile, "global_position",
		projectile.global_position + vel * lifetime,
		lifetime
	)
	tween.tween_callback(projectile.queue_free)

	# 碰撞检测（通过 area_entered 信号）
	projectile.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(burst_projectile_damage)
			projectile.queue_free()
	)

# ============================================================
# 死亡效果：脉冲消散
# ============================================================

func _execute_dash_burst() -> void:
	if phase_shift_type == PhaseShiftType.HIGH_PASS:
		_execute_laser_beam()
		return
		
	# 原冲刺爆发视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(0.5, 2.5), 0.05)
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.05)

func _execute_projectile_burst() -> void:
	if phase_shift_type == PhaseShiftType.LOW_PASS:
		_execute_shockwave_burst()
		return
		
	# 原发射环形弹幕
	for i in range(burst_projectile_count):
		var angle := (TAU / burst_projectile_count) * i
		var dir := Vector2.from_angle(angle)
		_spawn_enemy_projectile(dir)

	# 爆发视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(2.0, 2.0), 0.05)
		tween.tween_property(_sprite, "modulate", Color(0.5, 0.8, 1.0), 0.05)

# ============================================================
# 相位变体逻辑
# ============================================================

func apply_phase_shift(type: int) -> void:
	phase_shift_type = type
	match phase_shift_type:
		PhaseShiftType.NORMAL:
			# 普通模式，确保使用 LED Shader
			var shader_res = load("res://shaders/enemy_pulse_led.gdshader")
			if _sprite.material == null or _sprite.material.shader != shader_res:
				var mat = ShaderMaterial.new()
				mat.shader = shader_res
				_sprite.material = mat
			
		PhaseShiftType.HIGH_PASS: # 高通变体 (Overtone)
			# 冲刺攻击替换为激光
			alternate_attacks = true
			_next_attack_is_dash = true # 强制下次为“冲刺”（即激光）
			if not is_instance_valid(_high_pass_laser):
				_high_pass_laser = Line2D.new()
				_high_pass_laser.width = 12.0
				_high_pass_laser.default_color = Color(0.8, 0.9, 1.0, 0.9)
				# 注意：需要一个实际的 laser_segment.png 纹理文件，这里先假设它存在
				# _high_pass_laser.texture = load("res://assets/textures/effects/laser_segment.png")
				# _high_pass_laser.texture_mode = Line2D.LINE_TEXTURE_TILE
				_high_pass_laser.visible = false
				add_child(_high_pass_laser)
			
		PhaseShiftType.LOW_PASS: # 低通变体 (Sub-Bass)
			# 弹幕攻击替换为全屏冲击波
			alternate_attacks = true
			_next_attack_is_dash = false # 强制下次为“弹幕”（即冲击波）
			if not is_instance_valid(_shockwave_layer):
				_shockwave_layer = CanvasLayer.new()
				_shockwave_layer.layer = 1 # 在敌人上层
				_shockwave_rect = ColorRect.new()
				var mat = ShaderMaterial.new()
				mat.shader = load("res://shaders/pulse_shockwave.gdshader")
				_shockwave_rect.material = mat
				_shockwave_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				_shockwave_layer.add_child(_shockwave_rect)
				_shockwave_layer.visible = false
				get_tree().current_scene.add_child(_shockwave_layer)

func _execute_laser_beam() -> void:
	if not _target or not is_instance_valid(_high_pass_laser): return
	_high_pass_laser.clear_points()
	_high_pass_laser.add_point(to_local(global_position))
	var target_local_pos = to_local(_target.global_position)
	_high_pass_laser.add_point(target_local_pos.normalized() * 2000.0) # 激光画很长，穿过目标
	_high_pass_laser.visible = true

	var tween := create_tween()
	tween.tween_property(_high_pass_laser, "width", 20.0, 0.1).from(0.0)
	tween.tween_property(_high_pass_laser, "modulate:a", 0.0, 0.3).from(1.0).set_delay(0.2)
	tween.tween_callback(func(): _high_pass_laser.visible = false)

	# 简单的射线检测造成伤害
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, _target.global_position + _burst_direction * 1000)
	query.collide_with_areas = true
	var result = space_state.intersect_ray(query)
	if result and result.collider.is_in_group("player"):
		result.collider.take_damage(damage * 1.5)

func _execute_shockwave_burst() -> void:
	if not is_instance_valid(_shockwave_layer): return
	_shockwave_layer.visible = true
	var mat: ShaderMaterial = _shockwave_rect.material
	var screen_center = get_viewport().get_visible_rect().size / 2.0
	mat.set_shader_parameter("center", get_global_mouse_position() / get_viewport().get_visible_rect().size)

	var tween := create_tween().set_parallel()
	tween.tween_property(mat, "shader_parameter/progress", 1.0, 0.8).from(0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "shader_parameter/pixel_size", 1.0, 0.8).from(32.0)
	tween.tween_callback(func(): _shockwave_layer.visible = false)

	# 全屏伤害
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("take_damage"):
		player.take_damage(damage * 0.8)

func _on_death_effect() -> void:
	# Pulse 死亡时释放最后一波弱弹幕
	if current_hp <= 0.0:
		var weak_count := burst_projectile_count / 2
		for i in range(weak_count):
			var angle := (TAU / weak_count) * i + randf() * 0.3
			var dir := Vector2.from_angle(angle)
			_spawn_enemy_projectile(dir)
