## sequencer_ui.gd
## v3.0 序列器 UI — 4×4 序列器网格
##
## 4小节×4拍的乐谱序列器界面，支持：
##   - Godot 内置拖拽 API（_get_drag_data / _can_drop_data / _drop_data）
##   - 音符/和弦法术的拖拽放置
##   - 右键清除、序列器内拖拽交换
##   - 播放头指示、节拍闪烁
##   - 小节线、节拍标记
##   - 撤销/重做
##
## 与 SpellcraftSystem 全局单例对接
extends Control

# ============================================================
# 信号
# ============================================================
## 音符放置到序列器时触发
signal note_placed(cell_idx: int, note: int)
## 序列器格子被清除时触发
signal cell_cleared(cell_idx: int)
## 信息悬停（供主面板信息栏使用）
signal info_hover(title: String, desc: String, color: Color)

# ============================================================
# 常量
# ============================================================
const BEATS_PER_MEASURE := 4
const MEASURES := 4
const TOTAL_CELLS := BEATS_PER_MEASURE * MEASURES

## 序列器格子尺寸
const CELL_SIZE := Vector2(52, 52)
const CELL_GAP := 6.0
const MEASURE_GAP := 14.0

## 颜色定义（遵循全局 UI 主题）
const CELL_EMPTY_BG := Color("141026A0")
const CELL_HOVER_BG := Color("9D6FFF30")
const CELL_FILLED_BG := Color("1A1433D0")
const DROP_HIGHLIGHT_COLOR := Color("00FFD466")
const PLAYHEAD_COLOR := Color("FFFFFF", 0.8)
const MEASURE_LINE_COLOR := Color("9D6FFF40")
const BEAT_LABEL_COLOR := Color("9D8FBF99")
const CELL_BORDER_COLOR := Color("9D6FFF40")

## 撤销/重做
const MAX_UNDO: int = 32

# ============================================================
# 状态
# ============================================================
## 序列器数据缓存
var _sequencer_data: Array = []
## 播放头位置
var _playhead_position: int = 0
## 节拍闪烁动画
var _beat_flash: float = 0.0
## 当前悬停的格子索引（-1 表示无）
var _hover_cell: int = -1
## 是否正在被拖拽悬停（用于 DropZone 高亮）
var _drop_hover_cell: int = -1

## 格子矩形缓存（用于命中检测）
var _cell_rects: Array[Rect2] = []

