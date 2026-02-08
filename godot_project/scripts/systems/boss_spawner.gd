## boss_spawner.gd
## Boss 生成管理器 v2.0 — 章节系统集成版
## 负责 Boss 的生成时机、入场动画、Boss 战流程管理。
## 与 ChapterManager 协作，根据当前章节配置生成对应的最终 Boss。
##
## 两种模式：
##   - 传统模式：每 N 波触发 Boss 战
##   - 章节模式：由 ChapterManager 触发，生成章节对应 Boss
extends Node

# ============================================================
# 信号
# ============================================================
signal boss_fight_started(boss_name: String)
signal boss_fight_ended(boss_name: String, victory: bool)
signal boss_spawned(boss: Node)
signal boss_intro_started(boss_name: String)
signal boss_intro_completed(boss_name: String)

# ============================================================
# 配置
# ============================================================
## Boss 生成的波次间隔（传统模式）
@export var boss_wave_interval: int = 5
## Boss 入场动画时间
@export var boss_intro_duration: float = 3.0
## Boss 生成距离（相对于玩家）
@export var boss_spawn_distance: float = 400.0
## Boss 战前清场延迟
@export var pre_boss_clear_delay: float = 2.0
## Boss 战前警告持续时间
@export var boss_warning_duration: float = 3.0

# ============================================================
# Boss 场景注册（传统模式后备）
# ============================================================
const BOSS_SCENES: Dictionary = {
	"conductor": "res://scenes/enemies/boss_dissonant_conductor.tscn",
}

## Boss 出现顺序（传统模式循环）
const BOSS_ORDER: Array = ["conductor"]

# ============================================================
# 章节 Boss 脚本路径（由 ChapterData 定义，这里缓存）
# ============================================================
var _cached_boss_scripts: Dictionary = {}

# ============================================================
# 内部状态
# ============================================================
var _cached_boss_scenes: Dictionary = {}
var _current_boss: Node = null
var _boss_fight_active: bool = false
var _boss_index: int = 0
var _boss_health_bar: Node = null

## 章节模式
var _chapter_mode: bool = false
var _current_chapter_index: int = -1

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_preload_boss_scenes()
	_boss_health_bar = get_tree().get_first_node_in_group("boss_health_bar")
	
	# 连接 ChapterManager 信号
	var chapter_mgr := get_node_or_null("/root/ChapterManager")
	if chapter_mgr:
		if chapter_mgr.has_signal("boss_wave_triggered"):
			chapter_mgr.boss_wave_triggered.connect(_on_chapter_boss_triggered)

func _preload_boss_scenes() -> void:
	for boss_name in BOSS_SCENES:
		var scene := load(BOSS_SCENES[boss_name]) as PackedScene
		if scene:
			_cached_boss_scenes[boss_name] = scene
		else:
			push_warning("BossSpawner: Failed to load boss scene: %s" % BOSS_SCENES[boss_name])

# ============================================================
# 公共接口
# ============================================================

func is_boss_wave(wave_number: int) -> bool:
	return wave_number > 0 and wave_number % boss_wave_interval == 0

func is_boss_fight_active() -> bool:
	return _boss_fight_active

func get_current_boss() -> Node:
	return _current_boss

## 传统模式：触发 Boss 生成
func spawn_boss(player_pos: Vector2) -> void:
	if _boss_fight_active:
		return
	
	var boss_key: String = BOSS_ORDER[_boss_index % BOSS_ORDER.size()]
	var scene: PackedScene = _cached_boss_scenes.get(boss_key)
	
	if scene == null:
		_spawn_boss_from_code(boss_key, player_pos)
		return
	
	var boss := scene.instantiate()
	_setup_boss(boss, player_pos, boss_key)

## 章节模式：由 ChapterManager 触发
func spawn_chapter_boss(chapter_index: int, boss_config: Dictionary) -> void:
	if _boss_fight_active:
		return
	
	_chapter_mode = true
	_current_chapter_index = chapter_index
	
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("BossSpawner: No player found!")
		return
	
	var boss_key: String = boss_config.get("key", "")
	var script_path: String = boss_config.get("script_path", "")
	
	# 先播放Boss战警告
	_play_boss_warning(boss_key, func():
		# 警告结束后生成Boss
		_spawn_chapter_boss_instance(boss_key, script_path, player.global_position)
	)

