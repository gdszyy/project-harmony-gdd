## boss_noise.gd
## 第七章最终 Boss：合成主脑·噪音 (The Digital Void)
##
## 核心理念：一个没有固定形态、不断变化的数字生命体，
## 由纯粹数据和频率构成的有感知的算法。
## 时而凝聚成巨大几何形状，时而消散成噪音云。
## 代表音乐的最终解构——一切皆可为音乐，包括噪音本身。
##
## 时代特征：【波形战争 (Waveform Warfare)】
## Boss 在四种基础波形（正弦波、方波、锯齿波、噪音波）之间切换形态，
## 每种波形对应不同的攻击模式和弱点。
## 玩家必须用对应的"音色"来克制当前波形。
##
## 风格排斥：【单一的诅咒 (The Monotone Curse)】
## 如果玩家持续使用同一种音色/波形攻击，Boss 会"适应"并免疫。
## 玩家必须不断切换音色，体现现代音乐的多样性。
##
## 四阶段：初始化(Init) → 波形切换(Waveform Shift) →
##         频率风暴(Frequency Storm) → 奇点(Singularity)
extends "res://scripts/entities/enemies/boss_base.gd"

# ============================================================
# 噪音 Boss 专属常量
# ============================================================
## 波形类型枚举
enum WaveformType {
	SINE,       ## 正弦波：流畅、曲线弹幕
	SQUARE,     ## 方波：方形、网格弹幕
	SAWTOOTH,   ## 锯齿波：锐利、锯齿弹幕
	NOISE,      ## 噪音波：随机、混沌弹幕
}

## 正弦波攻击参数
const SINE_WAVE_AMPLITUDE: float = 80.0
const SINE_WAVE_FREQUENCY: float = 3.0
const SINE_PROJECTILE_SPEED: float = 180.0
const SINE_DAMAGE: float = 15.0

## 方波攻击参数
const SQUARE_GRID_SIZE: float = 60.0
const SQUARE_PROJECTILE_SPEED: float = 200.0
const SQUARE_DAMAGE: float = 18.0

## 锯齿波攻击参数
const SAW_SWEEP_SPEED: float = 250.0
const SAW_DAMAGE: float = 20.0
const SAW_TOOTH_COUNT: int = 8

## 噪音波攻击参数
const NOISE_BURST_COUNT: int = 20
const NOISE_PROJECTILE_SPEED: float = 160.0
const NOISE_DAMAGE: float = 12.0

## 降采样光环参数
const BITCRUSH_RADIUS: float = 150.0
const BITCRUSH_DAMAGE_REDUCTION: float = 0.5

## 故障传送参数
const GLITCH_TELEPORT_COOLDOWN: float = 5.0
const GLITCH_AFTERIMAGE_COUNT: int = 3

## 频率偏移参数
const FREQ_SHIFT_INTERVAL: float = 8.0
const FREQ_SHIFT_DURATION: float = 3.0

## 单一诅咒参数
const MONOTONE_THRESHOLD: int = 5  # 连续使用同一音色次数
const MONOTONE_IMMUNITY_DURATION: float = 4.0

# ============================================================
# 内部状态
# ============================================================
## 弹幕容器
var _projectile_container: Node2D = null

## 当前波形状态
var _current_waveform: WaveformType = WaveformType.SINE
var _waveform_timer: float = 0.0
var _waveform_switch_interval: float = 12.0

## 波形颜色映射
var _waveform_colors: Dictionary = {
	WaveformType.SINE: Color(0.2, 0.8, 0.4),
	WaveformType.SQUARE: Color(0.2, 0.4, 0.9),
	WaveformType.SAWTOOTH: Color(0.9, 0.6, 0.1),
	WaveformType.NOISE: Color(0.9, 0.1, 0.3),
}

## 故障视觉状态
var _glitch_timer: float = 0.0
var _glitch_teleport_timer: float = 0.0

## 降采样区域
var _bitcrush_zones: Array[Node2D] = []

## 频率偏移状态
var _freq_shift_active: bool = false
var _freq_shift_timer: float = 0.0
var _freq_shift_cooldown: float = 0.0

## 单一诅咒追踪
var _last_timbre_used: String = ""
var _same_timbre_count: int = 0
var _monotone_immune: bool = false
var _monotone_immune_timer: float = 0.0
var _immune_timbre: String = ""

## 残影系统
var _afterimages: Array[Node2D] = []

## 形态变化
var _form_scale: Vector2 = Vector2.ONE
var _form_target_scale: Vector2 = Vector2.ONE
var _dissolve_particles: Array[Node2D] = []

