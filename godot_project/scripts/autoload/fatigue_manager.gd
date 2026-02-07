## fatigue_manager.gd
## 听感疲劳管理器 (Autoload)
## GDScript 版本的 AestheticFatigueEngine
## 基于信息论、递归量化分析和翁特曲线理论
extends Node

# ============================================================
# 信号
# ============================================================
signal fatigue_updated(result: Dictionary)
signal fatigue_level_changed(level: MusicData.FatigueLevel)
signal note_locked(note: MusicData.WhiteKey)
signal recovery_suggestion(message: String)

# ============================================================
# 配置
# ============================================================

## 滑动窗口时长（秒）
@export var window_duration: float = 15.0
## 时间衰减半衰期（秒）
@export var decay_half_life: float = 5.0

## AFI 权重
var weights := {
	"pitch_entropy": 0.20,
	"transition_entropy": 0.15,
	"rhythm_entropy": 0.10,
	"chord_diversity": 0.10,
	"recurrence": 0.10,
	"density": 0.15,
	"rest_deficit": 0.10,
	"sustained_pressure": 0.10,
}

## 疲劳等级阈值
var thresholds := {
	MusicData.FatigueLevel.MILD: 0.3,
	MusicData.FatigueLevel.MODERATE: 0.5,
	MusicData.FatigueLevel.SEVERE: 0.7,
	MusicData.FatigueLevel.CRITICAL: 0.85,
}

## 惩罚模式
enum PenaltyMode { WEAKEN, LOCKOUT, GLOBAL_DEBUFF }
var penalty_mode: PenaltyMode = PenaltyMode.WEAKEN

## 削弱系数
var weaken_multipliers := {
	MusicData.FatigueLevel.NONE: 1.0,
	MusicData.FatigueLevel.MILD: 0.85,
	MusicData.FatigueLevel.MODERATE: 0.65,
	MusicData.FatigueLevel.SEVERE: 0.40,
	MusicData.FatigueLevel.CRITICAL: 0.15,
}

# ============================================================
# 状态
# ============================================================

## 法术事件历史 [{ "time": float, "note": int, "is_chord": bool, "chord_type": int }]
var _event_history: Array[Dictionary] = []

## 当前 AFI (0.0 ~ 1.0)
var current_afi: float = 0.0

## 当前疲劳等级
var current_level: MusicData.FatigueLevel = MusicData.FatigueLevel.NONE

## 各维度分量
var _fatigue_components: Dictionary = {}

## 上次施法时间
var _last_cast_time: float = -10.0

## 连续施法计数
var _continuous_cast_count: int = 0

## 连续施法起始时间
var _continuous_cast_start: float = 0.0

## 抗性加成 (来自升级)
var _monotony_resistance: float = 0.0
var _dissonance_decay_bonus: float = 0.0
var _density_resistance: float = 0.0

# ============================================================
# 衰减常数
# ============================================================
var _decay_lambda: float = 0.0

func _ready() -> void:
	_decay_lambda = log(2.0) / decay_half_life

# ============================================================
# 核心接口
# ============================================================

## 记录一次法术施放事件
func record_spell(event: Dictionary) -> Dictionary:
	var current_time: float = event.get("time", GameManager.game_time)

	_event_history.append(event)
	_cleanup_old_events(current_time)

	# 更新连续施法追踪
	var time_since_last := current_time - _last_cast_time
	if time_since_last < 1.0:
		_continuous_cast_count += 1
	else:
		_continuous_cast_count = 1
		_continuous_cast_start = current_time
	_last_cast_time = current_time

	# 计算 AFI
	var result := _calculate_afi(current_time)
	current_afi = result["afi"]

	# 判定疲劳等级
	var new_level := _determine_level(current_afi)
	if new_level != current_level:
		current_level = new_level
		fatigue_level_changed.emit(current_level)

	# 计算惩罚
	result["level"] = current_level
	result["penalty"] = _calculate_penalty()
	result["suggestions"] = _generate_suggestions()

	fatigue_updated.emit(result)

	# 发送恢复建议
	for suggestion in result["suggestions"]:
		recovery_suggestion.emit(suggestion)

	return result

## 查询当前疲劳状态（不记录新事件）
func query_fatigue() -> Dictionary:
	var current_time := GameManager.game_time
	_cleanup_old_events(current_time)
	var result := _calculate_afi(current_time)
	result["level"] = current_level
	result["penalty"] = _calculate_penalty()
	return result

