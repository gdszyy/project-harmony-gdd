## mutator_hud.gd
## 变异器 HUD 显示组件
## Issue #115: 在游戏 HUD 中显示当前活跃的变异器
##
## 功能：
##   - 在屏幕右上角显示当前活跃的变异器图标和名称
##   - 鼠标悬停显示详细描述
##   - 变异器激活/停用时有动画效果
extends CanvasLayer

# ============================================================
# 内部状态
# ============================================================
var _container: VBoxContainer = null
var _mutator_entries: Dictionary = {}  ## mutator_id → Control

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 11  # 在 HUD 之上
	_setup_ui()
	_connect_signals()

# ============================================================
# UI 构建
# ============================================================

func _setup_ui() -> void:
	_container = VBoxContainer.new()
	_container.name = "MutatorContainer"
	_container.anchor_left = 1.0
	_container.anchor_right = 1.0
	_container.anchor_top = 0.0
	_container.anchor_bottom = 0.0
	_container.offset_left = -220
	_container.offset_right = -10
	_container.offset_top = 10
	_container.offset_bottom = 300
	_container.add_theme_constant_override("separation", 4)
	add_child(_container)

	# 标题
	var title := Label.new()
	title.name = "MutatorTitle"
	title.text = "变异器"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", UIColors.with_alpha(UIColors.TEXT_DIM, 0.8))
	_container.add_child(title)

# ============================================================
# 信号连接
# ============================================================

func _connect_signals() -> void:
	var mutator_mgr := get_node_or_null("/root/MutatorManager")
	if mutator_mgr:
		if mutator_mgr.has_signal("mutator_activated"):
			mutator_mgr.mutator_activated.connect(_on_mutator_activated)
		if mutator_mgr.has_signal("mutator_deactivated"):
			mutator_mgr.mutator_deactivated.connect(_on_mutator_deactivated)
		if mutator_mgr.has_signal("all_mutators_cleared"):
			mutator_mgr.all_mutators_cleared.connect(_on_all_cleared)

# ============================================================
# 变异器条目管理
# ============================================================

func _on_mutator_activated(mutator_id: String) -> void:
	var mutator_mgr := get_node_or_null("/root/MutatorManager")
	if mutator_mgr == null:
		return

	var info: Dictionary = mutator_mgr.get_mutator_info(mutator_id)
	if info.is_empty():
		return

	# 创建条目
	var entry := HBoxContainer.new()
	entry.name = "Mutator_%s" % mutator_id
	entry.add_theme_constant_override("separation", 6)

	# 图标
	var icon := Label.new()
	icon.text = info.get("icon", "?")
	icon.add_theme_font_size_override("font_size", 16)
	entry.add_child(icon)

	# 名称
	var name_label := Label.new()
	name_label.text = info.get("name", mutator_id)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", info.get("color", Color.WHITE))
	entry.add_child(name_label)

	_container.add_child(entry)
	_mutator_entries[mutator_id] = entry

	# 淡入动画
	entry.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(entry, "modulate:a", 1.0, 0.5)

func _on_mutator_deactivated(mutator_id: String) -> void:
	if _mutator_entries.has(mutator_id):
		var entry: Control = _mutator_entries[mutator_id]
		var tween := create_tween()
		tween.tween_property(entry, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func():
			entry.queue_free()
			_mutator_entries.erase(mutator_id)
		)

func _on_all_cleared() -> void:
	for mutator_id in _mutator_entries:
		var entry: Control = _mutator_entries[mutator_id]
		entry.queue_free()
	_mutator_entries.clear()
