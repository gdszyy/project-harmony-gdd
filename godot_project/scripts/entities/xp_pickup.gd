## xp_pickup.gd
## 经验值拾取物 — 敌人死亡后掉落的和声碎片
## 视觉上是小型几何体，颜色随价值变化。
## 具有磁吸机制：靠近玩家时自动飞向玩家。
## 节拍同步：在强拍时微微脉冲发光。
extends Area2D

# ============================================================
# 信号
# ============================================================
signal collected(xp_value: int)

# ============================================================
# 配置
# ============================================================
@export var xp_value: int = 3
@export var attract_radius: float = 100.0
@export var attract_speed: float = 350.0
@export var max_attract_speed: float = 800.0
@export var collect_radius: float = 20.0
@export var lifetime: float = 15.0
@export var pop_force: float = 80.0

# ============================================================
# 颜色映射
# ============================================================
const COLOR_TIERS: Array[Dictionary] = [
	{ "min_xp": 0,  "color": Color(0.0, 1.0, 0.8, 0.85), "name": "common" },    # 青色
	{ "min_xp": 5,  "color": Color(0.2, 0.8, 1.0, 0.9),  "name": "uncommon" },   # 蓝色
	{ "min_xp": 10, "color": Color(0.6, 0.2, 1.0, 0.9),  "name": "rare" },       # 紫色
	{ "min_xp": 15, "color": Color(1.0, 0.85, 0.2, 0.95), "name": "epic" },      # 金色
]

# ============================================================
# 内部状态
# ============================================================
var _visual: Polygon2D = null
var _target: Node2D = null
var _is_attracting: bool = false
var _is_collected: bool = false
var _lifetime_timer: float = 0.0
var _pop_velocity: Vector2 = Vector2.ZERO
var _pop_timer: float = 0.0
var _beat_energy: float = 0.0
var _base_color: Color = Color.WHITE
var _rotation_speed: float = 2.0
var _bob_offset: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	add_to_group("xp_pickup")
	collision_layer = 4
	collision_mask = 1

	_create_visual()
	_create_collision()
	_connect_signals()

	# 初始弹出
	_pop_velocity = Vector2(
		randf_range(-pop_force, pop_force),
		randf_range(-pop_force, pop_force)
	)
	_pop_timer = 0.3

	_bob_offset = randf() * TAU
	_lifetime_timer = lifetime

func _create_visual() -> void:
	_visual = Polygon2D.new()

	# 根据 XP 值选择形状
	if xp_value >= 15:
		# 六角星（高价值）
		var points := PackedVector2Array()
		for i in range(6):
			var angle := (TAU / 6.0) * i - PI / 2.0
			var r := 7.0 if i % 2 == 0 else 4.0
			points.append(Vector2.from_angle(angle) * r)
		_visual.polygon = points
	elif xp_value >= 10:
		# 菱形（中高价值）
		_visual.polygon = PackedVector2Array([
			Vector2(0, -7), Vector2(5, 0), Vector2(0, 7), Vector2(-5, 0)
		])
	elif xp_value >= 5:
		# 正方形（中价值）
		_visual.polygon = PackedVector2Array([
			Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
		])
	else:
		# 三角形（低价值）
		_visual.polygon = PackedVector2Array([
			Vector2(0, -5), Vector2(4, 3), Vector2(-4, 3)
		])

	_base_color = _get_tier_color()
	_visual.color = _base_color
	add_child(_visual)

func _create_collision() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = collect_radius
	col.shape = shape
	add_child(col)

func _connect_signals() -> void:
	if GameManager.beat_tick.is_connected(_on_beat):
		return
	GameManager.beat_tick.connect(_on_beat)

func _get_tier_color() -> Color:
	var result_color := COLOR_TIERS[0]["color"]
	for tier in COLOR_TIERS:
		if xp_value >= tier["min_xp"]:
			result_color = tier["color"]
	return result_color

# ============================================================
# 每帧更新
# ============================================================