## 获取每个音符的独立疲劳度
func get_note_fatigue_map() -> Dictionary:
	var current_time := GameManager.game_time
	var note_counts: Dictionary = {}
	var total_weight: float = 0.0

	for event in _event_history:
		var weight := _time_weight(current_time, event["time"])
		var note = event.get("note", -1)
		if note >= 0:
			note_counts[note] = note_counts.get(note, 0.0) + weight
			total_weight += weight

	var fatigue_map: Dictionary = {}
	if total_weight > 0.0:
		for note in note_counts:
			fatigue_map[note] = clampf(note_counts[note] / total_weight * 2.0, 0.0, 1.0)

	return fatigue_map

# ============================================================
# AFI 计算
# ============================================================

func _calculate_afi(current_time: float) -> Dictionary:
	var events := _get_weighted_events(current_time)

	if events.is_empty():
		_fatigue_components = {}
		return { "afi": 0.0, "components": {} }

	# 计算各维度
	var f_pitch := _calc_pitch_fatigue(events)
	var f_transition := _calc_transition_fatigue(events)
	var f_rhythm := _calc_rhythm_fatigue(events)
	var f_chord := _calc_chord_fatigue(events)
	var f_ngram := _calc_ngram_fatigue(events)
	var f_density := _calc_density_fatigue(events, current_time)
	var f_rest := _calc_rest_deficit(events, current_time)
	var f_sustained := _calc_sustained_pressure(current_time)

	# 应用抗性
	f_pitch *= (1.0 - _monotony_resistance)
	f_density *= (1.0 - _density_resistance)

	_fatigue_components = {
		"pitch": f_pitch,
		"transition": f_transition,
		"rhythm": f_rhythm,
		"chord": f_chord,
		"ngram": f_ngram,
		"density": f_density,
		"rest": f_rest,
		"sustained": f_sustained,
	}

	# 加权求和
	var afi: float = 0.0
	afi += weights["pitch_entropy"] * f_pitch
	afi += weights["transition_entropy"] * f_transition
	afi += weights["rhythm_entropy"] * f_rhythm
	afi += weights["chord_diversity"] * f_chord
	afi += weights["recurrence"] * f_ngram
	afi += weights["density"] * f_density
	afi += weights["rest_deficit"] * f_rest
	afi += weights["sustained_pressure"] * f_sustained

	afi = clampf(afi, 0.0, 1.0)

	return { "afi": afi, "components": _fatigue_components }

# ============================================================
# 各维度计算
# ============================================================

## 音高疲劳：1 - 香农熵(音符分布)
func _calc_pitch_fatigue(events: Array) -> float:
	var note_weights: Dictionary = {}
	var total: float = 0.0

	for e in events:
		var note = e.get("note", -1)
		if note >= 0:
			note_weights[note] = note_weights.get(note, 0.0) + e["weight"]
			total += e["weight"]

	if total <= 0.0 or note_weights.size() <= 1:
		return 1.0

	var entropy := 0.0
	for note in note_weights:
		var p: float = note_weights[note] / total
		if p > 0.0:
			entropy -= p * log(p) / log(2.0)

	# 归一化：最大熵 = log2(7) ≈ 2.807 (7个白键)
	var max_entropy := log(7.0) / log(2.0)
	return 1.0 - clampf(entropy / max_entropy, 0.0, 1.0)

## 转移疲劳：1 - 转移熵
func _calc_transition_fatigue(events: Array) -> float:
	if events.size() < 2:
		return 0.0

	# 构建转移矩阵
	var transitions: Dictionary = {}  # { "from_to": weight }
	var from_counts: Dictionary = {}

	for i in range(1, events.size()):
		var from_note = events[i - 1].get("note", -1)
		var to_note = events[i].get("note", -1)
		if from_note >= 0 and to_note >= 0:
			var key := "%d_%d" % [from_note, to_note]
			var w: float = min(events[i]["weight"], events[i - 1]["weight"])
			transitions[key] = transitions.get(key, 0.0) + w
			from_counts[from_note] = from_counts.get(from_note, 0.0) + w

	if from_counts.is_empty():
		return 0.0

	var trans_entropy := 0.0
	for key in transitions:
		var parts := key.split("_")
		var from_note := int(parts[0])
		if from_counts.get(from_note, 0.0) > 0.0:
			var p: float = transitions[key] / from_counts[from_note]
			if p > 0.0:
				trans_entropy -= (from_counts[from_note] / _sum_values(from_counts)) * p * log(p) / log(2.0)

	var max_trans_entropy := log(7.0) / log(2.0)
	return 1.0 - clampf(trans_entropy / max_trans_entropy, 0.0, 1.0)

