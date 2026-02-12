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
## 炼成槽配置
const MAX_SLOTS: int = 6
const MIN_NOTES_FOR_CHORD: int = 3
const SLOT_SIZE := Vector2(48, 48)
const SLOT_GAP := 8.0

## 颜色定义
const SLOT_EMPTY_BG := Color("141026A0")
const SLOT_FILLED_BG := Color("1A1433D0")
const SLOT_HOVER_BG := Color("9D6FFF30")
const SLOT_DROP_HIGHLIGHT := Color("00FFD466")
const SLOT_BORDER := Color("9D6FFF40")
const SLOT_REQUIRED_MARK := Color("FF444460")

const SYNTH_BTN_VALID := Color("00FFD4CC")
const SYNTH_BTN_INVALID := Color("9D6FFF40")
const SYNTH_BTN_HOVER := Color("00FFD4FF")
const SYNTH_BTN_TEXT_VALID := Color("FFFFFF")
const SYNTH_BTN_TEXT_INVALID := Color("9D8FBF80")

const PREVIEW_VALID_COLOR := Color("00FFD4")
const PREVIEW_INVALID_COLOR := Color("FF4444")
const SECTION_TITLE_COLOR := Color("9D8FBF")

## 音符颜色（白键）
const NOTE_COLORS := {
	0: Color("00FFD4"), 1: Color("0088FF"), 2: Color("66FF66"),
	3: Color("8844FF"), 4: Color("FF4444"), 5: Color("FF8800"),
	6: Color("FF44AA"),
}

## 黑键音符颜色（用于和弦构成音模式）
const BLACK_KEY_COLORS := {
	7: Color("00BBAA"),   # C#/Db
	8: Color("0066CC"),   # D#/Eb
	9: Color("44BB44"),   # F#/Gb
	10: Color("6622CC"),  # G#/Ab
	11: Color("CC6600"),  # A#/Bb
}

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