func _process(delta: float) -> void:
	if _is_collected:
		return

	# 生命周期
	_lifetime_timer -= delta
	if _lifetime_timer <= 0.0:
		_fade_out()
		return

	# 弹出阶段
	if _pop_timer > 0.0:
		_pop_timer -= delta
		global_position += _pop_velocity * delta
		_pop_velocity *= 0.9  # 阻尼
	else:
		# 磁吸逻辑
		_update_attraction(delta)

	# 视觉更新
	_update_visual(delta)

func _update_attraction(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player")
		if _target == null:
			return

	var dist := global_position.distance_to(_target.global_position)

	# 进入吸引范围
	if dist < attract_radius:
		_is_attracting = true

	if _is_attracting:
		var dir := (_target.global_position - global_position).normalized()
		# 越近越快（指数加速）
		var speed_mult := remap(dist, 0.0, attract_radius, 3.0, 1.0)
		speed_mult = clamp(speed_mult, 1.0, 3.0)
		var final_speed := min(attract_speed * speed_mult, max_attract_speed)

		global_position += dir * final_speed * delta

		# 收集判定
		if dist < collect_radius * 0.5:
			_collect()

func _collect() -> void:
	if _is_collected:
		return
	_is_collected = true

	collected.emit(xp_value)

	# 收集视觉：闪光 + 缩小消失
	if _visual:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_visual, "modulate", Color.WHITE, 0.05)
		tween.tween_property(_visual, "scale", Vector2(1.5, 1.5), 0.05)
		tween.chain()
		tween.set_parallel(true)
		tween.tween_property(_visual, "scale", Vector2(0.0, 0.0), 0.1)
		tween.tween_property(_visual, "modulate:a", 0.0, 0.1)
		tween.chain()
		tween.tween_callback(queue_free)
	else:
		queue_free()

func _fade_out() -> void:
	_is_collected = true  # 防止重复处理
	if _visual:
		var tween := create_tween()
		tween.tween_property(_visual, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
	else:
		queue_free()

# ============================================================
# 视觉更新
# ============================================================

func _update_visual(delta: float) -> void:
	if _visual == null:
		return

	# 旋转
	_visual.rotation += _rotation_speed * delta

	# 上下浮动
	var bob := sin(Time.get_ticks_msec() * 0.003 + _bob_offset) * 2.0
	_visual.position.y = bob

	# 节拍脉冲衰减
	_beat_energy = max(0.0, _beat_energy - delta * 5.0)

	# 颜色计算
	var color := _base_color
	color = color.lerp(Color.WHITE, _beat_energy * 0.4)

	# 吸引时颜色变亮
	if _is_attracting:
		color = color.lerp(Color.WHITE, 0.2)

	# 即将消失时闪烁
	if _lifetime_timer < 3.0:
		var flicker := sin(Time.get_ticks_msec() * 0.01) > 0.0
		if not flicker:
			color.a *= 0.4

	_visual.color = color

	# 脉冲缩放
	var pulse_scale := 1.0 + _beat_energy * 0.2
	_visual.scale = Vector2(pulse_scale, pulse_scale)

func _on_beat(_beat_index: int) -> void:
	_beat_energy = 1.0

# ============================================================
# 合并机制（供 Spawner 调用，合并附近的小经验球）
# ============================================================

static func merge_nearby_pickups(pickups: Array, merge_radius: float = 30.0) -> void:
	var to_remove: Array = []

	for i in range(pickups.size()):
		if i in to_remove:
			continue
		var a = pickups[i]
		if not is_instance_valid(a):
			continue

		for j in range(i + 1, pickups.size()):
			if j in to_remove:
				continue
			var b = pickups[j]
			if not is_instance_valid(b):
				continue

			if a.global_position.distance_to(b.global_position) < merge_radius:
				# 合并到 a
				a.xp_value += b.xp_value
				a._base_color = a._get_tier_color()
				to_remove.append(j)
				b.queue_free()

# ============================================================
# 工厂方法
# ============================================================

static func create(pos: Vector2, xp: int) -> Area2D:
	var pickup := load("res://scripts/entities/xp_pickup.gd").new() as Area2D
	if pickup == null:
		# Fallback：直接创建
		pickup = Area2D.new()
	pickup.global_position = pos
	pickup.set("xp_value", xp)
	return pickup
