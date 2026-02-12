## ch6_atonal_shifter.gd
## 第六章特色敌人：无调性变形者 / 爵士即兴者 (Atonal Shifter / Jazz Improviser)
## 攻击模式随机化，难以预测。
## 音乐隐喻：现代音乐的无调性（勋伯格十二音技法）与爵士即兴——
## 打破一切既有规则和模式，在混沌中寻找新的秩序。
##
## 机制：
## - 拥有多种攻击模式（直线、扇形、环形、追踪、延迟爆破）
## - 每次攻击随机选择一种模式，无法被玩家预判
## - 形态随攻击模式变化（视觉变形）
## - 偶尔进入"即兴独奏"状态：短时间内快速连续释放不同模式的攻击
## - 被击中时有概率"变调"——随机改变自身属性（速度、大小、颜色）
## - 多个 Atonal Shifter 之间不会使用相同的攻击模式（十二音序列原则）
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Atonal Shifter 专属配置
# ============================================================

## 攻击间隔
@export var attack_interval: float = 2.5
## 弹幕基础伤害
@export var base_projectile_damage: float = 10.0
## 弹幕基础速度
@export var base_projectile_speed: float = 160.0
## 即兴独奏触发概率（每次攻击后）
@export var solo_chance: float = 0.15
## 即兴独奏持续时间
@export var solo_duration: float = 3.0
## 即兴独奏攻击间隔
@export var solo_attack_interval: float = 0.4
## 变调概率（被击中时）
@export var transpose_chance: float = 0.3
## 变调持续时间
@export var transpose_duration: float = 4.0

## 攻击模式枚举
enum AttackPattern {
	LINEAR,          # 直线弹幕
	SPREAD,          # 扇形弹幕
	RING,            # 环形弹幕
	HOMING,          # 追踪弹幕
	DELAYED_BURST,   # 延迟爆破
	SPIRAL,          # 螺旋弹幕
	RANDOM_SCATTER,  # 随机散射
	CROSS,           # 十字弹幕
	WAVE,            # 波浪弹幕
	BOUNCE,          # 反弹弹幕
	CLUSTER,         # 集束弹幕
	BEAM,            # 光束弹幕
}

## 攻击模式对应的视觉颜色
var _pattern_colors: Dictionary = {
	AttackPattern.LINEAR:         Color(0.9, 0.3, 0.3),   # 红
	AttackPattern.SPREAD:         Color(0.9, 0.6, 0.2),   # 橙
	AttackPattern.RING:           Color(0.9, 0.9, 0.2),   # 黄
	AttackPattern.HOMING:         Color(0.3, 0.9, 0.3),   # 绿
	AttackPattern.DELAYED_BURST:  Color(0.2, 0.8, 0.8),   # 青
	AttackPattern.SPIRAL:         Color(0.3, 0.3, 0.9),   # 蓝
	AttackPattern.RANDOM_SCATTER: Color(0.7, 0.3, 0.9),   # 紫
	AttackPattern.CROSS:          Color(0.9, 0.5, 0.7),   # 粉
	AttackPattern.WAVE:           Color(0.5, 0.9, 0.7),   # 薄荷
	AttackPattern.BOUNCE:         Color(0.8, 0.8, 0.5),   # 卡其
	AttackPattern.CLUSTER:        Color(0.6, 0.4, 0.3),   # 棕
	AttackPattern.BEAM:           Color(0.95, 0.95, 0.95), # 白
}

# ============================================================
# 内部状态
# ============================================================

