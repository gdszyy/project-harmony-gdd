## main_menu.gd
## 主菜单场景 — 模块1：主菜单与导航系统
##
## 设计规范来源: Docs/UI_Design_Module1_MainMenu.md
## 美术方向来源: Docs/Art_And_VFX_Direction.md 第10章
##
## 功能概述:
##   - 游戏 Logo 居中偏上，带扫光辉光效果
##   - 导航按钮垂直排列：继续、开始游戏、设置、图鉴、退出
##   - "继续"按钮仅在存在有效存档时可见
##   - 动态背景：sacred_geometry shader + 底部波形动画
##   - 入场动画：标题滑入 + 按钮依次淡入
##   - 按钮悬停/按下动效：缩放 + 辉光变化
##   - 通过 UITransitionManager 实现页面转场
##
## 节点结构 (对应 main_menu.tscn):
##   MainMenu (Control)
##     ├── BackgroundRect (ColorRect)        — 背景 shader
##     ├── WaveformRect (ColorRect)          — 底部波形 shader
##     ├── CenterContainer
##     │   └── VBoxContainer (MenuContainer)
##     │       ├── LogoLabel (Label)         — 游戏标题
##     │       ├── SubtitleLabel (Label)     — 副标题
##     │       ├── Spacer (Control)          — 间距
##     │       ├── ContinueButton (Button)
##     │       ├── StartButton (Button)
##     │       ├── SettingsButton (Button)
##     │       ├── CodexButton (Button)
##     │       └── QuitButton (Button)
##     └── VersionLabel (Label)              — 版本号
extends Control

# ============================================================
# 颜色常量 (来自 UIColors Autoload + 设计文档规范)
# ============================================================

## H1 标题色: 晶体白 #EAE6FF
const COLOR_TITLE := Color("#EAE6FF")
## H2 副标题色: 次级文本 #A098C8
const COLOR_SUBTITLE := Color("#A098C8")
## 按钮主强调色: #9D6FFF
const COLOR_ACCENT := Color("#9D6FFF")
## 面板背景色: 星空紫 #141026, 80% 不透明
const COLOR_PANEL_BG := Color(0.078, 0.063, 0.149, 0.8)
## 面板边框色: #9D6FFF, 40% 不透明
const COLOR_PANEL_BORDER := Color(0.616, 0.435, 1.0, 0.4)
## 深渊黑: #0A0814
const COLOR_ABYSS := Color("#0A0814")
## 版本号文本色
const COLOR_VERSION := Color("#6B668A")

# ============================================================
# 按钮动效参数 (来自设计文档 §6.1)
# ============================================================

## 悬停缩放倍率
const HOVER_SCALE := 1.05
## 按下缩放倍率
const PRESSED_SCALE := 0.95
## 悬停亮度增量 (+20%)
const HOVER_BRIGHTNESS := 1.2
## 按下亮度减量 (-20%)
const PRESSED_BRIGHTNESS := 0.8
## 按钮动效时长
const BUTTON_ANIM_DURATION := 0.12

# ============================================================
# 节点引用 (对应 .tscn 中的节点路径)
# ============================================================

@onready var _bg_rect: ColorRect = $BackgroundRect
@onready var _waveform_rect: ColorRect = $WaveformRect
@onready var _logo_label: Label = $CenterContainer/MenuContainer/LogoLabel
@onready var _subtitle_label: Label = $CenterContainer/MenuContainer/SubtitleLabel
@onready var _continue_button: Button = $CenterContainer/MenuContainer/ContinueButton
@onready var _start_button: Button = $CenterContainer/MenuContainer/StartButton
@onready var _settings_button: Button = $CenterContainer/MenuContainer/SettingsButton
@onready var _codex_button: Button = $CenterContainer/MenuContainer/CodexButton
@onready var _quit_button: Button = $CenterContainer/MenuContainer/QuitButton
@onready var _version_label: Label = $VersionLabel

# ============================================================
# 状态变量
# ============================================================

