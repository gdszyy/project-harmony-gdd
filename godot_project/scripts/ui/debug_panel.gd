## debug_panel.gd
## 测试场调试面板 — 左侧可折叠的控制面板
##
## 功能区域：
##   1. 调试开关（无敌/无限疲劳/冻结/碰撞箱）
##   2. 敌人生成（类型选择、数量、位置模式、预设波次）
##   3. 玩家属性（HP/移速/伤害倍率/等级）
##   4. 法术配置（BPM/调式/音色）
##   5. DPS 统计面板
##   6. 操作日志
extends CanvasLayer

# ============================================================
# 常量
# ============================================================
const PANEL_WIDTH := 340.0
const BG_COLOR := Color(0.05, 0.03, 0.10, 0.92)
const HEADER_COLOR := Color(0.08, 0.05, 0.14)
const SECTION_COLOR := Color(0.6, 0.4, 1.0)
const ACCENT := Color(0.5, 0.3, 0.9)
const TEXT_COLOR := Color(0.85, 0.82, 0.90)
const DIM_COLOR := Color(0.45, 0.42, 0.52)
const SUCCESS_COLOR := Color(0.3, 0.9, 0.5)
const WARNING_COLOR := Color(1.0, 0.8, 0.2)
const DANGER_COLOR := Color(1.0, 0.3, 0.3)

# ============================================================
# 节点引用
# ============================================================
var _test_chamber: Node2D = null
var _panel: PanelContainer = null
var _scroll: ScrollContainer = null
var _content: VBoxContainer = null
var _toggle_button: Button = null
var _is_collapsed: bool = false

# 动态更新的标签
var _dps_label: Label = null
var _peak_dps_label: Label = null
var _total_damage_label: Label = null
var _enemy_count_label: Label = null
var _kill_count_label: Label = null
var _session_time_label: Label = null
var _log_text: RichTextLabel = null

# 调试开关引用
var _god_mode_check: CheckBox = null
var _infinite_fatigue_check: CheckBox = null
var _freeze_check: CheckBox = null
var _hitbox_check: CheckBox = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 20  # 确保在最上层
	_build_ui()

	# 查找 TestChamber 节点
	await get_tree().process_frame
	_test_chamber = get_tree().get_first_node_in_group("test_chamber")
	if not _test_chamber:
		_test_chamber = get_parent()

	# 连接日志信号
	if _test_chamber and _test_chamber.has_signal("debug_message"):
		_test_chamber.debug_message.connect(_on_debug_message)

func _process(_delta: float) -> void:
	_update_stats_display()

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	# 折叠/展开按钮
	_toggle_button = Button.new()
	_toggle_button.text = "<<"
	_toggle_button.custom_minimum_size = Vector2(32, 80)
	_toggle_button.position = Vector2(PANEL_WIDTH, 200)
	_toggle_button.pressed.connect(_toggle_panel)
	_style_toggle_button()

	# 主面板
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(PANEL_WIDTH, ProjectSettings.get_setting("display/window/size/viewport_height", 720))

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = BG_COLOR
	panel_style.border_color = ACCENT * 0.5
	panel_style.border_width_right = 1
	_panel.add_theme_stylebox_override("panel", panel_style)

	# 滚动容器
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(_scroll)

	# 内容容器
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 4)
	_scroll.add_child(_content)

	# ---- 构建各区域 ----
	_build_header()
	_build_debug_toggles()
	_build_enemy_spawner()
	_build_player_config()
	_build_spell_config()
	_build_dps_stats()
	_build_log_area()

	# 添加到场景
	add_child(_panel)
	add_child(_toggle_button)

# ---- 标题区 ----
func _build_header() -> void:
	var header := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = HEADER_COLOR
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	header.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	header.add_child(vbox)

	var title := Label.new()
	title.text = "ECHOING CHAMBER"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "回响试炼场 · 调试面板"
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", DIM_COLOR)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var hotkeys := Label.new()
	hotkeys.text = "F1:无敌 F2:疲劳 F3:冻结 F4:碰撞箱 F5:清敌\nF6:重置DPS F7:慢放 F8:波次 F9:全图鉴"
	hotkeys.add_theme_font_size_override("font_size", 9)
	hotkeys.add_theme_color_override("font_color", DIM_COLOR)
	hotkeys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hotkeys)

	_content.add_child(header)

