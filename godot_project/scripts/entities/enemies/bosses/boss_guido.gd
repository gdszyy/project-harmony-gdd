## boss_guido.gd
## 第二章最终 Boss：圣咏宗师·圭多 (The Sacred Voice)
##
## 核心理念：中世纪记谱法的化身，一个身披光之法袍、手持巨大羽毛笔的
## 修道士形象。他将战场变为一张巨大的四线谱，用"书写"来定义攻击。
##
## 时代特征：【四线谱战场 (The Staff Field)】
## 战场上出现四条横贯的发光线条（四线谱），Boss在线上"书写"音符，
## 这些音符会变成实体弹幕。线间的空间是相对安全区。
##
## 风格排斥：惩罚纯单音攻击（声部孤立Debuff）
## 三阶段：吟诵(Chant) → 记谱(Notation) → 升华(Ascension)
##
## GDD参考：
## - 阶段一（齐唱之墙）：圣咏轨迹 + 圣歌护盾 + 声部孤立检测
## - 阶段二（双声部圣咏）：双轨迹 + Silence加入 + 圣咏加速
## - 阶段三（升华）：升华光柱 + 神圣合唱 + 全面强化
extends "res://scripts/entities/enemies/boss_base.gd"

# ============================================================
# 圭多专属常量
# ============================================================
## 四线谱参数
const STAFF_LINE_COUNT: int = 4
const STAFF_LINE_SPACING: float = 80.0
const STAFF_WIDTH: float = 600.0

## 音符弹幕参数
const NOTE_PROJECTILE_SPEED: float = 150.0
const NOTE_DAMAGE: float = 12.0

## 圣咏音墙参数（GDD：横向推进的音墙）
const CHANT_WALL_SPEED: float = 100.0
const CHANT_WALL_DAMAGE: float = 20.0
const CHANT_WALL_WIDTH: float = 500.0
const CHANT_WALL_INTERVAL_PHASE1: int = 16  # 阶段一：每16拍
const CHANT_WALL_INTERVAL_PHASE2: int = 16  # 阶段二：每16拍
const CHANT_WALL_INTERVAL_ENRAGED: int = 12  # HP<30%：每12拍

## 圣歌护盾参数（GDD：清除轨迹上Static后护盾消失4秒）
const SACRED_SHIELD_REAPPEAR_TIME: float = 4.0
const SACRED_SHIELD_HP: float = 250.0

## 声部孤立参数（GDD：10秒内只用单音攻击触发Debuff）
const ISOLATION_CHECK_WINDOW: float = 10.0
const ISOLATION_DAMAGE: float = 10.0
const ISOLATION_FATIGUE: float = 0.15
const ISOLATION_THRESHOLD: int = 4  # 连续使用单一音色次数阈值
const ISOLATION_IMMUNITY_DURATION: float = 3.5
const ISOLATION_DAMAGE_REDUCTION: float = 0.7
const ISOLATION_HEAL_REDUCTION: float = 0.5  # GDD：治疗和护盾效果降低50%

## 升华阶段参数
const ASCENSION_BEAM_DAMAGE: float = 30.0
const ASCENSION_BEAM_WIDTH: float = 60.0
const ASCENSION_BEAM_COUNT: int = 5

## 唱名弹幕参数（Do-Re-Mi-Fa-Sol-La）
const SOLMIZATION_NOTES: PackedStringArray = ["Do", "Re", "Mi", "Fa", "Sol", "La"]

## 双轨迹参数（阶段二）
const DUAL_TRACK_SPACING: float = 160.0

# ============================================================
# 内部状态
# ============================================================
var _projectile_container: Node2D = null

## 四线谱系统
var _staff_lines: Array[Dictionary] = []
var _staff_active: bool = false
var _staff_visual_nodes: Array[Node2D] = []
var _staff_center_y: float = 0.0

