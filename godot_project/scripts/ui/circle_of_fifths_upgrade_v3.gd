## circle_of_fifths_upgrade_v3.gd
## v3.0 五度圈罗盘升级系统 (统一升级入口)
##
## 核心改造：
##   1. 废除 upgrade_panel.gd 的三选一，本系统成为唯一的局内升级界面
##   2. 两阶段选择：先选方向（顺时针/当前/逆时针），再从该方向池中选择具体升级
##   3. 局外成长可视化：由和谐殿堂解锁的升级拥有特殊金色标识
##   4. 乐理突破事件：稀有事件，在罗盘中央浮现，解锁核心机制
##   5. 章节词条整合：词条作为特殊选项出现在对应方向中
##
## 交互流程：
##   Phase 1 — 方向选择：罗盘展示三个方向区域，玩家点击选择
##   Phase 2 — 具体选择：选定方向后，展示2-3个具体升级选项
##   特殊  — 乐理突破：低概率触发，替代方向选择，直接展示突破选项
##
extends Control

# ============================================================
# 信号
# ============================================================
signal upgrade_chosen(upgrade: Dictionary)

# ============================================================
# 常量 — 五度圈
# ============================================================
const CIRCLE_KEYS := ["C", "G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F"]
const CIRCLE_SIZE: int = 12

## 罗盘视觉参数
const COMPASS_RADIUS: float = 160.0
const COMPASS_INNER_RADIUS: float = 55.0
const KEY_LABEL_RADIUS: float = 180.0
const POINTER_LENGTH: float = 120.0
const TICK_LENGTH: float = 12.0

## 方向区域参数（Phase 1）
const DIRECTION_ARC_RADIUS: float = 220.0
const DIRECTION_LABEL_RADIUS: float = 250.0

## 选项卡片参数（Phase 2）
const OPTION_CARD_SIZE := Vector2(220, 120)
const OPTION_CARD_RADIUS: float = 260.0
const OPTIONS_PER_DIRECTION: int = 3

## 乐理突破参数
const BREAKTHROUGH_CHANCE: float = 0.08  # 8%概率触发
const BREAKTHROUGH_ICON_SIZE: float = 40.0

# ============================================================
# 常量 — 颜色
# ============================================================
const BG_OVERLAY := Color(0.0, 0.0, 0.02, 0.8)
const COMPASS_BG := Color(0.04, 0.03, 0.08, 0.9)
const COMPASS_RING := Color(0.25, 0.2, 0.4, 0.6)
const COMPASS_INNER := Color(0.06, 0.05, 0.12, 0.95)
const POINTER_COLOR := Color(1.0, 0.9, 0.4, 0.9)
const TICK_COLOR := Color(0.3, 0.25, 0.45, 0.5)
const TICK_ACTIVE := Color(0.8, 0.7, 1.0, 0.9)
const KEY_LABEL := Color(0.5, 0.45, 0.65, 0.7)
const KEY_LABEL_ACTIVE := Color(1.0, 0.95, 0.8, 1.0)
const TITLE_COLOR := Color(0.8, 0.75, 0.95, 0.9)

## 方向颜色
const DIRECTION_COLORS := {
	"clockwise": Color(1.0, 0.4, 0.2, 0.9),        # 进攻 — 火焰橙
	"current": Color(0.2, 0.8, 1.0, 0.9),            # 核心 — 冰蓝
	"counter_clockwise": Color(0.3, 1.0, 0.5, 0.9),  # 防御 — 翠绿
}

## 方向悬停颜色
const DIRECTION_HOVER_COLORS := {
	"clockwise": Color(1.0, 0.5, 0.3, 1.0),
	"current": Color(0.3, 0.9, 1.0, 1.0),
	"counter_clockwise": Color(0.4, 1.0, 0.6, 1.0),
}

## 稀有度颜色
const RARITY_COLORS := {
	"common": Color(0.6, 0.6, 0.6),
	"rare": Color(0.2, 0.6, 1.0),
	"epic": Color(0.7, 0.3, 1.0),
	"legendary": Color(1.0, 0.8, 0.0),
}

## 局外成长标识颜色
const META_UNLOCK_BORDER := Color(1.0, 0.85, 0.2, 0.9)
const META_UNLOCK_GLOW := Color(1.0, 0.9, 0.4, 0.3)

## 乐理突破颜色
const BREAKTHROUGH_COLOR := Color(1.0, 0.95, 0.6, 1.0)
const BREAKTHROUGH_GLOW := Color(1.0, 0.9, 0.3, 0.4)

# ============================================================
# 升级池 — 按方向分类 (继承并扩展自 v2.0)
# ============================================================

