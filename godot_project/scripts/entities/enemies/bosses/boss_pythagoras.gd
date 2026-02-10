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
##
## 两阶段设计（遵循 Chapter1_Dev_Plan.md v3.0）：
##   阶段一 (HP 800)：简单图形 — 八度共振 → 五度震荡 → 节拍考验 (循环)
##   阶段二 (HP 1200)：复杂图形 — 四度叠加 → 不和谐脉冲 → 终焉和弦 (HP<20%)
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

## 和谐护盾参数（节拍考验专用）
const HARMONY_SHIELD_DURATION: float = 8.0  # 16拍@BPM=120

## 风格排斥参数
const STYLE_REJECT_WINDOW: float = 2.0  # 检测窗口（秒）
const STYLE_REJECT_THRESHOLD: int = 5   # 无效输入次数阈值

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

## 和谐护盾状态（节拍考验机制）
var _harmony_shield_active: bool = false
var _harmony_shield_timer: float = 0.0
var _harmony_shield_pulse_timer: float = 0.0  # 全屏脉冲计时

## 阶段二特殊状态
var _phase2_initialized: bool = false
var _phase2_hp: float = 1200.0
var _irregular_pulse_pattern: Array[float] = [3.0, 5.0, 2.0]  # 不规则节奏间隔
var _irregular_pulse_index: int = 0
var _irregular_pulse_timer: float = 0.0
var _finale_chord_active: bool = false  # 终焉和弦状态

## 风格排斥追踪
var _offbeat_attack_timestamps: Array[float] = []

# ============================================================
# Boss 初始化
# ============================================================

func _on_boss_ready() -> void:
	boss_name = "律动尊者"
	boss_title = "毕达哥拉斯 · The First Resonator"
	
	# 阶段一数值
	max_hp = 800.0
	current_hp = 800.0
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
# 阶段定义（两阶段设计）
# ============================================================

