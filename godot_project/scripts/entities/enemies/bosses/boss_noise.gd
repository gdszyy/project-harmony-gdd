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
## 风格排斥：无
## 在这场最终的战斗中，任何策略都是被允许的，只要你能活下来。
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

## 最终阶段参数
const SPECTRUM_COLLAPSE_THRESHOLD: float = 0.1  # HP < 10% 触发频谱崩溃
var _is_spectrum_collapse: bool = false
var _final_chord_timer: float = 0.0
const FINAL_CHORD_DELAY: float = 4.0  # 减十三和弦延迟 4 拍

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

## 相位系统
# 1 = 低通, 2 = 高通, 3 = 全频
var _current_player_phase: int = 3

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
	max_hp = 10000.0
	current_hp = 10000.0
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
	
		# 频谱崩溃阶段逻辑
		if _is_spectrum_collapse:
			_update_spectrum_collapse(delta)
			return # 崩溃阶段停止常规逻辑
	
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
			_form_target_scale = Vector2(1.5, 1.5)  # 混沌放大
	
	# 播放切换音效
	AudioManager.play_sfx("boss_noise_waveform_switch", global_position)

# ============================================================
# 核心攻击逻辑
# ============================================================

## 正弦波扫射
func _attack_sine_wave_sweep(attack_data: Dictionary) -> void:
	var num_projectiles := 24
	var angle_step := 2.0 * PI / num_projectiles
	var base_angle := randf_range(0, 2 * PI)
	
	for i in range(num_projectiles):
		var angle := base_angle + i * angle_step
		var spawn_pos := global_position + Vector2.from_angle(angle) * 80.0
		var proj := ProjectileManager.spawn_projectile({
			"name": "NoiseSineWave",
			"type": "enemy",
			"texture": "res://assets/projectiles/projectile_sine.png",
			"position": spawn_pos,
			"velocity": Vector2.from_angle(angle) * SINE_PROJECTILE_SPEED,
			"damage": attack_data.damage,
			"scale": 1.2,
			"lifetime": 5.0,
			"collision_radius": 12.0,
			"homing_factor": 0.0,
			"custom_logic": "sine_wave_movement",
			"custom_data": {
				"amplitude": SINE_WAVE_AMPLITUDE,
				"frequency": SINE_WAVE_FREQUENCY,
				"phase_offset": i * 0.2
			}
		})
		if proj:
			_projectile_container.add_child(proj)
	
	AudioManager.play_sfx("boss_noise_sine_attack", global_position)

## 方波网格
func _attack_square_grid(attack_data: Dictionary) -> void:
	var grid_size := 8
	var spacing := SQUARE_GRID_SIZE
	var start_pos := _target.global_position - Vector2(spacing * (grid_size - 1) / 2.0, spacing * (grid_size - 1) / 2.0)
	
	for y in range(grid_size):
		for x in range(grid_size):
			# 棋盘格模式
			if (x + y) % 2 == 0:
				continue
			
			var spawn_pos := start_pos + Vector2(x * spacing, y * spacing)
			var proj := ProjectileManager.spawn_projectile({
				"name": "NoiseSquare",
				"type": "enemy",
				"texture": "res://assets/projectiles/projectile_square.png",
				"position": spawn_pos,
				"velocity": Vector2.ZERO, # 静止
				"damage": attack_data.damage,
				"scale": 1.5,
				"lifetime": 2.0,
				"collision_radius": 18.0,
				"fade_in_duration": 0.5,
			})
			if proj:
				_projectile_container.add_child(proj)
	
	AudioManager.play_sfx("boss_noise_square_attack", global_position)

