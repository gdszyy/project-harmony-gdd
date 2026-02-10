## ch6_bebop_virtuoso.gd
## 第六章精英/小Boss：比波普大师 (Bebop Virtuoso)
## 爵士时代的即兴演奏大师，以不可预测的切分节奏和快速音阶跑动攻击。
## 音乐隐喻：Bebop 爵士的极速即兴、复杂和弦替代与切分节奏。
## 机制：
## - 即兴独奏：快速、不规则的弹幕模式（非对称）
## - 和弦替代：随机改变弹幕属性（速度/方向突变）
## - 切分冲刺：在反拍突然位移，难以预判
## - 交易四小节（Trading Fours）：与玩家轮流"演奏"
## - 狂暴时进入"自由爵士"模式（完全随机化）
extends "res://scripts/entities/enemies/elite_base.gd"

# ============================================================
# Bebop Virtuoso 专属配置
# ============================================================
## 即兴独奏弹幕速度
@export var solo_projectile_speed: float = 220.0
## 即兴独奏基础伤害
@export var solo_damage: float = 10.0
## 切分冲刺距离
@export var syncopation_dash_distance: float = 120.0
## 切分冲刺冷却
@export var syncopation_cooldown: float = 3.0
## 交易四小节持续时间
@export var trading_fours_duration: float = 4.0
## 和弦替代概率
@export var chord_sub_chance: float = 0.3

# ============================================================
# 内部状态
# ============================================================
## 即兴节奏计数器
var _improv_beat_counter: int = 0
## 切分冲刺冷却计时
var _syncopation_timer: float = 0.0
## 当前即兴"调式"（影响弹幕模式）
var _current_mode: int = 0  # 0=Mixolydian, 1=Dorian, 2=Altered
## 调式切换计时
var _mode_switch_timer: float = 0.0
## 是否在"交易"阶段（暂停攻击，等待玩家回应）
var _trading_pause: bool = false
var _trading_timer: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _on_elite_ready() -> void:
	elite_name = "比波普大师"
	elite_title = "Bebop Virtuoso"
	
	max_hp = 600.0
	current_hp = 600.0
	move_speed = 55.0
	contact_damage = 13.0
	xp_value = 55
	
	base_color = Color(0.6, 0.3, 0.7)
	aura_radius = 0.0  # 无光环，靠机动性
	
	quantized_fps = 10.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.45
	
	_elite_shield = 80.0
	_elite_max_shield = 80.0

func _define_elite_attacks() -> void:
	_elite_attacks = [
		{
			"name": "bebop_solo",
			"duration": 2.5,
			"cooldown": 2.5,
			"damage": solo_damage,
			"weight": 3.5,
		},
		{
			"name": "chord_substitution",
			"duration": 1.5,
			"cooldown": 4.0,
			"damage": solo_damage * 1.2,
			"weight": 2.5,
		},
		{
			"name": "syncopation_dash",
			"duration": 0.8,
			"cooldown": 3.5,
			"damage": solo_damage * 0.8,
			"weight": 2.0,
		},
		{
			"name": "trading_fours",
			"duration": trading_fours_duration,
			"cooldown": 8.0,
			"damage": solo_damage * 1.5,
			"weight": 1.5,
		},
	]

# ============================================================
# 精英每帧逻辑
# ============================================================

func _on_elite_process(delta: float) -> void:
	# 切分冲刺冷却
	if _syncopation_timer > 0.0:
		_syncopation_timer -= delta
	
	# 调式切换
	_mode_switch_timer += delta
	if _mode_switch_timer >= 8.0:
		_mode_switch_timer = 0.0
		_current_mode = (_current_mode + 1) % 3
	
	# 交易暂停倒计时
	if _trading_pause:
		_trading_timer -= delta
		if _trading_timer <= 0.0:
			_trading_pause = false
	
	# 视觉：爵士摇摆
	if _sprite:
		var swing := sin(Time.get_ticks_msec() * 0.004) * 0.12
		_sprite.rotation = swing
		
		# 调式颜色
		var mode_colors := [
			Color(0.6, 0.3, 0.7),   # Mixolydian - 紫
			Color(0.3, 0.5, 0.7),   # Dorian - 蓝
			Color(0.8, 0.3, 0.4),   # Altered - 红
		]
		var target_color: Color = mode_colors[_current_mode]
		_sprite.modulate = _sprite.modulate.lerp(target_color, delta * 2.0)

# ============================================================
# 攻击实现
# ============================================================

func _perform_elite_attack(attack: Dictionary) -> void:
	if _trading_pause:
		return
	
	match attack["name"]:
		"bebop_solo":
			_attack_bebop_solo(attack)
		"chord_substitution":
			_attack_chord_substitution(attack)
		"syncopation_dash":
			_attack_syncopation_dash(attack)
		"trading_fours":
			_attack_trading_fours(attack)

