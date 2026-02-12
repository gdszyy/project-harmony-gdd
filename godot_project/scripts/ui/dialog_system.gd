## dialog_system.gd
## 通用弹窗/对话框/确认框系统 (CanvasLayer)
## 模块7：教学引导与辅助 UI
##
## 功能：
##   - 模态确认弹窗（暂停游戏，背景遮罩）
##   - 信息弹窗（纯信息展示，单按钮关闭）
##   - 自定义弹窗（支持自定义按钮和回调）
##   - 弹窗队列（多个弹窗按序显示）
##
## 设计原则：
##   - 遵循全局 UI 主题规范
##   - 模态弹窗暂停游戏
##   - 提供"确认"和"取消"按钮
##   - 支持键盘快捷键（Enter确认, Esc取消）
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal dialog_opened(dialog_id: String)
signal dialog_closed(dialog_id: String, result: String)
signal confirm_pressed(dialog_id: String)
signal cancel_pressed(dialog_id: String)

# ============================================================
# 主题颜色
# ============================================================
const PANEL_BG := Color("#141026")
const ACCENT_COLOR := Color("#9D6FFF")
const TEXT_PRIMARY := Color("#EAE6FF")
const TEXT_SECONDARY := Color("#A098C8")
const DANGER_COLOR := Color("#FF4D4D")
const SUCCESS_COLOR := Color("#4DFF80")
const MASK_COLOR := Color(0.0, 0.0, 0.0, 0.65)

# ============================================================
# 弹窗类型
# ============================================================
enum DialogType {
	CONFIRM,    ## 确认/取消
	INFO,       ## 纯信息（确定按钮）
	WARNING,    ## 警告（确认/取消，红色强调）
	CUSTOM,     ## 自定义按钮
}

# ============================================================
# 配置
# ============================================================
@export var fade_duration: float = 0.25
@export var pause_on_modal: bool = true

# ============================================================
# 内部节点
# ============================================================
var _overlay: ColorRect = null
var _dialog_panel: PanelContainer = null
var _title_label: Label = null
var _message_label: RichTextLabel = null
var _button_container: HBoxContainer = null
var _icon_label: Label = null

# ============================================================
# 内部状态
# ============================================================
var _is_showing: bool = false
var _current_dialog_id: String = ""
var _current_type: DialogType = DialogType.CONFIRM
var _dialog_queue: Array[Dictionary] = []
var _confirm_callback: Callable = Callable()
var _cancel_callback: Callable = Callable()
var _was_paused: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_hide_immediate()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_showing:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_on_confirm()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if _current_type != DialogType.INFO:
					_on_cancel()
				else:
					_on_confirm()
				get_viewport().set_input_as_handled()

# ============================================================
# 公共接口
# ============================================================

## 显示确认弹窗
func show_confirm(title: String, message: String, on_confirm: Callable = Callable(), on_cancel: Callable = Callable(), dialog_id: String = "") -> void:
	_enqueue_dialog({
		"type": DialogType.CONFIRM,
		"title": title,
		"message": message,
		"confirm_callback": on_confirm,
		"cancel_callback": on_cancel,
		"id": dialog_id if dialog_id != "" else "confirm_%d" % Time.get_ticks_msec(),
	})

## 显示信息弹窗
func show_info(title: String, message: String, on_close: Callable = Callable(), dialog_id: String = "") -> void:
	_enqueue_dialog({
		"type": DialogType.INFO,
		"title": title,
		"message": message,
		"confirm_callback": on_close,
		"cancel_callback": Callable(),
		"id": dialog_id if dialog_id != "" else "info_%d" % Time.get_ticks_msec(),
	})

## 显示警告弹窗
func show_warning(title: String, message: String, on_confirm: Callable = Callable(), on_cancel: Callable = Callable(), dialog_id: String = "") -> void:
	_enqueue_dialog({
		"type": DialogType.WARNING,
		"title": title,
		"message": message,
		"confirm_callback": on_confirm,
		"cancel_callback": on_cancel,
		"id": dialog_id if dialog_id != "" else "warning_%d" % Time.get_ticks_msec(),
	})

## 显示自定义弹窗
func show_custom(title: String, message: String, buttons: Array[Dictionary], dialog_id: String = "") -> void:
	## buttons: [{"text": "按钮文字", "callback": Callable, "color": Color}]
	_enqueue_dialog({
		"type": DialogType.CUSTOM,
		"title": title,
		"message": message,
		"buttons": buttons,
		"confirm_callback": Callable(),
		"cancel_callback": Callable(),
		"id": dialog_id if dialog_id != "" else "custom_%d" % Time.get_ticks_msec(),
	})