# ---- 调试开关区 ----
func _build_debug_toggles() -> void:
	_add_section_header("调试开关")

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)

	_god_mode_check = _create_checkbox("无敌模式 (F1)", false)
	_god_mode_check.toggled.connect(func(on): _set_debug("god_mode", on))
	grid.add_child(_god_mode_check)

	_infinite_fatigue_check = _create_checkbox("无限疲劳 (F2)", false)
	_infinite_fatigue_check.toggled.connect(func(on): _set_debug("infinite_fatigue", on))
	grid.add_child(_infinite_fatigue_check)

	_freeze_check = _create_checkbox("冻结敌人 (F3)", false)
	_freeze_check.toggled.connect(func(on): _set_debug("freeze_enemies", on))
	grid.add_child(_freeze_check)

	_hitbox_check = _create_checkbox("碰撞箱 (F4)", false)
	_hitbox_check.toggled.connect(func(on): _set_debug("show_hitboxes", on))
	grid.add_child(_hitbox_check)

	_content.add_child(grid)

	# 时间缩放滑块
	var time_hbox := HBoxContainer.new()
	var time_label := Label.new()
	time_label.text = "时间缩放:"
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", TEXT_COLOR)
	time_hbox.add_child(time_label)

	var time_slider := HSlider.new()
	time_slider.min_value = 0.1
	time_slider.max_value = 3.0
	time_slider.step = 0.1
	time_slider.value = 1.0
	time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_slider.custom_minimum_size.x = 120
	time_slider.value_changed.connect(func(val):
		if _test_chamber: _test_chamber.time_scale = val
		time_val_label.text = "%.1fx" % val
	)
	time_hbox.add_child(time_slider)

	var time_val_label := Label.new()
	time_val_label.name = "TimeValLabel"
	time_val_label.text = "1.0x"
	time_val_label.add_theme_font_size_override("font_size", 12)
	time_val_label.add_theme_color_override("font_color", WARNING_COLOR)
	time_hbox.add_child(time_val_label)

	_content.add_child(time_hbox)