## 攻击计时
var _attack_timer: float = 0.0
## 已使用的攻击模式（十二音序列追踪）
var _used_patterns: Array[AttackPattern] = []
## 当前攻击模式
var _current_pattern: AttackPattern = AttackPattern.LINEAR
## 即兴独奏状态
var _is_soloing: bool = false
var _solo_timer: float = 0.0
var _solo_attack_timer: float = 0.0
## 变调状态
var _is_transposed: bool = false
var _transpose_timer: float = 0.0
var _transpose_speed_mult: float = 1.0
var _transpose_scale_mult: float = 1.0
## 形态变形动画
var _morph_phase: float = 0.0
## 原始属性备份
var _original_move_speed: float = 0.0
var _original_scale: Vector2 = Vector2.ONE

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.SCREECH
	quantized_fps = 10.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.25
	move_on_offbeat = true

	# 不稳定的灰紫色调（无调性的不确定感）
	base_color = Color(0.6, 0.5, 0.7)
	base_glitch_intensity = 0.12
	max_glitch_intensity = 0.8

	_original_move_speed = move_speed
	_original_scale = scale

	# 随机初始攻击模式
	_current_pattern = AttackPattern.values()[randi() % AttackPattern.size()]

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 形态变形动画
	_morph_phase += delta * 2.0
	_update_morph_visuals(delta)

	# 即兴独奏状态
	if _is_soloing:
		_solo_timer -= delta
		_solo_attack_timer -= delta

		if _solo_timer <= 0.0:
			_is_soloing = false
			_attack_timer = attack_interval * 0.5  # 独奏后短暂休息
		elif _solo_attack_timer <= 0.0:
			_solo_attack_timer = solo_attack_interval
			_execute_random_attack()
		return

	# 变调状态
	if _is_transposed:
		_transpose_timer -= delta
		if _transpose_timer <= 0.0:
			_end_transpose()

	# 常规攻击计时
	_attack_timer += delta
	if _attack_timer >= attack_interval:
		_attack_timer = 0.0
		_execute_random_attack()

		# 检查是否触发即兴独奏
		if randf() < solo_chance:
			_start_solo()

# ============================================================
# 攻击系统：十二音序列
# ============================================================

## 选择下一个攻击模式（遵循十二音序列原则）
func _select_next_pattern() -> AttackPattern:
	# 如果所有12种模式都用过了，重置序列
	if _used_patterns.size() >= AttackPattern.size():
		_used_patterns.clear()

	# 从未使用的模式中随机选择
	var available: Array[AttackPattern] = []
	for pattern in AttackPattern.values():
		if pattern not in _used_patterns:
			available.append(pattern)

	var selected := available[randi() % available.size()]
	_used_patterns.append(selected)
	return selected

## 执行随机攻击
func _execute_random_attack() -> void:
	if _target == null:
		return

	_current_pattern = _select_next_pattern()
	base_color = _pattern_colors[_current_pattern]

	# OPT03: 攻击时触发音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")

	match _current_pattern:
		AttackPattern.LINEAR:
			_attack_linear()
		AttackPattern.SPREAD:
			_attack_spread()
		AttackPattern.RING:
			_attack_ring()
		AttackPattern.HOMING:
			_attack_homing()
		AttackPattern.DELAYED_BURST:
			_attack_delayed_burst()
		AttackPattern.SPIRAL:
			_attack_spiral()
		AttackPattern.RANDOM_SCATTER:
			_attack_random_scatter()
		AttackPattern.CROSS:
			_attack_cross()
		AttackPattern.WAVE:
			_attack_wave()
		AttackPattern.BOUNCE:
			_attack_bounce()
		AttackPattern.CLUSTER:
			_attack_cluster()
		AttackPattern.BEAM:
			_attack_beam()

	# 攻击时的形态变形脉冲
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.3, 0.8), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(0.8, 1.3), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

# ============================================================
# 12种攻击模式实现
# ============================================================

## 1. 直线弹幕
func _attack_linear() -> void:
	var dir := global_position.direction_to(_target.global_position)
	_spawn_projectile(dir, base_projectile_damage, base_projectile_speed)

## 2. 扇形弹幕
func _attack_spread() -> void:
	var base_dir := global_position.direction_to(_target.global_position)
	for i in range(5):
		var angle := base_dir.angle() + (i - 2) * 0.25
		var dir := Vector2.from_angle(angle)
		_spawn_projectile(dir, base_projectile_damage * 0.6, base_projectile_speed * 0.9)

## 3. 环形弹幕
func _attack_ring() -> void:
	for i in range(8):
		var angle := float(i) / 8.0 * TAU
		var dir := Vector2.from_angle(angle)
		_spawn_projectile(dir, base_projectile_damage * 0.5, base_projectile_speed * 0.8)

