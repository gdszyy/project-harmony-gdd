## note_inventory_ui.gd
## v3.0 音符库存面板 — 12音符库存显示与拖拽源
##
## 在一体化编曲台左侧区域垂直排列所有12种基础音符：
##   - 7个白键音符（C, D, E, F, G, A, B）
##   - 5个黑键修饰符（C#, D#, F#, G#, A#）
##
## 功能：
##   - 显示每种音符的名称、颜色编码、库存数量
##   - 作为拖拽源：支持 Godot 内置拖拽 API
##   - 库存不足时闪烁红色反馈
##   - 悬停时显示音符详细信息
##
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
## 白键格子尺寸
const WHITE_CELL_SIZE := Vector2(180, 36)
const WHITE_CELL_GAP := 4.0

## 黑键格子尺寸（略小于白键）
const BLACK_CELL_SIZE := Vector2(160, 30)
const BLACK_CELL_GAP := 4.0

## 分隔区域间距
const SECTION_GAP := 12.0

## 颜色定义
const CELL_BG := UIColors.with_alpha(UIColors.PANEL_BG, 0.63)
const CELL_HOVER_BG := UIColors.with_alpha(UIColors.ACCENT, 0.19)
const CELL_EMPTY_BG := UIColors.with_alpha(UIColors.PANEL_BG, 0.38)
const CELL_BORDER := UIColors.with_alpha(UIColors.ACCENT, 0.25)
const EMPTY_COUNT_COLOR := UIColors.with_alpha(UIColors.TEXT_HINT, 0.38)
const INSUFFICIENT_FLASH_COLOR := UIColors.with_alpha(UIColors.OFFENSE, 0.50)

## 闪烁效果
const FLASH_DURATION: float = 0.5

## 音符颜色编码（来自 UI 设计文档 §4.1）

## 音符描述（用于信息悬停）
const NOTE_DESCRIPTIONS := {
	0: "均衡型 — DMG/SPD/DUR/SIZE 均衡分配",
	1: "极速远程 — 高速度，适合远距离狙击",
	2: "大范围持久 — 大体积持久弹体",
	3: "区域控制 — 超持久缓行，区域封锁",
	4: "爆发伤害 — 高伤快消，瞬间爆发",
	5: "持久高伤 — 持续输出型",
	6: "高速高伤 — 高速穿透型",
}

const BLACK_KEY_DESCRIPTIONS := {
	0: "锐化(C#) — 穿透效果：弹体穿透敌人",
	1: "追踪(D#) — 追踪效果：弹体自动追踪目标",
	2: "分裂(F#) — 分裂效果：弹体命中后分裂",
	3: "回响(G#) — 回响效果：弹体产生回声",
	4: "散射(A#) — 散射效果：弹体扇形散射",
}

# ============================================================
# 状态
# ============================================================
## 白键格子矩形缓存
var _white_rects: Array[Rect2] = []
## 黑键格子矩形缓存
var _black_rects: Array[Rect2] = []
## 当前悬停的白键索引（-1 表示无）
var _hover_white: int = -1
## 当前悬停的黑键索引（-1 表示无）
var _hover_black: int = -1
## 闪烁计时器（库存不足反馈）
var _flash_timers: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _black_flash_timers: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	## 计算最小尺寸
	var total_h := 20.0  # 标题
	total_h += 7 * (WHITE_CELL_SIZE.y + WHITE_CELL_GAP)  # 白键
	total_h += SECTION_GAP + 16.0  # 分隔 + 黑键标题
	total_h += 5 * (BLACK_CELL_SIZE.y + BLACK_CELL_GAP)  # 黑键
	total_h += 10.0  # 底部留白
	custom_minimum_size = Vector2(WHITE_CELL_SIZE.x + 20, total_h)

	mouse_filter = Control.MOUSE_FILTER_STOP

	## 连接库存不足信号
	if NoteInventory.has_signal("insufficient_notes"):
		NoteInventory.insufficient_notes.connect(_on_insufficient_notes)
	if NoteInventory.has_signal("note_acquired"):
		NoteInventory.note_acquired.connect(_on_note_acquired)

