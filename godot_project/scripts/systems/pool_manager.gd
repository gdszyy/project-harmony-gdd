## pool_manager.gd
## 对象池管理器 (Issue #25)
## 统一管理游戏中所有对象池：敌人、经验值拾取物、伤害数字、死亡特效碎片
## 
## 架构设计：
## - 作为 Node 挂载到场景树中（非 Autoload，由 MainGame 管理）
## - 提供统一的 acquire/release 接口
## - 支持性能监控面板数据输出
## - 与 EnemySpawner、DamageNumberManager 等系统集成
##
## 性能目标：
## - 敌人池：预分配 60，峰值 120
## - XP 拾取物池：预分配 100，峰值 300
## - 伤害数字池：预分配 50，峰值 100
## - 死亡碎片池：预分配 80，峰值 200
extends Node

# ============================================================
# 信号
# ============================================================
signal pool_stats_updated(stats: Dictionary)

# ============================================================
# 池配置
# ============================================================
const POOL_CONFIG: Dictionary = {
	"enemy_static": { "initial": 30, "max": 150, "expand": 10 },
	"enemy_silence": { "initial": 8, "max": 30, "expand": 4 },
	"enemy_screech": { "initial": 15, "max": 60, "expand": 8 },
	"enemy_pulse": { "initial": 10, "max": 40, "expand": 5 },
	"enemy_wall": { "initial": 5, "max": 20, "expand": 3 },
	"xp_pickup": { "initial": 100, "max": 400, "expand": 20 },
	"damage_number": { "initial": 50, "max": 120, "expand": 10 },
	"death_fragment": { "initial": 80, "max": 250, "expand": 20 },
}

# ============================================================
# 敌人场景路径
# ============================================================
const ENEMY_SCENES: Dictionary = {
	"enemy_static":  "res://scenes/enemies/enemy_static.tscn",
	"enemy_silence": "res://scenes/enemies/enemy_silence.tscn",
	"enemy_screech": "res://scenes/enemies/enemy_screech.tscn",
	"enemy_pulse":   "res://scenes/enemies/enemy_pulse.tscn",
	"enemy_wall":    "res://scenes/enemies/enemy_wall.tscn",
}

# ============================================================
# 内部数据
# ============================================================
## 所有对象池
var _pools: Dictionary = {}  # pool_name -> ObjectPool

## 缓存的 PackedScene
var _cached_scenes: Dictionary = {}

## 统计更新计时器
var _stats_timer: float = 0.0
const STATS_UPDATE_INTERVAL: float = 1.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_to_group("pool_manager")
	_preload_scenes()
	_init_all_pools()

func _process(delta: float) -> void:
	_stats_timer += delta
	if _stats_timer >= STATS_UPDATE_INTERVAL:
		_stats_timer = 0.0
		_emit_stats()

# ============================================================
# 场景预加载
# ============================================================

func _preload_scenes() -> void:
	for pool_name in ENEMY_SCENES:
		var scene_path: String = ENEMY_SCENES[pool_name]
		var scene := load(scene_path) as PackedScene
		if scene:
			_cached_scenes[pool_name] = scene
		else:
			push_warning("PoolManager: Failed to load scene: %s" % scene_path)

# ============================================================
# 池初始化
# ============================================================

func _init_all_pools() -> void:
	# 敌人池
	for enemy_pool_name in ENEMY_SCENES:
		_init_enemy_pool(enemy_pool_name)
	
	# XP 拾取物池
	_init_xp_pool()
	
	# 伤害数字池
	_init_damage_number_pool()
	
	# 死亡碎片池
	_init_death_fragment_pool()

func _init_enemy_pool(pool_name: String) -> void:
	var config: Dictionary = POOL_CONFIG.get(pool_name, { "initial": 10, "max": 50, "expand": 5 })
	var scene: PackedScene = _cached_scenes.get(pool_name)
	
	if scene == null:
		push_warning("PoolManager: No scene for pool '%s'" % pool_name)
		return
	
	var factory := func() -> Node:
		var instance := scene.instantiate()
		return instance
	
	var reset_func := func(node: Node) -> void:
		_reset_enemy(node)
	
	var pool := ObjectPool.new(
		pool_name, factory, reset_func, self,
		config["initial"], config["max"]
	)
	pool.expand_increment = config["expand"]
	pool.preallocate()
	_pools[pool_name] = pool

