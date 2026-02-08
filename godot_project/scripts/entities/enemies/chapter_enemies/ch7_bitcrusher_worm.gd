## ch7_bitcrusher_worm.gd
## 第七章特色敌人：降采样蠕虫 (Bitcrusher Worm)
## 以数字音频降采样为主题的蠕虫状敌人。
## 音乐隐喻：Bitcrusher 效果器将高保真信号降级为粗糙的低分辨率声音。
## 机制：
## - 蠕虫由多个"采样段"组成，像素化的分段身体
## - 经过的区域会被"降采样"——玩家在该区域内伤害降低
## - 身体段数随时间增长，越来越长
## - 头部发射"量化噪音"弹幕
## - 被击中时身体段会"断裂"，断裂的段变成独立的小敌人
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Bitcrusher Worm 专属配置
# ============================================================
## 身体段数
@export var initial_segments: int = 4
## 最大身体段数
@export var max_segments: int = 10
## 段生长间隔
@export var growth_interval: float = 6.0
## 降采样区域半径
@export var bitcrush_radius: float = 40.0
## 降采样区域持续时间
@export var bitcrush_duration: float = 4.0
## 降采样伤害减免比例
@export var bitcrush_damage_reduction: float = 0.4
## 量化噪音弹幕伤害
@export var noise_damage: float = 10.0
## 量化噪音弹幕速度
@export var noise_speed: float = 140.0
## 弹幕间隔
@export var fire_interval: float = 2.0

# ============================================================
# 内部状态
# ============================================================
## 身体段
var _segments: Array[Dictionary] = []  # {node, position, color}
var _segment_spacing: float = 20.0

## 生长计时
var _growth_timer: float = 0.0

## 降采样区域
var _bitcrush_zones: Array[Dictionary] = []  # {node, position, timer}

## 弹幕计时
var _fire_timer: float = 0.0

## 移动历史（用于身体跟随）
var _position_history: Array[Vector2] = []
var _history_interval: float = 0.05
var _history_timer: float = 0.0

## 蛇形移动
var _wander_angle: float = 0.0
var _wander_timer: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.PULSE
	max_hp = 120.0
	current_hp = 120.0
	move_speed = 65.0
	contact_damage = 12.0
	xp_value = 15
	
	quantized_fps = 8.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.5
	move_on_offbeat = false
	
	base_color = Color(0.0, 0.8, 0.5)
	base_glitch_intensity = 0.1
	max_glitch_intensity = 0.8
	collision_radius = 14.0
	
	# 创建初始身体段
	_create_segments(initial_segments)
	
	# 初始化位置历史
	for i in range(max_segments * 5):
		_position_history.append(global_position)

func _create_segments(count: int) -> void:
	for i in range(count):
		_add_segment()

func _add_segment() -> void:
	if _segments.size() >= max_segments:
		return
	
	var seg_visual := Polygon2D.new()
	# 像素化的方形段
	var size := 10.0 - _segments.size() * 0.5  # 越靠后越小
	size = max(size, 5.0)
	seg_visual.polygon = PackedVector2Array([
		Vector2(-size, -size), Vector2(size, -size),
		Vector2(size, size), Vector2(-size, size)
	])
	
	# 颜色渐变：头部亮绿 → 尾部暗绿
	var t := float(_segments.size()) / max_segments
	seg_visual.color = base_color.lerp(Color(0.0, 0.3, 0.2), t)
	
	var pos := global_position
	if _segments.size() > 0:
		pos = _segments[-1]["position"]
	
	seg_visual.global_position = pos
	get_parent().add_child(seg_visual)
	
	_segments.append({
		"node": seg_visual,
		"position": pos,
		"color": seg_visual.color,
	})

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 记录位置历史
	_history_timer += delta
	if _history_timer >= _history_interval:
		_history_timer = 0.0
		_position_history.push_front(global_position)
		if _position_history.size() > max_segments * 10:
			_position_history.pop_back()
	
	# 更新身体段位置
	_update_segments()
	
	# 生长
	_growth_timer += delta
	if _growth_timer >= growth_interval:
		_growth_timer = 0.0
		_add_segment()
	
	# 降采样区域
	_update_bitcrush_zones(delta)
	
	# 弹幕
	_fire_timer += delta
	if _fire_timer >= fire_interval:
		_fire_timer = 0.0
		_fire_noise_burst()
	
	# 定期留下降采样区域
	if fmod(Time.get_ticks_msec() * 0.001, 2.0) < delta:
		_spawn_bitcrush_zone()

