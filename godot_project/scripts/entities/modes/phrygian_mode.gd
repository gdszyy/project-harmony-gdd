## phrygian_mode.gd
## 弗里几亚调式化身 (Issue #59 - mode_id=3)
## "利刃的刺客" - The Blade
##
## 几何体: ArrayMesh 尖锐晶体核心 + TorusMesh 刀锋变形光环
## 颜色: Error Red (#FF2020) + Neon Pink (#FF69B4)
## 效果: 刀锋变形, 刺击闪光, 威胁性脉动
## 动画风格: 迅捷、致命、充满攻击性
extends Node3D

class_name PhrygianMode

# ============================================================
# 配置
# ============================================================
## 晶体核心大小
@export var crystal_radius: float = 0.12
## 晶体尖锐度
@export var crystal_sharpness: float = 2.0
## 刀锋光环半径
@export var blade_ring_radius: float = 0.35
## 刀锋光环管半径
@export var blade_tube_radius: float = 0.01
## 刀锋锐利度
@export var blade_sharpness: float = 1.5
## 威胁性脉动速度
@export var threat_pulse_speed: float = 1.5

# ============================================================
# 颜色定义
# ============================================================
const COLOR_ERROR_RED := Color(1.0, 0.125, 0.125)
const COLOR_NEON_PINK := Color(1.0, 0.41, 0.71)

# ============================================================
# 节点引用
# ============================================================
var _crystal_core: MeshInstance3D = null
var _blade_ring: MeshInstance3D = null
var _shader_material: ShaderMaterial = null

# ============================================================
# 状态
# ============================================================
var _time: float = 0.0
var _beat_energy: float = 0.0
var _stab_offset: float = 0.0
var _threat_pulse: float = 0.5  # 基础威胁脉动

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_create_shader_material()
	_create_crystal_core()
	_create_blade_ring()

func _process(delta: float) -> void:
	_time += delta
	_update_threat_pulse(delta)
	_update_blade_animation(delta)
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
	_shader_material.set_shader_parameter("mode_id", 3)
	_shader_material.set_shader_parameter("primary_color", Vector3(
		COLOR_ERROR_RED.r, COLOR_ERROR_RED.g, COLOR_ERROR_RED.b))
	_shader_material.set_shader_parameter("secondary_color", Vector3(
		COLOR_NEON_PINK.r, COLOR_NEON_PINK.g, COLOR_NEON_PINK.b))
	_shader_material.set_shader_parameter("emission_energy", 4.0)
	_shader_material.set_shader_parameter("fresnel_power", 3.0)
	_shader_material.set_shader_parameter("blade_sharpness", blade_sharpness)
	_shader_material.set_shader_parameter("threat_pulse", _threat_pulse)
	return _shader_material

# ============================================================
# 尖锐晶体核心
# ============================================================

func _create_crystal_core() -> void:
	_crystal_core = MeshInstance3D.new()
	_crystal_core.name = "CrystalCore"
	_crystal_core.mesh = _generate_crystal_cluster(crystal_radius, crystal_sharpness)
	_crystal_core.material_override = _shader_material
	add_child(_crystal_core)