const CLOCKWISE_UPGRADES := [
	{
		"id": "dmg_boost_all", "category": "note_stat", "rarity": "common",
		"name": "音波增幅", "desc": "当前调性音符 DMG +0.5",
		"stat": "dmg", "value": 0.5,
	},
	{
		"id": "spd_boost_all", "category": "note_stat", "rarity": "common",
		"name": "音速强化", "desc": "当前调性音符 SPD +0.5",
		"stat": "spd", "value": 0.5,
	},
	{
		"id": "chord_power", "category": "chord_mastery", "rarity": "rare",
		"name": "和弦威力", "desc": "所有和弦伤害倍率 +0.1x",
		"type": "chord_power", "value": 0.1,
	},
	{
		"id": "bpm_boost", "category": "rhythm_mastery", "rarity": "rare",
		"name": "节奏加速", "desc": "基础 BPM +5",
		"type": "bpm_boost", "value": 5.0,
	},
	{
		"id": "perfect_beat_bonus", "category": "special", "rarity": "epic",
		"name": "完美节奏", "desc": "节拍对齐施法伤害 +25%",
		"type": "perfect_beat_bonus", "value": 0.25,
	},
	{
		"id": "chord_progression_boost", "category": "special", "rarity": "epic",
		"name": "和声进行", "desc": "和弦进行效果 +50%",
		"type": "chord_progression_boost", "value": 0.5,
	},
	{
		"id": "modifier_pierce", "category": "modifier_mastery", "rarity": "rare",
		"name": "穿透精通", "desc": "穿透效果增强，穿透数 +1",
		"type": "modifier_boost", "modifier": 0, "value": 1,
	},
	{
		"id": "modifier_split", "category": "modifier_mastery", "rarity": "rare",
		"name": "分裂精通", "desc": "分裂弹体数量 +1",
		"type": "modifier_boost", "modifier": 2, "value": 1,
	},
	# 音色精通 — 进攻向
	{
		"id": "timbre_harmonic_amp", "category": "timbre_mastery", "rarity": "common",
		"name": "泛音增幅", "desc": "里拉琴共鸣伤害 +10%",
		"type": "timbre_boost", "timbre": MusicData.ChapterTimbre.LYRE, "value": 0.10,
	},
	{
		"id": "timbre_counterpoint_acc", "category": "timbre_mastery", "rarity": "rare",
		"name": "对位精度", "desc": "羽管键琴对位弹体伤害 60% → 70%",
		"type": "timbre_boost", "timbre": MusicData.ChapterTimbre.HARPSICHORD, "value": 0.10,
	},
	{
		"id": "timbre_velocity_master", "category": "timbre_mastery", "rarity": "rare",
		"name": "力度大师", "desc": "钢琴 forte 伤害倍率 1.5 → 1.8",
		"type": "timbre_boost", "timbre": MusicData.ChapterTimbre.FORTEPIANO, "value": 0.30,
	},
	# 节奏型精通
	{
		"id": "rhythm_even_boost", "category": "rhythm_mastery", "rarity": "rare",
		"name": "连射精通", "desc": "连射节奏型弹体数量 +1",
		"type": "rhythm_boost", "rhythm": 0, "value": 1,
	},
	{
		"id": "rhythm_triplet_boost", "category": "rhythm_mastery", "rarity": "rare",
		"name": "三连精通", "desc": "三连发伤害倍率 +0.2x",
		"type": "rhythm_boost", "rhythm": 4, "value": 0.2,
	},
]

const CURRENT_UPGRADES := [
	{
		"id": "note_acquire_random", "category": "note_acquire", "rarity": "common",
		"name": "随机音符", "desc": "获得1个随机音符",
		"type": "random_note", "value": 1,
	},
	{
		"id": "note_acquire_specific", "category": "note_acquire", "rarity": "rare",
		"name": "指定音符", "desc": "获得1个当前调性根音",
		"type": "specific_note", "value": 1,
	},
	{
		"id": "all_boost", "category": "note_stat", "rarity": "epic",
		"name": "全维强化", "desc": "当前调性音符所有参数 +0.25",
		"stat": "all", "value": 0.25,
	},
	{
		"id": "timbre_switch_free", "category": "timbre_mastery", "rarity": "epic",
		"name": "音色自如", "desc": "音色切换不再产生疲劳",
		"type": "timbre_switch_free",
	},
	{
		"id": "extended_unlock", "category": "chord_mastery", "rarity": "legendary",
		"name": "扩展和弦解锁", "desc": "解锁5-6音扩展和弦",
		"type": "extended_unlock",
	},
	{
		"id": "multi_modifier", "category": "special", "rarity": "legendary",
		"name": "复合修饰", "desc": "允许同时应用2个黑键修饰符",
		"type": "multi_modifier",
	},
	# 音色精通 — 核心向
	{
		"id": "timbre_waveform_fusion", "category": "timbre_mastery", "rarity": "epic",
		"name": "波形融合", "desc": "合成主脑可同时激活两种波形",
		"type": "timbre_boost", "timbre": MusicData.ChapterTimbre.SYNTHESIZER, "value": 1,
	},
	{
		"id": "note_acquire_double", "category": "note_acquire", "rarity": "rare",
		"name": "音符丰收", "desc": "获得2个随机音符",
		"type": "random_note", "value": 2,
	},
]

