## ch4_court_kapellmeister.gd
## 第四章精英/小Boss：宫廷乐师长 (Court Kapellmeister)
## 莫扎特宫廷的乐队指挥，以完美的结构和对称性攻击。
## 音乐隐喻：古典主义对形式完美的追求。
## 机制：
## - 释放严格对称的弹幕图案
## - "繁复诅咒"：检测并惩罚过度复杂的攻击
## - 召唤小步舞曲舞者对
## - 奏鸣曲式攻击模式（呈示-发展-再现）
extends "res://scripts/entities/enemies/elite_base.gd"

# ============================================================
# Court Kapellmeister 专属配置
# ============================================================
## 对称弹幕速度
@export var symmetry_projectile_speed: float = 170.0
## 对称弹幕伤害
@export var symmetry_damage: float = 14.0
## 繁复诅咒检测半径
@export var complexity_detect_radius: float = 250.0
## 繁复诅咒疲劳增加量
@export var complexity_fatigue_penalty: float = 0.2

# ============================================================
# 内部状态
# ============================================================
## 奏鸣曲式阶段 (0=呈示, 1=发展, 2=再现)
var _sonata_phase: int = 0
var _sonata_attack_count: int = 0
## 对称角度
var _symmetry_angle: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _on_elite_ready() -> void:
	elite_name = "宫廷乐师长"
	elite_title = "Court Kapellmeister"
	
	max_hp = 500.0
	current_hp = 500.0
	move_speed = 45.0
	contact_damage = 12.0
	xp_value = 40
	
	base_color = Color(0.95, 0.85, 0.6)
	aura_radius = 0.0
	
	quantized_fps = 10.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.5
	
	_elite_shield = 80.0
	_elite_max_shield = 80.0

func _define_elite_attacks() -> void:
	_elite_attacks = [
		{
			"name": "symmetric_barrage",
			"duration": 2.0,
			"cooldown": 3.0,
			"damage": symmetry_damage,
			"weight": 3.0,
		},
		{
			"name": "mirror_waltz",
			"duration": 3.0,
			"cooldown": 4.0,
			"damage": symmetry_damage * 0.8,
			"weight": 2.5,
		},
		{
			"name": "complexity_curse",
			"duration": 0.5,
			"cooldown": 7.0,
			"damage": 15.0,
			"weight": 1.5,
		},
		{
			"name": "cadence_burst",
			"duration": 1.5,
			"cooldown": 5.0,
			"damage": symmetry_damage * 1.5,
			"weight": 2.0,
		},
	]

# ============================================================
# 精英每帧逻辑
# ============================================================

func _on_elite_process(delta: float) -> void:
	_symmetry_angle += delta * 0.5
	
	if _sprite:
		# 优雅的微摆
		_sprite.rotation = sin(_symmetry_angle * 2.0) * 0.08

# ============================================================
# 攻击实现
# ============================================================

func _perform_elite_attack(attack: Dictionary) -> void:
	_sonata_attack_count += 1
	# 每6次攻击切换奏鸣曲式阶段
	if _sonata_attack_count % 6 == 0:
		_sonata_phase = (_sonata_phase + 1) % 3
	
	match attack["name"]:
		"symmetric_barrage":
			_attack_symmetric_barrage(attack)
		"mirror_waltz":
			_attack_mirror_waltz(attack)
		"complexity_curse":
			_attack_complexity_curse(attack)
		"cadence_burst":
			_attack_cadence_burst(attack)

