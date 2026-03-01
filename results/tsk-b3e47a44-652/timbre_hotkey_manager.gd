## timbre_hotkey_manager.gd
## 音色切换快捷键绑定管理器
##
## 实现音色武器的快捷键切换功能：
## - 数字键 1-7 直接切换到对应章节的音色武器
## - Q 键打开音色轮盘（已有功能，此处补充直接切换逻辑）
## - Shift+数字键 切换到对应音色的电子乐变体
## - 鼠标滚轮 在已解锁音色间循环切换
##
## 快捷键映射：
##   Shift+1 → Ch1 里拉琴 / 正弦波合成
##   Shift+2 → Ch2 管风琴 / 无人机音合成
##   Shift+3 → Ch3 羽管键琴 / 琶音器合成
##   Shift+4 → Ch4 钢琴 / 力度感应垫
##   Shift+5 → Ch5 管弦全奏 / 超级锯齿波
##   Shift+6 → Ch6 萨克斯 / FM合成器
##   Shift+7 → Ch7 合成主脑 / 故障引擎
##   鼠标滚轮上/下 → 循环切换已解锁音色
##
## 用法：
##   作为 Autoload 或添加到主场景中
extends Node

# ============================================================
# 信号
# ============================================================
signal timbre_hotkey_pressed(timbre: int, is_electronic: bool)
signal timbre_cycle_changed(timbre: int, direction: int)

# ============================================================
# 配置
# ============================================================

## 快捷键到章节音色的映射
const HOTKEY_TIMBRE_MAP := {
	KEY_1: 1,  # MusicData.ChapterTimbre.LYRE
	KEY_2: 2,  # MusicData.ChapterTimbre.ORGAN
	KEY_3: 3,  # MusicData.ChapterTimbre.HARPSICHORD
	KEY_4: 4,  # MusicData.ChapterTimbre.FORTEPIANO
	KEY_5: 5,  # MusicData.ChapterTimbre.TUTTI
	KEY_6: 6,  # MusicData.ChapterTimbre.SAXOPHONE
	KEY_7: 7,  # MusicData.ChapterTimbre.SYNTHESIZER
}

## 音色名称映射（用于 UI 提示）
const TIMBRE_NAMES := {
	0: "无音色",
	1: "里拉琴",
	2: "管风琴",
	3: "羽管键琴",
	4: "钢琴",
	5: "管弦全奏",
	6: "萨克斯",
	7: "合成主脑",
}

## 是否启用快捷键（在某些 UI 打开时禁用）
var hotkeys_enabled: bool = true

## 是否启用鼠标滚轮切换
@export var enable_scroll_cycle: bool = true

## 切换提示显示时间（秒）
const HINT_DISPLAY_TIME := 1.5

# ============================================================
# 状态
# ============================================================
var _hint_timer: float = 0.0
var _hint_text: String = ""

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 注册快捷键输入动作
	_register_timbre_hotkeys()
	# 延迟连接信号
	call_deferred("_connect_signals")

func _process(delta: float) -> void:
	if _hint_timer > 0:
		_hint_timer -= delta

func _unhandled_input(event: InputEvent) -> void:
	if not hotkeys_enabled:
		return

	# Shift + 数字键：直接切换音色
	if event is InputEventKey and event.pressed and not event.is_echo():
		var key_event := event as InputEventKey
		if key_event.shift_pressed and key_event.keycode in HOTKEY_TIMBRE_MAP:
			var timbre: int = HOTKEY_TIMBRE_MAP[key_event.keycode]
			_switch_to_timbre(timbre, false)
			get_viewport().set_input_as_handled()
			return

		# Ctrl + Shift + 数字键：切换到电子乐变体
		if key_event.ctrl_pressed and key_event.shift_pressed and key_event.keycode in HOTKEY_TIMBRE_MAP:
			var timbre: int = HOTKEY_TIMBRE_MAP[key_event.keycode]
			_switch_to_timbre(timbre, true)
			get_viewport().set_input_as_handled()
			return

	# 鼠标滚轮：循环切换
	if enable_scroll_cycle and event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.shift_pressed:
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cycle_timbre(1)
				get_viewport().set_input_as_handled()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cycle_timbre(-1)
				get_viewport().set_input_as_handled()

