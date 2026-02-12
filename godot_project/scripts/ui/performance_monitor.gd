## performance_monitor.gd
## 性能监控面板 (Issue #25)
## 显示对象池使用率、碰撞检测性能、帧率等关键指标
## 仅在 Debug 模式下显示
extends CanvasLayer

# ============================================================
# 配置
# ============================================================
@export var update_interval: float = 0.5
@export var show_in_release: bool = false

# ============================================================
# 节点引用
# ============================================================
var _label: Label = null
var _update_timer: float = 0.0
var _visible: bool = false

# ============================================================
# 缓存的引用
# ============================================================
var _pool_manager: Node = null
var _projectile_manager: Node = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 仅在 Debug 模式下启用
	if not OS.is_debug_build() and not show_in_release:
		set_process(false)
		return
	
	_create_ui()
	_find_managers()
	
	# 默认隐藏，按 F3 切换
	_visible = false
	if _label:
		_label.visible = false

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= update_interval:
		_update_timer = 0.0
		if _visible:
			_update_display()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_visible = not _visible
		if _label:
			_label.visible = _visible

# ============================================================
# UI 创建
# ============================================================

func _create_ui() -> void:
	_label = Label.new()
	_label.name = "PerfLabel"
	_label.position = Vector2(10, 10)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", UIColors.with_alpha(UIColors.SUCCESS, 0.9))
	_label.add_theme_color_override("font_shadow_color", UIColors.with_alpha(Color.BLACK, 0.7))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)

func _find_managers() -> void:
	# 延迟查找，确保其他节点已初始化
	await get_tree().process_frame
	_pool_manager = get_tree().get_first_node_in_group("pool_manager")
	_projectile_manager = get_tree().get_first_node_in_group("projectile_manager")

# ============================================================
# 显示更新
# ============================================================

func _update_display() -> void:
	if _label == null:
		return
	
	var lines: PackedStringArray = PackedStringArray()
	
	# FPS
	lines.append("=== Performance Monitor (F3) ===")
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	lines.append("Frame Time: %.1f ms" % (1000.0 / max(Engine.get_frames_per_second(), 1)))
	lines.append("")
	
	# 对象池统计
	if _pool_manager and _pool_manager.has_method("get_performance_summary"):
		var summary: Dictionary = _pool_manager.get_performance_summary()
		lines.append("=== Object Pools ===")
		lines.append("Pools: %d | Created: %d" % [summary.get("total_pools", 0), summary.get("total_objects_created", 0)])
		lines.append("Active: %d | Available: %d" % [summary.get("total_active", 0), summary.get("total_available", 0)])
		lines.append("Utilization: %.1f%%" % [summary.get("overall_utilization", 0.0) * 100.0])
		lines.append("")
		
		# 各池详情
		if _pool_manager.has_method("get_all_stats"):
			var all_stats: Dictionary = _pool_manager.get_all_stats()
			for pool_name in all_stats:
				var stats: Dictionary = all_stats[pool_name]
				lines.append("  %s: %d/%d (peak: %d)" % [
					pool_name,
					stats.get("active", 0),
					stats.get("total_created", 0),
					stats.get("peak_active", 0),
				])
		lines.append("")
	
	# 碰撞检测统计
	if _projectile_manager and _projectile_manager.has_method("get_collision_stats"):
		var col_stats: Dictionary = _projectile_manager.get_collision_stats()
		lines.append("=== Collision Detection ===")
		lines.append("Checks: %d | Candidates: %d | Hits: %d" % [
			col_stats.get("last_check_count", 0),
			col_stats.get("last_candidate_count", 0),
			col_stats.get("last_hit_count", 0),
		])
		lines.append("Avg Time: %.2f ms | Max: %.2f ms" % [
			col_stats.get("avg_frame_time_ms", 0.0),
			col_stats.get("max_frame_time_ms", 0.0),
		])
		
		var sh_stats: Dictionary = col_stats.get("spatial_hash_stats", {})
		if sh_stats.size() > 0:
			lines.append("Grid Cells: %d | Max/Cell: %d" % [
				sh_stats.get("total_cells", 0),
				sh_stats.get("max_objects_per_cell", 0),
			])
		lines.append("")
	
	# 游戏状态
	lines.append("=== Game State ===")
	lines.append("Time: %.0f s | Level: %d" % [GameManager.game_time, GameManager.player_level])
	lines.append("Enemies: %d" % get_tree().get_nodes_in_group("enemies").size())
	lines.append("Projectiles: active (see ProjectileManager)")
	
	_label.text = "\n".join(lines)
