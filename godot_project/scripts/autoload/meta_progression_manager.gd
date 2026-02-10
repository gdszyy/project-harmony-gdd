## meta_progression_manager.gd
## 局外成长系统管理器 (Issue #31)
## "和谐殿堂" (The Hall of Harmony) — 局外永久成长系统
##
## 管理四大成长模块：
## A. 乐器调优 (Instrument Tuning) — 基础属性成长
## B. 乐理研习 (Theory Archives) — 复杂性解锁
## C. 调式风格 (Mode Mastery) — 职业/流派系统
## D. 声学降噪 (Acoustic Treatment) — 疲劳系统缓解
##
## 核心货币：共鸣碎片 (Resonance Fragments)
## 数据持久化：通过 SaveManager 存储到 user://meta_progression.cfg
extends Node

# ============================================================
# 信号
# ============================================================
signal resonance_fragments_changed(new_total: int)
signal upgrade_purchased(module: String, upgrade_id: String, new_level: int)
signal mode_unlocked(mode_name: String)
signal mode_selected(mode_name: String)
signal theory_unlocked(theory_id: String)

# ============================================================
# 常量
# ============================================================
const META_SAVE_PATH = "user://meta_progression.cfg"

# ============================================================
# 模块 A：乐器调优 — 基础属性升级配置
# ============================================================
## 每个升级项的配置：
## - max_level: 最大等级
## - base_cost: 基础花费
## - cost_growth: 每级花费增长率
## - effect_per_level: 每级效果值
## - stat_key: 对应的属性键名
const INSTRUMENT_UPGRADES: Dictionary = {
	"stage_presence": {
		"name": "舞台定力",
		"name_en": "Stage Presence",
		"description": "提升初始最大生命值",
		"effect_desc": "+%d HP / 级",
		"max_level": 10,
		"base_cost": 20,
		"cost_growth": 1.3,
		"effect_per_level": 10.0,
		"stat_key": "max_hp",
	},
	"acoustic_pressure": {
		"name": "基础声压",
		"name_en": "Acoustic Pressure",
		"description": "提升所有法术的基础伤害倍率",
		"effect_desc": "+%d%% 伤害 / 级",
		"max_level": 10,
		"base_cost": 25,
		"cost_growth": 1.4,
		"effect_per_level": 2.0,  # 百分比
		"stat_key": "damage_mult",
	},
	"rhythmic_sense": {
		"name": "节拍敏锐度",
		"name_en": "Rhythmic Sense",
		"description": "放宽完美判定的时间窗口",
		"effect_desc": "+%d ms 窗口 / 级",
		"max_level": 5,
		"base_cost": 30,
		"cost_growth": 1.5,
		"effect_per_level": 15.0,  # 毫秒
		"stat_key": "perfect_window_ms",
	},
	"pickup_range": {
		"name": "拾音范围",
		"name_en": "Pickup Range",
		"description": "扩大自动吸附掉落物的范围",
		"effect_desc": "+%d 像素 / 级",
		"max_level": 8,
		"base_cost": 15,
		"cost_growth": 1.25,
		"effect_per_level": 20.0,  # 像素
		"stat_key": "pickup_range",
	},
	"upbeat_velocity": {
		"name": "起拍速度",
		"name_en": "Upbeat Velocity",
		"description": "提升初始投射物的飞行速度",
		"effect_desc": "+%d%% 速度 / 级",
		"max_level": 8,
		"base_cost": 20,
		"cost_growth": 1.3,
		"effect_per_level": 3.0,  # 百分比
		"stat_key": "projectile_speed_mult",
	},
}

