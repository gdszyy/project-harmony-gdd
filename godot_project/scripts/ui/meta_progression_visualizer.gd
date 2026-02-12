## meta_progression_visualizer.gd
## v3.0 局外成长可视化系统 (Meta Progression Visualizer)
##
## 核心功能：
##   1. 技能树可视化 — 将和谐殿堂的四大模块以交互式技能树展示
##   2. 解锁动画 — 新解锁节点的粒子/光效动画
##   3. 局内效果标注 — 在局内UI上标注哪些能力来自局外成长
##   4. 乐理突破日志 — 记录并展示已获得的乐理突破事件
##   5. 共鸣碎片进度 — 可视化共鸣碎片的收集与消耗
##
## 本脚本同时作为 hall_of_harmony.gd 的增强层，
## 以及局内 circle_of_fifths_upgrade_v3.gd 的局外标注数据源。
##
extends Control

# ============================================================
# 信号
# ============================================================
signal node_unlocked(node_id: String, category: String)
signal breakthrough_logged(event_id: String)
signal start_game_pressed()   ## v3.0: 兼容 game_over.gd 的 HallOfHarmony 接口
signal back_pressed()           ## v3.0: 兼容 game_over.gd 的 HallOfHarmony 接口

# ============================================================
# 常量 — 技能树布局
# ============================================================
const TREE_NODE_SIZE := Vector2(60, 60)
const TREE_NODE_MARGIN := 20.0
const TREE_LINK_WIDTH := 2.0
const TREE_COLUMNS := 4  # 四大模块并排

## 模块定义
const MODULE_NAMES := ["乐器调优", "乐理研习", "调式风格", "声学降噪"]
const MODULE_ICONS := ["♪", "♫", "♬", "♩"]
const MODULE_COLORS := [
	Color(0.2, 0.8, 1.0),   # 蓝 — 乐器调优
	Color(0.8, 0.4, 1.0),   # 紫 — 乐理研习
	Color(1.0, 0.6, 0.2),   # 橙 — 调式风格
	Color(0.3, 1.0, 0.5),   # 绿 — 声学降噪
]

## 颜色
const BG_COLOR := Color(0.03, 0.025, 0.06, 0.95)
const NODE_LOCKED := Color(0.15, 0.12, 0.22, 0.6)
const NODE_UNLOCKED := Color(0.1, 0.08, 0.18, 0.9)
const NODE_MAXED := Color(0.08, 0.06, 0.14, 0.95)
const LINK_LOCKED := Color(0.2, 0.18, 0.3, 0.3)
const LINK_UNLOCKED := Color(0.5, 0.4, 0.7, 0.6)
const GLOW_COLOR := Color(1.0, 0.9, 0.4, 0.3)
const FRAGMENT_COLOR := Color(0.6, 0.4, 1.0)

# ============================================================
# 技能树数据结构
# ============================================================

