## render_bridge_3d.gd
## 2.5D 渲染桥接层
##
## 核心职责：
## 1. 在 2D 游戏逻辑之上叠加一个 3D 渲染场景
## 2. 管理 SubViewport 中的 3D 渲染管线（Camera3D + WorldEnvironment + Lights）
## 3. 将 2D 实体位置实时同步到 3D 空间的 Sprite3D / MultiMesh
## 4. 提供统一的 2D↔3D 坐标转换接口
##
## 设计原则：
## - 2D 物理和碰撞系统完全保留，不做任何迁移
## - 3D 层仅负责渲染（Glow/Bloom、真实光照、3D 粒子、体积雾）
## - 通过 SubViewportContainer 将 3D 渲染结果叠加到 2D 画面上
## - 所有现有的 2D 脚本无需修改即可运行
extends Node

# ============================================================
# 信号
# ============================================================
signal render_bridge_ready

# ============================================================
# 配置
# ============================================================

## 2D 像素到 3D 单位的换算比例 (100 像素 = 1 个 3D 单位)
@export var pixels_per_unit: float = 100.0

## 正交摄像机可视范围 (3D 单位)
@export var camera_ortho_size: float = 12.0

## 摄像机高度
@export var camera_height: float = 20.0

## 摄像机跟随平滑速度
@export var camera_follow_speed: float = 5.0

## 是否启用 3D 渲染层（可在运行时切换，用于性能调试）
@export var enable_3d_layer: bool = true

# ============================================================
# 3D 场景节点引用
# ============================================================
var _viewport_container: SubViewportContainer
var _sub_viewport: SubViewport
var _camera_3d: Camera3D
var _world_env: WorldEnvironment
var _main_env: Environment
var _directional_light: DirectionalLight3D
var _ground_layer: Node3D
var _entity_layer: Node3D
var _vfx_layer: Node3D
var _chapter_visual_mgr: Node3D

# ============================================================
# 3D 渲染代理
# ============================================================

## 玩家的 3D 渲染代理
var _player_proxy_3d: Node3D

## Issue #59: 玩家的谐振调式化身管理器
var _harmonic_avatar: HarmonicAvatarManager = null

## 弹幕的 3D MultiMesh 渲染器
var _projectile_renderer_3d: Node3D

## 敌人 3D 代理映射表 { enemy_node_2d: proxy_3d }
var _enemy_proxies: Dictionary = {}

# ============================================================
# 跟踪目标
# ============================================================
var _follow_target_2d: Node2D  ## 通常是 Player

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	if enable_3d_layer:
		_build_3d_scene()
		render_bridge_ready.emit()

func _process(delta: float) -> void:
	if not enable_3d_layer or not _sub_viewport:
		return

	# 1. 更新摄像机跟随
	_update_camera_follow(delta)

	# 2. 同步玩家位置到 3D 代理
	_sync_player_proxy()

	# 3. 同步敌人位置到 3D 代理
	_sync_enemy_proxies()

	# 4. 同步普通敌人 MultiMesh 批量渲染 (Issue #35 修复)
	_sync_enemy_multimesh()

# ============================================================
# 3D 场景构建
# ============================================================

