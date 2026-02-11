## chapter_visual_manager.gd
## 章节视觉管理器
##
## 职责：
## 1. 根据章节配置动态切换地面 Shader
## 2. 管理章节特有的持续性环境特效
## 3. 实现章节间的视觉过渡动画
## 4. 响应特殊机制的视觉化需求
extends Node2D

# ============================================================
# 配置
# ============================================================

## 章节地面 Shader 路径映射
const CHAPTER_GROUND_SHADERS: Dictionary = {
	0: "res://shaders/chapters/ch1_chladni_ground.gdshader",
	1: "res://shaders/chapters/ch2_cathedral_ground.gdshader",
	2: "res://shaders/chapters/ch3_baroque_ground.gdshader",
	3: "res://shaders/chapters/ch4_rococo_ground.gdshader",
	4: "res://shaders/chapters/ch5_romantic_ground.gdshader",
	5: "res://shaders/chapters/ch6_jazz_ground.gdshader",
	6: "res://shaders/chapters/ch7_digital_ground.gdshader",
}

## 章节色彩方案
const CHAPTER_COLORS: Dictionary = {
	0: { "primary": Color(0.9, 0.85, 0.6), "secondary": Color(0.3, 0.25, 0.15), "accent": Color(1.0, 0.95, 0.7) },
	1: { "primary": Color(0.2, 0.1, 0.4), "secondary": Color(0.6, 0.3, 0.8), "accent": Color(0.9, 0.7, 1.0) },
	2: { "primary": Color(0.7, 0.5, 0.2), "secondary": Color(0.3, 0.2, 0.1), "accent": Color(1.0, 0.8, 0.3) },
	3: { "primary": Color(0.9, 0.7, 0.8), "secondary": Color(0.5, 0.3, 0.5), "accent": Color(1.0, 0.85, 0.9) },
	4: { "primary": Color(0.15, 0.1, 0.3), "secondary": Color(0.5, 0.1, 0.2), "accent": Color(0.8, 0.3, 0.4) },
	5: { "primary": Color(0.1, 0.05, 0.15), "secondary": Color(0.8, 0.5, 0.1), "accent": Color(0.0, 0.8, 1.0) },
	6: { "primary": Color(0.02, 0.02, 0.05), "secondary": Color(0.0, 1.0, 0.3), "accent": Color(1.0, 0.0, 0.5) },
}

## 过渡动画时长
const TRANSITION_DURATION: float = 3.0

# ============================================================
# 节点引用
# ============================================================
var _ground_rect: ColorRect = null
var _ground_material: ShaderMaterial = null
var _env_vfx_container: Node2D = null
var _transition_overlay: ColorRect = null

# ============================================================
# 状态
# ============================================================
var _current_chapter: int = -1
var _is_transitioning: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_create_ground_layer()
	_create_env_vfx_container()
	_create_transition_overlay()
	_connect_signals()

func _connect_signals() -> void:
	# 尝试通过 Autoload 路径连接 ChapterManager 信号
	var cm = get_node_or_null("/root/ChapterManager")
	if cm == null:
		# 尝试通过场景树查找
		cm = _find_node_by_class("ChapterManager")
	
	if cm:
		if cm.has_signal("chapter_started"):
			cm.chapter_started.connect(_on_chapter_started)
		if cm.has_signal("chapter_transition_started"):
			cm.chapter_transition_started.connect(_on_transition_started)
		if cm.has_signal("transition_progress_updated"):
			cm.transition_progress_updated.connect(_on_transition_progress)
		if cm.has_signal("chapter_transition_completed"):
			cm.chapter_transition_completed.connect(_on_transition_completed)
		if cm.has_signal("special_mechanic_activated"):
			cm.special_mechanic_activated.connect(_on_mechanic_activated)
		if cm.has_signal("special_mechanic_deactivated"):
			cm.special_mechanic_deactivated.connect(_on_mechanic_deactivated)
		if cm.has_signal("boss_spawned"):
			cm.boss_spawned.connect(_on_boss_spawned)

func _find_node_by_class(class_name_str: String) -> Node:
	# 辅助函数：在场景树中查找指定类名的节点
	var root = get_tree().root
	return _search_children(root, class_name_str)

func _search_children(node: Node, class_name_str: String) -> Node:
	if node.get_class() == class_name_str or node.name == class_name_str:
		return node
	for child in node.get_children():
		var result = _search_children(child, class_name_str)
		if result:
			return result
	return null

# ============================================================
# 初始化
# ============================================================

