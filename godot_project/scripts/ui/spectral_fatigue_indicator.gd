## spectral_fatigue_indicator.gd
## 频谱偏移疲劳 (SOF) 指示器 UI
## 位于主 AFI 条下方的破碎辉光条，模拟信号干扰和数据损坏
## 关联文档：Docs/UI_Design_Module6_ResonanceSlicing.md §5
extends Control

# ============================================================
# 常量
# ============================================================

## 条宽度
const BAR_WIDTH: float = 160.0
## 条高度
const BAR_HEIGHT: float = 6.0
## 标题高度
const TITLE_HEIGHT: float = 12.0

## SOF 颜色分级
const COLOR_LOW := UIColors.ACCENT     # 暗紫 (0%-30%)
const COLOR_MID := UIColors.MODE_BLUES     # 品红 (30%-60%)
const COLOR_HIGH := UIColors.FATIGUE_CRITICAL    # 刺眼品红 (80%-100%)

## 全局警告阈值
const GLOBAL_WARNING_THRESHOLD: float = 0.8

# ============================================================
# 状态
# ============================================================

var _sof_value: float = 0.0
var _display_value: float = 0.0
var _time: float = 0.0
var _is_warning_active: bool = false

## 抖动偏移（用于毛刺效果）
var _jitter_offset: Vector2 = Vector2.ZERO
## 破碎段数据
var _fragment_offsets: Array[float] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	custom_minimum_size = Vector2(BAR_WIDTH + 20, BAR_HEIGHT + TITLE_HEIGHT + 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 连接信号
	var rsm := get_node_or_null("/root/ResonanceSlicingManager")
	if rsm:
		rsm.spectrum_offset_fatigue_changed.connect(_on_sof_changed)
		rsm.spectrum_corruption_triggered.connect(_on_corruption_triggered)
		rsm.spectrum_corruption_cleared.connect(_on_corruption_cleared)

	# 初始化破碎段
	_fragment_offsets.resize(16)
	for i in range(16):
		_fragment_offsets[i] = 0.0

func _process(delta: float) -> void:
	_time += delta
	_display_value = lerp(_display_value, _sof_value, delta * 10.0)

	# 更新抖动
	_update_jitter(delta)

	# 更新破碎段
	_update_fragments(delta)

	queue_redraw()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var start := Vector2(10, 0)
	var font := ThemeDB.fallback_font

	# 标题
	var title_color := COLOR_LOW
	if _display_value > 0.6:
		title_color = COLOR_MID
	if _display_value > 0.8:
		title_color = COLOR_HIGH
	title_color.a = max(0.3, _display_value)
	draw_string(font, start + _jitter_offset * 0.3, "SPECTRUM OFFSET",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, title_color)
	start.y += TITLE_HEIGHT

	# 背景条
	draw_rect(Rect2(start, Vector2(BAR_WIDTH, BAR_HEIGHT)),
		UIColors.with_alpha(UIColors.PANEL_BG, 0.5))

	# 填充条
	if _display_value > 0.001:
		_draw_fill_bar(start)

	# 百分比数值（60%以上显示）
	if _display_value > 0.6:
		var value_text := "%d%%" % int(_display_value * 100.0)
		var value_color := COLOR_HIGH if _display_value > 0.8 else COLOR_MID
		value_color.a = (_display_value - 0.6) / 0.4
		draw_string(font, start + Vector2(BAR_WIDTH + 4, BAR_HEIGHT - 1) + _jitter_offset * 0.5,
			value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, value_color)

## 绘制填充条（含破碎效果）
func _draw_fill_bar(start: Vector2) -> void:
	var fill_width := BAR_WIDTH * _display_value
	var bar_color := _get_sof_color()

	if _display_value < 0.3:
		# 低疲劳：平滑光条
		var alpha := _display_value / 0.3 * 0.3
		bar_color.a = alpha
		draw_rect(Rect2(start + _jitter_offset * 0.1, Vector2(fill_width, BAR_HEIGHT)), bar_color)
		return

	if _display_value < 0.6:
		# 中疲劳：轻微毛刺
		var segment_count := 8
		var seg_width := fill_width / float(segment_count)
		for i in range(segment_count):
			var seg_start := start + Vector2(seg_width * float(i), 0)
			var offset := Vector2(_fragment_offsets[i] * 1.0, 0)
			var seg_color := bar_color
			seg_color.a = 0.5 + 0.2 * sin(_time * 3.0 + float(i))
			draw_rect(Rect2(seg_start + offset + _jitter_offset * 0.3,
				Vector2(seg_width - 1.0, BAR_HEIGHT)), seg_color)
		return

	# 高疲劳（60%+）：破碎效果
	var segment_count := 16
	var seg_width := fill_width / float(segment_count)
	var break_strength := (_display_value - 0.6) / 0.4

	for i in range(segment_count):
		var seg_start := start + Vector2(seg_width * float(i), 0)
		var y_offset := _fragment_offsets[i] * break_strength * 3.0
		var x_offset := _fragment_offsets[i] * break_strength * 2.0
		var offset := Vector2(x_offset, y_offset) + _jitter_offset

		# 随机可见性（模拟破碎）
		var visibility := 1.0
		if break_strength > 0.5:
			var flicker := sin(_time * 15.0 + float(i) * 2.7)
			if flicker > 0.8 - break_strength * 0.3:
				visibility = 0.3

		var seg_color := bar_color
		seg_color.a = visibility

		# 扫描线效果
		var scanline := 0.0
		if break_strength > 0.3:
			scanline = step(0.9, sin(float(i) * 5.0 + _time * 10.0)) * 0.4

		seg_color = seg_color.lightened(scanline)

		# 噪点纹理模拟
		var noise_brightness := sin(_time * 20.0 + float(i) * 13.7) * 0.1 * break_strength
		seg_color = seg_color.lightened(noise_brightness)

		draw_rect(Rect2(seg_start + offset,
			Vector2(seg_width - 1.0 * break_strength, BAR_HEIGHT)), seg_color)

	# 剧烈闪烁（80%以上）
	if _display_value > 0.8:
		var flash_alpha := (0.3 + 0.3 * sin(_time * 15.0)) * ((_display_value - 0.8) / 0.2)
		var flash_color := COLOR_HIGH
		flash_color.a = flash_alpha
		draw_rect(Rect2(start + _jitter_offset, Vector2(fill_width, BAR_HEIGHT)), flash_color)

# ============================================================
# 更新逻辑
# ============================================================

func _update_jitter(_delta: float) -> void:
	if _display_value < 0.3:
		_jitter_offset = Vector2.ZERO
		return

	var jitter_strength := (_display_value - 0.3) / 0.7
	var jitter_freq := lerp(0.5, 5.0, jitter_strength)

	# 周期性抖动
	if sin(_time * jitter_freq * TAU) > 0.7:
		_jitter_offset = Vector2(
			(randf() - 0.5) * jitter_strength * 4.0,
			(randf() - 0.5) * jitter_strength * 2.0
		)
	else:
		_jitter_offset = _jitter_offset.lerp(Vector2.ZERO, _time * 0.1)

func _update_fragments(_delta: float) -> void:
	for i in range(_fragment_offsets.size()):
		# 随机偏移更新
		if randf() < 0.1 * _display_value:
			_fragment_offsets[i] = (randf() - 0.5) * 2.0
		else:
			_fragment_offsets[i] = lerp(_fragment_offsets[i], 0.0, 0.05)

# ============================================================
# 信号回调
# ============================================================

func _on_sof_changed(value: float) -> void:
	_sof_value = value

	# 全局警告检测
	if _sof_value >= GLOBAL_WARNING_THRESHOLD and not _is_warning_active:
		_is_warning_active = true
		_trigger_global_warning()
	elif _sof_value < GLOBAL_WARNING_THRESHOLD and _is_warning_active:
		_is_warning_active = false

func _on_corruption_triggered() -> void:
	# 频谱失调触发 — 极端视觉效果
	_is_warning_active = true

func _on_corruption_cleared() -> void:
	_is_warning_active = false

# ============================================================
# 全局警告
# ============================================================

func _trigger_global_warning() -> void:
	# 通知 HUD 触发全局视觉警告
	# 屏幕边缘品红色脉冲 + 全屏轻微扭曲 + HUD 元素抖动
	var hud := get_parent()
	if hud and hud.has_method("trigger_spectrum_warning"):
		hud.trigger_spectrum_warning(_sof_value)

# ============================================================
# 辅助方法
# ============================================================

func _get_sof_color() -> Color:
	if _display_value < 0.3:
		return COLOR_LOW
	elif _display_value < 0.6:
		var t := (_display_value - 0.3) / 0.3
		return COLOR_LOW.lerp(COLOR_MID, t)
	elif _display_value < 0.8:
		var t := (_display_value - 0.6) / 0.2
		return COLOR_MID.lerp(COLOR_HIGH, t)
	else:
		return COLOR_HIGH

# ============================================================
# 公共接口
# ============================================================

## 手动设置 SOF 值
func set_sof_value(value: float) -> void:
	_sof_value = clamp(value, 0.0, 1.0)

## 获取当前显示值
func get_display_value() -> float:
	return _display_value
