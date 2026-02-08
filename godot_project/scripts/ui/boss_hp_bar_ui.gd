## boss_hp_bar_ui.gd
## Boss 血条 UI 组件
## 使用 boss_hp_bar.gdshader 实现各章节 Boss 专属血条视觉效果
##
## 功能：
## - 根据章节自动切换血条纹理风格
## - 受击闪白反馈
## - 阶段转换动画
## - 低血量危险脉冲
## - Boss 名称和阶段名称显示
extends Control

# ============================================================
# 信号
# ============================================================
signal boss_defeated()
signal phase_changed(phase_index: int)

# ============================================================
# 配置
# ============================================================
const BAR_SIZE := Vector2(500, 32)
const BAR_MARGIN_TOP := 40.0
const DAMAGE_FLASH_DURATION := 0.12
const PHASE_TRANSITION_DURATION := 1.0

## 各章节 Boss 血条填充颜色
const CHAPTER_BAR_COLORS: Dictionary = {
	1: Color(1.0, 0.85, 0.2, 1.0),    # 金色 (毕达哥拉斯)
	2: Color(0.9, 0.8, 0.5, 1.0),     # 羊皮纸金 (圭多)
	3: Color(0.3, 0.4, 0.85, 1.0),    # 深蓝 (巴赫)
	4: Color(1.0, 0.9, 0.6, 1.0),     # 象牙金 (莫扎特)
	5: Color(0.85, 0.15, 0.1, 1.0),   # 深红 (贝多芬)
}

const CHAPTER_BORDER_COLORS: Dictionary = {
	1: Color(0.9, 0.8, 0.3, 1.0),
	2: Color(0.7, 0.6, 0.3, 1.0),
	3: Color(0.5, 0.55, 0.8, 1.0),
	4: Color(0.85, 0.75, 0.4, 1.0),
	5: Color(0.6, 0.15, 0.1, 1.0),
}

# ============================================================
# 节点引用
# ============================================================
var _bar_rect: ColorRect = null
var _bar_material: ShaderMaterial = null
var _name_label: Label = null
var _phase_label: Label = null
var _hp_text_label: Label = null

# ============================================================
# 状态
# ============================================================
var _current_chapter: int = 1
var _current_hp: float = 1.0
var _target_hp: float = 1.0
var _max_hp: float = 1000.0
var _damage_flash_timer: float = 0.0
var _phase_transition_timer: float = 0.0
var _current_phase: int = 0
var _boss_name: String = ""
var _phase_names: Array = []
var _visible_target: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_build_ui()
	visible = false

func _process(delta: float) -> void:
	if not _visible_target:
		return

	# 平滑血量变化
	_current_hp = lerp(_current_hp, _target_hp, delta * 8.0)

	# 受击闪白衰减
	if _damage_flash_timer > 0:
		_damage_flash_timer -= delta
		if _damage_flash_timer < 0:
			_damage_flash_timer = 0.0

	# 阶段转换衰减
	if _phase_transition_timer > 0:
		_phase_transition_timer -= delta
		if _phase_transition_timer < 0:
			_phase_transition_timer = 0.0

	_update_shader_params()
	_update_hp_text()

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	custom_minimum_size = Vector2(BAR_SIZE.x + 40, 80)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Boss 名称
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	vbox.add_child(_name_label)

	# 血条容器
	var bar_container := CenterContainer.new()
	bar_container.custom_minimum_size = BAR_SIZE

	_bar_rect = ColorRect.new()
	_bar_rect.custom_minimum_size = BAR_SIZE
	_bar_rect.size = BAR_SIZE

	# 加载 Shader
	var shader := load("res://shaders/boss_hp_bar.gdshader")
	if shader:
		_bar_material = ShaderMaterial.new()
		_bar_material.shader = shader
		_bar_rect.material = _bar_material

	bar_container.add_child(_bar_rect)
	vbox.add_child(bar_container)

	# HP 数值文字 (覆盖在血条上)
	_hp_text_label = Label.new()
	_hp_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_text_label.add_theme_font_size_override("font_size", 11)
	_hp_text_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	_hp_text_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar_rect.add_child(_hp_text_label)

	# 阶段名称
	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.add_theme_font_size_override("font_size", 10)
	_phase_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.8))
	vbox.add_child(_phase_label)

# ============================================================
# Shader 参数更新
# ============================================================

func _update_shader_params() -> void:
	if _bar_material == null:
		return

	_bar_material.set_shader_parameter("hp_ratio", _current_hp)
	_bar_material.set_shader_parameter("chapter", _current_chapter)
	_bar_material.set_shader_parameter("damage_flash", _damage_flash_timer / DAMAGE_FLASH_DURATION)
	_bar_material.set_shader_parameter("phase_transition", _phase_transition_timer / PHASE_TRANSITION_DURATION)

	# 章节颜色
	var fill_color: Color = CHAPTER_BAR_COLORS.get(_current_chapter, Color.RED)
	var border_color: Color = CHAPTER_BORDER_COLORS.get(_current_chapter, Color.GRAY)
	_bar_material.set_shader_parameter("bar_fill_color", fill_color)
	_bar_material.set_shader_parameter("bar_border_color", border_color)

func _update_hp_text() -> void:
	if _hp_text_label:
		var current_val := int(_current_hp * _max_hp)
		var max_val := int(_max_hp)
		_hp_text_label.text = "%d / %d" % [current_val, max_val]

# ============================================================
# 公共接口
# ============================================================

## 初始化 Boss 血条
func setup_boss(boss_name: String, chapter: int, max_hp: float, phase_names: Array = []) -> void:
	_boss_name = boss_name
	_current_chapter = clampi(chapter, 1, 5)
	_max_hp = max_hp
	_current_hp = 1.0
	_target_hp = 1.0
	_phase_names = phase_names
	_current_phase = 0

	if _name_label:
		_name_label.text = _boss_name

	if _phase_label and not _phase_names.is_empty():
		_phase_label.text = "阶段: %s" % _phase_names[0]

	_visible_target = true
	visible = true
	_update_shader_params()

## 更新 Boss 血量
func update_hp(current_hp: float, max_hp: float) -> void:
	_max_hp = max_hp
	var new_ratio := clampf(current_hp / max_hp, 0.0, 1.0)

	# 检测受击
	if new_ratio < _target_hp:
		_damage_flash_timer = DAMAGE_FLASH_DURATION

	_target_hp = new_ratio

	if new_ratio <= 0.0:
		boss_defeated.emit()

## 切换阶段
func set_phase(phase_index: int) -> void:
	if phase_index == _current_phase:
		return

	_current_phase = phase_index
	_phase_transition_timer = PHASE_TRANSITION_DURATION

	if _phase_label and phase_index < _phase_names.size():
		_phase_label.text = "阶段: %s" % _phase_names[phase_index]

	phase_changed.emit(phase_index)

## 隐藏血条
func hide_boss_bar() -> void:
	_visible_target = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): visible = false; modulate.a = 1.0)
