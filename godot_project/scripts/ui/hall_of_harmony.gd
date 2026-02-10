## "和谐殿堂" UI (Issue #31) - v4.0 数据统一版
## 局外成长系统的主界面，视觉风格为"神圣的音乐工作站"。
##
## ★ v4.0 修复：所有升级数据从 MetaProgressionManager 动态读取
##   消除了 v3.0 中 UI 硬编码数据与后端不一致的问题
##
## 包含四个可交互的"机架模块"：
## A. 乐器调优 (推杆/旋钮风格) — 基础属性升级
## B. 乐理研习 (技能树/五线谱风格) — 被动技能解锁
## C. 调式风格 (职业选择卡片) — 调式/职业选择
## D. 声学降噪 (调音台推杆) — 疲劳抗性升级
##
## 背景为星空与巨大发光五线谱的插画。
extends Control

# ============================================================
# 信号
# ============================================================
signal start_game_pressed()
signal back_pressed()
signal upgrade_selected(upgrade_id: String, category: String)

# ============================================================
# 配置
# ============================================================
const TAB_NAMES: Array = ["乐器调优", "乐理研习", "调式风格", "声学降噪"]
const TAB_ICONS: Array = [
	"res://assets/ui/icons/icon_tuning.png",
	"res://assets/ui/icons/icon_theory.png",
	"res://assets/ui/icons/icon_modes.png",
	"res://assets/ui/icons/icon_denoise.png"
]

# ============================================================
# 颜色方案
# ============================================================
const BG_COLOR := Color("#0A0814")
const PANEL_COLOR := Color("#141026F2")
const ACCENT_COLOR := Color("#9D6FFF")
const GOLD_COLOR := Color("#FFD700")
const TEXT_COLOR := Color("#EAE6FF")
const DIM_TEXT_COLOR := Color("#A098C8")
const SUCCESS_COLOR := Color("#4DFF80")
const LOCKED_COLOR := Color("#6B668A")
const TAB_ACTIVE_COLOR := Color("#9D6FFF4D")
const TAB_HOVER_COLOR := Color("#9D6FFF26")
const DANGER_COLOR := Color("#FF4D4D")

# ============================================================
# 节点引用
# ============================================================
var _background_texture: TextureRect = null
var _header: Control = null
var _fragments_label: Label = null
var _tab_bar: HBoxContainer = null
var _content_container: Control = null
var _tab_panels: Array[Control] = []
var _current_tab: int = 0
var _start_button: Button = null
var _back_button: Button = null
var _selected_mode: String = "ionian"

# ============================================================
# 升级状态（从 MetaProgressionManager 同步）
# ============================================================
var _resonance_fragments: int = 0

# ============================================================
# Meta 管理器引用
# ============================================================
var _meta: Node = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_meta = get_node_or_null("/root/MetaProgressionManager")
	_load_state()
	_build_ui()
	_refresh_all()

	if _meta:
		if _meta.has_signal("resonance_fragments_changed"):
			_meta.resonance_fragments_changed.connect(_on_fragments_changed)
		if _meta.has_signal("upgrade_purchased"):
			_meta.upgrade_purchased.connect(func(_m, _u, _l): _refresh_all())

# ============================================================
# 状态同步
# ============================================================

func _load_state() -> void:
	if _meta:
		_resonance_fragments = _meta.get_resonance_fragments()
		_selected_mode = _meta.get_selected_mode()

