## boss_jazz.gd
## 第六章最终 Boss：切分行者·爵士 (The Syncopated Shadow)
##
## 核心理念：一个戴着软呢帽、吹着萨克斯的神秘剪影，代表爵士乐的
## 自由、即兴与暧昧。攻击充满戏谑、挑逗与不可预测性，
## 仿佛在与玩家进行一场即兴对话 (Call and Response)。
##
## 时代特征：【摇摆力场 (The Swing Grid)】
## 整个战场节拍系统从正拍转换为摇摆节奏（三连音长-短律动），
## 地面安全区随爵士鼓镲声随机闪现。
##
## 风格排斥：【正拍的平庸 (The Downbeat Boredom)】
## 玩家在正拍释放技能 → Boss 进入虚无状态免疫伤害，
## 并将纯正大三和弦转化为属七和弦炸弹反击。
##
## 三阶段：即兴前奏(Intro) → 蓝调独奏(Blues Solo) → 自由爵士(Free Jazz)
extends "res://scripts/entities/enemies/boss_base.gd"

# ============================================================
# 爵士 Boss 专属常量
# ============================================================
## 摇摆弹幕参数
const SWING_PROJECTILE_SPEED: float = 200.0
const SWING_DAMAGE: float = 14.0
const SWING_BURST_COUNT: int = 5

## 萨克斯音波参数
const SAX_WAVE_WIDTH: float = 60.0
const SAX_WAVE_LENGTH: float = 400.0
const SAX_WAVE_DAMAGE: float = 18.0
const SAX_WAVE_SPEED: float = 250.0

## Call & Response 参数
const CALL_RESPONSE_WINDOW: float = 2.0
const RESPONSE_BONUS_DAMAGE: float = 1.5

## 正拍惩罚参数
const DOWNBEAT_IMMUNITY_DURATION: float = 1.5
const CHORD_BOMB_DAMAGE: float = 22.0
const CHORD_BOMB_RADIUS: float = 120.0

## 聚光灯安全区参数
const SPOTLIGHT_COUNT: int = 3
const SPOTLIGHT_RADIUS: float = 50.0
const SPOTLIGHT_DURATION: float = 4.0
const SPOTLIGHT_MOVE_SPEED: float = 40.0

## 行走贝斯线参数
const BASS_LINE_DAMAGE: float = 10.0
const BASS_LINE_SEGMENT_COUNT: int = 8
const BASS_LINE_SPEED: float = 60.0

## 蓝调音阶弹幕参数
const BLUE_NOTE_COUNT: int = 7
const BLUE_NOTE_SPEED: float = 180.0
const BLUE_NOTE_DAMAGE: float = 16.0

# ============================================================
# 内部状态
# ============================================================
## 弹幕容器
var _projectile_container: Node2D = null

## 摇摆节奏状态
var _swing_beat_phase: int = 0  # 0=长拍, 1=短拍 (三连音律动)
var _swing_timer: float = 0.0
var _swing_interval_long: float = 0.0  # 根据BPM计算
var _swing_interval_short: float = 0.0

## 正拍免疫状态
var _downbeat_immune: bool = false
var _downbeat_immune_timer: float = 0.0

## Call & Response 系统
var _call_active: bool = false
var _call_timer: float = 0.0
var _call_pattern: Array[float] = []  # 记录Boss的"呼叫"节奏
var _awaiting_response: bool = false

## 聚光灯安全区
var _spotlight_nodes: Array[Node2D] = []
var _spotlight_targets: Array[Vector2] = []

## 移动模式
var _movement_mode: String = "swing"  # swing, circle, teleport
var _circle_angle: float = 0.0
var _circle_center: Vector2 = Vector2.ZERO
var _teleport_cooldown: float = 0.0

## 节拍计数
var _jazz_beat_counter: int = 0
var _measure_beat: int = 0  # 小节内的拍号 (0-3)

# ============================================================
# Boss 初始化
# ============================================================

