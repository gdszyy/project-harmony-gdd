## run_results_screen.gd — 单局结算界面 v5.0
## "余韵回响" — 三阶段结算流程
##
## 设计文档: Docs/UI_Design_Module5_HallOfHarmony.md §5
## 阶段 1: 统计展示 — 演出评价 + 关键数据
## 阶段 2: 碎片结算 — 共鸣碎片获取动画
## 阶段 3: 行动选择 — 重试 / 和谐殿堂 / 主菜单
##
## 兼容 CanvasLayer 父类（game_over.gd 通过 CanvasLayer 加载）
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal retry_pressed()
signal go_to_hall_pressed()
signal main_menu_pressed()

# ============================================================
# 颜色方案
# ============================================================
const BG_COLOR := Color(0.02, 0.01, 0.03, 0.97)
const ACCENT := Color("#9D6FFF")
const GOLD := Color("#FFD700")
const CYAN := Color("#00E5FF")
const TEXT_COLOR := Color("#EAE6FF")
const DIM_TEXT := Color("#A098C8")
const SUCCESS := Color("#4DFF80")
const DANGER := Color("#FF4D4D")
const FRAGMENT_COLOR := Color(0.6, 0.4, 1.0)

# ============================================================
# 评价等级
# ============================================================
const EVALUATIONS := {
	"S": {"name": "HARMONIC MASTER", "color": Color("#FFD700"), "threshold": 2000},
	"A": {"name": "RESONANCE", "color": Color("#00E5FF"), "threshold": 1200},
	"B": {"name": "MELODY", "color": Color("#9D6FFF"), "threshold": 600},
	"C": {"name": "RHYTHM", "color": Color("#4DFF80"), "threshold": 300},
	"D": {"name": "NOISE", "color": Color("#A098C8"), "threshold": 0},
}

# ============================================================
# 结算阶段
# ============================================================
enum Phase { STATS, FRAGMENTS, ACTIONS }

# ============================================================
# 内部状态
# ============================================================
var _meta: Node = null
var _canvas: Control = null  # 用于 _draw 的 Control 子节点
var _current_phase: Phase = Phase.STATS
var _time: float = 0.0
var _phase_time: float = 0.0
var _is_showing: bool = false

## 结算数据
var _run_data: Dictionary = {}
var _result: Dictionary = {}

## 统计项动画
var _stat_items: Array[Dictionary] = []
var _stat_reveal_index: int = 0
var _stat_reveal_timer: float = 0.0
const STAT_REVEAL_INTERVAL := 0.35

## 碎片动画
var _fragment_count_display: int = 0
var _fragment_target: int = 0
var _fragment_anim_speed: float = 0.0
var _fragment_particles: Array[Dictionary] = []

## 评价
var _eval_grade: String = "D"
var _eval_name: String = "NOISE"
var _eval_color: Color = DIM_TEXT
var _eval_scale: float = 0.0

## 行动按钮
var _btn_rects: Dictionary = {}
var _hover_btn: String = ""

## 背景星尘
var _stars: Array[Dictionary] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_meta = get_node_or_null("/root/MetaProgressionManager")
	_generate_stars(100)
	visible = false

# ============================================================
# 公共接口
# ============================================================

func show_results(run_data: Dictionary) -> void:
	_run_data = run_data
	_is_showing = true
	visible = true
	_time = 0.0
	_phase_time = 0.0
	_current_phase = Phase.STATS

	# 计算结算
	if _meta and _meta.has_method("on_run_completed"):
		_result = _meta.on_run_completed(run_data)
	else:
		_result = _calculate_fallback_result(run_data)

	_prepare_stat_items()
	_calculate_evaluation()

	_fragment_target = _result.get("fragments_earned", 0)
	_fragment_count_display = 0
	_fragment_anim_speed = max(float(_fragment_target) / 1.5, 10.0)

	_stat_reveal_index = 0
	_stat_reveal_timer = 0.0
	_eval_scale = 0.0
	_fragment_particles.clear()

	# 创建绘制用 Control
	_build_canvas()

func hide_results() -> void:
	_is_showing = false
	visible = false
	if _canvas:
		_canvas.queue_free()
		_canvas = null

# ============================================================
# 绘制画布（CanvasLayer 不支持 _draw，需要子 Control）
# ============================================================

