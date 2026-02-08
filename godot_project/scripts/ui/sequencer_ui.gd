## sequencer_ui.gd
## 序列器 UI（v3.1 — 布局与交互修复）
## 4小节×4拍的乐谱序列器界面
##
## v3.1 修复：
##   - 修复布局：整个面板从底部向上展开，确保所有内容在屏幕内
##   - 修复交互：左键点击单元格直接放置当前选中音符（而非拖拽）
##   - 修复交互：右键清除单元格，长按右键显示小节菜单
##   - 优化：调色板和信息面板位于序列器上方，从下往上排列
##   - 优化：工具提示始终显示在面板内部，不会超出屏幕
extends Control

# ============================================================
# 信号
# ============================================================
signal note_placed(cell_idx: int, note: int)
signal cell_cleared(cell_idx: int)
signal edit_mode_changed(mode: String)

# ============================================================
# 配置
# ============================================================
const CELL_SIZE := Vector2(48, 48)
const CELL_MARGIN := 4.0
const MEASURE_GAP := 12.0
const BEATS_PER_MEASURE := 4
const MEASURES := 4
const TOTAL_CELLS := BEATS_PER_MEASURE * MEASURES

## 布局配置（从底部向上排列）
## 整个面板高度分配：
##   底部: 序列器单元格行 (48px)
##   上方: 调色板行 (36px)
##   再上方: 信息面板 (可选，悬停时显示)
const BOTTOM_PADDING := 8.0
const SEQUENCER_ROW_HEIGHT := 48.0
const PALETTE_ROW_HEIGHT := 40.0
const MODE_LABEL_HEIGHT := 16.0
const TOP_PADDING := 4.0

## 音符调色板配置
const PALETTE_CELL_SIZE := Vector2(36, 36)
const PALETTE_MARGIN := 3.0

## 颜色定义 — 使用全局调色板
const BG_COLOR := Color(0.04, 0.03, 0.08, 0.92)
const CELL_EMPTY_COLOR := Color(0.08, 0.06, 0.14, 0.6)
const CELL_HOVER_COLOR := Color(0.2, 0.18, 0.3, 0.4)
const PLAYHEAD_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const MEASURE_LINE_COLOR := Color(0.3, 0.28, 0.4, 0.5)
const REST_COLOR := Color(0.12, 0.1, 0.18, 0.4)
const DRAG_GHOST_ALPHA := 0.4
const PALETTE_BG_COLOR := Color(0.05, 0.04, 0.1, 0.7)
const PALETTE_SELECTED_BORDER := Color(1.0, 1.0, 1.0, 0.9)
const CHORD_INDICATOR_COLOR := Color(1.0, 0.8, 0.0, 0.7)
const RHYTHM_LABEL_COLOR := Color(0.5, 0.5, 0.6, 0.7)

# ============================================================
# 预设模板定义
# ============================================================
const PRESET_TEMPLATES := [
	{
		"name": "连射风暴",
		"desc": "全音符填充 → 连射模式",
		"icon": ">>",
		"color": Color(0.3, 0.6, 1.0),
		"pattern": ["note", "note", "note", "note"],
		"notes": [0, 2, 4, 0],  # C E G C
	},
	{
		"name": "重击节奏",
		"desc": "强拍音符+弱拍休止 → 重击",
		"icon": "!.",
		"color": Color(1.0, 0.3, 0.1),
		"pattern": ["note", "note", "note", "rest"],
		"notes": [4, 4, 4, -1],  # G G G _
	},
	{
		"name": "闪避射击",
		"desc": "弱拍起手 → 闪避射击",
		"icon": "<>",
		"color": Color(0.0, 0.8, 0.6),
		"pattern": ["rest", "note", "rest", "note"],
		"notes": [-1, 6, -1, 5],  # _ B _ A
	},
	{
		"name": "蓄力爆发",
		"desc": "大量休止+单音 → 蓄力加成",
		"icon": "**",
		"color": Color(1.0, 0.8, 0.0),
		"pattern": ["note", "rest", "rest", "rest"],
		"notes": [4, -1, -1, -1],  # G _ _ _
	},
	{
		"name": "三连冲击",
		"desc": "三音+休止 → 三连发",
		"icon": "3x",
		"color": Color(0.8, 0.4, 1.0),
		"pattern": ["note", "note", "note", "rest"],
		"notes": [0, 2, 4, -1],  # C D E _
	},
	{
		"name": "摇摆旋律",
		"desc": "三音+休止 → 摇摆弹道",
		"icon": "~S",
		"color": Color(1.0, 0.6, 0.3),
		"pattern": ["note", "rest", "note", "note"],
		"notes": [0, -1, 3, 5],  # C _ F A
	},
]

# ============================================================
# 状态
# ============================================================
var _playhead_position: int = 0
var _sequencer_data: Array = []
var _beat_flash: float = 0.0

## 编辑状态
var _edit_mode: String = "note"  # "note", "chord", "rest"
var _selected_note: int = MusicData.WhiteKey.C
var _chord_notes: Array[int] = []

## 拖拽状态
var _is_dragging: bool = false
var _drag_source_idx: int = -1
var _drag_note: int = -1
var _drag_from_palette: bool = false
var _drag_position: Vector2 = Vector2.ZERO
var _drag_started: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD := 8.0  # 拖拽启动阈值（像素）

## 多选状态
var _selected_cells: Array[int] = []
var _is_multi_selecting: bool = false
var _multi_select_start: int = -1

## 复制粘贴缓冲区
var _clipboard: Array[Dictionary] = []

## 撤销/重做历史
var _undo_stack: Array[Array] = []
var _redo_stack: Array[Array] = []
const MAX_UNDO_STEPS: int = 32

## 悬停状态
var _hover_cell_idx: int = -1
var _hover_palette_idx: int = -1
var _hover_mode_btn: int = -1
var _hover_template_idx: int = -1

## 工具提示
var _tooltip_text: String = ""
var _tooltip_position: Vector2 = Vector2.ZERO
var _tooltip_visible: bool = false

## 节奏型缓存
var _measure_rhythms: Array[String] = ["", "", "", ""]
var _measure_rhythm_descs: Array[String] = ["", "", "", ""]

## 右键菜单状态
var _context_menu_visible: bool = false
var _context_menu_position: Vector2 = Vector2.ZERO
var _context_menu_measure: int = -1
var _hover_context_item: int = -1

