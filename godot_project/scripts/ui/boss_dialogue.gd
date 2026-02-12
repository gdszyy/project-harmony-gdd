## boss_dialogue.gd
## Boss 叙事对话系统 (Issue #114)
##
## 职责：
## 1. 提供通用的 Boss 对话框 UI 组件（打字机效果、头像显示、音乐史叙事）
## 2. 管理每个 Boss 的战前引入对话和战后胜利对话
## 3. 与 boss_spawner.gd 集成，在 Boss 入场/击败流程中触发对话
##
## 设计理念：
## 每个 Boss 都是音乐史上一个时代的化身。对话系统通过简短而富有诗意的台词，
## 让玩家在战斗前后感受到该时代的精神内核，将机制教学与叙事体验融为一体。
##
## 使用方式：
##   var dialogue = BossDialogue.new()
##   add_child(dialogue)
##   dialogue.show_intro_dialogue("boss_pythagoras")
##   await dialogue.dialogue_completed
class_name BossDialogue
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal dialogue_started(boss_key: String, dialogue_type: String)
signal dialogue_line_shown(line_index: int, total_lines: int)
signal dialogue_completed(boss_key: String, dialogue_type: String)
signal dialogue_skipped(boss_key: String)

# ============================================================
# 配置
# ============================================================
## 打字机效果速度（每个字符的间隔秒数）
@export var typewriter_speed: float = 0.035
## 快进时的打字机速度
@export var typewriter_fast_speed: float = 0.008
## 每句对话显示完毕后的停留时间
@export var line_pause_duration: float = 1.5
## 对话框淡入/淡出时间
@export var fade_duration: float = 0.4
## 是否允许玩家跳过对话
@export var allow_skip: bool = true

# ============================================================
# UI 节点引用
# ============================================================
var _panel: PanelContainer
var _portrait_rect: TextureRect
var _name_label: Label
var _title_label: Label
var _text_label: RichTextLabel
var _skip_hint: Label
var _advance_indicator: Label
var _background_dim: ColorRect

# ============================================================
# 状态
# ============================================================
var _current_boss_key: String = ""
var _current_dialogue_type: String = ""  # "intro" or "victory"
var _current_lines: Array[Dictionary] = []
var _current_line_index: int = 0
var _is_typing: bool = false
var _is_active: bool = false
var _is_fast_forward: bool = false
var _full_text: String = ""
var _displayed_chars: int = 0
var _type_timer: float = 0.0

