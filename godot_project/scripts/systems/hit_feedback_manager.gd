## hit_feedback_manager.gd
## 玩家受击反馈管理器 (Autoload)
##
## 功能：
## - 受击时的屏幕抖动（Camera2D 偏移）
## - 受击时的边缘红色渐变（hit_feedback.gdshader）
## - 低血量时的持续红色脉冲
## - 受击方向性视觉反馈
## - 受击时的短暂时间减速（Hitstop）
extends CanvasLayer

# ============================================================
# 配置
# ============================================================

## 屏幕抖动
const SHAKE_DECAY_RATE := 8.0           ## 抖动衰减速率
const SHAKE_MAX_OFFSET := 8.0           ## 最大抖动像素偏移
const SHAKE_FREQUENCY := 30.0           ## 抖动频率 (Hz)

## 受击闪光
const HIT_FLASH_DECAY := 4.0            ## 受击闪光衰减速率
const HIT_VIGNETTE_DECAY := 3.0         ## 受击暗角衰减速率

## 低血量
const LOW_HP_THRESHOLD := 0.3           ## 低血量阈值 (30%)
const CRITICAL_HP_THRESHOLD := 0.15     ## 危急血量阈值 (15%)

## Hitstop (受击顿帧)
const HITSTOP_DURATION := 0.05          ## 顿帧持续时间
const HEAVY_HITSTOP_DURATION := 0.1     ## 重击顿帧持续时间

# ============================================================
# 节点引用
# ============================================================
var _feedback_rect: ColorRect = null
var _feedback_material: ShaderMaterial = null
var _camera: Camera2D = null

# ============================================================
# 状态
# ============================================================
var _shake_intensity: float = 0.0
var _shake_time: float = 0.0
var _hit_intensity: float = 0.0
var _flash_intensity: float = 0.0
var _hit_direction: Vector2 = Vector2.ZERO
var _low_hp_intensity: float = 0.0
var _hitstop_timer: float = 0.0
var _original_camera_offset: Vector2 = Vector2.ZERO

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 99  # 在 VFX 层之下，疲劳滤镜之上
	_create_feedback_layer()
	_connect_signals()

func _process(delta: float) -> void:
	# Hitstop 处理
	if _hitstop_timer > 0:
		_hitstop_timer -= delta
		if _hitstop_timer <= 0:
			Engine.time_scale = 1.0
		return

	# 屏幕抖动衰减
	if _shake_intensity > 0.001:
		_shake_intensity = lerp(_shake_intensity, 0.0, SHAKE_DECAY_RATE * delta)
		_shake_time += delta
		_apply_camera_shake()
	elif _shake_intensity > 0:
		_shake_intensity = 0.0
		_reset_camera_offset()

	# 受击强度衰减
	if _hit_intensity > 0.001:
		_hit_intensity = lerp(_hit_intensity, 0.0, HIT_VIGNETTE_DECAY * delta)
	else:
		_hit_intensity = 0.0

	# 闪光衰减
	if _flash_intensity > 0.001:
		_flash_intensity = lerp(_flash_intensity, 0.0, HIT_FLASH_DECAY * delta)
	else:
		_flash_intensity = 0.0

	_update_shader()

# ============================================================
# 初始化
# ============================================================

func _create_feedback_layer() -> void:
	_feedback_rect = ColorRect.new()
	_feedback_rect.name = "HitFeedbackRect"
	_feedback_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_feedback_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := load("res://shaders/hit_feedback.gdshader")
	if shader:
		_feedback_material = ShaderMaterial.new()
		_feedback_material.shader = shader
		_feedback_rect.material = _feedback_material

	add_child(_feedback_rect)

func _connect_signals() -> void:
	# 连接玩家受击信号
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		if gm.has_signal("player_damaged"):
			gm.player_damaged.connect(_on_player_damaged)
		if gm.has_signal("player_hp_changed"):
			gm.player_hp_changed.connect(_on_hp_changed)
	
	# 尝试连接节点方式的 GameManager
	var gm_node := get_node_or_null("/root/GameManager")
	if gm_node:
		if gm_node.has_signal("player_damaged"):
			gm_node.player_damaged.connect(_on_player_damaged)
		if gm_node.has_signal("player_hp_changed"):
			gm_node.player_hp_changed.connect(_on_hp_changed)

# ============================================================
# 屏幕抖动
# ============================================================

