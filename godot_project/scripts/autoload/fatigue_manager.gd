## fatigue_manager.gd
## 听感疲劳管理器 (Autoload)
## GDScript 版本的 AestheticFatigueEngine
## 基于信息论、递归量化分析和翁特曲线理论
##
## v2.0 更新：
##   - 实现"单音寂静"惩罚：重复使用同一音符会导致该音符暂时禁用
##   - 实现"密度过载"惩罚：音符堆太满时降低精准度（弹体散射偏移）
##   - 实现"不和谐值"连接：不和谐法术直接扣血（生命腐蚀），由 GameManager 处理
##   - 三维惩罚模型完整落地
extends Node

# ============================================================
# 信号
# ============================================================
signal fatigue_updated(result: Dictionary)
signal fatigue_level_changed(level: MusicData.FatigueLevel)
signal recovery_suggestion(message: String)
## 新增：单音寂静信号 — 当某个音符被禁用/解禁时发出
signal note_silenced(note: MusicData.WhiteKey, duration: float)
signal note_unsilenced(note: MusicData.WhiteKey)
## 新增：密度过载信号 — 当密度过载状态变化时发出
signal density_overload_changed(is_overloaded: bool, accuracy_penalty: float)

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
# 单音寂静系统配置
# ============================================================

## 单音寂静触发阈值：在窗口内同一音符使用次数超过此值则触发寂静
const SILENCE_TRIGGER_COUNT: int = 4
## 单音寂静基础持续时间（秒）
const SILENCE_BASE_DURATION: float = 3.0
## 单音寂静叠加系数：每多使用一次，额外增加的寂静时间
const SILENCE_STACK_DURATION: float = 1.0
## 单音寂静短窗口（秒）：在此窗口内计算重复使用次数
const SILENCE_WINDOW: float = 8.0

# ============================================================
# 密度过载系统配置
# ============================================================

## 密度过载触发阈值：最近3秒内施法次数超过此值则触发
const DENSITY_OVERLOAD_THRESHOLD: int = 8
## 密度过载精准度惩罚：弹体散射偏移角度（弧度）
const DENSITY_OVERLOAD_ACCURACY_PENALTY: float = 0.3
## 密度过载严重精准度惩罚
const DENSITY_OVERLOAD_SEVERE_PENALTY: float = 0.6
## 密度过载检测窗口（秒）
const DENSITY_OVERLOAD_WINDOW: float = 3.0

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
# 单音寂静状态
# ============================================================

## 被寂静的音符及其解禁时间 { WhiteKey: expiry_time }
var _silenced_notes: Dictionary = {}

## 每个音符在短窗口内的使用计数（带时间衰减）
var _note_use_counts: Dictionary = {}

# ============================================================
# 密度过载状态
# ============================================================

## 当前是否处于密度过载状态
var is_density_overloaded: bool = false

## 当前精准度惩罚值 (0.0 = 无惩罚, 越高散射越大)
var current_accuracy_penalty: float = 0.0

# ============================================================
# 衰减常数
# ============================================================
var _decay_lambda: float = 0.0

func _ready() -> void:
	_decay_lambda = log(2.0) / decay_half_life

func _process(delta: float) -> void:
	# 更新单音寂静计时器
	_update_silenced_notes()
	# 更新密度过载状态
	_update_density_overload()

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

	# 更新单音使用计数（用于单音寂静判定）
	var note = event.get("note", -1)
	if note >= 0 and not event.get("is_chord", false):
		_record_note_use(note, current_time)

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
	result["silenced_notes"] = get_silenced_notes()
	result["density_overloaded"] = is_density_overloaded
	result["accuracy_penalty"] = current_accuracy_penalty

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
	result["silenced_notes"] = get_silenced_notes()
	result["density_overloaded"] = is_density_overloaded
	result["accuracy_penalty"] = current_accuracy_penalty
	return result