func _can_afford(cost: int) -> bool:
	return _resonance_fragments >= cost

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	# 全屏背景
	_background_texture = TextureRect.new()
	_background_texture.name = "ThemedBackground"
	_background_texture.texture = null
	_background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background_texture)

	# 半透明背景覆盖层
	var bg_overlay := ColorRect.new()
	bg_overlay.color = Color(BG_COLOR.r, BG_COLOR.g, BG_COLOR.b, 0.85)
	bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg_overlay)

	# 主容器
	var main_container := VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 12)
	add_child(main_container)

	# ---- 顶部 Header ----
	_header = HBoxContainer.new()
	_header.custom_minimum_size.y = 50

	var title_label := Label.new()
	title_label.text = "和谐殿堂"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", GOLD_COLOR)
	_header.add_child(title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(spacer)

	_fragments_label = Label.new()
	_fragments_label.text = "共鸣碎片: %d" % _resonance_fragments
	_fragments_label.add_theme_font_size_override("font_size", 16)
	_fragments_label.add_theme_color_override("font_color", GOLD_COLOR)
	_header.add_child(_fragments_label)

	main_container.add_child(_header)

	# ---- 标签栏 ----
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 4)

	for i in range(TAB_NAMES.size()):
		var tab_btn := Button.new()
		tab_btn.text = TAB_NAMES[i]
		tab_btn.custom_minimum_size = Vector2(120, 36)
		tab_btn.pressed.connect(_on_tab_selected.bind(i))
		_tab_bar.add_child(tab_btn)

	main_container.add_child(_tab_bar)

	# ---- 内容区域 ----
	_content_container = Control.new()
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_tab_panels.clear()
	var panels := [
		_build_tuning_panel(),
		_build_theory_panel(),
		_build_mode_panel(),
		_build_denoise_panel(),
	]
	for p in panels:
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.visible = false
		_content_container.add_child(p)
		_tab_panels.append(p)

	main_container.add_child(_content_container)

	# ---- 底部按钮 ----
	var btn_bar := HBoxContainer.new()
	btn_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_bar.add_theme_constant_override("separation", 16)

	_back_button = Button.new()
	_back_button.text = "返回"
	_back_button.custom_minimum_size = Vector2(120, 42)
	_back_button.pressed.connect(func(): back_pressed.emit())
	btn_bar.add_child(_back_button)

	_start_button = Button.new()
	_start_button.text = "开始演奏"
	_start_button.custom_minimum_size = Vector2(160, 42)
	_start_button.pressed.connect(func(): start_game_pressed.emit())
	btn_bar.add_child(_start_button)

	main_container.add_child(btn_bar)

	# 默认显示第一个标签页
	_select_tab(0)

# ============================================================
# A. 乐器调优面板 — 从 MetaProgressionManager.INSTRUMENT_UPGRADES 读取
# ============================================================

func _build_tuning_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "TuningPanel"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = "乐器调优 — 基础属性成长"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "通过消耗共鸣碎片提升基础属性，效果永久生效。"
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	if _meta:
		for upgrade_id in _meta.INSTRUMENT_UPGRADES:
			var config: Dictionary = _meta.INSTRUMENT_UPGRADES[upgrade_id]
			var row := _build_instrument_row(upgrade_id, config)
			vbox.add_child(row)

	scroll.add_child(vbox)
	return scroll

func _build_instrument_row(upgrade_id: String, config: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Tuning_%s" % upgrade_id

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	# 名称和描述
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = config.get("name", upgrade_id)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	info_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = config.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_label)

	# 效果描述
	var effect_desc: String = config.get("effect_desc", "")
	if effect_desc != "":
		var effect_label := Label.new()
		var epl: float = config.get("effect_per_level", 0.0)
		effect_label.text = effect_desc % int(epl)
		effect_label.add_theme_font_size_override("font_size", 9)
		effect_label.add_theme_color_override("font_color", SUCCESS_COLOR)
		info_vbox.add_child(effect_label)

	hbox.add_child(info_vbox)

	# 等级和进度
	var level: int = _meta.get_instrument_level(upgrade_id) if _meta else 0
	var max_level: int = config.get("max_level", 10)

	var level_label := Label.new()
	level_label.text = "Lv. %d / %d" % [level, max_level]
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.add_theme_color_override("font_color", GOLD_COLOR if level > 0 else DIM_TEXT_COLOR)
	hbox.add_child(level_label)

	# 购买按钮
	var btn := Button.new()
	btn.name = "TuningBtn_%s" % upgrade_id
	if level >= max_level:
		btn.text = "MAX"
		btn.disabled = true
	else:
		var cost: int = _meta.get_instrument_cost(upgrade_id) if _meta else 0
		btn.text = "升级 (%d)" % cost
		btn.disabled = not _can_afford(cost)
	btn.custom_minimum_size = Vector2(110, 32)
	btn.pressed.connect(_on_instrument_upgrade_pressed.bind(upgrade_id))
	hbox.add_child(btn)

	panel.add_child(hbox)
	return panel