## 节拍计数
var _noise_beat_counter: int = 0

# ============================================================
# Boss 初始化
# ============================================================

func _on_boss_ready() -> void:
	boss_name = "合成主脑"
	boss_title = "噪音 · The Digital Void"
	
	# 数值设定（最终Boss，最高数值）
	max_hp = 7000.0
	current_hp = 7000.0
	move_speed = 100.0
	contact_damage = 22.0
	xp_value = 350
	
	# 狂暴时间
	enrage_time = 300.0
	
	# 共鸣碎片掉落
	resonance_fragment_drop = 150
	
	# 视觉
	base_color = Color(0.1, 0.9, 0.6)
	
	# 量化帧率（数字故障感）
	quantized_fps = 10.0
	_quantize_interval = 1.0 / quantized_fps
	
	# 中等击退抗性
	knockback_resistance = 0.5
	
	# 创建弹幕容器
	_projectile_container = Node2D.new()
	_projectile_container.name = "NoiseProjectiles"
	add_child(_projectile_container)

# ============================================================
# 阶段定义
# ============================================================

func _define_phases() -> void:
	_phase_configs = [
		# 阶段一：初始化 (Init) — 单一波形
		{
			"name": "初始化 · Init",
			"hp_threshold": 1.0,
			"speed_mult": 1.0,
			"damage_mult": 1.0,
			"color": Color(0.1, 0.9, 0.6),
			"shield_hp": 400.0,
			"music_layer": "boss_noise_init",
			"summon_enabled": false,
			"attack_selection": "adaptive",
			"attacks": [
				{
					"name": "sine_wave_sweep",
					"duration": 2.5,
					"cooldown": 3.0,
					"damage": SINE_DAMAGE,
					"weight": 3.0,
					"min_range": 0.0,
					"max_range": 99999.0,
				},
				{
					"name": "square_grid",
					"duration": 2.0,
					"cooldown": 3.5,
					"damage": SQUARE_DAMAGE,
					"weight": 2.0,
					"min_range": 0.0,
					"max_range": 300.0,
				},
				{
					"name": "data_stream",
					"duration": 1.5,
					"cooldown": 2.5,
					"damage": SINE_DAMAGE,
					"weight": 2.5,
					"min_range": 0.0,
					"max_range": 99999.0,
				},
			],
		},
		# 阶段二：波形切换 (Waveform Shift) — 动态切换波形
		{
			"name": "波形切换 · Waveform Shift",
			"hp_threshold": 0.65,
			"speed_mult": 1.2,
			"damage_mult": 1.3,
			"color": Color(0.2, 0.4, 0.9),
			"shield_hp": 300.0,
			"music_layer": "boss_noise_waveform",
			"summon_enabled": true,
			"summon_count": 4,
			"summon_type": "ch7_bitcrusher_worm",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "sine_wave_sweep",
					"duration": 2.5,
					"cooldown": 2.5,
					"damage": SINE_DAMAGE * 1.3,
					"weight": 2.0,
				},
				{
					"name": "square_grid",
					"duration": 2.0,
					"cooldown": 2.5,
					"damage": SQUARE_DAMAGE * 1.3,
					"weight": 2.0,
				},
				{
					"name": "sawtooth_slash",
					"duration": 2.0,
					"cooldown": 3.0,
					"damage": SAW_DAMAGE * 1.3,
					"weight": 2.5,
				},
				{
					"name": "noise_burst",
					"duration": 1.5,
					"cooldown": 2.0,
					"damage": NOISE_DAMAGE * 1.3,
					"weight": 2.0,
				},
				{
					"name": "bitcrush_zone",
					"duration": 3.0,
					"cooldown": 5.0,
					"damage": 0.0,
					"weight": 1.5,
				},
			],
		},
		# 阶段三：频率风暴 (Frequency Storm) — 多波形叠加
		{
			"name": "频率风暴 · Frequency Storm",
			"hp_threshold": 0.35,
			"speed_mult": 1.4,
			"damage_mult": 1.6,
			"color": Color(0.9, 0.6, 0.1),
			"shield_hp": 0.0,
			"music_layer": "boss_noise_storm",
			"summon_enabled": true,
			"summon_count": 5,
			"summon_type": "ch7_glitch_phantom",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "waveform_combo",
					"duration": 3.5,
					"cooldown": 3.0,
					"damage": SINE_DAMAGE * 1.6,
					"weight": 3.0,
				},
				{
					"name": "frequency_sweep",
					"duration": 3.0,
					"cooldown": 3.5,
					"damage": SAW_DAMAGE * 1.6,
					"weight": 2.5,
				},
				{
					"name": "noise_burst",
					"duration": 1.5,
					"cooldown": 1.5,
					"damage": NOISE_DAMAGE * 1.6,
					"weight": 2.0,
				},
				{
					"name": "glitch_teleport_assault",
					"duration": 2.5,
					"cooldown": 4.0,
					"damage": SQUARE_DAMAGE * 1.6,
					"weight": 2.0,
				},
			],
		},
		# 阶段四：奇点 (Singularity) — 终极形态
		{
			"name": "奇点 · Singularity",
			"hp_threshold": 0.12,
			"speed_mult": 1.6,
			"damage_mult": 2.0,
			"color": Color(1.0, 1.0, 1.0),
			"shield_hp": 0.0,
			"music_layer": "boss_noise_singularity",
			"summon_enabled": true,
			"summon_count": 6,
			"summon_type": "ch7_bitcrusher_worm",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "singularity_collapse",
					"duration": 5.0,
					"cooldown": 5.0,
					"damage": SAW_DAMAGE * 2.5,
					"weight": 3.0,
				},
				{
					"name": "waveform_combo",
					"duration": 3.5,
					"cooldown": 2.0,
					"damage": SINE_DAMAGE * 2.0,
					"weight": 2.5,
				},
				{
					"name": "noise_burst",
					"duration": 1.5,
					"cooldown": 1.0,
					"damage": NOISE_DAMAGE * 2.0,
					"weight": 2.0,
				},
				{
					"name": "frequency_sweep",
					"duration": 3.0,
					"cooldown": 2.5,
					"damage": SAW_DAMAGE * 2.0,
					"weight": 2.0,
				},
			],
		},
	]

