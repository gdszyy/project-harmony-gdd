## boss_dissonant_conductor.gd
## "失谐指挥家" (The Dissonant Conductor) — 第一个 Boss (Issue #27)
##
## 设计概念：
## 一位曾经伟大的指挥家，被不和谐的力量吞噬，
## 现在他指挥着一支由噪音和故障组成的"交响乐团"。
## 他的攻击模式模拟了一场失控的音乐会。
##
## 三个阶段（乐章）：
## 1. "序曲" (Overture) — HP 100%~60%：有序的指挥棒攻击
## 2. "变奏" (Variation) — HP 60%~25%：混乱的弹幕 + 召唤小兵
## 3. "终章" (Finale) — HP 25%~0%：狂暴的全屏攻击
##
## 音乐集成：
## - 每个阶段切换时触发 BGM 层变化
## - 攻击节奏与 BPM 同步
## - 特定攻击在节拍点触发
extends "res://scripts/entities/enemies/boss_base.gd"

# ============================================================
# Boss 配置
# ============================================================
const BATON_PROJECTILE_SPEED: float = 250.0
const BATON_PROJECTILE_DAMAGE: float = 15.0
const SHOCKWAVE_RADIUS: float = 200.0
const SHOCKWAVE_DAMAGE: float = 20.0
const CRESCENDO_RING_COUNT: int = 3
const CRESCENDO_RING_SPEED: float = 180.0
const FINALE_BULLET_COUNT: int = 24

# ============================================================
# 内部状态
# ============================================================
## 指挥棒旋转角度
var _baton_angle: float = 0.0
## 弹幕计数器
var _barrage_count: int = 0
## 终章弹幕角度偏移
var _finale_angle_offset: float = 0.0
## 当前攻击的弹幕容器
var _projectile_container: Node2D = null

# ============================================================
# 初始化
# ============================================================

func _on_boss_ready() -> void:
	boss_name = "失谐指挥家"
	boss_title = "The Dissonant Conductor"
	
	# Boss 基础属性
	max_hp = 5000.0
	current_hp = max_hp
	move_speed = 60.0
	contact_damage = 25.0
	xp_value = 200
	collision_radius = 32.0
	detection_range = 1200.0
	enrage_time = 180.0
	resonance_fragment_drop = 50
	
	# 视觉
	base_color = Color(0.8, 0.2, 0.9)  # 紫色主题
	
	# 创建弹幕容器
	_projectile_container = Node2D.new()
	_projectile_container.name = "BossProjectiles"
	add_child(_projectile_container)

# ============================================================
# 阶段定义
# ============================================================

