## mode_system.gd
## 调式系统 (Autoload)
## 根据玩家选择的调式/职业，限制可用音符、应用专属加成和被动效果
##
## 设计依据 (MetaProgressionSystem_Documentation.md):
##   - 伊奥尼亚 (Ionian): 均衡者 — 全套白键 (CDEFGAB)，和谐度高
##   - 多利亚 (Dorian): 民谣诗人 — 小调色彩，初始自带"回响"修饰符
##   - 五声音阶 (Pentatonic): 东方行者 — 仅 CDEGA，剩余音符基础伤害 +20%
##   - 布鲁斯 (Blues): 爵士乐手 — 不和谐值可转化为暴击率
extends Node

# ============================================================
# 信号
# ============================================================
signal mode_changed(mode_id: String)
signal crit_from_dissonance(crit_chance: float)

# ============================================================
# 调式定义：可用白键和专属效果
# ============================================================
const MODE_DEFINITIONS: Dictionary = {
	"ionian": {
		"name": "伊奥尼亚",
		"subtitle": "均衡者",
		"available_white_keys": [
			MusicData.WhiteKey.C, MusicData.WhiteKey.D, MusicData.WhiteKey.E,
			MusicData.WhiteKey.F, MusicData.WhiteKey.G, MusicData.WhiteKey.A,
			MusicData.WhiteKey.B,
		],
		"damage_multiplier": 1.0,
		"passive": "none",
		"passive_desc": "无特殊被动，全键位均衡",
	},
	"dorian": {
		"name": "多利亚",
		"subtitle": "民谣诗人",
		"available_white_keys": [
			MusicData.WhiteKey.C, MusicData.WhiteKey.D, MusicData.WhiteKey.E,
			MusicData.WhiteKey.F, MusicData.WhiteKey.G, MusicData.WhiteKey.A,
			MusicData.WhiteKey.B,
		],
		"damage_multiplier": 1.0,
		"passive": "auto_echo",
		"passive_desc": "初始自带回响修饰符效果（每3次施法自动附加回响）",
		"auto_echo_interval": 3,  # 每3次施法自动附加一次回响
	},
	"pentatonic": {
		"name": "五声音阶",
		"subtitle": "东方行者",
		"available_white_keys": [
			MusicData.WhiteKey.C, MusicData.WhiteKey.D, MusicData.WhiteKey.E,
			MusicData.WhiteKey.G, MusicData.WhiteKey.A,
		],  # 移除 F 和 B
		"damage_multiplier": 1.2,  # 剩余音符基础伤害 +20%
		"passive": "harmony_shield",
		"passive_desc": "极难产生不和谐值，不和谐度减半",
		"dissonance_multiplier": 0.5,
	},
	"blues": {
		"name": "布鲁斯",
		"subtitle": "爵士乐手",
		"available_white_keys": [
			MusicData.WhiteKey.C, MusicData.WhiteKey.D, MusicData.WhiteKey.E,
			MusicData.WhiteKey.F, MusicData.WhiteKey.G, MusicData.WhiteKey.A,
			MusicData.WhiteKey.B,
		],
		"damage_multiplier": 1.0,
		"passive": "dissonance_crit",
		"passive_desc": "不和谐值可转化为暴击率（每点不和谐度 +3% 暴击率，上限30%）",
		"crit_per_dissonance": 0.03,
		"crit_cap": 0.30,
	},
}

# ============================================================
# 运行时状态
# ============================================================
## 当前选择的调式 ID
var current_mode_id: String = "ionian"

## 当前调式的可用白键集合（用于快速查找）
var available_white_keys: Array[int] = []

## 当前调式的伤害倍率
var damage_multiplier: float = 1.0

## 当前调式的不和谐度倍率（五声音阶专用）
var dissonance_multiplier: float = 1.0

## 布鲁斯调式：累计不和谐度 → 暴击率
var blues_crit_chance: float = 0.0