## 关闭当前弹窗
func close_current() -> void:
	if not _is_showing:
		return
	_close_dialog("closed")

## 检查是否有弹窗显示
func is_showing() -> bool:
	return _is_showing

## 获取当前弹窗ID
func get_current_dialog_id() -> String:
	return _current_dialog_id

# ============================================================
# 内部方法 — 队列管理
# ============================================================

func _enqueue_dialog(data: Dictionary) -> void:
	if _is_showing:
		_dialog_queue.append(data)
		return
	_show_dialog(data)

func _show_next_in_queue() -> void:
	if _dialog_queue.is_empty():
		return
	var next: Dictionary = _dialog_queue.pop_front()
	# 延迟一帧再显示下一个
	get_tree().create_timer(0.1).timeout.connect(func():
		_show_dialog(next)
	)

# ============================================================
# 内部方法 — 显示/隐藏
# ============================================================

func _show_dialog(data: Dictionary) -> void:
	_current_dialog_id = data.get("id", "")
	_current_type = data.get("type", DialogType.CONFIRM) as DialogType
	_confirm_callback = data.get("confirm_callback", Callable())
	_cancel_callback = data.get("cancel_callback", Callable())

	# 设置标题
	_title_label.text = data.get("title", "")

	# 设置图标
	match _current_type:
		DialogType.CONFIRM:
			_icon_label.text = "?"
			_icon_label.add_theme_color_override("font_color", ACCENT_COLOR)
		DialogType.INFO:
			_icon_label.text = "i"
			_icon_label.add_theme_color_override("font_color", ACCENT_COLOR)
		DialogType.WARNING:
			_icon_label.text = "!"
			_icon_label.add_theme_color_override("font_color", DANGER_COLOR)
		DialogType.CUSTOM:
			_icon_label.text = "◆"
			_icon_label.add_theme_color_override("font_color", ACCENT_COLOR)

	# 设置消息
	_message_label.text = data.get("message", "")

	# 构建按钮
	_build_buttons(data)

	# 暂停游戏
	if pause_on_modal:
		_was_paused = get_tree().paused
		get_tree().paused = true

	# 显示动画
	_overlay.visible = true
	_dialog_panel.visible = true
	_overlay.modulate.a = 0.0
	_dialog_panel.modulate.a = 0.0
	_dialog_panel.scale = Vector2(0.9, 0.9)
	_dialog_panel.pivot_offset = _dialog_panel.size / 2.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_overlay, "modulate:a", 1.0, fade_duration)
	tween.tween_property(_dialog_panel, "modulate:a", 1.0, fade_duration)
	tween.tween_property(_dialog_panel, "scale", Vector2(1.0, 1.0), fade_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	_is_showing = true
	dialog_opened.emit(_current_dialog_id)

func _close_dialog(result: String) -> void:
	var dialog_id := _current_dialog_id

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_overlay, "modulate:a", 0.0, fade_duration)
	tween.tween_property(_dialog_panel, "modulate:a", 0.0, fade_duration)
	tween.tween_property(_dialog_panel, "scale", Vector2(0.95, 0.95), fade_duration)
	tween.chain()
	tween.tween_callback(func():
		_hide_immediate()
		# 恢复游戏暂停状态
		if pause_on_modal and not _was_paused:
			get_tree().paused = false
		_is_showing = false
		dialog_closed.emit(dialog_id, result)
		_show_next_in_queue()
	)

func _hide_immediate() -> void:
	_overlay.visible = false
	_dialog_panel.visible = false

# ============================================================
# 内部方法 — 按钮构建
# ============================================================

