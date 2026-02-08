## chord_builder_panel.gd
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
const CHORD_PRESETS := [
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
var _chord_function: String = ""
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
	visible = true
	_target_measure = target_measure
	_selected_notes.clear()
	_identified_chord = null
	_update_last_chord_function()
	_update_progression_guide()

func close() -> void:
	_is_open = false
	_selected_notes.clear()
	_identified_chord = null
	panel_closed.emit()

func is_open() -> bool:
	return _is_open

func set_target_measure(measure: int) -> void:
	_target_measure = measure

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if _open_progress <= 0.0:
		return

	var font := ThemeDB.fallback_font
	var alpha := _open_progress
	var scale := 0.9 + 0.1 * _open_progress

	# 计算面板位置（居中）
	var panel_pos := (size - Vector2(PANEL_WIDTH, PANEL_HEIGHT) * scale) / 2.0
	var panel_size := Vector2(PANEL_WIDTH, PANEL_HEIGHT) * scale

	# 半透明背景遮罩
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.3 * alpha))

	# 面板背景
	draw_rect(Rect2(panel_pos, panel_size), Color(0.06, 0.04, 0.12, 0.95 * alpha))
	draw_rect(Rect2(panel_pos, panel_size), Color(0.3, 0.25, 0.45, 0.5 * alpha), false, 1.5)

	# 面板内容起始位置
	var cx := panel_pos.x + PANEL_PADDING
	var cy := panel_pos.y + PANEL_PADDING

	# ========== 标题栏 ==========
	draw_string(font, Vector2(cx, cy + 14), "CHORD BUILDER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.55, 0.75, alpha))

	# 目标小节指示
	draw_string(font, Vector2(cx + 140, cy + 14), "→ M%d" % (_target_measure + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.84, 0.0, 0.7 * alpha))

	# 关闭按钮
	var close_rect := Rect2(Vector2(panel_pos.x + panel_size.x - 30, cy), Vector2(20, 20))
	var close_color := Color(1.0, 0.3, 0.3, 0.8 * alpha) if _hover_close else Color(0.5, 0.4, 0.6, 0.6 * alpha)
	draw_rect(close_rect, close_color)
	draw_string(font, close_rect.position + Vector2(5, 14), "X", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

	# ========== 钢琴键盘 ==========
	_draw_piano_keyboard(cx, cy + PIANO_Y_OFFSET, font, alpha)

	# ========== 已选音符显示 ==========
	_draw_selected_notes_display(cx, cy + PIANO_Y_OFFSET + PIANO_WHITE_KEY_HEIGHT + 8, font, alpha)

	# ========== 和弦预设面板 ==========
	_draw_chord_presets(cx, cy + PRESET_Y_OFFSET, font, alpha)

	# ========== 效果预览面板 ==========
	_draw_effect_preview(cx, cy + PREVIEW_Y_OFFSET, font, alpha)

	# ========== 进行引导面板 ==========
	_draw_progression_guide(cx, cy + GUIDE_Y_OFFSET, font, alpha)

	# ========== 确认/清除按钮 ==========
	_draw_action_buttons(cx, cy + GUIDE_Y_OFFSET + GUIDE_HEIGHT + 2, font, alpha)

# ============================================================
# 钢琴键盘绘制
# ============================================================

func _draw_piano_keyboard(x: float, y: float, font: Font, alpha: float) -> void:
	# 先绘制白键
	for key_info in PIANO_KEYS:
		if key_info["is_black"]:
			continue
		var white_idx: int = key_info["white_idx"]
		var key_x := x + white_idx * PIANO_KEY_WIDTH
		var key_rect := Rect2(Vector2(key_x, y), Vector2(PIANO_KEY_WIDTH - 2, PIANO_WHITE_KEY_HEIGHT))
		var note: int = key_info["note"]
		var is_selected := note in _selected_notes
		var is_hover := note == _hover_key

		# 键色
		var key_color := Color(0.9, 0.88, 0.95, alpha)
		if is_selected:
			key_color = _get_note_color(note)
			key_color.a = 0.9 * alpha
		elif is_hover:
			key_color = Color(0.75, 0.72, 0.85, alpha)

		draw_rect(key_rect, key_color)
		draw_rect(key_rect, Color(0.3, 0.28, 0.4, 0.5 * alpha), false, 1.0)

		# 音符名称
		var name_color := Color.WHITE if is_selected else Color(0.2, 0.18, 0.3, alpha)
		draw_string(font, Vector2(key_x + 6, y + PIANO_WHITE_KEY_HEIGHT - 8), key_info["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, name_color)

		# 选中标记
		if is_selected:
			var dot_pos := Vector2(key_x + PIANO_KEY_WIDTH / 2.0 - 1, y + PIANO_WHITE_KEY_HEIGHT - 22)
			draw_circle(dot_pos, 4.0, Color.WHITE)

	# 再绘制黑键（覆盖在白键上方）
	for key_info in PIANO_KEYS:
		if not key_info["is_black"]:
			continue
		var white_idx: int = key_info["white_idx"]
		var key_x := x + white_idx * PIANO_KEY_WIDTH + PIANO_KEY_WIDTH - PIANO_BLACK_KEY_WIDTH / 2.0 - 1
		var key_rect := Rect2(Vector2(key_x, y), Vector2(PIANO_BLACK_KEY_WIDTH, PIANO_BLACK_KEY_HEIGHT))
		var note: int = key_info["note"]
		var is_selected := note in _selected_notes
		var is_hover := note == _hover_key

		# 键色
		var key_color := Color(0.12, 0.1, 0.18, alpha)
		if is_selected:
			key_color = _get_note_color(note)
			key_color.a = 0.85 * alpha
		elif is_hover:
			key_color = Color(0.25, 0.22, 0.35, alpha)

		draw_rect(key_rect, key_color)
		draw_rect(key_rect, Color(0.2, 0.18, 0.3, 0.6 * alpha), false, 1.0)

		# 音符名称
		var name_color := Color.WHITE if is_selected else Color(0.6, 0.55, 0.7, alpha)
		draw_string(font, Vector2(key_x + 2, y + PIANO_BLACK_KEY_HEIGHT - 6), key_info["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, name_color)

# ============================================================
# 已选音符显示
# ============================================================

func _draw_selected_notes_display(x: float, y: float, font: Font, alpha: float) -> void:
	if _selected_notes.is_empty():
		draw_string(font, Vector2(x, y + 12), "点击键盘选择音符 (至少3个)", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.45, 0.6, 0.6 * alpha))
		return

	# 显示已选音符
	var note_text := "已选: "
	for i in range(_selected_notes.size()):
		var note_name := _get_note_name(_selected_notes[i])
		if i > 0:
			note_text += " + "
		note_text += note_name

	draw_string(font, Vector2(x, y + 12), note_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.82, 0.95, alpha))

	# 和弦识别结果
	if _identified_chord != null:
		var chord_type: MusicData.ChordType = _identified_chord["type"]
		var spell_info: Dictionary = MusicData.CHORD_SPELL_MAP.get(chord_type, {})
		var chord_name := _get_chord_type_name(chord_type)
		var func_text := _chord_function

		var result_color := FUNC_COLORS.get(func_text, Color(0.5, 0.5, 0.6))
		result_color.a = alpha
		draw_string(font, Vector2(x + 250, y + 12), "→ %s [%s]" % [chord_name, func_text], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, result_color)
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

		if i == _hover_preset:
			draw_rect(btn_rect, btn_color.lightened(0.3), false, 1.0)

		# 预设名称
		draw_string(font, btn_rect.position + Vector2(4, 12), preset["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.88, 0.95, alpha))
		# 音符组合
		draw_string(font, btn_rect.position + Vector2(4, 23), preset["display"], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.6, 0.55, 0.7, 0.7 * alpha))

# ============================================================
# 效果预览面板
# ============================================================

func _draw_effect_preview(x: float, y: float, font: Font, alpha: float) -> void:
	var preview_width := PANEL_WIDTH - PANEL_PADDING * 2
	draw_rect(Rect2(Vector2(x, y), Vector2(preview_width, PREVIEW_HEIGHT)), Color(0.04, 0.03, 0.08, 0.6 * alpha))

	draw_string(font, Vector2(x + 6, y + 14), "EFFECT PREVIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.45, 0.4, 0.55, alpha))

	if _identified_chord == null:
		draw_string(font, Vector2(x + 6, y + 35), "选择至少3个音符以预览和弦效果", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 0.35, 0.5, 0.5 * alpha))
		return

	var chord_type: MusicData.ChordType = _identified_chord["type"]
	var spell_info: Dictionary = MusicData.CHORD_SPELL_MAP.get(chord_type, {})

	# 法术形态
	var spell_name: String = spell_info.get("name", "未知")
	draw_string(font, Vector2(x + 6, y + 35), "法术形态: %s" % spell_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.82, 0.95, alpha))

	# 伤害倍率
	var multiplier: float = spell_info.get("multiplier", 1.0)
	var mult_color := Color(0.0, 0.8, 0.4, alpha) if multiplier >= 1.0 else Color(1.0, 0.4, 0.2, alpha)
	if multiplier == 0.0:
		draw_string(font, Vector2(x + 6, y + 50), "伤害倍率: 治疗/辅助型", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.8, 1.0, alpha))
	else:
		draw_string(font, Vector2(x + 6, y + 50), "伤害倍率: ×%.1f" % multiplier, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, mult_color)

	# 不和谐度
	var dissonance: float = MusicData.CHORD_DISSONANCE.get(chord_type, 0.0)
	var diss_color := Color(0.0, 0.8, 0.4, alpha)
	if dissonance > 4.0:
		diss_color = Color(1.0, 0.3, 0.1, alpha)
	elif dissonance > 2.0:
		diss_color = Color(1.0, 0.8, 0.0, alpha)
	draw_string(font, Vector2(x + 6, y + 65), "不和谐度: %.1f" % dissonance, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, diss_color)

	# 不和谐度条形图
	var bar_x := x + 120
	var bar_width := 100.0
	var bar_height := 6.0
	var fill_ratio := clamp(dissonance / 10.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2(bar_x, y + 58), Vector2(bar_width, bar_height)), Color(0.1, 0.08, 0.15, 0.5 * alpha))
	draw_rect(Rect2(Vector2(bar_x, y + 58), Vector2(bar_width * fill_ratio, bar_height)), diss_color)

	# 和弦功能
	var func_text := _chord_function
	var func_full_name := {"T": "主功能(稳定)", "PD": "下属功能(准备)", "D": "属功能(紧张)"}.get(func_text, "未知")
	var func_color: Color = FUNC_COLORS.get(func_text, Color(0.5, 0.5, 0.6))
	func_color.a = alpha
	draw_string(font, Vector2(x + 250, y + 35), "功能: %s" % func_full_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, func_color)

	# 扩展和弦标记
	if MusicTheoryEngine.is_extended_chord(chord_type):
		var fatigue_cost: float = MusicData.EXTENDED_CHORD_FATIGUE.get(chord_type, 0.0)
		draw_string(font, Vector2(x + 250, y + 50), "扩展和弦 (疲劳+%.0f%%)" % (fatigue_cost * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.6, 0.2, 0.8 * alpha))
		if not GameManager.extended_chords_unlocked:
			draw_string(font, Vector2(x + 250, y + 63), "需要传说级升级解锁", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.3, 0.3, 0.7 * alpha))

# ============================================================
# 进行引导面板
# ============================================================

func _draw_progression_guide(x: float, y: float, font: Font, alpha: float) -> void:
	var guide_width := PANEL_WIDTH - PANEL_PADDING * 2
	draw_rect(Rect2(Vector2(x, y), Vector2(guide_width, GUIDE_HEIGHT)), Color(0.04, 0.03, 0.08, 0.4 * alpha))

	draw_string(font, Vector2(x + 6, y + 14), "PROGRESSION GUIDE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.45, 0.4, 0.55, alpha))

	if _last_chord_function.is_empty():
		draw_string(font, Vector2(x + 6, y + 32), "放置第一个和弦开始构建进行", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 0.35, 0.5, 0.5 * alpha))
		return

	# 上一个和弦功能
	var last_func_color: Color = FUNC_COLORS.get(_last_chord_function, Color(0.5, 0.5, 0.6))
	last_func_color.a = alpha
	draw_string(font, Vector2(x + 6, y + 32), "上一和弦: [%s]" % _last_chord_function, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, last_func_color)

	# 推荐的下一个和弦功能
	if not _recommended_functions.is_empty():
		var rec_text := "推荐: "
		var rec_x := x + 120
		for i in range(_recommended_functions.size()):
			var func_name: String = _recommended_functions[i]
			var func_color: Color = FUNC_COLORS.get(func_name, Color(0.5, 0.5, 0.6))
			func_color.a = alpha
			if i > 0:
				draw_string(font, Vector2(rec_x, y + 32), " / ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.45, 0.6, 0.6 * alpha))
				rec_x += 20
			draw_string(font, Vector2(rec_x, y + 32), "[%s]" % func_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, func_color)
			rec_x += 30

	# 推荐描述
	if not _recommended_desc.is_empty():
		draw_string(font, Vector2(x + 6, y + 45), _recommended_desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.45, 0.6, 0.6 * alpha))

# ============================================================
# 操作按钮
# ============================================================

func _draw_action_buttons(x: float, y: float, font: Font, alpha: float) -> void:
	# 确认按钮
	var confirm_rect := Rect2(Vector2(x, y), Vector2(80, 24))
	var confirm_enabled := _identified_chord != null
	var confirm_color := Color(0.0, 0.7, 0.4, 0.7 * alpha) if confirm_enabled else Color(0.3, 0.3, 0.35, 0.3 * alpha)
	if _hover_confirm and confirm_enabled:
		confirm_color = confirm_color.lightened(0.2)
	draw_rect(confirm_rect, confirm_color)
	draw_string(font, confirm_rect.position + Vector2(12, 16), "确认放置", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE if confirm_enabled else Color(0.5, 0.5, 0.5, alpha))

	# 清除按钮
	var clear_rect := Rect2(Vector2(x + 90, y), Vector2(60, 24))
	var clear_color := Color(0.6, 0.3, 0.1, 0.4 * alpha)
	if _hover_clear:
		clear_color = clear_color.lightened(0.2)
	draw_rect(clear_rect, clear_color)
	draw_string(font, clear_rect.position + Vector2(12, 16), "清除", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.82, 0.95, alpha))

	# 快捷键提示
	draw_string(font, Vector2(x + 170, y + 16), "Enter=确认  Esc=关闭  1-7=白键  Backspace=撤销", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.4, 0.35, 0.5, 0.4 * alpha))