# ============================================================
# Boss 每帧逻辑
# ============================================================

func _on_boss_process(delta: float) -> void:
	# 波形自动切换（阶段二及以后）
	if _current_phase >= 1:
		_waveform_timer += delta
		if _waveform_timer >= _waveform_switch_interval:
			_waveform_timer = 0.0
			_switch_waveform()
	
	# 故障视觉更新
	_update_glitch_visual(delta)
	
	# 故障传送冷却
	if _glitch_teleport_timer > 0.0:
		_glitch_teleport_timer -= delta
	
	# 频率偏移
	if _freq_shift_active:
		_freq_shift_timer -= delta
		if _freq_shift_timer <= 0.0:
			_freq_shift_active = false
	if _freq_shift_cooldown > 0.0:
		_freq_shift_cooldown -= delta
	
	# 单一诅咒免疫
	if _monotone_immune:
		_monotone_immune_timer -= delta
		if _monotone_immune_timer <= 0.0:
			_monotone_immune = false
			_immune_timbre = ""
	
	# 残影更新
	_update_afterimages(delta)
	
	# 形态变化插值
	if _sprite:
		_sprite.scale = _sprite.scale.lerp(_form_target_scale, delta * 5.0)

func _switch_waveform() -> void:
	var old_waveform := _current_waveform
	# 随机选择不同的波形
	var new_waveform := _current_waveform
	while new_waveform == old_waveform:
		new_waveform = randi() % WaveformType.size() as WaveformType
	
	_current_waveform = new_waveform
	
	# 更新颜色
	var new_color: Color = _waveform_colors.get(_current_waveform, Color.WHITE)
	base_color = new_color
	
	# 切换视觉效果
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(_sprite, "modulate", new_color, 0.3)
	
	# 更新形态
	match _current_waveform:
		WaveformType.SINE:
			_form_target_scale = Vector2(1.2, 0.8)  # 椭圆
		WaveformType.SQUARE:
			_form_target_scale = Vector2(1.0, 1.0)  # 方形
		WaveformType.SAWTOOTH:
			_form_target_scale = Vector2(0.8, 1.3)  # 尖锐
		WaveformType.NOISE:
			_form_target_scale = Vector2(1.5, 1.5)  # 膨胀

func _update_glitch_visual(delta: float) -> void:
	# 故障强度随HP降低而增加
	var hp_ratio := current_hp / max_hp
	_glitch_intensity = (1.0 - hp_ratio) * 0.5
	
	_glitch_timer += delta
	if _glitch_timer >= 0.1:
		_glitch_timer = 0.0
		if _sprite and randf() < _glitch_intensity:
			# 随机偏移（故障效果）
			var offset := Vector2(randf_range(-5, 5), randf_range(-5, 5)) * _glitch_intensity
			_sprite.position = offset

