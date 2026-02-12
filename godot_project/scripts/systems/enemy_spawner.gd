## enemy_spawner.gd
## 敌人生成管理器 v3.0 — 章节系统集成版
## 基于波次系统和 BPM 节奏的敌人生成。
## 支持：基础敌人场景 + 章节特色敌人脚本 + 精英/小Boss 脚本
## 与 ChapterManager 协作，根据当前章节配置动态调整敌人池和波次模板。
##
## 生成模式：
##   - 传统模式（无章节）：使用原有权重系统
##   - 章节模式：由 ChapterManager 驱动，使用 ChapterData 配置
extends Node2D

# ============================================================
# 信号
# ============================================================
signal wave_started(wave_number: int, wave_type: String)
signal wave_completed(wave_number: int)
signal elite_spawned(enemy_type: String, position: Vector2)
signal spawn_count_changed(active: int, total_spawned: int)
signal scripted_wave_completed(wave_data: Resource)
signal scripted_wave_started(wave_name: String)

# ============================================================
# 敌人场景预加载（基础五种）
# ============================================================
const ENEMY_SCENES: Dictionary = {
	"static":  "res://scenes/enemies/enemy_static.tscn",
	"silence": "res://scenes/enemies/enemy_silence.tscn",
	"screech": "res://scenes/enemies/enemy_screech.tscn",
	"pulse":   "res://scenes/enemies/enemy_pulse.tscn",
	"wall":    "res://scenes/enemies/enemy_wall.tscn",
}

## 缓存已加载的 PackedScene（基础敌人）
var _loaded_scenes: Dictionary = {}
## 缓存已加载的脚本（章节特色敌人 + 精英）
var _loaded_scripts: Dictionary = {}

## 对象池管理器引用 (Issue #55)
var _pool_manager: Node = null
## 对象池支持的敌人类型（基础五种）
const POOLED_ENEMY_TYPES: Array = ["static", "silence", "screech", "pulse", "wall"]

# ============================================================
# 生成配置
# ============================================================
@export var spawn_radius: float = 600.0
@export var min_spawn_distance: float = 350.0
@export var max_enemies_on_screen: int = 120

## 波次配置
@export var wave_duration: float = 20.0
@export var wave_rest_duration: float = 3.0
@export var base_enemies_per_wave: int = 8

## 难度递增（传统模式用）
@export var difficulty_scale_time: float = 60.0
@export var hp_scale_per_level: float = 1.15
@export var speed_scale_per_level: float = 1.03
@export var damage_scale_per_level: float = 1.1
@export var spawn_count_scale: float = 1.12

# ============================================================
# 敌人类型数值表（基础五种，章节敌人在 ChapterData 中定义）
# ============================================================
const ENEMY_TYPE_DATA: Dictionary = {
	"static": {
		"hp": 30.0, "speed": 80.0, "damage": 8.0, "xp": 3,
		"collision_radius": 12.0, "weight": 1.0,
		"min_difficulty": 0, "desc": "底噪 — 白噪声蜂群",
	},
	"silence": {
		"hp": 120.0, "speed": 35.0, "damage": 15.0, "xp": 12,
		"collision_radius": 18.0, "weight": 3.0,
		"min_difficulty": 3, "desc": "寂静 — 吞噬声音的黑洞",
	},
	"screech": {
		"hp": 15.0, "speed": 150.0, "damage": 5.0, "xp": 4,
		"collision_radius": 8.0, "weight": 1.5,
		"min_difficulty": 1, "desc": "尖啸 — 刺耳的反馈音",
	},
	"pulse": {
		"hp": 60.0, "speed": 55.0, "damage": 12.0, "xp": 8,
		"collision_radius": 14.0, "weight": 2.5,
		"min_difficulty": 2, "desc": "脉冲 — 错误的节拍器",
	},
	"wall": {
		"hp": 200.0, "speed": 25.0, "damage": 20.0, "xp": 15,
		"collision_radius": 28.0, "weight": 4.0,
		"min_difficulty": 4, "desc": "音墙 — 砖墙限制器",
	},
}

# ============================================================
# 波次类型定义
# ============================================================
enum WaveType {
	NORMAL,
	SWARM,
	ELITE,
	SILENCE_TIDE,
	PULSE_STORM,
	BOSS_WAVE,
	CHAPTER_INTRO,  ## 章节引入波（展示新敌人）
	PRE_BOSS,       ## Boss前冲刺波
}

# ============================================================
# 状态
# ============================================================
var _difficulty_level: int = 0
var _total_enemies_spawned: int = 0
var _active_enemies: Array[Node2D] = []

## 波次状态
var _current_wave: int = 0
var _wave_timer: float = 0.0
var _wave_rest_timer: float = 0.0
var _is_wave_active: bool = false
var _is_resting: bool = false
var _current_wave_type: WaveType = WaveType.NORMAL
var _wave_spawn_budget: int = 0
var _wave_spawn_timer: float = 0.0

## BPM 节奏生成
var _beat_spawn_enabled: bool = true
var _beats_since_last_spawn: int = 0
var _spawn_every_n_beats: int = 2

## ===== 章节模式状态 =====
var _chapter_mode: bool = false
var _chapter_index: int = -1
var _chapter_config: Dictionary = {}
var _chapter_wave: int = 0  # 章节内波次号
var _current_wave_template: Dictionary = {}
var _boss_phase_active: bool = false  # Boss 阶段（暂停普通生成）

