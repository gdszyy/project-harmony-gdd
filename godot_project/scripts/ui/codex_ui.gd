## 图鉴系统 "谐振法典 (Codex Resonare)" UI 主界面 - v4.0 Full Interactive + Demo
##
## 视觉风格：充满神秘感的魔法书，背景为羊皮纸/星图纹理。
## 布局：顶部标题栏 + 左侧卷标签页/条目列表 + 右侧条目详情页（含法术演示区域）
## 功能：四卷完整数据浏览、条目解锁状态、搜索过滤、详情展示、法术演示
##
## ★ v4.0 新增：法术演示区域
##   - 在条目详情页底部新增演示区域
##   - 演示使用实际 SpellcraftSystem 的施法接口（而非独立模拟）
##   - 内嵌 SubViewport 渲染弹体效果，与游戏内表现完全一致
##   - 支持音符、和弦、修饰符、节奏型等所有法术类型的演示
extends Control

# ============================================================
# 信号
# ============================================================
signal back_pressed()
signal entry_viewed(entry_id: String)

# ============================================================
# 颜色方案
# ============================================================
const BG_COLOR := Color("#0A0814")
const PANEL_BG := Color("#141026")
const HEADER_BG := Color("#100C20")
const TAB_ACTIVE := Color("#9D6FFF4D")
const TAB_HOVER := Color("#9D6FFF33")
const TAB_NORMAL := Color("#141026CC")
const ACCENT := Color("#9D6FFF")
const GOLD := Color("#FFD700")
const TEXT_PRIMARY := Color("#EAE6FF")
const TEXT_SECONDARY := Color("#A098C8")
const TEXT_DIM := Color("#6B668A")
const LOCKED_BG := Color("#100C20E6")
const LOCKED_TEXT := Color("#6B668A")
const ENTRY_BG := Color("#18142C")
const ENTRY_HOVER := Color("#201A38")
const ENTRY_SELECTED := Color("#2A2248")
const DETAIL_BG := Color("#120E22F2")
const DEMO_BG := Color("#0D0A1A")
const DEMO_BORDER := Color("#9D6FFF33")

# ============================================================
# 卷配置 — 完整四卷数据映射
# ============================================================
const VOLUME_CONFIG: Array = [
	{
		"name": "第一卷：乐理纲要", "icon": "I", "volume": CodexData.Volume.MUSIC_THEORY,
		"subcategories": [
			{ "name": "音符", "data_source": "VOL1_NOTES" },
			{ "name": "基础和弦", "data_source": "VOL1_CHORDS" },
			{ "name": "扩展和弦", "data_source": "VOL1_EXTENDED_CHORDS" },
			{ "name": "节奏型", "data_source": "VOL1_RHYTHMS" },
			{ "name": "调式", "data_source": "VOL1_MODES" },
		],
	},
	{
		"name": "第二卷：百相众声", "icon": "II", "volume": CodexData.Volume.TIMBRE_GALLERY,
		"subcategories": [
			{ "name": "音色系别", "data_source": "VOL2_TIMBRES" },
		],
	},
	{
		"name": "第三卷：失谐魔物", "icon": "III", "volume": CodexData.Volume.BESTIARY,
		"subcategories": [
			{ "name": "基础敌人", "data_source": "VOL3_BASIC_ENEMIES" },
			{ "name": "章节敌人", "data_source": "VOL3_CHAPTER_ENEMIES" },
			{ "name": "精英", "data_source": "VOL3_ELITES" },
			{ "name": "Boss", "data_source": "VOL3_BOSSES" },
		],
	},
	{
		"name": "第四卷：神兵乐章", "icon": "IV", "volume": CodexData.Volume.SPELL_COMPENDIUM,
		"subcategories": [
			{ "name": "修饰符", "data_source": "VOL4_MODIFIERS" },
			{ "name": "和弦进行", "data_source": "VOL4_PROGRESSIONS" },
		],
	},
]

# ============================================================
# 数据源映射
# ============================================================
const DATA_SOURCES: Dictionary = {
	"VOL1_NOTES": "VOL1_NOTES",
	"VOL1_CHORDS": "VOL1_CHORDS",
	"VOL1_EXTENDED_CHORDS": "VOL1_EXTENDED_CHORDS",
	"VOL1_RHYTHMS": "VOL1_RHYTHMS",
	"VOL1_MODES": "VOL1_MODES",
	"VOL2_TIMBRES": "VOL2_TIMBRES",
	"VOL3_BASIC_ENEMIES": "VOL3_BASIC_ENEMIES",
	"VOL3_CHAPTER_ENEMIES": "VOL3_CHAPTER_ENEMIES",
	"VOL3_ELITES": "VOL3_ELITES",
	"VOL3_BOSSES": "VOL3_BOSSES",
	"VOL4_MODIFIERS": "VOL4_MODIFIERS",
	"VOL4_PROGRESSIONS": "VOL4_PROGRESSIONS",
}

