## save_manager.gd
## 存档管理器 (Autoload)
## 负责游戏数据的持久化存储（ConfigFile）
## 包括：局内进度、局外成长系统（和谐殿堂）、设置
extends Node

# ============================================================
# 信号
# ============================================================
signal resonance_changed(amount: int)
signal meta_upgrade_unlocked(module: String, upgrade_id: String, level: int)

# ============================================================
# 路径
# ============================================================
const SAVE_PATH = "user://save_game.cfg"
const SETTINGS_PATH = "user://settings.cfg"

# ============================================================
# 局外成长：乐器调优 (Instrument Tuning) 配置
# ============================================================
const INSTRUMENT_UPGRADES := {
	"stage_presence": {
		"name": "舞台定力",
		"desc": "提升初始最大生命值",
		"max_level": 10,
		"cost_base": 50,
		"cost_scale": 1.3,
		"per_level": 10.0,  # +10 HP/级
	},
	"acoustic_pressure": {
		"name": "基础声压",
		"desc": "提升所有法术基础伤害倍率",
		"max_level": 10,
		"cost_base": 60,
		"cost_scale": 1.4,
		"per_level": 0.02,  # +2%/级
	},
	"rhythmic_sense": {
		"name": "节拍敏锐度",
		"desc": "放宽完美判定时间窗口",
		"max_level": 5,
		"cost_base": 80,
		"cost_scale": 1.5,
		"per_level": 0.02,  # +20ms/级
	},
	"pickup_range": {
		"name": "拾音范围",
		"desc": "扩大自动吸附掉落物范围",
		"max_level": 8,
		"cost_base": 40,
		"cost_scale": 1.2,
		"per_level": 15.0,  # +15px/级
	},
	"upbeat_velocity": {
		"name": "起拍速度",
		"desc": "提升初始投射物飞行速度",
		"max_level": 8,
		"cost_base": 50,
		"cost_scale": 1.3,
		"per_level": 0.03,  # +3%/级
	},
}

# ============================================================
# 局外成长：乐理研习 (Theory Archives) 配置
# ============================================================
const THEORY_UNLOCKS := {
	# 黑键修饰符
	"modifier_homing": { "name": "追踪修饰符 (D#)", "cost": 120, "type": "modifier" },
	"modifier_echo": { "name": "回响修饰符 (G#)", "cost": 150, "type": "modifier" },
	"modifier_scatter": { "name": "散射修饰符 (A#)", "cost": 100, "type": "modifier" },
	# 和弦解锁
	"chord_diminished": { "name": "减三和弦 (冲击波)", "cost": 100, "type": "chord" },
	"chord_augmented": { "name": "增三和弦 (爆炸)", "cost": 100, "type": "chord" },
	"chord_seventh": { "name": "七和弦解析", "cost": 200, "type": "chord" },
	# 传说乐章
	"extended_chord_chance": { "name": "传说乐章许可", "cost": 300, "type": "legendary" },
}

# ============================================================
# 局外成长：声学降噪 (Acoustic Treatment) 配置
# ============================================================
const ACOUSTIC_UPGRADES := {
	"auditory_tolerance": {
		"name": "听觉耐受",
		"desc": "降低单调值累积速度",
		"max_level": 3,
		"cost_base": 100,
		"cost_scale": 1.5,
		"per_level": 0.05,  # -5%/级
	},
	"reverb_damping": {
		"name": "混响消除",
		"desc": "加快密度值恢复速度",
		"max_level": 3,
		"cost_base": 100,
		"cost_scale": 1.5,
		"per_level": 0.5,  # +0.5s 半衰期缩短/级
	},
	"perfect_pitch": {
		"name": "绝对音感",
		"desc": "减少不和谐值造成的生命腐蚀",
		"max_level": 3,
		"cost_base": 120,
		"cost_scale": 1.5,
		"per_level": 0.15,  # -15%/级
	},
	"rest_aesthetics": {
		"name": "休止符美学",
		"desc": "提升休止符清除负面状态效率",
		"max_level": 3,
		"cost_base": 80,
		"cost_scale": 1.4,
		"per_level": 0.1,  # +10%/级
	},
}

