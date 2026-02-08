## sequencer_ui.gd
## 序列器 UI（增强版 v2.0）
## 4小节×4拍的乐谱序列器界面
## 支持拖拽编辑、音符调色板、和弦构建、右键清除、
## 悬停预览、节奏型指示器、小节标记
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

## 音符调色板配置
const PALETTE_CELL_SIZE := Vector2(32, 32)
const PALETTE_MARGIN := 3.0
const PALETTE_Y_OFFSET := 70.0  # 调色板在序列器下方

## 颜色定义
const BG_COLOR := Color(0.03, 0.03, 0.08, 0.85)
const CELL_EMPTY_COLOR := Color(0.08, 0.08, 0.12, 0.6)
const CELL_HOVER_COLOR := Color(0.2, 0.2, 0.3, 0.4)
const PLAYHEAD_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const MEASURE_LINE_COLOR := Color(0.3, 0.3, 0.4, 0.5)
const REST_COLOR := Color(0.15, 0.15, 0.2, 0.4)
const DRAG_GHOST_ALPHA := 0.4
const PALETTE_BG_COLOR := Color(0.05, 0.05, 0.1, 0.7)
const PALETTE_SELECTED_BORDER := Color(1.0, 1.0, 1.0, 0.9)
const CHORD_INDICATOR_COLOR := Color(1.0, 0.8, 0.0, 0.7)
const RHYTHM_LABEL_COLOR := Color(0.5, 0.5, 0.6, 0.7)

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

## 工具提示
var _tooltip_text: String = ""
var _tooltip_position: Vector2 = Vector2.ZERO
var _tooltip_visible: bool = false

