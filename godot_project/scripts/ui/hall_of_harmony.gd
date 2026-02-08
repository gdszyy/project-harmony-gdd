## "和谐殿堂" UI (Issue #31) - v2.0 Themed
## 局外成长系统的主界面，视觉风格为“神圣的音乐工作站”。
##
## 包含四个可交互的“机架模块”：
## A. 乐器调优 (推杆/旋钮风格)
## B. 乐理研习 (技能树/五线谱风格)
## C. 调式风格 (职业选择卡片)
## D. 声学降噪 (调音台推杆)
##
## 背景为星空与巨大发光五线谱的插画。
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
# Icons can be replaced with custom texture paths
const TAB_ICONS: Array = ["res://assets/ui/icons/icon_tuning.png", "res://assets/ui/icons/icon_theory.png", "res://assets/ui/icons/icon_modes.png", "res://assets/ui/icons/icon_denoise.png"]

# ============================================================
# 颜色方案 (from UI_Art_Style_Enhancement_Proposal.md)
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

# ============================================================
# 节点引用
# ============================================================
var _background_texture: TextureRect = null
var _header: Control = null
var _fragments_label: Label = null
var _tab_bar: HBoxContainer = null
var _content_container: Control = null
var _tab_panels: Array[Control] = [] # These will be the "rack module" containers
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
	# 全屏背景 (现在是 TextureRect)
	_background_texture = TextureRect.new()
	_background_texture.name = "ThemedBackground"
	# The actual texture will be loaded from a path, e.g., load("res://assets/ui/hall_of_harmony_bg.png")
	_background_texture.texture = null # Placeholder
	_background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background_texture)

	# 主容器
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)

	# 顶部 Header (货币)
	_header = HBoxContainer.new()
	_header.custom_minimum_size.y = 60
	_fragments_label = Label.new()
	_fragments_label.text = "共鸣碎片: 0"
	_fragments_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fragments_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fragments_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_fragments_label)
	main_container.add_child(_header)

	# 标签页栏
	_tab_bar = HBoxContainer.new()
	_tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_bar.custom_minimum_size.y = 50
	main_container.add_child(_tab_bar)

	# 内容容器 (用于放置机架模块)
	_content_container = Control.new()
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(_content_container)

	# 创建标签页和面板
	for i in range(TAB_NAMES.size()):
		# 创建标签按钮
		var tab_button = Button.new()
		tab_button.text = TAB_NAMES[i]
		# tab_button.icon = load(TAB_ICONS[i]) # Load icon texture
		tab_button.pressed.connect(_on_tab_selected.bind(i))
		_tab_bar.add_child(tab_button)

		# 创建“机架模块”面板
		# In a real implementation, this would be instancing a scene, e.g., load("res://scenes/ui/rack_module_tuning.tscn").instance()
		var panel = PanelContainer.new()
		panel.name = TAB_NAMES[i]
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.visible = false
		# Add placeholder content
		var label = Label.new()
		label.text = "内容模块: %s" % TAB_NAMES[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(label)

		_content_container.add_child(panel)
		_tab_panels.append(panel)

	# 底部操作栏
	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.custom_minimum_size.y = 80
	_start_button = Button.new()
	_start_button.text = "开始远征"
	_start_button.pressed.connect(start_game_pressed.emit)
	footer.add_child(_start_button)
	main_container.add_child(footer)

	# 初始选择第一个标签页
	_select_tab(0)

func _select_tab(index: int) -> void:
	if index < 0 or index >= _tab_panels.size():
		return

	_current_tab = index
	for i in range(_tab_panels.size()):
		_tab_panels[i].visible = (i == index)
		var tab_button = _tab_bar.get_child(i) as Button
		if i == index:
			tab_button.disabled = true # Visually mark as active
		else:
			tab_button.disabled = false

# ============================================================
# 回调与刷新
# ============================================================

func _on_tab_selected(index: int) -> void:
	_select_tab(index)

func _refresh_all() -> void:
	if not _meta:
		return
	_on_fragments_changed(_meta.get_resonance_fragments())
	# Refresh content of the current tab
	_refresh_tab_content(_current_tab)

func _refresh_tab_content(index: int) -> void:
	# This is where the logic to update each specific "rack module" would go
	# For example, updating the skill tree in the "乐理研习" tab
	pass

func _on_fragments_changed(new_total: int) -> void:
	if _fragments_label:
		_fragments_label.text = "共鸣碎片: %d" % new_total

func _on_upgrade_purchased(upgrade_id: String, cost: int) -> void:
	# Refresh the UI to reflect the new purchase
	_refresh_tab_content(_current_tab)
