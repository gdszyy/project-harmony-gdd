## enemy_base.gd
## 敌人基类 — "不和谐的具象化 (Dissonance Incarnate)"
## 所有敌人继承此类。视觉上是故障的、低帧率的几何碎片；
## 机制上通过量化步进移动带来机械的压迫感。
## 设计参考：Project Harmony 敌人系统设计方案 v2.0
extends CharacterBody2D

# ============================================================
# 信号
# ============================================================
signal enemy_died(position: Vector2, xp_value: int, enemy_type: String)
signal enemy_damaged(current_hp: float, max_hp: float, damage_amount: float)
signal enemy_stunned(duration: float)

# ============================================================
# 敌人类型枚举
# ============================================================
enum EnemyType {
	STATIC,    ## 底噪 — 白噪声，数量巨大，直线蜂拥
	SILENCE,   ## 寂静 — 休止符/黑洞，增加玩家单调值
	SCREECH,   ## 尖啸 — 反馈音，快速接近，死亡爆发不和谐区域
	PULSE,     ## 脉冲 — 错误的节拍，定期冲刺/弹幕
	WALL,      ## 音墙 — 砖墙限制器，巨大阻挡者
}

# ============================================================
# 导出配置
# ============================================================
@export var enemy_type: EnemyType = EnemyType.STATIC
@export var max_hp: float = 50.0
@export var move_speed: float = 80.0
@export var contact_damage: float = 10.0
@export var xp_value: int = 5
@export var detection_range: float = 800.0

## 量化移动帧率（模拟"不和谐"的机械感）
## 越大的敌人帧率越低，显得更笨重
@export var quantized_fps: float = 12.0

## 碰撞半径（供 ProjectileManager 使用）
@export var collision_radius: float = 16.0

## 击退抗性 (0.0 = 完全击退, 1.0 = 完全免疫)
@export var knockback_resistance: float = 0.0

# ============================================================
# 节奏互动配置
# ============================================================
## 是否在弱拍移动（与玩家强拍施法形成错位感）
@export var move_on_offbeat: bool = true
## 完美卡拍攻击的额外击退倍率
@export var perfect_beat_knockback_multiplier: float = 2.5
## 完美卡拍攻击的额外伤害倍率
@export var perfect_beat_damage_multiplier: float = 1.5

# ============================================================
# 故障视觉配置
# ============================================================
## 基础故障强度（不同敌人类型可有不同基础值）
@export var base_glitch_intensity: float = 0.1
## 最大故障强度（HP 为 0 时）
@export var max_glitch_intensity: float = 1.0
## 故障闪烁频率
@export var glitch_flicker_speed: float = 0.03
## 敌人基础颜色
@export var base_color: Color = Color(1.0, 0.2, 0.3)

# ============================================================
# 节点引用
# ============================================================
@onready var _sprite: Node2D = $EnemyVisual
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _damage_area: Area2D = $DamageArea

# ============================================================
# 内部状态
# ============================================================
var current_hp: float = 50.0
var _target: Node2D = null
var _is_dead: bool = false

## 量化移动状态
var _quantize_timer: float = 0.0
var _quantize_interval: float = 1.0 / 12.0
var _last_quantized_position: Vector2 = Vector2.ZERO
var _movement_direction: Vector2 = Vector2.ZERO

## 节奏互动状态
var _is_on_beat: bool = false       ## 当前是否处于节拍时刻
var _is_on_offbeat: bool = false    ## 当前是否处于弱拍时刻
var _beat_energy: float = 0.0       ## 节拍能量（用于视觉脉冲）
var _can_move_this_tick: bool = true ## 本 tick 是否允许移动

## 故障视觉状态
var _glitch_intensity: float = 0.0          ## 当前故障强度 [0, 1]
var _hp_glitch_intensity: float = 0.0       ## 基于 HP 的故障强度
var _damage_flash_timer: float = 0.0        ## 受击闪白计时
var _pixel_dissolve_progress: float = 0.0   ## 死亡像素溶解进度
var _glitch_offset: Vector2 = Vector2.ZERO  ## 故障位移偏移

## 接触伤害冷却
var _contact_cooldown: float = 0.0
const CONTACT_COOLDOWN_TIME: float = 0.5

