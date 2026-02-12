## rhythm_indicator.gd — 节拍指示器 UI
## 静态外环 + 动态内缩环 + 完美/良好/错过 冲击波反馈
## 使用 _draw() + ShaderMaterial 实现
## 节拍同步通过 GameManager.beat_tick 信号
extends Control

# ============================================================
# 信号
# ============================================================
signal perfect_beat_hit()
signal good_beat_hit()
signal miss_beat()

# ============================================================
# 配置
# ============================================================
## 指示器直径 (px)
@export var indicator_size: float = 100.0
## 环形线宽
@export var ring_width: float = 3.0
## 完美卡拍窗口 (±ms)
@export var perfect_window_ms: float = 50.0
## 良好卡拍窗口 (±ms)
@export var good_window_ms: float = 100.0

# 颜色
var COLOR_RESONANCE_CYAN := UIColors.RESONANCE_CYAN     # #00FFD4
const COLOR_STARRY_PURPLE  := UIColors.PANEL_BG # #141026

# ============================================================
# 内部状态
# ============================================================
var _beat_progress: float = 0.0
var _beat_interval: float = 0.5
var _beat_timer: float = 0.0
var _current_beat_in_measure: int = 0
var _beats_per_measure: int = 4
var _time: float = 0.0

## 视觉反馈
var _flash_intensity: float = 0.0
var _flash_color: Color = Color.WHITE
var _shockwave_progress: float = 0.0
var _shockwave_color: Color = UIColors.GOLD

## 卡拍判定
var _last_beat_time: float = 0.0
var _beat_accuracy: String = ""

## 着色器
var _shader_material: ShaderMaterial = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	if not GameManager.beat_tick.is_connected(_on_beat_tick):
		GameManager.beat_tick.connect(_on_beat_tick)

	custom_minimum_size = Vector2(indicator_size + 20, indicator_size + 20)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_beat_interval = 60.0 / max(GameManager.current_bpm, 1.0)
	_apply_meta_timing_bonus()
	_setup_shader()

func _process(delta: float) -> void:
	_time += delta
	_beat_interval = 60.0 / max(GameManager.current_bpm, 1.0)

	# 更新节拍进度
	_beat_timer += delta
	_beat_progress = clamp(fmod(_beat_timer, _beat_interval) / _beat_interval, 0.0, 1.0)

	# 衰减视觉效果
	_flash_intensity = max(0.0, _flash_intensity - delta * 5.0)

	# 冲击波扩散
	if _shockwave_progress > 0.0:
		_shockwave_progress = max(0.0, _shockwave_progress - delta * 4.0)

	_beats_per_measure = GameManager.beats_per_measure if GameManager.has_method("get_beat_progress") else 4

	_update_shader_params()
	queue_redraw()

# ============================================================
# 着色器
# ============================================================

func _setup_shader() -> void:
	var shader := load("res://shaders/rhythm_indicator.gdshader")
	if shader:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = shader
		material = _shader_material

func _update_shader_params() -> void:
	if _shader_material == null:
		return
	_shader_material.set_shader_parameter("beat_progress", _beat_progress)
	_shader_material.set_shader_parameter("flash_intensity", _flash_intensity)
	_shader_material.set_shader_parameter("flash_color", Vector3(_flash_color.r, _flash_color.g, _flash_color.b))
	_shader_material.set_shader_parameter("time_sec", _time)
	_shader_material.set_shader_parameter("current_beat", _current_beat_in_measure)
	_shader_material.set_shader_parameter("beats_per_measure", _beats_per_measure)

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var center := size / 2.0
	var outer_radius := indicator_size / 2.0

	# === 1. 静态外环 ===
	_draw_outer_ring(center, outer_radius)

	# === 2. 动态内缩环 ===
	var inner_radius := outer_radius * (1.0 - _beat_progress)
	_draw_inner_ring(center, inner_radius)

	# === 3. 冲击波 ===
	if _shockwave_progress > 0.01:
		_draw_shockwave(center, outer_radius)

	# === 4. 中心脉冲 ===
	if _beat_progress < 0.15:
		var pulse_alpha := (1.0 - _beat_progress / 0.15) * 0.3
		draw_circle(center, outer_radius * 0.15, UIColors.with_alpha(COLOR_RESONANCE_CYAN, pulse_alpha))

	# === 5. BPM 文字 ===
	var font := ThemeDB.fallback_font
	var bpm_text := "%d" % int(GameManager.current_bpm)
	draw_string(font, center + Vector2(-10, 5), bpm_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, COLOR_RESONANCE_CYAN)

	# === 6. 卡拍精度文字 ===
	if _beat_accuracy != "" and _flash_intensity > 0.1:
		var accuracy_text := ""
		var accuracy_color := Color.WHITE
		match _beat_accuracy:
			"perfect":
				accuracy_text = "PERFECT!"
				accuracy_color = UIColors.GOLD
			"good":
				accuracy_text = "GOOD"
				accuracy_color = UIColors.SUCCESS
			"miss":
				accuracy_text = "MISS"
				accuracy_color = UIColors.ERROR_RED
		accuracy_color.a = _flash_intensity
		draw_string(font, Vector2(center.x - 22, size.y - 2), accuracy_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 11, accuracy_color)

