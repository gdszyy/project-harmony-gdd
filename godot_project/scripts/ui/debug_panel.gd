## debug_panel.gd
## 调试控制台 v4.0 — 纯遥控器架构
## 不包含任何游戏逻辑，所有操作通过 main_game.gd 暴露的 debug_* 接口执行
##
## 功能区域：
##   1. 调试开关（无敌/无限疲劳/冻结/碰撞箱）
##   2. 敌人生成（类型选择、数量、位置模式、预设波次）
##   3. 章节控制（启动/暂停章节系统、敌人波次系统）
##   4. 玩家属性（HP/移速/伤害倍率/等级）
##   5. 法术配置（BPM/调式/音色）
##   6. DPS 统计面板
##   7. 操作日志
extends CanvasLayer

# ============================================================
# 常量
# ============================================================
const PANEL_WIDTH := 340.0

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

# OPT05: 量化统计标签
var _quantize_mode_label: Label = null
var _quantize_queue_label: Label = null
var _quantize_stats_label: Label = null

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

	# 查找宿主场景（main_game.gd 在测试模式下会加入 test_chamber 组）
	await get_tree().process_frame
	_test_chamber = get_tree().get_first_node_in_group("test_chamber")
	if not _test_chamber:
		_test_chamber = get_parent()
		while _test_chamber and not _test_chamber.has_method("debug_spawn_enemy"):
			_test_chamber = _test_chamber.get_parent()

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
	panel_style.bg_color = UIColors.PRIMARY_BG
	panel_style.border_color = UIColors.ACCENT * 0.5
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
	_build_chapter_control()
	_build_player_config()
	_build_spell_config()
	_build_spell_quick_test()
	_build_sequencer_editor()
	_build_dps_stats()
	_build_quantize_stats()  # OPT05
	_build_log_area()

	# 添加到场景
	add_child(_panel)
	add_child(_toggle_button)