## ===== 剧本波次模式状态 =====
var _scripted_wave_active: bool = false
var _scripted_wave_data: Resource = null  # WaveData
var _scripted_wave_timer: float = 0.0
var _scripted_event_index: int = 0
var _scripted_enemies: Array[Node2D] = []  # 剧本波次生成的敌人
var _last_spawned_enemy: Node2D = null  # 最后生成的敌人（用于 SPAWN_ESCORT）

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_to_group("enemy_spawner")
	_preload_enemy_scenes()
	_connect_signals()
	_init_pool_manager()
	_is_resting = true
	_wave_rest_timer = 2.0

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	# Boss 阶段暂停普通生成
	if _boss_phase_active:
		_cleanup_dead_enemies()
		return
	
	# 剧本模式优先
	if _scripted_wave_active:
		_process_scripted_wave(delta)
		_cleanup_dead_enemies()
		return
	
	_update_difficulty()
	
	if _is_resting:
		_wave_rest_timer -= delta
		if _wave_rest_timer <= 0.0:
			_start_new_wave()
	elif _is_wave_active:
		_process_wave(delta)
	
	_cleanup_dead_enemies()

# ============================================================
# 场景和脚本预加载
# ============================================================

func _preload_enemy_scenes() -> void:
	for type_name in ENEMY_SCENES:
		var scene_path: String = ENEMY_SCENES[type_name]
		var scene := load(scene_path) as PackedScene
		if scene:
			_loaded_scenes[type_name] = scene
		else:
			push_warning("EnemySpawner: Failed to load scene: " + scene_path)

func _preload_chapter_scripts() -> void:
	# 优先预加载章节特色敌人场景文件（Issue #90）
	for type_name in ChapterData.ENEMY_SCENE_PATHS:
		var scene_path: String = ChapterData.ENEMY_SCENE_PATHS[type_name]
		if scene_path != "" and not _loaded_scenes.has(type_name):
			var scene := load(scene_path) as PackedScene
			if scene:
				_loaded_scenes[type_name] = scene
			else:
				push_warning("EnemySpawner: Failed to load chapter enemy scene: " + scene_path)
	
	# 预加载章节特色敌人脚本（作为场景加载失败时的回退）
	for type_name in ChapterData.ENEMY_SCRIPT_PATHS:
		var path: String = ChapterData.ENEMY_SCRIPT_PATHS[type_name]
		if path != "" and not _loaded_scripts.has(type_name):
			var script := load(path)
			if script:
				_loaded_scripts[type_name] = script
			else:
				push_warning("EnemySpawner: Failed to load chapter enemy script: " + path)
	
	# 优先预加载精英敌人场景文件（Issue #90）
	for type_name in ChapterData.ELITE_SCENE_PATHS:
		var scene_path: String = ChapterData.ELITE_SCENE_PATHS[type_name]
		if scene_path != "" and not _loaded_scenes.has(type_name):
			var scene := load(scene_path) as PackedScene
			if scene:
				_loaded_scenes[type_name] = scene
			else:
				push_warning("EnemySpawner: Failed to load elite scene: " + scene_path)
	
	# 预加载精英脚本（作为场景加载失败时的回退）
	for type_name in ChapterData.ELITE_SCRIPT_PATHS:
		var path: String = ChapterData.ELITE_SCRIPT_PATHS[type_name]
		if path != "" and not _loaded_scripts.has(type_name):
			var script := load(path)
			if script:
				_loaded_scripts[type_name] = script
			else:
				push_warning("EnemySpawner: Failed to load elite script: " + path)

func _connect_signals() -> void:
	if not GameManager.beat_tick.is_connected(_on_global_beat):
		GameManager.beat_tick.connect(_on_global_beat)

# ============================================================
# 章节模式接口（由 ChapterManager 调用）
# ============================================================

## 切换到章节模式
func set_chapter_mode(chapter_index: int, config: Dictionary) -> void:
	_chapter_mode = true
	_chapter_index = chapter_index
	_chapter_config = config
	_chapter_wave = 0
	_boss_phase_active = false
	
	# 预加载章节脚本
	_preload_chapter_scripts()
	
	# 重置波次
	_current_wave = 0
	_is_wave_active = false
	_is_resting = true
	_wave_rest_timer = 1.5

## 进入Boss阶段（暂停普通敌人生成）
func enter_boss_phase() -> void:
	_boss_phase_active = true
	_is_wave_active = false
	_is_resting = false

## 退出Boss阶段（恢复普通生成）
func exit_boss_phase() -> void:
	_boss_phase_active = false
	_is_resting = true
	_wave_rest_timer = 2.0

# ============================================================
# 剧本波次接口（由 ChapterManager 调用）
# ============================================================

## 注入一个剧本波次，暂停随机生成
func play_scripted_wave(wave_data: Resource) -> void:
	_scripted_wave_active = true
	_scripted_wave_data = wave_data
	_scripted_wave_timer = 0.0
	_scripted_event_index = 0
	_scripted_enemies.clear()
	_last_spawned_enemy = null
	# 暂停随机生成
	_is_wave_active = false
	_is_resting = false
	scripted_wave_started.emit(wave_data.wave_name if wave_data else "unknown")

## 恢复随机生成
func resume_random_spawning() -> void:
	_scripted_wave_active = false
	_scripted_wave_data = null
	_scripted_enemies.clear()
	_is_resting = true
	_wave_rest_timer = 2.0

## 检查剧本波次是否正在进行
func is_scripted_wave_active() -> bool:
	return _scripted_wave_active

