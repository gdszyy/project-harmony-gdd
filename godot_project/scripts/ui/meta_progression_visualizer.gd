## meta_progression_visualizer.gd — v5.0 技能树可视化系统
## "星图中的交响诗" — 四大模块技能树可视化
##
## 设计文档: Docs/UI_Design_Module5_HallOfHarmony.md §3-4
## 每个模块有独特的布局隐喻:
##   A. 乐器调优 → 星象调音台（垂直推杆）
##   B. 乐理研习 → 知识的螺旋星云（中心辐射）
##   C. 调式风格 → 晶格化职业星座（星座图）
##   D. 声学降噪 → 谐振防御场（同心环）
##
## 节点三态: 未解锁(灰暗虚线) / 可解锁(脉动辉光) / 已解锁(发光填充)
## 使用 _draw() 绘制技能树连线与节点
extends Control

# ============================================================
# 信号
# ============================================================
signal node_unlocked(node_id: String, category: String)
signal back_pressed()
signal start_game_pressed()

# ============================================================
# 颜色方案
# ============================================================
const BG_COLOR := Color(0.03, 0.02, 0.06, 0.97)
const ACCENT := Color("#9D6FFF")
const GOLD := Color("#FFD700")
const CYAN := Color("#00E5FF")
const TEXT_COLOR := Color("#EAE6FF")
const DIM_TEXT := Color("#A098C8")
const SUCCESS := Color("#4DFF80")
const DANGER := Color("#FF4D4D")
const FRAGMENT_COLOR := Color(0.6, 0.4, 1.0)

## 节点状态颜色
const NODE_LOCKED_BG := Color(0.1, 0.08, 0.16, 0.4)
const NODE_LOCKED_BORDER := Color(0.3, 0.25, 0.4, 0.3)
const NODE_UNLOCKABLE_BORDER := Color(0.6, 0.4, 1.0, 0.7)
const NODE_UNLOCKED_BG := Color(0.0, 0.9, 1.0, 0.15)
const NODE_UNLOCKED_BORDER := Color(0.0, 0.9, 1.0, 0.8)

## 连线颜色
const LINK_LOCKED := Color(0.2, 0.18, 0.3, 0.2)
const LINK_ACTIVE := Color(0.6, 0.4, 1.0, 0.5)
const LINK_UNLOCKED := Color(0.0, 0.9, 1.0, 0.4)

## 模块主题色
const MODULE_COLORS := {
	"instrument": Color(0.2, 0.8, 1.0),
	"theory": Color(0.8, 0.4, 1.0),
	"modes": Color(1.0, 0.6, 0.2),
	"denoise": Color(0.3, 1.0, 0.5),
}

const MODULE_NAMES := {
	"instrument": "乐器调优 — 星象调音台",
	"theory": "乐理研习 — 知识的螺旋星云",
	"modes": "调式风格 — 晶格化职业星座",
	"denoise": "声学降噪 — 谐振防御场",
}

# ============================================================
# 技能树数据 — 从 JSON 配置文件加载
# ============================================================
const SKILL_TREES_PATH := "res://data/skill_trees/skill_trees.json"
var SKILL_TREES: Dictionary = {}

func _load_skill_trees() -> void:
	var file := FileAccess.open(SKILL_TREES_PATH, FileAccess.READ)
	if file == null:
		push_error("MetaProgressionVisualizer: 无法加载技能树数据: %s" % SKILL_TREES_PATH)
		SKILL_TREES = _SKILL_TREES_LEGACY.duplicate(true)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("MetaProgressionVisualizer: JSON 解析失败: %s" % json.get_error_message())
		SKILL_TREES = _SKILL_TREES_LEGACY.duplicate(true)
		return
	SKILL_TREES = json.data
	print("[MetaProgressionVisualizer] 已加载 %d 个技能树模块" % SKILL_TREES.size())

