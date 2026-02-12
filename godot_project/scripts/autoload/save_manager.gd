## save_manager.gd
## 存档管理器 (Autoload)
## 负责游戏数据的持久化存储（ConfigFile）
## 包括：局内进度、设置
##
## ★ 局外成长数据统一由 MetaProgressionManager 管理和持久化
##   本文件仅保留局内进度存档和设置存档功能
##   所有局外升级的查询/购买/应用均委托给 MetaProgressionManager
extends Node

# ============================================================
# 信号
# ============================================================
signal resonance_changed(amount: int)

# ============================================================
# 路径
# ============================================================
const SAVE_PATH = "user://save_game.cfg"
const SETTINGS_PATH = "user://settings.cfg"

# ============================================================
# 内部数据
# ============================================================
var _save_data := ConfigFile.new()
var _settings_data := ConfigFile.new()

# ============================================================
# MetaProgressionManager 引用（延迟获取，避免 Autoload 顺序问题）
# ============================================================
var _meta: Node = null

func _get_meta() -> Node:
	if _meta == null:
		_meta = get_node_or_null("/root/MetaProgressionManager")
	return _meta

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

func get_best_time() -> float:
	return _save_data.get_value("progression", "best_time", 0.0)

func get_max_level() -> int:
	return _save_data.get_value("progression", "max_level", 1)

func get_total_kills() -> int:
	return _save_data.get_value("progression", "total_kills", 0)

func get_total_runs() -> int:
	return _save_data.get_value("progression", "total_runs", 0)

# ============================================================
# 共鸣碎片（委托给 MetaProgressionManager）
# ============================================================

func get_resonance_fragments() -> int:
	var meta := _get_meta()
	if meta and meta.has_method("get_resonance_fragments"):
		return meta.get_resonance_fragments()
	return 0

func add_resonance_fragments(amount: int) -> void:
	var meta := _get_meta()
	if meta and meta.has_method("add_resonance_fragments"):
		meta.add_resonance_fragments(amount)
	resonance_changed.emit(get_resonance_fragments())

func spend_resonance_fragments(amount: int) -> bool:
	var meta := _get_meta()
	if meta and meta.has_method("spend_resonance_fragments"):
		var success: bool = meta.spend_resonance_fragments(amount)
		if success:
			resonance_changed.emit(get_resonance_fragments())
		return success
	return false

# ============================================================
# 乐器调优 — 委托给 MetaProgressionManager
# ============================================================

func get_instrument_level(upgrade_id: String) -> int:
	var meta := _get_meta()
	if meta and meta.has_method("get_instrument_level"):
		return meta.get_instrument_level(upgrade_id)
	return 0

func upgrade_instrument(upgrade_id: String) -> bool:
	var meta := _get_meta()
	if meta and meta.has_method("purchase_instrument_upgrade"):
		return meta.purchase_instrument_upgrade(upgrade_id)
	return false

func get_instrument_cost(upgrade_id: String) -> int:
	var meta := _get_meta()
	if meta and meta.has_method("get_instrument_cost"):
		return meta.get_instrument_cost(upgrade_id)
	return -1

func get_instrument_bonus(upgrade_id: String) -> float:
	var meta := _get_meta()
	if meta and meta.has_method("get_instrument_bonus"):
		# MetaProgressionManager 使用 stat_key 查询，这里做适配
		# 先尝试直接用 upgrade_id 作为 stat_key
		return meta.get_instrument_bonus(upgrade_id)
	return 0.0

# ============================================================
# 乐理研习 — 委托给 MetaProgressionManager
# ============================================================

func is_theory_unlocked(unlock_id: String) -> bool:
	var meta := _get_meta()
	if meta and meta.has_method("is_theory_unlocked"):
		return meta.is_theory_unlocked(unlock_id)
	return false

func unlock_theory(unlock_id: String) -> bool:
	var meta := _get_meta()
	if meta and meta.has_method("purchase_theory_unlock"):
		return meta.purchase_theory_unlock(unlock_id)
	return false

## 检查某个修饰符是否已解锁（穿透和分裂默认解锁）
func is_modifier_available(modifier: MusicData.ModifierEffect) -> bool:
	var meta := _get_meta()
	if meta and meta.has_method("is_black_key_unlocked"):
		match modifier:
			MusicData.ModifierEffect.PIERCE, MusicData.ModifierEffect.SPLIT:
				return true  # 默认解锁
			MusicData.ModifierEffect.HOMING:
				return meta.is_black_key_unlocked("Ds")
			MusicData.ModifierEffect.ECHO:
				return meta.is_black_key_unlocked("Gs")
			MusicData.ModifierEffect.SCATTER:
				return meta.is_black_key_unlocked("As")
	return false

