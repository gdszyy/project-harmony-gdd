## vfx_manager.gd
## 全局视觉特效管理器 (Autoload) v2.0
##
## 负责管理和播放全屏级别的视觉特效，包括：
## - 和弦进行冲击波 (Progression Shockwave)
## - 调式切换边框 (Mode Border)
## - 单音寂静去饱和 (Silence Desaturation)
## - Boss阶段转换闪光 (Phase Transition Flash)
## - 评价等级结算特效 (Evaluation VFX)
## - 频谱相位全局后处理 (Spectral Phase Filter) — v2.0 新增
## - 惩罚效果全局后处理 (Penalty Effects Filter) — v2.0 新增
## - 和弦进行全屏增强特效 (Chord Progression VFX) — v2.0 新增
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

## 频谱相位后处理层 (v2.0)
var _spectral_rect: ColorRect = null
var _spectral_material: ShaderMaterial = null

## 惩罚效果后处理层 (v2.0)
var _penalty_rect: ColorRect = null
var _penalty_material: ShaderMaterial = null

## 和弦进行增强特效层 (v2.0)
var _progression_vfx_rect: ColorRect = null
var _progression_vfx_material: ShaderMaterial = null

# ============================================================
# 状态
# ============================================================
var _current_phase: int = 0  # 0=全频, 1=高通, 2=低通
var _phase_transition_progress: float = 0.0
var _noise_overload_intensity: float = 0.0
var _dissonance_intensity: float = 0.0
var _monotone_intensity: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 100 # 确保在最上层
	_create_vfx_layers()
	_connect_signals()

func _process(delta: float) -> void:
	# 惩罚效果自然衰减
	if _noise_overload_intensity > 0.001:
		_noise_overload_intensity = lerp(_noise_overload_intensity, 0.0, 2.0 * delta)
		_update_penalty_shader()
	elif _noise_overload_intensity > 0:
		_noise_overload_intensity = 0.0
		_update_penalty_shader()
	
	if _dissonance_intensity > 0.001:
		_dissonance_intensity = lerp(_dissonance_intensity, 0.0, 1.5 * delta)
		_update_penalty_shader()
	elif _dissonance_intensity > 0:
		_dissonance_intensity = 0.0
		_update_penalty_shader()
	
	if _monotone_intensity > 0.001:
		_monotone_intensity = lerp(_monotone_intensity, 0.0, 1.0 * delta)
		_update_penalty_shader()
	elif _monotone_intensity > 0:
		_monotone_intensity = 0.0
		_update_penalty_shader()

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
	
	# 频谱相位后处理层 (v2.0)
	_spectral_rect = ColorRect.new()
	_spectral_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spectral_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spectral_rect.visible = false
	var spectral_shader = load("res://shaders/spectral_phase.gdshader")
	if spectral_shader:
		_spectral_material = ShaderMaterial.new()
		_spectral_material.shader = spectral_shader
		_spectral_rect.material = _spectral_material
	add_child(_spectral_rect)
	
	# 惩罚效果后处理层 (v2.0)
	_penalty_rect = ColorRect.new()
	_penalty_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_penalty_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_penalty_rect.visible = false
	var penalty_shader = load("res://shaders/penalty_effects.gdshader")
	if penalty_shader:
		_penalty_material = ShaderMaterial.new()
		_penalty_material.shader = penalty_shader
		_penalty_rect.material = _penalty_material
	add_child(_penalty_rect)
	
	# 和弦进行增强特效层 (v2.0)
	_progression_vfx_rect = ColorRect.new()
	_progression_vfx_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_progression_vfx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progression_vfx_rect.visible = false
	var progression_shader = load("res://shaders/chord_progression_vfx.gdshader")
	if progression_shader:
		_progression_vfx_material = ShaderMaterial.new()
		_progression_vfx_material.shader = progression_shader
		_progression_vfx_rect.material = _progression_vfx_material
	add_child(_progression_vfx_rect)

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
	
	# 连接 SpellcraftSystem 节点方式的信号 (v2.0)
	var spellcraft_node := get_node_or_null("/root/SpellcraftSystem")
	if spellcraft_node:
		if spellcraft_node.has_signal("progression_resolved"):
			if not spellcraft_node.progression_resolved.is_connected(_on_progression_resolved):
				spellcraft_node.progression_resolved.connect(_on_progression_resolved)
		if spellcraft_node.has_signal("phase_switched"):
			spellcraft_node.phase_switched.connect(_on_phase_switched)
		if spellcraft_node.has_signal("monotone_silence_triggered"):
			spellcraft_node.monotone_silence_triggered.connect(_on_monotone_silence)
		if spellcraft_node.has_signal("noise_overload_triggered"):
			spellcraft_node.noise_overload_triggered.connect(_on_noise_overload)
		if spellcraft_node.has_signal("dissonance_corrosion_triggered"):
			spellcraft_node.dissonance_corrosion_triggered.connect(_on_dissonance_corrosion)
	
	var mode_node := get_node_or_null("/root/ModeSystem")
	if mode_node:
		if mode_node.has_signal("mode_changed"):
			if not mode_node.mode_changed.is_connected(_on_mode_changed):
				mode_node.mode_changed.connect(_on_mode_changed)

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
	
	# 同时播放和弦进行增强特效 (v2.0)
	_play_progression_vfx_enhanced(function_type)

