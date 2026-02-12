## toast_notification.gd
## Toast 通知系统 (CanvasLayer)
## 模块7：教学引导与辅助 UI
##
## 功能：
##   - 非关键、短暂的自动消息通知
##   - 屏幕角落滑入，停留2-3秒后自动消失
##   - 根据通知类型使用不同图标和颜色
##   - 使用对象池避免频繁创建/销毁
##   - 支持通知队列和堆叠显示
##
## 设计原则：
##   - 不打断游戏流程
##   - 使用对象池优化性能
##   - 各处（AchievementManager, Inventory等）均可调用
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal toast_shown(toast_type: String, message: String)
signal toast_dismissed(toast_type: String)

# ============================================================
# 主题颜色
# ============================================================
const PANEL_BG := Color("#141026")
const ACCENT_COLOR := Color("#9D6FFF")
const TEXT_PRIMARY := Color("#EAE6FF")
const TEXT_SECONDARY := Color("#A098C8")
const SUCCESS_COLOR := Color("#4DFF80")
const DANGER_COLOR := Color("#FF4D4D")
const GOLD_COLOR := Color("#FFD700")
const INFO_COLOR := Color("#4DFFF3")

# ============================================================
# Toast 类型
# ============================================================
enum ToastType {
	INFO,           ## 一般信息
	SUCCESS,        ## 成功/完成
	WARNING,        ## 警告
	ERROR,          ## 错误
	ACHIEVEMENT,    ## 成就解锁
	ITEM,           ## 物品获取
	LEVEL_UP,       ## 升级
	CODEX,          ## 法典解锁
}

# ============================================================
# 类型配置
# ============================================================
const TYPE_CONFIG: Dictionary = {
	ToastType.INFO: {"icon": "ℹ", "color": INFO_COLOR, "border": INFO_COLOR},
	ToastType.SUCCESS: {"icon": "✓", "color": SUCCESS_COLOR, "border": SUCCESS_COLOR},
	ToastType.WARNING: {"icon": "⚠", "color": GOLD_COLOR, "border": GOLD_COLOR},
	ToastType.ERROR: {"icon": "✗", "color": DANGER_COLOR, "border": DANGER_COLOR},
	ToastType.ACHIEVEMENT: {"icon": "🏆", "color": GOLD_COLOR, "border": GOLD_COLOR},
	ToastType.ITEM: {"icon": "♪", "color": ACCENT_COLOR, "border": ACCENT_COLOR},
	ToastType.LEVEL_UP: {"icon": "★", "color": GOLD_COLOR, "border": GOLD_COLOR},
	ToastType.CODEX: {"icon": "📖", "color": INFO_COLOR, "border": INFO_COLOR},
}

# ============================================================
# 配置
# ============================================================
@export var default_duration: float = 3.0
@export var fade_in_duration: float = 0.35
@export var fade_out_duration: float = 0.5
@export var slide_distance: float = 320.0
@export var max_visible_toasts: int = 4
@export var pool_size: int = 8
@export var toast_spacing: float = 8.0
@export var toast_margin_right: float = 20.0
@export var toast_margin_top: float = 80.0

# ============================================================
# 对象池
# ============================================================
var _pool: Array[PanelContainer] = []
var _pool_available: Array[int] = []

# ============================================================
# 活动 Toast
# ============================================================
## { panel_index: int, type: ToastType, tween: Tween, timer: float }
var _active_toasts: Array[Dictionary] = []

# ============================================================
# 通知队列
# ============================================================
var _queue: Array[Dictionary] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_pool()

func _process(_delta: float) -> void:
	# 尝试从队列中弹出
	if not _queue.is_empty() and _active_toasts.size() < max_visible_toasts:
		var next: Dictionary = _queue.pop_front()
		_show_toast_internal(next)

# ============================================================
# 公共接口
# ============================================================