# ============================================================
# 剧本波次处理
# ============================================================

func _process_scripted_wave(delta: float) -> void:
	if _scripted_wave_data == null:
		_scripted_wave_active = false
		return
	
	_scripted_wave_timer += delta
	var events: Array = _scripted_wave_data.events
	
	# 按时间戳触发事件
	while _scripted_event_index < events.size():
		var event: Dictionary = events[_scripted_event_index]
		var timestamp: float = event.get("timestamp", 0.0)
		if _scripted_wave_timer >= timestamp:
			_execute_scripted_event(event)
			_scripted_event_index += 1
		else:
			break
	
	# 所有事件已触发后，检查完成条件
	if _scripted_event_index >= events.size():
		var condition: String = _scripted_wave_data.success_condition if _scripted_wave_data and "success_condition" in _scripted_wave_data else "kill_all"
		var is_complete := false
		
		match condition:
			"kill_all":
				# 所有剧本敌人已被击杀
				var alive_scripted := _scripted_enemies.filter(
					func(e): return is_instance_valid(e) and e.get_meta("scripted", false)
				)
				is_complete = alive_scripted.is_empty()
			"survive":
				var survive_time: float = _scripted_wave_data.success_params.get("time", 30.0) if _scripted_wave_data.has("success_params") else 30.0
				is_complete = _scripted_wave_timer >= (_scripted_wave_data.get_last_event_timestamp() + survive_time)
			_:
				is_complete = true
		
		if is_complete:
			var completed_data := _scripted_wave_data
			scripted_wave_completed.emit(completed_data)
			resume_random_spawning()

func _execute_scripted_event(event: Dictionary) -> void:
	var event_type: String = event.get("type", "")
	var params: Dictionary = event.get("params", {})
	
	# 如果参数直接在 event 顶层（兼容简化格式）
	if params.is_empty():
		params = event.duplicate()
		params.erase("timestamp")
		params.erase("type")
	
	match event_type:
		"SPAWN":
			_scripted_spawn(params)
		"SPAWN_SWARM":
			_scripted_spawn_swarm(params)
		"SPAWN_ESCORT":
			_scripted_spawn_escort(params)
		"SET_BPM":
			_scripted_set_bpm(params)
		"SHOW_HINT":
			_scripted_show_hint(params)
		"CONDITIONAL_HINT":
			_scripted_conditional_hint(params)
		"UNLOCK":
			_scripted_unlock(params)

func _scripted_spawn(params: Dictionary) -> void:
	var enemy_type: String = params.get("enemy", "static")
	var position_param = params.get("position", "NORTH")
	var spawn_pos := _resolve_spawn_position(position_param)
	
	_spawn_enemy_at(spawn_pos, enemy_type)
	
	# 获取刚生成的敌人并应用剧本参数
	if not _active_enemies.is_empty():
		var enemy := _active_enemies[-1]
		if is_instance_valid(enemy):
			_apply_scripted_params(enemy, params)
			enemy.set_meta("scripted", true)
			_scripted_enemies.append(enemy)
			_last_spawned_enemy = enemy

func _scripted_spawn_swarm(params: Dictionary) -> void:
	var enemy_type: String = params.get("enemy", "static")
	var count: int = params.get("count", 5)
	var formation: String = params.get("formation", "LINE")
	var direction: String = params.get("direction", "NORTH")
	var speed: float = params.get("speed", 80.0)
	var swarm_enabled: bool = params.get("swarm_enabled", false)
	
	var player := get_tree().get_first_node_in_group("player")
	var base_pos := _resolve_spawn_position(direction)
	
	for i in range(count):
		var offset := _get_formation_offset(formation, i, count)
		var spawn_pos := base_pos + offset
		
		_spawn_enemy_at(spawn_pos, enemy_type)
		
		if not _active_enemies.is_empty():
			var enemy := _active_enemies[-1]
			if is_instance_valid(enemy):
				enemy.set("move_speed", speed)
				enemy.set_meta("scripted", true)
				if swarm_enabled:
					enemy.set_meta("swarm_enabled", true)
				_scripted_enemies.append(enemy)
				_last_spawned_enemy = enemy

func _scripted_spawn_escort(params: Dictionary) -> void:
	var enemy_type: String = params.get("enemy", "static")
	var count: int = params.get("count", 4)
	var orbit_radius: float = params.get("orbit_radius", 80.0)
	var speed: float = params.get("speed", 80.0)
	var orbit_target_str: String = params.get("orbit_target", "LAST_SPAWNED")
	
	var orbit_center := Vector2.ZERO
	if orbit_target_str == "LAST_SPAWNED" and is_instance_valid(_last_spawned_enemy):
		orbit_center = _last_spawned_enemy.global_position
	
	for i in range(count):
		var angle := (TAU / count) * i
		var spawn_pos := orbit_center + Vector2.from_angle(angle) * orbit_radius
		
		_spawn_enemy_at(spawn_pos, enemy_type)
		
		if not _active_enemies.is_empty():
			var enemy := _active_enemies[-1]
			if is_instance_valid(enemy):
				enemy.set("move_speed", speed)
				enemy.set_meta("scripted", true)
				enemy.set_meta("escort", true)
				if is_instance_valid(_last_spawned_enemy):
					enemy.set_meta("escort_target", _last_spawned_enemy)
				_scripted_enemies.append(enemy)

