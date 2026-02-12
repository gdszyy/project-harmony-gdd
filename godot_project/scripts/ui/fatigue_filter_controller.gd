## fatigue_filter_controller.gd
## 疲劳滤镜视觉控制器 (v3.1)
## 将 FatigueManager 的 AFI 值实时映射到 fatigue_filter.gdshader 的 uniform 参数
## 实现三级视觉效果的平滑过渡
##
## 三级视觉效果设计：
##   Tier 0 (AFI < 0.3): 正常画面，无任何后处理效果
##   Tier 1 (0.3 ≤ AFI < 0.5): 轻微暖色调偏移 + 微弱暗角
##   Tier 2 (0.5 ≤ AFI < 0.7): 色差 + 胶片噪点 + 扫描线 + 水平故障
##   Tier 3 (AFI ≥ 0.7): 去饱和 + 强烈暗角 + 红色警告脉冲 + 画面扭曲
##
## 关联文档：Docs/AestheticFatigueSystem_Documentation.md
extends Node

# ============================================================
# 配置
# ============================================================

## 滤镜 Shader 参数平滑过渡速度（越大越快）
const LERP_SPEED: float = 5.0
## 高疲劳时的额外脉冲频率
const HIGH_FATIGUE_PULSE_FREQ: float = 3.0
## Tier 变化时的闪烁强度
const TIER_CHANGE_FLASH_INTENSITY: float = 0.3
## Tier 变化闪烁持续时间
const TIER_CHANGE_FLASH_DURATION: float = 0.4

# ============================================================
# 引用
# ============================================================

## 疲劳滤镜 ColorRect（由 HUD 传入）
var _filter_rect: ColorRect = null
## ShaderMaterial 引用
var _shader_material: ShaderMaterial = null

# ============================================================
# 状态
# ============================================================

## 目标 AFI 值（来自 FatigueManager 信号）
var _target_afi: float = 0.0
## 当前显示 AFI 值（平滑过渡用）
var _display_afi: float = 0.0
## 当前疲劳 Tier
var _current_tier: int = 0
## 上一帧的 Tier（用于检测 Tier 变化）
var _prev_tier: int = 0
## Tier 变化闪烁计时器
var _tier_flash_timer: float = 0.0
## 不和谐度视觉强度（平滑过渡）
var _target_dissonance: float = 0.0
var _display_dissonance: float = 0.0
## 密度过载视觉强度
var _target_density_overload: float = 0.0
var _display_density_overload: float = 0.0

# ============================================================
# 初始化
# ============================================================

## 初始化控制器，绑定到指定的 ColorRect 滤镜
func initialize(filter_rect: ColorRect) -> void:
	_filter_rect = filter_rect
	if _filter_rect and _filter_rect.material is ShaderMaterial:
		_shader_material = _filter_rect.material as ShaderMaterial

	# 连接 FatigueManager 信号
	if FatigueManager.has_signal("afi_changed"):
		FatigueManager.afi_changed.connect(_on_afi_changed)
	if FatigueManager.has_signal("fatigue_level_changed"):
		FatigueManager.fatigue_level_changed.connect(_on_fatigue_level_changed)
	if FatigueManager.has_signal("density_overload_changed"):
		FatigueManager.density_overload_changed.connect(_on_density_overload_changed)
	if FatigueManager.has_signal("dissonance_corrosion_applied"):
		FatigueManager.dissonance_corrosion_applied.connect(_on_dissonance_corrosion)

	# 初始同步
	_target_afi = FatigueManager.current_afi
	_display_afi = _target_afi
	_current_tier = FatigueManager.get_fatigue_tier() if FatigueManager.has_method("get_fatigue_tier") else 0
	_prev_tier = _current_tier

# ============================================================
# 每帧更新
# ============================================================

func update(delta: float) -> void:
	if _shader_material == null:
		return

	# 平滑过渡 AFI 显示值
	_display_afi = lerp(_display_afi, _target_afi, delta * LERP_SPEED)

	# 平滑过渡不和谐度
	_display_dissonance = lerp(_display_dissonance, _target_dissonance, delta * LERP_SPEED)
	# 不和谐度自然衰减
	_target_dissonance = max(0.0, _target_dissonance - delta * 0.5)

	# 平滑过渡密度过载
	_display_density_overload = lerp(_display_density_overload, _target_density_overload, delta * LERP_SPEED)

	# Tier 变化闪烁
	if _tier_flash_timer > 0.0:
		_tier_flash_timer -= delta

	# 更新 Shader 参数
	_apply_shader_params(delta)

