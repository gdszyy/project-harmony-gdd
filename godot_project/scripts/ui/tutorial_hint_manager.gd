## tutorial_hint_manager.gd
## 新手教学提示系统 (Autoload / CanvasLayer)
## 模块7：教学引导与辅助 UI
##
## 功能：
##   - 步骤指引（进度条 + 步骤编号）
##   - 高亮遮罩（全屏半透明遮罩 + 聚光灯镂空）
##   - 箭头指示与文字说明气泡
##   - 解锁通知（从顶部滑入）
##   - 条件提示注册与自动触发
##
## 设计原则：
##   - 使用 CanvasLayer(layer=100) 确保在最上层
##   - 遵循全局 UI 主题规范（UIColors）
##   - 高亮遮罩使用 ColorRect + 镂空区域模拟聚光灯
##   - 箭头带脉冲动画，文字气泡遵循星空紫面板风格
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal hint_shown(text: String)
signal hint_dismissed()
signal unlock_shown(unlock_type: String, unlock_name: String)
signal condition_met(condition_id: String)
signal step_indicator_updated(current: int, total: int)
signal highlight_started(target_name: String)
signal highlight_ended(target_name: String)

# ============================================================
# 主题颜色常量
# ============================================================
const TEXT_SECONDARY := UIColors.TEXT_SECONDARY

# ============================================================
# 配置
# ============================================================
@export var default_hint_duration: float = 4.0
@export var fade_in_duration: float = 0.3
@export var fade_out_duration: float = 0.5
@export var unlock_display_duration: float = 3.0
@export var hint_bottom_offset: float = 120.0
@export var arrow_pulse_speed: float = 2.0
@export var arrow_bounce_amplitude: float = 8.0

# ============================================================
# 内部节点
# ============================================================
## 步骤指引 UI
var _step_container: Control = null
var _step_progress_bar: ProgressBar = null
var _step_title_label: Label = null
var _step_number_label: Label = null

## 高亮遮罩
var _mask_overlay: Control = null
var _mask_top: ColorRect = null
var _mask_bottom: ColorRect = null
var _mask_left: ColorRect = null
var _mask_right: ColorRect = null
var _highlight_glow: Panel = null

## 箭头指示
var _arrow_container: Control = null
var _arrow_sprite: Label = null
var _arrow_tween: Tween = null

## 文字说明气泡
var _bubble_panel: PanelContainer = null
var _bubble_label: RichTextLabel = null

## 提示面板（底部）
var _hint_panel: PanelContainer = null
var _hint_label: Label = null

## 解锁通知面板（顶部）
var _unlock_panel: PanelContainer = null
var _unlock_icon_label: Label = null
var _unlock_label: Label = null

## 跳过按钮
var _skip_button: Button = null

# ============================================================
# Tween 引用
# ============================================================
var _current_hint_tween: Tween = null
var _current_unlock_tween: Tween = null
var _current_highlight_tween: Tween = null
var _current_bubble_tween: Tween = null

# ============================================================
# 内部状态
# ============================================================
## 条件提示注册表
var _conditional_hints: Dictionary = {}
## 条件状态追踪
var _condition_trackers: Dictionary = {}
## 已显示的提示
var _shown_hints: Array[String] = []
## 已解锁的内容
var _unlocked_features: Array[String] = []
## 当前高亮的目标
var _current_highlight_target: String = ""
## 步骤指引状态
var _current_step: int = 0
var _total_steps: int = 0
var _step_title: String = ""
## 遮罩是否激活
var _mask_active: bool = false
## 跳过回调
var _skip_callback: Callable = Callable()

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 100
	_create_all_ui()

func _process(delta: float) -> void:
	_update_condition_trackers(delta)
	# 如果有高亮目标，持续跟踪其位置
	if _mask_active and _current_highlight_target != "":
		_update_highlight_position()

# ============================================================
# 公共接口 — 步骤指引
# ============================================================

## 显示步骤指引条
func show_step_indicator(current_step: int, total_steps: int, title: String = "") -> void:
	_current_step = current_step
	_total_steps = total_steps
	_step_title = title

	if _step_container == null:
		return

	_step_title_label.text = "教学：%s" % title if title != "" else "教学引导"
	_step_number_label.text = "%d / %d" % [current_step, total_steps]
	_step_progress_bar.max_value = total_steps
	_step_progress_bar.value = current_step

	_step_container.visible = true
	_step_container.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_step_container, "modulate:a", 1.0, fade_in_duration)

	step_indicator_updated.emit(current_step, total_steps)