## 检查某个和弦类型是否已解锁（大三、小三默认解锁）
func is_chord_type_available(chord_type: MusicData.ChordType) -> bool:
	var meta := _get_meta()
	if meta and meta.has_method("is_chord_unlocked"):
		match chord_type:
			MusicData.ChordType.MAJOR, MusicData.ChordType.MINOR:
				return true  # 默认解锁
			MusicData.ChordType.DIMINISHED:
				return meta.is_chord_unlocked("diminished")
			MusicData.ChordType.AUGMENTED:
				return meta.is_chord_unlocked("augmented")
			MusicData.ChordType.DOMINANT_7, MusicData.ChordType.MAJOR_7, \
			MusicData.ChordType.MINOR_7, MusicData.ChordType.DIMINISHED_7, \
			MusicData.ChordType.SUSPENDED, MusicData.ChordType.HALF_DIMINISHED_7, \
			MusicData.ChordType.AUGMENTED_MAJOR_7:
				return meta.is_chord_unlocked("dominant7")
		# 扩展和弦需要局内解锁 + 传说乐章许可
		return GameManager.extended_chords_unlocked
	return false

# ============================================================
# 声学降噪 — 委托给 MetaProgressionManager
# ============================================================

func get_acoustic_level(upgrade_id: String) -> int:
	var meta := _get_meta()
	if meta and meta.has_method("get_acoustic_level"):
		return meta.get_acoustic_level(upgrade_id)
	return 0

func upgrade_acoustic(upgrade_id: String) -> bool:
	var meta := _get_meta()
	if meta and meta.has_method("purchase_acoustic_upgrade"):
		return meta.purchase_acoustic_upgrade(upgrade_id)
	return false

func get_acoustic_bonus(upgrade_id: String) -> float:
	var meta := _get_meta()
	if meta and meta.has_method("get_acoustic_bonus"):
		return meta.get_acoustic_bonus(upgrade_id)
	return 0.0

# ============================================================
# 调式/职业选择 — 委托给 MetaProgressionManager
# ============================================================

func get_selected_mode() -> String:
	var meta := _get_meta()
	if meta and meta.has_method("get_selected_mode"):
		return meta.get_selected_mode()
	return "ionian"

func set_selected_mode(mode_id: String) -> bool:
	var meta := _get_meta()
	if meta and meta.has_method("set_selected_mode"):
		return meta.set_selected_mode(mode_id)
	return false

func is_mode_unlocked(mode_id: String) -> bool:
	var meta := _get_meta()
	if meta and meta.has_method("is_mode_unlocked"):
		return meta.is_mode_unlocked(mode_id)
	return mode_id == "ionian"

func unlock_mode(mode_id: String) -> bool:
	var meta := _get_meta()
	if meta and meta.has_method("purchase_mode_unlock"):
		return meta.purchase_mode_unlock(mode_id)
	return false

func get_all_unlocked_modes() -> Array[String]:
	var meta := _get_meta()
	var result: Array[String] = []
	if meta and meta.has_method("get_full_state"):
		var state: Dictionary = meta.get_full_state()
		var modes: Dictionary = state.get("unlocked_modes", {})
		for mode_name in modes:
			if modes[mode_name]:
				result.append(mode_name)
		return result
	result.append("ionian")
	return result

# ============================================================
# 局外加成应用（每局开始时调用）
# 委托给 MetaProgressionManager.apply_meta_bonuses()
# ============================================================

func apply_meta_bonuses() -> void:
	var meta := _get_meta()
	if meta and meta.has_method("apply_meta_bonuses"):
		meta.apply_meta_bonuses()

## 获取不和谐伤害减免倍率（供 GameManager 调用）
func get_dissonance_resist_multiplier() -> float:
	var meta := _get_meta()
	if meta and meta.has_method("get_acoustic_bonus"):
		var reduction: float = meta.get_acoustic_bonus("dissonance_damage_reduction")
		# 每级减少 1 HP 的腐蚀，转换为倍率
		# 最大3级 × 1.0 = 3.0 HP 减免，基础伤害 = dissonance × 2.0
		# 使用百分比减免更合理：每级 -15%
		return max(0.0, 1.0 - reduction * 0.15)
	return 1.0

## 获取伤害加成倍率（供 SpellcraftSystem 调用）
func get_damage_multiplier() -> float:
	var meta := _get_meta()
	if meta and meta.has_method("get_instrument_bonus"):
		var damage_pct: float = meta.get_instrument_bonus("damage_mult")
		return 1.0 + damage_pct / 100.0
	return 1.0

## 获取速度加成倍率
func get_speed_multiplier() -> float:
	var meta := _get_meta()
	if meta and meta.has_method("get_instrument_bonus"):
		var speed_pct: float = meta.get_instrument_bonus("projectile_speed_mult")
		return 1.0 + speed_pct / 100.0
	return 1.0

## 获取拾取范围加成（像素）
func get_pickup_range_bonus() -> float:
	var meta := _get_meta()
	if meta and meta.has_method("get_instrument_bonus"):
		return meta.get_instrument_bonus("pickup_range")
	return 0.0

## 获取节拍判定窗口加成（毫秒）
func get_timing_window_bonus() -> float:
	var meta := _get_meta()
	if meta and meta.has_method("get_instrument_bonus"):
		return meta.get_instrument_bonus("perfect_window_ms")
	return 0.0

## 获取休止符效率加成（百分比）
func get_rest_efficiency_bonus() -> float:
	var meta := _get_meta()
	if meta and meta.has_method("get_acoustic_bonus"):
		return meta.get_acoustic_bonus("rest_efficiency")
	return 0.0

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
	var meta := _get_meta()
	if meta and meta.has_method("debug_reset_all"):
		meta.debug_reset_all()
