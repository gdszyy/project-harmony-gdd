## phase_indicator_ui.gd
## 三相位切换指示器 UI (高通/全频/低通)
## 核心视觉焦点：三扇区圆环 + 光弧切换动画 + 节拍脉动
## 位于玩家角色正下方，底部中央
## 关联文档：Docs/UI_Design_Module6_ResonanceSlicing.md §3
extends Control

# ============================================================
# 信号
# ============================================================

signal phase_switch_requested(target_phase: int)

# ============================================================
# 常量
# ============================================================

## 圆环半径
const RING_RADIUS: float = 36.0
## 扇区内半径
const SECTOR_INNER_R: float = 14.0
## 扇区外半径
const SECTOR_OUTER_R: float = 32.0
## 图标激活态缩放
const ACTIVE_SCALE: float = 1.2
## 图标未激活态缩放
const INACTIVE_SCALE: float = 0.8
## 切换动画时长
const SWITCH_ANIM_DURATION: float = 0.2
## 光弧扫过时长
const ARC_SWEEP_DURATION: float = 0.2

## 三扇区角度配置（中心角度，弧度）
## Overtone: 12点钟 (-PI/2), Fundamental: 4点钟 (PI/6), SubBass: 8点钟 (5*PI/6)
const SECTOR_ANGLES: Dictionary = {
	ResonanceSlicingManager.Phase.OVERTONE: -PI / 2.0,
	ResonanceSlicingManager.Phase.FUNDAMENTAL: PI / 6.0,
	ResonanceSlicingManager.Phase.SUB_BASS: 5.0 * PI / 6.0,
}

## 扇区半角（120° 扇区，留间隙）
const SECTOR_HALF_ANGLE: float = PI / 3.0 - 0.08

## 相位图标符号
const PHASE_ICONS: Dictionary = {
	ResonanceSlicingManager.Phase.OVERTONE: "△",     # 锐利向上三角
	ResonanceSlicingManager.Phase.FUNDAMENTAL: "◎",  # 稳定圆形
	ResonanceSlicingManager.Phase.SUB_BASS: "▽",     # 厚重倒三角
}

# ============================================================
# 状态
# ============================================================

var _current_phase: int = ResonanceSlicingManager.Phase.FUNDAMENTAL
var _sector_progress: Dictionary = {
	ResonanceSlicingManager.Phase.FUNDAMENTAL: 1.0,
	ResonanceSlicingManager.Phase.OVERTONE: 0.0,
	ResonanceSlicingManager.Phase.SUB_BASS: 0.0,
}
var _sector_scales: Dictionary = {
	ResonanceSlicingManager.Phase.FUNDAMENTAL: ACTIVE_SCALE,
	ResonanceSlicingManager.Phase.OVERTONE: INACTIVE_SCALE,
	ResonanceSlicingManager.Phase.SUB_BASS: INACTIVE_SCALE,
}
var _beat_pulse: float = 0.0
var _time: float = 0.0

## 光弧动画状态
var _arc_sweep_active: bool = false
var _arc_sweep_progress: float = 0.0
var _arc_sweep_from: int = 0
var _arc_sweep_to: int = 0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	custom_minimum_size = Vector2(RING_RADIUS * 2.5, RING_RADIUS * 2.5)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 连接 ResonanceSlicingManager 信号
	var rsm := _get_rsm()
	if rsm:
		rsm.phase_changed.connect(_on_phase_changed)

	# 连接节拍信号
	var gmm := get_node_or_null("/root/GlobalMusicManager")
	if gmm and gmm.has_signal("beat_energy_updated"):
		gmm.beat_energy_updated.connect(_on_beat_energy_updated)