func _define_phases() -> void:
	_phase_configs = [
		# ================================================================
		# 阶段一：简单图形 (HP 800 → 0)
		# 攻击循环：八度共振 → 五度震荡 → 节拍考验
		# ================================================================
		{
			"name": "简单图形 · Simple Patterns",
			"hp_threshold": 1.0,
			"speed_mult": 1.0,
			"damage_mult": 1.0,
			"color": Color(0.3, 0.4, 1.0),
			"shield_hp": 0.0,
			"music_layer": "boss_pythagoras_prelude",
			"summon_enabled": false,
			"attack_selection": "sequence",
			"attacks": [
				{
					"name": "octave_resonance",
					"duration": 8.0,   # 16拍@BPM=120
					"cooldown": 2.0,
					"damage": CHLADNI_DAMAGE_PER_SEC,
					"weight": 1.0,
				},
				{
					"name": "fifth_oscillation",
					"duration": 12.0,  # 24拍@BPM=120
					"cooldown": 2.0,
					"damage": CHLADNI_DAMAGE_PER_SEC,
					"weight": 1.0,
				},
				{
					"name": "beat_trial",
					"duration": HARMONY_SHIELD_DURATION,
					"cooldown": 2.0,
					"damage": PULSE_DAMAGE,
					"weight": 1.0,
				},
			],
		},
		# ================================================================
		# 阶段二：复杂图形 (HP 1200 → 0)
		# 攻击循环：四度叠加 → 不和谐脉冲 → (HP<20%时) 终焉和弦
		# ================================================================
		{
			"name": "复杂图形 · Complex Patterns",
			"hp_threshold": 0.0,  # 手动触发（阶段一 HP 归零后）
			"speed_mult": 1.0,
			"damage_mult": 1.3,
			"color": Color(0.5, 0.2, 0.9),
			"shield_hp": 0.0,
			"music_layer": "boss_pythagoras_resonance",
			"summon_enabled": true,
			"summon_count": 4,
			"summon_type": "ch1_grid_static",
			"attack_selection": "sequence",
			"attacks": [
				{
					"name": "fourth_overlay",
					"duration": 12.0,  # 24拍@BPM=120
					"cooldown": 2.0,
					"damage": CHLADNI_DAMAGE_PER_SEC * 1.3,
					"weight": 1.0,
				},
				{
					"name": "dissonant_pulse",
					"duration": 8.0,   # 16拍@BPM=120
					"cooldown": 2.0,
					"damage": PULSE_DAMAGE * 1.3,
					"weight": 1.0,
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
	
	# 更新和谐护盾
	if _harmony_shield_active:
		_update_harmony_shield(delta)
	
	# 更新不规则脉冲（阶段二）
	if _current_phase == 1 and _irregular_pulse_timer > 0.0:
		_update_irregular_pulse(delta)
	
	# 检查终焉和弦触发条件（阶段二 HP < 20%）
	if _current_phase == 1 and not _finale_chord_active:
		var hp_ratio := current_hp / max_hp
		if hp_ratio < 0.2:
			_activate_finale_chord()
	
	# 清理过期的风格排斥时间戳
	var current_time := Time.get_ticks_msec() / 1000.0
	_offbeat_attack_timestamps = _offbeat_attack_timestamps.filter(
		func(t): return current_time - t < STYLE_REJECT_WINDOW
	)
	
	# 光环视觉
	if _sprite:
		_sprite.rotation = _ring_rotation_angles[0]

# ============================================================
# 伤害处理重写（和谐护盾机制）
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	if _is_dead or _is_transitioning:
		return
	
	# === 和谐护盾机制 ===
	# 节拍考验期间，只有完美卡拍才能造成伤害
	if _harmony_shield_active:
		if not is_perfect_beat:
			# 非完美卡拍：伤害被反弹
			_reflect_damage(amount)
			return
		else:
			# 完美卡拍：护盾不阻挡，且额外增伤
			amount *= 1.5
	
	# 调用父类伤害处理
	super.take_damage(amount, knockback_dir, is_perfect_beat)
	
	# 阶段一 HP 归零 → 触发阶段二
	if current_hp <= 0.0 and _current_phase == 0 and not _phase2_initialized:
		_trigger_phase_two()

## 反弹伤害（和谐护盾激活时，非完美卡拍的攻击被反弹）
func _reflect_damage(amount: float) -> void:
	if _target and is_instance_valid(_target) and _target.has_method("take_damage"):
		_target.take_damage(amount * 0.3)
	
	# "亵渎！"视觉效果
	_spawn_reflect_visual()

func _spawn_reflect_visual() -> void:
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(0.0, 0.5, 1.0, 1.0), 0.05)
		tween.tween_property(_sprite, "modulate", base_color, 0.3)

# ============================================================
# 阶段二触发
# ============================================================

func _trigger_phase_two() -> void:
	_phase2_initialized = true
	_is_dead = false  # 阻止死亡
	
	# 短暂无敌过渡动画（3 秒）
	_is_transitioning = true
	_is_attacking = false
	
	# 清除所有弹幕和克拉尼图形
	_clear_all_projectiles()
	_deactivate_chladni()
	_harmony_shield_active = false
	
	# 恢复 HP 为阶段二数值
	max_hp = _phase2_hp
	current_hp = _phase2_hp
	
	# 过渡动画
	_play_phase2_transition()
	
	# 延迟后进入阶段二
	get_tree().create_timer(3.0).timeout.connect(func():
		_is_transitioning = false
		_enter_phase(1)
		_ring_rotation_speeds = [0.8, -1.0, 0.5]
		_summon_cooldown_time = 12.0
	)

func _play_phase2_transition() -> void:
	if _sprite == null:
		return
	
	var tween := create_tween()
	# 膨胀 + 闪白
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", Vector2(3.0, 3.0), 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.3)
	# 收缩 + 新颜色
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", Vector2(0.6, 0.6), 0.3).set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, "modulate", Color(0.5, 0.2, 0.9), 0.4)
	# 恢复 + 脉冲
	tween.chain()
	tween.tween_property(_sprite, "scale", Vector2(1.5, 1.5), 0.4).set_ease(Tween.EASE_OUT)
	tween.chain()
	tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.3)

# ============================================================
# 攻击实现
# ============================================================

func _perform_attack(attack: Dictionary) -> void:
	var config: Dictionary = _phase_configs[_current_phase] if _current_phase < _phase_configs.size() else {}
	var damage_mult: float = config.get("damage_mult", 1.0)
	
	match attack["name"]:
		# 阶段一攻击
		"octave_resonance":
			_attack_octave_resonance(attack, damage_mult)
		"fifth_oscillation":
			_attack_fifth_oscillation(attack, damage_mult)
		"beat_trial":
			_attack_beat_trial(attack, damage_mult)
		# 阶段二攻击
		"fourth_overlay":
			_attack_fourth_overlay(attack, damage_mult)
		"dissonant_pulse":
			_attack_dissonant_pulse(attack, damage_mult)
		"finale_chord":
			_attack_finale_chord(attack, damage_mult)

# ============================================================
# 阶段一攻击1：八度共振 (Octave Resonance)
# 同心圆克拉尼图形，4 个固定安全节点（东南西北）
# 持续 16 拍（约 8 秒@BPM=120）
# ============================================================

func _attack_octave_resonance(attack: Dictionary, damage_mult: float) -> void:
	_chladni_active = true
	_chladni_timer = 8.0  # 16拍
	_chladni_pattern_index = 0  # 同心圆
	
	# 4 个固定安全节点（东南西北）
	_chladni_safe_points.clear()
	var directions := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	for dir in directions:
		_chladni_safe_points.append(global_position + dir * 150.0)
	
	_spawn_chladni_visual(damage_mult)
	
	# 同时释放缓慢的环形弹幕
	get_tree().create_timer(2.0).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			return
		for i in range(8):
			var angle := (TAU / 8) * i
			_spawn_boss_projectile(global_position, angle, RING_PROJECTILE_SPEED * 0.5, RING_DAMAGE * damage_mult * 0.5)
	)

# ============================================================
# 阶段一攻击2：五度震荡 (Fifth Oscillation)
# 花瓣形克拉尼图形，6 个安全节点，每 8 拍切换位置
# 持续 24 拍（约 12 秒@BPM=120）
# ============================================================

func _attack_fifth_oscillation(attack: Dictionary, damage_mult: float) -> void:
	_chladni_active = true
	_chladni_timer = 12.0  # 24拍
	_chladni_pattern_index = 1  # 花瓣形
	
	# 初始 6 个安全节点
	_generate_fifth_safe_points(0)
	_spawn_chladni_visual(damage_mult)
	
	# 每 4 秒（8 拍）切换安全节点位置
	for shift in range(2):
		get_tree().create_timer(4.0 * (shift + 1)).timeout.connect(func():
			if _is_dead or not is_instance_valid(self) or not _chladni_active:
				return
			# 新节点提前 1 秒开始发光预警
			_generate_fifth_safe_points(shift + 1)
			_refresh_safe_point_visuals()
		)

func _generate_fifth_safe_points(shift_index: int) -> void:
	_chladni_safe_points.clear()
	var base_offset := shift_index * PI / 3.0  # 每次旋转 60°
	for i in range(6):
		var angle := (TAU / 6) * i + base_offset
		var safe_pos := global_position + Vector2.from_angle(angle) * 180.0
		_chladni_safe_points.append(safe_pos)

func _refresh_safe_point_visuals() -> void:
	# 清理旧的安全节点视觉，生成新的
	var nodes_to_remove: Array[Node2D] = []
	for node in _chladni_visual_nodes:
		if is_instance_valid(node) and node.has_meta("safe_visual"):
			nodes_to_remove.append(node)
	for node in nodes_to_remove:
		_chladni_visual_nodes.erase(node)
		var tween := node.create_tween()
		tween.tween_property(node, "modulate:a", 0.0, 0.3)
		tween.tween_callback(node.queue_free)
	
	# 生成新的安全节点视觉
	for safe_pos in _chladni_safe_points:
		var safe_visual := Polygon2D.new()
		var points := PackedVector2Array()
		for i in range(16):
			var angle := (TAU / 16) * i
			points.append(Vector2.from_angle(angle) * CHLADNI_SAFE_RADIUS)
		safe_visual.polygon = points
		safe_visual.color = Color(0.2, 0.8, 1.0, 0.0)  # 从透明开始
		safe_visual.global_position = safe_pos
		safe_visual.set_meta("safe_visual", true)
		get_parent().add_child(safe_visual)
		_chladni_visual_nodes.append(safe_visual)
		
		# 预警动画：淡入
		var tween := safe_visual.create_tween()
		tween.tween_property(safe_visual, "color:a", 0.4, 1.0)
		# 脉冲
		var pulse_tween := safe_visual.create_tween().set_loops()
		pulse_tween.tween_property(safe_visual, "modulate:a", 0.7, 0.5)
		pulse_tween.tween_property(safe_visual, "modulate:a", 0.3, 0.5)

# ============================================================
# 阶段一攻击3：节拍考验 (Beat Trial)
# Boss 激活"和谐护盾"，只有完美卡拍攻击才能造成伤害
# 每 4 拍释放全屏脉冲
# 持续 16 拍（约 8 秒@BPM=120）
# ============================================================

func _attack_beat_trial(attack: Dictionary, damage_mult: float) -> void:
	_harmony_shield_active = true
	_harmony_shield_timer = HARMONY_SHIELD_DURATION
	_harmony_shield_pulse_timer = 0.0
	
	# 教学提示
	var hint_mgr := get_node_or_null("/root/TutorialHintManager")
	if hint_mgr and hint_mgr.has_method("show_hint"):
		hint_mgr.show_hint("和谐护盾激活！只有完美卡拍才能造成伤害", 3.0)
	
	# 视觉：Boss 发出蓝色光芒
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(0.3, 0.6, 1.0, 1.0), 0.3)

