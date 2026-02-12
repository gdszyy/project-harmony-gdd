## integrated_composer.gd
## v3.0 一体化编曲台 (Integrated Composer)
##
## 将原先分散在 chord_alchemy_panel / spellbook_ui / sequencer_ui / manual_slot_config
## 四个独立面板中的法术编辑流程，整合为一个统一的"编曲台"界面。
##
## 核心改进：
##   1. 情景式和弦创造 — 在序列器上直接拖拽音符，自动识别和弦并实时预览
##   2. 动态法术调色板 — 法术书作为侧边常驻面板，随时可拖入序列器/手动槽
##   3. 智能信息提示 — 悬停任何元素时在固定区域显示详细信息
##   4. 统一操作入口 — 一个面板完成所有法术编辑工作
##
## 布局结构 (自上而下)：
##   ┌─────────────────────────────────────────────────────────┐
##   │ [标题栏] 编曲台 COMPOSER  │ 模式指示 │ BPM │ 快捷键提示 │
##   ├──────────────────────┬──────────────────────────────────┤
##   │                      │                                  │
##   │  音符库存面板         │  4小节×4拍 序列器网格             │
##   │  (白键+黑键)         │  (支持拖拽放置/移除/交换)         │
##   │                      │                                  │
##   │  ──────────────      │  ──────────────────────────────  │
##   │                      │                                  │
##   │  法术书调色板         │  手动施法槽 [1] [2] [3]          │
##   │  (已合成和弦法术)     │                                  │
##   │                      │                                  │
##   ├──────────────────────┼──────────────────────────────────┤
##   │  [和弦炼成区]         │  [信息预览面板]                   │
##   │  拖入3+音符自动识别   │  悬停元素的详细信息               │
##   └──────────────────────┴──────────────────────────────────┘
##
extends Control

# ============================================================
# 信号
# ============================================================
signal note_placed(cell_idx: int, note: int)
signal cell_cleared(cell_idx: int)
signal chord_crafted(chord_spell: Dictionary)
signal alchemy_completed(chord_spell: Dictionary)  ## v3.0: 兼容别名，与 chord_crafted 同步触发
signal manual_slot_configured(slot_index: int, spell_data: Dictionary)
signal panel_toggled(is_open: bool)

# ============================================================
# 常量 — 布局
# ============================================================
## 面板整体
const PANEL_MARGIN := 12.0
const HEADER_HEIGHT := 32.0
const SECTION_GAP := 8.0

## 左侧面板 (库存 + 法术书 + 炼成)
const LEFT_PANEL_WIDTH := 220.0
const LEFT_PANEL_MIN_HEIGHT := 400.0

## 音符库存区
const INV_CELL_SIZE := Vector2(40, 40)
const INV_CELL_MARGIN := 4.0
const INV_SECTION_HEIGHT := 120.0
const INV_LABEL_HEIGHT := 18.0

## 法术书调色板区
const SPELL_CARD_HEIGHT := 48.0
const SPELL_CARD_MARGIN := 4.0
const SPELLBOOK_SECTION_HEIGHT := 160.0

## 和弦炼成区
const ALCHEMY_SLOT_SIZE := Vector2(44, 44)
const ALCHEMY_SLOT_MARGIN := 6.0
const ALCHEMY_SECTION_HEIGHT := 100.0
const MAX_ALCHEMY_SLOTS: int = 6
const MIN_NOTES_FOR_CHORD: int = 3

## 右侧面板 (序列器 + 手动槽 + 信息)
const SEQ_CELL_SIZE := Vector2(48, 48)
const SEQ_CELL_MARGIN := 4.0
const SEQ_MEASURE_GAP := 10.0
const BEATS_PER_MEASURE := 4
const MEASURES := 4
const TOTAL_CELLS := BEATS_PER_MEASURE * MEASURES

## 手动施法槽
const MANUAL_SLOT_SIZE := Vector2(56, 56)
const MANUAL_SLOT_MARGIN := 10.0
const MANUAL_SLOT_COUNT: int = 3
const MANUAL_SLOT_KEYS := ["1", "2", "3"]

## 信息预览面板
const INFO_PANEL_HEIGHT := 80.0

# ============================================================
# 常量 — 颜色
# ============================================================
const BG_COLOR := Color(0.03, 0.025, 0.06, 0.95)
const HEADER_BG := Color(0.05, 0.04, 0.1, 0.98)
const LEFT_BG := Color(0.04, 0.035, 0.08, 0.92)
const RIGHT_BG := Color(0.035, 0.03, 0.07, 0.90)
const SECTION_BORDER := Color(0.25, 0.2, 0.4, 0.4)
const SECTION_TITLE_COLOR := Color(0.6, 0.55, 0.75, 0.85)

const CELL_EMPTY := Color(0.08, 0.06, 0.14, 0.6)
const CELL_HOVER := Color(0.18, 0.15, 0.28, 0.5)
const CELL_FILLED := Color(0.1, 0.08, 0.18, 0.8)
const PLAYHEAD_COLOR := Color(1.0, 1.0, 1.0, 0.75)
const MEASURE_LINE := Color(0.3, 0.28, 0.4, 0.5)

const SLOT_EMPTY := Color(0.1, 0.08, 0.16, 0.6)
const SLOT_HOVER := Color(0.18, 0.15, 0.28, 0.7)
const SLOT_FILLED := Color(0.12, 0.1, 0.2, 0.85)
const SLOT_ACTIVE := Color(0.2, 0.15, 0.35, 0.9)

const ALCHEMY_EMPTY := Color(0.1, 0.08, 0.16, 0.7)
const ALCHEMY_FILLED := Color(0.12, 0.1, 0.2, 0.9)
const ALCHEMY_VALID := Color(0.1, 0.6, 0.4, 0.9)
const ALCHEMY_INVALID := Color(0.6, 0.2, 0.2, 0.6)

const DRAG_GHOST_ALPHA := 0.5
const INFO_BG := Color(0.05, 0.04, 0.1, 0.85)
const INFO_TEXT := Color(0.7, 0.65, 0.85, 0.9)

const SPELLBOOK_CARD_BG := Color(0.07, 0.06, 0.13, 0.7)
const SPELLBOOK_CARD_HOVER := Color(0.12, 0.1, 0.2, 0.8)
const SPELLBOOK_EQUIPPED := Color(0.06, 0.05, 0.1, 0.5)

## 和弦类型识别表 (复用 chord_alchemy_panel 的映射)
const CHORD_PATTERNS := {
	"0,4,7": { "name": "大三和弦", "spell_form": "enhanced_projectile", "desc": "强化弹体：弹体体积+50%，伤害+40%" },
	"0,3,7": { "name": "小三和弦", "spell_form": "dot_projectile", "desc": "DOT弹体：命中后持续伤害" },
	"0,3,6": { "name": "减三和弦", "spell_form": "shockwave", "desc": "冲击波：环形扩散后内爆" },
	"0,4,8": { "name": "增三和弦", "spell_form": "explosive_projectile", "desc": "爆炸弹体：命中时范围爆炸" },
	"0,4,7,11": { "name": "大七和弦", "spell_form": "shield_heal", "desc": "护盾/治疗法阵：恢复生命值" },
	"0,4,7,10": { "name": "属七和弦", "spell_form": "magic_circle", "desc": "法阵/区域：旋转法阵持续存在" },
	"0,3,7,10": { "name": "小七和弦", "spell_form": "summon_construct", "desc": "召唤/构造：水晶构造体" },
	"0,3,6,9": { "name": "减七和弦", "spell_form": "celestial_strike", "desc": "天降打击：延迟后毁灭性打击" },
	"0,3,6,10": { "name": "半减七和弦", "spell_form": "slow_field", "desc": "迟缓领域：大范围减速" },
	"0,5,7": { "name": "挂四和弦", "spell_form": "charged_projectile", "desc": "蓄力弹体：延迟释放" },
	"0,2,7": { "name": "挂二和弦", "spell_form": "charged_projectile", "desc": "蓄力弹体：延迟释放" },
}

