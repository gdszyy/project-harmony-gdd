## timed_milestone_manager.gd
## 计时里程碑管理器
## Issue #115: 游戏流程完善 — 计时里程碑系统
##
## 功能：
##   1. 在 5分钟 / 10分钟 / 15分钟 触发 Boss 出现
##   2. 与 ChapterManager 和 BossSpawner 协作
##   3. 为 BossSpawner 添加"计时模式"（补充现有的"传统模式"和"章节模式"）
##   4. 支持自定义里程碑时间点和对应 Boss
##   5. 里程碑到达时显示警告 UI 和倒计时
##
## 设计：
##   - 挂载在 main_game 场景中，监听 GameManager.game_time
##   - 到达里程碑时间时，通知 BossSpawner 生成对应 Boss
##   - 里程碑之间的间隔可被 DifficultyManager 影响
extends Node

# ============================================================
# 信号
# ============================================================
signal milestone_approaching(milestone_index: int, time_remaining: float)
signal milestone_reached(milestone_index: int, boss_key: String)
signal milestone_boss_defeated(milestone_index: int)
signal all_milestones_completed()

# ============================================================
# 里程碑配置
# ============================================================
const DEFAULT_MILESTONES: Array = [
	{
		"time": 300.0,   ## 5 分钟
		"boss_key": "boss_pythagoras",
		"name": "第一乐章终曲",
		"warning_text": "⚠ 第一乐章即将落幕... Boss 正在苏醒！",
		"warning_time": 30.0,  ## 提前 30 秒警告
		"difficulty_bonus": 0.0,
	},
	{
		"time": 600.0,   ## 10 分钟
		"boss_key": "boss_bach",
		"name": "第二乐章终曲",
		"warning_text": "⚠ 第二乐章高潮将至... 更强大的 Boss 正在觉醒！",
		"warning_time": 30.0,
		"difficulty_bonus": 0.3,
	},
	{
		"time": 900.0,   ## 15 分钟
		"boss_key": "boss_beethoven",
		"name": "终章决战",
		"warning_text": "⚠ 终章序曲响起... 最终 Boss 降临！",
		"warning_time": 30.0,
		"difficulty_bonus": 0.6,
	},
	{
		"time": 1200.0,  ## 20 分钟（可选的额外里程碑）
		"boss_key": "boss_noise",
		"name": "安可曲",
		"warning_text": "⚠ 安可曲开始... 噪音之主现身！",
		"warning_time": 30.0,
		"difficulty_bonus": 1.0,
	},
]

# ============================================================
# 配置
# ============================================================
## 是否启用计时模式
@export var timed_mode_enabled: bool = false
## 里程碑警告持续时间
@export var warning_display_duration: float = 5.0

# ============================================================
# 内部状态
# ============================================================
var _milestones: Array = []
var _current_milestone_index: int = 0
var _warning_shown: bool = false
var _milestone_active: bool = false
var _boss_fight_active: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_milestones = DEFAULT_MILESTONES.duplicate(true)
	_apply_difficulty_scaling()

func _process(_delta: float) -> void:
	if not timed_mode_enabled:
		return

	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	if _boss_fight_active:
		return

	if _current_milestone_index >= _milestones.size():
		return

	var current_time: float = GameManager.game_time
	var milestone: Dictionary = _milestones[_current_milestone_index]
	var milestone_time: float = milestone.get("time", 0.0)
	var warning_time: float = milestone.get("warning_time", 30.0)

	# 检查是否应该显示警告
	if not _warning_shown and current_time >= (milestone_time - warning_time):
		_show_milestone_warning(milestone)
		_warning_shown = true

	# 检查是否到达里程碑
	if current_time >= milestone_time and not _milestone_active:
		_trigger_milestone()

# ============================================================
# 公共接口
# ============================================================

## 启用计时模式
func enable_timed_mode() -> void:
	timed_mode_enabled = true
	_current_milestone_index = 0
	_warning_shown = false
	_milestone_active = false
	_boss_fight_active = false
	_apply_difficulty_scaling()

## 禁用计时模式
func disable_timed_mode() -> void:
	timed_mode_enabled = false

## 获取当前里程碑信息
func get_current_milestone() -> Dictionary:
	if _current_milestone_index < _milestones.size():
		return _milestones[_current_milestone_index]
	return {}