# ============================================================
# 模块 B：乐理研习 — 解锁配置
# ============================================================
const THEORY_UNLOCKS: Dictionary = {
	# 黑键修饰符
	"black_key_tracking": {
		"name": "D# 追踪修饰符",
		"name_en": "D# Tracking Modifier",
		"description": "解锁 D# 追踪修饰符到奖励池",
		"cost": 40,
		"category": "black_key",
		"prerequisite": "",
		"unlock_key": "Ds",
	},
	"black_key_echo": {
		"name": "G# 回响修饰符",
		"name_en": "G# Echo Modifier",
		"description": "解锁 G# 回响修饰符到奖励池",
		"cost": 40,
		"category": "black_key",
		"prerequisite": "",
		"unlock_key": "Gs",
	},
	"black_key_scatter": {
		"name": "A# 散射修饰符",
		"name_en": "A# Scatter Modifier",
		"description": "解锁 A# 散射修饰符到奖励池",
		"cost": 50,
		"category": "black_key",
		"prerequisite": "black_key_echo",
		"unlock_key": "As",
	},
	# 和弦图谱
	"chord_tension": {
		"name": "紧张度理论",
		"name_en": "Tension Theory",
		"description": "解锁减三和弦(冲击波)和增三和弦(爆炸)",
		"cost": 60,
		"category": "chord",
		"prerequisite": "",
		"unlock_key": "diminished_augmented",
	},
	"chord_seventh": {
		"name": "七和弦解析",
		"name_en": "Seventh Chord Analysis",
		"description": "解锁属七、大七、小七、减七和弦",
		"cost": 80,
		"category": "chord",
		"prerequisite": "chord_tension",
		"unlock_key": "seventh_chords",
	},
	# 传说乐章
	"legend_chapter": {
		"name": "传说乐章许可",
		"name_en": "Legendary Chapter License",
		"description": "提升遇到扩展和弦解锁的概率",
		"cost": 120,
		"category": "legend",
		"prerequisite": "chord_seventh",
		"unlock_key": "extended_chord_chance",
	},
}

# ============================================================
# 模块 C：调式风格 — 职业/流派配置
# ============================================================
const MODE_CONFIGS: Dictionary = {
	"ionian": {
		"name": "伊奥尼亚",
		"name_en": "Ionian",
		"title": "均衡者",
		"description": "C大调音阶，初始拥有全套白键",
		"cost": 0,  # 默认解锁
		"notes": ["C", "D", "E", "F", "G", "A", "B"],
		"passive": "harmony_bonus",
		"passive_desc": "和谐度加成 +10%",
		"passive_value": 0.1,
	},
	"dorian": {
		"name": "多利亚",
		"name_en": "Dorian",
		"title": "民谣诗人",
		"description": "侧重小调色彩，初始自带回响修饰符效果",
		"cost": 80,
		"notes": ["C", "D", "Eb", "F", "G", "A", "Bb"],
		"passive": "echo_innate",
		"passive_desc": "所有音符自带回响效果",
		"passive_value": 1.0,
	},
	"pentatonic": {
		"name": "五声音阶",
		"name_en": "Pentatonic",
		"title": "东方行者",
		"description": "仅 CDEGA 五个音符，单发伤害 +20%",
		"cost": 60,
		"notes": ["C", "D", "E", "G", "A"],
		"passive": "damage_boost",
		"passive_desc": "基础伤害 +20%",
		"passive_value": 0.2,
	},
	"blues": {
		"name": "布鲁斯",
		"name_en": "Blues",
		"title": "爵士乐手",
		"description": "自带降音，不和谐值可转化为暴击率",
		"cost": 100,
		"notes": ["C", "Eb", "F", "Gb", "G", "Bb"],
		"passive": "dissonance_crit",
		"passive_desc": "不和谐值 → 暴击率转化",
		"passive_value": 0.5,
	},
}

