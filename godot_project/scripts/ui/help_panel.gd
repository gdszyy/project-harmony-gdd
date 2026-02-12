## help_panel.gd
## 帮助面板 + 首次引导系统 — v6.0
##
## 根据 UI_Design_Module4_CircleOfFifths.md §10 设计文档实现：
##   - 首次引导 (First-Time Tutorial)：步骤式高亮引导序列 (§10.1)
##   - 帮助面板 (Help Panel)：图文结合的机制说明 (§10.2)
##   - 升级界面右下角 "?" 按钮触发
##   - 占屏幕 60%，星空紫背景 + 谐振紫边框
##   - 多页签式内容：五度圈基础、三个方向、金色标识、乐理突破
##
## 独立组件，可被 CircleOfFifthsUpgradeV3 或其他 UI 引用。
extends Control

# ============================================================
# 信号
# ============================================================
signal panel_closed()
signal tutorial_completed()
signal tutorial_step_advanced(step: int)

# ============================================================
# 常量 — 颜色方案 (§1.2)
# ============================================================
const COL_BG := Color("#0A0814F2")
const COL_PANEL_BG := Color("#141026")
const COL_ACCENT := Color("#9D6FFF")
const COL_GOLD := Color("#FFD700")
const COL_OFFENSE := Color("#FF4444")
const COL_DEFENSE := Color("#4488FF")
const COL_CORE := Color("#9D6FFF")
const COL_TEXT_PRIMARY := Color("#EAE6FF")
const COL_TEXT_SECONDARY := Color("#A098C8")
const COL_TEXT_DIM := Color("#6B668A")

# ============================================================
# 帮助页签配置
# ============================================================
enum HelpTab { CIRCLE_OF_FIFTHS, THREE_DIRECTIONS, GOLD_BADGE, THEORY_BREAKTHROUGH }

const TAB_CONFIG: Array = [
	{ "title": "五度圈基础", "icon": "◎", "tab": HelpTab.CIRCLE_OF_FIFTHS },
	{ "title": "三个方向", "icon": "△", "tab": HelpTab.THREE_DIRECTIONS },
	{ "title": "金色标识", "icon": "★", "tab": HelpTab.GOLD_BADGE },
	{ "title": "乐理突破", "icon": "✦", "tab": HelpTab.THEORY_BREAKTHROUGH },
]

# ============================================================
# 首次引导步骤配置 (§10.1)
# ============================================================
const TUTORIAL_STEPS: Array = [
	{ "text": "这是五度圈罗盘，你的升级之路。\n每次升级时，罗盘会激活并展示可选方向。", "highlight": "compass" },
	{ "text": "罗盘有三个方向：\n进攻（顺时针·红）、防御（逆时针·蓝）、核心（中心·紫）。\n每个方向提供不同类型的升级。", "highlight": "directions" },
	{ "text": "选择一个方向后，会出现 2-3 张升级卡片。\n仔细阅读效果，选择最适合当前局势的升级。", "highlight": "cards" },
	{ "text": "准备好了吗？现在轮到你来选择了！\n祝你在谐振之路上一帆风顺。", "highlight": "none" },
]

# ============================================================
# 内部状态
# ============================================================
var _help_visible: bool = false
var _current_tab: int = 0
var _overlay: ColorRect = null
var _panel: PanelContainer = null
var _tab_bar: HBoxContainer = null
var _content_container: VBoxContainer = null
var _content_scroll: ScrollContainer = null

var _tutorial_active: bool = false
var _tutorial_step: int = 0
var _tutorial_overlay: ColorRect = null
var _tutorial_panel: PanelContainer = null
var _tutorial_text: Label = null
var _tutorial_next_btn: Button = null
var _tutorial_skip_btn: Button = null
var _tutorial_step_label: Label = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _help_visible and not _tutorial_active:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _tutorial_active:
			_end_tutorial()
		else:
			hide_panel()
		get_viewport().set_input_as_handled()

# ============================================================
# 公共接口 — 帮助面板 (§10.2)
# ============================================================

func show_panel() -> void:
	if _help_visible:
		return
	_help_visible = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_help_panel()
	_play_show_animation()

func hide_panel() -> void:
	if not _help_visible:
		return
	_play_hide_animation()

