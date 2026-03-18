## spellbook_panel_v3.gd
## v3.0 法术书面板 (Spellbook Panel)
##
## 位于一体化编曲台右侧下半部分，功能包括：
##   - 以列表形式展示所有已炼成的和弦法术
##   - 显示法术名称、类型、形态图标、装备状态
##   - 作为拖拽源：可将法术拖到序列器或手动施法槽
##   - 滚动支持（法术数量超过可视区域时）
##   - 和弦法术形状编码系统（来自 UI 设计文档 §4.2）
##
## 使用 Godot 内置拖拽 API
## 与 NoteInventory 全局单例对接
extends Control

# ============================================================
# 信号
# ============================================================
## 信息悬停（供主面板信息栏使用）
signal info_hover(title: String, desc: String, color: Color)

# ============================================================
# 常量
# ============================================================
## 法术卡片尺寸
const CARD_HEIGHT := 52.0
const CARD_GAP := 4.0
const CARD_MARGIN_X := 6.0

## 颜色定义
var CARD_BG: Color = UIColors.with_alpha(UIColors.PANEL_DARK, 0.69)
static var CARD_HOVER_BG := UIColors.with_alpha(UIColors.ACCENT, 0.15)
var CARD_EQUIPPED_BG: Color = UIColors.with_alpha(UIColors.PRIMARY_BG, 0.5)
static var CARD_BORDER := UIColors.with_alpha(UIColors.ACCENT, 0.19)
static var CARD_HOVER_BORDER := UIColors.with_alpha(UIColors.ACCENT, 0.50)
static var CARD_EQUIPPED_BORDER := UIColors.with_alpha(UIColors.ACCENT, 0.09)
static var SPELL_NAME_EQUIPPED := UIColors.with_alpha(UIColors.TEXT_HINT, 0.50)
static var FORM_DESC_COLOR := UIColors.with_alpha(UIColors.TEXT_HINT, 0.69)
var STATUS_READY_COLOR: Color = UIColors.with_alpha(UIColors.SUCCESS, 0.69)
var STATUS_EQUIPPED_COLOR: Color = UIColors.with_alpha(UIColors.RARITY_RARE, 0.69)
static var EMPTY_HINT_COLOR := UIColors.with_alpha(UIColors.TEXT_HINT, 0.38)

## 法术形态颜色
const SPELL_FORM_COLORS: Dictionary = UIColors.FORM_COLORS
## 法术形态图标（来自 UI 设计文档 §4.2）
const SPELL_FORM_ICONS := {
	"enhanced_projectile": "▲",   # 大三和弦 → 强化弹体
	"dot_projectile": "💧",       # 小三和弦 → DOT弹体
	"explosive_projectile": "✦",  # 增三和弦 → 爆炸弹体
	"shockwave": "◎",             # 减三和弦 → 冲击波
	"magic_circle": "◉",          # 属七和弦 → 法阵/区域
	"celestial_strike": "⚡",     # 减七和弦 → 天降打击
	"shield_heal": "✚",           # 大七和弦 → 护盾/治疗
	"summon_construct": "▣",      # 小七和弦 → 召唤/构造
	"charged_projectile": "⌛",   # 挂留和弦 → 蓄力弹体
	"slow_field": "◐",            # 半减七 → 迟缓领域
	"generic_blast": "●",         # 通用
}

## 音符颜色

# ============================================================
# 状态
# ============================================================
## 法术卡片矩形缓存
var _card_rects: Array[Rect2] = []
## 当前悬停的卡片索引
var _hover_card: int = -1
## 滚动偏移
var _scroll_offset: float = 0.0
## 最大滚动范围
var _max_scroll: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	custom_minimum_size = Vector2(200, 200)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true  # 裁剪超出区域的内容

