## main_menu.gd
## 主菜单场景
## 极简主义设计：深色背景 + 神圣几何动态图案 + 呼吸感交互
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
# 状态
# ============================================================
var _time: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_ui()
	_setup_background()

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
	_title_label.add_theme_color_override("font_color", Color(0.0, 0.9, 0.7))
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.position.y = 200

	# 副标题
	var subtitle := Label.new()
	subtitle.text = "Where Music Becomes Magic"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position.y = 260
	add_child(subtitle)

	# 开始按钮
	if _start_button == null:
		_start_button = Button.new()
		_start_button.name = "StartButton"
		add_child(_start_button)

	_start_button.text = "BEGIN RESONANCE"
	_start_button.set_anchors_preset(Control.PRESET_CENTER)
	_start_button.position = Vector2(-100, 50)
	_start_button.custom_minimum_size = Vector2(200, 50)
	_style_button(_start_button, Color(0.0, 0.8, 0.6))
	_start_button.pressed.connect(_on_start_pressed)

	# 设置按钮
	if _settings_button == null:
		_settings_button = Button.new()
		_settings_button.name = "SettingsButton"
		add_child(_settings_button)

	_settings_button.text = "SETTINGS"
	_settings_button.set_anchors_preset(Control.PRESET_CENTER)
	_settings_button.position = Vector2(-100, 120)
	_settings_button.custom_minimum_size = Vector2(200, 50)
	_style_button(_settings_button, Color(0.4, 0.4, 0.5))

	# 退出按钮
	if _quit_button == null:
		_quit_button = Button.new()
		_quit_button.name = "QuitButton"
		add_child(_quit_button)

	_quit_button.text = "EXIT"
	_quit_button.set_anchors_preset(Control.PRESET_CENTER)
	_quit_button.position = Vector2(-100, 190)
	_quit_button.custom_minimum_size = Vector2(200, 50)
	_style_button(_quit_button, Color(0.3, 0.3, 0.4))
	_quit_button.pressed.connect(_on_quit_pressed)

	# 版本号
	if _version_label == null:
		_version_label = Label.new()
		_version_label.name = "VersionLabel"
		add_child(_version_label)

	_version_label.text = "v0.1.0 Alpha"
	_version_label.add_theme_font_size_override("font_size", 10)
	_version_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
	_version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_version_label.position = Vector2(-100, -30)

func _style_button(button: Button, accent_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	style.border_color = accent_color
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	button.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.12, 0.12, 0.2, 0.95)
	hover_style.border_color = accent_color * 1.3
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := style.duplicate()
	pressed_style.bg_color = accent_color * 0.3
	button.add_theme_stylebox_override("pressed", pressed_style)

	button.add_theme_color_override("font_color", Color.WHITE)

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
		# 呼吸感发光
		var glow := sin(_time * 1.5) * 0.2 + 0.8
		_title_label.modulate = Color(glow, glow, glow)

# ============================================================
# 按钮回调
# ============================================================

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
