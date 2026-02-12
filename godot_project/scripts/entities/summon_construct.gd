## summon_construct.gd
## 构造体基类 — "幻影声部" (The Phantom Section) (Issue #32)
## 基于 SummoningSystem_Documentation.md 设计。
##
## 每个构造体由小七和弦的根音决定类型：
##   C = 节拍哨塔 (律动塔)    D = 长程棱镜 (共鸣器)
##   E = 低频音墙 (干扰场)    F = 净化信标 (干扰场)
##   G = 重低音炮 (律动塔)    A = 和声光环 (共鸣器)
##   B = 高频陷阱 (干扰场)
##
## 核心机制：
##   - 强弱拍响应 (Accent System)
##   - 基于小节数的生命周期
##   - 共鸣网络 (Resonance Network)
##   - 玩家指挥 (Conducting) — 弹体击中触发激励
##
## OPT07 集成：
##   - 每种构造体挂载独立的 SummonAudioController
##   - 行为触发时同步触发音频事件
##   - 音频严格量化到节拍网格上
extends Node2D

# ============================================================
# 信号
# ============================================================
signal construct_expired(construct_id: int)
signal construct_action(construct_id: int, action_name: String)
signal construct_excited(construct_id: int)  ## 被玩家弹体激励

# ============================================================
# 构造体类别枚举
# ============================================================
enum ConstructCategory {
	RHYTHM,       ## 律动塔：直接输出
	RESONANCE,    ## 共鸣器：增强效果
	MODULATION,   ## 干扰场：控制敌人
}

# ============================================================
# 根音 → 构造体类型映射
# ============================================================
const ROOT_NOTE_CONFIG: Dictionary = {
	0: {  # C — 节拍哨塔
		"name": "节拍哨塔",
		"category": ConstructCategory.RHYTHM,
		"color": Color(0.2, 0.8, 1.0),
		"desc": "每拍发射一枚基础弹体，指向最近敌人",
		"strong_beat_mult": 1.0,
		"weak_beat_mult": 0.5,
		"attack_on_weak": true,
	},
	1: {  # D — 长程棱镜
		"name": "长程棱镜",
		"category": ConstructCategory.RESONANCE,
		"color": Color(0.9, 0.7, 0.2),
		"desc": "玩家穿过棱镜射出的弹体射程翻倍并分裂",
		"strong_beat_mult": 1.0,
		"weak_beat_mult": 0.5,
		"attack_on_weak": false,
	},
	2: {  # E — 低频音墙
		"name": "低频音墙",
		"category": ConstructCategory.MODULATION,
		"color": Color(0.3, 0.5, 0.9),
		"desc": "生成阻挡敌人的波形墙",
		"strong_beat_mult": 1.0,
		"weak_beat_mult": 0.5,
		"attack_on_weak": true,
	},
	3: {  # F — 净化信标
		"name": "净化信标",
		"category": ConstructCategory.MODULATION,
		"color": Color(0.5, 1.0, 0.5),
		"desc": "范围内每小节清除一个敌人的弹幕或Debuff",
		"strong_beat_mult": 1.0,
		"weak_beat_mult": 0.0,
		"attack_on_weak": false,
	},
	4: {  # G — 重低音炮
		"name": "重低音炮",
		"category": ConstructCategory.RHYTHM,
		"color": Color(1.0, 0.3, 0.2),
		"desc": "仅在强拍发射高伤冲击波",
		"strong_beat_mult": 2.0,
		"weak_beat_mult": 0.0,
		"attack_on_weak": false,
	},
	5: {  # A — 和声光环
		"name": "和声光环",
		"category": ConstructCategory.RESONANCE,
		"color": Color(0.8, 0.6, 1.0),
		"desc": "范围内玩家的疲劳值缓慢恢复",
		"strong_beat_mult": 1.0,
		"weak_beat_mult": 0.5,
		"attack_on_weak": true,
	},
	6: {  # B — 高频陷阱
		"name": "高频陷阱",
		"category": ConstructCategory.MODULATION,
		"color": Color(1.0, 0.9, 0.3),
		"desc": "地面生成尖刺区域，经过的敌人持续受到高频伤害",
		"strong_beat_mult": 1.0,
		"weak_beat_mult": 0.7,
		"attack_on_weak": true,
	},
}

# ============================================================
# 配置
# ============================================================
## 构造体 ID
var construct_id: int = -1
## 根音 (0=C, 1=D, ..., 6=B)
var root_note: int = 0
## 存活小节数
var measures_remaining: int = 4
## 基础伤害
var base_damage: float = 15.0
## 攻击范围
var attack_range: float = 180.0
## 攻击弹体速度
var projectile_speed: float = 500.0
## 脉冲范围（重低音炮、高频陷阱等）
var pulse_radius: float = 100.0
## 净化范围
var cleanse_radius: float = 120.0
## 光环范围（和声光环、长程棱镜）
var aura_radius: float = 150.0
## 疲劳恢复速率（和声光环）
var fatigue_recovery_rate: float = 0.3