# 以下为原始硬编码数据的备份引用（已迁移至 data/skill_trees/skill_trees.json）
const _SKILL_TREES_LEGACY := {
	"instrument": {
		"layout": "vertical",  # 垂直推杆
		"nodes": [
			{"id": "stage_presence", "name": "舞台定力", "desc": "初始最大生命值 +10/级",
			 "cost": 20, "max_level": 10, "layer": 0, "slot": 0, "prereqs": []},
			{"id": "acoustic_pressure", "name": "基础声压", "desc": "法术基础伤害 +2%/级",
			 "cost": 25, "max_level": 10, "layer": 0, "slot": 1, "prereqs": []},
			{"id": "rhythmic_sense", "name": "节拍敏锐度", "desc": "完美判定窗口 +15ms/级",
			 "cost": 30, "max_level": 5, "layer": 0, "slot": 2, "prereqs": []},
			{"id": "pickup_range", "name": "拾音范围", "desc": "吸附范围 +20px/级",
			 "cost": 15, "max_level": 8, "layer": 0, "slot": 3, "prereqs": []},
			{"id": "upbeat_velocity", "name": "起拍速度", "desc": "投射物速度 +3%/级",
			 "cost": 20, "max_level": 8, "layer": 0, "slot": 4, "prereqs": []},
		],
	},
	"theory": {
		"layout": "radial",  # 中心辐射
		"nodes": [
			{"id": "black_key_tracking", "name": "D# 追踪", "desc": "解锁 D# 追踪修饰符",
			 "cost": 40, "max_level": 1, "layer": 0, "slot": 0, "prereqs": []},
			{"id": "black_key_echo", "name": "G# 回响", "desc": "解锁 G# 回响修饰符",
			 "cost": 40, "max_level": 1, "layer": 0, "slot": 1, "prereqs": []},
			{"id": "black_key_scatter", "name": "A# 散射", "desc": "解锁 A# 散射修饰符",
			 "cost": 50, "max_level": 1, "layer": 1, "slot": 0, "prereqs": ["black_key_echo"]},
			{"id": "chord_tension", "name": "紧张度理论", "desc": "解锁减三/增三和弦",
			 "cost": 60, "max_level": 1, "layer": 1, "slot": 1, "prereqs": []},
			{"id": "chord_seventh", "name": "七和弦解析", "desc": "解锁属七/大七/小七/减七",
			 "cost": 80, "max_level": 1, "layer": 2, "slot": 0, "prereqs": ["chord_tension"]},
			{"id": "legend_chapter", "name": "传说乐章许可", "desc": "提升扩展和弦出现概率",
			 "cost": 120, "max_level": 1, "layer": 3, "slot": 0, "prereqs": ["chord_seventh"]},
		],
	},
	"modes": {
		"layout": "constellation",  # 星座图
		"nodes": [
			{"id": "ionian", "name": "伊奥尼亚", "desc": "[均衡者] C大调，全套白键",
			 "cost": 0, "max_level": 1, "layer": 0, "slot": 0, "prereqs": []},
			{"id": "dorian", "name": "多利亚", "desc": "[民谣诗人] 小调色彩，自带回响",
			 "cost": 80, "max_level": 1, "layer": 1, "slot": 0, "prereqs": ["ionian"]},
			{"id": "pentatonic", "name": "五声音阶", "desc": "[东方行者] CDEGA，伤害+20%",
			 "cost": 60, "max_level": 1, "layer": 1, "slot": 1, "prereqs": ["ionian"]},
			{"id": "blues", "name": "布鲁斯", "desc": "[爵士乐手] 不和谐→暴击转化",
			 "cost": 100, "max_level": 1, "layer": 2, "slot": 0, "prereqs": ["dorian"]},
		],
	},
	"denoise": {
		"layout": "ring",  # 同心环
		"nodes": [
			{"id": "auditory_tolerance", "name": "听觉耐受", "desc": "单调值累积 -5%/级",
			 "cost": 35, "max_level": 3, "layer": 0, "slot": 0, "prereqs": []},
			{"id": "reverb_damping", "name": "混响消除", "desc": "密度恢复 +10%/级",
			 "cost": 35, "max_level": 3, "layer": 0, "slot": 1, "prereqs": []},
			{"id": "perfect_pitch", "name": "绝对音感", "desc": "不和谐腐蚀 -1HP/级",
			 "cost": 40, "max_level": 3, "layer": 0, "slot": 2, "prereqs": []},
			{"id": "rest_aesthetics", "name": "休止符美学", "desc": "休止符清除效率 +15%/级",
			 "cost": 30, "max_level": 3, "layer": 1, "slot": 0, "prereqs": ["auditory_tolerance"]},
		],
	},
}

# ============================================================
# 布局参数 — @export 支持编辑器实时调整
# ============================================================
@export_group("Node Layout")
@export var node_radius: float = 32.0
@export var node_radius_hover: float = 38.0

# ============================================================
# 状态
# ============================================================
var _meta: Node = null
var _current_module: String = ""
var _is_open: bool = false
var _time: float = 0.0
var _fragments: int = 0

## 节点位置与状态
var _node_positions: Dictionary = {}   # node_id → Vector2
var _node_states: Dictionary = {}      # node_id → "locked" / "unlockable" / "unlocked"
var _hover_node: String = ""

## 解锁动画
var _unlock_anims: Array[Dictionary] = []

## 背景星尘
var _bg_stars: Array[Dictionary] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_load_skill_trees()
	_meta = get_node_or_null("/root/MetaProgressionManager")
	_generate_bg_stars(120)
	visible = false