## 圣咏轨迹系统（GDD核心机制）
var _chant_track_active: bool = false
var _chant_track_nodes: Array[Node2D] = []  # 轨迹上的Static编队
var _chant_track_count: int = 0  # 当前活跃轨迹数
var _chant_track_statics_alive: int = 0  # 轨迹上存活的Static数量
var _sacred_shield_down: bool = false  # 圣歌护盾是否被打破
var _sacred_shield_timer: float = 0.0  # 护盾消失倒计时

## 书写系统
var _writing_position: Vector2 = Vector2.ZERO
var _writing_target: Vector2 = Vector2.ZERO
var _is_writing: bool = false

## 圣咏节拍计数器
var _chant_beat_counter: int = 0
var _current_chant_interval: int = CHANT_WALL_INTERVAL_PHASE1

## 升华光柱
var _ascension_beams: Array[Dictionary] = []

## 声部孤立追踪（GDD：10秒内只用单音攻击则触发Debuff）
var _last_player_timbre: String = ""
var _same_timbre_count: int = 0
var _isolation_immune: bool = false
var _isolation_immune_timer: float = 0.0
var _immune_timbre: String = ""
var _isolation_debuff_active: bool = false
var _isolation_debuff_timer: float = 0.0
var _single_note_timer: float = 0.0  # 追踪单音使用时间
var _has_used_chord: bool = false  # 是否在窗口内使用过和弦

## 双轨迹状态（阶段二）
var _dual_track_active: bool = false
var _silence_spawned: bool = false

# ============================================================
# Boss 初始化
# ============================================================

func _on_boss_ready() -> void:
	boss_name = "圣咏宗师"
	boss_title = "圭多 · The Sacred Voice"
	
	max_hp = 3500.0
	current_hp = 3500.0
	move_speed = 45.0
	contact_damage = 15.0
	xp_value = 120
	
	enrage_time = 210.0
	resonance_fragment_drop = 60
	
	base_color = Color(0.9, 0.75, 0.2)
	quantized_fps = 6.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.8
	
	_projectile_container = Node2D.new()
	_projectile_container.name = "GuidoProjectiles"
	_projectile_container.top_level = true  # 使弹幕容器独立于 Boss 变换，避免 global_position 双重偏移
	add_child(_projectile_container)
	
	# 初始化四线谱
	_staff_center_y = global_position.y
	_setup_staff_lines()

# ============================================================
# 阶段定义（GDD：齐唱之墙 → 双声部圣咏 → 升华）
# ============================================================

