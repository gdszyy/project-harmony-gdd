## 和弦构建器面板（v1.0 — 全新交互组件）
##
## 提供可视化的和弦编辑体验：
##   1. 钢琴键盘式音符选择：直观的12键钢琴键盘，点击选择音符
##   2. 实时和弦识别预览：选中音符时即时显示和弦类型
##   3. 和弦效果预览：显示法术形态、伤害倍率、不和谐度
##   4. 和弦进行引导：显示当前和弦的功能(T/PD/D)和推荐的下一个和弦
##   5. 常用和弦快捷面板：预设常用和弦组合，一键放置
##   6. 和弦构建过程可视化：实时反馈选中音符组合
##
## 使用方式：
##   - 在序列器 UI 切换到和弦模式(C)时自动展开
##   - 也可通过 HUD 按钮手动打开
extends Control

# ============================================================
# 信号
# ============================================================
signal chord_confirmed(chord_notes: Array, target_measure: int)
signal chord_preview_changed(chord_type: Variant)
signal panel_closed()

# ============================================================
# 配置
# ============================================================
## 面板尺寸
const PANEL_WIDTH := 420.0
const PANEL_HEIGHT := 360.0
const PANEL_PADDING := 12.0

## 钢琴键盘配置
const PIANO_KEY_WIDTH := 28.0
const PIANO_WHITE_KEY_HEIGHT := 80.0
const PIANO_BLACK_KEY_HEIGHT := 50.0
const PIANO_BLACK_KEY_WIDTH := 18.0
const PIANO_Y_OFFSET := 50.0

## 和弦预设面板配置
const PRESET_BTN_WIDTH := 60.0
const PRESET_BTN_HEIGHT := 28.0
const PRESET_Y_OFFSET := 150.0

## 效果预览面板配置
const PREVIEW_Y_OFFSET := 210.0
const PREVIEW_HEIGHT := 80.0

## 进行引导面板配置
const GUIDE_Y_OFFSET := 300.0
const GUIDE_HEIGHT := 50.0

## 动画
const OPEN_DURATION := 0.2
const CLOSE_DURATION := 0.15

# ============================================================
# 常用和弦预设
# ============================================================
const CHORD_PRESETS: Array[Dictionary] = [
	{
		"name": "C大三",
		"notes": [0, 4, 7],  # C E G
		"display": "C-E-G",
		"type": "MAJOR",
		"color": Color(0.3, 0.6, 1.0),
	},
	{
		"name": "A小三",
		"notes": [9, 0, 4],  # A C E
		"display": "A-C-E",
		"type": "MINOR",
		"color": Color(0.6, 0.3, 0.8),
	},
	{
		"name": "G属七",
		"notes": [7, 11, 2, 5],  # G B D F
		"display": "G-B-D-F",
		"type": "DOM7",
		"color": Color(1.0, 0.8, 0.0),
	},
	{
		"name": "C增三",
		"notes": [0, 4, 8],  # C E G#
		"display": "C-E-G#",
		"type": "AUG",
		"color": Color(1.0, 0.4, 0.2),
	},
	{
		"name": "B减三",
		"notes": [11, 2, 5],  # B D F
		"display": "B-D-F",
		"type": "DIM",
		"color": Color(0.8, 0.2, 0.3),
	},
	{
		"name": "F挂留",
		"notes": [5, 10, 0],  # F Bb C
		"display": "F-Bb-C",
		"type": "SUS",
		"color": Color(0.4, 0.7, 0.5),
	},
]

