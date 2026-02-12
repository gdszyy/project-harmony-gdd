## ch5_fate_knocker.gd
## 第五章特色敌人：命运叩门者 (Fate Knocker)
## 以"命运动机"（短-短-短-长）节奏释放冲击波的重型敌人。
## 音乐隐喻：贝多芬《命运交响曲》的标志性四音动机。
## 机制：
## - 以"短-短-短-长"节奏发射冲击波
## - 前三次为小型冲击，第四次为大范围冲击
## - 冲击波有击退效果
## - 被击杀时释放最后一次"命运之击"
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Fate Knocker 专属配置
# ============================================================
## 小冲击伤害
@export var small_knock_damage: float = 8.0
## 大冲击伤害
@export var big_knock_damage: float = 20.0
## 小冲击范围
@export var small_knock_radius: float = 60.0
## 大冲击范围
@export var big_knock_radius: float = 120.0
## 冲击波击退力
@export var knock_force: float = 200.0
## 动机间隔（短音符）
@export var short_note_interval: float = 0.4
## 动机间隔（长音符后的休止）
@export var long_note_rest: float = 2.0

# ============================================================
# 内部状态
# ============================================================
## 命运动机计数 (0=短1, 1=短2, 2=短3, 3=长)
var _motif_index: int = 0
var _motif_timer: float = 0.0
var _motif_active: bool = false
## 蓄力视觉
var _charge_phase: float = 0.0
## 是否在蓄力大冲击
var _charging_big: bool = false

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.PULSE
	quantized_fps = 8.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.6
	move_on_offbeat = false
	
	# 深沉的暗红色（命运的沉重感）
	base_color = Color(0.6, 0.15, 0.15)
	base_glitch_intensity = 0.1
	max_glitch_intensity = 0.7
	
	# 较高HP
	max_hp *= 1.8
	current_hp = max_hp

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	_motif_timer += delta
	
	# 命运动机节奏
	if _motif_index < 3:
		# 短音符
		if _motif_timer >= short_note_interval:
			_motif_timer = 0.0
			_fire_small_knock()
			_motif_index += 1
	elif _motif_index == 3:
		# 长音符（蓄力）
		_charging_big = true
		_charge_phase += delta * 5.0
		if _sprite:
			var pulse := sin(_charge_phase) * 0.15
			_sprite.scale = Vector2(1.0 + pulse, 1.0 + pulse)
			_sprite.modulate = base_color.lerp(Color(1.0, 0.3, 0.1), 0.3 + pulse)
		
		if _motif_timer >= short_note_interval * 2.0:
			_motif_timer = 0.0
			_fire_big_knock()
			_motif_index = 4
			_charging_big = false
	else:
		# 休止
		if _motif_timer >= long_note_rest:
			_motif_timer = 0.0
			_motif_index = 0
			_charge_phase = 0.0
			if _sprite:
				_sprite.scale = Vector2(1.0, 1.0)
				_sprite.modulate = base_color

# ============================================================
# 冲击波攻击
# ============================================================

## 小冲击（短音符）
func _fire_small_knock() -> void:
	# OPT03: 攻击时触发音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")
	_create_shockwave(small_knock_radius, small_knock_damage,
		Color(0.6, 0.2, 0.2, 0.5), knock_force * 0.5)
	
	# 视觉反馈
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.2, 1.2), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

## 大冲击（长音符）
func _fire_big_knock() -> void:
	# OPT03: 攻击时触发音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")
	_create_shockwave(big_knock_radius, big_knock_damage,
		Color(1.0, 0.3, 0.1, 0.6), knock_force)
	
	# 强烈视觉反馈
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.6, 1.6), 0.08)
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.5, 0.2), 0.08)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.2)
		tween.tween_property(_sprite, "modulate", base_color, 0.3)

## 创建冲击波
func _create_shockwave(radius: float, damage: float, color: Color, force: float) -> void:
	# 冲击波视觉（扩展的圆环）
	var wave := Node2D.new()
	wave.global_position = global_position
	get_parent().add_child(wave)
	
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(24):
		var angle := (TAU / 24) * i
		points.append(Vector2.from_angle(angle) * 5.0)
	ring.polygon = points
	ring.color = color
	wave.add_child(ring)
	
	# 扩展动画
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", Vector2(radius / 5.0, radius / 5.0), 0.3)
	tween.parallel().tween_property(ring, "color:a", 0.0, 0.3)
	tween.tween_callback(wave.queue_free)
	
	# 伤害检测
	if _target and is_instance_valid(_target):
		var dist := global_position.distance_to(_target.global_position)
		if dist < radius:
			if _target.has_method("take_damage"):
				_target.take_damage(damage)
			# 击退
			var knockback_dir := (global_position.direction_to(_target.global_position)).normalized()
			if _target.has_method("apply_knockback"):
				_target.apply_knockback(knockback_dir * force)

# ============================================================
# 移动逻辑：缓慢但坚定
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	# 蓄力大冲击时停止移动
	if _charging_big:
		return Vector2.ZERO
	
	return (_target.global_position - global_position).normalized()

# ============================================================
# 节拍响应
# ============================================================

func _on_beat(_beat_index: int) -> void:
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.08, 1.08), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

# ============================================================
# 死亡效果：最后的命运之击
# ============================================================

func _on_death_effect() -> void:
	_create_shockwave(big_knock_radius * 1.5, big_knock_damage * 0.5,
		Color(1.0, 0.2, 0.0, 0.8), knock_force * 1.5)
