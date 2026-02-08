## boss_spawner.gd
## Boss 生成管理器 (Issue #27)
## 负责 Boss 的生成时机、入场动画、Boss 战流程管理
## 与 EnemySpawner 协作，在特定条件下触发 Boss 战
##
## Boss 生成条件：
## - 每 5 波（Wave 5, 10, 15...）触发 Boss 战
## - Boss 战期间暂停普通敌人生成
## - Boss 击败后恢复正常流程并给予奖励
extends Node

# ============================================================
# 信号
# ============================================================
signal boss_fight_started(boss_name: String)
signal boss_fight_ended(boss_name: String, victory: bool)
signal boss_spawned(boss: Node)

# ============================================================
# 配置
# ============================================================
## Boss 生成的波次间隔
@export var boss_wave_interval: int = 5

## Boss 入场动画时间
@export var boss_intro_duration: float = 3.0

## Boss 生成距离（相对于玩家）
@export var boss_spawn_distance: float = 400.0

# ============================================================
# Boss 场景注册
# ============================================================
const BOSS_SCENES: Dictionary = {
	"conductor": "res://scenes/enemies/boss_dissonant_conductor.tscn",
	# 未来可以添加更多 Boss
	# "virtuoso": "res://scenes/enemies/boss_virtuoso.tscn",
}

## Boss 出现顺序（循环）
const BOSS_ORDER: Array = ["conductor"]

# ============================================================
# 内部状态
# ============================================================
var _cached_boss_scenes: Dictionary = {}
var _current_boss: Node = null
var _boss_fight_active: bool = false
var _boss_index: int = 0
var _boss_health_bar: Node = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_preload_boss_scenes()
	
	# 查找 Boss 血条 UI
	_boss_health_bar = get_tree().get_first_node_in_group("boss_health_bar")

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

## 检查当前波次是否为 Boss 波
func is_boss_wave(wave_number: int) -> bool:
	return wave_number > 0 and wave_number % boss_wave_interval == 0

## 是否正在进行 Boss 战
func is_boss_fight_active() -> bool:
	return _boss_fight_active

## 触发 Boss 生成
func spawn_boss(player_pos: Vector2) -> void:
	if _boss_fight_active:
		return
	
	# 选择 Boss
	var boss_key: String = BOSS_ORDER[_boss_index % BOSS_ORDER.size()]
	var scene: PackedScene = _cached_boss_scenes.get(boss_key)
	
	if scene == null:
		# 如果场景未加载，使用代码创建
		_spawn_boss_from_code(boss_key, player_pos)
		return
	
	var boss := scene.instantiate()
	_setup_boss(boss, player_pos, boss_key)

## 使用代码创建 Boss（当场景文件不存在时的后备方案）
func _spawn_boss_from_code(boss_key: String, player_pos: Vector2) -> void:
	var BossScript = load("res://scripts/entities/enemies/boss_dissonant_conductor.gd")
	if BossScript == null:
		push_error("BossSpawner: Cannot load boss script!")
		return
	
	var boss := CharacterBody2D.new()
	boss.set_script(BossScript)
	
	# 创建必要的子节点
	_create_boss_nodes(boss)
	
	_setup_boss(boss, player_pos, boss_key)

func _create_boss_nodes(boss: Node) -> void:
	# EnemyVisual
	var visual := Polygon2D.new()
	visual.name = "EnemyVisual"
	# Boss 使用更大的多边形
	var points := PackedVector2Array()
	for i in range(6):
		var angle := (TAU / 6) * i - PI / 2.0
		var r := 28.0 if i % 2 == 0 else 20.0
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

func _setup_boss(boss: Node, player_pos: Vector2, boss_key: String) -> void:
	_boss_fight_active = true
	_current_boss = boss
	
	# 计算生成位置
	var angle := randf() * TAU
	var spawn_pos := player_pos + Vector2.from_angle(angle) * boss_spawn_distance
	boss.global_position = spawn_pos
	
	# 难度缩放
	var difficulty_mult := 1.0 + (_boss_index * 0.3)
	if boss.has_method("set"):
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

# ============================================================
# Boss 入场动画
# ============================================================

func _play_boss_intro(boss: Node) -> void:
	# Boss 入场时短暂无敌
	boss.set_physics_process(false)
	
	var visual := boss.get_node_or_null("EnemyVisual")
	if visual:
		# 从透明到可见
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
		# 无视觉节点，直接启用
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
	# 由 enemy_died 信号触发
	pass

func _on_boss_phase_changed(phase_index: int, phase_name: String) -> void:
	# 可以在这里触发全局效果（如屏幕闪烁、BGM 切换等）
	pass

func _on_boss_summon_minions(count: int, type: String) -> void:
	# 通知 EnemySpawner 生成小兵
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
		# 给予奖励
		_grant_boss_rewards()
	
	_current_boss = null
	boss_fight_ended.emit(boss_display_name, victory)

func _grant_boss_rewards() -> void:
	# Boss 击败奖励
	# 1. 大量经验值（已通过 enemy_died 信号处理）
	# 2. 共鸣碎片（局外货币，通过 MetaProgressionManager 处理）
	var meta_mgr := get_node_or_null("/root/MetaProgressionManager")
	if meta_mgr and meta_mgr.has_method("add_resonance_fragments"):
		var fragments := 50 + _boss_index * 10
		meta_mgr.add_resonance_fragments(fragments)

# ============================================================
# 获取当前 Boss
# ============================================================

func get_current_boss() -> Node:
	return _current_boss
