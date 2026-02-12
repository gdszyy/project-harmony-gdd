## DEPRECATED: This file has been archived and is no longer actively used.
## Signals defined here are not connected. Retained for reference only.
## circle_of_fifths_upgrade.gd
## 五度圈罗盘升级系统
## 用音乐理论驱动的罗盘界面替代传统三选一卡片
##
## 设计要点：
##   - 12刻度圆盘对应12个音级（C, G, D, A, E, B, F#, Db, Ab, Eb, Bb, F）
##   - 指针指向当前"音乐探索方向"，初始为C
##   - 三个升级选项浮现在指针所指及相邻五度/四度音级位置
##   - 选择后指针旋转到该音级，影响后续升级方向
##   - 顺时针（五度上行）→ 进攻性，逆时针（五度下行）→ 防御/资源
extends Control

# ============================================================
# 信号
# ============================================================
signal upgrade_chosen(upgrade: Dictionary)

# ============================================================
# 常量
# ============================================================
## 五度圈音级顺序（顺时针，从C开始）
const CIRCLE_KEYS := ["C", "G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F"]
## 五度圈音级数量
const CIRCLE_SIZE: int = 12

## 罗盘视觉参数
const COMPASS_RADIUS: float = 180.0
const COMPASS_INNER_RADIUS: float = 60.0
const KEY_LABEL_RADIUS: float = 200.0
const OPTION_CARD_RADIUS: float = 260.0
const OPTION_CARD_SIZE := Vector2(200, 110)
const POINTER_LENGTH: float = 140.0
const TICK_LENGTH: float = 15.0

## 颜色
const BG_OVERLAY_COLOR := Color(0.0, 0.0, 0.02, 0.75)
const COMPASS_BG_COLOR := Color(0.04, 0.03, 0.08, 0.9)
const COMPASS_RING_COLOR := Color(0.25, 0.2, 0.4, 0.6)
const COMPASS_INNER_COLOR := Color(0.06, 0.05, 0.12, 0.95)
const POINTER_COLOR := Color(1.0, 0.9, 0.4, 0.9)
const TICK_COLOR := Color(0.3, 0.25, 0.45, 0.5)
const TICK_ACTIVE_COLOR := Color(0.8, 0.7, 1.0, 0.9)
const KEY_LABEL_COLOR := Color(0.5, 0.45, 0.65, 0.7)
const KEY_LABEL_ACTIVE := Color(1.0, 0.95, 0.8, 1.0)
const TITLE_COLOR := Color(0.8, 0.75, 0.95, 0.9)

## 方向倾向颜色
const DIRECTION_COLORS := {
	"clockwise": Color(1.0, 0.4, 0.2, 0.9),     # 进攻性（顺时针/五度上行）
	"current": Color(0.2, 0.8, 1.0, 0.9),         # 核心强化（当前调性）
	"counter_clockwise": Color(0.3, 1.0, 0.5, 0.9),  # 防御/资源（逆时针/五度下行）
}

## 稀有度颜色
const RARITY_COLORS := {
	"common": Color(0.6, 0.6, 0.6),
	"rare": Color(0.2, 0.6, 1.0),
	"epic": Color(0.7, 0.3, 1.0),
	"legendary": Color(1.0, 0.8, 0.0),
}

# ============================================================
# 升级池（按方向分类）
# ============================================================