func _draw_outer_ring(center: Vector2, radius: float) -> void:
	var total_ticks := _beats_per_measure * 4  # 16 ticks
	var segments := 64

	# 环形底色
	for i in range(segments):
		var a1 := (TAU / segments) * i
		var a2 := (TAU / segments) * (i + 1)
		var p1 := center + Vector2.from_angle(a1) * radius
		var p2 := center + Vector2.from_angle(a2) * radius
		draw_line(p1, p2, UIColors.with_alpha(UIColors.TEXT_PRIMARY, 0.2), ring_width, true)

	# 刻度标记
	for i in range(total_ticks):
		var angle := (TAU / total_ticks) * i - PI / 2.0
		var is_downbeat := (i % _beats_per_measure) == 0
		var tick_len := 8.0 if is_downbeat else 4.0
		var tick_alpha := 0.8 if is_downbeat else 0.4
		var tick_width := 2.0 if is_downbeat else 1.0

		var p_outer := center + Vector2.from_angle(angle) * (radius + tick_len * 0.5)
		var p_inner := center + Vector2.from_angle(angle) * (radius - tick_len * 0.5)
		draw_line(p_inner, p_outer, UIColors.with_alpha(UIColors.TEXT_PRIMARY, tick_alpha), tick_width, true)

func _draw_inner_ring(center: Vector2, radius: float) -> void:
	if radius < 2.0:
		return
	var segments := 48
	# 内缩环
	for i in range(segments):
		var a1 := (TAU / segments) * i
		var a2 := (TAU / segments) * (i + 1)
		var p1 := center + Vector2.from_angle(a1) * radius
		var p2 := center + Vector2.from_angle(a2) * radius
		draw_line(p1, p2, UIColors.with_alpha(COLOR_RESONANCE_CYAN, 0.8), ring_width + 1.0, true)

	# 辉光
	for i in range(segments):
		var a1 := (TAU / segments) * i
		var a2 := (TAU / segments) * (i + 1)
		var p1 := center + Vector2.from_angle(a1) * radius
		var p2 := center + Vector2.from_angle(a2) * radius
		draw_line(p1, p2, UIColors.with_alpha(COLOR_RESONANCE_CYAN, 0.2), ring_width + 5.0, true)

func _draw_shockwave(center: Vector2, base_radius: float) -> void:
	var shock_radius := base_radius + (1.0 - _shockwave_progress) * 20.0
	var shock_alpha := _shockwave_progress * 0.6
	var segments := 48
	for i in range(segments):
		var a1 := (TAU / segments) * i
		var a2 := (TAU / segments) * (i + 1)
		var p1 := center + Vector2.from_angle(a1) * shock_radius
		var p2 := center + Vector2.from_angle(a2) * shock_radius
		draw_line(p1, p2, UIColors.with_alpha(_shockwave_color, shock_alpha), 2.0 * _shockwave_progress, true)

# ============================================================
# 节拍回调
# ============================================================

func _on_beat_tick(beat_index: int) -> void:
	_beat_timer = 0.0
	_current_beat_in_measure = beat_index % _beats_per_measure
	_last_beat_time = Time.get_ticks_msec() / 1000.0
	_beats_per_measure = GameManager.beats_per_measure if GameManager.get("beats_per_measure") else 4

# ============================================================
# 卡拍判定接口
# ============================================================

## 判定当前攻击的卡拍精度
func judge_beat_accuracy() -> String:
	var current_time := Time.get_ticks_msec() / 1000.0
	var time_since_beat := current_time - _last_beat_time
	var time_to_next_beat := _beat_interval - time_since_beat
	var min_offset_ms: float = minf(time_since_beat, time_to_next_beat) * 1000.0

	if min_offset_ms <= perfect_window_ms:
		_beat_accuracy = "perfect"
		_flash_color = UIColors.GOLD
		_flash_intensity = 1.0
		_shockwave_progress = 1.0
		_shockwave_color = UIColors.GOLD
		perfect_beat_hit.emit()
	elif min_offset_ms <= good_window_ms:
		_beat_accuracy = "good"
		_flash_color = UIColors.SUCCESS
		_flash_intensity = 0.7
		_shockwave_progress = 0.5
		_shockwave_color = Color.WHITE
		good_beat_hit.emit()
	else:
		_beat_accuracy = "miss"
		_flash_color = UIColors.ERROR_RED
		_flash_intensity = 0.4
		miss_beat.emit()

	return _beat_accuracy

## 获取当前距离最近拍的偏移 (ms)
func get_beat_offset_ms() -> float:
	var current_time := Time.get_ticks_msec() / 1000.0
	var time_since_beat := current_time - _last_beat_time
	var time_to_next_beat := _beat_interval - time_since_beat
	return minf(time_since_beat, time_to_next_beat) * 1000.0

## 当前是否处于完美卡拍窗口内
func is_in_perfect_window() -> bool:
	return get_beat_offset_ms() <= perfect_window_ms

## 当前是否处于良好卡拍窗口内
func is_in_good_window() -> bool:
	return get_beat_offset_ms() <= good_window_ms

# ============================================================
# 局外升级加成
# ============================================================

func _apply_meta_timing_bonus() -> void:
	var bonus_ms: float = SaveManager.get_timing_window_bonus() if SaveManager.has_method("get_timing_window_bonus") else 0.0
	if bonus_ms > 0.0:
		perfect_window_ms += bonus_ms
		good_window_ms += bonus_ms
