## manual_slot_config.gd
## 手动施法槽配置 UI
## 允许玩家从音符库存或法术书中拖拽法术到手动施法槽（1/2/3键）
##
## 设计要点：
##   - HUD 上显示3个手动施法槽图标（对应按键1/2/3）
##   - 点击槽位打开配置面板，可从库存/法术书选择内容
##   - 右键点击已配置的槽位可清空（内容返回库存/法术书）
##   - 支持拖拽操作
extends Control

# ============================================================
# 信号
# ============================================================
signal slot_configured(slot_index: int, spell_data: Dictionary)
signal slot_cleared(slot_index: int)
signal config_panel_toggled(is_open: bool)

# ============================================================
# 常量
# ============================================================
const SLOT_COUNT: int = 3
const SLOT_SIZE := Vector2(60, 60)
const SLOT_MARGIN := 10.0
const SLOT_KEYS := ["1", "2", "3"]

## 配置面板
const CONFIG_PANEL_WIDTH: float = 320.0
const CONFIG_PANEL_HEIGHT: float = 300.0
const CONFIG_ITEM_SIZE := Vector2(48, 48)
const CONFIG_ITEM_MARGIN := 6.0

## 颜色
const SLOT_BG_COLOR := Color(0.06, 0.05, 0.1, 0.85)
const SLOT_EMPTY_COLOR := Color(0.1, 0.08, 0.16, 0.6)
const SLOT_FILLED_COLOR := Color(0.08, 0.06, 0.14, 0.9)
const SLOT_HOVER_COLOR := Color(0.15, 0.12, 0.25, 0.8)
const SLOT_ACTIVE_COLOR := Color(0.2, 0.15, 0.35, 0.9)
const KEY_LABEL_COLOR := Color(0.6, 0.55, 0.75, 0.8)
const COOLDOWN_COLOR := Color(0.1, 0.1, 0.15, 0.7)
const CONFIG_BG_COLOR := Color(0.04, 0.03, 0.08, 0.95)
const CONFIG_SECTION_COLOR := Color(0.5, 0.45, 0.65, 0.8)
const CONFIG_ITEM_BG := Color(0.08, 0.06, 0.14, 0.7)
const CONFIG_ITEM_HOVER := Color(0.15, 0.12, 0.25, 0.8)

# ============================================================
# 状态
# ============================================================
## 当前各槽位的配置内容
## 每个元素: { "type": "empty"/"note"/"chord", "note": int, "spell_id": String, ... }
var _slot_configs: Array[Dictionary] = []

## 交互状态
var _hover_slot: int = -1
var _active_config_slot: int = -1  # 正在配置的槽位（-1表示配置面板关闭）
var _hover_config_item: int = -1
var _config_items: Array[Dictionary] = []  # 配置面板中的可选项

## 拖拽状态
var _is_dragging: bool = false
var _drag_data: Dictionary = {}
var _drag_position: Vector2 = Vector2.ZERO
var _drag_from_slot: int = -1

## 布局缓存
var _slot_rects: Array[Rect2] = []
var _config_panel_rect: Rect2 = Rect2()
var _config_item_rects: Array[Rect2] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_init_slots()
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 连接库存变化信号以刷新配置面板
	NoteInventory.inventory_changed.connect(_on_inventory_changed)
	NoteInventory.spellbook_changed.connect(_on_spellbook_changed)

func _process(_delta: float) -> void:
	queue_redraw()

# ============================================================
# 初始化
# ============================================================

func _init_slots() -> void:
	_slot_configs.clear()
	for i in range(SLOT_COUNT):
		_slot_configs.append({ "type": "empty" })

# ============================================================
# 布局
# ============================================================