func _update_segments() -> void:
	for i in range(_segments.size()):
		var seg := _segments[i]
		if not is_instance_valid(seg["node"]):
			continue
		
		# 每个段跟随位置历史中的对应位置
		var history_index := (i + 1) * 4
		if history_index < _position_history.size():
			seg["position"] = _position_history[history_index]
			seg["node"].global_position = seg["position"]
		
		# 像素化抖动
		if randf() < 0.1:
			seg["node"].position += Vector2(
				randf_range(-2, 2), randf_range(-2, 2)
			)

func _update_bitcrush_zones(delta: float) -> void:
	var expired: Array[int] = []
	
	for i in range(_bitcrush_zones.size()):
		var zone := _bitcrush_zones[i]
		zone["timer"] -= delta
		if zone["timer"] <= 0.0:
			expired.append(i)
			if is_instance_valid(zone["node"]):
				zone["node"].queue_free()
		else:
			# 淡出
			if is_instance_valid(zone["node"]):
				zone["node"].modulate.a = zone["timer"] / bitcrush_duration * 0.3
	
	for i in range(expired.size() - 1, -1, -1):
		_bitcrush_zones.remove_at(expired[i])

# ============================================================
# 降采样区域
# ============================================================

func _spawn_bitcrush_zone() -> void:
	var zone := Polygon2D.new()
	# 像素化方形
	zone.polygon = PackedVector2Array([
		Vector2(-bitcrush_radius, -bitcrush_radius),
		Vector2(bitcrush_radius, -bitcrush_radius),
		Vector2(bitcrush_radius, bitcrush_radius),
		Vector2(-bitcrush_radius, bitcrush_radius),
	])
	zone.color = Color(0.0, 0.6, 0.3, 0.15)
	zone.global_position = global_position
	get_parent().add_child(zone)
	
	_bitcrush_zones.append({
		"node": zone,
		"position": global_position,
		"timer": bitcrush_duration,
	})

## 检查位置是否在降采样区域内
func is_position_bitcrushed(pos: Vector2) -> bool:
	for zone in _bitcrush_zones:
		if pos.distance_to(zone["position"]) < bitcrush_radius:
			return true
	return false

# ============================================================
# 量化噪音弹幕
# ============================================================

func _fire_noise_burst() -> void:
	if _is_dead or not _target or not is_instance_valid(_target):
		return
	
	var dir := (global_position.direction_to(_target.global_position)).angle()
	
	# 量化噪音：不规则方向的弹幕
	var count := 3 + _segments.size() / 2
	for i in range(count):
		var angle := dir + randf_range(-0.5, 0.5)
		var speed := noise_speed * randf_range(0.7, 1.3)
		
		var proj := Area2D.new()
		proj.add_to_group("enemy_projectiles")
		
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 4.0
		col.shape = shape
		proj.add_child(col)
		
		# 像素化方形弹幕
		var visual := Polygon2D.new()
		var s := randf_range(3.0, 6.0)
		visual.polygon = PackedVector2Array([
			Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)
		])
		visual.color = Color(0.0, 1.0, 0.5, 0.8)
		proj.add_child(visual)
		
		proj.global_position = global_position
		get_parent().add_child(proj)
		
		var vel := Vector2.from_angle(angle) * speed
		var tween := proj.create_tween()
		tween.tween_property(proj, "global_position",
			proj.global_position + vel * 3.0, 3.0)
		tween.tween_callback(proj.queue_free)
		
		proj.body_entered.connect(func(body: Node2D):
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(noise_damage)
				proj.queue_free()
		)

