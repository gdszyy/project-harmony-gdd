## tutorial_hint_manager.gd
## 教学提示管理器 (Autoload)
## 管理非侵入式的教学提示系统，支持：
##   - 文字提示（柔和淡入淡出）
##   - UI 元素高亮
##   - 条件触发提示
##   - 解锁通知
##
## 设计原则：
##   - "柔和高亮"：提示不遮挡游戏画面，不暂停游戏
##   - "延迟触发"：条件提示在条件满足后才显示，避免过早干扰
##   - "环境即教程"：提示辅助理解，而非替代关卡设计的教学意图
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal hint_shown(text: String)
signal hint_dismissed()
signal unlock_shown(unlock_type: String, unlock_name: String)
signal condition_met(condition_id: String)

# ============================================================
# 配置
# ============================================================
## 提示框默认显示时长
@export var default_hint_duration: float = 4.0
## 提示框淡入时间
@export var fade_in_duration: float = 0.3
## 提示框淡出时间
@export var fade_out_duration: float = 0.5
## 解锁通知显示时长
@export var unlock_display_duration: float = 3.0
## 提示框与屏幕底部的偏移
@export var hint_bottom_offset: float = 120.0

# ============================================================
# 内部状态
# ============================================================
var _hint_label: Label = null
var _hint_panel: PanelContainer = null
var _unlock_label: Label = null
var _unlock_panel: PanelContainer = null
var _highlight_overlay: ColorRect = null

var _current_hint_tween: Tween = null
var _current_unlock_tween: Tween = null

## 条件提示注册表：condition_id → {text, highlight_ui, shown}
var _conditional_hints: Dictionary = {}

## 条件状态追踪
var _condition_trackers: Dictionary = {}

## 已显示的提示（避免重复）
var _shown_hints: Array[String] = []

## 已解锁的内容
var _unlocked_features: Array[String] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 100  # 确保在最上层
	_create_hint_ui()
	_create_unlock_ui()

func _process(delta: float) -> void:
	_update_condition_trackers(delta)

# ============================================================
# 公共接口
# ============================================================

## 显示教学提示
func show_hint(text: String, duration: float = -1.0, highlight_ui: String = "") -> void:
	if duration < 0.0:
		duration = default_hint_duration
	
	# 更新提示文本
	_hint_label.text = text
	
	# 淡入
	if _current_hint_tween and _current_hint_tween.is_valid():
		_current_hint_tween.kill()
	
	_current_hint_tween = create_tween()
	_hint_panel.modulate.a = 0.0
	_hint_panel.visible = true
	_current_hint_tween.tween_property(_hint_panel, "modulate:a", 1.0, fade_in_duration)
	
	# 持续显示后淡出
	_current_hint_tween.tween_interval(duration)
	_current_hint_tween.tween_property(_hint_panel, "modulate:a", 0.0, fade_out_duration)
	_current_hint_tween.tween_callback(func():
		_hint_panel.visible = false
		hint_dismissed.emit()
	)
	
	# UI 高亮
	if highlight_ui != "":
		_highlight_ui_element(highlight_ui, duration + fade_in_duration)
	
	hint_shown.emit(text)

