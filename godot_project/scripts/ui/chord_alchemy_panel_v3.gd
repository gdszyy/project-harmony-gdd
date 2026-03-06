## chord_alchemy_panel_v3.gd
## v3.0 和弦炼成区 (Chord Alchemy Panel)
##
## 位于一体化编曲台右侧上半部分，功能包括：
##   - 6个原材料槽（最少3个音符才能炼成）
##   - 实时和弦识别与预览
##   - 炼成按钮（配方有效时高亮）
##   - 拖拽放入/移出音符
##   - 炼成成功/失败的视觉反馈
##
## 使用 Godot 内置拖拽 API
## 与 NoteInventory 全局单例对接
extends Control

# ============================================================
# 信号
# ============================================================
## 炼成完成时触发
signal alchemy_completed(chord_spell: Dictionary)
## 信息悬停（供主面板信息栏使用）
signal info_hover(title: String, desc: String, color: Color)

# ============================================================
# 常量
# ============================================================
## 炼成槽配置 — @export 支持编辑器实时调整
@export_group("Alchemy Slots")
@export var max_slots: int = 6
@export var min_notes_for_chord: int = 3
@export var slot_size: Vector2 = Vector2(48, 48)
@export var slot_gap: float = 8.0

## 颜色定义
static var SLOT_EMPTY_BG := UIColors.with_alpha(UIColors.PANEL_BG, 0.63)
var SLOT_FILLED_BG: Color = UIColors.with_alpha(UIColors.PANEL_BG, 0.82)
static var SLOT_HOVER_BG := UIColors.with_alpha(UIColors.ACCENT, 0.19)
static var SLOT_DROP_HIGHLIGHT := UIColors.with_alpha(UIColors.ACCENT_2, 0.40)
static var SLOT_BORDER := UIColors.with_alpha(UIColors.ACCENT, 0.25)
static var SLOT_REQUIRED_MARK := UIColors.with_alpha(UIColors.OFFENSE, 0.38)

static var SYNTH_BTN_VALID := UIColors.with_alpha(UIColors.ACCENT_2, 0.80)
static var SYNTH_BTN_INVALID := UIColors.with_alpha(UIColors.ACCENT, 0.25)
static var SYNTH_BTN_HOVER := UIColors.with_alpha(UIColors.ACCENT_2, 1.00)
var SYNTH_BTN_TEXT_VALID := Color.WHITE
static var SYNTH_BTN_TEXT_INVALID := UIColors.with_alpha(UIColors.TEXT_HINT, 0.50)

const PREVIEW_VALID_COLOR := UIColors.ACCENT_2
const PREVIEW_INVALID_COLOR := UIColors.OFFENSE

## 音符颜色（白键）

## 黑键音符颜色（用于和弦构成音模式）

## 黑键音符名称
const BLACK_KEY_NAMES := {
	7: "C#",
	8: "Eb",
	9: "F#",
	10: "Ab",
	11: "Bb",
}

## 黑键索引到半音的映射（索引 7-11 对应 5 个黑键）
const BLACK_KEY_SEMITONE_MAP := {
	7: 1,   # C#/Db
	8: 3,   # D#/Eb
	9: 6,   # F#/Gb
	10: 8,  # G#/Ab
	11: 10, # A#/Bb
}

## 和弦类型识别表 — 从 JSON 配置文件加载
const CHORD_PATTERNS_PATH := "res://data/upgrades/chord_patterns.json"
var CHORD_PATTERNS: Dictionary = {}

func _load_chord_patterns() -> void:
	var file := FileAccess.open(CHORD_PATTERNS_PATH, FileAccess.READ)
	if file == null:
		push_error("ChordAlchemyPanelV3: 无法加载和弦配方数据: %s" % CHORD_PATTERNS_PATH)
		CHORD_PATTERNS = _CHORD_PATTERNS_LEGACY.duplicate(true)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("ChordAlchemyPanelV3: JSON 解析失败: %s" % json.get_error_message())
		CHORD_PATTERNS = _CHORD_PATTERNS_LEGACY.duplicate(true)
		return
	CHORD_PATTERNS = json.data

