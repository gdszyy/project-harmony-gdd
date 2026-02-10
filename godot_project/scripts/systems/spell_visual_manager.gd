## spell_visual_manager.gd
## 法术视觉效果管理器 v2.0 — 基于《法术系统视觉增强设计文档》全面重构
## 为所有法术形态提供独特的视觉表现，与 ProjectileManager 的数据层分离。
## ProjectileManager 负责弹体逻辑（碰撞、伤害），本管理器负责纯视觉效果。
##
## 视觉效果七大层级：
## 1. 一次性修饰层（黑键修饰符）— 弹体附着特效 + 施法反馈 + 法术槽UI反馈
## 2. 法术形态层（和弦法术）— 9种基础 + 6种扩展和弦法术的完整VFX
## 3. 攻击质感层（音色系别）— 弹拨/拉弦/吹奏/打击系弹体修饰
## 4. 行为模式层（节奏型）— 连射/重击/闪避/摇摆/三连/蓄力视觉
## 5. 组合效果层（和弦进行）— 全屏特效 + 音色×和弦交互
## 6. 环境与惩罚层 — 单调寂静/噪音过载/不和谐腐蚀
## 7. 频谱相位层（共鸣切片）— 高通/低通/全频全局视觉切换
extends Node2D

# ============================================================
# 信号
# ============================================================
signal visual_effect_spawned(effect_type: String, position: Vector2)

# ============================================================
# 配置
# ============================================================
const MAX_VISUAL_EFFECTS: int = 300
const CLEANUP_INTERVAL: float = 1.0

## 修饰符颜色映射（层级一）
const MODIFIER_COLORS: Dictionary = {
	MusicData.ModifierEffect.PIERCE: Color(0.0, 0.9, 0.9),     # 青色激光
	MusicData.ModifierEffect.HOMING: Color(0.2, 0.6, 1.0),     # 蓝色准星
	MusicData.ModifierEffect.SPLIT: Color(1.0, 0.5, 0.0),      # 橙色电弧
	MusicData.ModifierEffect.ECHO: Color(0.5, 0.5, 1.0),       # 淡蓝残影
	MusicData.ModifierEffect.SCATTER: Color(1.0, 1.0, 0.0),    # 黄色扇形
}

## 音色系别颜色映射（层级三）
const TIMBRE_COLORS: Dictionary = {
	MusicData.TimbreType.NONE: Color(0.0, 1.0, 0.8),
	MusicData.TimbreType.PLUCKED: Color(0.85, 0.75, 0.3),   # 金色/水墨
	MusicData.TimbreType.BOWED: Color(0.8, 0.2, 0.3),       # 暗红丝线
	MusicData.TimbreType.WIND: Color(0.6, 0.9, 0.7),        # 半透明气流
	MusicData.TimbreType.PERCUSSIVE: Color(0.9, 0.9, 0.9),  # 坚实白色
}

## 预加载 Shader（审计报告 2.4 修复：激活闲置 Shader）
var _timbre_projectile_shader: Shader = null
var _modifier_vfx_shader: Shader = null
var _scanline_glow_shader: Shader = null

## 和弦进行颜色映射（层级五）
const PROGRESSION_COLORS: Dictionary = {
	"burst_heal_or_damage": Color(1.0, 0.85, 0.2),   # D→T 金色冲击波
	"empower_next": Color(0.85, 0.6, 0.0),            # T→D 琥珀色
	"cooldown_reduction": Color(0.6, 0.2, 1.0),       # PD→D 紫色加速
}

# ============================================================
# 活跃视觉效果
# ============================================================
var _active_effects: Array[Dictionary] = []
var _cleanup_timer: float = 0.0

## 当前频谱相位状态（层级七）
var _current_phase: String = "fundamental"  # "fundamental", "overtone", "sub_bass"

## 当前音色（层级三）
var _current_timbre: MusicData.TimbreType = MusicData.TimbreType.NONE

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 预加载 Shader 资源（审计报告 2.4 修复）
	_timbre_projectile_shader = load("res://shaders/timbre_projectile.gdshader")
	_modifier_vfx_shader = load("res://shaders/modifier_vfx.gdshader")
	_scanline_glow_shader = load("res://shaders/scanline_glow.gdshader")

	# 连接法术系统信号
	SpellcraftSystem.spell_cast.connect(_on_spell_cast)
	SpellcraftSystem.chord_cast.connect(_on_chord_cast)
	SpellcraftSystem.progression_resolved.connect(_on_progression_resolved)
	SpellcraftSystem.modifier_applied.connect(_on_modifier_applied)
	
	# 连接音色系统信号（如果存在）
	if SpellcraftSystem.has_signal("timbre_changed"):
		SpellcraftSystem.timbre_changed.connect(_on_timbre_changed)
	
	# 连接频谱相位信号（如果存在）
	if SpellcraftSystem.has_signal("phase_switched"):
		SpellcraftSystem.phase_switched.connect(_on_phase_switched)
	
	# 连接惩罚信号（如果存在）
	if SpellcraftSystem.has_signal("monotone_silence_triggered"):
		SpellcraftSystem.monotone_silence_triggered.connect(_on_monotone_silence)
	if SpellcraftSystem.has_signal("noise_overload_triggered"):
		SpellcraftSystem.noise_overload_triggered.connect(_on_noise_overload)
	if SpellcraftSystem.has_signal("dissonance_corrosion_triggered"):
		SpellcraftSystem.dissonance_corrosion_triggered.connect(_on_dissonance_corrosion)

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
	var aim_dir := _get_aim_direction()
	
	# 施法光环（含音色修饰）
	_spawn_cast_aura_enhanced(player_pos, spell_data)
	
	# 层级一：修饰符视觉
	var modifier = spell_data.get("modifier", -1)
	if modifier >= 0:
		_spawn_modifier_visual_enhanced(player_pos, aim_dir, modifier, spell_data)
	
		# 层级三：音色系别弹体修饰（集成 timbre_projectile.gdshader）
	var timbre = spell_data.get("timbre", MusicData.TimbreType.NONE)
	if timbre != MusicData.TimbreType.NONE:
		_spawn_timbre_cast_feedback(player_pos, timbre)
		_apply_timbre_shader_to_cast(player_pos, timbre, spell_data)
	
	# 层级四：节奏型施法反馈
	var rhythm = spell_data.get("rhythm_pattern", -1)
	if rhythm >= 0:
		_spawn_rhythm_cast_feedback(player_pos, aim_dir, rhythm, spell_data)
	
	# 暴击视觉
	if spell_data.get("is_crit", false):
		_spawn_crit_flash(player_pos)

func _on_chord_cast(chord_data: Dictionary) -> void:
	var player_pos := _get_player_position()
	var spell_form = chord_data.get("spell_form", -1)
	
	# 和弦施法光环（更华丽）
	_spawn_chord_cast_aura(player_pos, chord_data)
	
	# 层级二：根据法术形态生成对应视觉效果
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
	
	# 层级五：音色×和弦交互特效
	var timbre = chord_data.get("timbre", MusicData.TimbreType.NONE)
	if timbre != MusicData.TimbreType.NONE:
		_spawn_timbre_chord_interaction(player_pos, timbre, spell_form, chord_data)

func _on_progression_resolved(progression: Dictionary) -> void:
	var player_pos := _get_player_position()
	_spawn_progression_resolve_vfx_enhanced(player_pos, progression)

func _on_modifier_applied(modifier: MusicData.ModifierEffect) -> void:
	var player_pos := _get_player_position()
	_spawn_modifier_ready_indicator_enhanced(player_pos, modifier)

func _on_timbre_changed(new_timbre: MusicData.TimbreType) -> void:
	_current_timbre = new_timbre

func _on_phase_switched(phase_name: String) -> void:
	var player_pos := _get_player_position()
	_spawn_phase_switch_vfx(player_pos, phase_name)
	_current_phase = phase_name

func _on_monotone_silence(note_data: Dictionary) -> void:
	var player_pos := _get_player_position()
	_spawn_monotone_silence_vfx(player_pos, note_data)

func _on_noise_overload(overload_data: Dictionary) -> void:
	var player_pos := _get_player_position()
	_spawn_noise_overload_vfx(player_pos, overload_data)

func _on_dissonance_corrosion(corrosion_data: Dictionary) -> void:
	var player_pos := _get_player_position()
	_spawn_dissonance_corrosion_vfx(player_pos, corrosion_data)

# ============================================================
# 层级一：一次性修饰层（黑键修饰符）— 增强版
# ============================================================

## 增强版修饰符视觉：弹体附着特效 + 施法瞬间反馈
func _spawn_modifier_visual_enhanced(pos: Vector2, aim_dir: Vector2, modifier: MusicData.ModifierEffect, _data: Dictionary) -> void:
	var color: Color = MODIFIER_COLORS.get(modifier, Color.WHITE)
	
	match modifier:
		MusicData.ModifierEffect.PIERCE:
			_modifier_vfx_pierce(pos, aim_dir, color)
		MusicData.ModifierEffect.HOMING:
			_modifier_vfx_homing(pos, color)
		MusicData.ModifierEffect.SPLIT:
			_modifier_vfx_split(pos, color)
		MusicData.ModifierEffect.ECHO:
			_modifier_vfx_echo(pos, color)
		MusicData.ModifierEffect.SCATTER:
			_modifier_vfx_scatter(pos, aim_dir, color)

