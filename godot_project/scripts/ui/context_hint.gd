## context_hint.gd
## 上下文敏感操作提示 (CanvasLayer)
## 模块7：教学引导与辅助 UI
##
## 功能：
##   - 非关键性、上下文敏感的操作提示
##   - 轻量级提示气泡，不打断游戏流程
##   - 基于玩家行为自动触发（长时间未使用功能、停留过久等）
##   - 从屏幕边缘或 UI 元素旁滑出
##
## 设计原则：
##   - 使用 ACCENT_2(#4DFFF3) 青色边框区别于教学系统的紫色
##   - 非模态，不暂停游戏
##   - 有冷却机制，避免频繁打扰
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal context_hint_shown(hint_id: String, text: String)
signal context_hint_dismissed(hint_id: String)

# ============================================================
# 主题颜色
# ============================================================
const PANEL_DARK := UIColors.PANEL_DARK
const ACCENT_CYAN := UIColors.ACCENT_2
const TEXT_SECONDARY := UIColors.TEXT_SECONDARY

# ============================================================
# 配置
# ============================================================
@export var hint_display_duration: float = 5.0
@export var hint_fade_in: float = 0.4
@export var hint_fade_out: float = 0.6
@export var hint_cooldown: float = 30.0
@export var idle_threshold: float = 15.0
@export var max_visible_hints: int = 2

# ============================================================
# 上下文提示定义
# ============================================================
const CONTEXT_HINTS: Dictionary = {
	"idle_no_cast": {
		"text": "尝试按下白键（A S D F G H J）施放音符法术！",
		"trigger": "idle",
		"idle_time": 10.0,
		"priority": 1,
		"max_shows": 2,
	},
	"low_hp_no_dodge": {
		"text": "生命值较低！注意走位躲避敌人攻击。",
		"trigger": "condition",
		"condition": "low_hp",
		"priority": 2,
		"max_shows": 3,
	},
	"high_fatigue_same_note": {
		"text": "尝试切换不同的音符来降低听感疲劳。",
		"trigger": "condition",
		"condition": "high_fatigue",
		"priority": 2,
		"max_shows": 3,
	},
	"unused_composer": {
		"text": "打开一体化编曲台，尝试构建更强力的和弦法术！",
		"trigger": "idle_feature",
		"feature": "IntegratedComposer",
		"idle_time": 60.0,
		"priority": 1,
		"max_shows": 2,
	},
	"unused_codex": {
		"text": "在谐振法典中查阅已发现的音乐知识和敌人信息。",
		"trigger": "idle_feature",
		"feature": "Codex",
		"idle_time": 120.0,
		"priority": 0,
		"max_shows": 1,
	},
	"phase_switch_hint": {
		"text": "尝试切换频谱相位来应对不同类型的敌人！",
		"trigger": "condition",
		"condition": "enemy_variety",
		"priority": 1,
		"max_shows": 2,
	},
	"boss_pattern_hint": {
		"text": "观察 Boss 的攻击节奏，在间隙中寻找反击机会。",
		"trigger": "condition",
		"condition": "boss_fight",
		"priority": 3,
		"max_shows": 1,
	},
}

# ============================================================
# 内部状态
# ============================================================
## 提示面板池
var _hint_panels: Array[PanelContainer] = []
## 当前显示的提示
var _active_hints: Array[Dictionary] = []
## 每个提示的显示次数
var _show_counts: Dictionary = {}
## 全局冷却计时器
var _global_cooldown: float = 0.0
## 各提示的独立冷却
var _hint_cooldowns: Dictionary = {}
## 空闲计时器
var _idle_timer: float = 0.0
## 功能使用时间追踪
var _feature_idle_timers: Dictionary = {}
## 上次玩家操作时间
var _last_action_time: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 90
	_create_hint_pool()
	_connect_signals()

func _process(delta: float) -> void:
	# 更新冷却
	if _global_cooldown > 0.0:
		_global_cooldown -= delta

	for hint_id in _hint_cooldowns.keys():
		_hint_cooldowns[hint_id] -= delta
		if _hint_cooldowns[hint_id] <= 0.0:
			_hint_cooldowns.erase(hint_id)

	# 更新空闲计时
	_idle_timer += delta
	for feature in _feature_idle_timers.keys():
		_feature_idle_timers[feature] += delta

	# 检查空闲触发
	_check_idle_triggers()

# ============================================================
# 公共接口
# ============================================================

## 显示上下文提示
func show_context_hint(hint_id: String, custom_text: String = "") -> void:
	# 检查冷却
	if _global_cooldown > 0.0:
		return
	if _hint_cooldowns.has(hint_id):
		return

	# 检查显示次数限制
	var hint_def: Dictionary = CONTEXT_HINTS.get(hint_id, {})
	var max_shows: int = hint_def.get("max_shows", 3)
	var current_shows: int = _show_counts.get(hint_id, 0)
	if current_shows >= max_shows:
		return

	# 检查最大可见数
	if _active_hints.size() >= max_visible_hints:
		return

	var text: String = custom_text if custom_text != "" else hint_def.get("text", "")
	if text == "":
		return

	# 获取空闲面板
	var panel := _get_available_panel()
	if panel == null:
		return

	# 设置文字
	var label: Label = panel.get_node_or_null("HintLabel")
	if label:
		label.text = text

	# 计算位置（从右侧滑入，垂直堆叠）
	var viewport_size := get_viewport().get_visible_rect().size
	var y_offset := 100.0 + _active_hints.size() * 70.0
	panel.position = Vector2(viewport_size.x + 10, y_offset)
	panel.visible = true
	panel.modulate.a = 1.0

	# 滑入动画
	var target_x := viewport_size.x - panel.custom_minimum_size.x - 20
	var tween := create_tween()
	tween.tween_property(panel, "position:x", target_x, hint_fade_in) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# 记录状态
	var hint_data := {
		"id": hint_id,
		"panel": panel,
		"tween": tween,
	}
	_active_hints.append(hint_data)
	_show_counts[hint_id] = current_shows + 1
	_global_cooldown = 5.0  # 短暂全局冷却
	_hint_cooldowns[hint_id] = hint_cooldown

	context_hint_shown.emit(hint_id, text)

	# 自动消失
	get_tree().create_timer(hint_display_duration).timeout.connect(func():
		_dismiss_hint(hint_id)
	)

