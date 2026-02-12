## codex_unlock_popup.gd
## 图鉴解锁弹窗与通知系统 — v6.0 重写
##
## 根据 UI_Design_Module4_CircleOfFifths.md §9 设计文档重写：
##   - 非阻塞式解锁通知弹窗
##   - 屏幕右上角滑入/滑出动画
##   - 多通知堆叠（最多3条同时显示）
##   - 特殊通知（乐理突破）使用圣光金边框 + 闪光效果
##   - 与 CodexUI 联动：点击弹窗可跳转到对应条目
##
## 设计规范 (§9.1)：
##   - 位置：屏幕右上角，距顶部 80px，距右侧 20px
##   - 尺寸：宽 300px × 高 80px，圆角 8px
##   - 背景：星空紫，90% 不透明度
##   - 边框：1px 谐振紫辉光边框
##   - 入场：从右侧滑入 0.3s，缓出曲线
##   - 停留：3 秒
##   - 退场：向右滑出 0.3s，缓入曲线
##   - 堆叠：向下堆叠，间距 8px，最多3条
extends Control

# ============================================================
# 信号
# ============================================================
signal notification_clicked(entry_id: String)
signal notification_dismissed(entry_id: String)

# ============================================================
# 常量 — 颜色方案 (与 §1.2 对齐)
# ============================================================
const COL_BG := Color("#141026E6")            ## 星空紫 90%
const COL_ACCENT := Color("#9D6FFF")          ## 谐振紫
const COL_GOLD := Color("#FFD700")            ## 圣光金
const COL_TEXT_PRIMARY := Color("#EAE6FF")    ## 晶体白
const COL_TEXT_SECONDARY := Color("#A098C8")  ## 次级文本
const COL_TEXT_DIM := Color("#6B668A")        ## 暗淡文本

# ============================================================
# 常量 — 布局参数 (§9.1)
# ============================================================
const POPUP_WIDTH: float = 300.0
const POPUP_HEIGHT: float = 80.0
const POPUP_CORNER_RADIUS: int = 8
const POPUP_MARGIN_TOP: float = 80.0
const POPUP_MARGIN_RIGHT: float = 20.0
const POPUP_SPACING: float = 8.0
const POPUP_ICON_SIZE: float = 40.0
const MAX_VISIBLE_POPUPS: int = 3

# ============================================================
# 常量 — 动画参数 (§11.1)
# ============================================================
const ANIM_SLIDE_IN_DURATION: float = 0.3
const ANIM_SLIDE_OUT_DURATION: float = 0.3
const ANIM_STAY_DURATION: float = 3.0

# ============================================================
# 卷名称映射
# ============================================================
const VOLUME_NAMES: Dictionary = {
	0: "乐理纲要",
	1: "百相众声",
	2: "失谐魔物",
	3: "神兵乐章",
}

# ============================================================
# 内部状态
# ============================================================
var _queue: Array[Dictionary] = []
var _active_popups: Array[Dictionary] = []  ## [{node, entry_id, is_special}]
var _popup_container: VBoxContainer = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 创建弹窗堆叠容器 — 定位到右上角
	_popup_container = VBoxContainer.new()
	_popup_container.name = "PopupStack"
	_popup_container.add_theme_constant_override("separation", int(POPUP_SPACING))
	_popup_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_container.set_anchor(SIDE_RIGHT, 1.0)
	_popup_container.set_anchor(SIDE_TOP, 0.0)
	_popup_container.offset_right = -POPUP_MARGIN_RIGHT
	_popup_container.offset_left = -POPUP_MARGIN_RIGHT - POPUP_WIDTH
	_popup_container.offset_top = POPUP_MARGIN_TOP
	_popup_container.offset_bottom = POPUP_MARGIN_TOP + (POPUP_HEIGHT + POPUP_SPACING) * MAX_VISIBLE_POPUPS
	add_child(_popup_container)

	# 连接 CodexManager 信号
	if CodexManager and CodexManager.has_signal("entry_unlocked"):
		CodexManager.entry_unlocked.connect(_on_entry_unlocked)