## 顺时针方向（进攻性）升级池
const CLOCKWISE_UPGRADES := [
	{
		"id": "dmg_boost_all", "category": "note_stat", "rarity": "common",
		"name": "音波增幅", "desc": "当前调性音符 DMG +0.5",
		"stat": "dmg", "value": 0.5,
	},
	{
		"id": "spd_boost_all", "category": "note_stat", "rarity": "common",
		"name": "音速强化", "desc": "当前调性音符 SPD +0.5",
		"stat": "spd", "value": 0.5,
	},
	{
		"id": "chord_power", "category": "chord_mastery", "rarity": "rare",
		"name": "和弦威力", "desc": "所有和弦伤害倍率 +0.1x",
		"type": "chord_power", "value": 0.1,
	},
	{
		"id": "bpm_boost", "category": "rhythm_mastery", "rarity": "rare",
		"name": "节奏加速", "desc": "基础 BPM +5",
		"type": "bpm_boost", "value": 5.0,
	},
	{
		"id": "perfect_beat_bonus", "category": "special", "rarity": "epic",
		"name": "完美节奏", "desc": "节拍对齐施法伤害 +25%",
		"type": "perfect_beat_bonus", "value": 0.25,
	},
	{
		"id": "chord_progression_boost", "category": "special", "rarity": "epic",
		"name": "和声进行", "desc": "和弦进行效果 +50%",
		"type": "chord_progression_boost", "value": 0.5,
	},
	{
		"id": "modifier_pierce", "category": "modifier_mastery", "rarity": "rare",
		"name": "穿透精通", "desc": "穿透效果增强，穿透数 +1",
		"type": "modifier_boost", "modifier": 0, "value": 1,
	},
	{
		"id": "modifier_split", "category": "modifier_mastery", "rarity": "rare",
		"name": "分裂精通", "desc": "分裂弹体数量 +1",
		"type": "modifier_boost", "modifier": 2, "value": 1,
	},
]

## 当前调性方向（核心强化）升级池
const CURRENT_UPGRADES := [
	{
		"id": "note_acquire_random", "category": "note_acquire", "rarity": "common",
		"name": "随机音符", "desc": "获得1个随机音符",
		"type": "random_note", "value": 1,
	},
	{
		"id": "note_acquire_specific", "category": "note_acquire", "rarity": "rare",
		"name": "指定音符", "desc": "获得1个当前调性根音",
		"type": "specific_note", "value": 1,
	},
	{
		"id": "all_boost", "category": "note_stat", "rarity": "epic",
		"name": "全维强化", "desc": "当前调性音符所有参数 +0.25",
		"stat": "all", "value": 0.25,
	},
	{
		"id": "timbre_switch_free", "category": "timbre_mastery", "rarity": "epic",
		"name": "音色自如", "desc": "音色切换不再产生疲劳",
		"type": "timbre_switch_free",
	},
	{
		"id": "extended_unlock", "category": "chord_mastery", "rarity": "legendary",
		"name": "扩展和弦解锁", "desc": "解锁5-6音扩展和弦",
		"type": "extended_unlock",
	},
	{
		"id": "multi_modifier", "category": "special", "rarity": "legendary",
		"name": "复合修饰", "desc": "允许同时应用2个黑键修饰符",
		"type": "multi_modifier",
	},
]

## 逆时针方向（防御/资源）升级池
const COUNTER_CLOCKWISE_UPGRADES := [
	{
		"id": "max_hp", "category": "survival", "rarity": "common",
		"name": "生命强化", "desc": "最大生命值 +25",
		"type": "max_hp", "value": 25.0,
	},
	{
		"id": "dodge", "category": "survival", "rarity": "rare",
		"name": "闪避本能", "desc": "基础闪避率 +3%",
		"type": "dodge", "value": 0.03,
	},
	{
		"id": "monotony_resist", "category": "fatigue_resist", "rarity": "rare",
		"name": "单调耐受", "desc": "单调值累积速率 -10%",
		"type": "monotony_resist", "value": 0.1,
	},
	{
		"id": "dissonance_decay", "category": "fatigue_resist", "rarity": "rare",
		"name": "不和谐消散", "desc": "不和谐值自然衰减 +0.5/秒",
		"type": "dissonance_decay", "value": 0.5,
	},
	{
		"id": "density_resist", "category": "fatigue_resist", "rarity": "rare",
		"name": "密度耐受", "desc": "密度疲劳累积速率 -10%",
		"type": "density_resist", "value": 0.1,
	},
	{
		"id": "note_acquire_double", "category": "note_acquire", "rarity": "rare",
		"name": "音符丰收", "desc": "获得2个随机音符",
		"type": "random_note", "value": 2,
	},
	{
		"id": "modifier_homing", "category": "modifier_mastery", "rarity": "rare",
		"name": "追踪精通", "desc": "追踪速度 +50%",
		"type": "modifier_boost", "modifier": 1, "value": 0.5,
	},
	{
		"id": "modifier_echo", "category": "modifier_mastery", "rarity": "rare",
		"name": "回响精通", "desc": "回响次数 +1",
		"type": "modifier_boost", "modifier": 3, "value": 1,
	},
]

