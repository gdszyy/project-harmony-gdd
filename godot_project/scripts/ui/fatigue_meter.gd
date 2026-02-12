## fatigue_meter.gd — 听感疲劳指示器 UI
## 垂直光条，从纤细青色到红色锯齿波故障
## 使用 _draw() + ShaderMaterial 实现
## 节拍同步通过 GameManager.beat_tick 信号
extends Control

# ============================================================
# 配置
# ============================================================
## 光条宽度 (不含辉光)
const BAR_WIDTH: float = 20.0
## 光条高度
const BAR_HEIGHT: float = 400.0
## 辉光扩展宽度
const GLOW_EXTEND: float = 20.0
## 控件总宽度
const TOTAL_WIDTH: float = BAR_WIDTH + GLOW_EXTEND * 2.0
## 控件总高度
const TOTAL_HEIGHT: float = BAR_HEIGHT + 40.0

# 颜色常量
var COLOR_CYAN   := UIColors.RESONANCE_CYAN   # #00FFD4
var COLOR_YELLOW := UIColors.FATIGUE_YELLOW    # #FFE066
var COLOR_ORANGE := UIColors.DATA_ORANGE    # #FF8800
const COLOR_RED    := UIColors.ERROR_RED  # #FF2244

# 疲劳等级名称
const LEVEL_NAMES := {
	0: "CLEAR",
	1: "MILD",
	2: "MODERATE",
	3: "SEVERE",
	4: "OVERLOAD",
}

