## hp_bar.gd
## 谐振完整度 (血条) UI
## 正弦波形式的血条，满血时平滑金色，低血时锯齿化红色
extends Control

# ============================================================
# 配置
# ============================================================
const BAR_WIDTH := 300.0
const BAR_HEIGHT := 30.0
const WAVE_POINTS := 60
const WAVE_AMPLITUDE := 8.0

# ============================================================
# 状态
# ============================================================
var _hp_ratio: float = 1.0
var _display_ratio: float = 1.0  # 平滑过渡
var _time: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	custom_minimum_size = Vector2(BAR_WIDTH + 20, BAR_HEIGHT + 20)
	GameManager.player_hp_changed.connect(_on_hp_changed)

func _process(delta: float) -> void:
	_time += delta
	_display_ratio = lerp(_display_ratio, _hp_ratio, delta * 5.0)
	queue_redraw()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var start := Vector2(10, size.y / 2.0)

	# 背景
	draw_rect(Rect2(Vector2(5, 5), Vector2(BAR_WIDTH + 10, BAR_HEIGHT + 10)), Color(0.05, 0.05, 0.1, 0.7))

	# 波形参数
	var frequency := 3.0 + (1.0 - _display_ratio) * 8.0  # 低血时频率更高
	var amplitude := WAVE_AMPLITUDE * _display_ratio
	var wave_type_mix := _display_ratio  # 1=正弦, 0=锯齿

	# 颜色
	var wave_color := Color(1.0, 0.85, 0.0)  # 金色
	if _display_ratio < 0.5:
		wave_color = Color(1.0, 0.2, 0.1)  # 红色
	elif _display_ratio < 0.75:
		wave_color = Color(1.0, 0.6, 0.0)  # 橙色

	# 绘制波形
	var points := PackedVector2Array()
	var fill_width := BAR_WIDTH * _display_ratio

	for i in range(WAVE_POINTS + 1):
		var t := float(i) / float(WAVE_POINTS)
		var x := start.x + t * fill_width

		# 正弦波 + 锯齿波混合
		var sine_val := sin(t * frequency * TAU + _time * 3.0)
		var saw_val := fmod(t * frequency + _time * 0.5, 1.0) * 2.0 - 1.0
		var wave_val := lerp(saw_val, sine_val, wave_type_mix)

		# 低血时添加不稳定抖动
		if _display_ratio < 0.3:
			wave_val += sin(_time * 20.0 + t * 50.0) * 0.3

		var y := start.y + wave_val * amplitude
		points.append(Vector2(x, y))

	# 绘制波形线
	if points.size() > 1:
		var line_width := 2.0 + (1.0 - _display_ratio) * 1.0
		draw_polyline(points, wave_color, line_width, true)

		# 发光效果
		var glow_color := wave_color
		glow_color.a = 0.3
		draw_polyline(points, glow_color, line_width + 3.0, true)

	# HP 文字
	var font := ThemeDB.fallback_font
	var hp_text := "%d / %d" % [int(GameManager.player_current_hp), int(GameManager.player_max_hp)]
	draw_string(font, Vector2(start.x + BAR_WIDTH / 2.0 - 20, start.y + BAR_HEIGHT / 2.0 + 3), hp_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1, 1, 1, 0.7))

	# 标签
	draw_string(font, Vector2(start.x, start.y - BAR_HEIGHT / 2.0 - 2), "RESONANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.5, 0.6))

# ============================================================
# 信号回调
# ============================================================

func _on_hp_changed(current_hp: float, max_hp: float) -> void:
	_hp_ratio = current_hp / max_hp if max_hp > 0 else 0.0
