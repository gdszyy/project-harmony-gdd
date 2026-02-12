## game_over.gd
## "最终乐章"游戏结束界面 v4.0
## 模块7：教学引导与辅助 UI
##
## 设计流程：
##   1. 死亡原因 — 屏幕中央清晰显示
##   2. 背景与氛围 — 基于和谐度评级的动态视觉效果
##   3. 统计摘要 — 动画逐条"演奏"核心数据
##   4. 操作选项 — "重塑谐振"(重试)、"返回殿堂"(主菜单)、"查看乐谱"(远期)
##
## 整合 RunResultsScreen + MetaProgressionVisualizer
## 审计报告 建议3 修复：打通 主菜单→游戏→结算→成长 完整循环
extends Control

# ============================================================
# 主题颜色
# ============================================================
const PANEL_BG := Color("#141026")
const ACCENT_COLOR := Color("#9D6FFF")
const TEXT_PRIMARY := Color("#EAE6FF")
const TEXT_SECONDARY := Color("#A098C8")
const DANGER_COLOR := Color("#FF4D4D")
const SUCCESS_COLOR := Color("#4DFF80")
const GOLD_COLOR := Color("#FFD700")
const BG_DARK := Color("#050310")

# ============================================================
# 评级颜色映射
# ============================================================
const RATING_COLORS: Dictionary = {
	"S": Color("#FFD700"),  # 金色
	"A": Color("#9D6FFF"),  # 紫色
	"B": Color("#4D8BFF"),  # 蓝色
	"C": Color("#4DFF80"),  # 绿色
	"D": Color("#FF4D4D"),  # 红色
}

const RATING_TITLES: Dictionary = {
	"S": "HARMONIC MASTER",
	"A": "RESONANCE",
	"B": "MELODY",
	"C": "RHYTHM",
	"D": "NOISE",
}

# ============================================================
# 节点引用
# ============================================================
@onready var _title_label: Label = $TitleLabel
@onready var _stats_container: VBoxContainer = $StatsContainer
@onready var _retry_button: Button = $RetryButton
@onready var _menu_button: Button = $MenuButton

# ============================================================
# 动态创建的节点
# ============================================================
var _bg_rect: ColorRect = null
var _death_reason_label: Label = null
var _rating_container: Control = null
var _rating_letter: Label = null
var _rating_title: Label = null
var _stats_panel: PanelContainer = null
var _button_container: HBoxContainer = null
var _hall_button: Button = null
var _score_button: Button = null
var _vignette: ColorRect = null

## 子系统
var _run_results_screen: Node = null
var _hall_of_harmony: Control = null
var _showing_results: bool = false
var _showing_hall: bool = false

## 动画状态
var _animation_phase: int = 0
var _stats_data: Array = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_build_themed_ui()
	_start_death_sequence()

# ============================================================
# UI 构建 — 主题化重构
# ============================================================

