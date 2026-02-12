## tutorial_sequence.gd
## 教学序列管理器 (CanvasLayer)
## 模块7：教学引导与辅助 UI
##
## 功能：
##   - 管理多步骤教学事件序列
##   - 支持跳过（标记为"已查看"）
##   - 支持回顾（收录到谐振法典）
##   - 与 TutorialHintManager 协作显示视觉引导
##   - 与 TutorialManager(Autoload) 对接教学步骤
##
## 设计原则：
##   - 教学事件由游戏内行为触发
##   - 不暂停游戏，但可限制部分操作
##   - 所有完成/跳过的教学内容收录到法典
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal sequence_started(sequence_id: String)
signal sequence_step_changed(sequence_id: String, step_index: int)
signal sequence_completed(sequence_id: String)
signal sequence_skipped(sequence_id: String)
signal all_sequences_completed()

# ============================================================
# 主题颜色
# ============================================================
const ACCENT_COLOR := Color("#9D6FFF")
const TEXT_PRIMARY := Color("#EAE6FF")
const TEXT_SECONDARY := Color("#A098C8")
const SUCCESS_COLOR := Color("#4DFF80")
const PANEL_BG := Color("#141026")

# ============================================================
# 教学事件定义
# ============================================================

## 教学事件数据结构
## {
##   "id": String,               # 事件唯一ID
##   "title": String,            # 事件标题
##   "trigger": String,          # 触发条件标识
##   "steps": [                  # 步骤数组
##     {
##       "text": String,         # 说明文字
##       "highlight": String,    # 高亮目标UI元素名
##       "arrow": bool,          # 是否显示箭头
##       "bubble": String,       # 气泡文字（可选）
##       "completion": String,   # 完成条件
##       "auto_delay": float,    # 自动推进延迟（仅 completion="auto" 时有效）
##     }
##   ],
##   "codex_entry": Dictionary,  # 法典收录数据
## }

const TUTORIAL_SEQUENCES_PATH := "res://data/tutorials/tutorial_sequences.json"
var TUTORIAL_SEQUENCES: Dictionary = {}

func _load_tutorial_sequences() -> void:
	var file := FileAccess.open(TUTORIAL_SEQUENCES_PATH, FileAccess.READ)
	if file == null:
		push_error("TutorialSequence: 无法加载教学序列数据: %s" % TUTORIAL_SEQUENCES_PATH)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("TutorialSequence: JSON 解析失败: %s" % json.get_error_message())
		return
	TUTORIAL_SEQUENCES = json.data
	print("[TutorialSequence] 已加载 %d 个教学序列" % TUTORIAL_SEQUENCES.size())

