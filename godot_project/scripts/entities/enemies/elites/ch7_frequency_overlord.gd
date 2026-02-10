## ch7_frequency_overlord.gd
## 第七章精英/小Boss：频率霸主 (Frequency Overlord)
## 数字虚空中的频率操控者，能够扭曲声波频谱进行攻击。
## 音乐隐喻：电子音乐中的频率调制、降采样与波形合成。
## 机制：
## - 频率扫描：发射从低频到高频渐变的弹幕扇面
## - 降采样区域：在区域内降低玩家移动精度（量化移动）
## - 波形切换：在正弦/方波/锯齿波之间切换弹幕模式
## - 共振攻击：锁定玩家频率，造成持续伤害
## - 狂暴时进入"白噪声"模式（全频段随机攻击）
extends "res://scripts/entities/enemies/elite_base.gd"

# ============================================================
# Frequency Overlord 专属配置
# ============================================================
## 频率扫描弹幕速度
@export var freq_projectile_speed: float = 200.0
## 频率扫描基础伤害
@export var freq_damage: float = 12.0
## 降采样区域半径
@export var bitcrush_radius: float = 150.0
## 降采样区域持续时间
@export var bitcrush_duration: float = 5.0
## 共振锁定伤害/秒
@export var resonance_dps: float = 15.0
## 共振锁定范围
@export var resonance_range: float = 200.0

# ============================================================
# 内部状态
# ============================================================
## 当前波形模式 (0=正弦, 1=方波, 2=锯齿)
var _waveform: int = 0
## 波形切换计时
var _waveform_timer: float = 0.0
## 频率扫描相位
var _sweep_phase: float = 0.0
## 共振锁定状态
var _resonance_active: bool = false
var _resonance_timer: float = 0.0
## 降采样区域列表
var _bitcrush_zones: Array[Dictionary] = []

# ============================================================
# 初始化
# ============================================================

func _on_elite_ready() -> void:
	elite_name = "频率霸主"
	elite_title = "Frequency Overlord"
	
	max_hp = 700.0
	current_hp = 700.0
	move_speed = 40.0
	contact_damage = 15.0
	xp_value = 65
	
	base_color = Color(0.1, 0.9, 0.6)
	aura_radius = 120.0
	aura_color = Color(0.1, 0.8, 0.5, 0.1)
	
	quantized_fps = 8.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.6
	
	_elite_shield = 120.0
	_elite_max_shield = 120.0

func _define_elite_attacks() -> void:
	_elite_attacks = [
		{
			"name": "frequency_sweep",
			"duration": 2.0,
			"cooldown": 3.0,
			"damage": freq_damage,
			"weight": 3.0,
		},
		{
			"name": "bitcrush_zone",
			"duration": 1.0,
			"cooldown": 6.0,
			"damage": freq_damage * 0.5,
			"weight": 2.0,
		},
		{
			"name": "waveform_barrage",
			"duration": 2.5,
			"cooldown": 3.5,
			"damage": freq_damage * 1.2,
			"weight": 2.5,
		},
		{
			"name": "resonance_lock",
			"duration": 3.0,
			"cooldown": 7.0,
			"damage": resonance_dps,
			"weight": 1.5,
		},
	]

# ============================================================
# 精英每帧逻辑
# ============================================================

func _on_elite_process(delta: float) -> void:
	# 波形切换
	_waveform_timer += delta
	if _waveform_timer >= 10.0:
		_waveform_timer = 0.0
		_waveform = (_waveform + 1) % 3
	
	# 频率扫描相位
	_sweep_phase += delta * 2.0
	
	# 共振锁定处理
	if _resonance_active:
		_resonance_timer -= delta
		if _resonance_timer <= 0.0:
			_resonance_active = false
		elif _target and is_instance_valid(_target):
			var dist := global_position.distance_to(_target.global_position)
			if dist < resonance_range:
				if _target.has_method("take_damage"):
					_target.take_damage(resonance_dps * delta)
	
	# 更新降采样区域
	_update_bitcrush_zones(delta)
	
	# 视觉：数字故障效果
	if _sprite:
		# 波形颜色
		var waveform_colors := [
			Color(0.1, 0.9, 0.6),   # 正弦 - 绿
			Color(0.1, 0.6, 0.9),   # 方波 - 蓝
			Color(0.9, 0.6, 0.1),   # 锯齿 - 橙
		]
		var target_color: Color = waveform_colors[_waveform]
		_sprite.modulate = _sprite.modulate.lerp(target_color, delta * 2.0)
		
		# 故障抖动
		var glitch := Vector2(
			randf_range(-2, 2) if randf() < 0.1 else 0.0,
			randf_range(-2, 2) if randf() < 0.1 else 0.0
		)
		_sprite.position = glitch

