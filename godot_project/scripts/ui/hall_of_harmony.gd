## hall_of_harmony.gd
## "和谐殿堂" UI (Issue #31)
## 局外成长系统的主界面，视觉风格为合成器机架/乐谱架
##
## 包含四个标签页对应四大模块：
## A. 乐器调优 (推杆/旋钮风格)
## B. 乐理研习 (技能树/五线谱风格)
## C. 调式风格 (职业选择卡片)
## D. 声学降噪 (调音台推杆)
##
## 以及顶部的货币显示和底部的操作按钮
extends Control

# ============================================================
# 信号
# ============================================================
signal start_game_pressed()
signal back_pressed()

# ============================================================
# 配置
# ============================================================
const TAB_NAMES: Array = ["乐器调优", "乐理研习", "调式风格", "声学降噪"]
const TAB_ICONS: Array = ["🎹", "📖", "🎵", "🔇"]

# ============================================================
# 颜色方案
# ============================================================
const BG_COLOR := Color(0.08, 0.06, 0.12)
const PANEL_COLOR := Color(0.12, 0.10, 0.18, 0.95)
const ACCENT_COLOR := Color(0.6, 0.4, 1.0)
const GOLD_COLOR := Color(1.0, 0.85, 0.3)
const TEXT_COLOR := Color(0.9, 0.88, 0.95)
const DIM_TEXT_COLOR := Color(0.5, 0.48, 0.55)
const SUCCESS_COLOR := Color(0.3, 0.9, 0.5)
const LOCKED_COLOR := Color(0.3, 0.28, 0.35)
const TAB_ACTIVE_COLOR := Color(0.6, 0.4, 1.0, 0.3)
const TAB_HOVER_COLOR := Color(0.6, 0.4, 1.0, 0.15)

# ============================================================
# 节点引用
# ============================================================
var _bg: ColorRect = null
var _header: Control = null
var _fragments_label: Label = null
var _tab_bar: HBoxContainer = null
var _content_container: Control = null
var _tab_panels: Array[Control] = []
var _current_tab: int = 0
var _start_button: Button = null

# ============================================================
# Meta 管理器引用
# ============================================================
var _meta: Node = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_meta = get_node_or_null("/root/MetaProgressionManager")
	_build_ui()
	_refresh_all()
	
	if _meta:
		_meta.resonance_fragments_changed.connect(_on_fragments_changed)
		_meta.upgrade_purchased.connect(_on_upgrade_purchased)

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	# 全屏背景
	_bg = ColorRect.new()
	_bg.color = BG_COLOR
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	
	# 主容器
	var main := VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 0)
	add_child(main)
	
	# 头部
	_build_header(main)
	
	# 标签栏
	_build_tab_bar(main)
	
	# 内容区域
	_content_container = Control.new()
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.custom_minimum_size = Vector2(0, 400)
	main.add_child(_content_container)
	
	# 构建四个标签页
	_build_instrument_tab()
	_build_theory_tab()
	_build_mode_tab()
	_build_acoustic_tab()
	
	# 底部按钮
	_build_footer(main)
	
	# 默认显示第一个标签
	_switch_tab(0)

func _build_header(parent: Node) -> void:
	_header = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_width_bottom = 2
	style.border_color = ACCENT_COLOR.darkened(0.3)
	_header.add_theme_stylebox_override("panel", style)
	parent.add_child(_header)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	_header.add_child(hbox)
	
	# 标题
	var title := Label.new()
	title.text = "和谐殿堂  The Hall of Harmony"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GOLD_COLOR)
	hbox.add_child(title)
	
	# 弹性空间
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	# 共鸣碎片显示
	_fragments_label = Label.new()
	_fragments_label.add_theme_font_size_override("font_size", 18)
	_fragments_label.add_theme_color_override("font_color", GOLD_COLOR)
	_update_fragments_display()
	hbox.add_child(_fragments_label)

func _build_tab_bar(parent: Node) -> void:
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 0)
	parent.add_child(_tab_bar)
	
	for i in range(TAB_NAMES.size()):
		var btn := Button.new()
		btn.text = "%s %s" % [TAB_ICONS[i], TAB_NAMES[i]]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 14)
		
		var tab_index := i
		btn.pressed.connect(func(): _switch_tab(tab_index))
		_tab_bar.add_child(btn)

