## player_visual_enhancer.gd
## 玩家视觉增强器
##
## 职责：
## 1. 管理玩家核心的视觉表现（正十二面体 + 金环）
## 2. 实现音色系统的视觉反馈
## 3. 响应施法动作的视觉效果
## 4. 管理频谱相位切换的视觉过渡
class_name PlayerVisualEnhancer
extends VisualEnhancerBase

# ============================================================
# 配置
# ============================================================

## 施法反馈配置
@export var cast_bounce_scale: float = 0.15
@export var cast_bounce_duration: float = 0.15
@export var manual_cast_scale: float = 0.25
@export var manual_cast_duration: float = 0.2

## 音色视觉配置
@export var timbre_transition_duration: float = 0.5

## 频谱相位视觉配置
@export var phase_transition_duration: float = 0.3

## 能量光环配置
@export var aura_base_radius: float = 30.0
@export var aura_pulse_amount: float = 5.0

# ============================================================
# 状态
# ============================================================
var _player_ref: Node = null
var _current_timbre: int = 0  # 0=无, 1=弦乐, 2=管乐, 3=打击, 4=键盘
var _current_phase: int = 0   # 0=全频, 1=高通, 2=低通
var _cast_bounce_timer: float = 0.0
var _aura_particles: GPUParticles2D = null
var _phase_overlay: ColorRect = null

# 音色色彩映射
const TIMBRE_COLORS: Dictionary = {
	0: Color(0.0, 1.0, 0.83),   # 默认：谐振青
	1: Color(0.8, 0.6, 0.2),    # 弦乐（拉弦）：温暖金色
	2: Color(0.4, 0.7, 1.0),    # 管乐（吹奏）：天蓝色
	3: Color(1.0, 0.4, 0.2),    # 打击：火焰橙
	4: Color(0.6, 0.4, 1.0),    # 键盘：薰衣草紫
}

# 频谱相位色彩
const PHASE_COLORS: Dictionary = {
	0: Color(1.0, 1.0, 1.0, 0.0),     # 全频：无覆盖
	1: Color(0.3, 0.6, 1.0, 0.15),    # 高通：冷蓝色
	2: Color(1.0, 0.3, 0.2, 0.15),    # 低通：暖红色
}

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	super._ready()
	_player_ref = get_parent()
	_create_aura_particles()
	_connect_player_signals()

func _update_visual(delta: float) -> void:
	if _player_ref == null:
		return

	# 施法弹跳衰减
	if _cast_bounce_timer > 0.0:
		_cast_bounce_timer = maxf(_cast_bounce_timer - delta / cast_bounce_duration, 0.0)
		var bounce := sin(_cast_bounce_timer * PI) * cast_bounce_scale
		if _visual_node:
			_visual_node.scale = _base_scale * (1.0 + bounce)

	# 更新能量光环
	_update_aura()

	# 更新 Shader 参数
	set_shader_param("timbre_family", _current_timbre)
	set_shader_param("phase_mode", _current_phase)

# ============================================================
# 初始化
# ============================================================

