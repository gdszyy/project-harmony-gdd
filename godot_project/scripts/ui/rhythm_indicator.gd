## rhythm_indicator.gd
## 节拍指示器 UI
## 在屏幕上显示当前节拍状态，提供完美卡拍的视觉反馈。
## 包含：
##   - 节拍环形进度条
##   - 完美卡拍金色闪光
##   - 节拍计数器（当前小节内的拍数）
##   - BPM 显示
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
## 指示器大小
@export var indicator_size: float = 80.0
## 环形进度条宽度
@export var ring_width: float = 6.0
## 完美卡拍窗口（占拍间隔的比例）
@export var perfect_window: float = 0.15
## 良好卡拍窗口
@export var good_window: float = 0.3

## 颜色配置
@export var ring_color: Color = Color(0.3, 0.6, 0.9, 0.6)
@export var beat_color: Color = Color(0.0, 0.9, 1.0, 0.9)
@export var perfect_color: Color = Color(1.0, 0.85, 0.2, 1.0)
@export var good_color: Color = Color(0.4, 0.9, 0.4, 0.8)
@export var miss_color: Color = Color(0.8, 0.2, 0.2, 0.6)

# ============================================================
# 内部状态
# ============================================================
var _beat_progress: float = 0.0  ## 当前拍内的进度 [0, 1]
var _beat_interval: float = 0.5  ## 拍间隔（秒）
var _beat_timer: float = 0.0
var _current_beat_in_measure: int = 0
var _beats_per_measure: int = 4

## 视觉反馈状态
var _flash_intensity: float = 0.0
var _flash_color: Color = Color.WHITE
var _pulse_scale: float = 1.0
var _beat_marker_alpha: float = 0.0

## 完美卡拍判定
var _last_beat_time: float = 0.0
var _beat_accuracy: String = ""  ## "perfect" / "good" / "miss" / ""

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 连接全局节拍信号
	if GameManager.beat_tick.is_connected(_on_beat_tick) == false:
		GameManager.beat_tick.connect(_on_beat_tick)
	
	# 设置最小尺寸
	custom_minimum_size = Vector2(indicator_size + 20, indicator_size + 40)
	
	# 初始化
	_beat_interval = 60.0 / GameManager.current_bpm

func _process(delta: float) -> void:
	# 更新拍间隔
	_beat_interval = 60.0 / max(GameManager.current_bpm, 1.0)
	
	# 更新节拍进度
	_beat_timer += delta
	_beat_progress = fmod(_beat_timer, _beat_interval) / _beat_interval
	
	# 衰减视觉效果
	_flash_intensity = max(0.0, _flash_intensity - delta * 5.0)
	_pulse_scale = lerp(_pulse_scale, 1.0, delta * 8.0)
	_beat_marker_alpha = max(0.0, _beat_marker_alpha - delta * 3.0)
	
	queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x / 2.0, size.y / 2.0 - 10.0)
	var radius := indicator_size / 2.0
	
	# 1. 背景环
	_draw_ring(center, radius, ring_width, ring_color * 0.3)
	
	# 2. 进度环（随节拍填充）
	_draw_progress_ring(center, radius, ring_width, ring_color, _beat_progress)
	
	# 3. 节拍标记点（四个方位，对应4/4拍）
	for i in range(_beats_per_measure):
		var angle := (TAU / _beats_per_measure) * i - PI / 2.0
		var marker_pos := center + Vector2.from_angle(angle) * radius
		var marker_color := beat_color if i == _current_beat_in_measure else ring_color * 0.5
		var marker_size := 5.0 if i == _current_beat_in_measure else 3.0
		draw_circle(marker_pos, marker_size, marker_color)
	
	# 4. 当前拍位置指示器
	var indicator_angle := _beat_progress * TAU - PI / 2.0
	var indicator_pos := center + Vector2.from_angle(indicator_angle) * radius
	var indicator_color := beat_color.lerp(_flash_color, _flash_intensity)
	draw_circle(indicator_pos, 4.0 * _pulse_scale, indicator_color)
	
	# 5. 中心节拍脉冲
	if _beat_marker_alpha > 0.0:
		var pulse_color := _flash_color
		pulse_color.a = _beat_marker_alpha * 0.6
		draw_circle(center, radius * 0.3 * _pulse_scale, pulse_color)
	
	# 6. 完美卡拍闪光
	if _flash_intensity > 0.3:
		var flash_ring_color := _flash_color
		flash_ring_color.a = _flash_intensity * 0.4
		_draw_ring(center, radius + 4.0, ring_width + 4.0, flash_ring_color)
	
	# 7. BPM 文本
	var bpm_text := "%d" % int(GameManager.current_bpm)
	draw_string(ThemeDB.fallback_font, center + Vector2(-12, 6), bpm_text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 14, beat_color)
	
	# 8. 卡拍精度文本
	if _beat_accuracy != "" and _flash_intensity > 0.1:
		var accuracy_text := ""
		var accuracy_color := Color.WHITE
		match _beat_accuracy:
			"perfect":
				accuracy_text = "PERFECT!"
				accuracy_color = perfect_color
			"good":
				accuracy_text = "GOOD"
				accuracy_color = good_color
			"miss":
				accuracy_text = "MISS"
				accuracy_color = miss_color
		
		accuracy_color.a = _flash_intensity
		draw_string(ThemeDB.fallback_font, 
			Vector2(center.x - 24, size.y - 4), accuracy_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 12, accuracy_color)

