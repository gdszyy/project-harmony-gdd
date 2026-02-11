## game_manager.gd
## 全局游戏状态管理器 (Autoload)
## 管理游戏流程、玩家状态、BPM节拍、升级系统等
extends Node

# ============================================================
# 信号
# ============================================================
signal beat_tick(beat_index: int)           ## 每个节拍触发
signal half_beat_tick(half_beat_index: int) ## 每个八分音符触发
signal measure_complete(measure_index: int) ## 每小节完成
signal game_state_changed(new_state: GameState)
signal player_hp_changed(current_hp: float, max_hp: float)
signal player_damaged(damage: float, source_position: Vector2)
signal player_died()
signal enemy_killed(enemy_position: Vector2)
signal xp_gained(amount: int)
signal level_up(new_level: int)
signal upgrade_selected(upgrade: Dictionary)
signal chapter_timbre_changed(new_timbre: int)     ## 章节音色武器变更
signal inscription_acquired(inscription: Dictionary) ## 获得章节词条
signal easter_egg_triggered(egg: Dictionary)         ## 音乐史彩蛋触发

# ============================================================
# 枚举
# ============================================================
enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	UPGRADE_SELECT,
	GAME_OVER,
}

# ============================================================
# 游戏配置
# ============================================================
## 基础BPM (每分钟节拍数)
@export var base_bpm: float = 120.0
## 当前BPM (可被升级修改)
var current_bpm: float = 120.0
## 拍号 (4/4拍)
var beats_per_measure: int = 4
## 当前游戏状态
var current_state: GameState = GameState.MENU

# ============================================================
# 常量
# ============================================================
## 不和谐度伤害转换系数：每点不和谐度造成的伤害
const DISSONANCE_DAMAGE_PER_POINT: float = 2.0
## 升级经验倍率
const XP_SCALE_FACTOR: float = 1.2

# ============================================================
# 玩家状态
# ============================================================
var player_max_hp: float = 100.0
var player_current_hp: float = 100.0
var player_level: int = 1
var player_xp: int = 0
var xp_to_next_level: int = 50
var player_dodge_chance: float = 0.0
var session_kills: int = 0
## 伤害倍率（可被调试面板修改）
var damage_multiplier: float = 1.0
## 是否处于测试模式
var is_test_mode: bool = false
## 护盾值（由 ProjectileManager 的护盾法阵提供）
var shield_hp: float = 0.0
var max_shield_hp: float = 0.0

# ============================================================
# 章节音色武器系统 (v2.0 — Issue #38)
# ============================================================
## 当前激活的音色武器
var active_chapter_timbre: int = MusicData.ChapterTimbre.NONE
## 是否使用电子乐变体
var is_electronic_variant: bool = false
## 已解锁的音色武器列表
var available_timbres: Array[int] = []
## 已获得的章节词条
var active_inscriptions: Array[Dictionary] = []
## 当前章节词条池
var current_chapter_inscription_pool: Array[Dictionary] = []
## 已触发的音乐史彩蛋
var triggered_easter_eggs: Array[Dictionary] = []

# ============================================================
# 节拍系统
# ============================================================
var _beat_timer: float = 0.0
var _half_beat_timer: float = 0.0
var _current_beat: int = 0
var _current_half_beat: int = 0
var _current_measure: int = 0
var _beat_interval: float = 0.5  # 60/120 = 0.5秒
var _half_beat_interval: float = 0.25

# ============================================================
# 游戏时间
# ============================================================
var game_time: float = 0.0

# ============================================================
# 升级系统
# ============================================================
## 已获得的升级列表
var acquired_upgrades: Array[Dictionary] = []
## 扩展和弦是否已解锁
var extended_chords_unlocked: bool = false
## 音符属性加成 { WhiteKey: { "dmg": 0.0, "spd": 0.0, "dur": 0.0, "size": 0.0 } }
var note_bonuses: Dictionary = {}

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_update_beat_interval()
	_init_note_bonuses()
	process_mode = Node.PROCESS_MODE_ALWAYS
	enemy_killed.connect(func(_pos): session_kills += 1)