## 锯齿波斩击
func _attack_sawtooth_slash(attack_data: Dictionary) -> void:
	var num_slashes := 3
	var slash_delay := 0.3
	
	for i in range(num_slashes):
		var angle := (_target.global_position - global_position).angle() + randf_range(-0.4, 0.4)
		var spawn_pos := global_position
		
		var tween := create_tween()
		tween.set_delay(i * slash_delay)
		tween.tween_callback(func():
			for j in range(SAW_TOOTH_COUNT):
				var tooth_angle := angle + (j - SAW_TOOTH_COUNT / 2.0) * 0.15
				var proj := ProjectileManager.spawn_projectile({
					"name": "NoiseSawtooth",
					"type": "enemy",
					"texture": "res://assets/projectiles/projectile_saw.png",
					"position": spawn_pos,
					"velocity": Vector2.from_angle(tooth_angle) * SAW_SWEEP_SPEED,
					"damage": attack_data.damage,
					"scale": 1.3,
					"lifetime": 3.0,
					"collision_radius": 14.0,
				})
				if proj:
					_projectile_container.add_child(proj)
			AudioManager.play_sfx("boss_noise_saw_attack", global_position)
		)

## 噪音爆发
func _attack_noise_burst(attack_data: Dictionary) -> void:
	for _i in range(NOISE_BURST_COUNT):
		var angle := randf_range(0, 2 * PI)
		var speed := randf_range(0.8, 1.2) * NOISE_PROJECTILE_SPEED
		var spawn_pos := global_position
		
		var proj := ProjectileManager.spawn_projectile({
			"name": "NoiseParticle",
			"type": "enemy",
			"texture": "res://assets/projectiles/projectile_noise.png",
			"position": spawn_pos,
			"velocity": Vector2.from_angle(angle) * speed,
			"damage": attack_data.damage,
			"scale": randf_range(0.8, 1.5),
			"lifetime": 2.5,
			"collision_radius": 10.0,
			"custom_logic": "random_walk",
			"custom_data": {
				"turn_speed": randf_range(2.0, 5.0)
			}
		})
		if proj:
			_projectile_container.add_child(proj)
	
	AudioManager.play_sfx("boss_noise_burst_attack", global_position)

## 数据流（追踪弹幕）
func _attack_data_stream(attack_data: Dictionary) -> void:
	var num_streams := 5
	var stream_delay := 0.2
	
	for i in range(num_streams):
		var tween := create_tween()
		tween.set_delay(i * stream_delay)
		tween.tween_callback(func():
			var angle := randf_range(0, 2 * PI)
			var spawn_pos := global_position + Vector2.from_angle(angle) * 100.0
			var proj := ProjectileManager.spawn_projectile({
				"name": "DataStream",
				"type": "enemy",
				"texture": "res://assets/projectiles/projectile_stream.png",
				"position": spawn_pos,
				"velocity": (_target.global_position - spawn_pos).normalized() * SINE_PROJECTILE_SPEED * 0.8,
				"damage": attack_data.damage,
				"scale": 1.0,
				"lifetime": 6.0,
				"collision_radius": 10.0,
				"homing_factor": 0.3,
				"homing_target": _target
			})
			if proj:
				_projectile_container.add_child(proj)
			AudioManager.play_sfx("boss_noise_stream_attack", global_position)
		)

## 降采样区域
func _attack_bitcrush_zone(_attack_data: Dictionary) -> void:
	var num_zones := 2
	for _i in range(num_zones):
		var zone := Area2D.new()
		var shape := CircleShape2D.new()
		shape.radius = BITCRUSH_RADIUS
		var col := CollisionShape2D.new()
		col.shape = shape
		zone.add_child(col)
		
		var spawn_pos := _target.global_position + Vector2(randf_range(-300, 300), randf_range(-300, 300))
		zone.global_position = spawn_pos
		
		# 视觉效果
		var visual := Polygon2D.new()
		var points: PackedVector2Array
		for i in range(32):
			var angle := i / 32.0 * 2 * PI
			points.append(Vector2.from_angle(angle) * BITCRUSH_RADIUS)
		visual.polygon = points
		visual.color = Color(0.5, 0.2, 0.8, 0.3)
		zone.add_child(visual)
		
		add_child(zone)
		_bitcrush_zones.append(zone)
		
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 4.0).from(0.4)
		tween.tween_callback(func():
			_bitcrush_zones.erase(zone)
			zone.queue_free()
		)
	
	AudioManager.play_sfx("boss_noise_bitcrush_spawn", global_position)

