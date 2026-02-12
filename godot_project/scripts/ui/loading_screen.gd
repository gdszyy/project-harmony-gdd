## loading_screen.gd
## 章节主题加载画面 (CanvasLayer)
## 模块7：教学引导与辅助 UI
##
## 功能：
##   - 章节主题背景插画（带视差效果）
##   - 章节标题与编号显示
##   - 流动能量波进度条
##   - 循环游戏提示 (Game Tips)
##   - 加载完成时的"谐振"过渡动画
##
## 设计原则：
##   - 加载画面是章节主题的预演和氛围延续
##   - 进度条使用主强调色 #9D6FFF 的能量波填充
##   - 提示文本从内置数据读取
##   - 由 GameManager 的场景切换函数调用
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal loading_started()
signal loading_progress_updated(progress: float)
signal loading_completed()
signal transition_finished()

# ============================================================
# 主题颜色
# ============================================================
const PANEL_BG := Color("#141026")
const ACCENT_COLOR := Color("#9D6FFF")
const TEXT_PRIMARY := Color("#EAE6FF")
const TEXT_SECONDARY := Color("#A098C8")
const BG_DARK := Color("#0A0814")

# ============================================================
# 章节数据
# ============================================================
const CHAPTER_DATA: Dictionary = {
	1: {"title": "谐振之初", "subtitle": "第一乐章", "bg_color": Color("#0D0826")},
	2: {"title": "圣咏回响", "subtitle": "第二乐章", "bg_color": Color("#0A1020")},
	3: {"title": "对位迷宫", "subtitle": "第三乐章", "bg_color": Color("#100818")},
	4: {"title": "古典秩序", "subtitle": "第四乐章", "bg_color": Color("#0C0A1E")},
	5: {"title": "命运交响", "subtitle": "第五乐章", "bg_color": Color("#120A10")},
	6: {"title": "爵士即兴", "subtitle": "第六乐章", "bg_color": Color("#0A0E1A")},
	7: {"title": "数字衰变", "subtitle": "第七乐章", "bg_color": Color("#0E0608")},
}

# ============================================================
# 游戏提示
# ============================================================
const GAME_TIPS: Array = [
	"不同音符的弹幕轨迹各不相同，多尝试组合！",
	"和弦法术的威力远超单音——同时按下多个键试试。",
	"重复使用相同音符会累积听感疲劳，注意变换！",
	"黑键修饰可以强化白键法术的效果。",
	"五度圈罗盘上的每条路径都有独特的升级方向。",
	"Boss 通常有特殊的弱点机制，观察攻击节奏。",
	"在谐振法典中可以查阅已发现的音乐知识。",
	"走位是生存的关键——灵活移动躲避敌人攻击。",
	"不同章节的敌人有不同的攻击模式和弱点。",
	"共鸣碎片可以在和谐殿堂中兑换永久升级。",
	"调式切换会影响所有音符法术的属性和效果。",
	"注意听背景音乐的节拍——它与游戏机制紧密相连。",
]

# ============================================================
# 配置
# ============================================================
@export var tip_cycle_interval: float = 4.0
@export var min_display_time: float = 1.5
@export var transition_duration: float = 0.8

# ============================================================
# 内部节点
# ============================================================
var _root_container: Control = null
var _bg_rect: ColorRect = null
var _bg_parallax_rect: ColorRect = null
var _chapter_label: Label = null
var _subtitle_label: Label = null
var _progress_bar: ProgressBar = null
var _progress_label: Label = null
var _tip_label: Label = null
var _flash_rect: ColorRect = null

# ============================================================
# 内部状态
# ============================================================
var _current_progress: float = 0.0
var _target_progress: float = 0.0
var _is_loading: bool = false
var _is_transitioning: bool = false
var _tip_timer: float = 0.0
var _current_tip_index: int = 0
var _min_time_elapsed: float = 0.0
var _parallax_offset: float = 0.0
var _loading_tween: Tween = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 110  # 在所有 UI 之上
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root_container.visible = false

