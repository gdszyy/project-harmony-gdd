## basalt_column_obstacle.gd
## "固化静默" 黑色玄武岩柱体障碍物
##
## 继承自 StaticBody2D，实现：
## 1. 黑色玄武岩柱体的视觉表现（basalt_column.gdshader）
## 2. 受击时短暂"亮起"并发出低沉共振光芒
## 3. 表面 EQ 频谱响应全局节拍能量
## 4. 可选的固化静默效果叠加（CrystallizedObstacle 组件）
## 5. 受击时触发共振粒子效果
##
## 用法：
##   直接使用 crystallized_silence_obstacle.tscn 场景
##   或将此脚本挂载到自定义 StaticBody2D 上
extends StaticBody2D

# ============================================================
# 信号
# ============================================================
signal obstacle_hit(damage: float, position: Vector2)
signal resonance_triggered()

# ============================================================
# 配置
# ============================================================
## 受击亮起持续时间（秒）
const HIT_GLOW_DURATION := 0.4
## 受击亮起峰值强度
const HIT_GLOW_PEAK := 0.8
## 受击亮起衰减曲线指数
const HIT_GLOW_DECAY_POWER := 2.0
## 共振声音路径
const RESONANCE_SFX_PATH := "res://audio/sfx/enemy/enemy_hit.ogg"

# ============================================================
# 节点引用
# ============================================================
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _particles: GPUParticles2D = $ResonanceParticles

# ============================================================
# 状态
# ============================================================
var _shader_material: ShaderMaterial = null
var _hit_glow_timer: float = 0.0
var _is_crystallized: bool = false

# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	add_to_group("obstacles")
	add_to_group("basalt_columns")
	_setup_shader()
	_connect_hit_area()

func _process(delta: float) -> void:
	if _shader_material == null:
		return

	# 响应全局节拍能量
	var beat_energy: float = 0.0
	var gmm = get_node_or_null("/root/GlobalMusicManager")
	if gmm and gmm.has_method("get_beat_energy"):
		beat_energy = gmm.get_beat_energy()
	_shader_material.set_shader_parameter("beat_energy", beat_energy)

	# 受击亮起衰减
	if _hit_glow_timer > 0.0:
		_hit_glow_timer -= delta
		var t: float = clampf(_hit_glow_timer / HIT_GLOW_DURATION, 0.0, 1.0)
		# 使用幂函数实现快速衰减
		var glow_value: float = pow(t, HIT_GLOW_DECAY_POWER) * HIT_GLOW_PEAK
		_shader_material.set_shader_parameter("hit_glow", glow_value)
	elif _hit_glow_timer <= 0.0 and _hit_glow_timer > -1.0:
		_shader_material.set_shader_parameter("hit_glow", 0.0)
		_hit_glow_timer = -1.0  # 标记已完成

# ============================================================
# 公共接口
# ============================================================

## 受击处理
func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	# 触发受击亮起
	_hit_glow_timer = HIT_GLOW_DURATION
	if _shader_material:
		_shader_material.set_shader_parameter("hit_glow", HIT_GLOW_PEAK)

	# 触发共振粒子
	if _particles:
		_particles.emitting = true

	# 播放共振音效
	_play_resonance_sfx()

	# 受击闪白
	_flash()

	# 发射信号
	obstacle_hit.emit(amount, global_position)
	resonance_triggered.emit()

## 启用固化静默效果
func enable_crystallize() -> void:
	if _is_crystallized:
		return
	_is_crystallized = true
	var crystal_node = _sprite.get_node_or_null("CrystallizedObstacle")
	if crystal_node and crystal_node.has_method("start_crystallize"):
		crystal_node.start_crystallize()

## 禁用固化静默效果
func disable_crystallize() -> void:
	if not _is_crystallized:
		return
	_is_crystallized = false
	var crystal_node = _sprite.get_node_or_null("CrystallizedObstacle")
	if crystal_node and crystal_node.has_method("start_decrystallize"):
		crystal_node.start_decrystallize()

## 获取是否处于固化状态
func is_crystallized() -> bool:
	return _is_crystallized

# ============================================================
# 内部方法
# ============================================================

func _setup_shader() -> void:
	if _sprite and _sprite.material is ShaderMaterial:
		_shader_material = _sprite.material as ShaderMaterial

func _connect_hit_area() -> void:
	var hit_area := get_node_or_null("HitArea")
	if hit_area and hit_area is Area2D:
		hit_area.area_entered.connect(_on_projectile_entered)

func _on_projectile_entered(area: Area2D) -> void:
	# 当弹体进入受击区域时触发
	if area.is_in_group("projectiles"):
		var damage: float = area.get("damage") if area.get("damage") != null else 10.0
		take_damage(damage)

func _flash() -> void:
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(2.0, 2.0, 2.5), 0.05)
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.25)

func _play_resonance_sfx() -> void:
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_ui_click"):
		# 使用现有的音效接口播放共振声
		audio_manager.play_ui_click()
