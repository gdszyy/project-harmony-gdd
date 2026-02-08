## spell_visual_manager.gd
## 法术视觉效果管理器
## 为所有法术形态提供独特的视觉表现，与 ProjectileManager 的数据层分离。
## ProjectileManager 负责弹体逻辑（碰撞、伤害），本管理器负责纯视觉效果。
##
## 视觉效果分类：
## 1. 基础和弦法术（强化弹体、DOT、爆炸、冲击波、法阵、天降、护盾、召唤、蓄力）
## 2. 扩展和弦法术（风暴区域、圣光领域、湮灭射线、时空裂隙、交响风暴、终焉乐章）
## 3. 施法特效（施法光环、节拍脉冲、和弦进行完成特效）
## 4. 修饰符特效（穿透拖尾、追踪轨迹、分裂爆发、回响残影、散射扩散）
extends Node2D

# ============================================================
# 信号
# ============================================================
signal visual_effect_spawned(effect_type: String, position: Vector2)

# ============================================================
# 配置
# ============================================================
const MAX_VISUAL_EFFECTS: int = 200
const CLEANUP_INTERVAL: float = 1.0

# ============================================================
# 活跃视觉效果
# ============================================================
var _active_effects: Array[Dictionary] = []
var _cleanup_timer: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 连接法术系统信号
	SpellcraftSystem.spell_cast.connect(_on_spell_cast)
	SpellcraftSystem.chord_cast.connect(_on_chord_cast)
	SpellcraftSystem.progression_resolved.connect(_on_progression_resolved)
	SpellcraftSystem.modifier_applied.connect(_on_modifier_applied)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	_update_effects(delta)
	
	_cleanup_timer += delta
	if _cleanup_timer >= CLEANUP_INTERVAL:
		_cleanup_timer = 0.0
		_cleanup_expired()

# ============================================================
# 信号处理
# ============================================================

func _on_spell_cast(spell_data: Dictionary) -> void:
	var player_pos := _get_player_position()
	
	# 施法光环
	_spawn_cast_aura(player_pos, spell_data)
	
	# 修饰符视觉
	var modifier = spell_data.get("modifier", -1)
	if modifier >= 0:
		_spawn_modifier_visual(player_pos, modifier, spell_data)
	
	# 暴击视觉
	if spell_data.get("is_crit", false):
		_spawn_crit_flash(player_pos)

func _on_chord_cast(chord_data: Dictionary) -> void:
	var player_pos := _get_player_position()
	var spell_form = chord_data.get("spell_form", -1)
	
	# 和弦施法光环（更华丽）
	_spawn_chord_cast_aura(player_pos, chord_data)
	
	# 根据法术形态生成对应视觉效果
	match spell_form:
		MusicData.SpellForm.ENHANCED_PROJECTILE:
			_vfx_enhanced_projectile(player_pos, chord_data)
		MusicData.SpellForm.DOT_PROJECTILE:
			_vfx_dot_projectile(player_pos, chord_data)
		MusicData.SpellForm.EXPLOSIVE:
			_vfx_explosive(player_pos, chord_data)
		MusicData.SpellForm.SHOCKWAVE:
			_vfx_shockwave(player_pos, chord_data)
		MusicData.SpellForm.FIELD:
			_vfx_field(player_pos, chord_data)
		MusicData.SpellForm.DIVINE_STRIKE:
			_vfx_divine_strike(player_pos, chord_data)
		MusicData.SpellForm.SHIELD_HEAL:
			_vfx_shield_heal(player_pos, chord_data)
		MusicData.SpellForm.SUMMON:
			_vfx_summon(player_pos, chord_data)
		MusicData.SpellForm.CHARGED:
			_vfx_charged(player_pos, chord_data)
		MusicData.SpellForm.STORM_FIELD:
			_vfx_storm_field(player_pos, chord_data)
		MusicData.SpellForm.HOLY_DOMAIN:
			_vfx_holy_domain(player_pos, chord_data)
		MusicData.SpellForm.ANNIHILATION_RAY:
			_vfx_annihilation_ray(player_pos, chord_data)
		MusicData.SpellForm.TIME_RIFT:
			_vfx_time_rift(player_pos, chord_data)
		MusicData.SpellForm.SYMPHONY_STORM:
			_vfx_symphony_storm(player_pos, chord_data)
		MusicData.SpellForm.FINALE:
			_vfx_finale(player_pos, chord_data)

