## dps_overlay.gd — DPS 实时统计覆盖层
## 在屏幕右上角显示实时 DPS 图表和数值
## 仅在测试场中激活，使用 _draw() 绘制折线图
extends CanvasLayer

# ============================================================
# 常量
# ============================================================
const OVERLAY_WIDTH := 260.0
const OVERLAY_HEIGHT := 160.0
const GRAPH_HEIGHT := 80.0
const GRAPH_WIDTH := 230.0
const MARGIN := 12.0
const DPS_COLOR := UIColors.DIFFICULTY_EASY
const PEAK_COLOR := UIColors.GOLD
var AVG_COLOR := UIColors.SHIELD
var GRAPH_BG := UIColors.with_alpha(UIColors.PANEL_DARK, 0.9)
const GRAPH_LINE := UIColors.with_alpha(UIColors.DIFFICULTY_EASY, 0.8)
const GRAPH_FILL := UIColors.with_alpha(UIColors.DIFFICULTY_EASY, 0.15)
const GRAPH_GRID := UIColors.with_alpha(UIColors.PANEL_LIGHTER, 0.5)

# ============================================================
# 状态
# ============================================================
var _test_chamber: Node = null
var _dps_history: Array[float] = []
const MAX_HISTORY := 60
var _sample_timer: float = 0.0
const SAMPLE_INTERVAL := 0.5

# 绘制面板
var _draw_panel: Control = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 19

	# 初始化历史数据
	for i in range(MAX_HISTORY):
		_dps_history.append(0.0)

	_build_ui()

	await get_tree().process_frame
	_test_chamber = get_tree().get_first_node_in_group("test_chamber")
	if not _test_chamber:
		_test_chamber = get_parent()
		while _test_chamber and not _test_chamber.has_method("get_dps_stats"):
			_test_chamber = _test_chamber.get_parent()

func _process(delta: float) -> void:
	_sample_timer += delta
	if _sample_timer >= SAMPLE_INTERVAL:
		_sample_timer -= SAMPLE_INTERVAL
		_record_sample()

	if _draw_panel:
		_draw_panel.queue_redraw()

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	_draw_panel = Control.new()
	_draw_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_draw_panel.offset_left = -OVERLAY_WIDTH - MARGIN
	_draw_panel.offset_right = -MARGIN
	_draw_panel.offset_top = MARGIN
	_draw_panel.offset_bottom = MARGIN + OVERLAY_HEIGHT
	_draw_panel.custom_minimum_size = Vector2(OVERLAY_WIDTH, OVERLAY_HEIGHT)
	_draw_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_panel.draw.connect(_on_panel_draw)
	add_child(_draw_panel)

# ============================================================
# 数据采样
# ============================================================

func _record_sample() -> void:
	if not _test_chamber or not _test_chamber.has_method("get_dps_stats"):
		_dps_history.append(0.0)
	else:
		var stats: Dictionary = _test_chamber.get_dps_stats()
		_dps_history.append(stats.get("current_dps", 0.0))

	if _dps_history.size() > MAX_HISTORY:
		_dps_history.pop_front()

# ============================================================
# 绘制
# ============================================================

func _on_panel_draw() -> void:
	if not _draw_panel:
		return

	var font := ThemeDB.fallback_font
	var panel_size := Vector2(OVERLAY_WIDTH, OVERLAY_HEIGHT)

	# 背景
	var bg_style := Rect2(Vector2.ZERO, panel_size)
	_draw_panel.draw_rect(bg_style, UIColors.PRIMARY_BG)
	_draw_panel.draw_rect(bg_style, UIColors.BORDER_DEFAULT, false, 1.0)

	# 标题
	_draw_panel.draw_string(font, Vector2(10, 16), "DPS MONITOR",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIColors.TEXT_DIM)

	# 获取统计数据
	var current_dps := 0.0
	var peak_dps := 0.0
	var avg_dps := 0.0

	if _test_chamber and _test_chamber.has_method("get_dps_stats"):
		var stats: Dictionary = _test_chamber.get_dps_stats()
		current_dps = stats.get("current_dps", 0.0)
		peak_dps = stats.get("peak_dps", 0.0)
		avg_dps = stats.get("average_dps", 0.0)

	# DPS 数值
	_draw_panel.draw_string(font, Vector2(10, 38), "%.1f" % current_dps,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DPS_COLOR)

	_draw_panel.draw_string(font, Vector2(120, 30), "PEAK",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIColors.TEXT_DIM)
	_draw_panel.draw_string(font, Vector2(120, 42), "%.1f" % peak_dps,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PEAK_COLOR)

	_draw_panel.draw_string(font, Vector2(180, 30), "AVG",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIColors.TEXT_DIM)
	_draw_panel.draw_string(font, Vector2(180, 42), "%.1f" % avg_dps,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AVG_COLOR)

	# 图表区域
	var graph_x := 15.0
	var graph_y := 55.0
	var graph_rect := Rect2(Vector2(graph_x, graph_y), Vector2(GRAPH_WIDTH, GRAPH_HEIGHT))

	# 图表背景
	_draw_panel.draw_rect(graph_rect, GRAPH_BG)

	# 网格线
	for i in range(5):
		var gy := graph_y + GRAPH_HEIGHT * float(i) / 4.0
		_draw_panel.draw_line(
			Vector2(graph_x, gy),
			Vector2(graph_x + GRAPH_WIDTH, gy),
			GRAPH_GRID, 1.0
		)

	# 折线图
	if _dps_history.size() > 1:
		var max_val := 1.0
		for v in _dps_history:
			max_val = max(max_val, v)

		var points := PackedVector2Array()
		var fill_points := PackedVector2Array()
		fill_points.append(Vector2(graph_x, graph_y + GRAPH_HEIGHT))

		for i in range(_dps_history.size()):
			var x := graph_x + (float(i) / float(max(_dps_history.size() - 1, 1))) * GRAPH_WIDTH
			var y := graph_y + GRAPH_HEIGHT * (1.0 - _dps_history[i] / max_val)
			points.append(Vector2(x, y))
			fill_points.append(Vector2(x, y))

		fill_points.append(Vector2(graph_x + GRAPH_WIDTH, graph_y + GRAPH_HEIGHT))

		# 填充区域
		if fill_points.size() > 2:
			_draw_panel.draw_colored_polygon(fill_points, GRAPH_FILL)

		# 折线
		if points.size() > 1:
			_draw_panel.draw_polyline(points, GRAPH_LINE, 1.5, true)

	# 图表边框
	_draw_panel.draw_rect(graph_rect, UIColors.BORDER_DEFAULT, false, 1.0)
