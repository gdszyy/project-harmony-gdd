## phase_transition_overlay.gd
## 相位切换全屏过渡效果
## 使用 GPU Shader 实现频谱扫描线 + 色差 + 噪点过渡
## 挂载在全屏 ColorRect 上，通过 Tween 驱动 Shader 参数
## 关联文档：Docs/UI_Design_Module6_ResonanceSlicing.md §7
extends ColorRect

# ============================================================
# 常量
# ============================================================

## 扫描线扫过时间
const SCAN_DURATION: float = 0.15
## 扫描线消散时间
const FADE_DURATION: float = 0.25
## 总过渡时间（含余波）
const TOTAL_DURATION: float = 0.4

## 扫描方向映射
const DIRECTION_MAP: Dictionary = {
	1: 0,  # Overtone → 从下往上
	2: 1,  # SubBass → 从上往下
	0: 2,  # Fundamental → 从中心向外
}

# ============================================================
# 状态
# ============================================================

var _is_playing: bool = false
var _current_tween: Tween = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 设置全屏覆盖
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	# 加载 Shader
	var shader := load("res://shaders/ui/phase_transition.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("progress", 0.0)
		mat.set_shader_parameter("direction", 0)
		mat.set_shader_parameter("target_color", Color("#4DFFF3"))
		mat.set_shader_parameter("scan_width", 0.1)
		mat.set_shader_parameter("chromatic_strength", 0.015)
		mat.set_shader_parameter("noise_strength", 0.3)
		mat.set_shader_parameter("ripple_count", 3)
		material = mat

	# 连接 ResonanceSlicingManager 信号
	var rsm := get_node_or_null("/root/ResonanceSlicingManager")
	if rsm:
		rsm.phase_changed.connect(_on_phase_changed)

# ============================================================
# 过渡效果
# ============================================================

## 播放相位切换过渡效果
func play_transition(target_phase: int) -> void:
	if material == null:
		return

	# 如果正在播放，快速结束当前效果
	if _is_playing and _current_tween:
		_current_tween.kill()
		_reset()

	_is_playing = true
	visible = true

	var mat := material as ShaderMaterial
	if mat == null:
		return

	# 设置方向和颜色
	var direction: int = DIRECTION_MAP.get(target_phase, 2)
	var color: Color = ResonanceSlicingManager.PHASE_COLORS.get(
		target_phase, Color("#9D6FFF"))

	mat.set_shader_parameter("direction", direction)
	mat.set_shader_parameter("target_color", color)
	mat.set_shader_parameter("progress", 0.0)

	# 创建过渡动画
	_current_tween = create_tween()

	# 阶段1：扫描线扫过 (0 → 1)
	_current_tween.tween_property(
		mat, "shader_parameter/progress",
		1.0, SCAN_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# 阶段2：扫描线消散 (1 → 0)
	_current_tween.tween_property(
		mat, "shader_parameter/progress",
		0.0, FADE_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# 完成回调
	_current_tween.tween_callback(_on_transition_complete)

## 播放频谱失调过渡效果（更剧烈）
func play_corruption_transition() -> void:
	if material == null:
		return

	if _is_playing and _current_tween:
		_current_tween.kill()
		_reset()

	_is_playing = true
	visible = true

	var mat := material as ShaderMaterial
	if mat == null:
		return

	# 频谱失调使用特殊参数
	mat.set_shader_parameter("direction", 2)  # 从中心向外
	mat.set_shader_parameter("target_color", Color("#FF0066"))
	mat.set_shader_parameter("scan_width", 0.15)
	mat.set_shader_parameter("chromatic_strength", 0.03)
	mat.set_shader_parameter("noise_strength", 0.6)
	mat.set_shader_parameter("progress", 0.0)

	_current_tween = create_tween()

	# 更慢、更剧烈的扫描
	_current_tween.tween_property(
		mat, "shader_parameter/progress",
		1.0, 0.3
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	_current_tween.tween_property(
		mat, "shader_parameter/progress",
		0.0, 0.5
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	_current_tween.tween_callback(_on_transition_complete)

# ============================================================
# 信号回调
# ============================================================

func _on_phase_changed(new_phase: int) -> void:
	play_transition(new_phase)

# ============================================================
# 内部方法
# ============================================================

func _on_transition_complete() -> void:
	_is_playing = false
	visible = false
	_reset_shader_params()

func _reset() -> void:
	_is_playing = false
	visible = false
	_reset_shader_params()

func _reset_shader_params() -> void:
	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("progress", 0.0)
		mat.set_shader_parameter("scan_width", 0.1)
		mat.set_shader_parameter("chromatic_strength", 0.015)
		mat.set_shader_parameter("noise_strength", 0.3)

# ============================================================
# 公共接口
# ============================================================

## 检查是否正在播放过渡效果
func is_playing() -> bool:
	return _is_playing

## 立即停止过渡效果
func stop() -> void:
	if _current_tween:
		_current_tween.kill()
	_reset()
