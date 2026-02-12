## game_mechanics_panel.gd
## 游戏机制状态面板 + 帮助面板 — v6.0 重写
##
## 本文件合并两大功能：
##   A) 机制状态面板 — HUD 右上角实时数值条（不和谐度、疲劳、密度、护盾等）
##   B) 帮助面板 — 根据 UI_Design_Module4_CircleOfFifths.md §10 设计的机制说明系统
##
## 帮助面板功能 (§10)：
##   - 首次引导 (First-Time Tutorial)：步骤式高亮引导序列 (§10.1)
##   - 帮助面板 (Help Panel)：图文结合的机制说明 (§10.2)
##   - 升级界面右下角 "?" 按钮触发
##   - 占屏幕 60%，星空紫背景 + 谐振紫边框
##   - 多页签式内容：五度圈基础、三个方向、金色标识、乐理突破
##
## 机制状态面板功能（保留原有）：
##   1. 不和谐度 (Dissonance) — 当前和弦的不和谐值
##   2. 听感疲劳 (Fatigue/AFI) — 综合疲劳指数
##   3. 密度过载 (Density Overload) — 施法密度
##   4. 单音寂静 (Note Silence) — 被禁用的音符状态
##   5. 暴击率 (Blues Crit) — 布鲁斯调式专用
##   6. 护盾值 (Shield) — 护盾法阵提供的护盾
extends Control

# ============================================================
# 信号
# ============================================================
signal help_panel_closed()
signal tutorial_completed()
signal tutorial_step_advanced(step: int)

# ============================================================
# HUD 状态面板布局 — @export 支持编辑器实时调整
# ============================================================
@export_group("HUD Layout")
@export var panel_width: float = 220.0
@export var bar_width: float = 160.0
@export var bar_height: float = 10.0
@export var bar_gap: float = 6.0
@export var label_width: float = 50.0
@export var panel_padding: float = 8.0

# ============================================================
# 常量 — 颜色方案 (与 §1.2 对齐)
# ============================================================

## HUD 状态面板颜色
const TITLE_COLOR := UIColors.with_alpha(UIColors.TEXT_HINT, 0.9)

## 不和谐度颜色渐变
const DISSONANCE_LOW_COLOR := UIColors.DISSONANCE_LOW
const DISSONANCE_MID_COLOR := UIColors.DISSONANCE_MID
const DISSONANCE_HIGH_COLOR := UIColors.DISSONANCE_HIGH

## 疲劳等级颜色
const FATIGUE_COLORS := {
	0: UIColors.SUCCESS,
	1: UIColors.OVERLOAD_COLORS[1],
	2: UIColors.OVERLOAD_COLORS[2],
	3: UIColors.OVERLOAD_COLORS[3],
	4: UIColors.OVERLOAD_COLORS[4],
}

## 密度过载颜色
const DENSITY_SAFE_COLOR := UIColors.DENSITY_SAFE

const DENSITY_OVERLOAD_COLOR := UIColors.DENSITY_OVERLOAD

## 护盾/暴击颜色
const SHIELD_COLOR := UIColors.with_alpha(UIColors.DENSITY_SAFE, 0.8)
const CRIT_COLOR := UIColors.WARNING

## 帮助面板颜色 (§1.2)

# ============================================================
# 帮助面板页签配置
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
# HUD 状态面板 — 内部状态
# ============================================================

## 不和谐度
var _dissonance_value: float = 0.0
var _display_dissonance: float = 0.0
var _last_dissonance_time: float = 0.0
var _dissonance_flash: float = 0.0

## 听感疲劳
var _fatigue_afi: float = 0.0
var _display_fatigue: float = 0.0
var _fatigue_level: int = 0
var _fatigue_penalty: float = 1.0

## 密度过载
var _density_ratio: float = 0.0
var _display_density: float = 0.0
var _is_overloaded: bool = false
var _accuracy_penalty: float = 0.0
var _overload_flash: float = 0.0

## 单音寂静
var _silenced_notes: Array = []

## 暴击率
var _crit_chance: float = 0.0
var _show_crit: bool = false

## 护盾值
var _shield_ratio: float = 0.0
var _display_shield: float = 0.0

## 动画时间
var _time: float = 0.0

## 面板折叠状态
var _is_collapsed: bool = false
var _collapse_progress: float = 1.0

# ============================================================
# 帮助面板 — 内部状态
# ============================================================
var _help_visible: bool = false
var _help_current_tab: int = 0
var _help_overlay: ColorRect = null
var _help_panel: PanelContainer = null
var _help_tab_bar: HBoxContainer = null
var _help_content_container: VBoxContainer = null
var _help_content_scroll: ScrollContainer = null

