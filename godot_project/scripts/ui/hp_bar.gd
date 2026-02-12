## hp_bar.gd — 谐振完整度 (血条) UI
## 正弦波形态弧形血条，满血时平滑青色正弦波，低血时锯齿/方波红色故障
## 使用 _draw() + ShaderMaterial 实现自定义绘制
## 节拍同步通过 GameManager.beat_tick 信号
extends Control

# ============================================================
# 配置
# ============================================================
## 弧形血条宽度 (px)
const ARC_WIDTH: float = 800.0
## 弧形血条高度 (px, 含辉光空间)
const ARC_HEIGHT: float = 150.0
## 波形采样点数
const WAVE_POINTS: int = 120
## 波形线宽
const LINE_WIDTH_BASE: float = 3.0
## 辉光线宽增量
const GLOW_WIDTH: float = 8.0

# 颜色常量
var COLOR_RESONANCE_CYAN := UIColors.RESONANCE_CYAN   # #00FFD4
var COLOR_DATA_ORANGE    := UIColors.DATA_ORANGE    # #FF8800
var COLOR_GLITCH_MAGENTA := UIColors.GLITCH_MAGENTA    # #FF00AA
var COLOR_CORRUPT_PURPLE := UIColors.CORRUPT_PURPLE    # #8800FF
const COLOR_STARRY_PURPLE  := UIColors.PANEL_BG # #141026

# ============================================================
# 状态
# ============================================================
var _hp_ratio: float = 1.0
var _display_ratio: float = 1.0
var _time: float = 0.0
var _beat_intensity: float = 0.0
var _hit_flash: float = 0.0
var _shader_material: ShaderMaterial = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	custom_minimum_size = Vector2(ARC_WIDTH, ARC_HEIGHT)
	size = Vector2(ARC_WIDTH, ARC_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 连接信号
	GameManager.player_hp_changed.connect(_on_hp_changed)
	GameManager.beat_tick.connect(_on_beat_tick)

	# 加载着色器
	_setup_shader()

func _process(delta: float) -> void:
	_time += delta
	_display_ratio = lerp(_display_ratio, _hp_ratio, delta * 5.0)

	# 衰减节拍强度
	_beat_intensity = max(0.0, _beat_intensity - delta * 4.0)

	# 衰减受击闪光
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta * 6.0)

	# 更新着色器参数
	_update_shader_params()
	queue_redraw()

# ============================================================
# 着色器设置
# ============================================================

func _setup_shader() -> void:
	var shader := load("res://shaders/hp_bar.gdshader")
	if shader:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = shader
		material = _shader_material

func _update_shader_params() -> void:
	if _shader_material == null:
		return
	_shader_material.set_shader_parameter("hp_ratio", _display_ratio)
	_shader_material.set_shader_parameter("beat_progress", GameManager.get_beat_progress() if GameManager.has_method("get_beat_progress") else 0.0)
	_shader_material.set_shader_parameter("beat_intensity", _beat_intensity)
	_shader_material.set_shader_parameter("hit_flash", _hit_flash)
	_shader_material.set_shader_parameter("time_sec", _time)

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var center_x := size.x / 2.0
	var center_y := size.y * 0.6

	# 背景弧形区域（半透明深色）
	var bg_points := PackedVector2Array()
	for i in range(WAVE_POINTS + 1):
		var t := float(i) / float(WAVE_POINTS)
		var x := t * ARC_WIDTH
		var arc_bend := sin(t * PI) * 20.0
		bg_points.append(Vector2(x, center_y - arc_bend))
	if bg_points.size() > 1:
		draw_polyline(bg_points, UIColors.with_alpha(COLOR_STARRY_PURPLE, 0.3), ARC_HEIGHT * 0.5, true)

	# 波形参数
	var frequency := 3.0 + (1.0 - _display_ratio) * 9.0
	var amplitude := 15.0 * _display_ratio + 3.0
	amplitude *= (1.0 + _beat_intensity * 0.15)

	# 绘制波形
	var wave_points := PackedVector2Array()
	var fill_width := ARC_WIDTH * _display_ratio

	for i in range(WAVE_POINTS + 1):
		var t := float(i) / float(WAVE_POINTS)
		var x := t * fill_width
		if x > fill_width:
			break

		# 弧形弯曲
		var arc_bend := sin((x / ARC_WIDTH) * PI) * 20.0

		# 波形混合
		var wave_t := t * frequency * TAU + _time * 3.0
		var wave_val := _get_waveform(wave_t, _display_ratio)

		# 低血量抖动
		if _display_ratio < 0.25:
			var jitter_strength := (0.25 - _display_ratio) / 0.25
			wave_val += sin(_time * 20.0 + t * 50.0) * 0.3 * jitter_strength

		var y := center_y - arc_bend + wave_val * amplitude

		# 受击故障偏移
		if _hit_flash > 0.1:
			var glitch_offset := sin(t * 100.0 + _time * 30.0) * _hit_flash * 5.0
			y += glitch_offset

		wave_points.append(Vector2(x, y))

	if wave_points.size() < 2:
		return

	# 获取颜色
	var wave_color := _get_hp_color(_display_ratio)

	# 受击时闪烁腐蚀紫
	if _hit_flash > 0.1:
		wave_color = wave_color.lerp(COLOR_CORRUPT_PURPLE, _hit_flash * 0.7)

	# 绘制辉光层
	var glow_color := UIColors.with_alpha(wave_color, 0.15 * (1.0 + _beat_intensity * 0.5))
	draw_polyline(wave_points, glow_color, LINE_WIDTH_BASE + GLOW_WIDTH, true)

	# 绘制主波形线
	var line_width := LINE_WIDTH_BASE + (1.0 - _display_ratio) * 1.5
	draw_polyline(wave_points, wave_color, line_width, true)

	# 绘制内辉光
	var inner_glow := UIColors.with_alpha(wave_color, 0.4)
	draw_polyline(wave_points, inner_glow, line_width + 3.0, true)

	# HP 文字
	var font := ThemeDB.fallback_font
	var hp_text := "%d / %d" % [int(GameManager.player_current_hp), int(GameManager.player_max_hp)]
	var text_pos := Vector2(center_x - 30, center_y + 35)
	draw_string(font, text_pos, hp_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, UIColors.with_alpha(UIColors.TEXT_PRIMARY, 0.8))

	# 标签
	draw_string(font, Vector2(center_x - 40, center_y - 40), "RESONANCE", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, UIColors.with_alpha(UIColors.TEXT_PRIMARY, 0.5))

	# 低血量故障方块
	if _display_ratio < 0.25:
		_draw_glitch_blocks(wave_color)

