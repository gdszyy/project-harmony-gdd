## damage_number.gd — 多类型伤害数字系统
## 对象池化，支持普通/暴击/不和谐自伤/治疗/完美节拍 五种类型
## 每种类型有独特的颜色、动画轨迹和 Shader 效果
## 使用 ShaderMaterial 实现故障/流淌/辉光特效
class_name DamageNumber
extends Node2D

# ============================================================
# 伤害类型枚举
# ============================================================
enum DamageType {
	NORMAL,      ## 普通伤害：晶体白，上浮消散
	CRITICAL,    ## 暴击伤害：圣光金，波纹+故障
	DISSONANCE,  ## 不和谐自伤：腐蚀紫，向下流淌
	HEAL,        ## 治疗：治愈绿，光点汇聚+上浮
	PERFECT,     ## 完美节拍：圣光金，波纹+故障+放大
}

# ============================================================
# 配置
# ============================================================
const DISPLAY_DURATION: float = 1.0
const FLOAT_SPEED: float = 50.0
const HORIZONTAL_SPREAD: float = 20.0

# 颜色
var COLOR_CORRUPT_PURPLE := UIColors.CORRUPT_PURPLE     # #8800FF
var COLOR_HEAL_GREEN     := UIColors.HEAL_GREEN     # #66FFB2

# 字体大小
const FONT_SIZE_NORMAL: int = 22
const FONT_SIZE_CRIT: int = 32
const FONT_SIZE_HEAL: int = 20

# ============================================================
# 节点引用
# ============================================================
var _label: Label = null
var _shader_material: ShaderMaterial = null

# ============================================================
# 状态
# ============================================================
var _is_active: bool = false
var _timer: float = 0.0
var _start_position: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _damage_type: DamageType = DamageType.NORMAL
var _damage_value: float = 0.0
var _initial_scale: Vector2 = Vector2.ONE
var _ripple_nodes: Array[Node2D] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_label()

func _process(delta: float) -> void:
	if not _is_active:
		return

	_timer += delta

	if _timer >= DISPLAY_DURATION:
		_deactivate()
		return

	var progress := _timer / DISPLAY_DURATION

	# 更新位置
	position += _velocity * delta

	# 减速
	_velocity *= (1.0 - delta * 2.0)

	# 更新着色器
	if _shader_material:
		_shader_material.set_shader_parameter("progress", progress)
		_shader_material.set_shader_parameter("time_sec", _timer)

	# 更新视觉效果
	_update_visual(progress)

# ============================================================
# 设置
# ============================================================

func _setup_label() -> void:
	if _label != null:
		return
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	add_child(_label)

	# 加载着色器
	var shader := load("res://shaders/damage_number.gdshader")
	if shader:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = shader
		_label.material = _shader_material

# ============================================================
# 公共接口
# ============================================================

## 显示伤害数字
func show_damage(damage: float, pos: Vector2, type: DamageType = DamageType.NORMAL) -> void:
	_is_active = true
	_timer = 0.0
	_damage_value = damage
	_damage_type = type
	_start_position = pos
	global_position = pos

	# 随机横向偏移
	var h_offset := randf_range(-HORIZONTAL_SPREAD, HORIZONTAL_SPREAD)

	# 根据类型设置
	match type:
		DamageType.NORMAL:
			_velocity = Vector2(h_offset * 0.3, -FLOAT_SPEED)
			_label.text = str(int(damage))
			_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
			_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
			_initial_scale = Vector2.ONE

		DamageType.CRITICAL:
			_velocity = Vector2(h_offset * 0.2, -FLOAT_SPEED * 0.3)
			_label.text = str(int(damage))
			_label.add_theme_font_size_override("font_size", FONT_SIZE_CRIT)
			_label.add_theme_color_override("font_color", UIColors.GOLD)
			_initial_scale = Vector2(1.2, 1.2)
			_spawn_ripple()

		DamageType.PERFECT:
			_velocity = Vector2(h_offset * 0.2, -FLOAT_SPEED * 0.3)
			_label.text = str(int(damage))
			_label.add_theme_font_size_override("font_size", FONT_SIZE_CRIT)
			_label.add_theme_color_override("font_color", UIColors.GOLD)
			_initial_scale = Vector2(1.3, 1.3)
			_spawn_ripple()

		DamageType.DISSONANCE:
			_velocity = Vector2(h_offset * 0.3, FLOAT_SPEED * 0.8)
			_label.text = str(int(damage))
			_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
			_label.add_theme_color_override("font_color", COLOR_CORRUPT_PURPLE)
			_initial_scale = Vector2.ONE

		DamageType.HEAL:
			_velocity = Vector2(h_offset * 0.2, -FLOAT_SPEED * 0.6)
			_label.text = "+" + str(int(damage))
			_label.add_theme_font_size_override("font_size", FONT_SIZE_HEAL)
			_label.add_theme_color_override("font_color", COLOR_HEAL_GREEN)
			_initial_scale = Vector2.ONE

	scale = _initial_scale

	# 设置着色器类型
	if _shader_material:
		_shader_material.set_shader_parameter("damage_type", type)
		_shader_material.set_shader_parameter("progress", 0.0)

	visible = true