# ============================================================
# 输入处理
# ============================================================

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	var pos := event.position

	# 检查关闭按钮
	var close_rect := _get_close_button_rect()
	if close_rect.has_point(pos):
		close()
		return

	# 检查钢琴键盘（先检查黑键，因为黑键在白键上方）
	var key_note := _get_piano_key_at_position(pos)
	if key_note >= 0:
		_toggle_note(key_note)
		return

	# 检查预设按钮
	var preset_idx := _get_preset_at_position(pos)
	if preset_idx >= 0:
		_apply_preset(preset_idx)
		return

	# 检查确认按钮
	var confirm_rect := _get_confirm_button_rect()
	if confirm_rect.has_point(pos) and _identified_chord != null:
		_confirm_chord()
		return

	# 检查清除按钮
	var clear_rect := _get_clear_button_rect()
	if clear_rect.has_point(pos):
		_selected_notes.clear()
		_update_chord_identification()
		return

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var pos := event.position
	_hover_key = _get_piano_key_at_position(pos)
	_hover_preset = _get_preset_at_position(pos)
	_hover_confirm = _get_confirm_button_rect().has_point(pos)
	_hover_clear = _get_clear_button_rect().has_point(pos)
	_hover_close = _get_close_button_rect().has_point(pos)

func _handle_key_input(event: InputEventKey) -> void:
	# Escape: 关闭
	if event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
		return

	# Enter: 确认
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if _identified_chord != null:
			_confirm_chord()
		get_viewport().set_input_as_handled()
		return

	# Backspace: 撤销最后一个音符
	if event.keycode == KEY_BACKSPACE:
		if not _selected_notes.is_empty():
			_selected_notes.pop_back()
			_update_chord_identification()
		get_viewport().set_input_as_handled()
		return

	# 1-7: 快捷选择白键
	if event.keycode >= KEY_1 and event.keycode <= KEY_7:
		var white_key_notes := [0, 2, 4, 5, 7, 9, 11]  # C D E F G A B
		var idx := event.keycode - KEY_1
		if idx < white_key_notes.size():
			_toggle_note(white_key_notes[idx])
		get_viewport().set_input_as_handled()