## 节奏型缓存
var _measure_rhythms: Array[String] = ["", "", "", ""]

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

	# 设置最小尺寸（包含调色板区域）
	custom_minimum_size = Vector2(
		MEASURES * BEATS_PER_MEASURE * (CELL_SIZE.x + CELL_MARGIN) + (MEASURES - 1) * MEASURE_GAP + 20,
		CELL_SIZE.y + PALETTE_Y_OFFSET + PALETTE_CELL_SIZE.y + 30
	)

	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	_beat_flash = max(0.0, _beat_flash - delta * 4.0)
	queue_redraw()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var total_width := custom_minimum_size.x
	var start_x := (size.x - total_width) / 2.0 + 10.0
	var start_y := 20.0

	# 背景
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)

	# 标题
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(start_x, 15), "SEQUENCER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.6))

	# 编辑模式指示
	var mode_text := ""
	match _edit_mode:
		"note": mode_text = "[NOTE]"
		"chord": mode_text = "[CHORD %d/3]" % _chord_notes.size()
		"rest": mode_text = "[REST]"
	draw_string(font, Vector2(start_x + 80, 15), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.0, 0.8, 0.6))

	# ========== 绘制序列器单元格 ==========
	for measure in range(MEASURES):
		# 小节号
		var measure_x := start_x + measure * BEATS_PER_MEASURE * (CELL_SIZE.x + CELL_MARGIN) + measure * MEASURE_GAP
		draw_string(font, Vector2(measure_x, start_y - 3), "%d" % (measure + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.4, 0.5))

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
						cell_color = Color(1.0, 0.8, 0.0, 0.6)
					"chord_sustain":
						cell_color = Color(1.0, 0.8, 0.0, 0.3)
					"rest":
						cell_color = REST_COLOR

			# 悬停高亮
			if idx == _hover_cell_idx and not _is_dragging:
				cell_color = cell_color.lightened(0.2)
				cell_color.a = max(cell_color.a, 0.5)

			# 多选高亮
			if idx in _selected_cells:
				cell_color = cell_color.lightened(0.15)
				cell_color.a = max(cell_color.a, 0.7)

			draw_rect(cell_rect, cell_color)

			# 多选边框
			if idx in _selected_cells:
				draw_rect(cell_rect, Color(0.0, 0.8, 1.0, 0.6), false, 2.0)

			# 拖拽目标高亮
			if _is_dragging and idx == _hover_cell_idx:
				draw_rect(cell_rect, Color(1.0, 1.0, 1.0, 0.15))

			# 单元格边框
			var border_color := Color(0.3, 0.3, 0.4, 0.3)
			if idx == _hover_cell_idx:
				border_color = Color(0.5, 0.5, 0.6, 0.6)
			draw_rect(cell_rect, border_color, false, 1.0)

			# 音符名称 / 和弦标记
			if idx < _sequencer_data.size():
				var slot: Dictionary = _sequencer_data[idx]
				if slot.get("type", "") == "note":
					var note_key = slot.get("note", 0)
					var note_name: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
					var text_pos := Vector2(cell_x + CELL_SIZE.x / 2.0 - 4, start_y + CELL_SIZE.y / 2.0 + 4)
					draw_string(font, text_pos, note_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)
				elif slot.get("type", "") == "chord":
					var text_pos := Vector2(cell_x + CELL_SIZE.x / 2.0 - 6, start_y + CELL_SIZE.y / 2.0 + 4)
					draw_string(font, text_pos, "CHORD", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.WHITE)
				elif slot.get("type", "") == "chord_sustain":
					var text_pos := Vector2(cell_x + CELL_SIZE.x / 2.0 - 2, start_y + CELL_SIZE.y / 2.0 + 4)
					draw_string(font, text_pos, "~", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 0.8, 0.0, 0.5))

			# 拍号标记（强拍加粗）
			if beat == 0:
				draw_rect(Rect2(Vector2(cell_x, start_y + CELL_SIZE.y), Vector2(CELL_SIZE.x, 2)), Color(0.4, 0.4, 0.5, 0.4))

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
			draw_string(font, Vector2(rhythm_x - 20, start_y + CELL_SIZE.y + 14), _measure_rhythms[measure], HORIZONTAL_ALIGNMENT_CENTER, -1, 8, RHYTHM_LABEL_COLOR)

	# ========== 播放头 ==========
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

	# ========== 音符调色板 ==========
	_draw_note_palette(start_x, start_y + PALETTE_Y_OFFSET, font)

	# ========== 拖拽幽灵 ==========
	if _is_dragging and _drag_note >= 0:
		var drag_color: Color = MusicData.NOTE_COLORS.get(_drag_note, Color(0.0, 1.0, 0.8))
		drag_color.a = DRAG_GHOST_ALPHA
		var ghost_rect := Rect2(_drag_position - CELL_SIZE / 2.0, CELL_SIZE)
		draw_rect(ghost_rect, drag_color)
		var note_name: String = MusicData.WHITE_KEY_STATS.get(_drag_note, {}).get("name", "?")
		draw_string(font, _drag_position + Vector2(-4, 5), note_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 1.0, 1.0, 0.6))

	# ========== 工具提示 ==========
	if _tooltip_visible and not _tooltip_text.is_empty():
		var tt_size := Vector2(font.get_string_size(_tooltip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12, 18)
		var tt_pos := _tooltip_position + Vector2(10, -20)
		draw_rect(Rect2(tt_pos, tt_size), Color(0.0, 0.0, 0.0, 0.8))
		draw_rect(Rect2(tt_pos, tt_size), Color(0.3, 0.3, 0.4, 0.5), false, 1.0)
		draw_string(font, tt_pos + Vector2(6, 13), _tooltip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.8, 0.9))

	# ========== 节拍信息 ==========
	var beat_in_measure := GameManager.get_beat_in_measure()
	var beat_text := "Beat: %d/%d" % [beat_in_measure + 1, BEATS_PER_MEASURE]
	draw_string(font, Vector2(start_x, start_y + CELL_SIZE.y + 26), beat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 0.4, 0.5))

# ============================================================
# 音符调色板绘制
# ============================================================

