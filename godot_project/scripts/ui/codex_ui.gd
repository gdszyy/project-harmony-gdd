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
	# 检查 is_enemy 标记字段（用于章节敌人和精英敌人）
	if entry.get("is_enemy", false):
		return true
	# 检查 enemy_type 字段（用于基础敌人）
	if entry.has("enemy_type"):
		return true
	# 检查 entry_id 前缀（用于 Boss 和基础敌人）
	return entry_id.begins_with("enemy_") or entry_id.begins_with("boss_") or entry_id.begins_with("elite_")

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

	# 章节敌人和精英敌人：使用独特的3D预览模型
	if entry.get("is_enemy", false):
		_create_chapter_enemy_model(entry_id, root)
		return root

	# 基础敌人和 Boss：使用原有逻辑
	var enemy_type: String = entry.get("enemy_type", "static")
	var color: Color = ENEMY_TYPE_COLORS.get(enemy_type, Color.WHITE)

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
## 创建章节敌人和精英敌人的独特 3D 预览模型
func _create_chapter_enemy_model(entry_id: String, root: Node3D) -> void:
	match entry_id:
		# ============================================================
		# 第一章敌人：数学几何风格
		# ============================================================
		"ch1_grid_static":
			# 网格阵列排列的小方块
			var grid_color := Color(0.4, 0.8, 1.0)
			for row in range(3):
				for col in range(3):
					var cube := MeshInstance3D.new()
					var box := BoxMesh.new()
					box.size = Vector3(0.25, 0.25, 0.25)
					cube.mesh = box
					var mat := StandardMaterial3D.new()
					mat.albedo_color = grid_color
					mat.emission_enabled = true
					mat.emission = grid_color
					mat.emission_energy_multiplier = 1.5
					cube.material_override = mat
					cube.position = Vector3((col - 1) * 0.4, (row - 1) * 0.4, 0)
					root.add_child(cube)

		"ch1_metronome_pulse":
			# 节拍器形状：中心球体 + 摆锤杆
			var met_color := Color(0.9, 0.7, 0.2)
			# 中心球体
			var center_ball := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.3
			sphere.height = 0.6
			center_ball.mesh = sphere
			var mat_ball := StandardMaterial3D.new()
			mat_ball.albedo_color = met_color
			mat_ball.emission_enabled = true
			mat_ball.emission = met_color
			mat_ball.emission_energy_multiplier = 2.0
			center_ball.material_override = mat_ball
			center_ball.position = Vector3(0, -0.3, 0)
			root.add_child(center_ball)
			# 摆锤杆
			var pendulum := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.05
			cyl.bottom_radius = 0.05
			cyl.height = 1.2
			pendulum.mesh = cyl
			var mat_pend := StandardMaterial3D.new()
			mat_pend.albedo_color = Color(0.8, 0.8, 0.8)
			mat_pend.emission_enabled = true
			mat_pend.emission = Color(0.8, 0.8, 0.8)
			mat_pend.emission_energy_multiplier = 0.8
			pendulum.material_override = mat_pend
			pendulum.position = Vector3(0, 0.3, 0)
			root.add_child(pendulum)

		# ============================================================
		# 第二章敌人：中世纪风格
		# ============================================================
		"ch2_scribe":
			# 羽毛笔形状：主体圆柱 + 尖端渐细
			var scribe_color := Color(0.9, 0.95, 0.7)
			# 笔杆主体
			var quill_body := MeshInstance3D.new()
			var quill_cyl := CylinderMesh.new()
			quill_cyl.top_radius = 0.05
			quill_cyl.bottom_radius = 0.15
			quill_cyl.height = 1.4
			quill_body.mesh = quill_cyl
			var mat_quill := StandardMaterial3D.new()
			mat_quill.albedo_color = scribe_color
			mat_quill.emission_enabled = true
			mat_quill.emission = scribe_color
			mat_quill.emission_energy_multiplier = 1.5
			quill_body.material_override = mat_quill
			quill_body.rotation_degrees = Vector3(0, 0, 30)
			root.add_child(quill_body)
			# 笔尖光点
			var tip := MeshInstance3D.new()
			var tip_sphere := SphereMesh.new()
			tip_sphere.radius = 0.08
			tip_sphere.height = 0.16
			tip.mesh = tip_sphere
			var mat_tip := StandardMaterial3D.new()
			mat_tip.albedo_color = Color(1.0, 0.8, 0.3)
			mat_tip.emission_enabled = true
			mat_tip.emission = Color(1.0, 0.8, 0.3)
			mat_tip.emission_energy_multiplier = 3.0
			tip.material_override = mat_tip
			tip.position = Vector3(-0.35, -0.6, 0)
			root.add_child(tip)

		"ch2_choir":
			# 多个小球组成的合唱团：圆弧排列
			var choir_colors := [
				Color(0.8, 0.4, 0.9),
				Color(0.4, 0.7, 0.9),
				Color(0.9, 0.6, 0.3),
				Color(0.4, 0.9, 0.6),
				Color(0.9, 0.4, 0.5),
			]
			for i in range(5):
				var angle := (float(i) / 5.0) * TAU
				var member := MeshInstance3D.new()
				var s := SphereMesh.new()
				s.radius = 0.18
				s.height = 0.36
				member.mesh = s
				var mat_m := StandardMaterial3D.new()
				mat_m.albedo_color = choir_colors[i]
				mat_m.emission_enabled = true
				mat_m.emission = choir_colors[i]
				mat_m.emission_energy_multiplier = 2.0
				member.material_override = mat_m
				member.position = Vector3(cos(angle) * 0.6, sin(angle) * 0.3, sin(angle) * 0.2)
				root.add_child(member)
			# 中心导唱球
			var leader := MeshInstance3D.new()
			var ls := SphereMesh.new()
			ls.radius = 0.25
			ls.height = 0.5
			leader.mesh = ls
			var mat_l := StandardMaterial3D.new()
			mat_l.albedo_color = Color(1.0, 0.95, 0.8)
			mat_l.emission_enabled = true
			mat_l.emission = Color(1.0, 0.95, 0.8)
			mat_l.emission_energy_multiplier = 2.5
			leader.material_override = mat_l
			leader.position = Vector3(0, 0.2, 0)
			root.add_child(leader)

		# ============================================================
		# 第三章敌人：巴洛克风格
		# ============================================================
		"ch3_counterpoint_crawler":
			# 成对的镜像爫虫：两个对称的圆柱体
			var crawler_color_a := Color(0.3, 0.8, 0.6)
			var crawler_color_b := Color(0.8, 0.3, 0.6)
			for side in range(2):
				var crawler := MeshInstance3D.new()
				var c_cyl := CylinderMesh.new()
				c_cyl.top_radius = 0.12
				c_cyl.bottom_radius = 0.12
				c_cyl.height = 0.8
				crawler.mesh = c_cyl
				var mat_c := StandardMaterial3D.new()
				mat_c.albedo_color = crawler_color_a if side == 0 else crawler_color_b
				mat_c.emission_enabled = true
				mat_c.emission = crawler_color_a if side == 0 else crawler_color_b
				mat_c.emission_energy_multiplier = 2.0
				crawler.material_override = mat_c
				crawler.rotation_degrees = Vector3(90, 0, 0)
				crawler.position = Vector3(-0.4 + side * 0.8, 0, 0)
				root.add_child(crawler)
			# 连接线
			var link := MeshInstance3D.new()
			var link_box := BoxMesh.new()
			link_box.size = Vector3(0.8, 0.05, 0.05)
			link.mesh = link_box
			var mat_link := StandardMaterial3D.new()
			mat_link.albedo_color = Color(0.6, 0.6, 0.9)
			mat_link.emission_enabled = true
			mat_link.emission = Color(0.6, 0.6, 0.9)
			mat_link.emission_energy_multiplier = 1.5
			link.material_override = mat_link
			root.add_child(link)

		# ============================================================
		# 第四章敌人：古典风格
		# ============================================================
		"ch4_minuet_dancer":
			# 旋转的舞者形状：洛可可风格烛台几何体
			var dancer_color := Color(0.95, 0.88, 0.92)
			# 底座
			var base := MeshInstance3D.new()
			var base_cyl := CylinderMesh.new()
			base_cyl.top_radius = 0.3
			base_cyl.bottom_radius = 0.4
			base_cyl.height = 0.15
			base.mesh = base_cyl
			var mat_base := StandardMaterial3D.new()
			mat_base.albedo_color = dancer_color
			mat_base.emission_enabled = true
			mat_base.emission = dancer_color
			mat_base.emission_energy_multiplier = 1.2
			base.material_override = mat_base
			base.position = Vector3(0, -0.5, 0)
			root.add_child(base)
			# 柱身
			var column := MeshInstance3D.new()
			var col_cyl := CylinderMesh.new()
			col_cyl.top_radius = 0.1
			col_cyl.bottom_radius = 0.2
			col_cyl.height = 0.8
			column.mesh = col_cyl
			var mat_col := StandardMaterial3D.new()
			mat_col.albedo_color = Color(0.92, 0.88, 0.78)
			mat_col.emission_enabled = true
			mat_col.emission = Color(0.92, 0.88, 0.78)
			mat_col.emission_energy_multiplier = 1.5
			column.material_override = mat_col
			column.position = Vector3(0, -0.05, 0)
			root.add_child(column)
			# 顶部火焰球
			var flame := MeshInstance3D.new()
			var flame_sphere := SphereMesh.new()
			flame_sphere.radius = 0.15
			flame_sphere.height = 0.3
			flame.mesh = flame_sphere
			var mat_flame := StandardMaterial3D.new()
			mat_flame.albedo_color = Color(1.0, 0.92, 0.6)
			mat_flame.emission_enabled = true
			mat_flame.emission = Color(1.0, 0.92, 0.6)
			mat_flame.emission_energy_multiplier = 4.0
			flame.material_override = mat_flame
			flame.position = Vector3(0, 0.55, 0)
			root.add_child(flame)

		# ============================================================
		# 第五章敌人：浪漫主义风格
		# ============================================================
		"ch5_crescendo_surge":
			# 膨胀的能量体：多层同心球
			var surge_color := Color(1.0, 0.5, 0.1)
			var radii := [0.15, 0.28, 0.42, 0.55]
			var alphas := [1.0, 0.7, 0.5, 0.3]
			for i in range(4):
				var ring := MeshInstance3D.new()
				var torus := TorusMesh.new()
				torus.inner_radius = radii[i] * 0.7
				torus.outer_radius = radii[i]
				ring.mesh = torus
				var mat_ring := StandardMaterial3D.new()
				var ring_color := Color(surge_color.r, surge_color.g, surge_color.b, alphas[i])
				mat_ring.albedo_color = ring_color
				mat_ring.emission_enabled = true
				mat_ring.emission = surge_color
				mat_ring.emission_energy_multiplier = 3.0 - float(i) * 0.5
				mat_ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ring.material_override = mat_ring
				ring.rotation_degrees = Vector3(90, float(i) * 45, 0)
				root.add_child(ring)
			# 核心球
			var core := MeshInstance3D.new()
			var core_s := SphereMesh.new()
			core_s.radius = 0.12
			core_s.height = 0.24
			core.mesh = core_s
			var mat_core := StandardMaterial3D.new()
			mat_core.albedo_color = Color(1.0, 0.9, 0.5)
			mat_core.emission_enabled = true
			mat_core.emission = Color(1.0, 0.9, 0.5)
			mat_core.emission_energy_multiplier = 5.0
			core.material_override = mat_core
			root.add_child(core)

		"ch5_fate_knocker":
			# 命运动机节奏形状：短短短长四个球
			var fate_color := Color(0.2, 0.2, 0.8)
			# 三个小球（短短短）
			for i in range(3):
				var small_ball := MeshInstance3D.new()
				var ss := SphereMesh.new()
				ss.radius = 0.15
				ss.height = 0.3
				small_ball.mesh = ss
				var mat_sb := StandardMaterial3D.new()
				mat_sb.albedo_color = fate_color
				mat_sb.emission_enabled = true
				mat_sb.emission = fate_color
				mat_sb.emission_energy_multiplier = 2.0
				small_ball.material_override = mat_sb
				small_ball.position = Vector3(-0.5 + float(i) * 0.35, 0.2, 0)
				root.add_child(small_ball)
			# 一个大球（长）
			var big_ball := MeshInstance3D.new()
			var bs := SphereMesh.new()
			bs.radius = 0.28
			bs.height = 0.56
			big_ball.mesh = bs
			var mat_bb := StandardMaterial3D.new()
			mat_bb.albedo_color = Color(0.5, 0.5, 1.0)
			mat_bb.emission_enabled = true
			mat_bb.emission = Color(0.5, 0.5, 1.0)
			mat_bb.emission_energy_multiplier = 3.0
			big_ball.material_override = mat_bb
			big_ball.position = Vector3(0.4, -0.1, 0)
			root.add_child(big_ball)

		"ch5_fury_spirit":
			# 闪电构成的不定形体：核心球 + 闪电触须
			var fury_color := Color(0.3, 0.5, 1.0)
			# 核心球
			var fury_core := MeshInstance3D.new()
			var fc_s := SphereMesh.new()
			fc_s.radius = 0.22
			fc_s.height = 0.44
			fury_core.mesh = fc_s
			var mat_fc := StandardMaterial3D.new()
			mat_fc.albedo_color = Color(0.6, 0.7, 1.0)
			mat_fc.emission_enabled = true
			mat_fc.emission = Color(0.6, 0.7, 1.0)
			mat_fc.emission_energy_multiplier = 4.0
			fury_core.material_override = mat_fc
			root.add_child(fury_core)
			# 闪电触须（细长圆柱）
			var lightning_angles := [0.0, PI * 0.5, PI, PI * 1.5, PI * 0.25, PI * 0.75]
			for angle in lightning_angles:
				var bolt := MeshInstance3D.new()
				var b_cyl := CylinderMesh.new()
				b_cyl.top_radius = 0.02
				b_cyl.bottom_radius = 0.02
				b_cyl.height = 0.5
				bolt.mesh = b_cyl
				var mat_bolt := StandardMaterial3D.new()
				mat_bolt.albedo_color = fury_color
				mat_bolt.emission_enabled = true
				mat_bolt.emission = fury_color
				mat_bolt.emission_energy_multiplier = 3.0
				bolt.material_override = mat_bolt
				bolt.position = Vector3(cos(angle) * 0.35, sin(angle) * 0.2, 0)
				bolt.rotation_degrees = Vector3(0, 0, rad_to_deg(angle) + 90)
				root.add_child(bolt)

		# ============================================================
		# 第六章敌人：爵士风格
		# ============================================================
		"ch6_walking_bass":
			# 低音提琴形状霓虹轮廓
			var bass_color := Color(0.0, 0.8, 1.0)
			# 提琴主体（橄橄形球体）
			var body := MeshInstance3D.new()
			var body_s := SphereMesh.new()
			body_s.radius = 0.35
			body_s.height = 0.9
			body.mesh = body_s
			var mat_body := StandardMaterial3D.new()
			mat_body.albedo_color = Color(0.0, 0.15, 0.2)
			mat_body.emission_enabled = true
			mat_body.emission = bass_color
			mat_body.emission_energy_multiplier = 0.5
			body.material_override = mat_body
			body.position = Vector3(0, -0.1, 0)
			root.add_child(body)
			# 霓虹轮廓圈
			var neon_ring := MeshInstance3D.new()
			var nr_torus := TorusMesh.new()
			nr_torus.inner_radius = 0.32
			nr_torus.outer_radius = 0.38
			neon_ring.mesh = nr_torus
			var mat_nr := StandardMaterial3D.new()
			mat_nr.albedo_color = bass_color
			mat_nr.emission_enabled = true
			mat_nr.emission = bass_color
			mat_nr.emission_energy_multiplier = 4.0
			neon_ring.material_override = mat_nr
			neon_ring.position = Vector3(0, -0.1, 0)
			neon_ring.rotation_degrees = Vector3(90, 0, 0)
			root.add_child(neon_ring)
			# 琴颈
			var neck := MeshInstance3D.new()
			var neck_cyl := CylinderMesh.new()
			neck_cyl.top_radius = 0.04
			neck_cyl.bottom_radius = 0.06
			neck_cyl.height = 0.7
			neck.mesh = neck_cyl
			var mat_neck := StandardMaterial3D.new()
			mat_neck.albedo_color = Color(0.9, 0.2, 0.8)
			mat_neck.emission_enabled = true
			mat_neck.emission = Color(0.9, 0.2, 0.8)
			mat_neck.emission_energy_multiplier = 2.0
			neck.material_override = mat_neck
			neck.position = Vector3(0, 0.65, 0)
			root.add_child(neck)

		"ch6_scat_singer":
			# 快速穿梭的小型体：小球 + 运动拖尾
			var scat_color := Color(1.0, 0.6, 0.0)
			# 主体球
			var scat_ball := MeshInstance3D.new()
			var sb_s := SphereMesh.new()
			sb_s.radius = 0.2
			sb_s.height = 0.4
			scat_ball.mesh = sb_s
			var mat_scat := StandardMaterial3D.new()
			mat_scat.albedo_color = scat_color
			mat_scat.emission_enabled = true
			mat_scat.emission = scat_color
			mat_scat.emission_energy_multiplier = 3.0
			scat_ball.material_override = mat_scat
			root.add_child(scat_ball)
			# 运动拖尾（多个逐渐缩小的球）
			for i in range(1, 5):
				var trail := MeshInstance3D.new()
				var ts := SphereMesh.new()
				var t_radius := 0.2 * (1.0 - float(i) * 0.18)
				ts.radius = t_radius
				ts.height = t_radius * 2
				trail.mesh = ts
				var mat_trail := StandardMaterial3D.new()
				var alpha := 1.0 - float(i) * 0.2
				mat_trail.albedo_color = Color(scat_color.r, scat_color.g, scat_color.b, alpha)
				mat_trail.emission_enabled = true
				mat_trail.emission = scat_color
				mat_trail.emission_energy_multiplier = 2.0 - float(i) * 0.4
				mat_trail.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				trail.material_override = mat_trail
				trail.position = Vector3(-float(i) * 0.25, float(i) * 0.1, 0)
				root.add_child(trail)

		# ============================================================
		# 第七章敌人：电子风格
		# ============================================================
		"ch7_bitcrusher_worm":
			# 像素块段组成的蠠虫：多个不同大小的方块
			var worm_colors := [
				Color(0.0, 1.0, 0.5),
				Color(0.0, 0.8, 0.4),
				Color(0.0, 0.6, 0.3),
				Color(0.0, 0.4, 0.2),
				Color(0.0, 0.3, 0.15),
			]
			var worm_sizes := [0.28, 0.22, 0.18, 0.14, 0.1]
			for i in range(5):
				var segment := MeshInstance3D.new()
				var seg_box := BoxMesh.new()
				var sz := worm_sizes[i]
				seg_box.size = Vector3(sz, sz, sz)
				segment.mesh = seg_box
				var mat_seg := StandardMaterial3D.new()
				mat_seg.albedo_color = worm_colors[i]
				mat_seg.emission_enabled = true
				mat_seg.emission = worm_colors[i]
				mat_seg.emission_energy_multiplier = 2.5 - float(i) * 0.3
				segment.material_override = mat_seg
				segment.position = Vector3(-0.5 + float(i) * 0.28, sin(float(i) * 0.8) * 0.15, 0)
				root.add_child(segment)

		"ch7_glitch_phantom":
			# 闪烁错位的幽灵：主体 + 错位层
			var ghost_color := Color(0.7, 0.3, 1.0)
			# 主体
			var ghost_body := MeshInstance3D.new()
			var gb_s := SphereMesh.new()
			gb_s.radius = 0.3
			gb_s.height = 0.6
			ghost_body.mesh = gb_s
			var mat_gb := StandardMaterial3D.new()
			mat_gb.albedo_color = Color(ghost_color.r, ghost_color.g, ghost_color.b, 0.8)
			mat_gb.emission_enabled = true
			mat_gb.emission = ghost_color
			mat_gb.emission_energy_multiplier = 2.0
			mat_gb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ghost_body.material_override = mat_gb
			root.add_child(ghost_body)
			# 错位层（偏移的半透明副本）
			for i in range(3):
				var glitch := MeshInstance3D.new()
				var gl_box := BoxMesh.new()
				gl_box.size = Vector3(0.5 + float(i) * 0.1, 0.08, 0.08)
				glitch.mesh = gl_box
				var mat_gl := StandardMaterial3D.new()
				var gl_color := Color(1.0 - float(i) * 0.3, 0.1, 1.0 - float(i) * 0.2)
				mat_gl.albedo_color = Color(gl_color.r, gl_color.g, gl_color.b, 0.6)
				mat_gl.emission_enabled = true
				mat_gl.emission = gl_color
				mat_gl.emission_energy_multiplier = 3.0
				mat_gl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glitch.material_override = mat_gl
				glitch.position = Vector3(float(i) * 0.12 - 0.12, float(i) * 0.15 - 0.15, float(i) * 0.05)
				root.add_child(glitch)

		# ============================================================
		# 精英敌人
		# ============================================================
		"ch1_harmony_guardian":
			# 带护盾光环的守卫：中心球 + 光环
			var guardian_color := Color(0.3, 0.9, 0.7)
			# 守卫主体
			var guardian_body := MeshInstance3D.new()
			var gb2 := CylinderMesh.new()
			gb2.top_radius = 0.2
			gb2.bottom_radius = 0.25
			gb2.height = 0.7
			guardian_body.mesh = gb2
			var mat_gb2 := StandardMaterial3D.new()
			mat_gb2.albedo_color = guardian_color
			mat_gb2.emission_enabled = true
			mat_gb2.emission = guardian_color
			mat_gb2.emission_energy_multiplier = 2.0
			guardian_body.material_override = mat_gb2
			root.add_child(guardian_body)
			# 护盾光环
			for i in range(2):
				var shield_ring := MeshInstance3D.new()
				var sr_torus := TorusMesh.new()
				sr_torus.inner_radius = 0.45 + float(i) * 0.12
				sr_torus.outer_radius = 0.52 + float(i) * 0.12
				shield_ring.mesh = sr_torus
				var mat_sr := StandardMaterial3D.new()
				mat_sr.albedo_color = Color(0.5, 1.0, 0.8)
				mat_sr.emission_enabled = true
				mat_sr.emission = Color(0.5, 1.0, 0.8)
				mat_sr.emission_energy_multiplier = 3.0
				shield_ring.material_override = mat_sr
				shield_ring.rotation_degrees = Vector3(float(i) * 60, float(i) * 45, 0)
				root.add_child(shield_ring)

		"ch1_frequency_sentinel":
			# 发出共振波的哨兵：中心体 + 同心波环
			var sentinel_color := Color(0.5, 0.7, 1.0)
			# 哨兵主体
			var sentinel_body := MeshInstance3D.new()
			var sb2 := BoxMesh.new()
			sb2.size = Vector3(0.4, 0.6, 0.4)
			sentinel_body.mesh = sb2
			var mat_sb2 := StandardMaterial3D.new()
			mat_sb2.albedo_color = sentinel_color
			mat_sb2.emission_enabled = true
			mat_sb2.emission = sentinel_color
			mat_sb2.emission_energy_multiplier = 2.0
			sentinel_body.material_override = mat_sb2
			root.add_child(sentinel_body)
			# 共振波环
			var wave_radii := [0.4, 0.65, 0.9]
			for i in range(3):
				var wave_ring := MeshInstance3D.new()
				var wr_torus := TorusMesh.new()
				wr_torus.inner_radius = wave_radii[i] - 0.03
				wr_torus.outer_radius = wave_radii[i]
				wave_ring.mesh = wr_torus
				var mat_wr := StandardMaterial3D.new()
				var alpha := 1.0 - float(i) * 0.3
				mat_wr.albedo_color = Color(sentinel_color.r, sentinel_color.g, sentinel_color.b, alpha)
				mat_wr.emission_enabled = true
				mat_wr.emission = sentinel_color
				mat_wr.emission_energy_multiplier = 2.5 - float(i) * 0.5
				mat_wr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wave_ring.material_override = mat_wr
				wave_ring.rotation_degrees = Vector3(90, 0, 0)
				root.add_child(wave_ring)

		"ch2_cantor_commander":
			# 手持指挥棒的形象：主体 + 指挥棒
			var cantor_color := Color(0.9, 0.7, 0.3)
			# 指挥主体
			var cantor_body := MeshInstance3D.new()
			var cb := SphereMesh.new()
			cb.radius = 0.28
			cb.height = 0.56
			cantor_body.mesh = cb
			var mat_cb := StandardMaterial3D.new()
			mat_cb.albedo_color = cantor_color
			mat_cb.emission_enabled = true
			mat_cb.emission = cantor_color
			mat_cb.emission_energy_multiplier = 2.0
			cantor_body.material_override = mat_cb
			root.add_child(cantor_body)
			# 指挥棒
			var baton := MeshInstance3D.new()
			var baton_cyl := CylinderMesh.new()
			baton_cyl.top_radius = 0.02
			baton_cyl.bottom_radius = 0.04
			baton_cyl.height = 0.7
			baton.mesh = baton_cyl
			var mat_baton := StandardMaterial3D.new()
			mat_baton.albedo_color = Color(1.0, 0.95, 0.7)
			mat_baton.emission_enabled = true
			mat_baton.emission = Color(1.0, 0.95, 0.7)
			mat_baton.emission_energy_multiplier = 3.0
			baton.material_override = mat_baton
			baton.position = Vector3(0.35, 0.15, 0)
			baton.rotation_degrees = Vector3(0, 0, -45)
			root.add_child(baton)
			# 强化光环
			var aura := MeshInstance3D.new()
			var aura_torus := TorusMesh.new()
			aura_torus.inner_radius = 0.45
			aura_torus.outer_radius = 0.5
			aura.mesh = aura_torus
			var mat_aura := StandardMaterial3D.new()
			mat_aura.albedo_color = Color(1.0, 0.8, 0.3)
			mat_aura.emission_enabled = true
			mat_aura.emission = Color(1.0, 0.8, 0.3)
			mat_aura.emission_energy_multiplier = 2.5
			aura.material_override = mat_aura
			aura.rotation_degrees = Vector3(90, 0, 0)
			root.add_child(aura)

		"ch3_fugue_weaver":
			# 带镜像分身的织者：主体 + 镜像分身
			var fugue_color := Color(0.7, 0.4, 0.9)
			# 主体
			var fugue_body := MeshInstance3D.new()
			var fb := SphereMesh.new()
			fb.radius = 0.28
			fb.height = 0.56
			fugue_body.mesh = fb
			var mat_fb := StandardMaterial3D.new()
			mat_fb.albedo_color = fugue_color
			mat_fb.emission_enabled = true
			mat_fb.emission = fugue_color
			mat_fb.emission_energy_multiplier = 2.5
			fugue_body.material_override = mat_fb
			fugue_body.position = Vector3(-0.3, 0, 0)
			root.add_child(fugue_body)
			# 镜像分身（半透明）
			var mirror := MeshInstance3D.new()
			var mb := SphereMesh.new()
			mb.radius = 0.22
			mb.height = 0.44
			mirror.mesh = mb
			var mat_mb := StandardMaterial3D.new()
			mat_mb.albedo_color = Color(fugue_color.r, fugue_color.g, fugue_color.b, 0.5)
			mat_mb.emission_enabled = true
			mat_mb.emission = fugue_color
			mat_mb.emission_energy_multiplier = 1.5
			mat_mb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mirror.material_override = mat_mb
			mirror.position = Vector3(0.3, 0, 0)
			root.add_child(mirror)
			# 连接线
			var fugue_link := MeshInstance3D.new()
			var fl_box := BoxMesh.new()
			fl_box.size = Vector3(0.6, 0.03, 0.03)
			fugue_link.mesh = fl_box
			var mat_fl := StandardMaterial3D.new()
			mat_fl.albedo_color = fugue_color
			mat_fl.emission_enabled = true
			mat_fl.emission = fugue_color
			mat_fl.emission_energy_multiplier = 2.0
			fugue_link.material_override = mat_fl
			root.add_child(fugue_link)

		"ch4_court_kapellmeister":
			# 华丽的宫廷指挥：主体 + 测山帽 + 指挥棒
			var kap_color := Color(1.0, 0.85, 0.3)
			# 指挥主体
			var kap_body := MeshInstance3D.new()
			var kb := CylinderMesh.new()
			kb.top_radius = 0.18
			kb.bottom_radius = 0.22
			kb.height = 0.65
			kap_body.mesh = kb
			var mat_kb := StandardMaterial3D.new()
			mat_kb.albedo_color = kap_color
			mat_kb.emission_enabled = true
			mat_kb.emission = kap_color
			mat_kb.emission_energy_multiplier = 2.0
			kap_body.material_override = mat_kb
			root.add_child(kap_body)
			# 测山帽
			var hat := MeshInstance3D.new()
			var hat_cyl := CylinderMesh.new()
			hat_cyl.top_radius = 0.05
			hat_cyl.bottom_radius = 0.22
			hat_cyl.height = 0.3
			hat.mesh = hat_cyl
			var mat_hat := StandardMaterial3D.new()
			mat_hat.albedo_color = Color(0.9, 0.7, 0.1)
			mat_hat.emission_enabled = true
			mat_hat.emission = Color(0.9, 0.7, 0.1)
			mat_hat.emission_energy_multiplier = 2.5
			hat.material_override = mat_hat
			hat.position = Vector3(0, 0.5, 0)
			root.add_child(hat)
			# 指挥棒
			var kap_baton := MeshInstance3D.new()
			var kb2 := CylinderMesh.new()
			kb2.top_radius = 0.02
			kb2.bottom_radius = 0.03
			kb2.height = 0.65
			kap_baton.mesh = kb2
			var mat_kb2 := StandardMaterial3D.new()
			mat_kb2.albedo_color = Color(1.0, 1.0, 0.8)
			mat_kb2.emission_enabled = true
			mat_kb2.emission = Color(1.0, 1.0, 0.8)
			mat_kb2.emission_energy_multiplier = 3.5
			kap_baton.material_override = mat_kb2
			kap_baton.position = Vector3(0.4, 0.1, 0)
			kap_baton.rotation_degrees = Vector3(0, 0, -35)
			root.add_child(kap_baton)

		"ch5_symphony_commander":
			# 四乐章形态的指挥：中心球 + 四个不同颜色的小球
			var sym_colors := [
				Color(0.3, 0.5, 1.0),   # 第一乐章：蓝色
				Color(0.8, 0.4, 0.2),   # 第二乐章：橙色
				Color(0.3, 0.8, 0.4),   # 第三乐章：绿色
				Color(0.9, 0.2, 0.3),   # 第四乐章：红色
			]
			# 中心核
			var sym_core := MeshInstance3D.new()
			var sc_s := SphereMesh.new()
			sc_s.radius = 0.25
			sc_s.height = 0.5
			sym_core.mesh = sc_s
			var mat_sc := StandardMaterial3D.new()
			mat_sc.albedo_color = Color(1.0, 0.9, 0.7)
			mat_sc.emission_enabled = true
			mat_sc.emission = Color(1.0, 0.9, 0.7)
			mat_sc.emission_energy_multiplier = 3.0
			sym_core.material_override = mat_sc
			root.add_child(sym_core)
			# 四个乐章小球
			for i in range(4):
				var angle := (float(i) / 4.0) * TAU
				var movement := MeshInstance3D.new()
				var ms := SphereMesh.new()
				ms.radius = 0.15
				ms.height = 0.3
				movement.mesh = ms
				var mat_ms := StandardMaterial3D.new()
				mat_ms.albedo_color = sym_colors[i]
				mat_ms.emission_enabled = true
				mat_ms.emission = sym_colors[i]
				mat_ms.emission_energy_multiplier = 2.5
				movement.material_override = mat_ms
				movement.position = Vector3(cos(angle) * 0.55, sin(angle) * 0.55, 0)
				root.add_child(movement)

		"ch6_bebop_virtuoso":
			# 爵士风格的快速形态：主体 + 即兴粒子
			var bebop_color := Color(1.0, 0.4, 0.0)
			# 主体
			var bebop_body := MeshInstance3D.new()
			var bb := SphereMesh.new()
			bb.radius = 0.28
			bb.height = 0.56
			bebop_body.mesh = bb
			var mat_bb2 := StandardMaterial3D.new()
			mat_bb2.albedo_color = bebop_color
			mat_bb2.emission_enabled = true
			mat_bb2.emission = bebop_color
			mat_bb2.emission_energy_multiplier = 3.0
			bebop_body.material_override = mat_bb2
			root.add_child(bebop_body)
			# 即兴粒子（快速运动轨迹）
			var jazz_colors := [Color(1.0, 0.8, 0.0), Color(0.0, 0.8, 1.0), Color(1.0, 0.2, 0.5)]
			for i in range(6):
				var angle := (float(i) / 6.0) * TAU
				var radius_var := 0.5 + float(i % 3) * 0.1
				var particle := MeshInstance3D.new()
				var ps := SphereMesh.new()
				ps.radius = 0.06
				ps.height = 0.12
				particle.mesh = ps
				var mat_p := StandardMaterial3D.new()
				mat_p.albedo_color = jazz_colors[i % 3]
				mat_p.emission_enabled = true
				mat_p.emission = jazz_colors[i % 3]
				mat_p.emission_energy_multiplier = 4.0
				particle.material_override = mat_p
				particle.position = Vector3(cos(angle) * radius_var, sin(angle) * radius_var * 0.5, 0)
				root.add_child(particle)

		"ch7_frequency_overlord":
			# 控制频率的数字霸主：中心体 + 频率环
			var overlord_color := Color(0.0, 1.0, 0.8)
			# 主体（八面体）
			var overlord_body := MeshInstance3D.new()
			var ob := SphereMesh.new()
			ob.radius = 0.3
			ob.height = 0.6
			overlord_body.mesh = ob
			var mat_ob := StandardMaterial3D.new()
			mat_ob.albedo_color = Color(0.0, 0.2, 0.15)
			mat_ob.emission_enabled = true
			mat_ob.emission = overlord_color
			mat_ob.emission_energy_multiplier = 2.0
			overlord_body.material_override = mat_ob
			root.add_child(overlord_body)
			# 频率控制环
			var freq_colors := [Color(0.0, 1.0, 0.8), Color(0.0, 0.8, 1.0), Color(0.5, 0.0, 1.0)]
			for i in range(3):
				var freq_ring := MeshInstance3D.new()
				var fr_torus := TorusMesh.new()
				fr_torus.inner_radius = 0.38 + float(i) * 0.15
				fr_torus.outer_radius = 0.43 + float(i) * 0.15
				freq_ring.mesh = fr_torus
				var mat_fr := StandardMaterial3D.new()
				mat_fr.albedo_color = freq_colors[i]
				mat_fr.emission_enabled = true
				mat_fr.emission = freq_colors[i]
				mat_fr.emission_energy_multiplier = 3.5
				freq_ring.material_override = mat_fr
				freq_ring.rotation_degrees = Vector3(float(i) * 30, float(i) * 45, float(i) * 60)
				root.add_child(freq_ring)
			# 数字小方块粒子
			for i in range(8):
				var angle := (float(i) / 8.0) * TAU
				var pixel := MeshInstance3D.new()
				var pb := BoxMesh.new()
				pb.size = Vector3(0.08, 0.08, 0.08)
				pixel.mesh = pb
				var mat_pix := StandardMaterial3D.new()
				mat_pix.albedo_color = overlord_color
				mat_pix.emission_enabled = true
				mat_pix.emission = overlord_color
				mat_pix.emission_energy_multiplier = 4.0
				pixel.material_override = mat_pix
				pixel.position = Vector3(cos(angle) * 0.75, sin(angle) * 0.75, 0)
				root.add_child(pixel)

		# 默认处理：未知敌人使用通用外观
		_:
			var default_mesh := MeshInstance3D.new()
			var default_sphere := SphereMesh.new()
			default_sphere.radius = 0.3
			default_sphere.height = 0.6
			default_mesh.mesh = default_sphere
			var mat_default := StandardMaterial3D.new()
			mat_default.albedo_color = Color(0.6, 0.4, 0.8)
			mat_default.emission_enabled = true
			mat_default.emission = Color(0.6, 0.4, 0.8)
			mat_default.emission_energy_multiplier = 2.0
			default_mesh.material_override = mat_default
			root.add_child(default_mesh)

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
	var note_name: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
	_update_demo_status("施放 %s 音符" % note_name)

