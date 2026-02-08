## codex_ui.gd
## 图鉴系统 "谐振法典 (Codex Resonare)" UI 主界面
##
## 视觉风格：暗色调 + 发光边框 + 古典书卷感
## 布局：顶部标题栏 + 左侧卷标签页 + 右侧条目列表/详情
##
## 四卷分页：
##   第一卷：乐理纲要 (子分类: 音符/和弦/扩展和弦/节奏型/调式)
##   第二卷：百相众声 (音色系别)
##   第三卷：失谐魔物 (子分类: 基础敌人/章节敌人/精英/Boss)
##   第四卷：神兵乐章 (子分类: 修饰符/和弦进行)
extends Control

# ============================================================
# 信号
# ============================================================
signal back_pressed()

# ============================================================
# 常量 — 颜色方案
# ============================================================
const BG_COLOR := Color(0.04, 0.03, 0.08)
const PANEL_BG := Color(0.08, 0.06, 0.14, 0.95)
const HEADER_BG := Color(0.06, 0.04, 0.10, 0.98)
const TAB_ACTIVE := Color(0.5, 0.3, 0.9, 0.4)
const TAB_HOVER := Color(0.5, 0.3, 0.9, 0.2)
const TAB_NORMAL := Color(0.1, 0.08, 0.16, 0.8)
const ACCENT := Color(0.6, 0.4, 1.0)
const GOLD := Color(1.0, 0.85, 0.2)
const TEXT_PRIMARY := Color(0.92, 0.90, 0.96)
const TEXT_SECONDARY := Color(0.55, 0.52, 0.62)
const TEXT_DIM := Color(0.35, 0.32, 0.42)
const LOCKED_BG := Color(0.06, 0.05, 0.10, 0.9)
const LOCKED_TEXT := Color(0.25, 0.22, 0.32)
const ENTRY_BG := Color(0.10, 0.08, 0.18, 0.9)
const ENTRY_HOVER := Color(0.14, 0.11, 0.24, 0.95)
const ENTRY_SELECTED := Color(0.18, 0.14, 0.30, 0.98)
const DETAIL_BG := Color(0.07, 0.05, 0.12, 0.95)

# ============================================================
# 卷配置
# ============================================================
const VOLUME_CONFIG: Array = [
	{
		"name": "第一卷：乐理纲要",
		"icon": "I",
		"subcategories": [
			{ "name": "音符", "data_key": "VOL1_NOTES" },
			{ "name": "和弦", "data_key": "VOL1_CHORDS" },
			{ "name": "扩展和弦", "data_key": "VOL1_EXTENDED_CHORDS" },
			{ "name": "节奏型", "data_key": "VOL1_RHYTHMS" },
			{ "name": "调式", "data_key": "VOL1_MODES" },
		],
	},
	{
		"name": "第二卷：百相众声",
		"icon": "II",
		"subcategories": [
			{ "name": "音色系别", "data_key": "VOL2_TIMBRES" },
		],
	},
	{
		"name": "第三卷：失谐魔物",
		"icon": "III",
		"subcategories": [
			{ "name": "基础敌人", "data_key": "VOL3_BASIC_ENEMIES" },
			{ "name": "章节敌人", "data_key": "VOL3_CHAPTER_ENEMIES" },
			{ "name": "精英", "data_key": "VOL3_ELITES" },
			{ "name": "Boss", "data_key": "VOL3_BOSSES" },
		],
	},
	{
		"name": "第四卷：神兵乐章",
		"icon": "IV",
		"subcategories": [
			{ "name": "修饰符", "data_key": "VOL4_MODIFIERS" },
			{ "name": "和弦进行", "data_key": "VOL4_PROGRESSIONS" },
		],
	},
]

# ============================================================
# 节点引用
# ============================================================
var _bg: ColorRect = null
var _header: PanelContainer = null
var _title_label: Label = null
var _completion_label: Label = null
var _back_button: Button = null
var _volume_tabs: VBoxContainer = null
var _content_area: HSplitContainer = null
var _entry_list_panel: PanelContainer = null
var _entry_list_scroll: ScrollContainer = null
var _entry_list: VBoxContainer = null
var _detail_panel: PanelContainer = null
var _detail_scroll: ScrollContainer = null
var _detail_content: VBoxContainer = null
var _subcategory_bar: HBoxContainer = null

