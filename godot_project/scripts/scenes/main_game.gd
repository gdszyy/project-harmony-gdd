## main_game.gd
## 主游戏场景 v5.0 — 统一游戏与测试环境 (v3.0 交互重构)
## 管理游戏循环、碰撞检测、场景组件协调
## 集成：ChapterManager、BossSpawner、SpellVisualManager、VfxManager、
##       DeathVfxManager、DamageNumberManager、SummonManager、RenderBridge3D
##       以及所有UI面板（NoteInventoryUI、IntegratedComposer、
##       CircleOfFifthsUpgradeV3、MetaProgressionVisualizer、
##       TimbreWheelUI、BossHPBar）
##
## v4.0 变更：
## - 统一游戏与测试环境：测试场不再是独立场景，而是主游戏 + 调试控制台叠加
## - 当 GameManager.is_test_mode == true 时，动态加载 DebugPanel + DPSOverlay
## - 暂停自动章节推进和敌人波次，由调试面板手动控制
## - 暴露调试公共接口（debug_*），供调试面板遥控
## - 保留 v3.0 的 2.5D 混合渲染方案
extends Node2D

# ============================================================
# 信号（调试模式使用）
# ============================================================
signal debug_message(text: String)

# ============================================================
# 节点引用 — 核心
# ============================================================
@onready var _player: CharacterBody2D = $Player
@onready var _enemy_spawner: Node2D = $EnemySpawner
@onready var _projectile_manager: Node2D = $ProjectileManager
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _ground: Node2D = $Ground
@onready var _hud: CanvasLayer = $HUD
@onready var _event_horizon: Node2D = $EventHorizon

# ============================================================
# 节点引用 — 系统管理器
# ============================================================
var _chapter_manager: Node = null  # P0 Fix #46: 使用 Autoload 单例
@onready var _boss_spawner: Node = $BossSpawner
@onready var _spell_visual_manager: Node2D = $SpellVisualManager
@onready var _death_vfx_manager: Node2D = $DeathVfxManager
@onready var _damage_number_manager: Node2D = $DamageNumberManager
@onready var _summon_manager: Node = $SummonManager
@onready var _vfx_manager: CanvasLayer = $VfxManager

# ============================================================
# 节点引用 — 2.5D 渲染桥接层 (v3.0 新增)
# ============================================================
@onready var _render_bridge: Node = $RenderBridge3D

# ============================================================
# 节点引用 — UI 面板 (v3.0 重构)
# ============================================================
@onready var _note_inventory_ui: Control = $HUD/NoteInventoryUI
@onready var _integrated_composer: Control = $HUD/IntegratedComposer  ## v3.0: 替代 SpellbookUI + ChordAlchemyPanel + ManualSlotConfig
@onready var _circle_of_fifths_v3: Control = $HUD/CircleOfFifthsUpgradeV3  ## v3.0: 替代旧版 CircleOfFifthsUpgrade
@onready var _meta_visualizer: Control = $HUD/MetaProgressionVisualizer  ## v3.0: 局外成长可视化
@onready var _timbre_wheel_ui: Control = $HUD/TimbreWheelUI
@onready var _boss_hp_bar: Control = $HUD/BossHPBar

# ============================================================
# 配置
# ============================================================
## 竞技场半径
@export var arena_radius: float = 1500.0
## 碰撞检测频率
const COLLISION_CHECK_INTERVAL: float = 0.033  # ~30Hz

# ============================================================
# 敌人场景路径（调试模式手动生成用）
# ============================================================
const ENEMY_SCENES: Dictionary = {
	"static":  "res://scenes/enemies/enemy_static.tscn",
	"silence": "res://scenes/enemies/enemy_silence.tscn",
	"screech": "res://scenes/enemies/enemy_screech.tscn",
	"pulse":   "res://scenes/enemies/enemy_pulse.tscn",
	"wall":    "res://scenes/enemies/enemy_wall.tscn",
}

# ============================================================
# 状态
# ============================================================
var _collision_timer: float = 0.0
## 游戏结束场景跳转延迟
var _game_over_timer: float = -1.0
const GAME_OVER_DELAY: float = 2.0

# ============================================================
# 调试模式状态 (v4.0)
# ============================================================
var _debug_panel: Node = null
var _dps_overlay: Node = null
var god_mode: bool = false
var infinite_fatigue: bool = false
var freeze_enemies: bool = false
var show_hitboxes: bool = false
var auto_fire: bool = false
var time_scale: float = 1.0
var _auto_fire_timer: float = 0.0
var _auto_fire_interval: float = 0.5
var _auto_fire_note_index: int = 0
var _current_test_chapter: int = 0
const MAX_CHAPTERS: int = 7

## DPS 统计
var _dps_tracker: Dictionary = {
	"total_damage": 0.0,
	"session_start": 0.0,
	"damage_log": [],
	"window_damage": 0.0,
	"window_start": 0.0,
	"current_dps": 0.0,
	"peak_dps": 0.0,
}
var _spawned_count: int = 0
var _killed_count: int = 0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# P0 Fix #46: 从 Autoload 获取 ChapterManager 单例
	_chapter_manager = get_node_or_null("/root/ChapterManager")
	if GameManager.is_test_mode:
		_enter_test_mode()
	else:
		_start_normal_game()

func _input(event: InputEvent) -> void:
	if GameManager.is_test_mode:
		_handle_test_mode_input(event)
	else:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game"):
			if GameManager.current_state == GameManager.GameState.PLAYING:
				GameManager.pause_game()
			elif GameManager.current_state == GameManager.GameState.PAUSED:
				GameManager.resume_game()

func _process(delta: float) -> void:
	if GameManager.is_test_mode:
		_process_test_mode(delta)
	else:
		_process_normal_game(delta)

# ============================================================
# 正常游戏流程
# ============================================================