func toggle_panel() -> void:
	if _help_visible:
		hide_panel()
	else:
		show_panel()

# ============================================================
# 公共接口 — 首次引导 (§10.1)
# ============================================================

func start_tutorial() -> void:
	if _tutorial_active:
		return
	_tutorial_active = true
	_tutorial_step = 0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_tutorial_ui()
	_show_tutorial_step(0)

func end_tutorial() -> void:
	_end_tutorial()

# ============================================================
# 帮助面板构建
# ============================================================

func _build_help_panel() -> void:
	for child in get_children():
		child.queue_free()

	# 全屏暗色遮罩
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = COL_BG
	_overlay.gui_input.connect(_on_overlay_clicked)
	add_child(_overlay)

	# 主面板 — 占屏幕 60%
	_panel = PanelContainer.new()
	_panel.set_anchor(SIDE_LEFT, 0.2)
	_panel.set_anchor(SIDE_RIGHT, 0.8)
	_panel.set_anchor(SIDE_TOP, 0.15)
	_panel.set_anchor(SIDE_BOTTOM, 0.85)
	_panel.offset_left = 0; _panel.offset_right = 0
	_panel.offset_top = 0; _panel.offset_bottom = 0

	var ps := StyleBoxFlat.new()
	ps.bg_color = COL_PANEL_BG
	ps.border_color = COL_ACCENT
	for side in ["border_width_left","border_width_right","border_width_top","border_width_bottom"]:
		ps.set(side, 2)
	for corner in ["corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right"]:
		ps.set(corner, 12)
	ps.content_margin_left = 24; ps.content_margin_right = 24
	ps.content_margin_top = 16; ps.content_margin_bottom = 16
	ps.shadow_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.15)
	ps.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", ps)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)

	# 标题栏
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "✦ 机制说明 — 五度圈罗盘 ✦"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"; close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(hide_panel)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.3, 0.1, 0.1, 0.3)
	for c in ["corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right"]:
		cs.set(c, 4)
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.add_theme_color_override("font_color", COL_TEXT_SECONDARY)
	close_btn.add_theme_color_override("font_hover_color", Color.RED)
	header.add_child(close_btn)
	main_vbox.add_child(header)

	# 分割线
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.4)
	main_vbox.add_child(sep)

	# 页签栏
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 8)
	_tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(TAB_CONFIG.size()):
		var tab := TAB_CONFIG[i] as Dictionary
		var btn := Button.new()
		btn.text = "%s %s" % [tab["icon"], tab["title"]]
		btn.custom_minimum_size = Vector2(120, 32)
		btn.pressed.connect(_on_tab_selected.bind(i))
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.1)
		bs.border_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.3)
		bs.border_width_bottom = 1
		bs.corner_radius_top_left = 4; bs.corner_radius_top_right = 4
		bs.content_margin_left = 8; bs.content_margin_right = 8
		btn.add_theme_stylebox_override("normal", bs)
		var ba := bs.duplicate()
		ba.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.25)
		ba.border_color = COL_ACCENT; ba.border_width_bottom = 2
		btn.add_theme_stylebox_override("disabled", ba)
		btn.add_theme_color_override("font_color", COL_TEXT_SECONDARY)
		btn.add_theme_color_override("font_disabled_color", COL_ACCENT)
		btn.add_theme_font_size_override("font_size", 12)
		btn.disabled = (i == _current_tab)
		_tab_bar.add_child(btn)
	main_vbox.add_child(_tab_bar)

	# 内容区域
	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 12)
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.add_child(_content_container)
	main_vbox.add_child(_content_scroll)

	_panel.add_child(main_vbox)
	add_child(_panel)
	_fill_tab_content(_current_tab)

# ============================================================
# 页签内容
# ============================================================

func _fill_tab_content(tab_idx: int) -> void:
	for child in _content_container.get_children():
		child.queue_free()
	match tab_idx:
		0: _fill_circle_of_fifths()
		1: _fill_three_directions()
		2: _fill_gold_badge()
		3: _fill_theory_breakthrough()