func _scripted_set_bpm(params: Dictionary) -> void:
	var bpm: float = params.get("bpm", 120.0)
	var chapter_mgr := get_node_or_null("/root/ChapterManager")
	if chapter_mgr and chapter_mgr.has_method("force_bpm_change"):
		chapter_mgr.force_bpm_change(bpm, false)
	else:
		GameManager.current_bpm = bpm
		if GameManager.has_method("_update_beat_interval"):
			GameManager._update_beat_interval()

func _scripted_show_hint(params: Dictionary) -> void:
	var text: String = params.get("text", "")
	var duration: float = params.get("duration", 4.0)
	var highlight_ui: String = params.get("highlight_ui", "")
	
	var hint_mgr := get_node_or_null("/root/TutorialHintManager")
	if hint_mgr and hint_mgr.has_method("show_hint"):
		hint_mgr.show_hint(text, duration, highlight_ui)

func _scripted_conditional_hint(params: Dictionary) -> void:
	var condition: String = params.get("condition", "")
	var text: String = params.get("text", "")
	var highlight_ui: String = params.get("highlight_ui", "")
	
	var hint_mgr := get_node_or_null("/root/TutorialHintManager")
	if hint_mgr:
		if hint_mgr.has_method("register_conditional_hint"):
			hint_mgr.register_conditional_hint(condition, text, highlight_ui)
		# 解析条件中的超时时间（如 NO_REST_USED_FOR_15s → 15秒）
		var timeout := _parse_condition_timeout(condition)
		if timeout > 0.0 and hint_mgr.has_method("start_condition_tracker"):
			hint_mgr.start_condition_tracker(condition, timeout)

func _scripted_unlock(params: Dictionary) -> void:
	var unlock_type: String = params.get("type", "")
	var message: String = params.get("message", "")
	var unlock_name: String = ""
	
	match unlock_type:
		"note":
			unlock_name = params.get("note", "")
		"feature":
			unlock_name = params.get("feature", "")
		"rhythm":
			unlock_name = params.get("rhythm", "")
	
	var hint_mgr := get_node_or_null("/root/TutorialHintManager")
	if hint_mgr and hint_mgr.has_method("show_unlock"):
		hint_mgr.show_unlock(unlock_type, unlock_name, message)

# ============================================================
# 剧本波次辅助函数
# ============================================================

func _resolve_spawn_position(position_param) -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	var player_pos: Vector2 = player.global_position if player else Vector2.ZERO
	
	if position_param is Vector2:
		return player_pos + position_param
	
	if position_param is String:
		# 检查是否是 Vector2 字符串格式
		var pos_str: String = position_param
		if pos_str.begins_with("Vector2("):
			var inner := pos_str.substr(8, pos_str.length() - 9)
			var parts := inner.split(",")
			if parts.size() == 2:
				return player_pos + Vector2(float(parts[0].strip_edges()), float(parts[1].strip_edges()))
		
		# 方位关键字
		match pos_str:
			"NORTH":
				return player_pos + Vector2(randf_range(-100, 100), -spawn_radius)
			"SOUTH":
				return player_pos + Vector2(randf_range(-100, 100), spawn_radius)
			"EAST":
				return player_pos + Vector2(spawn_radius, randf_range(-100, 100))
			"WEST":
				return player_pos + Vector2(-spawn_radius, randf_range(-100, 100))
	
	# 默认：随机位置
	return _calculate_spawn_position(player_pos)

func _apply_scripted_params(enemy: Node, params: Dictionary) -> void:
	if params.has("speed"):
		enemy.set("move_speed", params["speed"])
	if params.has("hp"):
		enemy.set("max_hp", params["hp"])
		enemy.set("current_hp", params["hp"])
	if params.has("shield"):
		if enemy.has_method("set_shield"):
			enemy.set_shield(params["shield"])
		else:
			enemy.set_meta("shield_hp", params["shield"])
	if params.has("damage"):
		enemy.set("contact_damage", params["damage"])

func _get_formation_offset(formation: String, index: int, total: int) -> Vector2:
	match formation:
		"LINE":
			var spacing := 40.0
			var start_x := -(total - 1) * spacing / 2.0
			return Vector2(start_x + index * spacing, 0.0)
		"CIRCLE":
			var angle := (TAU / total) * index
			return Vector2.from_angle(angle) * 60.0
		"SCATTERED":
			return Vector2(randf_range(-120, 120), randf_range(-80, 80))
		"V_SHAPE":
			var half := total / 2
			var side := 1 if index < half else -1
			var depth := index if index < half else index - half
			return Vector2(side * (depth + 1) * 35.0, depth * 25.0)
		_:
			return Vector2(randf_range(-80, 80), randf_range(-80, 80))

func _parse_condition_timeout(condition: String) -> float:
	# 从条件字符串中解析超时时间
	# 例如 "NO_REST_USED_FOR_15s" → 15.0
	var regex_match := condition.find("FOR_")
	if regex_match >= 0:
		var after := condition.substr(regex_match + 4)
		var num_str := after.rstrip("s")
		if num_str.is_valid_float():
			return float(num_str)
	return 0.0

## 为Boss召唤小兵
func spawn_minions_for_boss(count: int, type: String, boss_pos: Vector2) -> void:
	for i in range(count):
		var angle := (TAU / count) * i + randf_range(-0.3, 0.3)
		var dist := randf_range(80.0, 150.0)
		var spawn_pos := boss_pos + Vector2.from_angle(angle) * dist
		_spawn_enemy_at(spawn_pos, type)

# ============================================================
# 难度系统
# ============================================================