## 更新步骤进度（平滑动画）
func update_step_progress(current_step: int, title: String = "") -> void:
	_current_step = current_step
	if title != "":
		_step_title = title
		_step_title_label.text = "教学：%s" % title

	_step_number_label.text = "%d / %d" % [current_step, _total_steps]

	var tween := create_tween()
	tween.tween_property(_step_progress_bar, "value", float(current_step), 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	step_indicator_updated.emit(current_step, _total_steps)

## 隐藏步骤指引条
func hide_step_indicator() -> void:
	if _step_container == null:
		return
	var tween := create_tween()
	tween.tween_property(_step_container, "modulate:a", 0.0, fade_out_duration)
	tween.tween_callback(func(): _step_container.visible = false)

# ============================================================
# 公共接口 — 高亮遮罩
# ============================================================

## 高亮指定 UI 元素（带全屏遮罩）
func highlight_element(element_name: String, show_arrow: bool = true, bubble_text: String = "") -> void:
	var target := _find_ui_element(element_name)
	if target == null:
		push_warning("[TutorialHintManager] 未找到 UI 元素: %s" % element_name)
		return

	_current_highlight_target = element_name
	_mask_active = true

	# 显示遮罩
	_mask_overlay.visible = true
	_mask_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_mask_overlay, "modulate:a", 1.0, fade_in_duration)

	# 更新遮罩位置
	_position_mask_around(target)

	# 显示箭头
	if show_arrow:
		_show_arrow_at(target)

	# 显示文字气泡
	if bubble_text != "":
		_show_bubble(target, bubble_text)

	highlight_started.emit(element_name)

## 清除高亮遮罩
func clear_highlight() -> void:
	var old_target := _current_highlight_target
	_current_highlight_target = ""
	_mask_active = false

	if _mask_overlay:
		var tween := create_tween()
		tween.tween_property(_mask_overlay, "modulate:a", 0.0, fade_out_duration)
		tween.tween_callback(func(): _mask_overlay.visible = false)

	_hide_arrow()
	_hide_bubble()

	if old_target != "":
		highlight_ended.emit(old_target)

# ============================================================
# 公共接口 — 教学提示
# ============================================================

## 显示教学提示（底部面板）
func show_hint(text: String, duration: float = -1.0, highlight_ui: String = "") -> void:
	if duration < 0.0:
		duration = default_hint_duration

	_hint_label.text = text

	# 淡入
	_kill_tween(_current_hint_tween)
	_current_hint_tween = create_tween()
	_hint_panel.modulate.a = 0.0
	_hint_panel.visible = true
	_current_hint_tween.tween_property(_hint_panel, "modulate:a", 1.0, fade_in_duration)
	_current_hint_tween.tween_interval(duration)
	_current_hint_tween.tween_property(_hint_panel, "modulate:a", 0.0, fade_out_duration)
	_current_hint_tween.tween_callback(func():
		_hint_panel.visible = false
		hint_dismissed.emit()
	)

	# UI 高亮（轻量版，不带遮罩）
	if highlight_ui != "":
		_highlight_ui_element_light(highlight_ui, duration + fade_in_duration)

	hint_shown.emit(text)

## 显示解锁通知
func show_unlock(unlock_type: String, unlock_name: String, message: String) -> void:
	_unlocked_features.append(unlock_name)

	var icon := ""
	var color := Color.WHITE
	match unlock_type:
		"note":
			icon = "♪"
			color = UIColors.SHIELD
		"feature":
			icon = "★"
			color = UIColors.GOLD
		"rhythm":
			icon = "♩"
			color = UIColors.SUCCESS
		"achievement":
			icon = "🏆"
			color = UIColors.GOLD

	_unlock_icon_label.text = icon
	_unlock_icon_label.add_theme_color_override("font_color", color)
	_unlock_label.text = message

	_kill_tween(_current_unlock_tween)
	_current_unlock_tween = create_tween()
	_unlock_panel.visible = true
	_unlock_panel.modulate.a = 0.0
	_unlock_panel.position.y = -80.0

	_current_unlock_tween.set_parallel(true)
	_current_unlock_tween.tween_property(_unlock_panel, "modulate:a", 1.0, 0.3)
	_current_unlock_tween.tween_property(_unlock_panel, "position:y", 20.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	_current_unlock_tween.chain()
	_current_unlock_tween.tween_interval(unlock_display_duration)

	_current_unlock_tween.chain()
	_current_unlock_tween.set_parallel(true)
	_current_unlock_tween.tween_property(_unlock_panel, "modulate:a", 0.0, 0.5)
	_current_unlock_tween.tween_property(_unlock_panel, "position:y", -40.0, 0.5)

	_current_unlock_tween.chain()
	_current_unlock_tween.tween_callback(func():
		_unlock_panel.visible = false
	)

	unlock_shown.emit(unlock_type, unlock_name)

# ============================================================
# 公共接口 — 跳过按钮
# ============================================================

## 显示跳过按钮
func show_skip_button(callback: Callable) -> void:
	_skip_callback = callback
	_skip_button.visible = true
	_skip_button.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_skip_button, "modulate:a", 1.0, fade_in_duration)

