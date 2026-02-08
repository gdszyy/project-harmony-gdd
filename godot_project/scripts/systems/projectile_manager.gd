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

	# ★ 密度过载精准度惩罚：弹体方向随机偏移
	var accuracy_offset: float = spell_data.get("accuracy_offset", 0.0)
	if accuracy_offset > 0.0:
		var random_offset := randf_range(-accuracy_offset, accuracy_offset)
		aim_dir = aim_dir.rotated(random_offset)

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
		# 拖尾数据
		"trail_positions": [] as Array[Vector2],
		"trail_max": 8,
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

	# ★ 密度过载精准度惩罚：和弦弹体方向也受影响
	var accuracy_offset: float = chord_data.get("accuracy_offset", 0.0)
	if accuracy_offset > 0.0:
		var random_offset := randf_range(-accuracy_offset, accuracy_offset)
		aim_dir = aim_dir.rotated(random_offset)

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
	## 法阵/区域 (属七和弦) — 在指定位置生成持续伤害区域
	## 法阵会缓慢旋转，每 tick 对范围内敌人造成伤害
	## 法阵存在期间会产生减速光环效果
	var target_pos := pos + dir * 200.0
	var base_dmg: float = data.get("damage", 20.0)
	var multiplier: float = data.get("multiplier", 1.0)
	var proj := {
		"position": target_pos,
		"velocity": Vector2.ZERO,
		"damage": base_dmg * multiplier,
		"size": 80.0,
		"max_size": 100.0,
		"duration": 4.0,
		"time_alive": 0.0,
		"color": Color(0.0, 0.6, 1.0),
		"is_field": true,
		"field_type": "damage",
		"field_tick_interval": 0.5,
		"field_tick_timer": 0.0,
		"slow_factor": 0.4,
		"rotation": 0.0,
		"rotation_speed": 2.0,
		"pulse_phase": 0.0,
		"active": true,
		"modifier": -1,
		# 法阵入场动画：从小到大展开
		"spawn_anim": true,
		"spawn_duration": 0.3,
	}
	_projectiles.append(proj)

func _spawn_divine_strike(data: Dictionary, _pos: Vector2, dir: Vector2) -> void:
	## 天降打击 (减七和弦) — 从天而降的高伤害单体攻击
	## 伤害倍率 3.0x，命中时产生小范围爆炸 + 屏幕震动
	## 落点会显示一个警告标记，给玩家蹲避时间
	var target_pos := _get_player_position() + dir * 300.0
	var base_dmg: float = data.get("damage", 100.0)
	var multiplier: float = data.get("multiplier", 3.0)

	# 预警标记（地面光圈）
	var warning := {
		"position": target_pos,
		"velocity": Vector2.ZERO,
		"damage": 0.0,
		"size": 50.0,
		"duration": 0.6,
		"time_alive": 0.0,
		"color": Color(1.0, 0.2, 0.2, 0.4),
		"is_warning_marker": true,
		"active": true,
		"modifier": -1,
		"pulse_phase": 0.0,
	}
	_projectiles.append(warning)

	# 天降弹体（延迟发射，等待警告标记）
	var proj := {
		"position": target_pos + Vector2(0, -600),
		"target_position": target_pos,
		"velocity": Vector2(0, 1200),
		"damage": base_dmg * multiplier,
		"size": 45.0,
		"duration": 2.0,
		"time_alive": -0.4,  # 延迟0.4秒发射
		"color": Color(1.0, 0.15, 0.15),
		"is_divine_strike": true,
		"has_landed": false,
		"impact_radius": 70.0,
		"impact_damage_ratio": 0.5,  # 爆炸伤害为主体的50%
		"active": true,
		"modifier": -1,
		"trail_positions": [] as Array[Vector2],
		"trail_max": 6,
	}
	_projectiles.append(proj)

