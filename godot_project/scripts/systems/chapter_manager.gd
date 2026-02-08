## chapter_manager.gd
## 章节过渡管理器 (Autoload)
## 管理生存者游戏的章节流程：
##   1. 章节内波次推进（普通波 → 精英波 → Boss波）
##   2. 章节间过渡（奖励结算 → 主题切换 → BPM变化）
##   3. 难度递进（跨章节的全局难度缩放）
##   4. 与 EnemySpawner / BossSpawner 协调
##
## 生存者游戏流程：
##   [章节开始] → 多波次(含精英) → [Boss战] → [章节结算] → [过渡动画] → [下一章]
extends Node

# ============================================================
# 信号
# ============================================================
signal chapter_started(chapter: int, chapter_name: String)
signal chapter_completed(chapter: int, rewards: Dictionary)
signal chapter_transition_started(from_chapter: int, to_chapter: int)
signal chapter_transition_completed(new_chapter: int)
signal wave_started_in_chapter(chapter: int, wave: int, wave_type: String)
signal elite_wave_triggered(chapter: int, elite_type: String)
signal boss_wave_triggered(chapter: int, boss_key: String)
signal chapter_timer_updated(elapsed: float, total: float)
signal bpm_changed(new_bpm: float)

# ============================================================
# 章节状态枚举
# ============================================================
enum ChapterState {
	INACTIVE,          ## 未开始
	WAVE_PHASE,        ## 普通波次阶段
	ELITE_PHASE,       ## 精英出现阶段
	PRE_BOSS,          ## Boss前冲刺
	BOSS_FIGHT,        ## Boss战
	CHAPTER_COMPLETE,  ## 章节完成（结算中）
	TRANSITIONING,     ## 章节过渡中
}

# ============================================================
# 配置
# ============================================================
## 章节过渡动画时间（秒）
@export var transition_duration: float = 5.0
## Boss战前的警告时间（秒）
@export var boss_warning_duration: float = 3.0
## 章节完成后的结算展示时间（秒）
@export var completion_display_duration: float = 4.0
## BPM 过渡速度（每秒变化量）
@export var bpm_transition_speed: float = 5.0

# ============================================================
# 状态
# ============================================================
var _current_chapter: int = 0  # ChapterData.Chapter 枚举值
var _chapter_state: ChapterState = ChapterState.INACTIVE
var _chapter_wave: int = 0     # 当前章节内的波次号
var _chapter_timer: float = 0.0  # 章节已经过时间
var _chapter_config: Dictionary = {}
var _transition_timer: float = 0.0
var _target_bpm: float = 120.0
var _bpm_transitioning: bool = false

## Boss 战状态
var _boss_triggered: bool = false
var _boss_defeated: bool = false

## 精英已生成记录
var _elites_spawned_this_chapter: int = 0

## 全局难度层（跨章节累积）
var _global_difficulty_layer: int = 0

## 章节完成记录
var _completed_chapters: Array[int] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	match _chapter_state:
		ChapterState.WAVE_PHASE, ChapterState.ELITE_PHASE, ChapterState.PRE_BOSS:
			_process_chapter(delta)
		ChapterState.BOSS_FIGHT:
			_process_boss_fight(delta)
		ChapterState.CHAPTER_COMPLETE:
			_process_completion(delta)
		ChapterState.TRANSITIONING:
			_process_transition(delta)
	
	# BPM 平滑过渡
	if _bpm_transitioning:
		_process_bpm_transition(delta)

# ============================================================
# 公共接口
# ============================================================

## 开始游戏（从第一章开始）
func start_game() -> void:
	_current_chapter = 0
	_global_difficulty_layer = 0
	_completed_chapters.clear()
	_start_chapter(_current_chapter)

## 获取当前章节
func get_current_chapter() -> int:
	return _current_chapter

## 获取当前章节状态
func get_chapter_state() -> ChapterState:
	return _chapter_state

## 获取当前章节内波次号
func get_chapter_wave() -> int:
	return _chapter_wave

## 获取章节配置
func get_current_chapter_config() -> Dictionary:
	return _chapter_config

## 获取全局难度层
func get_global_difficulty() -> int:
	return _global_difficulty_layer

## 是否正在Boss战
func is_boss_fight() -> bool:
	return _chapter_state == ChapterState.BOSS_FIGHT

## 是否正在过渡
func is_transitioning() -> bool:
	return _chapter_state == ChapterState.TRANSITIONING

## Boss被击败时调用（由BossSpawner通知）
func on_boss_defeated() -> void:
	if _chapter_state == ChapterState.BOSS_FIGHT:
		_boss_defeated = true
		_complete_chapter()