## 获取每个音符的独立疲劳度
func get_note_fatigue_map() -> Dictionary:
	var current_time := GameManager.game_time
	var note_weights: Dictionary = {}
	var total_weight: float = 0.0

	for event in _event_history:
		var weight := _time_weight(current_time, event["time"])
		var note = event.get("note", -1)
		if note >= 0:
			note_weights[note] = note_weights.get(note, 0.0) + weight
			total_weight += weight

	var fatigue_map: Dictionary = {}
	if total_weight > 0.0:
		for note in note_weights:
			fatigue_map[note] = clampf(note_weights[note] / total_weight * 2.0, 0.0, 1.0)

	return fatigue_map

# ============================================================
# 单音寂静系统
# ============================================================

## 记录音符使用（用于单音寂静判定）
func _record_note_use(note: int, current_time: float) -> void:
	if not _note_use_counts.has(note):
		_note_use_counts[note] = []

	# 记录使用时间戳
	_note_use_counts[note].append(current_time)

	# 清理过期记录
	var timestamps: Array = _note_use_counts[note]
	while not timestamps.is_empty() and current_time - timestamps[0] > SILENCE_WINDOW:
		timestamps.pop_front()

	# 检查是否触发单音寂静
	var use_count: int = timestamps.size()
	if use_count >= SILENCE_TRIGGER_COUNT and not is_note_silenced(note):
		var white_key := _note_int_to_white_key(note)
		if white_key >= 0:
			var extra_stacks: int = use_count - SILENCE_TRIGGER_COUNT
			var silence_duration: float = SILENCE_BASE_DURATION + extra_stacks * SILENCE_STACK_DURATION
			# 应用单调抗性
			silence_duration *= (1.0 - _monotony_resistance)
			_silence_note(white_key, silence_duration)

## 使某个音符进入寂静状态
func _silence_note(white_key: int, duration: float) -> void:
	var expiry_time: float = GameManager.game_time + duration
	_silenced_notes[white_key] = expiry_time
	note_silenced.emit(white_key, duration)

## 更新寂静音符计时器
func _update_silenced_notes() -> void:
	var current_time := GameManager.game_time
	var to_remove: Array = []

	for note_key in _silenced_notes:
		if current_time >= _silenced_notes[note_key]:
			to_remove.append(note_key)

	for note_key in to_remove:
		_silenced_notes.erase(note_key)
		note_unsilenced.emit(note_key)

## 检查某个音符是否被寂静
func is_note_silenced(note) -> bool:
	# 支持 WhiteKey 枚举或 int
	if _silenced_notes.has(note):
		return GameManager.game_time < _silenced_notes[note]
	# 也检查从 int 转换的 WhiteKey
	var white_key = _note_int_to_white_key(note) if note is int and note > 6 else note
	if white_key >= 0 and _silenced_notes.has(white_key):
		return GameManager.game_time < _silenced_notes[white_key]
	return false

## 获取所有被寂静的音符列表
func get_silenced_notes() -> Array:
	var result: Array = []
	var current_time := GameManager.game_time
	for note_key in _silenced_notes:
		if current_time < _silenced_notes[note_key]:
			result.append({
				"note": note_key,
				"remaining": _silenced_notes[note_key] - current_time,
			})
	return result

## 使用不和谐法术可以缓解单调值（关键交互：不和谐是双刃剑）
func reduce_monotony_from_dissonance(dissonance: float) -> void:
	# 不和谐法术引入了变化，可以降低单调值
	# 每点不和谐度可以减少 0.5 秒的寂静时间
	var reduction: float = dissonance * 0.5
	var current_time := GameManager.game_time
	for note_key in _silenced_notes:
		_silenced_notes[note_key] = max(current_time, _silenced_notes[note_key] - reduction)

# ============================================================
# 密度过载系统
# ============================================================