func _draw_note_palette(start_x: float, start_y: float, font: Font) -> void:
	# 调色板背景
	var palette_width := 7 * (PALETTE_CELL_SIZE.x + PALETTE_MARGIN) + 60
	draw_rect(Rect2(Vector2(start_x, start_y - 2), Vector2(palette_width, PALETTE_CELL_SIZE.y + 4)), PALETTE_BG_COLOR)

	# 标签
	draw_string(font, Vector2(start_x + 2, start_y + PALETTE_CELL_SIZE.y / 2.0 + 4), "NOTE:", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.4, 0.5))

	# 7个白键音符
	var palette_start_x := start_x + 38
	for i in range(7):
		var note_key: int = i  # WhiteKey enum 0-6
		var cell_x := palette_start_x + i * (PALETTE_CELL_SIZE.x + PALETTE_MARGIN)
		var cell_rect := Rect2(Vector2(cell_x, start_y), PALETTE_CELL_SIZE)

		# 音符颜色
		var color: Color = MusicData.NOTE_COLORS.get(note_key, Color(0.5, 0.5, 0.5))
		color.a = 0.7

		# 选中高亮
		if note_key == _selected_note:
			color.a = 1.0
			draw_rect(cell_rect.grow(2), PALETTE_SELECTED_BORDER, false, 2.0)

		# 悬停高亮
		if i == _hover_palette_idx:
			color = color.lightened(0.2)

		draw_rect(cell_rect, color)

		# 音符名称
		var note_name: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
		var text_pos := Vector2(cell_x + PALETTE_CELL_SIZE.x / 2.0 - 4, start_y + PALETTE_CELL_SIZE.y / 2.0 + 4)
		draw_string(font, text_pos, note_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

	# 模式切换按钮
	var btn_x := palette_start_x + 7 * (PALETTE_CELL_SIZE.x + PALETTE_MARGIN) + 8
	var modes := [
		{"label": "N", "mode": "note", "color": Color(0.0, 0.8, 0.6)},
		{"label": "C", "mode": "chord", "color": Color(1.0, 0.8, 0.0)},
		{"label": "R", "mode": "rest", "color": Color(0.5, 0.5, 0.5)},
	]
	for j in range(modes.size()):
		var btn_rect := Rect2(Vector2(btn_x + j * 28, start_y + 2), Vector2(24, PALETTE_CELL_SIZE.y - 4))
		var btn_color: Color = modes[j]["color"]
		btn_color.a = 0.8 if _edit_mode == modes[j]["mode"] else 0.3
		draw_rect(btn_rect, btn_color)
		if _edit_mode == modes[j]["mode"]:
			draw_rect(btn_rect, Color.WHITE, false, 1.5)
		draw_string(font, btn_rect.position + Vector2(8, 18), modes[j]["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

# ============================================================
# 输入处理
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventKey and event.pressed:
		_handle_key_input(event as InputEventKey)

func _handle_key_input(event: InputEventKey) -> void:
	# Ctrl+C: 复制选中的单元格
	if event.ctrl_pressed and event.keycode == KEY_C:
		_copy_selected()
		get_viewport().set_input_as_handled()
	# Ctrl+V: 粘贴
	elif event.ctrl_pressed and event.keycode == KEY_V:
		_paste_at_cursor()
		get_viewport().set_input_as_handled()
	# Ctrl+Z: 撤销
	elif event.ctrl_pressed and event.keycode == KEY_Z:
		if event.shift_pressed:
			_redo()
		else:
			_undo()
		get_viewport().set_input_as_handled()
	# Ctrl+A: 全选
	elif event.ctrl_pressed and event.keycode == KEY_A:
		_select_all()
		get_viewport().set_input_as_handled()
	# Delete/Backspace: 删除选中
	elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
		_delete_selected()
		get_viewport().set_input_as_handled()
	# Escape: 取消选择
	elif event.keycode == KEY_ESCAPE:
		_selected_cells.clear()
		get_viewport().set_input_as_handled()
	# 1-7: 快捷选择音符
	elif event.keycode >= KEY_1 and event.keycode <= KEY_7:
		_selected_note = event.keycode - KEY_1
		get_viewport().set_input_as_handled()

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var pos := event.position

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 检查是否点击了调色板
			var palette_idx := _get_palette_at_position(pos)
			if palette_idx >= 0:
				_selected_note = palette_idx
				# 开始从调色板拖拽
				_is_dragging = true
				_drag_from_palette = true
				_drag_note = palette_idx
				_drag_source_idx = -1
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
						# 范围选择：从最后一个选中到当前
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
					# 普通点击：清除多选
					_selected_cells.clear()

				# 保存撤销快照
				_push_undo_snapshot()

				if cell_idx < _sequencer_data.size():
					var slot: Dictionary = _sequencer_data[cell_idx]
					if slot.get("type", "rest") == "note":
						# 拖拽已有音符
						_is_dragging = true
						_drag_from_palette = false
						_drag_note = slot.get("note", 0)
						_drag_source_idx = cell_idx
						_drag_position = pos
					else:
						# 在空格子上放置音符
						_place_at_cell(cell_idx)
				else:
					_place_at_cell(cell_idx)
		else:
			# 释放拖拽
			if _is_dragging:
				_finish_drag(pos)
			_is_dragging = false
			_drag_source_idx = -1
			_drag_note = -1

	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# 右键清除
		var cell_idx := _get_cell_at_position(pos)
		if cell_idx >= 0:
			SpellcraftSystem.set_sequencer_rest(cell_idx)
			cell_cleared.emit(cell_idx)

	elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		# 滚轮切换选中音符
		_selected_note = (_selected_note + 1) % 7

	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_selected_note = (_selected_note + 6) % 7  # -1 mod 7

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var pos := event.position

	if _is_dragging:
		_drag_position = pos
		_hover_cell_idx = _get_cell_at_position(pos)
	else:
		# 更新悬停状态
		_hover_cell_idx = _get_cell_at_position(pos)
		_hover_palette_idx = _get_palette_at_position(pos)

		# 工具提示
		_update_tooltip(pos)

func _finish_drag(pos: Vector2) -> void:
	var target_idx := _get_cell_at_position(pos)
	if target_idx < 0:
		return

	if _drag_from_palette:
		# 从调色板拖到序列器
		SpellcraftSystem.set_sequencer_note(target_idx, _drag_note)
		note_placed.emit(target_idx, _drag_note)
	else:
		# 序列器内拖拽（移动音符）
		if _drag_source_idx >= 0 and _drag_source_idx != target_idx:
			# 清除源位置
			SpellcraftSystem.set_sequencer_rest(_drag_source_idx)
			# 放置到目标位置
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

func _handle_mode_button_click(pos: Vector2) -> bool:
	var start_x := (size.x - custom_minimum_size.x) / 2.0 + 10.0
	var palette_start_x := start_x + 38
	var btn_x := palette_start_x + 7 * (PALETTE_CELL_SIZE.x + PALETTE_MARGIN) + 8
	var btn_y := 20.0 + PALETTE_Y_OFFSET + 2

	var modes := ["note", "chord", "rest"]
	for j in range(modes.size()):
		var btn_rect := Rect2(Vector2(btn_x + j * 28, btn_y), Vector2(24, PALETTE_CELL_SIZE.y - 4))
		if btn_rect.has_point(pos):
			_edit_mode = modes[j]
			if _edit_mode != "chord":
				_chord_notes.clear()
			edit_mode_changed.emit(_edit_mode)
			return true
	return false

# ============================================================
# 工具提示
# ============================================================

func _update_tooltip(pos: Vector2) -> void:
	_tooltip_visible = false

	# 序列器单元格提示
	var cell_idx := _get_cell_at_position(pos)
	if cell_idx >= 0 and cell_idx < _sequencer_data.size():
		var slot: Dictionary = _sequencer_data[cell_idx]
		var slot_type: String = slot.get("type", "rest")
		match slot_type:
			"note":
				var note_key = slot.get("note", 0)
				var stats: Dictionary = MusicData.WHITE_KEY_STATS.get(note_key, {})
				_tooltip_text = "%s — %s (DMG:%d SPD:%d)" % [
					stats.get("name", "?"),
					stats.get("desc", ""),
					stats.get("dmg", 0),
					stats.get("spd", 0),
				]
				_tooltip_visible = true
			"chord":
				_tooltip_text = "和弦 — 小节开始时触发和弦法术"
				_tooltip_visible = true
			"rest":
				_tooltip_text = "休止符 — 蓄力加成"
				_tooltip_visible = true
		_tooltip_position = pos
		return

	# 调色板提示
	var palette_idx := _get_palette_at_position(pos)
	if palette_idx >= 0:
		var stats: Dictionary = MusicData.WHITE_KEY_STATS.get(palette_idx, {})
		_tooltip_text = "%s: %s (DMG:%d SPD:%d DUR:%d SIZE:%d)" % [
			stats.get("name", "?"),
			stats.get("desc", ""),
			stats.get("dmg", 0),
			stats.get("spd", 0),
			stats.get("dur", 0),
			stats.get("size", 0),
		]
		_tooltip_visible = true
		_tooltip_position = pos

# ============================================================
# 位置计算
# ============================================================

func _get_cell_at_position(mouse_pos: Vector2) -> int:
	var total_width := custom_minimum_size.x
	var start_x := (size.x - total_width) / 2.0 + 10.0
	var start_y := 20.0

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
	var total_width := custom_minimum_size.x
	var start_x := (size.x - total_width) / 2.0 + 10.0
	var palette_start_x := start_x + 38
	var palette_y := 20.0 + PALETTE_Y_OFFSET

	if mouse_pos.y < palette_y or mouse_pos.y > palette_y + PALETTE_CELL_SIZE.y:
		return -1

	for i in range(7):
		var cell_x := palette_start_x + i * (PALETTE_CELL_SIZE.x + PALETTE_MARGIN)
		var cell_rect := Rect2(Vector2(cell_x, palette_y), PALETTE_CELL_SIZE)
		if cell_rect.has_point(mouse_pos):
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
	# 更新节奏型显示
	var pattern_names := {
		MusicData.RhythmPattern.EVEN_EIGHTH: "连射",
		MusicData.RhythmPattern.DOTTED: "重击",
		MusicData.RhythmPattern.SYNCOPATED: "闪避",
		MusicData.RhythmPattern.SWING: "摇摆",
		MusicData.RhythmPattern.TRIPLET: "三连",
		MusicData.RhythmPattern.REST: "蓄力",
	}
	# 更新当前小节的节奏型
	var current_measure := (_playhead_position / BEATS_PER_MEASURE) % MEASURES
	_measure_rhythms[current_measure] = pattern_names.get(pattern, "")

# ============================================================
# 公共接口
# ============================================================

## 设置编辑模式
func set_edit_mode(mode: String) -> void:
	_edit_mode = mode
	if mode != "chord":
		_chord_notes.clear()
	edit_mode_changed.emit(mode)

## 设置选中的音符
func set_selected_note(note: int) -> void:
	_selected_note = note

## 添加和弦音符
func add_chord_note(note: int) -> void:
	if note not in _chord_notes:
		_chord_notes.append(note)

## 清除和弦缓冲区
func clear_chord_buffer() -> void:
	_chord_notes.clear()

## 获取当前编辑模式
func get_edit_mode() -> String:
	return _edit_mode

## 获取选中音符
func get_selected_note() -> int:
	return _selected_note

## 获取多选的单元格
func get_selected_cells() -> Array[int]:
	return _selected_cells

# ============================================================
# 复制/粘贴/撤销/重做
# ============================================================

## 保存撤销快照
func _push_undo_snapshot() -> void:
	var snapshot: Array = []
	for slot in _sequencer_data:
		snapshot.append(slot.duplicate())
	_undo_stack.append(snapshot)
	if _undo_stack.size() > MAX_UNDO_STEPS:
		_undo_stack.pop_front()
	# 新操作后清除重做栈
	_redo_stack.clear()

## 撤销
func _undo() -> void:
	if _undo_stack.is_empty():
		return
	# 保存当前状态到重做栈
	var current_snapshot: Array = []
	for slot in _sequencer_data:
		current_snapshot.append(slot.duplicate())
	_redo_stack.append(current_snapshot)

	# 恢复上一个状态
	var prev_state: Array = _undo_stack.pop_back()
	_apply_snapshot(prev_state)

## 重做
func _redo() -> void:
	if _redo_stack.is_empty():
		return
	# 保存当前状态到撤销栈
	var current_snapshot: Array = []
	for slot in _sequencer_data:
		current_snapshot.append(slot.duplicate())
	_undo_stack.append(current_snapshot)

	# 恢复下一个状态
	var next_state: Array = _redo_stack.pop_back()
	_apply_snapshot(next_state)

## 应用快照状态
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
				# 和弦需要特殊处理，跳过单独恢复
				pass

## 复制选中的单元格
func _copy_selected() -> void:
	if _selected_cells.is_empty():
		return
	_clipboard.clear()
	# 按索引排序
	var sorted_cells := _selected_cells.duplicate()
	sorted_cells.sort()
	var base_idx: int = sorted_cells[0]
	for idx in sorted_cells:
		if idx < _sequencer_data.size():
			var slot_copy := _sequencer_data[idx].duplicate()
			slot_copy["_offset"] = idx - base_idx
			_clipboard.append(slot_copy)

## 粘贴到当前悬停位置
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

## 全选
func _select_all() -> void:
	_selected_cells.clear()
	for i in range(TOTAL_CELLS):
		_selected_cells.append(i)

## 删除选中的单元格
func _delete_selected() -> void:
	if _selected_cells.is_empty():
		return
	_push_undo_snapshot()
	for idx in _selected_cells:
		SpellcraftSystem.set_sequencer_rest(idx)
		cell_cleared.emit(idx)
	_selected_cells.clear()