func _define_phases() -> void:
	_phase_configs = [
		# 阶段1：序曲 (Overture) — 有序的指挥棒攻击
		{
			"name": "序曲 · Overture",
			"hp_threshold": 1.0,  # 初始阶段
			"speed_mult": 1.0,
			"damage_mult": 1.0,
			"color": Color(0.8, 0.2, 0.9),  # 紫色
			"music_layer": "boss_phase_1",
			"shield_hp": 0.0,
			"summon_enabled": false,
			"attack_selection": "sequence",
			"attacks": [
				{
					"name": "baton_sweep",
					"description": "指挥棒横扫 — 扇形弹幕",
					"duration": 1.5,
					"cooldown": 3.0,
					"weight": 1.0,
					"damage": 12.0,
				},
				{
					"name": "tempo_strike",
					"description": "节拍打击 — 在节拍点发射定向弹幕",
					"duration": 2.0,
					"cooldown": 2.5,
					"weight": 1.0,
					"damage": 15.0,
				},
				{
					"name": "rest_note",
					"description": "休止符 — 短暂停顿后突然冲刺",
					"duration": 1.0,
					"cooldown": 4.0,
					"weight": 0.5,
					"damage": 20.0,
				},
			],
		},
		# 阶段2：变奏 (Variation) — 混乱弹幕 + 召唤
		{
			"name": "变奏 · Variation",
			"hp_threshold": 0.6,
			"speed_mult": 1.3,
			"damage_mult": 1.3,
			"color": Color(1.0, 0.4, 0.2),  # 橙红色
			"music_layer": "boss_phase_2",
			"shield_hp": 500.0,
			"summon_enabled": true,
			"summon_count": 4,
			"summon_type": "static",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "dissonant_chord",
					"description": "不和谐和弦 — 多方向同时弹幕",
					"duration": 2.0,
					"cooldown": 2.0,
					"weight": 1.5,
					"damage": 18.0,
				},
				{
					"name": "crescendo_rings",
					"description": "渐强环 — 扩散的同心圆弹幕",
					"duration": 2.5,
					"cooldown": 3.0,
					"weight": 1.0,
					"damage": 15.0,
				},
				{
					"name": "summon_orchestra",
					"description": "召唤乐团 — 召唤小兵并短暂护盾",
					"duration": 1.5,
					"cooldown": 8.0,
					"weight": 0.5,
					"damage": 0.0,
				},
				{
					"name": "tempo_strike",
					"description": "节拍打击（强化版）",
					"duration": 2.0,
					"cooldown": 2.0,
					"weight": 1.0,
					"damage": 20.0,
				},
			],
		},
		# 阶段3：终章 (Finale) — 狂暴全屏攻击
		{
			"name": "终章 · Finale",
			"hp_threshold": 0.25,
			"speed_mult": 1.6,
			"damage_mult": 1.8,
			"color": Color(1.0, 0.1, 0.1),  # 血红色
			"music_layer": "boss_phase_3",
			"shield_hp": 0.0,
			"summon_enabled": true,
			"summon_count": 6,
			"summon_type": "screech",
			"attack_selection": "sequence",
			"attacks": [
				{
					"name": "finale_barrage",
					"description": "终章弹幕 — 全方位旋转弹幕",
					"duration": 3.0,
					"cooldown": 1.5,
					"weight": 1.5,
					"damage": 20.0,
				},
				{
					"name": "cacophony_blast",
					"description": "噪音冲击波 — 大范围 AOE",
					"duration": 1.5,
					"cooldown": 2.0,
					"weight": 1.0,
					"damage": 30.0,
				},
				{
					"name": "dissonant_chord",
					"description": "不和谐和弦（终章版）",
					"duration": 2.0,
					"cooldown": 1.5,
					"weight": 1.0,
					"damage": 25.0,
				},
				{
					"name": "silence_zone",
					"description": "寂静领域 — 在玩家周围创建减速区",
					"duration": 2.0,
					"cooldown": 5.0,
					"weight": 0.8,
					"damage": 10.0,
				},
			],
		},
	]

# ============================================================
# 攻击实现
# ============================================================

func _perform_attack(attack: Dictionary) -> void:
	var attack_name: String = attack.get("name", "")
	var damage_mult: float = _phase_configs[_current_phase].get("damage_mult", 1.0)
	
	match attack_name:
		"baton_sweep":
			_attack_baton_sweep(attack, damage_mult)
		"tempo_strike":
			_attack_tempo_strike(attack, damage_mult)
		"rest_note":
			_attack_rest_note(attack, damage_mult)
		"dissonant_chord":
			_attack_dissonant_chord(attack, damage_mult)
		"crescendo_rings":
			_attack_crescendo_rings(attack, damage_mult)
		"summon_orchestra":
			_attack_summon_orchestra(attack)
		"finale_barrage":
			_attack_finale_barrage(attack, damage_mult)
		"cacophony_blast":
			_attack_cacophony_blast(attack, damage_mult)
		"silence_zone":
			_attack_silence_zone(attack, damage_mult)

# ============================================================
# 攻击1：指挥棒横扫 (Baton Sweep)
# 扇形弹幕，模拟指挥棒的挥动
# ============================================================

