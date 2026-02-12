## mode_selection_screen.gd — 调式选择界面 v1.0
## "天体调音仪" — 调式风格选择与预览
##
## 设计文档: Docs/UI_Design_Module5_HallOfHarmony.md §3.C
## 圆形星座图布局，每个调式是一颗行星
## 已解锁调式可点击选择，选中调式高亮
## 显示调式音阶、被动效果、职业描述
extends Control

# ============================================================
# 信号
# ============================================================
signal mode_selected(mode_name: String)
signal back_pressed()
signal confirm_pressed()

# ============================================================
# 颜色方案
# ============================================================
const BG_COLOR := Color(0.03, 0.02, 0.06, 0.97)
const ACCENT := Color("#9D6FFF")
const GOLD := Color("#FFD700")
const CYAN := Color("#00E5FF")
const TEXT_COLOR := Color("#EAE6FF")
const DIM_TEXT := Color("#A098C8")
const SUCCESS := Color("#4DFF80")
const DANGER := Color("#FF4D4D")
const FRAGMENT_COLOR := Color(0.6, 0.4, 1.0)
const WARM_ORANGE := Color(1.0, 0.6, 0.2)

# ============================================================
# 调式数据（与 MetaProgressionManager.MODE_CONFIGS 对应）
# ============================================================
const MODE_DISPLAY := {
	"ionian": {
		"name": "伊奥尼亚",
		"title": "均衡者",
		"desc": "C大调，全套白键。没有特殊限制，适合新手。",
		"notes": "C D E F G A B",
		"passive": "无特殊被动",
		"color": Color(0.4, 0.6, 1.0),
		"orbit_radius": 0.0,  # 中心
		"angle_offset": 0.0,
	},
	"dorian": {
		"name": "多利亚",
		"title": "民谣诗人",
		"desc": "小调色彩，自带回响效果。投射物附带回音波。",
		"notes": "D E F G A B C",
		"passive": "投射物 +15% 回响范围",
		"color": Color(0.3, 0.8, 0.6),
		"orbit_radius": 160.0,
		"angle_offset": -0.5,
	},
	"pentatonic": {
		"name": "五声音阶",
		"title": "东方行者",
		"desc": "CDEGA 五音，减少选择但伤害更高。",
		"notes": "C D E G A",
		"passive": "法术伤害 +20%",
		"color": Color(1.0, 0.3, 0.3),
		"orbit_radius": 160.0,
		"angle_offset": 0.5,
	},
	"blues": {
		"name": "布鲁斯",
		"title": "爵士乐手",
		"desc": "不和谐音符不再造成伤害，转为暴击概率。",
		"notes": "C Eb F F# G Bb",
		"passive": "不和谐→暴击转化",
		"color": Color(0.8, 0.5, 1.0),
		"orbit_radius": 260.0,
		"angle_offset": 0.0,
	},
}

# ============================================================
# 内部状态
# ============================================================
var _meta: Node = null
var _time: float = 0.0
var _is_open: bool = false

var _selected_mode: String = "ionian"
var _hover_mode: String = ""

## 调式行星位置
var _mode_positions: Dictionary = {}  # mode_name → Vector2
var _mode_rects: Dictionary = {}      # mode_name → Rect2

## 背景星尘
var _stars: Array[Dictionary] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_meta = get_node_or_null("/root/MetaProgressionManager")
	_generate_stars(80)
	visible = false

func _process(delta: float) -> void:
	if not _is_open:
		return
	_time += delta
	queue_redraw()

# ============================================================
# 公共接口
# ============================================================

func open() -> void:
	_is_open = true
	visible = true
	if _meta:
		_selected_mode = _meta.get_selected_mode()
	_calculate_positions()
	queue_redraw()

func close() -> void:
	_is_open = false
	visible = false
	back_pressed.emit()

# ============================================================
# 位置计算
# ============================================================

