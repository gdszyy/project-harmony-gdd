## fatigue_meter.gd
## 听感疲劳度仪表 UI
## 显示 AFI 值、各维度分量、疲劳等级
extends Control

# ============================================================
# 配置
# ============================================================
const METER_WIDTH := 200.0
const METER_HEIGHT := 16.0
const COMPONENT_HEIGHT := 4.0
const COMPONENT_GAP := 2.0

## 疲劳等级颜色
const LEVEL_COLORS := {
	MusicData.FatigueLevel.NONE: Color(0.0, 0.8, 0.4),
	MusicData.FatigueLevel.MILD: Color(0.8, 0.8, 0.0),
	MusicData.FatigueLevel.MODERATE: Color(1.0, 0.5, 0.0),
	MusicData.FatigueLevel.SEVERE: Color(1.0, 0.2, 0.0),
	MusicData.FatigueLevel.CRITICAL: Color(0.8, 0.0, 0.2),
}

const LEVEL_NAMES := {
	MusicData.FatigueLevel.NONE: "CLEAR",
	MusicData.FatigueLevel.MILD: "MILD",
	MusicData.FatigueLevel.MODERATE: "MODERATE",
	MusicData.FatigueLevel.SEVERE: "SEVERE",
	MusicData.FatigueLevel.CRITICAL: "OVERLOAD",
}

# ============================================================
# 状态
# ============================================================
var _afi: float = 0.0
var _display_afi: float = 0.0
var _level: MusicData.FatigueLevel = MusicData.FatigueLevel.NONE
var _components: Dictionary = {}
var _time: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	custom_minimum_size = Vector2(METER_WIDTH + 20, 100)
	FatigueManager.fatigue_updated.connect(_on_fatigue_updated)
	FatigueManager.fatigue_level_changed.connect(_on_level_changed)

func _process(delta: float) -> void:
	_time += delta
	_display_afi = lerp(_display_afi, _afi, delta * 8.0)
	queue_redraw()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var start := Vector2(10, 10)
	var font := ThemeDB.fallback_font

	# 标题
	draw_string(font, start, "FATIGUE INDEX", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.5, 0.6))
	start.y += 14

	# 主仪表条
	var bar_rect := Rect2(start, Vector2(METER_WIDTH, METER_HEIGHT))
	draw_rect(bar_rect, Color(0.1, 0.1, 0.15, 0.6))

	var fill_width := METER_WIDTH * _display_afi
	var fill_color: Color = LEVEL_COLORS.get(_level, Color.GREEN)

	# 闪烁效果（高疲劳时）
	if _level >= MusicData.FatigueLevel.SEVERE:
		fill_color.a = 0.7 + sin(_time * 6.0) * 0.3

	draw_rect(Rect2(start, Vector2(fill_width, METER_HEIGHT)), fill_color)

	# 阈值标记
	for threshold_level in FatigueManager.thresholds:
		var threshold: float = FatigueManager.thresholds[threshold_level]
		var mark_x := start.x + METER_WIDTH * threshold
		draw_line(
			Vector2(mark_x, start.y),
			Vector2(mark_x, start.y + METER_HEIGHT),
			Color(1, 1, 1, 0.3), 1.0
		)

	# AFI 数值和等级名称
	var afi_text := "%.0f%%" % (_display_afi * 100)
	var level_name: String = LEVEL_NAMES.get(_level, "CLEAR")
	draw_string(font, Vector2(start.x + METER_WIDTH + 5, start.y + 12), afi_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, fill_color)
	draw_string(font, Vector2(start.x, start.y + METER_HEIGHT + 12), level_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, fill_color)

	# 维度分量条
	start.y += METER_HEIGHT + 20
	var component_names := {
		"pitch": "Pitch",
		"transition": "Trans",
		"rhythm": "Rhythm",
		"density": "Density",
		"rest": "Rest",
		"sustained": "Press",
	}

	for key in component_names:
		var value: float = _components.get(key, 0.0)
		var comp_rect := Rect2(start, Vector2(METER_WIDTH * 0.6, COMPONENT_HEIGHT))

		draw_rect(comp_rect, Color(0.1, 0.1, 0.15, 0.4))
		var comp_color := Color(0.0, 0.8, 0.4) if value < 0.5 else Color(1.0, 0.5, 0.0)
		if value > 0.7:
			comp_color = Color(1.0, 0.2, 0.0)
		draw_rect(Rect2(start, Vector2(METER_WIDTH * 0.6 * value, COMPONENT_HEIGHT)), comp_color)

		draw_string(font, Vector2(start.x + METER_WIDTH * 0.6 + 5, start.y + COMPONENT_HEIGHT), component_names[key], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.4, 0.4, 0.5))

		start.y += COMPONENT_HEIGHT + COMPONENT_GAP

# ============================================================
# 信号回调
# ============================================================

func _on_fatigue_updated(result: Dictionary) -> void:
	_afi = result.get("afi", 0.0)
	_components = result.get("components", {})

func _on_level_changed(level: MusicData.FatigueLevel) -> void:
	_level = level