func _update_difficulty() -> void:
	if _chapter_mode:
		# 章节模式下由 ChapterManager 提供难度倍率
		var new_level := int(GameManager.game_time / difficulty_scale_time)
		if new_level != _difficulty_level:
			_difficulty_level = new_level
	else:
		var new_level := int(GameManager.game_time / difficulty_scale_time)
		if new_level != _difficulty_level:
			_difficulty_level = new_level

func _get_difficulty_multipliers() -> Dictionary:
	if _chapter_mode:
		var chapter_mgr := get_node_or_null("/root/ChapterManager")
		if chapter_mgr and chapter_mgr.has_method("get_difficulty_multiplier"):
			return chapter_mgr.get_difficulty_multiplier()
	
	return {
		"hp": pow(hp_scale_per_level, _difficulty_level),
		"speed": pow(speed_scale_per_level, _difficulty_level),
		"damage": pow(damage_scale_per_level, _difficulty_level),
		"spawn_rate": pow(spawn_count_scale, _difficulty_level),
	}

func _get_hp_scale() -> float:
	return _get_difficulty_multipliers().get("hp", 1.0)

func _get_speed_scale() -> float:
	return _get_difficulty_multipliers().get("speed", 1.0)

func _get_damage_scale() -> float:
	return _get_difficulty_multipliers().get("damage", 1.0)

func _get_wave_enemy_count() -> int:
	if _chapter_mode and not _current_wave_template.is_empty():
		var base_count: int = _current_wave_template.get("enemy_count_base", base_enemies_per_wave)
		var spawn_mult: float = _get_difficulty_multipliers().get("spawn_rate", 1.0)
		return int(base_count * spawn_mult)
	return int(base_enemies_per_wave * _get_difficulty_multipliers().get("spawn_rate", 1.0))

# ============================================================
# 波次系统
# ============================================================

func _start_new_wave() -> void:
	_current_wave += 1
	_is_wave_active = true
	_is_resting = false
	_wave_spawn_timer = 0.0
	
	if _chapter_mode:
		_chapter_wave += 1
		# 通知 ChapterManager 波次推进
		var chapter_mgr := get_node_or_null("/root/ChapterManager")
		if chapter_mgr and chapter_mgr.has_method("advance_chapter_wave"):
			chapter_mgr.advance_chapter_wave()
		
		# 获取章节波次模板
		_current_wave_template = ChapterData.get_wave_template(_chapter_index, _chapter_wave)
		_current_wave_type = _determine_chapter_wave_type()
	else:
		_current_wave_type = _determine_wave_type()
	
	_wave_spawn_budget = _get_wave_enemy_count()
	_wave_timer = wave_duration
	
	# 特殊波次调整
	match _current_wave_type:
		WaveType.SWARM:
			_wave_spawn_budget = int(_wave_spawn_budget * 2.5)
		WaveType.ELITE:
			_wave_spawn_budget = max(2, int(_wave_spawn_budget * 0.3))
			# 章节模式下生成精英
			if _chapter_mode:
				_spawn_chapter_elite()
		WaveType.CHAPTER_INTRO:
			_wave_spawn_budget = int(_wave_spawn_budget * 0.7)
		WaveType.PRE_BOSS:
			_wave_spawn_budget = int(_wave_spawn_budget * 1.5)
		WaveType.SILENCE_TIDE:
			_wave_spawn_budget = int(_wave_spawn_budget * 0.8)
		WaveType.PULSE_STORM:
			_wave_spawn_budget = max(3, int(_wave_spawn_budget * 0.5))
	
	var wave_type_name := _get_wave_type_name(_current_wave_type)
	wave_started.emit(_current_wave, wave_type_name)

func _determine_chapter_wave_type() -> WaveType:
	if _current_wave_template.is_empty():
		return WaveType.NORMAL
	
	var type_str: String = _current_wave_template.get("type", "normal")
	match type_str:
		"normal":        return WaveType.NORMAL
		"swarm":         return WaveType.SWARM
		"elite":         return WaveType.ELITE
		"chapter_intro": return WaveType.CHAPTER_INTRO
		"pre_boss":      return WaveType.PRE_BOSS
		"silence_tide":  return WaveType.SILENCE_TIDE
		"pulse_storm":   return WaveType.PULSE_STORM
		_:               return WaveType.NORMAL

func _process_wave(delta: float) -> void:
	_wave_timer -= delta
	
	if _wave_timer <= 0.0 or (_wave_spawn_budget <= 0 and _active_enemies.size() == 0):
		_end_wave()
		return
	
	if _wave_spawn_budget > 0 and _active_enemies.size() < max_enemies_on_screen:
		var spawn_interval: float
		if _chapter_mode and _current_wave_template.has("spawn_interval"):
			spawn_interval = _current_wave_template["spawn_interval"]
		else:
			spawn_interval = wave_duration / float(max(1, _get_wave_enemy_count()))
			spawn_interval = max(spawn_interval, 0.3)
		
		_wave_spawn_timer += delta
		if _wave_spawn_timer >= spawn_interval:
			_wave_spawn_timer = 0.0
			_spawn_wave_enemies()

func _end_wave() -> void:
	_is_wave_active = false
	_is_resting = true
	_wave_rest_timer = wave_rest_duration
	wave_completed.emit(_current_wave)

