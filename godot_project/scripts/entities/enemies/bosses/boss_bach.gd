## boss_bach.gd
## 第三章最终 Boss：大构建师·巴赫 (The Grand Architect)
##
## 核心理念：复调音乐的终极建筑师，一个由齿轮、管风琴管道和数学公式
## 构成的巨大机械体。他将战场变为一座"赋格迷宫"。
##
## 时代特征：【赋格引擎 (The Fugue Engine)】
## Boss 释放一条"主题弹幕"后，会在不同位置、不同时间释放该主题的
## "模仿"（应答、逆行、倒影），形成多声部交织的弹幕网。
##
## 风格排斥：惩罚单音攻击（音墙吸收并恢复护盾）
## 三阶段：创意(Invention) → 赋格(Fugue) → 恰空(Chaconne)
extends "res://scripts/entities/enemies/boss_base.gd"

# ============================================================
# 巴赫专属常量
# ============================================================
## 赋格弹幕参数
const FUGUE_SUBJECT_SPEED: float = 160.0
const FUGUE_ANSWER_SPEED: float = 140.0
const FUGUE_DAMAGE: float = 14.0
const FUGUE_ANSWER_DELAY: float = 1.2

## 管风琴管道攻击
const PIPE_BEAM_DAMAGE: float = 25.0
const PIPE_BEAM_WIDTH: float = 50.0
const PIPE_BEAM_DURATION: float = 1.5

## 齿轮弹幕
const GEAR_PROJECTILE_SPEED: float = 120.0
const GEAR_DAMAGE: float = 10.0

## 音墙吸收
const ABSORB_SHIELD_RECOVERY: float = 30.0

## 恰空参数
const CHACONNE_WAVE_COUNT: int = 8
const CHACONNE_INTERVAL: float = 0.8

## 单音惩罚参数（体现巴赫复调理念）
const MONOPHONIC_THRESHOLD: int = 3  # 连续单音攻击次数阈值
const MONOPHONIC_SHIELD_RECOVERY: float = 50.0  # 单音攻击时护盾恢复量
const MONOPHONIC_REFLECT_DAMAGE: float = 8.0  # 反弹伤害

# ============================================================
# 内部状态
# ============================================================
var _projectile_container: Node2D = null

## 赋格主题记忆
var _fugue_subjects: Array[Array] = []
var _fugue_voice_count: int = 1

## 齿轮旋转
var _gear_angles: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _gear_speeds: Array[float] = [0.6, -0.8, 0.4, -0.5]

## 管风琴管道位置
var _pipe_positions: Array[Vector2] = []

## 恰空低音主题
var _chaconne_bass_angle: float = 0.0

## 节拍计数
var _bach_beat_counter: int = 0

## 单音惩罚追踪（参考 Issue #127）
var _player_attack_type_history: Array[String] = []
var _monophonic_count: int = 0

# ============================================================
# Boss 初始化
# ============================================================

func _on_boss_ready() -> void:
	boss_name = "大构建师"
	boss_title = "巴赫 · The Grand Architect"
	
	max_hp = 4000.0
	current_hp = 4000.0
	move_speed = 30.0
	contact_damage = 18.0
	xp_value = 150
	
	enrage_time = 220.0
	resonance_fragment_drop = 70
	
	base_color = Color(0.6, 0.4, 0.15)
	quantized_fps = 6.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.85
	
	_projectile_container = Node2D.new()
	_projectile_container.name = "BachProjectiles"
	add_child(_projectile_container)

# ============================================================
# 阶段定义
# ============================================================

