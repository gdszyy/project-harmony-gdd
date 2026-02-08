## boss_beethoven.gd
## 第五章最终 Boss：狂想者·贝多芬 (The Romantic Tempest)
##
## 核心理念：个人意志与命运的对抗。贝多芬是第一个打破古典框架的人，
## 他的Boss战体现了情感的极端波动和不可预测的力量爆发。
##
## 时代特征：【命运动机 (Fate Motif)】
## 以"短-短-短-长"的命运动机节奏驱动攻击，力度从pp到ff动态变化。
## 战场会随着音乐情感变化：宁静的慢板 → 狂暴的急板。
##
## 风格排斥：惩罚重复（贝多芬追求突破与创新）
## 四阶段：命运叩门(Fate Knocking) → 月光幻想(Moonlight Fantasy)
##         → 英雄进军(Eroica March) → 欢乐颂歌(Ode to Joy)
extends "res://scripts/entities/enemies/boss_base.gd"

# ============================================================
# 贝多芬专属常量
# ============================================================
## 命运动机参数
const FATE_MOTIF_SHORT_INTERVAL: float = 0.35
const FATE_MOTIF_LONG_MULT: float = 2.5
const FATE_KNOCK_DAMAGE: float = 18.0
const FATE_KNOCK_RADIUS: float = 100.0
const FATE_KNOCK_FORCE: float = 250.0

## 力度系统
const DYNAMIC_PP: float = 0.0
const DYNAMIC_FF: float = 1.0
const DYNAMIC_CRESCENDO_SPEED: float = 0.08  # 每秒渐强速度
const DYNAMIC_DECRESCENDO_SPEED: float = 0.15

## 月光弹幕
const MOONLIGHT_PROJECTILE_COUNT: int = 16
const MOONLIGHT_PROJECTILE_SPEED: float = 120.0
const MOONLIGHT_DAMAGE: float = 12.0
const MOONLIGHT_WAVE_COUNT: int = 4

## 英雄冲锋
const EROICA_CHARGE_SPEED: float = 350.0
const EROICA_CHARGE_DAMAGE: float = 30.0
const EROICA_TRAIL_DAMAGE: float = 10.0

## 欢乐颂
const ODE_BEAM_COUNT: int = 8
const ODE_BEAM_DAMAGE: float = 25.0
const ODE_BEAM_ROTATION_SPEED: float = 0.8

## 交响冲击波
const SYMPHONY_WAVE_DAMAGE: float = 20.0
const SYMPHONY_WAVE_RADIUS: float = 200.0

# ============================================================
# 内部状态
# ============================================================
## 弹幕容器
var _projectile_container: Node2D = null

## 力度系统
var _current_dynamic: float = 0.3  # 当前力度 (0=pp, 1=ff)
var _target_dynamic: float = 0.3
var _dynamic_direction: int = 1  # 1=渐强, -1=渐弱

## 命运动机状态
var _fate_motif_index: int = 0  # 0-2=短, 3=长
var _fate_motif_timer: float = 0.0
var _fate_motif_active: bool = false

## 英雄冲锋状态
var _is_charging: bool = false
var _charge_target: Vector2 = Vector2.ZERO
var _charge_timer: float = 0.0
var _charge_trail_timer: float = 0.0

## 欢乐颂光束
var _ode_beams_active: bool = false
var _ode_beam_angle: float = 0.0

## 情感状态（影响攻击模式和视觉）
enum EmotionState { DETERMINED, MELANCHOLIC, HEROIC, JOYFUL }
var _emotion: EmotionState = EmotionState.DETERMINED

## 重复惩罚追踪
var _player_attack_history: Array[String] = []
var _repetition_penalty_timer: float = 0.0

# ============================================================
# Boss 初始化
# ============================================================

