## summon_manager.gd
## 召唤系统 — "幻影声部 (Phantom Voice)"
## 法术第五维度：通过小七和弦（Minor 7th）召唤幻影声部伴奏实体。
## 幻影声部是持续存在的战术单位，提供伴奏、共鸣、干扰等多种支持。
##
## 设计理念：
## - 每个幻影声部代表一个"伴奏声部"（低音、和声、旋律、打击）
## - 声部之间可以产生"共鸣"效果（多个声部协同增强）
## - 声部的行为受当前音色影响
## - 声部有持续时间和维护成本（疲劳消耗）
##
## 召唤类型：
## 1. 伴奏声部 (Accompaniment) — 跟随玩家，自动攻击最近敌人
## 2. 共鸣声部 (Resonance) — 固定位置，增强区域内法术伤害
## 3. 干扰声部 (Interference) — 巡逻移动，减速和干扰敌人
## 4. 节奏声部 (Rhythm) — 跟随玩家，在节拍时释放脉冲波
extends Node

# ============================================================
# 信号
# ============================================================
signal summon_created(summon_data: Dictionary)
signal summon_expired(summon_id: int)
signal summon_attacked(summon_id: int, target_pos: Vector2)
signal resonance_activated(bonus: float)
signal summon_limit_reached()

# ============================================================
# 配置
# ============================================================
## 最大同时存在的召唤物数量
const MAX_SUMMONS: int = 4
## 召唤物基础持续时间（秒）
const BASE_DURATION: float = 12.0
## 召唤物疲劳消耗/秒
const FATIGUE_COST_PER_SEC: float = 0.5
## 共鸣加成基础倍率
const RESONANCE_BASE_BONUS: float = 0.15
## 共鸣检测范围
const RESONANCE_RANGE: float = 200.0

# ============================================================
# 召唤物类型枚举
# ============================================================
enum SummonType {
	ACCOMPANIMENT,  ## 伴奏声部：自动攻击
	RESONANCE,      ## 共鸣声部：区域增伤
	INTERFERENCE,   ## 干扰声部：减速敌人
	RHYTHM,         ## 节奏声部：节拍脉冲
}

# ============================================================
# 召唤物数据
# ============================================================
## 活跃召唤物列表
var _active_summons: Array[Dictionary] = []
## 召唤物 ID 计数器
var _next_summon_id: int = 0
## 共鸣加成缓存
var _resonance_bonus: float = 0.0
## 共鸣更新计时
var _resonance_update_timer: float = 0.0

# ============================================================
# 召唤物类型配置
# ============================================================
const SUMMON_CONFIGS: Dictionary = {
	SummonType.ACCOMPANIMENT: {
		"name": "伴奏声部",
		"color": Color(0.3, 0.5, 0.9),
		"size": 24.0,
		"attack_interval": 0.8,
		"attack_damage_mult": 0.6,
		"attack_range": 180.0,
		"attack_speed": 500.0,
		"follow_distance": 60.0,
		"follow_speed": 150.0,
		"duration_mult": 1.0,
	},
	SummonType.RESONANCE: {
		"name": "共鸣声部",
		"color": Color(0.9, 0.7, 0.2),
		"size": 40.0,
		"aura_radius": 120.0,
		"damage_bonus": 0.25,
		"duration_mult": 0.8,
	},
	SummonType.INTERFERENCE: {
		"name": "干扰声部",
		"color": Color(0.7, 0.2, 0.7),
		"size": 28.0,
		"patrol_radius": 150.0,
		"patrol_speed": 80.0,
		"slow_radius": 100.0,
		"slow_factor": 0.4,
		"interference_damage": 3.0,
		"duration_mult": 0.9,
	},
	SummonType.RHYTHM: {
		"name": "节奏声部",
		"color": Color(0.2, 0.9, 0.5),
		"size": 20.0,
		"pulse_damage": 15.0,
		"pulse_radius": 100.0,
		"follow_distance": 40.0,
		"follow_speed": 180.0,
		"duration_mult": 1.1,
	},
}

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 连接节拍信号
	if GameManager.beat_tick.is_connected(_on_beat_tick) == false:
		GameManager.beat_tick.connect(_on_beat_tick)
	
	# 连接法术系统信号
	if SpellcraftSystem.chord_cast.is_connected(_on_chord_cast) == false:
		SpellcraftSystem.chord_cast.connect(_on_chord_cast)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	_update_summons(delta)
	
	# 定期更新共鸣加成
	_resonance_update_timer += delta
	if _resonance_update_timer >= 0.5:
		_resonance_update_timer = 0.0
		_update_resonance_bonus()

