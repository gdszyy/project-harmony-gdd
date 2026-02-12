## circle_of_fifths_upgrade_v3.gd
## v3.1 五度圈罗盘升级系统 — 完整 UI 重写
##
## 根据 UI_Design_Module4_CircleOfFifths.md 设计文档实现：
##   1. 圆形罗盘布局：外圈大调音级环、中圈关系小调环、内圈连接线、核心星云区
##   2. 两阶段选择流程：方向选择（进攻/核心/防御）→ 具体升级卡片
##   3. 三方向视觉区分：进攻 Dominant黄 / 核心 晶体白 / 防御 治愈绿
##   4. 乐理突破事件：稀有事件，金色特殊 UI，跳过常规流程
##   5. 金色高亮标识：局外解锁升级的殿堂徽章
##   6. Tween 动画驱动的完整交互流程
##   7. 键盘/手柄支持
##
## 场景树结构 (由 _draw() 自绘制)：
##   CircleOfFifthsUpgradeV3 (Control)
##   ├── BackgroundOverlay (全屏暗色遮罩)
##   ├── CompassRoot (罗盘主体)
##   │   ├── OuterRing (大调音级环)
##   │   ├── MiddleRing (关系小调环)
##   │   ├── ConnectionWeb (连接线网络)
##   │   └── NebulaCoreVFX (中心星云)
##   ├── DirectionSelectionLayer (方向选择)
##   ├── CardSelectionLayer (卡片选择)
##   └── TheoryBreakthroughLayer (乐理突破)
extends Control

# ============================================================
# 信号
# ============================================================
signal upgrade_chosen(upgrade: Dictionary)
signal upgrade_cancelled

# ============================================================
# 枚举
# ============================================================
enum Phase { INACTIVE, DIRECTION_SELECT, CARD_SELECT, THEORY_BREAKTHROUGH }

# ============================================================
# 常量 — 五度圈音级序列
# ============================================================
const CIRCLE_KEYS := ["C", "G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F"]
const MINOR_KEYS := ["Am", "Em", "Bm", "F#m", "C#m", "G#m", "Ebm", "Bbm", "Fm", "Cm", "Gm", "Dm"]
const CIRCLE_SIZE: int = 12

# ============================================================
# 布局参数 — @export 支持编辑器实时调整
# ============================================================
@export_group("Compass Layout")
@export var compass_outer_radius: float = 200.0    ## 外圈大调音级环半径
@export var compass_middle_radius: float = 165.0   ## 中圈关系小调环半径
@export var compass_inner_radius: float = 130.0    ## 内圈连接线半径
@export var compass_core_radius: float = 80.0      ## 核心星云区半径
@export var key_label_radius: float = 220.0        ## 大调标签半径
@export var minor_label_radius: float = 180.0      ## 小调标签半径
@export var tick_length: float = 15.0              ## 刻度线长度

@export_group("Direction Runes")
@export var rune_radius: float = 280.0             ## 符文距中心距离
@export var rune_size: float = 50.0                ## 符文图标大小
@export var rune_hover_scale: float = 1.1          ## 悬停放大

@export_group("Upgrade Cards")
@export var card_width: float = 240.0
@export var card_height: float = 320.0
@export var card_spacing: float = 20.0
@export var card_hover_scale: float = 1.15
@export var card_hover_offset_y: float = -8.0
@export var options_per_direction: int = 3

@export_group("Theory Breakthrough")
@export var breakthrough_chance: float = 0.08
@export var breakthrough_card_width: float = 320.0
@export var breakthrough_card_height: float = 440.0
@export var breakthrough_ray_count: int = 24

@export_group("Animation")
@export var anim_standard: float = 0.3
@export var anim_emphasis: float = 0.5
@export var anim_card_stagger: float = 0.1

# ============================================================
# 常量 — 颜色体系 (严格遵循 UI 设计文档 §1.2)
# ============================================================
## 全局 UI 主题
const COL_PANEL_BG := Color("#141026")        ## 星空紫 80%
const COL_ACCENT := Color("#9D6FFF")          ## 谐振紫
const COL_TEXT_PRIMARY := Color("#EAE6FF")     ## 晶体白
const COL_TEXT_SECONDARY := Color("#A098C8")   ## 星云灰
const COL_HOLY_GOLD := Color("#FFD700")        ## 圣光金
const COL_CURRENT_KEY := Color("#00FFD4")      ## 谐振青
const COL_DEEP_BLACK := Color("#0A0814")       ## 深渊黑

## 三方向色 (设计文档 §3.1)
const COL_OFFENSE := Color("#FFE066")          ## Dominant 黄
const COL_DEFENSE := Color("#66FFB2")          ## 治愈绿
const COL_CORE := Color("#EAE6FF")             ## 晶体白

## 方向色映射
const DIRECTION_COLORS := {
	"offense": Color("#FFE066"),
	"defense": Color("#66FFB2"),
	"core": Color("#EAE6FF"),
}

## 背景遮罩
const BG_OVERLAY := Color(0.0, 0.0, 0.02, 0.75)

## 稀有度颜色
const RARITY_COLORS := {
	"common": Color(0.7, 0.7, 0.75),
	"rare": Color(0.3, 0.5, 1.0),
	"epic": Color(0.7, 0.3, 1.0),
	"legendary": Color(1.0, 0.85, 0.2),
}

## ============================================================
# 升级数据库 — 从 JSON 配置文件加载
# ============================================================
const UPGRADE_DB_PATH := "res://data/upgrades/upgrade_database.json"
var _upgrade_db_loaded: bool = false
var OFFENSE_UPGRADES: Array = []
var CORE_UPGRADES: Array = []
var DEFENSE_UPGRADES: Array = []
var BREAKTHROUGH_EVENTS: Array = []

## 加载升级数据库
func _load_upgrade_database() -> void:
	var file := FileAccess.open(UPGRADE_DB_PATH, FileAccess.READ)
	if file == null:
		push_error("CircleOfFifthsUpgradeV3: 无法加载升级数据库: %s" % UPGRADE_DB_PATH)
		_use_legacy_data()
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("CircleOfFifthsUpgradeV3: JSON 解析失败: %s" % json.get_error_message())
		_use_legacy_data()
		return
	var data: Dictionary = json.data
	OFFENSE_UPGRADES = _resolve_timbre_enums(data.get("offense_upgrades", []))
	CORE_UPGRADES = _resolve_timbre_enums(data.get("core_upgrades", []))
	DEFENSE_UPGRADES = _resolve_timbre_enums(data.get("defense_upgrades", []))
	BREAKTHROUGH_EVENTS = data.get("breakthrough_events", [])
	_upgrade_db_loaded = true
	print("[CircleOfFifthsUpgradeV3] 已加载升级数据库: %d/%d/%d + %d 突破" % [
		OFFENSE_UPGRADES.size(), CORE_UPGRADES.size(), DEFENSE_UPGRADES.size(), BREAKTHROUGH_EVENTS.size()])

## 将 JSON 中的音色字符串转换为 MusicData.ChapterTimbre 枚举值
func _resolve_timbre_enums(upgrades: Array) -> Array:
	var timbre_map := {
		"LYRE": MusicData.ChapterTimbre.LYRE,
		"ORGAN": MusicData.ChapterTimbre.ORGAN,
		"HARPSICHORD": MusicData.ChapterTimbre.HARPSICHORD,
		"FORTEPIANO": MusicData.ChapterTimbre.FORTEPIANO,
		"TUTTI": MusicData.ChapterTimbre.TUTTI,
		"SYNTHESIZER": MusicData.ChapterTimbre.SYNTHESIZER,
	}
	for upgrade in upgrades:
		if upgrade.has("timbre") and upgrade["timbre"] is String:
			var key: String = upgrade["timbre"]
			if timbre_map.has(key):
				upgrade["timbre"] = timbre_map[key]
	return upgrades