func _update_bitcrush_zones(delta: float) -> void:
	var expired: Array[int] = []
	for i in range(_bitcrush_zones.size()):
		var zone := _bitcrush_zones[i]
		zone["timer"] -= delta
		if zone["timer"] <= 0.0:
			expired.append(i)
			if is_instance_valid(zone["node"]):
				zone["node"].queue_free()
		else:
			# 视觉淡出
			if is_instance_valid(zone["node"]):
				zone["node"].modulate.a = zone["timer"] / bitcrush_duration * 0.5
	
	for i in range(expired.size() - 1, -1, -1):
		_bitcrush_zones.remove_at(expired[i])

# ============================================================
# 攻击实现
# ============================================================

func _perform_elite_attack(attack: Dictionary) -> void:
	match attack["name"]:
		"frequency_sweep":
			_attack_frequency_sweep(attack)
		"bitcrush_zone":
			_attack_bitcrush_zone(attack)
		"waveform_barrage":
			_attack_waveform_barrage(attack)
		"resonance_lock":
			_attack_resonance_lock(attack)

## 攻击1：频率扫描 — 从低频到高频的扇形弹幕
func _attack_frequency_sweep(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", freq_damage)
	
	if _target == null:
		return
	
	var base_angle := (global_position.direction_to(_target.global_position)).angle()
	var sweep_count := 12
	
	for i in range(sweep_count):
		var delay := i * 0.12
		get_tree().create_timer(delay).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			# 频率从低到高：速度递增，散布递减
			var freq_ratio := float(i) / float(sweep_count)
			var speed := freq_projectile_speed * (0.6 + freq_ratio * 0.8)
			var spread := (1.0 - freq_ratio) * 0.4
			
			var angle := base_angle + randf_range(-spread, spread)
			
			# 颜色从红（低频）到蓝（高频）
			var color := Color(1.0 - freq_ratio, 0.3, freq_ratio, 0.8)
			
			_spawn_elite_projectile(global_position, angle, speed, damage * 0.3, color)
		)

## 攻击2：降采样区域 — 在玩家位置创建干扰区
func _attack_bitcrush_zone(attack: Dictionary) -> void:
	if _target == null:
		return
	
	var zone_pos := _target.global_position
	
	# 视觉：降采样区域
	var zone_visual := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(6):  # 六边形
		var angle := (TAU / 6) * i
		points.append(Vector2.from_angle(angle) * bitcrush_radius)
	zone_visual.polygon = points
	zone_visual.color = Color(0.1, 0.8, 0.5, 0.15)
	zone_visual.global_position = zone_pos
	get_parent().add_child(zone_visual)
	
	_bitcrush_zones.append({
		"node": zone_visual,
		"position": zone_pos,
		"timer": bitcrush_duration,
	})
	
	# 区域内弹幕
	get_tree().create_timer(0.5).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			return
		for i in range(8):
			var angle := (TAU / 8) * i
			_spawn_elite_projectile(zone_pos, angle,
				freq_projectile_speed * 0.5, freq_damage * 0.25,
				Color(0.2, 0.9, 0.5, 0.6))
	)

