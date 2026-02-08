## codex_manager.gd
## 图鉴系统 "谐振法典 (Codex Resonare)" 全局管理器 (Autoload)
##
## 职责：
##   1. 管理所有图鉴条目的解锁状态
##   2. 通过 SaveManager 持久化解锁数据
##   3. 提供解锁触发接口（供其他系统调用）
##   4. 追踪击杀统计（用于敌人图鉴里程碑）
##   5. 计算图鉴完成度并提供奖励
##
## 与其他系统的集成点：
##   - GameManager.enemy_killed → 触发敌人条目解锁
##   - SpellcraftSystem.chord_cast → 触发和弦/法术条目解锁
##   - MetaProgressionManager.upgrade_purchased → 触发乐理/音色条目解锁
##   - SaveManager → 持久化存储
extends Node

# ============================================================
# 信号
# ============================================================
signal entry_unlocked(entry_id: String, entry_name: String, volume: CodexData.Volume)
signal milestone_reached(entry_id: String, milestone: int, current_kills: int)
signal completion_updated(volume: CodexData.Volume, unlocked: int, total: int)

# ============================================================
# 常量
# ============================================================
const CODEX_SAVE_SECTION := "codex"
const KILLS_SAVE_SECTION := "codex_kills"

# ============================================================
# 内部状态
# ============================================================
## 已解锁的条目集合 { entry_id: true }
var _unlocked_entries: Dictionary = {}

## 敌人击杀计数 { enemy_type_key: kill_count }
var _kill_counts: Dictionary = {}

## 已达成的里程碑 { entry_id: [milestone1, milestone2, ...] }
var _reached_milestones: Dictionary = {}

## 缓存：各卷完成度 { Volume: { "unlocked": int, "total": int } }
var _completion_cache: Dictionary = {}
var _cache_dirty: bool = true

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_load_codex_data()
	_unlock_default_entries()
	_connect_signals()

# ============================================================
# 初始化
# ============================================================

## 加载已保存的图鉴数据
func _load_codex_data() -> void:
	if not SaveManager:
		push_warning("CodexManager: SaveManager not available, using defaults")
		return

	var save_data: ConfigFile = SaveManager._save_data

	# 加载已解锁条目
	if save_data.has_section(CODEX_SAVE_SECTION):
		for key in save_data.get_section_keys(CODEX_SAVE_SECTION):
			_unlocked_entries[key] = save_data.get_value(CODEX_SAVE_SECTION, key, false)

	# 加载击杀计数
	if save_data.has_section(KILLS_SAVE_SECTION):
		for key in save_data.get_section_keys(KILLS_SAVE_SECTION):
			_kill_counts[key] = save_data.get_value(KILLS_SAVE_SECTION, key, 0)

	# 加载里程碑
	if save_data.has_section("codex_milestones"):
		for key in save_data.get_section_keys("codex_milestones"):
			var milestones_str: String = save_data.get_value("codex_milestones", key, "")
			if not milestones_str.is_empty():
				var arr: Array[int] = []
				for s in milestones_str.split(","):
					if s.is_valid_int():
						arr.append(int(s))
				_reached_milestones[key] = arr

## 解锁所有默认条目
func _unlock_default_entries() -> void:
	for volume in CodexData.Volume.values():
		var entries = CodexData.get_volume_entries(volume)
		for entry_id in entries:
			var data = CodexData.find_entry(entry_id)
			if data.is_empty():
				continue
			if data.get("unlock_type", CodexData.UnlockType.DEFAULT) == CodexData.UnlockType.DEFAULT:
				_unlock_entry_internal(entry_id, false)  # 静默解锁，不触发信号

