## global_visual_environment_3d.gd
## 全局 3D 视觉环境管理器 (Autoload)
##
## 职责：
## 1. 维护全局 Shader 参数（时间、节拍、章节色彩）
## 2. 提供 2D 坐标到 3D 空间的映射接口
## 3. 管理章节色彩过渡
## 4. 提供节拍驱动的全局视觉脉冲
## 5. 作为统一的视觉环境接口，供所有视觉增强器调用
##
## v3.0 变更：
## - 不再自行创建 Camera3D / WorldEnvironment（由 RenderBridge3D 管理）
## - 专注于全局 Shader 参数维护和公共接口
## - 兼容 RenderBridge3D 的 SubViewport 架构
extends Node

# ============================================================
# 配置
# ============================================================

## Glow 配置
const GLOW_INTENSITY_BASE: float = 0.8
const BEAT_GLOW_BOOST: float = 0.3
const BEAT_GLOW_DECAY: float = 4.0
const COLOR_TRANSITION_DURATION: float = 3.0

## 2D 像素到 3D 单位的换算比例
const PIXELS_PER_UNIT: float = 100.0

# ============================================================
# 状态
# ============================================================
var _beat_glow_extra: float = 0.0
var _current_chapter_color: Color = Color(0.0, 1.0, 0.83)
var _target_chapter_color: Color = Color(0.0, 1.0, 0.83)
var _color_transition_progress: float = 1.0
var _global_time: float = 0.0
var _beat_phase: float = 0.0

## RenderBridge3D 引用（运行时由 main_game 设置）
var _render_bridge: Node = null

# ============================================================
# 章节色彩定义
# ============================================================
const CHAPTER_COLORS: Array = [
	Color(0.0, 1.0, 0.83),  # Ch0 毕达哥拉斯：谐振青
	Color(0.6, 0.3, 0.8),   # Ch1 中世纪：教堂紫
	Color(1.0, 0.8, 0.3),   # Ch2 巴洛克：金色
	Color(1.0, 0.4, 0.6),   # Ch3 洛可可：粉色
	Color(0.8, 0.2, 0.2),   # Ch4 浪漫主义：深红
	Color(0.2, 0.6, 1.0),   # Ch5 爵士：蓝色
	Color(0.0, 1.0, 0.3),   # Ch6 数字：矩阵绿
]

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_connect_signals()
	_update_global_shader_params()

func _process(delta: float) -> void:
	_global_time += delta

	# 节拍 Glow 衰减
	if _beat_glow_extra > 0.001:
		_beat_glow_extra = lerpf(_beat_glow_extra, 0.0, BEAT_GLOW_DECAY * delta)
	else:
		_beat_glow_extra = 0.0

	# 节拍相位衰减 (0→1 逐渐衰减)
	_beat_phase = lerpf(_beat_phase, 1.0, delta * 3.0)

	# 色彩过渡
	if _color_transition_progress < 1.0:
		_color_transition_progress += delta / COLOR_TRANSITION_DURATION
		_color_transition_progress = minf(_color_transition_progress, 1.0)
		_current_chapter_color = _current_chapter_color.lerp(
			_target_chapter_color,
			_ease_in_out(_color_transition_progress)
		)

	# 更新全局 Shader 参数
	_update_global_shader_params()

# ============================================================
# 信号连接
# ============================================================

func _connect_signals() -> void:
	# 连接节拍信号
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_signal("beat_tick"):
			gm.beat_tick.connect(_on_beat_tick)

	# 注意：章节信号通过 ChapterManager 连接
	# ChapterManager 不是 Autoload，所以在场景加载后才可用
	# 使用延迟连接
	call_deferred("_deferred_connect_chapter_signals")

func _deferred_connect_chapter_signals() -> void:
	# 尝试多种路径查找 ChapterManager
	var cm = get_node_or_null("/root/ChapterManager")
	if not cm:
		# 在场景树中搜索
		var tree = get_tree()
		if tree:
			var nodes = tree.get_nodes_in_group("chapter_manager")
			if nodes.size() > 0:
				cm = nodes[0]

	if cm:
		if cm.has_signal("chapter_started"):
			cm.chapter_started.connect(_on_chapter_started)
		if cm.has_signal("color_theme_changed"):
			cm.color_theme_changed.connect(_on_color_theme_changed)

