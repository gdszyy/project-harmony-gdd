## boss_pythagoras.gd
## 第一章最终 Boss：律动尊者·毕达哥拉斯 (The First Resonator)
##
## 核心理念：宇宙初始和谐的具象化，一个位于场景中心、由多层旋转光环构成的
## 巨大几何体。它本身不进行移动，代表着一种绝对的、静态的完美。
##
## 时代特征：【绝对频率 (Absolute Frequency)】
## 通过震动战场生成克拉尼图形(Chladni Figures)，线条为致命伤害区域，
## 玩家必须站在"节点"安全区（对应纯律音程的整数频率比）。
##
## 风格排斥：惩罚无效输入（噪音惩罚）
## 三阶段：序曲(Prelude) → 共鸣(Resonance) → 天体乐章(Musica Universalis)
extends "res://scripts/entities/enemies/boss_base.gd"

# ============================================================
# 毕达哥拉斯专属常量
# ============================================================
## 克拉尼图形参数
const CHLADNI_DAMAGE_PER_SEC: float = 25.0
const CHLADNI_SAFE_RADIUS: float = 35.0
const CHLADNI_PATTERN_DURATION: float = 6.0
const CHLADNI_TRANSITION_TIME: float = 1.5

## 光环攻击参数
const RING_PROJECTILE_COUNT: int = 12
const RING_PROJECTILE_SPEED: float = 180.0
const RING_DAMAGE: float = 15.0

## 频率脉冲参数
const PULSE_RADIUS: float = 250.0
const PULSE_DAMAGE: float = 20.0

## 噪音惩罚参数
const NOISE_PUNISH_DAMAGE: float = 8.0
const NOISE_PUNISH_COOLDOWN: float = 3.0

## 天体轨道参数
const ORBIT_COUNT: int = 3
const ORBIT_SPEED_BASE: float = 1.2
const ORBIT_PROJECTILE_SPEED: float = 150.0

# ============================================================
# 内部状态
# ============================================================
## 弹幕容器
var _projectile_container: Node2D = null

## 克拉尼图形系统
var _chladni_active: bool = false
var _chladni_timer: float = 0.0
var _chladni_safe_points: Array[Vector2] = []
var _chladni_pattern_index: int = 0
var _chladni_visual_nodes: Array[Node2D] = []

## 光环旋转
var _ring_rotation_angles: Array[float] = [0.0, 0.0, 0.0]
var _ring_rotation_speeds: Array[float] = [0.5, -0.7, 0.3]

## 噪音惩罚冷却
var _noise_punish_timer: float = 0.0

## 天体轨道弹幕
var _orbit_angles: Array[float] = [0.0, 0.0, 0.0]

## 频率共振计数器
var _resonance_beat_counter: int = 0

# ============================================================
# Boss 初始化
# ============================================================

func _on_boss_ready() -> void:
	boss_name = "律动尊者"
	boss_title = "毕达哥拉斯 · The First Resonator"
	
	# 数值设定
	max_hp = 3000.0
	current_hp = 3000.0
	move_speed = 0.0  # 毕达哥拉斯不移动
	contact_damage = 20.0
	xp_value = 100
	
	# 狂暴时间
	enrage_time = 200.0
	
	# 共鸣碎片掉落
	resonance_fragment_drop = 50
	
	# 视觉
	base_color = Color(0.3, 0.4, 1.0)
	
	# 量化帧率（庄严、缓慢的威压）
	quantized_fps = 6.0
	_quantize_interval = 1.0 / quantized_fps
	
	# 极高击退抗性（不可移动）
	knockback_resistance = 1.0
	
	# 创建弹幕容器
	_projectile_container = Node2D.new()
	_projectile_container.name = "PythagorasProjectiles"
	add_child(_projectile_container)

# ============================================================
# 阶段定义
# ============================================================