# ============================================================
# 状态
# ============================================================
## 当前指针指向的音级索引（0=C, 1=G, 2=D, ...）
var _current_key_index: int = 0
## 当前三个升级选项
var _current_options: Array[Dictionary] = []
## 选项对应的方向标签
var _option_directions: Array[String] = []
## 面板是否可见
var _is_visible: bool = false
## 悬停的选项索引
var _hover_option: int = -1

## 动画状态
var _pointer_target_angle: float = 0.0
var _pointer_current_angle: float = 0.0
var _appear_progress: float = 0.0
var _option_appear_progress: Array[float] = [0.0, 0.0, 0.0]

## 罗盘中心位置
var _center: Vector2 = Vector2.ZERO

## 选项卡片矩形（用于点击检测）
var _option_rects: Array[Rect2] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	visible = false
	GameManager.game_state_changed.connect(_on_game_state_changed)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if not _is_visible:
		return

	# 指针旋转动画
	_pointer_current_angle = lerp(_pointer_current_angle, _pointer_target_angle, delta * 4.0)

	# 出现动画
	_appear_progress = min(1.0, _appear_progress + delta * 3.0)
	for i in range(3):
		if i < _option_appear_progress.size():
			_option_appear_progress[i] = min(1.0, _option_appear_progress[i] + delta * (2.0 + i * 0.5))

	queue_redraw()

# ============================================================
# 显示/隐藏
# ============================================================

func show_upgrade_options() -> void:
	_generate_options()
	_is_visible = true
	visible = true
	_appear_progress = 0.0
	_option_appear_progress = [0.0, 0.0, 0.0]
	_pointer_target_angle = _key_index_to_angle(_current_key_index)
	_pointer_current_angle = _pointer_target_angle
	queue_redraw()

func hide_panel() -> void:
	_is_visible = false
	visible = false

# ============================================================
# 选项生成
# ============================================================

func _generate_options() -> void:
	_current_options.clear()
	_option_directions.clear()

	# 三个方向：顺时针（五度上行）、当前、逆时针（五度下行）
	var clockwise_option := _pick_random_from_pool(CLOCKWISE_UPGRADES)
	var current_option := _pick_random_from_pool(CURRENT_UPGRADES)
	var counter_option := _pick_random_from_pool(COUNTER_CLOCKWISE_UPGRADES)

	# 为音符获取类升级注入当前调性信息
	_inject_key_context(clockwise_option)
	_inject_key_context(current_option)
	_inject_key_context(counter_option)

	# 顺序：逆时针、当前、顺时针
	_current_options.append(counter_option)
	_option_directions.append("counter_clockwise")

	_current_options.append(current_option)
	_option_directions.append("current")

	_current_options.append(clockwise_option)
	_option_directions.append("clockwise")

func _pick_random_from_pool(pool: Array) -> Dictionary:
	var available: Array = pool.duplicate(true)

	# 过滤已获得的一次性升级
	if GameManager.extended_chords_unlocked:
		available = available.filter(func(u): return u.get("id", "") != "extended_unlock")

	available.shuffle()
	if available.size() > 0:
		return available[0]
	return { "id": "empty", "name": "---", "desc": "No upgrade available", "rarity": "common" }