func _init_xp_pool() -> void:
	var config: Dictionary = POOL_CONFIG["xp_pickup"]
	
	var factory := func() -> Node:
		var pickup := Area2D.new()
		pickup.add_to_group("xp_pickup")
		pickup.collision_layer = 4
		pickup.collision_mask = 1
		
		# 视觉
		var visual := Polygon2D.new()
		visual.name = "Visual"
		visual.polygon = PackedVector2Array([
			Vector2(0, -5), Vector2(4, 3), Vector2(-4, 3)
		])
		visual.color = Color(0.0, 1.0, 0.8, 0.8)
		pickup.add_child(visual)
		
		# 碰撞
		var col := CollisionShape2D.new()
		col.name = "Collision"
		var shape := CircleShape2D.new()
		shape.radius = 15.0
		col.shape = shape
		pickup.add_child(col)
		
		return pickup
	
	var reset_func := func(node: Node) -> void:
		_reset_xp_pickup(node)
	
	var pool := ObjectPool.new(
		"xp_pickup", factory, reset_func, self,
		config["initial"], config["max"]
	)
	pool.expand_increment = config["expand"]
	pool.preallocate()
	_pools["xp_pickup"] = pool

func _init_damage_number_pool() -> void:
	var config: Dictionary = POOL_CONFIG["damage_number"]
	var DamageNumberScript = preload("res://scripts/ui/damage_number.gd")
	
	var factory := func() -> Node:
		var dn := Node2D.new()
		dn.set_script(DamageNumberScript)
		return dn
	
	var reset_func := func(node: Node) -> void:
		if node.has_method("reset"):
			node.reset()
		node.visible = false
		node.position = Vector2.ZERO
	
	var pool := ObjectPool.new(
		"damage_number", factory, reset_func, self,
		config["initial"], config["max"]
	)
	pool.expand_increment = config["expand"]
	pool.preallocate()
	_pools["damage_number"] = pool

func _init_death_fragment_pool() -> void:
	var config: Dictionary = POOL_CONFIG["death_fragment"]
	
	var factory := func() -> Node:
		var frag := Polygon2D.new()
		frag.polygon = PackedVector2Array([
			Vector2(-3, -3), Vector2(3, -1), Vector2(1, 3), Vector2(-2, 2)
		])
		frag.color = Color.WHITE
		return frag
	
	var reset_func := func(node: Node) -> void:
		if node is Polygon2D:
			node.color = Color.WHITE
			node.modulate = Color.WHITE
			node.scale = Vector2(1.0, 1.0)
			node.rotation = 0.0
			node.position = Vector2.ZERO
		node.visible = false
	
	var pool := ObjectPool.new(
		"death_fragment", factory, reset_func, self,
		config["initial"], config["max"]
	)
	pool.expand_increment = config["expand"]
	pool.preallocate()
	_pools["death_fragment"] = pool

# ============================================================
# 公共接口：获取对象
# ============================================================

## 从指定池获取对象
func acquire(pool_name: String) -> Node:
	var pool: ObjectPool = _pools.get(pool_name)
	if pool == null:
		push_warning("PoolManager: Unknown pool '%s'" % pool_name)
		return null
	return pool.acquire()

## 获取敌人（根据类型名称自动映射到对应池）
func acquire_enemy(type_name: String) -> Node:
	var pool_name := "enemy_" + type_name
	return acquire(pool_name)

## 获取 XP 拾取物
func acquire_xp_pickup() -> Node:
	return acquire("xp_pickup")

## 获取伤害数字
func acquire_damage_number() -> Node:
	return acquire("damage_number")

## 获取死亡碎片
func acquire_death_fragment() -> Node:
	return acquire("death_fragment")

# ============================================================
# 公共接口：归还对象
# ============================================================

## 归还对象到指定池
func release(pool_name: String, obj: Node) -> void:
	var pool: ObjectPool = _pools.get(pool_name)
	if pool == null:
		push_warning("PoolManager: Unknown pool '%s'" % pool_name)
		obj.queue_free()
		return
	pool.release(obj)