func _define_phases() -> void:
	_phase_configs = [
		# 阶段一：序曲 (Prelude) — 简单的几何攻击
		{
			"name": "序曲 · Prelude",
			"hp_threshold": 1.0,
			"speed_mult": 1.0,
			"damage_mult": 1.0,
			"color": Color(0.3, 0.4, 1.0),
			"shield_hp": 200.0,
			"music_layer": "boss_pythagoras_prelude",
			"summon_enabled": false,
			"attack_selection": "sequence",
			"attacks": [
				{
					"name": "harmonic_rings",
					"duration": 2.0,
					"cooldown": 3.5,
					"damage": RING_DAMAGE,
					"weight": 3.0,
				},
				{
					"name": "chladni_pattern",
					"duration": CHLADNI_PATTERN_DURATION,
					"cooldown": 4.0,
					"damage": CHLADNI_DAMAGE_PER_SEC,
					"weight": 2.0,
				},
				{
					"name": "frequency_pulse",
					"duration": 1.0,
					"cooldown": 3.0,
					"damage": PULSE_DAMAGE,
					"weight": 2.5,
				},
			],
		},
		# 阶段二：共鸣 (Resonance) — 更复杂的图形 + 召唤
		{
			"name": "共鸣 · Resonance",
			"hp_threshold": 0.6,
			"speed_mult": 1.0,
			"damage_mult": 1.3,
			"color": Color(0.4, 0.3, 0.9),
			"shield_hp": 300.0,
			"music_layer": "boss_pythagoras_resonance",
			"summon_enabled": true,
			"summon_count": 4,
			"summon_type": "ch1_grid_static",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "harmonic_rings",
					"duration": 2.0,
					"cooldown": 2.5,
					"damage": RING_DAMAGE * 1.3,
					"weight": 2.0,
				},
				{
					"name": "chladni_pattern",
					"duration": CHLADNI_PATTERN_DURATION,
					"cooldown": 3.0,
					"damage": CHLADNI_DAMAGE_PER_SEC * 1.3,
					"weight": 3.0,
				},
				{
					"name": "frequency_pulse",
					"duration": 1.0,
					"cooldown": 2.5,
					"damage": PULSE_DAMAGE * 1.3,
					"weight": 2.0,
				},
				{
					"name": "ratio_cascade",
					"duration": 3.0,
					"cooldown": 4.0,
					"damage": RING_DAMAGE * 1.2,
					"weight": 2.5,
				},
			],
		},
		# 阶段三：天体乐章 (Musica Universalis) — 全力攻击
		{
			"name": "天体乐章 · Musica Universalis",
			"hp_threshold": 0.25,
			"speed_mult": 1.0,
			"damage_mult": 1.6,
			"color": Color(0.6, 0.2, 1.0),
			"shield_hp": 0.0,
			"music_layer": "boss_pythagoras_universalis",
			"summon_enabled": true,
			"summon_count": 6,
			"summon_type": "ch1_metronome_pulse",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "harmonic_rings",
					"duration": 2.0,
					"cooldown": 2.0,
					"damage": RING_DAMAGE * 1.6,
					"weight": 2.0,
				},
				{
					"name": "chladni_pattern",
					"duration": CHLADNI_PATTERN_DURATION,
					"cooldown": 2.5,
					"damage": CHLADNI_DAMAGE_PER_SEC * 1.6,
					"weight": 2.5,
				},
				{
					"name": "celestial_orbits",
					"duration": 4.0,
					"cooldown": 3.0,
					"damage": ORBIT_PROJECTILE_SPEED,
					"weight": 3.0,
				},
				{
					"name": "ratio_cascade",
					"duration": 3.0,
					"cooldown": 3.0,
					"damage": RING_DAMAGE * 1.5,
					"weight": 2.0,
				},
				{
					"name": "universal_resonance",
					"duration": 5.0,
					"cooldown": 5.0,
					"damage": PULSE_DAMAGE * 2.0,
					"weight": 1.5,
				},
			],
		},
	]

# ============================================================
# Boss 每帧逻辑
# ============================================================

func _on_boss_process(delta: float) -> void:
	# 更新光环旋转
	for i in range(_ring_rotation_angles.size()):
		_ring_rotation_angles[i] += _ring_rotation_speeds[i] * delta
	
	# 更新克拉尼图形
	if _chladni_active:
		_update_chladni(delta)
	
	# 更新噪音惩罚冷却
	if _noise_punish_timer > 0.0:
		_noise_punish_timer -= delta
	
	# 更新天体轨道
	for i in range(_orbit_angles.size()):
		_orbit_angles[i] += ORBIT_SPEED_BASE * (1.0 + i * 0.3) * delta
	
	# 光环视觉
	if _sprite:
		_sprite.rotation = _ring_rotation_angles[0]

