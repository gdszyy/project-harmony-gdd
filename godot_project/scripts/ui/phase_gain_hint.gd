## phase_gain_hint.gd
## 相位增益提示面板 UI
## 切换相位时从屏幕左侧滑入的增益/减益效果面板
## 持续 2.5 秒后自动滑出
## 关联文档：Docs/UI_Design_Module6_ResonanceSlicing.md §9
extends Control

# ============================================================
# 常量
# ============================================================

## 面板宽度
const PANEL_WIDTH: float = 240.0
## 面板最大高度
const PANEL_MAX_HEIGHT: float = 200.0
## 面板圆角
const PANEL_CORNER_RADIUS: float = 4.0
## 面板背景色
const PANEL_BG := Color("#141026D9")  # 星空紫 85% 不透明
## 面板边框宽度
const BORDER_WIDTH: float = 1.5

## 动画时间
const SLIDE_IN_DURATION: float = 0.2
const DISPLAY_DURATION: float = 2.5
const SLIDE_OUT_DURATION: float = 0.2
## 快速切换时的加速滑出时间
const FAST_SLIDE_OUT: float = 0.1

## 字号
const TITLE_FONT_SIZE: int = 16
const BODY_FONT_SIZE: int = 12
const TIMBRE_BONUS_FONT_SIZE: int = 11

## 面板 Y 位置（屏幕左侧中偏上）
const PANEL_Y: float = 200.0
## 面板滑入后的 X 位置
const PANEL_X_VISIBLE: float = 20.0

# ============================================================
# 状态
# ============================================================

var _is_visible: bool = false
var _current_tween: Tween = null
var _current_phase: int = -1
var _panel_height: float = 120.0

## 面板数据缓存
var _phase_name: String = ""
var _phase_color: Color = Color.WHITE
var _modifiers: Array[Dictionary] = []
var _timbre_bonus_text: String = ""

## 辉光脉动
var _time: float = 0.0
var _beat_pulse: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 50

	# 连接信号
	var rsm := get_node_or_null("/root/ResonanceSlicingManager")
	if rsm:
		rsm.phase_changed.connect(_on_phase_changed)

	var gmm := get_node_or_null("/root/GlobalMusicManager")
	if gmm and gmm.has_signal("beat_energy_updated"):
		gmm.beat_energy_updated.connect(_on_beat_energy_updated)

func _process(delta: float) -> void:
	_time += delta
	_beat_pulse = max(0.0, _beat_pulse - delta * 3.0)

	if _is_visible:
		queue_redraw()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if not _is_visible:
		return

	var font := ThemeDB.fallback_font
	var panel_pos := Vector2(position.x, 0)  # 相对于自身
	var y_cursor: float = 12.0

	# 面板背景
	var bg_rect := Rect2(Vector2.ZERO, Vector2(PANEL_WIDTH, _panel_height))
	draw_rect(bg_rect, PANEL_BG)

	# 面板边框（发光）
	var border_color := _phase_color
	border_color.a = 0.6 + _beat_pulse * 0.3
	draw_rect(bg_rect, border_color, false, BORDER_WIDTH)

	# 相位图标 + 名称
	var icon := _get_phase_icon(_current_phase)
	var title_color := _phase_color
	draw_string(font, Vector2(12, y_cursor + TITLE_FONT_SIZE),
		icon + "  " + _phase_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FONT_SIZE, title_color)
	y_cursor += TITLE_FONT_SIZE + 10

	# 分隔线
	var sep_color := _phase_color
	sep_color.a = 0.3
	draw_line(Vector2(12, y_cursor), Vector2(PANEL_WIDTH - 12, y_cursor),
		sep_color, 0.5)
	y_cursor += 8

	# 修正项列表
	for mod in _modifiers:
		var mod_text: String = mod.get("text", "")
		var mod_color: Color = mod.get("color", Color.WHITE)
		draw_string(font, Vector2(16, y_cursor + BODY_FONT_SIZE),
			mod_text, HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_FONT_SIZE, mod_color)
		y_cursor += BODY_FONT_SIZE + 4

	# 音色增益提示（如有）
	if _timbre_bonus_text != "":
		y_cursor += 4
		draw_line(Vector2(12, y_cursor), Vector2(PANEL_WIDTH - 12, y_cursor),
			sep_color, 0.5)
		y_cursor += 8
		var bonus_color := Color("#FFD700")  # 金色
		draw_string(font, Vector2(16, y_cursor + TIMBRE_BONUS_FONT_SIZE),
			"♦ " + _timbre_bonus_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, TIMBRE_BONUS_FONT_SIZE, bonus_color)
		y_cursor += TIMBRE_BONUS_FONT_SIZE + 4

# ============================================================
# 面板显示逻辑
# ============================================================

## 显示相位增益提示
func show_phase_info(phase: int) -> void:
	# 快速连续切换处理
	if _is_visible and _current_tween:
		_current_tween.kill()
		# 快速滑出旧面板
		var fast_tween := create_tween()
		fast_tween.tween_property(self, "position:x", -PANEL_WIDTH - 10, FAST_SLIDE_OUT)\
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		fast_tween.tween_callback(func(): _show_new_panel(phase))
		return

	_show_new_panel(phase)

