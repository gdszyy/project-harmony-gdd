## boss_health_bar.gd
## Boss 血条 UI (Issue #27)
## 显示在屏幕顶部的 Boss 专属血条，包含：
## - Boss 名称和标题
## - HP 条（带平滑动画）
## - 护盾条（叠加在 HP 条上方）
## - 阶段指示器
## - 脆弱状态标记
## - 入场/退场动画
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal boss_bar_hidden()

# ============================================================
# 配置
# ============================================================
const BAR_WIDTH: float = 600.0
const BAR_HEIGHT: float = 16.0
const SHIELD_BAR_HEIGHT: float = 8.0
const BAR_Y_POSITION: float = 40.0
const SMOOTH_SPEED: float = 3.0

# ============================================================
# 内部状态
# ============================================================
var _boss: Node = null
var _is_visible: bool = false
var _displayed_hp_ratio: float = 1.0
var _displayed_shield_ratio: float = 0.0
var _target_hp_ratio: float = 1.0
var _target_shield_ratio: float = 0.0

# ============================================================
# UI 节点
# ============================================================
var _container: Control = null
var _name_label: Label = null
var _title_label: Label = null
var _hp_bar_bg: ColorRect = null
var _hp_bar_damage: ColorRect = null  # 延迟伤害条（红色）
var _hp_bar_fill: ColorRect = null
var _shield_bar_bg: ColorRect = null
var _shield_bar_fill: ColorRect = null
var _phase_container: HBoxContainer = null
var _phase_indicators: Array[ColorRect] = []
var _vulnerability_label: Label = null

# ============================================================
# 颜色配置
# ============================================================
const HP_COLOR := Color(0.8, 0.2, 0.3)
const HP_LOW_COLOR := Color(1.0, 0.1, 0.1)
const HP_BG_COLOR := Color(0.15, 0.1, 0.1, 0.8)
const DAMAGE_COLOR := Color(0.9, 0.3, 0.1, 0.7)
const SHIELD_COLOR := Color(0.3, 0.7, 1.0, 0.9)
const SHIELD_BG_COLOR := Color(0.1, 0.15, 0.2, 0.6)
const PHASE_ACTIVE_COLOR := Color(1.0, 0.85, 0.3)
const PHASE_INACTIVE_COLOR := Color(0.3, 0.3, 0.3, 0.5)
const PHASE_CURRENT_COLOR := Color(1.0, 0.5, 0.2)

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_create_ui()
	_hide_immediate()

func _process(delta: float) -> void:
	if not _is_visible or _boss == null:
		return
	
	if not is_instance_valid(_boss):
		hide_boss_bar()
		return
	
	_update_data()
	_smooth_bars(delta)
	_update_visuals()

# ============================================================
# UI 创建
# ============================================================

func _create_ui() -> void:
	_container = Control.new()
	_container.name = "BossBarContainer"
	_container.anchor_left = 0.5
	_container.anchor_right = 0.5
	_container.anchor_top = 0.0
	_container.anchor_bottom = 0.0
	_container.offset_left = -BAR_WIDTH / 2.0
	_container.offset_right = BAR_WIDTH / 2.0
	_container.offset_top = BAR_Y_POSITION
	_container.offset_bottom = BAR_Y_POSITION + 80.0
	add_child(_container)
	
	# Boss 名称
	_name_label = Label.new()
	_name_label.name = "BossName"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(0, 0)
	_name_label.size = Vector2(BAR_WIDTH, 24)
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8))
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_name_label.add_theme_constant_override("shadow_offset_x", 2)
	_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_container.add_child(_name_label)
	
	# Boss 标题
	_title_label = Label.new()
	_title_label.name = "BossTitle"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.position = Vector2(0, 22)
	_title_label.size = Vector2(BAR_WIDTH, 16)
	_title_label.add_theme_font_size_override("font_size", 11)
	_title_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.8, 0.8))
	_container.add_child(_title_label)
	
	# HP 条背景
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.position = Vector2(0, 42)
	_hp_bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_bar_bg.color = HP_BG_COLOR
	_container.add_child(_hp_bar_bg)
	
	# HP 延迟伤害条
	_hp_bar_damage = ColorRect.new()
	_hp_bar_damage.position = Vector2(0, 42)
	_hp_bar_damage.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_bar_damage.color = DAMAGE_COLOR
	_container.add_child(_hp_bar_damage)
	
	# HP 填充条
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.position = Vector2(0, 42)
	_hp_bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_bar_fill.color = HP_COLOR
	_container.add_child(_hp_bar_fill)
	
	# 护盾条背景
	_shield_bar_bg = ColorRect.new()
	_shield_bar_bg.position = Vector2(0, 42 + BAR_HEIGHT + 2)
	_shield_bar_bg.size = Vector2(BAR_WIDTH, SHIELD_BAR_HEIGHT)
	_shield_bar_bg.color = SHIELD_BG_COLOR
	_shield_bar_bg.visible = false
	_container.add_child(_shield_bar_bg)
	
	# 护盾填充条
	_shield_bar_fill = ColorRect.new()
	_shield_bar_fill.position = Vector2(0, 42 + BAR_HEIGHT + 2)
	_shield_bar_fill.size = Vector2(BAR_WIDTH, SHIELD_BAR_HEIGHT)
	_shield_bar_fill.color = SHIELD_COLOR
	_shield_bar_fill.visible = false
	_container.add_child(_shield_bar_fill)
	
	# 阶段指示器容器
	_phase_container = HBoxContainer.new()
	_phase_container.position = Vector2(BAR_WIDTH / 2.0 - 50, 42 + BAR_HEIGHT + SHIELD_BAR_HEIGHT + 6)
	_phase_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_phase_container.add_theme_constant_override("separation", 8)
	_container.add_child(_phase_container)
	
	# 脆弱状态标签
	_vulnerability_label = Label.new()
	_vulnerability_label.name = "VulnLabel"
	_vulnerability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vulnerability_label.position = Vector2(0, 42 + BAR_HEIGHT + SHIELD_BAR_HEIGHT + 24)
	_vulnerability_label.size = Vector2(BAR_WIDTH, 16)
	_vulnerability_label.add_theme_font_size_override("font_size", 12)
	_vulnerability_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_vulnerability_label.text = "VULNERABLE"
	_vulnerability_label.visible = false
	_container.add_child(_vulnerability_label)