func _on_boss_ready() -> void:
	boss_name = "狂想者"
	boss_title = "贝多芬 · The Romantic Tempest"
	
	max_hp = 5500.0
	current_hp = 5500.0
	move_speed = 60.0
	contact_damage = 18.0
	xp_value = 200
	
	enrage_time = 240.0
	resonance_fragment_drop = 80
	
	base_color = Color(0.7, 0.15, 0.15)
	
	quantized_fps = 8.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.85
	
	_projectile_container = Node2D.new()
	_projectile_container.name = "BeethovenProjectiles"
	add_child(_projectile_container)

# ============================================================
# 阶段定义
# ============================================================

func _define_phases() -> void:
	_phase_configs = [
		# 阶段一：命运叩门 (Fate Knocking)
		# "短-短-短-长"的命运动机攻击，力度从pp开始渐强
		{
			"name": "命运叩门 · Fate Knocking",
			"hp_threshold": 1.0,
			"speed_mult": 1.0,
			"damage_mult": 1.0,
			"color": Color(0.6, 0.2, 0.2),
			"shield_hp": 300.0,
			"music_layer": "boss_beethoven_fate",
			"summon_enabled": false,
			"attack_selection": "sequence",
			"attacks": [
				{
					"name": "fate_motif",
					"duration": 3.0,
					"cooldown": 3.0,
					"damage": FATE_KNOCK_DAMAGE,
					"weight": 3.0,
				},
				{
					"name": "crescendo_barrage",
					"duration": 2.5,
					"cooldown": 3.5,
					"damage": 15.0,
					"weight": 2.0,
				},
				{
					"name": "symphony_shockwave",
					"duration": 1.5,
					"cooldown": 4.0,
					"damage": SYMPHONY_WAVE_DAMAGE,
					"weight": 2.0,
				},
			],
		},
		# 阶段二：月光幻想 (Moonlight Fantasy)
		# 切换到忧郁的慢板，攻击变得优美但致命
		{
			"name": "月光幻想 · Moonlight Fantasy",
			"hp_threshold": 0.7,
			"speed_mult": 0.7,
			"damage_mult": 1.2,
			"color": Color(0.2, 0.25, 0.6),
			"shield_hp": 0.0,
			"music_layer": "boss_beethoven_moonlight",
			"summon_enabled": true,
			"summon_count": 3,
			"summon_type": "ch5_crescendo_surge",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "moonlight_sonata",
					"duration": 4.0,
					"cooldown": 3.0,
					"damage": MOONLIGHT_DAMAGE,
					"weight": 3.0,
				},
				{
					"name": "fate_motif",
					"duration": 3.0,
					"cooldown": 3.5,
					"damage": FATE_KNOCK_DAMAGE * 1.2,
					"weight": 2.0,
				},
				{
					"name": "melancholy_rain",
					"duration": 3.0,
					"cooldown": 4.0,
					"damage": 10.0,
					"weight": 2.5,
				},
			],
		},
		# 阶段三：英雄进军 (Eroica March)
		# 切换到激昂的进行曲，高速冲锋+力量攻击
		{
			"name": "英雄进军 · Eroica March",
			"hp_threshold": 0.4,
			"speed_mult": 1.8,
			"damage_mult": 1.5,
			"color": Color(0.9, 0.5, 0.1),
			"shield_hp": 200.0,
			"music_layer": "boss_beethoven_eroica",
			"summon_enabled": true,
			"summon_count": 5,
			"summon_type": "ch5_fate_knocker",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "eroica_charge",
					"duration": 2.0,
					"cooldown": 3.0,
					"damage": EROICA_CHARGE_DAMAGE,
					"weight": 3.0,
				},
				{
					"name": "fate_motif",
					"duration": 3.0,
					"cooldown": 2.5,
					"damage": FATE_KNOCK_DAMAGE * 1.5,
					"weight": 2.0,
				},
				{
					"name": "symphony_shockwave",
					"duration": 1.5,
					"cooldown": 2.0,
					"damage": SYMPHONY_WAVE_DAMAGE * 1.5,
					"weight": 2.5,
				},
				{
					"name": "crescendo_barrage",
					"duration": 2.5,
					"cooldown": 3.0,
					"damage": 20.0,
					"weight": 2.0,
				},
			],
		},
		# 阶段四：欢乐颂歌 (Ode to Joy)
		# 最终阶段：所有攻击模式混合，旋转光束+全屏弹幕
		{
			"name": "欢乐颂歌 · Ode to Joy",
			"hp_threshold": 0.15,
			"speed_mult": 1.5,
			"damage_mult": 2.0,
			"color": Color(1.0, 0.85, 0.2),
			"shield_hp": 0.0,
			"music_layer": "boss_beethoven_ode",
			"summon_enabled": true,
			"summon_count": 4,
			"summon_type": "ch5_fate_knocker",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "ode_to_joy",
					"duration": 5.0,
					"cooldown": 4.0,
					"damage": ODE_BEAM_DAMAGE,
					"weight": 3.0,
				},
				{
					"name": "eroica_charge",
					"duration": 2.0,
					"cooldown": 2.5,
					"damage": EROICA_CHARGE_DAMAGE * 1.5,
					"weight": 2.0,
				},
				{
					"name": "fate_motif",
					"duration": 3.0,
					"cooldown": 2.0,
					"damage": FATE_KNOCK_DAMAGE * 2.0,
					"weight": 2.5,
				},
				{
					"name": "moonlight_sonata",
					"duration": 4.0,
					"cooldown": 3.0,
					"damage": MOONLIGHT_DAMAGE * 2.0,
					"weight": 2.0,
				},
				{
					"name": "final_symphony",
					"duration": 6.0,
					"cooldown": 6.0,
					"damage": 30.0,
					"weight": 1.5,
				},
			],
		},
	]