## 法术形态颜色
const SPELL_FORM_COLORS := {
	"enhanced_projectile": Color(1.0, 0.85, 0.3),
	"dot_projectile": Color(0.2, 0.3, 0.8),
	"explosive_projectile": Color(1.0, 0.4, 0.2),
	"shockwave": Color(0.5, 0.1, 0.7),
	"magic_circle": Color(1.0, 0.8, 0.0),
	"celestial_strike": Color(0.8, 0.1, 0.1),
	"shield_heal": Color(0.2, 0.9, 0.4),
	"summon_construct": Color(0.15, 0.2, 0.7),
	"charged_projectile": Color(0.85, 0.85, 0.95),
	"slow_field": Color(0.3, 0.3, 0.7),
	"generic_blast": Color(0.5, 0.5, 0.5),
}

# ============================================================
# 状态 — 面板
# ============================================================
var _is_open: bool = false
var _panel_rect: Rect2 = Rect2()
var _left_rect: Rect2 = Rect2()
var _right_rect: Rect2 = Rect2()

# ============================================================
# 状态 — 序列器
# ============================================================
var _sequencer_data: Array = []
var _playhead_position: int = 0
var _beat_flash: float = 0.0
var _seq_cell_rects: Array[Rect2] = []

# ============================================================
# 状态 — 音符库存
# ============================================================
var _inv_white_rects: Array[Rect2] = []
var _inv_black_rects: Array[Rect2] = []

# ============================================================
# 状态 — 法术书
# ============================================================
var _spell_card_rects: Array[Rect2] = []
var _spellbook_scroll: float = 0.0

# ============================================================
# 状态 — 和弦炼成
# ============================================================
var _alchemy_slots: Array[int] = []  # WhiteKey值，-1=空
var _alchemy_slot_rects: Array[Rect2] = []
var _alchemy_preview: Dictionary = {}
var _alchemy_can_craft: bool = false
var _synth_button_rect: Rect2 = Rect2()

# ============================================================
# 状态 — 手动施法槽
# ============================================================
var _manual_slot_configs: Array[Dictionary] = []
var _manual_slot_rects: Array[Rect2] = []

# ============================================================
# 状态 — 交互
# ============================================================
var _hover_seq_cell: int = -1
var _hover_inv_white: int = -1
var _hover_inv_black: int = -1
var _hover_spell_card: int = -1
var _hover_alchemy_slot: int = -1
var _hover_manual_slot: int = -1
var _hover_synth_btn: bool = false

## 拖拽
var _is_dragging: bool = false
var _drag_type: String = ""  # "note", "black_key", "chord_spell", "seq_cell"
var _drag_note: int = -1
var _drag_spell_id: String = ""
var _drag_from_idx: int = -1
var _drag_position: Vector2 = Vector2.ZERO
var _drag_started: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD := 6.0

## 信息面板
var _info_title: String = ""
var _info_desc: String = ""
var _info_stats: String = ""
var _info_color: Color = Color.WHITE
var _info_rect: Rect2 = Rect2()

## 撤销/重做
var _undo_stack: Array[Array] = []
var _redo_stack: Array[Array] = []
const MAX_UNDO: int = 32

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_init_alchemy_slots()
	_init_manual_slots()

	# 连接信号
	GameManager.beat_tick.connect(_on_beat_tick)
	SpellcraftSystem.sequencer_updated.connect(_on_sequencer_updated)
	NoteInventory.inventory_changed.connect(_on_inventory_changed)
	NoteInventory.spellbook_changed.connect(_on_spellbook_changed)

func _process(delta: float) -> void:
	if not _is_open:
		return
	_beat_flash = max(0.0, _beat_flash - delta * 4.0)
	queue_redraw()

# ============================================================
# 初始化
# ============================================================

func _init_alchemy_slots() -> void:
	_alchemy_slots.clear()
	for i in range(MAX_ALCHEMY_SLOTS):
		_alchemy_slots.append(-1)
	_alchemy_preview = {}
	_alchemy_can_craft = false

func _init_manual_slots() -> void:
	_manual_slot_configs.clear()
	for i in range(MANUAL_SLOT_COUNT):
		_manual_slot_configs.append({ "type": "empty" })

# ============================================================
# 显示/隐藏
# ============================================================

func toggle() -> void:
	if _is_open:
		close_panel()
	else:
		open_panel()

func open_panel() -> void:
	_is_open = true
	visible = true
	_sequencer_data = SpellcraftSystem.get_sequencer_data()
	_sync_manual_slots()
	_calculate_layout()
	panel_toggled.emit(true)
	queue_redraw()

## v3.0: 供 main_game.gd 调用，和弦炼成完成后刷新法术书区域
func refresh_spellbook() -> void:
	_calculate_spellbook_layout()
	queue_redraw()

func close_panel() -> void:
	# 将炼成槽中的音符返回库存
	_return_alchemy_notes()
	_is_open = false
	visible = false
	panel_toggled.emit(false)

func _return_alchemy_notes() -> void:
	for i in range(MAX_ALCHEMY_SLOTS):
		if _alchemy_slots[i] >= 0:
			NoteInventory.unequip_note(_alchemy_slots[i])
			_alchemy_slots[i] = -1
	_alchemy_preview = {}
	_alchemy_can_craft = false

func _sync_manual_slots() -> void:
	# 从 SpellcraftSystem 同步手动施法槽状态
	for i in range(MANUAL_SLOT_COUNT):
		var slot_data: Dictionary = SpellcraftSystem.get_manual_slot_data(i)
		if slot_data.is_empty() or slot_data.get("type", "rest") == "rest":
			_manual_slot_configs[i] = { "type": "empty" }
		else:
			_manual_slot_configs[i] = slot_data.duplicate()

# ============================================================
# 布局计算
# ============================================================

func _calculate_layout() -> void:
	var vp_size := get_viewport_rect().size
	var panel_w := min(vp_size.x - PANEL_MARGIN * 2, 960.0)
	var panel_h := min(vp_size.y - PANEL_MARGIN * 2, 560.0)
	var panel_x := (vp_size.x - panel_w) / 2.0
	var panel_y := (vp_size.y - panel_h) / 2.0
	_panel_rect = Rect2(Vector2(panel_x, panel_y), Vector2(panel_w, panel_h))

	# 左侧面板
	_left_rect = Rect2(
		_panel_rect.position + Vector2(0, HEADER_HEIGHT),
		Vector2(LEFT_PANEL_WIDTH, panel_h - HEADER_HEIGHT)
	)

	# 右侧面板
	_right_rect = Rect2(
		_panel_rect.position + Vector2(LEFT_PANEL_WIDTH + SECTION_GAP, HEADER_HEIGHT),
		Vector2(panel_w - LEFT_PANEL_WIDTH - SECTION_GAP, panel_h - HEADER_HEIGHT)
	)

	_calculate_inventory_layout()
	_calculate_spellbook_layout()
	_calculate_alchemy_layout()
	_calculate_sequencer_layout()
	_calculate_manual_slot_layout()
	_calculate_info_layout()

