## enemy_spawner.gd
## 敌人生成管理器
## 控制敌人波次、生成频率和难度递增
extends Node2D

# ============================================================
# 信号
# ============================================================
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)

# ============================================================
# 配置
# ============================================================
@export var spawn_radius: float = 600.0
@export var min_spawn_distance: float = 300.0
@export var base_spawn_interval: float = 2.0
@export var max_enemies_on_screen: int = 100

## 难度递增
@export var difficulty_scale_time: float = 60.0  # 每60秒难度增加一级
@export var hp_scale_per_level: float = 1.2
@export var speed_scale_per_level: float = 1.05
@export var spawn_rate_scale: float = 0.9  # 生成间隔缩短

# ============================================================
# 敌人预制场景路径
# ============================================================
## 在实际项目中，这些会是 PackedScene 引用
## 目前使用脚本动态创建
const ENEMY_TYPES := {
	"basic": {
		"hp": 30.0,
		"speed": 80.0,
		"damage": 8.0,
		"xp": 3,
		"color": Color(1.0, 0.2, 0.3),
		"size": 12.0,
	},
	"fast": {
		"hp": 15.0,
		"speed": 150.0,
		"damage": 5.0,
		"xp": 2,
		"color": Color(1.0, 0.5, 0.0),
		"size": 8.0,
	},
	"tank": {
		"hp": 100.0,
		"speed": 40.0,
		"damage": 20.0,
		"xp": 10,
		"color": Color(0.6, 0.0, 0.8),
		"size": 20.0,
	},
	"swarm": {
		"hp": 10.0,
		"speed": 100.0,
		"damage": 3.0,
		"xp": 1,
		"color": Color(0.8, 0.8, 0.0),
		"size": 6.0,
	},
}

# ============================================================
# 状态
# ============================================================
var _spawn_timer: float = 0.0
var _current_spawn_interval: float = 2.0
var _difficulty_level: int = 0
var _total_enemies_spawned: int = 0
var _active_enemies: Array[Node2D] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_current_spawn_interval = base_spawn_interval

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# 更新难度
	_update_difficulty()

	# 生成计时
	_spawn_timer += delta
	if _spawn_timer >= _current_spawn_interval:
		_spawn_timer = 0.0
		_spawn_wave()

	# 清理无效引用
	_cleanup_dead_enemies()

# ============================================================
# 难度系统
# ============================================================

func _update_difficulty() -> void:
	var new_level := int(GameManager.game_time / difficulty_scale_time)
	if new_level != _difficulty_level:
		_difficulty_level = new_level
		_current_spawn_interval = base_spawn_interval * pow(spawn_rate_scale, _difficulty_level)
		_current_spawn_interval = max(_current_spawn_interval, 0.3)  # 最小间隔

# ============================================================
# 生成逻辑
# ============================================================

func _spawn_wave() -> void:
	if _active_enemies.size() >= max_enemies_on_screen:
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	# 根据难度决定生成数量和类型
	var spawn_count := _get_spawn_count()
	var enemy_type := _get_enemy_type()

	for i in range(spawn_count):
		_spawn_enemy(player.global_position, enemy_type)

func _spawn_enemy(player_pos: Vector2, type_name: String) -> void:
	var type_data: Dictionary = ENEMY_TYPES.get(type_name, ENEMY_TYPES["basic"])

	# 在玩家周围随机位置生成
	var angle := randf() * TAU
	var distance := randf_range(min_spawn_distance, spawn_radius)
	var spawn_pos := player_pos + Vector2.from_angle(angle) * distance

	# 创建敌人节点
	var enemy := CharacterBody2D.new()
	enemy.set_script(load("res://scripts/entities/enemy_base.gd"))

	# 设置属性（应用难度缩放）
	var hp_scale := pow(hp_scale_per_level, _difficulty_level)
	var speed_scale := pow(speed_scale_per_level, _difficulty_level)

	enemy.max_hp = type_data["hp"] * hp_scale
	enemy.move_speed = type_data["speed"] * speed_scale
	enemy.contact_damage = type_data["damage"] * hp_scale
	enemy.xp_value = type_data["xp"]

	# 创建视觉节点
	var visual := _create_enemy_visual(type_data)
	visual.name = "EnemyVisual"
	enemy.add_child(visual)

	# 创建碰撞形状
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = type_data["size"]
	collision.shape = shape
	enemy.add_child(collision)

	# 创建伤害区域
	var damage_area := Area2D.new()
	damage_area.name = "DamageArea"
	var damage_collision := CollisionShape2D.new()
	var damage_shape := CircleShape2D.new()
	damage_shape.radius = type_data["size"] + 4.0
	damage_collision.shape = damage_shape
	damage_area.add_child(damage_collision)
	enemy.add_child(damage_area)

	enemy.global_position = spawn_pos
	add_child(enemy)
	_active_enemies.append(enemy)
	_total_enemies_spawned += 1

	# 连接死亡信号
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died)