func _define_phases() -> void:
	_phase_configs = [
		# 阶段一：齐唱之墙 (Chant Wall)
		# GDD：圣咏轨迹 + 圣歌护盾 + 声部孤立检测
		{
			"name": "齐唱之墙 · Chant Wall",
			"hp_threshold": 1.0,
			"speed_mult": 1.0,
			"damage_mult": 1.0,
			"color": Color(0.9, 0.75, 0.2),
			"shield_hp": SACRED_SHIELD_HP,
			"music_layer": "boss_guido_chant",
			"summon_enabled": false,
			"attack_selection": "sequence",
			"attacks": [
				{
					"name": "staff_notation",
					"duration": 3.0,
					"cooldown": 3.5,
					"damage": NOTE_DAMAGE,
					"weight": 3.0,
				},
				{
					"name": "chant_wall",
					"duration": 2.0,
					"cooldown": 4.0,
					"damage": CHANT_WALL_DAMAGE,
					"weight": 2.0,
				},
				{
					"name": "neume_scatter",
					"duration": 1.5,
					"cooldown": 3.0,
					"damage": NOTE_DAMAGE * 0.8,
					"weight": 2.5,
				},
			],
		},
		# 阶段二：双声部圣咏 (Dual Chant)
		# GDD：双轨迹 + Silence加入 + 圣咏加速（HP<30%时16拍→12拍）
		{
			"name": "双声部圣咏 · Dual Chant",
			"hp_threshold": 0.55,
			"speed_mult": 1.2,
			"damage_mult": 1.3,
			"color": Color(1.0, 0.8, 0.2),
			"shield_hp": 300.0,
			"music_layer": "boss_guido_notation",
			"summon_enabled": true,
			"summon_count": 3,
			"summon_type": "ch2_choir",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "dual_chant_wall",
					"duration": 3.0,
					"cooldown": 3.0,
					"damage": CHANT_WALL_DAMAGE * 1.3,
					"weight": 3.0,
				},
				{
					"name": "staff_notation",
					"duration": 3.0,
					"cooldown": 2.5,
					"damage": NOTE_DAMAGE * 1.3,
					"weight": 2.0,
				},
				{
					"name": "solmization_barrage",
					"duration": 3.5,
					"cooldown": 4.0,
					"damage": NOTE_DAMAGE * 1.2,
					"weight": 2.5,
				},
				{
					"name": "voice_isolation",
					"duration": 0.5,
					"cooldown": 5.0,
					"damage": ISOLATION_DAMAGE,
					"weight": 1.5,
				},
			],
		},
		# 阶段三：升华 (Ascension)
		# GDD：升华光柱 + 神圣合唱 + 全面强化
		{
			"name": "升华 · Ascension",
			"hp_threshold": 0.2,
			"speed_mult": 1.0,
			"damage_mult": 1.6,
			"color": Color(1.0, 0.9, 0.4),
			"shield_hp": 0.0,
			"music_layer": "boss_guido_ascension",
			"summon_enabled": true,
			"summon_count": 5,
			"summon_type": "ch2_choir",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "ascension_beams",
					"duration": 4.0,
					"cooldown": 3.5,
					"damage": ASCENSION_BEAM_DAMAGE,
					"weight": 3.0,
				},
				{
					"name": "divine_chorus",
					"duration": 5.0,
					"cooldown": 4.5,
					"damage": CHANT_WALL_DAMAGE * 1.6,
					"weight": 2.5,
				},
				{
					"name": "solmization_barrage",
					"duration": 3.5,
					"cooldown": 3.0,
					"damage": NOTE_DAMAGE * 1.5,
					"weight": 2.0,
				},
				{
					"name": "dual_chant_wall",
					"duration": 3.0,
					"cooldown": 2.5,
					"damage": CHANT_WALL_DAMAGE * 1.6,
					"weight": 2.0,
				},
			],
		},
	]

# ============================================================
# 四线谱系统
# ============================================================

func _setup_staff_lines() -> void:
	_staff_active = true
	var total_height := (STAFF_LINE_COUNT - 1) * STAFF_LINE_SPACING
	var start_y := _staff_center_y - total_height / 2.0
	
	for i in range(STAFF_LINE_COUNT):
		var y_pos := start_y + i * STAFF_LINE_SPACING
		_staff_lines.append({
			"y": y_pos,
			"index": i,
		})
		
		# 视觉：发光线条（金色五线谱，GDD视觉方案）
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color(0.8, 0.7, 0.3, 0.3)
		line.add_point(Vector2(global_position.x - STAFF_WIDTH / 2, y_pos))
		line.add_point(Vector2(global_position.x + STAFF_WIDTH / 2, y_pos))
		get_parent().add_child(line)
		_staff_visual_nodes.append(line)

# ============================================================
# Boss 每帧逻辑
# ============================================================

func _on_boss_process(delta: float) -> void:
	# 更新圣歌护盾状态（GDD：清除Static后护盾消失4秒）
	_update_sacred_shield(delta)
	
	# 声部孤立检测计时（GDD：10秒窗口）
	_update_isolation_tracking(delta)
	
	# 声部孤立免疫计时
	if _isolation_immune:
		_isolation_immune_timer -= delta
		if _isolation_immune_timer <= 0.0:
			_isolation_immune = false
			_immune_timbre = ""
	
	# 声部孤立Debuff计时
	if _isolation_debuff_active:
		_isolation_debuff_timer -= delta
		if _isolation_debuff_timer <= 0.0:
			_isolation_debuff_active = false
	
	# 圣咏加速检测（GDD：HP<30%时从16拍变为12拍）
	_check_chant_acceleration()

