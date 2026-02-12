## upgrade_card.gd
## 升级卡片 UI 组件 — v6.0
##
## 根据 UI_Design_Module4_CircleOfFifths.md §5 设计文档实现：
##   - 卡片尺寸：240×320px，圆角 12px
##   - 方向色边框 + 辉光效果
##   - 金色高亮标识（局外解锁）
##   - 悬停放大效果 + 选中闪白动画
##   - 稀有度视觉区分
##
## 卡片布局 (§5.1)：
##   ┌──────────────────────┐
##   │   [方向色顶部条]      │
##   │   ┌────────────┐     │
##   │   │  升级图标   │     │
##   │   └────────────┘     │
##   │   升级名称            │
##   │   ─────────────      │
##   │   效果描述            │
##   │   (数值高亮)          │
##   │                      │
##   │   [标签] [标签]       │
##   │   [★ 局外解锁]       │
##   └──────────────────────┘
extends PanelContainer

# ============================================================
# 信号
# ============================================================
signal card_selected(card_index: int)
signal card_hovered(card_index: int)
signal card_unhovered(card_index: int)

# ============================================================
# 常量 — 颜色 (§1.2)
# ============================================================
const COL_BG := Color("#141026")
const COL_ACCENT := Color("#9D6FFF")
const COL_GOLD := Color("#FFD700")
const COL_TEXT_PRIMARY := Color("#EAE6FF")
const COL_TEXT_SECONDARY := Color("#A098C8")
const COL_TEXT_DIM := Color("#6B668A")

## 方向色
const DIRECTION_COLORS := {
	"offense": Color("#FF4444"),
	"defense": Color("#4488FF"),
	"core": Color("#9D6FFF"),
}

## 稀有度颜色
const RARITY_COLORS := {
	0: Color("#A098C8"),  ## 普通
	1: Color("#4488FF"),  ## 稀有
	2: Color("#9D6FFF"),  ## 史诗
	3: Color("#FFD700"),  ## 传说
}

const RARITY_NAMES := {
	0: "普通",
	1: "稀有",
	2: "史诗",
	3: "传说",
}

## 方向符号
const DIRECTION_SYMBOLS := {
	"offense": "♯",
	"defense": "♭",
	"core": "♮",
}

# ============================================================
# 常量 — 布局 (§5.1)
# ============================================================
const CARD_WIDTH: float = 240.0
const CARD_HEIGHT: float = 320.0
const CARD_CORNER_RADIUS: int = 12
const ICON_SIZE: float = 64.0
const TOP_BAR_HEIGHT: float = 4.0

# ============================================================
# 状态
# ============================================================
var card_index: int = 0
var card_data: Dictionary = {}
var is_meta_unlocked: bool = false
var _is_hovered: bool = false
var _original_scale: Vector2 = Vector2.ONE

# ============================================================
# 节点引用
# ============================================================
var _top_bar: ColorRect = null
var _icon_label: Label = null
var _title_label: Label = null
var _description: RichTextLabel = null
var _tags_container: HFlowContainer = null
var _gold_badge: Label = null
var _rarity_label: Label = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_card_ui()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

# ============================================================
# 公共接口
# ============================================================

## 配置卡片数据
func setup(data: Dictionary, index: int = 0) -> void:
	card_data = data
	card_index = index

	var direction: String = data.get("direction", "core")
	var rarity: int = data.get("rarity", 0)
	var direction_color: Color = DIRECTION_COLORS.get(direction, COL_ACCENT)
	var rarity_color: Color = RARITY_COLORS.get(rarity, COL_TEXT_SECONDARY)

	# 更新顶部方向色条
	if _top_bar:
		_top_bar.color = direction_color

	# 更新图标
	if _icon_label:
		_icon_label.text = DIRECTION_SYMBOLS.get(direction, "♮")
		_icon_label.add_theme_color_override("font_color", direction_color)

	# 更新标题
	if _title_label:
		_title_label.text = data.get("title", "未知升级")
		_title_label.add_theme_color_override("font_color", rarity_color)

	# 更新描述 — 使用 BBCode 高亮数值
	if _description:
		var desc_text: String = data.get("description", "无描述")
		var value_text: String = data.get("value_text", "")
		if not value_text.is_empty():
			desc_text = desc_text.replace(value_text,
				"[color=#9D6FFF]%s[/color]" % value_text)
		_description.text = desc_text

	# 更新标签
	_update_tags(data)

	# 更新稀有度
	if _rarity_label:
		_rarity_label.text = RARITY_NAMES.get(rarity, "普通")
		_rarity_label.add_theme_color_override("font_color", rarity_color)

	# 检查局外解锁
	is_meta_unlocked = data.get("is_meta_unlocked", false)
	if is_meta_unlocked:
		_apply_gold_highlight(direction_color)

	# 更新面板边框
	_update_border(direction_color, rarity)

## 播放入场动画 (§11.2)
func play_entrance_animation(delay: float = 0.0) -> void:
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	pivot_offset = size / 2.0

	var tween := create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.4)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## 播放选中确认动画 (§11.2)
func play_select_animation() -> void:
	var tween := create_tween()
	# 闪白
	tween.tween_property(self, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
	# 缩小飞走
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.3)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)

## 播放未选中消散动画 (§11.2)
func play_dismiss_animation() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(self, "scale", Vector2(0.9, 0.9), 0.2)

