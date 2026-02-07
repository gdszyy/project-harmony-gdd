## enemy_wall.gd
## Wall (音墙) — 砖墙限制器
## 巨大的阻挡者，迫使玩家走位，模拟动态范围压缩。
## 音乐隐喻：过度压缩的音墙（Wall of Sound），
## 将所有动态范围压平，令人窒息。
## 视觉：巨大的矩形/多边形，厚重感，低帧率，缓慢推进。
## 极高 HP，极慢速度，高击退抗性。
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Wall 专属配置
# ============================================================
## 推力（接触玩家时的推开力度）
@export var push_force: float = 400.0
## 推力范围
@export var push_radius: float = 60.0
## 护盾值（额外的伤害吸收层）
@export var shield_hp: float = 30.0
## 护盾恢复速度（每秒）
@export var shield_regen_rate: float = 5.0
## 护盾恢复延迟（受击后多久开始恢复）
@export var shield_regen_delay: float = 3.0
## 地震冲击波间隔（秒）
@export var quake_interval: float = 6.0
## 地震冲击波半径
@export var quake_radius: float = 150.0
## 地震冲击波伤害
@export var quake_damage: float = 12.0

# ============================================================
# 内部状态
# ============================================================
var _current_shield: float = 30.0
var _shield_regen_timer: float = 0.0
var _quake_timer: float = 0.0
var _is_shield_active: bool = true
var _quake_beat_counter: int = 0

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.WALL
	# Wall 使用极低的量化帧率（沉重、笨拙）
	quantized_fps = 4.0
	_quantize_interval = 1.0 / quantized_fps
	# 极高击退抗性（几乎不可推动）
	knockback_resistance = 0.95
	# 不受弱拍限制（持续缓慢推进）
	move_on_offbeat = false
	# 深灰色/铁灰色（金属质感）
	base_color = Color(0.4, 0.35, 0.5)
	# 低故障基础值（稳固的存在）
	base_glitch_intensity = 0.03
	max_glitch_intensity = 0.4
	# 大碰撞半径
	collision_radius = 28.0
	# 初始化护盾
	_current_shield = shield_hp

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	_update_shield(delta)
	_update_push_effect()
	_update_wall_visual(delta)

func _update_shield(delta: float) -> void:
	# 护盾恢复延迟计时
	if _shield_regen_timer > 0.0:
		_shield_regen_timer -= delta
		return

	# 护盾恢复
	if _current_shield < shield_hp:
		_current_shield = min(shield_hp, _current_shield + shield_regen_rate * delta)
		_is_shield_active = _current_shield > 0.0

func _update_push_effect() -> void:
	# 推开靠近的玩家
	if _target == null:
		return

	var dist := global_position.distance_to(_target.global_position)
	if dist < push_radius and dist > 0.0:
		var push_dir := (_target.global_position - global_position).normalized()
		var push_strength := (1.0 - dist / push_radius) * push_force
		if _target is CharacterBody2D:
			_target.velocity += push_dir * push_strength * get_physics_process_delta_time()

func _update_wall_visual(_delta: float) -> void:
	if _sprite == null:
		return

	# 护盾激活时的视觉效果
	if _is_shield_active and _current_shield > 0.0:
		var shield_ratio := _current_shield / shield_hp
		# 护盾层：外圈微微发光
		var shield_glow := Color(0.5, 0.5, 0.8, shield_ratio * 0.3)
		_sprite.modulate = base_color.lerp(shield_glow + base_color, shield_ratio * 0.3)
	else:
		# 护盾破碎：颜色变暗
		_sprite.modulate = base_color * 0.7

# ============================================================
# 伤害处理重写：护盾优先吸收
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	if _is_dead:
		return

	var final_damage := amount
	if is_perfect_beat:
		final_damage *= perfect_beat_damage_multiplier

	# 护盾吸收
	if _is_shield_active and _current_shield > 0.0:
		var shield_absorb := min(_current_shield, final_damage)
		_current_shield -= shield_absorb
		final_damage -= shield_absorb
		_shield_regen_timer = shield_regen_delay

		# 护盾受击视觉
		if _sprite:
			var tween := create_tween()
			tween.tween_property(_sprite, "modulate", Color(0.7, 0.7, 1.0), 0.05)
			tween.tween_property(_sprite, "modulate", base_color, 0.15)

		if _current_shield <= 0.0:
			_is_shield_active = false
			_on_shield_break()

	# 剩余伤害穿透到 HP
	if final_damage > 0.0:
		current_hp -= final_damage
		enemy_damaged.emit(current_hp, max_hp, final_damage)
		_damage_flash_timer = 0.15

	# 击退（极高抗性）
	if knockback_dir != Vector2.ZERO:
		var effective_knockback := 200.0 * (1.0 - knockback_resistance)
		if is_perfect_beat:
			effective_knockback *= perfect_beat_knockback_multiplier
		velocity = knockback_dir * effective_knockback
		move_and_slide()

	if current_hp <= 0.0:
		_die()

func _on_shield_break() -> void:
	# 护盾破碎视觉效果
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.3, 1.3), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.15)
		tween.tween_property(_sprite, "modulate", base_color * 0.7, 0.2)

# ============================================================
# 移动逻辑：极慢但坚定
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO

	# Wall 直线追踪，无任何偏移（不可阻挡的压迫感）
	return (_target.global_position - global_position).normalized()

# ============================================================
# 节拍响应：地震冲击波
# ============================================================

func _on_beat(_beat_index: int) -> void:
	_quake_beat_counter += 1

	# 每 N 拍触发地震冲击波
	var quake_beats := int(quake_interval / _get_beat_interval())
	if quake_beats < 1:
		quake_beats = 1

	if _quake_beat_counter >= quake_beats:
		_quake_beat_counter = 0
		_trigger_quake()

	# 强拍时的沉重脉冲
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.05, 0.95), 0.08)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.12)

func _trigger_quake() -> void:
	# 地震冲击波：对范围内玩家造成伤害
	if _target and is_instance_valid(_target):
		var dist := global_position.distance_to(_target.global_position)
		if dist < quake_radius:
			var falloff := 1.0 - (dist / quake_radius)
			if _target.has_method("take_damage"):
				_target.take_damage(quake_damage * falloff)

	# 冲击波视觉
	_spawn_quake_visual()

	# 冲击波时的自身视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.3, 0.7), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(0.9, 1.1), 0.08)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

func _spawn_quake_visual() -> void:
	# 扩散的环形冲击波
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	var segments := 24
	for i in range(segments):
		var angle := (TAU / segments) * i
		points.append(Vector2.from_angle(angle) * 10.0)
	ring.polygon = points
	ring.color = Color(0.5, 0.4, 0.6, 0.6)
	ring.global_position = global_position
	get_parent().add_child(ring)

	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(quake_radius / 10.0, quake_radius / 10.0), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.chain()
	tween.tween_callback(ring.queue_free)

# ============================================================
# 接触效果：强力推开
# ============================================================

func _on_contact_with_player() -> void:
	if _target and _target is CharacterBody2D:
		var push_dir := (_target.global_position - global_position).normalized()
		_target.velocity = push_dir * push_force

# ============================================================
# 死亡效果：崩塌
# ============================================================

func _on_death_effect() -> void:
	# Wall 死亡时触发最后一次强力地震
	_trigger_quake()
