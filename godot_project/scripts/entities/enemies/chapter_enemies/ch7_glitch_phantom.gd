## ch7_glitch_phantom.gd
## 第七章精英敌人：故障幽灵 (Glitch Phantom)
## 由数据错误和频率异常凝聚而成的幽灵实体。
## 音乐隐喻：数字音频中的故障艺术(Glitch Art)——
## 将错误和噪音转化为有意义的美学表达。
## 机制：
## - 周期性在可见/不可见状态之间切换（频率闪烁）
## - 不可见时免疫伤害但不攻击
## - 可见时释放"频率干扰"弹幕并可被攻击
## - 被击杀后会在原地留下"数据残留"——一个持续干扰的区域
## - 移动时会随机"传送"短距离（故障跳跃）
## - 多个幽灵会形成"干扰网络"，互相增强
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Glitch Phantom 专属配置
# ============================================================
## 可见/不可见切换间隔
@export var phase_interval: float = 3.0
## 可见持续时间
@export var visible_duration: float = 2.0
## 故障传送间隔
@export var teleport_interval: float = 1.5
## 故障传送距离
@export var teleport_distance: float = 80.0
## 频率干扰弹幕伤害
@export var interference_damage: float = 12.0
## 频率干扰弹幕速度
@export var interference_speed: float = 160.0
## 攻击间隔
@export var attack_interval: float = 1.0
## 数据残留持续时间
@export var residue_duration: float = 8.0
## 数据残留伤害/秒
@export var residue_dps: float = 6.0
## 数据残留半径
@export var residue_radius: float = 60.0

# ============================================================
# 内部状态
# ============================================================
## 相位状态
var _is_phased_in: bool = true  # true=可见可攻击
var _phase_timer: float = 0.0

## 传送状态
var _teleport_timer: float = 0.0

## 攻击计时
var _attack_timer: float = 0.0

## 残影
var _afterimage_timer: float = 0.0

## 干扰网络
var _network_bonus: float = 1.0  # 附近幽灵数量加成

## 故障视觉
var _glitch_visual_timer: float = 0.0
var _original_alpha: float = 1.0

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.SCREECH
	max_hp = 180.0
	current_hp = 180.0
	move_speed = 55.0
	contact_damage = 14.0
	xp_value = 20
	
	quantized_fps = 6.0  # 低帧率增强故障感
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.3
	move_on_offbeat = true
	
	base_color = Color(0.0, 1.0, 0.8, 0.8)
	base_glitch_intensity = 0.2
	max_glitch_intensity = 1.0
	collision_radius = 18.0

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 相位切换
	_phase_timer += delta
	if _is_phased_in:
		if _phase_timer >= visible_duration:
			_phase_out()
	else:
		if _phase_timer >= phase_interval - visible_duration:
			_phase_in()
	
	# 故障传送
	_teleport_timer += delta
	if _teleport_timer >= teleport_interval and _is_phased_in:
		_teleport_timer = 0.0
		if randf() < 0.4:  # 40%概率传送
			_glitch_teleport()
	
	# 攻击（仅可见时）
	if _is_phased_in:
		_attack_timer += delta
		if _attack_timer >= attack_interval / _network_bonus:
			_attack_timer = 0.0
			_fire_interference()
	
	# 更新干扰网络加成
	_update_network_bonus()
	
	# 故障视觉
	_update_glitch_effect(delta)

func _phase_out() -> void:
	_is_phased_in = false
	_phase_timer = 0.0
	
	# 淡出动画
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate:a", 0.1, 0.3)
	
	# 禁用碰撞（免疫伤害）
	if _collision:
		_collision.set_deferred("disabled", true)

func _phase_in() -> void:
	_is_phased_in = true
	_phase_timer = 0.0
	
	# 淡入动画（带故障效果）
	if _sprite:
		var tween := create_tween()
		# 故障闪烁
		tween.tween_property(_sprite, "modulate:a", 1.0, 0.05)
		tween.tween_property(_sprite, "modulate:a", 0.3, 0.05)
		tween.tween_property(_sprite, "modulate:a", 0.9, 0.05)
		tween.tween_property(_sprite, "modulate:a", 0.5, 0.05)
		tween.tween_property(_sprite, "modulate:a", 1.0, 0.1)
	
	# 启用碰撞
	if _collision:
		_collision.set_deferred("disabled", false)
	
	# 出现时释放一次干扰脉冲
	_fire_phase_in_pulse()