# ---- 敌人生成区 ----
func _build_enemy_spawner() -> void:
	_add_section_header("敌人生成")

	# 敌人类型选择
	var type_hbox := HBoxContainer.new()
	var type_label := Label.new()
	type_label.text = "类型:"
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", TEXT_COLOR)
	type_label.custom_minimum_size.x = 50
	type_hbox.add_child(type_label)

	var type_option := OptionButton.new()
	type_option.name = "EnemyTypeOption"
	type_option.add_item("底噪 (Static)")
	type_option.add_item("寂静 (Silence)")
	type_option.add_item("尖啸 (Screech)")
	type_option.add_item("脉冲 (Pulse)")
	type_option.add_item("音墙 (Wall)")
	type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_option.add_theme_font_size_override("font_size", 12)
	type_hbox.add_child(type_option)
	_content.add_child(type_hbox)

	# 数量
	var count_hbox := HBoxContainer.new()
	var count_label := Label.new()
	count_label.text = "数量:"
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", TEXT_COLOR)
	count_label.custom_minimum_size.x = 50
	count_hbox.add_child(count_label)

	var count_spin := SpinBox.new()
	count_spin.name = "EnemyCountSpin"
	count_spin.min_value = 1
	count_spin.max_value = 100
	count_spin.value = 5
	count_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_hbox.add_child(count_spin)
	_content.add_child(count_hbox)

	# 位置模式
	var pos_hbox := HBoxContainer.new()
	var pos_label := Label.new()
	pos_label.text = "位置:"
	pos_label.add_theme_font_size_override("font_size", 12)
	pos_label.add_theme_color_override("font_color", TEXT_COLOR)
	pos_label.custom_minimum_size.x = 50
	pos_hbox.add_child(pos_label)

	var pos_option := OptionButton.new()
	pos_option.name = "PositionOption"
	pos_option.add_item("随机 (random)")
	pos_option.add_item("环形 (circle)")
	pos_option.add_item("直线 (line)")
	pos_option.add_item("网格 (grid)")
	pos_option.add_item("玩家前方 (front)")
	pos_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pos_option.add_theme_font_size_override("font_size", 12)
	pos_hbox.add_child(pos_option)
	_content.add_child(pos_hbox)

	# 生成按钮
	var spawn_btn := Button.new()
	spawn_btn.text = "生成敌人"
	spawn_btn.custom_minimum_size.y = 32
	_style_action_button(spawn_btn, SUCCESS_COLOR)
	spawn_btn.pressed.connect(func():
		if not _test_chamber: return
		var types := ["static", "silence", "screech", "pulse", "wall"]
		var positions := ["random", "circle", "line", "grid", "player_front"]
		var type_idx: int = type_option.selected
		var count: int = int(count_spin.value)
		var pos_idx: int = pos_option.selected
		_test_chamber.spawn_enemy(types[type_idx], count, positions[pos_idx])
	)
	_content.add_child(spawn_btn)

	# 预设波次按钮
	_add_subsection_header("预设波次")
	var preset_grid := GridContainer.new()
	preset_grid.columns = 2
	preset_grid.add_theme_constant_override("h_separation", 4)
	preset_grid.add_theme_constant_override("v_separation", 4)

	var presets := [
		["基础混合", "mixed_basic"],
		["底噪蜂群", "static_swarm"],
		["精英测试", "elite_test"],
		["压力测试", "stress_test"],
		["DPS 木桩", "dps_dummy"],
	]

	for preset in presets:
		var btn := Button.new()
		btn.text = preset[0]
		btn.custom_minimum_size = Vector2(0, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(btn, ACCENT)
		var preset_name: String = preset[1]
		btn.pressed.connect(func(): if _test_chamber: _test_chamber.spawn_wave_preset(preset_name))
		preset_grid.add_child(btn)

	_content.add_child(preset_grid)

	# 清除按钮
	var clear_btn := Button.new()
	clear_btn.text = "清除所有敌人 (F5)"
	clear_btn.custom_minimum_size.y = 28
	_style_action_button(clear_btn, DANGER_COLOR)
	clear_btn.pressed.connect(func(): if _test_chamber: _test_chamber._clear_all_enemies())
	_content.add_child(clear_btn)

# ---- 玩家配置区 ----
func _build_player_config() -> void:
	_add_section_header("玩家配置")

	var configs := [
		["最大 HP", "max_hp", 100.0, 10.0, 9999.0, 10.0],
		["移动速度", "move_speed", 250.0, 50.0, 1000.0, 25.0],
		["伤害倍率", "damage_multiplier", 1.0, 0.1, 10.0, 0.1],
	]

	for cfg in configs:
		var hbox := HBoxContainer.new()
		var label := Label.new()
		label.text = cfg[0] + ":"
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", TEXT_COLOR)
		label.custom_minimum_size.x = 80
		hbox.add_child(label)

		var spin := SpinBox.new()
		spin.value = cfg[2]
		spin.min_value = cfg[3]
		spin.max_value = cfg[4]
		spin.step = cfg[5]
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var stat_name: String = cfg[1]
		spin.value_changed.connect(func(val):
			if _test_chamber: _test_chamber.set_player_stat(stat_name, val)
		)
		hbox.add_child(spin)
		_content.add_child(hbox)

	# 等级
	var level_hbox := HBoxContainer.new()
	var level_label := Label.new()
	level_label.text = "等级:"
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", TEXT_COLOR)
	level_label.custom_minimum_size.x = 80
	level_hbox.add_child(level_label)

	var level_spin := SpinBox.new()
	level_spin.value = 1
	level_spin.min_value = 1
	level_spin.max_value = 100
	level_spin.step = 1
	level_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_spin.value_changed.connect(func(val):
		if _test_chamber: _test_chamber.set_player_level(int(val))
	)
	level_hbox.add_child(level_spin)
	_content.add_child(level_hbox)

# ---- 法术配置区 ----
func _build_spell_config() -> void:
	_add_section_header("法术配置")

	# BPM
	var bpm_hbox := HBoxContainer.new()
	var bpm_label := Label.new()
	bpm_label.text = "BPM:"
	bpm_label.add_theme_font_size_override("font_size", 12)
	bpm_label.add_theme_color_override("font_color", TEXT_COLOR)
	bpm_label.custom_minimum_size.x = 80
	bpm_hbox.add_child(bpm_label)

	var bpm_spin := SpinBox.new()
	bpm_spin.value = 120
	bpm_spin.min_value = 60
	bpm_spin.max_value = 240
	bpm_spin.step = 5
	bpm_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bpm_spin.value_changed.connect(func(val):
		if _test_chamber: _test_chamber.set_bpm(val)
	)
	bpm_hbox.add_child(bpm_spin)
	_content.add_child(bpm_hbox)

	# 调式选择
	var mode_hbox := HBoxContainer.new()
	var mode_label := Label.new()
	mode_label.text = "调式:"
	mode_label.add_theme_font_size_override("font_size", 12)
	mode_label.add_theme_color_override("font_color", TEXT_COLOR)
	mode_label.custom_minimum_size.x = 80
	mode_hbox.add_child(mode_label)

	var mode_option := OptionButton.new()
	mode_option.add_item("伊奥尼亚 (均衡)")
	mode_option.add_item("多利亚 (诗人)")
	mode_option.add_item("五声音阶 (东方)")
	mode_option.add_item("布鲁斯 (爵士)")
	mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_option.add_theme_font_size_override("font_size", 12)
	var mode_ids := ["ionian", "dorian", "pentatonic", "blues"]
	mode_option.item_selected.connect(func(idx):
		if _test_chamber and idx < mode_ids.size():
			_test_chamber.set_mode(mode_ids[idx])
	)
	mode_hbox.add_child(mode_option)
	_content.add_child(mode_hbox)

	# 图鉴操作
	_add_subsection_header("图鉴操作")
	var codex_grid := GridContainer.new()
	codex_grid.columns = 2
	codex_grid.add_theme_constant_override("h_separation", 4)

	var unlock_all_btn := Button.new()
	unlock_all_btn.text = "全部解锁 (F9)"
	unlock_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(unlock_all_btn, WARNING_COLOR)
	unlock_all_btn.pressed.connect(func():
		if CodexManager: CodexManager.unlock_all()
		if _test_chamber: _test_chamber._log("已解锁全部图鉴条目")
	)
	codex_grid.add_child(unlock_all_btn)

	var reset_codex_btn := Button.new()
	reset_codex_btn.text = "重置图鉴"
	reset_codex_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(reset_codex_btn, DANGER_COLOR)
	reset_codex_btn.pressed.connect(func():
		if CodexManager: CodexManager.reset_all()
		if _test_chamber: _test_chamber._log("图鉴已重置")
	)
	codex_grid.add_child(reset_codex_btn)

	_content.add_child(codex_grid)

# ---- DPS 统计区 ----
func _build_dps_stats() -> void:
	_add_section_header("DPS 统计")

	var stats_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.02, 0.08, 0.9)
	style.border_color = ACCENT * 0.3
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	stats_panel.add_theme_stylebox_override("panel", style)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 2)
	stats_panel.add_child(stats_vbox)

	_dps_label = _create_stat_label("当前 DPS: 0.0")
	_dps_label.add_theme_color_override("font_color", SUCCESS_COLOR)
	stats_vbox.add_child(_dps_label)

	_peak_dps_label = _create_stat_label("峰值 DPS: 0.0")
	_peak_dps_label.add_theme_color_override("font_color", WARNING_COLOR)
	stats_vbox.add_child(_peak_dps_label)

	_total_damage_label = _create_stat_label("总伤害: 0")
	stats_vbox.add_child(_total_damage_label)

	_enemy_count_label = _create_stat_label("存活敌人: 0")
	stats_vbox.add_child(_enemy_count_label)

	_kill_count_label = _create_stat_label("击杀数: 0")
	stats_vbox.add_child(_kill_count_label)

	_session_time_label = _create_stat_label("测试时间: 0:00")
	stats_vbox.add_child(_session_time_label)

	_content.add_child(stats_panel)

	# 重置按钮
	var reset_btn := Button.new()
	reset_btn.text = "重置统计 (F6)"
	reset_btn.custom_minimum_size.y = 28
	_style_action_button(reset_btn, ACCENT)
	reset_btn.pressed.connect(func(): if _test_chamber: _test_chamber._reset_dps())
	_content.add_child(reset_btn)