func _on_progression_resolved(progression: Dictionary) -> void:
	var player_pos := _get_player_position()
	_spawn_progression_resolve_vfx(player_pos, progression)

func _on_modifier_applied(modifier: MusicData.ModifierEffect) -> void:
	var player_pos := _get_player_position()
	_spawn_modifier_ready_indicator(player_pos, modifier)

# ============================================================
# 施法光环
# ============================================================

func _spawn_cast_aura(pos: Vector2, spell_data: Dictionary) -> void:
	var color: Color = spell_data.get("color", Color(0.0, 1.0, 0.8))
	
	# 简洁的施法脉冲
	var ring := _create_ring(pos, 5.0, color, 0.4)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(8.0, 8.0), 0.2)
	tween.tween_property(ring, "modulate:a", 0.0, 0.25)
	tween.chain()
	tween.tween_callback(ring.queue_free)

func _spawn_chord_cast_aura(pos: Vector2, chord_data: Dictionary) -> void:
	var spell_form = chord_data.get("spell_form", -1)
	var color := _get_spell_form_color(spell_form)
	
	# 双层光环
	var outer := _create_ring(pos, 5.0, color, 0.3)
	var inner := _create_ring(pos, 3.0, color.lightened(0.3), 0.5)
	
	var tween := outer.create_tween()
	tween.set_parallel(true)
	tween.tween_property(outer, "scale", Vector2(12.0, 12.0), 0.3)
	tween.tween_property(outer, "modulate:a", 0.0, 0.35)
	tween.chain()
	tween.tween_callback(outer.queue_free)
	
	var tween2 := inner.create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(inner, "scale", Vector2(8.0, 8.0), 0.2)
	tween2.tween_property(inner, "modulate:a", 0.0, 0.3)
	tween2.chain()
	tween2.tween_callback(inner.queue_free)
	
	# 法术名称浮动文字
	_spawn_floating_text(pos + Vector2(0, -30), chord_data.get("spell_name", ""), color)

# ============================================================
# 基础和弦法术视觉效果
# ============================================================

