## timbre_wheel_ui.gd
## 音色切换快捷轮盘 UI
## 按住指定键（默认 Tab）弹出径向轮盘，鼠标方向选择音色系别。
## 松开按键后确认切换。
##
## 布局：
## - 中心：当前音色信息
## - 四个方向：弹拨(上)、拉弦(右)、吹奏(下)、打击(左)
## - 每个扇区显示音色名称、图标、ADSR 波形缩略图
## - 选中扇区高亮 + 音色预览音效
extends Control

# ============================================================
# 信号
# ============================================================
signal timbre_selected(timbre: MusicData.TimbreType)
signal wheel_opened()
signal wheel_closed()

# ============================================================
# 配置
# ============================================================
## 轮盘半径
const WHEEL_RADIUS: float = 120.0
## 内圈半径
const INNER_RADIUS: float = 35.0
## 扇区间距角度
const SECTOR_GAP: float = 0.08
## 打开/关闭动画时间
const ANIM_DURATION: float = 0.15
## 触发按键
const TRIGGER_KEY: Key = KEY_TAB

# ============================================================
# 音色扇区配置
# ============================================================
const TIMBRE_SECTORS: Array = [
	{
		"timbre": MusicData.TimbreType.PLUCKED,
		"name": "弹拨",
		"subtitle": "古筝 / 琵琶",
		"icon": "PLUCK",
		"color": Color(0.2, 0.8, 0.6),
		"angle_center": -PI / 2.0,  # 上
		"desc": "颗粒感爆发\n快速衰减",
		"summon": "伴奏声部",
	},
	{
		"timbre": MusicData.TimbreType.BOWED,
		"name": "拉弦",
		"subtitle": "二胡 / 大提琴",
		"icon": "BOW",
		"color": Color(0.8, 0.4, 0.2),
		"angle_center": 0.0,  # 右
		"desc": "持续共振\n连绵拉弓",
		"summon": "共鸣声部",
	},
	{
		"timbre": MusicData.TimbreType.WIND,
		"name": "吹奏",
		"subtitle": "笛子 / 长笛",
		"icon": "BLOW",
		"color": Color(0.3, 0.6, 1.0),
		"angle_center": PI / 2.0,  # 下
		"desc": "穿透气息\n管乐聚焦",
		"summon": "干扰声部",
	},
	{
		"timbre": MusicData.TimbreType.PERCUSSIVE,
		"name": "打击",
		"subtitle": "钢琴 / 贝斯",
		"icon": "STRIKE",
		"color": Color(1.0, 0.3, 0.3),
		"angle_center": PI,  # 左
		"desc": "节奏冲击\n重音打击",
		"summon": "节奏声部",
	},
]

# ============================================================
# 状态
# ============================================================
var _is_open: bool = false
var _open_progress: float = 0.0  # 0.0 = 关闭, 1.0 = 完全打开
var _selected_sector: int = -1
var _current_timbre: MusicData.TimbreType = MusicData.TimbreType.NONE
var _mouse_angle: float = 0.0
var _mouse_distance: float = 0.0
var _center: Vector2 = Vector2.ZERO

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	
	# 连接音色变更信号
	if SpellcraftSystem.has_signal("timbre_changed"):
		SpellcraftSystem.timbre_changed.connect(_on_timbre_changed)
	
	_current_timbre = SpellcraftSystem.get_current_timbre()

func _process(delta: float) -> void:
	if _is_open:
		_open_progress = min(1.0, _open_progress + delta / ANIM_DURATION)
	else:
		_open_progress = max(0.0, _open_progress - delta / ANIM_DURATION)
		if _open_progress <= 0.0 and visible:
			visible = false
	
	if visible:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == TRIGGER_KEY:
			if key_event.pressed and not key_event.is_echo():
				_open_wheel()
			elif not key_event.pressed:
				_close_wheel()
	
	if _is_open and event is InputEventMouseMotion:
		_update_selection(event.position)

# ============================================================
# 轮盘开关
# ============================================================

func _open_wheel() -> void:
	_is_open = true
	visible = true
	_center = get_viewport_rect().size / 2.0
	
	# 暂停游戏时间（可选：减速而非完全暂停）
	Engine.time_scale = 0.2
	
	wheel_opened.emit()

func _close_wheel() -> void:
	_is_open = false
	
	# 恢复游戏时间
	Engine.time_scale = 1.0
	
	# 确认选择
	if _selected_sector >= 0 and _selected_sector < TIMBRE_SECTORS.size():
		var sector: Dictionary = TIMBRE_SECTORS[_selected_sector]
		var timbre: MusicData.TimbreType = sector["timbre"]
		if timbre != _current_timbre:
			SpellcraftSystem.set_timbre(timbre)
			timbre_selected.emit(timbre)
	
	wheel_closed.emit()