func _update_afterimages(delta: float) -> void:
	for afterimage in _afterimages:
		if is_instance_valid(afterimage):
			afterimage.modulate.a -= delta * 2.0
			if afterimage.modulate.a <= 0.0:
				afterimage.queue_free()
	
	_afterimages = _afterimages.filter(func(n): return is_instance_valid(n))

# ============================================================
# 攻击实现
# ============================================================

func _perform_attack(attack: Dictionary) -> void:
	var config: Dictionary = _phase_configs[_current_phase] if _current_phase < _phase_configs.size() else {}
	var damage_mult: float = config.get("damage_mult", 1.0)
	
	match attack["name"]:
		"sine_wave_sweep":
			_attack_sine_wave_sweep(attack, damage_mult)
		"square_grid":
			_attack_square_grid(attack, damage_mult)
		"sawtooth_slash":
			_attack_sawtooth_slash(attack, damage_mult)
		"noise_burst":
			_attack_noise_burst(attack, damage_mult)
		"data_stream":
			_attack_data_stream(attack, damage_mult)
		"bitcrush_zone":
			_attack_bitcrush_zone(attack, damage_mult)
		"waveform_combo":
			_attack_waveform_combo(attack, damage_mult)
		"frequency_sweep":
			_attack_frequency_sweep(attack, damage_mult)
		"glitch_teleport_assault":
			_attack_glitch_teleport_assault(attack, damage_mult)
		"singularity_collapse":
			_attack_singularity_collapse(attack, damage_mult)

# ============================================================
# 攻击1：正弦波扫射 (Sine Wave Sweep)
# 弹幕沿正弦波轨迹移动
# ============================================================

func _attack_sine_wave_sweep(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", SINE_DAMAGE) * damage_mult
	
	if not _target or not is_instance_valid(_target):
		return
	
	var base_dir := (global_position.direction_to(_target.global_position))
	var base_angle := base_dir.angle()
	
	# 发射正弦波弹幕
	var count := 12
	for i in range(count):
		var delay := i * 0.1
		var phase_offset := i * 0.5
		
		get_tree().create_timer(delay).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			_spawn_sine_projectile(global_position, base_angle, 
				SINE_PROJECTILE_SPEED, damage * 0.5, phase_offset)
		)
	
	# 视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.4, 0.7), 0.15)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.3)

# ============================================================
# 攻击2：方波网格 (Square Grid)
# 生成网格状弹幕阵列
# ============================================================

func _attack_square_grid(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", SQUARE_DAMAGE) * damage_mult
	
	# 以Boss为中心生成方形网格弹幕
	var grid_count := 5
	var spacing := SQUARE_GRID_SIZE
	
	for x in range(-grid_count / 2, grid_count / 2 + 1):
		for y in range(-grid_count / 2, grid_count / 2 + 1):
			if x == 0 and y == 0:
				continue
			
			var offset := Vector2(x * spacing, y * spacing)
			var spawn_pos := global_position + offset
			
			# 延迟生成
			var delay := (abs(x) + abs(y)) * 0.1
			var pos_copy = spawn_pos
			
			get_tree().create_timer(delay).timeout.connect(func():
				if _is_dead or not is_instance_valid(self):
					return
				# 方形弹幕向外扩散
				var dir := offset.normalized()
				_spawn_square_projectile(pos_copy, dir.angle(),
					SQUARE_PROJECTILE_SPEED * 0.5, damage * 0.4)
			)

# ============================================================
# 攻击3：锯齿波斩击 (Sawtooth Slash) — 阶段二
# 锯齿形弹幕快速扫过战场
# ============================================================

func _attack_sawtooth_slash(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", SAW_DAMAGE) * damage_mult
	
	if not _target or not is_instance_valid(_target):
		return
	
	var dir := (global_position.direction_to(_target.global_position))
	var base_angle := dir.angle()
	
	# 锯齿形弹幕：交替上下偏移
	for i in range(SAW_TOOTH_COUNT):
		var delay := i * 0.12
		var offset_y := (20.0 if i % 2 == 0 else -20.0) * (1.0 + i * 0.2)
		
		get_tree().create_timer(delay).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			var perp := Vector2(-dir.y, dir.x)
			var spawn_pos := global_position + perp * offset_y
			_spawn_saw_projectile(spawn_pos, base_angle, SAW_SWEEP_SPEED, damage * 0.5)
		)

# ============================================================
# 攻击4：噪音爆发 (Noise Burst)
# 完全随机方向的弹幕爆发
# ============================================================

func _attack_noise_burst(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", NOISE_DAMAGE) * damage_mult
	
	for i in range(NOISE_BURST_COUNT):
		var angle := randf() * TAU
		var speed := NOISE_PROJECTILE_SPEED * randf_range(0.6, 1.4)
		var delay := randf() * 0.5
		
		get_tree().create_timer(delay).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			_spawn_noise_projectile(global_position, angle, speed, damage * 0.3)
		)
	
	# 故障视觉爆发
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.0, 0.5), 0.05)
		tween.tween_property(_sprite, "modulate", base_color, 0.2)