func _on_boss_ready() -> void:
	boss_name = "切分行者"
	boss_title = "爵士 · The Syncopated Shadow"
	
	# 数值设定
	max_hp = 5000.0
	current_hp = 5000.0
	move_speed = 120.0
	contact_damage = 18.0
	xp_value = 200
	
	# 狂暴时间
	enrage_time = 240.0
	
	# 共鸣碎片掉落
	resonance_fragment_drop = 100
	
	# 视觉
	base_color = Color(0.6, 0.3, 0.7)
	
	# 量化帧率（摇摆感）
	quantized_fps = 8.0
	_quantize_interval = 1.0 / quantized_fps
	
	# 中等击退抗性
	knockback_resistance = 0.6
	
	# 创建弹幕容器
	_projectile_container = Node2D.new()
	_projectile_container.name = "JazzProjectiles"
	add_child(_projectile_container)
	
	# 初始化摇摆节奏间隔
	_update_swing_intervals()
	
	# 初始化聚光灯
	_spawn_spotlights()

func _update_swing_intervals() -> void:
	var beat_interval: float = 60.0 / GameManager.current_bpm
	# 摇摆节奏：三连音中的 2/3 + 1/3
	_swing_interval_long = beat_interval * 2.0 / 3.0
	_swing_interval_short = beat_interval * 1.0 / 3.0

# ============================================================
# 阶段定义
# ============================================================

func _define_phases() -> void:
	_phase_configs = [
		# 阶段一：即兴前奏 (Intro) — 建立摇摆节奏
		{
			"name": "即兴前奏 · Intro",
			"hp_threshold": 1.0,
			"speed_mult": 1.0,
			"damage_mult": 1.0,
			"color": Color(0.6, 0.3, 0.7),
			"shield_hp": 300.0,
			"music_layer": "boss_jazz_intro",
			"summon_enabled": false,
			"attack_selection": "sequence",
			"attacks": [
				{
					"name": "sax_wave",
					"duration": 1.5,
					"cooldown": 3.0,
					"damage": SAX_WAVE_DAMAGE,
					"weight": 3.0,
				},
				{
					"name": "swing_burst",
					"duration": 2.0,
					"cooldown": 2.5,
					"damage": SWING_DAMAGE,
					"weight": 2.5,
				},
				{
					"name": "call_and_response",
					"duration": CALL_RESPONSE_WINDOW + 1.0,
					"cooldown": 4.0,
					"damage": SWING_DAMAGE,
					"weight": 2.0,
				},
			],
		},
		# 阶段二：蓝调独奏 (Blues Solo) — 更复杂的即兴
		{
			"name": "蓝调独奏 · Blues Solo",
			"hp_threshold": 0.55,
			"speed_mult": 1.2,
			"damage_mult": 1.3,
			"color": Color(0.3, 0.2, 0.6),
			"shield_hp": 200.0,
			"music_layer": "boss_jazz_blues",
			"summon_enabled": true,
			"summon_count": 3,
			"summon_type": "ch6_walking_bass",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "sax_wave",
					"duration": 1.5,
					"cooldown": 2.5,
					"damage": SAX_WAVE_DAMAGE * 1.3,
					"weight": 2.0,
				},
				{
					"name": "swing_burst",
					"duration": 2.0,
					"cooldown": 2.0,
					"damage": SWING_DAMAGE * 1.3,
					"weight": 2.0,
				},
				{
					"name": "walking_bass_line",
					"duration": 3.0,
					"cooldown": 3.5,
					"damage": BASS_LINE_DAMAGE * 1.3,
					"weight": 2.5,
				},
				{
					"name": "blue_note_scale",
					"duration": 2.5,
					"cooldown": 3.0,
					"damage": BLUE_NOTE_DAMAGE,
					"weight": 3.0,
				},
				{
					"name": "call_and_response",
					"duration": CALL_RESPONSE_WINDOW + 1.0,
					"cooldown": 4.0,
					"damage": SWING_DAMAGE * 1.3,
					"weight": 1.5,
				},
			],
		},
		# 阶段三：自由爵士 (Free Jazz) — 全面即兴，不可预测
		{
			"name": "自由爵士 · Free Jazz",
			"hp_threshold": 0.2,
			"speed_mult": 1.5,
			"damage_mult": 1.6,
			"color": Color(0.8, 0.2, 0.9),
			"shield_hp": 0.0,
			"music_layer": "boss_jazz_free",
			"summon_enabled": true,
			"summon_count": 5,
			"summon_type": "ch6_scat_singer",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "sax_wave",
					"duration": 1.5,
					"cooldown": 1.5,
					"damage": SAX_WAVE_DAMAGE * 1.6,
					"weight": 2.0,
				},
				{
					"name": "swing_burst",
					"duration": 2.0,
					"cooldown": 1.5,
					"damage": SWING_DAMAGE * 1.6,
					"weight": 2.0,
				},
				{
					"name": "walking_bass_line",
					"duration": 3.0,
					"cooldown": 2.5,
					"damage": BASS_LINE_DAMAGE * 1.6,
					"weight": 2.0,
				},
				{
					"name": "blue_note_scale",
					"duration": 2.5,
					"cooldown": 2.0,
					"damage": BLUE_NOTE_DAMAGE * 1.6,
					"weight": 2.5,
				},
				{
					"name": "free_improv",
					"duration": 4.0,
					"cooldown": 4.0,
					"damage": SAX_WAVE_DAMAGE * 2.0,
					"weight": 3.0,
				},
			],
		},
	]

