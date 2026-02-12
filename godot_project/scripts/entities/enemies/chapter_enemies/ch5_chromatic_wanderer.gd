## ch5_chromatic_wanderer.gd
## 第五章特色敌人：色彩游荡者 (Chromatic Wanderer)
## 移动路径呈半音阶式（小步频繁变向），攻击带有色彩变化效果。
## 音乐隐喻：浪漫主义的半音化和声——
## 瓦格纳式的色彩和声，在十二个半音之间自由游走，
## 模糊调性中心，创造出迷幻而不安定的听觉体验。
##
## 机制：
## - 移动路径呈半音阶式：每次移动只偏转一个小角度（半音=半个音程）
## - 频繁变向但每次变化幅度小，形成蛇形/螺旋形的不可预测路径
## - 攻击时释放"色彩弹幕"——弹幕颜色在十二色相环上循环
## - 不同颜色的弹幕有不同的附加效果（减速、DOT、击退等）
## - 身体颜色随移动不断变化，形成彩虹般的视觉效果
## - 靠近时会"感染"周围敌人，使其也获得色彩增益
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Chromatic Wanderer 专属配置
# ============================================================

## 半音阶移动：每次方向偏转角度（弧度）
@export var chromatic_step_angle: float = PI / 6.0  # 30度 ≈ 半音
## 变向间隔（秒）
@export var direction_change_interval: float = 0.4
## 色彩弹幕攻击间隔
@export var attack_interval: float = 2.0
## 弹幕伤害
@export var chromatic_damage: float = 10.0
## 弹幕速度
@export var chromatic_speed: float = 150.0
## 色彩感染范围
@export var chromatic_aura_radius: float = 100.0
## 色彩感染增益（给附近敌人的伤害加成）
@export var chromatic_buff_damage: float = 0.15
## 色彩循环速度
@export var color_cycle_speed: float = 1.5

# ============================================================
# 色彩系统
# ============================================================

## 十二色相环（对应十二个半音）
## C=红, C#=红橙, D=橙, D#=黄橙, E=黄, F=黄绿,
## F#=绿, G=青绿, G#=青, A=蓝, A#=蓝紫, B=紫
var _chromatic_palette: Array[Color] = [
	Color(1.0, 0.2, 0.2),    # C  — 红
	Color(1.0, 0.4, 0.15),   # C# — 红橙
	Color(1.0, 0.6, 0.1),    # D  — 橙
	Color(1.0, 0.8, 0.1),    # D# — 黄橙
	Color(1.0, 1.0, 0.2),    # E  — 黄
	Color(0.6, 1.0, 0.2),    # F  — 黄绿
	Color(0.2, 1.0, 0.4),    # F# — 绿
	Color(0.2, 1.0, 0.8),    # G  — 青绿
	Color(0.2, 0.8, 1.0),    # G# — 青
	Color(0.3, 0.4, 1.0),    # A  — 蓝
	Color(0.6, 0.3, 1.0),    # A# — 蓝紫
	Color(0.8, 0.2, 1.0),    # B  — 紫
]

## 弹幕附加效果类型
enum ChromaticEffect { NONE, SLOW, DOT, KNOCKBACK, WEAKEN }

## 色相→效果映射（每3个色相一组）
var _effect_map: Array[ChromaticEffect] = [
	ChromaticEffect.SLOW,      # C, C#, D
	ChromaticEffect.SLOW,
	ChromaticEffect.SLOW,
	ChromaticEffect.DOT,       # D#, E, F
	ChromaticEffect.DOT,
	ChromaticEffect.DOT,
	ChromaticEffect.KNOCKBACK, # F#, G, G#
	ChromaticEffect.KNOCKBACK,
	ChromaticEffect.KNOCKBACK,
	ChromaticEffect.WEAKEN,    # A, A#, B
	ChromaticEffect.WEAKEN,
	ChromaticEffect.WEAKEN,
]

# ============================================================
# 内部状态
# ============================================================

