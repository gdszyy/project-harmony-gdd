## global_visual_environment.gd
## 全局视觉环境管理器 (Autoload)
##
## 职责：
## 1. 管理 WorldEnvironment 后处理（Glow, Tonemap, Adjustments）
## 2. 维护全局 Shader 参数（时间、节拍、章节色彩）
## 3. 实现章节间的色彩平滑过渡
## 4. 提供节拍驱动的全局视觉脉冲
extends Node

# ============================================================
# 配置
# ============================================================

## Glow 配置
const GLOW_ENABLED: bool = true
const GLOW_HDR_THRESHOLD: float = 0.8
const GLOW_HDR_SCALE: float = 2.5
const GLOW_INTENSITY: float = 0.8
const GLOW_BLOOM: float = 0.1

## 节拍脉冲配置
const BEAT_GLOW_BOOST: float = 0.3        ## 节拍时刻的 Glow 增量
const BEAT_GLOW_DECAY: float = 4.0        ## Glow 增量衰减速率

## 色彩过渡配置
const COLOR_TRANSITION_DURATION: float = 3.0  ## 色彩过渡时长（秒）

# ============================================================
# 节点引用
# ============================================================
var _world_env: WorldEnvironment = null
var _environment: Environment = null

# ============================================================
# 状态
# ============================================================
var _beat_glow_extra: float = 0.0          ## 节拍驱动的额外 Glow
var _current_chapter_color: Color = Color(0.0, 1.0, 0.8)  ## 当前章节主色
var _target_chapter_color: Color = Color(0.0, 1.0, 0.8)   ## 目标章节主色
var _color_transition_progress: float = 1.0  ## 0.0 = 开始过渡, 1.0 = 过渡完成
var _global_time: float = 0.0
var _beat_phase: float = 0.0               ## 0.0 ~ 1.0，当前节拍相位

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_create_world_environment()
	_connect_signals()
	_update_global_shader_params()

func _process(delta: float) -> void:
	_global_time += delta

	# 节拍 Glow 衰减
	if _beat_glow_extra > 0.001:
		_beat_glow_extra = lerp(_beat_glow_extra, 0.0, BEAT_GLOW_DECAY * delta)
	else:
		_beat_glow_extra = 0.0

	# 色彩过渡
	if _color_transition_progress < 1.0:
		_color_transition_progress += delta / COLOR_TRANSITION_DURATION
		_color_transition_progress = minf(_color_transition_progress, 1.0)
		_current_chapter_color = _current_chapter_color.lerp(
			_target_chapter_color,
			_ease_in_out(_color_transition_progress)
		)

	# 更新 Glow
	if _environment and GLOW_ENABLED:
		_environment.glow_intensity = GLOW_INTENSITY + _beat_glow_extra

	# 更新全局 Shader 参数
	_update_global_shader_params()

# ============================================================
# 初始化
# ============================================================

func _create_world_environment() -> void:
	_environment = Environment.new()

	# 背景
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.01, 0.01, 0.02)

	# Glow / Bloom
	_environment.glow_enabled = GLOW_ENABLED
	_environment.glow_hdr_threshold = GLOW_HDR_THRESHOLD
	_environment.glow_hdr_scale = GLOW_HDR_SCALE
	_environment.glow_intensity = GLOW_INTENSITY
	_environment.glow_bloom = GLOW_BLOOM
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# Tonemap
	_environment.tonemap_mode = Environment.TONE_MAPPER_ACES

	# Adjustments
	_environment.adjustment_enabled = true
	_environment.adjustment_brightness = 1.0
	_environment.adjustment_contrast = 1.1
	_environment.adjustment_saturation = 1.15

	# 创建 WorldEnvironment 节点
	_world_env = WorldEnvironment.new()
	_world_env.environment = _environment
	add_child(_world_env)

func _connect_signals() -> void:
	# 连接章节管理器信号
	if Engine.has_singleton("ChapterManager"):
		var cm = Engine.get_singleton("ChapterManager")
		if cm.has_signal("chapter_started"):
			cm.chapter_started.connect(_on_chapter_started)
		if cm.has_signal("color_theme_changed"):
			cm.color_theme_changed.connect(_on_color_theme_changed)
	elif has_node("/root/ChapterManager"):
		var cm = get_node("/root/ChapterManager")
		if cm.has_signal("chapter_started"):
			cm.chapter_started.connect(_on_chapter_started)
		if cm.has_signal("color_theme_changed"):
			cm.color_theme_changed.connect(_on_color_theme_changed)

	# 连接节拍信号
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_signal("beat_tick"):
			gm.beat_tick.connect(_on_beat_tick)

# ============================================================
# 全局 Shader 参数
# ============================================================

func _update_global_shader_params() -> void:
	# 使用 Godot 4.x 的全局 Shader 参数
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
	var config := {}
	if has_node("/root/ChapterManager"):
		var cm = get_node("/root/ChapterManager")
		if cm.has_method("get_chapter_config"):
			config = cm.get_chapter_config(chapter)
	
	var new_color: Color = config.get("color_theme", Color(0.0, 1.0, 0.8))
	_start_color_transition(new_color)

	# 调整环境亮度和对比度
	var brightness: float = config.get("env_brightness", 1.0)
	var contrast: float = config.get("env_contrast", 1.1)
	if _environment:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_environment, "adjustment_brightness", brightness, 2.0)
		tween.tween_property(_environment, "adjustment_contrast", contrast, 2.0)

func _on_color_theme_changed(from_color: Color, to_color: Color, _progress: float) -> void:
	_target_chapter_color = to_color
	if _color_transition_progress >= 1.0:
		_current_chapter_color = from_color
		_color_transition_progress = 0.0

	func _on_beat_tick(beat_index: int) -> void:
		_beat_glow_extra = BEAT_GLOW_BOOST
		_beat_phase = 0.0

# ============================================================
# 公共接口
# ============================================================

## 获取当前章节主色
func get_chapter_color() -> Color:
	return _current_chapter_color

## 获取当前节拍相位 (0.0 ~ 1.0)
func get_beat_phase() -> float:
	return _beat_phase

## 手动设置 Glow 强度（用于 Boss 战等特殊场景）
func set_glow_override(intensity: float, duration: float = 0.5) -> void:
	if _environment:
		var tween := create_tween()
		tween.tween_property(_environment, "glow_intensity", intensity, duration)

## 恢复默认 Glow
func reset_glow(duration: float = 1.0) -> void:
	if _environment:
		var tween := create_tween()
		tween.tween_property(_environment, "glow_intensity", GLOW_INTENSITY, duration)

## Boss 战模式：增强对比度和饱和度
func enter_boss_mode() -> void:
	if _environment:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_environment, "adjustment_contrast", 1.3, 1.0)
		tween.tween_property(_environment, "adjustment_saturation", 1.3, 1.0)
		tween.tween_property(_environment, "glow_hdr_scale", 3.5, 1.0)

func exit_boss_mode() -> void:
	if _environment:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_environment, "adjustment_contrast", 1.1, 2.0)
		tween.tween_property(_environment, "adjustment_saturation", 1.15, 2.0)
		tween.tween_property(_environment, "glow_hdr_scale", GLOW_HDR_SCALE, 2.0)

# ============================================================
# 工具函数
# ============================================================

func _start_color_transition(target: Color) -> void:
	_target_chapter_color = target
	_color_transition_progress = 0.0

func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)  # Smoothstep