func _calculate_inventory_layout() -> void:
	_inv_white_rects.clear()
	_inv_black_rects.clear()
	var base_x := _left_rect.position.x + 10.0
	var base_y := _left_rect.position.y + INV_LABEL_HEIGHT + 8.0

	# 白键 (7个)
	for i in range(7):
		var x := base_x + i * (INV_CELL_SIZE.x + INV_CELL_MARGIN)
		_inv_white_rects.append(Rect2(Vector2(x, base_y), INV_CELL_SIZE))

	# 黑键 (5个，在白键下方)
	var black_y := base_y + INV_CELL_SIZE.y + INV_CELL_MARGIN + 2.0
	for i in range(5):
		var x := base_x + i * (INV_CELL_SIZE.x + INV_CELL_MARGIN)
		_inv_black_rects.append(Rect2(Vector2(x, black_y), INV_CELL_SIZE))

func _calculate_spellbook_layout() -> void:
	_spell_card_rects.clear()
	var base_x := _left_rect.position.x + 8.0
	var base_y := _left_rect.position.y + INV_SECTION_HEIGHT + SECTION_GAP + INV_LABEL_HEIGHT + 4.0
	var card_w := LEFT_PANEL_WIDTH - 16.0

	var spellbook := NoteInventory.spellbook
	for i in range(spellbook.size()):
		var y := base_y + i * (SPELL_CARD_HEIGHT + SPELL_CARD_MARGIN) - _spellbook_scroll
		_spell_card_rects.append(Rect2(Vector2(base_x, y), Vector2(card_w, SPELL_CARD_HEIGHT)))

func _calculate_alchemy_layout() -> void:
	_alchemy_slot_rects.clear()
	var base_x := _left_rect.position.x + 10.0
	var base_y := _left_rect.position.y + INV_SECTION_HEIGHT + SPELLBOOK_SECTION_HEIGHT + SECTION_GAP * 2 + INV_LABEL_HEIGHT + 4.0

	var slots_total_w := MAX_ALCHEMY_SLOTS * (ALCHEMY_SLOT_SIZE.x + ALCHEMY_SLOT_MARGIN) - ALCHEMY_SLOT_MARGIN
	var start_x := base_x + (LEFT_PANEL_WIDTH - 20.0 - slots_total_w) / 2.0

	for i in range(MAX_ALCHEMY_SLOTS):
		var x := start_x + i * (ALCHEMY_SLOT_SIZE.x + ALCHEMY_SLOT_MARGIN)
		_alchemy_slot_rects.append(Rect2(Vector2(x, base_y), ALCHEMY_SLOT_SIZE))

	# 合成按钮
	var btn_w := 140.0
	var btn_h := 30.0
	_synth_button_rect = Rect2(
		Vector2(base_x + (LEFT_PANEL_WIDTH - 20.0 - btn_w) / 2.0, base_y + ALCHEMY_SLOT_SIZE.y + 10.0),
		Vector2(btn_w, btn_h)
	)

func _calculate_sequencer_layout() -> void:
	_seq_cell_rects.clear()
	var base_x := _right_rect.position.x + 10.0
	var base_y := _right_rect.position.y + INV_LABEL_HEIGHT + 8.0

	for measure in range(MEASURES):
		for beat in range(BEATS_PER_MEASURE):
			var idx := measure * BEATS_PER_MEASURE + beat
			var x := base_x + idx * (SEQ_CELL_SIZE.x + SEQ_CELL_MARGIN) + measure * SEQ_MEASURE_GAP
			_seq_cell_rects.append(Rect2(Vector2(x, base_y), SEQ_CELL_SIZE))

func _calculate_manual_slot_layout() -> void:
	_manual_slot_rects.clear()
	var base_x := _right_rect.position.x + 10.0
	var base_y := _right_rect.position.y + INV_LABEL_HEIGHT + SEQ_CELL_SIZE.y + 40.0

	for i in range(MANUAL_SLOT_COUNT):
		var x := base_x + i * (MANUAL_SLOT_SIZE.x + MANUAL_SLOT_MARGIN)
		_manual_slot_rects.append(Rect2(Vector2(x, base_y), MANUAL_SLOT_SIZE))

func _calculate_info_layout() -> void:
	_info_rect = Rect2(
		Vector2(_right_rect.position.x + 10.0, _right_rect.position.y + _right_rect.size.y - INFO_PANEL_HEIGHT - 8.0),
		Vector2(_right_rect.size.x - 20.0, INFO_PANEL_HEIGHT)
	)

# ============================================================
# 绘制 — 主入口
# ============================================================

func _draw() -> void:
	if not _is_open:
		return

	_calculate_layout()
	var font := ThemeDB.fallback_font

	# 背景遮罩
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.0, 0.0, 0.0, 0.55))

	# 面板背景
	draw_rect(_panel_rect, BG_COLOR)
	draw_rect(_panel_rect, SECTION_BORDER, false, 1.5)

	# 头部
	_draw_header(font)

	# 左侧面板背景
	draw_rect(_left_rect, LEFT_BG)

	# 右侧面板背景
	draw_rect(_right_rect, RIGHT_BG)

	# 各区域绘制
	_draw_inventory(font)
	_draw_spellbook(font)
	_draw_alchemy(font)
	_draw_sequencer(font)
	_draw_manual_slots(font)
	_draw_info_panel(font)

	# 拖拽幽灵
	if _is_dragging and _drag_started:
		_draw_drag_ghost(font)

# ============================================================
# 绘制 — 头部
# ============================================================

func _draw_header(font: Font) -> void:
	var header_rect := Rect2(_panel_rect.position, Vector2(_panel_rect.size.x, HEADER_HEIGHT))
	draw_rect(header_rect, HEADER_BG)

	# 标题
	draw_string(font, header_rect.position + Vector2(16, 22),
		"COMPOSER", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.8, 1.0))

	# 副标题
	draw_string(font, header_rect.position + Vector2(110, 22),
		"Integrated Spell Workshop", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.45, 0.65))

	# BPM 信息
	var bpm_text := "BPM: %d" % int(GameManager.current_bpm)
	draw_string(font, header_rect.position + Vector2(header_rect.size.x - 120, 22),
		bpm_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, Color(0.5, 0.45, 0.65))

	# 关闭按钮提示
	draw_string(font, header_rect.position + Vector2(header_rect.size.x - 40, 22),
		"[ESC]", HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Color(0.6, 0.3, 0.3, 0.7))

	# 底部分隔线
	draw_line(
		header_rect.position + Vector2(0, HEADER_HEIGHT),
		header_rect.position + Vector2(header_rect.size.x, HEADER_HEIGHT),
		SECTION_BORDER, 1.0
	)

# ============================================================
# 绘制 — 音符库存
# ============================================================