## 隐藏跳过按钮
func hide_skip_button() -> void:
	if _skip_button:
		var tween := create_tween()
		tween.tween_property(_skip_button, "modulate:a", 0.0, fade_out_duration)
		tween.tween_callback(func(): _skip_button.visible = false)

# ============================================================
# 公共接口 — 条件提示
# ============================================================

## 注册条件提示
func register_conditional_hint(condition_id: String, text: String, highlight_ui: String = "") -> void:
	_conditional_hints[condition_id] = {
		"text": text,
		"highlight_ui": highlight_ui,
		"shown": false,
	}

## 触发条件提示
func trigger_condition(condition_id: String) -> void:
	if not _conditional_hints.has(condition_id):
		return
	var hint: Dictionary = _conditional_hints[condition_id]
	if hint["shown"]:
		return
	hint["shown"] = true
	show_hint(hint["text"], default_hint_duration, hint["highlight_ui"])
	condition_met.emit(condition_id)

## 开始追踪条件
func start_condition_tracker(condition_id: String, timeout: float) -> void:
	_condition_trackers[condition_id] = {
		"timer": timeout,
		"active": true,
	}

## 重置条件追踪器
func reset_condition_tracker(condition_id: String) -> void:
	if _condition_trackers.has(condition_id):
		_condition_trackers.erase(condition_id)

## 检查功能是否已解锁
func is_feature_unlocked(feature_name: String) -> bool:
	return feature_name in _unlocked_features

## 清除所有提示和追踪器
func clear_all() -> void:
	_kill_tween(_current_hint_tween)
	_kill_tween(_current_unlock_tween)
	_kill_tween(_current_highlight_tween)
	_kill_tween(_current_bubble_tween)

	if _hint_panel:
		_hint_panel.visible = false
	if _unlock_panel:
		_unlock_panel.visible = false

	clear_highlight()
	hide_step_indicator()
	hide_skip_button()

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
# UI 创建 — 总入口
# ============================================================

func _create_all_ui() -> void:
	_create_mask_overlay()
	_create_arrow_indicator()
	_create_bubble_panel()
	_create_step_indicator()
	_create_hint_panel()
	_create_unlock_panel()
	_create_skip_button()

# ============================================================
# UI 创建 — 步骤指引（屏幕顶部中央）
# ============================================================

func _create_step_indicator() -> void:
	_step_container = Control.new()
	_step_container.name = "StepIndicator"
	_step_container.visible = false
	_step_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_step_container.offset_left = -200.0
	_step_container.offset_right = 200.0
	_step_container.offset_top = 16.0
	_step_container.offset_bottom = 90.0

	# 标题
	_step_title_label = Label.new()
	_step_title_label.name = "StepTitle"
	_step_title_label.text = "教学引导"
	_step_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_title_label.add_theme_font_size_override("font_size", 16)
	_step_title_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	_step_title_label.position = Vector2(0, 0)
	_step_title_label.size = Vector2(400, 24)
	_step_container.add_child(_step_title_label)

	# 进度条
	_step_progress_bar = ProgressBar.new()
	_step_progress_bar.name = "StepProgressBar"
	_step_progress_bar.min_value = 0
	_step_progress_bar.max_value = 1
	_step_progress_bar.value = 0
	_step_progress_bar.show_percentage = false
	_step_progress_bar.position = Vector2(40, 28)
	_step_progress_bar.size = Vector2(320, 8)

	# 进度条样式
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = UIColors.with_alpha(UIColors.PANEL_BG, 0.6)
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	bar_bg.corner_radius_bottom_left = 4
	bar_bg.corner_radius_bottom_right = 4
	_step_progress_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = UIColors.ACCENT
	bar_fill.corner_radius_top_left = 4
	bar_fill.corner_radius_top_right = 4
	bar_fill.corner_radius_bottom_left = 4
	bar_fill.corner_radius_bottom_right = 4
	_step_progress_bar.add_theme_stylebox_override("fill", bar_fill)

	_step_container.add_child(_step_progress_bar)

	# 步骤编号
	_step_number_label = Label.new()
	_step_number_label.name = "StepNumber"
	_step_number_label.text = "0 / 0"
	_step_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_number_label.add_theme_font_size_override("font_size", 13)
	_step_number_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	_step_number_label.position = Vector2(0, 40)
	_step_number_label.size = Vector2(400, 20)
	_step_container.add_child(_step_number_label)

	add_child(_step_container)