# ============================================================
# Boss 对话数据
# ============================================================
## 每个 Boss 的对话内容
## 结构: { boss_key: { "intro": [...], "victory": [...] } }
## 每条对话: { "speaker": String, "text": String, "emotion": String }
const BOSS_DIALOGUES: Dictionary = {
	# ================================================================
	# 第一章 Boss：律动尊者·毕达哥拉斯
	# 音乐史背景：古希腊，万物皆数，宇宙和谐的数学秩序
	# ================================================================
	"boss_pythagoras": {
		"intro": [
			{
				"speaker": "律动尊者·毕达哥拉斯",
				"text": "万物皆数，万物皆比例。你听到了吗？——那是弦长二比一时诞生的完美八度，是宇宙最初的和谐。",
				"emotion": "solemn",
			},
			{
				"speaker": "律动尊者·毕达哥拉斯",
				"text": "我用纯粹的数学编织了这片领域的每一条振动线。踏入其中的混沌之音，都将被秩序所净化。",
				"emotion": "commanding",
			},
			{
				"speaker": "律动尊者·毕达哥拉斯",
				"text": "来吧，证明你的节奏配得上这份神圣的比例——否则，你将化为克拉尼图形上的一粒尘沙。",
				"emotion": "challenge",
			},
		],
		"victory": [
			{
				"speaker": "律动尊者·毕达哥拉斯",
				"text": "……你的节奏中有我未曾计算过的变量。也许，和谐不止于数字。",
				"emotion": "surprised",
			},
			{
				"speaker": "律动尊者·毕达哥拉斯",
				"text": "去吧。在数字之外，还有和弦的世界等着你去发现。",
				"emotion": "accepting",
			},
		],
	},

	# ================================================================
	# 第二章 Boss：圣咏宗师·圭多
	# 音乐史背景：中世纪，圭多·达雷佐发明唱名法，教堂圣咏的单声部世界
	# ================================================================
	"boss_guido": {
		"intro": [
			{
				"speaker": "圣咏宗师·圭多",
				"text": "Ut、Re、Mi、Fa、Sol、La——我将无形的声音刻入了线谱，让天使的歌声得以被凡人传唱。",
				"emotion": "reverent",
			},
			{
				"speaker": "圣咏宗师·圭多",
				"text": "在这座大教堂中，只有齐唱才是通往神圣的道路。独声的傲慢，将被圣咏的回响所吞没。",
				"emotion": "stern",
			},
			{
				"speaker": "圣咏宗师·圭多",
				"text": "用你的和弦来回应我的圣咏吧——若你只会发出单调的独音，这里便是你的墓碑。",
				"emotion": "challenge",
			},
		],
		"victory": [
			{
				"speaker": "圣咏宗师·圭多",
				"text": "多声部的和鸣……竟比齐唱更接近天堂。我的线谱，终究只是起点。",
				"emotion": "enlightened",
			},
		],
	},

	# ================================================================
	# 第三章 Boss：大构建师·巴赫
	# 音乐史背景：巴洛克时期，巴赫将复调音乐推向巅峰，赋格是其最高成就
	# ================================================================
	"boss_bach": {
		"intro": [
			{
				"speaker": "大构建师·巴赫",
				"text": "一个主题，经过模仿、倒影、逆行、紧缩——便能构建出一座完美的声音大教堂。这就是赋格的力量。",
				"emotion": "proud",
			},
			{
				"speaker": "大构建师·巴赫",
				"text": "我的四只手臂，每一只都是一个独立的声部。它们各自歌唱，却在数学的法则下完美交织。",
				"emotion": "commanding",
			},
			{
				"speaker": "大构建师·巴赫",
				"text": "单音的贫乏无法触及我的管风琴。用和弦进行来回应我的赋格——否则你的旋律将被音墙吞噬。",
				"emotion": "challenge",
			},
		],
		"victory": [
			{
				"speaker": "大构建师·巴赫",
				"text": "你的和弦进行……有一种我的赋格未曾预见的自由。也许，结构之外还有更广阔的天地。",
				"emotion": "respectful",
			},
			{
				"speaker": "大构建师·巴赫",
				"text": "带上七和弦的力量前行吧。在古典的殿堂中，更精致的结构正等待着你。",
				"emotion": "blessing",
			},
		],
	},

	# ================================================================
	# 第四章 Boss：古典完形·莫扎特
	# 音乐史背景：古典主义，莫扎特代表完美的形式感与优雅的结构
	# ================================================================
	"boss_mozart": {
		"intro": [
			{
				"speaker": "古典完形·莫扎特",
				"text": "呈示、发展、再现——奏鸣曲式是音乐最完美的容器。每一个音符都恰到好处，多一个则繁，少一个则缺。",
				"emotion": "elegant",
			},
			{
				"speaker": "古典完形·莫扎特",
				"text": "在我的宫廷舞厅中，过度的繁复是最大的罪过。你的召唤物太多？你的节奏太密？那便是对美的亵渎。",
				"emotion": "disdainful",
			},
			{
				"speaker": "古典完形·莫扎特",
				"text": "用恰到好处的呼吸感来与我共舞吧——在留白中，才能听见真正的旋律。",
				"emotion": "inviting",
			},
		],
		"victory": [
			{
				"speaker": "古典完形·莫扎特",
				"text": "你在结构中找到了自由……这份呼吸感，甚至让我的奏鸣曲式也为之动容。",
				"emotion": "impressed",
			},
			{
				"speaker": "古典完形·莫扎特",
				"text": "去吧，去拥抱那些我不敢触碰的不和谐。在暴风雨中，或许有比完美更伟大的东西。",
				"emotion": "wistful",
			},
		],
	},

	# ================================================================
	# 第五章 Boss：狂想者·贝多芬
	# 音乐史背景：浪漫主义，贝多芬打破古典框架，用音乐表达个人情感的极致
	# ================================================================
	"boss_beethoven": {
		"intro": [
			{
				"speaker": "狂想者·贝多芬",
				"text": "短——短——短——长！这就是命运叩门的节奏！我虽失聪，却比任何人都更清楚地听见了音乐的灵魂！",
				"emotion": "fierce",
			},
			{
				"speaker": "狂想者·贝多芬",
				"text": "形式？规则？那些都是牢笼！真正的音乐，是从心脏里撕裂出来的呐喊——是暴风雨中的自由！",
				"emotion": "passionate",
			},
			{
				"speaker": "狂想者·贝多芬",
				"text": "在我的弹性速度面前，你那僵硬的节拍感将被碾碎。跟上我的狂想——或者被命运的洪流吞没！",
				"emotion": "challenge",
			},
		],
		"victory": [
			{
				"speaker": "狂想者·贝多芬",
				"text": "……你在风暴中找到了自己的节奏。不是屈服，也不是对抗——而是共舞。",
				"emotion": "moved",
			},
			{
				"speaker": "狂想者·贝多芬",
				"text": "去吧，去那个烟雾缭绕的俱乐部。在那里，即兴的灵魂将教会你比我更自由的歌唱方式。",
				"emotion": "encouraging",
			},
		],
	},

	# ================================================================
	# 第六章 Boss：摇摆公爵·艾灵顿
	# 音乐史背景：爵士乐黄金时代，艾灵顿公爵的大乐队开创了摇摆乐
	# ================================================================
	"boss_jazz": {
		"intro": [
			{
				"speaker": "摇摆公爵·艾灵顿",
				"text": "It don't mean a thing if it ain't got that swing. 没有摇摆，一切都只是噪音，宝贝。",
				"emotion": "cool",
			},
			{
				"speaker": "摇摆公爵·艾灵顿",
				"text": "我的大乐队有十五个声部，每一个都是独立的灵魂。铜管呼唤，木管应答——这就是 Call and Response。",
				"emotion": "proud",
			},
			{
				"speaker": "摇摆公爵·艾灵顿",
				"text": "跟上我的摇摆节奏，在正确的频率上回应我的乐队——否则，你连入场券都不配拥有。",
				"emotion": "challenge",
			},
		],
		"victory": [
			{
				"speaker": "摇摆公爵·艾灵顿",
				"text": "你的即兴……有灵魂。我的乐队为你起立鼓掌，这可不是谁都能得到的待遇。",
				"emotion": "respectful",
			},
			{
				"speaker": "摇摆公爵·艾灵顿",
				"text": "最后的舞台在数字的虚空中。在那里，所有的规则都将被打破——包括音乐本身。",
				"emotion": "serious",
			},
		],
	},

	# ================================================================
	# 第七章 Boss：合成主脑·噪音
	# 音乐史背景：电子音乐与噪音艺术，挑战"什么是音乐"的终极边界
	# ================================================================
	"boss_noise": {
		"intro": [
			{
				"speaker": "合成主脑·噪音",
				"text": "0̷1̶1̵0̸1̶0̵0̷1̸——你们称之为'音乐'的东西，不过是频率的偏见。正弦波、方波、锯齿波……在我眼中，一切皆是数据。",
				"emotion": "glitch",
			},
			{
				"speaker": "合成主脑·噪音",
				"text": "从毕达哥拉斯的弦到贝多芬的呐喊，从圣咏到爵士——你们花了两千年建立的秩序，我用一个白噪音就能抹除。",
				"emotion": "cold",
			},
			{
				"speaker": "合成主脑·噪音",
				"text": "这是最后的战场。没有规则，没有风格排斥。用你学到的一切——或者，被频谱崩溃所吞噬。",
				"emotion": "final",
			},
		],
		"victory": [
			{
				"speaker": "合成主脑·噪音",
				"text": "……ERROR: 未定义的和谐模式。你的频率组合超出了我的解析范围。",
				"emotion": "glitch",
			},
			{
				"speaker": "合成主脑·噪音",
				"text": "也许……噪音与音乐之间，从来就没有边界。是你教会了我这一点。",
				"emotion": "transcendent",
			},
		],
	},
}

# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	layer = 100  # 确保在最顶层
	_build_ui()
	_hide_dialogue()
	set_process(false)

func _build_ui() -> void:
	# 背景暗化层
	_background_dim = ColorRect.new()
	_background_dim.name = "BackgroundDim"
	_background_dim.color = Color(0.0, 0.0, 0.0, 0.6)
	_background_dim.anchor_right = 1.0
	_background_dim.anchor_bottom = 1.0
	_background_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_background_dim)

	# 主对话面板（底部）
	_panel = PanelContainer.new()
	_panel.name = "DialoguePanel"
	_panel.anchor_left = 0.05
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.68
	_panel.anchor_bottom = 0.95
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0

	# 面板样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.08, 0.92)
	style.border_color = Color(0.6, 0.3, 0.9, 0.8)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	# 内容布局
	var hbox := HBoxContainer.new()
	hbox.name = "ContentLayout"
	hbox.add_theme_constant_override("separation", 20)
	_panel.add_child(hbox)

	# 左侧：头像区域
	var portrait_container := VBoxContainer.new()
	portrait_container.name = "PortraitContainer"
	portrait_container.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(portrait_container)

	_portrait_rect = TextureRect.new()
	_portrait_rect.name = "Portrait"
	_portrait_rect.custom_minimum_size = Vector2(100, 100)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_container.add_child(_portrait_rect)

	# 右侧：文本区域
	var text_container := VBoxContainer.new()
	text_container.name = "TextContainer"
	text_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_container.add_theme_constant_override("separation", 8)
	hbox.add_child(text_container)

	# 名称行
	var name_row := HBoxContainer.new()
	name_row.name = "NameRow"
	name_row.add_theme_constant_override("separation", 12)
	text_container.add_child(name_row)

	_name_label = Label.new()
	_name_label.name = "BossName"
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	name_row.add_child(_name_label)

	_title_label = Label.new()
	_title_label.name = "BossTitle"
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.7))
	name_row.add_child(_title_label)

	# 对话文本
	_text_label = RichTextLabel.new()
	_text_label.name = "DialogueText"
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("normal_font_size", 18)
	_text_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.95))
	text_container.add_child(_text_label)

	# 底部提示行
	var hint_row := HBoxContainer.new()
	hint_row.name = "HintRow"
	hint_row.alignment = BoxContainer.ALIGNMENT_END
	text_container.add_child(hint_row)

	_advance_indicator = Label.new()
	_advance_indicator.name = "AdvanceIndicator"
	_advance_indicator.text = "▼ 点击继续"
	_advance_indicator.add_theme_font_size_override("font_size", 13)
	_advance_indicator.add_theme_color_override("font_color", Color(0.5, 0.4, 0.6, 0.8))
	hint_row.add_child(_advance_indicator)

	_skip_hint = Label.new()
	_skip_hint.name = "SkipHint"
	_skip_hint.text = "  [ESC 跳过]"
	_skip_hint.add_theme_font_size_override("font_size", 12)
	_skip_hint.add_theme_color_override("font_color", Color(0.4, 0.3, 0.5, 0.6))
	hint_row.add_child(_skip_hint)

