## settings_menu.gd
## 设置菜单 — 模块1：主菜单与导航系统
##
## 设计规范来源: Docs/UI_Design_Module1_MainMenu.md §4.3
## 美术方向来源: Docs/Art_And_VFX_Direction.md 第10章
##
## 功能概述:
##   - 三个标签页: 音频(Audio)、画面(Video)、控制(Controls)
##   - 音频页: 主音量、音乐音量、音效音量滑块 + 量化模式选项
##   - 画面页: 分辨率、全屏/窗口模式、垂直同步、辉光强度
##   - 控制页: 按键绑定列表 + 恢复默认按钮
##   - 返回按钮位于面板右下角
##   - 所有设置实时应用并在关闭时持久化保存
##
## 节点结构 (对应 settings_menu.tscn):
##   SettingsMenu (Control)
##     ├── DimBackground (ColorRect)         — 半透明遮罩
##     ├── PanelContainer (1200x800)
##     │   └── MarginContainer
##     │       └── VBoxContainer
##     │           ├── TitleLabel
##     │           ├── TabContainer
##     │           │   ├── Audio (VBoxContainer)
##     │           │   ├── Video (VBoxContainer)
##     │           │   └── Controls (VBoxContainer)
##     │           └── BottomBar (HBoxContainer)
##     │               └── BackButton
##     └── (由脚本动态管理)
extends Control

# ============================================================
# 信号
# ============================================================

## 菜单关闭时发出，通知父级（主菜单或暂停菜单）
signal menu_closed

# ============================================================
# 颜色常量
# ============================================================

const COLOR_TITLE := Color("#EAE6FF")
const COLOR_SUBTITLE := Color("#A098C8")
const COLOR_ACCENT := Color("#9D6FFF")
const COLOR_DIM_BG := Color(0.039, 0.031, 0.078, 0.6)

# ============================================================
# 节点引用 — 音频标签页
# ============================================================

@onready var _master_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/MasterRow/MasterSlider
@onready var _master_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/MasterRow/MasterValue
@onready var _music_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/MusicRow/MusicSlider
@onready var _music_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/MusicRow/MusicValue
@onready var _sfx_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/SFXRow/SFXSlider
@onready var _sfx_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/SFXRow/SFXValue
@onready var _quantize_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/QuantizeRow/QuantizeOption

# ============================================================
# 节点引用 — 画面标签页
# ============================================================

@onready var _resolution_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Video/ResolutionRow/ResolutionOption
@onready var _fullscreen_check: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Video/FullscreenRow/FullscreenCheck
@onready var _vsync_check: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Video/VsyncRow/VsyncCheck
@onready var _glow_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Video/GlowRow/GlowSlider
@onready var _glow_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Video/GlowRow/GlowValue

# ============================================================
# 节点引用 — 控制标签页
# ============================================================

@onready var _controls_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Controls/ScrollContainer/ControlsList
@onready var _reset_controls_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Controls/ResetControlsButton

# ============================================================
# 节点引用 — 通用
# ============================================================

@onready var _back_button: Button = $PanelContainer/MarginContainer/VBoxContainer/BottomBar/BackButton
@onready var _dim_background: ColorRect = $DimBackground

# ============================================================
# 分辨率选项
# ============================================================

## 支持的分辨率列表
const RESOLUTIONS: Array = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

# ============================================================
# 按键绑定定义
# ============================================================

## 可重新绑定的操作列表
const REBINDABLE_ACTIONS: Array = [
	{ "action": "move_up", "display": "MOVE UP" },
	{ "action": "move_down", "display": "MOVE DOWN" },
	{ "action": "move_left", "display": "MOVE LEFT" },
	{ "action": "move_right", "display": "MOVE RIGHT" },
	{ "action": "pause", "display": "PAUSE" },
]

# ============================================================
# 状态
# ============================================================

## 是否正在等待按键输入（用于按键重绑定）
var _waiting_for_key: bool = false
## 当前正在重绑定的操作名称
var _rebinding_action: String = ""
## 当前正在重绑定的按钮引用
var _rebinding_button: Button = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 确保在暂停状态下也能操作
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 连接信号
	_connect_signals()

	# 加载并应用当前设置
	_load_current_settings()

	# 初始化画面设置选项
	_setup_video_options()

	# 初始化控制设置
	_setup_controls_list()

	# 播放入场动画
	_play_entrance_animation()


func _input(event: InputEvent) -> void:
	# 处理按键重绑定的输入捕获
	if _waiting_for_key and event is InputEventKey and event.pressed:
		_complete_rebinding(event)
		get_viewport().set_input_as_handled()

# ============================================================
# 信号连接
# ============================================================

