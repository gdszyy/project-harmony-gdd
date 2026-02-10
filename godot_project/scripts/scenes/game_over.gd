## game_over.gd
## 游戏结束场景 v2.0 — 集成 RunResultsScreen + HallOfHarmony
## 流程：游戏结束 → 结算界面 → 和谐殿堂（可选）→ 重试/主菜单
## 审计报告 建议3 修复：打通 主菜单→游戏→结算→成长 完整循环
extends Control

# ============================================================
# 节点引用
# ============================================================
@onready var _title_label: Label = $TitleLabel
@onready var _stats_container: VBoxContainer = $StatsContainer
@onready var _retry_button: Button = $RetryButton
@onready var _menu_button: Button = $MenuButton

# ============================================================
# 动态创建的子系统
# ============================================================
var _run_results_screen: Node = null
var _hall_of_harmony: Control = null
var _showing_results: bool = false
var _showing_hall: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_ui()
	_display_stats()
	# 自动显示结算界面（覆盖在基础统计之上）
	_show_run_results()

# ============================================================
# UI 设置
# ============================================================

func _setup_ui() -> void:
	# 标题
	if _title_label == null:
		_title_label = Label.new()
		_title_label.name = "TitleLabel"
		add_child(_title_label)

	_title_label.text = "DISSONANCE"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 40)
	_title_label.add_theme_color_override("font_color", Color("#FF4D4D"))
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.position.y = 100

	# 统计容器
	if _stats_container == null:
		_stats_container = VBoxContainer.new()
		_stats_container.name = "StatsContainer"
		add_child(_stats_container)

	_stats_container.set_anchors_preset(Control.PRESET_CENTER)
	_stats_container.position = Vector2(-150, -50)
	_stats_container.custom_minimum_size = Vector2(300, 200)

	# 重试按钮
	if _retry_button == null:
		_retry_button = Button.new()
		_retry_button.name = "RetryButton"
		add_child(_retry_button)

	_retry_button.text = "RETRY"
	_retry_button.set_anchors_preset(Control.PRESET_CENTER)
	_retry_button.position = Vector2(-100, 180)
	_retry_button.custom_minimum_size = Vector2(200, 45)
	_retry_button.pressed.connect(_on_retry_pressed)

	# 返回菜单按钮
	if _menu_button == null:
		_menu_button = Button.new()
		_menu_button.name = "MenuButton"
		add_child(_menu_button)

	_menu_button.text = "MAIN MENU"
	_menu_button.set_anchors_preset(Control.PRESET_CENTER)
	_menu_button.position = Vector2(-100, 240)
	_menu_button.custom_minimum_size = Vector2(200, 45)
	_menu_button.pressed.connect(_on_menu_pressed)

	# 和谐殿堂按钮（新增）
	var hall_button := Button.new()
	hall_button.name = "HallButton"
	hall_button.text = "HALL OF HARMONY"
	hall_button.set_anchors_preset(Control.PRESET_CENTER)
	hall_button.position = Vector2(-100, 300)
	hall_button.custom_minimum_size = Vector2(200, 45)
	hall_button.pressed.connect(_on_hall_pressed)
	add_child(hall_button)

# ============================================================
# 结算界面（RunResultsScreen 集成）
# ============================================================

func _show_run_results() -> void:
	var run_results_script := load("res://scripts/ui/run_results_screen.gd")
	if run_results_script == null:
		return

	_run_results_screen = CanvasLayer.new()
	_run_results_screen.set_script(run_results_script)
	_run_results_screen.layer = 20
	add_child(_run_results_screen)

	# 连接结算界面信号
	if _run_results_screen.has_signal("go_to_hall_pressed"):
		_run_results_screen.go_to_hall_pressed.connect(_on_results_go_to_hall)
	if _run_results_screen.has_signal("retry_pressed"):
		_run_results_screen.retry_pressed.connect(_on_retry_pressed)
	if _run_results_screen.has_signal("main_menu_pressed"):
		_run_results_screen.main_menu_pressed.connect(_on_menu_pressed)

	# 构建结算数据
	var run_data := {
		"survival_time": GameManager.game_time,
		"total_kills": GameManager.session_kills,
		"bosses_defeated": 0,  # 可从 ChapterManager 获取
		"max_level": GameManager.player_level,
		"max_fatigue": FatigueManager.current_afi,
		"evaluation": _get_evaluation(),
	}

	# 显示结算界面
	if _run_results_screen.has_method("show_results"):
		_run_results_screen.show_results(run_data)
		_showing_results = true
		# 隐藏基础 UI（被结算界面覆盖）
		_title_label.visible = false
		_stats_container.visible = false
		_retry_button.visible = false
		_menu_button.visible = false
		var hall_btn = get_node_or_null("HallButton")
		if hall_btn:
			hall_btn.visible = false

# ============================================================
# 和谐殿堂（HallOfHarmony 集成）
# ============================================================

func _show_hall_of_harmony() -> void:
	var hall_script := load("res://scripts/ui/hall_of_harmony.gd")
	if hall_script == null:
		return

	_hall_of_harmony = Control.new()
	_hall_of_harmony.set_script(hall_script)
	_hall_of_harmony.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_hall_of_harmony)

	# 连接和谐殿堂信号
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
	# 恢复基础 UI
	_title_label.visible = true
	_stats_container.visible = true
	_retry_button.visible = true
	_menu_button.visible = true
	var hall_btn = get_node_or_null("HallButton")
	if hall_btn:
		hall_btn.visible = true

# ============================================================
# 统计显示（基础版，被 RunResultsScreen 覆盖）
# ============================================================

func _display_stats() -> void:
	if _stats_container == null:
		return

	# 清除旧内容
	for child in _stats_container.get_children():
		child.queue_free()

	var stats := [
		["Survival Time", _format_time(GameManager.game_time)],
		["Level Reached", str(GameManager.player_level)],
		["Enemies Silenced", str(GameManager.session_kills)],
		["Max Fatigue", "%.0f%%" % (FatigueManager.current_afi * 100)],
		["Evaluation", _get_evaluation()],
	]

	for stat in stats:
		var row := HBoxContainer.new()

		var name_label := Label.new()
		name_label.text = stat[0]
		name_label.add_theme_color_override("font_color", Color("#A098C8"))
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.custom_minimum_size.x = 160
		row.add_child(name_label)

		var value_label := Label.new()
		value_label.text = stat[1]
		value_label.add_theme_color_override("font_color", Color("#EAE6FF"))
		value_label.add_theme_font_size_override("font_size", 14)
		row.add_child(value_label)

		_stats_container.add_child(row)

func _format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%02d:%02d" % [mins, secs]

func _get_evaluation() -> String:
	var score := GameManager.game_time * 0.5 + GameManager.session_kills * 10.0 + GameManager.player_level * 100.0
	if score > 2000: return "S - HARMONIC MASTER"
	if score > 1200: return "A - RESONANCE"
	if score > 600: return "B - MELODY"
	if score > 300: return "C - RHYTHM"
	return "D - NOISE"

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
	# 从结算界面跳转到和谐殿堂
	if _run_results_screen:
		_run_results_screen.queue_free()
		_run_results_screen = null
	_showing_results = false
	_show_hall_of_harmony()