## 强化弹体：金色光芒爆发
func _vfx_enhanced_projectile(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(1.0, 0.9, 0.3)
	_spawn_radial_particles(pos, color, 8, 30.0, 0.3)
	visual_effect_spawned.emit("enhanced_projectile", pos)

## DOT弹体：紫色毒雾扩散
func _vfx_dot_projectile(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(0.4, 0.0, 0.8, 0.6)
	for i in range(5):
		var offset := Vector2(randf_range(-20, 20), randf_range(-20, 20))
		var cloud := _create_polygon(pos + offset, 8.0, 6, color)
		var tween := cloud.create_tween()
		tween.set_parallel(true)
		tween.tween_property(cloud, "scale", Vector2(3.0, 3.0), 0.5)
		tween.tween_property(cloud, "modulate:a", 0.0, 0.6)
		tween.tween_property(cloud, "position", cloud.position + offset * 2, 0.6)
		tween.chain()
		tween.tween_callback(cloud.queue_free)
	visual_effect_spawned.emit("dot_projectile", pos)

## 爆炸弹体：橙色火焰爆发
func _vfx_explosive(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(1.0, 0.5, 0.0)
	_spawn_radial_particles(pos, color, 12, 50.0, 0.4)
	
	# 内核闪光
	var flash := _create_polygon(pos, 15.0, 8, Color.WHITE)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector2(3.0, 3.0), 0.1)
	tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)
	visual_effect_spawned.emit("explosive", pos)

## 冲击波：红色环形扩散 + 地面裂纹
func _vfx_shockwave(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(0.8, 0.0, 0.2)
	
	# 多层冲击波环
	for i in range(3):
		var delay := i * 0.08
		get_tree().create_timer(delay).timeout.connect(func():
			var ring := _create_ring(pos, 5.0, color.lightened(i * 0.15), 0.6 - i * 0.15)
			var tween := ring.create_tween()
			tween.set_parallel(true)
			tween.tween_property(ring, "scale", Vector2(30.0, 30.0), 0.5)
			tween.tween_property(ring, "modulate:a", 0.0, 0.6)
			tween.chain()
			tween.tween_callback(ring.queue_free)
		)
	
	# 地面裂纹
	for i in range(6):
		var angle := (TAU / 6) * i + randf() * 0.3
		var crack := Line2D.new()
		crack.width = 2.0
		crack.default_color = color
		crack.add_point(Vector2.ZERO)
		crack.add_point(Vector2.from_angle(angle) * 5.0)
		crack.global_position = pos
		add_child(crack)
		
		var tween := crack.create_tween()
		tween.tween_method(func(t: float):
			if is_instance_valid(crack) and crack.get_point_count() > 1:
				crack.set_point_position(1, Vector2.from_angle(angle) * t * 80.0)
		, 0.0, 1.0, 0.3)
		tween.tween_property(crack, "modulate:a", 0.0, 0.3)
		tween.tween_callback(crack.queue_free)
	
	visual_effect_spawned.emit("shockwave", pos)

## 法阵/区域：蓝色魔法阵 + 旋转符文
func _vfx_field(pos: Vector2, data: Dictionary) -> void:
	var aim_dir := _get_aim_direction()
	var target_pos := pos + aim_dir * 200.0
	var color := Color(0.0, 0.6, 1.0)
	
	# 法阵外环
	var outer := _create_ring(target_pos, 60.0, color, 0.3)
	
	# 法阵内环（旋转）
	var inner := _create_ring(target_pos, 40.0, color.lightened(0.2), 0.2)
	
	# 十字线
	for i in range(4):
		var angle := (PI / 2) * i
		var line := Line2D.new()
		line.width = 1.5
		line.default_color = Color(color.r, color.g, color.b, 0.3)
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2.from_angle(angle) * 60.0)
		line.global_position = target_pos
		add_child(line)
		
		var tween := line.create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 4.0)
		tween.tween_callback(line.queue_free)
	
	# 旋转动画
	_active_effects.append({
		"nodes": [outer, inner],
		"type": "field",
		"duration": 4.0,
		"time_alive": 0.0,
		"rotation_speed": 1.5,
	})
	
	visual_effect_spawned.emit("field", target_pos)

## 天降打击：红色光柱 + 落地冲击
func _vfx_divine_strike(pos: Vector2, data: Dictionary) -> void:
	var aim_dir := _get_aim_direction()
	var target_pos := pos + aim_dir * 300.0
	var color := Color(1.0, 0.2, 0.2)
	
	# 预警标记
	var warning := _create_ring(target_pos, 40.0, Color(1.0, 0.0, 0.0, 0.3), 0.3)
	var warn_tween := warning.create_tween()
	warn_tween.tween_property(warning, "modulate:a", 0.8, 0.3)
	warn_tween.tween_property(warning, "modulate:a", 0.3, 0.3)
	warn_tween.tween_callback(warning.queue_free)
	
	# 光柱（延迟出现）
	get_tree().create_timer(0.5).timeout.connect(func():
		# 垂直光柱
		var pillar := Line2D.new()
		pillar.width = 20.0
		pillar.default_color = Color(1.0, 0.3, 0.1, 0.8)
		pillar.add_point(Vector2(0, -600))
		pillar.add_point(Vector2(0, 0))
		pillar.global_position = target_pos
		add_child(pillar)
		
		var tween := pillar.create_tween()
		tween.tween_property(pillar, "width", 40.0, 0.1)
		tween.tween_property(pillar, "width", 5.0, 0.3)
		tween.tween_property(pillar, "modulate:a", 0.0, 0.2)
		tween.tween_callback(pillar.queue_free)
		
		# 落地冲击波
		var impact := _create_ring(target_pos, 5.0, Color.WHITE, 0.8)
		var imp_tween := impact.create_tween()
		imp_tween.set_parallel(true)
		imp_tween.tween_property(impact, "scale", Vector2(20.0, 20.0), 0.3)
		imp_tween.tween_property(impact, "modulate:a", 0.0, 0.4)
		imp_tween.chain()
		imp_tween.tween_callback(impact.queue_free)
		
		# 碎片
		_spawn_radial_particles(target_pos, color, 16, 60.0, 0.5)
	)
	
	visual_effect_spawned.emit("divine_strike", target_pos)

