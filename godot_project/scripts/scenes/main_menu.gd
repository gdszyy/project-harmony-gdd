## main_menu.gd
## 主菜单场景 - v2.2 UIColors Integration
## 极简主义设计：深色背景 + 神圣几何动态图案 + 呼吸感交互
## 修复：使用正确的锚点居中布局，适配不同分辨率
## v2.2: 替换硬编码颜色为 UIColors Autoload 引用
extends Control

# ============================================================
# 节点引用
# ============================================================
@onready var _title_label: Label = $TitleLabel
@onready var _start_button: Button = $StartButton
@onready var _settings_button: Button = $SettingsButton
@onready var _quit_button: Button = $QuitButton
@onready var _bg_visual: ColorRect = $BackgroundVisual
@onready var _version_label: Label = $VersionLabel

# ============================================================
# 颜色配置 (v2.2: 使用 UIColors Autoload 单例)
# ============================================================
var BG_BUTTON: Color
var BG_BUTTON_HOVER: Color
var BG_BUTTON_PRESSED: Color
var TITLE_COLOR: Color
var SUBTITLE_COLOR: Color
var VERSION_COLOR: Color

var BUTTON_CONFIGS: Array = []

# ============================================================
# 状态
# ============================================================
var _time: float = 0.0
var _buttons: Array[Button] = []
var _subtitle_label: Label = null
var _button_container: VBoxContainer = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_init_colors()
	_setup_ui()
	_setup_background()
	_play_entrance_animation()
	
	# 启动菜单 BGM
	if BGMManager.has_method("auto_select_bgm_for_state"):
		BGMManager.auto_select_bgm_for_state(GameManager.GameState.MENU)

func _process(delta: float) -> void:
	_time += delta
	_update_background()
	_update_title_animation()

# ============================================================
# 颜色初始化 (v2.2: 从 UIColors Autoload 读取)
# ============================================================

func _init_colors() -> void:
	BG_BUTTON = UIColors.with_alpha(UIColors.PANEL_BG, 0.9)
	BG_BUTTON_HOVER = UIColors.with_alpha(UIColors.PANEL_LIGHTER, 0.95)
	BG_BUTTON_PRESSED = UIColors.PANEL_SELECTED
	TITLE_COLOR = UIColors.TEXT_PRIMARY
	SUBTITLE_COLOR = UIColors.TEXT_SECONDARY
	VERSION_COLOR = UIColors.TEXT_DIM

	BUTTON_CONFIGS = [
		{ "name": "StartButton", "text": "BEGIN RESONANCE", "accent": UIColors.ACCENT },
		{ "name": "DifficultyButton", "text": "DIFFICULTY SELECT", "accent": UIColors.ACCENT_2 },
		{ "name": "TutorialButton", "text": "TUTORIAL", "accent": Color(0.3, 0.8, 0.5) },
		{ "name": "HallButton", "text": "HALL OF HARMONY", "accent": UIColors.GOLD },
		{ "name": "CodexButton", "text": "CODEX RESONARE", "accent": UIColors.ACCENT_2 },
		{ "name": "TestChamberButton", "text": "ECHOING CHAMBER", "accent": UIColors.WARNING },
		{ "name": "SettingsButton", "text": "SETTINGS", "accent": UIColors.TEXT_SECONDARY },
		{ "name": "QuitButton", "text": "EXIT", "accent": UIColors.TEXT_DIM },
	]

# ============================================================
# UI 设置 (v2.1 - 使用 VBoxContainer 居中布局)
# ============================================================