func _process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return

	game_time += delta
	_process_beat(delta)

# ============================================================
# 节拍处理
# ============================================================

func _process_beat(delta: float) -> void:
	_beat_timer += delta
	_half_beat_timer += delta

	# 八分音符 tick
	if _half_beat_timer >= _half_beat_interval:
		_half_beat_timer -= _half_beat_interval
		_current_half_beat += 1
		half_beat_tick.emit(_current_half_beat)

	# 四分音符 tick (节拍)
	if _beat_timer >= _beat_interval:
		_beat_timer -= _beat_interval
		_current_beat += 1
		beat_tick.emit(_current_beat)

		# 小节完成检测
		if _current_beat % beats_per_measure == 0:
			_current_measure += 1
			measure_complete.emit(_current_measure)

func _update_beat_interval() -> void:
	_beat_interval = 60.0 / current_bpm
	_half_beat_interval = _beat_interval / 2.0

# ============================================================
# 游戏状态管理
# ============================================================

## 内部公共重置逻辑（DRY 原则）
func _reset_common_state() -> void:
	game_time = 0.0
	player_level = 1
	player_xp = 0
	xp_to_next_level = 50
	acquired_upgrades.clear()
	extended_chords_unlocked = false
	_init_note_bonuses()
	_current_beat = 0
	_current_half_beat = 0
	_current_measure = 0
	_beat_timer = 0.0
	_half_beat_timer = 0.0

func reset_game() -> void:
	_reset_common_state()
	current_state = GameState.MENU
	player_max_hp = 100.0
	player_current_hp = 100.0
	current_bpm = base_bpm
	session_kills = 0
	player_dodge_chance = 0.0
	damage_multiplier = 1.0
	is_test_mode = false
	shield_hp = 0.0
	max_shield_hp = 0.0
	_update_beat_interval()

	# 重置音色武器系统
	active_chapter_timbre = MusicData.ChapterTimbre.NONE
	is_electronic_variant = false
	available_timbres.clear()
	active_inscriptions.clear()
	current_chapter_inscription_pool.clear()
	triggered_easter_eggs.clear()

	# 重置所有子系统
	if NoteInventory.has_method("reset"):
		NoteInventory.reset()
	if FatigueManager.has_method("reset"):
		FatigueManager.reset()
	if SpellcraftSystem.has_method("reset"):
		SpellcraftSystem.reset()
	if MusicTheoryEngine.has_method("clear_history"):
		MusicTheoryEngine.clear_history()
	if ModeSystem.has_method("reset"):
		ModeSystem.reset()

	game_state_changed.emit(current_state)

func start_game() -> void:
	_reset_common_state()
	current_state = GameState.PLAYING
	session_kills = 0

	# 应用局外成长加成（必须在设置 HP 之前）
	SaveManager.apply_meta_bonuses()
	player_current_hp = player_max_hp

	# 应用调式系统
	if ModeSystem.has_method("apply_mode"):
		ModeSystem.apply_mode(SaveManager.get_selected_mode())

	# 启动 BGM
	if BGMManager.has_method("start_bgm"):
		BGMManager.start_bgm(current_bpm)

	# 重置疲劳系统
	if FatigueManager.has_method("reset"):
		FatigueManager.reset()

	game_state_changed.emit(current_state)

func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		game_state_changed.emit(current_state)

func resume_game() -> void:
	if current_state == GameState.PAUSED or current_state == GameState.UPGRADE_SELECT:
		current_state = GameState.PLAYING
		get_tree().paused = false
		game_state_changed.emit(current_state)

func game_over() -> void:
	current_state = GameState.GAME_OVER

	# 局结算：保存局内进度
	SaveManager.save_game()
	# ★ 碎片奖励统一由 RunResultsScreen.show_results() 触发
	#   通过 MetaProgressionManager.on_run_completed() 计算并发放
	#   避免双重发放碎片

	game_state_changed.emit(current_state)

func enter_upgrade_select() -> void:
	current_state = GameState.UPGRADE_SELECT
	get_tree().paused = true
	game_state_changed.emit(current_state)