# ============================================================
# Boss 每帧逻辑
# ============================================================

func _on_boss_process(delta: float) -> void:
	# 力度系统更新
	_update_dynamic_system(delta)
	
	# 命运动机节奏
	if _fate_motif_active:
		_update_fate_motif(delta)
	
	# 英雄冲锋
	if _is_charging:
		_update_charge(delta)
	
	# 欢乐颂光束
	if _ode_beams_active:
		_ode_beam_angle += ODE_BEAM_ROTATION_SPEED * delta
	
	# 情感视觉
	_update_emotion_visual(delta)
	
	# 重复惩罚
	if _repetition_penalty_timer > 0.0:
		_repetition_penalty_timer -= delta

## 力度系统：在pp和ff之间动态变化
func _update_dynamic_system(delta: float) -> void:
	if _current_dynamic < _target_dynamic:
		_current_dynamic = min(_current_dynamic + DYNAMIC_CRESCENDO_SPEED * delta, _target_dynamic)
	elif _current_dynamic > _target_dynamic:
		_current_dynamic = max(_current_dynamic - DYNAMIC_DECRESCENDO_SPEED * delta, _target_dynamic)

## 情感视觉更新
func _update_emotion_visual(_delta: float) -> void:
	if _sprite == null:
		return
	
	var emotion_color: Color
	match _emotion:
		EmotionState.DETERMINED:
			emotion_color = Color(0.6, 0.2, 0.2)
		EmotionState.MELANCHOLIC:
			emotion_color = Color(0.2, 0.25, 0.6)
		EmotionState.HEROIC:
			emotion_color = Color(0.9, 0.5, 0.1)
		EmotionState.JOYFUL:
			emotion_color = Color(1.0, 0.85, 0.2)
	
	# 力度影响体积和颜色强度
	var dynamic_scale := lerp(0.9, 1.3, _current_dynamic)
	var dynamic_brightness := lerp(0.6, 1.2, _current_dynamic)
	
	if not _is_charging:
		_sprite.scale = _sprite.scale.lerp(Vector2(dynamic_scale, dynamic_scale), 0.1)
	_sprite.modulate = emotion_color * dynamic_brightness

# ============================================================
# 阶段进入回调
# ============================================================