func _attack_baton_sweep(attack: Dictionary, damage_mult: float) -> void:
	if _target == null:
		return
	
	var base_angle := ((_target.global_position - global_position).angle())
	var spread := PI / 3.0  # 60度扇形
	var bullet_count := 7
	var damage: float = attack.get("damage", 12.0) * damage_mult
	
	# 分三波发射，模拟挥棒动作
	for wave in range(3):
		get_tree().create_timer(wave * 0.2).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			var wave_angle := base_angle + (wave - 1) * 0.15
			for i in range(bullet_count):
				var angle := wave_angle - spread / 2.0 + (spread / (bullet_count - 1)) * i
				_spawn_boss_projectile(global_position, angle, BATON_PROJECTILE_SPEED, damage)
		)

# ============================================================
# 攻击2：节拍打击 (Tempo Strike)
# 在节拍点发射精准弹幕
# ============================================================

func _attack_tempo_strike(attack: Dictionary, damage_mult: float) -> void:
	if _target == null:
		return
	
	var damage: float = attack.get("damage", 15.0) * damage_mult
	var beat_interval := 60.0 / max(GameManager.current_bpm, 60.0)
	
	# 在接下来的 4 个节拍点各发射一组弹幕
	for beat in range(4):
		get_tree().create_timer(beat * beat_interval).timeout.connect(func():
			if _is_dead or not is_instance_valid(self) or _target == null:
				return
			# 每个节拍发射 3 发追踪弹
			var base_angle := (_target.global_position - global_position).angle()
			for i in range(3):
				var offset_angle := base_angle + (i - 1) * 0.2
				_spawn_boss_projectile(global_position, offset_angle, 
					BATON_PROJECTILE_SPEED * 1.2, damage)
		)

# ============================================================
# 攻击3：休止符 (Rest Note)
# 短暂停顿后突然冲刺向玩家
# ============================================================

func _attack_rest_note(attack: Dictionary, damage_mult: float) -> void:
	if _target == null:
		return
	
	# 视觉预警：收缩
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(0.5, 0.5), 0.3)
		tween.tween_callback(func():
			if _is_dead or _target == null:
				return
			# 冲刺
			var dir := (_target.global_position - global_position).normalized()
			velocity = dir * move_speed * 8.0
			move_and_slide()
			
			# 冲刺后的冲击波
			_spawn_shockwave(global_position, SHOCKWAVE_RADIUS, 
				attack.get("damage", 20.0) * damage_mult)
		)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.2)

# ============================================================
# 攻击4：不和谐和弦 (Dissonant Chord)
# 多方向同时弹幕
# ============================================================

func _attack_dissonant_chord(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", 18.0) * damage_mult
	
	# 发射 8 方向 + 4 对角方向的弹幕
	var directions := 12
	for i in range(directions):
		var angle := (TAU / directions) * i
		_spawn_boss_projectile(global_position, angle, BATON_PROJECTILE_SPEED * 0.8, damage)
	
	# 延迟后再发射一轮偏移弹幕
	get_tree().create_timer(0.5).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			return
		for i in range(directions):
			var angle := (TAU / directions) * i + TAU / (directions * 2)
			_spawn_boss_projectile(global_position, angle, 
				BATON_PROJECTILE_SPEED * 0.6, damage * 0.8)
	)

# ============================================================
# 攻击5：渐强环 (Crescendo Rings)
# 扩散的同心圆弹幕
# ============================================================

func _attack_crescendo_rings(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", 15.0) * damage_mult
	
	for ring in range(CRESCENDO_RING_COUNT):
		get_tree().create_timer(ring * 0.6).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			var bullet_count := 16 + ring * 4  # 每环递增
			var speed := CRESCENDO_RING_SPEED + ring * 30.0  # 每环加速
			for i in range(bullet_count):
				var angle := (TAU / bullet_count) * i
				_spawn_boss_projectile(global_position, angle, speed, 
					damage * (1.0 + ring * 0.2))
		)

# ============================================================
# 攻击6：召唤乐团 (Summon Orchestra)
# 召唤小兵并获得短暂护盾
# ============================================================

func _attack_summon_orchestra(attack: Dictionary) -> void:
	# 召唤动画
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 0.5), 0.2)
		tween.tween_property(_sprite, "modulate", base_color, 0.5)
	
	# 触发小兵召唤
	_spawn_minions()
	
	# 短暂护盾
	_shield_hp = 200.0
	_max_shield_hp = max(_max_shield_hp, 200.0)
	_shield_active = true

