## timbre_wheel_ui.gd
## 音色武器切换快捷轮盘 UI (v2.0 — Issue #38)
## 按住指定键（默认 Q）弹出径向轮盘，鼠标方向选择章节音色武器。
## 松开按键后确认切换。
##
## 布局 (v2.0)：
## - 中心：当前音色武器信息 + 电子乐变体切换按钮
## - 七个方向：按章节排列的音色武器扇区
## - 每个扇区显示：音色名称、章节标签、ADSR 波形缩略图
## - 已解锁的扇区高亮可选，未解锁的灰显
## - 当前章节专属音色武器有特殊标记（无额外疲劳）
## - 选中扇区显示详情面板（核心机制 + 词条协同）
extends Control

# ============================================================
# 信号
# ============================================================
signal timbre_selected(timbre: int)  # MusicData.ChapterTimbre
signal electronic_variant_toggled(is_electronic: bool)
signal wheel_opened()
signal wheel_closed()

# ============================================================
# 配置
# ============================================================
## 轮盘半径
const WHEEL_RADIUS: float = 150.0
## 内圈半径
const INNER_RADIUS: float = 40.0
## 扇区间距角度
const SECTOR_GAP: float = 0.06
## 打开/关闭动画时间
const ANIM_DURATION: float = 0.15
## 触发按键
const TRIGGER_KEY: Key = KEY_Q
## 扇区数量（7 个章节）
const SECTOR_COUNT: int = 7

# ============================================================
# 音色武器扇区配置
# 按章节顺序排列，角度均匀分布在 360° 上
# ============================================================
const TIMBRE_SECTORS: Array = [
	{
		"timbre": MusicData.ChapterTimbre.LYRE,
		"chapter": "Ch1",
		"name": "里拉琴",
		"name_en": "Lyre",
		"subtitle": "古希腊 · 泛音共鸣",
		"icon": "LYRE",
		"color": Color(0.9, 0.8, 0.3),  # 金色
		"desc": "纯净的泛音共鸣\n基于数学比例的伤害加成",
		"mechanic": "harmonic_resonance",
		"electronic_name": "Sine Wave Synth",
	},
	{
		"timbre": MusicData.ChapterTimbre.ORGAN,
		"chapter": "Ch2",
		"name": "管风琴",
		"name_en": "Organ",
		"subtitle": "中世纪 · 和声层叠",
		"icon": "ORGAN",
		"color": Color(0.6, 0.3, 0.7),  # 紫色
		"desc": "持续的和声层叠\n多声部叠加攻击",
		"mechanic": "harmonic_stacking",
		"electronic_name": "Drone Synth",
	},
	{
		"timbre": MusicData.ChapterTimbre.HARPSICHORD,
		"chapter": "Ch3",
		"name": "羽管键琴",
		"name_en": "Harpsichord",
		"subtitle": "巴洛克 · 对位交织",
		"icon": "HARPSICHORD",
		"color": Color(0.8, 0.6, 0.2),  # 琥珀色
		"desc": "精密的对位攻击\n多弹道交织",
		"mechanic": "counterpoint_weave",
		"electronic_name": "Arpeggiator Synth",
	},
	{
		"timbre": MusicData.ChapterTimbre.FORTEPIANO,
		"chapter": "Ch4",
		"name": "钢琴",
		"name_en": "Fortepiano",
		"subtitle": "古典主义 · 力度动态",
		"icon": "PIANO",
		"color": Color(0.9, 0.9, 0.95),  # 象牙白
		"desc": "力度动态控制\n强弱拍伤害差异化",
		"mechanic": "velocity_dynamics",
		"electronic_name": "Velocity Pad",
	},
	{
		"timbre": MusicData.ChapterTimbre.TUTTI,
		"chapter": "Ch5",
		"name": "管弦全奏",
		"name_en": "Tutti",
		"subtitle": "浪漫主义 · 情感爆发",
		"icon": "TUTTI",
		"color": Color(0.9, 0.2, 0.2),  # 炽红
		"desc": "情感爆发式攻击\n渐强渐弱的伤害曲线",
		"mechanic": "emotional_crescendo",
		"electronic_name": "Supersaw Synth",
	},
	{
		"timbre": MusicData.ChapterTimbre.SAXOPHONE,
		"chapter": "Ch6",
		"name": "萨克斯",
		"name_en": "Saxophone",
		"subtitle": "爵士 · 摇摆攻击",
		"icon": "SAX",
		"color": Color(0.2, 0.5, 0.9),  # 蓝紫色
		"desc": "摇摆节奏攻击\n反拍强化",
		"mechanic": "swing_attack",
		"electronic_name": "FM Synth",
	},
	{
		"timbre": MusicData.ChapterTimbre.SYNTHESIZER,
		"chapter": "Ch7",
		"name": "合成主脑",
		"name_en": "Synthesizer",
		"subtitle": "电子 · 波形变换",
		"icon": "SYNTH",
		"color": Color(0.0, 0.9, 0.7),  # 青色
		"desc": "波形变换攻击\n频率操控",
		"mechanic": "waveform_morph",
		"electronic_name": "Glitch Engine",
	},
]