func _setup_ui() -> void:
	# ---- 标题 ----
	if _title_label == null:
		_title_label = Label.new()
		_title_label.name = "TitleLabel"
		add_child(_title_label)

	_title_label.text = "PROJECT HARMONY"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.add_theme_color_override("font_shadow_color", UIColors.with_alpha(UIColors.ACCENT, 0.25))
	_title_label.add_theme_constant_override("shadow_offset_x", 0)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	# 使用全宽居中锚点
	_title_label.anchor_left = 0.0
	_title_label.anchor_right = 1.0
	_title_label.anchor_top = 0.0
	_title_label.anchor_bottom = 0.0
	_title_label.offset_left = 0
	_title_label.offset_right = 0
	_title_label.offset_top = 0
	_title_label.offset_bottom = 60
	# 使用 size_flags 和 margin 来定位
	# 标题位于屏幕上方约 25% 处
	_title_label.anchor_top = 0.2
	_title_label.anchor_bottom = 0.2
	_title_label.offset_top = -30
	_title_label.offset_bottom = 30

	# ---- 副标题 ----
	_subtitle_label = Label.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.text = "Where Music Becomes Magic"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 16)
	_subtitle_label.add_theme_color_override("font_color", SUBTITLE_COLOR)
	_subtitle_label.anchor_left = 0.0
	_subtitle_label.anchor_right = 1.0
	_subtitle_label.anchor_top = 0.2
	_subtitle_label.anchor_bottom = 0.2
	_subtitle_label.offset_left = 0
	_subtitle_label.offset_right = 0
	_subtitle_label.offset_top = 35
	_subtitle_label.offset_bottom = 55
	add_child(_subtitle_label)

	# ---- 按钮容器（垂直居中）----
	_button_container = VBoxContainer.new()
	_button_container.name = "ButtonContainer"
	# 锚点居中
	_button_container.anchor_left = 0.5
	_button_container.anchor_right = 0.5
	_button_container.anchor_top = 0.42
	_button_container.anchor_bottom = 0.42
	_button_container.offset_left = -120
	_button_container.offset_right = 120
	_button_container.offset_top = 0
	_button_container.offset_bottom = 350
	_button_container.add_theme_constant_override("separation", 12)
	add_child(_button_container)

	# ---- 创建所有按钮 ----
	_buttons.clear()
	for config in BUTTON_CONFIGS:
		var button: Button
		var existing = get_node_or_null(config.name)
		if existing:
			button = existing
			existing.reparent(_button_container)
		else:
			button = Button.new()
			button.name = config.name
			_button_container.add_child(button)
		
		button.text = config.text
		button.custom_minimum_size = Vector2(240, 50)
		_style_button(button, config.accent)
		_buttons.append(button)
	
	# 连接按钮信号
	_buttons[0].pressed.connect(_on_start_pressed)
	_buttons[1].pressed.connect(_on_difficulty_pressed)
	_buttons[2].pressed.connect(_on_tutorial_pressed)
	_buttons[3].pressed.connect(_on_hall_pressed)
	_buttons[4].pressed.connect(_on_codex_pressed)
	_buttons[5].pressed.connect(_on_test_chamber_pressed)
	# _buttons[6] settings - can be connected later
	_buttons[7].pressed.connect(_on_quit_pressed)

	# ---- 版本号（右下角）----
	if _version_label == null:
		_version_label = Label.new()
		_version_label.name = "VersionLabel"
		add_child(_version_label)

	_version_label.text = "v0.2.0 Alpha"
	_version_label.add_theme_font_size_override("font_size", 10)
	_version_label.add_theme_color_override("font_color", VERSION_COLOR)
	_version_label.anchor_left = 1.0
	_version_label.anchor_right = 1.0
	_version_label.anchor_top = 1.0
	_version_label.anchor_bottom = 1.0
	_version_label.offset_left = -120
	_version_label.offset_right = -10
	_version_label.offset_top = -30
	_version_label.offset_bottom = -10

func _style_button(button: Button, accent_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_BUTTON
	style.border_color = accent_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = BG_BUTTON_HOVER
	hover_style.border_color = accent_color.lightened(0.2)
	hover_style.set_border_width_all(2) # Thicker border on hover
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.25)
	pressed_style.border_color = accent_color
	button.add_theme_stylebox_override("pressed", pressed_style)

	var focus_style := hover_style.duplicate()
	button.add_theme_stylebox_override("focus", focus_style)

	button.add_theme_color_override("font_color", TITLE_COLOR)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 14)