# 以下为原始硬编码数据的备份引用（已迁移至 data/tutorials/tutorial_sequences.json）
const _TUTORIAL_SEQUENCES_LEGACY: Dictionary = {
	"FIRST_NOTE_PICKUP": {
		"id": "FIRST_NOTE_PICKUP",
		"title": "音符晶片",
		"trigger": "FIRST_NOTE_PICKUP",
		"steps": [
			{
				"text": "你拾取了第一枚音符晶片！音符是你施法的弹药。",
				"highlight": "NoteInventoryUI",
				"arrow": true,
				"bubble": "查看你的音符库存",
				"completion": "auto",
				"auto_delay": 5.0,
			},
			{
				"text": "不同音符拥有不同属性。白键音符是基础攻击，黑键音符可修饰强化。",
				"highlight": "",
				"arrow": false,
				"bubble": "",
				"completion": "auto",
				"auto_delay": 5.0,
			},
		],
		"codex_entry": {
			"category": "tutorial",
			"title": "音符晶片系统",
			"description": "音符晶片是施法的核心弹药。白键音符提供基础攻击，黑键音符可修饰并强化法术效果。",
		},
	},
	"FIRST_SPELL_CAST": {
		"id": "FIRST_SPELL_CAST",
		"title": "施法入门",
		"trigger": "FIRST_SPELL_CAST",
		"steps": [
			{
				"text": "按下键盘白键（A S D F G H J）施放音符法术！",
				"highlight": "",
				"arrow": false,
				"bubble": "",
				"completion": "spell_cast",
				"auto_delay": 0.0,
			},
			{
				"text": "很好！每个音符的弹幕轨迹和伤害类型各不相同。多尝试不同组合！",
				"highlight": "",
				"arrow": false,
				"bubble": "",
				"completion": "auto",
				"auto_delay": 4.0,
			},
		],
		"codex_entry": {
			"category": "tutorial",
			"title": "基础施法",
			"description": "使用键盘白键施放音符法术，每个音符拥有独特的弹幕轨迹和伤害属性。",
		},
	},
	"FATIGUE_FIRST_HIGH": {
		"id": "FATIGUE_FIRST_HIGH",
		"title": "听感疲劳警告",
		"trigger": "FATIGUE_FIRST_HIGH",
		"steps": [
			{
				"text": "警告！你的听感疲劳度已超过 60%！",
				"highlight": "FatigueBar",
				"arrow": true,
				"bubble": "注意疲劳指示器",
				"completion": "auto",
				"auto_delay": 4.0,
			},
			{
				"text": "重复使用相同音符会累积疲劳。疲劳过高时法术威力大幅下降！",
				"highlight": "",
				"arrow": false,
				"bubble": "",
				"completion": "auto",
				"auto_delay": 5.0,
			},
			{
				"text": "多变换音符组合来保持新鲜感，降低疲劳积累。",
				"highlight": "",
				"arrow": false,
				"bubble": "",
				"completion": "auto",
				"auto_delay": 4.0,
			},
		],
		"codex_entry": {
			"category": "tutorial",
			"title": "听感疲劳系统",
			"description": "重复使用相同音符会累积听感疲劳，导致法术威力下降。多变换音符组合可有效降低疲劳。",
		},
	},
	"FIRST_CHORD_BUILD": {
		"id": "FIRST_CHORD_BUILD",
		"title": "和弦构建",
		"trigger": "FIRST_CHORD_BUILD",
		"steps": [
			{
				"text": "你构建了第一个和弦！同时按下多个音符键可释放和弦法术。",
				"highlight": "IntegratedComposer",
				"arrow": true,
				"bubble": "在编曲台查看和弦效果",
				"completion": "auto",
				"auto_delay": 5.0,
			},
			{
				"text": "和弦法术的威力远超单音。不同和弦组合会产生不同的战斗效果！",
				"highlight": "",
				"arrow": false,
				"bubble": "",
				"completion": "auto",
				"auto_delay": 5.0,
			},
		],
		"codex_entry": {
			"category": "tutorial",
			"title": "和弦构建系统",
			"description": "同时按下多个音符键可构建和弦法术，威力远超单音。不同和弦组合产生不同战斗效果。",
		},
	},
	"FIRST_UPGRADE": {
		"id": "FIRST_UPGRADE",
		"title": "五度圈罗盘",
		"trigger": "FIRST_UPGRADE",
		"steps": [
			{
				"text": "升级了！五度圈罗盘已开启。",
				"highlight": "CircleOfFifthsUpgradeV3",
				"arrow": true,
				"bubble": "在罗盘上选择升级路径",
				"completion": "auto",
				"auto_delay": 5.0,
			},
			{
				"text": "每次选择都会影响你的战斗风格。仔细考虑每条路径的效果！",
				"highlight": "",
				"arrow": false,
				"bubble": "",
				"completion": "auto",
				"auto_delay": 4.0,
			},
		],
		"codex_entry": {
			"category": "tutorial",
			"title": "五度圈罗盘升级",
			"description": "升级时通过五度圈罗盘选择升级路径，每次选择都会影响战斗风格和能力发展方向。",
		},
	},
	"FIRST_BOSS_ENCOUNTER": {
		"id": "FIRST_BOSS_ENCOUNTER",
		"title": "Boss 战斗",
		"trigger": "FIRST_BOSS_ENCOUNTER",
		"steps": [
			{
				"text": "Boss 出现了！注意观察 Boss 的攻击模式。",
				"highlight": "BossHPBar",
				"arrow": true,
				"bubble": "Boss 血条",
				"completion": "auto",
				"auto_delay": 4.0,
			},
			{
				"text": "Boss 通常有特殊的弱点机制。尝试不同的音符组合来寻找最佳应对策略！",
				"highlight": "",
				"arrow": false,
				"bubble": "",
				"completion": "auto",
				"auto_delay": 5.0,
			},
		],
		"codex_entry": {
			"category": "tutorial",
			"title": "Boss 战斗指南",
			"description": "Boss 拥有独特的攻击模式和弱点机制，需要灵活运用不同音符组合来应对。",
		},
	},
}

# ============================================================
# 配置
# ============================================================
@export var step_transition_delay: float = 1.0
@export var auto_save_to_codex: bool = true

# ============================================================
# 内部状态
# ============================================================
var _current_sequence_id: String = ""
var _current_step_index: int = -1
var _is_playing: bool = false
var _step_timer: float = 0.0
var _auto_advance_timer: float = 0.0