func _build_3d_scene() -> void:
	# --- SubViewportContainer (全屏覆盖，透明混合) ---
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "RenderBridge3DContainer"
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 设置为透明混合，使 3D 渲染叠加在 2D 之上而不遮挡 2D 内容
	# 修复 Issue #35：确保 SubViewportContainer 不会完全遮挡下层 2D 渲染
	_viewport_container.self_modulate = Color(1, 1, 1, 1)
	# 启用透明混合模式，确保 3D SubViewport 的透明背景能正确透过
	_viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# ★ 修复弹体不可见：使用 Premultiplied Alpha 混合模式
	# Godot Issue #28141: Glow 后处理会污染透明通道，导致 SubViewportContainer
	# 在默认 Mix 混合模式下遮挡下层 2D 内容（包括弹体 MultiMesh）
	# 使用 CanvasItemMaterial + BLEND_MODE_PREMULT_ALPHA 确保透明区域不遮挡
	var overlay_material := CanvasItemMaterial.new()
	overlay_material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_viewport_container.material = overlay_material

	# --- SubViewport ---
	_sub_viewport = SubViewport.new()
	_sub_viewport.name = "RenderBridge3DViewport"
	_sub_viewport.size = get_viewport().get_visible_rect().size
	_sub_viewport.transparent_bg = true
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_viewport.own_world_3d = true  # 独立的 3D 世界，不与主场景冲突

	_viewport_container.add_child(_sub_viewport)

	# --- 3D 摄像机 (正交投影，垂直俯视) ---
	_camera_3d = Camera3D.new()
	_camera_3d.name = "Camera3D_Ortho"
	_camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera_3d.size = camera_ortho_size
	_camera_3d.near = 0.1
	_camera_3d.far = 100.0
	_camera_3d.position = Vector3(0, camera_height, 0)
	_camera_3d.rotation_degrees = Vector3(-90, 0, 0)  # 垂直俯视
	_sub_viewport.add_child(_camera_3d)

	# --- WorldEnvironment ---
	_setup_world_environment()

	# --- 方向光 ---
	_directional_light = DirectionalLight3D.new()
	_directional_light.name = "GlobalDirectionalLight"
	_directional_light.light_energy = 0.3
	_directional_light.light_color = Color(0.8, 0.9, 1.0)
	_directional_light.rotation_degrees = Vector3(-45, 45, 0)
	_directional_light.shadow_enabled = false  # 俯视角不需要阴影
	_sub_viewport.add_child(_directional_light)

	# --- 分层节点 ---
	_ground_layer = Node3D.new()
	_ground_layer.name = "GroundLayer3D"
	_sub_viewport.add_child(_ground_layer)

	_entity_layer = Node3D.new()
	_entity_layer.name = "EntityLayer3D"
	_sub_viewport.add_child(_entity_layer)

	_vfx_layer = Node3D.new()
	_vfx_layer.name = "VFXLayer3D"
	_sub_viewport.add_child(_vfx_layer)

	# --- 章节视觉管理器 (3D) ---
	_setup_chapter_visual_manager()

	# --- 弹幕 3D 渲染器 ---
	_setup_projectile_renderer()

	# --- 普通敌人 MultiMesh 批量渲染器 (Issue #35 修复) ---
	_setup_enemy_multimesh()

	# --- 将 SubViewportContainer 添加到场景 ---
	# 它需要作为 CanvasLayer 的子节点，以确保在 2D 之上渲染
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "RenderBridge3DOverlay"
	overlay_layer.layer = 5  # 在 2D 游戏内容之上，HUD 之下
	overlay_layer.add_child(_viewport_container)
	add_child(overlay_layer)

	# 连接窗口大小变化信号
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _setup_world_environment() -> void:
	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnv3D"
	_main_env = Environment.new()

	# 背景：透明（让 2D 内容透过来）
	_main_env.background_mode = Environment.BG_COLOR
	_main_env.background_color = Color(0, 0, 0, 0)

	# 核心：Glow/Bloom (3D 管线原生支持)
	_main_env.glow_enabled = true
	_main_env.set_glow_level(1, 1.0)
	_main_env.set_glow_level(3, 0.8)
	_main_env.set_glow_level(5, 0.5)
	_main_env.glow_intensity = 0.8
	_main_env.glow_strength = 1.0
	_main_env.glow_bloom = 0.2
	_main_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_main_env.glow_hdr_threshold = 0.8

	# 色调映射
	_main_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_main_env.tonemap_exposure = 1.0

	# SSAO (增强纵深感)
	_main_env.ssao_enabled = false  # 默认关闭，可通过设置开启

	# 色彩调整
	_main_env.adjustment_enabled = true
	_main_env.adjustment_contrast = 1.1
	_main_env.adjustment_saturation = 1.2

	_world_env.environment = _main_env
	_sub_viewport.add_child(_world_env)