func _inject_key_context(upgrade: Dictionary) -> void:
	var current_key_name: String = CIRCLE_KEYS[_current_key_index]

	# 为音符属性升级指定目标音符
	if upgrade.get("category", "") == "note_stat":
		var target_note := _key_name_to_white_key(current_key_name)
		if target_note >= 0:
			upgrade["target_note"] = target_note
			upgrade["desc"] = upgrade.get("desc", "").replace("当前调性", current_key_name)

	# 为指定音符获取升级注入调性
	if upgrade.get("type", "") == "specific_note":
		var target_note := _key_name_to_white_key(current_key_name)
		if target_note >= 0:
			upgrade["target_note"] = target_note
			upgrade["desc"] = "获得1个 %s 音符" % current_key_name

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if not _is_visible:
		return

	_center = get_viewport_rect().size / 2.0
	var font := ThemeDB.fallback_font
	var scale_factor := _appear_progress

	# 背景遮罩
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BG_OVERLAY_COLOR)

	# 标题
	var title_alpha: float = clampf(_appear_progress * 2.0, 0.0, 1.0)
	var title_color := TITLE_COLOR
	title_color.a = title_alpha
	draw_string(font, Vector2(_center.x - 60, _center.y - COMPASS_RADIUS - 50),
		"LEVEL UP", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, title_color)

	var subtitle_color := Color(0.6, 0.55, 0.75, title_alpha * 0.7)
	draw_string(font, Vector2(_center.x - 100, _center.y - COMPASS_RADIUS - 28),
		"Choose your musical direction", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, subtitle_color)

	# 罗盘外环
	_draw_compass_ring(scale_factor)

	# 音级刻度和标签
	_draw_key_ticks(font, scale_factor)

	# 指针
	_draw_pointer(scale_factor)

	# 罗盘中心
	_draw_compass_center(font, scale_factor)

	# 升级选项卡片
	_draw_option_cards(font)

func _draw_compass_ring(scale: float) -> void:
	var radius := COMPASS_RADIUS * scale
	# 外环
	draw_arc(_center, radius, 0, TAU, 64, COMPASS_RING_COLOR, 2.0)
	# 内环
	draw_arc(_center, COMPASS_INNER_RADIUS * scale, 0, TAU, 32, COMPASS_RING_COLOR * 0.5, 1.0)

func _draw_key_ticks(font: Font, scale: float) -> void:
	for i in range(CIRCLE_SIZE):
		var angle := _key_index_to_angle(i)
		var outer_point := _center + Vector2(cos(angle), sin(angle)) * COMPASS_RADIUS * scale
		var inner_point := _center + Vector2(cos(angle), sin(angle)) * (COMPASS_RADIUS - TICK_LENGTH) * scale
		var label_point := _center + Vector2(cos(angle), sin(angle)) * KEY_LABEL_RADIUS * scale

		# 刻度线
		var is_active := (i == _current_key_index)
		var tick_color := TICK_ACTIVE_COLOR if is_active else TICK_COLOR
		var tick_width := 2.5 if is_active else 1.0
		draw_line(inner_point, outer_point, tick_color, tick_width)

		# 音级标签
		var label_color := KEY_LABEL_ACTIVE if is_active else KEY_LABEL_COLOR
		var label_size := 14 if is_active else 10
		draw_string(font, label_point + Vector2(-8, 5), CIRCLE_KEYS[i],
			HORIZONTAL_ALIGNMENT_CENTER, -1, label_size, label_color)

		# 活跃音级的发光圆点
		if is_active:
			draw_circle(outer_point, 4.0 * scale, POINTER_COLOR * 0.6)