# ============================================================
# 攻击7：终章弹幕 (Finale Barrage)
# 全方位旋转弹幕
# ============================================================

func _attack_finale_barrage(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", 20.0) * damage_mult
	var duration := attack.get("duration", 3.0)
	var interval := 0.15  # 每 0.15 秒发射一轮
	var total_waves := int(duration / interval)
	
	for wave in range(total_waves):
		get_tree().create_timer(wave * interval).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			_finale_angle_offset += 0.2  # 每轮旋转
			for i in range(FINALE_BULLET_COUNT / 4):
				var angle := (TAU / (FINALE_BULLET_COUNT / 4)) * i + _finale_angle_offset
				_spawn_boss_projectile(global_position, angle, 
					BATON_PROJECTILE_SPEED * 1.1, damage)
		)

# ============================================================
# 攻击8：噪音冲击波 (Cacophony Blast)
# 大范围 AOE
# ============================================================

func _attack_cacophony_blast(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", 30.0) * damage_mult
	
	# 蓄力动画
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(2.5, 2.5), 0.8)
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.2)
		tween.tween_callback(func():
			if _is_dead:
				return
			# 释放冲击波
			_spawn_shockwave(global_position, SHOCKWAVE_RADIUS * 2.0, damage)
			# 同时发射环形弹幕
			for i in range(20):
				var angle := (TAU / 20) * i
				_spawn_boss_projectile(global_position, angle, 
					BATON_PROJECTILE_SPEED * 1.5, damage * 0.5)
		)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.3)

# ============================================================
# 攻击9：寂静领域 (Silence Zone)
# 在玩家周围创建减速区
# ============================================================

func _attack_silence_zone(attack: Dictionary, damage_mult: float) -> void:
	if _target == null:
		return
	
	var damage: float = attack.get("damage", 10.0) * damage_mult
	var zone_pos := _target.global_position
	
	# 创建寂静区域视觉
	var zone := Area2D.new()
	zone.global_position = zone_pos
	
	var visual := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(24):
		var angle := (TAU / 24) * i
		points.append(Vector2.from_angle(angle) * 120.0)
	visual.polygon = points
	visual.color = Color(0.1, 0.0, 0.2, 0.4)
	zone.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 120.0
	col.shape = shape
	zone.add_child(col)
	
	zone.collision_layer = 8
	zone.collision_mask = 1
	
	get_parent().add_child(zone)
	
	# 区域持续 4 秒
	var zone_duration := 4.0
	var zone_tween := zone.create_tween()
	zone_tween.tween_property(visual, "color:a", 0.6, 0.3)
	zone_tween.tween_interval(zone_duration - 0.6)
	zone_tween.tween_property(visual, "color:a", 0.0, 0.3)
	zone_tween.tween_callback(zone.queue_free)
	
	# 持续伤害（通过 process_frame）
	var tick_timer := 0.0
	var tick_interval := 0.5
	var callable := func():
		if not is_instance_valid(zone) or _target == null or not is_instance_valid(_target):
			return
		tick_timer += get_process_delta_time()
		if tick_timer >= tick_interval:
			tick_timer = 0.0
			var dist := zone_pos.distance_to(_target.global_position)
			if dist < 120.0 and _target.has_method("take_damage"):
				_target.take_damage(damage * 0.3)
	
	get_tree().process_frame.connect(callable)
	get_tree().create_timer(zone_duration).timeout.connect(func():
		if get_tree().process_frame.is_connected(callable):
			get_tree().process_frame.disconnect(callable)
	)

# ============================================================
# Boss 弹幕生成
# ============================================================