func _build_canvas() -> void:
	if _canvas:
		_canvas.queue_free()

	_canvas = _ResultsCanvas.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas._screen = self
	add_child(_canvas)

# ============================================================
# 内部绘制画布类
# ============================================================

class _ResultsCanvas extends Control:
	var _screen  # 引用外部 RunResultsScreen

	func _process(delta: float) -> void:
		if _screen == null or not _screen._is_showing:
			return
		_screen._time += delta
		_screen._phase_time += delta

		match _screen._current_phase:
			Phase.STATS:
				_screen._update_stats_phase(delta)
			Phase.FRAGMENTS:
				_screen._update_fragments_phase(delta)
		queue_redraw()

	func _draw() -> void:
		if _screen == null or not _screen._is_showing:
			return
		_screen._do_draw(self)

	func _gui_input(event: InputEvent) -> void:
		if _screen:
			_screen._handle_input(event)

# ============================================================
# 统计项准备
# ============================================================

func _prepare_stat_items() -> void:
	_stat_items.clear()
	var survival_time: float = _run_data.get("survival_time", 0.0)
	var total_kills: int = _run_data.get("total_kills", 0)
	var bosses: int = _run_data.get("bosses_defeated", 0)
	var max_level: int = _run_data.get("max_level", 1)
	var max_fatigue: float = _run_data.get("max_fatigue", 0.0)

	_stat_items.append({"label": "存活时间", "value": _format_time(survival_time), "icon": "⏱"})
	_stat_items.append({"label": "达到等级", "value": "Lv.%d" % max_level, "icon": "★"})
	_stat_items.append({"label": "消灭噪音", "value": "%d" % total_kills, "icon": "⚔"})
	if bosses > 0:
		_stat_items.append({"label": "Boss 击败", "value": "%d" % bosses, "icon": "♛"})
	_stat_items.append({"label": "最高疲劳", "value": "%.0f%%" % (max_fatigue * 100), "icon": "♨"})

func _calculate_evaluation() -> void:
	var survival_time: float = _run_data.get("survival_time", 0.0)
	var total_kills: int = _run_data.get("total_kills", 0)
	var max_level: int = _run_data.get("max_level", 1)
	var score := survival_time * 0.5 + total_kills * 10.0 + max_level * 100.0
	for grade in ["S", "A", "B", "C", "D"]:
		if score >= EVALUATIONS[grade]["threshold"]:
			_eval_grade = grade
			_eval_name = EVALUATIONS[grade]["name"]
			_eval_color = EVALUATIONS[grade]["color"]
			break

func _calculate_fallback_result(run_data: Dictionary) -> Dictionary:
	var survival_time: float = run_data.get("survival_time", 0.0)
	var kills: int = run_data.get("total_kills", 0)
	var bosses: int = run_data.get("bosses_defeated", 0)
	var max_level: int = run_data.get("max_level", 1)
	var fragments := int(survival_time / 30.0) * 5
	fragments += int(kills / 20.0) * 3
	fragments += bosses * 30
	fragments += max_level * 2
	return {"fragments_earned": fragments, "total_fragments": fragments}

# ============================================================
# 阶段更新
# ============================================================

func _update_stats_phase(delta: float) -> void:
	_stat_reveal_timer += delta
	if _stat_reveal_timer >= STAT_REVEAL_INTERVAL:
		_stat_reveal_timer -= STAT_REVEAL_INTERVAL
		if _stat_reveal_index < _stat_items.size():
			_stat_reveal_index += 1
	if _stat_reveal_index >= _stat_items.size():
		_eval_scale = min(_eval_scale + delta * 3.0, 1.0)
	if _phase_time > 4.5 and _stat_reveal_index >= _stat_items.size():
		_advance_phase()

func _update_fragments_phase(delta: float) -> void:
	if _fragment_count_display < _fragment_target:
		_fragment_count_display = min(
			_fragment_count_display + int(_fragment_anim_speed * delta),
			_fragment_target)
		if randf() < 0.5:
			_fragment_particles.append({
				"pos": Vector2(960 + randf_range(-100, 100), 400),
				"vel": Vector2(randf_range(-50, 50), randf_range(-80, -30)),
				"life": 1.0, "size": randf_range(2, 5),
			})
	var dead: Array[int] = []
	for i in range(_fragment_particles.size()):
		_fragment_particles[i]["pos"] += _fragment_particles[i]["vel"] * delta
		_fragment_particles[i]["life"] -= delta * 1.5
		if _fragment_particles[i]["life"] <= 0:
			dead.append(i)
	for i in range(dead.size() - 1, -1, -1):
		_fragment_particles.remove_at(dead[i])
	if _phase_time > 3.0 and _fragment_count_display >= _fragment_target:
		_advance_phase()