## 和弦进行增强全屏特效 (v2.0)
func _play_progression_vfx_enhanced(function_type: String) -> void:
	if _progression_vfx_material == null:
		return
	
	var prog_type: int = 0
	var color: Color = TONIC_COLOR
	match function_type:
		"tonic", "D_T", "burst_heal_or_damage":
			prog_type = 0
			color = Color(1.0, 0.85, 0.2)
		"dominant", "T_D", "empower_next":
			prog_type = 1
			color = Color(0.85, 0.6, 0.0)
		"pre_dominant", "PD_D", "cooldown_reduction":
			prog_type = 2
			color = Color(0.6, 0.2, 1.0)
	
	_progression_vfx_material.set_shader_parameter("progression_type", prog_type)
	_progression_vfx_material.set_shader_parameter("effect_color", color)
	_progression_vfx_material.set_shader_parameter("effect_intensity", 1.0)
	_progression_vfx_material.set_shader_parameter("progress", 0.0)
	_progression_vfx_rect.visible = true
	
	var tween := create_tween()
	tween.tween_method(func(val: float):
		_progression_vfx_material.set_shader_parameter("progress", val)
	, 0.0, 1.0, 0.8)
	tween.tween_callback(func():
		_progression_vfx_rect.visible = false
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
	play_screen_flash(Color.WHITE, 0.3)

# ============================================================
# 评价等级结算特效
# ============================================================

## 根据评价等级播放不同的结算背景特效
func play_evaluation_vfx(grade: String) -> void:
	match grade:
		"S":
			play_screen_flash(Color("#FFD700"), 0.5)
		"A":
			play_screen_flash(Color("#9D6FFF"), 0.4)
		"B":
			play_screen_flash(Color("#4D8BFF"), 0.3)
		"C":
			play_screen_flash(Color("#A098C8"), 0.2)
		"D":
			play_screen_flash(Color("#FF4D4D"), 0.15)

# ============================================================
# 频谱相位全局后处理 (v2.0)
# ============================================================

## 切换频谱相位
## phase: 0=全频(Fundamental), 1=高通(Overtone), 2=低通(Sub-Bass)
func switch_spectral_phase(phase: int) -> void:
	if _spectral_material == null:
		return
	
	_current_phase = phase
	_spectral_material.set_shader_parameter("phase", phase)
	
	if phase == 0:
		# 返回全频：渐隐后处理
		var tween := create_tween()
		tween.tween_method(func(val: float):
			_spectral_material.set_shader_parameter("transition_progress", val)
		, 1.0, 0.0, 0.5)
		tween.tween_callback(func():
			_spectral_rect.visible = false
			vfx_finished.emit("phase_fundamental")
		)
	else:
		# 切换到高通或低通：渐显后处理
		_spectral_material.set_shader_parameter("phase_intensity", 1.0)
		_spectral_material.set_shader_parameter("transition_progress", 0.0)
		_spectral_rect.visible = true
		
		var tween := create_tween()
		tween.tween_method(func(val: float):
			_spectral_material.set_shader_parameter("transition_progress", val)
		, 0.0, 1.0, 0.3)
		tween.tween_callback(func():
			var phase_name := "overtone" if phase == 1 else "sub_bass"
			vfx_finished.emit("phase_" + phase_name)
		)

# ============================================================
# 惩罚效果全局后处理 (v2.0)
# ============================================================

## 触发噪音过载视觉
func trigger_noise_overload(intensity: float = 0.5) -> void:
	_noise_overload_intensity = clampf(intensity, 0.0, 1.0)
	_update_penalty_shader()

## 触发不和谐腐蚀视觉
func trigger_dissonance_corrosion(intensity: float = 0.5) -> void:
	_dissonance_intensity = clampf(intensity, 0.0, 1.0)
	_update_penalty_shader()

## 触发单调寂静视觉
func trigger_monotone_silence(intensity: float = 0.5) -> void:
	_monotone_intensity = clampf(intensity, 0.0, 1.0)
	_update_penalty_shader()

func _update_penalty_shader() -> void:
	if _penalty_material == null:
		return
	
	var any_active := _noise_overload_intensity > 0.001 or \
					  _dissonance_intensity > 0.001 or \
					  _monotone_intensity > 0.001
	
	_penalty_rect.visible = any_active
	
	if any_active:
		_penalty_material.set_shader_parameter("noise_overload", _noise_overload_intensity)
		_penalty_material.set_shader_parameter("dissonance_corrosion", _dissonance_intensity)
		_penalty_material.set_shader_parameter("monotone_silence", _monotone_intensity)

# ============================================================
# 信号回调
# ============================================================

func _on_progression_resolved(progression_type: String, _completeness: float) -> void:
	play_progression_shockwave(progression_type)

func _on_mode_changed(mode_name: String) -> void:
	play_mode_switch(mode_name)

func _on_phase_switched(phase_name: String) -> void:
	match phase_name:
		"overtone":
			switch_spectral_phase(1)
		"sub_bass":
			switch_spectral_phase(2)
		"fundamental", _:
			switch_spectral_phase(0)

func _on_monotone_silence(_data: Dictionary) -> void:
	trigger_monotone_silence(0.6)

func _on_noise_overload(_data: Dictionary) -> void:
	trigger_noise_overload(0.5)

func _on_dissonance_corrosion(_data: Dictionary) -> void:
	trigger_dissonance_corrosion(0.5)