## 4. 追踪弹幕
func _attack_homing() -> void:
	var dir := global_position.direction_to(_target.global_position)

	var proj := Area2D.new()
	proj.add_to_group("enemy_projectiles")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	proj.add_child(col)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0, -5), Vector2(5, 3), Vector2(-5, 3)
	])
	visual.color = _pattern_colors[AttackPattern.HOMING]
	proj.add_child(visual)

	proj.global_position = global_position
	get_parent().add_child(proj)

	# 追踪逻辑通过 tween 模拟
	var target_ref := _target
	var lifetime := 0.0
	var vel := dir * base_projectile_speed * 0.7
	proj.set_meta("velocity", vel)
	proj.set_meta("lifetime", 0.0)

	# 使用 process 回调实现追踪
	var timer := Timer.new()
	timer.wait_time = 0.016  # ~60fps
	timer.one_shot = false
	var damage := base_projectile_damage * 0.8
	timer.timeout.connect(func():
		if not is_instance_valid(proj):
			timer.queue_free()
			return
		var lt: float = proj.get_meta("lifetime") + 0.016
		proj.set_meta("lifetime", lt)
		if lt > 3.0:
			proj.queue_free()
			timer.queue_free()
			return
		if is_instance_valid(target_ref):
			var to_target := proj.global_position.direction_to(target_ref.global_position)
			var current_vel: Vector2 = proj.get_meta("velocity")
			current_vel = current_vel.lerp(to_target * base_projectile_speed * 0.7, 0.03)
			proj.set_meta("velocity", current_vel)
			proj.global_position += current_vel * 0.016
			visual.rotation = current_vel.angle() + PI / 2.0
	)
	proj.add_child(timer)
	timer.start()

	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			proj.queue_free()
	)

## 5. 延迟爆破
func _attack_delayed_burst() -> void:
	if _target == null:
		return

	# 在目标位置放置延迟炸弹
	var target_pos := _target.global_position

	var marker := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(16):
		var angle := float(i) / 16.0 * TAU
		points.append(Vector2(cos(angle), sin(angle)) * 40.0)
	marker.polygon = points
	marker.color = Color(1.0, 0.3, 0.3, 0.3)
	marker.global_position = target_pos
	get_parent().add_child(marker)

	# 收缩动画（2拍延迟）
	var tween := marker.create_tween()
	tween.tween_property(marker, "scale", Vector2(0.1, 0.1), 1.2)
	tween.tween_callback(func():
		# 爆破
		if is_instance_valid(_target):
			var dist := target_pos.distance_to(_target.global_position)
			if dist < 50.0 and _target.has_method("take_damage"):
				_target.take_damage(base_projectile_damage * 1.5)

		# 爆破视觉
		marker.scale = Vector2(1.0, 1.0)
		marker.color = Color(1.0, 0.5, 0.2, 0.8)
		var explode_tween := marker.create_tween()
		explode_tween.set_parallel(true)
		explode_tween.tween_property(marker, "scale", Vector2(2.0, 2.0), 0.2)
		explode_tween.tween_property(marker, "modulate:a", 0.0, 0.3)
		explode_tween.chain()
		explode_tween.tween_callback(marker.queue_free)
	)

## 6. 螺旋弹幕
func _attack_spiral() -> void:
	for i in range(6):
		var delay := float(i) * 0.1
		# 使用 timer 延迟发射
		var timer := Timer.new()
		timer.wait_time = delay
		timer.one_shot = true
		var angle := _morph_phase + float(i) * (TAU / 6.0)
		timer.timeout.connect(func():
			if is_instance_valid(self) and not _is_dead:
				var dir := Vector2.from_angle(angle)
				_spawn_projectile(dir, base_projectile_damage * 0.5, base_projectile_speed * 0.85)
			timer.queue_free()
		)
		add_child(timer)
		timer.start()

## 7. 随机散射
func _attack_random_scatter() -> void:
	for i in range(7):
		var angle := randf() * TAU
		var dir := Vector2.from_angle(angle)
		var speed := base_projectile_speed * randf_range(0.6, 1.4)
		_spawn_projectile(dir, base_projectile_damage * 0.4, speed)

## 8. 十字弹幕
func _attack_cross() -> void:
	for i in range(4):
		var angle := float(i) * PI / 2.0
		var dir := Vector2.from_angle(angle)
		_spawn_projectile(dir, base_projectile_damage * 0.7, base_projectile_speed)
		# 对角线也发射
		var diag_dir := Vector2.from_angle(angle + PI / 4.0)
		_spawn_projectile(diag_dir, base_projectile_damage * 0.5, base_projectile_speed * 0.7)