# ============================================================
# 调式/职业
# ============================================================
const MODES := {
	"ionian": { "name": "伊奥尼亚", "desc": "均衡者 — 全套白键，和谐度高", "cost": 0 },
	"dorian": { "name": "多利亚", "desc": "民谣诗人 — 小调色彩，自带回响", "cost": 200 },
	"pentatonic": { "name": "五声音阶", "desc": "东方行者 — 仅5键，单发+20%", "cost": 150 },
	"blues": { "name": "布鲁斯", "desc": "爵士乐手 — 不和谐可转暴击", "cost": 250 },
}

# ============================================================
# 内部数据
# ============================================================
var _save_data := ConfigFile.new()
var _settings_data := ConfigFile.new()

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	load_game()
	load_settings()

# ============================================================
# 游戏进度存档（局内结算）
# ============================================================

func save_game() -> void:
	# 累计统计
	var prev_kills: int = _save_data.get_value("progression", "total_kills", 0)
	_save_data.set_value("progression", "total_kills", prev_kills + GameManager.session_kills)
	_save_data.set_value("progression", "best_time", max(get_best_time(), GameManager.game_time))
	_save_data.set_value("progression", "max_level", max(get_max_level(), GameManager.player_level))

	# 累计游戏次数
	var runs: int = _save_data.get_value("progression", "total_runs", 0)
	_save_data.set_value("progression", "total_runs", runs + 1)

	var err = _save_data.save(SAVE_PATH)
	if err != OK:
		push_error("SaveManager: Failed to save game data!")

func load_game() -> void:
	var err = _save_data.load(SAVE_PATH)
	if err != OK:
		# 首次运行，初始化默认值
		_init_default_save()

func _init_default_save() -> void:
	_save_data.set_value("progression", "total_kills", 0)
	_save_data.set_value("progression", "best_time", 0.0)
	_save_data.set_value("progression", "max_level", 1)
	_save_data.set_value("progression", "total_runs", 0)

	# 局外成长：共鸣碎片
	_save_data.set_value("meta", "resonance_fragments", 0)

	# 局外成长：当前选择的调式
	_save_data.set_value("meta", "selected_mode", "ionian")

	# 局外成长：已解锁的调式
	_save_data.set_value("meta", "unlocked_modes", "ionian")  # 逗号分隔

func get_best_time() -> float:
	return _save_data.get_value("progression", "best_time", 0.0)

func get_max_level() -> int:
	return _save_data.get_value("progression", "max_level", 1)

func get_total_kills() -> int:
	return _save_data.get_value("progression", "total_kills", 0)

func get_total_runs() -> int:
	return _save_data.get_value("progression", "total_runs", 0)

# ============================================================
# 共鸣碎片（局外货币）
# ============================================================

func get_resonance_fragments() -> int:
	return _save_data.get_value("meta", "resonance_fragments", 0)

func add_resonance_fragments(amount: int) -> void:
	var current: int = get_resonance_fragments()
	_save_data.set_value("meta", "resonance_fragments", current + amount)
	_save_data.save(SAVE_PATH)
	resonance_changed.emit(current + amount)

func spend_resonance_fragments(amount: int) -> bool:
	var current: int = get_resonance_fragments()
	if current < amount:
		return false
	_save_data.set_value("meta", "resonance_fragments", current - amount)
	_save_data.save(SAVE_PATH)
	resonance_changed.emit(current - amount)
	return true

# ============================================================
# 乐器调优 (Instrument Tuning)
# ============================================================

func get_instrument_level(upgrade_id: String) -> int:
	return _save_data.get_value("instrument", upgrade_id, 0)

func upgrade_instrument(upgrade_id: String) -> bool:
	if not INSTRUMENT_UPGRADES.has(upgrade_id):
		return false

	var config: Dictionary = INSTRUMENT_UPGRADES[upgrade_id]
	var current_level: int = get_instrument_level(upgrade_id)

	if current_level >= config["max_level"]:
		return false

	var cost: int = int(config["cost_base"] * pow(config["cost_scale"], current_level))
	if not spend_resonance_fragments(cost):
		return false

	_save_data.set_value("instrument", upgrade_id, current_level + 1)
	_save_data.save(SAVE_PATH)
	meta_upgrade_unlocked.emit("instrument", upgrade_id, current_level + 1)
	return true