## 技能树节点定义
## 每个模块包含多层节点，层级越深越强力
const SKILL_TREE := {
	# A. 乐器调优 — 基础属性升级
	"tuning": {
		"module_index": 0,
		"nodes": [
			# 第1层 — 基础
			{ "id": "tune_dmg_1", "name": "伤害调优 I", "desc": "基础伤害 +5%", "cost": 10, "layer": 0,
			  "effect": { "type": "stat_mult", "stat": "dmg", "value": 0.05 }, "prereqs": [] },
			{ "id": "tune_spd_1", "name": "速度调优 I", "desc": "弹体速度 +5%", "cost": 10, "layer": 0,
			  "effect": { "type": "stat_mult", "stat": "spd", "value": 0.05 }, "prereqs": [] },
			{ "id": "tune_dur_1", "name": "持续调优 I", "desc": "弹体持续时间 +10%", "cost": 10, "layer": 0,
			  "effect": { "type": "stat_mult", "stat": "dur", "value": 0.10 }, "prereqs": [] },
			# 第2层 — 进阶
			{ "id": "tune_dmg_2", "name": "伤害调优 II", "desc": "基础伤害 +10%", "cost": 25, "layer": 1,
			  "effect": { "type": "stat_mult", "stat": "dmg", "value": 0.10 }, "prereqs": ["tune_dmg_1"] },
			{ "id": "tune_spd_2", "name": "速度调优 II", "desc": "弹体速度 +10%", "cost": 25, "layer": 1,
			  "effect": { "type": "stat_mult", "stat": "spd", "value": 0.10 }, "prereqs": ["tune_spd_1"] },
			# 第3层 — 精通
			{ "id": "tune_master", "name": "调优大师", "desc": "所有基础属性 +8%", "cost": 60, "layer": 2,
			  "effect": { "type": "stat_mult", "stat": "all", "value": 0.08 }, "prereqs": ["tune_dmg_2", "tune_spd_2"] },
		]
	},
	# B. 乐理研习 — 被动技能解锁
	"theory": {
		"module_index": 1,
		"nodes": [
			{ "id": "theory_seventh", "name": "七和弦入门", "desc": "局内升级池中出现七和弦相关升级", "cost": 15, "layer": 0,
			  "effect": { "type": "unlock_pool", "pool": "seventh_chords" }, "prereqs": [] },
			{ "id": "theory_progression", "name": "和声进行基础", "desc": "解锁和弦功能转换系统", "cost": 20, "layer": 0,
			  "effect": { "type": "unlock_mechanic", "mechanic": "chord_progression" }, "prereqs": [] },
			{ "id": "theory_extended", "name": "扩展和弦理论", "desc": "局内可出现扩展和弦解锁突破事件", "cost": 40, "layer": 1,
			  "effect": { "type": "unlock_pool", "pool": "extended_chords" }, "prereqs": ["theory_seventh"] },
			{ "id": "theory_modulation", "name": "转调理论", "desc": "解锁调式交替突破事件", "cost": 50, "layer": 1,
			  "effect": { "type": "unlock_mechanic", "mechanic": "modulation" }, "prereqs": ["theory_progression"] },
			{ "id": "theory_master", "name": "乐理大师", "desc": "所有乐理效果 +25%", "cost": 80, "layer": 2,
			  "effect": { "type": "theory_mastery", "value": 0.25 }, "prereqs": ["theory_extended", "theory_modulation"] },
		]
	},
	# C. 调式风格 — 调式/职业选择
	"modes": {
		"module_index": 2,
		"nodes": [
			{ "id": "mode_ionian", "name": "伊奥尼亚", "desc": "均衡调式，无特殊加成", "cost": 0, "layer": 0,
			  "effect": { "type": "mode_unlock", "mode": "ionian" }, "prereqs": [] },
			{ "id": "mode_dorian", "name": "多利亚", "desc": "防御+15%，伤害-5%", "cost": 20, "layer": 0,
			  "effect": { "type": "mode_unlock", "mode": "dorian" }, "prereqs": [] },
			{ "id": "mode_mixolydian", "name": "混合利底亚", "desc": "伤害+10%，BPM+5", "cost": 20, "layer": 0,
			  "effect": { "type": "mode_unlock", "mode": "mixolydian" }, "prereqs": [] },
			{ "id": "mode_aeolian", "name": "艾奥利亚", "desc": "生命恢复+20%，弹体速度-10%", "cost": 25, "layer": 1,
			  "effect": { "type": "mode_unlock", "mode": "aeolian" }, "prereqs": ["mode_dorian"] },
			{ "id": "mode_locrian", "name": "洛克里亚", "desc": "极端模式：伤害+30%，生命-30%", "cost": 50, "layer": 2,
			  "effect": { "type": "mode_unlock", "mode": "locrian" }, "prereqs": ["mode_aeolian"] },
		]
	},
	# D. 声学降噪 — 疲劳抗性
	"denoise": {
		"module_index": 3,
		"nodes": [
			{ "id": "denoise_mono_1", "name": "单调耐受 I", "desc": "单调疲劳累积 -10%", "cost": 10, "layer": 0,
			  "effect": { "type": "fatigue_resist", "fatigue": "monotony", "value": 0.10 }, "prereqs": [] },
			{ "id": "denoise_dissonance_1", "name": "不和谐耐受 I", "desc": "不和谐衰减 +0.5/秒", "cost": 10, "layer": 0,
			  "effect": { "type": "fatigue_resist", "fatigue": "dissonance", "value": 0.5 }, "prereqs": [] },
			{ "id": "denoise_density_1", "name": "密度耐受 I", "desc": "密度疲劳累积 -10%", "cost": 10, "layer": 0,
			  "effect": { "type": "fatigue_resist", "fatigue": "density", "value": 0.10 }, "prereqs": [] },
			{ "id": "denoise_mono_2", "name": "单调耐受 II", "desc": "单调疲劳累积 -20%", "cost": 30, "layer": 1,
			  "effect": { "type": "fatigue_resist", "fatigue": "monotony", "value": 0.20 }, "prereqs": ["denoise_mono_1"] },
			{ "id": "denoise_master", "name": "降噪大师", "desc": "所有疲劳累积 -15%", "cost": 70, "layer": 2,
			  "effect": { "type": "fatigue_resist", "fatigue": "all", "value": 0.15 }, "prereqs": ["denoise_mono_2", "denoise_dissonance_1", "denoise_density_1"] },
		]
	},
}

