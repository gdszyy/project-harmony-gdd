## codex_ui.gd
## 图鉴系统 "谐振法典 (Codex Resonare)" UI 主界面 — v6.0 重写
##
## 根据 UI_Design_Module4_CircleOfFifths.md §8 设计文档重写：
##   - 经典双栏布局：左栏分类导航(25%) + 右栏详细内容(75%)
##   - "古籍"质感：装饰性线条边框、带扫光效果的科幻字体
##   - 完整四卷数据浏览、条目解锁状态、搜索过滤、详情展示
##   - 法术演示区域（2.5D 渲染）
##   - 敌人 3D 预览
##   - 全局色彩体系与 UI 设计文档 §1.2 对齐
##
## 视觉风格：
##   - 星空紫面板背景 + 谐振紫分割线/边框
##   - 已解锁条目：晶体白文本 + 彩色图标
##   - 未解锁条目：星云灰文本 + 灰色锁定图标
##   - 装饰性精细线条边框，营造"古代乐理典籍"沉浸感
extends Control

# ============================================================
# 信号
# ============================================================
signal back_pressed()
signal entry_viewed(entry_id: String)

# ============================================================
# 颜色方案 (与 UI 设计文档 §1.2 对齐)
# ============================================================
const COL_HEADER_BG := UIColors.PANEL_DARK       ## 深色头部
const COL_LOCKED := UIColors.TEXT_DIM          ## 锁定文本
const COL_ENTRY_BG := UIColors.PANEL_LIGHT        ## 条目背景
const COL_ENTRY_HOVER := UIColors.PANEL_LIGHTER     ## 条目悬停
const COL_ENTRY_SELECTED := UIColors.PANEL_SELECTED  ## 条目选中
var COL_DETAIL_BG: Color = UIColors.with_alpha(UIColors.PANEL_DARK, 0.95)  ## 详情背景
var COL_DEMO_BG: Color = UIColors.PRIMARY_BG  ## 演示区背景
static var COL_DEMO_BORDER := UIColors.with_alpha(UIColors.ACCENT, 0.20)   ## 演示区边框
static var COL_SEPARATOR := UIColors.with_alpha(UIColors.ACCENT, 0.25)     ## 分割线

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
# 敌人类型颜色映射
# ============================================================
const ENEMY_TYPE_COLORS: Dictionary = {
	"static":  UIColors.HAZARD_COLORS["static"],
	"silence": UIColors.HAZARD_COLORS["silence"],
	"screech": UIColors.DISSONANCE_MID,
	"pulse":   UIColors.SHIELD,
	"wall":    UIColors.TEXT_DIM,
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

# 法术演示区域节点
var _demo_viewport: SubViewport = null
var _demo_viewport_container: SubViewportContainer = null
var _demo_projectile_manager: Node2D = null
var _demo_section: VBoxContainer = null
var _demo_cast_btn: Button = null
var _demo_clear_btn: Button = null
var _demo_info_label: Label = null
var _demo_status_label: Label = null

# 演示区域 3D 渲染节点
var _demo_3d_viewport: SubViewport = null
var _demo_3d_viewport_container: SubViewportContainer = null
var _demo_3d_camera: Camera3D = null
var _demo_3d_env: WorldEnvironment = null
var _demo_3d_entity_layer: Node3D = null
var _demo_3d_light: DirectionalLight3D = null

# 敌人 3D 预览节点
var _enemy_preview_viewport: SubViewport = null
var _enemy_preview_container: SubViewportContainer = null
var _enemy_preview_camera: Camera3D = null
var _enemy_preview_model: Node3D = null

# 背景 3D 氛围效果
var _bg_3d_viewport: SubViewport = null
var _bg_3d_viewport_container: SubViewportContainer = null

# ============================================================
# 状态
# ============================================================
var _current_volume_idx: int = 0
var _current_subcat_idx: int = 0
var _current_entry_id: String = ""
var _search_filter: String = ""
var _demo_active: bool = false
var _demo_timer: float = 0.0

## 解锁状态
var _unlocked_entries: Dictionary = {}
var _codex_manager: Node = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_codex_manager = get_node_or_null("/root/CodexManager")
	_load_unlock_state()
	_build_ui()
	_build_bg_3d_atmosphere()
	_select_volume(0)

func _process(delta: float) -> void:
	if _demo_active:
		_demo_timer += delta
		if _demo_timer > 5.0:
			_clear_demo()

	if _enemy_preview_model and is_instance_valid(_enemy_preview_model):
		_enemy_preview_model.rotation.y += delta * 1.5

func _load_unlock_state() -> void:
	if _codex_manager and _codex_manager.has_method("get_unlocked_entries"):
		_unlocked_entries = _codex_manager.get_unlocked_entries()
	else:
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
# UI 构建 — 主布局 (设计文档 §8.2)
# ============================================================

func _build_ui() -> void:
	# 全屏背景
	_background = ColorRect.new()
	_background.color = UIColors.PRIMARY_BG
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	# 主布局容器
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)

	# 顶部标题栏
	var header := _build_header()
	main_vbox.add_child(header)

	# 装饰性分割线
	var top_sep := _create_decorative_separator()
	main_vbox.add_child(top_sep)

	# 内容区域 (左侧导航 25% + 右侧详情 75%)
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 0)
	main_vbox.add_child(content_hbox)

	# 左侧面板
	var left_panel := _build_left_panel()
	left_panel.custom_minimum_size.x = 360
	content_hbox.add_child(left_panel)

	# 垂直装饰分割线
	var v_sep := _create_vertical_separator()
	content_hbox.add_child(v_sep)

	# 右侧面板
	var right_panel := _build_right_panel()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(right_panel)

# ============================================================
# UI 构建 — 标题栏
# ============================================================

func _build_header() -> Control:
	var header := PanelContainer.new()
	header.custom_minimum_size.y = 56

	var header_style := StyleBoxFlat.new()
	header_style.bg_color = COL_HEADER_BG
	header_style.content_margin_left = 20
	header_style.content_margin_right = 20
	header_style.content_margin_top = 8
	header_style.content_margin_bottom = 8
	header_style.border_color = UIColors.ACCENT
	header_style.border_width_bottom = 1
	header.add_theme_stylebox_override("panel", header_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	# 返回按钮
	_back_btn = Button.new()
	_back_btn.text = "← 返回"
	_back_btn.custom_minimum_size = Vector2(80, 36)
	_back_btn.pressed.connect(_on_back_pressed)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = UIColors.PANEL_BG
	back_style.border_color = UIColors.ACCENT
	back_style.border_width_left = 1
	back_style.border_width_right = 1
	back_style.border_width_top = 1
	back_style.border_width_bottom = 1
	back_style.corner_radius_top_left = 4
	back_style.corner_radius_top_right = 4
	back_style.corner_radius_bottom_left = 4
	back_style.corner_radius_bottom_right = 4
	back_style.content_margin_left = 12
	back_style.content_margin_right = 12
	_back_btn.add_theme_stylebox_override("normal", back_style)
	_back_btn.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	_back_btn.add_theme_color_override("font_hover_color", UIColors.TEXT_PRIMARY)
	hbox.add_child(_back_btn)

	# 标题
	_title_label = Label.new()
	_title_label.text = "✦ 谐 振 法 典 ✦"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", UIColors.GOLD)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(_title_label)

	# 搜索框
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "搜索条目..."
	_search_input.custom_minimum_size = Vector2(220, 32)
	_search_input.text_changed.connect(_on_search_changed)
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = UIColors.with_alpha(UIColors.PANEL_BG, 0.9)
	search_style.border_color = UIColors.ACCENT
	search_style.border_width_bottom = 1
	search_style.corner_radius_top_left = 4
	search_style.corner_radius_top_right = 4
	search_style.corner_radius_bottom_left = 4
	search_style.corner_radius_bottom_right = 4
	search_style.content_margin_left = 10
	search_style.content_margin_right = 10
	_search_input.add_theme_stylebox_override("normal", search_style)
	_search_input.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	_search_input.add_theme_color_override("font_placeholder_color", UIColors.TEXT_DIM)
	hbox.add_child(_search_input)

	# 收集进度
	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 12)
	_progress_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	hbox.add_child(_progress_label)

	header.add_child(hbox)
	return header