func _define_phases() -> void:
	_phase_configs = [
		{
			"name": "创意 · Invention",
			"hp_threshold": 1.0,
			"speed_mult": 1.0,
			"damage_mult": 1.0,
			"color": Color(0.6, 0.4, 0.15),
			"shield_hp": 300.0,
			"music_layer": "boss_bach_invention",
			"summon_enabled": false,
			"attack_selection": "sequence",
			"attacks": [
				{
					"name": "fugue_subject",
					"duration": 3.0,
					"cooldown": 3.5,
					"damage": FUGUE_DAMAGE,
					"weight": 3.0,
				},
				{
					"name": "gear_barrage",
					"duration": 2.0,
					"cooldown": 3.0,
					"damage": GEAR_DAMAGE,
					"weight": 2.5,
				},
				{
					"name": "pipe_organ_blast",
					"duration": 2.0,
					"cooldown": 4.0,
					"damage": PIPE_BEAM_DAMAGE,
					"weight": 2.0,
				},
			],
		},
		{
			"name": "赋格 · Fugue",
			"hp_threshold": 0.55,
			"speed_mult": 1.1,
			"damage_mult": 1.3,
			"color": Color(0.7, 0.45, 0.15),
			"shield_hp": 350.0,
			"music_layer": "boss_bach_fugue",
			"summon_enabled": true,
			"summon_count": 4,
			"summon_type": "ch3_counterpoint_crawler",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "fugue_subject",
					"duration": 3.5,
					"cooldown": 3.0,
					"damage": FUGUE_DAMAGE * 1.3,
					"weight": 3.0,
				},
				{
					"name": "double_fugue",
					"duration": 4.0,
					"cooldown": 4.0,
					"damage": FUGUE_DAMAGE * 1.2,
					"weight": 2.5,
				},
				{
					"name": "gear_barrage",
					"duration": 2.5,
					"cooldown": 2.5,
					"damage": GEAR_DAMAGE * 1.3,
					"weight": 2.0,
				},
				{
					"name": "pipe_organ_blast",
					"duration": 2.0,
					"cooldown": 3.5,
					"damage": PIPE_BEAM_DAMAGE * 1.3,
					"weight": 2.0,
				},
			],
		},
		{
			"name": "恰空 · Chaconne",
			"hp_threshold": 0.2,
			"speed_mult": 1.0,
			"damage_mult": 1.6,
			"color": Color(0.8, 0.5, 0.1),
			"shield_hp": 0.0,
			"music_layer": "boss_bach_chaconne",
			"summon_enabled": true,
			"summon_count": 6,
			"summon_type": "ch3_counterpoint_crawler",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "triple_fugue",
					"duration": 5.0,
					"cooldown": 4.0,
					"damage": FUGUE_DAMAGE * 1.5,
					"weight": 3.0,
				},
				{
					"name": "chaconne_ground_bass",
					"duration": 6.0,
					"cooldown": 5.0,
					"damage": FUGUE_DAMAGE * 1.6,
					"weight": 2.5,
				},
				{
					"name": "pipe_organ_blast",
					"duration": 2.0,
					"cooldown": 2.5,
					"damage": PIPE_BEAM_DAMAGE * 1.6,
					"weight": 2.0,
				},
				{
					"name": "gear_barrage",
					"duration": 2.5,
					"cooldown": 2.0,
					"damage": GEAR_DAMAGE * 1.6,
					"weight": 2.0,
				},
			],
		},
	]

# ============================================================
# Boss 每帧逻辑
# ============================================================

func _on_boss_process(delta: float) -> void:
	for i in range(_gear_angles.size()):
		_gear_angles[i] += _gear_speeds[i] * delta
	
	if _sprite:
		_sprite.rotation = _gear_angles[0] * 0.3

# ============================================================
# 攻击实现
# ============================================================

func _perform_attack(attack: Dictionary) -> void:
	var config: Dictionary = _phase_configs[_current_phase] if _current_phase < _phase_configs.size() else {}
	var damage_mult: float = config.get("damage_mult", 1.0)
	
	match attack["name"]:
		"fugue_subject":
			_attack_fugue_subject(attack, damage_mult, 1)
		"double_fugue":
			_attack_fugue_subject(attack, damage_mult, 2)
		"triple_fugue":
			_attack_fugue_subject(attack, damage_mult, 3)
		"gear_barrage":
			_attack_gear_barrage(attack, damage_mult)
		"pipe_organ_blast":
			_attack_pipe_organ_blast(attack, damage_mult)
		"chaconne_ground_bass":
			_attack_chaconne_ground_bass(attack, damage_mult)

## 攻击1：赋格主题 — 发射主题+延迟应答（支持多声部）
func _attack_fugue_subject(attack: Dictionary, damage_mult: float, voices: int) -> void:
	var damage: float = attack.get("damage", FUGUE_DAMAGE) * damage_mult
	
	if _target == null:
		return
	
	var base_angle := (global_position.direction_to(_target.global_position)).angle()
	
	# 主题弹幕
	var subject_angles: Array[float] = []
	for i in range(5):
		var angle := base_angle + (i - 2) * 0.15
		subject_angles.append(angle)
		_spawn_boss_projectile(global_position, angle, FUGUE_SUBJECT_SPEED, damage,
			Color(0.7, 0.5, 0.2, 0.9))
	
	# 多声部应答
	for voice in range(voices):
		var delay := FUGUE_ANSWER_DELAY * (voice + 1)
		var voice_idx := voice
		get_tree().create_timer(delay).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			# 应答变换：逆行、倒影、逆行倒影
			for angle in subject_angles:
				var transformed_angle := angle
				match voice_idx % 3:
					0: transformed_angle = angle + PI  # 逆行
					1: transformed_angle = -angle  # 倒影
					2: transformed_angle = -(angle + PI)  # 逆行倒影
				
				var speed_mult := 1.0 - voice_idx * 0.1
				_spawn_boss_projectile(global_position, transformed_angle,
					FUGUE_ANSWER_SPEED * speed_mult, damage * 0.7,
					Color(0.5 + voice_idx * 0.1, 0.3, 0.1, 0.8))
		)
	
	# 视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.6, 1.6), 0.15)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.3)