# 以下为原始硬编码数据的备份引用（已迁移至 data/upgrades/chord_patterns.json）
const _CHORD_PATTERNS_LEGACY := {
	# === 基础三和弦 (3音) ===
	"0,4,7": { "name": "大三和弦", "spell_form": "enhanced_projectile", "desc": "强化弹体：弹体体积+50%，伤害+40%", "icon": "▲" },
	"0,3,7": { "name": "小三和弦", "spell_form": "dot_projectile", "desc": "DOT弹体：命中后持续伤害", "icon": "💧" },
	"0,3,6": { "name": "减三和弦", "spell_form": "shockwave", "desc": "冲击波：环形扩散后内爆", "icon": "◎" },
	"0,4,8": { "name": "增三和弦", "spell_form": "explosive_projectile", "desc": "爆炸弹体：命中时范围爆炸", "icon": "✦" },
	"0,5,7": { "name": "挂四和弦", "spell_form": "charged_projectile", "desc": "蓄力弹体：延迟释放", "icon": "⌛" },
	"0,2,7": { "name": "挂二和弦", "spell_form": "charged_projectile", "desc": "蓄力弹体：延迟释放", "icon": "⌛" },
	# === 七和弦 (4音) ===
	"0,4,7,11": { "name": "大七和弦", "spell_form": "shield_heal", "desc": "护盾/治疗法阵：恢复生命值", "icon": "✚" },
	"0,4,7,10": { "name": "属七和弦", "spell_form": "magic_circle", "desc": "法阵/区域：旋转法阵持续存在", "icon": "◉" },
	"0,3,7,10": { "name": "小七和弦", "spell_form": "summon_construct", "desc": "召唤/构造：水晶构造体", "icon": "▣" },
	"0,3,6,9": { "name": "减七和弦", "spell_form": "celestial_strike", "desc": "天降打击：延迟后毁灭性打击", "icon": "⚡" },
	"0,3,6,10": { "name": "半减七和弦", "spell_form": "slow_field", "desc": "迟缓领域：大范围减速", "icon": "◐" },
	"0,4,8,11": { "name": "增大七和弦", "spell_form": "augmented_burst", "desc": "增幅爆发：爆炸弹体+护盾效果，2.2x伤害", "icon": "☆" },
	# === 扩展和弦 (5-7音) — 需要传说级升级解锁 ===
	"0,2,4,7,10": { "name": "属九和弦", "spell_form": "storm_field", "desc": "风暴区域：区域内敌人减速30%，持续AOE", "icon": "🌀", "extended": true },
	"0,2,4,7,11": { "name": "大九和弦", "spell_form": "holy_domain", "desc": "圣光领域：领域内持续回血(2/秒)，净化负面", "icon": "✦", "extended": true },
	"0,1,3,6,9": { "name": "减九和弦", "spell_form": "annihilation_ray", "desc": "湮灭射线：直线贯穿，无视防御，4.0x伤害", "icon": "⚔", "extended": true },
	"0,2,4,5,7,10": { "name": "属十一和弦", "spell_form": "time_rift", "desc": "时空裂隙：区域内时间减速50%", "icon": "⏳", "extended": true },
	"0,2,4,5,7,9,10": { "name": "属十三和弦", "spell_form": "symphony_storm", "desc": "交响风暴：全屏持续AOE，附加随机元素效果", "icon": "🎵", "extended": true },
	"0,1,3,4,6,9": { "name": "减十三和弦", "spell_form": "finale", "desc": "终焉乐章：延迟后全屏毁灭打击，自损20%HP", "icon": "💀", "extended": true },
}

## 法术形态颜色
const SPELL_FORM_COLORS: Dictionary = UIColors.FORM_COLORS
## 黑键音符颜色（索引 7-11 对应 5 个黑键，映射到 UIColors.BLACK_KEY_COLORS 的 0-4）
const BLACK_KEY_COLORS: Dictionary = {
	7: UIColors.BLACK_KEY_COLORS[0],  # C#
	8: UIColors.BLACK_KEY_COLORS[1],  # D#/Eb
	9: UIColors.BLACK_KEY_COLORS[2],  # F#
	10: UIColors.BLACK_KEY_COLORS[3], # G#/Ab
	11: UIColors.BLACK_KEY_COLORS[4], # A#/Bb
}
## 最少音符数（与 @export var min_notes_for_chord 保持同步）
const MIN_NOTES_FOR_CHORD: int = 3