## 故障传送突袭
func _attack_glitch_teleport_assault(attack_data: Dictionary) -> void:
	if _glitch_teleport_timer > 0.0:
		return
	
	_glitch_teleport_timer = GLITCH_TELEPORT_COOLDOWN
	
	var original_pos := global_position
	
	# 创建残影
	for i in range(GLITCH_AFTERIMAGE_COUNT):
		var afterimage := Polygon2D.new()
		afterimage.polygon = _sprite.polygon
		afterimage.material = _sprite.material
		afterimage.global_position = global_position
		afterimage.rotation = _sprite.rotation
		afterimage.scale = _sprite.scale
		afterimage.modulate = Color(1,1,1, 0.5 - i * 0.1)
		get_parent().add_child(afterimage)
		
		var tween := create_tween()
		tween.tween_property(afterimage, "modulate:a", 0.0, 0.5).set_delay(i * 0.1)
		tween.tween_callback(afterimage.queue_free)
	
	# 传送到玩家附近
	var target_pos := _target.global_position + Vector2(randf_range(-150, 150), randf_range(-150, 150))
	global_position = target_pos
	
	# 传送后立即发动一次噪音爆发
	_attack_noise_burst(attack_data)
	
	AudioManager.play_sfx("boss_noise_teleport", original_pos)
	AudioManager.play_sfx("boss_noise_teleport_reappear", global_position)

## 波形组合技
func _attack_waveform_combo(attack_data: Dictionary) -> void:
	# 正弦波背景
	_attack_sine_wave_sweep(attack_data)
	
	# 延迟发动方波
	var tween := create_tween()
	tween.set_delay(0.5)
	tween.tween_callback(func():
		_attack_square_grid(attack_data)
	)

## 频率扫描
func _attack_frequency_sweep(attack_data: Dictionary) -> void:
	var sweep_arc := PI * 1.5
	var sweep_duration := 2.0
	var start_angle := (_target.global_position - global_position).angle() - sweep_arc / 2.0
	
	var sweep_node := Node2D.new()
	add_child(sweep_node)
	sweep_node.global_position = global_position
	
	var tween := create_tween()
	tween.tween_property(sweep_node, "rotation", sweep_arc, sweep_duration).from(0.0)
	tween.tween_callback(sweep_node.queue_free)
	
	var fire_timer := Timer.new()
	fire_timer.wait_time = 0.05
	fire_timer.autostart = true
	sweep_node.add_child(fire_timer)
	
	fire_timer.timeout.connect(func():
		var angle := start_angle + sweep_node.rotation
		var proj := ProjectileManager.spawn_projectile({
			"name": "FreqSweep",
			"type": "enemy",
			"texture": "res://assets/projectiles/projectile_saw.png",
			"position": global_position,
			"velocity": Vector2.from_angle(angle) * SAW_SWEEP_SPEED * 1.2,
			"damage": attack_data.damage,
			"scale": 1.1,
			"lifetime": 3.0,
			"collision_radius": 13.0,
		})
		if proj:
			_projectile_container.add_child(proj)
	)
	
	AudioManager.play_sfx("boss_noise_sweep_start", global_position)