## 手动触发条件提示
func trigger_condition(condition: String) -> void:
	for hint_id in CONTEXT_HINTS:
		var hint_def: Dictionary = CONTEXT_HINTS[hint_id]
		if hint_def.get("trigger", "") == "condition" and hint_def.get("condition", "") == condition:
			show_context_hint(hint_id)
			return

## 通知玩家执行了操作（重置空闲计时）
func notify_player_action(action_type: String = "") -> void:
	_idle_timer = 0.0
	_last_action_time = 0.0

	if action_type != "":
		_feature_idle_timers[action_type] = 0.0

## 通知功能被使用
func notify_feature_used(feature_name: String) -> void:
	_feature_idle_timers[feature_name] = 0.0

## 清除所有活动提示
func clear_all_hints() -> void:
	for hint_data in _active_hints:
		var panel: PanelContainer = hint_data.get("panel")
		if is_instance_valid(panel):
			panel.visible = false
	_active_hints.clear()

## 重置显示计数
func reset_show_counts() -> void:
	_show_counts.clear()

# ============================================================
# 内部方法
# ============================================================

func _dismiss_hint(hint_id: String) -> void:
	var to_remove: int = -1
	for i in range(_active_hints.size()):
		if _active_hints[i]["id"] == hint_id:
			to_remove = i
			break

	if to_remove < 0:
		return

	var hint_data: Dictionary = _active_hints[to_remove]
	var panel: PanelContainer = hint_data.get("panel")

	if is_instance_valid(panel):
		var viewport_size := get_viewport().get_visible_rect().size
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(panel, "position:x", viewport_size.x + 10, hint_fade_out) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(panel, "modulate:a", 0.0, hint_fade_out)
		tween.chain()
		tween.tween_callback(func():
			panel.visible = false
		)

	_active_hints.remove_at(to_remove)
	context_hint_dismissed.emit(hint_id)

func _check_idle_triggers() -> void:
	if _global_cooldown > 0.0:
		return

	for hint_id in CONTEXT_HINTS:
		var hint_def: Dictionary = CONTEXT_HINTS[hint_id]
		var trigger: String = hint_def.get("trigger", "")

		if trigger == "idle":
			var required_idle: float = hint_def.get("idle_time", 10.0)
			if _idle_timer >= required_idle:
				show_context_hint(hint_id)
				_idle_timer = 0.0
				return

		elif trigger == "idle_feature":
			var feature: String = hint_def.get("feature", "")
			var required_idle: float = hint_def.get("idle_time", 60.0)
			var feature_idle: float = _feature_idle_timers.get(feature, 0.0)
			if feature_idle >= required_idle:
				show_context_hint(hint_id)
				_feature_idle_timers[feature] = 0.0
				return

func _connect_signals() -> void:
	# 连接 GameManager 信号以追踪玩家行为
	if GameManager.has_signal("player_damaged"):
		if not GameManager.player_damaged.is_connected(_on_player_damaged):
			GameManager.player_damaged.connect(_on_player_damaged)

	if GameManager.has_signal("player_hp_changed"):
		if not GameManager.player_hp_changed.is_connected(_on_hp_changed):
			GameManager.player_hp_changed.connect(_on_hp_changed)

func _on_player_damaged(_amount: float, _source: Vector2) -> void:
	notify_player_action("combat")

func _on_hp_changed(current_hp: float, max_hp: float) -> void:
	if max_hp > 0 and current_hp / max_hp < 0.3:
		trigger_condition("low_hp")

# ============================================================
# 提示面板池
# ============================================================

func _create_hint_pool() -> void:
	for i in range(max_visible_hints + 1):
		var panel := _create_hint_panel_instance()
		panel.visible = false
		add_child(panel)
		_hint_panels.append(panel)

func _create_hint_panel_instance() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ContextHintPanel"
	panel.custom_minimum_size = Vector2(320, 50)

	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.with_alpha(PANEL_DARK, 0.92)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = UIColors.with_alpha(ACCENT_CYAN, 0.7)
	style.shadow_color = UIColors.with_alpha(ACCENT_CYAN, 0.2)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var icon := Label.new()
	icon.name = "HintIcon"
	icon.text = "💡"
	icon.add_theme_font_size_override("font_size", 18)
	hbox.add_child(icon)

	var label := Label.new()
	label.name = "HintLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 260
	label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(label)

	panel.add_child(hbox)
	return panel

func _get_available_panel() -> PanelContainer:
	for panel in _hint_panels:
		if not panel.visible:
			return panel
	return null