# ============================================================
# 状态
# ============================================================
var _current_volume: int = 0
var _current_subcategory: int = 0
var _selected_entry_id: String = ""
var _time: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_build_ui()
	_populate_volume_tabs()
	_select_volume(0)

	# 连接图鉴管理器信号
	if CodexManager:
		if CodexManager.has_signal("entry_unlocked"):
			CodexManager.entry_unlocked.connect(_on_entry_unlocked)

func _process(delta: float) -> void:
	_time += delta
	# 标题呼吸动画
	if _title_label:
		var glow := sin(_time * 1.2) * 0.15 + 0.85
		_title_label.modulate.a = glow

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	# 根节点设置
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 背景
	_bg = ColorRect.new()
	_bg.set_anchors_preset(PRESET_FULL_RECT)
	_bg.color = BG_COLOR
	add_child(_bg)

	# 主布局（垂直）
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(PRESET_FULL_RECT)
	main_vbox.set_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, 0)
	add_child(main_vbox)

	# ---- 顶部标题栏 ----
	_header = PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = HEADER_BG
	header_style.border_color = ACCENT * 0.5
	header_style.border_width_bottom = 1
	header_style.content_margin_left = 24
	header_style.content_margin_right = 24
	header_style.content_margin_top = 12
	header_style.content_margin_bottom = 12
	_header.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(_header)

	var header_hbox := HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_header.add_child(header_hbox)

	# 返回按钮
	_back_button = Button.new()
	_back_button.text = "< 返回"
	_back_button.custom_minimum_size = Vector2(80, 36)
	_style_button(_back_button, Color(0.4, 0.35, 0.5))
	_back_button.pressed.connect(func(): back_pressed.emit())
	header_hbox.add_child(_back_button)

	# 间隔
	var spacer1 := Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer1)

	# 标题
	_title_label = Label.new()
	_title_label.text = "CODEX RESONARE — 谐振法典"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", GOLD)
	header_hbox.add_child(_title_label)

	# 间隔
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer2)

	# 完成度标签
	_completion_label = Label.new()
	_completion_label.add_theme_font_size_override("font_size", 14)
	_completion_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	header_hbox.add_child(_completion_label)

	# ---- 主体区域（水平：左侧卷标签 + 右侧内容） ----
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(body_hbox)

	# 左侧卷标签栏
	var tab_panel := PanelContainer.new()
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = Color(0.06, 0.04, 0.10, 0.95)
	tab_style.border_color = ACCENT * 0.3
	tab_style.border_width_right = 1
	tab_style.content_margin_left = 8
	tab_style.content_margin_right = 8
	tab_style.content_margin_top = 16
	tab_style.content_margin_bottom = 16
	tab_panel.add_theme_stylebox_override("panel", tab_style)
	tab_panel.custom_minimum_size.x = 200
	body_hbox.add_child(tab_panel)

	_volume_tabs = VBoxContainer.new()
	_volume_tabs.add_theme_constant_override("separation", 8)
	tab_panel.add_child(_volume_tabs)

	# 右侧内容区域（垂直：子分类栏 + 水平分割：列表 + 详情）
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(right_vbox)

	# 子分类标签栏
	var subcat_panel := PanelContainer.new()
	var subcat_style := StyleBoxFlat.new()
	subcat_style.bg_color = Color(0.07, 0.05, 0.12, 0.9)
	subcat_style.border_color = ACCENT * 0.2
	subcat_style.border_width_bottom = 1
	subcat_style.content_margin_left = 16
	subcat_style.content_margin_right = 16
	subcat_style.content_margin_top = 8
	subcat_style.content_margin_bottom = 8
	subcat_panel.add_theme_stylebox_override("panel", subcat_style)
	right_vbox.add_child(subcat_panel)

	_subcategory_bar = HBoxContainer.new()
	_subcategory_bar.add_theme_constant_override("separation", 8)
	subcat_panel.add_child(_subcategory_bar)

	# 内容分割区域
	_content_area = HSplitContainer.new()
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_area.split_offset = 380
	right_vbox.add_child(_content_area)

	# 条目列表面板
	_entry_list_panel = PanelContainer.new()
	var list_style := StyleBoxFlat.new()
	list_style.bg_color = PANEL_BG
	list_style.content_margin_left = 8
	list_style.content_margin_right = 8
	list_style.content_margin_top = 8
	list_style.content_margin_bottom = 8
	_entry_list_panel.add_theme_stylebox_override("panel", list_style)
	_entry_list_panel.custom_minimum_size.x = 320
	_content_area.add_child(_entry_list_panel)

	_entry_list_scroll = ScrollContainer.new()
	_entry_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entry_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_list_panel.add_child(_entry_list_scroll)

	_entry_list = VBoxContainer.new()
	_entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_list.add_theme_constant_override("separation", 4)
	_entry_list_scroll.add_child(_entry_list)

	# 详情面板
	_detail_panel = PanelContainer.new()
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = DETAIL_BG
	detail_style.border_color = ACCENT * 0.3
	detail_style.border_width_left = 1
	detail_style.content_margin_left = 20
	detail_style.content_margin_right = 20
	detail_style.content_margin_top = 20
	detail_style.content_margin_bottom = 20
	_detail_panel.add_theme_stylebox_override("panel", detail_style)
	_content_area.add_child(_detail_panel)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(_detail_scroll)

	_detail_content = VBoxContainer.new()
	_detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_content.add_theme_constant_override("separation", 12)
	_detail_scroll.add_child(_detail_content)

	_update_completion_label()