# ============================================================
# 内部 — UI 构建
# ============================================================

func _build_card_ui() -> void:
	# 面板样式
	var style := StyleBoxFlat.new()
	style.bg_color = COL_BG
	style.corner_radius_top_left = CARD_CORNER_RADIUS
	style.corner_radius_top_right = CARD_CORNER_RADIUS
	style.corner_radius_bottom_left = CARD_CORNER_RADIUS
	style.corner_radius_bottom_right = CARD_CORNER_RADIUS
	style.border_color = COL_ACCENT
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# 顶部方向色条
	_top_bar = ColorRect.new()
	_top_bar.custom_minimum_size = Vector2(0, TOP_BAR_HEIGHT)
	_top_bar.color = COL_ACCENT
	vbox.add_child(_top_bar)

	# 图标区域
	var icon_center := CenterContainer.new()
	icon_center.custom_minimum_size.y = ICON_SIZE + 16

	_icon_label = Label.new()
	_icon_label.text = "♮"
	_icon_label.add_theme_font_size_override("font_size", 40)
	_icon_label.add_theme_color_override("font_color", COL_ACCENT)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_center.add_child(_icon_label)

	vbox.add_child(icon_center)

	# 标题
	_title_label = Label.new()
	_title_label.text = "升级名称"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", COL_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title_label)

	# 稀有度
	_rarity_label = Label.new()
	_rarity_label.text = "普通"
	_rarity_label.add_theme_font_size_override("font_size", 10)
	_rarity_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_rarity_label)

	# 分割线
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.3)
	vbox.add_child(sep)

	# 描述
	_description = RichTextLabel.new()
	_description.bbcode_enabled = true
	_description.fit_content = true
	_description.scroll_active = false
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_description.add_theme_font_size_override("normal_font_size", 12)
	_description.add_theme_color_override("default_color", COL_TEXT_PRIMARY)
	vbox.add_child(_description)

	# 标签容器
	_tags_container = HFlowContainer.new()
	_tags_container.add_theme_constant_override("h_separation", 4)
	_tags_container.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_tags_container)

	# 金色徽章（默认隐藏）
	_gold_badge = Label.new()
	_gold_badge.text = "★ 局外解锁"
	_gold_badge.add_theme_font_size_override("font_size", 10)
	_gold_badge.add_theme_color_override("font_color", COL_GOLD)
	_gold_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_badge.visible = false
	vbox.add_child(_gold_badge)

	add_child(vbox)

func _update_tags(data: Dictionary) -> void:
	for child in _tags_container.get_children():
		child.queue_free()

	var tags: Array = data.get("tags", [])
	var direction: String = data.get("direction", "core")
	var direction_color: Color = DIRECTION_COLORS.get(direction, COL_ACCENT)

	for tag_text in tags:
		var tag := Label.new()
		tag.text = " %s " % tag_text
		tag.add_theme_font_size_override("font_size", 9)
		tag.add_theme_color_override("font_color", direction_color)

		var tag_panel := PanelContainer.new()
		var tag_style := StyleBoxFlat.new()
		tag_style.bg_color = Color(direction_color.r, direction_color.g, direction_color.b, 0.1)
		tag_style.border_color = Color(direction_color.r, direction_color.g, direction_color.b, 0.3)
		tag_style.border_width_left = 1
		tag_style.border_width_right = 1
		tag_style.border_width_top = 1
		tag_style.border_width_bottom = 1
		tag_style.corner_radius_top_left = 3
		tag_style.corner_radius_top_right = 3
		tag_style.corner_radius_bottom_left = 3
		tag_style.corner_radius_bottom_right = 3
		tag_style.content_margin_left = 4
		tag_style.content_margin_right = 4
		tag_style.content_margin_top = 1
		tag_style.content_margin_bottom = 1
		tag_panel.add_theme_stylebox_override("panel", tag_style)
		tag_panel.add_child(tag)
		_tags_container.add_child(tag_panel)

func _update_border(direction_color: Color, rarity: int) -> void:
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style:
		style.border_color = direction_color
		var border_w := 1
		if rarity >= 2:
			border_w = 2
		if rarity >= 3:
			border_w = 3
		style.border_width_left = border_w
		style.border_width_right = border_w
		style.border_width_top = border_w
		style.border_width_bottom = border_w
		style.shadow_color = Color(direction_color.r, direction_color.g, direction_color.b, 0.2)
		style.shadow_size = 3 if rarity >= 1 else 0
		add_theme_stylebox_override("panel", style)

func _apply_gold_highlight(_original_color: Color) -> void:
	# 金色边框 (§6)
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style:
		style.border_color = COL_GOLD
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.shadow_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.3)
		style.shadow_size = 5
		add_theme_stylebox_override("panel", style)

	# 显示金色徽章
	if _gold_badge:
		_gold_badge.visible = true

# ============================================================
# 交互 — 悬停效果 (§5.2)
# ============================================================

func _on_mouse_entered() -> void:
	_is_hovered = true
	_original_scale = scale
	pivot_offset = size / 2.0

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.15)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	card_hovered.emit(card_index)

func _on_mouse_exited() -> void:
	_is_hovered = false
	pivot_offset = size / 2.0

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	card_unhovered.emit(card_index)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_selected.emit(card_index)