## 穿透 (C#)：锐利的青色激光指示器 + 旋转刀锋光环
func _modifier_vfx_pierce(pos: Vector2, aim_dir: Vector2, color: Color) -> void:
	# 青色激光指示线（前方延伸）
	var laser := Line2D.new()
	laser.width = 2.0
	laser.default_color = Color(color.r, color.g, color.b, 0.8)
	laser.add_point(Vector2.ZERO)
	laser.add_point(aim_dir * 120.0)
	laser.global_position = pos
	add_child(laser)
	
	var laser_tween := laser.create_tween()
	laser_tween.tween_method(func(t: float):
		if is_instance_valid(laser) and laser.get_point_count() > 1:
			laser.set_point_position(1, aim_dir * 120.0 * t)
	, 0.0, 1.0, 0.15)
	laser_tween.tween_property(laser, "modulate:a", 0.0, 0.2)
	laser_tween.tween_callback(laser.queue_free)
	
	# 旋转刀锋光环（4片刀刃）
	for i in range(4):
		var angle := (TAU / 4) * i
		var blade := Line2D.new()
		blade.width = 3.0
		blade.default_color = color
		blade.add_point(Vector2.from_angle(angle) * 15.0)
		blade.add_point(Vector2.from_angle(angle) * 30.0)
		blade.global_position = pos
		add_child(blade)
		
		var b_tween := blade.create_tween()
		b_tween.tween_property(blade, "rotation", TAU, 0.3)
		b_tween.parallel().tween_property(blade, "modulate:a", 0.0, 0.35)
		b_tween.tween_callback(blade.queue_free)
	
	# 玩家核心锐利光刃扩散
	_spawn_radial_particles(pos, color, 6, 40.0, 0.25)
	
	visual_effect_spawned.emit("modifier_pierce", pos)

## 追踪 (D#)：蓝色动态准星 + 数据流连接
func _modifier_vfx_homing(pos: Vector2, color: Color) -> void:
	# 旋转准星环
	var crosshair := _create_ring(pos, 20.0, color, 0.6)
	
	# 十字准星线
	for i in range(4):
		var angle := (PI / 2) * i
		var line := Line2D.new()
		line.width = 1.5
		line.default_color = Color(color.r, color.g, color.b, 0.7)
		line.add_point(Vector2.from_angle(angle) * 12.0)
		line.add_point(Vector2.from_angle(angle) * 25.0)
		line.global_position = pos
		add_child(line)
		
		var l_tween := line.create_tween()
		l_tween.tween_property(line, "rotation", TAU * 0.5, 0.4)
		l_tween.parallel().tween_property(line, "modulate:a", 0.0, 0.5)
		l_tween.tween_callback(line.queue_free)
	
	# 准星旋转并缩小
	var ch_tween := crosshair.create_tween()
	ch_tween.set_parallel(true)
	ch_tween.tween_property(crosshair, "rotation", TAU, 0.4)
	ch_tween.tween_property(crosshair, "scale", Vector2(0.5, 0.5), 0.4)
	ch_tween.tween_property(crosshair, "modulate:a", 0.0, 0.5)
	ch_tween.chain()
	ch_tween.tween_callback(crosshair.queue_free)
	
	# 全息箭头指向最近敌人
	var nearest_enemy := _find_nearest_enemy(pos)
	if nearest_enemy != Vector2.ZERO:
		var arrow_dir := (nearest_enemy - pos).normalized()
		var arrow := Line2D.new()
		arrow.width = 2.0
		arrow.default_color = Color(color.r, color.g, color.b, 0.5)
		arrow.add_point(Vector2.ZERO)
		arrow.add_point(arrow_dir * 50.0)
		arrow.global_position = pos
		add_child(arrow)
		
		var a_tween := arrow.create_tween()
		a_tween.tween_property(arrow, "modulate:a", 0.0, 0.4)
		a_tween.tween_callback(arrow.queue_free)
	
	visual_effect_spawned.emit("modifier_homing", pos)

## 分裂 (F#)：三个不稳定核心 + 电弧跳跃
func _modifier_vfx_split(pos: Vector2, color: Color) -> void:
	# 三个分裂核心
	var cores: Array[Polygon2D] = []
	var core_offsets: Array[Vector2] = [
		Vector2(0, -12),
		Vector2(-10, 8),
		Vector2(10, 8),
	]
	
	for i in range(3):
		var core := _create_polygon(pos + core_offsets[i], 5.0, 6, color)
		cores.append(core)
	
	# 核心间电弧（Line2D）
	for i in range(3):
		var from_offset := core_offsets[i]
		var to_offset := core_offsets[(i + 1) % 3]
		var arc := Line2D.new()
		arc.width = 1.5
		arc.default_color = Color(color.r, color.g, color.b, 0.7)
		# 添加锯齿形电弧点
		var steps := 5
		for j in range(steps + 1):
			var t := float(j) / float(steps)
			var p := from_offset.lerp(to_offset, t)
			if j > 0 and j < steps:
				p += Vector2(randf_range(-4, 4), randf_range(-4, 4))
			arc.add_point(p)
		arc.global_position = pos
		add_child(arc)
		
		var arc_tween := arc.create_tween()
		arc_tween.tween_property(arc, "modulate:a", 0.0, 0.35)
		arc_tween.tween_callback(arc.queue_free)
	
	# 核心分裂动画：先分开再合一
	for i in range(3):
		var core := cores[i]
		var expand_offset := core_offsets[i] * 2.5
		var c_tween := core.create_tween()
		c_tween.tween_property(core, "global_position", pos + expand_offset, 0.15)
		c_tween.tween_property(core, "global_position", pos, 0.15)
		c_tween.tween_property(core, "modulate:a", 0.0, 0.1)
		c_tween.tween_callback(core.queue_free)
	
	visual_effect_spawned.emit("modifier_split", pos)

## 回响 (G#)：主发光 + 延迟回声发光 + 残影拖尾
func _modifier_vfx_echo(pos: Vector2, color: Color) -> void:
	# 主发光环
	var main_ring := _create_ring(pos, 8.0, color, 0.7)
	var main_tween := main_ring.create_tween()
	main_tween.set_parallel(true)
	main_tween.tween_property(main_ring, "scale", Vector2(5.0, 5.0), 0.2)
	main_tween.tween_property(main_ring, "modulate:a", 0.0, 0.3)
	main_tween.chain()
	main_tween.tween_callback(main_ring.queue_free)
	
	# 延迟0.2秒的回声发光（较弱）
	get_tree().create_timer(0.2).timeout.connect(func():
		var echo_ring := _create_ring(pos, 8.0, color.darkened(0.2), 0.4)
		var echo_tween := echo_ring.create_tween()
		echo_tween.set_parallel(true)
		echo_tween.tween_property(echo_ring, "scale", Vector2(4.0, 4.0), 0.25)
		echo_tween.tween_property(echo_ring, "modulate:a", 0.0, 0.35)
		echo_tween.chain()
		echo_tween.tween_callback(echo_ring.queue_free)
	)
	
	# 残影效果（3个逐渐消失的半透明副本）
	for i in range(3):
		var ghost_offset := Vector2(-10.0 * (i + 1), 0)
		var ghost := _create_polygon(pos + ghost_offset, 12.0 - i * 2.0, 6,
			Color(color.r, color.g, color.b, 0.3 - i * 0.08))
		var g_tween := ghost.create_tween()
		g_tween.tween_property(ghost, "modulate:a", 0.0, 0.4 + i * 0.1)
		g_tween.tween_callback(ghost.queue_free)
	
	visual_effect_spawned.emit("modifier_echo", pos)

## 散射 (A#)：扇形弹道预示 + 虚拟光线
func _modifier_vfx_scatter(pos: Vector2, aim_dir: Vector2, color: Color) -> void:
	# 扇形弹道范围（前方 ±25度，5条光线）
	var spread_angle := deg_to_rad(25.0)
	var ray_count := 5
	
	for i in range(ray_count):
		var t := float(i) / float(ray_count - 1) - 0.5  # -0.5 to 0.5
		var angle_offset := t * spread_angle * 2.0
		var ray_dir := aim_dir.rotated(angle_offset)
		
		var ray := Line2D.new()
		ray.width = 1.5 if i != ray_count / 2 else 2.5  # 中间线更粗
		ray.default_color = Color(color.r, color.g, color.b, 0.4 if i != ray_count / 2 else 0.7)
		ray.add_point(Vector2.ZERO)
		ray.add_point(ray_dir * 80.0)
		ray.global_position = pos
		add_child(ray)
		
		var r_tween := ray.create_tween()
		r_tween.tween_method(func(val: float):
			if is_instance_valid(ray) and ray.get_point_count() > 1:
				ray.set_point_position(1, ray_dir * 80.0 * val)
		, 0.0, 1.0, 0.15)
		r_tween.tween_property(ray, "modulate:a", 0.0, 0.25)
		r_tween.tween_callback(ray.queue_free)
	
	# 扇形弧线
	var arc := Line2D.new()
	arc.width = 2.0
	arc.default_color = Color(color.r, color.g, color.b, 0.5)
	var arc_segments := 12
	for i in range(arc_segments + 1):
		var t := float(i) / float(arc_segments) - 0.5
		var angle_offset := t * spread_angle * 2.0
		var point := aim_dir.rotated(angle_offset) * 60.0
		arc.add_point(point)
	arc.global_position = pos
	add_child(arc)
	
	var arc_tween := arc.create_tween()
	arc_tween.tween_property(arc, "modulate:a", 0.0, 0.35)
	arc_tween.tween_callback(arc.queue_free)
	
	visual_effect_spawned.emit("modifier_scatter", pos)