func _build_footer(parent: Node) -> void:
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 20)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(footer)
	
	var back_btn := Button.new()
	back_btn.text = "返回主菜单"
	back_btn.custom_minimum_size = Vector2(150, 45)
	back_btn.pressed.connect(func(): back_pressed.emit())
	footer.add_child(back_btn)
	
	_start_button = Button.new()
	_start_button.text = "开始演奏"
	_start_button.custom_minimum_size = Vector2(200, 45)
	_start_button.add_theme_font_size_override("font_size", 16)
	_start_button.pressed.connect(func(): start_game_pressed.emit())
	footer.add_child(_start_button)

# ============================================================
# 标签页 A：乐器调优
# ============================================================

func _build_instrument_tab() -> void:
	var panel := _create_tab_panel()
	_tab_panels.append(panel)
	
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)
	
	# 模块标题
	var title := Label.new()
	title.text = "乐器调优  Instrument Tuning"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	vbox.add_child(title)
	
	var desc := Label.new()
	desc.text = "调整你的乐器，提升基础演奏能力。每次升级都像推大一格音量推杆。"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)
	
	# 升级项列表
	if _meta:
		for upgrade_id in _meta.INSTRUMENT_UPGRADES:
			var config: Dictionary = _meta.INSTRUMENT_UPGRADES[upgrade_id]
			var item := _create_upgrade_item(upgrade_id, config, "instrument")
			vbox.add_child(item)

# ============================================================
# 标签页 B：乐理研习
# ============================================================

func _build_theory_tab() -> void:
	var panel := _create_tab_panel()
	_tab_panels.append(panel)
	
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)
	
	var title := Label.new()
	title.text = "乐理研习  Theory Archives"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	vbox.add_child(title)
	
	var desc := Label.new()
	desc.text = "研习高级乐理知识，解锁更复杂的和弦与修饰符，扩展你的编曲可能性。"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)
	
	# 分类显示
	var categories := {"black_key": "黑键修饰符", "chord": "和弦图谱", "legend": "传说乐章"}
	for cat_key in categories:
		var cat_label := Label.new()
		cat_label.text = "— %s —" % categories[cat_key]
		cat_label.add_theme_font_size_override("font_size", 14)
		cat_label.add_theme_color_override("font_color", GOLD_COLOR.darkened(0.2))
		cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(cat_label)
		
		if _meta:
			for theory_id in _meta.THEORY_UNLOCKS:
				var config: Dictionary = _meta.THEORY_UNLOCKS[theory_id]
				if config.get("category", "") == cat_key:
					var item := _create_theory_item(theory_id, config)
					vbox.add_child(item)

# ============================================================
# 标签页 C：调式风格
# ============================================================

func _build_mode_tab() -> void:
	var panel := _create_tab_panel()
	_tab_panels.append(panel)
	
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)
	
	var title := Label.new()
	title.text = "调式风格  Mode Mastery"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	vbox.add_child(title)
	
	var desc := Label.new()
	desc.text = "选择你的演奏风格。不同调式提供独特的音符组合和被动效果。"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)
	
	if _meta:
		for mode_name in _meta.MODE_CONFIGS:
			var config: Dictionary = _meta.MODE_CONFIGS[mode_name]
			var card := _create_mode_card(mode_name, config)
			vbox.add_child(card)

# ============================================================
# 标签页 D：声学降噪
# ============================================================

func _build_acoustic_tab() -> void:
	var panel := _create_tab_panel()
	_tab_panels.append(panel)
	
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)
	
	var title := Label.new()
	title.text = "声学降噪  Acoustic Treatment"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	vbox.add_child(title)
	
	var desc := Label.new()
	desc.text = "优化你的声学环境，缓解演奏疲劳，让你能更专注于创作复杂的乐曲。"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)
	
	if _meta:
		for upgrade_id in _meta.ACOUSTIC_UPGRADES:
			var config: Dictionary = _meta.ACOUSTIC_UPGRADES[upgrade_id]
			var item := _create_upgrade_item(upgrade_id, config, "acoustic")
			vbox.add_child(item)

# ============================================================
# UI 组件工厂
# ============================================================

func _create_tab_panel() -> Control:
	var panel := Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	_content_container.add_child(panel)
	return panel