func _calculate_positions() -> void:
	_mode_positions.clear()
	var vp := get_viewport_rect().size
	var center := Vector2(vp.x * 0.4, vp.y * 0.5)  # 偏左，右侧留给信息面板

	for mode_name in MODE_DISPLAY:
		var display: Dictionary = MODE_DISPLAY[mode_name]
		var orbit_r: float = display.get("orbit_radius", 0.0)
		var angle_offset: float = display.get("angle_offset", 0.0)

		if orbit_r == 0.0:
			_mode_positions[mode_name] = center
		else:
			var angle := angle_offset + _time * 0.02  # 缓慢公转
			_mode_positions[mode_name] = center + Vector2(cos(angle), sin(angle)) * orbit_r

# ============================================================
# 背景
# ============================================================

func _generate_stars(count: int) -> void:
	_stars.clear()
	for i in range(count):
		_stars.append({
			"pos": Vector2(randf() * 1920.0, randf() * 1080.0),
			"size": randf_range(0.5, 1.8),
			"phase": randf() * TAU,
			"brightness": randf_range(0.2, 0.6),
		})

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if not _is_open:
		return

	var vp := get_viewport_rect().size
	var center := Vector2(vp.x * 0.4, vp.y * 0.5)
	var font := ThemeDB.fallback_font

	# 背景
	draw_rect(Rect2(Vector2.ZERO, vp), BG_COLOR)

	# 星尘
	for star in _stars:
		var flicker := 0.5 + 0.5 * sin(_time * 0.7 + star["phase"])
		draw_circle(star["pos"], star["size"],
			Color(0.5, 0.5, 0.7, star["brightness"] * flicker * 0.4))

	# 标题
	draw_string(font, Vector2(vp.x * 0.4 - 100, 40),
		"CELESTIAL TUNER", HORIZONTAL_ALIGNMENT_CENTER, 200, 20, WARM_ORANGE)
	draw_string(font, Vector2(vp.x * 0.4 - 60, 62),
		"天 体 调 音 仪", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, DIM_TEXT)

	# 轨道环
	_draw_orbits(center)

	# 更新位置
	_calculate_positions()

	# 连接线
	_draw_connections(center)

	# 调式行星
	_mode_rects.clear()
	for mode_name in MODE_DISPLAY:
		_draw_mode_planet(mode_name, font, center)

	# 信息面板（右侧）
	_draw_info_panel(font, vp)

	# 导航按钮
	_draw_buttons(font, vp)

func _draw_orbits(center: Vector2) -> void:
	# 轨道环
	var radii := [160.0, 260.0]
	for r in radii:
		draw_arc(center, r, 0, TAU, 64,
			Color(0.15, 0.12, 0.22, 0.3), 1.0)

func _draw_connections(center: Vector2) -> void:
	# 从中心向外连线
	for mode_name in MODE_DISPLAY:
		if mode_name == "ionian":
			continue
		var pos: Vector2 = _mode_positions.get(mode_name, center)
		draw_line(center, pos, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.1), 1.0)