func _draw_inventory(font: Font) -> void:
	var section_y := _left_rect.position.y
	draw_string(font, Vector2(_left_rect.position.x + 10, section_y + 14),
		"NOTE INVENTORY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SECTION_TITLE_COLOR)

	# 白键
	for i in range(7):
		var rect := _inv_white_rects[i]
		var count := NoteInventory.get_note_count(i)
		var note_color: Color = MusicData.NOTE_COLORS.get(i, Color(0.5, 0.5, 0.5))
		var is_hover := (_hover_inv_white == i)

		var bg := CELL_EMPTY
		if count > 0:
			bg = CELL_FILLED
		if is_hover:
			bg = CELL_HOVER
		draw_rect(rect, bg)

		# 边框
		var border := note_color if count > 0 else SECTION_BORDER
		border.a = 0.6 if count > 0 else 0.3
		draw_rect(rect, border, false, 1.0)

		# 音符名称
		var name_str: String = MusicData.WHITE_KEY_STATS.get(i, {}).get("name", "?")
		var text_color := note_color if count > 0 else Color(0.4, 0.4, 0.5, 0.5)
		draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 6, rect.size.y / 2.0 + 4),
			name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, text_color)

		# 数量
		var count_color := Color(0.8, 0.8, 0.9) if count > 0 else Color(0.4, 0.4, 0.5, 0.4)
		draw_string(font, rect.position + Vector2(rect.size.x - 4, 12),
			"x%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, -1, 8, count_color)

	# 黑键
	for i in range(5):
		var rect := _inv_black_rects[i]
		var count := NoteInventory.get_black_key_count(i)
		var is_hover := (_hover_inv_black == i)

		var bg := CELL_EMPTY
		if count > 0:
			bg = Color(0.12, 0.1, 0.18, 0.8)
		if is_hover:
			bg = CELL_HOVER
		draw_rect(rect, bg)

		var modifier_data: Dictionary = MusicData.BLACK_KEY_MODIFIERS.get(i, {})
		var mod_name: String = modifier_data.get("name", "?")
		var text_color := Color(0.7, 0.6, 0.9) if count > 0 else Color(0.4, 0.4, 0.5, 0.4)
		draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 8, rect.size.y / 2.0 + 4),
			mod_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, text_color)

		draw_string(font, rect.position + Vector2(rect.size.x - 4, 12),
			"x%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, -1, 8, text_color)

# ============================================================
# 绘制 — 法术书调色板
# ============================================================

func _draw_spellbook(font: Font) -> void:
	var section_y := _left_rect.position.y + INV_SECTION_HEIGHT + SECTION_GAP

	# 分隔线
	draw_line(
		Vector2(_left_rect.position.x + 8, section_y),
		Vector2(_left_rect.position.x + LEFT_PANEL_WIDTH - 8, section_y),
		SECTION_BORDER, 0.5
	)

	draw_string(font, Vector2(_left_rect.position.x + 10, section_y + 14),
		"SPELLBOOK", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SECTION_TITLE_COLOR)

	var spellbook := NoteInventory.spellbook
	if spellbook.is_empty():
		draw_string(font, Vector2(_left_rect.position.x + 10, section_y + 36),
			"No chord spells yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 0.38, 0.5, 0.5))
		draw_string(font, Vector2(_left_rect.position.x + 10, section_y + 50),
			"Use Alchemy below to craft.", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.38, 0.5, 0.4))
		return

	for i in range(spellbook.size()):
		if i >= _spell_card_rects.size():
			break
		var rect := _spell_card_rects[i]
		# 仅绘制可见区域
		if rect.position.y + rect.size.y < section_y + INV_LABEL_HEIGHT:
			continue
		if rect.position.y > section_y + SPELLBOOK_SECTION_HEIGHT:
			break

		var spell := spellbook[i]
		var is_hover := (_hover_spell_card == i)
		var is_equipped: bool = spell.get("is_equipped", false)

		var bg := SPELLBOOK_CARD_BG
		if is_equipped:
			bg = SPELLBOOK_EQUIPPED
		elif is_hover:
			bg = SPELLBOOK_CARD_HOVER
		draw_rect(rect, bg)
		draw_rect(rect, SECTION_BORDER, false, 0.5)

		# 法术名称
		var spell_name: String = spell.get("spell_name", "Unknown")
		var name_color := Color(1.0, 0.9, 0.6, 0.95) if not is_equipped else Color(0.6, 0.55, 0.5, 0.5)
		draw_string(font, rect.position + Vector2(8, 18),
			spell_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, name_color)

		# 法术形态
		var form_str: String = spell.get("spell_form", "unknown").replace("_", " ").capitalize()
		draw_string(font, rect.position + Vector2(8, 34),
			form_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.45, 0.65, 0.7))

		# 状态
		var status_text := "EQUIPPED" if is_equipped else "READY"
		var status_color := Color(0.2, 0.6, 1.0, 0.7) if is_equipped else Color(0.2, 0.8, 0.4, 0.7)
		draw_string(font, rect.position + Vector2(rect.size.x - 60, 18),
			status_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 8, status_color)

# ============================================================
# 绘制 — 和弦炼成区
# ============================================================

func _draw_alchemy(font: Font) -> void:
	var section_y := _left_rect.position.y + INV_SECTION_HEIGHT + SPELLBOOK_SECTION_HEIGHT + SECTION_GAP * 2

	# 分隔线
	draw_line(
		Vector2(_left_rect.position.x + 8, section_y),
		Vector2(_left_rect.position.x + LEFT_PANEL_WIDTH - 8, section_y),
		SECTION_BORDER, 0.5
	)

	draw_string(font, Vector2(_left_rect.position.x + 10, section_y + 14),
		"CHORD ALCHEMY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SECTION_TITLE_COLOR)

	# 炼成槽
	for i in range(MAX_ALCHEMY_SLOTS):
		var rect := _alchemy_slot_rects[i]
		var is_filled := _alchemy_slots[i] >= 0
		var is_hover := (_hover_alchemy_slot == i)

		var bg := ALCHEMY_EMPTY
		if is_filled:
			bg = ALCHEMY_FILLED
		if is_hover:
			bg = SLOT_HOVER
		draw_rect(rect, bg)

		# 边框
		var border := SECTION_BORDER
		if is_filled:
			border = MusicData.NOTE_COLORS.get(_alchemy_slots[i], Color(0.5, 0.5, 0.5))
			border.a = 0.7
		draw_rect(rect, border, false, 1.0)

		if is_filled:
			var note_color: Color = MusicData.NOTE_COLORS.get(_alchemy_slots[i], Color(0.5, 0.5, 0.5))
			note_color.a = 0.25
			draw_rect(rect.grow(-2), note_color)
			var name_str: String = MusicData.WHITE_KEY_STATS.get(_alchemy_slots[i], {}).get("name", "?")
			note_color.a = 1.0
			draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 6, rect.size.y / 2.0 + 5),
				name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, note_color)
		else:
			# 必需标记
			if i < MIN_NOTES_FOR_CHORD:
				draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 2, rect.size.y + 10),
					"*", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.5, 0.3, 0.3, 0.5))

	# 和弦预览
	if not _alchemy_preview.is_empty():
		var preview_y := _alchemy_slot_rects[0].position.y - 16.0
		var chord_name: String = _alchemy_preview.get("name", "???")
		var form_color: Color = SPELL_FORM_COLORS.get(_alchemy_preview.get("spell_form", ""), Color.WHITE)
		draw_string(font, Vector2(_left_rect.position.x + 10, preview_y),
			chord_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, form_color)

	# 合成按钮
	var btn_color := ALCHEMY_VALID if _alchemy_can_craft else ALCHEMY_INVALID
	if _hover_synth_btn and _alchemy_can_craft:
		btn_color = Color(0.15, 0.75, 0.5, 1.0)
	draw_rect(_synth_button_rect, btn_color)
	draw_rect(_synth_button_rect, SECTION_BORDER, false, 1.0)

	var btn_text := "SYNTHESIZE" if _alchemy_can_craft else "Need 3+ Notes"
	var btn_text_color := Color.WHITE if _alchemy_can_craft else Color(0.5, 0.5, 0.5, 0.6)
	draw_string(font, _synth_button_rect.position + Vector2(_synth_button_rect.size.x / 2.0 - 35, 20),
		btn_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, btn_text_color)