func _spawn_shield(data: Dictionary, pos: Vector2) -> void:
	## 护盾/治疗法阵 (大七和弦) — 为玩家提供临时护盾 + 持续治疗
	## 立即恢复 25 HP，然后每秒恢复 8 HP
	## 护盾泡泡跟随玩家移动，可吸收一定量的伤害
	## 护盾存在期间减少疲劳度累积速度
	var burst_heal: float = 25.0
	GameManager.heal_player(burst_heal)

	# 同步护盾值到 GameManager
	GameManager.shield_hp = 40.0
	GameManager.max_shield_hp = 40.0

	# 护盾泡泡（跟随玩家）
	var proj := {
		"position": pos,
		"velocity": Vector2.ZERO,
		"damage": 0.0,
		"size": 60.0,
		"duration": 4.0,
		"time_alive": 0.0,
		"color": Color(0.2, 1.0, 0.4, 0.6),
		"is_shield": true,
		"follows_player": true,
		"heal_per_second": 8.0,
		"heal_timer": 0.0,
		"shield_hp": 40.0,
		"max_shield_hp": 40.0,
		"fatigue_reduction": 0.01,  # 每秒减少疲劳度
		"fatigue_timer": 0.0,
		"pulse_phase": 0.0,
		"active": true,
		"modifier": -1,
		# 护盾入场动画
		"spawn_anim": true,
		"spawn_duration": 0.25,
	}
	_projectiles.append(proj)

