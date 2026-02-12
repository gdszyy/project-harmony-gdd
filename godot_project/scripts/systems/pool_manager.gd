## pool_manager.gd
## 对象池管理器 (Issue #25, Issue #116)
## 统一管理游戏中所有对象池：敌人、经验值拾取物、伤害数字、死亡特效碎片
## 
## 架构设计：
## - 作为 Node 挂载到场景树中（非 Autoload，由 MainGame 管理）
## - 提供统一的 acquire/release 接口
## - 支持性能监控面板数据输出
## - 与 EnemySpawner、DamageNumberManager 等系统集成
##
## Issue #116 增强：
## - 敌人实体完整纳入对象池管理（基础五种 + 章节特色 + 精英）
## - 动态池注册：支持运行时按需创建新敌人类型的池
## - 预热机制：章节切换时预分配该章节敌人的池
## - Shader 预编译：首次使用前预编译所有敌人 Shader 防止卡顿
## - 池容量自适应：根据波次类型动态调整池上限
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
## DEPRECATED: Signal emitted but no active consumer connected (Issue #86 audit)
signal pool_stats_updated(stats: Dictionary)

## Issue #116: 池扩容事件（供性能监控使用）
signal pool_expanded_warning(pool_name: String, new_total: int, max_size: int)

# ============================================================
# 池配置
# ============================================================
const POOL_CONFIG: Dictionary = {
	# 基础五种敌人
	"enemy_static": { "initial": 30, "max": 150, "expand": 10 },
	"enemy_silence": { "initial": 8, "max": 30, "expand": 4 },
	"enemy_screech": { "initial": 15, "max": 60, "expand": 8 },
	"enemy_pulse": { "initial": 10, "max": 40, "expand": 5 },
	"enemy_wall": { "initial": 5, "max": 20, "expand": 3 },
	# 章节特色敌人（按需预热，初始为 0）
	"enemy_ch1_grid_static":       { "initial": 0, "max": 40, "expand": 8 },
	"enemy_ch1_metronome_pulse":   { "initial": 0, "max": 30, "expand": 6 },
	"enemy_ch2_choir":             { "initial": 0, "max": 30, "expand": 6 },
	"enemy_ch2_scribe":            { "initial": 0, "max": 25, "expand": 5 },
	"enemy_ch3_counterpoint_crawler": { "initial": 0, "max": 25, "expand": 5 },
	"enemy_ch4_minuet_dancer":     { "initial": 0, "max": 25, "expand": 5 },
	"enemy_ch5_fate_knocker":      { "initial": 0, "max": 20, "expand": 4 },
	"enemy_ch5_crescendo_surge":   { "initial": 0, "max": 20, "expand": 4 },
	"enemy_ch5_fury_spirit":       { "initial": 0, "max": 20, "expand": 4 },
	"enemy_ch6_walking_bass":      { "initial": 0, "max": 20, "expand": 4 },
	"enemy_ch6_scat_singer":       { "initial": 0, "max": 20, "expand": 4 },
	"enemy_ch7_bitcrusher_worm":   { "initial": 0, "max": 20, "expand": 4 },
	"enemy_ch7_glitch_phantom":    { "initial": 0, "max": 20, "expand": 4 },
	# 非敌人池
	"xp_pickup": { "initial": 100, "max": 400, "expand": 20 },
	"damage_number": { "initial": 50, "max": 120, "expand": 10 },
	"death_fragment": { "initial": 80, "max": 250, "expand": 20 },
}

# ============================================================
# 章节预热配置：每个章节需要预分配的敌人类型和数量
# ============================================================
const CHAPTER_WARMUP: Dictionary = {
	1: { "enemy_ch1_grid_static": 15, "enemy_ch1_metronome_pulse": 10 },
	2: { "enemy_ch2_choir": 12, "enemy_ch2_scribe": 10 },
	3: { "enemy_ch3_counterpoint_crawler": 10 },
	4: { "enemy_ch4_minuet_dancer": 10 },
	5: { "enemy_ch5_fate_knocker": 8, "enemy_ch5_crescendo_surge": 8, "enemy_ch5_fury_spirit": 8 },
	6: { "enemy_ch6_walking_bass": 10, "enemy_ch6_scat_singer": 10 },
	7: { "enemy_ch7_bitcrusher_worm": 10, "enemy_ch7_glitch_phantom": 10 },
}