## 累计时间，用于驱动背景动画和标题呼吸效果
var _time: float = 0.0
## 所有菜单按钮的引用数组，用于批量操作
var _menu_buttons: Array[Button] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 初始化按钮列表
	_menu_buttons = [
		_continue_button,
		_start_button,
		_settings_button,
		_codex_button,
		_quit_button,
	]

	# 检查存档状态，决定"继续"按钮是否可见
	_update_continue_visibility()

	# 连接按钮信号
	_connect_button_signals()

	# 为所有按钮设置悬停/按下动效
	_setup_button_animations()

	# 设置背景 shader
	_setup_background()

	# 播放入场动画
	_play_entrance_animation()

	# 通知 GameManager 当前处于菜单状态
	if GameManager.current_state != GameManager.GameState.MENU:
		GameManager.current_state = GameManager.GameState.MENU
		GameManager.game_state_changed.emit(GameManager.GameState.MENU)

	# 启动菜单 BGM
	if BGMManager.has_method("auto_select_bgm_for_state"):
		BGMManager.auto_select_bgm_for_state(GameManager.GameState.MENU)


func _process(delta: float) -> void:
	_time += delta
	_update_background_uniforms()
	_update_title_glow()

# ============================================================
# 存档检测
# ============================================================

## 检查是否存在有效存档，控制"继续"按钮的可见性
func _update_continue_visibility() -> void:
	var has_save := SaveManager.get_total_runs() > 0
	_continue_button.visible = has_save

# ============================================================
# 信号连接
# ============================================================

## 连接所有按钮的 pressed 信号到对应的回调函数
func _connect_button_signals() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_codex_button.pressed.connect(_on_codex_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

# ============================================================
# 按钮动效系统 (设计文档 §6.1)
# ============================================================

## 为所有菜单按钮设置悬停和按下的交互动效
func _setup_button_animations() -> void:
	for button in _menu_buttons:
		# 设置按钮的 pivot 为中心，以便缩放时从中心变换
		button.pivot_offset = button.size / 2.0

		# 连接鼠标进入/离开信号
		button.mouse_entered.connect(_on_button_hover_enter.bind(button))
		button.mouse_exited.connect(_on_button_hover_exit.bind(button))

		# 连接按下/释放信号
		button.button_down.connect(_on_button_down.bind(button))
		button.button_up.connect(_on_button_up.bind(button))

		# 确保按钮大小变化时更新 pivot
		button.resized.connect(func(): button.pivot_offset = button.size / 2.0)


## 按钮悬停进入: 缩放 1.05x + 亮度 +20%
func _on_button_hover_enter(button: Button) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), BUTTON_ANIM_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "modulate", Color(HOVER_BRIGHTNESS, HOVER_BRIGHTNESS, HOVER_BRIGHTNESS), BUTTON_ANIM_DURATION)


## 按钮悬停离开: 恢复原始缩放和亮度
func _on_button_hover_exit(button: Button) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2.ONE, BUTTON_ANIM_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "modulate", Color.WHITE, BUTTON_ANIM_DURATION)


## 按钮按下: 缩放 0.95x + 亮度 -20%
func _on_button_down(button: Button) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2(PRESSED_SCALE, PRESSED_SCALE), BUTTON_ANIM_DURATION * 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "modulate", Color(PRESSED_BRIGHTNESS, PRESSED_BRIGHTNESS, PRESSED_BRIGHTNESS), BUTTON_ANIM_DURATION * 0.5)


## 按钮释放: 恢复悬停状态（因为鼠标仍在按钮上）
func _on_button_up(button: Button) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), BUTTON_ANIM_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "modulate", Color(HOVER_BRIGHTNESS, HOVER_BRIGHTNESS, HOVER_BRIGHTNESS), BUTTON_ANIM_DURATION)

# ============================================================
# 入场动画 (设计文档 §6)
# ============================================================

