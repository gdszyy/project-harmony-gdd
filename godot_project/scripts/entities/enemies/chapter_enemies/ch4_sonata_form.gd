## ch4_sonata_form.gd
## 第四章特色敌人：奏鸣曲式 (Sonata Form)
## 三阶段行为模式（呈示→展开→再现），每阶段攻击模式不同。
## 音乐隐喻：古典奏鸣曲的呈示-展开-再现结构——
## 音乐中最伟大的形式逻辑，在敌人行为中具象化。
##
## 机制：
## - 呈示部 (Exposition)：规律性直线冲刺 + 单发弹幕，攻击模式固定可预测
## - 展开部 (Development)：将呈示部的攻击模式变形组合，冲刺+弹幕同时释放
## - 再现部 (Recapitulation)：回归呈示部模式但速度和伤害大幅提升
## - 每个阶段持续一定时间后自动转换
## - 阶段转换时有明显的视觉和音频提示
## - 击杀后根据当前阶段掉落不同品质的奖励
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Sonata Form 专属配置
# ============================================================

## 阶段枚举
enum SonataPhase { EXPOSITION, DEVELOPMENT, RECAPITULATION }

## 当前阶段
var _current_phase: SonataPhase = SonataPhase.EXPOSITION

## 各阶段持续时间（秒）
@export var exposition_duration: float = 8.0
@export var development_duration: float = 10.0
@export var recapitulation_duration: float = 8.0

## 呈示部配置
@export var expo_dash_speed: float = 300.0
@export var expo_dash_duration: float = 0.3
@export var expo_dash_cooldown: float = 3.0
@export var expo_projectile_damage: float = 10.0
@export var expo_projectile_speed: float = 160.0

## 展开部配置（呈示部变形）
@export var dev_dash_speed: float = 350.0
@export var dev_projectile_count: int = 3
@export var dev_projectile_spread: float = 0.5  # ~28度扇形
@export var dev_combo_cooldown: float = 2.5

## 再现部配置（呈示部增强）
@export var recap_speed_multiplier: float = 1.5
@export var recap_damage_multiplier: float = 1.8
@export var recap_dash_cooldown: float = 2.0

## 阶段转换视觉
@export var transition_flash_color: Color = Color(1.0, 0.95, 0.7, 1.0)

# ============================================================
# 内部状态
# ============================================================

## 阶段计时器
var _phase_timer: float = 0.0
## 攻击冷却
var _attack_cooldown: float = 0.0
## 冲刺状态
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
## 阶段转换动画
var _transitioning: bool = false
var _transition_timer: float = 0.0
const TRANSITION_DURATION: float = 0.8
## 呈示部主题记录（供展开部变形使用）
var _theme_a_direction: Vector2 = Vector2.ZERO  # 上次冲刺方向
var _theme_b_direction: Vector2 = Vector2.ZERO  # 上次弹幕方向
## 视觉相位
var _visual_phase: float = 0.0
## 阶段颜色
var _phase_colors: Dictionary = {
	SonataPhase.EXPOSITION: Color(0.85, 0.75, 0.5),       # 明亮金色（古典优雅）
	SonataPhase.DEVELOPMENT: Color(0.7, 0.4, 0.2),        # 深铜色（紧张展开）
	SonataPhase.RECAPITULATION: Color(1.0, 0.85, 0.4),    # 辉煌金色（回归增强）
}
## 循环计数（完成一次完整奏鸣曲后增强）
var _cycle_count: int = 0

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.PULSE
	quantized_fps = 10.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.35
	move_on_offbeat = false

	# 古典金色调
	base_color = _phase_colors[SonataPhase.EXPOSITION]
	base_glitch_intensity = 0.06
	max_glitch_intensity = 0.5

	# 中等HP
	max_hp *= 1.4
	current_hp = max_hp

	# 从呈示部开始
	_current_phase = SonataPhase.EXPOSITION
	_phase_timer = 0.0
	_attack_cooldown = 1.5  # 初始延迟

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 阶段转换动画
	if _transitioning:
		_transition_timer += delta
		if _transition_timer >= TRANSITION_DURATION:
			_transitioning = false
			_transition_timer = 0.0
		else:
			# 转换期间闪烁效果
			var t := _transition_timer / TRANSITION_DURATION
			if _sprite:
				var flash := sin(t * TAU * 4.0) * 0.5 + 0.5
				_sprite.modulate = base_color.lerp(transition_flash_color, flash)
			return  # 转换期间不执行攻击

	# 阶段计时
	_phase_timer += delta
	_check_phase_transition()

	# 冲刺更新
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_is_dashing = false
			velocity = Vector2.ZERO
		else:
			var current_dash_speed := expo_dash_speed
			if _current_phase == SonataPhase.DEVELOPMENT:
				current_dash_speed = dev_dash_speed
			elif _current_phase == SonataPhase.RECAPITULATION:
				current_dash_speed = expo_dash_speed * recap_speed_multiplier
			velocity = _dash_direction * current_dash_speed
			move_and_slide()

	# 攻击冷却
	_attack_cooldown -= delta
	if _attack_cooldown <= 0.0 and not _is_dashing and not _transitioning:
		_execute_phase_attack()

	# 视觉更新
	_update_phase_visuals(delta)