## 眩晕状态
var _stun_timer: float = 0.0
var _is_stunned: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_to_group("enemies")
	current_hp = max_hp
	_quantize_interval = 1.0 / quantized_fps
	_last_quantized_position = global_position

	_find_player()
	_connect_beat_signals()
	_register_audio_signals()
	_on_enemy_ready()

## 子类重写此方法以执行额外的初始化
func _on_enemy_ready() -> void:
	pass

## 由 EnemySpawner 在剧本模式下调用，设置精确参数
func initialize_scripted(params: Dictionary) -> void:
	if params.has("speed"):
		move_speed = params["speed"]
	if params.has("hp"):
		max_hp = params["hp"]
		current_hp = params["hp"]
	if params.has("damage"):
		contact_damage = params["damage"]
	if params.has("shield"):
		if has_method("set_shield"):
			call("set_shield", params["shield"])
		else:
			set_meta("shield_hp", params["shield"])
	if params.has("quantized_fps"):
		quantized_fps = params["quantized_fps"]
		_quantize_interval = 1.0 / quantized_fps
	# 标记为剧本敌人
	set_meta("scripted", true)

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if _is_dead:
		return

	# 眩晕处理
	if _is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_is_stunned = false
			_stun_timer = 0.0
		else:
			_update_visual(delta)
			return

	_update_target()
	_quantized_movement(delta)
	_update_visual(delta)
	_update_contact_damage(delta)
	_on_enemy_process(delta)

## 子类重写此方法以执行额外的每帧逻辑
func _on_enemy_process(_delta: float) -> void:
	pass

# ============================================================
# 节拍信号连接
# ============================================================

func _connect_beat_signals() -> void:
	if not GameManager.beat_tick.is_connected(_on_beat_tick):
		GameManager.beat_tick.connect(_on_beat_tick)
	if not GameManager.half_beat_tick.is_connected(_on_half_beat_tick):
		GameManager.half_beat_tick.connect(_on_half_beat_tick)

func _on_beat_tick(_beat_index: int) -> void:
	_is_on_beat = true
	_beat_energy = 1.0

	# 弱拍移动模式：强拍时不移动（与玩家施法错位）
	if move_on_offbeat:
		_can_move_this_tick = false

	# 节拍时的视觉脉冲
	_apply_beat_pulse()

	# 子类可重写的节拍回调
	_on_beat(_beat_index)

	# 延迟恢复移动（弱拍时恢复）
	get_tree().create_timer(_get_beat_interval() * 0.5).timeout.connect(func():
		_is_on_beat = false
		if move_on_offbeat:
			_can_move_this_tick = true
	)

func _on_half_beat_tick(_half_beat_index: int) -> void:
	_is_on_offbeat = not _is_on_beat

	# 非弱拍移动模式：弱拍时不移动
	if not move_on_offbeat:
		_can_move_this_tick = _is_on_beat

	# 子类可重写的半拍回调
	_on_half_beat(_half_beat_index)

## 子类重写：节拍时的特殊行为
func _on_beat(_beat_index: int) -> void:
	pass

## 子类重写：半拍时的特殊行为
func _on_half_beat(_half_beat_index: int) -> void:
	pass

func _get_beat_interval() -> float:
	return 60.0 / GameManager.current_bpm

# ============================================================
# 音效信号注册
# ============================================================

## 将敌人的信号注册到全局 AudioManager
## AudioManager 通过监听信号来播放对应音效，避免在敌人脚本中直接播放
func _register_audio_signals() -> void:
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("register_enemy"):
			audio_mgr.register_enemy(self, _get_type_name())

# ============================================================
# 量化步进移动
# ============================================================

func _quantized_movement(delta: float) -> void:
	_quantize_timer += delta

	if _quantize_timer >= _quantize_interval:
		_quantize_timer -= _quantize_interval

		if _target == null:
			return

		# 节奏互动：检查是否允许移动
		if not _can_move_this_tick and move_on_offbeat:
			return

		# 计算移动方向（子类可重写）
		_movement_direction = _calculate_movement_direction()

		if _movement_direction == Vector2.ZERO:
			return

		# 步进移动（非平滑，模拟低帧率的机械感）
		var step_distance := move_speed * _quantize_interval
		velocity = _movement_direction * move_speed
		move_and_slide()

		_last_quantized_position = global_position

		# 量化步进音效：每次位置跳变时播放机械卡顿声
		_play_quantized_step_sound()

