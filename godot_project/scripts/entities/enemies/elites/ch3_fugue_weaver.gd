## ch3_fugue_weaver.gd
## 第三章精英/小Boss：赋格编织者 (Fugue Weaver)
## 巴赫的复调机械中枢，能够同时操控多条弹幕轨迹形成"赋格迷宫"。
## 音乐隐喻：赋格曲中的"主题"与"应答"的交织。
## 机制：
## - 释放"主题弹幕"后，延迟释放"应答弹幕"（模仿式对位）
## - 创建弹幕迷宫，限制玩家移动空间
## - 吸收单音攻击并转化为护盾
## - 狂暴时多条赋格声部同时运行
extends "res://scripts/entities/enemies/elite_base.gd"

# ============================================================
# Fugue Weaver 专属配置
# ============================================================
## 主题弹幕速度
@export var subject_speed: float = 140.0
## 应答弹幕延迟（秒）
@export var answer_delay: float = 1.5
## 弹幕伤害
@export var fugue_damage: float = 12.0
## 迷宫墙体持续时间
@export var maze_wall_duration: float = 4.0
## 单音吸收护盾量
@export var absorb_shield_amount: float = 20.0

# ============================================================
# 内部状态
# ============================================================
## 赋格主题记录（用于应答模仿）
var _subject_patterns: Array[Dictionary] = []
## 迷宫墙体节点
var _maze_walls: Array[Node2D] = []
## 编织视觉相位
var _weave_phase: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _on_elite_ready() -> void:
	elite_name = "赋格编织者"
	elite_title = "Fugue Weaver"
	
	max_hp = 450.0
	current_hp = 450.0
	move_speed = 40.0
	contact_damage = 12.0
	xp_value = 35
	
	base_color = Color(0.6, 0.4, 0.2)
	aura_radius = 120.0
	aura_color = Color(0.6, 0.4, 0.2, 0.1)
	
	quantized_fps = 8.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.55
	
	_elite_shield = 70.0
	_elite_max_shield = 70.0

func _define_elite_attacks() -> void:
	_elite_attacks = [
		{
			"name": "fugue_subject",
			"duration": 3.0,
			"cooldown": 4.0,
			"damage": fugue_damage,
			"weight": 3.0,
		},
		{
			"name": "maze_construct",
			"duration": 2.0,
			"cooldown": 6.0,
			"damage": fugue_damage * 0.8,
			"weight": 2.0,
		},
		{
			"name": "counterpoint_spiral",
			"duration": 3.5,
			"cooldown": 5.0,
			"damage": fugue_damage * 1.2,
			"weight": 2.5,
		},
	]

# ============================================================
# 精英每帧逻辑
# ============================================================

func _on_elite_process(delta: float) -> void:
	_weave_phase += delta * 2.5
	
	# 编织视觉
	if _sprite:
		_sprite.rotation = sin(_weave_phase) * 0.2
	
	# 清理过期迷宫墙体
	var to_remove: Array[int] = []
	for i in range(_maze_walls.size()):
		if not is_instance_valid(_maze_walls[i]):
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		_maze_walls.remove_at(to_remove[i])

# ============================================================
# 攻击实现
# ============================================================

func _perform_elite_attack(attack: Dictionary) -> void:
	match attack["name"]:
		"fugue_subject":
			_attack_fugue_subject(attack)
		"maze_construct":
			_attack_maze_construct(attack)
		"counterpoint_spiral":
			_attack_counterpoint_spiral(attack)

