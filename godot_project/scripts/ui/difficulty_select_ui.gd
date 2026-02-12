## difficulty_select_ui.gd
## 难度选择 UI 面板
## Issue #115: 在主菜单中添加难度选项
##
## 功能：
##   - 显示 4 种难度选项卡片
##   - 每张卡片包含难度名称、描述、属性倍率预览
##   - 选中后高亮并保存选择
##   - 与 DifficultyManager 协作
extends Control

# ============================================================
# 信号
# ============================================================
signal difficulty_selected(difficulty: int)
signal back_pressed()

# ============================================================
# 内部状态
# ============================================================
var _cards: Array[Control] = []
var _selected_index: int = 1  ## 默认选中 Normal
var _title_label: Label = null
var _back_button: Button = null
var _confirm_button: Button = null
var _description_label: Label = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_ui()
	# 从 DifficultyManager 读取当前难度
	var diff_mgr := get_node_or_null("/root/DifficultyManager")
	if diff_mgr:
		_selected_index = diff_mgr.get_difficulty()
	_update_selection()

# ============================================================
# UI 构建
# ============================================================

func _setup_ui() -> void:
	# 半透明背景
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.0, 0.0, 0.05, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 标题
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "选择难度"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_title_label.anchor_left = 0.0
	_title_label.anchor_right = 1.0
	_title_label.anchor_top = 0.0
	_title_label.anchor_bottom = 0.0
	_title_label.offset_top = 40
	_title_label.offset_bottom = 90
	add_child(_title_label)

	# 难度卡片容器
	var card_container := HBoxContainer.new()
	card_container.name = "CardContainer"
	card_container.anchor_left = 0.05
	card_container.anchor_right = 0.95
	card_container.anchor_top = 0.18
	card_container.anchor_bottom = 0.72
	card_container.offset_left = 0
	card_container.offset_right = 0
	card_container.offset_top = 0
	card_container.offset_bottom = 0
	card_container.add_theme_constant_override("separation", 16)
	card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(card_container)

	# 创建难度卡片
	var diff_mgr := get_node_or_null("/root/DifficultyManager")
	var difficulties: Array = []
	if diff_mgr:
		difficulties = diff_mgr.get_all_difficulties()
	else:
		# 后备数据
		difficulties = [
			{"id": 0, "name": "和声入门", "name_en": "Harmonic Prelude", "description": "适合新手", "icon": "♩", "color": Color(0.3, 0.8, 0.5)},
			{"id": 1, "name": "标准演奏", "name_en": "Standard Performance", "description": "推荐", "icon": "♪", "color": Color(0.3, 0.6, 1.0)},
			{"id": 2, "name": "大师挑战", "name_en": "Maestro Challenge", "description": "高难度", "icon": "♫", "color": Color(1.0, 0.6, 0.2)},
			{"id": 3, "name": "噩梦交响", "name_en": "Nightmare Symphony", "description": "极限", "icon": "𝄞", "color": Color(0.9, 0.15, 0.15)},
		]

	_cards.clear()
	for i in range(difficulties.size()):
		var diff: Dictionary = difficulties[i]
		var card := _create_difficulty_card(diff, i)
		card_container.add_child(card)
		_cards.append(card)

	# 描述标签
	_description_label = Label.new()
	_description_label.name = "DescriptionLabel"
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.add_theme_font_size_override("font_size", 18)
	_description_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_description_label.anchor_left = 0.1
	_description_label.anchor_right = 0.9
	_description_label.anchor_top = 0.74
	_description_label.anchor_bottom = 0.74
	_description_label.offset_top = 0
	_description_label.offset_bottom = 40
	add_child(_description_label)

	# 按钮容器
	var button_container := HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.anchor_left = 0.3
	button_container.anchor_right = 0.7
	button_container.anchor_top = 0.85
	button_container.anchor_bottom = 0.85
	button_container.offset_top = 0
	button_container.offset_bottom = 50
	button_container.add_theme_constant_override("separation", 20)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(button_container)

	# 返回按钮
	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = "返回"
	_back_button.custom_minimum_size = Vector2(140, 45)
	_style_button(_back_button, Color(0.5, 0.5, 0.6))
	_back_button.pressed.connect(_on_back_pressed)
	button_container.add_child(_back_button)

	# 确认按钮
	_confirm_button = Button.new()
	_confirm_button.name = "ConfirmButton"
	_confirm_button.text = "确认选择"
	_confirm_button.custom_minimum_size = Vector2(160, 45)
	_style_button(_confirm_button, Color(0.3, 0.7, 1.0))
	_confirm_button.pressed.connect(_on_confirm_pressed)
	button_container.add_child(_confirm_button)

func _create_difficulty_card(diff: Dictionary, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "DiffCard_%d" % index
	card.custom_minimum_size = Vector2(200, 280)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 卡片样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	style.border_color = diff.get("color", Color.WHITE).darkened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 20
	style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", style)

	# 卡片内容
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# 图标
	var icon_label := Label.new()
	icon_label.text = diff.get("icon", "♪")
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 42)
	icon_label.add_theme_color_override("font_color", diff.get("color", Color.WHITE))
	vbox.add_child(icon_label)

	# 难度名称
	var name_label := Label.new()
	name_label.text = diff.get("name", "")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	vbox.add_child(name_label)

	# 英文名
	var en_label := Label.new()
	en_label.text = diff.get("name_en", "")
	en_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	en_label.add_theme_font_size_override("font_size", 11)
	en_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(en_label)

	# 分隔线
	var separator := HSeparator.new()
	separator.add_theme_stylebox_override("separator", StyleBoxLine.new())
	vbox.add_child(separator)

	# 描述
	var desc_label := Label.new()
	desc_label.text = diff.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	vbox.add_child(desc_label)

	# 点击事件
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_selected_index = index
			_update_selection()
	)

	return card

func _style_button(button: Button, accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.2)
	hover.border_color = accent.lightened(0.2)
	hover.set_border_width_all(2)
	button.add_theme_stylebox_override("hover", hover)

	button.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	button.add_theme_font_size_override("font_size", 14)

# ============================================================
# 选择更新
# ============================================================

func _update_selection() -> void:
	var diff_mgr := get_node_or_null("/root/DifficultyManager")
	var difficulties: Array = []
	if diff_mgr:
		difficulties = diff_mgr.get_all_difficulties()

	for i in range(_cards.size()):
		var card: PanelContainer = _cards[i]
		var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()

		if i == _selected_index:
			# 选中状态
			var color: Color = Color(0.3, 0.6, 1.0)
			if i < difficulties.size():
				color = difficulties[i].get("color", color)
			style.border_color = color
			style.set_border_width_all(3)
			style.bg_color = Color(color.r, color.g, color.b, 0.15)
			card.add_theme_stylebox_override("panel", style)
			card.modulate = Color(1.1, 1.1, 1.1)

			# 更新描述
			if i < difficulties.size() and _description_label:
				_description_label.text = difficulties[i].get("description", "")
		else:
			# 未选中状态
			style.set_border_width_all(1)
			style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
			if i < difficulties.size():
				style.border_color = difficulties[i].get("color", Color.WHITE).darkened(0.5)
			card.add_theme_stylebox_override("panel", style)
			card.modulate = Color(0.7, 0.7, 0.7)

# ============================================================
# 按钮回调
# ============================================================

func _on_confirm_pressed() -> void:
	var diff_mgr := get_node_or_null("/root/DifficultyManager")
	if diff_mgr:
		diff_mgr.set_difficulty(_selected_index)
	difficulty_selected.emit(_selected_index)

func _on_back_pressed() -> void:
	back_pressed.emit()