func _setup_chapter_visual_manager() -> void:
	# 实例化 ChapterVisualManager3D 到 3D 地面层
	var cvm_script = load("res://scripts/systems/chapter_visual_manager_3d.gd")
	if cvm_script:
		_chapter_visual_mgr = Node3D.new()
		_chapter_visual_mgr.set_script(cvm_script)
		_chapter_visual_mgr.name = "ChapterVisualManager3D"
		_ground_layer.add_child(_chapter_visual_mgr)

func _setup_projectile_renderer() -> void:
	# 实例化 ProjectileManager3D 到实体层
	var pm3d_script = load("res://scripts/systems/projectile_manager_3d.gd")
	if pm3d_script:
		_projectile_renderer_3d = Node3D.new()
		_projectile_renderer_3d.set_script(pm3d_script)
		_projectile_renderer_3d.name = "ProjectileRenderer3D"
		_entity_layer.add_child(_projectile_renderer_3d)

# ============================================================
# 坐标转换
# ============================================================

## 将 2D 游戏坐标转换为 3D 世界坐标 (Y=0 平面)
func to_3d(pos_2d: Vector2) -> Vector3:
	return Vector3(pos_2d.x / pixels_per_unit, 0, pos_2d.y / pixels_per_unit)

## 将 3D 世界坐标转换回 2D 游戏坐标
func to_2d(pos_3d: Vector3) -> Vector2:
	return Vector2(pos_3d.x * pixels_per_unit, pos_3d.z * pixels_per_unit)

## 将 2D 屏幕坐标转换为 3D 世界坐标（通过摄像机投影）
func screen_to_3d(screen_pos: Vector2) -> Vector3:
	if _camera_3d:
		return _camera_3d.project_position(screen_pos, camera_height)
	return Vector3.ZERO

# ============================================================
# 摄像机跟随
# ============================================================

## 设置摄像机跟随的 2D 目标节点（通常是 Player）
func set_follow_target(target: Node2D) -> void:
	_follow_target_2d = target

func _update_camera_follow(delta: float) -> void:
	if not _camera_3d or not _follow_target_2d:
		return
	if not is_instance_valid(_follow_target_2d):
		return

	var target_3d = to_3d(_follow_target_2d.global_position)
	var cam_target = Vector3(target_3d.x, camera_height, target_3d.z)
	_camera_3d.global_position = _camera_3d.global_position.lerp(cam_target, camera_follow_speed * delta)

# ============================================================
# 实体同步
# ============================================================

func _sync_player_proxy() -> void:
	if not _player_proxy_3d or not _follow_target_2d:
		return
	if not is_instance_valid(_follow_target_2d):
		return
	_player_proxy_3d.global_position = to_3d(_follow_target_2d.global_position)

func _sync_enemy_proxies() -> void:
	# 清理已失效的代理
	var to_remove: Array = []
	for enemy_2d in _enemy_proxies:
		if not is_instance_valid(enemy_2d):
			to_remove.append(enemy_2d)
		else:
			var proxy: Node3D = _enemy_proxies[enemy_2d]
			if is_instance_valid(proxy):
				proxy.global_position = to_3d(enemy_2d.global_position)

	for key in to_remove:
		var proxy = _enemy_proxies[key]
		if is_instance_valid(proxy):
			proxy.queue_free()
		_enemy_proxies.erase(key)

# ============================================================
# 玩家 3D 代理管理
# ============================================================

