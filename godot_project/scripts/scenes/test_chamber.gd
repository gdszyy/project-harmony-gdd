## test_chamber.gd
## 回响试炼场 (The Echoing Chamber) — 测试场主逻辑 v2.0 (2.5D 迁移版)
##
## v2.0 变更：
## - 集成 RenderBridge3D 实现 2.5D 混合渲染（与 main_game 视觉风格一致）
## - 替换 Polygon2D 玩家视觉为 PlayerVisualEnhanced（正十二面体 + 金环）+ HarmonicAvatarManager (3D 程序化化身)
## - 添加 ChapterManager 支持章节视觉切换测试
## - 添加地面 Shader（pulsing_grid.gdshader 脉冲网格）
## - 敌人生成时自动注册 3D 代理（精英独立代理 / 普通 MultiMesh 批量渲染）
## - 弹幕数据实时同步到 3D 渲染层
## - 新增 F11 快捷键：切换章节视觉主题
## - 新增 F12 快捷键：切换 3D 渲染层开关（性能调试）
##
## 功能概述：
##   1. 自由生成任意敌人（类型、数量、等级可调）
##   2. 自由配置玩家属性（HP、伤害倍率、移速等）
##   3. 直接集成 SpellcraftSystem 进行法术测试（序列器 + 手动施法 + 和弦合成）
##   4. 实时 DPS 统计与伤害日志
##   5. 无限生命 / 无限疲劳 / 时间暂停等调试开关
##   6. 快速切换调式、音色、BPM 等核心参数
##   7. 一键解锁全部图鉴条目
##   8. 法术快速测试面板：一键施放任意音符/和弦/修饰符组合
##
## 与实际游戏机制的同步：
##   - 所有法术施放通过 SpellcraftSystem 的公开接口执行
##   - 弹体由 ProjectileManager 统一管理（监听 spell_cast / chord_cast 信号）
##   - 伤害计算遵循实际公式（含疲劳、调式、音色、节奏型修饰）
##   - 碰撞检测由 ProjectileManager.check_collisions() 统一处理
##
## 场景结构 (v2.0)：
##   TestChamber (Node2D)
##     ├── Ground (背景 + pulsing_grid Shader)
##     ├── Player (玩家)
##     │   ├── PlayerVisualEnhanced (正十二面体 + 金环 + 粒子, 2D 层)
##     │   └── HarmonicAvatarManager (程序化调式化身, 3D 层 via RenderBridge3D)
##     ├── EnemyContainer (敌人容器)
##     ├── ProjectileManager (弹体管理)
##     ├── ChapterManager (章节管理 — 支持视觉切换测试)
##     ├── SpellVisualManager (法术视觉管理)
##     ├── DeathVfxManager (死亡特效管理)
##     ├── DamageNumberManager (伤害数字管理)
##     ├── RenderBridge3D (2.5D 渲染桥接层)
##     ├── HUD (游戏 HUD)
##     ├── DebugPanel (调试面板 — 左侧可折叠)
##     └── DPSOverlay (DPS 统计覆盖层)
extends Node2D

# ============================================================
# 信号
# ============================================================
signal debug_message(text: String)

# ============================================================
# 常量
# ============================================================
const ARENA_SIZE := Vector2(3000, 3000)
const ARENA_CENTER := ARENA_SIZE / 2.0
const GRID_SIZE := 100.0
const GRID_COLOR := Color(0.08, 0.06, 0.14, 0.5)
const GRID_ACCENT := Color(0.15, 0.10, 0.25, 0.6)
const BORDER_COLOR := Color(0.6, 0.3, 1.0, 0.8)
## 碰撞检测频率
const COLLISION_CHECK_INTERVAL: float = 0.033  # ~30Hz

# 敌人场景路径
const ENEMY_SCENES: Dictionary = {
	"static":  "res://scenes/enemies/enemy_static.tscn",
	"silence": "res://scenes/enemies/enemy_silence.tscn",
	"screech": "res://scenes/enemies/enemy_screech.tscn",
	"pulse":   "res://scenes/enemies/enemy_pulse.tscn",
	"wall":    "res://scenes/enemies/enemy_wall.tscn",
}

# 敌人类型对应的 3D 代理颜色
const ENEMY_COLORS: Dictionary = {
	"static":  Color(0.7, 0.3, 0.3),   # 红色
	"silence": Color(0.2, 0.1, 0.4),   # 深紫
	"screech": Color(1.0, 0.8, 0.0),   # 黄色
	"pulse":   Color(0.0, 0.5, 1.0),   # 蓝色
	"wall":    Color(0.5, 0.5, 0.5),   # 灰色
}

# 精英敌人类型列表（用于判断是否创建独立 3D 代理）
const ELITE_TYPES: Array = ["pulse", "wall"]

# ============================================================
# 节点引用
# ============================================================
@onready var _player: CharacterBody2D = $Player
@onready var _enemy_container: Node2D = $EnemyContainer
@onready var _projectile_manager: Node2D = $ProjectileManager
@onready var _hud: CanvasLayer = $HUD
@onready var _ground: Node2D = $Ground

# v2.0: 2.5D 渲染桥接层
@onready var _render_bridge: Node = $RenderBridge3D

# v2.0: 章节管理器 (P0 Fix #46: 使用 Autoload 单例)
var _chapter_manager: Node = null

# v2.0: 视觉管理器
@onready var _spell_visual_manager: Node2D = $SpellVisualManager
@onready var _death_vfx_manager: Node2D = $DeathVfxManager
@onready var _damage_number_manager: Node2D = $DamageNumberManager

# ============================================================
# 调试状态
# ============================================================
var god_mode: bool = false          ## 无敌模式
var infinite_fatigue: bool = false   ## 无限疲劳（不增长）
var freeze_enemies: bool = false     ## 冻结敌人
var show_hitboxes: bool = false      ## 显示碰撞箱
var auto_fire: bool = false          ## 自动施法
var time_scale: float = 1.0         ## 时间缩放
var _collision_timer: float = 0.0    ## 碰撞检测计时器
var _auto_fire_timer: float = 0.0   ## 自动施法计时器
var _auto_fire_interval: float = 0.5 ## 自动施法间隔

# v2.0: 章节视觉切换
var _current_test_chapter: int = 0   ## 当前测试章节索引
const MAX_CHAPTERS: int = 7          ## 最大章节数

# DPS 统计
var _dps_tracker: Dictionary = {
	"total_damage": 0.0,
	"session_start": 0.0,
	"damage_log": [],       # [{time, damage, source}]
	"window_damage": 0.0,   # 5秒窗口伤害
	"window_start": 0.0,
	"current_dps": 0.0,
	"peak_dps": 0.0,
}