# ============================================================
# 状态
# ============================================================
var _is_open: bool = false
var _open_progress: float = 0.0  # 0.0 = 关闭, 1.0 = 完全打开
var _selected_sector: int = -1
var _current_timbre: int = MusicData.ChapterTimbre.NONE  # ChapterTimbre enum
var _is_electronic_variant: bool = false
var _mouse_angle: float = 0.0
var _mouse_distance: float = 0.0
var _center: Vector2 = Vector2.ZERO

## 已解锁的音色武器列表（进入新章节时自动解锁）
var _unlocked_timbres: Array[int] = []

## 当前章节的专属音色（使用时无额外疲劳）
var _current_chapter_timbre: int = MusicData.ChapterTimbre.NONE

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	
	# 连接 GameManager 信号
	if GameManager.has_signal("chapter_timbre_changed"):
		GameManager.chapter_timbre_changed.connect(_on_chapter_timbre_changed)
	
	# 初始化已解锁音色
	_unlocked_timbres = GameManager.available_timbres.duplicate()
	_current_timbre = GameManager.active_chapter_timbre
	_is_electronic_variant = GameManager.is_electronic_variant

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
		# E 键切换电子乐变体
		elif key_event.keycode == KEY_E and key_event.pressed and not key_event.is_echo():
			if _is_open:
				_toggle_electronic_variant()
	
	if _is_open and event is InputEventMouseMotion:
		_update_selection(event.position)

# ============================================================
# 轮盘开关
# ============================================================

func _open_wheel() -> void:
	_is_open = true
	visible = true
	_center = get_viewport_rect().size / 2.0
	
	# 刷新已解锁音色
	_unlocked_timbres = GameManager.available_timbres.duplicate()
	_current_timbre = GameManager.active_chapter_timbre
	_is_electronic_variant = GameManager.is_electronic_variant
	
	# 获取当前章节专属音色
	var chapter_config := ChapterData.get_chapter_timbre(ChapterManager.get_current_chapter())
	_current_chapter_timbre = chapter_config.get("timbre", MusicData.ChapterTimbre.NONE)
	
	# 减速游戏时间
	Engine.time_scale = 0.2
	
	wheel_opened.emit()

func _close_wheel() -> void:
	_is_open = false
	
	# 恢复游戏时间
	Engine.time_scale = 1.0
	
	# 确认选择
	if _selected_sector >= 0 and _selected_sector < TIMBRE_SECTORS.size():
		var sector: Dictionary = TIMBRE_SECTORS[_selected_sector]
		var timbre: int = sector["timbre"]
		# 只能切换到已解锁的音色
		if timbre in _unlocked_timbres and timbre != _current_timbre:
			GameManager.switch_timbre(timbre)
			_current_timbre = timbre
			timbre_selected.emit(timbre)
	
	wheel_closed.emit()