## 9. 波浪弹幕
func _attack_wave() -> void:
	var base_dir := global_position.direction_to(_target.global_position) if _target else Vector2.RIGHT
	for i in range(5):
		var offset := (float(i) - 2.0) * 0.15
		var dir := Vector2.from_angle(base_dir.angle() + offset)
		# 波浪弹幕有正弦偏移
		_spawn_wave_projectile(dir, base_projectile_damage * 0.5, base_projectile_speed * 0.8, float(i) * 0.5)

## 10. 反弹弹幕（模拟，实际为变向弹幕）
func _attack_bounce() -> void:
	var dir := global_position.direction_to(_target.global_position) if _target else Vector2.RIGHT
	_spawn_bounce_projectile(dir, base_projectile_damage * 0.7, base_projectile_speed * 0.9)

## 11. 集束弹幕
func _attack_cluster() -> void:
	var dir := global_position.direction_to(_target.global_position) if _target else Vector2.RIGHT
	for i in range(3):
		var spread := Vector2(randf_range(-10, 10), randf_range(-10, 10))
		var proj_dir := (dir * 100.0 + spread).normalized()
		_spawn_projectile(proj_dir, base_projectile_damage * 0.6, base_projectile_speed * randf_range(0.9, 1.1))

## 12. 光束弹幕（快速直线）
func _attack_beam() -> void:
	var dir := global_position.direction_to(_target.global_position) if _target else Vector2.RIGHT
	_spawn_projectile(dir, base_projectile_damage * 1.3, base_projectile_speed * 2.0)

# ============================================================
# 弹幕生成辅助函数
# ============================================================

func _spawn_projectile(dir: Vector2, damage: float, speed: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("enemy_projectiles")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	proj.add_child(col)

	var visual := Polygon2D.new()
	# 根据当前模式使用不同形状
	match _current_pattern:
		AttackPattern.LINEAR, AttackPattern.BEAM:
			visual.polygon = PackedVector2Array([
				Vector2(-6, -2), Vector2(6, -2), Vector2(6, 2), Vector2(-6, 2)
			])
		AttackPattern.RING, AttackPattern.SPIRAL:
			visual.polygon = PackedVector2Array([
				Vector2(0, -5), Vector2(5, 0), Vector2(0, 5), Vector2(-5, 0)
			])
		_:
			visual.polygon = PackedVector2Array([
				Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
			])

	visual.color = _pattern_colors.get(_current_pattern, base_color)
	visual.rotation = dir.angle()
	proj.add_child(visual)

	proj.global_position = global_position
	get_parent().add_child(proj)

	var end_pos := proj.global_position + dir * speed * 3.0
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position", end_pos, 3.0)
	tween.tween_callback(proj.queue_free)

	var captured_damage := damage
	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(captured_damage)
			proj.queue_free()
	)

## 波浪弹幕（带正弦偏移）
func _spawn_wave_projectile(dir: Vector2, damage: float, speed: float, phase_offset: float) -> void:
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
	visual.color = _pattern_colors[AttackPattern.WAVE]
	proj.add_child(visual)

	proj.global_position = global_position
	get_parent().add_child(proj)

	# 波浪运动
	var base_pos := proj.global_position
	var perpendicular := dir.rotated(PI / 2.0)
	var time_elapsed := 0.0
	var captured_damage := damage

	var timer := Timer.new()
	timer.wait_time = 0.016
	timer.one_shot = false
	timer.timeout.connect(func():
		if not is_instance_valid(proj):
			timer.queue_free()
			return
		time_elapsed += 0.016
		if time_elapsed > 3.0:
			proj.queue_free()
			timer.queue_free()
			return
		var wave_offset := sin(time_elapsed * 5.0 + phase_offset) * 30.0
		proj.global_position = base_pos + dir * speed * time_elapsed + perpendicular * wave_offset
	)
	proj.add_child(timer)
	timer.start()

	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(captured_damage)
			proj.queue_free()
	)