# ============================================================
# UI 构建 — 左侧面板 (§8.2 分类导航)
# ============================================================

func _build_left_panel() -> Control:
	var left_panel := PanelContainer.new()
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = UIColors.PANEL_BG
	left_style.content_margin_left = 8
	left_style.content_margin_right = 8
	left_style.content_margin_top = 8
	left_style.content_margin_bottom = 8
	left_panel.add_theme_stylebox_override("panel", left_style)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 4)

	# 卷标签页
	var vol_label := Label.new()
	vol_label.text = "— 卷目 —"
	vol_label.add_theme_font_size_override("font_size", 12)
	vol_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	vol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(vol_label)

	_volume_tabs = VBoxContainer.new()
	_volume_tabs.add_theme_constant_override("separation", 2)

	for i in range(VOLUME_CONFIG.size()):
		var vol := VOLUME_CONFIG[i] as Dictionary
		var btn := Button.new()
		btn.name = "VolumeTab_%d" % i
		btn.text = "%s  %s" % [vol["icon"], vol["name"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size.y = 38

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = COL_ENTRY_BG
		btn_style.border_color = UIColors.with_alpha(UIColors.ACCENT, 0.2)
		btn_style.border_width_left = 2
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_bottom_left = 4
		btn_style.content_margin_left = 12
		btn_style.content_margin_right = 8
		btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover := btn_style.duplicate()
		btn_hover.bg_color = COL_ENTRY_HOVER
		btn_hover.border_color = UIColors.ACCENT
		btn.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed := btn_style.duplicate()
		btn_pressed.bg_color = COL_ENTRY_SELECTED
		btn_pressed.border_color = UIColors.GOLD
		btn_pressed.border_width_left = 3
		btn.add_theme_stylebox_override("disabled", btn_pressed)

		btn.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
		btn.add_theme_color_override("font_hover_color", UIColors.GOLD)
		btn.add_theme_color_override("font_disabled_color", UIColors.GOLD)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_volume_selected.bind(i))
		_volume_tabs.add_child(btn)

	left_vbox.add_child(_volume_tabs)

	# 装饰分割线
	left_vbox.add_child(_create_decorative_separator())

	# 子分类栏
	var subcat_label := Label.new()
	subcat_label.text = "— 分类 —"
	subcat_label.add_theme_font_size_override("font_size", 11)
	subcat_label.add_theme_color_override("font_color", UIColors.TEXT_DIM)
	subcat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(subcat_label)

	_subcat_bar = HBoxContainer.new()
	_subcat_bar.add_theme_constant_override("separation", 4)
	left_vbox.add_child(_subcat_bar)

	# 装饰分割线
	left_vbox.add_child(_create_decorative_separator())

	# 条目列表 (滚动容器)
	_entry_list_scroll = ScrollContainer.new()
	_entry_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entry_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_entry_list_container = VBoxContainer.new()
	_entry_list_container.add_theme_constant_override("separation", 2)
	_entry_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_list_scroll.add_child(_entry_list_container)

	left_vbox.add_child(_entry_list_scroll)
	left_panel.add_child(left_vbox)
	return left_panel

# ============================================================
# UI 构建 — 右侧面板 (§8.2 详细内容)
# ============================================================

func _build_right_panel() -> Control:
	var right_panel := PanelContainer.new()
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = UIColors.with_alpha(COL_DETAIL_BG, 0.95)
	right_style.content_margin_left = 20
	right_style.content_margin_right = 20
	right_style.content_margin_top = 16
	right_style.content_margin_bottom = 16
	right_panel.add_theme_stylebox_override("panel", right_style)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", 10)
	_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 默认欢迎信息
	var welcome := Label.new()
	welcome.text = "选择左侧条目以查看详情"
	welcome.add_theme_font_size_override("font_size", 16)
	welcome.add_theme_color_override("font_color", UIColors.TEXT_DIM)
	welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	welcome.size_flags_vertical = Control.SIZE_EXPAND_FILL
	welcome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_container.add_child(welcome)

	_detail_scroll.add_child(_detail_container)
	right_panel.add_child(_detail_scroll)
	return right_panel

# ============================================================
# UI 构建 — 装饰元素
# ============================================================

func _create_decorative_separator() -> Control:
	var sep_container := CenterContainer.new()
	sep_container.custom_minimum_size.y = 12

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(200, 1)
	sep.color = COL_SEPARATOR
	sep_container.add_child(sep)

	return sep_container

func _create_vertical_separator() -> Control:
	var sep := ColorRect.new()
	sep.custom_minimum_size.x = 1
	sep.color = COL_SEPARATOR
	return sep

# ============================================================
# 背景 3D 氛围效果
# ============================================================

func _build_bg_3d_atmosphere() -> void:
	# 背景 SubViewport 用于微妙的 3D 粒子氛围
	_bg_3d_viewport = SubViewport.new()
	_bg_3d_viewport.size = Vector2i(320, 240)
	_bg_3d_viewport.transparent_bg = true
	_bg_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_bg_3d_viewport.msaa_3d = SubViewport.MSAA_2X

	var bg_camera := Camera3D.new()
	bg_camera.position = Vector3(0, 0, 5)
	bg_camera.fov = 60
	_bg_3d_viewport.add_child(bg_camera)

	var bg_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UIColors.with_alpha(Color.BLACK, 0.0)
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.3
	bg_env.environment = env
	_bg_3d_viewport.add_child(bg_env)

	_bg_3d_viewport_container = SubViewportContainer.new()
	_bg_3d_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_3d_viewport_container.stretch = true
	_bg_3d_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_3d_viewport_container.modulate.a = 0.15
	_bg_3d_viewport_container.add_child(_bg_3d_viewport)
	add_child(_bg_3d_viewport_container)
	move_child(_bg_3d_viewport_container, 1)  # 放在背景之后

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

	for i in range(_volume_tabs.get_child_count()):
		var btn := _volume_tabs.get_child(i) as Button
		btn.disabled = (i == idx)

	_rebuild_subcat_bar()
	_rebuild_entry_list()
	_update_progress()

func _rebuild_subcat_bar() -> void:
	for child in _subcat_bar.get_children():
		child.queue_free()

	var vol := VOLUME_CONFIG[_current_volume_idx] as Dictionary
	var subcats: Array = vol.get("subcategories", [])

	for i in range(subcats.size()):
		var subcat := subcats[i] as Dictionary
		var btn := Button.new()
		btn.name = "Subcat_%d" % i
		btn.text = subcat["name"]
		btn.custom_minimum_size = Vector2(60, 26)
		btn.disabled = (i == _current_subcat_idx)

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = COL_ENTRY_BG
		btn_style.border_color = UIColors.with_alpha(UIColors.ACCENT, 0.3)
		btn_style.border_width_bottom = 1
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_top_right = 4
		btn_style.content_margin_left = 8
		btn_style.content_margin_right = 8
		btn.add_theme_stylebox_override("normal", btn_style)

		var btn_active := btn_style.duplicate()
		btn_active.bg_color = COL_ENTRY_SELECTED
		btn_active.border_color = UIColors.ACCENT
		btn_active.border_width_bottom = 2
		btn.add_theme_stylebox_override("disabled", btn_active)

		btn.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
		btn.add_theme_color_override("font_disabled_color", UIColors.ACCENT)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_subcat_selected.bind(i))
		_subcat_bar.add_child(btn)

# ============================================================
# 条目列表
# ============================================================

