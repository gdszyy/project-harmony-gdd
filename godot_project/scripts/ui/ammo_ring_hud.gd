## ammo_ring_hud.gd — 弹药环形 HUD
## 围绕玩家的环形弧段，每个弧段代表一种音色/武器
## 弧段填充长度表示剩余弹药量，颜色对应音色特征色
## 使用 _draw() 实现自定义绘制
extends Node2D

# ============================================================
# 配置
# ============================================================
## 环形半径
@export var ring_radius: float = 80.0
## 弧段宽度
@export var arc_width: float = 8.0
## 弧段间隙 (弧度)
@export var arc_gap: float = 0.08
## 自动施法刻度数量
const AUTO_CAST_TICKS: int = 16
## 手动施法槽数量
const MANUAL_CAST_SLOTS: int = 3

# 音色颜色映射
const NOTE_COLORS: Dictionary = {
	"C": Color(0.0, 1.0, 0.831),    # 谐振青
	"D": Color(0.2, 0.5, 1.0),      # 蓝色
	"E": Color(0.4, 1.0, 0.698),    # 治愈绿
	"F": Color(0.533, 0.0, 1.0),    # 深渊紫
	"G": Color(1.0, 0.843, 0.0),    # 圣光金
	"A": Color(1.0, 0.533, 0.0),    # 数据橙
	"B": Color(1.0, 0.3, 0.6),      # 粉色
}

const COLOR_INACTIVE := Color(0.2, 0.2, 0.3, 0.4)
const COLOR_DEPLETED := Color(0.3, 0.3, 0.3, 0.5)
const COLOR_CURSOR   := Color(0.918, 0.902, 1.0, 1.0)

# ============================================================
# 状态
# ============================================================
## 弹药弧段数据: [{note: String, fill: float, color: Color, active: bool}]
var _ammo_arcs: Array[Dictionary] = []
## 序列器刻度数据
var _tick_states: Array[bool] = []
## 当前节拍位置
var _current_beat: int = 0
## 节拍进度
var _beat_progress: float = 0.0
## 时间
var _time: float = 0.0
## 激活的弧段索引
var _active_arc_index: int = -1

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 初始化刻度状态
	_tick_states.resize(AUTO_CAST_TICKS)
	_tick_states.fill(false)

	# 连接信号
	if GameManager.has_signal("beat_tick"):
		GameManager.beat_tick.connect(_on_beat_tick)
	if SpellcraftSystem.has_signal("sequencer_updated"):
		SpellcraftSystem.sequencer_updated.connect(_on_sequencer_updated)
	if SpellcraftSystem.has_signal("weapon_switched"):
		SpellcraftSystem.weapon_switched.connect(_on_weapon_switched)

func _process(delta: float) -> void:
	_time += delta
	_beat_progress = GameManager.get_beat_progress() if GameManager.has_method("get_beat_progress") else 0.0
	_update_ammo_data()
	queue_redraw()

# ============================================================
# 数据更新
# ============================================================

func _update_ammo_data() -> void:
	# 从 WeaponManager 或 SpellcraftSystem 获取弹药数据
	if SpellcraftSystem.has_method("get_ammo_ring_data"):
		_ammo_arcs = SpellcraftSystem.get_ammo_ring_data()
	elif _ammo_arcs.is_empty():
		# 默认数据
		_ammo_arcs = [
			{"note": "C", "fill": 1.0, "color": NOTE_COLORS["C"], "active": true},
			{"note": "E", "fill": 0.7, "color": NOTE_COLORS["E"], "active": false},
			{"note": "G", "fill": 0.4, "color": NOTE_COLORS["G"], "active": false},
		]

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	# === 1. 内环：序列器刻度 ===
	_draw_sequencer_ring()

	# === 2. 外环：弹药弧段 ===
	_draw_ammo_ring()

	# === 3. 节拍光标 ===
	_draw_beat_cursor()

## 绘制序列器刻度环
func _draw_sequencer_ring() -> void:
	var inner_radius := ring_radius - arc_width - 4.0

	for i in range(AUTO_CAST_TICKS):
		var angle := (TAU / AUTO_CAST_TICKS) * i - PI / 2.0
		var is_active := _tick_states[i] if i < _tick_states.size() else false
		var is_current := (i == _current_beat)

		# 刻度标记
		var tick_len := 6.0 if is_active else 3.0
		var p_outer := Vector2.from_angle(angle) * inner_radius
		var p_inner := Vector2.from_angle(angle) * (inner_radius - tick_len)

		var tick_color := COLOR_CURSOR if is_current else (Color(0.0, 0.8, 1.0, 0.8) if is_active else Color(0.078, 0.063, 0.149, 0.5))
		var tick_width := 3.0 if is_current else (2.0 if is_active else 1.0)

		draw_line(p_inner, p_outer, tick_color, tick_width, true)

		# 施法点高亮
		if is_active and is_current:
			draw_circle(p_outer, 4.0, Color(0.0, 1.0, 0.831, 0.8))

