## spellcraft_system.gd
## 法术构建系统 (Autoload)
## 管理序列器、手动施法、和弦构建、弹体生成
extends Node

# ============================================================
# 信号
# ============================================================
signal spell_cast(spell_data: Dictionary)
signal chord_cast(chord_data: Dictionary)
signal modifier_applied(modifier: MusicData.ModifierEffect)
signal sequencer_updated(sequence: Array)
signal rhythm_pattern_changed(pattern: MusicData.RhythmPattern)
signal timbre_changed(timbre: MusicData.TimbreType)
signal progression_resolved(progression: Dictionary)

# ============================================================
# 序列器配置
# ============================================================
## 序列器长度：4小节 × 4拍 = 16拍
const SEQUENCER_LENGTH: int = 16
const BEATS_PER_MEASURE: int = 4
const MEASURES: int = 4

# ============================================================
# Buff 系统常量
# ============================================================
## T→D 增伤 Buff 倍率
const EMPOWER_BUFF_MULTIPLIER: float = 2.0
## PD→D 冷却缩减比例
const COOLDOWN_REDUCTION_RATIO: float = 0.5
## D→T 爆发治疗基础量
const BURST_HEAL_BASE: float = 30.0
## D→T 全屏伤害基础量
const BURST_DAMAGE_BASE: float = 50.0
## 生命值阈值（低于此值触发治疗，高于触发伤害）
const BURST_HP_THRESHOLD: float = 0.5

# ============================================================
# 序列器状态
# ============================================================

## 序列器数据：每个位置可以是音符、和弦或休止符
## [{ "type": "note"|"chord"|"rest", "note": WhiteKey, "chord_notes": Array, ... }]
var sequencer: Array[Dictionary] = []

## 当前序列器播放位置
var _sequencer_position: int = 0

## 当前小节的节奏型
var _measure_rhythm_patterns: Array[MusicData.RhythmPattern] = []

## 手动施法槽 (2-4个)
var manual_cast_slots: Array[Dictionary] = []
const MAX_MANUAL_SLOTS: int = 3

## 待生效的黑键修饰符
var _pending_modifier: MusicData.ModifierEffect = -1
var _has_pending_modifier: bool = false

## 当前音色系别
var _current_timbre: MusicData.TimbreType = MusicData.TimbreType.NONE

## 和弦构建缓冲区
var _chord_buffer: Array[int] = []
var _chord_buffer_timeout: float = 0.0
const CHORD_BUFFER_WINDOW: float = 0.3  # 和弦输入窗口（秒）

# ============================================================
# Buff 系统状态
# ============================================================
## T→D: 下一次法术伤害倍率 Buff
var _empower_buff_active: bool = false
var _empower_buff_multiplier: float = 1.0

## 手动施法槽冷却时间 (秒)
var _manual_slot_cooldowns: Array[float] = []
const MANUAL_SLOT_BASE_COOLDOWN: float = 5.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_init_sequencer()
	_init_manual_slots()

	# 连接节拍信号
	GameManager.beat_tick.connect(_on_beat_tick)
	GameManager.half_beat_tick.connect(_on_half_beat_tick)
	GameManager.measure_complete.connect(_on_measure_complete)

func _process(delta: float) -> void:
	# 和弦缓冲区超时处理
	if not _chord_buffer.is_empty():
		_chord_buffer_timeout -= delta
		if _chord_buffer_timeout <= 0.0:
			_flush_chord_buffer()

	# 更新手动施法槽冷却
	_update_manual_slot_cooldowns(delta)

# ============================================================
# 序列器初始化
# ============================================================

func _init_sequencer() -> void:
	sequencer.clear()
	for i in range(SEQUENCER_LENGTH):
		sequencer.append({ "type": "rest" })

	_measure_rhythm_patterns.clear()
	for i in range(MEASURES):
		_measure_rhythm_patterns.append(MusicData.RhythmPattern.REST)

func _init_manual_slots() -> void:
	manual_cast_slots.clear()
	_manual_slot_cooldowns.clear()
	for i in range(MAX_MANUAL_SLOTS):
		manual_cast_slots.append({ "type": "empty" })
		_manual_slot_cooldowns.append(0.0)

# ============================================================
# 序列器编辑
# ============================================================

