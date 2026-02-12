## milestone_hud.gd
## 计时里程碑 HUD 显示组件
## Issue #115: 在游戏 HUD 中显示下一个里程碑的倒计时
##
## 功能：
##   - 显示下一个 Boss 里程碑的倒计时
##   - 里程碑接近时显示警告动画
##   - 里程碑完成时显示完成标记
extends CanvasLayer

# ============================================================
# 内部状态
# ============================================================
var _milestone_label: Label = null
var _progress_bar: ColorRect = null
var _progress_bg: ColorRect = null
var _warning_active: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 11
	_setup_ui()

func _process(_delta: float) -> void:
	_update_display()

# ============================================================
# UI 构建
# ============================================================

func _setup_ui() -> void:
	# 进度条背景
	_progress_bg = ColorRect.new()
	_progress_bg.name = "MilestoneProgressBG"
	_progress_bg.color = UIColors.with_alpha(UIColors.PANEL_DARK, 0.6)
	_progress_bg.anchor_left = 0.3
	_progress_bg.anchor_right = 0.7
	_progress_bg.anchor_top = 0.0
	_progress_bg.anchor_bottom = 0.0
	_progress_bg.offset_top = 5
	_progress_bg.offset_bottom = 10
	add_child(_progress_bg)

	# 进度条填充
	_progress_bar = ColorRect.new()
	_progress_bar.name = "MilestoneProgressFill"
	_progress_bar.color = UIColors.with_alpha(UIColors.DENSITY_SAFE, 0.8)
	_progress_bar.anchor_left = 0.3
	_progress_bar.anchor_right = 0.3  # 动态调整
	_progress_bar.anchor_top = 0.0
	_progress_bar.anchor_bottom = 0.0
	_progress_bar.offset_top = 5
	_progress_bar.offset_bottom = 10
	add_child(_progress_bar)

	# 里程碑标签
	_milestone_label = Label.new()
	_milestone_label.name = "MilestoneLabel"
	_milestone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_milestone_label.add_theme_font_size_override("font_size", 11)
	_milestone_label.add_theme_color_override("font_color", UIColors.with_alpha(UIColors.TEXT_SECONDARY, 0.9))
	_milestone_label.anchor_left = 0.3
	_milestone_label.anchor_right = 0.7
	_milestone_label.anchor_top = 0.0
	_milestone_label.anchor_bottom = 0.0
	_milestone_label.offset_top = 12
	_milestone_label.offset_bottom = 28
	add_child(_milestone_label)

# ============================================================
# 显示更新
# ============================================================

func _update_display() -> void:
	var milestone_mgr := get_node_or_null("/root/TimedMilestoneManager")
	if milestone_mgr == null or not milestone_mgr.timed_mode_enabled:
		_progress_bg.visible = false
		_progress_bar.visible = false
		_milestone_label.visible = false
		return

	_progress_bg.visible = true
	_progress_bar.visible = true
	_milestone_label.visible = true

	var remaining: float = milestone_mgr.get_time_to_next_milestone()
	var progress: float = milestone_mgr.get_milestone_progress()
	var milestone: Dictionary = milestone_mgr.get_current_milestone()

	if remaining < 0:
		_milestone_label.text = "所有里程碑已完成"
		_progress_bar.anchor_right = 0.7
		return

	# 更新进度条
	_progress_bar.anchor_right = 0.3 + 0.4 * progress

	# 更新标签
	var minutes: int = int(remaining) / 60
	var seconds: int = int(remaining) % 60
	var milestone_name: String = milestone.get("name", "下一个 Boss")
	_milestone_label.text = "%s — %02d:%02d" % [milestone_name, minutes, seconds]

	# 警告效果（最后 30 秒）
	if remaining <= 30.0 and not _warning_active:
		_warning_active = true
		_progress_bar.color = UIColors.with_alpha(UIColors.DANGER, 0.9)
	elif remaining > 30.0:
		_warning_active = false
		_progress_bar.color = UIColors.with_alpha(UIColors.DENSITY_SAFE, 0.8)