## 切换电子乐变体
func _toggle_electronic_variant() -> void:
	_is_electronic_variant = not _is_electronic_variant
	GameManager.is_electronic_variant = _is_electronic_variant
	electronic_variant_toggled.emit(_is_electronic_variant)

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
	
	# 确定选中扇区（7 个均匀分布）
	_selected_sector = -1
	var sector_angle_span := TAU / float(SECTOR_COUNT)
	var min_angle_diff := INF
	
	for i in range(TIMBRE_SECTORS.size()):
		var sector_angle := _get_sector_center_angle(i)
		var diff := _angle_diff(_mouse_angle, sector_angle)
		if diff < sector_angle_span / 2.0 and diff < min_angle_diff:
			min_angle_diff = diff
			_selected_sector = i

func _get_sector_center_angle(index: int) -> float:
	# 从正上方开始，顺时针排列
	return -PI / 2.0 + (TAU / float(SECTOR_COUNT)) * index

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
	var sector_angle_span := TAU / float(SECTOR_COUNT)
	
	# 半透明背景遮罩
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.4 * alpha))
	
	# ========== 绘制扇区 ==========
	for i in range(TIMBRE_SECTORS.size()):
		var sector: Dictionary = TIMBRE_SECTORS[i]
		var is_selected := (i == _selected_sector)
		var is_current := (sector["timbre"] == _current_timbre)
		var is_chapter_timbre := (sector["timbre"] == _current_chapter_timbre)
		var is_unlocked := (sector["timbre"] in _unlocked_timbres)
		var sector_color: Color = sector["color"]
		var angle_center := _get_sector_center_angle(i)
		
		# 扇区角度范围
		var sector_half_angle := sector_angle_span / 2.0 - SECTOR_GAP
		var angle_start := angle_center - sector_half_angle
		var angle_end := angle_center + sector_half_angle
		var outer_r := WHEEL_RADIUS * scale
		var inner_r := INNER_RADIUS * scale
		
		# 选中时扩大
		if is_selected and is_unlocked:
			outer_r *= 1.12
		
		# 绘制扇区多边形
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
		
		# 扇区填充颜色
		var fill_color := sector_color
		if not is_unlocked:
			fill_color = Color(0.2, 0.2, 0.25)  # 未解锁灰显
			fill_color.a = 0.2 * alpha
		elif is_selected:
			fill_color.a = 0.6 * alpha
		elif is_current:
			fill_color.a = 0.45 * alpha
		else:
			fill_color.a = 0.25 * alpha
		
		draw_colored_polygon(points, fill_color)
		
		# 扇区边框
		var border_color := sector_color if is_unlocked else Color(0.3, 0.3, 0.35)
		border_color.a = 0.4 * alpha
		if is_selected and is_unlocked:
			border_color.a = 0.9 * alpha
			border_color = border_color.lightened(0.3)
		if is_chapter_timbre and is_unlocked:
			border_color = Color(1.0, 0.85, 0.3)  # 当前章节专属金色边框
			border_color.a = 0.7 * alpha
		
		var line_width := 1.0
		if is_selected and is_unlocked:
			line_width = 2.0
		if is_chapter_timbre and is_unlocked:
			line_width = 2.5
		
		for j in range(points.size() - 1):
			draw_line(points[j], points[j + 1], border_color, line_width)
		draw_line(points[points.size() - 1], points[0], border_color, line_width)
		
		# 当前音色标记（菱形）
		if is_current:
			var mark_pos := _center + Vector2.from_angle(angle_center) * (inner_r + 8)
			_draw_diamond(mark_pos, 4.0, Color.WHITE)
		
		# 当前章节专属标记（星号）
		if is_chapter_timbre and is_unlocked and not is_current:
			var star_pos := _center + Vector2.from_angle(angle_center) * (outer_r - 8)
			draw_string(font, star_pos + Vector2(-4, 4), "★", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.85, 0.3, alpha))
		
		# ========== 扇区文字 ==========
		var text_r := (inner_r + outer_r) / 2.0
		var text_pos := _center + Vector2.from_angle(angle_center) * text_r
		
		# 章节标签
		var chapter_color := sector_color if is_unlocked else Color(0.4, 0.4, 0.45)
		chapter_color.a = 0.6 * alpha
		draw_string(font, text_pos + Vector2(-12, -16), sector["chapter"], HORIZONTAL_ALIGNMENT_CENTER, -1, 8, chapter_color)
		
		# 音色名称
		var name_color := Color.WHITE if is_unlocked else Color(0.5, 0.5, 0.55)
		name_color.a = alpha
		if is_selected and is_unlocked:
			name_color = sector_color.lightened(0.5)
		var display_name: String = sector["name"]
		if _is_electronic_variant and is_current:
			display_name = sector["electronic_name"]
		draw_string(font, text_pos + Vector2(-16, -2), display_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, name_color)
		
		# 副标题
		var sub_color := Color(0.7, 0.7, 0.8) if is_unlocked else Color(0.4, 0.4, 0.45)
		sub_color.a = 0.6 * alpha
		draw_string(font, text_pos + Vector2(-24, 12), sector["subtitle"], HORIZONTAL_ALIGNMENT_CENTER, -1, 7, sub_color)
		
		# 未解锁标记
		if not is_unlocked:
			draw_string(font, text_pos + Vector2(-8, 26), "🔒", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.5, 0.5, 0.55, alpha))
		
		# ADSR 波形缩略图（选中时显示）
		if is_selected and is_unlocked:
			_draw_adsr_preview(text_pos + Vector2(-15, 22), sector["timbre"], sector_color, alpha)
	
	# ========== 中心圆 ==========
	var center_points := PackedVector2Array()
	var center_r := INNER_RADIUS * scale
	for i in range(24):
		var angle := (TAU / 24) * i
		center_points.append(_center + Vector2.from_angle(angle) * center_r)
	draw_colored_polygon(center_points, Color(0.05, 0.05, 0.1, 0.9 * alpha))
	
	# 中心边框
	for i in range(center_points.size()):
		var next_idx := (i + 1) % center_points.size()
		draw_line(center_points[i], center_points[next_idx], Color(0.3, 0.3, 0.4, 0.6 * alpha), 1.0)
	
	# 当前音色武器名称
	var current_name := "无"
	for sector in TIMBRE_SECTORS:
		if sector["timbre"] == _current_timbre:
			if _is_electronic_variant:
				current_name = sector["electronic_name"]
			else:
				current_name = sector["name"]
			break
	draw_string(font, _center + Vector2(-16, 0), current_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.8, 0.8, 0.9, alpha))
	
	# 电子乐变体状态
	if _is_electronic_variant:
		draw_string(font, _center + Vector2(-12, 12), "[电子]", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.0, 0.9, 0.7, 0.8 * alpha))
	
	# ========== 选中扇区详情面板 ==========
	if _selected_sector >= 0 and _selected_sector < TIMBRE_SECTORS.size():
		var sector: Dictionary = TIMBRE_SECTORS[_selected_sector]
		var is_unlocked := (sector["timbre"] in _unlocked_timbres)
		var is_chapter_timbre := (sector["timbre"] == _current_chapter_timbre)
		var detail_pos := _center + Vector2(0, WHEEL_RADIUS * scale + 35)
		
		# 背景
		var detail_rect := Rect2(detail_pos + Vector2(-100, -5), Vector2(200, 65))
		draw_rect(detail_rect, Color(0.0, 0.0, 0.0, 0.75 * alpha))
		draw_rect(detail_rect, Color(sector["color"].r, sector["color"].g, sector["color"].b, 0.4 * alpha), false, 1.0)
		
		if is_unlocked:
			# 描述
			var desc_lines: PackedStringArray = sector["desc"].split("\n")
			for j in range(desc_lines.size()):
				draw_string(font, detail_pos + Vector2(-90, 10 + j * 14), desc_lines[j], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.8, 0.9, alpha))
			
			# 章节专属标记
			if is_chapter_timbre:
				draw_string(font, detail_pos + Vector2(-90, 38), "★ 当前章节专属 · 无额外疲劳", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.85, 0.3, alpha))
			else:
				var fatigue_text := "跨章节使用 · 疲劳 +%.2f/次" % MusicData.CROSS_CHAPTER_TIMBRE_FATIGUE
				draw_string(font, detail_pos + Vector2(-90, 38), fatigue_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.5, 0.3, alpha))
			
			# 电子乐变体提示
			draw_string(font, detail_pos + Vector2(-90, 52), "电子变体: " + sector["electronic_name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.0, 0.8, 0.6, 0.7 * alpha))
		else:
			draw_string(font, detail_pos + Vector2(-90, 15), "未解锁", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.55, alpha))
			draw_string(font, detail_pos + Vector2(-90, 30), "进入 " + sector["chapter"] + " 后自动获得", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.5, 0.55, 0.7 * alpha))
	
	# ========== 快捷键提示 ==========
	var hint_pos := _center + Vector2(0, -WHEEL_RADIUS * scale - 30)
	draw_string(font, hint_pos + Vector2(-60, 0), "松开 Q 确认 | E 切换电子变体", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.5, 0.5, 0.6, 0.6 * alpha))