func _show_new_panel(phase: int) -> void:
	_current_phase = phase
	_is_visible = true
	visible = true

	# 获取相位数据
	_phase_name = ResonanceSlicingManager.PHASE_NAMES.get(phase, "UNKNOWN")
	_phase_color = ResonanceSlicingManager.PHASE_COLORS.get(phase, Color.WHITE)

	# 获取修正项
	var rsm := get_node_or_null("/root/ResonanceSlicingManager")
	if rsm and rsm.has_method("get_phase_gain_data"):
		_modifiers = rsm.get_phase_gain_data(phase)
	else:
		_modifiers = _get_fallback_modifiers(phase)

	# 检查音色增益
	_timbre_bonus_text = _check_timbre_bonus(phase)

	# 计算面板高度
	_panel_height = 12.0 + TITLE_FONT_SIZE + 18.0  # 标题 + 间距
	_panel_height += float(_modifiers.size()) * (BODY_FONT_SIZE + 4.0)
	if _timbre_bonus_text != "":
		_panel_height += 12.0 + TIMBRE_BONUS_FONT_SIZE + 4.0
	_panel_height += 12.0  # 底部边距
	_panel_height = min(_panel_height, PANEL_MAX_HEIGHT)

	# 设置尺寸
	size = Vector2(PANEL_WIDTH, _panel_height)
	position = Vector2(-PANEL_WIDTH - 10, PANEL_Y)

	# 滑入动画
	_current_tween = create_tween()
	_current_tween.tween_property(self, "position:x", PANEL_X_VISIBLE, SLIDE_IN_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_current_tween.tween_interval(DISPLAY_DURATION)
	_current_tween.tween_property(self, "position:x", -PANEL_WIDTH - 10, SLIDE_OUT_DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_current_tween.tween_callback(_on_slide_out_complete)

func _on_slide_out_complete() -> void:
	_is_visible = false
	visible = false

# ============================================================
# 信号回调
# ============================================================

func _on_phase_changed(new_phase: int) -> void:
	show_phase_info(new_phase)

func _on_beat_energy_updated(energy: float) -> void:
	_beat_pulse = clamp(energy, 0.0, 1.0)

# ============================================================
# 辅助方法
# ============================================================

func _get_phase_icon(phase: int) -> String:
	match phase:
		1: return "△"  # Overtone
		2: return "▽"  # SubBass
		_: return "◎"  # Fundamental

func _check_timbre_bonus(phase: int) -> String:
	# 检查当前装备的音色是否属于该相位的增益系别
	var gain_data: Dictionary = ResonanceSlicingManager.PHASE_TIMBRE_GAINS.get(phase, {})
	if gain_data.is_empty():
		return ""

	var gain_family: String = gain_data.get("family", "")
	if gain_family == "":
		return ""

	# 获取当前音色的系别
	var current_family := _get_current_timbre_family()
	if current_family == gain_family:
		return gain_data.get("bonus_text", "")

	return ""

func _get_current_timbre_family() -> String:
	var current_timbre: int = MusicData.ChapterTimbre.NONE
	if GameManager and "active_chapter_timbre" in GameManager:
		current_timbre = GameManager.active_chapter_timbre

	# 音色 → 系别映射
	match current_timbre:
		MusicData.ChapterTimbre.LYRE, MusicData.ChapterTimbre.HARPSICHORD:
			return "plucked"
		MusicData.ChapterTimbre.FORTEPIANO:
			return "percussion"
		MusicData.ChapterTimbre.TUTTI:
			return "bowed"
		MusicData.ChapterTimbre.ORGAN, MusicData.ChapterTimbre.SAXOPHONE:
			return "wind"
		_:
			return ""

func _get_fallback_modifiers(phase: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match phase:
		1:  # Overtone
			result.append({"text": "▲ 移速 +30%", "color": Color("#4DFFF3")})
			result.append({"text": "▲ 冲刺冷却 -50%", "color": Color("#4DFFF3")})
			result.append({"text": "▼ 受伤 +20%", "color": Color("#FF4D4D")})
		2:  # SubBass
			result.append({"text": "▲ 获得霸体", "color": Color("#FF8C42")})
			result.append({"text": "▲ 受伤 -50%", "color": Color("#FF8C42")})
			result.append({"text": "▼ 移速 -20%", "color": Color("#FF4D4D")})
			result.append({"text": "▼ 无法冲刺", "color": Color("#FF4D4D")})
		_:  # Fundamental
			result.append({"text": "◆ 无属性修正", "color": Color("#A098C8")})
			result.append({"text": "▲ 能量恢复最快", "color": Color("#4DFF80")})
	return result

# ============================================================
# 公共接口
# ============================================================

## 立即隐藏面板
func hide_panel() -> void:
	if _current_tween:
		_current_tween.kill()
	_is_visible = false
	visible = false

## 检查面板是否正在显示
func is_showing() -> bool:
	return _is_visible