## 节奏疲劳：1 - 节奏间隔熵
func _calc_rhythm_fatigue(events: Array) -> float:
	if events.size() < 3:
		return 0.0

	# 计算时间间隔并量化
	var intervals: Array[float] = []
	for i in range(1, events.size()):
		intervals.append(events[i]["time"] - events[i - 1]["time"])

	# 量化到节拍单位
	var beat_interval := 60.0 / GameManager.current_bpm
	var quantized: Dictionary = {}
	var total := 0.0

	for interval in intervals:
		var q := roundf(interval / (beat_interval * 0.25)) * 0.25  # 量化到16分音符
		q = clampf(q, 0.0, 4.0)
		quantized[q] = quantized.get(q, 0.0) + 1.0
		total += 1.0

	if total <= 1.0:
		return 0.0

	var entropy := 0.0
	for q in quantized:
		var p: float = quantized[q] / total
		if p > 0.0:
			entropy -= p * log(p) / log(2.0)

	var max_entropy := log(8.0) / log(2.0)  # 假设最多8种不同间隔
	return 1.0 - clampf(entropy / max_entropy, 0.0, 1.0)

## 和弦疲劳：1 - 和弦类型熵
func _calc_chord_fatigue(events: Array) -> float:
	var chord_weights: Dictionary = {}
	var total: float = 0.0

	for e in events:
		if e.get("is_chord", false):
			var ct = e.get("chord_type", -1)
			if ct >= 0:
				chord_weights[ct] = chord_weights.get(ct, 0.0) + e["weight"]
				total += e["weight"]

	if total <= 0.0 or chord_weights.size() <= 1:
		return 0.5  # 没有和弦时返回中等值

	var entropy := 0.0
	for ct in chord_weights:
		var p: float = chord_weights[ct] / total
		if p > 0.0:
			entropy -= p * log(p) / log(2.0)

	var max_entropy := log(9.0) / log(2.0)  # 9种基础和弦类型
	return 1.0 - clampf(entropy / max_entropy, 0.0, 1.0)

## 模式疲劳：n-gram 递归率
func _calc_ngram_fatigue(events: Array) -> float:
	if events.size() < 4:
		return 0.0

	var notes: Array[int] = []
	for e in events:
		var n = e.get("note", -1)
		if n >= 0:
			notes.append(n)

	if notes.size() < 4:
		return 0.0

	var total_recurrence := 0.0
	var total_possible := 0.0

	# 检查 2-gram, 3-gram, 4-gram
	for gram_size in [2, 3, 4]:
		var gram_counts: Dictionary = {}
		for i in range(notes.size() - gram_size + 1):
			var gram := ""
			for j in range(gram_size):
				gram += str(notes[i + j]) + ","
			gram_counts[gram] = gram_counts.get(gram, 0) + 1

		for gram in gram_counts:
			if gram_counts[gram] > 1:
				total_recurrence += gram_counts[gram] - 1
			total_possible += 1

	if total_possible <= 0.0:
		return 0.0

	return clampf(total_recurrence / (total_possible * 2.0), 0.0, 1.0)

## 密度疲劳：施法频率过高
func _calc_density_fatigue(events: Array, current_time: float) -> float:
	if events.size() < 2:
		return 0.0

	# 计算最近时间窗口内的事件密度
	var recent_window := 3.0  # 最近3秒
	var recent_count := 0
	for e in events:
		if current_time - e["time"] < recent_window:
			recent_count += 1

	# BPM=120时，每秒2拍，3秒内6拍是正常上限
	var beat_rate := GameManager.current_bpm / 60.0
	var expected_max := beat_rate * recent_window * 1.2  # 允许20%超出

	return clampf((float(recent_count) - expected_max) / expected_max, 0.0, 1.0)

## 留白缺失疲劳
func _calc_rest_deficit(events: Array, current_time: float) -> float:
	if events.size() < 3:
		return 0.0

	# 检查最近事件中是否有足够的间隔
	var gaps := 0
	var total_intervals := 0
	var beat_interval := 60.0 / GameManager.current_bpm

	for i in range(1, events.size()):
		var dt: float = events[i]["time"] - events[i - 1]["time"]
		total_intervals += 1
		if dt > beat_interval * 1.5:  # 超过1.5拍算"留白"
			gaps += 1

	if total_intervals <= 0:
		return 0.0

	var gap_ratio: float = float(gaps) / float(total_intervals)
	# 理想留白比例约 20-30%
	if gap_ratio >= 0.2:
		return 0.0
	else:
		return clampf((0.2 - gap_ratio) / 0.2, 0.0, 1.0)

