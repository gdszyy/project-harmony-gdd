## projectile_manager.gd
## 弹体管理器
## 使用 MultiMeshInstance2D 实现高性能弹幕渲染
## 逻辑层与渲染层分离：纯数据驱动的弹体物理 + GPU批量渲染
## Issue #6: 集成 CollisionOptimizer 空间哈希网格，替代 O(n×m) 暴力碰撞检测
extends Node2D

# ============================================================
# 信号
# ============================================================
signal projectile_hit_enemy(projectile: Dictionary, enemy_position: Vector2)

# ============================================================
# 配置
# ============================================================
const MAX_PROJECTILES: int = 2000
const CLEANUP_INTERVAL: float = 0.5

# ============================================================
# 弹体数据结构
# ============================================================
## 活跃弹体数组 (纯数据，无节点)
var _projectiles: Array[Dictionary] = []

## MultiMesh 渲染节点
@onready var _multi_mesh_instance: MultiMeshInstance2D = $MultiMeshInstance2D

## 清理计时器
var _cleanup_timer: float = 0.0

## 碰撞优化器 (Issue #6)
var _collision_optimizer: CollisionOptimizer = null

## 回响延迟队列：[{ "spell_data": Dictionary, "delay_remaining": float }]
var _echo_queue: Array[Dictionary] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_multi_mesh()
	_setup_collision_optimizer()
	SpellcraftSystem.spell_cast.connect(_on_spell_cast)
	SpellcraftSystem.chord_cast.connect(_on_chord_cast)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	_update_projectiles(delta)
	_update_echo_queue(delta)
	_update_render()

	_cleanup_timer += delta
	if _cleanup_timer >= CLEANUP_INTERVAL:
		_cleanup_timer = 0.0
		_cleanup_expired()

# ============================================================
# MultiMesh 设置
# ============================================================

