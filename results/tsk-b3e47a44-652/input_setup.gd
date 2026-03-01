## input_setup.gd
## 输入映射设置 (Autoload)
## 在游戏启动时注册所有自定义输入动作
extends Node

func _ready() -> void:
	_register_input_actions()

func _register_input_actions() -> void:
	# === 移动 ===
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])

	# === 白键施法 (ASDFGHJ 映射 C D E F G A B) ===
	_add_action("note_c", [KEY_A])
	_add_action("note_d", [KEY_S])
	_add_action("note_e", [KEY_D])
	_add_action("note_f", [KEY_F])
	_add_action("note_g", [KEY_G])
	_add_action("note_a", [KEY_H])
	_add_action("note_b", [KEY_J])

	# === 黑键修饰符 (WETYU 映射 C# D# F# G# A#) ===
	_add_action("modifier_cs", [KEY_W])
	_add_action("modifier_ds", [KEY_E])
	_add_action("modifier_fs", [KEY_T])
	_add_action("modifier_gs", [KEY_Y])
	_add_action("modifier_as", [KEY_U])

	# === 手动施法槽 ===
	_add_action("manual_cast_1", [KEY_1])
	_add_action("manual_cast_2", [KEY_2])
	_add_action("manual_cast_3", [KEY_3])

	# === UI 切换 ===
	_add_action("toggle_spellbook", [KEY_B])
	_add_action("toggle_alchemy", [KEY_V])
	_add_action("toggle_timbre", [KEY_Q])

	# === 频谱相位切换 (Issue #50 — Resonance Slicing) ===
	_add_action("phase_overtone", [KEY_Z])     # Z 键：切换到高通相位
	_add_action("phase_sub_bass", [KEY_X])     # X 键：切换到低通相位
	_add_action("phase_fundamental", [KEY_C])  # C 键：返回全频相位

	# === 音色切换快捷键 (Shift+数字键) ===
	# 注意：Shift+数字键的实际处理在 timbre_hotkey_manager.gd 中
	# 这里注册基础动作名称以便在 InputMap 中可查询
	_add_action("timbre_switch_1", [])  # Shift+1: 里拉琴
	_add_action("timbre_switch_2", [])  # Shift+2: 管风琴
	_add_action("timbre_switch_3", [])  # Shift+3: 羽管键琴
	_add_action("timbre_switch_4", [])  # Shift+4: 钢琴
	_add_action("timbre_switch_5", [])  # Shift+5: 管弦全奏
	_add_action("timbre_switch_6", [])  # Shift+6: 萨克斯
	_add_action("timbre_switch_7", [])  # Shift+7: 合成主脑
	_add_action("timbre_cycle_next", [])  # 循环切换下一个
	_add_action("timbre_cycle_prev", [])  # 循环切换上一个

	# === 系统 ===
	_add_action("pause_game", [KEY_ESCAPE])
	_add_action("toggle_sequencer", [KEY_TAB])

func _add_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for key in keys:
		var event := InputEventKey.new()
		event.keycode = key
		InputMap.action_add_event(action_name, event)