# ============================================================
# UI 创建 — 高亮遮罩
# ============================================================

func _create_mask_overlay() -> void:
	_mask_overlay = Control.new()
	_mask_overlay.name = "MaskOverlay"
	_mask_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask_overlay.visible = false

	# 四个遮罩矩形（上下左右）
	_mask_top = _create_mask_rect("MaskTop")
	_mask_bottom = _create_mask_rect("MaskBottom")
	_mask_left = _create_mask_rect("MaskLeft")
	_mask_right = _create_mask_rect("MaskRight")

	_mask_overlay.add_child(_mask_top)
	_mask_overlay.add_child(_mask_bottom)
	_mask_overlay.add_child(_mask_left)
	_mask_overlay.add_child(_mask_right)

	# 高亮辉光边框
	_highlight_glow = Panel.new()
	_highlight_glow.name = "HighlightGlow"
	_highlight_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = UIColors.with_alpha(Color.BLACK, 0.0)
	glow_style.border_width_left = 3
	glow_style.border_width_right = 3
	glow_style.border_width_top = 3
	glow_style.border_width_bottom = 3
	glow_style.border_color = UIColors.ACCENT
	glow_style.corner_radius_top_left = 8
	glow_style.corner_radius_top_right = 8
	glow_style.corner_radius_bottom_left = 8
	glow_style.corner_radius_bottom_right = 8
	glow_style.shadow_color = UIColors.with_alpha(UIColors.ACCENT, 0.5)
	glow_style.shadow_size = 12
	_highlight_glow.add_theme_stylebox_override("panel", glow_style)
	_mask_overlay.add_child(_highlight_glow)

	add_child(_mask_overlay)

