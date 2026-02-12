## obstacle_spawner.gd
## 障碍物生成管理器 (Issue #54)
## 在关卡中动态生成"固化静默"玄武岩柱体障碍物。
## 与 ChapterManager 和 EnemySpawner 协作，根据章节配置和波次类型
## 在战场上放置障碍物，增加空间策略深度。
##
## 生成规则：
##   - 每个章节开始时，根据章节配置生成初始障碍物
##   - 特定波次（如 SILENCE_TIDE）会额外生成障碍物
##   - 障碍物不会生成在玩家或敌人附近
##   - 障碍物有最大数量限制
##   - 部分障碍物可被摧毁（高血量但可击碎）
extends Node2D

# ============================================================
# 信号
# ============================================================
signal obstacle_spawned(obstacle: Node, position: Vector2)
signal obstacle_destroyed(position: Vector2)
signal obstacles_cleared()

# ============================================================
# 配置
# ============================================================
## 障碍物场景路径
const OBSTACLE_SCENE_PATH: String = "res://scenes/obstacle.tscn"

## 最大同时存在的障碍物数量
@export var max_obstacles: int = 15

## 障碍物与玩家的最小距离
@export var min_distance_from_player: float = 150.0

## 障碍物之间的最小距离
@export var min_distance_between_obstacles: float = 80.0

## 战场范围（正方形半径）
@export var arena_radius: float = 800.0

# ============================================================
# 章节障碍物配置
# ============================================================
## 每个章节的障碍物生成配置
const CHAPTER_OBSTACLE_CONFIG: Dictionary = {
	0: {  # 第一章：毕达哥拉斯 — 几何对称布局
		"initial_count": 4,
		"pattern": "symmetric",
		"can_crystallize": false,
		"obstacle_hp": 0,  # 0 = 不可摧毁
	},
	1: {  # 第二章：圭多 — 四线谱布局
		"initial_count": 6,
		"pattern": "lines",
		"can_crystallize": false,
		"obstacle_hp": 0,
	},
	2: {  # 第三章：巴赫 — 迷宫式布局
		"initial_count": 8,
		"pattern": "maze",
		"can_crystallize": true,
		"obstacle_hp": 150,
	},
	3: {  # 第四章：莫扎特 — 优雅散布
		"initial_count": 5,
		"pattern": "elegant",
		"can_crystallize": false,
		"obstacle_hp": 0,
	},
	4: {  # 第五章：贝多芬 — 厚重壁垒
		"initial_count": 7,
		"pattern": "fortress",
		"can_crystallize": true,
		"obstacle_hp": 200,
	},
	5: {  # 第六章：爵士 — 随机散布
		"initial_count": 6,
		"pattern": "scattered",
		"can_crystallize": false,
		"obstacle_hp": 0,
	},
	6: {  # 第七章：噪声 — 密集混乱
		"initial_count": 10,
		"pattern": "chaotic",
		"can_crystallize": true,
		"obstacle_hp": 100,
	},
}

# ============================================================
# 内部状态
# ============================================================
var _obstacle_scene: PackedScene = null
var _active_obstacles: Array[Node2D] = []
var _current_chapter: int = -1
var _crystallize_script = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_to_group("obstacle_spawner")
	_preload_resources()
	_connect_signals()

func _preload_resources() -> void:
	_obstacle_scene = load(OBSTACLE_SCENE_PATH) as PackedScene
	if _obstacle_scene == null:
		push_warning("ObstacleSpawner: Failed to load obstacle scene: %s" % OBSTACLE_SCENE_PATH)
	
	var crystal_script = load("res://scripts/systems/crystallized_obstacle.gd")
	if crystal_script:
		_crystallize_script = crystal_script

func _connect_signals() -> void:
	# 连接 ChapterManager 信号
	var chapter_mgr := get_node_or_null("/root/ChapterManager")
	if chapter_mgr:
		if chapter_mgr.has_signal("chapter_started"):
			chapter_mgr.chapter_started.connect(_on_chapter_started)
		if chapter_mgr.has_signal("chapter_completed"):
			chapter_mgr.chapter_completed.connect(_on_chapter_completed)

# ============================================================
# 章节事件处理
# ============================================================

func _on_chapter_started(chapter_index: int, _chapter_name: String = "") -> void:
	_current_chapter = chapter_index
	clear_all_obstacles()
	_generate_chapter_obstacles(chapter_index)

func _on_chapter_completed(_chapter_index: int, _rewards: Dictionary = {}) -> void:
	# 章节结束时清除所有障碍物
	clear_all_obstacles()

