## boss_mozart.gd
## 第四章最终 Boss：古典完形·莫扎特 (The Classical Perfection)
##
## 核心理念：古典主义完美形式的化身，穿着华丽燕尾服、动作精准优雅的贵公子。
## 手持水晶指挥棒，如同击剑般挥洒出致命而精准的乐章。
##
## 时代特征：【奏鸣曲式力场 (Sonata Form Field)】
## 整场Boss战被严格划分为奏鸣曲三部分：呈示部、发展部、再现部。
## 呈示部展示主题A（冲刺斩击）和主题B（圆舞曲弹幕），
## 发展部将两个主题混合变形，再现部以强化形式重现所有主题。
##
## 风格排斥：【繁复的诅咒 (Complexity Curse)】
## 如果玩家场上存在过多召唤物或使用过于复杂的攻击模式，
## 莫扎特会清除召唤物并增加疲劳，体现"化繁为简"的古典美学。
##
## GDD参考：
## - 阶段一（呈示部）：主题A冲刺斩击 + 主题B圆舞曲弹幕 + 优雅反击
## - 阶段二（发展部）：主题A+B组合 + 镜面反射弹幕 + 繁复诅咒
## - 阶段三（再现部）：华彩乐章 + 全面强化 + 终焉和弦
##
## 三阶段：呈示部(Exposition) → 发展部(Development) → 再现部(Recapitulation)
extends "res://scripts/entities/enemies/boss_base.gd"

# ============================================================
# 莫扎特专属常量
# ============================================================
## 主题A：直线冲刺斩击
const THEME_A_DASH_SPEED: float = 500.0
const THEME_A_DASH_DAMAGE: float = 25.0
const THEME_A_SLASH_COUNT: int = 3
const THEME_A_DASH_DURATION: float = 0.2

## 主题B：圆舞曲式弹幕
const THEME_B_PROJECTILE_SPEED: float = 160.0
const THEME_B_DAMAGE: float = 12.0
const THEME_B_SPIRAL_COUNT: int = 6

## 繁复诅咒（GDD风格排斥）
const COMPLEXITY_FATIGUE_PENALTY: float = 0.25
const COMPLEXITY_CHECK_INTERVAL: float = 5.0
const COMPLEXITY_SUMMON_THRESHOLD: int = 2  # 召唤物数量阈值

## 镜面反射弹幕（GDD：发展部核心机制）
const MIRROR_REFLECT_SPEED: float = 200.0
const MIRROR_LIFETIME: float = 4.0
const MIRROR_BOUNDARY_SIZE: float = 400.0
const MIRROR_MAX_REFLECTS: int = 2

## 华彩乐章参数（GDD：再现部终极攻击）
const CADENZA_DASH_COUNT: int = 5
const CADENZA_BARRAGE_COUNT: int = 16
const CADENZA_DURATION: float = 4.5

## 终焉和弦参数（GDD：最终必杀技）
const FINAL_CHORD_DAMAGE: float = 35.0
const FINAL_CHORD_BEAM_COUNT: int = 12
const FINAL_CHORD_BEAM_WIDTH: float = 40.0
const FINAL_CHORD_BEAM_LENGTH: float = 450.0

## 奏鸣曲式力场视觉参数
const SONATA_FIELD_RADIUS: float = 350.0

# ============================================================
# 内部状态
# ============================================================
var _projectile_container: Node2D = null

## 奏鸣曲式阶段标识
var _sonata_section: String = "exposition"

## 冲刺系统
var _is_dashing: bool = false
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_timer: float = 0.0
var _pre_dash_pos: Vector2 = Vector2.ZERO

## 圆舞曲旋转
var _waltz_angle: float = 0.0
var _waltz_speed: float = 2.0

## 繁复诅咒计时
var _complexity_check_timer: float = 0.0

## 华彩乐章
var _cadenza_active: bool = false

## 节拍计数
var _mozart_beat_counter: int = 0

## 镜面反射系统
var _mirror_active: bool = false
var _mirror_boundaries: Array[Vector2] = []
var _mirror_visual_nodes: Array[Node2D] = []