# ============================================================
# 音符操作
# ============================================================

func _toggle_note(note: int) -> void:
	if note in _selected_notes:
		_selected_notes.erase(note)
	else:
		_selected_notes.append(note)
	_update_chord_identification()

func _apply_preset(preset_idx: int) -> void:
	if preset_idx < 0 or preset_idx >= CHORD_PRESETS.size():
		return
	var preset: Dictionary = CHORD_PRESETS[preset_idx]
	_selected_notes.clear()
	for note in preset["notes"]:
		_selected_notes.append(note)
	_update_chord_identification()

func _confirm_chord() -> void:
	if _identified_chord == null:
		return
	chord_confirmed.emit(_selected_notes.duplicate(), _target_measure)
	close()

# ============================================================
# 和弦识别更新
# ============================================================

func _update_chord_identification() -> void:
	if _selected_notes.size() < 3:
		_identified_chord = null
		_chord_function = ""
		_chord_spell_info = {}
		_chord_dissonance = 0.0
		chord_preview_changed.emit(null)
		return

	_identified_chord = MusicTheoryEngine.identify_chord(_selected_notes)
	if _identified_chord != null:
		var chord_type: MusicData.ChordType = _identified_chord["type"]
		var func_enum := MusicTheoryEngine.get_chord_function(chord_type)
		match func_enum:
			MusicData.ChordFunction.TONIC: _chord_function = "T"
			MusicData.ChordFunction.PREDOMINANT: _chord_function = "PD"
			MusicData.ChordFunction.DOMINANT: _chord_function = "D"
		_chord_spell_info = MusicData.CHORD_SPELL_MAP.get(chord_type, {})
		_chord_dissonance = MusicData.CHORD_DISSONANCE.get(chord_type, 0.0)
	else:
		_chord_function = ""
		_chord_spell_info = {}
		_chord_dissonance = 0.0

	chord_preview_changed.emit(_identified_chord)

