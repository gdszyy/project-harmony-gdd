## phase_hud_tint_manager.gd
## 各相位下 HUD 色调变化管理器
## 在 HUD 根节点上附加色调偏移 Shader，根据相位切换调整色相、亮度、对比度
## 关联文档：Docs/UI_Design_Module6_ResonanceSlicing.md §8
extends Node

# ============================================================
# 常量
# ============================================================

## 色调过渡时间
const TINT_TRANSITION_DURATION: float = 0.3

## 相位色调参数
const PHASE_TINT_PARAMS: Dictionary = {
	0: {  # Fundamental — 无偏移（基准）
		"hue_shift": 0.0,
		"brightness_offset": 0.0,
		"contrast_offset": 0.0,
		"blur_amount": 0.0,
		"sharpen_amount": 0.0,
	},
	1: {  # Overtone — 冷色偏移
		"hue_shift": -0.08,
		"brightness_offset": 0.05,
		"contrast_offset": 0.05,
		"blur_amount": 0.0,
		"sharpen_amount": 0.3,
	},
	2: {  # SubBass — 暖色偏移
		"hue_shift": 0.08,
		"brightness_offset": -0.05,
		"contrast_offset": 0.1,
		"blur_amount": 0.5,
		"sharpen_amount": 0.0,
	},
}

# ============================================================
# 状态
# ============================================================

## 目标 HUD 节点（应为 CanvasLayer 或 Control）
var _target_node: CanvasItem = null
## Shader 材质
var _tint_material: ShaderMaterial = null
## 当前过渡 Tween
var _tween: Tween = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 连接 ResonanceSlicingManager 信号
	var rsm := get_node_or_null("/root/ResonanceSlicingManager")
	if rsm:
		rsm.phase_changed.connect(_on_phase_changed)
		rsm.spectrum_corruption_triggered.connect(_on_corruption_triggered)
		rsm.spectrum_corruption_cleared.connect(_on_corruption_cleared)

	# 延迟初始化（等待父节点准备好）
	call_deferred("_setup_tint_shader")

# ============================================================
# 初始化
# ============================================================

func _setup_tint_shader() -> void:
	# 查找目标节点（父节点或指定节点）
	_target_node = get_parent() as CanvasItem
	if _target_node == null:
		push_warning("PhaseHudTintManager: 父节点不是 CanvasItem，色调偏移将不可用")
		return

	# 加载 Shader
	var shader := load("res://shaders/ui/hud_phase_tint.gdshader")
	if shader == null:
		push_warning("PhaseHudTintManager: 无法加载 hud_phase_tint.gdshader")
		return

	# 创建材质
	_tint_material = ShaderMaterial.new()
	_tint_material.shader = shader
	_tint_material.set_shader_parameter("hue_shift", 0.0)
	_tint_material.set_shader_parameter("brightness_offset", 0.0)
	_tint_material.set_shader_parameter("contrast_offset", 0.0)
	_tint_material.set_shader_parameter("blur_amount", 0.0)
	_tint_material.set_shader_parameter("sharpen_amount", 0.0)

	# 附加到目标节点
	_target_node.material = _tint_material

# ============================================================
# 相位色调切换
# ============================================================

## 切换到指定相位的色调
func apply_phase_tint(phase: int) -> void:
	if _tint_material == null:
		return

	var params: Dictionary = PHASE_TINT_PARAMS.get(phase, PHASE_TINT_PARAMS[0])

	# 取消之前的 Tween
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(true)

	for param_name in params.keys():
		var target_value: float = params[param_name]
		_tween.tween_property(
			_tint_material,
			"shader_parameter/" + param_name,
			target_value,
			TINT_TRANSITION_DURATION
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

## 应用频谱失调色调（极端效果）
func apply_corruption_tint() -> void:
	if _tint_material == null:
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(true)

	# 频谱失调：强烈的品红色偏移 + 高对比度
	_tween.tween_property(_tint_material, "shader_parameter/hue_shift",
		0.15, 0.2).set_ease(Tween.EASE_IN)
	_tween.tween_property(_tint_material, "shader_parameter/brightness_offset",
		-0.1, 0.2).set_ease(Tween.EASE_IN)
	_tween.tween_property(_tint_material, "shader_parameter/contrast_offset",
		0.15, 0.2).set_ease(Tween.EASE_IN)

## 重置色调到基准状态
func reset_tint() -> void:
	apply_phase_tint(0)  # Fundamental = 基准

# ============================================================
# 信号回调
# ============================================================

func _on_phase_changed(new_phase: int) -> void:
	apply_phase_tint(new_phase)

func _on_corruption_triggered() -> void:
	apply_corruption_tint()

func _on_corruption_cleared() -> void:
	# 恢复到当前相位的色调
	var rsm := get_node_or_null("/root/ResonanceSlicingManager")
	if rsm:
		apply_phase_tint(rsm.current_phase)
	else:
		reset_tint()

# ============================================================
# 公共接口
# ============================================================

## 获取当前 Shader 材质（供外部调试）
func get_tint_material() -> ShaderMaterial:
	return _tint_material

## 设置目标节点（如果需要手动指定）
func set_target_node(node: CanvasItem) -> void:
	_target_node = node
	if _tint_material:
		_target_node.material = _tint_material

## 手动触发色调更新
func force_update() -> void:
	var rsm := get_node_or_null("/root/ResonanceSlicingManager")
	if rsm:
		apply_phase_tint(rsm.current_phase)