func _create_mask_rect(rect_name: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = rect_name
	rect.color = UIColors.MASK_COLOR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

# ============================================================
# UI 创建 — 箭头指示
# ============================================================

func _create_arrow_indicator() -> void:
	_arrow_container = Control.new()
	_arrow_container.name = "ArrowIndicator"
	_arrow_container.visible = false
	_arrow_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_arrow_sprite = Label.new()
	_arrow_sprite.name = "ArrowLabel"
	_arrow_sprite.text = "▼"
	_arrow_sprite.add_theme_font_size_override("font_size", 36)
	_arrow_sprite.add_theme_color_override("font_color", UIColors.ACCENT)
	_arrow_sprite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow_container.add_child(_arrow_sprite)

	add_child(_arrow_container)

# ============================================================
# UI 创建 — 文字说明气泡
# ============================================================

func _create_bubble_panel() -> void:
	_bubble_panel = PanelContainer.new()
	_bubble_panel.name = "BubblePanel"
	_bubble_panel.visible = false
	_bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_panel.custom_minimum_size = Vector2(280, 60)

	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.with_alpha(UIColors.PANEL_BG, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = UIColors.ACCENT
	style.shadow_color = UIColors.with_alpha(UIColors.ACCENT, 0.3)
	style.shadow_size = 8
	_bubble_panel.add_theme_stylebox_override("panel", style)

	_bubble_label = RichTextLabel.new()
	_bubble_label.name = "BubbleText"
	_bubble_label.bbcode_enabled = true
	_bubble_label.fit_content = true
	_bubble_label.scroll_active = false
	_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_label.add_theme_color_override("default_color", UIColors.TEXT_PRIMARY)
	_bubble_label.add_theme_font_size_override("normal_font_size", 15)
	_bubble_panel.add_child(_bubble_label)

	add_child(_bubble_panel)

# ============================================================
# UI 创建 — 提示面板（底部）
# ============================================================

func _create_hint_panel() -> void:
	_hint_panel = PanelContainer.new()
	_hint_panel.name = "HintPanel"
	_hint_panel.visible = false
	_hint_panel.anchor_left = 0.2
	_hint_panel.anchor_right = 0.8
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.offset_top = -(hint_bottom_offset + 70.0)
	_hint_panel.offset_bottom = -hint_bottom_offset

	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.with_alpha(UIColors.PANEL_BG, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = UIColors.with_alpha(UIColors.ACCENT, 0.6)
	style.shadow_color = UIColors.with_alpha(UIColors.ACCENT, 0.2)
	style.shadow_size = 6
	_hint_panel.add_theme_stylebox_override("panel", style)

	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_panel.add_child(_hint_label)

	add_child(_hint_panel)

# ============================================================
# UI 创建 — 解锁通知面板
# ============================================================

func _create_unlock_panel() -> void:
	_unlock_panel = PanelContainer.new()
	_unlock_panel.name = "UnlockPanel"
	_unlock_panel.visible = false
	_unlock_panel.anchor_left = 0.25
	_unlock_panel.anchor_right = 0.75
	_unlock_panel.anchor_top = 0.0
	_unlock_panel.anchor_bottom = 0.0
	_unlock_panel.offset_top = 20.0
	_unlock_panel.offset_bottom = 76.0

	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.with_alpha(UIColors.PANEL_BG, 0.92)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = UIColors.with_alpha(UIColors.GOLD, 0.7)
	style.shadow_color = UIColors.with_alpha(UIColors.GOLD, 0.3)
	style.shadow_size = 8
	_unlock_panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)

	_unlock_icon_label = Label.new()
	_unlock_icon_label.name = "UnlockIcon"
	_unlock_icon_label.add_theme_font_size_override("font_size", 28)
	_unlock_icon_label.add_theme_color_override("font_color", UIColors.GOLD)
	hbox.add_child(_unlock_icon_label)

	_unlock_label = Label.new()
	_unlock_label.name = "UnlockLabel"
	_unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unlock_label.add_theme_color_override("font_color", UIColors.GOLD)
	_unlock_label.add_theme_font_size_override("font_size", 20)
	hbox.add_child(_unlock_label)

	_unlock_panel.add_child(hbox)
	add_child(_unlock_panel)

# ============================================================
# UI 创建 — 跳过按钮
# ============================================================

func _create_skip_button() -> void:
	_skip_button = Button.new()
	_skip_button.name = "SkipTutorialButton"
	_skip_button.text = "跳过教学 ▸▸"
	_skip_button.visible = false
	_skip_button.anchor_left = 1.0
	_skip_button.anchor_right = 1.0
	_skip_button.anchor_top = 0.0
	_skip_button.anchor_bottom = 0.0
	_skip_button.offset_left = -170.0
	_skip_button.offset_top = 16.0
	_skip_button.offset_right = -16.0
	_skip_button.offset_bottom = 50.0

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = UIColors.with_alpha(UIColors.PANEL_BG, 0.8)
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.corner_radius_bottom_right = 6
	style_normal.border_width_left = 1
	style_normal.border_width_right = 1
	style_normal.border_width_top = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = UIColors.with_alpha(TEXT_SECONDARY, 0.5)
	_skip_button.add_theme_stylebox_override("normal", style_normal)

	var style_hover := style_normal.duplicate()
	style_hover.border_color = UIColors.ACCENT
	_skip_button.add_theme_stylebox_override("hover", style_hover)

	_skip_button.add_theme_color_override("font_color", TEXT_SECONDARY)
	_skip_button.add_theme_color_override("font_hover_color", UIColors.TEXT_PRIMARY)
	_skip_button.add_theme_font_size_override("font_size", 14)

	_skip_button.pressed.connect(_on_skip_pressed)
	add_child(_skip_button)

# ============================================================
# 内部方法 — 遮罩定位
# ============================================================

func _position_mask_around(target: Control) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var target_rect := _get_global_rect(target)
	var padding := 12.0

	var left := target_rect.position.x - padding
	var top := target_rect.position.y - padding
	var right := target_rect.position.x + target_rect.size.x + padding
	var bottom := target_rect.position.y + target_rect.size.y + padding

	# 上方遮罩
	_mask_top.position = Vector2.ZERO
	_mask_top.size = Vector2(viewport_size.x, max(top, 0))

	# 下方遮罩
	_mask_bottom.position = Vector2(0, bottom)
	_mask_bottom.size = Vector2(viewport_size.x, max(viewport_size.y - bottom, 0))

	# 左侧遮罩
	_mask_left.position = Vector2(0, top)
	_mask_left.size = Vector2(max(left, 0), bottom - top)

	# 右侧遮罩
	_mask_right.position = Vector2(right, top)
	_mask_right.size = Vector2(max(viewport_size.x - right, 0), bottom - top)

	# 辉光边框
	_highlight_glow.position = Vector2(left - 3, top - 3)
	_highlight_glow.size = Vector2(right - left + 6, bottom - top + 6)

func _update_highlight_position() -> void:
	var target := _find_ui_element(_current_highlight_target)
	if target == null:
		return
	_position_mask_around(target)
	# 更新箭头位置
	if _arrow_container.visible:
		var target_rect := _get_global_rect(target)
		_arrow_container.position = Vector2(
			target_rect.position.x + target_rect.size.x / 2.0 - 20,
			target_rect.position.y - 50
		)

func _get_global_rect(control: Control) -> Rect2:
	return Rect2(control.global_position, control.size)

# ============================================================
# 内部方法 — 箭头
# ============================================================

func _show_arrow_at(target: Control) -> void:
	var target_rect := _get_global_rect(target)
	_arrow_container.position = Vector2(
		target_rect.position.x + target_rect.size.x / 2.0 - 20,
		target_rect.position.y - 50
	)
	_arrow_container.visible = true

	# 脉冲动画
	_kill_tween(_arrow_tween)
	_arrow_tween = create_tween().set_loops()
	_arrow_tween.tween_property(_arrow_container, "position:y",
		target_rect.position.y - 50 + arrow_bounce_amplitude, 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_arrow_tween.tween_property(_arrow_container, "position:y",
		target_rect.position.y - 50 - arrow_bounce_amplitude, 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _hide_arrow() -> void:
	_kill_tween(_arrow_tween)
	if _arrow_container:
		_arrow_container.visible = false

# ============================================================
# 内部方法 — 文字气泡
# ============================================================

func _show_bubble(target: Control, text: String) -> void:
	_bubble_label.text = text
	var target_rect := _get_global_rect(target)
	var viewport_size := get_viewport().get_visible_rect().size

	# 默认显示在目标下方
	var bubble_x := target_rect.position.x + target_rect.size.x / 2.0 - 140
	var bubble_y := target_rect.position.y + target_rect.size.y + 20

	# 如果下方空间不足，显示在上方
	if bubble_y + 80 > viewport_size.y:
		bubble_y = target_rect.position.y - 100

	# 确保不超出屏幕
	bubble_x = clampf(bubble_x, 16, viewport_size.x - 296)
	bubble_y = clampf(bubble_y, 16, viewport_size.y - 80)

	_bubble_panel.position = Vector2(bubble_x, bubble_y)
	_bubble_panel.visible = true
	_bubble_panel.modulate.a = 0.0

	_kill_tween(_current_bubble_tween)
	_current_bubble_tween = create_tween()
	_current_bubble_tween.tween_property(_bubble_panel, "modulate:a", 1.0, fade_in_duration)

func _hide_bubble() -> void:
	_kill_tween(_current_bubble_tween)
	if _bubble_panel:
		_bubble_panel.visible = false

# ============================================================
# 内部方法 — 轻量高亮（不带遮罩）
# ============================================================

func _highlight_ui_element_light(element_name: String, duration: float) -> void:
	var target_node := _find_ui_element(element_name)
	if target_node == null:
		return

	var highlight := ColorRect.new()
	highlight.name = "UIHighlight_%s" % element_name
	highlight.color = UIColors.with_alpha(UIColors.ACCENT, 0.0)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if target_node.get_parent():
		target_node.get_parent().add_child(highlight)
		highlight.position = target_node.position - Vector2(4, 4)
		highlight.size = target_node.size + Vector2(8, 8)

	var tween := highlight.create_tween().set_loops(int(duration / 1.0))
	tween.tween_property(highlight, "color:a", 0.3, 0.5)
	tween.tween_property(highlight, "color:a", 0.1, 0.5)

	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(highlight):
			var fade := highlight.create_tween()
			fade.tween_property(highlight, "color:a", 0.0, 0.3)
			fade.tween_callback(highlight.queue_free)
	)

# ============================================================
# 内部方法 — 查找 UI 元素
# ============================================================

func _find_ui_element(element_name: String) -> Control:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		var found := hud.find_child(element_name, true, false)
		if found and found is Control:
			return found as Control

	var root := get_tree().current_scene
	if root:
		var found := root.find_child(element_name, true, false)
		if found and found is Control:
			return found as Control

	return null

# ============================================================
# 内部方法 — 工具
# ============================================================

func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()

func _on_skip_pressed() -> void:
	if _skip_callback.is_valid():
		_skip_callback.call()