func _spawn_summon(data: Dictionary, pos: Vector2) -> void:
	## 召唤/构造 (小七和弦) — 在战场上放置自动攻击的构造体
	## 构造体会跟随玩家移动，自动向最近敌人发射小弹体
	## 攻击间隔 0.8 秒，射程 180px，持续 6 秒
	## 构造体会缓慢旋转并发出光芒
	var base_dmg: float = data.get("damage", 15.0)
	var multiplier: float = data.get("multiplier", 0.8)
	var spawn_offset := Vector2(randf_range(-60, 60), randf_range(-60, 60))
	var proj := {
		"position": pos + spawn_offset,
		"velocity": Vector2.ZERO,
		"damage": base_dmg * multiplier,
		"size": 35.0,
		"duration": 6.0,
		"time_alive": 0.0,
		"color": Color(0.3, 0.4, 0.9),
		"is_summon": true,
		"follows_player": true,
		"follow_distance": 80.0,
		"follow_speed": 120.0,
		"attack_interval": 0.8,
		"attack_timer": 0.0,
		"attack_range": 180.0,
		"rotation": randf() * TAU,
		"rotation_speed": 1.5,
		"pulse_phase": randf() * TAU,
		"total_attacks": 0,
		"max_attacks": 8,  # 最多攻击8次后消失
		"active": true,
		"modifier": -1,
		# 入场动画
		"spawn_anim": true,
		"spawn_duration": 0.3,
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

## 属九：风暴区域 — 持续伤害 + 减速 + 旋转视觉
func _spawn_storm_field(data: Dictionary, pos: Vector2) -> void:
	var base_dmg: float = data.get("damage", 50.0)
	var field := {
		"position": pos,
		"velocity": Vector2.ZERO,
		"damage": base_dmg * 0.5,
		"size": 130.0,
		"duration": 5.0,
		"time_alive": 0.0,
		"color": Color(0.3, 0.8, 1.0),
		"active": true,
		"is_field": true,
		"field_type": "storm",
		"field_tick_interval": 0.4,
		"field_tick_timer": 0.0,
		"slow_factor": 0.5,
		"rotation": 0.0,
		"rotation_speed": 4.0,
		"pulse_phase": 0.0,
		"modifier": -1,
		"spawn_anim": true,
		"spawn_duration": 0.4,
	}
	_projectiles.append(field)

## 大九：圣光领域 — 治疗区域 + 伤害加成光环
func _spawn_holy_domain(data: Dictionary, pos: Vector2) -> void:
	var domain := {
		"position": pos,
		"velocity": Vector2.ZERO,
		"damage": 0.0,
		"heal_per_sec": 15.0,
		"size": 110.0,
		"duration": 6.0,
		"time_alive": 0.0,
		"color": Color(1.0, 0.95, 0.6),
		"active": true,
		"is_field": true,
		"is_shield": true,
		"field_type": "heal",
		"heal_per_second": 15.0,
		"heal_timer": 0.0,
		"damage_boost": 0.2,  # 范围内玩家伤害+20%
		"fatigue_reduction": 0.02,
		"fatigue_timer": 0.0,
		"rotation": 0.0,
		"rotation_speed": 1.0,
		"pulse_phase": 0.0,
		"modifier": -1,
		"spawn_anim": true,
		"spawn_duration": 0.5,
	}
	_projectiles.append(domain)

## 减九：湮灭射线 — 贯穿全屏的高伤害射线 (4.0x 伤害倍率)
func _spawn_annihilation_ray(data: Dictionary, pos: Vector2, dir: Vector2) -> void:
	var base_dmg: float = data.get("damage", 80.0)
	var multiplier: float = data.get("multiplier", 4.0)
	# 射线由多个密集弹体组成，模拟光束效果
	var beam_segments := 8
	for i in range(beam_segments):
		var offset_time := float(i) * 0.02  # 微小延迟创建流动感
		var ray := {
			"position": pos + dir * (i * 30.0),
			"velocity": dir * 1500.0,
			"damage": base_dmg * multiplier / float(beam_segments),
			"size": 20.0 - i * 0.5,  # 射线头部稍粗
			"duration": 0.6,
			"time_alive": -offset_time,
			"color": Color(0.8, 0.0, 0.8).lerp(Color(1.0, 0.3, 1.0), float(i) / float(beam_segments)),
			"active": true,
			"pierce": true,
			"max_pierce": 999,
			"pierce_count": 0,
			"is_ray": true,
			"modifier": -1,
			"trail_positions": [] as Array[Vector2],
			"trail_max": 10,
		}
		_projectiles.append(ray)

## 属十一：时空裂雙 — 强力减速区域 + 持续伤害
func _spawn_time_rift(data: Dictionary, pos: Vector2) -> void:
	var base_dmg: float = data.get("damage", 30.0)
	var rift := {
		"position": pos,
		"velocity": Vector2.ZERO,
		"damage": base_dmg * 0.6,
		"size": 160.0,
		"duration": 5.0,
		"time_alive": 0.0,
		"color": Color(0.5, 0.0, 1.0),
		"active": true,
		"is_field": true,
		"field_type": "slow",
		"field_tick_interval": 0.4,
		"field_tick_timer": 0.0,
		"slow_factor": 0.3,
		"rotation": 0.0,
		"rotation_speed": -2.0,  # 反向旋转表示时间扣曲
		"pulse_phase": 0.0,
		"modifier": -1,
		"spawn_anim": true,
		"spawn_duration": 0.5,
	}
	_projectiles.append(rift)

## 属十三：交响风暴 — 多波次环形弹幕 + 螺旋弹道
func _spawn_symphony_storm(data: Dictionary, pos: Vector2) -> void:
	var wave_count := 4
	var projectiles_per_wave := 16
	var base_dmg: float = data.get("damage", 40.0)

	for wave in range(wave_count):
		var wave_offset := float(wave) * (TAU / float(projectiles_per_wave) / 2.0)  # 每波偏转
		for i in range(projectiles_per_wave):
			var angle := (TAU / projectiles_per_wave) * i + wave_offset
			var dir := Vector2.from_angle(angle)
			var speed := 350.0 + wave * 80.0
			var proj := {
				"position": pos,
				"velocity": dir * speed,
				"damage": base_dmg * 0.5 / float(wave_count),
				"size": 18.0 - wave * 1.5,
				"duration": 2.5,
				"time_alive": -wave * 0.35,  # 延迟发射
				"color": Color(1.0, 0.6, 0.0).lerp(Color(1.0, 0.2, 0.0), float(wave) / float(wave_count)),
				"active": true,
				"modifier": -1,
				"wave_trajectory": wave % 2 == 1,  # 奇数波次使用螺旋弹道
				"wave_freq": 6.0,
				"wave_amp": 40.0,
				"trail_positions": [] as Array[Vector2],
				"trail_max": 6,
			}
			_projectiles.append(proj)

## 减十三：终焉乐章 — 毁灭性全屏攻击 (5.0x 伤害倍率)
## 分两步：先蓄力收缩，然后全屏爆发
func _spawn_finale(data: Dictionary, pos: Vector2) -> void:
	var base_dmg: float = data.get("damage", 200.0)
	var multiplier: float = data.get("multiplier", 5.0)

	# 第一步：蓄力收缩效果（向内吸引的光环）
	var charge := {
		"position": pos,
		"velocity": Vector2.ZERO,
		"damage": 0.0,
		"size": 200.0,
		"duration": 0.8,
		"time_alive": 0.0,
		"color": Color(1.0, 0.0, 0.0, 0.6),
		"is_shockwave": true,
		"expand_speed": -200.0,  # 负值 = 收缩
		"max_size": 200.0,
		"active": true,
		"modifier": -1,
	}
	_projectiles.append(charge)

	# 第二步：全屏爆发（延迟发射）
	var finale := {
		"position": pos,
		"velocity": Vector2.ZERO,
		"damage": base_dmg * multiplier,
		"size": 10.0,
		"max_size": 2000.0,
		"duration": 1.0,
		"time_alive": -0.8,  # 蓄力完成后爆发
		"color": Color(1.0, 0.1, 0.0),
		"active": true,
		"is_shockwave": true,
		"is_aoe": true,
		"expand_speed": 3000.0,
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
			# 护盾消失时清除 GameManager 中的护盾值
			if proj.get("is_shield", false):
				GameManager.shield_hp = 0.0
				GameManager.max_shield_hp = 0.0
			continue

		# 蓄力弹体特殊处理
		if proj.get("is_charged", false) and not proj.get("charged", false):
			if proj["time_alive"] >= proj.get("charge_time", 1.0):
				proj["charged"] = true
				proj["velocity"] = proj.get("final_velocity", Vector2(800, 0))
			continue

		# 冲击波扩展/收缩
		if proj.get("is_shockwave", false):
			var expand_spd: float = proj.get("expand_speed", 200.0)
			proj["size"] += expand_spd * delta
			if expand_spd > 0.0:
				proj["size"] = min(proj["size"], proj.get("max_size", 150.0))
			else:
				proj["size"] = max(proj["size"], 5.0)  # 收缩最小值
			continue

		# 天降打击着陆检测
		if proj.get("is_divine_strike", false) and not proj.get("has_landed", false):
			var target_y: float = proj.get("target_position", proj["position"]).y
			if proj["position"].y >= target_y:
				proj["has_landed"] = true
				proj["position"].y = target_y
				proj["velocity"] = Vector2.ZERO
				# 着陆爆炸
				var impact := {
					"position": proj["position"],
					"velocity": Vector2.ZERO,
					"damage": proj["damage"] * proj.get("impact_damage_ratio", 0.5),
					"size": proj.get("impact_radius", 70.0),
					"duration": 0.3,
					"time_alive": 0.0,
					"color": Color(1.0, 0.4, 0.1, 0.8),
					"active": true,
					"is_explosion_effect": true,
					"modifier": -1,
				}
				_projectiles.append(impact)
				# 着陆后弹体快速消失
				proj["duration"] = proj["time_alive"] + 0.3

		# 警告标记脉冲
		if proj.get("is_warning_marker", false):
			proj["pulse_phase"] = proj.get("pulse_phase", 0.0) + delta * 15.0
			var pulse := (sin(proj["pulse_phase"]) + 1.0) * 0.5
			proj["color"].a = 0.2 + pulse * 0.4

		# 护盾跟随玩家 + 疲劳减少
		if proj.get("is_shield", false) and proj.get("follows_player", false):
			proj["position"] = _get_player_position()
			# 疲劳度减少
			proj["fatigue_timer"] = proj.get("fatigue_timer", 0.0) + delta
			if proj["fatigue_timer"] >= 1.0:
				proj["fatigue_timer"] = 0.0
				if FatigueManager:
					FatigueManager.reduce_fatigue(proj.get("fatigue_reduction", 0.01))
			# 护盾脉冲效果
			proj["pulse_phase"] = proj.get("pulse_phase", 0.0) + delta * 3.0
			var shield_ratio: float = proj.get("shield_hp", 0.0) / proj.get("max_shield_hp", 1.0)
			proj["color"].a = 0.3 + shield_ratio * 0.4 + sin(proj["pulse_phase"]) * 0.1

		# 入场动画（从小到大展开）
		if proj.get("spawn_anim", false):
			var spawn_dur: float = proj.get("spawn_duration", 0.3)
			if proj["time_alive"] < spawn_dur:
				var progress: float = proj["time_alive"] / spawn_dur
				# 弹性缩放：超调后回弹
				var scale_factor: float = 1.0 + (1.0 - progress) * 0.3
				proj["_render_scale"] = progress * scale_factor
			else:
				proj["spawn_anim"] = false
				proj["_render_scale"] = 1.0

		# 追踪逻辑（HOMING 修饰符 — 已实现）
		if proj.get("homing", false):
			var nearest_enemy := _find_nearest_enemy(proj["position"])
			if nearest_enemy != Vector2.INF:
				var to_enemy = (nearest_enemy - proj["position"]).normalized()
				var current_dir = proj["velocity"].normalized()
				var homing_strength: float = proj.get("homing_strength", 5.0)
				var new_dir = current_dir.lerp(to_enemy, homing_strength * delta).normalized()
				proj["velocity"] = new_dir * proj["velocity"].length()

		# 摇摆弹道 (SWING S型轨迹)
		if proj.get("wave_trajectory", false):
			# 正弦波横向偏移：频率随时间递减（S型收敛），振幅受弹体速度影响
			var wave_freq: float = proj.get("wave_freq", 8.0)
			var wave_amp: float = proj.get("wave_amp", 80.0)
			var t = proj["time_alive"]
			# S型轨迹：频率随时间略微递减，振幅随时间衰减
			var decay := exp(-t * 0.5)  # 缓慢衰减
			var current_offset := sin(t * wave_freq) * wave_amp * decay * delta
			var perp = proj["velocity"].normalized().rotated(PI / 2.0)
			proj["position"] += perp * current_offset
			# 记录拖尾位置
			if proj.has("trail_positions"):
				proj["trail_positions"].append(proj["position"])
				if proj["trail_positions"].size() > proj.get("trail_max", 8):
					proj["trail_positions"].pop_front()

		# 召唤物自动攻击
		if proj.get("is_summon", false):
			# 旋转动画
			proj["rotation"] = proj.get("rotation", 0.0) + proj.get("rotation_speed", 1.5) * delta
			proj["pulse_phase"] = proj.get("pulse_phase", 0.0) + delta * 2.0
			# 自动攻击
			proj["attack_timer"] += delta
			if proj["attack_timer"] >= proj.get("attack_interval", 0.8):
				proj["attack_timer"] = 0.0
				_summon_attack(proj)
				proj["total_attacks"] = proj.get("total_attacks", 0) + 1
				# 达到最大攻击次数后消失
				if proj["total_attacks"] >= proj.get("max_attacks", 8):
					proj["active"] = false
			# 跟随玩家（保持一定距离）
			var player_pos := _get_player_position()
			var to_player = (player_pos - proj["position"])
			var follow_dist: float = proj.get("follow_distance", 80.0)
			var follow_spd: float = proj.get("follow_speed", 120.0)
			if to_player.length() > follow_dist:
				proj["position"] += to_player.normalized() * follow_spd * delta
			# 小幅径向浮动（视觉效果）
			var orbit_offset := Vector2(
				cos(proj["rotation"]) * 5.0,
				sin(proj["rotation"]) * 5.0
			)
			proj["position"] += orbit_offset * delta

		# 位置更新
		proj["position"] += proj["velocity"] * delta

		# 通用拖尾记录（非摇摆弹体也有短拖尾）
		if proj.has("trail_positions") and not proj.get("wave_trajectory", false):
			# 每隔几帧记录一次位置（降低开销）
			if Engine.get_process_frames() % 3 == 0:
				proj["trail_positions"].append(proj["position"])
				if proj["trail_positions"].size() > proj.get("trail_max", 8):
					proj["trail_positions"].pop_front()

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

	var dir = (nearest - summon_proj["position"]).normalized()
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
				var angle = proj["velocity"].angle() + randf_range(-0.5, 0.5)
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
			proj["wave_freq"] = 8.0
			proj["wave_amp"] = 80.0
			proj["trail_positions"] = [] as Array[Vector2]
			proj["trail_max"] = 12  # 摇摆弹道拖尾更长
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
			var dist = proj["position"].distance_to(enemy["position"])
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

	# 计算活跃弹体 + 拖尾粒子总数
	var active_count := 0
	var trail_count := 0
	for proj in _projectiles:
		if proj["active"] and proj["time_alive"] >= 0.0:
			active_count += 1
			if proj.has("trail_positions"):
				trail_count += proj["trail_positions"].size()

	var total_instances := active_count + trail_count
	var mm := _multi_mesh_instance.multimesh

	if mm.instance_count != total_instances:
		mm.instance_count = total_instances
		mm.visible_instance_count = total_instances

	var idx := 0
	for proj in _projectiles:
		if not proj["active"] or proj["time_alive"] < 0.0:
			continue
		if idx >= total_instances:
			break

		# 渲染弹体本体
		var t := Transform2D()
		var scale_factor: float = proj["size"] / 16.0  # 基准大小16px
		# 应用入场动画缩放
		var render_scale: float = proj.get("_render_scale", 1.0)
		scale_factor *= render_scale
		# 应用旋转（法阵/召唤物）
		var rot: float = proj.get("rotation", 0.0)
		if rot != 0.0:
			t = t.rotated(rot)
		t = t.scaled(Vector2(scale_factor, scale_factor))
		t.origin = proj["position"]

		mm.set_instance_transform_2d(idx, t)
		mm.set_instance_color(idx, proj["color"])
		idx += 1

		# 渲染拖尾粒子（透明度和大小递减）
		if proj.has("trail_positions") and not proj["trail_positions"].is_empty():
			var trail: Array = proj["trail_positions"]
			var trail_size := trail.size()
			for ti in range(trail_size):
				if idx >= total_instances:
					break
				var progress := float(ti) / float(trail_size)  # 0.0 = 最旧, 1.0 = 最新
				var trail_alpha := progress * 0.6  # 透明度从0到0.6
				var trail_scale := scale_factor * (0.3 + progress * 0.5)  # 大小从30%到80%
				var trail_t := Transform2D()
				trail_t = trail_t.scaled(Vector2(trail_scale, trail_scale))
				trail_t.origin = trail[ti]
				mm.set_instance_transform_2d(idx, trail_t)
				var trail_color = proj["color"]
				trail_color.a = trail_alpha
				mm.set_instance_color(idx, trail_color)
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