func _update_harmony_shield(delta: float) -> void:
	_harmony_shield_timer -= delta
	
	if _harmony_shield_timer <= 0.0:
		_harmony_shield_active = false
		# 恢复正常颜色
		if _sprite:
			var tween := create_tween()
			tween.tween_property(_sprite, "modulate", base_color, 0.5)
		return
	
	# 每 2 秒（约 4 拍@BPM=120）释放全屏脉冲
	_harmony_shield_pulse_timer += delta
	var beat_interval: float = 60.0 / maxf(GameManager.current_bpm, 1.0)
	var pulse_interval: float = beat_interval * 4.0  # 4 拍
	
	if _harmony_shield_pulse_timer >= pulse_interval:
		_harmony_shield_pulse_timer -= pulse_interval
		_spawn_shockwave(global_position, PULSE_RADIUS * 1.5, PULSE_DAMAGE * 0.5)
		
		# 脉冲视觉
		if _sprite:
			var tween := create_tween()
			tween.tween_property(_sprite, "scale", Vector2(1.6, 1.6), 0.08)
			tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.15)
	
	# 护盾视觉：蓝色脉冲呼吸
	if _sprite:
		var pulse := sin(Time.get_ticks_msec() * 0.008) * 0.15
		_sprite.modulate = Color(0.3, 0.6, 1.0).lerp(Color(0.5, 0.8, 1.0), 0.5 + pulse)

