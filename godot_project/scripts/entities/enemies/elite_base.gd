## elite_base.gd
## 精英敌人基类 — 小 Boss / 精英怪
## 介于普通敌人与章节 Boss 之间的中等威胁。
## 在生存者波次中周期性出现，拥有独特机制和更高数值。
##
## 特性：
## - 继承 enemy_base.gd，复用量化移动、故障视觉等基础系统
## - 新增精英专属光环和被动效果
## - 新增多攻击模式切换
## - 击败后掉落更高价值奖励
## - 显示精英血条 UI
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# 精英专属信号
# ============================================================
signal elite_defeated(position: Vector2, elite_type: String)
signal elite_ability_used(ability_name: String)
signal elite_enraged()

# ============================================================
# 精英配置
# ============================================================
## 精英名称（显示在血条上）
@export var elite_name: String = "Unknown Elite"
## 精英称号
@export var elite_title: String = ""
## 是否显示精英血条
@export var show_elite_bar: bool = true
## 精英光环半径（0 = 无光环）
@export var aura_radius: float = 0.0
## 精英光环颜色
@export var aura_color: Color = Color(1.0, 0.8, 0.2, 0.15)

# ============================================================
# 精英攻击模式
# ============================================================
## 攻击模式列表（子类通过 _define_elite_attacks() 填充）
var _elite_attacks: Array[Dictionary] = []
## 当前攻击索引
var _elite_attack_index: int = 0
## 攻击冷却
var _elite_attack_cooldown: float = 0.0
## 是否正在执行攻击
var _elite_is_attacking: bool = false

# ============================================================
# 精英状态
# ============================================================
## 是否已进入狂暴（HP < 30%）
var _elite_enraged: bool = false
## 狂暴 HP 阈值
var _enrage_threshold: float = 0.3
## 精英护盾
var _elite_shield: float = 0.0
var _elite_max_shield: float = 0.0
## 弹幕容器
var _elite_projectile_container: Node2D = null

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	# 精英使用较低量化帧率（更具威压感）
	quantized_fps = 8.0
	_quantize_interval = 1.0 / quantized_fps
	
	# 较高击退抗性
	knockback_resistance = 0.5
	
	# 精英不使用弱拍移动
	move_on_offbeat = false
	
	# 较高故障基础值
	base_glitch_intensity = 0.12
	max_glitch_intensity = 0.9
	
	# 创建弹幕容器
	_elite_projectile_container = Node2D.new()
	_elite_projectile_container.name = "EliteProjectiles"
	add_child(_elite_projectile_container)
	
	# 子类定义攻击
	_define_elite_attacks()
	
	# 子类额外初始化
	_on_elite_ready()

## 子类重写：精英专属初始化
func _on_elite_ready() -> void:
	pass

## 子类重写：定义精英攻击模式
## 每个攻击是一个 Dictionary：
## {
##   "name": String,        # 攻击名称
##   "duration": float,     # 攻击持续时间
##   "cooldown": float,     # 攻击冷却
##   "damage": float,       # 基础伤害
##   "weight": float,       # 选择权重
## }
func _define_elite_attacks() -> void:
	pass

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	if _is_dead:
		return
	
	# 攻击模式更新
	_update_elite_attacks(delta)
	
	# 狂暴检查
	_check_elite_enrage()
	
	# 精英光环效果
	_update_elite_aura(delta)
	
	# 精英视觉
	_update_elite_visual(delta)
	
	# 子类每帧逻辑
	_on_elite_process(delta)

## 子类重写：精英专属每帧逻辑
func _on_elite_process(_delta: float) -> void:
	pass

# ============================================================
# 攻击系统
# ============================================================

func _update_elite_attacks(delta: float) -> void:
	if _elite_is_attacking:
		return
	
	_elite_attack_cooldown -= delta
	if _elite_attack_cooldown <= 0.0:
		_execute_elite_attack()