## 归还敌人
func release_enemy(type_name: String, obj: Node) -> void:
	release("enemy_" + type_name, obj)

## 归还 XP 拾取物
func release_xp_pickup(obj: Node) -> void:
	release("xp_pickup", obj)

## 归还伤害数字
func release_damage_number(obj: Node) -> void:
	release("damage_number", obj)

## 归还死亡碎片
func release_death_fragment(obj: Node) -> void:
	release("death_fragment", obj)

# ============================================================
# 对象重置方法
# ============================================================

func _reset_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	
	# 重置基本属性
	if enemy.has_method("set"):
		var type_name: String = ""
		if enemy.has_method("_get_type_name"):
			type_name = enemy._get_type_name()
		
		# 从 ENEMY_TYPE_DATA 获取基础值（如果 EnemySpawner 可访问）
		enemy.set("current_hp", enemy.get("max_hp"))
		enemy.set("_is_dead", false)
		enemy.set("_is_stunned", false)
		enemy.set("_stun_timer", 0.0)
		enemy.set("_contact_cooldown", 0.0)
		enemy.set("_damage_flash_timer", 0.0)
		enemy.set("_glitch_intensity", 0.0)
		enemy.set("_pixel_dissolve_progress", 0.0)
	
	# 重新启用物理处理
	enemy.set_physics_process(true)
	enemy.set_process(true)
	
	# 重置碰撞
	var collision := enemy.get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", false)
	
	# 重置视觉
	var visual := enemy.get_node_or_null("EnemyVisual")
	if visual:
		visual.visible = true
		visual.modulate = Color.WHITE
		visual.scale = Vector2(1.0, 1.0)
		visual.rotation = 0.0
	
	# 重置速度
	if enemy is CharacterBody2D:
		enemy.velocity = Vector2.ZERO

func _reset_xp_pickup(pickup: Node) -> void:
	if pickup == null:
		return
	
	pickup.set_meta("xp_value", 3)
	pickup.set_meta("attract_active", false)
	
	# 重置视觉
	var visual := pickup.get_node_or_null("Visual")
	if visual and visual is Polygon2D:
		visual.color = Color(0.0, 1.0, 0.8, 0.8)
		visual.modulate = Color.WHITE
		visual.scale = Vector2(1.0, 1.0)
		visual.rotation = 0.0
	
	# 重置碰撞
	var collision := pickup.get_node_or_null("Collision")
	if collision:
		collision.set_deferred("disabled", false)

# ============================================================
# 统计
# ============================================================

func _emit_stats() -> void:
	var stats: Dictionary = {}
	for pool_name in _pools:
		stats[pool_name] = _pools[pool_name].get_stats()
	pool_stats_updated.emit(stats)

## 获取所有池的统计信息
func get_all_stats() -> Dictionary:
	var stats: Dictionary = {}
	for pool_name in _pools:
		stats[pool_name] = _pools[pool_name].get_stats()
	return stats

## 获取指定池的统计信息
func get_pool_stats(pool_name: String) -> Dictionary:
	var pool: ObjectPool = _pools.get(pool_name)
	if pool:
		return pool.get_stats()
	return {}

## 获取总体性能摘要
func get_performance_summary() -> Dictionary:
	var total_created := 0
	var total_active := 0
	var total_available := 0
	
	for pool_name in _pools:
		var stats: Dictionary = _pools[pool_name].get_stats()
		total_created += stats["total_created"]
		total_active += stats["active"]
		total_available += stats["available"]
	
	return {
		"total_pools": _pools.size(),
		"total_objects_created": total_created,
		"total_active": total_active,
		"total_available": total_available,
		"overall_utilization": float(total_active) / float(max(total_created, 1)),
	}

# ============================================================
# 清理
# ============================================================

## 释放所有池中的活跃对象
func release_all_pools() -> void:
	for pool_name in _pools:
		_pools[pool_name].release_all()

## 销毁所有池
func destroy_all_pools() -> void:
	for pool_name in _pools:
		_pools[pool_name].destroy()
	_pools.clear()
