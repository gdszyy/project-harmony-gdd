## ch5_symphony_commander.gd
## 第五章精英/小Boss：交响指挥 (Symphony Commander)
## 贝多芬时代的管弦乐指挥，能够指挥不同"乐器组"发动协调攻击。
## 音乐隐喻：贝多芬扩展管弦乐编制的革命性创新。
## 机制：
## - 四种乐器组攻击模式（弦乐、管乐、打击乐、铜管）
## - 力度标记系统：攻击强度动态变化（pp→ff）
## - 指挥光环增强范围内敌人
## - 狂暴时进入"英雄交响曲"模式
extends "res://scripts/entities/enemies/elite_base.gd"

# ============================================================
# Symphony Commander 专属配置
# ============================================================
## 弦乐组：连续快速弹幕
@export var string_damage: float = 8.0
@export var string_speed: float = 200.0
## 管乐组：持续性光束
@export var wind_damage: float = 15.0
## 打击乐组：冲击波
@export var percussion_damage: float = 20.0
@export var percussion_radius: float = 100.0
## 铜管组：高伤害定向冲击
@export var brass_damage: float = 25.0
## 指挥光环半径
@export var command_radius: float = 180.0
## 力度标记
var _dynamic_level: float = 0.0  # 0=pp, 1=ff

# ============================================================
# 内部状态
# ============================================================
var _instrument_phase: int = 0  # 0=弦乐 1=管乐 2=打击 3=铜管
var _dynamic_timer: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _on_elite_ready() -> void:
	elite_name = "交响指挥"
	elite_title = "Symphony Commander"
	
	max_hp = 550.0
	current_hp = 550.0
	move_speed = 40.0
	contact_damage = 14.0
	xp_value = 45
	
	base_color = Color(0.7, 0.2, 0.2)
	aura_radius = command_radius
	aura_color = Color(0.7, 0.2, 0.2, 0.1)
	
	quantized_fps = 8.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.6
	
	_elite_shield = 90.0
	_elite_max_shield = 90.0

func _define_elite_attacks() -> void:
	_elite_attacks = [
		{
			"name": "string_section",
			"duration": 2.5,
			"cooldown": 3.0,
			"damage": string_damage,
			"weight": 3.0,
		},
		{
			"name": "wind_section",
			"duration": 2.0,
			"cooldown": 4.0,
			"damage": wind_damage,
			"weight": 2.0,
		},
		{
			"name": "percussion_section",
			"duration": 1.5,
			"cooldown": 4.0,
			"damage": percussion_damage,
			"weight": 2.5,
		},
		{
			"name": "brass_section",
			"duration": 1.5,
			"cooldown": 5.0,
			"damage": brass_damage,
			"weight": 2.0,
		},
		{
			"name": "tutti",
			"duration": 4.0,
			"cooldown": 8.0,
			"damage": 20.0,
			"weight": 1.5,
		},
	]

# ============================================================
# 精英每帧逻辑
# ============================================================

func _on_elite_process(delta: float) -> void:
	# 力度渐强
	_dynamic_timer += delta
	_dynamic_level = clamp(_dynamic_timer / 10.0, 0.0, 1.0)
	
	# 指挥视觉
	if _sprite:
		var sway := sin(Time.get_ticks_msec() * 0.002) * 0.1
		_sprite.rotation = sway
		
		# 力度颜色
		var intensity_color := base_color.lerp(Color(1.0, 0.3, 0.1), _dynamic_level * 0.5)
		_sprite.modulate = intensity_color
	
	# 指挥光环效果
	_apply_command_aura()

func _apply_command_aura() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < command_radius:
			if enemy.has_method("set"):
				var base_speed: float = enemy.get("move_speed")
				if base_speed > 0:
					enemy.set("move_speed", base_speed * (1.0 + _dynamic_level * 0.1))

# ============================================================
# 攻击实现
# ============================================================

func _perform_elite_attack(attack: Dictionary) -> void:
	var dynamic_mult := 1.0 + _dynamic_level * 0.8
	
	match attack["name"]:
		"string_section":
			_attack_string_section(attack, dynamic_mult)
		"wind_section":
			_attack_wind_section(attack, dynamic_mult)
		"percussion_section":
			_attack_percussion_section(attack, dynamic_mult)
		"brass_section":
			_attack_brass_section(attack, dynamic_mult)
		"tutti":
			_attack_tutti(attack, dynamic_mult)