func _demo_cast_note_modifier(config: Dictionary) -> void:
	var note_key: int = config.get("demo_note", 0)
	var modifier: int = config.get("demo_modifier", 0)
	var spell_data := _build_demo_spell_data(note_key, modifier)
	_spawn_demo_3d_projectile(spell_data)
	# 额外生成修饰符视觉特效
	_spawn_demo_modifier_vfx(modifier, spell_data)
	_update_demo_status("施放 %s + %s" % [
		MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?"),
		_get_modifier_display_name(modifier)
	])

func _demo_cast_chord(config: Dictionary) -> void:
	var chord_type: int = config.get("demo_chord_type", 0)
	var chord_name: String = MusicData.CHORD_SPELL_MAP.get(chord_type, {}).get("name", "未知")
	_update_demo_status("施放 %s 和弦" % chord_name)
	_spawn_demo_chord_vfx(chord_type)

func _demo_cast_rhythm(config: Dictionary) -> void:
	var rhythm_pattern: String = config.get("demo_rhythm_pattern", "")
	var note_key: int = config.get("demo_note", 4)  # 默认 G 音符
	var spell_data := _build_demo_spell_data(note_key, -1)
	_spawn_demo_rhythm_vfx(rhythm_pattern, spell_data)
	_update_demo_status("节奏型演示: %s" % rhythm_pattern)

