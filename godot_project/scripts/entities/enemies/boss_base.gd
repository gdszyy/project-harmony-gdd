## boss_base.gd
## Boss 敌人基类 (Issue #27)
## 所有 Boss 继承此类，提供多阶段行为框架、音乐系统深度集成、
## 独特攻击模式管理和 Boss 战专属视觉效果。
##
## 设计理念：
## Boss 是"不和谐"的终极具象化 — 一首"失控的交响乐"。
## 每个 Boss 都有多个"乐章"（Phase），每个乐章有独特的攻击模式和音乐主题。
## Boss 战的核心体验是"用和谐征服混沌"。
##
## 架构：
## - 继承 enemy_base.gd，复用量化移动、故障视觉等基础系统
## - 新增多阶段状态机（Phase System）
## - 新增攻击模式管理器（Attack Pattern Manager）
## - 新增 Boss 专属信号（阶段转换、弱点暴露等）
## - 与 BGMManager 深度集成（阶段切换触发音乐变化）
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Boss 专属信号
# ============================================================
signal boss_phase_changed(phase_index: int, phase_name: String)
signal boss_enraged(enrage_level: int)
signal boss_vulnerability_started(duration: float)
signal boss_vulnerability_ended()
signal boss_defeated()
signal boss_attack_started(attack_name: String)
signal boss_attack_ended(attack_name: String)
signal boss_summon_minions(count: int, type: String)

# ============================================================
# Boss 阶段定义
# ============================================================
## 每个阶段的配置数据
## 子类通过 _define_phases() 填充此数组
var _phase_configs: Array[Dictionary] = []

## 当前阶段索引
var _current_phase: int = 0

## 阶段转换中标志
var _is_transitioning: bool = false

## 阶段转换动画持续时间
var _transition_duration: float = 2.0

# ============================================================
# Boss 配置
# ============================================================
## Boss 名称
@export var boss_name: String = "Unknown Conductor"

## Boss 标题（显示在血条下方）
@export var boss_title: String = "The Dissonant Maestro"

## 是否显示 Boss 血条 UI
@export var show_boss_bar: bool = true

## 狂暴计时器（超时后进入狂暴状态）
@export var enrage_time: float = 180.0

## 共鸣碎片掉落量（局外货币）
@export var resonance_fragment_drop: int = 50

# ============================================================
# 攻击模式系统
# ============================================================
## 当前阶段的攻击模式列表
var _attack_patterns: Array[Dictionary] = []

## 当前正在执行的攻击
var _current_attack: Dictionary = {}

## 攻击冷却计时器
var _attack_cooldown: float = 0.0

## 攻击序列索引（用于固定攻击循环）
var _attack_sequence_index: int = 0

## 是否正在执行攻击
var _is_attacking: bool = false

# ============================================================
# Boss 状态
# ============================================================
## 狂暴等级 (0 = 正常, 1 = 轻度狂暴, 2 = 完全狂暴)
var _enrage_level: int = 0
var _enrage_timer: float = 0.0

## 脆弱状态（Boss 在特定时机暴露弱点）
var _is_vulnerable: bool = false
var _vulnerability_timer: float = 0.0
var _vulnerability_damage_multiplier: float = 2.0

## 护盾系统
var _shield_hp: float = 0.0
var _max_shield_hp: float = 0.0
var _shield_active: bool = false
var _shield_regen_timer: float = 0.0
var _shield_regen_delay: float = 5.0
var _shield_regen_rate: float = 10.0

## Boss 战开始标志
var _boss_fight_started: bool = false

## 小兵召唤冷却
var _summon_cooldown: float = 0.0
var _summon_cooldown_time: float = 15.0

## 节拍计数器（用于节拍同步攻击）
var _boss_beat_counter: int = 0

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	# Boss 使用较低的量化帧率（更具威压感）
	quantized_fps = 6.0
	_quantize_interval = 1.0 / quantized_fps
	
	# Boss 高击退抗性
	knockback_resistance = 0.7
	
	# Boss 不使用弱拍移动（有自己的节奏模式）
	move_on_offbeat = false
	
	# 高故障基础值
	base_glitch_intensity = 0.15
	max_glitch_intensity = 1.0
	
	# 子类定义阶段
	_define_phases()
	
	# 初始化第一阶段
	if _phase_configs.size() > 0:
		_enter_phase(0)
	
	# 子类额外初始化
	_on_boss_ready()

