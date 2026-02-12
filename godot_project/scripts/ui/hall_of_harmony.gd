## hall_of_harmony.gd — 和谐殿堂主界面 v5.0
## "星图中的交响诗" — 四大星宿入口导航
##
## 设计文档: Docs/UI_Design_Module5_HallOfHarmony.md §2
## 中央星云 + 四大星宿（左上/右上/左下/右下）
## 共鸣碎片货币展示（右上角常驻）
## 点击星宿 → 飞入技能树子界面
extends Control

# ============================================================
# 信号
# ============================================================
signal start_game_pressed()
signal back_pressed()
signal module_selected(module_key: String)
signal upgrade_selected(upgrade_id: String, category: String)

# ============================================================
# 颜色方案 — 全局 UI 主题规范
# ============================================================
const BG_COLOR := Color("#0A0814")
const PANEL_BG := Color("#141026CC")       # 80% 不透明
const ACCENT := Color("#9D6FFF")           # 主强调色
const GOLD := Color("#FFD700")             # 圣光金
const CYAN := Color("#00E5FF")             # 谐振青
const TEXT_COLOR := Color("#EAE6FF")       # 晶体白
const DIM_TEXT := Color("#A098C8")         # 次级文本
const SUCCESS := Color("#4DFF80")
const DANGER := Color("#FF4D4D")
const LOCKED_COLOR := Color("#6B668A")

# ============================================================
# 布局参数 — @export 支持编辑器实时调整
# ============================================================
@export_group("Layout")
@export var star_count: int = 200
@export var viewport_width: float = 1920.0
@export var viewport_height: float = 1080.0
@export var fragment_panel_width: float = 240.0
@export var fragment_panel_height: float = 44.0
@export var panel_corner_radius: int = 8
@export var panel_content_margin: float = 16.0

# ============================================================
# 四大模块定义
# ============================================================
const MODULES := {
	"instrument": {
		"name": "乐器调优",
		"name_en": "Instrument Tuning",
		"desc": "永久强化你的基础能力",
		"icon": "♪",
		"color": Color(0.2, 0.8, 1.0),
		"position": "top_left",
	},
	"theory": {
		"name": "乐理研习",
		"name_en": "Theory Archives",
		"desc": "解锁高级乐理知识与和弦",
		"icon": "♫",
		"color": Color(0.8, 0.4, 1.0),
		"position": "top_right",
	},
	"modes": {
		"name": "调式风格",
		"name_en": "Mode Mastery",
		"desc": "发现并激活新的演奏风格",
		"icon": "♬",
		"color": Color(1.0, 0.6, 0.2),
		"position": "bottom_left",
	},
	"denoise": {
		"name": "声学降噪",
		"name_en": "Acoustic Treatment",
		"desc": "构建谐振防御场，抵御疲劳",
		"icon": "♩",
		"color": Color(0.3, 1.0, 0.5),
		"position": "bottom_right",
	},
}

# ============================================================
# 内部状态
# ============================================================
var _meta: Node = null
var _resonance_fragments: int = 0
var _selected_mode: String = "ionian"

## 星宿区域（用于悬停检测）
var _constellation_rects: Dictionary = {}   # module_key → Rect2
var _constellation_centers: Dictionary = {} # module_key → Vector2
var _hover_module: String = ""
var _time: float = 0.0

## 子界面
var _active_sub_screen: Control = null
var _fragments_label: Label = null

## 星尘粒子（背景装饰）
var _stars: Array[Dictionary] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_meta = get_node_or_null("/root/MetaProgressionManager")
	_load_state()
	_generate_stars(star_count)
	_build_ui_overlay()

	if _meta:
		if _meta.has_signal("resonance_fragments_changed"):
			_meta.resonance_fragments_changed.connect(_on_fragments_changed)

	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

# ============================================================
# 状态同步
# ============================================================

func _load_state() -> void:
	if _meta:
		_resonance_fragments = _meta.get_resonance_fragments()
		_selected_mode = _meta.get_selected_mode()

# ============================================================
# 背景星尘生成
# ============================================================

func _generate_stars(count: int) -> void:
	_stars.clear()
	for i in range(count):
		_stars.append({
			"pos": Vector2(randf() * viewport_width, randf() * viewport_height),
			"size": randf_range(0.5, 2.5),
			"speed": randf_range(0.1, 0.5),
			"phase": randf() * TAU,
			"brightness": randf_range(0.3, 1.0),
		})

# ============================================================
# UI 覆盖层（货币 + 按钮）
# ============================================================