# ============================================================
# 卷标签页
# ============================================================

func _populate_volume_tabs() -> void:
	for child in _volume_tabs.get_children():
		child.queue_free()

	for i in range(VOLUME_CONFIG.size()):
		var config: Dictionary = VOLUME_CONFIG[i]
		var btn := Button.new()
		btn.text = "%s  %s" % [config["icon"], config["name"]]
		btn.custom_minimum_size = Vector2(180, 44)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_select_volume.bind(i))
		_style_tab_button(btn, i == _current_volume)

		# 完成度标签
		var volume_enum: int = i  # CodexData.Volume 枚举值与索引一致
		if CodexManager:
			var comp := CodexManager.get_volume_completion(volume_enum)
			btn.text += "  [%d/%d]" % [comp["unlocked"], comp["total"]]

		_volume_tabs.add_child(btn)

func _select_volume(index: int) -> void:
	_current_volume = index
	_current_subcategory = 0
	_selected_entry_id = ""

	# 更新标签页高亮
	var tabs := _volume_tabs.get_children()
	for i in range(tabs.size()):
		if tabs[i] is Button:
			_style_tab_button(tabs[i], i == _current_volume)

	# 更新子分类栏
	_populate_subcategory_bar()

	# 更新条目列表
	_populate_entry_list()

	# 清空详情
	_clear_detail()

# ============================================================
# 子分类标签
# ============================================================

func _populate_subcategory_bar() -> void:
	for child in _subcategory_bar.get_children():
		child.queue_free()

	var config: Dictionary = VOLUME_CONFIG[_current_volume]
	var subcats: Array = config["subcategories"]

	for i in range(subcats.size()):
		var subcat: Dictionary = subcats[i]
		var btn := Button.new()
		btn.text = subcat["name"]
		btn.custom_minimum_size = Vector2(80, 32)
		btn.pressed.connect(_select_subcategory.bind(i))
		_style_subcat_button(btn, i == _current_subcategory)
		_subcategory_bar.add_child(btn)

func _select_subcategory(index: int) -> void:
	_current_subcategory = index
	_selected_entry_id = ""

	# 更新高亮
	var buttons := _subcategory_bar.get_children()
	for i in range(buttons.size()):
		if buttons[i] is Button:
			_style_subcat_button(buttons[i], i == _current_subcategory)

	_populate_entry_list()
	_clear_detail()