# ---- 日志区 ----
func _build_log_area() -> void:
	_add_section_header("操作日志")

	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.custom_minimum_size = Vector2(0, 150)
	_log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_text.add_theme_color_override("default_color", DIM_COLOR)
	_log_text.add_theme_font_size_override("normal_font_size", 10)

	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.03, 0.02, 0.06, 0.9)
	log_style.content_margin_left = 6
	log_style.content_margin_right = 6
	log_style.content_margin_top = 4
	log_style.content_margin_bottom = 4
	_log_text.add_theme_stylebox_override("normal", log_style)

	_content.add_child(_log_text)

	# 清除日志按钮
	var clear_log_btn := Button.new()
	clear_log_btn.text = "清除日志"
	clear_log_btn.custom_minimum_size.y = 24
	_style_action_button(clear_log_btn, DIM_COLOR)
	clear_log_btn.pressed.connect(func(): if _log_text: _log_text.clear())
	_content.add_child(clear_log_btn)

# ============================================================
# 实时更新
# ============================================================

func _update_stats_display() -> void:
	if not _test_chamber:
		return

	var stats := _test_chamber.get_stats_summary()

	if _dps_label:
		_dps_label.text = "当前 DPS: %.1f" % stats.get("current_dps", 0.0)
	if _peak_dps_label:
		_peak_dps_label.text = "峰值 DPS: %.1f" % stats.get("peak_dps", 0.0)
	if _total_damage_label:
		_total_damage_label.text = "总伤害: %.0f" % stats.get("total_damage", 0.0)
	if _enemy_count_label:
		_enemy_count_label.text = "存活敌人: %d" % stats.get("enemies_alive", 0)
	if _kill_count_label:
		_kill_count_label.text = "击杀数: %d" % stats.get("enemies_killed", 0)
	if _session_time_label:
		var t: float = stats.get("session_time", 0.0)
		_session_time_label.text = "测试时间: %d:%02d" % [int(t) / 60, int(t) % 60]

