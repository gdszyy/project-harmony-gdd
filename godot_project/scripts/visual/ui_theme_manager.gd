## ui_theme_manager.gd
## UI 主题管理器
##
## 职责：
## 1. 根据章节切换动态更新 UI 主题颜色
## 2. 管理 UI 元素的发光边缘效果
## 3. 实现 UI 元素的节拍脉冲响应
## 4. 提供章节特色的 UI 风格变体
extends Node

# ============================================================
# 章节 UI 色彩方案
# ============================================================
const CHAPTER_UI_COLORS: Dictionary = {
	0: {  # 毕达哥拉斯
		"border": Color(0.9, 0.85, 0.6, 0.6),
		"glow": Color(1.0, 0.95, 0.7, 0.15),
		"accent": Color(1.0, 0.95, 0.7, 1.0),
		"text": Color(0.9, 0.88, 0.75, 1.0),
	},
	1: {  # 中世纪
		"border": Color(0.6, 0.3, 0.8, 0.6),
		"glow": Color(0.9, 0.7, 1.0, 0.15),
		"accent": Color(0.9, 0.7, 1.0, 1.0),
		"text": Color(0.85, 0.75, 0.95, 1.0),
	},
	2: {  # 巴洛克
		"border": Color(0.7, 0.5, 0.2, 0.6),
		"glow": Color(1.0, 0.8, 0.3, 0.15),
		"accent": Color(1.0, 0.8, 0.3, 1.0),
		"text": Color(0.9, 0.8, 0.6, 1.0),
	},
	3: {  # 洛可可
		"border": Color(0.9, 0.7, 0.8, 0.6),
		"glow": Color(1.0, 0.85, 0.9, 0.15),
		"accent": Color(1.0, 0.85, 0.9, 1.0),
		"text": Color(0.95, 0.85, 0.9, 1.0),
	},
	4: {  # 浪漫主义
		"border": Color(0.5, 0.1, 0.2, 0.6),
		"glow": Color(0.8, 0.3, 0.4, 0.15),
		"accent": Color(0.8, 0.3, 0.4, 1.0),
		"text": Color(0.85, 0.7, 0.75, 1.0),
	},
	5: {  # 爵士
		"border": Color(0.8, 0.5, 0.1, 0.6),
		"glow": Color(0.0, 0.8, 1.0, 0.15),
		"accent": Color(0.0, 0.8, 1.0, 1.0),
		"text": Color(0.8, 0.75, 0.65, 1.0),
	},
	6: {  # 数字
		"border": Color(0.0, 1.0, 0.3, 0.6),
		"glow": Color(1.0, 0.0, 0.5, 0.15),
		"accent": Color(0.0, 1.0, 0.3, 1.0),
		"text": Color(0.7, 0.9, 0.75, 1.0),
	},
}

# 默认（非章节状态）
const DEFAULT_UI_COLORS: Dictionary = {
	"border": Color(0, 0.8, 0.6, 0.5),
	"glow": Color(0, 0.8, 0.6, 0.1),
	"accent": Color(0, 1.0, 0.83, 1.0),
	"text": Color(0.7, 0.8, 0.75, 1.0),
}

# ============================================================
# 状态
# ============================================================
var _current_colors: Dictionary = DEFAULT_UI_COLORS.duplicate()
var _target_colors: Dictionary = DEFAULT_UI_COLORS.duplicate()
var _transition_progress: float = 1.0
var _transition_duration: float = 2.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_connect_signals()

func _process(delta: float) -> void:
	if _transition_progress < 1.0:
		_transition_progress += delta / _transition_duration
		_transition_progress = minf(_transition_progress, 1.0)
		_interpolate_colors()

# ============================================================
# 信号连接
# ============================================================

func _connect_signals() -> void:
	var cm = get_node_or_null("/root/ChapterManager")
	if cm and cm.has_signal("chapter_started"):
		cm.chapter_started.connect(_on_chapter_started)

func _on_chapter_started(chapter: int, _chapter_name: String) -> void:
	_target_colors = CHAPTER_UI_COLORS.get(chapter, DEFAULT_UI_COLORS).duplicate()
	_transition_progress = 0.0

# ============================================================
# 颜色插值
# ============================================================

func _interpolate_colors() -> void:
	var t := _ease_in_out(_transition_progress)
	for key in _current_colors.keys():
		if _target_colors.has(key):
			_current_colors[key] = _current_colors[key].lerp(_target_colors[key], t)

func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

# ============================================================
# 公共接口
# ============================================================

## 获取当前 UI 颜色方案
func get_current_colors() -> Dictionary:
	return _current_colors

## 获取特定颜色
func get_border_color() -> Color:
	return _current_colors.get("border", DEFAULT_UI_COLORS["border"])

func get_glow_color() -> Color:
	return _current_colors.get("glow", DEFAULT_UI_COLORS["glow"])

func get_accent_color() -> Color:
	return _current_colors.get("accent", DEFAULT_UI_COLORS["accent"])

func get_text_color() -> Color:
	return _current_colors.get("text", DEFAULT_UI_COLORS["text"])

## 手动设置章节（用于测试）
func force_chapter_colors(chapter: int) -> void:
	_on_chapter_started(chapter, "")