## 奇点坍缩
func _attack_singularity_collapse(attack_data: Dictionary) -> void:
	# 全屏吸附
	var pull_center := global_position
	var pull_strength := 400.0
	var pull_duration := 4.0
	
	# 创建视觉效果
	var vortex := Polygon2D.new()
	var points: PackedVector2Array
	for i in range(64):
		var angle := i / 64.0 * 2 * PI
		points.append(Vector2.from_angle(angle) * 20.0)
	vortex.polygon = points
	vortex.color = Color(0.1, 0.1, 0.1, 0.8)
	vortex.global_position = pull_center
	add_child(vortex)
	
	var tween := create_tween().set_parallel()
	tween.tween_property(vortex, "scale", Vector2.ONE * 50, pull_duration)
	tween.tween_property(vortex, "modulate:a", 0.0, pull_duration).from(0.9)
	tween.tween_callback(vortex.queue_free)
	
	# 施加引力
	GameManager.get_player().apply_central_force(pull_center, pull_strength, pull_duration)
	
	# 延迟爆发
	var explosion_tween := create_tween()
	explosion_tween.set_delay(pull_duration)
	explosion_tween.tween_callback(func():
		for i in range(100):
			var angle := randf_range(0, 2 * PI)
			var speed := randf_range(200, 400)
			var proj := ProjectileManager.spawn_projectile({
				"name": "SingularityFragment",
				"type": "enemy",
				"texture": "res://assets/projectiles/projectile_noise.png",
				"position": pull_center,
				"velocity": Vector2.from_angle(angle) * speed,
				"damage": attack_data.damage,
				"scale": randf_range(1.0, 2.0),
				"lifetime": 4.0,
				"collision_radius": 15.0,
			})
			if proj:
				_projectile_container.add_child(proj)
		
		# 屏幕震动
		GameManager.camera_shake(1.5, 0.8)
		AudioManager.play_sfx("boss_noise_singularity_explode", pull_center)
	)
	
	AudioManager.play_sfx("boss_noise_singularity_pull", pull_center)

# ============================================================
# 节拍 & 阶段 & 伤害 & 死亡
# ============================================================

func _on_beat(beat_index: int) -> void:
	_noise_beat_counter += 1
	
	# 频谱崩溃阶段的特殊节拍逻辑
	if _is_spectrum_collapse:
		_final_chord_timer += 1
		# 减十三和弦的节拍触发
		if _final_chord_timer == FINAL_CHORD_DELAY:
			_play_diminished_13th_chord()
			# 之后每拍都尝试触发，直到Boss死亡
			_final_chord_timer = FINAL_CHORD_DELAY - 1 
		return
	
	# 每 4 拍执行一次频率偏移
	if _noise_beat_counter % 4 == 0 and _freq_shift_cooldown <= 0.0:
		_start_frequency_shift()

func _on_phase_changed(new_phase_index: int, old_phase_index: int) -> void:
	super._on_phase_changed(new_phase_index, old_phase_index)
	
	# 进入波形切换阶段
	if new_phase_index == 1:
		_waveform_switch_interval = 10.0
		_switch_waveform()
	
	# 进入频率风暴阶段
	if new_phase_index == 2:
		_waveform_switch_interval = 7.0
		_freq_shift_cooldown = 0.0 # 立刻允许频率偏移
		_start_frequency_shift()
	
	# 进入奇点阶段
	if new_phase_index == 3:
		_waveform_switch_interval = 5.0
		# 停止所有现有弹幕
		for child in _projectile_container.get_children():
			child.queue_free()
		# 立即发动一次奇点坍缩
		_attack_singularity_collapse(_get_current_attack_data("singularity_collapse"))

func take_damage(damage_info: Dictionary) -> void:
	# 根据波形调整伤害
	var timbre_type = damage_info.get("timbre_type", "default")
	var damage_multiplier := 1.0
	
	match _current_waveform:
		WaveformType.SINE:
			if timbre_type == "square": damage_multiplier = 1.5 # 方波克制正弦波
		WaveformType.SQUARE:
			if timbre_type == "sawtooth": damage_multiplier = 1.5 # 锯齿波克制方波
		WaveformType.SAWTOOTH:
			if timbre_type == "sine": damage_multiplier = 1.5 # 正弦波克制锯齿波
		WaveformType.NOISE:
			if timbre_type == "noise": damage_multiplier = 1.5 # 噪音波互相克制
	
	# 频率偏移期间，伤害减半
	if _freq_shift_active:
		damage_multiplier *= 0.5
	
	var final_damage_info := damage_info.duplicate()
	final_damage_info["amount"] *= damage_multiplier
	
	super.take_damage(final_damage_info)
	
	# 检查是否进入频谱崩溃
	if not _is_spectrum_collapse and current_hp / max_hp <= SPECTRUM_COLLAPSE_THRESHOLD:
		_start_spectrum_collapse()

