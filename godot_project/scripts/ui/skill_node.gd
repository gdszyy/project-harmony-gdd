## skill_node.gd — 可复用技能树节点组件 v1.0
## 设计文档: Docs/UI_Design_Module5_HallOfHarmony.md §4
##
## 节点三态设计:
##   - 未解锁 (locked): 灰暗虚线几何形状，灰色剪影
##   - 可解锁 (unlockable): 实线强调色辉光，脉动呼吸效果
##   - 已解锁 (unlocked): 谐振青/圣光金填充，强烈稳定光芒
##
## 作为 Control 子类，支持鼠标悬停和点击交互
## 可在 .tscn 场景中实例化，也可由代码动态创建
extends Control
class_name SkillNode

# ============================================================
# 信号
# ============================================================
signal node_clicked(node_id: String)
signal node_hovered(node_id: String)
signal node_unhovered(node_id: String)

# ============================================================
# 导出属性（可在编辑器中配置）
# ============================================================
@export var node_id: String = ""
@export var node_name: String = ""
@export var node_description: String = ""
@export var node_cost: int = 0
@export var node_max_level: int = 1
@export var node_current_level: int = 0
@export var node_color: Color = UIColors.ACCENT
@export var node_radius: float = 32.0

# ============================================================
# 节点状态枚举
# ============================================================
enum State { LOCKED, UNLOCKABLE, UNLOCKED }

# ============================================================
# 颜色常量
# ============================================================
const FRAGMENT_COLOR := UIColors.ACCENT

# ============================================================
# 内部状态
# ============================================================
var _state: State = State.LOCKED
var _is_hovered: bool = false
var _time: float = 0.0
var _unlock_progress: float = -1.0  # -1 = 无动画, 0~1 = 解锁动画
var _error_flash: float = 0.0       # 错误闪烁

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(node_radius * 2.5, node_radius * 2.5 + 30)
	size = custom_minimum_size
	set_process(true)

func _process(delta: float) -> void:
	_time += delta

	# 解锁动画
	if _unlock_progress >= 0.0:
		_unlock_progress += delta * 2.0
		if _unlock_progress >= 1.0:
			_unlock_progress = -1.0

	# 错误闪烁衰减
	if _error_flash > 0.0:
		_error_flash -= delta * 3.0
		if _error_flash < 0.0:
			_error_flash = 0.0

	queue_redraw()

# ============================================================
# 公共接口
# ============================================================

func set_state(new_state: State) -> void:
	_state = new_state
	queue_redraw()

func get_state() -> State:
	return _state

func set_node_data(data: Dictionary) -> void:
	node_id = data.get("id", "")
	node_name = data.get("name", "")
	node_description = data.get("desc", "")
	node_cost = data.get("cost", 0)
	node_max_level = data.get("max_level", 1)
	node_current_level = data.get("current_level", 0)
	if data.has("color"):
		node_color = data["color"]

func play_unlock_animation() -> void:
	_unlock_progress = 0.0

func play_error_flash() -> void:
	_error_flash = 1.0

func update_level(level: int) -> void:
	node_current_level = level
	if level >= node_max_level:
		_state = State.UNLOCKED
	elif level > 0:
		_state = State.UNLOCKED
	queue_redraw()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var center := size / 2.0 - Vector2(0, 12)
	var font := ThemeDB.fallback_font
	var radius := node_radius
	if _is_hovered:
		radius *= 1.15

	match _state:
		State.LOCKED:
			_draw_locked(center, radius, font)
		State.UNLOCKABLE:
			_draw_unlockable(center, radius, font)
		State.UNLOCKED:
			_draw_unlocked(center, radius, font)

	# 错误闪烁覆盖
	if _error_flash > 0.0:
		draw_arc(center, radius + 2, 0, TAU, 48,
			UIColors.with_alpha(UIColors.DANGER, _error_flash * 0.6), 3.0)

	# 解锁动画
	if _unlock_progress >= 0.0:
		_draw_unlock_anim(center, radius)

func _draw_locked(center: Vector2, radius: float, font: Font) -> void:
	# 虚线圆形
	var segments := 20
	for i in range(segments):
		if i % 2 == 0:
			var a1 := float(i) / float(segments) * TAU
			var a2 := float(i + 1) / float(segments) * TAU
			var p1 := center + Vector2(cos(a1), sin(a1)) * radius
			var p2 := center + Vector2(cos(a2), sin(a2)) * radius
			var alpha := 0.4 if _is_hovered else 0.25
			draw_line(p1, p2, UIColors.with_alpha(UIColors.TEXT_LOCKED, alpha), 1.5)

	# 悬停时变实线
	if _is_hovered:
		draw_arc(center, radius, 0, TAU, 48, UIColors.with_alpha(UIColors.TEXT_DIM, 0.4), 1.5)

	# 灰色名称
	var alpha := 0.5 if _is_hovered else 0.3
	var short_name := node_name.left(4) if node_name.length() > 4 else node_name
	draw_string(font, center + Vector2(-16, 5), short_name,
		HORIZONTAL_ALIGNMENT_CENTER, 32, 10, UIColors.with_alpha(UIColors.TEXT_DIM, alpha))

	# 悬停时显示费用
	if _is_hovered:
		draw_string(font, center + Vector2(-20, radius + 16),
			"%d ✦" % node_cost, HORIZONTAL_ALIGNMENT_CENTER, 40, 10,
			UIColors.with_alpha(UIColors.DANGER, 0.7))