func _rebuild_entry_list() -> void:
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
	btn.custom_minimum_size.y = 42
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var rarity: int = entry.get("rarity", CodexData.Rarity.COMMON)
	var rarity_color: Color = CodexData.RARITY_COLORS.get(rarity, Color.WHITE)

	# 条目行样式
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = COL_ENTRY_BG
	row_style.border_color = UIColors.with_alpha(UIColors.ACCENT, 0.1)
	row_style.border_width_left = 2
	row_style.corner_radius_top_left = 3
	row_style.corner_radius_bottom_left = 3
	row_style.content_margin_left = 12
	row_style.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", row_style)

	var hover_style := row_style.duplicate()
	hover_style.bg_color = COL_ENTRY_HOVER
	hover_style.border_color = rarity_color if is_unlocked else COL_LOCKED
	btn.add_theme_stylebox_override("hover", hover_style)

	var selected_style := row_style.duplicate()
	selected_style.bg_color = COL_ENTRY_SELECTED
	selected_style.border_color = rarity_color if is_unlocked else COL_LOCKED
	selected_style.border_width_left = 3
	btn.add_theme_stylebox_override("disabled", selected_style)

	if is_unlocked:
		var name_text: String = entry.get("name", entry_id)
		var subtitle: String = entry.get("subtitle", "")
		var has_demo := CodexData.has_demo(entry_id)
		var demo_indicator := " ▶" if has_demo else ""
		btn.text = "%s  —  %s%s" % [name_text, subtitle, demo_indicator] if not subtitle.is_empty() else name_text + demo_indicator
		btn.add_theme_color_override("font_color", rarity_color)
		btn.add_theme_color_override("font_hover_color", rarity_color.lightened(0.2))
	else:
		btn.text = "🔒 ???"
		btn.add_theme_color_override("font_color", COL_LOCKED)
		btn.add_theme_color_override("font_hover_color", UIColors.TEXT_DIM)

	btn.add_theme_font_size_override("font_size", 12)

	if entry_id == _current_entry_id:
		btn.disabled = true

	btn.pressed.connect(_on_entry_selected.bind(entry_id, is_unlocked))
	return btn

# ============================================================
# 条目详情页 (§8.2 右栏)
# ============================================================

func _show_entry_detail(entry_id: String) -> void:
	_current_entry_id = entry_id
	var entry := CodexData.find_entry(entry_id)
	if entry.is_empty():
		return

	_clear_demo()
	_cleanup_enemy_preview()

	# 清除旧详情
	for child in _detail_container.get_children():
		child.queue_free()

	var is_unlocked := _is_entry_unlocked(entry_id)

	if not is_unlocked:
		_show_locked_detail(entry_id, entry)
		return

	entry_viewed.emit(entry_id)

	# ---- 条目标题 ----
	var rarity: int = entry.get("rarity", CodexData.Rarity.COMMON)
	var rarity_color: Color = CodexData.RARITY_COLORS.get(rarity, Color.WHITE)
	var rarity_name: String = CodexData.RARITY_NAMES.get(rarity, "普通")

	var title_label := Label.new()
	title_label.text = entry.get("name", entry_id)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", rarity_color)
	_detail_container.add_child(title_label)

	# 副标题和稀有度标签
	var subtitle_hbox := HBoxContainer.new()
	subtitle_hbox.add_theme_constant_override("separation", 12)

	var subtitle_label := Label.new()
	subtitle_label.text = entry.get("subtitle", "")
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	subtitle_hbox.add_child(subtitle_label)

	var rarity_label := Label.new()
	rarity_label.text = "[%s]" % rarity_name
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	subtitle_hbox.add_child(rarity_label)

	_detail_container.add_child(subtitle_hbox)

	# 装饰分割线
	_detail_container.add_child(_create_decorative_separator())

	# ---- 敌人 3D 预览 ----
	if _is_enemy_entry(entry_id, entry):
		_build_enemy_3d_preview(entry_id, entry)

	# ---- 描述 ----
	var desc_label := Label.new()
	desc_label.text = entry.get("description", "无描述")
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_container.add_child(desc_label)

	# ---- 属性表格 ----
	_build_detail_stats(entry_id, entry)

	# ---- 法术演示区域 ----
	if CodexData.has_demo(entry_id):
		_build_demo_section_25d(entry_id, entry)

	_rebuild_entry_list()

func _show_locked_detail(entry_id: String, entry: Dictionary) -> void:
	var lock_container := VBoxContainer.new()
	lock_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lock_container.alignment = BoxContainer.ALIGNMENT_CENTER

	var lock_icon := Label.new()
	lock_icon.text = "🔒"
	lock_icon.add_theme_font_size_override("font_size", 48)
	lock_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_container.add_child(lock_icon)

	var lock_label := Label.new()
	lock_label.text = "未解锁"
	lock_label.add_theme_font_size_override("font_size", 20)
	lock_label.add_theme_color_override("font_color", COL_LOCKED)
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_container.add_child(lock_label)

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
		hint_label.add_theme_font_size_override("font_size", 12)
		hint_label.add_theme_color_override("font_color", UIColors.TEXT_DIM)
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock_container.add_child(hint_label)

	_detail_container.add_child(lock_container)

# ============================================================
# 属性表格
# ============================================================

func _build_detail_stats(entry_id: String, entry: Dictionary) -> void:
	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 16)
	stats_grid.add_theme_constant_override("v_separation", 6)

	# 音符属性
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
		_add_stat_row(stats_grid, "音程结构", str(intervals))
	if entry.has("note_count"):
		_add_stat_row(stats_grid, "音符数量", str(entry["note_count"]))
	if entry.has("dissonance"):
		_add_stat_row(stats_grid, "不和谐度", "%.1f" % entry["dissonance"])
	if entry.has("damage_mult"):
		_add_stat_row(stats_grid, "伤害倍率", "%.2fx" % entry["damage_mult"])

	# 敌人属性
	if entry.has("hp"):
		_add_stat_row(stats_grid, "生命值", str(entry["hp"]))
	if entry.has("damage"):
		_add_stat_row(stats_grid, "伤害", str(entry["damage"]))
	if entry.has("speed"):
		_add_stat_row(stats_grid, "移动速度", str(entry["speed"]))
	if entry.has("xp"):
		_add_stat_row(stats_grid, "经验值", str(entry["xp"]))

	# 修饰符属性
	if entry.has("effect"):
		_add_stat_row(stats_grid, "效果", str(entry["effect"]))
	if entry.has("modifier_type"):
		_add_stat_row(stats_grid, "类型", str(entry["modifier_type"]))

	if stats_grid.get_child_count() > 0:
		_detail_container.add_child(_create_decorative_separator())
		var stats_title := Label.new()
		stats_title.text = "— 属性 —"
		stats_title.add_theme_font_size_override("font_size", 13)
		stats_title.add_theme_color_override("font_color", UIColors.ACCENT)
		stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_detail_container.add_child(stats_title)
		_detail_container.add_child(stats_grid)
	else:
		stats_grid.queue_free()

func _add_stat_row(grid: GridContainer, label_text: String, value_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	label.custom_minimum_size.x = 120
	grid.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 12)
	value.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	grid.add_child(value)

# ============================================================
# 敌人检测与 3D 预览
# ============================================================

func _is_enemy_entry(entry_id: String, entry: Dictionary) -> bool:
	return entry.has("enemy_type") or entry_id.begins_with("enemy_") or entry_id.begins_with("boss_") or entry_id.begins_with("elite_")

func _build_enemy_3d_preview(entry_id: String, entry: Dictionary) -> void:
	_cleanup_enemy_preview()

	_enemy_preview_viewport = SubViewport.new()
	_enemy_preview_viewport.size = Vector2i(300, 200)
	_enemy_preview_viewport.transparent_bg = true
	_enemy_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_enemy_preview_viewport.msaa_3d = SubViewport.MSAA_2X

	_enemy_preview_camera = Camera3D.new()
	_enemy_preview_camera.position = Vector3(0, 1, 3)
	_enemy_preview_camera.look_at_from_position(Vector3(0, 1, 3), Vector3.ZERO)
	_enemy_preview_camera.fov = 50
	_enemy_preview_viewport.add_child(_enemy_preview_camera)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UIColors.with_alpha(Color.BLACK, 0.0)
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env_node.environment = env
	_enemy_preview_viewport.add_child(env_node)

	var light := DirectionalLight3D.new()
	light.position = Vector3(2, 3, 2)
	light.look_at_from_position(Vector3(2, 3, 2), Vector3.ZERO)
	light.light_energy = 1.5
	_enemy_preview_viewport.add_child(light)

	_enemy_preview_model = _create_enemy_3d_model(entry_id, entry)
	_enemy_preview_viewport.add_child(_enemy_preview_model)

	_enemy_preview_container = SubViewportContainer.new()
	_enemy_preview_container.custom_minimum_size = Vector2(300, 200)
	_enemy_preview_container.stretch = true
	_enemy_preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_preview_container.add_child(_enemy_preview_viewport)
	_detail_container.add_child(_enemy_preview_container)