func _apply_camera_shake() -> void:
	_camera = _find_camera()
	if _camera == null:
		return

	var offset_x := sin(_shake_time * SHAKE_FREQUENCY) * _shake_intensity * SHAKE_MAX_OFFSET
	var offset_y := cos(_shake_time * SHAKE_FREQUENCY * 1.3) * _shake_intensity * SHAKE_MAX_OFFSET

	_camera.offset = _original_camera_offset + Vector2(offset_x, offset_y)

	# 同步到 shader
	if _feedback_material:
		_feedback_material.set_shader_parameter("shake_offset_x", offset_x / get_viewport().get_visible_rect().size.x)
		_feedback_material.set_shader_parameter("shake_offset_y", offset_y / get_viewport().get_visible_rect().size.y)

func _reset_camera_offset() -> void:
	if _camera:
		_camera.offset = _original_camera_offset
	if _feedback_material:
		_feedback_material.set_shader_parameter("shake_offset_x", 0.0)
		_feedback_material.set_shader_parameter("shake_offset_y", 0.0)

func _find_camera() -> Camera2D:
	if _camera and is_instance_valid(_camera):
		return _camera
	# 查找当前活跃的 Camera2D
	var viewport := get_viewport()
	if viewport:
		var cam := viewport.get_camera_2d()
		if cam:
			_original_camera_offset = cam.offset
			return cam
	return null

# ============================================================
# Shader 更新
# ============================================================

func _update_shader() -> void:
	if _feedback_material == null:
		return

	_feedback_material.set_shader_parameter("hit_intensity", _hit_intensity)
	_feedback_material.set_shader_parameter("flash_intensity", _flash_intensity)
	_feedback_material.set_shader_parameter("low_hp_intensity", _low_hp_intensity)
	_feedback_material.set_shader_parameter("hit_direction_x", _hit_direction.x)
	_feedback_material.set_shader_parameter("hit_direction_y", _hit_direction.y)

# ============================================================
# 公共接口
# ============================================================

## 触发受击反馈
## damage: 伤害值
## direction: 伤害来源方向 (归一化向量，从玩家指向伤害源)
## is_heavy: 是否为重击 (Boss 攻击等)
func trigger_hit(damage: float, direction: Vector2 = Vector2.ZERO, is_heavy: bool = false) -> void:
	# 根据伤害计算强度
	var intensity := clampf(damage / 50.0, 0.1, 1.0)
	if is_heavy:
		intensity = clampf(intensity * 1.5, 0.3, 1.0)

	# 屏幕抖动
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_time = 0.0

	# 受击暗角
	_hit_intensity = maxf(_hit_intensity, intensity)
	_hit_direction = direction.normalized() if direction.length() > 0.01 else Vector2(0.0, -1.0)

	# 闪白
	_flash_intensity = maxf(_flash_intensity, intensity * 0.5)

	# Hitstop
	if is_heavy:
		_apply_hitstop(HEAVY_HITSTOP_DURATION)
	elif intensity > 0.3:
		_apply_hitstop(HITSTOP_DURATION)

## 触发纯屏幕抖动（不带红色暗角，用于爆炸等非受击场景）
func trigger_shake(intensity: float = 0.5) -> void:
	_shake_intensity = maxf(_shake_intensity, clampf(intensity, 0.0, 1.0))
	_shake_time = 0.0

## 手动设置低血量强度
func set_low_hp_intensity(intensity: float) -> void:
	_low_hp_intensity = clampf(intensity, 0.0, 1.0)

# ============================================================
# Hitstop (顿帧)
# ============================================================

func _apply_hitstop(duration: float) -> void:
	_hitstop_timer = duration
	Engine.time_scale = 0.05  # 几乎暂停

# ============================================================
# 信号回调
# ============================================================

func _on_player_damaged(damage: float, source_position: Vector2) -> void:
	# 计算伤害方向
	var player_pos := Vector2.ZERO
	var player_node := get_node_or_null("/root/Main/Player")
	if player_node and player_node is Node2D:
		player_pos = (player_node as Node2D).global_position

	var direction := Vector2.ZERO
	if source_position.length() > 0.01 and player_pos.length() > 0.01:
		direction = (source_position - player_pos).normalized()

	var is_heavy := damage >= 30.0
	trigger_hit(damage, direction, is_heavy)

func _on_hp_changed(current_hp: float, max_hp: float) -> void:
	var hp_ratio := current_hp / maxf(max_hp, 1.0)

	if hp_ratio < CRITICAL_HP_THRESHOLD:
		_low_hp_intensity = 1.0
	elif hp_ratio < LOW_HP_THRESHOLD:
		_low_hp_intensity = (LOW_HP_THRESHOLD - hp_ratio) / (LOW_HP_THRESHOLD - CRITICAL_HP_THRESHOLD)
	else:
		_low_hp_intensity = 0.0
