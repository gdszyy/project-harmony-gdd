## codex_unlock_popup.gd
## 图鉴条目解锁通知弹窗
## 当新条目解锁时，在屏幕右上角显示一个短暂的通知动画
## 设计风格：暗色半透明底 + 稀有度边框颜色 + 滑入/淡出动画
extends Control

# ============================================================
# 常量
# ============================================================
const DISPLAY_DURATION := 3.0
const SLIDE_IN_DURATION := 0.4
const FADE_OUT_DURATION := 0.6
const POPUP_WIDTH := 320.0
const POPUP_HEIGHT := 72.0
const MARGIN_RIGHT := 20.0
const MARGIN_TOP := 80.0

const VOLUME_NAMES: Dictionary = {
	0: "乐理纲要",
	1: "百相众声",
	2: "失谐魔物",
	3: "神兵乐章",
}

# ============================================================
# 内部状态
# ============================================================
var _queue: Array[Dictionary] = []
var _is_showing: bool = false
var _current_panel: PanelContainer = null
var _timer: float = 0.0
var _state: int = 0  # 0=idle, 1=slide_in, 2=display, 3=fade_out

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 连接 CodexManager 信号
	if CodexManager and CodexManager.has_signal("entry_unlocked"):
		CodexManager.entry_unlocked.connect(_on_entry_unlocked)

func _process(delta: float) -> void:
	if _state == 0:
		if not _queue.is_empty() and not _is_showing:
			_show_next()
		return

	_timer += delta

	match _state:
		1:  # slide_in
			var t := clampf(_timer / SLIDE_IN_DURATION, 0.0, 1.0)
			var ease_t := 1.0 - pow(1.0 - t, 3.0)  # ease out cubic
			if _current_panel:
				_current_panel.position.x = size.x - MARGIN_RIGHT - POPUP_WIDTH * ease_t
				_current_panel.modulate.a = ease_t
			if t >= 1.0:
				_state = 2
				_timer = 0.0

		2:  # display
			if _timer >= DISPLAY_DURATION:
				_state = 3
				_timer = 0.0

		3:  # fade_out
			var t := clampf(_timer / FADE_OUT_DURATION, 0.0, 1.0)
			if _current_panel:
				_current_panel.modulate.a = 1.0 - t
				_current_panel.position.x = size.x - MARGIN_RIGHT - POPUP_WIDTH + 30.0 * t
			if t >= 1.0:
				if _current_panel:
					_current_panel.queue_free()
					_current_panel = null
				_is_showing = false
				_state = 0

# ============================================================
# 显示逻辑
# ============================================================

func _on_entry_unlocked(entry_id: String, entry_name: String, volume: int) -> void:
	var data = CodexData.find_entry(entry_id)
	var rarity: int = data.get("rarity", CodexData.Rarity.COMMON)
	_queue.append({
		"name": entry_name,
		"volume": volume,
		"rarity": rarity,
	})

func _show_next() -> void:
	if _queue.is_empty():
		return

	var info: Dictionary = _queue.pop_front()
	_is_showing = true
	_state = 1
	_timer = 0.0

	var rarity_color: Color = CodexData.RARITY_COLORS.get(info["rarity"], Color.WHITE)
	var volume_name: String = VOLUME_NAMES.get(info["volume"], "未知")

	# 创建面板
	_current_panel = PanelContainer.new()
	_current_panel.custom_minimum_size = Vector2(POPUP_WIDTH, POPUP_HEIGHT)
	_current_panel.position = Vector2(size.x, MARGIN_TOP)
	_current_panel.modulate.a = 0.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.12, 0.95)
	style.border_color = rarity_color
	style.border_width_left = 3
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_current_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_current_panel.add_child(vbox)

	# 标题行
	var title := Label.new()
	title.text = "图鉴解锁 — %s" % volume_name
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.5, 0.45, 0.6))
	vbox.add_child(title)

	# 条目名称
	var name_label := Label.new()
	name_label.text = info["name"]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", rarity_color)
	vbox.add_child(name_label)

	# 稀有度
	var rarity_label := Label.new()
	rarity_label.text = CodexData.RARITY_NAMES.get(info["rarity"], "普通")
	rarity_label.add_theme_font_size_override("font_size", 10)
	rarity_label.add_theme_color_override("font_color", rarity_color * 0.7)
	vbox.add_child(rarity_label)

	add_child(_current_panel)
