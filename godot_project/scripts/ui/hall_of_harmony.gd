## "和谐殿堂" UI (Issue #31) - v3.0 Full Interactive
## 局外成长系统的主界面，视觉风格为"神圣的音乐工作站"。
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
# 升级数据定义
# ============================================================

## A. 乐器调优 — 基础属性推杆
const TUNING_UPGRADES: Array = [
	{
		"id": "dmg_boost", "name": "音量增幅", "desc": "提升所有音符弹体的基础伤害",
		"icon": "♪", "max_level": 10, "cost_base": 50, "cost_scale": 1.5,
		"stat": "damage_mult", "value_per_level": 0.08,
	},
	{
		"id": "spd_boost", "name": "节拍加速", "desc": "提升弹体飞行速度",
		"icon": "♫", "max_level": 8, "cost_base": 40, "cost_scale": 1.4,
		"stat": "speed_mult", "value_per_level": 0.06,
	},
	{
		"id": "size_boost", "name": "共鸣扩展", "desc": "增大弹体碰撞范围",
		"icon": "◎", "max_level": 6, "cost_base": 60, "cost_scale": 1.6,
		"stat": "size_mult", "value_per_level": 0.05,
	},
	{
		"id": "hp_boost", "name": "生命和弦", "desc": "增加最大生命值",
		"icon": "♥", "max_level": 10, "cost_base": 45, "cost_scale": 1.4,
		"stat": "max_hp_bonus", "value_per_level": 10.0,
	},
	{
		"id": "crit_boost", "name": "布鲁斯之魂", "desc": "提升布鲁斯暴击率",
		"icon": "★", "max_level": 5, "cost_base": 80, "cost_scale": 1.8,
		"stat": "crit_rate_bonus", "value_per_level": 0.03,
	},
]

## B. 乐理研习 — 被动技能树
const THEORY_SKILLS: Array = [
	{
		"id": "chord_mastery", "name": "和弦精通", "desc": "和弦法术伤害+15%，冷却-10%",
		"icon": "🎵", "cost": 120, "requires": [],
		"effect": {"chord_damage_mult": 1.15, "chord_cooldown_mult": 0.9},
	},
	{
		"id": "rhythm_sense", "name": "节奏感知", "desc": "完美节拍的判定窗口+20%",
		"icon": "🥁", "cost": 80, "requires": [],
		"effect": {"perfect_beat_window_mult": 1.2},
	},
	{
		"id": "harmonic_shield", "name": "谐波护盾", "desc": "和弦进行完成时获得短暂护盾",
		"icon": "🛡", "cost": 150, "requires": ["chord_mastery"],
		"effect": {"progression_shield": true, "shield_amount": 20},
	},
	{
		"id": "echo_mastery", "name": "回响精通", "desc": "回响修饰符效果翻倍",
		"icon": "🔊", "cost": 100, "requires": ["rhythm_sense"],
		"effect": {"echo_power_mult": 2.0},
	},
	{
		"id": "rest_power", "name": "休止蓄力", "desc": "休止符蓄力加成+25%",
		"icon": "⏸", "cost": 90, "requires": [],
		"effect": {"rest_charge_mult": 1.25},
	},
	{
		"id": "modulation_master", "name": "转调大师", "desc": "解锁转调能力，切换调式不消耗时间",
		"icon": "🔄", "cost": 200, "requires": ["chord_mastery", "rhythm_sense"],
		"effect": {"free_modulation": true},
	},
	{
		"id": "perfect_pitch", "name": "绝对音感", "desc": "所有音符伤害+10%，疲劳积累-15%",
		"icon": "🎯", "cost": 300, "requires": ["modulation_master"],
		"effect": {"all_damage_mult": 1.1, "fatigue_rate_mult": 0.85},
	},
]