## 圣歌护盾机制（GDD核心机制）
## 只有在圣咏轨迹上的所有Static被清除后，护盾才会短暂消失4秒
func _update_sacred_shield(delta: float) -> void:
	if _sacred_shield_down:
		_sacred_shield_timer -= delta
		if _sacred_shield_timer <= 0.0:
			_sacred_shield_down = false
			# 护盾重新激活
			_shield_hp = _max_shield_hp
			_shield_active = true
			# 视觉：护盾重现
			if _sprite:
				var tween := create_tween()
				tween.tween_property(_sprite, "modulate",
					base_color.lerp(Color(0.5, 0.8, 1.0), 0.3), 0.5)

## 声部孤立追踪（GDD：10秒内只使用单音则触发）
func _update_isolation_tracking(delta: float) -> void:
	_single_note_timer += delta
	if _single_note_timer >= ISOLATION_CHECK_WINDOW:
		if not _has_used_chord and _current_phase >= 1:
			# 10秒内没有使用和弦，触发声部孤立Debuff
			_trigger_isolation_debuff()
		# 重置窗口
		_single_note_timer = 0.0
		_has_used_chord = false

## 触发声部孤立Debuff（GDD：治疗和护盾效果大幅降低）
func _trigger_isolation_debuff() -> void:
	_isolation_debuff_active = true
	_isolation_debuff_timer = 8.0  # Debuff持续8秒
	
	# 视觉：屏幕边缘灰暗羊皮纸纹理 + 锁链特效
	if _target and is_instance_valid(_target):
		if _target.has_method("take_damage"):
			_target.take_damage(ISOLATION_DAMAGE)
		if FatigueManager and FatigueManager.has_method("add_external_fatigue"):
			FatigueManager.add_external_fatigue(ISOLATION_FATIGUE)
	
	# Boss视觉反馈：金色脉冲
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.9, 0.4), 0.2)
		tween.tween_property(_sprite, "modulate", base_color, 0.5)

## 圣咏加速检测（GDD：HP<30%时频率从16拍变为12拍）
func _check_chant_acceleration() -> void:
	var hp_ratio := current_hp / max_hp
	if hp_ratio < 0.3:
		_current_chant_interval = CHANT_WALL_INTERVAL_ENRAGED
	elif _current_phase >= 1:
		_current_chant_interval = CHANT_WALL_INTERVAL_PHASE2
	else:
		_current_chant_interval = CHANT_WALL_INTERVAL_PHASE1

# ============================================================
# 攻击实现
# ============================================================

func _perform_attack(attack: Dictionary) -> void:
	var config: Dictionary = _phase_configs[_current_phase] if _current_phase < _phase_configs.size() else {}
	var damage_mult: float = config.get("damage_mult", 1.0)
	
	match attack["name"]:
		"staff_notation":
			_attack_staff_notation(attack, damage_mult)
		"chant_wall":
			_attack_chant_wall(attack, damage_mult)
		"neume_scatter":
			_attack_neume_scatter(attack, damage_mult)
		"solmization_barrage":
			_attack_solmization_barrage(attack, damage_mult)
		"voice_isolation":
			_attack_voice_isolation(attack, damage_mult)
		"dual_chant_wall":
			_attack_dual_chant_wall(attack, damage_mult)
		"ascension_beams":
			_attack_ascension_beams(attack, damage_mult)
		"divine_chorus":
			_attack_divine_chorus(attack, damage_mult)

