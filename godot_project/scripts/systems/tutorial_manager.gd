## tutorial_manager.gd
## 新手引导/教程管理器 (Autoload)
## Issue #115: 游戏流程完善 — 新手引导系统
##
## 功能：
##   1. 分步引导玩家理解核心操作（白键施法、黑键修饰、和弦构建）
##   2. 引导玩家理解听感疲劳系统的惩罚机制
##   3. 引导玩家使用五度圈罗盘升级系统
##   4. 与 TutorialHintManager 协作显示提示 UI
##
## 设计原则：
##   - 渐进式教学：按步骤逐步解锁功能
##   - 非侵入式：不暂停游戏，使用柔和提示
##   - 条件触发：玩家完成当前步骤后才推进下一步
##   - 可跳过：玩家可以随时跳过教程
extends Node

# ============================================================
# 信号
# ============================================================
signal tutorial_started()
signal tutorial_step_completed(step_id: String)
signal tutorial_completed()
signal tutorial_skipped()

# ============================================================
# 教程步骤枚举
# ============================================================
enum TutorialStep {
	NONE,
	WELCOME,              ## 欢迎介绍
	MOVEMENT,             ## 移动操作
	WHITE_KEY_CASTING,    ## 白键施法
	BLACK_KEY_MODIFIER,   ## 黑键修饰
	CHORD_BUILDING,       ## 和弦构建
	FATIGUE_SYSTEM,       ## 听感疲劳系统
	CIRCLE_OF_FIFTHS,     ## 五度圈罗盘升级
	COMBAT_PRACTICE,      ## 实战练习
	COMPLETED,            ## 教程完成
}

# ============================================================
# 教程步骤配置
# ============================================================
const TUTORIAL_STEPS: Dictionary = {
	TutorialStep.WELCOME: {
		"id": "welcome",
		"title": "欢迎来到 Project Harmony",
		"hint_text": "♪ 欢迎来到谐律幻境！在这里，音乐就是你的武器。\n让我们一步步学习如何演奏战斗的乐章。",
		"duration": 5.0,
		"highlight_ui": "",
		"completion_condition": "auto",  ## 自动完成（等待时间）
		"auto_advance_delay": 5.0,
	},
	TutorialStep.MOVEMENT: {
		"id": "movement",
		"title": "基础移动",
		"hint_text": "使用 WASD 或方向键移动你的角色。\n在战场上灵活走位是生存的基础！",
		"duration": 6.0,
		"highlight_ui": "",
		"completion_condition": "player_moved",  ## 玩家移动后完成
		"required_distance": 100.0,
	},
	TutorialStep.WHITE_KEY_CASTING: {
		"id": "white_key_casting",
		"title": "白键施法",
		"hint_text": "按下键盘上的白键（A S D F G H J）来施放音符法术！\n每个音符都会发射不同的弹幕攻击敌人。",
		"duration": 8.0,
		"highlight_ui": "NoteInventoryUI",
		"completion_condition": "white_keys_cast",  ## 施放3次白键法术
		"required_count": 3,
	},
	TutorialStep.BLACK_KEY_MODIFIER: {
		"id": "black_key_modifier",
		"title": "黑键修饰",
		"hint_text": "黑键（W E T Y U）可以为你的法术添加升降号修饰。\n先按住黑键，再按白键，体验修饰后的强化效果！",
		"duration": 8.0,
		"highlight_ui": "",
		"completion_condition": "black_key_used",  ## 使用1次黑键修饰
		"required_count": 1,
	},
	TutorialStep.CHORD_BUILDING: {
		"id": "chord_building",
		"title": "和弦构建",
		"hint_text": "同时按下多个音符键可以构建和弦！\n和弦法术的威力远超单音——试试同时按下三个键。",
		"duration": 8.0,
		"highlight_ui": "IntegratedComposer",
		"completion_condition": "chord_built",  ## 构建1次和弦
		"required_count": 1,
	},
	TutorialStep.FATIGUE_SYSTEM: {
		"id": "fatigue_system",
		"title": "听感疲劳",
		"hint_text": "注意！重复使用相同音符会积累「听感疲劳」。\n疲劳过高时法术威力下降，甚至会被「寂静」封印。\n多变换音符组合来保持新鲜感！",
		"duration": 8.0,
		"highlight_ui": "FatigueBar",
		"completion_condition": "auto",
		"auto_advance_delay": 8.0,
	},
	TutorialStep.CIRCLE_OF_FIFTHS: {
		"id": "circle_of_fifths",
		"title": "五度圈罗盘",
		"hint_text": "升级时会打开「五度圈罗盘」！\n在罗盘上选择升级路径，解锁新的音符能力和被动效果。\n每次选择都会影响你的战斗风格。",
		"duration": 8.0,
		"highlight_ui": "CircleOfFifthsUpgradeV3",
		"completion_condition": "auto",
		"auto_advance_delay": 8.0,
	},
	TutorialStep.COMBAT_PRACTICE: {
		"id": "combat_practice",
		"title": "实战练习",
		"hint_text": "很好！现在你已经掌握了基础操作。\n消灭眼前的敌人来完成教程吧！击败 3 个敌人即可。",
		"duration": 6.0,
		"highlight_ui": "",
		"completion_condition": "enemies_killed",  ## 击杀3个敌人
		"required_count": 3,
	},
	TutorialStep.COMPLETED: {
		"id": "completed",
		"title": "教程完成",
		"hint_text": "★ 恭喜！你已经掌握了谐律幻境的基本操作！\n现在，真正的冒险开始了——祝你好运，指挥家！",
		"duration": 5.0,
		"highlight_ui": "",
		"completion_condition": "auto",
		"auto_advance_delay": 5.0,
	},
}