## 攻击1：赋格主题 — 发射主题弹幕，延迟后发射应答弹幕
func _attack_fugue_subject(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", fugue_damage)
	
	if _target == null:
		return
	
	var base_angle := (global_position.direction_to(_target.global_position)).angle()
	
	# 主题：5发弹幕
	var subject_angles: Array[float] = []
	for i in range(5):
		var angle := base_angle + (i - 2) * 0.2
		subject_angles.append(angle)
		_spawn_elite_projectile(global_position, angle, subject_speed, damage,
			Color(0.7, 0.5, 0.2, 0.9))
	
	# 记录主题
	_subject_patterns.append({
		"angles": subject_angles,
		"origin": global_position,
	})
	
	# 延迟后发射应答（转位模仿）
	get_tree().create_timer(answer_delay).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			return
		# 应答：主题的逆行（角度翻转）
		for angle in subject_angles:
			var answer_angle := angle + PI  # 逆行
			_spawn_elite_projectile(global_position, answer_angle,
				subject_speed * 0.8, damage * 0.8,
				Color(0.8, 0.6, 0.3, 0.8))
	)
	
	# 视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(_sprite, "modulate", Color(0.8, 0.6, 0.3), 0.1)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.3)
		tween.tween_property(_sprite, "modulate", base_color, 0.3)

## 攻击2：迷宫构建 — 在战场上放置弹幕墙体
func _attack_maze_construct(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", fugue_damage * 0.8)
	
	# 放置 3-4 段墙体
	var wall_count := randi_range(3, 4)
	for i in range(wall_count):
		var angle := randf() * TAU
		var dist := randf_range(80.0, 200.0)
		var wall_pos := global_position + Vector2.from_angle(angle) * dist
		var wall_angle := angle + PI / 2.0  # 垂直于放射方向
		
		_spawn_maze_wall(wall_pos, wall_angle, damage)

func _spawn_maze_wall(pos: Vector2, angle: float, damage: float) -> void:
	var wall := Node2D.new()
	wall.global_position = pos
	get_parent().add_child(wall)
	_maze_walls.append(wall)
	
	# 墙体视觉
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-40, -3), Vector2(40, -3), Vector2(40, 3), Vector2(-40, 3)
	])
	visual.color = Color(0.6, 0.4, 0.2, 0.6)
	visual.rotation = angle
	wall.add_child(visual)
	
	# 墙体存在期间持续检测碰撞
	var lifetime := maze_wall_duration
	var timer := 0.0
	
	var update_fn := func():
		if not is_instance_valid(wall):
			return
		timer += get_process_delta_time()
		if timer >= lifetime:
			var tween := wall.create_tween()
			tween.tween_property(wall, "modulate:a", 0.0, 0.3)
			tween.tween_callback(wall.queue_free)
			return
		# 碰撞检测
		if _target and is_instance_valid(_target):
			if _target.global_position.distance_to(pos) < 45.0:
				if _target.has_method("take_damage"):
					_target.take_damage(damage * get_process_delta_time())
	
	get_tree().process_frame.connect(update_fn)
	wall.tree_exiting.connect(func():
		if get_tree().process_frame.is_connected(update_fn):
			get_tree().process_frame.disconnect(update_fn)
	)

## 攻击3：对位螺旋 — 双螺旋弹幕
func _attack_counterpoint_spiral(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", fugue_damage * 1.2)
	var duration := 3.0
	var interval := 0.15
	var total := int(duration / interval)
	
	for step in range(total):
		get_tree().create_timer(step * interval).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			# 双螺旋
			var angle1 := _weave_phase + step * 0.2
			var angle2 := _weave_phase + step * 0.2 + PI  # 对位（相差半圈）
			
			_spawn_elite_projectile(global_position, angle1, subject_speed,
				damage * 0.5, Color(0.7, 0.5, 0.2, 0.8))
			_spawn_elite_projectile(global_position, angle2, subject_speed * 0.9,
				damage * 0.5, Color(0.5, 0.3, 0.1, 0.8))
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
	elif dist < 120.0:
		return -to_player.normalized()
	else:
		# 绕圈移动
		return to_player.normalized().rotated(PI / 2.5)

# ============================================================
# 狂暴
# ============================================================

func _on_elite_enrage() -> void:
	move_speed *= 1.3
	answer_delay *= 0.5
	
	for attack in _elite_attacks:
		attack["cooldown"] = attack.get("cooldown", 2.0) * 0.5
	
	base_color = Color(0.8, 0.3, 0.1)

func _on_elite_death_effect() -> void:
	# 清理迷宫墙体
	for wall in _maze_walls:
		if is_instance_valid(wall):
			wall.queue_free()
	_maze_walls.clear()

func _get_type_name() -> String:
	return "fugue_weaver"
