## timbre_wheel_ui.gd
## 音色武器切换快捷轮盘 UI (v3.0 — 频谱相位系统整合)
## 重构为四象限布局（弹拨/打击/拉弦/吹奏），新增相位增益联动提示
## 按住指定键（默认 Tab）弹出径向轮盘，鼠标方向选择音色系别/武器。
## 松开按键后确认切换。
##
## 布局 (v3.0)：
## - 四象限：弹拨系(上)、打击系(右)、拉弦系(下)、吹奏系(左)
## - 中心：合成主脑(Ch7) 独立选项 + 电子乐变体切换
## - 相位增益联动：当前相位的增益系别象限高亮 + 增益徽章
## - 每个象限内包含该系别的所有已解锁章节武器
##
## 关联文档：Docs/UI_Design_Module6_ResonanceSlicing.md §6
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

## 轮盘布局与动画 — @export 支持编辑器实时调整
@export_group("Wheel Layout")
@export var wheel_radius: float = 150.0        ## 轮盘半径
@export var inner_radius: float = 40.0         ## 内圈半径
@export var quadrant_count: int = 4            ## 象限数量
@export var quadrant_gap: float = 0.06         ## 象限间隙角度

@export_group("Animation")
@export var anim_duration: float = 0.15        ## 打开/关闭动画时间

## 触发按键
const TRIGGER_KEY: Key = KEY_TAB

# ============================================================
# 四大音色系别象限配置
# ============================================================

const FAMILY_QUADRANTS: Array = [
	{
		"key": "plucked",
		"name": "弹拨系",
		"name_en": "Plucked",
		"angle_center": -PI / 2.0,  # 上方 (12点)
		"color": UIColors.ACCENT_2,
		"gain_phase": 1,  # ResonanceSlicingManager.Phase.OVERTONE
		"gain_text": "+50% 瞬态伤害",
		"timbres": [
			{
				"timbre": MusicData.ChapterTimbre.LYRE,
				"chapter": "Ch1", "name": "里拉琴", "name_en": "Lyre",
				"subtitle": "古希腊 · 泛音共鸣",
				"electronic_name": "Sine Wave Synth",
			},
			{
				"timbre": MusicData.ChapterTimbre.HARPSICHORD,
				"chapter": "Ch3", "name": "羽管键琴", "name_en": "Harpsichord",
				"subtitle": "巴洛克 · 对位交织",
				"electronic_name": "Arpeggiator Synth",
			},
		],
	},
	{
		"key": "percussion",
		"name": "打击系",
		"name_en": "Percussion",
		"angle_center": 0.0,  # 右方 (3点)
		"color": UIColors.WARNING,
		"gain_phase": 2,  # ResonanceSlicingManager.Phase.SUB_BASS
		"gain_text": "x2 击退/眩晕",
		"timbres": [
			{
				"timbre": MusicData.ChapterTimbre.FORTEPIANO,
				"chapter": "Ch4", "name": "钢琴", "name_en": "Fortepiano",
				"subtitle": "古典主义 · 力度动态",
				"electronic_name": "Velocity Pad",
			},
		],
	},
	{
		"key": "bowed",
		"name": "拉弦系",
		"name_en": "Bowed",
		"angle_center": PI / 2.0,  # 下方 (6点)
		"color": UIColors.ACCENT,
		"gain_phase": 0,  # ResonanceSlicingManager.Phase.FUNDAMENTAL
		"gain_text": "+50% 持续时间",
		"timbres": [
			{
				"timbre": MusicData.ChapterTimbre.TUTTI,
				"chapter": "Ch5", "name": "管弦全奏", "name_en": "Tutti",
				"subtitle": "浪漫主义 · 情感爆发",
				"electronic_name": "Supersaw Synth",
			},
		],
	},
	{
		"key": "wind",
		"name": "吹奏系",
		"name_en": "Wind",
		"angle_center": PI,  # 左方 (9点)
		"color": UIColors.SUCCESS,
		"gain_phase": -1,  # 特殊：切换瞬间增益
		"gain_text": "首击聚焦",
		"timbres": [
			{
				"timbre": MusicData.ChapterTimbre.ORGAN,
				"chapter": "Ch2", "name": "管风琴", "name_en": "Organ",
				"subtitle": "中世纪 · 和声层叠",
				"electronic_name": "Drone Synth",
			},
			{
				"timbre": MusicData.ChapterTimbre.SAXOPHONE,
				"chapter": "Ch6", "name": "萨克斯", "name_en": "Saxophone",
				"subtitle": "爵士 · 摇摆攻击",
				"electronic_name": "FM Synth",
			},
		],
	},
]