func _create_enemy_3d_model(entry_id: String, entry: Dictionary) -> Node3D:
	var root := Node3D.new()
	var enemy_type: String = entry.get("enemy_type", "")

	# 若 enemy_type 为空，尝试从 entry_id 推断
	if enemy_type.is_empty():
		if entry_id.begins_with("enemy_static") or entry_id == "enemy_static":
			enemy_type = "static"
		elif entry_id.begins_with("enemy_silence") or entry_id == "enemy_silence":
			enemy_type = "silence"
		elif entry_id.begins_with("enemy_screech") or entry_id == "enemy_screech":
			enemy_type = "screech"
		elif entry_id.begins_with("enemy_pulse") or entry_id == "enemy_pulse":
			enemy_type = "pulse"
		elif entry_id.begins_with("enemy_wall") or entry_id == "enemy_wall":
			enemy_type = "wall"
		else:
			enemy_type = "static"

	# 根据 enemy_type 分发到对应的构建函数
	match enemy_type:
		"static":
			_build_static_model(root)
		"silence":
			_build_silence_model(root)
		"screech":
			_build_screech_model(root)
		"pulse":
			_build_pulse_model(root)
		"wall":
			_build_wall_model(root)
		"boss_pythagoras":
			_build_boss_pythagoras_model(root)
		"boss_guido":
			_build_boss_guido_model(root)
		"boss_bach":
			_build_boss_bach_model(root)
		"boss_mozart":
			_build_boss_mozart_model(root)
		"boss_beethoven":
			_build_boss_beethoven_model(root)
		_:
			# 未知类型：使用通用几何体，颜色从 ENEMY_TYPE_COLORS 获取
			var color: Color = ENEMY_TYPE_COLORS.get(enemy_type, Color(0.6, 0.6, 0.6))
			var mi := MeshInstance3D.new()
			mi.mesh = BoxMesh.new()
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 1.5
			mi.material_override = mat
			root.add_child(mi)

	return root

## Static（底噪）：多个小型锯齿碎片，红色调，故障闪烁感
func _build_static_model(root: Node3D) -> void:
	var base_color := Color(1.0, 0.2, 0.3)  # 红色调
	var accent_color := Color(1.0, 0.5, 0.5)

	# 创建多个大小不一的碎片方块，模拟锯齿碎片
	var fragment_data: Array = [
		{"pos": Vector3(0, 0, 0),      "scale": Vector3(0.5, 0.5, 0.5),   "rot": Vector3(0.3, 0.5, 0.2)},
		{"pos": Vector3(0.4, 0.3, 0),  "scale": Vector3(0.25, 0.35, 0.2), "rot": Vector3(0.8, 0.2, 0.6)},
		{"pos": Vector3(-0.35, 0.2, 0.1), "scale": Vector3(0.3, 0.2, 0.25), "rot": Vector3(0.1, 1.0, 0.4)},
		{"pos": Vector3(0.2, -0.35, 0.1), "scale": Vector3(0.2, 0.3, 0.2), "rot": Vector3(0.5, 0.3, 0.9)},
		{"pos": Vector3(-0.2, -0.25, -0.1), "scale": Vector3(0.15, 0.15, 0.3), "rot": Vector3(0.7, 0.6, 0.1)},
	]

	for i in fragment_data.size():
		var fd: Dictionary = fragment_data[i]
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = fd["scale"]
		mi.mesh = box
		mi.position = fd["pos"]
		mi.rotation = fd["rot"]

		var mat := StandardMaterial3D.new()
		# 交替使用主色和强调色
		var c: Color = base_color if i % 2 == 0 else accent_color
		mat.albedo_color = c
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 2.5
		mat.roughness = 0.8
		mi.material_override = mat
		root.add_child(mi)

	# 添加一个点光源增强故障闪烁感
	var omni := OmniLight3D.new()
	omni.light_color = base_color
	omni.light_energy = 3.0
	omni.omni_range = 3.0
	omni.position = Vector3(0, 0.5, 0)
	root.add_child(omni)

## Silence（寂静）：深色旋涡球体，半透明，黑洞吸引感
func _build_silence_model(root: Node3D) -> void:
	var core_color := Color(0.15, 0.1, 0.35)  # 深紫色
	var glow_color := Color(0.4, 0.2, 0.8)    # 紫色光晕

	# 核心球体（深色，半透明）
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	sphere.radial_segments = 32
	sphere.rings = 16
	core.mesh = sphere

	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.05, 0.02, 0.15, 0.85)
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.2, 0.05, 0.5)
	core_mat.emission_energy_multiplier = 1.5
	core_mat.roughness = 0.1
	core_mat.metallic = 0.3
	core.material_override = core_mat
	root.add_child(core)

	# 外层光晕球（更大，更透明）
	var halo := MeshInstance3D.new()
	var halo_sphere := SphereMesh.new()
	halo_sphere.radius = 0.7
	halo_sphere.height = 1.4
	halo_sphere.radial_segments = 16
	halo_sphere.rings = 8
	halo.mesh = halo_sphere

	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(0.3, 0.1, 0.6, 0.15)
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.emission_enabled = true
	halo_mat.emission = glow_color
	halo_mat.emission_energy_multiplier = 0.8
	halo_mat.cull_mode = BaseMaterial3D.CULL_FRONT  # 内面渲染，营造旋涡感
	halo.material_override = halo_mat
	root.add_child(halo)

	# 旋转环（模拟旋涡轨道）
	for i in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.55 + i * 0.15
		torus.outer_radius = 0.65 + i * 0.15
		torus.rings = 24
		torus.ring_segments = 8
		ring.mesh = torus
		ring.rotation = Vector3(PI / 3.0 * i, PI / 4.0 * i, 0)

		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = Color(0.5, 0.2, 0.9, 0.4 - i * 0.1)
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.emission_enabled = true
		ring_mat.emission = glow_color
		ring_mat.emission_energy_multiplier = 1.2 - i * 0.3
		ring.material_override = ring_mat
		root.add_child(ring)

	# 点光源（紫色光晕）
	var omni := OmniLight3D.new()
	omni.light_color = glow_color
	omni.light_energy = 2.0
	omni.omni_range = 3.0
	root.add_child(omni)

## Screech（尖啸）：尖锐三角/锥体，黄白色调，高频闪烁感
func _build_screech_model(root: Node3D) -> void:
	var base_color := Color(1.0, 0.95, 0.5)  # 黄白色
	var hot_color := Color(1.0, 1.0, 0.8)    # 高亮白黄

	# 主体：尖锐锥体（朝上）
	var cone := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0    # 尖顶
	cyl.bottom_radius = 0.35
	cyl.height = 1.0
	cyl.radial_segments = 4  # 4面，更尖锐
	cyl.rings = 1
	cone.mesh = cyl
	cone.position = Vector3(0, 0.1, 0)

	var cone_mat := StandardMaterial3D.new()
	cone_mat.albedo_color = base_color
	cone_mat.emission_enabled = true
	cone_mat.emission = hot_color
	cone_mat.emission_energy_multiplier = 3.0
	cone_mat.roughness = 0.2
	cone_mat.metallic = 0.5
	cone.material_override = cone_mat
	root.add_child(cone)

	# 倒锥（朝下，镜像）
	var cone2 := MeshInstance3D.new()
	var cyl2 := CylinderMesh.new()
	cyl2.top_radius = 0.25
	cyl2.bottom_radius = 0.0  # 尖底
	cyl2.height = 0.6
	cyl2.radial_segments = 4
	cyl2.rings = 1
	cone2.mesh = cyl2
	cone2.position = Vector3(0, -0.5, 0)
	cone2.rotation = Vector3(0, PI / 4.0, 0)  # 旋转45度，形成星形

	var cone2_mat := StandardMaterial3D.new()
	cone2_mat.albedo_color = Color(1.0, 0.8, 0.3)
	cone2_mat.emission_enabled = true
	cone2_mat.emission = base_color
	cone2_mat.emission_energy_multiplier = 2.0
	cone2_mat.roughness = 0.3
	cone2.material_override = cone2_mat
	root.add_child(cone2)

	# 侧翼三角形碎片
	for i in 3:
		var shard := MeshInstance3D.new()
		var shard_cyl := CylinderMesh.new()
		shard_cyl.top_radius = 0.0
		shard_cyl.bottom_radius = 0.1
		shard_cyl.height = 0.5
		shard_cyl.radial_segments = 3
		shard.mesh = shard_cyl
		var angle := (TAU / 3.0) * i + PI / 6.0
		shard.position = Vector3(cos(angle) * 0.5, 0.1, sin(angle) * 0.5)
		shard.rotation = Vector3(0.3, angle, 0.5)

		var shard_mat := StandardMaterial3D.new()
		shard_mat.albedo_color = hot_color
		shard_mat.emission_enabled = true
		shard_mat.emission = hot_color
		shard_mat.emission_energy_multiplier = 4.0
		shard.material_override = shard_mat
		root.add_child(shard)

	# 强烈点光源（高频闪烁感）
	var omni := OmniLight3D.new()
	omni.light_color = hot_color
	omni.light_energy = 4.0
	omni.omni_range = 4.0
	root.add_child(omni)