func _determine_wave_type() -> WaveType:
	if _current_wave <= 3:
		return WaveType.NORMAL
	
	var roll := randf()
	if _current_wave % 5 == 0:
		return WaveType.ELITE
	if _current_wave % 7 == 0:
		if _difficulty_level >= 3:
			return WaveType.SILENCE_TIDE
		else:
			return WaveType.SWARM
	
	if roll < 0.45:
		return WaveType.NORMAL
	elif roll < 0.65:
		return WaveType.SWARM
	elif roll < 0.80:
		return WaveType.ELITE
	elif roll < 0.90 and _difficulty_level >= 3:
		return WaveType.SILENCE_TIDE
	elif _difficulty_level >= 2:
		return WaveType.PULSE_STORM
	else:
		return WaveType.NORMAL

func _get_wave_type_name(wave_type: WaveType) -> String:
	match wave_type:
		WaveType.NORMAL:        return "normal"
		WaveType.SWARM:         return "swarm"
		WaveType.ELITE:         return "elite"
		WaveType.SILENCE_TIDE:  return "silence_tide"
		WaveType.PULSE_STORM:   return "pulse_storm"
		WaveType.BOSS_WAVE:     return "boss"
		WaveType.CHAPTER_INTRO: return "chapter_intro"
		WaveType.PRE_BOSS:      return "pre_boss"
		_:                      return "unknown"

# ============================================================
# BPM 节奏生成
# ============================================================

func _on_global_beat(_beat_index: int) -> void:
	if not _is_wave_active or not _beat_spawn_enabled:
		return
	
	_beats_since_last_spawn += 1
	if _beats_since_last_spawn >= _spawn_every_n_beats:
		_beats_since_last_spawn = 0
		var half_beat := 60.0 / GameManager.current_bpm / 2.0
		get_tree().create_timer(half_beat).timeout.connect(_beat_spawn_batch)

func _beat_spawn_batch() -> void:
	if _wave_spawn_budget <= 0 or _active_enemies.size() >= max_enemies_on_screen:
		return
	_spawn_wave_enemies()

# ============================================================
# 生成逻辑
# ============================================================

func _spawn_wave_enemies() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	
	var spawn_count := _get_batch_spawn_count()
	
	for i in range(spawn_count):
		if _wave_spawn_budget <= 0:
			break
		
		var enemy_type := _select_enemy_type()
		_spawn_enemy(player.global_position, enemy_type)
		_wave_spawn_budget -= 1

func _get_batch_spawn_count() -> int:
	match _current_wave_type:
		WaveType.SWARM:
			return randi_range(3, 6)
		WaveType.ELITE:
			return 1
		WaveType.SILENCE_TIDE:
			return randi_range(2, 4)
		WaveType.PULSE_STORM:
			return randi_range(1, 2)
		WaveType.CHAPTER_INTRO:
			return randi_range(1, 2)
		WaveType.PRE_BOSS:
			return randi_range(2, 5)
		_:
			return randi_range(1, 3)

func _select_enemy_type() -> String:
	# 章节模式：使用波次模板中的敌人类型
	if _chapter_mode and not _current_wave_template.is_empty():
		var types: Array = _current_wave_template.get("enemy_types", ["static"])
		if types.is_empty():
			return "static"
		return types[randi() % types.size()]
	
	# 传统模式
	match _current_wave_type:
		WaveType.SWARM:
			return "static" if randf() < 0.9 else "screech"
		WaveType.ELITE:
			var roll := randf()
			if _difficulty_level >= 4 and roll < 0.3:
				return "wall"
			elif _difficulty_level >= 3 and roll < 0.5:
				return "silence"
			elif roll < 0.7:
				return "pulse"
			else:
				return "screech"
		WaveType.SILENCE_TIDE:
			return "silence" if randf() < 0.25 else "static"
		WaveType.PULSE_STORM:
			return "pulse" if randf() < 0.6 else "static"
		_:
			return _weighted_enemy_select()

func _weighted_enemy_select() -> String:
	if _chapter_mode:
		return ChapterData.weighted_select_enemy(_chapter_index, _chapter_wave)
	
	var available: Array[Dictionary] = []
	var total_weight := 0.0
	for type_name in ENEMY_TYPE_DATA:
		var data: Dictionary = ENEMY_TYPE_DATA[type_name]
		if _difficulty_level >= data["min_difficulty"]:
			available.append({"name": type_name, "weight": data["weight"]})
			total_weight += data["weight"]
	
	if available.is_empty():
		return "static"
	
	var roll := randf() * total_weight
	var cumulative := 0.0
	for entry in available:
		cumulative += entry["weight"]
		if roll <= cumulative:
			return entry["name"]
	return available[-1]["name"]

# ============================================================
# 精英生成（章节模式）
# ============================================================

func _spawn_chapter_elite() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	
	var elite_type: String = ""
	if not _current_wave_template.is_empty():
		elite_type = _current_wave_template.get("elite_type", "")
	
	if elite_type == "":
		elite_type = ChapterData.select_elite(_chapter_index, _chapter_wave)
	
	if elite_type == "":
		return
	
	var spawn_pos := _calculate_spawn_position(player.global_position)
	_spawn_enemy_at(spawn_pos, elite_type)
	elite_spawned.emit(elite_type, spawn_pos)

# ============================================================
# 敌人实例化（统一入口）
# ============================================================

func _spawn_enemy(player_pos: Vector2, type_name: String) -> void:
	var spawn_pos := _calculate_spawn_position(player_pos)
	_spawn_enemy_at(spawn_pos, type_name)