# ============================================================
# 阶段二攻击1：四度叠加 (Fourth Overlay)
# 两组克拉尼图形叠加，仅 3 个安全节点
# 持续 24 拍（约 12 秒@BPM=120）
# ============================================================

func _attack_fourth_overlay(attack: Dictionary, damage_mult: float) -> void:
	_chladni_active = true
	_chladni_timer = 12.0
	_chladni_pattern_index = 2  # 叠加图形
	
	# 仅 3 个安全节点
	_chladni_safe_points.clear()
	for i in range(3):
		var angle := (TAU / 3) * i + randf_range(0, TAU / 6)
		var safe_pos := global_position + Vector2.from_angle(angle) * 160.0
		_chladni_safe_points.append(safe_pos)
	
	_spawn_chladni_visual(damage_mult)
	
	# 同时释放环形弹幕
	for wave in range(3):
		get_tree().create_timer(wave * 3.0).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			var count := RING_PROJECTILE_COUNT + wave * 2
			for i in range(count):
				var angle := (TAU / count) * i + _ring_rotation_angles[0]
				_spawn_boss_projectile(global_position, angle,
					RING_PROJECTILE_SPEED * 0.7, RING_DAMAGE * damage_mult * 0.6)
		)

# ============================================================
# 阶段二攻击2：不和谐脉冲 (Dissonant Pulse)
# 不规则节奏的脉冲（3拍、5拍、2拍随机间隔）
# 持续 16 拍（约 8 秒@BPM=120）
# ============================================================