## Pulse（脉冲）：菱形/八面体，电蓝色调，脉冲发光
func _build_pulse_model(root: Node3D) -> void:
	var base_color := Color(0.2, 0.5, 1.0)   # 电蓝色
	var glow_color := Color(0.4, 0.8, 1.0)   # 亮蓝
	var dark_color := Color(0.05, 0.15, 0.4) # 深蓝

	# 主体：八面体（用两个锥体拼合）
	# 上锥
	var top_cone := MeshInstance3D.new()
	var top_cyl := CylinderMesh.new()
	top_cyl.top_radius = 0.0
	top_cyl.bottom_radius = 0.45
	top_cyl.height = 0.6
	top_cyl.radial_segments = 4  # 4面菱形
	top_cyl.rings = 1
	top_cone.mesh = top_cyl
	top_cone.position = Vector3(0, 0.3, 0)

	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = base_color
	top_mat.emission_enabled = true
	top_mat.emission = glow_color
	top_mat.emission_energy_multiplier = 2.5
	top_mat.metallic = 0.8
	top_mat.roughness = 0.1
	top_cone.material_override = top_mat
	root.add_child(top_cone)

	# 下锥
	var bot_cone := MeshInstance3D.new()
	var bot_cyl := CylinderMesh.new()
	bot_cyl.top_radius = 0.45
	bot_cyl.bottom_radius = 0.0
	bot_cyl.height = 0.6
	bot_cyl.radial_segments = 4
	bot_cyl.rings = 1
	bot_cone.mesh = bot_cyl
	bot_cone.position = Vector3(0, -0.3, 0)

	var bot_mat := StandardMaterial3D.new()
	bot_mat.albedo_color = dark_color
	bot_mat.emission_enabled = true
	bot_mat.emission = base_color
	bot_mat.emission_energy_multiplier = 2.0
	bot_mat.metallic = 0.8
	bot_mat.roughness = 0.1
	bot_cone.material_override = bot_mat
	root.add_child(bot_cone)

	# 外层光晕环（脉冲效果）
	for i in 2:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.5 + i * 0.2
		torus.outer_radius = 0.6 + i * 0.2
		torus.rings = 32
		torus.ring_segments = 8
		ring.mesh = torus
		ring.rotation.x = PI / 2.0

		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = Color(0.3, 0.7, 1.0, 0.5 - i * 0.2)
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.emission_enabled = true
		ring_mat.emission = glow_color
		ring_mat.emission_energy_multiplier = 2.0 - i * 0.5
		ring.material_override = ring_mat
		root.add_child(ring)

	# 点光源（电蓝脉冲光）
	var omni := OmniLight3D.new()
	omni.light_color = glow_color
	omni.light_energy = 3.5
	omni.omni_range = 4.0
	root.add_child(omni)

## Wall（音墙）：巨大多面体，灰紫色调，护盾层效果
func _build_wall_model(root: Node3D) -> void:
	var base_color := Color(0.5, 0.35, 0.6)  # 灰紫色
	var shield_color := Color(0.7, 0.5, 0.9) # 护盾紫
	var dark_color := Color(0.2, 0.15, 0.3)  # 深紫

	# 主体：大型多面体（使用球体模拟多边形）
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	sphere.radial_segments = 6   # 低多边形，模拟多面体
	sphere.rings = 4
	body.mesh = sphere

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = dark_color
	body_mat.emission_enabled = true
	body_mat.emission = base_color
	body_mat.emission_energy_multiplier = 1.5
	body_mat.metallic = 0.6
	body_mat.roughness = 0.4
	var body_wireframe := StandardMaterial3D.new()
	body.material_override = body_mat
	root.add_child(body)

	# 护盾层（外层半透明球）
	var shield := MeshInstance3D.new()
	var shield_sphere := SphereMesh.new()
	shield_sphere.radius = 0.85
	shield_sphere.height = 1.7
	shield_sphere.radial_segments = 8
	shield_sphere.rings = 6
	shield.mesh = shield_sphere

	var shield_mat := StandardMaterial3D.new()
	shield_mat.albedo_color = Color(0.6, 0.4, 0.8, 0.2)
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.emission_enabled = true
	shield_mat.emission = shield_color
	shield_mat.emission_energy_multiplier = 1.0
	shield_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	shield.material_override = shield_mat
	root.add_child(shield)

	# 护盾环（水平方向，模拟护盾层）
	for i in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.7
		torus.outer_radius = 0.85
		torus.rings = 16
		torus.ring_segments = 6
		ring.mesh = torus
		ring.rotation.x = PI / 2.0
		ring.position.y = -0.3 + i * 0.3

		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = Color(0.7, 0.5, 0.9, 0.6)
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.emission_enabled = true
		ring_mat.emission = shield_color
		ring_mat.emission_energy_multiplier = 1.5
		ring.material_override = ring_mat
		root.add_child(ring)

	# 点光源
	var omni := OmniLight3D.new()
	omni.light_color = shield_color
	omni.light_energy = 2.5
	omni.omni_range = 4.0
	root.add_child(omni)

## Boss：毕达哥拉斯 — 多层旋转光环几何体，金色
func _build_boss_pythagoras_model(root: Node3D) -> void:
	var gold_color := Color(1.0, 0.85, 0.2)   # 金色
	var bright_gold := Color(1.0, 0.95, 0.5)  # 亮金
	var dark_gold := Color(0.6, 0.45, 0.05)   # 暗金

	# 核心球体
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	sphere.radial_segments = 16
	sphere.rings = 8
	core.mesh = sphere

	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = bright_gold
	core_mat.emission_enabled = true
	core_mat.emission = bright_gold
	core_mat.emission_energy_multiplier = 4.0
	core_mat.metallic = 1.0
	core_mat.roughness = 0.05
	core.material_override = core_mat
	root.add_child(core)

	# 多层旋转光环（毕达哥拉斯的标志性多层圆环）
	var ring_configs: Array = [
		{"radius": 0.55, "thickness": 0.04, "rot": Vector3(0, 0, 0),           "energy": 3.0},
		{"radius": 0.75, "thickness": 0.035, "rot": Vector3(PI/3.0, 0, 0),     "energy": 2.5},
		{"radius": 0.95, "thickness": 0.03, "rot": Vector3(PI/6.0, PI/4.0, 0), "energy": 2.0},
		{"radius": 1.15, "thickness": 0.025, "rot": Vector3(PI/2.0, PI/6.0, 0), "energy": 1.5},
		{"radius": 1.35, "thickness": 0.02, "rot": Vector3(PI/4.0, PI/3.0, 0), "energy": 1.0},
	]

	for rc in ring_configs:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = rc["radius"] - rc["thickness"]
		torus.outer_radius = rc["radius"] + rc["thickness"]
		torus.rings = 48
		torus.ring_segments = 8
		ring.mesh = torus
		ring.rotation = rc["rot"]

		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = gold_color
		ring_mat.emission_enabled = true
		ring_mat.emission = gold_color
		ring_mat.emission_energy_multiplier = rc["energy"]
		ring_mat.metallic = 0.9
		ring_mat.roughness = 0.1
		ring.material_override = ring_mat
		root.add_child(ring)

	# 金色点光源
	var omni := OmniLight3D.new()
	omni.light_color = gold_color
	omni.light_energy = 4.0
	omni.omni_range = 5.0
	root.add_child(omni)

