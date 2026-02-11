## enemy_visual_enhancer.gd
## 敌人视觉增强器
## 从 enemy_base.gd 中解耦出来的视觉逻辑
##
## 职责：
## 1. 管理敌人的故障效果（HP 关联）
## 2. 处理受击闪白反馈
## 3. 实现章节差异化视觉
## 4. 响应节拍脉冲
class_name EnemyVisualEnhancer
extends VisualEnhancerBase

# ============================================================
# 配置
# ============================================================

## 故障效果配置
@export var glitch_base_intensity: float = 0.05
@export var glitch_damage_multiplier: float = 0.5
@export var glitch_flicker_chance: float = 0.02

## 受击闪白配置
@export var hit_flash_duration: float = 0.1
@export var hit_flash_color: Color = Color.WHITE

## 死亡动画配置
@export var death_dissolve_duration: float = 0.5
@export var death_pixelate_amount: float = 20.0

# ============================================================
# 状态
# ============================================================
var _glitch_intensity: float = 0.0
var _hit_flash_timer: float = 0.0
var _is_stunned: bool = false
var _hp_ratio: float = 1.0
var _enemy_ref: Node = null
var _original_modulate: Color = Color.WHITE
var _is_dying: bool = false

# ============================================================
# 章节视觉差异化
# ============================================================
var _chapter_glitch_color: Color = Color(1.0, 0.0, 0.67)  # 默认故障洋红
var _chapter_glow_intensity: float = 1.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	super._ready()
	_enemy_ref = get_parent()
	if _visual_node:
		_original_modulate = _visual_node.modulate
	
	# 连接章节视觉信号
	_update_chapter_visual()

func _update_visual(delta: float) -> void:
	if _enemy_ref == null or _is_dying:
		return

	# 从敌人获取状态
	if _enemy_ref.has_method("get_hp_ratio"):
		_hp_ratio = _enemy_ref.get_hp_ratio()
	elif "hp" in _enemy_ref and "max_hp" in _enemy_ref:
		_hp_ratio = float(_enemy_ref.hp) / float(_enemy_ref.max_hp) if _enemy_ref.max_hp > 0 else 1.0

	# 更新故障强度（HP 越低，故障越强）
	var damage_glitch := (1.0 - _hp_ratio) * glitch_damage_multiplier
	_glitch_intensity = glitch_base_intensity + damage_glitch

	# 随机故障闪烁
	if randf() < glitch_flicker_chance:
		_glitch_intensity += randf_range(0.1, 0.3)

	# 受击闪白衰减
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			_hit_flash_timer = 0.0
			if _visual_node:
				_visual_node.modulate = _original_modulate
		else:
			var flash_ratio := _hit_flash_timer / hit_flash_duration
			if _visual_node:
				_visual_node.modulate = _original_modulate.lerp(hit_flash_color, flash_ratio * 0.7)

	# 更新 Shader 参数
	set_shader_param("glitch_intensity", _glitch_intensity)
	set_shader_param("hp_ratio", _hp_ratio)
	set_shader_param("is_stunned", 1.0 if _is_stunned else 0.0)

# ============================================================
# 公共接口
# ============================================================

## 触发受击闪白
func trigger_hit_flash() -> void:
	_hit_flash_timer = hit_flash_duration
	if _visual_node:
		_visual_node.modulate = hit_flash_color

## 设置眩晕状态
func set_stunned(stunned: bool) -> void:
	_is_stunned = stunned
	set_shader_param("is_stunned", 1.0 if _is_stunned else 0.0)

## 播放死亡动画
func play_death_animation() -> void:
	_is_dying = true
	if _visual_node:
		var tween := create_tween()
		tween.set_parallel(true)
		# 故障强度急剧增加
		tween.tween_method(func(v: float):
			set_shader_param("glitch_intensity", v)
		, _glitch_intensity, 1.0, death_dissolve_duration * 0.5)
		# 缩小并淡出
		tween.tween_property(_visual_node, "scale", Vector2.ZERO, death_dissolve_duration)
		tween.tween_property(_visual_node, "modulate:a", 0.0, death_dissolve_duration)

## 重置视觉状态（用于对象池回收后重用）
func reset_visual() -> void:
	_is_dying = false
	_hp_ratio = 1.0
	_glitch_intensity = glitch_base_intensity
	_hit_flash_timer = 0.0
	_is_stunned = false
	if _visual_node:
		_visual_node.modulate = _original_modulate
		_visual_node.scale = _base_scale
	set_shader_param("glitch_intensity", glitch_base_intensity)
	set_shader_param("hp_ratio", 1.0)
	set_shader_param("is_stunned", 0.0)

## 节拍视觉响应
func _on_beat_visual() -> void:
	set_shader_param("beat_energy", 1.0)
	# beat_energy 将在 Shader 中自行衰减

# ============================================================
# 章节差异化
# ============================================================

func _update_chapter_visual() -> void:
	# 获取当前章节信息以调整视觉风格
	var cvm = get_node_or_null("/root/ChapterVisualManager")
	if cvm == null:
		# 尝试在场景树中查找
		var main_game = get_tree().root.get_node_or_null("MainGame")
		if main_game:
			cvm = main_game.get_node_or_null("ChapterVisualManager")
	
	if cvm and cvm.has_method("get_current_chapter"):
		var chapter: int = cvm.get_current_chapter()
		_apply_chapter_style(chapter)

func _apply_chapter_style(chapter: int) -> void:
	match chapter:
		0:  # 毕达哥拉斯：纯粹几何，故障更"数学化"
			_chapter_glitch_color = Color(1.0, 0.2, 0.2)
			glitch_flicker_chance = 0.01
		1:  # 中世纪：暗红色故障
			_chapter_glitch_color = Color(0.8, 0.2, 0.3)
			glitch_flicker_chance = 0.015
		2:  # 巴洛克：金色故障
			_chapter_glitch_color = Color(1.0, 0.8, 0.2)
			glitch_flicker_chance = 0.02
		3:  # 洛可可：粉色故障
			_chapter_glitch_color = Color(1.0, 0.5, 0.7)
			glitch_flicker_chance = 0.02
		4:  # 浪漫主义：深紫故障
			_chapter_glitch_color = Color(0.6, 0.1, 0.8)
			glitch_flicker_chance = 0.03
		5:  # 爵士：橙色故障
			_chapter_glitch_color = Color(1.0, 0.5, 0.0)
			glitch_flicker_chance = 0.025
		6:  # 数字：洋红故障（最强烈）
			_chapter_glitch_color = Color(1.0, 0.0, 0.5)
			glitch_flicker_chance = 0.04
	
	set_shader_param("glitch_color", _chapter_glitch_color)