# ============================================================
# 章节Boss触发处理
# ============================================================

func _on_chapter_boss_triggered(chapter_index: int, boss_key: String) -> void:
	var config := ChapterData.get_chapter_config(chapter_index)
	var boss_config: Dictionary = config.get("boss", {})
	spawn_chapter_boss(chapter_index, boss_config)

func _spawn_chapter_boss_instance(boss_key: String, script_path: String, player_pos: Vector2) -> void:
	var boss: CharacterBody2D = null
	
	# 尝试加载Boss脚本
	var script = _cached_boss_scripts.get(boss_key)
	if script == null and script_path != "":
		script = load(script_path)
		if script:
			_cached_boss_scripts[boss_key] = script
	
	if script:
		boss = CharacterBody2D.new()
		boss.set_script(script)
		_create_boss_nodes(boss)
	else:
		# 后备：尝试场景
		var scene: PackedScene = _cached_boss_scenes.get(boss_key)
		if scene:
			boss = scene.instantiate() as CharacterBody2D
	
	if boss == null:
		push_error("BossSpawner: Cannot create boss: %s" % boss_key)
		return
	
	_setup_boss(boss, player_pos, boss_key)

# ============================================================
# Boss 战警告
# ============================================================

func _play_boss_warning(boss_key: String, on_complete: Callable) -> void:
	boss_intro_started.emit(boss_key)
	
	# 通知 EnemySpawner 进入Boss阶段
	var spawner := get_tree().get_first_node_in_group("enemy_spawner")
	if spawner and spawner.has_method("enter_boss_phase"):
		spawner.enter_boss_phase()
	
	# 警告期间等待
	get_tree().create_timer(boss_warning_duration).timeout.connect(func():
		boss_intro_completed.emit(boss_key)
		on_complete.call()
	)

# ============================================================
# Boss 设置（通用）
# ============================================================

func _setup_boss(boss: Node, player_pos: Vector2, boss_key: String) -> void:
	_boss_fight_active = true
	_current_boss = boss
	
	# 计算生成位置
	var angle := randf() * TAU
	var spawn_pos := player_pos + Vector2.from_angle(angle) * boss_spawn_distance
	boss.global_position = spawn_pos
	
	# 难度缩放
	var difficulty_mult := 1.0 + (_boss_index * 0.3)
	if _chapter_mode:
		difficulty_mult += _current_chapter_index * 0.2
		var chapter_mgr := get_node_or_null("/root/ChapterManager")
		if chapter_mgr and chapter_mgr.has_method("get_global_difficulty"):
			difficulty_mult += chapter_mgr.get_global_difficulty() * 0.15
	
	var base_hp: float = boss.get("max_hp") if boss.get("max_hp") else 5000.0
	boss.set("max_hp", base_hp * difficulty_mult)
	boss.set("current_hp", base_hp * difficulty_mult)
	
	# 添加到场景
	add_child(boss)
	
	# 连接信号
	if boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)
	if boss.has_signal("boss_phase_changed"):
		boss.boss_phase_changed.connect(_on_boss_phase_changed)
	if boss.has_signal("enemy_died"):
		boss.enemy_died.connect(_on_boss_died)
	if boss.has_signal("boss_summon_minions"):
		boss.boss_summon_minions.connect(_on_boss_summon_minions)
	
	# 入场动画
	_play_boss_intro(boss)
	
	# 显示 Boss 血条
	if _boss_health_bar and _boss_health_bar.has_method("show_boss_bar"):
		_boss_health_bar.show_boss_bar(boss)
	
	boss_spawned.emit(boss)
	
	var boss_display_name: String = boss.get("boss_name") if boss.get("boss_name") else boss_key
	boss_fight_started.emit(boss_display_name)

func _spawn_boss_from_code(boss_key: String, player_pos: Vector2) -> void:
	var BossScript = load("res://scripts/entities/enemies/boss_dissonant_conductor.gd")
	if BossScript == null:
		push_error("BossSpawner: Cannot load boss script!")
		return
	
	var boss := CharacterBody2D.new()
	boss.set_script(BossScript)
	_create_boss_nodes(boss)
	_setup_boss(boss, player_pos, boss_key)