## Boss：圭多 — 五线谱相关视觉元素，白银色调
func _build_boss_guido_model(root: Node3D) -> void:
	var staff_color := Color(0.9, 0.9, 1.0)   # 银白
	var note_color := Color(0.6, 0.8, 1.0)    # 淡蓝（音符）
	var glow_color := Color(0.8, 0.9, 1.0)    # 发光白

	# 五条水平线（五线谱）
	for i in 5:
		var line_mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.6, 0.03, 0.03)
		line_mi.mesh = box
		line_mi.position = Vector3(0, -0.4 + i * 0.2, 0)

		var line_mat := StandardMaterial3D.new()
		line_mat.albedo_color = staff_color
		line_mat.emission_enabled = true
		line_mat.emission = glow_color
		line_mat.emission_energy_multiplier = 2.0
		line_mi.material_override = line_mat
		root.add_child(line_mi)

	# 音符球（在五线谱上的音符）
	var note_positions: Array = [
		Vector3(-0.5, -0.4, 0.05),  # 第一线
		Vector3(-0.1, -0.2, 0.05),  # 第二线
		Vector3(0.3, 0.0, 0.05),    # 第三线
		Vector3(0.6, 0.2, 0.05),    # 第四线
	]

	for np in note_positions:
		var note := MeshInstance3D.new()
		var note_sphere := SphereMesh.new()
		note_sphere.radius = 0.08
		note_sphere.height = 0.16
		note_sphere.radial_segments = 12
		note_sphere.rings = 6
		note.mesh = note_sphere
		note.position = np

		var note_mat := StandardMaterial3D.new()
		note_mat.albedo_color = note_color
		note_mat.emission_enabled = true
		note_mat.emission = note_color
		note_mat.emission_energy_multiplier = 3.0
		note.material_override = note_mat
		root.add_child(note)

	# 竖线（小节线）
	for i in 2:
		var bar := MeshInstance3D.new()
		var bar_box := BoxMesh.new()
		bar_box.size = Vector3(0.03, 1.0, 0.03)
		bar.mesh = bar_box
		bar.position = Vector3(-0.7 + i * 1.4, 0, 0)

		var bar_mat := StandardMaterial3D.new()
		bar_mat.albedo_color = staff_color
		bar_mat.emission_enabled = true
		bar_mat.emission = glow_color
		bar_mat.emission_energy_multiplier = 1.5
		bar.material_override = bar_mat
		root.add_child(bar)

	# 点光源
	var omni := OmniLight3D.new()
	omni.light_color = glow_color
	omni.light_energy = 3.0
	omni.omni_range = 4.0
	root.add_child(omni)

## Boss：巴赫 — 赋格结构的多层对位几何体，琥珀棕色调
func _build_boss_bach_model(root: Node3D) -> void:
	var primary_color := Color(0.8, 0.55, 0.1)  # 琥珀棕
	var secondary_color := Color(0.6, 0.35, 0.05) # 深棕
	var accent_color := Color(1.0, 0.75, 0.3)    # 亮琥珀

	# 赋格结构：主题（中心大方块）
	var theme := MeshInstance3D.new()
	var theme_box := BoxMesh.new()
	theme_box.size = Vector3(0.5, 0.5, 0.5)
	theme.mesh = theme_box
	theme.position = Vector3(0, 0, 0)

	var theme_mat := StandardMaterial3D.new()
	theme_mat.albedo_color = primary_color
	theme_mat.emission_enabled = true
	theme_mat.emission = accent_color
	theme_mat.emission_energy_multiplier = 2.5
	theme_mat.metallic = 0.7
	theme_mat.roughness = 0.2
	theme.material_override = theme_mat
	root.add_child(theme)

	# 答题（对位：旋转45度的方块，稍小）
	var answer := MeshInstance3D.new()
	var answer_box := BoxMesh.new()
	answer_box.size = Vector3(0.35, 0.35, 0.35)
	answer.mesh = answer_box
	answer.position = Vector3(0.5, 0.3, 0)
	answer.rotation = Vector3(PI/4.0, PI/4.0, 0)

	var answer_mat := StandardMaterial3D.new()
	answer_mat.albedo_color = secondary_color
	answer_mat.emission_enabled = true
	answer_mat.emission = primary_color
	answer_mat.emission_energy_multiplier = 2.0
	answer_mat.metallic = 0.6
	answer.material_override = answer_mat
	root.add_child(answer)

	# 对题（第三声部：更小的方块，不同位置）
	var counter_subject := MeshInstance3D.new()
	var cs_box := BoxMesh.new()
	cs_box.size = Vector3(0.25, 0.25, 0.25)
	counter_subject.mesh = cs_box
	counter_subject.position = Vector3(-0.45, 0.4, 0)
	counter_subject.rotation = Vector3(PI/6.0, PI/3.0, PI/4.0)

	var cs_mat := StandardMaterial3D.new()
	cs_mat.albedo_color = accent_color
	cs_mat.emission_enabled = true
	cs_mat.emission = accent_color
	cs_mat.emission_energy_multiplier = 3.0
	counter_subject.material_override = cs_mat
	root.add_child(counter_subject)

	# 第四声部（最小）
	var voice4 := MeshInstance3D.new()
	var v4_box := BoxMesh.new()
	v4_box.size = Vector3(0.18, 0.18, 0.18)
	voice4.mesh = v4_box
	voice4.position = Vector3(0.2, -0.5, 0)
	voice4.rotation = Vector3(PI/5.0, PI/5.0, PI/5.0)

	var v4_mat := StandardMaterial3D.new()
	v4_mat.albedo_color = primary_color
	v4_mat.emission_enabled = true
	v4_mat.emission = primary_color
	v4_mat.emission_energy_multiplier = 1.5
	voice4.material_override = v4_mat
	root.add_child(voice4)

	# 连接线（赋格的声部连接）
	for i in 3:
		var connector := MeshInstance3D.new()
		var conn_box := BoxMesh.new()
		conn_box.size = Vector3(0.02, 0.02, 0.6 + i * 0.1)
		connector.mesh = conn_box
		connector.position = Vector3(-0.1 + i * 0.2, 0.1 + i * 0.1, 0)
		connector.rotation = Vector3(0.2 * i, 0.3 * i, 0.1 * i)

		var conn_mat := StandardMaterial3D.new()
		conn_mat.albedo_color = Color(0.9, 0.7, 0.3, 0.7)
		conn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		conn_mat.emission_enabled = true
		conn_mat.emission = accent_color
		conn_mat.emission_energy_multiplier = 1.0
		connector.material_override = conn_mat
		root.add_child(connector)

	# 点光源
	var omni := OmniLight3D.new()
	omni.light_color = accent_color
	omni.light_energy = 3.0
	omni.omni_range = 4.0
	root.add_child(omni)

