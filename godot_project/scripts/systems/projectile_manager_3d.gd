## projectile_manager_3d.gd
## 3D 弹幕渲染管理器
##
## 职责：
## 1. 使用 MultiMeshInstance3D 实现高性能弹幕渲染
## 2. 接收 2D 弹幕数据并映射到 3D 空间
## 3. 应用 3D 材质和 Glow 效果
extends Node3D

# ============================================================
# 配置
# ============================================================
@export var max_projectiles: int = 5000
@export var mesh_size: float = 0.2

# ============================================================
# 引用
# ============================================================
var mm_instance: MultiMeshInstance3D
var _material: ShaderMaterial

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_multimesh()

func _setup_multimesh() -> void:
	mm_instance = MultiMeshInstance3D.new()
	mm_instance.name = "ProjectileMultiMesh"
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.instance_count = max_projectiles
	mm.visible_instance_count = 0
	
	# 使用 QuadMesh 作为弹体基础
	var quad := QuadMesh.new()
	quad.size = Vector2(mesh_size, mesh_size)
	quad.orientation = PlaneMesh.FACE_Y  # 修复：面向Y轴，确保俯视正交摄像机下可见
	mm.mesh = quad
	
	mm_instance.multimesh = mm
	
	# 设置材质
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/projectile_glow_3d.gdshader")
	mm_instance.material_override = _material
	
	add_child(mm_instance)

# ============================================================
# 渲染更新
# ============================================================

## 批量更新弹体位置（由 2D 弹幕系统调用）
func update_projectiles(projectile_data: Array) -> void:
	var mm = mm_instance.multimesh
	var count = min(projectile_data.size(), max_projectiles)
	mm.visible_instance_count = count
	
	var gve = get_node_or_null("/root/GlobalVisualEnvironment3D")
	
	for i in range(count):
		var data = projectile_data[i]
		var pos_2d = data.get("position", Vector2.ZERO)
		var rot_2d = data.get("rotation", 0.0)
		var color = data.get("color", Color.WHITE)
		var custom = data.get("custom_data", Color(0,0,0,0))
		
		# 转换到 3D 空间
		var pos_3d = gve.to_3d(pos_2d) if gve else Vector3(pos_2d.x/100.0, 0, pos_2d.y/100.0)
		
		var t = Transform3D()
		t = t.rotated(Vector3.UP, -rot_2d)
		t.origin = pos_3d
		
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, color)
		mm.set_instance_custom_data(i, custom)