## 通知波次完成（由EnemySpawner通知）
func on_wave_completed(wave_number: int) -> void:
	# 这里的 wave_number 是全局波次，需要转换为章节内波次
	pass

# ============================================================
# 章节流程
# ============================================================

func _start_chapter(chapter_index: int) -> void:
	_current_chapter = chapter_index
	_chapter_config = ChapterData.get_chapter_config(chapter_index)
	
	if _chapter_config.is_empty():
		push_warning("ChapterManager: No config for chapter %d" % chapter_index)
		return
	
	_chapter_state = ChapterState.WAVE_PHASE
	_chapter_wave = 0
	_chapter_timer = 0.0
	_boss_triggered = false
	_boss_defeated = false
	_elites_spawned_this_chapter = 0
	
	# 设置章节BPM
	var target_bpm: float = _chapter_config.get("bpm", 120)
	_start_bpm_transition(target_bpm)
	
	# 设置拍号
	var beats: int = _chapter_config.get("beats_per_measure", 4)
	GameManager.beats_per_measure = beats
	
	var chapter_name: String = _chapter_config.get("name", "未知章节")
	chapter_started.emit(_current_chapter, chapter_name)
	
	# 通知 EnemySpawner 切换到章节模式
	_notify_spawner_chapter_start()

func _process_chapter(delta: float) -> void:
	_chapter_timer += delta
	
	var duration: float = _chapter_config.get("duration", 180.0)
	chapter_timer_updated.emit(_chapter_timer, duration)
	
	# 检查是否应该触发Boss
	if _should_trigger_boss():
		_trigger_boss()
		return
	
	# 检查是否应该切换到精英阶段
	_update_chapter_phase()

func _update_chapter_phase() -> void:
	var templates: Array = _chapter_config.get("wave_templates", [])
	
	for template in templates:
		var range_start: int = template["waves"][0]
		var range_end: int = template["waves"][1]
		
		if _chapter_wave >= range_start and _chapter_wave <= range_end:
			var wave_type: String = template.get("type", "normal")
			
			match wave_type:
				"elite":
					if _chapter_state != ChapterState.ELITE_PHASE:
						_chapter_state = ChapterState.ELITE_PHASE
						var elite_type: String = template.get("elite_type", "")
						if elite_type != "":
							elite_wave_triggered.emit(_current_chapter, elite_type)
				"pre_boss":
					if _chapter_state != ChapterState.PRE_BOSS:
						_chapter_state = ChapterState.PRE_BOSS
				_:
					if _chapter_state == ChapterState.ELITE_PHASE:
						_chapter_state = ChapterState.WAVE_PHASE
			break

func _should_trigger_boss() -> bool:
	if _boss_triggered:
		return false
	
	var duration: float = _chapter_config.get("duration", 180.0)
	var min_waves: int = _chapter_config.get("min_waves_before_boss", 8)
	
	# 条件1：章节时间达到
	var time_ready := _chapter_timer >= duration
	
	# 条件2：最小波次数达到
	var waves_ready := _chapter_wave >= min_waves
	
	return time_ready and waves_ready

func _trigger_boss() -> void:
	_boss_triggered = true
	_chapter_state = ChapterState.BOSS_FIGHT
	
	var boss_config: Dictionary = _chapter_config.get("boss", {})
	var boss_key: String = boss_config.get("key", "")
	
	boss_wave_triggered.emit(_current_chapter, boss_key)
	
	# 通知 EnemySpawner 暂停普通生成
	_notify_spawner_boss_phase()

func _process_boss_fight(_delta: float) -> void:
	# Boss 战由 BossSpawner 管理，这里只等待结果
	pass

# ============================================================
# 章节完成与过渡
# ============================================================

func _complete_chapter() -> void:
	_chapter_state = ChapterState.CHAPTER_COMPLETE
	_completed_chapters.append(_current_chapter)
	_global_difficulty_layer += 1
	
	var rewards: Dictionary = _chapter_config.get("completion_rewards", {})
	chapter_completed.emit(_current_chapter, rewards)
	
	# 发放奖励
	_grant_chapter_rewards(rewards)
	
	# 延迟后开始过渡
	get_tree().create_timer(completion_display_duration).timeout.connect(func():
		_start_transition()
	)