## 快捷键提示
var _show_shortcuts: bool = false

## 模式切换动画
var _mode_switch_flash: float = 0.0
var _mode_switch_color: Color = Color.WHITE

## 布局缓存
var _seq_row_y: float = 0.0
var _palette_row_y: float = 0.0
var _content_start_x: float = 0.0
var _total_content_width: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 连接信号
	GameManager.beat_tick.connect(_on_beat_tick)
	SpellcraftSystem.sequencer_updated.connect(_on_sequencer_updated)
	if SpellcraftSystem.has_signal("rhythm_pattern_changed"):
		SpellcraftSystem.rhythm_pattern_changed.connect(_on_rhythm_changed)

	# 初始化数据
	_sequencer_data = SpellcraftSystem.get_sequencer_data()

	# 计算面板所需的总宽度
	_total_content_width = MEASURES * BEATS_PER_MEASURE * (CELL_SIZE.x + CELL_MARGIN) + (MEASURES - 1) * MEASURE_GAP + 20

	# 设置最小尺寸
	# 高度 = 顶部标签 + 调色板行 + 间距 + 序列器行 + 底部间距
	var total_height := TOP_PADDING + MODE_LABEL_HEIGHT + PALETTE_ROW_HEIGHT + 8.0 + SEQUENCER_ROW_HEIGHT + BOTTOM_PADDING + 30.0
	custom_minimum_size = Vector2(_total_content_width, total_height)

	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	_beat_flash = max(0.0, _beat_flash - delta * 4.0)
	_mode_switch_flash = max(0.0, _mode_switch_flash - delta * 5.0)
	queue_redraw()

# ============================================================
# 布局计算（从底部向上排列）
# ============================================================

func _calculate_layout() -> void:
	_content_start_x = (size.x - _total_content_width) / 2.0 + 10.0

	# 从底部向上排列
	# 序列器单元格行在底部
	_seq_row_y = size.y - BOTTOM_PADDING - SEQUENCER_ROW_HEIGHT
	# 调色板行在序列器上方
	_palette_row_y = _seq_row_y - 8.0 - PALETTE_ROW_HEIGHT

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	_calculate_layout()

	var start_x := _content_start_x
	var font := ThemeDB.fallback_font

	# 背景
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)

	# ========== 顶部标题栏 ==========
	var title_y := _palette_row_y - MODE_LABEL_HEIGHT - 2
	draw_string(font, Vector2(start_x, title_y + 12), "SEQUENCER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.55, 0.75))

	# 编辑模式指示
	var mode_text := ""
	var mode_color := Color(0.0, 0.8, 0.6)
	match _edit_mode:
		"note":
			mode_text = "NOTE [%s]" % MusicData.WHITE_KEY_STATS.get(_selected_note, {}).get("name", "C")
			mode_color = Color(0.0, 0.8, 0.6)
		"chord":
			mode_text = "CHORD [%d/3]" % _chord_notes.size()
			mode_color = Color(1.0, 0.8, 0.0)
		"rest":
			mode_text = "REST MODE"
			mode_color = Color(0.5, 0.5, 0.6)

	if _mode_switch_flash > 0:
		mode_color = mode_color.lerp(_mode_switch_color, _mode_switch_flash)

	draw_string(font, Vector2(start_x + 90, title_y + 12), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, mode_color)

	# 节拍信息
	var beat_in_measure := GameManager.get_beat_in_measure()
	var beat_text := "Beat: %d/%d" % [beat_in_measure + 1, BEATS_PER_MEASURE]
	draw_string(font, Vector2(start_x + _total_content_width - 80, title_y + 12), beat_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 9, Color(0.4, 0.35, 0.5))

	# 操作提示
	var help_text := "左键:放置  右键:清除  滚轮:切换音符  1-7:选音符  Q/W/E:切模式  H:快捷键"
	draw_string(font, Vector2(start_x + 250, title_y + 12), help_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.35, 0.3, 0.45, 0.6))

	# ========== 音符调色板（在序列器上方）==========
	_draw_note_palette(start_x, _palette_row_y, font)

	# ========== 序列器单元格（在底部）==========
	_draw_sequencer_cells(start_x, _seq_row_y, font)

	# ========== 播放头 ==========
	_draw_playhead(start_x, _seq_row_y, font)

	# ========== 拖拽幽灵 ==========
	if _is_dragging and _drag_started and _drag_note >= 0:
		var drag_color: Color = MusicData.NOTE_COLORS.get(_drag_note, Color(0.0, 1.0, 0.8))
		drag_color.a = DRAG_GHOST_ALPHA
		var ghost_rect := Rect2(_drag_position - CELL_SIZE / 2.0, CELL_SIZE)
		draw_rect(ghost_rect, drag_color)
		var note_name: String = MusicData.WHITE_KEY_STATS.get(_drag_note, {}).get("name", "?")
		draw_string(font, _drag_position + Vector2(-4, 5), note_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 1.0, 1.0, 0.6))

	# ========== 工具提示（在面板上方显示）==========
	if _tooltip_visible and not _tooltip_text.is_empty():
		_draw_tooltip(font)

	# ========== 右键菜单 ==========
	if _context_menu_visible:
		_draw_context_menu(font)

	# ========== 快捷键覆盖层 ==========
	if _show_shortcuts:
		_draw_shortcuts_overlay(font)

# ============================================================
# 序列器单元格绘制
# ============================================================