## 奏鸣曲式力场视觉
var _sonata_field_node: Node2D = null

## 主题记忆（用于再现部重现）
var _theme_a_performed: bool = false
var _theme_b_performed: bool = false

# ============================================================
# Boss 初始化
# ============================================================

func _on_boss_ready() -> void:
	boss_name = "古典完形"
	boss_title = "莫扎特 · The Classical Perfection"
	
	max_hp = 4500.0
	current_hp = 4500.0
	move_speed = 65.0
	contact_damage = 18.0
	xp_value = 180
	
	enrage_time = 230.0
	resonance_fragment_drop = 80
	
	base_color = Color(0.95, 0.9, 0.7)
	quantized_fps = 10.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.75
	
	_projectile_container = Node2D.new()
	_projectile_container.name = "MozartProjectiles"
	_projectile_container.top_level = true  # 使弹幕容器独立于 Boss 变换，避免 global_position 双重偏移
	add_child(_projectile_container)

# ============================================================
# 阶段定义（GDD：呈示部 → 发展部 → 再现部）
# ============================================================

func _define_phases() -> void:
	_phase_configs = [
		# 阶段一：呈示部 (Exposition)
		# GDD：展示主题A（冲刺斩击）和主题B（圆舞曲弹幕）
		{
			"name": "呈示部 · Exposition",
			"hp_threshold": 1.0,
			"speed_mult": 1.0,
			"damage_mult": 1.0,
			"color": Color(0.95, 0.9, 0.7),
			"shield_hp": 300.0,
			"music_layer": "boss_mozart_exposition",
			"summon_enabled": false,
			"attack_selection": "sequence",
			"attacks": [
				{
					"name": "theme_a_dash",
					"duration": 2.0,
					"cooldown": 3.0,
					"damage": THEME_A_DASH_DAMAGE,
					"weight": 3.0,
				},
				{
					"name": "theme_b_waltz",
					"duration": 3.0,
					"cooldown": 3.5,
					"damage": THEME_B_DAMAGE,
					"weight": 3.0,
				},
				{
					"name": "elegant_riposte",
					"duration": 1.5,
					"cooldown": 3.0,
					"damage": 15.0,
					"weight": 2.0,
				},
			],
		},
		# 阶段二：发展部 (Development)
		# GDD：主题A+B混合变形 + 镜面反射弹幕 + 繁复诅咒
		{
			"name": "发展部 · Development",
			"hp_threshold": 0.55,
			"speed_mult": 1.3,
			"damage_mult": 1.3,
			"color": Color(1.0, 0.95, 0.6),
			"shield_hp": 250.0,
			"music_layer": "boss_mozart_development",
			"summon_enabled": true,
			"summon_count": 2,
			"summon_type": "ch4_minuet_dancer",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "theme_ab_combined",
					"duration": 4.0,
					"cooldown": 3.0,
					"damage": THEME_A_DASH_DAMAGE * 1.3,
					"weight": 3.0,
				},
				{
					"name": "theme_b_waltz",
					"duration": 3.0,
					"cooldown": 2.5,
					"damage": THEME_B_DAMAGE * 1.3,
					"weight": 2.0,
				},
				{
					"name": "mirror_reflection",
					"duration": 3.0,
					"cooldown": 4.0,
					"damage": 15.0,
					"weight": 2.5,
				},
				{
					"name": "complexity_curse",
					"duration": 0.5,
					"cooldown": 6.0,
					"damage": 0.0,
					"weight": 1.5,
				},
			],
		},
		# 阶段三：再现部 (Recapitulation)
		# GDD：华彩乐章 + 终焉和弦 + 全面强化
		{
			"name": "再现部 · Recapitulation",
			"hp_threshold": 0.2,
			"speed_mult": 1.5,
			"damage_mult": 1.8,
			"color": Color(1.0, 0.85, 0.3),
			"shield_hp": 0.0,
			"music_layer": "boss_mozart_recapitulation",
			"summon_enabled": true,
			"summon_count": 4,
			"summon_type": "ch4_minuet_dancer",
			"attack_selection": "random",
			"attacks": [
				{
					"name": "theme_a_dash",
					"duration": 1.5,
					"cooldown": 2.0,
					"damage": THEME_A_DASH_DAMAGE * 1.8,
					"weight": 2.5,
				},
				{
					"name": "theme_b_waltz",
					"duration": 2.5,
					"cooldown": 2.0,
					"damage": THEME_B_DAMAGE * 1.8,
					"weight": 2.5,
				},
				{
					"name": "cadenza",
					"duration": 5.0,
					"cooldown": 5.0,
					"damage": THEME_A_DASH_DAMAGE * 2.0,
					"weight": 2.0,
				},
				{
					"name": "final_chord",
					"duration": 3.0,
					"cooldown": 6.0,
					"damage": FINAL_CHORD_DAMAGE,
					"weight": 2.0,
				},
				{
					"name": "complexity_curse",
					"duration": 0.5,
					"cooldown": 5.0,
					"damage": 0.0,
					"weight": 1.0,
				},
			],
		},
	]

