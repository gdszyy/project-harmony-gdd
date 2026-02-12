## phase_energy_bar.gd
## 相位能量条 UI — 包裹三相位指示器的流动光粒圆环
## 使用自定义 _draw() + Shader 方案实现精确控制
## 关联文档：Docs/UI_Design_Module6_ResonanceSlicing.md §4
extends Control

# ============================================================
# 常量
# ============================================================

## 圆环外半径
const RING_OUTER_R: float = 42.0
## 圆环内半径
const RING_INNER_R: float = 36.0
## 圆环线宽
const RING_WIDTH: float = 4.0
## 最大粒子数
const MAX_PARTICLES: int = 200
## 数值标签显示阈值（低于30%时显示精确数值）
const NUMERIC_THRESHOLD: float = 0.3

## 能量颜色分级
const COLOR_FULL := Color("#EAE6FF")      # 晶体白 (100%-50%)
const COLOR_WARNING := Color("#FFD700")    # 黄色 (50%-10%)
const COLOR_CRITICAL := Color("#FF4D4D")   # 危险红 (10%-0%)

## 刻度位置（25%, 50%, 75%, 100%）
const TICK_POSITIONS: Array = [0.25, 0.5, 0.75, 1.0]

# ============================================================
# 状态
# ============================================================

var _energy_ratio: float = 1.0
var _display_ratio: float = 1.0
var _time: float = 0.0
var _beat_pulse: float = 0.0

## 蒸发粒子（能量消耗时的散逸效果）
var _evaporation_particles: Array[Dictionary] = []

## 汇入粒子（能量恢复时的汇入效果）
var _inflow_particles: Array[Dictionary] = []

## 流动光粒
var _flow_particles: Array[Dictionary] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	custom_minimum_size = Vector2(RING_OUTER_R * 2.5, RING_OUTER_R * 2.5)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 连接信号
	var rsm := get_node_or_null("/root/ResonanceSlicingManager")
	if rsm:
		rsm.phase_energy_changed.connect(_on_energy_changed)

	var gmm := get_node_or_null("/root/GlobalMusicManager")
	if gmm and gmm.has_signal("beat_energy_updated"):
		gmm.beat_energy_updated.connect(_on_beat_energy_updated)

	# 初始化流动光粒
	_init_flow_particles()

func _process(delta: float) -> void:
	_time += delta
	_beat_pulse = max(0.0, _beat_pulse - delta * 3.0)

	# 平滑插值
	var old_display := _display_ratio
	_display_ratio = lerp(_display_ratio, _energy_ratio, delta * 8.0)

	# 检测能量变化方向，生成效果粒子
	var energy_delta := _display_ratio - old_display
	if energy_delta < -0.005:
		_spawn_evaporation_particle()
	elif energy_delta > 0.005:
		_spawn_inflow_particle()

	# 更新效果粒子
	_update_effect_particles(delta)

	# 更新流动光粒
	_update_flow_particles(delta)

	queue_redraw()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var center := size / 2.0
	var font := ThemeDB.fallback_font

	# 1. 背景圆环（暗色）
	_draw_ring_bg(center)

	# 2. 能量填充弧
	_draw_energy_arc(center)

	# 3. 流动光粒
	_draw_flow_particles(center)

	# 4. 刻度标记
	_draw_tick_marks(center)

	# 5. 蒸发/汇入粒子
	_draw_effect_particles(center)

	# 6. 数值标签（低能量时）
	if _display_ratio < NUMERIC_THRESHOLD:
		var value_text := "%d" % int(_display_ratio * 100.0)
		var text_color := COLOR_CRITICAL if _display_ratio < 0.1 else COLOR_WARNING
		# 闪烁效果
		if _display_ratio < 0.1:
			text_color.a = 0.5 + 0.5 * sin(_time * 10.0)
		draw_string(font, center + Vector2(-6, RING_OUTER_R + 14),
			value_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, text_color)