## 攻击2：齿轮弹幕 — 旋转的齿轮形弹幕
func _attack_gear_barrage(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", GEAR_DAMAGE) * damage_mult
	var waves := 4
	
	for wave in range(waves):
		get_tree().create_timer(wave * 0.4).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			var count := 10
			var offset := _gear_angles[0] + wave * 0.3
			for i in range(count):
				var angle := (TAU / count) * i + offset
				_spawn_boss_projectile(global_position, angle,
					GEAR_PROJECTILE_SPEED + wave * 20.0, damage,
					Color(0.5, 0.35, 0.15, 0.8))
		)

## 攻击3：管风琴冲击 — 定向高伤害光柱
func _attack_pipe_organ_blast(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", PIPE_BEAM_DAMAGE) * damage_mult
	
	if _target == null:
		return
	
	# 预警
	var target_pos := _target.global_position
	var dir := (global_position.direction_to(target_pos)).normalized()
	
	# 预警线
	var warning := Line2D.new()
	warning.width = 4.0
	warning.default_color = Color(1.0, 0.5, 0.1, 0.4)
	warning.add_point(global_position)
	warning.add_point(global_position + dir * 500.0)
	get_parent().add_child(warning)
	
	var warn_tween := warning.create_tween().set_loops(3)
	warn_tween.tween_property(warning, "modulate:a", 0.8, 0.15)
	warn_tween.tween_property(warning, "modulate:a", 0.3, 0.15)
	
	# 1秒后发射光柱
	get_tree().create_timer(1.0).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			if is_instance_valid(warning):
				warning.queue_free()
			return
		
		# 光柱视觉
		warning.width = PIPE_BEAM_WIDTH
		warning.default_color = Color(1.0, 0.7, 0.2, 0.8)
		
		# 伤害检测
		if _target and is_instance_valid(_target):
			var player_pos := _target.global_position
			var to_player := player_pos - global_position
			var proj := to_player.project(dir)
			var perp_dist := (to_player - proj).length()
			
			if perp_dist < PIPE_BEAM_WIDTH / 2.0 and proj.length() < 500.0:
				if _target.has_method("take_damage"):
					_target.take_damage(damage)
		
		# 消散
		var fade := warning.create_tween()
		fade.tween_property(warning, "modulate:a", 0.0, 0.5)
		fade.tween_callback(warning.queue_free)
	)

## 攻击4：恰空固定低音 — 第三阶段终极攻击
func _attack_chaconne_ground_bass(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", FUGUE_DAMAGE * 1.6) * damage_mult
	
	# 恰空：固定低音主题不断重复，上方声部越来越复杂
	for wave in range(CHACONNE_WAVE_COUNT):
		get_tree().create_timer(wave * CHACONNE_INTERVAL).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			
			# 固定低音：稳定的环形弹幕
			_chaconne_bass_angle += 0.3
			var bass_count := 6
			for i in range(bass_count):
				var angle := (TAU / bass_count) * i + _chaconne_bass_angle
				_spawn_boss_projectile(global_position, angle,
					GEAR_PROJECTILE_SPEED, damage * 0.4,
					Color(0.4, 0.25, 0.1, 0.7))
			
			# 上方声部：逐渐增加的复杂弹幕
			var upper_count := 2 + wave
			for i in range(upper_count):
				var angle := randf() * TAU
				if _target:
					angle = (global_position.direction_to(_target.global_position)).angle()
					angle += randf_range(-0.5, 0.5)
				_spawn_boss_projectile(global_position, angle,
					FUGUE_SUBJECT_SPEED * (0.8 + wave * 0.05), damage * 0.3,
					Color(0.8, 0.6, 0.2, 0.8))
		)

# ============================================================
# Boss 弹幕生成
# ============================================================