# ============================================================
# Boss 每帧逻辑
# ============================================================

func _on_boss_process(delta: float) -> void:
	# 圆舞曲旋转
	_waltz_angle += _waltz_speed * delta
	
	# 冲刺更新
	if _is_dashing:
		_dash_timer -= delta
		velocity = _dash_direction * THEME_A_DASH_SPEED
		move_and_slide()
		if _dash_timer <= 0.0:
			_end_dash()
	
	# 繁复诅咒检测
	_complexity_check_timer += delta
	if _complexity_check_timer >= COMPLEXITY_CHECK_INTERVAL:
		_complexity_check_timer = 0.0
		_check_complexity()

# ============================================================
# 攻击实现
# ============================================================

func _perform_attack(attack: Dictionary) -> void:
	var config: Dictionary = _phase_configs[_current_phase] if _current_phase < _phase_configs.size() else {}
	var damage_mult: float = config.get("damage_mult", 1.0)
	
	match attack["name"]:
		"theme_a_dash":
			_attack_theme_a_dash(attack, damage_mult)
		"theme_b_waltz":
			_attack_theme_b_waltz(attack, damage_mult)
		"elegant_riposte":
			_attack_elegant_riposte(attack, damage_mult)
		"theme_ab_combined":
			_attack_theme_ab_combined(attack, damage_mult)
		"mirror_reflection":
			_attack_mirror_reflection(attack, damage_mult)
		"complexity_curse":
			_attack_complexity_curse()
		"cadenza":
			_attack_cadenza(attack, damage_mult)
		"final_chord":
			_attack_final_chord(attack, damage_mult)

## 攻击1：主题A — 直线冲刺斩击
## GDD：如同击剑般精准的冲刺，冲刺路径上留下扇形斩击弹幕
func _attack_theme_a_dash(attack: Dictionary, damage_mult: float) -> void:
	if _target == null:
		return
	
	_theme_a_performed = true
	var slashes := THEME_A_SLASH_COUNT
	if _current_phase == 2:
		slashes += 2  # 再现部增加斩击次数（GDD：强化重现）
	
	for i in range(slashes):
		var i_idx := i
		get_tree().create_timer(i * 0.5).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			_start_dash()
		)

func _start_dash() -> void:
	if _target == null:
		return
	_is_dashing = true
	_dash_timer = THEME_A_DASH_DURATION
	_pre_dash_pos = global_position
	_dash_direction = (global_position.direction_to(_target.global_position)).normalized()
	
	# 冲刺视觉（GDD：水晶指挥棒划出的轨迹）
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(0.5, 2.0), 0.05)
		_sprite.rotation = _dash_direction.angle()
	
	# 冲刺轨迹残影
	_spawn_dash_afterimage()

