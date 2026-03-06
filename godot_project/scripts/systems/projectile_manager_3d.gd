## projectile_manager_3d.gd
## 3D 弹幕渲染管理器 (重构版)
##
## 职责：
## 1. 使用 MultiMeshInstance3D 实现高性能弹幕渲染
## 2. 接收 2D 弹幕数据并映射到 3D 空间
## 3. 应用统一的 spell_material_3d.gdshader
## 4. 实现弹性扩容 MultiMesh (每次增加100个实例)
## 5. 集成 VFXManager3D 对象池 (命中/爆炸粒子)
extends Node3D

# ============================================================
# 配置
# ============================================================
@export var initial_projectiles: int = 1000
@export var expand_increment: int = 100
@export var max_projectiles: int = 50000 # 高端设备上限
@export var mesh_size: float = 0.2

# ============================================================
# 引用
# ============================================================
var mm_instance: MultiMeshInstance3D
var _material: ShaderMaterial
var _current_capacity: int = 0

# 预热粒子系统
var _hit_spark_prefab: PackedScene
var _explosion_prefab: PackedScene

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_current_capacity = initial_projectiles
	_setup_multimesh()
	_setup_vfx_pools()

func _setup_multimesh() -> void:
	if mm_instance:
		mm_instance.queue_free()
		
	mm_instance = MultiMeshInstance3D.new()
	mm_instance.name = "ProjectileMultiMesh"
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.instance_count = _current_capacity
	mm.visible_instance_count = 0
	
	# 使用 QuadMesh 作为弹体基础
	var quad := QuadMesh.new()
	quad.size = Vector2(mesh_size, mesh_size)
	quad.orientation = PlaneMesh.FACE_Y  # 面向Y轴，确保俯视正交摄像机下可见
	mm.mesh = quad
	
	mm_instance.multimesh = mm
	
	# 设置统一材质
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/spell_material_3d.gdshader")
	mm_instance.material_override = _material
	
	add_child(mm_instance)

func _setup_vfx_pools() -> void:
	# 假设存在这些预制体，实际项目中需要替换为真实路径
	# _hit_spark_prefab = load("res://scenes/vfx/hit_spark_3d.tscn")
	# _explosion_prefab = load("res://scenes/vfx/explosion_3d.tscn")
	
	# 注册到全局对象池
	# if PoolManager and _hit_spark_prefab:
	# 	PoolManager.register_pool("hit_sparks_3d", _hit_spark_prefab, 50, 200)
	# if PoolManager and _explosion_prefab:
	# 	PoolManager.register_pool("explosions_3d", _explosion_prefab, 20, 100)
	pass

# ============================================================
# 渲染更新
# ============================================================

## 批量更新弹体位置（由 2D 弹幕系统调用）
func update_projectiles(projectile_data: Array) -> void:
	var count = projectile_data.size()
	
	# 弹性扩容
	if count > _current_capacity:
		_expand_multimesh(count)
		
	var mm = mm_instance.multimesh
	mm.visible_instance_count = min(count, _current_capacity)
	
	var gve = get_node_or_null("/root/GlobalVisualEnvironment3D")
	
	for i in range(mm.visible_instance_count):
		var data = projectile_data[i]
		var pos_2d = data.get("position", Vector2.ZERO)
		var rot_2d = data.get("rotation", 0.0)
		var color = data.get("color", Color.WHITE)
		
		# 解析 vfx_combinator 传递的 shader_params
		var shader_params = data.get("shader_params", {})
		var custom = Color(
			shader_params.get("base_color_index", 0.0),
			shader_params.get("emission_multiplier", 1.0),
			shader_params.get("timbre_texture_mask", 0.0),
			shader_params.get("distortion_glitch", 0.0)
		)
		
		# 转换到 3D 空间
		var pos_3d = gve.to_3d(pos_2d) if gve else Vector3(pos_2d.x/100.0, 0, pos_2d.y/100.0)
		
		var t = Transform3D()
		t = t.rotated(Vector3.UP, -rot_2d)
		
		# 应用缩放
		var scale_3d = data.get("scale", Vector3.ONE)
		t = t.scaled(scale_3d)
		
		t.origin = pos_3d
		
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, color)
		mm.set_instance_custom_data(i, custom)

## 弹性扩容 MultiMesh
func _expand_multimesh(target_count: int) -> void:
	if _current_capacity >= max_projectiles:
		return # 达到硬上限
		
	# 计算需要扩容的次数
	var needed = target_count - _current_capacity
	var increments = ceil(float(needed) / expand_increment)
	var new_capacity = min(_current_capacity + increments * expand_increment, max_projectiles)
	
	if new_capacity > _current_capacity:
		# 保存旧数据
		var old_mm = mm_instance.multimesh
		var old_count = old_mm.visible_instance_count
		
		# 创建新 MultiMesh
		var new_mm = MultiMesh.new()
		new_mm.transform_format = MultiMesh.TRANSFORM_3D
		new_mm.use_colors = true
		new_mm.use_custom_data = true
		new_mm.instance_count = new_capacity
		new_mm.mesh = old_mm.mesh
		
		# 复制旧数据 (可选，因为每帧都会全量更新，这里其实可以跳过)
		# for i in range(old_count):
		# 	new_mm.set_instance_transform(i, old_mm.get_instance_transform(i))
		# 	new_mm.set_instance_color(i, old_mm.get_instance_color(i))
		# 	new_mm.set_instance_custom_data(i, old_mm.get_instance_custom_data(i))
			
		mm_instance.multimesh = new_mm
		_current_capacity = new_capacity
		print("ProjectileManager3D: Expanded capacity to ", _current_capacity)

# ============================================================
# 特效触发
# ============================================================

## 触发命中特效
func spawn_hit_spark(pos_2d: Vector2, color: Color, particle_type: String = "default") -> void:
	# 实际项目中应从 PoolManager 获取
	# var spark = PoolManager.acquire("hit_sparks_3d")
	# if spark:
	#     var gve = get_node_or_null("/root/GlobalVisualEnvironment3D")
	#     spark.global_position = gve.to_3d(pos_2d) if gve else Vector3(pos_2d.x/100.0, 0, pos_2d.y/100.0)
	#     # 设置颜色等参数
	#     spark.emit()
	pass

## 触发爆炸特效
func spawn_explosion(pos_2d: Vector2, color: Color, scale: float = 1.0) -> void:
	# 实际项目中应从 PoolManager 获取
	pass