func _on_phase_entered(phase_index: int, _config: Dictionary) -> void:
	match phase_index:
		0:
			_emotion = EmotionState.DETERMINED
			_target_dynamic = 0.3
		1:
			_emotion = EmotionState.MELANCHOLIC
			_target_dynamic = 0.2
			_current_dynamic = 0.5  # 从forte突然降到piano
		2:
			_emotion = EmotionState.HEROIC
			_target_dynamic = 0.7
		3:
			_emotion = EmotionState.JOYFUL
			_target_dynamic = 0.5

# ============================================================
# 攻击实现
# ============================================================

func _perform_attack(attack: Dictionary) -> void:
	var config: Dictionary = _phase_configs[_current_phase] if _current_phase < _phase_configs.size() else {}
	var damage_mult: float = config.get("damage_mult", 1.0)
	var dynamic_mult: float = 1.0 + _current_dynamic * 0.5
	
	match attack["name"]:
		"fate_motif":
			_attack_fate_motif(attack, damage_mult * dynamic_mult)
		"crescendo_barrage":
			_attack_crescendo_barrage(attack, damage_mult * dynamic_mult)
		"symphony_shockwave":
			_attack_symphony_shockwave(attack, damage_mult * dynamic_mult)
		"moonlight_sonata":
			_attack_moonlight_sonata(attack, damage_mult * dynamic_mult)
		"melancholy_rain":
			_attack_melancholy_rain(attack, damage_mult * dynamic_mult)
		"eroica_charge":
			_attack_eroica_charge(attack, damage_mult * dynamic_mult)
		"ode_to_joy":
			_attack_ode_to_joy(attack, damage_mult * dynamic_mult)
		"final_symphony":
			_attack_final_symphony(attack, damage_mult * dynamic_mult)

# ============================================================
# 攻击1：命运动机 (Fate Motif)
# "短-短-短-长"节奏的冲击波
# ============================================================

func _attack_fate_motif(attack: Dictionary, mult: float) -> void:
	_fate_motif_active = true
	_fate_motif_index = 0
	_fate_motif_timer = 0.0
	
	# 渐强到forte
	_target_dynamic = min(_current_dynamic + 0.3, 1.0)

func _update_fate_motif(delta: float) -> void:
	_fate_motif_timer += delta
	
	if _fate_motif_index < 3:
		# 短音符
		if _fate_motif_timer >= FATE_MOTIF_SHORT_INTERVAL:
			_fate_motif_timer = 0.0
			_fire_fate_knock(false)
			_fate_motif_index += 1
	elif _fate_motif_index == 3:
		# 长音符（蓄力后释放）
		if _fate_motif_timer >= FATE_MOTIF_SHORT_INTERVAL * FATE_MOTIF_LONG_MULT:
			_fate_motif_timer = 0.0
			_fire_fate_knock(true)
			_fate_motif_active = false
			_fate_motif_index = 0
	else:
		_fate_motif_active = false

func _fire_fate_knock(is_long: bool) -> void:
	var radius := FATE_KNOCK_RADIUS * (1.8 if is_long else 1.0) * (1.0 + _current_dynamic * 0.5)
	var damage := FATE_KNOCK_DAMAGE * (2.0 if is_long else 1.0) * (1.0 + _current_dynamic * 0.5)
	var force := FATE_KNOCK_FORCE * (1.5 if is_long else 1.0)
	var color := Color(1.0, 0.3, 0.1, 0.7) if is_long else Color(0.7, 0.2, 0.2, 0.5)
	
	# 冲击波视觉
	var wave := Node2D.new()
	wave.global_position = global_position
	get_parent().add_child(wave)
	
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(32):
		var angle := (TAU / 32) * i
		points.append(Vector2.from_angle(angle) * 5.0)
	ring.polygon = points
	ring.color = color
	wave.add_child(ring)
	
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", Vector2(radius / 5.0, radius / 5.0), 0.3)
	tween.parallel().tween_property(ring, "color:a", 0.0, 0.3)
	tween.tween_callback(wave.queue_free)
	
	# 伤害
	if _target and is_instance_valid(_target):
		if global_position.distance_to(_target.global_position) < radius:
			if _target.has_method("take_damage"):
				_target.take_damage(damage)
			if _target.has_method("apply_knockback"):
				var dir := global_position.direction_to(_target.global_position)
				_target.apply_knockback(dir * force)
	
	# 视觉反馈
	if _sprite:
		var s_tween := create_tween()
		var scale_mult := 1.8 if is_long else 1.3
		s_tween.tween_property(_sprite, "scale", Vector2(scale_mult, scale_mult), 0.08)
		s_tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.15)

