## object_pool.gd
## 通用对象池系统 (Issue #25)
## 提供高性能的对象复用机制，避免频繁的 instantiate/queue_free 开销。
##
## 支持的对象类型：
## - 敌人 (CharacterBody2D)
## - 经验值拾取物 (Area2D)
## - 伤害数字 (Node2D)
## - 死亡特效碎片 (Polygon2D)
## - 任意 Node 子类
##
## 设计原则：
## - 预分配策略：启动时创建固定数量的对象
## - 弹性扩容：当池耗尽时按需创建新对象并加入池
## - 延迟回收：对象"死亡"后不销毁，而是重置状态并归还池
## - 统计监控：提供池使用率、命中率等性能指标
class_name ObjectPool

# ============================================================
# 信号
# ============================================================
signal pool_exhausted(pool_name: String)
signal pool_expanded(pool_name: String, new_size: int)

# ============================================================
# 配置
# ============================================================
## 池名称（用于调试和统计）
var pool_name: String = "default"

## 初始池大小
var initial_size: int = 20

## 最大池大小（0 = 无限制）
var max_size: int = 0

## 每次扩容的增量
var expand_increment: int = 10

## 是否允许动态扩容
var allow_expansion: bool = true

# ============================================================
# 内部数据
# ============================================================
## 可用对象队列
var _available: Array = []

## 已借出的对象集合
var _active: Dictionary = {}  # instance_id -> object

## 对象工厂函数（用于创建新对象）
var _factory: Callable

## 对象重置函数（用于回收时重置状态）
var _reset_func: Callable

## 父节点（对象将被添加为其子节点）
var _parent: Node = null

## 统计
var _total_created: int = 0
var _total_acquired: int = 0
var _total_released: int = 0
var _peak_active: int = 0
var _expansion_count: int = 0

# ============================================================
# 初始化
# ============================================================

## 创建对象池
## factory: 创建新对象的工厂函数 () -> Node
## reset_func: 重置对象状态的函数 (node: Node) -> void
## parent: 对象的父节点
## p_initial_size: 初始池大小
## p_max_size: 最大池大小（0 = 无限制）
func _init(p_name: String, factory: Callable, reset_func: Callable, 
		parent: Node, p_initial_size: int = 20, p_max_size: int = 0) -> void:
	pool_name = p_name
	_factory = factory
	_reset_func = reset_func
	_parent = parent
	initial_size = p_initial_size
	max_size = p_max_size

## 预分配对象（在 _ready 中调用）
func preallocate() -> void:
	for i in range(initial_size):
		var obj := _create_object()
		if obj != null:
			_available.append(obj)

# ============================================================
# 核心接口
# ============================================================

## 从池中获取一个对象
## 如果池为空且允许扩容，则创建新对象
## 返回 null 表示池已耗尽且不允许扩容
func acquire() -> Node:
	_total_acquired += 1
	
	var obj: Node = null
	
	if _available.size() > 0:
		obj = _available.pop_back()
		# 确保对象仍然有效
		while obj != null and not is_instance_valid(obj):
			obj = _available.pop_back() if _available.size() > 0 else null
	
	if obj == null:
		# 池为空，尝试扩容
		if allow_expansion and (max_size == 0 or _total_created < max_size):
			_expand()
			if _available.size() > 0:
				obj = _available.pop_back()
		
		if obj == null:
			pool_exhausted.emit(pool_name)
			return null
	
	# 激活对象
	var obj_id := obj.get_instance_id()
	_active[obj_id] = obj
	obj.visible = true
	obj.set_process(true)
	obj.set_physics_process(true)
	
	# 更新峰值统计
	if _active.size() > _peak_active:
		_peak_active = _active.size()
	
	return obj

## 将对象归还池
func release(obj: Node) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	
	var obj_id := obj.get_instance_id()
	if not _active.has(obj_id):
		return  # 对象不属于此池
	
	_total_released += 1
	_active.erase(obj_id)
	
	# 重置对象状态
	_reset_func.call(obj)
	
	# 隐藏并停止处理
	obj.visible = false
	obj.set_process(false)
	obj.set_physics_process(false)
	
	# 归还到可用队列
	_available.append(obj)

## 释放所有活跃对象
func release_all() -> void:
	var active_copy := _active.values()
	for obj in active_copy:
		release(obj)

# ============================================================
# 内部方法
# ============================================================

## 创建一个新对象
func _create_object() -> Node:
	var obj: Node = _factory.call()
	if obj == null:
		push_error("ObjectPool '%s': Factory returned null!" % pool_name)
		return null
	
	_total_created += 1
	
	# 初始状态：隐藏且不处理
	obj.visible = false
	obj.set_process(false)
	obj.set_physics_process(false)
	
	# 添加到父节点
	if _parent and is_instance_valid(_parent):
		_parent.add_child(obj)
	
	return obj

## 扩容池
func _expand() -> void:
	var count := expand_increment
	if max_size > 0:
		count = min(count, max_size - _total_created)
	
	if count <= 0:
		return
	
	for i in range(count):
		var obj := _create_object()
		if obj != null:
			_available.append(obj)
	
	_expansion_count += 1
	pool_expanded.emit(pool_name, _total_created)

# ============================================================
# 统计接口
# ============================================================

## 获取池统计信息
func get_stats() -> Dictionary:
	return {
		"name": pool_name,
		"total_created": _total_created,
		"available": _available.size(),
		"active": _active.size(),
		"total_acquired": _total_acquired,
		"total_released": _total_released,
		"peak_active": _peak_active,
		"expansion_count": _expansion_count,
		"utilization": float(_active.size()) / float(max(_total_created, 1)),
	}

## 获取当前活跃对象数量
func get_active_count() -> int:
	return _active.size()

## 获取可用对象数量
func get_available_count() -> int:
	return _available.size()

## 获取池总大小
func get_total_size() -> int:
	return _total_created

# ============================================================
# 清理
# ============================================================

## 销毁池中的所有对象
func destroy() -> void:
	release_all()
	for obj in _available:
		if is_instance_valid(obj):
			obj.queue_free()
	_available.clear()
	_active.clear()
