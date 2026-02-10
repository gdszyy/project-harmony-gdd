## chapter_manager.gd
## 章节过渡管理器 (Autoload)
## 管理生存者游戏的章节流程：
##   1. 章节内波次推进（普通波 → 精英波 → Boss波）
##   2. 章节间过渡（奖励结算 → 主题切换 → BPM变化 → 色彩过渡）
##   3. 难度递进（跨章节的全局难度缩放）
##   4. 与 EnemySpawner / BossSpawner 协调
##   5. 章节特殊机制管理（摇摆力场、波形战争等）
##   6. Boss 实际实例化与生命周期管理
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

## 新增信号：Boss 生命周期
signal boss_spawned(boss_node: Node)
signal boss_health_changed(boss_key: String, current_hp: float, max_hp: float)
signal boss_phase_changed(boss_key: String, phase: int)

## 新增信号：章节过渡视觉
signal transition_progress_updated(progress: float)  ## 0.0 → 1.0
signal color_theme_changed(from_color: Color, to_color: Color, progress: float)
signal special_mechanic_activated(mechanic_name: String, params: Dictionary)
signal special_mechanic_deactivated(mechanic_name: String)
signal scripted_wave_injected(wave_name: String)
signal scripted_wave_finished(wave_name: String)

## 新增信号：游戏通关
signal game_completed()
signal endless_mode_started(loop_count: int)

# ============================================================
# 章节状态枚举
# ============================================================
enum ChapterState {
	INACTIVE,          ## 未开始
	WAVE_PHASE,        ## 普通波次阶段
	ELITE_PHASE,       ## 精英出现阶段
	PRE_BOSS,          ## Boss前冲刺
	BOSS_WARNING,      ## Boss 出场警告（屏幕震动 + 字幕）
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
var _boss_warning_timer: float = 0.0
var _current_boss_node: Node = null
var _current_boss_key: String = ""

## 精英已生成记录
var _elites_spawned_this_chapter: int = 0

## 全局难度层（跨章节累积）
var _global_difficulty_layer: int = 0

## 章节完成记录
var _completed_chapters: Array[int] = []

## 无尽模式循环计数
var _endless_loop_count: int = 0
var _is_endless_mode: bool = false

## 剧本波次调度
var _scripted_wave_schedule: Array = []  # 当前章节的剧本波次调度表
var _scripted_wave_index: int = 0  # 下一个待触发的剧本波次索引
var _pending_scripted_wave: Resource = null  # 待执行的剧本波次

## 章节过渡视觉状态
var _transition_from_color: Color = Color.BLACK
var _transition_to_color: Color = Color.BLACK

## 当前活跃的特殊机制
var _active_special_mechanics: Dictionary = {}

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
		ChapterState.BOSS_WARNING:
			_process_boss_warning(delta)
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
	_endless_loop_count = 0
	_is_endless_mode = false
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

## 是否处于无尽模式
func is_endless_mode() -> bool:
	return _is_endless_mode

## 获取当前 Boss 节点
func get_current_boss() -> Node:
	return _current_boss_node

## Boss被击败时调用（由 Boss 自身或 BossSpawner 通知）
func on_boss_defeated() -> void:
	if _chapter_state == ChapterState.BOSS_FIGHT:
		_boss_defeated = true
		# 清理 Boss 节点
		if is_instance_valid(_current_boss_node):
			_current_boss_node.queue_free()
			_current_boss_node = null
		_complete_chapter()

## 通知波次完成（由EnemySpawner通知）
func on_wave_completed(_wave_number: int) -> void:
	# 自动推进章节内波次
	advance_chapter_wave()

## 获取当前活跃的特殊机制
func get_active_special_mechanics() -> Dictionary:
	return _active_special_mechanics

## 检查特定特殊机制是否激活
func is_mechanic_active(mechanic_name: String) -> bool:
	return _active_special_mechanics.has(mechanic_name) and _active_special_mechanics[mechanic_name]

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
	_boss_warning_timer = 0.0
	_current_boss_node = null
	_current_boss_key = ""
	_elites_spawned_this_chapter = 0
	
	# 初始化剧本波次调度表
	_scripted_wave_schedule = _chapter_config.get("scripted_waves", [])
	_scripted_wave_index = 0
	_pending_scripted_wave = null
	
	# 设置章节BPM
	var target_bpm: float = _chapter_config.get("bpm", 120)
	_start_bpm_transition(target_bpm)
	
	# 设置拍号
	var beats: int = _chapter_config.get("beats_per_measure", 4)
	GameManager.beats_per_measure = beats
	
	# 激活章节特殊机制
	_activate_special_mechanics()
	
	var chapter_name: String = _chapter_config.get("name", "未知章节")
	chapter_started.emit(_current_chapter, chapter_name)
	
	# 通知 EnemySpawner 切换到章节模式
	_notify_spawner_chapter_start()
	
