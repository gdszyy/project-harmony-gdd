## sequencer_ui.gd
## 序列器 UI
## 4小节×4拍的乐谱序列器界面
## 显示当前编排、播放进度、音符颜色
extends Control

# ============================================================
# 配置
# ============================================================
const CELL_SIZE := Vector2(48, 48)
const CELL_MARGIN := 4.0
const MEASURE_GAP := 12.0
const BEATS_PER_MEASURE := 4
const MEASURES := 4

## 颜色定义
const BG_COLOR := Color(0.05, 0.05, 0.1, 0.8)
const CELL_EMPTY_COLOR := Color(0.1, 0.1, 0.15, 0.6)
const CELL_ACTIVE_COLOR := Color(0.0, 0.8, 0.6, 0.3)
const PLAYHEAD_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const MEASURE_LINE_COLOR := Color(0.3, 0.3, 0.4, 0.5)
const REST_COLOR := Color(0.2, 0.2, 0.25, 0.4)

	# ============================================================
	# 状态
	# ============================================================
	var _playhead_position: int = 0
	var _sequencer_data: Array = []
	var _beat_flash: float = 0.0
	var _is_dragging: bool = false
	var _selected_note: int = MusicData.WhiteKey.C  # 当前选中的音符
	var _edit_mode: String = "note"  # "note", "chord", "rest"
	var _chord_notes: Array[int] = []  # 和弦构建缓冲区

# ============================================================
# 生命周期
# ============================================================

	func _ready() -> void:
		# 连接信号
		GameManager.beat_tick.connect(_on_beat_tick)
		SpellcraftSystem.sequencer_updated.connect(_on_sequencer_updated)
	
		# 初始化数据
		_sequencer_data = SpellcraftSystem.get_sequencer_data()
	
		# 设置最小尺寸
		custom_minimum_size = Vector2(
			MEASURES * BEATS_PER_MEASURE * (CELL_SIZE.x + CELL_MARGIN) + (MEASURES - 1) * MEASURE_GAP + 20,
			CELL_SIZE.y + 40
		)
		
		# Issue #14: 启用鼠标交互
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

	# 绘制每个单元格
	for measure in range(MEASURES):
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

			draw_rect(cell_rect, cell_color)

			# 单元格边框
			draw_rect(cell_rect, Color(0.3, 0.3, 0.4, 0.3), false, 1.0)

			# 音符名称
			if idx < _sequencer_data.size():
				var slot: Dictionary = _sequencer_data[idx]
				if slot.get("type", "") == "note":
					var note_key = slot.get("note", 0)
					var note_name: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
					var text_pos := Vector2(cell_x + CELL_SIZE.x / 2.0 - 4, start_y + CELL_SIZE.y / 2.0 + 4)
					draw_string(font, text_pos, note_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)
				elif slot.get("type", "") == "chord":
					var text_pos := Vector2(cell_x + CELL_SIZE.x / 2.0 - 4, start_y + CELL_SIZE.y / 2.0 + 4)
					draw_string(font, text_pos, "♪", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)

		# 小节分隔线
		if measure < MEASURES - 1:
			var line_x := start_x + (measure + 1) * BEATS_PER_MEASURE * (CELL_SIZE.x + CELL_MARGIN) + measure * MEASURE_GAP + MEASURE_GAP / 2.0
			draw_line(
				Vector2(line_x, start_y - 5),
				Vector2(line_x, start_y + CELL_SIZE.y + 5),
				MEASURE_LINE_COLOR, 1.0
			)

	# 播放头
	var playhead_idx := _playhead_position % (MEASURES * BEATS_PER_MEASURE)
	var playhead_measure := playhead_idx / BEATS_PER_MEASURE
	var playhead_x := start_x + playhead_idx * (CELL_SIZE.x + CELL_MARGIN) + playhead_measure * MEASURE_GAP
	var playhead_rect := Rect2(Vector2(playhead_x - 1, start_y - 3), Vector2(CELL_SIZE.x + 2, CELL_SIZE.y + 6))

	var ph_color := PLAYHEAD_COLOR
	ph_color.a = 0.5 + _beat_flash * 0.5
	draw_rect(playhead_rect, ph_color, false, 2.0)

	# 节拍指示器
	var beat_in_measure := GameManager.get_beat_in_measure()
	var beat_text := "Beat: %d/%d" % [beat_in_measure + 1, BEATS_PER_MEASURE]
	draw_string(font, Vector2(start_x, start_y + CELL_SIZE.y + 18), beat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 0.4, 0.5))

# ============================================================
# 信号回调
# ============================================================

func _on_beat_tick(beat_index: int) -> void:
	_playhead_position = beat_index
	_beat_flash = 1.0

	func _on_sequencer_updated(sequence: Array) -> void:
		_sequencer_data = sequence
	
	# ============================================================
	# Issue #14: 交互编辑
	# ============================================================
	
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				if mouse_event.pressed:
					_is_dragging = true
					_handle_cell_click(mouse_event.position)
				else:
					_is_dragging = false
			
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
				# 右键清除格子
				_handle_cell_clear(mouse_event.position)
		
		elif event is InputEventMouseMotion and _is_dragging:
			var mouse_motion := event as InputEventMouseMotion
			_handle_cell_click(mouse_motion.position)
	
	func _handle_cell_click(mouse_pos: Vector2) -> void:
		var cell_idx := _get_cell_at_position(mouse_pos)
		if cell_idx < 0:
			return
		
		match _edit_mode:
			"note":
				# 放置音符
				SpellcraftSystem.set_sequencer_note(cell_idx, _selected_note)
			"rest":
				# 放置休止符
				SpellcraftSystem.set_sequencer_rest(cell_idx)
			"chord":
				# 和弦模式：需要在小节开头
				var measure_idx := cell_idx / BEATS_PER_MEASURE
				if _chord_notes.size() >= 3:
					SpellcraftSystem.set_sequencer_chord(measure_idx, _chord_notes)
					_chord_notes.clear()
	
	func _handle_cell_clear(mouse_pos: Vector2) -> void:
		var cell_idx := _get_cell_at_position(mouse_pos)
		if cell_idx < 0:
			return
		
		# 清除为休止符
		SpellcraftSystem.set_sequencer_rest(cell_idx)
	
	func _get_cell_at_position(mouse_pos: Vector2) -> int:
		var total_width := custom_minimum_size.x
		var start_x := (size.x - total_width) / 2.0 + 10.0
		var start_y := 20.0
		
		# 检查是否在单元格区域内
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
	
	## 设置编辑模式
	func set_edit_mode(mode: String) -> void:
		_edit_mode = mode
	
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
