## enemy_spawner.gd
## 敌人生成管理器 v2.0
## 基于波次系统和 BPM 节奏的敌人生成，使用 PackedScene 模板。
## 设计参考：Project Harmony 敌人系统设计方案 — "噪音分类学"
extends Node2D

# ============================================================
# 信号
# ============================================================
signal wave_started(wave_number: int, wave_type: String)
signal wave_completed(wave_number: int)
signal elite_spawned(enemy_type: String, position: Vector2)
signal spawn_count_changed(active: int, total_spawned: int)

# ============================================================
# 敌人场景预加载
# ============================================================
const ENEMY_SCENES: Dictionary = {
	"static":  "res://scenes/enemies/enemy_static.tscn",
	"silence": "res://scenes/enemies/enemy_silence.tscn",
	"screech": "res://scenes/enemies/enemy_screech.tscn",
	"pulse":   "res://scenes/enemies/enemy_pulse.tscn",
	"wall":    "res://scenes/enemies/enemy_wall.tscn",
}

## 缓存已加载的 PackedScene
var _loaded_scenes: Dictionary = {}

# ============================================================
# 生成配置
# ============================================================
@export var spawn_radius: float = 600.0
@export var min_spawn_distance: float = 350.0
@export var max_enemies_on_screen: int = 120

## 波次配置
@export var wave_duration: float = 20.0       ## 每波持续时间（秒）
@export var wave_rest_duration: float = 3.0   ## 波间休息时间（秒）
@export var base_enemies_per_wave: int = 8    ## 基础每波敌人数

## 难度递增
@export var difficulty_scale_time: float = 60.0
@export var hp_scale_per_level: float = 1.15
@export var speed_scale_per_level: float = 1.03
@export var damage_scale_per_level: float = 1.1
@export var spawn_count_scale: float = 1.12

# ============================================================
# 敌人类型数值表（基础值，与场景模板中的 @export 对应）
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
	NORMAL,       ## 普通混合波
	SWARM,        ## 蜂群波（大量 Static）
	ELITE,        ## 精英波（少量强敌）
	SILENCE_TIDE, ## 寂静潮（Silence + Static 护卫）
	PULSE_STORM,  ## 脉冲风暴（多个 Pulse 同步弹幕）
	BOSS_WAVE,    ## Boss 波（预留）
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
var _wave_spawn_budget: int = 0     ## 本波剩余生成预算
var _wave_spawn_timer: float = 0.0  ## 波内生成间隔计时

## BPM 节奏生成
var _beat_spawn_enabled: bool = true
var _beats_since_last_spawn: int = 0
var _spawn_every_n_beats: int = 2   ## 每 N 拍生成一批

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_preload_enemy_scenes()
	_connect_signals()
	# 首波延迟 2 秒开始
	_is_resting = true
	_wave_rest_timer = 2.0

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
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
# 场景预加载
# ============================================================

func _preload_enemy_scenes() -> void:
	for type_name in ENEMY_SCENES:
		var scene_path: String = ENEMY_SCENES[type_name]
		var scene := load(scene_path) as PackedScene
		if scene:
			_loaded_scenes[type_name] = scene
		else:
			push_warning("EnemySpawner: Failed to load scene: " + scene_path)

func _connect_signals() -> void:
	if not GameManager.beat_tick.is_connected(_on_global_beat):
		GameManager.beat_tick.connect(_on_global_beat)

# ============================================================
# 难度系统
# ============================================================

func _update_difficulty() -> void:
	var new_level := int(GameManager.game_time / difficulty_scale_time)
	if new_level != _difficulty_level:
		_difficulty_level = new_level

func _get_hp_scale() -> float:
	return pow(hp_scale_per_level, _difficulty_level)

func _get_speed_scale() -> float:
	return pow(speed_scale_per_level, _difficulty_level)

func _get_damage_scale() -> float:
	return pow(damage_scale_per_level, _difficulty_level)

func _get_wave_enemy_count() -> int:
	return int(base_enemies_per_wave * pow(spawn_count_scale, _difficulty_level))

# ============================================================
# 波次系统
# ============================================================

func _start_new_wave() -> void:
	_current_wave += 1
	_is_wave_active = true
	_is_resting = false
	_wave_timer = wave_duration
	_wave_spawn_timer = 0.0

	# 决定波次类型
	_current_wave_type = _determine_wave_type()
	_wave_spawn_budget = _get_wave_enemy_count()

	# 特殊波次调整
	match _current_wave_type:
		WaveType.SWARM:
			_wave_spawn_budget = int(_wave_spawn_budget * 2.5)
		WaveType.ELITE:
			_wave_spawn_budget = max(2, int(_wave_spawn_budget * 0.3))
		WaveType.SILENCE_TIDE:
			_wave_spawn_budget = int(_wave_spawn_budget * 0.8)
		WaveType.PULSE_STORM:
			_wave_spawn_budget = max(3, int(_wave_spawn_budget * 0.5))

	var wave_type_name := _get_wave_type_name(_current_wave_type)
	wave_started.emit(_current_wave, wave_type_name)