## 中心特殊武器（合成主脑）
const CENTER_TIMBRE: Dictionary = {
	"timbre": MusicData.ChapterTimbre.SYNTHESIZER,
	"chapter": "Ch7", "name": "合成主脑", "name_en": "Synthesizer",
	"subtitle": "电子 · 波形变换",
	"color": UIColors.TIMBRE_CENTER,
	"electronic_name": "Glitch Engine",
}

# ============================================================
# 状态
# ============================================================

var _is_open: bool = false
var _open_progress: float = 0.0
var _selected_quadrant: int = -1  # -1=无, 0-3=象限, 4=中心
var _selected_timbre_in_quadrant: int = 0  # 象限内选中的武器索引
var _current_timbre: int = MusicData.ChapterTimbre.NONE
var _is_electronic_variant: bool = false
var _mouse_angle: float = 0.0
var _mouse_distance: float = 0.0
var _center: Vector2 = Vector2.ZERO

## 已解锁的音色武器列表
var _unlocked_timbres: Array[int] = []
## 当前章节的专属音色
var _current_chapter_timbre: int = MusicData.ChapterTimbre.NONE
## 当前相位（用于增益高亮）
var _current_phase: int = 0  # ResonanceSlicingManager.Phase.FUNDAMENTAL
## 吹奏系闪烁计时器（切换瞬间增益）
var _wind_flash_timer: float = 0.0

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

	# 连接 ResonanceSlicingManager 信号
	var rsm := get_node_or_null("/root/ResonanceSlicingManager")
	if rsm:
		rsm.phase_changed.connect(_on_phase_changed)

	# 初始化
	_unlocked_timbres = GameManager.available_timbres.duplicate()
	_current_timbre = GameManager.active_chapter_timbre
	_is_electronic_variant = GameManager.is_electronic_variant

func _process(delta: float) -> void:
	if _is_open:
		_open_progress = min(1.0, _open_progress + delta / anim_duration)
	else:
		_open_progress = max(0.0, _open_progress - delta / anim_duration)
		if _open_progress <= 0.0 and visible:
			visible = false

	# 吹奏系闪烁衰减
	if _wind_flash_timer > 0.0:
		_wind_flash_timer -= delta

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

	_unlocked_timbres = GameManager.available_timbres.duplicate()
	_current_timbre = GameManager.active_chapter_timbre
	_is_electronic_variant = GameManager.is_electronic_variant

	var chapter_config := ChapterData.get_chapter_timbre(ChapterManager.get_current_chapter())
	_current_chapter_timbre = chapter_config.get("timbre", MusicData.ChapterTimbre.NONE)

	# 获取当前相位
	var rsm := get_node_or_null("/root/ResonanceSlicingManager")
	if rsm:
		_current_phase = rsm.current_phase

	Engine.time_scale = 0.3  # 子弹时间
	wheel_opened.emit()