func _process(delta: float) -> void:
	if not _is_open:
		return
	_time += delta

	# 更新解锁动画
	var finished: Array[int] = []
	for i in range(_unlock_anims.size()):
		_unlock_anims[i]["progress"] += delta * 2.0
		if _unlock_anims[i]["progress"] >= 1.0:
			finished.append(i)
	for i in range(finished.size() - 1, -1, -1):
		_unlock_anims.remove_at(finished[i])

	queue_redraw()

# ============================================================
# 公共接口
# ============================================================

func open_module(module_key: String) -> void:
	_current_module = module_key
	_is_open = true
	visible = true
	_refresh_data()
	_calculate_positions()
	queue_redraw()

func open_panel() -> void:
	open_module("instrument")

func close_panel() -> void:
	_is_open = false
	visible = false
	back_pressed.emit()

# ============================================================
# 数据刷新
# ============================================================

func _refresh_data() -> void:
	if _meta:
		_fragments = _meta.get_resonance_fragments()
	_update_node_states()

func _update_node_states() -> void:
	_node_states.clear()
	if _current_module.is_empty():
		return

	var tree: Dictionary = SKILL_TREES.get(_current_module, {})
	var nodes: Array = tree.get("nodes", [])

	for node in nodes:
		var nid: String = node["id"]
		var is_unlocked := _is_node_unlocked(nid)
		if is_unlocked:
			_node_states[nid] = "unlocked"
		elif _can_unlock_node(node):
			_node_states[nid] = "unlockable"
		else:
			_node_states[nid] = "locked"

func _is_node_unlocked(node_id: String) -> bool:
	if not _meta:
		return false
	# 检查各模块
	match _current_module:
		"instrument":
			return _meta.get_instrument_level(node_id) > 0
		"theory":
			return _meta.is_theory_unlocked(node_id)
		"modes":
			return _meta.is_mode_unlocked(node_id)
		"denoise":
			return _meta.get_acoustic_level(node_id) > 0
	return false

func _get_node_level(node_id: String) -> int:
	if not _meta:
		return 0
	match _current_module:
		"instrument":
			return _meta.get_instrument_level(node_id)
		"denoise":
			return _meta.get_acoustic_level(node_id)
		"theory":
			return 1 if _meta.is_theory_unlocked(node_id) else 0
		"modes":
			return 1 if _meta.is_mode_unlocked(node_id) else 0
	return 0

func _get_node_max_level(node: Dictionary) -> int:
	return node.get("max_level", 1)

func _get_node_cost(node_id: String) -> int:
	if not _meta:
		return 0
	match _current_module:
		"instrument":
			return _meta.get_instrument_cost(node_id)
		"theory":
			var config: Dictionary = _meta.THEORY_UNLOCKS.get(node_id, {})
			return config.get("cost", 0)
		"modes":
			var config: Dictionary = _meta.MODE_CONFIGS.get(node_id, {})
			return config.get("cost", 0)
		"denoise":
			return _meta.get_acoustic_cost(node_id)
	return 0

func _can_unlock_node(node: Dictionary) -> bool:
	var nid: String = node["id"]
	var level := _get_node_level(nid)
	var max_level: int = node.get("max_level", 1)
	if level >= max_level:
		return false

	# 检查前置
	var prereqs: Array = node.get("prereqs", [])
	for prereq_id in prereqs:
		if not _is_node_unlocked(prereq_id):
			return false

	# 检查费用
	var cost := _get_node_cost(nid)
	return _fragments >= cost

# ============================================================
# 位置计算 — 根据模块布局类型
# ============================================================

func _calculate_positions() -> void:
	_node_positions.clear()
	var vp := get_viewport_rect().size
	var center := vp / 2.0

	var tree: Dictionary = SKILL_TREES.get(_current_module, {})
	var layout: String = tree.get("layout", "vertical")
	var nodes: Array = tree.get("nodes", [])

	match layout:
		"vertical":
			_calc_vertical_layout(nodes, center, vp)
		"radial":
			_calc_radial_layout(nodes, center)
		"constellation":
			_calc_constellation_layout(nodes, center)
		"ring":
			_calc_ring_layout(nodes, center)

func _calc_vertical_layout(nodes: Array, center: Vector2, vp: Vector2) -> void:
	# 乐器调优：每个属性一根垂直推杆
	var count := nodes.size()
	var spacing := min(160.0, (vp.x - 200.0) / float(max(count, 1)))
	var start_x := center.x - (count - 1) * spacing / 2.0

	for i in range(nodes.size()):
		var node: Dictionary = nodes[i]
		var x := start_x + i * spacing
		var y := center.y
		_node_positions[node["id"]] = Vector2(x, y)