# ============================================================
# 攻击2：渐强弹幕 (Crescendo Barrage)
# 弹幕密度和速度随力度渐强
# ============================================================

func _attack_crescendo_barrage(attack: Dictionary, mult: float) -> void:
	var waves := 5
	_target_dynamic = 1.0  # 渐强到ff
	
	for w in range(waves):
		get_tree().create_timer(w * 0.4).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			var progress := float(w) / float(waves)
			var count := int(lerp(4.0, 12.0, progress))
			var speed := lerp(100.0, 250.0, progress)
			var damage := attack.get("damage", 15.0) * mult * lerp(0.5, 1.5, progress)
			
			if _target and is_instance_valid(_target):
				var base_angle := global_position.direction_to(_target.global_position).angle()
				var spread := lerp(0.3, 0.8, progress)
				
				for i in range(count):
					var t := float(i) / float(max(1, count - 1))
					var angle := base_angle - spread / 2.0 + spread * t
					if count == 1:
						angle = base_angle
					_spawn_boss_projectile(global_position, angle, speed, damage)
		)

# ============================================================
# 攻击3：交响冲击波 (Symphony Shockwave)
# 多层同心圆冲击波
# ============================================================

func _attack_symphony_shockwave(attack: Dictionary, mult: float) -> void:
	var damage: float = attack.get("damage", SYMPHONY_WAVE_DAMAGE) * mult
	var waves := 3
	
	for w in range(waves):
		get_tree().create_timer(w * 0.6).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			var radius := SYMPHONY_WAVE_RADIUS * (1.0 + w * 0.3)
			
			var wave_node := Node2D.new()
			wave_node.global_position = global_position
			get_parent().add_child(wave_node)
			
			var ring := Polygon2D.new()
			var points := PackedVector2Array()
			for i in range(32):
				var angle := (TAU / 32) * i
				points.append(Vector2.from_angle(angle) * 5.0)
			ring.polygon = points
			ring.color = Color(0.8, 0.3, 0.1, 0.6)
			wave_node.add_child(ring)
			
			var tween := wave_node.create_tween()
			tween.tween_property(wave_node, "scale",
				Vector2(radius / 5.0, radius / 5.0), 0.4)
			tween.parallel().tween_property(ring, "color:a", 0.0, 0.4)
			tween.tween_callback(wave_node.queue_free)
			
			if _target and is_instance_valid(_target):
				if global_position.distance_to(_target.global_position) < radius:
					if _target.has_method("take_damage"):
						_target.take_damage(damage * (1.0 - w * 0.2))
		)

# ============================================================
# 攻击4：月光奏鸣曲 (Moonlight Sonata)
# 优美的螺旋弹幕，缓慢但覆盖面广
# ============================================================

func _attack_moonlight_sonata(attack: Dictionary, mult: float) -> void:
	_emotion = EmotionState.MELANCHOLIC
	_target_dynamic = 0.2  # 渐弱到pp
	
	var damage: float = attack.get("damage", MOONLIGHT_DAMAGE) * mult
	
	for w in range(MOONLIGHT_WAVE_COUNT):
		get_tree().create_timer(w * 0.8).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			var base_angle := w * 0.3
			for i in range(MOONLIGHT_PROJECTILE_COUNT):
				var angle := (TAU / MOONLIGHT_PROJECTILE_COUNT) * i + base_angle
				var speed := MOONLIGHT_PROJECTILE_SPEED * (0.8 + w * 0.1)
				
				# 螺旋偏移
				var spiral_offset := i * 0.05
				_spawn_boss_projectile(global_position, angle + spiral_offset,
					speed, damage, Color(0.3, 0.4, 0.8, 0.7))
		)