func _close_wheel() -> void:
	_is_open = false
	Engine.time_scale = 1.0

	# 确认选择
	if _selected_quadrant >= 0 and _selected_quadrant < quadrant_count:
		var quadrant: Dictionary = FAMILY_QUADRANTS[_selected_quadrant]
		var timbres: Array = quadrant["timbres"]
		if _selected_timbre_in_quadrant >= 0 and _selected_timbre_in_quadrant < timbres.size():
			var timbre_data: Dictionary = timbres[_selected_timbre_in_quadrant]
			var timbre: int = timbre_data["timbre"]
			if timbre in _unlocked_timbres and timbre != _current_timbre:
				GameManager.switch_timbre(timbre)
				_current_timbre = timbre
				timbre_selected.emit(timbre)
	elif _selected_quadrant == 4:
		# 中心：合成主脑
		var timbre: int = CENTER_TIMBRE["timbre"]
		if timbre in _unlocked_timbres and timbre != _current_timbre:
			GameManager.switch_timbre(timbre)
			_current_timbre = timbre
			timbre_selected.emit(timbre)

	wheel_closed.emit()

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

	if _mouse_distance < inner_radius:
		_selected_quadrant = 4  # 中心
		return

	# 确定选中象限
	_selected_quadrant = -1
	var quadrant_half_angle := PI / 2.0 - quadrant_gap

	for i in range(quadrant_count):
		var q: Dictionary = FAMILY_QUADRANTS[i]
		var q_center: float = q["angle_center"]
		var diff := _angle_diff(_mouse_angle, q_center)
		if diff < quadrant_half_angle:
			_selected_quadrant = i
			# 确定象限内选中的武器
			var timbres: Array = q["timbres"]
			if timbres.size() > 1:
				# 多武器象限：根据径向距离选择
				var radial_t: float = clamp((_mouse_distance - inner_radius) / (wheel_radius - inner_radius), 0.0, 1.0)
				_selected_timbre_in_quadrant = int(radial_t * float(timbres.size()))
				_selected_timbre_in_quadrant = min(_selected_timbre_in_quadrant, timbres.size() - 1)
			else:
				_selected_timbre_in_quadrant = 0
			break

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
	var scale_val := _open_progress
	var alpha := _open_progress
	var quadrant_half_angle := PI / 2.0 - quadrant_gap

	# 半透明背景遮罩
	draw_rect(Rect2(Vector2.ZERO, size), UIColors.with_alpha(Color.BLACK, 0.45 * alpha))

	# ========== 绘制四个象限 ==========
	for i in range(quadrant_count):
		var q: Dictionary = FAMILY_QUADRANTS[i]
		var is_selected := (i == _selected_quadrant)
		var q_color: Color = q["color"]
		var q_center: float = q["angle_center"]
		var angle_start := q_center - quadrant_half_angle
		var angle_end := q_center + quadrant_half_angle
		var outer_r := wheel_radius * scale_val
		var inner_r := inner_radius * scale_val

		if is_selected:
			outer_r *= 1.08

		# 检查是否为当前相位的增益象限
		var is_gain_quadrant: bool = (int(q["gain_phase"]) == _current_phase)
		var is_wind_flashing: bool = (str(q["key"]) == "wind" and _wind_flash_timer > 0.0)

		# 绘制象限多边形
		var segment_count := 20
		var points := PackedVector2Array()

		for j in range(segment_count + 1):
			var t := float(j) / float(segment_count)
			var angle := angle_start + t * (angle_end - angle_start)
			points.append(_center + Vector2.from_angle(angle) * inner_r)

		for j in range(segment_count, -1, -1):
			var t := float(j) / float(segment_count)
			var angle := angle_start + t * (angle_end - angle_start)
			points.append(_center + Vector2.from_angle(angle) * outer_r)

		# 填充颜色
		var fill_color := q_color
		if is_selected:
			fill_color.a = 0.5 * alpha
		elif is_gain_quadrant:
			fill_color.a = 0.35 * alpha
		else:
			fill_color.a = 0.15 * alpha

		draw_colored_polygon(points, fill_color)

		# 边框
		var border_color := q_color
		var border_width := 1.0
		if is_gain_quadrant:
			border_color = border_color.lightened(0.5)
			border_width = 2.5
		elif is_selected:
			border_color = border_color.lightened(0.3)
			border_width = 2.0
		border_color.a = 0.6 * alpha

		for j in range(points.size() - 1):
			draw_line(points[j], points[j + 1], border_color, border_width)
		draw_line(points[points.size() - 1], points[0], border_color, border_width)

		# 增益辉光（当前相位增益象限）
		if is_gain_quadrant:
			var glow_color := q_color
			glow_color.a = 0.15 * alpha
			draw_arc(_center, outer_r + 4.0, angle_start, angle_end,
				segment_count, glow_color, 4.0)

		# 吹奏系闪烁
		if is_wind_flashing:
			var flash_alpha := _wind_flash_timer * 0.5
			var flash_color := q_color
			flash_color.a = flash_alpha * alpha
			draw_colored_polygon(points, flash_color)

		# ========== 象限文字 ==========
		var text_r := (inner_r + outer_r) / 2.0
		var text_pos := _center + Vector2.from_angle(q_center) * text_r

		# 系别名称
		var name_color := q_color if is_selected or is_gain_quadrant else UIColors.TEXT_SECONDARY
		name_color.a = alpha
		draw_string(font, text_pos + Vector2(-16, -14), q["name"],
			HORIZONTAL_ALIGNMENT_CENTER, -1, 11, name_color)
		draw_string(font, text_pos + Vector2(-20, -2), q["name_en"],
			HORIZONTAL_ALIGNMENT_CENTER, -1, 8, UIColors.with_alpha(UIColors.TEXT_DIM, 0.6 * alpha))

		# 武器列表
		var timbres: Array = q["timbres"]
		for t_idx in range(timbres.size()):
			var t_data: Dictionary = timbres[t_idx]
			var t_timbre: int = t_data["timbre"]
			var is_unlocked: bool = t_timbre in _unlocked_timbres
			var is_current: bool = t_timbre == _current_timbre
			var is_t_selected: bool = is_selected and t_idx == _selected_timbre_in_quadrant
			var y_offset := 12.0 + float(t_idx) * 14.0

			var t_name: String = t_data["name"]
			if _is_electronic_variant and is_current:
				t_name = t_data["electronic_name"]

			var t_color := Color.WHITE if is_unlocked else UIColors.TEXT_LOCKED
			if is_t_selected and is_unlocked:
				t_color = q_color.lightened(0.4)
			if is_current:
				t_name = "> " + t_name
			t_color.a = alpha

			draw_string(font, text_pos + Vector2(-20, y_offset), t_name,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 9, t_color)

			if not is_unlocked:
				draw_string(font, text_pos + Vector2(24, y_offset), "🔒",
					HORIZONTAL_ALIGNMENT_CENTER, -1, 8, UIColors.with_alpha(UIColors.TEXT_DIM, alpha))

		# 增益徽章
		if is_gain_quadrant:
			var badge_pos := _center + Vector2.from_angle(q_center) * (outer_r + 18.0)
			_draw_gain_badge(badge_pos, q["gain_text"], q_color, alpha)

	# ========== 中心圆（合成主脑） ==========
	var center_r := inner_radius * scale_val
	var center_selected := (_selected_quadrant == 4)
	var center_points := PackedVector2Array()
	for i in range(24):
		var angle := (TAU / 24.0) * float(i)
		center_points.append(_center + Vector2.from_angle(angle) * center_r)

	var center_fill := UIColors.with_alpha(UIColors.PRIMARY_BG, 0.9 * alpha)
	if center_selected:
		center_fill = CENTER_TIMBRE["color"]
		center_fill.a = 0.3 * alpha
	draw_colored_polygon(center_points, center_fill)

	# 中心边框
	var center_border: Color = CENTER_TIMBRE["color"] if center_selected else UIColors.TEXT_LOCKED
	center_border.a = 0.6 * alpha
	for i in range(center_points.size()):
		var next_idx := (i + 1) % center_points.size()
		draw_line(center_points[i], center_points[next_idx], center_border, 1.0)

	# 中心文字
	var center_name: Color = CENTER_TIMBRE["name"]
	var center_name_color: Color = CENTER_TIMBRE["color"] if center_selected else UIColors.TEXT_SECONDARY
	center_name_color.a = alpha
	draw_string(font, _center + Vector2(-16, -4), center_name,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 9, center_name_color)
	draw_string(font, _center + Vector2(-12, 8), "Ch7",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 7, UIColors.with_alpha(UIColors.TEXT_DIM, 0.5 * alpha))

	# 电子乐变体状态
	if _is_electronic_variant:
		draw_string(font, _center + Vector2(-10, 18), "[电子]",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 7, UIColors.with_alpha(UIColors.ACCENT_2, 0.8 * alpha))

	# ========== 选中象限详情面板 ==========
	if _selected_quadrant >= 0 and _selected_quadrant < quadrant_count:
		_draw_detail_panel(font, alpha)

	# ========== 快捷键提示 ==========
	var hint_pos := _center + Vector2(0, -wheel_radius * scale_val - 25)
	draw_string(font, hint_pos + Vector2(-70, 0),
		"松开 Tab 确认 | E 切换电子变体",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 9, UIColors.with_alpha(UIColors.TEXT_DIM, 0.6 * alpha))