# ============================================================
# 状态
# ============================================================
var _afi: float = 0.0
var _display_afi: float = 0.0
var _time: float = 0.0
var _beat_intensity: float = 0.0
var _components: Dictionary = {}
var _fatigue_level: int = 0
var _shader_material: ShaderMaterial = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	custom_minimum_size = Vector2(TOTAL_WIDTH, TOTAL_HEIGHT)
	size = Vector2(TOTAL_WIDTH, TOTAL_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 连接信号
	FatigueManager.fatigue_updated.connect(_on_fatigue_updated)
	if FatigueManager.has_signal("fatigue_level_changed"):
		FatigueManager.fatigue_level_changed.connect(_on_level_changed)
	GameManager.beat_tick.connect(_on_beat_tick)

	_setup_shader()

func _process(delta: float) -> void:
	_time += delta
	_display_afi = lerp(_display_afi, _afi, delta * 8.0)
	_beat_intensity = max(0.0, _beat_intensity - delta * 4.0)

	_update_shader_params()
	queue_redraw()

# ============================================================
# 着色器
# ============================================================

func _setup_shader() -> void:
	var shader := load("res://shaders/fatigue_meter.gdshader")
	if shader:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = shader
		material = _shader_material

func _update_shader_params() -> void:
	if _shader_material == null:
		return
	_shader_material.set_shader_parameter("afi_ratio", _display_afi)
	_shader_material.set_shader_parameter("beat_intensity", _beat_intensity)
	_shader_material.set_shader_parameter("time_sec", _time)

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var bar_x := GLOW_EXTEND
	var bar_top := 20.0
	var bar_bottom := bar_top + BAR_HEIGHT

	# 背景条
	var bg_rect := Rect2(Vector2(bar_x, bar_top), Vector2(BAR_WIDTH, BAR_HEIGHT))
	draw_rect(bg_rect, UIColors.with_alpha(UIColors.PRIMARY_BG, 0.5))

	# 填充高度（从底部向上）
	var fill_height := BAR_HEIGHT * _display_afi
	var fill_top := bar_bottom - fill_height

	if fill_height < 1.0:
		_draw_labels(bar_x, bar_bottom)
		return

	# 获取颜色
	var bar_color := _get_afi_color(_display_afi)

	# 波形边缘宽度
	var base_width := BAR_WIDTH
	var wave_strength := clamp((_display_afi - 0.4) / 0.6, 0.0, 1.0)

	# 绘制填充区域（带波形边缘）
	var segments := int(fill_height / 2.0)
	for i in range(segments):
		var t := float(i) / float(max(segments, 1))
		var y := fill_top + t * fill_height
		var seg_height := fill_height / float(max(segments, 1)) + 1.0

		# 波形边缘偏移
		var edge_offset := 0.0
		if wave_strength > 0.0:
			var freq := lerp(4.0, 15.0, wave_strength)
			if _display_afi < 0.8:
				# 三角波
				edge_offset = abs(fmod((y / BAR_HEIGHT) * freq + _time * 2.0, 2.0) - 1.0) * 3.0 * wave_strength
			else:
				# 锯齿波 + 不规则
				edge_offset = fmod((y / BAR_HEIGHT) * freq + _time * 3.0, 1.0) * 4.0 * wave_strength
				edge_offset += sin(y * 0.5 + _time * 8.0) * 2.0 * wave_strength

		var seg_width := base_width + edge_offset * 2.0
		var seg_x := bar_x - edge_offset

		# 节拍脉动 (AFI > 0.6)
		var pulse_alpha := 1.0
		if _display_afi > 0.6 and _beat_intensity > 0.0:
			pulse_alpha = 1.0 + _beat_intensity * 0.3

		var seg_color := UIColors.with_alpha(bar_color, 0.8 * pulse_alpha)

		# 故障效果 (AFI > 0.8)
		if _display_afi > 0.8 and _beat_intensity > 0.3:
			var glitch_seed := sin(float(i) * 127.1 + _time * 15.0)
			if glitch_seed > 0.85:
				seg_color.r += 0.3
				seg_color.b -= 0.2
				seg_x += sin(_time * 30.0 + float(i)) * 3.0

		draw_rect(Rect2(Vector2(seg_x, y), Vector2(seg_width, seg_height)), seg_color)

	# 辉光效果
	var glow_color := UIColors.with_alpha(bar_color, 0.15 * (1.0 + _beat_intensity * 0.3))
	var glow_rect := Rect2(
		Vector2(bar_x - GLOW_EXTEND * 0.5, fill_top),
		Vector2(BAR_WIDTH + GLOW_EXTEND, fill_height)
	)
	draw_rect(glow_rect, glow_color)

	# 填充顶部边缘高亮
	var edge_color := UIColors.with_alpha(bar_color, 0.9)
	draw_line(
		Vector2(bar_x, fill_top),
		Vector2(bar_x + BAR_WIDTH, fill_top),
		edge_color, 2.0
	)

	# 阈值标记线
	var thresholds := [0.4, 0.6, 0.8]
	for threshold in thresholds:
		var mark_y := bar_bottom - BAR_HEIGHT * threshold
		draw_line(
			Vector2(bar_x - 3, mark_y),
			Vector2(bar_x + BAR_WIDTH + 3, mark_y),
			UIColors.with_alpha(UIColors.TEXT_PRIMARY, 0.3), 1.0
		)

	# 粒子喷发 (AFI > 0.6)
	if _display_afi > 0.6:
		_draw_particles(bar_x, fill_top, fill_height, bar_color)

	# 标签
	_draw_labels(bar_x, bar_bottom)

func _draw_labels(bar_x: float, bar_bottom: float) -> void:
	var font := ThemeDB.fallback_font
	var bar_color := _get_afi_color(_display_afi)

	# AFI 百分比
	var afi_text := "%.0f%%" % (_display_afi * 100.0)
	draw_string(font, Vector2(bar_x - 5, bar_bottom + 14), afi_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, bar_color)

	# 等级名称
	var level_name: String = LEVEL_NAMES.get(_fatigue_level, "CLEAR")
	draw_string(font, Vector2(bar_x - 5, bar_bottom + 28), level_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIColors.with_alpha(bar_color, 0.8))

func _draw_particles(bar_x: float, fill_top: float, fill_height: float, base_color: Color) -> void:
	var particle_strength := (_display_afi - 0.6) / 0.4
	var particle_count := int(particle_strength * 6)
	for i in range(particle_count):
		var seed_x := sin(float(i) * 73.1 + _time * 6.0)
		var seed_y := cos(float(i) * 37.7 + _time * 5.0)
		if abs(seed_x) > 0.5:
			var px := bar_x + BAR_WIDTH * 0.5 + seed_x * (BAR_WIDTH + 10.0)
			var py := fill_top + abs(seed_y) * fill_height
			var p_size := 1.5 + abs(seed_x) * 2.0
			draw_circle(Vector2(px, py), p_size, UIColors.with_alpha(base_color, particle_strength * 0.6))

# ============================================================
# 颜色计算
# ============================================================

func _get_afi_color(afi: float) -> Color:
	if afi < 0.4:
		return COLOR_CYAN
	elif afi < 0.6:
		var t := (afi - 0.4) / 0.2
		return COLOR_CYAN.lerp(COLOR_YELLOW, t)
	elif afi < 0.8:
		var t := (afi - 0.6) / 0.2
		return COLOR_YELLOW.lerp(COLOR_ORANGE, t)
	else:
		var t := (afi - 0.8) / 0.2
		return COLOR_ORANGE.lerp(COLOR_RED, t)

# ============================================================
# 信号回调
# ============================================================

func _on_fatigue_updated(result: Dictionary) -> void:
	_afi = result.get("afi", 0.0)
	_components = result.get("components", {})

func _on_level_changed(level) -> void:
	# 兼容枚举和整数
	_fatigue_level = int(level)

func _on_beat_tick(_beat_index: int) -> void:
	# 仅在 AFI > 0.6 时响应节拍
	if _display_afi > 0.6:
		_beat_intensity = 1.0

# ============================================================
# 公共接口
# ============================================================

func get_current_afi() -> float:
	return _display_afi

func get_fatigue_level() -> int:
	return _fatigue_level
