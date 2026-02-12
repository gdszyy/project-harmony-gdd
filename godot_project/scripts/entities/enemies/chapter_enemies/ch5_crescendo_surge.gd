## ch5_crescendo_surge.gd
## 第五章特色敌人：渐强潮涌 (Crescendo Surge)
## 随存活时间不断增强的敌人，体现贝多芬的力度变化革命。
## 音乐隐喻：贝多芬标志性的 pp → ff 渐强。
## 机制：
## - 初始很弱（pp），随时间逐渐增强到极强（ff）
## - 体积、速度、伤害、弹幕密度都随时间增长
## - 达到 ff 后释放一次大爆发然后重置为 pp
## - 需要在达到 ff 之前击杀
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Crescendo Surge 专属配置
# ============================================================
## 从 pp 到 ff 的时间（秒）
@export var crescendo_duration: float = 8.0
## pp 时的速度倍率
@export var pp_speed_mult: float = 0.5
## ff 时的速度倍率
@export var ff_speed_mult: float = 2.5
## pp 时的伤害倍率
@export var pp_damage_mult: float = 0.3
## ff 时的伤害倍率
@export var ff_damage_mult: float = 3.0
## ff 爆发伤害
@export var ff_burst_damage: float = 30.0
## ff 爆发范围
@export var ff_burst_radius: float = 150.0
## 弹幕速度
@export var projectile_speed: float = 150.0

# ============================================================
# 内部状态
# ============================================================
## 渐强进度 (0.0 = pp, 1.0 = ff)
var _crescendo_progress: float = 0.0
var _base_move_speed: float = 0.0
var _base_contact_damage: float = 0.0
## 弹幕计时
var _projectile_timer: float = 0.0
## 已爆发次数
var _burst_count: int = 0

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.PULSE
	quantized_fps = 10.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.1
	move_on_offbeat = false
	
	# 初始淡蓝色（pp），逐渐变为深红（ff）
	base_color = Color(0.5, 0.6, 0.8)
	base_glitch_intensity = 0.03
	max_glitch_intensity = 0.8
	
	_base_move_speed = move_speed
	_base_contact_damage = contact_damage
	
	# 初始弱化
	move_speed = _base_move_speed * pp_speed_mult
	contact_damage = _base_contact_damage * pp_damage_mult

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 渐强进度
	_crescendo_progress += delta / crescendo_duration
	
	if _crescendo_progress >= 1.0:
		# 达到 ff：爆发
		_ff_burst()
		return
	
	# 根据进度更新属性
	var t := _crescendo_progress
	
	# 速度渐强
	move_speed = _base_move_speed * lerp(pp_speed_mult, ff_speed_mult, t)
	
	# 伤害渐强
	contact_damage = _base_contact_damage * lerp(pp_damage_mult, ff_damage_mult, t)
	
	# 击退抗性渐强
	knockback_resistance = lerp(0.1, 0.7, t)
	
	# 颜色渐变：蓝 → 红
	var current_color := Color(
		lerp(0.5, 1.0, t),
		lerp(0.6, 0.2, t),
		lerp(0.8, 0.1, t)
	)
	base_color = current_color
	
	# 体积渐大
	if _sprite:
		var scale_mult = lerp(0.7, 1.5, t)
		_sprite.scale = Vector2(scale_mult, scale_mult)
		_sprite.modulate = current_color
		
		# 渐强脉冲（越强越快）
		var pulse_speed = lerp(2.0, 8.0, t)
		var pulse = sin(Time.get_ticks_msec() * 0.001 * pulse_speed) * lerp(0.02, 0.1, t)
		_sprite.scale += Vector2(pulse, pulse)
	
	# 弹幕频率渐增
	var fire_interval = lerp(3.0, 0.5, t)
	_projectile_timer += delta
	if _projectile_timer >= fire_interval:
		_projectile_timer = 0.0
		_fire_crescendo_projectile()

# ============================================================
# 弹幕攻击
# ============================================================