func _create_ground_layer() -> void:
	_ground_rect = ColorRect.new()
	_ground_rect.name = "GroundShaderRect"
	_ground_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ground_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground_rect.z_index = -100  # 确保在最底层
	# 初始使用第一章 Shader（如果存在）
	_load_ground_shader(0)
	add_child(_ground_rect)

func _create_env_vfx_container() -> void:
	_env_vfx_container = Node2D.new()
	_env_vfx_container.name = "EnvVFXContainer"
	_env_vfx_container.z_index = -50  # 在地面之上，实体之下
	add_child(_env_vfx_container)

func _create_transition_overlay() -> void:
	_transition_overlay = ColorRect.new()
	_transition_overlay.name = "TransitionOverlay"
	_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_overlay.color = Color(0, 0, 0, 0)  # 初始透明
	_transition_overlay.z_index = 90  # 在大多数元素之上
	_transition_overlay.visible = false
	add_child(_transition_overlay)

# ============================================================
# 地面 Shader 管理
# ============================================================

func _load_ground_shader(chapter: int) -> void:
	var shader_path: String = CHAPTER_GROUND_SHADERS.get(chapter, "")
	if shader_path.is_empty():
		# 回退到默认的 pulsing_grid
		shader_path = "res://shaders/pulsing_grid.gdshader"

	var shader = load(shader_path)
	if shader:
		_ground_material = ShaderMaterial.new()
		_ground_material.shader = shader

		# 设置章节色彩参数
		var colors: Dictionary = CHAPTER_COLORS.get(chapter, {})
		if not colors.is_empty():
			_ground_material.set_shader_parameter("primary_color",
				colors.get("primary", Color.WHITE))
			_ground_material.set_shader_parameter("secondary_color",
				colors.get("secondary", Color.GRAY))
			_ground_material.set_shader_parameter("accent_color",
				colors.get("accent", Color.WHITE))

		_ground_rect.material = _ground_material
	else:
		push_warning("ChapterVisualManager: Failed to load shader: %s" % shader_path)

func _crossfade_ground_shader(new_chapter: int, duration: float = 2.0) -> void:
	# 保存旧材质的引用
	var old_material := _ground_material

	# 加载新 Shader
	_load_ground_shader(new_chapter)

	# 如果有旧材质，执行交叉淡入淡出
	if old_material and _ground_material:
		# 新材质从透明开始
		_ground_material.set_shader_parameter("fade_alpha", 0.0)

		var tween := create_tween()
		tween.tween_method(func(t: float):
			if _ground_material:
				_ground_material.set_shader_parameter("fade_alpha", t)
		, 0.0, 1.0, duration)

# ============================================================
# 章节过渡
# ============================================================

func _on_chapter_started(chapter: int, _chapter_name: String) -> void:
	if _current_chapter == chapter:
		return

	var is_first_chapter := _current_chapter == -1
	_current_chapter = chapter

	if is_first_chapter:
		_load_ground_shader(chapter)
	else:
		_crossfade_ground_shader(chapter)

	# 清理旧章节的环境特效
	_clear_env_vfx()

	# 加载新章节的环境特效
	_setup_chapter_env_vfx(chapter)

func _on_transition_started(_from_chapter: int, to_chapter: int) -> void:
	_is_transitioning = true
	_transition_overlay.visible = true

	# 过渡动画：先淡入黑幕，切换内容，再淡出
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "color:a", 0.8, TRANSITION_DURATION * 0.4)
	tween.tween_callback(func():
		_crossfade_ground_shader(to_chapter, TRANSITION_DURATION * 0.3)
	)
	tween.tween_property(_transition_overlay, "color:a", 0.0, TRANSITION_DURATION * 0.3)
	tween.tween_callback(func():
		_transition_overlay.visible = false
		_is_transitioning = false
	)

func _on_transition_progress(progress: float) -> void:
	# 可用于驱动额外的过渡效果
	if _ground_material:
		_ground_material.set_shader_parameter("transition_progress", progress)

func _on_transition_completed(_new_chapter: int) -> void:
	_is_transitioning = false
	_transition_overlay.visible = false

# ============================================================
# 环境特效管理
# ============================================================

func _setup_chapter_env_vfx(chapter: int) -> void:
	match chapter:
		0:  # 第一章：毕达哥拉斯 — 浮动几何粒子
			_spawn_floating_geometry_particles()
		1:  # 第二章：中世纪 — 光柱效果
			_spawn_light_shafts()
		2:  # 第三章：巴洛克 — 齿轮装饰
			_spawn_clockwork_decorations()
		3:  # 第四章：洛可可 — 花瓣飘落
			_spawn_petal_particles()
		4:  # 第五章：浪漫主义 — 风暴云层
			_spawn_storm_clouds()
		5:  # 第六章：爵士 — 烟雾效果
			_spawn_smoke_effect()
		6:  # 第七章：数字 — 数据流
			_spawn_data_streams()