	# 连接 EnemySpawner 的剧本波次完成信号
	var spawner := get_tree().get_first_node_in_group("enemy_spawner")
	if spawner:
		if spawner.has_signal("scripted_wave_completed") and not spawner.scripted_wave_completed.is_connected(_on_scripted_wave_completed):
			spawner.scripted_wave_completed.connect(_on_scripted_wave_completed)
	
	# 检查是否有 chapter_start 触发的剧本波次
	_check_scripted_wave_trigger("chapter_start", 0)

func _process_chapter(delta: float) -> void:
	_chapter_timer += delta
	
	var duration: float = _chapter_config.get("duration", 180.0)
	chapter_timer_updated.emit(_chapter_timer, duration)
	
	# 检查是否应该触发Boss
	if _should_trigger_boss():
		_start_boss_warning()
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
							_elites_spawned_this_chapter += 1
							elite_wave_triggered.emit(_current_chapter, elite_type)
							_spawn_elite(elite_type)
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

# ============================================================
# Boss 警告与生成
# ============================================================

func _start_boss_warning() -> void:
	_boss_triggered = true
	_chapter_state = ChapterState.BOSS_WARNING
	_boss_warning_timer = boss_warning_duration
	
	# 通知 EnemySpawner 暂停普通生成
	_notify_spawner_boss_phase()
	
	var boss_config: Dictionary = _chapter_config.get("boss", {})
	_current_boss_key = boss_config.get("key", "")
	
	boss_wave_triggered.emit(_current_chapter, _current_boss_key)

func _process_boss_warning(delta: float) -> void:
	_boss_warning_timer -= delta
	
	if _boss_warning_timer <= 0.0:
		_trigger_boss()

func _trigger_boss() -> void:
	_chapter_state = ChapterState.BOSS_FIGHT
	
	var boss_config: Dictionary = _chapter_config.get("boss", {})
	var boss_key: String = boss_config.get("key", "")
	var boss_script_path: String = boss_config.get("script_path", "")
	
	# 实际实例化 Boss
	_spawn_boss(boss_key, boss_script_path)

func _spawn_boss(boss_key: String, script_path: String) -> void:
	if script_path.is_empty():
		push_warning("ChapterManager: No script path for boss '%s'" % boss_key)
		return
	
	var boss_script = load(script_path)
	if boss_script == null:
		push_warning("ChapterManager: Failed to load boss script '%s'" % script_path)
		return
	
	# 创建 Boss 节点
	var boss_node: Node2D = Node2D.new()
	boss_node.set_script(boss_script)
	boss_node.name = "Boss_%s" % boss_key
	boss_node.add_to_group("bosses")
	boss_node.add_to_group("enemies")
	
	# 设置 Boss 位置（屏幕上方中央入场）
	var viewport_size := get_viewport().get_visible_rect().size
	boss_node.position = Vector2(viewport_size.x / 2.0, -100.0)
	
	# 应用难度缩放
	var difficulty := get_difficulty_multiplier()
	if boss_node.has_method("apply_difficulty_scaling"):
		boss_node.apply_difficulty_scaling(difficulty)
	
	# 连接 Boss 信号
	if boss_node.has_signal("defeated"):
		boss_node.defeated.connect(_on_boss_defeated_signal)
	if boss_node.has_signal("health_changed"):
		boss_node.health_changed.connect(func(current: float, max_hp: float):
			boss_health_changed.emit(boss_key, current, max_hp)
		)
	if boss_node.has_signal("phase_changed"):
		boss_node.phase_changed.connect(func(phase: int):
			boss_phase_changed.emit(boss_key, phase)
		)
	
	# 添加到场景树
	var game_world := get_tree().get_first_node_in_group("game_world")
	if game_world:
		game_world.add_child(boss_node)
	else:
		get_tree().current_scene.add_child(boss_node)
	
	_current_boss_node = boss_node
	boss_spawned.emit(boss_node)

func _on_boss_defeated_signal() -> void:
	on_boss_defeated()

func _spawn_elite(elite_type: String) -> void:
	var script_path: String = ChapterData.ELITE_SCRIPT_PATHS.get(elite_type, "")
	if script_path.is_empty():
		return
	
	var elite_script = load(script_path)
	if elite_script == null:
		push_warning("ChapterManager: Failed to load elite script '%s'" % script_path)
		return
	
	var elite_node: Node2D = Node2D.new()
	elite_node.set_script(elite_script)
	elite_node.name = "Elite_%s_%d" % [elite_type, _elites_spawned_this_chapter]
	elite_node.add_to_group("elites")
	elite_node.add_to_group("enemies")
	
