## theory_breakthrough_popup.gd
## 乐理突破事件特殊 UI — v6.0
##
## 根据 UI_Design_Module4_CircleOfFifths.md §7 设计文档实现：
##   - 全屏金色闪光 + 几何图案粒子效果
##   - 罗盘剧烈旋转 → 中心星云爆发金色光芒
##   - 传说级卡片展示（金色边框 + 脉冲辉光）
##   - 仪式感十足的动画序列
##
## 触发条件：
##   - 玩家在特定音级组合上积累足够升级时触发
##   - 由 UpgradeManager 检测并调用 show_breakthrough()
extends Control

# ============================================================
# 信号
# ============================================================
signal breakthrough_acknowledged(breakthrough_data: Dictionary)
signal breakthrough_animation_completed()

# ============================================================
# 常量 — 颜色 (§1.2)
# ============================================================

# ============================================================
# 动画参数
# ============================================================
const FLASH_DURATION: float = 0.4
const SPIN_DURATION: float = 1.5
const REVEAL_DURATION: float = 0.6
const PARTICLE_COUNT: int = 30

# ============================================================
# 状态
# ============================================================
var _breakthrough_data: Dictionary = {}
var _is_active: bool = false
var _time: float = 0.0
var _particles: Array = []  ## [{pos, vel, life, max_life, size, color}]
var _flash_alpha: float = 0.0
var _spin_angle: float = 0.0
var _nebula_alpha: float = 0.0

# 节点
var _overlay: ColorRect = null
var _card_panel: PanelContainer = null
var _title_label: Label = null
var _desc_label: Label = null
var _confirm_btn: Button = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _process(delta: float) -> void:
	if not _is_active:
		return
	_time += delta

	# 更新粒子
	var i := _particles.size() - 1
	while i >= 0:
		var p := _particles[i] as Dictionary
		p["life"] -= delta
		if p["life"] <= 0:
			_particles.remove_at(i)
		else:
			p["pos"] += p["vel"] * delta
			p["vel"] *= 0.98  # 阻力
		i -= 1

	queue_redraw()

func _draw() -> void:
	if not _is_active:
		return

	var center := size / 2.0

	# 金色闪光
	if _flash_alpha > 0:
		draw_rect(Rect2(Vector2.ZERO, size), UIColors.with_alpha(UIColors.GOLD, _flash_alpha))

	# 几何图案粒子
	for p in _particles:
		var life_ratio := p["life"] / p["max_life"]
		var alpha := life_ratio * 0.8
		var col := UIColors.with_alpha(p["color"], alpha)
		var s: float = p["size"] * life_ratio

		# 绘制菱形粒子
		var pos: Vector2 = p["pos"]
		var points := PackedVector2Array([
			pos + Vector2(0, -s),
			pos + Vector2(s * 0.6, 0),
			pos + Vector2(0, s),
			pos + Vector2(-s * 0.6, 0),
		])
		draw_colored_polygon(points, col)

	# 中心星云辉光
	if _nebula_alpha > 0:
		var glow_col := UIColors.with_alpha(UIColors.GOLD, _nebula_alpha * 0.3)
		for r in range(3):
			var radius := 80.0 + r * 40.0
			draw_arc(center, radius, 0, TAU, 64, glow_col, 2.0 + r)

# ============================================================
# 公共接口
# ============================================================

## 显示乐理突破事件
func show_breakthrough(data: Dictionary) -> void:
	if _is_active:
		return

	_breakthrough_data = data
	_is_active = true
	_time = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 启动动画序列
	_play_breakthrough_sequence()

## 关闭
func dismiss() -> void:
	_play_dismiss_animation()

# ============================================================
# 动画序列
# ============================================================

func _play_breakthrough_sequence() -> void:
	# 阶段1：金色全屏闪光
	var tween := create_tween()

	# 闪光
	tween.tween_method(_set_flash_alpha, 0.0, 0.8, FLASH_DURATION * 0.3)
	tween.tween_method(_set_flash_alpha, 0.8, 0.0, FLASH_DURATION * 0.7)

	# 阶段2：生成粒子
	tween.tween_callback(_spawn_particles)

	# 阶段3：星云辉光
	tween.tween_method(_set_nebula_alpha, 0.0, 1.0, 0.5)

	# 阶段4：等待一下再展示卡片
	tween.tween_interval(0.3)

	# 阶段5：展示传说级卡片
	tween.tween_callback(_build_breakthrough_card)
	tween.tween_callback(func(): breakthrough_animation_completed.emit())

func _set_flash_alpha(val: float) -> void:
	_flash_alpha = val

func _set_nebula_alpha(val: float) -> void:
	_nebula_alpha = val