func _clear_env_vfx() -> void:
	for child in _env_vfx_container.get_children():
		child.queue_free()

func _spawn_floating_geometry_particles() -> void:
	# 使用 GPUParticles2D 创建浮动的几何粒子
	var particles := GPUParticles2D.new()
	particles.amount = 30
	particles.lifetime = 8.0
	particles.preprocess = 4.0

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(600, 400, 0)
	material.direction = Vector3(0, -1, 0)
	material.spread = 30.0
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	material.gravity = Vector3(0, 0, 0)
	material.angular_velocity_min = -30.0
	material.angular_velocity_max = 30.0
	material.scale_min = 0.5
	material.scale_max = 2.0

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.9, 0.85, 0.6, 0.0))
	gradient.add_point(0.2, Color(0.9, 0.85, 0.6, 0.3))
	gradient.add_point(0.8, Color(0.9, 0.85, 0.6, 0.3))
	gradient.set_color(1, Color(0.9, 0.85, 0.6, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	material.color_ramp = color_ramp

	particles.process_material = material
	_env_vfx_container.add_child(particles)

func _spawn_light_shafts() -> void:
	# 第二章：从上方射下的光柱效果
	for i in range(5):
		var shaft := Polygon2D.new()
		var x := randf_range(-400, 400)
		var width := randf_range(30, 80)
		shaft.polygon = PackedVector2Array([
			Vector2(x - width * 0.5, -500),
			Vector2(x + width * 0.5, -500),
			Vector2(x + width * 1.5, 500),
			Vector2(x - width * 1.5, 500),
		])
		shaft.color = Color(0.6, 0.3, 0.8, 0.05)

		# 缓慢摆动动画
		var tween := shaft.create_tween().set_loops()
		tween.tween_property(shaft, "position:x", randf_range(-20, 20), randf_range(3.0, 6.0))
		tween.tween_property(shaft, "position:x", randf_range(-20, 20), randf_range(3.0, 6.0))

		_env_vfx_container.add_child(shaft)

func _spawn_clockwork_decorations() -> void:
	# 第三章：巴洛克齿轮装饰
	for i in range(6):
		var gear := _create_gear_polygon(randf_range(40, 100), randi_range(8, 16))
		gear.position = Vector2(randf_range(-500, 500), randf_range(-400, 400))
		gear.color = Color(0.7, 0.5, 0.2, 0.08)

		# 旋转动画
		var speed := randf_range(0.3, 1.0) * (1.0 if randi() % 2 == 0 else -1.0)
		var tween := gear.create_tween().set_loops()
		tween.tween_property(gear, "rotation", gear.rotation + TAU * sign(speed), abs(TAU / speed))

		_env_vfx_container.add_child(gear)

func _spawn_petal_particles() -> void:
	# 第四章：洛可可花瓣飘落
	var particles := GPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 6.0
	particles.preprocess = 3.0

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(600, 10, 0)
	material.emission_shape_offset = Vector3(0, -400, 0)
	material.direction = Vector3(0.3, 1, 0)
	material.spread = 20.0
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 40.0
	material.gravity = Vector3(0, 10, 0)
	material.angular_velocity_min = -90.0
	material.angular_velocity_max = 90.0
	material.scale_min = 1.0
	material.scale_max = 3.0

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.9, 0.7, 0.8, 0.0))
	gradient.add_point(0.1, Color(0.9, 0.7, 0.8, 0.4))
	gradient.add_point(0.9, Color(1.0, 0.85, 0.9, 0.3))
	gradient.set_color(1, Color(1.0, 0.85, 0.9, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	material.color_ramp = color_ramp

	particles.process_material = material
	_env_vfx_container.add_child(particles)

func _spawn_storm_clouds() -> void:
	# 第五章：浪漫主义风暴云层
	for i in range(8):
		var cloud := Polygon2D.new()
		var cx := randf_range(-500, 500)
		var cy := randf_range(-400, -200)
		var size := randf_range(80, 200)
		# 简化的云形状
		var points := PackedVector2Array()
		for j in range(12):
			var angle := TAU / 12.0 * j
			var r := size * (0.7 + randf_range(0, 0.3))
			points.append(Vector2(cx + cos(angle) * r, cy + sin(angle) * r * 0.5))
		cloud.polygon = points
		cloud.color = Color(0.15, 0.1, 0.3, 0.1)

		# 缓慢漂移
		var tween := cloud.create_tween().set_loops()
		tween.tween_property(cloud, "position:x", randf_range(-30, 30), randf_range(4.0, 8.0))
		tween.tween_property(cloud, "position:x", randf_range(-30, 30), randf_range(4.0, 8.0))

		_env_vfx_container.add_child(cloud)

func _spawn_smoke_effect() -> void:
	# 第六章：爵士烟雾效果
	var particles := GPUParticles2D.new()
	particles.amount = 15
	particles.lifetime = 5.0
	particles.preprocess = 2.5

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(500, 300, 0)
	material.direction = Vector3(0, -1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	material.gravity = Vector3(0, -5, 0)
	material.scale_min = 3.0
	material.scale_max = 8.0

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.1, 0.05, 0.15, 0.0))
	gradient.add_point(0.3, Color(0.1, 0.05, 0.15, 0.08))
	gradient.add_point(0.7, Color(0.1, 0.05, 0.15, 0.06))
	gradient.set_color(1, Color(0.1, 0.05, 0.15, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	material.color_ramp = color_ramp

	particles.process_material = material
	_env_vfx_container.add_child(particles)

func _spawn_data_streams() -> void:
	# 第七章：垂直数据流（Matrix 风格）
	for i in range(8):
		var stream := Line2D.new()
		stream.width = 2.0
		stream.default_color = Color(0.0, 1.0, 0.3, 0.3)
		var x := randf_range(-500, 500)
		for j in range(20):
			stream.add_point(Vector2(x, -400 + j * 40))
		_env_vfx_container.add_child(stream)

		# 向下滚动动画
		var tween := stream.create_tween().set_loops()
		tween.tween_property(stream, "position:y", 40.0, randf_range(0.5, 1.5))
		tween.tween_callback(func():
			stream.position.y = 0.0
			stream.modulate.a = randf_range(0.1, 0.5)
		)

# ============================================================
# 特殊机制视觉化
# ============================================================

func _on_mechanic_activated(mechanic_name: String, _params: Dictionary) -> void:
	match mechanic_name:
		"swing_grid":
			_activate_swing_grid_visual(_params)
		"waveform_warfare":
			_activate_waveform_visual(_params)

func _on_mechanic_deactivated(_mechanic_name: String) -> void:
	# 清理特殊机制的视觉效果
	pass

func _activate_swing_grid_visual(_params: Dictionary) -> void:
	# 爵士章节的摇摆网格视觉：聚光灯效果
	if _ground_material:
		_ground_material.set_shader_parameter("swing_mode", true)

func _activate_waveform_visual(_params: Dictionary) -> void:
	# 数字章节的波形战争视觉
	if _ground_material:
		_ground_material.set_shader_parameter("waveform_mode", true)

# ============================================================
# Boss 出场视觉
# ============================================================

func _on_boss_spawned(_boss_node: Node) -> void:
	# Boss 出场时的全屏视觉效果
	_transition_overlay.visible = true
	_transition_overlay.color = Color(1, 1, 1, 0)

	var tween := create_tween()
	# 白色闪光
	tween.tween_property(_transition_overlay, "color:a", 0.6, 0.1)
	tween.tween_property(_transition_overlay, "color:a", 0.0, 0.5)
	tween.tween_callback(func():
		_transition_overlay.visible = false
	)

	# 通知 GlobalVisualEnvironment 进入 Boss 模式
	var gve := get_node_or_null("/root/GlobalVisualEnvironment")
	if gve and gve.has_method("enter_boss_mode"):
		gve.enter_boss_mode()

# ============================================================
# 公共接口
# ============================================================

## 获取当前章节索引
func get_current_chapter() -> int:
	return _current_chapter

## 获取当前地面材质（供外部系统修改参数）
func get_ground_material() -> ShaderMaterial:
	return _ground_material

## 手动触发章节切换（用于测试）
func force_chapter_switch(chapter: int) -> void:
	_on_chapter_started(chapter, "Chapter %d" % (chapter + 1))

# ============================================================
# 工具函数
# ============================================================

func _create_gear_polygon(radius: float, teeth: int) -> Polygon2D:
	var poly := Polygon2D.new()
	var points := PackedVector2Array()
	var inner_radius := radius * 0.7
	for i in range(teeth * 2):
		var angle := (TAU / (teeth * 2)) * i
		var r := radius if i % 2 == 0 else inner_radius
		points.append(Vector2.from_angle(angle) * r)
	poly.polygon = points
	return poly