# ============================================================
# 敌人场景路径（基础五种）
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

## Issue #116: Shader 预编译状态
var _shaders_precompiled: bool = false

## Issue #116: 已预热的章节
var _warmed_chapters: Array[int] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_to_group("pool_manager")
	_preload_scenes()
	_init_all_pools()
	# Issue #116: 延迟一帧后执行 Shader 预编译，避免阻塞启动
	call_deferred("_precompile_shaders")

func _process(delta: float) -> void:
	_stats_timer += delta
	if _stats_timer >= STATS_UPDATE_INTERVAL:
		_stats_timer = 0.0
		_emit_stats()

# ============================================================
# 场景预加载
# ============================================================

func _preload_scenes() -> void:
	# 基础敌人场景
	for pool_name in ENEMY_SCENES:
		var scene_path: String = ENEMY_SCENES[pool_name]
		var scene := load(scene_path) as PackedScene
		if scene:
			_cached_scenes[pool_name] = scene
		else:
			push_warning("PoolManager: Failed to load scene: %s" % scene_path)

## Issue #116: 预加载章节特色敌人场景
func _preload_chapter_scenes(chapter_index: int) -> void:
	var chapter_scenes: Dictionary = {}
	
	# 从 ChapterData 获取章节敌人场景路径
	if Engine.has_singleton("ChapterData") or ClassDB.class_exists("ChapterData"):
		pass  # ChapterData 是 const，直接访问
	
	var prefix := "ch%d_" % chapter_index
	for type_name in ChapterData.ENEMY_SCENE_PATHS:
		if type_name.begins_with(prefix):
			var pool_name := "enemy_" + type_name
			if not _cached_scenes.has(pool_name):
				var scene_path: String = ChapterData.ENEMY_SCENE_PATHS[type_name]
				var scene := load(scene_path) as PackedScene
				if scene:
					_cached_scenes[pool_name] = scene
	
	# 精英场景
	for type_name in ChapterData.ELITE_SCENE_PATHS:
		if type_name.begins_with(prefix):
			var pool_name := "enemy_" + type_name
			if not _cached_scenes.has(pool_name):
				var scene_path: String = ChapterData.ELITE_SCENE_PATHS[type_name]
				var scene := load(scene_path) as PackedScene
				if scene:
					_cached_scenes[pool_name] = scene

# ============================================================
# 池初始化
# ============================================================

func _init_all_pools() -> void:
	# 基础敌人池（立即预分配）
	for enemy_pool_name in ENEMY_SCENES:
		_init_enemy_pool(enemy_pool_name)
	
	# XP 拾取物池
	_init_xp_pool()
	
	# 伤害数字池
	_init_damage_number_pool()
	
	# 死亡碎片池
	_init_death_fragment_pool()

func _init_enemy_pool(pool_name: String) -> void:
	if _pools.has(pool_name):
		return  # 避免重复初始化
	
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
# Issue #116: 章节预热 — 提前分配章节敌人池
# ============================================================

## 预热指定章节的敌人池（由 ChapterManager 在章节切换时调用）
func warmup_chapter(chapter_index: int) -> void:
	if chapter_index in _warmed_chapters:
		return  # 已预热过
	
	print("PoolManager: Warming up pools for chapter %d" % chapter_index)
	
	# 预加载章节场景
	_preload_chapter_scenes(chapter_index)
	
	# 获取预热配置
	var warmup: Dictionary = CHAPTER_WARMUP.get(chapter_index, {})
	
	for pool_name in warmup:
		var warmup_count: int = warmup[pool_name]
		
		# 如果池尚不存在，先创建
		if not _pools.has(pool_name):
			_init_enemy_pool(pool_name)
		
		# 确保池中有足够的预分配对象
		var pool: ObjectPool = _pools.get(pool_name)
		if pool and pool.get_available_count() < warmup_count:
			var needed := warmup_count - pool.get_available_count()
			for i in range(needed):
				pool._expand()  # 手动扩容
	
	_warmed_chapters.append(chapter_index)
	print("PoolManager: Chapter %d warmup complete" % chapter_index)

# ============================================================
# Issue #116: 动态池注册 — 运行时按需创建新敌人类型的池
# ============================================================

