## lydian_mode.gd
## 吕底亚调式化身 (Issue #59 - mode_id=2)
## "星云的舞者" - The Nebula
##
## VFX: GPUParticles3D 星云/星环效果，无纹理粒子
## 颜色: 程序化彩虹色 (hsv_to_rgb 基于粒子生命周期)
## 效果: 旋转星尘漩涡, 星尘涟漪施法爆发, 惯性拖尾
## 动画风格: 飘逸、广阔、如星云般流动
extends Node3D

class_name LydianMode

# ============================================================
# 配置
# ============================================================
## 星环半径
@export var ring_radius: float = 0.4
## 星环厚度
@export var ring_thickness: float = 0.08
## 粒子数量
@export var particle_count: int = 200
## 粒子生命周期
@export var particle_lifetime: float = 2.0
## 旋转速度
@export var swirl_speed: float = 0.5
## 惯性系数
@export var inertia_factor: float = 0.85

# ============================================================
# 颜色定义（彩虹色由着色器程序化生成）
# ============================================================
const COLOR_NEBULA_BASE := Color(0.6, 0.4, 1.0)
const COLOR_STAR_WHITE := Color(1.0, 0.95, 0.9)

# ============================================================
# 节点引用
# ============================================================
var _nebula_particles: GPUParticles3D = null
var _burst_particles: GPUParticles3D = null
var _shader_material: ShaderMaterial = null
var _particle_material: ShaderMaterial = null

# ============================================================
# 状态
# ============================================================
var _time: float = 0.0
var _beat_energy: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _velocity_offset: Vector3 = Vector3.ZERO

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_create_shader_material()
	_create_nebula_particles()
	_create_burst_particles()

func _process(delta: float) -> void:
	_time += delta
	_update_swirl(delta)
	_update_inertia(delta)
	_update_shader_params()
	_decay_effects(delta)

# ============================================================
# 着色器材质
# ============================================================

func _create_shader_material() -> ShaderMaterial:
	_shader_material = ShaderMaterial.new()
	var shader := load("res://shaders/player_mode.gdshader")
	if shader:
		_shader_material.shader = shader
	_shader_material.set_shader_parameter("mode_id", 2)
	_shader_material.set_shader_parameter("primary_color", Vector3(
		COLOR_NEBULA_BASE.r, COLOR_NEBULA_BASE.g, COLOR_NEBULA_BASE.b))
	_shader_material.set_shader_parameter("secondary_color", Vector3(
		COLOR_STAR_WHITE.r, COLOR_STAR_WHITE.g, COLOR_STAR_WHITE.b))
	_shader_material.set_shader_parameter("emission_energy", 3.5)
	_shader_material.set_shader_parameter("nebula_density", 1.0)
	_shader_material.set_shader_parameter("star_brightness", 1.0)
	return _shader_material

# ============================================================
# 星云粒子系统
# ============================================================