const COUNTER_CLOCKWISE_UPGRADES := [
	{
		"id": "max_hp", "category": "survival", "rarity": "common",
		"name": "生命强化", "desc": "最大生命值 +25",
		"type": "max_hp", "value": 25.0,
	},
	{
		"id": "dodge", "category": "survival", "rarity": "rare",
		"name": "闪避本能", "desc": "基础闪避率 +3%",
		"type": "dodge", "value": 0.03,
	},
	{
		"id": "monotony_resist", "category": "fatigue_resist", "rarity": "rare",
		"name": "单调耐受", "desc": "单调值累积速率 -10%",
		"type": "monotony_resist", "value": 0.1,
	},
	{
		"id": "dissonance_decay", "category": "fatigue_resist", "rarity": "rare",
		"name": "不和谐消散", "desc": "不和谐值自然衰减 +0.5/秒",
		"type": "dissonance_decay", "value": 0.5,
	},
	{
		"id": "density_resist", "category": "fatigue_resist", "rarity": "rare",
		"name": "密度耐受", "desc": "密度疲劳累积速率 -10%",
		"type": "density_resist", "value": 0.1,
	},
	{
		"id": "modifier_homing", "category": "modifier_mastery", "rarity": "rare",
		"name": "追踪精通", "desc": "追踪速度 +50%",
		"type": "modifier_boost", "modifier": 1, "value": 0.5,
	},
	{
		"id": "modifier_echo", "category": "modifier_mastery", "rarity": "rare",
		"name": "回响精通", "desc": "回响次数 +1",
		"type": "modifier_boost", "modifier": 3, "value": 1,
	},
	# 音色精通 — 防御向
	{
		"id": "timbre_voice_extend", "category": "timbre_mastery", "rarity": "common",
		"name": "声部扩展", "desc": "管风琴最大声部层 +1（5 层）",
		"type": "timbre_boost", "timbre": MusicData.ChapterTimbre.ORGAN, "value": 1,
	},
	{
		"id": "timbre_emotion_resonance", "category": "timbre_mastery", "rarity": "rare",
		"name": "情感共鸣", "desc": "管弦全奏情感强度递增速度 +50%",
		"type": "timbre_boost", "timbre": MusicData.ChapterTimbre.TUTTI, "value": 0.50,
	},
	{
		"id": "rhythm_rest_boost", "category": "rhythm_mastery", "rarity": "rare",
		"name": "蓄力精通", "desc": "休止符蓄力加成 +0.3/个",
		"type": "rhythm_boost", "rhythm": 5, "value": 0.3,
	},
	{
		"id": "electronic_variant_unlock", "category": "timbre_mastery", "rarity": "rare",
		"name": "电子乐变体", "desc": "将当前音色武器切换为电子乐变体（疲劳 -50%）",
		"type": "electronic_variant",
	},
]

# ============================================================
# 乐理突破事件池
# ============================================================
const BREAKTHROUGH_EVENTS := [
	{
		"id": "bt_seventh_chords", "name": "七和弦觉醒",
		"desc": "解锁七和弦系列：属七、大七、小七、减七和弦",
		"type": "unlock_seventh_chords",
		"rarity": "legendary",
		"icon": "VII",
	},
	{
		"id": "bt_extended_chords", "name": "扩展和弦领悟",
		"desc": "解锁5-6音扩展和弦：九和弦、十一和弦、十三和弦",
		"type": "extended_unlock",
		"rarity": "legendary",
		"icon": "EXT",
	},
	{
		"id": "bt_black_key_mastery", "name": "黑键精通",
		"desc": "黑键修饰符效果翻倍，解锁双重修饰",
		"type": "black_key_mastery",
		"rarity": "legendary",
		"icon": "#b",
	},
	{
		"id": "bt_chord_progression", "name": "和声进行觉醒",
		"desc": "解锁和弦功能转换系统：T→D→T 循环产生额外效果",
		"type": "chord_progression_unlock",
		"rarity": "legendary",
		"icon": "I-V",
	},
	{
		"id": "bt_modal_interchange", "name": "调式交替",
		"desc": "允许在同一局内切换调式，每次切换获得临时增益",
		"type": "modal_interchange",
		"rarity": "legendary",
		"icon": "M↔",
	},
]

# ============================================================
# 状态
# ============================================================
## 交互阶段
enum Phase { DIRECTION_SELECT, OPTION_SELECT, BREAKTHROUGH }
var _current_phase: Phase = Phase.DIRECTION_SELECT

## 五度圈指针
var _current_key_index: int = 0
var _pointer_target_angle: float = 0.0
var _pointer_current_angle: float = 0.0

## 方向选择
var _hover_direction: String = ""  # "clockwise", "current", "counter_clockwise"
var _selected_direction: String = ""

## 具体选项
var _current_options: Array[Dictionary] = []
var _hover_option: int = -1
var _option_rects: Array[Rect2] = []

## 乐理突破
var _breakthrough_event: Dictionary = {}
var _hover_breakthrough: bool = false
var _breakthrough_rect: Rect2 = Rect2()

## 动画
var _appear_progress: float = 0.0
var _phase_transition: float = 0.0
var _option_appear: Array[float] = []
var _breakthrough_pulse: float = 0.0

## 面板状态
var _is_visible: bool = false
var _center: Vector2 = Vector2.ZERO

