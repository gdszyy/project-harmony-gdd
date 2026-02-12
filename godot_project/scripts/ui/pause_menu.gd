## pause_menu.gd
## 暂停菜单 — 模块1：主菜单与导航系统
##
## 设计规范来源: Docs/UI_Design_Module1_MainMenu.md §4.2
## 美术方向来源: Docs/Art_And_VFX_Direction.md 第10章
##
## 功能概述:
##   - 以模态面板叠加在游戏画面之上
##   - 背景效果: 游戏画面暂停 + 高斯模糊 + 饱和度降低 + 50% 深渊黑遮罩
##   - 面板: 600x400px 居中，遵循全局面板背景和边框规范
##   - 导航按钮: 继续、设置、返回主菜单
##   - 显示当前局内统计信息
##   - 通过 GameManager.game_state_changed 信号驱动显示/隐藏
##
## 节点结构 (对应 pause_menu.tscn):
##   PauseMenu (Control)
##     ├── BlurBackground (ColorRect)      — 模糊 + 暗化遮罩
##     ├── PanelContainer (600x400)
##     │   └── MarginContainer
##     │       └── VBoxContainer
##     │           ├── TitleLabel
##     │           ├── StatsLabel
##     │           ├── Spacer
##     │           ├── ContinueButton
##     │           ├── SettingsButton
##     │           └── ReturnButton
##     └── (设置菜单由脚本动态实例化)
extends Control

# ============================================================
# 颜色常量
# ============================================================

## 背景遮罩色: 深渊黑 #0A0814, 50% 透明
const COLOR_OVERLAY := Color(0.039, 0.031, 0.078, 0.5)
## 标题色: 晶体白
const COLOR_TITLE := Color("#EAE6FF")
## 统计信息色: 次级文本
const COLOR_STATS := Color("#A098C8")

# ============================================================
# 动画参数
# ============================================================

## 面板入场动画时长
const PANEL_ANIM_DURATION := 0.25
## 按钮动效参数（与主菜单保持一致）
const HOVER_SCALE := 1.05
const PRESSED_SCALE := 0.95
const BUTTON_ANIM_DURATION := 0.12

# ============================================================
# 节点引用
# ============================================================

@onready var _blur_bg: ColorRect = $BlurBackground
@onready var _panel: PanelContainer = $PanelContainer
@onready var _title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var _stats_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsLabel
@onready var _continue_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ContinueButton
@onready var _settings_button: Button = $PanelContainer/MarginContainer/VBoxContainer/SettingsButton
@onready var _return_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ReturnButton

# ============================================================
# 状态
# ============================================================

## 所有菜单按钮的引用数组
var _menu_buttons: Array[Button] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 确保在暂停状态下也能处理输入和动画
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 初始状态为隐藏
	visible = false

	# 初始化按钮列表
	_menu_buttons = [_continue_button, _settings_button, _return_button]

	# 连接信号
	_connect_signals()

	# 设置按钮动效
	_setup_button_animations()

	# 监听 GameManager 的状态变化
	GameManager.game_state_changed.connect(_on_game_state_changed)


func _unhandled_input(event: InputEvent) -> void:
	# 按 ESC 键切换暂停状态
	if event.is_action_pressed("pause") and visible:
		_on_continue_pressed()
		get_viewport().set_input_as_handled()

# ============================================================
# 信号连接
# ============================================================

func _connect_signals() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_return_button.pressed.connect(_on_return_pressed)

# ============================================================
# GameManager 状态响应
# ============================================================

## 响应游戏状态变化，控制暂停菜单的显示/隐藏
func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.PAUSED:
			_show_menu()
		_:
			if visible:
				_hide_menu()

# ============================================================
# 菜单显示/隐藏
# ============================================================

## 显示暂停菜单，带入场动画
func _show_menu() -> void:
	visible = true
	_update_stats()

	# --- 背景遮罩淡入 ---
	if _blur_bg:
		_blur_bg.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_blur_bg, "modulate:a", 1.0, PANEL_ANIM_DURATION) \
			.set_ease(Tween.EASE_OUT)

	# --- 面板从中心缩放弹出 ---
	if _panel:
		_panel.modulate.a = 0.0
		_panel.scale = Vector2(0.9, 0.9)
		_panel.pivot_offset = _panel.size / 2.0

		var tween := create_tween().set_parallel(true)
		tween.tween_property(_panel, "modulate:a", 1.0, PANEL_ANIM_DURATION) \
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(_panel, "scale", Vector2.ONE, PANEL_ANIM_DURATION * 1.2) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# --- 按钮依次淡入 ---
	for i in range(_menu_buttons.size()):
		var button := _menu_buttons[i]
		button.modulate.a = 0.0
		var delay := PANEL_ANIM_DURATION * 0.5 + i * 0.06
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(button, "modulate:a", 1.0, 0.15) \
			.set_ease(Tween.EASE_OUT)