# ============================================================
# 配置
# ============================================================
## 是否启用教程（首次游戏自动启用）
@export var tutorial_enabled: bool = true
## 步骤间的延迟
@export var step_transition_delay: float = 1.5

# ============================================================
# 内部状态
# ============================================================
var _current_step: TutorialStep = TutorialStep.NONE
var _is_active: bool = false
var _is_completed: bool = false
var _step_timer: float = 0.0
var _auto_advance_timer: float = 0.0

## 步骤完成追踪
var _player_start_position: Vector2 = Vector2.ZERO
var _player_total_distance: float = 0.0
var _white_key_cast_count: int = 0
var _black_key_use_count: int = 0
var _chord_build_count: int = 0
var _enemies_killed_count: int = 0

## 提示管理器引用
var _hint_manager: Node = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not _is_active:
		return

	_step_timer += delta

	# 自动推进计时
	if _auto_advance_timer > 0.0:
		_auto_advance_timer -= delta
		if _auto_advance_timer <= 0.0:
			_advance_to_next_step()
			return

	# 检查当前步骤的完成条件
	_check_step_completion()

# ============================================================
# 公共接口
# ============================================================

## 开始教程
func start_tutorial() -> void:
	if _is_completed:
		return

	_is_active = true
	_current_step = TutorialStep.NONE

	# 获取提示管理器
	_hint_manager = get_node_or_null("/root/TutorialHintManager")

	# 连接游戏信号
	_connect_game_signals()

	tutorial_started.emit()

	# 延迟后开始第一步
	get_tree().create_timer(1.0).timeout.connect(func():
		_advance_to_next_step()
	)

## 跳过教程
func skip_tutorial() -> void:
	_is_active = false
	_is_completed = true
	_current_step = TutorialStep.COMPLETED

	if _hint_manager:
		_hint_manager.show_hint("教程已跳过。祝你好运，指挥家！", 3.0)

	tutorial_skipped.emit()

## 检查教程是否正在进行
func is_tutorial_active() -> bool:
	return _is_active

## 检查教程是否已完成
func is_tutorial_completed() -> bool:
	return _is_completed

## 获取当前步骤
func get_current_step() -> TutorialStep:
	return _current_step

## 检查是否应该显示教程（首次游戏）
func should_show_tutorial() -> bool:
	if not tutorial_enabled:
		return false
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("get_data"):
		var save_data: Dictionary = save_mgr.get_data()
		return not save_data.get("tutorial_completed", false)
	return true

## 标记教程已完成并保存
func mark_tutorial_completed() -> void:
	_is_completed = true
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("set_data"):
		save_mgr.set_data("tutorial_completed", true)