# ============================================================
# Shader 参数映射
# ============================================================

func _apply_shader_params(_delta: float) -> void:
	# 核心参数：fatigue_level 和 fatigue_tier
	var effective_fatigue := _display_afi

	# Tier 变化时的闪烁叠加
	if _tier_flash_timer > 0.0:
		var flash_progress := _tier_flash_timer / TIER_CHANGE_FLASH_DURATION
		var flash_boost := TIER_CHANGE_FLASH_INTENSITY * flash_progress * sin(flash_progress * TAU * 2.0)
		effective_fatigue = clampf(effective_fatigue + abs(flash_boost), 0.0, 1.0)

	_shader_material.set_shader_parameter("fatigue_level", effective_fatigue)
	_shader_material.set_shader_parameter("fatigue_tier", _current_tier)

	# 不和谐度视觉
	_shader_material.set_shader_parameter("dissonance_level", _display_dissonance)

	# 密度过载
	_shader_material.set_shader_parameter("density_overload", _display_density_overload)

	# 节拍脉冲（高疲劳时增强）
	if GameManager.has_method("get_beat_progress"):
		var beat_progress := GameManager.get_beat_progress()
		var base_pulse := max(0.0, 1.0 - beat_progress * 3.0)
		# 高疲劳时脉冲更强
		var fatigue_pulse_mult := 1.0
		if _current_tier >= 2:
			fatigue_pulse_mult = 1.0 + (_display_afi - 0.5) * 2.0
		elif _current_tier >= 3:
			fatigue_pulse_mult = 2.0
		_shader_material.set_shader_parameter("beat_pulse", base_pulse * 0.3 * fatigue_pulse_mult)

# ============================================================
# 信号回调
# ============================================================

## AFI 值变化回调
func _on_afi_changed(afi_value: float, fatigue_tier: int) -> void:
	_target_afi = afi_value
	_prev_tier = _current_tier
	_current_tier = fatigue_tier

	# 检测 Tier 变化，触发过渡闪烁
	if _current_tier != _prev_tier:
		_tier_flash_timer = TIER_CHANGE_FLASH_DURATION
		# Tier 升高时闪烁更强
		if _current_tier > _prev_tier:
			_tier_flash_timer = TIER_CHANGE_FLASH_DURATION * 1.5

## 疲劳等级变化回调
func _on_fatigue_level_changed(_level: MusicData.FatigueLevel) -> void:
	# 疲劳等级变化时额外触发一次视觉反馈
	_tier_flash_timer = TIER_CHANGE_FLASH_DURATION

## 密度过载状态变化回调
func _on_density_overload_changed(is_overloaded: bool, _accuracy_penalty: float) -> void:
	if is_overloaded:
		_target_density_overload = 1.0 - FatigueManager.current_density_damage_multiplier
	else:
		_target_density_overload = 0.0

## 不和谐腐蚀触发回调
func _on_dissonance_corrosion(dissonance: float, _damage: float) -> void:
	# 不和谐腐蚀触发时产生短暂的视觉冲击
	_target_dissonance = clampf(dissonance * 0.15, 0.0, 1.0)

# ============================================================
# 公共接口
# ============================================================

## 手动设置不和谐度视觉（供 HUD 中旧版代码兼容调用）
func set_dissonance_visual(value: float) -> void:
	_target_dissonance = clampf(value, 0.0, 1.0)

## 获取当前显示的 AFI 值
func get_display_afi() -> float:
	return _display_afi

## 获取当前 Tier
func get_current_tier() -> int:
	return _current_tier

## 清理信号连接
func cleanup() -> void:
	if FatigueManager.has_signal("afi_changed"):
		if FatigueManager.afi_changed.is_connected(_on_afi_changed):
			FatigueManager.afi_changed.disconnect(_on_afi_changed)
	if FatigueManager.has_signal("fatigue_level_changed"):
		if FatigueManager.fatigue_level_changed.is_connected(_on_fatigue_level_changed):
			FatigueManager.fatigue_level_changed.disconnect(_on_fatigue_level_changed)
	if FatigueManager.has_signal("density_overload_changed"):
		if FatigueManager.density_overload_changed.is_connected(_on_density_overload_changed):
			FatigueManager.density_overload_changed.disconnect(_on_density_overload_changed)
	if FatigueManager.has_signal("dissonance_corrosion_applied"):
		if FatigueManager.dissonance_corrosion_applied.is_connected(_on_dissonance_corrosion):
			FatigueManager.dissonance_corrosion_applied.disconnect(_on_dissonance_corrosion)
