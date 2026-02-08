## boss_mozart.gd
## 第四章最终 Boss：古典完形·莫扎特 (The Classical Perfection)
##
## 核心理念：古典主义完美形式的化身，穿着华丽燕尾服、动作精准优雅的贵公子。
## 手持水晶指挥棒，如同击剑般挥洒出致命而精准的乐章。
##
## 时代特征：【奏鸣曲式力场 (Sonata Form Field)】
## 整场Boss战被严格划分为奏鸣曲三部分：呈示部、发展部、再现部。
##
## 风格排斥：繁复的诅咒（清除召唤物+增加疲劳）
## 三阶段：呈示部(Exposition) → 发展部(Development) → 再现部(Recapitulation)
extends "res://scripts/entities/enemies/boss_base.gd"

# ============================================================
# 莫扎特专属常量
# ============================================================
## 主题A：直线冲刺斩击
const THEME_A_DASH_SPEED: float = 500.0
const THEME_A_DASH_DAMAGE: float = 25.0
const THEME_A_SLASH_COUNT: int = 3

## 主题B：圆舞曲式弹幕
const THEME_B_PROJECTILE_SPEED: float = 160.0
const THEME_B_DAMAGE: float = 12.0
const THEME_B_SPIRAL_COUNT: int = 6

## 繁复诅咒
const COMPLEXITY_FATIGUE_PENALTY: float = 0.25
const COMPLEXITY_CHECK_INTERVAL: float = 5.0

## 镜面反射弹幕
const MIRROR_REFLECT_SPEED: float = 200.0

# ============================================================
# 内部状态
# ============================================================
var _projectile_container: Node2D = null

## 奏鸣曲式阶段标识
var _sonata_section: String = "exposition"

## 冲刺系统
var _is_dashing: bool = false
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_timer: float = 0.0
var _pre_dash_pos: Vector2 = Vector2.ZERO

## 圆舞曲旋转
var _waltz_angle: float = 0.0
var _waltz_speed: float = 2.0

## 繁复诅咒计时
var _complexity_check_timer: float = 0.0

## 华彩乐章
var _cadenza_active: bool = false

## 节拍计数
var _mozart_beat_counter: int = 0

# ============================================================
# Boss 初始化
# ============================================================

func _on_boss_ready() -> void:
	boss_name = "古典完形"
	boss_title = "莫扎特 · The Classical Perfection"
	
	max_hp = 4500.0
	current_hp = 4500.0
	move_speed = 65.0
	contact_damage = 18.0
	xp_value = 180
	
	enrage_time = 230.0
	resonance_fragment_drop = 80
	
	base_color = Color(0.95, 0.9, 0.7)
	quantized_fps = 10.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.75
	
	_projectile_container = Node2D.new()
	_projectile_container.name = "MozartProjectiles"
	add_child(_projectile_container)

# ============================================================
# 阶段定义
# ============================================================

