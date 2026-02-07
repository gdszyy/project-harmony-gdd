## enemy_base.gd
## 敌人基类
## 锯齿状碎片造型，量化步进移动，低帧率动画
extends CharacterBody2D

# ============================================================
# 信号
# ============================================================
signal enemy_died(position: Vector2, xp_value: int)
signal enemy_damaged(current_hp: float, max_hp: float)

# ============================================================
# 配置
# ============================================================
@export var max_hp: float = 50.0
@export var move_speed: float = 80.0
@export var contact_damage: float = 10.0
@export var xp_value: int = 5
@export var detection_range: float = 800.0

## 量化移动帧率（模拟"不和谐"的机械感）
@export var quantized_fps: float = 12.0

# ============================================================
# 节点引用
# ============================================================
@onready var _sprite: Node2D = $EnemyVisual
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _damage_area: Area2D = $DamageArea

# ============================================================
# 状态
# ============================================================
var current_hp: float = 50.0
var _target: Node2D = null
var _quantize_timer: float = 0.0
var _quantize_interval: float = 1.0 / 12.0
var _last_quantized_position: Vector2 = Vector2.ZERO
var _visual_glitch_intensity: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_to_group("enemies")
	current_hp = max_hp
	_quantize_interval = 1.0 / quantized_fps
	_last_quantized_position = global_position
	_find_player()

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	_update_target()
	_quantized_movement(delta)
	_update_visual(delta)
	_check_contact_damage()

# ============================================================
# 量化步进移动
# ============================================================

func _quantized_movement(delta: float) -> void:
	_quantize_timer += delta

	if _quantize_timer >= _quantize_interval:
		_quantize_timer -= _quantize_interval

		if _target == null:
			return

		# 计算朝向玩家的方向
		var direction := (_target.global_position - global_position).normalized()
		var step_distance := move_speed * _quantize_interval

		# 步进移动（非平滑，模拟低帧率）
		velocity = direction * move_speed
		move_and_slide()

		_last_quantized_position = global_position

# ============================================================
# 视觉更新
# ============================================================

func _update_visual(delta: float) -> void:
	if _sprite == null:
		return

	# 故障效果强度随生命值降低而增加
	_visual_glitch_intensity = 1.0 - (current_hp / max_hp)

	# 量化旋转（不平滑）
	if _target:
		var angle := (_target.global_position - global_position).angle()
		# 量化到45度增量
		var quantized_angle := roundf(angle / (PI / 4.0)) * (PI / 4.0)
		_sprite.rotation = quantized_angle

	# 受伤时的闪烁
	if _visual_glitch_intensity > 0.5:
		var glitch := sin(Time.get_ticks_msec() * 0.03) > 0.0
		_sprite.visible = true if not glitch else (randf() > 0.3)
	else:
		_sprite.visible = true

	# 颜色随生命值变化
	var hp_ratio := current_hp / max_hp
	_sprite.modulate = Color(1.0, hp_ratio, hp_ratio * 0.5)

# ============================================================
# 伤害处理
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	current_hp -= amount
	enemy_damaged.emit(current_hp, max_hp)

	# 击退
	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir * 200.0
		move_and_slide()

	# 受击视觉反馈
	_flash_damage()

	if current_hp <= 0.0:
		_die()

func _flash_damage() -> void:
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.05)
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.3, 0.3), 0.1)

func _die() -> void:
	enemy_died.emit(global_position, xp_value)
	GameManager.enemy_killed.emit(global_position)

	# 死亡效果：像素化碎裂
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(_sprite, "modulate:a", 0.0, 0.15)
		tween.tween_callback(queue_free)
	else:
		queue_free()

# ============================================================
# 接触伤害
# ============================================================

func _check_contact_damage() -> void:
	if _target == null:
		return

	var dist := global_position.distance_to(_target.global_position)
	if dist < 30.0:  # 接触距离
		if _target.has_method("take_damage"):
			_target.take_damage(contact_damage)

# ============================================================
# 目标追踪
# ============================================================

func _find_player() -> void:
	_target = get_tree().get_first_node_in_group("player")

func _update_target() -> void:
	if _target == null or not is_instance_valid(_target):
		_find_player()

# ============================================================
# 碰撞数据接口（供 ProjectileManager 使用）
# ============================================================

func get_collision_data() -> Dictionary:
	return {
		"position": global_position,
		"radius": 16.0,
		"node": self,
	}