# 注：重绘已改为事件驱动，仅在数据变化（悬停、滚动、刷新）时调用 queue_redraw()
# 删除了每帧无条件重绘的 _process 函数

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var font := ThemeDB.fallback_font
	_card_rects.clear()

	var x := CARD_MARGIN_X
	var y := 4.0

	## ===== 标题 =====
	draw_string(font, Vector2(x, y + 12), "SPELLBOOK",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIColors.TEXT_HINT)

	## 法术数量
	var spellbook := NoteInventory.spellbook
	var count_str := "(%d)" % spellbook.size()
	draw_string(font, Vector2(x + 80, y + 12), count_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIColors.with_alpha(UIColors.TEXT_HINT, 0.50))
	y += 20.0

	## ===== 空法术书提示 =====
	if spellbook.is_empty():
		draw_string(font, Vector2(x, y + 16),
			"尚无和弦法术", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, EMPTY_HINT_COLOR)
		draw_string(font, Vector2(x, y + 32),
			"在上方炼成区合成", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIColors.with_alpha(UIColors.TEXT_HINT, 0.25))
		return

	## ===== 法术卡片列表 =====
	var visible_y := y - _scroll_offset
	var card_w := size.x - CARD_MARGIN_X * 2

	for i in range(spellbook.size()):
		var card_y := visible_y + i * (CARD_HEIGHT + CARD_GAP)
		var card_rect := Rect2(Vector2(x, card_y), Vector2(card_w, CARD_HEIGHT))
		_card_rects.append(card_rect)

		## 跳过不可见的卡片
		if card_y + CARD_HEIGHT < y:
			continue
		if card_y > size.y:
			break

		var spell: Dictionary = spellbook[i]
		var is_hover := (_hover_card == i)
		var is_equipped: bool = spell.get("is_equipped", false)

		## 卡片背景
		var bg := CARD_BG
		if is_equipped:
			bg = CARD_EQUIPPED_BG
		elif is_hover:
			bg = CARD_HOVER_BG
		draw_rect(card_rect, bg)

		## 卡片边框
		var border := CARD_BORDER
		if is_hover:
			border = CARD_HOVER_BORDER
		elif is_equipped:
			border = CARD_EQUIPPED_BORDER
		draw_rect(card_rect, border, false, 1.0)

		## 法术形态图标（左侧）
		var spell_form: String = spell.get("spell_form", "generic_blast")
		var form_color: Color = SPELL_FORM_COLORS.get(spell_form, Color.WHITE)
		var form_icon: String = SPELL_FORM_ICONS.get(spell_form, "●")
		if is_equipped:
			form_color.a = 0.4
		draw_string(font,
			card_rect.position + Vector2(8, CARD_HEIGHT / 2.0 + 6),
			form_icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, form_color)

		## 法术名称
		var spell_name: String = spell.get("spell_name", "Unknown")
		var name_color := UIColors.TEXT_PRIMARY if not is_equipped else SPELL_NAME_EQUIPPED
		draw_string(font,
			card_rect.position + Vector2(30, 20),
			spell_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, name_color)

		## 法术形态描述
		var form_str: String = spell_form.replace("_", " ").capitalize()
		draw_string(font,
			card_rect.position + Vector2(30, 36),
			form_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, FORM_DESC_COLOR)

		## 根音色条
		var root_note: int = spell.get("root_note", 0)
		var root_color: Color = UIColors.get_note_color_by_int(root_note)
		if is_equipped:
			root_color.a = 0.3
		draw_rect(
			Rect2(card_rect.position, Vector2(3, CARD_HEIGHT)),
			root_color
		)

		## 装备状态标签
		var status_text := "已装备" if is_equipped else "可用"
		var status_color := STATUS_EQUIPPED_COLOR if is_equipped else STATUS_READY_COLOR
		draw_string(font,
			card_rect.position + Vector2(card_w - 50, 20),
			status_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 9, status_color)

	## 更新最大滚动范围
	var total_content_h := spellbook.size() * (CARD_HEIGHT + CARD_GAP)
	var visible_h := size.y - y
	_max_scroll = max(0, total_content_h - visible_h)

# ============================================================
# 鼠标交互
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_scroll_offset = max(0, _scroll_offset - 30)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_scroll_offset = min(_max_scroll, _scroll_offset + 30)
			queue_redraw()

## 更新悬停状态
func _update_hover(pos: Vector2) -> void:
	var old_hover := _hover_card
	_hover_card = -1

	for i in range(_card_rects.size()):
		if _card_rects[i].has_point(pos):
			_hover_card = i
			break

	if _hover_card != old_hover:
		if _hover_card >= 0:
			_emit_card_info(_hover_card)
		queue_redraw()

## 发送卡片信息
func _emit_card_info(idx: int) -> void:
	var spellbook := NoteInventory.spellbook
	if idx >= spellbook.size():
		return
	var spell: Dictionary = spellbook[idx]
	var spell_name: String = spell.get("spell_name", "Unknown")
	var spell_form: String = spell.get("spell_form", "generic_blast")
	var form_color: Color = SPELL_FORM_COLORS.get(spell_form, Color.WHITE)
	var is_equipped: bool = spell.get("is_equipped", false)
	var root_note: int = spell.get("root_note", 0)
	var root_name: String = MusicData.WHITE_KEY_STATS.get(root_note, {}).get("name", "?")

	var desc := "形态: %s | 根音: %s" % [spell_form.replace("_", " ").capitalize(), root_name]
	if is_equipped:
		desc += " | 已装备到: %s" % spell.get("equipped_location", "?")
	else:
		desc += " | 拖拽到序列器或手动施法槽装备"

	info_hover.emit(spell_name, desc, form_color)

# ============================================================
# Godot 内置拖拽 API
# ============================================================

## 从法术书开始拖拽
func _get_drag_data(at_position: Vector2) -> Variant:
	var spellbook := NoteInventory.spellbook

	for i in range(_card_rects.size()):
		if _card_rects[i].has_point(at_position) and i < spellbook.size():
			var spell: Dictionary = spellbook[i]

			## 已装备的法术不能拖拽
			if spell.get("is_equipped", false):
				return null

			var spell_id: String = spell.get("id", "")
			var spell_name: String = spell.get("spell_name", "Unknown")
			var spell_form: String = spell.get("spell_form", "generic_blast")
			var form_color: Color = SPELL_FORM_COLORS.get(spell_form, Color.WHITE)
			var form_icon: String = SPELL_FORM_ICONS.get(spell_form, "●")

			## 创建拖拽预览
			var preview := _create_spell_drag_preview(form_icon, spell_name, form_color)
			set_drag_preview(preview)

			return {
				"type": "chord_spell",
				"spell_id": spell_id,
				"spell_name": spell_name,
				"spell_form": spell_form,
				"source": "spellbook",
				"source_idx": i,
			}

	return null

# ============================================================
# 外部接口
# ============================================================

## 刷新法术书显示
func refresh() -> void:
	_scroll_offset = 0
	queue_redraw()

# ============================================================
# 工具方法
# ============================================================

## 创建法术拖拽预览
func _create_spell_drag_preview(icon: String, name: String, color: Color) -> Control:
	var preview := Control.new()
	var sz := Vector2(120, 40)
	preview.custom_minimum_size = sz
	preview.size = sz

	var panel := Panel.new()
	panel.custom_minimum_size = sz
	panel.size = sz

	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.with_alpha(color, 0.4)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = UIColors.with_alpha(color, 0.5)
	style.shadow_size = 5
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "%s %s" % [icon, name]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = sz
	label.size = sz
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 11)

	preview.add_child(panel)
	preview.add_child(label)
	return preview
