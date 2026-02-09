## note_inventory_ui.gd
## 音符库存 HUD 显示
## 在游戏界面中显示玩家当前持有的音符数量
## 紧凑的横向条形式，显示7个白键音符的图标和数量
extends Control

# ============================================================
# 常量
# ============================================================
const CELL_SIZE := Vector2(32, 32)
const CELL_MARGIN := 4.0
const BG_COLOR := Color(0.04, 0.03, 0.08, 0.85)
const CELL_BG_COLOR := Color(0.08, 0.06, 0.14, 0.6)
const COUNT_COLOR := Color(0.8, 0.8, 0.9, 0.9)
const LABEL_COLOR := Color(0.5, 0.45, 0.6, 0.7)

## 获得音符时的闪烁效果
const FLASH_DURATION: float = 0.5

# ============================================================
# 状态
# ============================================================
var _flash_timers: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 计算最小尺寸
	var total_width := 7 * (CELL_SIZE.x + CELL_MARGIN) + 10.0
	custom_minimum_size = Vector2(total_width, CELL_SIZE.y + 30.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 连接信号
	NoteInventory.note_acquired.connect(_on_note_acquired)

func _process(delta: float) -> void:
	# 更新闪烁计时器
	var needs_redraw := false
	for i in range(7):
		if _flash_timers[i] > 0:
			_flash_timers[i] -= delta
			needs_redraw = true
	if needs_redraw:
		queue_redraw()
	else:
		# 每秒刷新一次即可
		if Engine.get_frames_drawn() % 30 == 0:
			queue_redraw()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var font := ThemeDB.fallback_font

	# 背景
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)

	# 标题
	draw_string(font, Vector2(6, 12), "NOTES", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, LABEL_COLOR)

	# 音符格子
	var start_x := 6.0
	var start_y := 18.0

	for i in range(7):
		var note_key: int = i
		var count: int = NoteInventory.get_note_count(note_key)
		var note_color: Color = MusicData.NOTE_COLORS.get(note_key, Color(0.5, 0.5, 0.5))
		var cell_x := start_x + i * (CELL_SIZE.x + CELL_MARGIN)
		var cell_rect := Rect2(Vector2(cell_x, start_y), CELL_SIZE)

		# 格子背景
		var bg := CELL_BG_COLOR
		if _flash_timers[i] > 0:
			# 闪烁效果
			var flash_alpha := _flash_timers[i] / FLASH_DURATION
			bg = bg.lerp(note_color * 0.4, flash_alpha)
		draw_rect(cell_rect, bg)

		# 边框
		var border_color := note_color
		border_color.a = 0.4 if count > 0 else 0.15
		draw_rect(cell_rect, border_color, false, 1.0)

		# 音符名称
		var name_color := note_color if count > 0 else Color(0.3, 0.3, 0.3, 0.5)
		var note_name: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
		draw_string(font, cell_rect.position + Vector2(cell_rect.size.x / 2.0 - 5, cell_rect.size.y / 2.0 + 2),
			note_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, name_color)

		# 数量
		var count_color := COUNT_COLOR if count > 0 else Color(0.4, 0.4, 0.4, 0.5)
		draw_string(font, cell_rect.position + Vector2(cell_rect.size.x / 2.0 - 4, cell_rect.size.y + 12),
			"%d" % count, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, count_color)

# ============================================================
# 信号回调
# ============================================================

func _on_note_acquired(note_key: int, _amount: int, _source: String) -> void:
	if note_key >= 0 and note_key < 7:
		_flash_timers[note_key] = FLASH_DURATION
	queue_redraw()
