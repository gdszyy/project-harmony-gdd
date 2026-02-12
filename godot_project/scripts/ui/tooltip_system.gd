## tooltip_system.gd
## 工具提示系统 (CanvasLayer)
## 模块7：教学引导与辅助 UI
##
## 功能：
##   - 鼠标悬停 0.5 秒后显示详细信息
##   - 紧凑、信息密度高的面板
##   - 使用次要背景色，避免干扰主 UI
##   - 支持富文本（BBCode）
##   - 支持自定义 Tooltip 内容（标题+描述+属性列表）
##   - 自动跟随鼠标位置
##   - 自动避免超出屏幕边界
##
## 设计原则：
##   - 覆盖 Control._make_custom_tooltip 方法
##   - 全局脚本设置，为所有控件启用自定义 Tooltip
##   - 延迟显示避免闪烁
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal tooltip_shown(tooltip_id: String)
signal tooltip_hidden()

# ============================================================
# 主题颜色
# ============================================================
const TEXT_SECONDARY := UIColors.TEXT_SECONDARY

# ============================================================
# 配置
# ============================================================
@export var show_delay: float = 0.5
@export var fade_in_duration: float = 0.15
@export var max_width: float = 350.0
@export var mouse_offset: Vector2 = Vector2(16, 16)
@export var edge_padding: float = 12.0

# ============================================================
# 内部节点
# ============================================================
var _tooltip_panel: PanelContainer = null
var _title_label: Label = null
var _separator: ColorRect = null
var _description_label: RichTextLabel = null
var _stats_container: VBoxContainer = null
var _rarity_label: Label = null

# ============================================================
# 内部状态
# ============================================================
var _is_showing: bool = false
var _current_tooltip_id: String = ""
var _hover_timer: float = 0.0
var _is_hovering: bool = false
var _pending_data: Dictionary = {}
var _show_tween: Tween = null

# ============================================================
# 注册的 Tooltip 数据
# ============================================================
## tooltip_id → { title, description, stats, rarity }
var _registered_tooltips: Dictionary = {}

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 108
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_tooltip_panel.visible = false

func _process(delta: float) -> void:
	if _is_hovering and not _is_showing:
		_hover_timer += delta
		if _hover_timer >= show_delay:
			_display_tooltip()

	if _is_showing:
		_update_position()

func _input(event: InputEvent) -> void:
	# 鼠标移动时更新位置
	if event is InputEventMouseMotion and _is_showing:
		_update_position()

# ============================================================
# 公共接口
# ============================================================

## 注册 Tooltip 数据
func register_tooltip(tooltip_id: String, data: Dictionary) -> void:
	## data: {
	##   "title": String,           # 标题
	##   "description": String,     # 描述（支持 BBCode）
	##   "stats": Array,            # 属性列表 [{"label": "伤害", "value": "120", "color": Color}]
	##   "rarity": String,          # 稀有度 "common"/"rare"/"epic"/"legendary"
	## }
	_registered_tooltips[tooltip_id] = data

## 注销 Tooltip
func unregister_tooltip(tooltip_id: String) -> void:
	_registered_tooltips.erase(tooltip_id)

## 请求显示 Tooltip（通常由 UI 元素的 mouse_entered 调用）
func request_show(tooltip_id: String) -> void:
	if not _registered_tooltips.has(tooltip_id):
		return

	_pending_data = _registered_tooltips[tooltip_id]
	_current_tooltip_id = tooltip_id
	_is_hovering = true
	_hover_timer = 0.0

## 请求显示自定义内容的 Tooltip
func request_show_custom(data: Dictionary) -> void:
	_pending_data = data
	_current_tooltip_id = "custom_%d" % Time.get_ticks_msec()
	_is_hovering = true
	_hover_timer = 0.0

## 请求显示简单文字 Tooltip
func request_show_text(text: String) -> void:
	request_show_custom({"title": "", "description": text})

## 请求隐藏 Tooltip（通常由 UI 元素的 mouse_exited 调用）
func request_hide() -> void:
	_is_hovering = false
	_hover_timer = 0.0
	_pending_data = {}

	if _is_showing:
		_hide_tooltip()

## 立即显示（跳过延迟）
func show_immediate(tooltip_id: String) -> void:
	if not _registered_tooltips.has(tooltip_id):
		return
	_pending_data = _registered_tooltips[tooltip_id]
	_current_tooltip_id = tooltip_id
	_display_tooltip()

## 立即显示自定义内容
func show_immediate_custom(data: Dictionary) -> void:
	_pending_data = data
	_current_tooltip_id = "custom_%d" % Time.get_ticks_msec()
	_display_tooltip()

## 强制隐藏
func hide() -> void:
	_is_hovering = false
	_hover_timer = 0.0
	_hide_tooltip()

## 为 Control 节点绑定 Tooltip
func bind_tooltip(control: Control, tooltip_id: String) -> void:
	if not control.mouse_entered.is_connected(request_show.bind(tooltip_id)):
		control.mouse_entered.connect(request_show.bind(tooltip_id))
	if not control.mouse_exited.is_connected(request_hide):
		control.mouse_exited.connect(request_hide)

## 为 Control 节点绑定简单文字 Tooltip
func bind_text_tooltip(control: Control, text: String) -> void:
	if not control.mouse_entered.is_connected(request_show_text.bind(text)):
		control.mouse_entered.connect(request_show_text.bind(text))
	if not control.mouse_exited.is_connected(request_hide):
		control.mouse_exited.connect(request_hide)