func _connect_signals() -> void:
	# 音频滑块
	_master_slider.value_changed.connect(_on_master_value_changed)
	_music_slider.value_changed.connect(_on_music_value_changed)
	_sfx_slider.value_changed.connect(_on_sfx_value_changed)

	# 量化模式
	if _quantize_option:
		_quantize_option.item_selected.connect(_on_quantize_mode_changed)

	# 画面设置
	_resolution_option.item_selected.connect(_on_resolution_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_vsync_check.toggled.connect(_on_vsync_toggled)
	_glow_slider.value_changed.connect(_on_glow_value_changed)

	# 控制设置
	_reset_controls_button.pressed.connect(_on_reset_controls_pressed)

	# 返回按钮
	_back_button.pressed.connect(_on_back_pressed)

# ============================================================
# 设置加载
# ============================================================

## 从 SaveManager 加载当前设置并应用到 UI 控件
func _load_current_settings() -> void:
	var settings := SaveManager.load_settings()

	# 音频设置
	var master_vol: float = settings.get("master", 80.0)
	var music_vol: float = settings.get("music", 80.0)
	var sfx_vol: float = settings.get("sfx", 80.0)

	_master_slider.value = master_vol
	_music_slider.value = music_vol
	_sfx_slider.value = sfx_vol

	_update_volume_label(_master_value_label, master_vol)
	_update_volume_label(_music_value_label, music_vol)
	_update_volume_label(_sfx_value_label, sfx_vol)

	_apply_volume("Master", master_vol)
	_apply_volume("Music", music_vol)
	_apply_volume("SFX", sfx_vol)

	# 量化模式
	if _quantize_option:
		_quantize_option.clear()
		_quantize_option.add_item("FULL QUANTIZE", 0)
		_quantize_option.add_item("SOFT QUANTIZE", 1)
		_quantize_option.add_item("OFF", 2)
		var saved_mode: int = settings.get("quantize_mode", 0)
		_quantize_option.selected = saved_mode
		_apply_quantize_mode(saved_mode)

	# 画面设置
	var fullscreen: bool = settings.get("fullscreen", true)
	_fullscreen_check.button_pressed = fullscreen

	var vsync: bool = settings.get("vsync", true)
	_vsync_check.button_pressed = vsync

	var glow: float = settings.get("glow_intensity", 100.0)
	_glow_slider.value = glow
	_update_volume_label(_glow_value_label, glow)

# ============================================================
# 画面设置初始化
# ============================================================

## 初始化分辨率下拉菜单
func _setup_video_options() -> void:
	_resolution_option.clear()
	var current_size := DisplayServer.window_get_size()
	var selected_idx := 3  # 默认 1920x1080

	for i in range(RESOLUTIONS.size()):
		var res: Vector2i = RESOLUTIONS[i]
		_resolution_option.add_item("%dx%d" % [res.x, res.y], i)
		if res == current_size:
			selected_idx = i

	_resolution_option.selected = selected_idx

# ============================================================
# 控制设置初始化
# ============================================================

## 构建按键绑定列表
func _setup_controls_list() -> void:
	# 清空现有列表
	for child in _controls_list.get_children():
		child.queue_free()

	# 为每个可重绑定的操作创建一行
	for action_info in REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 40)

		# 操作名称标签
		var label := Label.new()
		label.text = action_info.display
		label.custom_minimum_size = Vector2(200, 0)
		label.add_theme_color_override("font_color", COLOR_SUBTITLE)
		label.add_theme_font_size_override("font_size", 16)
		row.add_child(label)

		# 间距
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		# 按键绑定按钮
		var key_button := Button.new()
		key_button.custom_minimum_size = Vector2(200, 36)
		key_button.text = _get_action_key_name(action_info.action)
		key_button.pressed.connect(_on_rebind_pressed.bind(action_info.action, key_button))
		row.add_child(key_button)

		_controls_list.add_child(row)

# ============================================================
# 音频回调
# ============================================================

## 主音量滑块变化
func _on_master_value_changed(value: float) -> void:
	_apply_volume("Master", value)
	_update_volume_label(_master_value_label, value)

## 音乐音量滑块变化
func _on_music_value_changed(value: float) -> void:
	_apply_volume("Music", value)
	_update_volume_label(_music_value_label, value)

## 音效音量滑块变化
func _on_sfx_value_changed(value: float) -> void:
	_apply_volume("SFX", value)
	_update_volume_label(_sfx_value_label, value)