## 多利亚调式：施法计数器（用于自动回响）
var _dorian_cast_counter: int = 0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 从存档读取当前调式
	var saved_mode := SaveManager.get_selected_mode()
	apply_mode(saved_mode)

# ============================================================
# 调式应用
# ============================================================

## 应用指定调式（在每局游戏开始时由 GameManager.start_game 调用）
func apply_mode(mode_id: String) -> void:
	if not MODE_DEFINITIONS.has(mode_id):
		mode_id = "ionian"

	current_mode_id = mode_id
	var def: Dictionary = MODE_DEFINITIONS[mode_id]

	# 设置可用白键
	available_white_keys.clear()
	for key in def["available_white_keys"]:
		available_white_keys.append(key)

	# 设置伤害倍率
	damage_multiplier = def.get("damage_multiplier", 1.0)

	# 设置不和谐度倍率
	dissonance_multiplier = def.get("dissonance_multiplier", 1.0)

	# 重置被动状态
	blues_crit_chance = 0.0
	_dorian_cast_counter = 0

	mode_changed.emit(mode_id)

## 重置（供 GameManager.reset_game 调用）
func reset() -> void:
	blues_crit_chance = 0.0
	_dorian_cast_counter = 0
	apply_mode(SaveManager.get_selected_mode())

# ============================================================
# 查询接口
# ============================================================

## 检查某个白键在当前调式下是否可用
func is_white_key_available(white_key: MusicData.WhiteKey) -> bool:
	return white_key in available_white_keys

## 获取当前调式的伤害倍率
func get_damage_multiplier() -> float:
	return damage_multiplier

## 获取当前调式的不和谐度倍率
func get_dissonance_multiplier() -> float:
	return dissonance_multiplier

## 获取当前调式信息
func get_current_mode_info() -> Dictionary:
	return MODE_DEFINITIONS.get(current_mode_id, MODE_DEFINITIONS["ionian"])

## 获取所有可用白键的名称列表（用于UI显示）
func get_available_key_names() -> Array[String]:
	var names: Array[String] = []
	for key in available_white_keys:
		var stats: Dictionary = MusicData.WHITE_KEY_STATS.get(key, {})
		names.append(stats.get("name", "?"))
	return names

# ============================================================
# 被动效果处理
# ============================================================

## 施法时调用：处理调式被动效果
## 返回需要附加的额外修饰符（-1 表示无）
func on_spell_cast() -> int:
	var def: Dictionary = MODE_DEFINITIONS.get(current_mode_id, {})
	var passive: String = def.get("passive", "none")

	match passive:
		"auto_echo":
			# 多利亚：每N次施法自动附加回响
			_dorian_cast_counter += 1
			var interval: int = def.get("auto_echo_interval", 3)
			if _dorian_cast_counter >= interval:
				_dorian_cast_counter = 0
				return MusicData.ModifierEffect.ECHO
		"dissonance_crit":
			# 布鲁斯：暴击率已在 on_dissonance_applied 中更新
			pass

	return -1  # 无额外修饰符

## 不和谐度产生时调用：处理布鲁斯被动
func on_dissonance_applied(dissonance: float) -> void:
	var def: Dictionary = MODE_DEFINITIONS.get(current_mode_id, {})
	if def.get("passive", "") != "dissonance_crit":
		return

	var crit_per := def.get("crit_per_dissonance", 0.03)
	var cap := def.get("crit_cap", 0.30)

	blues_crit_chance = min(blues_crit_chance + dissonance * crit_per, cap)
	crit_from_dissonance.emit(blues_crit_chance)

## 检查是否触发暴击（布鲁斯被动）
func check_crit() -> bool:
	if current_mode_id != "blues":
		return false
	return randf() < blues_crit_chance

## 获取当前暴击率（布鲁斯被动）
func get_crit_chance() -> float:
	return blues_crit_chance