# ============================================================
# 召唤物创建
# ============================================================

func _on_chord_cast(chord_data: Dictionary) -> void:
	var spell_form = chord_data.get("spell_form", -1)
	if spell_form != MusicData.SpellForm.SUMMON:
		return
	
	create_summon(chord_data)

## 创建召唤物
func create_summon(chord_data: Dictionary) -> void:
	if _active_summons.size() >= MAX_SUMMONS:
		summon_limit_reached.emit()
		# 替换最旧的召唤物
		_remove_oldest_summon()
	
	# 根据当前音色决定召唤类型
	var summon_type := _determine_summon_type(chord_data)
	var config: Dictionary = SUMMON_CONFIGS[summon_type]
	
	var player_pos := _get_player_position()
	var base_damage: float = chord_data.get("damage", 15.0)
	
	# 计算持续时间（受音色和疲劳影响）
	var duration := BASE_DURATION * config.get("duration_mult", 1.0)
	
	var summon := {
		"id": _next_summon_id,
		"type": summon_type,
		"type_name": config["name"],
		"position": player_pos + Vector2(randf_range(-40, 40), randf_range(-40, 40)),
		"base_damage": base_damage,
		"size": config["size"],
		"color": config["color"],
		"duration": duration,
		"time_alive": 0.0,
		"active": true,
		"config": config,
		# 视觉状态
		"visual_node": null,
		"pulse_scale": 1.0,
		"orbit_angle": randf() * TAU,
		# 攻击状态
		"attack_timer": 0.0,
		# 巡逻状态
		"patrol_angle": randf() * TAU,
		"patrol_center": player_pos,
	}
	
	_next_summon_id += 1
	_active_summons.append(summon)
	
	# 创建视觉节点
	_create_summon_visual(summon)
	
	summon_created.emit(summon)

## 根据音色决定召唤类型
func _determine_summon_type(chord_data: Dictionary) -> SummonType:
	var timbre = chord_data.get("timbre", MusicData.TimbreType.NONE)
	
	match timbre:
		MusicData.TimbreType.PLUCK:
			return SummonType.ACCOMPANIMENT
		MusicData.TimbreType.BOW:
			return SummonType.RESONANCE
		MusicData.TimbreType.BLOW:
			return SummonType.INTERFERENCE
		MusicData.TimbreType.STRIKE:
			return SummonType.RHYTHM
		_:
			# 默认伴奏声部
			return SummonType.ACCOMPANIMENT

# ============================================================
# 召唤物视觉创建
# ============================================================

func _create_summon_visual(summon: Dictionary) -> void:
	var visual := Node2D.new()
	visual.global_position = summon["position"]
	
	var config: Dictionary = summon["config"]
	var color: Color = summon["color"]
	var size: float = summon["size"]
	
	# 主体
	var body := Polygon2D.new()
	var points := PackedVector2Array()
	var vertex_count := 6
	match summon["type"]:
		SummonType.ACCOMPANIMENT:
			vertex_count = 5  # 五角星形
		SummonType.RESONANCE:
			vertex_count = 8  # 八角形
		SummonType.INTERFERENCE:
			vertex_count = 3  # 三角形
		SummonType.RHYTHM:
			vertex_count = 4  # 菱形
	
	for i in range(vertex_count):
		var angle := (TAU / vertex_count) * i - PI / 2.0
		var r := size * 0.5
		# 星形变体
		if summon["type"] == SummonType.ACCOMPANIMENT:
			r = size * (0.5 if i % 2 == 0 else 0.25)
		points.append(Vector2.from_angle(angle) * r)
	
	body.polygon = points
	body.color = color
	body.name = "Body"
	visual.add_child(body)
	
	# 光环（共鸣声部特有）
	if summon["type"] == SummonType.RESONANCE:
		var aura := Polygon2D.new()
		var aura_points := PackedVector2Array()
		var aura_radius: float = config.get("aura_radius", 120.0)
		for i in range(32):
			var angle := (TAU / 32) * i
			aura_points.append(Vector2.from_angle(angle) * aura_radius)
		aura.polygon = aura_points
		aura.color = Color(color.r, color.g, color.b, 0.1)
		aura.name = "Aura"
		visual.add_child(aura)
	
	# 干扰范围（干扰声部特有）
	if summon["type"] == SummonType.INTERFERENCE:
		var slow_ring := Polygon2D.new()
		var ring_points := PackedVector2Array()
		var slow_radius: float = config.get("slow_radius", 100.0)
		for i in range(24):
			var angle := (TAU / 24) * i
			ring_points.append(Vector2.from_angle(angle) * slow_radius)
		slow_ring.polygon = ring_points
		slow_ring.color = Color(color.r, color.g, color.b, 0.08)
		slow_ring.name = "SlowRing"
		visual.add_child(slow_ring)
	
	get_tree().current_scene.add_child(visual)
	summon["visual_node"] = visual