func _fill_circle_of_fifths() -> void:
	_sec("五度圈 (Circle of Fifths)")
	_para("五度圈是音乐理论中最重要的概念之一，它描述了 12 个音级之间的和谐关系。在《Project Harmony》中，五度圈被具象化为一个古代星盘——你的升级罗盘。")
	_kv([["顺时针方向","升号方向 (♯)，音色更明亮、锐利",COL_OFFENSE],["逆时针方向","降号方向 (♭)，音色更柔和、温暖",COL_DEFENSE],["中心位置","当前调性的稳定核心",COL_CORE]])
	_para("每次升级时，罗盘会激活。你需要先选择一个方向（进攻/防御/核心），然后从该方向提供的 2-3 张升级卡片中选择一张。")
	_sec("音级与调性")
	_para("罗盘外圈展示 12 个大调音级（C, G, D, A, E, B, F♯/G♭, D♭, A♭, E♭, B♭, F），按照五度关系排列。当前调性会以高亮标记，相邻音级代表和谐度最高的调性。")

func _fill_three_directions() -> void:
	_sec("三个升级方向")
	_dir("进攻方向 (♯ 升号)", COL_OFFENSE, ["提升伤害、攻击速度、弹体效果","对应五度圈顺时针方向","适合追求高输出的玩法风格","升级类型：伤害加成、穿透、暴击、范围扩大"])
	_dir("防御方向 (♭ 降号)", COL_DEFENSE, ["提升生存能力、护盾、回复","对应五度圈逆时针方向","适合追求稳健生存的玩法风格","升级类型：护盾、生命回复、减伤、控制效果"])
	_dir("核心方向 (♮ 还原号)", COL_CORE, ["提升基础能力、解锁新机制","对应五度圈中心位置","适合追求全面发展的玩法风格","升级类型：经验加成、冷却缩减、新法术形态、乐理突破"])

func _fill_gold_badge() -> void:
	_sec("金色标识 — 局外解锁")
	_para("带有金色边框和 ★ 标识的升级卡片，代表它来自「和谐殿堂」的局外解锁系统。这些升级是你在多次游戏中积累的永久成长成果。")
	_kv([["金色边框","该升级通过局外成长系统解锁",COL_GOLD],["★ 徽章","标记此升级为局外解锁来源",COL_GOLD],["出现条件","需要在和谐殿堂中先解锁对应节点",COL_TEXT_SECONDARY]])
	_para("局外解锁的升级不会替代普通升级池，而是作为额外选项出现。它们通常比同稀有度的普通升级更强，代表了你作为谐振者的成长。")

func _fill_theory_breakthrough() -> void:
	_sec("乐理突破 — 特殊事件")
	_para("「乐理突破」是一种稀有的特殊升级事件，当你在五度圈上达到特定条件时触发。它会直接解锁核心游戏机制，如新的和弦类型、调式切换、节奏型等。")
	_kv([["触发条件","在特定音级组合上积累足够升级",COL_ACCENT],["视觉表现","金色全屏闪光 + 几何图案粒子效果",COL_GOLD],["效果","永久解锁新的游戏机制",COL_GOLD]])
	_para("乐理突破事件的 UI 表现具有强烈的仪式感：罗盘会剧烈旋转，中心星云爆发金色光芒，随后展示一张传说级卡片。")
	_sec("突破类型示例")
	_kv([["和弦解锁","解锁新的和弦组合方式",COL_ACCENT],["调式切换","获得在战斗中切换调式的能力",COL_ACCENT],["节奏进化","解锁更复杂的节奏型",COL_ACCENT],["音色融合","解锁音色混合技术",COL_ACCENT]])

# ============================================================
# 内容辅助函数 (简写)
# ============================================================

func _sec(text: String) -> void:
	var l := Label.new()
	l.text = "— %s —" % text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", COL_ACCENT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_container.add_child(l)

func _para(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", COL_TEXT_PRIMARY)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_container.add_child(l)

func _kv(items: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	for item in items:
		var kl := Label.new()
		kl.text = item[0]; kl.custom_minimum_size.x = 120
		kl.add_theme_font_size_override("font_size", 12)
		kl.add_theme_color_override("font_color", item[2] if item.size() > 2 else COL_TEXT_SECONDARY)
		grid.add_child(kl)
		var vl := Label.new()
		vl.text = item[1]
		vl.add_theme_font_size_override("font_size", 12)
		vl.add_theme_color_override("font_color", COL_TEXT_PRIMARY)
		vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(vl)
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.08)
	s.border_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.2)
	s.border_width_left = 2
	s.corner_radius_top_left = 4; s.corner_radius_bottom_left = 4
	s.content_margin_left = 16; s.content_margin_right = 16
	s.content_margin_top = 10; s.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", s)
	p.add_child(grid)
	_content_container.add_child(p)

