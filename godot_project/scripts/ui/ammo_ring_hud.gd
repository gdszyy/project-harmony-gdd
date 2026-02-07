## ammo_ring_hud.gd
## 弹药/冷却环形 HUD (Issue #26)
## 围绕玩家核心的环形刻度，显示自动施法和手动施法状态
extends Node2D

# ============================================================
# 配置
# ============================================================
## 环形半径
@export var ring_radius: float = 60.0
## 自动施法刻度数量（对应序列器长度）
const AUTO_CAST_TICKS: int = 16
## 手动施法槽数量
const MANUAL_CAST_SLOTS: int = 3

# ============================================================
# 颜色配置
# ============================================================
const COLOR_AUTO_INACTIVE := Color(0.2, 0.2, 0.3, 0.5)
const COLOR_AUTO_ACTIVE := Color(0.0, 0.8, 1.0, 1.0)
const COLOR_MANUAL_READY := Color(1.0, 0.8, 0.0, 1.0)
const COLOR_MANUAL_COOLDOWN := Color(0.3, 0.3, 0.4, 0.5)

# ============================================================
# 节点引用
# ============================================================
var _auto_cast_markers: Array[Node2D] = []
var _manual_cast_indicators: Array[Node2D] = []
var _beat_cursor: Node2D = null

# ============================================================
# 状态
# ============================================================
var _current_beat_position: int = 0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_auto_cast_ring()
	_setup_manual_cast_indicators()
	_setup_beat_cursor()
	
	# 连接信号
	if GameManager.has_signal("beat_tick"):
		GameManager.beat_tick.connect(_on_beat_tick)
	if SpellcraftSystem.has_signal("sequencer_updated"):
		SpellcraftSystem.sequencer_updated.connect(_on_sequencer_updated)

func _process(_delta: float) -> void:
	_update_beat_cursor()
	_update_manual_cast_indicators()

# ============================================================
# 自动施法环形刻度
# ============================================================

func _setup_auto_cast_ring() -> void:
	for i in range(AUTO_CAST_TICKS):
		var marker := _create_tick_marker(i)
		_auto_cast_markers.append(marker)
		add_child(marker)

func _create_tick_marker(index: int) -> Node2D:
	var marker := Node2D.new()
	
	# 计算位置（圆形排列）
	var angle := (TAU / AUTO_CAST_TICKS) * index - PI / 2.0  # -PI/2 使0点在顶部
	var pos := Vector2.from_angle(angle) * ring_radius
	marker.position = pos
	
	# 创建视觉元素（小矩形）
	var rect := ColorRect.new()
	rect.size = Vector2(3, 8)
	rect.position = Vector2(-1.5, -4)
	rect.color = COLOR_AUTO_INACTIVE
	marker.add_child(rect)
	
	# 旋转使其指向圆心
	marker.rotation = angle + PI / 2.0
	
	return marker

func _update_tick_marker(index: int, is_active: bool) -> void:
	if index < 0 or index >= _auto_cast_markers.size():
		return
	
	var marker := _auto_cast_markers[index]
	var rect := marker.get_child(0) as ColorRect
	if rect:
		rect.color = COLOR_AUTO_ACTIVE if is_active else COLOR_AUTO_INACTIVE

# ============================================================
# 节拍光标
# ============================================================

func _setup_beat_cursor() -> void:
	_beat_cursor = Node2D.new()
	_beat_cursor.name = "BeatCursor"
	add_child(_beat_cursor)
	
	# 创建光点
	var light := ColorRect.new()
	light.size = Vector2(6, 6)
	light.position = Vector2(-3, -3)
	light.color = Color(1.0, 1.0, 1.0, 1.0)
	_beat_cursor.add_child(light)
	
	# 创建拖尾效果（可选）
	var trail := Line2D.new()
	trail.width = 2.0
	trail.default_color = Color(0.5, 0.8, 1.0, 0.5)
	_beat_cursor.add_child(trail)

func _update_beat_cursor() -> void:
	if _beat_cursor == null:
		return
	
	# 获取当前序列器位置
	var seq_pos := SpellcraftSystem.get_sequencer_position()
	
	# 计算角度
	var angle := (TAU / AUTO_CAST_TICKS) * seq_pos - PI / 2.0
	
	# 平滑插值（基于节拍进度）
	var beat_progress := GameManager.get_beat_progress() if GameManager.has_method("get_beat_progress") else 0.0
	var next_angle := (TAU / AUTO_CAST_TICKS) * ((seq_pos + 1) % AUTO_CAST_TICKS) - PI / 2.0
	var current_angle := lerp_angle(angle, next_angle, beat_progress)
	
	# 更新位置
	_beat_cursor.position = Vector2.from_angle(current_angle) * ring_radius
	
	# 脉冲效果
	var pulse := 1.0 + sin(beat_progress * PI) * 0.3
	_beat_cursor.scale = Vector2(pulse, pulse)

# ============================================================
# 手动施法指示器
# ============================================================

func _setup_manual_cast_indicators() -> void:
	for i in range(MANUAL_CAST_SLOTS):
		var indicator := _create_manual_indicator(i)
		_manual_cast_indicators.append(indicator)
		add_child(indicator)

func _create_manual_indicator(slot_index: int) -> Node2D:
	var indicator := Node2D.new()
	
	# 计算位置（在环外侧，均匀分布）
	var angle := (TAU / MANUAL_CAST_SLOTS) * slot_index + PI / 2.0
	var pos := Vector2.from_angle(angle) * (ring_radius + 30.0)
	indicator.position = pos
	
	# 创建背景圆
	var bg := ColorRect.new()
	bg.size = Vector2(24, 24)
	bg.position = Vector2(-12, -12)
	bg.color = COLOR_MANUAL_COOLDOWN
	indicator.add_child(bg)
	
	# 创建快捷键标签
	var label := Label.new()
	label.text = str(slot_index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-12, -12)
	label.size = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	indicator.add_child(label)
	
	return indicator

func _update_manual_cast_indicators() -> void:
	for i in range(min(MANUAL_CAST_SLOTS, _manual_cast_indicators.size())):
		var indicator := _manual_cast_indicators[i]
		var bg := indicator.get_child(0) as ColorRect
		if bg == null:
			continue
		
		# 检查槽位状态
		var slot_data := SpellcraftSystem.manual_cast_slots[i] if i < SpellcraftSystem.manual_cast_slots.size() else {}
		var is_ready := slot_data.get("type", "empty") != "empty"
		
		# 更新颜色
		bg.color = COLOR_MANUAL_READY if is_ready else COLOR_MANUAL_COOLDOWN
		
		# 就绪时的电流特效
		if is_ready:
			# 脉冲动画
			var time := Time.get_ticks_msec() * 0.001
			var pulse := 1.0 + sin(time * 3.0) * 0.1
			indicator.scale = Vector2(pulse, pulse)
			
			# 颜色闪烁
			bg.color = COLOR_MANUAL_READY.lerp(Color.WHITE, sin(time * 5.0) * 0.3 + 0.3)
		else:
			indicator.scale = Vector2.ONE

# ============================================================
# 信号回调
# ============================================================

func _on_beat_tick(beat_index: int) -> void:
	_current_beat_position = beat_index % AUTO_CAST_TICKS
	
	# 高亮当前拍的刻度
	for i in range(AUTO_CAST_TICKS):
		_update_tick_marker(i, i == _current_beat_position)

func _on_sequencer_updated(sequence: Array) -> void:
	# 根据序列器内容更新刻度颜色
	# 这里可以根据是否有音符来改变刻度的显示
	pass