# ============================================================
# Boss 每帧逻辑
# ============================================================

func _on_boss_process(delta: float) -> void:
	# 更新摇摆节奏
	_update_swing_rhythm(delta)
	
	# 更新正拍免疫
	if _downbeat_immune:
		_downbeat_immune_timer -= delta
		if _downbeat_immune_timer <= 0.0:
			_downbeat_immune = false
	
	# 更新 Call & Response
	if _call_active:
		_call_timer -= delta
		if _call_timer <= 0.0:
			_call_active = false
			_awaiting_response = false
	
	# 更新聚光灯移动
	_update_spotlights(delta)
	
	# 更新移动模式
	_update_movement(delta)
	
	# 传送冷却
	if _teleport_cooldown > 0.0:
		_teleport_cooldown -= delta

func _update_swing_rhythm(delta: float) -> void:
	_swing_timer -= delta
	if _swing_timer <= 0.0:
		_swing_beat_phase = 1 - _swing_beat_phase
		if _swing_beat_phase == 0:
			_swing_timer = _swing_interval_long
		else:
			_swing_timer = _swing_interval_short

func _update_movement(delta: float) -> void:
	match _movement_mode:
		"swing":
			# 摇摆式移动：左右摆动靠近玩家
			if _target and is_instance_valid(_target):
				var dir := (_target.global_position - global_position).normalized()
				var swing_offset := sin(Time.get_ticks_msec() * 0.003) * 80.0
				var perp := Vector2(-dir.y, dir.x)
				var target_pos := _target.global_position + perp * swing_offset - dir * 200.0
				global_position = global_position.lerp(target_pos, delta * 1.5)
		"circle":
			# 绕场地中心旋转
			_circle_angle += delta * 1.2
			var radius := 200.0
			global_position = _circle_center + Vector2.from_angle(_circle_angle) * radius
		"teleport":
			pass  # 瞬移由攻击触发

# ============================================================
# 攻击实现
# ============================================================

func _perform_attack(attack: Dictionary) -> void:
	var config: Dictionary = _phase_configs[_current_phase] if _current_phase < _phase_configs.size() else {}
	var damage_mult: float = config.get("damage_mult", 1.0)
	
	match attack["name"]:
		"sax_wave":
			_attack_sax_wave(attack, damage_mult)
		"swing_burst":
			_attack_swing_burst(attack, damage_mult)
		"call_and_response":
			_attack_call_and_response(attack, damage_mult)
		"walking_bass_line":
			_attack_walking_bass_line(attack, damage_mult)
		"blue_note_scale":
			_attack_blue_note_scale(attack, damage_mult)
		"free_improv":
			_attack_free_improv(attack, damage_mult)

# ============================================================
# 攻击1：萨克斯音波 (Sax Wave)
# 向玩家方向释放扇形音波弹幕
# ============================================================