## Boss：莫扎特 — 优雅的古典几何体，银白蓝色调
func _build_boss_mozart_model(root: Node3D) -> void:
	var silver_color := Color(0.85, 0.88, 0.95)  # 银白
	var blue_accent := Color(0.5, 0.65, 1.0)     # 古典蓝
	var pearl_color := Color(0.95, 0.95, 1.0)    # 珍珠白

	# 主体：优雅的球体（古典完美圆形）
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	sphere.radial_segments = 32
	sphere.rings = 16
	body.mesh = sphere

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = silver_color
	body_mat.emission_enabled = true
	body_mat.emission = pearl_color
	body_mat.emission_energy_multiplier = 1.5
	body_mat.metallic = 0.9
	body_mat.roughness = 0.05
	body.material_override = body_mat
	root.add_child(body)

	# 三层对称装饰环（奏鸣曲三段式）
	var ring_heights: Array = [-0.3, 0.0, 0.3]
	var ring_radii: Array = [0.55, 0.65, 0.55]

	for i in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = ring_radii[i] - 0.03
		torus.outer_radius = ring_radii[i] + 0.03
		torus.rings = 48
		torus.ring_segments = 12
		ring.mesh = torus
		ring.rotation.x = PI / 2.0
		ring.position.y = ring_heights[i]

		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = blue_accent
		ring_mat.emission_enabled = true
		ring_mat.emission = blue_accent
		ring_mat.emission_energy_multiplier = 2.0
		ring_mat.metallic = 0.8
		ring_mat.roughness = 0.1
		ring.material_override = ring_mat
		root.add_child(ring)

	# 四个对称装饰球（古典对称美）
	for i in 4:
		var deco := MeshInstance3D.new()
		var deco_sphere := SphereMesh.new()
		deco_sphere.radius = 0.08
		deco_sphere.height = 0.16
		deco_sphere.radial_segments = 12
		deco_sphere.rings = 6
		deco.mesh = deco_sphere
		var angle := (TAU / 4.0) * i + PI / 4.0
		deco.position = Vector3(cos(angle) * 0.65, 0, sin(angle) * 0.65)

		var deco_mat := StandardMaterial3D.new()
		deco_mat.albedo_color = pearl_color
		deco_mat.emission_enabled = true
		deco_mat.emission = pearl_color
		deco_mat.emission_energy_multiplier = 3.0
		deco_mat.metallic = 1.0
		deco_mat.roughness = 0.05
		deco.material_override = deco_mat
		root.add_child(deco)

	# 点光源（柔和银白光）
	var omni := OmniLight3D.new()
	omni.light_color = pearl_color
	omni.light_energy = 3.0
	omni.omni_range = 4.0
	root.add_child(omni)

## Boss：贝多芬 — 狂暴的不规则几何体，深红橙色调
func _build_boss_beethoven_model(root: Node3D) -> void:
	var rage_color := Color(0.9, 0.2, 0.1)    # 狂暴红
	var fire_color := Color(1.0, 0.5, 0.0)    # 火焰橙
	var dark_color := Color(0.3, 0.05, 0.05)  # 深暗红
	var white_hot := Color(1.0, 0.9, 0.7)     # 白热

	# 核心：不规则扭曲的大球体
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8   # 低多边形，粗犷感
	sphere.rings = 5
	core.mesh = sphere
	core.rotation = Vector3(0.3, 0.5, 0.2)  # 不规则倾斜

	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = dark_color
	core_mat.emission_enabled = true
	core_mat.emission = rage_color
	core_mat.emission_energy_multiplier = 3.0
	core_mat.roughness = 0.9
	core.material_override = core_mat
	root.add_child(core)

	# 爆裂碎片（不规则散射的方块/锥体）
	var shard_data: Array = [
		{"pos": Vector3(0.6, 0.5, 0.1),  "scale": Vector3(0.2, 0.4, 0.15), "rot": Vector3(0.8, 0.3, 1.2), "color": fire_color},
		{"pos": Vector3(-0.7, 0.3, -0.1), "scale": Vector3(0.15, 0.35, 0.2), "rot": Vector3(1.5, 0.7, 0.4), "color": rage_color},
		{"pos": Vector3(0.3, -0.6, 0.2),  "scale": Vector3(0.25, 0.2, 0.15), "rot": Vector3(0.4, 1.8, 0.9), "color": fire_color},
		{"pos": Vector3(-0.4, -0.5, -0.2), "scale": Vector3(0.18, 0.3, 0.12), "rot": Vector3(1.1, 0.5, 1.6), "color": rage_color},
		{"pos": Vector3(0.7, -0.2, 0.3),  "scale": Vector3(0.12, 0.12, 0.35), "rot": Vector3(0.6, 1.2, 0.3), "color": white_hot},
		{"pos": Vector3(-0.5, 0.6, 0.2),  "scale": Vector3(0.1, 0.1, 0.3),   "rot": Vector3(1.3, 0.8, 0.5), "color": white_hot},
	]

	for sd in shard_data:
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = sd["scale"]
		shard.mesh = box
		shard.position = sd["pos"]
		shard.rotation = sd["rot"]

		var shard_mat := StandardMaterial3D.new()
		shard_mat.albedo_color = sd["color"]
		shard_mat.emission_enabled = true
		shard_mat.emission = sd["color"]
		shard_mat.emission_energy_multiplier = 3.5
		shard_mat.roughness = 0.7
		shard.material_override = shard_mat
		root.add_child(shard)

	# 强烈的多色点光源（命运交响的戏剧性）
	var omni1 := OmniLight3D.new()
	omni1.light_color = rage_color
	omni1.light_energy = 4.0
	omni1.omni_range = 5.0
	root.add_child(omni1)

	var omni2 := OmniLight3D.new()
	omni2.light_color = fire_color
	omni2.light_energy = 2.0
	omni2.omni_range = 3.0
	omni2.position = Vector3(0.5, 0.5, 0.5)
	root.add_child(omni2)

func _cleanup_enemy_preview() -> void:
	if _enemy_preview_container and is_instance_valid(_enemy_preview_container):
		_enemy_preview_container.queue_free()
		_enemy_preview_container = null
		_enemy_preview_viewport = null  # viewport 是 container 的子节点，随 container 一起释放
	elif _enemy_preview_viewport and is_instance_valid(_enemy_preview_viewport):
		_enemy_preview_viewport.queue_free()
		_enemy_preview_viewport = null
	_enemy_preview_model = null

# ============================================================
# 法术演示区域 (2.5D)
# ============================================================