## 清除所有注册
func clear_all() -> void:
	_registered_tooltips.clear()
	hide()

# ============================================================
# 内部方法 — 显示/隐藏
# ============================================================

func _display_tooltip() -> void:
	if _pending_data.is_empty():
		return

	_update_content(_pending_data)
	_update_position()

	_tooltip_panel.visible = true
	_tooltip_panel.modulate.a = 0.0

	if _show_tween and _show_tween.is_valid():
		_show_tween.kill()
	_show_tween = create_tween()
	_show_tween.tween_property(_tooltip_panel, "modulate:a", 1.0, fade_in_duration)

	_is_showing = true
	tooltip_shown.emit(_current_tooltip_id)

func _hide_tooltip() -> void:
	if not _is_showing:
		return

	if _show_tween and _show_tween.is_valid():
		_show_tween.kill()

	_show_tween = create_tween()
	_show_tween.tween_property(_tooltip_panel, "modulate:a", 0.0, 0.1)
	_show_tween.tween_callback(func():
		_tooltip_panel.visible = false
		_is_showing = false
		tooltip_hidden.emit()
	)

# ============================================================
# 内部方法 — 内容更新
# ============================================================

func _update_content(data: Dictionary) -> void:
	var title: String = data.get("title", "")
	var description: String = data.get("description", "")
	var stats: Array = data.get("stats", [])
	var rarity: String = data.get("rarity", "")

	# 标题
	if title != "":
		_title_label.text = title
		_title_label.visible = true
		_separator.visible = true
	else:
		_title_label.visible = false
		_separator.visible = false

	# 稀有度
	if rarity != "":
		_rarity_label.text = _get_rarity_text(rarity)
		_rarity_label.add_theme_color_override("font_color", _get_rarity_color(rarity))
		_rarity_label.visible = true
	else:
		_rarity_label.visible = false

	# 描述
	if description != "":
		_description_label.text = description
		_description_label.visible = true
	else:
		_description_label.visible = false

	# 属性列表
	for child in _stats_container.get_children():
		child.queue_free()

	if stats.size() > 0:
		_stats_container.visible = true
		for stat in stats:
			var row := _create_stat_row(stat)
			_stats_container.add_child(row)
	else:
		_stats_container.visible = false

func _create_stat_row(stat: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = stat.get("label", "")
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", TEXT_SECONDARY)
	label.custom_minimum_size.x = 80
	row.add_child(label)

	var value := Label.new()
	value.text = str(stat.get("value", ""))
	value.add_theme_font_size_override("font_size", 13)
	var color: Color = stat.get("color", UIColors.TEXT_PRIMARY)
	value.add_theme_color_override("font_color", color)
	row.add_child(value)

	return row

# ============================================================
# 内部方法 — 位置更新
# ============================================================

func _update_position() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := _tooltip_panel.size

	var pos := mouse_pos + mouse_offset

	# 右边界检查
	if pos.x + panel_size.x + edge_padding > viewport_size.x:
		pos.x = mouse_pos.x - panel_size.x - mouse_offset.x

	# 下边界检查
	if pos.y + panel_size.y + edge_padding > viewport_size.y:
		pos.y = mouse_pos.y - panel_size.y - mouse_offset.y

	# 确保不超出左/上边界
	pos.x = maxf(pos.x, edge_padding)
	pos.y = maxf(pos.y, edge_padding)

	_tooltip_panel.position = pos

# ============================================================
# 辅助方法
# ============================================================

func _get_rarity_text(rarity: String) -> String:
	match rarity:
		"common": return "普通"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传说"
		_: return rarity

func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return TEXT_SECONDARY
		"rare": return UIColors.RARITY_RARE
		"epic": return UIColors.ACCENT
		"legendary": return UIColors.GOLD
		_: return TEXT_SECONDARY

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.name = "TooltipPanel"
	_tooltip_panel.custom_minimum_size = Vector2(180, 40)
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.with_alpha(UIColors.PANEL_BG, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = UIColors.BORDER_DEFAULT
	style.shadow_color = UIColors.with_alpha(Color.BLACK, 0.4)
	style.shadow_size = 4
	_tooltip_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.name = "TooltipVBox"
	vbox.add_theme_constant_override("separation", 6)

	# 标题行
	var title_hbox := HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 8)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = ""
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(_title_label)

	_rarity_label = Label.new()
	_rarity_label.name = "RarityLabel"
	_rarity_label.text = ""
	_rarity_label.visible = false
	_rarity_label.add_theme_font_size_override("font_size", 12)
	title_hbox.add_child(_rarity_label)

	vbox.add_child(title_hbox)

	# 分隔线
	_separator = ColorRect.new()
	_separator.name = "Separator"
	_separator.color = UIColors.with_alpha(UIColors.ACCENT, 0.2)
	_separator.custom_minimum_size.y = 1
	vbox.add_child(_separator)

	# 描述
	_description_label = RichTextLabel.new()
	_description_label.name = "DescriptionLabel"
	_description_label.bbcode_enabled = true
	_description_label.fit_content = true
	_description_label.scroll_active = false
	_description_label.custom_minimum_size = Vector2(160, 20)
	_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_label.add_theme_color_override("default_color", TEXT_SECONDARY)
	_description_label.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(_description_label)

	# 属性列表容器
	_stats_container = VBoxContainer.new()
	_stats_container.name = "StatsContainer"
	_stats_container.add_theme_constant_override("separation", 3)
	_stats_container.visible = false
	vbox.add_child(_stats_container)

	_tooltip_panel.add_child(vbox)
	add_child(_tooltip_panel)