# ============================================================
# 攻击5：忧郁之雨 (Melancholy Rain)
# 从上方降落的弹幕雨
# ============================================================

func _attack_melancholy_rain(attack: Dictionary, mult: float) -> void:
	var damage: float = attack.get("damage", 10.0) * mult
	var count := 20
	
	for i in range(count):
		get_tree().create_timer(i * 0.12).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			if _target == null or not is_instance_valid(_target):
				return
			
			# 在玩家周围随机位置从上方降落
			var offset := Vector2(randf_range(-150, 150), -300.0)
			var start_pos := _target.global_position + offset
			var end_pos := start_pos + Vector2(randf_range(-30, 30), 350.0)
			
			# 预警
			var warning := Polygon2D.new()
			warning.polygon = PackedVector2Array([
				Vector2(-8, -8), Vector2(8, -8), Vector2(0, 8)
			])
			warning.color = Color(0.3, 0.3, 0.7, 0.3)
			warning.global_position = end_pos
			get_parent().add_child(warning)
			
			get_tree().create_timer(0.5).timeout.connect(func():
				if is_instance_valid(warning):
					warning.queue_free()
				
				var proj := Area2D.new()
				proj.add_to_group("enemy_projectiles")
				var col := CollisionShape2D.new()
				var shape := CircleShape2D.new()
				shape.radius = 5.0
				col.shape = shape
				proj.add_child(col)
				
				var visual := Polygon2D.new()
				visual.polygon = PackedVector2Array([
					Vector2(0, -6), Vector2(4, 2), Vector2(-4, 2)
				])
				visual.color = Color(0.4, 0.5, 0.9, 0.8)
				proj.add_child(visual)
				
				proj.global_position = start_pos
				get_parent().add_child(proj)
				
				var tween := proj.create_tween()
				tween.tween_property(proj, "global_position", end_pos, 0.6)
				tween.tween_callback(func():
					if _target and is_instance_valid(_target):
						if proj.global_position.distance_to(_target.global_position) < 25.0:
							if _target.has_method("take_damage"):
								_target.take_damage(damage)
					proj.queue_free()
				)
			)
		)

# ============================================================
# 攻击6：英雄冲锋 (Eroica Charge)
# 高速冲向玩家，留下伤害轨迹
# ============================================================

func _attack_eroica_charge(attack: Dictionary, mult: float) -> void:
	_emotion = EmotionState.HEROIC
	_target_dynamic = 0.9
	
	if _target == null or not is_instance_valid(_target):
		return
	
	# 蓄力预警
	_charge_target = _target.global_position
	
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(0.6, 1.4), 0.5)
		tween.tween_callback(func():
			_is_charging = true
			_charge_timer = 0.8
			_charge_trail_timer = 0.0
		)

func _update_charge(delta: float) -> void:
	_charge_timer -= delta
	_charge_trail_timer += delta
	
	if _charge_timer <= 0.0:
		_is_charging = false
		if _sprite:
			_sprite.scale = Vector2(1.0, 1.0)
		return
	
	# 冲向目标
	var dir := global_position.direction_to(_charge_target)
	velocity = dir * EROICA_CHARGE_SPEED
	move_and_slide()
	
	# 留下伤害轨迹
	if _charge_trail_timer >= 0.08:
		_charge_trail_timer = 0.0
		_spawn_charge_trail()
	
	# 冲锋碰撞检测
	if _target and is_instance_valid(_target):
		if global_position.distance_to(_target.global_position) < 40.0:
			if _target.has_method("take_damage"):
				_target.take_damage(EROICA_CHARGE_DAMAGE * (1.0 + _current_dynamic * 0.5))
			_is_charging = false
			if _sprite:
				_sprite.scale = Vector2(1.0, 1.0)

