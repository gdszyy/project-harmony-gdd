## spatial_hash.gd
## 空间哈希网格 — 高性能空间分区系统 (Issue #6)
## 用于替代 O(n×m) 暴力碰撞检测，将复杂度降低到接近 O(n+m)。
## 
## 设计思路：
## - 将游戏世界划分为固定大小的网格单元格
## - 每个对象根据其位置被分配到一个或多个单元格
## - 碰撞检测只在相邻单元格之间进行
## - 相比四叉树，空间哈希在对象分布均匀时性能更优，且实现更简洁
## - 适合 Project Harmony 的竞技场场景（固定大小、对象分布相对均匀）
class_name SpatialHash

# ============================================================
# 配置
# ============================================================
## 单元格大小（应大于最大碰撞体的直径）
var cell_size: float = 128.0

## 半个单元格大小（缓存，避免重复计算）
var _half_cell: float = 64.0

# ============================================================
# 内部数据
# ============================================================
## 哈希表：cell_key(int) -> Array of objects
var _grid: Dictionary = {}

## 对象到所在单元格的反向映射（用于快速移除）
var _object_cells: Dictionary = {}

## 当前帧的统计信息
var _total_objects: int = 0
var _total_cells: int = 0
var _max_objects_per_cell: int = 0

# ============================================================
# 初始化
# ============================================================

func _init(p_cell_size: float = 128.0) -> void:
	cell_size = p_cell_size
	_half_cell = cell_size / 2.0

# ============================================================
# 公共接口
# ============================================================

## 清空所有数据（每帧开始时调用）
func clear() -> void:
	_grid.clear()
	_object_cells.clear()
	_total_objects = 0
	_total_cells = 0
	_max_objects_per_cell = 0

## 插入一个点对象（如弹体）
func insert_point(object: Variant, position: Vector2) -> void:
	var key := _hash_position(position)
	_insert_to_cell(key, object)
	_total_objects += 1

## 插入一个有大小的对象（如敌人，可能跨越多个单元格）
func insert_aabb(object: Variant, position: Vector2, radius: float) -> void:
	var min_x := int(floor((position.x - radius) / cell_size))
	var max_x := int(floor((position.x + radius) / cell_size))
	var min_y := int(floor((position.y - radius) / cell_size))
	var max_y := int(floor((position.y + radius) / cell_size))
	
	var cells: Array[int] = []
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var key := _hash_cell(x, y)
			_insert_to_cell(key, object)
			cells.append(key)
	
	# 记录对象所在的所有单元格（用于后续查询优化）
	var obj_id = object.get_instance_id() if object is Object else hash(object)
	_object_cells[obj_id] = cells
	_total_objects += 1

## 查询指定位置附近的所有对象
func query_point(position: Vector2) -> Array:
	var key := _hash_position(position)
	return _grid.get(key, [])

## 查询指定区域内的所有对象（检查 3x3 邻域）
func query_area(position: Vector2, radius: float = 0.0) -> Array:
	var results: Array = []
	var seen: Dictionary = {}  # 去重
	
	var min_x := int(floor((position.x - radius) / cell_size))
	var max_x := int(floor((position.x + radius) / cell_size))
	var min_y := int(floor((position.y - radius) / cell_size))
	var max_y := int(floor((position.y + radius) / cell_size))
	
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var key := _hash_cell(x, y)
			var cell: Array = _grid.get(key, [])
			for obj in cell:
				var obj_id = obj.get_instance_id() if obj is Object else hash(obj)
				if not seen.has(obj_id):
					seen[obj_id] = true
					results.append(obj)
	
	return results

## 查询与指定圆形区域相交的所有对象（精确距离检测）
func query_circle(center: Vector2, radius: float) -> Array:
	var candidates := query_area(center, radius)
	# 候选对象已经通过空间哈希粗筛，调用者需要进一步做精确距离检测
	return candidates

