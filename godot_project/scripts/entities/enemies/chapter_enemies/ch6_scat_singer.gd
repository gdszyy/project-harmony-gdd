## ch6_scat_singer.gd
## 第六章精英敌人：拟声歌者 (Scat Singer)
## 模仿爵士拟声唱法(Scat)的精英敌人，能即兴复制玩家的攻击模式。
## 音乐隐喻：爵士拟声唱法的即兴模仿与变奏。
## 机制：
## - 观察玩家最近使用的法术序列
## - 延迟一小段时间后"模仿"释放类似弹幕（变调版本）
## - 模仿的弹幕带有爵士特色的"摇摆"偏移
## - 被击中时会"即兴变奏"——随机改变自己的攻击模式
## - 高HP、中等速度，是需要策略应对的精英
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Scat Singer 专属配置
# ============================================================
## 模仿延迟时间
@export var mimic_delay: float = 1.5
## 模仿弹幕伤害倍率
@export var mimic_damage_mult: float = 0.7
## 模仿弹幕速度
@export var mimic_projectile_speed: float = 170.0
## 即兴变奏冷却
@export var improv_cooldown: float = 3.0
## 自主攻击间隔
@export var auto_attack_interval: float = 2.5
## 拟声弹幕数量
@export var scat_burst_count: int = 5

# ============================================================
# 内部状态
# ============================================================
## 模仿队列
var _mimic_queue: Array[Dictionary] = []  # {delay_timer, pattern_type, direction, count}
## 即兴变奏冷却
var _improv_timer: float = 0.0
## 自主攻击计时
var _auto_attack_timer: float = 0.0
## 当前即兴模式
var _current_improv: String = "straight"  # straight, swing, bebop
## 观察到的玩家模式
var _observed_patterns: Array[String] = []
var _observe_timer: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.PULSE
	max_hp = 200.0
	current_hp = 200.0
	move_speed = 70.0
	contact_damage = 15.0
	xp_value = 25
	
	quantized_fps = 10.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.4
	move_on_offbeat = true
	
	base_color = Color(0.8, 0.5, 0.2)
	base_glitch_intensity = 0.05
	max_glitch_intensity = 0.7
	collision_radius = 20.0

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 更新模仿队列
	_update_mimic_queue(delta)
	
	# 即兴变奏冷却
	if _improv_timer > 0.0:
		_improv_timer -= delta
	
	# 自主攻击
	_auto_attack_timer += delta
	if _auto_attack_timer >= auto_attack_interval:
		_auto_attack_timer = 0.0
		_perform_scat_attack()
	
	# 观察玩家（通过检测附近弹幕）
	_observe_timer += delta
	if _observe_timer >= 0.5:
		_observe_timer = 0.0
		_observe_player_patterns()

func _update_mimic_queue(delta: float) -> void:
	var to_execute: Array[int] = []
	
	for i in range(_mimic_queue.size()):
		_mimic_queue[i]["delay_timer"] -= delta
		if _mimic_queue[i]["delay_timer"] <= 0.0:
			to_execute.append(i)
	
	# 执行到期的模仿
	for i in range(to_execute.size() - 1, -1, -1):
		var pattern := _mimic_queue[to_execute[i]]
		_execute_mimic(pattern)
		_mimic_queue.remove_at(to_execute[i])

func _observe_player_patterns() -> void:
	# 检测玩家附近的弹幕类型
	var projectiles := get_tree().get_nodes_in_group("player_projectiles")
	for proj in projectiles:
		if is_instance_valid(proj):
			var dist := global_position.distance_to(proj.global_position)
			if dist < 200.0:
				# 记录弹幕类型用于模仿
				var proj_type := proj.get_meta("spell_form", "bolt") as String
				if not _observed_patterns.has(proj_type):
					_observed_patterns.append(proj_type)
					# 加入模仿队列
					_queue_mimic(proj_type, proj.global_position)
				# 限制观察数量
				if _observed_patterns.size() > 5:
					_observed_patterns.pop_front()

func _queue_mimic(pattern_type: String, source_pos: Vector2) -> void:
	var dir := Vector2.ZERO
	if _target and is_instance_valid(_target):
		dir = (global_position.direction_to(_target.global_position))
	
	_mimic_queue.append({
		"delay_timer": mimic_delay,
		"pattern_type": pattern_type,
		"direction": dir,
		"count": randi_range(2, 4),
	})

# ============================================================
# 模仿执行
# ============================================================