# ============================================================
# 选择更新
# ============================================================

func _update_selection(mouse_pos: Vector2) -> void:
	var to_mouse := mouse_pos - _center
	_mouse_distance = to_mouse.length()
	_mouse_angle = to_mouse.angle()
	
	if _mouse_distance < INNER_RADIUS:
		_selected_sector = -1
		return
	
	# 确定选中扇区
	_selected_sector = -1
	var min_angle_diff := INF
	for i in range(TIMBRE_SECTORS.size()):
		var sector_angle: float = TIMBRE_SECTORS[i]["angle_center"]
		var diff := _angle_diff(_mouse_angle, sector_angle)
		if diff < PI / 4.0 + SECTOR_GAP and diff < min_angle_diff:
			min_angle_diff = diff
			_selected_sector = i

func _angle_diff(a: float, b: float) -> float:
	var diff := fmod(a - b + PI, TAU) - PI
	return abs(diff)

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if _open_progress <= 0.0:
		return
	
	var font := ThemeDB.fallback_font
	var scale := _open_progress
	var alpha := _open_progress
	
	# 半透明背景遮罩
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.4 * alpha))
	
	# ========== 绘制扇区 ==========
	for i in range(TIMBRE_SECTORS.size()):
		var sector: Dictionary = TIMBRE_SECTORS[i]
		var is_selected := (i == _selected_sector)
		var is_current = (sector["timbre"] == _current_timbre)
		var sector_color: Color = sector["color"]
		var angle_center: float = sector["angle_center"]
		
		# 扇区参数
		var sector_half_angle := PI / 4.0 - SECTOR_GAP
		var angle_start := angle_center - sector_half_angle
		var angle_end := angle_center + sector_half_angle
		var outer_r := WHEEL_RADIUS * scale
		var inner_r := INNER_RADIUS * scale
		
		# 选中时扩大
		if is_selected:
			outer_r *= 1.15
		
		# 绘制扇区
		var segment_count := 16
		var points := PackedVector2Array()
		
		# 内弧
		for j in range(segment_count + 1):
			var t := float(j) / float(segment_count)
			var angle := angle_start + t * (angle_end - angle_start)
			points.append(_center + Vector2.from_angle(angle) * inner_r)
		
		# 外弧（反向）
		for j in range(segment_count, -1, -1):
			var t := float(j) / float(segment_count)
			var angle := angle_start + t * (angle_end - angle_start)
			points.append(_center + Vector2.from_angle(angle) * outer_r)
		
		# 扇区颜色
		var fill_color := sector_color
		fill_color.a = 0.3 * alpha
		if is_selected:
			fill_color.a = 0.6 * alpha
		if is_current:
			fill_color.a = max(fill_color.a, 0.4 * alpha)
		
		draw_colored_polygon(points, fill_color)
		
		# 扇区边框
		var border_color := sector_color
		border_color.a = 0.5 * alpha
		if is_selected:
			border_color.a = 0.9 * alpha
			border_color = border_color.lightened(0.3)
		
		# 绘制边框线
		for j in range(points.size() - 1):
			draw_line(points[j], points[j + 1], border_color, 1.0 if not is_selected else 2.0)
		draw_line(points[points.size() - 1], points[0], border_color, 1.0 if not is_selected else 2.0)
		
		# 当前音色标记
		if is_current:
			var mark_pos := _center + Vector2.from_angle(angle_center) * (inner_r + 8)
			_draw_diamond(mark_pos, 4.0, Color.WHITE)
		
		# ========== 扇区文字 ==========
		var text_r := (inner_r + outer_r) / 2.0
		var text_pos := _center + Vector2.from_angle(angle_center) * text_r
		
		# 音色名称
		var name_color := Color.WHITE
		name_color.a = alpha
		if is_selected:
			name_color = sector_color.lightened(0.5)
		draw_string(font, text_pos + Vector2(-12, -8), sector["name"], HORIZONTAL_ALIGNMENT_CENTER, -1, 14, name_color)
		
		# 副标题
		var sub_color := Color(0.7, 0.7, 0.8)
		sub_color.a = 0.7 * alpha
		draw_string(font, text_pos + Vector2(-20, 6), sector["subtitle"], HORIZONTAL_ALIGNMENT_CENTER, -1, 8, sub_color)
		
		# 召唤类型
		var summon_color := sector_color
		summon_color.a = 0.6 * alpha
		draw_string(font, text_pos + Vector2(-16, 18), sector["summon"], HORIZONTAL_ALIGNMENT_CENTER, -1, 8, summon_color)
		
		# ADSR 波形缩略图
		if is_selected:
			_draw_adsr_preview(text_pos + Vector2(-15, 26), sector["timbre"], sector_color, alpha)
	
	# ========== 中心圆 ==========
	var center_points := PackedVector2Array()
	var center_r := INNER_RADIUS * scale
	for i in range(24):
		var angle := (TAU / 24) * i
		center_points.append(_center + Vector2.from_angle(angle) * center_r)
	draw_colored_polygon(center_points, Color(0.05, 0.05, 0.1, 0.9 * alpha))
	
	# 中心边框
	for i in range(center_points.size()):
		var next := (i + 1) % center_points.size()
		draw_line(center_points[i], center_points[next], Color(0.3, 0.3, 0.4, 0.6 * alpha), 1.0)
	
	# 当前音色名称
	var current_name := "无"
	for sector in TIMBRE_SECTORS:
		if sector["timbre"] == _current_timbre:
			current_name = sector["name"]
			break
	draw_string(font, _center + Vector2(-8, 5), current_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.8, 0.8, 0.9, alpha))
	
	# ========== 选中扇区详情面板 ==========
	if _selected_sector >= 0 and _selected_sector < TIMBRE_SECTORS.size():
		var sector: Dictionary = TIMBRE_SECTORS[_selected_sector]
		var detail_pos := _center + Vector2(0, WHEEL_RADIUS * scale + 30)
		
		# 背景
		var detail_rect := Rect2(detail_pos + Vector2(-80, -5), Vector2(160, 50))
		draw_rect(detail_rect, Color(0.0, 0.0, 0.0, 0.7 * alpha))
		draw_rect(detail_rect, Color(sector["color"].r, sector["color"].g, sector["color"].b, 0.4 * alpha), false, 1.0)
		
		# 描述
		var desc_lines: PackedStringArray = sector["desc"].split("\n")
		for j in range(desc_lines.size()):
			draw_string(font, detail_pos + Vector2(-70, 10 + j * 14), desc_lines[j], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.8, 0.9, alpha))
	
	# ========== 快捷键提示 ==========
	var hint_pos := _center + Vector2(0, -WHEEL_RADIUS * scale - 25)
	draw_string(font, hint_pos + Vector2(-40, 0), "松开 Tab 确认", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.5, 0.5, 0.6, 0.6 * alpha))