func _draw_mode_planet(mode_name: String, font: Font, center: Vector2) -> void:
	var display: Dictionary = MODE_DISPLAY[mode_name]
	var pos: Vector2 = _mode_positions.get(mode_name, center)
	var mode_color: Color = display.get("color", ACCENT)
	var is_selected := (mode_name == _selected_mode)
	var is_hover := (mode_name == _hover_mode)
	var is_unlocked := _is_mode_unlocked(mode_name)

	var radius := 35.0 if is_selected else (30.0 if is_hover else 26.0)

	# 记录碰撞区域
	_mode_rects[mode_name] = Rect2(pos - Vector2(radius, radius), Vector2(radius * 2, radius * 2))

	if not is_unlocked:
		# 未解锁 — 灰暗虚线
		var segments := 16
		for i in range(segments):
			if i % 2 == 0:
				var a1 := float(i) / float(segments) * TAU
				var a2 := float(i + 1) / float(segments) * TAU
				var p1 := pos + Vector2(cos(a1), sin(a1)) * radius
				var p2 := pos + Vector2(cos(a2), sin(a2)) * radius
				draw_line(p1, p2, Color(0.3, 0.25, 0.4, 0.3), 1.5)
		draw_string(font, pos + Vector2(-8, 5), "?",
			HORIZONTAL_ALIGNMENT_CENTER, 16, 14, Color(0.4, 0.35, 0.5, 0.4))
		# 费用
		var cost := _get_mode_cost(mode_name)
		if cost > 0:
			draw_string(font, pos + Vector2(-20, radius + 14),
				"%d ✦" % cost, HORIZONTAL_ALIGNMENT_CENTER, 40, 9,
				Color(DANGER.r, DANGER.g, DANGER.b, 0.5))
		return

	# 已解锁
	if is_selected:
		# 选中态 — 金色光环
		for i in range(3):
			var r := radius + 4 + i * 4.0
			var alpha := 0.15 - i * 0.04
			draw_arc(pos, r, 0, TAU, 48,
				Color(GOLD.r, GOLD.g, GOLD.b, alpha + 0.05 * sin(_time * 2.0)), 2.0)
		draw_circle(pos, radius, Color(mode_color.r, mode_color.g, mode_color.b, 0.2))
		draw_arc(pos, radius, 0, TAU, 48, Color(GOLD.r, GOLD.g, GOLD.b, 0.8), 2.5)
	elif is_hover:
		draw_circle(pos, radius, Color(mode_color.r, mode_color.g, mode_color.b, 0.12))
		draw_arc(pos, radius, 0, TAU, 48,
			Color(mode_color.r, mode_color.g, mode_color.b, 0.6), 2.0)
	else:
		draw_circle(pos, radius, Color(mode_color.r, mode_color.g, mode_color.b, 0.08))
		draw_arc(pos, radius, 0, TAU, 48,
			Color(mode_color.r, mode_color.g, mode_color.b, 0.35), 1.5)

	# 调式名称
	var name_text: String = display.get("name", "")
	var name_short := name_text.left(4) if name_text.length() > 4 else name_text
	var text_col := GOLD if is_selected else (TEXT_COLOR if is_hover else mode_color)
	draw_string(font, pos + Vector2(-16, 5), name_short,
		HORIZONTAL_ALIGNMENT_CENTER, 32, 11, text_col)

	# 标签
	draw_string(font, pos + Vector2(-30, radius + 14),
		display.get("name", ""), HORIZONTAL_ALIGNMENT_CENTER, 60, 10,
		Color(DIM_TEXT.r, DIM_TEXT.g, DIM_TEXT.b, 0.7))

