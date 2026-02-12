## ionian_mode.gd
## 爱奥尼亚调式化身 (Issue #59 - mode_id=0)
## "和谐的指挥家" - The Standard
##
## 几何体: 三同心 TorusMesh 光环 + ArrayMesh 十二面体核心
## 颜色: Resonant Teal (#00D9BF) + Crystal White (#E6F0FF)
## 效果: 平滑 BPM 同步旋转, 柔和涟漪施法效果
## 动画风格: 精准、平滑、与节拍完美同步
extends Node3D

class_name IonianMode

# ============================================================
# 配置
# ============================================================
## 核心十二面体大小
@export var core_radius: float = 0.15
## 光环半径 [内环, 中环, 外环]
@export var ring_radii: Array[float] = [0.25, 0.35, 0.45]
## 光环旋转速度（弧度/秒）[内环, 中环, 外环]
@export var ring_speeds: Array[float] = [0.8, -1.2, 0.5]
## 光环管半径
@export var ring_tube_radius: float = 0.008

# ============================================================
# 颜色定义
# ============================================================
const COLOR_RESONANT_TEAL := Color(0.0, 0.85, 0.75)
const COLOR_CRYSTAL_WHITE := Color(0.9, 0.94, 1.0)

# ============================================================
# 节点引用
# ============================================================
var _core_mesh: MeshInstance3D = null
var _rings: Array[MeshInstance3D] = []
var _shader_material: ShaderMaterial = null

# ============================================================
# 状态
# ============================================================
var _time: float = 0.0
var _beat_energy: float = 0.0
var _ripple_intensity: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_create_shader_material()
	_create_core()
	_create_rings()

func _process(delta: float) -> void:
	_time += delta
	_update_rotation(delta)
	_update_breathing(delta)
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
	_shader_material.set_shader_parameter("mode_id", 0)
	_shader_material.set_shader_parameter("primary_color", Vector3(
		COLOR_RESONANT_TEAL.r, COLOR_RESONANT_TEAL.g, COLOR_RESONANT_TEAL.b))
	_shader_material.set_shader_parameter("secondary_color", Vector3(
		COLOR_CRYSTAL_WHITE.r, COLOR_CRYSTAL_WHITE.g, COLOR_CRYSTAL_WHITE.b))
	_shader_material.set_shader_parameter("emission_energy", 3.0)
	_shader_material.set_shader_parameter("fresnel_power", 2.5)
	_shader_material.set_shader_parameter("rotation_speed", 1.0)
	return _shader_material

# ============================================================
# 十二面体核心
# ============================================================

func _create_core() -> void:
	_core_mesh = MeshInstance3D.new()
	_core_mesh.name = "DodecahedronCore"
	_core_mesh.mesh = _generate_dodecahedron(core_radius)
	_core_mesh.material_override = _shader_material
	add_child(_core_mesh)

