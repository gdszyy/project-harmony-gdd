## spellbook_ui.gd
## 法术书 UI 面板
## 展示所有已合成的和弦法术，支持拖拽到序列器或手动施法槽
##
## 设计要点：
##   - 显示所有已合成的和弦法术及其状态（可用/已装备）
##   - 可从法术书拖拽和弦法术到序列器的小节或手动施法槽
##   - 按 Tab 键或点击按钮打开/关闭
extends Control

# ============================================================
# 信号
# ============================================================
signal spell_selected(spell: Dictionary)
signal panel_toggled(is_open: bool)

# ============================================================
# 常量
# ============================================================
const PANEL_WIDTH: float = 280.0
const SPELL_CARD_HEIGHT: float = 60.0
const SPELL_CARD_MARGIN: float = 6.0
const HEADER_HEIGHT: float = 36.0

## 颜色
const BG_COLOR := Color(0.04, 0.03, 0.08, 0.92)
const HEADER_COLOR := Color(0.06, 0.05, 0.12, 0.95)
const CARD_BG_COLOR := Color(0.08, 0.06, 0.14, 0.7)
const CARD_HOVER_COLOR := Color(0.12, 0.1, 0.2, 0.8)
const CARD_EQUIPPED_COLOR := Color(0.06, 0.05, 0.1, 0.5)
const CARD_BORDER_COLOR := Color(0.3, 0.25, 0.45, 0.5)
const EQUIPPED_BADGE_COLOR := Color(0.2, 0.6, 1.0, 0.7)
const AVAILABLE_BADGE_COLOR := Color(0.2, 0.8, 0.4, 0.7)
const TITLE_COLOR := Color(0.7, 0.65, 0.85, 0.9)
const SPELL_NAME_COLOR := Color(1.0, 0.9, 0.6, 0.95)
const SPELL_FORM_COLOR := Color(0.6, 0.55, 0.75, 0.8)
const EMPTY_COLOR := Color(0.4, 0.38, 0.5, 0.5)

# ============================================================
# 状态
# ============================================================
var _is_open: bool = false
var _hover_card_idx: int = -1
var _scroll_offset: float = 0.0
var _card_rects: Array[Rect2] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 400)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# 连接法术书变化信号
	NoteInventory.spellbook_changed.connect(_on_spellbook_changed)

func _process(_delta: float) -> void:
	if _is_open:
		queue_redraw()

# ============================================================
# 显示/隐藏
# ============================================================

func toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	panel_toggled.emit(_is_open)
	if _is_open:
		queue_redraw()

func open_panel() -> void:
	_is_open = true
	visible = true
	panel_toggled.emit(true)
	queue_redraw()

func close_panel() -> void:
	_is_open = false
	visible = false
	panel_toggled.emit(false)

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if not _is_open:
		return

	var font := ThemeDB.fallback_font
	_card_rects.clear()

	# 背景
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)

	# 头部
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, HEADER_HEIGHT)), HEADER_COLOR)
	draw_string(font, Vector2(12, 24), "SPELLBOOK", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TITLE_COLOR)

	var spell_count := NoteInventory.get_spellbook_size()
	draw_string(font, Vector2(size.x - 40, 24), "%d" % spell_count,
		HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color(0.5, 0.45, 0.65, 0.7))

	# 分隔线
	draw_line(Vector2(0, HEADER_HEIGHT), Vector2(size.x, HEADER_HEIGHT), Color(0.25, 0.2, 0.4, 0.5), 1.0)

	# 法术卡片列表
	var spellbook := NoteInventory.spellbook
	if spellbook.is_empty():
		draw_string(font, Vector2(12, HEADER_HEIGHT + 30),
			"No chord spells yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, EMPTY_COLOR)
		draw_string(font, Vector2(12, HEADER_HEIGHT + 50),
			"Use the Alchemy panel to", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, EMPTY_COLOR)
		draw_string(font, Vector2(12, HEADER_HEIGHT + 66),
			"synthesize chord spells.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, EMPTY_COLOR)
		return

	var y_offset := HEADER_HEIGHT + 8.0 - _scroll_offset
	for i in range(spellbook.size()):
		var spell := spellbook[i]
		var card_rect := Rect2(
			Vector2(6, y_offset),
			Vector2(size.x - 12, SPELL_CARD_HEIGHT)
		)
		_card_rects.append(card_rect)

		# 仅绘制可见的卡片
		if card_rect.position.y + card_rect.size.y > HEADER_HEIGHT and card_rect.position.y < size.y:
			_draw_spell_card(card_rect, spell, i, font)

		y_offset += SPELL_CARD_HEIGHT + SPELL_CARD_MARGIN

func _draw_spell_card(rect: Rect2, spell: Dictionary, index: int, font: Font) -> void:
	var is_hover := (_hover_card_idx == index)
	var is_equipped: bool = spell.get("is_equipped", false)

	# 背景
	var bg_color := CARD_BG_COLOR
	if is_equipped:
		bg_color = CARD_EQUIPPED_COLOR
	elif is_hover:
		bg_color = CARD_HOVER_COLOR
	draw_rect(rect, bg_color)

	# 边框
	draw_rect(rect, CARD_BORDER_COLOR, false, 1.0)

	# 法术名称
	var name_color := SPELL_NAME_COLOR
	if is_equipped:
		name_color.a = 0.5
	draw_string(font, rect.position + Vector2(10, 22),
		spell.get("spell_name", "Unknown"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, name_color)

	# 法术形态
	var form_text := spell.get("spell_form", "unknown").replace("_", " ").capitalize()
	draw_string(font, rect.position + Vector2(10, 40),
		form_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SPELL_FORM_COLOR)

	# 根音
	var root_note: int = spell.get("root_note", 0)
	var root_name: String = MusicData.WHITE_KEY_STATS.get(root_note, {}).get("name", "?")
	var root_color: Color = MusicData.NOTE_COLORS.get(root_note, Color(0.5, 0.5, 0.5))
	draw_string(font, rect.position + Vector2(10, 54),
		"Root: %s" % root_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, root_color * 0.8)

	# 状态标签
	var badge_text := ""
	var badge_color := Color.WHITE
	if is_equipped:
		badge_text = "EQUIPPED"
		badge_color = EQUIPPED_BADGE_COLOR
		var location: String = spell.get("equipped_location", "")
		draw_string(font, rect.position + Vector2(rect.size.x - 70, 54),
			location, HORIZONTAL_ALIGNMENT_RIGHT, -1, 8, Color(0.4, 0.5, 0.7, 0.6))
	else:
		badge_text = "READY"
		badge_color = AVAILABLE_BADGE_COLOR

	draw_string(font, rect.position + Vector2(rect.size.x - 70, 22),
		badge_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 9, badge_color)

# ============================================================
# 输入处理
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_click(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_offset = max(0.0, _scroll_offset - 30.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_offset += 30.0

func _update_hover(pos: Vector2) -> void:
	_hover_card_idx = -1
	for i in range(_card_rects.size()):
		if _card_rects[i].has_point(pos):
			_hover_card_idx = i
			break

func _handle_click(pos: Vector2) -> void:
	for i in range(_card_rects.size()):
		if _card_rects[i].has_point(pos):
			var spellbook := NoteInventory.spellbook
			if i < spellbook.size():
				spell_selected.emit(spellbook[i])
			break

# ============================================================
# 快捷键
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			toggle()
			get_viewport().set_input_as_handled()

# ============================================================
# 信号回调
# ============================================================

func _on_spellbook_changed(_spellbook: Array) -> void:
	if _is_open:
		queue_redraw()
