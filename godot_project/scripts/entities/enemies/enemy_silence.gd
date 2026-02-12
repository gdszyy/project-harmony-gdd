## enemy_silence.gd
## Silence (寂静) — 休止符 / 黑洞
## 试图吞噬声音。靠近玩家时会增加玩家的"单调值"或使法术静音。
## 音乐隐喻：令人窒息的沉默，音乐的空白与虚无。
## 视觉：深色、半透明的旋涡状几何体，周围有"吸收"粒子效果。
## 低帧率量化（笨重感），缓慢但不可阻挡。
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Silence 专属配置
# ============================================================
## 静音光环半径
@export var silence_aura_radius: float = 120.0
## 每秒增加的疲劳度（当玩家在光环内）
@export var fatigue_per_second: float = 0.08
## 光环内法术伤害削减比例
@export var spell_damage_reduction: float = 0.4
## 光环脉冲频率（视觉用）
@export var aura_pulse_speed: float = 2.0

# ============================================================
# 相位变体
# ============================================================
## 0 = Normal, 1 = Overtone (高通), 2 = Sub-Bass (低通)
@export var phase_shift_type: int = 0

# ============================================================
# 节点引用
# ============================================================
@onready var _distortion_aura: Node2D = $DistortionAura
@onready var _overtone_visual: Polygon2D = $OvertoneVisual
@onready var _sub_bass_particles: CPUParticles2D = $SubBassParticles

# ============================================================
# 内部状态
# ============================================================
var _player_in_aura: bool = false
var _aura_timer: float = 0.0
var _rotation_speed: float = 0.3  ## 缓慢旋转

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.SILENCE
	# Silence 使用极低的量化帧率（沉重、笨拙）
	quantized_fps = 6.0
	_quantize_interval = 1.0 / quantized_fps
	# 高击退抗性（难以推动）
	knockback_resistance = 0.7
	# 不受弱拍限制（沉默无处不在）
	move_on_offbeat = false
	
	# 核心视觉为纯黑色
	base_color = Color.BLACK
	
	# 低故障基础值（沉默是"平静"的恐怖）
	base_glitch_intensity = 0.02
	max_glitch_intensity = 0.5

	# 根据相位初始化视觉
	apply_phase_shift(phase_shift_type)

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	_check_silence_aura(delta)
	_update_visuals(delta)

func _check_silence_aura(delta: float) -> void:
	if _target == null:
		_player_in_aura = false
		return

	var dist := global_position.distance_to(_target.global_position)
	_player_in_aura = dist < silence_aura_radius

	if _player_in_aura:
		_aura_timer += delta
		# 持续增加玩家疲劳度
		if FatigueManager and FatigueManager.has_method("add_external_fatigue"):
			FatigueManager.add_external_fatigue(fatigue_per_second * delta)
	else:
		_aura_timer = 0.0

func _update_visuals(delta: float) -> void:
	if _sprite == null:
		return

	# 核心多边形缓慢旋转
	_sprite.rotation += _rotation_speed * delta

	# 根据相位更新视觉效果
	match phase_shift_type:
		1: # Overtone
			_overtone_visual.rotation += delta * 2.0
			_overtone_visual.material.set_shader_parameter("time_offset", Time.get_ticks_msec() * 0.001)
		2: # Sub-Bass
			pass # 粒子效果是自动的

# ============================================================
# 移动逻辑：缓慢但坚定地追踪
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO

	var dir := (_target.global_position - global_position).normalized()
	# Silence 移动极为平稳，无随机偏移
	return dir

# ============================================================
# 节拍响应：反节拍 — 在强拍时"吸收"能量
# ============================================================

func _on_beat(_beat_index: int) -> void:
	# 强拍时短暂收缩（吸收声音的视觉暗示）
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(0.85, 0.85), 0.08)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.15)

	# 如果玩家在光环内，强拍时额外增加疲劳
	if _player_in_aura:
		if FatigueManager and FatigueManager.has_method("add_external_fatigue"):
			FatigueManager.add_external_fatigue(fatigue_per_second * 0.5)

# ============================================================
# 接触效果：接触时大幅增加疲劳
# ============================================================

func _on_contact_with_player() -> void:
	if FatigueManager and FatigueManager.has_method("add_external_fatigue"):
			FatigueManager.add_external_fatigue(0.15)

# ============================================================
# 死亡效果：沉默消散 — 缓慢内爆
# ============================================================

func _on_death_effect() -> void:
	# Silence 死亡时释放被吞噬的声音能量
	# 短暂降低附近区域的疲劳度（奖励玩家击杀它）
	if FatigueManager and FatigueManager.has_method("reduce_fatigue"):
			FatigueManager.reduce_fatigue(0.1)

# ============================================================
# 相位变体实现
# ============================================================

## 应用指定的相位变体效果
func apply_phase_shift(type: int) -> void:
	phase_shift_type = type

	# 重置所有相位视觉
	_overtone_visual.visible = false
	_sub_bass_particles.emitting = false
	var base_material = _distortion_aura.material as ShaderMaterial
	if base_material:
		base_material.set_shader_parameter("distortion_amount", 0.05)

	match phase_shift_type:
		0: # Normal
			pass # 默认状态
		1: # Overtone (高通)
			_overtone_visual.visible = true
		2: # Sub-Bass (低通)
			if base_material:
				base_material.set_shader_parameter("distortion_amount", 0.2) # 大幅增加扭曲
			_sub_bass_particles.emitting = true

# ============================================================
# 接口：检查玩家是否在静音光环内（供 SpellcraftSystem 查询）
# ============================================================

func is_player_in_aura() -> bool:
	return _player_in_aura

func get_spell_damage_reduction() -> float:
	if _player_in_aura:
		return spell_damage_reduction
	return 0.0