## 绘制背景圆环
func _draw_ring_bg(center: Vector2) -> void:
	var bg_color := Color(0.08, 0.06, 0.15, 0.4)
	draw_arc(center, (RING_INNER_R + RING_OUTER_R) / 2.0,
		0, TAU, 48, bg_color, RING_WIDTH)

## 绘制能量填充弧
func _draw_energy_arc(center: Vector2) -> void:
	if _display_ratio <= 0.001:
		return

	var fill_angle := _display_ratio * TAU
	# 从底部（PI/2）开始顺时针
	var start_angle := PI / 2.0
	var end_angle := start_angle + fill_angle

	var energy_color := _get_energy_color()

	# 节拍脉冲
	var pulse_brightness := _beat_pulse * 0.3
	energy_color = energy_color.lightened(pulse_brightness)

	# 绘制填充弧（多段以实现渐变效果）
	var segments := 32
	var prev_angle := start_angle
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		if t > _display_ratio:
			t = _display_ratio
		var angle := start_angle + t * TAU
		var seg_color := energy_color
		# 尾部渐暗
		if t > _display_ratio - 0.05:
			var fade := (_display_ratio - t) / 0.05
			seg_color.a *= clamp(fade, 0.3, 1.0)

		draw_arc(center, (RING_INNER_R + RING_OUTER_R) / 2.0,
			prev_angle, angle, 4, seg_color, RING_WIDTH)
		prev_angle = angle

		if t >= _display_ratio:
			break

## 绘制流动光粒
func _draw_flow_particles(center: Vector2) -> void:
	for p in _flow_particles:
		if not p.get("visible", true):
			continue
		var angle: float = p["angle"]
		# 只在填充范围内显示
		var mapped := fmod(angle - PI / 2.0 + TAU, TAU) / TAU
		if mapped > _display_ratio:
			continue

		var r: float = p["radius"]
		var pos := center + Vector2.from_angle(angle) * r
		var p_color: Color = p["color"]
		p_color.a *= p.get("alpha", 1.0)

		# 闪烁（低能量时）
		if _display_ratio < 0.1:
			p_color.a *= 0.5 + 0.5 * sin(_time * 10.0 + p["phase_offset"])

		draw_circle(pos, p["size"], p_color)

## 绘制刻度标记
func _draw_tick_marks(center: Vector2) -> void:
	for tick in TICK_POSITIONS:
		var angle := PI / 2.0 + tick * TAU
		var inner_pos := center + Vector2.from_angle(angle) * RING_INNER_R
		var outer_pos := center + Vector2.from_angle(angle) * RING_OUTER_R
		var tick_color := Color(0.4, 0.38, 0.5, 0.25)
		draw_line(inner_pos, outer_pos, tick_color, 1.0)

## 绘制蒸发/汇入效果粒子
func _draw_effect_particles(center: Vector2) -> void:
	for p in _evaporation_particles:
		var pos := center + Vector2.from_angle(p["angle"]) * p["radius"]
		var p_color: Color = p["color"]
		p_color.a = p["life"]
		draw_circle(pos, p["size"] * p["life"], p_color)

	for p in _inflow_particles:
		var pos := center + Vector2.from_angle(p["angle"]) * p["radius"]
		var p_color: Color = p["color"]
		p_color.a = p["life"]
		draw_circle(pos, p["size"] * p["life"], p_color)

# ============================================================
# 粒子系统
# ============================================================

func _init_flow_particles() -> void:
	_flow_particles.clear()
	var particle_count := MAX_PARTICLES
	for i in range(particle_count):
		var angle := randf() * TAU
		var r := RING_INNER_R + randf() * (RING_OUTER_R - RING_INNER_R)
		_flow_particles.append({
			"angle": angle,
			"radius": r,
			"speed": randf_range(0.3, 1.5),
			"size": randf_range(0.5, 2.0),
			"color": COLOR_FULL,
			"alpha": randf_range(0.3, 0.8),
			"phase_offset": randf() * TAU,
			"visible": true,
		})

