## main_game.gd
## 主游戏场景 v2.0 — 全系统集成版
## 管理游戏循环、碰撞检测、场景组件协调
## 集成：ChapterManager、BossSpawner、SpellVisualManager、VfxManager、
##       DeathVfxManager、DamageNumberManager、SummonManager
##       以及所有UI面板（NoteInventoryUI、SpellbookUI、ChordAlchemyPanel、
##       TimbreWheelUI、ManualSlotConfig、BossHPBar）
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
# 节点引用 — 系统管理器（审计报告 2.4 / 2.5 修复）
# ============================================================
@onready var _chapter_manager: Node = $ChapterManager
@onready var _boss_spawner: Node = $BossSpawner
@onready var _spell_visual_manager: Node2D = $SpellVisualManager
@onready var _death_vfx_manager: Node2D = $DeathVfxManager
@onready var _damage_number_manager: Node2D = $DamageNumberManager
@onready var _summon_manager: Node = $SummonManager
@onready var _vfx_manager: CanvasLayer = $VfxManager

# ============================================================
# 节点引用 — UI 面板（审计报告 2.1 / 2.2 修复）
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
# 系统信号连接（审计报告修复核心）
# ============================================================

func _connect_system_signals() -> void:
	# --- 游戏状态信号 ---
	if not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)
	if not GameManager.game_state_changed.is_connected(_on_game_state_changed):
		GameManager.game_state_changed.connect(_on_game_state_changed)

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
# 章节系统启动（审计报告 2.4 修复）
# ============================================================

func _start_chapter_system() -> void:
	if _chapter_manager and _chapter_manager.has_method("start_game"):
		_chapter_manager.start_game()

# ============================================================
# 信号回调 — 游戏状态
# ============================================================

func _on_player_died() -> void:
	# 启动游戏结束延迟跳转
	_game_over_timer = 0.0

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.GAME_OVER:
			# 游戏结束处理（跳转由 _game_over_timer 控制）
			pass
		GameManager.GameState.PAUSED:
			pass
		GameManager.GameState.PLAYING:
			pass

# ============================================================
# 信号回调 — 章节系统
# ============================================================

func _on_chapter_started(_chapter_index: int, _chapter_name: String) -> void:
	# 章节开始的全屏特效（使用 play_screen_flash + play_mode_switch）
	if _vfx_manager:
		if _vfx_manager.has_method("play_screen_flash"):
			_vfx_manager.play_screen_flash(Color(0.2, 0.8, 1.0, 0.5), 0.3)
		if _vfx_manager.has_method("play_mode_switch"):
			var mode_name: String = ModeSystem.current_mode_id if ModeSystem else "ionian"
			_vfx_manager.play_mode_switch(mode_name)

func _on_chapter_completed(_chapter_index: int) -> void:
	pass

func _on_chapter_boss_triggered(_chapter_index: int, _boss_key: String) -> void:
	# Boss 战开始时显示 Boss 血条
	if _boss_hp_bar:
		_boss_hp_bar.visible = true

func _on_game_completed() -> void:
	# 全部章节通关
	_game_over_timer = 0.0

# ============================================================
# 信号回调 — Boss 系统
# ============================================================

func _on_boss_fight_started(_boss_name: String) -> void:
	if _boss_hp_bar:
		_boss_hp_bar.visible = true
	if _vfx_manager and _vfx_manager.has_method("play_boss_phase_transition"):
		_vfx_manager.play_boss_phase_transition()

func _on_boss_fight_ended(_boss_name: String, _victory: bool) -> void:
	if _boss_hp_bar:
		_boss_hp_bar.visible = false
	if _vfx_manager and _vfx_manager.has_method("play_screen_flash"):
		_vfx_manager.play_screen_flash(Color(1.0, 0.9, 0.3, 0.6), 0.5)

# ============================================================
# 信号回调 — 视觉特效
# ============================================================

func _on_enemy_killed_vfx(enemy_position: Vector2, enemy_type: String = "static") -> void:
	if _death_vfx_manager and _death_vfx_manager.has_method("play_death_effect"):
		_death_vfx_manager.play_death_effect(enemy_position, enemy_type)
	# 同时显示击杀伤害数字
	if _damage_number_manager and _damage_number_manager.has_method("show_damage"):
		_damage_number_manager.show_damage(0.0, enemy_position)  # 0 = 击杀标记

# ============================================================
# 信号回调 — 和弦炼成
# ============================================================

func _on_alchemy_completed(_chord_spell: Dictionary) -> void:
	# 炼成完成后自动打开法术书
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
		move_child(_ground, 0)  # 放到最底层

	# 创建大型地面精灵
	var ground_sprite := Sprite2D.new()
	ground_sprite.name = "GroundSprite"

	# 使用程序化纹理 + Shader
	var texture := GradientTexture2D.new()
	texture.width = 4096
	texture.height = 4096
	texture.fill = GradientTexture2D.FILL_RADIAL
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.02, 0.05))
	gradient.set_color(1, Color(0.0, 0.0, 0.02))
	texture.gradient = gradient
	ground_sprite.texture = texture

	# 应用脉冲网格 Shader
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

	# 创建环形边界视觉效果
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

	# 获取敌人碰撞数据
	var enemy_data = _enemy_spawner.get_enemy_collision_data()

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

			# 显示伤害数字（优先使用 DamageNumberManager）
			if _damage_number_manager and _damage_number_manager.has_method("show_damage"):
				_damage_number_manager.show_damage(hit["damage"], hit["position"])
			elif _hud and _hud.has_method("show_damage_number"):
				_hud.show_damage_number(hit["position"], hit["damage"])

			# 命中视觉特效
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

		# 根据疲劳度调整网格颜色
		var fatigue := FatigueManager.current_afi
		var grid_color := Color(0.0, 0.6, 0.8).lerp(Color(0.8, 0.0, 0.2), fatigue)
		mat.set_shader_parameter("grid_color", grid_color)