func _spawn_particles() -> void:
	var center := size / 2.0
	for i in range(PARTICLE_COUNT):
		var angle := randf() * TAU
		var speed := randf_range(100.0, 300.0)
		var particle := {
			"pos": center + Vector2(randf_range(-20, 20), randf_range(-20, 20)),
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": randf_range(1.0, 2.5),
			"max_life": randf_range(1.0, 2.5),
			"size": randf_range(4.0, 12.0),
			"color": UIColors.GOLD.lerp(UIColors.GOLD_BRIGHT, randf()),
		}
		particle["max_life"] = particle["life"]
		_particles.append(particle)

func _build_breakthrough_card() -> void:
	# 暗色背景
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = UIColors.with_alpha(UIColors.PRIMARY_BG, 0.85)
	_overlay.modulate.a = 0.0
	add_child(_overlay)

	# 传说级卡片面板
	_card_panel = PanelContainer.new()
	_card_panel.set_anchors_preset(Control.PRESET_CENTER)
	_card_panel.offset_left = -180
	_card_panel.offset_right = 180
	_card_panel.offset_top = -200
	_card_panel.offset_bottom = 120

	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.PANEL_BG
	style.border_color = UIColors.GOLD
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = UIColors.with_alpha(UIColors.GOLD, 0.3)
	style.shadow_size = 12
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 20
	_card_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# 顶部装饰
	var deco := Label.new()
	deco.text = "✦ 乐理突破 ✦"
	deco.add_theme_font_size_override("font_size", 14)
	deco.add_theme_color_override("font_color", UIColors.GOLD)
	deco.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(deco)

	# 图标
	var icon := Label.new()
	icon.text = "♮"
	icon.add_theme_font_size_override("font_size", 48)
	icon.add_theme_color_override("font_color", UIColors.GOLD_BRIGHT)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon)

	# 标题
	_title_label = Label.new()
	_title_label.text = _breakthrough_data.get("title", "乐理突破")
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", UIColors.GOLD)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title_label)

	# 分割线
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = UIColors.with_alpha(UIColors.GOLD, 0.4)
	vbox.add_child(sep)

	# 描述
	_desc_label = Label.new()
	_desc_label.text = _breakthrough_data.get("description", "你在音乐理论上获得了新的领悟。")
	_desc_label.add_theme_font_size_override("font_size", 14)
	_desc_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_desc_label)

	# 效果说明
	var effect_text: String = _breakthrough_data.get("effect_text", "")
	if not effect_text.is_empty():
		var effect_label := Label.new()
		effect_label.text = effect_text
		effect_label.add_theme_font_size_override("font_size", 12)
		effect_label.add_theme_color_override("font_color", UIColors.ACCENT)
		effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(effect_label)

	# 确认按钮
	_confirm_btn = Button.new()
	_confirm_btn.text = "领悟 ✦"
	_confirm_btn.custom_minimum_size = Vector2(160, 40)
	_confirm_btn.pressed.connect(_on_confirm)
	_confirm_btn.add_theme_color_override("font_color", UIColors.PANEL_BG)
	_confirm_btn.add_theme_font_size_override("font_size", 15)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = UIColors.GOLD
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.content_margin_left = 20
	btn_style.content_margin_right = 20
	btn_style.content_margin_top = 8
	btn_style.content_margin_bottom = 8
	_confirm_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = UIColors.GOLD_BRIGHT
	_confirm_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_center := CenterContainer.new()
	btn_center.add_child(_confirm_btn)
	vbox.add_child(btn_center)

	_card_panel.add_child(vbox)
	_card_panel.modulate.a = 0.0
	_card_panel.scale = Vector2(0.7, 0.7)
	_card_panel.pivot_offset = Vector2(180, 160)
	add_child(_card_panel)

	# 入场动画
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(_card_panel, "modulate:a", 1.0, REVEAL_DURATION)
	tween.tween_property(_card_panel, "scale", Vector2(1.0, 1.0), REVEAL_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_confirm() -> void:
	breakthrough_acknowledged.emit(_breakthrough_data)
	_play_dismiss_animation()

func _play_dismiss_animation() -> void:
	var tween := create_tween().set_parallel(true)
	if _card_panel and is_instance_valid(_card_panel):
		tween.tween_property(_card_panel, "modulate:a", 0.0, 0.3)
		tween.tween_property(_card_panel, "scale", Vector2(1.1, 1.1), 0.3)
	if _overlay and is_instance_valid(_overlay):
		tween.tween_property(_overlay, "modulate:a", 0.0, 0.3)

	tween.chain().tween_callback(func():
		_is_active = false
		_particles.clear()
		_flash_alpha = 0.0
		_nebula_alpha = 0.0
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for child in get_children():
			child.queue_free()
	)