# ============================================================
# 条目列表
# ============================================================

func _populate_entry_list() -> void:
	for child in _entry_list.get_children():
		child.queue_free()

	var config: Dictionary = VOLUME_CONFIG[_current_volume]
	var subcats: Array = config["subcategories"]
	if _current_subcategory >= subcats.size():
		return

	var data_key: String = subcats[_current_subcategory]["data_key"]
	var data_table: Dictionary = _get_data_table(data_key)

	for entry_id in data_table:
		var entry_data: Dictionary = data_table[entry_id]
		var is_unlocked: bool = CodexManager.is_unlocked(entry_id) if CodexManager else false

		var entry_btn := _create_entry_button(entry_id, entry_data, is_unlocked)
		_entry_list.add_child(entry_btn)

func _create_entry_button(entry_id: String, data: Dictionary, is_unlocked: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 52)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	if is_unlocked:
		var rarity: int = data.get("rarity", CodexData.Rarity.COMMON)
		var rarity_color: Color = CodexData.RARITY_COLORS.get(rarity, TEXT_PRIMARY)
		btn.text = "  %s" % data.get("name", entry_id)
		if data.has("subtitle"):
			btn.text += "\n    %s" % data["subtitle"]
		btn.add_theme_color_override("font_color", rarity_color)

		var style := StyleBoxFlat.new()
		style.bg_color = ENTRY_BG
		style.border_color = rarity_color * 0.5
		style.border_width_left = 3
		style.corner_radius_top_left = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.content_margin_left = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", style)

		var hover_style := style.duplicate()
		hover_style.bg_color = ENTRY_HOVER
		hover_style.border_color = rarity_color * 0.8
		btn.add_theme_stylebox_override("hover", hover_style)

		var pressed_style := style.duplicate()
		pressed_style.bg_color = ENTRY_SELECTED
		pressed_style.border_color = rarity_color
		btn.add_theme_stylebox_override("pressed", pressed_style)
	else:
		btn.text = "  ???\n    [未解锁]"
		btn.add_theme_color_override("font_color", LOCKED_TEXT)

		var style := StyleBoxFlat.new()
		style.bg_color = LOCKED_BG
		style.border_color = Color(0.15, 0.12, 0.22)
		style.border_width_left = 3
		style.corner_radius_top_left = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.content_margin_left = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", style)

	btn.pressed.connect(_on_entry_selected.bind(entry_id, is_unlocked))
	return btn

# ============================================================
# 详情面板
# ============================================================

func _on_entry_selected(entry_id: String, is_unlocked: bool) -> void:
	_selected_entry_id = entry_id
	_clear_detail()

	if not is_unlocked:
		_show_locked_detail(entry_id)
		return

	var data = CodexData.find_entry(entry_id)
	if data.is_empty():
		return

	_show_entry_detail(entry_id, data)

func _clear_detail() -> void:
	for child in _detail_content.get_children():
		child.queue_free()

func _show_locked_detail(entry_id: String) -> void:
	var lock_label := Label.new()
	lock_label.text = "??? — 未解锁"
	lock_label.add_theme_font_size_override("font_size", 24)
	lock_label.add_theme_color_override("font_color", LOCKED_TEXT)
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_content.add_child(lock_label)

	var hint_label := Label.new()
	var data = CodexData.find_entry(entry_id)
	var unlock_type: int = data.get("unlock_type", CodexData.UnlockType.DEFAULT)
	match unlock_type:
		CodexData.UnlockType.META_UNLOCK:
			hint_label.text = "通过「和谐殿堂」解锁对应升级后获得"
		CodexData.UnlockType.ENCOUNTER:
			hint_label.text = "在战斗中遭遇并击败该目标后获得"
		CodexData.UnlockType.CAST_SPELL:
			hint_label.text = "成功施放对应法术或触发对应效果后获得"
		CodexData.UnlockType.KILL_COUNT:
			hint_label.text = "击杀足够数量的目标后获得"
		_:
			hint_label.text = "继续探索以解锁此条目"

	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", TEXT_DIM)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(hint_label)

