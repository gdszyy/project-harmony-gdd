## ch2_cantor_commander.gd
## 第二章精英/小Boss：圣歌指挥官 (Cantor Commander)
## 中世纪教堂的唱诗班指挥，能够强化周围唱诗班敌人并释放圣咏音墙。
## 音乐隐喻：领唱者(Cantor)，引导齐唱的核心人物。
## 机制：
## - 增强范围内唱诗班编队的攻击力和护盾
## - 释放宽幅"圣咏音墙"横扫战场
## - 召唤临时唱诗班编队
## - 惩罚单音攻击（声部孤立Debuff）
extends "res://scripts/entities/enemies/elite_base.gd"

# ============================================================
# Cantor Commander 专属配置
# ============================================================
## 指挥光环半径
@export var command_aura_radius: float = 200.0
## 光环内敌人攻击力加成
@export var command_damage_bonus: float = 0.3
## 圣咏音墙宽度
@export var chant_wall_width: float = 400.0
## 圣咏音墙速度
@export var chant_wall_speed: float = 120.0
## 圣咏音墙伤害
@export var chant_wall_damage: float = 18.0
## 声部孤立Debuff持续时间
@export var isolation_debuff_duration: float = 3.0

# ============================================================
# 内部状态
# ============================================================
var _command_pulse_timer: float = 0.0
var _chant_visual_phase: float = 0.0
## 指挥手势动画
var _gesture_phase: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _on_elite_ready() -> void:
	elite_name = "圣歌指挥官"
	elite_title = "Cantor Commander"
	
	max_hp = 400.0
	current_hp = 400.0
	move_speed = 35.0
	contact_damage = 10.0
	xp_value = 30
	
	base_color = Color(0.9, 0.75, 0.2)
	aura_radius = command_aura_radius
	aura_color = Color(0.9, 0.75, 0.2, 0.1)
	
	quantized_fps = 6.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.6
	
	_elite_shield = 60.0
	_elite_max_shield = 60.0

func _define_elite_attacks() -> void:
	_elite_attacks = [
		{
			"name": "chant_wall",
			"duration": 1.5,
			"cooldown": 4.0,
			"damage": chant_wall_damage,
			"weight": 3.0,
		},
		{
			"name": "choir_summon",
			"duration": 1.0,
			"cooldown": 8.0,
			"damage": 0.0,
			"weight": 2.0,
		},
		{
			"name": "gregorian_blast",
			"duration": 2.0,
			"cooldown": 5.0,
			"damage": 15.0,
			"weight": 2.5,
		},
		{
			"name": "voice_isolation",
			"duration": 0.5,
			"cooldown": 6.0,
			"damage": 10.0,
			"weight": 1.5,
		},
	]

# ============================================================
# 精英每帧逻辑
# ============================================================

func _on_elite_process(delta: float) -> void:
	_gesture_phase += delta * 1.5
	_chant_visual_phase += delta * 2.0
	
	# 指挥光环脉冲
	_command_pulse_timer += delta
	if _command_pulse_timer >= 2.0:
		_command_pulse_timer = 0.0
		_apply_command_aura()
	
	# 指挥手势视觉
	if _sprite:
		_sprite.rotation = sin(_gesture_phase) * 0.15

# ============================================================
# 攻击实现
# ============================================================

func _perform_elite_attack(attack: Dictionary) -> void:
	match attack["name"]:
		"chant_wall":
			_attack_chant_wall(attack)
		"choir_summon":
			_attack_choir_summon()
		"gregorian_blast":
			_attack_gregorian_blast(attack)
		"voice_isolation":
			_attack_voice_isolation(attack)