func get_instrument_cost(upgrade_id: String) -> int:
	if not INSTRUMENT_UPGRADES.has(upgrade_id):
		return -1
	var config: Dictionary = INSTRUMENT_UPGRADES[upgrade_id]
	var current_level: int = get_instrument_level(upgrade_id)
	if current_level >= config["max_level"]:
		return -1
	return int(config["cost_base"] * pow(config["cost_scale"], current_level))

## 获取乐器调优的实际加成值
func get_instrument_bonus(upgrade_id: String) -> float:
	if not INSTRUMENT_UPGRADES.has(upgrade_id):
		return 0.0
	var level: int = get_instrument_level(upgrade_id)
	return level * INSTRUMENT_UPGRADES[upgrade_id]["per_level"]

# ============================================================
# 乐理研习 (Theory Archives)
# ============================================================

func is_theory_unlocked(unlock_id: String) -> bool:
	return _save_data.get_value("theory", unlock_id, false)

func unlock_theory(unlock_id: String) -> bool:
	if not THEORY_UNLOCKS.has(unlock_id):
		return false
	if is_theory_unlocked(unlock_id):
		return false

	var cost: int = THEORY_UNLOCKS[unlock_id]["cost"]
	if not spend_resonance_fragments(cost):
		return false

	_save_data.set_value("theory", unlock_id, true)
	_save_data.save(SAVE_PATH)
	meta_upgrade_unlocked.emit("theory", unlock_id, 1)
	return true

## 检查某个修饰符是否已解锁（穿透和分裂默认解锁）
func is_modifier_available(modifier: MusicData.ModifierEffect) -> bool:
	match modifier:
		MusicData.ModifierEffect.PIERCE, MusicData.ModifierEffect.SPLIT:
			return true  # 默认解锁
		MusicData.ModifierEffect.HOMING:
			return is_theory_unlocked("modifier_homing")
		MusicData.ModifierEffect.ECHO:
			return is_theory_unlocked("modifier_echo")
		MusicData.ModifierEffect.SCATTER:
			return is_theory_unlocked("modifier_scatter")
	return false

## 检查某个和弦类型是否已解锁（大三、小三默认解锁）
func is_chord_type_available(chord_type: MusicData.ChordType) -> bool:
	match chord_type:
		MusicData.ChordType.MAJOR, MusicData.ChordType.MINOR:
			return true  # 默认解锁
		MusicData.ChordType.DIMINISHED:
			return is_theory_unlocked("chord_diminished")
		MusicData.ChordType.AUGMENTED:
			return is_theory_unlocked("chord_augmented")
		MusicData.ChordType.DOMINANT_7TH, MusicData.ChordType.MAJOR_7TH, \
		MusicData.ChordType.MINOR_7TH, MusicData.ChordType.DIMINISHED_7TH:
			return is_theory_unlocked("chord_seventh")
	# 扩展和弦需要局内解锁 + 传说乐章许可
	return GameManager.extended_chords_unlocked

# ============================================================
# 声学降噪 (Acoustic Treatment)
# ============================================================

func get_acoustic_level(upgrade_id: String) -> int:
	return _save_data.get_value("acoustic", upgrade_id, 0)

func upgrade_acoustic(upgrade_id: String) -> bool:
	if not ACOUSTIC_UPGRADES.has(upgrade_id):
		return false

	var config: Dictionary = ACOUSTIC_UPGRADES[upgrade_id]
	var current_level: int = get_acoustic_level(upgrade_id)

	if current_level >= config["max_level"]:
		return false

	var cost: int = int(config["cost_base"] * pow(config["cost_scale"], current_level))
	if not spend_resonance_fragments(cost):
		return false

	_save_data.set_value("acoustic", upgrade_id, current_level + 1)
	_save_data.save(SAVE_PATH)
	meta_upgrade_unlocked.emit("acoustic", upgrade_id, current_level + 1)
	return true

func get_acoustic_bonus(upgrade_id: String) -> float:
	if not ACOUSTIC_UPGRADES.has(upgrade_id):
		return 0.0
	var level: int = get_acoustic_level(upgrade_id)
	return level * ACOUSTIC_UPGRADES[upgrade_id]["per_level"]

# ============================================================
# 调式/职业选择
# ============================================================