func _create_enemy_visual(type_data: Dictionary) -> Node2D:
	# 使用 Polygon2D 创建锯齿状碎片造型
	var visual := Polygon2D.new()
	var size: float = type_data["size"]

	# 生成不规则多边形（锯齿状）
	var points: PackedVector2Array = PackedVector2Array()
	var num_points := randi_range(5, 8)
	for i in range(num_points):
		var angle := (TAU / num_points) * i
		var radius := size * randf_range(0.7, 1.3)
		points.append(Vector2.from_angle(angle) * radius)

	visual.polygon = points
	visual.color = type_data["color"]

	return visual

# ============================================================
# 生成参数
# ============================================================

func _get_spawn_count() -> int:
	var base_count := 1
	if _difficulty_level >= 2:
		base_count = 2
	if _difficulty_level >= 5:
		base_count = 3
	if _difficulty_level >= 8:
		base_count = randi_range(3, 5)

	# 偶尔生成大群
	if randf() < 0.1:
		base_count += randi_range(3, 6)

	return base_count

func _get_enemy_type() -> String:
	var roll := randf()

	if _difficulty_level < 2:
		return "basic"
	elif _difficulty_level < 4:
		if roll < 0.7:
			return "basic"
		elif roll < 0.9:
			return "fast"
		else:
			return "swarm"
	elif _difficulty_level < 7:
		if roll < 0.4:
			return "basic"
		elif roll < 0.6:
			return "fast"
		elif roll < 0.8:
			return "tank"
		else:
			return "swarm"
	else:
		# 后期：更多精英
		if roll < 0.3:
			return "basic"
		elif roll < 0.5:
			return "fast"
		elif roll < 0.7:
			return "tank"
		else:
			return "swarm"

# ============================================================
# 敌人管理
# ============================================================

func _on_enemy_died(pos: Vector2, xp: int) -> void:
	GameManager.add_xp(xp)
	_spawn_xp_pickup(pos, xp)

func _spawn_xp_pickup(pos: Vector2, value: int) -> void:
	# 生成经验值拾取物（音符符号）
	var pickup := Area2D.new()
	pickup.add_to_group("xp_pickup")
	pickup.set_meta("xp_value", value)

	var visual := Polygon2D.new()
	# 小型正四面体形状
	visual.polygon = PackedVector2Array([
		Vector2(0, -5), Vector2(4, 3), Vector2(-4, 3)
	])
	visual.color = Color(0.0, 1.0, 0.8, 0.8)
	pickup.add_child(visual)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 15.0  # 较大的拾取范围
	col.shape = shape
	pickup.add_child(col)

	pickup.global_position = pos
	add_child(pickup)

	# 自动吸引到玩家
	var tween := create_tween()
	tween.set_loops()
	tween.tween_callback(func():
		var player = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(pickup):
			var dir = (player.global_position - pickup.global_position).normalized()
			pickup.global_position += dir * 200.0 * get_process_delta_time()
			if pickup.global_position.distance_to(player.global_position) < 20.0:
				GameManager.add_xp(value)
				pickup.queue_free()
	).set_delay(0.016)

	# 10秒后自动消失
	get_tree().create_timer(10.0).timeout.connect(func():
		if is_instance_valid(pickup):
			pickup.queue_free()
	)

func _cleanup_dead_enemies() -> void:
	_active_enemies = _active_enemies.filter(func(e): return is_instance_valid(e))

## 获取所有活跃敌人的碰撞数据
func get_enemy_collision_data() -> Array:
	var data: Array = []
	for enemy in _active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("get_collision_data"):
			data.append(enemy.get_collision_data())
	return data

## 获取活跃敌人数量
func get_active_enemy_count() -> int:
	return _active_enemies.size()
