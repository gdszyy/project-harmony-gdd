## damage_number_manager.gd
## 伤害数字管理器 (Issue #19)
## 使用对象池管理伤害数字显示
extends Node2D

# ============================================================
# 配置
# ============================================================
const POOL_SIZE: int = 50
const DamageNumber = preload("res://scripts/ui/damage_number.gd")

# ============================================================
# 对象池
# ============================================================
var _pool: Array[Node2D] = []
var _pool_index: int = 0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_init_pool()
	
	# 连接信号
	if GameManager.has_signal("enemy_killed"):
		GameManager.enemy_killed.connect(_on_enemy_killed)

# ============================================================
# 对象池初始化
# ============================================================

func _init_pool() -> void:
	for i in range(POOL_SIZE):
		var damage_number := Node2D.new()
		damage_number.set_script(DamageNumber)
		damage_number.visible = false
		add_child(damage_number)
		_pool.append(damage_number)

# ============================================================
# 公共接口
# ============================================================

## 显示伤害数字
func show_damage(damage: float, position: Vector2, is_critical: bool = false, 
		is_perfect_beat: bool = false, is_dissonance: bool = false) -> void:
	
	var damage_number := _get_from_pool()
	if damage_number == null:
		return
	
	# 确定伤害类型
	var damage_type: int = DamageNumber.DamageType.NORMAL
	if is_critical or is_perfect_beat:
		damage_type = DamageNumber.DamageType.CRITICAL
	elif is_dissonance:
		damage_type = DamageNumber.DamageType.DISSONANCE
	
	# 显示
	damage_number.show_damage(damage, position, damage_type)

## 从对象池获取可用的伤害数字
func _get_from_pool() -> Node2D:
	# 循环查找未激活的对象
	for i in range(POOL_SIZE):
		var idx := (_pool_index + i) % POOL_SIZE
		var damage_number = _pool[idx]
		if not damage_number.is_active():
			_pool_index = (idx + 1) % POOL_SIZE
			return damage_number
	
	# 池满，覆盖最旧的
	var damage_number = _pool[_pool_index]
	damage_number.reset()
	_pool_index = (_pool_index + 1) % POOL_SIZE
	return damage_number

# ============================================================
# 信号回调
# ============================================================

func _on_enemy_killed(enemy_position: Vector2) -> void:
	# 敌人死亡时可以显示经验值获得等信息
	pass