func _build_ui_overlay() -> void:
	# 共鸣碎片显示 — 右上角
	var frag_panel := PanelContainer.new()
	frag_panel.name = "FragmentPanel"
	var frag_style := StyleBoxFlat.new()
	frag_style.bg_color = Color(0.08, 0.06, 0.14, 0.9)
	frag_style.border_color = ACCENT.darkened(0.3)
	frag_style.border_width_top = 1
	frag_style.border_width_bottom = 1
	frag_style.border_width_left = 1
	frag_style.border_width_right = 1
	frag_style.corner_radius_top_left = panel_corner_radius
	frag_style.corner_radius_top_right = panel_corner_radius
	frag_style.corner_radius_bottom_left = panel_corner_radius
	frag_style.corner_radius_bottom_right = panel_corner_radius
	frag_style.content_margin_left = int(panel_content_margin)
	frag_style.content_margin_right = int(panel_content_margin)
	frag_style.content_margin_top = 8
	frag_style.content_margin_bottom = 8
	frag_panel.add_theme_stylebox_override("panel", frag_style)
	frag_panel.position = Vector2(viewport_width - 260, 16)
	frag_panel.size = Vector2(fragment_panel_width, fragment_panel_height)
	add_child(frag_panel)

	var frag_hbox := HBoxContainer.new()
	frag_hbox.add_theme_constant_override("separation", 8)
	frag_panel.add_child(frag_hbox)

	var icon_label := Label.new()
	icon_label.text = "✦"
	icon_label.add_theme_font_size_override("font_size", 20)
	icon_label.add_theme_color_override("font_color", ACCENT)
	frag_hbox.add_child(icon_label)

	_fragments_label = Label.new()
	_fragments_label.text = "%d" % _resonance_fragments
	_fragments_label.add_theme_font_size_override("font_size", 18)
	_fragments_label.add_theme_color_override("font_color", TEXT_COLOR)
	frag_hbox.add_child(_fragments_label)

	var frag_name := Label.new()
	frag_name.text = "共鸣碎片"
	frag_name.add_theme_font_size_override("font_size", 12)
	frag_name.add_theme_color_override("font_color", DIM_TEXT)
	frag_hbox.add_child(frag_name)

	# 底部按钮栏
	var btn_bar := HBoxContainer.new()
	btn_bar.name = "ButtonBar"
	btn_bar.position = Vector2(1920 / 2.0 - 200, 1080 - 70)
	btn_bar.size = Vector2(400, 50)
	btn_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_bar.add_theme_constant_override("separation", 24)
	add_child(btn_bar)

	var back_btn := Button.new()
	back_btn.text = "← 返回"
	back_btn.custom_minimum_size = Vector2(140, 44)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.pressed.connect(func(): back_pressed.emit())
	btn_bar.add_child(back_btn)

	var start_btn := Button.new()
	start_btn.text = "开始演奏 ▶"
	start_btn.custom_minimum_size = Vector2(180, 44)
	start_btn.add_theme_font_size_override("font_size", 14)
	start_btn.pressed.connect(func(): start_game_pressed.emit())
	btn_bar.add_child(start_btn)

# ============================================================
# 绘制 — 星图主界面
# ============================================================

func _draw() -> void:
	if _active_sub_screen != null:
		return

	var vp := get_viewport_rect().size
	var center := vp / 2.0

	# 深空背景
	draw_rect(Rect2(Vector2.ZERO, vp), BG_COLOR)

	# 星尘粒子
	_draw_stars()

	# 中央星云
	_draw_central_nebula(center)

	# 四大星宿
	_draw_constellations(center, vp)

	# 标题
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(center.x - 120, 50),
		"HALL OF HARMONY", HORIZONTAL_ALIGNMENT_CENTER, 240, 22,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.9))
	draw_string(font, Vector2(center.x - 60, 72),
		"和 谐 殿 堂", HORIZONTAL_ALIGNMENT_CENTER, 120, 13,
		Color(DIM_TEXT.r, DIM_TEXT.g, DIM_TEXT.b, 0.7))

	# 悬停信息
	_draw_hover_info(font, vp)

func _draw_stars() -> void:
	for star in _stars:
		var brightness: float = star["brightness"]
		var phase: float = star["phase"]
		var flicker := 0.5 + 0.5 * sin(_time * star["speed"] * 2.0 + phase)
		var alpha := brightness * flicker
		var s: float = star["size"]
		var pos: Vector2 = star["pos"]
		# 缓慢漂移
		pos.x = fmod(pos.x + star["speed"] * 0.3, 1920.0)
		star["pos"] = pos
		draw_circle(pos, s, Color(0.7, 0.7, 0.9, alpha * 0.6))

