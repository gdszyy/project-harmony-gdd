## run_results_screen.gd
## 局结算界面 (Issue #31)
## 每局游戏结束后显示战斗统计和共鸣碎片奖励
## 包含：
## - 存活时间、击杀数、最高等级等统计
## - 共鸣碎片获取明细
## - 和谐度评价加成
## - "前往和谐殿堂" / "再来一局" 按钮
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal go_to_hall_pressed()
signal retry_pressed()
signal main_menu_pressed()

# ============================================================
# 颜色
# ============================================================
const BG_COLOR := Color(0.05, 0.04, 0.08, 0.92)
const PANEL_COLOR := Color(0.1, 0.08, 0.15, 0.95)
const GOLD := Color(1.0, 0.85, 0.3)
const TEXT := Color(0.9, 0.88, 0.95)
const DIM := Color(0.5, 0.48, 0.55)
const ACCENT := Color(0.6, 0.4, 1.0)
const GREEN := Color(0.3, 0.9, 0.5)

# ============================================================
# 内部状态
# ============================================================
var _result_data: Dictionary = {}
var _container: Control = null
var _is_showing: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	visible = false

# ============================================================
# 公共接口
# ============================================================

## 显示结算界面
func show_results(run_data: Dictionary) -> void:
	# 通过 MetaProgressionManager 计算奖励
	var meta := get_node_or_null("/root/MetaProgressionManager")
	if meta and meta.has_method("on_run_completed"):
		_result_data = meta.on_run_completed(run_data)
	else:
		_result_data = run_data
	
	_build_results_ui()
	visible = true
	_is_showing = true
	
	# 入场动画
	if _container:
		_container.modulate.a = 0.0
		_container.scale = Vector2(0.9, 0.9)
		_container.pivot_offset = _container.size / 2.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_container, "modulate:a", 1.0, 0.4)
		tween.tween_property(_container, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT)

## 隐藏结算界面
func hide_results() -> void:
	visible = false
	_is_showing = false
	if _container:
		_container.queue_free()
		_container = null

# ============================================================
# UI 构建
# ============================================================

func _build_results_ui() -> void:
	# 清除旧 UI
	if _container:
		_container.queue_free()
	
	# 背景遮罩
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 主容器
	_container = PanelContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_container.custom_minimum_size = Vector2(500, 500)
	_container.offset_left = -250
	_container.offset_right = 250
	_container.offset_top = -250
	_container.offset_bottom = 250
	
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = ACCENT.darkened(0.3)
	_container.add_theme_stylebox_override("panel", style)
	add_child(_container)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_container.add_child(vbox)
	
	# 标题
	var title := Label.new()
	title.text = "演奏结束"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(title)
	
	# 分隔线
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# 统计数据
	_add_stat_row(vbox, "存活时间", _format_time(_result_data.get("survival_time", 0.0)))
	_add_stat_row(vbox, "总击杀", str(_result_data.get("total_kills", 0)))
	_add_stat_row(vbox, "Boss 击败", str(_result_data.get("bosses_defeated", 0)))
	_add_stat_row(vbox, "最高等级", "Lv. %d" % _result_data.get("max_level", 1))
	
	# 和谐度加成
	if _result_data.get("harmony_bonus", false):
		var harmony_label := Label.new()
		harmony_label.text = "高和谐度加成!"
		harmony_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		harmony_label.add_theme_font_size_override("font_size", 14)
		harmony_label.add_theme_color_override("font_color", GREEN)
		vbox.add_child(harmony_label)
	
	# 碎片奖励
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)
	
	var fragments_earned: int = _result_data.get("fragments_earned", 0)
	var fragments_label := Label.new()
	fragments_label.text = "获得共鸣碎片: +%d" % fragments_earned
	fragments_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fragments_label.add_theme_font_size_override("font_size", 20)
	fragments_label.add_theme_color_override("font_color", GOLD)
	vbox.add_child(fragments_label)
	
	var total_label := Label.new()
	total_label.text = "碎片总计: %d" % _result_data.get("total_fragments", 0)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 13)
	total_label.add_theme_color_override("font_color", DIM)
	vbox.add_child(total_label)
	
	# 按钮区域
	var sep3 := HSeparator.new()
	vbox.add_child(sep3)
	
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_hbox)
	
	var hall_btn := Button.new()
	hall_btn.text = "前往和谐殿堂"
	hall_btn.custom_minimum_size = Vector2(160, 42)
	hall_btn.add_theme_font_size_override("font_size", 14)
	hall_btn.pressed.connect(func():
		hide_results()
		go_to_hall_pressed.emit()
	)
	btn_hbox.add_child(hall_btn)
	
	var retry_btn := Button.new()
	retry_btn.text = "再来一局"
	retry_btn.custom_minimum_size = Vector2(120, 42)
	retry_btn.pressed.connect(func():
		hide_results()
		retry_pressed.emit()
	)
	btn_hbox.add_child(retry_btn)
	
	var menu_btn := Button.new()
	menu_btn.text = "主菜单"
	menu_btn.custom_minimum_size = Vector2(100, 42)
	menu_btn.pressed.connect(func():
		hide_results()
		main_menu_pressed.emit()
	)
	btn_hbox.add_child(menu_btn)

func _add_stat_row(parent: Node, label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)
	
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", DIM)
	hbox.add_child(label)
	
	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", TEXT)
	hbox.add_child(value)

func _format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%d:%02d" % [mins, secs]