func _draw_sequencer_cells(start_x: float, start_y: float, font: Font) -> void:
	for measure in range(MEASURES):
		var measure_x := start_x + measure * BEATS_PER_MEASURE * (CELL_SIZE.x + CELL_MARGIN) + measure * MEASURE_GAP
		# 小节号
		var measure_label := "M%d" % (measure + 1)
		draw_string(font, Vector2(measure_x, start_y - 3), measure_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.45, 0.4, 0.55))

		for beat in range(BEATS_PER_MEASURE):
			var idx := measure * BEATS_PER_MEASURE + beat
			var cell_x := start_x + idx * (CELL_SIZE.x + CELL_MARGIN) + measure * MEASURE_GAP
			var cell_rect := Rect2(Vector2(cell_x, start_y), CELL_SIZE)

			# 单元格背景
			var cell_color := CELL_EMPTY_COLOR
			if idx < _sequencer_data.size():
				var slot: Dictionary = _sequencer_data[idx]
				match slot.get("type", "rest"):
					"note":
						var note_key = slot.get("note", 0)
						cell_color = MusicData.NOTE_COLORS.get(note_key, Color(0.0, 1.0, 0.8))
						cell_color.a = 0.6
					"chord":
						cell_color = Color(1.0, 0.84, 0.0, 0.6)
					"chord_sustain":
						cell_color = Color(1.0, 0.84, 0.0, 0.3)
					"rest":
						cell_color = REST_COLOR

			# 悬停高亮
			if idx == _hover_cell_idx and not (_is_dragging and _drag_started):
				cell_color = cell_color.lightened(0.2)
				cell_color.a = max(cell_color.a, 0.5)

			# 多选高亮
			if idx in _selected_cells:
				cell_color = cell_color.lightened(0.15)
				cell_color.a = max(cell_color.a, 0.7)

			draw_rect(cell_rect, cell_color)

			# 多选边框
			if idx in _selected_cells:
				draw_rect(cell_rect, Color(0.3, 0.55, 1.0, 0.6), false, 2.0)

			# 拖拽目标高亮
			if _is_dragging and _drag_started and idx == _hover_cell_idx:
				draw_rect(cell_rect, Color(1.0, 1.0, 1.0, 0.15))
				if _drag_note >= 0:
					var preview_color: Color = MusicData.NOTE_COLORS.get(_drag_note, Color(0.0, 1.0, 0.8))
					preview_color.a = 0.2
					draw_rect(cell_rect, preview_color)

			# 单元格边框
			var border_color := Color(0.25, 0.22, 0.35, 0.3)
			if idx == _hover_cell_idx:
				border_color = Color(0.5, 0.45, 0.65, 0.6)
			draw_rect(cell_rect, border_color, false, 1.0)

			# 音符名称 / 和弦标记
			if idx < _sequencer_data.size():
				var slot: Dictionary = _sequencer_data[idx]
				if slot.get("type", "") == "note":
					var note_key = slot.get("note", 0)
					var note_name: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
					var text_pos := Vector2(cell_x + CELL_SIZE.x / 2.0 - 4, start_y + CELL_SIZE.y / 2.0 + 4)
					draw_string(font, text_pos, note_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)
					# 音符底部小色条
					draw_rect(Rect2(Vector2(cell_x + 4, start_y + CELL_SIZE.y - 4), Vector2(CELL_SIZE.x - 8, 3)),
						MusicData.NOTE_COLORS.get(note_key, Color.WHITE))
				elif slot.get("type", "") == "chord":
					var text_pos := Vector2(cell_x + CELL_SIZE.x / 2.0 - 6, start_y + CELL_SIZE.y / 2.0 + 4)
					draw_string(font, text_pos, "CHORD", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.WHITE)
					draw_rect(Rect2(Vector2(cell_x + 4, start_y + CELL_SIZE.y - 4), Vector2(CELL_SIZE.x - 8, 3)),
						Color(1.0, 0.84, 0.0))
				elif slot.get("type", "") == "chord_sustain":
					var text_pos := Vector2(cell_x + CELL_SIZE.x / 2.0 - 2, start_y + CELL_SIZE.y / 2.0 + 3)
					draw_string(font, text_pos, "~", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 0.84, 0.0, 0.5))
				elif slot.get("type", "") == "rest":
					var rest_pos := Vector2(cell_x + CELL_SIZE.x / 2.0 - 3, start_y + CELL_SIZE.y / 2.0 + 3)
					draw_string(font, rest_pos, "—", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.4, 0.35, 0.5, 0.5))

			# 强拍标记
			if beat == 0:
				draw_rect(Rect2(Vector2(cell_x, start_y + CELL_SIZE.y), Vector2(CELL_SIZE.x, 2)), Color(0.4, 0.35, 0.55, 0.4))

		# 小节分隔线
		if measure < MEASURES - 1:
			var line_x := start_x + (measure + 1) * BEATS_PER_MEASURE * (CELL_SIZE.x + CELL_MARGIN) + measure * MEASURE_GAP + MEASURE_GAP / 2.0
			draw_line(
				Vector2(line_x, start_y - 5),
				Vector2(line_x, start_y + CELL_SIZE.y + 5),
				MEASURE_LINE_COLOR, 1.0
			)

		# 节奏型标签
		if measure < _measure_rhythms.size() and not _measure_rhythms[measure].is_empty():
			var rhythm_x := measure_x + BEATS_PER_MEASURE * (CELL_SIZE.x + CELL_MARGIN) / 2.0
			var rhythm_name := _measure_rhythms[measure]
			draw_string(font, Vector2(rhythm_x - 20, start_y + CELL_SIZE.y + 14), rhythm_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.3, 0.8, 0.6, 0.8))

# ============================================================
# 播放头绘制
# ============================================================

func _draw_playhead(start_x: float, start_y: float, _font: Font) -> void:
	var playhead_idx := _playhead_position % TOTAL_CELLS
	var playhead_measure := playhead_idx / BEATS_PER_MEASURE
	var playhead_x := start_x + playhead_idx * (CELL_SIZE.x + CELL_MARGIN) + playhead_measure * MEASURE_GAP
	var playhead_rect := Rect2(Vector2(playhead_x - 1, start_y - 3), Vector2(CELL_SIZE.x + 2, CELL_SIZE.y + 6))

	var ph_color := PLAYHEAD_COLOR
	ph_color.a = 0.5 + _beat_flash * 0.5
	draw_rect(playhead_rect, ph_color, false, 2.0)

	# 播放头顶部三角
	var tri_center := Vector2(playhead_x + CELL_SIZE.x / 2.0, start_y - 6)
	var tri_points := PackedVector2Array([
		tri_center + Vector2(-4, -6),
		tri_center + Vector2(4, -6),
		tri_center + Vector2(0, 0),
	])
	draw_colored_polygon(tri_points, ph_color)

# ============================================================
# 音符调色板绘制
# ============================================================