func _create_boss_nodes(boss: Node) -> void:
	# EnemyVisual（Boss用更大的多边形）
	var visual := Polygon2D.new()
	visual.name = "EnemyVisual"
	var points := PackedVector2Array()
	for i in range(8):
		var angle := (TAU / 8) * i - PI / 2.0
		var r := 32.0 if i % 2 == 0 else 24.0
		points.append(Vector2.from_angle(angle) * r)
	visual.polygon = points
	visual.color = Color(0.8, 0.2, 0.9)
	boss.add_child(visual)
	
	# CollisionShape2D
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 32.0
	col.shape = shape
	boss.add_child(col)
	
	# DamageArea
	var damage_area := Area2D.new()
	damage_area.name = "DamageArea"
	damage_area.collision_layer = 2
	damage_area.collision_mask = 1
	var da_col := CollisionShape2D.new()
	var da_shape := CircleShape2D.new()
	da_shape.radius = 36.0
	da_col.shape = da_shape
	damage_area.add_child(da_col)
	boss.add_child(damage_area)

# ============================================================
# Boss 入场动画
# ============================================================

func _play_boss_intro(boss: Node) -> void:
	boss.set_physics_process(false)
	
	var visual := boss.get_node_or_null("EnemyVisual")
	if visual:
		visual.modulate.a = 0.0
		visual.scale = Vector2(3.0, 3.0)
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(visual, "modulate:a", 1.0, boss_intro_duration * 0.5)
		tween.tween_property(visual, "scale", Vector2(1.0, 1.0), boss_intro_duration).set_ease(Tween.EASE_OUT)
		tween.chain()
		tween.tween_callback(func():
			boss.set_physics_process(true)
		)
	else:
		get_tree().create_timer(boss_intro_duration).timeout.connect(func():
			if is_instance_valid(boss):
				boss.set_physics_process(true)
		)

# ============================================================
# Boss 事件处理
# ============================================================

func _on_boss_defeated() -> void:
	_end_boss_fight(true)

func _on_boss_died(_pos: Vector2, _xp: int, _type: String) -> void:
	pass

func _on_boss_phase_changed(phase_index: int, phase_name: String) -> void:
	# 阶段切换时可以触发全局效果
	# 例如：屏幕闪烁、BGM 切换、生成额外小兵
	pass

func _on_boss_summon_minions(count: int, type: String) -> void:
	var spawner := get_tree().get_first_node_in_group("enemy_spawner")
	if spawner and spawner.has_method("spawn_minions_for_boss"):
		spawner.spawn_minions_for_boss(count, type, _current_boss.global_position)

func _end_boss_fight(victory: bool) -> void:
	_boss_fight_active = false
	
	var boss_display_name := ""
	if _current_boss and is_instance_valid(_current_boss):
		boss_display_name = _current_boss.get("boss_name") if _current_boss.get("boss_name") else "Boss"
	
	# 隐藏 Boss 血条
	if _boss_health_bar and _boss_health_bar.has_method("hide_boss_bar"):
		_boss_health_bar.hide_boss_bar()
	
	if victory:
		_boss_index += 1
		_grant_boss_rewards()
		
		# 章节模式：通知 ChapterManager Boss 已被击败
		if _chapter_mode:
			var chapter_mgr := get_node_or_null("/root/ChapterManager")
			if chapter_mgr and chapter_mgr.has_method("on_boss_defeated"):
				chapter_mgr.on_boss_defeated()
		
		# 通知 EnemySpawner 退出Boss阶段
		var spawner := get_tree().get_first_node_in_group("enemy_spawner")
		if spawner and spawner.has_method("exit_boss_phase"):
			spawner.exit_boss_phase()
	
	_current_boss = null
	boss_fight_ended.emit(boss_display_name, victory)

func _grant_boss_rewards() -> void:
	# Boss 击败奖励（基础）
	var meta_mgr := get_node_or_null("/root/MetaProgressionManager")
	if meta_mgr and meta_mgr.has_method("add_resonance_fragments"):
		var fragments := 50 + _boss_index * 10
		meta_mgr.add_resonance_fragments(fragments)
	elif SaveManager and SaveManager.has_method("add_resonance_fragments"):
		var fragments := 50 + _boss_index * 10
		SaveManager.add_resonance_fragments(fragments)