# ============================================================
# 阶段转换
# ============================================================

func _check_phase_transition() -> void:
	var duration := 0.0
	match _current_phase:
		SonataPhase.EXPOSITION:
			duration = exposition_duration
		SonataPhase.DEVELOPMENT:
			duration = development_duration
		SonataPhase.RECAPITULATION:
			duration = recapitulation_duration

	if _phase_timer >= duration:
		_advance_phase()

func _advance_phase() -> void:
	_phase_timer = 0.0
	_transitioning = true
	_transition_timer = 0.0

	match _current_phase:
		SonataPhase.EXPOSITION:
			_current_phase = SonataPhase.DEVELOPMENT
		SonataPhase.DEVELOPMENT:
			_current_phase = SonataPhase.RECAPITULATION
		SonataPhase.RECAPITULATION:
			# 完成一个完整的奏鸣曲循环
			_current_phase = SonataPhase.EXPOSITION
			_cycle_count += 1
			# 每次循环后略微增强
			max_hp *= 1.1
			current_hp = min(current_hp + max_hp * 0.1, max_hp)

	# 更新基础颜色
	base_color = _phase_colors[_current_phase]

	# OPT03: 阶段转换时触发音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")

	# 阶段转换脉冲
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.3)

# ============================================================
# 阶段攻击
# ============================================================

func _execute_phase_attack() -> void:
	match _current_phase:
		SonataPhase.EXPOSITION:
			_attack_exposition()
		SonataPhase.DEVELOPMENT:
			_attack_development()
		SonataPhase.RECAPITULATION:
			_attack_recapitulation()

## 呈示部攻击：规律冲刺 + 单发弹幕（主题A + 主题B）
func _attack_exposition() -> void:
	if _target == null:
		return

	# 交替使用主题A（冲刺）和主题B（弹幕）
	if randf() > 0.5:
		_execute_theme_a_dash()
	else:
		_execute_theme_b_projectile()

	_attack_cooldown = expo_dash_cooldown

## 展开部攻击：主题变形——冲刺+弹幕同时释放
func _attack_development() -> void:
	if _target == null:
		return

	# 同时执行冲刺和扇形弹幕
	_execute_theme_a_dash()
	# 冲刺过程中释放扇形弹幕
	_fire_spread_projectiles()

	_attack_cooldown = dev_combo_cooldown

## 再现部攻击：呈示部增强版
func _attack_recapitulation() -> void:
	if _target == null:
		return

	# 与呈示部相同的模式，但更快更强
	if randf() > 0.5:
		_execute_theme_a_dash()
	else:
		_execute_theme_b_projectile()

	_attack_cooldown = recap_dash_cooldown