# ============================================================
# 攻击5：数据流 (Data Stream) — 阶段一
# 连续的定向弹幕流
# ============================================================

func _attack_data_stream(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", SINE_DAMAGE) * damage_mult
	var stream_count := 8
	
	for i in range(stream_count):
		get_tree().create_timer(i * 0.15).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			if not _target or not is_instance_valid(_target):
				return
			var dir := (global_position.direction_to(_target.global_position)).angle()
			dir += randf_range(-0.1, 0.1)
			_spawn_data_projectile(global_position, dir, 
				SINE_PROJECTILE_SPEED * 1.2, damage * 0.4)
		)

# ============================================================
# 攻击6：降采样区域 (Bitcrush Zone) — 阶段二
# 在战场上放置降低玩家伤害的区域
# ============================================================

func _attack_bitcrush_zone(_attack: Dictionary, _damage_mult: float) -> void:
	if not _target or not is_instance_valid(_target):
		return
	
	# 在玩家附近放置降采样区域
	var zone_pos := _target.global_position + Vector2.from_angle(randf() * TAU) * 80.0
	
	var zone := Polygon2D.new()
	var points := PackedVector2Array()
	# 像素化的方形区域
	var size := BITCRUSH_RADIUS
	points.append(Vector2(-size, -size))
	points.append(Vector2(size, -size))
	points.append(Vector2(size, size))
	points.append(Vector2(-size, size))
	zone.polygon = points
	zone.color = Color(0.0, 1.0, 0.5, 0.15)
	zone.global_position = zone_pos
	get_parent().add_child(zone)
	_bitcrush_zones.append(zone)
	
	# 像素化边框效果
	var tween := zone.create_tween().set_loops()
	tween.tween_property(zone, "modulate:a", 0.6, 0.3)
	tween.tween_property(zone, "modulate:a", 0.2, 0.3)
	
	# 持续时间后消失
	get_tree().create_timer(8.0).timeout.connect(func():
		if is_instance_valid(zone):
			var fade := zone.create_tween()
			fade.tween_property(zone, "modulate:a", 0.0, 0.5)
			fade.tween_callback(zone.queue_free)
	)

## 检查玩家是否在降采样区域内
func is_player_in_bitcrush() -> bool:
	if not _target or not is_instance_valid(_target):
		return false
	
	for zone in _bitcrush_zones:
		if is_instance_valid(zone):
			if _target.global_position.distance_to(zone.global_position) < BITCRUSH_RADIUS:
				return true
	return false

# ============================================================
# 攻击7：波形组合 (Waveform Combo) — 阶段三
# 同时释放多种波形的弹幕
# ============================================================

func _attack_waveform_combo(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", SINE_DAMAGE) * damage_mult
	
	# 同时释放四种波形弹幕
	_attack_sine_wave_sweep({"damage": damage * 0.4}, 1.0)
	
	get_tree().create_timer(0.5).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			return
		_attack_noise_burst({"damage": damage * 0.3}, 1.0)
	)
	
	get_tree().create_timer(1.0).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			return
		_attack_square_grid({"damage": damage * 0.3}, 1.0)
	)

# ============================================================
# 攻击8：频率扫射 (Frequency Sweep) — 阶段三
# 弹幕速度从极慢到极快变化
# ============================================================

func _attack_frequency_sweep(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", SAW_DAMAGE) * damage_mult
	var sweep_count := 15
	
	for i in range(sweep_count):
		var delay := i * 0.15
		var speed_ratio := float(i) / sweep_count  # 0.0 → 1.0
		var speed := lerp(80.0, 350.0, speed_ratio)
		
		get_tree().create_timer(delay).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			if not _target or not is_instance_valid(_target):
				return
			var dir := (global_position.direction_to(_target.global_position)).angle()
			_spawn_data_projectile(global_position, dir, speed, damage * 0.3)
		)