## 已完成的序列
var _completed_sequences: Array[String] = []
## 已跳过的序列
var _skipped_sequences: Array[String] = []
## 已查看的序列（完成 + 跳过）
var _viewed_sequences: Array[String] = []

## TutorialHintManager 引用
var _hint_manager: Node = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_tutorial_sequences()
	call_deferred("_find_hint_manager")
	_load_progress()

func _process(delta: float) -> void:
	if not _is_playing:
		return

	_step_timer += delta

	if _auto_advance_timer > 0.0:
		_auto_advance_timer -= delta
		if _auto_advance_timer <= 0.0:
			advance_step()

# ============================================================
# 公共接口
# ============================================================

## 触发教学事件（通过触发条件标识）
func trigger_event(trigger_id: String) -> void:
	# 查找匹配的序列
	for seq_id in TUTORIAL_SEQUENCES:
		var seq: Dictionary = TUTORIAL_SEQUENCES[seq_id]
		if seq.get("trigger", "") == trigger_id:
			start_sequence(seq_id)
			return

## 开始教学序列
func start_sequence(sequence_id: String) -> void:
	if sequence_id in _viewed_sequences:
		return  # 已查看过，不重复
	if _is_playing:
		return  # 正在播放其他序列

	var seq: Dictionary = TUTORIAL_SEQUENCES.get(sequence_id, {})
	if seq.is_empty():
		push_warning("[TutorialSequence] 未找到序列: %s" % sequence_id)
		return

	_current_sequence_id = sequence_id
	_current_step_index = -1
	_is_playing = true

	# 显示步骤指引
	var steps: Array = seq.get("steps", [])
	if _hint_manager and _hint_manager.has_method("show_step_indicator"):
		_hint_manager.show_step_indicator(1, steps.size(), seq.get("title", ""))

	# 显示跳过按钮
	if _hint_manager and _hint_manager.has_method("show_skip_button"):
		_hint_manager.show_skip_button(skip_current_sequence)

	sequence_started.emit(sequence_id)

	# 开始第一步
	advance_step()

## 推进到下一步
func advance_step() -> void:
	if not _is_playing:
		return

	var seq: Dictionary = TUTORIAL_SEQUENCES.get(_current_sequence_id, {})
	var steps: Array = seq.get("steps", [])

	_current_step_index += 1

	# 清除上一步的高亮
	if _hint_manager and _hint_manager.has_method("clear_highlight"):
		_hint_manager.clear_highlight()

	# 检查是否完成所有步骤
	if _current_step_index >= steps.size():
		_complete_current_sequence()
		return

	var step: Dictionary = steps[_current_step_index]
	_step_timer = 0.0
	_auto_advance_timer = 0.0

	# 更新步骤指引
	if _hint_manager and _hint_manager.has_method("update_step_progress"):
		_hint_manager.update_step_progress(_current_step_index + 1, seq.get("title", ""))

	# 显示提示文字
	var hint_text: String = step.get("text", "")
	if hint_text != "" and _hint_manager and _hint_manager.has_method("show_hint"):
		_hint_manager.show_hint(hint_text, 10.0)

	# 高亮目标
	var highlight: String = step.get("highlight", "")
	if highlight != "" and _hint_manager and _hint_manager.has_method("highlight_element"):
		var show_arrow: bool = step.get("arrow", false)
		var bubble: String = step.get("bubble", "")
		_hint_manager.highlight_element(highlight, show_arrow, bubble)

	# 设置自动推进
	var completion: String = step.get("completion", "auto")
	if completion == "auto":
		var delay: float = step.get("auto_delay", 5.0)
		_auto_advance_timer = delay + step_transition_delay

	sequence_step_changed.emit(_current_sequence_id, _current_step_index)

## 跳过当前序列
func skip_current_sequence() -> void:
	if not _is_playing:
		return

	var seq_id := _current_sequence_id
	_skipped_sequences.append(seq_id)
	_viewed_sequences.append(seq_id)

	_cleanup_sequence()

	# 保存到法典
	if auto_save_to_codex:
		_save_to_codex(seq_id)

	# 显示跳过提示
	if _hint_manager and _hint_manager.has_method("show_hint"):
		_hint_manager.show_hint("教学已跳过。可在谐振法典中回顾。", 2.5)

	_save_progress()
	sequence_skipped.emit(seq_id)

## 检查序列是否已完成
func is_sequence_completed(sequence_id: String) -> bool:
	return sequence_id in _completed_sequences

## 检查序列是否已查看（完成或跳过）
func is_sequence_viewed(sequence_id: String) -> bool:
	return sequence_id in _viewed_sequences