func _create_nebula_particles() -> void:
	_nebula_particles = GPUParticles3D.new()
	_nebula_particles.name = "NebulaParticles"
	_nebula_particles.amount = particle_count
	_nebula_particles.lifetime = particle_lifetime
	_nebula_particles.preprocess = 1.0
	_nebula_particles.explosiveness = 0.0
	_nebula_particles.randomness = 0.3
	_nebula_particles.fixed_fps = 60
	_nebula_particles.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME

	# 创建粒子处理材质
	var process_mat := ParticleProcessMaterial.new()

	# 环形发射
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process_mat.emission_ring_radius = ring_radius
	process_mat.emission_ring_inner_radius = ring_radius - ring_thickness
	process_mat.emission_ring_height = ring_thickness * 0.5
	process_mat.emission_ring_axis = Vector3(0, 1, 0)

	# 运动参数
	process_mat.direction = Vector3(0, 0, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 0.02
	process_mat.initial_velocity_max = 0.08
	process_mat.gravity = Vector3(0, 0, 0)  # 无重力
	process_mat.damping_min = 0.5
	process_mat.damping_max = 1.5

	# 缩放
	process_mat.scale_min = 0.3
	process_mat.scale_max = 1.2

	# 程序化彩虹色渐变
	var color_gradient := Gradient.new()
	color_gradient.set_color(0, Color(1.0, 0.3, 0.3, 0.0))    # 红色淡入
	color_gradient.add_point(0.15, Color(1.0, 0.6, 0.2, 0.6))  # 橙色
	color_gradient.add_point(0.3, Color(1.0, 1.0, 0.3, 0.8))   # 黄色
	color_gradient.add_point(0.45, Color(0.3, 1.0, 0.5, 0.9))  # 绿色
	color_gradient.add_point(0.6, Color(0.3, 0.7, 1.0, 0.8))   # 蓝色
	color_gradient.add_point(0.75, Color(0.6, 0.3, 1.0, 0.6))  # 紫色
	color_gradient.set_color(1, Color(0.8, 0.4, 1.0, 0.0))     # 淡出

	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = color_gradient
	process_mat.color_ramp = color_ramp

	# 缩放曲线
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.0))
	scale_curve.add_point(Vector2(0.2, 1.0))
	scale_curve.add_point(Vector2(0.8, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	process_mat.scale_curve = scale_texture

	_nebula_particles.process_material = process_mat

	# 使用简单的球形网格作为粒子（无纹理）
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.008
	particle_mesh.height = 0.016
	particle_mesh.radial_segments = 4
	particle_mesh.rings = 2
	_nebula_particles.draw_pass_1 = particle_mesh

	add_child(_nebula_particles)

# ============================================================
# 施法爆发粒子
# ============================================================

func _create_burst_particles() -> void:
	_burst_particles = GPUParticles3D.new()
	_burst_particles.name = "BurstParticles"
	_burst_particles.amount = 64
	_burst_particles.lifetime = 0.8
	_burst_particles.one_shot = true
	_burst_particles.emitting = false
	_burst_particles.explosiveness = 1.0

	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = ring_radius * 0.5
	process_mat.direction = Vector3(0, 0, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 0.3
	process_mat.initial_velocity_max = 0.8
	process_mat.damping_min = 2.0
	process_mat.damping_max = 4.0
	process_mat.gravity = Vector3(0, 0, 0)

	# 爆发时的彩虹色
	var burst_gradient := Gradient.new()
	burst_gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	burst_gradient.add_point(0.3, Color(0.5, 0.8, 1.0, 0.8))
	burst_gradient.set_color(1, Color(0.6, 0.3, 1.0, 0.0))
	var burst_ramp := GradientTexture1D.new()
	burst_ramp.gradient = burst_gradient
	process_mat.color_ramp = burst_ramp

	_burst_particles.process_material = process_mat

	var burst_mesh := SphereMesh.new()
	burst_mesh.radius = 0.012
	burst_mesh.height = 0.024
	burst_mesh.radial_segments = 4
	burst_mesh.rings = 2
	_burst_particles.draw_pass_1 = burst_mesh

	add_child(_burst_particles)

# ============================================================
# 更新逻辑
# ============================================================

## 旋转星尘漩涡
func _update_swirl(delta: float) -> void:
	if _nebula_particles:
		_nebula_particles.rotation.y += swirl_speed * delta

## 惯性效果 - 移动后光环继续飘动
func _update_inertia(_delta: float) -> void:
	var current_pos := global_position
	var movement := current_pos - _last_position
	_last_position = current_pos

	# 计算惯性偏移
	_velocity_offset = _velocity_offset * inertia_factor + movement * (1.0 - inertia_factor)

	# 应用惯性偏移到粒子系统
	if _nebula_particles:
		_nebula_particles.position = -_velocity_offset * 2.0

## 更新着色器参数
func _update_shader_params() -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("beat_energy", _beat_energy)
		_shader_material.set_shader_parameter("nebula_density",
			1.0 + _beat_energy * 0.3)
		_shader_material.set_shader_parameter("star_brightness",
			1.0 + _beat_energy * 2.0)

## 效果衰减
func _decay_effects(delta: float) -> void:
	_beat_energy = max(0.0, _beat_energy - delta * 2.0)

# ============================================================
# 公共接口
# ============================================================

## 触发节拍脉冲
func trigger_beat() -> void:
	_beat_energy = 1.0

## 触发施法星尘涟漪 (emit_particles 爆发)
func trigger_spellcast_ripple() -> void:
	if _burst_particles:
		_burst_particles.emitting = true

## 获取调式 ID
func get_mode_id() -> int:
	return 2

## 获取着色器材质
func get_shader_material() -> ShaderMaterial:
	return _shader_material