## 白键到半音的映射
const SEMITONE_MAP := [0, 2, 4, 5, 7, 9, 11]  # C D E F G A B

## 统一的音符索引到半音映射（支持白键 0-6 和黑键 7-11）
static func note_index_to_semitone(note_idx: int) -> int:
	if note_idx >= 0 and note_idx < SEMITONE_MAP.size():
		return SEMITONE_MAP[note_idx]  # 白键
	elif BLACK_KEY_SEMITONE_MAP.has(note_idx):
		return BLACK_KEY_SEMITONE_MAP[note_idx]  # 黑键
	else:
		return note_idx  # 回退

## 获取音符名称（白键或黑键）
static func get_note_display_name(note_idx: int) -> String:
	if note_idx >= 0 and note_idx < 7:
		return MusicData.WHITE_KEY_STATS.get(note_idx, {}).get("name", "?")
	elif BLACK_KEY_NAMES.has(note_idx):
		return BLACK_KEY_NAMES[note_idx]
	else:
		return "?"

## 获取音符颜色（白键或黑键）
static func get_note_color(note_idx: int) -> Color:
	if (note_idx >= 0 and note_idx < 7):
		return UIColors.get_note_color_by_int(note_idx)
	elif BLACK_KEY_COLORS.has(note_idx):
		return UIColors.get_black_key_color(note_idx)
	else:
		return UIColors.TEXT_DIM