## 播放主菜单的入场动画序列
func _play_entrance_animation() -> void:
	# --- Logo 从上方滑入 + 淡入 ---
	if _logo_label:
		_logo_label.modulate.a = 0.0
		_logo_label.position.y -= 30.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_logo_label, "modulate:a", 1.0, 0.6) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_logo_label, "position:y", _logo_label.position.y + 30.0, 0.6) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# --- 副标题延迟淡入 ---
	if _subtitle_label:
		_subtitle_label.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.3)
		tween.tween_property(_subtitle_label, "modulate:a", 1.0, 0.5) \
			.set_ease(Tween.EASE_OUT)

	# --- 按钮依次淡入（从上到下，每个间隔 80ms）---
	var visible_buttons: Array[Button] = []
	for btn in _menu_buttons:
		if btn.visible:
			visible_buttons.append(btn)

	for i in range(visible_buttons.size()):
		var button := visible_buttons[i]
		button.modulate.a = 0.0
		button.position.x += 20.0  # 从右侧轻微滑入
		var delay := 0.4 + i * 0.08
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.set_parallel(true)
		tween.tween_property(button, "modulate:a", 1.0, 0.3) \
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "position:x", button.position.x - 20.0, 0.3) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# --- 版本号淡入 ---
	if _version_label:
		_version_label.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.8)
		tween.tween_property(_version_label, "modulate:a", 1.0, 0.4)

# ============================================================
# 背景视觉效果 (设计文档 §6.3)
# ============================================================

## 初始化背景 shader
func _setup_background() -> void:
	# 背景 sacred_geometry shader
	if _bg_rect:
		var shader := load("res://shaders/sacred_geometry.gdshader")
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			_bg_rect.material = mat

	# 底部波形 shader (如果存在)
	if _waveform_rect:
		var waveform_shader := load("res://shaders/waveform.gdshader") if ResourceLoader.exists("res://shaders/waveform.gdshader") else null
		if waveform_shader:
			var mat := ShaderMaterial.new()
			mat.shader = waveform_shader
			_waveform_rect.material = mat


## 每帧更新背景 shader 的 uniform 参数
func _update_background_uniforms() -> void:
	# 更新 sacred_geometry shader
	if _bg_rect and _bg_rect.material is ShaderMaterial:
		var mat: ShaderMaterial = _bg_rect.material
		mat.set_shader_parameter("time", _time)
		mat.set_shader_parameter("beat_energy", sin(_time * 2.0) * 0.3 + 0.5)

	# 更新波形 shader
	if _waveform_rect and _waveform_rect.material is ShaderMaterial:
		var mat: ShaderMaterial = _waveform_rect.material
		mat.set_shader_parameter("time", _time)

# ============================================================
# 标题呼吸辉光效果
# ============================================================

## 标题文字的呼吸感发光动画
func _update_title_glow() -> void:
	if _logo_label:
		# 使用正弦波驱动亮度变化，营造"呼吸"感
		var glow := sin(_time * 1.5) * 0.1 + 0.95
		# 轻微的蓝紫色调偏移，增强科幻感
		_logo_label.modulate = Color(glow, glow, glow + 0.03, _logo_label.modulate.a)

# ============================================================
# 按钮回调
# ============================================================

## 继续游戏 — 加载最近的存档并进入游戏
func _on_continue_pressed() -> void:
	SaveManager.load_game()
	if UITransitionManager:
		UITransitionManager.transition_to_scene("res://scenes/main_game.tscn", "glitch")
	else:
		get_tree().change_scene_to_file("res://scenes/main_game.tscn")


## 开始新游戏 — 重置状态并进入游戏
func _on_start_pressed() -> void:
	GameManager.is_test_mode = false
	if UITransitionManager:
		UITransitionManager.transition_to_scene("res://scenes/main_game.tscn", "glitch")
	else:
		get_tree().change_scene_to_file("res://scenes/main_game.tscn")


## 打开设置菜单 — 实例化设置菜单场景并叠加显示
func _on_settings_pressed() -> void:
	var settings_scene := load("res://scenes/settings_menu.tscn")
	if settings_scene:
		var settings_menu := settings_scene.instantiate()
		settings_menu.z_index = 50
		add_child(settings_menu)
		# 连接设置菜单的关闭信号
		if settings_menu.has_signal("menu_closed"):
			settings_menu.menu_closed.connect(func(): settings_menu.queue_free())


## 打开图鉴 — 通过转场切换到图鉴场景
func _on_codex_pressed() -> void:
	if UITransitionManager:
		UITransitionManager.transition_to_scene("res://scenes/codex.tscn", "glitch")
	else:
		get_tree().change_scene_to_file("res://scenes/codex.tscn")


## 退出游戏
func _on_quit_pressed() -> void:
	# 播放一个短暂的淡出效果后退出
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	get_tree().quit()
