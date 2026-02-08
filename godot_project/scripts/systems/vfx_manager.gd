## vfx_manager.gd
## 全局视觉特效管理器 (Autoload)
##
## 负责管理和播放全屏级别的视觉特效，包括：
## - 和弦进行冲击波 (Progression Shockwave)
## - 调式切换边框 (Mode Border)
## - 单音寂静去饱和 (Silence Desaturation)
## - Boss阶段转换闪光 (Phase Transition Flash)
## - 评价等级结算特效 (Evaluation VFX)
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal vfx_finished(vfx_name: String)

# ============================================================
# 颜色配置 (和弦功能对应颜色)
# ============================================================
const TONIC_COLOR := Color("#4D8BFF")     # 稳定蓝色
const DOMINANT_COLOR := Color("#FFD700")   # 紧张金色
const PRE_DOMINANT_COLOR := Color("#9D6FFF") # 过渡紫色

# 调式边框颜色
const MODE_COLORS: Dictionary = {
	"ionian": Color("#9D6FFF"),    # 紫色 (均衡)
	"dorian": Color("#FF8C42"),    # 橙色 (民谣)
	"pentatonic": Color("#4DFFF3"), # 青色 (东方)
	"blues": Color("#FF4D6A"),     # 霓虹粉 (爵士)
}

# 调式边框 pattern_type
const MODE_PATTERNS: Dictionary = {
	"ionian": 0,
	"dorian": 1,
	"pentatonic": 2,
	"blues": 3,
}

# ============================================================
# 节点引用
# ============================================================
var _shockwave_rect: ColorRect = null
var _shockwave_material: ShaderMaterial = null
var _mode_border_rect: ColorRect = null
var _mode_border_material: ShaderMaterial = null
var _flash_rect: ColorRect = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 100 # 确保在最上层
	_create_vfx_layers()
	_connect_signals()

func _create_vfx_layers() -> void:
	# 和弦进行冲击波层
	_shockwave_rect = ColorRect.new()
	_shockwave_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shockwave_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shockwave_rect.visible = false
	_shockwave_material = ShaderMaterial.new()
	_shockwave_material.shader = load("res://shaders/progression_shockwave.gdshader")
	_shockwave_rect.material = _shockwave_material
	add_child(_shockwave_rect)
	
	# 调式边框层
	_mode_border_rect = ColorRect.new()
	_mode_border_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_border_rect.visible = false
	_mode_border_material = ShaderMaterial.new()
	_mode_border_material.shader = load("res://shaders/mode_border.gdshader")
	_mode_border_rect.material = _mode_border_material
	add_child(_mode_border_rect)
	
	# 全屏闪光层
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	add_child(_flash_rect)

func _connect_signals() -> void:
	# 连接全局信号
	if Engine.has_singleton("SpellcraftSystem"):
		var spellcraft = Engine.get_singleton("SpellcraftSystem")
		if spellcraft.has_signal("progression_resolved"):
			spellcraft.progression_resolved.connect(_on_progression_resolved)
	
	if Engine.has_singleton("ModeSystem"):
		var mode_system = Engine.get_singleton("ModeSystem")
		if mode_system.has_signal("mode_changed"):
			mode_system.mode_changed.connect(_on_mode_changed)

# ============================================================
# 和弦进行冲击波
# ============================================================

## 播放和弦进行成功的冲击波特效
## function_type: "tonic", "dominant", "pre_dominant"
func play_progression_shockwave(function_type: String = "tonic") -> void:
	var color: Color
	match function_type:
		"tonic", "D_T":
			color = TONIC_COLOR
		"dominant", "T_D":
			color = DOMINANT_COLOR
		"pre_dominant", "PD_D":
			color = PRE_DOMINANT_COLOR
		_:
			color = TONIC_COLOR
	
	_shockwave_material.set_shader_parameter("wave_color", color)
	_shockwave_material.set_shader_parameter("wave_radius", 0.0)
	_shockwave_material.set_shader_parameter("wave_intensity", 1.0)
	_shockwave_rect.visible = true
	
	var tween := create_tween()
	tween.tween_method(func(val: float):
		_shockwave_material.set_shader_parameter("wave_radius", val)
	, 0.0, 1.5, 0.6)
	tween.tween_callback(func():
		_shockwave_rect.visible = false
		vfx_finished.emit("progression_shockwave")
	)

# ============================================================
# 调式切换边框
# ============================================================

## 播放调式切换的边框出现特效
func play_mode_switch(mode_name: String) -> void:
	var color: Color = MODE_COLORS.get(mode_name, Color("#9D6FFF"))
	var pattern: int = MODE_PATTERNS.get(mode_name, 0)
	
	_mode_border_material.set_shader_parameter("border_color", color)
	_mode_border_material.set_shader_parameter("pattern_type", pattern)
	_mode_border_material.set_shader_parameter("border_width", 0.0)
	_mode_border_rect.visible = true
	
	var tween := create_tween()
	# 边框从无到有
	tween.tween_method(func(val: float):
		_mode_border_material.set_shader_parameter("border_width", val)
	, 0.0, 0.04, 0.3).set_ease(Tween.EASE_OUT)
	
	# 保持一段时间
	tween.tween_interval(1.5)
	
	# 边框渐隐
	tween.tween_method(func(val: float):
		_mode_border_material.set_shader_parameter("border_width", val)
	, 0.04, 0.0, 0.5)
	
	tween.tween_callback(func():
		_mode_border_rect.visible = false
		vfx_finished.emit("mode_switch")
	)

# ============================================================
# 全屏闪光
# ============================================================

## 播放一个快速的全屏闪光
func play_screen_flash(color: Color = Color.WHITE, duration: float = 0.15) -> void:
	_flash_rect.color = Color(color.r, color.g, color.b, 0.6)
	
	var tween := create_tween()
	tween.tween_property(_flash_rect, "color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		vfx_finished.emit("screen_flash")
	)

# ============================================================
# Boss 阶段转换
# ============================================================

## 播放Boss阶段转换的全屏特效
func play_boss_phase_transition() -> void:
	# 快速白闪 + 屏幕震动效果
	play_screen_flash(Color.WHITE, 0.3)
	
	# 可以在这里添加更复杂的效果，如屏幕扭曲等

# ============================================================
# 评价等级结算特效
# ============================================================

## 根据评价等级播放不同的结算背景特效
func play_evaluation_vfx(grade: String) -> void:
	match grade:
		"S":
			# 金色曼陀罗绽放
			play_screen_flash(Color("#FFD700"), 0.5)
		"A":
			# 紫色光环
			play_screen_flash(Color("#9D6FFF"), 0.4)
		"B":
			# 蓝色脉冲
			play_screen_flash(Color("#4D8BFF"), 0.3)
		"C":
			# 暗淡闪烁
			play_screen_flash(Color("#A098C8"), 0.2)
		"D":
			# 红色故障
			play_screen_flash(Color("#FF4D4D"), 0.15)

# ============================================================
# 信号回调
# ============================================================

func _on_progression_resolved(progression_type: String, _completeness: float) -> void:
	play_progression_shockwave(progression_type)

func _on_mode_changed(mode_name: String) -> void:
	play_mode_switch(mode_name)