## 攻击1：四线谱记谱 — 在四线谱上书写音符弹幕
## GDD：6只Static被吸附在轨迹上排成一列，同步发射缓慢直线弹幕形成"音墙"
func _attack_staff_notation(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", NOTE_DAMAGE) * damage_mult
	var notes_per_line := 4
	
	for line_data in _staff_lines:
		var y: float = line_data["y"]
		for n in range(notes_per_line):
			var delay := n * 0.3
			get_tree().create_timer(delay).timeout.connect(func():
				if _is_dead or not is_instance_valid(self):
					return
				# 从左到右在线上生成音符弹幕
				var x_start := global_position.x - STAFF_WIDTH / 2.0
				var x_pos := x_start + (STAFF_WIDTH / notes_per_line) * n
				var note_pos := Vector2(x_pos, y)
				
				# 音符向玩家方向飞行
				var angle := 0.0
				if _target:
					angle = (note_pos.direction_to(_target.global_position)).angle()
				
				_spawn_note_projectile(note_pos, angle, NOTE_PROJECTILE_SPEED, damage)
			)

## 攻击2：圣咏音墙 — 横向推进的音墙
## GDD：形成"音墙"，玩家需横向移动躲避
func _attack_chant_wall(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", CHANT_WALL_DAMAGE) * damage_mult
	
	# 从Boss位置向玩家方向推进音墙
	var dir := Vector2.RIGHT
	if _target:
		dir = (global_position.direction_to(_target.global_position)).normalized()
	
	var perp := dir.rotated(PI / 2.0)
	
	# 生成宽幅音墙（GDD：横贯战场的音墙）
	var segments := 8
	for i in range(segments):
		var offset := perp * ((i - segments / 2.0) * (CHANT_WALL_WIDTH / segments))
		var start_pos := global_position + offset
		
		_spawn_wall_segment(start_pos, dir, CHANT_WALL_SPEED, damage, CHANT_WALL_WIDTH / segments)

## 攻击3：纽姆散射 — 随机方向的纽姆符号弹幕
func _attack_neume_scatter(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", NOTE_DAMAGE * 0.8) * damage_mult
	var count := 12
	
	for i in range(count):
		var angle := randf() * TAU
		var speed := randf_range(100.0, 200.0)
		_spawn_note_projectile(global_position, angle, speed, damage)

## 攻击4：唱名弹幕 — Do-Re-Mi-Fa-Sol-La 六连发
## GDD：圭多发明了唱名法，以此作为标志性攻击
func _attack_solmization_barrage(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", NOTE_DAMAGE * 1.2) * damage_mult
	
	for i in range(SOLMIZATION_NOTES.size()):
		get_tree().create_timer(i * 0.4).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			
			if _target == null:
				return
			
			# 每个唱名对应不同的弹幕模式
			var base_angle := (global_position.direction_to(_target.global_position)).angle()
			var count := 3 + i  # 逐渐增加弹幕数（Do=3, La=8）
			var spread := PI / 6.0 + i * PI / 18.0
			
			for j in range(count):
				var t := float(j) / float(max(1, count - 1))
				var angle := base_angle - spread / 2.0 + spread * t
				if count == 1:
					angle = base_angle
				_spawn_note_projectile(global_position, angle,
					NOTE_PROJECTILE_SPEED * (1.0 + i * 0.1), damage * 0.6)
		)

## 攻击5：声部孤立 — 主动惩罚单音攻击
## GDD：10秒内只用单音攻击则触发"声部孤立"Debuff
func _attack_voice_isolation(attack: Dictionary, _damage_mult: float) -> void:
	if _target and is_instance_valid(_target):
		if _target.has_method("take_damage"):
			_target.take_damage(ISOLATION_DAMAGE)
		if FatigueManager and FatigueManager.has_method("add_external_fatigue"):
			FatigueManager.add_external_fatigue(ISOLATION_FATIGUE)

## 攻击6：双轨迹圣咏 — 阶段二专属
## GDD：同时出现两条圣咏轨迹（上下平行），形成双层音墙
func _attack_dual_chant_wall(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", CHANT_WALL_DAMAGE * 1.3) * damage_mult
	
	# 上下两条平行轨迹
	var center_y := global_position.y
	var upper_y := center_y - DUAL_TRACK_SPACING / 2.0
	var lower_y := center_y + DUAL_TRACK_SPACING / 2.0
	
	# 两条轨迹的方向（向玩家推进）
	var dir := Vector2.RIGHT
	if _target:
		dir = (global_position.direction_to(_target.global_position)).normalized()
	var perp := dir.rotated(PI / 2.0)
	
	# 上层音墙
	var segments := 6
	for i in range(segments):
		var offset := perp * ((i - segments / 2.0) * (CHANT_WALL_WIDTH * 0.8 / segments))
		var start_pos := Vector2(global_position.x, upper_y) + offset
		_spawn_wall_segment(start_pos, dir, CHANT_WALL_SPEED * 1.1, damage * 0.7, CHANT_WALL_WIDTH * 0.8 / segments)
	
	# 下层音墙（延迟0.5秒，制造走位压力）
	get_tree().create_timer(0.5).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			return
		for i in range(segments):
			var offset := perp * ((i - segments / 2.0) * (CHANT_WALL_WIDTH * 0.8 / segments))
			var start_pos := Vector2(global_position.x, lower_y) + offset
			_spawn_wall_segment(start_pos, dir, CHANT_WALL_SPEED * 1.1, damage * 0.7, CHANT_WALL_WIDTH * 0.8 / segments)
	)
	
	# GDD：阶段二 Silence加入（首次触发时召唤）
	if _current_phase >= 1 and not _silence_spawned:
		_silence_spawned = true
		# 通过信号召唤Silence到两条轨迹之间
		boss_summon_minions.emit(1, "silence")

## 攻击7：升华光柱 — 第三阶段专属，从天而降的光柱
## GDD：升华阶段的核心攻击，光柱落在玩家附近
func _attack_ascension_beams(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", ASCENSION_BEAM_DAMAGE) * damage_mult
	var beam_count := ASCENSION_BEAM_COUNT
	
	for i in range(beam_count):
		get_tree().create_timer(i * 0.6).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			
			# 光柱落在玩家附近（预判位置）
			var target_pos := Vector2.ZERO
			if _target:
				target_pos = _target.global_position + Vector2(
					randf_range(-80, 80), randf_range(-80, 80)
				)
			else:
				target_pos = global_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
			
			_spawn_ascension_beam(target_pos, damage)
		)

## 攻击8：神圣合唱 — 终极攻击，四方向同时推进音墙
## GDD：升华阶段的终极攻击，全屏圣咏压迫
func _attack_divine_chorus(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", CHANT_WALL_DAMAGE * 1.6) * damage_mult
	
	# 四个方向同时推进音墙
	var directions := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	
	for wave in range(3):
		get_tree().create_timer(wave * 1.2).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			
			# 每波选择不同方向
			var dir: Vector2 = directions[wave % directions.size()]
			var perp := dir.rotated(PI / 2.0)
			
			var segments := 6
			for i in range(segments):
				var offset := perp * ((i - segments / 2.0) * 60.0)
				var start_pos := global_position + offset - dir * 200.0
				_spawn_wall_segment(start_pos, dir, CHANT_WALL_SPEED * 1.3, damage * 0.5, 60.0)
			
			# 同时在对角方向释放音符弹幕
			var diag_dirs := [dir.rotated(PI / 4.0), dir.rotated(-PI / 4.0)]
			for d in diag_dirs:
				for j in range(3):
					var angle: float = d.angle() + (j - 1) * 0.15
					_spawn_note_projectile(global_position, angle,
						NOTE_PROJECTILE_SPEED * 1.2, damage * 0.3)
		)

# ============================================================
# 弹幕生成
# ============================================================

func _spawn_note_projectile(pos: Vector2, angle: float, speed: float, damage: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	
	# 音符形状视觉（GDD：纽姆记谱法风格）
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-4, -3), Vector2(4, -3), Vector2(4, 3), Vector2(-4, 3),
		Vector2(-4, -3), Vector2(-4, -8)  # 符干
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
	
	if _projectile_container and is_instance_valid(_projectile_container):
		_projectile_container.add_child(proj)
	else:
		get_parent().add_child(proj)
	
	var vel := Vector2.from_angle(angle) * speed
	var lifetime := 5.0
	
	var move_fn := func():
		if not is_instance_valid(proj):
			return
		proj.global_position += vel * get_process_delta_time()
		if _target and is_instance_valid(_target):
			if proj.global_position.distance_to(_target.global_position) < 16.0:
				if _target.has_method("take_damage"):
					_target.take_damage(damage)
				proj.queue_free()
	
	get_tree().process_frame.connect(move_fn)
	proj.tree_exiting.connect(func():
		if get_tree().process_frame.is_connected(move_fn):
			get_tree().process_frame.disconnect(move_fn)
	)
	
	get_tree().create_timer(lifetime).timeout.connect(func():
		if is_instance_valid(proj):
			proj.queue_free()
	)

func _spawn_wall_segment(pos: Vector2, dir: Vector2, speed: float, damage: float, width: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	
	var visual := Polygon2D.new()
	var hw := width / 2.0
	visual.polygon = PackedVector2Array([
		Vector2(-hw, -4), Vector2(hw, -4), Vector2(hw, 4), Vector2(-hw, 4)
	])
	visual.color = Color(0.9, 0.8, 0.3, 0.6)
	visual.rotation = dir.angle()
	proj.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 8)
	col.shape = shape
	col.rotation = dir.angle()
	proj.add_child(col)
	
	proj.global_position = pos
	get_parent().add_child(proj)
	
	var end_pos := pos + dir * 600.0
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position", end_pos, 600.0 / speed)
	tween.tween_callback(proj.queue_free)
	
	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
	)

func _spawn_ascension_beam(target_pos: Vector2, damage: float) -> void:
	# 预警标记（GDD视觉：金色光环预警）
	var warning := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(16):
		var angle := (TAU / 16) * i
		points.append(Vector2.from_angle(angle) * ASCENSION_BEAM_WIDTH / 2.0)
	warning.polygon = points
	warning.color = Color(1.0, 0.9, 0.3, 0.3)
	warning.global_position = target_pos
	get_parent().add_child(warning)
	
	# 预警闪烁
	var warn_tween := warning.create_tween().set_loops(3)
	warn_tween.tween_property(warning, "modulate:a", 0.8, 0.15)
	warn_tween.tween_property(warning, "modulate:a", 0.3, 0.15)
	
	# 1秒后光柱落下
	get_tree().create_timer(1.0).timeout.connect(func():
		if not is_instance_valid(warning):
			return
		warning.color = Color(1.0, 0.95, 0.5, 0.8)
		
		# 伤害检测
		if _target and is_instance_valid(_target):
			if _target.global_position.distance_to(target_pos) < ASCENSION_BEAM_WIDTH / 2.0:
				if _target.has_method("take_damage"):
					_target.take_damage(damage)
		
		# 消散
		var fade := warning.create_tween()
		fade.tween_property(warning, "modulate:a", 0.0, 0.5)
		fade.tween_callback(warning.queue_free)
	)

# ============================================================
# 阶段进入回调
# ============================================================

func _on_phase_entered(phase_index: int, _config: Dictionary) -> void:
	match phase_index:
		0:
			_current_chant_interval = CHANT_WALL_INTERVAL_PHASE1
		1:
			# 阶段二：双声部圣咏
			_dual_track_active = true
			_summon_cooldown_time = 12.0
			_current_chant_interval = CHANT_WALL_INTERVAL_PHASE2
		2:
			# 阶段三：升华
			_summon_cooldown_time = 10.0
			# 四线谱发光增强（GDD视觉：升华时谱线更亮）
			for node in _staff_visual_nodes:
				if is_instance_valid(node) and node is Line2D:
					node.default_color = Color(1.0, 0.9, 0.4, 0.6)
					node.width = 3.0

# ============================================================
# 狂暴
# ============================================================

func _on_enrage(level: int) -> void:
	match level:
		1:
			base_color = base_color.lerp(Color(1.0, 0.4, 0.1), 0.3)
			_current_chant_interval = CHANT_WALL_INTERVAL_ENRAGED
		2:
			base_color = Color(1.0, 0.2, 0.0)
			# 狂暴2：所有攻击冷却缩短
			for phase in _phase_configs:
				for attack in phase.get("attacks", []):
					attack["cooldown"] = attack.get("cooldown", 2.0) * 0.7

# ============================================================
# 节拍回调
# ============================================================

func _on_boss_beat(_beat_index: int) -> void:
	_chant_beat_counter += 1
	
	# 按节拍间隔自动发射圣咏音墙（GDD核心机制）
	if _chant_beat_counter % _current_chant_interval == 0:
		if not _is_attacking and not _is_dead:
			if _target:
				var angle := (global_position.direction_to(_target.global_position)).angle()
				_spawn_note_projectile(global_position, angle, NOTE_PROJECTILE_SPEED * 0.6, 6.0)
	
	# 每 8 拍在非攻击状态时自动发射一次音符
	if not _is_attacking and _chant_beat_counter % 8 == 0:
		if _target and not _is_dead:
			var angle := (global_position.direction_to(_target.global_position)).angle()
			_spawn_note_projectile(global_position, angle, NOTE_PROJECTILE_SPEED * 0.6, 6.0)

# ============================================================
# 移动逻辑：缓慢飘浮
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	var to_player := _target.global_position - global_position
	var dist := to_player.length()
	
	# 保持中远距离（修道士风格：庄严缓慢）
	if dist > 300.0:
		return to_player.normalized() * 0.5
	elif dist < 150.0:
		return -to_player.normalized()
	return Vector2.ZERO

# ============================================================
# 声部孤立机制（GDD：10秒内只用单音攻击触发Debuff）
# ============================================================

## 外部调用：记录玩家使用的音色
## 供玩家攻击系统调用，用于追踪单一音色使用
func register_player_timbre(timbre: String) -> void:
	if timbre == _last_player_timbre:
		_same_timbre_count += 1
	else:
		_same_timbre_count = 1
		_last_player_timbre = timbre
	
	if _same_timbre_count >= ISOLATION_THRESHOLD:
		_trigger_isolation_immunity(timbre)

## 外部调用：记录玩家使用了和弦（非单音）
func register_player_chord_use() -> void:
	_has_used_chord = true
	# 重置单音计时
	_single_note_timer = 0.0

func _trigger_isolation_immunity(timbre: String) -> void:
	_isolation_immune = true
	_isolation_immune_timer = ISOLATION_IMMUNITY_DURATION
	_immune_timbre = timbre
	_same_timbre_count = 0
	
	# 视觉：获得免疫效果（金色护盾闪烁）
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.9, 0.4), 0.3)
		tween.tween_property(_sprite, "modulate", base_color, ISOLATION_IMMUNITY_DURATION)

## 重写伤害处理：声部孤立免疫 + 圣歌护盾机制
func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	# 如果玩家使用单一音色且触发免疫，大幅减伤
	var final_damage := amount
	if _isolation_immune:
		final_damage *= (1.0 - ISOLATION_DAMAGE_REDUCTION)
	
	# 调用父类伤害处理
	super.take_damage(final_damage, knockback_dir, is_perfect_beat)

func _get_type_name() -> String:
	return "boss_guido"

# ============================================================
# 清理
# ============================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _projectile_container and is_instance_valid(_projectile_container):
			for child in _projectile_container.get_children():
				if is_instance_valid(child):
					child.queue_free()
		for node in _staff_visual_nodes:
			if is_instance_valid(node):
				node.queue_free()
		for node in _chant_track_nodes:
			if is_instance_valid(node):
				node.queue_free()