func _attack_dissonant_pulse(attack: Dictionary, damage_mult: float) -> void:
	_irregular_pulse_timer = 8.0
	_irregular_pulse_index = 0
	
	# 打乱不规则节奏序列
	_irregular_pulse_pattern = [3.0, 5.0, 2.0, 4.0, 1.0]
	_irregular_pulse_pattern.shuffle()

func _update_irregular_pulse(delta: float) -> void:
	_irregular_pulse_timer -= delta
	
	if _irregular_pulse_timer <= 0.0:
		_irregular_pulse_timer = 0.0
		return
	
	var beat_interval: float = 60.0 / maxf(GameManager.current_bpm, 1.0)
	var current_pattern_beats: float = _irregular_pulse_pattern[_irregular_pulse_index % _irregular_pulse_pattern.size()]
	var pulse_interval: float = beat_interval * current_pattern_beats
	
	# 简单计时器检测
	# 使用 meta 存储上次脉冲时间
	var last_pulse_time: float = get_meta("last_irregular_pulse", 0.0)
	var current_time := Time.get_ticks_msec() / 1000.0
	
	if current_time - last_pulse_time >= pulse_interval:
		set_meta("last_irregular_pulse", current_time)
		_irregular_pulse_index += 1
		
		var config: Dictionary = _phase_configs[_current_phase] if _current_phase < _phase_configs.size() else {}
		var damage_mult: float = config.get("damage_mult", 1.0)
		
		# 释放脉冲
		_spawn_shockwave(global_position, PULSE_RADIUS, PULSE_DAMAGE * damage_mult)
		
		# 同时释放少量弹幕
		var count := 6
		for i in range(count):
			var angle := (TAU / count) * i + randf_range(0, TAU / count)
			_spawn_boss_projectile(global_position, angle,
				RING_PROJECTILE_SPEED * 0.6, RING_DAMAGE * damage_mult * 0.4)

# ============================================================
# 终焉和弦 (Finale Chord) — 阶段二 HP < 20% 触发
# 所有图形同时激活，仅 2 个安全节点，每 4 拍切换
# ============================================================

func _activate_finale_chord() -> void:
	_finale_chord_active = true
	
	# 替换当前攻击模式为终焉和弦
	if _current_phase == 1:
		_phase_configs[1]["attacks"] = [
			{
				"name": "finale_chord",
				"duration": 999.0,  # 持续至 Boss 被击败
				"cooldown": 0.0,
				"damage": CHLADNI_DAMAGE_PER_SEC * 1.6,
				"weight": 1.0,
			},
		]
		_attack_patterns = _phase_configs[1]["attacks"]
		_attack_sequence_index = 0
		_is_attacking = false
		_attack_cooldown = 0.5
	
	# 光环加速
	_ring_rotation_speeds = [1.5, -2.0, 1.0]
	
	# 视觉警告
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(0.8, 0.1, 0.1), 0.3)
		tween.tween_property(_sprite, "modulate", Color(0.6, 0.2, 1.0), 0.5)

func _attack_finale_chord(attack: Dictionary, damage_mult: float) -> void:
	# 激活多组叠加克拉尼图形
	_chladni_active = true
	_chladni_timer = 999.0  # 持续至 Boss 死亡
	_chladni_pattern_index = 3  # 最复杂图形
	
	# 仅 2 个安全节点
	_chladni_safe_points.clear()
	_chladni_safe_points.append(global_position + Vector2(120, 0))
	_chladni_safe_points.append(global_position + Vector2(-120, 0))
	
	_spawn_chladni_visual(damage_mult)
	
	# 每 2 秒（4 拍）切换安全节点位置
	var switch_count := 0
	var switch_timer_func: Callable
	switch_timer_func = func():
		if _is_dead or not is_instance_valid(self):
			return
		switch_count += 1
		_chladni_safe_points.clear()
		var offset_angle := switch_count * PI / 4.0
		_chladni_safe_points.append(global_position + Vector2.from_angle(offset_angle) * 120.0)
		_chladni_safe_points.append(global_position + Vector2.from_angle(offset_angle + PI) * 120.0)
		_refresh_safe_point_visuals()
		
		# 同时释放弹幕
		for i in range(RING_PROJECTILE_COUNT):
			var angle := (TAU / RING_PROJECTILE_COUNT) * i + _ring_rotation_angles[0]
			_spawn_boss_projectile(global_position, angle,
				RING_PROJECTILE_SPEED * 0.5, RING_DAMAGE * damage_mult * 0.4)
		
		get_tree().create_timer(2.0).timeout.connect(switch_timer_func)
	
	get_tree().create_timer(2.0).timeout.connect(switch_timer_func)