# ============================================================
# 模块 D：声学降噪 — 疲劳缓解配置
# ============================================================
const ACOUSTIC_UPGRADES: Dictionary = {
	"auditory_tolerance": {
		"name": "听觉耐受",
		"name_en": "Auditory Tolerance",
		"description": "降低单调值的累积速度",
		"effect_desc": "-%d%% 单调值累积 / 级",
		"max_level": 3,
		"base_cost": 35,
		"cost_growth": 1.5,
		"effect_per_level": 5.0,  # 百分比
		"stat_key": "monotony_reduction",
	},
	"reverb_damping": {
		"name": "混响消除",
		"name_en": "Reverb Damping",
		"description": "加快密度值负面效果的恢复速度",
		"effect_desc": "+%d%% 密度恢复 / 级",
		"max_level": 3,
		"base_cost": 35,
		"cost_growth": 1.5,
		"effect_per_level": 10.0,  # 百分比
		"stat_key": "density_recovery",
	},
	"perfect_pitch": {
		"name": "绝对音感",
		"name_en": "Perfect Pitch",
		"description": "减少不和谐值造成的生命腐蚀伤害",
		"effect_desc": "每跳 -%d HP 腐蚀 / 级",
		"max_level": 3,
		"base_cost": 40,
		"cost_growth": 1.5,
		"effect_per_level": 1.0,  # HP
		"stat_key": "dissonance_damage_reduction",
	},
	"rest_aesthetics": {
		"name": "休止符美学",
		"name_en": "Rest Aesthetics",
		"description": "提升休止符清除负面状态的效率",
		"effect_desc": "+%d%% 清除效率 / 级",
		"max_level": 3,
		"base_cost": 30,
		"cost_growth": 1.4,
		"effect_per_level": 15.0,  # 百分比
		"stat_key": "rest_efficiency",
	},
}

# ============================================================
# 运行时数据
# ============================================================
## 共鸣碎片（核心货币）
var resonance_fragments: int = 0

## 模块 A：各升级项的当前等级
var instrument_levels: Dictionary = {}  # upgrade_id -> int

## 模块 B：已解锁的乐理项
var unlocked_theories: Dictionary = {}  # theory_id -> bool

## 模块 C：已解锁的调式
var unlocked_modes: Dictionary = {}  # mode_name -> bool

## 模块 C：当前选择的调式
var selected_mode: String = "ionian"

## 模块 D：各升级项的当前等级
var acoustic_levels: Dictionary = {}  # upgrade_id -> int

## 总游戏局数
var total_runs: int = 0

## 总击败 Boss 数
var total_bosses_defeated: int = 0

# ============================================================
# 存档数据
# ============================================================
var _save_data := ConfigFile.new()

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_init_defaults()
	load_meta_data()

func _init_defaults() -> void:
	# 模块 A 默认等级
	for upgrade_id in INSTRUMENT_UPGRADES:
		instrument_levels[upgrade_id] = 0
	
	# 模块 B 默认未解锁
	for theory_id in THEORY_UNLOCKS:
		unlocked_theories[theory_id] = false
	
	# 模块 C 默认只有 Ionian
	for mode_name in MODE_CONFIGS:
		unlocked_modes[mode_name] = (mode_name == "ionian")
	selected_mode = "ionian"
	
	# 模块 D 默认等级
	for upgrade_id in ACOUSTIC_UPGRADES:
		acoustic_levels[upgrade_id] = 0

# ============================================================
# 存档读写
# ============================================================

func save_meta_data() -> void:
	# 货币
	_save_data.set_value("meta", "resonance_fragments", resonance_fragments)
	_save_data.set_value("meta", "total_runs", total_runs)
	_save_data.set_value("meta", "total_bosses_defeated", total_bosses_defeated)
	
	# 模块 A
	for upgrade_id in instrument_levels:
		_save_data.set_value("instrument", upgrade_id, instrument_levels[upgrade_id])
	
	# 模块 B
	for theory_id in unlocked_theories:
		_save_data.set_value("theory", theory_id, unlocked_theories[theory_id])
	
	# 模块 C
	for mode_name in unlocked_modes:
		_save_data.set_value("modes", mode_name, unlocked_modes[mode_name])
	_save_data.set_value("modes", "selected", selected_mode)
	
	# 模块 D
	for upgrade_id in acoustic_levels:
		_save_data.set_value("acoustic", upgrade_id, acoustic_levels[upgrade_id])
	
	var err := _save_data.save(META_SAVE_PATH)
	if err != OK:
		push_error("MetaProgressionManager: Failed to save data! Error: %d" % err)

