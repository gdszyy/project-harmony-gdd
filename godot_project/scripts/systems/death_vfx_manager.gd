## death_vfx_manager.gd
## 死亡特效管理器 — 统一管理敌人死亡时的视觉效果
## 使用对象池避免频繁实例化，支持不同敌人类型的差异化特效。
## 设计参考：敌人死亡 = "信号崩溃"，视觉上模拟老式电视关机效果。
extends Node2D

# ============================================================
# 特效配置
# ============================================================
## 粒子碎片数量（每次死亡）
@export var fragment_count: int = 6
## 碎片最大速度
@export var fragment_speed: float = 200.0
## 碎片存活时间
@export var fragment_lifetime: float = 0.4
## 闪光持续时间
@export var flash_duration: float = 0.1
## 对象池大小
@export var pool_size: int = 50

# ============================================================
# 敌人类型特效配置
# ============================================================
const TYPE_VFX_CONFIG: Dictionary = {
	"static": {
		"fragments": 4,
		"speed": 150.0,
		"color": Color(1.0, 0.2, 0.3),
		"fragment_shape": "triangle",
		"screen_shake": 0.0,
	},
	"silence": {
		"fragments": 8,
		"speed": 80.0,
		"color": Color(0.15, 0.05, 0.25),
		"fragment_shape": "circle",
		"screen_shake": 0.3,
		"implode": true,  # 内爆效果
	},
	"screech": {
		"fragments": 10,
		"speed": 300.0,
		"color": Color(1.0, 0.9, 0.2),
		"fragment_shape": "spike",
		"screen_shake": 0.2,
		"burst_ring": true,  # 爆发环
	},
	"pulse": {
		"fragments": 6,
		"speed": 200.0,
		"color": Color(0.2, 0.6, 1.0),
		"fragment_shape": "square",
		"screen_shake": 0.15,
		"ripple": true,  # 涟漪效果
	},
	"wall": {
		"fragments": 12,
		"speed": 120.0,
		"color": Color(0.4, 0.35, 0.5),
		"fragment_shape": "rectangle",
		"screen_shake": 0.5,
		"quake_ring": true,  # 地震环
	},
}

# ============================================================
# 对象池
# ============================================================
var _fragment_pool: Array[Polygon2D] = []
var _pool_index: int = 0

# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	_init_fragment_pool()
	# 连接全局敌人死亡信号
	if GameManager.has_signal("enemy_killed"):
		GameManager.enemy_killed.connect(_on_enemy_killed_global)

func _init_fragment_pool() -> void:
	for i in range(pool_size):
		var frag := Polygon2D.new()
		frag.polygon = PackedVector2Array([
			Vector2(-3, -3), Vector2(3, -1), Vector2(1, 3), Vector2(-2, 2)
		])
		frag.visible = false
		add_child(frag)
		_fragment_pool.append(frag)

# ============================================================
# 公共接口
# ============================================================

## 播放敌人死亡特效
func play_death_effect(pos: Vector2, enemy_type: String) -> void:
	var config: Dictionary = TYPE_VFX_CONFIG.get(enemy_type, TYPE_VFX_CONFIG["static"])

	# 1. 碎片爆散
	_spawn_fragments(pos, config)

	# 2. 闪光
	_spawn_flash(pos, config)

	# 3. 特殊效果
	if config.get("burst_ring", false):
		_spawn_burst_ring(pos, config)
	if config.get("implode", false):
		_spawn_implode_effect(pos, config)
	if config.get("ripple", false):
		_spawn_ripple(pos, config)
	if config.get("quake_ring", false):
		_spawn_quake_ring(pos, config)

	# 4. 屏幕震动
	var shake_strength: float = config.get("screen_shake", 0.0)
	if shake_strength > 0.0:
		_trigger_screen_shake(shake_strength)

func _on_enemy_killed_global(_pos: Vector2) -> void:
	# 全局信号不携带类型信息，使用默认特效
	# 实际的类型特效由 enemy_base._die() → _on_death_effect() 触发
	pass

# ============================================================
# 碎片系统
# ============================================================