# ============================================================
# 绘制 — 序列器
# ============================================================

func _draw_sequencer(font: Font) -> void:
	var section_y := _right_rect.position.y
	draw_string(font, Vector2(_right_rect.position.x + 10, section_y + 14),
		"SEQUENCER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SECTION_TITLE_COLOR)

	# 节拍信息
	var beat_in_measure := GameManager.get_beat_in_measure()
	draw_string(font, Vector2(_right_rect.position.x + _right_rect.size.x - 80, section_y + 14),
		"Beat %d/%d" % [beat_in_measure + 1, BEATS_PER_MEASURE],
		HORIZONTAL_ALIGNMENT_RIGHT, -1, 9, Color(0.4, 0.35, 0.5))

	for idx in range(TOTAL_CELLS):
		if idx >= _seq_cell_rects.size():
			break
		var rect := _seq_cell_rects[idx]
		var is_hover := (_hover_seq_cell == idx)

		# 小节线
		if idx > 0 and idx % BEATS_PER_MEASURE == 0:
			var line_x := rect.position.x - SEQ_MEASURE_GAP / 2.0
			draw_line(
				Vector2(line_x, rect.position.y - 2),
				Vector2(line_x, rect.position.y + rect.size.y + 2),
				MEASURE_LINE, 1.0
			)

		# 单元格背景
		var bg := CELL_EMPTY
		if idx < _sequencer_data.size():
			var slot: Dictionary = _sequencer_data[idx]
			var slot_type: String = slot.get("type", "rest")
			if slot_type == "note" or slot_type == "chord":
				bg = CELL_FILLED
		if is_hover:
			bg = CELL_HOVER
		draw_rect(rect, bg)
		draw_rect(rect, SECTION_BORDER, false, 0.5)

		# 单元格内容
		if idx < _sequencer_data.size():
			var slot: Dictionary = _sequencer_data[idx]
			var slot_type: String = slot.get("type", "rest")
			if slot_type == "note":
				var note_key: int = slot.get("note", 0)
				var note_color: Color = MusicData.NOTE_COLORS.get(note_key, Color(0.5, 0.5, 0.5))
				note_color.a = 0.3
				draw_rect(rect.grow(-2), note_color)
				note_color.a = 1.0
				var name_str: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
				draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 6, rect.size.y / 2.0 + 5),
					name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, note_color)
			elif slot_type == "chord":
				var chord_color := Color(1.0, 0.8, 0.0, 0.3)
				draw_rect(rect.grow(-2), chord_color)
				draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 6, rect.size.y / 2.0 + 5),
					"C", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 0.8, 0.0))

		# 小节号
		if idx % BEATS_PER_MEASURE == 0:
			var measure_idx := idx / BEATS_PER_MEASURE
			draw_string(font, Vector2(rect.position.x, rect.position.y - 4),
				"M%d" % (measure_idx + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.35, 0.5, 0.6))

	# 播放头
	_draw_playhead(font)

func _draw_playhead(font: Font) -> void:
	var pos := SpellcraftSystem.get_sequencer_position()
	if pos >= 0 and pos < _seq_cell_rects.size():
		var rect := _seq_cell_rects[pos]
		var flash_alpha := 0.3 + _beat_flash * 0.5
		var playhead_rect := Rect2(
			Vector2(rect.position.x - 1, rect.position.y - 2),
			Vector2(rect.size.x + 2, rect.size.y + 4)
		)
		var ph_color := PLAYHEAD_COLOR
		ph_color.a = flash_alpha
		draw_rect(playhead_rect, ph_color, false, 2.0)

# ============================================================
# 绘制 — 手动施法槽
# ============================================================

func _draw_manual_slots(font: Font) -> void:
	if _manual_slot_rects.is_empty():
		return

	var label_y := _manual_slot_rects[0].position.y - 16.0
	draw_string(font, Vector2(_right_rect.position.x + 10, label_y),
		"MANUAL CAST", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SECTION_TITLE_COLOR)

	for i in range(MANUAL_SLOT_COUNT):
		var rect := _manual_slot_rects[i]
		var config := _manual_slot_configs[i]
		var is_hover := (_hover_manual_slot == i)
		var is_filled: bool = config.get("type", "empty") != "empty"

		var bg := SLOT_EMPTY
		if is_hover:
			bg = SLOT_HOVER
		elif is_filled:
			bg = SLOT_FILLED
		draw_rect(rect, bg)

		var border := SECTION_BORDER
		if is_filled:
			border = _get_manual_slot_color(config)
			border.a = 0.7
		draw_rect(rect, border, false, 1.0)

		if is_filled:
			_draw_manual_slot_content(rect, config, font)
		else:
			draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 6, rect.size.y / 2.0 + 6),
				"+", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(0.3, 0.28, 0.4, 0.5))

		# 按键标签
		draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 3, rect.size.y + 14),
			MANUAL_SLOT_KEYS[i], HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.6, 0.55, 0.75, 0.8))

		# 冷却覆盖
		var cd := SpellcraftSystem.get_manual_slot_cooldown_progress(i)
		if cd > 0.01:
			var cd_h := rect.size.y * cd
			draw_rect(Rect2(
				Vector2(rect.position.x, rect.position.y + rect.size.y - cd_h),
				Vector2(rect.size.x, cd_h)
			), Color(0.1, 0.1, 0.15, 0.7))

func _draw_manual_slot_content(rect: Rect2, config: Dictionary, font: Font) -> void:
	var slot_type: String = config.get("type", "empty")
	match slot_type:
		"note":
			var note_key: int = config.get("note", 0)
			var note_color: Color = MusicData.NOTE_COLORS.get(note_key, Color(0.5, 0.5, 0.5))
			note_color.a = 0.25
			draw_rect(rect.grow(-3), note_color)
			note_color.a = 1.0
			var name_str: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
			draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 8, rect.size.y / 2.0 + 6),
				name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, note_color)
		"chord":
			var chord_color := Color(1.0, 0.8, 0.0, 0.25)
			draw_rect(rect.grow(-3), chord_color)
			draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 8, rect.size.y / 2.0 + 6),
				"C", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 0.8, 0.0))

func _get_manual_slot_color(config: Dictionary) -> Color:
	match config.get("type", "empty"):
		"note":
			return MusicData.NOTE_COLORS.get(config.get("note", 0), Color(0.5, 0.5, 0.5))
		"chord":
			return Color(1.0, 0.8, 0.0)
	return Color(0.5, 0.5, 0.5)

# ============================================================
# 绘制 — 信息预览面板
# ============================================================

func _draw_info_panel(font: Font) -> void:
	draw_rect(_info_rect, INFO_BG)
	draw_rect(_info_rect, SECTION_BORDER, false, 0.5)

	if _info_title.is_empty():
		draw_string(font, _info_rect.position + Vector2(10, 24),
			"Hover over any element for details", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.38, 0.5, 0.5))
		return

	# 标题
	draw_string(font, _info_rect.position + Vector2(10, 20),
		_info_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, _info_color)

	# 描述
	if not _info_desc.is_empty():
		draw_string(font, _info_rect.position + Vector2(10, 40),
			_info_desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INFO_TEXT)

	# 数值
	if not _info_stats.is_empty():
		draw_string(font, _info_rect.position + Vector2(10, 58),
			_info_stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.8, 0.6, 0.8))

# ============================================================
# 绘制 — 拖拽幽灵
# ============================================================

