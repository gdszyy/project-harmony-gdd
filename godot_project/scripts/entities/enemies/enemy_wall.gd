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
# 相位变体 (Phase Shift)
# ============================================================
enum Phase { NORMAL, HIGH_PASS, LOW_PASS }
@export var phase_shift_type: Phase = Phase.NORMAL

# ============================================================
# 节点引用
# ============================================================
@onready var _shield_visual: Polygon2D = $ShieldVisual
@onready var _cracks_visual: Polygon2D = $CracksVisual
@onready var _high_pass_visual: Line2D = $HighPassVisual

# ============================================================
# 内部状态
# ============================================================
var _current_shield: float = 30.0
var _shield_regen_timer: float = 0.0
var _quake_timer: float = 0.0
var _is_shield_active: bool = true
var _quake_beat_counter: int = 0

## 频谱数据
var _spectrum_image: Image
var _spectrum_texture: ImageTexture
const SPECTRUM_SIZE = 16

## 原始多边形数据，用于恢复形状
var _original_polygon: PackedVector2Array

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.WALL
	quantized_fps = 4.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.95
	move_on_offbeat = false
	base_color = Color(0.4, 0.35, 0.5)
	base_glitch_intensity = 0.03
	max_glitch_intensity = 0.4
	collision_radius = 28.0
	
	_current_shield = shield_hp
	
	# OPT06: 护盾激活时应用 "shielded" 空间音频状态
	if _spatial_audio_ctrl and _is_shield_active:
		_spatial_audio_ctrl.apply_state_fx("shielded")
	
	# ## 初始化频谱纹理
	_spectrum_image = Image.create(SPECTRUM_SIZE, 1, false, Image.FORMAT_RF)
	_spectrum_texture = ImageTexture.create_from_image(_spectrum_image)
	
	# ## 设置主视觉的 Shader
	if _sprite and _sprite.material:
		_sprite.material.set_shader_parameter("spectrum_texture", _spectrum_texture)

	# ## 存储原始形状
	if _sprite is Polygon2D:
		_original_polygon = _sprite.polygon
	
	# ## 初始化视觉状态
	apply_phase_shift(phase_shift_type)

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	_update_shield(delta)
	_update_push_effect()
	_update_spectrum_data()
	_update_wall_visual(delta)

func _update_shield(delta: float) -> void:
	if _shield_regen_timer > 0.0:
		_shield_regen_timer -= delta
		return

	if _current_shield < shield_hp:
		var was_inactive := not _is_shield_active
		_current_shield = min(shield_hp, _current_shield + shield_regen_rate * delta)
		_is_shield_active = _current_shield > 0.0
		# OPT06: 护盾从无到有时恢复 shielded 状态
		if _is_shield_active and was_inactive and _spatial_audio_ctrl:
			_spatial_audio_ctrl.apply_state_fx("shielded")
		# 护盾恢复动画
		if _shield_visual and _shield_visual.material:
			_shield_visual.material.set_shader_parameter("shield_strength", _current_shield / shield_hp)

func _update_push_effect() -> void:
	if _target == null: return

	var dist := global_position.distance_to(_target.global_position)
	if dist < push_radius and dist > 0.0:
		var push_dir := (_target.global_position - global_position).normalized()
		var push_strength := (1.0 - dist / push_radius) * push_force
		if _target is CharacterBody2D:
			_target.velocity += push_dir * push_strength * get_physics_process_delta_time()

func _update_wall_visual(_delta: float) -> void:
	if _sprite == null: return

	# ## 根据相位更新视觉
	match phase_shift_type:
		Phase.NORMAL:
			var shield_ratio := _current_shield / shield_hp
			if _shield_visual and _shield_visual.material:
				_shield_visual.material.set_shader_parameter("shield_strength", shield_ratio)
		Phase.HIGH_PASS:
			# 线框闪烁效果
			_high_pass_visual.modulate.a = 0.5 + sin(TIME * 20.0) * 0.5
		Phase.LOW_PASS:
			# 裂缝强度可以随 HP 变化
			if _cracks_visual and _cracks_visual.material:
				_cracks_visual.material.set_shader_parameter("crack_intensity", 1.0 - get_hp_ratio())

# ============================================================
# 伤害处理重写：护盾优先吸收
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	if _is_dead: return

	var final_damage := amount
	if is_perfect_beat:
		final_damage *= perfect_beat_damage_multiplier

	var had_shield := _is_shield_active and _current_shield > 0.0
	if _is_shield_active and _current_shield > 0.0:
		var shield_absorb = min(_current_shield, final_damage)
		_current_shield -= shield_absorb
		final_damage -= shield_absorb
		_shield_regen_timer = shield_regen_delay

		# 护盾受击视觉 (闪烁)
		if _shield_visual:
			var tween := create_tween()
			tween.tween_property(_shield_visual, "modulate", Color.WHITE, 0.05)
			tween.tween_property(_shield_visual, "modulate", Color(1,1,1,1), 0.15)

		if _current_shield <= 0.0:
			_is_shield_active = false
			_on_shield_break()
			# OPT06: 护盾破碎时清除护盾音频状态
			if _spatial_audio_ctrl and had_shield:
				_spatial_audio_ctrl.clear_state_fx()

	if final_damage > 0.0:
		current_hp -= final_damage
		enemy_damaged.emit(current_hp, max_hp, final_damage)
		_damage_flash_timer = 0.15
		# OPT03: Wall 受击时触发音高层
		if _audio_controller:
			_audio_controller.play_behavior_pitch("hit")
		# OPT06: 检查是否进入低血量状态
		if _spatial_audio_ctrl and current_hp > 0.0:
			var hp_ratio := current_hp / max_hp
			if hp_ratio < 0.3 and _spatial_audio_ctrl.get_active_state() != "low_health":
				_spatial_audio_ctrl.apply_state_fx("low_health")

	if knockback_dir != Vector2.ZERO:
		var effective_knockback := 200.0 * (1.0 - knockback_resistance)
		if is_perfect_beat:
			effective_knockback *= perfect_beat_knockback_multiplier
		velocity = knockback_dir * effective_knockback
		move_and_slide()

	if current_hp <= 0.0:
		_die()