# ============================================================
# 钢琴键盘布局
# ============================================================
## 12个半音的键盘信息
const PIANO_KEYS := [
	{"note": 0,  "name": "C",  "is_black": false, "white_idx": 0},
	{"note": 1,  "name": "C#", "is_black": true,  "white_idx": 0},
	{"note": 2,  "name": "D",  "is_black": false, "white_idx": 1},
	{"note": 3,  "name": "D#", "is_black": true,  "white_idx": 1},
	{"note": 4,  "name": "E",  "is_black": false, "white_idx": 2},
	{"note": 5,  "name": "F",  "is_black": false, "white_idx": 3},
	{"note": 6,  "name": "F#", "is_black": true,  "white_idx": 3},
	{"note": 7,  "name": "G",  "is_black": false, "white_idx": 4},
	{"note": 8,  "name": "G#", "is_black": true,  "white_idx": 4},
	{"note": 9,  "name": "A",  "is_black": false, "white_idx": 5},
	{"note": 10, "name": "A#", "is_black": true,  "white_idx": 5},
	{"note": 11, "name": "B",  "is_black": false, "white_idx": 6},
]

## 白键的 x 偏移索引
const WHITE_KEY_COUNT := 7

# ============================================================
# 和弦功能颜色
# ============================================================
const FUNC_COLORS := {
	"T": Color(0.3, 0.55, 1.0),     # 主功能 - 蓝
	"PD": Color(0.6, 0.35, 0.9),    # 下属功能 - 紫
	"D": Color(1.0, 0.8, 0.0),      # 属功能 - 金
}

# ============================================================
# 状态
# ============================================================
var _is_open: bool = false
var _open_progress: float = 0.0
var _selected_notes: Array[int] = []  # 当前选中的音符 (MIDI 0-11)
var _hover_key: int = -1
var _hover_preset: int = -1
var _target_measure: int = 0  # 目标小节

## 和弦识别结果缓存
var _identified_chord: Variant = null  # Dictionary or null
var _chord_function: MusicData.ChordFunction = MusicData.ChordFunction.TONIC
var _chord_spell_info: Dictionary = {}
var _chord_dissonance: float = 0.0

## 进行引导
var _last_chord_function: String = ""
var _recommended_functions: Array[String] = []
var _recommended_desc: String = ""

## 确认按钮悬停
var _hover_confirm: bool = false
var _hover_clear: bool = false
var _hover_close: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50

	# 获取上一个和弦的功能
	_update_last_chord_function()

func _process(delta: float) -> void:
	if _is_open:
		_open_progress = min(1.0, _open_progress + delta / OPEN_DURATION)
	else:
		_open_progress = max(0.0, _open_progress - delta / CLOSE_DURATION)
		if _open_progress <= 0.0 and visible:
			visible = false

	if visible:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventKey and event.pressed:
		_handle_key_input(event as InputEventKey)

# ============================================================
# 开关控制
# ============================================================

func open(target_measure: int = 0) -> void:
	_is_open = true
	_target_measure = target_measure
	visible = true
	_update_last_chord_function()
	_update_recommendations()

func close() -> void:
	_is_open = false
	panel_closed.emit()

# ============================================================
# 绘制逻辑
# ============================================================