func _draw_drag_ghost(font: Font) -> void:
	var ghost_size := Vector2(40, 40)
	var ghost_color := Color(0.5, 0.5, 0.5, DRAG_GHOST_ALPHA)
	var label := "?"

	match _drag_type:
		"note":
			ghost_color = MusicData.NOTE_COLORS.get(_drag_note, Color(0.5, 0.5, 0.5))
			ghost_color.a = DRAG_GHOST_ALPHA
			label = MusicData.WHITE_KEY_STATS.get(_drag_note, {}).get("name", "?")
		"black_key":
			ghost_color = Color(0.6, 0.4, 0.8, DRAG_GHOST_ALPHA)
			label = MusicData.BLACK_KEY_MODIFIERS.get(_drag_note, {}).get("name", "?")
		"chord_spell":
			ghost_color = Color(1.0, 0.8, 0.0, DRAG_GHOST_ALPHA)
			label = "C"
		"seq_cell":
			ghost_color = MusicData.NOTE_COLORS.get(_drag_note, Color(0.5, 0.5, 0.5))
			ghost_color.a = DRAG_GHOST_ALPHA
			label = MusicData.WHITE_KEY_STATS.get(_drag_note, {}).get("name", "?")

	var ghost_rect := Rect2(_drag_position - ghost_size / 2.0, ghost_size)
	draw_rect(ghost_rect, ghost_color)
	draw_string(font, _drag_position + Vector2(-6, 5), label,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 1.0, 1.0, 0.7))