# ============================================================
# 攻击实现
# ============================================================

func _perform_attack(attack: Dictionary) -> void:
	var config: Dictionary = _phase_configs[_current_phase] if _current_phase < _phase_configs.size() else {}
	var damage_mult: float = config.get("damage_mult", 1.0)
	
	match attack["name"]:
		"harmonic_rings":
			_attack_harmonic_rings(attack, damage_mult)
		"chladni_pattern":
			_attack_chladni_pattern(attack, damage_mult)
		"frequency_pulse":
			_attack_frequency_pulse(attack, damage_mult)
		"ratio_cascade":
			_attack_ratio_cascade(attack, damage_mult)
		"celestial_orbits":
			_attack_celestial_orbits(attack, damage_mult)
		"universal_resonance":
			_attack_universal_resonance(attack, damage_mult)

# ============================================================
# 攻击1：和谐光环 (Harmonic Rings)
# 从中心向外扩散的同心圆弹幕环
# ============================================================

func _attack_harmonic_rings(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", RING_DAMAGE) * damage_mult
	var waves := 3
	var interval := 0.5
	
	for wave in range(waves):
		get_tree().create_timer(wave * interval).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			var count := RING_PROJECTILE_COUNT + wave * 2
			var offset := _ring_rotation_angles[0] + wave * 0.2
			for i in range(count):
				var angle := (TAU / count) * i + offset
				_spawn_boss_projectile(global_position, angle,
					RING_PROJECTILE_SPEED + wave * 30.0, damage)
		)
	
	# 视觉：光环膨胀
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.8, 1.8), 0.2)
		tween.tween_property(_sprite, "modulate", Color(0.5, 0.6, 1.0), 0.2)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.5)
		tween.tween_property(_sprite, "modulate", base_color, 0.5)

# ============================================================
# 攻击2：克拉尼图形 (Chladni Pattern)
# 在地面生成致命的振动图形，玩家需站在安全节点
# ============================================================

func _attack_chladni_pattern(attack: Dictionary, damage_mult: float) -> void:
	_chladni_active = true
	_chladni_timer = CHLADNI_PATTERN_DURATION
	_chladni_pattern_index = (_chladni_pattern_index + 1) % 4
	
	# 生成安全节点（基于纯律音程比例）
	_generate_chladni_safe_points()
	
	# 创建克拉尼图形视觉
	_spawn_chladni_visual(damage_mult)

func _generate_chladni_safe_points() -> void:
	_chladni_safe_points.clear()
	
	# 安全节点基于纯律比例分布在Boss周围
	# 八度(2:1), 五度(3:2), 四度(4:3)
	var ratios := [
		{"distance": 80.0, "count": 2},   # 八度：2个节点
		{"distance": 150.0, "count": 3},   # 五度：3个节点
		{"distance": 220.0, "count": 4},   # 四度：4个节点
	]
	
	var pattern_offset := _chladni_pattern_index * PI / 4.0
	
	for ratio in ratios:
		var dist: float = ratio["distance"]
		var count: int = ratio["count"]
		for i in range(count):
			var angle := (TAU / count) * i + pattern_offset
			var safe_pos := global_position + Vector2.from_angle(angle) * dist
			_chladni_safe_points.append(safe_pos)