func _attack_sax_wave(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", SAX_WAVE_DAMAGE) * damage_mult
	
	if not _target or not is_instance_valid(_target):
		return
	
	var dir := (global_position.direction_to(_target.global_position))
	var base_angle := dir.angle()
	
	# 扇形音波（5条射线，30度扇面）
	var fan_count := 5
	var fan_spread := deg_to_rad(30.0)
	
	for i in range(fan_count):
		var angle_offset := (float(i) / (fan_count - 1) - 0.5) * fan_spread
		var angle := base_angle + angle_offset
		_spawn_sax_projectile(global_position, angle, SAX_WAVE_SPEED, damage)
	
	# 视觉：萨克斯吹奏动画
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.3, 0.8), 0.1)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.3)

# ============================================================
# 攻击2：摇摆连射 (Swing Burst)
# 以摇摆节奏（长-短-长-短）发射弹幕
# ============================================================

func _attack_swing_burst(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", SWING_DAMAGE) * damage_mult
	
	# 摇摆节奏连射：长拍发射3颗，短拍发射1颗
	var beat_interval: float = 60.0 / GameManager.current_bpm
	var long_interval := beat_interval * 2.0 / 3.0
	var short_interval := beat_interval * 1.0 / 3.0
	
	var delays: Array[float] = [0.0, long_interval, long_interval + short_interval,
		long_interval * 2 + short_interval, long_interval * 2 + short_interval * 2]
	
	for idx in range(delays.size()):
		get_tree().create_timer(delays[idx]).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			if not _target or not is_instance_valid(_target):
				return
			
			var dir := (global_position.direction_to(_target.global_position))
			var base_angle := dir.angle()
			
			# 长拍：3颗扩散弹 / 短拍：1颗精准弹
			var is_long := idx % 2 == 0
			if is_long:
				for j in range(3):
					var offset := (j - 1) * deg_to_rad(15.0)
					_spawn_swing_projectile(global_position, base_angle + offset,
						SWING_PROJECTILE_SPEED, damage * 0.7)
			else:
				_spawn_swing_projectile(global_position, base_angle,
					SWING_PROJECTILE_SPEED * 1.3, damage)
		)

# ============================================================
# 攻击3：Call & Response（呼叫与回应）
# Boss发出一段节奏"呼叫"，玩家需要在反拍回应
# ============================================================

func _attack_call_and_response(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", SWING_DAMAGE) * damage_mult
	
	_call_active = true
	_call_timer = CALL_RESPONSE_WINDOW
	_call_pattern.clear()
	
	# Boss 的"呼叫"：发射一系列有节奏的弹幕
	var call_count := 4
	var beat_interval: float = 60.0 / GameManager.current_bpm
	
	for i in range(call_count):
		var delay := i * beat_interval * 0.75
		_call_pattern.append(delay)
		
		get_tree().create_timer(delay).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			# 发射标记弹幕（可被反拍攻击消除）
			var angle := randf() * TAU
			_spawn_call_projectile(global_position, angle, 
				SWING_PROJECTILE_SPEED * 0.6, damage * 0.5)
		)
	
	# 呼叫结束后，如果玩家没有正确回应，释放惩罚弹幕
	get_tree().create_timer(CALL_RESPONSE_WINDOW + 0.5).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			return
		if _awaiting_response:
			# 惩罚：全方位弹幕
			for i in range(12):
				var angle := (TAU / 12) * i
				_spawn_swing_projectile(global_position, angle,
					SWING_PROJECTILE_SPEED, damage)
	)
	_awaiting_response = true

# ============================================================
# 攻击4：行走贝斯线 (Walking Bass Line) — 阶段二
# 在地面留下伤害轨迹，模拟行走贝斯的音阶进行
# ============================================================

func _attack_walking_bass_line(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", BASS_LINE_DAMAGE) * damage_mult
	
	# 从Boss位置开始，沿音阶路径生成伤害区域
	var start_pos := global_position
	var bass_notes := [0, 2, 4, 5, 7, 9, 10, 12]  # 蓝调音阶度数
	var step_distance := 50.0
	
	var current_pos := start_pos
	var base_dir := Vector2.RIGHT.rotated(randf() * TAU)
	
	for i in range(bass_notes.size()):
		var note := bass_notes[i]
		var angle_offset := note * deg_to_rad(15.0)
		var dir := base_dir.rotated(angle_offset)
		var next_pos := current_pos + dir * step_distance
		
		var delay := i * 0.3
		var pos_copy := next_pos
		
		get_tree().create_timer(delay).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			_spawn_bass_zone(pos_copy, damage)
		)
		
		current_pos = next_pos