## 为 2D 玩家创建 3D 渲染代理
## Issue #59: 使用 HarmonicAvatarManager 替代硬编码几何体
func create_player_proxy(player_2d: Node2D) -> void:
	_follow_target_2d = player_2d

	_player_proxy_3d = Node3D.new()
	_player_proxy_3d.name = "PlayerProxy3D"

	# 核心光源（玩家发光）
	var point_light := OmniLight3D.new()
	point_light.name = "PlayerCoreLight"
	point_light.light_energy = 2.0
	point_light.light_color = Color(0.0, 1.0, 0.83)
	point_light.omni_range = 5.0
	point_light.omni_attenuation = 1.5
	_player_proxy_3d.add_child(point_light)

	# --- Issue #59: 创建 HarmonicAvatarManager 作为玩家 3D 化身 ---
	_harmonic_avatar = HarmonicAvatarManager.new()
	_harmonic_avatar.name = "HarmonicAvatar"
	_harmonic_avatar.skeleton_enabled = true
	_harmonic_avatar.rendering_enabled = true
	_player_proxy_3d.add_child(_harmonic_avatar)

	# 将化身管理器注册到 2D 玩家节点，供其他系统访问
	if player_2d.has_method("register_harmonic_avatar"):
		player_2d.register_harmonic_avatar(_harmonic_avatar)

	# 拖尾粒子（保留，作为移动拖尾补充）
	var trail_particles := GPUParticles3D.new()
	trail_particles.name = "PlayerTrail3D"
	trail_particles.amount = 16
	trail_particles.lifetime = 0.8
	trail_particles.emitting = true

	var trail_mat := ParticleProcessMaterial.new()
	trail_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	trail_mat.emission_sphere_radius = 0.1
	trail_mat.direction = Vector3(0, 1, 0)
	trail_mat.spread = 30.0
	trail_mat.initial_velocity_min = 0.5
	trail_mat.initial_velocity_max = 1.0
	trail_mat.gravity = Vector3(0, 0, 0)
	trail_mat.damping_min = 2.0
	trail_mat.damping_max = 4.0
	trail_mat.scale_min = 0.05
	trail_mat.scale_max = 0.15

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.0, 1.0, 0.83, 0.8))
	gradient.set_color(1, Color(0.0, 1.0, 0.83, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	trail_mat.color_ramp = color_ramp

	trail_particles.process_material = trail_mat
	_player_proxy_3d.add_child(trail_particles)

	_entity_layer.add_child(_player_proxy_3d)

## 更新玩家光源颜色（响应章节切换）
func update_player_light_color(color: Color) -> void:
	if _player_proxy_3d:
		var light = _player_proxy_3d.get_node_or_null("PlayerCoreLight")
		if light:
			var tween = create_tween()
			tween.tween_property(light, "light_color", color, 2.0)

# ============================================================
# 敌人 3D 代理管理
# ============================================================

## 为 2D 敌人创建 3D 渲染代理（带发光点光源 + 可见几何体）
func register_enemy_proxy(enemy_2d: Node2D, enemy_color: Color = Color.RED, is_elite: bool = false) -> void:
	if _enemy_proxies.has(enemy_2d):
		return

	var proxy := Node3D.new()
	proxy.name = "EnemyProxy3D_%d" % enemy_2d.get_instance_id()

	# 敌人发光光源
	var light := OmniLight3D.new()
	light.name = "EnemyGlow"
	light.light_energy = 1.0 if is_elite else 0.5
	light.light_color = enemy_color
	light.omni_range = 3.0 if is_elite else 2.0
	light.omni_attenuation = 2.0
	proxy.add_child(light)

	# 可见几何体（修复 Issue #35：敌人在 3D 层不可见）
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "EnemyMesh3D"
	if is_elite:
		# 精英敌人使用更大的菱形体
		var prism_mesh := PrismMesh.new()
		prism_mesh.size = Vector3(0.35, 0.35, 0.35)
		mesh_instance.mesh = prism_mesh
	else:
		# 普通敌人使用小方块
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.15, 0.15, 0.15)
		mesh_instance.mesh = box_mesh

	var enemy_mat := StandardMaterial3D.new()
	enemy_mat.albedo_color = enemy_color
	enemy_mat.emission_enabled = true
	enemy_mat.emission = enemy_color
	enemy_mat.emission_energy_multiplier = 2.5 if is_elite else 1.5
	enemy_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	enemy_mat.albedo_color.a = 0.85
	mesh_instance.material_override = enemy_mat
	proxy.add_child(mesh_instance)

	proxy.global_position = to_3d(enemy_2d.global_position)
	_entity_layer.add_child(proxy)
	_enemy_proxies[enemy_2d] = proxy

## 移除敌人 3D 代理
func unregister_enemy_proxy(enemy_2d: Node2D) -> void:
	if _enemy_proxies.has(enemy_2d):
		var proxy = _enemy_proxies[enemy_2d]
		if is_instance_valid(proxy):
			proxy.queue_free()
		_enemy_proxies.erase(enemy_2d)

# ============================================================
# 弹幕渲染同步
# ============================================================

## 将 2D 弹幕数据同步到 3D 渲染器
func sync_projectiles(projectile_data: Array) -> void:
	if _projectile_renderer_3d and _projectile_renderer_3d.has_method("update_projectiles"):
		_projectile_renderer_3d.update_projectiles(projectile_data)

# ============================================================
# 环境效果接口
# ============================================================

## 获取 3D 环境对象（供外部调整后处理参数）
func get_environment() -> Environment:
	return _main_env

## 设置 Glow 强度
func set_glow_intensity(intensity: float, duration: float = 0.5) -> void:
	if _main_env:
		var tween = create_tween()
		tween.tween_property(_main_env, "glow_intensity", intensity, duration)

## 重置 Glow 到默认值
func reset_glow(duration: float = 1.0) -> void:
	set_glow_intensity(0.8, duration)

## 进入 Boss 战模式（增强视觉效果）
func enter_boss_mode() -> void:
	if _main_env:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(_main_env, "adjustment_contrast", 1.3, 1.0)
		tween.tween_property(_main_env, "adjustment_saturation", 1.3, 1.0)
		tween.tween_property(_main_env, "glow_intensity", 1.2, 1.0)

## 退出 Boss 战模式
func exit_boss_mode() -> void:
	if _main_env:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(_main_env, "adjustment_contrast", 1.1, 2.0)
		tween.tween_property(_main_env, "adjustment_saturation", 1.2, 2.0)
		tween.tween_property(_main_env, "glow_intensity", 0.8, 2.0)

## 节拍脉冲（由 GameManager.beat_tick 驱动）
func on_beat_pulse(beat_index: int) -> void:
	if _main_env:
		# Glow 脉冲
		_main_env.glow_intensity = 1.2
		var tween = create_tween()
		tween.tween_property(_main_env, "glow_intensity", 0.8, 0.3)

	# 方向光脉冲
	if _directional_light:
		_directional_light.light_energy = 0.6
		var tween2 = create_tween()
		tween2.tween_property(_directional_light, "light_energy", 0.3, 0.3)

	# Issue #59: 转发节拍脉冲到 HarmonicAvatarManager
	if _harmonic_avatar and is_instance_valid(_harmonic_avatar):
		_harmonic_avatar.on_beat_pulse(beat_index)

## Issue #59: 获取玩家的谐振调式化身管理器
func get_harmonic_avatar() -> HarmonicAvatarManager:
	return _harmonic_avatar

# ============================================================
# VFX 接口
# ============================================================

## 在 3D 空间创建一次性爆发粒子（用于施法、死亡等）
func spawn_burst_particles(pos_2d: Vector2, color: Color, amount: int = 32) -> void:
	if not _vfx_layer:
		return

	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = 0.6
	particles.explosiveness = 1.0

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.1
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0
	mat.damping_min = 2.0
	mat.damping_max = 4.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 0.02
	mat.scale_max = 0.08

	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 1.0))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	particles.process_material = mat

	_vfx_layer.add_child(particles)
	particles.global_position = to_3d(pos_2d)
	particles.emitting = true

	# 自动清理
	get_tree().create_timer(1.5).timeout.connect(particles.queue_free)