# ============================================================
# 共鸣网络
# ============================================================
## 共鸣连接距离
const RESONANCE_LINK_DISTANCE: float = 400.0
## 共鸣网络增益
const NETWORK_BONUS: Dictionary = {
	ConstructCategory.RHYTHM: {"attack_speed": 0.2},
	ConstructCategory.RESONANCE: {"range": 0.25},
	ConstructCategory.MODULATION: {"strength": 0.3},
}

## 当前连接的构造体 ID 列表
var _linked_constructs: Array[int] = []
## 网络增益倍率
var _network_bonus: float = 0.0

# ============================================================
# 内部状态
# ============================================================
var _config: Dictionary = {}
var _category: int = ConstructCategory.RHYTHM
var _current_beat: int = 0
var _is_fading: bool = false
var _fade_timer: float = 0.0
var _visual_body: Polygon2D = null
var _visual_aura: Polygon2D = null
var _excitation_cooldown: float = 0.0

## === OPT07: 音频控制器 ===
var _audio_controller: Node2D = null  ## SummonAudioController 实例

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_config = ROOT_NOTE_CONFIG.get(root_note, ROOT_NOTE_CONFIG[0])
	_category = _config.get("category", ConstructCategory.RHYTHM)
	
	# 创建视觉
	_create_visual()
	
	# 连接节拍信号
	if GameManager.has_signal("beat_tick"):
		if not GameManager.beat_tick.is_connected(_on_beat):
			GameManager.beat_tick.connect(_on_beat)
	
	# === OPT07: 初始化音频控制器 ===
	_setup_audio_controller()
	
	# 入场动画
	_play_spawn_animation()

func _process(delta: float) -> void:
	if _is_fading:
		_fade_timer += delta
		if _fade_timer >= 1.0:
			queue_free()
			return
		modulate.a = 1.0 - _fade_timer
		return
	
	# 激励冷却
	if _excitation_cooldown > 0:
		_excitation_cooldown -= delta
	
	# 持续效果（非节拍驱动）
	_update_continuous_effects(delta)
	
	# 视觉更新
	_update_visual(delta)

# ============================================================
# 节拍回调 — 核心行为驱动
# ============================================================

func _on_beat(beat_index: int) -> void:
	if _is_fading:
		return
	
	_current_beat = beat_index
	
	# 强弱拍判断 (4/4拍：第0、2拍为强拍)
	var is_strong_beat: bool = (beat_index % 2 == 0)
	
	# 获取效能倍率
	var beat_mult: float
	if is_strong_beat:
		beat_mult = _config.get("strong_beat_mult", 1.0)
	else:
		beat_mult = _config.get("weak_beat_mult", 0.5)
		if not _config.get("attack_on_weak", true):
			beat_mult = 0.0
	
	# 应用网络增益
	var total_mult := beat_mult * (1.0 + _network_bonus)
	
	# 执行具体行为
	if total_mult > 0.0:
		_perform_action(is_strong_beat, total_mult)
	
	# 生命周期管理：每小节（第0拍）减少存活小节数
	if beat_index == 0:
		measures_remaining -= 1
		if measures_remaining <= 0:
			_start_fade_out()
	
	# 节拍视觉脉冲
	_beat_visual_pulse(is_strong_beat)

# ============================================================
# 具体行为实现（根据根音类型）
# ============================================================

func _perform_action(is_strong: bool, multiplier: float) -> void:
	match root_note:
		0:  # C — 节拍哨塔：每拍射击
			_action_rhythm_tower(multiplier)
		1:  # D — 长程棱镜：增强穿过的弹体
			_action_prism(multiplier)
		2:  # E — 低频音墙：推开敌人
			_action_bass_wall(multiplier)
		3:  # F — 净化信标：清除debuff
			if is_strong:
				_action_cleanse(multiplier)
		4:  # G — 重低音炮：仅强拍冲击
			if is_strong:
				_action_sub_bass(multiplier)
		5:  # A — 和声光环：恢复疲劳
			_action_harmony_aura(multiplier)
		6:  # B — 高频陷阱：持续伤害
			_action_hi_hat_trap(multiplier)
	
	# === OPT07: 触发事件型音频 ===
	_trigger_event_audio()
	
	construct_action.emit(construct_id, _config.get("name", "unknown"))

## C — 节拍哨塔：射击最近敌人
func _action_rhythm_tower(mult: float) -> void:
	var nearest := _find_nearest_enemy(attack_range)
	if nearest == null:
		return
	
	var dir := (nearest.global_position - global_position).normalized()
	var damage := base_damage * mult
	
	_fire_projectile(dir, damage, projectile_speed)