## 获取下一个里程碑的剩余时间
func get_time_to_next_milestone() -> float:
	if _current_milestone_index >= _milestones.size():
		return -1.0
	var milestone: Dictionary = _milestones[_current_milestone_index]
	return max(0.0, milestone.get("time", 0.0) - GameManager.game_time)

## 获取里程碑进度（0.0 ~ 1.0）
func get_milestone_progress() -> float:
	if _current_milestone_index >= _milestones.size():
		return 1.0

	var milestone: Dictionary = _milestones[_current_milestone_index]
	var milestone_time: float = milestone.get("time", 300.0)

	var prev_time: float = 0.0
	if _current_milestone_index > 0:
		prev_time = _milestones[_current_milestone_index - 1].get("time", 0.0)

	var elapsed: float = GameManager.game_time - prev_time
	var duration: float = milestone_time - prev_time

	if duration <= 0.0:
		return 1.0
	return clampf(elapsed / duration, 0.0, 1.0)

## 获取已完成的里程碑数量
func get_completed_milestone_count() -> int:
	return _current_milestone_index

## 通知 Boss 已被击败
func on_milestone_boss_defeated() -> void:
	_boss_fight_active = false
	_milestone_active = false
	milestone_boss_defeated.emit(_current_milestone_index)

	_current_milestone_index += 1
	_warning_shown = false

	if _current_milestone_index >= _milestones.size():
		all_milestones_completed.emit()

## 设置自定义里程碑
func set_custom_milestones(milestones: Array) -> void:
	_milestones = milestones.duplicate(true)
	_current_milestone_index = 0
	_warning_shown = false
	_milestone_active = false

# ============================================================
# 里程碑触发
# ============================================================

func _trigger_milestone() -> void:
	_milestone_active = true
	_boss_fight_active = true

	var milestone: Dictionary = _milestones[_current_milestone_index]
	var boss_key: String = milestone.get("boss_key", "")

	milestone_reached.emit(_current_milestone_index, boss_key)

	# 通知 BossSpawner 生成 Boss
	var boss_spawner := get_tree().get_first_node_in_group("boss_spawner")
	if boss_spawner == null:
		boss_spawner = get_node_or_null("../BossSpawner")

	if boss_spawner:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			# 使用计时模式生成 Boss
			if boss_spawner.has_method("spawn_timed_boss"):
				var difficulty_bonus: float = milestone.get("difficulty_bonus", 0.0)
				boss_spawner.spawn_timed_boss(boss_key, player.global_position, difficulty_bonus)
			else:
				# 后备：使用传统生成方式
				boss_spawner.spawn_boss(player.global_position)

			# 连接 Boss 战结束信号
			if boss_spawner.has_signal("boss_fight_ended"):
				if not boss_spawner.boss_fight_ended.is_connected(_on_boss_fight_ended):
					boss_spawner.boss_fight_ended.connect(_on_boss_fight_ended)

func _on_boss_fight_ended(_boss_name: String, victory: bool) -> void:
	if victory:
		on_milestone_boss_defeated()
	else:
		_boss_fight_active = false
		_milestone_active = false

# ============================================================
# 警告显示
# ============================================================

func _show_milestone_warning(milestone: Dictionary) -> void:
	var warning_text: String = milestone.get("warning_text", "Boss 即将出现！")
	var remaining: float = milestone.get("time", 0.0) - GameManager.game_time

	milestone_approaching.emit(_current_milestone_index, remaining)

	# 通过 TutorialHintManager 显示警告
	var hint_mgr := get_node_or_null("/root/TutorialHintManager")
	if hint_mgr and hint_mgr.has_method("show_hint"):
		hint_mgr.show_hint(warning_text, warning_display_duration)

# ============================================================
# 难度缩放
# ============================================================

func _apply_difficulty_scaling() -> void:
	var diff_mgr := get_node_or_null("/root/DifficultyManager")
	if diff_mgr == null:
		return

	var wave_interval_mult: float = diff_mgr.get_wave_interval_multiplier()

	# 根据难度调整里程碑时间
	for i in range(_milestones.size()):
		_milestones[i]["time"] = DEFAULT_MILESTONES[i]["time"] * wave_interval_mult