# ============================================================
# ADSR 波形预览
# ============================================================

func _draw_adsr_preview(pos: Vector2, timbre: int, color: Color, alpha: float) -> void:
	var adsr: Dictionary = MusicData.CHAPTER_TIMBRE_ADSR.get(timbre, {})
	if adsr.is_empty():
		return
	
	var attack: float = adsr.get("attack", 0.01)
	var decay: float = adsr.get("decay", 0.1)
	var sustain: float = adsr.get("sustain", 0.6)
	var release: float = adsr.get("release", 0.05)
	
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
	
	for j in range(points.size() - 1):
		draw_line(points[j], points[j + 1], draw_color, 1.5)

# ============================================================
# 辅助绘制
# ============================================================

func _draw_diamond(pos: Vector2, diamond_size: float, color: Color) -> void:
	var points := PackedVector2Array([
		pos + Vector2(0, -diamond_size),
		pos + Vector2(diamond_size, 0),
		pos + Vector2(0, diamond_size),
		pos + Vector2(-diamond_size, 0),
	])
	draw_colored_polygon(points, color)

# ============================================================
# 信号回调
# ============================================================

func _on_chapter_timbre_changed(new_timbre: int) -> void:
	_current_timbre = new_timbre
	# 刷新已解锁列表
	_unlocked_timbres = GameManager.available_timbres.duplicate()

# ============================================================
# 公共接口
# ============================================================

## 获取当前选中的音色武器
func get_current_timbre() -> int:
	return _current_timbre

## 获取是否使用电子乐变体
func is_electronic_variant() -> bool:
	return _is_electronic_variant

## 构建音色武器列表（供外部 UI 使用）
func get_timbre_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sector in TIMBRE_SECTORS:
		var item := {
			"timbre": sector["timbre"],
			"name": sector["name"],
			"name_en": sector["name_en"],
			"chapter": sector["chapter"],
			"is_unlocked": sector["timbre"] in _unlocked_timbres,
			"is_current": sector["timbre"] == _current_timbre,
			"is_chapter_timbre": sector["timbre"] == _current_chapter_timbre,
			"electronic_name": sector["electronic_name"],
		}
		result.append(item)
	return result