# ============================================================
# 全局 Shader 参数
# ============================================================

func _update_global_shader_params() -> void:
	RenderingServer.global_shader_parameter_set("global_time", _global_time)
	RenderingServer.global_shader_parameter_set("beat_phase", _beat_phase)
	RenderingServer.global_shader_parameter_set(
		"chapter_color",
		Vector3(_current_chapter_color.r, _current_chapter_color.g, _current_chapter_color.b)
	)
	RenderingServer.global_shader_parameter_set("beat_glow_extra", _beat_glow_extra)

# ============================================================
# 信号回调
# ============================================================

func _on_chapter_started(chapter: int, _chapter_name: String) -> void:
	if chapter < CHAPTER_COLORS.size():
		_start_color_transition(CHAPTER_COLORS[chapter])

	# 通知 RenderBridge3D 更新玩家光源颜色
	if _render_bridge and _render_bridge.has_method("update_player_light_color"):
		if chapter < CHAPTER_COLORS.size():
			_render_bridge.update_player_light_color(CHAPTER_COLORS[chapter])

func _on_color_theme_changed(from_color: Color, to_color: Color, _progress: float) -> void:
	_target_chapter_color = to_color
	if _color_transition_progress >= 1.0:
		_current_chapter_color = from_color
		_color_transition_progress = 0.0

func _on_beat_tick(beat_index: int) -> void:
	_beat_glow_extra = BEAT_GLOW_BOOST
	_beat_phase = 0.0

	# 通知 RenderBridge3D 执行节拍脉冲
	if _render_bridge and _render_bridge.has_method("on_beat_pulse"):
		_render_bridge.on_beat_pulse(beat_index)

# ============================================================
# 公共接口
# ============================================================

## 设置 RenderBridge3D 引用
func set_render_bridge(bridge: Node) -> void:
	_render_bridge = bridge

## 获取当前章节主色
func get_chapter_color() -> Color:
	return _current_chapter_color

## 获取当前节拍相位 (0.0 ~ 1.0)
func get_beat_phase() -> float:
	return _beat_phase

## 手动设置 Glow 强度（用于 Boss 战等特殊场景）
func set_glow_override(intensity: float, duration: float = 0.5) -> void:
	if _render_bridge and _render_bridge.has_method("set_glow_intensity"):
		_render_bridge.set_glow_intensity(intensity, duration)

## 恢复默认 Glow
func reset_glow(duration: float = 1.0) -> void:
	if _render_bridge and _render_bridge.has_method("reset_glow"):
		_render_bridge.reset_glow(duration)

## Boss 战模式：增强对比度和饱和度
func enter_boss_mode() -> void:
	if _render_bridge and _render_bridge.has_method("enter_boss_mode"):
		_render_bridge.enter_boss_mode()

## 退出 Boss 战模式
func exit_boss_mode() -> void:
	if _render_bridge and _render_bridge.has_method("exit_boss_mode"):
		_render_bridge.exit_boss_mode()

## 将 2D 游戏坐标转换为 3D 世界坐标 (Y=0 平面)
func to_3d(pos_2d: Vector2) -> Vector3:
	return Vector3(pos_2d.x / PIXELS_PER_UNIT, 0, pos_2d.y / PIXELS_PER_UNIT)

## 将 3D 世界坐标转换回 2D 游戏坐标
func to_2d(pos_3d: Vector3) -> Vector2:
	return Vector2(pos_3d.x * PIXELS_PER_UNIT, pos_3d.z * PIXELS_PER_UNIT)

## 在 3D 空间创建一次性爆发粒子
func spawn_burst_particles(pos_2d: Vector2, color: Color, amount: int = 32) -> void:
	if _render_bridge and _render_bridge.has_method("spawn_burst_particles"):
		_render_bridge.spawn_burst_particles(pos_2d, color, amount)

# ============================================================
# 工具函数
# ============================================================

func _start_color_transition(target: Color) -> void:
	_target_chapter_color = target
	_color_transition_progress = 0.0

func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