## 回退：使用内联备份数据
func _use_legacy_data() -> void:
	OFFENSE_UPGRADES = _OFFENSE_UPGRADES_LEGACY.duplicate(true)
	CORE_UPGRADES = _CORE_UPGRADES_LEGACY.duplicate(true)
	DEFENSE_UPGRADES = _DEFENSE_UPGRADES_LEGACY.duplicate(true)
	BREAKTHROUGH_EVENTS = _BREAKTHROUGH_EVENTS_LEGACY.duplicate(true)
	_upgrade_db_loaded = true
	push_warning("[CircleOfFifthsUpgradeV3] 使用内联备份数据")

# 以下为原始硬编码数据的备份引用（已迁移至 data/upgrades/upgrade_database.json）
const _OFFENSE_UPGRADES_LEGACY := [
	{
		"id": "dmg_boost_all", "category": "note_stat", "rarity": "common",
		"name": "音波增幅", "desc": "当前调性音符 DMG +0.5",
		"stat": "dmg", "value": 0.5,
		"tags": ["进攻", "伤害"],
	},
	{
		"id": "spd_boost_all", "category": "note_stat", "rarity": "common",
		"name": "音速强化", "desc": "当前调性音符 SPD +0.5",
		"stat": "spd", "value": 0.5,
		"tags": ["进攻", "速度"],
	},
	{
		"id": "chord_power", "category": "chord_mastery", "rarity": "rare",
		"name": "和弦威力", "desc": "所有和弦伤害倍率 +0.1x",
		"type": "chord_power", "value": 0.1,
		"tags": ["进攻", "和弦"],
	},
	{
		"id": "bpm_boost", "category": "rhythm_mastery", "rarity": "rare",
		"name": "节奏加速", "desc": "基础 BPM +5",
		"type": "bpm_boost", "value": 5.0,
		"tags": ["进攻", "节奏"],
	},
	{
		"id": "perfect_beat_bonus", "category": "special", "rarity": "epic",
		"name": "完美节奏", "desc": "节拍对齐施法伤害 +25%",
		"type": "perfect_beat_bonus", "value": 0.25,
		"tags": ["进攻", "节奏"],
	},
	{
		"id": "chord_progression_boost", "category": "special", "rarity": "epic",
		"name": "和声进行", "desc": "和弦进行效果 +50%",
		"type": "chord_progression_boost", "value": 0.5,
		"tags": ["进攻", "和弦"],
	},
	{
		"id": "modifier_pierce", "category": "modifier_mastery", "rarity": "rare",
		"name": "穿透精通", "desc": "穿透效果增强，穿透数 +1",
		"type": "modifier_boost", "modifier": 0, "value": 1,
		"tags": ["进攻", "修饰符"],
	},
	{
		"id": "modifier_split", "category": "modifier_mastery", "rarity": "rare",
		"name": "分裂精通", "desc": "分裂弹体数量 +1",
		"type": "modifier_boost", "modifier": 2, "value": 1,
		"tags": ["进攻", "修饰符"],
	},
	{
		"id": "timbre_harmonic_amp", "category": "timbre_mastery", "rarity": "common",
		"name": "泛音增幅", "desc": "里拉琴共鸣伤害 +10%",
		"type": "timbre_boost", "timbre": MusicData.ChapterTimbre.LYRE, "value": 0.10,
		"tags": ["进攻", "音色"],
	},
	{
		"id": "timbre_counterpoint_acc", "category": "timbre_mastery", "rarity": "rare",
		"name": "对位精度", "desc": "羽管键琴对位弹体伤害 60% → 70%",
		"type": "timbre_boost", "timbre": MusicData.ChapterTimbre.HARPSICHORD, "value": 0.10,
		"tags": ["进攻", "音色"],
	},
	{
		"id": "timbre_velocity_master", "category": "timbre_mastery", "rarity": "rare",
		"name": "力度大师", "desc": "钢琴 forte 伤害倍率 1.5 → 1.8",
		"type": "timbre_boost", "timbre": MusicData.ChapterTimbre.FORTEPIANO, "value": 0.30,
		"tags": ["进攻", "音色"],
	},
	{
		"id": "rhythm_even_boost", "category": "rhythm_mastery", "rarity": "rare",
		"name": "连射精通", "desc": "连射节奏型弹体数量 +1",
		"type": "rhythm_boost", "rhythm": 0, "value": 1,
		"tags": ["进攻", "节奏"],
	},
	{
		"id": "rhythm_triplet_boost", "category": "rhythm_mastery", "rarity": "rare",
		"name": "三连精通", "desc": "三连发伤害倍率 +0.2x",
		"type": "rhythm_boost", "rhythm": 4, "value": 0.2,
		"tags": ["进攻", "节奏"],
	},
]

const _CORE_UPGRADES_LEGACY := [
	{
		"id": "note_acquire_random", "category": "note_acquire", "rarity": "common",
		"name": "随机音符", "desc": "获得1个随机音符",
		"type": "random_note", "value": 1,
		"tags": ["核心", "音符"],
	},
	{
		"id": "note_acquire_specific", "category": "note_acquire", "rarity": "rare",
		"name": "指定音符", "desc": "获得1个当前调性根音",
		"type": "specific_note", "value": 1,
		"tags": ["核心", "音符"],
	},
	{
		"id": "all_boost", "category": "note_stat", "rarity": "epic",
		"name": "全维强化", "desc": "当前调性音符所有参数 +0.25",
		"stat": "all", "value": 0.25,
		"tags": ["核心", "强化"],
	},
	{
		"id": "timbre_switch_free", "category": "timbre_mastery", "rarity": "epic",
		"name": "音色自如", "desc": "音色切换不再产生疲劳",
		"type": "timbre_switch_free",
		"tags": ["核心", "音色"],
	},
	{
		"id": "extended_unlock", "category": "chord_mastery", "rarity": "legendary",
		"name": "扩展和弦解锁", "desc": "解锁5-6音扩展和弦",
		"type": "extended_unlock",
		"tags": ["核心", "和弦"],
	},
	{
		"id": "multi_modifier", "category": "special", "rarity": "legendary",
		"name": "复合修饰", "desc": "允许同时应用2个黑键修饰符",
		"type": "multi_modifier",
		"tags": ["核心", "修饰符"],
	},
	{
		"id": "timbre_waveform_fusion", "category": "timbre_mastery", "rarity": "epic",
		"name": "波形融合", "desc": "合成主脑可同时激活两种波形",
		"type": "timbre_boost", "timbre": MusicData.ChapterTimbre.SYNTHESIZER, "value": 1,
		"tags": ["核心", "音色"],
	},
	{
		"id": "note_acquire_double", "category": "note_acquire", "rarity": "rare",
		"name": "音符丰收", "desc": "获得2个随机音符",
		"type": "random_note", "value": 2,
		"tags": ["核心", "音符"],
	},
]