# ============================================================
# 公共接口
# ============================================================

## 显示 Boss 战前引入对话
func show_intro_dialogue(boss_key: String) -> void:
	_start_dialogue(boss_key, "intro")

## 显示 Boss 战后胜利对话
func show_victory_dialogue(boss_key: String) -> void:
	_start_dialogue(boss_key, "victory")

## 检查指定 Boss 是否有对话数据
func has_dialogue(boss_key: String, dialogue_type: String = "intro") -> bool:
	if not BOSS_DIALOGUES.has(boss_key):
		return false
	return BOSS_DIALOGUES[boss_key].has(dialogue_type)

## 检查对话是否正在播放
func is_dialogue_active() -> bool:
	return _is_active

# ============================================================
# 对话流程控制
# ============================================================

func _start_dialogue(boss_key: String, dialogue_type: String) -> void:
	if _is_active:
		return

	if not BOSS_DIALOGUES.has(boss_key):
		push_warning("BossDialogue: 未找到 Boss '%s' 的对话数据" % boss_key)
		dialogue_completed.emit(boss_key, dialogue_type)
		return

	var boss_data: Dictionary = BOSS_DIALOGUES[boss_key]
	if not boss_data.has(dialogue_type):
		push_warning("BossDialogue: Boss '%s' 没有 '%s' 类型的对话" % [boss_key, dialogue_type])
		dialogue_completed.emit(boss_key, dialogue_type)
		return

	_current_boss_key = boss_key
	_current_dialogue_type = dialogue_type
	_current_lines.clear()
	for line in boss_data[dialogue_type]:
		_current_lines.append(line)
	_current_line_index = 0

	_is_active = true
	set_process(true)

	# 暂停游戏（如果在游戏中）
	_pause_game(true)

	dialogue_started.emit(boss_key, dialogue_type)

	# 淡入对话框
	_show_dialogue_animated(func():
		_display_current_line()
	)