func _build_demo_spell_data(white_key: int, modifier: int) -> Dictionary:
	var stats: Dictionary = MusicData.WHITE_KEY_STATS.get(white_key, {})
	# BUG FIX: WHITE_KEY_STATS 中没有 color 字段，必需从 NOTE_COLORS 获取音符颜色
	var color: Color = MusicData.NOTE_COLORS.get(white_key, Color.WHITE)
	return {
		"white_key": white_key,
		"modifier": modifier,
		"dmg": stats.get("dmg", 2),
		"spd": stats.get("spd", 2),
		"dur": stats.get("dur", 2),
		"size": stats.get("size", 2),
		"color": color,
	}

func _spawn_demo_3d_projectile(spell_data: Dictionary) -> void:
	if not _demo_3d_entity_layer:
		return

	var color: Color = spell_data.get("color", Color.WHITE)
	var size_param: float = spell_data.get("size", 2.0)
	var spd_param: float = spell_data.get("spd", 2.0)
	var dur_param: float = spell_data.get("dur", 2.0)
	var dmg_param: float = spell_data.get("dmg", 2.0)

	# 根据 SIZE 参数计算弹体半径 (0.15 ~ 0.45)
	var radius: float = clampf(size_param * 0.08, 0.12, 0.5)
	# 根据 SPD 参数计算飞行时长 (SPD高则快)
	var duration: float = clampf(6.0 / max(spd_param, 0.5), 0.4, 3.0)

	# 主弹体网格实例
	var projectile := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	projectile.mesh = sphere_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	# 根据 DMG 参数调整发光强度
	mat.emission_energy_multiplier = 2.0 + dmg_param * 0.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	projectile.material_override = mat
	projectile.position = Vector3(-5, 0.5, 0)
	_demo_3d_entity_layer.add_child(projectile)

	# 拖尾粒子系统：根据 SIZE 和 SPD 生成不同数量的拖尾
	var trail_count: int = int(clampf(size_param * 1.5, 2, 8))
	for i in range(trail_count):
		var trail_delay: float = (i + 1) * 0.05
		get_tree().create_timer(trail_delay).timeout.connect(func():
			if not is_instance_valid(projectile) or not is_instance_valid(_demo_3d_entity_layer):
				return
			var trail := MeshInstance3D.new()
			var trail_mesh := SphereMesh.new()
			var trail_radius: float = radius * (1.0 - float(i) / float(trail_count))
			trail_mesh.radius = trail_radius
			trail_mesh.height = trail_radius * 2.0
			trail.mesh = trail_mesh
			var trail_mat := StandardMaterial3D.new()
			var trail_alpha: float = 0.6 - float(i) * 0.08
			trail_mat.albedo_color = Color(color.r, color.g, color.b, trail_alpha)
			trail_mat.emission_enabled = true
			trail_mat.emission = color
			trail_mat.emission_energy_multiplier = 1.5
			trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			trail.material_override = trail_mat
			trail.position = projectile.position
			_demo_3d_entity_layer.add_child(trail)
			var trail_tween := create_tween()
			trail_tween.tween_property(trail_mat, "albedo_color:a", 0.0, 0.3)
			trail_tween.tween_callback(trail.queue_free)
		)

	# 主弹体飞行动画
	var tween := create_tween()
	tween.tween_property(projectile, "position:x", 5.0, duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	# 命中闪光效果
	tween.tween_callback(func():
		if is_instance_valid(_demo_3d_entity_layer):
			_spawn_demo_3d_impact(projectile.position, color, radius)
	)
	tween.tween_callback(projectile.queue_free)

## 弹体命中闪光特效
func _spawn_demo_3d_impact(pos: Vector3, color: Color, radius: float) -> void:
	if not _demo_3d_entity_layer:
		return
	var burst_count: int = 6
	for i in range(burst_count):
		var spark := MeshInstance3D.new()
		var spark_mesh := SphereMesh.new()
		spark_mesh.radius = radius * 0.3
		spark_mesh.height = radius * 0.6
		spark.mesh = spark_mesh
		var spark_mat := StandardMaterial3D.new()
		spark_mat.albedo_color = color
		spark_mat.emission_enabled = true
		spark_mat.emission = color
		spark_mat.emission_energy_multiplier = 3.0
		spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spark.material_override = spark_mat
		spark.position = pos
		_demo_3d_entity_layer.add_child(spark)
		var angle: float = (TAU / burst_count) * i
		var target_pos := pos + Vector3(cos(angle) * 0.8, sin(angle) * 0.5, 0)
		var spark_tween := create_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "position", target_pos, 0.3)
		spark_tween.tween_property(spark_mat, "albedo_color:a", 0.0, 0.4)
		spark_tween.chain()
		spark_tween.tween_callback(spark.queue_free)