## 绘制增益徽章
func _draw_gain_badge(pos: Vector2, text: String, color: Color, alpha: float) -> void:
	var font := ThemeDB.fallback_font
	var badge_size := Vector2(90, 18)
	var badge_rect := Rect2(pos - badge_size / 2.0, badge_size)

	# 背景
	var bg_color := UIColors.with_alpha(UIColors.PANEL_BG, 0.85 * alpha)
	draw_rect(badge_rect, bg_color)

	# 边框
	var border_color := color
	border_color.a = 0.8 * alpha
	draw_rect(badge_rect, border_color, false, 1.5)

	# 文字
	var text_color := color
	text_color.a = alpha
	draw_string(font, pos + Vector2(-40, 5), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 8, text_color)

## 绘制选中象限的详情面板
func _draw_detail_panel(font: Font, alpha: float) -> void:
	var q: Dictionary = FAMILY_QUADRANTS[_selected_quadrant]
	var timbres: Array = q["timbres"]
	if _selected_timbre_in_quadrant >= timbres.size():
		return

	var t_data: Dictionary = timbres[_selected_timbre_in_quadrant]
	var is_unlocked: bool = t_data["timbre"] in _unlocked_timbres
	var is_chapter_timbre: bool = t_data["timbre"] == _current_chapter_timbre

	var detail_pos := _center + Vector2(0, wheel_radius * _open_progress + 35)
	var detail_rect := Rect2(detail_pos + Vector2(-110, -5), Vector2(220, 55))

	# 背景
	draw_rect(detail_rect, UIColors.with_alpha(Color.BLACK, 0.75 * alpha))
	var q_color: Color = q["color"]
	draw_rect(detail_rect, UIColors.with_alpha(q_color, 0.4 * alpha), false, 1.0)

	if is_unlocked:
		# 武器名称
		draw_string(font, detail_pos + Vector2(-100, 8), t_data["name"] + " — " + t_data["subtitle"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIColors.with_alpha(UIColors.TEXT_PRIMARY, alpha))

		# 章节专属标记
		if is_chapter_timbre:
			draw_string(font, detail_pos + Vector2(-100, 22),
				"★ 当前章节专属 · 无额外疲劳",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIColors.with_alpha(UIColors.GOLD, alpha))
		else:
			var fatigue_text := "跨章节使用 · 疲劳 +%.2f/次" % MusicData.CROSS_CHAPTER_TIMBRE_FATIGUE
			draw_string(font, detail_pos + Vector2(-100, 22), fatigue_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIColors.with_alpha(UIColors.WARNING, alpha))

		# 电子乐变体
		draw_string(font, detail_pos + Vector2(-100, 36),
			"电子变体: " + t_data["electronic_name"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIColors.with_alpha(UIColors.ACCENT_2, 0.7 * alpha))

		# 相位增益提示
		if q["gain_phase"] == _current_phase:
			draw_string(font, detail_pos + Vector2(-100, 48),
				"♦ " + q["gain_text"] + " (当前相位增益)",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIColors.with_alpha(UIColors.GOLD, alpha))
	else:
		draw_string(font, detail_pos + Vector2(-100, 12), "未解锁",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIColors.with_alpha(UIColors.TEXT_DIM, alpha))
		draw_string(font, detail_pos + Vector2(-100, 28),
			"进入 " + t_data["chapter"] + " 后自动获得",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIColors.with_alpha(UIColors.TEXT_DIM, 0.7 * alpha))

# ============================================================
# 信号回调
# ============================================================

func _on_chapter_timbre_changed(new_timbre: int) -> void:
	_current_timbre = new_timbre
	_unlocked_timbres = GameManager.available_timbres.duplicate()

func _on_phase_changed(new_phase: int) -> void:
	var old_phase := _current_phase
	_current_phase = new_phase

	# 吹奏系切换瞬间增益闪烁
	if old_phase != new_phase:
		_wind_flash_timer = 1.0

# ============================================================
# 公共接口
# ============================================================

## 获取当前选中的音色武器
func get_current_timbre() -> int:
	return _current_timbre

## 获取是否使用电子乐变体
func is_electronic_variant() -> bool:
	return _is_electronic_variant

## 更新相位增益高亮（供外部调用）
func update_gain_highlights() -> void:
	var rsm := get_node_or_null("/root/ResonanceSlicingManager")
	if rsm:
		_current_phase = rsm.current_phase
	queue_redraw()

## 构建音色武器列表（供外部 UI 使用）
func get_timbre_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for q in FAMILY_QUADRANTS:
		for t_data in q["timbres"]:
			var item := {
				"timbre": t_data["timbre"],
				"name": t_data["name"],
				"name_en": t_data["name_en"],
				"chapter": t_data["chapter"],
				"family": q["key"],
				"is_unlocked": t_data["timbre"] in _unlocked_timbres,
				"is_current": t_data["timbre"] == _current_timbre,
				"is_chapter_timbre": t_data["timbre"] == _current_chapter_timbre,
				"electronic_name": t_data["electronic_name"],
			}
			result.append(item)
	# 合成主脑
	result.append({
		"timbre": CENTER_TIMBRE["timbre"],
		"name": CENTER_TIMBRE["name"],
		"name_en": CENTER_TIMBRE["name_en"],
		"chapter": CENTER_TIMBRE["chapter"],
		"family": "synthesizer",
		"is_unlocked": CENTER_TIMBRE["timbre"] in _unlocked_timbres,
		"is_current": CENTER_TIMBRE["timbre"] == _current_timbre,
		"is_chapter_timbre": CENTER_TIMBRE["timbre"] == _current_chapter_timbre,
		"electronic_name": CENTER_TIMBRE["electronic_name"],
	})
	return result