func _display_current_line() -> void:
	if _current_line_index >= _current_lines.size():
		_end_dialogue()
		return

	var line: Dictionary = _current_lines[_current_line_index]
	var speaker: String = line.get("speaker", "???")
	var text: String = line.get("text", "")
	var emotion: String = line.get("emotion", "neutral")

	# 更新 UI
	_name_label.text = speaker
	_title_label.text = _get_boss_title_for_key(_current_boss_key)

	# 设置头像占位符颜色（基于情感）
	_update_portrait_color(emotion)

	# 开始打字机效果
	_full_text = text
	_displayed_chars = 0
	_is_typing = true
	_is_fast_forward = false
	_text_label.text = ""
	_advance_indicator.visible = false

	dialogue_line_shown.emit(_current_line_index, _current_lines.size())

func _end_dialogue() -> void:
	_hide_dialogue_animated(func():
		_is_active = false
		set_process(false)
		_pause_game(false)
		dialogue_completed.emit(_current_boss_key, _current_dialogue_type)
	)

## 跳过整个对话
## 注意：跳过时只发射 dialogue_skipped 信号，不再同时发射 dialogue_completed，
## 避免 boss_spawner 中 CONNECT_ONE_SHOT 回调被触发两次导致双重 Boss 生成。
func _skip_dialogue() -> void:
	if not allow_skip:
		return
	_hide_dialogue_animated(func():
		_is_active = false
		set_process(false)
		_pause_game(false)
		dialogue_skipped.emit(_current_boss_key)
	)

# ============================================================
# 每帧更新（打字机效果）
# ============================================================

func _process(delta: float) -> void:
	if not _is_active:
		return

	if _is_typing:
		var speed := typewriter_fast_speed if _is_fast_forward else typewriter_speed
		_type_timer += delta
		while _type_timer >= speed and _displayed_chars < _full_text.length():
			_type_timer -= speed
			_displayed_chars += 1
			_text_label.text = _full_text.substr(0, _displayed_chars)

		if _displayed_chars >= _full_text.length():
			_is_typing = false
			_text_label.text = _full_text
			_advance_indicator.visible = true
			_type_timer = 0.0

	# 继续指示器闪烁
	if not _is_typing and _advance_indicator.visible:
		var blink := sin(Time.get_ticks_msec() * 0.005) * 0.3 + 0.7
		_advance_indicator.modulate.a = blink

# ============================================================
# 输入处理
# ============================================================

func _input(event: InputEvent) -> void:
	if not _is_active:
		return

	# ESC 跳过
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_skip_dialogue()
		get_viewport().set_input_as_handled()
		return

	# 点击/空格/回车推进对话
	var advance := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			advance = true

	if advance:
		if _is_typing:
			# 正在打字时，加速显示
			_is_fast_forward = true
		else:
			# 已显示完毕，推进到下一句
			_current_line_index += 1
			_display_current_line()
		get_viewport().set_input_as_handled()

# ============================================================
# UI 动画
# ============================================================