func _calculate_layout() -> void:
	_slot_rects.clear()

	# 槽位从左到右排列
	var start_x := 10.0
	var start_y := (size.y - SLOT_SIZE.y) / 2.0
	for i in range(SLOT_COUNT):
		var x := start_x + i * (SLOT_SIZE.x + SLOT_MARGIN)
		_slot_rects.append(Rect2(Vector2(x, start_y), SLOT_SIZE))

	# 配置面板位置（在活跃槽位上方）
	if _active_config_slot >= 0 and _active_config_slot < _slot_rects.size():
		var slot_rect := _slot_rects[_active_config_slot]
		var panel_x := slot_rect.position.x - CONFIG_PANEL_WIDTH / 2.0 + SLOT_SIZE.x / 2.0
		var panel_y := slot_rect.position.y - CONFIG_PANEL_HEIGHT - 10.0

		# 确保面板不超出屏幕
		panel_x = clamp(panel_x, 5.0, size.x - CONFIG_PANEL_WIDTH - 5.0)
		if panel_y < 5.0:
			panel_y = slot_rect.position.y + SLOT_SIZE.y + 10.0

		_config_panel_rect = Rect2(Vector2(panel_x, panel_y), Vector2(CONFIG_PANEL_WIDTH, CONFIG_PANEL_HEIGHT))

		# 配置项布局
		_calculate_config_items_layout()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	_calculate_layout()
	var font := ThemeDB.fallback_font

	# 背景
	draw_rect(Rect2(Vector2.ZERO, size), SLOT_BG_COLOR)

	# 标题
	draw_string(font, Vector2(10, 14), "MANUAL CAST", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.45, 0.6, 0.7))

	# 绘制每个槽位
	for i in range(SLOT_COUNT):
		_draw_slot(i, font)

	# 绘制配置面板
	if _active_config_slot >= 0:
		_draw_config_panel(font)

	# 拖拽幽灵
	if _is_dragging:
		_draw_drag_ghost(font)

func _draw_slot(index: int, font: Font) -> void:
	var rect := _slot_rects[index]
	var config := _slot_configs[index]
	var is_hover := (_hover_slot == index)
	var is_active := (_active_config_slot == index)
	var is_filled: bool = config.get("type", "empty") != "empty"

	# 背景
	var bg_color := SLOT_EMPTY_COLOR
	if is_active:
		bg_color = SLOT_ACTIVE_COLOR
	elif is_hover:
		bg_color = SLOT_HOVER_COLOR
	elif is_filled:
		bg_color = SLOT_FILLED_COLOR
	draw_rect(rect, bg_color)

	# 边框
	var border_color := Color(0.3, 0.25, 0.45, 0.5)
	if is_active:
		border_color = Color(0.5, 0.4, 0.8, 0.8)
	elif is_filled:
		border_color = _get_config_color(config)
		border_color.a = 0.7
	draw_rect(rect, border_color, false, 1.5)

	# 内容
	if is_filled:
		_draw_slot_content(rect, config, font)
	else:
		# 空槽位：显示加号
		draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 6, rect.size.y / 2.0 + 6),
			"+", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(0.3, 0.28, 0.4, 0.5))

	# 按键标签
	draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 3, rect.size.y + 14),
		SLOT_KEYS[index], HORIZONTAL_ALIGNMENT_CENTER, -1, 11, KEY_LABEL_COLOR)

	# 冷却覆盖
	var cooldown_progress := SpellcraftSystem.get_manual_slot_cooldown_progress(index)
	if cooldown_progress > 0.01:
		var cooldown_height := rect.size.y * cooldown_progress
		var cooldown_rect := Rect2(
			Vector2(rect.position.x, rect.position.y + rect.size.y - cooldown_height),
			Vector2(rect.size.x, cooldown_height)
		)
		draw_rect(cooldown_rect, COOLDOWN_COLOR)

func _draw_slot_content(rect: Rect2, config: Dictionary, font: Font) -> void:
	var slot_type: String = config.get("type", "empty")

	match slot_type:
		"note":
			var note_key: int = config.get("note", 0)
			var note_color: Color = MusicData.NOTE_COLORS.get(note_key, Color(0.0, 1.0, 0.8))
			# 音符颜色填充
			note_color.a = 0.25
			draw_rect(rect.grow(-3), note_color)
			# 音符名称
			note_color.a = 1.0
			var note_name: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
			draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 8, rect.size.y / 2.0 + 6),
				note_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, note_color)

		"chord":
			var spell_id: String = config.get("spell_id", "")
			var spell := NoteInventory.get_chord_spell(spell_id)
			if not spell.is_empty():
				# 和弦颜色
				var chord_color := Color(1.0, 0.8, 0.0, 0.25)
				draw_rect(rect.grow(-3), chord_color)
				# 和弦图标
				draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 8, rect.size.y / 2.0 - 2),
					"C", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1.0, 0.8, 0.0))
				# 法术名称（缩写）
				var spell_name: String = spell.get("spell_name", "?")
				if spell_name.length() > 4:
					spell_name = spell_name.left(4)
				draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 10, rect.size.y / 2.0 + 14),
					spell_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.9, 0.8, 0.5))

