## ch1_frequency_sentinel.gd
## 第一章精英/小Boss：频率哨兵 (Frequency Sentinel)
## 毕达哥拉斯的执法者，一个由三角形和正弦波构成的高速巡逻者。
## 音乐隐喻：频率的守门人，检测并惩罚"不和谐"的存在。
## 机制：
## - 高速巡逻，沿正弦波轨迹移动
## - 检测玩家的"不和谐度"，不和谐度越高受到的伤害越大
## - 释放"频率锁定"光束追踪玩家
## - 狂暴时释放全方位频率扫描
extends "res://scripts/entities/enemies/elite_base.gd"

# ============================================================
# Frequency Sentinel 专属配置
# ============================================================
## 正弦波移动振幅
@export var sine_amplitude: float = 100.0
## 正弦波移动频率
@export var sine_frequency: float = 2.0
## 频率锁定光束伤害
@export var beam_damage: float = 15.0
## 频率锁定持续时间
@export var beam_duration: float = 1.5
## 频率扫描弹幕速度
@export var scan_projectile_speed: float = 280.0
## 频率扫描弹幕伤害
@export var scan_projectile_damage: float = 10.0
## 不和谐度伤害加成系数
@export var dissonance_damage_bonus: float = 2.0

# ============================================================
# 内部状态
# ============================================================
## 正弦波移动相位
var _sine_phase: float = 0.0
## 基准移动方向
var _base_move_direction: Vector2 = Vector2.RIGHT
## 是否正在释放光束
var _beam_active: bool = false
## 光束计时器
var _beam_timer: float = 0.0
## 扫描旋转角度
var _scan_angle: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _on_elite_ready() -> void:
	elite_name = "频率哨兵"
	elite_title = "Frequency Sentinel"
	
	# 数值
	max_hp = 250.0
	current_hp = 250.0
	move_speed = 75.0
	contact_damage = 10.0
	xp_value = 20
	
	# 视觉
	base_color = Color(0.2, 1.0, 0.6)
	aura_radius = 0.0  # 无光环
	
	# 高量化帧率（快速巡逻感）
	quantized_fps = 14.0
	_quantize_interval = 1.0 / quantized_fps
	
	# 中等击退抗性
	knockback_resistance = 0.4
	
	# 精英护盾
	_elite_shield = 30.0
	_elite_max_shield = 30.0

func _define_elite_attacks() -> void:
	_elite_attacks = [
		{
			"name": "frequency_lock",
			"duration": beam_duration,
			"cooldown": 4.0,
			"damage": beam_damage,
			"weight": 3.0,
		},
		{
			"name": "frequency_scan",
			"duration": 1.5,
			"cooldown": 5.0,
			"damage": scan_projectile_damage,
			"weight": 2.0,
		},
		{
			"name": "dissonance_punish",
			"duration": 0.5,
			"cooldown": 6.0,
			"damage": 20.0,
			"weight": 1.5,
		},
	]

# ============================================================
# 精英每帧逻辑
# ============================================================

func _on_elite_process(delta: float) -> void:
	# 正弦波移动相位更新
	_sine_phase += sine_frequency * delta
	
	# 光束更新
	if _beam_active:
		_beam_timer -= delta
		if _beam_timer <= 0.0:
			_beam_active = false
		else:
			_update_beam_damage(delta)
	
	# 视觉：正弦波轨迹效果
	if _sprite:
		var wave_offset := sin(_sine_phase * 3.0) * 3.0
		_sprite.position.y = wave_offset

# ============================================================
# 攻击实现
# ============================================================

func _perform_elite_attack(attack: Dictionary) -> void:
	match attack["name"]:
		"frequency_lock":
			_attack_frequency_lock(attack)
		"frequency_scan":
			_attack_frequency_scan(attack)
		"dissonance_punish":
			_attack_dissonance_punish(attack)

## 攻击1：频率锁定 — 向玩家发射追踪光束
func _attack_frequency_lock(attack: Dictionary) -> void:
	_beam_active = true
	_beam_timer = beam_duration
	
	# 蓄力视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.3, 0.3), 0.2)
		tween.tween_property(_sprite, "scale", Vector2(1.3, 1.3), 0.2)
	
	# 光束视觉（简化为线段）
	_spawn_beam_visual()