func _end_dash() -> void:
	_is_dashing = false
	
	# 斩击弹幕（冲刺路径上的扇形，GDD：精准的击剑式斩击）
	var slash_angle := _dash_direction.angle()
	var fan_count := 5
	if _current_phase >= 2:
		fan_count = 7  # 再现部扇形更宽
	
	for i in range(fan_count):
		var spread := PI / 3.0 if _current_phase >= 2 else PI / 4.0
		var angle := slash_angle - spread / 2.0 + (spread / float(max(1, fan_count - 1))) * i
		if fan_count == 1:
			angle = slash_angle
		_spawn_boss_projectile(global_position, angle,
			MIRROR_REFLECT_SPEED, THEME_A_DASH_DAMAGE * 0.4,
			Color(0.95, 0.9, 0.7, 0.8))
	
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.15)
		tween.tween_property(_sprite, "rotation", 0.0, 0.15)

## 冲刺残影
func _spawn_dash_afterimage() -> void:
	var afterimage := Polygon2D.new()
	afterimage.polygon = PackedVector2Array([
		Vector2(-8, -12), Vector2(8, -12), Vector2(8, 12), Vector2(-8, 12)
	])
	afterimage.color = Color(0.95, 0.9, 0.7, 0.4)
	afterimage.global_position = global_position
	afterimage.rotation = _dash_direction.angle()
	get_parent().add_child(afterimage)
	
	var tween := afterimage.create_tween()
	tween.tween_property(afterimage, "modulate:a", 0.0, 0.5)
	tween.tween_callback(afterimage.queue_free)

## 攻击2：主题B — 圆舞曲式弹幕
## GDD：优雅的双螺旋弹幕，如同华尔兹舞步
func _attack_theme_b_waltz(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", THEME_B_DAMAGE) * damage_mult
	_theme_b_performed = true
	
	var duration := 2.5
	var interval := 0.15
	var steps := int(duration / interval)
	
	for step in range(steps):
		var step_idx := step
		get_tree().create_timer(step * interval).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			# 双螺旋弹幕（GDD：圆舞曲旋转模式）
			for s in range(THEME_B_SPIRAL_COUNT):
				var angle := _waltz_angle + step_idx * 0.15 + (TAU / THEME_B_SPIRAL_COUNT) * s
				_spawn_boss_projectile(global_position, angle,
					THEME_B_PROJECTILE_SPEED, damage * 0.3,
					Color(0.9, 0.85, 0.6, 0.7))
		)