func _draw() -> void:
	if not visible:
		return

	var alpha := _open_progress
	var panel_rect := Rect2(Vector2.ZERO, Vector2(PANEL_WIDTH, PANEL_HEIGHT * alpha))
	
	# 背景阴影
	draw_rect(Rect2(Vector2(4, 4), panel_rect.size), Color(0, 0, 0, 0.3 * alpha))
	# 主背景
	draw_rect(panel_rect, Color(0.08, 0.07, 0.12, 0.95 * alpha))
	# 边框
	draw_rect(panel_rect, Color(0.3, 0.25, 0.45, 0.8 * alpha), false, 1.5)

	if _open_progress < 0.5:
		return

	var font := ThemeDB.fallback_font
	var x := PANEL_PADDING
	var y := PANEL_PADDING

	# 标题
	draw_string(font, Vector2(x, y + 18), "CHORD BUILDER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.65, 0.85, alpha))
	
	# 顶部按钮
	_draw_top_buttons(font, alpha)

	# 1. 钢琴键盘
	_draw_piano_keyboard(x, y + PIANO_Y_OFFSET, font, alpha)

	# 2. 当前选中音符显示
	_draw_selection_info(x, y + PIANO_Y_OFFSET + PIANO_WHITE_KEY_HEIGHT + 10, font, alpha)

	# 3. 和弦预设
	_draw_chord_presets(x, y + PRESET_Y_OFFSET, font, alpha)

	# 4. 效果预览
	_draw_effect_preview(x, y + PREVIEW_Y_OFFSET, font, alpha)

	# 5. 进行引导
	_draw_progression_guide(x, y + GUIDE_Y_OFFSET, font, alpha)

	# 6. 确认按钮
	_draw_confirm_button(font, alpha)

func _draw_top_buttons(font: Font, alpha: float) -> void:
	# 关闭按钮 (X)
	var close_rect := Rect2(Vector2(PANEL_WIDTH - 30, 8), Vector2(22, 22))
	var close_color := Color(0.8, 0.3, 0.3, alpha) if _hover_close else Color(0.5, 0.4, 0.4, alpha)
	draw_rect(close_rect, close_color, false, 1.5)
	draw_string(font, close_rect.position + Vector2(7, 16), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, close_color)

	# 清空按钮
	var clear_rect := Rect2(Vector2(PANEL_WIDTH - 80, 8), Vector2(45, 22))
	var clear_color := Color(0.7, 0.7, 0.7, alpha) if _hover_clear else Color(0.4, 0.4, 0.4, alpha)
	draw_rect(clear_rect, clear_color, false, 1.0)
	draw_string(font, clear_rect.position + Vector2(6, 15), "CLEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, clear_color)

func _draw_piano_keyboard(x: float, y: float, font: Font, alpha: float) -> void:
	# 先画白键
	for i in range(WHITE_KEY_COUNT):
		var key_rect := Rect2(Vector2(x + i * PIANO_KEY_WIDTH, y), Vector2(PIANO_KEY_WIDTH - 1, PIANO_WHITE_KEY_HEIGHT))
		
		# 查找对应的 MIDI 音符
		var note := -1
		for k in PIANO_KEYS:
			if not k["is_black"] and k["white_idx"] == i:
				note = k["note"]
				break
		
		var is_selected := _selected_notes.has(note)
		var is_hover := _hover_key == note
		
		var key_color := Color(0.9, 0.9, 0.95, alpha)
		if is_selected:
			key_color = Color(0.4, 0.6, 1.0, alpha)
		elif is_hover:
			key_color = Color(0.7, 0.75, 0.85, alpha)
			
		draw_rect(key_rect, key_color)
		draw_rect(key_rect, Color(0.2, 0.2, 0.3, 0.5 * alpha), false, 1.0)
		
		# 键位标签
		var label_color := Color(0.1, 0.1, 0.2, 0.6 * alpha)
		draw_string(font, key_rect.position + Vector2(PIANO_KEY_WIDTH/2 - 4, PIANO_WHITE_KEY_HEIGHT - 6), PIANO_KEYS[note]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, label_color)

	# 再画黑键
	for k in PIANO_KEYS:
		if k["is_black"]:
			var white_idx: int = k["white_idx"]
			var note: int = k["note"]
			var key_x := x + (white_idx + 1) * PIANO_KEY_WIDTH - PIANO_BLACK_KEY_WIDTH / 2
			var key_rect := Rect2(Vector2(key_x, y), Vector2(PIANO_BLACK_KEY_WIDTH, PIANO_BLACK_KEY_HEIGHT))
			
			var is_selected := _selected_notes.has(note)
			var is_hover := _hover_key == note
			
			var key_color := Color(0.15, 0.12, 0.2, alpha)
			if is_selected:
				key_color = Color(0.3, 0.5, 0.9, alpha)
			elif is_hover:
				key_color = Color(0.25, 0.22, 0.35, alpha)
				
			draw_rect(key_rect, key_color)
			draw_rect(key_rect, Color(0.4, 0.4, 0.6, 0.3 * alpha), false, 1.0)

func _draw_selection_info(x: float, y: float, font: Font, alpha: float) -> void:
	if _selected_notes.is_empty():
		draw_string(font, Vector2(x, y + 12), "请点击键盘选择音符...", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.35, 0.5, 0.6 * alpha))
		return

	var note_text := ""
	for i in range(_selected_notes.size()):
		var note_name := _get_note_name(_selected_notes[i])
		if i > 0:
			note_text += " + "
		note_text += note_name

	draw_string(font, Vector2(x, y + 12), note_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.82, 0.95, alpha))

	# 和弦识别结果
	if _identified_chord != null:
		var chord_type: MusicData.ChordType = _identified_chord.get("type", MusicData.ChordType.MAJOR)
		var chord_name := _get_chord_type_name(chord_type)
		
		var func_key: String = ""
		match _chord_function:
			MusicData.ChordFunction.TONIC: func_key = "T"
			MusicData.ChordFunction.PREDOMINANT: func_key = "PD"
			MusicData.ChordFunction.DOMINANT: func_key = "D"

		var result_color: Color = FUNC_COLORS.get(func_key, Color(0.5, 0.5, 0.6))
		result_color.a = alpha
		draw_string(font, Vector2(x + 250, y + 12), "→ %s [%s]" % [chord_name, func_key], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, result_color)
	elif _selected_notes.size() >= 3:
		draw_string(font, Vector2(x + 250, y + 12), "无法识别", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.3, 0.3, 0.7 * alpha))