func _spawn_bass_zone(pos: Vector2, damage: float) -> void:
	# 创建地面伤害区域
	var zone := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(16):
		var angle := (TAU / 16) * i
		points.append(Vector2.from_angle(angle) * 30.0)
	zone.polygon = points
	zone.color = Color(0.4, 0.2, 0.6, 0.4)
	zone.global_position = pos
	get_parent().add_child(zone)
	
	# 脉冲动画
	var tween := zone.create_tween()
	tween.tween_property(zone, "modulate:a", 0.7, 0.2)
	tween.tween_property(zone, "modulate:a", 0.3, 0.2)
	tween.set_loops(5)
	
	# 持续伤害检测
	var lifetime := 3.0
	var elapsed := 0.0
	var damage_callable := func():
		if not is_instance_valid(zone):
			return
		elapsed += get_process_delta_time()
		if elapsed >= lifetime:
			zone.queue_free()
			return
		if _target and is_instance_valid(_target):
			if _target.global_position.distance_to(pos) < 35.0:
				if _target.has_method("take_damage"):
					_target.take_damage(damage * get_process_delta_time())
	
	get_tree().process_frame.connect(damage_callable)
	zone.tree_exiting.connect(func():
		if get_tree().process_frame.is_connected(damage_callable):
			get_tree().process_frame.disconnect(damage_callable)
	)

# ============================================================
# 攻击5：蓝调音阶 (Blue Note Scale) — 阶段二
# 沿蓝调音阶发射带有"蓝色音符"色彩的弹幕
# ============================================================

func _attack_blue_note_scale(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", BLUE_NOTE_DAMAGE) * damage_mult
	
	if not _target or not is_instance_valid(_target):
		return
	
	# 蓝调音阶：1 b3 4 b5 5 b7 8
	var blue_scale_intervals := [0.0, 3.0, 5.0, 6.0, 7.0, 10.0, 12.0]
	var base_angle := (global_position.direction_to(_target.global_position)).angle()
	
	for i in range(blue_scale_intervals.size()):
		var interval := blue_scale_intervals[i]
		var delay := i * 0.15
		var angle_offset := interval * deg_to_rad(5.0) - deg_to_rad(15.0)
		var speed_mult := 1.0 + (interval / 12.0) * 0.3
		
		get_tree().create_timer(delay).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			var angle := base_angle + angle_offset
			# 蓝色音符弹幕（带有特殊颜色）
			var is_blue_note := (i == 1 or i == 3 or i == 5)  # b3, b5, b7
			_spawn_blue_note_projectile(global_position, angle,
				BLUE_NOTE_SPEED * speed_mult, damage, is_blue_note)
		)

# ============================================================
# 攻击6：自由即兴 (Free Improv) — 阶段三终极攻击
# 完全随机的弹幕模式，模拟自由爵士的不可预测性
# ============================================================

func _attack_free_improv(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", SAX_WAVE_DAMAGE * 2.0) * damage_mult
	var duration := 4.0
	var interval := 0.15
	var total_bursts := int(duration / interval)
	
	# 随机瞬移
	_movement_mode = "teleport"
	
	for burst in range(total_bursts):
		get_tree().create_timer(burst * interval).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			
			# 随机选择攻击类型
			var attack_type := randi() % 4
			match attack_type:
				0:
					# 随机方向单发
					var angle := randf() * TAU
					_spawn_swing_projectile(global_position, angle,
						SWING_PROJECTILE_SPEED * randf_range(0.8, 1.5), damage * 0.3)
				1:
					# 瞄准玩家
					if _target and is_instance_valid(_target):
						var dir := (global_position.direction_to(_target.global_position)).angle()
						_spawn_sax_projectile(global_position, dir,
							SAX_WAVE_SPEED * 1.2, damage * 0.4)
				2:
					# 小范围散射
					for j in range(3):
						var angle := randf() * TAU
						_spawn_swing_projectile(global_position, angle,
							SWING_PROJECTILE_SPEED * 0.7, damage * 0.2)
				3:
					# 短距瞬移
					if _target and is_instance_valid(_target):
						var offset := Vector2.from_angle(randf() * TAU) * randf_range(100, 250)
						global_position = _target.global_position + offset
		)
	
	# 攻击结束后恢复摇摆移动
	get_tree().create_timer(duration).timeout.connect(func():
		_movement_mode = "swing"
	)

