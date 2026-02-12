## summon_hud.gd — 召唤物 HUD 面板
## 屏幕右上角卡片式列表，显示活跃召唤物状态
## 支持：滑入/滑出动画、状态边框闪烁、持续时间进度条
extends Control

# ============================================================
# 配置
# ============================================================
const CARD_SIZE := Vector2(180, 48)
const CARD_MARGIN := 6.0
const MAX_DISPLAY_CARDS := 5
const ICON_SIZE := 36.0
const PROGRESS_BAR_HEIGHT := 3.0

# 颜色
const BG_COLOR := Color(0.04, 0.03, 0.08, 0.75)
const BORDER_COLOR := Color(0.616, 0.435, 1.0, 0.3)
const BORDER_UPGRADE := Color(1.0, 0.843, 0.0, 0.8)
const BORDER_BERSERK := Color(1.0, 0.133, 0.267, 0.8)
const COLOR_CRYSTAL_WHITE := Color(0.918, 0.902, 1.0)
const COLOR_WARNING := Color(1.0, 0.3, 0.1)

# ============================================================
# 状态
# ============================================================
var _summon_manager: Node = null
var _summon_data: Array[Dictionary] = []
var _resonance_bonus: float = 0.0
var _time: float = 0.0

## 卡片动画状态: {id: {offset_x: float, alpha: float}}
var _card_animations: Dictionary = {}
## 已知的召唤物 ID 集合
var _known_ids: Array[int] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_summon_manager = get_node_or_null("/root/SummonManager")
	if _summon_manager == null:
		_summon_manager = get_tree().current_scene.get_node_or_null("SummonManager") if get_tree().current_scene else null

	if _summon_manager:
		if _summon_manager.has_signal("summon_created"):
			_summon_manager.summon_created.connect(_on_summon_created)
		if _summon_manager.has_signal("summon_expired"):
			_summon_manager.summon_expired.connect(_on_summon_expired)
		if _summon_manager.has_signal("resonance_activated"):
			_summon_manager.resonance_activated.connect(_on_resonance_updated)

	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	custom_minimum_size = Vector2(CARD_SIZE.x + 20, (CARD_SIZE.y + CARD_MARGIN) * MAX_DISPLAY_CARDS + 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	_update_data()
	_update_animations(delta)
	queue_redraw()

# ============================================================
# 数据更新
# ============================================================

func _update_data() -> void:
	if _summon_manager and _summon_manager.has_method("get_active_summons_info"):
		_summon_data = _summon_manager.get_active_summons_info()
	if _summon_manager and _summon_manager.has_method("get_resonance_bonus"):
		_resonance_bonus = _summon_manager.get_resonance_bonus()

func _update_animations(delta: float) -> void:
	# 更新现有卡片动画
	for id in _card_animations.keys():
		var anim: Dictionary = _card_animations[id]
		# 滑入动画
		if anim.get("entering", false):
			anim["offset_x"] = lerp(anim["offset_x"] as float, 0.0, delta * 8.0)
			anim["alpha"] = lerp(anim["alpha"] as float, 1.0, delta * 6.0)
			if abs(anim["offset_x"]) < 1.0:
				anim["entering"] = false
				anim["offset_x"] = 0.0
				anim["alpha"] = 1.0
		# 滑出动画
		elif anim.get("exiting", false):
			anim["offset_x"] = lerp(anim["offset_x"] as float, CARD_SIZE.x + 20.0, delta * 10.0)
			anim["alpha"] = lerp(anim["alpha"] as float, 0.0, delta * 8.0)
			if anim["alpha"] < 0.05:
				_card_animations.erase(id)

	# 检测新增/消失的召唤物
	var current_ids: Array[int] = []
	for data in _summon_data:
		var id: int = data.get("id", 0)
		current_ids.append(id)
		if id not in _known_ids:
			_card_animations[id] = {"offset_x": CARD_SIZE.x + 20.0, "alpha": 0.0, "entering": true, "exiting": false}
			_known_ids.append(id)

	# 标记消失的召唤物
	var to_remove: Array[int] = []
	for id in _known_ids:
		if id not in current_ids:
			if _card_animations.has(id):
				_card_animations[id]["exiting"] = true
				_card_animations[id]["entering"] = false
			to_remove.append(id)

	for id in to_remove:
		_known_ids.erase(id)

# ============================================================
# 信号回调
# ============================================================

func _on_summon_created(_data: Dictionary) -> void:
	_update_data()

func _on_summon_expired(_id: int) -> void:
	_update_data()

func _on_resonance_updated(bonus: float) -> void:
	_resonance_bonus = bonus

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if _summon_data.is_empty() and _card_animations.is_empty():
		return

	var font := ThemeDB.fallback_font
	var start_x := 5.0
	var start_y := 5.0

	# 面板背景
	var total_height := max(_summon_data.size(), 1) * (CARD_SIZE.y + CARD_MARGIN) + 28
	draw_rect(Rect2(Vector2(0, 0), Vector2(CARD_SIZE.x + 10, total_height)), BG_COLOR)

	# 标题
	draw_string(font, Vector2(start_x, 14), "PHANTOM VOICES", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(COLOR_CRYSTAL_WHITE, 0.5))

	# 共鸣加成
	if _resonance_bonus > 0.0:
		var res_text := "Resonance: +%.0f%%" % (_resonance_bonus * 100.0)
		draw_string(font, Vector2(start_x + 95, 14), res_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.843, 0.0, 0.8))

	start_y = 22.0

	# 绘制卡片
	for i in range(min(_summon_data.size(), MAX_DISPLAY_CARDS)):
		var data: Dictionary = _summon_data[i]
		var id: int = data.get("id", 0)
		var slot_y := start_y + i * (CARD_SIZE.y + CARD_MARGIN)

		# 获取动画偏移
		var offset_x := 0.0
		var alpha := 1.0
		if _card_animations.has(id):
			offset_x = _card_animations[id].get("offset_x", 0.0)
			alpha = _card_animations[id].get("alpha", 1.0)

		_draw_summon_card(data, Vector2(start_x + offset_x, slot_y), alpha, font)