func _build_themed_ui() -> void:
	# 隐藏原始节点（如果存在）
	if _title_label:
		_title_label.visible = false
	if _stats_container:
		_stats_container.visible = false
	if _retry_button:
		_retry_button.visible = false
	if _menu_button:
		_menu_button.visible = false

	# 背景
	_bg_rect = ColorRect.new()
	_bg_rect.name = "ThemedBackground"
	_bg_rect.color = BG_DARK
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_rect)
	move_child(_bg_rect, 0)

	# 暗角效果
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.color = Color(0, 0, 0, 0.3)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	# 死亡原因标签
	_death_reason_label = Label.new()
	_death_reason_label.name = "DeathReasonLabel"
	_death_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_reason_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_reason_label.add_theme_font_size_override("font_size", 22)
	_death_reason_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	_death_reason_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death_reason_label.offset_top = -200
	_death_reason_label.offset_bottom = -160
	_death_reason_label.offset_left = -300
	_death_reason_label.offset_right = 300
	_death_reason_label.modulate.a = 0.0
	add_child(_death_reason_label)

	# 评级容器
	_rating_container = Control.new()
	_rating_container.name = "RatingContainer"
	_rating_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_rating_container.offset_top = -150
	_rating_container.offset_bottom = 0
	_rating_container.offset_left = -200
	_rating_container.offset_right = 200
	_rating_container.modulate.a = 0.0
	add_child(_rating_container)

	# 评级字母
	_rating_letter = Label.new()
	_rating_letter.name = "RatingLetter"
	_rating_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rating_letter.add_theme_font_size_override("font_size", 96)
	_rating_letter.position = Vector2(0, 0)
	_rating_letter.size = Vector2(400, 110)
	_rating_container.add_child(_rating_letter)

	# 评级标题
	_rating_title = Label.new()
	_rating_title.name = "RatingTitle"
	_rating_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rating_title.add_theme_font_size_override("font_size", 18)
	_rating_title.add_theme_color_override("font_color", TEXT_SECONDARY)
	_rating_title.position = Vector2(0, 110)
	_rating_title.size = Vector2(400, 30)
	_rating_container.add_child(_rating_title)

	# 统计面板
	_stats_panel = PanelContainer.new()
	_stats_panel.name = "StatsPanel"
	_stats_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_stats_panel.offset_top = 20
	_stats_panel.offset_bottom = 260
	_stats_panel.offset_left = -220
	_stats_panel.offset_right = 220
	_stats_panel.modulate.a = 0.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(PANEL_BG, 0.85)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 24.0
	panel_style.content_margin_right = 24.0
	panel_style.content_margin_top = 20.0
	panel_style.content_margin_bottom = 20.0
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(ACCENT_COLOR, 0.4)
	_stats_panel.add_theme_stylebox_override("panel", panel_style)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.name = "StatsVBox"
	stats_vbox.add_theme_constant_override("separation", 10)
	_stats_panel.add_child(stats_vbox)
	add_child(_stats_panel)

	# 按钮容器
	_button_container = HBoxContainer.new()
	_button_container.name = "ButtonContainer"
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 20)
	_button_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_button_container.offset_top = -100
	_button_container.offset_bottom = -40
	_button_container.offset_left = -350
	_button_container.offset_right = 350
	_button_container.modulate.a = 0.0
	add_child(_button_container)

	# 重试按钮
	var retry_btn := _create_themed_button("重塑谐振", ACCENT_COLOR)
	retry_btn.pressed.connect(_on_retry_pressed)
	_button_container.add_child(retry_btn)

	# 主菜单按钮
	var menu_btn := _create_themed_button("返回殿堂", TEXT_SECONDARY)
	menu_btn.pressed.connect(_on_menu_pressed)
	_button_container.add_child(menu_btn)

	# 和谐殿堂按钮
	_hall_button = _create_themed_button("和谐殿堂", GOLD_COLOR)
	_hall_button.pressed.connect(_on_hall_pressed)
	_button_container.add_child(_hall_button)

	# 查看乐谱按钮（远期功能，灰色）
	_score_button = _create_themed_button("查看乐谱", Color(TEXT_SECONDARY, 0.5))
	_score_button.disabled = true
	_button_container.add_child(_score_button)

# ============================================================
# 死亡序列动画
# ============================================================

func _start_death_sequence() -> void:
	var rating := _get_rating_letter()
	var rating_color: Color = RATING_COLORS.get(rating, DANGER_COLOR)

	# 设置评级
	_rating_letter.text = rating
	_rating_letter.add_theme_color_override("font_color", rating_color)
	_rating_title.text = RATING_TITLES.get(rating, "UNKNOWN")

	# 设置死亡原因
	_death_reason_label.text = _get_death_reason()

	# 准备统计数据
	_prepare_stats_data()

	# Phase 1: 死亡原因显示
	_animation_phase = 1
	var tween1 := create_tween()
	tween1.tween_property(_death_reason_label, "modulate:a", 1.0, 0.8)
	tween1.tween_interval(2.0)
	tween1.tween_property(_death_reason_label, "modulate:a", 0.0, 0.6)
	tween1.tween_callback(_show_rating)

