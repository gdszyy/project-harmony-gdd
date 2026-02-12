## damage_number_pool.gd — 伤害数字对象池管理器
## 预创建伤害数字实例，避免运行时频繁实例化
## 作为 HUD 的子节点管理伤害数字的生命周期
extends Node2D

# ============================================================
# 配置
# ============================================================
const POOL_SIZE: int = 30
const POOL_EXPAND_SIZE: int = 10

# ============================================================
# 状态
# ============================================================
var _pool: Array[DamageNumber] = []
var _active_count: int = 0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_initialize_pool()

# ============================================================
# 对象池管理
# ============================================================

func _initialize_pool() -> void:
	for i in range(POOL_SIZE):
		_create_instance()

func _create_instance() -> DamageNumber:
	var instance := DamageNumber.new()
	instance.visible = false
	add_child(instance)
	_pool.append(instance)
	return instance

func _get_available() -> DamageNumber:
	for instance in _pool:
		if not instance.is_active():
			return instance

	# 池已满，扩展
	for i in range(POOL_EXPAND_SIZE):
		_create_instance()

	return _pool[_pool.size() - POOL_EXPAND_SIZE]

# ============================================================
# 公共接口
# ============================================================

## 生成伤害数字
func spawn_damage(damage: float, world_pos: Vector2, type: DamageNumber.DamageType = DamageNumber.DamageType.NORMAL) -> void:
	var instance := _get_available()
	if instance:
		instance.reset()
		instance.show_damage(damage, world_pos, type)

## 生成普通伤害
func spawn_normal(damage: float, pos: Vector2) -> void:
	spawn_damage(damage, pos, DamageNumber.DamageType.NORMAL)

## 生成暴击伤害
func spawn_critical(damage: float, pos: Vector2) -> void:
	spawn_damage(damage, pos, DamageNumber.DamageType.CRITICAL)

## 生成不和谐自伤
func spawn_dissonance(damage: float, pos: Vector2) -> void:
	spawn_damage(damage, pos, DamageNumber.DamageType.DISSONANCE)

## 生成治疗数字
func spawn_heal(amount: float, pos: Vector2) -> void:
	spawn_damage(amount, pos, DamageNumber.DamageType.HEAL)

## 生成完美节拍伤害
func spawn_perfect(damage: float, pos: Vector2) -> void:
	spawn_damage(damage, pos, DamageNumber.DamageType.PERFECT)

## 获取当前活跃数量
func get_active_count() -> int:
	var count := 0
	for instance in _pool:
		if instance.is_active():
			count += 1
	return count

## 清除所有活跃的伤害数字
func clear_all() -> void:
	for instance in _pool:
		instance.reset()
