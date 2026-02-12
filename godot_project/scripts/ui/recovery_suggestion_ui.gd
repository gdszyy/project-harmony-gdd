## recovery_suggestion_ui.gd
## 恢复建议 UI 控制器 (v3.1)
## 将 FatigueManager 的恢复建议连接到 HUD，通过 Toast 通知系统展示
## 当疲劳达到中/高级别时在 HUD 上显示建议文本
##
## 显示策略：
##   - 低疲劳 (Tier 0-1): 不显示建议
##   - 中疲劳 (Tier 2): 以 INFO 类型 Toast 显示，每 15 秒最多一条
##   - 高疲劳 (Tier 3): 以 WARNING 类型 Toast 显示，每 10 秒最多一条
##   - 建议文本根据疲劳分量动态生成，避免重复
##
## 关联文档：Docs/AestheticFatigueSystem_Documentation.md
extends Node

# ============================================================
# 配置
# ============================================================

## 中疲劳建议间隔（秒）
const SUGGESTION_INTERVAL_MODERATE: float = 15.0
## 高疲劳建议间隔（秒）
const SUGGESTION_INTERVAL_SEVERE: float = 10.0
## 建议显示持续时间（秒）
const SUGGESTION_DURATION: float = 4.0
## 建议去重窗口：同一条建议在此时间内不会重复显示
const DEDUP_WINDOW: float = 30.0
## 中疲劳 AFI 阈值
const MODERATE_THRESHOLD: float = 0.5
## 高疲劳 AFI 阈值
const SEVERE_THRESHOLD: float = 0.7

# ============================================================
# 状态
# ============================================================

## 上次显示建议的时间
var _last_suggestion_time: float = -999.0
## 最近显示过的建议文本（用于去重）
var _recent_suggestions: Array[Dictionary] = []  # [{ "text": String, "time": float }]
## Toast 通知系统引用
var _toast_system: Node = null
## HUD 中的建议标签引用（旧版兼容）
var _suggestion_label: Label = null

# ============================================================
# 初始化
# ============================================================

## 初始化控制器
func initialize(toast_system: Node = null, suggestion_label: Label = null) -> void:
	_toast_system = toast_system
	_suggestion_label = suggestion_label

	# 连接 FatigueManager 信号
	if FatigueManager.has_signal("recovery_suggestion"):
		FatigueManager.recovery_suggestion.connect(_on_recovery_suggestion)
	if FatigueManager.has_signal("afi_changed"):
		FatigueManager.afi_changed.connect(_on_afi_changed)
	if FatigueManager.has_signal("fatigue_level_changed"):
		FatigueManager.fatigue_level_changed.connect(_on_fatigue_level_changed)

# ============================================================
# 信号回调
# ============================================================

## 收到恢复建议信号
func _on_recovery_suggestion(message: String) -> void:
	_try_show_suggestion(message)

## AFI 值变化回调 — 用于主动检查是否需要显示建议
func _on_afi_changed(afi_value: float, _fatigue_tier: int) -> void:
	# 只在中/高疲劳时主动检查
	if afi_value < MODERATE_THRESHOLD:
		return

	var current_time := _get_game_time()
	var interval := SUGGESTION_INTERVAL_SEVERE if afi_value >= SEVERE_THRESHOLD else SUGGESTION_INTERVAL_MODERATE

	# 检查是否到了可以显示下一条建议的时间
	if current_time - _last_suggestion_time < interval:
		return

	# 主动从 FatigueManager 获取建议
	if FatigueManager.has_method("get_recovery_suggestions"):
		var suggestions: Array[String] = FatigueManager.get_recovery_suggestions()
		if not suggestions.is_empty():
			# 选择一条未重复的建议
			var chosen := _pick_non_duplicate(suggestions)
			if not chosen.is_empty():
				_show_suggestion(chosen, afi_value)

## 疲劳等级变化回调 — Tier 升高时立即显示一条建议
func _on_fatigue_level_changed(level: MusicData.FatigueLevel) -> void:
	# 只在升到中/高疲劳时触发
	if level == MusicData.FatigueLevel.MODERATE or level == MusicData.FatigueLevel.SEVERE or level == MusicData.FatigueLevel.CRITICAL:
		var current_time := _get_game_time()
		# 等级变化时忽略间隔限制，但至少间隔 3 秒
		if current_time - _last_suggestion_time < 3.0:
			return

		if FatigueManager.has_method("get_recovery_suggestions"):
			var suggestions: Array[String] = FatigueManager.get_recovery_suggestions()
			if not suggestions.is_empty():
				var chosen := _pick_non_duplicate(suggestions)
				if not chosen.is_empty():
					_show_suggestion(chosen, FatigueManager.current_afi)