func _fire_phase_in_pulse() -> void:
	# 出现时的脉冲波
	# OPT03: 攻击时触发音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(24):
		var angle := (TAU / 24) * i
		points.append(Vector2.from_angle(angle) * 5.0)
	ring.polygon = points
	ring.color = Color(0.0, 1.0, 0.8, 0.5)
	ring.global_position = global_position
	get_parent().add_child(ring)
	
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(15.0, 15.0), 0.3)
	tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.chain()
	tween.tween_callback(ring.queue_free)

func _glitch_teleport() -> void:
	# 留下残影
	_spawn_afterimage()
	
	# 随机短距传送
	var offset := Vector2.from_angle(randf() * TAU) * teleport_distance
	
	# 偏向玩家方向
	if _target and is_instance_valid(_target):
		var to_player := (_target.global_position - global_position).normalized()
		offset = offset.lerp(to_player * teleport_distance, 0.3)
	
	global_position += offset
	
	# 传送视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.05)
		tween.tween_property(_sprite, "modulate", base_color, 0.15)

func _spawn_afterimage() -> void:
	var afterimage := Polygon2D.new()
	afterimage.polygon = PackedVector2Array([
		Vector2(-12, -12), Vector2(12, -12), Vector2(12, 12), Vector2(-12, 12)
	])
	afterimage.color = Color(0.0, 0.8, 0.6, 0.4)
	afterimage.global_position = global_position
	get_parent().add_child(afterimage)
	
	var tween := afterimage.create_tween()
	tween.tween_property(afterimage, "modulate:a", 0.0, 0.5)
	tween.tween_callback(afterimage.queue_free)

func _update_network_bonus() -> void:
	# 检查附近的其他故障幽灵
	var nearby_count := 0
	var phantoms := get_tree().get_nodes_in_group("enemies")
	for enemy in phantoms:
		if enemy != self and is_instance_valid(enemy) and enemy is CharacterBody2D:
			if enemy.has_method("_get_type_name"):
				if enemy._get_type_name() == "ch7_glitch_phantom":
					if global_position.distance_to(enemy.global_position) < 200.0:
						nearby_count += 1
	
	_network_bonus = 1.0 + nearby_count * 0.3

func _update_glitch_effect(delta: float) -> void:
	_glitch_visual_timer += delta
	
	if _sprite and _is_phased_in:
		# 随机故障偏移
		if randf() < 0.15:
			_sprite.position = Vector2(
				randf_range(-4, 4), randf_range(-4, 4)
			)
		else:
			_sprite.position = _sprite.position.lerp(Vector2.ZERO, delta * 10.0)
		
		# 颜色故障
		if randf() < 0.05:
			_sprite.modulate = Color(
				randf_range(0.0, 1.0),
				randf_range(0.5, 1.0),
				randf_range(0.5, 1.0)
			)
		else:
			_sprite.modulate = _sprite.modulate.lerp(base_color, delta * 5.0)

# ============================================================
# 频率干扰弹幕
# ============================================================

func _fire_interference() -> void:
	if _is_dead or not _target or not is_instance_valid(_target):
		return
	
	# OPT03: 攻击时触发音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")
	var dir := (global_position.direction_to(_target.global_position)).angle()
	var damage := interference_damage * _network_bonus
	
	# 干扰弹幕：不规则方向
	var count := 2 + int(_network_bonus)
	for i in range(count):
		var angle := dir + randf_range(-0.4, 0.4)
		var speed := interference_speed * randf_range(0.8, 1.2)
		
		var proj := Area2D.new()
		proj.add_to_group("enemy_projectiles")
		
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 4.0
		col.shape = shape
		proj.add_child(col)
		
		# 故障形状弹幕
		var visual := Polygon2D.new()
		var point_count := randi_range(3, 5)
		var pts := PackedVector2Array()
		for p in range(point_count):
			var a := (TAU / point_count) * p + randf() * 0.3
			var r := randf_range(3.0, 6.0)
			pts.append(Vector2.from_angle(a) * r)
		visual.polygon = pts
		visual.color = Color(0.0, 1.0, 0.8, 0.8)
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
				body.take_damage(damage)
				proj.queue_free()
		)

