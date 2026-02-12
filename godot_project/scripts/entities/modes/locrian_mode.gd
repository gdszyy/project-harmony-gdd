## locrian_mode.gd
## 洛克里亚调式化身 (Issue #59 - mode_id=1)
## "失谐的痉挛者" - The Glitch
##
## 几何体: 三条不闭合的管状弧线 (ArrayMesh)
## 颜色: Corrosive Purple (#8B00FF) + Error Red (#FF2020)
## 效果: 顶点毛刺位移, 色差, 数字衰变闪烁
## 动画风格: 不稳定、抽搐、充满"错误"感
extends Node3D

class_name LocrianMode

# ============================================================
# 配置
# ============================================================
## 弧线半径 [内弧, 中弧, 外弧]
@export var arc_radii: Array[float] = [0.25, 0.35, 0.45]
## 弧线管半径
@export var arc_tube_radius: float = 0.012
## 弧线开口角度（弧度）
@export var arc_gap_angle: float = 0.8
## 弧线段数
@export var arc_segments: int = 32
## 管截面段数
@export var tube_segments: int = 8

# ============================================================
# 颜色定义
# ============================================================
const COLOR_CORROSIVE_PURPLE := Color(0.55, 0.0, 1.0)
const COLOR_ERROR_RED := Color(1.0, 0.125, 0.125)

# ============================================================
# 节点引用
# ============================================================
var _arcs: Array[MeshInstance3D] = []
var _shader_material: ShaderMaterial = null

# ============================================================
# 状态
# ============================================================
var _time: float = 0.0
var _beat_energy: float = 0.0
var _glitch_intensity: float = 0.3  # 基础毛刺强度
var _damage_glitch_boost: float = 0.0  # 受伤时的额外毛刺

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_create_shader_material()
	_create_arcs()

func _process(delta: float) -> void:
	_time += delta
	_update_jitter(delta)
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
	_shader_material.set_shader_parameter("mode_id", 1)
	_shader_material.set_shader_parameter("primary_color", Vector3(
		COLOR_CORROSIVE_PURPLE.r, COLOR_CORROSIVE_PURPLE.g, COLOR_CORROSIVE_PURPLE.b))
	_shader_material.set_shader_parameter("secondary_color", Vector3(
		COLOR_ERROR_RED.r, COLOR_ERROR_RED.g, COLOR_ERROR_RED.b))
	_shader_material.set_shader_parameter("emission_energy", 4.0)
	_shader_material.set_shader_parameter("fresnel_power", 2.0)
	_shader_material.set_shader_parameter("glitch_intensity", _glitch_intensity)
	_shader_material.set_shader_parameter("jitter_frequency", 15.0)
	_shader_material.set_shader_parameter("chromatic_aberration", 0.02)
	return _shader_material

# ============================================================
# 不闭合弧线生成
# ============================================================

func _create_arcs() -> void:
	for i in range(3):
		var arc := MeshInstance3D.new()
		arc.name = "Arc_%d" % i
		arc.mesh = _generate_tube_arc(arc_radii[i], arc_tube_radius, arc_gap_angle)
		arc.material_override = _shader_material

		# 不同倾斜角度和偏移，制造不规则感
		match i:
			0:
				arc.rotation_degrees = Vector3(0, 0, 0)
			1:
				arc.rotation_degrees = Vector3(20, 120, 5)
			2:
				arc.rotation_degrees = Vector3(-15, 240, -8)

		_arcs.append(arc)
		add_child(arc)

## 程序化生成管状弧线 ArrayMesh（不闭合的环）
func _generate_tube_arc(radius: float, tube_r: float, gap: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var indices: PackedInt32Array = []

	var arc_angle: float = TAU - gap  # 弧线覆盖的角度

	for i in range(arc_segments + 1):
		var t: float = float(i) / float(arc_segments)
		var angle: float = t * arc_angle - arc_angle * 0.5  # 居中弧线

		# 弧线中心点
		var center := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		# 弧线切线方向
		var tangent := Vector3(-sin(angle), 0, cos(angle)).normalized()
		# 法线方向（从中心向外）
		var outward := Vector3(cos(angle), 0, sin(angle)).normalized()
		# 上方向
		var up := Vector3.UP

		for j in range(tube_segments + 1):
			var tube_t: float = float(j) / float(tube_segments)
			var tube_angle: float = tube_t * TAU

			# 管截面上的点
			var local_normal := outward * cos(tube_angle) + up * sin(tube_angle)
			var vertex := center + local_normal * tube_r

			vertices.append(vertex)
			normals.append(local_normal)
			uvs.append(Vector2(t, tube_t))

	# 生成三角形索引
	for i in range(arc_segments):
		for j in range(tube_segments):
			var current := i * (tube_segments + 1) + j
			var next := current + tube_segments + 1

			indices.append(current)
			indices.append(next)
			indices.append(current + 1)

			indices.append(current + 1)
			indices.append(next)
			indices.append(next + 1)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# ============================================================
# 更新逻辑
# ============================================================

## 抽搐/抖动效果 - 随机偏移弧线位置和旋转
func _update_jitter(_delta: float) -> void:
	var total_glitch := _glitch_intensity + _damage_glitch_boost

	for i in range(_arcs.size()):
		var arc := _arcs[i]

		# 随机触发抽搐
		if randf() < total_glitch * 0.15:
			# 位置抖动
			arc.position = Vector3(
				randf_range(-0.01, 0.01) * total_glitch,
				randf_range(-0.01, 0.01) * total_glitch,
				randf_range(-0.005, 0.005) * total_glitch
			)
			# 旋转抖动
			arc.rotation_degrees.z += randf_range(-2.0, 2.0) * total_glitch
		else:
			# 缓慢回归原位
			arc.position = arc.position.lerp(Vector3.ZERO, 0.1)

## 更新着色器参数
func _update_shader_params() -> void:
	if _shader_material:
		var total_glitch := _glitch_intensity + _damage_glitch_boost
		_shader_material.set_shader_parameter("glitch_intensity", total_glitch)
		_shader_material.set_shader_parameter("chromatic_aberration",
			0.02 + _damage_glitch_boost * 0.05)
		_shader_material.set_shader_parameter("beat_energy", _beat_energy)

## 效果衰减
func _decay_effects(delta: float) -> void:
	_beat_energy = max(0.0, _beat_energy - delta * 3.0)
	_damage_glitch_boost = max(0.0, _damage_glitch_boost - delta * 2.0)

# ============================================================
# 公共接口
# ============================================================

## 触发节拍脉冲
func trigger_beat() -> void:
	_beat_energy = 1.0
	# 洛克里亚式的节拍是不稳定的 - 随机偏移
	if randf() < 0.3:
		_glitch_intensity = clamp(_glitch_intensity + randf_range(-0.1, 0.15), 0.1, 0.6)

## 触发施法效果 - 强烈抽搐
func trigger_spellcast_ripple() -> void:
	_damage_glitch_boost = 0.5

## 触发受击效果 - 数字衰变
func trigger_damage_decay() -> void:
	_damage_glitch_boost = 0.8

## 设置基础毛刺强度
func set_base_glitch(intensity: float) -> void:
	_glitch_intensity = clamp(intensity, 0.0, 1.0)

## 获取调式 ID
func get_mode_id() -> int:
	return 1

## 获取着色器材质
func get_shader_material() -> ShaderMaterial:
	return _shader_material