## C. 调式风格 — 职业/调式选择
const MODE_STYLES: Array = [
	{
		"id": "ionian", "name": "伊奥尼亚 (大调)",
		"desc": "均衡型。所有属性+5%，无特殊惩罚。适合新手。",
		"color": Color(0.4, 0.8, 1.0), "icon": "I",
		"bonuses": {"all_stats": 1.05},
		"penalties": {},
	},
	{
		"id": "dorian", "name": "多利亚 (小调)",
		"desc": "防御型。生命+20%，护盾效果+30%，伤害-10%。",
		"color": Color(0.3, 0.6, 1.0), "icon": "II",
		"bonuses": {"hp_mult": 1.2, "shield_mult": 1.3},
		"penalties": {"damage_mult": 0.9},
	},
	{
		"id": "phrygian", "name": "弗里几亚",
		"desc": "DOT型。持续伤害+40%，直接伤害-15%，移速+10%。",
		"color": Color(0.8, 0.3, 0.3), "icon": "III",
		"bonuses": {"dot_mult": 1.4, "move_speed_mult": 1.1},
		"penalties": {"direct_damage_mult": 0.85},
	},
	{
		"id": "lydian", "name": "利底亚",
		"desc": "爆发型。暴击率+15%，暴击伤害+50%，生命-15%。",
		"color": Color(1.0, 0.8, 0.2), "icon": "IV",
		"bonuses": {"crit_rate": 0.15, "crit_damage_mult": 1.5},
		"penalties": {"hp_mult": 0.85},
	},
	{
		"id": "mixolydian", "name": "混合利底亚",
		"desc": "召唤型。召唤物伤害+35%，召唤物持续时间+50%，自身伤害-20%。",
		"color": Color(0.5, 1.0, 0.5), "icon": "V",
		"bonuses": {"summon_damage_mult": 1.35, "summon_duration_mult": 1.5},
		"penalties": {"self_damage_mult": 0.8},
	},
	{
		"id": "aeolian", "name": "爱奥利亚 (自然小调)",
		"desc": "法阵型。法阵范围+30%，法阵持续+40%，移速-10%。",
		"color": Color(0.6, 0.3, 0.8), "icon": "VI",
		"bonuses": {"field_range_mult": 1.3, "field_duration_mult": 1.4},
		"penalties": {"move_speed_mult": 0.9},
	},
	{
		"id": "locrian", "name": "洛克里亚",
		"desc": "高风险型。所有伤害+30%，生命-30%，疲劳积累+20%。",
		"color": Color(0.9, 0.2, 0.5), "icon": "VII",
		"bonuses": {"all_damage_mult": 1.3},
		"penalties": {"hp_mult": 0.7, "fatigue_rate_mult": 1.2},
	},
]

## D. 声学降噪 — 疲劳抗性推杆
const DENOISE_UPGRADES: Array = [
	{
		"id": "fatigue_resist", "name": "听感耐受", "desc": "降低疲劳积累速率",
		"icon": "🔇", "max_level": 8, "cost_base": 60, "cost_scale": 1.5,
		"stat": "fatigue_rate_mult", "value_per_level": -0.04,
	},
	{
		"id": "recovery_speed", "name": "恢复速率", "desc": "提升疲劳自然恢复速度",
		"icon": "💤", "max_level": 6, "cost_base": 70, "cost_scale": 1.6,
		"stat": "fatigue_recovery_mult", "value_per_level": 0.08,
	},
	{
		"id": "silence_resist", "name": "静默抗性", "desc": "降低单音寂静的禁用时长",
		"icon": "🔕", "max_level": 5, "cost_base": 80, "cost_scale": 1.7,
		"stat": "silence_duration_mult", "value_per_level": -0.06,
	},
	{
		"id": "density_tolerance", "name": "密度容忍", "desc": "提高密度过载的触发阈值",
		"icon": "📊", "max_level": 5, "cost_base": 90, "cost_scale": 1.8,
		"stat": "density_threshold_bonus", "value_per_level": 0.1,
	},
]

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
# 升级状态 (从 MetaProgressionManager 同步)
# ============================================================
var _upgrade_levels: Dictionary = {}  # { "dmg_boost": 3, ... }
var _unlocked_skills: Array[String] = []
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
	_load_upgrade_state()
	_build_ui()
	_refresh_all()

	if _meta:
		if _meta.has_signal("resonance_fragments_changed"):
			_meta.resonance_fragments_changed.connect(_on_fragments_changed)
		if _meta.has_signal("upgrade_purchased"):
			_meta.upgrade_purchased.connect(_on_upgrade_purchased)

# ============================================================
# 升级状态管理
# ============================================================

func _load_upgrade_state() -> void:
	if _meta and _meta.has_method("get_upgrade_levels"):
		_upgrade_levels = _meta.get_upgrade_levels()
	if _meta and _meta.has_method("get_unlocked_skills"):
		_unlocked_skills = _meta.get_unlocked_skills()
	if _meta and _meta.has_method("get_selected_mode"):
		_selected_mode = _meta.get_selected_mode()
	if _meta and _meta.has_method("get_resonance_fragments"):
		_resonance_fragments = _meta.get_resonance_fragments()

func _get_upgrade_level(upgrade_id: String) -> int:
	return _upgrade_levels.get(upgrade_id, 0)