## D — 长程棱镜：标记自身为棱镜增强区域
func _action_prism(_mult: float) -> void:
	# 棱镜效果在 _update_continuous_effects 中持续处理
	# 节拍时产生视觉脉冲
	pass

## E — 低频音墙：推开范围内敌人
func _action_bass_wall(mult: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < pulse_radius:
			var push_dir := (enemy.global_position - global_position).normalized()
			var push_force := 200.0 * mult * (1.0 - dist / pulse_radius)
			if enemy is CharacterBody2D:
				enemy.velocity += push_dir * push_force

## F — 净化信标：清除范围内debuff
func _action_cleanse(_mult: float) -> void:
	# 清除范围内敌人弹幕（如果有弹幕系统）
	var player := get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < cleanse_radius:
		# 减少玩家不和谐度
		if player.has_method("reduce_dissonance"):
			player.reduce_dissonance(5.0)

## G — 重低音炮：范围冲击波
func _action_sub_bass(mult: float) -> void:
	var damage := base_damage * mult
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < pulse_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage * (1.0 - dist / pulse_radius))
			# 击退
			if enemy is CharacterBody2D:
				var push_dir := (enemy.global_position - global_position).normalized()
				enemy.velocity += push_dir * 300.0

## A — 和声光环：恢复疲劳
func _action_harmony_aura(mult: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < aura_radius:
		FatigueManager.add_external_fatigue(-fatigue_recovery_rate * mult)

## B — 高频陷阱：持续伤害区域
func _action_hi_hat_trap(mult: float) -> void:
	var damage := base_damage * 0.3 * mult
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < pulse_radius * 0.8:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)

# ============================================================
# 持续效果（每帧）
# ============================================================

func _update_continuous_effects(_delta: float) -> void:
	match root_note:
		1:  # D — 长程棱镜：增强穿过的弹体
			_prism_enhance_projectiles()
		6:  # B — 高频陷阱：持续视觉
			pass

func _prism_enhance_projectiles() -> void:
	# 查找 ProjectileManager 并增强穿过棱镜的弹体
	var proj_mgr := get_tree().current_scene.get_node_or_null("ProjectileManager")
	if proj_mgr == null:
		return
	
	if not proj_mgr.has("_projectiles"):
		return
	
	for proj in proj_mgr._projectiles:
		if not proj.get("active", false):
			continue
		if proj.get("prism_enhanced", false):
			continue
		var proj_pos: Vector2 = proj.get("position", Vector2.ZERO)
		if proj_pos.distance_to(global_position) < aura_radius * 0.5:
			# 增强弹体：射程翻倍
			proj["duration"] = proj.get("duration", 1.0) * 2.0
			proj["prism_enhanced"] = true

# ============================================================
# 玩家指挥 — 激励 (Excitation)
# ============================================================

## 当玩家弹体击中构造体时调用
func excite() -> void:
	if _excitation_cooldown > 0:
		return
	_excitation_cooldown = 0.5  # 激励冷却
	
	# 立即执行一次强拍效果
	_perform_action(true, _config.get("strong_beat_mult", 1.0) * 1.5)
	
	# === OPT07: 激励时触发额外音频事件 ===
	if _audio_controller and _audio_controller.has_method("trigger_on_event"):
		_audio_controller.trigger_on_event()
	
	# 激励视觉
	_play_excitation_visual()
	construct_excited.emit(construct_id)

# ============================================================
# 共鸣网络
# ============================================================

## 更新共鸣网络连接（由 SummonManager 调用）
func update_network(all_constructs: Array) -> void:
	_linked_constructs.clear()
	_network_bonus = 0.0
	
	for other in all_constructs:
		if other == self or not is_instance_valid(other):
			continue
		if not other is Node2D:
			continue
		if other.get("_category") != _category:
			continue
		
		var dist := global_position.distance_to(other.global_position)
		if dist < RESONANCE_LINK_DISTANCE:
			_linked_constructs.append(other.get("construct_id", -1))
	
	# 计算网络增益
	if _linked_constructs.size() > 0:
		var bonus_config: Dictionary = NETWORK_BONUS.get(_category, {})
		for key in bonus_config:
			_network_bonus += bonus_config[key] * _linked_constructs.size()

# ============================================================
# 弹体发射（律动塔类使用）
# ============================================================

func _fire_projectile(dir: Vector2, damage: float, speed: float) -> void:
	var proj_mgr := get_tree().current_scene.get_node_or_null("ProjectileManager")
	if proj_mgr == null:
		return
	
	if not proj_mgr.has("_projectiles"):
		return
	
	var proj := {
		"position": global_position,
		"velocity": dir * speed,
		"damage": damage,
		"size": 8.0,
		"duration": 0.8,
		"time_alive": 0.0,
		"color": _config.get("color", Color.WHITE).lightened(0.3),
		"active": true,
		"modifier": -1,
		"is_summon_attack": true,
	}
	proj_mgr._projectiles.append(proj)

