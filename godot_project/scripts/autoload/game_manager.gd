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
signal player_died()
signal enemy_killed(enemy_position: Vector2)
signal xp_gained(amount: int)
signal level_up(new_level: int)
signal upgrade_selected(upgrade: Dictionary)

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
	_update_beat_interval()

	# 重置所有子系统
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

	# 局结算：保存进度并计算共鸣碎片奖励
	SaveManager.save_game()
	_award_resonance_fragments()

	game_state_changed.emit(current_state)

func enter_upgrade_select() -> void:
	current_state = GameState.UPGRADE_SELECT
	get_tree().paused = true
	game_state_changed.emit(current_state)

# ============================================================
# 玩家生命值
# ============================================================

func damage_player(amount: float) -> void:
	# 闪避检测
	if randf() < player_dodge_chance:
		return  # 闪避成功

	player_current_hp = max(0.0, player_current_hp - amount)
	player_hp_changed.emit(player_current_hp, player_max_hp)

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
	player_xp += amount
	xp_gained.emit(amount)

	while player_xp >= xp_to_next_level:
		player_xp -= xp_to_next_level
		player_level += 1
		xp_to_next_level = int(xp_to_next_level * XP_SCALE_FACTOR)
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

	upgrade_selected.emit(upgrade)

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
# 局结算：共鸣碎片奖励
# ============================================================

func _award_resonance_fragments() -> void:
	# 基础奖励：存活时间
	var time_bonus: int = int(game_time / 30.0) * 5  # 每30秒5碎片

	# 击杀奖励
	var kill_bonus: int = session_kills * 1  # 每次击杀1碎片

	# 等级奖励
	var level_bonus: int = (player_level - 1) * 3  # 每级3碎片

	var total: int = time_bonus + kill_bonus + level_bonus
	if total > 0:
		SaveManager.add_resonance_fragments(total)