# ============================================================
# 玩家生命值
# ============================================================

func damage_player(amount: float, source_position: Vector2 = Vector2.ZERO) -> void:
	# 闪避检测
	if randf() < player_dodge_chance:
		return  # 闪避成功

	# 护盾吸收伤害
	var remaining_damage := amount
	if shield_hp > 0.0:
		var absorbed: float = min(shield_hp, remaining_damage)
		shield_hp -= absorbed
		remaining_damage -= absorbed
		if remaining_damage <= 0.0:
			player_damaged.emit(amount, source_position)
			return

	player_current_hp = max(0.0, player_current_hp - remaining_damage)
	player_hp_changed.emit(player_current_hp, player_max_hp)
	player_damaged.emit(amount, source_position)

	if player_current_hp <= 0.0:
		player_died.emit()
		game_over()

func heal_player(amount: float) -> void:
	player_current_hp = min(player_max_hp, player_current_hp + amount)
	player_hp_changed.emit(player_current_hp, player_max_hp)

## 不和谐值导致的生命腐蚀
func apply_dissonance_damage(dissonance: float) -> void:
	var damage := dissonance * DISSONANCE_DAMAGE_PER_POINT
	# 应用局外成长的不和谐伤害减免
	var resist := SaveManager.get_dissonance_resist_multiplier()
	damage *= resist
	damage_player(damage)

# ============================================================
# 经验值与升级
# ============================================================

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	player_xp += amount
	xp_gained.emit(amount)

	while player_xp >= xp_to_next_level:
		player_xp -= xp_to_next_level
		player_level += 1
		xp_to_next_level = int(xp_to_next_level * XP_SCALE_FACTOR)
		print("[GameManager] Level Up! Now Lv.%d | Next: %d XP" % [player_level, xp_to_next_level])
		level_up.emit(player_level)
		enter_upgrade_select()

# ============================================================
# 升级系统
# ============================================================

func apply_upgrade(upgrade: Dictionary) -> void:
	acquired_upgrades.append(upgrade)

	match upgrade.get("category", ""):
		"note_stat":
			_apply_note_stat_upgrade(upgrade)
		"fatigue_resist":
			_apply_fatigue_resist_upgrade(upgrade)
		"rhythm_mastery":
			_apply_rhythm_mastery_upgrade(upgrade)
		"chord_mastery":
			_apply_chord_mastery_upgrade(upgrade)
		"survival":
			_apply_survival_upgrade(upgrade)
		"timbre_mastery":
			_apply_timbre_mastery_upgrade(upgrade)
		"modifier_mastery":
			_apply_modifier_mastery_upgrade(upgrade)
		"special":
			_apply_special_upgrade(upgrade)
		"note_acquire":
			_apply_note_acquire_upgrade(upgrade)
		"inscription":
			_apply_inscription_upgrade(upgrade)

	# ★ 每次升级额外获得一个随机音符（基础奖励）
	NoteInventory.add_random_note(1, "level_up_bonus")

	upgrade_selected.emit(upgrade)

## 音符获取类升级（由五度圈罗盘系统触发）
func _apply_note_acquire_upgrade(upgrade: Dictionary) -> void:
	# 音符获取已由 circle_of_fifths_upgrade.gd 的 _process_note_acquisition 处理
	# 此处仅作为占位，避免 match 警告
	pass

func _apply_note_stat_upgrade(upgrade: Dictionary) -> void:
	var note_key = upgrade.get("target_note", -1)
	var stat = upgrade.get("stat", "")
	var value = upgrade.get("value", 0.0)
	if note_key >= 0 and note_bonuses.has(note_key):
		note_bonuses[note_key][stat] = note_bonuses[note_key].get(stat, 0.0) + value

func _apply_fatigue_resist_upgrade(upgrade: Dictionary) -> void:
	# 由 FatigueManager 处理
	FatigueManager.apply_resistance_upgrade(upgrade)

func _apply_rhythm_mastery_upgrade(upgrade: Dictionary) -> void:
	match upgrade.get("type", ""):
		"bpm_boost":
			current_bpm += upgrade.get("value", 5.0)
			_update_beat_interval()