## 方向区域矩形（用于点击检测）
var _direction_rects: Dictionary = {}  # String → Rect2

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	visible = false
	GameManager.game_state_changed.connect(_on_game_state_changed)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if not _is_visible:
		return

	# 指针旋转动画
	_pointer_current_angle = lerp(_pointer_current_angle, _pointer_target_angle, delta * 4.0)

	# 出现动画
	_appear_progress = min(1.0, _appear_progress + delta * 3.0)

	# 阶段过渡动画
	_phase_transition = min(1.0, _phase_transition + delta * 4.0)

	# 选项出现动画
	for i in range(_option_appear.size()):
		_option_appear[i] = min(1.0, _option_appear[i] + delta * (2.5 + i * 0.5))

	# 突破脉冲动画
	if _current_phase == Phase.BREAKTHROUGH:
		_breakthrough_pulse = fmod(_breakthrough_pulse + delta * 2.0, TAU)

	queue_redraw()

# ============================================================
# 显示/隐藏
# ============================================================

func show_upgrade_options() -> void:
	# 检查是否触发乐理突破
	if _should_trigger_breakthrough():
		_setup_breakthrough()
	else:
		_setup_direction_select()

	_is_visible = true
	visible = true
	_appear_progress = 0.0
	_pointer_target_angle = _key_index_to_angle(_current_key_index)
	_pointer_current_angle = _pointer_target_angle
	queue_redraw()

func hide_panel() -> void:
	_is_visible = false
	visible = false

func _setup_direction_select() -> void:
	_current_phase = Phase.DIRECTION_SELECT
	_phase_transition = 0.0
	_hover_direction = ""
	_selected_direction = ""
	_current_options.clear()

func _setup_option_select(direction: String) -> void:
	_current_phase = Phase.OPTION_SELECT
	_selected_direction = direction
	_phase_transition = 0.0
	_hover_option = -1
	_generate_options_for_direction(direction)
	_option_appear.clear()
	for i in range(_current_options.size()):
		_option_appear.append(0.0)

func _setup_breakthrough() -> void:
	_current_phase = Phase.BREAKTHROUGH
	_phase_transition = 0.0
	_breakthrough_pulse = 0.0
	_hover_breakthrough = false

	# 选择一个未触发的突破事件
	var available: Array = []
	for event in BREAKTHROUGH_EVENTS:
		if not _is_breakthrough_acquired(event["id"]):
			available.append(event)
	if available.is_empty():
		# 所有突破已获得，回退到普通选择
		_setup_direction_select()
		return
	available.shuffle()
	_breakthrough_event = available[0]

func _should_trigger_breakthrough() -> bool:
	# 检查是否有未获得的突破事件
	var has_available := false
	for event in BREAKTHROUGH_EVENTS:
		if not _is_breakthrough_acquired(event["id"]):
			has_available = true
			break
	if not has_available:
		return false
	return randf() < BREAKTHROUGH_CHANCE

func _is_breakthrough_acquired(event_id: String) -> bool:
	for upgrade in GameManager.acquired_upgrades:
		if upgrade.get("id", "") == event_id:
			return true
	return false

# ============================================================
# 选项生成
# ============================================================

func _generate_options_for_direction(direction: String) -> void:
	_current_options.clear()
	var pool: Array = []

	match direction:
		"clockwise":
			pool = CLOCKWISE_UPGRADES.duplicate(true)
		"current":
			pool = CURRENT_UPGRADES.duplicate(true)
		"counter_clockwise":
			pool = COUNTER_CLOCKWISE_UPGRADES.duplicate(true)

	# 过滤已满的升级
	if GameManager.extended_chords_unlocked:
		pool = pool.filter(func(u): return u.get("id", "") != "extended_unlock")

	# 注入调性上下文
	for upgrade in pool:
		_inject_key_context(upgrade)

	# 随机选择
	pool.shuffle()
	for i in range(min(OPTIONS_PER_DIRECTION, pool.size())):
		_current_options.append(pool[i])

	# 章节词条插入（15%概率替换一个选项）
	if randf() < MusicData.INSCRIPTION_APPEAR_CHANCE:
		var unacquired := GameManager.get_unacquired_inscriptions()
		if not unacquired.is_empty():
			var inscription: Dictionary = unacquired[randi() % unacquired.size()]
			var inscription_option := _create_inscription_option(inscription)
			if not _current_options.is_empty():
				_current_options[randi() % _current_options.size()] = inscription_option

func _inject_key_context(upgrade: Dictionary) -> void:
	var current_key_name: String = CIRCLE_KEYS[_current_key_index]
	if upgrade.get("category", "") == "note_stat":
		var target_note := _key_name_to_white_key(current_key_name)
		if target_note >= 0:
			upgrade["target_note"] = target_note
			upgrade["desc"] = upgrade.get("desc", "").replace("当前调性", current_key_name)
	if upgrade.get("type", "") == "specific_note":
		var target_note := _key_name_to_white_key(current_key_name)
		if target_note >= 0:
			upgrade["target_note"] = target_note
			upgrade["desc"] = "获得1个 %s 音符" % current_key_name