# ============================================================
# 信号回调
# ============================================================

func _on_debug_message(text: String) -> void:
	if _log_text:
		_log_text.append_text(text + "\n")

func _set_debug(property: String, value: bool) -> void:
	if _test_chamber and property in _test_chamber:
		_test_chamber.set(property, value)

# ============================================================
# 面板折叠
# ============================================================

func _toggle_panel() -> void:
	_is_collapsed = !_is_collapsed
	if _is_collapsed:
		_panel.visible = false
		_toggle_button.text = ">>"
		_toggle_button.position.x = 0
	else:
		_panel.visible = true
		_toggle_button.text = "<<"
		_toggle_button.position.x = PANEL_WIDTH

# ============================================================
# UI 辅助方法
# ============================================================

func _add_section_header(title: String) -> void:
	var sep := HSeparator.new()
	_content.add_child(sep)

	var label := Label.new()
	label.text = "  %s" % title
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", SECTION_COLOR)
	_content.add_child(label)

func _add_subsection_header(title: String) -> void:
	var label := Label.new()
	label.text = "    %s" % title
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", DIM_COLOR)
	_content.add_child(label)

func _create_checkbox(text: String, default: bool) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = default
	cb.add_theme_font_size_override("font_size", 11)
	cb.add_theme_color_override("font_color", TEXT_COLOR)
	return cb

func _create_stat_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	return label

func _style_action_button(button: Button, accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = accent * 0.2
	style.border_color = accent * 0.6
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.content_margin_left = 8
	style.content_margin_right = 8
	button.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = accent * 0.35
	hover.border_color = accent
	button.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = accent * 0.5
	button.add_theme_stylebox_override("pressed", pressed)

	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 12)

func _style_toggle_button() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.12, 0.95)
	style.border_color = ACCENT * 0.5
	style.border_width_left = 1
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 4
	style.content_margin_right = 4
	_toggle_button.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = ACCENT * 0.3
	_toggle_button.add_theme_stylebox_override("hover", hover)

	_toggle_button.add_theme_color_override("font_color", ACCENT)
	_toggle_button.add_theme_font_size_override("font_size", 14)