## 当前色相索引 (0-11)
var _current_hue_index: int = 0
## 色相相位（连续值，用于平滑过渡）
var _hue_phase: float = 0.0
## 移动方向角度
var _move_angle: float = 0.0
## 变向计时器
var _direction_timer: float = 0.0
## 攻击计时器
var _attack_timer: float = 0.0
## 感染检查计时器
var _aura_check_timer: float = 0.0
const AURA_CHECK_INTERVAL: float = 0.5
## 拖尾效果
var _trail_points: Array[Vector2] = []
var _trail_colors: Array[Color] = []
var _trail_line: Line2D = null
const MAX_TRAIL_POINTS: int = 20

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.SCREECH
	quantized_fps = 12.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.2
	move_on_offbeat = true

	# 初始颜色（随机起始色相）
	_current_hue_index = randi() % 12
	_hue_phase = float(_current_hue_index)
	base_color = _chromatic_palette[_current_hue_index]
	base_glitch_intensity = 0.08
	max_glitch_intensity = 0.6

	# 随机初始移动方向
	_move_angle = randf() * TAU

	# 创建拖尾效果
	_trail_line = Line2D.new()
	_trail_line.width = 5.0
	_trail_line.antialiased = true
	_trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trail_line)

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 色相循环
	_hue_phase += delta * color_cycle_speed
	_current_hue_index = int(fmod(_hue_phase, 12.0))
	var current_color := _get_interpolated_color()

	# 更新视觉颜色
	if _sprite:
		_sprite.modulate = current_color

	# 半音阶变向
	_direction_timer += delta
	if _direction_timer >= direction_change_interval:
		_direction_timer = 0.0
		_chromatic_direction_change()

	# 攻击计时
	_attack_timer += delta
	if _attack_timer >= attack_interval:
		_attack_timer = 0.0
		_fire_chromatic_projectile()

	# 色彩感染检查
	_aura_check_timer += delta
	if _aura_check_timer >= AURA_CHECK_INTERVAL:
		_aura_check_timer = 0.0
		_apply_chromatic_aura()

	# 更新拖尾
	_update_trail(current_color)

# ============================================================
# 半音阶移动
# ============================================================

## 半音阶式变向：每次只偏转一个小角度
func _chromatic_direction_change() -> void:
	# 半音阶移动：随机向左或向右偏转一个"半音"角度
	var direction := 1.0 if randf() > 0.5 else -1.0
	_move_angle += chromatic_step_angle * direction

	# 如果有目标，轻微偏向目标方向（避免完全随机游走）
	if _target and is_instance_valid(_target):
		var to_target := global_position.direction_to(_target.global_position)
		var target_angle := to_target.angle()
		var angle_diff := wrapf(target_angle - _move_angle, -PI, PI)
		# 10% 的吸引力朝向玩家
		_move_angle += angle_diff * 0.1

func _calculate_movement_direction() -> Vector2:
	return Vector2.from_angle(_move_angle)

# ============================================================
# 色彩弹幕攻击
# ============================================================

func _fire_chromatic_projectile() -> void:
	if _target == null:
		return

	var dir := global_position.direction_to(_target.global_position)
	var color := _chromatic_palette[_current_hue_index]
	var effect := _effect_map[_current_hue_index]

	# OPT03: 攻击时触发音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")

	var proj := Area2D.new()
	proj.add_to_group("enemy_projectiles")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	col.shape = shape
	proj.add_child(col)

	# 视觉：色彩菱形弹幕
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0, -6), Vector2(6, 0), Vector2(0, 6), Vector2(-6, 0)
	])
	visual.color = color
	proj.add_child(visual)

	# 辉光效果
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(0, -10), Vector2(10, 0), Vector2(0, 10), Vector2(-10, 0)
	])
	glow.color = Color(color.r, color.g, color.b, 0.3)
	proj.add_child(glow)

	proj.global_position = global_position
	get_parent().add_child(proj)

	# 弹幕飞行（略带弧度，模拟半音滑行）
	var curve_offset := Vector2.from_angle(dir.angle() + PI / 2.0) * sin(_hue_phase) * 30.0
	var end_pos := proj.global_position + dir * chromatic_speed * 2.5 + curve_offset
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position", end_pos, 2.5)
	tween.tween_callback(proj.queue_free)

	# 弹幕颜色渐变动画
	var color_tween := proj.create_tween()
	var next_color := _chromatic_palette[(_current_hue_index + 1) % 12]
	color_tween.tween_property(visual, "color", next_color, 2.5)

	# 碰撞检测
	var captured_effect := effect
	var captured_damage := chromatic_damage
	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(captured_damage)
			_apply_chromatic_effect(body, captured_effect)
			proj.queue_free()
	)