## 显示 Toast 通知
func show_toast(message: String, type: int = ToastType.INFO, duration: float = -1.0, subtitle: String = "") -> void:
	if duration < 0.0:
		duration = default_duration

	var data := {
		"message": message,
		"type": type,
		"duration": duration,
		"subtitle": subtitle,
	}

	if _active_toasts.size() >= max_visible_toasts:
		_queue.append(data)
	else:
		_show_toast_internal(data)

## 便捷方法 — 信息通知
func info(message: String, subtitle: String = "") -> void:
	show_toast(message, ToastType.INFO, -1.0, subtitle)

## 便捷方法 — 成功通知
func success(message: String, subtitle: String = "") -> void:
	show_toast(message, ToastType.SUCCESS, -1.0, subtitle)

## 便捷方法 — 警告通知
func warning(message: String, subtitle: String = "") -> void:
	show_toast(message, ToastType.WARNING, -1.0, subtitle)

## 便捷方法 — 错误通知
func error(message: String, subtitle: String = "") -> void:
	show_toast(message, ToastType.ERROR, -1.0, subtitle)

## 便捷方法 — 成就通知
func achievement(message: String, subtitle: String = "") -> void:
	show_toast(message, ToastType.ACHIEVEMENT, 4.0, subtitle)

## 便捷方法 — 物品通知
func item(message: String, subtitle: String = "") -> void:
	show_toast(message, ToastType.ITEM, -1.0, subtitle)

## 便捷方法 — 升级通知
func level_up(message: String, subtitle: String = "") -> void:
	show_toast(message, ToastType.LEVEL_UP, 3.5, subtitle)

## 便捷方法 — 法典通知
func codex(message: String, subtitle: String = "") -> void:
	show_toast(message, ToastType.CODEX, -1.0, subtitle)

## 清除所有通知
func clear_all() -> void:
	for toast_data in _active_toasts:
		var idx: int = toast_data.get("panel_index", -1)
		if idx >= 0 and idx < _pool.size():
			var tween: Tween = toast_data.get("tween")
			if tween and tween.is_valid():
				tween.kill()
			_pool[idx].visible = false
			if idx not in _pool_available:
				_pool_available.append(idx)
	_active_toasts.clear()
	_queue.clear()

# ============================================================
# 内部方法 — 显示
# ============================================================