func load_meta_data() -> void:
	var err := _save_data.load(META_SAVE_PATH)
	if err != OK:
		# 首次运行，使用默认值
		return
	
	# 货币
	resonance_fragments = _save_data.get_value("meta", "resonance_fragments", 0)
	total_runs = _save_data.get_value("meta", "total_runs", 0)
	total_bosses_defeated = _save_data.get_value("meta", "total_bosses_defeated", 0)
	
	# 模块 A
	for upgrade_id in INSTRUMENT_UPGRADES:
		instrument_levels[upgrade_id] = _save_data.get_value("instrument", upgrade_id, 0)
	
	# 模块 B
	for theory_id in THEORY_UNLOCKS:
		unlocked_theories[theory_id] = _save_data.get_value("theory", theory_id, false)
	
	# 模块 C
	for mode_name in MODE_CONFIGS:
		unlocked_modes[mode_name] = _save_data.get_value("modes", mode_name, mode_name == "ionian")
	selected_mode = _save_data.get_value("modes", "selected", "ionian")
	
	# 模块 D
	for upgrade_id in ACOUSTIC_UPGRADES:
		acoustic_levels[upgrade_id] = _save_data.get_value("acoustic", upgrade_id, 0)

# ============================================================
# 货币管理
# ============================================================

## 添加共鸣碎片
func add_resonance_fragments(amount: int) -> void:
	resonance_fragments += amount
	resonance_fragments_changed.emit(resonance_fragments)
	save_meta_data()

## 消耗共鸣碎片（返回是否成功）
func spend_resonance_fragments(amount: int) -> bool:
	if resonance_fragments < amount:
		return false
	resonance_fragments -= amount
	resonance_fragments_changed.emit(resonance_fragments)
	save_meta_data()
	return true

## 获取当前碎片数量
func get_resonance_fragments() -> int:
	return resonance_fragments

# ============================================================
# 模块 A：乐器调优 — 购买与查询
# ============================================================

## 获取升级项的当前等级
func get_instrument_level(upgrade_id: String) -> int:
	return instrument_levels.get(upgrade_id, 0)

## 获取升级项的下一级花费
func get_instrument_cost(upgrade_id: String) -> int:
	var config: Dictionary = INSTRUMENT_UPGRADES.get(upgrade_id, {})
	var level: int = instrument_levels.get(upgrade_id, 0)
	if level >= config.get("max_level", 0):
		return -1  # 已满级
	var base_cost: int = config.get("base_cost", 20)
	var growth: float = config.get("cost_growth", 1.3)
	return int(base_cost * pow(growth, level))

## 购买乐器调优升级
func purchase_instrument_upgrade(upgrade_id: String) -> bool:
	var config: Dictionary = INSTRUMENT_UPGRADES.get(upgrade_id, {})
	if config.is_empty():
		return false
	
	var level: int = instrument_levels.get(upgrade_id, 0)
	if level >= config.get("max_level", 0):
		return false  # 已满级
	
	var cost := get_instrument_cost(upgrade_id)
	if not spend_resonance_fragments(cost):
		return false
	
	instrument_levels[upgrade_id] = level + 1
	upgrade_purchased.emit("instrument", upgrade_id, level + 1)
	save_meta_data()
	return true

## 获取乐器调优的属性加成值
func get_instrument_bonus(stat_key: String) -> float:
	for upgrade_id in INSTRUMENT_UPGRADES:
		var config: Dictionary = INSTRUMENT_UPGRADES[upgrade_id]
		if config.get("stat_key", "") == stat_key:
			var level: int = instrument_levels.get(upgrade_id, 0)
			return level * config.get("effect_per_level", 0.0)
	return 0.0

# ============================================================
# 模块 B：乐理研习 — 解锁与查询
# ============================================================

## 检查乐理项是否已解锁
func is_theory_unlocked(theory_id: String) -> bool:
	return unlocked_theories.get(theory_id, false)

## 检查乐理项的前置条件是否满足
func can_unlock_theory(theory_id: String) -> bool:
	var config: Dictionary = THEORY_UNLOCKS.get(theory_id, {})
	if config.is_empty():
		return false
	if unlocked_theories.get(theory_id, false):
		return false  # 已解锁
	
	var prerequisite: String = config.get("prerequisite", "")
	if prerequisite != "" and not unlocked_theories.get(prerequisite, false):
		return false  # 前置未满足
	
	return resonance_fragments >= config.get("cost", 0)

