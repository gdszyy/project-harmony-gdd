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
@onready var _visual: Node2D = $PlayerVisual
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _invincibility_timer: Timer = $InvincibilityTimer
@onready var _pickup_area: Area2D = $PickupArea

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

	# 暂停
	if event.is_action_pressed("pause_game"):
		if GameManager.current_state == GameManager.GameState.PLAYING:
			GameManager.pause_game()
		elif GameManager.current_state == GameManager.GameState.PAUSED:
			GameManager.resume_game()

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

func take_damage(amount: float) -> void:
	if _is_invincible:
		return

	GameManager.damage_player(amount)
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

func _on_pickup_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("xp_pickup"):
		var xp_value: int = body.get("xp_value") if body.has_method("get") else 5
		GameManager.add_xp(xp_value)
		body.queue_free()

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