# ============================================================
# 窗口大小响应
# ============================================================

func _on_viewport_size_changed() -> void:
	if _sub_viewport:
		_sub_viewport.size = get_viewport().get_visible_rect().size

# ============================================================
# 公共查询
# ============================================================

## 检查 3D 渲染层是否已就绪
func is_ready() -> bool:
	return _sub_viewport != null and _camera_3d != null

## 获取 3D 摄像机引用
func get_camera_3d() -> Camera3D:
	return _camera_3d

## 获取 VFX 层节点（供外部挂载自定义 3D 特效）
func get_vfx_layer() -> Node3D:
	return _vfx_layer

## 获取实体层节点
func get_entity_layer() -> Node3D:
	return _entity_layer

## 获取地面层节点
func get_ground_layer() -> Node3D:
	return _ground_layer

# ============================================================
# 普通敌人批量 3D 渲染（Issue #35 修复 — MultiMesh 方案）
# ============================================================

## MultiMeshInstance3D 用于批量渲染普通敌人的 3D 代理
var _enemy_multimesh_instance: MultiMeshInstance3D
var _enemy_multimesh: MultiMesh
## 追踪的普通敌人列表（弱引用）
var _tracked_normal_enemies: Array = []
## 批量渲染的最大实例数
const MAX_ENEMY_INSTANCES: int = 256

