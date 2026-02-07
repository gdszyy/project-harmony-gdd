## player_visual_enhanced.gd
## 玩家视觉完善 (Issue #12)
## 正十二面体能量核心 + 三道旋转金环 + 节拍脉冲 + 神圣几何 Shader
extends Node2D

# ============================================================
# 配置
# ============================================================
## 核心大小
@export var core_size: float = 32.0
## 金环半径
@export var ring_radii: Array[float] = [40.0, 50.0, 60.0]
## 金环旋转速度（度/秒）
@export var ring_speeds: Array[float] = [30.0, -45.0, 60.0]
## 节拍脉冲强度
@export var beat_pulse_strength: float = 0.15

# ============================================================
# 节点引用
# ============================================================
var _core: Node2D = null
var _rings: Array[Node2D] = []
var _glow_particles: CPUParticles2D = null

# ============================================================
# 状态
# ============================================================
var _time: float = 0.0
var _beat_pulse: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_core()
	_setup_rings()
	_setup_particles()
	
	# 连接信号
	if GameManager.has_signal("beat_tick"):
		GameManager.beat_tick.connect(_on_beat_tick)

func _process(delta: float) -> void:
	_time += delta
	_update_core(delta)
	_update_rings(delta)
	_update_beat_pulse(delta)

# ============================================================
# 核心设置
# ============================================================

func _setup_core() -> void:
	_core = Node2D.new()
	_core.name = "Core"
	add_child(_core)
	
	# 创建正十二面体的2D投影（简化为正十二边形）
	var dodecagon := Polygon2D.new()
	var points: PackedVector2Array = []
	var sides := 12
	for i in range(sides):
		var angle := (TAU / sides) * i
		var point := Vector2.from_angle(angle) * core_size
		points.append(point)
	
	dodecagon.polygon = points
	dodecagon.color = Color(0.0, 0.9, 0.7, 0.9)
	
	# 应用神圣几何 Shader
	var shader := load("res://shaders/sacred_geometry.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		dodecagon.material = mat
	
	_core.add_child(dodecagon)
	
	# 添加边框
	var outline := Line2D.new()
	outline.points = points
	outline.closed = true
	outline.width = 2.0
	outline.default_color = Color(0.0, 1.0, 0.8, 1.0)
	_core.add_child(outline)

# ============================================================
# 金环设置
# ============================================================

func _setup_rings() -> void:
	for i in range(3):
		var ring := _create_ring(ring_radii[i], ring_speeds[i])
		ring.name = "Ring%d" % i
		_rings.append(ring)
		add_child(ring)

func _create_ring(radius: float, _speed: float) -> Node2D:
	var ring := Node2D.new()
	
	# 创建环形（使用多个小段）
	var segments := 64
	var line := Line2D.new()
	var points: PackedVector2Array = []
	
	for i in range(segments + 1):
		var angle := (TAU / segments) * i
		var point := Vector2.from_angle(angle) * radius
		points.append(point)
	
	line.points = points
	line.width = 3.0
	line.default_color = Color(1.0, 0.8, 0.0, 0.6)  # 金色
	
	# 添加发光效果
	line.antialiased = true
	
	ring.add_child(line)
	
	return ring

# ============================================================
# 粒子效果
# ============================================================

func _setup_particles() -> void:
	_glow_particles = CPUParticles2D.new()
	_glow_particles.name = "GlowParticles"
	_glow_particles.emitting = true
	_glow_particles.amount = 20
	_glow_particles.lifetime = 1.0
	_glow_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_glow_particles.emission_sphere_radius = core_size
	_glow_particles.direction = Vector2(0, -1)
	_glow_particles.spread = 180.0
	_glow_particles.gravity = Vector2.ZERO
	_glow_particles.initial_velocity_min = 10.0
	_glow_particles.initial_velocity_max = 30.0
	_glow_particles.scale_amount_min = 2.0
	_glow_particles.scale_amount_max = 4.0
	_glow_particles.color = Color(0.0, 0.9, 0.7, 0.5)
	
	add_child(_glow_particles)

# ============================================================
# 更新
# ============================================================

func _update_core(delta: float) -> void:
	if _core == null:
		return
	
	# 缓慢旋转
	_core.rotation += delta * 0.5
	
	# 节拍脉冲缩放
	var pulse_scale := 1.0 + _beat_pulse * beat_pulse_strength
	_core.scale = Vector2(pulse_scale, pulse_scale)
	
	# 更新 Shader 参数
	var dodecagon := _core.get_child(0)
	if dodecagon and dodecagon.material is ShaderMaterial:
		var mat: ShaderMaterial = dodecagon.material
		mat.set_shader_parameter("time", _time)
		mat.set_shader_parameter("beat_energy", _beat_pulse)

func _update_rings(delta: float) -> void:
	for i in range(_rings.size()):
		if i >= ring_speeds.size():
			continue
		
		var ring := _rings[i]
		var speed := ring_speeds[i]
		ring.rotation += deg_to_rad(speed) * delta
		
		# 节拍脉冲效果
		var pulse_scale := 1.0 + _beat_pulse * beat_pulse_strength * 0.5
		ring.scale = Vector2(pulse_scale, pulse_scale)
		
		# 透明度随节拍变化
		var line := ring.get_child(0) as Line2D
		if line:
			var alpha := 0.6 + _beat_pulse * 0.3
			line.default_color.a = alpha

func _update_beat_pulse(delta: float) -> void:
	# 节拍脉冲衰减
	_beat_pulse = max(0.0, _beat_pulse - delta * 3.0)

# ============================================================
# 受伤效果
# ============================================================

func apply_damage_effect() -> void:
	# 故障效果：快速闪烁和颜色变化
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(self, "modulate", Color(1.0, 0.3, 0.3), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.05)
	
	# 抖动效果
	var original_pos := position
	for i in range(5):
		await get_tree().create_timer(0.02).timeout
		position = original_pos + Vector2(randf_range(-3, 3), randf_range(-3, 3))
	position = original_pos

# ============================================================
# 信号回调
# ============================================================

func _on_beat_tick(_beat_index: int) -> void:
	# 触发节拍脉冲
	_beat_pulse = 1.0
	
	# 粒子爆发
	if _glow_particles:
		_glow_particles.emitting = true