# ============================================================
# 状态
# ============================================================
## 炼成槽内容（-1 表示空）
var _slots: Array[int] = []
## 炼成槽矩形缓存
var _slot_rects: Array[Rect2] = []
## 合成按钮矩形
var _synth_btn_rect: Rect2 = Rect2()
## 和弦预览数据
var _preview: Dictionary = {}
## 是否可以炼成
var _can_craft: bool = false
## 悬停状态
var _hover_slot: int = -1
var _hover_synth_btn: bool = false
## 拖拽放置悬停
var _drop_hover_slot: int = -1
## 炼成动画
var _craft_flash: float = 0.0
var _craft_success: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_load_chord_patterns()
	## 初始化炼成槽
	_slots.clear()
	for i in range(max_slots):
		_slots.append(-1)

	## 计算最小尺寸
	var slots_w := max_slots * (slot_size.x + slot_gap)
	var total_h := 20 + slot_size.y + 20 + 30 + 30 + 10  # 标题 + 槽 + 预览 + 按钮 + 留白
	custom_minimum_size = Vector2(slots_w + 20, total_h)

	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if _craft_flash > 0:
		_craft_flash -= delta * 3.0
		queue_redraw()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var font := ThemeDB.fallback_font
	_slot_rects.clear()

	var x := 10.0
	var y := 4.0

	## ===== 标题 =====
	draw_string(font, Vector2(x, y + 12), "CHORD ALCHEMY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIColors.TEXT_HINT)
	y += 20.0

	## ===== 和弦预览 =====
	if not _preview.is_empty():
		var chord_name: String = _preview.get("name", "???")
		var spell_form: String = _preview.get("spell_form", "")
		var form_color: Color = SPELL_FORM_COLORS.get(spell_form, Color.WHITE)
		var icon: String = _preview.get("icon", "")
		draw_string(font, Vector2(x, y + 12),
			"%s %s" % [icon, chord_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, form_color)
		var desc: String = _preview.get("desc", "")
		draw_string(font, Vector2(x, y + 24),
			desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIColors.with_alpha(form_color, 0.7))
	elif _get_filled_count() >= MIN_NOTES_FOR_CHORD:
		draw_string(font, Vector2(x, y + 12),
			"不和谐组合", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, PREVIEW_INVALID_COLOR)
	else:
		var needed := min_notes_for_chord - _get_filled_count()
		draw_string(font, Vector2(x, y + 12),
			"还需 %d 个音符..." % needed, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIColors.with_alpha(UIColors.TEXT_HINT, 0.50))
	y += 30.0

	## ===== 炼成槽 =====
	var slots_start_x := x
	for i in range(max_slots):
		var slot_x := slots_start_x + i * (slot_size.x + slot_gap)
		var rect := Rect2(Vector2(slot_x, y), slot_size)
		_slot_rects.append(rect)

		var is_filled: bool = _slots[i] >= 0
		var is_hover := (_hover_slot == i)
		var is_drop_hover := (_drop_hover_slot == i)

		## 背景色
		var bg := SLOT_EMPTY_BG
		if is_filled:
			bg = SLOT_FILLED_BG
		if is_hover:
			bg = SLOT_HOVER_BG
		if is_drop_hover:
			bg = SLOT_DROP_HIGHLIGHT

		## 炼成成功闪烁
		if _craft_flash > 0 and _craft_success:
			bg = bg.lerp(UIColors.with_alpha(UIColors.ACCENT_2, 0.25), _craft_flash)
		elif _craft_flash > 0 and not _craft_success:
			bg = bg.lerp(UIColors.with_alpha(UIColors.OFFENSE, 0.25), _craft_flash)

		draw_rect(rect, bg)

		## 边框
		var border := SLOT_BORDER
		if is_filled:
			var note_color: Color = get_note_color(_slots[i])
			border = UIColors.with_alpha(note_color, 0.7)
		if is_drop_hover:
			border = UIColors.with_alpha(UIColors.ACCENT_2, 0.80)
		draw_rect(rect, border, false, 1.0)

		## 内容
		if is_filled:
			var note_key: int = _slots[i]
			var note_color: Color = get_note_color(note_key)
			## 色块背景
			draw_rect(rect.grow(-3), UIColors.with_alpha(note_color, 0.25))
			## 音符名称（支持白键和黑键）
			var name_str: String = get_note_display_name(note_key)
			draw_string(font,
				rect.position + Vector2(rect.size.x / 2.0 - 6, rect.size.y / 2.0 + 5),
				name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, note_color)
		else:
			## 必需标记（前3个槽位）
			if i < min_notes_for_chord:
				draw_string(font,
					rect.position + Vector2(rect.size.x / 2.0 - 2, rect.size.y / 2.0 + 4),
					"*", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, SLOT_REQUIRED_MARK)

	y += slot_size.y + 12.0

	## ===== 合成按钮 =====
	var btn_w := max_slots * (slot_size.x + slot_gap) - slot_gap
	_synth_btn_rect = Rect2(Vector2(slots_start_x, y), Vector2(btn_w, 28))

	var btn_color := SYNTH_BTN_VALID if _can_craft else SYNTH_BTN_INVALID
	if _hover_synth_btn and _can_craft:
		btn_color = SYNTH_BTN_HOVER
	draw_rect(_synth_btn_rect, btn_color)
	draw_rect(_synth_btn_rect, SLOT_BORDER, false, 1.0)

	var btn_text := "✦ 炼成 SYNTHESIZE" if _can_craft else "需要 %d+ 个有效音符" % min_notes_for_chord
	var btn_text_color := SYNTH_BTN_TEXT_VALID if _can_craft else SYNTH_BTN_TEXT_INVALID
	draw_string(font,
		_synth_btn_rect.position + Vector2(_synth_btn_rect.size.x / 2.0 - 50, 19),
		btn_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, btn_text_color)

# ============================================================
# 鼠标交互
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			## 点击合成按钮
			if _synth_btn_rect.has_point(event.position) and _can_craft:
				_execute_alchemy()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			## 右键移除炼成槽中的音符
			for i in range(_slot_rects.size()):
				if _slot_rects[i].has_point(event.position) and _slots[i] >= 0:
					_remove_from_slot(i)
					break

## 更新悬停状态
func _update_hover(pos: Vector2) -> void:
	_hover_slot = -1
	_hover_synth_btn = false

	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos):
			_hover_slot = i
			_emit_slot_info(i)
			queue_redraw()
			return

	if _synth_btn_rect.has_point(pos):
		_hover_synth_btn = true
		if _can_craft:
			info_hover.emit("炼成", "点击将音符炼成和弦法术（音符将被永久消耗）", PREVIEW_VALID_COLOR)
		else:
			info_hover.emit("炼成", "需要至少 %d 个音符且组合有效" % MIN_NOTES_FOR_CHORD, UIColors.TEXT_HINT)
		queue_redraw()

## 发送槽位信息
func _emit_slot_info(idx: int) -> void:
	if _slots[idx] >= 0:
		var note_key: int = _slots[idx]
		var name_str: String = get_note_display_name(note_key)
		var color: Color = get_note_color(note_key)
		var key_type := "黑键" if note_key >= 7 else "白键"
		info_hover.emit(
			"%s %s音符（炼成槽 %d）" % [name_str, key_type, idx + 1],
			"右键移除 | 可拖出到其他位置",
			color
		)
	else:
		var label := "必需" if idx < min_notes_for_chord else "可选"
		info_hover.emit(
			"炼成槽 %d（%s）" % [idx + 1, label],
			"拖入音符作为和弦原材料",
			UIColors.TEXT_HINT
		)

# ============================================================
# Godot 内置拖拽 API
# ============================================================

## 从炼成槽拖出音符
func _get_drag_data(at_position: Vector2) -> Variant:
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(at_position) and _slots[i] >= 0:
			var note_key: int = _slots[i]
			var name_str: String = get_note_display_name(note_key)
			var color: Color = get_note_color(note_key)

			## 从炼成槽移除并归还库存
			NoteInventory.unequip_note(note_key)
			_slots[i] = -1
			_update_preview()
			queue_redraw()

			## 创建拖拽预览
			var preview := _create_drag_preview(name_str, color)
			set_drag_preview(preview)

			return {
				"type": "note",
				"note_key": note_key,
				"source": "alchemy",
				"source_idx": i,
			}
	return null

## 判断是否可以接受拖拽放置
## 支持白键音符和黑键音符
func _can_drop_data(at_position: Vector2, data) -> bool:
	if data == null or not data is Dictionary:
		_drop_hover_slot = -1
		return false

	var drag_type: String = data.get("type", "")
	# 支持白键 "note" 和黑键 "black_key_note" 两种拖拽类型
	if drag_type != "note" and drag_type != "black_key_note":
		_drop_hover_slot = -1
		return false

	## 查找目标槽位
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(at_position):
			_drop_hover_slot = i
			queue_redraw()
			return true

	_drop_hover_slot = -1
	return false

## 处理拖拽放置
## 支持白键音符和黑键音符
func _drop_data(at_position: Vector2, data) -> void:
	_drop_hover_slot = -1

	if data == null or not data is Dictionary:
		return

	var drag_type: String = data.get("type", "")
	# 支持白键 "note" 和黑键 "black_key_note" 两种拖拽类型
	if drag_type != "note" and drag_type != "black_key_note":
		return

	var note_key: int = data.get("note_key", -1)
	if note_key < 0:
		return

	## 查找目标槽位
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(at_position):
			_place_in_slot(i, note_key)
			break

	queue_redraw()

# ============================================================
# 炼成操作
# ============================================================

## 放置音符到炼成槽
func _place_in_slot(slot_idx: int, note_key: int) -> void:
	## 如果该槽位已有音符，先归还
	if _slots[slot_idx] >= 0:
		NoteInventory.unequip_note(_slots[slot_idx])

	## 从库存装备新音符
	if not NoteInventory.equip_note(note_key):
		return  # 库存不足

	_slots[slot_idx] = note_key
	_update_preview()

## 从炼成槽移除音符（右键）
func _remove_from_slot(slot_idx: int) -> void:
	if _slots[slot_idx] >= 0:
		NoteInventory.unequip_note(_slots[slot_idx])
		_slots[slot_idx] = -1
		_update_preview()
		queue_redraw()

## 更新和弦预览
## 支持白键（0-6）和黑键（7-11）的统一音程计算
func _update_preview() -> void:
	var notes: Array[int] = []
	for slot in _slots:
		if slot >= 0:
			notes.append(slot)

	_preview = {}
	_can_craft = false

	if notes.size() < min_notes_for_chord:
		queue_redraw()
		return

	## 计算半音音程模式（支持白键和黑键）
	var midi_notes: Array[int] = []
	for n in notes:
		midi_notes.append(note_index_to_semitone(n))
	midi_notes.sort()

	## 去重
	var unique_notes: Array[int] = []
	for n in midi_notes:
		if not unique_notes.has(n):
			unique_notes.append(n)

	if unique_notes.size() < min_notes_for_chord:
		queue_redraw()
		return

	## 尝试每个音作为根音，匹配最佳和弦模式
	var best_pattern: Dictionary = {}
	var best_note_count: int = 0

	for root_idx in range(unique_notes.size()):
		var root: int = unique_notes[root_idx]
		var intervals: Array[int] = []
		for i in range(unique_notes.size()):
			var interval: int = (unique_notes[(root_idx + i) % unique_notes.size()] - root + 12) % 12
			intervals.append(interval)
		intervals.sort()

		var pattern_key := ",".join(intervals.map(func(val): return str(val)))

		if CHORD_PATTERNS.has(pattern_key):
			var pattern_data: Dictionary = CHORD_PATTERNS[pattern_key]
			## 优先匹配音数更多的和弦（扩展和弦优先）
			var note_count: int = intervals.size()
			if note_count > best_note_count:
				best_note_count = note_count
				best_pattern = pattern_data.duplicate()

	if not best_pattern.is_empty():
		## 检查扩展和弦是否已解锁
		if best_pattern.get("extended", false) and not GameManager.extended_chords_unlocked:
			_preview = { "name": best_pattern["name"] + " (未解锁)", "desc": "需要传说级升级“扩展和弦解锁”", "icon": "🔒" }
			_can_craft = false
		else:
			_preview = best_pattern
			_can_craft = true

	queue_redraw()

## 执行炼成
func _execute_alchemy() -> void:
	if not _can_craft or _preview.is_empty():
		## 炼成失败动画
		_craft_flash = 1.0
		_craft_success = false
		return

	## 收集炼成槽中的音符
	var notes_to_consume: Array = []
	for slot in _slots:
		if slot >= 0:
			notes_to_consume.append(slot)

	## 确定根音和法术信息
	var root_note: int = notes_to_consume[0]
	var spell_form: String = _preview.get("spell_form", "generic_blast")
	var root_name: String = get_note_display_name(root_note)
	var spell_name: String = "%s %s" % [
		root_name,
		_preview.get("name", "Unknown")
	]

	## 添加到法术书（音符已在放入炼成槽时从库存扣除，此处直接消耗）
	var chord_spell := NoteInventory.add_chord_spell(
		0,  # chord_type placeholder
		notes_to_consume,
		root_note,
		spell_form,
		spell_name
	)

	## 清空炼成槽（音符已消耗，不返回库存）
	for i in range(max_slots):
		_slots[i] = -1
	_preview = {}
	_can_craft = false

	## 炼成成功动画
	_craft_flash = 1.0
	_craft_success = true

	## 发送信号
	alchemy_completed.emit(chord_spell)

## 归还未使用的音符到库存（关闭面板时调用）
func return_unused_notes() -> void:
	for i in range(max_slots):
		if _slots[i] >= 0:
			NoteInventory.unequip_note(_slots[i])
			_slots[i] = -1
	_preview = {}
	_can_craft = false

## 获取已填充的槽位数量
func _get_filled_count() -> int:
	var count := 0
	for slot in _slots:
		if slot >= 0:
			count += 1
	return count

## 刷新面板
func refresh() -> void:
	_update_preview()
	queue_redraw()

# ============================================================
# 工具方法
# ============================================================

## 创建拖拽预览控件
func _create_drag_preview(text: String, color: Color) -> Control:
	var preview := Control.new()
	var sz := slot_size
	preview.custom_minimum_size = sz
	preview.size = sz

	var panel := Panel.new()
	panel.custom_minimum_size = sz
	panel.size = sz

	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.with_alpha(color, 0.5)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = UIColors.with_alpha(color, 0.6)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = sz
	label.size = sz
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 16)

	preview.add_child(panel)
	preview.add_child(label)
	return preview
