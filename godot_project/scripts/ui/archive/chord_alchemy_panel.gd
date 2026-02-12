## DEPRECATED: This file has been archived and is no longer actively used.
## Signals defined here are not connected. Retained for reference only.
## chord_alchemy_panel.gd
## 和弦炼成台 UI
## 玩家将3个以上音符放入炼成槽，系统自动识别和弦类型并合成"和弦法术"
##
## 设计要点：
##   - 从音符库存拖入音符到炼成槽（最多6个）
##   - 实时预览和弦类型、法术形态、效果描述
##   - 点击"合成"永久消耗音符，生成和弦法术存入法术书
##   - 右键点击炼成槽中的音符可将其移回库存
extends Control

# ============================================================
# 信号
# ============================================================
signal alchemy_completed(chord_spell: Dictionary)
signal panel_closed()

# ============================================================
# 常量
# ============================================================
## 炼成槽数量（最多支持6音和弦）
const MAX_INGREDIENT_SLOTS: int = 6
## 最少合成所需音符数
const MIN_NOTES_FOR_CHORD: int = 3

## 布局常量
const PANEL_SIZE := Vector2(600, 450)
const SLOT_SIZE := Vector2(56, 56)
const SLOT_MARGIN := 8.0
const INVENTORY_CELL_SIZE := Vector2(44, 44)
const INVENTORY_CELL_MARGIN := 6.0

## 颜色
const BG_COLOR := Color(0.04, 0.03, 0.08, 0.95)
const SLOT_EMPTY_COLOR := Color(0.1, 0.08, 0.16, 0.7)
const SLOT_FILLED_COLOR := Color(0.12, 0.1, 0.2, 0.9)
const SLOT_HOVER_COLOR := Color(0.18, 0.15, 0.28, 0.8)
const PREVIEW_BG_COLOR := Color(0.06, 0.05, 0.12, 0.8)
const SYNTH_BUTTON_COLOR := Color(0.1, 0.6, 0.4, 0.9)
const SYNTH_BUTTON_DISABLED := Color(0.2, 0.2, 0.25, 0.5)
const SYNTH_BUTTON_HOVER := Color(0.15, 0.75, 0.5, 1.0)
const INVENTORY_BG_COLOR := Color(0.05, 0.04, 0.1, 0.7)
const CLOSE_BUTTON_COLOR := Color(0.8, 0.2, 0.2, 0.8)

# ============================================================
# 和弦类型识别表（音程集合 → 和弦类型）
# ============================================================
## 音程模式 → { "name": 显示名, "spell_form": 法术形态, "desc": 效果描述 }
## ★ 映射已与 GDD 4.3 节及 Spell_Visual_Enhancement_Design.md 同步
const CHORD_PATTERNS := {
	# 三和弦（3音）
	"0,4,7": { "name": "大三和弦", "spell_form": "enhanced_projectile", "desc": "强化弹体：弹体体积+50%，伤害+40%，圣光金色" },
	"0,3,7": { "name": "小三和弦", "spell_form": "dot_projectile", "desc": "DOT弹体：命中后持续伤害，暗蓝色液态质感" },
	"0,3,6": { "name": "减三和弦", "spell_form": "shockwave", "desc": "冲击波：环形扩散后内爆，深紫色能量刀刃" },
	"0,4,8": { "name": "增三和弦", "spell_form": "explosive_projectile", "desc": "爆炸弹体：命中时范围爆炸，烈焰橙不稳定能量球" },
	# 七和弦（4音）
	"0,4,7,11": { "name": "大七和弦", "spell_form": "shield_heal", "desc": "护盾/治疗法阵：治愈绿半球护盾，恢复生命值" },
	"0,4,7,10": { "name": "属七和弦", "spell_form": "magic_circle", "desc": "法阵/区域：Dominant黄旋转法阵，持续存在" },
	"0,3,7,10": { "name": "小七和弦", "spell_form": "summon_construct", "desc": "召唤/构造：深蓝色水晶构造体从地面生长" },
	"0,3,6,9": { "name": "减七和弦", "spell_form": "celestial_strike", "desc": "天降打击：延迟后毁灭性打击，血红预警区域" },
	"0,3,6,10": { "name": "半减七和弦", "spell_form": "slow_field", "desc": "迟缓领域：大范围减速效果" },
	# 挂留和弦（3音）
	"0,5,7": { "name": "挂四和弦", "spell_form": "charged_projectile", "desc": "蓄力弹体：延迟释放，银白色蓄能球体" },
	"0,2,7": { "name": "挂二和弦", "spell_form": "charged_projectile", "desc": "蓄力弹体：延迟释放，银白色蓄能球体" },
}