# ============================================================
# 工具函数
# ============================================================

func _find_nearest_enemy(max_range: float) -> Node:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node = null
	var nearest_dist := max_range
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	
	return nearest

# ============================================================
# 视觉系统
# ============================================================

func _create_visual() -> void:
	var color: Color = _config.get("color", Color.WHITE)
	var size := 20.0
	
	# 主体多边形
	_visual_body = Polygon2D.new()
	var points := PackedVector2Array()
	var vertex_count := 6
	
	match _category:
		ConstructCategory.RHYTHM:
			vertex_count = 4  # 方形
		ConstructCategory.RESONANCE:
			vertex_count = 8  # 八角形
		ConstructCategory.MODULATION:
			vertex_count = 3  # 三角形
	
	for i in range(vertex_count):
		var angle := (TAU / vertex_count) * i - PI / 2.0
		points.append(Vector2.from_angle(angle) * size)
	
	_visual_body.polygon = points
	_visual_body.color = color
	_visual_body.name = "Body"
	add_child(_visual_body)
	
	# 光环（共鸣器和干扰场）
	if _category != ConstructCategory.RHYTHM:
		_visual_aura = Polygon2D.new()
		var aura_points := PackedVector2Array()
		var aura_r := aura_radius if _category == ConstructCategory.RESONANCE else pulse_radius
		for i in range(32):
			var angle := (TAU / 32) * i
			aura_points.append(Vector2.from_angle(angle) * aura_r)
		_visual_aura.polygon = aura_points
		_visual_aura.color = Color(color.r, color.g, color.b, 0.08)
		_visual_aura.name = "Aura"
		add_child(_visual_aura)

func _play_spawn_animation() -> void:
	scale = Vector2(0.0, 0.0)
	modulate.a = 0.0
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _update_visual(_delta: float) -> void:
	if _visual_body:
		_visual_body.rotation += _delta * 0.3
	
	# 浮动效果
	if _visual_body:
		var float_y := sin(Time.get_ticks_msec() * 0.002 + construct_id * 1.5) * 3.0
		_visual_body.position.y = float_y

func _beat_visual_pulse(is_strong: bool) -> void:
	if _visual_body == null:
		return
	
	var target_scale := Vector2(1.4, 1.4) if is_strong else Vector2(1.15, 1.15)
	var tween := create_tween()
	tween.tween_property(_visual_body, "scale", target_scale, 0.05)
	tween.tween_property(_visual_body, "scale", Vector2(1.0, 1.0), 0.1)

func _play_excitation_visual() -> void:
	if _visual_body == null:
		return
	
	# 闪白 + 放大
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual_body, "modulate", Color.WHITE, 0.05)
	tween.tween_property(_visual_body, "scale", Vector2(1.8, 1.8), 0.08)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(_visual_body, "modulate", Color(1, 1, 1, 1), 0.15)
	tween.tween_property(_visual_body, "scale", Vector2(1.0, 1.0), 0.15)

func _start_fade_out() -> void:
	_is_fading = true
	_fade_timer = 0.0
	
	# === OPT07: 停用音频控制器 ===
	if _audio_controller and _audio_controller.has_method("deactivate"):
		_audio_controller.deactivate()
	
	construct_expired.emit(construct_id)

# ============================================================
# OPT07 — 音频控制器集成
# ============================================================

## 初始化音频控制器
func _setup_audio_controller() -> void:
	var controller_script = load("res://scripts/entities/summon_audio_controller.gd")
	if controller_script == null:
		push_warning("SummonConstruct: 无法加载 SummonAudioController 脚本")
		return
	
	_audio_controller = Node2D.new()
	_audio_controller.set_script(controller_script)
	
	# 获取对应的音频配置
	var profile: SummonAudioProfile = SummonAudioProfile.get_profile_for_root(root_note)
	_audio_controller.audio_profile = profile
	
	_audio_controller.name = "AudioController"
	add_child(_audio_controller)

## 触发事件型音频（在 _perform_action 中调用）
func _trigger_event_audio() -> void:
	if _audio_controller == null:
		return
	
	# 仅对事件型触发模式的构造体手动触发
	if _audio_controller.audio_profile == null:
		return
	
	var trigger_mode = _audio_controller.audio_profile.trigger_mode
	if trigger_mode == SummonAudioProfile.TriggerMode.ON_EVENT:
		if _audio_controller.has_method("trigger_on_event"):
			_audio_controller.trigger_on_event()

## 获取音频控制器信息（供调试使用）
func get_audio_info() -> Dictionary:
	if _audio_controller and _audio_controller.has_method("get_audio_info"):
		return _audio_controller.get_audio_info()
	return {}