# ============================================================
# 攻击9：故障传送突袭 (Glitch Teleport Assault) — 阶段三
# 快速传送并在每个位置释放弹幕
# ============================================================

func _attack_glitch_teleport_assault(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", SQUARE_DAMAGE) * damage_mult
	var teleport_count := 4
	
	for i in range(teleport_count):
		get_tree().create_timer(i * 0.5).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			
			# 留下残影
			_spawn_afterimage()
			
			# 传送到玩家附近
			if _target and is_instance_valid(_target):
				var offset := Vector2.from_angle(randf() * TAU) * randf_range(100, 200)
				global_position = _target.global_position + offset
			
			# 释放环形弹幕
			for j in range(8):
				var angle := (TAU / 8) * j
				_spawn_noise_projectile(global_position, angle,
					NOISE_PROJECTILE_SPEED, damage * 0.3)
		)

func _spawn_afterimage() -> void:
	if _sprite == null:
		return
	
	var afterimage := Polygon2D.new()
	# 简单的方形残影
	afterimage.polygon = PackedVector2Array([
		Vector2(-15, -15), Vector2(15, -15), Vector2(15, 15), Vector2(-15, 15)
	])
	afterimage.color = base_color
	afterimage.modulate.a = 0.5
	afterimage.global_position = global_position
	afterimage.scale = _sprite.scale
	get_parent().add_child(afterimage)
	_afterimages.append(afterimage)

# ============================================================
# 攻击10：奇点坍缩 (Singularity Collapse) — 阶段四终极攻击
# 全屏吸引 + 大爆炸
# ============================================================

func _attack_singularity_collapse(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", SAW_DAMAGE * 2.5) * damage_mult
	
	# 阶段1：收缩（2秒）— 吸引玩家
	_form_target_scale = Vector2(0.3, 0.3)
	
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 1.0)
	
	# 吸引效果
	var pull_timer := 0.0
	var pull_callable := func():
		if not is_instance_valid(self) or _is_dead:
			return
		pull_timer += get_process_delta_time()
		if pull_timer >= 2.5:
			return
		if _target and is_instance_valid(_target):
			var dir := (global_position - _target.global_position).normalized()
			if _target.has_method("apply_external_force"):
				_target.apply_external_force(dir * 150.0)
			else:
				_target.global_position += dir * 80.0 * get_process_delta_time()
	
	get_tree().process_frame.connect(pull_callable)
	
	# 阶段2：爆发（2.5秒后）
	get_tree().create_timer(2.5).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			if get_tree().process_frame.is_connected(pull_callable):
				get_tree().process_frame.disconnect(pull_callable)
			return
		
		if get_tree().process_frame.is_connected(pull_callable):
			get_tree().process_frame.disconnect(pull_callable)
		
		# 大爆炸
		_form_target_scale = Vector2(3.0, 3.0)
		
		# 全方位弹幕爆发
		for ring in range(3):
			var count := 16 + ring * 4
			for i in range(count):
				var angle := (TAU / count) * i + ring * 0.1
				var speed := 120.0 + ring * 60.0
				_spawn_noise_projectile(global_position, angle, speed, damage * 0.15)
		
		# 冲击波
		_spawn_shockwave(global_position, 400.0, damage * 0.5)
		
		# 恢复正常大小
		get_tree().create_timer(0.5).timeout.connect(func():
			_form_target_scale = Vector2.ONE
			if _sprite:
				var tween2 := create_tween()
				tween2.tween_property(_sprite, "modulate", base_color, 0.5)
		)
	)

# ============================================================
# 单一诅咒系统 (The Monotone Curse)
# ============================================================

## 外部调用：记录玩家使用的音色
func register_player_timbre(timbre: String) -> void:
	if timbre == _last_timbre_used:
		_same_timbre_count += 1
	else:
		_same_timbre_count = 1
		_last_timbre_used = timbre
	
	if _same_timbre_count >= MONOTONE_THRESHOLD:
		_trigger_monotone_curse(timbre)

func _trigger_monotone_curse(timbre: String) -> void:
	_monotone_immune = true
	_monotone_immune_timer = MONOTONE_IMMUNITY_DURATION
	_immune_timbre = timbre
	_same_timbre_count = 0
	
	# 视觉：适应效果
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(0.5, 0.5, 0.5), 0.2)
		tween.tween_property(_sprite, "modulate", base_color, MONOTONE_IMMUNITY_DURATION)

