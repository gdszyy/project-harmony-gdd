## visual_enhancer_base.gd
## 视觉增强器基类
## 所有实体的视觉增强器都继承自此类
class_name VisualEnhancerBase
extends Node

# ============================================================
# 配置
# ============================================================

## 目标视觉节点（Polygon2D 或 Sprite2D）
@export var visual_node_path: NodePath = ""

## 是否启用节拍脉冲
@export var beat_pulse_enabled: bool = true

## 节拍脉冲强度
@export var beat_pulse_scale: float = 0.1

# ============================================================
# 状态
# ============================================================
var _visual_node: CanvasItem = null
var _shader_material: ShaderMaterial = null
var _base_scale: Vector2 = Vector2.ONE
var _beat_pulse_timer: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	if not visual_node_path.is_empty():
		_visual_node = get_node_or_null(visual_node_path)
	else:
		# 自动查找第一个 CanvasItem 子节点
		for child in get_parent().get_children():
			if child is Polygon2D or child is Sprite2D:
				_visual_node = child
				break

	if _visual_node and _visual_node.material is ShaderMaterial:
		_shader_material = _visual_node.material as ShaderMaterial

	if _visual_node:
		_base_scale = _visual_node.scale

	_connect_beat_signal()

func _process(delta: float) -> void:
	_update_beat_pulse(delta)
	_update_visual(delta)

# ============================================================
# 虚函数（子类重写）
# ============================================================

## 子类重写：每帧视觉更新
func _update_visual(_delta: float) -> void:
	pass

## 子类重写：节拍触发时的视觉响应
func _on_beat_visual() -> void:
	pass

# ============================================================
# 节拍脉冲
# ============================================================

func _connect_beat_signal() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("beat_tick"):
		gm.beat_tick.connect(_on_beat_tick)

func _on_beat_tick() -> void:
	if beat_pulse_enabled:
		_beat_pulse_timer = 1.0
	_on_beat_visual()

func _update_beat_pulse(delta: float) -> void:
	if not beat_pulse_enabled or _visual_node == null:
		return

	if _beat_pulse_timer > 0.0:
		_beat_pulse_timer = maxf(_beat_pulse_timer - delta * 4.0, 0.0)
		var pulse := _beat_pulse_timer * beat_pulse_scale
		_visual_node.scale = _base_scale * (1.0 + pulse)
	else:
		_visual_node.scale = _base_scale

# ============================================================
# Shader 参数接口
# ============================================================

func set_shader_param(param_name: String, value: Variant) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter(param_name, value)

func get_shader_param(param_name: String) -> Variant:
	if _shader_material:
		return _shader_material.get_shader_parameter(param_name)
	return null

## 获取视觉节点引用
func get_visual_node() -> CanvasItem:
	return _visual_node

## 获取 Shader 材质引用
func get_shader_material() -> ShaderMaterial:
	return _shader_material