## 更新密度过载状态
func _update_density_overload() -> void:
	var current_time := GameManager.game_time
	var recent_count := 0

	for event in _event_history:
		if current_time - event["time"] < DENSITY_OVERLOAD_WINDOW:
			recent_count += 1

	# BPM 相关的动态阈值
	var beat_rate := GameManager.current_bpm / 60.0
	var dynamic_threshold := int(beat_rate * DENSITY_OVERLOAD_WINDOW * 1.2)
	var effective_threshold = max(DENSITY_OVERLOAD_THRESHOLD, dynamic_threshold)

	# 应用密度抗性
	effective_threshold = int(float(effective_threshold) * (1.0 + _density_resistance))

	var was_overloaded := is_density_overloaded

	if recent_count > effective_threshold:
		is_density_overloaded = true
		# 根据超出程度计算精准度惩罚
		var excess_ratio := float(recent_count - effective_threshold) / float(effective_threshold)
		if excess_ratio > 0.5:
			current_accuracy_penalty = DENSITY_OVERLOAD_SEVERE_PENALTY
		else:
			current_accuracy_penalty = DENSITY_OVERLOAD_ACCURACY_PENALTY
	else:
		is_density_overloaded = false
		current_accuracy_penalty = 0.0

	# 状态变化时发出信号
	if was_overloaded != is_density_overloaded:
		density_overload_changed.emit(is_density_overloaded, current_accuracy_penalty)

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
		var parts = key.split("_")
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
func _calc_rest_deficit(events: Array, _current_time: float) -> float:
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
# 惩罚计算（增强版：包含三维惩罚）
# ============================================================