## 和弦类型识别表（半音音程模式 → 和弦信息）
## 包含基础和弦（3-4音）和扩展和弦（5-7音）
const CHORD_PATTERNS := {
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
const SPELL_FORM_COLORS := {
	# 基础和弦法术形态
	"enhanced_projectile": Color("FFD94D"),
	"dot_projectile": Color("3366CC"),
	"explosive_projectile": Color("FF6633"),
	"shockwave": Color("8822BB"),
	"magic_circle": Color("FFCC00"),
	"celestial_strike": Color("CC1111"),
	"shield_heal": Color("33E666"),
	"summon_construct": Color("2233BB"),
	"charged_projectile": Color("D9D9F2"),
	"slow_field": Color("4D4DBB"),
	"augmented_burst": Color("FF9933"),
	"generic_blast": Color("808080"),
	# 扩展和弦法术形态
	"storm_field": Color("4488FF"),
	"holy_domain": Color("FFE066"),
	"annihilation_ray": Color("FF0044"),
	"time_rift": Color("AA00FF"),
	"symphony_storm": Color("00CCFF"),
	"finale": Color("FF2200"),
}

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
	if NOTE_COLORS.has(note_idx):
		return NOTE_COLORS[note_idx]
	elif BLACK_KEY_COLORS.has(note_idx):
		return BLACK_KEY_COLORS[note_idx]
	else:
		return Color(0.5, 0.5, 0.5)

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
	## 初始化炼成槽
	_slots.clear()
	for i in range(MAX_SLOTS):
		_slots.append(-1)

	## 计算最小尺寸
	var slots_w := MAX_SLOTS * (SLOT_SIZE.x + SLOT_GAP)
	var total_h := 20 + SLOT_SIZE.y + 20 + 30 + 30 + 10  # 标题 + 槽 + 预览 + 按钮 + 留白
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
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SECTION_TITLE_COLOR)
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
			desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(form_color.r, form_color.g, form_color.b, 0.7))
	elif _get_filled_count() >= MIN_NOTES_FOR_CHORD:
		draw_string(font, Vector2(x, y + 12),
			"不和谐组合", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, PREVIEW_INVALID_COLOR)
	else:
		var needed := MIN_NOTES_FOR_CHORD - _get_filled_count()
		draw_string(font, Vector2(x, y + 12),
			"还需 %d 个音符..." % needed, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("9D8FBF80"))
	y += 30.0

	## ===== 炼成槽 =====
	var slots_start_x := x
	for i in range(MAX_SLOTS):
		var slot_x := slots_start_x + i * (SLOT_SIZE.x + SLOT_GAP)
		var rect := Rect2(Vector2(slot_x, y), SLOT_SIZE)
		_slot_rects.append(rect)

		var is_filled := _slots[i] >= 0
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
			bg = bg.lerp(Color("00FFD440"), _craft_flash)
		elif _craft_flash > 0 and not _craft_success:
			bg = bg.lerp(Color("FF444440"), _craft_flash)

		draw_rect(rect, bg)

		## 边框
		var border := SLOT_BORDER
		if is_filled:
			var note_color: Color = get_note_color(_slots[i])
			border = Color(note_color.r, note_color.g, note_color.b, 0.7)
		if is_drop_hover:
			border = Color("00FFD4CC")
		draw_rect(rect, border, false, 1.0)

		## 内容
		if is_filled:
			var note_key := _slots[i]
			var note_color: Color = get_note_color(note_key)
			## 色块背景
			draw_rect(rect.grow(-3), Color(note_color.r, note_color.g, note_color.b, 0.25))
			## 音符名称（支持白键和黑键）
			var name_str: String = get_note_display_name(note_key)
			draw_string(font,
				rect.position + Vector2(rect.size.x / 2.0 - 6, rect.size.y / 2.0 + 5),
				name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, note_color)
		else:
			## 必需标记（前3个槽位）
			if i < MIN_NOTES_FOR_CHORD:
				draw_string(font,
					rect.position + Vector2(rect.size.x / 2.0 - 2, rect.size.y / 2.0 + 4),
					"*", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, SLOT_REQUIRED_MARK)

	y += SLOT_SIZE.y + 12.0

	## ===== 合成按钮 =====
	var btn_w := MAX_SLOTS * (SLOT_SIZE.x + SLOT_GAP) - SLOT_GAP
	_synth_btn_rect = Rect2(Vector2(slots_start_x, y), Vector2(btn_w, 28))

	var btn_color := SYNTH_BTN_VALID if _can_craft else SYNTH_BTN_INVALID
	if _hover_synth_btn and _can_craft:
		btn_color = SYNTH_BTN_HOVER
	draw_rect(_synth_btn_rect, btn_color)
	draw_rect(_synth_btn_rect, SLOT_BORDER, false, 1.0)

	var btn_text := "✦ 炼成 SYNTHESIZE" if _can_craft else "需要 %d+ 个有效音符" % MIN_NOTES_FOR_CHORD
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
			info_hover.emit("炼成", "需要至少 %d 个音符且组合有效" % MIN_NOTES_FOR_CHORD, Color("9D8FBF"))
		queue_redraw()

## 发送槽位信息
func _emit_slot_info(idx: int) -> void:
	if _slots[idx] >= 0:
		var note_key := _slots[idx]
		var name_str: String = get_note_display_name(note_key)
		var color: Color = get_note_color(note_key)
		var key_type := "黑键" if note_key >= 7 else "白键"
		info_hover.emit(
			"%s %s音符（炼成槽 %d）" % [name_str, key_type, idx + 1],
			"右键移除 | 可拖出到其他位置",
			color
		)
	else:
		var label := "必需" if idx < MIN_NOTES_FOR_CHORD else "可选"
		info_hover.emit(
			"炼成槽 %d（%s）" % [idx + 1, label],
			"拖入音符作为和弦原材料",
			Color("9D8FBF")
		)

# ============================================================
# Godot 内置拖拽 API
# ============================================================

## 从炼成槽拖出音符
func _get_drag_data(at_position: Vector2) -> Variant:
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(at_position) and _slots[i] >= 0:
			var note_key := _slots[i]
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

	if notes.size() < MIN_NOTES_FOR_CHORD:
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

	if unique_notes.size() < MIN_NOTES_FOR_CHORD:
		queue_redraw()
		return

	## 尝试每个音作为根音，匹配最佳和弦模式
	var best_pattern: Dictionary = {}
	var best_note_count: int = 0

	for root_idx in range(unique_notes.size()):
		var root := unique_notes[root_idx]
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
	for i in range(MAX_SLOTS):
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
	for i in range(MAX_SLOTS):
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
	var sz := SLOT_SIZE
	preview.custom_minimum_size = sz
	preview.size = sz

	var panel := Panel.new()
	panel.custom_minimum_size = sz
	panel.size = sz

	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.5)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(color.r, color.g, color.b, 0.6)
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