## 连接其他系统的信号
func _connect_signals() -> void:
	# 连接 GameManager 的敌人击杀信号
	if GameManager and GameManager.has_signal("enemy_killed"):
		if not GameManager.enemy_killed.is_connected(_on_enemy_killed):
			GameManager.enemy_killed.connect(_on_enemy_killed)

	# 连接 SpellcraftSystem 的法术施放信号
	if SpellcraftSystem:
		if SpellcraftSystem.has_signal("spell_cast") and not SpellcraftSystem.spell_cast.is_connected(_on_spell_cast):
			SpellcraftSystem.spell_cast.connect(_on_spell_cast)
		if SpellcraftSystem.has_signal("chord_cast") and not SpellcraftSystem.chord_cast.is_connected(_on_chord_cast):
			SpellcraftSystem.chord_cast.connect(_on_chord_cast)

# ============================================================
# 解锁接口
# ============================================================

## 解锁指定条目（公共接口）
func unlock_entry(entry_id: String) -> bool:
	if is_unlocked(entry_id):
		return false

	var data = CodexData.find_entry(entry_id)
	if data.is_empty():
		push_warning("CodexManager: Unknown entry '%s'" % entry_id)
		return false

	_unlock_entry_internal(entry_id, true)
	return true

## 内部解锁逻辑
func _unlock_entry_internal(entry_id: String, emit_signal: bool) -> void:
	if _unlocked_entries.get(entry_id, false):
		return

	_unlocked_entries[entry_id] = true
	_cache_dirty = true

	# 持久化
	_save_entry(entry_id)

	# 触发信号
	if emit_signal:
		var data = CodexData.find_entry(entry_id)
		var volume = _get_entry_volume(entry_id)
		var entry_name: String = data.get("name", entry_id)
		entry_unlocked.emit(entry_id, entry_name, volume)

		# 更新完成度
		var comp := get_volume_completion(volume)
		completion_updated.emit(volume, comp["unlocked"], comp["total"])

## 检查条目是否已解锁
func is_unlocked(entry_id: String) -> bool:
	return _unlocked_entries.get(entry_id, false)

## 批量解锁（用于调试或测试场）
func unlock_all() -> void:
	for volume in CodexData.Volume.values():
		var entries = CodexData.get_volume_entries(volume)
		for entry_id in entries:
			_unlock_entry_internal(entry_id, false)
	_cache_dirty = true
	_save_all()

## 重置所有解锁状态（用于调试）
func reset_all() -> void:
	_unlocked_entries.clear()
	_kill_counts.clear()
	_reached_milestones.clear()
	_cache_dirty = true
	_unlock_default_entries()
	_save_all()

# ============================================================
# 击杀追踪
# ============================================================

## 记录敌人击杀（由 GameManager.enemy_killed 信号触发）
func record_kill(enemy_key: String) -> void:
	var count: int = _kill_counts.get(enemy_key, 0) + 1
	_kill_counts[enemy_key] = count

	# 检查是否触发条目解锁（首次遭遇）
	var codex_key := "enemy_" + enemy_key
	if not is_unlocked(codex_key):
		var data = CodexData.find_entry(codex_key)
		if not data.is_empty() and data.get("unlock_type") == CodexData.UnlockType.ENCOUNTER:
			unlock_entry(codex_key)

	# 同时检查章节敌人和精英的 key
	for prefix in ["ch1_", "ch2_", "ch3_", "ch4_", "ch5_"]:
		if enemy_key.begins_with(prefix):
			if not is_unlocked(enemy_key):
				var data = CodexData.find_entry(enemy_key)
				if not data.is_empty():
					unlock_entry(enemy_key)

	# 检查击杀里程碑
	_check_kill_milestones(codex_key, count)

	# 持久化击杀计数
	_save_kill_count(enemy_key)

## 获取指定敌人的击杀数
func get_kill_count(enemy_key: String) -> int:
	return _kill_counts.get(enemy_key, 0)