func _advance_phase() -> void:
	match _current_phase:
		Phase.STATS:
			_current_phase = Phase.FRAGMENTS
			_phase_time = 0.0
		Phase.FRAGMENTS:
			_current_phase = Phase.ACTIONS
			_phase_time = 0.0

# ============================================================
# 背景
# ============================================================

func _generate_stars(count: int) -> void:
	_stars.clear()
	for i in range(count):
		_stars.append({
			"pos": Vector2(randf() * 1920.0, randf() * 1080.0),
			"size": randf_range(0.5, 2.0),
			"phase": randf() * TAU,
			"brightness": randf_range(0.2, 0.7),
		})

# ============================================================
# 绘制（由 _ResultsCanvas._draw 调用）
# ============================================================

func _do_draw(canvas: Control) -> void:
	var vp := canvas.get_viewport_rect().size
	var center := vp / 2.0
	var font := ThemeDB.fallback_font

	# 背景
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), BG_COLOR)

	# 星尘
	for star in _stars:
		var flicker := 0.5 + 0.5 * sin(_time * 0.6 + star["phase"])
		canvas.draw_circle(star["pos"], star["size"],
			Color(0.5, 0.5, 0.7, star["brightness"] * flicker * 0.4))

	match _current_phase:
		Phase.STATS:
			_draw_stats_phase(canvas, center, font, vp)
		Phase.FRAGMENTS:
			_draw_fragments_phase(canvas, center, font, vp)
		Phase.ACTIONS:
			_draw_actions_phase(canvas, center, font, vp)

	_draw_phase_indicator(canvas, font, vp)