func _draw_unlockable(center: Vector2, radius: float, font: Font) -> void:
	# 脉动呼吸
	var breath := 0.85 + 0.15 * sin(_time * 2.5)

	# 辉光层
	for i in range(3):
		var r := radius * breath + i * 5.0
		var alpha := 0.12 - i * 0.03
		if _is_hovered:
			alpha *= 2.0
		draw_arc(center, r, 0, TAU, 48,
			UIColors.with_alpha(node_color, alpha), 2.0)

	# 实线边框
	draw_arc(center, radius, 0, TAU, 48,
		UIColors.with_alpha(node_color, 0.7), 2.0)

	# 半透明填充
	draw_circle(center, radius * 0.85,
		UIColors.with_alpha(node_color, 0.06))

	# 名称
	var short_name := node_name.left(4) if node_name.length() > 4 else node_name
	draw_string(font, center + Vector2(-16, 5), short_name,
		HORIZONTAL_ALIGNMENT_CENTER, 32, 10,
		UIColors.with_alpha(UIColors.TEXT_PRIMARY, 0.8))

	# 费用
	draw_string(font, center + Vector2(-20, radius + 16),
		"%d ✦" % node_cost, HORIZONTAL_ALIGNMENT_CENTER, 40, 10, FRAGMENT_COLOR)

	# 悬停粒子
	if _is_hovered:
		for i in range(4):
			var angle := _time * 3.0 + i * TAU / 4.0
			var dist := radius + 12.0 - fmod(_time * 18.0 + i * 5.0, 18.0)
			var pt := center + Vector2(cos(angle), sin(angle)) * dist
			draw_circle(pt, 2.0, UIColors.with_alpha(node_color, 0.4))

func _draw_unlocked(center: Vector2, radius: float, font: Font) -> void:
	var is_maxed := node_current_level >= node_max_level

	# 填充
	var fill_color: Color
	if is_maxed:
		fill_color = UIColors.with_alpha(UIColors.GOLD, 0.2)
	else:
		fill_color = UIColors.with_alpha(UIColors.CYAN, 0.15)
	draw_circle(center, radius, fill_color)

	# 边框
	var border := UIColors.with_alpha(UIColors.GOLD, 0.8) if is_maxed else UIColors.with_alpha(UIColors.CYAN, 0.8)
	draw_arc(center, radius, 0, TAU, 48, border, 2.5)

	# 辉光
	var glow_alpha := 0.08 + 0.04 * sin(_time * 1.5)
	if _is_hovered:
		glow_alpha *= 2.0
	draw_arc(center, radius + 4, 0, TAU, 48,
		UIColors.with_alpha(border, glow_alpha), 3.0)

	# 名称
	var short_name := node_name.left(4) if node_name.length() > 4 else node_name
	var text_col := UIColors.GOLD if is_maxed else UIColors.CYAN
	draw_string(font, center + Vector2(-16, 5), short_name,
		HORIZONTAL_ALIGNMENT_CENTER, 32, 10, text_col)

	# 等级
	if node_max_level > 1:
		var level_text := "MAX" if is_maxed else "Lv.%d/%d" % [node_current_level, node_max_level]
		var level_col := UIColors.with_alpha(UIColors.GOLD, 0.7) if is_maxed else UIColors.with_alpha(UIColors.CYAN, 0.7)
		draw_string(font, center + Vector2(-24, radius + 16),
			level_text, HORIZONTAL_ALIGNMENT_CENTER, 48, 9, level_col)

func _draw_unlock_anim(center: Vector2, radius: float) -> void:
	if _unlock_progress < 0.0:
		return

	var p := _unlock_progress

	# 冲击波
	var ring_r := radius * (1.0 + p * 3.0)
	draw_arc(center, ring_r, 0, TAU, 48,
		UIColors.with_alpha(UIColors.CYAN, (1.0 - p) * 0.6), 2.5)

	# 放射线
	for i in range(8):
		var angle := float(i) * TAU / 8.0 + p * 0.5
		var inner := center + Vector2(cos(angle), sin(angle)) * radius * 0.5
		var outer := center + Vector2(cos(angle), sin(angle)) * radius * (1.0 + p * 2.0)
		draw_line(inner, outer,
			UIColors.with_alpha(UIColors.GOLD, (1.0 - p) * 0.5), 1.5)

# ============================================================
# 输入处理
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var center := size / 2.0 - Vector2(0, 12)
		var was_hovered := _is_hovered
		_is_hovered = center.distance_to(event.position) <= node_radius * 1.2
		if _is_hovered and not was_hovered:
			node_hovered.emit(node_id)
		elif not _is_hovered and was_hovered:
			node_unhovered.emit(node_id)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var center := size / 2.0 - Vector2(0, 12)
			if center.distance_to(event.position) <= node_radius * 1.2:
				node_clicked.emit(node_id)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		if _is_hovered:
			_is_hovered = false
			node_unhovered.emit(node_id)