func _spawn_chladni_visual(damage_mult: float) -> void:
	# 清理旧的视觉节点
	for node in _chladni_visual_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_chladni_visual_nodes.clear()
	
	# 生成危险区域视觉（同心环形线条）
	var danger_visual := Node2D.new()
	danger_visual.global_position = global_position
	get_parent().add_child(danger_visual)
	_chladni_visual_nodes.append(danger_visual)
	
	# 绘制多层同心环（代表克拉尼图形的振动线条）
	for ring_idx in range(5):
		var ring := Polygon2D.new()
		var points := PackedVector2Array()
		var radius := 60.0 + ring_idx * 50.0
		var segments := 32
		for i in range(segments):
			var angle := (TAU / segments) * i
			# 添加波纹变形（模拟克拉尼图形的复杂线条）
			var wave := sin(angle * (ring_idx + 2) + _chladni_pattern_index) * 15.0
			points.append(Vector2.from_angle(angle) * (radius + wave))
		ring.polygon = points
		ring.color = Color(0.8, 0.3, 0.2, 0.35)
		danger_visual.add_child(ring)
	
	# 生成安全节点视觉（发光的圆形区域）
	for safe_pos in _chladni_safe_points:
		var safe_visual := Polygon2D.new()
		var points := PackedVector2Array()
		for i in range(16):
			var angle := (TAU / 16) * i
			points.append(Vector2.from_angle(angle) * CHLADNI_SAFE_RADIUS)
		safe_visual.polygon = points
		safe_visual.color = Color(0.2, 0.8, 1.0, 0.3)
		safe_visual.global_position = safe_pos
		get_parent().add_child(safe_visual)
		_chladni_visual_nodes.append(safe_visual)
		
		# 安全区脉冲动画
		var tween := safe_visual.create_tween().set_loops()
		tween.tween_property(safe_visual, "modulate:a", 0.6, 0.5)
		tween.tween_property(safe_visual, "modulate:a", 0.3, 0.5)
	
	# 预警动画：先淡入
	var fade_tween := danger_visual.create_tween()
	danger_visual.modulate.a = 0.0
	fade_tween.tween_property(danger_visual, "modulate:a", 1.0, CHLADNI_TRANSITION_TIME)

func _update_chladni(delta: float) -> void:
	_chladni_timer -= delta
	
	if _chladni_timer <= 0.0:
		# 结束克拉尼图形
		_chladni_active = false
		for node in _chladni_visual_nodes:
			if is_instance_valid(node):
				var tween := node.create_tween()
				tween.tween_property(node, "modulate:a", 0.0, 0.5)
				tween.tween_callback(node.queue_free)
		_chladni_visual_nodes.clear()
		return
	
	# 检测玩家是否在安全区内
	if _target and is_instance_valid(_target):
		var player_pos := _target.global_position
		var in_safe_zone := false
		
		for safe_pos in _chladni_safe_points:
			if player_pos.distance_to(safe_pos) < CHLADNI_SAFE_RADIUS:
				in_safe_zone = true
				break
		
		# 不在安全区则持续受到伤害
		if not in_safe_zone:
			var config: Dictionary = _phase_configs[_current_phase] if _current_phase < _phase_configs.size() else {}
			var damage_mult: float = config.get("damage_mult", 1.0)
			if _target.has_method("take_damage"):
				_target.take_damage(CHLADNI_DAMAGE_PER_SEC * damage_mult * delta)

# ============================================================
# 攻击3：频率脉冲 (Frequency Pulse)
# 从中心释放扩散的冲击波
# ============================================================

func _attack_frequency_pulse(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", PULSE_DAMAGE) * damage_mult
	
	# 蓄力
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(2.5, 2.5), 0.5)
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.3)
		tween.tween_callback(func():
			if _is_dead:
				return
			# 释放冲击波
			_spawn_shockwave(global_position, PULSE_RADIUS, damage)
			# 同时释放环形弹幕
			for i in range(8):
				var angle := (TAU / 8) * i
				_spawn_boss_projectile(global_position, angle,
					RING_PROJECTILE_SPEED * 0.8, damage * 0.4)
		)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.3)
		tween.tween_property(_sprite, "modulate", base_color, 0.3)

# ============================================================
# 攻击4：比例级联 (Ratio Cascade)
# 以纯律比例（2:1, 3:2, 4:3）发射多轮弹幕
# ============================================================

func _attack_ratio_cascade(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", RING_DAMAGE) * damage_mult
	
	# 三轮弹幕，对应三种纯律比例
	var ratio_configs := [
		{"count": 8, "speed_mult": 1.0, "delay": 0.0},    # 八度 2:1
		{"count": 6, "speed_mult": 0.75, "delay": 0.8},   # 五度 3:2
		{"count": 4, "speed_mult": 0.5, "delay": 1.6},    # 四度 4:3
	]
	
	for config in ratio_configs:
		var delay: float = config["delay"]
		var count: int = config["count"]
		var speed_mult: float = config["speed_mult"]
		
		get_tree().create_timer(delay).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			
			var base_angle := 0.0
			if _target:
				base_angle = (global_position.direction_to(_target.global_position)).angle()
			
			for i in range(count):
				var angle := (TAU / count) * i + base_angle
				_spawn_boss_projectile(global_position, angle,
					RING_PROJECTILE_SPEED * speed_mult, damage)
			
			# 视觉脉冲
			if _sprite:
				var tween := create_tween()
				tween.tween_property(_sprite, "scale", Vector2(1.4, 1.4), 0.08)
				tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.15)
		)