# ============================================================
# 快捷键注册
# ============================================================

func _register_timbre_hotkeys() -> void:
	# 注册 timbre_switch_1 到 timbre_switch_7 的输入动作
	for key in HOTKEY_TIMBRE_MAP:
		var action_name := "timbre_switch_%d" % HOTKEY_TIMBRE_MAP[key]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var event := InputEventKey.new()
			event.keycode = key
			event.shift_pressed = true
			InputMap.action_add_event(action_name, event)

	# 注册循环切换动作
	if not InputMap.has_action("timbre_cycle_next"):
		InputMap.add_action("timbre_cycle_next")
	if not InputMap.has_action("timbre_cycle_prev"):
		InputMap.add_action("timbre_cycle_prev")

# ============================================================
# 信号连接
# ============================================================

func _connect_signals() -> void:
	# 监听 UI 状态变化，在某些 UI 打开时禁用快捷键
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_signal("ui_opened"):
			gm.ui_opened.connect(func(_ui_name): hotkeys_enabled = false)
		if gm.has_signal("ui_closed"):
			gm.ui_closed.connect(func(_ui_name): hotkeys_enabled = true)

# ============================================================
# 音色切换逻辑
# ============================================================

func _switch_to_timbre(timbre: int, electronic: bool) -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return

	# 检查音色是否已解锁
	if not gm.get("available_timbres"):
		return
	if timbre not in gm.available_timbres:
		_show_hint("音色未解锁: %s" % TIMBRE_NAMES.get(timbre, "未知"))
		return

	# 切换音色
	if gm.has_method("switch_timbre"):
		gm.switch_timbre(timbre)

	# 切换电子乐变体状态
	if gm.get("is_electronic_variant") != null:
		gm.is_electronic_variant = electronic

	var variant_text := " (电子变体)" if electronic else ""
	_show_hint("切换音色: %s%s" % [TIMBRE_NAMES.get(timbre, "未知"), variant_text])
	timbre_hotkey_pressed.emit(timbre, electronic)

func _cycle_timbre(direction: int) -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return

	var available: Array = gm.get("available_timbres") if gm.get("available_timbres") else []
	if available.is_empty():
		return

	var current: int = gm.get("active_chapter_timbre") if gm.get("active_chapter_timbre") != null else 0
	var current_index: int = available.find(current)
	if current_index < 0:
		current_index = 0

	var new_index: int = (current_index + direction) % available.size()
	if new_index < 0:
		new_index = available.size() - 1

	var new_timbre: int = available[new_index]
	if gm.has_method("switch_timbre"):
		gm.switch_timbre(new_timbre)

	_show_hint("切换音色: %s" % TIMBRE_NAMES.get(new_timbre, "未知"))
	timbre_cycle_changed.emit(new_timbre, direction)

# ============================================================
# UI 提示
# ============================================================

func _show_hint(text: String) -> void:
	_hint_text = text
	_hint_timer = HINT_DISPLAY_TIME
	# 尝试通过 HUD 显示提示
	var hud := get_node_or_null("/root/Main/HUD")
	if hud and hud.has_method("show_toast"):
		hud.show_toast(text, HINT_DISPLAY_TIME)

# ============================================================
# 公共接口
# ============================================================

## 启用/禁用快捷键
func set_hotkeys_enabled(enabled: bool) -> void:
	hotkeys_enabled = enabled

## 获取当前提示文本
func get_hint_text() -> String:
	return _hint_text if _hint_timer > 0 else ""

## 获取音色名称
func get_timbre_name(timbre: int) -> String:
	return TIMBRE_NAMES.get(timbre, "未知")