func _draw_config_panel(font: Font) -> void:
	# 面板背景
	draw_rect(_config_panel_rect, CONFIG_BG_COLOR)
	draw_rect(_config_panel_rect, Color(0.4, 0.35, 0.6, 0.5), false, 1.5)

	var pos := _config_panel_rect.position

	# 标题
	draw_string(font, pos + Vector2(12, 22),
		"Configure Slot %s" % SLOT_KEYS[_active_config_slot],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.75, 0.95))

	# 分隔线
	draw_line(pos + Vector2(10, 30), pos + Vector2(CONFIG_PANEL_WIDTH - 10, 30), Color(0.3, 0.25, 0.45, 0.5), 1.0)

	# 音符区标题
	draw_string(font, pos + Vector2(12, 48),
		"NOTES", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CONFIG_SECTION_COLOR)

	# 和弦法术区标题
	draw_string(font, pos + Vector2(12, 140),
		"CHORD SPELLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CONFIG_SECTION_COLOR)

	# 绘制配置项
	for i in range(_config_items.size()):
		if i < _config_item_rects.size():
			_draw_config_item(i, font)

func _draw_config_item(index: int, font: Font) -> void:
	var rect := _config_item_rects[index]
	var item := _config_items[index]
	var is_hover := (_hover_config_item == index)

	var bg_color := CONFIG_ITEM_BG
	if is_hover:
		bg_color = CONFIG_ITEM_HOVER
	draw_rect(rect, bg_color)

	var item_type: String = item.get("type", "")

	if item_type == "note":
		var note_key: int = item.get("note", 0)
		var count: int = item.get("count", 0)
		var note_color: Color = MusicData.NOTE_COLORS.get(note_key, Color(0.5, 0.5, 0.5))

		if count <= 0:
			note_color = Color(0.3, 0.3, 0.3, 0.4)

		# 边框
		draw_rect(rect, note_color * 0.6, false, 1.0)

		# 音符名称
		var note_name: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
		draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 6, rect.size.y / 2.0 + 4),
			note_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, note_color)

		# 数量
		var count_color := Color(0.7, 0.7, 0.8) if count > 0 else Color(0.4, 0.4, 0.4)
		draw_string(font, rect.position + Vector2(rect.size.x - 4, 12),
			"x%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, -1, 8, count_color)

	elif item_type == "chord":
		var spell: Dictionary = item.get("spell", {})
		var chord_color := Color(1.0, 0.8, 0.0)

		draw_rect(rect, chord_color * 0.15, false, 1.0)

		# 和弦名称
		var spell_name: String = spell.get("spell_name", "?")
		if spell_name.length() > 6:
			spell_name = spell_name.left(6)
		draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 12, rect.size.y / 2.0 + 4),
			spell_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, chord_color)

func _draw_drag_ghost(font: Font) -> void:
	var drag_type: String = _drag_data.get("type", "")
	var ghost_color := Color(0.5, 0.5, 0.5, 0.5)
	var label := "?"

	if drag_type == "note":
		var note_key: int = _drag_data.get("note", 0)
		ghost_color = MusicData.NOTE_COLORS.get(note_key, Color(0.0, 1.0, 0.8))
		ghost_color.a = 0.5
		label = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
	elif drag_type == "chord":
		ghost_color = Color(1.0, 0.8, 0.0, 0.5)
		label = "C"

	var ghost_rect := Rect2(_drag_position - SLOT_SIZE / 2.0, SLOT_SIZE)
	draw_rect(ghost_rect, ghost_color)
	draw_string(font, _drag_position + Vector2(-6, 6), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)

# ============================================================
# 配置面板项目布局
# ============================================================

func _calculate_config_items_layout() -> void:
	_config_items.clear()
	_config_item_rects.clear()

	var panel_pos := _config_panel_rect.position

	# 音符项（7个白键）
	var note_start_x := panel_pos.x + 12.0
	var note_y := panel_pos.y + 56.0
	for i in range(7):
		var note_key: int = i
		var count: int = NoteInventory.get_note_count(note_key)
		_config_items.append({
			"type": "note",
			"note": note_key,
			"count": count,
		})
		var x := note_start_x + i * (CONFIG_ITEM_SIZE.x + CONFIG_ITEM_MARGIN)
		_config_item_rects.append(Rect2(Vector2(x, note_y), CONFIG_ITEM_SIZE))

	# 和弦法术项
	var chord_spells := NoteInventory.get_available_chord_spells()
	var chord_start_x := panel_pos.x + 12.0
	var chord_y := panel_pos.y + 155.0
	for i in range(chord_spells.size()):
		var spell := chord_spells[i]
		_config_items.append({
			"type": "chord",
			"spell": spell,
			"spell_id": spell.get("id", ""),
		})
		var col := i % 5
		var row := i / 5
		var x := chord_start_x + col * (CONFIG_ITEM_SIZE.x + CONFIG_ITEM_MARGIN)
		var y := chord_y + row * (CONFIG_ITEM_SIZE.y + CONFIG_ITEM_MARGIN)
		_config_item_rects.append(Rect2(Vector2(x, y), CONFIG_ITEM_SIZE))