# 生成的敌人计数
var _spawned_count: int = 0
var _killed_count: int = 0

# 地面 Shader 节点
var _ground_sprite: Sprite2D = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# P0 Fix #46: 从 Autoload 获取 ChapterManager 单例
	_chapter_manager = get_node_or_null("/root/ChapterManager")
	_dps_tracker["session_start"] = Time.get_ticks_msec() / 1000.0
	_dps_tracker["window_start"] = _dps_tracker["session_start"]

	# 将玩家放在场地中心
	if _player:
		_player.position = ARENA_CENTER

	# 设置 GameManager 为测试模式并启动游戏
	if GameManager:
		GameManager.is_test_mode = true
		GameManager.current_state = GameManager.GameState.PLAYING

	# v2.0: 设置地面 Shader
	_setup_ground()

	# v2.0: 初始化 2.5D 渲染桥接层
	_setup_render_bridge()

	# v2.0: 连接节拍信号到 3D 渲染层
	_connect_beat_signal()

	# ★ 连接 SpellcraftSystem 信号以追踪法术施放
	_connect_spell_signals()

	# v2.0: 连接敌人击杀信号到死亡特效
	if not GameManager.enemy_killed.is_connected(_on_enemy_killed_vfx):
		GameManager.enemy_killed.connect(_on_enemy_killed_vfx)

	_log("回响试炼场 v2.0 (2.5D) 已启动。使用左侧调试面板控制测试环境。")
	_log("法术系统已同步：所有施法通过 SpellcraftSystem 执行。")
	_log("F11: 切换章节视觉主题 | F12: 切换 3D 渲染层")

func _process(delta: float) -> void:
	# 应用时间缩放
	Engine.time_scale = time_scale

	# God mode: 通过 GameManager 恢复满血
	if god_mode:
		GameManager.player_current_hp = GameManager.player_max_hp
		GameManager.player_hp_changed.emit(GameManager.player_current_hp, GameManager.player_max_hp)

	# 冻结敌人
	if freeze_enemies:
		for enemy in _enemy_container.get_children():
			if enemy.has_method("set_frozen"):
				enemy.set_frozen(true)

	# 无限疲劳：通过 FatigueManager 重置疲劳度
	if infinite_fatigue:
		FatigueManager.current_afi = 0.0

	# 自动施法（通过 SpellcraftSystem 的实际接口）
	if auto_fire:
		_auto_fire_timer += delta
		if _auto_fire_timer >= _auto_fire_interval:
			_auto_fire_timer = 0.0
			_auto_fire_cast()

	# 碰撞检测
	_collision_timer += delta
	if _collision_timer >= COLLISION_CHECK_INTERVAL:
		_collision_timer = 0.0
		_check_collisions()

	# 更新 DPS 窗口
	_update_dps_window()

	# 绘制调试信息
	if show_hitboxes:
		queue_redraw()

	# v2.0: 更新地面 Shader 参数
	_update_ground_shader()

	# v2.0: 同步弹幕数据到 3D 渲染层
	_sync_projectiles_to_3d()

func _draw() -> void:
	# 绘制竞技场网格
	_draw_arena_grid()

	# 绘制竞技场边界
	_draw_arena_border()

	# 绘制碰撞箱
	if show_hitboxes:
		_draw_hitboxes()

func _unhandled_input(event: InputEvent) -> void:
	# 快捷键
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				god_mode = !god_mode
				_log("无敌模式: %s" % ("开启" if god_mode else "关闭"))
			KEY_F2:
				infinite_fatigue = !infinite_fatigue
				_log("无限疲劳: %s" % ("开启" if infinite_fatigue else "关闭"))
			KEY_F3:
				freeze_enemies = !freeze_enemies
				_log("冻结敌人: %s" % ("开启" if freeze_enemies else "关闭"))
			KEY_F4:
				show_hitboxes = !show_hitboxes
				queue_redraw()
				_log("碰撞箱显示: %s" % ("开启" if show_hitboxes else "关闭"))
			KEY_F5:
				_clear_all_enemies()
			KEY_F6:
				_reset_dps()
			KEY_F7:
				time_scale = 0.5 if time_scale == 1.0 else 1.0
				_log("时间缩放: %.1fx" % time_scale)
			KEY_F8:
				_spawn_wave_preset("mixed_basic")
			KEY_F9:
				if CodexManager:
					CodexManager.unlock_all()
					_log("已解锁全部图鉴条目")
			KEY_F10:
				auto_fire = !auto_fire
				_log("自动施法: %s" % ("开启" if auto_fire else "关闭"))
			KEY_F11:
				# v2.0: 切换章节视觉主题
				_cycle_chapter_visual()
			KEY_F12:
				# v2.0: 切换 3D 渲染层开关
				_toggle_3d_layer()
			KEY_ESCAPE:
				_return_to_menu()

# ============================================================
# v2.0: 地面 Shader 设置（脉冲网格）
# ============================================================