func _spawn_charge_trail() -> void:
	var trail := Polygon2D.new()
	trail.polygon = PackedVector2Array([
		Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)
	])
	trail.color = Color(0.9, 0.5, 0.1, 0.6)
	trail.global_position = global_position
	get_parent().add_child(trail)
	
	# 轨迹持续伤害
	var area := Area2D.new()
	area.add_to_group("enemy_projectiles")
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	col.shape = shape
	area.add_child(col)
	area.global_position = global_position
	get_parent().add_child(area)
	
	# 淡出
	var tween := trail.create_tween()
	tween.tween_property(trail, "color:a", 0.0, 1.5)
	tween.tween_callback(func():
		trail.queue_free()
		if is_instance_valid(area):
			area.queue_free()
	)

# ============================================================
# 攻击7：欢乐颂歌 (Ode to Joy)
# 旋转光束 + 全方位弹幕
# ============================================================

func _attack_ode_to_joy(attack: Dictionary, mult: float) -> void:
	_emotion = EmotionState.JOYFUL
	_target_dynamic = 0.8
	_ode_beams_active = true
	_ode_beam_angle = 0.0
	
	var damage: float = attack.get("damage", ODE_BEAM_DAMAGE) * mult
	var duration: float = attack.get("duration", 5.0)
	
	# 旋转光束持续伤害
	var beam_tick := 0.3
	var ticks := int(duration / beam_tick)
	
	for t in range(ticks):
		get_tree().create_timer(t * beam_tick).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			
			# 8条旋转光束
			for i in range(ODE_BEAM_COUNT):
				var angle := (TAU / ODE_BEAM_COUNT) * i + _ode_beam_angle
				var beam_end := global_position + Vector2.from_angle(angle) * 350.0
				
				# 光束视觉
				var line := Line2D.new()
				line.width = 4.0
				line.default_color = Color(1.0, 0.85, 0.2, 0.5)
				line.add_point(global_position)
				line.add_point(beam_end)
				get_parent().add_child(line)
				
				var fade := line.create_tween()
				fade.tween_property(line, "modulate:a", 0.0, beam_tick * 0.8)
				fade.tween_callback(line.queue_free)
				
				# 光束伤害检测
				if _target and is_instance_valid(_target):
					var to_player := _target.global_position - global_position
					var beam_dir := Vector2.from_angle(angle)
					var proj := to_player.project(beam_dir)
					var perp_dist := (to_player - proj).length()
					if perp_dist < 20.0 and proj.length() < 350.0 and proj.dot(beam_dir) > 0:
						if _target.has_method("take_damage"):
							_target.take_damage(damage * 0.15)
		)
	
	# 结束光束
	get_tree().create_timer(duration).timeout.connect(func():
		_ode_beams_active = false
	)

# ============================================================
# 攻击8：最终交响曲 (Final Symphony)
# 终极攻击：命运动机 + 冲击波 + 全方位弹幕
# ============================================================