func _execute_elite_attack() -> void:
	if _elite_attacks.is_empty():
		return
	
	var attack := _select_elite_attack()
	if attack.is_empty():
		return
	
	_elite_is_attacking = true
	elite_ability_used.emit(attack.get("name", "unknown"))
	
	# 执行攻击（子类实现）
	_perform_elite_attack(attack)
	
	# 攻击结束后冷却
	var duration: float = attack.get("duration", 1.0)
	var cooldown: float = attack.get("cooldown", 2.0)
	
	get_tree().create_timer(duration).timeout.connect(func():
		_elite_is_attacking = false
		_elite_attack_cooldown = cooldown
		_elite_attack_index = (_elite_attack_index + 1) % _elite_attacks.size()
	)

func _select_elite_attack() -> Dictionary:
	if _elite_attacks.is_empty():
		return {}
	
	# 加权随机选择
	var total_weight := 0.0
	for attack in _elite_attacks:
		total_weight += attack.get("weight", 1.0)
	
	var roll := randf() * total_weight
	var cumulative := 0.0
	for attack in _elite_attacks:
		cumulative += attack.get("weight", 1.0)
		if roll <= cumulative:
			return attack
	
	return _elite_attacks[-1]

## 子类重写：执行具体攻击逻辑
func _perform_elite_attack(_attack: Dictionary) -> void:
	pass

# ============================================================
# 狂暴系统
# ============================================================

func _check_elite_enrage() -> void:
	if _elite_enraged:
		return
	
	var hp_ratio := current_hp / max_hp
	if hp_ratio <= _enrage_threshold:
		_elite_enraged = true
		elite_enraged.emit()
		_on_elite_enrage()

## 子类重写：狂暴时的特殊行为
func _on_elite_enrage() -> void:
	# 默认：加速 + 攻击冷却减半
	move_speed *= 1.3
	for attack in _elite_attacks:
		attack["cooldown"] = attack.get("cooldown", 2.0) * 0.6
	
	# 狂暴视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(_sprite, "modulate", base_color.lerp(Color(1.0, 0.2, 0.0), 0.4), 0.3)

# ============================================================
# 光环系统
# ============================================================

func _update_elite_aura(_delta: float) -> void:
	if aura_radius <= 0.0 or _target == null:
		return
	
	var dist := global_position.distance_to(_target.global_position)
	if dist < aura_radius:
		_apply_aura_effect(_target, dist)

## 子类重写：光环效果
func _apply_aura_effect(_target_node: Node2D, _distance: float) -> void:
	pass

# ============================================================
# 精英视觉
# ============================================================

func _update_elite_visual(_delta: float) -> void:
	if _sprite == null:
		return
	
	# 精英光环视觉脉冲
	if aura_radius > 0.0:
		var pulse := sin(Time.get_ticks_msec() * 0.003) * 0.1
		# 光环效果通过 modulate 叠加
		var aura_blend := aura_color.a * (0.5 + pulse)
		_sprite.modulate = _sprite.modulate.lerp(aura_color, aura_blend * 0.1)
	
	# 狂暴视觉
	if _elite_enraged:
		var rage_pulse := sin(Time.get_ticks_msec() * 0.008) * 0.15
		_sprite.modulate = _sprite.modulate.lerp(Color(1.0, 0.2, 0.0), 0.2 + rage_pulse)

# ============================================================
# 伤害处理（精英重写）
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	if _is_dead:
		return
	
	var final_damage := amount
	if is_perfect_beat:
		final_damage *= perfect_beat_damage_multiplier
	
	# 精英护盾吸收
	if _elite_shield > 0.0:
		var absorbed := min(_elite_shield, final_damage)
		_elite_shield -= absorbed
		final_damage -= absorbed
	
	# 应用伤害
	if final_damage > 0.0:
		current_hp -= final_damage
		enemy_damaged.emit(current_hp, max_hp, final_damage)
	
	# 击退（考虑抗性）
	if knockback_dir != Vector2.ZERO:
		var effective_knockback := 150.0 * (1.0 - knockback_resistance)
		if is_perfect_beat:
			effective_knockback *= perfect_beat_knockback_multiplier
		velocity = knockback_dir * effective_knockback
		move_and_slide()
	
	_damage_flash_timer = 0.15
	
	if current_hp <= 0.0:
		_elite_die()