## 法术形态颜色（与 Spell_Visual_Enhancement_Design.md 视觉规范同步）
const SPELL_FORM_COLORS := {
	"enhanced_projectile": Color(1.0, 0.85, 0.3),   # 圣光金 — 大三和弦
	"dot_projectile": Color(0.2, 0.3, 0.8),          # 暗蓝色 — 小三和弦
	"explosive_projectile": Color(1.0, 0.4, 0.2),    # 烈焰橙 — 增三和弦
	"shockwave": Color(0.5, 0.1, 0.7),               # 深紫色 — 减三和弦
	"magic_circle": Color(1.0, 0.8, 0.0),             # Dominant黄 — 属七和弦
	"celestial_strike": Color(0.8, 0.1, 0.1),         # 血红色 — 减七和弦
	"shield_heal": Color(0.2, 0.9, 0.4),              # 治愈绿 — 大七和弦
	"summon_construct": Color(0.15, 0.2, 0.7),        # 深蓝色 — 小七和弦
	"charged_projectile": Color(0.85, 0.85, 0.95),    # 银白色 — 挂留和弦
	"slow_field": Color(0.3, 0.3, 0.7),               # 紫蓝色 — 半减七和弦
	"generic_blast": Color(0.5, 0.5, 0.5),            # 灰色 — 未识别和弦
}

# ============================================================
# 状态
# ============================================================
## 炼成槽中的音符（WhiteKey 值，-1 表示空）
var _ingredient_slots: Array[int] = []
## 当前识别到的和弦信息
var _preview_chord: Dictionary = {}
## 是否可以合成
var _can_synthesize: bool = false
## 面板是否可见
var _is_visible: bool = false

## 交互状态
var _hover_slot_idx: int = -1
var _hover_inventory_idx: int = -1
var _hover_synth_button: bool = false
var _hover_close_button: bool = false

## 拖拽状态
var _is_dragging: bool = false
var _drag_note: int = -1
var _drag_from_slot: int = -1  # -1 表示从库存拖入
var _drag_position: Vector2 = Vector2.ZERO

## 布局缓存
var _panel_rect: Rect2 = Rect2()
var _slot_rects: Array[Rect2] = []
var _inventory_rects: Array[Rect2] = []
var _synth_button_rect: Rect2 = Rect2()
var _close_button_rect: Rect2 = Rect2()
var _preview_rect: Rect2 = Rect2()

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	visible = false
	_init_slots()
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_delta: float) -> void:
	if _is_visible:
		queue_redraw()

# ============================================================
# 初始化
# ============================================================

func _init_slots() -> void:
	_ingredient_slots.clear()
	for i in range(MAX_INGREDIENT_SLOTS):
		_ingredient_slots.append(-1)
	_preview_chord = {}
	_can_synthesize = false

# ============================================================
# 显示/隐藏
# ============================================================

func show_panel() -> void:
	_is_visible = true
	visible = true
	_init_slots()
	_calculate_layout()
	queue_redraw()

func hide_panel() -> void:
	# 将炼成槽中的音符返回库存
	for i in range(MAX_INGREDIENT_SLOTS):
		if _ingredient_slots[i] >= 0:
			NoteInventory.unequip_note(_ingredient_slots[i])
			_ingredient_slots[i] = -1
	_is_visible = false
	visible = false
	panel_closed.emit()

# ============================================================
# 布局计算
# ============================================================

