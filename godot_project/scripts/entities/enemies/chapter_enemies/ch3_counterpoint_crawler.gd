## ch3_counterpoint_crawler.gd
## 第三章特色敌人：对位爬虫 (Counterpoint Crawler)
## 双声部敌人：主体缓慢移动，背上的"炮塔"独立瞄准射击。
## 音乐隐喻：巴赫对位法中两个独立声部的具象化。
## 机制：
## - 主体（低音声部）缓慢追踪玩家
## - 炮塔（高音声部）独立旋转并射击
## - 两个部分可以分别受伤，先摧毁炮塔可削弱攻击
## - 主体死亡时炮塔也一起消失
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Counterpoint Crawler 专属配置
# ============================================================
## 炮塔射击间隔（秒）
@export var turret_fire_interval: float = 2.0
## 炮塔弹幕速度
@export var turret_projectile_speed: float = 200.0
## 炮塔弹幕伤害
@export var turret_projectile_damage: float = 10.0
## 炮塔旋转速度
@export var turret_rotation_speed: float = 1.5
## 炮塔HP（独立于主体）
@export var turret_hp: float = 40.0
## 炮塔弹幕数
@export var turret_projectile_count: int = 3
## 炮塔弹幕扇形角度
@export var turret_spread: float = 0.4  # ~23度

# ============================================================
# 内部状态
# ============================================================
var _turret_alive: bool = true
var _turret_current_hp: float = 0.0
var _turret_fire_timer: float = 0.0
var _turret_angle: float = 0.0
## 炮塔视觉节点
var _turret_visual: Node2D = null
## 对位节奏相位（主体和炮塔不同步）
var _body_phase: float = 0.0
var _turret_phase: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.PULSE
	quantized_fps = 8.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.4
	move_on_offbeat = false
	
	# 铜管色调（巴洛克机械感）
	base_color = Color(0.7, 0.5, 0.2)
	base_glitch_intensity = 0.08
	max_glitch_intensity = 0.6
	
	# 初始化炮塔
	_turret_current_hp = turret_hp
	_setup_turret_visual()

func _setup_turret_visual() -> void:
	_turret_visual = Node2D.new()
	_turret_visual.name = "Turret"
	
	# 炮塔形状：小三角
	var turret_shape := Polygon2D.new()
	turret_shape.polygon = PackedVector2Array([
		Vector2(-5, -4), Vector2(8, 0), Vector2(-5, 4)
	])
	turret_shape.color = Color(0.9, 0.7, 0.3)
	_turret_visual.add_child(turret_shape)
	
	# 炮塔位置在主体上方
	_turret_visual.position = Vector2(0, -12)
	add_child(_turret_visual)

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 主体节奏相位
	_body_phase += delta * 2.0
	
	# 炮塔逻辑
	if _turret_alive:
		_turret_phase += delta * 3.0
		
		# 炮塔独立追踪玩家
		if _target and is_instance_valid(_target):
			var target_angle := (global_position.direction_to(_target.global_position)).angle()
			_turret_angle = lerp_angle(_turret_angle, target_angle, turret_rotation_speed * delta)
		
		# 更新炮塔视觉
		if _turret_visual:
			_turret_visual.rotation = _turret_angle
			# 炮塔独立脉冲
			var turret_pulse := sin(_turret_phase) * 0.05
			_turret_visual.scale = Vector2(1.0 + turret_pulse, 1.0 + turret_pulse)
		
		# 炮塔射击
		_turret_fire_timer += delta
		if _turret_fire_timer >= turret_fire_interval:
			_turret_fire_timer = 0.0
			_turret_fire()
	
	# 主体视觉
	if _sprite:
		var body_pulse := sin(_body_phase) * 0.03
		_sprite.scale = Vector2(1.0 + body_pulse, 1.0 + body_pulse)

# ============================================================
# 炮塔射击
# ============================================================

func _turret_fire() -> void:
	if not _turret_alive or _target == null:
		return
	
	for i in range(turret_projectile_count):
		var t := float(i) / float(max(1, turret_projectile_count - 1))
		var angle := _turret_angle - turret_spread / 2.0 + turret_spread * t
		if turret_projectile_count == 1:
			angle = _turret_angle
		_spawn_turret_projectile(angle)
	
	# 射击反馈
	if _turret_visual:
		var tween := _turret_visual.create_tween()
		tween.tween_property(_turret_visual, "scale", Vector2(1.3, 0.7), 0.05)
		tween.tween_property(_turret_visual, "scale", Vector2(1.0, 1.0), 0.1)

func _spawn_turret_projectile(angle: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("enemy_projectiles")
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	col.shape = shape
	proj.add_child(col)
	
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-3, -2), Vector2(5, 0), Vector2(-3, 2)
	])
	visual.color = Color(0.9, 0.7, 0.3, 0.8)
	visual.rotation = angle
	proj.add_child(visual)
	
	proj.global_position = global_position + Vector2(0, -12)
	get_parent().add_child(proj)
	
	var vel := Vector2.from_angle(angle) * turret_projectile_speed
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position",
		proj.global_position + vel * 3.0, 3.0)
	tween.tween_callback(proj.queue_free)
	
	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(turret_projectile_damage)
			proj.queue_free()
	)

# ============================================================
# 伤害处理：炮塔可独立受伤
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	# 30% 概率伤害命中炮塔
	if _turret_alive and randf() < 0.3:
		_turret_current_hp -= amount
		if _turret_current_hp <= 0.0:
			_destroy_turret()
		# 炮塔受击闪烁
		if _turret_visual:
			var tween := _turret_visual.create_tween()
			tween.tween_property(_turret_visual, "modulate", Color.WHITE, 0.05)
			tween.tween_property(_turret_visual, "modulate", Color(0.9, 0.7, 0.3), 0.1)
	else:
		super.take_damage(amount, knockback_dir, is_perfect_beat)

func _destroy_turret() -> void:
	_turret_alive = false
	if _turret_visual:
		var tween := _turret_visual.create_tween()
		tween.tween_property(_turret_visual, "modulate:a", 0.0, 0.3)
		tween.tween_property(_turret_visual, "scale", Vector2(0.0, 0.0), 0.3)
		tween.tween_callback(_turret_visual.queue_free)
	
	# 主体加速（失去炮塔后更具攻击性）
	move_speed *= 1.5
	contact_damage *= 1.3

# ============================================================
# 移动逻辑：缓慢追踪
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	return (_target.global_position - global_position).normalized()

# ============================================================
# 节拍响应
# ============================================================

func _on_beat(_beat_index: int) -> void:
	# 主体节拍脉冲
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.12, 1.12), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	if _turret_visual and is_instance_valid(_turret_visual):
		_turret_visual.queue_free()