func _apply_chord_mastery_upgrade(upgrade: Dictionary) -> void:
	match upgrade.get("type", ""):
		"chord_power":
			pass  # SpellcraftSystem 会读取 acquired_upgrades
		"extended_unlock":
			extended_chords_unlocked = true

func _apply_survival_upgrade(upgrade: Dictionary) -> void:
	match upgrade.get("type", ""):
		"max_hp":
			player_max_hp += upgrade.get("value", 25.0)
			player_current_hp += upgrade.get("value", 25.0)
			player_hp_changed.emit(player_current_hp, player_max_hp)
		"dodge":
			player_dodge_chance += upgrade.get("value", 0.03)

## 音色精通升级
func _apply_timbre_mastery_upgrade(upgrade: Dictionary) -> void:
	# 音色精通升级由 SpellcraftSystem 读取 acquired_upgrades 处理
	pass

## 章节词条升级
func _apply_inscription_upgrade(upgrade: Dictionary) -> void:
	var inscription: Dictionary = upgrade.get("inscription", {})
	if inscription.is_empty():
		return
	acquire_inscription(inscription)

## 修饰符精通升级
func _apply_modifier_mastery_upgrade(upgrade: Dictionary) -> void:
	# 修饰符精通升级由 SpellcraftSystem 读取 acquired_upgrades 处理
	pass

## 特殊升级
func _apply_special_upgrade(upgrade: Dictionary) -> void:
	match upgrade.get("type", ""):
		"perfect_beat_bonus":
			pass  # SpellcraftSystem 会读取 acquired_upgrades
		"chord_progression_boost":
			pass  # SpellcraftSystem 会读取 acquired_upgrades
		"multi_modifier":
			pass  # SpellcraftSystem 会读取 acquired_upgrades

func _init_note_bonuses() -> void:
	note_bonuses.clear()
	for key in MusicData.WhiteKey.values():
		note_bonuses[key] = { "dmg": 0.0, "spd": 0.0, "dur": 0.0, "size": 0.0 }

# ============================================================
# 工具函数
# ============================================================

## 获取音符的实际属性（基础 + 加成）
func get_note_effective_stats(white_key: MusicData.WhiteKey) -> Dictionary:
	var base = MusicData.WHITE_KEY_STATS[white_key].duplicate()
	var bonus = note_bonuses.get(white_key, {})

	return {
		"dmg": base["dmg"] + bonus.get("dmg", 0.0),
		"spd": base["spd"] + bonus.get("spd", 0.0),
		"dur": base["dur"] + bonus.get("dur", 0.0),
		"size": base["size"] + bonus.get("size", 0.0),
	}

## 获取当前节拍进度 (0.0 ~ 1.0)
func get_beat_progress() -> float:
	return _beat_timer / _beat_interval

## 获取当前小节内的拍号 (0 ~ beats_per_measure-1)
func get_beat_in_measure() -> int:
	return _current_beat % beats_per_measure

## 获取当前BPM
func get_bpm() -> float:
	return current_bpm

# ============================================================
# 章节音色武器管理 (v2.0 — Issue #38)
# ============================================================

## 进入新章节时激活对应音色武器
func activate_chapter_timbre(chapter: int) -> void:
	var config: Dictionary = ChapterData.get_chapter_timbre(chapter)
	if config.is_empty():
		return
	var timbre: int = config["timbre"]
	active_chapter_timbre = timbre
	if timbre not in available_timbres:
		available_timbres.append(timbre)
	# 加载章节词条池
	current_chapter_inscription_pool = ChapterData.get_chapter_inscriptions(chapter)
	chapter_timbre_changed.emit(active_chapter_timbre)