# ---- 标题区 ----
func _build_header() -> void:
	var header := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.PANEL_BG
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
	title.add_theme_color_override("font_color", UIColors.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "回响试炼场 · 调试控制台 v4.0"
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", UIColors.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var hotkeys := Label.new()
	hotkeys.text = "F1:无敌 F2:疲劳 F3:冻结 F4:碰撞箱 F5:清敌\nF6:重置DPS F7:慢放 F8:波次 F9:全图鉴\nF10:自动施法 F11:章节 F12:3D层 Esc:返回"
	hotkeys.add_theme_font_size_override("font_size", 9)
	hotkeys.add_theme_color_override("font_color", UIColors.TEXT_DIM)
	hotkeys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hotkeys)

	# 返回主菜单按钮
	var back_btn := Button.new()
	back_btn.text = "← 返回主菜单"
	back_btn.custom_minimum_size.y = 32
	_style_action_button(back_btn, UIColors.WARNING)
	back_btn.pressed.connect(_on_back_to_menu)
	vbox.add_child(back_btn)

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
	time_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	time_hbox.add_child(time_label)

	var time_val_label := Label.new()
	time_val_label.name = "TimeValLabel"
	time_val_label.text = "1.0x"
	time_val_label.add_theme_font_size_override("font_size", 12)
	time_val_label.add_theme_color_override("font_color", UIColors.WARNING)

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
	type_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
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
	count_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
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
	pos_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
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
	_style_action_button(spawn_btn, UIColors.SUCCESS)
	spawn_btn.pressed.connect(func():
		if not _test_chamber: return
		var types := ["static", "silence", "screech", "pulse", "wall"]
		var positions := ["random", "circle", "line", "grid", "player_front"]
		var type_idx: int = type_option.selected
		var count: int = int(count_spin.value)
		var pos_idx: int = pos_option.selected
		_test_chamber.debug_spawn_enemy(types[type_idx], count, positions[pos_idx])
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
		_style_action_button(btn, UIColors.ACCENT)
		var preset_name: String = preset[1]
		btn.pressed.connect(func(): if _test_chamber: _test_chamber.debug_spawn_wave_preset(preset_name))
		preset_grid.add_child(btn)

	_content.add_child(preset_grid)

	# 清除按钮
	var clear_btn := Button.new()
	clear_btn.text = "清除所有敌人 (F5)"
	clear_btn.custom_minimum_size.y = 28
	_style_action_button(clear_btn, UIColors.DANGER)
	clear_btn.pressed.connect(func(): if _test_chamber: _test_chamber.debug_clear_all_enemies())
	_content.add_child(clear_btn)

# ---- 章节控制区 ----
func _build_chapter_control() -> void:
	_add_section_header("章节与波次控制")

	var chapter_grid := GridContainer.new()
	chapter_grid.columns = 2
	chapter_grid.add_theme_constant_override("h_separation", 4)
	chapter_grid.add_theme_constant_override("v_separation", 4)

	var start_chapter_btn := Button.new()
	start_chapter_btn.text = "启动章节系统"
	start_chapter_btn.custom_minimum_size = Vector2(0, 28)
	start_chapter_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(start_chapter_btn, UIColors.SUCCESS)
	start_chapter_btn.pressed.connect(func():
		if _test_chamber: _test_chamber.debug_start_chapter_system()
	)
	chapter_grid.add_child(start_chapter_btn)

	var pause_chapter_btn := Button.new()
	pause_chapter_btn.text = "暂停章节系统"
	pause_chapter_btn.custom_minimum_size = Vector2(0, 28)
	pause_chapter_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(pause_chapter_btn, UIColors.WARNING)
	pause_chapter_btn.pressed.connect(func():
		if _test_chamber: _test_chamber.debug_pause_chapter_system()
	)
	chapter_grid.add_child(pause_chapter_btn)

	var start_spawner_btn := Button.new()
	start_spawner_btn.text = "启动敌人波次"
	start_spawner_btn.custom_minimum_size = Vector2(0, 28)
	start_spawner_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(start_spawner_btn, UIColors.SUCCESS)
	start_spawner_btn.pressed.connect(func():
		if _test_chamber: _test_chamber.debug_start_enemy_spawner()
	)
	chapter_grid.add_child(start_spawner_btn)

	var pause_spawner_btn := Button.new()
	pause_spawner_btn.text = "暂停敌人波次"
	pause_spawner_btn.custom_minimum_size = Vector2(0, 28)
	pause_spawner_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(pause_spawner_btn, UIColors.WARNING)
	pause_spawner_btn.pressed.connect(func():
		if _test_chamber: _test_chamber.debug_pause_enemy_spawner()
	)
	chapter_grid.add_child(pause_spawner_btn)

	_content.add_child(chapter_grid)

	# 章节视觉切换和 3D 层切换
	var visual_grid := GridContainer.new()
	visual_grid.columns = 2
	visual_grid.add_theme_constant_override("h_separation", 4)
	visual_grid.add_theme_constant_override("v_separation", 4)

	var cycle_visual_btn := Button.new()
	cycle_visual_btn.text = "切换章节视觉 (F11)"
	cycle_visual_btn.custom_minimum_size = Vector2(0, 28)
	cycle_visual_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(cycle_visual_btn, UIColors.ACCENT)
	cycle_visual_btn.pressed.connect(func():
		if _test_chamber: _test_chamber._cycle_chapter_visual()
	)
	visual_grid.add_child(cycle_visual_btn)

	var toggle_3d_btn := Button.new()
	toggle_3d_btn.text = "切换 3D 层 (F12)"
	toggle_3d_btn.custom_minimum_size = Vector2(0, 28)
	toggle_3d_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(toggle_3d_btn, UIColors.ACCENT)
	toggle_3d_btn.pressed.connect(func():
		if _test_chamber: _test_chamber._toggle_3d_layer()
	)
	visual_grid.add_child(toggle_3d_btn)

	_content.add_child(visual_grid)

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
		label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
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
	level_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
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
	bpm_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
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
	mode_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
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
	_style_action_button(unlock_all_btn, UIColors.WARNING)
	unlock_all_btn.pressed.connect(func():
		if CodexManager: CodexManager.unlock_all()
		if _test_chamber: _test_chamber._debug_log("已解锁全部图鉴条目")
	)
	codex_grid.add_child(unlock_all_btn)

	var reset_codex_btn := Button.new()
	reset_codex_btn.text = "重置图鉴"
	reset_codex_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(reset_codex_btn, UIColors.DANGER)
	reset_codex_btn.pressed.connect(func():
		if CodexManager: CodexManager.reset_all()
		if _test_chamber: _test_chamber._debug_log("图鉴已重置")
	)
	codex_grid.add_child(reset_codex_btn)

	_content.add_child(codex_grid)

# ---- 法术快速测试区 ----
func _build_spell_quick_test() -> void:
	_add_section_header("法术快速测试")

	# ---- 音符施放 ----
	_add_subsection_header("单音符施放")
	var note_grid := GridContainer.new()
	note_grid.columns = 4
	note_grid.add_theme_constant_override("h_separation", 4)
	note_grid.add_theme_constant_override("v_separation", 4)

	var note_names := ["C", "D", "E", "F", "G", "A", "B"]
	var note_colors := [
		UIColors.DANGER, UIColors.WARNING, UIColors.GOLD,
		Color(0.3, 1.0, 0.3), UIColors.SHIELD, Color(0.5, 0.3, 1.0),
		UIColors.RAINBOW_SEQUENCE[6],
	]
	for i in range(7):
		var btn := Button.new()
		btn.text = note_names[i]
		btn.custom_minimum_size = Vector2(0, 32)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(btn, note_colors[i])
		var note_idx: int = i
		btn.pressed.connect(func(): if _test_chamber: _test_chamber.test_cast_note(note_idx))
		note_grid.add_child(btn)

	# 第8个按钮：全部连射
	var all_btn := Button.new()
	all_btn.text = "全部"
	all_btn.custom_minimum_size = Vector2(0, 32)
	all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(all_btn, UIColors.SUCCESS)
	all_btn.pressed.connect(func():
		if _test_chamber:
			for j in range(7):
				_test_chamber.test_cast_note(j)
	)
	note_grid.add_child(all_btn)
	_content.add_child(note_grid)

	# ---- 修饰符选择 ----
	_add_subsection_header("修饰符 + 音符")
	var mod_hbox := HBoxContainer.new()
	var mod_option := OptionButton.new()
	mod_option.name = "ModifierOption"
	mod_option.add_item("穿透 (C#)")
	mod_option.add_item("追踪 (D#)")
	mod_option.add_item("分裂 (F#)")
	mod_option.add_item("回响 (G#)")
	mod_option.add_item("散射 (A#)")
	mod_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mod_option.add_theme_font_size_override("font_size", 11)
	mod_hbox.add_child(mod_option)

	var mod_note_option := OptionButton.new()
	mod_note_option.name = "ModNoteOption"
	for n in note_names:
		mod_note_option.add_item(n)
	mod_note_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mod_note_option.add_theme_font_size_override("font_size", 11)
	mod_hbox.add_child(mod_note_option)

	var mod_cast_btn := Button.new()
	mod_cast_btn.text = "施放"
	mod_cast_btn.custom_minimum_size = Vector2(50, 28)
	_style_action_button(mod_cast_btn, UIColors.ACCENT)
	mod_cast_btn.pressed.connect(func():
		if not _test_chamber: return
		var mod_idx: int = mod_option.selected
		var note_key: int = mod_note_option.selected
		_test_chamber.test_cast_note_with_modifier(note_key, mod_idx)
	)
	mod_hbox.add_child(mod_cast_btn)
	_content.add_child(mod_hbox)

	# ---- 和弦施放 ----
	_add_subsection_header("和弦法术")
	var chord_grid := GridContainer.new()
	chord_grid.columns = 2
	chord_grid.add_theme_constant_override("h_separation", 4)
	chord_grid.add_theme_constant_override("v_separation", 4)

	var chord_types := [
		["大三和弦", 0], ["小三和弦", 1], ["增三和弦", 2],
		["减三和弦", 3], ["挂留和弦", 4], ["属七和弦", 5],
		["减七和弦", 6], ["大七和弦", 7], ["小七和弦", 8],
	]
	for ct in chord_types:
		var btn := Button.new()
		btn.text = ct[0]
		btn.custom_minimum_size = Vector2(0, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(btn, UIColors.DENSITY_SAFE)
		var chord_id: int = ct[1]
		btn.pressed.connect(func(): if _test_chamber: _test_chamber.test_cast_chord(chord_id))
		chord_grid.add_child(btn)
	_content.add_child(chord_grid)

	# ---- 音色选择 ----
	_add_subsection_header("音色系别")
	var timbre_grid := GridContainer.new()
	timbre_grid.columns = 3
	timbre_grid.add_theme_constant_override("h_separation", 4)
	timbre_grid.add_theme_constant_override("v_separation", 4)

	var timbres := [
		["合成器", 0, UIColors.INSTRUMENT_FAMILY_COLORS[0]],
		["弹拨", 1, UIColors.INSTRUMENT_FAMILY_COLORS[1]],
		["拉弦", 2, UIColors.INSTRUMENT_FAMILY_COLORS[2]],
		["吹奏", 3, UIColors.INSTRUMENT_FAMILY_COLORS[3]],
		["打击", 4, UIColors.INSTRUMENT_FAMILY_COLORS[4]],
	]
	for t in timbres:
		var btn := Button.new()
		btn.text = t[0]
		btn.custom_minimum_size = Vector2(0, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(btn, t[2])
		var timbre_id: int = t[1]
		btn.pressed.connect(func(): if _test_chamber: _test_chamber.test_set_timbre(timbre_id))
		timbre_grid.add_child(btn)
	_content.add_child(timbre_grid)

	# ---- 自动施法控制 ----
	_add_subsection_header("自动施法")
	var auto_hbox := HBoxContainer.new()

	var auto_check := CheckBox.new()
	auto_check.text = "自动施法 (F10)"
	auto_check.add_theme_font_size_override("font_size", 11)
	auto_check.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	auto_check.toggled.connect(func(on):
		if _test_chamber:
			_test_chamber.auto_fire = on
	)
	auto_hbox.add_child(auto_check)
	_content.add_child(auto_hbox)

	var interval_hbox := HBoxContainer.new()
	var interval_label := Label.new()
	interval_label.text = "施法间隔:"
	interval_label.add_theme_font_size_override("font_size", 11)
	interval_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	interval_hbox.add_child(interval_label)

	var interval_spin := SpinBox.new()
	interval_spin.value = 0.5
	interval_spin.min_value = 0.05
	interval_spin.max_value = 3.0
	interval_spin.step = 0.05
	interval_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interval_spin.value_changed.connect(func(val):
		if _test_chamber: _test_chamber._auto_fire_interval = val
	)
	interval_hbox.add_child(interval_spin)
	_content.add_child(interval_hbox)

	# ---- 预设组合 ----
	_add_subsection_header("预设组合")
	var preset_grid := GridContainer.new()
	preset_grid.columns = 2
	preset_grid.add_theme_constant_override("h_separation", 4)
	preset_grid.add_theme_constant_override("v_separation", 4)

	var presets := [
		["全音符连射", "full_note"],
		["蓄力序列", "charged"],
		["全修饰符", "all_mods"],
		["基础和弦", "basic_chords"],
		["七和弦", "seventh_chords"],
	]
	for p in presets:
		var btn := Button.new()
		btn.text = p[0]
		btn.custom_minimum_size = Vector2(0, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(btn, UIColors.GOLD)
		var preset_id: String = p[1]
		btn.pressed.connect(func():
			if not _test_chamber: return
			match preset_id:
				"full_note": _test_chamber.preset_full_note_sequencer()
				"charged": _test_chamber.preset_charged_sequencer()
				"all_mods": _test_chamber.preset_all_modifiers()
				"basic_chords": _test_chamber.preset_all_basic_chords()
				"seventh_chords": _test_chamber.preset_all_seventh_chords()
		)
		preset_grid.add_child(btn)
	_content.add_child(preset_grid)

# ---- 序列器编辑区 ----
func _build_sequencer_editor() -> void:
	_add_section_header("序列器编辑")

	# 序列器16拍可视化编辑
	_add_subsection_header("16拍序列器 (点击设置音符)")

	# 音符选择器
	var note_select_hbox := HBoxContainer.new()
	var note_select_label := Label.new()
	note_select_label.text = "音符:"
	note_select_label.add_theme_font_size_override("font_size", 11)
	note_select_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	note_select_hbox.add_child(note_select_label)

	var seq_note_option := OptionButton.new()
	seq_note_option.name = "SeqNoteOption"
	var note_names := ["C", "D", "E", "F", "G", "A", "B", "休止符"]
	for n in note_names:
		seq_note_option.add_item(n)
	seq_note_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seq_note_option.add_theme_font_size_override("font_size", 11)
	note_select_hbox.add_child(seq_note_option)
	_content.add_child(note_select_hbox)

	# 4x4 网格按钮代表16拍
	var seq_grid := GridContainer.new()
	seq_grid.columns = 4
	seq_grid.add_theme_constant_override("h_separation", 3)
	seq_grid.add_theme_constant_override("v_separation", 3)

	for i in range(16):
		var btn := Button.new()
		btn.text = "%d" % (i + 1)
		btn.custom_minimum_size = Vector2(0, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(btn, UIColors.TEXT_DIM)
		var beat_idx: int = i
		btn.pressed.connect(func():
			if not _test_chamber or not SpellcraftSystem: return
			var selected: int = seq_note_option.selected
			if selected >= 7:  # 休止符
				SpellcraftSystem.set_sequencer_rest(beat_idx)
				btn.text = "%d: -" % (beat_idx + 1)
				_style_action_button(btn, UIColors.TEXT_DIM)
			else:
				SpellcraftSystem.set_sequencer_note(beat_idx, selected)
				var names := ["C", "D", "E", "F", "G", "A", "B"]
				btn.text = "%d: %s" % [beat_idx + 1, names[selected]]
				var colors := [
					UIColors.DANGER, UIColors.WARNING, UIColors.GOLD,
					Color(0.3, 1.0, 0.3), UIColors.SHIELD, Color(0.5, 0.3, 1.0),
					UIColors.RAINBOW_SEQUENCE[6],
				]
				_style_action_button(btn, colors[selected])
				if _test_chamber: _test_chamber._debug_log("序列器 [%d] 已设置" % (beat_idx + 1))
		)
		seq_grid.add_child(btn)
	_content.add_child(seq_grid)

	# 清空序列器按钮
	var clear_seq_btn := Button.new()
	clear_seq_btn.text = "清空序列器"
	clear_seq_btn.custom_minimum_size.y = 28
	_style_action_button(clear_seq_btn, UIColors.DANGER)
	clear_seq_btn.pressed.connect(func():
		if SpellcraftSystem:
			SpellcraftSystem.clear_sequencer()
			if _test_chamber: _test_chamber._debug_log("序列器已清空")
			# 重置按钮文本
			var idx := 0
			for child in seq_grid.get_children():
				if child is Button:
					child.text = "%d" % (idx + 1)
					_style_action_button(child, UIColors.TEXT_DIM)
					idx += 1
	)
	_content.add_child(clear_seq_btn)

	# 手动施法槽配置
	_add_subsection_header("手动施法槽")
	var manual_grid := GridContainer.new()
	manual_grid.columns = 3
	manual_grid.add_theme_constant_override("h_separation", 4)
	manual_grid.add_theme_constant_override("v_separation", 4)

	for slot_i in range(3):
		var slot_label := Label.new()
		slot_label.text = "槽%d:" % (slot_i + 1)
		slot_label.add_theme_font_size_override("font_size", 11)
		slot_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
		manual_grid.add_child(slot_label)

		var slot_note := OptionButton.new()
		var slot_note_names := ["C", "D", "E", "F", "G", "A", "B", "空"]
		for n in slot_note_names:
			slot_note.add_item(n)
		slot_note.selected = 7  # 默认空
		slot_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_note.add_theme_font_size_override("font_size", 11)
		manual_grid.add_child(slot_note)

		var slot_set_btn := Button.new()
		slot_set_btn.text = "设置"
		slot_set_btn.custom_minimum_size = Vector2(45, 24)
		_style_action_button(slot_set_btn, UIColors.ACCENT)
		var si: int = slot_i
		slot_set_btn.pressed.connect(func():
			if not _test_chamber: return
			var sel: int = slot_note.selected
			if sel >= 7:
				_test_chamber.test_set_manual_slot(si, {"type": "empty"})
			else:
				_test_chamber.test_set_manual_slot(si, {"type": "note", "note": sel})
		)
		manual_grid.add_child(slot_set_btn)
	_content.add_child(manual_grid)

	# 触发手动施法按钮
	var trigger_hbox := HBoxContainer.new()
	trigger_hbox.add_theme_constant_override("separation", 4)
	for slot_i in range(3):
		var trigger_btn := Button.new()
		trigger_btn.text = "触发槽%d" % (slot_i + 1)
		trigger_btn.custom_minimum_size = Vector2(0, 28)
		trigger_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(trigger_btn, UIColors.SUCCESS)
		var si: int = slot_i
		trigger_btn.pressed.connect(func(): if _test_chamber: _test_chamber.test_trigger_manual_cast(si))
		trigger_hbox.add_child(trigger_btn)
	_content.add_child(trigger_hbox)

# ---- DPS 统计区 ----
func _build_dps_stats() -> void:
	_add_section_header("DPS 统计")

	var stats_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.with_alpha(UIColors.PRIMARY_BG, 0.9)
	style.border_color = UIColors.ACCENT * 0.3
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
	_dps_label.add_theme_color_override("font_color", UIColors.SUCCESS)
	stats_vbox.add_child(_dps_label)

	_peak_dps_label = _create_stat_label("峰值 DPS: 0.0")
	_peak_dps_label.add_theme_color_override("font_color", UIColors.WARNING)
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
	_style_action_button(reset_btn, UIColors.ACCENT)
	reset_btn.pressed.connect(func(): if _test_chamber: _test_chamber._reset_dps())
	_content.add_child(reset_btn)

# ---- OPT05: 音效量化统计区 ----
func _build_quantize_stats() -> void:
	_add_section_header("音效量化 (OPT05)")

	var stats_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.with_alpha(UIColors.PRIMARY_BG, 0.9)
	style.border_color = UIColors.SHIELD * 0.3
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

	_quantize_mode_label = _create_stat_label("量化模式: FULL")
	_quantize_mode_label.add_theme_color_override("font_color", UIColors.DENSITY_SAFE)
	stats_vbox.add_child(_quantize_mode_label)

	_quantize_queue_label = _create_stat_label("队列大小: 0")
	stats_vbox.add_child(_quantize_queue_label)

	_quantize_stats_label = _create_stat_label("总入队: 0 | 已处理: 0 | 即时: 0")
	stats_vbox.add_child(_quantize_stats_label)

	_content.add_child(stats_panel)

	# 量化模式切换按钮
	var mode_hbox := HBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 4)

	var full_btn := Button.new()
	full_btn.text = "FULL"
	full_btn.custom_minimum_size = Vector2(0, 26)
	full_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(full_btn, UIColors.SHIELD)
	full_btn.pressed.connect(func(): AudioManager.set_quantize_mode(AudioEventQueue.QuantizeMode.FULL))
	mode_hbox.add_child(full_btn)

	var soft_btn := Button.new()
	soft_btn.text = "SOFT"
	soft_btn.custom_minimum_size = Vector2(0, 26)
	soft_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(soft_btn, UIColors.GOLD)
	soft_btn.pressed.connect(func(): AudioManager.set_quantize_mode(AudioEventQueue.QuantizeMode.SOFT))
	mode_hbox.add_child(soft_btn)

	var off_btn := Button.new()
	off_btn.text = "OFF"
	off_btn.custom_minimum_size = Vector2(0, 26)
	off_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(off_btn, UIColors.DANGER)
	off_btn.pressed.connect(func(): AudioManager.set_quantize_mode(AudioEventQueue.QuantizeMode.OFF))
	mode_hbox.add_child(off_btn)

	_content.add_child(mode_hbox)

# ---- 日志区 ----
func _build_log_area() -> void:
	_add_section_header("操作日志")

	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.custom_minimum_size = Vector2(0, 150)
	_log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_text.add_theme_color_override("default_color", UIColors.TEXT_DIM)
	_log_text.add_theme_font_size_override("normal_font_size", 10)

	var log_style := StyleBoxFlat.new()
	log_style.bg_color = UIColors.with_alpha(UIColors.PRIMARY_BG, 0.9)
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
	_style_action_button(clear_log_btn, UIColors.TEXT_DIM)
	clear_log_btn.pressed.connect(func(): if _log_text: _log_text.clear())
	_content.add_child(clear_log_btn)

# ============================================================
# 实时更新
# ============================================================

func _update_stats_display() -> void:
	# OPT05: 更新量化统计显示
	_update_quantize_display()

	if not _test_chamber:
		return

	var stats = _test_chamber.get_stats_summary()

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

## OPT05: 更新量化统计显示
func _update_quantize_display() -> void:
	var q_stats := AudioManager.get_quantize_stats()
	if q_stats.is_empty():
		return

	if _quantize_mode_label:
		_quantize_mode_label.text = "量化模式: %s" % q_stats.get("quantize_mode", "N/A")
	if _quantize_queue_label:
		_quantize_queue_label.text = "队列大小: %d" % q_stats.get("current_queue_size", 0)
	if _quantize_stats_label:
		_quantize_stats_label.text = "总入队: %d | 已处理: %d | 即时: %d" % [
			q_stats.get("total_enqueued", 0),
			q_stats.get("total_processed", 0),
			q_stats.get("total_immediate", 0),
		]

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
	label.add_theme_color_override("font_color", UIColors.ACCENT)
	_content.add_child(label)

func _add_subsection_header(title: String) -> void:
	var label := Label.new()
	label.text = "    %s" % title
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", UIColors.TEXT_DIM)
	_content.add_child(label)

func _create_checkbox(text: String, default: bool) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = default
	cb.add_theme_font_size_override("font_size", 11)
	cb.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	return cb

func _create_stat_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
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
	style.bg_color = UIColors.with_alpha(UIColors.PANEL_DARK, 0.95)
	style.border_color = UIColors.ACCENT * 0.5
	style.border_width_left = 1
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 4
	style.content_margin_right = 4
	_toggle_button.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = UIColors.ACCENT * 0.3
	_toggle_button.add_theme_stylebox_override("hover", hover)

	_toggle_button.add_theme_color_override("font_color", UIColors.ACCENT)
	_toggle_button.add_theme_font_size_override("font_size", 14)

# ============================================================
# 返回主菜单
# ============================================================

func _on_back_to_menu() -> void:
	# 委托给宿主场景处理返回逻辑（包括信号断开、时间恢复等）
	if _test_chamber and _test_chamber.has_method("_return_to_menu"):
		_test_chamber._return_to_menu()
	else:
		# 回退方案
		Engine.time_scale = 1.0
		if GameManager:
			GameManager.is_test_mode = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