# ============================================================
# 乐理突破日志
# ============================================================
var _breakthrough_log: Array[Dictionary] = []

# ============================================================
# 状态
# ============================================================
var _meta: Node = null
var _unlocked_nodes: Dictionary = {}  # node_id → true
var _node_positions: Dictionary = {}  # node_id → Vector2
var _node_rects: Dictionary = {}      # node_id → Rect2
var _hover_node: String = ""
var _selected_module: int = 0
var _fragments: int = 0
var _is_open: bool = false

## 动画
var _unlock_animations: Array[Dictionary] = []  # { "node_id": String, "progress": float, "particles": Array }

## v3.0: 导航按钮区域
var _back_button_rect: Rect2 = Rect2()
var _start_button_rect: Rect2 = Rect2()

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	visible = false
	_meta = get_node_or_null("/root/MetaProgressionManager")
	_load_unlocked_state()

func _process(delta: float) -> void:
	if not _is_open:
		return

	# 更新解锁动画
	var finished: Array[int] = []
	for i in range(_unlock_animations.size()):
		_unlock_animations[i]["progress"] += delta * 2.0
		if _unlock_animations[i]["progress"] >= 1.0:
			finished.append(i)
	for i in range(finished.size() - 1, -1, -1):
		_unlock_animations.remove_at(finished[i])

	queue_redraw()

# ============================================================
# 数据加载
# ============================================================

func _load_unlocked_state() -> void:
	_unlocked_nodes.clear()
	if _meta and _meta.has_method("get_unlocked_upgrades"):
		var unlocked: Array = _meta.get_unlocked_upgrades()
		for uid in unlocked:
			_unlocked_nodes[uid] = true

	# 加载共鸣碎片
	if _meta and _meta.has_method("get_resonance_fragments"):
		_fragments = _meta.get_resonance_fragments()

func _load_breakthrough_log() -> void:
	_breakthrough_log.clear()
	if _meta and _meta.has_method("get_breakthrough_log"):
		_breakthrough_log = _meta.get_breakthrough_log()

# ============================================================
# 显示/隐藏
# ============================================================

func open_panel() -> void:
	_is_open = true
	visible = true
	_load_unlocked_state()
	_load_breakthrough_log()
	_calculate_node_positions()
	queue_redraw()

func close_panel() -> void:
	_is_open = false
	visible = false
	back_pressed.emit()  # v3.0: 通知父场景（兼容 HallOfHarmony 接口）