func _draw_note_palette(start_x: float, start_y: float, font: Font) -> void:
	var palette_start_x := start_x + 42
	var palette_width := 7 * (PALETTE_CELL_SIZE.x + PALETTE_MARGIN) + 130
	draw_rect(Rect2(Vector2(start_x, start_y - 2), Vector2(palette_width, PALETTE_CELL_SIZE.y + 4)), PALETTE_BG_COLOR)

	# 标签
	draw_string(font, Vector2(start_x + 2, start_y + PALETTE_CELL_SIZE.y / 2.0 + 4), "NOTE:", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.35, 0.5))

	# 7个白键音符
	for i in range(7):
		var note_key: int = i
		var cell_x := palette_start_x + i * (PALETTE_CELL_SIZE.x + PALETTE_MARGIN)
		var cell_rect := Rect2(Vector2(cell_x, start_y), PALETTE_CELL_SIZE)

		var color: Color = MusicData.NOTE_COLORS.get(note_key, Color(0.5, 0.5, 0.5))
		color.a = 0.7

		# 选中高亮
		if note_key == _selected_note:
			color.a = 1.0
			draw_rect(cell_rect.grow(2), PALETTE_SELECTED_BORDER, false, 2.0)
			# 选中指示三角
			var tri_pos := Vector2(cell_x + PALETTE_CELL_SIZE.x / 2.0, start_y - 4)
			var tri_pts := PackedVector2Array([
				tri_pos + Vector2(-3, -4),
				tri_pos + Vector2(3, -4),
				tri_pos + Vector2(0, 0),
			])
			draw_colored_polygon(tri_pts, color)

		# 悬停高亮
		if i == _hover_palette_idx:
			color = color.lightened(0.2)

		draw_rect(cell_rect, color)

		# 音符名称
		var note_name: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
		var text_pos := Vector2(cell_x + PALETTE_CELL_SIZE.x / 2.0 - 4, start_y + PALETTE_CELL_SIZE.y / 2.0 + 4)
		draw_string(font, text_pos, note_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)

		# 快捷键提示
		draw_string(font, Vector2(cell_x + PALETTE_CELL_SIZE.x - 8, start_y + PALETTE_CELL_SIZE.y - 2), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_RIGHT, -1, 7, Color(1.0, 1.0, 1.0, 0.3))

	# 模式切换按钮
	var btn_x := palette_start_x + 7 * (PALETTE_CELL_SIZE.x + PALETTE_MARGIN) + 10
	var modes := [
		{"label": "N", "full": "音符", "mode": "note", "color": Color(0.0, 0.8, 0.6), "key": "Q"},
		{"label": "C", "full": "和弦", "mode": "chord", "color": Color(1.0, 0.84, 0.0), "key": "W"},
		{"label": "R", "full": "休止", "mode": "rest", "color": Color(0.5, 0.5, 0.6), "key": "E"},
	]
	for j in range(modes.size()):
		var btn_rect := Rect2(Vector2(btn_x + j * 36, start_y), Vector2(32, PALETTE_CELL_SIZE.y))
		var btn_color: Color = modes[j]["color"]
		var is_active: bool = _edit_mode == modes[j]["mode"]
		var is_hover := j == _hover_mode_btn

		btn_color.a = 0.8 if is_active else (0.4 if is_hover else 0.2)
		draw_rect(btn_rect, btn_color)

		if is_active:
			draw_rect(btn_rect, Color.WHITE, false, 2.0)
		elif is_hover:
			draw_rect(btn_rect, btn_color.lightened(0.3), false, 1.0)

		# 图标字母
		draw_string(font, btn_rect.position + Vector2(10, 16), modes[j]["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)
		# 快捷键提示
		draw_string(font, btn_rect.position + Vector2(10, 28), modes[j]["key"], HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(1.0, 1.0, 1.0, 0.35))
		# 模式名称（选中时显示）
		if is_active:
			draw_string(font, btn_rect.position + Vector2(1, PALETTE_CELL_SIZE.y + 10), modes[j]["full"], HORIZONTAL_ALIGNMENT_CENTER, -1, 7, btn_color)

	# 预设模板按钮（在模式按钮右侧）
	var template_x := btn_x + 3 * 36 + 15
	draw_string(font, Vector2(template_x - 2, start_y + 10), "PRESETS:", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.4, 0.35, 0.5))
	var tmpl_btn_width := 42.0
	var tmpl_btn_height := 18.0
	var tmpl_y := start_y + 16
	for i in range(min(PRESET_TEMPLATES.size(), 3)):  # 只显示前3个模板节省空间
		var template: Dictionary = PRESET_TEMPLATES[i]
		var tmpl_rect := Rect2(Vector2(template_x + i * (tmpl_btn_width + 3), tmpl_y), Vector2(tmpl_btn_width, tmpl_btn_height))
		var tmpl_color: Color = template["color"]
		tmpl_color.a = 0.5 if i == _hover_template_idx else 0.2
		draw_rect(tmpl_rect, tmpl_color)
		if i == _hover_template_idx:
			draw_rect(tmpl_rect, tmpl_color.lightened(0.3), false, 1.0)
		draw_string(font, tmpl_rect.position + Vector2(2, 12), template["icon"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)

# ============================================================
# 工具提示绘制（确保在面板内部显示）
# ============================================================

func _draw_tooltip(font: Font) -> void:
	var lines := _tooltip_text.split("\n")
	var max_width := 0.0
	for line in lines:
		var line_width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		max_width = max(max_width, line_width)

	var tt_size := Vector2(max_width + 16, lines.size() * 14 + 8)
	# 工具提示显示在鼠标上方，确保在面板内
	var tt_pos := _tooltip_position + Vector2(12, -tt_size.y - 5)

	# 确保不超出面板右边界
	if tt_pos.x + tt_size.x > size.x:
		tt_pos.x = size.x - tt_size.x - 5
	# 确保不超出面板上边界
	if tt_pos.y < 0:
		tt_pos.y = _tooltip_position.y + 15
	# 确保不超出面板下边界
	if tt_pos.y + tt_size.y > size.y:
		tt_pos.y = size.y - tt_size.y - 5

	draw_rect(Rect2(tt_pos, tt_size), Color(0.05, 0.04, 0.08, 0.92))
	draw_rect(Rect2(tt_pos, tt_size), Color(0.3, 0.28, 0.4, 0.5), false, 1.0)

	for i in range(lines.size()):
		var line_color := Color(0.85, 0.82, 0.95) if i == 0 else Color(0.6, 0.55, 0.7)
		draw_string(font, tt_pos + Vector2(8, 13 + i * 14), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, line_color)

# ============================================================
# 右键菜单绘制
# ============================================================

func _draw_context_menu(font: Font) -> void:
	var items := [
		"复制小节",
		"粘贴到小节",
		"清空小节",
		"填充当前音符",
		"应用模板...",
	]

	var menu_width := 120.0
	var item_height := 22.0
	var menu_height := items.size() * item_height + 4

	var menu_pos := _context_menu_position
	# 确保菜单在面板内
	if menu_pos.x + menu_width > size.x:
		menu_pos.x = size.x - menu_width - 5
	# 菜单向上展开（因为面板在底部）
	if menu_pos.y + menu_height > size.y:
		menu_pos.y = menu_pos.y - menu_height
	if menu_pos.y < 0:
		menu_pos.y = 0

	draw_rect(Rect2(menu_pos, Vector2(menu_width, menu_height)), Color(0.08, 0.06, 0.12, 0.95))
	draw_rect(Rect2(menu_pos, Vector2(menu_width, menu_height)), Color(0.3, 0.28, 0.4, 0.6), false, 1.0)

	for i in range(items.size()):
		var item_rect := Rect2(menu_pos + Vector2(2, 2 + i * item_height), Vector2(menu_width - 4, item_height))
		if i == _hover_context_item:
			draw_rect(item_rect, Color(0.15, 0.12, 0.25, 0.8))
		draw_string(font, item_rect.position + Vector2(8, 15), items[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.82, 0.95) if i == _hover_context_item else Color(0.6, 0.55, 0.7))

# ============================================================
# 快捷键覆盖层
# ============================================================

func _draw_shortcuts_overlay(font: Font) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.7))

	var center_x := size.x / 2.0
	var y := 10.0

	draw_string(font, Vector2(center_x - 60, y), "KEYBOARD SHORTCUTS", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.3, 0.8, 0.6))
	y += 20

	var shortcuts := [
		["1-7", "选择音符 C-B"],
		["Q / W / E", "切换: 音符/和弦/休止"],
		["左键", "放置音符（拖拽可移动）"],
		["右键", "清除单元格"],
		["滚轮", "切换选中音符"],
		["Shift+点击", "范围选择"],
		["Ctrl+C/V", "复制/粘贴"],
		["Ctrl+Z/Y", "撤销/重做"],
		["Delete", "删除选中"],
	]

	for shortcut in shortcuts:
		draw_string(font, Vector2(center_x - 100, y), shortcut[0], HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Color(1.0, 0.84, 0.0, 0.9))
		draw_string(font, Vector2(center_x - 85, y), shortcut[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.65, 0.8, 0.8))
		y += 14

