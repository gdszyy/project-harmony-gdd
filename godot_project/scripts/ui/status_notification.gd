## status_notification.gd — 状态提示与警告系统
## 最高优先级临时信息，支持：密度过载警告、和弦进行提示、单音寂静灰化
## 使用 _draw() + 对象池实现
class_name StatusNotification
extends Control

# ============================================================
# 通知类型枚举
# ============================================================
enum NotificationType {
	DENSITY_OVERLOAD,    ## 密度过载警告
	CHORD_PROGRESSION,   ## 和弦进行提示
	NOTE_SILENCED,       ## 单音寂静灰化
	GENERIC_WARNING,     ## 通用警告
	GENERIC_INFO,        ## 通用信息
}

# ============================================================
# 配置
# ============================================================
const DISPLAY_DURATION: float = 2.0
const FADE_IN_DURATION: float = 0.2
const FADE_OUT_DURATION: float = 0.5

# 颜色
const COLOR_ERROR_RED      := Color(1.0, 0.133, 0.267)   # #FF2244
const COLOR_HOLY_GOLD      := Color(1.0, 0.843, 0.0)     # #FFD700
const COLOR_SECONDARY_TEXT := Color(0.627, 0.596, 0.784)  # #A098C8
const COLOR_CRYSTAL_WHITE  := Color(0.918, 0.902, 1.0)    # #EAE6FF

# ============================================================
# 状态
# ============================================================
var _is_active: bool = false
var _timer: float = 0.0
var _duration: float = DISPLAY_DURATION
var _type: NotificationType = NotificationType.GENERIC_INFO
var _text: String = ""
var _color: Color = COLOR_CRYSTAL_WHITE
var _font_size: int = 24
var _time: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _process(delta: float) -> void:
	if not _is_active:
		return

	_time += delta
	_timer += delta

	if _timer >= _duration:
		_deactivate()
		return

	queue_redraw()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if not _is_active:
		return

	var font := ThemeDB.fallback_font
	var progress := _timer / _duration
	var center := size / 2.0

	# 计算透明度
	var alpha := 1.0
	if _timer < FADE_IN_DURATION:
		alpha = _timer / FADE_IN_DURATION
	elif _timer > _duration - FADE_OUT_DURATION:
		alpha = (_duration - _timer) / FADE_OUT_DURATION

	match _type:
		NotificationType.DENSITY_OVERLOAD:
			_draw_density_overload(font, center, alpha)
		NotificationType.CHORD_PROGRESSION:
			_draw_chord_progression(font, center, alpha, progress)
		NotificationType.NOTE_SILENCED:
			_draw_note_silenced(font, center, alpha)
		_:
			_draw_generic(font, center, alpha)

## 密度过载警告 — 故障艺术字体 + 红色闪烁 + 震动
func _draw_density_overload(font: Font, center: Vector2, alpha: float) -> void:
	# 全屏红色闪烁背景
	var flash_alpha := sin(_time * 12.0) * 0.1 + 0.05
	draw_rect(Rect2(Vector2.ZERO, size), Color(COLOR_ERROR_RED, flash_alpha * alpha))

	# 文字震动
	var shake_x := sin(_time * 30.0) * 3.0 * alpha
	var shake_y := cos(_time * 25.0) * 2.0 * alpha
	var text_pos := center + Vector2(shake_x - 80, shake_y + 10)

	# 故障效果：色彩通道偏移
	var ca_offset := 2.0 * alpha
	draw_string(font, text_pos + Vector2(ca_offset, 0), _text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color(1.0, 0.0, 0.0, alpha * 0.5))
	draw_string(font, text_pos + Vector2(-ca_offset, 0), _text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color(0.0, 0.0, 1.0, alpha * 0.3))

	# 主文字
	draw_string(font, text_pos, _text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color(COLOR_ERROR_RED, alpha))

	# 像素化故障块
	var block_count := 5
	for i in range(block_count):
		var bx := center.x + sin(float(i) * 73.1 + _time * 20.0) * 100.0
		var by := center.y + cos(float(i) * 37.7 + _time * 15.0) * 20.0
		var bw := 10.0 + abs(sin(float(i) * 17.3 + _time * 10.0)) * 30.0
		var bh := 3.0 + abs(cos(float(i) * 23.1)) * 5.0
		draw_rect(Rect2(Vector2(bx, by), Vector2(bw, bh)), Color(COLOR_ERROR_RED, alpha * 0.4))