# ============================================================
# 步骤推进
# ============================================================

func _advance_to_next_step() -> void:
	var next_step: TutorialStep = _current_step + 1 as TutorialStep

	if next_step > TutorialStep.COMPLETED:
		_complete_tutorial()
		return

	_current_step = next_step
	_step_timer = 0.0
	_auto_advance_timer = 0.0

	var config: Dictionary = TUTORIAL_STEPS.get(_current_step, {})
	if config.is_empty():
		_complete_tutorial()
		return

	# 显示提示
	if _hint_manager:
		var hint_text: String = config.get("hint_text", "")
		var duration: float = config.get("duration", 5.0)
		var highlight: String = config.get("highlight_ui", "")
		_hint_manager.show_hint(hint_text, duration, highlight)

	# 设置自动推进
	var condition: String = config.get("completion_condition", "auto")
	if condition == "auto":
		_auto_advance_timer = config.get("auto_advance_delay", 5.0) + step_transition_delay

	tutorial_step_completed.emit(config.get("id", ""))

func _complete_tutorial() -> void:
	_is_active = false
	_is_completed = true
	mark_tutorial_completed()
	tutorial_completed.emit()

# ============================================================
# 完成条件检查
# ============================================================

func _check_step_completion() -> void:
	var config: Dictionary = TUTORIAL_STEPS.get(_current_step, {})
	if config.is_empty():
		return

	var condition: String = config.get("completion_condition", "auto")

	match condition:
		"player_moved":
			var player := get_tree().get_first_node_in_group("player")
			if player:
				var dist: float = player.global_position.distance_to(_player_start_position)
				_player_total_distance += dist
				_player_start_position = player.global_position
				if _player_total_distance >= config.get("required_distance", 100.0):
					_on_step_condition_met()

		"white_keys_cast":
			if _white_key_cast_count >= config.get("required_count", 3):
				_on_step_condition_met()

		"black_key_used":
			if _black_key_use_count >= config.get("required_count", 1):
				_on_step_condition_met()

		"chord_built":
			if _chord_build_count >= config.get("required_count", 1):
				_on_step_condition_met()

		"enemies_killed":
			if _enemies_killed_count >= config.get("required_count", 3):
				_on_step_condition_met()

func _on_step_condition_met() -> void:
	if _hint_manager:
		_hint_manager.show_hint("✓ 做得好！", 1.5)

	# 延迟后推进到下一步
	get_tree().create_timer(step_transition_delay).timeout.connect(func():
		_advance_to_next_step()
	)

# ============================================================
# 信号连接
# ============================================================

func _connect_game_signals() -> void:
	# 连接击杀信号
	if GameManager.has_signal("enemy_killed"):
		if not GameManager.enemy_killed.is_connected(_on_enemy_killed):
			GameManager.enemy_killed.connect(_on_enemy_killed)

	# 连接施法信号
	if SpellcraftSystem.has_signal("spell_cast"):
		if not SpellcraftSystem.spell_cast.is_connected(_on_spell_cast):
			SpellcraftSystem.spell_cast.connect(_on_spell_cast)

	# 连接和弦信号
	if SpellcraftSystem.has_signal("chord_resolved"):
		if not SpellcraftSystem.chord_resolved.is_connected(_on_chord_resolved):
			SpellcraftSystem.chord_resolved.connect(_on_chord_resolved)

	# 记录玩家初始位置
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_player_start_position = player.global_position

# ============================================================
# 信号回调
# ============================================================

func _on_enemy_killed(_pos: Vector2, _type: String) -> void:
	if not _is_active:
		return
	_enemies_killed_count += 1

func _on_spell_cast(spell_data: Dictionary) -> void:
	if not _is_active:
		return

	var note_type: String = spell_data.get("type", "")
	if note_type == "white" or note_type == "natural":
		_white_key_cast_count += 1
	elif note_type == "black" or note_type == "sharp" or note_type == "flat":
		_black_key_use_count += 1

func _on_chord_resolved(_chord_data: Dictionary) -> void:
	if not _is_active:
		return
	_chord_build_count += 1