func _start_normal_game() -> void:
	_setup_scene()
	_setup_render_bridge()
	_connect_system_signals()
	_start_chapter_system()
	GameManager.start_game()
	# v7.0: 应用角色/职业系统 (Issue #28)
	var class_mgr := get_node_or_null("CharacterClassManager")
	if class_mgr and class_mgr.has_method("apply_class"):
		class_mgr.apply_class()

	# Issue #115: 初始化新手引导系统
	var tutorial_mgr := get_node_or_null("/root/TutorialManager")
	if tutorial_mgr and tutorial_mgr.should_show_tutorial():
		tutorial_mgr.start_tutorial()

	# Issue #115: 初始化随机变异器系统
	var mutator_mgr := get_node_or_null("/root/MutatorManager")
	if mutator_mgr:
		mutator_mgr.roll_mutators()

	# Issue #115: 加载变异器 HUD
	var mutator_hud_script := load("res://scripts/ui/mutator_hud.gd")
	if mutator_hud_script:
		var mutator_hud := CanvasLayer.new()
		mutator_hud.name = "MutatorHUD"
		mutator_hud.set_script(mutator_hud_script)
		add_child(mutator_hud)

	# Issue #115: 加载里程碑 HUD
	var milestone_hud_script := load("res://scripts/ui/milestone_hud.gd")
	if milestone_hud_script:
		var milestone_hud := CanvasLayer.new()
		milestone_hud.name = "MilestoneHUD"
		milestone_hud.set_script(milestone_hud_script)
		add_child(milestone_hud)

func _process_normal_game(delta: float) -> void:
	# 游戏结束延迟跳转
	if _game_over_timer >= 0.0:
		_game_over_timer += delta
		if _game_over_timer >= GAME_OVER_DELAY:
			_game_over_timer = -1.0
			get_tree().change_scene_to_file("res://scenes/game_over.tscn")
		return

	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# 碰撞检测
	_collision_timer += delta
	if _collision_timer >= COLLISION_CHECK_INTERVAL:
		_collision_timer = 0.0
		_check_collisions()

	# 竞技场边界限制
	_enforce_arena_boundary()

	# 更新地面 Shader 参数
	_update_ground_shader()

	# 更新事件视界
	_update_event_horizon()

	# v3.0: 同步弹幕数据到 3D 渲染层
	_sync_projectiles_to_3d()

# ============================================================
# 测试模式 (v4.0)
# ============================================================

func _enter_test_mode() -> void:
	# 1. 基础场景设置（与正常游戏完全一致）
	_setup_scene()
	_setup_render_bridge()
	_connect_system_signals()

	# 2. 暂停自动进程系统（由调试面板手动控制）
	if _chapter_manager:
		_chapter_manager.set_process(false)
	if _enemy_spawner:
		_enemy_spawner.set_process(false)

	# 3. 启动游戏核心（玩家、节拍、BGM等）
	GameManager.start_game()

	# 4. 动态加载调试面板
	var debug_panel_script = load("res://scripts/ui/debug_panel.gd")
	if debug_panel_script:
		_debug_panel = CanvasLayer.new()
		_debug_panel.name = "DebugPanel"
		_debug_panel.set_script(debug_panel_script)
		add_child(_debug_panel)

	# 5. 动态加载 DPS 覆盖层
	var dps_overlay_script = load("res://scripts/ui/dps_overlay.gd")
	if dps_overlay_script:
		_dps_overlay = CanvasLayer.new()
		_dps_overlay.name = "DPSOverlay"
		_dps_overlay.set_script(dps_overlay_script)
		add_child(_dps_overlay)

	# 6. 初始化 DPS 统计
	var now := Time.get_ticks_msec() / 1000.0
	_dps_tracker["session_start"] = now
	_dps_tracker["window_start"] = now

	# 7. 连接法术系统信号（用于日志追踪）
	_connect_spell_signals()

	# 8. 添加到 test_chamber 组（供 DebugPanel 查找）
	add_to_group("test_chamber")

	_debug_log("回响试炼场 v4.0 已启动（基于正式游戏环境）")
	_debug_log("所有游戏系统均已加载，调试面板可控制完整游戏功能。")
	_debug_log("F11: 切换章节视觉主题 | F12: 切换 3D 渲染层")

func _process_test_mode(delta: float) -> void:
	# 应用时间缩放
	Engine.time_scale = time_scale

	# God mode
	if god_mode:
		GameManager.player_current_hp = GameManager.player_max_hp
		GameManager.player_hp_changed.emit(GameManager.player_current_hp, GameManager.player_max_hp)

	# 冻结敌人
	if freeze_enemies:
		for enemy in _get_all_enemies():
			if enemy.has_method("set_frozen"):
				enemy.set_frozen(true)

	# 无限疲劳
	if infinite_fatigue:
		FatigueManager.current_afi = 0.0

	# 自动施法
	if auto_fire:
		_auto_fire_timer += delta
		if _auto_fire_timer >= _auto_fire_interval:
			_auto_fire_timer = 0.0
			_auto_fire_cast()

	# 碰撞检测（使用正式游戏的完整逻辑）
	_collision_timer += delta
	if _collision_timer >= COLLISION_CHECK_INTERVAL:
		_collision_timer = 0.0
		_check_collisions()

	# 竞技场边界限制
	_enforce_arena_boundary()

	# 更新 DPS 窗口
	_update_dps_window()

	# 绘制调试信息
	if show_hitboxes:
		queue_redraw()

	# 更新地面 Shader 参数
	_update_ground_shader()

	# 更新事件视界
	_update_event_horizon()

	# 同步弹幕数据到 3D 渲染层
	_sync_projectiles_to_3d()

func _handle_test_mode_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		KEY_F1:
			god_mode = !god_mode
			_debug_log("无敌模式: %s" % ("开启" if god_mode else "关闭"))
		KEY_F2:
			infinite_fatigue = !infinite_fatigue
			_debug_log("无限疲劳: %s" % ("开启" if infinite_fatigue else "关闭"))
		KEY_F3:
			freeze_enemies = !freeze_enemies
			_debug_log("冻结敌人: %s" % ("开启" if freeze_enemies else "关闭"))
		KEY_F4:
			show_hitboxes = !show_hitboxes
			_debug_log("碰撞箱显示: %s" % ("开启" if show_hitboxes else "关闭"))
		KEY_F5:
			debug_clear_all_enemies()
		KEY_F6:
			_reset_dps()
		KEY_F7:
			time_scale = 0.25 if time_scale >= 1.0 else 1.0
			_debug_log("时间缩放: %.2fx" % time_scale)
		KEY_F8:
			debug_spawn_wave_preset("mixed_basic")
		KEY_F9:
			if CodexManager:
				CodexManager.unlock_all()
				_debug_log("已解锁全部图鉴条目")
		KEY_F10:
			auto_fire = !auto_fire
			_debug_log("自动施法: %s" % ("开启" if auto_fire else "关闭"))
		KEY_F11:
			_cycle_chapter_visual()
		KEY_F12:
			_toggle_3d_layer()
		KEY_ESCAPE:
			_return_to_menu()