## 首次引导
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
	mouse_filter = Control.MOUSE_FILTER_PASS
	z_index = 20

	# 连接信号
	FatigueManager.fatigue_updated.connect(_on_fatigue_updated)
	FatigueManager.fatigue_level_changed.connect(_on_fatigue_level_changed)
	FatigueManager.density_overload_changed.connect(_on_density_overload_changed)
	FatigueManager.note_silenced.connect(_on_note_silenced)
	FatigueManager.note_unsilenced.connect(_on_note_unsilenced)

	GameManager.player_hp_changed.connect(_on_hp_changed)

	if SpellcraftSystem.has_signal("chord_cast"):
		SpellcraftSystem.chord_cast.connect(_on_chord_cast)

	if ModeSystem.has_signal("mode_changed"):
		ModeSystem.mode_changed.connect(_on_mode_changed)
	if ModeSystem.has_signal("crit_from_dissonance"):
		ModeSystem.crit_from_dissonance.connect(_on_crit_updated)

	_show_crit = (ModeSystem.current_mode_id == "blues")

func _process(delta: float) -> void:
	_time += delta

	# 平滑过渡
	_display_dissonance = lerp(_display_dissonance, _dissonance_value, delta * 6.0)
	_display_fatigue = lerp(_display_fatigue, _fatigue_afi, delta * 5.0)
	_display_density = lerp(_display_density, _density_ratio, delta * 8.0)
	_display_shield = lerp(_display_shield, _shield_ratio, delta * 6.0)

	# 不和谐度自然衰减
	if GameManager.game_time - _last_dissonance_time > 2.0:
		_dissonance_value = max(0.0, _dissonance_value - delta * 2.0)

	# 闪烁衰减
	_dissonance_flash = max(0.0, _dissonance_flash - delta * 4.0)
	_overload_flash = max(0.0, _overload_flash - delta * 3.0)

	# 折叠动画
	if _is_collapsed:
		_collapse_progress = max(0.0, _collapse_progress - delta * 5.0)
	else:
		_collapse_progress = min(1.0, _collapse_progress + delta * 5.0)

	_update_density_from_manager()
	_update_shield()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.y < 20:
			_is_collapsed = not _is_collapsed

func _unhandled_input(event: InputEvent) -> void:
	if not _help_visible and not _tutorial_active:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _tutorial_active:
				_end_tutorial()
			else:
				hide_help_panel()
			get_viewport().set_input_as_handled()