# ============================================================
# 障碍物生成
# ============================================================

## 根据章节配置生成障碍物
func _generate_chapter_obstacles(chapter_index: int) -> void:
	var config: Dictionary = CHAPTER_OBSTACLE_CONFIG.get(chapter_index, {})
	if config.is_empty():
		return
	
	var count: int = config.get("initial_count", 4)
	var pattern: String = config.get("pattern", "scattered")
	var can_crystallize: bool = config.get("can_crystallize", false)
	var obstacle_hp: int = config.get("obstacle_hp", 0)
	
	var positions := _generate_positions(count, pattern)
	
	for pos in positions:
		_spawn_obstacle_at(pos, can_crystallize, obstacle_hp)

## 在波次中动态添加障碍物
func spawn_wave_obstacles(count: int, near_position: Vector2 = Vector2.ZERO) -> void:
	if _active_obstacles.size() >= max_obstacles:
		return
	
	var remaining := max_obstacles - _active_obstacles.size()
	count = min(count, remaining)
	
	for i in range(count):
		var angle := randf() * TAU
		var dist := randf_range(100.0, 300.0)
		var pos := near_position + Vector2.from_angle(angle) * dist
		pos = _clamp_to_arena(pos)
		
		if _is_valid_spawn_position(pos):
			_spawn_obstacle_at(pos, false, 0)

## 在指定位置生成单个障碍物
func _spawn_obstacle_at(pos: Vector2, can_crystallize: bool, hp: int) -> void:
	if _obstacle_scene == null:
		return
	if _active_obstacles.size() >= max_obstacles:
		return
	
	var obstacle := _obstacle_scene.instantiate() as StaticBody2D
	if obstacle == null:
		return
	
	obstacle.global_position = pos
	
	# 设置可摧毁属性
	if hp > 0:
		obstacle.set_meta("destructible", true)
		obstacle.set_meta("obstacle_hp", hp)
		obstacle.set_meta("max_obstacle_hp", hp)
	
	# 应用固化静默效果
	if can_crystallize and _crystallize_script:
		var sprite := obstacle.get_node_or_null("Sprite2D")
		if sprite:
			var crystal = _crystallize_script.new()
			sprite.add_child(crystal)
			# 延迟启动石化效果
			crystal.call_deferred("set_crystallized")
	
	add_child(obstacle)
	_active_obstacles.append(obstacle)
	obstacle_spawned.emit(obstacle, pos)

# ============================================================
# 位置生成策略
# ============================================================

func _generate_positions(count: int, pattern: String) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	
	match pattern:
		"symmetric":
			positions = _pattern_symmetric(count)
		"lines":
			positions = _pattern_lines(count)
		"maze":
			positions = _pattern_maze(count)
		"elegant":
			positions = _pattern_elegant(count)
		"fortress":
			positions = _pattern_fortress(count)
		"scattered":
			positions = _pattern_scattered(count)
		"chaotic":
			positions = _pattern_chaotic(count)
		_:
			positions = _pattern_scattered(count)
	
	return positions