func _process(_delta: float) -> void:
	# 处理队列中的待显示通知
	if not _queue.is_empty() and _active_popups.size() < MAX_VISIBLE_POPUPS:
		_show_next()

# ============================================================
# 公共接口
# ============================================================

## 显示普通解锁通知
func show_unlock(entry_id: String, entry_name: String, subtitle: String = "",
				 rarity: int = 0, rarity_color: Color = Color.WHITE,
				 icon_color: Color = Color.WHITE) -> void:
	_queue.append({
		"entry_id": entry_id,
		"name": entry_name,
		"subtitle": subtitle,
		"rarity": rarity,
		"rarity_color": rarity_color,
		"icon_color": icon_color,
		"is_special": false,
		"category_text": "已添加至图鉴",
	})

## 显示特殊解锁通知（乐理突破等）— §9.2
func show_special_unlock(entry_id: String, entry_name: String,
						 subtitle: String = "", category_text: String = "乐理突破！") -> void:
	# 特殊通知优先显示（插入队列前端）
	_queue.push_front({
		"entry_id": entry_id,
		"name": entry_name,
		"subtitle": subtitle,
		"rarity": 3,
		"rarity_color": COL_GOLD,
		"icon_color": COL_GOLD,
		"is_special": true,
		"category_text": category_text,
	})

## 显示升级获得通知
func show_upgrade_acquired(upgrade_name: String, direction: String) -> void:
	var icon_color := Color.WHITE
	var cat_text := "升级获得"
	match direction:
		"offense":
			icon_color = Color("#FF4444")
			cat_text = "进攻升级获得"
		"defense":
			icon_color = Color("#4488FF")
			cat_text = "防御升级获得"
		"core":
			icon_color = COL_ACCENT
			cat_text = "核心升级获得"

	_queue.append({
		"entry_id": "",
		"name": upgrade_name,
		"subtitle": "",
		"rarity": 0,
		"rarity_color": icon_color,
		"icon_color": icon_color,
		"is_special": false,
		"category_text": cat_text,
	})

## 清除所有通知
func clear_all() -> void:
	_queue.clear()
	for popup_info in _active_popups:
		if popup_info.has("node") and is_instance_valid(popup_info["node"]):
			popup_info["node"].queue_free()
	_active_popups.clear()

# ============================================================
# 内部 — CodexManager 信号回调
# ============================================================

func _on_entry_unlocked(entry_id: String, entry_name: String, volume: int) -> void:
	var data := CodexData.find_entry(entry_id)
	var rarity: int = data.get("rarity", CodexData.Rarity.COMMON)
	var rarity_color: Color = CodexData.RARITY_COLORS.get(rarity, Color.WHITE)
	var volume_name: String = VOLUME_NAMES.get(volume, "未知")

	show_unlock(entry_id, entry_name,
		"第%s卷 · %s" % [["一","二","三","四"].get(volume, "?"), volume_name],
		rarity, rarity_color, rarity_color)

# ============================================================
# 内部 — 通知显示
# ============================================================