func _get_upgrade_cost(upgrade_data: Dictionary) -> int:
	var level := _get_upgrade_level(upgrade_data["id"])
	var base: int = upgrade_data.get("cost_base", 50)
	var scale: float = upgrade_data.get("cost_scale", 1.5)
	return int(base * pow(scale, level))

func _can_afford(cost: int) -> bool:
	return _resonance_fragments >= cost

func _is_skill_unlocked(skill_id: String) -> bool:
	return skill_id in _unlocked_skills

func _are_requirements_met(skill_data: Dictionary) -> bool:
	var requires: Array = skill_data.get("requires", [])
	for req_id in requires:
		if req_id not in _unlocked_skills:
			return false
	return true

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	# 全屏背景
	_background_texture = TextureRect.new()
	_background_texture.name = "ThemedBackground"
	_background_texture.texture = null  # 占位，实际从资源加载
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
	title_label.text = "✦ 和 谐 殿 堂 ✦"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", GOLD_COLOR)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(title_label)

	_fragments_label = Label.new()
	_fragments_label.text = "共鸣碎片: %d" % _resonance_fragments
	_fragments_label.add_theme_font_size_override("font_size", 16)
	_fragments_label.add_theme_color_override("font_color", GOLD_COLOR)
	_fragments_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fragments_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_fragments_label)

	main_container.add_child(_header)

	# ---- 标签页栏 ----
	_tab_bar = HBoxContainer.new()
	_tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_bar.custom_minimum_size.y = 44
	_tab_bar.add_theme_constant_override("separation", 8)
	main_container.add_child(_tab_bar)

	# ---- 内容容器 ----
	_content_container = Control.new()
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(_content_container)

	# 创建标签页和面板
	for i in range(TAB_NAMES.size()):
		var tab_button := Button.new()
		tab_button.text = TAB_NAMES[i]
		tab_button.custom_minimum_size = Vector2(120, 36)
		tab_button.pressed.connect(_on_tab_selected.bind(i))
		_tab_bar.add_child(tab_button)

		var panel: Control
		match i:
			0: panel = _build_tuning_panel()
			1: panel = _build_theory_panel()
			2: panel = _build_mode_panel()
			3: panel = _build_denoise_panel()
			_: panel = _build_placeholder_panel(TAB_NAMES[i])

		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.visible = false
		_content_container.add_child(panel)
		_tab_panels.append(panel)

	# ---- 底部操作栏 ----
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.custom_minimum_size.y = 60
	footer.add_theme_constant_override("separation", 20)

	_back_button = Button.new()
	_back_button.text = "← 返回"
	_back_button.custom_minimum_size = Vector2(100, 40)
	_back_button.pressed.connect(func(): back_pressed.emit())
	footer.add_child(_back_button)

	_start_button = Button.new()
	_start_button.text = "♪ 开始远征 ♪"
	_start_button.custom_minimum_size = Vector2(160, 40)
	_start_button.pressed.connect(func(): start_game_pressed.emit())
	footer.add_child(_start_button)

	main_container.add_child(footer)

	_select_tab(0)

# ============================================================
# A. 乐器调优面板 — 推杆式属性升级
# ============================================================

func _build_tuning_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "TuningPanel"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 面板标题
	var title := Label.new()
	title.text = "乐器调优 — 基础属性强化"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "消耗共鸣碎片提升基础属性。每个属性有独立的升级上限。"
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# 升级推杆列表
	for upgrade in TUNING_UPGRADES:
		var row := _build_upgrade_slider_row(upgrade, "tuning")
		vbox.add_child(row)

	scroll.add_child(vbox)
	return scroll