# ============================================================
# 公共接口
# ============================================================

## 显示 Boss 血条
func show_boss_bar(boss: Node) -> void:
	_boss = boss
	_is_visible = true
	
	# 初始化数据
	if boss.has_method("get_boss_bar_data"):
		var data: Dictionary = boss.get_boss_bar_data()
		_name_label.text = data.get("name", "???")
		_title_label.text = data.get("title", "")
		_displayed_hp_ratio = data.get("hp_ratio", 1.0)
		_target_hp_ratio = _displayed_hp_ratio
		
		# 创建阶段指示器
		_create_phase_indicators(data.get("total_phases", 1))
	
	# 入场动画
	_container.modulate.a = 0.0
	_container.position.y = -20.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_container, "modulate:a", 1.0, 0.5)
	tween.tween_property(_container, "position:y", 0.0, 0.5).set_ease(Tween.EASE_OUT)

## 隐藏 Boss 血条
func hide_boss_bar() -> void:
	if not _is_visible:
		return
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_container, "modulate:a", 0.0, 0.5)
	tween.tween_property(_container, "position:y", -20.0, 0.5)
	tween.chain()
	tween.tween_callback(func():
		_is_visible = false
		_boss = null
		boss_bar_hidden.emit()
	)

func _hide_immediate() -> void:
	_container.modulate.a = 0.0
	_is_visible = false

# ============================================================
# 数据更新
# ============================================================

func _update_data() -> void:
	if _boss == null or not _boss.has_method("get_boss_bar_data"):
		return
	
	var data: Dictionary = _boss.get_boss_bar_data()
	_target_hp_ratio = data.get("hp_ratio", 0.0)
	_target_shield_ratio = data.get("shield_ratio", 0.0)
	
	# 护盾显示
	var has_shield: bool = data.get("max_shield_hp", 0.0) > 0.0
	_shield_bar_bg.visible = has_shield
	_shield_bar_fill.visible = has_shield
	
	# 阶段指示器更新
	var current_phase: int = data.get("phase", 0)
	_update_phase_indicators(current_phase)
	
	# 脆弱状态
	_vulnerability_label.visible = data.get("is_vulnerable", false)

func _smooth_bars(delta: float) -> void:
	# HP 条平滑
	_displayed_hp_ratio = lerp(_displayed_hp_ratio, _target_hp_ratio, SMOOTH_SPEED * delta)
	
	# 护盾条平滑
	_displayed_shield_ratio = lerp(_displayed_shield_ratio, _target_shield_ratio, SMOOTH_SPEED * delta)

func _update_visuals() -> void:
	# HP 条
	_hp_bar_fill.size.x = BAR_WIDTH * _displayed_hp_ratio
	
	# 延迟伤害条（比实际 HP 慢）
	var damage_ratio := lerp(float(_hp_bar_damage.size.x / BAR_WIDTH), _displayed_hp_ratio, 0.02)
	_hp_bar_damage.size.x = BAR_WIDTH * max(damage_ratio, _displayed_hp_ratio)
	
	# HP 颜色（低 HP 时变红）
	_hp_bar_fill.color = HP_COLOR.lerp(HP_LOW_COLOR, 1.0 - _displayed_hp_ratio)
	
	# 护盾条
	_shield_bar_fill.size.x = BAR_WIDTH * _displayed_shield_ratio

# ============================================================
# 阶段指示器
# ============================================================

func _create_phase_indicators(total_phases: int) -> void:
	# 清除旧的
	for indicator in _phase_indicators:
		indicator.queue_free()
	_phase_indicators.clear()
	
	for i in range(total_phases):
		var indicator := ColorRect.new()
		indicator.custom_minimum_size = Vector2(12, 12)
		indicator.color = PHASE_INACTIVE_COLOR
		_phase_container.add_child(indicator)
		_phase_indicators.append(indicator)

func _update_phase_indicators(current_phase: int) -> void:
	for i in range(_phase_indicators.size()):
		if i < current_phase:
			_phase_indicators[i].color = PHASE_ACTIVE_COLOR
		elif i == current_phase:
			# 当前阶段闪烁
			var pulse := sin(Time.get_ticks_msec() * 0.005) * 0.3
			_phase_indicators[i].color = PHASE_CURRENT_COLOR.lerp(Color.WHITE, 0.3 + pulse)
		else:
			_phase_indicators[i].color = PHASE_INACTIVE_COLOR