# ============================================================
# 节点位置计算
# ============================================================

func _calculate_node_positions() -> void:
	_node_positions.clear()
	_node_rects.clear()
	var vp_size := get_viewport_rect().size
	var module_width := (vp_size.x - 80.0) / float(TREE_COLUMNS)
	var base_y := 120.0

	for module_key in SKILL_TREE.keys():
		var module: Dictionary = SKILL_TREE[module_key]
		var col: int = module["module_index"]
		var module_x := 40.0 + col * module_width + module_width / 2.0

		var nodes: Array = module["nodes"]
		# 按层分组
		var layers: Dictionary = {}
		for node in nodes:
			var layer: int = node["layer"]
			if not layers.has(layer):
				layers[layer] = []
			layers[layer].append(node)

		for layer in layers.keys():
			var layer_nodes: Array = layers[layer]
			var layer_y := base_y + layer * (TREE_NODE_SIZE.y + TREE_NODE_MARGIN + 30.0)
			var layer_width := layer_nodes.size() * (TREE_NODE_SIZE.x + TREE_NODE_MARGIN) - TREE_NODE_MARGIN
			var start_x := module_x - layer_width / 2.0

			for i in range(layer_nodes.size()):
				var node: Dictionary = layer_nodes[i]
				var x := start_x + i * (TREE_NODE_SIZE.x + TREE_NODE_MARGIN)
				var pos := Vector2(x, layer_y)
				_node_positions[node["id"]] = pos
				_node_rects[node["id"]] = Rect2(pos, TREE_NODE_SIZE)

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if not _is_open:
		return

	var font := ThemeDB.fallback_font
	var vp_size := get_viewport_rect().size

	# 背景
	draw_rect(Rect2(Vector2.ZERO, vp_size), BG_COLOR)

	# 标题
	draw_string(font, Vector2(vp_size.x / 2.0 - 60, 35),
		"HALL OF HARMONY", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(0.8, 0.75, 0.95))

	# 共鸣碎片
	draw_string(font, Vector2(vp_size.x - 200, 35),
		"Resonance Fragments: %d" % _fragments, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, FRAGMENT_COLOR)

	# 模块标签
	_draw_module_headers(font)

	# 连线
	_draw_links(font)

	# 节点
	_draw_nodes(font)

	# 解锁动画
	_draw_unlock_animations()

	# 突破日志
	_draw_breakthrough_log(font)

	# 悬停信息
	_draw_hover_info(font)

	# v3.0: 导航按钮
	_draw_nav_buttons(font, vp_size)