const _DEFENSE_UPGRADES_LEGACY := [
	{
		"id": "max_hp", "category": "survival", "rarity": "common",
		"name": "生命强化", "desc": "最大生命值 +25",
		"type": "max_hp", "value": 25.0,
		"tags": ["防御", "生存"],
	},
	{
		"id": "dodge", "category": "survival", "rarity": "rare",
		"name": "闪避本能", "desc": "基础闪避率 +3%",
		"type": "dodge", "value": 0.03,
		"tags": ["防御", "生存"],
	},
	{
		"id": "monotony_resist", "category": "fatigue_resist", "rarity": "rare",
		"name": "单调耐受", "desc": "单调值累积速率 -10%",
		"type": "monotony_resist", "value": 0.1,
		"tags": ["防御", "疲劳"],
	},
	{
		"id": "dissonance_decay", "category": "fatigue_resist", "rarity": "rare",
		"name": "不和谐消散", "desc": "不和谐值自然衰减 +0.5/秒",
		"type": "dissonance_decay", "value": 0.5,
		"tags": ["防御", "疲劳"],
	},
	{
		"id": "density_resist", "category": "fatigue_resist", "rarity": "rare",
		"name": "密度耐受", "desc": "密度疲劳累积速率 -10%",
		"type": "density_resist", "value": 0.1,
		"tags": ["防御", "疲劳"],
	},
	{
		"id": "modifier_homing", "category": "modifier_mastery", "rarity": "rare",
		"name": "追踪精通", "desc": "追踪速度 +50%",
		"type": "modifier_boost", "modifier": 1, "value": 0.5,
		"tags": ["防御", "修饰符"],
	},
	{
		"id": "modifier_echo", "category": "modifier_mastery", "rarity": "rare",
		"name": "回响精通", "desc": "回响次数 +1",
		"type": "modifier_boost", "modifier": 3, "value": 1,
		"tags": ["防御", "修饰符"],
	},
	{
		"id": "timbre_voice_extend", "category": "timbre_mastery", "rarity": "common",
		"name": "声部扩展", "desc": "管风琴最大声部层 +1（5 层）",
		"type": "timbre_boost", "timbre": MusicData.ChapterTimbre.ORGAN, "value": 1,
		"tags": ["防御", "音色"],
	},
	{
		"id": "timbre_emotion_resonance", "category": "timbre_mastery", "rarity": "rare",
		"name": "情感共鸣", "desc": "管弦全奏情感强度递增速度 +50%",
		"type": "timbre_boost", "timbre": MusicData.ChapterTimbre.TUTTI, "value": 0.50,
		"tags": ["防御", "音色"],
	},
	{
		"id": "rhythm_rest_boost", "category": "rhythm_mastery", "rarity": "rare",
		"name": "蓄力精通", "desc": "休止符蓄力加成 +0.3/个",
		"type": "rhythm_boost", "rhythm": 5, "value": 0.3,
		"tags": ["防御", "节奏"],
	},
	{
		"id": "electronic_variant_unlock", "category": "timbre_mastery", "rarity": "rare",
		"name": "电子乐变体", "desc": "将当前音色武器切换为电子乐变体（疲劳 -50%）",
		"type": "electronic_variant",
		"tags": ["防御", "音色"],
	},
]

# ============================================================
# 乐理突破事件池
# ============================================================
const _BREAKTHROUGH_EVENTS_LEGACY := [
	{
		"id": "bt_seventh_chords", "name": "七和弦觉醒",
		"desc": "解锁七和弦系列：属七、大七、小七、减七和弦",
		"type": "unlock_seventh_chords", "rarity": "legendary", "icon": "VII",
	},
	{
		"id": "bt_extended_chords", "name": "扩展和弦领悟",
		"desc": "解锁5-6音扩展和弦：九和弦、十一和弦、十三和弦",
		"type": "extended_unlock", "rarity": "legendary", "icon": "EXT",
	},
	{
		"id": "bt_black_key_mastery", "name": "黑键精通",
		"desc": "黑键修饰符效果翻倍，解锁双重修饰",
		"type": "black_key_mastery", "rarity": "legendary", "icon": "#b",
	},
	{
		"id": "bt_chord_progression", "name": "和声进行觉醒",
		"desc": "解锁和弦功能转换系统：T→D→T 循环产生额外效果",
		"type": "chord_progression_unlock", "rarity": "legendary", "icon": "I-V",
	},
	{
		"id": "bt_modal_interchange", "name": "调式交替",
		"desc": "允许在同一局内切换调式，每次切换获得临时增益",
		"type": "modal_interchange", "rarity": "legendary", "icon": "M↔",
	},
]

# ============================================================
# 状态变量
# ============================================================
var _current_phase: Phase = Phase.INACTIVE
var _current_key_index: int = 0
var _pointer_target_angle: float = 0.0
var _pointer_current_angle: float = 0.0

## 方向选择
var _hover_direction: String = ""  ## "offense", "defense", "core"
var _selected_direction: String = ""
var _direction_hover_areas: Dictionary = {}  ## String → { center: Vector2, radius: float }

## 升级卡片
var _current_options: Array[Dictionary] = []
var _hover_card: int = -1
var _card_rects: Array[Rect2] = []

## 乐理突破
var _breakthrough_event: Dictionary = {}
var _hover_breakthrough: bool = false
var _breakthrough_rect: Rect2 = Rect2()

## 动画状态
var _appear_progress: float = 0.0
var _phase_transition: float = 0.0
var _card_appear: Array[float] = []
var _breakthrough_pulse: float = 0.0
var _rune_pulse: Array[float] = [0.0, 0.0, 0.0]  ## offense, core, defense
var _compass_rotation_offset: float = 0.0
var _nebula_rotation: float = 0.0
var _current_key_glow: float = 0.0
var _direction_trail_progress: float = 0.0

## 面板状态
var _is_visible: bool = false
var _center: Vector2 = Vector2.ZERO
var _time: float = 0.0

## 首次引导
var _is_first_time: bool = true
var _tutorial_step: int = -1  ## -1 = 无引导

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_upgrade_database()
	GameManager.game_state_changed.connect(_on_game_state_changed)

func _process(delta: float) -> void:
	if not _is_visible:
		return

	_time += delta

	# 指针旋转平滑
	_pointer_current_angle = lerp_angle(_pointer_current_angle, _pointer_target_angle, delta * 4.0)

	# 出现动画
	_appear_progress = minf(1.0, _appear_progress + delta * 2.5)

	# 阶段过渡
	_phase_transition = minf(1.0, _phase_transition + delta * 3.0)

	# 卡片出现动画
	for i in range(_card_appear.size()):
		_card_appear[i] = minf(1.0, _card_appear[i] + delta * (2.0 + i * 0.5))

	# 符文脉冲
	for i in range(3):
		_rune_pulse[i] = fmod(_rune_pulse[i] + delta * (1.5 + i * 0.3), TAU)

	# 星云旋转
	_nebula_rotation = fmod(_nebula_rotation + delta * 0.3, TAU)

	# 当前调性呼吸发光
	_current_key_glow = sin(_time * 2.0) * 0.15 + 0.85

	# 乐理突破脉冲
	if _current_phase == Phase.THEORY_BREAKTHROUGH:
		_breakthrough_pulse = fmod(_breakthrough_pulse + delta * 2.0, TAU)

	# 方向悬停轨迹动画
	if _hover_direction != "" and _current_phase == Phase.DIRECTION_SELECT:
		_direction_trail_progress = minf(1.0, _direction_trail_progress + delta * 3.0)
	else:
		_direction_trail_progress = maxf(0.0, _direction_trail_progress - delta * 5.0)

	queue_redraw()

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