## 子类重写：Boss 专属初始化
func _on_boss_ready() -> void:
	pass

## 子类重写：定义 Boss 的所有阶段
## 每个阶段是一个 Dictionary：
## {
##   "name": String,          # 阶段名称
##   "hp_threshold": float,   # HP 百分比阈值（低于此值进入下一阶段）
##   "speed_mult": float,     # 速度倍率
##   "damage_mult": float,    # 伤害倍率
##   "attacks": Array,        # 攻击模式列表
##   "shield_hp": float,      # 护盾 HP（0 = 无护盾）
##   "music_layer": String,   # 音乐层名称（用于 BGM 切换）
##   "color": Color,          # 阶段主题颜色
##   "summon_enabled": bool,  # 是否可以召唤小兵
## }
func _define_phases() -> void:
	pass

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	if _is_dead or _is_transitioning:
		return
	
	# 狂暴计时
	_update_enrage(delta)
	
	# 脆弱状态
	_update_vulnerability(delta)
	
	# 护盾恢复
	_update_shield(delta)
	
	# 攻击模式
	_update_attacks(delta)
	
	# 小兵召唤
	_update_summon(delta)
	
	# 阶段检查
	_check_phase_transition()
	
	# Boss 专属视觉
	_update_boss_visual(delta)
	
	# 子类每帧逻辑
	_on_boss_process(delta)

## 子类重写：Boss 专属每帧逻辑
func _on_boss_process(_delta: float) -> void:
	pass

# ============================================================
# 阶段系统
# ============================================================

func _check_phase_transition() -> void:
	if _is_transitioning:
		return
	
	var hp_ratio := current_hp / max_hp
	
	# 检查是否需要进入下一阶段
	var next_phase := _current_phase + 1
	if next_phase < _phase_configs.size():
		var threshold: float = _phase_configs[next_phase].get("hp_threshold", 0.0)
		if hp_ratio <= threshold:
			_start_phase_transition(next_phase)

func _start_phase_transition(new_phase: int) -> void:
	_is_transitioning = true
	_is_attacking = false
	
	# 阶段转换动画
	_play_phase_transition_animation(new_phase)
	
	# 延迟后进入新阶段
	get_tree().create_timer(_transition_duration).timeout.connect(func():
		_enter_phase(new_phase)
		_is_transitioning = false
	)

func _enter_phase(phase_index: int) -> void:
	if phase_index >= _phase_configs.size():
		return
	
	_current_phase = phase_index
	var config: Dictionary = _phase_configs[phase_index]
	
	# 应用阶段配置
	var speed_mult: float = config.get("speed_mult", 1.0)
	move_speed = move_speed * speed_mult
	
	# 设置护盾
	_max_shield_hp = config.get("shield_hp", 0.0)
	_shield_hp = _max_shield_hp
	_shield_active = _max_shield_hp > 0.0
	
	# 设置攻击模式
	_attack_patterns = config.get("attacks", [])
	_attack_sequence_index = 0
	_attack_cooldown = 1.0  # 阶段开始后短暂冷却
	
	# 更新颜色
	var phase_color: Color = config.get("color", base_color)
	base_color = phase_color
	
	# 通知音乐系统切换层
	var music_layer: String = config.get("music_layer", "")
	if music_layer != "":
		_notify_music_change(music_layer)
	
	# 发出信号
	var phase_name: String = config.get("name", "Phase %d" % (phase_index + 1))
	boss_phase_changed.emit(phase_index, phase_name)
	
	# 子类回调
	_on_phase_entered(phase_index, config)

## 子类重写：阶段进入时的特殊逻辑
func _on_phase_entered(_phase_index: int, _config: Dictionary) -> void:
	pass

