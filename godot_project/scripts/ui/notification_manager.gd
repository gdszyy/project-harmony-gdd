## notification_manager.gd — 全局通知管理器
## 管理状态提示与警告的对象池，接收来自各系统的信号
## 作为 HUD 的子节点，位于最高渲染层级 (Layer 11)
extends CanvasLayer

# ============================================================
# 配置
# ============================================================
const POOL_SIZE: int = 5
const MAX_CONCURRENT: int = 3

# ============================================================
# 状态
# ============================================================
var _pool: Array[StatusNotification] = []
var _queue: Array[Dictionary] = []

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 11
	_initialize_pool()
	_connect_signals()

func _process(_delta: float) -> void:
	# 处理队列中的通知
	if not _queue.is_empty():
		var active_count := _get_active_count()
		if active_count < MAX_CONCURRENT:
			var next: Dictionary = _queue.pop_front()
			_show_from_pool(next["text"], next["type"], next["duration"])

# ============================================================
# 对象池
# ============================================================

func _initialize_pool() -> void:
	for i in range(POOL_SIZE):
		var notification := StatusNotification.new()
		notification.set_anchors_preset(Control.PRESET_FULL_RECT)
		notification.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(notification)
		_pool.append(notification)

func _get_available() -> StatusNotification:
	for n in _pool:
		if not n.is_active():
			return n
	# 扩展池
	var notification := StatusNotification.new()
	notification.set_anchors_preset(Control.PRESET_FULL_RECT)
	notification.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notification)
	_pool.append(notification)
	return notification

func _get_active_count() -> int:
	var count := 0
	for n in _pool:
		if n.is_active():
			count += 1
	return count

func _show_from_pool(text: String, type: StatusNotification.NotificationType, duration: float) -> void:
	var n := _get_available()
	if n:
		n.reset()
		n.show_notification(text, type, duration)

# ============================================================
# 信号连接
# ============================================================

func _connect_signals() -> void:
	# 密度过载
	var density_mgr := get_node_or_null("/root/DensityManager")
	if density_mgr and density_mgr.has_signal("density_overload"):
		density_mgr.density_overload.connect(_on_density_overload)

	# 和弦进行
	var chord_mgr := get_node_or_null("/root/ChordManager")
	if chord_mgr and chord_mgr.has_signal("chord_progression_triggered"):
		chord_mgr.chord_progression_triggered.connect(_on_chord_progression)

	# 单音寂静
	var note_mgr := get_node_or_null("/root/NoteManager")
	if note_mgr and note_mgr.has_signal("note_silenced"):
		note_mgr.note_silenced.connect(_on_note_silenced)

# ============================================================
# 信号回调
# ============================================================

func _on_density_overload() -> void:
	show_warning("DENSITY OVERLOAD", StatusNotification.NotificationType.DENSITY_OVERLOAD, 2.5)

func _on_chord_progression(chord_name: String) -> void:
	show_info("CHORD PROGRESSION: %s" % chord_name, StatusNotification.NotificationType.CHORD_PROGRESSION, 2.0)

func _on_note_silenced(note_name: String) -> void:
	show_info("NOTE SILENCED: %s" % note_name, StatusNotification.NotificationType.NOTE_SILENCED, 1.5)

# ============================================================
# 公共接口
# ============================================================

## 显示警告
func show_warning(text: String, type: StatusNotification.NotificationType = StatusNotification.NotificationType.GENERIC_WARNING, duration: float = 2.0) -> void:
	if _get_active_count() >= MAX_CONCURRENT:
		_queue.append({"text": text, "type": type, "duration": duration})
	else:
		_show_from_pool(text, type, duration)

## 显示信息
func show_info(text: String, type: StatusNotification.NotificationType = StatusNotification.NotificationType.GENERIC_INFO, duration: float = 2.0) -> void:
	if _get_active_count() >= MAX_CONCURRENT:
		_queue.append({"text": text, "type": type, "duration": duration})
	else:
		_show_from_pool(text, type, duration)