## 增强版修饰符就绪指示器
func _spawn_modifier_ready_indicator_enhanced(pos: Vector2, modifier: MusicData.ModifierEffect) -> void:
	var color: Color = MODIFIER_COLORS.get(modifier, Color.WHITE)
	var mod_name := ""
	
	match modifier:
		MusicData.ModifierEffect.PIERCE: mod_name = "穿透"
		MusicData.ModifierEffect.HOMING: mod_name = "追踪"
		MusicData.ModifierEffect.SPLIT: mod_name = "分裂"
		MusicData.ModifierEffect.ECHO: mod_name = "回响"
		MusicData.ModifierEffect.SCATTER: mod_name = "散射"
	
	# 修饰符就绪光环
	var indicator := _create_ring(pos, 15.0, color, 0.5)
	var tween := indicator.create_tween()
	tween.set_parallel(true)
	tween.tween_property(indicator, "scale", Vector2(2.0, 2.0), 0.3)
	tween.tween_property(indicator, "modulate:a", 0.0, 0.5)
	tween.chain()
	tween.tween_callback(indicator.queue_free)
	
	# 修饰符名称浮动
	_spawn_floating_text(pos + Vector2(0, -30), mod_name + " 就绪", color)

# ============================================================
# 施法光环（全局优化：施法前摇与手感）
# ============================================================

## 增强版施法光环：含音色修饰和节拍弹跳
func _spawn_cast_aura_enhanced(pos: Vector2, spell_data: Dictionary) -> void:
	var color: Color = spell_data.get("color", Color(0.0, 1.0, 0.8))
	var timbre = spell_data.get("timbre", MusicData.TimbreType.NONE)
	
	# 基础施法脉冲环
	var ring := _create_ring(pos, 5.0, color, 0.4)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(8.0, 8.0), 0.2)
	tween.tween_property(ring, "modulate:a", 0.0, 0.25)
	tween.chain()
	tween.tween_callback(ring.queue_free)
	
	# 音色修饰叠加
	if timbre != MusicData.TimbreType.NONE:
		var timbre_color: Color = TIMBRE_COLORS.get(timbre, Color.WHITE)
		match timbre:
			MusicData.TimbreType.PLUCKED:
				# 弹拨系：水墨波纹同心圆
				var ink_ring := _create_ring(pos, 8.0, timbre_color, 0.3)
				var ink_tween := ink_ring.create_tween()
				ink_tween.set_parallel(true)
				ink_tween.tween_property(ink_ring, "scale", Vector2(6.0, 6.0), 0.15)
				ink_tween.tween_property(ink_ring, "modulate:a", 0.0, 0.2)
				ink_tween.chain()
				ink_tween.tween_callback(ink_ring.queue_free)
			MusicData.TimbreType.BOWED:
				# 拉弦系：两条交织光弦
				for i in range(2):
					var strand := Line2D.new()
					strand.width = 1.5
					strand.default_color = timbre_color
					var offset := 5.0 if i == 0 else -5.0
					strand.add_point(Vector2(-20, offset))
					strand.add_point(Vector2(0, -offset))
					strand.add_point(Vector2(20, offset))
					strand.global_position = pos
					add_child(strand)
					var s_tween := strand.create_tween()
					s_tween.tween_property(strand, "modulate:a", 0.0, 0.3)
					s_tween.tween_callback(strand.queue_free)
			MusicData.TimbreType.WIND:
				# 吹奏系：气流扩散
				_spawn_radial_particles(pos, timbre_color, 4, 25.0, 0.2)
			MusicData.TimbreType.PERCUSSIVE:
				# 打击系：方形脉冲
				var pulse := _create_polygon(pos, 10.0, 4, Color(timbre_color.r, timbre_color.g, timbre_color.b, 0.4))
				var p_tween := pulse.create_tween()
				p_tween.tween_property(pulse, "scale", Vector2(3.0, 3.0), 0.1)
				p_tween.tween_property(pulse, "modulate:a", 0.0, 0.15)
				p_tween.tween_callback(pulse.queue_free)

func _spawn_chord_cast_aura(pos: Vector2, chord_data: Dictionary) -> void:
	var spell_form = chord_data.get("spell_form", -1)
	var color := _get_spell_form_color(spell_form)
	
	# 三层光环（外→内）
	var outer := _create_ring(pos, 5.0, color, 0.3)
	var mid := _create_ring(pos, 4.0, color.lightened(0.2), 0.4)
	var inner := _create_ring(pos, 3.0, color.lightened(0.4), 0.6)
	
	var tween := outer.create_tween()
	tween.set_parallel(true)
	tween.tween_property(outer, "scale", Vector2(14.0, 14.0), 0.35)
	tween.tween_property(outer, "modulate:a", 0.0, 0.4)
	tween.chain()
	tween.tween_callback(outer.queue_free)
	
	var tween2 := mid.create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(mid, "scale", Vector2(10.0, 10.0), 0.25)
	tween2.tween_property(mid, "modulate:a", 0.0, 0.35)
	tween2.chain()
	tween2.tween_callback(mid.queue_free)
	
	var tween3 := inner.create_tween()
	tween3.set_parallel(true)
	tween3.tween_property(inner, "scale", Vector2(8.0, 8.0), 0.2)
	tween3.tween_property(inner, "modulate:a", 0.0, 0.3)
	tween3.chain()
	tween3.tween_callback(inner.queue_free)
	
	# 法术名称浮动文字
	_spawn_floating_text(pos + Vector2(0, -30), chord_data.get("spell_name", ""), color)

# ============================================================
# 层级二：法术形态层（和弦法术）— 增强版
# ============================================================

