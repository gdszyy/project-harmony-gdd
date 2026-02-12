## info_panel.gd — 信息面板 UI
## 屏幕左上角，显示 BPM / 时间 / 等级 / 敌人数量
## 低频更新（每秒一次），避免不必要的性能开销
extends Control

# ============================================================
# 配置
# ============================================================
const PANEL_SIZE := Vector2(200, 100)
const UPDATE_INTERVAL: float = 1.0

# 颜色
const COLOR_CRYSTAL_WHITE := Color(0.918, 0.902, 1.0)   # #EAE6FF
const COLOR_ACCENT        := Color(0.616, 0.435, 1.0)   # #9D6FFF
const COLOR_STARRY_PURPLE := Color(0.078, 0.063, 0.149) # #141026
const COLOR_LABEL          := Color(0.627, 0.596, 0.784) # #A098C8

# ============================================================
# 状态
# ============================================================
var _update_timer: float = 0.0
var _bpm: float = 120.0
var _elapsed_time: float = 0.0
var _player_level: int = 1
var _enemy_count: int = 0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 连接信号
	if GameManager.has_signal("level_up"):
		GameManager.level_up.connect(_on_level_up)

func _process(delta: float) -> void:
	_elapsed_time += delta
	_update_timer += delta

	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_refresh_data()
		queue_redraw()

# ============================================================
# 数据刷新
# ============================================================

func _refresh_data() -> void:
	_bpm = GameManager.current_bpm if GameManager.get("current_bpm") else 120.0
	_player_level = GameManager.player_level if GameManager.get("player_level") else 1
	_enemy_count = _get_enemy_count()

func _get_enemy_count() -> int:
	var enemies := get_tree().get_nodes_in_group("enemies")
	return enemies.size()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var font := ThemeDB.fallback_font

	# 面板背景
	var bg_rect := Rect2(Vector2.ZERO, PANEL_SIZE)
	draw_rect(bg_rect, Color(COLOR_STARRY_PURPLE, 0.8))

	# 边框
	draw_rect(bg_rect, Color(COLOR_ACCENT, 0.3), false, 1.0)

	# 数据行
	var y_start := 18.0
	var line_height := 20.0
	var label_x := 10.0
	var value_x := 90.0

	# BPM
	draw_string(font, Vector2(label_x, y_start), "BPM", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_LABEL)
	draw_string(font, Vector2(value_x, y_start), "%d" % int(_bpm), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_CRYSTAL_WHITE)

	# Time
	y_start += line_height
	var minutes := int(_elapsed_time) / 60
	var seconds := int(_elapsed_time) % 60
	draw_string(font, Vector2(label_x, y_start), "TIME", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_LABEL)
	draw_string(font, Vector2(value_x, y_start), "%02d:%02d" % [minutes, seconds], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_CRYSTAL_WHITE)

	# Level
	y_start += line_height
	draw_string(font, Vector2(label_x, y_start), "LEVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_LABEL)
	draw_string(font, Vector2(value_x, y_start), "%d" % _player_level, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_CRYSTAL_WHITE)

	# Enemies
	y_start += line_height
	draw_string(font, Vector2(label_x, y_start), "ENEMIES", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_LABEL)
	var enemy_color := COLOR_CRYSTAL_WHITE
	if _enemy_count > 20:
		enemy_color = Color(1.0, 0.133, 0.267)  # 高密度警告
	draw_string(font, Vector2(value_x, y_start), "%d" % _enemy_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, enemy_color)

# ============================================================
# 信号回调
# ============================================================

func _on_level_up(new_level: int) -> void:
	_player_level = new_level
	queue_redraw()