func _setup_ground() -> void:
	if not _ground:
		return

	# 创建大型 Sprite2D 作为地面载体
	_ground_sprite = Sprite2D.new()
	_ground_sprite.name = "GroundGrid"

	# 使用纯白纹理，让 Shader 完全控制颜色
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_ground_sprite.texture = tex
	_ground_sprite.scale = ARENA_SIZE  # 覆盖整个竞技场

	# 应用脉冲网格 Shader
	var shader = load("res://shaders/pulsing_grid.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("grid_color", Color(0.0, 1.0, 0.8, 1.0))
		mat.set_shader_parameter("grid_color_secondary", Color(0.0, 0.4, 0.8, 1.0))
		mat.set_shader_parameter("cell_size", 64.0)
		mat.set_shader_parameter("beat_energy", 0.0)
		mat.set_shader_parameter("time", 0.0)
		mat.set_shader_parameter("player_position", ARENA_CENTER)
		_ground_sprite.material = mat

	_ground_sprite.position = ARENA_CENTER
	_ground.add_child(_ground_sprite)

func _update_ground_shader() -> void:
	if _ground_sprite and _ground_sprite.material is ShaderMaterial:
		var mat: ShaderMaterial = _ground_sprite.material
		mat.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
		if _player:
			mat.set_shader_parameter("player_position", _player.position - ARENA_CENTER)

# ============================================================
# v2.0: 2.5D 渲染桥接层设置
# ============================================================

func _setup_render_bridge() -> void:
	if not _render_bridge:
		return

	# 设置摄像机跟随玩家
	if _player and _render_bridge.has_method("set_follow_target"):
		_render_bridge.set_follow_target(_player)

	# 为玩家创建 3D 渲染代理
	if _player and _render_bridge.has_method("create_player_proxy"):
		_render_bridge.create_player_proxy(_player)

	_log("2.5D 渲染桥接层已初始化")

## 连接节拍信号到 3D 渲染层脉冲
func _connect_beat_signal() -> void:
	if GameManager.has_signal("beat_tick"):
		if not GameManager.beat_tick.is_connected(_on_beat_tick_3d):
			GameManager.beat_tick.connect(_on_beat_tick_3d)

## 节拍信号回调 → 3D 渲染层脉冲
func _on_beat_tick_3d(beat_index: int) -> void:
	if _render_bridge and _render_bridge.has_method("on_beat_pulse"):
		_render_bridge.on_beat_pulse(beat_index)

## 将弹幕数据同步到 3D 渲染层
func _sync_projectiles_to_3d() -> void:
	if not _render_bridge or not _projectile_manager:
		return
	if not _render_bridge.has_method("sync_projectiles"):
		return
	if not _projectile_manager.has_method("get_projectile_render_data"):
		return

	var render_data = _projectile_manager.get_projectile_render_data()
	_render_bridge.sync_projectiles(render_data)

## 为敌人注册 3D 渲染代理
func _register_enemy_3d(enemy: Node2D, enemy_type: String) -> void:
	if not _render_bridge:
		return

	var color: Color = ENEMY_COLORS.get(enemy_type, Color(0.9, 0.3, 0.6))
	var is_elite: bool = enemy_type in ELITE_TYPES

	if is_elite:
		# 精英敌人：创建独立的 3D 代理（带光源 + 几何体）
		if _render_bridge.has_method("register_enemy_proxy"):
			_render_bridge.register_enemy_proxy(enemy, color, true)
	else:
		# 普通敌人：注册到 MultiMesh 批量渲染
		if _render_bridge.has_method("register_normal_enemy"):
			_render_bridge.register_normal_enemy(enemy, color)

	enemy.set_meta("registered_3d", true)

## 移除敌人 3D 代理
func _unregister_enemy_3d(enemy: Node2D) -> void:
	if not _render_bridge:
		return
	if _render_bridge.has_method("unregister_enemy_proxy"):
		_render_bridge.unregister_enemy_proxy(enemy)

# ============================================================
# v2.0: 章节视觉切换（测试用）
# ============================================================

## 循环切换章节视觉主题
func _cycle_chapter_visual() -> void:
	_current_test_chapter = (_current_test_chapter + 1) % MAX_CHAPTERS
	var chapter_names := [
		"毕达哥拉斯学派", "中世纪教堂", "巴洛克宫廷",
		"洛可可沙龙", "浪漫主义音乐厅", "爵士俱乐部", "数字空间"
	]
	var chapter_name: String = chapter_names[_current_test_chapter] if _current_test_chapter < chapter_names.size() else "未知"

	# 通知 ChapterManager 切换章节（如果可用）
	if _chapter_manager and _chapter_manager.has_method("force_chapter"):
		_chapter_manager.force_chapter(_current_test_chapter)
	elif _chapter_manager and _chapter_manager.has_signal("chapter_started"):
		_chapter_manager.chapter_started.emit(_current_test_chapter, chapter_name)

	# 更新 3D 渲染层的章节视觉
	if _render_bridge and _render_bridge.has_method("update_player_light_color"):
		var chapter_colors := [
			Color(0.0, 1.0, 0.8),   # Ch1: 青色
			Color(0.8, 0.6, 1.0),   # Ch2: 紫色
			Color(1.0, 0.85, 0.0),  # Ch3: 金色
			Color(1.0, 0.6, 0.8),   # Ch4: 粉色
			Color(0.9, 0.3, 0.3),   # Ch5: 红色
			Color(0.0, 0.5, 1.0),   # Ch6: 蓝色
			Color(0.0, 1.0, 0.5),   # Ch7: 绿色
		]
		if _current_test_chapter < chapter_colors.size():
			_render_bridge.update_player_light_color(chapter_colors[_current_test_chapter])

	_log("章节视觉切换: 第 %d 章 — %s" % [_current_test_chapter + 1, chapter_name])

## 切换 3D 渲染层开关
func _toggle_3d_layer() -> void:
	if _render_bridge and "enable_3d_layer" in _render_bridge:
		_render_bridge.enable_3d_layer = !_render_bridge.enable_3d_layer
		_log("3D 渲染层: %s" % ("开启" if _render_bridge.enable_3d_layer else "关闭"))

# ============================================================
# v2.0: 敌人击杀特效
# ============================================================

func _on_enemy_killed_vfx(pos: Vector2, enemy_type: String = "static") -> void:
	# 在 3D 层生成死亡爆发粒子
	if _render_bridge and _render_bridge.has_method("spawn_burst_particles"):
		var color: Color = ENEMY_COLORS.get(enemy_type, Color(0.9, 0.3, 0.6))
		_render_bridge.spawn_burst_particles(pos, color, 24)

	# 2D 死亡特效
	if _death_vfx_manager and _death_vfx_manager.has_method("spawn_death_vfx"):
		_death_vfx_manager.spawn_death_vfx(pos, enemy_type)

# ============================================================
# ★ SpellcraftSystem 信号连接与法术追踪
# ============================================================

func _connect_spell_signals() -> void:
	# 连接法术施放信号以追踪 DPS
	if SpellcraftSystem:
		if not SpellcraftSystem.spell_cast.is_connected(_on_spellcraft_spell_cast):
			SpellcraftSystem.spell_cast.connect(_on_spellcraft_spell_cast)
		if not SpellcraftSystem.chord_cast.is_connected(_on_spellcraft_chord_cast):
			SpellcraftSystem.chord_cast.connect(_on_spellcraft_chord_cast)
		if not SpellcraftSystem.spell_blocked_by_silence.is_connected(_on_spell_blocked):
			SpellcraftSystem.spell_blocked_by_silence.connect(_on_spell_blocked)
		if not SpellcraftSystem.rhythm_pattern_changed.is_connected(_on_rhythm_changed):
			SpellcraftSystem.rhythm_pattern_changed.connect(_on_rhythm_changed)
		if not SpellcraftSystem.progression_resolved.is_connected(_on_progression_resolved):
			SpellcraftSystem.progression_resolved.connect(_on_progression_resolved)
		if not SpellcraftSystem.timbre_changed.is_connected(_on_timbre_changed):
			SpellcraftSystem.timbre_changed.connect(_on_timbre_changed)

func _on_spellcraft_spell_cast(spell_data: Dictionary) -> void:
	var note = spell_data.get("note", -1)
	var modifier = spell_data.get("modifier", -1)
	var damage = spell_data.get("damage", 0.0)
	var note_name := _get_white_key_name(note)
	var mod_name := _get_modifier_name(modifier)
	var rhythm_name := _get_rhythm_name(spell_data.get("rhythm_pattern", -1))

	var msg := "施放音符: %s | 伤害: %.1f" % [note_name, damage]
	if modifier >= 0:
		msg += " | 修饰符: %s" % mod_name
	if not rhythm_name.is_empty():
		msg += " | 节奏型: %s" % rhythm_name
	if spell_data.get("is_crit", false):
		msg += " | ★暴击★"
	_log(msg)

func _on_spellcraft_chord_cast(chord_data: Dictionary) -> void:
	var spell_name = chord_data.get("spell_name", "未知")
	var damage = chord_data.get("damage", 0.0)
	var dissonance = chord_data.get("dissonance", 0.0)
	var msg := "施放和弦: %s | 伤害: %.1f | 不和谐度: %.1f" % [spell_name, damage, dissonance]
	if chord_data.has("progression"):
		msg += " | 和弦进行触发!"
	_log(msg)

func _on_spell_blocked(note: int) -> void:
	_log("⚠ 音符 %s 被寂静封锁!" % _get_white_key_name(note))

func _on_rhythm_changed(pattern) -> void:
	_log("节奏型变更: %s" % _get_rhythm_name(pattern))

func _on_progression_resolved(progression: Dictionary) -> void:
	var effect_type: String = progression.get("effect", {}).get("type", "")
	_log("★ 和弦进行解决: %s (效果: %s)" % [progression.get("name", ""), effect_type])

func _on_timbre_changed(timbre) -> void:
	var timbre_info := SpellcraftSystem.get_timbre_info(timbre)
	_log("音色切换: %s" % timbre_info.get("name", "未知"))

# ============================================================
# ★ 法术快速测试接口（通过 SpellcraftSystem 实际机制）
# ============================================================

## 快速施放单音符（通过 SpellcraftSystem 序列器）
func test_cast_note(white_key: int) -> void:
	if not SpellcraftSystem:
		_log("SpellcraftSystem 不可用")
		return

	# 直接构造 spell_data 并通过 SpellcraftSystem 的信号链施放
	var stats := GameManager.get_note_effective_stats(white_key)
	var fatigue := FatigueManager.query_fatigue()
	var damage_mult: float = fatigue.get("penalty", {}).get("damage_multiplier", 1.0)
	var meta_dmg_mult := SaveManager.get_damage_multiplier()
	var meta_spd_mult := SaveManager.get_speed_multiplier()
	var mode_dmg_mult := ModeSystem.get_damage_multiplier()
	var timbre := SpellcraftSystem.get_current_timbre()
	var timbre_data: Dictionary = MusicData.TIMBRE_ADSR.get(timbre, {})
	var timbre_fatigue_mult: float = MusicData.TIMBRE_FATIGUE_PENALTY.get(
		FatigueManager.current_level, 1.0
	)

	var base_damage: float = stats["dmg"] * MusicData.PARAM_CONVERSION["dmg_per_point"] * damage_mult * timbre_fatigue_mult * meta_dmg_mult * mode_dmg_mult

	var spell_data := {
		"type": "note",
		"note": white_key,
		"stats": stats,
		"damage": base_damage,
		"speed": stats["spd"] * MusicData.PARAM_CONVERSION["spd_per_point"] * meta_spd_mult,
		"duration": stats["dur"] * MusicData.PARAM_CONVERSION["dur_per_point"],
		"size": stats["size"] * MusicData.PARAM_CONVERSION["size_per_point"],
		"color": MusicData.NOTE_COLORS.get(white_key, Color.WHITE),
		"modifier": -1,
		"timbre": timbre,
		"timbre_name": timbre_data.get("name", "合成器"),
		"is_rapid_fire": false,
		"rapid_fire_count": 1,
		"has_knockback": false,
		"dodge_back": false,
		"accuracy_offset": 0.0,
	}

	# 记录疲劳事件（与实际游戏一致）
	FatigueManager.record_spell({
		"time": GameManager.game_time,
		"note": white_key,
		"is_chord": false,
	})

	# 通过 SpellcraftSystem 的信号链发射
	SpellcraftSystem.spell_cast.emit(spell_data)
	_log("测试施放: %s (DMG=%.1f, SPD=%.0f)" % [_get_white_key_name(white_key), base_damage, spell_data["speed"]])

## 快速施放带修饰符的音符
func test_cast_note_with_modifier(white_key: int, modifier: int) -> void:
	if not SpellcraftSystem:
		return

	var stats := GameManager.get_note_effective_stats(white_key)
	var fatigue := FatigueManager.query_fatigue()
	var damage_mult: float = fatigue.get("penalty", {}).get("damage_multiplier", 1.0)
	var meta_dmg_mult := SaveManager.get_damage_multiplier()
	var meta_spd_mult := SaveManager.get_speed_multiplier()
	var mode_dmg_mult := ModeSystem.get_damage_multiplier()
	var timbre := SpellcraftSystem.get_current_timbre()
	var timbre_data: Dictionary = MusicData.TIMBRE_ADSR.get(timbre, {})
	var timbre_fatigue_mult: float = MusicData.TIMBRE_FATIGUE_PENALTY.get(
		FatigueManager.current_level, 1.0
	)

	var base_damage: float = stats["dmg"] * MusicData.PARAM_CONVERSION["dmg_per_point"] * damage_mult * timbre_fatigue_mult * meta_dmg_mult * mode_dmg_mult

	var spell_data := {
		"type": "note",
		"note": white_key,
		"stats": stats,
		"damage": base_damage,
		"speed": stats["spd"] * MusicData.PARAM_CONVERSION["spd_per_point"] * meta_spd_mult,
		"duration": stats["dur"] * MusicData.PARAM_CONVERSION["dur_per_point"],
		"size": stats["size"] * MusicData.PARAM_CONVERSION["size_per_point"],
		"color": MusicData.NOTE_COLORS.get(white_key, Color.WHITE),
		"modifier": modifier,
		"timbre": timbre,
		"timbre_name": timbre_data.get("name", "合成器"),
		"is_rapid_fire": false,
		"rapid_fire_count": 1,
		"has_knockback": false,
		"dodge_back": false,
		"accuracy_offset": 0.0,
	}

	FatigueManager.record_spell({
		"time": GameManager.game_time,
		"note": white_key,
		"is_chord": false,
	})

	SpellcraftSystem.spell_cast.emit(spell_data)
	_log("测试施放: %s + %s" % [_get_white_key_name(white_key), _get_modifier_name(modifier)])

## 快速施放和弦法术（通过 MusicTheoryEngine 识别 + SpellcraftSystem 信号链）
func test_cast_chord(chord_type: int) -> void:
	if not SpellcraftSystem:
		return

	var spell_info = MusicData.CHORD_SPELL_MAP.get(chord_type, {})
	if spell_info.is_empty():
		_log("未知和弦类型: %d" % chord_type)
		return

	# 使用 C 为根音构建和弦音符
	var intervals: Array = MusicData.CHORD_INTERVALS.get(chord_type, [])
	var chord_notes: Array = []
	for interval in intervals:
		chord_notes.append(interval)  # C=0 为根音

	# 通过 MusicTheoryEngine 识别和弦（与实际游戏流程一致）
	var chord_result = MusicTheoryEngine.identify_chord(chord_notes)
	if chord_result == null:
		_log("和弦识别失败: %s" % spell_info.get("name", ""))
		return

	# 计算和弦伤害（基于根音 C）
	var root_stats := GameManager.get_note_effective_stats(MusicData.WhiteKey.C)
	var fatigue := FatigueManager.query_fatigue()
	var damage_mult: float = fatigue.get("penalty", {}).get("damage_multiplier", 1.0)
	var chord_multiplier: float = spell_info.get("multiplier", 1.0)
	var timbre := SpellcraftSystem.get_current_timbre()
	var timbre_data: Dictionary = MusicData.TIMBRE_ADSR.get(timbre, {})
	var timbre_fatigue_mult: float = MusicData.TIMBRE_FATIGUE_PENALTY.get(
		FatigueManager.current_level, 1.0
	)

	var base_damage: float = root_stats["dmg"] * MusicData.PARAM_CONVERSION["dmg_per_point"] * chord_multiplier * damage_mult * timbre_fatigue_mult

	# 不和谐度处理（与实际游戏一致）
	var raw_dissonance = MusicTheoryEngine.get_chord_dissonance(chord_type)
	var dissonance = raw_dissonance * ModeSystem.get_dissonance_multiplier()
	if dissonance > 2.0:
		GameManager.apply_dissonance_damage(dissonance)
		ModeSystem.on_dissonance_applied(dissonance)
		FatigueManager.reduce_monotony_from_dissonance(dissonance)

	# 扩展和弦额外疲劳
	var extra_fatigue: float = MusicData.EXTENDED_CHORD_FATIGUE.get(chord_type, 0.0)
	if extra_fatigue > 0.0:
		FatigueManager.add_external_fatigue(extra_fatigue)

	var chord_data := {
		"type": "chord",
		"chord_type": chord_type,
		"spell_form": spell_info["form"],
		"spell_name": spell_info["name"],
		"damage": base_damage,
		"dissonance": dissonance,
		"extra_fatigue": extra_fatigue,
		"modifier": -1,
		"timbre": timbre,
		"timbre_name": timbre_data.get("name", "合成器"),
		"accuracy_offset": 0.0,
	}

	# 记录疲劳事件
	FatigueManager.record_spell({
		"time": GameManager.game_time,
		"note": 0,  # C 根音
		"is_chord": true,
		"chord_type": chord_type,
	})

	# 通过 SpellcraftSystem 的信号链发射
	SpellcraftSystem.chord_cast.emit(chord_data)
	_log("测试施放和弦: %s (DMG=%.1f, 不和谐=%.1f)" % [spell_info["name"], base_damage, dissonance])

## 快速设置序列器（通过 SpellcraftSystem 的实际接口）
func test_set_sequencer_pattern(pattern: Array) -> void:
	if not SpellcraftSystem:
		return

	# 先清空序列器
	SpellcraftSystem.clear_sequencer()

	# 按照 pattern 设置序列器
	# pattern 格式: [{"type": "note", "note": WhiteKey}, {"type": "rest"}, ...]
	for i in range(min(pattern.size(), SpellcraftSystem.SEQUENCER_LENGTH)):
		var slot: Dictionary = pattern[i]
		match slot.get("type", "rest"):
			"note":
				var white_key: int = slot.get("note", MusicData.WhiteKey.C)
				SpellcraftSystem.set_sequencer_note(i, white_key)
			"chord":
				var measure: int = i / SpellcraftSystem.BEATS_PER_MEASURE
				var chord_notes: Array = slot.get("chord_notes", [])
				SpellcraftSystem.set_sequencer_chord_raw(measure, chord_notes)
			"rest":
				pass  # 默认就是休止符

	_log("序列器已配置: %d 个槽位" % pattern.size())

## 快速设置手动施法槽（通过 SpellcraftSystem 的实际接口）
func test_set_manual_slot(slot_index: int, spell_data: Dictionary) -> void:
	if not SpellcraftSystem:
		return
	SpellcraftSystem.set_manual_slot(slot_index, spell_data)
	_log("手动施法槽 %d 已配置" % slot_index)

## 触发手动施法（通过 SpellcraftSystem 的实际接口）
func test_trigger_manual_cast(slot_index: int) -> void:
	if not SpellcraftSystem:
		return
	SpellcraftSystem.trigger_manual_cast(slot_index)

## 切换音色（通过 SpellcraftSystem 的实际接口）
func test_set_timbre(timbre: int) -> void:
	if not SpellcraftSystem:
		return
	SpellcraftSystem.set_timbre(timbre)

## 切换调式（通过 ModeSystem 的实际接口）
func test_set_mode(mode_id: String) -> void:
	if ModeSystem and ModeSystem.has_method("apply_mode"):
		ModeSystem.apply_mode(mode_id)
		_log("调式切换: %s" % mode_id)

## 自动施法逻辑：循环施放所有可用白键音符
var _auto_fire_note_index: int = 0
func _auto_fire_cast() -> void:
	var available_keys: Array = ModeSystem.available_white_keys if ModeSystem else [
		MusicData.WhiteKey.C, MusicData.WhiteKey.D, MusicData.WhiteKey.E,
		MusicData.WhiteKey.F, MusicData.WhiteKey.G, MusicData.WhiteKey.A,
		MusicData.WhiteKey.B,
	]
	if available_keys.is_empty():
		return
	_auto_fire_note_index = _auto_fire_note_index % available_keys.size()
	test_cast_note(available_keys[_auto_fire_note_index])
	_auto_fire_note_index += 1

# ============================================================
# ★ 法术预设（方便快速测试特定组合）
# ============================================================

## 预设：全音符连射序列器
func preset_full_note_sequencer() -> void:
	var pattern: Array = []
	var keys := [MusicData.WhiteKey.C, MusicData.WhiteKey.D, MusicData.WhiteKey.E, MusicData.WhiteKey.F,
				 MusicData.WhiteKey.G, MusicData.WhiteKey.A, MusicData.WhiteKey.B, MusicData.WhiteKey.C,
				 MusicData.WhiteKey.G, MusicData.WhiteKey.E, MusicData.WhiteKey.C, MusicData.WhiteKey.G,
				 MusicData.WhiteKey.A, MusicData.WhiteKey.B, MusicData.WhiteKey.D, MusicData.WhiteKey.F]
	for i in range(SpellcraftSystem.SEQUENCER_LENGTH):
		pattern.append({"type": "note", "note": keys[i % keys.size()]})
	test_set_sequencer_pattern(pattern)
	_log("预设: 全音符连射序列器")

## 预设：蓄力序列器（交替音符和休止符）
func preset_charged_sequencer() -> void:
	var pattern: Array = []
	for i in range(SpellcraftSystem.SEQUENCER_LENGTH):
		if i % 2 == 0:
			pattern.append({"type": "note", "note": MusicData.WhiteKey.G})
		else:
			pattern.append({"type": "rest"})
	test_set_sequencer_pattern(pattern)
	_log("预设: 蓄力序列器 (G + 休止符交替)")

## 预设：所有基础和弦依次施放
func preset_all_basic_chords() -> void:
	var chord_types := [
		MusicData.ChordType.MAJOR, MusicData.ChordType.MINOR,
		MusicData.ChordType.AUGMENTED, MusicData.ChordType.DIMINISHED,
		MusicData.ChordType.SUSPENDED,
	]
	for chord_type in chord_types:
		test_cast_chord(chord_type)
		await get_tree().create_timer(0.5).timeout
	_log("预设: 所有基础和弦已施放")

## 预设：所有七和弦依次施放
func preset_all_seventh_chords() -> void:
	var chord_types := [
		MusicData.ChordType.DOMINANT_7, MusicData.ChordType.DIMINISHED_7,
		MusicData.ChordType.MAJOR_7, MusicData.ChordType.MINOR_7,
	]
	for chord_type in chord_types:
		test_cast_chord(chord_type)
		await get_tree().create_timer(0.5).timeout
	_log("预设: 所有七和弦已施放")

## 预设：所有修饰符测试（G 音符 + 每种修饰符）
func preset_all_modifiers() -> void:
	var modifiers := [
		MusicData.ModifierEffect.PIERCE, MusicData.ModifierEffect.HOMING,
		MusicData.ModifierEffect.SPLIT, MusicData.ModifierEffect.ECHO,
		MusicData.ModifierEffect.SCATTER,
	]
	for mod in modifiers:
		test_cast_note_with_modifier(MusicData.WhiteKey.G, mod)
		await get_tree().create_timer(0.3).timeout
	_log("预设: 所有修饰符已测试")

# ============================================================
# 敌人生成
# ============================================================

## 生成指定类型的敌人
func spawn_enemy(enemy_type: String, count: int = 1, position_mode: String = "random") -> void:
	if not ENEMY_SCENES.has(enemy_type):
		_log("未知敌人类型: %s" % enemy_type)
		return

	var scene: PackedScene = load(ENEMY_SCENES[enemy_type])
	if not scene:
		_log("无法加载敌人场景: %s" % enemy_type)
		return

	for i in range(count):
		var enemy := scene.instantiate()
		var spawn_pos := _get_spawn_position(position_mode, i, count)
		enemy.position = spawn_pos

		# 连接死亡信号
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(_on_enemy_died)

		_enemy_container.add_child(enemy)
		_spawned_count += 1

		# v2.0: 注册敌人 3D 渲染代理
		_register_enemy_3d(enemy, enemy_type)

	_log("已生成 %d 个 [%s]，位置模式: %s" % [count, enemy_type, position_mode])

## 获取生成位置
func _get_spawn_position(mode: String, index: int, total: int) -> Vector2:
	match mode:
		"random":
			return Vector2(
				randf_range(200, ARENA_SIZE.x - 200),
				randf_range(200, ARENA_SIZE.y - 200)
			)
		"circle":
			var angle := (TAU / total) * index
			var radius := 400.0
			return ARENA_CENTER + Vector2(cos(angle), sin(angle)) * radius
		"line":
			var start_x := ARENA_CENTER.x - (total * 60) / 2.0
			return Vector2(start_x + index * 60, ARENA_CENTER.y - 300)
		"grid":
			var cols := ceili(sqrt(total))
			var row := index / cols
			var col := index % cols
			var start := ARENA_CENTER - Vector2(cols * 60, (total / cols) * 60) / 2.0
			return start + Vector2(col * 60, row * 60)
		"player_front":
			if _player:
				var offset := Vector2(randf_range(-100, 100), -200 - randf_range(0, 200))
				return _player.position + offset
			return ARENA_CENTER
		_:
			return ARENA_CENTER + Vector2(randf_range(-300, 300), randf_range(-300, 300))

## 预设波次
func spawn_wave_preset(preset_name: String) -> void:
	_spawn_wave_preset(preset_name)

func _spawn_wave_preset(preset_name: String) -> void:
	match preset_name:
		"mixed_basic":
			spawn_enemy("static", 10, "circle")
			spawn_enemy("silence", 2, "random")
			spawn_enemy("screech", 3, "random")
			_log("预设波次: 基础混合")
		"static_swarm":
			spawn_enemy("static", 30, "circle")
			_log("预设波次: 底噪蜂群 (30)")
		"elite_test":
			spawn_enemy("pulse", 3, "line")
			spawn_enemy("wall", 1, "player_front")
			_log("预设波次: 精英测试")
		"stress_test":
			spawn_enemy("static", 50, "random")
			spawn_enemy("screech", 10, "random")
			spawn_enemy("pulse", 5, "random")
			spawn_enemy("wall", 3, "random")
			spawn_enemy("silence", 5, "random")
			_log("预设波次: 压力测试 (73 敌人)")
		"dps_dummy":
			# 生成一个高HP的音墙作为DPS木桩
			spawn_enemy("wall", 1, "player_front")
			_log("预设波次: DPS 木桩")
		_:
			_log("未知预设: %s" % preset_name)

## 清除所有敌人
func _clear_all_enemies() -> void:
	var count := _enemy_container.get_child_count()
	for child in _enemy_container.get_children():
		# v2.0: 移除 3D 代理
		_unregister_enemy_3d(child)
		child.queue_free()
	_log("已清除 %d 个敌人" % count)

## 获取当前敌人数量
func get_enemy_count() -> int:
	return _enemy_container.get_child_count()

# ============================================================
# 碰撞检测
# ============================================================

func _check_collisions() -> void:
	if _projectile_manager == null:
		return

	# 获取敌人碰撞数据
	var enemy_data = _get_enemy_collision_data()
	if enemy_data.is_empty():
		return

	# 检测弹体-敌人碰撞
	var hits = _projectile_manager.check_collisions(enemy_data)

	# 处理命中
	for hit in hits:
		var enemy_node = hit["enemy"].get("node")
		if enemy_node and is_instance_valid(enemy_node) and enemy_node.has_method("take_damage"):
			var knockback_dir := Vector2.ZERO
			var proj = hit["projectile"]
			if proj.get("velocity", Vector2.ZERO) != Vector2.ZERO:
				knockback_dir = proj["velocity"].normalized()

			enemy_node.take_damage(hit["damage"], knockback_dir)

			# 记录伤害到 DPS 统计
			record_damage(hit["damage"], "spell")

			# 显示伤害数字
			if _hud and _hud.has_method("show_damage_number"):
				_hud.show_damage_number(hit["position"], hit["damage"])

			# v2.0: 显示伤害数字（通过 DamageNumberManager）
			if _damage_number_manager and _damage_number_manager.has_method("spawn_damage_number"):
				_damage_number_manager.spawn_damage_number(hit["position"], hit["damage"])

func _get_enemy_collision_data() -> Array:
	var data: Array = []
	for enemy in _enemy_container.get_children():
		if is_instance_valid(enemy) and enemy.has_method("get_collision_data"):
			data.append(enemy.get_collision_data())
	return data

# ============================================================
# DPS 统计
# ============================================================

## 记录伤害（由弹体系统调用）
func record_damage(damage: float, source: String = "spell") -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_dps_tracker["total_damage"] += damage
	_dps_tracker["damage_log"].append({
		"time": now,
		"damage": damage,
		"source": source,
	})
	_dps_tracker["window_damage"] += damage

## 更新 DPS 滑动窗口（5秒）
func _update_dps_window() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var window := 5.0

	# 移除超出窗口的记录
	var log: Array = _dps_tracker["damage_log"]
	while not log.is_empty() and log[0]["time"] < now - window:
		_dps_tracker["window_damage"] -= log[0]["damage"]
		log.pop_front()

	# 计算当前 DPS
	var elapsed = now - _dps_tracker.get("window_start", now)
	if elapsed > 0.1:
		_dps_tracker["current_dps"] = _dps_tracker["window_damage"] / min(elapsed, window)
	else:
		_dps_tracker["current_dps"] = 0.0

	# 更新峰值
	if _dps_tracker["current_dps"] > _dps_tracker["peak_dps"]:
		_dps_tracker["peak_dps"] = _dps_tracker["current_dps"]

## 获取 DPS 统计
func get_dps_stats() -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	var session_time = now - _dps_tracker["session_start"]
	var avg_dps = _dps_tracker["total_damage"] / max(session_time, 0.1)
	return {
		"current_dps": _dps_tracker["current_dps"],
		"peak_dps": _dps_tracker["peak_dps"],
		"average_dps": avg_dps,
		"total_damage": _dps_tracker["total_damage"],
		"session_time": session_time,
	}

## 重置 DPS 统计
func _reset_dps() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_dps_tracker = {
		"total_damage": 0.0,
		"session_start": now,
		"damage_log": [],
		"window_damage": 0.0,
		"window_start": now,
		"current_dps": 0.0,
		"peak_dps": 0.0,
	}
	_killed_count = 0
	_log("DPS 统计已重置")

# ============================================================
# 玩家属性调整
# ============================================================

## 设置玩家属性（由调试面板调用）
func set_player_stat(stat: String, value: float) -> void:
	if not _player:
		return

	match stat:
		"max_hp":
			GameManager.player_max_hp = value
			GameManager.player_current_hp = min(GameManager.player_current_hp, value)
			GameManager.player_hp_changed.emit(GameManager.player_current_hp, GameManager.player_max_hp)
			_log("玩家最大 HP: %.0f" % value)
		"move_speed":
			if "move_speed" in _player:
				_player.move_speed = value
			_log("玩家移速: %.0f" % value)
		"damage_multiplier":
			if GameManager and "damage_multiplier" in GameManager:
				GameManager.damage_multiplier = value
			_log("伤害倍率: %.2fx" % value)
		"pickup_range":
			if "pickup_range" in _player:
				_player.pickup_range = value
			_log("拾取范围: %.0f" % value)

## 设置 BPM（通过 GameManager 的实际接口）
func set_bpm(bpm: float) -> void:
	if GameManager:
		GameManager.current_bpm = bpm
		_log("BPM: %.0f" % bpm)

## 设置调式（通过 ModeSystem 的实际接口）
func set_mode(mode_id: String) -> void:
	test_set_mode(mode_id)

## 设置玩家等级
func set_player_level(level: int) -> void:
	if GameManager:
		GameManager.player_level = level
		_log("玩家等级: %d" % level)

# ============================================================
# ★ 系统状态查询（用于调试面板显示）
# ============================================================

## 获取当前法术系统状态
func get_spell_system_state() -> Dictionary:
	var state := {}
	if SpellcraftSystem:
		state["sequencer"] = SpellcraftSystem.get_sequencer_data()
		state["sequencer_position"] = SpellcraftSystem.get_sequencer_position()
		state["manual_slots"] = SpellcraftSystem.manual_cast_slots.duplicate(true)
		state["current_timbre"] = SpellcraftSystem.get_current_timbre()
	if FatigueManager:
		state["fatigue"] = FatigueManager.query_fatigue()
		state["fatigue_level"] = FatigueManager.current_level
	if ModeSystem:
		state["current_mode"] = ModeSystem.current_mode_id if "current_mode_id" in ModeSystem else "ionian"
	return state

## 获取当前弹体统计
func get_projectile_stats() -> Dictionary:
	if _projectile_manager and _projectile_manager.has_method("get_active_count"):
		return {
			"active_projectiles": _projectile_manager.get_active_count(),
			"collision_stats": _projectile_manager.get_collision_stats() if _projectile_manager.has_method("get_collision_stats") else {},
		}
	return {}

# ============================================================
# 绘制辅助
# ============================================================

func _draw_arena_grid() -> void:
	# 网格线
	for x in range(0, int(ARENA_SIZE.x), int(GRID_SIZE)):
		var color := GRID_ACCENT if x % (int(GRID_SIZE) * 5) == 0 else GRID_COLOR
		draw_line(Vector2(x, 0), Vector2(x, ARENA_SIZE.y), color, 1.0)
	for y in range(0, int(ARENA_SIZE.y), int(GRID_SIZE)):
		var color := GRID_ACCENT if y % (int(GRID_SIZE) * 5) == 0 else GRID_COLOR
		draw_line(Vector2(0, y), Vector2(ARENA_SIZE.x, y), color, 1.0)

	# 中心十字
	draw_line(ARENA_CENTER - Vector2(50, 0), ARENA_CENTER + Vector2(50, 0), BORDER_COLOR * 0.5, 2.0)
	draw_line(ARENA_CENTER - Vector2(0, 50), ARENA_CENTER + Vector2(0, 50), BORDER_COLOR * 0.5, 2.0)

func _draw_arena_border() -> void:
	var rect := Rect2(Vector2.ZERO, ARENA_SIZE)
	draw_rect(rect, BORDER_COLOR, false, 3.0)

	# 角落装饰
	var corner_size := 30.0
	var corners := [
		Vector2.ZERO, Vector2(ARENA_SIZE.x, 0),
		Vector2(0, ARENA_SIZE.y), ARENA_SIZE
	]
	for c in corners:
		draw_circle(c, corner_size * 0.3, BORDER_COLOR * 0.6)

func _draw_hitboxes() -> void:
	# 绘制玩家碰撞箱
	if _player:
		draw_circle(_player.position, 12.0, Color(0.0, 1.0, 0.5, 0.3))

	# 绘制敌人碰撞箱
	for enemy in _enemy_container.get_children():
		if "collision_radius" in enemy:
			draw_circle(enemy.position, enemy.collision_radius, Color(1.0, 0.3, 0.3, 0.3))
		else:
			draw_circle(enemy.position, 16.0, Color(1.0, 0.3, 0.3, 0.3))

# ============================================================
# 信号回调
# ============================================================

func _on_enemy_died(pos: Vector2, xp_value: int, enemy_type: String) -> void:
	_killed_count += 1
	if CodexManager:
		CodexManager.on_enemy_died(pos, xp_value, enemy_type)

# ============================================================
# 名称工具函数
# ============================================================

func _get_white_key_name(key: int) -> String:
	var key_stats: Dictionary = MusicData.WHITE_KEY_STATS.get(key, {})
	return key_stats.get("name", "?") if not key_stats.is_empty() else "?"

func _get_modifier_name(mod: int) -> String:
	match mod:
		MusicData.ModifierEffect.PIERCE: return "锐化(穿透)"
		MusicData.ModifierEffect.HOMING: return "追踪"
		MusicData.ModifierEffect.SPLIT: return "分裂"
		MusicData.ModifierEffect.ECHO: return "回响"
		MusicData.ModifierEffect.SCATTER: return "散射"
		_: return ""

func _get_rhythm_name(rhythm) -> String:
	var rhythm_data: Dictionary = MusicData.RHYTHM_MODIFIERS.get(rhythm, {})
	return rhythm_data.get("name", "") if not rhythm_data.is_empty() else ""

# ============================================================
# 日志
# ============================================================

func _log(text: String) -> void:
	var timestamp := Time.get_time_string_from_system()
	var msg := "[%s] %s" % [timestamp, text]
	debug_message.emit(msg)
	print("[TestChamber] %s" % msg)

## 获取统计摘要
func get_stats_summary() -> Dictionary:
	var dps := get_dps_stats()
	var proj_stats := get_projectile_stats()
	return {
		"enemies_alive": get_enemy_count(),
		"enemies_spawned": _spawned_count,
		"enemies_killed": _killed_count,
		"current_dps": dps["current_dps"],
		"peak_dps": dps["peak_dps"],
		"total_damage": dps["total_damage"],
		"session_time": dps["session_time"],
		"god_mode": god_mode,
		"time_scale": time_scale,
		"active_projectiles": proj_stats.get("active_projectiles", 0),
		"auto_fire": auto_fire,
		"current_chapter": _current_test_chapter,
		"render_3d_enabled": _render_bridge.enable_3d_layer if _render_bridge and "enable_3d_layer" in _render_bridge else false,
	}

# ============================================================
# 返回主菜单
# ============================================================

func _return_to_menu() -> void:
	# 恢复时间缩放
	Engine.time_scale = 1.0
	time_scale = 1.0
	# 断开信号连接
	if SpellcraftSystem:
		if SpellcraftSystem.spell_cast.is_connected(_on_spellcraft_spell_cast):
			SpellcraftSystem.spell_cast.disconnect(_on_spellcraft_spell_cast)
		if SpellcraftSystem.chord_cast.is_connected(_on_spellcraft_chord_cast):
			SpellcraftSystem.chord_cast.disconnect(_on_spellcraft_chord_cast)
		if SpellcraftSystem.spell_blocked_by_silence.is_connected(_on_spell_blocked):
			SpellcraftSystem.spell_blocked_by_silence.disconnect(_on_spell_blocked)
		if SpellcraftSystem.rhythm_pattern_changed.is_connected(_on_rhythm_changed):
			SpellcraftSystem.rhythm_pattern_changed.disconnect(_on_rhythm_changed)
		if SpellcraftSystem.progression_resolved.is_connected(_on_progression_resolved):
			SpellcraftSystem.progression_resolved.disconnect(_on_progression_resolved)
		if SpellcraftSystem.timbre_changed.is_connected(_on_timbre_changed):
			SpellcraftSystem.timbre_changed.disconnect(_on_timbre_changed)
	# 断开节拍信号
	if GameManager.has_signal("beat_tick"):
		if GameManager.beat_tick.is_connected(_on_beat_tick_3d):
			GameManager.beat_tick.disconnect(_on_beat_tick_3d)
	# 断开敌人击杀信号
	if GameManager.enemy_killed.is_connected(_on_enemy_killed_vfx):
		GameManager.enemy_killed.disconnect(_on_enemy_killed_vfx)
	# 重置测试模式标记
	if GameManager:
		GameManager.is_test_mode = false
	_log("返回主菜单")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