func _calculate_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var panel_pos := (viewport_size - PANEL_SIZE) / 2.0
	_panel_rect = Rect2(panel_pos, PANEL_SIZE)

	# 炼成槽位置（面板上部居中）
	_slot_rects.clear()
	var slots_total_width := MAX_INGREDIENT_SLOTS * (SLOT_SIZE.x + SLOT_MARGIN) - SLOT_MARGIN
	var slots_start_x := _panel_rect.position.x + (_panel_rect.size.x - slots_total_width) / 2.0
	var slots_y := _panel_rect.position.y + 60.0
	for i in range(MAX_INGREDIENT_SLOTS):
		var x := slots_start_x + i * (SLOT_SIZE.x + SLOT_MARGIN)
		_slot_rects.append(Rect2(Vector2(x, slots_y), SLOT_SIZE))

	# 预览区（炼成槽下方）
	_preview_rect = Rect2(
		Vector2(_panel_rect.position.x + 30, slots_y + SLOT_SIZE.y + 20),
		Vector2(PANEL_SIZE.x - 60, 100)
	)

	# 音符库存区（预览区下方）
	_inventory_rects.clear()
	var inv_start_x := _panel_rect.position.x + 30.0
	var inv_y := _preview_rect.position.y + _preview_rect.size.y + 20.0
	for i in range(7):  # 7个白键
		var x := inv_start_x + i * (INVENTORY_CELL_SIZE.x + INVENTORY_CELL_MARGIN)
		_inventory_rects.append(Rect2(Vector2(x, inv_y), INVENTORY_CELL_SIZE))

	# 合成按钮（底部居中）
	var synth_btn_size := Vector2(180, 44)
	_synth_button_rect = Rect2(
		Vector2(_panel_rect.position.x + (_panel_rect.size.x - synth_btn_size.x) / 2.0,
				_panel_rect.position.y + PANEL_SIZE.y - 65),
		synth_btn_size
	)

	# 关闭按钮（右上角）
	_close_button_rect = Rect2(
		Vector2(_panel_rect.position.x + PANEL_SIZE.x - 36, _panel_rect.position.y + 8),
		Vector2(28, 28)
	)

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if not _is_visible:
		return

	_calculate_layout()
	var font := ThemeDB.fallback_font

	# 背景遮罩
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.0, 0.0, 0.0, 0.5))

	# 面板背景
	draw_rect(_panel_rect, BG_COLOR)
	draw_rect(_panel_rect, Color(0.3, 0.25, 0.5, 0.4), false, 2.0)

	# 标题
	draw_string(font, _panel_rect.position + Vector2(20, 35),
		"CHORD ALCHEMY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.7, 1.0))
	draw_string(font, _panel_rect.position + Vector2(200, 35),
		"Place 3+ notes to synthesize a chord spell", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.45, 0.6))

	# 关闭按钮
	var close_color := CLOSE_BUTTON_COLOR if not _hover_close_button else Color(1.0, 0.3, 0.3, 1.0)
	draw_rect(_close_button_rect, close_color)
	draw_string(font, _close_button_rect.position + Vector2(8, 20), "X", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)

	# 炼成槽
	_draw_ingredient_slots(font)

	# 预览区
	_draw_preview(font)

	# 音符库存
	_draw_inventory(font)

	# 合成按钮
	_draw_synth_button(font)

	# 拖拽幽灵
	if _is_dragging and _drag_note >= 0:
		var drag_color: Color = MusicData.NOTE_COLORS.get(_drag_note, Color(0.0, 1.0, 0.8))
		drag_color.a = 0.6
		draw_rect(Rect2(_drag_position - SLOT_SIZE / 2.0, SLOT_SIZE), drag_color)
		var note_name: String = MusicData.WHITE_KEY_STATS.get(_drag_note, {}).get("name", "?")
		draw_string(font, _drag_position + Vector2(-6, 6), note_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)

func _draw_ingredient_slots(font: Font) -> void:
	for i in range(MAX_INGREDIENT_SLOTS):
		var rect := _slot_rects[i]
		var is_filled := _ingredient_slots[i] >= 0
		var is_hover := (_hover_slot_idx == i)

		# 背景
		var bg_color := SLOT_FILLED_COLOR if is_filled else SLOT_EMPTY_COLOR
		if is_hover:
			bg_color = SLOT_HOVER_COLOR
		draw_rect(rect, bg_color)

		# 边框
		var border_color := Color(0.4, 0.35, 0.55, 0.5)
		if is_filled:
			border_color = MusicData.NOTE_COLORS.get(_ingredient_slots[i], Color(0.0, 1.0, 0.8))
			border_color.a = 0.8
		draw_rect(rect, border_color, false, 1.5)

		if is_filled:
			# 音符颜色填充
			var note_color: Color = MusicData.NOTE_COLORS.get(_ingredient_slots[i], Color(0.0, 1.0, 0.8))
			note_color.a = 0.3
			draw_rect(rect.grow(-3), note_color)

			# 音符名称
			var note_name: String = MusicData.WHITE_KEY_STATS.get(_ingredient_slots[i], {}).get("name", "?")
			draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 8, rect.size.y / 2.0 + 6),
				note_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.WHITE)
		else:
			# 空槽位编号
			var slot_label := "%d" % (i + 1)
			draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 4, rect.size.y / 2.0 + 4),
				slot_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.3, 0.28, 0.4, 0.5))

		# 最低要求标记（前3个槽位）
		if i < MIN_NOTES_FOR_CHORD:
			draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 2, rect.size.y + 12),
				"*", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.6, 0.2, 0.6))

