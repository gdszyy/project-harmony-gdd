## ch2_scribe.gd
## 第二章特色敌人：经文抄写者 (Scribe)
## 在地面留下持续伤害的"四线谱"轨迹，模拟圭多发明的记谱法。
## 音乐隐喻：圭多的记谱法革命 — 将无形的声音固定为有形的符号。
## 机制：
## - 移动时在地面留下"四线谱"伤害轨迹
## - 轨迹持续一段时间后消失
## - 轨迹上的玩家受到持续伤害
## - 与 Silence 敌人类似的区域控制角色
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Scribe 专属配置
# ============================================================
## 轨迹伤害（每秒）
@export var trail_damage_per_sec: float = 12.0
## 轨迹持续时间
@export var trail_duration: float = 5.0
## 轨迹宽度
@export var trail_width: float = 30.0
## 轨迹生成间隔（秒）
@export var trail_interval: float = 0.3
## 最大同时存在轨迹数
@export var max_trail_segments: int = 20

# ============================================================
# 内部状态
# ============================================================
var _trail_timer: float = 0.0
var _trail_segments: Array[Dictionary] = []
var _last_trail_pos: Vector2 = Vector2.ZERO
## 书写动画相位
var _writing_phase: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.SILENCE
	quantized_fps = 10.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.2
	move_on_offbeat = true
	
	# 羊皮纸色调
	base_color = Color(0.7, 0.6, 0.4)
	base_glitch_intensity = 0.05
	max_glitch_intensity = 0.4
	
	_last_trail_pos = global_position

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 书写动画
	_writing_phase += delta * 4.0
	if _sprite:
		var bob := sin(_writing_phase) * 2.0
		_sprite.position.y = bob
	
	# 轨迹生成
	_trail_timer += delta
	if _trail_timer >= trail_interval:
		_trail_timer = 0.0
		var dist := global_position.distance_to(_last_trail_pos)
		if dist > 15.0:
			_spawn_trail_segment()
			_last_trail_pos = global_position
	
	# 更新轨迹（伤害检测+生命周期）
	_update_trails(delta)

# ============================================================
# 轨迹系统
# ============================================================

func _spawn_trail_segment() -> void:
	# 限制最大轨迹数
	if _trail_segments.size() >= max_trail_segments:
		var oldest := _trail_segments.pop_front()
		if is_instance_valid(oldest.get("visual")):
			oldest["visual"].queue_free()
	
	# 创建视觉：四条平行线（四线谱）
	var trail_visual := Node2D.new()
	trail_visual.global_position = global_position
	get_parent().add_child(trail_visual)
	
	for i in range(4):
		var line := Line2D.new()
		line.width = 1.5
		line.default_color = Color(0.6, 0.5, 0.3, 0.5)
		var y_offset := (i - 1.5) * (trail_width / 4.0)
		line.add_point(Vector2(-trail_width / 2, y_offset))
		line.add_point(Vector2(trail_width / 2, y_offset))
		trail_visual.add_child(line)
	
	# 添加一个随机"音符"符号
	var note := Polygon2D.new()
	var note_y := randf_range(-trail_width / 3, trail_width / 3)
	note.polygon = PackedVector2Array([
		Vector2(-3, -2), Vector2(3, -2), Vector2(3, 2), Vector2(-3, 2)
	])
	note.color = Color(0.3, 0.2, 0.1, 0.6)
	note.position = Vector2(0, note_y)
	trail_visual.add_child(note)
	
	_trail_segments.append({
		"position": global_position,
		"visual": trail_visual,
		"lifetime": trail_duration,
		"radius": trail_width / 2.0,
	})

func _update_trails(delta: float) -> void:
	var to_remove: Array[int] = []
	
	for i in range(_trail_segments.size()):
		var seg: Dictionary = _trail_segments[i]
		seg["lifetime"] -= delta
		
		if seg["lifetime"] <= 0.0:
			to_remove.append(i)
			if is_instance_valid(seg.get("visual")):
				var tween := seg["visual"].create_tween()
				tween.tween_property(seg["visual"], "modulate:a", 0.0, 0.3)
				tween.tween_callback(seg["visual"].queue_free)
			continue
		
		# 淡出效果
		if seg["lifetime"] < 1.0 and is_instance_valid(seg.get("visual")):
			seg["visual"].modulate.a = seg["lifetime"]
		
		# 伤害检测
		if _target and is_instance_valid(_target):
			var dist := _target.global_position.distance_to(seg["position"])
			if dist < seg["radius"]:
				if _target.has_method("take_damage"):
					_target.take_damage(trail_damage_per_sec * delta)
	
	# 移除过期轨迹
	for i in range(to_remove.size() - 1, -1, -1):
		_trail_segments.remove_at(to_remove[i])

# ============================================================
# 移动逻辑：蛇形移动（模拟书写）
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	var to_player := (_target.global_position - global_position).normalized()
	# 蛇形偏移
	var perpendicular := to_player.rotated(PI / 2.0)
	var snake := sin(_writing_phase * 0.5) * 0.5
	
	return (to_player + perpendicular * snake).normalized()

# ============================================================
# 节拍响应
# ============================================================

func _on_beat(_beat_index: int) -> void:
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.1, 1.1), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# 死亡时所有轨迹加速消失
	for seg in _trail_segments:
		seg["lifetime"] = min(seg["lifetime"], 0.5)