func _calc_radial_layout(nodes: Array, center: Vector2) -> void:
	# 乐理研习：中心辐射状螺旋
	var layer_radius := [0.0, 120.0, 200.0, 280.0]
	var layer_counts: Dictionary = {}

	for node in nodes:
		var layer: int = node.get("layer", 0)
		if not layer_counts.has(layer):
			layer_counts[layer] = 0
		layer_counts[layer] += 1

	var layer_indices: Dictionary = {}
	for node in nodes:
		var layer: int = node.get("layer", 0)
		if not layer_indices.has(layer):
			layer_indices[layer] = 0

		var count: int = layer_counts[layer]
		var idx: int = layer_indices[layer]
		layer_indices[layer] += 1

		if layer == 0:
			# 第0层围绕中心
			var angle := idx * TAU / float(max(count, 1)) - PI / 2.0
			var r := 100.0
			_node_positions[node["id"]] = center + Vector2(cos(angle), sin(angle)) * r
		else:
			var r: float = layer_radius[min(layer, layer_radius.size() - 1)]
			var angle := idx * TAU / float(max(count, 1)) - PI / 2.0 + layer * 0.3
			_node_positions[node["id"]] = center + Vector2(cos(angle), sin(angle)) * r

func _calc_constellation_layout(nodes: Array, center: Vector2) -> void:
	# 调式风格：星座图
	var positions := {
		0: [Vector2(0, -80)],                                    # 层0: 中心上方
		1: [Vector2(-120, 20), Vector2(120, 20)],                # 层1: 左右
		2: [Vector2(0, 120)],                                     # 层2: 下方
	}

	for node in nodes:
		var layer: int = node.get("layer", 0)
		var slot: int = node.get("slot", 0)
		var layer_pos: Array = positions.get(layer, [Vector2.ZERO])
		var pos: Vector2 = layer_pos[min(slot, layer_pos.size() - 1)]
		_node_positions[node["id"]] = center + pos

func _calc_ring_layout(nodes: Array, center: Vector2) -> void:
	# 声学降噪：同心环
	var ring_radii := [100.0, 180.0]
	var layer_counts: Dictionary = {}
	var layer_indices: Dictionary = {}

	for node in nodes:
		var layer: int = node.get("layer", 0)
		if not layer_counts.has(layer):
			layer_counts[layer] = 0
		layer_counts[layer] += 1

	for node in nodes:
		var layer: int = node.get("layer", 0)
		if not layer_indices.has(layer):
			layer_indices[layer] = 0
		var idx: int = layer_indices[layer]
		layer_indices[layer] += 1

		var r: float = ring_radii[min(layer, ring_radii.size() - 1)]
		var count: int = layer_counts[layer]
		var angle := idx * TAU / float(max(count, 1)) - PI / 2.0
		_node_positions[node["id"]] = center + Vector2(cos(angle), sin(angle)) * r

# ============================================================
# 背景星尘
# ============================================================