## 停用（返回对象池）
func _deactivate() -> void:
	_is_active = false
	visible = false
	_clear_ripples()

## 检查是否激活
func is_active() -> bool:
	return _is_active

## 重置状态（对象池回收时调用）
func reset() -> void:
	_is_active = false
	_timer = 0.0
	_damage_value = 0.0
	_damage_type = DamageType.NORMAL
	_velocity = Vector2.ZERO
	visible = false
	scale = Vector2.ONE
	if _label:
		_label.position = Vector2.ZERO
		_label.modulate.a = 1.0
		_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	if _shader_material:
		_shader_material.set_shader_parameter("progress", 0.0)
		_shader_material.set_shader_parameter("damage_type", 0)
	_clear_ripples()

# ============================================================
# 视觉效果
# ============================================================

func _update_visual(progress: float) -> void:
	match _damage_type:
		DamageType.NORMAL:
			# 线性淡出
			modulate.a = 1.0 - progress

		DamageType.CRITICAL, DamageType.PERFECT:
			# 短暂停留 -> 放大 -> 快速消散
			if progress < 0.2:
				# 停留并微微放大
				scale = _initial_scale * (1.0 + progress * 0.5)
				modulate.a = 1.0
			else:
				# 快速消散
				var fade_progress := (progress - 0.2) / 0.8
				scale = _initial_scale * (1.1 - fade_progress * 0.3)
				modulate.a = 1.0 - fade_progress

			# 故障抖动
			if randf() < 0.08 * (1.0 - progress):
				_label.position.x = randf_range(-3.0, 3.0)
			else:
				_label.position.x = 0.0

		DamageType.DISSONANCE:
			# 向下流淌 + 拉伸
			modulate.a = 1.0 - progress
			scale.y = 1.0 + progress * 0.6
			scale.x = 1.0 - progress * 0.2

		DamageType.HEAL:
			# 汇聚 -> 上浮淡出
			if progress < 0.3:
				# 汇聚阶段
				scale = Vector2.ONE * (0.5 + progress * 1.5)
				modulate.a = progress / 0.3
			else:
				# 上浮淡出
				var fade_progress := (progress - 0.3) / 0.7
				modulate.a = 1.0 - fade_progress

	# 更新波纹
	_update_ripples(progress)

## 生成暴击波纹
func _spawn_ripple() -> void:
	_clear_ripples()
	# 使用简单的 Node2D 作为波纹标记（实际绘制在 _draw 中）
	for i in range(2):
		var ripple := Node2D.new()
		ripple.set_meta("start_delay", float(i) * 0.1)
		ripple.set_meta("radius", 0.0)
		ripple.set_meta("alpha", 1.0)
		add_child(ripple)
		_ripple_nodes.append(ripple)
	queue_redraw()

func _update_ripples(progress: float) -> void:
	if _ripple_nodes.is_empty():
		return
	for ripple in _ripple_nodes:
		var delay: float = ripple.get_meta("start_delay", 0.0)
		var ripple_progress := clamp((progress - delay) / 0.5, 0.0, 1.0)
		ripple.set_meta("radius", ripple_progress * 40.0)
		ripple.set_meta("alpha", (1.0 - ripple_progress) * 0.5)
	queue_redraw()

func _clear_ripples() -> void:
	for ripple in _ripple_nodes:
		if is_instance_valid(ripple):
			ripple.queue_free()
	_ripple_nodes.clear()

func _draw() -> void:
	if not _is_active:
		return
	# 绘制暴击波纹
	if _damage_type == DamageType.CRITICAL or _damage_type == DamageType.PERFECT:
		for ripple in _ripple_nodes:
			if not is_instance_valid(ripple):
				continue
			var r: float = ripple.get_meta("radius", 0.0)
			var a: float = ripple.get_meta("alpha", 0.0)
			if r > 0.1 and a > 0.01:
				var ripple_color := UIColors.with_alpha(UIColors.GOLD, a)
				_draw_ring(Vector2.ZERO, r, 1.5, ripple_color)

	# 治疗光点汇聚
	if _damage_type == DamageType.HEAL:
		var progress := _timer / DISPLAY_DURATION
		if progress < 0.3:
			var converge := progress / 0.3
			for i in range(6):
				var angle := (TAU / 6.0) * float(i)
				var dist := 30.0 * (1.0 - converge)
				var p := Vector2.from_angle(angle) * dist
				var dot_alpha := (1.0 - converge) * 0.6
				draw_circle(p, 2.0, UIColors.with_alpha(COLOR_HEAL_GREEN, dot_alpha))

func _draw_ring(center: Vector2, radius: float, width: float, color: Color) -> void:
	var segments := 32
	for i in range(segments):
		var a1 := (TAU / segments) * i
		var a2 := (TAU / segments) * (i + 1)
		var p1 := center + Vector2.from_angle(a1) * radius
		var p2 := center + Vector2.from_angle(a2) * radius
		draw_line(p1, p2, color, width, true)