func _build_buttons(data: Dictionary) -> void:
	# 清除旧按钮
	for child in _button_container.get_children():
		child.queue_free()

	match _current_type:
		DialogType.CONFIRM:
			var cancel_btn := _create_dialog_button("取消", TEXT_SECONDARY)
			cancel_btn.pressed.connect(_on_cancel)
			_button_container.add_child(cancel_btn)

			var confirm_btn := _create_dialog_button("确认", ACCENT_COLOR)
			confirm_btn.pressed.connect(_on_confirm)
			_button_container.add_child(confirm_btn)

		DialogType.INFO:
			var ok_btn := _create_dialog_button("确定", ACCENT_COLOR)
			ok_btn.pressed.connect(_on_confirm)
			_button_container.add_child(ok_btn)

		DialogType.WARNING:
			var cancel_btn := _create_dialog_button("取消", TEXT_SECONDARY)
			cancel_btn.pressed.connect(_on_cancel)
			_button_container.add_child(cancel_btn)

			var confirm_btn := _create_dialog_button("确认", DANGER_COLOR)
			confirm_btn.pressed.connect(_on_confirm)
			_button_container.add_child(confirm_btn)

		DialogType.CUSTOM:
			var buttons: Array = data.get("buttons", [])
			for btn_data in buttons:
				var btn_text: String = btn_data.get("text", "按钮")
				var btn_color: Color = btn_data.get("color", ACCENT_COLOR)
				var btn_callback: Callable = btn_data.get("callback", Callable())
				var btn := _create_dialog_button(btn_text, btn_color)
				if btn_callback.is_valid():
					btn.pressed.connect(func():
						btn_callback.call()
						_close_dialog(btn_text)
					)
				else:
					btn.pressed.connect(func():
						_close_dialog(btn_text)
					)
				_button_container.add_child(btn)

func _create_dialog_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 40)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL_BG, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = accent
	btn.add_theme_stylebox_override("normal", style)

	var style_hover := style.duplicate()
	style_hover.bg_color = Color(accent, 0.15)
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed := style.duplicate()
	style_pressed.bg_color = Color(accent, 0.25)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	btn.add_theme_font_size_override("font_size", 15)

	return btn

# ============================================================
# 按钮回调
# ============================================================

func _on_confirm() -> void:
	if _confirm_callback.is_valid():
		_confirm_callback.call()
	confirm_pressed.emit(_current_dialog_id)
	_close_dialog("confirm")

func _on_cancel() -> void:
	if _cancel_callback.is_valid():
		_cancel_callback.call()
	cancel_pressed.emit(_current_dialog_id)
	_close_dialog("cancel")

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	# 背景遮罩
	_overlay = ColorRect.new()
	_overlay.name = "DialogOverlay"
	_overlay.color = MASK_COLOR
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# 弹窗面板
	_dialog_panel = PanelContainer.new()
	_dialog_panel.name = "DialogPanel"
	_dialog_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_dialog_panel.offset_left = -220
	_dialog_panel.offset_right = 220
	_dialog_panel.offset_top = -120
	_dialog_panel.offset_bottom = 120

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(PANEL_BG, 0.95)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.content_margin_left = 28.0
	panel_style.content_margin_right = 28.0
	panel_style.content_margin_top = 24.0
	panel_style.content_margin_bottom = 24.0
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(ACCENT_COLOR, 0.5)
	panel_style.shadow_color = Color(ACCENT_COLOR, 0.15)
	panel_style.shadow_size = 12
	_dialog_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)

	# 标题行（图标 + 标题）
	var title_hbox := HBoxContainer.new()
	title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_hbox.add_theme_constant_override("separation", 10)

	_icon_label = Label.new()
	_icon_label.name = "DialogIcon"
	_icon_label.text = "?"
	_icon_label.add_theme_font_size_override("font_size", 28)
	_icon_label.add_theme_color_override("font_color", ACCENT_COLOR)
	title_hbox.add_child(_icon_label)

	_title_label = Label.new()
	_title_label.name = "DialogTitle"
	_title_label.text = "标题"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	title_hbox.add_child(_title_label)

	vbox.add_child(title_hbox)

	# 分隔线
	var separator := ColorRect.new()
	separator.color = Color(ACCENT_COLOR, 0.3)
	separator.custom_minimum_size.y = 1
	vbox.add_child(separator)

	# 消息内容
	_message_label = RichTextLabel.new()
	_message_label.name = "DialogMessage"
	_message_label.bbcode_enabled = true
	_message_label.fit_content = true
	_message_label.scroll_active = false
	_message_label.custom_minimum_size.y = 60
	_message_label.add_theme_color_override("default_color", TEXT_SECONDARY)
	_message_label.add_theme_font_size_override("normal_font_size", 16)
	vbox.add_child(_message_label)

	# 按钮容器
	_button_container = HBoxContainer.new()
	_button_container.name = "ButtonContainer"
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 16)
	vbox.add_child(_button_container)

	_dialog_panel.add_child(vbox)
	add_child(_dialog_panel)