func _unhandled_key_input(event: InputEvent) -> void:
	if not _is_visible:
		return
	if not event.is_pressed():
		return

	match _current_phase:
		Phase.DIRECTION_SELECT:
			# 键盘/手柄支持 (设计文档 §3.3)
			if event.is_action("ui_right") or (event is InputEventKey and event.keycode == KEY_D):
				_select_direction("offense")
			elif event.is_action("ui_up") or (event is InputEventKey and event.keycode == KEY_W):
				_select_direction("core")
			elif event.is_action("ui_left") or (event is InputEventKey and event.keycode == KEY_A):
				_select_direction("defense")
		Phase.CARD_SELECT:
			if event.is_action("ui_left"):
				_hover_card = maxi(0, _hover_card - 1)
			elif event.is_action("ui_right"):
				_hover_card = mini(_current_options.size() - 1, _hover_card + 1)
			elif event.is_action("ui_accept"):
				if _hover_card >= 0 and _hover_card < _current_options.size():
					_select_option(_hover_card)
			elif event.is_action("ui_cancel"):
				_handle_right_click()
		Phase.THEORY_BREAKTHROUGH:
			if event.is_action("ui_accept"):
				_select_breakthrough()

func _handle_mouse_motion(pos: Vector2) -> void:
	match _current_phase:
		Phase.DIRECTION_SELECT:
			_hover_direction = ""
			for dir_key in _direction_hover_areas.keys():
				var area: Dictionary = _direction_hover_areas[dir_key]
				if pos.distance_to(area["center"]) < area["radius"]:
					_hover_direction = dir_key
					break
			if _hover_direction == "":
				_direction_trail_progress = 0.0
		Phase.CARD_SELECT:
			_hover_card = -1
			for i in range(_card_rects.size()):
				if _card_rects[i].has_point(pos):
					_hover_card = i
					break
		Phase.THEORY_BREAKTHROUGH:
			_hover_breakthrough = _breakthrough_rect.has_point(pos)

func _handle_left_click(pos: Vector2) -> void:
	match _current_phase:
		Phase.DIRECTION_SELECT:
			for dir_key in _direction_hover_areas.keys():
				var area: Dictionary = _direction_hover_areas[dir_key]
				if pos.distance_to(area["center"]) < area["radius"]:
					_select_direction(dir_key)
					return
		Phase.CARD_SELECT:
			for i in range(_card_rects.size()):
				if _card_rects[i].has_point(pos):
					_select_option(i)
					return
		Phase.THEORY_BREAKTHROUGH:
			if _breakthrough_rect.has_point(pos):
				_select_breakthrough()

func _handle_right_click() -> void:
	if _current_phase == Phase.CARD_SELECT:
		_setup_direction_select()

# ============================================================
# 显示/隐藏 & 阶段管理
# ============================================================

func show_upgrade_options() -> void:
	if _should_trigger_breakthrough():
		_setup_breakthrough()
	else:
		_setup_direction_select()

	_is_visible = true
	visible = true
	_appear_progress = 0.0
	_pointer_target_angle = _key_index_to_angle(_current_key_index)
	_pointer_current_angle = _pointer_target_angle
	_time = 0.0
	queue_redraw()

func hide_panel() -> void:
	_is_visible = false
	visible = false
	_current_phase = Phase.INACTIVE

func _setup_direction_select() -> void:
	_current_phase = Phase.DIRECTION_SELECT
	_phase_transition = 0.0
	_hover_direction = ""
	_selected_direction = ""
	_current_options.clear()
	_direction_trail_progress = 0.0

func _setup_card_select(direction: String) -> void:
	_current_phase = Phase.CARD_SELECT
	_selected_direction = direction
	_phase_transition = 0.0
	_hover_card = -1
	_generate_options_for_direction(direction)
	_card_appear.clear()
	for i in range(_current_options.size()):
		_card_appear.append(0.0)

func _setup_breakthrough() -> void:
	_current_phase = Phase.THEORY_BREAKTHROUGH
	_phase_transition = 0.0
	_breakthrough_pulse = 0.0
	_hover_breakthrough = false

	var available: Array = []
	for event in BREAKTHROUGH_EVENTS:
		if not _is_breakthrough_acquired(event["id"]):
			available.append(event)
	if available.is_empty():
		_setup_direction_select()
		return
	available.shuffle()
	_breakthrough_event = available[0]

func _should_trigger_breakthrough() -> bool:
	var has_available := false
	for event in BREAKTHROUGH_EVENTS:
		if not _is_breakthrough_acquired(event["id"]):
			has_available = true
			break
	if not has_available:
		return false
	return randf() < breakthrough_chance

func _is_breakthrough_acquired(event_id: String) -> bool:
	for upgrade in GameManager.acquired_upgrades:
		if upgrade.get("id", "") == event_id:
			return true
	return false

# ============================================================
# 方向选择处理
# ============================================================

func _select_direction(direction: String) -> void:
	_selected_direction = direction
	# 使用 Tween 过渡动画
	var tween := create_tween()
	tween.set_parallel(true)
	# 罗盘旋转到对应方向
	var target_rotation := 0.0
	match direction:
		"offense":
			target_rotation = -PI / 6.0  ## 顺时针偏移
		"defense":
			target_rotation = PI / 6.0   ## 逆时针偏移
		"core":
			target_rotation = 0.0
	tween.tween_property(self, "_compass_rotation_offset", target_rotation, anim_standard)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_callback(_setup_card_select.bind(direction))

# ============================================================
# 选项生成
# ============================================================

func _generate_options_for_direction(direction: String) -> void:
	_current_options.clear()
	var pool: Array = []

	match direction:
		"offense":
			pool = OFFENSE_UPGRADES.duplicate(true)
		"core":
			pool = CORE_UPGRADES.duplicate(true)
		"defense":
			pool = DEFENSE_UPGRADES.duplicate(true)

	# 过滤已满的升级
	if GameManager.extended_chords_unlocked:
		pool = pool.filter(func(u): return u.get("id", "") != "extended_unlock")

	# 注入调性上下文
	for upgrade in pool:
		_inject_key_context(upgrade)

	# 随机选择
	pool.shuffle()
	for i in range(mini(options_per_direction, pool.size())):
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
		"tags": ["词条"],
	}

# ============================================================
# 选择处理
# ============================================================

func _select_option(option_index: int) -> void:
	if option_index < 0 or option_index >= _current_options.size():
		return

	var option := _current_options[option_index]

	# 更新指针方向
	match _selected_direction:
		"offense":
			_current_key_index = (_current_key_index + 1) % CIRCLE_SIZE
		"defense":
			_current_key_index = (_current_key_index - 1 + CIRCLE_SIZE) % CIRCLE_SIZE
		"core":
			pass

	_pointer_target_angle = _key_index_to_angle(_current_key_index)

	# 处理音符获取类升级
	_process_note_acquisition(option)

	# 应用升级
	GameManager.apply_upgrade(option)

	upgrade_chosen.emit(option)
	_play_card_confirm_animation(option_index)

func _select_breakthrough() -> void:
	if _breakthrough_event.is_empty():
		return

	var upgrade := {
		"id": _breakthrough_event["id"],
		"category": "breakthrough",
		"rarity": "legendary",
		"name": _breakthrough_event.get("name", "???"),
		"desc": _breakthrough_event.get("desc", ""),
		"type": _breakthrough_event.get("type", ""),
	}

	GameManager.apply_upgrade(upgrade)

	match _breakthrough_event.get("type", ""):
		"extended_unlock":
			GameManager.extended_chords_unlocked = true

	upgrade_chosen.emit(upgrade)
	_play_breakthrough_confirm_animation()

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
# 动画
# ============================================================

func _play_card_confirm_animation(card_index: int) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	# 背景淡出
	tween.tween_property(self, "_appear_progress", 0.0, anim_standard)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_callback(_deactivate_compass)

func _play_breakthrough_confirm_animation() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_appear_progress", 0.0, anim_emphasis)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_deactivate_compass)

func _deactivate_compass() -> void:
	hide_panel()
	GameManager.resume_game()