## 和弦法术演示特效：根据和弦类型生成独特视觉效果
func _spawn_demo_chord_vfx(chord_type: int) -> void:
	if not _demo_3d_entity_layer:
		return

	# 和弦法术颜色映射
	var chord_colors: Dictionary = {
		0: Color(1.0, 0.9, 0.3),   # MAJOR 大三 - 圣光金
		1: Color(0.4, 0.2, 0.8),   # MINOR 小三 - 暗紫
		2: Color(1.0, 0.5, 0.0),   # AUGMENTED 增三 - 烈焰橙
		3: Color(0.5, 0.0, 0.8),   # DIMINISHED 减三 - 深紫
		4: Color(0.9, 0.8, 0.0),   # DOMINANT_7 属七 - 黄金
		5: Color(0.8, 0.0, 0.0),   # DIMINISHED_7 减七 - 血红
		6: Color(0.2, 0.9, 0.4),   # MAJOR_7 大七 - 治愈绿
		7: Color(0.15, 0.15, 0.7), # MINOR_7 小七 - 深蓝
		8: Color(0.9, 0.9, 1.0),   # SUSPENDED 挂留 - 银白
		9: Color(0.3, 0.8, 1.0),   # DOMINANT_9 属九 - 风暴蓝
		10: Color(1.0, 0.95, 0.6), # MAJOR_9 大九 - 圣光金
		11: Color(0.8, 0.0, 0.8),  # DIMINISHED_9 减九 - 湮灭紫
		13: Color(1.0, 0.6, 0.0),  # DOMINANT_13 属十三 - 交响橙
		14: Color(1.0, 0.0, 0.0),  # DIMINISHED_13 减十三 - 终焉红
	}
	var color: Color = chord_colors.get(chord_type, UIColors.ACCENT)

	match chord_type:
		0:  # MAJOR 大三 - 强化弹体：金色光球扩展
			_demo_chord_enhanced_projectile(color)
		1:  # MINOR 小三 - DOT弹体：暗色漩渍碗云
			_demo_chord_dot_projectile(color)
		2:  # AUGMENTED 增三 - 爆炸弹体：火焰爆炸
			_demo_chord_explosive(color)
		3:  # DIMINISHED 减三 - 冲击波：环形波纹
			_demo_chord_shockwave(color)
		4:  # DOMINANT_7 属七 - 法阵：旋转几何法阵
			_demo_chord_field(color)
		5:  # DIMINISHED_7 减七 - 天降打击：预警+光柱
			_demo_chord_divine_strike(color)
		6:  # MAJOR_7 大七 - 护盾/治疗：绿色护盾泡
			_demo_chord_shield_heal(color)
		7:  # MINOR_7 小七 - 召唤：构造体生成
			_demo_chord_summon(color)
		8:  # SUSPENDED 挂留 - 蓄力弹体：能量踟缩释放
			_demo_chord_charged(color)
		9:  # DOMINANT_9 属九 - 风暴区域：旋转风暴
			_demo_chord_storm_field(color)
		10: # MAJOR_9 大九 - 圣光领域：金色光柱治疗光环
			_demo_chord_holy_domain(color)
		11: # DIMINISHED_9 减九 - 湮灭射线：紫色激光
			_demo_chord_annihilation_ray(color)
		13: # DOMINANT_13 属十三 - 交响风暴：多波次弹幕
			_demo_chord_symphony_storm(color)
		14: # DIMINISHED_13 减十三 - 终焉乐章：全屏毁灭
			_demo_chord_finale(color)
		_:  # 默认处理
			_demo_chord_default(color)