# ============================================================
# 正拍惩罚系统 (The Downbeat Boredom)
# ============================================================

## 外部调用：检测玩家是否在正拍攻击
func check_downbeat_punishment(attack_beat_position: float) -> bool:
	# beat_position: 0.0 = 正拍, 0.5 = 反拍
	var is_downbeat := attack_beat_position < 0.15 or attack_beat_position > 0.85
	
	if is_downbeat and not _downbeat_immune:
		_trigger_downbeat_punishment()
		return true
	return false

func _trigger_downbeat_punishment() -> void:
	_downbeat_immune = true
	_downbeat_immune_timer = DOWNBEAT_IMMUNITY_DURATION
	
	# Boss 进入虚无状态
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate:a", 0.2, 0.1)
		tween.tween_property(_sprite, "modulate:a", 1.0, DOWNBEAT_IMMUNITY_DURATION - 0.1)
	
	# 释放属七和弦炸弹反击
	if _target and is_instance_valid(_target):
		_spawn_chord_bomb(_target.global_position)

func _spawn_chord_bomb(target_pos: Vector2) -> void:
	# 属七和弦炸弹：在目标位置生成延迟爆炸
	var bomb_visual := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(7):
		var angle := (TAU / 7) * i
		var radius := 15.0 if i % 2 == 0 else 25.0
		points.append(Vector2.from_angle(angle) * radius)
	bomb_visual.polygon = points
	bomb_visual.color = Color(1.0, 0.5, 0.0, 0.8)
	bomb_visual.global_position = target_pos
	get_parent().add_child(bomb_visual)
	
	# 警告闪烁
	var tween := bomb_visual.create_tween()
	tween.tween_property(bomb_visual, "modulate", Color(1.0, 0.0, 0.0), 0.3)
	tween.tween_property(bomb_visual, "modulate", Color.WHITE, 0.3)
	tween.set_loops(3)
	
	# 延迟爆炸
	get_tree().create_timer(1.5).timeout.connect(func():
		if not is_instance_valid(bomb_visual):
			return
		# 爆炸伤害
		if _target and is_instance_valid(_target):
			if _target.global_position.distance_to(target_pos) < CHORD_BOMB_RADIUS:
				if _target.has_method("take_damage"):
					_target.take_damage(CHORD_BOMB_DAMAGE)
		# 爆炸视觉
		_spawn_shockwave(target_pos, CHORD_BOMB_RADIUS, 0.0)
		bomb_visual.queue_free()
	)

## 重写伤害处理：正拍免疫期间免疫伤害
func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	if _downbeat_immune:
		# 免疫伤害，播放"哈欠"视觉
		if _sprite:
			var tween := create_tween()
			tween.tween_property(_sprite, "scale", Vector2(1.1, 0.9), 0.1)
			tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.2)
		return
	
	super.take_damage(amount, knockback_dir, is_perfect_beat)

# ============================================================
# 聚光灯安全区系统
# ============================================================