# ============================================================
# 风格排斥系统（惩罚无效输入）
# ============================================================

## 记录一次非完美卡拍的攻击（由外部系统调用）
func record_offbeat_attack() -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	_offbeat_attack_timestamps.append(current_time)
	
	# 检查是否触发风格排斥
	if _offbeat_attack_timestamps.size() >= STYLE_REJECT_THRESHOLD:
		trigger_noise_punishment()
		_offbeat_attack_timestamps.clear()

## 触发噪音惩罚
func trigger_noise_punishment() -> void:
	if _noise_punish_timer > 0.0:
		return
	
	_noise_punish_timer = NOISE_PUNISH_COOLDOWN
	
	# 全屏微弱伤害（约 5% 玩家最大 HP）
	if _target and is_instance_valid(_target):
		if _target.has_method("take_damage"):
			_target.take_damage(NOISE_PUNISH_DAMAGE)
	
	# 增加疲劳
	var fatigue_mgr := get_node_or_null("/root/FatigueManager")
	if fatigue_mgr and fatigue_mgr.has_method("add_external_fatigue"):
		fatigue_mgr.add_external_fatigue(0.1)
	
	# "亵渎！" 视觉效果
	_spawn_blasphemy_visual()

func _spawn_blasphemy_visual() -> void:
	# 全屏闪红
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.0, 0.0), 0.1)
		tween.tween_property(_sprite, "modulate", base_color, 0.5)
	
	# 显示"亵渎！"文字提示
	var hint_mgr := get_node_or_null("/root/TutorialHintManager")
	if hint_mgr and hint_mgr.has_method("show_hint"):
		hint_mgr.show_hint("亵渎！", 1.5)

# ============================================================
# 克拉尼图形系统
# ============================================================

func _spawn_chladni_visual(damage_mult: float) -> void:
	# 清理旧的视觉节点
	for node in _chladni_visual_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_chladni_visual_nodes.clear()
	
	# 生成危险区域视觉（同心环形线条 + chladni_pattern.gdshader）
	var danger_visual := Node2D.new()
	danger_visual.global_position = global_position
	get_parent().add_child(danger_visual)
	_chladni_visual_nodes.append(danger_visual)
	
	# 应用克拉尼图形 Shader（审计报告 2.4 修复：激活闲置 Shader）
	var chladni_shader := load("res://shaders/chladni_pattern.gdshader")
	if chladni_shader:
		var chladni_bg := Sprite2D.new()
		var tex := GradientTexture2D.new()
		tex.width = 512
		tex.height = 512
		var grad := Gradient.new()
		grad.set_color(0, Color(0.8, 0.3, 0.2, 0.4))
		grad.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		chladni_bg.texture = tex
		var mat := ShaderMaterial.new()
		mat.shader = chladni_shader
		# 根据图形类型设置模态参数
		match _chladni_pattern_index:
			0: # 八度：简单同心圆
				mat.set_shader_parameter("pattern_n", 2.0)
				mat.set_shader_parameter("pattern_m", 2.0)
			1: # 五度：花瓣形
				mat.set_shader_parameter("pattern_n", 3.0)
				mat.set_shader_parameter("pattern_m", 5.0)
			2: # 四度叠加：复杂
				mat.set_shader_parameter("pattern_n", 4.0)
				mat.set_shader_parameter("pattern_m", 7.0)
			3: # 终焉和弦：最复杂
				mat.set_shader_parameter("pattern_n", 5.0)
				mat.set_shader_parameter("pattern_m", 8.0)
		mat.set_shader_parameter("pattern_blend", 0.5)
		chladni_bg.material = mat
		chladni_bg.z_index = -1
		danger_visual.add_child(chladni_bg)
	
	# 根据图形类型绘制不同的克拉尼图案
	var ring_count := 5
	match _chladni_pattern_index:
		0: ring_count = 4   # 八度：简单同心圆
		1: ring_count = 5   # 五度：花瓣形
		2: ring_count = 6   # 四度叠加：复杂
		3: ring_count = 8   # 终焉和弦：最复杂
	
	for ring_idx in range(ring_count):
		var ring := Polygon2D.new()
		var points := PackedVector2Array()
		var radius := 60.0 + ring_idx * 45.0
		var segments := 32
		for i in range(segments):
			var angle := (TAU / segments) * i
			var wave := sin(angle * (ring_idx + 2) + _chladni_pattern_index) * 15.0
			# 叠加图形时增加复杂度
			if _chladni_pattern_index >= 2:
				wave += cos(angle * (ring_idx + 3) * 1.5) * 10.0
			points.append(Vector2.from_angle(angle) * (radius + wave))
		ring.polygon = points
		ring.color = Color(0.8, 0.3, 0.2, 0.35)
		danger_visual.add_child(ring)
	
	# 生成安全节点视觉
	for safe_pos in _chladni_safe_points:
		var safe_visual := Polygon2D.new()
		var points := PackedVector2Array()
		for i in range(16):
			var angle := (TAU / 16) * i
			points.append(Vector2.from_angle(angle) * CHLADNI_SAFE_RADIUS)
		safe_visual.polygon = points
		safe_visual.color = Color(0.2, 0.8, 1.0, 0.3)
		safe_visual.global_position = safe_pos
		safe_visual.set_meta("safe_visual", true)
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
		_deactivate_chladni()
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