func _fire_crescendo_projectile() -> void:
	if _target == null:
		return
	
	# OPT03: 攻击时触发音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")
	var count := int(lerp(1.0, 5.0, _crescendo_progress))
	var base_angle := (global_position.direction_to(_target.global_position)).angle()
	var spread = lerp(0.1, 0.6, _crescendo_progress)
	
	for i in range(count):
		var t := float(i) / float(max(1, count - 1))
		var angle = base_angle - spread / 2.0 + spread * t
		if count == 1:
			angle = base_angle
		
		var proj := Area2D.new()
		proj.add_to_group("enemy_projectiles")
		
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = lerp(3.0, 6.0, _crescendo_progress)
		col.shape = shape
		proj.add_child(col)
		
		var visual := Polygon2D.new()
		var points := PackedVector2Array()
		for p in range(6):
			var a := (TAU / 6) * p
			points.append(Vector2.from_angle(a) * shape.radius)
		visual.polygon = points
		visual.color = base_color.lerp(Color.WHITE, 0.3)
		proj.add_child(visual)
		
		proj.global_position = global_position
		get_parent().add_child(proj)
		
		var vel = Vector2.from_angle(angle) * projectile_speed * lerp(0.6, 1.5, _crescendo_progress)
		var tween := proj.create_tween()
		tween.tween_property(proj, "global_position",
			proj.global_position + vel * 3.0, 3.0)
		tween.tween_callback(proj.queue_free)
		
		proj.body_entered.connect(func(body: Node2D):
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(contact_damage * 0.5)
				proj.queue_free()
		)

# ============================================================
# ff 爆发
# ============================================================

func _ff_burst() -> void:
	# OPT03: 攻击时触发音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")
	_burst_count += 1
	
	# 大范围冲击波
	var wave := Node2D.new()
	wave.global_position = global_position
	get_parent().add_child(wave)
	
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(32):
		var angle := (TAU / 32) * i
		points.append(Vector2.from_angle(angle) * 5.0)
	ring.polygon = points
	ring.color = Color(1.0, 0.2, 0.0, 0.8)
	wave.add_child(ring)
	
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", Vector2(ff_burst_radius / 5.0, ff_burst_radius / 5.0), 0.4)
	tween.parallel().tween_property(ring, "color:a", 0.0, 0.4)
	tween.tween_callback(wave.queue_free)
	
	# 伤害
	if _target and is_instance_valid(_target):
		if global_position.distance_to(_target.global_position) < ff_burst_radius:
			if _target.has_method("take_damage"):
				_target.take_damage(ff_burst_damage)
	
	# 全方位弹幕
	for i in range(16):
		var angle := (TAU / 16) * i
		var proj := Area2D.new()
		proj.add_to_group("enemy_projectiles")
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 5.0
		col.shape = shape
		proj.add_child(col)
		var visual := Polygon2D.new()
		var pts := PackedVector2Array()
		for p in range(6):
			var a := (TAU / 6) * p
			pts.append(Vector2.from_angle(a) * 5.0)
		visual.polygon = pts
		visual.color = Color(1.0, 0.3, 0.1, 0.9)
		proj.add_child(visual)
		proj.global_position = global_position
		get_parent().add_child(proj)
		var vel := Vector2.from_angle(angle) * projectile_speed * 1.5
		var proj_tween := proj.create_tween()
		proj_tween.tween_property(proj, "global_position",
			proj.global_position + vel * 3.0, 3.0)
		proj_tween.tween_callback(proj.queue_free)
	
	# 重置为 pp
	_crescendo_progress = 0.0
	_projectile_timer = 0.0
	move_speed = _base_move_speed * pp_speed_mult
	contact_damage = _base_contact_damage * pp_damage_mult
	
	if _sprite:
		_sprite.scale = Vector2(0.7, 0.7)
		_sprite.modulate = Color(0.5, 0.6, 0.8)

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	return (_target.global_position - global_position).normalized()

func _on_beat(_beat_index: int) -> void:
	if _sprite:
		var intensity = lerp(0.05, 0.2, _crescendo_progress)
		var tween := create_tween()
		tween.tween_property(_sprite, "scale",
			_sprite.scale + Vector2(intensity, intensity), 0.05)
		tween.tween_property(_sprite, "scale",
			_sprite.scale, 0.1)

func _on_death_effect() -> void:
	# 死亡时根据渐强进度释放对应强度的爆发
	if _crescendo_progress > 0.3:
		var radius := ff_burst_radius * _crescendo_progress
		var damage := ff_burst_damage * _crescendo_progress * 0.5
		
		if _target and is_instance_valid(_target):
			if global_position.distance_to(_target.global_position) < radius:
				if _target.has_method("take_damage"):
					_target.take_damage(damage)