# ============================================================
# 进行引导更新
# ============================================================

func _update_last_chord_function() -> void:
	# 从 MusicTheoryEngine 获取最近的和弦功能
	# 这里简化处理，实际应从 _chord_history 获取
	_last_chord_function = ""

func _update_progression_guide() -> void:
	_recommended_functions.clear()
	_recommended_desc = ""

	if _last_chord_function.is_empty():
		_recommended_functions = ["T", "PD", "D"]
		_recommended_desc = "任意功能均可作为起始"
		return

	match _last_chord_function:
		"T":
			_recommended_functions = ["D"]
			_recommended_desc = "T→D: 稳定到紧张 → 下一法术伤害翻倍"
		"D":
			_recommended_functions = ["T"]
			_recommended_desc = "D→T: 紧张到解决 → 爆发治疗或全屏伤害"
		"PD":
			_recommended_functions = ["D"]
			_recommended_desc = "PD→D: 准备到紧张 → 全体冷却缩减50%"

# ============================================================
# 位置计算
# ============================================================

func _get_panel_rect() -> Rect2:
	var scale := 0.9 + 0.1 * _open_progress
	var panel_pos := (size - Vector2(PANEL_WIDTH, PANEL_HEIGHT) * scale) / 2.0
	return Rect2(panel_pos, Vector2(PANEL_WIDTH, PANEL_HEIGHT) * scale)