## 隐藏暂停菜单，带退场动画
func _hide_menu() -> void:
	# 面板缩小淡出
	if _panel:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_panel, "modulate:a", 0.0, PANEL_ANIM_DURATION * 0.8) \
			.set_ease(Tween.EASE_IN)
		tween.tween_property(_panel, "scale", Vector2(0.95, 0.95), PANEL_ANIM_DURATION * 0.8) \
			.set_ease(Tween.EASE_IN)

	# 背景淡出
	if _blur_bg:
		var tween := create_tween()
		tween.tween_property(_blur_bg, "modulate:a", 0.0, PANEL_ANIM_DURATION * 0.8) \
			.set_ease(Tween.EASE_IN)
		await tween.finished

	visible = false

# ============================================================
# 统计信息更新
# ============================================================

## 更新当前局内的游戏统计信息
func _update_stats() -> void:
	if not _stats_label:
		return

	var time_val: float = GameManager.game_time if "game_time" in GameManager else 0.0
	var mins := int(time_val) / 60
	var secs := int(time_val) % 60

	var level: int = GameManager.player_level if "player_level" in GameManager else 1
	var kills: int = GameManager.session_kills if "session_kills" in GameManager else 0
	var upgrades_count: int = GameManager.acquired_upgrades.size() if "acquired_upgrades" in GameManager else 0

	var stats_text := ""
	stats_text += "TIME     %02d:%02d\n" % [mins, secs]
	stats_text += "LEVEL    %d\n" % level
	stats_text += "KILLS    %d\n" % kills
	stats_text += "UPGRADES %d" % upgrades_count

	_stats_label.text = stats_text

# ============================================================
# 按钮动效 (与主菜单保持一致)
# ============================================================

## 为所有按钮设置悬停和按下的交互动效
func _setup_button_animations() -> void:
	for button in _menu_buttons:
		button.pivot_offset = button.size / 2.0
		button.mouse_entered.connect(_on_button_hover_enter.bind(button))
		button.mouse_exited.connect(_on_button_hover_exit.bind(button))
		button.button_down.connect(_on_button_down.bind(button))
		button.button_up.connect(_on_button_up.bind(button))
		button.resized.connect(func(): button.pivot_offset = button.size / 2.0)


## 悬停进入: 缩放 1.05x
func _on_button_hover_enter(button: Button) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), BUTTON_ANIM_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "modulate", Color(1.2, 1.2, 1.2), BUTTON_ANIM_DURATION)


## 悬停离开: 恢复
func _on_button_hover_exit(button: Button) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2.ONE, BUTTON_ANIM_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "modulate", Color.WHITE, BUTTON_ANIM_DURATION)


## 按下: 缩放 0.95x
func _on_button_down(button: Button) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2(PRESSED_SCALE, PRESSED_SCALE), BUTTON_ANIM_DURATION * 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "modulate", Color(0.8, 0.8, 0.8), BUTTON_ANIM_DURATION * 0.5)


## 释放: 恢复悬停状态
func _on_button_up(button: Button) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), BUTTON_ANIM_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "modulate", Color(1.2, 1.2, 1.2), BUTTON_ANIM_DURATION)

# ============================================================
# 按钮回调
# ============================================================

## 继续游戏 — 恢复游戏状态
func _on_continue_pressed() -> void:
	GameManager.resume_game()


## 打开设置菜单 — 实例化设置菜单并叠加显示
func _on_settings_pressed() -> void:
	var settings_scene := load("res://scenes/settings_menu.tscn")
	if settings_scene:
		var settings_menu := settings_scene.instantiate()
		settings_menu.z_index = 100
		add_child(settings_menu)
		if settings_menu.has_signal("menu_closed"):
			settings_menu.menu_closed.connect(func(): settings_menu.queue_free())


## 返回主菜单 — 取消暂停并切换到主菜单场景
func _on_return_pressed() -> void:
	# 先取消暂停状态
	get_tree().paused = false

	# 使用转场管理器切换（如果可用）
	if UITransitionManager:
		UITransitionManager.transition_to_scene("res://scenes/main_menu.tscn", "glitch")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