func _draw_nav_buttons(font: Font, vp_size: Vector2) -> void:
	# 返回按钮
	var back_rect := Rect2(Vector2(30, vp_size.y - 50), Vector2(100, 35))
	draw_rect(back_rect, Color(0.15, 0.12, 0.22, 0.9))
	draw_rect(back_rect, Color(0.4, 0.35, 0.55, 0.6), false, 1.0)
	draw_string(font, back_rect.position + Vector2(20, 23),
		"← 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.65, 0.85))
	_back_button_rect = back_rect

	# 开始渔戏按钮
	var start_rect := Rect2(Vector2(vp_size.x - 180, vp_size.y - 50), Vector2(150, 35))
	draw_rect(start_rect, Color(0.1, 0.2, 0.15, 0.9))
	draw_rect(start_rect, Color(0.3, 0.8, 0.5, 0.6), false, 1.0)
	draw_string(font, start_rect.position + Vector2(20, 23),
		"开始演奏 ▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.3, 0.9, 0.5))
	_start_button_rect = start_rect

func _draw_module_headers(font: Font) -> void:
	var vp_size := get_viewport_rect().size
	var module_width := (vp_size.x - 80.0) / float(TREE_COLUMNS)

	for i in range(TREE_COLUMNS):
		var x := 40.0 + i * module_width + module_width / 2.0
		var color := MODULE_COLORS[i]
		draw_string(font, Vector2(x - 30, 75), MODULE_ICONS[i],
			HORIZONTAL_ALIGNMENT_CENTER, -1, 16, color)
		draw_string(font, Vector2(x - 30, 95), MODULE_NAMES[i],
			HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.6, 0.55, 0.75, 0.8))

func _draw_links(font: Font) -> void:
	for module_key in SKILL_TREE.keys():
		var module: Dictionary = SKILL_TREE[module_key]
		var nodes: Array = module["nodes"]
		for node in nodes:
			var node_id: String = node["id"]
			var prereqs: Array = node.get("prereqs", [])
			if not _node_positions.has(node_id):
				continue
			var to_pos: Vector2 = _node_positions[node_id] + TREE_NODE_SIZE / 2.0
			for prereq_id in prereqs:
				if not _node_positions.has(prereq_id):
					continue
				var from_pos: Vector2 = _node_positions[prereq_id] + TREE_NODE_SIZE / 2.0
				var is_unlocked := _unlocked_nodes.has(node_id)
				var link_color := LINK_UNLOCKED if is_unlocked else LINK_LOCKED
				draw_line(from_pos, to_pos, link_color, TREE_LINK_WIDTH)

func _draw_nodes(font: Font) -> void:
	for module_key in SKILL_TREE.keys():
		var module: Dictionary = SKILL_TREE[module_key]
		var module_color: Color = MODULE_COLORS[module["module_index"]]
		var nodes: Array = module["nodes"]

		for node in nodes:
			var node_id: String = node["id"]
			if not _node_rects.has(node_id):
				continue
			var rect: Rect2 = _node_rects[node_id]
			var is_unlocked := _unlocked_nodes.has(node_id)
			var is_available := _can_unlock(node)
			var is_hover := (_hover_node == node_id)

			# 背景
			var bg := NODE_LOCKED
			if is_unlocked:
				bg = NODE_UNLOCKED
			if is_hover and (is_available or is_unlocked):
				bg = Color(0.15, 0.12, 0.25, 0.9)
			draw_rect(rect, bg)

			# 边框
			var border := Color(0.3, 0.25, 0.4, 0.4)
			if is_unlocked:
				border = module_color
				border.a = 0.7
			elif is_available:
				border = module_color
				border.a = 0.4
			draw_rect(rect, border, false, 1.5)

			# 已解锁发光
			if is_unlocked:
				var glow := module_color
				glow.a = 0.15
				draw_rect(rect.grow(3), glow)

			# 图标/名称
			var text_color := module_color if is_unlocked else Color(0.4, 0.38, 0.5, 0.6)
			var short_name: String = node.get("name", "?")
			if short_name.length() > 6:
				short_name = short_name.left(6)
			draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 18, rect.size.y / 2.0 + 4),
				short_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, text_color)

			# 费用
			if not is_unlocked:
				var cost: int = node.get("cost", 0)
				var cost_color := FRAGMENT_COLOR if _fragments >= cost else Color(0.5, 0.3, 0.3, 0.6)
				draw_string(font, rect.position + Vector2(rect.size.x / 2.0 - 8, rect.size.y + 12),
					"%d" % cost, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, cost_color)

func _draw_unlock_animations() -> void:
	for anim in _unlock_animations:
		var node_id: String = anim["node_id"]
		if not _node_rects.has(node_id):
			continue
		var rect: Rect2 = _node_rects[node_id]
		var progress: float = anim["progress"]
		var center := rect.position + rect.size / 2.0

		# 扩散光环
		var ring_radius := TREE_NODE_SIZE.x * (0.5 + progress * 1.5)
		var ring_alpha := (1.0 - progress) * 0.6
		draw_arc(center, ring_radius, 0, TAU, 32, Color(1.0, 0.9, 0.4, ring_alpha), 2.0)

		# 粒子效果（简化为放射线）
		for j in range(8):
			var angle := float(j) * TAU / 8.0
			var line_start := center + Vector2(cos(angle), sin(angle)) * TREE_NODE_SIZE.x * 0.3
			var line_end := center + Vector2(cos(angle), sin(angle)) * TREE_NODE_SIZE.x * (0.5 + progress)
			var line_alpha := (1.0 - progress) * 0.5
			draw_line(line_start, line_end, Color(1.0, 0.9, 0.4, line_alpha), 1.5)

