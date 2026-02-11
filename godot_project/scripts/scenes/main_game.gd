## main_game.gd
## 主游戏场景 v3.0 — 2.5D 混合渲染集成版
## 管理游戏循环、碰撞检测、场景组件协调
## 集成：ChapterManager、BossSpawner、SpellVisualManager、VfxManager、
##       DeathVfxManager、DamageNumberManager、SummonManager、RenderBridge3D
##       以及所有UI面板（NoteInventoryUI、SpellbookUI、ChordAlchemyPanel、
##       TimbreWheelUI、ManualSlotConfig、BossHPBar）
##
## v3.0 变更：
## - 集成 RenderBridge3D 实现 2D 逻辑 + 3D 渲染的 2.5D 混合方案
## - 2D 物理和碰撞系统完全保留
## - 3D 层提供 Glow/Bloom、真实光照、3D 粒子等视觉增强
extends Node2D

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
@onready var _chapter_manager: Node = $ChapterManager
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
# 节点引用 — UI 面板
# ============================================================
@onready var _note_inventory_ui: Control = $HUD/NoteInventoryUI
@onready var _spellbook_ui: Control = $HUD/SpellbookUI
@onready var _chord_alchemy_panel: Control = $HUD/ChordAlchemyPanel
@onready var _timbre_wheel_ui: Control = $HUD/TimbreWheelUI
@onready var _manual_slot_config: Control = $HUD/ManualSlotConfig
@onready var _boss_hp_bar: Control = $HUD/BossHPBar

# ============================================================
# 配置
# ============================================================
## 竞技场半径
@export var arena_radius: float = 1500.0
## 碰撞检测频率
const COLLISION_CHECK_INTERVAL: float = 0.033  # ~30Hz

# ============================================================
# 状态
# ============================================================
var _collision_timer: float = 0.0
## 游戏结束场景跳转延迟
var _game_over_timer: float = -1.0
const GAME_OVER_DELAY: float = 2.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_scene()
	_setup_render_bridge()
	_connect_system_signals()
	_start_chapter_system()
	GameManager.start_game()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game"):
		if GameManager.current_state == GameManager.GameState.PLAYING:
			GameManager.pause_game()
		elif GameManager.current_state == GameManager.GameState.PAUSED:
			GameManager.resume_game()

func _process(delta: float) -> void:
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
		_enemy_spawner.elite_spawned.connect(_on_elite_spawned_3d)

	# Issue #35 修复：连接普通敌人生成信号，注册到 MultiMesh 批量渲染
	if _enemy_spawner and _enemy_spawner.has_signal("spawn_count_changed"):
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
	if _enemy_spawner:
		for child in _enemy_spawner.get_children():
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
			_chapter_manager.boss_triggered.connect(_on_chapter_boss_triggered)
		if _chapter_manager.has_signal("chapter_started"):
			_chapter_manager.chapter_started.connect(_on_chapter_started)
		if _chapter_manager.has_signal("chapter_completed"):
			_chapter_manager.chapter_completed.connect(_on_chapter_completed)
		if _chapter_manager.has_signal("game_completed"):
			_chapter_manager.game_completed.connect(_on_game_completed)

	# --- Boss 生成器信号 ---
	if _boss_spawner:
		if _boss_spawner.has_signal("boss_fight_started"):
			_boss_spawner.boss_fight_started.connect(_on_boss_fight_started)
		if _boss_spawner.has_signal("boss_fight_ended"):
			_boss_spawner.boss_fight_ended.connect(_on_boss_fight_ended)

	# --- 敌人击杀 → 死亡特效 ---
	if not GameManager.enemy_killed.is_connected(_on_enemy_killed_vfx):
		GameManager.enemy_killed.connect(_on_enemy_killed_vfx)

	# --- 和弦炼成完成信号 ---
	if _chord_alchemy_panel and _chord_alchemy_panel.has_signal("alchemy_completed"):
		_chord_alchemy_panel.alchemy_completed.connect(_on_alchemy_completed)

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
	if _spellbook_ui and _spellbook_ui.has_method("open_panel"):
		_spellbook_ui.open_panel()

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
	if _projectile_manager == null or _enemy_spawner == null:
		return

	var enemy_data = _enemy_spawner.get_enemy_collision_data()
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