## 撤销/重做栈
var _undo_stack: Array[Array] = []
var _redo_stack: Array[Array] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	## 初始化数据
	_sequencer_data = SpellcraftSystem.get_sequencer_data()

	## 设置最小尺寸
	var total_w := MEASURES * BEATS_PER_MEASURE * (CELL_SIZE.x + CELL_GAP) + (MEASURES - 1) * MEASURE_GAP + 20
	var total_h := CELL_SIZE.y + 40  # 上方标签 + 下方留白
	custom_minimum_size = Vector2(total_w, total_h)

	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	_beat_flash = max(0.0, _beat_flash - delta * 4.0)
	queue_redraw()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var font := ThemeDB.fallback_font
	_cell_rects.clear()

	var start_x := 10.0
	var start_y := 22.0  # 留出标签空间

	## 标题
	draw_string(font, Vector2(start_x, 14), "SEQUENCER  4×4",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("9D8FBF"))

	## 绘制每个格子
	for measure in range(MEASURES):
		## 小节标签
		var measure_x := start_x + measure * (BEATS_PER_MEASURE * (CELL_SIZE.x + CELL_GAP)) + measure * MEASURE_GAP
		draw_string(font, Vector2(measure_x, start_y - 4),
			"M%d" % (measure + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, BEAT_LABEL_COLOR)

		for beat in range(BEATS_PER_MEASURE):
			var idx := measure * BEATS_PER_MEASURE + beat
			var cell_x := measure_x + beat * (CELL_SIZE.x + CELL_GAP)
			var cell_rect := Rect2(Vector2(cell_x, start_y), CELL_SIZE)
			_cell_rects.append(cell_rect)

			## 确定背景色
			var bg_color := CELL_EMPTY_BG
			if idx < _sequencer_data.size():
				var slot: Dictionary = _sequencer_data[idx]
				if slot.get("type", "rest") in ["note", "chord", "chord_sustain"]:
					bg_color = CELL_FILLED_BG

			## 悬停高亮
			if _hover_cell == idx:
				bg_color = CELL_HOVER_BG

			## 拖拽放置区高亮（谐振青脉冲）
			if _drop_hover_cell == idx:
				bg_color = DROP_HIGHLIGHT_COLOR

			## 绘制格子背景
			draw_rect(cell_rect, bg_color)
			draw_rect(cell_rect, CELL_BORDER_COLOR, false, 1.0)

			## 绘制格子内容
			if idx < _sequencer_data.size():
				_draw_cell_content(cell_rect, _sequencer_data[idx], font)

			## 节拍编号
			draw_string(font, Vector2(cell_x + CELL_SIZE.x / 2.0 - 3, start_y + CELL_SIZE.y + 12),
				"%d" % (beat + 1), HORIZONTAL_ALIGNMENT_CENTER, -1, 8, BEAT_LABEL_COLOR)

		## 小节分隔线（除最后一个小节外）
		if measure < MEASURES - 1:
			var line_x := measure_x + BEATS_PER_MEASURE * (CELL_SIZE.x + CELL_GAP) + MEASURE_GAP / 2.0 - 3
			draw_line(
				Vector2(line_x, start_y - 2),
				Vector2(line_x, start_y + CELL_SIZE.y + 2),
				MEASURE_LINE_COLOR, 1.0
			)

	## 播放头
	_draw_playhead()

## 绘制单个格子的内容
func _draw_cell_content(rect: Rect2, slot: Dictionary, font: Font) -> void:
	var slot_type: String = slot.get("type", "rest")
	match slot_type:
		"note":
			var note_key: int = slot.get("note", 0)
			var note_color: Color = IntegratedComposer.get_note_color(note_key) if has_node("/root/IntegratedComposer") else _get_note_color_fallback(note_key)
			## 音符色块背景
			var inner_rect := rect.grow(-3)
			var bg := Color(note_color.r, note_color.g, note_color.b, 0.25)
			draw_rect(inner_rect, bg)
			## 音符名称
			var name_str: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
			draw_string(font,
				rect.position + Vector2(rect.size.x / 2.0 - 6, rect.size.y / 2.0 + 5),
				name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, note_color)
			## 修饰符标记
			if slot.has("modifier"):
				draw_string(font,
					rect.position + Vector2(rect.size.x - 8, 12),
					"#", HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Color("FFD700"))
		"chord":
			## 和弦法术 — 金色标记
			var chord_color := Color("FFD700")
			var inner_rect := rect.grow(-3)
			draw_rect(inner_rect, Color(chord_color.r, chord_color.g, chord_color.b, 0.2))
			draw_string(font,
				rect.position + Vector2(rect.size.x / 2.0 - 4, rect.size.y / 2.0 + 5),
				"♫", HORIZONTAL_ALIGNMENT_CENTER, -1, 18, chord_color)
		"chord_sustain":
			## 和弦延续 — 淡金色
			var sustain_color := Color("FFD70060")
			draw_rect(rect.grow(-3), sustain_color)
			draw_string(font,
				rect.position + Vector2(rect.size.x / 2.0 - 4, rect.size.y / 2.0 + 3),
				"~", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color("FFD70099"))

## 绘制播放头指示器
func _draw_playhead() -> void:
	var pos := SpellcraftSystem.get_sequencer_position()
	if pos >= 0 and pos < _cell_rects.size():
		var rect := _cell_rects[pos]
		var flash_alpha := 0.3 + _beat_flash * 0.5
		var ph_rect := Rect2(
			rect.position - Vector2(2, 2),
			rect.size + Vector2(4, 4)
		)
		var ph_color := PLAYHEAD_COLOR
		ph_color.a = flash_alpha
		draw_rect(ph_rect, ph_color, false, 2.5)

# ============================================================
# 鼠标交互
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			## 右键清除格子
			var idx := _get_cell_at(event.position)
			if idx >= 0:
				_clear_cell(idx)

## 更新悬停状态
func _update_hover(pos: Vector2) -> void:
	var old_hover := _hover_cell
	_hover_cell = _get_cell_at(pos)
	if _hover_cell != old_hover:
		if _hover_cell >= 0:
			_emit_cell_info(_hover_cell)
		queue_redraw()

## 获取鼠标位置对应的格子索引
func _get_cell_at(pos: Vector2) -> int:
	for i in range(_cell_rects.size()):
		if _cell_rects[i].has_point(pos):
			return i
	return -1

## 发送格子信息到信息栏
func _emit_cell_info(idx: int) -> void:
	if idx < 0 or idx >= TOTAL_CELLS:
		return
	var measure := idx / BEATS_PER_MEASURE + 1
	var beat := idx % BEATS_PER_MEASURE + 1
	if idx < _sequencer_data.size():
		var slot: Dictionary = _sequencer_data[idx]
		var slot_type: String = slot.get("type", "rest")
		match slot_type:
			"note":
				var note_key: int = slot.get("note", 0)
				var note_name: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
				var note_color := _get_note_color_fallback(note_key)
				info_hover.emit(
					"%s 音符 — M%d B%d" % [note_name, measure, beat],
					"右键清除 | 可拖出交换位置",
					note_color
				)
			"chord":
				info_hover.emit(
					"和弦法术 — M%d B%d" % [measure, beat],
					"和弦法术占据此位置 | 右键清除",
					Color("FFD700")
				)
			_:
				info_hover.emit(
					"空位 — M%d B%d" % [measure, beat],
					"拖入音符或和弦法术",
					Color("9D8FBF")
				)
	else:
		info_hover.emit(
			"空位 — M%d B%d" % [measure, beat],
			"拖入音符或和弦法术",
			Color("9D8FBF")
		)

# ============================================================
# Godot 内置拖拽 API
# ============================================================

## 从序列器格子开始拖拽（拖出已放置的音符）
func _get_drag_data(at_position: Vector2) -> Variant:
	var idx := _get_cell_at(at_position)
	if idx < 0 or idx >= _sequencer_data.size():
		return null

	var slot: Dictionary = _sequencer_data[idx]
	var slot_type: String = slot.get("type", "rest")

	if slot_type == "note":
		var note_key: int = slot.get("note", 0)
		var note_name: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
		var note_color := _get_note_color_fallback(note_key)

		## 创建拖拽预览
		var preview := _create_drag_preview(note_name, note_color)
		set_drag_preview(preview)

		## 返回拖拽数据
		return {
			"type": "note",
			"note_key": note_key,
			"source": "sequencer",
			"source_idx": idx,
		}
	elif slot_type == "chord":
		var spell_id: String = slot.get("spell_id", "")
		var preview := _create_drag_preview("♫", Color("FFD700"))
		set_drag_preview(preview)
		return {
			"type": "chord_spell",
			"spell_id": spell_id,
			"source": "sequencer",
			"source_idx": idx,
		}

	return null

## 判断是否可以接受拖拽放置
func _can_drop_data(at_position: Vector2, data) -> bool:
	if data == null or not data is Dictionary:
		_drop_hover_cell = -1
		return false

	var idx := _get_cell_at(at_position)
	if idx < 0:
		_drop_hover_cell = -1
		return false

	var drag_type: String = data.get("type", "")

	## 音符可以放到任何格子
	if drag_type == "note":
		_drop_hover_cell = idx
		queue_redraw()
		return true

	## 和弦法术可以放到任何格子
	if drag_type == "chord_spell":
		_drop_hover_cell = idx
		queue_redraw()
		return true

	## 黑键修饰符只能放到已有音符的格子上
	if drag_type == "black_key":
		if idx < _sequencer_data.size() and _sequencer_data[idx].get("type", "rest") == "note":
			_drop_hover_cell = idx
			queue_redraw()
			return true

	_drop_hover_cell = -1
	return false

## 处理拖拽放置
func _drop_data(at_position: Vector2, data) -> void:
	_drop_hover_cell = -1

	if data == null or not data is Dictionary:
		return

	var idx := _get_cell_at(at_position)
	if idx < 0:
		return

	var drag_type: String = data.get("type", "")
	var source: String = data.get("source", "")

	match drag_type:
		"note":
			var note_key: int = data.get("note_key", 0)
			if source == "sequencer":
				## 序列器内部交换
				var from_idx: int = data.get("source_idx", -1)
				if from_idx >= 0 and from_idx != idx:
					_swap_cells(from_idx, idx)
			elif source == "inventory":
				## 从库存放入序列器
				_place_note(idx, note_key)
			elif source == "alchemy":
				## 从炼成槽拖回（当作新放置）
				_place_note(idx, note_key)
		"chord_spell":
			var spell_id: String = data.get("spell_id", "")
			if source == "sequencer":
				var from_idx: int = data.get("source_idx", -1)
				if from_idx >= 0 and from_idx != idx:
					_swap_cells(from_idx, idx)
			else:
				_place_chord(idx, spell_id)
		"black_key":
			var black_key_idx: int = data.get("black_key_idx", 0)
			_apply_modifier(idx, black_key_idx)

	queue_redraw()

# ============================================================
# 序列器操作
# ============================================================

## 放置音符到指定位置
func _place_note(idx: int, note_key: int) -> void:
	_push_undo()
	SpellcraftSystem.set_sequencer_note(idx, note_key)
	_sequencer_data = SpellcraftSystem.get_sequencer_data()
	note_placed.emit(idx, note_key)

## 放置和弦法术到指定位置
func _place_chord(idx: int, spell_id: String) -> void:
	_push_undo()
	var measure := idx / BEATS_PER_MEASURE
	SpellcraftSystem.set_sequencer_chord(measure, spell_id)
	_sequencer_data = SpellcraftSystem.get_sequencer_data()

## 清除指定位置
func _clear_cell(idx: int) -> void:
	if idx < 0 or idx >= _sequencer_data.size():
		return
	var slot: Dictionary = _sequencer_data[idx]
	if slot.get("type", "rest") == "rest":
		return
	_push_undo()
	SpellcraftSystem.set_sequencer_rest(idx)
	_sequencer_data = SpellcraftSystem.get_sequencer_data()
	cell_cleared.emit(idx)

## 交换两个格子的内容
func _swap_cells(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx:
		return
	_push_undo()
	## 保存源数据
	var from_slot: Dictionary = _sequencer_data[from_idx].duplicate() if from_idx < _sequencer_data.size() else {"type": "rest"}
	var to_slot: Dictionary = _sequencer_data[to_idx].duplicate() if to_idx < _sequencer_data.size() else {"type": "rest"}

	## 先清除两个位置（归还音符到库存）
	SpellcraftSystem.set_sequencer_rest(from_idx)
	SpellcraftSystem.set_sequencer_rest(to_idx)

	## 重新放置（从库存装备）
	if to_slot.get("type", "rest") == "note":
		SpellcraftSystem.set_sequencer_note(from_idx, to_slot.get("note", 0))
	if from_slot.get("type", "rest") == "note":
		SpellcraftSystem.set_sequencer_note(to_idx, from_slot.get("note", 0))

	_sequencer_data = SpellcraftSystem.get_sequencer_data()

## 应用黑键修饰符
func _apply_modifier(idx: int, black_key_idx: int) -> void:
	if NoteInventory.equip_black_key(black_key_idx):
		if SpellcraftSystem.has_method("apply_black_key_modifier"):
			SpellcraftSystem.apply_black_key_modifier(black_key_idx)
		_sequencer_data = SpellcraftSystem.get_sequencer_data()

# ============================================================
# 撤销/重做
# ============================================================

func _push_undo() -> void:
	_undo_stack.append(_sequencer_data.duplicate(true))
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()
	_redo_stack.clear()

func undo() -> void:
	if _undo_stack.is_empty():
		return
	_redo_stack.append(_sequencer_data.duplicate(true))
	var state: Array = _undo_stack.pop_back()
	_restore_state(state)

func redo() -> void:
	if _redo_stack.is_empty():
		return
	_undo_stack.append(_sequencer_data.duplicate(true))
	var state: Array = _redo_stack.pop_back()
	_restore_state(state)

func _restore_state(state: Array) -> void:
	## 先清空所有序列器槽
	for i in range(TOTAL_CELLS):
		SpellcraftSystem.set_sequencer_rest(i)
	## 恢复状态
	for i in range(state.size()):
		var slot: Dictionary = state[i]
		if slot.get("type", "rest") == "note":
			SpellcraftSystem.set_sequencer_note(i, slot.get("note", 0))
	_sequencer_data = SpellcraftSystem.get_sequencer_data()

# ============================================================
# 外部接口
# ============================================================

## 刷新序列器数据
func refresh() -> void:
	_sequencer_data = SpellcraftSystem.get_sequencer_data()
	queue_redraw()

## 节拍回调
func on_beat_tick(_beat_index: int) -> void:
	_beat_flash = 1.0
	_playhead_position = SpellcraftSystem.get_sequencer_position()

# ============================================================
# 工具方法
# ============================================================

## 创建拖拽预览控件
func _create_drag_preview(text: String, color: Color) -> Control:
	var preview := Control.new()
	preview.custom_minimum_size = CELL_SIZE
	preview.size = CELL_SIZE

	var panel := Panel.new()
	panel.custom_minimum_size = CELL_SIZE
	panel.size = CELL_SIZE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.4)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(color.r, color.g, color.b, 0.5)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = CELL_SIZE
	label.size = CELL_SIZE
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 16)

	preview.add_child(panel)
	preview.add_child(label)
	return preview

## 音符颜色回退方法（当无法访问 IntegratedComposer 时）
func _get_note_color_fallback(note_key: int) -> Color:
	var colors := {
		0: Color("00FFD4"), 1: Color("0088FF"), 2: Color("66FF66"),
		3: Color("8844FF"), 4: Color("FF4444"), 5: Color("FF8800"),
		6: Color("FF44AA"),
	}
	return colors.get(note_key, Color(0.5, 0.5, 0.5))