func _spawn_enemy_at(spawn_pos: Vector2, type_name: String) -> void:
	var enemy: CharacterBody2D = null
	var from_pool: bool = false
	
	# 1. 优先尝试从对象池获取 (Issue #55)
	if _pool_manager and type_name in POOLED_ENEMY_TYPES:
		enemy = _pool_manager.acquire_enemy(type_name) as CharacterBody2D
		if enemy:
			from_pool = true
	
	# 2. 尝试从预加载场景实例化（基础五种）
	if enemy == null:
		var scene: PackedScene = _loaded_scenes.get(type_name)
		if scene:
			enemy = scene.instantiate() as CharacterBody2D
	
	# 3. 尝试从脚本实例化（章节特色 + 精英）
	if enemy == null:
		enemy = _instantiate_from_script(type_name)
	
	if enemy == null:
		push_warning("EnemySpawner: Cannot create enemy of type: " + type_name)
		return
	
	enemy.global_position = spawn_pos
	
	# 标记敌人来源（用于回收时判断）
	enemy.set_meta("from_pool", from_pool)
	enemy.set_meta("pool_type", type_name)
	
	# 应用难度缩放
	_apply_difficulty_scaling(enemy, type_name)
	
	# 精英波中的普通敌人获得额外加成
	if _current_wave_type == WaveType.ELITE and not ChapterData.is_elite_enemy(type_name):
		_apply_elite_bonus(enemy, type_name)
	
	# 从对象池获取的敌人已在场景树中，只需重新激活
	if not from_pool:
		add_child(enemy)
	_active_enemies.append(enemy)
	_total_enemies_spawned += 1
	
	if enemy.has_signal("enemy_died"):
		if not enemy.enemy_died.is_connected(_on_enemy_died):
			enemy.enemy_died.connect(_on_enemy_died)
	
	spawn_count_changed.emit(_active_enemies.size(), _total_enemies_spawned)

## 从脚本动态实例化敌人
func _instantiate_from_script(type_name: String) -> CharacterBody2D:
	var script = _loaded_scripts.get(type_name)
	
	# 如果未缓存，尝试加载
	if script == null:
		var path: String = ""
		if ChapterData.ENEMY_SCRIPT_PATHS.has(type_name):
			path = ChapterData.ENEMY_SCRIPT_PATHS[type_name]
		elif ChapterData.ELITE_SCRIPT_PATHS.has(type_name):
			path = ChapterData.ELITE_SCRIPT_PATHS[type_name]
		
		if path != "":
			script = load(path)
			if script:
				_loaded_scripts[type_name] = script
	
	if script == null:
		return null
	
	var enemy := CharacterBody2D.new()
	enemy.set_script(script)
	
	# 创建必要的子节点
	_create_enemy_nodes(enemy, type_name)
	
	return enemy

## 为脚本实例化的敌人创建必要子节点
## 章节特色敌人拥有自定义程序化视觉，其 _on_enemy_ready() 会自行创建视觉节点并设置 _sprite
## 因此对这些敌人仅创建碰撞体和伤害区域，跳过通用 EnemyVisual
const CUSTOM_VISUAL_ENEMIES: Array = [
	"ch3_counterpoint_crawler",
	"ch4_minuet_dancer",
	"ch5_fury_spirit",
	"ch6_walking_bass",
	"ch7_bitcrusher_worm",
]
func _create_enemy_nodes(enemy: Node, type_name: String) -> void:
	var is_elite = ChapterData.is_elite_enemy(type_name)
	var radius := 16.0 if is_elite else 12.0
	var has_custom_visual := type_name in CUSTOM_VISUAL_ENEMIES
	
	# EnemyVisual — 拥有自定义视觉的敌人跳过通用视觉创建
	# 它们会在 _on_enemy_ready() 中创建程序化视觉并命名为 "EnemyVisual"
	if not has_custom_visual:
		var visual := Polygon2D.new()
		visual.name = "EnemyVisual"
		var points := PackedVector2Array()
		var sides := 6 if is_elite else 4
		for i in range(sides):
			var angle := (TAU / sides) * i - PI / 2.0
			var r := radius * (1.2 if i % 2 == 0 else 0.9) if is_elite else radius
			points.append(Vector2.from_angle(angle) * r)
		visual.polygon = points
		visual.color = Color(0.7, 0.3, 0.3)
		enemy.add_child(visual)
	
	# CollisionShape2D
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	enemy.add_child(col)
	
	# DamageArea
	var damage_area := Area2D.new()
	damage_area.name = "DamageArea"
	damage_area.collision_layer = 2
	damage_area.collision_mask = 1
	var da_col := CollisionShape2D.new()
	var da_shape := CircleShape2D.new()
	da_shape.radius = radius + 4.0
	da_col.shape = da_shape
	damage_area.add_child(da_col)
	enemy.add_child(damage_area)

func _calculate_spawn_position(player_pos: Vector2) -> Vector2:
	var angle := randf() * TAU
	var distance := randf_range(min_spawn_distance, spawn_radius)
	return player_pos + Vector2.from_angle(angle) * distance