# ============================================================
# 精英死亡
# ============================================================

func _elite_die() -> void:
	if _is_dead:
		return
	_is_dead = true
	
	_elite_is_attacking = false
	elite_defeated.emit(global_position, _get_type_name())
	
	# 精英死亡效果
	_on_elite_death_effect()
	
	# 通知系统
	enemy_died.emit(global_position, xp_value, _get_type_name())
	GameManager.enemy_killed.emit(global_position)
	
	# 华丽死亡动画
	_play_elite_death_animation()

## 子类重写：精英死亡特殊效果
func _on_elite_death_effect() -> void:
	pass

func _play_elite_death_animation() -> void:
	set_physics_process(false)
	if _collision:
		_collision.set_deferred("disabled", true)
	
	if _sprite == null:
		queue_free()
		return
	
	var tween := create_tween()
	# 膨胀 + 闪白
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", Vector2(2.5, 2.5), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.2)
	# 抖动
	tween.chain()
	for i in range(4):
		var offset := Vector2(randf_range(-6, 6), randf_range(-6, 6))
		tween.tween_property(_sprite, "position", offset, 0.04)
	# 压缩消散
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", Vector2(0.0, 0.0), 0.25)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.25)
	tween.chain()
	tween.tween_callback(queue_free)

# ============================================================
# 精英弹幕生成（通用工具）
# ============================================================

func _spawn_elite_projectile(pos: Vector2, angle: float, speed: float, damage: float, color: Color = Color.WHITE) -> void:
	var proj := Area2D.new()
	proj.add_to_group("elite_projectiles")
	proj.collision_layer = 8
	proj.collision_mask = 1
	
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-4, -4), Vector2(8, 0), Vector2(-4, 4)
	])
	visual.color = color if color != Color.WHITE else base_color.lerp(Color.WHITE, 0.3)
	visual.rotation = angle
	proj.add_child(visual)
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	col.shape = shape
	proj.add_child(col)
	
	proj.global_position = pos
	proj.set_meta("velocity", Vector2.from_angle(angle) * speed)
	proj.set_meta("damage", damage)
	proj.set_meta("lifetime", 5.0)
	proj.set_meta("age", 0.0)
	
	if _elite_projectile_container and is_instance_valid(_elite_projectile_container):
		_elite_projectile_container.add_child(proj)
	else:
		get_parent().add_child(proj)
	
	var move_callable := func():
		if not is_instance_valid(proj):
			return
		var vel: Vector2 = proj.get_meta("velocity")
		proj.global_position += vel * get_process_delta_time()
		var age: float = proj.get_meta("age") + get_process_delta_time()
		proj.set_meta("age", age)
		if age >= proj.get_meta("lifetime"):
			proj.queue_free()
			return
		if _target and is_instance_valid(_target):
			var dist := proj.global_position.distance_to(_target.global_position)
			if dist < 18.0:
				if _target.has_method("take_damage"):
					_target.take_damage(proj.get_meta("damage"))
				proj.queue_free()
	
	get_tree().process_frame.connect(move_callable)
	proj.tree_exiting.connect(func():
		if get_tree().process_frame.is_connected(move_callable):
			get_tree().process_frame.disconnect(move_callable)
	)

# ============================================================
# 精英血条数据接口
# ============================================================

func get_elite_bar_data() -> Dictionary:
	return {
		"name": elite_name,
		"title": elite_title,
		"hp": current_hp,
		"max_hp": max_hp,
		"hp_ratio": current_hp / max_hp if max_hp > 0.0 else 0.0,
		"shield": _elite_shield,
		"max_shield": _elite_max_shield,
		"is_enraged": _elite_enraged,
	}

# ============================================================
# 清理
# ============================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _elite_projectile_container and is_instance_valid(_elite_projectile_container):
			for child in _elite_projectile_container.get_children():
				if is_instance_valid(child):
					child.queue_free()