# ============================================================
# 受击断裂
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	super.take_damage(amount, knockback_dir, is_perfect_beat)
	
	# 受到大量伤害时断裂尾部段
	if amount >= max_hp * 0.15 and _segments.size() > 1 and not _is_dead:
		_break_tail_segment()

func _break_tail_segment() -> void:
	if _segments.is_empty():
		return
	
	var tail = _segments.pop_back()
	if not is_instance_valid(tail["node"]):
		return
	
	var tail_pos: Vector2 = tail["position"]
	
	# 断裂视觉
	var tween = tail["node"].create_tween()
	tween.tween_property(tail["node"], "modulate", Color.WHITE, 0.1)
	tween.tween_property(tail["node"], "modulate:a", 0.0, 0.3)
	tween.tween_callback(tail["node"].queue_free)
	
	# 断裂处释放噪音弹幕
	for i in range(4):
		var angle := (TAU / 4) * i + randf() * 0.5
		var proj := Area2D.new()
		proj.add_to_group("enemy_projectiles")
		
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 3.0
		col.shape = shape
		proj.add_child(col)
		
		var visual := Polygon2D.new()
		visual.polygon = PackedVector2Array([
			Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
		])
		visual.color = Color(0.0, 1.0, 0.5, 0.7)
		proj.add_child(visual)
		
		proj.global_position = tail_pos
		get_parent().add_child(proj)
		
		var vel := Vector2.from_angle(angle) * noise_speed * 0.5
		var proj_tween := proj.create_tween()
		proj_tween.tween_property(proj, "global_position",
			proj.global_position + vel * 2.0, 2.0)
		proj_tween.tween_callback(proj.queue_free)

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	# 蛇形移动：朝玩家方向蜿蜒前进
	var to_player := (_target.global_position - global_position).normalized()
	
	_wander_timer += _quantize_interval
	_wander_angle += sin(_wander_timer * 2.0) * 0.8
	
	var wander_dir := Vector2.from_angle(to_player.angle() + sin(_wander_timer * 1.5) * 0.8)
	
	return wander_dir

# ============================================================
# 节拍回调
# ============================================================

func _on_beat(_beat_index: int) -> void:
	# 节拍时所有段闪烁
	for seg in _segments:
		if is_instance_valid(seg["node"]):
			var tween = seg["node"].create_tween()
			tween.tween_property(seg["node"], "modulate", Color.WHITE, 0.05)
			tween.tween_property(seg["node"], "modulate", seg["color"], 0.1)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# 死亡时所有段爆炸
	for seg in _segments:
		if is_instance_valid(seg["node"]):
			# 爆炸弹幕
			for i in range(3):
				var angle := randf() * TAU
				var proj := Area2D.new()
				proj.add_to_group("enemy_projectiles")
				var col := CollisionShape2D.new()
				var shape := CircleShape2D.new()
				shape.radius = 3.0
				col.shape = shape
				proj.add_child(col)
				var visual := Polygon2D.new()
				visual.polygon = PackedVector2Array([
					Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
				])
				visual.color = Color(0.0, 1.0, 0.5, 0.7)
				proj.add_child(visual)
				proj.global_position = seg["position"]
				get_parent().add_child(proj)
				var vel := Vector2.from_angle(angle) * noise_speed * 0.4
				var tween := proj.create_tween()
				tween.tween_property(proj, "global_position",
					proj.global_position + vel * 2.0, 2.0)
				tween.tween_callback(proj.queue_free)
			
			# 段消失
			seg["node"].queue_free()
	_segments.clear()
	
	# 清理降采样区域
	for zone in _bitcrush_zones:
		if is_instance_valid(zone["node"]):
			zone["node"].queue_free()
	_bitcrush_zones.clear()

func _get_type_name() -> String:
	return "ch7_bitcrusher_worm"