## 检查击杀里程碑
func _check_kill_milestones(entry_id: String, current_kills: int) -> void:
	var data = CodexData.find_entry(entry_id)
	if data.is_empty():
		return

	var milestones: Array = data.get("kill_milestones", [])
	if milestones.is_empty():
		return

	var reached: Array = _reached_milestones.get(entry_id, [])

	for milestone in milestones:
		if current_kills >= milestone and milestone not in reached:
			reached.append(milestone)
			_reached_milestones[entry_id] = reached
			milestone_reached.emit(entry_id, milestone, current_kills)
			_save_milestones(entry_id)

## 获取敌人条目的里程碑进度
func get_milestone_progress(entry_id: String) -> Dictionary:
	var data = CodexData.find_entry(entry_id)
	if data.is_empty():
		return {}

	var milestones: Array = data.get("kill_milestones", [])
	var reached: Array = _reached_milestones.get(entry_id, [])
	var enemy_key := entry_id.replace("enemy_", "")
	var kills: int = _kill_counts.get(enemy_key, 0)

	return {
		"milestones": milestones,
		"reached": reached,
		"current_kills": kills,
	}

# ============================================================
# 完成度统计
# ============================================================

## 获取指定卷的完成度
func get_volume_completion(volume: CodexData.Volume) -> Dictionary:
	if _cache_dirty:
		_rebuild_completion_cache()

	return _completion_cache.get(volume, { "unlocked": 0, "total": 0 })

## 获取总完成度
func get_total_completion() -> Dictionary:
	if _cache_dirty:
		_rebuild_completion_cache()

	var total_unlocked := 0
	var total_entries := 0
	for volume in CodexData.Volume.values():
		var comp: Dictionary = _completion_cache.get(volume, { "unlocked": 0, "total": 0 })
		total_unlocked += comp["unlocked"]
		total_entries += comp["total"]

	return {
		"unlocked": total_unlocked,
		"total": total_entries,
		"percentage": (float(total_unlocked) / max(total_entries, 1)) * 100.0,
	}

## 重建完成度缓存
func _rebuild_completion_cache() -> void:
	_completion_cache.clear()
	for volume in CodexData.Volume.values():
		var entries = CodexData.get_volume_entries(volume)
		var unlocked_count := 0
		for entry_id in entries:
			if is_unlocked(entry_id):
				unlocked_count += 1
		_completion_cache[volume] = {
			"unlocked": unlocked_count,
			"total": entries.size(),
		}
	_cache_dirty = false

# ============================================================
# 信号回调
# ============================================================

## 敌人被击杀时
func _on_enemy_killed(enemy_position: Vector2) -> void:
	# 注意：GameManager.enemy_killed 信号只传递位置
	# 实际的敌人类型需要通过其他方式获取
	# 这里我们通过 enemy_base.gd 的 enemy_died 信号来处理
	pass

## 法术施放时
func _on_spell_cast(spell_data: Dictionary) -> void:
	# 解锁节奏型条目
	var rhythm = spell_data.get("rhythm_pattern", -1)
	if rhythm >= 0:
		var rhythm_keys := ["rhythm_even_eighth", "rhythm_dotted", "rhythm_syncopated",
							"rhythm_swing", "rhythm_triplet", "rhythm_rest"]
		if rhythm < rhythm_keys.size():
			unlock_entry(rhythm_keys[rhythm])

	# 解锁音色条目
	var timbre = spell_data.get("timbre", 0)
	if timbre > 0:
		var timbre_keys := { 1: "timbre_plucked", 2: "timbre_bowed", 3: "timbre_wind", 4: "timbre_percussive" }
		if timbre_keys.has(timbre):
			unlock_entry(timbre_keys[timbre])