## 绘制故障方块效果
func _draw_glitch_blocks(base_color: Color) -> void:
	var glitch_strength := (0.25 - _display_ratio) / 0.25
	var block_count := int(glitch_strength * 8)
	for i in range(block_count):
		var seed_val := sin(float(i) * 127.1 + _time * 8.0)
		if seed_val > 0.3:
			var bx := fmod(abs(sin(float(i) * 311.7 + _time * 5.0)) * ARC_WIDTH, ARC_WIDTH * _display_ratio)
			var by := fmod(abs(cos(float(i) * 43.7 + _time * 7.0)) * ARC_HEIGHT, ARC_HEIGHT)
			var bw := 4.0 + abs(sin(float(i) * 17.3)) * 20.0
			var bh := 2.0 + abs(cos(float(i) * 23.1)) * 6.0
			var block_color := UIColors.with_alpha(base_color, glitch_strength * 0.4)
			draw_rect(Rect2(Vector2(bx, by), Vector2(bw, bh)), block_color)

# ============================================================
# 波形函数
# ============================================================

func _get_waveform(t: float, hp: float) -> float:
	var sine_val := sin(t)
	var tri_val := abs(fmod(t / PI, 2.0) - 1.0) * 2.0 - 1.0
	var saw_val := fmod(t / PI + 1.0, 2.0) - 1.0
	var sq_val := 1.0 if sin(t) > 0 else -1.0

	if hp > 0.75:
		return sine_val
	elif hp > 0.50:
		var blend := (0.75 - hp) / 0.25
		return lerp(sine_val, tri_val, blend)
	elif hp > 0.25:
		var blend := (0.50 - hp) / 0.25
		return lerp(tri_val, saw_val, blend)
	else:
		var blend := (0.25 - hp) / 0.25
		var noisy_sq := sq_val + sin(_time * 20.0 + t * 3.0) * 0.3 * blend
		return lerp(saw_val, noisy_sq, blend)

func _get_hp_color(hp: float) -> Color:
	if hp > 0.75:
		return COLOR_RESONANCE_CYAN
	elif hp > 0.50:
		var blend := (0.75 - hp) / 0.25
		return COLOR_RESONANCE_CYAN.lerp(COLOR_DATA_ORANGE, blend)
	elif hp > 0.25:
		var blend := (0.50 - hp) / 0.25
		return COLOR_DATA_ORANGE.lerp(UIColors.ERROR_RED, blend)
	else:
		var blend := (0.25 - hp) / 0.25
		var flicker := sin(_time * 15.0) * 0.5 + 0.5
		return UIColors.ERROR_RED.lerp(COLOR_GLITCH_MAGENTA, blend * flicker)

# ============================================================
# 信号回调
# ============================================================

func _on_hp_changed(current_hp: float, max_hp: float) -> void:
	var new_ratio := current_hp / max_hp if max_hp > 0 else 0.0
	# 受击检测
	if new_ratio < _hp_ratio:
		_hit_flash = 1.0
	_hp_ratio = new_ratio

func _on_beat_tick(_beat_index: int) -> void:
	_beat_intensity = 1.0

# ============================================================
# 公共接口
# ============================================================

## 外部触发受击闪光
func trigger_hit_flash() -> void:
	_hit_flash = 1.0

## 获取当前显示的 HP 比例
func get_display_ratio() -> float:
	return _display_ratio