## 购买乐理解锁
func purchase_theory_unlock(theory_id: String) -> bool:
	if not can_unlock_theory(theory_id):
		return false
	
	var config: Dictionary = THEORY_UNLOCKS[theory_id]
	var cost: int = config.get("cost", 0)
	
	if not spend_resonance_fragments(cost):
		return false
	
	unlocked_theories[theory_id] = true
	theory_unlocked.emit(theory_id)
	save_meta_data()
	return true

## 检查和弦类型是否已解锁
func is_chord_unlocked(chord_type: String) -> bool:
	match chord_type:
		"major", "minor":
			return true  # 默认解锁
		"diminished", "augmented":
			return unlocked_theories.get("chord_tension", false)
		"dominant7", "major7", "minor7", "diminished7":
			return unlocked_theories.get("chord_seventh", false)
		_:
			return false

## 检查黑键修饰符是否已解锁
func is_black_key_unlocked(key_name: String) -> bool:
	match key_name:
		"Cs", "Fs":
			return true  # 默认解锁
		"Ds":
			return unlocked_theories.get("black_key_tracking", false)
		"Gs":
			return unlocked_theories.get("black_key_echo", false)
		"As":
			return unlocked_theories.get("black_key_scatter", false)
		_:
			return false

# ============================================================
# 模块 C：调式风格 — 解锁与选择
# ============================================================

## 检查调式是否已解锁
func is_mode_unlocked(mode_name: String) -> bool:
	return unlocked_modes.get(mode_name, false)

## 购买调式解锁
func purchase_mode_unlock(mode_name: String) -> bool:
	var config: Dictionary = MODE_CONFIGS.get(mode_name, {})
	if config.is_empty():
		return false
	if unlocked_modes.get(mode_name, false):
		return false  # 已解锁
	
	var cost: int = config.get("cost", 0)
	if not spend_resonance_fragments(cost):
		return false
	
	unlocked_modes[mode_name] = true
	mode_unlocked.emit(mode_name)
	save_meta_data()
	return true

## 选择调式（用于下一局游戏）
func select_mode(mode_name: String) -> bool:
	if not unlocked_modes.get(mode_name, false):
		return false
	selected_mode = mode_name
	mode_selected.emit(mode_name)
	save_meta_data()
	return true

## 获取当前选择的调式配置
func get_selected_mode_config() -> Dictionary:
	return MODE_CONFIGS.get(selected_mode, MODE_CONFIGS["ionian"])

## 获取当前调式的可用音符列表
func get_available_notes() -> Array:
	var config: Dictionary = get_selected_mode_config()
	return config.get("notes", ["C", "D", "E", "F", "G", "A", "B"])

## 获取当前调式的被动效果
func get_mode_passive() -> Dictionary:
	var config: Dictionary = get_selected_mode_config()
	return {
		"type": config.get("passive", ""),
		"value": config.get("passive_value", 0.0),
		"description": config.get("passive_desc", ""),
	}

# ============================================================
# 模块 D：声学降噪 — 购买与查询
# ============================================================

## 获取声学升级的当前等级
func get_acoustic_level(upgrade_id: String) -> int:
	return acoustic_levels.get(upgrade_id, 0)

## 获取声学升级的下一级花费
func get_acoustic_cost(upgrade_id: String) -> int:
	var config: Dictionary = ACOUSTIC_UPGRADES.get(upgrade_id, {})
	var level: int = acoustic_levels.get(upgrade_id, 0)
	if level >= config.get("max_level", 0):
		return -1
	var base_cost: int = config.get("base_cost", 35)
	var growth: float = config.get("cost_growth", 1.5)
	return int(base_cost * pow(growth, level))

## 购买声学降噪升级
func purchase_acoustic_upgrade(upgrade_id: String) -> bool:
	var config: Dictionary = ACOUSTIC_UPGRADES.get(upgrade_id, {})
	if config.is_empty():
		return false
	
	var level: int = acoustic_levels.get(upgrade_id, 0)
	if level >= config.get("max_level", 0):
		return false
	
	var cost := get_acoustic_cost(upgrade_id)
	if not spend_resonance_fragments(cost):
		return false
	
	acoustic_levels[upgrade_id] = level + 1
	upgrade_purchased.emit("acoustic", upgrade_id, level + 1)
	save_meta_data()
	return true