func _create_upgrade_item(upgrade_id: String, config: Dictionary, module: String) -> PanelContainer:
	var container := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 3
	style.border_color = ACCENT_COLOR.darkened(0.3)
	container.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	container.add_child(hbox)
	
	# 左侧：信息
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var name_label := Label.new()
	name_label.text = "%s (%s)" % [config.get("name", ""), config.get("name_en", "")]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	info_vbox.add_child(name_label)
	
	var desc_label := Label.new()
	desc_label.text = config.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	info_vbox.add_child(desc_label)
	
	# 等级显示
	var level_label := Label.new()
	level_label.name = "LevelLabel_%s" % upgrade_id
	var current_level := 0
	if _meta:
		if module == "instrument":
			current_level = _meta.get_instrument_level(upgrade_id)
		elif module == "acoustic":
			current_level = _meta.get_acoustic_level(upgrade_id)
	var max_level: int = config.get("max_level", 1)
	level_label.text = "Lv. %d / %d" % [current_level, max_level]
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", 
		SUCCESS_COLOR if current_level >= max_level else GOLD_COLOR)
	info_vbox.add_child(level_label)
	
	# 右侧：购买按钮
	var buy_btn := Button.new()
	buy_btn.name = "BuyBtn_%s" % upgrade_id
	buy_btn.custom_minimum_size = Vector2(120, 40)
	
	var cost := 0
	if _meta:
		if module == "instrument":
			cost = _meta.get_instrument_cost(upgrade_id)
		elif module == "acoustic":
			cost = _meta.get_acoustic_cost(upgrade_id)
	
	if cost < 0:
		buy_btn.text = "已满级"
		buy_btn.disabled = true
	else:
		buy_btn.text = "%d 碎片" % cost
		buy_btn.disabled = (_meta and _meta.resonance_fragments < cost)
	
	var uid := upgrade_id
	var mod := module
	buy_btn.pressed.connect(func(): _on_purchase_upgrade(uid, mod))
	hbox.add_child(buy_btn)
	
	return container

func _create_theory_item(theory_id: String, config: Dictionary) -> PanelContainer:
	var container := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 3
	
	var is_unlocked := false
	if _meta:
		is_unlocked = _meta.is_theory_unlocked(theory_id)
	style.border_color = SUCCESS_COLOR if is_unlocked else LOCKED_COLOR
	container.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	container.add_child(hbox)
	
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var name_label := Label.new()
	name_label.text = "%s (%s)" % [config.get("name", ""), config.get("name_en", "")]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", 
		SUCCESS_COLOR if is_unlocked else TEXT_COLOR)
	info_vbox.add_child(name_label)
	
	var desc_label := Label.new()
	desc_label.text = config.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	info_vbox.add_child(desc_label)
	
	# 前置条件显示
	var prereq: String = config.get("prerequisite", "")
	if prereq != "" and _meta:
		var prereq_met := _meta.is_theory_unlocked(prereq)
		var prereq_config: Dictionary = _meta.THEORY_UNLOCKS.get(prereq, {})
		var prereq_label := Label.new()
		prereq_label.text = "需要: %s %s" % [
			prereq_config.get("name", prereq),
			"(已解锁)" if prereq_met else "(未解锁)"
		]
		prereq_label.add_theme_font_size_override("font_size", 10)
		prereq_label.add_theme_color_override("font_color", 
			SUCCESS_COLOR if prereq_met else Color(0.8, 0.3, 0.3))
		info_vbox.add_child(prereq_label)
	
	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(120, 40)
	
	if is_unlocked:
		buy_btn.text = "已解锁"
		buy_btn.disabled = true
	else:
		var cost: int = config.get("cost", 0)
		buy_btn.text = "%d 碎片" % cost
		var can_unlock := _meta.can_unlock_theory(theory_id) if _meta else false
		buy_btn.disabled = not can_unlock
	
	var tid := theory_id
	buy_btn.pressed.connect(func(): _on_purchase_theory(tid))
	hbox.add_child(buy_btn)
	
	return container