## 播放量化步进移动音效
## 每次位置跳变时触发，让敌人移动听起来像坏掉的时钟
func _play_quantized_step_sound() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_enemy_move_sfx"):
		audio_mgr.play_enemy_move_sfx(_get_type_name(), global_position)

## 子类重写此方法以实现不同的移动逻辑
## 默认：直线追踪玩家
func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	return (_target.global_position - global_position).normalized()

# ============================================================
# 故障视觉系统 (Glitch Art Visual System)
# ============================================================

func _update_visual(delta: float) -> void:
	if _sprite == null:
		return

	# 1. 计算综合故障强度
	var hp_ratio := current_hp / max_hp
	_hp_glitch_intensity = (1.0 - hp_ratio) * max_glitch_intensity
	_glitch_intensity = base_glitch_intensity + _hp_glitch_intensity

	# 眩晕时故障加剧
	if _is_stunned:
		_glitch_intensity = min(_glitch_intensity + 0.4, 1.0)

	# 2. 节拍能量衰减
	_beat_energy = max(0.0, _beat_energy - delta * 4.0)

	# 3. 受击闪白衰减
	_damage_flash_timer = max(0.0, _damage_flash_timer - delta)

	# 4. 量化旋转（不平滑，锁定到 45° 增量）
	if _target and not _is_dead:
		var angle := (_target.global_position - global_position).angle()
		var quantized_angle := roundf(angle / (PI / 4.0)) * (PI / 4.0)
		_sprite.rotation = quantized_angle

	# 5. 故障闪烁（HP < 50% 时开始）
	if _glitch_intensity > 0.5:
		var flicker_wave := sin(Time.get_ticks_msec() * glitch_flicker_speed)
		var flicker_threshold := remap(_glitch_intensity, 0.5, 1.0, 0.8, 0.3)
		_sprite.visible = flicker_wave > 0.0 or randf() > flicker_threshold
	else:
		_sprite.visible = true

	# 6. 故障位移偏移（高故障时像素抖动）
	if _glitch_intensity > 0.3:
		var offset_strength := _glitch_intensity * 3.0
		if randf() < _glitch_intensity * 0.3:
			_glitch_offset = Vector2(
				randf_range(-offset_strength, offset_strength),
				randf_range(-offset_strength, offset_strength)
			)
		_sprite.position = _glitch_offset
	else:
		_sprite.position = Vector2.ZERO
		_glitch_offset = Vector2.ZERO

	# 7. 颜色计算
	var final_color := base_color
	# HP 越低，颜色越偏向白色（信号崩溃感）
	if hp_ratio < 0.5:
		var white_blend := remap(hp_ratio, 0.0, 0.5, 0.6, 0.0)
		final_color = final_color.lerp(Color.WHITE, white_blend)
	# 受击闪白
	if _damage_flash_timer > 0.0:
		var flash_ratio := _damage_flash_timer / 0.15
		final_color = final_color.lerp(Color.WHITE, flash_ratio)
	# 节拍脉冲亮度
	final_color = final_color.lerp(final_color * 1.3, _beat_energy * 0.3)

	_sprite.modulate = final_color

	# 8. 节拍脉冲缩放
	var pulse_scale := 1.0 + _beat_energy * 0.15
	_sprite.scale = Vector2(pulse_scale, pulse_scale)

func _apply_beat_pulse() -> void:
	if _sprite and not _is_dead:
		# 节拍时的瞬间放大效果
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.2, 1.2), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)

# ============================================================
# 伤害处理
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	if _is_dead:
		return

	# 完美卡拍攻击加成
	var final_damage := amount
	var final_knockback_force := 200.0

	if is_perfect_beat:
		final_damage *= perfect_beat_damage_multiplier
		final_knockback_force *= perfect_beat_knockback_multiplier
		_trigger_perfect_beat_glitch()

	current_hp -= final_damage
	enemy_damaged.emit(current_hp, max_hp, final_damage)

	# 击退（考虑击退抗性）
	if knockback_dir != Vector2.ZERO:
		var effective_knockback := final_knockback_force * (1.0 - knockback_resistance)
		velocity = knockback_dir * effective_knockback
		move_and_slide()

	# 受击视觉反馈
	_damage_flash_timer = 0.15

	# 受击故障抖动
	if _sprite:
		_glitch_offset = Vector2(
			randf_range(-4.0, 4.0),
			randf_range(-4.0, 4.0)
		)

	if current_hp <= 0.0:
		_die()