func _show_entry_detail(entry_id: String, data: Dictionary) -> void:
	# 名称
	var name_label := Label.new()
	name_label.text = data.get("name", entry_id)
	name_label.add_theme_font_size_override("font_size", 26)
	var rarity: int = data.get("rarity", CodexData.Rarity.COMMON)
	var rarity_color: Color = CodexData.RARITY_COLORS.get(rarity, TEXT_PRIMARY)
	name_label.add_theme_color_override("font_color", rarity_color)
	_detail_content.add_child(name_label)

	# 稀有度标签
	var rarity_label := Label.new()
	rarity_label.text = CodexData.RARITY_NAMES.get(rarity, "普通")
	rarity_label.add_theme_font_size_override("font_size", 12)
	rarity_label.add_theme_color_override("font_color", rarity_color * 0.8)
	_detail_content.add_child(rarity_label)

	# 分隔线
	_add_separator()

	# 副标题
	if data.has("subtitle"):
		var subtitle := Label.new()
		subtitle.text = data["subtitle"]
		subtitle.add_theme_font_size_override("font_size", 16)
		subtitle.add_theme_color_override("font_color", ACCENT)
		_detail_content.add_child(subtitle)

	# 描述
	if data.has("description"):
		var desc := RichTextLabel.new()
		desc.bbcode_enabled = true
		desc.fit_content = true
		desc.scroll_active = false
		desc.custom_minimum_size.y = 60
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.add_theme_color_override("default_color", TEXT_PRIMARY)
		desc.add_theme_font_size_override("normal_font_size", 14)
		desc.text = data["description"]
		_detail_content.add_child(desc)

	# ---- 类型特定信息 ----

	# 音符属性
	if data.has("stats"):
		_add_separator()
		_add_section_title("四维参数")
		var stats: Dictionary = data["stats"]
		_add_stat_bar("伤害 (DMG)", stats.get("dmg", 0), 5, Color(1.0, 0.3, 0.3))
		_add_stat_bar("速度 (SPD)", stats.get("spd", 0), 5, Color(0.3, 0.8, 1.0))
		_add_stat_bar("持续 (DUR)", stats.get("dur", 0), 5, Color(0.3, 1.0, 0.5))
		_add_stat_bar("大小 (SIZE)", stats.get("size", 0), 5, Color(1.0, 0.8, 0.3))

	# 和弦音程
	if data.has("intervals"):
		_add_separator()
		_add_section_title("音程结构")
		var intervals_str := "  ".join(data["intervals"].map(func(i): return "+%d" % i if i > 0 else "根音"))
		var interval_label := Label.new()
		interval_label.text = intervals_str
		interval_label.add_theme_font_size_override("font_size", 16)
		interval_label.add_theme_color_override("font_color", ACCENT)
		_detail_content.add_child(interval_label)

	# 不和谐度
	if data.has("dissonance"):
		var diss_label := Label.new()
		diss_label.text = "不和谐度: %.1f" % data["dissonance"]
		diss_label.add_theme_font_size_override("font_size", 14)
		var diss_color := TEXT_PRIMARY.lerp(Color(1.0, 0.2, 0.2), data["dissonance"] / 10.0)
		diss_label.add_theme_color_override("font_color", diss_color)
		_detail_content.add_child(diss_label)

	# 疲劳代价（扩展和弦）
	if data.has("fatigue_cost"):
		var fatigue_label := Label.new()
		fatigue_label.text = "疲劳代价: %.0f%%" % (data["fatigue_cost"] * 100)
		fatigue_label.add_theme_font_size_override("font_size", 14)
		fatigue_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
		_detail_content.add_child(fatigue_label)

	# 敌人数值
	if data.has("hp") and data.has("speed"):
		_add_separator()
		_add_section_title("战斗数值")
		var stats_text := "HP: %d  |  速度: %d  |  伤害: %d" % [
			data.get("hp", 0), data.get("speed", 0), data.get("damage", 0)]
		if data.has("quantized_fps"):
			stats_text += "  |  量化帧率: %d FPS" % data["quantized_fps"]
		var stats_label := Label.new()
		stats_label.text = stats_text
		stats_label.add_theme_font_size_override("font_size", 13)
		stats_label.add_theme_color_override("font_color", TEXT_SECONDARY)
		stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_content.add_child(stats_label)

	# 特殊机制
	if data.has("mechanic"):
		_add_section_title("特殊机制")
		var mech_label := Label.new()
		mech_label.text = data["mechanic"]
		mech_label.add_theme_font_size_override("font_size", 14)
		mech_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		mech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_content.add_child(mech_label)

	# 应对技巧
	if data.has("counter_tip"):
		_add_section_title("应对技巧")
		var tip_label := Label.new()
		tip_label.text = data["counter_tip"]
		tip_label.add_theme_font_size_override("font_size", 13)
		tip_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.6))
		tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_content.add_child(tip_label)

	# Boss 阶段
	if data.has("phases"):
		_add_separator()
		_add_section_title("Boss 阶段")
		for i in range(data["phases"].size()):
			var phase_label := Label.new()
			phase_label.text = "  阶段 %d: %s" % [i + 1, data["phases"][i]]
			phase_label.add_theme_font_size_override("font_size", 14)
			phase_label.add_theme_color_override("font_color", GOLD)
			_detail_content.add_child(phase_label)

	# 击杀里程碑
	if data.has("kill_milestones") and CodexManager:
		_add_separator()
		_add_section_title("击杀里程碑")
		var progress := CodexManager.get_milestone_progress(entry_id)
		if not progress.is_empty():
			var milestones: Array = progress.get("milestones", [])
			var reached: Array = progress.get("reached", [])
			var kills: int = progress.get("current_kills", 0)
			for m in milestones:
				var is_reached: bool = m in reached
				var ms_label := Label.new()
				ms_label.text = "  %s  击杀 %d 次  (当前: %d)" % [
					"[v]" if is_reached else "[ ]", m, kills]
				ms_label.add_theme_font_size_override("font_size", 13)
				ms_label.add_theme_color_override("font_color",
					Color(0.3, 0.9, 0.5) if is_reached else TEXT_DIM)
				_detail_content.add_child(ms_label)

	# ADSR 信息（音色）
	if data.has("adsr"):
		_add_separator()
		_add_section_title("ADSR 包络")
		var adsr_label := Label.new()
		adsr_label.text = data["adsr"]
		adsr_label.add_theme_font_size_override("font_size", 13)
		adsr_label.add_theme_color_override("font_color", TEXT_SECONDARY)
		adsr_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_content.add_child(adsr_label)

	# 乐器列表（音色）
	if data.has("instruments"):
		_add_section_title("代表乐器")
		var inst_label := Label.new()
		inst_label.text = data["instruments"]
		inst_label.add_theme_font_size_override("font_size", 14)
		inst_label.add_theme_color_override("font_color", ACCENT)
		inst_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_content.add_child(inst_label)

	# 效果说明（节奏型）
	if data.has("effect"):
		_add_separator()
		_add_section_title("效果")
		var effect_label := Label.new()
		effect_label.text = data["effect"]
		effect_label.add_theme_font_size_override("font_size", 14)
		effect_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_content.add_child(effect_label)

	# 调式可用键位
	if data.has("available_keys"):
		_add_separator()
		_add_section_title("可用键位")
		var keys_label := Label.new()
		keys_label.text = data["available_keys"]
		keys_label.add_theme_font_size_override("font_size", 18)
		keys_label.add_theme_color_override("font_color", GOLD)
		_detail_content.add_child(keys_label)

	# 被动效果
	if data.has("passive"):
		_add_section_title("被动效果")
		var passive_label := Label.new()
		passive_label.text = data["passive"]
		passive_label.add_theme_font_size_override("font_size", 14)
		passive_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.7))
		passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_content.add_child(passive_label)