func _setup_multi_mesh() -> void:
	if _multi_mesh_instance == null:
		_multi_mesh_instance = MultiMeshInstance2D.new()
		add_child(_multi_mesh_instance)

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_2D
	multi_mesh.use_colors = true
	multi_mesh.instance_count = 0
	multi_mesh.visible_instance_count = 0

	# 使用 QuadMesh 配合 Shader 实现发光效果
	var mesh := QuadMesh.new()
	mesh.size = Vector2(32, 32)
	multi_mesh.mesh = mesh

	# 应用 Shader
	var shader := load("res://shaders/projectile_glow.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_multi_mesh_instance.material = mat

	_multi_mesh_instance.multimesh = multi_mesh

# ============================================================
# 弹体创建
# ============================================================

func _on_spell_cast(spell_data: Dictionary) -> void:
	_create_projectile(spell_data)

func _on_chord_cast(chord_data: Dictionary) -> void:
	_create_chord_projectile(chord_data)

func _create_projectile(spell_data: Dictionary) -> void:
	if _projectiles.size() >= MAX_PROJECTILES:
		return

	var player_pos: Vector2 = _get_player_position()
	var aim_dir: Vector2 = _get_aim_direction()

	# 支持连射角度偏移
	var angle_offset: float = spell_data.get("rapid_fire_angle_offset", 0.0)
	if angle_offset != 0.0:
		aim_dir = aim_dir.rotated(angle_offset)

	var projectile := {
		"position": player_pos,
		"velocity": aim_dir * spell_data.get("speed", 600.0),
		"damage": spell_data.get("damage", 30.0),
		"size": spell_data.get("size", 24.0),
		"duration": spell_data.get("duration", 1.5),
		"time_alive": 0.0,
		"color": spell_data.get("color", Color(0.0, 1.0, 0.8)),
		"note": spell_data.get("note", -1),
		"modifier": spell_data.get("modifier", -1),
		"active": true,
		# 节奏型特殊属性
		"wave_trajectory": false,
		"knockback": spell_data.get("has_knockback", false),
	}

	# 应用修饰符
	_apply_modifier(projectile, spell_data)

	# 应用节奏型
	var rhythm = spell_data.get("rhythm_pattern", -1)
	_apply_rhythm_to_projectile(projectile, rhythm, spell_data)

	_projectiles.append(projectile)

func _create_chord_projectile(chord_data: Dictionary) -> void:
	var spell_form = chord_data.get("spell_form", -1)
	var player_pos := _get_player_position()
	var aim_dir := _get_aim_direction()

	match spell_form:
		MusicData.SpellForm.ENHANCED_PROJECTILE:
			_spawn_enhanced_projectile(chord_data, player_pos, aim_dir)
		MusicData.SpellForm.DOT_PROJECTILE:
			_spawn_dot_projectile(chord_data, player_pos, aim_dir)
		MusicData.SpellForm.EXPLOSIVE:
			_spawn_explosive(chord_data, player_pos, aim_dir)
		MusicData.SpellForm.SHOCKWAVE:
			_spawn_shockwave(chord_data, player_pos)
		MusicData.SpellForm.FIELD:
			_spawn_field(chord_data, player_pos, aim_dir)
		MusicData.SpellForm.DIVINE_STRIKE:
			_spawn_divine_strike(chord_data, player_pos, aim_dir)
		MusicData.SpellForm.SHIELD_HEAL:
			_spawn_shield(chord_data, player_pos)
		MusicData.SpellForm.SUMMON:
			_spawn_summon(chord_data, player_pos)
		MusicData.SpellForm.CHARGED:
			_spawn_charged(chord_data, player_pos, aim_dir)
		_:
			# 扩展和弦形态
			_spawn_extended_spell(chord_data, player_pos, aim_dir)

# ============================================================
# 各种法术形态生成
# ============================================================

func _spawn_enhanced_projectile(data: Dictionary, pos: Vector2, dir: Vector2) -> void:
	var proj := _base_projectile(data, pos, dir)
	proj["damage"] *= 1.5
	proj["size"] *= 1.3
	proj["color"] = Color(1.0, 0.9, 0.3)  # 金色
	_projectiles.append(proj)

func _spawn_dot_projectile(data: Dictionary, pos: Vector2, dir: Vector2) -> void:
	var proj := _base_projectile(data, pos, dir)
	proj["is_dot"] = true
	proj["dot_damage"] = proj["damage"] * 0.3
	proj["dot_interval"] = 0.5
	proj["dot_timer"] = 0.0
	proj["duration"] *= 2.0
	proj["color"] = Color(0.4, 0.0, 0.8)  # 紫色
	_projectiles.append(proj)

func _spawn_explosive(data: Dictionary, pos: Vector2, dir: Vector2) -> void:
	var proj := _base_projectile(data, pos, dir)
	proj["is_explosive"] = true
	proj["explosion_radius"] = 80.0
	proj["color"] = Color(1.0, 0.5, 0.0)  # 橙色
	_projectiles.append(proj)

func _spawn_shockwave(data: Dictionary, pos: Vector2) -> void:
	# 冲击波：从玩家位置向外扩散的环形
	var proj := {
		"position": pos,
		"velocity": Vector2.ZERO,
		"damage": data.get("damage", 50.0),
		"size": 10.0,
		"max_size": 150.0,
		"expand_speed": 200.0,
		"duration": 0.8,
		"time_alive": 0.0,
		"color": Color(0.8, 0.0, 0.2),
		"is_shockwave": true,
		"active": true,
		"modifier": -1,
	}
	_projectiles.append(proj)

func _spawn_field(data: Dictionary, pos: Vector2, dir: Vector2) -> void:
	var target_pos := pos + dir * 200.0
	var proj := {
		"position": target_pos,
		"velocity": Vector2.ZERO,
		"damage": data.get("damage", 20.0),
		"size": 60.0,
		"duration": 4.0,
		"time_alive": 0.0,
		"color": Color(0.0, 0.6, 1.0),
		"is_field": true,
		"field_tick_interval": 0.5,
		"field_tick_timer": 0.0,
		"active": true,
		"modifier": -1,
	}
	_projectiles.append(proj)

func _spawn_divine_strike(data: Dictionary, _pos: Vector2, dir: Vector2) -> void:
	var target_pos := _get_player_position() + dir * 300.0
	var proj := {
		"position": target_pos + Vector2(0, -500),  # 从天而降
		"target_position": target_pos,
		"velocity": Vector2(0, 800),
		"damage": data.get("damage", 100.0),
		"size": 40.0,
		"duration": 1.5,
		"time_alive": 0.0,
		"color": Color(1.0, 0.2, 0.2),
		"is_divine_strike": true,
		"active": true,
		"modifier": -1,
	}
	_projectiles.append(proj)

func _spawn_shield(data: Dictionary, pos: Vector2) -> void:
	# 护盾/治疗法阵
	GameManager.heal_player(20.0)
	var proj := {
		"position": pos,
		"velocity": Vector2.ZERO,
		"damage": 0.0,
		"size": 50.0,
		"duration": 3.0,
		"time_alive": 0.0,
		"color": Color(0.2, 1.0, 0.4),
		"is_shield": true,
		"heal_per_second": 5.0,
		"heal_timer": 0.0,
		"active": true,
		"modifier": -1,
	}
	_projectiles.append(proj)

func _spawn_summon(data: Dictionary, pos: Vector2) -> void:
	var proj := {
		"position": pos + Vector2(randf_range(-50, 50), randf_range(-50, 50)),
		"velocity": Vector2.ZERO,
		"damage": data.get("damage", 15.0),
		"size": 30.0,
		"duration": 5.0,
		"time_alive": 0.0,
		"color": Color(0.3, 0.3, 0.8),
		"is_summon": true,
		"attack_interval": 1.0,
		"attack_timer": 0.0,
		"attack_range": 150.0,
		"active": true,
		"modifier": -1,
	}
	_projectiles.append(proj)

func _spawn_charged(data: Dictionary, pos: Vector2, dir: Vector2) -> void:
	var proj := _base_projectile(data, pos, dir)
	proj["is_charged"] = true
	proj["charge_time"] = 1.0  # 1拍延迟
	proj["charged"] = false
	proj["damage"] *= 2.0
	proj["size"] *= 1.5
	proj["velocity"] = Vector2.ZERO  # 蓄力期间不移动
	proj["final_velocity"] = dir * 800.0
	proj["color"] = Color(1.0, 1.0, 0.0)
	_projectiles.append(proj)

# ============================================================
# 扩展和弦法术形态（修复：从嵌套函数移出为顶层函数）
# ============================================================

func _spawn_extended_spell(data: Dictionary, pos: Vector2, dir: Vector2) -> void:
	# Issue #17: 扩展和弦法术形态
	var spell_form = data.get("spell_form", -1)

	match spell_form:
		MusicData.SpellForm.STORM_FIELD:
			_spawn_storm_field(data, pos)
		MusicData.SpellForm.HOLY_DOMAIN:
			_spawn_holy_domain(data, pos)
		MusicData.SpellForm.ANNIHILATION_RAY:
			_spawn_annihilation_ray(data, pos, dir)
		MusicData.SpellForm.TIME_RIFT:
			_spawn_time_rift(data, pos)
		MusicData.SpellForm.SYMPHONY_STORM:
			_spawn_symphony_storm(data, pos)
		MusicData.SpellForm.FINALE:
			_spawn_finale(data, pos)
		_:
			# 默认处理
			var proj := _base_projectile(data, pos, dir)
			proj["damage"] *= data.get("damage", 50.0) / 30.0
			proj["size"] *= 2.0
			proj["duration"] *= 1.5
			proj["color"] = Color(1.0, 0.0, 0.5)
			_projectiles.append(proj)

## 属九：风暴区域
func _spawn_storm_field(data: Dictionary, pos: Vector2) -> void:
	var field := {
		"position": pos,
		"velocity": Vector2.ZERO,
		"damage": data.get("damage", 50.0) * 0.5,
		"size": 120.0,
		"duration": 5.0,
		"time_alive": 0.0,
		"color": Color(0.3, 0.8, 1.0),
		"active": true,
		"is_field": true,
		"field_type": "storm",
		"field_tick_interval": 0.5,
		"field_tick_timer": 0.0,
		"rotation": 0.0,
		"rotation_speed": 3.0,
		"modifier": -1,
	}
	_projectiles.append(field)

## 大九：圣光领域
func _spawn_holy_domain(data: Dictionary, pos: Vector2) -> void:
	var domain := {
		"position": pos,
		"velocity": Vector2.ZERO,
		"damage": 0.0,
		"heal_per_sec": 15.0,
		"size": 100.0,
		"duration": 6.0,
		"time_alive": 0.0,
		"color": Color(1.0, 0.95, 0.6),
		"active": true,
		"is_field": true,
		"is_shield": true,
		"field_type": "heal",
		"heal_per_second": 15.0,
		"heal_timer": 0.0,
		"modifier": -1,
	}
	_projectiles.append(domain)

## 减九：湮灭射线
func _spawn_annihilation_ray(data: Dictionary, pos: Vector2, dir: Vector2) -> void:
	var ray := {
		"position": pos,
		"velocity": dir * 1200.0,
		"damage": data.get("damage", 80.0),
		"size": 16.0,
		"duration": 0.8,
		"time_alive": 0.0,
		"color": Color(0.8, 0.0, 0.8),
		"active": true,
		"pierce": true,
		"max_pierce": 999,
		"pierce_count": 0,
		"is_ray": true,
		"modifier": -1,
	}
	_projectiles.append(ray)

## 属十一：时空裂隙
func _spawn_time_rift(data: Dictionary, pos: Vector2) -> void:
	var rift := {
		"position": pos,
		"velocity": Vector2.ZERO,
		"damage": data.get("damage", 30.0) * 0.6,
		"size": 150.0,
		"duration": 4.0,
		"time_alive": 0.0,
		"color": Color(0.5, 0.0, 1.0),
		"active": true,
		"is_field": true,
		"field_type": "slow",
		"field_tick_interval": 0.5,
		"field_tick_timer": 0.0,
		"slow_factor": 0.3,
		"modifier": -1,
	}
	_projectiles.append(rift)

## 属十三：交响风暴
func _spawn_symphony_storm(data: Dictionary, pos: Vector2) -> void:
	var wave_count := 3
	var projectiles_per_wave := 12

	for wave in range(wave_count):
		for i in range(projectiles_per_wave):
			var angle := (TAU / projectiles_per_wave) * i
			var dir := Vector2.from_angle(angle)
			var proj := {
				"position": pos,
				"velocity": dir * (400.0 + wave * 100.0),
				"damage": data.get("damage", 40.0) * 0.6,
				"size": 20.0,
				"duration": 2.0,
				"time_alive": -wave * 0.3,  # 延迟发射
				"color": Color(1.0, 0.6, 0.0),
				"active": true,
				"modifier": -1,
			}
			_projectiles.append(proj)

## 减十三：终焉乐章
func _spawn_finale(data: Dictionary, pos: Vector2) -> void:
	var finale := {
		"position": pos,
		"velocity": Vector2.ZERO,
		"damage": data.get("damage", 200.0),
		"size": 999999.0,
		"duration": 0.5,
		"time_alive": 0.0,
		"color": Color(1.0, 0.0, 0.0),
		"active": true,
		"is_aoe": true,
		"expansion_speed": 2000.0,
		"modifier": -1,
	}
	_projectiles.append(finale)

func _base_projectile(data: Dictionary, pos: Vector2, dir: Vector2) -> Dictionary:
	return {
		"position": pos,
		"velocity": dir * 600.0,
		"damage": data.get("damage", 30.0),
		"size": 24.0,
		"duration": 1.5,
		"time_alive": 0.0,
		"color": Color(0.0, 1.0, 0.8),
		"active": true,
		"modifier": data.get("modifier", -1),
	}

# ============================================================
# 弹体更新
# ============================================================

func _update_projectiles(delta: float) -> void:
	for proj in _projectiles:
		if not proj["active"]:
			continue

		proj["time_alive"] += delta

		# 延迟发射的弹体（time_alive < 0 时不更新）
		if proj["time_alive"] < 0.0:
			continue

		# 超时销毁
		if proj["time_alive"] >= proj["duration"]:
			proj["active"] = false
			# 爆炸弹体在消失时触发爆炸
			if proj.get("is_explosive", false):
				_trigger_explosion(proj)
			continue

		# 蓄力弹体特殊处理
		if proj.get("is_charged", false) and not proj.get("charged", false):
			if proj["time_alive"] >= proj.get("charge_time", 1.0):
				proj["charged"] = true
				proj["velocity"] = proj.get("final_velocity", Vector2(800, 0))
			continue

		# 冲击波扩展
		if proj.get("is_shockwave", false):
			proj["size"] = min(proj["size"] + proj.get("expand_speed", 200.0) * delta, proj.get("max_size", 150.0))
			continue

		# 追踪逻辑（HOMING 修饰符 — 已实现）
		if proj.get("homing", false):
			var nearest_enemy := _find_nearest_enemy(proj["position"])
			if nearest_enemy != Vector2.INF:
				var to_enemy := (nearest_enemy - proj["position"]).normalized()
				var current_dir := proj["velocity"].normalized()
				var homing_strength: float = proj.get("homing_strength", 5.0)
				var new_dir := current_dir.lerp(to_enemy, homing_strength * delta).normalized()
				proj["velocity"] = new_dir * proj["velocity"].length()

		# 摇摆弹道
		if proj.get("wave_trajectory", false):
			var wave_offset := sin(proj["time_alive"] * 10.0) * 100.0 * delta
			var perp := proj["velocity"].normalized().rotated(PI / 2.0)
			proj["position"] += perp * wave_offset

		# 召唤物自动攻击
		if proj.get("is_summon", false):
			proj["attack_timer"] += delta
			if proj["attack_timer"] >= proj.get("attack_interval", 1.0):
				proj["attack_timer"] = 0.0
				_summon_attack(proj)
			# 召唤物跟随玩家
			var player_pos := _get_player_position()
			var to_player := (player_pos - proj["position"])
			if to_player.length() > 80.0:
				proj["position"] += to_player.normalized() * 100.0 * delta

		# 位置更新
		proj["position"] += proj["velocity"] * delta

		# 法阵 tick
		if proj.get("is_field", false):
			if not proj.has("field_tick_timer"):
				proj["field_tick_timer"] = 0.0
			proj["field_tick_timer"] += delta
			if proj["field_tick_timer"] >= proj.get("field_tick_interval", 0.5):
				proj["field_tick_timer"] = 0.0
				# 对范围内敌人造成伤害（由碰撞检测处理）

		# 护盾治疗 tick
		if proj.get("is_shield", false):
			if not proj.has("heal_timer"):
				proj["heal_timer"] = 0.0
			proj["heal_timer"] += delta
			if proj["heal_timer"] >= 1.0:
				proj["heal_timer"] = 0.0
				GameManager.heal_player(proj.get("heal_per_second", 5.0))

		# 风暴旋转
		if proj.get("field_type", "") == "storm":
			proj["rotation"] = proj.get("rotation", 0.0) + proj.get("rotation_speed", 3.0) * delta

func _trigger_explosion(proj: Dictionary) -> void:
	# 在爆炸位置创建一个短暂的大范围伤害区域
	var explosion := {
		"position": proj["position"],
		"velocity": Vector2.ZERO,
		"damage": proj["damage"] * 1.5,
		"size": proj.get("explosion_radius", 80.0),
		"duration": 0.2,
		"time_alive": 0.0,
		"color": Color(1.0, 0.6, 0.0, 0.8),
		"active": true,
		"is_explosion_effect": true,
		"modifier": -1,
	}
	_projectiles.append(explosion)

## 召唤物自动攻击：向最近敌人发射小弹体
func _summon_attack(summon_proj: Dictionary) -> void:
	var nearest := _find_nearest_enemy(summon_proj["position"])
	if nearest == Vector2.INF:
		return

	var dir := (nearest - summon_proj["position"]).normalized()
	var attack := {
		"position": summon_proj["position"],
		"velocity": dir * 500.0,
		"damage": summon_proj["damage"],
		"size": 12.0,
		"duration": 0.8,
		"time_alive": 0.0,
		"color": summon_proj["color"].lightened(0.3),
		"active": true,
		"modifier": -1,
	}
	_projectiles.append(attack)

# ============================================================
# 回响（Echo）延迟队列
# ============================================================

func _update_echo_queue(delta: float) -> void:
	var i := 0
	while i < _echo_queue.size():
		_echo_queue[i]["delay_remaining"] -= delta
		if _echo_queue[i]["delay_remaining"] <= 0.0:
			# 触发回响弹体
			var echo_data: Dictionary = _echo_queue[i]["spell_data"]
			_create_echo_projectile(echo_data)
			_echo_queue.remove_at(i)
		else:
			i += 1

func _create_echo_projectile(spell_data: Dictionary) -> void:
	if _projectiles.size() >= MAX_PROJECTILES:
		return

	var player_pos := _get_player_position()
	var aim_dir := _get_aim_direction()

	var proj := {
		"position": player_pos,
		"velocity": aim_dir * spell_data.get("speed", 600.0) * 0.8,  # 回响弹体稍慢
		"damage": spell_data.get("damage", 30.0) * 0.6,  # 回响伤害衰减
		"size": spell_data.get("size", 24.0) * 0.8,
		"duration": spell_data.get("duration", 1.5) * 0.7,
		"time_alive": 0.0,
		"color": spell_data.get("color", Color(0.0, 1.0, 0.8)).darkened(0.2),
		"active": true,
		"modifier": -1,  # 回响弹体不再触发修饰符
		"is_echo": true,
	}
	_projectiles.append(proj)

# ============================================================
# 修饰符应用（已实现追踪和回响）
# ============================================================

func _apply_modifier(proj: Dictionary, spell_data: Dictionary = {}) -> void:
	var mod = proj.get("modifier", -1)
	if mod < 0:
		return

	match mod:
		MusicData.ModifierEffect.PIERCE:
			proj["pierce"] = true
			proj["max_pierce"] = 3
			proj["pierce_count"] = 0
		MusicData.ModifierEffect.HOMING:
			# 追踪修饰符：弹体会转向最近的敌人
			proj["homing"] = true
			proj["homing_strength"] = 5.0
			proj["duration"] *= 1.3  # 追踪弹体持续时间稍长
		MusicData.ModifierEffect.SPLIT:
			proj["split_on_hit"] = true
			proj["split_count"] = 3
		MusicData.ModifierEffect.ECHO:
			# 回响修饰符：延迟后在玩家位置再发射一个衰减弹体
			proj["echo"] = true
			_echo_queue.append({
				"spell_data": spell_data.duplicate() if not spell_data.is_empty() else {
					"speed": proj["velocity"].length(),
					"damage": proj["damage"],
					"size": proj["size"],
					"duration": proj["duration"],
					"color": proj["color"],
				},
				"delay_remaining": 0.3,
			})
		MusicData.ModifierEffect.SCATTER:
			# 散射：替换为多个小弹体
			proj["damage"] *= 0.4
			proj["size"] *= 0.6
			# 生成额外散射弹体
			for i in range(4):
				var angle := proj["velocity"].angle() + randf_range(-0.5, 0.5)
				var scatter_proj := proj.duplicate()
				scatter_proj["velocity"] = Vector2.from_angle(angle) * proj["velocity"].length()
				scatter_proj["modifier"] = -1
				_projectiles.append(scatter_proj)

func _apply_rhythm_to_projectile(proj: Dictionary, rhythm, _spell_data: Dictionary) -> void:
	if rhythm is int and rhythm < 0:
		return
	match rhythm:
		MusicData.RhythmPattern.EVEN_EIGHTH:
			# 连射：弹体更小、更快、伤害降低（但总 DPS 更高）
			proj["damage"] *= 0.6
			proj["velocity"] *= 1.2
			proj["size"] *= 0.7
		MusicData.RhythmPattern.SWING:
			proj["wave_trajectory"] = true
		MusicData.RhythmPattern.DOTTED:
			# 重击：增加单发伤害和击退
			proj["knockback"] = true
			proj["damage"] *= 1.4
			proj["size"] *= 1.2
		MusicData.RhythmPattern.SYNCOPATED:
			# 闪避射击：增加弹速，弹体可穿透1个敌人
			proj["velocity"] *= 1.3
			proj["pierce"] = true
			proj["max_pierce"] = 1
			proj["pierce_count"] = 0
		MusicData.RhythmPattern.TRIPLET:
			# 三连发：弹体更小但更密集
			proj["size"] *= 0.8
			proj["duration"] *= 0.8
		MusicData.RhythmPattern.REST:
			# 精准蓄力：延迟发射但大幅增强
			proj["is_charged"] = true
			proj["charge_time"] = 0.5
			proj["charged"] = false
			proj["final_velocity"] = proj["velocity"] * 1.5
			proj["velocity"] = Vector2.ZERO
			proj["damage"] *= 1.8
			proj["size"] *= 1.3

# ============================================================
# 碰撞优化器设置 (Issue #6)
# ============================================================

func _setup_collision_optimizer() -> void:
	# 单元格大小设为 128px，约为最大弹体尺寸的 2-4 倍
	# 这个值在大多数情况下能提供良好的性能
	_collision_optimizer = CollisionOptimizer.new(128.0)

# ============================================================
# 碰撞检测 (Issue #6: 空间哈希优化版)
# ============================================================

## 检测弹体与敌人的碰撞
## 使用 CollisionOptimizer 空间哈希网格替代暴力 O(n×m) 检测
## enemies: Array[Dictionary] - [{ "position": Vector2, "radius": float }]
func check_collisions(enemies: Array) -> Array[Dictionary]:
	if _collision_optimizer == null:
		return _check_collisions_bruteforce(enemies)
	
	# 使用空间哈希优化的碰撞检测
	var hits := _collision_optimizer.check_collisions(_projectiles, enemies)
	
	# 处理分裂弹体
	for hit in hits:
		var proj = hit["projectile"]
		if proj.get("split_on_hit", false):
			_split_projectile(proj)
	
	return hits

## 暴力碰撞检测（回退方案）
func _check_collisions_bruteforce(enemies: Array) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []

	for proj in _projectiles:
		if not proj["active"]:
			continue
		# 跳过延迟发射的弹体
		if proj["time_alive"] < 0.0:
			continue

		for enemy in enemies:
			var dist := proj["position"].distance_to(enemy["position"])
			if dist < proj["size"] + enemy.get("radius", 16.0):
				var hit_data := {
					"projectile": proj,
					"enemy": enemy,
					"damage": proj["damage"],
					"position": enemy["position"],
					"knockback": proj.get("knockback", false),
					"slow_factor": proj.get("slow_factor", 0.0),
				}
				hits.append(hit_data)

				projectile_hit_enemy.emit(proj, enemy["position"])

				if proj.get("pierce", false):
					proj["pierce_count"] = proj.get("pierce_count", 0) + 1
					if proj["pierce_count"] >= proj.get("max_pierce", 3):
						proj["active"] = false
				elif not proj.get("is_field", false) and not proj.get("is_shockwave", false) and not proj.get("is_aoe", false):
					proj["active"] = false

				if proj.get("split_on_hit", false):
					_split_projectile(proj)

				if not proj.get("is_field", false) and not proj.get("is_shockwave", false):
					break  # 每帧每个非区域弹体只命中一个敌人

	return hits

## 获取碰撞检测性能统计 (Issue #6)
func get_collision_stats() -> Dictionary:
	if _collision_optimizer:
		return _collision_optimizer.get_performance_stats()
	return {}

func _split_projectile(proj: Dictionary) -> void:
	var count: int = proj.get("split_count", 3)
	for i in range(count):
		var angle := (2.0 * PI / count) * i
		var split := {
			"position": proj["position"],
			"velocity": Vector2.from_angle(angle) * proj["velocity"].length() * 0.7,
			"damage": proj["damage"] * 0.5,
			"size": proj["size"] * 0.7,
			"duration": proj["duration"] * 0.5,
			"time_alive": 0.0,
			"color": proj["color"],
			"active": true,
			"modifier": -1,
		}
		_projectiles.append(split)

# ============================================================
# 渲染更新
# ============================================================

func _update_render() -> void:
	if _multi_mesh_instance == null or _multi_mesh_instance.multimesh == null:
		return

	var active_count := 0
	for proj in _projectiles:
		if proj["active"] and proj["time_alive"] >= 0.0:
			active_count += 1

	var mm := _multi_mesh_instance.multimesh

	if mm.instance_count != active_count:
		mm.instance_count = active_count
		mm.visible_instance_count = active_count

	var idx := 0
	for proj in _projectiles:
		if not proj["active"] or proj["time_alive"] < 0.0:
			continue
		if idx >= active_count:
			break

		var t := Transform2D()
		var scale_factor: float = proj["size"] / 16.0  # 基准大小16px
		t = t.scaled(Vector2(scale_factor, scale_factor))
		t.origin = proj["position"]

		mm.set_instance_transform_2d(idx, t)
		mm.set_instance_color(idx, proj["color"])
		idx += 1

# ============================================================
# 清理
# ============================================================

func _cleanup_expired() -> void:
	_projectiles = _projectiles.filter(func(p): return p["active"])

## 清除所有弹体
func clear_all() -> void:
	_projectiles.clear()
	_echo_queue.clear()
	if _multi_mesh_instance and _multi_mesh_instance.multimesh:
		_multi_mesh_instance.multimesh.visible_instance_count = 0

# ============================================================
# 工具函数
# ============================================================

func _get_player_position() -> Vector2:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		return player.global_position
	return Vector2.ZERO

func _get_aim_direction() -> Vector2:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		return (get_global_mouse_position() - player.global_position).normalized()
	return Vector2.RIGHT

## 查找最近的敌人位置（用于追踪和召唤物攻击）
func _find_nearest_enemy(from_pos: Vector2) -> Vector2:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest_pos := Vector2.INF
	var nearest_dist := INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := from_pos.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_pos = enemy.global_position

	return nearest_pos

func get_active_count() -> int:
	var count := 0
	for p in _projectiles:
		if p["active"]:
			count += 1
	return count