## 攻击3：优雅反击 — 精准的扇形弹幕
## GDD：如同击剑中的反击，快速精准
func _attack_elegant_riposte(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", 15.0) * damage_mult
	
	if _target == null:
		return
	
	var angle := (global_position.direction_to(_target.global_position)).angle()
	var count := 10
	for i in range(count):
		var a := angle + (i - (count - 1) / 2.0) * 0.1
		_spawn_boss_projectile(global_position, a,
			MIRROR_REFLECT_SPEED * 1.2, damage * 0.4,
			Color(1.0, 0.95, 0.7, 0.9))

## 攻击4：发展部 — 主题A+B组合
## GDD：发展部将两个主题混合变形，同时冲刺+释放旋转弹幕
func _attack_theme_ab_combined(attack: Dictionary, damage_mult: float) -> void:
	# 同时冲刺 + 释放旋转弹幕
	_attack_theme_a_dash(attack, damage_mult)
	
	get_tree().create_timer(0.3).timeout.connect(func():
		if _is_dead:
			return
		_attack_theme_b_waltz(attack, damage_mult)
	)

## 攻击5：镜面反射 — 发展部核心机制
## GDD：弹幕碰到"镜面边界"后反射，形成不可预测的弹幕路径
func _attack_mirror_reflection(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", 15.0) * damage_mult
	
	if _target == null:
		return
	
	# 激活镜面边界
	_activate_mirror_boundaries()
	
	var angle := (global_position.direction_to(_target.global_position)).angle()
	
	# 发射镜面反射弹幕
	var count := 8
	if _current_phase >= 2:
		count = 12  # 再现部增加弹幕数
	
	for i in range(count):
		var a := angle + (i - (count - 1) / 2.0) * 0.15
		_spawn_mirror_projectile(global_position, a,
			MIRROR_REFLECT_SPEED, damage * 0.5)
	
	# 镜面边界持续3秒
	get_tree().create_timer(3.0).timeout.connect(func():
		_deactivate_mirror_boundaries()
	)

## 攻击6：繁复诅咒 — 清除召唤物+增加疲劳
## GDD：如果玩家场上存在过多召唤物，莫扎特会清除它们
func _attack_complexity_curse() -> void:
	_check_complexity()

func _check_complexity() -> void:
	var summon_count := 0
	for node in get_tree().get_nodes_in_group("player_summons"):
		if is_instance_valid(node):
			summon_count += 1
	
	if summon_count >= COMPLEXITY_SUMMON_THRESHOLD:
		# GDD："化繁为简，朋友" — 清除召唤物
		for node in get_tree().get_nodes_in_group("player_summons"):
			if is_instance_valid(node) and node is Node2D:
				# 消散视觉（GDD：优雅的消散效果）
				var tween := node.create_tween()
				tween.tween_property(node, "modulate:a", 0.0, 0.5)
				tween.tween_callback(node.queue_free)
		
		# 增加疲劳
		if FatigueManager and FatigueManager.has_method("add_external_fatigue"):
			FatigueManager.add_external_fatigue(COMPLEXITY_FATIGUE_PENALTY)
		
		# 视觉：莫扎特优雅地摇头
		if _sprite:
			var tween := create_tween()
			tween.tween_property(_sprite, "rotation", 0.15, 0.15)
			tween.tween_property(_sprite, "rotation", -0.15, 0.3)
			tween.tween_property(_sprite, "rotation", 0.0, 0.15)

## 攻击7：华彩乐章 — 再现部终极攻击
## GDD：快速连续冲刺+密集弹幕，展现莫扎特的天才即兴能力
func _attack_cadenza(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", THEME_A_DASH_DAMAGE * 2.0) * damage_mult
	_cadenza_active = true
	
	# 快速连续冲刺 + 密集弹幕
	for i in range(CADENZA_DASH_COUNT):
		var i_idx := i
		get_tree().create_timer(i * 0.8).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			# 冲刺
			_start_dash()
			# 全方位弹幕
			for j in range(CADENZA_BARRAGE_COUNT):
				var angle := (TAU / CADENZA_BARRAGE_COUNT) * j + i_idx * 0.2
				_spawn_boss_projectile(global_position, angle,
					THEME_B_PROJECTILE_SPEED * 1.3, damage * 0.2,
					Color(1.0, 0.9, 0.4, 0.9))
		)
	
	get_tree().create_timer(CADENZA_DURATION).timeout.connect(func():
		_cadenza_active = false
	)

## 攻击8：终焉和弦 — 再现部专属终极必杀
## GDD：全方向光柱+冲击波，如同交响曲的最终和弦
func _attack_final_chord(attack: Dictionary, damage_mult: float) -> void:
	var damage: float = attack.get("damage", FINAL_CHORD_DAMAGE) * damage_mult
	
	# 预警：Boss升空+蓄力（GDD视觉：金色光芒聚集）
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.5, 1.5), 0.5)
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.95, 0.5), 0.5)
	
	# 1秒后释放终焉和弦
	get_tree().create_timer(1.0).timeout.connect(func():
		if _is_dead or not is_instance_valid(self):
			return
		
		# 全方向光柱（GDD：如同交响曲的最终和弦）
		for i in range(FINAL_CHORD_BEAM_COUNT):
			var angle := (TAU / FINAL_CHORD_BEAM_COUNT) * i
			var dir := Vector2.from_angle(angle)
			
			# 光柱视觉
			var beam := Line2D.new()
			beam.width = FINAL_CHORD_BEAM_WIDTH
			beam.default_color = Color(1.0, 0.95, 0.6, 0.9)
			beam.add_point(global_position)
			beam.add_point(global_position + dir * FINAL_CHORD_BEAM_LENGTH)
			get_parent().add_child(beam)
			
			# 伤害检测
			if _target and is_instance_valid(_target):
				var to_player := _target.global_position - global_position
				var proj := to_player.project(dir)
				var perp_dist := (to_player - proj).length()
				if perp_dist < FINAL_CHORD_BEAM_WIDTH / 2.0 and proj.length() < FINAL_CHORD_BEAM_LENGTH and proj.dot(dir) > 0:
					if _target.has_method("take_damage"):
						_target.take_damage(damage * 0.5)
			
			# 光柱消散
			var fade := beam.create_tween()
			fade.tween_property(beam, "modulate:a", 0.0, 0.6)
			fade.tween_callback(beam.queue_free)
		
		# 冲击波（环形弹幕）
		var ring_count := 24
		for i in range(ring_count):
			var angle := (TAU / ring_count) * i
			_spawn_boss_projectile(global_position, angle,
				THEME_B_PROJECTILE_SPEED * 0.8, damage * 0.3,
				Color(1.0, 0.9, 0.5, 0.7))
		
		# Boss恢复
		if _sprite:
			var tween := create_tween()
			tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.3)
			tween.tween_property(_sprite, "modulate", Color.WHITE, 0.3)
	)