func _show_next() -> void:
	if _queue.is_empty():
		return

	var info: Dictionary = _queue.pop_front()
	var is_special: bool = info.get("is_special", false)
	var rarity_color: Color = info.get("rarity_color", Color.WHITE)
	var icon_color: Color = info.get("icon_color", Color.WHITE)
	var entry_id: String = info.get("entry_id", "")

	# ---- 创建面板 ----
	var panel := PanelContainer.new()
	panel.name = "Popup_%s" % entry_id
	panel.custom_minimum_size = Vector2(POPUP_WIDTH, POPUP_HEIGHT)

	var style := StyleBoxFlat.new()
	style.bg_color = COL_BG
	style.corner_radius_top_left = POPUP_CORNER_RADIUS
	style.corner_radius_top_right = POPUP_CORNER_RADIUS
	style.corner_radius_bottom_left = POPUP_CORNER_RADIUS
	style.corner_radius_bottom_right = POPUP_CORNER_RADIUS
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8

	# 边框：特殊 → 圣光金 2px + 阴影；普通 → 谐振紫 1px
	var border_color := COL_GOLD if is_special else rarity_color
	var border_w := 2 if is_special else 1
	style.border_color = border_color
	style.border_width_left = border_w
	style.border_width_right = border_w
	style.border_width_top = border_w
	style.border_width_bottom = border_w

	if is_special:
		style.shadow_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.3)
		style.shadow_size = 4

	panel.add_theme_stylebox_override("panel", style)

	# ---- 内容布局 ----
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	# 左侧图标
	var icon_bg := ColorRect.new()
	icon_bg.custom_minimum_size = Vector2(POPUP_ICON_SIZE, POPUP_ICON_SIZE)
	icon_bg.color = Color(icon_color.r, icon_color.g, icon_color.b, 0.2)

	var icon_label := Label.new()
	icon_label.text = "★" if is_special else "♪"
	icon_label.add_theme_font_size_override("font_size", 22)
	icon_label.add_theme_color_override("font_color", COL_GOLD if is_special else icon_color)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_bg.add_child(icon_label)
	hbox.add_child(icon_bg)

	# 右侧文本
	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 2)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var name_label := Label.new()
	name_label.text = info.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", COL_GOLD if is_special else COL_TEXT_PRIMARY)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_vbox.add_child(name_label)

	var cat_label := Label.new()
	cat_label.text = info.get("category_text", "已添加至图鉴")
	cat_label.add_theme_font_size_override("font_size", 11)
	cat_label.add_theme_color_override("font_color", COL_TEXT_SECONDARY)
	text_vbox.add_child(cat_label)

	var subtitle: String = info.get("subtitle", "")
	if not subtitle.is_empty():
		var sub_label := Label.new()
		sub_label.text = subtitle
		sub_label.add_theme_font_size_override("font_size", 10)
		sub_label.add_theme_color_override("font_color", COL_TEXT_DIM)
		sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text_vbox.add_child(sub_label)

	hbox.add_child(text_vbox)
	panel.add_child(hbox)

	# 点击事件
	panel.gui_input.connect(_on_popup_clicked.bind(entry_id))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# 初始位置（屏幕外右侧）
	panel.position.x = POPUP_WIDTH + 50
	panel.modulate.a = 0.0

	_popup_container.add_child(panel)

	var popup_info := {"node": panel, "entry_id": entry_id, "is_special": is_special}
	_active_popups.append(popup_info)

	# ---- 入场动画 (§9.1) ----
	var tween_in := create_tween().set_parallel(true)
	tween_in.tween_property(panel, "position:x", 0.0, ANIM_SLIDE_IN_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween_in.tween_property(panel, "modulate:a", 1.0, ANIM_SLIDE_IN_DURATION * 0.7)

	# 特殊通知：金色脉冲
	if is_special:
		var pulse_tween := create_tween().set_loops(3)
		pulse_tween.tween_property(panel, "modulate",
			Color(1.3, 1.2, 0.8, 1.0), 0.3)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		pulse_tween.tween_property(panel, "modulate",
			Color(1.0, 1.0, 1.0, 1.0), 0.3)\
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

	# ---- 自动退场定时器 ----
	var timer := get_tree().create_timer(ANIM_SLIDE_IN_DURATION + ANIM_STAY_DURATION)
	timer.timeout.connect(_dismiss_popup.bind(popup_info))

func _dismiss_popup(popup_info: Dictionary) -> void:
	var node: Control = popup_info.get("node")
	if not node or not is_instance_valid(node):
		_active_popups.erase(popup_info)
		return

	notification_dismissed.emit(popup_info.get("entry_id", ""))

	# 退场动画 (§9.1)
	var tween_out := create_tween().set_parallel(true)
	tween_out.tween_property(node, "position:x", POPUP_WIDTH + 50, ANIM_SLIDE_OUT_DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween_out.tween_property(node, "modulate:a", 0.0, ANIM_SLIDE_OUT_DURATION)

	# 延迟移除
	var cleanup_timer := get_tree().create_timer(ANIM_SLIDE_OUT_DURATION + 0.1)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free()
		_active_popups.erase(popup_info)
	)

# ============================================================
# 交互回调
# ============================================================

func _on_popup_clicked(event: InputEvent, entry_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not entry_id.is_empty():
			notification_clicked.emit(entry_id)