func _dir(title: String, color: Color, points: Array) -> void:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, 0.08)
	s.border_color = Color(color.r, color.g, color.b, 0.4)
	s.border_width_left = 3
	s.corner_radius_top_left = 6; s.corner_radius_bottom_left = 6
	s.content_margin_left = 16; s.content_margin_right = 16
	s.content_margin_top = 12; s.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", s)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 14)
	tl.add_theme_color_override("font_color", color)
	vb.add_child(tl)
	for pt in points:
		var pl := Label.new()
		pl.text = "  · %s" % pt
		pl.add_theme_font_size_override("font_size", 12)
		pl.add_theme_color_override("font_color", COL_TEXT_PRIMARY)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(pl)
	p.add_child(vb)
	_content_container.add_child(p)

# ============================================================
# 页签切换
# ============================================================

func _on_tab_selected(idx: int) -> void:
	_current_tab = idx
	for i in range(_tab_bar.get_child_count()):
		var btn := _tab_bar.get_child(i) as Button
		if btn: btn.disabled = (i == idx)
	var tween := create_tween()
	tween.tween_property(_content_scroll, "modulate:a", 0.0, 0.15)
	tween.tween_callback(_fill_tab_content.bind(idx))
	tween.tween_property(_content_scroll, "modulate:a", 1.0, 0.15)

# ============================================================
# 首次引导 UI (§10.1)
# ============================================================

func _build_tutorial_ui() -> void:
	for child in get_children():
		child.queue_free()

	_tutorial_overlay = ColorRect.new()
	_tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial_overlay.color = Color(0, 0, 0, 0.7)
	add_child(_tutorial_overlay)

	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.set_anchor(SIDE_LEFT, 0.25)
	_tutorial_panel.set_anchor(SIDE_RIGHT, 0.75)
	_tutorial_panel.set_anchor(SIDE_BOTTOM, 1.0)
	_tutorial_panel.set_anchor(SIDE_TOP, 1.0)
	_tutorial_panel.offset_bottom = -60; _tutorial_panel.offset_top = -200
	_tutorial_panel.offset_left = 0; _tutorial_panel.offset_right = 0

	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(COL_PANEL_BG.r, COL_PANEL_BG.g, COL_PANEL_BG.b, 0.95)
	ps.border_color = COL_ACCENT
	for side in ["border_width_left","border_width_right","border_width_top","border_width_bottom"]:
		ps.set(side, 2)
	for corner in ["corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right"]:
		ps.set(corner, 10)
	ps.content_margin_left = 24; ps.content_margin_right = 24
	ps.content_margin_top = 20; ps.content_margin_bottom = 16
	_tutorial_panel.add_theme_stylebox_override("panel", ps)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	_tutorial_step_label = Label.new()
	_tutorial_step_label.add_theme_font_size_override("font_size", 11)
	_tutorial_step_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	_tutorial_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_tutorial_step_label)

	_tutorial_text = Label.new()
	_tutorial_text.add_theme_font_size_override("font_size", 15)
	_tutorial_text.add_theme_color_override("font_color", COL_TEXT_PRIMARY)
	_tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tutorial_text)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	_tutorial_skip_btn = Button.new()
	_tutorial_skip_btn.text = "跳过引导"
	_tutorial_skip_btn.custom_minimum_size = Vector2(100, 32)
	_tutorial_skip_btn.pressed.connect(_end_tutorial)
	_tutorial_skip_btn.add_theme_color_override("font_color", COL_TEXT_DIM)
	_tutorial_skip_btn.add_theme_font_size_override("font_size", 12)
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.1, 0.08, 0.15, 0.5)
	for c in ["corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right"]:
		ss.set(c, 4)
	ss.content_margin_left = 12; ss.content_margin_right = 12
	_tutorial_skip_btn.add_theme_stylebox_override("normal", ss)
	btn_hbox.add_child(_tutorial_skip_btn)

	_tutorial_next_btn = Button.new()
	_tutorial_next_btn.text = "下一步 →"
	_tutorial_next_btn.custom_minimum_size = Vector2(120, 36)
	_tutorial_next_btn.pressed.connect(_advance_tutorial)
	_tutorial_next_btn.add_theme_color_override("font_color", COL_TEXT_PRIMARY)
	_tutorial_next_btn.add_theme_font_size_override("font_size", 13)
	var ns := StyleBoxFlat.new()
	ns.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.3)
	ns.border_color = COL_ACCENT
	for side in ["border_width_left","border_width_right","border_width_top","border_width_bottom"]:
		ns.set(side, 1)
	for c in ["corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right"]:
		ns.set(c, 6)
	ns.content_margin_left = 16; ns.content_margin_right = 16
	_tutorial_next_btn.add_theme_stylebox_override("normal", ns)
	btn_hbox.add_child(_tutorial_next_btn)

	vbox.add_child(btn_hbox)
	_tutorial_panel.add_child(vbox)
	add_child(_tutorial_panel)