# ============================================================
# 和弦预设面板
# ============================================================

func _draw_chord_presets(x: float, y: float, font: Font, alpha: float) -> void:
	draw_string(font, Vector2(x, y + 12), "PRESETS:", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.45, 0.4, 0.55, alpha))

	var btn_x := x + 65
	for i in range(CHORD_PRESETS.size()):
		var preset: Dictionary = CHORD_PRESETS[i]
		var btn_rect := Rect2(Vector2(btn_x + i * (PRESET_BTN_WIDTH + 4), y - 2), Vector2(PRESET_BTN_WIDTH, PRESET_BTN_HEIGHT))

		var btn_color: Color = preset["color"]
		btn_color.a = 0.5 * alpha if i == _hover_preset else 0.2 * alpha
		draw_rect(btn_rect, btn_color)
		draw_rect(btn_rect, Color(btn_color.r, btn_color.g, btn_color.b, 0.8 * alpha), false, 1.0)

		draw_string(font, btn_rect.position + Vector2(4, 18), preset["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.9, 0.9, alpha))

# ============================================================
# 效果预览面板
# ============================================================

func _draw_effect_preview(x: float, y: float, font: Font, alpha: float) -> void:
	var preview_rect := Rect2(Vector2(x, y), Vector2(PANEL_WIDTH - PANEL_PADDING * 2, PREVIEW_HEIGHT))
	draw_rect(preview_rect, Color(0.15, 0.13, 0.22, 0.4 * alpha))
	draw_rect(preview_rect, Color(0.3, 0.25, 0.4, 0.3 * alpha), false, 1.0)

	if _identified_chord == null:
		draw_string(font, preview_rect.position + Vector2(10, 45), "识别和弦以预览法术效果...", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.35, 0.5, 0.5 * alpha))
		return

	var chord_type: MusicData.ChordType = _identified_chord.get("type", MusicData.ChordType.MAJOR)
	var spell_info: Dictionary = MusicData.CHORD_SPELL_MAP.get(chord_type, {})
	
	# 法术图标/名称
	draw_string(font, preview_rect.position + Vector2(15, 25), "法术形态: " + spell_info.get("name", "未知"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.85, 1.0, alpha))
	
	# 伤害倍率
	var mult: float = spell_info.get("multiplier", 1.0)
	var mult_color := Color(0.4, 1.0, 0.4, alpha) if mult >= 1.5 else Color(0.8, 0.8, 0.8, alpha)
	draw_string(font, preview_rect.position + Vector2(15, 50), "伤害倍率: x%.1f" % mult, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, mult_color)
	
	# 不和谐度
	var diss: float = MusicTheoryEngine.get_chord_dissonance(chord_type)
	draw_string(font, preview_rect.position + Vector2(150, 50), "不和谐度: %.1f" % diss, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.5, 0.3, alpha))
	
	# 描述
	var desc := "完整度和弦可触发特殊进行效果"
	draw_string(font, preview_rect.position + Vector2(15, 70), desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.55, 0.7, alpha))