func _create_inscription_option(inscription: Dictionary) -> Dictionary:
	var rarity_map := {
		MusicData.InscriptionRarity.COMMON: "common",
		MusicData.InscriptionRarity.RARE: "rare",
		MusicData.InscriptionRarity.EPIC: "epic",
	}
	var rarity_str: String = rarity_map.get(inscription.get("rarity", 0), "common")
	var color_map := {
		MusicData.InscriptionRarity.COMMON: Color(0.7, 0.7, 0.5),
		MusicData.InscriptionRarity.RARE: Color(0.3, 0.7, 1.0),
		MusicData.InscriptionRarity.EPIC: Color(0.8, 0.4, 1.0),
	}
	var synergy_text: String = inscription.get("synergy_desc", "")
	var full_desc: String = inscription.get("desc", "")
	if synergy_text != "":
		full_desc += "\n★ 协同: " + synergy_text
	return {
		"id": inscription["id"],
		"category": "inscription",
		"rarity": rarity_str,
		"name": "【词条】" + inscription.get("name", "???"),
		"desc": full_desc,
		"inscription": inscription,
		"icon_color": color_map.get(inscription.get("rarity", 0), Color.WHITE),
	}

# ============================================================
# 绘制 — 主入口
# ============================================================

func _draw() -> void:
	if not _is_visible:
		return

	_center = get_viewport_rect().size / 2.0
	var font := ThemeDB.fallback_font
	var scale := _appear_progress

	# 背景遮罩
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BG_OVERLAY)

	# 标题
	var title_alpha := clampf(_appear_progress * 2.0, 0.0, 1.0)
	var tc := TITLE_COLOR
	tc.a = title_alpha
	draw_string(font, Vector2(_center.x - 50, _center.y - COMPASS_RADIUS - 55),
		"LEVEL UP", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, tc)

	# 副标题（根据阶段变化）
	var subtitle := ""
	match _current_phase:
		Phase.DIRECTION_SELECT:
			subtitle = "Choose your musical direction"
		Phase.OPTION_SELECT:
			var dir_name := _get_direction_display_name(_selected_direction)
			subtitle = "%s — Select an upgrade" % dir_name
		Phase.BREAKTHROUGH:
			subtitle = "★ THEORY BREAKTHROUGH ★"

	var sc := Color(0.6, 0.55, 0.75, title_alpha * 0.7)
	if _current_phase == Phase.BREAKTHROUGH:
		sc = BREAKTHROUGH_COLOR
		sc.a = title_alpha * 0.9
	draw_string(font, Vector2(_center.x - 100, _center.y - COMPASS_RADIUS - 33),
		subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, sc)

	# 罗盘
	_draw_compass_ring(scale)
	_draw_key_ticks(font, scale)
	_draw_pointer(scale)
	_draw_compass_center(font, scale)

	# 根据阶段绘制不同内容
	match _current_phase:
		Phase.DIRECTION_SELECT:
			_draw_direction_select(font)
		Phase.OPTION_SELECT:
			_draw_option_select(font)
		Phase.BREAKTHROUGH:
			_draw_breakthrough(font)

# ============================================================
# 绘制 — 罗盘基础
# ============================================================

func _draw_compass_ring(scale: float) -> void:
	draw_arc(_center, COMPASS_RADIUS * scale, 0, TAU, 64, COMPASS_RING, 2.0)
	draw_arc(_center, COMPASS_INNER_RADIUS * scale, 0, TAU, 32, COMPASS_RING * 0.5, 1.0)

func _draw_key_ticks(font: Font, scale: float) -> void:
	for i in range(CIRCLE_SIZE):
		var angle := _key_index_to_angle(i)
		var outer := _center + Vector2(cos(angle), sin(angle)) * COMPASS_RADIUS * scale
		var inner := _center + Vector2(cos(angle), sin(angle)) * (COMPASS_RADIUS - TICK_LENGTH) * scale
		var label_pos := _center + Vector2(cos(angle), sin(angle)) * KEY_LABEL_RADIUS * scale

		var is_active := (i == _current_key_index)
		var tc := TICK_ACTIVE if is_active else TICK_COLOR
		var tw := 2.5 if is_active else 1.0
		draw_line(inner, outer, tc, tw)

		var lc := KEY_LABEL_ACTIVE if is_active else KEY_LABEL
		var ls := 13 if is_active else 9
		draw_string(font, label_pos + Vector2(-8, 5), CIRCLE_KEYS[i],
			HORIZONTAL_ALIGNMENT_CENTER, -1, ls, lc)

		if is_active:
			draw_circle(outer, 3.5 * scale, POINTER_COLOR * 0.6)

func _draw_pointer(scale: float) -> void:
	var angle := _pointer_current_angle
	var tip := _center + Vector2(cos(angle), sin(angle)) * POINTER_LENGTH * scale
	var bl := _center + Vector2(cos(angle + 2.8), sin(angle + 2.8)) * 7.0 * scale
	var br := _center + Vector2(cos(angle - 2.8), sin(angle - 2.8)) * 7.0 * scale
	draw_colored_polygon(PackedVector2Array([tip, bl, br]), POINTER_COLOR)
	draw_line(_center, tip, POINTER_COLOR * 0.4, 1.5)