func _build_upgrade_slider_row(upgrade: Dictionary, category: String) -> Control:
	var hbox := HBoxContainer.new()
	hbox.name = "Row_%s" % upgrade["id"]
	hbox.custom_minimum_size.y = 56
	hbox.add_theme_constant_override("separation", 10)

	# 图标
	var icon_label := Label.new()
	icon_label.text = upgrade.get("icon", "?")
	icon_label.add_theme_font_size_override("font_size", 20)
	icon_label.custom_minimum_size.x = 32
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(icon_label)

	# 名称和描述
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = upgrade["name"]
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	info_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = upgrade["desc"]
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	info_vbox.add_child(desc_label)

	hbox.add_child(info_vbox)

	# 等级进度条 (模拟推杆)
	var level := _get_upgrade_level(upgrade["id"])
	var max_level: int = upgrade.get("max_level", 10)

	var progress := ProgressBar.new()
	progress.name = "Progress_%s" % upgrade["id"]
	progress.min_value = 0
	progress.max_value = max_level
	progress.value = level
	progress.custom_minimum_size = Vector2(120, 20)
	progress.show_percentage = false
	hbox.add_child(progress)

	# 等级文字
	var level_label := Label.new()
	level_label.name = "Level_%s" % upgrade["id"]
	level_label.text = "%d/%d" % [level, max_level]
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", TEXT_COLOR)
	level_label.custom_minimum_size.x = 40
	hbox.add_child(level_label)

	# 升级按钮
	var cost := _get_upgrade_cost(upgrade)
	var btn := Button.new()
	btn.name = "Btn_%s" % upgrade["id"]
	if level >= max_level:
		btn.text = "MAX"
		btn.disabled = true
	else:
		btn.text = "↑ %d" % cost
		btn.disabled = not _can_afford(cost)
	btn.custom_minimum_size = Vector2(80, 32)
	btn.pressed.connect(_on_upgrade_pressed.bind(upgrade["id"], category))
	hbox.add_child(btn)

	return hbox

# ============================================================
# B. 乐理研习面板 — 技能树
# ============================================================

func _build_theory_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "TheoryPanel"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = "乐理研习 — 被动技能树"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "解锁被动技能以增强战斗能力。部分技能需要先解锁前置技能。"
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# 技能卡片网格
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)

	for skill in THEORY_SKILLS:
		var card := _build_skill_card(skill)
		grid.add_child(card)

	vbox.add_child(grid)
	scroll.add_child(vbox)
	return scroll

func _build_skill_card(skill: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Skill_%s" % skill["id"]
	panel.custom_minimum_size = Vector2(200, 120)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var is_unlocked := _is_skill_unlocked(skill["id"])
	var reqs_met := _are_requirements_met(skill)
	var cost: int = skill.get("cost", 100)

	# 技能名称
	var name_hbox := HBoxContainer.new()
	var icon_label := Label.new()
	icon_label.text = skill.get("icon", "?")
	icon_label.add_theme_font_size_override("font_size", 18)
	name_hbox.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = skill["name"]
	name_label.add_theme_font_size_override("font_size", 13)
	if is_unlocked:
		name_label.add_theme_color_override("font_color", SUCCESS_COLOR)
	elif reqs_met:
		name_label.add_theme_color_override("font_color", TEXT_COLOR)
	else:
		name_label.add_theme_color_override("font_color", LOCKED_COLOR)
	name_hbox.add_child(name_label)
	vbox.add_child(name_hbox)

	# 描述
	var desc_label := Label.new()
	desc_label.text = skill["desc"]
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# 前置需求
	var requires: Array = skill.get("requires", [])
	if not requires.is_empty():
		var req_label := Label.new()
		var req_names := []
		for req_id in requires:
			for s in THEORY_SKILLS:
				if s["id"] == req_id:
					req_names.append(s["name"])
		req_label.text = "需要: %s" % ", ".join(req_names)
		req_label.add_theme_font_size_override("font_size", 9)
		req_label.add_theme_color_override("font_color", LOCKED_COLOR if not reqs_met else DIM_TEXT_COLOR)
		vbox.add_child(req_label)

	# 解锁按钮
	var btn := Button.new()
	btn.name = "SkillBtn_%s" % skill["id"]
	if is_unlocked:
		btn.text = "✓ 已解锁"
		btn.disabled = true
	elif not reqs_met:
		btn.text = "🔒 未满足前置"
		btn.disabled = true
	else:
		btn.text = "解锁 (%d碎片)" % cost
		btn.disabled = not _can_afford(cost)
	btn.pressed.connect(_on_skill_pressed.bind(skill["id"]))
	vbox.add_child(btn)

	panel.add_child(vbox)
	return panel

# ============================================================
# C. 调式风格面板 — 职业选择卡片
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
	desc.text = "每种调式提供独特的加成与惩罚，影响整局游戏的战斗风格。"
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# 调式卡片网格
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)

	for mode in MODE_STYLES:
		var card := _build_mode_card(mode)
		grid.add_child(card)

	vbox.add_child(grid)
	scroll.add_child(vbox)
	return scroll