func _draw() -> void:
	if not GameManager.is_test_mode:
		return
	if show_hitboxes:
		_draw_hitboxes()

# ============================================================
# 场景设置
# ============================================================

func _setup_scene() -> void:
	# 设置相机
	if _camera:
		_camera.zoom = Vector2(1.0, 1.0)
		_camera.position_smoothing_enabled = true
		_camera.position_smoothing_speed = 5.0

	# 创建地面（脉冲网格）
	_setup_ground()

	# 创建事件视界（竞技场边界）
	_setup_event_horizon()

# ============================================================
# 2.5D 渲染桥接层设置 (v3.0 新增)
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

	# 连接敌人生成信号，自动创建 3D 代理
	if _enemy_spawner and _enemy_spawner.has_signal("elite_spawned"):
		if not _enemy_spawner.elite_spawned.is_connected(_on_elite_spawned_3d):
			_enemy_spawner.elite_spawned.connect(_on_elite_spawned_3d)

	# Issue #35 修复：连接普通敌人生成信号，注册到 MultiMesh 批量渲染
	if _enemy_spawner and _enemy_spawner.has_signal("spawn_count_changed"):
		if not _enemy_spawner.spawn_count_changed.is_connected(_on_enemy_count_changed_3d):
			_enemy_spawner.spawn_count_changed.connect(_on_enemy_count_changed_3d)

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

## 精英敌人生成时创建 3D 代理——修复 Issue #35
func _on_elite_spawned_3d(enemy_type: String, position: Vector2) -> void:
	if not _render_bridge or not _render_bridge.has_method("register_enemy_proxy"):
		return

	# 查找刚生成的精英敌人节点
	var elite_node: Node2D = null
	var search_parent = _enemy_spawner if _enemy_spawner else self
	for child in search_parent.get_children():
		if child is CharacterBody2D and child.global_position.distance_to(position) < 50.0:
			elite_node = child
			break

	if elite_node == null:
		return

	# 根据敌人类型选择颜色
	var elite_color := _get_enemy_color(enemy_type)
	_render_bridge.register_enemy_proxy(elite_node, elite_color, true)

## 普通敌人数量变化时，将新敌人注册到 MultiMesh 批量渲染——修复 Issue #35
func _on_enemy_count_changed_3d(_active: int, _total_spawned: int) -> void:
	if not _render_bridge or not _render_bridge.has_method("register_normal_enemy"):
		return
	if not _enemy_spawner:
		return

	# 遍历 EnemySpawner 的子节点，找到未注册的普通敌人
	for child in _enemy_spawner.get_children():
		if child is CharacterBody2D and not child.has_meta("registered_3d"):
			var enemy_type_str: String = ""
			if child.has_method("get_enemy_type"):
				enemy_type_str = child.get_enemy_type()
			var color := _get_enemy_color(enemy_type_str)
			_render_bridge.register_normal_enemy(child, color)
			child.set_meta("registered_3d", true)

## 根据敌人类型返回对应的 3D 代理颜色
func _get_enemy_color(enemy_type: String) -> Color:
	match enemy_type:
		"static":
			return Color(0.7, 0.3, 0.3)   # 红色
		"silence":
			return Color(0.2, 0.1, 0.4)   # 深紫
		"screech":
			return Color(1.0, 0.8, 0.0)   # 黄色
		"pulse":
			return Color(0.0, 0.5, 1.0)   # 蓝色
		"wall":
			return Color(0.5, 0.5, 0.5)   # 灰色
		_:
			# 章节特色敌人 / 精英
			return Color(0.9, 0.3, 0.6)   # 品红

# ============================================================
# 系统信号连接
# ============================================================

func _connect_system_signals() -> void:
	# --- 游戏状态信号 ---
	if not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)
	if not GameManager.game_state_changed.is_connected(_on_game_state_changed):
		GameManager.game_state_changed.connect(_on_game_state_changed)

	# --- 节拍信号 → 3D 渲染层脉冲 (v3.0) ---
	if GameManager.has_signal("beat_tick"):
		if not GameManager.beat_tick.is_connected(_on_beat_tick_3d):
			GameManager.beat_tick.connect(_on_beat_tick_3d)

	# --- 章节管理器信号 ---
	if _chapter_manager:
		if _chapter_manager.has_signal("boss_triggered"):
			if not _chapter_manager.boss_triggered.is_connected(_on_chapter_boss_triggered):
				_chapter_manager.boss_triggered.connect(_on_chapter_boss_triggered)
		if _chapter_manager.has_signal("chapter_started"):
			if not _chapter_manager.chapter_started.is_connected(_on_chapter_started):
				_chapter_manager.chapter_started.connect(_on_chapter_started)
		if _chapter_manager.has_signal("chapter_completed"):
			if not _chapter_manager.chapter_completed.is_connected(_on_chapter_completed):
				_chapter_manager.chapter_completed.connect(_on_chapter_completed)
		if _chapter_manager.has_signal("game_completed"):
			if not _chapter_manager.game_completed.is_connected(_on_game_completed):
				_chapter_manager.game_completed.connect(_on_game_completed)

	# --- Boss 生成器信号 ---
	if _boss_spawner:
		if _boss_spawner.has_signal("boss_fight_started"):
			if not _boss_spawner.boss_fight_started.is_connected(_on_boss_fight_started):
				_boss_spawner.boss_fight_started.connect(_on_boss_fight_started)
		if _boss_spawner.has_signal("boss_fight_ended"):
			if not _boss_spawner.boss_fight_ended.is_connected(_on_boss_fight_ended):
				_boss_spawner.boss_fight_ended.connect(_on_boss_fight_ended)

	# --- 敌人击杀 → 死亡特效 ---
	if not GameManager.enemy_killed.is_connected(_on_enemy_killed_vfx):
		GameManager.enemy_killed.connect(_on_enemy_killed_vfx)

	# --- v3.0: 一体化编曲台信号 ---
	if _integrated_composer and _integrated_composer.has_signal("alchemy_completed"):
		if not _integrated_composer.alchemy_completed.is_connected(_on_alchemy_completed):
			_integrated_composer.alchemy_completed.connect(_on_alchemy_completed)