## 强化弹体演示：金色光球+六边形能量网格
func _demo_chord_enhanced_projectile(color: Color) -> void:
	var orb := MeshInstance3D.new()
	orb.mesh = SphereMesh.new()
	(orb.mesh as SphereMesh).radius = 0.4
	(orb.mesh as SphereMesh).height = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb.material_override = mat
	orb.position = Vector3(-3, 1, 0)
	_demo_3d_entity_layer.add_child(orb)
	# 外圈光环
	var ring := MeshInstance3D.new()
	ring.mesh = TorusMesh.new()
	(ring.mesh as TorusMesh).inner_radius = 0.45
	(ring.mesh as TorusMesh).outer_radius = 0.55
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = color.lightened(0.3)
	ring_mat.emission_enabled = true
	ring_mat.emission = color
	ring_mat.emission_energy_multiplier = 3.0
	ring.material_override = ring_mat
	ring.position = Vector3(-3, 1, 0)
	_demo_3d_entity_layer.add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(orb, "position:x", 3.0, 1.2)
	tween.tween_property(ring, "position:x", 3.0, 1.2)
	tween.tween_property(ring, "rotation:y", TAU, 1.2)
	tween.chain()
	tween.tween_callback(orb.queue_free)
	tween.tween_callback(ring.queue_free)

## DOT弹体演示：暗色漩渍碗云+漩渍滚落
func _demo_chord_dot_projectile(color: Color) -> void:
	var orb := MeshInstance3D.new()
	orb.mesh = SphereMesh.new()
	(orb.mesh as SphereMesh).radius = 0.35
	(orb.mesh as SphereMesh).height = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb.material_override = mat
	orb.position = Vector3(-3, 1, 0)
	_demo_3d_entity_layer.add_child(orb)
	# 漩渍碗云拖尾
	for i in range(5):
		get_tree().create_timer(i * 0.1).timeout.connect(func():
			if not is_instance_valid(_demo_3d_entity_layer): return
			var cloud := MeshInstance3D.new()
			cloud.mesh = SphereMesh.new()
			(cloud.mesh as SphereMesh).radius = 0.2 + i * 0.05
			(cloud.mesh as SphereMesh).height = (0.2 + i * 0.05) * 2
			var cloud_mat := StandardMaterial3D.new()
			cloud_mat.albedo_color = Color(color.r, color.g, color.b, 0.5 - i * 0.08)
			cloud_mat.emission_enabled = true
			cloud_mat.emission = color
			cloud_mat.emission_energy_multiplier = 1.5
			cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cloud.material_override = cloud_mat
			cloud.position = orb.position
			_demo_3d_entity_layer.add_child(cloud)
			var cloud_tween := create_tween()
			cloud_tween.tween_property(cloud_mat, "albedo_color:a", 0.0, 0.6)
			cloud_tween.tween_callback(cloud.queue_free)
		)
	var tween := create_tween()
	tween.tween_property(orb, "position:x", 3.0, 1.5)
	tween.tween_callback(orb.queue_free)

## 爆炸弹体演示：火焰球命中爆炸
func _demo_chord_explosive(color: Color) -> void:
	var orb := MeshInstance3D.new()
	orb.mesh = SphereMesh.new()
	(orb.mesh as SphereMesh).radius = 0.3
	(orb.mesh as SphereMesh).height = 0.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 6.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb.material_override = mat
	orb.position = Vector3(-3, 1, 0)
	_demo_3d_entity_layer.add_child(orb)
	var tween := create_tween()
	tween.tween_property(orb, "position:x", 1.0, 0.6)
	tween.tween_callback(func():
		if is_instance_valid(orb): orb.queue_free()
		if not is_instance_valid(_demo_3d_entity_layer): return
		# 爆炸效果：多个火花向外扩散
		for i in range(8):
			var spark := MeshInstance3D.new()
			spark.mesh = SphereMesh.new()
			(spark.mesh as SphereMesh).radius = 0.15
			(spark.mesh as SphereMesh).height = 0.3
			var spark_mat := StandardMaterial3D.new()
			spark_mat.albedo_color = color
			spark_mat.emission_enabled = true
			spark_mat.emission = color
			spark_mat.emission_energy_multiplier = 5.0
			spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			spark.material_override = spark_mat
			spark.position = Vector3(1, 1, 0)
			_demo_3d_entity_layer.add_child(spark)
			var angle: float = (TAU / 8) * i
			var target := Vector3(1 + cos(angle) * 2.0, 1 + sin(angle) * 1.5, 0)
			var s_tween := create_tween()
			s_tween.set_parallel(true)
			s_tween.tween_property(spark, "position", target, 0.5)
			s_tween.tween_property(spark_mat, "albedo_color:a", 0.0, 0.6)
			s_tween.chain()
			s_tween.tween_callback(spark.queue_free)
	)

## 冲击波演示：环形波纹向外扩散
func _demo_chord_shockwave(color: Color) -> void:
	# 创建多层冲击波环
	for i in range(3):
		get_tree().create_timer(i * 0.15).timeout.connect(func():
			if not is_instance_valid(_demo_3d_entity_layer): return
			var ring := MeshInstance3D.new()
			ring.mesh = TorusMesh.new()
			(ring.mesh as TorusMesh).inner_radius = 0.05
			(ring.mesh as TorusMesh).outer_radius = 0.15
			var ring_mat := StandardMaterial3D.new()
			ring_mat.albedo_color = Color(color.r, color.g, color.b, 0.8 - i * 0.2)
			ring_mat.emission_enabled = true
			ring_mat.emission = color
			ring_mat.emission_energy_multiplier = 4.0
			ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ring.material_override = ring_mat
			ring.position = Vector3(0, 0.5, 0)
			ring.rotation = Vector3(PI / 2, 0, 0)
			_demo_3d_entity_layer.add_child(ring)
			var r_tween := create_tween()
			r_tween.set_parallel(true)
			r_tween.tween_property(ring, "scale", Vector3(8, 8, 8), 0.8)
			r_tween.tween_property(ring_mat, "albedo_color:a", 0.0, 1.0)
			r_tween.chain()
			r_tween.tween_callback(ring.queue_free)
		)

## 法阵演示：旋转几何法阵+上升粒子
func _demo_chord_field(color: Color) -> void:
	# 外圈圆盘
	var outer := MeshInstance3D.new()
	outer.mesh = CylinderMesh.new()
	(outer.mesh as CylinderMesh).top_radius = 2.5
	(outer.mesh as CylinderMesh).bottom_radius = 2.5
	(outer.mesh as CylinderMesh).height = 0.05
	var outer_mat := StandardMaterial3D.new()
	outer_mat.albedo_color = Color(color.r, color.g, color.b, 0.3)
	outer_mat.emission_enabled = true
	outer_mat.emission = color
	outer_mat.emission_energy_multiplier = 2.0
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer.material_override = outer_mat
	outer.position = Vector3(0, 0.1, 0)
	_demo_3d_entity_layer.add_child(outer)
	# 内圈旋转六边形
	var inner := MeshInstance3D.new()
	inner.mesh = CylinderMesh.new()
	(inner.mesh as CylinderMesh).top_radius = 1.5
	(inner.mesh as CylinderMesh).bottom_radius = 1.5
	(inner.mesh as CylinderMesh).height = 0.05
	var inner_mat := StandardMaterial3D.new()
	inner_mat.albedo_color = Color(color.r, color.g, color.b, 0.4)
	inner_mat.emission_enabled = true
	inner_mat.emission = color
	inner_mat.emission_energy_multiplier = 3.0
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner.material_override = inner_mat
	inner.position = Vector3(0, 0.1, 0)
	_demo_3d_entity_layer.add_child(inner)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(outer, "rotation:y", TAU, 3.0)
	tween.tween_property(inner, "rotation:y", -TAU, 3.0)
	tween.chain()
	tween.tween_callback(outer.queue_free)
	tween.tween_callback(inner.queue_free)

## 天降打击演示：预警标记+光柱落下
func _demo_chord_divine_strike(color: Color) -> void:
	# 预警圆圈
	var warning := MeshInstance3D.new()
	warning.mesh = TorusMesh.new()
	(warning.mesh as TorusMesh).inner_radius = 1.4
	(warning.mesh as TorusMesh).outer_radius = 1.6
	var warn_mat := StandardMaterial3D.new()
	warn_mat.albedo_color = Color(1.0, 0.0, 0.0, 0.5)
	warn_mat.emission_enabled = true
	warn_mat.emission = Color(1.0, 0.0, 0.0)
	warn_mat.emission_energy_multiplier = 3.0
	warn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning.material_override = warn_mat
	warning.position = Vector3(0, 0.1, 0)
	warning.rotation = Vector3(PI / 2, 0, 0)
	_demo_3d_entity_layer.add_child(warning)
	# 预警收缩动画
	var tween := create_tween()
	tween.tween_property(warning, "scale", Vector3(0.5, 0.5, 0.5), 0.8)
	tween.tween_callback(func():
		if is_instance_valid(warning): warning.queue_free()
		if not is_instance_valid(_demo_3d_entity_layer): return
		# 天降光柱
		var strike := MeshInstance3D.new()
		strike.mesh = CylinderMesh.new()
		(strike.mesh as CylinderMesh).top_radius = 0.3
		(strike.mesh as CylinderMesh).bottom_radius = 0.3
		(strike.mesh as CylinderMesh).height = 8.0
		var strike_mat := StandardMaterial3D.new()
		strike_mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
		strike_mat.emission_enabled = true
		strike_mat.emission = color
		strike_mat.emission_energy_multiplier = 8.0
		strike_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		strike.material_override = strike_mat
		strike.position = Vector3(0, 4, 0)
		_demo_3d_entity_layer.add_child(strike)
		var s_tween := create_tween()
		s_tween.tween_property(strike_mat, "albedo_color:a", 0.0, 0.5)
		s_tween.tween_callback(strike.queue_free)
	)

