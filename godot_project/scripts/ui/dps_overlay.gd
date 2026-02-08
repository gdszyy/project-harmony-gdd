## dps_overlay.gd
## DPS 实时统计覆盖层
## 在屏幕右上角显示实时 DPS 图表和数值
## 仅在测试场中激活
extends CanvasLayer

# ============================================================
# 常量
# ============================================================
const OVERLAY_WIDTH := 260.0
const OVERLAY_HEIGHT := 140.0
const GRAPH_HEIGHT := 80.0
const MARGIN := 12.0
const BG_COLOR := Color(0.04, 0.03, 0.08, 0.85)
const BORDER_COLOR := Color(0.5, 0.3, 0.9, 0.5)
const DPS_COLOR := Color(0.3, 0.9, 0.5)
const PEAK_COLOR := Color(1.0, 0.85, 0.2)
const GRAPH_BG := Color(0.06, 0.04, 0.10, 0.9)
const GRAPH_LINE := Color(0.3, 0.9, 0.5, 0.8)
const GRAPH_FILL := Color(0.3, 0.9, 0.5, 0.15)
const GRAPH_GRID := Color(0.15, 0.12, 0.22, 0.5)

# ============================================================
# 状态
# ============================================================
var _test_chamber: Node2D = null
var _dps_history: Array[float] = []
const MAX_HISTORY := 60  # 60个采样点（每0.5秒一个，共30秒）
var _sample_timer: float = 0.0
const SAMPLE_INTERVAL := 0.5

# 节点引用
var _panel: PanelContainer = null
var _dps_value_label: Label = null
var _peak_value_label: Label = null
var _avg_value_label: Label = null
var _graph_rect: ColorRect = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 19
	_build_ui()

	# 初始化历史数据
	for i in range(MAX_HISTORY):
		_dps_history.append(0.0)

	await get_tree().process_frame
	_test_chamber = get_tree().get_first_node_in_group("test_chamber")
	if not _test_chamber:
		_test_chamber = get_parent()

func _process(delta: float) -> void:
	_sample_timer += delta
	if _sample_timer >= SAMPLE_INTERVAL:
		_sample_timer -= SAMPLE_INTERVAL
		_record_sample()

	_update_display()

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.position = Vector2(-OVERLAY_WIDTH - MARGIN, MARGIN)
	_panel.custom_minimum_size = Vector2(OVERLAY_WIDTH, OVERLAY_HEIGHT)

	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "DPS MONITOR"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.4, 0.35, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# 数值行
	var stats_hbox := HBoxContainer.new()
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_hbox.add_theme_constant_override("separation", 16)

	_dps_value_label = Label.new()
	_dps_value_label.text = "0.0"
	_dps_value_label.add_theme_font_size_override("font_size", 20)
	_dps_value_label.add_theme_color_override("font_color", DPS_COLOR)
	stats_hbox.add_child(_dps_value_label)

	var peak_vbox := VBoxContainer.new()
	var peak_title := Label.new()
	peak_title.text = "PEAK"
	peak_title.add_theme_font_size_override("font_size", 8)
	peak_title.add_theme_color_override("font_color", Color(0.4, 0.35, 0.5))
	peak_vbox.add_child(peak_title)

	_peak_value_label = Label.new()
	_peak_value_label.text = "0.0"
	_peak_value_label.add_theme_font_size_override("font_size", 12)
	_peak_value_label.add_theme_color_override("font_color", PEAK_COLOR)
	peak_vbox.add_child(_peak_value_label)
	stats_hbox.add_child(peak_vbox)

	var avg_vbox := VBoxContainer.new()
	var avg_title := Label.new()
	avg_title.text = "AVG"
	avg_title.add_theme_font_size_override("font_size", 8)
	avg_title.add_theme_color_override("font_color", Color(0.4, 0.35, 0.5))
	avg_vbox.add_child(avg_title)

	_avg_value_label = Label.new()
	_avg_value_label.text = "0.0"
	_avg_value_label.add_theme_font_size_override("font_size", 12)
	_avg_value_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	avg_vbox.add_child(_avg_value_label)
	stats_hbox.add_child(avg_vbox)

	vbox.add_child(stats_hbox)

	# DPS 图表区域（使用 ColorRect 作为占位，实际绘制在 _draw 中）
	_graph_rect = ColorRect.new()
	_graph_rect.custom_minimum_size = Vector2(OVERLAY_WIDTH - 20, GRAPH_HEIGHT)
	_graph_rect.color = GRAPH_BG
	vbox.add_child(_graph_rect)

	add_child(_panel)

# ============================================================
# 数据采样
# ============================================================

func _record_sample() -> void:
	if not _test_chamber:
		_dps_history.append(0.0)
	else:
		var stats = _test_chamber.get_dps_stats()
		_dps_history.append(stats.get("current_dps", 0.0))

	if _dps_history.size() > MAX_HISTORY:
		_dps_history.pop_front()

# ============================================================
# 显示更新
# ============================================================

func _update_display() -> void:
	if not _test_chamber:
		return

	var stats = _test_chamber.get_dps_stats()

	if _dps_value_label:
		_dps_value_label.text = "%.1f" % stats.get("current_dps", 0.0)
	if _peak_value_label:
		_peak_value_label.text = "%.1f" % stats.get("peak_dps", 0.0)
	if _avg_value_label:
		_avg_value_label.text = "%.1f" % stats.get("average_dps", 0.0)