# ============================================================
# 法术系统信号连接（调试模式日志追踪）
# ============================================================

func _connect_spell_signals() -> void:
	if not SpellcraftSystem:
		return
	if not SpellcraftSystem.spell_cast.is_connected(_on_spellcraft_spell_cast):
		SpellcraftSystem.spell_cast.connect(_on_spellcraft_spell_cast)
	if not SpellcraftSystem.chord_cast.is_connected(_on_spellcraft_chord_cast):
		SpellcraftSystem.chord_cast.connect(_on_spellcraft_chord_cast)
	if not SpellcraftSystem.spell_blocked_by_silence.is_connected(_on_spell_blocked):
		SpellcraftSystem.spell_blocked_by_silence.connect(_on_spell_blocked)
	if not SpellcraftSystem.rhythm_pattern_changed.is_connected(_on_rhythm_changed):
		SpellcraftSystem.rhythm_pattern_changed.connect(_on_rhythm_changed)
	if SpellcraftSystem.has_signal("progression_resolved"):
		if not SpellcraftSystem.progression_resolved.is_connected(_on_progression_resolved):
			SpellcraftSystem.progression_resolved.connect(_on_progression_resolved)
	if SpellcraftSystem.has_signal("timbre_changed"):
		if not SpellcraftSystem.timbre_changed.is_connected(_on_timbre_changed):
			SpellcraftSystem.timbre_changed.connect(_on_timbre_changed)

func _on_spellcraft_spell_cast(spell_data: Dictionary) -> void:
	if not GameManager.is_test_mode:
		return
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
	_debug_log(msg)

func _on_spellcraft_chord_cast(chord_data: Dictionary) -> void:
	if not GameManager.is_test_mode:
		return
	var spell_name = chord_data.get("spell_name", "未知")
	var damage = chord_data.get("damage", 0.0)
	var dissonance = chord_data.get("dissonance", 0.0)
	var msg := "施放和弦: %s | 伤害: %.1f | 不和谐度: %.1f" % [spell_name, damage, dissonance]
	if chord_data.has("progression"):
		msg += " | 和弦进行触发!"
	_debug_log(msg)

func _on_spell_blocked(note: int) -> void:
	if GameManager.is_test_mode:
		_debug_log("⚠ 音符 %s 被寂静封锁!" % _get_white_key_name(note))

func _on_rhythm_changed(pattern) -> void:
	if GameManager.is_test_mode:
		_debug_log("节奏型变更: %s" % _get_rhythm_name(pattern))

func _on_progression_resolved(progression: Dictionary) -> void:
	if GameManager.is_test_mode:
		var effect_type: String = progression.get("effect", {}).get("type", "")
		_debug_log("★ 和弦进行解决: %s (效果: %s)" % [progression.get("name", ""), effect_type])

func _on_timbre_changed(timbre) -> void:
	if GameManager.is_test_mode:
		var timbre_info := SpellcraftSystem.get_timbre_info(timbre)
		_debug_log("音色切换: %s" % timbre_info.get("name", "未知"))

# ============================================================
# 章节系统启动
# ============================================================

func _start_chapter_system() -> void:
	if _chapter_manager and _chapter_manager.has_method("start_game"):
		_chapter_manager.start_game()

# ============================================================
# 信号回调 — 游戏状态
# ============================================================

func _on_player_died() -> void:
	if GameManager.is_test_mode:
		# 测试模式下不跳转到 game_over
		_debug_log("⚠ 玩家死亡！（测试模式下不跳转）")
		return
	_game_over_timer = 0.0

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.GAME_OVER:
			pass
		GameManager.GameState.PAUSED:
			pass
		GameManager.GameState.PLAYING:
			pass

# ============================================================
# 信号回调 — 章节系统
# ============================================================

func _on_chapter_started(_chapter_index: int, _chapter_name: String) -> void:
	# 章节开始的全屏特效
	if _vfx_manager:
		if _vfx_manager.has_method("play_screen_flash"):
			_vfx_manager.play_screen_flash(Color(0.2, 0.8, 1.0, 0.5), 0.3)
		if _vfx_manager.has_method("play_mode_switch"):
			var mode_name: String = ModeSystem.current_mode_id if ModeSystem else "ionian"
			_vfx_manager.play_mode_switch(mode_name)

	# v3.0: 更新 3D 渲染层的玩家光源颜色
	if _render_bridge and _render_bridge.has_method("update_player_light_color"):
		var chapter_colors = [
			Color(0.0, 1.0, 0.83),  # Ch0 毕达哥拉斯
			Color(0.6, 0.3, 0.8),   # Ch1 中世纪
			Color(1.0, 0.8, 0.3),   # Ch2 巴洛克
			Color(1.0, 0.4, 0.6),   # Ch3 洛可可
			Color(0.8, 0.2, 0.2),   # Ch4 浪漫主义
			Color(0.2, 0.6, 1.0),   # Ch5 爵士
			Color(0.0, 1.0, 0.3),   # Ch6 数字
		]
		if _chapter_index < chapter_colors.size():
			_render_bridge.update_player_light_color(chapter_colors[_chapter_index])

func _on_chapter_completed(_chapter_index: int) -> void:
	pass

func _on_chapter_boss_triggered(_chapter_index: int, _boss_key: String) -> void:
	if _boss_hp_bar:
		_boss_hp_bar.visible = true

func _on_game_completed() -> void:
	if GameManager.is_test_mode:
		_debug_log("★ 游戏完成！（测试模式下不跳转）")
		return
	_game_over_timer = 0.0

# ============================================================
# 信号回调 — Boss 系统
# ============================================================

func _on_boss_fight_started(_boss_name: String) -> void:
	if _boss_hp_bar:
		_boss_hp_bar.visible = true
	if _vfx_manager and _vfx_manager.has_method("play_boss_phase_transition"):
		_vfx_manager.play_boss_phase_transition()

	# v3.0: 3D 渲染层进入 Boss 模式
	if _render_bridge and _render_bridge.has_method("enter_boss_mode"):
		_render_bridge.enter_boss_mode()