## 动态注册一个新的敌人池（用于未预配置的章节/精英敌人）
func register_enemy_pool(type_name: String, scene: PackedScene) -> void:
	var pool_name := "enemy_" + type_name
	if _pools.has(pool_name):
		return  # 已存在
	
	_cached_scenes[pool_name] = scene
	
	var config: Dictionary = POOL_CONFIG.get(pool_name, { "initial": 5, "max": 30, "expand": 5 })
	
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
	print("PoolManager: Dynamically registered pool '%s'" % pool_name)

## 检查指定敌人类型是否有可用的对象池
func has_enemy_pool(type_name: String) -> bool:
	return _pools.has("enemy_" + type_name)

# ============================================================
# Issue #116: Shader 预编译 — 防止首次使用时的编译卡顿
# ============================================================

## 预编译所有敌人相关 Shader
## 通过在屏幕外短暂渲染一帧来触发 Shader 编译
func _precompile_shaders() -> void:
	if _shaders_precompiled:
		return
	
	var shader_paths: Array[String] = [
		"res://shaders/enemy_static_glitch.gdshader",
		"res://shaders/enemy_pulse_led.gdshader",
		"res://shaders/enemy_screech_glitch.gdshader",
		"res://shaders/enemy_glitch.gdshader",
		"res://shaders/projectile_glow.gdshader",
		"res://shaders/fatigue_filter.gdshader",
		"res://shaders/hit_feedback.gdshader",
		"res://shaders/crystallized_silence.gdshader",
		"res://shaders/silence_distortion.gdshader",
		"res://shaders/pulse_shockwave.gdshader",
		"res://shaders/wall_cracks.gdshader",
	]
	
	var precompile_container := Node2D.new()
	precompile_container.name = "ShaderPrecompile"
	precompile_container.position = Vector2(-10000, -10000)  # 屏幕外
	precompile_container.modulate = Color(1, 1, 1, 0.01)  # 近乎透明
	add_child(precompile_container)
	
	for shader_path in shader_paths:
		var shader := load(shader_path) as Shader
		if shader == null:
			continue
		
		var mat := ShaderMaterial.new()
		mat.shader = shader
		
		# 创建一个小的 ColorRect 来触发 Shader 编译
		var rect := ColorRect.new()
		rect.size = Vector2(4, 4)
		rect.material = mat
		precompile_container.add_child(rect)
	
	# 等待两帧后移除预编译节点（确保 GPU 已编译）
	await get_tree().process_frame
	await get_tree().process_frame
	precompile_container.queue_free()
	
	_shaders_precompiled = true
	print("PoolManager: Shader precompilation complete (%d shaders)" % shader_paths.size())

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
	
	# Issue #116: 调用自定义重置方法（如果敌人脚本提供）
	if enemy.has_method("pool_reset"):
		enemy.pool_reset()
	
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
	
	# 清除元数据
	enemy.set_meta("from_pool", false)
	enemy.set_meta("pool_type", "")
	enemy.set_meta("scripted", false)
	enemy.set_meta("escort", false)
	enemy.set_meta("swarm_enabled", false)

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
		"shaders_precompiled": _shaders_precompiled,
		"warmed_chapters": _warmed_chapters.duplicate(),
	}

## Issue #116: 获取敌人池专项统计
func get_enemy_pool_summary() -> Dictionary:
	var enemy_stats: Dictionary = {}
	var total_enemy_active := 0
	var total_enemy_available := 0
	
	for pool_name in _pools:
		if pool_name.begins_with("enemy_"):
			var stats: Dictionary = _pools[pool_name].get_stats()
			enemy_stats[pool_name] = stats
			total_enemy_active += stats["active"]
			total_enemy_available += stats["available"]
	
	return {
		"pools": enemy_stats,
		"total_active": total_enemy_active,
		"total_available": total_enemy_available,
		"pool_count": enemy_stats.size(),
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

## Issue #116: 释放指定章节的敌人池（章节结束时调用，释放内存）
func release_chapter_pools(chapter_index: int) -> void:
	var prefix := "enemy_ch%d_" % chapter_index
	for pool_name in _pools:
		if pool_name.begins_with(prefix):
			_pools[pool_name].release_all()