func _draw_compass_center(font: Font, scale: float) -> void:
	draw_circle(_center, COMPASS_INNER_RADIUS * scale * 0.8, COMPASS_INNER)
	draw_arc(_center, COMPASS_INNER_RADIUS * scale * 0.8, 0, TAU, 32, COMPASS_RING * 0.7, 1.5)
	var key_name: String = CIRCLE_KEYS[_current_key_index]
	draw_string(font, _center + Vector2(-10, -5), key_name,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 26, POINTER_COLOR)
	draw_string(font, _center + Vector2(-15, 16), "Lv.%d" % GameManager.player_level,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.6, 0.55, 0.75, 0.8))

# ============================================================
# 绘制 — Phase 1: 方向选择
# ============================================================

func _draw_direction_select(font: Font) -> void:
	_direction_rects.clear()
	var directions := ["counter_clockwise", "current", "clockwise"]
	var dir_labels := ["DEFENSE", "CORE", "ATTACK"]
	var dir_descs := ["Survival & Resources", "Key Strengthening", "Damage & Speed"]

	# 三个方向区域分布在罗盘外围
	var angles: Array[float] = []
	angles.append(_key_index_to_angle((_current_key_index - 1 + CIRCLE_SIZE) % CIRCLE_SIZE))
	angles.append(_key_index_to_angle(_current_key_index))
	angles.append(_key_index_to_angle((_current_key_index + 1) % CIRCLE_SIZE))

	for i in range(3):
		var dir := directions[i]
		var angle := angles[i]
		var progress := clampf(_phase_transition * 2.0 - i * 0.2, 0.0, 1.0)
		if progress < 0.01:
			continue

		var card_center := _center + Vector2(cos(angle), sin(angle)) * DIRECTION_ARC_RADIUS
		var card_size := Vector2(180, 80) * progress
		var card_pos := card_center - card_size / 2.0
		var card_rect := Rect2(card_pos, card_size)
		_direction_rects[dir] = card_rect

		var is_hover := (_hover_direction == dir)
		var dir_color: Color = DIRECTION_COLORS.get(dir, Color.WHITE)
		if is_hover:
			dir_color = DIRECTION_HOVER_COLORS.get(dir, dir_color)

		# 卡片背景
		var bg := Color(0.06, 0.05, 0.12, 0.9 * progress)
		if is_hover:
			bg = Color(0.1, 0.08, 0.18, 0.95 * progress)
		draw_rect(card_rect, bg)

		# 方向色边框
		var bc := dir_color
		bc.a = (0.8 if is_hover else 0.5) * progress
		draw_rect(card_rect, bc, false, 2.0 if is_hover else 1.5)

		# 方向标签
		var lc := dir_color
		lc.a = 0.9 * progress
		draw_string(font, card_rect.position + Vector2(card_size.x / 2.0 - 25, 28),
			dir_labels[i], HORIZONTAL_ALIGNMENT_CENTER, -1, 14, lc)

		# 描述
		var dc := Color(0.6, 0.55, 0.75, 0.7 * progress)
		draw_string(font, card_rect.position + Vector2(card_size.x / 2.0 - 50, 50),
			dir_descs[i], HORIZONTAL_ALIGNMENT_CENTER, -1, 9, dc)

		# 底部方向指示条
		var bar_rect := Rect2(
			Vector2(card_rect.position.x, card_rect.position.y + card_size.y - 3),
			Vector2(card_size.x, 3)
		)
		var bar_color := dir_color
		bar_color.a = 0.6 * progress
		draw_rect(bar_rect, bar_color)

# ============================================================
# 绘制 — Phase 2: 具体选项
# ============================================================

func _draw_option_select(font: Font) -> void:
	_option_rects.clear()

	if _current_options.is_empty():
		return

	var dir_color: Color = DIRECTION_COLORS.get(_selected_direction, Color.WHITE)

	# 返回按钮提示
	var back_alpha := clampf(_phase_transition * 2.0, 0.0, 1.0)
	draw_string(font, Vector2(_center.x - 40, _center.y + COMPASS_RADIUS + 50),
		"[Right-click to go back]", HORIZONTAL_ALIGNMENT_CENTER, -1, 9,
		Color(0.5, 0.45, 0.6, 0.5 * back_alpha))

	# 选项卡片分布
	var option_count := _current_options.size()
	var total_width := option_count * (OPTION_CARD_SIZE.x + 15.0) - 15.0
	var start_x := _center.x - total_width / 2.0

	for i in range(option_count):
		var progress := _option_appear[i] if i < _option_appear.size() else 0.0
		if progress < 0.01:
			_option_rects.append(Rect2())
			continue

		var card_x := start_x + i * (OPTION_CARD_SIZE.x + 15.0)
		var card_y := _center.y + COMPASS_RADIUS + 70.0
		var card_rect := Rect2(Vector2(card_x, card_y), OPTION_CARD_SIZE * progress)
		_option_rects.append(card_rect)

		var option := _current_options[i]
		var is_hover := (_hover_option == i)
		_draw_option_card(card_rect, option, is_hover, font, progress, dir_color)