func _draw_preview(font: Font) -> void:
	draw_rect(_preview_rect, PREVIEW_BG_COLOR)
	draw_rect(_preview_rect, Color(0.25, 0.2, 0.4, 0.3), false, 1.0)

	if _preview_chord.is_empty():
		draw_string(font, _preview_rect.position + Vector2(20, 35),
			"Place notes above to preview chord type...",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.38, 0.5, 0.6))
		return

	var chord_name: String = _preview_chord.get("name", "Unknown")
	var spell_form: String = _preview_chord.get("spell_form", "unknown")
	var desc: String = _preview_chord.get("desc", "")
	var form_color: Color = SPELL_FORM_COLORS.get(spell_form, Color(0.5, 0.5, 0.5))

	# 和弦名称
	draw_string(font, _preview_rect.position + Vector2(20, 30),
		chord_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, form_color)

	# 法术形态
	draw_string(font, _preview_rect.position + Vector2(20, 55),
		"Form: %s" % spell_form.replace("_", " ").capitalize(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.65, 0.8))

	# 效果描述
	draw_string(font, _preview_rect.position + Vector2(20, 80),
		desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.58, 0.7))

func _draw_inventory(font: Font) -> void:
	# 标题
	if _inventory_rects.size() > 0:
		draw_string(font, _inventory_rects[0].position + Vector2(0, -8),
			"NOTE INVENTORY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.45, 0.6))

	for i in range(min(7, _inventory_rects.size())):
		var rect := _inventory_rects[i]
		var note_key: int = i  # WhiteKey 0-6
		var count: int = NoteInventory.get_note_count(note_key)
		var is_hover := (_hover_inventory_idx == i)

		# 背景
		var bg_color := INVENTORY_BG_COLOR
		if is_hover and count > 0:
			bg_color = Color(0.1, 0.08, 0.18, 0.9)
		draw_rect(rect, bg_color)

		# 音符颜色
		var note_color: Color = MusicData.NOTE_COLORS.get(note_key, Color(0.5, 0.5, 0.5))
		if count <= 0:
			note_color = Color(0.3, 0.3, 0.3, 0.4)

		# 边框
		draw_rect(rect, note_color * 0.7, false, 1.0)

		# 音符名称
		var note_name: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
		draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 6, rect.size.y / 2.0 + 2),
			note_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, note_color)

		# 数量
		var count_color := Color(0.8, 0.8, 0.9) if count > 0 else Color(0.4, 0.4, 0.4)
		draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 4, rect.size.y + 14),
			"x%d" % count, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, count_color)

func _draw_synth_button(font: Font) -> void:
	var btn_color := SYNTH_BUTTON_COLOR if _can_synthesize else SYNTH_BUTTON_DISABLED
	if _hover_synth_button and _can_synthesize:
		btn_color = SYNTH_BUTTON_HOVER
	draw_rect(_synth_button_rect, btn_color)
	draw_rect(_synth_button_rect, Color(0.3, 0.8, 0.6, 0.5) if _can_synthesize else Color(0.3, 0.3, 0.35, 0.3), false, 1.5)

	var text_color := Color.WHITE if _can_synthesize else Color(0.5, 0.5, 0.55)
	draw_string(font, _synth_button_rect.position + Vector2(_synth_button_rect.size.x / 2.0 - 40, 28),
		"SYNTHESIZE", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, text_color)

# ============================================================
# 输入处理
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if not _is_visible:
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.position)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)

