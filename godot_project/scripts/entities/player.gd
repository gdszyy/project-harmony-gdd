## player.gd
## 玩家角色控制器
## 正十二面体能量核心，悬浮移动，带有缓入缓出插值
## 注意：所有视觉效果（旋转、脉冲、闪烁等）统一由 player_visual_enhanced.gd 负责
extends CharacterBody2D

# ============================================================
# 信号
# ============================================================
signal player_moved(position: Vector2)

# ============================================================
# 配置
# ============================================================
@export var move_speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1500.0

## 无敌帧时间
@export var invincibility_duration: float = 0.5

# ============================================================
# 节点引用
# ============================================================
@onready var _visual: Node2D = _find_visual_node()
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _invincibility_timer: Timer = $InvincibilityTimer
@onready var _pickup_area: Area2D = $PickupArea

# ============================================================
# 节点查找辅助
# ============================================================

## 兼容 PlayerVisual 和 PlayerVisualEnhanced 两种场景结构
func _find_visual_node() -> Node2D:
	var node := get_node_or_null("PlayerVisualEnhanced")
	if node:
		return node
	node = get_node_or_null("PlayerVisual")
	if node:
		return node
	# 找不到视觉节点时返回 null，不报错
	return null

# ============================================================
# 状态
# ============================================================
var _is_invincible: bool = false
var _input_direction: Vector2 = Vector2.ZERO

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_to_group("player")
	_setup_timers()

	# 连接信号
	GameManager.player_died.connect(_on_player_died)

	# 连接 InvincibilityTimer 的 timeout 信号（场景中已有该节点时需要手动连接）
	if _invincibility_timer and not _invincibility_timer.timeout.is_connected(_on_invincibility_timeout):
		_invincibility_timer.timeout.connect(_on_invincibility_timeout)

	# 连接 PickupArea 的 area_entered 信号（xp_pickup 是 Area2D，不是 PhysicsBody2D）
	if _pickup_area and not _pickup_area.area_entered.is_connected(_on_pickup_area_entered):
		_pickup_area.area_entered.connect(_on_pickup_area_entered)

	# 应用局外升级的拾取范围加成
	_apply_meta_pickup_range()

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	_handle_input()
	_apply_movement(delta)
	move_and_slide()
	player_moved.emit(global_position)

	# 将无敌状态传递给视觉组件
	if _visual and _visual.has_method("set_invincible"):
		_visual.set_invincible(_is_invincible)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# 手动施法输入
	if event.is_action_pressed("manual_cast_1"):
		SpellcraftSystem.trigger_manual_cast(0)
	elif event.is_action_pressed("manual_cast_2"):
		SpellcraftSystem.trigger_manual_cast(1)
	elif event.is_action_pressed("manual_cast_3"):
		SpellcraftSystem.trigger_manual_cast(2)


# ============================================================
# 移动处理
# ============================================================

func _handle_input() -> void:
	_input_direction = Vector2.ZERO

	if Input.is_action_pressed("move_up"):
		_input_direction.y -= 1
	if Input.is_action_pressed("move_down"):
		_input_direction.y += 1
	if Input.is_action_pressed("move_left"):
		_input_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		_input_direction.x += 1

	_input_direction = _input_direction.normalized()

func _apply_movement(delta: float) -> void:
	if _input_direction != Vector2.ZERO:
		# 加速
		velocity = velocity.move_toward(_input_direction * move_speed, acceleration * delta)
	else:
		# 减速（摩擦）
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

# ============================================================
# 伤害处理
# ============================================================

func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO) -> void:
	if _is_invincible:
		return

	GameManager.damage_player(amount, source_position)
	_start_invincibility()

	# 通知视觉组件播放受伤效果
	if _visual and _visual.has_method("apply_damage_effect"):
		_visual.apply_damage_effect()

func _start_invincibility() -> void:
	_is_invincible = true
	_invincibility_timer.start(invincibility_duration)

func _on_invincibility_timeout() -> void:
	_is_invincible = false

func _on_player_died() -> void:
	# 死亡动画/效果
	set_physics_process(false)
	if _visual:
		var tween := create_tween()
		tween.tween_property(_visual, "scale", Vector2.ZERO, 0.5).set_ease(Tween.EASE_IN)
		tween.tween_property(_visual, "modulate:a", 0.0, 0.3)

# ============================================================
# 拾取
# ============================================================

func _on_pickup_area_entered(area: Area2D) -> void:
	if area.is_in_group("xp_pickup"):
		# 如果是 xp_pickup.gd 实例（有 _collect 方法），由其自身处理经验收集
		if area.has_method("_collect"):
			return  # xp_pickup.gd 的 _collect() 已经处理了 add_xp
		# enemy_spawner 生成的简易 xp_pickup：读取经验值并添加
		var xp_val: int = 5
		if area.has_meta("xp_value"):
			xp_val = area.get_meta("xp_value")
		GameManager.add_xp(xp_val)
		area.queue_free()

# ============================================================
# 设置
# ============================================================

func _setup_timers() -> void:
	if not has_node("InvincibilityTimer"):
		_invincibility_timer = Timer.new()
		_invincibility_timer.name = "InvincibilityTimer"
		_invincibility_timer.one_shot = true
		_invincibility_timer.timeout.connect(_on_invincibility_timeout)
		add_child(_invincibility_timer)

## 获取朝向鼠标的方向
func get_aim_direction() -> Vector2:
	return (get_global_mouse_position() - global_position).normalized()

# ============================================================
# 局外升级加成
# ============================================================

## 应用拾取范围加成（从 MetaProgressionManager 读取）
func _apply_meta_pickup_range() -> void:
	if not _pickup_area:
		return

	# 从 SaveManager 获取拾取范围加成（已委托给 MetaProgressionManager）
	var bonus_range: float = SaveManager.get_pickup_range_bonus()
	if bonus_range <= 0.0:
		return

	# 查找 PickupArea 下的 CollisionShape2D 并扩大其半径
	for child in _pickup_area.get_children():
		if child is CollisionShape2D:
			var shape = child.shape
			if shape is CircleShape2D:
				shape.radius += bonus_range
			elif shape is RectangleShape2D:
				shape.size += Vector2(bonus_range, bonus_range)
			break