func _on_shield_break() -> void:
	# 护盾破碎视觉效果 (通过 Shader uniform)
	if _shield_visual and _shield_visual.material:
		var tween := create_tween()
		tween.tween_property(_shield_visual.material, "shader_parameter/shield_activation", 0.0, 0.3).set_ease(Tween.EASE_IN)

# ============================================================
# 相位切换逻辑
# ============================================================

func apply_phase_shift(type: int) -> void:
	phase_shift_type = type
	
	# ## 先重置所有状态
	_sprite.visible = false
	_shield_visual.visible = false
	_cracks_visual.visible = false
	_high_pass_visual.visible = false
	if _sprite is Polygon2D: _sprite.polygon = _original_polygon

	match phase_shift_type:
		Phase.NORMAL:
			_sprite.visible = true
			_shield_visual.visible = true
			if _shield_visual.material:
				_shield_visual.material.set_shader_parameter("shield_activation", 1.0)
		
		Phase.HIGH_PASS: # Overtone - 线框模式
			_high_pass_visual.visible = true
			_high_pass_visual.points = _original_polygon
			_high_pass_visual.add_point(_original_polygon[0]) # 闭合 Line2D
			# TODO: 实现残影效果 (可能需要 VFXManager)

		Phase.LOW_PASS: # Sub-Bass - 岩石模式
			_sprite.visible = true
			_cracks_visual.visible = true
			# ## 程序化变形多边形
			var new_poly = PackedVector2Array()
			var noise = FastNoiseLite.new()
			noise.seed = randi()
			noise.frequency = 0.2
			for p in _original_polygon:
				var offset = Vector2(noise.get_noise_2d(p.x, p.y), noise.get_noise_2d(p.y, p.x + 100.0)) * 15.0
				new_poly.append(p + offset)
			if _sprite is Polygon2D: _sprite.polygon = new_poly
			_cracks_visual.polygon = new_poly # 裂缝也使用变形后的形状

# ============================================================
# 频谱数据处理
# ============================================================

func _update_spectrum_data() -> void:
	# ## 从总线获取频谱数据
	# ## 注意：这需要在项目设置中启用音频频谱分析
	var spectrum: PackedFloat32Array = AudioServer.get_spectrum_for_bus(0, 2048, AudioServer.FFT_SIZE_2048)
	if spectrum.is_empty(): return

	_spectrum_image.lock()
	for i in range(SPECTRUM_SIZE):
		# ## 对数映射，获取部分频谱数据
		var start_index = int(pow(2, float(i) / 2.0)) - 1
		var end_index = int(pow(2, float(i+1) / 2.0)) - 1
		var avg_magnitude = 0.0
		if start_index < end_index:
			for j in range(start_index, min(end_index, spectrum.size())):
				avg_magnitude += spectrum[j]
			avg_magnitude /= (end_index - start_index)
		
		# ## 转换为分贝并归一化
		var db = linear_to_db(avg_magnitude)
		var normalized_val = clamp((db + 60.0) / 60.0, 0.0, 1.0)
		_spectrum_image.set_pixel(i, 0, Color(normalized_val, 0, 0))

	_spectrum_image.unlock()
	_spectrum_texture.update(_spectrum_image)

# ============================================================
# 移动逻辑：极慢但坚定
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null: return Vector2.ZERO
	return (_target.global_position - global_position).normalized()

# ============================================================
# 节拍响应：地震冲击波
# ============================================================

func _on_beat(_beat_index: int) -> void:
	_quake_beat_counter += 1

	var quake_beats := int(quake_interval / _get_beat_interval())
	if quake_beats < 1: quake_beats = 1

	if _quake_beat_counter >= quake_beats:
		_quake_beat_counter = 0
		_trigger_quake()

	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.05, 0.95), 0.08)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.12)

func _trigger_quake() -> void:
	# OPT03: 地震攻击时触发音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")
	if _target and is_instance_valid(_target):
		var dist := global_position.distance_to(_target.global_position)
		if dist < quake_radius:
			var falloff := 1.0 - (dist / quake_radius)
			if _target.has_method("take_damage"):
				_target.take_damage(quake_damage * falloff)

	_spawn_quake_visual()

	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.3, 0.7), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(0.9, 1.1), 0.08)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

func _spawn_quake_visual() -> void:
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
	_trigger_quake()