func _generate_bg_stars(count: int) -> void:
	_bg_stars.clear()
	for i in range(count):
		_bg_stars.append({
			"pos": Vector2(randf() * 1920.0, randf() * 1080.0),
			"size": randf_range(0.5, 2.0),
			"phase": randf() * TAU,
			"brightness": randf_range(0.2, 0.8),
		})

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if not _is_open:
		return

	var vp := get_viewport_rect().size
	var center := vp / 2.0
	var font := ThemeDB.fallback_font
	var module_color: Color = MODULE_COLORS.get(_current_module, ACCENT)

	# 背景
	draw_rect(Rect2(Vector2.ZERO, vp), BG_COLOR)

	# 星尘
	for star in _bg_stars:
		var flicker := 0.5 + 0.5 * sin(_time * 0.8 + star["phase"])
		draw_circle(star["pos"], star["size"],
			Color(0.6, 0.6, 0.8, star["brightness"] * flicker * 0.5))

	# 模块标题
	var title: String = MODULE_NAMES.get(_current_module, "")
	draw_string(font, Vector2(center.x - 160, 40), title,
		HORIZONTAL_ALIGNMENT_CENTER, 320, 18, module_color)

	# 共鸣碎片
	draw_string(font, Vector2(vp.x - 220, 35),
		"✦ %d 共鸣碎片" % _fragments, HORIZONTAL_ALIGNMENT_RIGHT, 200, 14, FRAGMENT_COLOR)

	# 进度条
	if _meta:
		var progress := _meta.get_module_progress(_current_module)
		var bar_w := 300.0
		var bar_h := 6.0
		var bar_x := center.x - bar_w / 2.0
		var bar_y := 55.0
		draw_rect(Rect2(Vector2(bar_x, bar_y), Vector2(bar_w, bar_h)),
			Color(0.15, 0.12, 0.22, 0.6))
		draw_rect(Rect2(Vector2(bar_x, bar_y), Vector2(bar_w * progress, bar_h)),
			Color(module_color.r, module_color.g, module_color.b, 0.7))
		draw_string(font, Vector2(bar_x + bar_w + 10, bar_y + 5),
			"%d%%" % int(progress * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DIM_TEXT)

	# 布局装饰
	_draw_layout_decoration(center, module_color)

	# 连线
	_draw_links(module_color)

	# 节点
	_draw_nodes(font, module_color)

	# 解锁动画
	_draw_unlock_animations(module_color)

	# 悬停信息
	_draw_hover_tooltip(font, vp)

	# 导航按钮
	_draw_nav_buttons(font, vp)

func _draw_layout_decoration(center: Vector2, color: Color) -> void:
	match _current_module:
		"instrument":
			# 调音台底座线
			var tree: Dictionary = SKILL_TREES["instrument"]
			var nodes: Array = tree["nodes"]
			if nodes.size() > 0:
				var first_pos: Vector2 = _node_positions.get(nodes[0]["id"], center)
				var last_pos: Vector2 = _node_positions.get(nodes[nodes.size() - 1]["id"], center)
				draw_line(Vector2(first_pos.x - 40, center.y + 80),
					Vector2(last_pos.x + 40, center.y + 80),
					Color(color.r, color.g, color.b, 0.15), 2.0)
			# 推杆轨道
			for node in nodes:
				var pos: Vector2 = _node_positions.get(node["id"], center)
				var level := _get_node_level(node["id"])
				var max_level: int = node.get("max_level", 10)
				var track_h := 120.0
				var track_top := pos.y - track_h / 2.0
				# 轨道背景
				draw_line(Vector2(pos.x, track_top), Vector2(pos.x, track_top + track_h),
					Color(0.2, 0.18, 0.3, 0.3), 4.0)
				# 填充量
				var fill := float(level) / float(max(max_level, 1))
				var fill_h := track_h * fill
				draw_line(Vector2(pos.x, track_top + track_h - fill_h),
					Vector2(pos.x, track_top + track_h),
					Color(color.r, color.g, color.b, 0.4), 4.0)

		"theory":
			# 螺旋装饰线
			var points := 64
			for i in range(points):
				var t := float(i) / float(points)
				var angle := t * TAU * 2.0 + _time * 0.1
				var r := 50.0 + t * 250.0
				var pt := center + Vector2(cos(angle), sin(angle)) * r
				var alpha := (1.0 - t) * 0.08
				draw_circle(pt, 1.0, Color(color.r, color.g, color.b, alpha))

		"modes":
			# 星座背景网格
			pass

		"denoise":
			# 同心环装饰
			for i in range(4):
				var r := 60.0 + i * 50.0
				var alpha := 0.06 - i * 0.01
				var speed := 0.3 + i * 0.1
				draw_arc(center, r, _time * speed, _time * speed + TAU, 64,
					Color(color.r, color.g, color.b, alpha), 1.0)

func _draw_links(module_color: Color) -> void:
	var tree: Dictionary = SKILL_TREES.get(_current_module, {})
	var nodes: Array = tree.get("nodes", [])

	for node in nodes:
		var nid: String = node["id"]
		var prereqs: Array = node.get("prereqs", [])
		if not _node_positions.has(nid):
			continue
		var to_pos: Vector2 = _node_positions[nid]

		for prereq_id in prereqs:
			if not _node_positions.has(prereq_id):
				continue
			var from_pos: Vector2 = _node_positions[prereq_id]

			var state: String = _node_states.get(nid, "locked")
			var prereq_state: String = _node_states.get(prereq_id, "locked")
			var link_color: Color

			if state == "unlocked":
				link_color = LINK_UNLOCKED
			elif prereq_state == "unlocked":
				link_color = LINK_ACTIVE
				# 能量脉冲动画
				var pulse := fmod(_time * 0.8, 1.0)
				var pulse_pos := from_pos.lerp(to_pos, pulse)
				draw_circle(pulse_pos, 3.0,
					Color(module_color.r, module_color.g, module_color.b, 0.5 * (1.0 - pulse)))
			else:
				link_color = LINK_LOCKED

			# 虚线（未解锁）或实线（已解锁）
			if state == "locked" and prereq_state == "locked":
				_draw_dashed_line(from_pos, to_pos, link_color, 2.0, 8.0)
			else:
				draw_line(from_pos, to_pos, link_color, 2.0)

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float) -> void:
	var dir := (to - from).normalized()
	var total_len := from.distance_to(to)
	var pos := from
	var drawn := 0.0
	var is_dash := true
	while drawn < total_len:
		var seg_len := min(dash_len, total_len - drawn)
		var end_pos := pos + dir * seg_len
		if is_dash:
			draw_line(pos, end_pos, color, width)
		pos = end_pos
		drawn += seg_len
		is_dash = not is_dash