# ============================================================
# 输入处理
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_left_press(event.position)
			else:
				_handle_left_release(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_spellbook_scroll = max(0.0, _spellbook_scroll - 20.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_spellbook_scroll += 20.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _is_open:
			close_panel()
			get_viewport().set_input_as_handled()

# ============================================================
# 鼠标移动
# ============================================================

func _handle_mouse_motion(pos: Vector2) -> void:
	# 拖拽更新
	if _is_dragging:
		_drag_position = pos
		if not _drag_started:
			if pos.distance_to(_drag_start_pos) > DRAG_THRESHOLD:
				_drag_started = true
		return

	# 悬停检测
	_clear_hover()
	_update_hover(pos)

func _clear_hover() -> void:
	_hover_seq_cell = -1
	_hover_inv_white = -1
	_hover_inv_black = -1
	_hover_spell_card = -1
	_hover_alchemy_slot = -1
	_hover_manual_slot = -1
	_hover_synth_btn = false
	_info_title = ""
	_info_desc = ""
	_info_stats = ""
	_info_color = Color.WHITE

func _update_hover(pos: Vector2) -> void:
	# 序列器
	for i in range(_seq_cell_rects.size()):
		if _seq_cell_rects[i].has_point(pos):
			_hover_seq_cell = i
			_update_info_for_seq_cell(i)
			return

	# 白键库存
	for i in range(_inv_white_rects.size()):
		if _inv_white_rects[i].has_point(pos):
			_hover_inv_white = i
			_update_info_for_note(i)
			return

	# 黑键库存
	for i in range(_inv_black_rects.size()):
		if _inv_black_rects[i].has_point(pos):
			_hover_inv_black = i
			_update_info_for_black_key(i)
			return

	# 法术书
	for i in range(_spell_card_rects.size()):
		if _spell_card_rects[i].has_point(pos):
			_hover_spell_card = i
			_update_info_for_spell(i)
			return

	# 炼成槽
	for i in range(_alchemy_slot_rects.size()):
		if _alchemy_slot_rects[i].has_point(pos):
			_hover_alchemy_slot = i
			return

	# 手动施法槽
	for i in range(_manual_slot_rects.size()):
		if _manual_slot_rects[i].has_point(pos):
			_hover_manual_slot = i
			_update_info_for_manual_slot(i)
			return

	# 合成按钮
	if _synth_button_rect.has_point(pos):
		_hover_synth_btn = true

# ============================================================
# 信息面板更新
# ============================================================

func _update_info_for_note(note_key: int) -> void:
	var stats: Dictionary = MusicData.WHITE_KEY_STATS.get(note_key, {})
	_info_title = "%s Note" % stats.get("name", "?")
	_info_desc = stats.get("desc", "")
	_info_stats = "DMG:%d  SPD:%d  DUR:%d  SIZE:%d  |  Stock: x%d" % [
		stats.get("dmg", 0), stats.get("spd", 0), stats.get("dur", 0), stats.get("size", 0),
		NoteInventory.get_note_count(note_key)
	]
	_info_color = MusicData.NOTE_COLORS.get(note_key, Color.WHITE)

func _update_info_for_black_key(key_idx: int) -> void:
	var modifier: Dictionary = MusicData.BLACK_KEY_MODIFIERS.get(key_idx, {})
	_info_title = "%s Modifier" % modifier.get("name", "?")
	_info_desc = "Effect: %s" % modifier.get("desc", "")
	_info_stats = "Stock: x%d" % NoteInventory.get_black_key_count(key_idx)
	_info_color = Color(0.7, 0.5, 0.9)

func _update_info_for_seq_cell(idx: int) -> void:
	if idx >= _sequencer_data.size():
		_info_title = "Empty Slot"
		_info_desc = "Drag a note here to fill"
		return
	var slot: Dictionary = _sequencer_data[idx]
	var slot_type: String = slot.get("type", "rest")
	var measure := idx / BEATS_PER_MEASURE + 1
	var beat := idx % BEATS_PER_MEASURE + 1

	match slot_type:
		"note":
			var note_key: int = slot.get("note", 0)
			var stats := GameManager.get_note_effective_stats(note_key)
			_info_title = "%s Note — M%d B%d" % [MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?"), measure, beat]
			_info_desc = "Left-click to replace, Right-click to clear"
			_info_stats = "DMG:%.1f  SPD:%.1f  DUR:%.1f  SIZE:%.1f" % [stats.get("dmg", 0), stats.get("spd", 0), stats.get("dur", 0), stats.get("size", 0)]
			_info_color = MusicData.NOTE_COLORS.get(note_key, Color.WHITE)
		"chord":
			_info_title = "Chord Spell — M%d B%d" % [measure, beat]
			_info_desc = "Chord spell occupies this slot"
			_info_color = Color(1.0, 0.8, 0.0)
		_:
			_info_title = "Rest — M%d B%d" % [measure, beat]
			_info_desc = "Drag a note here to fill"
			_info_color = Color(0.5, 0.5, 0.6)

func _update_info_for_spell(idx: int) -> void:
	var spellbook := NoteInventory.spellbook
	if idx >= spellbook.size():
		return
	var spell := spellbook[idx]
	_info_title = spell.get("spell_name", "Unknown")
	_info_desc = "Form: %s" % spell.get("spell_form", "unknown").replace("_", " ").capitalize()
	var root_name: String = MusicData.WHITE_KEY_STATS.get(spell.get("root_note", 0), {}).get("name", "?")
	_info_stats = "Root: %s  |  %s" % [root_name, "Equipped" if spell.get("is_equipped", false) else "Available — Drag to equip"]
	_info_color = SPELL_FORM_COLORS.get(spell.get("spell_form", ""), Color.WHITE)

func _update_info_for_manual_slot(idx: int) -> void:
	var config := _manual_slot_configs[idx]
	if config.get("type", "empty") == "empty":
		_info_title = "Manual Slot [%s]" % MANUAL_SLOT_KEYS[idx]
		_info_desc = "Drag a note or chord spell here"
		_info_color = Color(0.6, 0.55, 0.75)
	else:
		_info_title = "Manual Slot [%s] — Configured" % MANUAL_SLOT_KEYS[idx]
		_info_desc = "Right-click to clear"
		_info_color = _get_manual_slot_color(config)

# ============================================================
# 左键按下
# ============================================================

func _handle_left_press(pos: Vector2) -> void:
	_drag_start_pos = pos
	_drag_position = pos

	# 合成按钮
	if _synth_button_rect.has_point(pos) and _alchemy_can_craft:
		_execute_alchemy()
		return

	# 从库存开始拖拽白键
	for i in range(_inv_white_rects.size()):
		if _inv_white_rects[i].has_point(pos) and NoteInventory.get_note_count(i) > 0:
			_start_drag("note", i, -1)
			return

	# 从库存开始拖拽黑键
	for i in range(_inv_black_rects.size()):
		if _inv_black_rects[i].has_point(pos) and NoteInventory.get_black_key_count(i) > 0:
			_start_drag("black_key", i, -1)
			return

	# 从法术书开始拖拽
	var spellbook := NoteInventory.spellbook
	for i in range(_spell_card_rects.size()):
		if _spell_card_rects[i].has_point(pos) and i < spellbook.size():
			if not spellbook[i].get("is_equipped", false):
				_drag_spell_id = spellbook[i].get("id", "")
				_start_drag("chord_spell", -1, i)
				return

	# 从序列器开始拖拽
	for i in range(_seq_cell_rects.size()):
		if _seq_cell_rects[i].has_point(pos) and i < _sequencer_data.size():
			var slot: Dictionary = _sequencer_data[i]
			if slot.get("type", "rest") == "note":
				_start_drag("seq_cell", slot.get("note", 0), i)
				return

	# 从炼成槽开始拖拽
	for i in range(_alchemy_slot_rects.size()):
		if _alchemy_slot_rects[i].has_point(pos) and _alchemy_slots[i] >= 0:
			var note := _alchemy_slots[i]
			_alchemy_slots[i] = -1
			NoteInventory.unequip_note(note)
			_update_alchemy_preview()
			_start_drag("note", note, -1)
			return

func _start_drag(type: String, note: int, from_idx: int) -> void:
	_is_dragging = true
	_drag_started = false
	_drag_type = type
	_drag_note = note
	_drag_from_idx = from_idx

# ============================================================
# 左键释放
# ============================================================

func _handle_left_release(pos: Vector2) -> void:
	if not _is_dragging:
		return

	var was_started := _drag_started
	_is_dragging = false
	_drag_started = false

	if not was_started:
		# 没有真正拖拽，当作点击处理
		_handle_click_at(pos)
		return

	# 拖拽释放 — 检测目标
	_handle_drop(pos)

func _handle_click_at(pos: Vector2) -> void:
	# 点击序列器单元格 — 放置当前选中的音符
	for i in range(_seq_cell_rects.size()):
		if _seq_cell_rects[i].has_point(pos):
			if _drag_type == "note" and _drag_note >= 0:
				_place_note_in_sequencer(i, _drag_note)
			return

func _handle_drop(pos: Vector2) -> void:
	match _drag_type:
		"note":
			_handle_note_drop(pos)
		"black_key":
			_handle_black_key_drop(pos)
		"chord_spell":
			_handle_spell_drop(pos)
		"seq_cell":
			_handle_seq_cell_drop(pos)

func _handle_note_drop(pos: Vector2) -> void:
	# 放到序列器
	for i in range(_seq_cell_rects.size()):
		if _seq_cell_rects[i].has_point(pos):
			_place_note_in_sequencer(i, _drag_note)
			return

	# 放到炼成槽
	for i in range(_alchemy_slot_rects.size()):
		if _alchemy_slot_rects[i].has_point(pos):
			_place_note_in_alchemy(i, _drag_note)
			return

	# 放到手动施法槽
	for i in range(_manual_slot_rects.size()):
		if _manual_slot_rects[i].has_point(pos):
			_place_note_in_manual_slot(i, _drag_note)
			return

	# 未放到有效目标 — 不消耗

func _handle_black_key_drop(pos: Vector2) -> void:
	# 黑键修饰符目前只能应用到序列器中已有音符上
	for i in range(_seq_cell_rects.size()):
		if _seq_cell_rects[i].has_point(pos):
			if i < _sequencer_data.size() and _sequencer_data[i].get("type", "rest") == "note":
				_apply_modifier_to_seq(i, _drag_note)
				return

func _handle_spell_drop(pos: Vector2) -> void:
	# 放到序列器
	for i in range(_seq_cell_rects.size()):
		if _seq_cell_rects[i].has_point(pos):
			_place_spell_in_sequencer(i, _drag_spell_id)
			return

	# 放到手动施法槽
	for i in range(_manual_slot_rects.size()):
		if _manual_slot_rects[i].has_point(pos):
			_place_spell_in_manual_slot(i, _drag_spell_id)
			return

func _handle_seq_cell_drop(pos: Vector2) -> void:
	# 序列器内移动
	for i in range(_seq_cell_rects.size()):
		if _seq_cell_rects[i].has_point(pos) and i != _drag_from_idx:
			_move_seq_cell(_drag_from_idx, i)
			return

	# 放到手动施法槽
	for i in range(_manual_slot_rects.size()):
		if _manual_slot_rects[i].has_point(pos):
			if _drag_from_idx >= 0 and _drag_from_idx < _sequencer_data.size():
				var note_key: int = _sequencer_data[_drag_from_idx].get("note", 0)
				_clear_seq_cell(_drag_from_idx)
				_place_note_in_manual_slot(i, note_key)
				return

	# 放到炼成槽
	for i in range(_alchemy_slot_rects.size()):
		if _alchemy_slot_rects[i].has_point(pos):
			if _drag_from_idx >= 0 and _drag_from_idx < _sequencer_data.size():
				var note_key: int = _sequencer_data[_drag_from_idx].get("note", 0)
				_clear_seq_cell(_drag_from_idx)
				_place_note_in_alchemy(i, note_key)
				return

# ============================================================
# 右键点击
# ============================================================

func _handle_right_click(pos: Vector2) -> void:
	# 右键序列器 — 清除
	for i in range(_seq_cell_rects.size()):
		if _seq_cell_rects[i].has_point(pos):
			_clear_seq_cell(i)
			return

	# 右键炼成槽 — 移回库存
	for i in range(_alchemy_slot_rects.size()):
		if _alchemy_slot_rects[i].has_point(pos) and _alchemy_slots[i] >= 0:
			NoteInventory.unequip_note(_alchemy_slots[i])
			_alchemy_slots[i] = -1
			_update_alchemy_preview()
			return

	# 右键手动施法槽 — 清除
	for i in range(_manual_slot_rects.size()):
		if _manual_slot_rects[i].has_point(pos):
			_clear_manual_slot(i)
			return

# ============================================================
# 操作 — 序列器
# ============================================================

func _place_note_in_sequencer(idx: int, note_key: int) -> void:
	if not NoteInventory.equip_note(note_key):
		return  # 库存不足

	# 保存撤销状态
	_push_undo()

	# 如果目标格已有内容，先卸下
	if idx < _sequencer_data.size():
		var old_slot: Dictionary = _sequencer_data[idx]
		if old_slot.get("type", "rest") == "note":
			SpellcraftSystem.remove_from_sequencer(idx)

	SpellcraftSystem.place_note_in_sequencer(idx, note_key)
	_sequencer_data = SpellcraftSystem.get_sequencer_data()
	note_placed.emit(idx, note_key)

func _place_spell_in_sequencer(idx: int, spell_id: String) -> void:
	# 和弦法术占据一个小节的位置
	_push_undo()
	if SpellcraftSystem.has_method("place_chord_in_sequencer"):
		SpellcraftSystem.place_chord_in_sequencer(idx, spell_id)
	NoteInventory.mark_spell_equipped(spell_id, "sequencer_%d" % idx)
	_sequencer_data = SpellcraftSystem.get_sequencer_data()

func _clear_seq_cell(idx: int) -> void:
	if idx >= _sequencer_data.size():
		return
	_push_undo()
	SpellcraftSystem.remove_from_sequencer(idx)
	_sequencer_data = SpellcraftSystem.get_sequencer_data()
	cell_cleared.emit(idx)

func _move_seq_cell(from_idx: int, to_idx: int) -> void:
	_push_undo()
	if SpellcraftSystem.has_method("swap_sequencer_slots"):
		SpellcraftSystem.swap_sequencer_slots(from_idx, to_idx)
	_sequencer_data = SpellcraftSystem.get_sequencer_data()

func _apply_modifier_to_seq(idx: int, modifier_key: int) -> void:
	if NoteInventory.equip_black_key(modifier_key):
		if SpellcraftSystem.has_method("apply_modifier_to_slot"):
			SpellcraftSystem.apply_modifier_to_slot(idx, modifier_key)
		_sequencer_data = SpellcraftSystem.get_sequencer_data()

# ============================================================
# 操作 — 炼成
# ============================================================

func _place_note_in_alchemy(slot_idx: int, note_key: int) -> void:
	if _alchemy_slots[slot_idx] >= 0:
		# 已有音符，先返回
		NoteInventory.unequip_note(_alchemy_slots[slot_idx])

	if not NoteInventory.equip_note(note_key):
		return

	_alchemy_slots[slot_idx] = note_key
	_update_alchemy_preview()

func _update_alchemy_preview() -> void:
	var notes: Array[int] = []
	for slot in _alchemy_slots:
		if slot >= 0:
			notes.append(slot)

	_alchemy_preview = {}
	_alchemy_can_craft = false

	if notes.size() < MIN_NOTES_FOR_CHORD:
		return

	# 计算音程模式
	var midi_notes: Array[int] = []
	for n in notes:
		midi_notes.append(n)  # 简化：使用 WhiteKey 值
	midi_notes.sort()

	var root := midi_notes[0]
	var intervals: Array[int] = []
	for n in midi_notes:
		intervals.append(n - root)

	# 转换为半音音程（白键到半音映射）
	var semitone_map := [0, 2, 4, 5, 7, 9, 11]  # C D E F G A B
	var semitone_intervals: Array[int] = []
	for interval in intervals:
		if interval >= 0 and interval < semitone_map.size():
			semitone_intervals.append(semitone_map[interval])
		else:
			semitone_intervals.append(interval)

	var pattern_key := ",".join(semitone_intervals.map(func(x): return str(x)))

	if CHORD_PATTERNS.has(pattern_key):
		_alchemy_preview = CHORD_PATTERNS[pattern_key]
		_alchemy_can_craft = true

func _execute_alchemy() -> void:
	if not _alchemy_can_craft or _alchemy_preview.is_empty():
		return

	# 收集炼成槽中的音符
	var notes_to_consume: Array = []
	for slot in _alchemy_slots:
		if slot >= 0:
			notes_to_consume.append(slot)

	# 音符已经在放入炼成槽时从库存扣除了，这里直接创建法术
	var root_note: int = notes_to_consume[0]
	var spell_form: String = _alchemy_preview.get("spell_form", "generic_blast")
	var spell_name: String = "%s %s" % [
		MusicData.WHITE_KEY_STATS.get(root_note, {}).get("name", "?"),
		_alchemy_preview.get("name", "Unknown")
	]

	# 添加到法术书
	var chord_spell := NoteInventory.add_chord_spell(
		0,  # chord_type placeholder
		notes_to_consume,
		root_note,
		spell_form,
		spell_name
	)

	# 清空炼成槽（音符已消耗，不返回库存）
	for i in range(MAX_ALCHEMY_SLOTS):
		_alchemy_slots[i] = -1
	_alchemy_preview = {}
	_alchemy_can_craft = false

	chord_crafted.emit(chord_spell)
	alchemy_completed.emit(chord_spell)  # v3.0: 同步触发兼容信号

# ============================================================
# 操作 — 手动施法槽
# ============================================================

func _place_note_in_manual_slot(idx: int, note_key: int) -> void:
	if not NoteInventory.equip_note(note_key):
		return

	# 先清除旧内容
	_clear_manual_slot_internal(idx)

	_manual_slot_configs[idx] = { "type": "note", "note": note_key }
	SpellcraftSystem.configure_manual_slot(idx, { "type": "note", "note": note_key })
	manual_slot_configured.emit(idx, _manual_slot_configs[idx])

func _place_spell_in_manual_slot(idx: int, spell_id: String) -> void:
	_clear_manual_slot_internal(idx)

	_manual_slot_configs[idx] = { "type": "chord", "spell_id": spell_id }
	NoteInventory.mark_spell_equipped(spell_id, "manual_%d" % idx)
	SpellcraftSystem.configure_manual_slot(idx, _manual_slot_configs[idx])
	manual_slot_configured.emit(idx, _manual_slot_configs[idx])

func _clear_manual_slot(idx: int) -> void:
	_clear_manual_slot_internal(idx)
	_manual_slot_configs[idx] = { "type": "empty" }

func _clear_manual_slot_internal(idx: int) -> void:
	var config := _manual_slot_configs[idx]
	match config.get("type", "empty"):
		"note":
			NoteInventory.unequip_note(config.get("note", 0))
		"chord":
			NoteInventory.mark_spell_unequipped(config.get("spell_id", ""))
	SpellcraftSystem.clear_manual_slot(idx)

# ============================================================
# 撤销/重做
# ============================================================

func _push_undo() -> void:
	_undo_stack.append(_sequencer_data.duplicate(true))
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()
	_redo_stack.clear()

func undo() -> void:
	if _undo_stack.is_empty():
		return
	_redo_stack.append(_sequencer_data.duplicate(true))
	var state: Array = _undo_stack.pop_back()
	_restore_sequencer_state(state)

func redo() -> void:
	if _redo_stack.is_empty():
		return
	_undo_stack.append(_sequencer_data.duplicate(true))
	var state: Array = _redo_stack.pop_back()
	_restore_sequencer_state(state)

func _restore_sequencer_state(state: Array) -> void:
	# 先清空所有序列器槽
	for i in range(TOTAL_CELLS):
		SpellcraftSystem.remove_from_sequencer(i)
	# 恢复状态
	for i in range(state.size()):
		var slot: Dictionary = state[i]
		if slot.get("type", "rest") == "note":
			SpellcraftSystem.place_note_in_sequencer(i, slot.get("note", 0))
	_sequencer_data = SpellcraftSystem.get_sequencer_data()

# ============================================================
# 信号回调
# ============================================================

func _on_beat_tick(_beat_index: int) -> void:
	_beat_flash = 1.0
	_playhead_position = SpellcraftSystem.get_sequencer_position()

func _on_sequencer_updated() -> void:
	_sequencer_data = SpellcraftSystem.get_sequencer_data()

func _on_inventory_changed(_note_key: int, _new_count: int) -> void:
	if _is_open:
		queue_redraw()

func _on_spellbook_changed(_spellbook: Array) -> void:
	if _is_open:
		_calculate_spellbook_layout()
		queue_redraw()