# ============================================================
# 节点引用
# ============================================================
var _background: ColorRect = null
var _volume_tabs: VBoxContainer = null
var _entry_list_container: VBoxContainer = null
var _entry_list_scroll: ScrollContainer = null
var _detail_container: VBoxContainer = null
var _detail_scroll: ScrollContainer = null
var _search_input: LineEdit = null
var _back_btn: Button = null
var _title_label: Label = null
var _progress_label: Label = null
var _subcat_bar: HBoxContainer = null

# ★ 法术演示区域节点
var _demo_viewport: SubViewport = null
var _demo_viewport_container: SubViewportContainer = null
var _demo_projectile_manager: Node2D = null
var _demo_section: VBoxContainer = null
var _demo_cast_btn: Button = null
var _demo_clear_btn: Button = null
var _demo_info_label: Label = null
var _demo_status_label: Label = null

# ============================================================
# 状态
# ============================================================
var _current_volume_idx: int = 0
var _current_subcat_idx: int = 0
var _current_entry_id: String = ""
var _search_filter: String = ""
var _demo_active: bool = false
var _demo_timer: float = 0.0

## 解锁状态 (从 CodexManager 同步)
var _unlocked_entries: Dictionary = {}  # { "entry_id": true }
var _codex_manager: Node = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_codex_manager = get_node_or_null("/root/CodexManager")
	_load_unlock_state()
	_build_ui()
	_select_volume(0)

func _process(delta: float) -> void:
	# 更新演示区域的弹体
	if _demo_active and _demo_projectile_manager:
		_demo_projectile_manager.update_projectiles(delta)
		_demo_timer += delta
		# 自动清理超过 5 秒的演示
		if _demo_timer > 5.0:
			_clear_demo()

func _load_unlock_state() -> void:
	if _codex_manager and _codex_manager.has_method("get_unlocked_entries"):
		_unlocked_entries = _codex_manager.get_unlocked_entries()
	else:
		# 默认解锁所有 DEFAULT 类型的条目
		for vol_config in VOLUME_CONFIG:
			for subcat in vol_config["subcategories"]:
				var data := _get_data_dict(subcat["data_source"])
				for entry_id in data:
					var entry: Dictionary = data[entry_id]
					if entry.get("unlock_type", CodexData.UnlockType.DEFAULT) == CodexData.UnlockType.DEFAULT:
						_unlocked_entries[entry_id] = true

func _is_entry_unlocked(entry_id: String) -> bool:
	return _unlocked_entries.get(entry_id, false)

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	# 全屏背景
	_background = ColorRect.new()
	_background.color = BG_COLOR
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	# 主布局
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)

	# ---- 顶部标题栏 ----
	var header := _build_header()
	main_vbox.add_child(header)

	# ---- 内容区域 (左侧导航 + 右侧详情) ----
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 0)
	main_vbox.add_child(content_hbox)

	# 左侧面板：卷标签 + 子分类 + 条目列表
	var left_panel := _build_left_panel()
	left_panel.custom_minimum_size.x = 360
	content_hbox.add_child(left_panel)

	# 分隔线
	var separator := VSeparator.new()
	content_hbox.add_child(separator)

	# 右侧面板：条目详情
	var right_panel := _build_right_panel()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(right_panel)

func _build_header() -> Control:
	var header := PanelContainer.new()
	header.custom_minimum_size.y = 50

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	_back_btn = Button.new()
	_back_btn.text = "← 返回"
	_back_btn.pressed.connect(_on_back_pressed)
	hbox.add_child(_back_btn)

	_title_label = Label.new()
	_title_label.text = "✦ 谐 振 法 典 ✦"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", GOLD)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_title_label)

	# 搜索框
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "搜索条目..."
	_search_input.custom_minimum_size = Vector2(200, 30)
	_search_input.text_changed.connect(_on_search_changed)
	hbox.add_child(_search_input)

	# 收集进度
	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 12)
	_progress_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	hbox.add_child(_progress_label)

	header.add_child(hbox)
	return header