# ============================================================
# 局外成长可视化
# ============================================================

func _is_meta_unlocked_upgrade(upgrade: Dictionary) -> bool:
	var meta := get_node_or_null("/root/MetaProgressionManager")
	if meta == null:
		return false
	if meta.has_method("is_upgrade_unlocked"):
		return meta.is_upgrade_unlocked(upgrade.get("id", ""))
	if meta.has_method("is_theory_unlocked"):
		return meta.is_theory_unlocked(upgrade.get("id", ""))
	var rarity: String = upgrade.get("rarity", "common")
	if rarity == "legendary":
		return true
	return false

# ============================================================
# 绘制 — 主入口
# ============================================================

func _draw() -> void:
	if not _is_visible:
		return

	_center = get_viewport_rect().size / 2.0
	var font := ThemeDB.fallback_font
	var alpha := _appear_progress

	# 1. 背景遮罩
	var overlay_color := BG_OVERLAY
	overlay_color.a *= alpha
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), overlay_color)

	# 2. 罗盘主体
	_draw_nebula_core(alpha)
	_draw_connection_web(alpha)
	_draw_outer_ring(font, alpha)
	_draw_middle_ring(font, alpha)
	_draw_current_key_highlight(font, alpha)

	# 3. 标题
	_draw_title(font, alpha)

	# 4. 根据阶段绘制
	match _current_phase:
		Phase.DIRECTION_SELECT:
			_draw_direction_runes(font)
		Phase.CARD_SELECT:
			_draw_upgrade_cards(font)
		Phase.THEORY_BREAKTHROUGH:
			_draw_breakthrough_event(font)

# ============================================================
# 绘制 — 星云核心
# ============================================================

func _draw_nebula_core(alpha: float) -> void:
	var scale := alpha
	# 核心区域深色背景
	var core_color := COL_PANEL_BG
	core_color.a = 0.95 * alpha
	draw_circle(_center, compass_core_radius * scale, core_color)

	# 星云效果 — 多层同心圆模拟旋转星云
	var layers := 5
	for i in range(layers):
		var t := float(i) / float(layers)
		var r := compass_core_radius * scale * (0.3 + t * 0.7)
		var nebula_color := COL_ACCENT
		nebula_color.a = (0.08 - t * 0.015) * alpha
		var offset_angle := _nebula_rotation + t * PI * 0.5
		var offset := Vector2(cos(offset_angle), sin(offset_angle)) * 3.0 * (1.0 - t)
		draw_arc(_center + offset, r, 0, TAU, 48, nebula_color, 2.0 - t)

	# 核心边缘辉光
	var glow_color := COL_ACCENT
	glow_color.a = 0.25 * alpha * _current_key_glow
	draw_arc(_center, compass_core_radius * scale, 0, TAU, 48, glow_color, 3.0)

# ============================================================
# 绘制 — 连接线网络
# ============================================================

func _draw_connection_web(alpha: float) -> void:
	var scale := alpha
	for i in range(CIRCLE_SIZE):
		var angle_a := _key_index_to_angle(i) + _compass_rotation_offset
		var angle_b := _key_index_to_angle((i + 1) % CIRCLE_SIZE) + _compass_rotation_offset
		var pos_a := _center + Vector2(cos(angle_a), sin(angle_a)) * compass_inner_radius * scale
		var pos_b := _center + Vector2(cos(angle_b), sin(angle_b)) * compass_inner_radius * scale

		var line_color := COL_ACCENT
		# 高亮当前调性相邻的连接线
		if i == _current_key_index or (i + 1) % CIRCLE_SIZE == _current_key_index:
			line_color.a = 0.5 * alpha
		else:
			line_color.a = 0.15 * alpha
		draw_line(pos_a, pos_b, line_color, 1.0, true)

# ============================================================
# 绘制 — 外圈大调音级环
# ============================================================

func _draw_outer_ring(font: Font, alpha: float) -> void:
	var scale := alpha

	# 外圈环线
	var ring_color := COL_ACCENT
	ring_color.a = 0.3 * alpha
	draw_arc(_center, compass_outer_radius * scale, 0, TAU, 64, ring_color, 1.5)

	# 12个音级刻度和标签
	for i in range(CIRCLE_SIZE):
		var angle := _key_index_to_angle(i) + _compass_rotation_offset
		var outer_pos := _center + Vector2(cos(angle), sin(angle)) * compass_outer_radius * scale
		var inner_pos := _center + Vector2(cos(angle), sin(angle)) * (compass_outer_radius - tick_length) * scale
		var label_pos := _center + Vector2(cos(angle), sin(angle)) * key_label_radius * scale

		var is_current := (i == _current_key_index)

		# 刻度线
		var tick_color: Color
		var tick_width: float
		if is_current:
			tick_color = COL_CURRENT_KEY
			tick_color.a = alpha * _current_key_glow
			tick_width = 3.0
		else:
			tick_color = COL_ACCENT
			tick_color.a = 0.4 * alpha
			tick_width = 1.5
		draw_line(inner_pos, outer_pos, tick_color, tick_width, true)

		# 音级标签
		var label_color: Color
		var label_size: int
		if is_current:
			label_color = COL_CURRENT_KEY
			label_color.a = alpha * _current_key_glow
			label_size = 18
		else:
			label_color = COL_TEXT_PRIMARY
			label_color.a = 0.7 * alpha
			label_size = 16

		var key_text: String = CIRCLE_KEYS[i]
		var text_offset := Vector2(-float(key_text.length()) * 4.0, 6.0)
		draw_string(font, label_pos + text_offset, key_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, label_size, label_color)

		# 当前调性发光圆点
		if is_current:
			var dot_color := COL_CURRENT_KEY
			dot_color.a = 0.6 * alpha * _current_key_glow
			draw_circle(outer_pos, 4.0 * scale, dot_color)
			# 呼吸光晕
			var halo_color := COL_CURRENT_KEY
			halo_color.a = 0.15 * alpha * _current_key_glow
			draw_circle(outer_pos, 10.0 * scale, halo_color)

# ============================================================
# 绘制 — 中圈关系小调环
# ============================================================

func _draw_middle_ring(font: Font, alpha: float) -> void:
	var scale := alpha

	# 中圈环线（更淡）
	var ring_color := COL_ACCENT
	ring_color.a = 0.15 * alpha
	draw_arc(_center, compass_middle_radius * scale, 0, TAU, 48, ring_color, 1.0)

	# 12个关系小调标签
	for i in range(CIRCLE_SIZE):
		var angle := _key_index_to_angle(i) + _compass_rotation_offset
		var label_pos := _center + Vector2(cos(angle), sin(angle)) * minor_label_radius * scale

		var label_color := COL_TEXT_SECONDARY
		label_color.a = 0.5 * alpha

		var minor_text: String = MINOR_KEYS[i]
		var text_offset := Vector2(-float(minor_text.length()) * 3.0, 4.0)
		draw_string(font, label_pos + text_offset, minor_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 11, label_color)

# ============================================================
# 绘制 — 当前调性高亮
# ============================================================

func _draw_current_key_highlight(font: Font, alpha: float) -> void:
	var scale := alpha
	# 中心显示当前调性
	var key_name: String = CIRCLE_KEYS[_current_key_index]
	var key_color := COL_CURRENT_KEY
	key_color.a = alpha
	draw_string(font, _center + Vector2(-12, -8), key_name,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 28, key_color)

	# 等级显示
	var level_color := COL_TEXT_SECONDARY
	level_color.a = 0.8 * alpha
	draw_string(font, _center + Vector2(-18, 14), "Lv.%d" % GameManager.player_level,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 12, level_color)

