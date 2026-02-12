## enemy_static.gd
## Static (底噪) — 白噪声
## 最基础的敌人，数量巨大，直线蜂拥而至。
## 音乐隐喻：无处不在的背景噪音，低级但持续的干扰。
## 视觉：小型不规则多边形碎片，具有 Datamosh 和顶点抖动效果。
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Static 专属配置
# ============================================================
## 群体加速：附近同类越多，移动越快
@export var swarm_speed_bonus: float = 0.05
## 群体加速检测半径
@export var swarm_detect_radius: float = 80.0
## 最大群体加速倍率
@export var max_swarm_multiplier: float = 1.6

## 多边形生成参数
@export var polygon_base_radius: float = 12.0
@export var polygon_vertices_count: int = 7
@export var polygon_irregularity: float = 0.4

# ============================================================
# 内部状态
# ============================================================
var _swarm_speed_multiplier: float = 1.0
var _swarm_check_timer: float = 0.0
const SWARM_CHECK_INTERVAL: float = 0.5

## 相位变体 (0: Normal, 1: Overtone/High-pass, 2: Sub-bass/Low-pass)
var phase_shift_type: int = 0

## 组件引用
var _trail: Line2D

## 原始状态备份
var _original_move_speed: float
var _original_scale: Vector2
var _brownian_direction: Vector2
var _brownian_timer: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.STATIC
	quantized_fps = 16.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.0
	move_on_offbeat = true

	# 动态生成不规则多边形
	_generate_irregular_polygon()

	# 准备拖尾效果节点
	_trail = Line2D.new()
	_trail.width = 4.0
	_trail.default_color = Color(0.9, 0.2, 0.9, 0.5) # 洋红色
	_trail.antialiased = true
	add_child(_trail)
	_trail.visible = false

	# 备份原始状态
	_original_move_speed = move_speed
	_original_scale = scale

	# 设置 Shader 的 datamosh 强度
	if _sprite.material and _sprite.material.has_param("datamosh_intensity"):
		_sprite.material.set("shader_parameter/datamosh_intensity", randf_range(0.2, 0.6))

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 定期检测附近同类数量，计算群体加速
	_swarm_check_timer += delta
	if _swarm_check_timer >= SWARM_CHECK_INTERVAL:
		_swarm_check_timer = 0.0
		if phase_shift_type != 1: # Overtone 模式不进行群体加速
			_update_swarm_bonus()
		else:
			_swarm_speed_multiplier = 1.0

	# 更新拖尾
	if _trail.visible:
		_add_trail_point(global_position)

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO

	var dir: Vector2

	# 根据相位变体选择移动模式
	match phase_shift_type:
		0: # Normal: 直线追踪 + 群体加速
			dir = (_target.global_position - global_position).normalized()
			# 轻微随机偏移
			var noise_offset := Vector2(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15))
			dir = (dir + noise_offset).normalized()
			velocity = dir * move_speed * _swarm_speed_multiplier

		1: # Overtone: 布朗运动
			_brownian_timer -= get_process_delta_time()
			if _brownian_timer <= 0:
				_brownian_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
				_brownian_timer = randf_range(0.1, 0.3) # 每隔一小段时间改变方向
			dir = _brownian_direction
			velocity = dir * move_speed

		2: # Sub-bass: 直线追踪，但速度较慢
			dir = (_target.global_position - global_position).normalized()
			velocity = dir * move_speed

	move_and_slide()
	return Vector2.ZERO # 已在此处完成移动

func _update_swarm_bonus() -> void:
	var nearby_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < swarm_detect_radius:
			if enemy.enemy_type == EnemyType.STATIC:
				nearby_count += 1

	_swarm_speed_multiplier = min(1.0 + nearby_count * swarm_speed_bonus, max_swarm_multiplier)

# ============================================================
# 视觉生成
# ============================================================

## 生成不规则多边形顶点
func _generate_irregular_polygon() -> void:
	var points: PackedVector2Array = []
	var angle_step = TAU / polygon_vertices_count

	for i in range(polygon_vertices_count):
		var angle = i * angle_step
		var radius = polygon_base_radius * (1.0 + randf_range(-polygon_irregularity, polygon_irregularity))
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	if _sprite and _sprite is Polygon2D:
		_sprite.polygon = points

# ============================================================
# 相位变体
# ============================================================

## 应用相位变体效果
func apply_phase_shift(type: int) -> void:
	phase_shift_type = type

	# 重置为默认状态
	move_speed = _original_move_speed
	scale = _original_scale
	_trail.visible = false
	if _sprite.material and _sprite.material.has_param("pixel_size"):
		_sprite.material.set("shader_parameter/pixel_size", 1.0)

	# 应用新状态
	match phase_shift_type:
		1: # Overtone (高通)
			scale = _original_scale * 0.75
			move_speed = _original_move_speed * 1.5
			_trail.visible = true
			_trail.clear_points()
			_brownian_timer = 0 # 立即选择新方向

		2: # Sub-bass (低通)
			scale = _original_scale * 1.5
			move_speed = _original_move_speed * 0.6
			if _sprite.material and _sprite.material.has_param("pixel_size"):
				_sprite.material.set("shader_parameter/pixel_size", 8.0)

## 添加拖尾点并管理长度
func _add_trail_point(point: Vector2) -> void:
	_trail.add_point(to_local(point))
	while _trail.get_point_count() > 15:
		_trail.remove_point(0)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# Static 死亡无特殊区域效果，仅视觉碎裂
	pass