## 批量插入弹体数据（优化版本，减少函数调用开销）
func batch_insert_projectiles(projectiles: Array) -> void:
	for proj in projectiles:
		if not proj.get("active", false):
			continue
		var pos: Vector2 = proj["position"]
		var key := _hash_position(pos)
		_insert_to_cell(key, proj)
	_total_objects = projectiles.size()

## 批量插入敌人数据
func batch_insert_enemies(enemies: Array) -> void:
	for enemy_data in enemies:
		var pos: Vector2 = enemy_data["position"]
		var radius: float = enemy_data.get("radius", 16.0)
		insert_aabb(enemy_data, pos, radius)

# ============================================================
# 碰撞对查询 — 核心优化方法
# ============================================================

## 查找弹体与敌人之间的碰撞对
## 这是替代 O(n×m) 暴力检测的核心方法
## projectiles: Array[Dictionary] - 弹体数据数组
## enemies: Array[Dictionary] - 敌人碰撞数据数组
## 返回: Array[Dictionary] - 命中结果数组
func find_collisions(projectiles: Array, enemies: Array) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	
	# 步骤1：将所有敌人插入空间哈希
	clear()
	for enemy_data in enemies:
		var pos: Vector2 = enemy_data["position"]
		var radius: float = enemy_data.get("radius", 16.0)
		insert_aabb(enemy_data, pos, radius)
	
	# 步骤2：对每个活跃弹体，查询其所在单元格的敌人
	for proj in projectiles:
		if not proj.get("active", false):
			continue
		
		var proj_pos: Vector2 = proj["position"]
		var proj_size: float = proj.get("size", 24.0)
		
		# 查询弹体附近的敌人候选集
		var candidates := query_area(proj_pos, proj_size)
		
		# 步骤3：对候选集进行精确距离检测
		for enemy_data in candidates:
			var enemy_pos: Vector2 = enemy_data["position"]
			var enemy_radius: float = enemy_data.get("radius", 16.0)
			
			var dist := proj_pos.distance_to(enemy_pos)
			if dist < proj_size + enemy_radius:
				hits.append({
					"projectile": proj,
					"enemy": enemy_data,
					"damage": proj.get("damage", 0.0),
					"position": enemy_pos,
				})
				
				# 穿透检测
				if proj.get("pierce", false):
					proj["pierce_count"] = proj.get("pierce_count", 0) + 1
					if proj["pierce_count"] >= proj.get("max_pierce", 3):
						proj["active"] = false
						break
				else:
					proj["active"] = false
					break
	
	return hits

# ============================================================
# 内部方法
# ============================================================

## 将位置哈希到单元格键
func _hash_position(position: Vector2) -> int:
	var cx := int(floor(position.x / cell_size))
	var cy := int(floor(position.y / cell_size))
	return _hash_cell(cx, cy)

## 将单元格坐标哈希为唯一键
## 使用 Cantor 配对函数的变体，支持负坐标
func _hash_cell(cx: int, cy: int) -> int:
	# 将负坐标映射到正整数空间
	var ax := cx * 2 if cx >= 0 else (-cx * 2 - 1)
	var ay := cy * 2 if cy >= 0 else (-cy * 2 - 1)
	# Cantor 配对
	return (ax + ay) * (ax + ay + 1) / 2 + ay

## 将对象插入到指定单元格
func _insert_to_cell(key: int, object: Variant) -> void:
	if not _grid.has(key):
		_grid[key] = []
		_total_cells += 1
	_grid[key].append(object)
	
	var cell_count: int = _grid[key].size()
	if cell_count > _max_objects_per_cell:
		_max_objects_per_cell = cell_count

# ============================================================
# 调试与统计
# ============================================================

## 获取当前统计信息
func get_stats() -> Dictionary:
	return {
		"total_objects": _total_objects,
		"total_cells": _total_cells,
		"max_objects_per_cell": _max_objects_per_cell,
		"cell_size": cell_size,
	}

## 获取所有非空单元格的位置（用于调试可视化）
func get_occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for key in _grid:
		if _grid[key].size() > 0:
			# 反向计算单元格坐标（近似，用于调试）
			cells.append(Vector2i(key % 1000, key / 1000))
	return cells