# ============================================================
# 绘制 — 标题
# ============================================================

func _draw_title(font: Font, alpha: float) -> void:
	var title_alpha := clampf(alpha * 2.0, 0.0, 1.0)

	# 主标题
	var tc := COL_TEXT_PRIMARY
	tc.a = title_alpha
	var title_text := "LEVEL UP"
	var title_width := font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24).x
	draw_string(font, Vector2(_center.x - title_width / 2.0, _center.y - compass_outer_radius - 60),
		title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, tc)

	# 副标题
	var subtitle := ""
	var subtitle_color := COL_TEXT_SECONDARY
	match _current_phase:
		Phase.DIRECTION_SELECT:
			subtitle = "Choose your musical direction"
		Phase.CARD_SELECT:
			var dir_name := _get_direction_display_name(_selected_direction)
			subtitle = "%s — Select an upgrade" % dir_name
			subtitle_color = DIRECTION_COLORS.get(_selected_direction, COL_TEXT_SECONDARY)
		Phase.THEORY_BREAKTHROUGH:
			subtitle = "◆ THEORY BREAKTHROUGH ◆"
			subtitle_color = COL_HOLY_GOLD

	subtitle_color.a = title_alpha * 0.8
	var sub_width := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x
	draw_string(font, Vector2(_center.x - sub_width / 2.0, _center.y - compass_outer_radius - 38),
		subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, subtitle_color)

# ============================================================
# 绘制 — Phase 1: 方向选择符文
# ============================================================

func _draw_direction_runes(font: Font) -> void:
	_direction_hover_areas.clear()

	var directions := [
		{ "key": "offense", "label": "ATTACK", "desc": "强化伤害与速度",
		  "icon": "♯", "angle_offset": 0.0 },  ## 3点钟方向 (右)
		{ "key": "core", "label": "CORE", "desc": "深化核心机制",
		  "icon": "♮", "angle_offset": -PI / 2.0 },  ## 12点钟方向 (上)
		{ "key": "defense", "label": "DEFENSE", "desc": "提升生存与资源",
		  "icon": "♭", "angle_offset": PI },  ## 9点钟方向 (左)
	]

	for i in range(directions.size()):
		var dir_info: Dictionary = directions[i]
		var dir_key: String = dir_info["key"]
		var progress := clampf(_phase_transition * 2.0 - i * 0.15, 0.0, 1.0)
		if progress < 0.01:
			continue

		var angle: float = dir_info["angle_offset"]
		var rune_center := _center + Vector2(cos(angle), sin(angle)) * rune_radius * _appear_progress
		var dir_color: Color = DIRECTION_COLORS.get(dir_key, COL_TEXT_PRIMARY)
		var is_hover := (_hover_direction == dir_key)
		var pulse := sin(_rune_pulse[i]) * 0.1 + 0.9

		# 悬停放大
		var rune_scale := progress * (rune_hover_scale if is_hover else 1.0)
		var rune_r := rune_size * rune_scale

		# 存储悬停区域
		_direction_hover_areas[dir_key] = { "center": rune_center, "radius": rune_r * 1.5 }

		# 符文背景圆
		var bg_color := COL_PANEL_BG
		bg_color.a = (0.95 if is_hover else 0.85) * progress
		draw_circle(rune_center, rune_r, bg_color)

		# 方向色边框
		var border_color := dir_color
		border_color.a = (0.9 if is_hover else 0.5) * progress * pulse
		draw_arc(rune_center, rune_r, 0, TAU, 48, border_color, 2.5 if is_hover else 1.5)

		# 辉光效果
		if is_hover:
			var glow := dir_color
			glow.a = 0.2 * progress * pulse
			draw_arc(rune_center, rune_r + 5, 0, TAU, 48, glow, 4.0)
			# 方向轨迹高亮
			_draw_direction_trail(dir_key, dir_color, progress)

		# 图标
		var icon_color := dir_color
		icon_color.a = progress * pulse
		var icon_text: String = dir_info["icon"]
		draw_string(font, rune_center + Vector2(-8, 8), icon_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 24, icon_color)

		# 标签
		var label_color := dir_color
		label_color.a = 0.9 * progress
		var label_text: String = dir_info["label"]
		var label_width := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
		draw_string(font, rune_center + Vector2(-label_width / 2.0, rune_r + 22),
			label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_color)

		# 描述
		var desc_color := COL_TEXT_SECONDARY
		desc_color.a = (0.8 if is_hover else 0.5) * progress
		var desc_text: String = dir_info["desc"]
		var desc_width := font.get_string_size(desc_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11).x
		draw_string(font, rune_center + Vector2(-desc_width / 2.0, rune_r + 38),
			desc_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, desc_color)

## 绘制方向悬停时的调性轨迹高亮
func _draw_direction_trail(direction: String, color: Color, alpha: float) -> void:
	if _direction_trail_progress < 0.01:
		return

	var steps: int = 3
	var step_dir: int = 0
	match direction:
		"offense":
			step_dir = 1   ## 顺时针
		"defense":
			step_dir = -1  ## 逆时针
		"core":
			return  ## 核心方向无轨迹

	for s in range(steps):
		var t := clampf(_direction_trail_progress - float(s) * 0.2, 0.0, 1.0)
		if t < 0.01:
			continue
		var idx := (_current_key_index + step_dir * (s + 1) + CIRCLE_SIZE) % CIRCLE_SIZE
		var angle := _key_index_to_angle(idx) + _compass_rotation_offset
		var pos := _center + Vector2(cos(angle), sin(angle)) * compass_outer_radius * _appear_progress

		var trail_color := color
		trail_color.a = 0.4 * t * alpha * (1.0 - float(s) / float(steps))
		draw_circle(pos, 6.0 * t, trail_color)

# ============================================================
# 绘制 — Phase 2: 升级卡片
# ============================================================

func _draw_upgrade_cards(font: Font) -> void:
	_card_rects.clear()

	if _current_options.is_empty():
		return

	var dir_color: Color = DIRECTION_COLORS.get(_selected_direction, COL_TEXT_PRIMARY)
	var card_count := _current_options.size()

	# 返回提示
	var back_alpha := clampf(_phase_transition * 2.0, 0.0, 1.0)
	var back_text := "[Right-click / ESC to go back]"
	var back_width := font.get_string_size(back_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10).x
	draw_string(font, Vector2(_center.x - back_width / 2.0, _center.y + compass_outer_radius + 200),
		back_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(COL_TEXT_SECONDARY.r, COL_TEXT_SECONDARY.g, COL_TEXT_SECONDARY.b, 0.5 * back_alpha))

	# 卡片弧形排列
	var total_width := card_count * (card_width + card_spacing) - card_spacing
	var start_x := _center.x - total_width / 2.0
	var base_y := _center.y - card_height / 2.0 + 20.0

	for i in range(card_count):
		var progress := _card_appear[i] if i < _card_appear.size() else 0.0
		if progress < 0.01:
			_card_rects.append(Rect2())
			continue

		var is_hover := (_hover_card == i)
		var card_scale := progress * (card_hover_scale if is_hover else 1.0)
		var hover_y := card_hover_offset_y if is_hover else 0.0

		var card_w := card_width * card_scale
		var card_h := card_height * card_scale
		var card_x := start_x + i * (card_width + card_spacing) + (card_width - card_w) / 2.0
		var card_y := base_y + hover_y + (card_height - card_h) / 2.0

		var card_rect := Rect2(Vector2(card_x, card_y), Vector2(card_w, card_h))
		_card_rects.append(card_rect)

		var option := _current_options[i]
		var card_alpha := (1.0 if is_hover else 0.7) * progress
		_draw_single_card(card_rect, option, is_hover, font, card_alpha, dir_color)