func _spawn_spotlights() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	
	for i in range(SPOTLIGHT_COUNT):
		var spotlight := Polygon2D.new()
		var points := PackedVector2Array()
		for j in range(24):
			var angle := (TAU / 24) * j
			points.append(Vector2.from_angle(angle) * SPOTLIGHT_RADIUS)
		spotlight.polygon = points
		spotlight.color = Color(1.0, 0.9, 0.5, 0.15)
		
		var pos := Vector2(
			randf_range(100, viewport_size.x - 100),
			randf_range(100, viewport_size.y - 100)
		)
		spotlight.global_position = pos
		get_parent().add_child(spotlight)
		_spotlight_nodes.append(spotlight)
		_spotlight_targets.append(Vector2(
			randf_range(100, viewport_size.x - 100),
			randf_range(100, viewport_size.y - 100)
		))
		
		# 脉冲动画
		var tween := spotlight.create_tween().set_loops()
		tween.tween_property(spotlight, "modulate:a", 0.8, 0.5)
		tween.tween_property(spotlight, "modulate:a", 0.3, 0.5)

func _update_spotlights(delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	
	for i in range(_spotlight_nodes.size()):
		if not is_instance_valid(_spotlight_nodes[i]):
			continue
		
		var spotlight := _spotlight_nodes[i]
		var target := _spotlight_targets[i]
		
		spotlight.global_position = spotlight.global_position.lerp(target, delta * 0.5)
		
		# 到达目标后重新随机
		if spotlight.global_position.distance_to(target) < 10.0:
			_spotlight_targets[i] = Vector2(
				randf_range(100, viewport_size.x - 100),
				randf_range(100, viewport_size.y - 100)
			)

# ============================================================
# 弹幕生成辅助
# ============================================================

func _spawn_sax_projectile(pos: Vector2, angle: float, speed: float, damage: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	proj.collision_layer = 8
	proj.collision_mask = 1
	
	# 音波形状（波浪线）
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-12, -3), Vector2(-6, 5), Vector2(0, -5),
		Vector2(6, 5), Vector2(12, -3), Vector2(12, 3),
		Vector2(6, -5), Vector2(0, 5), Vector2(-6, -5), Vector2(-12, 3)
	])
	visual.color = Color(0.7, 0.4, 0.9, 0.9)
	visual.rotation = angle
	proj.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	col.shape = shape
	proj.add_child(col)
	
	proj.global_position = pos
	proj.set_meta("velocity", Vector2.from_angle(angle) * speed)
	proj.set_meta("damage", damage)
	proj.set_meta("lifetime", 5.0)
	proj.set_meta("age", 0.0)
	
	_add_projectile_to_container(proj)

func _spawn_swing_projectile(pos: Vector2, angle: float, speed: float, damage: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	proj.collision_layer = 8
	proj.collision_mask = 1
	
	# 音符形状
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-5, -5), Vector2(5, 0), Vector2(-5, 5)
	])
	visual.color = Color(0.5, 0.3, 0.8, 0.9)
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
	proj.set_meta("lifetime", 5.0)
	proj.set_meta("age", 0.0)
	
	_add_projectile_to_container(proj)

func _spawn_call_projectile(pos: Vector2, angle: float, speed: float, damage: float) -> void:
	# 特殊弹幕：可被玩家反拍攻击消除
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	proj.add_to_group("call_projectiles")
	proj.collision_layer = 8
	proj.collision_mask = 1
	
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(7, 0), Vector2(0, 8), Vector2(-7, 0)
	])
	visual.color = Color(1.0, 0.8, 0.2, 0.9)
	visual.rotation = angle
	proj.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	col.shape = shape
	proj.add_child(col)
	
	proj.global_position = pos
	proj.set_meta("velocity", Vector2.from_angle(angle) * speed)
	proj.set_meta("damage", damage)
	proj.set_meta("lifetime", 6.0)
	proj.set_meta("age", 0.0)
	proj.set_meta("is_call", true)
	
	_add_projectile_to_container(proj)

func _spawn_blue_note_projectile(pos: Vector2, angle: float, speed: float, damage: float, is_blue: bool) -> void:
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	proj.collision_layer = 8
	proj.collision_mask = 1
	
	var visual := Polygon2D.new()
	var size := 8.0 if is_blue else 5.0
	visual.polygon = PackedVector2Array([
		Vector2(-size, -size), Vector2(size, -size),
		Vector2(size, size), Vector2(-size, size)
	])
	visual.color = Color(0.2, 0.3, 0.9, 0.9) if is_blue else Color(0.6, 0.4, 0.8, 0.9)
	visual.rotation = angle
	proj.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = size
	col.shape = shape
	proj.add_child(col)
	
	proj.global_position = pos
	proj.set_meta("velocity", Vector2.from_angle(angle) * speed)
	proj.set_meta("damage", damage * (1.3 if is_blue else 1.0))
	proj.set_meta("lifetime", 5.0)
	proj.set_meta("age", 0.0)
	
	_add_projectile_to_container(proj)

