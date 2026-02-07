## music_theory_engine.gd
## 音乐理论引擎 (Autoload)
## 负责和弦识别、和弦功能判定、和弦进行分析等乐理计算
extends Node

# ============================================================
# 信号
# ============================================================
signal chord_identified(chord_type: MusicData.ChordType, root_note: int)
signal progression_triggered(effect_type: String, bonus_multiplier: float)

# ============================================================
# 和弦进行追踪
# ============================================================
var _chord_history: Array[Dictionary] = []  # { "type": ChordType, "function": ChordFunction, "time": float }
const MAX_CHORD_HISTORY: int = 8

# ============================================================
# 和弦识别
# ============================================================

	## 从一组音符中识别和弦类型
	## notes: Array[int] - MIDI音符编号或 Note 枚举值
	## 返回: { "type": ChordType, "root": int, "quality": String } 或 null
	## Issue #18: 黑键双重身份 - 黑键在和弦构建窗口内参与和弦类型判定
	func identify_chord(notes: Array) -> Variant:
		if notes.size() < 3:
			return null
	
		# 将音符归一化到一个八度内 (0-11)
		# Issue #18: 黑键也参与和弦判定，不再过滤
		var pitch_classes: Array[int] = []
		for n in notes:
			var pc: int = n % 12
			if pc not in pitch_classes:
				pitch_classes.append(pc)
	
		pitch_classes.sort()
	
		if pitch_classes.size() < 3:
			return null

	# 尝试每个音作为根音
	for root_idx in range(pitch_classes.size()):
		var root: int = pitch_classes[root_idx]
		var intervals: Array[int] = []

		for i in range(pitch_classes.size()):
			var interval: int = (pitch_classes[(root_idx + i) % pitch_classes.size()] - root + 12) % 12
			intervals.append(interval)

		intervals.sort()

		# 匹配和弦模板
		var chord_type = _match_chord_template(intervals)
		if chord_type != null:
			return {
				"type": chord_type,
				"root": root,
				"intervals": intervals,
			}

	return null

## 匹配和弦模板
func _match_chord_template(intervals: Array) -> Variant:
	# 将 intervals 转为 Array[int] 以便比较
	var int_arr: Array[int] = []
	for i in intervals:
		int_arr.append(i)

	for chord_type in MusicData.CHORD_INTERVALS:
		var template: Array = MusicData.CHORD_INTERVALS[chord_type]
		# 将模板也归一化到一个八度
		var norm_template: Array[int] = []
		for t in template:
			norm_template.append(t % 12)
		norm_template.sort()

		# 去重
		var unique_template: Array[int] = []
		for t in norm_template:
			if t not in unique_template:
				unique_template.append(t)

		if int_arr == unique_template:
			return chord_type

	return null

# ============================================================
# 和弦功能判定
# ============================================================

## 判断和弦在当前调性中的功能
## 简化版：基于和弦类型直接判定
func get_chord_function(chord_type: MusicData.ChordType) -> MusicData.ChordFunction:
	match chord_type:
		# 主功能 (T) - 稳定和弦
		MusicData.ChordType.MAJOR, MusicData.ChordType.MAJOR_7, \
		MusicData.ChordType.MAJOR_9:
			return MusicData.ChordFunction.TONIC

		# 属功能 (D) - 紧张和弦
		MusicData.ChordType.DOMINANT_7, MusicData.ChordType.DIMINISHED, \
		MusicData.ChordType.DIMINISHED_7, MusicData.ChordType.DIMINISHED_9, \
		MusicData.ChordType.DIMINISHED_13:
			return MusicData.ChordFunction.DOMINANT

		# 下属功能 (PD) - 准备和弦
		MusicData.ChordType.MINOR, MusicData.ChordType.MINOR_7, \
		MusicData.ChordType.AUGMENTED, MusicData.ChordType.SUSPENDED, \
		MusicData.ChordType.DOMINANT_9, MusicData.ChordType.DOMINANT_11, \
		MusicData.ChordType.DOMINANT_13:
			return MusicData.ChordFunction.PREDOMINANT

		_:
			return MusicData.ChordFunction.TONIC

# ============================================================
# 和弦进行分析
# ============================================================