func _define_phases() -> void:
	_phase_configs = [
		{
			"name": "呈示部 · Exposition",
			"hp_threshold": 1.0,
			"speed_mult": 1.0,
			"damage_mult": 1.0,
			"color": Color(0.95, 0.9, 0.7),
			"shield_hp": 300.0,
			"music_layer": "boss_mozart_exposition",
			"summon_enabled": false,
			"attack_selection": "sequence",
			"attacks": [
				{
					"name": "theme_a_dash",
					"duration": 2.0,
					"cooldown": 3.0,
					"damage": THEME_A_DASH_DAMAGE,
					"weight": 3.0,
				},
				{
					"name": "theme_b_waltz",
					"duration": 3.0,
					"cooldown": 3.5,
					"damage": THEME_B_DAMAGE,
					"weight": 3.0,
				},
				{
					"name": "elegant_riposte",
					"duration": 1.5,
					"cooldown": 3.0,
					"damage": 15.0,
					"weight": 2.0,
				},
			],
		},
		{
			"name": "发展部 · Development",
			"hp_threshold": 0.55,
			"speed_mult": 1.3,
			"damage_mult": 1.3,
			"color": Color(1.0, 0.95, 0.6),
			"shield_hp": 250.0,
			"music_layer": "boss_mozart_development",
			"summon_enabled": true,
			"summon_count": 2,
			"summon_type": "ch4_minuet_dancer",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "theme_ab_combined",
					"duration": 4.0,
					"cooldown": 3.0,
					"damage": THEME_A_DASH_DAMAGE * 1.3,
					"weight": 3.0,
				},
				{
					"name": "theme_b_waltz",
					"duration": 3.0,
					"cooldown": 2.5,
					"damage": THEME_B_DAMAGE * 1.3,
					"weight": 2.0,
				},
				{
					"name": "mirror_reflection",
					"duration": 3.0,
					"cooldown": 4.0,
					"damage": 15.0,
					"weight": 2.5,
				},
				{
					"name": "complexity_curse",
					"duration": 0.5,
					"cooldown": 6.0,
					"damage": 0.0,
					"weight": 1.5,
				},
			],
		},
		{
			"name": "再现部 · Recapitulation",
			"hp_threshold": 0.2,
			"speed_mult": 1.5,
			"damage_mult": 1.8,
			"color": Color(1.0, 0.85, 0.3),
			"shield_hp": 0.0,
			"music_layer": "boss_mozart_recapitulation",
			"summon_enabled": true,
			"summon_count": 4,
			"summon_type": "ch4_minuet_dancer",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "theme_a_dash",
					"duration": 1.5,
					"cooldown": 2.0,
					"damage": THEME_A_DASH_DAMAGE * 1.8,
					"weight": 2.5,
				},
				{
					"name": "theme_b_waltz",
					"duration": 2.5,
					"cooldown": 2.0,
					"damage": THEME_B_DAMAGE * 1.8,
					"weight": 2.5,
				},
				{
					"name": "cadenza",
					"duration": 5.0,
					"cooldown": 5.0,
					"damage": THEME_A_DASH_DAMAGE * 2.0,
					"weight": 2.0,
				},
				{
					"name": "complexity_curse",
					"duration": 0.5,
					"cooldown": 5.0,
					"damage": 0.0,
					"weight": 1.0,
				},
			],
		},
	]

# ============================================================
# Boss 每帧逻辑
# ============================================================

func _on_boss_process(delta: float) -> void:
	_waltz_angle += _waltz_speed * delta
	
	# 冲刺更新
	if _is_dashing:
		_dash_timer -= delta
		velocity = _dash_direction * THEME_A_DASH_SPEED
		move_and_slide()
		if _dash_timer <= 0.0:
			_end_dash()
	
	# 繁复诅咒检测
	_complexity_check_timer += delta
	if _complexity_check_timer >= COMPLEXITY_CHECK_INTERVAL:
		_complexity_check_timer = 0.0
		_check_complexity()

# ============================================================
# 攻击实现
# ============================================================

func _perform_attack(attack: Dictionary) -> void:
	var config: Dictionary = _phase_configs[_current_phase] if _current_phase < _phase_configs.size() else {}
	var damage_mult: float = config.get("damage_mult", 1.0)
	
	match attack["name"]:
		"theme_a_dash":
			_attack_theme_a_dash(attack, damage_mult)
		"theme_b_waltz":
			_attack_theme_b_waltz(attack, damage_mult)
		"elegant_riposte":
			_attack_elegant_riposte(attack, damage_mult)
		"theme_ab_combined":
			_attack_theme_ab_combined(attack, damage_mult)
		"mirror_reflection":
			_attack_mirror_reflection(attack, damage_mult)
		"complexity_curse":
			_attack_complexity_curse()
		"cadenza":
			_attack_cadenza(attack, damage_mult)