## 攻击1：圣咏音墙 — 宽幅横扫弹幕
func _attack_chant_wall(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", chant_wall_damage)
	
	if _target == null:
		return
	
	var dir := (global_position.direction_to(_target.global_position)).normalized()
	var perp := dir.rotated(PI / 2.0)
	
	# 生成音墙（多条平行弹幕线）
	var line_count := 5
	for i in range(line_count):
		var offset := perp * ((i - line_count / 2.0) * (chant_wall_width / line_count))
		var start_pos := global_position + offset
		
		var proj := Area2D.new()
		proj.add_to_group("enemy_projectiles")
		
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(chant_wall_width / line_count, 8)
		col.shape = shape
		col.rotation = dir.angle()
		proj.add_child(col)
		
		var visual := Polygon2D.new()
		var half_w := chant_wall_width / line_count / 2.0
		visual.polygon = PackedVector2Array([
			Vector2(-half_w, -4), Vector2(half_w, -4),
			Vector2(half_w, 4), Vector2(-half_w, 4)
		])
		visual.color = Color(0.9, 0.8, 0.3, 0.7)
		visual.rotation = dir.angle()
		proj.add_child(visual)
		
		proj.global_position = start_pos
		get_parent().add_child(proj)
		
		var end_pos := start_pos + dir * 500.0
		var tween := proj.create_tween()
		tween.tween_property(proj, "global_position", end_pos, 500.0 / chant_wall_speed)
		tween.tween_callback(proj.queue_free)
		
		proj.body_entered.connect(func(body: Node2D):
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(damage)
		)
	
	# 视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.6, 1.6), 0.15)
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.9, 0.4), 0.15)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.3)
		tween.tween_property(_sprite, "modulate", base_color, 0.3)

## 攻击2：召唤唱诗班
func _attack_choir_summon() -> void:
	# 通过信号通知生成系统召唤唱诗班编队
	emit_signal("elite_summon_requested", 3, "ch2_choir")
	
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.2)
		tween.tween_property(_sprite, "modulate", base_color, 0.5)

## 攻击3：格里高利冲击 — 多方向圣咏弹幕
func _attack_gregorian_blast(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", 15.0)
	var waves := 3
	
	for wave in range(waves):
		get_tree().create_timer(wave * 0.6).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			# 8方向弹幕
			for i in range(8):
				var angle := (TAU / 8) * i + wave * 0.2
				_spawn_elite_projectile(
					global_position, angle, 160.0,
					damage, Color(0.9, 0.8, 0.3, 0.8)
				)
		)

## 攻击4：声部孤立 — 惩罚性Debuff
func _attack_voice_isolation(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", 10.0)
	
	if _target and is_instance_valid(_target):
		if _target.has_method("take_damage"):
			_target.take_damage(damage)
		
		# 施加声部孤立Debuff（增加疲劳）
		if FatigueManager and FatigueManager.has_method("add_external_fatigue"):
			FatigueManager.add_external_fatigue(0.15)
	
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(0.5, 0.0, 0.5), 0.1)
		tween.tween_property(_sprite, "modulate", base_color, 0.4)

# ============================================================
# 指挥光环
# ============================================================

func _apply_command_aura() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < command_aura_radius:
			# 临时增加攻击力（通过增加 contact_damage）
			if enemy.has_method("set") and enemy.has_method("get"):
				var base_dmg: float = enemy.get("contact_damage")
				if base_dmg > 0:
					enemy.set("contact_damage", base_dmg * (1.0 + command_damage_bonus * 0.1))

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	var to_player := _target.global_position - global_position
	var dist := to_player.length()
	
	# 保持中远距离
	if dist > 250.0:
		return to_player.normalized()
	elif dist < 150.0:
		return -to_player.normalized()
	else:
		return to_player.normalized().rotated(PI / 3.0)

# ============================================================
# 狂暴
# ============================================================

func _on_elite_enrage() -> void:
	command_aura_radius *= 1.5
	aura_radius = command_aura_radius
	move_speed *= 1.2
	
	for attack in _elite_attacks:
		attack["cooldown"] = attack.get("cooldown", 2.0) * 0.6
	
	base_color = Color(1.0, 0.5, 0.1)

func _on_elite_death_effect() -> void:
	# 死亡时释放最后一次圣咏脉冲（纯视觉）
	pass

func _get_type_name() -> String:
	return "cantor_commander"