func _process(delta: float) -> void:
	if not _is_loading:
		return

	_min_time_elapsed += delta

	# 平滑进度条
	if _current_progress < _target_progress:
		_current_progress = move_toward(_current_progress, _target_progress, delta * 0.8)
		_progress_bar.value = _current_progress
		_progress_label.text = "%d%%" % int(_current_progress * 100)

	# 提示循环
	_tip_timer += delta
	if _tip_timer >= tip_cycle_interval:
		_tip_timer = 0.0
		_cycle_tip()

	# 背景视差
	_parallax_offset += delta * 5.0
	if _bg_parallax_rect:
		_bg_parallax_rect.position.x = sin(_parallax_offset * 0.3) * 10.0
		_bg_parallax_rect.position.y = cos(_parallax_offset * 0.2) * 5.0

# ============================================================
# 公共接口
# ============================================================

## 显示加载画面
func show_loading(chapter_number: int = 1) -> void:
	_is_loading = true
	_is_transitioning = false
	_current_progress = 0.0
	_target_progress = 0.0
	_min_time_elapsed = 0.0
	_tip_timer = 0.0
	_current_tip_index = randi() % GAME_TIPS.size()

	# 设置章节数据
	var chapter: Dictionary = CHAPTER_DATA.get(chapter_number, CHAPTER_DATA[1])
	_chapter_label.text = chapter.get("title", "未知乐章")
	_subtitle_label.text = chapter.get("subtitle", "")
	_bg_rect.color = chapter.get("bg_color", BG_DARK)

	# 设置初始提示
	_tip_label.text = GAME_TIPS[_current_tip_index]

	# 重置进度条
	_progress_bar.value = 0.0
	_progress_label.text = "0%"

	# 显示
	_root_container.visible = true
	_root_container.modulate.a = 0.0
	_flash_rect.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(_root_container, "modulate:a", 1.0, 0.4)

	# 章节标题入场动画
	_chapter_label.modulate.a = 0.0
	_chapter_label.position.y = 380
	_subtitle_label.modulate.a = 0.0

	var title_tween := create_tween()
	title_tween.tween_interval(0.3)
	title_tween.tween_property(_subtitle_label, "modulate:a", 1.0, 0.5)
	title_tween.tween_property(_chapter_label, "modulate:a", 1.0, 0.6)
	title_tween.set_parallel(true)
	title_tween.tween_property(_chapter_label, "position:y", 360, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	loading_started.emit()

## 更新加载进度 (0.0 ~ 1.0)
func update_progress(progress: float) -> void:
	_target_progress = clampf(progress, 0.0, 1.0)
	loading_progress_updated.emit(_target_progress)

## 加载完成，播放过渡动画
func finish_loading() -> void:
	_target_progress = 1.0

	# 等待最小显示时间
	var wait_time := max(min_display_time - _min_time_elapsed, 0.0)

	get_tree().create_timer(wait_time).timeout.connect(func():
		_play_transition()
	)

	loading_completed.emit()

## 立即隐藏（无动画）
func hide_immediate() -> void:
	_is_loading = false
	_is_transitioning = false
	_root_container.visible = false

# ============================================================
# 内部方法
# ============================================================

func _cycle_tip() -> void:
	# 淡出当前提示
	var tween := create_tween()
	tween.tween_property(_tip_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		_current_tip_index = (_current_tip_index + 1) % GAME_TIPS.size()
		_tip_label.text = GAME_TIPS[_current_tip_index]
	)
	tween.tween_property(_tip_label, "modulate:a", 1.0, 0.3)

func _play_transition() -> void:
	_is_transitioning = true

	# 确保进度条满
	_progress_bar.value = 1.0
	_progress_label.text = "100%"

	# 白光闪现
	_flash_rect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_flash_rect, "modulate:a", 1.0, 0.15)
	tween.tween_interval(0.1)
	tween.tween_property(_flash_rect, "modulate:a", 0.0, transition_duration)
	tween.set_parallel(true)
	tween.tween_property(_root_container, "modulate:a", 0.0, transition_duration)
	tween.chain()
	tween.tween_callback(func():
		_root_container.visible = false
		_is_loading = false
		_is_transitioning = false
		transition_finished.emit()
	)

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	_root_container = Control.new()
	_root_container.name = "LoadingScreenRoot"
	_root_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_container.mouse_filter = Control.MOUSE_FILTER_STOP

	# 背景
	_bg_rect = ColorRect.new()
	_bg_rect.name = "Background"
	_bg_rect.color = BG_DARK
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_container.add_child(_bg_rect)

	# 视差背景层
	_bg_parallax_rect = ColorRect.new()
	_bg_parallax_rect.name = "ParallaxLayer"
	_bg_parallax_rect.color = Color(ACCENT_COLOR, 0.03)
	_bg_parallax_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_parallax_rect.offset_left = -20
	_bg_parallax_rect.offset_right = 20
	_bg_parallax_rect.offset_top = -10
	_bg_parallax_rect.offset_bottom = 10
	_root_container.add_child(_bg_parallax_rect)

	# 装饰线条（顶部和底部）
	var top_line := ColorRect.new()
	top_line.color = Color(ACCENT_COLOR, 0.3)
	top_line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_line.offset_bottom = 2
	_root_container.add_child(top_line)

	var bottom_line := ColorRect.new()
	bottom_line.color = Color(ACCENT_COLOR, 0.3)
	bottom_line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_line.offset_top = -2
	_root_container.add_child(bottom_line)

	# 章节副标题（如"第一乐章"）
	_subtitle_label = Label.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.text = "第一乐章"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 20)
	_subtitle_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	_subtitle_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_subtitle_label.offset_top = -80
	_subtitle_label.offset_bottom = -50
	_subtitle_label.offset_left = -300
	_subtitle_label.offset_right = 300
	_root_container.add_child(_subtitle_label)

	# 章节标题
	_chapter_label = Label.new()
	_chapter_label.name = "ChapterLabel"
	_chapter_label.text = "谐振之初"
	_chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter_label.add_theme_font_size_override("font_size", 52)
	_chapter_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	_chapter_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_chapter_label.offset_top = -40
	_chapter_label.offset_bottom = 30
	_chapter_label.offset_left = -400
	_chapter_label.offset_right = 400
	_root_container.add_child(_chapter_label)

	# 提示文字（进度条上方）
	_tip_label = Label.new()
	_tip_label.name = "TipLabel"
	_tip_label.text = ""
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.add_theme_font_size_override("font_size", 15)
	_tip_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	_tip_label.anchor_left = 0.15
	_tip_label.anchor_right = 0.85
	_tip_label.anchor_top = 1.0
	_tip_label.anchor_bottom = 1.0
	_tip_label.offset_top = -80
	_tip_label.offset_bottom = -55
	_root_container.add_child(_tip_label)

	# 进度条
	_progress_bar = ProgressBar.new()
	_progress_bar.name = "LoadingProgressBar"
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.anchor_left = 0.2
	_progress_bar.anchor_right = 0.8
	_progress_bar.anchor_top = 1.0
	_progress_bar.anchor_bottom = 1.0
	_progress_bar.offset_top = -45
	_progress_bar.offset_bottom = -35

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(PANEL_BG, 0.6)
	bar_bg.corner_radius_top_left = 5
	bar_bg.corner_radius_top_right = 5
	bar_bg.corner_radius_bottom_left = 5
	bar_bg.corner_radius_bottom_right = 5
	_progress_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = ACCENT_COLOR
	bar_fill.corner_radius_top_left = 5
	bar_fill.corner_radius_top_right = 5
	bar_fill.corner_radius_bottom_left = 5
	bar_fill.corner_radius_bottom_right = 5
	_progress_bar.add_theme_stylebox_override("fill", bar_fill)

	_root_container.add_child(_progress_bar)

	# 进度百分比
	_progress_label = Label.new()
	_progress_label.name = "ProgressLabel"
	_progress_label.text = "0%"
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 12)
	_progress_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	_progress_label.anchor_left = 0.45
	_progress_label.anchor_right = 0.55
	_progress_label.anchor_top = 1.0
	_progress_label.anchor_bottom = 1.0
	_progress_label.offset_top = -28
	_progress_label.offset_bottom = -12
	_root_container.add_child(_progress_label)

	# 白光闪现层
	_flash_rect = ColorRect.new()
	_flash_rect.name = "FlashRect"
	_flash_rect.color = Color.WHITE
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.modulate.a = 0.0
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_container.add_child(_flash_rect)

	add_child(_root_container)