# ============================================================
# 攻击5：天体轨道 (Celestial Orbits) — 第三阶段专属
# 多条旋转弹幕轨道，模拟行星运动
# ============================================================

func _attack_celestial_orbits(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", 12.0) * damage_mult
	var duration := 4.0
	var interval := 0.2
	var total_waves := int(duration / interval)
	
	for wave in range(total_waves):
		get_tree().create_timer(wave * interval).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			
			# 三条轨道同时发射
			for orbit in range(ORBIT_COUNT):
				_orbit_angles[orbit] += 0.15
				var orbit_radius := 50.0 + orbit * 40.0
				var orbit_pos := global_position + Vector2.from_angle(_orbit_angles[orbit]) * orbit_radius
				
				# 从轨道位置向外发射弹幕
				var outward_angle := _orbit_angles[orbit] + PI / 2.0
				_spawn_boss_projectile(orbit_pos, outward_angle,
					ORBIT_PROJECTILE_SPEED, damage * 0.6)
		)

# ============================================================
# 攻击6：宇宙共鸣 (Universal Resonance) — 第三阶段终极攻击
# 全屏振动 + 克拉尼图形 + 环形弹幕的组合攻击
# ============================================================

func _attack_universal_resonance(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", PULSE_DAMAGE * 2.0) * damage_mult
	
	# 先激活克拉尼图形
	_chladni_active = true
	_chladni_timer = 5.0
	_chladni_pattern_index = (_chladni_pattern_index + 1) % 4
	_generate_chladni_safe_points()
	_spawn_chladni_visual(damage_mult)
	
	# 同时释放多轮环形弹幕
	for wave in range(4):
		get_tree().create_timer(wave * 1.0).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			# 冲击波
			_spawn_shockwave(global_position, PULSE_RADIUS * (1.0 + wave * 0.2), damage * 0.3)
			# 环形弹幕
			var count := RING_PROJECTILE_COUNT + wave * 3
			for i in range(count):
				var angle := (TAU / count) * i + wave * 0.15
				_spawn_boss_projectile(global_position, angle,
					RING_PROJECTILE_SPEED * (0.8 + wave * 0.1), damage * 0.2)
		)

# ============================================================
# 噪音惩罚系统
# 当玩家进行无效输入时触发
# ============================================================

func trigger_noise_punishment() -> void:
	if _noise_punish_timer > 0.0:
		return
	
	_noise_punish_timer = NOISE_PUNISH_COOLDOWN
	
	# 全屏微弱伤害
	if _target and is_instance_valid(_target):
		if _target.has_method("take_damage"):
			_target.take_damage(NOISE_PUNISH_DAMAGE)
	
	# 增加疲劳
	if FatigueManager and FatigueManager.has_method("add_external_fatigue"):
		FatigueManager.add_external_fatigue(0.1)
	
	# "亵渎！" 视觉效果
	_spawn_blasphemy_visual()

func _spawn_blasphemy_visual() -> void:
	# 全屏闪红
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.0, 0.0), 0.1)
		tween.tween_property(_sprite, "modulate", base_color, 0.5)

# ============================================================
# Boss 弹幕生成
# ============================================================