func _create_aura_particles() -> void:
	_aura_particles = GPUParticles2D.new()
	_aura_particles.name = "AuraParticles"
	_aura_particles.amount = 16
	_aura_particles.lifetime = 1.5
	_aura_particles.preprocess = 0.5

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = aura_base_radius
	mat.emission_ring_inner_radius = aura_base_radius - 5.0
	mat.emission_ring_height = 0.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3(0, -10, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.5

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.0, 1.0, 0.83, 0.0))
	gradient.add_point(0.2, Color(0.0, 1.0, 0.83, 0.4))
	gradient.add_point(0.8, Color(0.0, 1.0, 0.83, 0.2))
	gradient.set_color(1, Color(0.0, 1.0, 0.83, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	_aura_particles.process_material = mat
	add_child(_aura_particles)

func _connect_player_signals() -> void:
	# 连接施法系统信号
	var ss = get_node_or_null("/root/SpellcraftSystem")
	if ss:
		if ss.has_signal("spell_cast"):
			ss.spell_cast.connect(_on_spell_cast)
		if ss.has_signal("chord_cast"):
			ss.chord_cast.connect(_on_chord_cast)
		if ss.has_signal("manual_cast"):
			ss.manual_cast.connect(_on_manual_cast)

	# 连接音色系统信号
	var ts = get_node_or_null("/root/TimbreSystem")
	if ts == null and _player_ref:
		ts = _player_ref.get_node_or_null("TimbreSystem")
	if ts and ts.has_signal("timbre_changed"):
		ts.timbre_changed.connect(_on_timbre_changed)

	# 连接频谱相位信号
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_signal("phase_changed"):
			gm.phase_changed.connect(_on_phase_changed)

# ============================================================
# 信号回调
# ============================================================

func _on_spell_cast(_spell_data: Dictionary) -> void:
	# 自动施法的轻微弹跳
	_cast_bounce_timer = 1.0

func _on_chord_cast(_chord_data: Dictionary) -> void:
	# 和弦施法的更强弹跳 + 粒子爆发
	_cast_bounce_timer = 1.0
	_trigger_cast_burst()

func _on_manual_cast(_slot: int) -> void:
	# 手动施法的最强弹跳
	_cast_bounce_timer = 1.0
	_trigger_cast_burst()

func _on_timbre_changed(new_timbre: int) -> void:
	var old_timbre := _current_timbre
	_current_timbre = new_timbre
	_transition_timbre_visual(old_timbre, new_timbre)

func _on_phase_changed(new_phase: int) -> void:
	var old_phase := _current_phase
	_current_phase = new_phase
	_transition_phase_visual(old_phase, new_phase)

# ============================================================
# 视觉效果
# ============================================================

func _update_aura() -> void:
	if _aura_particles == null or _aura_particles.process_material == null:
		return
	
	var mat := _aura_particles.process_material as ParticleProcessMaterial
	if mat == null:
		return
	
	# 根据音色调整光环颜色
	var target_color: Color = TIMBRE_COLORS.get(_current_timbre, Color(0.0, 1.0, 0.83))
	
	# 更新粒子颜色
	var gradient := Gradient.new()
	gradient.set_color(0, Color(target_color.r, target_color.g, target_color.b, 0.0))
	gradient.add_point(0.2, Color(target_color.r, target_color.g, target_color.b, 0.4))
	gradient.add_point(0.8, Color(target_color.r, target_color.g, target_color.b, 0.2))
	gradient.set_color(1, Color(target_color.r, target_color.g, target_color.b, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

func _trigger_cast_burst() -> void:
	# 施法时的粒子爆发
	var burst := GPUParticles2D.new()
	burst.one_shot = true
	burst.amount = 24
	burst.lifetime = 0.5
	burst.explosiveness = 1.0

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 5.0
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 150.0
	mat.damping_min = 80.0
	mat.damping_max = 150.0
	mat.scale_min = 0.5
	mat.scale_max = 2.0

	var color: Color = TIMBRE_COLORS.get(_current_timbre, Color(0.0, 1.0, 0.83))
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 1.0))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	burst.process_material = mat
	add_child(burst)
	burst.emitting = true

	# 自动清理
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)

func _transition_timbre_visual(_old_timbre: int, new_timbre: int) -> void:
	# 音色切换的视觉过渡
	var target_color: Color = TIMBRE_COLORS.get(new_timbre, Color(0.0, 1.0, 0.83))
	
	if _visual_node:
		var tween := create_tween()
		tween.tween_property(_visual_node, "modulate",
			Color(target_color.r * 1.2, target_color.g * 1.2, target_color.b * 1.2, 1.0),
			timbre_transition_duration * 0.3)
		tween.tween_property(_visual_node, "modulate",
			Color.WHITE,
			timbre_transition_duration * 0.7)

func _transition_phase_visual(_old_phase: int, new_phase: int) -> void:
	# 频谱相位切换的视觉过渡
	var phase_color: Color = PHASE_COLORS.get(new_phase, Color(1.0, 1.0, 1.0, 0.0))
	
	# 通知全局视觉环境
	var gve = get_node_or_null("/root/GlobalVisualEnvironment")
	if gve and gve.has_method("set_glow_override"):
		# 切换瞬间 Glow 闪烁
		gve.set_glow_override(1.5, 0.1)
		get_tree().create_timer(0.2).timeout.connect(func():
			if gve.has_method("reset_glow"):
				gve.reset_glow(0.5)
		)

	# 更新 Shader
	set_shader_param("phase_mode", new_phase)
	set_shader_param("phase_color", phase_color)

# ============================================================
# 节拍视觉响应
# ============================================================

func _on_beat_visual() -> void:
	# 节拍时核心发光脉冲
	set_shader_param("beat_energy", 1.0)
	
	# 光环脉冲
	if _aura_particles and _aura_particles.process_material:
		var mat := _aura_particles.process_material as ParticleProcessMaterial
		if mat:
			mat.emission_ring_radius = aura_base_radius + aura_pulse_amount

# ============================================================
# 公共接口
# ============================================================

## 获取当前音色
func get_current_timbre() -> int:
	return _current_timbre

## 获取当前相位
func get_current_phase() -> int:
	return _current_phase

## 手动设置音色（用于测试）
func force_timbre(timbre: int) -> void:
	_on_timbre_changed(timbre)

## 手动设置相位（用于测试）
func force_phase(phase: int) -> void:
	_on_phase_changed(phase)