func _draw_stats_phase(canvas: Control, center: Vector2, font: Font, vp: Vector2) -> void:
	canvas.draw_string(font, Vector2(center.x - 100, 80),
		"PERFORMANCE", HORIZONTAL_ALIGNMENT_CENTER, 200, 24,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.9))
	canvas.draw_string(font, Vector2(center.x - 60, 105),
		"演 出 评 价", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, DIM_TEXT)
	canvas.draw_line(Vector2(center.x - 200, 120), Vector2(center.x + 200, 120),
		Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.2), 1.0)

	var start_y := 160.0
	var row_h := 45.0
	for i in range(min(_stat_reveal_index, _stat_items.size())):
		var item: Dictionary = _stat_items[i]
		var y := start_y + i * row_h
		var reveal_progress := min((_phase_time - i * STAT_REVEAL_INTERVAL) * 3.0, 1.0)
		var alpha := reveal_progress
		canvas.draw_string(font, Vector2(center.x - 180, y + 18),
			item["icon"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(ACCENT.r, ACCENT.g, ACCENT.b, alpha * 0.7))
		canvas.draw_string(font, Vector2(center.x - 150, y + 18),
			item["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(DIM_TEXT.r, DIM_TEXT.g, DIM_TEXT.b, alpha))
		canvas.draw_string(font, Vector2(center.x + 80, y + 18),
			item["value"], HORIZONTAL_ALIGNMENT_RIGHT, 100, 16,
			Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, alpha))
		canvas.draw_line(Vector2(center.x - 180, y + 30), Vector2(center.x + 180, y + 30),
			Color(0.2, 0.18, 0.3, alpha * 0.3), 1.0)

	if _eval_scale > 0.0:
		var eval_y := start_y + _stat_items.size() * row_h + 40
		var scale := ease(_eval_scale, 0.3)
		var eval_rect := Rect2(
			Vector2(center.x - 120 * scale, eval_y),
			Vector2(240 * scale, 60 * scale))
		canvas.draw_rect(eval_rect, Color(_eval_color.r, _eval_color.g, _eval_color.b, 0.08 * scale))
		canvas.draw_rect(eval_rect, Color(_eval_color.r, _eval_color.g, _eval_color.b, 0.3 * scale), false, 2.0)
		canvas.draw_string(font, eval_rect.position + Vector2(20 * scale, 38 * scale),
			_eval_grade, HORIZONTAL_ALIGNMENT_LEFT, -1, int(32 * scale),
			Color(_eval_color.r, _eval_color.g, _eval_color.b, scale))
		canvas.draw_string(font, eval_rect.position + Vector2(60 * scale, 30 * scale),
			_eval_name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * scale),
			Color(_eval_color.r, _eval_color.g, _eval_color.b, scale * 0.8))

	if _stat_reveal_index >= _stat_items.size() and _eval_scale >= 0.8:
		var hint_alpha := 0.3 + 0.3 * sin(_time * 2.0)
		canvas.draw_string(font, Vector2(center.x - 60, vp.y - 50),
			"点击继续", HORIZONTAL_ALIGNMENT_CENTER, 120, 12,
			Color(DIM_TEXT.r, DIM_TEXT.g, DIM_TEXT.b, hint_alpha))

func _draw_fragments_phase(canvas: Control, center: Vector2, font: Font, vp: Vector2) -> void:
	canvas.draw_string(font, Vector2(center.x - 100, 80),
		"RESONANCE", HORIZONTAL_ALIGNMENT_CENTER, 200, 24,
		Color(FRAGMENT_COLOR.r, FRAGMENT_COLOR.g, FRAGMENT_COLOR.b, 0.9))
	canvas.draw_string(font, Vector2(center.x - 60, 105),
		"共 鸣 收 获", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, DIM_TEXT)
	canvas.draw_string(font, Vector2(center.x - 15, center.y - 30),
		"✦", HORIZONTAL_ALIGNMENT_CENTER, 30, 48,
		Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.8))
	var count_text := "+%d" % _fragment_count_display
	canvas.draw_string(font, Vector2(center.x - 60, center.y + 30),
		count_text, HORIZONTAL_ALIGNMENT_CENTER, 120, 36,
		Color(FRAGMENT_COLOR.r, FRAGMENT_COLOR.g, FRAGMENT_COLOR.b, 1.0))
	var total := _result.get("total_fragments", _fragment_count_display)
	canvas.draw_string(font, Vector2(center.x - 80, center.y + 65),
		"总计: %d 共鸣碎片" % total, HORIZONTAL_ALIGNMENT_CENTER, 160, 13, DIM_TEXT)
	if _result.get("harmony_bonus", false):
		canvas.draw_string(font, Vector2(center.x - 60, center.y + 90),
			"♪ 和谐度加成!", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, SUCCESS)
	for particle in _fragment_particles:
		var alpha: float = particle["life"]
		canvas.draw_circle(particle["pos"], particle["size"],
			Color(ACCENT.r, ACCENT.g, ACCENT.b, alpha * 0.6))
	if _fragment_count_display >= _fragment_target:
		var hint_alpha := 0.3 + 0.3 * sin(_time * 2.0)
		canvas.draw_string(font, Vector2(center.x - 60, vp.y - 50),
			"点击继续", HORIZONTAL_ALIGNMENT_CENTER, 120, 12,
			Color(DIM_TEXT.r, DIM_TEXT.g, DIM_TEXT.b, hint_alpha))