## 检查是否正在播放
func is_playing() -> bool:
	return _is_playing

## 获取当前序列ID
func get_current_sequence_id() -> String:
	return _current_sequence_id

## 获取当前步骤索引
func get_current_step_index() -> int:
	return _current_step_index

## 获取所有可回顾的教学内容
func get_reviewable_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for seq_id in _viewed_sequences:
		var seq: Dictionary = TUTORIAL_SEQUENCES.get(seq_id, {})
		if seq.has("codex_entry"):
			var entry: Dictionary = seq["codex_entry"].duplicate()
			entry["sequence_id"] = seq_id
			entry["was_skipped"] = seq_id in _skipped_sequences
			entries.append(entry)
	return entries

## 外部通知步骤完成条件已满足
func notify_condition_met(condition: String) -> void:
	if not _is_playing:
		return

	var seq: Dictionary = TUTORIAL_SEQUENCES.get(_current_sequence_id, {})
	var steps: Array = seq.get("steps", [])
	if _current_step_index < 0 or _current_step_index >= steps.size():
		return

	var step: Dictionary = steps[_current_step_index]
	var required_completion: String = step.get("completion", "auto")

	if required_completion == condition:
		# 显示完成反馈
		if _hint_manager and _hint_manager.has_method("show_hint"):
			_hint_manager.show_hint("✓ 做得好！", 1.5)

		get_tree().create_timer(step_transition_delay).timeout.connect(func():
			advance_step()
		)

## 重置所有进度
func reset_all_progress() -> void:
	_completed_sequences.clear()
	_skipped_sequences.clear()
	_viewed_sequences.clear()
	_save_progress()

# ============================================================
# 内部方法
# ============================================================

func _complete_current_sequence() -> void:
	var seq_id := _current_sequence_id
	_completed_sequences.append(seq_id)
	_viewed_sequences.append(seq_id)

	_cleanup_sequence()

	# 保存到法典
	if auto_save_to_codex:
		_save_to_codex(seq_id)

	# 显示完成反馈
	if _hint_manager and _hint_manager.has_method("show_hint"):
		_hint_manager.show_hint("★ 教学完成！", 2.0)

	_save_progress()
	sequence_completed.emit(seq_id)

	# 检查是否所有序列都已完成
	var all_done := true
	for sid in TUTORIAL_SEQUENCES:
		if sid not in _viewed_sequences:
			all_done = false
			break
	if all_done:
		all_sequences_completed.emit()

func _cleanup_sequence() -> void:
	_is_playing = false
	_current_sequence_id = ""
	_current_step_index = -1
	_auto_advance_timer = 0.0

	if _hint_manager:
		if _hint_manager.has_method("clear_highlight"):
			_hint_manager.clear_highlight()
		if _hint_manager.has_method("hide_step_indicator"):
			_hint_manager.hide_step_indicator()
		if _hint_manager.has_method("hide_skip_button"):
			_hint_manager.hide_skip_button()

func _find_hint_manager() -> void:
	# 尝试查找 TutorialHintManager Autoload 或场景中的实例
	_hint_manager = get_node_or_null("/root/TutorialHintManager")
	if _hint_manager == null:
		_hint_manager = get_tree().get_first_node_in_group("tutorial_hint_manager")

func _save_to_codex(sequence_id: String) -> void:
	var seq: Dictionary = TUTORIAL_SEQUENCES.get(sequence_id, {})
	if not seq.has("codex_entry"):
		return

	var codex := get_node_or_null("/root/CodexManager")
	if codex and codex.has_method("add_entry"):
		var entry: Dictionary = seq["codex_entry"]
		codex.add_entry(entry.get("category", "tutorial"), {
			"title": entry.get("title", ""),
			"description": entry.get("description", ""),
			"source": "tutorial_sequence",
			"sequence_id": sequence_id,
		})

# ============================================================
# 进度存档
# ============================================================

func _save_progress() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("set_data"):
		save_mgr.set_data("tutorial_sequences_completed", _completed_sequences)
		save_mgr.set_data("tutorial_sequences_skipped", _skipped_sequences)
		save_mgr.set_data("tutorial_sequences_viewed", _viewed_sequences)

func _load_progress() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("get_data"):
		var data: Dictionary = save_mgr.get_data()
		var completed = data.get("tutorial_sequences_completed", [])
		var skipped = data.get("tutorial_sequences_skipped", [])
		var viewed = data.get("tutorial_sequences_viewed", [])
		for s in completed:
			_completed_sequences.append(s)
		for s in skipped:
			_skipped_sequences.append(s)
		for s in viewed:
			_viewed_sequences.append(s)