# ============================================================
# 输入处理
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventKey:
		if event.pressed:
			_handle_key_input(event as InputEventKey)
		else:
			_handle_key_release(event as InputEventKey)

func _handle_key_input(event: InputEventKey) -> void:
	# 关闭右键菜单
	if _context_menu_visible and event.keycode == KEY_ESCAPE:
		_context_menu_visible = false
		get_viewport().set_input_as_handled()
		return

	# Ctrl+C: 复制选中的单元格
	if event.ctrl_pressed and event.keycode == KEY_C:
		_copy_selected()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_V:
		_paste_at_cursor()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_Z:
		if event.shift_pressed:
			_redo()
		else:
			_undo()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_Y:
		_redo()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_A:
		_select_all()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
		_delete_selected()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		_selected_cells.clear()
		get_viewport().set_input_as_handled()
	# 1-7: 快捷选择音符
	elif event.keycode >= KEY_1 and event.keycode <= KEY_7:
		_selected_note = event.keycode - KEY_1
		get_viewport().set_input_as_handled()
	# Q/W/E: 快捷切换编辑模式
	elif event.keycode == KEY_Q:
		_switch_edit_mode("note")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_W and not event.ctrl_pressed:
		_switch_edit_mode("chord")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_E and not event.ctrl_pressed:
		_switch_edit_mode("rest")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_H:
		_show_shortcuts = true
		get_viewport().set_input_as_handled()

func _handle_key_release(event: InputEventKey) -> void:
	if event.keycode == KEY_H:
		_show_shortcuts = false

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var pos := event.position

	# 关闭右键菜单
	if _context_menu_visible:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var item := _get_context_menu_item(pos)
			if item >= 0:
				_execute_context_menu_action(item)
			_context_menu_visible = false
			return
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_context_menu_visible = false
			return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 检查是否点击了模板按钮
			var template_idx := _get_template_at_position(pos)
			if template_idx >= 0:
				_apply_template_to_next_empty_measure(template_idx)
				return

			# 检查是否点击了调色板
			var palette_idx := _get_palette_at_position(pos)
			if palette_idx >= 0:
				_selected_note = palette_idx
				# 准备拖拽（但不立即开始，等移动超过阈值）
				_is_dragging = true
				_drag_started = false
				_drag_from_palette = true
				_drag_note = palette_idx
				_drag_source_idx = -1
				_drag_start_pos = pos
				_drag_position = pos
				return

			# 检查是否点击了模式按钮
			if _handle_mode_button_click(pos):
				return

			# 检查是否点击了序列器单元格
			var cell_idx := _get_cell_at_position(pos)
			if cell_idx >= 0:
				# Shift+点击：多选/范围选择
				if event.shift_pressed:
					if _selected_cells.is_empty():
						_selected_cells.append(cell_idx)
					else:
						var last := _selected_cells[-1]
						var from_idx := mini(last, cell_idx)
						var to_idx := maxi(last, cell_idx)
						for i in range(from_idx, to_idx + 1):
							if i not in _selected_cells:
								_selected_cells.append(i)
					return
				# Ctrl+点击：切换单个选择
				elif event.ctrl_pressed:
					if cell_idx in _selected_cells:
						_selected_cells.erase(cell_idx)
					else:
						_selected_cells.append(cell_idx)
					return
				else:
					_selected_cells.clear()

				# 保存撤销快照
				_push_undo_snapshot()

				# ★ 修复：左键点击直接放置当前选中的音符/休止符
				# 如果单元格有音符，准备拖拽（但先放置，拖拽需要移动超过阈值）
				if cell_idx < _sequencer_data.size():
					var slot: Dictionary = _sequencer_data[cell_idx]
					if slot.get("type", "rest") == "note":
						# 记录拖拽信息，但不立即启动拖拽
						_is_dragging = true
						_drag_started = false
						_drag_from_palette = false
						_drag_note = slot.get("note", 0)
						_drag_source_idx = cell_idx
						_drag_start_pos = pos
						_drag_position = pos
					else:
						# 空单元格或休止符：直接放置
						_place_at_cell(cell_idx)
				else:
					_place_at_cell(cell_idx)
		else:
			# 释放左键
			if _is_dragging:
				if _drag_started:
					# 拖拽完成，放置到目标位置
					_finish_drag(pos)
				else:
					# 没有真正拖拽（点击未移动），在原位放置当前选中音符
					if not _drag_from_palette:
						var cell_idx := _get_cell_at_position(pos)
						if cell_idx >= 0:
							_place_at_cell(cell_idx)
			_is_dragging = false
			_drag_started = false
			_drag_source_idx = -1
			_drag_note = -1

	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var cell_idx := _get_cell_at_position(pos)
		if cell_idx >= 0:
			# ★ 修复：右键直接清除单元格
			_push_undo_snapshot()
			SpellcraftSystem.set_sequencer_rest(cell_idx)
			cell_cleared.emit(cell_idx)
		else:
			# 不在单元格上
			_context_menu_visible = false

	elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_selected_note = (_selected_note + 1) % 7

	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_selected_note = (_selected_note + 6) % 7

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var pos := event.position

	if _is_dragging:
		_drag_position = pos
		# 检查是否超过拖拽阈值
		if not _drag_started and pos.distance_to(_drag_start_pos) > DRAG_THRESHOLD:
			_drag_started = true
		_hover_cell_idx = _get_cell_at_position(pos)
	elif _context_menu_visible:
		_hover_context_item = _get_context_menu_item(pos)
	else:
		_hover_cell_idx = _get_cell_at_position(pos)
		_hover_palette_idx = _get_palette_at_position(pos)
		_hover_mode_btn = _get_mode_button_at_position(pos)
		_hover_template_idx = _get_template_at_position(pos)
		_update_tooltip(pos)