# ============================================================
# UI 辅助方法
# ============================================================

func _add_separator() -> void:
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	sep.add_theme_constant_override("separation", 8)
	_detail_content.add_child(sep)

func _add_section_title(title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", ACCENT * 0.8)
	_detail_content.add_child(label)

func _add_stat_bar(label_text: String, value: int, max_value: int, bar_color: Color) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 100
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", TEXT_SECONDARY)
	hbox.add_child(label)

	# 进度条背景
	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(120, 14)
	bar_bg.color = Color(0.1, 0.08, 0.16)

	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(120, 14)
	hbox.add_child(bar_container)
	bar_container.add_child(bar_bg)

	# 进度条填充
	var bar_fill := ColorRect.new()
	bar_fill.custom_minimum_size = Vector2(120.0 * value / max_value, 14)
	bar_fill.color = bar_color
	bar_container.add_child(bar_fill)

	# 数值
	var val_label := Label.new()
	val_label.text = str(value)
	val_label.add_theme_font_size_override("font_size", 13)
	val_label.add_theme_color_override("font_color", bar_color)
	hbox.add_child(val_label)

	_detail_content.add_child(hbox)

func _update_completion_label() -> void:
	if not _completion_label or not CodexManager:
		return
	var comp := CodexManager.get_total_completion()
	_completion_label.text = "图鉴完成度: %d / %d (%.1f%%)" % [
		comp["unlocked"], comp["total"], comp["percentage"]]

func _style_button(button: Button, accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.16, 0.9)
	style.border_color = accent
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	button.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = accent * 0.3
	button.add_theme_stylebox_override("hover", hover)

	button.add_theme_color_override("font_color", TEXT_PRIMARY)

func _style_tab_button(button: Button, is_active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = TAB_ACTIVE if is_active else TAB_NORMAL
	style.border_color = ACCENT if is_active else ACCENT * 0.3
	style.border_width_left = 3 if is_active else 0
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = TAB_HOVER if not is_active else TAB_ACTIVE
	button.add_theme_stylebox_override("hover", hover)

	button.add_theme_color_override("font_color", GOLD if is_active else TEXT_SECONDARY)
	button.add_theme_font_size_override("font_size", 14)

func _style_subcat_button(button: Button, is_active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT * 0.3 if is_active else Color(0.1, 0.08, 0.16, 0.6)
	style.border_color = ACCENT if is_active else Color(0.2, 0.18, 0.28)
	style.border_width_bottom = 2 if is_active else 0
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	button.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = ACCENT * 0.2
	button.add_theme_stylebox_override("hover", hover)

	button.add_theme_color_override("font_color", TEXT_PRIMARY if is_active else TEXT_SECONDARY)
	button.add_theme_font_size_override("font_size", 13)

# ============================================================
# 数据表查找
# ============================================================

func _get_data_table(data_key: String) -> Dictionary:
	match data_key:
		"VOL1_NOTES": return CodexData.VOL1_NOTES
		"VOL1_CHORDS": return CodexData.VOL1_CHORDS
		"VOL1_EXTENDED_CHORDS": return CodexData.VOL1_EXTENDED_CHORDS
		"VOL1_RHYTHMS": return CodexData.VOL1_RHYTHMS
		"VOL1_MODES": return CodexData.VOL1_MODES
		"VOL2_TIMBRES": return CodexData.VOL2_TIMBRES
		"VOL3_BASIC_ENEMIES": return CodexData.VOL3_BASIC_ENEMIES
		"VOL3_CHAPTER_ENEMIES": return CodexData.VOL3_CHAPTER_ENEMIES
		"VOL3_ELITES": return CodexData.VOL3_ELITES
		"VOL3_BOSSES": return CodexData.VOL3_BOSSES
		"VOL4_MODIFIERS": return CodexData.VOL4_MODIFIERS
		"VOL4_PROGRESSIONS": return CodexData.VOL4_PROGRESSIONS
	return {}

# ============================================================
# 信号回调
# ============================================================

func _on_entry_unlocked(_entry_id: String, _entry_name: String, _volume: int) -> void:
	# 刷新当前显示
	_populate_volume_tabs()
	_populate_entry_list()
	_update_completion_label()