# ============================================================
# 镜面反射系统（GDD：发展部核心机制）
# ============================================================

func _activate_mirror_boundaries() -> void:
	_mirror_active = true
	_mirror_boundaries.clear()
	
	# 四面镜面边界（以Boss为中心）
	var center := global_position
	var half := MIRROR_BOUNDARY_SIZE / 2.0
	_mirror_boundaries = [
		center + Vector2(-half, 0),  # 左
		center + Vector2(half, 0),   # 右
		center + Vector2(0, -half),  # 上
		center + Vector2(0, half),   # 下
	]
	
	# 镜面边界视觉（GDD：水晶般的半透明边界）
	for i in range(4):
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(0.8, 0.9, 1.0, 0.4)
		
		match i:
			0:  # 左
				line.add_point(center + Vector2(-half, -half))
				line.add_point(center + Vector2(-half, half))
			1:  # 右
				line.add_point(center + Vector2(half, -half))
				line.add_point(center + Vector2(half, half))
			2:  # 上
				line.add_point(center + Vector2(-half, -half))
				line.add_point(center + Vector2(half, -half))
			3:  # 下
				line.add_point(center + Vector2(-half, half))
				line.add_point(center + Vector2(half, half))
		
		get_parent().add_child(line)
		_mirror_visual_nodes.append(line)

func _deactivate_mirror_boundaries() -> void:
	_mirror_active = false
	for node in _mirror_visual_nodes:
		if is_instance_valid(node):
			var tween := node.create_tween()
			tween.tween_property(node, "modulate:a", 0.0, 0.3)
			tween.tween_callback(node.queue_free)
	_mirror_visual_nodes.clear()

## 镜面反射弹幕生成
func _spawn_mirror_projectile(pos: Vector2, angle: float, speed: float, damage: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	
	# 镜面弹幕视觉（菱形，GDD：水晶般的弹幕）
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0, -6), Vector2(6, 0), Vector2(0, 6), Vector2(-6, 0)
	])
	visual.color = Color(0.8, 0.9, 1.0, 0.9)
	proj.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	col.shape = shape
	proj.add_child(col)
	
	proj.global_position = pos
	
	if _projectile_container and is_instance_valid(_projectile_container):
		_projectile_container.add_child(proj)
	else:
		get_parent().add_child(proj)
	
	var vel := Vector2.from_angle(angle) * speed
	var reflect_count := 0
	
	var move_fn := func():
		if not is_instance_valid(proj):
			return
		
		var delta := get_process_delta_time()
		proj.global_position += vel * delta
		
		# 检测镜面边界反射（GDD：弹幕碰到镜面后反射）
		if _mirror_active and reflect_count < MIRROR_MAX_REFLECTS:
			for i in range(_mirror_boundaries.size()):
				var boundary: Vector2 = _mirror_boundaries[i]
				var dist := proj.global_position.distance_to(boundary)
				
				if dist < 30.0:
					if i < 2:  # 左右边界
						vel.x = -vel.x
					else:  # 上下边界
						vel.y = -vel.y
					
					reflect_count += 1
					
					# 反射视觉效果
					if is_instance_valid(visual):
						var flash := visual.create_tween()
						flash.tween_property(visual, "modulate", Color(1.0, 1.0, 1.0), 0.1)
						flash.tween_property(visual, "modulate", Color(0.8, 0.9, 1.0), 0.1)
					break
		
		# 碰撞检测
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
	
	get_tree().create_timer(MIRROR_LIFETIME).timeout.connect(func():
		if is_instance_valid(proj):
			proj.queue_free()
	)