# ============================================================
# 建议显示逻辑
# ============================================================

## 尝试显示建议（带节流和去重）
func _try_show_suggestion(message: String) -> void:
	var current_time := _get_game_time()
	var afi := FatigueManager.current_afi

	# 低疲劳时不显示
	if afi < MODERATE_THRESHOLD:
		return

	# 节流检查
	var interval := SUGGESTION_INTERVAL_SEVERE if afi >= SEVERE_THRESHOLD else SUGGESTION_INTERVAL_MODERATE
	if current_time - _last_suggestion_time < interval:
		return

	# 去重检查
	if _is_recently_shown(message, current_time):
		return

	_show_suggestion(message, afi)

## 实际显示建议
func _show_suggestion(message: String, afi: float) -> void:
	var current_time := _get_game_time()
	_last_suggestion_time = current_time

	# 记录到去重列表
	_recent_suggestions.append({"text": message, "time": current_time})
	_cleanup_dedup_list(current_time)

	# 确定显示类型
	var is_severe := afi >= SEVERE_THRESHOLD

	# 方式1：通过 Toast 通知系统显示（优先）
	if _toast_system and _toast_system.has_method("show_toast"):
		var toast_type: int = 2 if is_severe else 0  # WARNING = 2, INFO = 0
		var subtitle := "疲劳度: %d%%" % int(afi * 100.0)
		_toast_system.show_toast(message, toast_type, SUGGESTION_DURATION, subtitle)

	# 方式2：更新 HUD 中的建议标签（旧版兼容）
	if _suggestion_label:
		_suggestion_label.text = message
		var suggestion_color: Color
		if is_severe:
			suggestion_color = UIColors.DANGER
		else:
			suggestion_color = UIColors.GOLD
		_suggestion_label.add_theme_color_override("font_color", suggestion_color)

# ============================================================
# 辅助方法
# ============================================================

## 从建议列表中选择一条未重复的
func _pick_non_duplicate(suggestions: Array[String]) -> String:
	var current_time := _get_game_time()
	_cleanup_dedup_list(current_time)

	for suggestion in suggestions:
		if not _is_recently_shown(suggestion, current_time):
			return suggestion

	# 所有建议都最近显示过，返回第一条（强制显示）
	if not suggestions.is_empty():
		return suggestions[0]
	return ""

## 检查某条建议是否最近显示过
func _is_recently_shown(message: String, current_time: float) -> bool:
	for entry in _recent_suggestions:
		if entry["text"] == message and current_time - entry["time"] < DEDUP_WINDOW:
			return true
	return false

## 清理过期的去重记录
func _cleanup_dedup_list(current_time: float) -> void:
	var to_remove: Array[int] = []
	for i in range(_recent_suggestions.size()):
		if current_time - _recent_suggestions[i]["time"] > DEDUP_WINDOW:
			to_remove.append(i)
	# 从后往前删除
	to_remove.reverse()
	for idx in to_remove:
		_recent_suggestions.remove_at(idx)

## 获取游戏时间
func _get_game_time() -> float:
	if GameManager.get("game_time") != null:
		return GameManager.game_time
	return Time.get_ticks_msec() / 1000.0

# ============================================================
# 清理
# ============================================================

func cleanup() -> void:
	if FatigueManager.has_signal("recovery_suggestion"):
		if FatigueManager.recovery_suggestion.is_connected(_on_recovery_suggestion):
			FatigueManager.recovery_suggestion.disconnect(_on_recovery_suggestion)
	if FatigueManager.has_signal("afi_changed"):
		if FatigueManager.afi_changed.is_connected(_on_afi_changed):
			FatigueManager.afi_changed.disconnect(_on_afi_changed)
	if FatigueManager.has_signal("fatigue_level_changed"):
		if FatigueManager.fatigue_level_changed.is_connected(_on_fatigue_level_changed):
			FatigueManager.fatigue_level_changed.disconnect(_on_fatigue_level_changed)