## 攻击3：波形弹幕 — 根据当前波形模式发射不同图案
func _attack_waveform_barrage(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", freq_damage * 1.2)
	
	if _target == null:
		return
	
	var base_angle := (global_position.direction_to(_target.global_position)).angle()
	
	match _waveform:
		0:  # 正弦波：波浪形弹幕
			for i in range(10):
				var delay := i * 0.15
				get_tree().create_timer(delay).timeout.connect(func():
					if _is_dead or not is_instance_valid(self):
						return
					var wave_offset := sin(i * 0.8) * 0.3
					var angle := base_angle + wave_offset
					_spawn_elite_projectile(global_position, angle,
						freq_projectile_speed, damage * 0.3,
						Color(0.1, 0.9, 0.6, 0.8))
				)
		
		1:  # 方波：交替高低的弹幕
			for i in range(8):
				var delay := i * 0.18
				get_tree().create_timer(delay).timeout.connect(func():
					if _is_dead or not is_instance_valid(self):
						return
					var offset := 0.3 if i % 2 == 0 else -0.3
					var angle := base_angle + offset
					_spawn_elite_projectile(global_position, angle,
						freq_projectile_speed * 1.1, damage * 0.35,
						Color(0.1, 0.6, 0.9, 0.8))
				)
		
		2:  # 锯齿波：渐变扇形
			for i in range(10):
				var delay := i * 0.1
				get_tree().create_timer(delay).timeout.connect(func():
					if _is_dead or not is_instance_valid(self):
						return
					var sweep := float(i) / 10.0 * 0.8 - 0.4
					var angle := base_angle + sweep
					_spawn_elite_projectile(global_position, angle,
						freq_projectile_speed * (0.8 + float(i) / 10.0 * 0.6),
						damage * 0.3,
						Color(0.9, 0.6, 0.1, 0.8))
				)

## 攻击4：共振锁定 — 持续伤害光束
func _attack_resonance_lock(attack: Dictionary) -> void:
	if _target == null:
		return
	
	_resonance_active = true
	_resonance_timer = 3.0
	
	# 视觉：共振连线
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color(0.1, 0.9, 0.6, 0.6)
	get_parent().add_child(line)
	
	# 持续更新连线
	var update_line := func():
		if not is_instance_valid(line) or not is_instance_valid(self):
			return
		if not _resonance_active:
			if is_instance_valid(line):
				line.queue_free()
			return
		line.clear_points()
		line.add_point(global_position)
		if _target and is_instance_valid(_target):
			line.add_point(_target.global_position)
		line.default_color.a = _resonance_timer / 3.0 * 0.6
	
	get_tree().process_frame.connect(update_line)
	
	# 3秒后清理
	get_tree().create_timer(3.2).timeout.connect(func():
		_resonance_active = false
		if is_instance_valid(line):
			line.queue_free()
		if get_tree().process_frame.is_connected(update_line):
			get_tree().process_frame.disconnect(update_line)
	)

# ============================================================
# 光环效果
# ============================================================

func _apply_aura_effect(target_node: Node2D, distance: float) -> void:
	# 频率干扰：靠近时增加玩家的"故障"视觉
	pass

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	var to_player := _target.global_position - global_position
	var dist := to_player.length()
	
	# 频率霸主保持远距离，缓慢逼近
	if dist > 280.0:
		return to_player.normalized()
	elif dist < 150.0:
		return -to_player.normalized()
	else:
		# 中距离：缓慢环绕
		var orbit := to_player.normalized().rotated(PI / 2.0)
		var approach := to_player.normalized() * 0.2
		return (orbit + approach).normalized()

func _on_elite_enrage() -> void:
	# 白噪声模式：全频段随机攻击
	move_speed *= 1.3
	for attack in _elite_attacks:
		attack["cooldown"] = attack.get("cooldown", 2.0) * 0.4
	base_color = Color(0.9, 0.9, 0.9)  # 白噪声 = 白色
	
	# 持续释放随机弹幕
	_waveform = randi() % 3

func _on_elite_death_effect() -> void:
	# 死亡时释放频率爆炸
	for i in range(24):
		var angle := (TAU / 24) * i
		var freq_ratio := float(i) / 24.0
		var color := Color(1.0 - freq_ratio, 0.5, freq_ratio, 0.6)
		_spawn_elite_projectile(global_position, angle,
			freq_projectile_speed * 0.4, freq_damage * 0.15, color)

func _get_type_name() -> String:
	return "frequency_overlord"