func _play_phase_transition_animation(new_phase: int) -> void:
	if _sprite == null:
		return
	
	var config: Dictionary = _phase_configs[new_phase]
	var new_color: Color = config.get("color", Color.WHITE)
	
	# 阶段转换动画：强烈闪烁 + 膨胀 + 颜色变化
	var tween := create_tween()
	
	# 阶段1：膨胀 + 闪白 (0.0 ~ 0.5s)
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", Vector2(2.0, 2.0), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.2)
	
	# 阶段2：收缩 + 新颜色 (0.5 ~ 1.0s)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", Vector2(0.5, 0.5), 0.2).set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, "modulate", new_color, 0.3)
	
	# 阶段3：恢复正常 + 脉冲 (1.0 ~ 2.0s)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", Vector2(1.5, 1.5), 0.3).set_ease(Tween.EASE_OUT)
	tween.chain()
	tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.3)

# ============================================================
# 攻击模式系统
# ============================================================

func _update_attacks(delta: float) -> void:
	if _is_attacking:
		return
	
	_attack_cooldown -= delta
	if _attack_cooldown <= 0.0:
		_execute_next_attack()

func _execute_next_attack() -> void:
	if _attack_patterns.is_empty():
		return
	
	# 选择下一个攻击
	var attack: Dictionary = _select_attack()
	if attack.is_empty():
		return
	
	_current_attack = attack
	_is_attacking = true
	
	var attack_name: String = attack.get("name", "unknown")
	boss_attack_started.emit(attack_name)
	
	# 执行攻击（子类实现具体逻辑）
	_perform_attack(attack)
	
	# 攻击结束后的冷却
	var duration: float = attack.get("duration", 1.0)
	var cooldown: float = attack.get("cooldown", 2.0)
	
	get_tree().create_timer(duration).timeout.connect(func():
		_is_attacking = false
		_attack_cooldown = cooldown
		boss_attack_ended.emit(attack_name)
		_attack_sequence_index = (_attack_sequence_index + 1) % _attack_patterns.size()
	)

func _select_attack() -> Dictionary:
	if _attack_patterns.is_empty():
		return {}
	
	var config: Dictionary = _phase_configs[_current_phase] if _current_phase < _phase_configs.size() else {}
	var selection_mode: String = config.get("attack_selection", "sequence")
	
	match selection_mode:
		"sequence":
			# 固定序列循环
			return _attack_patterns[_attack_sequence_index % _attack_patterns.size()]
		"random":
			# 加权随机
			return _weighted_attack_select()
		"adaptive":
			# 自适应选择（根据玩家位置等）
			return _adaptive_attack_select()
		_:
			return _attack_patterns[0]

func _weighted_attack_select() -> Dictionary:
	var total_weight := 0.0
	for attack in _attack_patterns:
		total_weight += attack.get("weight", 1.0)
	
	var roll := randf() * total_weight
	var cumulative := 0.0
	for attack in _attack_patterns:
		cumulative += attack.get("weight", 1.0)
		if roll <= cumulative:
			return attack
	
	return _attack_patterns[-1]

func _adaptive_attack_select() -> Dictionary:
	if _target == null:
		return _attack_patterns[0] if _attack_patterns.size() > 0 else {}
	
	var dist := global_position.distance_to(_target.global_position)
	
	# 根据距离选择攻击
	for attack in _attack_patterns:
		var min_range: float = attack.get("min_range", 0.0)
		var max_range: float = attack.get("max_range", 99999.0)
		if dist >= min_range and dist <= max_range:
			return attack
	
	return _attack_patterns[0] if _attack_patterns.size() > 0 else {}

## 子类重写：执行具体攻击逻辑
func _perform_attack(_attack: Dictionary) -> void:
	pass

# ============================================================
# 伤害处理（Boss 重写）
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	if _is_dead or _is_transitioning:
		return
	
	var final_damage := amount
	
	# 完美卡拍加成
	if is_perfect_beat:
		final_damage *= perfect_beat_damage_multiplier
	
	# 脆弱状态加成
	if _is_vulnerable:
		final_damage *= _vulnerability_damage_multiplier
	
	# 护盾吸收
	if _shield_active and _shield_hp > 0.0:
		var absorbed = min(_shield_hp, final_damage)
		_shield_hp -= absorbed
		final_damage -= absorbed
		_shield_regen_timer = 0.0  # 重置护盾恢复计时
		
		if _shield_hp <= 0.0:
			_shield_active = false
			_on_shield_broken()
	
	# 应用伤害
	if final_damage > 0.0:
		current_hp -= final_damage
		enemy_damaged.emit(current_hp, max_hp, final_damage)
	
	# Boss 击退减弱
	if knockback_dir != Vector2.ZERO:
		var effective_knockback := 100.0 * (1.0 - knockback_resistance)
		velocity = knockback_dir * effective_knockback
		move_and_slide()
	
	# 受击视觉
	_damage_flash_timer = 0.15
	
	if current_hp <= 0.0:
		_boss_die()