## 绘制单张升级卡片 (设计文档 §5)
func _draw_single_card(rect: Rect2, option: Dictionary, is_hover: bool,
		font: Font, alpha: float, dir_color: Color) -> void:
	var rarity: String = option.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.GRAY)
	var is_meta := _is_meta_unlocked_upgrade(option)
	var is_legendary := (rarity == "legendary")

	# ---- 卡片背景 ----
	var bg := COL_PANEL_BG
	bg.a = 0.8 * alpha
	if is_hover:
		bg = Color(COL_PANEL_BG.r + 0.03, COL_PANEL_BG.g + 0.02, COL_PANEL_BG.b + 0.06, 0.9 * alpha)
	_draw_rounded_rect(rect, bg, 12.0)

	# ---- 边框 (§5.2) ----
	var border_color := dir_color
	var border_width := 1.5

	if is_meta:
		# 局外解锁金色边框 (§6.1)
		border_color = COL_HOLY_GOLD
		border_width = 2.0
		# 金色辉光
		var glow_rect := rect.grow(3)
		var glow_color := COL_HOLY_GOLD
		glow_color.a = 0.2 * alpha
		_draw_rounded_rect_outline(glow_rect, glow_color, 12.0, 3.0)
	elif is_legendary:
		border_color = COL_HOLY_GOLD
		border_width = 3.0

	if is_hover:
		border_width += 0.5

	border_color.a = (0.9 if is_hover else 0.6) * alpha
	_draw_rounded_rect_outline(rect, border_color, 12.0, border_width)

	# ---- 稀有度视觉分级 (§5.4) ----
	if rarity == "rare":
		# 双层边框
		var outer_glow := border_color
		outer_glow.a = 0.15 * alpha
		_draw_rounded_rect_outline(rect.grow(2), outer_glow, 14.0, 0.5)
	elif rarity == "epic":
		# 三层渐变边框
		for layer in range(3):
			var layer_color := border_color.lerp(Color.WHITE, float(layer) / 3.0)
			layer_color.a = (0.3 - float(layer) * 0.08) * alpha
			_draw_rounded_rect_outline(rect.grow(2 + layer * 2), layer_color, 14.0 + layer * 2, 0.5)

	# ---- 殿堂徽章 (§6.1) ----
	if is_meta:
		var badge_center := rect.position + Vector2(rect.size.x - 20, 20)
		var badge_color := COL_HOLY_GOLD
		badge_color.a = alpha * (sin(_time * 3.0) * 0.1 + 0.9)
		draw_circle(badge_center, 12.0, badge_color)
		# 徽章内星形
		var star_color := COL_DEEP_BLACK
		star_color.a = alpha
		draw_string(font, badge_center + Vector2(-5, 5), "★",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 10, star_color)

	# ---- 顶部标题区 (§5.1) ----
	var title_y := rect.position.y + 30
	var title_text: String = option.get("name", "???")
	if is_legendary:
		title_text = "◆ " + title_text
	var title_color := COL_HOLY_GOLD if is_legendary else COL_TEXT_PRIMARY
	title_color.a = alpha
	var title_width := font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
	draw_string(font, Vector2(rect.position.x + (rect.size.x - title_width) / 2.0, title_y),
		title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, title_color)

	# ---- 中部图标区 (§5.1) ----
	var icon_center := Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y + rect.size.y * 0.4)
	var icon_radius := 35.0

	# 图标容器背景
	var icon_bg := COL_DEEP_BLACK
	icon_bg.a = 0.8 * alpha
	draw_circle(icon_center, icon_radius, icon_bg)

	# 图标容器边框
	var icon_border := dir_color
	if is_meta:
		icon_border = COL_HOLY_GOLD
	icon_border.a = 0.7 * alpha
	draw_arc(icon_center, icon_radius, 0, TAU, 32, icon_border, 1.5)

	# 图标文本（使用分类首字母作为抽象图标）
	var icon_text := _get_category_icon(option)
	var icon_text_color := dir_color
	if is_meta:
		icon_text_color = COL_HOLY_GOLD
	icon_text_color.a = alpha
	draw_string(font, icon_center + Vector2(-8, 8), icon_text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 20, icon_text_color)

	# ---- 下部描述区 (§5.1) ----
	var desc_y := rect.position.y + rect.size.y * 0.62
	var desc_text: String = option.get("desc", "")
	var desc_color := COL_TEXT_PRIMARY
	desc_color.a = 0.85 * alpha
	var max_desc_width := rect.size.x - 24.0

	# 简单文本换行
	var lines := _wrap_text(desc_text, font, max_desc_width, 13)
	for line_idx in range(mini(lines.size(), 3)):
		draw_string(font, Vector2(rect.position.x + 12, desc_y + line_idx * 18),
			lines[line_idx], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, desc_color)

	# ---- 底部标签区 (§5.1) ----
	var tags: Array = option.get("tags", [])
	var tag_y := rect.position.y + rect.size.y - 30
	var tag_x := rect.position.x + 12
	var tag_color := COL_TEXT_SECONDARY
	tag_color.a = 0.6 * alpha

	for tag in tags:
		var tag_text := "[%s]" % str(tag)
		draw_string(font, Vector2(tag_x, tag_y), tag_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tag_color)
		tag_x += font.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 6

	# 局外解锁标签
	if is_meta:
		var meta_tag_color := COL_HOLY_GOLD
		meta_tag_color.a = 0.7 * alpha
		draw_string(font, Vector2(tag_x, tag_y), "[殿堂]",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, meta_tag_color)

	# ---- 底部方向指示条 ----
	var bar_rect := Rect2(
		Vector2(rect.position.x, rect.position.y + rect.size.y - 4),
		Vector2(rect.size.x, 4)
	)
	var bar_color := dir_color
	if is_meta:
		bar_color = COL_HOLY_GOLD
	bar_color.a = 0.6 * alpha
	draw_rect(bar_rect, bar_color)

# ============================================================
# 绘制 — 乐理突破 (设计文档 §7)
# ============================================================