func _process_wave(delta: float) -> void:
	_wave_timer -= delta

	# 波次时间到或预算用完
	if _wave_timer <= 0.0 or (_wave_spawn_budget <= 0 and _active_enemies.size() == 0):
		_end_wave()
		return

	# 基于时间的持续生成（波内均匀分布）
	if _wave_spawn_budget > 0 and _active_enemies.size() < max_enemies_on_screen:
		var spawn_interval := wave_duration / float(_get_wave_enemy_count())
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
	# 前3波固定为普通波
	if _current_wave <= 3:
		return WaveType.NORMAL

	var roll := randf()

	# 每5波必出精英波
	if _current_wave % 5 == 0:
		return WaveType.ELITE

	# 每7波必出特殊波
	if _current_wave % 7 == 0:
		if _difficulty_level >= 3:
			return WaveType.SILENCE_TIDE
		else:
			return WaveType.SWARM

	# 随机波次类型
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
		WaveType.NORMAL:       return "normal"
		WaveType.SWARM:        return "swarm"
		WaveType.ELITE:        return "elite"
		WaveType.SILENCE_TIDE: return "silence_tide"
		WaveType.PULSE_STORM:  return "pulse_storm"
		WaveType.BOSS_WAVE:    return "boss"
		_:                     return "unknown"

# ============================================================
# BPM 节奏生成
# ============================================================

func _on_global_beat(_beat_index: int) -> void:
	if not _is_wave_active or not _beat_spawn_enabled:
		return

	_beats_since_last_spawn += 1

	# 每 N 拍在弱拍时刻生成敌人（与敌人的弱拍移动呼应）
	if _beats_since_last_spawn >= _spawn_every_n_beats:
		_beats_since_last_spawn = 0
		# 延迟半拍生成（弱拍时刻）
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
		_:
			return randi_range(1, 3)

func _select_enemy_type() -> String:
	match _current_wave_type:
		WaveType.SWARM:
			# 蜂群波：90% Static, 10% Screech
			return "static" if randf() < 0.9 else "screech"

		WaveType.ELITE:
			# 精英波：强敌为主
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
			# 寂静潮：Silence + Static 护卫
			return "silence" if randf() < 0.25 else "static"

		WaveType.PULSE_STORM:
			# 脉冲风暴：Pulse 为主 + 少量 Static
			return "pulse" if randf() < 0.6 else "static"

		_:
			# 普通波：基于难度的权重选择
			return _weighted_enemy_select()

func _weighted_enemy_select() -> String:
	# 收集当前难度可用的敌人类型
	var available: Array[Dictionary] = []
	var total_weight := 0.0

	for type_name in ENEMY_TYPE_DATA:
		var data: Dictionary = ENEMY_TYPE_DATA[type_name]
		if _difficulty_level >= data["min_difficulty"]:
			available.append({"name": type_name, "weight": data["weight"]})
			total_weight += data["weight"]

	if available.is_empty():
		return "static"

	# 加权随机选择
	var roll := randf() * total_weight
	var cumulative := 0.0
	for entry in available:
		cumulative += entry["weight"]
		if roll <= cumulative:
			return entry["name"]

	return available[-1]["name"]

# ============================================================
# 敌人实例化
# ============================================================

func _spawn_enemy(player_pos: Vector2, type_name: String) -> void:
	var scene: PackedScene = _loaded_scenes.get(type_name)
	if scene == null:
		push_warning("EnemySpawner: No scene loaded for type: " + type_name)
		return

	# 实例化场景
	var enemy := scene.instantiate() as CharacterBody2D
	if enemy == null:
		return

	# 计算生成位置
	var spawn_pos := _calculate_spawn_position(player_pos)
	enemy.global_position = spawn_pos

	# 应用难度缩放
	_apply_difficulty_scaling(enemy, type_name)

	# 精英标记（精英波中的敌人获得额外加成）
	if _current_wave_type == WaveType.ELITE:
		_apply_elite_bonus(enemy, type_name)

	# 添加到场景树
	add_child(enemy)
	_active_enemies.append(enemy)
	_total_enemies_spawned += 1

	# 连接信号
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died)

	spawn_count_changed.emit(_active_enemies.size(), _total_enemies_spawned)

func _calculate_spawn_position(player_pos: Vector2) -> Vector2:
	var angle := randf() * TAU
	var distance := randf_range(min_spawn_distance, spawn_radius)
	return player_pos + Vector2.from_angle(angle) * distance

func _apply_difficulty_scaling(enemy: CharacterBody2D, type_name: String) -> void:
	var base_data: Dictionary = ENEMY_TYPE_DATA.get(type_name, ENEMY_TYPE_DATA["static"])

	# 应用难度缩放到属性
	if enemy.has_method("set") or true:  # CharacterBody2D 总是有 set
		var scaled_hp := base_data["hp"] * _get_hp_scale()
		var scaled_speed := base_data["speed"] * _get_speed_scale()
		var scaled_damage := base_data["damage"] * _get_damage_scale()

		enemy.set("max_hp", scaled_hp)
		enemy.set("current_hp", scaled_hp)
		enemy.set("move_speed", scaled_speed)
		enemy.set("contact_damage", scaled_damage)

