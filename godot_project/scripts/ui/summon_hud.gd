## summon_hud.gd
## 召唤物 HUD 面板
## 显示当前活跃的幻影声部信息：类型、剩余时间、共鸣加成
## 位于屏幕右侧，紧凑的垂直列表
extends Control

# ============================================================
# 配置
# ============================================================
const SLOT_SIZE := Vector2(140, 36)
const SLOT_MARGIN := 4.0
const MAX_DISPLAY_SLOTS := 4
const BG_COLOR := Color(0.03, 0.03, 0.08, 0.7)
const BORDER_COLOR := Color(0.2, 0.2, 0.3, 0.5)

# ============================================================
# 状态
# ============================================================
var _summon_manager: Node = null
var _summon_data: Array[Dictionary] = []
var _resonance_bonus: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 查找 SummonManager
	_summon_manager = get_node_or_null("/root/SummonManager")
	if _summon_manager == null:
		_summon_manager = get_tree().current_scene.get_node_or_null("SummonManager")
	
	if _summon_manager:
		if _summon_manager.has_signal("summon_created"):
			_summon_manager.summon_created.connect(_on_summon_changed)
		if _summon_manager.has_signal("summon_expired"):
			_summon_manager.summon_expired.connect(_on_summon_expired)
		if _summon_manager.has_signal("resonance_activated"):
			_summon_manager.resonance_activated.connect(_on_resonance_updated)
	
	# 设置位置（右侧）
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	custom_minimum_size = Vector2(SLOT_SIZE.x + 10, (SLOT_SIZE.y + SLOT_MARGIN) * MAX_DISPLAY_SLOTS + 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	_update_data()
	queue_redraw()

# ============================================================
# 数据更新
# ============================================================

func _update_data() -> void:
	if _summon_manager and _summon_manager.has_method("get_active_summons_info"):
		_summon_data = _summon_manager.get_active_summons_info()
	if _summon_manager and _summon_manager.has_method("get_resonance_bonus"):
		_resonance_bonus = _summon_manager.get_resonance_bonus()

func _on_summon_changed(_data: Dictionary) -> void:
	_update_data()

func _on_summon_expired(_id: int) -> void:
	_update_data()

func _on_resonance_updated(bonus: float) -> void:
	_resonance_bonus = bonus

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if _summon_data.is_empty():
		return
	
	var font := ThemeDB.fallback_font
	var start_x := 5.0
	var start_y := 5.0
	
	# 背景
	var total_height := (_summon_data.size()) * (SLOT_SIZE.y + SLOT_MARGIN) + 30
	draw_rect(Rect2(Vector2(0, 0), Vector2(SLOT_SIZE.x + 10, total_height)), BG_COLOR)
	
	# 标题
	draw_string(font, Vector2(start_x, 14), "PHANTOM VOICES", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.5, 0.6))
	
	# 共鸣加成
	if _resonance_bonus > 0.0:
		var res_text := "Resonance: +%.0f%%" % (_resonance_bonus * 100.0)
		draw_string(font, Vector2(start_x + 90, 14), res_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.7, 0.2))
	
	start_y = 22.0
	
	# 绘制每个召唤物槽位
	for i in range(min(_summon_data.size(), MAX_DISPLAY_SLOTS)):
		var data: Dictionary = _summon_data[i]
		var slot_y := start_y + i * (SLOT_SIZE.y + SLOT_MARGIN)
		var slot_rect := Rect2(Vector2(start_x, slot_y), SLOT_SIZE)
		
		var color: Color = data.get("color", Color(0.5, 0.5, 0.5))
		var time_remaining: float = data.get("time_remaining", 0.0)
		var type_name: String = data.get("type_name", "")
		
		# 槽位背景
		var bg := Color(color.r, color.g, color.b, 0.15)
		draw_rect(slot_rect, bg)
		
		# 时间条
		var max_duration := 12.0  # 基础持续时间
		var time_ratio = clamp(time_remaining / max_duration, 0.0, 1.0)
		var bar_rect := Rect2(
			Vector2(start_x, slot_y + SLOT_SIZE.y - 3),
			Vector2(SLOT_SIZE.x * time_ratio, 3)
		)
		var bar_color := color
		bar_color.a = 0.6
		if time_remaining < 3.0:
			bar_color = Color(1.0, 0.3, 0.1, 0.8)
		draw_rect(bar_rect, bar_color)
		
		# 边框
		draw_rect(slot_rect, BORDER_COLOR, false, 1.0)
		
		# 类型图标（小色块）
		var icon_rect := Rect2(Vector2(start_x + 3, slot_y + 4), Vector2(8, 8))
		draw_rect(icon_rect, color)
		
		# 类型名称
		draw_string(font, Vector2(start_x + 15, slot_y + 14), type_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		
		# 剩余时间
		var time_text := "%.1fs" % time_remaining
		var time_color := Color(0.7, 0.7, 0.8)
		if time_remaining < 3.0:
			time_color = Color(1.0, 0.4, 0.2)
		draw_string(font, Vector2(start_x + SLOT_SIZE.x - 35, slot_y + 14), time_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, time_color)
		
		# ID
		draw_string(font, Vector2(start_x + 15, slot_y + 28), "#%d" % data.get("id", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.4, 0.5))