func get_selected_mode() -> String:
	return _save_data.get_value("meta", "selected_mode", "ionian")

func set_selected_mode(mode_id: String) -> bool:
	if not is_mode_unlocked(mode_id):
		return false
	_save_data.set_value("meta", "selected_mode", mode_id)
	_save_data.save(SAVE_PATH)
	return true

func is_mode_unlocked(mode_id: String) -> bool:
	var unlocked_str: String = _save_data.get_value("meta", "unlocked_modes", "ionian")
	return mode_id in unlocked_str.split(",")

func unlock_mode(mode_id: String) -> bool:
	if not MODES.has(mode_id):
		return false
	if is_mode_unlocked(mode_id):
		return false

	var cost: int = MODES[mode_id]["cost"]
	if not spend_resonance_fragments(cost):
		return false

	var unlocked_str: String = _save_data.get_value("meta", "unlocked_modes", "ionian")
	unlocked_str += "," + mode_id
	_save_data.set_value("meta", "unlocked_modes", unlocked_str)
	_save_data.save(SAVE_PATH)
	meta_upgrade_unlocked.emit("mode", mode_id, 1)
	return true

func get_all_unlocked_modes() -> Array[String]:
	var unlocked_str: String = _save_data.get_value("meta", "unlocked_modes", "ionian")
	var result: Array[String] = []
	for m in unlocked_str.split(","):
		if not m.is_empty():
			result.append(m)
	return result

# ============================================================
# 局外加成应用（每局开始时调用）
# ============================================================

## 将所有局外升级的加成应用到 GameManager 和 FatigueManager
func apply_meta_bonuses() -> void:
	# 乐器调优
	GameManager.player_max_hp += get_instrument_bonus("stage_presence")
	GameManager.player_current_hp = GameManager.player_max_hp

	# 声学降噪 → 疲劳系统
	var monotony_resist := get_acoustic_bonus("auditory_tolerance")
	var density_resist := get_acoustic_bonus("reverb_damping")
	if monotony_resist > 0.0:
		FatigueManager.apply_resistance_upgrade({
			"type": "monotony_resist",
			"value": monotony_resist,
		})
	if density_resist > 0.0:
		FatigueManager.apply_resistance_upgrade({
			"type": "density_resist",
			"value": density_resist,
		})

	# 不和谐伤害减免
	var dissonance_resist := get_acoustic_bonus("perfect_pitch")
	if dissonance_resist > 0.0:
		# 通过修改 GameManager 的伤害系数实现
		# GameManager 中的 DISSONANCE_DAMAGE_PER_POINT 是 const，
		# 所以我们在 apply_dissonance_damage 中通过乘数来处理
		pass  # 由 GameManager.apply_dissonance_damage 读取

## 获取不和谐伤害减免倍率（供 GameManager 调用）
func get_dissonance_resist_multiplier() -> float:
	return 1.0 - get_acoustic_bonus("perfect_pitch")

## 获取伤害加成倍率（供 SpellcraftSystem 调用）
func get_damage_multiplier() -> float:
	return 1.0 + get_instrument_bonus("acoustic_pressure")

## 获取速度加成倍率
func get_speed_multiplier() -> float:
	return 1.0 + get_instrument_bonus("upbeat_velocity")

## 获取拾取范围加成
func get_pickup_range_bonus() -> float:
	return get_instrument_bonus("pickup_range")

## 获取节拍判定窗口加成（秒）
func get_timing_window_bonus() -> float:
	return get_instrument_bonus("rhythmic_sense")

# ============================================================
# 设置存档
# ============================================================

func save_settings(settings: Dictionary) -> void:
	for key in settings:
		_settings_data.set_value("audio", key, settings[key])
	_settings_data.save(SETTINGS_PATH)

func load_settings() -> Dictionary:
	var err = _settings_data.load(SETTINGS_PATH)
	var settings = {}
	if err == OK:
		if _settings_data.has_section("audio"):
			for key in _settings_data.get_section_keys("audio"):
				settings[key] = _settings_data.get_value("audio", key)
	return settings

# ============================================================
# 重置（调试用）
# ============================================================

func reset_all_progress() -> void:
	_init_default_save()
	_save_data.save(SAVE_PATH)