func _finish_drag(pos: Vector2) -> void:
	var target_idx := _get_cell_at_position(pos)
	if target_idx < 0:
		return

	if _drag_from_palette:
		SpellcraftSystem.set_sequencer_note(target_idx, _drag_note)
		note_placed.emit(target_idx, _drag_note)
	else:
		if _drag_source_idx >= 0 and _drag_source_idx != target_idx:
			SpellcraftSystem.set_sequencer_rest(_drag_source_idx)
			SpellcraftSystem.set_sequencer_note(target_idx, _drag_note)
			note_placed.emit(target_idx, _drag_note)

func _place_at_cell(cell_idx: int) -> void:
	match _edit_mode:
		"note":
			SpellcraftSystem.set_sequencer_note(cell_idx, _selected_note)
			note_placed.emit(cell_idx, _selected_note)
		"rest":
			SpellcraftSystem.set_sequencer_rest(cell_idx)
			cell_cleared.emit(cell_idx)
		"chord":
			_chord_notes.append(_selected_note)
			if _chord_notes.size() >= 3:
				var measure_idx := cell_idx / BEATS_PER_MEASURE
				SpellcraftSystem.set_sequencer_chord(measure_idx, _chord_notes)
				_chord_notes.clear()

# ============================================================
# 模式切换
# ============================================================

func _switch_edit_mode(mode: String) -> void:
	if _edit_mode == mode:
		return
	_edit_mode = mode
	if mode != "chord":
		_chord_notes.clear()

	match mode:
		"note": _mode_switch_color = Color(0.0, 0.8, 0.6)
		"chord": _mode_switch_color = Color(1.0, 0.84, 0.0)
		"rest": _mode_switch_color = Color(0.5, 0.5, 0.6)
	_mode_switch_flash = 1.0

	edit_mode_changed.emit(mode)

func _handle_mode_button_click(pos: Vector2) -> bool:
	_calculate_layout()
	var palette_start_x := _content_start_x + 42
	var btn_x := palette_start_x + 7 * (PALETTE_CELL_SIZE.x + PALETTE_MARGIN) + 10
	var btn_y := _palette_row_y

	var modes := ["note", "chord", "rest"]
	for j in range(modes.size()):
		var btn_rect := Rect2(Vector2(btn_x + j * 36, btn_y), Vector2(32, PALETTE_CELL_SIZE.y))
		if btn_rect.has_point(pos):
			_switch_edit_mode(modes[j])
			return true
	return false

# ============================================================
# 预设模板系统
# ============================================================

func _apply_template_to_next_empty_measure(template_idx: int) -> void:
	if template_idx < 0 or template_idx >= PRESET_TEMPLATES.size():
		return

	var template: Dictionary = PRESET_TEMPLATES[template_idx]
	var pattern: Array = template["pattern"]
	var notes: Array = template["notes"]

	var target_measure := -1
	if _context_menu_measure >= 0:
		target_measure = _context_menu_measure
	else:
		for m in range(MEASURES):
			var is_empty := true
			for b in range(BEATS_PER_MEASURE):
				var idx := m * BEATS_PER_MEASURE + b
				if idx < _sequencer_data.size() and _sequencer_data[idx].get("type", "rest") != "rest":
					is_empty = false
					break
			if is_empty:
				target_measure = m
				break
		if target_measure < 0:
			target_measure = 0

	_push_undo_snapshot()

	for i in range(min(pattern.size(), BEATS_PER_MEASURE)):
		var idx := target_measure * BEATS_PER_MEASURE + i
		if pattern[i] == "note" and notes[i] >= 0:
			SpellcraftSystem.set_sequencer_note(idx, notes[i])
		else:
			SpellcraftSystem.set_sequencer_rest(idx)

func _apply_template_to_measure(template_idx: int, measure: int) -> void:
	if template_idx < 0 or template_idx >= PRESET_TEMPLATES.size():
		return
	if measure < 0 or measure >= MEASURES:
		return

	var template: Dictionary = PRESET_TEMPLATES[template_idx]
	var pattern: Array = template["pattern"]
	var notes: Array = template["notes"]

	_push_undo_snapshot()

	for i in range(min(pattern.size(), BEATS_PER_MEASURE)):
		var idx := measure * BEATS_PER_MEASURE + i
		if pattern[i] == "note" and notes[i] >= 0:
			SpellcraftSystem.set_sequencer_note(idx, notes[i])
		else:
			SpellcraftSystem.set_sequencer_rest(idx)

# ============================================================
# 右键菜单操作
# ============================================================

func _execute_context_menu_action(item_idx: int) -> void:
	match item_idx:
		0:
			_copy_measure(_context_menu_measure)
		1:
			_paste_measure(_context_menu_measure)
		2:
			_clear_measure(_context_menu_measure)
		3:
			_fill_measure_with_note(_context_menu_measure, _selected_note)
		4:
			_apply_template_to_measure(0, _context_menu_measure)

