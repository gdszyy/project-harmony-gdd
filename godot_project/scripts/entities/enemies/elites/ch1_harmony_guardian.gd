## ch1_harmony_guardian.gd
## 第一章精英/小Boss：和谐守卫 (Harmony Guardian)
## 毕达哥拉斯的护卫者，一个由同心光环构成的中型几何体。
## 音乐隐喻：纯律音程的守护者，以完美的数学比例攻击。
## 机制：
## - 生成"和谐力场"，场内敌人获得护盾
## - 以纯律比例（2:1, 3:2, 4:3）发射弹幕
## - 狂暴时力场扩大并开始造成伤害
extends "res://scripts/entities/enemies/elite_base.gd"

# ============================================================
# Harmony Guardian 专属配置
# ============================================================
## 和谐力场半径
@export var harmony_field_radius: float = 150.0
## 力场内敌人护盾加成
@export var field_shield_bonus: float = 15.0
## 力场脉冲间隔（秒）
@export var field_pulse_interval: float = 2.0
## 共振弹幕速度
@export var resonance_projectile_speed: float = 200.0
## 共振弹幕伤害
@export var resonance_projectile_damage: float = 12.0
## 旋转速度
@export var orbit_speed: float = 0.8

# ============================================================
# 内部状态
# ============================================================
## 光环旋转角度
var _ring_rotation: float = 0.0
## 力场脉冲计时器
var _field_pulse_timer: float = 0.0
## 共振攻击计数器（用于纯律比例循环）
var _resonance_counter: int = 0
## 纯律比例序列：八度(2:1=8弹), 五度(3:2=6弹), 四度(4:3=4弹)
const PURE_RATIOS: Array = [
	{"name": "octave", "count": 8, "spread": TAU},
	{"name": "fifth", "count": 6, "spread": TAU * 0.75},
	{"name": "fourth", "count": 4, "spread": TAU * 0.5},
]

# ============================================================
# 初始化
# ============================================================

func _on_elite_ready() -> void:
	elite_name = "和谐守卫"
	elite_title = "Harmony Guardian"
	
	# 数值
	max_hp = 350.0
	current_hp = 350.0
	move_speed = 40.0
	contact_damage = 12.0
	xp_value = 25
	
	# 视觉
	base_color = Color(0.3, 0.5, 1.0)
	aura_radius = harmony_field_radius
	aura_color = Color(0.3, 0.5, 1.0, 0.12)
	
	# 量化帧率（庄严感）
	quantized_fps = 8.0
	_quantize_interval = 1.0 / quantized_fps
	
	# 击退抗性
	knockback_resistance = 0.6
	
	# 精英护盾
	_elite_shield = 50.0
	_elite_max_shield = 50.0

func _define_elite_attacks() -> void:
	_elite_attacks = [
		{
			"name": "resonance_burst",
			"duration": 0.8,
			"cooldown": 3.0,
			"damage": resonance_projectile_damage,
			"weight": 3.0,
		},
		{
			"name": "harmony_pulse",
			"duration": 0.5,
			"cooldown": 5.0,
			"damage": 8.0,
			"weight": 2.0,
		},
		{
			"name": "ratio_barrage",
			"duration": 2.0,
			"cooldown": 6.0,
			"damage": resonance_projectile_damage * 0.7,
			"weight": 1.5,
		},
	]

# ============================================================
# 精英每帧逻辑
# ============================================================

func _on_elite_process(delta: float) -> void:
	# 光环旋转
	_ring_rotation += orbit_speed * delta
	
	# 力场脉冲
	_field_pulse_timer += delta
	if _field_pulse_timer >= field_pulse_interval:
		_field_pulse_timer = 0.0
		_apply_harmony_field()
	
	# 旋转视觉
	if _sprite:
		_sprite.rotation = _ring_rotation

# ============================================================
# 攻击实现
# ============================================================

func _perform_elite_attack(attack: Dictionary) -> void:
	match attack["name"]:
		"resonance_burst":
			_attack_resonance_burst(attack)
		"harmony_pulse":
			_attack_harmony_pulse(attack)
		"ratio_barrage":
			_attack_ratio_barrage(attack)