## 切换音色武器
func switch_timbre(timbre: int) -> void:
	if timbre == active_chapter_timbre:
		return
	if timbre not in available_timbres:
		return
	# 判断是否跨章节使用，产生额外疲劳
	var current_chapter_config: Dictionary = ChapterData.get_chapter_timbre(
		ChapterManager.get_current_chapter() if ChapterManager else 0
	)
	var chapter_timbre: int = current_chapter_config.get("timbre", -1)
	if chapter_timbre != timbre:
		# 跨章节使用，产生额外疲劳
		var fatigue_cost: float = MusicData.CROSS_CHAPTER_TIMBRE_FATIGUE
		if is_electronic_variant:
			fatigue_cost *= MusicData.ELECTRONIC_VARIANT_FATIGUE_MULT
		if FatigueManager.has_method("apply_manual_fatigue"):
			FatigueManager.apply_manual_fatigue(fatigue_cost)
	active_chapter_timbre = timbre
	chapter_timbre_changed.emit(active_chapter_timbre)

## 获取词条
func acquire_inscription(inscription: Dictionary) -> void:
	# 检查是否已拥有
	for existing in active_inscriptions:
		if existing["id"] == inscription["id"]:
			return
	active_inscriptions.append(inscription)
	inscription_acquired.emit(inscription)
	_check_music_history_easter_eggs()

## 获取尚未拥有的当前章节词条
func get_unacquired_inscriptions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var owned_ids: Array[String] = []
	for ins in active_inscriptions:
		owned_ids.append(ins["id"])
	for ins in current_chapter_inscription_pool:
		if ins["id"] not in owned_ids:
			result.append(ins)
	return result

## 检查音乐史彩蛋
func _check_music_history_easter_eggs() -> void:
	var owned_ids: Array[String] = []
	for ins in active_inscriptions:
		owned_ids.append(ins["id"])
	var eggs: Array[Dictionary] = ChapterData.check_easter_eggs(owned_ids)
	for egg in eggs:
		var already_triggered := false
		for existing in triggered_easter_eggs:
			if existing["id"] == egg["id"]:
				already_triggered = true
				break
		if not already_triggered:
			triggered_easter_eggs.append(egg)
			easter_egg_triggered.emit(egg)

## 检查当前音色武器是否为章节专属（无额外疲劳）
func is_current_chapter_timbre() -> bool:
	var config: Dictionary = ChapterData.get_chapter_timbre(
		ChapterManager.get_current_chapter() if ChapterManager else 0
	)
	return config.get("timbre", -1) == active_chapter_timbre

## 获取词条与当前音色武器的协同加成状态
func get_inscription_synergy_active(inscription: Dictionary) -> bool:
	if not is_current_chapter_timbre():
		return false
	# 检查词条是否属于当前章节
	var chapter_inscriptions: Array = current_chapter_inscription_pool
	for ins in chapter_inscriptions:
		if ins["id"] == inscription["id"]:
			return true
	return false

# ============================================================
# 局结算：共鸣碎片奖励
# ============================================================

func _award_resonance_fragments() -> void:
	# ★ 统一使用 MetaProgressionManager.on_run_completed 计算碎片奖励
	# 避免 GameManager 和 MetaProgressionManager 双重计算
	var meta := get_node_or_null("/root/MetaProgressionManager")
	if meta and meta.has_method("on_run_completed"):
		var run_data := {
			"survival_time": game_time,
			"total_kills": session_kills,
			"bosses_defeated": 0,  # TODO: 接入 Boss 击败计数
			"max_level": player_level,
			"harmony_score": 0.0,  # TODO: 接入和谐度评分
		}
		# 尝试从 FatigueManager 获取和谐度数据
		if FatigueManager.has_method("query_fatigue"):
			var fatigue_data := FatigueManager.query_fatigue()
			# 和谐度 = 1 - 疲劳度（疲劳越低越和谐）
			run_data["harmony_score"] = 1.0 - fatigue_data.get("afi", 0.5)
		meta.on_run_completed(run_data)
	else:
		# 回退方案：直接通过 SaveManager 添加碎片
		var time_bonus: int = int(game_time / 30.0) * 5
		var kill_bonus: int = session_kills * 1
		var level_bonus: int = (player_level - 1) * 3
		var total: int = time_bonus + kill_bonus + level_bonus
		if total > 0:
			SaveManager.add_resonance_fragments(total)