## 持续施法压力
func _calc_sustained_pressure(current_time: float) -> float:
	if _continuous_cast_count < 5:
		return 0.0

	var duration := current_time - _continuous_cast_start
	# 超过10秒连续施法开始累积压力
	if duration < 10.0:
		return 0.0

	return clampf((duration - 10.0) / 20.0, 0.0, 1.0)

# ============================================================
# 惩罚计算
# ============================================================

func _calculate_penalty() -> Dictionary:
	var result := {
		"damage_multiplier": 1.0,
		"is_locked": false,
		"global_debuff": 0.0,
	}

	match penalty_mode:
		PenaltyMode.WEAKEN:
			result["damage_multiplier"] = weaken_multipliers.get(current_level, 1.0)
		PenaltyMode.LOCKOUT:
			result["is_locked"] = current_level == MusicData.FatigueLevel.CRITICAL
			result["damage_multiplier"] = weaken_multipliers.get(current_level, 1.0)
		PenaltyMode.GLOBAL_DEBUFF:
			result["global_debuff"] = current_afi
			result["damage_multiplier"] = 1.0 - current_afi * 0.5

	return result

func _determine_level(afi: float) -> MusicData.FatigueLevel:
	if afi >= thresholds[MusicData.FatigueLevel.CRITICAL]:
		return MusicData.FatigueLevel.CRITICAL
	elif afi >= thresholds[MusicData.FatigueLevel.SEVERE]:
		return MusicData.FatigueLevel.SEVERE
	elif afi >= thresholds[MusicData.FatigueLevel.MODERATE]:
		return MusicData.FatigueLevel.MODERATE
	elif afi >= thresholds[MusicData.FatigueLevel.MILD]:
		return MusicData.FatigueLevel.MILD
	else:
		return MusicData.FatigueLevel.NONE

# ============================================================
# 恢复建议
# ============================================================

func _generate_suggestions() -> Array[String]:
	var suggestions: Array[String] = []

	if _fatigue_components.is_empty():
		return suggestions

	# 按严重程度排序建议
	if _fatigue_components.get("sustained", 0.0) > 0.5:
		suggestions.append("暂停施法！你已经连续施法太久了，休息一下让旋律呼吸")
	if _fatigue_components.get("density", 0.0) > 0.5:
		suggestions.append("放慢施法节奏，给音乐留出空间")
	if _fatigue_components.get("rest", 0.0) > 0.5:
		suggestions.append("在乐句之间留出空隙，沉默也是音乐的一部分")
	if _fatigue_components.get("pitch", 0.0) > 0.5:
		suggestions.append("尝试使用不同的音符，增加旋律多样性")
	if _fatigue_components.get("transition", 0.0) > 0.5:
		suggestions.append("打破当前的音符序列模式，尝试不同的组合顺序")
	if _fatigue_components.get("rhythm", 0.0) > 0.5:
		suggestions.append("改变施法节奏，尝试不同的时间间隔")
	if _fatigue_components.get("ngram", 0.0) > 0.5:
		suggestions.append("你的乐句在重复！尝试新的旋律组合")

	return suggestions

# ============================================================
# 升级接口
# ============================================================

func apply_resistance_upgrade(upgrade: Dictionary) -> void:
	match upgrade.get("type", ""):
		"monotony_resist":
			_monotony_resistance += upgrade.get("value", 0.1)
		"dissonance_decay":
			_dissonance_decay_bonus += upgrade.get("value", 0.5)
		"density_resist":
			_density_resistance += upgrade.get("value", 0.1)

# ============================================================
# 工具函数
# ============================================================

func _cleanup_old_events(current_time: float) -> void:
	while not _event_history.is_empty() and current_time - _event_history[0]["time"] > window_duration:
		_event_history.pop_front()

func _get_weighted_events(current_time: float) -> Array:
	var weighted: Array = []
	for event in _event_history:
		var w := _time_weight(current_time, event["time"])
		if w > 0.01:
			var e := event.duplicate()
			e["weight"] = w
			weighted.append(e)
	return weighted

func _time_weight(current_time: float, event_time: float) -> float:
	var dt := current_time - event_time
	return exp(-_decay_lambda * dt)

func _sum_values(dict: Dictionary) -> float:
	var total := 0.0
	for key in dict:
		total += dict[key]
	return total

## 重置疲劳系统
func reset() -> void:
	_event_history.clear()
	current_afi = 0.0
	current_level = MusicData.FatigueLevel.NONE
	_fatigue_components.clear()
	_last_cast_time = -10.0
	_continuous_cast_count = 0
	_monotony_resistance = 0.0
	_dissonance_decay_bonus = 0.0
	_density_resistance = 0.0