# ============================================================
# B. 乐理研习面板 — 从 MetaProgressionManager.THEORY_UNLOCKS 读取
# ============================================================

func _build_theory_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "TheoryPanel"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = "乐理研习 — 解锁高级技法"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "解锁新的黑键修饰符、和弦类型和传说乐章。"
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# 技能卡片网格
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)

	if _meta:
		for theory_id in _meta.THEORY_UNLOCKS:
			var config: Dictionary = _meta.THEORY_UNLOCKS[theory_id]
			var card := _build_theory_card(theory_id, config)
			grid.add_child(card)

	vbox.add_child(grid)
	scroll.add_child(vbox)
	return scroll

func _build_theory_card(theory_id: String, config: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Theory_%s" % theory_id
	panel.custom_minimum_size = Vector2(200, 120)

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var is_unlocked: bool = _meta.is_theory_unlocked(theory_id) if _meta else false
	var can_unlock: bool = _meta.can_unlock_theory(theory_id) if _meta else false
	var cost: int = config.get("cost", 0)
	var prerequisite: String = config.get("prerequisite", "")

	# 类别标签
	var category: String = config.get("category", "")
	var category_names := {"black_key": "黑键", "chord": "和弦", "legend": "传说"}
	var cat_label := Label.new()
	cat_label.text = "[%s]" % category_names.get(category, category)
	cat_label.add_theme_font_size_override("font_size", 9)
	cat_label.add_theme_color_override("font_color", ACCENT_COLOR)
	vbox.add_child(cat_label)

	# 名称
	var name_label := Label.new()
	name_label.text = config.get("name", theory_id)
	name_label.add_theme_font_size_override("font_size", 13)
	if is_unlocked:
		name_label.add_theme_color_override("font_color", SUCCESS_COLOR)
	elif can_unlock:
		name_label.add_theme_color_override("font_color", TEXT_COLOR)
	else:
		name_label.add_theme_color_override("font_color", LOCKED_COLOR)
	vbox.add_child(name_label)

	# 描述
	var desc_label := Label.new()
	desc_label.text = config.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# 前置需求
	if prerequisite != "":
		var prereq_config: Dictionary = _meta.THEORY_UNLOCKS.get(prerequisite, {}) if _meta else {}
		var prereq_name: String = prereq_config.get("name", prerequisite)
		var prereq_met: bool = _meta.is_theory_unlocked(prerequisite) if _meta else false
		var req_label := Label.new()
		req_label.text = "需要: %s" % prereq_name
		req_label.add_theme_font_size_override("font_size", 9)
		req_label.add_theme_color_override("font_color", DIM_TEXT_COLOR if prereq_met else LOCKED_COLOR)
		vbox.add_child(req_label)

	# 解锁按钮
	var btn := Button.new()
	btn.name = "TheoryBtn_%s" % theory_id
	if is_unlocked:
		btn.text = "✓ 已解锁"
		btn.disabled = true
	elif not can_unlock:
		if prerequisite != "" and not (_meta.is_theory_unlocked(prerequisite) if _meta else false):
			btn.text = "前置未满足"
		else:
			btn.text = "碎片不足 (%d)" % cost
		btn.disabled = true
	else:
		btn.text = "解锁 (%d碎片)" % cost
		btn.disabled = false
	btn.pressed.connect(_on_theory_unlock_pressed.bind(theory_id))
	vbox.add_child(btn)

	panel.add_child(vbox)
	return panel

# ============================================================
# C. 调式风格面板 — 从 MetaProgressionManager.MODE_CONFIGS 读取
# ============================================================

func _build_mode_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "ModePanel"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = "调式风格 — 选择你的演奏风格"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "每种调式限制可用音符并提供独特的被动效果，影响整局游戏的战斗风格。"
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# 调式卡片网格
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)

	if _meta:
		for mode_name in _meta.MODE_CONFIGS:
			var config: Dictionary = _meta.MODE_CONFIGS[mode_name]
			var card := _build_mode_card(mode_name, config)
			grid.add_child(card)

	vbox.add_child(grid)
	scroll.add_child(vbox)
	return scroll