func _draw_summon_card(data: Dictionary, pos: Vector2, alpha: float, font: Font) -> void:
	var color: Color = data.get("color", Color(0.5, 0.5, 0.5))
	var time_remaining: float = data.get("time_remaining", 0.0)
	var max_duration: float = data.get("max_duration", 12.0)
	var type_name: String = data.get("type_name", "Unknown")
	var level: int = data.get("level", 1)
	var status: String = data.get("status", "normal")

	var card_rect := Rect2(pos, CARD_SIZE)

	# 卡片背景
	draw_rect(card_rect, Color(color.r, color.g, color.b, 0.12 * alpha))

	# 状态边框
	var border_col := BORDER_COLOR
	match status:
		"upgrade_ready":
			border_col = BORDER_UPGRADE
			# 金色闪烁
			border_col.a = 0.5 + sin(_time * 4.0) * 0.3
		"berserk":
			border_col = BORDER_BERSERK
			border_col.a = 0.5 + sin(_time * 6.0) * 0.3
		_:
			border_col.a *= alpha

	draw_rect(card_rect, border_col, false, 1.5)

	# 图标色块 (48x48 区域内的小色块)
	var icon_rect := Rect2(pos + Vector2(4, 6), Vector2(ICON_SIZE, ICON_SIZE))
	draw_rect(icon_rect, Color(color, 0.6 * alpha))
	# 图标内文字
	draw_string(font, pos + Vector2(10, 30), type_name.left(2).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(COLOR_CRYSTAL_WHITE, alpha))

	# 名称和等级
	var name_pos := pos + Vector2(ICON_SIZE + 10, 16)
	draw_string(font, name_pos, type_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(COLOR_CRYSTAL_WHITE, alpha))
	draw_string(font, pos + Vector2(ICON_SIZE + 10, 30), "Lv.%d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(COLOR_CRYSTAL_WHITE, 0.6 * alpha))

	# 剩余时间
	var time_text := "%.1fs" % time_remaining
	var time_color := Color(0.7, 0.7, 0.8, alpha)
	if time_remaining < 3.0:
		time_color = Color(COLOR_WARNING, alpha)
		# 闪烁
		time_color.a *= (0.5 + sin(_time * 8.0) * 0.5)
	draw_string(font, pos + Vector2(CARD_SIZE.x - 38, 16), time_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, time_color)

	# 持续时间进度条
	var bar_y := pos.y + CARD_SIZE.y - PROGRESS_BAR_HEIGHT - 1
	var time_ratio := clamp(time_remaining / max_duration, 0.0, 1.0) if max_duration > 0 else 0.0

	# 背景
	draw_rect(Rect2(Vector2(pos.x + 1, bar_y), Vector2(CARD_SIZE.x - 2, PROGRESS_BAR_HEIGHT)), Color(0.1, 0.1, 0.15, 0.5 * alpha))
	# 填充
	var bar_color := Color(color, 0.6 * alpha)
	if time_remaining < 3.0:
		bar_color = Color(COLOR_WARNING, 0.8 * alpha)
	draw_rect(Rect2(Vector2(pos.x + 1, bar_y), Vector2((CARD_SIZE.x - 2) * time_ratio, PROGRESS_BAR_HEIGHT)), bar_color)
