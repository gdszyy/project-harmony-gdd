## main_game.gd
## 主游戏场景
## 管理游戏循环、碰撞检测、场景组件协调
extends Node2D

# ============================================================
# 节点引用
# ============================================================
@onready var _player: CharacterBody2D = $Player
@onready var _enemy_spawner: Node2D = $EnemySpawner
@onready var _projectile_manager: Node2D = $ProjectileManager
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _ground: Node2D = $Ground
@onready var _hud: CanvasLayer = $HUD
@onready var _event_horizon: Node2D = $EventHorizon

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

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_scene()
	GameManager.start_game()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if GameManager.current_state == GameManager.GameState.PLAYING:
			GameManager.pause_game()
		elif GameManager.current_state == GameManager.GameState.PAUSED:
			GameManager.resume_game()

func _process(delta: float) -> void:
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
	# 使用多个 Sprite2D 排列成圆形，应用 event_horizon Shader
	var segments := 64
	for i in range(segments):
		var angle := (TAU / segments) * i
		var pos := Vector2.from_angle(angle) * arena_radius

		var segment_sprite := Sprite2D.new()
		# 使用简单的白色纹理 + Shader
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
	# 更新事件视界 Shader 参数
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

			# 显示伤害数字
			if _hud and _hud.has_method("show_damage_number"):
				_hud.show_damage_number(hit["position"], hit["damage"])

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