# ============================================================
# 输入处理
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.position)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)

func _handle_mouse_motion(pos: Vector2) -> void:
	_hover_slot = -1
	_hover_config_item = -1

	# 检查槽位悬停
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos):
			_hover_slot = i
			break

	# 检查配置面板项悬停
	if _active_config_slot >= 0:
		for i in range(_config_item_rects.size()):
			if _config_item_rects[i].has_point(pos):
				_hover_config_item = i
				break

	# 拖拽更新
	if _is_dragging:
		_drag_position = pos

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_left_press(event.position)
		else:
			_on_left_release(event.position)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_on_right_press(event.position)

func _on_left_press(pos: Vector2) -> void:
	# 点击配置面板中的项目
	if _active_config_slot >= 0:
		for i in range(_config_item_rects.size()):
			if _config_item_rects[i].has_point(pos):
				_select_config_item(i)
				return

		# 点击面板外部关闭
		if not _config_panel_rect.has_point(pos):
			# 检查是否点击了其他槽位
			for i in range(_slot_rects.size()):
				if _slot_rects[i].has_point(pos):
					if i == _active_config_slot:
						_active_config_slot = -1
						config_panel_toggled.emit(false)
					else:
						_active_config_slot = i
						config_panel_toggled.emit(true)
					return
			_active_config_slot = -1
			config_panel_toggled.emit(false)
			return

	# 点击槽位
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos):
			_active_config_slot = i
			config_panel_toggled.emit(true)
			return

func _on_left_release(pos: Vector2) -> void:
	if _is_dragging:
		# 检查是否放入槽位
		for i in range(_slot_rects.size()):
			if _slot_rects[i].has_point(pos):
				_configure_slot(i, _drag_data)
				break
		_is_dragging = false
		_drag_data = {}
		_drag_from_slot = -1

func _on_right_press(pos: Vector2) -> void:
	# 右键清空槽位
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos):
			if _slot_configs[i].get("type", "empty") != "empty":
				_clear_slot(i)
			return

# ============================================================
# 槽位配置
# ============================================================

## 选择配置面板中的项目
func _select_config_item(item_index: int) -> void:
	if item_index < 0 or item_index >= _config_items.size():
		return
	if _active_config_slot < 0:
		return

	var item := _config_items[item_index]
	_configure_slot(_active_config_slot, item)
	_active_config_slot = -1
	config_panel_toggled.emit(false)

## 配置指定槽位
func _configure_slot(slot_index: int, data: Dictionary) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return

	var item_type: String = data.get("type", "")

	if item_type == "note":
		var note_key: int = data.get("note", -1)
		if note_key < 0:
			return
		var spell_data := {
			"type": "note",
			"note": note_key,
		}
		SpellcraftSystem.set_manual_slot(slot_index, spell_data)
		_slot_configs[slot_index] = spell_data
		slot_configured.emit(slot_index, spell_data)

	elif item_type == "chord":
		var spell_id: String = data.get("spell_id", "")
		if spell_id.is_empty():
			return
		var spell_data := {
			"type": "chord",
			"spell_id": spell_id,
		}
		SpellcraftSystem.set_manual_slot(slot_index, spell_data)
		_slot_configs[slot_index] = spell_data
		slot_configured.emit(slot_index, spell_data)

## 清空指定槽位
func _clear_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	SpellcraftSystem.clear_manual_slot(slot_index)
	_slot_configs[slot_index] = { "type": "empty" }
	slot_cleared.emit(slot_index)

# ============================================================
# 工具函数
# ============================================================

func _get_config_color(config: Dictionary) -> Color:
	var config_type: String = config.get("type", "empty")
	match config_type:
		"note":
			var note_key: int = config.get("note", 0)
			return MusicData.NOTE_COLORS.get(note_key, Color(0.0, 1.0, 0.8))
		"chord":
			return Color(1.0, 0.8, 0.0)
	return Color(0.5, 0.5, 0.5)

## 重置所有槽位
func reset() -> void:
	for i in range(SLOT_COUNT):
		_clear_slot(i)
	_active_config_slot = -1

# ============================================================
# 信号回调
# ============================================================

func _on_inventory_changed(_note_key: int, _new_count: int) -> void:
	# 刷新配置面板
	if _active_config_slot >= 0:
		_calculate_config_items_layout()

func _on_spellbook_changed(_spellbook: Array) -> void:
	# 刷新配置面板
	if _active_config_slot >= 0:
		_calculate_config_items_layout()
