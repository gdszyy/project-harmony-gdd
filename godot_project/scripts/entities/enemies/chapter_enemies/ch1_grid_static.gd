## ch1_grid_static.gd
## 第一章特色敌人：网格静电 (Grid Static)
## 基于 Static 的变体，移动轨迹被约束在场景的脉冲网格线上。
## 音乐隐喻：被毕达哥拉斯数学秩序约束的噪音，只能沿整数比例的路径行进。
## 视觉：与普通 Static 相似，但带有蓝白色的网格线发光效果。
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Grid Static 专属配置
# ============================================================
## 网格单元大小（像素）
@export var grid_cell_size: float = 64.0
## 在网格节点停留的时间（秒）
@export var grid_pause_duration: float = 0.15
## 网格移动速度倍率（沿网格线移动更快）
@export var grid_speed_multiplier: float = 1.4
## 群体加速（继承自 Static）
@export var swarm_speed_bonus: float = 0.04
@export var swarm_detect_radius: float = 80.0
@export var max_swarm_multiplier: float = 1.5
## 网格脉冲视觉强度
@export var grid_pulse_intensity: float = 0.6

# ============================================================
# 内部状态
# ============================================================
## 当前移动方向（仅四方向：上下左右）
var _grid_direction: Vector2 = Vector2.RIGHT
## 是否正在网格节点上暂停
var _grid_pausing: bool = false
## 网格暂停计时器
var _grid_pause_timer: float = 0.0
## 当前目标网格节点
var _target_grid_node: Vector2 = Vector2.ZERO
## 是否已到达目标节点
var _reached_target: bool = true
## 群体加速
var _swarm_speed_multiplier: float = 1.0
var _swarm_check_timer: float = 0.0
const SWARM_CHECK_INTERVAL: float = 0.5
## 网格视觉脉冲相位
var _grid_visual_phase: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.STATIC
	# 网格 Static 使用中等量化帧率（比普通 Static 低，更有"步进"感）
	quantized_fps = 12.0
	_quantize_interval = 1.0 / quantized_fps
	# 低击退抗性
	knockback_resistance = 0.05
	# 弱拍移动
	move_on_offbeat = true
	# 蓝白色调（网格/数学感）
	base_color = Color(0.4, 0.6, 1.0)
	# 中等故障
	base_glitch_intensity = 0.08
	max_glitch_intensity = 0.6
	
	# 初始化目标网格节点
	_target_grid_node = _snap_to_grid(global_position)

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 群体检测
	_swarm_check_timer += delta
	if _swarm_check_timer >= SWARM_CHECK_INTERVAL:
		_swarm_check_timer = 0.0
		_update_swarm_bonus()
	
	# 网格暂停逻辑
	if _grid_pausing:
		_grid_pause_timer -= delta
		if _grid_pause_timer <= 0.0:
			_grid_pausing = false
			_choose_next_grid_direction()
	
	# 网格视觉脉冲
	_grid_visual_phase += delta * 3.0
	if _sprite:
		var pulse := sin(_grid_visual_phase) * grid_pulse_intensity * 0.15
		var grid_glow := Color(0.3, 0.5, 1.0, 0.3 + pulse)
		_sprite.modulate = base_color.lerp(grid_glow, 0.2)

# ============================================================
# 移动逻辑：沿网格线移动
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _grid_pausing:
		return Vector2.ZERO
	
	if _reached_target:
		# 到达网格节点，暂停并选择新方向
		_grid_pausing = true
		_grid_pause_timer = grid_pause_duration
		return Vector2.ZERO
	
	# 向目标网格节点移动
	var to_target := _target_grid_node - global_position
	var dist := to_target.length()
	
	if dist < 4.0:
		# 到达目标节点
		global_position = _target_grid_node
		_reached_target = true
		return Vector2.ZERO
	
	# 沿网格方向移动
	var speed := move_speed * grid_speed_multiplier * _swarm_speed_multiplier
	velocity = _grid_direction * speed
	move_and_slide()
	return Vector2.ZERO

func _choose_next_grid_direction() -> void:
	if _target == null:
		# 无目标时随机选择方向
		var dirs := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		_grid_direction = dirs[randi() % 4]
	else:
		# 有目标时选择最接近玩家方向的网格方向
		var to_player := _target.global_position - global_position
		
		# 选择主轴方向（曼哈顿距离优先）
		var abs_x := abs(to_player.x)
		var abs_y := abs(to_player.y)
		
		if abs_x > abs_y:
			_grid_direction = Vector2.RIGHT if to_player.x > 0 else Vector2.LEFT
		else:
			_grid_direction = Vector2.DOWN if to_player.y > 0 else Vector2.UP
		
		# 20% 概率选择次轴方向（增加不可预测性）
		if randf() < 0.2:
			if abs_x > abs_y:
				_grid_direction = Vector2.DOWN if to_player.y > 0 else Vector2.UP
			else:
				_grid_direction = Vector2.RIGHT if to_player.x > 0 else Vector2.LEFT
	
	# 计算下一个网格节点
	_target_grid_node = _snap_to_grid(global_position + _grid_direction * grid_cell_size)
	_reached_target = false

# ============================================================
# 网格工具函数
# ============================================================

func _snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(
		round(pos.x / grid_cell_size) * grid_cell_size,
		round(pos.y / grid_cell_size) * grid_cell_size
	)

# ============================================================
# 群体加速
# ============================================================

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
# 节拍响应：网格脉冲
# ============================================================

func _on_beat(_beat_index: int) -> void:
	# 强拍时网格线发光脉冲
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(0.6, 0.8, 1.0), 0.05)
		tween.tween_property(_sprite, "modulate", base_color, 0.2)

# ============================================================
# 死亡效果：网格碎裂
# ============================================================

func _on_death_effect() -> void:
	# 死亡时沿网格线释放四方向脉冲
	pass
