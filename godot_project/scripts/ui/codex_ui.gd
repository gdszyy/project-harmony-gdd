## 图鉴系统 "谐振法典 (Codex Resonare)" UI 主界面 - v5.0 2.5D 渲染迁移版
##
## 视觉风格：充满神秘感的魔法书，背景为羊皮纸/星图纹理。
## 布局：顶部标题栏 + 左侧卷标签页/条目列表 + 右侧条目详情页（含法术演示区域）
## 功能：四卷完整数据浏览、条目解锁状态、搜索过滤、详情展示、法术演示
##
## ★ v5.0 变更 (Issue #36 — 2.5D 渲染迁移)：
##   - 法术演示区域升级为 2.5D 混合渲染：
##     · SubViewport 内嵌独立 3D 渲染管线（WorldEnvironment + Glow/Bloom）
##     · 弹体在 3D 空间渲染，带真实光照和发光效果
##     · 与主游戏 (main_game) 的视觉风格完全一致
##   - 敌人条目详情页新增 3D 预览：
##     · 使用独立 SubViewport 渲染敌人的 3D 代理模型
##     · 展示敌人的发光颜色、几何形态和粒子效果
##   - 背景增加微妙的 3D 粒子氛围效果
##   - 全局 Glow/Bloom 后处理，提升视觉一致性
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
# 敌人类型颜色映射（与 main_game / render_bridge_3d 一致）
# ============================================================
const ENEMY_TYPE_COLORS: Dictionary = {
	"static":  Color(0.7, 0.3, 0.3),
	"silence": Color(0.2, 0.1, 0.4),
	"screech": Color(1.0, 0.8, 0.0),
	"pulse":   Color(0.0, 0.5, 1.0),
	"wall":    Color(0.5, 0.5, 0.5),
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

# ★ 法术演示区域节点 (v5.0: 2.5D 升级)
var _demo_viewport: SubViewport = null
var _demo_viewport_container: SubViewportContainer = null
var _demo_projectile_manager: Node2D = null
var _demo_section: VBoxContainer = null
var _demo_cast_btn: Button = null
var _demo_clear_btn: Button = null
var _demo_info_label: Label = null
var _demo_status_label: Label = null

# ★ v5.0: 演示区域 3D 渲染节点
var _demo_3d_viewport: SubViewport = null
var _demo_3d_viewport_container: SubViewportContainer = null
var _demo_3d_camera: Camera3D = null
var _demo_3d_env: WorldEnvironment = null
var _demo_3d_entity_layer: Node3D = null
var _demo_3d_light: DirectionalLight3D = null

# ★ v5.0: 敌人 3D 预览节点
var _enemy_preview_viewport: SubViewport = null
var _enemy_preview_container: SubViewportContainer = null
var _enemy_preview_camera: Camera3D = null
var _enemy_preview_model: Node3D = null

# ★ v5.0: 背景 3D 氛围效果
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
	_build_bg_3d_atmosphere()
	_select_volume(0)

func _process(delta: float) -> void:
	# v5.1: 演示定时器（自动清理超过 5 秒的演示）
	if _demo_active:
		_demo_timer += delta
		if _demo_timer > 5.0:
			_clear_demo()

	# v5.0: 旋转敌人 3D 预览模型
	if _enemy_preview_model and is_instance_valid(_enemy_preview_model):
		_enemy_preview_model.rotation.y += delta * 1.5

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
# v5.0: 背景 3D 氛围效果
# ============================================================

## 在 UI 背景层叠加微妙的 3D 粒子氛围效果
func _build_bg_3d_atmosphere() -> void:
	# 创建背景 3D 视口
	_bg_3d_viewport_container = SubViewportContainer.new()
	_bg_3d_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_3d_viewport_container.stretch = true
	_bg_3d_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_3d_viewport_container.self_modulate = Color(1, 1, 1, 0.3)  # 半透明叠加

	_bg_3d_viewport = SubViewport.new()
	_bg_3d_viewport.size = Vector2i(1280, 720)
	_bg_3d_viewport.transparent_bg = true
	_bg_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_bg_3d_viewport.own_world_3d = true

	# 3D 摄像机
	var bg_camera := Camera3D.new()
	bg_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	bg_camera.size = 10.0
	bg_camera.position = Vector3(0, 10, 0)
	bg_camera.rotation_degrees = Vector3(-90, 0, 0)
	_bg_3d_viewport.add_child(bg_camera)

	# 环境（Glow/Bloom）
	var bg_env_node := WorldEnvironment.new()
	var bg_env := Environment.new()
	bg_env.background_mode = Environment.BG_COLOR
	bg_env.background_color = Color(0, 0, 0, 0)
	bg_env.glow_enabled = true
	bg_env.set_glow_level(1, 0.8)
	bg_env.set_glow_level(3, 0.5)
	bg_env.glow_intensity = 0.6
	bg_env.glow_bloom = 0.3
	bg_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	bg_env.glow_hdr_threshold = 0.5
	bg_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	bg_env_node.environment = bg_env
	_bg_3d_viewport.add_child(bg_env_node)

	# 漂浮粒子（星尘效果）
	var stardust := GPUParticles3D.new()
	stardust.name = "StardustParticles"
	stardust.amount = 64
	stardust.lifetime = 4.0
	stardust.emitting = true

	var stardust_mat := ParticleProcessMaterial.new()
	stardust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	stardust_mat.emission_box_extents = Vector3(5, 0.5, 5)
	stardust_mat.direction = Vector3(0, 1, 0)
	stardust_mat.spread = 30.0
	stardust_mat.initial_velocity_min = 0.1
	stardust_mat.initial_velocity_max = 0.3
	stardust_mat.gravity = Vector3(0, 0, 0)
	stardust_mat.damping_min = 0.5
	stardust_mat.damping_max = 1.0
	stardust_mat.scale_min = 0.02
	stardust_mat.scale_max = 0.06

	var stardust_gradient := Gradient.new()
	stardust_gradient.set_color(0, Color(0.6, 0.4, 1.0, 0.0))
	stardust_gradient.add_point(0.2, Color(0.6, 0.4, 1.0, 0.6))
	stardust_gradient.add_point(0.8, Color(1.0, 0.85, 0.0, 0.4))
	stardust_gradient.set_color(1, Color(1.0, 0.85, 0.0, 0.0))
	var stardust_ramp := GradientTexture1D.new()
	stardust_ramp.gradient = stardust_gradient
	stardust_mat.color_ramp = stardust_ramp

	stardust.process_material = stardust_mat
	_bg_3d_viewport.add_child(stardust)

	# 缓慢旋转的光源（营造氛围）
	var ambient_light := OmniLight3D.new()
	ambient_light.light_energy = 0.8
	ambient_light.light_color = Color(0.6, 0.4, 1.0)
	ambient_light.omni_range = 8.0
	ambient_light.position = Vector3(0, 2, 0)
	_bg_3d_viewport.add_child(ambient_light)

	_bg_3d_viewport_container.add_child(_bg_3d_viewport)

	# 插入到背景之后、主布局之前
	add_child(_bg_3d_viewport_container)
	move_child(_bg_3d_viewport_container, 1)  # 在 _background 之后

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

	# 清理敌人 3D 预览
	_cleanup_enemy_preview()

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

	# ---- v5.0: 敌人 3D 预览（第三卷条目） ----
	if _is_enemy_entry(entry_id, entry):
		_build_enemy_3d_preview(entry_id, entry)

	# ---- 描述 ----
	var desc_label := Label.new()
	desc_label.text = entry.get("description", "无描述")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_container.add_child(desc_label)

	# ---- 属性表格 (根据条目类型显示不同信息) ----
	_build_detail_stats(entry_id, entry)

	# ---- ★ 法术演示区域 (v5.0: 2.5D 升级) ----
	if CodexData.has_demo(entry_id):
		_build_demo_section_25d(entry_id, entry)

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
# v5.0: 敌人 3D 预览
# ============================================================

## 判断条目是否为敌人类型
func _is_enemy_entry(entry_id: String, entry: Dictionary) -> bool:
	# 第三卷的所有条目都是敌人
	var vol := VOLUME_CONFIG[_current_volume_idx] as Dictionary
	return vol.get("volume", -1) == CodexData.Volume.BESTIARY

## 构建敌人 3D 预览区域
func _build_enemy_3d_preview(entry_id: String, entry: Dictionary) -> void:
	# 预览区域标题
	var preview_title := Label.new()
	preview_title.text = "◆ 3D 预览"
	preview_title.add_theme_font_size_override("font_size", 12)
	preview_title.add_theme_color_override("font_color", ACCENT)
	_detail_container.add_child(preview_title)

	# 创建预览面板
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(0, 180)

	# SubViewportContainer
	_enemy_preview_container = SubViewportContainer.new()
	_enemy_preview_container.custom_minimum_size = Vector2(0, 160)
	_enemy_preview_container.stretch = true
	_enemy_preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# SubViewport
	_enemy_preview_viewport = SubViewport.new()
	_enemy_preview_viewport.size = Vector2i(400, 160)
	_enemy_preview_viewport.transparent_bg = true
	_enemy_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_enemy_preview_viewport.own_world_3d = true

	# 3D 摄像机（正面视角）
	_enemy_preview_camera = Camera3D.new()
	_enemy_preview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_enemy_preview_camera.size = 3.0
	_enemy_preview_camera.position = Vector3(0, 1, 3)
	_enemy_preview_camera.rotation_degrees = Vector3(-15, 0, 0)
	_enemy_preview_viewport.add_child(_enemy_preview_camera)

	# 环境（Glow/Bloom）
	var preview_env_node := WorldEnvironment.new()
	var preview_env := Environment.new()
	preview_env.background_mode = Environment.BG_COLOR
	preview_env.background_color = Color(0, 0, 0, 0)
	preview_env.glow_enabled = true
	preview_env.set_glow_level(1, 1.0)
	preview_env.set_glow_level(3, 0.6)
	preview_env.glow_intensity = 1.0
	preview_env.glow_bloom = 0.3
	preview_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	preview_env.glow_hdr_threshold = 0.6
	preview_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	preview_env_node.environment = preview_env
	_enemy_preview_viewport.add_child(preview_env_node)

	# 光源
	var preview_light := DirectionalLight3D.new()
	preview_light.light_energy = 0.5
	preview_light.light_color = Color(0.8, 0.9, 1.0)
	preview_light.rotation_degrees = Vector3(-45, 45, 0)
	_enemy_preview_viewport.add_child(preview_light)

	# 创建敌人 3D 模型
	_enemy_preview_model = _create_enemy_3d_model(entry_id, entry)
	_enemy_preview_viewport.add_child(_enemy_preview_model)

	_enemy_preview_container.add_child(_enemy_preview_viewport)
	preview_panel.add_child(_enemy_preview_container)
	_detail_container.add_child(preview_panel)

## v5.1: 根据敌人类型创建差异化 3D 模型（不同敌人类型使用不同几何形态）
func _create_enemy_3d_model(entry_id: String, entry: Dictionary) -> Node3D:
	var model := Node3D.new()
	model.name = "EnemyPreviewModel"

	# 判断敌人类别：Boss > 精英 > 章节敌人 > 基础敌人
	var is_boss: bool = entry.has("phases")
	var is_elite: bool = CodexData.VOL3_ELITES.has(entry_id)
	var is_chapter: bool = CodexData.VOL3_CHAPTER_ENEMIES.has(entry_id)

	# 获取敌人颜色：优先使用数据中的 color 字段，其次根据 entry_id 推断类型
	var enemy_color: Color = entry.get("color", Color(0.9, 0.3, 0.6))
	if not entry.has("color"):
		# 根据 entry_id 推断敌人类型颜色
		if "static" in entry_id:
			enemy_color = ENEMY_TYPE_COLORS["static"]
		elif "silence" in entry_id:
			enemy_color = ENEMY_TYPE_COLORS["silence"]
		elif "screech" in entry_id:
			enemy_color = ENEMY_TYPE_COLORS["screech"]
		elif "pulse" in entry_id or "metronome" in entry_id:
			enemy_color = ENEMY_TYPE_COLORS["pulse"]
		elif "wall" in entry_id:
			enemy_color = ENEMY_TYPE_COLORS["wall"]
		elif is_boss:
			# Boss 根据章节分配颜色
			var chapter: int = entry.get("chapter", 1)
			match chapter:
				1: enemy_color = Color(0.8, 0.7, 1.0)   # 毕达哥拉斯 - 淡紫
				2: enemy_color = Color(1.0, 0.85, 0.4)  # 圭多 - 金色
				3: enemy_color = Color(0.4, 0.6, 1.0)   # 巴赫 - 蓝色
				4: enemy_color = Color(1.0, 0.6, 0.8)   # 莫扎特 - 粉色
				5: enemy_color = Color(1.0, 0.3, 0.2)   # 贝多芬 - 红色
				_: enemy_color = Color(0.9, 0.3, 0.6)
		elif is_elite:
			var chapter: int = entry.get("chapter", 1)
			match chapter:
				1: enemy_color = Color(0.6, 0.5, 1.0)
				2: enemy_color = Color(0.9, 0.75, 0.3)
				3: enemy_color = Color(0.3, 0.5, 0.9)
				4: enemy_color = Color(0.9, 0.5, 0.7)
				5: enemy_color = Color(0.9, 0.2, 0.15)
				_: enemy_color = Color(0.7, 0.3, 0.8)
		elif is_chapter:
			var chapter: int = entry.get("chapter", 1)
			match chapter:
				1: enemy_color = Color(0.5, 0.4, 0.8)
				2: enemy_color = Color(0.8, 0.65, 0.2)
				3: enemy_color = Color(0.2, 0.4, 0.8)
				4: enemy_color = Color(0.8, 0.4, 0.6)
				5: enemy_color = Color(0.8, 0.15, 0.1)
				_: enemy_color = Color(0.6, 0.3, 0.7)

	# ---- 核心几何体：根据敌人类型创建不同形态 ----
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "EnemyCoreMesh"

	if is_boss:
		# Boss：大型多层旋转光环体
		var chapter: int = entry.get("chapter", 1)
		match chapter:
			1:  # 毕达哥拉斯：多层旋转光环（几何体）
				var sphere := SphereMesh.new()
				sphere.radius = 0.4
				sphere.height = 0.8
				sphere.radial_segments = 16
				sphere.rings = 8
				mesh_instance.mesh = sphere
			2:  # 圭多：五线谱架构师
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 0.3
				cylinder.bottom_radius = 0.5
				cylinder.height = 0.8
				cylinder.radial_segments = 8
				mesh_instance.mesh = cylinder
			3:  # 巴赫：赋格大师
				var prism := PrismMesh.new()
				prism.size = Vector3(0.8, 0.9, 0.8)
				mesh_instance.mesh = prism
			4:  # 莫扎特：古典完形
				var sphere := SphereMesh.new()
				sphere.radius = 0.35
				sphere.height = 0.7
				sphere.radial_segments = 32
				sphere.rings = 16
				mesh_instance.mesh = sphere
			5:  # 贝多芬：狂想者
				var prism := PrismMesh.new()
				prism.size = Vector3(0.9, 1.0, 0.9)
				mesh_instance.mesh = prism
			_:
				var prism := PrismMesh.new()
				prism.size = Vector3(0.8, 0.8, 0.8)
				mesh_instance.mesh = prism
	elif is_elite:
		# 精英：菱形体 + 光晕环，根据章节微调
		var prism := PrismMesh.new()
		prism.size = Vector3(0.5, 0.6, 0.5)
		mesh_instance.mesh = prism
	elif is_chapter:
		# 章节敌人：根据描述创建不同形态
		var chapter: int = entry.get("chapter", 1)
		if "grid" in entry_id or "metronome" in entry_id:
			# 网格/节拍：立方体
			var box := BoxMesh.new()
			box.size = Vector3(0.35, 0.35, 0.35)
			mesh_instance.mesh = box
		elif "scribe" in entry_id:
			# 抄谱员：细长圆柱
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.1
			cylinder.bottom_radius = 0.15
			cylinder.height = 0.5
			cylinder.radial_segments = 6
			mesh_instance.mesh = cylinder
		elif "choir" in entry_id:
			# 唱诗班：球体群
			var sphere := SphereMesh.new()
			sphere.radius = 0.15
			sphere.height = 0.3
			mesh_instance.mesh = sphere
		elif "counterpoint" in entry_id:
			# 对位爬虫：双棱柱
			var prism := PrismMesh.new()
			prism.size = Vector3(0.3, 0.4, 0.3)
			mesh_instance.mesh = prism
		elif "dancer" in entry_id or "minuet" in entry_id:
			# 小步舞者：球体
			var sphere := SphereMesh.new()
			sphere.radius = 0.2
			sphere.height = 0.4
			sphere.radial_segments = 12
			sphere.rings = 6
			mesh_instance.mesh = sphere
		elif "crescendo" in entry_id or "surge" in entry_id:
			# 渐强浪潮：大型球体
			var sphere := SphereMesh.new()
			sphere.radius = 0.3
			sphere.height = 0.6
			mesh_instance.mesh = sphere
		elif "fate" in entry_id or "knocker" in entry_id:
			# 命运叩门者：棱柱体
			var prism := PrismMesh.new()
			prism.size = Vector3(0.35, 0.5, 0.35)
			mesh_instance.mesh = prism
		else:
			var box := BoxMesh.new()
			box.size = Vector3(0.35, 0.35, 0.35)
			mesh_instance.mesh = box
	else:
		# 基础敌人：根据敌人类型创建不同几何形态
		if "static" in entry_id:
			# 底噪：小型锯齿立方体（红色）
			var box := BoxMesh.new()
			box.size = Vector3(0.25, 0.25, 0.25)
			mesh_instance.mesh = box
		elif "silence" in entry_id:
			# 寂静：深色旋涡球体（黑洞感）
			var sphere := SphereMesh.new()
			sphere.radius = 0.3
			sphere.height = 0.6
			sphere.radial_segments = 16
			sphere.rings = 8
			mesh_instance.mesh = sphere
		elif "screech" in entry_id:
			# 尖啸：尖锐三棱柱（黄白色）
			var prism := PrismMesh.new()
			prism.size = Vector3(0.2, 0.45, 0.2)
			mesh_instance.mesh = prism
		elif "pulse" in entry_id:
			# 脉冲：菱形体（电蓝色）
			var prism := PrismMesh.new()
			prism.size = Vector3(0.3, 0.35, 0.3)
			mesh_instance.mesh = prism
		elif "wall" in entry_id:
			# 音墙：巨大扁平方块（灰紫色）
			var box := BoxMesh.new()
			box.size = Vector3(0.5, 0.3, 0.5)
			mesh_instance.mesh = box
		else:
			var box := BoxMesh.new()
			box.size = Vector3(0.3, 0.3, 0.3)
			mesh_instance.mesh = box

	# 自发光材质
	var mat := StandardMaterial3D.new()
	mat.albedo_color = enemy_color
	mat.emission_enabled = true
	mat.emission = enemy_color
	mat.emission_energy_multiplier = 3.0 if is_boss else (2.5 if is_elite else 1.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.9
	mesh_instance.material_override = mat
	model.add_child(mesh_instance)

	# 核心光源
	var point_light := OmniLight3D.new()
	point_light.light_energy = 2.0 if is_boss else (1.5 if is_elite else 0.8)
	point_light.light_color = enemy_color
	point_light.omni_range = 4.0 if is_boss else (3.0 if is_elite else 2.0)
	point_light.omni_attenuation = 1.5
	model.add_child(point_light)

	# Boss 和精英：外层光晕环
	if is_elite or is_boss:
		var halo := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.4 if is_boss else 0.3
		torus.outer_radius = 0.5 if is_boss else 0.4
		torus.rings = 16
		torus.ring_segments = 12
		halo.mesh = torus
		halo.rotation_degrees = Vector3(90, 0, 0)

		var halo_mat := StandardMaterial3D.new()
		halo_mat.albedo_color = Color(enemy_color.r, enemy_color.g, enemy_color.b, 0.5)
		halo_mat.emission_enabled = true
		halo_mat.emission = enemy_color
		halo_mat.emission_energy_multiplier = 2.0
		halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		halo.material_override = halo_mat
		model.add_child(halo)

	# Boss：额外的装饰元素（旋转光环）
	if is_boss:
		var ring1 := MeshInstance3D.new()
		var torus1 := TorusMesh.new()
		torus1.inner_radius = 0.55
		torus1.outer_radius = 0.6
		torus1.rings = 24
		torus1.ring_segments = 16
		ring1.mesh = torus1
		ring1.rotation_degrees = Vector3(45, 0, 0)

		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = Color(enemy_color.r, enemy_color.g, enemy_color.b, 0.3)
		ring_mat.emission_enabled = true
		ring_mat.emission = enemy_color
		ring_mat.emission_energy_multiplier = 1.5
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring1.material_override = ring_mat
		model.add_child(ring1)

		var ring2 := MeshInstance3D.new()
		var torus2 := TorusMesh.new()
		torus2.inner_radius = 0.65
		torus2.outer_radius = 0.7
		torus2.rings = 24
		torus2.ring_segments = 16
		ring2.mesh = torus2
		ring2.rotation_degrees = Vector3(0, 0, 45)
		ring2.material_override = ring_mat
		model.add_child(ring2)

	# 寂静敌人：额外的吸收粒子（黑洞效果）
	if "silence" in entry_id and not is_boss and not is_elite:
		var absorb := GPUParticles3D.new()
		absorb.amount = 12
		absorb.lifetime = 1.5
		absorb.emitting = true

		var absorb_mat := ParticleProcessMaterial.new()
		absorb_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		absorb_mat.emission_sphere_radius = 0.5
		absorb_mat.direction = Vector3(0, 0, 0)
		absorb_mat.spread = 180.0
		absorb_mat.initial_velocity_min = -0.3
		absorb_mat.initial_velocity_max = -0.1
		absorb_mat.gravity = Vector3(0, 0, 0)
		absorb_mat.attractor_interaction_enabled = true
		absorb_mat.scale_min = 0.01
		absorb_mat.scale_max = 0.04

		var absorb_gradient := Gradient.new()
		absorb_gradient.set_color(0, Color(0.3, 0.1, 0.5, 0.6))
		absorb_gradient.set_color(1, Color(0.1, 0.05, 0.2, 0.0))
		var absorb_ramp := GradientTexture1D.new()
		absorb_ramp.gradient = absorb_gradient
		absorb_mat.color_ramp = absorb_ramp

		absorb.process_material = absorb_mat
		model.add_child(absorb)

	# 通用粒子效果
	var particles := GPUParticles3D.new()
	particles.amount = 16 if is_boss else (12 if is_elite else 8)
	particles.lifetime = 1.0
	particles.emitting = true

	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_mat.emission_sphere_radius = 0.2
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.spread = 60.0
	p_mat.initial_velocity_min = 0.2
	p_mat.initial_velocity_max = 0.5
	p_mat.gravity = Vector3(0, 0, 0)
	p_mat.damping_min = 1.0
	p_mat.damping_max = 2.0
	p_mat.scale_min = 0.02
	p_mat.scale_max = 0.06

	var p_gradient := Gradient.new()
	p_gradient.set_color(0, Color(enemy_color.r, enemy_color.g, enemy_color.b, 0.8))
	p_gradient.set_color(1, Color(enemy_color.r, enemy_color.g, enemy_color.b, 0.0))
	var p_ramp := GradientTexture1D.new()
	p_ramp.gradient = p_gradient
	p_mat.color_ramp = p_ramp

	particles.process_material = p_mat
	model.add_child(particles)

	return model

## 清理敌人 3D 预览
func _cleanup_enemy_preview() -> void:
	_enemy_preview_model = null
	# SubViewport 会随 _detail_container 的子节点一起被 queue_free

# ============================================================
# ★ v5.0: 法术演示区域 (2.5D 升级版)
# ============================================================

## 构建纯 3D 法术演示区域（v5.1: 移除旧 2D 层，统一为 3D 渲染）
func _build_demo_section_25d(entry_id: String, entry: Dictionary) -> void:
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
	_demo_info_label.text = demo_config.get("demo_desc", "点击下方按钮查看法术效果。弹体使用 3D 渲染管线呈现。")
	_demo_info_label.add_theme_font_size_override("font_size", 11)
	_demo_info_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	_demo_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_container.add_child(_demo_info_label)

	# 演示视口容器（带边框背景）
	var demo_panel := PanelContainer.new()
	demo_panel.custom_minimum_size = Vector2(0, 240)

	# ---- v5.1: 纯 3D 渲染层（移除旧 2D 弹体层，避免 2D/3D 重叠） ----
	_demo_3d_viewport_container = SubViewportContainer.new()
	_demo_3d_viewport_container.custom_minimum_size = Vector2(0, 220)
	_demo_3d_viewport_container.stretch = true
	_demo_3d_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_demo_3d_viewport = SubViewport.new()
	_demo_3d_viewport.size = Vector2i(600, 220)
	_demo_3d_viewport.transparent_bg = false
	_demo_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_demo_3d_viewport.own_world_3d = true

	# 3D 正交摄像机（俯视，居中对准演示区域）
	_demo_3d_camera = Camera3D.new()
	_demo_3d_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_demo_3d_camera.size = 5.0
	_demo_3d_camera.position = Vector3(2.5, 10, 1.1)
	_demo_3d_camera.rotation_degrees = Vector3(-90, 0, 0)
	_demo_3d_viewport.add_child(_demo_3d_camera)

	# WorldEnvironment（Glow/Bloom — 与 main_game 一致）
	_demo_3d_env = WorldEnvironment.new()
	var demo_env := Environment.new()
	demo_env.background_mode = Environment.BG_COLOR
	demo_env.background_color = DEMO_BG
	demo_env.glow_enabled = true
	demo_env.set_glow_level(1, 1.0)
	demo_env.set_glow_level(3, 0.8)
	demo_env.set_glow_level(5, 0.5)
	demo_env.glow_intensity = 0.8
	demo_env.glow_strength = 1.0
	demo_env.glow_bloom = 0.2
	demo_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	demo_env.glow_hdr_threshold = 0.8
	demo_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	demo_env.adjustment_enabled = true
	demo_env.adjustment_contrast = 1.1
	demo_env.adjustment_saturation = 1.2
	_demo_3d_env.environment = demo_env
	_demo_3d_viewport.add_child(_demo_3d_env)

	# 方向光
	_demo_3d_light = DirectionalLight3D.new()
	_demo_3d_light.light_energy = 0.3
	_demo_3d_light.light_color = Color(0.8, 0.9, 1.0)
	_demo_3d_light.rotation_degrees = Vector3(-45, 45, 0)
	_demo_3d_viewport.add_child(_demo_3d_light)

	# 3D 实体层（用于放置弹体和敌人的 3D 代理）
	_demo_3d_entity_layer = Node3D.new()
	_demo_3d_entity_layer.name = "DemoEntityLayer3D"
	_demo_3d_viewport.add_child(_demo_3d_entity_layer)

	# ★ v5.1: 在演示区域添加敌人目标
	_spawn_demo_enemies()

	# 3D 地面网格（替代旧 2D 网格）
	_create_demo_3d_ground()

	_demo_3d_viewport_container.add_child(_demo_3d_viewport)
	demo_panel.add_child(_demo_3d_viewport_container)
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

	# v5.1: 清除 3D 层的旧弹体代理（保留敌人和地面）
	_clear_demo_3d_projectiles()

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

## ★ 演示施放音符（v5.1: 统一使用 3D 渲染）
func _demo_cast_note(config: Dictionary) -> void:
	var white_key: int = config.get("demo_note", 0)
	var spell_data := _build_demo_spell_data(white_key, -1)

	# 调整弹体位置和方向以适应演示视口
	spell_data["_demo_origin"] = Vector2(50, 110)  # 从左侧发射
	spell_data["_demo_direction"] = Vector2.RIGHT

	# v5.1: 仅在 3D 层生成发光弹体
	_spawn_demo_3d_projectile(spell_data)

	var note_name: String = MusicData.WHITE_KEY_STATS.get(white_key, {}).get("name", "?")
	_update_demo_status("施放: %s | DMG=%.0f SPD=%.0f DUR=%.1fs SIZE=%.0fpx" % [
		note_name, spell_data["damage"], spell_data["speed"],
		spell_data["duration"], spell_data["size"]
	])

## ★ 演示施放带修饰符的音符（v5.1: 统一 3D）
func _demo_cast_note_modifier(config: Dictionary) -> void:
	var white_key: int = config.get("demo_note", 0)
	var modifier: int = config.get("demo_modifier", -1)
	var spell_data := _build_demo_spell_data(white_key, modifier)

	spell_data["_demo_origin"] = Vector2(50, 110)
	spell_data["_demo_direction"] = Vector2.RIGHT

	# v5.1: 仅在 3D 层生成发光弹体
	_spawn_demo_3d_projectile(spell_data)

	var note_name: String = MusicData.WHITE_KEY_STATS.get(white_key, {}).get("name", "?")
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
	var root_stats: Dictionary = MusicData.WHITE_KEY_STATS.get(MusicData.WhiteKey.C, {})
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
		"timbre": MusicData.TimbreType.NONE,
		"accuracy_offset": 0.0,
	}

	# v5.1: 仅在 3D 层生成和弦爆发粒子
	_spawn_demo_3d_chord_burst(chord_data)

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
		spell_data["_demo_origin"] = Vector2(50, 40 + i * 45)
		spell_data["_demo_direction"] = Vector2.RIGHT

		# 应用节奏型效果到弹体（与 ProjectileManager._apply_rhythm_to_projectile 一致）
		_apply_demo_rhythm_effect(spell_data, pattern_type)
		# v5.1: 仅在 3D 层生成弹体
		_spawn_demo_3d_projectile(spell_data)

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
		"timbre": MusicData.TimbreType.NONE,
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

	var origin: Vector2 = spell_data.get("_demo_origin", Vector2(50, 110))
	var direction: Vector2 = spell_data.get("_demo_direction", Vector2.RIGHT)

	# 通过 ProjectileManager 的实际接口生成弹体
	if _demo_projectile_manager.has_method("spawn_from_spell"):
		_demo_projectile_manager.spawn_from_spell(spell_data, origin, direction)
	elif _demo_projectile_manager.has_method("spawn_projectile"):
		_demo_projectile_manager.spawn_projectile({
			"position": origin,
			"velocity": direction * spell_data["speed"],
			"damage": spell_data["damage"],
			"size": spell_data["size"],
			"duration": spell_data["duration"],
			"color": spell_data["color"],
			"modifier": spell_data.get("modifier", -1),
		})

# ============================================================
# v5.0: 3D 演示弹体代理
# ============================================================

## 在 3D 层生成弹体的发光代理
func _spawn_demo_3d_projectile(spell_data: Dictionary) -> void:
	if not _demo_3d_entity_layer:
		return

	var origin_2d: Vector2 = spell_data.get("_demo_origin", Vector2(50, 110))
	var direction_2d: Vector2 = spell_data.get("_demo_direction", Vector2.RIGHT)
	var color: Color = spell_data.get("color", Color.WHITE)
	var speed: float = spell_data.get("speed", 200.0)
	var size: float = spell_data.get("size", 16.0)
	var duration: float = spell_data.get("duration", 1.0)

	# 将 2D 演示坐标转换为 3D 空间（简化映射：100px = 1 unit）
	var pos_3d := Vector3(origin_2d.x / 100.0, 0.0, origin_2d.y / 100.0)
	var vel_3d := Vector3(direction_2d.x * speed / 100.0, 0.0, direction_2d.y * speed / 100.0)

	# 创建 3D 弹体代理
	var projectile_3d := Node3D.new()
	projectile_3d.name = "DemoProjectile3D"
	projectile_3d.position = pos_3d

	# 发光球体
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size / 200.0  # 缩放到 3D 空间
	sphere.height = size / 100.0
	sphere.radial_segments = 8
	sphere.rings = 4
	mesh_inst.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.9
	mesh_inst.material_override = mat
	projectile_3d.add_child(mesh_inst)

	# 点光源
	var light := OmniLight3D.new()
	light.light_energy = 1.5
	light.light_color = color
	light.omni_range = 1.5
	light.omni_attenuation = 2.0
	projectile_3d.add_child(light)

	# 拖尾粒子
	var trail := GPUParticles3D.new()
	trail.amount = 8
	trail.lifetime = 0.4
	trail.emitting = true

	var trail_mat := ParticleProcessMaterial.new()
	trail_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	trail_mat.emission_sphere_radius = 0.02
	trail_mat.direction = Vector3(-direction_2d.x, 0, -direction_2d.y)
	trail_mat.spread = 15.0
	trail_mat.initial_velocity_min = 0.2
	trail_mat.initial_velocity_max = 0.5
	trail_mat.gravity = Vector3(0, 0, 0)
	trail_mat.damping_min = 2.0
	trail_mat.damping_max = 4.0
	trail_mat.scale_min = 0.01
	trail_mat.scale_max = 0.04

	var trail_gradient := Gradient.new()
	trail_gradient.set_color(0, Color(color.r, color.g, color.b, 0.8))
	trail_gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var trail_ramp := GradientTexture1D.new()
	trail_ramp.gradient = trail_gradient
	trail_mat.color_ramp = trail_ramp
	trail.process_material = trail_mat
	projectile_3d.add_child(trail)

	_demo_3d_entity_layer.add_child(projectile_3d)

	# 使用 Tween 驱动 3D 弹体移动
	var target_pos := pos_3d + vel_3d * duration
	var tween := create_tween()
	tween.tween_property(projectile_3d, "position", target_pos, duration)
	tween.tween_callback(projectile_3d.queue_free)

## 在 3D 层生成和弦爆发粒子
func _spawn_demo_3d_chord_burst(chord_data: Dictionary) -> void:
	if not _demo_3d_entity_layer:
		return

	# 在视口中心生成爆发粒子
	var burst := GPUParticles3D.new()
	burst.name = "ChordBurst3D"
	burst.one_shot = true
	burst.amount = 32
	burst.lifetime = 0.8
	burst.explosiveness = 1.0
	burst.position = Vector3(3, 0, 1.1)  # 视口中心

	var burst_mat := ParticleProcessMaterial.new()
	burst_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	burst_mat.emission_sphere_radius = 0.1
	burst_mat.direction = Vector3(0, 0, 0)
	burst_mat.spread = 180.0
	burst_mat.initial_velocity_min = 1.0
	burst_mat.initial_velocity_max = 3.0
	burst_mat.damping_min = 2.0
	burst_mat.damping_max = 4.0
	burst_mat.gravity = Vector3(0, 0, 0)
	burst_mat.scale_min = 0.02
	burst_mat.scale_max = 0.08

	var chord_color := Color(0.6, 0.4, 1.0)  # 默认紫色
	var burst_gradient := Gradient.new()
	burst_gradient.set_color(0, Color(chord_color.r, chord_color.g, chord_color.b, 1.0))
	burst_gradient.set_color(1, Color(chord_color.r, chord_color.g, chord_color.b, 0.0))
	var burst_ramp := GradientTexture1D.new()
	burst_ramp.gradient = burst_gradient
	burst_mat.color_ramp = burst_ramp
	burst.process_material = burst_mat

	_demo_3d_entity_layer.add_child(burst)
	burst.emitting = true

	# 同时闪烁 Glow
	if _demo_3d_env and _demo_3d_env.environment:
		_demo_3d_env.environment.glow_intensity = 1.5
		var tween := create_tween()
		tween.tween_property(_demo_3d_env.environment, "glow_intensity", 0.8, 0.5)

	# 自动清理
	get_tree().create_timer(2.0).timeout.connect(burst.queue_free)

## v5.1: 清除 3D 演示层的弹体（保留敌人和地面）
func _clear_demo_3d_projectiles() -> void:
	if _demo_3d_entity_layer:
		for child in _demo_3d_entity_layer.get_children():
			# 保留敌人目标和地面网格
			if child.name.begins_with("DemoEnemy") or child.name == "DemoGround3D":
				continue
			child.queue_free()

## v5.1: 在演示区域生成敌人目标（供弹体打击）
func _spawn_demo_enemies() -> void:
	if not _demo_3d_entity_layer:
		return

	# 在演示区域右侧放置 3 个敌人目标
	var enemy_configs := [
		{"pos": Vector3(3.5, 0, 0.6), "color": Color(0.7, 0.3, 0.3), "type": "static"},
		{"pos": Vector3(3.5, 0, 1.1), "color": Color(0.2, 0.5, 1.0), "type": "pulse"},
		{"pos": Vector3(3.5, 0, 1.6), "color": Color(1.0, 0.95, 0.5), "type": "screech"},
	]

	for i in range(enemy_configs.size()):
		var cfg: Dictionary = enemy_configs[i]
		var enemy := Node3D.new()
		enemy.name = "DemoEnemy_%d" % i
		enemy.position = cfg["pos"]

		# 根据敌人类型创建不同几何体
		var mesh_inst := MeshInstance3D.new()
		var enemy_mesh: Mesh
		match cfg["type"]:
			"static":
				var box := BoxMesh.new()
				box.size = Vector3(0.2, 0.2, 0.2)
				enemy_mesh = box
			"pulse":
				var prism := PrismMesh.new()
				prism.size = Vector3(0.25, 0.25, 0.25)
				enemy_mesh = prism
			"screech":
				var prism := PrismMesh.new()
				prism.size = Vector3(0.2, 0.3, 0.2)
				enemy_mesh = prism
			_:
				var box := BoxMesh.new()
				box.size = Vector3(0.2, 0.2, 0.2)
				enemy_mesh = box
		mesh_inst.mesh = enemy_mesh

		var mat := StandardMaterial3D.new()
		mat.albedo_color = cfg["color"]
		mat.emission_enabled = true
		mat.emission = cfg["color"]
		mat.emission_energy_multiplier = 1.5
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.85
		mesh_inst.material_override = mat
		enemy.add_child(mesh_inst)

		# 敌人发光
		var light := OmniLight3D.new()
		light.light_energy = 0.5
		light.light_color = cfg["color"]
		light.omni_range = 1.5
		light.omni_attenuation = 2.0
		enemy.add_child(light)

		_demo_3d_entity_layer.add_child(enemy)

## v5.1: 创建 3D 地面网格（替代旧 2D 网格）
func _create_demo_3d_ground() -> void:
	if not _demo_3d_entity_layer:
		return

	var ground := Node3D.new()
	ground.name = "DemoGround3D"

	# 半透明地面平面
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(6, 3)
	var plane_inst := MeshInstance3D.new()
	plane_inst.mesh = plane_mesh
	plane_inst.position = Vector3(2.5, -0.01, 1.1)

	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.1, 0.08, 0.15, 0.3)
	ground_mat.emission_enabled = true
	ground_mat.emission = Color(0.15, 0.1, 0.25)
	ground_mat.emission_energy_multiplier = 0.3
	ground_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plane_inst.material_override = ground_mat
	ground.add_child(plane_inst)

	_demo_3d_entity_layer.add_child(ground)

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
	if _demo_status_label:
		_demo_status_label.text = ""
	# v5.1: 清除 3D 层弹体（保留敌人和地面）
	_clear_demo_3d_projectiles()

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