## 护盾/治疗法阵：绿色六角护盾 + 治疗粒子
func _vfx_shield_heal(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(0.2, 1.0, 0.4)
	
	# 六角护盾
	var shield := _create_polygon(pos, 50.0, 6, Color(color.r, color.g, color.b, 0.15))
	
	# 护盾边框
	var border := _create_ring(pos, 50.0, color, 0.4)
	
	# 治疗粒子上升
	for i in range(8):
		get_tree().create_timer(i * 0.3).timeout.connect(func():
			var particle := _create_polygon(
				pos + Vector2(randf_range(-30, 30), randf_range(-10, 10)),
				4.0, 4, Color(0.3, 1.0, 0.5, 0.7)
			)
			var tween := particle.create_tween()
			tween.set_parallel(true)
			tween.tween_property(particle, "position",
				particle.position + Vector2(0, -40), 0.8)
			tween.tween_property(particle, "modulate:a", 0.0, 0.8)
			tween.tween_property(particle, "scale", Vector2(0.3, 0.3), 0.8)
			tween.chain()
			tween.tween_callback(particle.queue_free)
		)
	
	# 护盾持续动画
	_active_effects.append({
		"nodes": [shield, border],
		"type": "shield",
		"duration": 3.0,
		"time_alive": 0.0,
		"position": pos,
	})
	
	visual_effect_spawned.emit("shield_heal", pos)

## 召唤：蓝色召唤阵 + 实体凝聚
func _vfx_summon(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(0.3, 0.3, 0.8)
	var summon_pos := pos + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	
	# 召唤阵
	var circle := _create_ring(summon_pos, 30.0, color, 0.5)
	var tween := circle.create_tween()
	tween.tween_property(circle, "rotation", TAU, 1.0)
	tween.parallel().tween_property(circle, "modulate:a", 0.0, 1.2)
	tween.tween_callback(circle.queue_free)
	
	# 凝聚粒子（从外向内）
	for i in range(12):
		var angle := (TAU / 12) * i
		var start := summon_pos + Vector2.from_angle(angle) * 60.0
		var particle := _create_polygon(start, 3.0, 4, color.lightened(0.3))
		var p_tween := particle.create_tween()
		p_tween.tween_property(particle, "global_position", summon_pos, 0.5)
		p_tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.6)
		p_tween.tween_callback(particle.queue_free)
	
	visual_effect_spawned.emit("summon", summon_pos)

## 蓄力弹体：黄色能量聚集 + 释放爆发
func _vfx_charged(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(1.0, 1.0, 0.0)
	
	# 能量聚集
	for i in range(8):
		var angle := (TAU / 8) * i
		var start := pos + Vector2.from_angle(angle) * 40.0
		var particle := _create_polygon(start, 4.0, 3, color)
		var tween := particle.create_tween()
		tween.tween_property(particle, "global_position", pos, 0.8)
		tween.parallel().tween_property(particle, "scale", Vector2(2.0, 2.0), 0.8)
		tween.tween_callback(particle.queue_free)
	
	# 延迟释放闪光
	get_tree().create_timer(1.0).timeout.connect(func():
		var flash := _create_polygon(pos, 20.0, 8, Color.WHITE)
		var tween := flash.create_tween()
		tween.tween_property(flash, "scale", Vector2(3.0, 3.0), 0.1)
		tween.tween_property(flash, "modulate:a", 0.0, 0.2)
		tween.tween_callback(flash.queue_free)
	)
	
	visual_effect_spawned.emit("charged", pos)

# ============================================================
# 扩展和弦法术视觉效果
# ============================================================

## 风暴区域：旋转的蓝色风暴漩涡
func _vfx_storm_field(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(0.3, 0.8, 1.0)
	
	# 漩涡中心
	var center := _create_polygon(pos, 10.0, 8, color)
	
	# 旋转臂
	var arms: Array[Node2D] = []
	for i in range(3):
		var arm := Line2D.new()
		arm.width = 3.0
		arm.default_color = Color(color.r, color.g, color.b, 0.5)
		var arm_points := PackedVector2Array()
		for j in range(20):
			var t := float(j) / 20.0
			var r := t * 120.0
			var a := t * TAU * 2.0 + (TAU / 3.0) * i
			arm_points.append(Vector2.from_angle(a) * r)
		for pt in arm_points:
			arm.add_point(pt)
		arm.global_position = pos
		add_child(arm)
		arms.append(arm)
	
	# 旋转动画
	_active_effects.append({
		"nodes": [center] + arms,
		"type": "storm",
		"duration": 5.0,
		"time_alive": 0.0,
		"rotation_speed": 3.0,
		"position": pos,
	})
	
	visual_effect_spawned.emit("storm_field", pos)

## 圣光领域：金色光柱 + 治疗光环
func _vfx_holy_domain(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(1.0, 0.95, 0.6)
	
	# 光柱
	var pillar := Line2D.new()
	pillar.width = 40.0
	pillar.default_color = Color(1.0, 0.95, 0.6, 0.15)
	pillar.add_point(Vector2(0, -400))
	pillar.add_point(Vector2(0, 0))
	pillar.global_position = pos
	add_child(pillar)
	
	# 底部光环
	var aura := _create_ring(pos, 100.0, color, 0.2)
	
	# 上升光粒
	_active_effects.append({
		"nodes": [pillar, aura],
		"type": "holy",
		"duration": 6.0,
		"time_alive": 0.0,
		"position": pos,
		"particle_timer": 0.0,
		"particle_interval": 0.3,
		"color": color,
	})
	
	visual_effect_spawned.emit("holy_domain", pos)

## 湮灭射线：紫色激光 + 灼烧痕迹
func _vfx_annihilation_ray(pos: Vector2, _data: Dictionary) -> void:
	var aim_dir := _get_aim_direction()
	var color := Color(0.8, 0.0, 0.8)
	
	# 主射线
	var ray := Line2D.new()
	ray.width = 8.0
	ray.default_color = color
	ray.add_point(Vector2.ZERO)
	ray.add_point(aim_dir * 800.0)
	ray.global_position = pos
	add_child(ray)
	
	# 射线光晕
	var glow := Line2D.new()
	glow.width = 24.0
	glow.default_color = Color(color.r, color.g, color.b, 0.3)
	glow.add_point(Vector2.ZERO)
	glow.add_point(aim_dir * 800.0)
	glow.global_position = pos
	add_child(glow)
	
	var tween := ray.create_tween()
	tween.tween_property(ray, "width", 16.0, 0.1)
	tween.tween_property(ray, "width", 2.0, 0.5)
	tween.parallel().tween_property(ray, "modulate:a", 0.0, 0.6)
	tween.tween_callback(ray.queue_free)
	
	var tween2 := glow.create_tween()
	tween2.tween_property(glow, "modulate:a", 0.0, 0.7)
	tween2.tween_callback(glow.queue_free)
	
	# 灼烧粒子
	for i in range(10):
		var t := float(i) / 10.0
		var burn_pos := pos + aim_dir * 800.0 * t
		_spawn_radial_particles(burn_pos, color, 3, 15.0, 0.3)
	
	visual_effect_spawned.emit("annihilation_ray", pos)

## 时空裂隙：紫色扭曲空间 + 时间减速视觉
func _vfx_time_rift(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(0.5, 0.0, 1.0)
	
	# 裂隙中心
	var rift := _create_polygon(pos, 20.0, 5, Color(0.0, 0.0, 0.0, 0.5))
	
	# 扭曲环
	var rings: Array[Node2D] = []
	for i in range(3):
		var ring := _create_ring(pos, 50.0 + i * 30.0,
			Color(color.r, color.g, color.b, 0.3 - i * 0.08), 0.3)
		rings.append(ring)
	
	_active_effects.append({
		"nodes": [rift] + rings,
		"type": "time_rift",
		"duration": 4.0,
		"time_alive": 0.0,
		"rotation_speed": -2.0,  # 反向旋转
		"position": pos,
	})
	
	visual_effect_spawned.emit("time_rift", pos)

## 交响风暴：多色波次弹幕视觉
func _vfx_symphony_storm(pos: Vector2, _data: Dictionary) -> void:
	var colors := [
		Color(1.0, 0.3, 0.0),
		Color(0.0, 0.8, 1.0),
		Color(1.0, 1.0, 0.0),
	]
	
	for wave in range(3):
		get_tree().create_timer(wave * 0.3).timeout.connect(func():
			var color: Color = colors[wave % colors.size()]
			var ring := _create_ring(pos, 5.0, color, 0.6)
			var tween := ring.create_tween()
			tween.set_parallel(true)
			tween.tween_property(ring, "scale", Vector2(40.0, 40.0), 0.5)
			tween.tween_property(ring, "modulate:a", 0.0, 0.6)
			tween.chain()
			tween.tween_callback(ring.queue_free)
		)
	
	visual_effect_spawned.emit("symphony_storm", pos)

## 终焉乐章：全屏白色闪光 + 红色冲击
func _vfx_finale(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(1.0, 0.0, 0.0)
	
	# 全屏白色闪光
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.8)
	flash.size = Vector2(2000, 2000)
	flash.position = Vector2(-1000, -1000)
	flash.z_index = 100
	add_child(flash)
	
	var tween := flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.5)
	tween.tween_callback(flash.queue_free)
	
	# 多层冲击波
	for i in range(5):
		get_tree().create_timer(i * 0.05).timeout.connect(func():
			var ring := _create_ring(pos, 10.0, color.lightened(i * 0.1), 0.8 - i * 0.1)
			var r_tween := ring.create_tween()
			r_tween.set_parallel(true)
			r_tween.tween_property(ring, "scale", Vector2(100.0, 100.0), 0.8)
			r_tween.tween_property(ring, "modulate:a", 0.0, 1.0)
			r_tween.chain()
			r_tween.tween_callback(ring.queue_free)
		)
	
	visual_effect_spawned.emit("finale", pos)

# ============================================================
# 和弦进行完成特效
# ============================================================

func _spawn_progression_resolve_vfx(pos: Vector2, progression: Dictionary) -> void:
	var effect_type: String = progression.get("effect", {}).get("type", "")
	var color := Color.WHITE
	
	match effect_type:
		"burst_heal_or_damage":
			color = Color(0.0, 1.0, 0.5)  # D→T 绿色
		"empower_next":
			color = Color(1.0, 0.8, 0.0)  # T→D 金色
		"cooldown_reduction":
			color = Color(0.3, 0.6, 1.0)  # PD→D 蓝色
	
	# 和弦进行完成光环
	var ring := _create_ring(pos, 10.0, color, 0.7)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(15.0, 15.0), 0.4)
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.chain()
	tween.tween_callback(ring.queue_free)
	
	# 文字提示
	var text := ""
	match effect_type:
		"burst_heal_or_damage": text = "终止解决!"
		"empower_next": text = "增幅就绪!"
		"cooldown_reduction": text = "冷却缩减!"
	
	_spawn_floating_text(pos + Vector2(0, -40), text, color)

# ============================================================
# 修饰符视觉
# ============================================================

func _spawn_modifier_visual(pos: Vector2, modifier: MusicData.ModifierEffect, _data: Dictionary) -> void:
	match modifier:
		MusicData.ModifierEffect.PIERCE:
			# 穿透：箭头形粒子
			_spawn_radial_particles(pos, Color(0.8, 0.8, 0.8), 4, 20.0, 0.2)
		MusicData.ModifierEffect.HOMING:
			# 追踪：螺旋粒子
			for i in range(6):
				var angle := (TAU / 6) * i
				var particle := _create_polygon(pos + Vector2.from_angle(angle) * 30.0, 3.0, 3, Color(0.0, 1.0, 0.5))
				var tween := particle.create_tween()
				tween.tween_property(particle, "global_position", pos, 0.3)
				tween.tween_property(particle, "modulate:a", 0.0, 0.1)
				tween.tween_callback(particle.queue_free)
		MusicData.ModifierEffect.SPLIT:
			# 分裂：三叉粒子
			_spawn_radial_particles(pos, Color(1.0, 0.5, 0.0), 3, 25.0, 0.3)
		MusicData.ModifierEffect.ECHO:
			# 回响：淡影
			var ghost := _create_polygon(pos, 15.0, 6, Color(0.5, 0.5, 1.0, 0.3))
			var tween := ghost.create_tween()
			tween.tween_property(ghost, "scale", Vector2(2.0, 2.0), 0.5)
			tween.tween_property(ghost, "modulate:a", 0.0, 0.5)
			tween.tween_callback(ghost.queue_free)
		MusicData.ModifierEffect.SCATTER:
			# 散射：放射粒子
			_spawn_radial_particles(pos, Color(1.0, 1.0, 0.0), 8, 35.0, 0.3)

func _spawn_modifier_ready_indicator(pos: Vector2, modifier: MusicData.ModifierEffect) -> void:
	var color := Color.WHITE
	match modifier:
		MusicData.ModifierEffect.PIERCE: color = Color(0.8, 0.8, 0.8)
		MusicData.ModifierEffect.HOMING: color = Color(0.0, 1.0, 0.5)
		MusicData.ModifierEffect.SPLIT: color = Color(1.0, 0.5, 0.0)
		MusicData.ModifierEffect.ECHO: color = Color(0.5, 0.5, 1.0)
		MusicData.ModifierEffect.SCATTER: color = Color(1.0, 1.0, 0.0)
	
	# 修饰符就绪指示器
	var indicator := _create_polygon(pos + Vector2(0, -25), 5.0, 4, color)
	var tween := indicator.create_tween()
	tween.tween_property(indicator, "position",
		indicator.position + Vector2(0, -10), 0.3)
	tween.parallel().tween_property(indicator, "modulate:a", 0.0, 0.5)
	tween.tween_callback(indicator.queue_free)

func _spawn_crit_flash(pos: Vector2) -> void:
	var flash := _create_polygon(pos, 25.0, 4, Color(1.0, 0.0, 0.0, 0.6))
	flash.rotation = PI / 4.0
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.1)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)
	
	_spawn_floating_text(pos + Vector2(0, -20), "暴击!", Color(1.0, 0.3, 0.0))

# ============================================================
# 效果更新
# ============================================================

func _update_effects(delta: float) -> void:
	var expired: Array[int] = []
	
	for i in range(_active_effects.size()):
		var effect := _active_effects[i]
		effect["time_alive"] += delta
		
		if effect["time_alive"] >= effect["duration"]:
			expired.append(i)
			continue
		
		# 旋转效果
		if effect.has("rotation_speed"):
			for node in effect.get("nodes", []):
				if is_instance_valid(node):
					node.rotation += effect["rotation_speed"] * delta
		
		# 淡出（最后1秒）
		var remaining := effect["duration"] - effect["time_alive"]
		if remaining < 1.0:
			var alpha := remaining
			for node in effect.get("nodes", []):
				if is_instance_valid(node):
					node.modulate.a = alpha
		
		# 圣光领域粒子生成
		if effect["type"] == "holy":
			effect["particle_timer"] = effect.get("particle_timer", 0.0) + delta
			if effect["particle_timer"] >= effect.get("particle_interval", 0.3):
				effect["particle_timer"] = 0.0
				var epos: Vector2 = effect.get("position", Vector2.ZERO)
				var ecolor: Color = effect.get("color", Color.WHITE)
				var particle := _create_polygon(
					epos + Vector2(randf_range(-50, 50), 0),
					3.0, 4, ecolor
				)
				var tween := particle.create_tween()
				tween.set_parallel(true)
				tween.tween_property(particle, "position",
					particle.position + Vector2(0, -60), 1.0)
				tween.tween_property(particle, "modulate:a", 0.0, 1.0)
				tween.chain()
				tween.tween_callback(particle.queue_free)
	
	# 清理过期效果
	for i in range(expired.size() - 1, -1, -1):
		var effect := _active_effects[expired[i]]
		for node in effect.get("nodes", []):
			if is_instance_valid(node):
				node.queue_free()
		_active_effects.remove_at(expired[i])

func _cleanup_expired() -> void:
	var to_remove: Array[int] = []
	for i in range(_active_effects.size()):
		var effect := _active_effects[i]
		var all_invalid := true
		for node in effect.get("nodes", []):
			if is_instance_valid(node):
				all_invalid = false
				break
		if all_invalid:
			to_remove.append(i)
	
	for i in range(to_remove.size() - 1, -1, -1):
		_active_effects.remove_at(to_remove[i])

# ============================================================
# 工具函数
# ============================================================

func _create_ring(pos: Vector2, radius: float, color: Color, alpha: float = 0.5) -> Polygon2D:
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	var segments := 32
	for i in range(segments):
		var angle := (TAU / segments) * i
		points.append(Vector2.from_angle(angle) * radius)
	ring.polygon = points
	ring.color = Color(color.r, color.g, color.b, alpha)
	ring.global_position = pos
	add_child(ring)
	return ring

func _create_polygon(pos: Vector2, size: float, vertex_count: int, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(vertex_count):
		var angle := (TAU / vertex_count) * i - PI / 2.0
		points.append(Vector2.from_angle(angle) * size)
	poly.polygon = points
	poly.color = color
	poly.global_position = pos
	add_child(poly)
	return poly

func _spawn_radial_particles(pos: Vector2, color: Color, count: int, distance: float, duration: float) -> void:
	for i in range(count):
		var angle := (TAU / count) * i + randf() * 0.2
		var particle := _create_polygon(pos, 3.0, 4, color)
		var target := pos + Vector2.from_angle(angle) * distance
		var tween := particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", target, duration)
		tween.tween_property(particle, "modulate:a", 0.0, duration * 1.2)
		tween.tween_property(particle, "scale", Vector2(0.3, 0.3), duration)
		tween.chain()
		tween.tween_callback(particle.queue_free)

func _spawn_floating_text(pos: Vector2, text: String, color: Color) -> void:
	if text.is_empty():
		return
	
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = pos - Vector2(50, 10)
	label.size = Vector2(100, 20)
	label.z_index = 50
	add_child(label)
	
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -30), 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.chain()
	tween.tween_callback(label.queue_free)

func _get_spell_form_color(spell_form) -> Color:
	match spell_form:
		MusicData.SpellForm.ENHANCED_PROJECTILE: return Color(1.0, 0.9, 0.3)
		MusicData.SpellForm.DOT_PROJECTILE: return Color(0.4, 0.0, 0.8)
		MusicData.SpellForm.EXPLOSIVE: return Color(1.0, 0.5, 0.0)
		MusicData.SpellForm.SHOCKWAVE: return Color(0.8, 0.0, 0.2)
		MusicData.SpellForm.FIELD: return Color(0.0, 0.6, 1.0)
		MusicData.SpellForm.DIVINE_STRIKE: return Color(1.0, 0.2, 0.2)
		MusicData.SpellForm.SHIELD_HEAL: return Color(0.2, 1.0, 0.4)
		MusicData.SpellForm.SUMMON: return Color(0.3, 0.3, 0.8)
		MusicData.SpellForm.CHARGED: return Color(1.0, 1.0, 0.0)
		MusicData.SpellForm.STORM_FIELD: return Color(0.3, 0.8, 1.0)
		MusicData.SpellForm.HOLY_DOMAIN: return Color(1.0, 0.95, 0.6)
		MusicData.SpellForm.ANNIHILATION_RAY: return Color(0.8, 0.0, 0.8)
		MusicData.SpellForm.TIME_RIFT: return Color(0.5, 0.0, 1.0)
		MusicData.SpellForm.SYMPHONY_STORM: return Color(1.0, 0.6, 0.0)
		MusicData.SpellForm.FINALE: return Color(1.0, 0.0, 0.0)
		_: return Color(0.0, 1.0, 0.8)

func _get_player_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.global_position
	return Vector2.ZERO

func _get_aim_direction() -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return (get_global_mouse_position() - player.global_position).normalized()
	return Vector2.RIGHT

## 清除所有视觉效果
func clear_all() -> void:
	for effect in _active_effects:
		for node in effect.get("nodes", []):
			if is_instance_valid(node):
				node.queue_free()
	_active_effects.clear()