	# 随机边缘位置
	var viewport_size := get_viewport().get_visible_rect().size
	var side := randi() % 4
	match side:
		0: elite_node.position = Vector2(randf_range(0, viewport_size.x), -50)
		1: elite_node.position = Vector2(randf_range(0, viewport_size.x), viewport_size.y + 50)
		2: elite_node.position = Vector2(-50, randf_range(0, viewport_size.y))
		3: elite_node.position = Vector2(viewport_size.x + 50, randf_range(0, viewport_size.y))
	
	# 应用难度缩放
	var difficulty := get_difficulty_multiplier()
	if elite_node.has_method("apply_difficulty_scaling"):
		elite_node.apply_difficulty_scaling(difficulty)
	
	var game_world := get_tree().get_first_node_in_group("game_world")
	if game_world:
		game_world.add_child(elite_node)
	else:
		get_tree().current_scene.add_child(elite_node)

func _process_boss_fight(_delta: float) -> void:
	# 监控 Boss 状态
	if _current_boss_node and not is_instance_valid(_current_boss_node):
		# Boss 节点已被销毁（可能被外部系统击杀）
		_current_boss_node = null
		if not _boss_defeated:
			on_boss_defeated()

# ============================================================
# 章节完成与过渡
# ============================================================

func _complete_chapter() -> void:
	_chapter_state = ChapterState.CHAPTER_COMPLETE
	_completed_chapters.append(_current_chapter)
	_global_difficulty_layer += 1
	
	# 停用当前章节特殊机制
	_deactivate_special_mechanics()
	
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
	
	# 解锁项
	var unlock: String = rewards.get("unlock", "")
	if unlock != "":
		var save_mgr := get_node_or_null("/root/SaveManager")
		if save_mgr and save_mgr.has_method("unlock_content"):
			save_mgr.unlock_content(unlock)

func _start_transition() -> void:
	var next_chapter := _current_chapter + 1
	
	# 检查是否还有下一章
	if next_chapter >= ChapterData.get_chapter_count():
		if not _is_endless_mode:
			# 首次通关
			game_completed.emit()
		# 进入无尽模式
		_enter_endless_mode()
		return
	
	_chapter_state = ChapterState.TRANSITIONING
	_transition_timer = transition_duration
	
	# 记录过渡色彩
	_transition_from_color = _chapter_config.get("color_theme", Color.BLACK)
	var next_config = ChapterData.get_chapter_config(next_chapter)
	_transition_to_color = next_config.get("color_theme", Color.WHITE)
	
	# 开始下一章的 BPM 过渡
	var next_bpm: float = next_config.get("bpm", 120)
	_start_bpm_transition(next_bpm)
	
	chapter_transition_started.emit(_current_chapter, next_chapter)

func _process_transition(delta: float) -> void:
	_transition_timer -= delta
	
	# 计算过渡进度
	var progress := 1.0 - (_transition_timer / transition_duration)
	progress = clampf(progress, 0.0, 1.0)
	transition_progress_updated.emit(progress)
	color_theme_changed.emit(_transition_from_color, _transition_to_color, progress)
	
	if _transition_timer <= 0.0:
		var next_chapter := _current_chapter + 1
		if next_chapter >= ChapterData.get_chapter_count():
			# 无尽模式下随机选章
			next_chapter = _completed_chapters[randi() % _completed_chapters.size()]
		
		_chapter_state = ChapterState.INACTIVE
		chapter_transition_completed.emit(next_chapter)
		
		# 开始下一章
		_start_chapter(next_chapter)

func _process_completion(_delta: float) -> void:
	# 等待结算展示完成（由 create_timer 控制）
	pass

# ============================================================
# 特殊机制管理
# ============================================================

func _activate_special_mechanics() -> void:
	var mechanics: Dictionary = _chapter_config.get("special_mechanics", {})
	_active_special_mechanics = mechanics.duplicate()
	
	for mechanic_name in mechanics:
		if mechanics[mechanic_name]:
			var params: Dictionary = {}
			# 收集该机制的参数
			match mechanic_name:
				"swing_grid":
					params = {
						"offbeat_attack_ratio": mechanics.get("offbeat_attack_ratio", 0.7),
						"spotlight_safe_zones": mechanics.get("spotlight_safe_zones", true),
					}
				"waveform_warfare":
					params = {
						"glitch_shader": mechanics.get("glitch_shader", true),
						"bitcrush_zones": mechanics.get("bitcrush_zones", true),
						"frequency_shift": mechanics.get("frequency_shift", true),
					}
			special_mechanic_activated.emit(mechanic_name, params)

func _deactivate_special_mechanics() -> void:
	for mechanic_name in _active_special_mechanics:
		if _active_special_mechanics[mechanic_name]:
			special_mechanic_deactivated.emit(mechanic_name)
	_active_special_mechanics.clear()

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
	