func _build_demo_section_25d(entry_id: String, entry: Dictionary) -> void:
	_detail_container.add_child(_create_decorative_separator())

	_demo_section = VBoxContainer.new()
	_demo_section.add_theme_constant_override("separation", 8)

	var demo_title := Label.new()
	demo_title.text = "— 法术演示 —"
	demo_title.add_theme_font_size_override("font_size", 14)
	demo_title.add_theme_color_override("font_color", UIColors.ACCENT)
	demo_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_demo_section.add_child(demo_title)

	# 演示信息
	var demo_config: Dictionary = CodexData.DEMO_CONFIGS.get(entry_id, {})
	_demo_info_label = Label.new()
	_demo_info_label.text = demo_config.get("demo_desc", "点击施放按钮查看效果")
	_demo_info_label.add_theme_font_size_override("font_size", 11)
	_demo_info_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	_demo_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_demo_section.add_child(_demo_info_label)

	# 2.5D 演示视口
	_demo_3d_viewport = SubViewport.new()
	_demo_3d_viewport.size = Vector2i(600, 300)
	_demo_3d_viewport.transparent_bg = false
	_demo_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_demo_3d_viewport.msaa_3d = SubViewport.MSAA_2X

	_demo_3d_camera = Camera3D.new()
	_demo_3d_camera.position = Vector3(0, 8, 8)
	_demo_3d_camera.look_at_from_position(Vector3(0, 8, 8), Vector3.ZERO)
	_demo_3d_camera.fov = 45
	_demo_3d_viewport.add_child(_demo_3d_camera)

	_demo_3d_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UIColors.PRIMARY_BG
	env.ambient_light_color = UIColors.TEXT_LOCKED
	env.ambient_light_energy = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.4
	_demo_3d_env.environment = env
	_demo_3d_viewport.add_child(_demo_3d_env)

	_demo_3d_light = DirectionalLight3D.new()
	_demo_3d_light.position = Vector3(3, 5, 3)
	_demo_3d_light.look_at_from_position(Vector3(3, 5, 3), Vector3.ZERO)
	_demo_3d_light.light_energy = 1.2
	_demo_3d_viewport.add_child(_demo_3d_light)

	_demo_3d_entity_layer = Node3D.new()
	_demo_3d_entity_layer.name = "EntityLayer"
	_demo_3d_viewport.add_child(_demo_3d_entity_layer)

	_create_demo_grid()

	_demo_3d_viewport_container = SubViewportContainer.new()
	_demo_3d_viewport_container.custom_minimum_size = Vector2(600, 300)
	_demo_3d_viewport_container.stretch = true
	_demo_3d_viewport_container.add_child(_demo_3d_viewport)

	var demo_panel := PanelContainer.new()
	var demo_style := StyleBoxFlat.new()
	demo_style.bg_color = COL_DEMO_BG
	demo_style.border_color = UIColors.ACCENT
	demo_style.border_width_left = 1
	demo_style.border_width_right = 1
	demo_style.border_width_top = 1
	demo_style.border_width_bottom = 1
	demo_style.corner_radius_top_left = 6
	demo_style.corner_radius_top_right = 6
	demo_style.corner_radius_bottom_left = 6
	demo_style.corner_radius_bottom_right = 6
	demo_panel.add_theme_stylebox_override("panel", demo_style)
	demo_panel.add_child(_demo_3d_viewport_container)
	_demo_section.add_child(demo_panel)

	# 控制按钮
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	_demo_cast_btn = Button.new()
	_demo_cast_btn.text = "▶ 施放"
	_demo_cast_btn.custom_minimum_size = Vector2(100, 32)
	_demo_cast_btn.pressed.connect(_on_demo_cast.bind(entry_id))
	var cast_style := StyleBoxFlat.new()
	cast_style.bg_color = UIColors.with_alpha(UIColors.ACCENT, 0.3)
	cast_style.border_color = UIColors.ACCENT
	cast_style.border_width_left = 1
	cast_style.border_width_right = 1
	cast_style.border_width_top = 1
	cast_style.border_width_bottom = 1
	cast_style.corner_radius_top_left = 4
	cast_style.corner_radius_top_right = 4
	cast_style.corner_radius_bottom_left = 4
	cast_style.corner_radius_bottom_right = 4
	cast_style.content_margin_left = 12
	cast_style.content_margin_right = 12
	_demo_cast_btn.add_theme_stylebox_override("normal", cast_style)
	_demo_cast_btn.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	btn_hbox.add_child(_demo_cast_btn)

	_demo_clear_btn = Button.new()
	_demo_clear_btn.text = "✕ 清除"
	_demo_clear_btn.custom_minimum_size = Vector2(100, 32)
	_demo_clear_btn.pressed.connect(_clear_demo)
	var clear_style := cast_style.duplicate()
	clear_style.bg_color = UIColors.with_alpha(UIColors.DANGER, 0.3)
	clear_style.border_color = UIColors.DANGER
	_demo_clear_btn.add_theme_stylebox_override("normal", clear_style)
	_demo_clear_btn.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	btn_hbox.add_child(_demo_clear_btn)

	_demo_section.add_child(btn_hbox)

	# 状态标签
	_demo_status_label = Label.new()
	_demo_status_label.text = ""
	_demo_status_label.add_theme_font_size_override("font_size", 10)
	_demo_status_label.add_theme_color_override("font_color", UIColors.TEXT_DIM)
	_demo_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_demo_section.add_child(_demo_status_label)

	_detail_container.add_child(_demo_section)

func _create_demo_grid() -> Node2D:
	# 在 3D 场景中创建地面网格
	if _demo_3d_entity_layer:
		var grid_mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(20, 20)
		grid_mesh.mesh = plane
		var mat := StandardMaterial3D.new()
		mat.albedo_color = UIColors.PRIMARY_BG
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		grid_mesh.material_override = mat
		_demo_3d_entity_layer.add_child(grid_mesh)
	return null

func _on_demo_cast(entry_id: String) -> void:
	_demo_active = true
	_demo_timer = 0.0

	var demo_config: Dictionary = CodexData.DEMO_CONFIGS.get(entry_id, {})
	if demo_config.is_empty():
		_update_demo_status("无可用演示配置")
		return

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

func _demo_cast_note(config: Dictionary) -> void:
	var note_key: int = config.get("demo_note", 0)
	var spell_data := _build_demo_spell_data(note_key, -1)
	_spawn_demo_3d_projectile(spell_data)
	_update_demo_status("施放 %s 音符" % MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?"))

func _demo_cast_note_modifier(config: Dictionary) -> void:
	var note_key: int = config.get("demo_note", 0)
	var modifier: int = config.get("demo_modifier", 0)
	var spell_data := _build_demo_spell_data(note_key, modifier)
	_spawn_demo_3d_projectile(spell_data)
	_update_demo_status("施放 %s + %s" % [
		MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?"),
		_get_modifier_display_name(modifier)
	])

func _demo_cast_chord(config: Dictionary) -> void:
	var chord_type: int = config.get("demo_chord_type", 0)
	var chord_name: String = MusicData.CHORD_SPELL_MAP.get(chord_type, {}).get("name", "未知")
	_update_demo_status("施放 %s 和弦" % chord_name)
	# 创建简单的和弦视觉效果
	if _demo_3d_entity_layer:
		var sphere := MeshInstance3D.new()
		sphere.mesh = SphereMesh.new()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = UIColors.ACCENT
		mat.emission_enabled = true
		mat.emission = UIColors.ACCENT
		mat.emission_energy_multiplier = 3.0
		sphere.material_override = mat
		sphere.position = Vector3(0, 1, 0)
		_demo_3d_entity_layer.add_child(sphere)
		# 动画
		var tween := create_tween()
		tween.tween_property(sphere, "scale", Vector3(3, 3, 3), 0.5)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.8)
		tween.tween_callback(sphere.queue_free)

func _demo_cast_rhythm(config: Dictionary) -> void:
	_update_demo_status("节奏型演示")

func _build_demo_spell_data(white_key: int, modifier: int) -> Dictionary:
	var stats: Dictionary = MusicData.WHITE_KEY_STATS.get(white_key, {})
	return {
		"white_key": white_key,
		"modifier": modifier,
		"dmg": stats.get("dmg", 2),
		"spd": stats.get("spd", 2),
		"dur": stats.get("dur", 2),
		"size": stats.get("size", 2),
		"color": stats.get("color", Color.WHITE),
	}

func _spawn_demo_3d_projectile(spell_data: Dictionary) -> void:
	if not _demo_3d_entity_layer:
		return

	var projectile := MeshInstance3D.new()
	projectile.mesh = SphereMesh.new()
	(projectile.mesh as SphereMesh).radius = 0.2
	(projectile.mesh as SphereMesh).height = 0.4

	var color: Color = spell_data.get("color", Color.WHITE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	projectile.material_override = mat
	projectile.position = Vector3(-5, 0.5, 0)
	_demo_3d_entity_layer.add_child(projectile)

	var speed: float = spell_data.get("spd", 2) * 1.5
	var duration: float = spell_data.get("dur", 2) * 0.5
	var tween := create_tween()
	tween.tween_property(projectile, "position:x", 5.0, duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(projectile.queue_free)

func _clear_demo() -> void:
	_demo_active = false
	_demo_timer = 0.0
	if _demo_3d_entity_layer and is_instance_valid(_demo_3d_entity_layer):
		for child in _demo_3d_entity_layer.get_children():
			child.queue_free()
		_create_demo_grid()
	_update_demo_status("")

func _update_demo_status(text: String) -> void:
	if _demo_status_label and is_instance_valid(_demo_status_label):
		_demo_status_label.text = text

func _get_modifier_display_name(modifier: int) -> String:
	match modifier:
		0: return "穿透 (C#)"
		1: return "追踪 (Eb)"
		2: return "分裂 (F#)"
		3: return "回响 (Ab)"
		4: return "散射 (Bb)"
	return "修饰符 %d" % modifier

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
	for i in range(_subcat_bar.get_child_count()):
		var btn := _subcat_bar.get_child(i) as Button
		if btn:
			btn.disabled = (i == idx)
	_rebuild_entry_list()

func _on_entry_selected(entry_id: String, _is_unlocked: bool) -> void:
	_show_entry_detail(entry_id)

func _on_search_changed(new_text: String) -> void:
	_search_filter = new_text.strip_edges()
	_rebuild_entry_list()

func _on_back_pressed() -> void:
	_clear_demo()
	_cleanup_enemy_preview()
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
	for vol_idx in range(VOLUME_CONFIG.size()):
		var vol := VOLUME_CONFIG[vol_idx] as Dictionary
		for sub_idx in range(vol["subcategories"].size()):
			var subcat: Dictionary = vol["subcategories"][sub_idx] as Dictionary
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