func _draw_central_nebula(center: Vector2) -> void:
	# 呼吸效果
	var breath := 0.9 + 0.1 * sin(_time * 0.8)
	var base_radius := 60.0 * breath

	# 多层辉光
	for i in range(5):
		var r := base_radius + i * 20.0
		var alpha := 0.15 - i * 0.025
		var color := Color(CYAN.r, CYAN.g, CYAN.b, alpha)
		draw_arc(center, r, 0, TAU, 64, color, 2.0)

	# 核心光点
	draw_circle(center, 8.0, Color(CYAN.r, CYAN.g, CYAN.b, 0.6 * breath))
	draw_circle(center, 4.0, Color(1.0, 1.0, 1.0, 0.8 * breath))

	# 旋转光线
	for i in range(8):
		var angle := _time * 0.3 + i * TAU / 8.0
		var inner := center + Vector2(cos(angle), sin(angle)) * 15.0
		var outer := center + Vector2(cos(angle), sin(angle)) * (base_radius + 10.0)
		draw_line(inner, outer, Color(GOLD.r, GOLD.g, GOLD.b, 0.08), 1.0)

func _draw_constellations(center: Vector2, vp: Vector2) -> void:
	_constellation_rects.clear()
	_constellation_centers.clear()

	var offsets := {
		"top_left": Vector2(-0.28, -0.25),
		"top_right": Vector2(0.28, -0.25),
		"bottom_left": Vector2(-0.28, 0.22),
		"bottom_right": Vector2(0.28, 0.22),
	}

	var font := ThemeDB.fallback_font

	for module_key in MODULES:
		var module: Dictionary = MODULES[module_key]
		var pos_key: String = module["position"]
		var offset: Vector2 = offsets[pos_key]
		var constellation_center := center + Vector2(offset.x * vp.x, offset.y * vp.y)
		var module_color: Color = module["color"]
		var is_hover := (_hover_module == module_key)

		_constellation_centers[module_key] = constellation_center

		# 星宿区域
		var rect_size := Vector2(220, 180)
		var rect := Rect2(constellation_center - rect_size / 2.0, rect_size)
		_constellation_rects[module_key] = rect

		# 连接线到中央星云
		var line_alpha := 0.15 if not is_hover else 0.35
		draw_line(center, constellation_center, Color(ACCENT.r, ACCENT.g, ACCENT.b, line_alpha), 1.0)

		# 星宿光点群
		_draw_constellation_pattern(module_key, constellation_center, module_color, is_hover)

		# 模块图标
		var icon_alpha := 0.8 if is_hover else 0.5
		var icon_size := 28 if is_hover else 22
		draw_string(font, constellation_center + Vector2(-8, -40),
			module["icon"], HORIZONTAL_ALIGNMENT_CENTER, -1, icon_size,
			Color(module_color.r, module_color.g, module_color.b, icon_alpha))

		# 模块名称
		var name_alpha := 1.0 if is_hover else 0.6
		draw_string(font, constellation_center + Vector2(-40, 55),
			module["name"], HORIZONTAL_ALIGNMENT_CENTER, 80, 14,
			Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, name_alpha))

		# 进度指示
		if _meta:
			var progress := _meta.get_module_progress(module_key)
			var progress_text := "%d%%" % int(progress * 100)
			draw_string(font, constellation_center + Vector2(-20, 72),
				progress_text, HORIZONTAL_ALIGNMENT_CENTER, 40, 10,
				Color(DIM_TEXT.r, DIM_TEXT.g, DIM_TEXT.b, 0.6))

		# 悬停辉光
		if is_hover:
			for i in range(3):
				var glow_r := 80.0 + i * 15.0
				var glow_a := 0.08 - i * 0.02
				draw_arc(constellation_center, glow_r, 0, TAU, 48,
					Color(module_color.r, module_color.g, module_color.b, glow_a), 2.0)