	var step = sign(diff) * bpm_transition_speed * delta
	GameManager.current_bpm += step
	GameManager._update_beat_interval()

## 外部动态 BPM 变化（用于贝多芬 Rubato 等）
func force_bpm_change(new_bpm: float, instant: bool = false) -> void:
	if instant:
		GameManager.current_bpm = new_bpm
		GameManager._update_beat_interval()
		_bpm_transitioning = false
		bpm_changed.emit(new_bpm)
	else:
		_start_bpm_transition(new_bpm)

# ============================================================
# 无尽模式
# ============================================================

func _enter_endless_mode() -> void:
	_is_endless_mode = true
	_endless_loop_count += 1
	_global_difficulty_layer += 2
	
	endless_mode_started.emit(_endless_loop_count)
	
	# 随机循环已完成的章节，持续增加难度
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
	var template = ChapterData.get_wave_template(_current_chapter, _chapter_wave)
	var wave_type: String = template.get("type", "normal")
	
	wave_started_in_chapter.emit(_current_chapter, _chapter_wave, wave_type)
	
	# 检查是否应触发剧本波次
	_check_scripted_wave_trigger("after_random_wave", _chapter_wave)

# ============================================================
# 剧本波次调度器
# ============================================================

## 检查并触发剧本波次
func _check_scripted_wave_trigger(trigger_type: String, wave_number: int) -> void:
	if _scripted_wave_index >= _scripted_wave_schedule.size():
		return
	
	var entry: Dictionary = _scripted_wave_schedule[_scripted_wave_index]
	var entry_trigger: String = entry.get("trigger", "")
	
	var should_trigger := false
	
	match entry_trigger:
		"chapter_start":
			should_trigger = (trigger_type == "chapter_start")
		"after_random_wave":
			var trigger_wave: int = entry.get("trigger_wave", 0)
			should_trigger = (trigger_type == "after_random_wave" and wave_number >= trigger_wave)
		"time_based":
			var trigger_time: float = entry.get("trigger_time", 0.0)
			should_trigger = (_chapter_timer >= trigger_time)
	
	if should_trigger:
		var wave_data_path: String = entry.get("wave_data", "")
		if not wave_data_path.is_empty():
			var wave_data = load(wave_data_path)
			if wave_data:
				_inject_scripted_wave(wave_data)
			else:
				push_warning("ChapterManager: Failed to load wave data: %s" % wave_data_path)
		_scripted_wave_index += 1

## 注入剧本波次到 EnemySpawner
func _inject_scripted_wave(wave_data: Resource) -> void:
	var spawner := get_tree().get_first_node_in_group("enemy_spawner")
	if spawner and spawner.has_method("play_scripted_wave"):
		spawner.play_scripted_wave(wave_data)
		var wave_name: String = wave_data.wave_name if wave_data.has("wave_name") else "unknown"
		scripted_wave_injected.emit(wave_name)
	else:
		push_warning("ChapterManager: EnemySpawner not found or missing play_scripted_wave method")

## 剧本波次完成回调
func _on_scripted_wave_completed(wave_data: Resource) -> void:
	var wave_name: String = wave_data.wave_name if wave_data and wave_data.has("wave_name") else "unknown"
	scripted_wave_finished.emit(wave_name)
	
	# 检查是否有紧接的下一个剧本波次
	if _scripted_wave_index < _scripted_wave_schedule.size():
		var next_entry: Dictionary = _scripted_wave_schedule[_scripted_wave_index]
		var next_trigger: String = next_entry.get("trigger", "")
		if next_trigger == "after_scripted":
			_check_scripted_wave_trigger("after_scripted", 0)

# ============================================================
# 难度缩放接口
# ============================================================

## 获取当前章节+全局的综合难度倍率
func get_difficulty_multiplier() -> Dictionary:
	var chapter_mult := 1.0 + _current_chapter * 0.15
	var global_mult := 1.0 + _global_difficulty_layer * 0.1
	var time_mult := 1.0 + _chapter_timer / 300.0  # 每5分钟+100%
	
	# 无尽模式额外难度
	var endless_mult := 1.0
	if _is_endless_mode:
		endless_mult = 1.0 + _endless_loop_count * 0.25
	
	return {
		"hp": chapter_mult * global_mult * endless_mult * (1.0 + time_mult * 0.3),
		"speed": chapter_mult * endless_mult * (1.0 + time_mult * 0.1),
		"damage": chapter_mult * global_mult * endless_mult * (1.0 + time_mult * 0.2),
		"spawn_rate": (1.0 + time_mult * 0.15) * endless_mult,
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

## 获取章节进度百分比
func get_chapter_progress() -> float:
	var duration: float = _chapter_config.get("duration", 180.0)
	if duration <= 0.0:
		return 1.0
	return clampf(_chapter_timer / duration, 0.0, 1.0)

## 获取当前章节颜色主题
func get_current_color_theme() -> Color:
	return _chapter_config.get("color_theme", Color.WHITE)