## 和弦进行提示 — 圣光金 + 放大出现 + 光点消散
func _draw_chord_progression(font: Font, center: Vector2, alpha: float, progress: float) -> void:
	# 放大效果
	var scale_factor := 1.0
	if progress < 0.15:
		scale_factor = 0.5 + (progress / 0.15) * 0.5
	elif progress > 0.7:
		scale_factor = 1.0 - (progress - 0.7) / 0.3 * 0.3

	var text_pos := center + Vector2(-100, 10)

	# 辉光
	var glow_alpha := alpha * 0.3 * scale_factor
	draw_string(font, text_pos + Vector2(-1, -1), _text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, int(22 * scale_factor), Color(COLOR_HOLY_GOLD, glow_alpha))
	draw_string(font, text_pos + Vector2(1, 1), _text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, int(22 * scale_factor), Color(COLOR_HOLY_GOLD, glow_alpha))

	# 主文字
	draw_string(font, text_pos, _text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, int(22 * scale_factor), Color(COLOR_HOLY_GOLD, alpha))

	# 光点消散 (后半段)
	if progress > 0.5:
		var particle_progress := (progress - 0.5) / 0.5
		for i in range(8):
			var angle := (TAU / 8.0) * float(i)
			var dist := particle_progress * 60.0
			var px := center.x + cos(angle) * dist
			var py := center.y + sin(angle) * dist
			var p_alpha := (1.0 - particle_progress) * alpha * 0.6
			draw_circle(Vector2(px, py), 3.0 * (1.0 - particle_progress), Color(COLOR_HOLY_GOLD, p_alpha))

## 单音寂静灰化 — 屏幕下方淡入淡出
func _draw_note_silenced(font: Font, center: Vector2, alpha: float) -> void:
	# 位于屏幕下方
	var text_pos := Vector2(center.x - 60, size.y * 0.8)

	# 灰化图标
	var icon_rect := Rect2(text_pos + Vector2(-20, -14), Vector2(16, 16))
	draw_rect(icon_rect, Color(0.3, 0.3, 0.3, alpha))

	# 文字
	draw_string(font, text_pos, _text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(COLOR_SECONDARY_TEXT, alpha))

## 通用提示
func _draw_generic(font: Font, center: Vector2, alpha: float) -> void:
	var text_pos := center + Vector2(-80, 10)
	draw_string(font, text_pos, _text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, _font_size, Color(_color, alpha))

# ============================================================
# 公共接口
# ============================================================

## 显示通知
func show_notification(text: String, type: NotificationType, duration: float = DISPLAY_DURATION) -> void:
	_is_active = true
	_timer = 0.0
	_time = 0.0
	_text = text
	_type = type
	_duration = duration
	visible = true

	match type:
		NotificationType.DENSITY_OVERLOAD:
			_color = COLOR_ERROR_RED
			_font_size = 28
		NotificationType.CHORD_PROGRESSION:
			_color = COLOR_HOLY_GOLD
			_font_size = 22
		NotificationType.NOTE_SILENCED:
			_color = COLOR_SECONDARY_TEXT
			_font_size = 16
		_:
			_color = COLOR_CRYSTAL_WHITE
			_font_size = 20

func _deactivate() -> void:
	_is_active = false
	visible = false

func is_active() -> bool:
	return _is_active

func reset() -> void:
	_is_active = false
	_timer = 0.0
	_text = ""
	visible = false