## 绘制弹药弧段
func _draw_ammo_ring() -> void:
	if _ammo_arcs.is_empty():
		return

	var arc_count := _ammo_arcs.size()
	var total_gap := arc_gap * arc_count
	var available_arc := TAU - total_gap
	var arc_length := available_arc / arc_count

	for i in range(arc_count):
		var arc_data: Dictionary = _ammo_arcs[i]
		var start_angle := -PI / 2.0 + (arc_length + arc_gap) * i
		var fill: float = arc_data.get("fill", 1.0)
		var color: Color = arc_data.get("color", Color.WHITE)
		var is_active: bool = arc_data.get("active", false)
		var is_depleted := fill < 0.01

		# 绘制背景弧段
		_draw_arc_segment(start_angle, start_angle + arc_length, ring_radius, arc_width, Color(color, 0.15))

		# 绘制填充弧段
		var fill_end := start_angle + arc_length * fill
		var fill_color := color
		if is_depleted:
			fill_color = COLOR_DEPLETED
		elif is_active:
			var flash := sin(_time * 8.0) * 0.2 + 0.8
			fill_color = Color(color.r * flash, color.g * flash, color.b * flash, 0.9)
		else:
			fill_color = Color(color, 0.7)

		if fill > 0.01:
			_draw_arc_segment(start_angle, fill_end, ring_radius, arc_width, fill_color)

		# 耗尽红色闪烁
		if is_depleted:
			var red_flash := sin(_time * 6.0) * 0.3 + 0.3
			_draw_arc_segment(start_angle, start_angle + arc_length, ring_radius, arc_width, Color(1.0, 0.1, 0.1, red_flash))

		# 激活高亮边框
		if is_active:
			_draw_arc_outline(start_angle, start_angle + arc_length, ring_radius, arc_width, Color(color, 0.6), 1.5)

## 绘制弧段
func _draw_arc_segment(start: float, end: float, radius: float, width: float, color: Color) -> void:
	var segments := 24
	var inner_r := radius - width / 2.0
	var outer_r := radius + width / 2.0
	var angle_range := end - start

	for i in range(segments):
		var t1 := float(i) / segments
		var t2 := float(i + 1) / segments
		var a1 := start + angle_range * t1
		var a2 := start + angle_range * t2

		var p1_inner := Vector2.from_angle(a1) * inner_r
		var p1_outer := Vector2.from_angle(a1) * outer_r
		var p2_inner := Vector2.from_angle(a2) * inner_r
		var p2_outer := Vector2.from_angle(a2) * outer_r

		var points := PackedVector2Array([p1_inner, p1_outer, p2_outer, p2_inner])
		var colors := PackedColorArray([color, color, color, color])
		draw_polygon(points, colors)

## 绘制弧段轮廓
func _draw_arc_outline(start: float, end: float, radius: float, width: float, color: Color, line_width: float) -> void:
	var segments := 24
	var inner_r := radius - width / 2.0
	var outer_r := radius + width / 2.0
	var angle_range := end - start

	var inner_points := PackedVector2Array()
	var outer_points := PackedVector2Array()

	for i in range(segments + 1):
		var t := float(i) / segments
		var a := start + angle_range * t
		inner_points.append(Vector2.from_angle(a) * inner_r)
		outer_points.append(Vector2.from_angle(a) * outer_r)

	if inner_points.size() > 1:
		draw_polyline(inner_points, color, line_width, true)
		draw_polyline(outer_points, color, line_width, true)

## 绘制节拍光标
func _draw_beat_cursor() -> void:
	var inner_radius := ring_radius - arc_width - 4.0

	# 当前位置角度
	var current_angle := (TAU / AUTO_CAST_TICKS) * _current_beat - PI / 2.0
	var next_angle := (TAU / AUTO_CAST_TICKS) * ((_current_beat + 1) % AUTO_CAST_TICKS) - PI / 2.0

	# 平滑插值
	var interp_angle := lerp_angle(current_angle, next_angle, _beat_progress)
	var cursor_pos := Vector2.from_angle(interp_angle) * inner_radius

	# 光点
	var pulse := 1.0 + sin(_beat_progress * PI) * 0.3
	draw_circle(cursor_pos, 4.0 * pulse, COLOR_CURSOR)

	# 辉光
	draw_circle(cursor_pos, 8.0 * pulse, Color(COLOR_CURSOR, 0.2))

# ============================================================
# 信号回调
# ============================================================

func _on_beat_tick(beat_index: int) -> void:
	_current_beat = beat_index % AUTO_CAST_TICKS

func _on_sequencer_updated(sequence: Array) -> void:
	for i in range(min(sequence.size(), AUTO_CAST_TICKS)):
		_tick_states[i] = sequence[i] != null and sequence[i] != ""

func _on_weapon_switched(weapon_index: int) -> void:
	_active_arc_index = weapon_index
	for i in range(_ammo_arcs.size()):
		_ammo_arcs[i]["active"] = (i == weapon_index)