## 显示解锁通知
func show_unlock(unlock_type: String, unlock_name: String, message: String) -> void:
	_unlocked_features.append(unlock_name)
	
	# 根据解锁类型设置图标和颜色
	var icon := ""
	var color := Color.WHITE
	match unlock_type:
		"note":
			icon = "♪"
			color = Color(0.3, 0.8, 1.0)
		"feature":
			icon = "★"
			color = Color(1.0, 0.85, 0.2)
		"rhythm":
			icon = "♩"
			color = Color(0.6, 1.0, 0.4)
	
	_unlock_label.text = "%s %s" % [icon, message]
	
	# 动画：从上方滑入
	if _current_unlock_tween and _current_unlock_tween.is_valid():
		_current_unlock_tween.kill()
	
	_current_unlock_tween = create_tween()
	_unlock_panel.visible = true
	_unlock_panel.modulate.a = 0.0
	_unlock_panel.position.y = -60.0
	
	_current_unlock_tween.set_parallel(true)
	_current_unlock_tween.tween_property(_unlock_panel, "modulate:a", 1.0, 0.3)
	_current_unlock_tween.tween_property(_unlock_panel, "position:y", 20.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	_current_unlock_tween.chain()
	_current_unlock_tween.tween_interval(unlock_display_duration)
	
	_current_unlock_tween.chain()
	_current_unlock_tween.set_parallel(true)
	_current_unlock_tween.tween_property(_unlock_panel, "modulate:a", 0.0, 0.5)
	_current_unlock_tween.tween_property(_unlock_panel, "position:y", -30.0, 0.5)
	
	_current_unlock_tween.chain()
	_current_unlock_tween.tween_callback(func():
		_unlock_panel.visible = false
	)
	
	unlock_shown.emit(unlock_type, unlock_name)

## 注册条件提示
func register_conditional_hint(condition_id: String, text: String, highlight_ui: String = "") -> void:
	_conditional_hints[condition_id] = {
		"text": text,
		"highlight_ui": highlight_ui,
		"shown": false,
	}

## 触发条件提示（当条件满足时调用）
func trigger_condition(condition_id: String) -> void:
	if not _conditional_hints.has(condition_id):
		return
	
	var hint: Dictionary = _conditional_hints[condition_id]
	if hint["shown"]:
		return
	
	hint["shown"] = true
	show_hint(hint["text"], default_hint_duration, hint["highlight_ui"])
	condition_met.emit(condition_id)

## 开始追踪条件（用于时间相关的条件）
func start_condition_tracker(condition_id: String, timeout: float) -> void:
	_condition_trackers[condition_id] = {
		"timer": timeout,
		"active": true,
	}

## 重置条件追踪器（当玩家执行了相关操作时）
func reset_condition_tracker(condition_id: String) -> void:
	if _condition_trackers.has(condition_id):
		_condition_trackers.erase(condition_id)

## 检查功能是否已解锁
func is_feature_unlocked(feature_name: String) -> bool:
	return feature_name in _unlocked_features

## 清除所有提示和追踪器
func clear_all() -> void:
	if _current_hint_tween and _current_hint_tween.is_valid():
		_current_hint_tween.kill()
	if _current_unlock_tween and _current_unlock_tween.is_valid():
		_current_unlock_tween.kill()
	
	_hint_panel.visible = false
	_unlock_panel.visible = false
	_conditional_hints.clear()
	_condition_trackers.clear()

# ============================================================
# 条件追踪更新
# ============================================================

func _update_condition_trackers(delta: float) -> void:
	var to_trigger: Array[String] = []
	
	for condition_id in _condition_trackers:
		var tracker: Dictionary = _condition_trackers[condition_id]
		if not tracker["active"]:
			continue
		
		tracker["timer"] -= delta
		if tracker["timer"] <= 0.0:
			tracker["active"] = false
			to_trigger.append(condition_id)
	
	for condition_id in to_trigger:
		trigger_condition(condition_id)
		_condition_trackers.erase(condition_id)

# ============================================================
# UI 创建
# ============================================================

func _create_hint_ui() -> void:
	# 提示面板（屏幕下方居中）
	_hint_panel = PanelContainer.new()
	_hint_panel.name = "HintPanel"
	_hint_panel.visible = false
	_hint_panel.anchor_left = 0.2
	_hint_panel.anchor_right = 0.8
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.offset_top = -(hint_bottom_offset + 60.0)
	_hint_panel.offset_bottom = -hint_bottom_offset
	
	# 半透明背景样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.8, 1.0, 0.5)
	_hint_panel.add_theme_stylebox_override("panel", style)
	
	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_panel.add_child(_hint_label)
	
	add_child(_hint_panel)

func _create_unlock_ui() -> void:
	# 解锁通知面板（屏幕上方居中）
	_unlock_panel = PanelContainer.new()
	_unlock_panel.name = "UnlockPanel"
	_unlock_panel.visible = false
	_unlock_panel.anchor_left = 0.25
	_unlock_panel.anchor_right = 0.75
	_unlock_panel.anchor_top = 0.0
	_unlock_panel.anchor_bottom = 0.0
	_unlock_panel.offset_top = 20.0
	_unlock_panel.offset_bottom = 70.0
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.05, 0.2, 0.85)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.85, 0.2, 0.7)
	_unlock_panel.add_theme_stylebox_override("panel", style)
	
	_unlock_label = Label.new()
	_unlock_label.name = "UnlockLabel"
	_unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unlock_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_unlock_label.add_theme_font_size_override("font_size", 22)
	_unlock_panel.add_child(_unlock_label)
	
	add_child(_unlock_panel)

# ============================================================
# UI 高亮
# ============================================================

func _highlight_ui_element(element_name: String, duration: float) -> void:
	# 尝试查找并高亮指定的 UI 元素
	var target_node := _find_ui_element(element_name)
	if target_node == null:
		return
	
	# 创建高亮边框效果
	var highlight := ColorRect.new()
	highlight.name = "UIHighlight_%s" % element_name
	highlight.color = Color(0.0, 0.8, 1.0, 0.0)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 将高亮添加为目标节点的兄弟节点
	if target_node.get_parent():
		target_node.get_parent().add_child(highlight)
		highlight.position = target_node.position - Vector2(4, 4)
		highlight.size = target_node.size + Vector2(8, 8)
	
	# 脉冲动画
	var tween := highlight.create_tween().set_loops(int(duration / 1.0))
	tween.tween_property(highlight, "color:a", 0.3, 0.5)
	tween.tween_property(highlight, "color:a", 0.1, 0.5)
	
	# 到时间后移除
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(highlight):
			var fade := highlight.create_tween()
			fade.tween_property(highlight, "color:a", 0.0, 0.3)
			fade.tween_callback(highlight.queue_free)
	)

func _find_ui_element(element_name: String) -> Control:
	# 在 HUD 和其他 UI 节点中查找
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		var found := hud.find_child(element_name, true, false)
		if found and found is Control:
			return found as Control
	
	# 在整个场景树中查找
	var root := get_tree().current_scene
	if root:
		var found := root.find_child(element_name, true, false)
		if found and found is Control:
			return found as Control
	
	return null