func _apply_elite_bonus(enemy: CharacterBody2D, type_name: String) -> void:
	# 精英加成：HP +50%, 伤害 +30%, 体型 +20%
	var current_hp: float = enemy.get("max_hp")
	enemy.set("max_hp", current_hp * 1.5)
	enemy.set("current_hp", current_hp * 1.5)

	var current_damage: float = enemy.get("contact_damage")
	enemy.set("contact_damage", current_damage * 1.3)

	# 精英视觉标记：稍大 + 颜色偏移
	var visual := enemy.get_node_or_null("EnemyVisual")
	if visual:
		visual.scale *= 1.2
		# 精英发光（金色边缘）
		visual.modulate = visual.modulate.lerp(Color(1.0, 0.85, 0.3), 0.3)

	elite_spawned.emit(type_name, enemy.global_position)

# ============================================================
# 敌人管理
# ============================================================

func _on_enemy_died(pos: Vector2, xp: int, enemy_type: String) -> void:
	GameManager.add_xp(xp)
	_spawn_xp_pickup(pos, xp, enemy_type)

func _cleanup_dead_enemies() -> void:
	_active_enemies = _active_enemies.filter(func(e): return is_instance_valid(e))

# ============================================================
# 经验值拾取物（基础版，XPPickup 系统会在后续完善）
# ============================================================

func _spawn_xp_pickup(pos: Vector2, value: int, _enemy_type: String) -> void:
	var pickup := Area2D.new()
	pickup.add_to_group("xp_pickup")
	pickup.set_meta("xp_value", value)
	pickup.collision_layer = 4
	pickup.collision_mask = 1

	# 视觉：小型正四面体
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0, -6), Vector2(5, 3), Vector2(-5, 3)
	])
	# 根据经验值大小调整颜色
	if value >= 10:
		visual.color = Color(1.0, 0.85, 0.2, 0.9)  # 金色（高价值）
	elif value >= 5:
		visual.color = Color(0.2, 0.8, 1.0, 0.9)    # 蓝色（中价值）
	else:
		visual.color = Color(0.0, 1.0, 0.8, 0.8)    # 青色（低价值）
	pickup.add_child(visual)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 15.0
	col.shape = shape
	pickup.add_child(col)

	pickup.global_position = pos

	# 生成时的弹出动画
	var offset := Vector2(randf_range(-20, 20), randf_range(-20, 20))
	pickup.global_position += offset

	add_child(pickup)

	# 延迟后开始吸引到玩家
	var attract_delay := 0.5
	get_tree().create_timer(attract_delay).timeout.connect(func():
		if not is_instance_valid(pickup):
			return
		_start_pickup_attraction(pickup, value)
	)

	# 15秒后自动消失
	get_tree().create_timer(15.0).timeout.connect(func():
		if is_instance_valid(pickup):
			# 淡出
			var vis := pickup.get_child(0) as Polygon2D
			if vis:
				var tween := pickup.create_tween()
				tween.tween_property(vis, "modulate:a", 0.0, 0.5)
				tween.tween_callback(pickup.queue_free)
			else:
				pickup.queue_free()
	)

func _start_pickup_attraction(pickup: Area2D, value: int) -> void:
	# 使用 process 回调进行吸引
	var attract_speed := 300.0
	var collect_distance := 25.0

	# 创建一个简单的 process 连接
	pickup.set_process(true)
	pickup.set_meta("attract_active", true)

	# 通过 tree_process_frame 信号实现持续吸引
	var callable := func():
		if not is_instance_valid(pickup):
			return
		var player = get_tree().get_first_node_in_group("player")
		if player == null or not is_instance_valid(player):
			return

		var dir := (player.global_position - pickup.global_position).normalized()
		var dist := pickup.global_position.distance_to(player.global_position)

		# 越近吸引越快
		var speed_mult := remap(dist, 0.0, 200.0, 3.0, 1.0)
		speed_mult = clamp(speed_mult, 1.0, 3.0)

		pickup.global_position += dir * attract_speed * speed_mult * get_process_delta_time()

		if dist < collect_distance:
			GameManager.add_xp(value)
			pickup.queue_free()

	get_tree().process_frame.connect(callable)

	# 当 pickup 被销毁时断开连接
	pickup.tree_exiting.connect(func():
		if get_tree().process_frame.is_connected(callable):
			get_tree().process_frame.disconnect(callable)
	)

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

func get_difficulty_level() -> int:
	return _difficulty_level

func is_wave_active() -> bool:
	return _is_wave_active

func get_wave_progress() -> float:
	if not _is_wave_active:
		return 0.0
	return 1.0 - (_wave_timer / wave_duration)