func _draw_option_card(rect: Rect2, option: Dictionary, is_hover: bool,
		font: Font, alpha: float, dir_color: Color) -> void:
	var rarity: String = option.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.GRAY)

	# 检查是否为局外成长解锁的升级
	var is_meta_unlock := _is_meta_unlocked_upgrade(option)

	# 卡片背景
	var bg := Color(0.06, 0.05, 0.12, 0.92 * alpha)
	if is_hover:
		bg = Color(0.1, 0.08, 0.18, 0.95 * alpha)
	draw_rect(rect, bg)

	# 边框（局外成长升级使用金色边框）
	var border_color := dir_color
	if is_meta_unlock:
		border_color = META_UNLOCK_BORDER
		# 金色发光效果
		var glow_rect := rect.grow(2)
		draw_rect(glow_rect, META_UNLOCK_GLOW, false, 3.0)
	border_color.a = (0.8 if is_hover else 0.5) * alpha
	draw_rect(rect, border_color, false, 2.0 if is_hover else 1.5)

	# 局外成长标识
	if is_meta_unlock:
		var badge_pos := rect.position + Vector2(rect.size.x - 20, 8)
		draw_string(font, badge_pos, "★", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, META_UNLOCK_BORDER)

	# 稀有度标签
	var rl := rarity_color
	rl.a = 0.7 * alpha
	draw_string(font, rect.position + Vector2(8, 16), "[%s]" % rarity.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, rl)

	# 升级名称
	var nc := Color.WHITE
	nc.a = alpha
	draw_string(font, rect.position + Vector2(8, 40), option.get("name", "???"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, nc)

	# 描述
	var dc := Color(0.7, 0.65, 0.8)
	dc.a = 0.8 * alpha
	var desc_text: String = option.get("desc", "")
	# 简单的文本换行处理
	if desc_text.length() > 35:
		var line1 := desc_text.left(35)
		var line2 := desc_text.substr(35)
		draw_string(font, rect.position + Vector2(8, 62), line1,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, dc)
		draw_string(font, rect.position + Vector2(8, 76), line2,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, dc)
	else:
		draw_string(font, rect.position + Vector2(8, 62), desc_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, dc)

	# 底部方向指示条
	var bar := Rect2(
		Vector2(rect.position.x, rect.position.y + rect.size.y - 3),
		Vector2(rect.size.x, 3)
	)
	var bc := dir_color
	bc.a = 0.6 * alpha
	draw_rect(bar, bc)

# ============================================================
# 绘制 — 乐理突破
# ============================================================

func _draw_breakthrough(font: Font) -> void:
	if _breakthrough_event.is_empty():
		return

	var progress := clampf(_phase_transition, 0.0, 1.0)
	var pulse := sin(_breakthrough_pulse) * 0.15 + 0.85

	# 中央发光效果
	var glow_radius := COMPASS_INNER_RADIUS * 1.5 * progress * pulse
	draw_arc(_center, glow_radius, 0, TAU, 48, BREAKTHROUGH_GLOW, 4.0)
	draw_arc(_center, glow_radius * 0.7, 0, TAU, 32, BREAKTHROUGH_GLOW * 0.5, 2.0)

	# 突破卡片
	var card_size := Vector2(320, 160) * progress
	var card_pos := Vector2(_center.x - card_size.x / 2.0, _center.y + COMPASS_RADIUS + 30)
	var card_rect := Rect2(card_pos, card_size)
	_breakthrough_rect = card_rect

	var bg := Color(0.08, 0.06, 0.04, 0.95 * progress)
	if _hover_breakthrough:
		bg = Color(0.12, 0.1, 0.06, 0.98 * progress)
	draw_rect(card_rect, bg)

	# 金色边框（脉冲效果）
	var bc := BREAKTHROUGH_COLOR
	bc.a = pulse * progress
	draw_rect(card_rect, bc, false, 2.5)
	draw_rect(card_rect.grow(3), BREAKTHROUGH_GLOW * pulse, false, 1.5)

	# 图标
	var icon_text: String = _breakthrough_event.get("icon", "?")
	draw_string(font, card_pos + Vector2(card_size.x / 2.0 - 12, 35),
		icon_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, BREAKTHROUGH_COLOR)

	# 标题
	draw_string(font, card_pos + Vector2(card_size.x / 2.0 - 60, 65),
		_breakthrough_event.get("name", "???"), HORIZONTAL_ALIGNMENT_CENTER, -1, 16,
		Color(1.0, 0.95, 0.8, progress))

	# 描述
	draw_string(font, card_pos + Vector2(15, 95),
		_breakthrough_event.get("desc", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.8, 0.75, 0.6, 0.85 * progress))

	# 提示
	draw_string(font, card_pos + Vector2(card_size.x / 2.0 - 40, card_size.y - 15),
		"Click to acquire", HORIZONTAL_ALIGNMENT_CENTER, -1, 10,
		Color(0.6, 0.55, 0.4, 0.6 * progress * pulse))

# ============================================================
# 输入处理
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if not _is_visible:
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_left_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click()

func _handle_mouse_motion(pos: Vector2) -> void:
	match _current_phase:
		Phase.DIRECTION_SELECT:
			_hover_direction = ""
			for dir in _direction_rects.keys():
				if _direction_rects[dir].has_point(pos):
					_hover_direction = dir
					break
		Phase.OPTION_SELECT:
			_hover_option = -1
			for i in range(_option_rects.size()):
				if not _option_rects[i].size == Vector2.ZERO and _option_rects[i].has_point(pos):
					_hover_option = i
					break
		Phase.BREAKTHROUGH:
			_hover_breakthrough = _breakthrough_rect.has_point(pos)

func _handle_left_click(pos: Vector2) -> void:
	match _current_phase:
		Phase.DIRECTION_SELECT:
			for dir in _direction_rects.keys():
				if _direction_rects[dir].has_point(pos):
					_setup_option_select(dir)
					return
		Phase.OPTION_SELECT:
			for i in range(_option_rects.size()):
				if not _option_rects[i].size == Vector2.ZERO and _option_rects[i].has_point(pos):
					_select_option(i)
					return
		Phase.BREAKTHROUGH:
			if _breakthrough_rect.has_point(pos):
				_select_breakthrough()

func _handle_right_click() -> void:
	# 在选项阶段，右键返回方向选择
	if _current_phase == Phase.OPTION_SELECT:
		_setup_direction_select()

# ============================================================
# 选择处理
# ============================================================

func _select_option(option_index: int) -> void:
	if option_index < 0 or option_index >= _current_options.size():
		return

	var option := _current_options[option_index]

	# 更新指针方向
	match _selected_direction:
		"clockwise":
			_current_key_index = (_current_key_index + 1) % CIRCLE_SIZE
		"counter_clockwise":
			_current_key_index = (_current_key_index - 1 + CIRCLE_SIZE) % CIRCLE_SIZE
		"current":
			pass

	_pointer_target_angle = _key_index_to_angle(_current_key_index)

	# 处理音符获取类升级
	_process_note_acquisition(option)

	# 应用升级到 GameManager
	GameManager.apply_upgrade(option)

	upgrade_chosen.emit(option)
	hide_panel()
	GameManager.resume_game()

func _select_breakthrough() -> void:
	if _breakthrough_event.is_empty():
		return

	# 将突破事件作为升级应用
	var upgrade := {
		"id": _breakthrough_event["id"],
		"category": "breakthrough",
		"rarity": "legendary",
		"name": _breakthrough_event.get("name", "???"),
		"desc": _breakthrough_event.get("desc", ""),
		"type": _breakthrough_event.get("type", ""),
	}

	GameManager.apply_upgrade(upgrade)

	# 特殊处理
	match _breakthrough_event.get("type", ""):
		"extended_unlock":
			GameManager.extended_chords_unlocked = true
		"black_key_mastery":
			pass  # SpellcraftSystem 会读取 acquired_upgrades
		"chord_progression_unlock":
			pass  # SpellcraftSystem 会读取 acquired_upgrades

	upgrade_chosen.emit(upgrade)
	hide_panel()
	GameManager.resume_game()

func _process_note_acquisition(upgrade: Dictionary) -> void:
	var upgrade_type: String = upgrade.get("type", "")
	if upgrade_type == "random_note":
		var amount: int = int(upgrade.get("value", 1))
		for i in range(amount):
			NoteInventory.add_random_note(1, "level_up")
	elif upgrade_type == "specific_note":
		var target_note: int = upgrade.get("target_note", -1)
		if target_note >= 0:
			NoteInventory.add_specific_note(target_note, 1, "level_up")
		else:
			NoteInventory.add_random_note(1, "level_up")

# ============================================================
# 局外成长可视化
# ============================================================

func _is_meta_unlocked_upgrade(upgrade: Dictionary) -> bool:
	## 检查该升级是否由局外成长（和谐殿堂）解锁
	var meta := get_node_or_null("/root/MetaProgressionManager")
	if meta == null:
		return false

	# 检查升级ID是否在局外解锁列表中
	if meta.has_method("is_upgrade_unlocked"):
		return meta.is_upgrade_unlocked(upgrade.get("id", ""))

	# 回退：检查传说级升级是否与局外成长相关
	var rarity: String = upgrade.get("rarity", "common")
	if rarity == "legendary":
		return true  # 传说级升级通常需要局外解锁

	return false

# ============================================================
# 工具函数
# ============================================================

func _key_index_to_angle(index: int) -> float:
	return -PI / 2.0 + float(index) * TAU / float(CIRCLE_SIZE)

func _key_name_to_white_key(key_name: String) -> int:
	match key_name:
		"C": return 0
		"D": return 1
		"E": return 2
		"F": return 3
		"G": return 4
		"A": return 5
		"B": return 6
	return -1

func _get_direction_display_name(direction: String) -> String:
	match direction:
		"clockwise": return "ATTACK"
		"current": return "CORE"
		"counter_clockwise": return "DEFENSE"
	return direction

# ============================================================
# 信号回调
# ============================================================

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.UPGRADE_SELECT:
		show_upgrade_options()
	elif _is_visible:
		hide_panel()
