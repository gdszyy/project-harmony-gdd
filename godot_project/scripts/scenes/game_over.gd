## game_over.gd
## 游戏结束场景
## 显示本局统计数据、成绩评价
extends Control

# ============================================================
# 节点引用
# ============================================================
@onready var _title_label: Label = $TitleLabel
@onready var _stats_container: VBoxContainer = $StatsContainer
@onready var _retry_button: Button = $RetryButton
@onready var _menu_button: Button = $MenuButton

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_ui()
	_display_stats()

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
	_title_label.add_theme_color_override("font_color", Color(0.8, 0.0, 0.2))
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

# ============================================================
# 统计显示
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
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.custom_minimum_size.x = 160
		row.add_child(name_label)

		var value_label := Label.new()
		value_label.text = stat[1]
		value_label.add_theme_color_override("font_color", Color(0.0, 0.9, 0.7))
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