# ============================================================
# 召唤物更新
# ============================================================

func _update_summons(delta: float) -> void:
	var expired_ids: Array[int] = []
	
	for summon in _active_summons:
		if not summon["active"]:
			continue
		
		summon["time_alive"] += delta
		
		# 检查过期
		if summon["time_alive"] >= summon["duration"]:
			summon["active"] = false
			expired_ids.append(summon["id"])
			continue
		
		# 疲劳消耗
		FatigueManager.add_external_fatigue(FATIGUE_COST_PER_SEC * delta)
		
		# 根据类型更新行为
		match summon["type"]:
			SummonType.ACCOMPANIMENT:
				_update_accompaniment(summon, delta)
			SummonType.RESONANCE:
				_update_resonance(summon, delta)
			SummonType.INTERFERENCE:
				_update_interference(summon, delta)
			SummonType.RHYTHM:
				_update_rhythm(summon, delta)
		
		# 更新视觉
		_update_summon_visual(summon, delta)
	
	# 移除过期召唤物
	for id in expired_ids:
		_remove_summon(id)

# ============================================================
# 伴奏声部行为
# ============================================================

func _update_accompaniment(summon: Dictionary, delta: float) -> void:
	var config: Dictionary = summon["config"]
	var player_pos := _get_player_position()
	
	# 跟随玩家（保持一定距离）
	var follow_dist: float = config.get("follow_distance", 60.0)
	var follow_speed: float = config.get("follow_speed", 150.0)
	
	# 轨道运动
	summon["orbit_angle"] += delta * 1.5
	var orbit_target := player_pos + Vector2.from_angle(summon["orbit_angle"]) * follow_dist
	var to_target := orbit_target - summon["position"]
	if to_target.length() > 5.0:
		summon["position"] += to_target.normalized() * follow_speed * delta
	
	# 自动攻击
	summon["attack_timer"] += delta
	var attack_interval: float = config.get("attack_interval", 0.8)
	if summon["attack_timer"] >= attack_interval:
		summon["attack_timer"] = 0.0
		_summon_auto_attack(summon)

func _summon_auto_attack(summon: Dictionary) -> void:
	var config: Dictionary = summon["config"]
	var attack_range: float = config.get("attack_range", 180.0)
	var attack_speed: float = config.get("attack_speed", 500.0)
	var damage: float = summon["base_damage"] * config.get("attack_damage_mult", 0.6)
	
	# 应用共鸣加成
	damage *= (1.0 + _resonance_bonus)
	
	# 找最近敌人
	var nearest := _find_nearest_enemy(summon["position"], attack_range)
	if nearest == Vector2.INF:
		return
	
	var dir := (nearest - summon["position"]).normalized()
	
	# 创建攻击弹体（通过 ProjectileManager 的数据格式）
	var proj_mgr := get_node_or_null("/root/ProjectileManager")
	if proj_mgr == null:
		proj_mgr = get_tree().current_scene.get_node_or_null("ProjectileManager")
	
	if proj_mgr and proj_mgr.has("_projectiles"):
		var proj := {
			"position": summon["position"],
			"velocity": dir * attack_speed,
			"damage": damage,
			"size": 10.0,
			"duration": 0.6,
			"time_alive": 0.0,
			"color": summon["color"].lightened(0.3),
			"active": true,
			"modifier": -1,
			"is_summon_attack": true,
		}
		proj_mgr._projectiles.append(proj)
	
	# 攻击视觉
	_flash_summon(summon)
	summon_attacked.emit(summon["id"], nearest)

# ============================================================
# 共鸣声部行为
# ============================================================

func _update_resonance(summon: Dictionary, delta: float) -> void:
	# 共鸣声部固定位置，不移动
	# 视觉脉冲
	summon["pulse_scale"] = 1.0 + sin(summon["time_alive"] * 3.0) * 0.1

# ============================================================
# 干扰声部行为
# ============================================================

