## boss_hp_bar_ui.gd — Boss 血条 UI 组件
## 7种Boss主题化血条，使用 boss_hp_bar.gdshader 实现
## 支持：章节自动切换、受击闪白、阶段转换、低血量脉冲、节拍同步
extends Control

# ============================================================
# 信号
# ============================================================
signal boss_defeated()
signal phase_changed(phase_index: int)

# ============================================================
# 配置
# ============================================================
const CONTAINER_SIZE := Vector2(1000, 120)
const BAR_SIZE := Vector2(800, 40)
const BAR_MARGIN_TOP := 20.0
const DAMAGE_FLASH_DURATION := 0.12
const PHASE_TRANSITION_DURATION := 1.0

## 7种Boss填充颜色
const CHAPTER_FILL_COLORS: Dictionary = {
	1: Color(0.0, 1.0, 0.831),    # 谐振青 (毕达哥拉斯)
	2: Color(0.4, 0.15, 0.1),     # 暗红 + 圣光金 (圭多)
	3: Color(0.7, 0.55, 0.2),     # 黄铜 (巴赫)
	4: Color(1.0, 0.9, 0.6),      # 象牙白 / 金色 (莫扎特)
	5: Color(0.85, 0.15, 0.1),    # 橙红 (贝多芬)
	6: Color(0.2, 0.5, 1.0),      # 霓虹蓝 (爵士)
	7: Color(0.5, 0.5, 0.5),      # 全频谱灰 (噪音)
}

const CHAPTER_BORDER_COLORS: Dictionary = {
	1: Color(0.918, 0.902, 1.0),   # 晶体白
	2: Color(1.0, 0.843, 0.0),     # 圣光金
	3: Color(0.5, 0.4, 0.15),      # 暗金
	4: Color(1.0, 0.85, 0.3),      # 金色
	5: Color(1.0, 0.6, 0.15),      # 闪电橙
	6: Color(1.0, 0.3, 0.6),       # 霓虹粉
	7: Color(1.0, 0.0, 0.667),     # 故障洋红
}

const CHAPTER_BOSS_NAMES: Dictionary = {
	1: "PYTHAGORAS",
	2: "GUIDO",
	3: "BACH",
	4: "MOZART",
	5: "BEETHOVEN",
	6: "JAZZ",
	7: "NOISE",
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
var _beat_intensity: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_to_group("boss_health_bar")
	_build_ui()
	visible = false

	# 连接节拍信号
	if not GameManager.beat_tick.is_connected(_on_beat_tick):
		GameManager.beat_tick.connect(_on_beat_tick)

func _process(delta: float) -> void:
	if not _visible_target:
		return

	# 平滑血量
	_current_hp = lerp(_current_hp, _target_hp, delta * 8.0)

	# 受击闪白衰减
	if _damage_flash_timer > 0:
		_damage_flash_timer = max(0.0, _damage_flash_timer - delta)

	# 阶段转换衰减
	if _phase_transition_timer > 0:
		_phase_transition_timer = max(0.0, _phase_transition_timer - delta)

	# 节拍衰减
	_beat_intensity = max(0.0, _beat_intensity - delta * 4.0)

	_update_shader_params()
	_update_hp_text()

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	custom_minimum_size = CONTAINER_SIZE
	size = CONTAINER_SIZE

	# Boss 名称
	_name_label = Label.new()
	_name_label.name = "BossNameLabel"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_name_label.offset_top = 5
	_name_label.offset_left = -200
	_name_label.offset_right = 200
	add_child(_name_label)

	# 血条 ColorRect
	_bar_rect = ColorRect.new()
	_bar_rect.name = "BossBarRect"
	_bar_rect.custom_minimum_size = BAR_SIZE
	_bar_rect.size = BAR_SIZE
	_bar_rect.set_anchors_preset(Control.PRESET_CENTER)
	_bar_rect.offset_left = -BAR_SIZE.x / 2.0
	_bar_rect.offset_right = BAR_SIZE.x / 2.0
	_bar_rect.offset_top = BAR_MARGIN_TOP
	_bar_rect.offset_bottom = BAR_MARGIN_TOP + BAR_SIZE.y

	# 加载 Shader
	var shader := load("res://shaders/boss_hp_bar.gdshader")
	if shader:
		_bar_material = ShaderMaterial.new()
		_bar_material.shader = shader
		_bar_rect.material = _bar_material

	add_child(_bar_rect)

	# HP 数值文字
	_hp_text_label = Label.new()
	_hp_text_label.name = "HPTextLabel"
	_hp_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_text_label.add_theme_font_size_override("font_size", 12)
	_hp_text_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	_hp_text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar_rect.add_child(_hp_text_label)

	# 阶段名称
	_phase_label = Label.new()
	_phase_label.name = "PhaseLabel"
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.add_theme_font_size_override("font_size", 11)
	_phase_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.8))
	_phase_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_phase_label.offset_top = -20
	_phase_label.offset_left = -200
	_phase_label.offset_right = 200
	add_child(_phase_label)