func _draw_nodes(font: Font, module_color: Color) -> void:
	var tree: Dictionary = SKILL_TREES.get(_current_module, {})
	var nodes: Array = tree.get("nodes", [])

	for node in nodes:
		var nid: String = node["id"]
		if not _node_positions.has(nid):
			continue
		var pos: Vector2 = _node_positions[nid]
		var state: String = _node_states.get(nid, "locked")
		var is_hover := (_hover_node == nid)
		var radius := node_radius_hover if is_hover else node_radius

		# 绘制节点
		match state:
			"locked":
				_draw_locked_node(pos, radius, node, font, is_hover)
			"unlockable":
				_draw_unlockable_node(pos, radius, node, font, module_color, is_hover)
			"unlocked":
				_draw_unlocked_node(pos, radius, node, font, module_color, is_hover)

func _draw_locked_node(pos: Vector2, radius: float, node: Dictionary, font: Font, is_hover: bool) -> void:
	# 虚线圆形轮廓
	var segments := 24
	for i in range(segments):
		if i % 2 == 0:
			var a1 := float(i) / float(segments) * TAU
			var a2 := float(i + 1) / float(segments) * TAU
			var p1 := pos + Vector2(cos(a1), sin(a1)) * radius
			var p2 := pos + Vector2(cos(a2), sin(a2)) * radius
			var border_color := NODE_LOCKED_BORDER
			if is_hover:
				border_color = Color(NODE_LOCKED_BORDER.r, NODE_LOCKED_BORDER.g, NODE_LOCKED_BORDER.b, 0.6)
			draw_line(p1, p2, border_color, 1.5)

	# 灰色图标
	var name_text: String = node.get("name", "?")
	if name_text.length() > 4:
		name_text = name_text.left(4)
	var text_color := Color(0.4, 0.35, 0.5, 0.4)
	if is_hover:
		text_color = Color(0.5, 0.45, 0.6, 0.7)
		# 实线轮廓
		draw_arc(pos, radius, 0, TAU, 48, Color(0.4, 0.35, 0.55, 0.5), 1.5)
	draw_string(font, pos + Vector2(-16, 5), name_text,
		HORIZONTAL_ALIGNMENT_CENTER, 32, 10, text_color)

	# 费用（悬停时显示）
	if is_hover:
		var cost := _get_node_cost(node["id"])
		var cost_color := DANGER if _fragments < cost else FRAGMENT_COLOR
		draw_string(font, pos + Vector2(-20, radius + 16),
			"%d ✦" % cost, HORIZONTAL_ALIGNMENT_CENTER, 40, 10, cost_color)

func _draw_unlockable_node(pos: Vector2, radius: float, node: Dictionary, font: Font, module_color: Color, is_hover: bool) -> void:
	# 脉动呼吸效果
	var breath := 0.85 + 0.15 * sin(_time * 2.5)
	var glow_radius := radius * breath

	# 辉光
	for i in range(3):
		var r := glow_radius + i * 5.0
		var alpha := 0.15 - i * 0.04
		if is_hover:
			alpha *= 2.0
		draw_arc(pos, r, 0, TAU, 48,
			Color(module_color.r, module_color.g, module_color.b, alpha), 2.0)

	# 实线边框
	draw_arc(pos, radius, 0, TAU, 48, NODE_UNLOCKABLE_BORDER, 2.0)

	# 半透明填充
	draw_circle(pos, radius * 0.9, Color(module_color.r, module_color.g, module_color.b, 0.08))

	# 图标（单色但清晰）
	var name_text: String = node.get("name", "?")
	if name_text.length() > 4:
		name_text = name_text.left(4)
	draw_string(font, pos + Vector2(-16, 5), name_text,
		HORIZONTAL_ALIGNMENT_CENTER, 32, 10,
		Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, 0.8))

	# 费用
	var cost := _get_node_cost(node["id"])
	var cost_color := FRAGMENT_COLOR
	draw_string(font, pos + Vector2(-20, radius + 16),
		"%d ✦" % cost, HORIZONTAL_ALIGNMENT_CENTER, 40, 10, cost_color)

	# 粒子流入效果
	if is_hover:
		for i in range(4):
			var angle := _time * 3.0 + i * TAU / 4.0
			var dist := radius + 15.0 - fmod(_time * 20.0 + i * 5.0, 20.0)
			var pt := pos + Vector2(cos(angle), sin(angle)) * dist
			draw_circle(pt, 2.0, Color(module_color.r, module_color.g, module_color.b, 0.4))