func _draw_pointer(scale: float) -> void:
	var angle := _pointer_current_angle
	var tip := _center + Vector2(cos(angle), sin(angle)) * POINTER_LENGTH * scale
	var base_left := _center + Vector2(cos(angle + 2.8), sin(angle + 2.8)) * 8.0 * scale
	var base_right := _center + Vector2(cos(angle - 2.8), sin(angle - 2.8)) * 8.0 * scale

	# 指针三角形
	draw_colored_polygon(PackedVector2Array([tip, base_left, base_right]), POINTER_COLOR)

	# 指针发光线
	draw_line(_center, tip, POINTER_COLOR * 0.4, 1.5)

func _draw_compass_center(font: Font, scale: float) -> void:
	# 中心圆
	draw_circle(_center, COMPASS_INNER_RADIUS * scale * 0.8, COMPASS_INNER_COLOR)
	draw_arc(_center, COMPASS_INNER_RADIUS * scale * 0.8, 0, TAU, 32, COMPASS_RING_COLOR * 0.7, 1.5)

	# 当前音级
	var key_name: String = CIRCLE_KEYS[_current_key_index]
	draw_string(font, _center + Vector2(-10, -5), key_name,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 28, POINTER_COLOR)

	# 等级信息
	draw_string(font, _center + Vector2(-15, 18), "Lv.%d" % GameManager.player_level,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.6, 0.55, 0.75, 0.8))

func _draw_option_cards(font: Font) -> void:
	_option_rects.clear()

	if _current_options.size() < 3:
		return

	# 三个选项的角度位置
	var angles: Array[float] = []
	# 逆时针方向（左侧）
	angles.append(_key_index_to_angle((_current_key_index - 1 + CIRCLE_SIZE) % CIRCLE_SIZE))
	# 当前方向（正上方/指针方向）
	angles.append(_key_index_to_angle(_current_key_index))
	# 顺时针方向（右侧）
	angles.append(_key_index_to_angle((_current_key_index + 1) % CIRCLE_SIZE))

	for i in range(3):
		var progress := _option_appear_progress[i] if i < _option_appear_progress.size() else 0.0
		if progress < 0.01:
			_option_rects.append(Rect2())
			continue

		var angle := angles[i]
		var card_center := _center + Vector2(cos(angle), sin(angle)) * OPTION_CARD_RADIUS
		var card_pos := card_center - OPTION_CARD_SIZE / 2.0
		var card_rect := Rect2(card_pos, OPTION_CARD_SIZE)
		_option_rects.append(card_rect)

		var option := _current_options[i]
		var direction: String = _option_directions[i]
		var is_hover := (_hover_option == i)

		# 卡片缩放动画
		var card_scale := progress
		var scaled_size := OPTION_CARD_SIZE * card_scale
		var scaled_pos := card_center - scaled_size / 2.0
		var scaled_rect := Rect2(scaled_pos, scaled_size)

		_draw_option_card(scaled_rect, option, direction, is_hover, font, progress)