func _spawn_boss_projectile(pos: Vector2, angle: float, speed: float, damage: float, color: Color = Color.WHITE) -> void:
	if color == Color.WHITE:
		color = base_color.lerp(Color.WHITE, 0.3)
	
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-4, -4), Vector2(6, 0), Vector2(-4, 4)
	])
	visual.color = color
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
	
	var move_fn := func():
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
			if proj.global_position.distance_to(_target.global_position) < 16.0:
				if _target.has_method("take_damage"):
					_target.take_damage(proj.get_meta("damage"))
				proj.queue_free()
	
	get_tree().process_frame.connect(move_fn)
	proj.tree_exiting.connect(func():
		if get_tree().process_frame.is_connected(move_fn):
			get_tree().process_frame.disconnect(move_fn)
	)

# ============================================================
# 阶段进入回调
# ============================================================

func _on_phase_entered(phase_index: int, _config: Dictionary) -> void:
	match phase_index:
		1:
			_fugue_voice_count = 2
			_gear_speeds = [0.9, -1.2, 0.6, -0.8]
			_summon_cooldown_time = 12.0
		2:
			_fugue_voice_count = 3
			_gear_speeds = [1.3, -1.6, 0.9, -1.1]
			_summon_cooldown_time = 10.0

# ============================================================
# 狂暴
# ============================================================

func _on_enrage(level: int) -> void:
	match level:
		1:
			base_color = base_color.lerp(Color(1.0, 0.3, 0.0), 0.3)
			_gear_speeds = [1.5, -2.0, 1.2, -1.5]
		2:
			base_color = Color(1.0, 0.1, 0.0)

# ============================================================
# 节拍回调
# ============================================================

func _on_boss_beat(_beat_index: int) -> void:
	_bach_beat_counter += 1
	
	if not _is_attacking and _bach_beat_counter % 6 == 0:
		if _target and not _is_dead:
			var angle := (global_position.direction_to(_target.global_position)).angle()
			_spawn_boss_projectile(global_position, angle,
				GEAR_PROJECTILE_SPEED * 0.6, 6.0,
				Color(0.5, 0.35, 0.15, 0.7))

# ============================================================
# 移动逻辑：缓慢机械步进
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	var to_player := _target.global_position - global_position
	var dist := to_player.length()
	
	if dist > 250.0:
		return to_player.normalized() * 0.6
	elif dist < 120.0:
		return -to_player.normalized()
	return to_player.normalized().rotated(PI / 3.0) * 0.4


# ============================================================
# 单音惩罚机制（参考 Issue #127）
# ============================================================

## 外部调用：记录玩家攻击类型
## 供玩家攻击系统调用，用于追踪单音/和弦攻击
func register_player_attack_type(attack_type: String) -> void:
	# attack_type: "monophonic" (单音) 或 "polyphonic" (和弦/多声部)
	if attack_type == "monophonic":
		_monophonic_count += 1
	else:
		_monophonic_count = 0  # 使用和弦则重置计数
	
	# 记录历史（保留最近5次）
	_player_attack_type_history.append(attack_type)
	if _player_attack_type_history.size() > 5:
		_player_attack_type_history.pop_front()

## 重写伤害处理：单音惩罚
func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	# 检测是否连续使用单音攻击
	if _monophonic_count >= MONOPHONIC_THRESHOLD:
		# 惩罚1：护盾恢复（音墙吸收）
		if _current_shield_hp < _max_shield_hp:
			_current_shield_hp = min(_current_shield_hp + MONOPHONIC_SHIELD_RECOVERY, _max_shield_hp)
			
			# 视觉：护盾恢复效果
			if _sprite:
				var tween := create_tween()
				tween.tween_property(_sprite, "modulate", Color(0.8, 0.6, 0.3), 0.2)
				tween.tween_property(_sprite, "modulate", base_color, 0.4)
		
		# 惩罚2：反弹伤害
		if _target and is_instance_valid(_target):
			if _target.has_method("take_damage"):
				_target.take_damage(MONOPHONIC_REFLECT_DAMAGE)
		
		# 减少实际伤害
		amount *= 0.5
		
		# 重置计数（避免连续触发）
		_monophonic_count = 0
	
	# 调用父类伤害处理
	super.take_damage(amount, knockback_dir, is_perfect_beat)


func _get_type_name() -> String:
	return "boss_bach"

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _projectile_container and is_instance_valid(_projectile_container):
			for child in _projectile_container.get_children():
				if is_instance_valid(child):
					child.queue_free()