# ============================================================
# 绘制 — HUD 状态面板
# ============================================================

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var y := panel_padding
	var x := panel_padding

	var content_height := _calculate_content_height()
	var panel_height := panel_padding * 2 + 16 + content_height * _collapse_progress

	# 面板背景
	var panel_rect := Rect2(Vector2.ZERO, Vector2(PANEL_WIDTH, panel_height))
	draw_rect(panel_rect, UIColors.PRIMARY_BG)
	draw_rect(panel_rect, UIColors.BORDER_DEFAULT, false, 1.0)

	# 标题栏
	var collapse_icon := "▼" if not _is_collapsed else "▶"
	draw_string(font, Vector2(x, y + 11), collapse_icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, TITLE_COLOR)
	draw_string(font, Vector2(x + 14, y + 11), "MECHANICS STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, TITLE_COLOR)
	y += 16

	if _collapse_progress < 0.05:
		return

	var content_alpha := _collapse_progress

	# 1. 不和谐度
	y += 2
	_draw_bar_section(font, x, y, "DISSONANCE", _display_dissonance / 10.0,
		_get_dissonance_color(_display_dissonance),
		"%.1f" % _display_dissonance, content_alpha)
	if _dissonance_flash > 0:
		var flash_rect := Rect2(Vector2(x + LABEL_WIDTH, y + 1), Vector2(BAR_WIDTH, BAR_HEIGHT))
		draw_rect(flash_rect, UIColors.with_alpha(UIColors.DANGER, _dissonance_flash * 0.3))
	y += BAR_HEIGHT + BAR_GAP

	# 2. 听感疲劳
	var fatigue_color: Color = FATIGUE_COLORS.get(_fatigue_level, FATIGUE_COLORS[0])
	var fatigue_level_names := ["CLEAR", "MILD", "MODERATE", "SEVERE", "CRITICAL"]
	var level_name: String = fatigue_level_names[clampi(_fatigue_level, 0, 4)]
	_draw_bar_section(font, x, y, "FATIGUE", _display_fatigue,
		fatigue_color, "%d%% [%s]" % [int(_display_fatigue * 100), level_name], content_alpha)
	if _fatigue_level >= 3:
		var flash_alpha := sin(_time * 5.0) * 0.15 + 0.15
		var flash_rect := Rect2(Vector2(x + LABEL_WIDTH, y + 1), Vector2(BAR_WIDTH * _display_fatigue, BAR_HEIGHT))
		draw_rect(flash_rect, UIColors.with_alpha(UIColors.DANGER, flash_alpha * content_alpha))
	if _fatigue_penalty < 0.99:
		var penalty_text := "DMG ×%.0f%%" % (_fatigue_penalty * 100)
		draw_string(font, Vector2(x + LABEL_WIDTH + BAR_WIDTH + 5, y + BAR_HEIGHT), penalty_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UIColors.with_alpha(UIColors.DANGER, 0.8 * content_alpha))
	y += BAR_HEIGHT + BAR_GAP

	# 3. 密度过载
	var density_color := DENSITY_SAFE_COLOR
	var density_label := "%.0f%%" % (_display_density * 100)
	if _is_overloaded:
		density_color = DENSITY_OVERLOAD_COLOR
		density_label += " OVERLOAD"
	elif _display_density > 0.7:
		density_color = UIColors.DENSITY_WARN
		density_label += " WARN"
	_draw_bar_section(font, x, y, "DENSITY", _display_density,
		density_color, density_label, content_alpha)
	if _overload_flash > 0:
		var flash_rect := Rect2(Vector2(x + LABEL_WIDTH, y + 1), Vector2(BAR_WIDTH, BAR_HEIGHT))
		draw_rect(flash_rect, UIColors.with_alpha(UIColors.DENSITY_OVERLOAD, _overload_flash * 0.4 * content_alpha))
	if _accuracy_penalty > 0.01:
		draw_string(font, Vector2(x + label_width + bar_width + 5, y + bar_height),
			"Accuracy -%.0f%%" % (_accuracy_penalty * 100),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UIColors.with_alpha(UIColors.DANGER, 0.8 * content_alpha))
	y += BAR_HEIGHT + BAR_GAP

	# 4. 护盾值
	if GameManager.max_shield_hp > 0:
		_draw_bar_section(font, x, y, "SHIELD", _display_shield,
			SHIELD_COLOR, "%d/%d" % [int(GameManager.shield_hp), int(GameManager.max_shield_hp)], content_alpha)
		y += bar_height + bar_gap

	# 5. 暴击率
	if _show_crit:
		var crit_ratio := clampf(_crit_chance / 0.3, 0.0, 1.0)
		_draw_bar_section(font, x, y, "CRIT", crit_ratio,
			CRIT_COLOR, "%.0f%%" % (_crit_chance * 100), content_alpha)
		y += bar_height + bar_gap

	# 6. 单音寂静
	if not _silenced_notes.is_empty():
		y += 2
		draw_string(font, Vector2(x, y + 9), "SILENCED:", HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			UIColors.with_alpha(UIColors.with_alpha(UIColors.TEXT_HINT, 0.8), content_alpha))
		var note_x := x + LABEL_WIDTH
		for entry in _silenced_notes:
			if entry is Dictionary:
				var note_key: int = entry.get("note", -1)
				var remaining: float = entry.get("remaining", 0.0)
				var note_name: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
				var note_alpha := 0.5 + sin(_time * 4.0) * 0.3
				draw_string(font, Vector2(note_x, y + 9), note_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
					UIColors.with_alpha(UIColors.DANGER, note_alpha * content_alpha))
				var timer_ratio := clampf(remaining / 5.0, 0.0, 1.0)
				draw_rect(Rect2(Vector2(note_x, y + 12), Vector2(20.0 * timer_ratio, 2)),
					UIColors.with_alpha(UIColors.DANGER, 0.6 * content_alpha))
				note_x += 30

# ============================================================
# 数值条绘制辅助
# ============================================================

func _draw_bar_section(font: Font, x: float, y: float, label: String,
		ratio: float, bar_color: Color, value_text: String, alpha: float) -> void:
	draw_string(font, Vector2(x, y + BAR_HEIGHT - 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		UIColors.with_alpha(UIColors.with_alpha(UIColors.TEXT_HINT, 0.8), alpha))

	var bar_x := x + LABEL_WIDTH
	draw_rect(Rect2(Vector2(bar_x, y + 1), Vector2(BAR_WIDTH, BAR_HEIGHT)),
		UIColors.with_alpha(UIColors.PANEL_DARK, 0.5 * alpha))

	var fill_ratio := clampf(ratio, 0.0, 1.0)
	if fill_ratio > 0.001:
		draw_rect(Rect2(Vector2(bar_x, y + 1), Vector2(BAR_WIDTH * fill_ratio, BAR_HEIGHT)),
			UIColors.with_alpha(bar_color, bar_color.a * alpha))
		var glow_x := bar_x + BAR_WIDTH * fill_ratio - 2
		if glow_x > bar_x:
			draw_rect(Rect2(Vector2(glow_x, y + 1), Vector2(3, BAR_HEIGHT)),
				UIColors.with_alpha(bar_color, 0.3 * alpha))

	# 疲劳阈值标记线
	if label == "FATIGUE":
		for threshold_level in FatigueManager.thresholds:
			var threshold: float = FatigueManager.thresholds[threshold_level]
			draw_line(Vector2(bar_x + BAR_WIDTH * threshold, y + 1),
				Vector2(bar_x + BAR_WIDTH * threshold, y + 1 + BAR_HEIGHT),
				UIColors.with_alpha(Color.WHITE, 0.2 * alpha), 1.0)

	draw_string(font, Vector2(bar_x + bar_width + 4, y + bar_height - 1), value_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
		UIColors.with_alpha(UIColors.with_alpha(UIColors.TEXT_PRIMARY, 0.9), alpha))

func _get_dissonance_color(value: float) -> Color:
	if value <= 2.0:
		return DISSONANCE_LOW_COLOR
	elif value <= 5.0:
		return DISSONANCE_LOW_COLOR.lerp(DISSONANCE_MID_COLOR, (value - 2.0) / 3.0)
	else:
		return DISSONANCE_MID_COLOR.lerp(DISSONANCE_HIGH_COLOR, clampf((value - 5.0) / 5.0, 0.0, 1.0))

func _calculate_content_height() -> float:
	var height := bar_height + bar_gap + 2  # 不和谐度
	height += bar_height + bar_gap           # 疲劳
	height += bar_height + bar_gap           # 密度
	if GameManager.max_shield_hp > 0:
		height += bar_height + bar_gap
	if _show_crit:
		height += bar_height + bar_gap
	if not _silenced_notes.is_empty():
		height += 20
	return height

# ============================================================
# 数据更新
# ============================================================

func _update_density_from_manager() -> void:
	_is_overloaded = FatigueManager.is_density_overloaded
	_accuracy_penalty = FatigueManager.current_accuracy_penalty
	var current_time := GameManager.game_time
	var recent_count := 0
	for event in FatigueManager._event_history:
		if current_time - event.get("time", 0.0) < FatigueManager.DENSITY_OVERLOAD_WINDOW:
			recent_count += 1
	var beat_rate := GameManager.current_bpm / 60.0
	var dynamic_threshold: int = int(max(float(FatigueManager.DENSITY_OVERLOAD_THRESHOLD),
		beat_rate * FatigueManager.DENSITY_OVERLOAD_WINDOW * 1.2))
	_density_ratio = clampf(float(recent_count) / float(dynamic_threshold), 0.0, 1.0)

func _update_shield() -> void:
	if GameManager.max_shield_hp > 0:
		_shield_ratio = GameManager.shield_hp / GameManager.max_shield_hp
	else:
		_shield_ratio = 0.0

# ============================================================
# HUD 信号回调
# ============================================================

func _on_fatigue_updated(result: Dictionary) -> void:
	_fatigue_afi = result.get("afi", 0.0)
	_fatigue_penalty = result.get("penalty", {}).get("damage_multiplier", 1.0)
	_silenced_notes = result.get("silenced_notes", [])

func _on_fatigue_level_changed(level: MusicData.FatigueLevel) -> void:
	_fatigue_level = int(level)

func _on_density_overload_changed(is_overloaded: bool, accuracy_penalty: float) -> void:
	_is_overloaded = is_overloaded
	_accuracy_penalty = accuracy_penalty
	if is_overloaded:
		_overload_flash = 1.0

func _on_note_silenced(_note: MusicData.WhiteKey, _duration: float) -> void:
	pass

func _on_note_unsilenced(_note: MusicData.WhiteKey) -> void:
	pass

func _on_hp_changed(_current_hp: float, _max_hp: float) -> void:
	pass

func _on_chord_cast(chord_data: Dictionary) -> void:
	var dissonance: float = chord_data.get("dissonance", 0.0)
	if dissonance > 0:
		_dissonance_value = dissonance
		_last_dissonance_time = GameManager.game_time
		if dissonance > 2.0:
			_dissonance_flash = 1.0

func _on_mode_changed(_mode_id: String) -> void:
	_show_crit = (ModeSystem.current_mode_id == "blues")
	if not _show_crit:
		_crit_chance = 0.0

func _on_crit_updated(crit_chance: float) -> void:
	_crit_chance = crit_chance

# ============================================================
# ============================================================
# 帮助面板系统 (§10)
# ============================================================
# ============================================================

# ============================================================
# 帮助面板 — 公共接口
# ============================================================

## 显示帮助面板 (§10.2)
func show_help_panel() -> void:
	if _help_visible:
		return
	_help_visible = true
	_build_help_panel()
	_play_help_show_animation()

## 隐藏帮助面板
func hide_help_panel() -> void:
	if not _help_visible:
		return
	_play_help_hide_animation()

## 切换帮助面板
func toggle_help_panel() -> void:
	if _help_visible:
		hide_help_panel()
	else:
		show_help_panel()

## 开始首次引导序列 (§10.1)
func start_tutorial() -> void:
	if _tutorial_active:
		return
	_tutorial_active = true
	_tutorial_step = 0
	_build_tutorial_ui()
	_show_tutorial_step(0)

## 结束引导
func end_tutorial() -> void:
	_end_tutorial()

# ============================================================
# 帮助面板 — 构建 (§10.2)
# ============================================================

func _build_help_panel() -> void:
	# 全屏暗色遮罩
	_help_overlay = ColorRect.new()
	_help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.color = UIColors.PRIMARY_BG
	_help_overlay.gui_input.connect(_on_help_overlay_clicked)
	_help_overlay.z_index = 100
	add_child(_help_overlay)

	# 主面板 — 占屏幕 60%
	_help_panel = PanelContainer.new()
	_help_panel.set_anchor(SIDE_LEFT, 0.2)
	_help_panel.set_anchor(SIDE_RIGHT, 0.8)
	_help_panel.set_anchor(SIDE_TOP, 0.15)
	_help_panel.set_anchor(SIDE_BOTTOM, 0.85)
	_help_panel.offset_left = 0
	_help_panel.offset_right = 0
	_help_panel.offset_top = 0
	_help_panel.offset_bottom = 0
	_help_panel.z_index = 101

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UIColors.PANEL_BG
	panel_style.border_color = UIColors.ACCENT
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	panel_style.shadow_color = UIColors.with_alpha(UIColors.ACCENT, 0.15)
	panel_style.shadow_size = 8
	_help_panel.add_theme_stylebox_override("panel", panel_style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)

	# 标题栏
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)

	var title_label := Label.new()
	title_label.text = "✦ 机制说明 — 五度圈罗盘 ✦"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", UIColors.GOLD)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(hide_help_panel)
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = UIColors.with_alpha(UIColors.DANGER, 0.3)
	close_style.corner_radius_top_left = 4
	close_style.corner_radius_top_right = 4
	close_style.corner_radius_bottom_left = 4
	close_style.corner_radius_bottom_right = 4
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	close_btn.add_theme_color_override("font_hover_color", Color.RED)
	header.add_child(close_btn)

	main_vbox.add_child(header)

	# 分割线
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = UIColors.with_alpha(UIColors.ACCENT, 0.4)
	main_vbox.add_child(sep)

	# 页签栏
	_help_tab_bar = HBoxContainer.new()
	_help_tab_bar.add_theme_constant_override("separation", 8)
	_help_tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER

	for i in range(TAB_CONFIG.size()):
		var tab := TAB_CONFIG[i] as Dictionary
		var btn := Button.new()
		btn.text = "%s %s" % [tab["icon"], tab["title"]]
		btn.custom_minimum_size = Vector2(120, 32)
		btn.pressed.connect(_on_help_tab_selected.bind(i))

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = UIColors.with_alpha(UIColors.ACCENT, 0.1)
		btn_style.border_color = UIColors.with_alpha(UIColors.ACCENT, 0.3)
		btn_style.border_width_bottom = 1
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_top_right = 4
		btn_style.content_margin_left = 8
		btn_style.content_margin_right = 8
		btn.add_theme_stylebox_override("normal", btn_style)

		var btn_active := btn_style.duplicate()
		btn_active.bg_color = UIColors.with_alpha(UIColors.ACCENT, 0.25)
		btn_active.border_color = UIColors.ACCENT
		btn_active.border_width_bottom = 2
		btn.add_theme_stylebox_override("disabled", btn_active)

		btn.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
		btn.add_theme_color_override("font_disabled_color", UIColors.ACCENT)
		btn.add_theme_font_size_override("font_size", 12)
		btn.disabled = (i == _help_current_tab)
		_help_tab_bar.add_child(btn)

	main_vbox.add_child(_help_tab_bar)

	# 内容区域
	_help_content_scroll = ScrollContainer.new()
	_help_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_help_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_help_content_container = VBoxContainer.new()
	_help_content_container.add_theme_constant_override("separation", 12)
	_help_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help_content_scroll.add_child(_help_content_container)

	main_vbox.add_child(_help_content_scroll)
	_help_panel.add_child(main_vbox)
	add_child(_help_panel)

	_fill_help_tab_content(_help_current_tab)

# ============================================================
# 帮助面板 — 页签内容
# ============================================================

func _fill_help_tab_content(tab_idx: int) -> void:
	for child in _help_content_container.get_children():
		child.queue_free()

	match tab_idx:
		0: _fill_circle_of_fifths_content()
		1: _fill_three_directions_content()
		2: _fill_gold_badge_content()
		3: _fill_theory_breakthrough_content()

func _fill_circle_of_fifths_content() -> void:
	_add_help_section_title("五度圈 (Circle of Fifths)")
	_add_help_paragraph(
		"五度圈是音乐理论中最重要的概念之一，它描述了 12 个音级之间的和谐关系。" +
		"在《Project Harmony》中，五度圈被具象化为一个古代星盘——你的升级罗盘。")
	_add_help_kv_block([
		["顺时针方向", "升号方向 (♯)，音色更明亮、锐利", UIColors.OFFENSE],
		["逆时针方向", "降号方向 (♭)，音色更柔和、温暖", UIColors.DEFENSE],
		["中心位置", "当前调性的稳定核心", UIColors.ACCENT],
	])
	_add_help_paragraph(
		"每次升级时，罗盘会激活。你需要先选择一个方向（进攻/防御/核心），" +
		"然后从该方向提供的 2-3 张升级卡片中选择一张。")
	_add_help_section_title("音级与调性")
	_add_help_paragraph(
		"罗盘外圈展示 12 个大调音级（C, G, D, A, E, B, F♯/G♭, D♭, A♭, E♭, B♭, F），" +
		"按照五度关系排列。当前调性会以高亮标记，相邻音级代表和谐度最高的调性。")

func _fill_three_directions_content() -> void:
	_add_help_section_title("三个升级方向")
	_add_help_direction_block("进攻方向 (♯ 升号)", UIColors.OFFENSE, [
		"提升伤害、攻击速度、弹体效果",
		"对应五度圈顺时针方向",
		"适合追求高输出的玩法风格",
		"升级类型：伤害加成、穿透、暴击、范围扩大",
	])
	_add_help_direction_block("防御方向 (♭ 降号)", UIColors.DEFENSE, [
		"提升生存能力、护盾、回复",
		"对应五度圈逆时针方向",
		"适合追求稳健生存的玩法风格",
		"升级类型：护盾、生命回复、减伤、控制效果",
	])
	_add_help_direction_block("核心方向 (♮ 还原号)", UIColors.ACCENT, [
		"提升基础能力、解锁新机制",
		"对应五度圈中心位置",
		"适合追求全面发展的玩法风格",
		"升级类型：经验加成、冷却缩减、新法术形态、乐理突破",
	])

func _fill_gold_badge_content() -> void:
	_add_help_section_title("金色标识 — 局外解锁")
	_add_help_paragraph(
		"带有金色边框和 ★ 标识的升级卡片，代表它来自「和谐殿堂」的局外解锁系统。" +
		"这些升级是你在多次游戏中积累的永久成长成果。")
	_add_help_kv_block([
		["金色边框", "该升级通过局外成长系统解锁", UIColors.GOLD],
		["★ 徽章", "标记此升级为局外解锁来源", UIColors.GOLD],
		["出现条件", "需要在和谐殿堂中先解锁对应节点", UIColors.TEXT_SECONDARY],
	])
	_add_help_paragraph(
		"局外解锁的升级不会替代普通升级池，而是作为额外选项出现。" +
		"它们通常比同稀有度的普通升级更强，代表了你作为谐振者的成长。")

func _fill_theory_breakthrough_content() -> void:
	_add_help_section_title("乐理突破 — 特殊事件")
	_add_help_paragraph(
		"「乐理突破」是一种稀有的特殊升级事件，当你在五度圈上达到特定条件时触发。" +
		"它会直接解锁核心游戏机制，如新的和弦类型、调式切换、节奏型等。")
	_add_help_kv_block([
		["触发条件", "在特定音级组合上积累足够升级", UIColors.ACCENT],
		["视觉表现", "金色全屏闪光 + 几何图案粒子效果", UIColors.GOLD],
		["效果", "永久解锁新的游戏机制", UIColors.GOLD],
	])
	_add_help_paragraph(
		"乐理突破事件的 UI 表现具有强烈的仪式感：罗盘会剧烈旋转，" +
		"中心星云爆发金色光芒，随后展示一张传说级卡片。" +
		"这代表着你在音乐理论上的「顿悟」时刻。")
	_add_help_section_title("突破类型示例")
	_add_help_kv_block([
		["和弦解锁", "解锁新的和弦组合方式", UIColors.ACCENT],
		["调式切换", "获得在战斗中切换调式的能力", UIColors.ACCENT],
		["节奏进化", "解锁更复杂的节奏型", UIColors.ACCENT],
		["音色融合", "解锁音色混合技术", UIColors.ACCENT],
	])

# ============================================================
# 帮助面板 — 内容辅助函数
# ============================================================

func _add_help_section_title(text: String) -> void:
	var label := Label.new()
	label.text = "— %s —" % text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UIColors.ACCENT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help_content_container.add_child(label)

func _add_help_paragraph(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_content_container.add_child(label)

func _add_help_kv_block(items: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)

	for item in items:
		var key_label := Label.new()
		key_label.text = item[0]
		key_label.add_theme_font_size_override("font_size", 12)
		key_label.add_theme_color_override("font_color", item[2] if item.size() > 2 else UIColors.TEXT_SECONDARY)
		key_label.custom_minimum_size.x = 120
		grid.add_child(key_label)

		var val_label := Label.new()
		val_label.text = item[1]
		val_label.add_theme_font_size_override("font_size", 12)
		val_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
		val_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(val_label)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.with_alpha(UIColors.ACCENT, 0.08)
	style.border_color = UIColors.with_alpha(UIColors.ACCENT, 0.2)
	style.border_width_left = 2
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(grid)
	_help_content_container.add_child(panel)

func _add_help_direction_block(title: String, color: Color, points: Array) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.with_alpha(color, 0.08)
	style.border_color = UIColors.with_alpha(color, 0.4)
	style.border_width_left = 3
	style.corner_radius_top_left = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", color)
	vbox.add_child(title_label)

	for point in points:
		var point_label := Label.new()
		point_label.text = "  · %s" % point
		point_label.add_theme_font_size_override("font_size", 12)
		point_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
		point_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(point_label)

	panel.add_child(vbox)
	_help_content_container.add_child(panel)

# ============================================================
# 帮助面板 — 页签切换
# ============================================================

func _on_help_tab_selected(idx: int) -> void:
	_help_current_tab = idx
	for i in range(_help_tab_bar.get_child_count()):
		var btn := _help_tab_bar.get_child(i) as Button
		if btn:
			btn.disabled = (i == idx)

	var tween := create_tween()
	tween.tween_property(_help_content_scroll, "modulate:a", 0.0, 0.15)
	tween.tween_callback(_fill_help_tab_content.bind(idx))
	tween.tween_property(_help_content_scroll, "modulate:a", 1.0, 0.15)

# ============================================================
# 帮助面板 — 动画
# ============================================================

func _play_help_show_animation() -> void:
	if not _help_overlay or not _help_panel:
		return
	_help_overlay.modulate.a = 0.0
	_help_panel.modulate.a = 0.0
	_help_panel.scale = Vector2(0.9, 0.9)
	_help_panel.pivot_offset = _help_panel.size / 2.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_help_overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(_help_panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(_help_panel, "scale", Vector2(1.0, 1.0), 0.4)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _play_help_hide_animation() -> void:
	var tween := create_tween().set_parallel(true)
	if _help_overlay:
		tween.tween_property(_help_overlay, "modulate:a", 0.0, 0.3)
	if _help_panel:
		tween.tween_property(_help_panel, "modulate:a", 0.0, 0.3)
		tween.tween_property(_help_panel, "scale", Vector2(0.9, 0.9), 0.3)\
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	tween.chain().tween_callback(func():
		_help_visible = false
		if _help_overlay and is_instance_valid(_help_overlay):
			_help_overlay.queue_free()
			_help_overlay = null
		if _help_panel and is_instance_valid(_help_panel):
			_help_panel.queue_free()
			_help_panel = null
		help_panel_closed.emit()
	)

func _on_help_overlay_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_help_panel()

# ============================================================
# 首次引导 (§10.1)
# ============================================================

func _build_tutorial_ui() -> void:
	# 半透明暗色遮罩
	_tutorial_overlay = ColorRect.new()
	_tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial_overlay.color = UIColors.with_alpha(Color.BLACK, 0.7)
	_tutorial_overlay.z_index = 200
	add_child(_tutorial_overlay)

	# 引导文本面板
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.set_anchor(SIDE_LEFT, 0.25)
	_tutorial_panel.set_anchor(SIDE_RIGHT, 0.75)
	_tutorial_panel.set_anchor(SIDE_BOTTOM, 1.0)
	_tutorial_panel.set_anchor(SIDE_TOP, 1.0)
	_tutorial_panel.offset_bottom = -60
	_tutorial_panel.offset_top = -200
	_tutorial_panel.offset_left = 0
	_tutorial_panel.offset_right = 0
	_tutorial_panel.z_index = 201

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UIColors.with_alpha(UIColors.PANEL_BG, 0.95)
	panel_style.border_color = UIColors.ACCENT
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 16
	_tutorial_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	# 步骤指示器
	_tutorial_step_label = Label.new()
	_tutorial_step_label.add_theme_font_size_override("font_size", 11)
	_tutorial_step_label.add_theme_color_override("font_color", UIColors.TEXT_DIM)
	_tutorial_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_tutorial_step_label)

	# 引导文本
	_tutorial_text = Label.new()
	_tutorial_text.add_theme_font_size_override("font_size", 15)
	_tutorial_text.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	_tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tutorial_text)

	# 按钮栏
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	_tutorial_skip_btn = Button.new()
	_tutorial_skip_btn.text = "跳过引导"
	_tutorial_skip_btn.custom_minimum_size = Vector2(100, 32)
	_tutorial_skip_btn.pressed.connect(_end_tutorial)
	_tutorial_skip_btn.add_theme_color_override("font_color", UIColors.TEXT_DIM)
	_tutorial_skip_btn.add_theme_font_size_override("font_size", 12)
	var skip_style := StyleBoxFlat.new()
	skip_style.bg_color = UIColors.with_alpha(UIColors.PANEL_LIGHT, 0.5)
	skip_style.corner_radius_top_left = 4
	skip_style.corner_radius_top_right = 4
	skip_style.corner_radius_bottom_left = 4
	skip_style.corner_radius_bottom_right = 4
	skip_style.content_margin_left = 12
	skip_style.content_margin_right = 12
	_tutorial_skip_btn.add_theme_stylebox_override("normal", skip_style)
	btn_hbox.add_child(_tutorial_skip_btn)

	_tutorial_next_btn = Button.new()
	_tutorial_next_btn.text = "下一步 →"
	_tutorial_next_btn.custom_minimum_size = Vector2(120, 36)
	_tutorial_next_btn.pressed.connect(_advance_tutorial)
	_tutorial_next_btn.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	_tutorial_next_btn.add_theme_font_size_override("font_size", 13)
	var next_style := StyleBoxFlat.new()
	next_style.bg_color = UIColors.with_alpha(UIColors.ACCENT, 0.3)
	next_style.border_color = UIColors.ACCENT
	next_style.border_width_left = 1
	next_style.border_width_right = 1
	next_style.border_width_top = 1
	next_style.border_width_bottom = 1
	next_style.corner_radius_top_left = 6
	next_style.corner_radius_top_right = 6
	next_style.corner_radius_bottom_left = 6
	next_style.corner_radius_bottom_right = 6
	next_style.content_margin_left = 16
	next_style.content_margin_right = 16
	_tutorial_next_btn.add_theme_stylebox_override("normal", next_style)
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

	# 淡入动画
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
		if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
			_tutorial_overlay.queue_free()
			_tutorial_overlay = null
		if _tutorial_panel and is_instance_valid(_tutorial_panel):
			_tutorial_panel.queue_free()
			_tutorial_panel = null
	)

# ============================================================
# 静态辅助 — 创建帮助按钮 (§10.2 右下角 "?" 按钮)
# ============================================================

static func create_help_button(callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = "?"
	btn.custom_minimum_size = Vector2(40, 40)
	btn.pressed.connect(callback)

	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.with_alpha(UIColors.PANEL_BG, 0.8)
	style.border_color = UIColors.ACCENT
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = UIColors.with_alpha(UIColors.PANEL_LIGHTER, 0.9)
	hover_style.border_color = UIColors.GOLD
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	btn.add_theme_color_override("font_hover_color", UIColors.GOLD)
	btn.add_theme_font_size_override("font_size", 18)

	return btn