func _process(delta: float) -> void:
	_time += delta

	# 节拍脉冲衰减
	_beat_pulse = max(0.0, _beat_pulse - delta * 3.0)

	# 光弧动画更新
	if _arc_sweep_active:
		_arc_sweep_progress += delta / ARC_SWEEP_DURATION
		if _arc_sweep_progress >= 1.0:
			_arc_sweep_progress = 1.0
			_arc_sweep_active = false

	# 平滑插值扇区进度和缩放
	for phase_id in _sector_progress.keys():
		var target_progress: float = 1.0 if phase_id == _current_phase else 0.0
		_sector_progress[phase_id] = lerp(_sector_progress[phase_id], target_progress, delta * 10.0)

		var target_scale: float = ACTIVE_SCALE if phase_id == _current_phase else INACTIVE_SCALE
		_sector_scales[phase_id] = lerp(_sector_scales[phase_id], target_scale, delta * 10.0)

	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		var key_event := event as InputEventKey
		# 1 键 → 高通, 2 键 → 全频, 3 键 → 低通
		match key_event.keycode:
			KEY_1:
				_request_switch(ResonanceSlicingManager.Phase.OVERTONE)
			KEY_2:
				_request_switch(ResonanceSlicingManager.Phase.FUNDAMENTAL)
			KEY_3:
				_request_switch(ResonanceSlicingManager.Phase.SUB_BASS)

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var center := size / 2.0
	var font := ThemeDB.fallback_font

	# 绘制三个扇区
	for phase_id in [
		ResonanceSlicingManager.Phase.OVERTONE,
		ResonanceSlicingManager.Phase.FUNDAMENTAL,
		ResonanceSlicingManager.Phase.SUB_BASS,
	]:
		_draw_sector(center, phase_id)

	# 绘制光弧扫过效果
	if _arc_sweep_active:
		_draw_arc_sweep(center)

	# 绘制中心点
	draw_circle(center, 4.0, Color(0.08, 0.06, 0.15, 0.9))
	draw_arc(center, 4.0, 0, TAU, 16, Color(0.4, 0.3, 0.6, 0.6), 1.0)

	# 绘制快捷键提示（小字）
	var hint_color := Color(0.42, 0.4, 0.54, 0.5)
	draw_string(font, center + Vector2(-6, RING_RADIUS + 16), "1/2/3",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 7, hint_color)

## 绘制单个扇区
func _draw_sector(center: Vector2, phase_id: int) -> void:
	var font := ThemeDB.fallback_font
	var angle_center: float = SECTOR_ANGLES[phase_id]
	var progress: float = _sector_progress[phase_id]
	var scale_val: float = _sector_scales[phase_id]
	var phase_color: Color = ResonanceSlicingManager.PHASE_COLORS[phase_id]
	var is_active: bool = (phase_id == _current_phase)

	# 扇区弧线
	var angle_start := angle_center - SECTOR_HALF_ANGLE
	var angle_end := angle_center + SECTOR_HALF_ANGLE
	var inner_r := SECTOR_INNER_R * scale_val
	var outer_r := SECTOR_OUTER_R * scale_val

	# 构建扇区多边形
	var segment_count := 16
	var points := PackedVector2Array()

	# 内弧
	for i in range(segment_count + 1):
		var t := float(i) / float(segment_count)
		var angle := angle_start + t * (angle_end - angle_start)
		points.append(center + Vector2.from_angle(angle) * inner_r)

	# 外弧（反向）
	for i in range(segment_count, -1, -1):
		var t := float(i) / float(segment_count)
		var angle := angle_start + t * (angle_end - angle_start)
		points.append(center + Vector2.from_angle(angle) * outer_r)

	# 填充颜色
	var fill_color := phase_color
	var brightness := lerp(0.15, 1.0, progress)
	fill_color = fill_color * brightness
	fill_color.a = lerp(0.15, 0.6, progress)

	# 节拍脉动（仅激活扇区）
	if is_active:
		fill_color = fill_color.lightened(_beat_pulse * 0.3)
		fill_color.a += _beat_pulse * 0.15

	draw_colored_polygon(points, fill_color)

	# 边框辉光
	var border_color := phase_color
	border_color.a = lerp(0.2, 0.8, progress)
	var border_width := lerp(0.5, 2.0, progress)

	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], border_color, border_width)
	draw_line(points[points.size() - 1], points[0], border_color, border_width)

	# 外部辉光（激活态）
	if progress > 0.5:
		var glow_alpha := (progress - 0.5) * 2.0 * 0.15
		var glow_color := phase_color
		glow_color.a = glow_alpha
		draw_arc(center, outer_r + 3.0, angle_start, angle_end, segment_count,
			glow_color, 3.0)

	# 图标
	var icon_pos := center + Vector2.from_angle(angle_center) * ((inner_r + outer_r) / 2.0)
	var icon_text: String = PHASE_ICONS[phase_id]
	var icon_color := Color.WHITE if is_active else phase_color
	icon_color.a = lerp(0.3, 1.0, progress)
	var icon_size := int(lerp(8.0, 14.0, progress))
	draw_string(font, icon_pos + Vector2(-icon_size * 0.3, icon_size * 0.3),
		icon_text, HORIZONTAL_ALIGNMENT_CENTER, -1, icon_size, icon_color)

	# 内部动画效果（激活态）
	if is_active and progress > 0.8:
		_draw_sector_animation(center, phase_id, angle_start, angle_end, inner_r, outer_r)

