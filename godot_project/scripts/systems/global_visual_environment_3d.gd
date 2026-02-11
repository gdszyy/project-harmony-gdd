## global_visual_environment_3d.gd
## 全局 3D 视觉环境管理器
##
## 职责：
## 1. 初始化 3D 场景核心节点（Camera3D, WorldEnvironment, Lights）
## 2. 管理 3D 后处理效果（Glow, Tonemapping, SSR, SSAO）
## 3. 维护 3D 全局 Shader 参数
## 4. 提供 2D 坐标到 3D 空间的映射
extends Node3D

# ============================================================
# 状态与引用
# ============================================================
var camera: Camera3D
var world_environment: WorldEnvironment
var directional_light: DirectionalLight3D
var main_env: Environment

var _current_chapter_color: Color = Color(0.0, 1.0, 0.83)
var _target_chapter_color: Color = Color(0.0, 1.0, 0.83)
var _beat_intensity: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_3d_environment()
	_connect_signals()

func _process(delta: float) -> void:
	# 更新全局 Shader 时间
	var time = Time.get_ticks_msec() / 1000.0
	RenderingServer.global_shader_parameter_set("global_time", time)
	
	# 节拍能量衰减
	_beat_intensity = lerpf(_beat_intensity, 0.0, delta * 4.0)
	RenderingServer.global_shader_parameter_set("beat_phase", _beat_intensity)
	
	# 章节颜色平滑插值
	_current_chapter_color = _current_chapter_color.lerp(_target_chapter_color, delta * 2.0)
	RenderingServer.global_shader_parameter_set("chapter_color", _current_chapter_color)
	
	# 动态调整 Glow 强度
	if main_env:
		main_env.glow_intensity = 0.8 + _beat_intensity * 0.5

# ============================================================
# 环境搭建
# ============================================================

func _setup_3d_environment() -> void:
	# 1. 创建摄像机 (正交投影)
	camera = Camera3D.new()
	camera.name = "MainCamera3D"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0  # 对应 2D 视野大小
	camera.position = Vector3(0, 20, 0)
	camera.rotation_degrees = Vector3(-90, 0, 0) # 垂直俯视
	add_child(camera)
	
	# 2. 创建环境
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment3D"
	main_env = Environment.new()
	
	# 背景配置
	main_env.background_mode = Environment.BG_COLOR
	main_env.background_color = Color(0.02, 0.02, 0.05)
	
	# 核心：Glow (3D 管线原生支持)
	main_env.glow_enabled = true
	main_env.glow_levels_1 = 1.0
	main_env.glow_levels_3 = 1.0
	main_env.glow_levels_5 = 1.0
	main_env.glow_intensity = 0.8
	main_env.glow_strength = 1.0
	main_env.glow_bloom = 0.2
	main_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	main_env.glow_hdr_threshold = 0.8
	
	# 色彩映射
	main_env.tonemap_mode = Environment.TONE_MAP_ACES
	main_env.tonemap_exposure = 1.0
	main_env.tonemap_white = 1.0
	
	# 屏幕空间效果 (可选)
	main_env.ssr_enabled = false
	main_env.ssao_enabled = true
	main_env.ssao_intensity = 2.0
	
	# 调整
	main_env.adjustment_enabled = true
	main_env.adjustment_contrast = 1.1
	main_env.adjustment_saturation = 1.2
	
	world_environment.environment = main_env
	add_child(world_environment)
	
	# 3. 创建基础光照
	directional_light = DirectionalLight3D.new()
	directional_light.name = "GlobalLight"
	directional_light.light_energy = 0.5
	directional_light.light_color = Color(0.8, 0.9, 1.0)
	directional_light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(directional_light)

# ============================================================
# 信号与交互
# ============================================================

func _connect_signals() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("beat_tick"):
		gm.beat_tick.connect(_on_beat)
	
	var cm = get_node_or_null("/root/ChapterManager")
	if cm and cm.has_signal("chapter_started"):
		cm.chapter_started.connect(_on_chapter_started)

func _on_beat(_beat_count: int) -> void:
	_beat_intensity = 1.0

func _on_chapter_started(chapter: int, _name: String) -> void:
	# 章节色彩定义
	var colors = [
		Color(0.0, 1.0, 0.83), # Ch0
		Color(0.6, 0.3, 0.8), # Ch1
		Color(1.0, 0.8, 0.3), # Ch2
		Color(1.0, 0.4, 0.6), # Ch3
		Color(0.8, 0.2, 0.2), # Ch4
		Color(0.2, 0.6, 1.0), # Ch5
		Color(0.0, 1.0, 0.3)  # Ch6
	]
	if chapter < colors.size():
		_target_chapter_color = colors[chapter]

# ============================================================
# 坐标转换接口 (2D -> 3D)
# ============================================================

## 将 2D 游戏逻辑坐标转换为 3D 世界坐标 (Y=0 平面)
func to_3d(pos_2d: Vector2) -> Vector3:
	# 假设 2D 坐标 100 像素对应 3D 1 单位
	return Vector3(pos_2d.x / 100.0, 0, pos_2d.y / 100.0)

## 将 3D 世界坐标投影回 2D 屏幕坐标
func to_2d(pos_3d: Vector3) -> Vector2:
	if camera:
		return camera.unproject_position(pos_3d)
	return Vector2.ZERO
