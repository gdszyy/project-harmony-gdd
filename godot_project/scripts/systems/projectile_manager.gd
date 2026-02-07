## projectile_manager.gd
## 弹体管理器
## 使用 MultiMeshInstance2D 实现高性能弹幕渲染
## 逻辑层与渲染层分离：纯数据驱动的弹体物理 + GPU批量渲染
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

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_multi_mesh()
	SpellcraftSystem.spell_cast.connect(_on_spell_cast)
	SpellcraftSystem.chord_cast.connect(_on_chord_cast)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	_update_projectiles(delta)
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

	# 使用简单的圆形网格
	# 在实际项目中，这里会使用自定义的 Mesh 或 QuadMesh
	# 配合 Shader 实现发光效果

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
		"knockback": false,
	}

	# 应用修饰符
	_apply_modifier(projectile)

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

func _spawn_extended_spell(data: Dictionary, pos: Vector2, dir: Vector2) -> void:
	# 扩展和弦的通用处理
	var proj := _base_projectile(data, pos, dir)
	proj["damage"] *= data.get("damage", 50.0) / 30.0
	proj["size"] *= 2.0
	proj["duration"] *= 1.5
	proj["color"] = Color(1.0, 0.0, 0.5)
	_projectiles.append(proj)

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

		# 摇摆弹道
		if proj.get("wave_trajectory", false):
			var wave_offset := sin(proj["time_alive"] * 10.0) * 100.0 * delta
			var perp := proj["velocity"].normalized().rotated(PI / 2.0)
			proj["position"] += perp * wave_offset

		# 位置更新
		proj["position"] += proj["velocity"] * delta

		# 法阵 tick
		if proj.get("is_field", false):
			proj["field_tick_timer"] += delta
			if proj["field_tick_timer"] >= proj.get("field_tick_interval", 0.5):
				proj["field_tick_timer"] = 0.0
				# 对范围内敌人造成伤害（由碰撞检测处理）

		# 护盾治疗 tick
		if proj.get("is_shield", false):
			proj["heal_timer"] += delta
			if proj["heal_timer"] >= 1.0:
				proj["heal_timer"] = 0.0
				GameManager.heal_player(proj.get("heal_per_second", 5.0))

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

# ============================================================
# 修饰符应用
# ============================================================

func _apply_modifier(proj: Dictionary) -> void:
	var mod = proj.get("modifier", -1)
	if mod < 0:
		return

	match mod:
		MusicData.ModifierEffect.PIERCE:
			proj["pierce"] = true
			proj["max_pierce"] = 3
			proj["pierce_count"] = 0
		MusicData.ModifierEffect.HOMING:
			proj["homing"] = true
			proj["homing_strength"] = 5.0
		MusicData.ModifierEffect.SPLIT:
			proj["split_on_hit"] = true
			proj["split_count"] = 3
		MusicData.ModifierEffect.ECHO:
			proj["echo"] = true
			proj["echo_delay"] = 0.3
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

func _apply_rhythm_to_projectile(proj: Dictionary, rhythm: MusicData.RhythmPattern, _spell_data: Dictionary) -> void:
	match rhythm:
		MusicData.RhythmPattern.SWING:
			proj["wave_trajectory"] = true
		MusicData.RhythmPattern.DOTTED:
			proj["knockback"] = true

# ============================================================
# 碰撞检测 (简化的距离检测)
# ============================================================

## 检测弹体与敌人的碰撞
## enemies: Array[Dictionary] - [{ "position": Vector2, "radius": float }]
func check_collisions(enemies: Array) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []

	for proj in _projectiles:
		if not proj["active"]:
			continue

		for enemy in enemies:
			var dist := proj["position"].distance_to(enemy["position"])
			if dist < proj["size"] + enemy.get("radius", 16.0):
				hits.append({
					"projectile": proj,
					"enemy": enemy,
					"damage": proj["damage"],
					"position": enemy["position"],
				})

				# 穿透检测
				if proj.get("pierce", false):
					proj["pierce_count"] = proj.get("pierce_count", 0) + 1
					if proj["pierce_count"] >= proj.get("max_pierce", 3):
						proj["active"] = false
				else:
					proj["active"] = false

				# 分裂
				if proj.get("split_on_hit", false):
					_split_projectile(proj)

				break  # 每帧每个弹体只命中一个敌人

	return hits

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
		if proj["active"]:
			active_count += 1

	var mm := _multi_mesh_instance.multimesh

	if mm.instance_count != active_count:
		mm.instance_count = active_count
		mm.visible_instance_count = active_count

	var idx := 0
	for proj in _projectiles:
		if not proj["active"]:
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

func get_active_count() -> int:
	var count := 0
	for p in _projectiles:
		if p["active"]:
			count += 1
	return count