func _draw_unlocked_node(pos: Vector2, radius: float, node: Dictionary, font: Font, module_color: Color, is_hover: bool) -> void:
	var level := _get_node_level(node["id"])
	var max_level: int = node.get("max_level", 1)
	var is_maxed := level >= max_level

	# 发光填充
	var fill_color: Color
	if is_maxed:
		fill_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.2)
	else:
		fill_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.15)
	draw_circle(pos, radius, fill_color)

	# 强烈边框
	var border_color := Color(GOLD.r, GOLD.g, GOLD.b, 0.8) if is_maxed else NODE_UNLOCKED_BORDER
	draw_arc(pos, radius, 0, TAU, 48, border_color, 2.5)

	# 外层辉光
	var glow_alpha := 0.1 + 0.05 * sin(_time * 1.5)
	if is_hover:
		glow_alpha *= 2.0
	draw_arc(pos, radius + 4, 0, TAU, 48,
		Color(border_color.r, border_color.g, border_color.b, glow_alpha), 3.0)

	# 全彩图标
	var name_text: String = node.get("name", "?")
	if name_text.length() > 4:
		name_text = name_text.left(4)
	var text_color := GOLD if is_maxed else CYAN
	draw_string(font, pos + Vector2(-16, 5), name_text,
		HORIZONTAL_ALIGNMENT_CENTER, 32, 10, text_color)

	# 等级显示
	if max_level > 1:
		var level_text := "Lv.%d/%d" % [level, max_level]
		if is_maxed:
			level_text = "MAX"
		draw_string(font, pos + Vector2(-24, radius + 16),
			level_text, HORIZONTAL_ALIGNMENT_CENTER, 48, 9,
			Color(GOLD.r, GOLD.g, GOLD.b, 0.7) if is_maxed else Color(CYAN.r, CYAN.g, CYAN.b, 0.7))

	# 可继续升级时显示费用
	if not is_maxed:
		var cost := _get_node_cost(node["id"])
		if cost > 0:
			var can_afford := _fragments >= cost
			draw_string(font, pos + Vector2(-20, radius + 28),
				"%d ✦" % cost, HORIZONTAL_ALIGNMENT_CENTER, 40, 9,
				FRAGMENT_COLOR if can_afford else Color(DANGER.r, DANGER.g, DANGER.b, 0.6))

func _draw_unlock_animations(module_color: Color) -> void:
	for anim in _unlock_anims:
		var nid: String = anim["node_id"]
		if not _node_positions.has(nid):
			continue
		var pos: Vector2 = _node_positions[nid]
		var progress: float = anim["progress"]

		# 冲击波
		var ring_r := node_radius * (1.0 + progress * 3.0)
		var ring_alpha := (1.0 - progress) * 0.6
		draw_arc(pos, ring_r, 0, TAU, 48,
			Color(CYAN.r, CYAN.g, CYAN.b, ring_alpha), 2.5)

		# 放射粒子
		for i in range(8):
			var angle := float(i) * TAU / 8.0 + progress * 0.5
			var dist := node_radius * (0.5 + progress * 2.0)
			var pt := pos + Vector2(cos(angle), sin(angle)) * dist
			var pt_alpha := (1.0 - progress) * 0.5
			draw_circle(pt, 3.0 * (1.0 - progress),
				Color(GOLD.r, GOLD.g, GOLD.b, pt_alpha))