## 护盾被击破时的回调
func _on_shield_broken() -> void:
	# 进入短暂脆弱状态
	_start_vulnerability(3.0)
	
	# 视觉效果：护盾碎裂
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.5, 0.5), 0.1)
		tween.tween_property(_sprite, "modulate", base_color, 0.3)

# ============================================================
# 脆弱状态
# ============================================================

func _start_vulnerability(duration: float) -> void:
	_is_vulnerable = true
	_vulnerability_timer = duration
	boss_vulnerability_started.emit(duration)

func _update_vulnerability(delta: float) -> void:
	if not _is_vulnerable:
		return
	
	_vulnerability_timer -= delta
	if _vulnerability_timer <= 0.0:
		_is_vulnerable = false
		boss_vulnerability_ended.emit()

# ============================================================
# 护盾系统
# ============================================================

func _update_shield(delta: float) -> void:
	if _max_shield_hp <= 0.0:
		return
	
	if not _shield_active and _shield_hp < _max_shield_hp:
		_shield_regen_timer += delta
		if _shield_regen_timer >= _shield_regen_delay:
			_shield_hp = min(_shield_hp + _shield_regen_rate * delta, _max_shield_hp)
			if _shield_hp >= _max_shield_hp:
				_shield_active = true

# ============================================================
# 狂暴系统
# ============================================================

func _update_enrage(delta: float) -> void:
	_enrage_timer += delta
	
	if _enrage_level == 0 and _enrage_timer >= enrage_time * 0.7:
		_enrage_level = 1
		boss_enraged.emit(1)
		_on_enrage(1)
	
	if _enrage_level == 1 and _enrage_timer >= enrage_time:
		_enrage_level = 2
		boss_enraged.emit(2)
		_on_enrage(2)

## 子类重写：狂暴时的特殊行为
func _on_enrage(_level: int) -> void:
	pass

# ============================================================
# 小兵召唤
# ============================================================

func _update_summon(delta: float) -> void:
	if _current_phase >= _phase_configs.size():
		return
	
	var config: Dictionary = _phase_configs[_current_phase]
	if not config.get("summon_enabled", false):
		return
	
	_summon_cooldown -= delta
	if _summon_cooldown <= 0.0:
		_summon_cooldown = _summon_cooldown_time
		_spawn_minions()

func _spawn_minions() -> void:
	var config: Dictionary = _phase_configs[_current_phase]
	var minion_count: int = config.get("summon_count", 3)
	var minion_type: String = config.get("summon_type", "static")
	
	boss_summon_minions.emit(minion_count, minion_type)
	
	# 召唤视觉效果
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.2)

# ============================================================
# 节拍响应（Boss 重写）
# ============================================================

func _on_beat(_beat_index: int) -> void:
	_boss_beat_counter += 1
	
	# Boss 的节拍脉冲更强烈
	if _sprite and not _is_dead:
		var pulse_size := 1.3 if _enrage_level > 0 else 1.2
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(pulse_size, pulse_size), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)
	
	# 子类节拍回调
	_on_boss_beat(_beat_index)

## 子类重写：Boss 专属节拍行为
func _on_boss_beat(_beat_index: int) -> void:
	pass

# ============================================================
# Boss 死亡
# ============================================================

func _boss_die() -> void:
	if _is_dead:
		return
	_is_dead = true
	
	# 停止所有攻击
	_is_attacking = false
	
	# 发出 Boss 击败信号
	boss_defeated.emit()
	
	# 掉落共鸣碎片
	_drop_resonance_fragments()
	
	# Boss 死亡动画（比普通敌人更华丽）
	_play_boss_death_animation()
	
	# 通知 GameManager
	var type_name := _get_type_name()
	enemy_died.emit(global_position, xp_value, type_name)
	GameManager.enemy_killed.emit(global_position, type_name)