func _build_mode_card(mode_name: String, config: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Mode_%s" % mode_name
	panel.custom_minimum_size = Vector2(180, 160)

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var is_selected: bool = (_selected_mode == mode_name)
	var is_unlocked: bool = _meta.is_mode_unlocked(mode_name) if _meta else (mode_name == "ionian")
	var cost: int = config.get("cost", 0)

	# 调式图标和名称
	var header := HBoxContainer.new()
	var icon_label := Label.new()
	icon_label.text = config.get("name_en", mode_name).left(1)
	icon_label.add_theme_font_size_override("font_size", 22)
	icon_label.add_theme_color_override("font_color", ACCENT_COLOR if is_selected else TEXT_COLOR)
	header.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = "%s (%s)" % [config.get("name", mode_name), config.get("title", "")]
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", GOLD_COLOR if is_selected else TEXT_COLOR)
	header.add_child(name_label)
	vbox.add_child(header)

	# 描述
	var desc_label := Label.new()
	desc_label.text = config.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# 可用音符
	var notes: Array = config.get("notes", [])
	if not notes.is_empty():
		var notes_label := Label.new()
		notes_label.text = "音符: %s" % ", ".join(notes)
		notes_label.add_theme_font_size_override("font_size", 9)
		notes_label.add_theme_color_override("font_color", SUCCESS_COLOR)
		vbox.add_child(notes_label)

	# 被动效果
	var passive_desc: String = config.get("passive_desc", "")
	if passive_desc != "":
		var passive_label := Label.new()
		passive_label.text = "被动: %s" % passive_desc
		passive_label.add_theme_font_size_override("font_size", 9)
		passive_label.add_theme_color_override("font_color", ACCENT_COLOR)
		vbox.add_child(passive_label)

	# 按钮
	var btn := Button.new()
	btn.name = "ModeBtn_%s" % mode_name
	if is_selected:
		btn.text = "✓ 当前选择"
		btn.disabled = true
	elif not is_unlocked:
		if cost > 0:
			btn.text = "解锁 (%d碎片)" % cost
			btn.disabled = not _can_afford(cost)
		else:
			btn.text = "选择此调式"
			btn.disabled = false
	else:
		btn.text = "选择此调式"
		btn.disabled = false
	btn.pressed.connect(_on_mode_pressed.bind(mode_name))
	vbox.add_child(btn)

	panel.add_child(vbox)
	return panel

# ============================================================
# D. 声学降噪面板 — 从 MetaProgressionManager.ACOUSTIC_UPGRADES 读取
# ============================================================

func _build_denoise_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "DenoisePanel"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = "声学降噪 — 疲劳抗性强化"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "降低听感疲劳的负面影响，让你能更持久地战斗。"
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	if _meta:
		for upgrade_id in _meta.ACOUSTIC_UPGRADES:
			var config: Dictionary = _meta.ACOUSTIC_UPGRADES[upgrade_id]
			var row := _build_acoustic_row(upgrade_id, config)
			vbox.add_child(row)

	scroll.add_child(vbox)
	return scroll

func _build_acoustic_row(upgrade_id: String, config: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Acoustic_%s" % upgrade_id

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	# 名称和描述
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = config.get("name", upgrade_id)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	info_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = config.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_label)

	# 效果描述
	var effect_desc: String = config.get("effect_desc", "")
	if effect_desc != "":
		var effect_label := Label.new()
		var epl: float = config.get("effect_per_level", 0.0)
		effect_label.text = effect_desc % int(epl)
		effect_label.add_theme_font_size_override("font_size", 9)
		effect_label.add_theme_color_override("font_color", SUCCESS_COLOR)
		info_vbox.add_child(effect_label)

	hbox.add_child(info_vbox)

	# 等级
	var level: int = _meta.get_acoustic_level(upgrade_id) if _meta else 0
	var max_level: int = config.get("max_level", 3)

	var level_label := Label.new()
	level_label.text = "Lv. %d / %d" % [level, max_level]
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.add_theme_color_override("font_color", GOLD_COLOR if level > 0 else DIM_TEXT_COLOR)
	hbox.add_child(level_label)

	# 购买按钮
	var btn := Button.new()
	btn.name = "AcousticBtn_%s" % upgrade_id
	if level >= max_level:
		btn.text = "MAX"
		btn.disabled = true
	else:
		var cost: int = _meta.get_acoustic_cost(upgrade_id) if _meta else 0
		btn.text = "升级 (%d)" % cost
		btn.disabled = not _can_afford(cost)
	btn.custom_minimum_size = Vector2(110, 32)
	btn.pressed.connect(_on_acoustic_upgrade_pressed.bind(upgrade_id))
	hbox.add_child(btn)

	panel.add_child(hbox)
	return panel

# ============================================================
# 标签页切换
# ============================================================

func _select_tab(index: int) -> void:
	if index < 0 or index >= _tab_panels.size():
		return

	_current_tab = index
	for i in range(_tab_panels.size()):
		_tab_panels[i].visible = (i == index)
		var tab_button := _tab_bar.get_child(i) as Button
		if i == index:
			tab_button.disabled = true
		else:
			tab_button.disabled = false

# ============================================================
# 交互回调
# ============================================================

func _on_tab_selected(index: int) -> void:
	_select_tab(index)

func _on_instrument_upgrade_pressed(upgrade_id: String) -> void:
	if _meta and _meta.has_method("purchase_instrument_upgrade"):
		if _meta.purchase_instrument_upgrade(upgrade_id):
			upgrade_selected.emit(upgrade_id, "instrument")
			_refresh_all()

func _on_theory_unlock_pressed(theory_id: String) -> void:
	if _meta and _meta.has_method("purchase_theory_unlock"):
		if _meta.purchase_theory_unlock(theory_id):
			upgrade_selected.emit(theory_id, "theory")
			_refresh_all()

func _on_acoustic_upgrade_pressed(upgrade_id: String) -> void:
	if _meta and _meta.has_method("purchase_acoustic_upgrade"):
		if _meta.purchase_acoustic_upgrade(upgrade_id):
			upgrade_selected.emit(upgrade_id, "acoustic")
			_refresh_all()

func _on_mode_pressed(mode_name: String) -> void:
	if not _meta:
		return

	var is_unlocked: bool = _meta.is_mode_unlocked(mode_name)
	if not is_unlocked:
		# 需要先解锁
		if _meta.has_method("purchase_mode_unlock"):
			if not _meta.purchase_mode_unlock(mode_name):
				return  # 购买失败（碎片不足）

	# 选择调式
	if _meta.has_method("select_mode"):
		_meta.select_mode(mode_name)
		_selected_mode = mode_name
		upgrade_selected.emit(mode_name, "mode")
		_refresh_all()

# ============================================================
# 刷新
# ============================================================

func _refresh_all() -> void:
	_load_state()

	if _fragments_label:
		_fragments_label.text = "共鸣碎片: %d" % _resonance_fragments

	# 重建当前标签页内容
	_rebuild_current_tab()

func _rebuild_current_tab() -> void:
	if _current_tab < 0 or _current_tab >= _tab_panels.size():
		return

	var old_panel := _tab_panels[_current_tab]
	var new_panel: Control
	match _current_tab:
		0: new_panel = _build_tuning_panel()
		1: new_panel = _build_theory_panel()
		2: new_panel = _build_mode_panel()
		3: new_panel = _build_denoise_panel()
		_: return

	new_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	new_panel.visible = true

	# 替换面板
	var parent := old_panel.get_parent()
	var idx := old_panel.get_index()
	parent.remove_child(old_panel)
	old_panel.queue_free()
	parent.add_child(new_panel)
	parent.move_child(new_panel, idx)
	_tab_panels[_current_tab] = new_panel

func _on_fragments_changed(new_total: int) -> void:
	_resonance_fragments = new_total
	if _fragments_label:
		_fragments_label.text = "共鸣碎片: %d" % new_total
	_rebuild_current_tab()