var _measure_clipboard: Array[Dictionary] = []

func _copy_measure(measure: int) -> void:
	_measure_clipboard.clear()
	var start := measure * BEATS_PER_MEASURE
	for i in range(BEATS_PER_MEASURE):
		if start + i < _sequencer_data.size():
			_measure_clipboard.append(_sequencer_data[start + i].duplicate())
		else:
			_measure_clipboard.append({"type": "rest"})

func _paste_measure(measure: int) -> void:
	if _measure_clipboard.is_empty():
		return
	_push_undo_snapshot()
	var start := measure * BEATS_PER_MEASURE
	for i in range(min(_measure_clipboard.size(), BEATS_PER_MEASURE)):
		var slot: Dictionary = _measure_clipboard[i]
		var idx := start + i
		match slot.get("type", "rest"):
			"note":
				SpellcraftSystem.set_sequencer_note(idx, slot.get("note", 0))
			"rest":
				SpellcraftSystem.set_sequencer_rest(idx)

func _clear_measure(measure: int) -> void:
	_push_undo_snapshot()
	var start := measure * BEATS_PER_MEASURE
	for i in range(BEATS_PER_MEASURE):
		SpellcraftSystem.set_sequencer_rest(start + i)

func _fill_measure_with_note(measure: int, note: int) -> void:
	_push_undo_snapshot()
	var start := measure * BEATS_PER_MEASURE
	for i in range(BEATS_PER_MEASURE):
		SpellcraftSystem.set_sequencer_note(start + i, note)

# ============================================================
# 工具提示
# ============================================================

func _update_tooltip(pos: Vector2) -> void:
	_tooltip_visible = false

	var cell_idx := _get_cell_at_position(pos)
	if cell_idx >= 0 and cell_idx < _sequencer_data.size():
		var slot: Dictionary = _sequencer_data[cell_idx]
		var slot_type: String = slot.get("type", "rest")
		var measure_idx := cell_idx / BEATS_PER_MEASURE
		var beat_idx := cell_idx % BEATS_PER_MEASURE
		match slot_type:
			"note":
				var note_key = slot.get("note", 0)
				var stats: Dictionary = MusicData.WHITE_KEY_STATS.get(note_key, {})
				_tooltip_text = "%s — %s\nDMG:%d  SPD:%d  DUR:%d  SIZE:%d\n小节%d 第%d拍" % [
					stats.get("name", "?"),
					stats.get("desc", ""),
					stats.get("dmg", 0),
					stats.get("spd", 0),
					stats.get("dur", 0),
					stats.get("size", 0),
					measure_idx + 1,
					beat_idx + 1,
				]
				_tooltip_visible = true
			"chord":
				_tooltip_text = "和弦 — 小节开始时触发和弦法术\n占据整个小节(4拍)\n小节%d" % (measure_idx + 1)
				_tooltip_visible = true
			"rest":
				_tooltip_text = "休止符 — 蓄力加成\n连续2个休止符触发留白清洗\n小节%d 第%d拍" % [measure_idx + 1, beat_idx + 1]
				_tooltip_visible = true
		_tooltip_position = pos
		return

	var palette_idx := _get_palette_at_position(pos)
	if palette_idx >= 0:
		var stats: Dictionary = MusicData.WHITE_KEY_STATS.get(palette_idx, {})
		_tooltip_text = "%s: %s\nDMG:%d  SPD:%d  DUR:%d  SIZE:%d\n快捷键: %d  |  点击选择 / 拖拽放置" % [
			stats.get("name", "?"),
			stats.get("desc", ""),
			stats.get("dmg", 0),
			stats.get("spd", 0),
			stats.get("dur", 0),
			stats.get("size", 0),
			palette_idx + 1,
		]
		_tooltip_visible = true
		_tooltip_position = pos

# ============================================================
# 位置计算（使用缓存的布局值）
# ============================================================

func _get_cell_at_position(mouse_pos: Vector2) -> int:
	_calculate_layout()
	var start_x := _content_start_x
	var start_y := _seq_row_y

	if mouse_pos.y < start_y or mouse_pos.y > start_y + CELL_SIZE.y:
		return -1

	for measure in range(MEASURES):
		for beat in range(BEATS_PER_MEASURE):
			var idx := measure * BEATS_PER_MEASURE + beat
			var cell_x := start_x + idx * (CELL_SIZE.x + CELL_MARGIN) + measure * MEASURE_GAP
			var cell_rect := Rect2(Vector2(cell_x, start_y), CELL_SIZE)
			if cell_rect.has_point(mouse_pos):
				return idx

	return -1

func _get_palette_at_position(mouse_pos: Vector2) -> int:
	_calculate_layout()
	var palette_start_x := _content_start_x + 42
	var palette_y := _palette_row_y

	if mouse_pos.y < palette_y or mouse_pos.y > palette_y + PALETTE_CELL_SIZE.y:
		return -1

	for i in range(7):
		var cell_x := palette_start_x + i * (PALETTE_CELL_SIZE.x + PALETTE_MARGIN)
		var cell_rect := Rect2(Vector2(cell_x, palette_y), PALETTE_CELL_SIZE)
		if cell_rect.has_point(mouse_pos):
			return i

	return -1

func _get_mode_button_at_position(mouse_pos: Vector2) -> int:
	_calculate_layout()
	var palette_start_x := _content_start_x + 42
	var btn_x := palette_start_x + 7 * (PALETTE_CELL_SIZE.x + PALETTE_MARGIN) + 10
	var btn_y := _palette_row_y

	for j in range(3):
		var btn_rect := Rect2(Vector2(btn_x + j * 36, btn_y), Vector2(32, PALETTE_CELL_SIZE.y))
		if btn_rect.has_point(mouse_pos):
			return j
	return -1

func _get_template_at_position(mouse_pos: Vector2) -> int:
	_calculate_layout()
	var palette_start_x := _content_start_x + 42
	var btn_x := palette_start_x + 7 * (PALETTE_CELL_SIZE.x + PALETTE_MARGIN) + 10
	var template_x := btn_x + 3 * 36 + 15
	var tmpl_y := _palette_row_y + 16
	var tmpl_btn_width := 42.0
	var tmpl_btn_height := 18.0

	if mouse_pos.y < tmpl_y or mouse_pos.y > tmpl_y + tmpl_btn_height:
		return -1

	for i in range(min(PRESET_TEMPLATES.size(), 3)):
		var btn_rect := Rect2(Vector2(template_x + i * (tmpl_btn_width + 3), tmpl_y), Vector2(tmpl_btn_width, tmpl_btn_height))
		if btn_rect.has_point(mouse_pos):
			return i

	return -1