func _attack_final_symphony(attack: Dictionary, mult: float) -> void:
	_target_dynamic = 1.0
	var damage: float = attack.get("damage", 30.0) * mult
	
	# 第一乐章：命运叩门（冲击波）
	_fire_fate_knock(true)
	
	# 第二乐章：月光弹幕
	get_tree().create_timer(1.0).timeout.connect(func():
		if _is_dead:
			return
		for i in range(24):
			var angle := (TAU / 24) * i
			_spawn_boss_projectile(global_position, angle, 150.0,
				damage * 0.3, Color(0.3, 0.4, 0.8, 0.7))
	)
	
	# 第三乐章：英雄冲击波
	get_tree().create_timer(2.5).timeout.connect(func():
		if _is_dead:
			return
		for w in range(3):
			get_tree().create_timer(w * 0.3).timeout.connect(func():
				if _is_dead:
					return
				var wave_node := Node2D.new()
				wave_node.global_position = global_position
				get_parent().add_child(wave_node)
				var ring := Polygon2D.new()
				var points := PackedVector2Array()
				for i in range(32):
					var a := (TAU / 32) * i
					points.append(Vector2.from_angle(a) * 5.0)
				ring.polygon = points
				ring.color = Color(0.9, 0.5, 0.1, 0.7)
				wave_node.add_child(ring)
				var tween := wave_node.create_tween()
				tween.tween_property(wave_node, "scale",
					Vector2(50.0, 50.0), 0.5)
				tween.parallel().tween_property(ring, "color:a", 0.0, 0.5)
				tween.tween_callback(wave_node.queue_free)
			)
	)
	
	# 第四乐章：欢乐颂弹幕
	get_tree().create_timer(4.0).timeout.connect(func():
		if _is_dead:
			return
		for w in range(3):
			get_tree().create_timer(w * 0.3).timeout.connect(func():
				if _is_dead:
					return
				for i in range(16):
					var angle := (TAU / 16) * i + w * 0.15
					_spawn_boss_projectile(global_position, angle,
						180.0 + w * 30.0, damage * 0.25,
						Color(1.0, 0.85, 0.2, 0.8))
			)
	)

# ============================================================
# 弹幕生成工具
# ============================================================

func _spawn_boss_projectile(pos: Vector2, angle: float, speed: float,
		damage: float, color: Color = Color(0.7, 0.2, 0.2, 0.8)) -> void:
	var proj := Area2D.new()
	proj.add_to_group("enemy_projectiles")
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0 + _current_dynamic * 2.0
	col.shape = shape
	proj.add_child(col)
	
	var visual := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(6):
		var a := (TAU / 6) * i
		points.append(Vector2.from_angle(a) * shape.radius)
	visual.polygon = points
	visual.color = color
	proj.add_child(visual)
	
	proj.global_position = pos
	
	if _projectile_container and is_instance_valid(_projectile_container):
		_projectile_container.add_child(proj)
	else:
		get_parent().add_child(proj)
	
	var vel := Vector2.from_angle(angle) * speed
	var lifetime := 4.0
	
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position",
		proj.global_position + vel * lifetime, lifetime)
	tween.tween_callback(proj.queue_free)
	
	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			proj.queue_free()
	)

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null or _is_charging:
		return Vector2.ZERO
	
	var to_player := _target.global_position - global_position
	var dist := to_player.length()
	
	# 根据情感状态调整移动行为
	match _emotion:
		EmotionState.DETERMINED:
			# 坚定地接近
			if dist > 200.0:
				return to_player.normalized()
			return Vector2.ZERO
		EmotionState.MELANCHOLIC:
			# 缓慢环绕
			if dist > 250.0:
				return to_player.normalized()
			return to_player.normalized().rotated(PI / 2.5)
		EmotionState.HEROIC:
			# 积极追击
			return to_player.normalized()
		EmotionState.JOYFUL:
			# 自由移动
			if dist > 180.0:
				return to_player.normalized()
			elif dist < 100.0:
				return -to_player.normalized()
			return to_player.normalized().rotated(PI / 3.0)
	
	return Vector2.ZERO

# ============================================================
# 节拍响应
# ============================================================

func _on_boss_beat(_beat_index: int) -> void:
	# 命运动机节奏强调
	if _boss_beat_counter % 4 == 0:
		_target_dynamic = min(_current_dynamic + 0.1, 1.0)

# ============================================================
# 狂暴
# ============================================================

func _on_enrage(level: int) -> void:
	if level == 1:
		_target_dynamic = 0.8
		move_speed *= 1.3
	elif level == 2:
		_target_dynamic = 1.0
		move_speed *= 1.5
		# 永久ff
		_current_dynamic = 1.0
		for phase in _phase_configs:
			for attack in phase.get("attacks", []):
				attack["cooldown"] = attack.get("cooldown", 2.0) * 0.6

func _get_type_name() -> String:
	return "boss_beethoven"
