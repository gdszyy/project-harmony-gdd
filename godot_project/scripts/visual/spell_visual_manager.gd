## spell_visual_manager.gd
## 法术视觉管理器
##
## 职责：
## 1. 管理施法时的粒子爆发效果
## 2. 实现和弦法术的视觉增强
## 3. 处理法术弹体的音色视觉修饰
## 4. 管理法术命中的视觉反馈
class_name SpellVisualManager
extends Node2D

# ============================================================
# 配置
# ============================================================

## 施法爆发粒子数量
@export var cast_burst_amount: int = 32
@export var cast_burst_lifetime: float = 0.6

## 和弦施法增强
@export var chord_burst_amount: int = 48
@export var chord_burst_lifetime: float = 0.8

## 命中反馈
@export var hit_spark_amount: int = 12
@export var hit_spark_lifetime: float = 0.3

# ============================================================
# 音色色彩映射
# ============================================================
const TIMBRE_COLORS: Dictionary = {
	0: Color(0.0, 1.0, 0.83),   # 默认：谐振青
	1: Color(0.8, 0.6, 0.2),    # 弦乐：温暖金色
	2: Color(0.4, 0.7, 1.0),    # 管乐：天蓝色
	3: Color(1.0, 0.4, 0.2),    # 打击：火焰橙
	4: Color(0.6, 0.4, 1.0),    # 键盘：薰衣草紫
}

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_connect_signals()

func _connect_signals() -> void:
	var ss = get_node_or_null("/root/SpellcraftSystem")
	if ss:
		if ss.has_signal("spell_cast"):
			ss.spell_cast.connect(_on_spell_cast)
		if ss.has_signal("chord_cast"):
			ss.chord_cast.connect(_on_chord_cast)
		if ss.has_signal("spell_hit"):
			ss.spell_hit.connect(_on_spell_hit)

# ============================================================
# 施法视觉效果
# ============================================================

func _on_spell_cast(spell_data: Dictionary) -> void:
	var pos: Vector2 = spell_data.get("position", Vector2.ZERO)
	var timbre: int = spell_data.get("timbre", 0)
	var color: Color = TIMBRE_COLORS.get(timbre, TIMBRE_COLORS[0])
	_create_cast_burst_particles(pos, color)

func _on_chord_cast(chord_data: Dictionary) -> void:
	var pos: Vector2 = chord_data.get("position", Vector2.ZERO)
	var timbre: int = chord_data.get("timbre", 0)
	var color: Color = TIMBRE_COLORS.get(timbre, TIMBRE_COLORS[0])
	var chord_type: String = chord_data.get("chord_type", "major")
	_create_chord_burst_particles(pos, color, chord_type)

func _on_spell_hit(hit_data: Dictionary) -> void:
	var pos: Vector2 = hit_data.get("position", Vector2.ZERO)
	var timbre: int = hit_data.get("timbre", 0)
	var color: Color = TIMBRE_COLORS.get(timbre, TIMBRE_COLORS[0])
	_create_hit_spark_particles(pos, color)

# ============================================================
# 粒子创建
# ============================================================

func _create_cast_burst_particles(pos: Vector2, color: Color) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = cast_burst_amount
	particles.lifetime = cast_burst_lifetime
	particles.explosiveness = 1.0

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 5.0
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 200.0
	mat.damping_min = 100.0
	mat.damping_max = 200.0
	mat.scale_min = 1.0
	mat.scale_max = 3.0

	# 颜色渐变：从亮色到透明
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 1.0))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	particles.process_material = mat
	particles.position = pos
	add_child(particles)
	particles.emitting = true

	# 自动清理
	get_tree().create_timer(cast_burst_lifetime + 0.5).timeout.connect(particles.queue_free)
	return particles

func _create_chord_burst_particles(pos: Vector2, color: Color, chord_type: String) -> void:
	# 和弦施法：更大规模的粒子爆发 + 环形波
	
	# 主爆发
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = chord_burst_amount
	particles.lifetime = chord_burst_lifetime
	particles.explosiveness = 1.0

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 8.0
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 120.0
	mat.initial_velocity_max = 300.0
	mat.damping_min = 80.0
	mat.damping_max = 150.0
	mat.scale_min = 1.5
	mat.scale_max = 4.0

	# 和弦类型影响颜色渐变
	var secondary_color := color
	match chord_type:
		"major":
			secondary_color = Color(color.r + 0.2, color.g + 0.1, color.b, 1.0).clamp()
		"minor":
			secondary_color = Color(color.r - 0.1, color.g, color.b + 0.2, 1.0).clamp()
		"diminished":
			secondary_color = Color(color.r + 0.3, color.g - 0.1, color.b - 0.1, 1.0).clamp()
		"augmented":
			secondary_color = Color(color.r, color.g + 0.2, color.b + 0.2, 1.0).clamp()

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))  # 白色核心
	gradient.add_point(0.2, Color(color.r, color.g, color.b, 1.0))
	gradient.add_point(0.6, Color(secondary_color.r, secondary_color.g, secondary_color.b, 0.6))
	gradient.set_color(1, Color(secondary_color.r, secondary_color.g, secondary_color.b, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	particles.process_material = mat
	particles.position = pos
	add_child(particles)
	particles.emitting = true

	# 环形冲击波
	_create_shockwave_ring(pos, color)

	# 自动清理
	get_tree().create_timer(chord_burst_lifetime + 0.5).timeout.connect(particles.queue_free)

func _create_hit_spark_particles(pos: Vector2, color: Color) -> void:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = hit_spark_amount
	particles.lifetime = hit_spark_lifetime
	particles.explosiveness = 1.0

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 100.0
	mat.damping_min = 150.0
	mat.damping_max = 300.0
	mat.scale_min = 0.5
	mat.scale_max = 1.5

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.3, Color(color.r, color.g, color.b, 0.8))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	particles.process_material = mat
	particles.position = pos
	add_child(particles)
	particles.emitting = true

	# 自动清理
	get_tree().create_timer(hit_spark_lifetime + 0.5).timeout.connect(particles.queue_free)

func _create_shockwave_ring(pos: Vector2, color: Color) -> void:
	# 环形冲击波效果（使用 Polygon2D 动画）
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	var segments := 32
	var radius := 5.0
	for i in range(segments + 1):
		var angle := TAU / segments * i
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	ring.polygon = points
	ring.color = Color(color.r, color.g, color.b, 0.6)
	ring.position = pos
	add_child(ring)

	# 扩展动画
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(15, 15), 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "color:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)

# ============================================================
# 公共接口
# ============================================================

## 手动触发施法爆发（用于测试）
func trigger_test_burst(pos: Vector2, timbre: int = 0) -> void:
	var color: Color = TIMBRE_COLORS.get(timbre, TIMBRE_COLORS[0])
	_create_cast_burst_particles(pos, color)

## 手动触发和弦爆发（用于测试）
func trigger_test_chord_burst(pos: Vector2, timbre: int = 0, chord_type: String = "major") -> void:
	var color: Color = TIMBRE_COLORS.get(timbre, TIMBRE_COLORS[0])
	_create_chord_burst_particles(pos, color, chord_type)