func _deactivate_chladni() -> void:
	_chladni_active = false
	for node in _chladni_visual_nodes:
		if is_instance_valid(node):
			var tween := node.create_tween()
			tween.tween_property(node, "modulate:a", 0.0, 0.5)
			tween.tween_callback(node.queue_free)
	_chladni_visual_nodes.clear()

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
# 辅助函数
# ============================================================

func _clear_all_projectiles() -> void:
	if _projectile_container:
		for child in _projectile_container.get_children():
			if is_instance_valid(child):
				child.queue_free()

# ============================================================
# 阶段进入回调
# ============================================================

func _on_phase_entered(phase_index: int, _config: Dictionary) -> void:
	match phase_index:
		0:
			pass
		1:
			# 阶段二：光环旋转加速
			_ring_rotation_speeds = [0.8, -1.0, 0.5]
			_summon_cooldown_time = 12.0

# ============================================================
# 狂暴回调
# ============================================================

func _on_enrage(level: int) -> void:
	match level:
		1:
			_ring_rotation_speeds = [1.5, -2.0, 1.0]
			base_color = base_color.lerp(Color(1.0, 0.3, 0.0), 0.3)
		2:
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
# Boss 击败奖励
# ============================================================

func _boss_die() -> void:
	if _is_dead:
		return
	
	# 清理所有弹幕和克拉尼图形
	_clear_all_projectiles()
	_deactivate_chladni()
	_harmony_shield_active = false
	
	# 调用父类死亡逻辑
	super._boss_die()
	
	# 解锁和弦炼成系统
	_unlock_chord_crafting()

func _unlock_chord_crafting() -> void:
	# 通知解锁和弦炼成
	var hint_mgr := get_node_or_null("/root/TutorialHintManager")
	if hint_mgr and hint_mgr.has_method("show_unlock"):
		hint_mgr.show_unlock("feature", "CHORD_CRAFTING", "解锁：和弦炼成系统")
	
	# 给予玩家 C、E、G 音符
	var note_mgr := get_node_or_null("/root/NoteInventoryManager")
	if note_mgr:
		if note_mgr.has_method("add_note"):
			note_mgr.add_note("C", 3)
			note_mgr.add_note("E", 3)
			note_mgr.add_note("G", 3)

# ============================================================
# 清理
# ============================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_clear_all_projectiles()
		for node in _chladni_visual_nodes:
			if is_instance_valid(node):
				node.queue_free()