## 获取声学降噪的效果值
func get_acoustic_bonus(stat_key: String) -> float:
	for upgrade_id in ACOUSTIC_UPGRADES:
		var config: Dictionary = ACOUSTIC_UPGRADES[upgrade_id]
		if config.get("stat_key", "") == stat_key:
			var level: int = acoustic_levels.get(upgrade_id, 0)
			return level * config.get("effect_per_level", 0.0)
	return 0.0

# ============================================================
# 游戏开始时应用局外加成
# ============================================================

## 在每局游戏开始时调用，将所有局外加成应用到 GameManager
func apply_meta_bonuses() -> void:
	# 模块 A：基础属性加成
	_apply_instrument_bonuses()
	
	# 模块 C：调式被动效果
	_apply_mode_passive()
	
	# 模块 D：疲劳缓解
	_apply_acoustic_bonuses()

func _apply_instrument_bonuses() -> void:
	# 生命值加成
	var hp_bonus := get_instrument_bonus("max_hp")
	if hp_bonus > 0.0:
		GameManager.player_max_hp += hp_bonus
		GameManager.player_current_hp = GameManager.player_max_hp
	
	# 伤害倍率 — 由 SaveManager.get_damage_multiplier() 委托读取，无需额外存储
	# SpellcraftSystem 已通过 SaveManager.get_damage_multiplier() 获取
	
	# 投射物速度倍率 — 由 SaveManager.get_speed_multiplier() 委托读取
	# SpellcraftSystem 已通过 SaveManager.get_speed_multiplier() 获取
	
	# 拾取范围 → 存储到 GameManager meta，供 player.gd 读取
	var pickup_range := get_instrument_bonus("pickup_range")
	if pickup_range > 0.0:
		GameManager.set_meta("meta_pickup_range_bonus", pickup_range)
	
	# 完美判定窗口 → 存储到 GameManager meta，供 rhythm_indicator.gd 读取
	var perfect_window := get_instrument_bonus("perfect_window_ms")
	if perfect_window > 0.0:
		GameManager.set_meta("meta_perfect_window_bonus_ms", perfect_window)

func _apply_mode_passive() -> void:
	var passive := get_mode_passive()
	if passive["type"] == "":
		return
	
	GameManager.set_meta("meta_mode_passive_type", passive["type"])
	GameManager.set_meta("meta_mode_passive_value", passive["value"])

func _apply_acoustic_bonuses() -> void:
	# 单调值减少 → 直接应用到 FatigueManager
	var monotony_reduction := get_acoustic_bonus("monotony_reduction")
	if monotony_reduction > 0.0 and FatigueManager.has_method("apply_resistance_upgrade"):
		FatigueManager.apply_resistance_upgrade({
			"type": "monotony_resist",
			"value": monotony_reduction / 100.0,
		})
	
	# 密度恢复加速 → 直接应用到 FatigueManager
	var density_recovery := get_acoustic_bonus("density_recovery")
	if density_recovery > 0.0 and FatigueManager.has_method("apply_resistance_upgrade"):
		FatigueManager.apply_resistance_upgrade({
			"type": "density_resist",
			"value": density_recovery / 100.0,
		})
	
	# 不和谐伤害减少（由 SaveManager.get_dissonance_resist_multiplier 读取）
	# 无需额外操作，GameManager.apply_dissonance_damage 已通过 SaveManager 委托读取
	
	# 休止符效率 → 存储到 GameManager meta 供 FatigueManager 读取
	var rest_efficiency := get_acoustic_bonus("rest_efficiency")
	if rest_efficiency > 0.0:
		GameManager.set_meta("meta_rest_efficiency_bonus", rest_efficiency / 100.0)

# ============================================================
# 局结束时的结算
# ============================================================