func _draw_constellation_pattern(module_key: String, center: Vector2, color: Color, is_hover: bool) -> void:
	var breath := 0.8 + 0.2 * sin(_time * 1.2)
	var base_alpha := 0.7 if is_hover else 0.35
	var points: Array[Vector2] = []

	match module_key:
		"instrument":
			# 里拉琴形状 — 垂直推杆
			for i in range(5):
				var x := center.x + (i - 2) * 18.0
				var y := center.y + sin(_time * 0.5 + i * 0.8) * 8.0
				points.append(Vector2(x, y))
				var h := 25.0 + i * 3.0
				draw_line(Vector2(x, y - h), Vector2(x, y + h),
					Color(color.r, color.g, color.b, base_alpha * 0.6), 1.5)
		"theory":
			# 螺旋星系 — 辐射状
			for i in range(12):
				var angle := i * TAU / 12.0 + _time * 0.2
				var r := 20.0 + i * 3.0
				var pt := center + Vector2(cos(angle), sin(angle)) * r
				points.append(pt)
		"modes":
			# 万花尺 — 分形图案
			for i in range(8):
				var angle := i * TAU / 8.0 + _time * 0.15
				var r := 30.0 + 10.0 * sin(angle * 3.0 + _time)
				var pt := center + Vector2(cos(angle), sin(angle)) * r
				points.append(pt)
		"denoise":
			# 声波干涉 — 同心环
			for i in range(3):
				var r := 15.0 + i * 15.0
				draw_arc(center, r * breath, 0, TAU, 32,
					Color(color.r, color.g, color.b, base_alpha * (0.5 - i * 0.1)), 1.0)

	# 绘制星点
	for pt in points:
		var s := 2.5 if is_hover else 1.8
		draw_circle(pt, s * breath, Color(color.r, color.g, color.b, base_alpha * breath))

	# 连接线
	if points.size() > 1:
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1],
				Color(color.r, color.g, color.b, base_alpha * 0.3), 0.8)

func _draw_hover_info(font: Font, vp: Vector2) -> void:
	if _hover_module.is_empty():
		return
	var module: Dictionary = MODULES[_hover_module]
	var info_text := "%s: %s" % [module["name"], module["desc"]]
	var info_w := 500.0
	var info_rect := Rect2(Vector2(vp.x / 2.0 - info_w / 2.0, vp.y - 120), Vector2(info_w, 40))
	draw_rect(info_rect, Color(0.06, 0.04, 0.12, 0.85))
	draw_rect(info_rect, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3), false, 1.0)
	draw_string(font, info_rect.position + Vector2(20, 26),
		info_text, HORIZONTAL_ALIGNMENT_LEFT, int(info_w - 40), 13, TEXT_COLOR)

# ============================================================
# 输入处理
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if _active_sub_screen != null:
		return

	if event is InputEventMouseMotion:
		_hover_module = ""
		for module_key in _constellation_rects:
			if _constellation_rects[module_key].has_point(event.position):
				_hover_module = module_key
				break

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not _hover_module.is_empty():
				_open_module(_hover_module)

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			back_pressed.emit()

# ============================================================
# 模块子界面管理
# ============================================================

func _open_module(module_key: String) -> void:
	module_selected.emit(module_key)

	# 加载技能树可视化器
	var viz_script := load("res://scripts/ui/meta_progression_visualizer.gd")
	if viz_script == null:
		return

	_active_sub_screen = Control.new()
	_active_sub_screen.set_script(viz_script)
	_active_sub_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_active_sub_screen)

	# 传入选中的模块
	if _active_sub_screen.has_method("open_module"):
		_active_sub_screen.open_module(module_key)
	elif _active_sub_screen.has_method("open_panel"):
		_active_sub_screen.open_panel()

	# 连接信号
	if _active_sub_screen.has_signal("back_pressed"):
		_active_sub_screen.back_pressed.connect(_on_sub_screen_back)
	if _active_sub_screen.has_signal("node_unlocked"):
		_active_sub_screen.node_unlocked.connect(
			func(nid: String, cat: String): upgrade_selected.emit(nid, cat))

func _on_sub_screen_back() -> void:
	if _active_sub_screen:
		_active_sub_screen.queue_free()
		_active_sub_screen = null
	_load_state()
	_update_fragments_display()
	queue_redraw()

func _update_fragments_display() -> void:
	if _fragments_label:
		_fragments_label.text = "%d" % _resonance_fragments

func _on_fragments_changed(new_total: int) -> void:
	_resonance_fragments = new_total
	_update_fragments_display()

# ============================================================
# 公共接口（兼容 game_over.gd 调用）
# ============================================================

func open_panel() -> void:
	visible = true
	_load_state()
	_update_fragments_display()
	queue_redraw()

func close_panel() -> void:
	if _active_sub_screen:
		_active_sub_screen.queue_free()
		_active_sub_screen = null
	visible = false
	back_pressed.emit()