# ============================================================
# Shader 参数
# ============================================================

func _update_shader_params() -> void:
	if _bar_material == null:
		return

	_bar_material.set_shader_parameter("hp_ratio", _current_hp)
	_bar_material.set_shader_parameter("chapter", _current_chapter)
	_bar_material.set_shader_parameter("damage_flash", _damage_flash_timer / DAMAGE_FLASH_DURATION if DAMAGE_FLASH_DURATION > 0 else 0.0)
	_bar_material.set_shader_parameter("phase_transition", _phase_transition_timer / PHASE_TRANSITION_DURATION if PHASE_TRANSITION_DURATION > 0 else 0.0)
	_bar_material.set_shader_parameter("beat_intensity", _beat_intensity)

	var fill_color: Color = CHAPTER_FILL_COLORS.get(_current_chapter, Color.RED)
	var border_color: Color = CHAPTER_BORDER_COLORS.get(_current_chapter, Color.GRAY)
	_bar_material.set_shader_parameter("bar_fill_color", fill_color)
	_bar_material.set_shader_parameter("bar_border_color", border_color)

func _update_hp_text() -> void:
	if _hp_text_label:
		var current_val := int(_current_hp * _max_hp)
		var max_val := int(_max_hp)
		_hp_text_label.text = "%d / %d" % [current_val, max_val]

# ============================================================
# 节拍回调
# ============================================================

func _on_beat_tick(_beat_index: int) -> void:
	_beat_intensity = 1.0

# ============================================================
# 公共接口
# ============================================================

## 初始化 Boss 血条
func setup_boss(boss_name: String, chapter: int, max_hp: float, phase_names: Array = []) -> void:
	_boss_name = boss_name
	_current_chapter = clampi(chapter, 1, 7)
	_max_hp = max_hp
	_current_hp = 1.0
	_target_hp = 1.0
	_phase_names = phase_names
	_current_phase = 0

	if _name_label:
		_name_label.text = _boss_name
		# 使用章节对应的边框色作为名称颜色
		_name_label.add_theme_color_override("font_color", CHAPTER_BORDER_COLORS.get(_current_chapter, Color.WHITE))

	if _phase_label and not _phase_names.is_empty():
		_phase_label.text = _phase_names[0]

	_visible_target = true
	visible = true
	modulate.a = 1.0
	_update_shader_params()

## 更新 Boss 血量
func update_hp(current_hp: float, max_hp: float) -> void:
	_max_hp = max_hp
	var new_ratio := clampf(current_hp / max_hp, 0.0, 1.0)

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
		_phase_label.text = _phase_names[phase_index]

	phase_changed.emit(phase_index)

## 兼容接口
func show_boss_bar(boss_node: Node) -> void:
	if boss_node == null:
		return

	var b_name: String = boss_node.get("boss_name") if boss_node.get("boss_name") else "Boss"
	var chapter: int = 1
	var b_max_hp: float = boss_node.get("max_hp") if boss_node.get("max_hp") else 1000.0
	var b_current_hp: float = boss_node.get("current_hp") if boss_node.get("current_hp") else b_max_hp
	var phase_names: Array = []

	if boss_node.has_method("get_boss_bar_data"):
		var data: Dictionary = boss_node.get_boss_bar_data()
		b_name = data.get("name", b_name)
		b_max_hp = data.get("max_hp", b_max_hp)
		b_current_hp = data.get("hp", b_current_hp)
		chapter = data.get("chapter", chapter)
		var total_phases: int = data.get("total_phases", 1)
		for i in range(total_phases):
			phase_names.append("Phase %d" % (i + 1))

	# 尝试获取章节
	var chapter_mgr = get_node_or_null("/root/ChapterManager")
	if chapter_mgr and chapter_mgr.has_method("get_current_chapter_index"):
		chapter = clampi(chapter_mgr.get_current_chapter_index() + 1, 1, 7)

	setup_boss(b_name, chapter, b_max_hp, phase_names)
	update_hp(b_current_hp, b_max_hp)

## 隐藏血条
func hide_boss_bar() -> void:
	_visible_target = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): visible = false; modulate.a = 1.0)