func _calculate_penalty() -> Dictionary:
	var result := {
		"damage_multiplier": 1.0,
		"is_locked": false,
		"global_debuff": 0.0,
		# 新增三维惩罚信息
		"silenced_notes": get_silenced_notes(),
		"density_overloaded": is_density_overloaded,
		"accuracy_penalty": current_accuracy_penalty,
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
# 恢复建议（增强版：包含三维惩罚建议）
# ============================================================

func _generate_suggestions() -> Array[String]:
	var suggestions: Array[String] = []

	if _fatigue_components.is_empty():
		return suggestions

	# 单音寂静建议
	var silenced := get_silenced_notes()
	if not silenced.is_empty():
		var note_names: Array[String] = []
		for s in silenced:
			var wk: int = s["note"]
			if wk >= 0 and wk < MusicData.WHITE_KEY_STATS.size():
				var stats = MusicData.WHITE_KEY_STATS.values()[wk]
				note_names.append(stats.get("name", "?"))
		if not note_names.is_empty():
			suggestions.append("音符 %s 已进入寂静！使用其他音符来恢复多样性" % ", ".join(note_names))

	# 密度过载建议
	if is_density_overloaded:
		suggestions.append("密度过载！施法太密集了，弹体精准度大幅下降。编入休止符留出空拍！")

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

## 将 int 音符值转为 WhiteKey 枚举
func _note_int_to_white_key(note: int) -> int:
	var pc := note % 12 if note > 6 else note
	match pc:
		0: return MusicData.WhiteKey.C
		2: return MusicData.WhiteKey.D
		4: return MusicData.WhiteKey.E
		5: return MusicData.WhiteKey.F
		7: return MusicData.WhiteKey.G
		9: return MusicData.WhiteKey.A
		11: return MusicData.WhiteKey.B
		_:
			# 如果 note 本身就是 WhiteKey 枚举值 (0-6)
			if note >= 0 and note <= 6:
				return note
			return -1

## 外部疲劳注入（供 Silence 敌人等调用）
func add_external_fatigue(amount: float) -> void:
	current_afi = clampf(current_afi + amount, 0.0, 1.0)

	# 重新判定疲劳等级
	var new_level := _determine_level(current_afi)
	if new_level != current_level:
		current_level = new_level
		fatigue_level_changed.emit(current_level)

	# 发出更新信号
	var result := {
		"afi": current_afi,
		"components": _fatigue_components,
		"level": current_level,
		"penalty": _calculate_penalty(),
	}
	fatigue_updated.emit(result)

# ============================================================
# 留白奖励机制（休止符主动清除负面状态）
# ============================================================

## 休止符奖励配置
const REST_CLEANSE_THRESHOLD: int = 2  ## 连续休止符数量达到此值时触发清洗
const REST_SILENCE_REDUCTION: float = 1.5  ## 每次清洗减少的寂静时间（秒）
const REST_FATIGUE_REDUCTION: float = 0.03  ## 每次清洗减少的疲劳度
const REST_DENSITY_COOLDOWN: float = 1.0  ## 清洗后密度过载的额外冷却时间

## 连续休止符计数器
var _consecutive_rest_count: int = 0

## 留白奖励信号
signal rest_cleanse_triggered(rest_count: int)

## 记录休止符（由 SpellcraftSystem 在序列器播放休止符时调用）
func record_rest() -> void:
	_consecutive_rest_count += 1

	if _consecutive_rest_count >= REST_CLEANSE_THRESHOLD:
		_apply_rest_cleanse()

## 重置休止符计数（当施法时重置）
func reset_rest_counter() -> void:
	_consecutive_rest_count = 0

## 应用休止符清洗效果
func _apply_rest_cleanse() -> void:
	var current_time := GameManager.game_time

	# 获取局外升级的休止符效率加成
	var rest_efficiency_bonus: float = 0.0
	if GameManager.has_meta("meta_rest_efficiency_bonus"):
		rest_efficiency_bonus = GameManager.get_meta("meta_rest_efficiency_bonus")
	var efficiency_mult: float = 1.0 + rest_efficiency_bonus  # 例如 +45% = 1.45倍

	# 1. 减少所有被寂静音符的剩余时间（应用休止符效率加成）
	var effective_silence_reduction: float = REST_SILENCE_REDUCTION * efficiency_mult
	var cleansed_notes: Array = []
	for note_key in _silenced_notes:
		_silenced_notes[note_key] -= effective_silence_reduction
		if _silenced_notes[note_key] <= current_time:
			cleansed_notes.append(note_key)

	for note_key in cleansed_notes:
		_silenced_notes.erase(note_key)
		note_unsilenced.emit(note_key)

	# 2. 减少总体疲劳度（应用休止符效率加成）
	var effective_fatigue_reduction: float = REST_FATIGUE_REDUCTION * efficiency_mult
	current_afi = clampf(current_afi - effective_fatigue_reduction, 0.0, 1.0)

	# 3. 缓解密度过载（减少近期施法记录的影响）
	if is_density_overloaded:
		current_accuracy_penalty = max(0.0, current_accuracy_penalty - 0.15)
		if current_accuracy_penalty <= 0.0:
			is_density_overloaded = false
			density_overload_changed.emit(false, 0.0)

	# 4. 重新判定疲劳等级
	var new_level := _determine_level(current_afi)
	if new_level != current_level:
		current_level = new_level
		fatigue_level_changed.emit(current_level)

	rest_cleanse_triggered.emit(_consecutive_rest_count)

	# 发出更新信号
	var result := {
		"afi": current_afi,
		"components": _fatigue_components,
		"level": current_level,
		"penalty": _calculate_penalty(),
	}
	fatigue_updated.emit(result)

## 获取当前疲劳度值（便捷接口）
func get_current_fatigue() -> float:
	return current_afi

## 减少疲劳度（击杀 Silence 敌人的奖励）
func reduce_fatigue(amount: float) -> void:
	current_afi = clampf(current_afi - amount, 0.0, 1.0)

	var new_level := _determine_level(current_afi)
	if new_level != current_level:
		current_level = new_level
		fatigue_level_changed.emit(current_level)

	var result := {
		"afi": current_afi,
		"components": _fatigue_components,
		"level": current_level,
		"penalty": _calculate_penalty(),
	}
	fatigue_updated.emit(result)

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
	# 重置单音寂静
	_silenced_notes.clear()
	_note_use_counts.clear()
	# 重置密度过载
	is_density_overloaded = false
	current_accuracy_penalty = 0.0
	# 重置留白计数器
	_consecutive_rest_count = 0