## 初始化普通敌人的 MultiMesh 批量渲染器
func _setup_enemy_multimesh() -> void:
	_enemy_multimesh = MultiMesh.new()
	_enemy_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_enemy_multimesh.use_colors = true
	_enemy_multimesh.instance_count = MAX_ENEMY_INSTANCES
	_enemy_multimesh.visible_instance_count = 0

	# 使用小立方体作为普通敌人的 3D 表现
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 0.12)

	var enemy_mat := StandardMaterial3D.new()
	enemy_mat.vertex_color_use_as_albedo = true
	enemy_mat.emission_enabled = true
	enemy_mat.emission_energy_multiplier = 1.5
	# 使用顶点颜色作为自发光色
	enemy_mat.emission = Color(1.0, 1.0, 1.0)
	enemy_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box.material = enemy_mat

	_enemy_multimesh.mesh = box

	_enemy_multimesh_instance = MultiMeshInstance3D.new()
	_enemy_multimesh_instance.name = "EnemyMultiMesh3D"
	_enemy_multimesh_instance.multimesh = _enemy_multimesh
	_entity_layer.add_child(_enemy_multimesh_instance)

## 注册普通敌人到 MultiMesh 批量渲染（轻量级，不创建独立 Node3D）
func register_normal_enemy(enemy_2d: Node2D, enemy_color: Color = Color(0.7, 0.3, 0.3)) -> void:
	if _tracked_normal_enemies.size() >= MAX_ENEMY_INSTANCES:
		return
	_tracked_normal_enemies.append({"node": enemy_2d, "color": enemy_color})

## 批量同步普通敌人位置到 MultiMesh（在 _process 中调用）
func _sync_enemy_multimesh() -> void:
	if _enemy_multimesh == null:
		return

	# 清理已失效的引用
	_tracked_normal_enemies = _tracked_normal_enemies.filter(
		func(entry): return is_instance_valid(entry["node"])
	)

	var count := mini(_tracked_normal_enemies.size(), MAX_ENEMY_INSTANCES)
	_enemy_multimesh.visible_instance_count = count

	for i in range(count):
		var entry: Dictionary = _tracked_normal_enemies[i]
		var enemy_2d: Node2D = entry["node"]
		var pos_3d := to_3d(enemy_2d.global_position)
		var xform := Transform3D(Basis(), pos_3d)
		_enemy_multimesh.set_instance_transform(i, xform)
		_enemy_multimesh.set_instance_color(i, entry["color"])
