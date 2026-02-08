## game_mechanics_panel.gd
## 游戏机制状态面板 (v1.0)
## 集中显示所有核心机制的数值条：
##   1. 不和谐度 (Dissonance) — 当前和弦的不和谐值，影响自伤
##   2. 听感疲劳 (Fatigue/AFI) — 综合疲劳指数，影响伤害输出
##   3. 密度过载 (Density Overload) — 施法密度，影响精准度
##   4. 单音寂静 (Note Silence) — 被禁用的音符状态
##   5. 暴击率 (Blues Crit) — 布鲁斯调式专用
##   6. 护盾值 (Shield) — 护盾法阵提供的护盾
##
## 位置：屏幕右上角，紧凑的垂直排列
extends Control

# ============================================================
# 配置
# ============================================================
const PANEL_WIDTH := 220.0
const BAR_WIDTH := 160.0
const BAR_HEIGHT := 10.0
const BAR_GAP := 6.0
const LABEL_WIDTH := 50.0
const SECTION_GAP := 10.0
const PANEL_PADDING := 8.0

## 颜色定义
const BG_COLOR := Color(0.04, 0.03, 0.08, 0.85)
const BORDER_COLOR := Color(0.25, 0.22, 0.38, 0.6)
const TITLE_COLOR := Color(0.55, 0.5, 0.7, 0.9)
const LABEL_COLOR := Color(0.5, 0.48, 0.6, 0.8)
const VALUE_COLOR := Color(0.75, 0.72, 0.88, 0.9)

## 不和谐度颜色渐变
const DISSONANCE_LOW_COLOR := Color(0.2, 0.7, 0.4)     # 绿色 - 低不和谐
const DISSONANCE_MID_COLOR := Color(1.0, 0.8, 0.0)     # 金色 - 中等不和谐
const DISSONANCE_HIGH_COLOR := Color(1.0, 0.2, 0.1)    # 红色 - 高不和谐

## 疲劳等级颜色
const FATIGUE_COLORS := {
	0: Color(0.0, 0.8, 0.4),    # NONE - 绿
	1: Color(0.7, 0.8, 0.0),    # MILD - 黄绿
	2: Color(1.0, 0.6, 0.0),    # MODERATE - 橙
	3: Color(1.0, 0.2, 0.0),    # SEVERE - 红
	4: Color(0.8, 0.0, 0.2),    # CRITICAL - 深红
}

## 密度过载颜色
const DENSITY_SAFE_COLOR := Color(0.3, 0.6, 1.0)
const DENSITY_WARN_COLOR := Color(1.0, 0.6, 0.0)
const DENSITY_OVERLOAD_COLOR := Color(1.0, 0.15, 0.1)

## 护盾颜色
const SHIELD_COLOR := Color(0.3, 0.7, 1.0, 0.8)

## 暴击率颜色
const CRIT_COLOR := Color(1.0, 0.6, 0.2)

# ============================================================
# 状态（平滑显示用）
# ============================================================

## 不和谐度
var _dissonance_value: float = 0.0        # 当前不和谐度 (0-10)
var _display_dissonance: float = 0.0      # 平滑显示值
var _last_dissonance_time: float = 0.0    # 上次不和谐度变化时间
var _dissonance_flash: float = 0.0        # 不和谐度闪烁

## 听感疲劳
var _fatigue_afi: float = 0.0             # 当前 AFI (0-1)
var _display_fatigue: float = 0.0         # 平滑显示值
var _fatigue_level: int = 0               # 当前疲劳等级 (0-4)
var _fatigue_penalty: float = 1.0         # 当前伤害惩罚倍率

## 密度过载
var _density_ratio: float = 0.0           # 当前密度比率 (0-1)
var _display_density: float = 0.0         # 平滑显示值
var _is_overloaded: bool = false          # 是否过载
var _accuracy_penalty: float = 0.0        # 精准度惩罚值
var _overload_flash: float = 0.0          # 过载闪烁

## 单音寂静
var _silenced_notes: Array = []           # 被寂静的音符列表

## 暴击率（布鲁斯调式）
var _crit_chance: float = 0.0
var _show_crit: bool = false