func _draw_breakthrough_event(font: Font) -> void:
	if _breakthrough_event.is_empty():
		return

	var progress := clampf(_phase_transition, 0.0, 1.0)
	var pulse := sin(_breakthrough_pulse) * 0.15 + 0.85

	# 屏幕变暗至10%
	var dark_overlay := Color(0, 0, 0, 0.85 * progress)
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), dark_overlay)

	# 中心金色光线放射 (§7.2)
	for r in range(breakthrough_ray_count):
		var ray_angle := float(r) / float(breakthrough_ray_count) * TAU + _time * 0.3
		var ray_length := 400.0 * progress * pulse
		var ray_end := _center + Vector2(cos(ray_angle), sin(ray_angle)) * ray_length
		var ray_color := COL_HOLY_GOLD
		ray_color.a = 0.08 * progress * pulse
		draw_line(_center, ray_end, ray_color, 1.5)

	# 中心星云加速旋转（金色）
	for i in range(8):
		var t := float(i) / 8.0
		var r := compass_core_radius * progress * (0.5 + t * 0.5)
		var nebula_color := COL_HOLY_GOLD
		nebula_color.a = (0.1 - t * 0.01) * progress * pulse
		var offset_angle := _time * 2.0 + t * PI * 0.5
		var offset := Vector2(cos(offset_angle), sin(offset_angle)) * 5.0 * (1.0 - t)
		draw_arc(_center + offset, r, 0, TAU, 48, nebula_color, 2.0)

	# 突破卡片 (§7.2 — 更大尺寸)
	var card_w := breakthrough_card_width * progress
	var card_h := breakthrough_card_height * progress
	var card_pos := Vector2(_center.x - card_w / 2.0, _center.y - card_h / 2.0 + 20)
	var card_rect := Rect2(card_pos, Vector2(card_w, card_h))
	_breakthrough_rect = card_rect

	# 卡片背景 — 流动金色星云纹理
	var bg := Color(0.15, 0.12, 0.05, 0.95 * progress)
	if _hover_breakthrough:
		bg = Color(0.2, 0.16, 0.06, 0.98 * progress)
	_draw_rounded_rect(card_rect, bg, 12.0)

	# 金色边框 — 双层辉光 (§7.2)
	var bc := COL_HOLY_GOLD
	bc.a = pulse * progress
	_draw_rounded_rect_outline(card_rect, bc, 12.0, 3.0)
	var outer_glow := COL_HOLY_GOLD
	outer_glow.a = 0.3 * pulse * progress
	_draw_rounded_rect_outline(card_rect.grow(4), outer_glow, 16.0, 2.0)

	# 图标 — 神圣几何图案
	var icon_center := Vector2(card_pos.x + card_w / 2.0, card_pos.y + card_h * 0.25)
	var icon_text: String = _breakthrough_event.get("icon", "?")
	var icon_color := COL_HOLY_GOLD
	icon_color.a = progress * pulse
	draw_string(font, icon_center + Vector2(-15, 10), icon_text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 32, icon_color)

	# 旋转的几何装饰
	var geo_radius := 45.0 * progress
	for j in range(6):
		var geo_angle := float(j) / 6.0 * TAU + _time * 0.5
		var geo_pos := icon_center + Vector2(cos(geo_angle), sin(geo_angle)) * geo_radius
		var geo_color := COL_HOLY_GOLD
		geo_color.a = 0.3 * progress * pulse
		draw_circle(geo_pos, 3.0, geo_color)

	# 标题 — 传说标志
	var title_text := "◆ " + _breakthrough_event.get("name", "???")
	var title_color := COL_HOLY_GOLD
	title_color.a = progress
	var title_width := font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20).x
	draw_string(font, Vector2(card_pos.x + (card_w - title_width) / 2.0, card_pos.y + card_h * 0.5),
		title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, title_color)

	# 描述
	var desc_text: String = _breakthrough_event.get("desc", "")
	var desc_color := Color(1.0, 0.95, 0.8, 0.85 * progress)
	var desc_lines := _wrap_text(desc_text, font, card_w - 40, 14)
	for line_idx in range(desc_lines.size()):
		draw_string(font, Vector2(card_pos.x + 20, card_pos.y + card_h * 0.58 + line_idx * 20),
			desc_lines[line_idx], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, desc_color)

	# 稀有度标签
	var rarity_text := "[LEGENDARY]"
	var rarity_color := COL_HOLY_GOLD
	rarity_color.a = 0.7 * progress
	var rarity_width := font.get_string_size(rarity_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11).x
	draw_string(font, Vector2(card_pos.x + (card_w - rarity_width) / 2.0, card_pos.y + card_h * 0.75),
		rarity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, rarity_color)

	# 确认提示
	var hint_text := "Click to acquire"
	var hint_color := COL_HOLY_GOLD
	hint_color.a = 0.5 * progress * pulse
	var hint_width := font.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12).x
	draw_string(font, Vector2(card_pos.x + (card_w - hint_width) / 2.0, card_pos.y + card_h - 30),
		hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, hint_color)

# ============================================================
# 绘制辅助函数
# ============================================================

## 绘制圆角矩形填充
func _draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	# 使用多边形近似圆角矩形
	var points := PackedVector2Array()
	var corner_segments := 8

	# 右上角
	for i in range(corner_segments + 1):
		var angle := -PI / 2.0 + float(i) / float(corner_segments) * PI / 2.0
		points.append(Vector2(rect.position.x + rect.size.x - radius + cos(angle) * radius,
			rect.position.y + radius + sin(angle) * radius))
	# 右下角
	for i in range(corner_segments + 1):
		var angle := float(i) / float(corner_segments) * PI / 2.0
		points.append(Vector2(rect.position.x + rect.size.x - radius + cos(angle) * radius,
			rect.position.y + rect.size.y - radius + sin(angle) * radius))
	# 左下角
	for i in range(corner_segments + 1):
		var angle := PI / 2.0 + float(i) / float(corner_segments) * PI / 2.0
		points.append(Vector2(rect.position.x + radius + cos(angle) * radius,
			rect.position.y + rect.size.y - radius + sin(angle) * radius))
	# 左上角
	for i in range(corner_segments + 1):
		var angle := PI + float(i) / float(corner_segments) * PI / 2.0
		points.append(Vector2(rect.position.x + radius + cos(angle) * radius,
			rect.position.y + radius + sin(angle) * radius))

	if points.size() >= 3:
		draw_colored_polygon(points, color)

## 绘制圆角矩形描边
func _draw_rounded_rect_outline(rect: Rect2, color: Color, radius: float, width: float) -> void:
	var points := PackedVector2Array()
	var corner_segments := 8

	for i in range(corner_segments + 1):
		var angle := -PI / 2.0 + float(i) / float(corner_segments) * PI / 2.0
		points.append(Vector2(rect.position.x + rect.size.x - radius + cos(angle) * radius,
			rect.position.y + radius + sin(angle) * radius))
	for i in range(corner_segments + 1):
		var angle := float(i) / float(corner_segments) * PI / 2.0
		points.append(Vector2(rect.position.x + rect.size.x - radius + cos(angle) * radius,
			rect.position.y + rect.size.y - radius + sin(angle) * radius))
	for i in range(corner_segments + 1):
		var angle := PI / 2.0 + float(i) / float(corner_segments) * PI / 2.0
		points.append(Vector2(rect.position.x + radius + cos(angle) * radius,
			rect.position.y + rect.size.y - radius + sin(angle) * radius))
	for i in range(corner_segments + 1):
		var angle := PI + float(i) / float(corner_segments) * PI / 2.0
		points.append(Vector2(rect.position.x + radius + cos(angle) * radius,
			rect.position.y + radius + sin(angle) * radius))

	# 闭合
	if points.size() > 0:
		points.append(points[0])
	draw_polyline(points, color, width, true)

## 简单文本换行
func _wrap_text(text: String, font: Font, max_width: float, font_size: int) -> Array[String]:
	var lines: Array[String] = []
	var words := text.split(" ")
	var current_line := ""

	for word in words:
		var test_line := current_line + (" " if current_line != "" else "") + word
		var test_width := font.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if test_width > max_width and current_line != "":
			lines.append(current_line)
			current_line = word
		else:
			current_line = test_line

	if current_line != "":
		lines.append(current_line)

	return lines

## 获取分类图标
func _get_category_icon(option: Dictionary) -> String:
	var category: String = option.get("category", "")
	match category:
		"note_stat": return "♪"
		"chord_mastery": return "♫"
		"rhythm_mastery": return "♩"
		"modifier_mastery": return "♯"
		"timbre_mastery": return "♬"
		"survival": return "♡"
		"fatigue_resist": return "◎"
		"note_acquire": return "★"
		"special": return "◆"
		"inscription": return "✦"
		"breakthrough": return "✧"
	return "?"

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
		"offense": return "ATTACK"
		"core": return "CORE"
		"defense": return "DEFENSE"
	return direction

# ============================================================
# 信号回调
# ============================================================

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.UPGRADE_SELECT:
		show_upgrade_options()
	elif _is_visible:
		hide_panel()
