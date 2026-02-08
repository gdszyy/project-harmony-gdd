## collision_optimizer.gd
## 碰撞检测优化器 (Issue #6)
## 封装空间哈希网格，提供高层碰撞检测 API
## 替代 ProjectileManager 中的 O(n×m) 暴力检测
##
## 性能目标：
## - 500+ 弹体 + 120 敌人同屏时保持流畅
## - 2000 弹体极端情况下仍可接受
##
## 架构：
## - 使用 SpatialHash 进行空间分区
## - 支持分裂弹体的延迟处理
## - 提供性能统计接口
class_name CollisionOptimizer

# ============================================================
# 空间哈希实例
# ============================================================
var _spatial_hash: SpatialHash

# ============================================================
# 性能统计
# ============================================================
var _last_check_count: int = 0       ## 上次检测的实际比较次数
var _last_candidate_count: int = 0   ## 上次的候选对数量
var _last_hit_count: int = 0         ## 上次的命中数量
var _frame_times: Array[float] = []  ## 最近 N 帧的碰撞检测耗时
const MAX_FRAME_SAMPLES: int = 60

# ============================================================
# 配置
# ============================================================
## 空间哈希单元格大小
## 建议设置为最大弹体尺寸的 2-4 倍
var cell_size: float = 128.0

# ============================================================
# 初始化
# ============================================================

func _init(p_cell_size: float = 128.0) -> void:
	cell_size = p_cell_size
	_spatial_hash = SpatialHash.new(cell_size)

# ============================================================
# 核心碰撞检测
# ============================================================

## 执行弹体-敌人碰撞检测（空间哈希优化版）
## 这是替代 ProjectileManager.check_collisions() 的核心方法
func check_collisions(projectiles: Array, enemies: Array) -> Array[Dictionary]:
	var start_time := Time.get_ticks_usec()
	
	var hits: Array[Dictionary] = []
	var check_count := 0
	var candidate_count := 0
	
	# 步骤1：将所有敌人插入空间哈希
	_spatial_hash.clear()
	for enemy_data in enemies:
		var pos: Vector2 = enemy_data["position"]
		var radius: float = enemy_data.get("radius", 16.0)
		_spatial_hash.insert_aabb(enemy_data, pos, radius)
	
	# 步骤2：对每个活跃弹体进行碰撞检测
	# 收集需要延迟添加的分裂弹体
	var split_queue: Array[Dictionary] = []
	
	for proj in projectiles:
		if not proj.get("active", false):
			continue
		
		var proj_pos: Vector2 = proj["position"]
		var proj_size: float = proj.get("size", 24.0)
		
		# 通过空间哈希获取候选敌人（大幅减少比较次数）
		var candidates := _spatial_hash.query_area(proj_pos, proj_size)
		candidate_count += candidates.size()
		
		# 精确距离检测
		for enemy_data in candidates:
			check_count += 1
			
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
				else:
					proj["active"] = false
				
				# 分裂弹体
				if proj.get("split_on_hit", false) and proj.get("active", false) == false:
					split_queue.append(proj.duplicate())
				
				break  # 每帧每个弹体只命中一个敌人
	
	# 更新统计
	var end_time := Time.get_ticks_usec()
	var elapsed := (end_time - start_time) / 1000.0  # 转换为毫秒
	
	_last_check_count = check_count
	_last_candidate_count = candidate_count
	_last_hit_count = hits.size()
	
	_frame_times.append(elapsed)
	if _frame_times.size() > MAX_FRAME_SAMPLES:
		_frame_times.pop_front()
	
	return hits

## 执行场/法阵类弹体的区域碰撞检测
## 用于冲击波、法阵等持续性区域效果
func check_field_collisions(fields: Array, enemies: Array) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	
	_spatial_hash.clear()
	for enemy_data in enemies:
		var pos: Vector2 = enemy_data["position"]
		var radius: float = enemy_data.get("radius", 16.0)
		_spatial_hash.insert_aabb(enemy_data, pos, radius)
	
	for field in fields:
		if not field.get("active", false):
			continue
		if not field.get("is_field", false) and not field.get("is_shockwave", false):
			continue
		
		var field_pos: Vector2 = field["position"]
		var field_size: float = field.get("size", 60.0)
		
		var candidates := _spatial_hash.query_area(field_pos, field_size)
		
		for enemy_data in candidates:
			var enemy_pos: Vector2 = enemy_data["position"]
			var enemy_radius: float = enemy_data.get("radius", 16.0)
			
			var dist := field_pos.distance_to(enemy_pos)
			if dist < field_size + enemy_radius:
				hits.append({
					"projectile": field,
					"enemy": enemy_data,
					"damage": field.get("damage", 0.0),
					"position": enemy_pos,
				})
	
	return hits

# ============================================================
# 性能统计接口
# ============================================================

## 获取碰撞检测性能统计
func get_performance_stats() -> Dictionary:
	var avg_time := 0.0
	if _frame_times.size() > 0:
		var total := 0.0
		for t in _frame_times:
			total += t
		avg_time = total / _frame_times.size()
	
	var max_time := 0.0
	for t in _frame_times:
		if t > max_time:
			max_time = t
	
	return {
		"last_check_count": _last_check_count,
		"last_candidate_count": _last_candidate_count,
		"last_hit_count": _last_hit_count,
		"avg_frame_time_ms": avg_time,
		"max_frame_time_ms": max_time,
		"spatial_hash_stats": _spatial_hash.get_stats(),
	}

## 获取平均碰撞检测耗时（毫秒）
func get_avg_collision_time() -> float:
	if _frame_times.size() == 0:
		return 0.0
	var total := 0.0
	for t in _frame_times:
		total += t
	return total / _frame_times.size()

## 动态调整单元格大小
## 当检测到性能不佳时，可以尝试调整
func adjust_cell_size(new_size: float) -> void:
	cell_size = new_size
	_spatial_hash = SpatialHash.new(new_size)