# ============================================================
# ADSR 波形预览
# ============================================================

func _draw_adsr_preview(pos: Vector2, timbre: MusicData.TimbreType, color: Color, alpha: float) -> void:
	var adsr: Dictionary = MusicData.TIMBRE_ADSR.get(timbre, {})
	if adsr.is_empty():
		return
	
	var attack: float = adsr.get("attack_time", 0.01)
	var decay: float = adsr.get("decay_time", 0.1)
	var sustain: float = adsr.get("sustain_level", 0.6)
	var release: float = adsr.get("release_time", 0.05)
	
	# 归一化时间
	var total_time := attack + decay + 0.3 + release  # 0.3秒 sustain 展示
	var w := 30.0
	var h := 15.0
	
	var draw_color := color
	draw_color.a = 0.6 * alpha
	
	# 绘制 ADSR 曲线
	var points: Array[Vector2] = []
	points.append(pos)  # 起点
	
	# Attack
	var attack_x := (attack / total_time) * w
	points.append(pos + Vector2(attack_x, -h))
	
	# Decay
	var decay_x := attack_x + (decay / total_time) * w
	points.append(pos + Vector2(decay_x, -h * sustain))
	
	# Sustain
	var sustain_x := decay_x + (0.3 / total_time) * w
	points.append(pos + Vector2(sustain_x, -h * sustain))
	
	# Release
	points.append(pos + Vector2(w, 0))
	
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], draw_color, 1.5)

# ============================================================
# 辅助绘制
# ============================================================

func _draw_diamond(pos: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array([
		pos + Vector2(0, -size),
		pos + Vector2(size, 0),
		pos + Vector2(0, size),
		pos + Vector2(-size, 0),
	])
	draw_colored_polygon(points, color)

# ============================================================
# 信号回调
# ============================================================

func _on_timbre_changed(timbre: MusicData.TimbreType) -> void:
	_current_timbre = timbre