func _build_left_panel() -> Control:
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 4)

	# 卷标签页
	_volume_tabs = VBoxContainer.new()
	_volume_tabs.add_theme_constant_override("separation", 2)

	for i in range(VOLUME_CONFIG.size()):
		var vol := VOLUME_CONFIG[i] as Dictionary
		var btn := Button.new()
		btn.name = "VolumeTab_%d" % i
		btn.text = "%s %s" % [vol["icon"], vol["name"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size.y = 36
		btn.pressed.connect(_on_volume_selected.bind(i))
		_volume_tabs.add_child(btn)

	left_vbox.add_child(_volume_tabs)

	# 子分类栏
	_subcat_bar = HBoxContainer.new()
	_subcat_bar.add_theme_constant_override("separation", 4)
	_subcat_bar.custom_minimum_size.y = 30
	left_vbox.add_child(_subcat_bar)

	# 条目列表
	_entry_list_scroll = ScrollContainer.new()
	_entry_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_entry_list_container = VBoxContainer.new()
	_entry_list_container.add_theme_constant_override("separation", 2)
	_entry_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_list_scroll.add_child(_entry_list_container)

	left_vbox.add_child(_entry_list_scroll)

	return left_vbox

func _build_right_panel() -> Control:
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", 12)
	_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 初始提示
	var hint := Label.new()
	hint.text = "选择左侧条目查看详情"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_container.add_child(hint)

	_detail_scroll.add_child(_detail_container)
	return _detail_scroll

# ============================================================
# 数据获取
# ============================================================

func _get_data_dict(data_source: String) -> Dictionary:
	match data_source:
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
# 卷/子分类选择
# ============================================================

func _select_volume(idx: int) -> void:
	_current_volume_idx = idx
	_current_subcat_idx = 0

	# 更新卷标签高亮
	for i in range(_volume_tabs.get_child_count()):
		var btn := _volume_tabs.get_child(i) as Button
		btn.disabled = (i == idx)

	# 更新子分类栏
	_rebuild_subcat_bar()

	# 更新条目列表
	_rebuild_entry_list()

	# 更新进度
	_update_progress()

func _rebuild_subcat_bar() -> void:
	# 清除旧子分类按钮
	for child in _subcat_bar.get_children():
		child.queue_free()

	var vol := VOLUME_CONFIG[_current_volume_idx] as Dictionary
	var subcats: Array = vol.get("subcategories", [])

	for i in range(subcats.size()):
		var subcat := subcats[i] as Dictionary
		var btn := Button.new()
		btn.name = "Subcat_%d" % i
		btn.text = subcat["name"]
		btn.custom_minimum_size = Vector2(60, 24)
		btn.disabled = (i == _current_subcat_idx)
		btn.pressed.connect(_on_subcat_selected.bind(i))
		_subcat_bar.add_child(btn)

# ============================================================
# 条目列表
# ============================================================

func _rebuild_entry_list() -> void:
	# 清除旧条目
	for child in _entry_list_container.get_children():
		child.queue_free()

	var vol := VOLUME_CONFIG[_current_volume_idx] as Dictionary
	var subcats: Array = vol.get("subcategories", [])
	if _current_subcat_idx >= subcats.size():
		return

	var subcat := subcats[_current_subcat_idx] as Dictionary
	var data := _get_data_dict(subcat["data_source"])

	for entry_id in data:
		var entry: Dictionary = data[entry_id]
		var entry_name: String = entry.get("name", entry_id)

		# 搜索过滤
		if not _search_filter.is_empty():
			var search_lower := _search_filter.to_lower()
			var name_lower := entry_name.to_lower()
			var desc_lower: String = entry.get("description", "").to_lower()
			var subtitle_lower: String = entry.get("subtitle", "").to_lower()
			if not (name_lower.contains(search_lower) or desc_lower.contains(search_lower) or subtitle_lower.contains(search_lower)):
				continue

		var is_unlocked := _is_entry_unlocked(entry_id)
		var row := _build_entry_row(entry_id, entry, is_unlocked)
		_entry_list_container.add_child(row)

func _build_entry_row(entry_id: String, entry: Dictionary, is_unlocked: bool) -> Control:
	var btn := Button.new()
	btn.name = "Entry_%s" % entry_id
	btn.custom_minimum_size.y = 40
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var rarity: int = entry.get("rarity", CodexData.Rarity.COMMON)
	var rarity_color: Color = CodexData.RARITY_COLORS.get(rarity, Color.WHITE)

	if is_unlocked:
		var name_text: String = entry.get("name", entry_id)
		var subtitle: String = entry.get("subtitle", "")
		var has_demo := CodexData.has_demo(entry_id)
		var demo_indicator := " ▶" if has_demo else ""
		btn.text = "%s  —  %s%s" % [name_text, subtitle, demo_indicator] if not subtitle.is_empty() else name_text + demo_indicator
		# 稀有度颜色指示（通过文字前缀模拟）
		btn.add_theme_color_override("font_color", rarity_color)
	else:
		btn.text = "??? — 未解锁"
		btn.add_theme_color_override("font_color", LOCKED_TEXT)

	if entry_id == _current_entry_id:
		btn.disabled = true

	btn.pressed.connect(_on_entry_selected.bind(entry_id, is_unlocked))
	return btn

# ============================================================
# 条目详情页
# ============================================================

func _show_entry_detail(entry_id: String) -> void:
	_current_entry_id = entry_id
	var entry := CodexData.find_entry(entry_id)
	if entry.is_empty():
		return

	# 停止当前演示
	_clear_demo()

	# 清除旧详情
	for child in _detail_container.get_children():
		child.queue_free()

	var is_unlocked := _is_entry_unlocked(entry_id)

	if not is_unlocked:
		_show_locked_detail(entry_id, entry)
		return

	# 标记为已查看
	entry_viewed.emit(entry_id)

	# ---- 条目标题 ----
	var rarity: int = entry.get("rarity", CodexData.Rarity.COMMON)
	var rarity_color: Color = CodexData.RARITY_COLORS.get(rarity, Color.WHITE)
	var rarity_name: String = CodexData.RARITY_NAMES.get(rarity, "普通")

	var title_label := Label.new()
	title_label.text = entry.get("name", entry_id)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", rarity_color)
	_detail_container.add_child(title_label)

	# 副标题和稀有度
	var subtitle_hbox := HBoxContainer.new()
	subtitle_hbox.add_theme_constant_override("separation", 12)

	var subtitle_label := Label.new()
	subtitle_label.text = entry.get("subtitle", "")
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	subtitle_hbox.add_child(subtitle_label)

	var rarity_label := Label.new()
	rarity_label.text = "[%s]" % rarity_name
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	subtitle_hbox.add_child(rarity_label)

	_detail_container.add_child(subtitle_hbox)

	# 分隔线
	_detail_container.add_child(HSeparator.new())

	# ---- 描述 ----
	var desc_label := Label.new()
	desc_label.text = entry.get("description", "无描述")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_container.add_child(desc_label)

	# ---- 属性表格 (根据条目类型显示不同信息) ----
	_build_detail_stats(entry_id, entry)

	# ---- ★ 法术演示区域 ----
	if CodexData.has_demo(entry_id):
		_build_demo_section(entry_id, entry)

	# 重建条目列表以更新选中状态
	_rebuild_entry_list()

func _show_locked_detail(entry_id: String, entry: Dictionary) -> void:
	var lock_label := Label.new()
	lock_label.text = "🔒 未解锁"
	lock_label.add_theme_font_size_override("font_size", 20)
	lock_label.add_theme_color_override("font_color", LOCKED_TEXT)
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_container.add_child(lock_label)

	# 解锁提示
	var unlock_type: int = entry.get("unlock_type", CodexData.UnlockType.DEFAULT)
	var hint_text := ""
	match unlock_type:
		CodexData.UnlockType.META_UNLOCK:
			hint_text = "在「和谐殿堂」中解锁对应升级后可查看"
		CodexData.UnlockType.ENCOUNTER:
			hint_text = "在游戏中遭遇此目标后自动解锁"
		CodexData.UnlockType.CAST_SPELL:
			hint_text = "施放对应法术后自动解锁"
		CodexData.UnlockType.KILL_COUNT:
			hint_text = "击杀足够数量后解锁更多信息"
		CodexData.UnlockType.CHAPTER_CLEAR:
			hint_text = "通关对应章节后解锁"

	if not hint_text.is_empty():
		var hint_label := Label.new()
		hint_label.text = hint_text
		hint_label.add_theme_font_size_override("font_size", 11)
		hint_label.add_theme_color_override("font_color", TEXT_DIM)
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_container.add_child(hint_label)

func _build_detail_stats(entry_id: String, entry: Dictionary) -> void:
	# 根据条目内容动态生成属性面板
	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 16)
	stats_grid.add_theme_constant_override("v_separation", 6)

	# 音符属性 — 显示原始参数和实际转换值
	if entry.has("stats"):
		var stats: Dictionary = entry["stats"]
		var dmg: int = stats.get("dmg", 0)
		var spd: int = stats.get("spd", 0)
		var dur: int = stats.get("dur", 0)
		var sz: int = stats.get("size", 0)
		_add_stat_row(stats_grid, "伤害 (DMG)", "%d (= %d 基础伤害)" % [dmg, dmg * 10])
		_add_stat_row(stats_grid, "速度 (SPD)", "%d (= %d 像素/秒)" % [spd, spd * 200])
		_add_stat_row(stats_grid, "持续 (DUR)", "%d (= %.1f 秒)" % [dur, dur * 0.5])
		_add_stat_row(stats_grid, "范围 (SIZE)", "%d (= %d 像素)" % [sz, sz * 8])
		_add_stat_row(stats_grid, "参数总和", "%d / 12" % (dmg + spd + dur + sz))

	# 和弦属性
	if entry.has("intervals"):
		var intervals: Array = entry["intervals"]
		_add_stat_row(stats_grid, "音程构成", str(intervals))
	if entry.has("spell_form"):
		_add_stat_row(stats_grid, "法术形态", str(entry["spell_form"]))
	if entry.has("multiplier"):
		_add_stat_row(stats_grid, "伤害倍率", "%.1fx" % entry["multiplier"])
	if entry.has("dissonance"):
		var diss: float = entry["dissonance"]
		var diss_warning := " (超过 2.0 触发生命腐蚀)" if diss > 2.0 else ""
		_add_stat_row(stats_grid, "不和谐度", "%.1f%s" % [diss, diss_warning])
	if entry.has("fatigue_cost"):
		_add_stat_row(stats_grid, "疲劳代价", "%.2f" % entry["fatigue_cost"])

	# 节奏型效果
	if entry.has("effect"):
		_add_stat_row(stats_grid, "效果", str(entry["effect"]))

	# 调式属性
	if entry.has("available_keys"):
		_add_stat_row(stats_grid, "可用音符", str(entry["available_keys"]))
	if entry.has("passive"):
		_add_stat_row(stats_grid, "被动效果", str(entry["passive"]))
	if entry.has("damage_multiplier"):
		_add_stat_row(stats_grid, "伤害倍率", "%.1fx" % entry["damage_multiplier"])

	# 音色属性
	if entry.has("family"):
		_add_stat_row(stats_grid, "音色系别", str(entry["family"]))
	if entry.has("adsr"):
		_add_stat_row(stats_grid, "ADSR", str(entry["adsr"]))
	if entry.has("mechanic"):
		_add_stat_row(stats_grid, "核心机制", str(entry["mechanic"]))
	if entry.has("instruments"):
		_add_stat_row(stats_grid, "代表乐器", str(entry["instruments"]))

	# 敌人属性
	if entry.has("hp"):
		_add_stat_row(stats_grid, "生命值", str(entry["hp"]))
	if entry.has("speed"):
		_add_stat_row(stats_grid, "移动速度", "%d 像素/秒" % entry["speed"])
	if entry.has("damage"):
		_add_stat_row(stats_grid, "接触伤害", str(entry["damage"]))
	if entry.has("quantized_fps"):
		_add_stat_row(stats_grid, "量化帧率", "%d FPS" % entry["quantized_fps"])
	if entry.has("counter_tip"):
		_add_stat_row(stats_grid, "攻略提示", str(entry["counter_tip"]))

	# Boss 阶段
	if entry.has("phases"):
		var phases: Array = entry["phases"]
		_add_stat_row(stats_grid, "战斗阶段", " → ".join(phases))

	# 修饰符
	if entry.has("black_key"):
		_add_stat_row(stats_grid, "对应黑键", str(entry["black_key"]))

	# 和弦进行
	if entry.has("from"):
		_add_stat_row(stats_grid, "起始功能", str(entry["from"]))
	if entry.has("to"):
		_add_stat_row(stats_grid, "目标功能", str(entry["to"]))

	# 击杀里程碑
	if entry.has("kill_milestones"):
		var milestones: Array = entry["kill_milestones"]
		_add_stat_row(stats_grid, "击杀里程碑", str(milestones))

	# 章节
	if entry.has("chapter"):
		_add_stat_row(stats_grid, "所属章节", "第 %d 章" % entry["chapter"])

	# 颜色
	if entry.has("color"):
		var c: Color = entry["color"]
		_add_stat_row(stats_grid, "弹体颜色", "R%.2f G%.2f B%.2f" % [c.r, c.g, c.b])

	if stats_grid.get_child_count() > 0:
		_detail_container.add_child(HSeparator.new())
		var stats_title := Label.new()
		stats_title.text = "属性详情"
		stats_title.add_theme_font_size_override("font_size", 14)
		stats_title.add_theme_color_override("font_color", ACCENT)
		_detail_container.add_child(stats_title)
		_detail_container.add_child(stats_grid)

func _add_stat_row(grid: GridContainer, label_text: String, value_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", TEXT_SECONDARY)
	grid.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", TEXT_PRIMARY)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(value)

# ============================================================
# ★ 法术演示区域
# ============================================================

## 构建法术演示区域
func _build_demo_section(entry_id: String, entry: Dictionary) -> void:
	var demo_config := CodexData.get_demo_config(entry_id)
	if demo_config.is_empty():
		return

	_detail_container.add_child(HSeparator.new())

	# 演示区域标题
	var demo_title := Label.new()
	demo_title.text = "▶ 法术演示"
	demo_title.add_theme_font_size_override("font_size", 14)
	demo_title.add_theme_color_override("font_color", GOLD)
	_detail_container.add_child(demo_title)

	# 演示说明
	_demo_info_label = Label.new()
	_demo_info_label.text = demo_config.get("demo_desc", "点击下方按钮查看法术效果。")
	_demo_info_label.add_theme_font_size_override("font_size", 11)
	_demo_info_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	_demo_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_container.add_child(_demo_info_label)

	# 演示视口容器（带边框背景）
	var demo_panel := PanelContainer.new()
	demo_panel.custom_minimum_size = Vector2(0, 220)

	# 创建 SubViewport 用于渲染弹体
	_demo_viewport_container = SubViewportContainer.new()
	_demo_viewport_container.custom_minimum_size = Vector2(0, 200)
	_demo_viewport_container.stretch = true
	_demo_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_demo_viewport = SubViewport.new()
	_demo_viewport.size = Vector2i(600, 200)
	_demo_viewport.transparent_bg = true
	_demo_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# 在 SubViewport 中创建 ProjectileManager 实例
	# ★ 使用与游戏相同的 ProjectileManager 脚本
	var pm_script = load("res://scripts/systems/projectile_manager.gd")
	if pm_script:
		_demo_projectile_manager = Node2D.new()
		_demo_projectile_manager.set_script(pm_script)
		_demo_viewport.add_child(_demo_projectile_manager)

		# 添加深色背景
		var bg := ColorRect.new()
		bg.color = DEMO_BG
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.z_index = -1
		_demo_viewport.add_child(bg)

		# 添加网格线（帮助感知弹体运动）
		var grid := _create_demo_grid()
		_demo_viewport.add_child(grid)

	_demo_viewport_container.add_child(_demo_viewport)
	demo_panel.add_child(_demo_viewport_container)
	_detail_container.add_child(demo_panel)

	# 控制按钮栏
	var btn_bar := HBoxContainer.new()
	btn_bar.add_theme_constant_override("separation", 8)

	_demo_cast_btn = Button.new()
	_demo_cast_btn.text = "▶ 施放演示"
	_demo_cast_btn.custom_minimum_size = Vector2(120, 32)
	_demo_cast_btn.pressed.connect(_on_demo_cast.bind(entry_id))
	btn_bar.add_child(_demo_cast_btn)

	_demo_clear_btn = Button.new()
	_demo_clear_btn.text = "✕ 清除"
	_demo_clear_btn.custom_minimum_size = Vector2(80, 32)
	_demo_clear_btn.pressed.connect(_clear_demo)
	btn_bar.add_child(_demo_clear_btn)

	# 状态标签
	_demo_status_label = Label.new()
	_demo_status_label.text = ""
	_demo_status_label.add_theme_font_size_override("font_size", 10)
	_demo_status_label.add_theme_color_override("font_color", TEXT_DIM)
	_demo_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_bar.add_child(_demo_status_label)

	_detail_container.add_child(btn_bar)

## 创建演示区域的网格背景
func _create_demo_grid() -> Node2D:
	var grid := Node2D.new()
	grid.z_index = -1
	# 网格将在 _draw 中绘制（通过自定义 Node2D）
	return grid

## 演示施法按钮回调
func _on_demo_cast(entry_id: String) -> void:
	var demo_config := CodexData.get_demo_config(entry_id)
	if demo_config.is_empty():
		return

	# 清除之前的弹体
	if _demo_projectile_manager and _demo_projectile_manager.has_method("clear_all"):
		_demo_projectile_manager.clear_all()

	_demo_active = true
	_demo_timer = 0.0

	var demo_type: String = demo_config.get("demo_type", "")
	match demo_type:
		"note":
			_demo_cast_note(demo_config)
		"note_modifier":
			_demo_cast_note_modifier(demo_config)
		"chord":
			_demo_cast_chord(demo_config)
		"rhythm":
			_demo_cast_rhythm(demo_config)
		_:
			_update_demo_status("未知演示类型: %s" % demo_type)

## ★ 演示施放音符（通过 SpellcraftSystem 信号链 + 本地 ProjectileManager）
func _demo_cast_note(config: Dictionary) -> void:
	var white_key: int = config.get("demo_note", 0)
	var spell_data := _build_demo_spell_data(white_key, -1)

	# 调整弹体位置和方向以适应演示视口
	spell_data["_demo_origin"] = Vector2(50, 100)  # 从左侧发射
	spell_data["_demo_direction"] = Vector2.RIGHT

	# 通过 ProjectileManager 的实际接口生成弹体
	_spawn_demo_projectile(spell_data)

	var note_name := MusicData.WHITE_KEY_STATS.get(white_key, {}).get("name", "?")
	_update_demo_status("施放: %s | DMG=%.0f SPD=%.0f DUR=%.1fs SIZE=%.0fpx" % [
		note_name, spell_data["damage"], spell_data["speed"],
		spell_data["duration"], spell_data["size"]
	])

## ★ 演示施放带修饰符的音符
func _demo_cast_note_modifier(config: Dictionary) -> void:
	var white_key: int = config.get("demo_note", 0)
	var modifier: int = config.get("demo_modifier", -1)
	var spell_data := _build_demo_spell_data(white_key, modifier)

	spell_data["_demo_origin"] = Vector2(50, 100)
	spell_data["_demo_direction"] = Vector2.RIGHT

	_spawn_demo_projectile(spell_data)

	var note_name := MusicData.WHITE_KEY_STATS.get(white_key, {}).get("name", "?")
	var mod_name := _get_modifier_display_name(modifier)
	_update_demo_status("施放: %s + %s" % [note_name, mod_name])

## ★ 演示施放和弦法术
func _demo_cast_chord(config: Dictionary) -> void:
	var chord_type: int = config.get("demo_chord_type", 0)
	var spell_info: Dictionary = MusicData.CHORD_SPELL_MAP.get(chord_type, {})
	if spell_info.is_empty():
		_update_demo_status("未知和弦类型")
		return

	# 构建和弦 spell_data（与 SpellcraftSystem._execute_chord_cast 一致）
	var root_stats := MusicData.WHITE_KEY_STATS.get(MusicData.WhiteKey.C, {})
	var base_dmg: float = root_stats.get("dmg", 3) * MusicData.PARAM_CONVERSION["dmg_per_point"]
	var chord_multiplier: float = spell_info.get("multiplier", 1.0)
	var dissonance: float = MusicData.CHORD_DISSONANCE.get(chord_type, 0.0)

	var chord_data := {
		"type": "chord",
		"chord_type": chord_type,
		"spell_form": spell_info.get("form", 0),
		"spell_name": spell_info.get("name", ""),
		"damage": base_dmg * chord_multiplier,
		"dissonance": dissonance,
		"modifier": -1,
		"timbre": MusicData.TimbreFamily.NONE,
		"accuracy_offset": 0.0,
	}

	# 通过 ProjectileManager 的和弦施法接口生成弹体
	if _demo_projectile_manager and _demo_projectile_manager.has_method("spawn_chord_projectiles"):
		# 设置演示用的玩家位置（视口中心）
		_demo_projectile_manager.spawn_chord_projectiles(chord_data, Vector2(300, 100), Vector2.RIGHT)
	else:
		# 回退：通过 SpellcraftSystem 信号链（弹体会出现在主游戏场景中）
		SpellcraftSystem.chord_cast.emit(chord_data)

	_update_demo_status("施放和弦: %s | DMG=%.0f | 不和谐度=%.1f" % [
		spell_info.get("name", ""), base_dmg * chord_multiplier, dissonance
	])

## ★ 演示节奏型效果
func _demo_cast_rhythm(config: Dictionary) -> void:
	var white_key: int = config.get("demo_note", 4)  # 默认 G
	var pattern_type: String = config.get("demo_rhythm_pattern", "full")

	# 根据节奏型模式连续施放多个弹体以展示效果
	var spell_count := 4
	var delay := 0.15

	for i in range(spell_count):
		var spell_data := _build_demo_spell_data(white_key, -1)
		spell_data["_demo_origin"] = Vector2(50, 40 + i * 40)
		spell_data["_demo_direction"] = Vector2.RIGHT

		# 应用节奏型效果到弹体（与 ProjectileManager._apply_rhythm_to_projectile 一致）
		_apply_demo_rhythm_effect(spell_data, pattern_type)
		_spawn_demo_projectile(spell_data)

	_update_demo_status("节奏型演示: %s (4 个弹体)" % pattern_type)

## 构建演示用的 spell_data（与 SpellcraftSystem 的实际数据结构一致）
func _build_demo_spell_data(white_key: int, modifier: int) -> Dictionary:
	var stats: Dictionary = MusicData.WHITE_KEY_STATS.get(white_key, MusicData.WHITE_KEY_STATS[MusicData.WhiteKey.C])
	var base_damage: float = stats["dmg"] * MusicData.PARAM_CONVERSION["dmg_per_point"]
	var speed: float = stats["spd"] * MusicData.PARAM_CONVERSION["spd_per_point"]
	var duration: float = stats["dur"] * MusicData.PARAM_CONVERSION["dur_per_point"]
	var size: float = stats["size"] * MusicData.PARAM_CONVERSION["size_per_point"]

	return {
		"type": "note",
		"note": white_key,
		"stats": stats,
		"damage": base_damage,
		"speed": speed,
		"duration": duration,
		"size": size,
		"color": MusicData.NOTE_COLORS.get(white_key, Color.WHITE),
		"modifier": modifier,
		"timbre": MusicData.TimbreFamily.NONE,
		"timbre_name": "合成器",
		"is_rapid_fire": false,
		"rapid_fire_count": 1,
		"has_knockback": false,
		"dodge_back": false,
		"accuracy_offset": 0.0,
	}

## 在演示 ProjectileManager 中生成弹体
func _spawn_demo_projectile(spell_data: Dictionary) -> void:
	if not _demo_projectile_manager:
		return

	var origin: Vector2 = spell_data.get("_demo_origin", Vector2(50, 100))
	var direction: Vector2 = spell_data.get("_demo_direction", Vector2.RIGHT)

	# 通过 ProjectileManager 的实际接口生成弹体
	if _demo_projectile_manager.has_method("spawn_from_spell"):
		_demo_projectile_manager.spawn_from_spell(spell_data, origin, direction)
	elif _demo_projectile_manager.has_method("spawn_projectile"):
		# 回退：直接调用底层生成方法
		_demo_projectile_manager.spawn_projectile({
			"position": origin,
			"velocity": direction * spell_data["speed"],
			"damage": spell_data["damage"],
			"size": spell_data["size"],
			"duration": spell_data["duration"],
			"color": spell_data["color"],
			"modifier": spell_data.get("modifier", -1),
		})

## 应用演示用的节奏型效果
func _apply_demo_rhythm_effect(spell_data: Dictionary, pattern_type: String) -> void:
	match pattern_type:
		"full":
			# 均匀八分音符：连射效果
			spell_data["damage"] *= 0.6
			spell_data["speed"] *= 1.2
			spell_data["size"] *= 0.7
		"dotted":
			# 附点节奏：重击
			spell_data["damage"] *= 1.4
			spell_data["size"] *= 1.2
		"syncopated":
			# 切分节奏：高速穿透
			spell_data["speed"] *= 1.3
		"swing":
			# 摇摆节奏：波浪弹道（标记，由 ProjectileManager 处理）
			spell_data["_wave_trajectory"] = true
		"triplet":
			# 三连音：小弹体
			spell_data["size"] *= 0.8
			spell_data["duration"] *= 0.8
		"rest_boost":
			# 精准蓄力：增强
			spell_data["damage"] *= 1.8
			spell_data["size"] *= 1.3

## 清除演示
func _clear_demo() -> void:
	_demo_active = false
	_demo_timer = 0.0
	if _demo_projectile_manager and _demo_projectile_manager.has_method("clear_all"):
		_demo_projectile_manager.clear_all()
	if _demo_status_label:
		_demo_status_label.text = ""

## 更新演示状态文字
func _update_demo_status(text: String) -> void:
	if _demo_status_label:
		_demo_status_label.text = text

## 获取修饰符显示名称
func _get_modifier_display_name(modifier: int) -> String:
	match modifier:
		MusicData.ModifierEffect.PIERCE: return "锐化(穿透)"
		MusicData.ModifierEffect.HOMING: return "追踪"
		MusicData.ModifierEffect.SPLIT: return "分裂"
		MusicData.ModifierEffect.ECHO: return "回响"
		MusicData.ModifierEffect.SCATTER: return "散射"
		_: return "无"

# ============================================================
# 进度统计
# ============================================================

func _update_progress() -> void:
	if not _progress_label:
		return

	var vol := VOLUME_CONFIG[_current_volume_idx] as Dictionary
	var total := 0
	var unlocked := 0

	for subcat in vol.get("subcategories", []):
		var data := _get_data_dict(subcat["data_source"])
		total += data.size()
		for entry_id in data:
			if _is_entry_unlocked(entry_id):
				unlocked += 1

	_progress_label.text = "收集进度: %d / %d (%.0f%%)" % [unlocked, total, (float(unlocked) / max(total, 1)) * 100.0]

# ============================================================
# 信号回调
# ============================================================

func _on_volume_selected(idx: int) -> void:
	_select_volume(idx)

func _on_subcat_selected(idx: int) -> void:
	_current_subcat_idx = idx
	# 更新子分类按钮高亮
	for i in range(_subcat_bar.get_child_count()):
		var btn := _subcat_bar.get_child(i) as Button
		if btn:
			btn.disabled = (i == idx)
	_rebuild_entry_list()

func _on_entry_selected(entry_id: String, is_unlocked: bool) -> void:
	_show_entry_detail(entry_id)

func _on_search_changed(new_text: String) -> void:
	_search_filter = new_text.strip_edges()
	_rebuild_entry_list()

func _on_back_pressed() -> void:
	_clear_demo()
	back_pressed.emit()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_back_pressed()

# ============================================================
# 公共接口
# ============================================================

## 解锁条目
func unlock_entry(entry_id: String) -> void:
	_unlocked_entries[entry_id] = true
	_rebuild_entry_list()
	_update_progress()

## 跳转到指定条目
func navigate_to_entry(entry_id: String) -> void:
	# 查找条目所在的卷和子分类
	for vol_idx in range(VOLUME_CONFIG.size()):
		var vol := VOLUME_CONFIG[vol_idx] as Dictionary
		for sub_idx in range(vol["subcategories"].size()):
			var subcat := vol["subcategories"][sub_idx] as Dictionary
			var data := _get_data_dict(subcat["data_source"])
			if data.has(entry_id):
				_current_volume_idx = vol_idx
				_current_subcat_idx = sub_idx
				_select_volume(vol_idx)
				_on_subcat_selected(sub_idx)
				_show_entry_detail(entry_id)
				return

## 获取总收集进度
func get_total_progress() -> Dictionary:
	var total := CodexData.get_total_entries()
	var unlocked := _unlocked_entries.size()
	return {
		"total": total,
		"unlocked": unlocked,
		"percentage": (float(unlocked) / max(total, 1)) * 100.0,
	}