## 攻击1：共振爆发 — 以纯律比例发射弹幕
func _attack_resonance_burst(attack: Dictionary) -> void:
	var ratio_data: Dictionary = PURE_RATIOS[_resonance_counter % PURE_RATIOS.size()]
	_resonance_counter += 1
	
	var count: int = ratio_data["count"]
	var spread: float = ratio_data["spread"]
	var damage: float = attack.get("damage", resonance_projectile_damage)
	
	# 向玩家方向的扇形弹幕
	var base_angle := 0.0
	if _target:
		base_angle = (global_position.direction_to(_target.global_position)).angle()
	
	for i in range(count):
		var t := float(i) / float(max(1, count - 1))
		var angle := base_angle - spread / 2.0 + spread * t
		if count == 1:
			angle = base_angle
		_spawn_elite_projectile(
			global_position, angle, resonance_projectile_speed,
			damage, Color(0.4, 0.6, 1.0, 0.9)
		)
	
	# 视觉反馈
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.8, 1.8), 0.1)
		tween.tween_property(_sprite, "modulate", Color(0.5, 0.7, 1.0), 0.1)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.3)
		tween.tween_property(_sprite, "modulate", base_color, 0.3)

## 攻击2：和谐脉冲 — 力场爆发伤害
func _attack_harmony_pulse(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", 8.0)
	
	# 力场范围内的玩家受到伤害
	if _target and is_instance_valid(_target):
		var dist := global_position.distance_to(_target.global_position)
		if dist < harmony_field_radius:
			var falloff := 1.0 - (dist / harmony_field_radius)
			if _target.has_method("take_damage"):
				_target.take_damage(damage * falloff)
	
	# 脉冲视觉
	_spawn_harmony_pulse_visual()

## 攻击3：比例弹幕 — 连续发射多轮纯律弹幕
func _attack_ratio_barrage(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", resonance_projectile_damage * 0.7)
	
	# 三轮弹幕，每轮间隔 0.5 秒
	for wave in range(3):
		get_tree().create_timer(wave * 0.5).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			var ratio_data: Dictionary = PURE_RATIOS[wave % PURE_RATIOS.size()]
			var count: int = ratio_data["count"]
			var angle_offset := _ring_rotation + wave * 0.3
			
			for i in range(count):
				var angle := (TAU / count) * i + angle_offset
				_spawn_elite_projectile(
					global_position, angle, resonance_projectile_speed * 0.8,
					damage, Color(0.5, 0.7, 1.0, 0.8)
				)
		)

# ============================================================
# 和谐力场
# ============================================================

func _apply_harmony_field() -> void:
	# 为力场范围内的敌人提供临时护盾
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < harmony_field_radius:
			# 通过临时增加 HP 模拟护盾效果
			if enemy.has_method("set"):
				var cur_hp: float = enemy.get("current_hp")
				var max_hp_val: float = enemy.get("max_hp")
				if cur_hp < max_hp_val:
					enemy.set("current_hp", min(cur_hp + field_shield_bonus * 0.3, max_hp_val))

func _spawn_harmony_pulse_visual() -> void:
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(32):
		var angle := (TAU / 32) * i
		points.append(Vector2.from_angle(angle) * 10.0)
	ring.polygon = points
	ring.color = Color(0.3, 0.5, 1.0, 0.5)
	ring.global_position = global_position
	get_parent().add_child(ring)
	
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(harmony_field_radius / 10.0, harmony_field_radius / 10.0), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.chain()
	tween.tween_callback(ring.queue_free)

# ============================================================
# 光环效果：力场内玩家受到减速
# ============================================================

func _apply_aura_effect(_target_node: Node2D, distance: float) -> void:
	# 力场内增加玩家疲劳
	var intensity := 1.0 - (distance / harmony_field_radius)
	if FatigueManager and FatigueManager.has_method("add_external_fatigue"):
		FatigueManager.add_external_fatigue(0.02 * intensity * get_process_delta_time())

# ============================================================
# 狂暴
# ============================================================

func _on_elite_enrage() -> void:
	# 力场扩大
	harmony_field_radius *= 1.5
	aura_radius = harmony_field_radius
	
	# 攻击加速
	move_speed *= 1.3
	for attack in _elite_attacks:
		attack["cooldown"] = attack.get("cooldown", 2.0) * 0.5
	
	# 视觉
	base_color = Color(0.5, 0.3, 1.0)
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)
		tween.tween_property(_sprite, "modulate", base_color, 0.4)

# ============================================================
# 移动逻辑：绕圈移动
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	var to_player := _target.global_position - global_position
	var dist := to_player.length()
	var preferred_distance := 200.0
	
	if dist > preferred_distance + 40.0:
		return to_player.normalized()
	elif dist < preferred_distance - 40.0:
		return -to_player.normalized()
	else:
		return to_player.normalized().rotated(PI / 2.0)

# ============================================================
# 精英死亡效果
# ============================================================

func _on_elite_death_effect() -> void:
	# 死亡时释放最后一次大范围和谐脉冲（但对玩家无害，纯视觉）
	_spawn_harmony_pulse_visual()

func _get_type_name() -> String:
	return "harmony_guardian"