## 重写伤害处理：单一诅咒免疫
func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	# 降采样区域内玩家伤害降低
	var final_amount := amount
	if is_player_in_bitcrush():
		final_amount *= BITCRUSH_DAMAGE_REDUCTION
	
	super.take_damage(final_amount, knockback_dir, is_perfect_beat)

# ============================================================
# 弹幕生成辅助
# ============================================================

func _spawn_sine_projectile(pos: Vector2, angle: float, speed: float, damage: float, phase_offset: float = 0.0) -> void:
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	proj.collision_layer = 8
	proj.collision_mask = 1
	
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-6, 0), Vector2(-3, -4), Vector2(3, -4),
		Vector2(6, 0), Vector2(3, 4), Vector2(-3, 4)
	])
	visual.color = _waveform_colors[WaveformType.SINE]
	proj.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	proj.add_child(col)
	
	proj.global_position = pos
	proj.set_meta("base_angle", angle)
	proj.set_meta("speed", speed)
	proj.set_meta("damage", damage)
	proj.set_meta("lifetime", 5.0)
	proj.set_meta("age", 0.0)
	proj.set_meta("phase_offset", phase_offset)
	proj.set_meta("wave_type", "sine")
	
	_add_projectile_to_container(proj, true)

func _spawn_square_projectile(pos: Vector2, angle: float, speed: float, damage: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	proj.collision_layer = 8
	proj.collision_mask = 1
	
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)
	])
	visual.color = _waveform_colors[WaveformType.SQUARE]
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
	
	_add_projectile_to_container(proj, false)

func _spawn_saw_projectile(pos: Vector2, angle: float, speed: float, damage: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	proj.collision_layer = 8
	proj.collision_mask = 1
	
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-8, 4), Vector2(0, -6), Vector2(8, 4)
	])
	visual.color = _waveform_colors[WaveformType.SAWTOOTH]
	visual.rotation = angle
	proj.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	col.shape = shape
	proj.add_child(col)
	
	proj.global_position = pos
	proj.set_meta("velocity", Vector2.from_angle(angle) * speed)
	proj.set_meta("damage", damage)
	proj.set_meta("lifetime", 4.0)
	proj.set_meta("age", 0.0)
	
	_add_projectile_to_container(proj, false)

func _spawn_noise_projectile(pos: Vector2, angle: float, speed: float, damage: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	proj.collision_layer = 8
	proj.collision_mask = 1
	
	# 随机形状（噪音感）
	var visual := Polygon2D.new()
	var point_count := randi_range(3, 6)
	var points := PackedVector2Array()
	for i in range(point_count):
		var a := (TAU / point_count) * i + randf() * 0.5
		var r := randf_range(3.0, 7.0)
		points.append(Vector2.from_angle(a) * r)
	visual.polygon = points
	visual.color = _waveform_colors[WaveformType.NOISE]
	proj.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	proj.add_child(col)
	
	proj.global_position = pos
	proj.set_meta("velocity", Vector2.from_angle(angle) * speed)
	proj.set_meta("damage", damage)
	proj.set_meta("lifetime", 4.0)
	proj.set_meta("age", 0.0)
	
	_add_projectile_to_container(proj, false)

func _spawn_data_projectile(pos: Vector2, angle: float, speed: float, damage: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	proj.collision_layer = 8
	proj.collision_mask = 1
	
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
	])
	visual.color = Color(0.0, 1.0, 0.8, 0.8)
	proj.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	col.shape = shape
	proj.add_child(col)
	
	proj.global_position = pos
	proj.set_meta("velocity", Vector2.from_angle(angle) * speed)
	proj.set_meta("damage", damage)
	proj.set_meta("lifetime", 5.0)
	proj.set_meta("age", 0.0)
	
	_add_projectile_to_container(proj, false)