func _update_flow_particles(delta: float) -> void:
	var speed_mult := lerp(0.1, 1.5, _display_ratio)
	var visible_count := int(float(MAX_PARTICLES) * _display_ratio)
	var energy_color := _get_energy_color()

	for i in range(_flow_particles.size()):
		var p: Dictionary = _flow_particles[i]
		p["visible"] = (i < visible_count)
		p["angle"] += p["speed"] * speed_mult * delta
		if p["angle"] > TAU:
			p["angle"] -= TAU
		p["color"] = energy_color
		# 半径微弱波动
		var base_r := (RING_INNER_R + RING_OUTER_R) / 2.0
		p["radius"] = base_r + sin(_time * 2.0 + p["phase_offset"]) * RING_WIDTH * 0.3

func _spawn_evaporation_particle() -> void:
	if _evaporation_particles.size() > 20:
		return
	var fill_angle := _display_ratio * TAU + PI / 2.0
	_evaporation_particles.append({
		"angle": fill_angle + randf_range(-0.1, 0.1),
		"radius": RING_OUTER_R + randf_range(2.0, 8.0),
		"speed": randf_range(10.0, 25.0),
		"size": randf_range(1.0, 2.5),
		"color": _get_energy_color(),
		"life": 1.0,
	})

func _spawn_inflow_particle() -> void:
	if _inflow_particles.size() > 15:
		return
	# 从底部源点汇入
	_inflow_particles.append({
		"angle": PI / 2.0 + randf_range(-0.2, 0.2),
		"radius": RING_OUTER_R + randf_range(5.0, 15.0),
		"speed": -randf_range(15.0, 30.0),
		"size": randf_range(1.0, 2.0),
		"color": COLOR_FULL,
		"life": 1.0,
	})

func _update_effect_particles(delta: float) -> void:
	# 蒸发粒子：向外扩散并衰减
	var to_remove_evap: Array[int] = []
	for i in range(_evaporation_particles.size()):
		var p: Dictionary = _evaporation_particles[i]
		p["radius"] += p["speed"] * delta
		p["life"] -= delta * 2.0
		if p["life"] <= 0.0:
			to_remove_evap.append(i)
	for i in range(to_remove_evap.size() - 1, -1, -1):
		_evaporation_particles.remove_at(to_remove_evap[i])

	# 汇入粒子：向内收缩并衰减
	var to_remove_inflow: Array[int] = []
	for i in range(_inflow_particles.size()):
		var p: Dictionary = _inflow_particles[i]
		p["radius"] += p["speed"] * delta
		if p["radius"] <= (RING_INNER_R + RING_OUTER_R) / 2.0:
			to_remove_inflow.append(i)
			continue
		p["life"] -= delta * 1.5
		if p["life"] <= 0.0:
			to_remove_inflow.append(i)
	for i in range(to_remove_inflow.size() - 1, -1, -1):
		_inflow_particles.remove_at(to_remove_inflow[i])

# ============================================================
# 信号回调
# ============================================================

func _on_energy_changed(current: float, maximum: float) -> void:
	_energy_ratio = current / maximum if maximum > 0.0 else 0.0

func _on_beat_energy_updated(energy: float) -> void:
	_beat_pulse = clamp(energy, 0.0, 1.0)

# ============================================================
# 辅助方法
# ============================================================

func _get_energy_color() -> Color:
	if _display_ratio > 0.5:
		return COLOR_FULL
	elif _display_ratio > 0.3:
		var t := (_display_ratio - 0.3) / 0.2
		return COLOR_WARNING.lerp(COLOR_FULL, t)
	elif _display_ratio > 0.1:
		var t := (_display_ratio - 0.1) / 0.2
		return COLOR_CRITICAL.lerp(COLOR_WARNING, t)
	else:
		return COLOR_CRITICAL

# ============================================================
# 公共接口
# ============================================================

## 手动更新能量值
func update_energy(current: float, maximum: float) -> void:
	_on_energy_changed(current, maximum)

## 获取当前显示的能量比例
func get_display_ratio() -> float:
	return _display_ratio