## 弦乐组：快速连续弹幕
func _attack_string_section(attack: Dictionary, dynamic_mult: float) -> void:
	var damage: float = attack.get("damage", string_damage) * dynamic_mult
	var count := int(8 + _dynamic_level * 8)
	
	for i in range(count):
		get_tree().create_timer(i * 0.1).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			if _target:
				var angle := (global_position.direction_to(_target.global_position)).angle()
				angle += randf_range(-0.15, 0.15)
				_spawn_elite_projectile(global_position, angle,
					string_speed, damage * 0.3,
					Color(0.8, 0.6, 0.3, 0.8))
		)

## 管乐组：持续性光束
func _attack_wind_section(attack: Dictionary, dynamic_mult: float) -> void:
	var damage: float = attack.get("damage", wind_damage) * dynamic_mult
	
	if _target == null:
		return
	
	var dir := (global_position.direction_to(_target.global_position)).normalized()
	
	# 预警线
	var warning := Line2D.new()
	warning.width = 3.0
	warning.default_color = Color(0.3, 0.5, 0.7, 0.4)
	warning.add_point(global_position)
	warning.add_point(global_position + dir * 400.0)
	get_parent().add_child(warning)
	
	get_tree().create_timer(0.8).timeout.connect(func():
		if not is_instance_valid(warning):
			return
		warning.width = 20.0
		warning.default_color = Color(0.5, 0.7, 1.0, 0.7)
		
		if _target and is_instance_valid(_target):
			var to_player := _target.global_position - global_position
			var proj := to_player.project(dir)
			var perp_dist := (to_player - proj).length()
			if perp_dist < 25.0 and proj.length() < 400.0:
				if _target.has_method("take_damage"):
					_target.take_damage(damage)
		
		var fade := warning.create_tween()
		fade.tween_property(warning, "modulate:a", 0.0, 0.4)
		fade.tween_callback(warning.queue_free)
	)

## 打击乐组：冲击波
func _attack_percussion_section(attack: Dictionary, dynamic_mult: float) -> void:
	var damage: float = attack.get("damage", percussion_damage) * dynamic_mult
	var radius := percussion_radius * (1.0 + _dynamic_level * 0.5)
	
	# 冲击波
	var wave := Node2D.new()
	wave.global_position = global_position
	get_parent().add_child(wave)
	
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(24):
		var angle := (TAU / 24) * i
		points.append(Vector2.from_angle(angle) * 5.0)
	ring.polygon = points
	ring.color = Color(0.8, 0.4, 0.1, 0.7)
	wave.add_child(ring)
	
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", Vector2(radius / 5.0, radius / 5.0), 0.3)
	tween.parallel().tween_property(ring, "color:a", 0.0, 0.3)
	tween.tween_callback(wave.queue_free)
	
	if _target and is_instance_valid(_target):
		if global_position.distance_to(_target.global_position) < radius:
			if _target.has_method("take_damage"):
				_target.take_damage(damage)

## 铜管组：定向高伤害冲击
func _attack_brass_section(attack: Dictionary, dynamic_mult: float) -> void:
	var damage: float = attack.get("damage", brass_damage) * dynamic_mult
	
	if _target == null:
		return
	
	var angle := (global_position.direction_to(_target.global_position)).angle()
	
	# 集中的高速弹幕
	for i in range(5):
		var spread := (i - 2) * 0.08
		_spawn_elite_projectile(global_position, angle + spread,
			string_speed * 1.5, damage * 0.4,
			Color(0.9, 0.6, 0.1, 0.9))

## 全体齐奏（Tutti）
func _attack_tutti(attack: Dictionary, dynamic_mult: float) -> void:
	var damage: float = attack.get("damage", 20.0) * dynamic_mult
	
	# 同时发动所有乐器组攻击
	_attack_string_section({"damage": string_damage * 0.5}, dynamic_mult)
	get_tree().create_timer(0.5).timeout.connect(func():
		if _is_dead:
			return
		_attack_percussion_section({"damage": percussion_damage * 0.5}, dynamic_mult)
	)
	get_tree().create_timer(1.0).timeout.connect(func():
		if _is_dead:
			return
		_attack_brass_section({"damage": brass_damage * 0.5}, dynamic_mult)
	)

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	var to_player := _target.global_position - global_position
	var dist := to_player.length()
	
	if dist > 220.0:
		return to_player.normalized()
	elif dist < 130.0:
		return -to_player.normalized()
	return to_player.normalized().rotated(PI / 3.0)

func _on_elite_enrage() -> void:
	_dynamic_level = 1.0
	move_speed *= 1.4
	for attack in _elite_attacks:
		attack["cooldown"] = attack.get("cooldown", 2.0) * 0.5
	base_color = Color(1.0, 0.2, 0.0)

func _on_elite_death_effect() -> void:
	pass

func _get_type_name() -> String:
	return "symphony_commander"