## 主题A：直线冲刺斩击
func _attack_theme_a_dash(attack: Dictionary, damage_mult: float) -> void:
	if _target == null:
		return
	
	var slashes := THEME_A_SLASH_COUNT
	if _current_phase == 2:
		slashes += 2  # 再现部增加斩击次数
	
	for i in range(slashes):
		get_tree().create_timer(i * 0.5).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			_start_dash()
		)

func _start_dash() -> void:
	if _target == null:
		return
	_is_dashing = true
	_dash_timer = 0.2
	_pre_dash_pos = global_position
	_dash_direction = (global_position.direction_to(_target.global_position)).normalized()
	
	# 冲刺视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(0.5, 2.0), 0.05)
		_sprite.rotation = _dash_direction.angle()

func _end_dash() -> void:
	_is_dashing = false
	
	# 斩击弹幕（冲刺路径上的扇形）
	var slash_angle := _dash_direction.angle()
	for i in range(5):
		var angle := slash_angle - PI / 4.0 + (PI / 2.0 / 4.0) * i
		_spawn_boss_projectile(global_position, angle,
			MIRROR_REFLECT_SPEED, THEME_A_DASH_DAMAGE * 0.4,
			Color(0.95, 0.9, 0.7, 0.8))
	
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.15)
		tween.tween_property(_sprite, "rotation", 0.0, 0.15)

## 主题B：圆舞曲式弹幕
func _attack_theme_b_waltz(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", THEME_B_DAMAGE) * damage_mult
	var duration := 2.5
	var interval := 0.15
	var steps := int(duration / interval)
	
	for step in range(steps):
		get_tree().create_timer(step * interval).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			# 双螺旋弹幕
			for s in range(THEME_B_SPIRAL_COUNT):
				var angle := _waltz_angle + step * 0.15 + (TAU / THEME_B_SPIRAL_COUNT) * s
				_spawn_boss_projectile(global_position, angle,
					THEME_B_PROJECTILE_SPEED, damage * 0.3,
					Color(0.9, 0.85, 0.6, 0.7))
		)