func _process(delta: float) -> void:
	var needs_redraw := false
	for i in range(7):
		if _flash_timers[i] > 0:
			_flash_timers[i] -= delta
			needs_redraw = true
	for i in range(5):
		if _black_flash_timers[i] > 0:
			_black_flash_timers[i] -= delta
			needs_redraw = true
	if needs_redraw:
		queue_redraw()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var font := ThemeDB.fallback_font
	_white_rects.clear()
	_black_rects.clear()

	var x := 10.0
	var y := 4.0

	## ===== 白键区域标题 =====
	draw_string(font, Vector2(x, y + 12), "WHITE KEYS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIColors.TEXT_HINT)
	y += 18.0

	## ===== 白键音符 =====
	for i in range(7):
		var rect := Rect2(Vector2(x, y), WHITE_CELL_SIZE)
		_white_rects.append(rect)

		var count: int = NoteInventory.get_note_count(i)
		var note_color: Color = UIColors.get_note_color_by_int(i)
		var is_hover := (_hover_white == i)

		## 背景色
		var bg := CELL_BG if count > 0 else CELL_EMPTY_BG
		if is_hover:
			bg = CELL_HOVER_BG
		## 库存不足闪烁
		if _flash_timers[i] > 0:
			var flash_t := _flash_timers[i] / FLASH_DURATION
			bg = bg.lerp(INSUFFICIENT_FLASH_COLOR, flash_t)

		draw_rect(rect, bg)

		## 边框（有库存时使用音符颜色）
		var border_color := note_color if count > 0 else CELL_BORDER
		border_color.a = 0.6 if count > 0 else 0.3
		draw_rect(rect, border_color, false, 1.0)

		## 左侧色条指示器
		var indicator_rect := Rect2(Vector2(x, y), Vector2(4, WHITE_CELL_SIZE.y))
		var indicator_color := note_color if count > 0 else UIColors.with_alpha(note_color, 0.2)
		draw_rect(indicator_rect, indicator_color)

		## 音符名称
		var name_str: String = MusicData.WHITE_KEY_STATS.get(i, {}).get("name", "?")
		var text_color := note_color if count > 0 else UIColors.with_alpha(UIColors.TEXT_LOCKED, 0.5)
		draw_string(font, Vector2(x + 12, y + WHITE_CELL_SIZE.y / 2.0 + 5),
			name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_color)

		## 音符描述
		var desc_str: String = MusicData.WHITE_KEY_STATS.get(i, {}).get("desc", "")
		var desc_color := UIColors.with_alpha(UIColors.TEXT_HINT, 0.7) if count > 0 else UIColors.with_alpha(UIColors.TEXT_LOCKED, 0.3)
		draw_string(font, Vector2(x + 36, y + WHITE_CELL_SIZE.y / 2.0 + 4),
			desc_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, desc_color)

		## 库存数量
		var count_str := "×%d" % count
		var count_color := UIColors.TEXT_PRIMARY if count > 0 else EMPTY_COUNT_COLOR
		draw_string(font, Vector2(x + WHITE_CELL_SIZE.x - 36, y + WHITE_CELL_SIZE.y / 2.0 + 5),
			count_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, count_color)

		y += WHITE_CELL_SIZE.y + WHITE_CELL_GAP

	## ===== 分隔线 =====
	y += SECTION_GAP / 2.0
	draw_line(
		Vector2(x + 4, y),
		Vector2(x + WHITE_CELL_SIZE.x - 4, y),
		CELL_BORDER, 0.5
	)
	y += SECTION_GAP / 2.0

	## ===== 黑键区域标题 =====
	draw_string(font, Vector2(x, y + 12), "BLACK KEYS (修饰符)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIColors.TEXT_HINT)
	y += 18.0

	## ===== 黑键修饰符 =====
	var black_key_names := ["C#", "D#", "F#", "G#", "A#"]
	for i in range(5):
		var rect := Rect2(Vector2(x + 10, y), BLACK_CELL_SIZE)
		_black_rects.append(rect)

		var count: int = NoteInventory.get_black_key_count(i)
		var bk_color: Color = UIColors.get_black_key_color(i)
		var is_hover := (_hover_black == i)

		## 背景色
		var bg := CELL_BG if count > 0 else CELL_EMPTY_BG
		if is_hover:
			bg = CELL_HOVER_BG
		if _black_flash_timers[i] > 0:
			var flash_t := _black_flash_timers[i] / FLASH_DURATION
			bg = bg.lerp(INSUFFICIENT_FLASH_COLOR, flash_t)

		draw_rect(rect, bg)

		## 边框
		var border_color := bk_color if count > 0 else CELL_BORDER
		border_color.a = 0.5 if count > 0 else 0.2
		draw_rect(rect, border_color, false, 1.0)

		## 左侧色条
		draw_rect(Rect2(Vector2(x + 10, y), Vector2(3, BLACK_CELL_SIZE.y)),
			bk_color if count > 0 else UIColors.with_alpha(bk_color, 0.2))

		## 黑键名称
		var text_color := bk_color if count > 0 else UIColors.with_alpha(UIColors.TEXT_LOCKED, 0.4)
		draw_string(font, Vector2(x + 20, y + BLACK_CELL_SIZE.y / 2.0 + 4),
			black_key_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_color)

		## 修饰符效果名称
		var mod_data: Dictionary = MusicData.BLACK_KEY_MODIFIERS.get(i, {})
		var mod_name: String = mod_data.get("name", "?")
		var mod_desc_color := UIColors.with_alpha(UIColors.TEXT_HINT, 0.6) if count > 0 else UIColors.with_alpha(UIColors.TEXT_LOCKED, 0.3)
		draw_string(font, Vector2(x + 48, y + BLACK_CELL_SIZE.y / 2.0 + 4),
			mod_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, mod_desc_color)

		## 库存数量
		var count_str := "×%d" % count
		var count_color := UIColors.TEXT_PRIMARY if count > 0 else EMPTY_COUNT_COLOR
		draw_string(font, Vector2(x + 10 + BLACK_CELL_SIZE.x - 36, y + BLACK_CELL_SIZE.y / 2.0 + 4),
			count_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, count_color)

		y += BLACK_CELL_SIZE.y + BLACK_CELL_GAP

# ============================================================
# 鼠标交互
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)

## 更新悬停状态
func _update_hover(pos: Vector2) -> void:
	var old_white := _hover_white
	var old_black := _hover_black
	_hover_white = -1
	_hover_black = -1

	## 检查白键
	for i in range(_white_rects.size()):
		if _white_rects[i].has_point(pos):
			_hover_white = i
			break

	## 检查黑键
	if _hover_white < 0:
		for i in range(_black_rects.size()):
			if _black_rects[i].has_point(pos):
				_hover_black = i
				break

	## 发送信息悬停
	if _hover_white != old_white or _hover_black != old_black:
		if _hover_white >= 0:
			_emit_white_info(_hover_white)
		elif _hover_black >= 0:
			_emit_black_info(_hover_black)
		queue_redraw()

## 发送白键信息
func _emit_white_info(idx: int) -> void:
	var stats: Dictionary = MusicData.WHITE_KEY_STATS.get(idx, {})
	var name_str: String = stats.get("name", "?")
	var count: int = NoteInventory.get_note_count(idx)
	var color: Color = UIColors.get_note_color_by_int(idx)
	var desc := NOTE_DESCRIPTIONS.get(idx, "")
	var stat_str := "DMG:%s SPD:%s DUR:%s SIZE:%s | 库存: ×%d" % [
		str(stats.get("dmg", 0)), str(stats.get("spd", 0)),
		str(stats.get("dur", 0)), str(stats.get("size", 0)), count
	]
	info_hover.emit("%s 音符" % name_str, "%s | %s" % [desc, stat_str], color)

## 发送黑键信息
func _emit_black_info(idx: int) -> void:
	var color: Color = UIColors.get_black_key_color(idx)
	var count: int = NoteInventory.get_black_key_count(idx)
	var desc := BLACK_KEY_DESCRIPTIONS.get(idx, "")
	info_hover.emit("黑键修饰符", "%s | 库存: ×%d" % [desc, count], color)

# ============================================================
# Godot 内置拖拽 API
# ============================================================

## 从库存开始拖拽
func _get_drag_data(at_position: Vector2) -> Variant:
	## 检查白键
	for i in range(_white_rects.size()):
		if _white_rects[i].has_point(at_position):
			var count: int = NoteInventory.get_note_count(i)
			if count <= 0:
				## 库存不足 — 闪烁反馈
				_flash_timers[i] = FLASH_DURATION
				queue_redraw()
				return null

			var name_str: String = MusicData.WHITE_KEY_STATS.get(i, {}).get("name", "?")
			var color: Color = UIColors.get_note_color_by_int(i)

			## 创建拖拽预览
			var preview := _create_drag_preview(name_str, color)
			set_drag_preview(preview)

			return {
				"type": "note",
				"note_key": i,
				"source": "inventory",
			}

	## 检查黑键
	for i in range(_black_rects.size()):
		if _black_rects[i].has_point(at_position):
			var count: int = NoteInventory.get_black_key_count(i)
			if count <= 0:
				_black_flash_timers[i] = FLASH_DURATION
				queue_redraw()
				return null

			var bk_names := ["C#", "D#", "F#", "G#", "A#"]
			var color: Color = UIColors.get_black_key_color(i)

			var preview := _create_drag_preview(bk_names[i], color, Vector2(40, 32))
			set_drag_preview(preview)

			return {
				"type": "black_key",
				"black_key_idx": i,
				"source": "inventory",
			}

	return null

# ============================================================
# 外部接口
# ============================================================

## 刷新库存显示
func refresh() -> void:
	queue_redraw()

# ============================================================
# 信号回调
# ============================================================

## 库存不足反馈
func _on_insufficient_notes(note_key: int) -> void:
	if note_key >= 0 and note_key < 7:
		_flash_timers[note_key] = FLASH_DURATION
		queue_redraw()

## 音符获得闪烁
func _on_note_acquired(note_key: int, _amount: int, _source: String) -> void:
	if note_key >= 0 and note_key < 7:
		_flash_timers[note_key] = FLASH_DURATION * 0.5
		queue_redraw()

# ============================================================
# 工具方法
# ============================================================

## 创建拖拽预览控件
func _create_drag_preview(text: String, color: Color, preview_size: Vector2 = Vector2(44, 36)) -> Control:
	var preview := Control.new()
	preview.custom_minimum_size = preview_size
	preview.size = preview_size

	var panel := Panel.new()
	panel.custom_minimum_size = preview_size
	panel.size = preview_size

	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.with_alpha(color, 0.5)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = UIColors.with_alpha(color, 0.6)
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = preview_size
	label.size = preview_size
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 14)

	preview.add_child(panel)
	preview.add_child(label)
	return preview