## 程序化生成尖锐晶体簇 ArrayMesh
func _generate_crystal_cluster(radius: float, sharpness: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var indices: PackedInt32Array = []

	# 生成多个尖锐的四面体晶体
	var crystal_count := 6
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # 固定种子确保一致性

	for c in range(crystal_count):
		var base_idx := vertices.size()

		# 随机方向
		var dir := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-0.5, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized()

		# 晶体尖端
		var tip := dir * radius * sharpness * rng.randf_range(0.8, 1.2)

		# 晶体底面（三角形）
		var base_center := dir * radius * 0.3
		var perp1 := dir.cross(Vector3.UP).normalized()
		if perp1.length() < 0.1:
			perp1 = dir.cross(Vector3.RIGHT).normalized()
		var perp2 := dir.cross(perp1).normalized()
		var base_size := radius * 0.15 * rng.randf_range(0.7, 1.3)

		var b0 := base_center + perp1 * base_size
		var b1 := base_center + perp2 * base_size
		var b2 := base_center - perp1 * base_size * 0.5 - perp2 * base_size * 0.5

		# 三个侧面
		var faces_data := [
			[tip, b0, b1],
			[tip, b1, b2],
			[tip, b2, b0],
		]

		for face in faces_data:
			var v0: Vector3 = face[0]
			var v1: Vector3 = face[1]
			var v2: Vector3 = face[2]
			var face_normal := (v1 - v0).cross(v2 - v0).normalized()

			var idx := vertices.size()
			vertices.append(v0)
			vertices.append(v1)
			vertices.append(v2)
			normals.append(face_normal)
			normals.append(face_normal)
			normals.append(face_normal)
			uvs.append(Vector2(0.5, 0.0))
			uvs.append(Vector2(0.0, 1.0))
			uvs.append(Vector2(1.0, 1.0))
			indices.append(idx)
			indices.append(idx + 1)
			indices.append(idx + 2)

		# 底面
		var bottom_normal := -dir
		var idx := vertices.size()
		vertices.append(b0)
		vertices.append(b1)
		vertices.append(b2)
		normals.append(bottom_normal)
		normals.append(bottom_normal)
		normals.append(bottom_normal)
		uvs.append(Vector2(0.0, 0.0))
		uvs.append(Vector2(1.0, 0.0))
		uvs.append(Vector2(0.5, 1.0))
		indices.append(idx)
		indices.append(idx + 2)
		indices.append(idx + 1)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# ============================================================
# 刀锋光环
# ============================================================

func _create_blade_ring() -> void:
	_blade_ring = MeshInstance3D.new()
	_blade_ring.name = "BladeRing"

	# 使用 TorusMesh，刀锋变形在着色器中实现
	var torus := TorusMesh.new()
	torus.inner_radius = blade_ring_radius - blade_tube_radius
	torus.outer_radius = blade_ring_radius + blade_tube_radius
	torus.rings = 64
	torus.ring_segments = 8
	_blade_ring.mesh = torus
	_blade_ring.material_override = _shader_material

	add_child(_blade_ring)

# ============================================================
# 更新逻辑
# ============================================================

## 威胁性脉动 - 缓慢的明暗交替和开合
func _update_threat_pulse(_delta: float) -> void:
	# 缓慢呼吸般的开合
	var pulse := sin(_time * threat_pulse_speed) * 0.5 + 0.5
	_threat_pulse = 0.3 + pulse * 0.7

	# 刀锋光环缓慢开合
	if _blade_ring:
		var scale_pulse := 1.0 + sin(_time * threat_pulse_speed * 0.5) * 0.05
		_blade_ring.scale = Vector3(scale_pulse, 1.0, scale_pulse)

	# 晶体核心不稳定红光
	if _crystal_core:
		var crystal_pulse := 0.8 + sin(_time * threat_pulse_speed * 2.0) * 0.2
		_crystal_core.scale = Vector3.ONE * crystal_pulse

## 刀锋动画
func _update_blade_animation(delta: float) -> void:
	# 刺击偏移衰减
	if _stab_offset > 0.01:
		# 快速的前冲
		position.z -= _stab_offset * 0.02
	else:
		# 缓慢回归
		position.z = lerp(position.z, 0.0, delta * 5.0)

## 更新着色器参数
func _update_shader_params() -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("beat_energy", _beat_energy)
		_shader_material.set_shader_parameter("stab_offset", _stab_offset)
		_shader_material.set_shader_parameter("threat_pulse", _threat_pulse)
		_shader_material.set_shader_parameter("blade_sharpness", blade_sharpness)

## 效果衰减
func _decay_effects(delta: float) -> void:
	_beat_energy = max(0.0, _beat_energy - delta * 4.0)
	_stab_offset = max(0.0, _stab_offset - delta * 6.0)

# ============================================================
# 公共接口
# ============================================================

## 触发节拍脉冲
func trigger_beat() -> void:
	_beat_energy = 1.0

## 触发施法效果 - 快速刺击
func trigger_spellcast_ripple() -> void:
	_stab_offset = 1.0

## 触发刺击动作（可由 root 骨骼或管理器调用）
func trigger_stab() -> void:
	_stab_offset = 1.0

## 获取调式 ID
func get_mode_id() -> int:
	return 3

## 获取着色器材质
func get_shader_material() -> ShaderMaterial:
	return _shader_material