func _draw_actions_phase(canvas: Control, center: Vector2, font: Font, vp: Vector2) -> void:
	canvas.draw_string(font, Vector2(center.x - 80, 100),
		"NEXT MOVE", HORIZONTAL_ALIGNMENT_CENTER, 160, 22,
		Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, 0.9))
	canvas.draw_string(font, Vector2(center.x - 60, 125),
		"下 一 步", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, DIM_TEXT)

	_btn_rects.clear()
	var btn_w := 280.0
	var btn_h := 70.0
	var btn_gap := 24.0
	var total_h := 3 * btn_h + 2 * btn_gap
	var start_y := center.y - total_h / 2.0

	var buttons := [
		{"key": "retry", "label": "再次演奏", "sublabel": "挑战更高评价",
		 "icon": "▶", "color": SUCCESS},
		{"key": "hall", "label": "和谐殿堂", "sublabel": "强化你的能力",
		 "icon": "✦", "color": ACCENT},
		{"key": "menu", "label": "返回主菜单", "sublabel": "保存并退出",
		 "icon": "◀", "color": DIM_TEXT},
	]

	for i in range(buttons.size()):
		var btn: Dictionary = buttons[i]
		var y := start_y + i * (btn_h + btn_gap)
		var rect := Rect2(Vector2(center.x - btn_w / 2.0, y), Vector2(btn_w, btn_h))
		_btn_rects[btn["key"]] = rect

		var is_hover := (_hover_btn == btn["key"])
		var btn_color: Color = btn["color"]
		var bg_alpha := 0.12 if is_hover else 0.06
		canvas.draw_rect(rect, Color(btn_color.r, btn_color.g, btn_color.b, bg_alpha))
		var border_alpha := 0.6 if is_hover else 0.25
		canvas.draw_rect(rect, Color(btn_color.r, btn_color.g, btn_color.b, border_alpha), false, 1.5)
		if is_hover:
			var glow_rect := Rect2(rect.position - Vector2(3, 3), rect.size + Vector2(6, 6))
			canvas.draw_rect(glow_rect, Color(btn_color.r, btn_color.g, btn_color.b, 0.06), false, 3.0)
		canvas.draw_string(font, rect.position + Vector2(20, 35),
			btn["icon"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
			Color(btn_color.r, btn_color.g, btn_color.b, 0.8 if is_hover else 0.5))
		canvas.draw_string(font, rect.position + Vector2(55, 30),
			btn["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, 1.0 if is_hover else 0.7))
		canvas.draw_string(font, rect.position + Vector2(55, 50),
			btn["sublabel"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(DIM_TEXT.r, DIM_TEXT.g, DIM_TEXT.b, 0.7 if is_hover else 0.4))

func _draw_phase_indicator(canvas: Control, font: Font, vp: Vector2) -> void:
	var indicator_y := 30.0
	var dot_spacing := 20.0
	var start_x := vp.x / 2.0 - dot_spacing
	for i in range(3):
		var x := start_x + i * dot_spacing
		var is_current := (i == int(_current_phase))
		var is_past := (i < int(_current_phase))
		var r := 4.0 if is_current else 3.0
		var color: Color
		if is_current:
			color = ACCENT
		elif is_past:
			color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4)
		else:
			color = Color(0.3, 0.25, 0.4, 0.3)
		canvas.draw_circle(Vector2(x, indicator_y), r, color)
		if i < 2:
			var line_color := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.2)
			if is_past:
				line_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4)
			canvas.draw_line(Vector2(x + 5, indicator_y), Vector2(x + dot_spacing - 5, indicator_y),
				line_color, 1.0)

# ============================================================
# 输入处理
# ============================================================

func _handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_btn = ""
		if _current_phase == Phase.ACTIONS:
			for key in _btn_rects:
				if _btn_rects[key].has_point(event.position):
					_hover_btn = key
					break

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			match _current_phase:
				Phase.STATS:
					if _stat_reveal_index < _stat_items.size():
						_stat_reveal_index = _stat_items.size()
						_eval_scale = 1.0
					else:
						_advance_phase()
				Phase.FRAGMENTS:
					if _fragment_count_display < _fragment_target:
						_fragment_count_display = _fragment_target
					else:
						_advance_phase()
				Phase.ACTIONS:
					if not _hover_btn.is_empty():
						match _hover_btn:
							"retry":
								hide_results()
								retry_pressed.emit()
							"hall":
								hide_results()
								go_to_hall_pressed.emit()
							"menu":
								hide_results()
								main_menu_pressed.emit()

	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE, KEY_ENTER:
				match _current_phase:
					Phase.STATS:
						if _stat_reveal_index >= _stat_items.size():
							_advance_phase()
						else:
							_stat_reveal_index = _stat_items.size()
							_eval_scale = 1.0
					Phase.FRAGMENTS:
						if _fragment_count_display >= _fragment_target:
							_advance_phase()
						else:
							_fragment_count_display = _fragment_target
			KEY_1:
				if _current_phase == Phase.ACTIONS:
					hide_results()
					retry_pressed.emit()
			KEY_2:
				if _current_phase == Phase.ACTIONS:
					hide_results()
					go_to_hall_pressed.emit()
			KEY_3:
				if _current_phase == Phase.ACTIONS:
					hide_results()
					main_menu_pressed.emit()
			KEY_ESCAPE:
				hide_results()
				main_menu_pressed.emit()

# ============================================================
# 工具函数
# ============================================================

func _format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%02d:%02d" % [mins, secs]
