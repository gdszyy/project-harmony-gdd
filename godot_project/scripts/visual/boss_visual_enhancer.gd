## boss_visual_enhancer.gd
## Boss 视觉增强器
##
## 职责：
## 1. 管理 Boss 的章节特色视觉表现
## 2. 实现 Boss 阶段切换的视觉过渡
## 3. 处理 Boss 特有的视觉效果（光环、粒子、屏幕效果）
## 4. 响应节拍脉冲（更强烈的视觉反馈）
class_name BossVisualEnhancer
extends VisualEnhancerBase

# ============================================================
# 配置
# ============================================================

## Boss 光环配置
@export var aura_enabled: bool = true
@export var aura_color: Color = Color(1.0, 0.0, 0.5, 0.6)
@export var aura_radius: float = 80.0
@export var aura_pulse_speed: float = 2.0

## 阶段切换配置
@export var phase_transition_duration: float = 1.5
@export var phase_flash_color: Color = Color.WHITE

## 节拍脉冲增强
@export_range(0.1, 0.5) var boss_beat_scale: float = 0.2

# ============================================================
# 状态
# ============================================================
var _boss_ref: Node = null
var _current_boss_phase: int = 0
var _aura_timer: float = 0.0
var _aura_particles: GPUParticles2D = null
var _hp_ratio: float = 1.0
var _is_enraged: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	super._ready()
	beat_pulse_scale = boss_beat_scale  # Boss 的节拍脉冲更强
	_boss_ref = get_parent()
	
	if aura_enabled:
		_create_boss_aura()
	
	_connect_boss_signals()

func _update_visual(delta: float) -> void:
	if _boss_ref == null:
		return

	# 获取 Boss HP
	if _boss_ref.has_method("get_hp_ratio"):
		_hp_ratio = _boss_ref.get_hp_ratio()
	elif "hp" in _boss_ref and "max_hp" in _boss_ref:
		_hp_ratio = float(_boss_ref.hp) / float(_boss_ref.max_hp) if _boss_ref.max_hp > 0 else 1.0

	# 光环脉冲
	_aura_timer += delta * aura_pulse_speed
	if _aura_particles and _aura_particles.process_material:
		var mat := _aura_particles.process_material as ParticleProcessMaterial
		if mat:
			var pulse := sin(_aura_timer) * 0.3 + 1.0
			mat.emission_ring_radius = aura_radius * pulse

	# 低 HP 时视觉增强
	var rage_factor := clampf((1.0 - _hp_ratio) * 2.0, 0.0, 1.0)
	set_shader_param("rage_factor", rage_factor)
	set_shader_param("hp_ratio", _hp_ratio)
	
	# 狂暴状态视觉
	if _hp_ratio < 0.3 and not _is_enraged:
		_is_enraged = true
		_enter_enrage_visual()

# ============================================================
# 初始化
# ============================================================