func _execute_mimic(pattern: Dictionary) -> void:
	if _is_dead:
		return
	
	var dir: Vector2 = pattern["direction"]
	if dir == Vector2.ZERO and _target and is_instance_valid(_target):
		dir = (global_position.direction_to(_target.global_position))
	
	var base_angle := dir.angle()
	var count: int = pattern["count"]
	var damage := contact_damage * mimic_damage_mult
	
	# 根据当前即兴模式添加变化
	match _current_improv:
		"straight":
			# 直接模仿
			for i in range(count):
				var offset = (float(i) / max(1, count - 1) - 0.5) * deg_to_rad(20.0)
				_spawn_scat_projectile(global_position, base_angle + offset,
					mimic_projectile_speed, damage)
		"swing":
			# 摇摆偏移
			for i in range(count):
				var delay := i * 0.15
				var swing_offset := (i % 2 * 2 - 1) * deg_to_rad(15.0)
				get_tree().create_timer(delay).timeout.connect(func():
					if _is_dead or not is_instance_valid(self):
						return
					_spawn_scat_projectile(global_position, base_angle + swing_offset,
						mimic_projectile_speed * 1.2, damage)
				)
		"bebop":
			# 快速连射 + 随机偏移
			for i in range(count + 2):
				var delay := i * 0.08
				get_tree().create_timer(delay).timeout.connect(func():
					if _is_dead or not is_instance_valid(self):
						return
					var random_offset := randf_range(-0.4, 0.4)
					_spawn_scat_projectile(global_position, base_angle + random_offset,
						mimic_projectile_speed * 1.5, damage * 0.6)
				)
	
	# 模仿视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.8, 0.3), 0.1)
		tween.tween_property(_sprite, "modulate", base_color, 0.3)

# ============================================================
# 自主拟声攻击
# ============================================================

func _perform_scat_attack() -> void:
	if _is_dead or not _target or not is_instance_valid(_target):
		return
	
	# OPT03: 攻击时触发音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")
	var dir := (global_position.direction_to(_target.global_position)).angle()
	var damage := contact_damage * 0.6
	
	# "Doo-ba-doo-bop" 节奏弹幕
	var scat_rhythm := [0.0, 0.15, 0.35, 0.45, 0.7]
	
	for i in range(min(scat_burst_count, scat_rhythm.size())):
		var delay = scat_rhythm[i]
		var angle_offset := (i % 2 * 2 - 1) * deg_to_rad(10.0 + i * 3.0)
		
		get_tree().create_timer(delay).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			_spawn_scat_projectile(global_position, dir + angle_offset,
				mimic_projectile_speed * 0.9, damage)
		)

# ============================================================
# 弹幕生成
# ============================================================

func _spawn_scat_projectile(pos: Vector2, angle: float, speed: float, damage: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("enemy_projectiles")
	proj.collision_layer = 8
	proj.collision_mask = 1
	
	# 音符形状（带有即兴感的不规则形状）
	var visual := Polygon2D.new()
	var size := randf_range(4.0, 7.0)
	visual.polygon = PackedVector2Array([
		Vector2(-size, -size * 0.5), Vector2(size, 0),
		Vector2(-size, size * 0.5)
	])
	visual.color = Color(0.9, 0.6, 0.2, 0.9)
	visual.rotation = angle
	proj.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	proj.add_child(col)
	
	proj.global_position = pos
	get_parent().add_child(proj)
	
	var vel := Vector2.from_angle(angle) * speed
	var lifetime := 4.0
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position",
		proj.global_position + vel * lifetime, lifetime)
	tween.tween_callback(proj.queue_free)
	
	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			proj.queue_free()
	)

# ============================================================
# 受击即兴变奏
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	super.take_damage(amount, knockback_dir, is_perfect_beat)
	
	# 受击时触发即兴变奏
	if _improv_timer <= 0.0 and not _is_dead:
		_improv_timer = improv_cooldown
		_improvise()

func _improvise() -> void:
	# 随机切换即兴模式
	var modes := ["straight", "swing", "bebop"]
	var old_mode := _current_improv
	while _current_improv == old_mode:
		_current_improv = modes[randi() % modes.size()]
	
	# 变奏视觉
	if _sprite:
		var tween := create_tween()
		match _current_improv:
			"straight":
				tween.tween_property(_sprite, "modulate", Color(0.8, 0.5, 0.2), 0.2)
			"swing":
				tween.tween_property(_sprite, "modulate", Color(0.6, 0.3, 0.8), 0.2)
			"bebop":
				tween.tween_property(_sprite, "modulate", Color(1.0, 0.3, 0.3), 0.2)
		tween.tween_property(_sprite, "modulate", base_color, 0.5)

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	var dir := (_target.global_position - global_position)
	var dist := dir.length()
	
	# 保持中等距离（像歌手在舞台上的走位）
	if dist < 120.0:
		return -dir.normalized()
	elif dist > 250.0:
		return dir.normalized()
	else:
		# 横向移动
		var perp := Vector2(-dir.y, dir.x).normalized()
		var sway := sin(Time.get_ticks_msec() * 0.002) 
		return perp * sway

# ============================================================
# 节拍回调
# ============================================================

func _on_beat(_beat_index: int) -> void:
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.2, 1.2), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

func _on_death_effect() -> void:
	# 死亡时释放最后的"即兴独奏"
	for i in range(8):
		var angle := (TAU / 8) * i + randf() * 0.3
		_spawn_scat_projectile(global_position, angle,
			mimic_projectile_speed * 0.6, contact_damage * 0.3)

func _get_type_name() -> String:
	return "ch6_scat_singer"