# ============================================================
# 进行引导面板
# ============================================================

func _draw_progression_guide(x: float, y: float, font: Font, alpha: float) -> void:
	draw_string(font, Vector2(x, y + 12), "PROGRESSION GUIDE:", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.45, 0.4, 0.55, alpha))
	
	var guide_text := _recommended_desc
	if guide_text.is_empty():
		guide_text = "尝试构建一个三和弦..."
		
	draw_string(font, Vector2(x + 10, y + 35), guide_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.65, 0.85, alpha))

# ============================================================
# 确认按钮
# ============================================================

func _draw_confirm_button(font: Font, alpha: float) -> void:
	var btn_width := 120.0
	var btn_height := 32.0
	var btn_rect := Rect2(Vector2(PANEL_WIDTH - btn_width - PANEL_PADDING, PANEL_HEIGHT - btn_height - PANEL_PADDING), Vector2(btn_width, btn_height))
	
	var is_disabled := _selected_notes.is_empty()
	var btn_color := Color(0.2, 0.5, 0.3, alpha)
	
	if is_disabled:
		btn_color = Color(0.2, 0.2, 0.2, alpha)
	elif _hover_confirm:
		btn_color = Color(0.3, 0.7, 0.4, alpha)
		
	draw_rect(btn_rect, btn_color)
	draw_rect(btn_rect, Color(0.5, 0.8, 0.6, 0.5 * alpha), false, 1.5)
	
	var text := "PLACE CHORD"
	draw_string(font, btn_rect.position + Vector2(22, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 1.0, 0.9, alpha if not is_disabled else 0.4 * alpha))

# ============================================================
# 交互处理
# ============================================================

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
		
	if event.button_index == MOUSE_BUTTON_LEFT:
		if _hover_key != -1:
			_toggle_note(_hover_key)
		elif _hover_preset != -1:
			_apply_preset(_hover_preset)
		elif _hover_confirm:
			_confirm_chord()
		elif _hover_clear:
			_clear_selection()
		elif _hover_close:
			close()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_clear_selection()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var m_pos := event.position
	var old_hover_key := _hover_key
	var old_hover_preset := _hover_preset
	
	_hover_key = -1
	_hover_preset = -1
	_hover_confirm = false
	_hover_clear = false
	_hover_close = false

	# 检测钢琴键
	var x := PANEL_PADDING
	var y := PANEL_PADDING + PIANO_Y_OFFSET
	
	# 先检测黑键（因为在上面）
	for k in PIANO_KEYS:
		if k["is_black"]:
			var white_idx: int = k["white_idx"]
			var key_x := x + (white_idx + 1) * PIANO_KEY_WIDTH - PIANO_BLACK_KEY_WIDTH / 2
			var key_rect := Rect2(Vector2(key_x, y), Vector2(PIANO_BLACK_KEY_WIDTH, PIANO_BLACK_KEY_HEIGHT))
			if key_rect.has_point(m_pos):
				_hover_key = k["note"]
				break
				
	# 如果没点到黑键，检测白键
	if _hover_key == -1:
		for i in range(WHITE_KEY_COUNT):
			var key_rect := Rect2(Vector2(x + i * PIANO_KEY_WIDTH, y), Vector2(PIANO_KEY_WIDTH, PIANO_WHITE_KEY_HEIGHT))
			if key_rect.has_point(m_pos):
				for k in PIANO_KEYS:
					if not k["is_black"] and k["white_idx"] == i:
						_hover_key = k["note"]
						break
				break

	# 检测预设
	var preset_x := x + 65
	var preset_y := PANEL_PADDING + PRESET_Y_OFFSET
	for i in range(CHORD_PRESETS.size()):
		var btn_rect := Rect2(Vector2(preset_x + i * (PRESET_BTN_WIDTH + 4), preset_y - 2), Vector2(PRESET_BTN_WIDTH, PRESET_BTN_HEIGHT))
		if btn_rect.has_point(m_pos):
			_hover_preset = i
			break

	# 检测按钮
	var btn_width := 120.0
	var btn_height := 32.0
	var btn_rect := Rect2(Vector2(PANEL_WIDTH - btn_width - PANEL_PADDING, PANEL_HEIGHT - btn_height - PANEL_PADDING), Vector2(btn_width, btn_height))
	if btn_rect.has_point(m_pos):
		_hover_confirm = true

	var close_rect := Rect2(Vector2(PANEL_WIDTH - 30, 8), Vector2(22, 22))
	if close_rect.has_point(m_pos):
		_hover_close = true

	var clear_rect := Rect2(Vector2(PANEL_WIDTH - 80, 8), Vector2(45, 22))
	if clear_rect.has_point(m_pos):
		_hover_clear = true

	if _hover_key != old_hover_key or _hover_preset != old_hover_preset:
		queue_redraw()

