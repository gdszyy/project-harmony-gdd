## ui_animation_helper.gd
## 全局 UI 动画辅助工具 (Autoload)
##
## 提供统一的 UI 动画效果，确保所有界面的交互反馈一致。
## 包含：
## - 按钮交互增强 (悬停放大、按下缩小)
## - 面板入场动画 (从中心展开 + 数字故障)
## - 节拍同步脉动 (跟随BPM)
## - 通用 Tween 工厂方法
extends Node

# ============================================================
# 常量
# ============================================================
const HOVER_SCALE := Vector2(1.05, 1.05)
const PRESS_SCALE := Vector2(0.95, 0.95)
const NORMAL_SCALE := Vector2(1.0, 1.0)
const HOVER_DURATION := 0.12
const PRESS_DURATION := 0.08
const PANEL_ENTER_DURATION := 0.35
const PANEL_EXIT_DURATION := 0.25

# ============================================================
# 按钮交互增强
# ============================================================

## 为一个按钮添加悬停和按下的缩放动画
func enhance_button(button: BaseButton) -> void:
	button.mouse_entered.connect(_on_button_hover.bind(button))
	button.mouse_exited.connect(_on_button_unhover.bind(button))
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))
	button.pivot_offset = button.size / 2.0

## 批量增强一个容器下的所有按钮
func enhance_all_buttons(container: Node) -> void:
	for child in container.get_children():
		if child is BaseButton:
			enhance_button(child)
		if child.get_child_count() > 0:
			enhance_all_buttons(child)

func _on_button_hover(button: BaseButton) -> void:
	if button.disabled:
		return
	var tween := button.create_tween()
	tween.tween_property(button, "scale", HOVER_SCALE, HOVER_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_button_unhover(button: BaseButton) -> void:
	var tween := button.create_tween()
	tween.tween_property(button, "scale", NORMAL_SCALE, HOVER_DURATION).set_ease(Tween.EASE_OUT)

func _on_button_down(button: BaseButton) -> void:
	var tween := button.create_tween()
	tween.tween_property(button, "scale", PRESS_SCALE, PRESS_DURATION).set_ease(Tween.EASE_IN)

func _on_button_up(button: BaseButton) -> void:
	var tween := button.create_tween()
	tween.tween_property(button, "scale", HOVER_SCALE, PRESS_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

# ============================================================
# 面板入场/退场动画
# ============================================================

## 播放面板入场动画 (从中心展开 + 淡入)
func play_panel_enter(panel: Control, callback: Callable = Callable()) -> void:
	panel.visible = true
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = panel.size / 2.0
	
	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, PANEL_ENTER_DURATION)
	tween.tween_property(panel, "scale", Vector2.ONE, PANEL_ENTER_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	if callback.is_valid():
		tween.chain()
		tween.tween_callback(callback)

## 播放面板退场动画 (缩小 + 淡出)
func play_panel_exit(panel: Control, callback: Callable = Callable()) -> void:
	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, PANEL_EXIT_DURATION)
	tween.tween_property(panel, "scale", Vector2(0.9, 0.9), PANEL_EXIT_DURATION).set_ease(Tween.EASE_IN)
	
	tween.chain()
	tween.tween_callback(func():
		panel.visible = false
		if callback.is_valid():
			callback.call()
	)

# ============================================================
# 节拍同步脉动
# ============================================================

## 让一个 Control 节点跟随 BPM 进行微弱的辉光脉动
## 需要该节点有一个 ShaderMaterial
func start_beat_pulse(control: Control, bpm: float = 120.0) -> void:
	var beat_interval := 60.0 / bpm
	_pulse_loop(control, beat_interval)

func _pulse_loop(control: Control, interval: float) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	
	var tween := control.create_tween()
	tween.tween_property(control, "modulate", Color(1.15, 1.15, 1.15, 1.0), interval * 0.15)
	tween.tween_property(control, "modulate", Color.WHITE, interval * 0.85)
	tween.tween_callback(_pulse_loop.bind(control, interval))

# ============================================================
# 通用特效
# ============================================================

## 播放一个快速的"数字故障"闪烁效果
func play_glitch_flash(control: Control, duration: float = 0.2) -> void:
	var original_pos := control.position
	var tween := control.create_tween()
	
	# 快速的位置抖动 + 色彩偏移
	var steps := 4
	var step_dur := duration / float(steps)
	for i in range(steps):
		var offset := Vector2(randf_range(-3, 3), randf_range(-2, 2))
		var color_shift := Color(randf_range(0.9, 1.1), randf_range(0.9, 1.1), randf_range(0.9, 1.1))
		tween.tween_property(control, "position", original_pos + offset, step_dur * 0.5)
		tween.tween_property(control, "modulate", color_shift, step_dur * 0.5)
	
	# 恢复
	tween.tween_property(control, "position", original_pos, step_dur)
	tween.tween_property(control, "modulate", Color.WHITE, step_dur)

## 播放一个数值"跳动"动画 (用于分数、伤害数字等)
func play_number_pop(label: Label, target_value: int, duration: float = 0.5) -> void:
	var start_value := int(label.text) if label.text.is_valid_int() else 0
	var tween := label.create_tween()
	
	# 数值滚动
	tween.tween_method(func(val: float):
		label.text = str(int(val))
	, float(start_value), float(target_value), duration)
	
	# 同时播放缩放弹跳
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), duration * 0.3).set_ease(Tween.EASE_OUT)
	tween.chain()
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), duration * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