func _show_rating() -> void:
	# Phase 2: 评级显示
	_animation_phase = 2

	# 背景颜色变化
	var rating := _get_rating_letter()
	var rating_color: Color = RATING_COLORS.get(rating, DANGER_COLOR)
	var bg_tween := create_tween()
	bg_tween.tween_property(_bg_rect, "color", Color(rating_color, 0.08), 1.0)

	# 评级入场
	_rating_container.modulate.a = 0.0
	_rating_container.scale = Vector2(0.5, 0.5)
	_rating_container.pivot_offset = Vector2(200, 75)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_rating_container, "modulate:a", 1.0, 0.5)
	tween.tween_property(_rating_container, "scale", Vector2(1.0, 1.0), 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain()
	tween.tween_interval(0.5)
	tween.tween_callback(_show_stats_animated)

func _show_stats_animated() -> void:
	# Phase 3: 统计摘要逐条显示
	_animation_phase = 3

	_stats_panel.modulate.a = 0.0
	_stats_panel.scale = Vector2(0.95, 0.95)
	_stats_panel.pivot_offset = Vector2(220, 120)

	var panel_tween := create_tween()
	panel_tween.set_parallel(true)
	panel_tween.tween_property(_stats_panel, "modulate:a", 1.0, 0.4)
	panel_tween.tween_property(_stats_panel, "scale", Vector2(1.0, 1.0), 0.4) \
		.set_ease(Tween.EASE_OUT)

	# 逐条添加统计行
	var stats_vbox: VBoxContainer = _stats_panel.get_node("StatsVBox")
	var delay := 0.6
	for i in range(_stats_data.size()):
		var stat: Array = _stats_data[i]
		get_tree().create_timer(delay + i * 0.3).timeout.connect(func():
			_add_stat_row(stats_vbox, stat[0], stat[1], stat[2])
		)

	# 显示按钮
	var total_delay := delay + _stats_data.size() * 0.3 + 0.5
	get_tree().create_timer(total_delay).timeout.connect(_show_buttons)

func _show_buttons() -> void:
	# Phase 4: 按钮显示
	_animation_phase = 4
	var tween := create_tween()
	tween.tween_property(_button_container, "modulate:a", 1.0, 0.5)

	# 同时尝试显示结算界面
	_try_show_run_results()

# ============================================================
# 统计数据
# ============================================================

func _prepare_stats_data() -> void:
	_stats_data = [
		["存活时间", _format_time(GameManager.game_time), TEXT_PRIMARY],
		["达到等级", str(GameManager.player_level), ACCENT_COLOR],
		["消灭敌人", str(GameManager.session_kills), SUCCESS_COLOR],
		["最高疲劳", "%.0f%%" % (FatigueManager.current_afi * 100), _get_fatigue_color()],
		["和谐评价", _get_evaluation(), RATING_COLORS.get(_get_rating_letter(), TEXT_PRIMARY)],
	]

func _add_stat_row(container: VBoxContainer, label_text: String, value_text: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.modulate.a = 0.0

	var name_label := Label.new()
	name_label.text = label_text
	name_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.custom_minimum_size.x = 160
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", color)
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.custom_minimum_size.x = 160
	row.add_child(value_label)

	container.add_child(row)

	# 淡入动画
	var tween := row.create_tween()
	tween.tween_property(row, "modulate:a", 1.0, 0.3)

# ============================================================
# 结算界面集成
# ============================================================

func _try_show_run_results() -> void:
	var run_results_script := load("res://scripts/ui/run_results_screen.gd")
	if run_results_script == null:
		return

	_run_results_screen = CanvasLayer.new()
	_run_results_screen.set_script(run_results_script)
	_run_results_screen.layer = 20
	add_child(_run_results_screen)

	if _run_results_screen.has_signal("go_to_hall_pressed"):
		_run_results_screen.go_to_hall_pressed.connect(_on_results_go_to_hall)
	if _run_results_screen.has_signal("retry_pressed"):
		_run_results_screen.retry_pressed.connect(_on_retry_pressed)
	if _run_results_screen.has_signal("main_menu_pressed"):
		_run_results_screen.main_menu_pressed.connect(_on_menu_pressed)

	var run_data := {
		"survival_time": GameManager.game_time,
		"total_kills": GameManager.session_kills,
		"bosses_defeated": 0,
		"max_level": GameManager.player_level,
		"max_fatigue": FatigueManager.current_afi,
		"evaluation": _get_evaluation(),
	}

	if _run_results_screen.has_method("show_results"):
		_run_results_screen.show_results(run_data)
		_showing_results = true

# ============================================================
# 和谐殿堂集成
# ============================================================

func _show_hall_of_harmony() -> void:
	var viz_script := load("res://scripts/ui/meta_progression_visualizer.gd")
	if viz_script:
		_hall_of_harmony = Control.new()
		_hall_of_harmony.set_script(viz_script)
		_hall_of_harmony.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_hall_of_harmony)
		if _hall_of_harmony.has_signal("start_game_pressed"):
			_hall_of_harmony.start_game_pressed.connect(_on_retry_pressed)
		if _hall_of_harmony.has_signal("back_pressed"):
			_hall_of_harmony.back_pressed.connect(_on_hall_back)
		_showing_hall = true
		return

	var hall_script := load("res://scripts/ui/hall_of_harmony.gd")
	if hall_script == null:
		return
	_hall_of_harmony = Control.new()
	_hall_of_harmony.set_script(hall_script)
	_hall_of_harmony.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_hall_of_harmony)
	if _hall_of_harmony.has_signal("start_game_pressed"):
		_hall_of_harmony.start_game_pressed.connect(_on_retry_pressed)
	if _hall_of_harmony.has_signal("back_pressed"):
		_hall_of_harmony.back_pressed.connect(_on_hall_back)
	_showing_hall = true