func _on_boss_fight_ended(_boss_name: String, _victory: bool) -> void:
	if _boss_hp_bar:
		_boss_hp_bar.visible = false
	if _vfx_manager and _vfx_manager.has_method("play_screen_flash"):
		_vfx_manager.play_screen_flash(Color(1.0, 0.9, 0.3, 0.6), 0.5)

	# v3.0: 3D 渲染层退出 Boss 模式
	if _render_bridge and _render_bridge.has_method("exit_boss_mode"):
		_render_bridge.exit_boss_mode()

# ============================================================
# 信号回调 — 节拍 (v3.0 新增)
# ============================================================

func _on_beat_tick_3d(beat_index: int) -> void:
	if _render_bridge and _render_bridge.has_method("on_beat_pulse"):
		_render_bridge.on_beat_pulse(beat_index)

# ============================================================
# 信号回调 — 视觉特效
# ============================================================

func _on_enemy_killed_vfx(enemy_position: Vector2, enemy_type: String = "static") -> void:
	if _death_vfx_manager and _death_vfx_manager.has_method("play_death_effect"):
		_death_vfx_manager.play_death_effect(enemy_position, enemy_type)
	if _damage_number_manager and _damage_number_manager.has_method("show_damage"):
		_damage_number_manager.show_damage(0.0, enemy_position)

	# v3.0: 在 3D 层也产生爆发粒子
	if _render_bridge and _render_bridge.has_method("spawn_burst_particles"):
		var kill_color := Color(1.0, 0.3, 0.1)  # 默认橙红色
		_render_bridge.spawn_burst_particles(enemy_position, kill_color, 16)

# ============================================================
# 信号回调 — 和弦炼成
# ============================================================

func _on_alchemy_completed(_chord_spell: Dictionary) -> void:
	# v3.0: 和弦炼成完成后在一体化编曲台内自动更新法术书区域
	if _integrated_composer and _integrated_composer.has_method("refresh_spellbook"):
		_integrated_composer.refresh_spellbook()

# ============================================================
# 地面设置
# ============================================================