func _apply_difficulty_scaling(enemy: CharacterBody2D, type_name: String) -> void:
	# 获取基础数值
	var base_data: Dictionary
	if ENEMY_TYPE_DATA.has(type_name):
		base_data = ENEMY_TYPE_DATA[type_name]
	elif ChapterData.CHAPTER_ENEMY_STATS.has(type_name):
		base_data = ChapterData.get_enemy_base_stats(type_name)
	else:
		base_data = {"hp": 30.0, "speed": 80.0, "damage": 8.0, "xp": 3}
	
	var mults := _get_difficulty_multipliers()
	
	var scaled_hp = base_data.get("hp", 30.0) * mults.get("hp", 1.0)
	var scaled_speed = base_data.get("speed", 80.0) * mults.get("speed", 1.0)
	var scaled_damage = base_data.get("damage", 8.0) * mults.get("damage", 1.0)
	
	enemy.set("max_hp", scaled_hp)
	enemy.set("current_hp", scaled_hp)
	enemy.set("move_speed", scaled_speed)
	enemy.set("contact_damage", scaled_damage)

func _apply_elite_bonus(enemy: CharacterBody2D, _type_name: String) -> void:
	var current_hp: float = enemy.get("max_hp")
	enemy.set("max_hp", current_hp * 1.5)
	enemy.set("current_hp", current_hp * 1.5)
	
	var current_damage: float = enemy.get("contact_damage")
	enemy.set("contact_damage", current_damage * 1.3)
	
	var visual := enemy.get_node_or_null("EnemyVisual")
	if visual:
		visual.scale *= 1.2
		visual.modulate = visual.modulate.lerp(Color(1.0, 0.85, 0.3), 0.3)
	
	elite_spawned.emit(_type_name, enemy.global_position)

# ============================================================
# 敌人管理
# ============================================================

func _on_enemy_died(pos: Vector2, xp: int, enemy_type: String) -> void:
	# 经验值由 xp_pickup 拾取时添加，不在此处重复添加
	_spawn_xp_pickup(pos, xp, enemy_type)
	
	# 尝试将死亡敌人归还对象池 (Issue #55)
	_return_dead_enemy_to_pool(enemy_type)

func _cleanup_dead_enemies() -> void:
	_active_enemies = _active_enemies.filter(func(e): return is_instance_valid(e))

# ============================================================
# 经验值拾取物
# ============================================================

func _spawn_xp_pickup(pos: Vector2, value: int, _enemy_type: String) -> void:
	## 重构：使用 xp_pickup.gd 脚本创建经验拾取物 (Issue #51)
	## xp_pickup.gd 已包含完整的视觉、磁吸、节拍脉冲、生命周期、颜色分级和合并机制
	var XpPickupScript = load("res://scripts/entities/xp_pickup.gd")
	var pickup := XpPickupScript.create(pos, value)
	add_child(pickup)

# ============================================================
# 公共接口
# ============================================================

func get_enemy_collision_data() -> Array:
	var data: Array = []
	for enemy in _active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("get_collision_data"):
			data.append(enemy.get_collision_data())
	return data

func get_active_enemy_count() -> int:
	return _active_enemies.size()

func get_current_wave() -> int:
	return _current_wave

func get_chapter_wave() -> int:
	return _chapter_wave

func get_difficulty_level() -> int:
	return _difficulty_level

func is_wave_active() -> bool:
	return _is_wave_active

func is_chapter_mode() -> bool:
	return _chapter_mode

func is_boss_phase() -> bool:
	return _boss_phase_active

func get_wave_progress() -> float:
	if not _is_wave_active:
		return 0.0
	return 1.0 - (_wave_timer / wave_duration)

## 清除所有活跃敌人（章节过渡时使用）
func clear_all_enemies() -> void:
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			var from_pool: bool = enemy.get_meta("from_pool", false)
			var pool_type: String = enemy.get_meta("pool_type", "")
			if from_pool and _pool_manager and pool_type != "":
				_pool_manager.release_enemy(pool_type, enemy)
			else:
				enemy.queue_free()
	_active_enemies.clear()
	_wave_spawn_budget = 0

# ============================================================
# 对象池集成 (Issue #55)
# ============================================================

## 初始化对象池管理器引用
func _init_pool_manager() -> void:
	# PoolManager 可能作为场景子节点存在，也可能作为 Autoload
	_pool_manager = get_node_or_null("/root/PoolManager")
	if _pool_manager == null:
		# 尝试在场景树中查找
		_pool_manager = get_tree().get_first_node_in_group("pool_manager") if get_tree() else null
	if _pool_manager == null:
		# 尝试从父节点查找
		var parent := get_parent()
		if parent:
			_pool_manager = parent.get_node_or_null("PoolManager")
	if _pool_manager:
		print("EnemySpawner: PoolManager connected (Issue #55)")
	else:
		push_warning("EnemySpawner: PoolManager not found, falling back to instantiate/queue_free")

## 将死亡敌人归还对象池
func _return_dead_enemy_to_pool(enemy_type: String) -> void:
	if _pool_manager == null:
		return
	
	# 查找匹配类型的死亡敌人
	var to_return: Array[Node2D] = []
	for enemy in _active_enemies:
		if not is_instance_valid(enemy):
			continue
		var is_dead: bool = enemy.get("_is_dead") if enemy.get("_is_dead") != null else false
		if not is_dead:
			continue
		var from_pool: bool = enemy.get_meta("from_pool", false)
		var pool_type: String = enemy.get_meta("pool_type", "")
		if from_pool and pool_type == enemy_type:
			to_return.append(enemy)
	
	for enemy in to_return:
		_active_enemies.erase(enemy)
		_pool_manager.release_enemy(enemy_type, enemy)

## 获取对象池统计信息（供性能监控使用）
func get_pool_stats() -> Dictionary:
	if _pool_manager and _pool_manager.has_method("get_all_stats"):
		return _pool_manager.get_all_stats()
	return {}