func _on_death() -> void:
	# 停止所有攻击
	_stop_all_attacks()
	
	# 清除所有弹幕和效果
	for child in _projectile_container.get_children():
		child.queue_free()
	for zone in _bitcrush_zones:
		zone.queue_free()
	_bitcrush_zones.clear()
	
	# 停止音乐，播放死亡音效
	BGMManager.stop_all_music(2.0)
	AudioManager.play_sfx("boss_noise_death", global_position)
	
	# 死亡视觉效果：数字瓦解
	var death_tween := create_tween()
	death_tween.tween_property(_sprite.material, "shader_parameter/pixel_size", 20.0, 2.0).from(1.0)
	death_tween.tween_property(_sprite, "modulate:a", 0.0, 2.5).from(1.0)
	death_tween.tween_callback(func():
		.die() # 调用基类死亡处理
	)

# ============================================================
# 特殊机制
# ============================================================

## 频率偏移
func _start_frequency_shift() -> void:
	_freq_shift_active = true
	_freq_shift_timer = FREQ_SHIFT_DURATION
	_freq_shift_cooldown = FREQ_SHIFT_INTERVAL
	
	# 视觉效果
	var tween := create_tween()
	tween.tween_property(_sprite.material, "shader_parameter/chromatic_offset", 15.0, 0.3)
	tween.tween_property(_sprite.material, "shader_parameter/chromatic_offset", 2.0, FREQ_SHIFT_DURATION).set_delay(0.3)
	
	AudioManager.play_sfx("boss_noise_freq_shift", global_position)

## 频谱崩溃（最终阶段）
func _start_spectrum_collapse() -> void:
	_is_spectrum_collapse = true
	_stop_all_attacks()
	
	# 视觉：变成纯白，剧烈抖动
	base_color = Color.WHITE
	_glitch_intensity = 1.0
	max_glitch_intensity = 1.0
	
	# 音乐：进入最终的减十三和弦背景
	BGMManager.play_music_layer("boss_noise_final_chord_bg", true)
	
	# 禁用移动
	move_speed = 0.0
	
	# 重置节拍器，准备最终和弦
	_final_chord_timer = 0

func _update_spectrum_collapse(_delta: float) -> void:
	# 持续的屏幕震动和视觉故障
	GameManager.camera_shake(0.2, 0.1)
	_glitch_intensity = 1.0
	_update_glitch_visual(_delta)

## 播放减十三和弦（秒杀技）
func _play_diminished_13th_chord() -> void:
	# 对玩家造成巨大伤害
	var player := GameManager.get_player()
	if player:
		player.take_damage({
			"amount": 9999,
			"type": "spectral",
			"source": self
		})
	
	# 播放毁灭性的和弦音效
	AudioManager.play_sfx("boss_noise_dim13_chord", global_position)
	
	# 屏幕白闪
	GameManager.screen_flash(Color.WHITE, 0.8)

# ============================================================
# 视觉效果 & 辅助函数
# ============================================================

func _update_glitch_visual(delta: float) -> void:
	_glitch_timer += delta
	
	var material: ShaderMaterial = _sprite.material
	if not material:
		return
	
	# 基础故障强度
	var hp_ratio := current_hp / max_hp
	_hp_glitch_intensity = (1.0 - hp_ratio) * max_glitch_intensity
	_glitch_intensity = base_glitch_intensity + _hp_glitch_intensity
	
	# 频率偏移时故障加剧
	if _freq_shift_active:
		_glitch_intensity = min(_glitch_intensity + 0.5, 1.0)
	
	material.set_shader_parameter("glitch_intensity", _glitch_intensity)
	material.set_shader_parameter("hp_ratio", hp_ratio)
	material.set_shader_parameter("base_tint", base_color)