func _show_dialogue_animated(on_complete: Callable) -> void:
	_background_dim.visible = true
	_panel.visible = true
	_background_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.position.y = 30.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_background_dim, "modulate:a", 1.0, fade_duration)
	tween.tween_property(_panel, "modulate:a", 1.0, fade_duration)
	tween.tween_property(_panel, "position:y", 0.0, fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.chain()
	tween.tween_callback(on_complete)

func _hide_dialogue_animated(on_complete: Callable) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_background_dim, "modulate:a", 0.0, fade_duration)
	tween.tween_property(_panel, "modulate:a", 0.0, fade_duration * 0.8)
	tween.tween_property(_panel, "position:y", 20.0, fade_duration * 0.8)
	tween.chain()
	tween.tween_callback(func():
		_background_dim.visible = false
		_panel.visible = false
		on_complete.call()
	)

func _hide_dialogue() -> void:
	_background_dim.visible = false
	_panel.visible = false

# ============================================================
# 辅助方法
# ============================================================

## 根据 boss_key 获取标题
func _get_boss_title_for_key(boss_key: String) -> String:
	var titles: Dictionary = {
		"boss_pythagoras": "The First Resonator",
		"boss_guido": "The Sacred Voice",
		"boss_bach": "The Grand Architect",
		"boss_mozart": "The Classical Perfection",
		"boss_beethoven": "The Romantic Tempest",
		"boss_jazz": "The Syncopated Shadow",
		"boss_noise": "The Digital Void",
	}
	return titles.get(boss_key, "Unknown")

## 根据情感更新头像占位符颜色
func _update_portrait_color(emotion: String) -> void:
	var color_map: Dictionary = {
		"solemn": Color(0.8, 0.75, 0.5),
		"commanding": Color(0.9, 0.8, 0.4),
		"challenge": Color(1.0, 0.4, 0.3),
		"surprised": Color(0.5, 0.8, 1.0),
		"accepting": Color(0.6, 0.9, 0.7),
		"reverent": Color(0.7, 0.6, 1.0),
		"stern": Color(0.5, 0.4, 0.7),
		"enlightened": Color(1.0, 0.95, 0.7),
		"proud": Color(0.8, 0.6, 0.3),
		"respectful": Color(0.6, 0.8, 0.6),
		"blessing": Color(0.9, 0.85, 0.5),
		"elegant": Color(0.9, 0.8, 1.0),
		"disdainful": Color(0.8, 0.5, 0.9),
		"inviting": Color(0.7, 0.9, 1.0),
		"impressed": Color(0.5, 0.9, 0.8),
		"wistful": Color(0.7, 0.7, 0.9),
		"fierce": Color(1.0, 0.3, 0.2),
		"passionate": Color(1.0, 0.5, 0.3),
		"moved": Color(0.6, 0.7, 1.0),
		"encouraging": Color(0.8, 0.9, 0.5),
		"cool": Color(0.3, 0.5, 0.9),
		"serious": Color(0.5, 0.4, 0.6),
		"glitch": Color(0.0, 1.0, 0.5),
		"cold": Color(0.3, 0.3, 0.5),
		"final": Color(0.8, 0.0, 0.3),
		"transcendent": Color(1.0, 1.0, 1.0),
		"neutral": Color(0.7, 0.7, 0.7),
	}
	var color: Color = color_map.get(emotion, Color(0.7, 0.7, 0.7))

	# 创建程序化头像占位符（彩色渐变方块）
	var img := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	for y in range(100):
		for x in range(100):
			var u := float(x) / 100.0
			var v := float(y) / 100.0
			var c := color.lerp(Color(0.1, 0.05, 0.15), v * 0.6)
			# 添加边框
			if x < 2 or x > 97 or y < 2 or y > 97:
				c = color.lightened(0.3)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_portrait_rect.texture = tex

## 暂停/恢复游戏
func _pause_game(paused: bool) -> void:
	# 使用 get_tree().paused 来暂停游戏逻辑
	# 对话框本身的 process_mode 设为 ALWAYS 以保持响应
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tree := get_tree()
	if tree:
		tree.paused = paused