# ============================================================
# 绘制辅助
# ============================================================

func _draw_ring(center: Vector2, radius: float, width: float, color: Color) -> void:
	var segments := 64
	for i in range(segments):
		var angle_start := (TAU / segments) * i
		var angle_end := (TAU / segments) * (i + 1)
		var p1 := center + Vector2.from_angle(angle_start) * radius
		var p2 := center + Vector2.from_angle(angle_end) * radius
		draw_line(p1, p2, color, width, true)

func _draw_progress_ring(center: Vector2, radius: float, width: float, color: Color, progress: float) -> void:
	var segments := int(64 * progress)
	if segments < 1:
		return
	for i in range(segments):
		var angle_start := (TAU / 64) * i - PI / 2.0
		var angle_end := (TAU / 64) * (i + 1) - PI / 2.0
		var p1 := center + Vector2.from_angle(angle_start) * radius
		var p2 := center + Vector2.from_angle(angle_end) * radius
		draw_line(p1, p2, color, width + 1.0, true)

# ============================================================
# 节拍回调
# ============================================================

func _on_beat_tick(beat_index: int) -> void:
	_beat_timer = 0.0
	_current_beat_in_measure = beat_index % _beats_per_measure
	_last_beat_time = Time.get_ticks_msec() / 1000.0
	
	# 节拍脉冲效果
	_pulse_scale = 1.3
	_beat_marker_alpha = 1.0
	_flash_color = beat_color
	_flash_intensity = 0.5
	
	# 更新拍号
	_beats_per_measure = GameManager.beats_per_measure

# ============================================================
# 卡拍判定接口
# ============================================================

## 判定当前攻击的卡拍精度
## 返回: "perfect" / "good" / "miss"
func judge_beat_accuracy() -> String:
	var current_time := Time.get_ticks_msec() / 1000.0
	var time_since_beat := current_time - _last_beat_time
	var time_to_next_beat := _beat_interval - time_since_beat
	
	# 取距离最近的拍的时间差
	var min_offset := min(time_since_beat, time_to_next_beat)
	var offset_ratio := min_offset / _beat_interval
	
	if offset_ratio <= perfect_window:
		_beat_accuracy = "perfect"
		_flash_color = perfect_color
		_flash_intensity = 1.0
		_pulse_scale = 1.5
		perfect_beat_hit.emit()
	elif offset_ratio <= good_window:
		_beat_accuracy = "good"
		_flash_color = good_color
		_flash_intensity = 0.7
		_pulse_scale = 1.2
		good_beat_hit.emit()
	else:
		_beat_accuracy = "miss"
		_flash_color = miss_color
		_flash_intensity = 0.4
		miss_beat.emit()
	
	return _beat_accuracy

## 获取当前距离最近拍的偏移比例 [0, 0.5]
func get_beat_offset_ratio() -> float:
	var current_time := Time.get_ticks_msec() / 1000.0
	var time_since_beat := current_time - _last_beat_time
	var time_to_next_beat := _beat_interval - time_since_beat
	var min_offset := min(time_since_beat, time_to_next_beat)
	return min_offset / _beat_interval

## 当前是否处于完美卡拍窗口内
func is_in_perfect_window() -> bool:
	return get_beat_offset_ratio() <= perfect_window

## 当前是否处于良好卡拍窗口内
func is_in_good_window() -> bool:
	return get_beat_offset_ratio() <= good_window