## 和弦施放时
func _on_chord_cast(chord_data: Dictionary) -> void:
	var chord_type = chord_data.get("chord_type", -1)
	if chord_type < 0:
		return

	# 和弦类型到图鉴条目的映射
	var chord_keys := {
		0: "chord_major", 1: "chord_minor", 2: "chord_augmented",
		3: "chord_diminished", 4: "chord_dominant_7", 5: "chord_diminished_7",
		6: "chord_major_7", 7: "chord_minor_7", 8: "chord_suspended",
		9: "chord_dominant_9", 10: "chord_major_9", 11: "chord_diminished_9",
		12: "chord_dominant_11", 13: "chord_dominant_13", 14: "chord_diminished_13",
	}

	if chord_keys.has(chord_type):
		unlock_entry(chord_keys[chord_type])

	# 检查和弦进行
	var progression = chord_data.get("progression_type", "")
	if not progression.is_empty():
		var prog_keys := {
			"D_to_T": "prog_d_to_t",
			"T_to_D": "prog_t_to_d",
			"PD_to_D": "prog_pd_to_d",
		}
		if prog_keys.has(progression):
			unlock_entry(prog_keys[progression])

## 供外部直接调用的敌人死亡处理
## 由 enemy_base.gd 的 enemy_died 信号连接
func on_enemy_died(_position: Vector2, _xp_value: int, enemy_type: String) -> void:
	record_kill(enemy_type)

# ============================================================
# 持久化
# ============================================================

func _save_entry(entry_id: String) -> void:
	if not SaveManager:
		return
	SaveManager._save_data.set_value(CODEX_SAVE_SECTION, entry_id, true)
	SaveManager._save_data.save(SaveManager.SAVE_PATH)

func _save_kill_count(enemy_key: String) -> void:
	if not SaveManager:
		return
	SaveManager._save_data.set_value(KILLS_SAVE_SECTION, enemy_key, _kill_counts[enemy_key])
	SaveManager._save_data.save(SaveManager.SAVE_PATH)

func _save_milestones(entry_id: String) -> void:
	if not SaveManager:
		return
	var reached: Array = _reached_milestones.get(entry_id, [])
	var milestones_str := ",".join(reached.map(func(m): return str(m)))
	SaveManager._save_data.set_value("codex_milestones", entry_id, milestones_str)
	SaveManager._save_data.save(SaveManager.SAVE_PATH)

func _save_all() -> void:
	if not SaveManager:
		return
	# 清除旧数据
	if SaveManager._save_data.has_section(CODEX_SAVE_SECTION):
		SaveManager._save_data.erase_section(CODEX_SAVE_SECTION)
	if SaveManager._save_data.has_section(KILLS_SAVE_SECTION):
		SaveManager._save_data.erase_section(KILLS_SAVE_SECTION)
	if SaveManager._save_data.has_section("codex_milestones"):
		SaveManager._save_data.erase_section("codex_milestones")

	# 写入当前数据
	for key in _unlocked_entries:
		SaveManager._save_data.set_value(CODEX_SAVE_SECTION, key, _unlocked_entries[key])
	for key in _kill_counts:
		SaveManager._save_data.set_value(KILLS_SAVE_SECTION, key, _kill_counts[key])
	for key in _reached_milestones:
		var reached: Array = _reached_milestones[key]
		var milestones_str := ",".join(reached.map(func(m): return str(m)))
		SaveManager._save_data.set_value("codex_milestones", key, milestones_str)

	SaveManager._save_data.save(SaveManager.SAVE_PATH)

# ============================================================
# 工具方法
# ============================================================

## 获取条目所属的卷
func _get_entry_volume(entry_id: String) -> CodexData.Volume:
	for volume in CodexData.Volume.values():
		var entries = CodexData.get_volume_entries(volume)
		if entry_id in entries:
			return volume
	return CodexData.Volume.MUSIC_THEORY  # 默认

## 获取指定卷中所有已解锁条目的数据列表
func get_unlocked_entries_for_volume(volume: CodexData.Volume) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var entries = CodexData.get_volume_entries(volume)
	for entry_id in entries:
		var data = CodexData.find_entry(entry_id)
		if data.is_empty():
			continue
		var entry_info = data.duplicate()
		entry_info["id"] = entry_id
		entry_info["is_unlocked"] = is_unlocked(entry_id)
		result.append(entry_info)
	return result