## 将音量值应用到对应的音频总线
func _apply_volume(bus_name: String, value: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

## 更新音量数值标签显示
func _update_volume_label(label: Label, value: float) -> void:
	if label:
		label.text = "%d%%" % int(value)

## 量化模式切换
func _on_quantize_mode_changed(index: int) -> void:
	_apply_quantize_mode(index)

## 应用量化模式到音频系统
func _apply_quantize_mode(mode_index: int) -> void:
	if not AudioManager:
		return
	match mode_index:
		0:
			if AudioManager.has_method("set_quantize_mode"):
				AudioManager.set_quantize_mode(AudioEventQueue.QuantizeMode.FULL)
		1:
			if AudioManager.has_method("set_quantize_mode"):
				AudioManager.set_quantize_mode(AudioEventQueue.QuantizeMode.SOFT)
		2:
			if AudioManager.has_method("set_quantize_mode"):
				AudioManager.set_quantize_mode(AudioEventQueue.QuantizeMode.OFF)

# ============================================================
# 画面设置回调
# ============================================================

## 分辨率切换
func _on_resolution_changed(index: int) -> void:
	if index >= 0 and index < RESOLUTIONS.size():
		var res: Vector2i = RESOLUTIONS[index]
		DisplayServer.window_set_size(res)
		# 居中窗口
		var screen_size := DisplayServer.screen_get_size()
		var window_pos := (screen_size - res) / 2
		DisplayServer.window_set_position(window_pos)

## 全屏/窗口模式切换
func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

## 垂直同步切换
func _on_vsync_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

## 辉光强度变化
func _on_glow_value_changed(value: float) -> void:
	_update_volume_label(_glow_value_label, value)
	# 通知全局视觉环境更新辉光强度
	if GlobalVisualEnvironment3D and GlobalVisualEnvironment3D.has_method("set_glow_intensity"):
		GlobalVisualEnvironment3D.set_glow_intensity(value / 100.0)

# ============================================================
# 控制设置回调
# ============================================================

## 开始按键重绑定
func _on_rebind_pressed(action: String, button: Button) -> void:
	_waiting_for_key = true
	_rebinding_action = action
	_rebinding_button = button
	button.text = "[ PRESS KEY ]"
	button.add_theme_color_override("font_color", COLOR_ACCENT)

## 完成按键重绑定
func _complete_rebinding(event: InputEventKey) -> void:
	_waiting_for_key = false

	# 移除旧的按键绑定
	var old_events := InputMap.action_get_events(_rebinding_action)
	for old_event in old_events:
		InputMap.action_erase_event(_rebinding_action, old_event)

	# 添加新的按键绑定
	InputMap.action_add_event(_rebinding_action, event)

	# 更新按钮文本
	if _rebinding_button:
		_rebinding_button.text = event.as_text()
		_rebinding_button.remove_theme_color_override("font_color")

	_rebinding_action = ""
	_rebinding_button = null

## 恢复默认按键绑定
func _on_reset_controls_pressed() -> void:
	InputMap.load_from_project_settings()
	_setup_controls_list()

## 获取操作当前绑定的按键名称
func _get_action_key_name(action: String) -> String:
	var events := InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			return event.as_text()
	return "UNBOUND"

# ============================================================
# 入场/退场动画
# ============================================================

## 播放设置菜单的入场动画
func _play_entrance_animation() -> void:
	# 背景遮罩淡入
	if _dim_background:
		_dim_background.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_dim_background, "modulate:a", 1.0, 0.2)

	# 面板从下方滑入
	var panel := $PanelContainer
	if panel:
		panel.modulate.a = 0.0
		panel.position.y += 30.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(panel, "modulate:a", 1.0, 0.25) \
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "position:y", panel.position.y - 30.0, 0.3) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## 播放退场动画并关闭菜单
func _play_exit_animation() -> void:
	# 面板向下滑出 + 淡出
	var panel := $PanelContainer
	if panel:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(panel, "modulate:a", 0.0, 0.2) \
			.set_ease(Tween.EASE_IN)
		tween.tween_property(panel, "position:y", panel.position.y + 30.0, 0.2) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# 背景遮罩淡出
	if _dim_background:
		var tween := create_tween()
		tween.tween_property(_dim_background, "modulate:a", 0.0, 0.2)
		await tween.finished

# ============================================================
# 返回/关闭
# ============================================================

## 保存所有设置并关闭菜单
func _on_back_pressed() -> void:
	# 收集所有设置数据
	var settings := {
		"master": _master_slider.value,
		"music": _music_slider.value,
		"sfx": _sfx_slider.value,
		"quantize_mode": _quantize_option.selected if _quantize_option else 0,
		"fullscreen": _fullscreen_check.button_pressed,
		"vsync": _vsync_check.button_pressed,
		"glow_intensity": _glow_slider.value,
	}

	# 持久化保存
	SaveManager.save_settings(settings)

	# 播放退场动画
	await _play_exit_animation()

	# 发出关闭信号
	menu_closed.emit()

	# 如果没有父级监听信号，则自行隐藏
	visible = false