func _spawn_fragments(pos: Vector2, config: Dictionary) -> void:
	var count: int = config.get("fragments", fragment_count)
	var speed: float = config.get("speed", fragment_speed)
	var color: Color = config.get("color", Color.WHITE)
	var shape_type: String = config.get("fragment_shape", "triangle")

	for i in range(count):
		var frag := _get_pooled_fragment()
		if frag == null:
			continue

		# 设置形状
		frag.polygon = _get_fragment_shape(shape_type)
		frag.color = color
		frag.modulate = Color.WHITE
		frag.visible = true
		frag.global_position = pos
		frag.rotation = randf() * TAU
		frag.scale = Vector2(1.0, 1.0)

		# 随机方向和速度
		var angle := (TAU / count) * i + randf_range(-0.3, 0.3)
		var dir := Vector2.from_angle(angle)
		var vel := dir * speed * randf_range(0.6, 1.0)

		# 动画
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(frag, "global_position",
			frag.global_position + vel * fragment_lifetime, fragment_lifetime
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(frag, "modulate:a", 0.0, fragment_lifetime)
		tween.tween_property(frag, "rotation", frag.rotation + randf_range(-PI, PI), fragment_lifetime)
		tween.tween_property(frag, "scale", Vector2(0.1, 0.1), fragment_lifetime)
		tween.chain()
		tween.tween_callback(func(): frag.visible = false)

func _get_pooled_fragment() -> Polygon2D:
	for i in range(pool_size):
		var idx := (_pool_index + i) % pool_size
		if not _fragment_pool[idx].visible:
			_pool_index = (idx + 1) % pool_size
			return _fragment_pool[idx]
	# 池满，覆盖最旧的
	_pool_index = (_pool_index + 1) % pool_size
	return _fragment_pool[_pool_index]

func _get_fragment_shape(shape_type: String) -> PackedVector2Array:
	match shape_type:
		"triangle":
			return PackedVector2Array([
				Vector2(0, -4), Vector2(3, 2), Vector2(-3, 2)
			])
		"square":
			return PackedVector2Array([
				Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
			])
		"spike":
			return PackedVector2Array([
				Vector2(0, -6), Vector2(2, -1), Vector2(1, 3), Vector2(-1, 3), Vector2(-2, -1)
			])
		"circle":
			var points := PackedVector2Array()
			for j in range(8):
				var angle := (TAU / 8.0) * j
				points.append(Vector2.from_angle(angle) * 3.0)
			return points
		"rectangle":
			return PackedVector2Array([
				Vector2(-5, -3), Vector2(5, -3), Vector2(5, 3), Vector2(-5, 3)
			])
		_:
			return PackedVector2Array([
				Vector2(-3, -3), Vector2(3, -1), Vector2(1, 3), Vector2(-2, 2)
			])

# ============================================================
# 闪光效果
# ============================================================

func _spawn_flash(pos: Vector2, config: Dictionary) -> void:
	var color: Color = config.get("color", Color.WHITE)

	var flash := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(8):
		var angle := (TAU / 8.0) * i
		var r := 15.0 if i % 2 == 0 else 8.0
		points.append(Vector2.from_angle(angle) * r)
	flash.polygon = points
	flash.color = Color.WHITE
	flash.modulate = Color(color.r, color.g, color.b, 0.8)
	flash.global_position = pos
	add_child(flash)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2.5, 2.5), flash_duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, flash_duration * 1.5)
	tween.chain()
	tween.tween_callback(flash.queue_free)

# ============================================================
# 特殊效果
# ============================================================

func _spawn_burst_ring(pos: Vector2, config: Dictionary) -> void:
	var color: Color = config.get("color", Color.YELLOW)
	var ring := _create_ring(pos, color, 5.0)

	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(8.0, 8.0), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.chain()
	tween.tween_callback(ring.queue_free)

func _spawn_implode_effect(pos: Vector2, config: Dictionary) -> void:
	var color: Color = config.get("color", Color.PURPLE)
	var ring := _create_ring(pos, color, 40.0)
	ring.modulate.a = 0.0

	var tween := ring.create_tween()
	tween.set_parallel(true)
	# 从大到小（内爆）
	tween.tween_property(ring, "scale", Vector2(0.1, 0.1), 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(ring, "modulate:a", 0.8, 0.1)
	tween.chain()
	tween.tween_property(ring, "modulate:a", 0.0, 0.15)
	tween.chain()
	tween.tween_callback(ring.queue_free)

func _spawn_ripple(pos: Vector2, config: Dictionary) -> void:
	var color: Color = config.get("color", Color.CYAN)
	# 多层涟漪
	for i in range(3):
		var delay := i * 0.08
		get_tree().create_timer(delay).timeout.connect(func():
			var ring := _create_ring(pos, color, 3.0)
			ring.modulate.a = 0.6 - i * 0.15
			var tween := ring.create_tween()
			tween.set_parallel(true)
			tween.tween_property(ring, "scale", Vector2(6.0 + i * 2.0, 6.0 + i * 2.0), 0.35)
			tween.tween_property(ring, "modulate:a", 0.0, 0.4)
			tween.chain()
			tween.tween_callback(ring.queue_free)
		)

func _spawn_quake_ring(pos: Vector2, config: Dictionary) -> void:
	var color: Color = config.get("color", Color.GRAY)
	var ring := _create_ring(pos, color, 8.0)

	# 粗重的地震环
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(12.0, 12.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ring, "modulate:a", 0.0, 0.6)
	tween.chain()
	tween.tween_callback(ring.queue_free)

func _create_ring(pos: Vector2, color: Color, radius: float) -> Polygon2D:
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	var segments := 20
	for i in range(segments):
		var angle := (TAU / segments) * i
		points.append(Vector2.from_angle(angle) * radius)
	ring.polygon = points
	ring.color = color
	ring.global_position = pos
	add_child(ring)
	return ring

# ============================================================
# 屏幕震动
# ============================================================

func _trigger_screen_shake(intensity: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	var original_offset := camera.offset
	var shake_tween := create_tween()
	var shake_count := 4
	var shake_duration := 0.05

	for i in range(shake_count):
		var offset := Vector2(
			randf_range(-intensity * 10.0, intensity * 10.0),
			randf_range(-intensity * 10.0, intensity * 10.0)
		)
		shake_tween.tween_property(camera, "offset", original_offset + offset, shake_duration)

	shake_tween.tween_property(camera, "offset", original_offset, shake_duration)