func _get_piano_key_at_position(pos: Vector2) -> int:
	var panel := _get_panel_rect()
	var cx := panel.position.x + PANEL_PADDING
	var cy := panel.position.y + PANEL_PADDING + PIANO_Y_OFFSET

	# 先检查黑键（优先级更高，因为在白键上方）
	for key_info in PIANO_KEYS:
		if not key_info["is_black"]:
			continue
		var white_idx: int = key_info["white_idx"]
		var key_x := cx + white_idx * PIANO_KEY_WIDTH + PIANO_KEY_WIDTH - PIANO_BLACK_KEY_WIDTH / 2.0 - 1
		var key_rect := Rect2(Vector2(key_x, cy), Vector2(PIANO_BLACK_KEY_WIDTH, PIANO_BLACK_KEY_HEIGHT))
		if key_rect.has_point(pos):
			return key_info["note"]

	# 再检查白键
	for key_info in PIANO_KEYS:
		if key_info["is_black"]:
			continue
		var white_idx: int = key_info["white_idx"]
		var key_x := cx + white_idx * PIANO_KEY_WIDTH
		var key_rect := Rect2(Vector2(key_x, cy), Vector2(PIANO_KEY_WIDTH - 2, PIANO_WHITE_KEY_HEIGHT))
		if key_rect.has_point(pos):
			return key_info["note"]

	return -1