## 绘制扇区内部动画
func _draw_sector_animation(center: Vector2, phase_id: int,
		angle_start: float, angle_end: float,
		inner_r: float, outer_r: float) -> void:
	var phase_color: Color = ResonanceSlicingManager.PHASE_COLORS[phase_id]

	match phase_id:
		ResonanceSlicingManager.Phase.OVERTONE:
			# 线框闪烁效果
			var line_color := phase_color
			line_color.a = 0.2 + 0.15 * sin(_time * 15.0)
			var mid_r := (inner_r + outer_r) / 2.0
			for i in range(3):
				var r := inner_r + (outer_r - inner_r) * float(i + 1) / 4.0
				draw_arc(center, r, angle_start + 0.1, angle_end - 0.1, 8, line_color, 0.5)

		ResonanceSlicingManager.Phase.FUNDAMENTAL:
			# 正弦波流动
			var wave_color := phase_color
			wave_color.a = 0.25
			var mid_r := (inner_r + outer_r) / 2.0
			var prev_point := Vector2.ZERO
			for i in range(17):
				var t := float(i) / 16.0
				var angle := angle_start + t * (angle_end - angle_start)
				var wave_offset := sin(angle * 6.0 + _time * 3.0) * 3.0
				var point := center + Vector2.from_angle(angle) * (mid_r + wave_offset)
				if i > 0:
					draw_line(prev_point, point, wave_color, 1.0)
				prev_point = point

		ResonanceSlicingManager.Phase.SUB_BASS:
			# 液态涌动（脉动圆点）
			var blob_color := phase_color
			blob_color.a = 0.2
			var mid_r := (inner_r + outer_r) / 2.0
			for i in range(5):
				var t := float(i) / 5.0
				var angle := angle_start + t * (angle_end - angle_start) + 0.1
				var pulse_r := 2.0 + sin(_time * 1.5 + float(i) * 1.3) * 1.5
				var pos := center + Vector2.from_angle(angle) * mid_r
				draw_circle(pos, pulse_r, blob_color)

## 绘制光弧扫过动画
func _draw_arc_sweep(center: Vector2) -> void:
	var from_angle: float = SECTOR_ANGLES[_arc_sweep_from]
	var to_angle: float = SECTOR_ANGLES[_arc_sweep_to]

	# 计算最短弧路径
	var angle_diff := to_angle - from_angle
	if angle_diff > PI:
		angle_diff -= TAU
	elif angle_diff < -PI:
		angle_diff += TAU

	var current_angle := from_angle + angle_diff * _arc_sweep_progress
	var arc_r := (SECTOR_INNER_R + SECTOR_OUTER_R) / 2.0 * 1.1

	# 光弧颜色（从源相位色到目标相位色渐变）
	var from_color: Color = ResonanceSlicingManager.PHASE_COLORS[_arc_sweep_from]
	var to_color: Color = ResonanceSlicingManager.PHASE_COLORS[_arc_sweep_to]
	var arc_color := from_color.lerp(to_color, _arc_sweep_progress)
	arc_color.a = 1.0 - _arc_sweep_progress * 0.5

	# 绘制光弧头部
	var head_pos := center + Vector2.from_angle(current_angle) * arc_r
	draw_circle(head_pos, 3.0 * (1.0 - _arc_sweep_progress * 0.5), arc_color)

	# 绘制拖尾
	var trail_length := 8
	for i in range(trail_length):
		var trail_t := _arc_sweep_progress - float(i) / float(trail_length) * 0.3
		if trail_t < 0.0:
			continue
		var trail_angle := from_angle + angle_diff * trail_t
		var trail_pos := center + Vector2.from_angle(trail_angle) * arc_r
		var trail_color := arc_color
		trail_color.a *= 1.0 - float(i) / float(trail_length)
		draw_circle(trail_pos, 2.0 * (1.0 - float(i) / float(trail_length)), trail_color)

# ============================================================
# 信号回调
# ============================================================

func _on_phase_changed(new_phase: int) -> void:
	var old_phase := _current_phase
	_current_phase = new_phase
	_start_arc_sweep(old_phase, new_phase)

func _on_beat_energy_updated(energy: float) -> void:
	_beat_pulse = clamp(energy, 0.0, 1.0)

# ============================================================
# 内部方法
# ============================================================

func _request_switch(target: int) -> void:
	var rsm := _get_rsm()
	if rsm:
		rsm.switch_phase(target)
	phase_switch_requested.emit(target)

func _start_arc_sweep(from: int, to: int) -> void:
	_arc_sweep_active = true
	_arc_sweep_progress = 0.0
	_arc_sweep_from = from
	_arc_sweep_to = to

func _get_rsm() -> Node:
	return get_node_or_null("/root/ResonanceSlicingManager")

# ============================================================
# 公共接口
# ============================================================

## 获取当前相位
func get_current_phase() -> int:
	return _current_phase

## 强制刷新显示
func refresh() -> void:
	var rsm := _get_rsm()
	if rsm:
		_current_phase = rsm.current_phase
	queue_redraw()