func _setup_ground() -> void:
	if _ground == null:
		_ground = Node2D.new()
		_ground.name = "Ground"
		add_child(_ground)
		move_child(_ground, 0)

	var ground_sprite := Sprite2D.new()
	ground_sprite.name = "GroundSprite"

	var texture := GradientTexture2D.new()
	texture.width = 4096
	texture.height = 4096
	texture.fill = GradientTexture2D.FILL_RADIAL
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.02, 0.05))
	gradient.set_color(1, Color(0.0, 0.0, 0.02))
	texture.gradient = gradient
	ground_sprite.texture = texture

	var shader := load("res://shaders/pulsing_grid.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		ground_sprite.material = mat

	_ground.add_child(ground_sprite)

# ============================================================
# 事件视界（竞技场边界）
# ============================================================

func _setup_event_horizon() -> void:
	if _event_horizon == null:
		_event_horizon = Node2D.new()
		_event_horizon.name = "EventHorizon"
		add_child(_event_horizon)

	var segments := 64
	for i in range(segments):
		var angle := (TAU / segments) * i
		var pos := Vector2.from_angle(angle) * arena_radius

		var segment_sprite := Sprite2D.new()
		var tex := GradientTexture2D.new()
		tex.width = 64
		tex.height = 256
		var grad := Gradient.new()
		grad.set_color(0, Color(0.1, 0.0, 0.2, 0.8))
		grad.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_LINEAR
		segment_sprite.texture = tex

		segment_sprite.position = pos
		segment_sprite.rotation = angle + PI / 2.0

		var shader := load("res://shaders/event_horizon.gdshader")
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			segment_sprite.material = mat

		_event_horizon.add_child(segment_sprite)

func _update_event_horizon() -> void:
	if _event_horizon == null:
		return

	var game_time := GameManager.game_time
	for child in _event_horizon.get_children():
		if child is Sprite2D and child.material is ShaderMaterial:
			var mat: ShaderMaterial = child.material
			mat.set_shader_parameter("time", game_time)

# ============================================================
# 碰撞检测
# ============================================================

func _check_collisions() -> void:
	if _projectile_manager == null:
		return

	# 获取碰撞数据：正常模式从 EnemySpawner，测试模式从 EnemySpawner 或手动生成的敌人
	var enemy_data: Array = []
	if _enemy_spawner and _enemy_spawner.has_method("get_enemy_collision_data"):
		enemy_data = _enemy_spawner.get_enemy_collision_data()

	# 测试模式下也收集手动生成的敌人（挂在 EnemySpawner 下）
	# 注意：调试模式的敌人也生成到 EnemySpawner 下，统一管理

	if enemy_data.is_empty():
		return

	var hits = _projectile_manager.check_collisions(enemy_data)

	for hit in hits:
		var enemy_node = hit["enemy"].get("node")
		if not enemy_node or not is_instance_valid(enemy_node):
			continue
		if not enemy_node.has_method("take_damage"):
			continue

		var knockback_dir := Vector2.ZERO
		var proj = hit["projectile"]
		if proj.get("velocity", Vector2.ZERO) != Vector2.ZERO:
			knockback_dir = proj["velocity"].normalized()

		enemy_node.take_damage(hit["damage"], knockback_dir)

		# DPS 统计（测试模式）
		if GameManager.is_test_mode:
			record_damage(hit["damage"], "spell")

		if _damage_number_manager and _damage_number_manager.has_method("show_damage"):
			_damage_number_manager.show_damage(hit["damage"], hit["position"])
		elif _hud and _hud.has_method("show_damage_number"):
			_hud.show_damage_number(hit["position"], hit["damage"])

		if _spell_visual_manager and _spell_visual_manager.has_method("on_projectile_hit"):
			_spell_visual_manager.on_projectile_hit(hit["position"], proj)

# ============================================================
# 竞技场边界
# ============================================================

func _enforce_arena_boundary() -> void:
	if _player == null:
		return

	var dist := _player.global_position.length()
	if dist > arena_radius:
		_player.global_position = _player.global_position.normalized() * arena_radius

# ============================================================
# 地面 Shader 更新
# ============================================================

func _update_ground_shader() -> void:
	if _ground == null:
		return

	var ground_sprite = _ground.get_node_or_null("GroundSprite")
	if ground_sprite and ground_sprite.material is ShaderMaterial:
		var mat: ShaderMaterial = ground_sprite.material
		mat.set_shader_parameter("time", GameManager.game_time)
		mat.set_shader_parameter("beat_energy", GlobalMusicManager.get_beat_energy())
		mat.set_shader_parameter("player_position", _player.global_position)

		var fatigue := FatigueManager.current_afi
		var grid_color := Color(0.0, 0.6, 0.8).lerp(Color(0.8, 0.0, 0.2), fatigue)
		mat.set_shader_parameter("grid_color", grid_color)

# ============================================================
# ★ 调试公共接口 (v4.0) — 供 DebugPanel 遥控
# ============================================================

## 手动生成敌人（调试模式）
func debug_spawn_enemy(enemy_type: String, count: int = 1, position_mode: String = "random") -> void:
	if not ENEMY_SCENES.has(enemy_type):
		_debug_log("未知敌人类型: %s" % enemy_type)
		return

	var scene: PackedScene = load(ENEMY_SCENES[enemy_type])
	if not scene:
		_debug_log("无法加载敌人场景: %s" % enemy_type)
		return

	# 确保 EnemySpawner 存在作为容器
	var container: Node2D = _enemy_spawner if _enemy_spawner else self

	for i in range(count):
		var enemy := scene.instantiate()
		var spawn_pos := _get_debug_spawn_position(position_mode, i, count)
		enemy.position = spawn_pos

		# 连接死亡信号
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(_on_debug_enemy_died)

		container.add_child(enemy)
		_spawned_count += 1

		# 注册 3D 渲染代理
		_register_debug_enemy_3d(enemy, enemy_type)

	_debug_log("已生成 %d 个 [%s]，位置模式: %s" % [count, enemy_type, position_mode])

## 生成预设波次（调试模式）
func debug_spawn_wave_preset(preset_name: String) -> void:
	match preset_name:
		"mixed_basic":
			debug_spawn_enemy("static", 10, "circle")
			debug_spawn_enemy("silence", 2, "random")
			debug_spawn_enemy("screech", 3, "random")
			_debug_log("预设波次: 基础混合")
		"static_swarm":
			debug_spawn_enemy("static", 30, "circle")
			_debug_log("预设波次: 底噪蜂群 (30)")
		"elite_test":
			debug_spawn_enemy("pulse", 3, "line")
			debug_spawn_enemy("wall", 1, "player_front")
			_debug_log("预设波次: 精英测试")
		"stress_test":
			debug_spawn_enemy("static", 50, "random")
			debug_spawn_enemy("screech", 10, "random")
			debug_spawn_enemy("pulse", 5, "random")
			debug_spawn_enemy("wall", 3, "random")
			debug_spawn_enemy("silence", 5, "random")
			_debug_log("预设波次: 压力测试 (73 敌人)")
		"dps_dummy":
			debug_spawn_enemy("wall", 1, "player_front")
			_debug_log("预设波次: DPS 木桩")
		_:
			_debug_log("未知预设: %s" % preset_name)

## 清除所有敌人（调试模式）
func debug_clear_all_enemies() -> void:
	var enemies := _get_all_enemies()
	var count := enemies.size()
	for enemy in enemies:
		# 移除 3D 代理
		if _render_bridge and _render_bridge.has_method("unregister_enemy_proxy"):
			_render_bridge.unregister_enemy_proxy(enemy)
		enemy.queue_free()
	_debug_log("已清除 %d 个敌人" % count)

## 获取当前敌人数量
func get_enemy_count() -> int:
	return _get_all_enemies().size()

## 设置玩家属性（调试模式）
func set_player_stat(stat: String, value: float) -> void:
	if not _player:
		return
	match stat:
		"max_hp":
			GameManager.player_max_hp = value
			GameManager.player_current_hp = min(GameManager.player_current_hp, value)
			GameManager.player_hp_changed.emit(GameManager.player_current_hp, GameManager.player_max_hp)
			_debug_log("玩家最大 HP: %.0f" % value)
		"move_speed":
			if "move_speed" in _player:
				_player.move_speed = value
			_debug_log("玩家移速: %.0f" % value)
		"damage_multiplier":
			if GameManager and "damage_multiplier" in GameManager:
				GameManager.damage_multiplier = value
			_debug_log("伤害倍率: %.2fx" % value)
		"pickup_range":
			if "pickup_range" in _player:
				_player.pickup_range = value
			_debug_log("拾取范围: %.0f" % value)

## 设置 BPM
func set_bpm(bpm: float) -> void:
	if GameManager:
		GameManager.current_bpm = bpm
		_debug_log("BPM: %.0f" % bpm)

## 设置调式
func set_mode(mode_id: String) -> void:
	test_set_mode(mode_id)

## 设置玩家等级
func set_player_level(level: int) -> void:
	if GameManager:
		GameManager.player_level = level
		_debug_log("玩家等级: %d" % level)

# ============================================================
# ★ 法术快速测试接口（通过 SpellcraftSystem 实际机制）
# ============================================================

## 快速施放单音符
func test_cast_note(white_key: int) -> void:
	if not SpellcraftSystem:
		_debug_log("SpellcraftSystem 不可用")
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
		"modifier": -1,
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
	_debug_log("测试施放: %s (DMG=%.1f, SPD=%.0f)" % [_get_white_key_name(white_key), base_damage, spell_data["speed"]])

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
	_debug_log("测试施放: %s + %s" % [_get_white_key_name(white_key), _get_modifier_name(modifier)])

## 快速施放和弦法术
func test_cast_chord(chord_type: int) -> void:
	if not SpellcraftSystem:
		return

	var spell_info = MusicData.CHORD_SPELL_MAP.get(chord_type, {})
	if spell_info.is_empty():
		_debug_log("未知和弦类型: %d" % chord_type)
		return

	var intervals: Array = MusicData.CHORD_INTERVALS.get(chord_type, [])
	var chord_notes: Array = []
	for interval in intervals:
		chord_notes.append(interval)

	var chord_result = MusicTheoryEngine.identify_chord(chord_notes)
	if chord_result == null:
		_debug_log("和弦识别失败: %s" % spell_info.get("name", ""))
		return

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

	var raw_dissonance = MusicTheoryEngine.get_chord_dissonance(chord_type)
	var dissonance = raw_dissonance * ModeSystem.get_dissonance_multiplier()
	if dissonance > 2.0:
		GameManager.apply_dissonance_damage(dissonance)
		ModeSystem.on_dissonance_applied(dissonance)
		FatigueManager.reduce_monotony_from_dissonance(dissonance)

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

	FatigueManager.record_spell({
		"time": GameManager.game_time,
		"note": chord_result.get("root", 0),
		"is_chord": true,
		"chord_type": chord_type,
	})

	# OPT01: 记录和弦进行并通知和声指挥官
	var chord_root_pc: int = chord_result.get("root", 0) % 12
	MusicTheoryEngine.record_chord(chord_type, chord_root_pc)

	SpellcraftSystem.chord_cast.emit(chord_data)
	_debug_log("测试施放和弦: %s (DMG=%.1f, 不和谐=%.1f)" % [spell_info["name"], base_damage, dissonance])

## 设置序列器
func test_set_sequencer_pattern(pattern: Array) -> void:
	if not SpellcraftSystem:
		return
	SpellcraftSystem.clear_sequencer()
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
				pass
	_debug_log("序列器已配置: %d 个槽位" % pattern.size())

## 设置手动施法槽
func test_set_manual_slot(slot_index: int, spell_data: Dictionary) -> void:
	if not SpellcraftSystem:
		return
	SpellcraftSystem.set_manual_slot(slot_index, spell_data)
	_debug_log("手动施法槽 %d 已配置" % slot_index)

## 触发手动施法
func test_trigger_manual_cast(slot_index: int) -> void:
	if not SpellcraftSystem:
		return
	SpellcraftSystem.trigger_manual_cast(slot_index)

## 切换音色
func test_set_timbre(timbre: int) -> void:
	if not SpellcraftSystem:
		return
	SpellcraftSystem.set_timbre(timbre)

## 切换调式
func test_set_mode(mode_id: String) -> void:
	if ModeSystem and ModeSystem.has_method("apply_mode"):
		ModeSystem.apply_mode(mode_id)
		_debug_log("调式切换: %s" % mode_id)

# ============================================================
# ★ 法术预设（方便快速测试特定组合）
# ============================================================

func preset_full_note_sequencer() -> void:
	var pattern: Array = []
	var keys := [MusicData.WhiteKey.C, MusicData.WhiteKey.D, MusicData.WhiteKey.E, MusicData.WhiteKey.F,
				 MusicData.WhiteKey.G, MusicData.WhiteKey.A, MusicData.WhiteKey.B, MusicData.WhiteKey.C,
				 MusicData.WhiteKey.G, MusicData.WhiteKey.E, MusicData.WhiteKey.C, MusicData.WhiteKey.G,
				 MusicData.WhiteKey.A, MusicData.WhiteKey.B, MusicData.WhiteKey.D, MusicData.WhiteKey.F]
	for i in range(SpellcraftSystem.SEQUENCER_LENGTH):
		pattern.append({"type": "note", "note": keys[i % keys.size()]})
	test_set_sequencer_pattern(pattern)
	_debug_log("预设: 全音符连射序列器")

func preset_charged_sequencer() -> void:
	var pattern: Array = []
	for i in range(SpellcraftSystem.SEQUENCER_LENGTH):
		if i % 2 == 0:
			pattern.append({"type": "note", "note": MusicData.WhiteKey.G})
		else:
			pattern.append({"type": "rest"})
	test_set_sequencer_pattern(pattern)
	_debug_log("预设: 蓄力序列器 (G + 休止符交替)")

func preset_all_basic_chords() -> void:
	var chord_types := [
		MusicData.ChordType.MAJOR, MusicData.ChordType.MINOR,
		MusicData.ChordType.AUGMENTED, MusicData.ChordType.DIMINISHED,
		MusicData.ChordType.SUSPENDED,
	]
	for chord_type in chord_types:
		test_cast_chord(chord_type)
		await get_tree().create_timer(0.5).timeout
	_debug_log("预设: 所有基础和弦已施放")

func preset_all_seventh_chords() -> void:
	var chord_types := [
		MusicData.ChordType.DOMINANT_7, MusicData.ChordType.DIMINISHED_7,
		MusicData.ChordType.MAJOR_7, MusicData.ChordType.MINOR_7,
	]
	for chord_type in chord_types:
		test_cast_chord(chord_type)
		await get_tree().create_timer(0.5).timeout
	_debug_log("预设: 所有七和弦已施放")

func preset_all_modifiers() -> void:
	var modifiers := [
		MusicData.ModifierEffect.PIERCE, MusicData.ModifierEffect.HOMING,
		MusicData.ModifierEffect.SPLIT, MusicData.ModifierEffect.ECHO,
		MusicData.ModifierEffect.SCATTER,
	]
	for mod in modifiers:
		test_cast_note_with_modifier(MusicData.WhiteKey.G, mod)
		await get_tree().create_timer(0.3).timeout
	_debug_log("预设: 所有修饰符已测试")

# ============================================================
# ★ 章节控制接口（调试模式）
# ============================================================

## 手动启动章节系统
func debug_start_chapter_system() -> void:
	if _chapter_manager:
		_chapter_manager.set_process(true)
		_start_chapter_system()
		_debug_log("章节系统已手动启动")

## 手动暂停章节系统
func debug_pause_chapter_system() -> void:
	if _chapter_manager:
		_chapter_manager.set_process(false)
		_debug_log("章节系统已暂停")

## 手动启动敌人波次系统
func debug_start_enemy_spawner() -> void:
	if _enemy_spawner:
		_enemy_spawner.set_process(true)
		_debug_log("敌人波次系统已启动")

## 手动暂停敌人波次系统
func debug_pause_enemy_spawner() -> void:
	if _enemy_spawner:
		_enemy_spawner.set_process(false)
		_debug_log("敌人波次系统已暂停")

## 切换章节视觉主题
func _cycle_chapter_visual() -> void:
	_current_test_chapter = (_current_test_chapter + 1) % MAX_CHAPTERS
	if _chapter_manager and _chapter_manager.has_method("force_chapter_visual"):
		_chapter_manager.force_chapter_visual(_current_test_chapter)
	_on_chapter_started(_current_test_chapter, "Chapter %d" % _current_test_chapter)
	# OPT04: 同步切换章节调式
	var tonality_key: int = _current_test_chapter + 1
	if BgmManager and BgmManager.has_method("set_tonality"):
		BgmManager.set_tonality(tonality_key)
	_debug_log("章节视觉切换: Chapter %d" % _current_test_chapter)

## 切换 3D 渲染层
func _toggle_3d_layer() -> void:
	if _render_bridge and "enable_3d_layer" in _render_bridge:
		_render_bridge.enable_3d_layer = !_render_bridge.enable_3d_layer
		_debug_log("3D 渲染层: %s" % ("开启" if _render_bridge.enable_3d_layer else "关闭"))

# ============================================================
# DPS 统计
# ============================================================

func record_damage(damage: float, source: String = "spell") -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_dps_tracker["total_damage"] += damage
	_dps_tracker["damage_log"].append({
		"time": now,
		"damage": damage,
		"source": source,
	})
	_dps_tracker["window_damage"] += damage

func _update_dps_window() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var window := 5.0
	var log: Array = _dps_tracker["damage_log"]
	while not log.is_empty() and log[0]["time"] < now - window:
		_dps_tracker["window_damage"] -= log[0]["damage"]
		log.pop_front()
	var elapsed = now - _dps_tracker.get("window_start", now)
	if elapsed > 0.1:
		_dps_tracker["current_dps"] = _dps_tracker["window_damage"] / min(elapsed, window)
	else:
		_dps_tracker["current_dps"] = 0.0
	if _dps_tracker["current_dps"] > _dps_tracker["peak_dps"]:
		_dps_tracker["peak_dps"] = _dps_tracker["current_dps"]

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
	_debug_log("DPS 统计已重置")

# ============================================================
# 系统状态查询（供调试面板显示）
# ============================================================

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

func get_projectile_stats() -> Dictionary:
	if _projectile_manager and _projectile_manager.has_method("get_active_count"):
		return {
			"active_projectiles": _projectile_manager.get_active_count(),
			"collision_stats": _projectile_manager.get_collision_stats() if _projectile_manager.has_method("get_collision_stats") else {},
		}
	return {}

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
# 内部辅助函数
# ============================================================

## 获取所有活着的敌人（兼容 EnemySpawner 和手动生成）
func _get_all_enemies() -> Array:
	var enemies: Array = []
	if _enemy_spawner:
		for child in _enemy_spawner.get_children():
			if child is CharacterBody2D and is_instance_valid(child):
				enemies.append(child)
	return enemies

## 获取调试模式生成位置
func _get_debug_spawn_position(mode: String, index: int, total: int) -> Vector2:
	var center := _player.global_position if _player else Vector2.ZERO
	match mode:
		"random":
			return center + Vector2(randf_range(-600, 600), randf_range(-600, 600))
		"circle":
			var angle := (TAU / total) * index
			var radius := 400.0
			return center + Vector2(cos(angle), sin(angle)) * radius
		"line":
			var start_x := center.x - (total * 60) / 2.0
			return Vector2(start_x + index * 60, center.y - 300)
		"grid":
			var cols := ceili(sqrt(total))
			var row := index / cols
			var col := index % cols
			var start := center - Vector2(cols * 60, (total / cols) * 60) / 2.0
			return start + Vector2(col * 60, row * 60)
		"player_front":
			if _player:
				var offset := Vector2(randf_range(-100, 100), -200 - randf_range(0, 200))
				return _player.global_position + offset
			return center
		_:
			return center + Vector2(randf_range(-300, 300), randf_range(-300, 300))

## 注册调试模式敌人的 3D 渲染代理
func _register_debug_enemy_3d(enemy: Node2D, enemy_type: String) -> void:
	if not _render_bridge:
		return
	var color := _get_enemy_color(enemy_type)
	var is_elite := enemy_type in ["pulse", "wall"]
	if is_elite and _render_bridge.has_method("register_enemy_proxy"):
		_render_bridge.register_enemy_proxy(enemy, color, true)
	elif _render_bridge.has_method("register_normal_enemy"):
		_render_bridge.register_normal_enemy(enemy, color)
	enemy.set_meta("registered_3d", true)

## 自动施法逻辑
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

## 敌人死亡回调（调试模式）
func _on_debug_enemy_died(pos: Vector2, xp_value: int, enemy_type: String) -> void:
	_killed_count += 1
	if CodexManager:
		CodexManager.on_enemy_died(pos, xp_value, enemy_type)

## 绘制碰撞箱
func _draw_hitboxes() -> void:
	if _player:
		draw_circle(_player.global_position, 12.0, Color(0.0, 1.0, 0.5, 0.3))
	for enemy in _get_all_enemies():
		if "collision_radius" in enemy:
			draw_circle(enemy.global_position, enemy.collision_radius, Color(1.0, 0.3, 0.3, 0.3))
		else:
			draw_circle(enemy.global_position, 16.0, Color(1.0, 0.3, 0.3, 0.3))

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

func _debug_log(text: String) -> void:
	var timestamp := Time.get_time_string_from_system()
	var msg := "[%s] %s" % [timestamp, text]
	debug_message.emit(msg)
	print("[MainGame:TestMode] %s" % msg)

# ============================================================
# 返回主菜单
# ============================================================

func _return_to_menu() -> void:
	# 恢复时间缩放
	Engine.time_scale = 1.0
	time_scale = 1.0

	# 断开法术系统信号
	if SpellcraftSystem:
		if SpellcraftSystem.spell_cast.is_connected(_on_spellcraft_spell_cast):
			SpellcraftSystem.spell_cast.disconnect(_on_spellcraft_spell_cast)
		if SpellcraftSystem.chord_cast.is_connected(_on_spellcraft_chord_cast):
			SpellcraftSystem.chord_cast.disconnect(_on_spellcraft_chord_cast)
		if SpellcraftSystem.spell_blocked_by_silence.is_connected(_on_spell_blocked):
			SpellcraftSystem.spell_blocked_by_silence.disconnect(_on_spell_blocked)
		if SpellcraftSystem.rhythm_pattern_changed.is_connected(_on_rhythm_changed):
			SpellcraftSystem.rhythm_pattern_changed.disconnect(_on_rhythm_changed)
		if SpellcraftSystem.has_signal("progression_resolved"):
			if SpellcraftSystem.progression_resolved.is_connected(_on_progression_resolved):
				SpellcraftSystem.progression_resolved.disconnect(_on_progression_resolved)
		if SpellcraftSystem.has_signal("timbre_changed"):
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

	_debug_log("返回主菜单")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
