## crystallized_obstacle.gd
## "固化静默" 障碍物组件
##
## 附加到障碍物 Sprite2D 上，应用水晶化/石化视觉效果。
## 当障碍物被"固化静默"效果影响时，逐渐石化；
## 效果消失时，逐渐恢复正常。
##
## 用法：
##   var crystal = CrystallizedObstacle.new()
##   obstacle_sprite.add_child(crystal)
##   crystal.start_crystallize()
extends Node

# ============================================================
# 信号
# ============================================================
signal crystallize_complete()
signal decrystallize_complete()

# ============================================================
# 配置
# ============================================================
const CRYSTALLIZE_DURATION := 1.5       ## 石化过渡时间
const DECRYSTALLIZE_DURATION := 2.0     ## 恢复过渡时间
const CRACK_DENSITY_NORMAL := 8.0
const CRACK_DENSITY_SHATTERED := 15.0

# ============================================================
# 状态
# ============================================================
enum State { NORMAL, CRYSTALLIZING, CRYSTALLIZED, DECRYSTALLIZING }

var _state: State = State.NORMAL
var _material: ShaderMaterial = null
var _target_sprite: Sprite2D = null
var _original_material: Material = null
var _freeze_progress: float = 0.0
var _tween: Tween = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 查找父级 Sprite2D
	var parent := get_parent()
	if parent is Sprite2D:
		_target_sprite = parent as Sprite2D
		_original_material = _target_sprite.material

func _process(_delta: float) -> void:
	if _material:
		# 更新能量脉络速度（根据状态）
		match _state:
			State.CRYSTALLIZING:
				_material.set_shader_parameter("energy_speed", 1.0)
			State.CRYSTALLIZED:
				_material.set_shader_parameter("energy_speed", 0.3)
			State.DECRYSTALLIZING:
				_material.set_shader_parameter("energy_speed", 2.0)

# ============================================================
# 公共接口
# ============================================================

## 开始石化过程
func start_crystallize(duration: float = CRYSTALLIZE_DURATION) -> void:
	if _target_sprite == null:
		return
	if _state == State.CRYSTALLIZED or _state == State.CRYSTALLIZING:
		return

	_state = State.CRYSTALLIZING
	_apply_shader()

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_method(_set_freeze_progress, _freeze_progress, 1.0, duration)
	_tween.tween_callback(func():
		_state = State.CRYSTALLIZED
		crystallize_complete.emit()
	)

## 开始恢复过程
func start_decrystallize(duration: float = DECRYSTALLIZE_DURATION) -> void:
	if _target_sprite == null:
		return
	if _state == State.NORMAL or _state == State.DECRYSTALLIZING:
		return

	_state = State.DECRYSTALLIZING

	if _tween:
		_tween.kill()

	# 恢复前先增加裂纹密度（碎裂效果）
	_material.set_shader_parameter("crack_density", CRACK_DENSITY_SHATTERED)

	_tween = create_tween()
	_tween.tween_method(_set_freeze_progress, _freeze_progress, 0.0, duration)
	_tween.tween_callback(func():
		_state = State.NORMAL
		_remove_shader()
		decrystallize_complete.emit()
	)

## 立即设置为完全石化
func set_crystallized() -> void:
	if _target_sprite == null:
		return
	_state = State.CRYSTALLIZED
	_apply_shader()
	_set_freeze_progress(1.0)

## 立即恢复正常
func set_normal() -> void:
	if _target_sprite == null:
		return
	_state = State.NORMAL
	_set_freeze_progress(0.0)
	_remove_shader()

## 获取当前状态
func get_crystal_state() -> State:
	return _state

## 是否已完全石化
func is_crystallized() -> bool:
	return _state == State.CRYSTALLIZED

# ============================================================
# 内部方法
# ============================================================

func _apply_shader() -> void:
	if _target_sprite == null:
		return
	if _material != null:
		return  # 已经应用了

	var shader := load("res://shaders/crystallized_silence.gdshader")
	if shader == null:
		return

	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("freeze_progress", _freeze_progress)
	_material.set_shader_parameter("crack_density", CRACK_DENSITY_NORMAL)
	_target_sprite.material = _material

func _remove_shader() -> void:
	if _target_sprite:
		_target_sprite.material = _original_material
	_material = null

func _set_freeze_progress(value: float) -> void:
	_freeze_progress = value
	if _material:
		_material.set_shader_parameter("freeze_progress", value)

# ============================================================
# 清理
# ============================================================

func _exit_tree() -> void:
	if _tween:
		_tween.kill()
	_remove_shader()