## 强化弹体（大三）：圣光金 + 六边形能量网格 + 行星光球
func _vfx_enhanced_projectile(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(1.0, 0.9, 0.3)  # 圣光金
	
	# 金色光芒爆发
	_spawn_radial_particles(pos, color, 10, 35.0, 0.3)
	
	# 六边形能量网格闪光
	var hex := _create_polygon(pos, 20.0, 6, Color(color.r, color.g, color.b, 0.4))
	var hex_tween := hex.create_tween()
	hex_tween.set_parallel(true)
	hex_tween.tween_property(hex, "scale", Vector2(2.5, 2.5), 0.2)
	hex_tween.tween_property(hex, "rotation", PI / 6.0, 0.2)
	hex_tween.tween_property(hex, "modulate:a", 0.0, 0.3)
	hex_tween.chain()
	hex_tween.tween_callback(hex.queue_free)
	
	# 环绕行星光球
	for i in range(4):
		var angle := (TAU / 4) * i
		var orbit_pos := pos + Vector2.from_angle(angle) * 25.0
		var orb := _create_polygon(orbit_pos, 3.0, 8, Color(1.0, 0.95, 0.5, 0.8))
		var orb_tween := orb.create_tween()
		orb_tween.tween_property(orb, "global_position",
			pos + Vector2.from_angle(angle + PI) * 35.0, 0.3)
		orb_tween.parallel().tween_property(orb, "modulate:a", 0.0, 0.35)
		orb_tween.tween_callback(orb.queue_free)
	
	visual_effect_spawned.emit("enhanced_projectile", pos)

## DOT弹体（小三）：暗蓝色粘稠液体 + 漩涡 + 腐蚀滴落
func _vfx_dot_projectile(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(0.15, 0.1, 0.6, 0.7)  # 暗蓝色
	
	# 粘稠液体云
	for i in range(6):
		var offset := Vector2(randf_range(-20, 20), randf_range(-20, 20))
		var cloud := _create_polygon(pos + offset, 8.0, 6, color)
		var tween := cloud.create_tween()
		tween.set_parallel(true)
		tween.tween_property(cloud, "scale", Vector2(3.0, 3.0), 0.5)
		tween.tween_property(cloud, "modulate:a", 0.0, 0.6)
		tween.tween_property(cloud, "position", cloud.position + offset * 2, 0.6)
		tween.tween_property(cloud, "rotation", TAU * 0.5, 0.6)  # 漩涡旋转
		tween.chain()
		tween.tween_callback(cloud.queue_free)
	
	# 中心漩涡
	var vortex := _create_ring(pos, 12.0, color, 0.5)
	var v_tween := vortex.create_tween()
	v_tween.set_parallel(true)
	v_tween.tween_property(vortex, "rotation", TAU, 0.5)
	v_tween.tween_property(vortex, "scale", Vector2(2.0, 2.0), 0.5)
	v_tween.tween_property(vortex, "modulate:a", 0.0, 0.6)
	v_tween.chain()
	v_tween.tween_callback(vortex.queue_free)
	
	# 滴落粒子
	for i in range(4):
		get_tree().create_timer(i * 0.1).timeout.connect(func():
			var drop := _create_polygon(
				pos + Vector2(randf_range(-15, 15), 0), 3.0, 4, color)
			var d_tween := drop.create_tween()
			d_tween.tween_property(drop, "position",
				drop.position + Vector2(0, 30), 0.4)
			d_tween.parallel().tween_property(drop, "modulate:a", 0.0, 0.4)
			d_tween.parallel().tween_property(drop, "scale", Vector2(0.3, 0.3), 0.4)
			d_tween.tween_callback(drop.queue_free)
		)
	
	visual_effect_spawned.emit("dot_projectile", pos)

## 爆炸弹体（增三）：烈焰橙 + 不稳定核心 + 火星迸发
func _vfx_explosive(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(1.0, 0.5, 0.0)  # 烈焰橙
	
	# 内核白色闪光
	var flash := _create_polygon(pos, 18.0, 8, Color.WHITE)
	var f_tween := flash.create_tween()
	f_tween.tween_property(flash, "scale", Vector2(3.5, 3.5), 0.08)
	f_tween.tween_property(flash, "modulate:a", 0.0, 0.12)
	f_tween.tween_callback(flash.queue_free)
	
	# 火焰粒子爆发（更多、更远）
	_spawn_radial_particles(pos, color, 16, 55.0, 0.4)
	
	# 第二波暖色粒子
	get_tree().create_timer(0.05).timeout.connect(func():
		_spawn_radial_particles(pos, Color(1.0, 0.3, 0.0), 8, 40.0, 0.35)
	)
	
	# 不稳定核心脉冲
	var core := _create_polygon(pos, 10.0, 8, Color(1.0, 0.7, 0.2, 0.6))
	var c_tween := core.create_tween()
	c_tween.tween_property(core, "scale", Vector2(2.0, 2.0), 0.1)
	c_tween.tween_property(core, "scale", Vector2(1.5, 1.5), 0.05)
	c_tween.tween_property(core, "scale", Vector2(2.5, 2.5), 0.08)
	c_tween.tween_property(core, "modulate:a", 0.0, 0.15)
	c_tween.tween_callback(core.queue_free)
	
	visual_effect_spawned.emit("explosive", pos)

## 冲击波（减三）：深紫色环形 + 空间涟漪 + 内爆
func _vfx_shockwave(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(0.5, 0.0, 0.5)  # 深紫色
	
	# 多层冲击波环（波前锋利）
	for i in range(3):
		var delay := i * 0.06
		get_tree().create_timer(delay).timeout.connect(func():
			var ring := _create_ring(pos, 5.0, color.lightened(i * 0.15), 0.7 - i * 0.15)
			var tween := ring.create_tween()
			tween.set_parallel(true)
			tween.tween_property(ring, "scale", Vector2(35.0, 35.0), 0.45)
			tween.tween_property(ring, "modulate:a", 0.0, 0.55)
			tween.chain()
			tween.tween_callback(ring.queue_free)
		)
	
	# 地面切割裂纹
	for i in range(8):
		var angle := (TAU / 8) * i + randf() * 0.2
		var crack := Line2D.new()
		crack.width = 2.5
		crack.default_color = color
		crack.add_point(Vector2.ZERO)
		crack.add_point(Vector2.from_angle(angle) * 5.0)
		crack.global_position = pos
		add_child(crack)
		
		var tween := crack.create_tween()
		tween.tween_method(func(t: float):
			if is_instance_valid(crack) and crack.get_point_count() > 1:
				crack.set_point_position(1, Vector2.from_angle(angle) * t * 90.0)
		, 0.0, 1.0, 0.25)
		tween.tween_property(crack, "modulate:a", 0.0, 0.3)
		tween.tween_callback(crack.queue_free)
	
	# 内爆效果（延迟后向中心收缩）
	get_tree().create_timer(0.5).timeout.connect(func():
		var implode := _create_ring(pos, 80.0, Color(color.r, color.g, color.b, 0.4), 0.4)
		var imp_tween := implode.create_tween()
		imp_tween.set_parallel(true)
		imp_tween.tween_property(implode, "scale", Vector2(0.1, 0.1), 0.2)
		imp_tween.tween_property(implode, "modulate:a", 0.8, 0.1)
		imp_tween.chain()
		imp_tween.tween_property(implode, "modulate:a", 0.0, 0.15)
		imp_tween.tween_callback(implode.queue_free)
		
		# 内爆闪光
		var imp_flash := _create_polygon(pos, 5.0, 8, Color.WHITE)
		var if_tween := imp_flash.create_tween()
		if_tween.tween_property(imp_flash, "scale", Vector2(4.0, 4.0), 0.1)
		if_tween.tween_property(imp_flash, "modulate:a", 0.0, 0.15)
		if_tween.tween_callback(imp_flash.queue_free)
	)
	
	visual_effect_spawned.emit("shockwave", pos)

## 法阵/区域（属七）：Dominant黄旋转几何法阵 + 光柱印记
func _vfx_field(pos: Vector2, _data: Dictionary) -> void:
	var aim_dir := _get_aim_direction()
	var target_pos := pos + aim_dir * 200.0
	var color := Color(0.9, 0.8, 0.0)  # Dominant黄
	
	# 从天而降的光柱印记
	var pillar := Line2D.new()
	pillar.width = 30.0
	pillar.default_color = Color(color.r, color.g, color.b, 0.3)
	pillar.add_point(Vector2(0, -400))
	pillar.add_point(Vector2(0, 0))
	pillar.global_position = target_pos
	add_child(pillar)
	
	var p_tween := pillar.create_tween()
	p_tween.tween_property(pillar, "modulate:a", 1.0, 0.1)
	p_tween.tween_property(pillar, "modulate:a", 0.0, 0.3)
	p_tween.tween_callback(pillar.queue_free)
	
	# 法阵外环（六芒星）
	var outer := _create_polygon(target_pos, 65.0, 6, Color(color.r, color.g, color.b, 0.2))
	
	# 法阵内环
	var inner := _create_polygon(target_pos, 45.0, 6, Color(color.r, color.g, color.b, 0.15))
	inner.rotation = PI / 6.0  # 旋转30度形成六芒星
	
	# 法阵边框环
	var border := _create_ring(target_pos, 60.0, color, 0.3)
	
	# 上升能量粒子
	_active_effects.append({
		"nodes": [outer, inner, border],
		"type": "field",
		"duration": 4.0,
		"time_alive": 0.0,
		"rotation_speed": 1.5,
		"position": target_pos,
		"particle_timer": 0.0,
		"particle_interval": 0.2,
		"color": color,
	})
	
	visual_effect_spawned.emit("field", target_pos)

## 天降打击（减七）：血红色预警 + 乌云闪电 + 全屏闪白
func _vfx_divine_strike(pos: Vector2, _data: Dictionary) -> void:
	var aim_dir := _get_aim_direction()
	var target_pos := pos + aim_dir * 300.0
	var color := Color(0.8, 0.0, 0.0)  # 血红色
	
	# 收缩预警圆
	var warning := _create_ring(target_pos, 80.0, Color(1.0, 0.0, 0.0, 0.3), 0.3)
	var warn_tween := warning.create_tween()
	warn_tween.tween_property(warning, "scale", Vector2(0.5, 0.5), 0.5)
	warn_tween.parallel().tween_property(warning, "modulate:a", 0.8, 0.3)
	warn_tween.tween_callback(warning.queue_free)
	
	# 上升吸附粒子（山雨欲来）
	for i in range(8):
		var p_offset := Vector2(randf_range(-40, 40), randf_range(-20, 20))
		var particle := _create_polygon(target_pos + p_offset, 3.0, 4,
			Color(1.0, 0.2, 0.1, 0.6))
		var pt_tween := particle.create_tween()
		pt_tween.tween_property(particle, "position",
			particle.position + Vector2(0, -60), 0.4)
		pt_tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		pt_tween.tween_callback(particle.queue_free)
	
	# 光柱落下（延迟）
	get_tree().create_timer(0.5).timeout.connect(func():
		# 全屏闪白
		var flash := ColorRect.new()
		flash.color = Color(1.0, 1.0, 1.0, 0.5)
		flash.size = Vector2(2000, 2000)
		flash.position = Vector2(-1000, -1000)
		flash.z_index = 100
		add_child(flash)
		var fl_tween := flash.create_tween()
		fl_tween.tween_property(flash, "color:a", 0.0, 0.15)
		fl_tween.tween_callback(flash.queue_free)
		
		# 垂直光柱
		var strike := Line2D.new()
		strike.width = 25.0
		strike.default_color = Color(1.0, 0.2, 0.1, 0.9)
		strike.add_point(Vector2(0, -600))
		strike.add_point(Vector2(0, 0))
		strike.global_position = target_pos
		add_child(strike)
		
		var s_tween := strike.create_tween()
		s_tween.tween_property(strike, "width", 50.0, 0.08)
		s_tween.tween_property(strike, "width", 3.0, 0.25)
		s_tween.tween_property(strike, "modulate:a", 0.0, 0.2)
		s_tween.tween_callback(strike.queue_free)
		
		# 落地冲击波
		var impact := _create_ring(target_pos, 5.0, Color.WHITE, 0.9)
		var imp_tween := impact.create_tween()
		imp_tween.set_parallel(true)
		imp_tween.tween_property(impact, "scale", Vector2(25.0, 25.0), 0.3)
		imp_tween.tween_property(impact, "modulate:a", 0.0, 0.4)
		imp_tween.chain()
		imp_tween.tween_callback(impact.queue_free)
		
		# 碎石飞溅
		_spawn_radial_particles(target_pos, color, 20, 70.0, 0.5)
	)
	
	visual_effect_spawned.emit("divine_strike", target_pos)

## 护盾/治疗（大七）：治愈绿半球护盾 + 蜂巢能量格 + 汇聚光点
func _vfx_shield_heal(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(0.2, 0.9, 0.4)  # 治愈绿
	
	# 半透明护盾（六角形模拟半球）
	var shield := _create_polygon(pos, 55.0, 6, Color(color.r, color.g, color.b, 0.12))
	
	# 护盾边框（蜂巢纹理用多层六角模拟）
	var border := _create_ring(pos, 55.0, color, 0.4)
	var inner_hex := _create_polygon(pos, 35.0, 6, Color(color.r, color.g, color.b, 0.08))
	inner_hex.rotation = PI / 6.0
	
	# 四面八方汇聚的绿色光点
	for i in range(12):
		var angle := (TAU / 12) * i
		var start := pos + Vector2.from_angle(angle) * 100.0
		var particle := _create_polygon(start, 3.0, 4, Color(0.3, 1.0, 0.5, 0.7))
		var p_tween := particle.create_tween()
		p_tween.tween_property(particle, "global_position", pos, 0.5)
		p_tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.6)
		p_tween.tween_callback(particle.queue_free)
	
	# 治疗粒子上升
	_active_effects.append({
		"nodes": [shield, border, inner_hex],
		"type": "shield",
		"duration": 4.0,
		"time_alive": 0.0,
		"position": pos,
		"particle_timer": 0.0,
		"particle_interval": 0.25,
		"color": color,
	})
	
	visual_effect_spawned.emit("shield_heal", pos)

## 召唤/构造（小七）：深蓝色水晶生长 + 模块化拼接
func _vfx_summon(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(0.15, 0.15, 0.7)  # 深蓝色
	var summon_pos := pos + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	
	# 地面召唤阵
	var circle := _create_ring(summon_pos, 35.0, color, 0.5)
	var c_tween := circle.create_tween()
	c_tween.tween_property(circle, "rotation", TAU, 1.0)
	c_tween.parallel().tween_property(circle, "modulate:a", 0.0, 1.2)
	c_tween.tween_callback(circle.queue_free)
	
	# 模块化拼接动画（方块从下方生长）
	for i in range(5):
		var block_offset := Vector2(randf_range(-20, 20), 30 - i * 12)
		var block := _create_polygon(summon_pos + Vector2(block_offset.x, 30), 
			8.0 - i * 0.5, 4, Color(color.r, color.g + i * 0.05, color.b, 0.6))
		
		get_tree().create_timer(i * 0.1).timeout.connect(func():
			if is_instance_valid(block):
				var b_tween := block.create_tween()
				b_tween.tween_property(block, "global_position",
					summon_pos + block_offset, 0.2)
				b_tween.tween_property(block, "modulate:a", 0.0, 0.8)
				b_tween.tween_callback(block.queue_free)
		)
	
	# 凝聚粒子（从外向内）
	for i in range(12):
		var angle := (TAU / 12) * i
		var start := summon_pos + Vector2.from_angle(angle) * 60.0
		var particle := _create_polygon(start, 3.0, 4, color.lightened(0.3))
		var p_tween := particle.create_tween()
		p_tween.tween_property(particle, "global_position", summon_pos, 0.5)
		p_tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.6)
		p_tween.tween_callback(particle.queue_free)
	
	# 核心脉冲光
	_active_effects.append({
		"nodes": [],
		"type": "summon_pulse",
		"duration": 3.0,
		"time_alive": 0.0,
		"position": summon_pos,
		"particle_timer": 0.0,
		"particle_interval": 0.5,
		"color": color,
	})
	
	visual_effect_spawned.emit("summon", summon_pos)

## 蓄力弹体（挂留）：银白色能量球 + 空间扭曲 + 彗星尾迹
func _vfx_charged(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(0.9, 0.9, 1.0)  # 银白色
	
	# 能量球（逐渐变大变亮）
	var orb := _create_polygon(pos, 8.0, 12, Color(color.r, color.g, color.b, 0.5))
	
	# 能量线被吸入球体
	for i in range(10):
		var angle := (TAU / 10) * i
		var start := pos + Vector2.from_angle(angle) * 50.0
		var line := Line2D.new()
		line.width = 1.0
		line.default_color = Color(color.r, color.g, color.b, 0.4)
		line.add_point(start - pos)
		line.add_point(Vector2.ZERO)
		line.global_position = pos
		add_child(line)
		
		get_tree().create_timer(i * 0.08).timeout.connect(func():
			if is_instance_valid(line):
				var l_tween := line.create_tween()
				l_tween.tween_property(line, "modulate:a", 0.0, 0.3)
				l_tween.tween_callback(line.queue_free)
		)
	
	# 蓄力膨胀动画
	var orb_tween := orb.create_tween()
	orb_tween.tween_property(orb, "scale", Vector2(3.0, 3.0), 0.8)
	orb_tween.parallel().tween_property(orb, "modulate:a", 1.0, 0.8)
	
	# 释放闪光
	orb_tween.tween_callback(func():
		if is_instance_valid(orb):
			orb.queue_free()
		var release := _create_polygon(pos, 25.0, 8, Color.WHITE)
		var r_tween := release.create_tween()
		r_tween.tween_property(release, "scale", Vector2(4.0, 4.0), 0.1)
		r_tween.tween_property(release, "modulate:a", 0.0, 0.15)
		r_tween.tween_callback(release.queue_free)
		
		# 后坐力径向模糊效果
		_spawn_radial_particles(pos, color, 8, 50.0, 0.3)
	)
	
	visual_effect_spawned.emit("charged", pos)

# ============================================================
# 扩展和弦法术视觉效果
# ============================================================

## 风暴区域：旋转的蓝色风暴漩涡
func _vfx_storm_field(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(0.3, 0.8, 1.0)
	
	var center := _create_polygon(pos, 10.0, 8, color)
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
	
	var pillar := Line2D.new()
	pillar.width = 40.0
	pillar.default_color = Color(1.0, 0.95, 0.6, 0.15)
	pillar.add_point(Vector2(0, -400))
	pillar.add_point(Vector2(0, 0))
	pillar.global_position = pos
	add_child(pillar)
	
	var aura := _create_ring(pos, 100.0, color, 0.2)
	
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
	
	var ray := Line2D.new()
	ray.width = 8.0
	ray.default_color = color
	ray.add_point(Vector2.ZERO)
	ray.add_point(aim_dir * 800.0)
	ray.global_position = pos
	add_child(ray)
	
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
	
	for i in range(10):
		var t := float(i) / 10.0
		var burn_pos := pos + aim_dir * 800.0 * t
		_spawn_radial_particles(burn_pos, color, 3, 15.0, 0.3)
	
	visual_effect_spawned.emit("annihilation_ray", pos)

## 时空裂隙：紫色扭曲空间
func _vfx_time_rift(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(0.5, 0.0, 1.0)
	
	var rift := _create_polygon(pos, 20.0, 5, Color(0.0, 0.0, 0.0, 0.5))
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
		"rotation_speed": -2.0,
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
	
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.8)
	flash.size = Vector2(2000, 2000)
	flash.position = Vector2(-1000, -1000)
	flash.z_index = 100
	add_child(flash)
	
	var tween := flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.5)
	tween.tween_callback(flash.queue_free)
	
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
# 层级三：攻击质感层（音色系别）
# ============================================================

## 音色施法反馈（叠加在基础施法光环上）
func _spawn_timbre_cast_feedback(pos: Vector2, timbre: MusicData.TimbreType) -> void:
	var color: Color = TIMBRE_COLORS.get(timbre, Color.WHITE)
	
	match timbre:
		MusicData.TimbreType.PLUCKED:
			# 弹拨系：短促有力的同心圆冲击波（墨滴炸开）
			var ink := _create_ring(pos, 5.0, color, 0.6)
			var tween := ink.create_tween()
			tween.set_parallel(true)
			tween.tween_property(ink, "scale", Vector2(6.0, 6.0), 0.12)
			tween.tween_property(ink, "modulate:a", 0.0, 0.18)
			tween.chain()
			tween.tween_callback(ink.queue_free)
		
		MusicData.TimbreType.BOWED:
			# 拉弦系：连绵光轨
			var trail := Line2D.new()
			trail.width = 2.0
			trail.default_color = color
			trail.add_point(Vector2(-30, 0))
			trail.add_point(Vector2(30, 0))
			trail.global_position = pos
			add_child(trail)
			var t_tween := trail.create_tween()
			t_tween.tween_property(trail, "modulate:a", 0.0, 0.5)
			t_tween.tween_callback(trail.queue_free)
		
		MusicData.TimbreType.WIND:
			# 吹奏系：气流轨迹
			var aim_dir := _get_aim_direction()
			var wind := Line2D.new()
			wind.width = 3.0
			wind.default_color = Color(color.r, color.g, color.b, 0.4)
			wind.add_point(Vector2.ZERO)
			wind.add_point(aim_dir * 40.0)
			wind.global_position = pos
			add_child(wind)
			var w_tween := wind.create_tween()
			w_tween.tween_method(func(t: float):
				if is_instance_valid(wind) and wind.get_point_count() > 1:
					wind.set_point_position(1, aim_dir * 40.0 * t)
					wind.width = 3.0 * (1.0 - t * 0.5)
			, 0.0, 1.0, 0.2)
			w_tween.tween_property(wind, "modulate:a", 0.0, 0.15)
			w_tween.tween_callback(wind.queue_free)
		
		MusicData.TimbreType.PERCUSSIVE:
			# 打击系：坚实方形脉冲 + 屏幕微震
			var square := _create_polygon(pos, 12.0, 4, Color(color.r, color.g, color.b, 0.5))
			var sq_tween := square.create_tween()
			sq_tween.tween_property(square, "scale", Vector2(2.5, 2.5), 0.08)
			sq_tween.tween_property(square, "modulate:a", 0.0, 0.12)
			sq_tween.tween_callback(square.queue_free)

## 音色×和弦交互特效（层级五）
func _spawn_timbre_chord_interaction(pos: Vector2, timbre: MusicData.TimbreType, spell_form: int, _data: Dictionary) -> void:
	var timbre_color: Color = TIMBRE_COLORS.get(timbre, Color.WHITE)
	
	match timbre:
		MusicData.TimbreType.PLUCKED:
			# 弹拨×和弦：金色光珠二次爆发
			if spell_form == MusicData.SpellForm.EXPLOSIVE:
				get_tree().create_timer(0.15).timeout.connect(func():
					_spawn_radial_particles(pos, Color(0.85, 0.75, 0.3), 8, 40.0, 0.3)
				)
			else:
				_spawn_radial_particles(pos, timbre_color, 4, 20.0, 0.2)
		
		MusicData.TimbreType.BOWED:
			# 拉弦×和弦：暗红能量丝线缠绕
			for i in range(3):
				var angle := (TAU / 3) * i + randf() * 0.5
				var strand := Line2D.new()
				strand.width = 1.5
				strand.default_color = timbre_color
				var points := 8
				for j in range(points):
					var t := float(j) / float(points - 1)
					var r := 15.0 + t * 25.0
					strand.add_point(Vector2.from_angle(angle + t * PI) * r)
				strand.global_position = pos
				add_child(strand)
				var s_tween := strand.create_tween()
				s_tween.tween_property(strand, "modulate:a", 0.0, 0.5)
				s_tween.tween_callback(strand.queue_free)
		
		MusicData.TimbreType.WIND:
			# 吹奏×和弦：竹叶/风旋粒子
			for i in range(6):
				var leaf := _create_polygon(pos + Vector2(randf_range(-20, 20), randf_range(-20, 20)),
					4.0, 3, timbre_color)
				var l_tween := leaf.create_tween()
				l_tween.set_parallel(true)
				l_tween.tween_property(leaf, "position",
					leaf.position + Vector2(randf_range(-40, 40), randf_range(-40, -20)), 0.5)
				l_tween.tween_property(leaf, "rotation", randf_range(-PI, PI), 0.5)
				l_tween.tween_property(leaf, "modulate:a", 0.0, 0.5)
				l_tween.chain()
				l_tween.tween_callback(leaf.queue_free)
		
		MusicData.TimbreType.PERCUSSIVE:
			# 打击×和弦：物理破碎感
			for i in range(6):
				var shard := _create_polygon(pos, 5.0, 4,
					Color(timbre_color.r, timbre_color.g, timbre_color.b, 0.7))
				shard.rotation = randf() * TAU
				var dir := Vector2.from_angle(randf() * TAU)
				var sh_tween := shard.create_tween()
				sh_tween.set_parallel(true)
				sh_tween.tween_property(shard, "global_position",
					pos + dir * randf_range(20, 50), 0.3)
				sh_tween.tween_property(shard, "rotation",
					shard.rotation + randf_range(-PI, PI), 0.3)
				sh_tween.tween_property(shard, "modulate:a", 0.0, 0.35)
				sh_tween.chain()
				sh_tween.tween_callback(shard.queue_free)

# ============================================================
# 层级四：行为模式层（节奏型）
# ============================================================

## 节奏型施法反馈
func _spawn_rhythm_cast_feedback(pos: Vector2, aim_dir: Vector2, rhythm: int, _data: Dictionary) -> void:
	match rhythm:
		MusicData.RhythmPattern.EVEN_EIGHTH:
			# 连射：快速短促的小型脉冲
			var pulse := _create_polygon(pos, 4.0, 4, Color(0.0, 1.0, 0.8, 0.4))
			var p_tween := pulse.create_tween()
			p_tween.tween_property(pulse, "scale", Vector2(2.0, 2.0), 0.08)
			p_tween.tween_property(pulse, "modulate:a", 0.0, 0.1)
			p_tween.tween_callback(pulse.queue_free)
		
		MusicData.RhythmPattern.DOTTED:
			# 重击：大幅度蓄力后坐动画
			var heavy := _create_polygon(pos, 15.0, 6, Color(1.0, 0.6, 0.2, 0.5))
			var h_tween := heavy.create_tween()
			h_tween.tween_property(heavy, "scale", Vector2(0.5, 0.5), 0.1)  # 蓄力收缩
			h_tween.tween_property(heavy, "scale", Vector2(3.0, 3.0), 0.15)  # 释放膨胀
			h_tween.tween_property(heavy, "modulate:a", 0.0, 0.2)
			h_tween.tween_callback(heavy.queue_free)
		
		MusicData.RhythmPattern.SYNCOPATED:
			# 闪避射击：向后闪现残影
			var ghost := _create_polygon(pos, 12.0, 8, Color(0.5, 0.8, 1.0, 0.3))
			var g_tween := ghost.create_tween()
			g_tween.tween_property(ghost, "global_position",
				pos - aim_dir * 20.0, 0.1)
			g_tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
			g_tween.tween_callback(ghost.queue_free)
		
		MusicData.RhythmPattern.SWING:
			# 摇摆弹道：摇摆动画
			var swing := _create_polygon(pos, 8.0, 6, Color(0.8, 0.5, 1.0, 0.4))
			var sw_tween := swing.create_tween()
			sw_tween.tween_property(swing, "rotation", 0.3, 0.1)
			sw_tween.tween_property(swing, "rotation", -0.3, 0.1)
			sw_tween.tween_property(swing, "rotation", 0.0, 0.1)
			sw_tween.tween_property(swing, "modulate:a", 0.0, 0.1)
			sw_tween.tween_callback(swing.queue_free)
		
		MusicData.RhythmPattern.TRIPLET:
			# 三连发：三方向扇动
			for i in range(3):
				var angle := (deg_to_rad(30.0) * (i - 1))
				var tri_dir := aim_dir.rotated(angle)
				var tri := Line2D.new()
				tri.width = 2.0
				tri.default_color = Color(0.0, 1.0, 0.5, 0.5)
				tri.add_point(Vector2.ZERO)
				tri.add_point(tri_dir * 30.0)
				tri.global_position = pos
				add_child(tri)
				var t_tween := tri.create_tween()
				t_tween.tween_property(tri, "modulate:a", 0.0, 0.2)
				t_tween.tween_callback(tri.queue_free)
		
		MusicData.RhythmPattern.REST:
			# 精准蓄力：能量漩涡积聚
			var vortex := _create_ring(pos, 20.0, Color(1.0, 0.9, 0.3, 0.4), 0.4)
			var v_tween := vortex.create_tween()
			v_tween.set_parallel(true)
			v_tween.tween_property(vortex, "scale", Vector2(0.3, 0.3), 0.3)
			v_tween.tween_property(vortex, "rotation", TAU, 0.3)
			v_tween.chain()
			v_tween.tween_property(vortex, "modulate:a", 0.0, 0.1)
			v_tween.tween_callback(vortex.queue_free)

# ============================================================
# 层级五：组合效果层（和弦进行）— 增强版
# ============================================================

## 增强版和弦进行完成特效
func _spawn_progression_resolve_vfx_enhanced(pos: Vector2, progression: Dictionary) -> void:
	var effect_type: String = progression.get("effect", {}).get("type", "")
	var color: Color = PROGRESSION_COLORS.get(effect_type, Color.WHITE)
	
	match effect_type:
		"burst_heal_or_damage":
			_vfx_progression_d_to_t(pos, color)
		"empower_next":
			_vfx_progression_t_to_d(pos, color)
		"cooldown_reduction":
			_vfx_progression_pd_to_d(pos, color)
		_:
			# 默认光环
			var ring := _create_ring(pos, 10.0, color, 0.7)
			var tween := ring.create_tween()
			tween.set_parallel(true)
			tween.tween_property(ring, "scale", Vector2(15.0, 15.0), 0.4)
			tween.tween_property(ring, "modulate:a", 0.0, 0.5)
			tween.chain()
			tween.tween_callback(ring.queue_free)

## D→T 紧张到解决：全屏金色冲击波 + 金色光矛
func _vfx_progression_d_to_t(pos: Vector2, color: Color) -> void:
	# 全屏金色冲击波
	var shockwave := _create_ring(pos, 5.0, color, 0.8)
	var sw_tween := shockwave.create_tween()
	sw_tween.set_parallel(true)
	sw_tween.tween_property(shockwave, "scale", Vector2(80.0, 80.0), 0.6)
	sw_tween.tween_property(shockwave, "modulate:a", 0.0, 0.7)
	sw_tween.chain()
	sw_tween.tween_callback(shockwave.queue_free)
	
	# 暖色调全屏闪光
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.9, 0.5, 0.25)
	flash.size = Vector2(2000, 2000)
	flash.position = Vector2(-1000, -1000)
	flash.z_index = 95
	add_child(flash)
	var fl_tween := flash.create_tween()
	fl_tween.tween_property(flash, "color:a", 0.0, 0.4)
	fl_tween.tween_callback(flash.queue_free)
	
	# 金色光屑粒子
	_spawn_radial_particles(pos, color, 16, 80.0, 0.5)
	
	_spawn_floating_text(pos + Vector2(0, -40), "终止解决!", color)

## T→D 稳定到紧张：屏幕边缘收缩 + 琥珀色能量框
func _vfx_progression_t_to_d(pos: Vector2, color: Color) -> void:
	# 琥珀色边框收缩效果
	var border := ColorRect.new()
	border.color = Color(color.r, color.g, color.b, 0.15)
	border.size = Vector2(2000, 2000)
	border.position = Vector2(-1000, -1000)
	border.z_index = 95
	add_child(border)
	
	var b_tween := border.create_tween()
	b_tween.tween_property(border, "color:a", 0.3, 0.2)
	b_tween.tween_property(border, "color:a", 0.0, 0.5)
	b_tween.tween_callback(border.queue_free)
	
	# 能量高速旋转积聚
	for i in range(8):
		var angle := (TAU / 8) * i
		var particle := _create_polygon(pos + Vector2.from_angle(angle) * 50.0,
			4.0, 4, color)
		var p_tween := particle.create_tween()
		p_tween.tween_property(particle, "global_position", pos, 0.3)
		p_tween.parallel().tween_property(particle, "rotation", TAU * 2, 0.3)
		p_tween.tween_property(particle, "modulate:a", 0.0, 0.1)
		p_tween.tween_callback(particle.queue_free)
	
	_spawn_floating_text(pos + Vector2(0, -40), "增幅就绪!", color)

## PD→D 准备到紧张：全屏加速线条
func _vfx_progression_pd_to_d(pos: Vector2, color: Color) -> void:
	# 紫色加速线条（从后方向前方掠过）
	var aim_dir := _get_aim_direction()
	for i in range(12):
		var offset := Vector2(randf_range(-200, 200), randf_range(-200, 200))
		var line := Line2D.new()
		line.width = 1.5
		line.default_color = Color(color.r, color.g, color.b, 0.5)
		line.add_point(offset)
		line.add_point(offset + aim_dir * 5.0)
		line.global_position = pos
		add_child(line)
		
		var l_tween := line.create_tween()
		l_tween.tween_method(func(t: float):
			if is_instance_valid(line) and line.get_point_count() > 1:
				line.set_point_position(1, offset + aim_dir * (5.0 + t * 100.0))
		, 0.0, 1.0, 0.3)
		l_tween.tween_property(line, "modulate:a", 0.0, 0.15)
		l_tween.tween_callback(line.queue_free)
	
	_spawn_floating_text(pos + Vector2(0, -40), "冷却缩减!", color)

# ============================================================
# 层级六：环境与惩罚层
# ============================================================

## 单调寂静惩罚：法术槽死亡 + 灰色消散
func _spawn_monotone_silence_vfx(pos: Vector2, note_data: Dictionary) -> void:
	var note_color: Color = note_data.get("color", Color(0.5, 0.5, 0.5))
	
	# 灰色消散效果
	var death := _create_polygon(pos, 20.0, 8, Color(0.3, 0.3, 0.3, 0.6))
	var d_tween := death.create_tween()
	d_tween.tween_property(death, "scale", Vector2(3.0, 3.0), 0.3)
	d_tween.tween_property(death, "modulate:a", 0.0, 0.4)
	d_tween.tween_callback(death.queue_free)
	
	# 红色交叉线
	for i in range(2):
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(1.0, 0.0, 0.0, 0.7)
		var offset := 20.0
		if i == 0:
			line.add_point(Vector2(-offset, -offset))
			line.add_point(Vector2(offset, offset))
		else:
			line.add_point(Vector2(-offset, offset))
			line.add_point(Vector2(offset, -offset))
		line.global_position = pos
		add_child(line)
		
		var l_tween := line.create_tween()
		l_tween.tween_property(line, "modulate:a", 0.0, 0.8)
		l_tween.tween_callback(line.queue_free)
	
	# 静电/数据损坏粒子
	for i in range(8):
		var shard := _create_polygon(
			pos + Vector2(randf_range(-15, 15), randf_range(-15, 15)),
			3.0, 4, Color(0.5, 0.5, 0.5, 0.5))
		var s_tween := shard.create_tween()
		s_tween.set_parallel(true)
		s_tween.tween_property(shard, "position",
			shard.position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 0.4)
		s_tween.tween_property(shard, "modulate:a", 0.0, 0.5)
		s_tween.chain()
		s_tween.tween_callback(shard.queue_free)
	
	_spawn_floating_text(pos + Vector2(0, -30), "单调寂静!", Color(0.8, 0.0, 0.0))

## 噪音过载惩罚：弹道偏移 + 像素化故障
func _spawn_noise_overload_vfx(pos: Vector2, _data: Dictionary) -> void:
	# 故障闪烁效果
	for i in range(5):
		var glitch := _create_polygon(
			pos + Vector2(randf_range(-30, 30), randf_range(-30, 30)),
			randf_range(5, 15), 4, Color(1.0, 0.0, 0.0, 0.3))
		var g_tween := glitch.create_tween()
		g_tween.tween_property(glitch, "modulate:a", 0.6, 0.05)
		g_tween.tween_property(glitch, "modulate:a", 0.0, 0.1)
		g_tween.tween_callback(glitch.queue_free)
	
	_spawn_floating_text(pos + Vector2(0, -30), "噪音过载!", Color(1.0, 0.3, 0.0))

## 不和谐腐蚀惩罚：紫色数字病毒
func _spawn_dissonance_corrosion_vfx(pos: Vector2, _data: Dictionary) -> void:
	var color := Color(0.6, 0.0, 0.8)
	
	# 紫色腐蚀扩散
	var corrosion := _create_ring(pos, 10.0, color, 0.5)
	var c_tween := corrosion.create_tween()
	c_tween.set_parallel(true)
	c_tween.tween_property(corrosion, "scale", Vector2(5.0, 5.0), 0.3)
	c_tween.tween_property(corrosion, "modulate:a", 0.0, 0.4)
	c_tween.chain()
	c_tween.tween_callback(corrosion.queue_free)
	
	# 屏幕边缘紫光闪烁
	var edge_flash := ColorRect.new()
	edge_flash.color = Color(0.6, 0.0, 0.8, 0.15)
	edge_flash.size = Vector2(2000, 2000)
	edge_flash.position = Vector2(-1000, -1000)
	edge_flash.z_index = 90
	add_child(edge_flash)
	
	var ef_tween := edge_flash.create_tween()
	ef_tween.tween_property(edge_flash, "color:a", 0.3, 0.1)
	ef_tween.tween_property(edge_flash, "color:a", 0.0, 0.2)
	ef_tween.tween_callback(edge_flash.queue_free)
	
	_spawn_floating_text(pos + Vector2(0, -30), "不和谐腐蚀!", color)

# ============================================================
# 层级七：频谱相位层（共鸣切片）
# ============================================================

## 频谱相位切换全局视觉
func _spawn_phase_switch_vfx(pos: Vector2, phase_name: String) -> void:
	match phase_name:
		"overtone":
			_vfx_switch_to_overtone(pos)
		"sub_bass":
			_vfx_switch_to_sub_bass(pos)
		"fundamental":
			_vfx_switch_to_fundamental(pos)

## 切换至高通 (Overtone)：全屏闪白 + 冷色调 + 锐化
func _vfx_switch_to_overtone(pos: Vector2) -> void:
	# 全屏闪白
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.7)
	flash.size = Vector2(2000, 2000)
	flash.position = Vector2(-1000, -1000)
	flash.z_index = 100
	add_child(flash)
	
	var fl_tween := flash.create_tween()
	fl_tween.tween_property(flash, "color:a", 0.0, 0.3)
	fl_tween.tween_callback(flash.queue_free)
	
	# 上升气泡粒子
	for i in range(15):
		var bubble := _create_polygon(
			pos + Vector2(randf_range(-200, 200), randf_range(50, 150)),
			randf_range(2, 5), 8, Color(0.7, 0.9, 1.0, 0.4))
		var b_tween := bubble.create_tween()
		b_tween.set_parallel(true)
		b_tween.tween_property(bubble, "position",
			bubble.position + Vector2(0, -200), 1.0)
		b_tween.tween_property(bubble, "modulate:a", 0.0, 1.0)
		b_tween.chain()
		b_tween.tween_callback(bubble.queue_free)
	
	_spawn_floating_text(pos + Vector2(0, -40), "高通相位", Color(0.7, 0.9, 1.0))

## 切换至低通 (Sub-Bass)：全屏闪黑 + 暖色调 + 液态化
func _vfx_switch_to_sub_bass(pos: Vector2) -> void:
	# 全屏闪黑
	var flash := ColorRect.new()
	flash.color = Color(0.0, 0.0, 0.0, 0.7)
	flash.size = Vector2(2000, 2000)
	flash.position = Vector2(-1000, -1000)
	flash.z_index = 100
	add_child(flash)
	
	var fl_tween := flash.create_tween()
	fl_tween.tween_property(flash, "color:a", 0.0, 0.4)
	fl_tween.tween_callback(flash.queue_free)
	
	# 下降岩浆粒子
	for i in range(15):
		var lava := _create_polygon(
			pos + Vector2(randf_range(-200, 200), randf_range(-150, -50)),
			randf_range(3, 7), 6, Color(1.0, 0.4, 0.1, 0.5))
		var l_tween := lava.create_tween()
		l_tween.set_parallel(true)
		l_tween.tween_property(lava, "position",
			lava.position + Vector2(0, 200), 1.2)
		l_tween.tween_property(lava, "modulate:a", 0.0, 1.2)
		l_tween.chain()
		l_tween.tween_callback(lava.queue_free)
	
	_spawn_floating_text(pos + Vector2(0, -40), "低通相位", Color(1.0, 0.4, 0.1))

## 返回全频 (Fundamental)：平滑过渡回原始风格
func _vfx_switch_to_fundamental(pos: Vector2) -> void:
	# 柔和的白色脉冲
	var pulse := _create_ring(pos, 10.0, Color(0.8, 0.8, 0.8), 0.4)
	var p_tween := pulse.create_tween()
	p_tween.set_parallel(true)
	p_tween.tween_property(pulse, "scale", Vector2(30.0, 30.0), 0.5)
	p_tween.tween_property(pulse, "modulate:a", 0.0, 0.6)
	p_tween.chain()
	p_tween.tween_callback(pulse.queue_free)
	
	_spawn_floating_text(pos + Vector2(0, -40), "全频相位", Color(0.8, 0.8, 0.8))

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
		var remaining = effect["duration"] - effect["time_alive"]
		if remaining < 1.0:
			var alpha = remaining
			for node in effect.get("nodes", []):
				if is_instance_valid(node):
					node.modulate.a = alpha
		
		# 持续粒子生成（圣光领域、护盾、法阵等）
		if effect["type"] in ["holy", "shield", "field", "summon_pulse"]:
			effect["particle_timer"] = effect.get("particle_timer", 0.0) + delta
			if effect["particle_timer"] >= effect.get("particle_interval", 0.3):
				effect["particle_timer"] = 0.0
				var epos: Vector2 = effect.get("position", Vector2.ZERO)
				var ecolor: Color = effect.get("color", Color.WHITE)
				
				if effect["type"] == "field":
					# 法阵：边缘上升粒子
					var angle := randf() * TAU
					var spawn_pos := epos + Vector2.from_angle(angle) * 55.0
					var particle := _create_polygon(spawn_pos, 2.0, 4, ecolor)
					var tween := particle.create_tween()
					tween.set_parallel(true)
					tween.tween_property(particle, "position",
						particle.position + Vector2(0, -30), 0.6)
					tween.tween_property(particle, "modulate:a", 0.0, 0.6)
					tween.chain()
					tween.tween_callback(particle.queue_free)
				else:
					# 通用上升粒子
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
		MusicData.SpellForm.ENHANCED_PROJECTILE: return Color(1.0, 0.9, 0.3)   # 圣光金
		MusicData.SpellForm.DOT_PROJECTILE: return Color(0.15, 0.1, 0.6)       # 暗蓝色
		MusicData.SpellForm.EXPLOSIVE: return Color(1.0, 0.5, 0.0)             # 烈焰橙
		MusicData.SpellForm.SHOCKWAVE: return Color(0.5, 0.0, 0.5)             # 深紫色
		MusicData.SpellForm.FIELD: return Color(0.9, 0.8, 0.0)                 # Dominant黄
		MusicData.SpellForm.DIVINE_STRIKE: return Color(0.8, 0.0, 0.0)         # 血红色
		MusicData.SpellForm.SHIELD_HEAL: return Color(0.2, 0.9, 0.4)           # 治愈绿
		MusicData.SpellForm.SUMMON: return Color(0.15, 0.15, 0.7)              # 深蓝色
		MusicData.SpellForm.CHARGED: return Color(0.9, 0.9, 1.0)               # 银白色
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

func _find_nearest_enemy(pos: Vector2) -> Vector2:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest_pos := Vector2.ZERO
	var nearest_dist := INF
	for enemy in enemies:
		if enemy is Node2D:
			var dist := pos.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_pos = enemy.global_position
	return nearest_pos

# ============================================================
# Shader 集成（审计报告 2.4 修复：激活闲置 Shader）
# ============================================================

## 应用音色弹体 Shader 到施法反馈
func _apply_timbre_shader_to_cast(pos: Vector2, timbre: MusicData.TimbreType, _spell_data: Dictionary) -> void:
	if _timbre_projectile_shader == null:
		return
	var timbre_sprite := Sprite2D.new()
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	var grad := Gradient.new()
	var timbre_color: Color = TIMBRE_COLORS.get(timbre, Color.WHITE)
	grad.set_color(0, timbre_color)
	grad.set_color(1, Color(timbre_color.r, timbre_color.g, timbre_color.b, 0.0))
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	timbre_sprite.texture = tex
	timbre_sprite.global_position = pos
	var mat := ShaderMaterial.new()
	mat.shader = _timbre_projectile_shader
	mat.set_shader_parameter("timbre_type", timbre)
	mat.set_shader_parameter("timbre_color", timbre_color)
	mat.set_shader_parameter("intensity", 1.0)
	mat.set_shader_parameter("beat_phase", GlobalMusicManager.get_beat_energy())
	timbre_sprite.material = mat
	add_child(timbre_sprite)
	var tween := timbre_sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(timbre_sprite, "scale", Vector2(3.0, 3.0), 0.2)
	tween.tween_property(timbre_sprite, "modulate:a", 0.0, 0.25)
	tween.chain()
	tween.tween_callback(timbre_sprite.queue_free)

## 应用修饰符 VFX Shader 到修饰符视觉效果
func _apply_modifier_shader(node: Node2D, modifier: MusicData.ModifierEffect) -> void:
	if _modifier_vfx_shader == null or node == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = _modifier_vfx_shader
	var mod_type: int = 0
	match modifier:
		MusicData.ModifierEffect.PIERCE: mod_type = 0
		MusicData.ModifierEffect.HOMING: mod_type = 1
		MusicData.ModifierEffect.SPLIT: mod_type = 2
		MusicData.ModifierEffect.ECHO: mod_type = 3
		MusicData.ModifierEffect.SCATTER: mod_type = 4
	mat.set_shader_parameter("modifier_type", mod_type)
	var color: Color = MODIFIER_COLORS.get(modifier, Color.WHITE)
	mat.set_shader_parameter("modifier_color", color)
	mat.set_shader_parameter("intensity", 1.0)
	mat.set_shader_parameter("time_offset", GameManager.game_time)
	node.material = mat

## 应用扫描线发光 Shader（用于特殊效果）
func _apply_scanline_glow(node: Node2D, color: Color) -> void:
	if _scanline_glow_shader == null or node == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = _scanline_glow_shader
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("scan_speed", 0.5)
	mat.set_shader_parameter("scan_width", 0.1)
	node.material = mat

## 清除所有视觉效果
func clear_all() -> void:
	for effect in _active_effects:
		for node in effect.get("nodes", []):
			if is_instance_valid(node):
				node.queue_free()
	_active_effects.clear()

## 暂击视觉效果：在玩家位置生成一个闪光环
func _spawn_crit_flash(pos: Vector2) -> void:
	var flash := _create_ring(pos, 40.0, Color(1.0, 0.9, 0.2, 0.9))
	flash.z_index = 60
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2.5, 2.5), 0.25)
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.chain()
	tween.tween_callback(flash.queue_free)
	_spawn_floating_text(pos + Vector2(0, -20), "★CRIT★", Color(1.0, 0.85, 0.1))
	visual_effect_spawned.emit("crit_flash", pos)