func _add_projectile_to_container(proj: Area2D) -> void:
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

func _spawn_shockwave(pos: Vector2, radius: float, damage: float) -> void:
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(32):
		var angle := (TAU / 32) * i
		points.append(Vector2.from_angle(angle) * 10.0)
	ring.polygon = points
	ring.color = Color(0.6, 0.3, 0.7)
	ring.global_position = pos
	get_parent().add_child(ring)
	
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(radius / 10.0, radius / 10.0), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.chain()
	tween.tween_callback(ring.queue_free)
	
	if damage > 0.0 and _target and is_instance_valid(_target):
		if pos.distance_to(_target.global_position) < radius:
			if _target.has_method("take_damage"):
				_target.take_damage(damage)

# ============================================================
# 阶段进入回调
# ============================================================

func _on_phase_entered(phase_index: int, _config: Dictionary) -> void:
	match phase_index:
		0:
			_movement_mode = "swing"
		1:
			# 蓝调独奏：开始绕场移动
			_movement_mode = "swing"
			_summon_cooldown_time = 15.0
		2:
			# 自由爵士：更激进的移动
			_movement_mode = "swing"
			_summon_cooldown_time = 10.0
			# 清除所有弹幕
			if _projectile_container:
				for child in _projectile_container.get_children():
					child.queue_free()

# ============================================================
# 狂暴回调
# ============================================================

func _on_enrage(level: int) -> void:
	match level:
		1:
			base_color = base_color.lerp(Color(1.0, 0.3, 0.0), 0.3)
			move_speed *= 1.3
		2:
			base_color = Color(1.0, 0.0, 0.2)
			move_speed *= 1.2
			# 狂暴：持续释放随机弹幕
			_start_enrage_jazz()

func _start_enrage_jazz() -> void:
	get_tree().create_timer(0.5).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			return
		# 随机方向弹幕
		for i in range(3):
			var angle := randf() * TAU
			_spawn_swing_projectile(global_position, angle,
				SWING_PROJECTILE_SPEED * 0.8, 12.0)
		if _enrage_level >= 2 and not _is_dead:
			_start_enrage_jazz()
	)

# ============================================================
# 节拍回调
# ============================================================

func _on_boss_beat(_beat_index: int) -> void:
	_jazz_beat_counter += 1
	_measure_beat = _jazz_beat_counter % 4
	
	# 更新摇摆间隔（BPM可能动态变化）
	_update_swing_intervals()
	
	# 反拍时发射额外弹幕（模拟爵士的反拍重音）
	if _measure_beat == 1 or _measure_beat == 3:  # 弱拍/反拍
		if not _is_attacking and not _is_dead:
			if _target and is_instance_valid(_target):
				var angle := (global_position.direction_to(_target.global_position)).angle()
				angle += randf_range(-0.3, 0.3)  # 即兴偏移
				_spawn_swing_projectile(global_position, angle,
					SWING_PROJECTILE_SPEED * 0.5, 6.0)

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	# 保持与玩家的距离（不太近也不太远）
	var dir := (_target.global_position - global_position)
	var dist := dir.length()
	
	if dist < 150.0:
		return -dir.normalized()  # 太近则后退
	elif dist > 350.0:
		return dir.normalized()   # 太远则靠近
	else:
		# 适当距离：横向移动
		return Vector2(-dir.y, dir.x).normalized()

# ============================================================
# 类型名称
# ============================================================

func _get_type_name() -> String:
	return "boss_jazz"

# ============================================================
# 清理
# ============================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _projectile_container and is_instance_valid(_projectile_container):
			for child in _projectile_container.get_children():
				if is_instance_valid(child):
					child.queue_free()
		for spotlight in _spotlight_nodes:
			if is_instance_valid(spotlight):
				spotlight.queue_free()