func _create_boss_aura() -> void:
	_aura_particles = GPUParticles2D.new()
	_aura_particles.name = "BossAura"
	_aura_particles.amount = 32
	_aura_particles.lifetime = 2.0
	_aura_particles.preprocess = 1.0

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = aura_radius
	mat.emission_ring_inner_radius = aura_radius - 10.0
	mat.emission_ring_height = 0.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, -20, 0)
	mat.scale_min = 1.0
	mat.scale_max = 3.0

	var gradient := Gradient.new()
	gradient.set_color(0, Color(aura_color.r, aura_color.g, aura_color.b, 0.0))
	gradient.add_point(0.2, Color(aura_color.r, aura_color.g, aura_color.b, 0.6))
	gradient.add_point(0.7, Color(aura_color.r, aura_color.g, aura_color.b, 0.3))
	gradient.set_color(1, Color(aura_color.r, aura_color.g, aura_color.b, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	_aura_particles.process_material = mat
	add_child(_aura_particles)

func _connect_boss_signals() -> void:
	if _boss_ref:
		# Issue #52: 修复信号名称，使用 boss_base.gd 中定义的 boss_phase_changed 信号
		if _boss_ref.has_signal("boss_phase_changed"):
			_boss_ref.boss_phase_changed.connect(_on_boss_phase_changed_signal)
		if _boss_ref.has_signal("boss_attack_started"):
			_boss_ref.boss_attack_started.connect(_on_special_attack)
		if _boss_ref.has_signal("boss_enraged"):
			_boss_ref.boss_enraged.connect(_on_boss_enraged)

# ============================================================
# Boss 阶段切换
# ============================================================

## 从 boss_phase_changed(phase_index, phase_name) 信号调用 (Issue #52)
func _on_boss_phase_changed_signal(phase_index: int, _phase_name: String) -> void:
	_on_boss_phase_changed(phase_index)

## 从 boss_enraged(enrage_level) 信号调用 (Issue #52)
func _on_boss_enraged(_enrage_level: int) -> void:
	_enter_enrage_visual()

func _on_boss_phase_changed(new_phase: int) -> void:
	var old_phase := _current_boss_phase
	_current_boss_phase = new_phase
	
	# 阶段切换闪光
	if _visual_node:
		var tween := create_tween()
		tween.tween_property(_visual_node, "modulate", phase_flash_color, 0.1)
		tween.tween_property(_visual_node, "modulate", Color.WHITE, phase_transition_duration)
	
	# 通知全局视觉环境
	var gve = get_node_or_null("/root/GlobalVisualEnvironment3D")
	if gve and gve.has_method("set_glow_override"):
		gve.set_glow_override(2.0, 0.2)
		get_tree().create_timer(0.5).timeout.connect(func():
			if gve.has_method("reset_glow"):
				gve.reset_glow(1.0)
		)
	
	# 更新光环颜色
	_update_aura_for_phase(new_phase)

func _update_aura_for_phase(phase: int) -> void:
	# 每个阶段光环颜色变化
	var phase_colors := [
		Color(1.0, 0.0, 0.5, 0.6),   # 阶段 1：洋红
		Color(1.0, 0.5, 0.0, 0.7),   # 阶段 2：橙色
		Color(1.0, 0.0, 0.0, 0.8),   # 阶段 3：红色
	]
	
	if phase < phase_colors.size():
		aura_color = phase_colors[phase]
		if _aura_particles:
			_create_boss_aura()  # 重建光环以更新颜色

func _on_special_attack(_attack_name: String) -> void:
	# Boss 特殊攻击的视觉反馈
	if _visual_node:
		var tween := create_tween()
		tween.tween_property(_visual_node, "scale", _base_scale * 1.3, 0.2)
		tween.tween_property(_visual_node, "scale", _base_scale, 0.3)

func _enter_enrage_visual() -> void:
	# 狂暴状态：光环变红，脉冲加速
	aura_color = Color(1.0, 0.1, 0.0, 0.8)
	aura_pulse_speed = 4.0
	beat_pulse_scale = boss_beat_scale * 1.5
	
	# 通知全局进入 Boss 狂暴模式
	var gve = get_node_or_null("/root/GlobalVisualEnvironment3D")
	if gve and gve.has_method("enter_boss_mode"):
		gve.enter_boss_mode()

# ============================================================
# 节拍视觉响应
# ============================================================

func _on_beat_visual() -> void:
	set_shader_param("beat_energy", 1.0)
	
	# Boss 的节拍脉冲更强烈
	if _aura_particles and _aura_particles.process_material:
		var mat := _aura_particles.process_material as ParticleProcessMaterial
		if mat:
			mat.emission_ring_radius = aura_radius * 1.3

# ============================================================
# 公共接口
# ============================================================

## 设置 Boss 光环颜色
func set_aura_color(color: Color) -> void:
	aura_color = color
	# 重建光环
	if _aura_particles:
		_aura_particles.queue_free()
		_create_boss_aura()

## 获取当前 Boss 阶段
func get_boss_phase() -> int:
	return _current_boss_phase