func _create_mode_card(mode_name: String, config: Dictionary) -> PanelContainer:
	var container := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 4
	
	var is_unlocked := _meta.is_mode_unlocked(mode_name) if _meta else false
	var is_selected := (_meta.selected_mode == mode_name) if _meta else false
	
	if is_selected:
		style.border_color = GOLD_COLOR
	elif is_unlocked:
		style.border_color = SUCCESS_COLOR
	else:
		style.border_color = LOCKED_COLOR
	container.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	container.add_child(vbox)
	
	# 标题行
	var title_hbox := HBoxContainer.new()
	vbox.add_child(title_hbox)
	
	var name_label := Label.new()
	name_label.text = "%s — %s" % [config.get("name", ""), config.get("title", "")]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", 
		GOLD_COLOR if is_selected else (TEXT_COLOR if is_unlocked else DIM_TEXT_COLOR))
	title_hbox.add_child(name_label)
	
	if is_selected:
		var selected_tag := Label.new()
		selected_tag.text = "  [当前选择]"
		selected_tag.add_theme_font_size_override("font_size", 12)
		selected_tag.add_theme_color_override("font_color", GOLD_COLOR)
		title_hbox.add_child(selected_tag)
	
	# 描述
	var desc_label := Label.new()
	desc_label.text = config.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)
	
	# 音符列表
	var notes: Array = config.get("notes", [])
	var notes_label := Label.new()
	notes_label.text = "可用音符: %s" % " ".join(notes)
	notes_label.add_theme_font_size_override("font_size", 11)
	notes_label.add_theme_color_override("font_color", ACCENT_COLOR)
	vbox.add_child(notes_label)
	
	# 被动效果
	var passive_label := Label.new()
	passive_label.text = "被动: %s" % config.get("passive_desc", "无")
	passive_label.add_theme_font_size_override("font_size", 11)
	passive_label.add_theme_color_override("font_color", SUCCESS_COLOR)
	vbox.add_child(passive_label)
	
	# 按钮
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_hbox)
	
	if not is_unlocked:
		var unlock_btn := Button.new()
		var cost: int = config.get("cost", 0)
		unlock_btn.text = "解锁 (%d 碎片)" % cost
		unlock_btn.custom_minimum_size = Vector2(140, 35)
		unlock_btn.disabled = (_meta and _meta.resonance_fragments < cost)
		var mn := mode_name
		unlock_btn.pressed.connect(func(): _on_purchase_mode(mn))
		btn_hbox.add_child(unlock_btn)
	elif not is_selected:
		var select_btn := Button.new()
		select_btn.text = "选择此调式"
		select_btn.custom_minimum_size = Vector2(120, 35)
		var mn := mode_name
		select_btn.pressed.connect(func(): _on_select_mode(mn))
		btn_hbox.add_child(select_btn)
	
	return container

# ============================================================
# 标签切换
# ============================================================

func _switch_tab(index: int) -> void:
	_current_tab = index
	for i in range(_tab_panels.size()):
		_tab_panels[i].visible = (i == index)

# ============================================================
# 购买操作
# ============================================================

func _on_purchase_upgrade(upgrade_id: String, module: String) -> void:
	if _meta == null:
		return
	
	var success := false
	if module == "instrument":
		success = _meta.purchase_instrument_upgrade(upgrade_id)
	elif module == "acoustic":
		success = _meta.purchase_acoustic_upgrade(upgrade_id)
	
	if success:
		_refresh_all()

func _on_purchase_theory(theory_id: String) -> void:
	if _meta == null:
		return
	
	if _meta.purchase_theory_unlock(theory_id):
		_refresh_all()

func _on_purchase_mode(mode_name: String) -> void:
	if _meta == null:
		return
	
	if _meta.purchase_mode_unlock(mode_name):
		_refresh_all()

func _on_select_mode(mode_name: String) -> void:
	if _meta == null:
		return
	
	if _meta.select_mode(mode_name):
		_refresh_all()

# ============================================================
# 信号回调
# ============================================================

func _on_fragments_changed(_new_total: int) -> void:
	_update_fragments_display()

func _on_upgrade_purchased(_module: String, _upgrade_id: String, _new_level: int) -> void:
	_refresh_all()

# ============================================================
# 刷新
# ============================================================

func _update_fragments_display() -> void:
	if _fragments_label and _meta:
		_fragments_label.text = "共鸣碎片: %d" % _meta.resonance_fragments

func _refresh_all() -> void:
	_update_fragments_display()
	# 重建所有标签页内容
	for panel in _tab_panels:
		panel.queue_free()
	_tab_panels.clear()
	
	_build_instrument_tab()
	_build_theory_tab()
	_build_mode_tab()
	_build_acoustic_tab()
	
	_switch_tab(_current_tab)
