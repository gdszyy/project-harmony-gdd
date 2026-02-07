## damage_number.gd
## 伤害数字显示系统 (Issue #19)
## 对象池化的伤害数字，支持多种视觉效果
class_name DamageNumber
extends Node2D

# ============================================================
# 配置
# ============================================================
## 数字显示时长
const DISPLAY_DURATION: float = 1.0
## 上浮速度
const FLOAT_SPEED: float = 50.0
## 横向随机偏移范围
const HORIZONTAL_SPREAD: float = 20.0

# ============================================================
# 伤害类型枚举
# ============================================================
enum DamageType {
	NORMAL,      # 普通伤害：白色，上浮消散
	CRITICAL,    # 暴击：金色波纹 + 故障效果
	PERFECT,     # 完美节拍：金色波纹 + 故障效果
	DISSONANCE,  # 不和谐伤害：紫色，向下流淌
}

# ============================================================
# 节点引用
# ============================================================
var _label: Label = null

# ============================================================
# 状态
# ============================================================
var _is_active: bool = false
var _timer: float = 0.0
var _start_position: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _damage_type: DamageType = DamageType.NORMAL
var _damage_value: float = 0.0

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
	
	# 更新位置
	position += _velocity * delta
	
	# 更新视觉效果
	_update_visual_effect()

# ============================================================
# 设置
# ============================================================

func _setup_label() -> void:
	if _label == null:
		_label = Label.new()
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 24)
		add_child(_label)

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
	
	# 设置随机横向偏移
	var horizontal_offset := randf_range(-HORIZONTAL_SPREAD, HORIZONTAL_SPREAD)
	
	# 根据类型设置速度
	match type:
		DamageType.DISSONANCE:
			# 不和谐伤害向下流淌
			_velocity = Vector2(horizontal_offset * 0.5, FLOAT_SPEED)
		_:
			# 其他类型向上浮动
			_velocity = Vector2(horizontal_offset * 0.5, -FLOAT_SPEED)
	
	# 设置文本
	_label.text = str(int(damage))
	
	# 设置初始颜色
	_set_initial_color()
	
	# 显示
	visible = true

## 停用（返回对象池）
func _deactivate() -> void:
	_is_active = false
	visible = false

## 检查是否激活
func is_active() -> bool:
	return _is_active

# ============================================================
# 视觉效果
# ============================================================

func _set_initial_color() -> void:
	match _damage_type:
		DamageType.NORMAL:
			_label.add_theme_color_override("font_color", Color.WHITE)
		DamageType.CRITICAL, DamageType.PERFECT:
			_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))  # 金色
			_label.add_theme_font_size_override("font_size", 32)
		DamageType.DISSONANCE:
			_label.add_theme_color_override("font_color", Color(0.8, 0.0, 0.8))  # 紫色

func _update_visual_effect() -> void:
	var progress := _timer / DISPLAY_DURATION
	
	match _damage_type:
		DamageType.NORMAL:
			# 普通伤害：线性淡出
			_label.modulate.a = 1.0 - progress
		
		DamageType.CRITICAL, DamageType.PERFECT:
			# 暴击/完美节拍：金色波纹 + 故障效果
			_label.modulate.a = 1.0 - progress
			# 波纹缩放
			var pulse := 1.0 + sin(progress * PI * 4.0) * 0.1
			scale = Vector2(pulse, pulse)
			# 故障效果（随机偏移）
			if randf() < 0.1:
				_label.position.x = randf_range(-2.0, 2.0)
			else:
				_label.position.x = 0.0
		
		DamageType.DISSONANCE:
			# 不和谐伤害：向下流淌，渐变消失
			_label.modulate.a = 1.0 - progress
			# 拉伸效果
			scale.y = 1.0 + progress * 0.5
			scale.x = 1.0 - progress * 0.2

# ============================================================
# 对象池接口
# ============================================================

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
		_label.add_theme_font_size_override("font_size", 24)