## 应用色彩弹幕的附加效果
func _apply_chromatic_effect(target: Node2D, effect: ChromaticEffect) -> void:
	match effect:
		ChromaticEffect.SLOW:
			# 减速效果（如果目标有减速方法）
			if target.has_method("apply_slow"):
				target.apply_slow(0.5, 2.0)  # 50%减速，持续2秒

		ChromaticEffect.DOT:
			# 持续伤害（通过多次小伤害模拟）
			if target.has_method("take_damage"):
				# 创建DOT计时器
				var dot_timer := Timer.new()
				dot_timer.wait_time = 0.5
				dot_timer.one_shot = false
				var ticks := 0
				dot_timer.timeout.connect(func():
					ticks += 1
					if ticks >= 4 or not is_instance_valid(target):
						dot_timer.queue_free()
						return
					if target.has_method("take_damage"):
						target.take_damage(chromatic_damage * 0.2)
				)
				get_tree().root.add_child(dot_timer)
				dot_timer.start()

		ChromaticEffect.KNOCKBACK:
			# 击退效果
			if target is CharacterBody2D:
				var kb_dir := global_position.direction_to(target.global_position)
				target.velocity = kb_dir * 250.0
				target.move_and_slide()

		ChromaticEffect.WEAKEN:
			# 弱化效果（暂时降低玩家伤害输出）
			pass  # 需要玩家系统支持

# ============================================================
# 色彩感染光环
# ============================================================

func _apply_chromatic_aura() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < chromatic_aura_radius:
			# 给附近敌人添加色彩增益视觉
			if enemy.has_method("get_sprite"):
				var sprite = enemy.get_sprite()
				if sprite:
					sprite.modulate = sprite.modulate.lerp(
						_chromatic_palette[_current_hue_index], 0.2
					)

# ============================================================
# 拖尾效果
# ============================================================

func _update_trail(current_color: Color) -> void:
	_trail_points.append(global_position)
	_trail_colors.append(current_color)

	while _trail_points.size() > MAX_TRAIL_POINTS:
		_trail_points.pop_front()
		_trail_colors.pop_front()

	if _trail_line:
		_trail_line.clear_points()
		for i in range(_trail_points.size()):
			_trail_line.add_point(to_local(_trail_points[i]))

		# 渐变效果
		var gradient := Gradient.new()
		if _trail_colors.size() >= 2:
			gradient.colors = PackedColorArray(_trail_colors)
			var offsets := PackedFloat32Array()
			for i in range(_trail_colors.size()):
				offsets.append(float(i) / float(_trail_colors.size() - 1))
			gradient.offsets = offsets
			_trail_line.gradient = gradient

# ============================================================
# 视觉辅助
# ============================================================

## 获取当前色相的平滑插值颜色
func _get_interpolated_color() -> Color:
	var idx := int(fmod(_hue_phase, 12.0))
	var next_idx := (idx + 1) % 12
	var t := fmod(_hue_phase, 1.0)
	return _chromatic_palette[idx].lerp(_chromatic_palette[next_idx], t)

# ============================================================
# 节拍响应
# ============================================================

func _on_beat(_beat_index: int) -> void:
	# 每个节拍推进一个半音
	_current_hue_index = (_current_hue_index + 1) % 12

	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.15, 1.15), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# 死亡时释放"色彩爆发"——向12个方向各发射一个不同颜色的弹幕
	for i in range(12):
		var angle := float(i) / 12.0 * TAU
		var dir := Vector2.from_angle(angle)
		var color := _chromatic_palette[i]

		var proj := Area2D.new()
		proj.add_to_group("enemy_projectiles")

		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 4.0
		col.shape = shape
		proj.add_child(col)

		var visual := Polygon2D.new()
		visual.polygon = PackedVector2Array([
			Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
		])
		visual.color = color
		proj.add_child(visual)

		proj.global_position = global_position
		get_parent().add_child(proj)

		var end_pos := proj.global_position + dir * 200.0
		var tween := proj.create_tween()
		tween.set_parallel(true)
		tween.tween_property(proj, "global_position", end_pos, 1.0)
		tween.tween_property(proj, "modulate:a", 0.0, 1.0)
		tween.chain()
		tween.tween_callback(proj.queue_free)

	# 清理拖尾
	if _trail_line:
		_trail_line.clear_points()