func _show_toast_internal(data: Dictionary) -> void:
	var panel_idx := _acquire_panel()
	if panel_idx < 0:
		_queue.append(data)
		return

	var panel: PanelContainer = _pool[panel_idx]
	var type: int = data.get("type", ToastType.INFO)
	var config: Dictionary = TYPE_CONFIG.get(type, TYPE_CONFIG[ToastType.INFO])
	var message: String = data.get("message", "")
	var subtitle: String = data.get("subtitle", "")
	var duration: float = data.get("duration", default_duration)

	# 更新面板内容
	_update_panel_content(panel, config, message, subtitle)

	# 更新面板样式
	_update_panel_style(panel, config)

	# 计算位置（右上角，向下堆叠）
	var viewport_size := get_viewport().get_visible_rect().size
	var y_pos := toast_margin_top + _active_toasts.size() * (60.0 + toast_spacing)
	var start_x := viewport_size.x + 10
	var target_x := viewport_size.x - slide_distance - toast_margin_right

	panel.position = Vector2(start_x, y_pos)
	panel.visible = true
	panel.modulate.a = 1.0

	# 滑入动画
	var tween := create_tween()
	tween.tween_property(panel, "position:x", target_x, fade_in_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# 停留
	tween.tween_interval(duration)

	# 滑出动画
	tween.tween_property(panel, "position:x", start_x, fade_out_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, fade_out_duration)

	tween.chain()
	tween.tween_callback(func():
		_release_toast(panel_idx, type)
	)

	var toast_info := {
		"panel_index": panel_idx,
		"type": type,
		"tween": tween,
	}
	_active_toasts.append(toast_info)

	var type_name := _get_type_name(type)
	toast_shown.emit(type_name, message)

func _release_toast(panel_idx: int, type: int) -> void:
	# 从活动列表移除
	var to_remove := -1
	for i in range(_active_toasts.size()):
		if _active_toasts[i].get("panel_index", -1) == panel_idx:
			to_remove = i
			break

	if to_remove >= 0:
		_active_toasts.remove_at(to_remove)

	# 归还到池
	_pool[panel_idx].visible = false
	if panel_idx not in _pool_available:
		_pool_available.append(panel_idx)

	# 重新排列活动 Toast 位置
	_reposition_active_toasts()

	var type_name := _get_type_name(type)
	toast_dismissed.emit(type_name)

func _reposition_active_toasts() -> void:
	for i in range(_active_toasts.size()):
		var panel_idx: int = _active_toasts[i].get("panel_index", -1)
		if panel_idx < 0 or panel_idx >= _pool.size():
			continue
		var panel: PanelContainer = _pool[panel_idx]
		var target_y := toast_margin_top + i * (60.0 + toast_spacing)
		var tween := create_tween()
		tween.tween_property(panel, "position:y", target_y, 0.2) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

# ============================================================
# 内部方法 — 面板更新
# ============================================================

func _update_panel_content(panel: PanelContainer, config: Dictionary, message: String, subtitle: String) -> void:
	var icon_label: Label = panel.get_node_or_null("HBox/IconLabel")
	var msg_label: Label = panel.get_node_or_null("HBox/VBox/MessageLabel")
	var sub_label: Label = panel.get_node_or_null("HBox/VBox/SubtitleLabel")

	if icon_label:
		icon_label.text = config.get("icon", "ℹ")
		icon_label.add_theme_color_override("font_color", config.get("color", INFO_COLOR))

	if msg_label:
		msg_label.text = message

	if sub_label:
		if subtitle != "":
			sub_label.text = subtitle
			sub_label.visible = true
		else:
			sub_label.visible = false

func _update_panel_style(panel: PanelContainer, config: Dictionary) -> void:
	var border_color: Color = config.get("border", ACCENT_COLOR)
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style:
		style.border_color = Color(border_color, 0.7)
		style.shadow_color = Color(border_color, 0.15)
		panel.add_theme_stylebox_override("panel", style)

# ============================================================
# 对象池
# ============================================================

func _create_pool() -> void:
	for i in range(pool_size):
		var panel := _create_toast_panel()
		panel.name = "ToastPanel_%d" % i
		panel.visible = false
		add_child(panel)
		_pool.append(panel)
		_pool_available.append(i)

func _acquire_panel() -> int:
	if _pool_available.is_empty():
		return -1
	return _pool_available.pop_front()

func _create_toast_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 54)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL_BG, 0.92)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(ACCENT_COLOR, 0.7)
	style.shadow_color = Color(ACCENT_COLOR, 0.15)
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 10)

	# 图标
	var icon := Label.new()
	icon.name = "IconLabel"
	icon.text = "ℹ"
	icon.add_theme_font_size_override("font_size", 22)
	icon.add_theme_color_override("font_color", INFO_COLOR)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon)

	# 文字容器
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var msg := Label.new()
	msg.name = "MessageLabel"
	msg.text = ""
	msg.add_theme_font_size_override("font_size", 15)
	msg.add_theme_color_override("font_color", TEXT_PRIMARY)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size.x = 230
	vbox.add_child(msg)

	var sub := Label.new()
	sub.name = "SubtitleLabel"
	sub.text = ""
	sub.visible = false
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", TEXT_SECONDARY)
	vbox.add_child(sub)

	hbox.add_child(vbox)
	panel.add_child(hbox)

	return panel

func _get_type_name(type: int) -> String:
	match type:
		ToastType.INFO: return "info"
		ToastType.SUCCESS: return "success"
		ToastType.WARNING: return "warning"
		ToastType.ERROR: return "error"
		ToastType.ACHIEVEMENT: return "achievement"
		ToastType.ITEM: return "item"
		ToastType.LEVEL_UP: return "level_up"
		ToastType.CODEX: return "codex"
		_: return "unknown"