## 在序列器指定位置放置音符
func set_sequencer_note(position: int, white_key: MusicData.WhiteKey) -> void:
	if position < 0 or position >= SEQUENCER_LENGTH:
		return

	sequencer[position] = {
		"type": "note",
		"note": white_key,
	}

	_update_measure_rhythm(position / BEATS_PER_MEASURE)
	sequencer_updated.emit(sequencer)

## 在序列器指定位置放置和弦（占据整个小节）
func set_sequencer_chord(measure: int, chord_notes: Array) -> void:
	if measure < 0 or measure >= MEASURES:
		return

	var start_pos := measure * BEATS_PER_MEASURE
	# 和弦占据整个小节
	for i in range(BEATS_PER_MEASURE):
		if i == 0:
			sequencer[start_pos + i] = {
				"type": "chord",
				"chord_notes": chord_notes,
			}
		else:
			sequencer[start_pos + i] = { "type": "chord_sustain" }

	_update_measure_rhythm(measure)
	sequencer_updated.emit(sequencer)

## 在序列器指定位置放置休止符
func set_sequencer_rest(position: int) -> void:
	if position < 0 or position >= SEQUENCER_LENGTH:
		return

	sequencer[position] = { "type": "rest" }
	_update_measure_rhythm(position / BEATS_PER_MEASURE)
	sequencer_updated.emit(sequencer)

## 清空序列器
func clear_sequencer() -> void:
	_init_sequencer()
	sequencer_updated.emit(sequencer)

# ============================================================
# 手动施法槽
# ============================================================

## 设置手动施法槽
func set_manual_slot(slot_index: int, spell_data: Dictionary) -> void:
	if slot_index < 0 or slot_index >= MAX_MANUAL_SLOTS:
		return
	manual_cast_slots[slot_index] = spell_data