func _grant_chapter_rewards(rewards: Dictionary) -> void:
	# 共鸣碎片
	var fragments: int = rewards.get("resonance_fragments", 0)
	if fragments > 0:
		var meta_mgr := get_node_or_null("/root/MetaProgressionManager")
		if meta_mgr and meta_mgr.has_method("add_resonance_fragments"):
			meta_mgr.add_resonance_fragments(fragments)
		elif SaveManager and SaveManager.has_method("add_resonance_fragments"):
			SaveManager.add_resonance_fragments(fragments)
	
	# 经验值奖励
	var xp_bonus: int = rewards.get("xp_bonus", 0)
	if xp_bonus > 0:
		GameManager.add_xp(xp_bonus)

func _start_transition() -> void:
	var next_chapter := _current_chapter + 1
	
	# 检查是否还有下一章
	if next_chapter >= ChapterData.get_chapter_count():
		# 游戏通关！（或进入无尽模式）
		_enter_endless_mode()
		return
	
	_chapter_state = ChapterState.TRANSITIONING
	_transition_timer = transition_duration
	
	chapter_transition_started.emit(_current_chapter, next_chapter)

func _process_transition(delta: float) -> void:
	_transition_timer -= delta
	
	if _transition_timer <= 0.0:
		var next_chapter := _current_chapter + 1
		_chapter_state = ChapterState.INACTIVE
		chapter_transition_completed.emit(next_chapter)
		
		# 开始下一章
		_start_chapter(next_chapter)

func _process_completion(_delta: float) -> void:
	# 等待结算展示完成
	pass

# ============================================================
# BPM 过渡
# ============================================================

func _start_bpm_transition(target: float) -> void:
	_target_bpm = target
	if abs(GameManager.current_bpm - target) > 1.0:
		_bpm_transitioning = true
	else:
		GameManager.current_bpm = target
		GameManager._update_beat_interval()
		bpm_changed.emit(target)

func _process_bpm_transition(delta: float) -> void:
	var diff := _target_bpm - GameManager.current_bpm
	if abs(diff) < 0.5:
		GameManager.current_bpm = _target_bpm
		GameManager._update_beat_interval()
		_bpm_transitioning = false
		bpm_changed.emit(_target_bpm)
		return
	
	var step := sign(diff) * bpm_transition_speed * delta
	GameManager.current_bpm += step
	GameManager._update_beat_interval()

# ============================================================
# 无尽模式
# ============================================================

func _enter_endless_mode() -> void:
	# 所有章节完成后进入无尽模式
	# 随机循环已完成的章节，持续增加难度
	_global_difficulty_layer += 2
	var random_chapter := _completed_chapters[randi() % _completed_chapters.size()]
	_start_chapter(random_chapter)

# ============================================================
# 与 Spawner 通信
# ============================================================

func _notify_spawner_chapter_start() -> void:
	var spawner := get_tree().get_first_node_in_group("enemy_spawner")
	if spawner and spawner.has_method("set_chapter_mode"):
		spawner.set_chapter_mode(_current_chapter, _chapter_config)

func _notify_spawner_boss_phase() -> void:
	var spawner := get_tree().get_first_node_in_group("enemy_spawner")
	if spawner and spawner.has_method("enter_boss_phase"):
		spawner.enter_boss_phase()

## 由 EnemySpawner 调用，通知章节内波次推进
func advance_chapter_wave() -> void:
	_chapter_wave += 1
	
	# 获取当前波次模板
	var template := ChapterData.get_wave_template(_current_chapter, _chapter_wave)
	var wave_type: String = template.get("type", "normal")
	
	wave_started_in_chapter.emit(_current_chapter, _chapter_wave, wave_type)

# ============================================================
# 难度缩放接口
# ============================================================

## 获取当前章节+全局的综合难度倍率
func get_difficulty_multiplier() -> Dictionary:
	var chapter_mult := 1.0 + _current_chapter * 0.15
	var global_mult := 1.0 + _global_difficulty_layer * 0.1
	var time_mult := 1.0 + _chapter_timer / 300.0  # 每5分钟+100%
	
	return {
		"hp": chapter_mult * global_mult * (1.0 + time_mult * 0.3),
		"speed": chapter_mult * (1.0 + time_mult * 0.1),
		"damage": chapter_mult * global_mult * (1.0 + time_mult * 0.2),
		"spawn_rate": 1.0 + time_mult * 0.15,
	}

## 获取当前波次应该使用的波次模板
func get_current_wave_template() -> Dictionary:
	return ChapterData.get_wave_template(_current_chapter, _chapter_wave)

## 获取当前章节应该生成的敌人类型
func select_enemy_for_current_chapter() -> String:
	return ChapterData.weighted_select_enemy(_current_chapter, _chapter_wave)

## 获取当前章节应该生成的精英类型
func select_elite_for_current_chapter() -> String:
	return ChapterData.select_elite(_current_chapter, _chapter_wave)