## 护盾值
var _shield_ratio: float = 0.0
var _display_shield: float = 0.0

## 动画时间
var _time: float = 0.0

## 面板折叠状态
var _is_collapsed: bool = false
var _collapse_progress: float = 1.0  # 1.0 = 展开, 0.0 = 折叠

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

	# 初始化调式检查
	_show_crit = (ModeSystem.current_mode_id == "blues")

func _process(delta: float) -> void:
	_time += delta

	# 平滑过渡
	_display_dissonance = lerp(_display_dissonance, _dissonance_value, delta * 6.0)
	_display_fatigue = lerp(_display_fatigue, _fatigue_afi, delta * 5.0)
	_display_density = lerp(_display_density, _density_ratio, delta * 8.0)
	_display_shield = lerp(_display_shield, _shield_ratio, delta * 6.0)

	# 不和谐度自然衰减（视觉上）
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

	# 持续从 FatigueManager 读取密度状态
	_update_density_from_manager()

	# 读取护盾值
	_update_shield()

	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	# 点击标题栏折叠/展开
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.y < 20:
			_is_collapsed = not _is_collapsed

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var y := PANEL_PADDING
	var x := PANEL_PADDING

	# 计算面板总高度
	var content_height := _calculate_content_height()
	var panel_height := PANEL_PADDING * 2 + 16 + content_height * _collapse_progress

	# 面板背景
	var panel_rect := Rect2(Vector2.ZERO, Vector2(PANEL_WIDTH, panel_height))
	draw_rect(panel_rect, BG_COLOR)
	draw_rect(panel_rect, BORDER_COLOR, false, 1.0)

	# 标题栏
	var collapse_icon := "▼" if not _is_collapsed else "▶"
	draw_string(font, Vector2(x, y + 11), collapse_icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, TITLE_COLOR)
	draw_string(font, Vector2(x + 14, y + 11), "MECHANICS STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, TITLE_COLOR)
	y += 16

	if _collapse_progress < 0.05:
		return

	# 设置裁剪（通过透明度模拟折叠效果）
	var content_alpha := _collapse_progress

	# ========== 1. 不和谐度 ==========
	y += 2
	_draw_bar_section(font, x, y, "DISSONANCE", _display_dissonance / 10.0,
		_get_dissonance_color(_display_dissonance),
		"%.1f" % _display_dissonance, content_alpha)

	# 不和谐度闪烁效果
	if _dissonance_flash > 0:
		var flash_rect := Rect2(Vector2(x + LABEL_WIDTH, y + 1), Vector2(BAR_WIDTH, BAR_HEIGHT))
		draw_rect(flash_rect, Color(1.0, 0.3, 0.1, _dissonance_flash * 0.3))
	y += BAR_HEIGHT + BAR_GAP

	# ========== 2. 听感疲劳 ==========
	var fatigue_color: Color = FATIGUE_COLORS.get(_fatigue_level, FATIGUE_COLORS[0])
	var fatigue_level_names := ["CLEAR", "MILD", "MODERATE", "SEVERE", "CRITICAL"]
	var level_name: String = fatigue_level_names[clampi(_fatigue_level, 0, 4)]
	_draw_bar_section(font, x, y, "FATIGUE", _display_fatigue,
		fatigue_color, "%d%% [%s]" % [int(_display_fatigue * 100), level_name], content_alpha)

	# 疲劳等级严重时闪烁
	if _fatigue_level >= 3:
		var flash_alpha := sin(_time * 5.0) * 0.15 + 0.15
		var flash_rect := Rect2(Vector2(x + LABEL_WIDTH, y + 1), Vector2(BAR_WIDTH * _display_fatigue, BAR_HEIGHT))
		draw_rect(flash_rect, Color(1.0, 0.0, 0.0, flash_alpha * content_alpha))

	# 伤害惩罚倍率显示
	if _fatigue_penalty < 0.99:
		var penalty_text := "DMG ×%.0f%%" % (_fatigue_penalty * 100)
		var penalty_color := Color(1.0, 0.4, 0.2, 0.8 * content_alpha)
		draw_string(font, Vector2(x + LABEL_WIDTH + BAR_WIDTH + 5, y + BAR_HEIGHT), penalty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, penalty_color)
	y += BAR_HEIGHT + BAR_GAP

	# ========== 3. 密度过载 ==========
	var density_color := DENSITY_SAFE_COLOR
	var density_label := "%.0f%%" % (_display_density * 100)
	if _is_overloaded:
		density_color = DENSITY_OVERLOAD_COLOR
		density_label += " OVERLOAD"
	elif _display_density > 0.7:
		density_color = DENSITY_WARN_COLOR
		density_label += " WARN"

	_draw_bar_section(font, x, y, "DENSITY", _display_density,
		density_color, density_label, content_alpha)

	# 过载闪烁
	if _overload_flash > 0:
		var flash_rect := Rect2(Vector2(x + LABEL_WIDTH, y + 1), Vector2(BAR_WIDTH, BAR_HEIGHT))
		draw_rect(flash_rect, Color(1.0, 0.15, 0.1, _overload_flash * 0.4 * content_alpha))

	# 精准度惩罚显示
	if _accuracy_penalty > 0.01:
		var acc_text := "Accuracy -%.0f%%" % (_accuracy_penalty * 100)
		var acc_color := Color(1.0, 0.3, 0.1, 0.8 * content_alpha)
		draw_string(font, Vector2(x + LABEL_WIDTH + BAR_WIDTH + 5, y + BAR_HEIGHT), acc_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, acc_color)
	y += BAR_HEIGHT + BAR_GAP

	# ========== 4. 护盾值 ==========
	if GameManager.max_shield_hp > 0:
		_draw_bar_section(font, x, y, "SHIELD", _display_shield,
			SHIELD_COLOR, "%d/%d" % [int(GameManager.shield_hp), int(GameManager.max_shield_hp)], content_alpha)
		y += BAR_HEIGHT + BAR_GAP

	# ========== 5. 暴击率（布鲁斯调式）==========
	if _show_crit:
		var crit_ratio := clampf(_crit_chance / 0.3, 0.0, 1.0)  # 最大30%暴击
		_draw_bar_section(font, x, y, "CRIT", crit_ratio,
			CRIT_COLOR, "%.0f%%" % (_crit_chance * 100), content_alpha)
		y += BAR_HEIGHT + BAR_GAP

	# ========== 6. 单音寂静状态 ==========
	if not _silenced_notes.is_empty():
		y += 2
		draw_string(font, Vector2(x, y + 9), "SILENCED:", HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Color(LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, content_alpha))

		var note_x := x + LABEL_WIDTH
		for entry in _silenced_notes:
			if entry is Dictionary:
				var note_key: int = entry.get("note", -1)
				var remaining: float = entry.get("remaining", 0.0)
				var note_name: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")

				# 音符名称（红色闪烁）
				var note_alpha := 0.5 + sin(_time * 4.0) * 0.3
				var note_color := Color(1.0, 0.2, 0.2, note_alpha * content_alpha)
				draw_string(font, Vector2(note_x, y + 9), note_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, note_color)

				# 剩余时间小条
				var timer_width := 20.0
				var timer_ratio := clampf(remaining / 5.0, 0.0, 1.0)
				var timer_rect := Rect2(Vector2(note_x, y + 12), Vector2(timer_width * timer_ratio, 2))
				draw_rect(timer_rect, Color(1.0, 0.3, 0.3, 0.6 * content_alpha))

				note_x += 30

		y += 16

# ============================================================
# 数值条绘制辅助
# ============================================================

func _draw_bar_section(font: Font, x: float, y: float, label: String,
		ratio: float, bar_color: Color, value_text: String, alpha: float) -> void:
	# 标签
	draw_string(font, Vector2(x, y + BAR_HEIGHT - 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		Color(LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, alpha))

	# 条形背景
	var bar_x := x + LABEL_WIDTH
	var bar_rect := Rect2(Vector2(bar_x, y + 1), Vector2(BAR_WIDTH, BAR_HEIGHT))
	draw_rect(bar_rect, Color(0.08, 0.06, 0.12, 0.5 * alpha))

	# 填充条
	var fill_ratio := clampf(ratio, 0.0, 1.0)
	if fill_ratio > 0.001:
		var fill_color := Color(bar_color.r, bar_color.g, bar_color.b, bar_color.a * alpha)
		draw_rect(Rect2(Vector2(bar_x, y + 1), Vector2(BAR_WIDTH * fill_ratio, BAR_HEIGHT)), fill_color)

		# 发光边缘
		var glow_color := Color(bar_color.r, bar_color.g, bar_color.b, 0.3 * alpha)
		var glow_x := bar_x + BAR_WIDTH * fill_ratio - 2
		if glow_x > bar_x:
			draw_rect(Rect2(Vector2(glow_x, y + 1), Vector2(3, BAR_HEIGHT)), glow_color)

	# 阈值标记线（用于疲劳条）
	if label == "FATIGUE":
		for threshold_level in FatigueManager.thresholds:
			var threshold: float = FatigueManager.thresholds[threshold_level]
			var mark_x := bar_x + BAR_WIDTH * threshold
			draw_line(
				Vector2(mark_x, y + 1),
				Vector2(mark_x, y + 1 + BAR_HEIGHT),
				Color(1, 1, 1, 0.2 * alpha), 1.0
			)

	# 数值文字
	draw_string(font, Vector2(bar_x + BAR_WIDTH + 4, y + BAR_HEIGHT - 1), value_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
		Color(VALUE_COLOR.r, VALUE_COLOR.g, VALUE_COLOR.b, alpha))

# ============================================================
# 颜色计算
# ============================================================

func _get_dissonance_color(value: float) -> Color:
	if value <= 2.0:
		return DISSONANCE_LOW_COLOR
	elif value <= 5.0:
		var t := (value - 2.0) / 3.0
		return DISSONANCE_LOW_COLOR.lerp(DISSONANCE_MID_COLOR, t)
	else:
		var t := clampf((value - 5.0) / 5.0, 0.0, 1.0)
		return DISSONANCE_MID_COLOR.lerp(DISSONANCE_HIGH_COLOR, t)

# ============================================================
# 内容高度计算
# ============================================================

func _calculate_content_height() -> float:
	var height := 0.0
	# 不和谐度
	height += BAR_HEIGHT + BAR_GAP + 2
	# 疲劳
	height += BAR_HEIGHT + BAR_GAP
	# 密度
	height += BAR_HEIGHT + BAR_GAP
	# 护盾（条件显示）
	if GameManager.max_shield_hp > 0:
		height += BAR_HEIGHT + BAR_GAP
	# 暴击率（条件显示）
	if _show_crit:
		height += BAR_HEIGHT + BAR_GAP
	# 单音寂静
	if not _silenced_notes.is_empty():
		height += 20
	return height

# ============================================================
# 数据更新
# ============================================================

func _update_density_from_manager() -> void:
	# 从 FatigueManager 读取密度相关状态
	_is_overloaded = FatigueManager.is_density_overloaded
	_accuracy_penalty = FatigueManager.current_accuracy_penalty

	# 估算密度比率（基于事件历史）
	var current_time := GameManager.game_time
	var recent_count := 0
	for event in FatigueManager._event_history:
		if current_time - event.get("time", 0.0) < FatigueManager.DENSITY_OVERLOAD_WINDOW:
			recent_count += 1

	var beat_rate := GameManager.current_bpm / 60.0
	var dynamic_threshold := max(FatigueManager.DENSITY_OVERLOAD_THRESHOLD,
		int(beat_rate * FatigueManager.DENSITY_OVERLOAD_WINDOW * 1.2))
	_density_ratio = clampf(float(recent_count) / float(dynamic_threshold), 0.0, 1.0)

func _update_shield() -> void:
	if GameManager.max_shield_hp > 0:
		_shield_ratio = GameManager.shield_hp / GameManager.max_shield_hp
	else:
		_shield_ratio = 0.0

# ============================================================
# 信号回调
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

func _on_note_silenced(note: MusicData.WhiteKey, _duration: float) -> void:
	# 更新寂静列表（由 fatigue_updated 信号统一更新）
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