## 触发手动施法
func trigger_manual_cast(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= MAX_MANUAL_SLOTS:
		return

	# 检查冷却
	if _manual_slot_cooldowns[slot_index] > 0.0:
		return

	var slot := manual_cast_slots[slot_index]
	if slot.get("type", "empty") == "empty":
		return

	_execute_spell(slot)
	# 设置冷却
	_manual_slot_cooldowns[slot_index] = MANUAL_SLOT_BASE_COOLDOWN

## 更新手动施法槽冷却
func _update_manual_slot_cooldowns(delta: float) -> void:
	for i in range(_manual_slot_cooldowns.size()):
		if _manual_slot_cooldowns[i] > 0.0:
			_manual_slot_cooldowns[i] = max(0.0, _manual_slot_cooldowns[i] - delta)

## 获取手动施法槽冷却进度 (0.0 = 就绪, 1.0 = 满冷却)
func get_manual_slot_cooldown_progress(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= MAX_MANUAL_SLOTS:
		return 0.0
	return _manual_slot_cooldowns[slot_index] / MANUAL_SLOT_BASE_COOLDOWN

# ============================================================
# 黑键修饰符
# ============================================================

## 使用黑键作为修饰符
func apply_black_key_modifier(black_key: MusicData.BlackKey) -> void:
	var mod_data = MusicData.BLACK_KEY_MODIFIERS.get(black_key, null)
	if mod_data == null:
		return

	# 检查修饰符是否已通过局外成长解锁
	var effect: MusicData.ModifierEffect = mod_data["effect"]
	if not SaveManager.is_modifier_available(effect):
		return

	_pending_modifier = effect
	_has_pending_modifier = true
	modifier_applied.emit(_pending_modifier)

## 消耗待生效的修饰符
func _consume_modifier() -> MusicData.ModifierEffect:
	if _has_pending_modifier:
		_has_pending_modifier = false
		var mod := _pending_modifier
		_pending_modifier = -1
		return mod
	return -1

# ============================================================
# 和弦构建
# ============================================================

## 向和弦缓冲区添加音符
func add_to_chord_buffer(note: int) -> void:
	if _chord_buffer.is_empty():
		_chord_buffer_timeout = CHORD_BUFFER_WINDOW

	if note not in _chord_buffer:
		_chord_buffer.append(note)

	# 如果已经有3个音符，尝试识别和弦
	if _chord_buffer.size() >= 3:
		_chord_buffer_timeout = 0.1  # 缩短等待时间

func _flush_chord_buffer() -> void:
	if _chord_buffer.size() >= 3:
		# 尝试识别和弦
		var chord_result = MusicTheoryEngine.identify_chord(_chord_buffer)
		if chord_result != null:
			_cast_chord(chord_result)
		else:
			# 无法识别为和弦，逐个施放
			for note in _chord_buffer:
				_cast_single_note(note)
	elif _chord_buffer.size() > 0:
		# 不足3个音符，逐个施放
		for note in _chord_buffer:
			_cast_single_note(note)

	_chord_buffer.clear()

# ============================================================
# 节拍回调（修复：从嵌套函数移出为顶层函数）
# ============================================================

func _on_beat_tick(beat_index: int) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# 自动施法：执行序列器当前位置
	var pos := beat_index % SEQUENCER_LENGTH
	_sequencer_position = pos
	_execute_sequencer_position(pos)

func _on_half_beat_tick(_half_beat_index: int) -> void:
	# 八分音符精度的手动施法时机
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	# 目前手动施法由玩家输入触发，这里仅作为时机标记

func _on_measure_complete(measure_index: int) -> void:
	# 小节完成时的处理
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# 获取当前小节的节奏型
	var measure_idx := measure_index % MEASURES
	var rhythm := _measure_rhythm_patterns[measure_idx]

	# 计算小节内的休止符数量
	var start_pos := measure_idx * BEATS_PER_MEASURE
	var rest_count := 0
	for i in range(BEATS_PER_MEASURE):
		var pos := start_pos + i
		if pos < SEQUENCER_LENGTH and sequencer[pos].get("type", "") == "rest":
			rest_count += 1

	# 如果小节内有休止符，应用精准蓄力加成
	# 加成已经在 _apply_rhythm_modifier 中处理
	# 这里可以触发视觉/音效反馈

# ============================================================
# 法术执行
# ============================================================

func _execute_sequencer_position(pos: int) -> void:
	var slot := sequencer[pos]
	var slot_type: String = slot.get("type", "rest")

	match slot_type:
		"note":
			_cast_single_note_from_sequencer(slot, pos)
		"chord":
			_cast_chord_from_sequencer(slot, pos)
		"rest":
			# 休止符 - 不施法，但记录用于蓄力计算
			pass
		"chord_sustain":
			# 和弦持续 - 不做额外操作
			pass

func _cast_single_note_from_sequencer(slot: Dictionary, pos: int) -> void:
	var white_key: MusicData.WhiteKey = slot["note"]
	var stats := GameManager.get_note_effective_stats(white_key)

	# 应用节奏型修饰
	var measure_idx := pos / BEATS_PER_MEASURE
	var rhythm := _measure_rhythm_patterns[measure_idx]
	stats = _apply_rhythm_modifier(stats, rhythm, measure_idx)

	# 应用疲劳惩罚
	var fatigue := FatigueManager.query_fatigue()
	var damage_mult: float = fatigue.get("penalty", {}).get("damage_multiplier", 1.0)

	# 获取音色信息
	var timbre := _current_timbre
	var timbre_data: Dictionary = MusicData.TIMBRE_ADSR.get(timbre, {})
	var timbre_fatigue_mult: float = MusicData.TIMBRE_FATIGUE_PENALTY.get(
		FatigueManager.current_level, 1.0
	)

	# 获取节奏型修饰数据
	var rhythm_data: Dictionary = MusicData.RHYTHM_MODIFIERS.get(rhythm, {})

	# 计算基础伤害（包含局外成长加成）
	var meta_dmg_mult := SaveManager.get_damage_multiplier()
	var meta_spd_mult := SaveManager.get_speed_multiplier()
	var base_damage: float = stats["dmg"] * MusicData.PARAM_CONVERSION["dmg_per_point"] * damage_mult * timbre_fatigue_mult * meta_dmg_mult

	# 应用增伤 Buff（T→D 和弦进行效果）
	if _empower_buff_active:
		base_damage *= _empower_buff_multiplier
		_empower_buff_active = false
		_empower_buff_multiplier = 1.0

	var spell_data := {
		"type": "note",
		"note": white_key,
		"stats": stats,
		"damage": base_damage,
		"speed": stats["spd"] * MusicData.PARAM_CONVERSION["spd_per_point"] * meta_spd_mult,
		"duration": stats["dur"] * MusicData.PARAM_CONVERSION["dur_per_point"],
		"size": stats["size"] * MusicData.PARAM_CONVERSION["size_per_point"],
		"color": MusicData.NOTE_COLORS.get(white_key, Color.WHITE),
		"modifier": _consume_modifier(),
		"rhythm_pattern": rhythm,
		"rhythm_data": rhythm_data,
		"timbre": timbre,
		"timbre_name": timbre_data.get("name", "合成器"),
		# 节奏型行为标记
		"is_rapid_fire": rhythm == MusicData.RhythmPattern.EVEN_EIGHTH,
		"rapid_fire_count": rhythm_data.get("count", 1),
		"has_knockback": rhythm_data.get("knockback", false),
		"dodge_back": rhythm_data.get("dodge_back", false),
	}

	# 记录疲劳事件
	FatigueManager.record_spell({
		"time": GameManager.game_time,
		"note": white_key,
		"is_chord": false,
	})

	# 播放音符音效
	var note_enum: int = MusicData.WHITE_KEY_TO_NOTE.get(white_key, MusicData.Note.C)
	var gmm := get_node_or_null("/root/GlobalMusicManager")
	if gmm and gmm.has_method("play_note_sound"):
		gmm.play_note_sound(note_enum, spell_data["duration"], timbre)

	# 节奏型行为：连射（EVEN_EIGHTH）发射多个弹体
	if spell_data["is_rapid_fire"] and spell_data["rapid_fire_count"] > 1:
		for i in range(spell_data["rapid_fire_count"]):
			var rapid_data := spell_data.duplicate()
			rapid_data["rapid_fire_index"] = i
			rapid_data["rapid_fire_angle_offset"] = (i - spell_data["rapid_fire_count"] / 2.0) * 0.1
			spell_cast.emit(rapid_data)
	else:
		spell_cast.emit(spell_data)

	# 节奏型行为：闪避射击（SYNCOPATED）玩家向后微位移
	if spell_data["dodge_back"]:
		var player := get_tree().get_first_node_in_group("player")
		if player and player is CharacterBody2D:
			var aim_dir := (player.get_global_mouse_position() - player.global_position).normalized()
			player.velocity -= aim_dir * 150.0  # 向后推

func _cast_single_note(note: int) -> void:
	# 将 MIDI 音符转为白键
	var white_key := _note_to_white_key(note)
	if white_key < 0:
		return

	var stats := GameManager.get_note_effective_stats(white_key)
	var fatigue := FatigueManager.query_fatigue()
	var damage_mult: float = fatigue.get("penalty", {}).get("damage_multiplier", 1.0)

	var timbre := _current_timbre
	var timbre_data: Dictionary = MusicData.TIMBRE_ADSR.get(timbre, {})
	var timbre_fatigue_mult: float = MusicData.TIMBRE_FATIGUE_PENALTY.get(
		FatigueManager.current_level, 1.0
	)

	# 计算基础伤害
	var base_damage: float = stats["dmg"] * MusicData.PARAM_CONVERSION["dmg_per_point"] * damage_mult * timbre_fatigue_mult

	# 应用增伤 Buff
	if _empower_buff_active:
		base_damage *= _empower_buff_multiplier
		_empower_buff_active = false
		_empower_buff_multiplier = 1.0

	var spell_data := {
		"type": "note",
		"note": white_key,
		"stats": stats,
		"damage": base_damage,
		"speed": stats["spd"] * MusicData.PARAM_CONVERSION["spd_per_point"],
		"duration": stats["dur"] * MusicData.PARAM_CONVERSION["dur_per_point"],
		"size": stats["size"] * MusicData.PARAM_CONVERSION["size_per_point"],
		"color": MusicData.NOTE_COLORS.get(white_key, Color.WHITE),
		"modifier": _consume_modifier(),
		"timbre": timbre,
		"timbre_name": timbre_data.get("name", "合成器"),
	}

	FatigueManager.record_spell({
		"time": GameManager.game_time,
		"note": white_key,
		"is_chord": false,
	})

	# 播放音符音效
	var note_enum: int = MusicData.WHITE_KEY_TO_NOTE.get(white_key, MusicData.Note.C)
	var gmm := get_node_or_null("/root/GlobalMusicManager")
	if gmm and gmm.has_method("play_note_sound"):
		gmm.play_note_sound(note_enum, spell_data["duration"], timbre)

	spell_cast.emit(spell_data)

func _cast_chord(chord_result: Dictionary) -> void:
	var chord_type: MusicData.ChordType = chord_result["type"]

	# 检查和弦是否已通过局外成长解锁
	if not SaveManager.is_chord_type_available(chord_type):
		return

	# 检查扩展和弦是否已在局内解锁
	if MusicTheoryEngine.is_extended_chord(chord_type) and not GameManager.extended_chords_unlocked:
		return

	var spell_info := MusicTheoryEngine.get_spell_form_info(chord_type)
	if spell_info.is_empty():
		return

	# 计算和弦伤害（基于根音）
	var root_white_key := _note_to_white_key(chord_result["root"])
	var root_stats := GameManager.get_note_effective_stats(root_white_key) if root_white_key >= 0 else { "dmg": 3.0 }

	var fatigue := FatigueManager.query_fatigue()
	var damage_mult: float = fatigue.get("penalty", {}).get("damage_multiplier", 1.0)
	var chord_multiplier: float = spell_info.get("multiplier", 1.0)

	# 不和谐度处理
	var dissonance := MusicTheoryEngine.get_chord_dissonance(chord_type)
	if dissonance > 2.0:
		GameManager.apply_dissonance_damage(dissonance)

	# 扩展和弦额外疲劳
	var extra_fatigue: float = MusicData.EXTENDED_CHORD_FATIGUE.get(chord_type, 0.0)

	var timbre := _current_timbre
	var timbre_data: Dictionary = MusicData.TIMBRE_ADSR.get(timbre, {})
	var timbre_fatigue_mult: float = MusicData.TIMBRE_FATIGUE_PENALTY.get(
		FatigueManager.current_level, 1.0
	)

	# 计算基础伤害
	var base_damage: float = root_stats["dmg"] * MusicData.PARAM_CONVERSION["dmg_per_point"] * chord_multiplier * damage_mult * timbre_fatigue_mult

	# 应用增伤 Buff
	if _empower_buff_active:
		base_damage *= _empower_buff_multiplier
		_empower_buff_active = false
		_empower_buff_multiplier = 1.0

	var chord_data := {
		"type": "chord",
		"chord_type": chord_type,
		"spell_form": spell_info["form"],
		"spell_name": spell_info["name"],
		"damage": base_damage,
		"dissonance": dissonance,
		"extra_fatigue": extra_fatigue,
		"modifier": _consume_modifier(),
		"timbre": timbre,
		"timbre_name": timbre_data.get("name", "合成器"),
	}

	# 记录疲劳事件
	FatigueManager.record_spell({
		"time": GameManager.game_time,
		"note": chord_result["root"],
		"is_chord": true,
		"chord_type": chord_type,
	})

	# 记录和弦进行
	var progression := MusicTheoryEngine.record_chord(chord_type)
	if not progression.is_empty():
		chord_data["progression"] = progression
		# 触发和弦进行效果
		_trigger_progression_effect(progression)

	# 播放和弦音效
	var chord_notes_for_sound: Array = chord_result.get("notes", [])
	var note_enums: Array = []
	for n in chord_notes_for_sound:
		note_enums.append(n % 12)  # 转换为 Note 枚举 (0-11)
	var gmm := get_node_or_null("/root/GlobalMusicManager")
	if gmm and gmm.has_method("play_chord_sound"):
		gmm.play_chord_sound(note_enums, 0.5, timbre)

	chord_cast.emit(chord_data)

func _cast_chord_from_sequencer(slot: Dictionary, _pos: int) -> void:
	var chord_notes: Array = slot.get("chord_notes", [])
	if chord_notes.size() < 3:
		return

	var chord_result = MusicTheoryEngine.identify_chord(chord_notes)
	if chord_result != null:
		_cast_chord(chord_result)

# ============================================================
# 节奏型分析（增强版：支持更多节奏型判定）
# ============================================================

func _update_measure_rhythm(measure_idx: int) -> void:
	if measure_idx < 0 or measure_idx >= MEASURES:
		return

	var start := measure_idx * BEATS_PER_MEASURE
	var pattern := _analyze_rhythm_pattern(start)
	_measure_rhythm_patterns[measure_idx] = pattern
	rhythm_pattern_changed.emit(pattern)

func _analyze_rhythm_pattern(start_pos: int) -> MusicData.RhythmPattern:
	var notes := 0
	var rests := 0
	var pattern_slots: Array[String] = []  # 记录每拍的类型

	for i in range(BEATS_PER_MEASURE):
		var pos := start_pos + i
		if pos >= SEQUENCER_LENGTH:
			pattern_slots.append("rest")
			rests += 1
			continue
		var slot_type: String = sequencer[pos].get("type", "rest")
		match slot_type:
			"note":
				notes += 1
				pattern_slots.append("note")
			"chord", "chord_sustain":
				notes += 1
				pattern_slots.append("chord")
			"rest":
				rests += 1
				pattern_slots.append("rest")

	# 全休止
	if rests == BEATS_PER_MEASURE:
		return MusicData.RhythmPattern.REST

	# 全音符（均匀八分音符 → 连射）
	if notes == BEATS_PER_MEASURE:
		return MusicData.RhythmPattern.EVEN_EIGHTH

	# 附点节奏判定：强拍有音符，弱拍有休止（如 note-rest-note-rest 或 note-note-note-rest）
	if pattern_slots[0] == "note" and rests == 1 and pattern_slots[3] == "rest":
		return MusicData.RhythmPattern.DOTTED

	# 切分节奏判定：弱拍有音符，强拍有休止（如 rest-note-rest-note）
	if pattern_slots[0] == "rest" and pattern_slots[1] == "note":
		return MusicData.RhythmPattern.SYNCOPATED

	# 摇摆节奏判定：交替模式（如 note-rest-note-note）
	if notes == 3 and rests == 1:
		return MusicData.RhythmPattern.SWING

	# 三连音判定：3个音符 + 1个休止（特定位置）
	if notes == 3 and pattern_slots[3] == "rest":
		return MusicData.RhythmPattern.TRIPLET

	# 默认：有休止就算休止型，否则均匀八分
	if rests >= 2:
		return MusicData.RhythmPattern.REST
	else:
		return MusicData.RhythmPattern.EVEN_EIGHTH

func _apply_rhythm_modifier(stats: Dictionary, rhythm: MusicData.RhythmPattern, _measure_idx: int) -> Dictionary:
	var modified := stats.duplicate()
	var rhythm_data: Dictionary = MusicData.RHYTHM_MODIFIERS.get(rhythm, {})

	if rhythm_data.is_empty():
		return modified

	# 应用修饰
	if rhythm_data.has("size_mod"):
		modified["size"] = max(1.0, modified["size"] + rhythm_data["size_mod"])
	if rhythm_data.has("spd_mod"):
		modified["spd"] = max(1.0, modified["spd"] + rhythm_data["spd_mod"])
	if rhythm_data.has("dmg_mod"):
		modified["dmg"] += rhythm_data["dmg_mod"]
	if rhythm_data.has("dmg_mod_mult"):
		modified["dmg"] *= rhythm_data["dmg_mod_mult"]

	# 休止符蓄力加成
	if rhythm == MusicData.RhythmPattern.REST:
		var rest_count := 0
		var start := _measure_idx * BEATS_PER_MEASURE
		for i in range(BEATS_PER_MEASURE):
			if start + i < SEQUENCER_LENGTH and sequencer[start + i].get("type", "") == "rest":
				rest_count += 1
		var boost: float = rest_count * rhythm_data.get("boost_per_rest", 0.5)
		modified["dmg"] += boost
		modified["size"] += boost

	return modified

# ============================================================
# 和弦进行效果（修复：从嵌套函数移出，实现完整逻辑）
# ============================================================

## 触发和弦进行效果
func _trigger_progression_effect(progression: Dictionary) -> void:
	var effect_type: String = progression.get("effect", {}).get("type", "")
	var bonus_mult: float = progression.get("bonus_multiplier", 1.0)

	if effect_type.is_empty():
		return

	match effect_type:
		"burst_heal_or_damage":
			# D→T: 全屏伤害或爆发治疗
			_apply_burst_effect(bonus_mult)
		"empower_next":
			# T→D: 下一个法术伤害翻倍
			_apply_empower_buff(bonus_mult)
		"cooldown_reduction":
			# PD→D: 全体冷却缩减
			_apply_cooldown_reduction(bonus_mult)

	# 播放和弦进行完成音效（通过 AudioManager）
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_progression_resolve_sfx"):
		audio_mgr.play_progression_resolve_sfx()

	progression_resolved.emit(progression)

## D→T: 爆发治疗或全屏伤害
func _apply_burst_effect(bonus_mult: float) -> void:
	var player_hp_percent := GameManager.player_current_hp / GameManager.player_max_hp

	if player_hp_percent < BURST_HP_THRESHOLD:
		# 生命值低于阈值，触发爆发治疗
		var heal_amount := BURST_HEAL_BASE * bonus_mult
		GameManager.heal_player(heal_amount)
	else:
		# 生命值高于阈值，触发全屏伤害
		var damage := BURST_DAMAGE_BASE * bonus_mult
		# 发出信号，由 EnemySpawner 监听并对所有敌人造成伤害
		var event_data := {
			"type": "aoe_damage",
			"damage": damage,
			"radius": 999999.0,  # 全屏
		}
		spell_cast.emit(event_data)

## T→D: 下一个法术伤害翻倍（已实现 Buff 系统）
func _apply_empower_buff(bonus_mult: float) -> void:
	_empower_buff_active = true
	_empower_buff_multiplier = EMPOWER_BUFF_MULTIPLIER * bonus_mult

## PD→D: 全体冷却缩减（已实现冷却系统）
func _apply_cooldown_reduction(bonus_mult: float) -> void:
	# 立即缩减所有手动施法槽的冷却时间
	var reduction_ratio := COOLDOWN_REDUCTION_RATIO * bonus_mult
	for i in range(_manual_slot_cooldowns.size()):
		_manual_slot_cooldowns[i] *= (1.0 - reduction_ratio)

# ============================================================
# 工具函数
# ============================================================

func _note_to_white_key(note: int) -> int:
	var pc := note % 12
	match pc:
		0: return MusicData.WhiteKey.C
		2: return MusicData.WhiteKey.D
		4: return MusicData.WhiteKey.E
		5: return MusicData.WhiteKey.F
		7: return MusicData.WhiteKey.G
		9: return MusicData.WhiteKey.A
		11: return MusicData.WhiteKey.B
		_: return -1  # 黑键

func _execute_spell(spell_data: Dictionary) -> void:
	spell_cast.emit(spell_data)

## 获取序列器当前位置
func get_sequencer_position() -> int:
	return _sequencer_position

## 获取序列器数据
func get_sequencer_data() -> Array:
	return sequencer.duplicate(true)

## 重置系统状态（供 GameManager.reset_game 调用）
func reset() -> void:
	_init_sequencer()
	_init_manual_slots()
	_empower_buff_active = false
	_empower_buff_multiplier = 1.0
	_pending_modifier = -1
	_has_pending_modifier = false
	_chord_buffer.clear()

# ============================================================
# 音色系统接口
# ============================================================

## 切换音色系别
## 切换时会产生少量疲劳代价
func set_timbre(timbre: MusicData.TimbreType) -> void:
	if timbre == _current_timbre:
		return

	_current_timbre = timbre

	# 音色切换产生疲劳代价
	FatigueManager.record_spell({
		"time": GameManager.game_time,
		"note": -1,
		"is_chord": false,
		"is_timbre_switch": true,
	})

	# 同步到 GlobalMusicManager
	var gmm := get_node_or_null("/root/GlobalMusicManager")
	if gmm and gmm.has_method("set_timbre"):
		gmm.set_timbre(timbre)

	timbre_changed.emit(timbre)

## 获取当前音色系别
func get_current_timbre() -> MusicData.TimbreType:
	return _current_timbre

## 获取音色系别信息
func get_timbre_info(timbre: MusicData.TimbreType) -> Dictionary:
	return MusicData.TIMBRE_ADSR.get(timbre, {})