# ============================================================
# 入场动画
# ============================================================

func _play_entrance_animation() -> void:
	# 标题从上方滑入 + 淡入
	if _title_label:
		_title_label.modulate.a = 0.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_title_label, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	
	# 副标题淡入
	if _subtitle_label:
		_subtitle_label.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.2)
		tween.tween_property(_subtitle_label, "modulate:a", 1.0, 0.5)
	
	# 按钮依次淡入
	for i in range(_buttons.size()):
		var button = _buttons[i]
		button.modulate.a = 0.0
		var delay = 0.3 + i * 0.08
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(button, "modulate:a", 1.0, 0.3)

# ============================================================
# 背景
# ============================================================

func _setup_background() -> void:
	if _bg_visual == null:
		_bg_visual = ColorRect.new()
		_bg_visual.name = "BackgroundVisual"
		add_child(_bg_visual)
		move_child(_bg_visual, 0)

	_bg_visual.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 应用神圣几何 Shader
	var shader := load("res://shaders/sacred_geometry.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_bg_visual.material = mat

func _update_background() -> void:
	if _bg_visual and _bg_visual.material is ShaderMaterial:
		var mat: ShaderMaterial = _bg_visual.material
		mat.set_shader_parameter("time", _time)
		mat.set_shader_parameter("beat_energy", sin(_time * 2.0) * 0.3 + 0.5)

# ============================================================
# 标题动画
# ============================================================

func _update_title_animation() -> void:
	if _title_label:
		# 呼吸感发光 (使用新的调色板)
		var glow := sin(_time * 1.5) * 0.15 + 0.85
		_title_label.modulate = Color(glow, glow, glow + 0.05) # Slight blue tint on glow

# ============================================================
# 按钮回调
# ============================================================

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_codex_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/codex.tscn")

func _on_test_chamber_pressed() -> void:
	# v4.0: 测试场不再是独立场景，而是以测试模式启动正式游戏
	GameManager.is_test_mode = true
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_hall_pressed() -> void:
	# 打开和谐殿堂（局外成长系统）—— 审计报告 建议3 修复
	var hall_script := load("res://scripts/ui/hall_of_harmony.gd")
	if hall_script == null:
		return
	var hall := Control.new()
	hall.set_script(hall_script)
	hall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hall.z_index = 100
	add_child(hall)
	if hall.has_signal("start_game_pressed"):
		hall.start_game_pressed.connect(func():
			hall.queue_free()
			_on_start_pressed()
		)
	if hall.has_signal("back_pressed"):
		hall.back_pressed.connect(func():
			hall.queue_free()
		)

func _on_difficulty_pressed() -> void:
	# Issue #115: 打开难度选择面板
	var diff_ui_script := load("res://scripts/ui/difficulty_select_ui.gd")
	if diff_ui_script == null:
		return
	var diff_ui := Control.new()
	diff_ui.set_script(diff_ui_script)
	diff_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	diff_ui.z_index = 100
	add_child(diff_ui)
	if diff_ui.has_signal("difficulty_selected"):
		diff_ui.difficulty_selected.connect(func(_d: int):
			diff_ui.queue_free()
		)
	if diff_ui.has_signal("back_pressed"):
		diff_ui.back_pressed.connect(func():
			diff_ui.queue_free()
		)

func _on_tutorial_pressed() -> void:
	# Issue #115: 启动教程模式（强制重新开始教程）
	var tutorial_mgr := get_node_or_null("/root/TutorialManager")
	if tutorial_mgr:
		tutorial_mgr.tutorial_enabled = true
		tutorial_mgr._is_completed = false  # 允许重新开始
	GameManager.is_test_mode = false
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