func _handle_mouse_motion(pos: Vector2) -> void:
	_hover_slot_idx = -1
	_hover_inventory_idx = -1
	_hover_synth_button = false
	_hover_close_button = false

	# 检查炼成槽悬停
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos):
			_hover_slot_idx = i
			break

	# 检查库存悬停
	for i in range(_inventory_rects.size()):
		if _inventory_rects[i].has_point(pos):
			_hover_inventory_idx = i
			break

	# 检查合成按钮
	_hover_synth_button = _synth_button_rect.has_point(pos)

	# 检查关闭按钮
	_hover_close_button = _close_button_rect.has_point(pos)

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
	# 关闭按钮
	if _close_button_rect.has_point(pos):
		hide_panel()
		return

	# 合成按钮
	if _synth_button_rect.has_point(pos) and _can_synthesize:
		_execute_synthesis()
		return

	# 从库存开始拖拽
	for i in range(_inventory_rects.size()):
		if _inventory_rects[i].has_point(pos):
			var note_key: int = i
			if NoteInventory.has_note(note_key):
				_is_dragging = true
				_drag_note = note_key
				_drag_from_slot = -1
				_drag_position = pos
			return

	# 从炼成槽开始拖拽
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos):
			if _ingredient_slots[i] >= 0:
				_is_dragging = true
				_drag_note = _ingredient_slots[i]
				_drag_from_slot = i
				_drag_position = pos
			return

func _on_left_release(pos: Vector2) -> void:
	if not _is_dragging:
		return

	# 检查是否放入炼成槽
	var dropped := false
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos):
			if _drag_from_slot >= 0:
				# 从一个槽位移到另一个
				_move_between_slots(_drag_from_slot, i)
			else:
				# 从库存放入槽位
				_place_note_in_slot(i, _drag_note)
			dropped = true
			break

	# 如果从炼成槽拖出但没有放到有效位置，返回库存
	if not dropped and _drag_from_slot >= 0:
		_remove_note_from_slot(_drag_from_slot)

	_is_dragging = false
	_drag_note = -1
	_drag_from_slot = -1
	_update_preview()

func _on_right_press(pos: Vector2) -> void:
	# 右键点击炼成槽：移除音符返回库存
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos):
			if _ingredient_slots[i] >= 0:
				_remove_note_from_slot(i)
				_update_preview()
			return

# ============================================================
# 炼成槽操作
# ============================================================

## 将音符放入炼成槽
func _place_note_in_slot(slot_idx: int, note_key: int) -> void:
	if slot_idx < 0 or slot_idx >= MAX_INGREDIENT_SLOTS:
		return

	# 如果槽位已有音符，先移除
	if _ingredient_slots[slot_idx] >= 0:
		_remove_note_from_slot(slot_idx)

	# 从库存扣除
	if not NoteInventory.equip_note(note_key):
		return  # 库存不足

	_ingredient_slots[slot_idx] = note_key
	_update_preview()