func _draw_option_card(rect: Rect2, option: Dictionary, direction: String,
		is_hover: bool, font: Font, alpha: float) -> void:
	var dir_color: Color = DIRECTION_COLORS.get(direction, Color.WHITE)
	var rarity: String = option.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.GRAY)

	# 卡片背景
	var bg_color := Color(0.06, 0.05, 0.12, 0.92 * alpha)
	if is_hover:
		bg_color = Color(0.1, 0.08, 0.18, 0.95 * alpha)
	draw_rect(rect, bg_color)

	# 方向色边框
	var border_color := dir_color
	border_color.a = (0.8 if is_hover else 0.5) * alpha
	draw_rect(rect, border_color, false, 2.0 if is_hover else 1.5)

	# 方向标签
	var dir_label := ""
	match direction:
		"clockwise": dir_label = "ATTACK"
		"current": dir_label = "CORE"
		"counter_clockwise": dir_label = "DEFENSE"
	var dir_label_color := dir_color
	dir_label_color.a = 0.8 * alpha
	draw_string(font, rect.position + Vector2(8, 16), dir_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, dir_label_color)

	# 稀有度标签
	var rarity_label_color := rarity_color
	rarity_label_color.a = 0.7 * alpha
	draw_string(font, rect.position + Vector2(rect.size.x - 60, 16), "[%s]" % rarity.to_upper(),
		HORIZONTAL_ALIGNMENT_RIGHT, -1, 8, rarity_label_color)

	# 升级名称
	var name_color := Color.WHITE
	name_color.a = alpha
	draw_string(font, rect.position + Vector2(8, 40), option.get("name", "???"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, name_color)

	# 描述
	var desc_color := Color(0.7, 0.65, 0.8)
	desc_color.a = 0.8 * alpha
	draw_string(font, rect.position + Vector2(8, 62), option.get("desc", ""),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, desc_color)

	# 底部方向指示条
	var bar_rect := Rect2(
		Vector2(rect.position.x, rect.position.y + rect.size.y - 3),
		Vector2(rect.size.x, 3)
	)
	var bar_color := dir_color
	bar_color.a = 0.6 * alpha
	draw_rect(bar_rect, bar_color)

# ============================================================
# 输入处理
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if not _is_visible:
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_click(event.position)

func _handle_mouse_motion(pos: Vector2) -> void:
	_hover_option = -1
	for i in range(_option_rects.size()):
		if _option_rects[i].has_point(pos):
			_hover_option = i
			break

func _handle_click(pos: Vector2) -> void:
	for i in range(_option_rects.size()):
		if _option_rects[i].has_point(pos):
			_select_option(i)
			return

# ============================================================
# 选择处理
# ============================================================

func _select_option(option_index: int) -> void:
	if option_index < 0 or option_index >= _current_options.size():
		return

	var option := _current_options[option_index]
	var direction: String = _option_directions[option_index]

	# 更新指针方向
	match direction:
		"clockwise":
			_current_key_index = (_current_key_index + 1) % CIRCLE_SIZE
		"counter_clockwise":
			_current_key_index = (_current_key_index - 1 + CIRCLE_SIZE) % CIRCLE_SIZE
		"current":
			pass  # 保持当前位置

	_pointer_target_angle = _key_index_to_angle(_current_key_index)

	# 处理音符获取类升级
	_process_note_acquisition(option)

	# 应用升级到 GameManager
	GameManager.apply_upgrade(option)

	upgrade_chosen.emit(option)
	hide_panel()
	GameManager.resume_game()

## 处理音符获取类升级
func _process_note_acquisition(upgrade: Dictionary) -> void:
	var upgrade_type: String = upgrade.get("type", "")

	if upgrade_type == "random_note":
		var amount: int = int(upgrade.get("value", 1))
		for i in range(amount):
			NoteInventory.add_random_note(1, "level_up")

	elif upgrade_type == "specific_note":
		var target_note: int = upgrade.get("target_note", -1)
		if target_note >= 0:
			NoteInventory.add_specific_note(target_note, 1, "level_up")
		else:
			NoteInventory.add_random_note(1, "level_up")

# ============================================================
# 工具函数
# ============================================================

## 音级索引 → 角度（弧度，12点钟方向为起始，顺时针）
func _key_index_to_angle(index: int) -> float:
	# 12点钟方向 = -PI/2，每个刻度 = TAU/12
	return -PI / 2.0 + float(index) * TAU / float(CIRCLE_SIZE)

## 音级名称 → WhiteKey 枚举值
func _key_name_to_white_key(key_name: String) -> int:
	match key_name:
		"C": return 0
		"D": return 1
		"E": return 2
		"F": return 3
		"G": return 4
		"A": return 5
		"B": return 6
	return -1  # 非白键（如 F#, Db 等）

# ============================================================
# 信号回调
# ============================================================

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.UPGRADE_SELECT:
		show_upgrade_options()
	elif _is_visible:
		hide_panel()