func _add_projectile_to_container(proj: Area2D, is_sine: bool) -> void:
	if _projectile_container and is_instance_valid(_projectile_container):
		_projectile_container.add_child(proj)
	else:
		get_parent().add_child(proj)
	
	var move_callable: Callable
	if is_sine:
		# 正弦波轨迹
		move_callable = func():
			if not is_instance_valid(proj):
				return
			var age: float = proj.get_meta("age") + get_process_delta_time()
			proj.set_meta("age", age)
			if age >= proj.get_meta("lifetime"):
				proj.queue_free()
				return
			var base_angle: float = proj.get_meta("base_angle")
			var speed: float = proj.get_meta("speed")
			var phase: float = proj.get_meta("phase_offset")
			var forward := Vector2.from_angle(base_angle) * speed
			var perp := Vector2(-forward.y, forward.x).normalized()
			var sine_offset := sin(age * SINE_WAVE_FREQUENCY + phase) * SINE_WAVE_AMPLITUDE
			proj.global_position += (forward + perp * sine_offset * 0.1) * get_process_delta_time()
			if _target and is_instance_valid(_target):
				if proj.global_position.distance_to(_target.global_position) < 18.0:
					if _target.has_method("take_damage"):
						_target.take_damage(proj.get_meta("damage"))
					proj.queue_free()
	else:
		# 直线轨迹
		move_callable = func():
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
				if proj.global_position.distance_to(_target.global_position) < 18.0:
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
	ring.color = base_color
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
			_current_waveform = WaveformType.SINE
			_waveform_switch_interval = 999.0  # 阶段一不切换
		1:
			_waveform_switch_interval = 12.0
			_switch_waveform()
		2:
			_waveform_switch_interval = 8.0
			_summon_cooldown_time = 12.0
		3:
			# 奇点阶段：极快切换
			_waveform_switch_interval = 4.0
			_summon_cooldown_time = 8.0
			# 清除所有弹幕
			if _projectile_container:
				for child in _projectile_container.get_children():
					child.queue_free()
			# 清除降采样区域
			for zone in _bitcrush_zones:
				if is_instance_valid(zone):
					zone.queue_free()
			_bitcrush_zones.clear()

# ============================================================
# 狂暴回调
# ============================================================

func _on_enrage(level: int) -> void:
	match level:
		1:
			base_color = base_color.lerp(Color(1.0, 0.3, 0.0), 0.3)
			_waveform_switch_interval *= 0.7
		2:
			base_color = Color(1.0, 0.0, 0.0)
			_start_enrage_noise()

func _start_enrage_noise() -> void:
	get_tree().create_timer(0.3).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			return
		# 持续噪音弹幕
		for i in range(5):
			var angle := randf() * TAU
			_spawn_noise_projectile(global_position, angle,
				NOISE_PROJECTILE_SPEED * 0.8, 10.0)
		if _enrage_level >= 2 and not _is_dead:
			_start_enrage_noise()
	)

# ============================================================
# 节拍回调
# ============================================================

func _on_boss_beat(_beat_index: int) -> void:
	_noise_beat_counter += 1
	
	# 每 2 拍在非攻击状态时发射波形弹幕
	if not _is_attacking and _noise_beat_counter % 2 == 0:
		if _target and not _is_dead:
			var angle := (_target.global_position - global_position).angle()
			match _current_waveform:
				WaveformType.SINE:
					_spawn_sine_projectile(global_position, angle,
						SINE_PROJECTILE_SPEED * 0.5, 6.0)
				WaveformType.SQUARE:
					_spawn_square_projectile(global_position, angle,
						SQUARE_PROJECTILE_SPEED * 0.5, 7.0)
				WaveformType.SAWTOOTH:
					_spawn_saw_projectile(global_position, angle,
						SAW_SWEEP_SPEED * 0.5, 8.0)
				WaveformType.NOISE:
					_spawn_noise_projectile(global_position, randf() * TAU,
						NOISE_PROJECTILE_SPEED * 0.5, 5.0)

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	var dir := (_target.global_position - global_position)
	var dist := dir.length()
	
	# 根据波形改变移动模式
	match _current_waveform:
		WaveformType.SINE:
			# 正弦波移动：平滑曲线
			var time := Time.get_ticks_msec() * 0.001
			return Vector2(cos(time * 2.0), sin(time * 3.0)).normalized()
		WaveformType.SQUARE:
			# 方波移动：只走直线（水平/垂直）
			if abs(dir.x) > abs(dir.y):
				return Vector2(sign(dir.x), 0)
			else:
				return Vector2(0, sign(dir.y))
		WaveformType.SAWTOOTH:
			# 锯齿波：快速冲刺
			if dist > 200.0:
				return dir.normalized()
			else:
				return -dir.normalized()
		WaveformType.NOISE:
			# 噪音：随机移动
			return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	return Vector2.ZERO

# ============================================================
# 类型名称
# ============================================================

func _get_type_name() -> String:
	return "boss_noise"

# ============================================================
# 清理
# ============================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _projectile_container and is_instance_valid(_projectile_container):
			for child in _projectile_container.get_children():
				if is_instance_valid(child):
					child.queue_free()
		for zone in _bitcrush_zones:
			if is_instance_valid(zone):
				zone.queue_free()
		for afterimage in _afterimages:
			if is_instance_valid(afterimage):
				afterimage.queue_free()