func _get_context_menu_item(mouse_pos: Vector2) -> int:
	if not _context_menu_visible:
		return -1

	var items_count := 5
	var menu_width := 120.0
	var item_height := 22.0
	var menu_height := items_count * item_height + 4
	var menu_pos := _context_menu_position

	if menu_pos.x + menu_width > size.x:
		menu_pos.x = size.x - menu_width - 5
	if menu_pos.y + menu_height > size.y:
		menu_pos.y = menu_pos.y - menu_height
	if menu_pos.y < 0:
		menu_pos.y = 0

	for i in range(items_count):
		var item_rect := Rect2(menu_pos + Vector2(2, 2 + i * item_height), Vector2(menu_width - 4, item_height))
		if item_rect.has_point(mouse_pos):
			return i

	return -1

# ============================================================
# 信号回调
# ============================================================

func _on_beat_tick(beat_index: int) -> void:
	_playhead_position = beat_index
	_beat_flash = 1.0

func _on_sequencer_updated(sequence: Array) -> void:
	_sequencer_data = sequence

func _on_rhythm_changed(pattern) -> void:
	var pattern_names := {
		MusicData.RhythmPattern.EVEN_EIGHTH: "连射",
		MusicData.RhythmPattern.DOTTED: "重击",
		MusicData.RhythmPattern.SYNCOPATED: "闪避",
		MusicData.RhythmPattern.SWING: "摇摆",
		MusicData.RhythmPattern.TRIPLET: "三连",
		MusicData.RhythmPattern.REST: "蓄力",
	}
	var pattern_descs := {
		MusicData.RhythmPattern.EVEN_EIGHTH: "SIZE-1, 每拍2发",
		MusicData.RhythmPattern.DOTTED: "SPD-1, DMG+1, 击退",
		MusicData.RhythmPattern.SYNCOPATED: "施法后向后位移",
		MusicData.RhythmPattern.SWING: "S型波浪弹道",
		MusicData.RhythmPattern.TRIPLET: "DMG×50%, 3发扇形",
		MusicData.RhythmPattern.REST: "每休止+0.5 DMG/SIZE",
	}
	var current_measure := (_playhead_position / BEATS_PER_MEASURE) % MEASURES
	_measure_rhythms[current_measure] = pattern_names.get(pattern, "")
	_measure_rhythm_descs[current_measure] = pattern_descs.get(pattern, "")

# ============================================================
# 公共接口
# ============================================================

func set_edit_mode(mode: String) -> void:
	_switch_edit_mode(mode)

func set_selected_note(note: int) -> void:
	_selected_note = note

func add_chord_note(note: int) -> void:
	if note not in _chord_notes:
		_chord_notes.append(note)

func clear_chord_buffer() -> void:
	_chord_notes.clear()

func get_edit_mode() -> String:
	return _edit_mode

func get_selected_note() -> int:
	return _selected_note

func get_selected_cells() -> Array[int]:
	return _selected_cells

# ============================================================
# 复制/粘贴/撤销/重做
# ============================================================

func _push_undo_snapshot() -> void:
	var snapshot: Array = []
	for slot in _sequencer_data:
		snapshot.append(slot.duplicate())
	_undo_stack.append(snapshot)
	if _undo_stack.size() > MAX_UNDO_STEPS:
		_undo_stack.pop_front()
	_redo_stack.clear()

func _undo() -> void:
	if _undo_stack.is_empty():
		return
	var current_snapshot: Array = []
	for slot in _sequencer_data:
		current_snapshot.append(slot.duplicate())
	_redo_stack.append(current_snapshot)

	var prev_state: Array = _undo_stack.pop_back()
	_apply_snapshot(prev_state)

func _redo() -> void:
	if _redo_stack.is_empty():
		return
	var current_snapshot: Array = []
	for slot in _sequencer_data:
		current_snapshot.append(slot.duplicate())
	_undo_stack.append(current_snapshot)

	var next_state: Array = _redo_stack.pop_back()
	_apply_snapshot(next_state)

func _apply_snapshot(snapshot: Array) -> void:
	for i in range(mini(snapshot.size(), TOTAL_CELLS)):
		var slot: Dictionary = snapshot[i]
		var slot_type: String = slot.get("type", "rest")
		match slot_type:
			"note":
				SpellcraftSystem.set_sequencer_note(i, slot.get("note", 0))
			"rest":
				SpellcraftSystem.set_sequencer_rest(i)
			"chord":
				pass

func _copy_selected() -> void:
	if _selected_cells.is_empty():
		return
	_clipboard.clear()
	var sorted_cells := _selected_cells.duplicate()
	sorted_cells.sort()
	var base_idx: int = sorted_cells[0]
	for idx in sorted_cells:
		if idx < _sequencer_data.size():
			var slot_copy: Dictionary = _sequencer_data[idx].duplicate()
			slot_copy["_offset"] = idx - base_idx
			_clipboard.append(slot_copy)

func _paste_at_cursor() -> void:
	if _clipboard.is_empty() or _hover_cell_idx < 0:
		return
	_push_undo_snapshot()
	for slot_data in _clipboard:
		var offset: int = slot_data.get("_offset", 0)
		var target_idx := _hover_cell_idx + offset
		if target_idx >= 0 and target_idx < TOTAL_CELLS:
			var slot_type: String = slot_data.get("type", "rest")
			match slot_type:
				"note":
					SpellcraftSystem.set_sequencer_note(target_idx, slot_data.get("note", 0))
					note_placed.emit(target_idx, slot_data.get("note", 0))
				"rest":
					SpellcraftSystem.set_sequencer_rest(target_idx)

func _select_all() -> void:
	_selected_cells.clear()
	for i in range(TOTAL_CELLS):
		_selected_cells.append(i)

func _delete_selected() -> void:
	if _selected_cells.is_empty():
		return
	_push_undo_snapshot()
	for idx in _selected_cells:
		SpellcraftSystem.set_sequencer_rest(idx)
		cell_cleared.emit(idx)
	_selected_cells.clear()
