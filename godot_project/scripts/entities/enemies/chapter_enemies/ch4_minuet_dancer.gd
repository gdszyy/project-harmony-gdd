## ch4_minuet_dancer.gd
## 第四章特色敌人：小步舞曲舞者 (Minuet Dancer)
## 永远成对出现，移动轨迹保持完美的镜像对称。
## 音乐隐喻：古典主义的对称之美，莫扎特宫廷舞会的优雅。
## 机制：
## - 成对镜像对称移动
## - 攻击严格遵循3/4拍
## - 每小节第一拍进行旋转（短暂无敌帧）
## - 击杀一个后另一个狂暴
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Minuet Dancer 专属配置
# ============================================================
## 舞伴引用
var dance_partner: Node2D = null
## 是否为"领舞"（另一个为"跟舞"，镜像移动）
@export var is_lead: bool = true
## 镜像轴（垂直于此轴镜像）
var mirror_axis: Vector2 = Vector2.UP
## 镜像中心点
var mirror_center: Vector2 = Vector2.ZERO
## 旋转无敌帧持续时间
@export var spin_invincibility_duration: float = 0.4
## 3/4拍攻击伤害
@export var waltz_attack_damage: float = 10.0
## 弹幕速度
@export var waltz_projectile_speed: float = 180.0
## 狂暴速度倍率
@export var rage_speed_multiplier: float = 2.0
## 狂暴伤害倍率
@export var rage_damage_multiplier: float = 1.8

# ============================================================
# 内部状态
# ============================================================
var _waltz_beat_counter: int = 0  # 3/4拍计数 (0,1,2)
var _is_spinning: bool = false
var _spin_timer: float = 0.0
var _is_invincible: bool = false
var _partner_dead: bool = false
var _is_enraged: bool = false
## 舞步相位
var _dance_phase: float = 0.0
## 旋转角度
var _spin_angle: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.STATIC
	quantized_fps = 12.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.2
	move_on_offbeat = false
	
	# 洛可可粉白色调
	base_color = Color(0.95, 0.8, 0.85) if is_lead else Color(0.8, 0.85, 0.95)
	base_glitch_intensity = 0.03
	max_glitch_intensity = 0.4

# ============================================================
# 舞伴设置
# ============================================================

func setup_partner(partner: Node2D, lead: bool) -> void:
	dance_partner = partner
	is_lead = lead
	base_color = Color(0.95, 0.8, 0.85) if is_lead else Color(0.8, 0.85, 0.95)

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	_dance_phase += delta * 2.5
	
	# 旋转无敌帧
	if _is_spinning:
		_spin_timer -= delta
		_spin_angle += delta * 15.0
		if _sprite:
			_sprite.rotation = _spin_angle
		if _spin_timer <= 0.0:
			_is_spinning = false
			_is_invincible = false
			if _sprite:
				_sprite.rotation = 0.0
	
	# 舞步视觉
	if _sprite and not _is_spinning:
		var sway := sin(_dance_phase) * 5.0
		_sprite.position.x = sway
		
		# 狂暴视觉
		if _is_enraged:
			var rage_flash := sin(Time.get_ticks_msec() * 0.01) * 0.3
			_sprite.modulate = base_color.lerp(Color(1.0, 0.2, 0.2), 0.3 + rage_flash)
		else:
			_sprite.modulate = base_color
	
	# 检查舞伴状态
	if dance_partner and not is_instance_valid(dance_partner):
		if not _partner_dead:
			_on_partner_death()

# ============================================================
# 移动逻辑：镜像对称
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	if is_lead or _partner_dead:
		# 领舞/失伴：直接追踪玩家
		var dir := (_target.global_position - global_position).normalized()
		# 加入优雅的弧线
		var curve := sin(_dance_phase * 0.7) * 0.3
		return dir.rotated(curve)
	else:
		# 跟舞：镜像领舞的移动
		if dance_partner and is_instance_valid(dance_partner):
			# 计算镜像位置
			var partner_to_target := Vector2.ZERO
			if _target:
				partner_to_target = _target.global_position - dance_partner.global_position
			
			# 水平镜像
			var mirrored_dir := Vector2(-partner_to_target.x, partner_to_target.y).normalized()
			var curve := sin(_dance_phase * 0.7) * 0.3
			return mirrored_dir.rotated(-curve)
		
		return (_target.global_position - global_position).normalized()

# ============================================================
# 伤害处理：旋转时无敌
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	if _is_invincible:
		# 旋转无敌帧 — 闪烁提示
		if _sprite:
			var tween := create_tween()
			tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.5), 0.05)
			tween.tween_property(_sprite, "modulate", base_color, 0.1)
		return
	
	super.take_damage(amount, knockback_dir, is_perfect_beat)

# ============================================================
# 节拍响应：3/4拍攻击
# ============================================================

func _on_beat(_beat_index: int) -> void:
	_waltz_beat_counter = (_waltz_beat_counter + 1) % 3
	
	match _waltz_beat_counter:
		0:
			# 第一拍（强拍）：旋转 + 无敌帧
			_start_spin()
		1:
			# 第二拍：发射弹幕
			_waltz_attack()
		2:
			# 第三拍：轻拍脉冲
			if _sprite:
				var tween := create_tween()
				tween.tween_property(_sprite, "scale", Vector2(1.08, 1.08), 0.05)
				tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

func _start_spin() -> void:
	_is_spinning = true
	_is_invincible = true
	_spin_timer = spin_invincibility_duration
	_spin_angle = 0.0
	
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.2)

func _waltz_attack() -> void:
	if _target == null:
		return
	
	var angle := (global_position.direction_to(_target.global_position)).angle()
	var damage := waltz_attack_damage
	if _is_enraged:
		damage *= rage_damage_multiplier
	
	# 发射优雅的弧线弹幕
	for i in range(3):
		var offset_angle := angle + (i - 1) * 0.25
		_spawn_waltz_projectile(offset_angle, damage)

func _spawn_waltz_projectile(angle: float, damage: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("enemy_projectiles")
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	col.shape = shape
	proj.add_child(col)
	
	# 优雅的圆形弹体
	var visual := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(8):
		var a := (TAU / 8) * i
		points.append(Vector2.from_angle(a) * 4.0)
	visual.polygon = points
	visual.color = base_color.lerp(Color.WHITE, 0.4)
	proj.add_child(visual)
	
	proj.global_position = global_position
	get_parent().add_child(proj)
	
	var vel := Vector2.from_angle(angle) * waltz_projectile_speed
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position",
		proj.global_position + vel * 2.5, 2.5)
	tween.tween_callback(proj.queue_free)
	
	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			proj.queue_free()
	)

# ============================================================
# 舞伴死亡：狂暴
# ============================================================

func _on_partner_death() -> void:
	_partner_dead = true
	_is_enraged = true
	
	# 狂暴效果
	move_speed *= rage_speed_multiplier
	contact_damage *= rage_damage_multiplier
	
	base_color = Color(1.0, 0.3, 0.3)
	
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)
		tween.tween_property(_sprite, "scale", Vector2(1.5, 1.5), 0.15)
		tween.tween_property(_sprite, "modulate", base_color, 0.3)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.3)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# 通知舞伴
	if dance_partner and is_instance_valid(dance_partner):
		if dance_partner.has_method("_on_partner_death"):
			dance_partner._on_partner_death()