func _spawn_boss_projectile(pos: Vector2, angle: float, speed: float, damage: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	proj.collision_layer = 8  # Boss 弹幕层
	proj.collision_mask = 1   # 玩家层
	
	# 视觉
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-3, -3), Vector2(6, 0), Vector2(-3, 3)
	])
	visual.color = base_color.lerp(Color.WHITE, 0.3)
	visual.rotation = angle
	proj.add_child(visual)
	
	# 碰撞
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	proj.add_child(col)
	
	proj.global_position = pos
	proj.set_meta("velocity", Vector2.from_angle(angle) * speed)
	proj.set_meta("damage", damage)
	proj.set_meta("lifetime", 5.0)
	proj.set_meta("age", 0.0)
	
	if _projectile_container and is_instance_valid(_projectile_container):
		_projectile_container.add_child(proj)
	else:
		get_parent().add_child(proj)
	
	# 弹幕移动和生命周期
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
		
		# 检测与玩家碰撞
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
	# 视觉效果
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(24):
		var angle := (TAU / 24) * i
		points.append(Vector2.from_angle(angle) * 10.0)
	ring.polygon = points
	ring.color = base_color
	ring.global_position = pos
	get_parent().add_child(ring)
	
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(radius / 10.0, radius / 10.0), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.chain()
	tween.tween_callback(ring.queue_free)
	
	# 伤害检测
	if _target and is_instance_valid(_target):
		var dist := pos.distance_to(_target.global_position)
		if dist < radius:
			if _target.has_method("take_damage"):
				_target.take_damage(damage)

# ============================================================
# 阶段进入回调
# ============================================================

func _on_phase_entered(phase_index: int, config: Dictionary) -> void:
	match phase_index:
		0:
			# 序曲：正常状态
			pass
		1:
			# 变奏：开始召唤，获得护盾
			_summon_cooldown = 5.0
		2:
			# 终章：进入狂暴前兆
			_finale_angle_offset = 0.0
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
			# 轻度狂暴：加速
			move_speed *= 1.3
			base_color = base_color.lerp(Color(1.0, 0.3, 0.0), 0.3)
		2:
			# 完全狂暴：大幅加速 + 持续弹幕
			move_speed *= 1.5
			base_color = Color(1.0, 0.0, 0.0)
			# 狂暴时每秒发射环形弹幕
			_start_enrage_barrage()

func _start_enrage_barrage() -> void:
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			return
		# 发射环形弹幕
		for i in range(12):
			var angle := (TAU / 12) * i + _finale_angle_offset
			_spawn_boss_projectile(global_position, angle, 
				BATON_PROJECTILE_SPEED * 0.7, 10.0)
		_finale_angle_offset += 0.3
		# 递归
		if _enrage_level >= 2 and not _is_dead:
			_start_enrage_barrage()
	)

# ============================================================
# Boss 节拍回调
# ============================================================

func _on_boss_beat(_beat_index: int) -> void:
	# 每 4 个节拍发射一次节拍弹幕（非攻击状态时）
	if not _is_attacking and _boss_beat_counter % 4 == 0:
		if _target and not _is_dead:
			var angle := (_target.global_position - global_position).angle()
			_spawn_boss_projectile(global_position, angle, 
				BATON_PROJECTILE_SPEED * 0.5, 8.0)

# ============================================================
# 移动逻辑（Boss 重写）
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	var to_player := _target.global_position - global_position
	var dist := to_player.length()
	
	# Boss 保持在一定距离外
	var preferred_distance := 250.0
	
	match _current_phase:
		0:
			# 序曲：保持中距离
			preferred_distance = 300.0
		1:
			# 变奏：更积极地移动
			preferred_distance = 200.0
		2:
			# 终章：逼近玩家
			preferred_distance = 150.0
	
	if dist > preferred_distance + 50.0:
		return to_player.normalized()
	elif dist < preferred_distance - 50.0:
		return -to_player.normalized()
	else:
		# 绕圈移动
		return to_player.normalized().rotated(PI / 2.0)

# ============================================================
# 类型名称
# ============================================================

func _get_type_name() -> String:
	return "boss_conductor"

# ============================================================
# 清理
# ============================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# 清理弹幕容器
		if _projectile_container and is_instance_valid(_projectile_container):
			for child in _projectile_container.get_children():
				if is_instance_valid(child):
					child.queue_free()