func _build_mode_card(mode: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Mode_%s" % mode["id"]
	panel.custom_minimum_size = Vector2(180, 160)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var is_selected: bool = (_selected_mode == mode["id"])

	# 调式图标和名称
	var header := HBoxContainer.new()
	var icon_label := Label.new()
	icon_label.text = mode.get("icon", "?")
	icon_label.add_theme_font_size_override("font_size", 22)
	icon_label.add_theme_color_override("font_color", mode.get("color", TEXT_COLOR))
	header.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = mode["name"]
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", mode.get("color", TEXT_COLOR) if is_selected else TEXT_COLOR)
	header.add_child(name_label)
	vbox.add_child(header)

	# 描述
	var desc_label := Label.new()
	desc_label.text = mode["desc"]
	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# 加成列表
	var bonuses: Dictionary = mode.get("bonuses", {})
	if not bonuses.is_empty():
		var bonus_label := Label.new()
		var bonus_texts := []
		for key in bonuses:
			bonus_texts.append("+ %s: %s" % [key, str(bonuses[key])])
		bonus_label.text = "\n".join(bonus_texts)
		bonus_label.add_theme_font_size_override("font_size", 9)
		bonus_label.add_theme_color_override("font_color", SUCCESS_COLOR)
		vbox.add_child(bonus_label)

	# 惩罚列表
	var penalties: Dictionary = mode.get("penalties", {})
	if not penalties.is_empty():
		var penalty_label := Label.new()
		var penalty_texts := []
		for key in penalties:
			penalty_texts.append("- %s: %s" % [key, str(penalties[key])])
		penalty_label.text = "\n".join(penalty_texts)
		penalty_label.add_theme_font_size_override("font_size", 9)
		penalty_label.add_theme_color_override("font_color", DANGER_COLOR)
		vbox.add_child(penalty_label)

	# 选择按钮
	var btn := Button.new()
	btn.name = "ModeBtn_%s" % mode["id"]
	if is_selected:
		btn.text = "✓ 当前选择"
		btn.disabled = true
	else:
		btn.text = "选择此调式"
	btn.pressed.connect(_on_mode_selected.bind(mode["id"]))
	vbox.add_child(btn)

	panel.add_child(vbox)
	return panel

# ============================================================
# D. 声学降噪面板 — 疲劳抗性推杆
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

	for upgrade in DENOISE_UPGRADES:
		var row := _build_upgrade_slider_row(upgrade, "denoise")
		vbox.add_child(row)

	scroll.add_child(vbox)
	return scroll

# ============================================================
# 占位面板
# ============================================================

func _build_placeholder_panel(tab_name: String) -> Control:
	var panel := PanelContainer.new()
	var label := Label.new()
	label.text = "内容模块: %s (开发中)" % tab_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
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

func _on_upgrade_pressed(upgrade_id: String, category: String) -> void:
	# 查找升级数据
	var upgrade_data: Dictionary = {}
	var source_array: Array = TUNING_UPGRADES if category == "tuning" else DENOISE_UPGRADES
	for u in source_array:
		if u["id"] == upgrade_id:
			upgrade_data = u
			break

	if upgrade_data.is_empty():
		return

	var level := _get_upgrade_level(upgrade_id)
	var max_level: int = upgrade_data.get("max_level", 10)
	if level >= max_level:
		return

	var cost := _get_upgrade_cost(upgrade_data)
	if not _can_afford(cost):
		return

	# 执行购买
	if _meta and _meta.has_method("purchase_upgrade"):
		_meta.purchase_upgrade(upgrade_id, cost)
	else:
		# 本地模拟
		_resonance_fragments -= cost
		_upgrade_levels[upgrade_id] = level + 1

	upgrade_selected.emit(upgrade_id, category)
	_refresh_all()

func _on_skill_pressed(skill_id: String) -> void:
	var skill_data: Dictionary = {}
	for s in THEORY_SKILLS:
		if s["id"] == skill_id:
			skill_data = s
			break

	if skill_data.is_empty():
		return

	if _is_skill_unlocked(skill_id):
		return

	if not _are_requirements_met(skill_data):
		return

	var cost: int = skill_data.get("cost", 100)
	if not _can_afford(cost):
		return

	# 执行解锁
	if _meta and _meta.has_method("unlock_skill"):
		_meta.unlock_skill(skill_id, cost)
	else:
		_resonance_fragments -= cost
		_unlocked_skills.append(skill_id)

	upgrade_selected.emit(skill_id, "theory")
	_refresh_all()

func _on_mode_selected(mode_id: String) -> void:
	_selected_mode = mode_id
	if _meta and _meta.has_method("set_selected_mode"):
		_meta.set_selected_mode(mode_id)
	upgrade_selected.emit(mode_id, "mode")
	_refresh_all()

# ============================================================
# 刷新
# ============================================================

func _refresh_all() -> void:
	_load_upgrade_state()

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

func _on_upgrade_purchased(_upgrade_id: String, _cost: int) -> void:
	_refresh_all()