func _update_beam_damage(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	
	# 光束持续伤害
	var dist := global_position.distance_to(_target.global_position)
	if dist < 300.0:  # 光束射程
		var damage_per_sec := beam_damage / beam_duration
		if _target.has_method("take_damage"):
			_target.take_damage(damage_per_sec * delta)

func _spawn_beam_visual() -> void:
	if _target == null:
		return
	
	# 创建光束视觉线段
	var beam_line := Line2D.new()
	beam_line.width = 3.0
	beam_line.default_color = Color(1.0, 0.3, 0.3, 0.7)
	beam_line.add_point(Vector2.ZERO)
	beam_line.add_point(_target.global_position - global_position)
	add_child(beam_line)
	
	# 光束持续时间后消失
	var tween := beam_line.create_tween()
	tween.tween_property(beam_line, "modulate:a", 0.0, beam_duration)
	tween.tween_callback(beam_line.queue_free)

## 攻击2：频率扫描 — 旋转扇形弹幕
func _attack_frequency_scan(attack: Dictionary) -> void:
	var damage: float = attack.get("damage", scan_projectile_damage)
	var waves := 5
	var interval := 0.25
	
	for wave in range(waves):
		get_tree().create_timer(wave * interval).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			_scan_angle += 0.4
			# 发射 3 发扇形弹幕
			for i in range(3):
				var angle := _scan_angle + (i - 1) * 0.3
				_spawn_elite_projectile(
					global_position, angle, scan_projectile_speed,
					damage, Color(0.2, 1.0, 0.6, 0.8)
				)
		)
	
	# 视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(0.4, 1.0, 0.8), 0.1)
		tween.tween_property(_sprite, "modulate", base_color, 0.5)

## 攻击3：不和谐惩罚 — 基于玩家疲劳度的高伤害攻击
func _attack_dissonance_punish(attack: Dictionary) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	
	var base_damage: float = attack.get("damage", 20.0)
	
	# 获取玩家当前疲劳度/不和谐度
	var fatigue_level := 0.0
	if FatigueManager and FatigueManager.has_method("get_current_fatigue"):
		fatigue_level = FatigueManager.get_current_fatigue()
	
	# 不和谐度越高伤害越大
	var final_damage := base_damage * (1.0 + fatigue_level * dissonance_damage_bonus)
	
	# 向玩家发射一发高伤害追踪弹
	if _target:
		var angle := (global_position.direction_to(_target.global_position)).angle()
		_spawn_elite_projectile(
			global_position, angle, scan_projectile_speed * 1.5,
			final_damage, Color(1.0, 0.2, 0.8, 0.9)
		)
	
	# 惩罚视觉
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.0, 0.5), 0.1)
		tween.tween_property(_sprite, "scale", Vector2(2.0, 2.0), 0.1)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.3)
		tween.tween_property(_sprite, "modulate", base_color, 0.3)

# ============================================================
# 移动逻辑：正弦波巡逻
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	# 基础方向：朝向玩家
	var to_player := (_target.global_position - global_position).normalized()
	
	# 正弦波偏移
	var perpendicular := to_player.rotated(PI / 2.0)
	var sine_offset := sin(_sine_phase) * sine_amplitude * 0.01
	
	var final_dir := (to_player + perpendicular * sine_offset).normalized()
	
	# 保持中等距离
	var dist := global_position.distance_to(_target.global_position)
	if dist < 120.0:
		final_dir = -to_player  # 太近则后退
	
	return final_dir

# ============================================================
# 狂暴
# ============================================================

func _on_elite_enrage() -> void:
	move_speed *= 1.4
	sine_frequency *= 1.5
	
	# 攻击冷却减半
	for attack in _elite_attacks:
		attack["cooldown"] = attack.get("cooldown", 2.0) * 0.5
	
	# 视觉
	base_color = Color(1.0, 0.4, 0.2)
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(_sprite, "modulate", base_color, 0.3)

# ============================================================
# 精英死亡效果
# ============================================================

func _on_elite_death_effect() -> void:
	# 死亡时释放全方位频率脉冲
	for i in range(12):
		var angle := (TAU / 12) * i
		_spawn_elite_projectile(
			global_position, angle, scan_projectile_speed * 0.5,
			scan_projectile_damage * 0.5, Color(0.2, 1.0, 0.6, 0.5)
		)

func _get_type_name() -> String:
	return "frequency_sentinel"