func _spawn_boss_projectile(pos: Vector2, angle: float, speed: float, damage: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	proj.collision_layer = 8
	proj.collision_mask = 1
	
	# 视觉：几何形状（三角/菱形）
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-4, -4), Vector2(8, 0), Vector2(-4, 4)
	])
	visual.color = base_color.lerp(Color.WHITE, 0.3)
	visual.rotation = angle
	proj.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	proj.add_child(col)
	
	proj.global_position = pos
	proj.set_meta("velocity", Vector2.from_angle(angle) * speed)
	proj.set_meta("damage", damage)
	proj.set_meta("lifetime", 6.0)
	proj.set_meta("age", 0.0)
	
	if _projectile_container and is_instance_valid(_projectile_container):
		_projectile_container.add_child(proj)
	else:
		get_parent().add_child(proj)
	
	var move_callable := func():
		if not is_instance_valid(proj):
			return
		var vel: Vector2 = proj.get_meta("velocity")
		proj.global_position += vel * get_process_delta_time()
		var age: float = proj.get_meta("age") + get_process_delta_time()
		proj.set_meta("age", age)
		if age >= proj.get_meta("lifetime"):
			proj.queue_free()
			return
		if _target and is_instance_valid(_target):
			var dist := proj.global_position.distance_to(_target.global_position)
			if dist < 18.0:
				if _target.has_method("take_damage"):
					_target.take_damage(proj.get_meta("damage"))
				proj.queue_free()
	
	get_tree().process_frame.connect(move_callable)
	proj.tree_exiting.connect(func():
		if get_tree().process_frame.is_connected(move_callable):
			get_tree().process_frame.disconnect(move_callable)
	)

# ============================================================
# 冲击波生成
# ============================================================

func _spawn_shockwave(pos: Vector2, radius: float, damage: float) -> void:
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(32):
		var angle := (TAU / 32) * i
		points.append(Vector2.from_angle(angle) * 10.0)
	ring.polygon = points
	ring.color = base_color
	ring.global_position = pos
	get_parent().add_child(ring)
	
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(radius / 10.0, radius / 10.0), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.chain()
	tween.tween_callback(ring.queue_free)
	
	if _target and is_instance_valid(_target):
		var dist := pos.distance_to(_target.global_position)
		if dist < radius:
			if _target.has_method("take_damage"):
				_target.take_damage(damage)

# ============================================================
# 阶段进入回调
# ============================================================

func _on_phase_entered(phase_index: int, _config: Dictionary) -> void:
	match phase_index:
		0:
			pass
		1:
			# 共鸣阶段：光环旋转加速
			_ring_rotation_speeds = [0.8, -1.0, 0.5]
			_summon_cooldown_time = 12.0
		2:
			# 天体乐章：全力模式
			_ring_rotation_speeds = [1.2, -1.5, 0.8]
			_summon_cooldown_time = 10.0
			# 清除所有现有弹幕
			if _projectile_container:
				for child in _projectile_container.get_children():
					child.queue_free()

# ============================================================
# 狂暴回调
# ============================================================

func _on_enrage(level: int) -> void:
	match level:
		1:
			# 轻度狂暴：弹幕加速
			_ring_rotation_speeds = [1.5, -2.0, 1.0]
			base_color = base_color.lerp(Color(1.0, 0.3, 0.0), 0.3)
		2:
			# 完全狂暴：持续释放弹幕
			base_color = Color(1.0, 0.0, 0.0)
			_start_enrage_barrage()

func _start_enrage_barrage() -> void:
	get_tree().create_timer(0.8).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			return
		for i in range(RING_PROJECTILE_COUNT):
			var angle := (TAU / RING_PROJECTILE_COUNT) * i + _ring_rotation_angles[0]
			_spawn_boss_projectile(global_position, angle,
				RING_PROJECTILE_SPEED * 0.6, 10.0)
		if _enrage_level >= 2 and not _is_dead:
			_start_enrage_barrage()
	)

# ============================================================
# 节拍回调
# ============================================================

func _on_boss_beat(_beat_index: int) -> void:
	_resonance_beat_counter += 1
	
	# 每 4 拍在非攻击状态时发射一次弹幕
	if not _is_attacking and _resonance_beat_counter % 4 == 0:
		if _target and not _is_dead:
			var angle := (_target.global_position - global_position).angle()
			_spawn_boss_projectile(global_position, angle,
				RING_PROJECTILE_SPEED * 0.5, 8.0)

# ============================================================
# 移动逻辑（毕达哥拉斯不移动）
# ============================================================

func _calculate_movement_direction() -> Vector2:
	return Vector2.ZERO

# ============================================================
# 类型名称
# ============================================================

func _get_type_name() -> String:
	return "boss_pythagoras"

# ============================================================
# 清理
# ============================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# 清理弹幕
		if _projectile_container and is_instance_valid(_projectile_container):
			for child in _projectile_container.get_children():
				if is_instance_valid(child):
					child.queue_free()
		# 清理克拉尼视觉
		for node in _chladni_visual_nodes:
			if is_instance_valid(node):
				node.queue_free()