## 程序化生成正十二面体 ArrayMesh
func _generate_dodecahedron(radius: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	# 正十二面体的顶点（基于黄金比例）
	var phi: float = (1.0 + sqrt(5.0)) / 2.0
	var inv_phi: float = 1.0 / phi

	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var indices: PackedInt32Array = []

	# 20 个顶点
	var raw_verts: Array[Vector3] = [
		# 立方体顶点 (±1, ±1, ±1)
		Vector3(-1, -1, -1), Vector3(-1, -1, 1),
		Vector3(-1, 1, -1), Vector3(-1, 1, 1),
		Vector3(1, -1, -1), Vector3(1, -1, 1),
		Vector3(1, 1, -1), Vector3(1, 1, 1),
		# (0, ±inv_phi, ±phi)
		Vector3(0, -inv_phi, -phi), Vector3(0, -inv_phi, phi),
		Vector3(0, inv_phi, -phi), Vector3(0, inv_phi, phi),
		# (±inv_phi, ±phi, 0)
		Vector3(-inv_phi, -phi, 0), Vector3(-inv_phi, phi, 0),
		Vector3(inv_phi, -phi, 0), Vector3(inv_phi, phi, 0),
		# (±phi, 0, ±inv_phi)
		Vector3(-phi, 0, -inv_phi), Vector3(-phi, 0, inv_phi),
		Vector3(phi, 0, -inv_phi), Vector3(phi, 0, inv_phi),
	]

	# 归一化到指定半径
	for i in range(raw_verts.size()):
		raw_verts[i] = raw_verts[i].normalized() * radius

	# 正十二面体的 12 个五边形面（用三角形扇形化）
	var faces: Array = [
		[0, 8, 10, 2, 16],
		[0, 16, 17, 1, 12],
		[0, 12, 14, 4, 8],
		[7, 11, 9, 5, 19],
		[7, 19, 18, 6, 15],
		[7, 15, 13, 3, 11],
		[1, 17, 3, 11, 9],
		[1, 9, 5, 14, 12],
		[2, 10, 6, 15, 13],
		[2, 13, 3, 17, 16],
		[4, 14, 5, 19, 18],
		[4, 18, 6, 10, 8],
	]

	for face in faces:
		# 计算面法线
		var v0: Vector3 = raw_verts[face[0]]
		var v1: Vector3 = raw_verts[face[1]]
		var v2: Vector3 = raw_verts[face[2]]
		var face_normal := (v1 - v0).cross(v2 - v0).normalized()

		# 五边形扇形三角化
		var center := Vector3.ZERO
		for idx in face:
			center += raw_verts[idx]
		center /= float(face.size())

		var base_idx := vertices.size()
		# 添加中心点
		vertices.append(center)
		normals.append(face_normal)
		uvs.append(Vector2(0.5, 0.5))

		# 添加五边形顶点
		for i in range(face.size()):
			var v: Vector3 = raw_verts[face[i]]
			vertices.append(v)
			normals.append(face_normal)
			var angle := float(i) / float(face.size()) * TAU
			uvs.append(Vector2(cos(angle) * 0.5 + 0.5, sin(angle) * 0.5 + 0.5))

		# 三角形索引
		for i in range(face.size()):
			indices.append(base_idx)  # 中心
			indices.append(base_idx + 1 + i)
			indices.append(base_idx + 1 + ((i + 1) % face.size()))

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# ============================================================
# 同心光环
# ============================================================

func _create_rings() -> void:
	for i in range(3):
		var ring := MeshInstance3D.new()
		ring.name = "Ring_%d" % i

		var torus := TorusMesh.new()
		torus.inner_radius = ring_radii[i] - ring_tube_radius
		torus.outer_radius = ring_radii[i] + ring_tube_radius
		torus.rings = 48
		torus.ring_segments = 12
		ring.mesh = torus
		ring.material_override = _shader_material

		# 不同倾斜角度
		match i:
			0: ring.rotation_degrees = Vector3(0, 0, 0)
			1: ring.rotation_degrees = Vector3(15, 0, 0)
			2: ring.rotation_degrees = Vector3(-10, 0, 10)

		_rings.append(ring)
		add_child(ring)

# ============================================================
# 更新逻辑
# ============================================================

## 平滑 BPM 同步旋转
func _update_rotation(delta: float) -> void:
	# 核心缓慢自转
	if _core_mesh:
		_core_mesh.rotation.y += delta * 0.3

	# 光环各自旋转
	for i in range(_rings.size()):
		if i < ring_speeds.size():
			_rings[i].rotation.y += ring_speeds[i] * delta

## BPM 呼吸效果 - 整体缩放 1% 并恢复
func _update_breathing(_delta: float) -> void:
	var breath := sin(_time * 2.0) * 0.01
	var breath_scale := 1.0 + breath + _beat_energy * 0.03
	scale = Vector3(breath_scale, breath_scale, breath_scale)

## 更新着色器参数
func _update_shader_params() -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("beat_energy", _beat_energy)
		_shader_material.set_shader_parameter("ripple_intensity", _ripple_intensity)
		_shader_material.set_shader_parameter("bpm_phase", fmod(_time, 1.0))

## 效果衰减
func _decay_effects(delta: float) -> void:
	_beat_energy = max(0.0, _beat_energy - delta * 3.0)
	_ripple_intensity = max(0.0, _ripple_intensity - delta * 2.0)

# ============================================================
# 公共接口
# ============================================================

## 触发节拍脉冲
func trigger_beat() -> void:
	_beat_energy = 1.0

## 触发施法涟漪效果
func trigger_spellcast_ripple() -> void:
	_ripple_intensity = 1.0

## 获取调式 ID
func get_mode_id() -> int:
	return 0

## 获取着色器材质
func get_shader_material() -> ShaderMaterial:
	return _shader_material