## 优雅反击
func _attack_elegant_riposte(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", 15.0) * damage_mult
	
	if _target == null:
		return
	
	var angle := (global_position.direction_to(_target.global_position)).angle()
	for i in range(10):
		var a := angle + (i - 4.5) * 0.1
		_spawn_boss_projectile(global_position, a,
			MIRROR_REFLECT_SPEED * 1.2, damage * 0.4,
			Color(1.0, 0.95, 0.7, 0.9))

## 发展部：主题A+B组合
func _attack_theme_ab_combined(attack: Dictionary, damage_mult: float) -> void:
	# 同时冲刺 + 释放旋转弹幕
	_attack_theme_a_dash(attack, damage_mult)
	
	get_tree().create_timer(0.3).timeout.connect(func():
		if _is_dead:
			return
		_attack_theme_b_waltz(attack, damage_mult)
	)

## 镜面反射
func _attack_mirror_reflection(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", 15.0) * damage_mult
	
	# 发射弹幕，碰到"镜面边界"后反射
	if _target == null:
		return
	
	var angle := (global_position.direction_to(_target.global_position)).angle()
	for i in range(8):
		var a := angle + (i - 3.5) * 0.15
		_spawn_boss_projectile(global_position, a,
			MIRROR_REFLECT_SPEED, damage * 0.5,
			Color(0.8, 0.9, 1.0, 0.8))

## 繁复诅咒
func _attack_complexity_curse() -> void:
	_check_complexity()

func _check_complexity() -> void:
	var summon_count := 0
	for node in get_tree().get_nodes_in_group("player_summons"):
		if is_instance_valid(node):
			summon_count += 1
	
	if summon_count >= 2:
		# "化繁为简，朋友"
		for node in get_tree().get_nodes_in_group("player_summons"):
			if is_instance_valid(node) and node is Node2D:
				var tween := node.create_tween()
				tween.tween_property(node, "modulate:a", 0.0, 0.5)
				tween.tween_callback(node.queue_free)
		
		if FatigueManager and FatigueManager.has_method("add_external_fatigue"):
			FatigueManager.add_external_fatigue(COMPLEXITY_FATIGUE_PENALTY)

## 华彩乐章（再现部终极攻击）
func _attack_cadenza(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", THEME_A_DASH_DAMAGE * 2.0) * damage_mult
	_cadenza_active = true
	
	# 快速连续冲刺 + 密集弹幕
	for i in range(5):
		get_tree().create_timer(i * 0.8).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			# 冲刺
			_start_dash()
			# 全方位弹幕
			var count := 16
			for j in range(count):
				var angle := (TAU / count) * j + i * 0.2
				_spawn_boss_projectile(global_position, angle,
					THEME_B_PROJECTILE_SPEED * 1.3, damage * 0.2,
					Color(1.0, 0.9, 0.4, 0.9))
		)
	
	get_tree().create_timer(4.5).timeout.connect(func():
		_cadenza_active = false
	)

# ============================================================
# Boss 弹幕生成
# ============================================================

func _spawn_boss_projectile(pos: Vector2, angle: float, speed: float, damage: float, color: Color = Color.WHITE) -> void:
	if color == Color.WHITE:
		color = base_color.lerp(Color.WHITE, 0.3)
	
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-3, -3), Vector2(6, 0), Vector2(-3, 3)
	])
	visual.color = color
	visual.rotation = angle
	proj.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	col.shape = shape
	proj.add_child(col)
	
	proj.global_position = pos
	proj.set_meta("velocity", Vector2.from_angle(angle) * speed)
	proj.set_meta("damage", damage)
	proj.set_meta("age", 0.0)
	
	if _projectile_container and is_instance_valid(_projectile_container):
		_projectile_container.add_child(proj)
	else:
		get_parent().add_child(proj)
	
	var move_fn := func():
		if not is_instance_valid(proj):
			return
		var vel: Vector2 = proj.get_meta("velocity")
		proj.global_position += vel * get_process_delta_time()
		var age: float = proj.get_meta("age") + get_process_delta_time()
		proj.set_meta("age", age)
		if age >= 5.0:
			proj.queue_free()
			return
		if _target and is_instance_valid(_target):
			if proj.global_position.distance_to(_target.global_position) < 15.0:
				if _target.has_method("take_damage"):
					_target.take_damage(proj.get_meta("damage"))
				proj.queue_free()
	
	get_tree().process_frame.connect(move_fn)
	proj.tree_exiting.connect(func():
		if get_tree().process_frame.is_connected(move_fn):
			get_tree().process_frame.disconnect(move_fn)
	)

# ============================================================
# 阶段进入回调
# ============================================================

func _on_phase_entered(phase_index: int, _config: Dictionary) -> void:
	match phase_index:
		0:
			_sonata_section = "exposition"
		1:
			_sonata_section = "development"
			_waltz_speed = 3.0
			_summon_cooldown_time = 12.0
		2:
			_sonata_section = "recapitulation"
			_waltz_speed = 4.0
			_summon_cooldown_time = 8.0

func _on_enrage(level: int) -> void:
	match level:
		1:
			base_color = base_color.lerp(Color(1.0, 0.5, 0.2), 0.3)
		2:
			base_color = Color(1.0, 0.3, 0.1)

func _on_boss_beat(_beat_index: int) -> void:
	_mozart_beat_counter += 1

func _calculate_movement_direction() -> Vector2:
	if _is_dashing:
		return Vector2.ZERO
	if _target == null:
		return Vector2.ZERO
	
	var to_player := _target.global_position - global_position
	var dist := to_player.length()
	
	# 优雅的绕圈移动
	if dist > 200.0:
		return to_player.normalized()
	elif dist < 80.0:
		return -to_player.normalized()
	return to_player.normalized().rotated(PI / 2.5)

func _get_type_name() -> String:
	return "boss_mozart"

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _projectile_container and is_instance_valid(_projectile_container):
			for child in _projectile_container.get_children():
				if is_instance_valid(child):
					child.queue_free()