## 从炼成槽移除音符，返回库存
func _remove_note_from_slot(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= MAX_INGREDIENT_SLOTS:
		return
	if _ingredient_slots[slot_idx] < 0:
		return

	NoteInventory.unequip_note(_ingredient_slots[slot_idx])
	_ingredient_slots[slot_idx] = -1
	_update_preview()

## 在两个槽位之间移动音符
func _move_between_slots(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx:
		return
	if from_idx < 0 or from_idx >= MAX_INGREDIENT_SLOTS:
		return
	if to_idx < 0 or to_idx >= MAX_INGREDIENT_SLOTS:
		return

	var temp := _ingredient_slots[to_idx]
	_ingredient_slots[to_idx] = _ingredient_slots[from_idx]
	_ingredient_slots[from_idx] = temp
	_update_preview()

# ============================================================
# 和弦识别与预览
# ============================================================

## 更新和弦预览
func _update_preview() -> void:
	var notes: Array[int] = []
	for note_key in _ingredient_slots:
		if note_key >= 0:
			notes.append(note_key)

	if notes.size() < MIN_NOTES_FOR_CHORD:
		_preview_chord = {}
		_can_synthesize = false
		return

	# 将 WhiteKey 转换为半音值并计算音程
	var semitones: Array[int] = []
	for note_key in notes:
		var semitone: int = _white_key_to_semitone(note_key)
		semitones.append(semitone)

	# 排序并计算相对音程
	semitones.sort()
	var root := semitones[0]
	var intervals: Array[int] = []
	for s in semitones:
		intervals.append((s - root) % 12)
	intervals.sort()

	# 去重
	var unique_intervals: Array[int] = []
	for iv in intervals:
		if iv not in unique_intervals:
			unique_intervals.append(iv)

	# 查找匹配的和弦模式
	var pattern_key := ",".join(unique_intervals.map(func(x): return str(x)))

	if CHORD_PATTERNS.has(pattern_key):
		_preview_chord = CHORD_PATTERNS[pattern_key].duplicate()
		_preview_chord["intervals"] = unique_intervals
		_preview_chord["root_note"] = notes[0]  # 第一个放入的音符作为根音
		_can_synthesize = true
	else:
		# 未知和弦类型
		_preview_chord = {
			"name": "Unknown Chord (%s)" % pattern_key,
			"spell_form": "generic_blast",
			"desc": "Unrecognized chord pattern — generic blast spell",
			"intervals": unique_intervals,
			"root_note": notes[0],
		}
		_can_synthesize = true  # 仍然允许合成未知和弦

## 白键 → 半音值
func _white_key_to_semitone(white_key: int) -> int:
	# C=0, D=2, E=4, F=5, G=7, A=9, B=11
	const SEMITONE_MAP := [0, 2, 4, 5, 7, 9, 11]
	if white_key >= 0 and white_key < SEMITONE_MAP.size():
		return SEMITONE_MAP[white_key]
	return 0

# ============================================================
# 合成执行
# ============================================================

## 执行和弦合成
func _execute_synthesis() -> void:
	if not _can_synthesize or _preview_chord.is_empty():
		return

	# 收集炼成槽中的音符
	var consumed_notes: Array[int] = []
	for note_key in _ingredient_slots:
		if note_key >= 0:
			consumed_notes.append(note_key)

	if consumed_notes.size() < MIN_NOTES_FOR_CHORD:
		return

	# 生成 MIDI 音符数组（用于和弦法术的实际效果）
	var chord_midi_notes: Array[int] = []
	for note_key in consumed_notes:
		chord_midi_notes.append(60 + _white_key_to_semitone(note_key))

	# 添加和弦法术到法术书
	var spell := NoteInventory.add_chord_spell(
		_get_chord_type_enum(),
		chord_midi_notes,
		consumed_notes[0],
		_preview_chord.get("spell_form", "generic_blast"),
		_preview_chord.get("name", "Unknown Chord")
	)

	# 清空炼成槽（音符已在 equip_note 时扣除，不需要再次扣除）
	# 但需要标记为"永久消耗"而非"卸下"
	# 由于放入炼成槽时已经从库存扣除了，这里直接清空槽位即可
	for i in range(MAX_INGREDIENT_SLOTS):
		_ingredient_slots[i] = -1

	_preview_chord = {}
	_can_synthesize = false

	alchemy_completed.emit(spell)

## 获取和弦类型枚举值
func _get_chord_type_enum() -> int:
	var name: String = _preview_chord.get("name", "")
	if "大三" in name:
		return 0  # MusicData.ChordType.MAJOR_TRIAD
	elif "小三" in name:
		return 1  # MusicData.ChordType.MINOR_TRIAD
	elif "减三" in name:
		return 2  # MusicData.ChordType.DIMINISHED_TRIAD
	elif "增三" in name:
		return 3  # MusicData.ChordType.AUGMENTED_TRIAD
	elif "大七" in name:
		return 4  # MusicData.ChordType.MAJOR_SEVENTH
	elif "属七" in name:
		return 5  # MusicData.ChordType.DOMINANT_SEVENTH
	elif "小七" in name:
		return 6  # MusicData.ChordType.MINOR_SEVENTH
	elif "减七" in name:
		return 7  # MusicData.ChordType.DIMINISHED_SEVENTH
	elif "半减七" in name:
		return 8  # MusicData.ChordType.HALF_DIMINISHED
	elif "挂四" in name:
		return 9  # MusicData.ChordType.SUS4
	elif "挂二" in name:
		return 10  # MusicData.ChordType.SUS2
	return 0

# ============================================================
# 快捷键
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_V:
			if _is_visible:
				hide_panel()
			else:
				show_panel()
			get_viewport().set_input_as_handled()
			return
	if not _is_visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide_panel()
			get_viewport().set_input_as_handled()