# ============================================================
# 伤害处理（仅可见时受伤）
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	if not _is_phased_in:
		# 不可见时免疫，但显示"未命中"效果
		if _sprite:
			var tween := create_tween()
			tween.tween_property(_sprite, "modulate:a", 0.3, 0.05)
			tween.tween_property(_sprite, "modulate:a", 0.1, 0.05)
		return
	
	super.take_damage(amount, knockback_dir, is_perfect_beat)
	
	# 受击时有概率立即传送
	if randf() < 0.3 and not _is_dead:
		_glitch_teleport()

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	if not _is_phased_in:
		# 不可见时缓慢靠近玩家
		return (_target.global_position - global_position).normalized() * 0.5
	
	var dir := (_target.global_position - global_position)
	var dist := dir.length()
	
	# 保持中等距离
	if dist < 100.0:
		return -dir.normalized()
	elif dist > 250.0:
		return dir.normalized()
	else:
		# 环绕移动
		var perp := Vector2(-dir.y, dir.x).normalized()
		return perp * sign(sin(Time.get_ticks_msec() * 0.001))

# ============================================================
# 节拍回调
# ============================================================

func _on_beat(_beat_index: int) -> void:
	if _sprite and _is_phased_in:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.3, 1.3), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# 死亡时留下"数据残留"区域
	_spawn_data_residue()
	
	# 爆炸弹幕
	for i in range(8):
		var angle := (TAU / 8) * i + randf() * 0.3
		var proj := Area2D.new()
		proj.add_to_group("enemy_projectiles")
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 3.0
		col.shape = shape
		proj.add_child(col)
		var visual := Polygon2D.new()
		var pts := PackedVector2Array()
		for p in range(4):
			var a := (TAU / 4) * p
			pts.append(Vector2.from_angle(a) * 4.0)
		visual.polygon = pts
		visual.color = Color(0.0, 1.0, 0.8, 0.7)
		proj.add_child(visual)
		proj.global_position = global_position
		get_parent().add_child(proj)
		var vel := Vector2.from_angle(angle) * interference_speed * 0.5
		var tween := proj.create_tween()
		tween.tween_property(proj, "global_position",
			proj.global_position + vel * 2.0, 2.0)
		tween.tween_callback(proj.queue_free)

func _spawn_data_residue() -> void:
	var residue := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(24):
		var angle := (TAU / 24) * i
		var r := residue_radius + randf_range(-10, 10)
		points.append(Vector2.from_angle(angle) * r)
	residue.polygon = points
	residue.color = Color(0.0, 0.8, 0.6, 0.2)
	residue.global_position = global_position
	get_parent().add_child(residue)
	
	# 持续伤害
	var pos := global_position
	var elapsed := 0.0
	var damage_callable := func():
		if not is_instance_valid(residue):
			return
		elapsed += residue.get_process_delta_time()
		if elapsed >= residue_duration:
			residue.queue_free()
			return
		# 淡出
		residue.modulate.a = (1.0 - elapsed / residue_duration) * 0.3
		# 故障闪烁
		if randf() < 0.1:
			residue.modulate = Color(randf(), 1.0, randf(), residue.modulate.a)
		# 伤害检测
		var player := residue.get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			if player.global_position.distance_to(pos) < residue_radius:
				if player.has_method("take_damage"):
					player.take_damage(residue_dps * residue.get_process_delta_time())
	
	residue.set_process(true)
	residue.get_tree().process_frame.connect(damage_callable)
	residue.tree_exiting.connect(func():
		if residue.get_tree().process_frame.is_connected(damage_callable):
			residue.get_tree().process_frame.disconnect(damage_callable)
	)

func _get_type_name() -> String:
	return "ch7_glitch_phantom"