## 反弹弹幕（中途变向一次）
func _spawn_bounce_projectile(dir: Vector2, damage: float, speed: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("enemy_projectiles")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	proj.add_child(col)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
	])
	visual.color = _pattern_colors[AttackPattern.BOUNCE]
	proj.add_child(visual)

	proj.global_position = global_position
	get_parent().add_child(proj)

	# 第一段飞行
	var mid_pos := proj.global_position + dir * speed * 0.8
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position", mid_pos, 0.8)

	# 中途变向（朝向玩家当前位置）
	var target_ref := _target
	var captured_damage := damage
	tween.tween_callback(func():
		if is_instance_valid(proj) and is_instance_valid(target_ref):
			var new_dir := proj.global_position.direction_to(target_ref.global_position)
			var end_pos := proj.global_position + new_dir * speed * 2.0
			var tween2 := proj.create_tween()
			tween2.tween_property(proj, "global_position", end_pos, 2.0)
			tween2.tween_callback(proj.queue_free)
		elif is_instance_valid(proj):
			proj.queue_free()
	)

	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(captured_damage)
			proj.queue_free()
	)

# ============================================================
# 即兴独奏
# ============================================================

func _start_solo() -> void:
	_is_soloing = true
	_solo_timer = solo_duration
	_solo_attack_timer = 0.0

	# 独奏开始视觉效果
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(_sprite, "modulate", base_color, 0.2)

	# 独奏时移速提升
	move_speed = _original_move_speed * 1.5

func _end_solo() -> void:
	_is_soloing = false
	move_speed = _original_move_speed * _transpose_speed_mult

# ============================================================
# 变调系统
# ============================================================

func _start_transpose() -> void:
	_is_transposed = true
	_transpose_timer = transpose_duration

	# 随机变调效果
	_transpose_speed_mult = randf_range(0.6, 1.8)
	_transpose_scale_mult = randf_range(0.7, 1.5)

	move_speed = _original_move_speed * _transpose_speed_mult
	scale = _original_scale * _transpose_scale_mult

	# 变调视觉
	base_color = Color(randf_range(0.3, 1.0), randf_range(0.3, 1.0), randf_range(0.3, 1.0))

func _end_transpose() -> void:
	_is_transposed = false
	_transpose_speed_mult = 1.0
	_transpose_scale_mult = 1.0
	move_speed = _original_move_speed
	scale = _original_scale
	base_color = Color(0.6, 0.5, 0.7)

# ============================================================
# 移动逻辑：不可预测的移动
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO

	var to_player := (_target.global_position - global_position)
	var dist := to_player.length()

	# 基础方向：朝向玩家
	var base_dir := to_player.normalized()

	# 添加随机偏移（无调性的不可预测感）
	var random_offset := Vector2(
		sin(_morph_phase * 3.7) * 0.5,
		cos(_morph_phase * 2.3) * 0.5
	)

	# 保持中等距离
	if dist < 80.0:
		base_dir = -base_dir * 0.5  # 太近时后退
	elif dist > 250.0:
		base_dir = base_dir  # 太远时接近

	return (base_dir + random_offset).normalized()

# ============================================================
# 视觉更新
# ============================================================

func _update_morph_visuals(delta: float) -> void:
	if _sprite == null:
		return

	# 不稳定的形态变形
	var morph_x := 1.0 + sin(_morph_phase * 3.0) * 0.1
	var morph_y := 1.0 + cos(_morph_phase * 2.5) * 0.1

	if not _is_soloing:
		_sprite.scale = Vector2(morph_x, morph_y)
	else:
		# 独奏时更剧烈的变形
		var solo_morph_x := 1.0 + sin(_morph_phase * 8.0) * 0.2
		var solo_morph_y := 1.0 + cos(_morph_phase * 6.0) * 0.2
		_sprite.scale = Vector2(solo_morph_x, solo_morph_y)

# ============================================================
# 伤害处理
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	super.take_damage(amount, knockback_dir, is_perfect_beat)

	# 被击中时有概率变调
	if randf() < transpose_chance and not _is_transposed:
		_start_transpose()

# ============================================================
# 节拍响应
# ============================================================

func _on_beat(_beat_index: int) -> void:
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.15, 1.15), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# 死亡时释放"十二音爆发"——12个方向各一种颜色的弹幕
	var patterns := AttackPattern.values()
	for i in range(min(12, patterns.size())):
		var angle := float(i) / 12.0 * TAU
		var dir := Vector2.from_angle(angle)
		var color := _pattern_colors.get(patterns[i], Color.WHITE)

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

		var end_pos := proj.global_position + dir * 180.0
		var tween := proj.create_tween()
		tween.set_parallel(true)
		tween.tween_property(proj, "global_position", end_pos, 0.8)
		tween.tween_property(proj, "modulate:a", 0.0, 0.8)
		tween.chain()
		tween.tween_callback(proj.queue_free)