## 护盾/治疗演示：绿色护盾泡泡+治疗光点
func _demo_chord_shield_heal(color: Color) -> void:
	# 护盾半球
	var shield := MeshInstance3D.new()
	shield.mesh = SphereMesh.new()
	(shield.mesh as SphereMesh).radius = 1.5
	(shield.mesh as SphereMesh).height = 3.0
	var shield_mat := StandardMaterial3D.new()
	shield_mat.albedo_color = Color(color.r, color.g, color.b, 0.2)
	shield_mat.emission_enabled = true
	shield_mat.emission = color
	shield_mat.emission_energy_multiplier = 2.0
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield.material_override = shield_mat
	shield.position = Vector3(0, 0.5, 0)
	_demo_3d_entity_layer.add_child(shield)
	# 治疗光点从外向内汇聚
	for i in range(8):
		get_tree().create_timer(i * 0.1).timeout.connect(func():
			if not is_instance_valid(_demo_3d_entity_layer): return
			var particle := MeshInstance3D.new()
			particle.mesh = SphereMesh.new()
			(particle.mesh as SphereMesh).radius = 0.08
			(particle.mesh as SphereMesh).height = 0.16
			var p_mat := StandardMaterial3D.new()
			p_mat.albedo_color = Color(0.5, 1.0, 0.6, 0.9)
			p_mat.emission_enabled = true
			p_mat.emission = Color(0.3, 1.0, 0.5)
			p_mat.emission_energy_multiplier = 4.0
			p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			particle.material_override = p_mat
			var angle: float = (TAU / 8) * i
			particle.position = Vector3(cos(angle) * 2.5, 0.5, sin(angle) * 2.5)
			_demo_3d_entity_layer.add_child(particle)
			var p_tween := create_tween()
			p_tween.set_parallel(true)
			p_tween.tween_property(particle, "position", Vector3(0, 0.5, 0), 0.6)
			p_tween.tween_property(p_mat, "albedo_color:a", 0.0, 0.7)
			p_tween.chain()
			p_tween.tween_callback(particle.queue_free)
		)
	var tween := create_tween()
	tween.tween_property(shield_mat, "albedo_color:a", 0.0, 3.0)
	tween.tween_callback(shield.queue_free)

## 召唤演示：构造体从地面生长
func _demo_chord_summon(color: Color) -> void:
	# 召唤阵圆
	var circle := MeshInstance3D.new()
	circle.mesh = TorusMesh.new()
	(circle.mesh as TorusMesh).inner_radius = 1.2
	(circle.mesh as TorusMesh).outer_radius = 1.4
	var circle_mat := StandardMaterial3D.new()
	circle_mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	circle_mat.emission_enabled = true
	circle_mat.emission = color
	circle_mat.emission_energy_multiplier = 3.0
	circle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	circle.material_override = circle_mat
	circle.position = Vector3(0, 0.1, 0)
	circle.rotation = Vector3(PI / 2, 0, 0)
	_demo_3d_entity_layer.add_child(circle)
	var c_tween := create_tween()
	c_tween.tween_property(circle, "rotation:z", TAU, 1.5)
	c_tween.parallel().tween_property(circle_mat, "albedo_color:a", 0.0, 1.8)
	c_tween.tween_callback(circle.queue_free)
	# 构造体从下方生长
	get_tree().create_timer(0.5).timeout.connect(func():
		if not is_instance_valid(_demo_3d_entity_layer): return
		var construct := MeshInstance3D.new()
		construct.mesh = BoxMesh.new()
		(construct.mesh as BoxMesh).size = Vector3(0.6, 0.6, 0.6)
		var c_mat := StandardMaterial3D.new()
		c_mat.albedo_color = color
		c_mat.emission_enabled = true
		c_mat.emission = color
		c_mat.emission_energy_multiplier = 3.0
		construct.material_override = c_mat
		construct.position = Vector3(0, -0.5, 0)
		_demo_3d_entity_layer.add_child(construct)
		var grow_tween := create_tween()
		grow_tween.tween_property(construct, "position:y", 0.8, 0.6)
		grow_tween.tween_property(construct, "rotation:y", TAU, 2.0)
		grow_tween.tween_callback(construct.queue_free)
	)

## 蓄力弹体演示：能量球蓄力至最大后释放
func _demo_chord_charged(color: Color) -> void:
	# 蓄力能量球
	var orb := MeshInstance3D.new()
	orb.mesh = SphereMesh.new()
	(orb.mesh as SphereMesh).radius = 0.15
	(orb.mesh as SphereMesh).height = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 6.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb.material_override = mat
	orb.position = Vector3(-2, 1, 0)
	_demo_3d_entity_layer.add_child(orb)
	# 能量线条被吸入
	for i in range(6):
		var angle: float = (TAU / 6) * i
		var start_pos := Vector3(-2 + cos(angle) * 1.5, 1 + sin(angle) * 1.0, 0)
		get_tree().create_timer(i * 0.1).timeout.connect(func():
			if not is_instance_valid(_demo_3d_entity_layer): return
			var line_node := MeshInstance3D.new()
			line_node.mesh = CylinderMesh.new()
			(line_node.mesh as CylinderMesh).top_radius = 0.02
			(line_node.mesh as CylinderMesh).bottom_radius = 0.02
			(line_node.mesh as CylinderMesh).height = 1.5
			var l_mat := StandardMaterial3D.new()
			l_mat.albedo_color = Color(color.r, color.g, color.b, 0.6)
			l_mat.emission_enabled = true
			l_mat.emission = color
			l_mat.emission_energy_multiplier = 2.0
			l_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			line_node.material_override = l_mat
			line_node.position = start_pos.lerp(Vector3(-2, 1, 0), 0.5)
			line_node.look_at(Vector3(-2, 1, 0))
			_demo_3d_entity_layer.add_child(line_node)
			var l_tween := create_tween()
			l_tween.tween_property(l_mat, "albedo_color:a", 0.0, 0.4)
			l_tween.tween_callback(line_node.queue_free)
		)
	# 蓄力膨胀动画
	var tween := create_tween()
	tween.tween_property(orb, "scale", Vector3(4, 4, 4), 1.0)
	tween.tween_callback(func():
		if is_instance_valid(orb): orb.queue_free()
		if not is_instance_valid(_demo_3d_entity_layer): return
		# 释放闪光
		var flash := MeshInstance3D.new()
		flash.mesh = SphereMesh.new()
		(flash.mesh as SphereMesh).radius = 0.8
		(flash.mesh as SphereMesh).height = 1.6
		var f_mat := StandardMaterial3D.new()
		f_mat.albedo_color = Color.WHITE
		f_mat.emission_enabled = true
		f_mat.emission = Color.WHITE
		f_mat.emission_energy_multiplier = 10.0
		f_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flash.material_override = f_mat
		flash.position = Vector3(-2, 1, 0)
		_demo_3d_entity_layer.add_child(flash)
		var f_tween := create_tween()
		f_tween.tween_property(f_mat, "albedo_color:a", 0.0, 0.3)
		f_tween.tween_callback(flash.queue_free)
	)

## 风暴区域演示：旋转风暴漩渍
func _demo_chord_storm_field(color: Color) -> void:
	# 中心旋转圆盘
	var disk := MeshInstance3D.new()
	disk.mesh = CylinderMesh.new()
	(disk.mesh as CylinderMesh).top_radius = 2.0
	(disk.mesh as CylinderMesh).bottom_radius = 2.0
	(disk.mesh as CylinderMesh).height = 0.05
	var disk_mat := StandardMaterial3D.new()
	disk_mat.albedo_color = Color(color.r, color.g, color.b, 0.2)
	disk_mat.emission_enabled = true
	disk_mat.emission = color
	disk_mat.emission_energy_multiplier = 2.0
	disk_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disk.material_override = disk_mat
	disk.position = Vector3(0, 0.1, 0)
	_demo_3d_entity_layer.add_child(disk)
	# 旋转风暴臂
	for i in range(3):
		var arm := MeshInstance3D.new()
		arm.mesh = CylinderMesh.new()
		(arm.mesh as CylinderMesh).top_radius = 0.08
		(arm.mesh as CylinderMesh).bottom_radius = 0.08
		(arm.mesh as CylinderMesh).height = 2.0
		var arm_mat := StandardMaterial3D.new()
		arm_mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
		arm_mat.emission_enabled = true
		arm_mat.emission = color
		arm_mat.emission_energy_multiplier = 4.0
		arm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		arm.material_override = arm_mat
		arm.position = Vector3(0, 0.5, 0)
		arm.rotation = Vector3(0, (TAU / 3) * i, PI / 2)
		_demo_3d_entity_layer.add_child(arm)
		var a_tween := create_tween()
		a_tween.tween_property(arm, "rotation:y", (TAU / 3) * i + TAU, 3.0)
		a_tween.tween_callback(arm.queue_free)
	var d_tween := create_tween()
	d_tween.tween_property(disk, "rotation:y", TAU, 3.0)
	d_tween.tween_callback(disk.queue_free)

## 圣光领域演示：金色光柱+治疗光环
func _demo_chord_holy_domain(color: Color) -> void:
	# 光柱
	var pillar := MeshInstance3D.new()
	pillar.mesh = CylinderMesh.new()
	(pillar.mesh as CylinderMesh).top_radius = 0.8
	(pillar.mesh as CylinderMesh).bottom_radius = 0.8
	(pillar.mesh as CylinderMesh).height = 6.0
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(color.r, color.g, color.b, 0.25)
	pillar_mat.emission_enabled = true
	pillar_mat.emission = color
	pillar_mat.emission_energy_multiplier = 3.0
	pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pillar.material_override = pillar_mat
	pillar.position = Vector3(0, 3, 0)
	_demo_3d_entity_layer.add_child(pillar)
	# 圆形光环
	var aura := MeshInstance3D.new()
	aura.mesh = TorusMesh.new()
	(aura.mesh as TorusMesh).inner_radius = 1.8
	(aura.mesh as TorusMesh).outer_radius = 2.0
	var aura_mat := StandardMaterial3D.new()
	aura_mat.albedo_color = Color(color.r, color.g, color.b, 0.5)
	aura_mat.emission_enabled = true
	aura_mat.emission = color
	aura_mat.emission_energy_multiplier = 3.0
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura.material_override = aura_mat
	aura.position = Vector3(0, 0.3, 0)
	aura.rotation = Vector3(PI / 2, 0, 0)
	_demo_3d_entity_layer.add_child(aura)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(pillar_mat, "albedo_color:a", 0.0, 3.0)
	tween.tween_property(aura, "rotation:z", TAU, 3.0)
	tween.chain()
	tween.tween_callback(pillar.queue_free)
	tween.tween_callback(aura.queue_free)

