## main_menu.gd
## 主菜单场景 - v2.0 Themed
## 极简主义设计：深色背景 + 神圣几何动态图案 + 呼吸感交互
## 优化：统一调色板、按钮交互增强、入场动画
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
# 颜色配置 (from UIColors / UI_Art_Style_Enhancement_Proposal.md)
# ============================================================
const BG_BUTTON := Color("#141026E6")
const BG_BUTTON_HOVER := Color("#201A38F2")
const BG_BUTTON_PRESSED := Color("#2A2248")
const TITLE_COLOR := Color("#EAE6FF")
const SUBTITLE_COLOR := Color("#A098C8")
const VERSION_COLOR := Color("#6B668A")

const BUTTON_CONFIGS: Array = [
	{ "name": "StartButton", "text": "BEGIN RESONANCE", "accent": Color("#9D6FFF") },
	{ "name": "CodexButton", "text": "CODEX RESONARE", "accent": Color("#4DFFF3") },
	{ "name": "TestChamberButton", "text": "ECHOING CHAMBER", "accent": Color("#FF8C42") },
	{ "name": "SettingsButton", "text": "SETTINGS", "accent": Color("#A098C8") },
	{ "name": "QuitButton", "text": "EXIT", "accent": Color("#6B668A") },
]

# ============================================================
# 状态
# ============================================================
var _time: float = 0.0
var _buttons: Array[Button] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
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
# UI 设置
# ============================================================

func _setup_ui() -> void:
	# 标题
	if _title_label == null:
		_title_label = Label.new()
		_title_label.name = "TitleLabel"
		add_child(_title_label)

	_title_label.text = "PROJECT HARMONY"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.add_theme_color_override("font_shadow_color", Color("#9D6FFF40"))
	_title_label.add_theme_constant_override("shadow_offset_x", 0)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.position.y = 200

	# 副标题
	var subtitle := Label.new()
	subtitle.text = "Where Music Becomes Magic"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position.y = 260
	add_child(subtitle)

	# 按钮容器
	var button_container := VBoxContainer.new()
	button_container.set_anchors_preset(Control.PRESET_CENTER)
	button_container.position = Vector2(-110, 30)
	button_container.custom_minimum_size = Vector2(220, 0)
	button_container.add_theme_constant_override("separation", 12)
	add_child(button_container)

	# 创建所有按钮
	_buttons.clear()
	for config in BUTTON_CONFIGS:
		var button: Button
		var existing = get_node_or_null(config.name)
		if existing:
			button = existing
			existing.reparent(button_container)
		else:
			button = Button.new()
			button.name = config.name
			button_container.add_child(button)
		
		button.text = config.text
		button.custom_minimum_size = Vector2(220, 50)
		_style_button(button, config.accent)
		_buttons.append(button)
	
	# 连接按钮信号
	_buttons[0].pressed.connect(_on_start_pressed)
	_buttons[1].pressed.connect(_on_codex_pressed)
	_buttons[2].pressed.connect(_on_test_chamber_pressed)
	# _buttons[3] settings - can be connected later
	_buttons[4].pressed.connect(_on_quit_pressed)

	# 版本号
	if _version_label == null:
		_version_label = Label.new()
		_version_label.name = "VersionLabel"
		add_child(_version_label)

	_version_label.text = "v0.2.0 Alpha"
	_version_label.add_theme_font_size_override("font_size", 10)
	_version_label.add_theme_color_override("font_color", VERSION_COLOR)
	_version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_version_label.position = Vector2(-100, -30)

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
		var original_y = _title_label.position.y
		_title_label.position.y = original_y - 40
		_title_label.modulate.a = 0.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_title_label, "position:y", original_y, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(_title_label, "modulate:a", 1.0, 0.5)
	
	# 按钮依次从下方滑入
	for i in range(_buttons.size()):
		var button = _buttons[i]
		var original_pos = button.position
		button.position.y += 30
		button.modulate.a = 0.0
		var delay = 0.3 + i * 0.08
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.set_parallel(true)
		tween.tween_property(button, "position:y", original_pos.y, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
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
	get_tree().change_scene_to_file("res://scenes/test_chamber.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