func _update_interference(summon: Dictionary, delta: float) -> void:
	var config: Dictionary = summon["config"]
	var patrol_radius: float = config.get("patrol_radius", 150.0)
	var patrol_speed: float = config.get("patrol_speed", 80.0)
	var slow_radius: float = config.get("slow_radius", 100.0)
	
	# 巡逻移动
	summon["patrol_angle"] += delta * 0.8
	var player_pos := _get_player_position()
	summon["patrol_center"] = summon["patrol_center"].lerp(player_pos, delta * 0.5)
	var patrol_target := summon["patrol_center"] + Vector2.from_angle(summon["patrol_angle"]) * patrol_radius
	var to_target := patrol_target - summon["position"]
	if to_target.length() > 5.0:
		summon["position"] += to_target.normalized() * patrol_speed * delta
	
	# 减速附近敌人
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := summon["position"].distance_to(enemy.global_position)
		if dist < slow_radius:
			# 减速效果
			if enemy.has_method("apply_stun"):
				# 轻微减速（不是完全眩晕）
				var slow_factor: float = config.get("slow_factor", 0.4)
				if enemy is CharacterBody2D:
					enemy.velocity *= (1.0 - slow_factor * delta)
			
			# 干扰伤害
			var interference_dmg: float = config.get("interference_damage", 3.0) * delta
			if enemy.has_method("take_damage"):
				enemy.take_damage(interference_dmg * (1.0 + _resonance_bonus))

# ============================================================
# 节奏声部行为
# ============================================================

func _update_rhythm(summon: Dictionary, delta: float) -> void:
	var config: Dictionary = summon["config"]
	var player_pos := _get_player_position()
	
	# 跟随玩家
	var follow_dist: float = config.get("follow_distance", 40.0)
	var follow_speed: float = config.get("follow_speed", 180.0)
	
	summon["orbit_angle"] += delta * 2.0
	var orbit_target := player_pos + Vector2.from_angle(summon["orbit_angle"]) * follow_dist
	var to_target := orbit_target - summon["position"]
	if to_target.length() > 5.0:
		summon["position"] += to_target.normalized() * follow_speed * delta

# ============================================================
# 节拍回调
# ============================================================

func _on_beat_tick(_beat_index: int) -> void:
	for summon in _active_summons:
		if not summon["active"]:
			continue
		
		# 节奏声部：在节拍时释放脉冲
		if summon["type"] == SummonType.RHYTHM:
			_rhythm_pulse(summon)
		
		# 所有召唤物的节拍视觉脉冲
		_beat_pulse_visual(summon)

func _rhythm_pulse(summon: Dictionary) -> void:
	var config: Dictionary = summon["config"]
	var pulse_damage: float = config.get("pulse_damage", 15.0) * (1.0 + _resonance_bonus)
	var pulse_radius: float = config.get("pulse_radius", 100.0)
	
	# 对范围内敌人造成伤害
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := summon["position"].distance_to(enemy.global_position)
		if dist < pulse_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(pulse_damage)
	
	# 脉冲视觉
	if summon["visual_node"] and is_instance_valid(summon["visual_node"]):
		var ring := Polygon2D.new()
		var points := PackedVector2Array()
		for i in range(24):
			var angle := (TAU / 24) * i
			points.append(Vector2.from_angle(angle) * 5.0)
		ring.polygon = points
		ring.color = Color(summon["color"].r, summon["color"].g, summon["color"].b, 0.5)
		ring.global_position = summon["position"]
		summon["visual_node"].get_parent().add_child(ring)
		
		var tween := ring.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ring, "scale",
			Vector2(pulse_radius / 5.0, pulse_radius / 5.0), 0.3)
		tween.tween_property(ring, "modulate:a", 0.0, 0.4)
		tween.chain()
		tween.tween_callback(ring.queue_free)

# ============================================================
# 共鸣系统
# ============================================================

func _update_resonance_bonus() -> void:
	var old_bonus := _resonance_bonus
	_resonance_bonus = 0.0
	
	# 计算共鸣加成：每个共鸣声部为范围内的其他召唤物提供增伤
	var resonance_summons: Array[Dictionary] = []
	for summon in _active_summons:
		if summon["active"] and summon["type"] == SummonType.RESONANCE:
			resonance_summons.append(summon)
	
	if resonance_summons.is_empty():
		return
	
	# 基础共鸣加成
	_resonance_bonus = resonance_summons.size() * RESONANCE_BASE_BONUS
	
	# 多个共鸣声部之间的协同加成
	if resonance_summons.size() >= 2:
		_resonance_bonus += 0.1 * (resonance_summons.size() - 1)
	
	# 共鸣声部也增强附近玩家的法术伤害
	# 通过信号通知 SpellcraftSystem
	if _resonance_bonus != old_bonus:
		resonance_activated.emit(_resonance_bonus)