func _draw_hover_tooltip(font: Font, vp: Vector2) -> void:
	if _hover_node.is_empty():
		return

	var node_data := _find_node(_hover_node)
	if node_data.is_empty():
		return

	var tooltip_w := 320.0
	var tooltip_h := 70.0
	var tooltip_rect := Rect2(
		Vector2(vp.x / 2.0 - tooltip_w / 2.0, vp.y - 100),
		Vector2(tooltip_w, tooltip_h))

	draw_rect(tooltip_rect, Color(0.06, 0.04, 0.12, 0.92))
	draw_rect(tooltip_rect, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3), false, 1.0)

	# 名称
	draw_string(font, tooltip_rect.position + Vector2(12, 22),
		node_data.get("name", "?"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT_COLOR)

	# 描述
	draw_string(font, tooltip_rect.position + Vector2(12, 42),
		node_data.get("desc", ""), HORIZONTAL_ALIGNMENT_LEFT, int(tooltip_w - 24), 11, DIM_TEXT)

	# 状态
	var state: String = _node_states.get(_hover_node, "locked")
	var level := _get_node_level(_hover_node)
	var max_level: int = node_data.get("max_level", 1)
	var status_text := ""
	var status_color := DIM_TEXT

	match state:
		"unlocked":
			if level >= max_level:
				status_text = "已满级"
				status_color = GOLD
			else:
				status_text = "Lv.%d/%d" % [level, max_level]
				status_color = CYAN
		"unlockable":
			status_text = "可解锁"
			status_color = SUCCESS
		"locked":
			status_text = "未解锁"
			status_color = Color(0.5, 0.4, 0.6)

	draw_string(font, tooltip_rect.position + Vector2(tooltip_w - 80, 22),
		status_text, HORIZONTAL_ALIGNMENT_RIGHT, 70, 11, status_color)

var _back_btn_rect := Rect2()
var _start_btn_rect := Rect2()

func _draw_nav_buttons(font: Font, vp: Vector2) -> void:
	# 返回按钮
	_back_btn_rect = Rect2(Vector2(30, vp.y - 55), Vector2(120, 40))
	draw_rect(_back_btn_rect, Color(0.1, 0.08, 0.18, 0.85))
	draw_rect(_back_btn_rect, Color(0.4, 0.35, 0.55, 0.5), false, 1.0)
	draw_string(font, _back_btn_rect.position + Vector2(16, 26),
		"← 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.65, 0.85))

	# 开始游戏按钮
	_start_btn_rect = Rect2(Vector2(vp.x - 180, vp.y - 55), Vector2(150, 40))
	draw_rect(_start_btn_rect, Color(0.05, 0.15, 0.1, 0.85))
	draw_rect(_start_btn_rect, Color(0.3, 0.8, 0.5, 0.5), false, 1.0)
	draw_string(font, _start_btn_rect.position + Vector2(16, 26),
		"开始演奏 ▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 0.9, 0.5))

# ============================================================
# 输入处理
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event is InputEventMouseMotion:
		_hover_node = ""
		for nid in _node_positions:
			var pos: Vector2 = _node_positions[nid]
			if pos.distance_to(event.position) <= node_radius_hover:
				_hover_node = nid
				break

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var click_pos := event.position

			# 导航按钮
			if _back_btn_rect.has_point(click_pos):
				close_panel()
				return
			if _start_btn_rect.has_point(click_pos):
				start_game_pressed.emit()
				return

			# 节点点击
			if not _hover_node.is_empty():
				_try_unlock_node(_hover_node)

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			close_panel()

	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				close_panel()
			KEY_ENTER:
				start_game_pressed.emit()
			KEY_1:
				open_module("instrument")
			KEY_2:
				open_module("theory")
			KEY_3:
				open_module("modes")
			KEY_4:
				open_module("denoise")

# ============================================================
# 解锁逻辑
# ============================================================

func _try_unlock_node(node_id: String) -> void:
	var node_data := _find_node(node_id)
	if node_data.is_empty():
		return

	var state: String = _node_states.get(node_id, "locked")

	# 已解锁但未满级的可继续升级
	if state == "unlocked":
		var level := _get_node_level(node_id)
		var max_level: int = node_data.get("max_level", 1)
		if level >= max_level:
			return  # 已满级
		# 可继续升级
		if not _meta:
			return
		var cost := _get_node_cost(node_id)
		if _fragments < cost:
			return

	elif state != "unlockable":
		return

	# 执行解锁/升级
	if not _meta:
		return

	var success := false
	match _current_module:
		"instrument":
			success = _meta.purchase_instrument_upgrade(node_id)
		"theory":
			success = _meta.purchase_theory_unlock(node_id)
		"modes":
			if _meta.is_mode_unlocked(node_id):
				_meta.select_mode(node_id)
				success = true
			else:
				success = _meta.purchase_mode_unlock(node_id)
		"denoise":
			success = _meta.purchase_acoustic_upgrade(node_id)

	if success:
		# 播放解锁动画
		_unlock_anims.append({"node_id": node_id, "progress": 0.0})
		node_unlocked.emit(node_id, _current_module)
		_refresh_data()

# ============================================================
# 工具函数
# ============================================================

func _find_node(node_id: String) -> Dictionary:
	var tree: Dictionary = SKILL_TREES.get(_current_module, {})
	var nodes: Array = tree.get("nodes", [])
	for node in nodes:
		if node["id"] == node_id:
			return node
	return {}

# ============================================================
# 局内标注接口 — 兼容旧版
# ============================================================

func is_upgrade_meta_unlocked(upgrade_id: String) -> bool:
	if not _meta:
		return false
	return _meta.is_theory_unlocked(upgrade_id) if _meta.has_method("is_theory_unlocked") else false

func get_meta_bonus_for_stat(stat: String) -> float:
	if not _meta:
		return 0.0
	return _meta.get_instrument_bonus(stat) if _meta.has_method("get_instrument_bonus") else 0.0

func get_fatigue_resistance(fatigue_type: String) -> float:
	if not _meta:
		return 0.0
	return _meta.get_acoustic_bonus(fatigue_type) if _meta.has_method("get_acoustic_bonus") else 0.0

func get_unlocked_modes() -> Array[String]:
	var modes: Array[String] = []
	if _meta:
		for mode_name in _meta.MODE_CONFIGS:
			if _meta.is_mode_unlocked(mode_name):
				modes.append(mode_name)
	return modes
