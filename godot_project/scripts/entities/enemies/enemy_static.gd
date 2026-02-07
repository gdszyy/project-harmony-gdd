## enemy_static.gd
## Static (底噪) — 白噪声
## 最基础的敌人，数量巨大，直线蜂拥而至。
## 音乐隐喻：无处不在的背景噪音，低级但持续的干扰。
## 视觉：小型锯齿碎片，快速抖动，高帧率量化移动。
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
## 视觉抖动幅度
@export var visual_jitter_amplitude: float = 1.5

# ============================================================
# 内部状态
# ============================================================
var _swarm_speed_multiplier: float = 1.0
var _swarm_check_timer: float = 0.0
const SWARM_CHECK_INTERVAL: float = 0.5

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.STATIC
	# Static 使用较高的量化帧率（更灵活的小碎片）
	quantized_fps = 16.0
	_quantize_interval = 1.0 / quantized_fps
	# 低击退抗性（容易被推开）
	knockback_resistance = 0.0
	# 弱拍移动
	move_on_offbeat = true

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 定期检测附近同类数量，计算群体加速
	_swarm_check_timer += delta
	if _swarm_check_timer >= SWARM_CHECK_INTERVAL:
		_swarm_check_timer = 0.0
		_update_swarm_bonus()

	# 视觉抖动（模拟白噪声的随机性）
	if _sprite:
		var jitter := Vector2(
			randf_range(-visual_jitter_amplitude, visual_jitter_amplitude),
			randf_range(-visual_jitter_amplitude, visual_jitter_amplitude)
		)
		# 叠加在故障偏移之上
		_sprite.position += jitter

# ============================================================
# 移动逻辑：直线追踪 + 群体加速
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO

	var dir := (_target.global_position - global_position).normalized()

	# 轻微随机偏移（模拟噪声的不精确性）
	var noise_offset := Vector2(
		randf_range(-0.15, 0.15),
		randf_range(-0.15, 0.15)
	)
	dir = (dir + noise_offset).normalized()

	# 应用群体加速（通过临时修改 velocity 幅度）
	velocity = dir * move_speed * _swarm_speed_multiplier
	move_and_slide()
	return Vector2.ZERO  # 已在此处完成移动，返回零向量避免基类重复移动

func _update_swarm_bonus() -> void:
	var nearby_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < swarm_detect_radius:
			nearby_count += 1

	_swarm_speed_multiplier = min(
		1.0 + nearby_count * swarm_speed_bonus,
		max_swarm_multiplier
	)

# ============================================================
# 节拍响应
# ============================================================

func _on_beat(_beat_index: int) -> void:
	# 强拍时短暂"冻结"（与玩家施法错位）
	# 基类已处理 move_on_offbeat 逻辑
	pass

# ============================================================
# 死亡效果：快速碎裂消散
# ============================================================

func _on_death_effect() -> void:
	# Static 死亡无特殊区域效果，仅视觉碎裂
	pass