func _update_afterimages(delta: float) -> void:
	# 清理旧的残影
	_afterimages = _afterimages.filter(func(img): return is_instance_valid(img))
	
	# 每隔一段时间创建新残影
	# (逻辑可根据需要添加)

func _get_type_name() -> String:
	return "BossNoise"


# ============================================================
# 自定义弹幕逻辑
# ============================================================

## 挂载到 ProjectileManager 的自定义逻辑
func _get_custom_projectile_logics() -> Dictionary:
	return {
		"sine_wave_movement": Callable(self, "_sine_wave_projectile_logic"),
		"random_walk": Callable(self, "_random_walk_projectile_logic"),
	}

func _sine_wave_projectile_logic(proj: Node2D) -> void:
	var age: float = proj.get_meta("age")
	var base_angle: float = proj.get_meta("base_angle")
	var speed: float = proj.get_meta("speed")
	var phase: float = proj.get_meta("phase_offset")
	var forward := Vector2.from_angle(base_angle) * speed
	var perp := Vector2(-forward.y, forward.x).normalized()
	var sine_offset := sin(age * SINE_WAVE_FREQUENCY + phase) * SINE_WAVE_AMPLITUDE
	proj.global_position += (forward + perp * sine_offset * 0.1) * get_process_delta_time()
	
	# 检查相位：正弦波只在低通(1)和全频(3)生效
	var is_active = (_current_player_phase == 1 or _current_player_phase == 3)
	if _is_spectrum_collapse: is_active = true # 崩溃阶段全部生效
	
	if not is_active:
		proj.modulate.a = 0.2
	else:
		proj.modulate.a = 1.0

func _random_walk_projectile_logic(proj: Node2D) -> void:
	var turn_speed: float = proj.get_meta("turn_speed")
	var velocity: Vector2 = proj.get("velocity") # 假设速度存储在弹丸上
	
	var angle_change := randf_range(-1.0, 1.0) * turn_speed * get_process_delta_time()
	var new_velocity := velocity.rotated(angle_change)
	
	proj.set("velocity", new_velocity)
	proj.global_position += new_velocity * get_process_delta_time()

# ============================================================
# 玩家相位系统交互
# ============================================================

func _on_player_phase_changed(phase_id: int) -> void:
	_current_player_phase = phase_id
	
	# 根据玩家相位调整 Boss 行为
	match phase_id:
		1: # 低通
			# 增加方波和锯齿波攻击频率
			_set_attack_weight("square_grid", 3.0)
			_set_attack_weight("sawtooth_slash", 3.0)
			_set_attack_weight("sine_wave_sweep", 1.0)
		2: # 高通
			# 增加正弦波和噪音波攻击频率
			_set_attack_weight("sine_wave_sweep", 3.0)
			_set_attack_weight("noise_burst", 3.0)
			_set_attack_weight("square_grid", 1.0)
		3: # 全频
			# 所有攻击权重恢复正常
			_reset_attack_weights()

func _set_attack_weight(attack_name: String, weight: float) -> void:
	for phase_cfg in _phase_configs:
		for attack_cfg in phase_cfg.attacks:
			if attack_cfg.name == attack_name:
				attack_cfg.weight = weight

func _reset_attack_weights() -> void:
	# 重新加载初始阶段定义以恢复权重
	var temp_boss := load("res://scripts/entities/enemies/bosses/boss_noise.gd").new()
	temp_boss._define_phases()
	var original_configs = temp_boss._phase_configs
	
	for i in range(_phase_configs.size()):
		for j in range(_phase_configs[i].attacks.size()):
			_phase_configs[i].attacks[j].weight = original_configs[i].attacks[j].weight
	
	temp_boss.queue_free()