func _show_tutorial_step(step: int) -> void:
	if step >= TUTORIAL_STEPS.size():
		_end_tutorial()
		return
	_tutorial_step = step
	var step_data := TUTORIAL_STEPS[step] as Dictionary
	_tutorial_text.text = step_data["text"]
	_tutorial_step_label.text = "步骤 %d / %d" % [step + 1, TUTORIAL_STEPS.size()]
	if step == TUTORIAL_STEPS.size() - 1:
		_tutorial_next_btn.text = "开始游戏 ✦"
		_tutorial_skip_btn.visible = false
	else:
		_tutorial_next_btn.text = "下一步 →"
		_tutorial_skip_btn.visible = true
	_tutorial_text.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_tutorial_text, "modulate:a", 1.0, 0.2)
	tutorial_step_advanced.emit(step)

func _advance_tutorial() -> void:
	_show_tutorial_step(_tutorial_step + 1)

func _end_tutorial() -> void:
	_tutorial_active = false
	tutorial_completed.emit()
	var tween := create_tween()
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		tween.tween_property(_tutorial_overlay, "modulate:a", 0.0, 0.3)
	if _tutorial_panel and is_instance_valid(_tutorial_panel):
		tween.parallel().tween_property(_tutorial_panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		for child in get_children():
			child.queue_free()
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	)

# ============================================================
# 动画
# ============================================================

func _play_show_animation() -> void:
	if not _overlay or not _panel: return
	_overlay.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.9, 0.9)
	_panel.pivot_offset = _panel.size / 2.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.4)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _play_hide_animation() -> void:
	var tween := create_tween().set_parallel(true)
	if _overlay:
		tween.tween_property(_overlay, "modulate:a", 0.0, 0.3)
	if _panel:
		tween.tween_property(_panel, "modulate:a", 0.0, 0.3)
		tween.tween_property(_panel, "scale", Vector2(0.9, 0.9), 0.3)\
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_callback(func():
		_help_visible = false
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for child in get_children():
			child.queue_free()
		panel_closed.emit()
	)

func _on_overlay_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_panel()

# ============================================================
# 静态辅助 — 创建帮助按钮 (§10.2)
# ============================================================

static func create_help_button(callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = "?"
	btn.custom_minimum_size = Vector2(40, 40)
	btn.pressed.connect(callback)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.06, 0.15, 0.8)
	s.border_color = Color("#9D6FFF")
	for side in ["border_width_left","border_width_right","border_width_top","border_width_bottom"]:
		s.set(side, 1)
	for c in ["corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right"]:
		s.set(c, 20)
	btn.add_theme_stylebox_override("normal", s)
	var hs := s.duplicate()
	hs.bg_color = Color(0.15, 0.1, 0.25, 0.9)
	hs.border_color = Color("#FFD700")
	btn.add_theme_stylebox_override("hover", hs)
	btn.add_theme_color_override("font_color", Color("#A098C8"))
	btn.add_theme_color_override("font_hover_color", Color("#FFD700"))
	btn.add_theme_font_size_override("font_size", 18)
	return btn