## 获取位置处的共鸣加成（供 ProjectileManager 使用）
func get_resonance_bonus_at(pos: Vector2) -> float:
	var bonus := 0.0
	for summon in _active_summons:
		if not summon["active"] or summon["type"] != SummonType.RESONANCE:
			continue
		var config: Dictionary = summon["config"]
		var aura_radius: float = config.get("aura_radius", 120.0)
		var dist := pos.distance_to(summon["position"])
		if dist < aura_radius:
			bonus += config.get("damage_bonus", 0.25)
	return bonus

# ============================================================
# 视觉更新
# ============================================================

func _update_summon_visual(summon: Dictionary, delta: float) -> void:
	var visual: Node2D = summon.get("visual_node")
	if visual == null or not is_instance_valid(visual):
		return
	
	# 位置同步
	visual.global_position = summon["position"]
	
	# 浮动动画
	var float_offset := sin(summon["time_alive"] * 2.0 + summon["id"] * 1.5) * 4.0
	visual.position.y += float_offset * delta * 10.0
	
	# 旋转
	visual.rotation += delta * 0.5
	
	# 缩放脉冲
	var scale_val: float = summon.get("pulse_scale", 1.0)
	visual.scale = Vector2(scale_val, scale_val)
	
	# 淡出（接近过期时）
	var remaining := summon["duration"] - summon["time_alive"]
	if remaining < 2.0:
		var alpha := remaining / 2.0
		visual.modulate.a = alpha
		# 闪烁
		if remaining < 1.0 and fmod(remaining, 0.2) < 0.1:
			visual.visible = false
		else:
			visual.visible = true
	else:
		visual.modulate.a = 1.0
		visual.visible = true

func _flash_summon(summon: Dictionary) -> void:
	var visual: Node2D = summon.get("visual_node")
	if visual == null or not is_instance_valid(visual):
		return
	
	var tween := visual.create_tween()
	tween.tween_property(visual, "modulate", Color.WHITE, 0.05)
	tween.tween_property(visual, "modulate", Color(1, 1, 1, visual.modulate.a), 0.1)

func _beat_pulse_visual(summon: Dictionary) -> void:
	var visual: Node2D = summon.get("visual_node")
	if visual == null or not is_instance_valid(visual):
		return
	
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.1)

# ============================================================
# 召唤物移除
# ============================================================

func _remove_summon(summon_id: int) -> void:
	for i in range(_active_summons.size()):
		if _active_summons[i]["id"] == summon_id:
			var summon := _active_summons[i]
			
			# 移除视觉节点
			var visual: Node2D = summon.get("visual_node")
			if visual and is_instance_valid(visual):
				# 消散动画
				var tween := visual.create_tween()
				tween.set_parallel(true)
				tween.tween_property(visual, "scale", Vector2(0.0, 0.0), 0.3)
				tween.tween_property(visual, "modulate:a", 0.0, 0.3)
				tween.chain()
				tween.tween_callback(visual.queue_free)
			
			_active_summons.remove_at(i)
			summon_expired.emit(summon_id)
			break

func _remove_oldest_summon() -> void:
	if _active_summons.is_empty():
		return
	
	var oldest_id: int = _active_summons[0]["id"]
	_remove_summon(oldest_id)

## 移除所有召唤物
func clear_all() -> void:
	for summon in _active_summons:
		var visual: Node2D = summon.get("visual_node")
		if visual and is_instance_valid(visual):
			visual.queue_free()
	_active_summons.clear()

# ============================================================
# 工具函数
# ============================================================

func _get_player_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.global_position
	return Vector2.ZERO

func _find_nearest_enemy(from_pos: Vector2, max_range: float = INF) -> Vector2:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest_pos := Vector2.INF
	var nearest_dist := max_range
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := from_pos.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_pos = enemy.global_position
	
	return nearest_pos

## 获取活跃召唤物数量
func get_active_count() -> int:
	return _active_summons.size()

## 获取活跃召唤物数据（供 UI 使用）
func get_active_summons_info() -> Array[Dictionary]:
	var info: Array[Dictionary] = []
	for summon in _active_summons:
		info.append({
			"id": summon["id"],
			"type": summon["type"],
			"type_name": summon["type_name"],
			"position": summon["position"],
			"time_remaining": summon["duration"] - summon["time_alive"],
			"color": summon["color"],
		})
	return info

## 获取当前共鸣加成
func get_resonance_bonus() -> float:
	return _resonance_bonus

## 重置系统
func reset() -> void:
	clear_all()
	_next_summon_id = 0
	_resonance_bonus = 0.0