## 主题A：冲刺攻击
func _execute_theme_a_dash() -> void:
	if _target == null:
		return

	_dash_direction = global_position.direction_to(_target.global_position)
	_theme_a_direction = _dash_direction
	_is_dashing = true
	_dash_timer = expo_dash_duration

	# 冲刺视觉预警
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.3, 0.7), 0.1)
		tween.tween_property(_sprite, "scale", Vector2(0.8, 1.2), 0.05)

## 主题B：单发弹幕
func _execute_theme_b_projectile() -> void:
	if _target == null:
		return

	var dir := global_position.direction_to(_target.global_position)
	_theme_b_direction = dir
	var damage := expo_projectile_damage
	var speed := expo_projectile_speed

	if _current_phase == SonataPhase.RECAPITULATION:
		damage *= recap_damage_multiplier
		speed *= recap_speed_multiplier

	_fire_single_projectile(dir, damage, speed)

## 展开部扇形弹幕
func _fire_spread_projectiles() -> void:
	if _target == null:
		return

	var base_dir := global_position.direction_to(_target.global_position)
	var angle_step := dev_projectile_spread / float(dev_projectile_count - 1) if dev_projectile_count > 1 else 0.0
	var start_angle := base_dir.angle() - dev_projectile_spread / 2.0

	for i in range(dev_projectile_count):
		var angle := start_angle + angle_step * i
		var dir := Vector2.from_angle(angle)
		_fire_single_projectile(dir, expo_projectile_damage * 0.8, expo_projectile_speed * 0.9)

## 发射单个弹幕
func _fire_single_projectile(dir: Vector2, damage: float, speed: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("enemy_projectiles")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	proj.add_child(col)

	# 视觉：根据阶段不同颜色的音符弹幕
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
	])
	visual.color = _phase_colors[_current_phase]
	visual.rotation = dir.angle()
	proj.add_child(visual)

	proj.global_position = global_position
	get_parent().add_child(proj)

	# 弹幕飞行
	var end_pos := proj.global_position + dir * speed * 3.0
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position", end_pos, 3.0)
	tween.tween_callback(proj.queue_free)

	# 碰撞检测
	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			proj.queue_free()
	)

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null or _is_dashing or _transitioning:
		return Vector2.ZERO

	var to_player := (_target.global_position - global_position)
	var dist := to_player.length()

	match _current_phase:
		SonataPhase.EXPOSITION:
			# 呈示部：保持中等距离，缓慢接近
			if dist > 200.0:
				return to_player.normalized()
			elif dist < 100.0:
				return -to_player.normalized() * 0.5
			return Vector2.ZERO

		SonataPhase.DEVELOPMENT:
			# 展开部：绕玩家做圆弧运动
			var tangent := to_player.normalized().rotated(PI / 2.0)
			var approach := to_player.normalized() if dist > 150.0 else Vector2.ZERO
			return (tangent * 0.7 + approach * 0.3).normalized()

		SonataPhase.RECAPITULATION:
			# 再现部：更积极地接近
			if dist > 80.0:
				return to_player.normalized()
			return Vector2.ZERO

	return Vector2.ZERO

# ============================================================
# 视觉更新
# ============================================================

func _update_phase_visuals(delta: float) -> void:
	_visual_phase += delta * 3.0

	if _sprite == null:
		return

	if _transitioning:
		return

	# 根据阶段不同的视觉脉冲
	match _current_phase:
		SonataPhase.EXPOSITION:
			# 稳定的轻微脉冲（规律感）
			var pulse := sin(_visual_phase * 2.0) * 0.05
			_sprite.modulate = base_color * (1.0 + pulse)

		SonataPhase.DEVELOPMENT:
			# 不规则的强烈脉冲（紧张感）
			var pulse := sin(_visual_phase * 4.0) * sin(_visual_phase * 2.7) * 0.15
			_sprite.modulate = base_color * (1.0 + pulse)
			# 展开部轻微抖动
			_sprite.position = Vector2(
				sin(_visual_phase * 7.0) * 1.5,
				cos(_visual_phase * 5.0) * 1.5
			)

		SonataPhase.RECAPITULATION:
			# 辉煌的强脉冲（回归的力量感）
			var pulse := sin(_visual_phase * 3.0) * 0.1
			_sprite.modulate = base_color * (1.2 + pulse)