func _get_preset_at_position(pos: Vector2) -> int:
	var panel := _get_panel_rect()
	var cx := panel.position.x + PANEL_PADDING
	var cy := panel.position.y + PANEL_PADDING + PRESET_Y_OFFSET
	var btn_x := cx + 65

	for i in range(CHORD_PRESETS.size()):
		var btn_rect := Rect2(Vector2(btn_x + i * (PRESET_BTN_WIDTH + 4), cy - 2), Vector2(PRESET_BTN_WIDTH, PRESET_BTN_HEIGHT))
		if btn_rect.has_point(pos):
			return i
	return -1

func _get_confirm_button_rect() -> Rect2:
	var panel := _get_panel_rect()
	var cx := panel.position.x + PANEL_PADDING
	var cy := panel.position.y + PANEL_PADDING + GUIDE_Y_OFFSET + GUIDE_HEIGHT + 2
	return Rect2(Vector2(cx, cy), Vector2(80, 24))

func _get_clear_button_rect() -> Rect2:
	var panel := _get_panel_rect()
	var cx := panel.position.x + PANEL_PADDING
	var cy := panel.position.y + PANEL_PADDING + GUIDE_Y_OFFSET + GUIDE_HEIGHT + 2
	return Rect2(Vector2(cx + 90, cy), Vector2(60, 24))

func _get_close_button_rect() -> Rect2:
	var panel := _get_panel_rect()
	return Rect2(Vector2(panel.position.x + panel.size.x - 30, panel.position.y + PANEL_PADDING), Vector2(20, 20))

# ============================================================
# 辅助方法
# ============================================================

func _get_note_name(note: int) -> String:
	for key_info in PIANO_KEYS:
		if key_info["note"] == note:
			return key_info["name"]
	return "?"

func _get_note_color(note: int) -> Color:
	# 白键使用 MusicData 颜色，黑键使用修饰符颜色
	match note:
		0: return Color(0.0, 1.0, 0.8)    # C
		1: return Color(0.8, 0.3, 0.5)    # C#
		2: return Color(0.2, 0.6, 1.0)    # D
		3: return Color(0.7, 0.4, 0.8)    # D#
		4: return Color(0.0, 0.8, 0.4)    # E
		5: return Color(0.6, 0.2, 0.8)    # F
		6: return Color(0.5, 0.7, 0.3)    # F#
		7: return Color(1.0, 0.3, 0.1)    # G
		8: return Color(0.9, 0.5, 0.2)    # G#
		9: return Color(1.0, 0.8, 0.0)    # A
		10: return Color(0.8, 0.6, 0.1)   # A#
		11: return Color(1.0, 0.4, 0.6)   # B
		_: return Color(0.5, 0.5, 0.5)

func _get_chord_type_name(chord_type: MusicData.ChordType) -> String:
	match chord_type:
		MusicData.ChordType.MAJOR: return "大三和弦"
		MusicData.ChordType.MINOR: return "小三和弦"
		MusicData.ChordType.AUGMENTED: return "增三和弦"
		MusicData.ChordType.DIMINISHED: return "减三和弦"
		MusicData.ChordType.DOMINANT_7: return "属七和弦"
		MusicData.ChordType.DIMINISHED_7: return "减七和弦"
		MusicData.ChordType.MAJOR_7: return "大七和弦"
		MusicData.ChordType.MINOR_7: return "小七和弦"
		MusicData.ChordType.SUSPENDED: return "挂留和弦"
		MusicData.ChordType.DOMINANT_9: return "属九和弦"
		MusicData.ChordType.MAJOR_9: return "大九和弦"
		MusicData.ChordType.DIMINISHED_9: return "减九和弦"
		MusicData.ChordType.DOMINANT_11: return "属十一和弦"
		MusicData.ChordType.DOMINANT_13: return "属十三和弦"
		MusicData.ChordType.DIMINISHED_13: return "减十三和弦"
		_: return "未知和弦"