## 完美卡拍攻击的额外故障效果
func _trigger_perfect_beat_glitch() -> void:
	if _sprite == null:
		return
	# 瞬间强烈故障：缩放抖动 + 颜色反转
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(0.5, 1.5), 0.03)
	tween.tween_property(_sprite, "scale", Vector2(1.5, 0.5), 0.03)
	tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.06)

## 冻结敌人（停止移动和行为）
func set_frozen(frozen: bool) -> void:
	_is_stunned = frozen
	if frozen:
		_stun_timer = 999999.0  # 无限期冻结
		velocity = Vector2.ZERO
	else:
		_stun_timer = 0.0

## 施加眩晕
func apply_stun(duration: float) -> void:
	_is_stunned = true
	_stun_timer = duration
	enemy_stunned.emit(duration)

# ============================================================
# 死亡系统 — "信号崩溃"
# ============================================================

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true

	# 发出死亡信号（携带敌人类型信息）
	var type_name := _get_type_name()
	enemy_died.emit(global_position, xp_value, type_name)
	GameManager.enemy_killed.emit(global_position)

	# 子类的死亡效果（如 Screech 的不和谐爆发）
	_on_death_effect()

	# 执行死亡动画
	_play_death_animation()

## 子类重写：死亡时的特殊效果
func _on_death_effect() -> void:
	pass

func _play_death_animation() -> void:
	# 禁用碰撞和移动
	set_physics_process(false)
	if _collision:
		_collision.set_deferred("disabled", true)

	if _sprite == null:
		queue_free()
		return

	# 死亡动画：像素化碎裂 + 老式电视关机效果
	var tween := create_tween()
	tween.set_parallel(true)

	# 阶段1：瞬间膨胀 + 强烈闪烁 (0.0 ~ 0.1s)
	tween.tween_property(_sprite, "scale", Vector2(1.8, 0.3), 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.05)

	# 阶段2：压缩成线 + 淡出 (0.1 ~ 0.3s)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", Vector2(0.0, 0.0), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.2)

	# 完成后销毁
	tween.chain()
	tween.tween_callback(queue_free)

# ============================================================
# 接触伤害
# ============================================================

func _update_contact_damage(delta: float) -> void:
	if _contact_cooldown > 0.0:
		_contact_cooldown -= delta
		return

	if _target == null:
		return

	var dist := global_position.distance_to(_target.global_position)
	if dist < (collision_radius + 14.0):  # 接触距离 = 自身半径 + 玩家半径
		if _target.has_method("take_damage"):
			_target.take_damage(contact_damage, global_position)
			_contact_cooldown = CONTACT_COOLDOWN_TIME
			_on_contact_with_player()

## 子类重写：接触玩家时的特殊效果
func _on_contact_with_player() -> void:
	pass

# ============================================================
# 目标追踪
# ============================================================

func _find_player() -> void:
	_target = get_tree().get_first_node_in_group("player")

func _update_target() -> void:
	if _target == null or not is_instance_valid(_target):
		_find_player()

func get_target() -> Node2D:
	return _target

# ============================================================
# 碰撞数据接口（供 ProjectileManager 使用）
# ============================================================

func get_collision_data() -> Dictionary:
	return {
		"position": global_position,
		"radius": collision_radius,
		"node": self,
		"type": enemy_type,
		"hp_ratio": current_hp / max_hp if max_hp > 0.0 else 0.0,
	}

# ============================================================
# 工具函数
# ============================================================

func _get_type_name() -> String:
	match enemy_type:
		EnemyType.STATIC:  return "static"
		EnemyType.SILENCE: return "silence"
		EnemyType.SCREECH: return "screech"
		EnemyType.PULSE:   return "pulse"
		EnemyType.WALL:    return "wall"
		_:                 return "unknown"

func get_hp_ratio() -> float:
	return current_hp / max_hp if max_hp > 0.0 else 0.0

func is_alive() -> bool:
	return not _is_dead and current_hp > 0.0

## 获取当前故障强度（供 Shader 使用）
func get_glitch_intensity() -> float:
	return _glitch_intensity