func _handle_key_input(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		close()
	elif event.keycode == KEY_ENTER and not _selected_notes.is_empty():
		_confirm_chord()
	elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
		_clear_selection()

# ============================================================
# 内部逻辑
# ============================================================

func _toggle_note(note: int) -> void:
	if _selected_notes.has(note):
		_selected_notes.erase(note)
	else:
		if _selected_notes.size() < 4:  # 最多4音和弦
			_selected_notes.append(note)
			_selected_notes.sort()
			
	_update_identification()
	queue_redraw()

func _apply_preset(idx: int) -> void:
	var preset: Dictionary = CHORD_PRESETS[idx]
	_selected_notes.clear()
	for n in preset["notes"]:
		_selected_notes.append(n)
	_selected_notes.sort()
	
	_update_identification()
	queue_redraw()

func _clear_selection() -> void:
	_selected_notes.clear()
	_update_identification()
	queue_redraw()

func _update_identification() -> void:
	if _selected_notes.size() < 3:
		_identified_chord = null
		_chord_function = MusicData.ChordFunction.TONIC
		chord_preview_changed.emit(null)
		return
		
	# 调用音乐理论引擎进行识别
	var result: Variant = MusicTheoryEngine.identify_chord(_selected_notes)
	_identified_chord = result
	
	if result != null:
		var type: MusicData.ChordType = result["type"]
		_chord_function = MusicTheoryEngine.get_chord_function(type)
		chord_preview_changed.emit(type)
	else:
		_chord_function = MusicData.ChordFunction.TONIC
		chord_preview_changed.emit(null)

func _confirm_chord() -> void:
	if _selected_notes.is_empty():
		return
		
	chord_confirmed.emit(_selected_notes.duplicate(), _target_measure)
	close()

func _update_last_chord_function() -> void:
	# 从序列器获取前一个和弦的功能
	# 这里简化处理，实际应从 SequenceManager 获取
	_last_chord_function = ""

func _update_recommendations() -> void:
	if _last_chord_function.is_empty():
		_recommended_functions = ["T"]
		_recommended_desc = "从主功能开始一段乐句"
	else:
		# 简化逻辑，因为 get_recommended_next_functions 不存在
		_recommended_functions = ["D" if _last_chord_function == "T" else "T"]
		_recommended_desc = "尝试进行到" + ("属功能" if _last_chord_function == "T" else "主功能")

func _get_note_name(midi_note: int) -> String:
	for k in PIANO_KEYS:
		if k["note"] == midi_note:
			return k["name"]
	return "?"

func _get_chord_type_name(type: MusicData.ChordType) -> String:
	var info: Dictionary = MusicData.CHORD_SPELL_MAP.get(type, {})
	return info.get("name", "未知和弦")