## 局结束时调用，计算并发放共鸣碎片
func on_run_completed(run_data: Dictionary) -> Dictionary:
	total_runs += 1
	
	var fragments_earned := 0
	
	# 基础奖励：存活时间
	var survival_time: float = run_data.get("survival_time", 0.0)
	fragments_earned += int(survival_time / 30.0) * 5  # 每 30 秒 5 碎片
	
	# 击杀奖励
	var kills: int = run_data.get("total_kills", 0)
	fragments_earned += int(kills / 20.0) * 3  # 每 20 击杀 3 碎片
	
	# Boss 击败奖励
	var bosses_defeated: int = run_data.get("bosses_defeated", 0)
	fragments_earned += bosses_defeated * 30  # 每个 Boss 30 碎片
	total_bosses_defeated += bosses_defeated
	
	# 等级奖励
	var max_level: int = run_data.get("max_level", 1)
	fragments_earned += max_level * 2  # 每级 2 碎片
	
	# 和谐度奖励
	var harmony_score: float = run_data.get("harmony_score", 0.0)
	if harmony_score > 0.8:
		fragments_earned = int(fragments_earned * 1.5)  # 高和谐度 +50%
	elif harmony_score > 0.6:
		fragments_earned = int(fragments_earned * 1.2)  # 中和谐度 +20%
	
	# 发放碎片
	add_resonance_fragments(fragments_earned)
	
	var result := {
		"fragments_earned": fragments_earned,
		"total_fragments": resonance_fragments,
		"survival_time": survival_time,
		"total_kills": kills,
		"bosses_defeated": bosses_defeated,
		"max_level": max_level,
		"harmony_bonus": harmony_score > 0.6,
	}
	
	save_meta_data()
	return result

# ============================================================
# 供 UI 适配接口（hall_of_harmony.gd 使用）
# ============================================================

## 获取所有升级项的当前等级 { upgrade_id: level }
func get_upgrade_levels() -> Dictionary:
	var levels := instrument_levels.duplicate()
	for key in acoustic_levels:
		levels[key] = acoustic_levels[key]
	return levels

## 获取所有已解锁的技能/乐理项 { theory_id: bool }
func get_unlocked_skills() -> Dictionary:
	return unlocked_theories.duplicate()

## 获取当前选择的调式名称
func get_selected_mode() -> String:
	return selected_mode

## 设置当前调式（别名，委托给 select_mode）
func set_selected_mode(mode_name: String) -> bool:
	return select_mode(mode_name)

## 购买升级（通用接口，自动判断模块）
func purchase_upgrade(upgrade_id: String, _cost: int = 0) -> bool:
	if INSTRUMENT_UPGRADES.has(upgrade_id):
		return purchase_instrument_upgrade(upgrade_id)
	elif ACOUSTIC_UPGRADES.has(upgrade_id):
		return purchase_acoustic_upgrade(upgrade_id)
	elif THEORY_UNLOCKS.has(upgrade_id):
		return purchase_theory_unlock(upgrade_id)
	return false

## 解锁技能（通用接口，委托给对应模块）
func unlock_skill(skill_id: String, _cost: int = 0) -> bool:
	if THEORY_UNLOCKS.has(skill_id):
		return purchase_theory_unlock(skill_id)
	elif MODE_CONFIGS.has(skill_id):
		return purchase_mode_unlock(skill_id)
	return false

# ============================================================
# 获取所有模块的完整状态（供 UI 使用）
# ============================================================

func get_full_state() -> Dictionary:
	return {
		"resonance_fragments": resonance_fragments,
		"total_runs": total_runs,
		"total_bosses_defeated": total_bosses_defeated,
		"selected_mode": selected_mode,
		"instrument_levels": instrument_levels.duplicate(),
		"unlocked_theories": unlocked_theories.duplicate(),
		"unlocked_modes": unlocked_modes.duplicate(),
		"acoustic_levels": acoustic_levels.duplicate(),
	}

# ============================================================
# 调试/测试接口
# ============================================================

## 重置所有局外进度（调试用）
func debug_reset_all() -> void:
	resonance_fragments = 0
	total_runs = 0
	total_bosses_defeated = 0
	_init_defaults()
	save_meta_data()

## 添加测试用碎片
func debug_add_fragments(amount: int) -> void:
	add_resonance_fragments(amount)