## 攻击1：对称弹幕 — 完美对称的弹幕图案
func _attack_symmetric_barrage(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", symmetry_damage)
	var count := 8
	var base_angle := 0.0
	if _target:
		base_angle = (global_position.direction_to(_target.global_position)).angle()
	
	# 对称发射
	for i in range(count):
		var angle := base_angle + (TAU / count) * i
		_spawn_elite_projectile(global_position, angle,
			symmetry_projectile_speed, damage,
			Color(0.95, 0.85, 0.6, 0.8))
		# 镜像
		var mirror_angle := base_angle - (TAU / count) * i
		_spawn_elite_projectile(global_position, mirror_angle,
			symmetry_projectile_speed, damage,
			Color(0.85, 0.75, 0.5, 0.8))
	
	# 再现部加速
	if _sonata_phase == 2:
		get_tree().create_timer(0.5).timeout.connect(func():
			if _is_dead:
				return
			for i in range(count):
				var angle := base_angle + (TAU / count) * i + 0.2
				_spawn_elite_projectile(global_position, angle,
					symmetry_projectile_speed * 1.3, damage * 1.2,
					Color(1.0, 0.9, 0.5, 0.9))
		)

## 攻击2：镜像华尔兹 — 旋转对称弹幕
func _attack_mirror_waltz(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", symmetry_damage * 0.8)
	var steps := 8
	
	for step in range(steps):
		get_tree().create_timer(step * 0.3).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			var angle := _symmetry_angle + step * 0.4
			# 双螺旋（对称）
			_spawn_elite_projectile(global_position, angle,
				symmetry_projectile_speed * 0.8, damage,
				Color(0.9, 0.8, 0.6, 0.8))
			_spawn_elite_projectile(global_position, angle + PI,
				symmetry_projectile_speed * 0.8, damage,
				Color(0.9, 0.8, 0.6, 0.8))
		)

## 攻击3：繁复诅咒 — 惩罚过度复杂
func _attack_complexity_curse(attack: Dictionary) -> void:
	# 检测玩家周围的召唤物数量
	var summon_count := 0
	for node in get_tree().get_nodes_in_group("player_summons"):
		if is_instance_valid(node):
			summon_count += 1
	
	if summon_count >= 2:
		# 清除召唤物
		for node in get_tree().get_nodes_in_group("player_summons"):
			if is_instance_valid(node):
				# 优雅地分解
				if node is Node2D:
					var tween := node.create_tween()
					tween.tween_property(node, "modulate:a", 0.0, 0.5)
					tween.tween_callback(node.queue_free)
				else:
					node.queue_free()
		
		# 增加疲劳
		if FatigueManager and FatigueManager.has_method("add_external_fatigue"):
			FatigueManager.add_external_fatigue(complexity_fatigue_penalty)
	
	# 无论如何都释放一次弹幕
	if _target:
		var angle := (global_position.direction_to(_target.global_position)).angle()
		for i in range(6):
			var a := angle + (i - 2.5) * 0.2
			_spawn_elite_projectile(global_position, a,
				symmetry_projectile_speed, attack.get("damage", 15.0),
				Color(0.8, 0.6, 0.9, 0.8))

## 攻击4：终止式爆发 — 高伤害集中弹幕
func _attack_cadence_burst(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", symmetry_damage * 1.5)
	
	if _target == null:
		return
	
	var angle := (global_position.direction_to(_target.global_position)).angle()
	
	# 集中的高速弹幕
	for i in range(8):
		var spread := (i - 3.5) * 0.08
		_spawn_elite_projectile(global_position, angle + spread,
			symmetry_projectile_speed * 1.5, damage * 0.5,
			Color(1.0, 0.9, 0.5, 0.9))

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	var to_player := _target.global_position - global_position
	var dist := to_player.length()
	
	if dist > 200.0:
		return to_player.normalized()
	elif dist < 100.0:
		return -to_player.normalized()
	else:
		return to_player.normalized().rotated(PI / 2.0)

func _on_elite_enrage() -> void:
	move_speed *= 1.3
	for attack in _elite_attacks:
		attack["cooldown"] = attack.get("cooldown", 2.0) * 0.5
	base_color = Color(1.0, 0.6, 0.2)

func _on_elite_death_effect() -> void:
	pass

func _get_type_name() -> String:
	return "court_kapellmeister"
