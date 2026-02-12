## ui_transition_manager.gd
## 全局 UI 页面转场动效管理器 (Autoload 单例)
##
## 负责管理全屏菜单之间的"数字故障切换"转场效果。
## 使用顶层 CanvasLayer + 全屏 ColorRect + glitch_transition.gdshader 实现。
## 通过 Tween 驱动 shader 的 progress uniform 控制动画进程。
##
## 用法:
##   UITransitionManager.transition_to_scene("res://scenes/main_menu.tscn")
##   UITransitionManager.transition_to_scene("res://scenes/gameplay.tscn", "fade")
##
## 支持的转场类型:
##   - "glitch": 数字故障转场（默认），约250ms
##   - "fade":   简单淡入淡出，约400ms
##   - "instant": 无转场，立即切换
extends Node

# ============================================================
# 信号
# ============================================================

## 转场动画开始时发出
signal transition_started
## 转场动画到达中点（旧场景即将被替换）时发出
signal transition_midpoint
## 转场动画完成时发出
signal transition_finished

# ============================================================
# 常量
# ============================================================

## 故障转场总时长（秒）
const GLITCH_DURATION: float = 0.5
## 淡入淡出转场总时长（秒）
const FADE_DURATION: float = 0.8

# ============================================================
# 内部节点
# ============================================================

## 顶层画布层，确保转场效果覆盖所有 UI
var _canvas_layer: CanvasLayer = null
## 全屏 ColorRect，承载转场 shader
var _transition_rect: ColorRect = null
## 用于淡入淡出的备用 ColorRect
var _fade_rect: ColorRect = null
## 转场 shader 材质
var _glitch_material: ShaderMaterial = null

## 转场锁，防止重复触发
var _is_transitioning: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_transition_layer()


## 构建转场所需的节点层级
func _setup_transition_layer() -> void:
	# 创建顶层 CanvasLayer (z_index 设为极高值)
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "TransitionCanvasLayer"
	_canvas_layer.layer = 100
	add_child(_canvas_layer)

	# 创建故障转场用的 ColorRect
	_transition_rect = ColorRect.new()
	_transition_rect.name = "GlitchRect"
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_rect.visible = false
	_canvas_layer.add_child(_transition_rect)

	# 加载并应用故障转场 shader
	var shader := load("res://shaders/glitch_transition.gdshader")
	if shader:
		_glitch_material = ShaderMaterial.new()
		_glitch_material.shader = shader
		_glitch_material.set_shader_parameter("progress", 0.0)
		_transition_rect.material = _glitch_material

	# 创建淡入淡出用的 ColorRect
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0.039, 0.031, 0.078, 0.0)  # 深渊黑 #0A0814
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.visible = false
	_canvas_layer.add_child(_fade_rect)

# ============================================================
# 公共 API
# ============================================================

## 执行转场并切换到目标场景
## [param target_scene_path] 目标场景的资源路径
## [param transition_type] 转场类型: "glitch", "fade", "instant"
func transition_to_scene(target_scene_path: String, transition_type: String = "glitch") -> void:
	if _is_transitioning:
		push_warning("UITransitionManager: 转场正在进行中，忽略重复请求")
		return

	match transition_type:
		"glitch":
			await _play_glitch_transition(target_scene_path)
		"fade":
			await _play_fade_transition(target_scene_path)
		"instant":
			_instant_transition(target_scene_path)
		_:
			push_warning("UITransitionManager: 未知转场类型 '%s'，使用默认 glitch" % transition_type)
			await _play_glitch_transition(target_scene_path)


## 执行转场并调用回调（用于非场景切换的情况，如弹出子菜单）
## [param callback] 在转场中点执行的回调函数
## [param transition_type] 转场类型
func transition_with_callback(callback: Callable, transition_type: String = "glitch") -> void:
	if _is_transitioning:
		push_warning("UITransitionManager: 转场正在进行中，忽略重复请求")
		return

	match transition_type:
		"glitch":
			await _play_glitch_callback(callback)
		"fade":
			await _play_fade_callback(callback)
		_:
			callback.call()


## 查询当前是否正在转场
func is_transitioning() -> bool:
	return _is_transitioning

# ============================================================
# 故障转场实现
# ============================================================

## 播放故障转场效果并切换场景
func _play_glitch_transition(target_scene_path: String) -> void:
	_is_transitioning = true
	transition_started.emit()

	# 显示转场层
	_transition_rect.visible = true
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # 阻止点击穿透

	# 前半段：故障效果增强 (0.0 -> 1.0)
	var half_duration := GLITCH_DURATION * 0.5
	var tween := create_tween()
	tween.tween_method(_set_glitch_progress, 0.0, 1.0, half_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tween.finished

	# 中点：切换场景
	transition_midpoint.emit()
	get_tree().change_scene_to_file(target_scene_path)

	# 等待一帧让新场景加载
	await get_tree().process_frame

	# 后半段：故障效果消退 (1.0 -> 0.0)
	var tween2 := create_tween()
	tween2.tween_method(_set_glitch_progress, 1.0, 0.0, half_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await tween2.finished

	# 清理
	_transition_rect.visible = false
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_finished.emit()


## 播放故障转场效果并执行回调
func _play_glitch_callback(callback: Callable) -> void:
	_is_transitioning = true
	transition_started.emit()

	_transition_rect.visible = true
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var half_duration := GLITCH_DURATION * 0.5
	var tween := create_tween()
	tween.tween_method(_set_glitch_progress, 0.0, 1.0, half_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tween.finished

	transition_midpoint.emit()
	callback.call()
	await get_tree().process_frame

	var tween2 := create_tween()
	tween2.tween_method(_set_glitch_progress, 1.0, 0.0, half_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await tween2.finished

	_transition_rect.visible = false
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_finished.emit()


## 设置故障 shader 的 progress 参数
func _set_glitch_progress(value: float) -> void:
	if _glitch_material:
		_glitch_material.set_shader_parameter("progress", value)

# ============================================================
# 淡入淡出转场实现
# ============================================================

## 播放淡入淡出转场并切换场景
func _play_fade_transition(target_scene_path: String) -> void:
	_is_transitioning = true
	transition_started.emit()

	_fade_rect.visible = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var half_duration := FADE_DURATION * 0.5

	# 淡出（变黑）
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, half_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await tween.finished

	# 切换场景
	transition_midpoint.emit()
	get_tree().change_scene_to_file(target_scene_path)
	await get_tree().process_frame

	# 淡入（恢复）
	var tween2 := create_tween()
	tween2.tween_property(_fade_rect, "color:a", 0.0, half_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await tween2.finished

	_fade_rect.visible = false
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_finished.emit()


## 播放淡入淡出转场并执行回调
func _play_fade_callback(callback: Callable) -> void:
	_is_transitioning = true
	transition_started.emit()

	_fade_rect.visible = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var half_duration := FADE_DURATION * 0.5

	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, half_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await tween.finished

	transition_midpoint.emit()
	callback.call()
	await get_tree().process_frame

	var tween2 := create_tween()
	tween2.tween_property(_fade_rect, "color:a", 0.0, half_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await tween2.finished

	_fade_rect.visible = false
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_finished.emit()

# ============================================================
# 即时切换
# ============================================================

## 无转场效果，立即切换场景
func _instant_transition(target_scene_path: String) -> void:
	transition_started.emit()
	transition_midpoint.emit()
	get_tree().change_scene_to_file(target_scene_path)
	transition_finished.emit()