func _on_hall_back() -> void:
	if _hall_of_harmony:
		_hall_of_harmony.queue_free()
		_hall_of_harmony = null
	_showing_hall = false

# ============================================================
# 辅助方法
# ============================================================

func _create_themed_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(150, 48)

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(PANEL_BG, 0.8)
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = accent
	style_normal.shadow_color = Color(accent, 0.2)
	style_normal.shadow_size = 4
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover := style_normal.duplicate()
	style_hover.bg_color = Color(accent, 0.15)
	style_hover.shadow_size = 8
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = Color(accent, 0.25)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	btn.add_theme_font_size_override("font_size", 16)

	return btn

func _get_death_reason() -> String:
	# 尝试从 GameManager 获取死亡原因
	if GameManager.has_method("get_death_reason"):
		return GameManager.get_death_reason()
	# 默认死亡原因
	if GameManager.player_current_hp <= 0:
		return "被不和谐所吞噬"
	return "旋律消散于虚空"

func _format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%02d:%02d" % [mins, secs]

func _get_evaluation() -> String:
	var rating := _get_rating_letter()
	var title: String = RATING_TITLES.get(rating, "UNKNOWN")
	return "%s - %s" % [rating, title]

func _get_rating_letter() -> String:
	var score := GameManager.game_time * 0.5 + GameManager.session_kills * 10.0 + GameManager.player_level * 100.0
	if score > 2000: return "S"
	if score > 1200: return "A"
	if score > 600: return "B"
	if score > 300: return "C"
	return "D"

func _get_fatigue_color() -> Color:
	var afi: float = FatigueManager.current_afi
	if afi < 0.3: return SUCCESS_COLOR
	if afi < 0.6: return GOLD_COLOR
	if afi < 0.8: return Color("#FF8C42")
	return DANGER_COLOR

# ============================================================
# 按钮回调
# ============================================================

func _on_retry_pressed() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_menu_pressed() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_hall_pressed() -> void:
	_show_hall_of_harmony()

func _on_results_go_to_hall() -> void:
	if _run_results_screen:
		_run_results_screen.queue_free()
		_run_results_screen = null
	_showing_results = false
	_show_hall_of_harmony()