## 攻击1：比波普独奏 — 快速不规则弹幕
func _attack_bebop_solo(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", solo_damage)
	# 根据调式改变弹幕数量和散布
	var note_count := 6 + _current_mode * 3
	var spread := 0.3 + _current_mode * 0.15
	
	for i in range(note_count):
		# 不规则时间间隔（切分感）
		var delay := i * 0.12 + randf_range(-0.04, 0.04)
		if delay < 0.0:
			delay = 0.0
		
		get_tree().create_timer(delay).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			if _target == null:
				return
			
			var base_angle := (global_position.direction_to(_target.global_position)).angle()
			# 即兴偏移（非均匀散布）
			var offset := randf_range(-spread, spread)
			var angle := base_angle + offset
			
			# 和弦替代：随机改变速度
			var speed := solo_projectile_speed
			if randf() < chord_sub_chance:
				speed *= randf_range(0.7, 1.5)
			
			var color := Color(0.7, 0.4, 0.9, 0.8)
			if _current_mode == 2:  # Altered 模式用红色
				color = Color(0.9, 0.3, 0.5, 0.8)
			
			_spawn_elite_projectile(global_position, angle, speed, damage * 0.35, color)
		)

## 攻击2：和弦替代 — 弹幕突然变向
func _attack_chord_substitution(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", solo_damage * 1.2)
	
	if _target == null:
		return
	
	var base_angle := (global_position.direction_to(_target.global_position)).angle()
	
	# 第一波：正常方向
	for i in range(5):
		var angle := base_angle + (i - 2) * 0.15
		_spawn_elite_projectile(global_position, angle,
			solo_projectile_speed, damage * 0.4,
			Color(0.5, 0.3, 0.8, 0.8))
	
	# 第二波：替代方向（偏移90度）
	get_tree().create_timer(0.4).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			return
		if _target == null:
			return
		var new_angle := (global_position.direction_to(_target.global_position)).angle() + PI * 0.5
		for i in range(5):
			var angle := new_angle + (i - 2) * 0.15
			_spawn_elite_projectile(global_position, angle,
				solo_projectile_speed * 1.2, damage * 0.4,
				Color(0.8, 0.5, 0.3, 0.8))
	)

## 攻击3：切分冲刺 — 反拍位移 + 弹幕
func _attack_syncopation_dash(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", solo_damage * 0.8)
	
	if _target == null:
		return
	
	# 随机方向冲刺
	var dash_dir := Vector2.from_angle(randf() * TAU)
	var dash_target := global_position + dash_dir * syncopation_dash_distance
	
	# 冲刺
	var tween := create_tween()
	tween.tween_property(self, "global_position", dash_target, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		if _is_dead:
			return
		# 冲刺后全方位弹幕
		for i in range(8):
			var angle := (TAU / 8) * i
			_spawn_elite_projectile(global_position, angle,
				solo_projectile_speed * 0.8, damage * 0.5,
				Color(0.6, 0.4, 0.8, 0.7))
	)
	
	_syncopation_timer = syncopation_cooldown

## 攻击4：交易四小节 — 密集攻击后暂停
func _attack_trading_fours(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", solo_damage * 1.5)
	
	if _target == null:
		return
	
	# 密集的4拍攻击
	for beat in range(4):
		get_tree().create_timer(beat * 0.6).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			if _target == null:
				return
			var angle := (global_position.direction_to(_target.global_position)).angle()
			for i in range(4):
				var a := angle + (i - 1.5) * 0.12
				_spawn_elite_projectile(global_position, a,
					solo_projectile_speed * 1.1, damage * 0.3,
					Color(0.7, 0.5, 0.9, 0.9))
		)
	
	# 4拍后暂停（"轮到玩家"）
	get_tree().create_timer(2.4).timeout.connect(func():
		if _is_dead:
			return
		_trading_pause = true
		_trading_timer = 2.0  # 暂停2秒
	)

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	var to_player := _target.global_position - global_position
	var dist := to_player.length()
	
	# 比波普大师保持中距离，频繁变向
	var swing_offset := Vector2.from_angle(Time.get_ticks_msec() * 0.003) * 0.5
	
	if dist > 250.0:
		return (to_player.normalized() + swing_offset).normalized()
	elif dist < 120.0:
		return (-to_player.normalized() + swing_offset).normalized()
	else:
		# 中距离：绕圈 + 摇摆
		return (to_player.normalized().rotated(PI / 2.5) + swing_offset).normalized()

func _on_elite_enrage() -> void:
	# 自由爵士模式：完全随机化
	move_speed *= 1.5
	chord_sub_chance = 0.6  # 更多和弦替代
	for attack in _elite_attacks:
		attack["cooldown"] = attack.get("cooldown", 2.0) * 0.4
	base_color = Color(0.9, 0.2, 0.5)
	_current_mode = 2  # 强制 Altered 模式

func _on_elite_death_effect() -> void:
	# 死亡时释放最终即兴独奏
	for i in range(16):
		var angle := randf() * TAU
		_spawn_elite_projectile(global_position, angle,
			solo_projectile_speed * 0.5, solo_damage * 0.2,
			Color(0.6, 0.3, 0.7, 0.5))

func _get_type_name() -> String:
	return "bebop_virtuoso"