## 湮灭射线演示：紫色激光贯穿全屏
func _demo_chord_annihilation_ray(color: Color) -> void:
	# 主射线圆柱
	var ray := MeshInstance3D.new()
	ray.mesh = CylinderMesh.new()
	(ray.mesh as CylinderMesh).top_radius = 0.15
	(ray.mesh as CylinderMesh).bottom_radius = 0.15
	(ray.mesh as CylinderMesh).height = 12.0
	var ray_mat := StandardMaterial3D.new()
	ray_mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	ray_mat.emission_enabled = true
	ray_mat.emission = color
	ray_mat.emission_energy_multiplier = 8.0
	ray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray.material_override = ray_mat
	ray.position = Vector3(0, 0.5, 0)
	ray.rotation = Vector3(0, 0, PI / 2)
	_demo_3d_entity_layer.add_child(ray)
	# 外圈光晕
	var glow := MeshInstance3D.new()
	glow.mesh = CylinderMesh.new()
	(glow.mesh as CylinderMesh).top_radius = 0.5
	(glow.mesh as CylinderMesh).bottom_radius = 0.5
	(glow.mesh as CylinderMesh).height = 12.0
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(color.r, color.g, color.b, 0.2)
	glow_mat.emission_enabled = true
	glow_mat.emission = color
	glow_mat.emission_energy_multiplier = 2.0
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.material_override = glow_mat
	glow.position = Vector3(0, 0.5, 0)
	glow.rotation = Vector3(0, 0, PI / 2)
	_demo_3d_entity_layer.add_child(glow)
	var tween := create_tween()
	tween.tween_property(ray, "scale:x", 3.0, 0.1)
	tween.tween_property(ray, "scale:x", 0.3, 0.5)
	tween.parallel().tween_property(ray_mat, "albedo_color:a", 0.0, 0.6)
	tween.tween_callback(ray.queue_free)
	var g_tween := create_tween()
	g_tween.tween_property(glow_mat, "albedo_color:a", 0.0, 0.7)
	g_tween.tween_callback(glow.queue_free)

## 交响风暴演示：多波次环形弹幕
func _demo_chord_symphony_storm(color: Color) -> void:
	var wave_colors: Array = [
		Color(1.0, 0.3, 0.0),
		Color(0.0, 0.8, 1.0),
		Color(1.0, 1.0, 0.0),
	]
	for wave in range(3):
		get_tree().create_timer(wave * 0.4).timeout.connect(func():
			if not is_instance_valid(_demo_3d_entity_layer): return
			var wave_color: Color = wave_colors[wave % wave_colors.size()]
			var ring := MeshInstance3D.new()
			ring.mesh = TorusMesh.new()
			(ring.mesh as TorusMesh).inner_radius = 0.1
			(ring.mesh as TorusMesh).outer_radius = 0.2
			var ring_mat := StandardMaterial3D.new()
			ring_mat.albedo_color = Color(wave_color.r, wave_color.g, wave_color.b, 0.8)
			ring_mat.emission_enabled = true
			ring_mat.emission = wave_color
			ring_mat.emission_energy_multiplier = 5.0
			ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ring.material_override = ring_mat
			ring.position = Vector3(0, 0.5, 0)
			ring.rotation = Vector3(PI / 2, 0, 0)
			_demo_3d_entity_layer.add_child(ring)
			var r_tween := create_tween()
			r_tween.set_parallel(true)
			r_tween.tween_property(ring, "scale", Vector3(12, 12, 12), 0.6)
			r_tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.7)
			r_tween.chain()
			r_tween.tween_callback(ring.queue_free)
		)

## 终焉乐章演示：全屏收缩后爆发
func _demo_chord_finale(color: Color) -> void:
	# 先创建多个向中心收缩的环
	for i in range(4):
		get_tree().create_timer(i * 0.1).timeout.connect(func():
			if not is_instance_valid(_demo_3d_entity_layer): return
			var ring := MeshInstance3D.new()
			ring.mesh = TorusMesh.new()
			(ring.mesh as TorusMesh).inner_radius = 0.1
			(ring.mesh as TorusMesh).outer_radius = 0.2
			var ring_mat := StandardMaterial3D.new()
			ring_mat.albedo_color = Color(color.r, color.g, color.b, 0.6)
			ring_mat.emission_enabled = true
			ring_mat.emission = color
			ring_mat.emission_energy_multiplier = 5.0
			ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ring.material_override = ring_mat
			ring.position = Vector3(0, 0.5, 0)
			ring.rotation = Vector3(PI / 2, 0, 0)
			ring.scale = Vector3(8 - i, 8 - i, 8 - i)
			_demo_3d_entity_layer.add_child(ring)
			var r_tween := create_tween()
			r_tween.tween_property(ring, "scale", Vector3(0.5, 0.5, 0.5), 0.6)
			r_tween.tween_callback(func():
				if is_instance_valid(ring): ring.queue_free()
			)
		)
	# 最终爆发
	get_tree().create_timer(0.7).timeout.connect(func():
		if not is_instance_valid(_demo_3d_entity_layer): return
		for i in range(12):
			var spark := MeshInstance3D.new()
			spark.mesh = SphereMesh.new()
			(spark.mesh as SphereMesh).radius = 0.2
			(spark.mesh as SphereMesh).height = 0.4
			var spark_mat := StandardMaterial3D.new()
			spark_mat.albedo_color = color
			spark_mat.emission_enabled = true
			spark_mat.emission = color
			spark_mat.emission_energy_multiplier = 8.0
			spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			spark.material_override = spark_mat
			spark.position = Vector3(0, 0.5, 0)
			_demo_3d_entity_layer.add_child(spark)
			var angle: float = (TAU / 12) * i
			var target := Vector3(cos(angle) * 3.0, 0.5 + sin(angle) * 2.0, 0)
			var s_tween := create_tween()
			s_tween.set_parallel(true)
			s_tween.tween_property(spark, "position", target, 0.6)
			s_tween.tween_property(spark_mat, "albedo_color:a", 0.0, 0.7)
			s_tween.chain()
			s_tween.tween_callback(spark.queue_free)
	)

## 默认和弦演示：通用光球扩展
func _demo_chord_default(color: Color) -> void:
	var sphere := MeshInstance3D.new()
	sphere.mesh = SphereMesh.new()
	(sphere.mesh as SphereMesh).radius = 0.4
	(sphere.mesh as SphereMesh).height = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material_override = mat
	sphere.position = Vector3(0, 1, 0)
	_demo_3d_entity_layer.add_child(sphere)
	var tween := create_tween()
	tween.tween_property(sphere, "scale", Vector3(4, 4, 4), 0.6)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tween.tween_callback(sphere.queue_free)

## 修饰符演示特效
func _spawn_demo_modifier_vfx(modifier: int, spell_data: Dictionary) -> void:
	if not _demo_3d_entity_layer:
		return
	var color: Color = spell_data.get("color", Color.WHITE)
	match modifier:
		0:  # PIERCE 穿透：多个弹体排成一行穿透
			for i in range(3):
				get_tree().create_timer(i * 0.25).timeout.connect(func():
					if not is_instance_valid(_demo_3d_entity_layer): return
					var extra := MeshInstance3D.new()
					extra.mesh = SphereMesh.new()
					(extra.mesh as SphereMesh).radius = 0.18
					(extra.mesh as SphereMesh).height = 0.36
					var e_mat := StandardMaterial3D.new()
					e_mat.albedo_color = Color(0.0, 0.9, 0.9)
					e_mat.emission_enabled = true
					e_mat.emission = Color(0.0, 0.9, 0.9)
					e_mat.emission_energy_multiplier = 4.0
					e_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					extra.material_override = e_mat
					extra.position = Vector3(-3.5 + i * 2.0, 0.5, 0)
					_demo_3d_entity_layer.add_child(extra)
					var e_tween := create_tween()
					e_tween.tween_property(extra, "position:x", extra.position.x + 6.0, 0.8)
					e_tween.tween_callback(extra.queue_free)
				)
		1:  # HOMING 追踪：弹体先向上弧形轨迹追踪目标
			var target_orb := MeshInstance3D.new()
			target_orb.mesh = SphereMesh.new()
			(target_orb.mesh as SphereMesh).radius = 0.3
			(target_orb.mesh as SphereMesh).height = 0.6
			var t_mat := StandardMaterial3D.new()
			t_mat.albedo_color = Color(1.0, 0.3, 0.3, 0.7)
			t_mat.emission_enabled = true
			t_mat.emission = Color(1.0, 0.3, 0.3)
			t_mat.emission_energy_multiplier = 3.0
			t_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			target_orb.material_override = t_mat
			target_orb.position = Vector3(3, 1, 0)
			_demo_3d_entity_layer.add_child(target_orb)
			# 弹体弧形轨迹追踪目标
			var homing := MeshInstance3D.new()
			homing.mesh = SphereMesh.new()
			(homing.mesh as SphereMesh).radius = 0.2
			(homing.mesh as SphereMesh).height = 0.4
			var h_mat := StandardMaterial3D.new()
			h_mat.albedo_color = Color(0.2, 0.6, 1.0)
			h_mat.emission_enabled = true
			h_mat.emission = Color(0.2, 0.6, 1.0)
			h_mat.emission_energy_multiplier = 4.0
			h_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			homing.material_override = h_mat
			homing.position = Vector3(-4, 0.5, 0)
			_demo_3d_entity_layer.add_child(homing)
			var h_tween := create_tween()
			h_tween.tween_property(homing, "position", Vector3(-1, 2.5, 0), 0.4)
			h_tween.tween_property(homing, "position", Vector3(3, 1, 0), 0.4)
			h_tween.tween_callback(homing.queue_free)
			h_tween.tween_callback(target_orb.queue_free)
		2:  # SPLIT 分裂：弹体命中后分裂为3个
			var main_orb := MeshInstance3D.new()
			main_orb.mesh = SphereMesh.new()
			(main_orb.mesh as SphereMesh).radius = 0.25
			(main_orb.mesh as SphereMesh).height = 0.5
			var m_mat := StandardMaterial3D.new()
			m_mat.albedo_color = Color(1.0, 0.5, 0.0)
			m_mat.emission_enabled = true
			m_mat.emission = Color(1.0, 0.5, 0.0)
			m_mat.emission_energy_multiplier = 4.0
			m_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			main_orb.material_override = m_mat
			main_orb.position = Vector3(-4, 0.5, 0)
			_demo_3d_entity_layer.add_child(main_orb)
			var m_tween := create_tween()
			m_tween.tween_property(main_orb, "position:x", 0.0, 0.5)
			m_tween.tween_callback(func():
				if is_instance_valid(main_orb): main_orb.queue_free()
				if not is_instance_valid(_demo_3d_entity_layer): return
				var split_dirs: Array = [
					Vector3(2, 1, 0), Vector3(2, 0, 0), Vector3(2, -1, 0)
				]
				for dir in split_dirs:
					var sub := MeshInstance3D.new()
					sub.mesh = SphereMesh.new()
					(sub.mesh as SphereMesh).radius = 0.15
					(sub.mesh as SphereMesh).height = 0.3
					var s_mat := StandardMaterial3D.new()
					s_mat.albedo_color = Color(1.0, 0.7, 0.3)
					s_mat.emission_enabled = true
					s_mat.emission = Color(1.0, 0.5, 0.0)
					s_mat.emission_energy_multiplier = 3.0
					s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					sub.material_override = s_mat
					sub.position = Vector3(0, 0.5, 0)
					_demo_3d_entity_layer.add_child(sub)
					var s_tween := create_tween()
					s_tween.tween_property(sub, "position", Vector3(0, 0.5, 0) + dir, 0.5)
					s_tween.tween_callback(sub.queue_free)
			)
		3:  # ECHO 回响：延迟后在原位置生成回响弹体
			get_tree().create_timer(0.6).timeout.connect(func():
				if not is_instance_valid(_demo_3d_entity_layer): return
				var echo := MeshInstance3D.new()
				echo.mesh = SphereMesh.new()
				(echo.mesh as SphereMesh).radius = 0.2
				(echo.mesh as SphereMesh).height = 0.4
				var e_mat := StandardMaterial3D.new()
				e_mat.albedo_color = Color(0.5, 0.5, 1.0, 0.7)
				e_mat.emission_enabled = true
				e_mat.emission = Color(0.5, 0.5, 1.0)
				e_mat.emission_energy_multiplier = 3.0
				e_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				echo.material_override = e_mat
				echo.position = Vector3(-5, 0.5, 0)
				_demo_3d_entity_layer.add_child(echo)
				var e_tween := create_tween()
				e_tween.tween_property(echo, "position:x", 5.0, 1.0)
				e_tween.tween_callback(echo.queue_free)
			)
		4:  # SCATTER 散射：生成扇形散射弹体
			for i in range(5):
				get_tree().create_timer(i * 0.05).timeout.connect(func():
					if not is_instance_valid(_demo_3d_entity_layer): return
					var scatter := MeshInstance3D.new()
					scatter.mesh = SphereMesh.new()
					(scatter.mesh as SphereMesh).radius = 0.15
					(scatter.mesh as SphereMesh).height = 0.3
					var s_mat := StandardMaterial3D.new()
					s_mat.albedo_color = Color(1.0, 1.0, 0.0)
					s_mat.emission_enabled = true
					s_mat.emission = Color(1.0, 1.0, 0.0)
					s_mat.emission_energy_multiplier = 4.0
					s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					scatter.material_override = s_mat
					scatter.position = Vector3(-4, 0.5, 0)
					_demo_3d_entity_layer.add_child(scatter)
					var spread_angle: float = deg_to_rad(-20.0 + i * 10.0)
					var target := Vector3(-4 + cos(spread_angle) * 8.0, 0.5 + sin(spread_angle) * 3.0, 0)
					var s_tween := create_tween()
					s_tween.tween_property(scatter, "position", target, 0.8)
					s_tween.tween_callback(scatter.queue_free)
				)