func _drop_resonance_fragments() -> void:
	# 在 Boss 位置周围散落共鸣碎片
	# 这些碎片是局外成长系统的货币
	for i in range(min(resonance_fragment_drop / 5, 20)):
		var angle := randf() * TAU
		var dist := randf_range(20.0, 80.0)
		var drop_pos := global_position + Vector2.from_angle(angle) * dist
		# 通过信号通知 MetaProgressionManager
		# （具体实现在 Issue #31 中完成）

func _play_boss_death_animation() -> void:
	set_physics_process(false)
	if _collision:
		_collision.set_deferred("disabled", true)
	
	if _sprite == null:
		queue_free()
		return
	
	# Boss 死亡：多阶段华丽动画
	var tween := create_tween()
	
	# 阶段1：时间冻结感（膨胀 + 闪白）
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", Vector2(3.0, 3.0), 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.3)
	
	# 阶段2：剧烈抖动
	tween.chain()
	for i in range(6):
		var offset := Vector2(randf_range(-8, 8), randf_range(-8, 8))
		tween.tween_property(_sprite, "position", offset, 0.05)
	
	# 阶段3：压缩成线 + 爆发
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", Vector2(4.0, 0.1), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, "modulate", Color(1.0, 0.5, 0.0), 0.15)
	
	# 阶段4：消散
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", Vector2(0.0, 0.0), 0.3)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.3)
	
	tween.chain()
	tween.tween_callback(queue_free)

# ============================================================
# Boss 视觉
# ============================================================

func _update_boss_visual(delta: float) -> void:
	if _sprite == null:
		return
	
	# 护盾视觉效果
	if _shield_active and _shield_hp > 0.0:
		var shield_ratio := _shield_hp / _max_shield_hp
		# 护盾闪烁（低护盾时更频繁）
		var flicker_speed := remap(shield_ratio, 0.0, 1.0, 0.02, 0.005)
		var shield_pulse := sin(Time.get_ticks_msec() * flicker_speed) * 0.15
		_sprite.modulate = base_color.lerp(Color(0.5, 0.8, 1.0), 0.3 + shield_pulse)
	
	# 脆弱状态视觉
	if _is_vulnerable:
		var vuln_flash := sin(Time.get_ticks_msec() * 0.015) * 0.3
		_sprite.modulate = base_color.lerp(Color(1.0, 0.3, 0.3), 0.5 + vuln_flash)
	
	# 狂暴视觉
	if _enrage_level >= 2:
		var rage_pulse := sin(Time.get_ticks_msec() * 0.01) * 0.2
		_sprite.modulate = _sprite.modulate.lerp(Color(1.0, 0.0, 0.0), 0.3 + rage_pulse)

# ============================================================
# 音乐系统集成
# ============================================================

func _notify_music_change(layer_name: String) -> void:
	var bgm_mgr := get_node_or_null("/root/BGMManager")
	if bgm_mgr and bgm_mgr.has_method("set_boss_layer"):
		bgm_mgr.set_boss_layer(layer_name)
	elif bgm_mgr and bgm_mgr.has_method("transition_to_section"):
		bgm_mgr.transition_to_section(layer_name)

# ============================================================
# 碰撞数据（重写，包含护盾信息）
# ============================================================

func get_collision_data() -> Dictionary:
	var data := super.get_collision_data()
	data["is_boss"] = true
	data["shield_hp"] = _shield_hp
	data["shield_active"] = _shield_active
	data["is_vulnerable"] = _is_vulnerable
	data["phase"] = _current_phase
	return data

# ============================================================
# Boss 血条数据接口
# ============================================================

func get_boss_bar_data() -> Dictionary:
	return {
		"name": boss_name,
		"title": boss_title,
		"hp": current_hp,
		"max_hp": max_hp,
		"hp_ratio": current_hp / max_hp if max_hp > 0.0 else 0.0,
		"shield_hp": _shield_hp,
		"max_shield_hp": _max_shield_hp,
		"shield_ratio": _shield_hp / _max_shield_hp if _max_shield_hp > 0.0 else 0.0,
		"phase": _current_phase,
		"total_phases": _phase_configs.size(),
		"is_vulnerable": _is_vulnerable,
		"enrage_level": _enrage_level,
	}