# ============================================================
# Boss 弹幕生成
# ============================================================

func _spawn_boss_projectile(pos: Vector2, angle: float, speed: float,
		damage: float, color: Color = Color.WHITE) -> void:
	if color == Color.WHITE:
		color = base_color.lerp(Color.WHITE, 0.3)
	
	var proj := Area2D.new()
	proj.add_to_group("boss_projectiles")
	
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-3, -3), Vector2(6, 0), Vector2(-3, 3)
	])
	visual.color = color
	visual.rotation = angle
	proj.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	col.shape = shape
	proj.add_child(col)
	
	proj.global_position = pos
	proj.set_meta("velocity", Vector2.from_angle(angle) * speed)
	proj.set_meta("damage", damage)
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
		if age >= 5.0:
			proj.queue_free()
			return
		if _target and is_instance_valid(_target):
			if proj.global_position.distance_to(_target.global_position) < 15.0:
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
		0:
			_sonata_section = "exposition"
		1:
			_sonata_section = "development"
			_waltz_speed = 3.0
			_summon_cooldown_time = 12.0
		2:
			_sonata_section = "recapitulation"
			_waltz_speed = 4.0
			_summon_cooldown_time = 8.0

# ============================================================
# 狂暴
# ============================================================

func _on_enrage(level: int) -> void:
	match level:
		1:
			base_color = base_color.lerp(Color(1.0, 0.5, 0.2), 0.3)
			move_speed *= 1.2
		2:
			base_color = Color(1.0, 0.3, 0.1)
			move_speed *= 1.4
			# 所有攻击冷却缩短
			for phase in _phase_configs:
				for attack in phase.get("attacks", []):
					attack["cooldown"] = attack.get("cooldown", 2.0) * 0.6

# ============================================================
# 节拍回调
# ============================================================

func _on_boss_beat(_beat_index: int) -> void:
	_mozart_beat_counter += 1
	
	# 每 4 拍在非攻击状态时自动发射优雅弹幕
	if not _is_attacking and _mozart_beat_counter % 4 == 0:
		if _target and not _is_dead:
			var angle := (global_position.direction_to(_target.global_position)).angle()
			# 三连发精准弹幕
			for i in range(3):
				var a := angle + (i - 1) * 0.12
				_spawn_boss_projectile(global_position, a,
					THEME_B_PROJECTILE_SPEED * 0.6, 5.0,
					Color(0.9, 0.85, 0.6, 0.5))

# ============================================================
# 移动逻辑：优雅的绕圈移动
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _is_dashing:
		return Vector2.ZERO
	if _target == null:
		return Vector2.ZERO
	
	var to_player := _target.global_position - global_position
	var dist := to_player.length()
	
	# 莫扎特风格：优雅的绕圈移动（如同华尔兹）
	if dist > 200.0:
		return to_player.normalized()
	elif dist < 80.0:
		return -to_player.normalized()
	return to_player.normalized().rotated(PI / 2.5)

func _get_type_name() -> String:
	return "boss_mozart"

# ============================================================
# 清理
# ============================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _projectile_container and is_instance_valid(_projectile_container):
			for child in _projectile_container.get_children():
				if is_instance_valid(child):
					child.queue_free()
		for node in _mirror_visual_nodes:
			if is_instance_valid(node):
				node.queue_free()