func _draw_info_panel(font: Font, vp: Vector2) -> void:
	# 右侧信息面板
	var panel_x := vp.x * 0.65
	var panel_y := vp.y * 0.15
	var panel_w := vp.x * 0.3
	var panel_h := vp.y * 0.65
	var panel_rect := Rect2(Vector2(panel_x, panel_y), Vector2(panel_w, panel_h))

	draw_rect(panel_rect, Color(0.06, 0.04, 0.1, 0.7))
	draw_rect(panel_rect, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.15), false, 1.0)

	# 显示当前悬停或选中的调式信息
	var display_mode := _hover_mode if not _hover_mode.is_empty() else _selected_mode
	var display: Dictionary = MODE_DISPLAY.get(display_mode, {})
	if display.is_empty():
		return

	var mode_color: Color = display.get("color", ACCENT)
	var y := panel_y + 20

	# 调式名称
	draw_string(font, Vector2(panel_x + 20, y + 20),
		display.get("name", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, mode_color)
	y += 30

	# 职业标题
	draw_string(font, Vector2(panel_x + 20, y + 15),
		"[ %s ]" % display.get("title", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.7))
	y += 30

	# 分隔线
	draw_line(Vector2(panel_x + 20, y), Vector2(panel_x + panel_w - 20, y),
		Color(0.2, 0.18, 0.3, 0.4), 1.0)
	y += 15

	# 描述
	draw_string(font, Vector2(panel_x + 20, y + 14),
		display.get("desc", ""), HORIZONTAL_ALIGNMENT_LEFT, int(panel_w - 40), 12, DIM_TEXT)
	y += 40

	# 音阶
	draw_string(font, Vector2(panel_x + 20, y + 14),
		"音阶:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.45, 0.6))
	draw_string(font, Vector2(panel_x + 70, y + 14),
		display.get("notes", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CYAN)
	y += 30

	# 被动效果
	draw_string(font, Vector2(panel_x + 20, y + 14),
		"被动:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.45, 0.6))
	draw_string(font, Vector2(panel_x + 70, y + 14),
		display.get("passive", ""), HORIZONTAL_ALIGNMENT_LEFT, int(panel_w - 90), 12, SUCCESS)
	y += 30

	# 解锁状态
	var is_unlocked := _is_mode_unlocked(display_mode)
	if is_unlocked:
		if display_mode == _selected_mode:
			draw_string(font, Vector2(panel_x + 20, y + 14),
				"✓ 当前选择", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
		else:
			draw_string(font, Vector2(panel_x + 20, y + 14),
				"已解锁 — 点击选择", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color(CYAN.r, CYAN.g, CYAN.b, 0.7))
	else:
		var cost := _get_mode_cost(display_mode)
		draw_string(font, Vector2(panel_x + 20, y + 14),
			"需要 %d ✦ 解锁" % cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(DANGER.r, DANGER.g, DANGER.b, 0.7))

var _back_btn_rect := Rect2()
var _confirm_btn_rect := Rect2()

func _draw_buttons(font: Font, vp: Vector2) -> void:
	# 返回
	_back_btn_rect = Rect2(Vector2(30, vp.y - 55), Vector2(120, 40))
	draw_rect(_back_btn_rect, Color(0.1, 0.08, 0.18, 0.85))
	draw_rect(_back_btn_rect, Color(0.4, 0.35, 0.55, 0.5), false, 1.0)
	draw_string(font, _back_btn_rect.position + Vector2(16, 26),
		"← 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.65, 0.85))

	# 确认选择
	_confirm_btn_rect = Rect2(Vector2(vp.x - 180, vp.y - 55), Vector2(150, 40))
	draw_rect(_confirm_btn_rect, Color(0.05, 0.15, 0.1, 0.85))
	draw_rect(_confirm_btn_rect, Color(0.3, 0.8, 0.5, 0.5), false, 1.0)
	draw_string(font, _confirm_btn_rect.position + Vector2(16, 26),
		"确认选择 ✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 0.9, 0.5))

# ============================================================
# 输入处理
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event is InputEventMouseMotion:
		_hover_mode = ""
		for mode_name in _mode_rects:
			var rect: Rect2 = _mode_rects[mode_name]
			var pos: Vector2 = _mode_positions.get(mode_name, Vector2.ZERO)
			if pos.distance_to(event.position) <= 40.0:
				_hover_mode = mode_name
				break

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 按钮
			if _back_btn_rect.has_point(event.position):
				close()
				return
			if _confirm_btn_rect.has_point(event.position):
				_confirm_selection()
				return

			# 调式行星
			if not _hover_mode.is_empty():
				_on_mode_clicked(_hover_mode)

	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				close()
			KEY_ENTER:
				_confirm_selection()

# ============================================================
# 交互逻辑
# ============================================================

func _on_mode_clicked(mode_name: String) -> void:
	if _is_mode_unlocked(mode_name):
		# 选择调式
		_selected_mode = mode_name
		if _meta:
			_meta.select_mode(mode_name)
		mode_selected.emit(mode_name)
	else:
		# 尝试解锁
		if _meta:
			var success := _meta.purchase_mode_unlock(mode_name)
			if success:
				_selected_mode = mode_name
				_meta.select_mode(mode_name)
				mode_selected.emit(mode_name)

func _confirm_selection() -> void:
	confirm_pressed.emit()
	close()

# ============================================================
# 工具函数
# ============================================================

func _is_mode_unlocked(mode_name: String) -> bool:
	if not _meta:
		return mode_name == "ionian"
	return _meta.is_mode_unlocked(mode_name)

func _get_mode_cost(mode_name: String) -> int:
	if not _meta:
		return 0
	var config: Dictionary = _meta.MODE_CONFIGS.get(mode_name, {})
	return config.get("cost", 0)
