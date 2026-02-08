## ch6_walking_bass.gd
## 第六章特色敌人：行走贝斯 (Walking Bass)
## 沿着爵士行走贝斯线的音阶路径移动的敌人。
## 音乐隐喻：爵士乐中行走贝斯的稳定律动，四分音符逐级进行。
## 机制：
## - 沿预设的音阶路径移动（非直线追踪）
## - 每到达一个"音符节点"时释放低频脉冲
## - 路径上留下持续伤害的"贝斯线"轨迹
## - 多个行走贝斯会形成和声路径网络
## - 在反拍（2、4拍）时移动速度加倍（摇摆感）
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Walking Bass 专属配置
# ============================================================
## 路径节点间距
@export var path_step_distance: float = 60.0
## 低频脉冲伤害
@export var pulse_damage: float = 8.0
## 低频脉冲范围
@export var pulse_radius: float = 80.0
## 轨迹持续时间
@export var trail_duration: float = 5.0
## 轨迹伤害/秒
@export var trail_dps: float = 5.0
## 反拍速度倍率
@export var offbeat_speed_mult: float = 2.0
## 音阶模式（蓝调音阶度数）
@export var scale_degrees: Array[int] = [0, 2, 3, 5, 7, 9, 10, 12]

# ============================================================
# 内部状态
# ============================================================
## 路径系统
var _path_nodes: Array[Vector2] = []
var _current_path_index: int = 0
var _path_direction: int = 1  # 1=正向, -1=反向
var _base_move_speed: float = 0.0

## 轨迹系统
var _trail_segments: Array[Dictionary] = []  # {node, position, timer}

## 脉冲冷却
var _pulse_cooldown: float = 0.0

## 节拍状态
var _is_offbeat: bool = false
var _beat_counter: int = 0

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.PULSE
	quantized_fps = 12.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.3
	move_on_offbeat = true  # 反拍移动
	
	base_color = Color(0.4, 0.2, 0.6)
	base_glitch_intensity = 0.05
	max_glitch_intensity = 0.6
	
	_base_move_speed = move_speed
	
	# 生成初始路径
	_generate_bass_path()

func _generate_bass_path() -> void:
	_path_nodes.clear()
	
	# 以当前位置为起点，沿音阶度数生成路径
	var start_pos := global_position
	var base_angle := randf() * TAU
	
	for i in range(scale_degrees.size()):
		var degree := scale_degrees[i]
		# 每个音阶度数对应一个方向偏移
		var angle := base_angle + degree * deg_to_rad(12.0)
		var pos := start_pos + Vector2.from_angle(angle) * path_step_distance * (i + 1)
		_path_nodes.append(pos)
	
	_current_path_index = 0

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 更新轨迹
	_update_trails(delta)
	
	# 脉冲冷却
	if _pulse_cooldown > 0.0:
		_pulse_cooldown -= delta
	
	# 速度调整（反拍加速）
	if _is_offbeat:
		move_speed = _base_move_speed * offbeat_speed_mult
	else:
		move_speed = _base_move_speed

func _update_trails(delta: float) -> void:
	var expired: Array[int] = []
	for i in range(_trail_segments.size()):
		var seg := _trail_segments[i]
		seg["timer"] -= delta
		if seg["timer"] <= 0.0:
			expired.append(i)
			if is_instance_valid(seg["node"]):
				seg["node"].queue_free()
		else:
			# 轨迹伤害
			if _target and is_instance_valid(_target):
				var dist := _target.global_position.distance_to(seg["position"])
				if dist < 20.0:
					if _target.has_method("take_damage"):
						_target.take_damage(trail_dps * delta)
			# 淡出
			if is_instance_valid(seg["node"]):
				seg["node"].modulate.a = seg["timer"] / trail_duration
	
	# 移除过期轨迹
	for i in range(expired.size() - 1, -1, -1):
		_trail_segments.remove_at(expired[i])

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _path_nodes.is_empty():
		_generate_bass_path()
		return Vector2.ZERO
	
	var target_pos := _path_nodes[_current_path_index]
	var dir := (target_pos - global_position)
	var dist := dir.length()
	
	if dist < 15.0:
		# 到达节点：释放脉冲 + 留下轨迹
		_on_reach_path_node()
		
		# 移动到下一个节点
		_current_path_index += _path_direction
		if _current_path_index >= _path_nodes.size():
			_path_direction = -1
			_current_path_index = _path_nodes.size() - 2
		elif _current_path_index < 0:
			_path_direction = 1
			_current_path_index = 1
			# 重新生成路径（朝向玩家）
			if _target and is_instance_valid(_target):
				_regenerate_path_toward_player()
	
	return dir.normalized()

func _regenerate_path_toward_player() -> void:
	_path_nodes.clear()
	var start_pos := global_position
	var base_angle := (global_position.direction_to(_target.global_position)).angle()
	
	for i in range(scale_degrees.size()):
		var degree := scale_degrees[i]
		var angle := base_angle + degree * deg_to_rad(8.0) - deg_to_rad(40.0)
		var pos := start_pos + Vector2.from_angle(angle) * path_step_distance * (i + 1)
		_path_nodes.append(pos)
	
	_current_path_index = 0
	_path_direction = 1

# ============================================================
# 路径节点到达事件
# ============================================================

func _on_reach_path_node() -> void:
	# 释放低频脉冲
	if _pulse_cooldown <= 0.0:
		_pulse_cooldown = 1.0
		_fire_bass_pulse()
	
	# 留下轨迹
	_spawn_trail_segment()

func _fire_bass_pulse() -> void:
	# 视觉：低频脉冲波
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(24):
		var angle := (TAU / 24) * i
		points.append(Vector2.from_angle(angle) * 5.0)
	ring.polygon = points
	ring.color = Color(0.5, 0.2, 0.7, 0.6)
	ring.global_position = global_position
	get_parent().add_child(ring)
	
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(pulse_radius / 5.0, pulse_radius / 5.0), 0.4)
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.chain()
	tween.tween_callback(ring.queue_free)
	
	# 伤害
	if _target and is_instance_valid(_target):
		if global_position.distance_to(_target.global_position) < pulse_radius:
			if _target.has_method("take_damage"):
				_target.take_damage(pulse_damage)

func _spawn_trail_segment() -> void:
	var trail := Polygon2D.new()
	trail.polygon = PackedVector2Array([
		Vector2(-8, -4), Vector2(8, -4), Vector2(8, 4), Vector2(-8, 4)
	])
	trail.color = Color(0.3, 0.15, 0.5, 0.5)
	trail.global_position = global_position
	get_parent().add_child(trail)
	
	_trail_segments.append({
		"node": trail,
		"position": global_position,
		"timer": trail_duration,
	})

# ============================================================
# 节拍回调
# ============================================================

func _on_beat(_beat_index: int) -> void:
	_beat_counter += 1
	_is_offbeat = false
	
	# 强拍：视觉脉冲
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.3, 0.8), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

func _on_half_beat(_half_beat_index: int) -> void:
	_is_offbeat = true
	
	# 反拍：加速脉冲
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(0.8, 1.2), 0.03)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.08)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# 死亡时释放最终低频脉冲
	_fire_bass_pulse()
	
	# 清理所有轨迹
	for seg in _trail_segments:
		if is_instance_valid(seg["node"]):
			seg["node"].queue_free()
	_trail_segments.clear()

func _get_type_name() -> String:
	return "ch6_walking_bass"
