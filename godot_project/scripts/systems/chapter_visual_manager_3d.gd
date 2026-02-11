## chapter_visual_manager_3d.gd
## 3D 章节视觉管理器
##
## 职责：
## 1. 管理 3D 地面网格 (PlaneMesh) 及其 Shader
## 2. 动态切换 3D 环境特效
## 3. 处理 3D 空间的章节过渡
extends Node3D

# ============================================================
# 配置
# ============================================================
@export var ground_size: Vector2 = Vector2(100, 100)

# ============================================================
# 状态
# ============================================================
var ground_mesh: MeshInstance3D
var _current_material: ShaderMaterial

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_ground()
	_connect_signals()

func _setup_ground() -> void:
	ground_mesh = MeshInstance3D.new()
	ground_mesh.name = "ChapterGround"
	
	var plane := PlaneMesh.new()
	plane.size = ground_size
	ground_mesh.mesh = plane
	
	_current_material = ShaderMaterial.new()
	ground_mesh.material_override = _current_material
	
	add_child(ground_mesh)

func _connect_signals() -> void:
	var cm = get_node_or_null("/root/ChapterManager")
	if cm and cm.has_signal("chapter_started"):
		cm.chapter_started.connect(_on_chapter_started)

# ============================================================
# 章节切换
# ============================================================

func _on_chapter_started(chapter: int, _name: String) -> void:
	_update_ground_shader(chapter)
	_update_environment_vfx(chapter)

func _update_ground_shader(chapter: int) -> void:
	var shader_path = "res://shaders/chapters/3d/ch%d_ground_3d.gdshader" % (chapter + 1)
	if FileAccess.file_exists(shader_path):
		var shader = load(shader_path)
		_current_material.shader = shader
	else:
		# 如果没有专门的 3D Shader，尝试使用通用的 3D 基础 Shader
		var base_shader = load("res://shaders/chapters/3d/base_ground_3d.gdshader")
		_current_material.shader = base_shader
		_current_material.set_shader_parameter("chapter_index", chapter)

func _update_environment_vfx(chapter: int) -> void:
	# 清理旧特效
	for child in get_children():
		if child.name.begins_with("EnvVFX"):
			child.queue_free()
	
	# 根据章节创建新的 3D 特效
	match chapter:
		0: # 毕达哥拉斯：浮动几何体
			_create_floating_geometry()
		6: # 数字：代码雨粒子
			_create_digital_rain()

func _create_floating_geometry() -> void:
	var particles = GPUParticles3D.new()
	particles.name = "EnvVFX_Geometry"
	# 配置 3D 粒子材质与网格...
	add_child(particles)

func _create_digital_rain() -> void:
	# 配置 3D 代码雨...
	pass