func _draw_breakthrough_log(font: Font) -> void:
	if _breakthrough_log.is_empty():
		return

	var vp_size := get_viewport_rect().size
	var log_y := vp_size.y - 120.0

	draw_string(font, Vector2(40, log_y),
		"THEORY BREAKTHROUGHS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.9, 0.4, 0.8))

	for i in range(min(3, _breakthrough_log.size())):
		var entry := _breakthrough_log[i]
		var y := log_y + 20 + i * 22
		draw_string(font, Vector2(50, y),
			"★ %s" % entry.get("name", "???"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(1.0, 0.95, 0.7, 0.7))
		draw_string(font, Vector2(250, y),
			entry.get("desc", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.6, 0.55, 0.5, 0.6))

func _draw_hover_info(font: Font) -> void:
	if _hover_node.is_empty():
		return

	var node_data := _find_node_data(_hover_node)
	if node_data.is_empty():
		return

	var vp_size := get_viewport_rect().size
	var info_rect := Rect2(Vector2(vp_size.x / 2.0 - 150, vp_size.y - 70), Vector2(300, 55))
	draw_rect(info_rect, Color(0.06, 0.05, 0.12, 0.95))
	draw_rect(info_rect, Color(0.3, 0.25, 0.4, 0.5), false, 1.0)

	draw_string(font, info_rect.position + Vector2(10, 20),
		node_data.get("name", "?"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.85, 1.0))
	draw_string(font, info_rect.position + Vector2(10, 40),
		node_data.get("desc", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.55, 0.75, 0.8))

	var cost: int = node_data.get("cost", 0)
	var is_unlocked := _unlocked_nodes.has(_hover_node)
	var status := "UNLOCKED" if is_unlocked else "Cost: %d" % cost
	var status_color := Color(0.3, 0.8, 0.4) if is_unlocked else FRAGMENT_COLOR
	draw_string(font, info_rect.position + Vector2(info_rect.size.x - 80, 20),
		status, HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, status_color)

# ============================================================
# 输入处理
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event is InputEventMouseMotion:
		_hover_node = ""
		for node_id in _node_rects.keys():
			if _node_rects[node_id].has_point(event.position):
				_hover_node = node_id
				break

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var pos := event.position
			# v3.0: 检查导航按钮
			if _back_button_rect.has_point(pos):
				close_panel()
				return
			if _start_button_rect.has_point(pos):
				start_game_pressed.emit()
				return
			if not _hover_node.is_empty():
				_try_unlock(_hover_node)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			close_panel()

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			close_panel()
		elif event.keycode == KEY_ENTER:
			start_game_pressed.emit()  # v3.0: Enter 键开始游戏

# ============================================================
# 解锁逻辑
# ============================================================

func _can_unlock(node: Dictionary) -> bool:
	var node_id: String = node["id"]
	if _unlocked_nodes.has(node_id):
		return false
	var cost: int = node.get("cost", 0)
	if _fragments < cost:
		return false
	var prereqs: Array = node.get("prereqs", [])
	for prereq_id in prereqs:
		if not _unlocked_nodes.has(prereq_id):
			return false
	return true

func _try_unlock(node_id: String) -> void:
	var node_data := _find_node_data(node_id)
	if node_data.is_empty():
		return
	if not _can_unlock(node_data):
		return

	var cost: int = node_data.get("cost", 0)
	_fragments -= cost
	_unlocked_nodes[node_id] = true

	# 同步到 MetaProgressionManager
	if _meta and _meta.has_method("unlock_upgrade"):
		_meta.unlock_upgrade(node_id, cost)

	# 播放解锁动画
	_unlock_animations.append({
		"node_id": node_id,
		"progress": 0.0,
	})

	# 找到模块分类
	var category := _find_node_category(node_id)
	node_unlocked.emit(node_id, category)

# ============================================================
# 局内标注接口 — 供 circle_of_fifths_upgrade_v3 调用
# ============================================================

func is_upgrade_meta_unlocked(upgrade_id: String) -> bool:
	## 检查某个局内升级是否由局外成长解锁
	## 用于在升级选项上显示金色标识
	for module_key in SKILL_TREE.keys():
		var module: Dictionary = SKILL_TREE[module_key]
		for node in module["nodes"]:
			var effect: Dictionary = node.get("effect", {})
			if effect.get("type", "") == "unlock_pool":
				# 检查该升级是否属于此解锁池
				if _unlocked_nodes.has(node["id"]):
					if _upgrade_belongs_to_pool(upgrade_id, effect.get("pool", "")):
						return true
	return false

func get_meta_bonus_for_stat(stat: String) -> float:
	## 获取局外成长对某个属性的总加成
	var total := 0.0
	for module_key in SKILL_TREE.keys():
		var module: Dictionary = SKILL_TREE[module_key]
		for node in module["nodes"]:
			if not _unlocked_nodes.has(node["id"]):
				continue
			var effect: Dictionary = node.get("effect", {})
			if effect.get("type", "") == "stat_mult":
				if effect.get("stat", "") == stat or effect.get("stat", "") == "all":
					total += effect.get("value", 0.0)
	return total

func get_fatigue_resistance(fatigue_type: String) -> float:
	## 获取局外成长对某种疲劳的抗性加成
	var total := 0.0
	for node in SKILL_TREE["denoise"]["nodes"]:
		if not _unlocked_nodes.has(node["id"]):
			continue
		var effect: Dictionary = node.get("effect", {})
		if effect.get("type", "") == "fatigue_resist":
			if effect.get("fatigue", "") == fatigue_type or effect.get("fatigue", "") == "all":
				total += effect.get("value", 0.0)
	return total

func get_unlocked_modes() -> Array[String]:
	## 获取已解锁的调式列表
	var modes: Array[String] = []
	for node in SKILL_TREE["modes"]["nodes"]:
		if _unlocked_nodes.has(node["id"]):
			var effect: Dictionary = node.get("effect", {})
			if effect.get("type", "") == "mode_unlock":
				modes.append(effect.get("mode", ""))
	return modes

# ============================================================
# 乐理突破日志
# ============================================================

func log_breakthrough(event: Dictionary) -> void:
	_breakthrough_log.append({
		"id": event.get("id", ""),
		"name": event.get("name", "???"),
		"desc": event.get("desc", ""),
		"timestamp": Time.get_unix_time_from_system(),
	})
	if _meta and _meta.has_method("save_breakthrough_log"):
		_meta.save_breakthrough_log(_breakthrough_log)
	breakthrough_logged.emit(event.get("id", ""))

# ============================================================
# 工具函数
# ============================================================

func _find_node_data(node_id: String) -> Dictionary:
	for module_key in SKILL_TREE.keys():
		var module: Dictionary = SKILL_TREE[module_key]
		for node in module["nodes"]:
			if node["id"] == node_id:
				return node
	return {}

func _find_node_category(node_id: String) -> String:
	for module_key in SKILL_TREE.keys():
		var module: Dictionary = SKILL_TREE[module_key]
		for node in module["nodes"]:
			if node["id"] == node_id:
				return module_key
	return ""

func _upgrade_belongs_to_pool(upgrade_id: String, pool: String) -> bool:
	match pool:
		"seventh_chords":
			return upgrade_id.contains("seventh") or upgrade_id.contains("chord")
		"extended_chords":
			return upgrade_id.contains("extended") or upgrade_id.contains("ninth") or upgrade_id.contains("eleventh")
	return false