## 节奏型演示特效
func _spawn_demo_rhythm_vfx(rhythm_pattern: String, spell_data: Dictionary) -> void:
	if not _demo_3d_entity_layer:
		return
	var color: Color = spell_data.get("color", Color(1.0, 0.3, 0.1))
	match rhythm_pattern:
		"full":  # 全音符 → 连射：快速发射多个弹体
			for i in range(4):
				get_tree().create_timer(i * 0.3).timeout.connect(func():
					if not is_instance_valid(_demo_3d_entity_layer): return
					var orb := MeshInstance3D.new()
					orb.mesh = SphereMesh.new()
					(orb.mesh as SphereMesh).radius = 0.18
					(orb.mesh as SphereMesh).height = 0.36
					var mat := StandardMaterial3D.new()
					mat.albedo_color = color
					mat.emission_enabled = true
					mat.emission = color
					mat.emission_energy_multiplier = 4.0
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					orb.material_override = mat
					orb.position = Vector3(-5, 0.5 + i * 0.3, 0)
					_demo_3d_entity_layer.add_child(orb)
					var o_tween := create_tween()
					o_tween.tween_property(orb, "position:x", 5.0, 0.6)
					o_tween.tween_callback(orb.queue_free)
				)
		"dotted":  # 附点节奏 → 重击：大弹体+击退效果
			var heavy := MeshInstance3D.new()
			heavy.mesh = SphereMesh.new()
			(heavy.mesh as SphereMesh).radius = 0.45
			(heavy.mesh as SphereMesh).height = 0.9
			var h_mat := StandardMaterial3D.new()
			h_mat.albedo_color = Color(1.0, 0.6, 0.2)
			h_mat.emission_enabled = true
			h_mat.emission = Color(1.0, 0.6, 0.2)
			h_mat.emission_energy_multiplier = 5.0
			h_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			heavy.material_override = h_mat
			heavy.position = Vector3(-4, 0.5, 0)
			_demo_3d_entity_layer.add_child(heavy)
			var h_tween := create_tween()
			h_tween.tween_property(heavy, "position:x", 2.0, 0.8)
			h_tween.tween_callback(func():
				if is_instance_valid(heavy): heavy.queue_free()
				# 击退波
				if not is_instance_valid(_demo_3d_entity_layer): return
				var wave := MeshInstance3D.new()
				wave.mesh = TorusMesh.new()
				(wave.mesh as TorusMesh).inner_radius = 0.05
				(wave.mesh as TorusMesh).outer_radius = 0.15
				var w_mat := StandardMaterial3D.new()
				w_mat.albedo_color = Color(1.0, 0.8, 0.3, 0.8)
				w_mat.emission_enabled = true
				w_mat.emission = Color(1.0, 0.6, 0.2)
				w_mat.emission_energy_multiplier = 4.0
				w_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wave.material_override = w_mat
				wave.position = Vector3(2, 0.5, 0)
				wave.rotation = Vector3(PI / 2, 0, 0)
				_demo_3d_entity_layer.add_child(wave)
				var w_tween := create_tween()
				w_tween.set_parallel(true)
				w_tween.tween_property(wave, "scale", Vector3(6, 6, 6), 0.5)
				w_tween.tween_property(w_mat, "albedo_color:a", 0.0, 0.6)
				w_tween.chain()
				w_tween.tween_callback(wave.queue_free)
			)
		"syncopated":  # 切分节奏 → 闪避射击：弹体发射时玩家向后闪现
			var orb := MeshInstance3D.new()
			orb.mesh = SphereMesh.new()
			(orb.mesh as SphereMesh).radius = 0.22
			(orb.mesh as SphereMesh).height = 0.44
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 4.0
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			orb.material_override = mat
			orb.position = Vector3(-4, 0.5, 0)
			_demo_3d_entity_layer.add_child(orb)
			# 玩家模拟块向后闪现
			var player_ghost := MeshInstance3D.new()
			player_ghost.mesh = BoxMesh.new()
			(player_ghost.mesh as BoxMesh).size = Vector3(0.5, 0.8, 0.3)
			var pg_mat := StandardMaterial3D.new()
			pg_mat.albedo_color = Color(0.5, 0.8, 1.0, 0.5)
			pg_mat.emission_enabled = true
			pg_mat.emission = Color(0.5, 0.8, 1.0)
			pg_mat.emission_energy_multiplier = 2.0
			pg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			player_ghost.material_override = pg_mat
			player_ghost.position = Vector3(0, 0.5, 0)
			_demo_3d_entity_layer.add_child(player_ghost)
			var o_tween := create_tween()
			o_tween.tween_property(orb, "position:x", 5.0, 0.8)
			o_tween.tween_callback(orb.queue_free)
			var pg_tween := create_tween()
			pg_tween.tween_property(player_ghost, "position:x", -1.5, 0.2)
			pg_tween.tween_property(pg_mat, "albedo_color:a", 0.0, 0.4)
			pg_tween.tween_callback(player_ghost.queue_free)
		"swing":  # 摇摆节奏 → S型波浪弹道
			var orb := MeshInstance3D.new()
			orb.mesh = SphereMesh.new()
			(orb.mesh as SphereMesh).radius = 0.22
			(orb.mesh as SphereMesh).height = 0.44
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.8, 0.5, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.5, 1.0)
			mat.emission_energy_multiplier = 4.0
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			orb.material_override = mat
			orb.position = Vector3(-4, 0.5, 0)
			_demo_3d_entity_layer.add_child(orb)
			# S型波浪轨迹
			var tween := create_tween()
			tween.tween_property(orb, "position", Vector3(-2, 1.5, 0), 0.3)
			tween.tween_property(orb, "position", Vector3(0, 0.5, 0), 0.3)
			tween.tween_property(orb, "position", Vector3(2, 1.5, 0), 0.3)
			tween.tween_property(orb, "position", Vector3(4, 0.5, 0), 0.3)
			tween.tween_callback(orb.queue_free)
		"triplet":  # 三连音 → 三连发：扇形三弹体
			var spread_angles: Array = [deg_to_rad(-15.0), 0.0, deg_to_rad(15.0)]
			for i in range(3):
				get_tree().create_timer(i * 0.08).timeout.connect(func():
					if not is_instance_valid(_demo_3d_entity_layer): return
					var orb := MeshInstance3D.new()
					orb.mesh = SphereMesh.new()
					(orb.mesh as SphereMesh).radius = 0.18
					(orb.mesh as SphereMesh).height = 0.36
					var mat := StandardMaterial3D.new()
					mat.albedo_color = Color(0.0, 1.0, 0.5)
					mat.emission_enabled = true
					mat.emission = Color(0.0, 1.0, 0.5)
					mat.emission_energy_multiplier = 4.0
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					orb.material_override = mat
					orb.position = Vector3(-4, 0.5, 0)
					_demo_3d_entity_layer.add_child(orb)
					var angle: float = spread_angles[i]
					var target := Vector3(-4 + cos(angle) * 8.0, 0.5 + sin(angle) * 3.0, 0)
					var o_tween := create_tween()
					o_tween.tween_property(orb, "position", target, 0.7)
					o_tween.tween_callback(orb.queue_free)
				)
		"rest_boost":  # 精准蓄力：能量漩渍后释放强化弹体
			# 蓄力阶段：能量环绕圆心旋转
			var charge_ring := MeshInstance3D.new()
			charge_ring.mesh = TorusMesh.new()
			(charge_ring.mesh as TorusMesh).inner_radius = 0.6
			(charge_ring.mesh as TorusMesh).outer_radius = 0.7
			var cr_mat := StandardMaterial3D.new()
			cr_mat.albedo_color = Color(1.0, 0.9, 0.3, 0.8)
			cr_mat.emission_enabled = true
			cr_mat.emission = Color(1.0, 0.9, 0.3)
			cr_mat.emission_energy_multiplier = 4.0
			cr_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			charge_ring.material_override = cr_mat
			charge_ring.position = Vector3(-3, 0.5, 0)
			charge_ring.rotation = Vector3(PI / 2, 0, 0)
			_demo_3d_entity_layer.add_child(charge_ring)
			var cr_tween := create_tween()
			cr_tween.tween_property(charge_ring, "rotation:z", TAU, 0.8)
			cr_tween.tween_callback(func():
				if is_instance_valid(charge_ring): charge_ring.queue_free()
				# 释放强化弹体
				if not is_instance_valid(_demo_3d_entity_layer): return
				var powered := MeshInstance3D.new()
				powered.mesh = SphereMesh.new()
				(powered.mesh as SphereMesh).radius = 0.4
				(powered.mesh as SphereMesh).height = 0.8
				var p_mat := StandardMaterial3D.new()
				p_mat.albedo_color = Color(1.0, 1.0, 0.5)
				p_mat.emission_enabled = true
				p_mat.emission = Color(1.0, 0.9, 0.3)
				p_mat.emission_energy_multiplier = 8.0
				p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				powered.material_override = p_mat
				powered.position = Vector3(-3, 0.5, 0)
				_demo_3d_entity_layer.add_child(powered)
				var p_tween := create_tween()
				p_tween.tween_property(powered, "position:x", 5.0, 0.5)
				p_tween.tween_callback(powered.queue_free)
			)
		_:  # 默认节奏型演示
			var orb := MeshInstance3D.new()
			orb.mesh = SphereMesh.new()
			(orb.mesh as SphereMesh).radius = 0.22
			(orb.mesh as SphereMesh).height = 0.44
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 4.0
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			orb.material_override = mat
			orb.position = Vector3(-4, 0.5, 0)
			_demo_3d_entity_layer.add_child(orb)
			var tween := create_tween()
			tween.tween_property(orb, "position:x", 4.0, 1.0)
			tween.tween_callback(orb.queue_free)

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