## 对称布局（第一章）
func _pattern_symmetric(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var radius := arena_radius * 0.5
	for i in range(count):
		var angle := (TAU / count) * i
		var pos := Vector2.from_angle(angle) * radius
		if _is_valid_spawn_position(pos):
			positions.append(pos)
	return positions

## 线条布局（第二章 — 模拟四线谱）
func _pattern_lines(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var line_count := 4
	var spacing := arena_radius * 0.3
	var per_line := count / line_count + 1
	
	for line in range(line_count):
		var y := (line - line_count / 2.0 + 0.5) * spacing
		for col in range(per_line):
			if positions.size() >= count:
				break
			var x := (col - per_line / 2.0 + 0.5) * 120.0
			var pos := Vector2(x, y)
			if _is_valid_spawn_position(pos):
				positions.append(pos)
	return positions

## 迷宫布局（第三章）
func _pattern_maze(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var grid_size := 3
	var cell_size := arena_radius * 0.4
	
	for row in range(grid_size):
		for col in range(grid_size):
			if positions.size() >= count:
				break
			# 棋盘格式跳过
			if (row + col) % 2 == 0:
				continue
			var x := (col - grid_size / 2.0 + 0.5) * cell_size
			var y := (row - grid_size / 2.0 + 0.5) * cell_size
			var pos := Vector2(x, y)
			if _is_valid_spawn_position(pos):
				positions.append(pos)
	
	# 补充不够的位置
	while positions.size() < count:
		var pos := Vector2(randf_range(-arena_radius * 0.6, arena_radius * 0.6),
						   randf_range(-arena_radius * 0.6, arena_radius * 0.6))
		if _is_valid_spawn_position(pos):
			positions.append(pos)
	
	return positions

## 优雅散布（第四章）
func _pattern_elegant(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	# 黄金螺旋布局
	var golden_angle := PI * (3.0 - sqrt(5.0))
	for i in range(count):
		var r := arena_radius * 0.3 * sqrt(float(i + 1) / float(count))
		var theta := golden_angle * i
		var pos := Vector2.from_angle(theta) * r
		if _is_valid_spawn_position(pos):
			positions.append(pos)
	return positions

## 堡垒布局（第五章）
func _pattern_fortress(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	# 内外两圈
	var inner_count := count / 2
	var outer_count := count - inner_count
	
	for i in range(inner_count):
		var angle := (TAU / inner_count) * i
		var pos := Vector2.from_angle(angle) * arena_radius * 0.25
		if _is_valid_spawn_position(pos):
			positions.append(pos)
	
	for i in range(outer_count):
		var angle := (TAU / outer_count) * i + PI / outer_count
		var pos := Vector2.from_angle(angle) * arena_radius * 0.55
		if _is_valid_spawn_position(pos):
			positions.append(pos)
	
	return positions

## 随机散布（第六章）
func _pattern_scattered(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var attempts := 0
	while positions.size() < count and attempts < count * 10:
		var pos := Vector2(randf_range(-arena_radius * 0.7, arena_radius * 0.7),
						   randf_range(-arena_radius * 0.7, arena_radius * 0.7))
		if _is_valid_spawn_position(pos):
			var too_close := false
			for existing in positions:
				if pos.distance_to(existing) < min_distance_between_obstacles:
					too_close = true
					break
			if not too_close:
				positions.append(pos)
		attempts += 1
	return positions

## 混乱布局（第七章）
func _pattern_chaotic(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for i in range(count):
		var angle := randf() * TAU
		var dist := randf_range(arena_radius * 0.15, arena_radius * 0.65)
		var pos := Vector2.from_angle(angle) * dist
		# 添加随机偏移
		pos += Vector2(randf_range(-40, 40), randf_range(-40, 40))
		if _is_valid_spawn_position(pos):
			positions.append(pos)
	return positions

# ============================================================
# 位置验证
# ============================================================

func _is_valid_spawn_position(pos: Vector2) -> bool:
	# 检查是否在战场范围内
	if pos.length() > arena_radius:
		return false
	
	# 检查与玩家的距离
	var player := get_tree().get_first_node_in_group("player")
	if player and pos.distance_to(player.global_position) < min_distance_from_player:
		return false
	
	# 检查与现有障碍物的距离
	for obstacle in _active_obstacles:
		if is_instance_valid(obstacle) and pos.distance_to(obstacle.global_position) < min_distance_between_obstacles:
			return false
	
	return true

func _clamp_to_arena(pos: Vector2) -> Vector2:
	if pos.length() > arena_radius * 0.8:
		return pos.normalized() * arena_radius * 0.8
	return pos

# ============================================================
# 障碍物管理
# ============================================================

## 处理障碍物受击（可摧毁的障碍物）
func damage_obstacle(obstacle: Node, amount: float) -> void:
	if not obstacle.get_meta("destructible", false):
		return
	
	var hp: float = obstacle.get_meta("obstacle_hp", 0)
	hp -= amount
	obstacle.set_meta("obstacle_hp", hp)
	
	if hp <= 0:
		_destroy_obstacle(obstacle)

func _destroy_obstacle(obstacle: Node) -> void:
	var pos: Vector2 = obstacle.global_position
	_active_obstacles.erase(obstacle)
	
	# 播放销毁动画
	var visual := obstacle.get_node_or_null("Sprite2D")
	if visual:
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func():
			if is_instance_valid(obstacle):
				obstacle.queue_free()
		)
	else:
		obstacle.queue_free()
	
	obstacle_destroyed.emit(pos)

## 清除所有障碍物
func clear_all_obstacles() -> void:
	for obstacle in _active_obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	_active_obstacles.clear()
	obstacles_cleared.emit()

## 获取活跃障碍物数量
func get_active_count() -> int:
	_active_obstacles = _active_obstacles.filter(func(o): return is_instance_valid(o))
	return _active_obstacles.size()

## 获取所有障碍物位置（供 AI 寻路使用）
func get_obstacle_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for obstacle in _active_obstacles:
		if is_instance_valid(obstacle):
			positions.append(obstacle.global_position)
	return positions