# ============================================================
# 节拍响应
# ============================================================

func _on_beat(_beat_index: int) -> void:
	if _sprite and not _transitioning:
		var tween := create_tween()
		# 根据阶段不同的节拍响应
		match _current_phase:
			SonataPhase.EXPOSITION:
				tween.tween_property(_sprite, "scale", Vector2(1.1, 1.1), 0.05)
				tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)
			SonataPhase.DEVELOPMENT:
				# 展开部更强烈的节拍响应
				tween.tween_property(_sprite, "scale", Vector2(1.2, 0.9), 0.04)
				tween.tween_property(_sprite, "scale", Vector2(0.9, 1.2), 0.04)
				tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.08)
			SonataPhase.RECAPITULATION:
				tween.tween_property(_sprite, "scale", Vector2(1.15, 1.15), 0.05)
				tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

# ============================================================
# 伤害处理
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	# 展开部受到的伤害略微减少（紧张的展开不易被打断）
	var final_amount := amount
	if _current_phase == SonataPhase.DEVELOPMENT:
		final_amount *= 0.85

	# 冲刺中受击退效果减弱
	if _is_dashing:
		knockback_dir *= 0.3

	super.take_damage(final_amount, knockback_dir, is_perfect_beat)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# 死亡时根据当前阶段释放不同效果
	match _current_phase:
		SonataPhase.EXPOSITION:
			# 呈示部死亡：简单的碎裂
			pass

		SonataPhase.DEVELOPMENT:
			# 展开部死亡：释放一圈弹幕（未完成的展开）
			if _target:
				for i in range(6):
					var angle := float(i) / 6.0 * TAU
					var dir := Vector2.from_angle(angle)
					_fire_single_projectile(dir, expo_projectile_damage * 0.5, expo_projectile_speed * 0.7)

		SonataPhase.RECAPITULATION:
			# 再现部死亡：释放最终的"完美终止"冲击波
			_fire_death_cadence()

## 再现部死亡特效：完美终止式冲击波
func _fire_death_cadence() -> void:
	# 创建扩散的视觉冲击波
	var wave := Polygon2D.new()
	var points := PackedVector2Array()
	var segments := 24
	for i in range(segments):
		var angle := float(i) / segments * TAU
		points.append(Vector2(cos(angle), sin(angle)) * 10.0)
	wave.polygon = points
	wave.color = Color(1.0, 0.9, 0.5, 0.6)
	wave.global_position = global_position
	get_parent().add_child(wave)

	var tween := wave.create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave, "scale", Vector2(8.0, 8.0), 0.5)
	tween.tween_property(wave, "modulate:a", 0.0, 0.5)
	tween.chain()
	tween.tween_callback(wave.queue_free)

	# 对范围内玩家造成伤害
	if _target and is_instance_valid(_target):
		var dist := global_position.distance_to(_target.global_position)
		if dist < 120.0 and _target.has_method("take_damage"):
			_target.take_damage(expo_projectile_damage * recap_damage_multiplier)

# ============================================================
# 工具函数
# ============================================================

## 获取当前阶段名称（供UI或调试使用）
func get_current_phase_name() -> String:
	match _current_phase:
		SonataPhase.EXPOSITION:
			return "exposition"
		SonataPhase.DEVELOPMENT:
			return "development"
		SonataPhase.RECAPITULATION:
			return "recapitulation"
	return "unknown"

## 获取当前阶段进度 (0.0 ~ 1.0)
func get_phase_progress() -> float:
	var duration := 0.0
	match _current_phase:
		SonataPhase.EXPOSITION:
			duration = exposition_duration
		SonataPhase.DEVELOPMENT:
			duration = development_duration
		SonataPhase.RECAPITULATION:
			duration = recapitulation_duration
	return _phase_timer / duration if duration > 0.0 else 0.0