## 记录一个和弦并分析进行效果
func record_chord(chord_type: MusicData.ChordType) -> Dictionary:
	var chord_func := get_chord_function(chord_type)
	var entry := {
		"type": chord_type,
		"function": chord_func,
		"time": GameManager.game_time,
	}

	_chord_history.append(entry)
	if _chord_history.size() > MAX_CHORD_HISTORY:
		_chord_history.pop_front()

	chord_identified.emit(chord_type, 0)

	# 分析进行效果
	return _analyze_progression()

## 分析最近的和弦进行
func _analyze_progression() -> Dictionary:
	if _chord_history.size() < 2:
		return {}

	var prev = _chord_history[-2]
	var curr = _chord_history[-1]

	var prev_func: MusicData.ChordFunction = prev["function"]
	var curr_func: MusicData.ChordFunction = curr["function"]

	var transition_key := ""

	# D → T (紧张到解决)
	if prev_func == MusicData.ChordFunction.DOMINANT and curr_func == MusicData.ChordFunction.TONIC:
		transition_key = "D_to_T"
	# T → D (稳定到紧张)
	elif prev_func == MusicData.ChordFunction.TONIC and curr_func == MusicData.ChordFunction.DOMINANT:
		transition_key = "T_to_D"
	# PD → D (准备到紧张)
	elif prev_func == MusicData.ChordFunction.PREDOMINANT and curr_func == MusicData.ChordFunction.DOMINANT:
		transition_key = "PD_to_D"

	if transition_key.is_empty():
		return {}

	# 计算完整度奖励
	var completeness := _calculate_completeness()
	var bonus_multiplier: float = MusicData.COMPLETENESS_BONUS.get(completeness, 1.0)

	var effect = MusicData.PROGRESSION_EFFECTS.get(transition_key, {})
	if not effect.is_empty():
		progression_triggered.emit(effect["type"], bonus_multiplier)

	return {
		"transition": transition_key,
		"effect": effect,
		"completeness": completeness,
		"bonus_multiplier": bonus_multiplier,
	}

## 计算最近和弦进行的完整度 (连续有效转换的数量)
func _calculate_completeness() -> int:
	if _chord_history.size() < 2:
		return 0

	var count := 0
	# 从最近的开始向前检查连续有效转换
	for i in range(_chord_history.size() - 1, 0, -1):
		var curr_func = _chord_history[i]["function"]
		var prev_func = _chord_history[i - 1]["function"]

		if curr_func != prev_func:  # 有功能转换
			count += 1
		else:
			break

		if count >= 4:
			break

	return min(count + 1, 4)  # 2-4和弦

# ============================================================
# 不和谐度计算
# ============================================================

## 计算和弦的不和谐度
func get_chord_dissonance(chord_type: MusicData.ChordType) -> float:
	return MusicData.CHORD_DISSONANCE.get(chord_type, 0.0)

## 计算音程的不和谐度
func get_interval_dissonance(semitones: int) -> float:
	# 基于音程的协和度排序
	var dissonance_map := {
		0: 0.0,   # 纯一度 (完全协和)
		7: 0.5,   # 纯五度
		5: 1.0,   # 纯四度
		4: 1.5,   # 大三度
		3: 2.0,   # 小三度
		9: 2.0,   # 大六度
		8: 2.5,   # 小六度
		2: 3.0,   # 大二度
		10: 3.5,  # 小七度
		11: 4.0,  # 大七度
		1: 5.0,   # 小二度 (最不和谐)
		6: 4.5,   # 三全音
	}
	return dissonance_map.get(semitones % 12, 3.0)

# ============================================================
# 工具函数
# ============================================================

## 获取和弦的法术形态信息
func get_spell_form_info(chord_type: MusicData.ChordType) -> Dictionary:
	return MusicData.CHORD_SPELL_MAP.get(chord_type, {})

## 检查和弦是否为扩展和弦
func is_extended_chord(chord_type: MusicData.ChordType) -> bool:
	return chord_type in [
		MusicData.ChordType.DOMINANT_9,
		MusicData.ChordType.MAJOR_9,
		MusicData.ChordType.DIMINISHED_9,
		MusicData.ChordType.DOMINANT_11,
		MusicData.ChordType.DOMINANT_13,
		MusicData.ChordType.DIMINISHED_13,
	]

## 清除历史
func clear_history() -> void:
	_chord_history.clear()
