## spellcraft_system.gd
## 法术构建系统 (Autoload)
## 管理序列器、手动施法、和弦构建、弹体生成
##
## v3.0 更新：
##   - 集成音符经济系统：序列器/手动槽编辑时自动装备/卸下音符
##   - 集成法术书：和弦法术从法术书装备/卸下
##   - 集成单音寂静检查、密度过载惩罚、黑键双重身份
##   - 完善手动施法：支持快捷键触发，对齐八分音符精度
##   - 完善和弦进行效果：D→T/T→D/PD→D 三种转换效果完整实现
##   - 不和谐法术缓解单调值的交互
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
## 新增：音符被寂静阻止时的信号
signal spell_blocked_by_silence(note: MusicData.WhiteKey)
## 新增：密度过载散射时的信号
signal accuracy_penalized(penalty: float)
## 新增：频谱相位切换信号 (Issue #50 — Resonance Slicing)
signal phase_switched(phase_name: String)
## 新增：惩罚效果信号（供 VfxManager 监听）
signal monotone_silence_triggered(data: Dictionary)
signal noise_overload_triggered(data: Dictionary)
signal dissonance_corrosion_triggered(data: Dictionary)

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

# ============================================================
# 频谱相位系统状态 (Issue #50 — Resonance Slicing)
# ============================================================
## 当前相位: 0=全频(Fundamental), 1=高通(Overtone), 2=低通(Sub-Bass)
var _current_spectral_phase: int = 0
## 相位能量 (0~100)
var phase_energy: float = 100.0
const MAX_PHASE_ENERGY: float = 100.0
const PHASE_SWITCH_COST: float = 10.0
const PHASE_SUSTAIN_COST: float = 5.0  # 每秒消耗
const PHASE_NAMES: Array[String] = ["fundamental", "overtone", "sub_bass"]

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
# 手动施法八分音符对齐
# ============================================================
## 是否在当前八分音符窗口内
var _in_half_beat_window: bool = false
## 八分音符窗口容差（秒）
const HALF_BEAT_TOLERANCE: float = 0.05

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

	# 更新频谱相位能量 (Issue #50)
	_update_phase_energy(delta)

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

## 在序列器指定位置放置音符（集成音符经济：自动装备）
func set_sequencer_note(position: int, white_key: MusicData.WhiteKey) -> void:
	if position < 0 or position >= SEQUENCER_LENGTH:
		return

	# ★ 音符经济：尝试从库存装备音符
	if not NoteInventory.equip_note(white_key):
		return  # 库存不足，无法放置

	# 如果该位置已有音符，先卸下旧音符
	_unequip_sequencer_slot(position)

	sequencer[position] = {
		"type": "note",
		"note": white_key,
	}

	_update_measure_rhythm(position / BEATS_PER_MEASURE)
	sequencer_updated.emit(sequencer)

## 在序列器指定小节放置和弦法术（从法术书装备，占据整个小节）
func set_sequencer_chord(measure: int, spell_id: String) -> void:
	if measure < 0 or measure >= MEASURES:
		return

	var spell := NoteInventory.get_chord_spell(spell_id)
	if spell.is_empty():
		return
	if spell["is_equipped"]:
		return  # 已装备到其他槽位

	# 先卸下该小节内的所有旧内容
	var start_pos := measure * BEATS_PER_MEASURE
	for i in range(BEATS_PER_MEASURE):
		_unequip_sequencer_slot(start_pos + i)

	# 标记法术为已装备
	NoteInventory.mark_spell_equipped(spell_id, "sequencer_M%d" % (measure + 1))

	# 和弦占据整个小节
	for i in range(BEATS_PER_MEASURE):
		if i == 0:
			sequencer[start_pos + i] = {
				"type": "chord",
				"chord_notes": spell["chord_notes"],
				"spell_id": spell_id,
			}
		else:
			sequencer[start_pos + i] = { "type": "chord_sustain", "spell_id": spell_id }

	_update_measure_rhythm(measure)
	sequencer_updated.emit(sequencer)

## 兼容旧接口：直接用音符数组放置和弦（用于自动施法等不需要库存的场景）
func set_sequencer_chord_raw(measure: int, chord_notes: Array) -> void:
	if measure < 0 or measure >= MEASURES:
		return

	var start_pos := measure * BEATS_PER_MEASURE
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

## 在序列器指定位置放置休止符（自动卸下旧音符）
func set_sequencer_rest(position: int) -> void:
	if position < 0 or position >= SEQUENCER_LENGTH:
		return

	# ★ 音符经济：卸下旧音符返回库存
	_unequip_sequencer_slot(position)

	sequencer[position] = { "type": "rest" }
	_update_measure_rhythm(position / BEATS_PER_MEASURE)
	sequencer_updated.emit(sequencer)

## 清空序列器（所有音符返回库存）
func clear_sequencer() -> void:
	# ★ 音符经济：卸下所有已装备的音符和和弦法术
	for i in range(SEQUENCER_LENGTH):
		_unequip_sequencer_slot(i)
	_init_sequencer()
	sequencer_updated.emit(sequencer)

## ★ 内部工具：卸下序列器某个位置的内容，将音符/和弦返回库存/法术书
func _unequip_sequencer_slot(position: int) -> void:
	if position < 0 or position >= SEQUENCER_LENGTH:
		return
	var slot := sequencer[position]
	var slot_type: String = slot.get("type", "rest")

	match slot_type:
		"note":
			# 音符返回库存
			var note_key: int = slot.get("note", -1)
			if note_key >= 0:
				NoteInventory.unequip_note(note_key)
		"chord":
			# 和弦法术返回法术书
			var spell_id: String = slot.get("spell_id", "")
			if not spell_id.is_empty():
				NoteInventory.mark_spell_unequipped(spell_id)
		"chord_sustain":
			# 和弦延续槽位，不需要单独处理（由主槽位统一处理）
			pass

# ============================================================
# 手动施法槽（完善版：支持快捷键触发和八分音符对齐）
# ============================================================

## 设置手动施法槽（集成音符经济）
func set_manual_slot(slot_index: int, spell_data: Dictionary) -> void:
	if slot_index < 0 or slot_index >= MAX_MANUAL_SLOTS:
		return

	# ★ 卸下旧槽位内容
	_unequip_manual_slot(slot_index)

	# ★ 装备新内容
	var slot_type: String = spell_data.get("type", "empty")
	if slot_type == "note":
		var note_key: int = spell_data.get("note", -1)
		if note_key >= 0 and not NoteInventory.equip_note(note_key):
			return  # 库存不足
	elif slot_type == "chord":
		var spell_id: String = spell_data.get("spell_id", "")
		if not spell_id.is_empty():
			NoteInventory.mark_spell_equipped(spell_id, "manual_%d" % slot_index)

	manual_cast_slots[slot_index] = spell_data

## 清空手动施法槽（卸下内容返回库存/法术书）
func clear_manual_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= MAX_MANUAL_SLOTS:
		return
	_unequip_manual_slot(slot_index)
	manual_cast_slots[slot_index] = { "type": "empty" }

## ★ 内部工具：卸下手动施法槽的内容
func _unequip_manual_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= MAX_MANUAL_SLOTS:
		return
	var slot := manual_cast_slots[slot_index]
	var slot_type: String = slot.get("type", "empty")

	match slot_type:
		"note":
			var note_key: int = slot.get("note", -1)
			if note_key >= 0:
				NoteInventory.unequip_note(note_key)
		"chord":
			var spell_id: String = slot.get("spell_id", "")
			if not spell_id.is_empty():
				NoteInventory.mark_spell_unequipped(spell_id)

## 触发手动施法（完善版：对齐到八分音符精度）
func trigger_manual_cast(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= MAX_MANUAL_SLOTS:
		return

	# 检查冷却
	if _manual_slot_cooldowns[slot_index] > 0.0:
		return

	var slot := manual_cast_slots[slot_index]
	if slot.get("type", "empty") == "empty":
		return

	# 八分音符精度对齐：检查当前是否接近八分音符时机
	# 允许在八分音符前后 HALF_BEAT_TOLERANCE 秒内触发
	var beat_progress := GameManager.get_beat_progress()
	var half_beat_progress := fmod(beat_progress * 2.0, 1.0)
	var is_near_half_beat := half_beat_progress < HALF_BEAT_TOLERANCE * 2.0 * (GameManager.current_bpm / 60.0) or \
		half_beat_progress > 1.0 - HALF_BEAT_TOLERANCE * 2.0 * (GameManager.current_bpm / 60.0)

	# 即使不在精确时机也允许施法，但在精确时机有额外奖励
	var timing_bonus: float = 1.0
	if is_near_half_beat:
		timing_bonus = 1.15  # 精准时机 +15% 伤害

	# 检查音符是否被寂静（寂静音符仍可施法但伤害为0）
	var note = slot.get("note", -1)
	var is_silenced: bool = note >= 0 and FatigueManager.is_note_silenced(note)
	if is_silenced:
		spell_blocked_by_silence.emit(note)
		monotone_silence_triggered.emit({"note": note})

	var enhanced_slot := slot.duplicate()
	enhanced_slot["timing_bonus"] = timing_bonus
	enhanced_slot["is_manual"] = true
	enhanced_slot["is_silenced"] = is_silenced
	enhanced_slot["silence_damage_mult"] = FatigueManager.get_note_silence_damage_multiplier(note) if note >= 0 else 1.0
	# ★ Issue #100: 添加密度过载惩罚
	enhanced_slot["density_damage_multiplier"] = FatigueManager.get_density_damage_multiplier()

	# v3.1: 手动施法槽中的和弦也要检查不和谐值生命腐蚀
	var slot_type: String = slot.get("type", "empty")
	if slot_type == "chord":
		var chord_type = slot.get("chord_type", -1)
		if chord_type >= 0:
			var raw_dissonance = MusicTheoryEngine.get_chord_dissonance(chord_type)
			var mode_dissonance_mult := ModeSystem.get_dissonance_multiplier()
			var corrosion_damage := FatigueManager.apply_dissonance_corrosion(raw_dissonance, mode_dissonance_mult)
			if corrosion_damage > 0.0:
				var dissonance = raw_dissonance * mode_dissonance_mult
				ModeSystem.on_dissonance_applied(dissonance)
				dissonance_corrosion_triggered.emit({"dissonance": dissonance, "damage": corrosion_damage})
			enhanced_slot["dissonance"] = raw_dissonance * mode_dissonance_mult

	_execute_spell(enhanced_slot)
	
	# ★ Issue #100: 记录疲劳事件
	FatigueManager.record_spell({
		"time": GameManager.game_time,
		"note": note,
		"is_chord": slot_type == "chord",
		"chord_type": slot.get("chord_type", -1) if slot_type == "chord" else -1,
	})
	
	# 设置冷却（PD→D 效果可能已缩减冷却）
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
# 黑键双重身份（完善版：根据上下文自动判定）
# ============================================================

## 处理黑键输入：根据上下文决定作为修饰符还是和弦构成音
## Issue #18: 黑键双重身份
func handle_black_key_input(black_key: MusicData.BlackKey) -> void:
	var midi_note := _black_key_to_midi(black_key)

	# 如果和弦缓冲区已有音符（正在构建和弦），黑键参与和弦构建
	if not _chord_buffer.is_empty():
		add_to_chord_buffer(midi_note)
		return

	# 否则，作为修饰符使用
	apply_black_key_modifier(black_key)

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

## 黑键枚举转 MIDI 音符
func _black_key_to_midi(black_key: MusicData.BlackKey) -> int:
	match black_key:
		MusicData.BlackKey.CS: return 1
		MusicData.BlackKey.DS: return 3
		MusicData.BlackKey.FS: return 6
		MusicData.BlackKey.GS: return 8
		MusicData.BlackKey.AS: return 10
		_: return -1

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
# 节拍回调
# ============================================================

func _on_beat_tick(beat_index: int) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# 自动施法：执行序列器当前位置
	var pos := beat_index % SEQUENCER_LENGTH
	_sequencer_position = pos
	_execute_sequencer_position(pos)

func _on_half_beat_tick(_half_beat_index: int) -> void:
	# 八分音符精度的手动施法时机标记
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_in_half_beat_window = true
	# 窗口会在下一帧的 _process 中自动关闭（通过时间检测）

func _on_measure_complete(measure_index: int) -> void:
	# 小节完成时的处理
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# 获取当前小节的节奏型
	var measure_idx := measure_index % MEASURES
	var rhythm := _measure_rhythm_patterns[measure_idx]

	# 计算小节内的休止符数量（用于精准蓄力加成的视觉/音效反馈）
	var start_pos := measure_idx * BEATS_PER_MEASURE
	var rest_count := 0
	for i in range(BEATS_PER_MEASURE):
		var pos := start_pos + i
		if pos < SEQUENCER_LENGTH and sequencer[pos].get("type", "") == "rest":
			rest_count += 1

	# 小节完成反馈（可由 HUD 监听）
	if rest_count > 0 and rhythm == MusicData.RhythmPattern.REST:
		# 精准蓄力小节完成 — 视觉反馈
		pass

# ============================================================
# 法术执行
# ============================================================

func _execute_sequencer_position(pos: int) -> void:
	var slot := sequencer[pos]
	var slot_type: String = slot.get("type", "rest")

	match slot_type:
		"note":
			FatigueManager.reset_rest_counter()  # 施法时重置休止符计数
			_cast_single_note_from_sequencer(slot, pos)
		"chord":
			FatigueManager.reset_rest_counter()  # 施法时重置休止符计数
			_cast_chord_from_sequencer(slot, pos)
		"rest":
			# 休止符 - 不施法，记录用于蓄力计算和留白奖励
			FatigueManager.record_rest()
		"chord_sustain":
			# 和弦持续 - 不做额外操作
			pass

func _cast_single_note_from_sequencer(slot: Dictionary, pos: int) -> void:
	var white_key: MusicData.WhiteKey = slot["note"]

	# ★ 调式检查：当前调式下不可用的音符无法施放
	if not ModeSystem.is_white_key_available(white_key):
		return  # 静默跳过，不触发任何反馈

	# ★ 单音寂静检查：被寂静的音符伤害降为0，视觉变灰
	var is_silenced: bool = FatigueManager.is_note_silenced(white_key)
	var silence_damage_mult: float = FatigueManager.get_note_silence_damage_multiplier(white_key)
	if is_silenced:
		spell_blocked_by_silence.emit(white_key)
		monotone_silence_triggered.emit({"note": white_key})

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

	# 计算基础伤害（包含局外成长加成 + 调式加成）
	var meta_dmg_mult := SaveManager.get_damage_multiplier()
	var meta_spd_mult := SaveManager.get_speed_multiplier()
	var mode_dmg_mult := ModeSystem.get_damage_multiplier()
	var base_damage: float = stats["dmg"] * MusicData.PARAM_CONVERSION["dmg_per_point"] * damage_mult * timbre_fatigue_mult * meta_dmg_mult * mode_dmg_mult

	# ★ 单音寂静惩罚：伤害降为0
	base_damage *= silence_damage_mult

	# ★ 密度过载伤害衰减
	base_damage *= FatigueManager.get_density_damage_multiplier()

	# 应用增伤 Buff（T→D 和弦进行效果）
	if _empower_buff_active and not is_silenced:
		base_damage *= _empower_buff_multiplier
		_empower_buff_active = false
		_empower_buff_multiplier = 1.0

	# ★ 密度过载精准度惩罚：弹体方向随机偏移
	var accuracy_offset: float = 0.0
	if FatigueManager.is_density_overloaded:
		accuracy_offset = FatigueManager.current_accuracy_penalty
		accuracy_penalized.emit(accuracy_offset)
		noise_overload_triggered.emit({"density": FatigueManager.current_density_damage_multiplier})

	# OPT02: 获取白键的音程度数（用于相对音高系统）
	var pitch_degree: int = MusicData.WHITE_KEY_PITCH_DEGREE.get(white_key, 1)

	var spell_data := {
		"type": "note",
		"note": white_key,
		"white_key": white_key,  # OPT02: 显式传递白键枚举值
		"pitch_degree": pitch_degree,  # OPT02: 音程度数 (1-7)
		"base_octave": 4,  # OPT02: 基础八度 (C4 = MIDI 60)
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
		# ★ 密度过载精准度偏移
		"accuracy_offset": accuracy_offset,
		# ★ 单音寂静标记（供弹体管理器灰色渲染）
		"is_silenced": is_silenced,
		# ★ 密度过载伤害倍率（供弹体管理器显示）
		"density_damage_multiplier": FatigueManager.get_density_damage_multiplier(),
	}

	# ★ 寂静音符颜色变灰
	if is_silenced:
		spell_data["color"] = Color(0.4, 0.4, 0.4, 0.5)

	# 调式被动效果：多利亚自动回响 / 布鲁斯暴击
	var mode_modifier := ModeSystem.on_spell_cast()
	if mode_modifier >= 0 and spell_data["modifier"] == -1:
		spell_data["modifier"] = mode_modifier
	if ModeSystem.check_crit() and not is_silenced:
		spell_data["damage"] *= 2.0
		spell_data["is_crit"] = true

	# 记录疲劳事件
	FatigueManager.record_spell({
		"time": GameManager.game_time,
		"note": white_key,
		"is_chord": false,
	})

	# 播放音符音效（带修饰符效果 + 转调偏移）
	var note_enum: int = MusicData.WHITE_KEY_TO_NOTE.get(white_key, MusicData.Note.C)
	var pitch_shift: int = ModeSystem.get_pitch_shift()  # 转调偏移
	var transposed_note: int = ModeSystem.apply_transpose(note_enum)  # 转调后音符
	spell_data["transposed_note"] = transposed_note
	spell_data["pitch_shift"] = pitch_shift
	var gmm := get_node_or_null("/root/GlobalMusicManager")
	var modifier: int = spell_data.get("modifier", -1)
	if gmm:
		if modifier >= 0 and gmm.has_method("play_note_sound_with_modifier"):
			# 播放带修饰符效果的音符（应用转调）
			gmm.play_note_sound_with_modifier(transposed_note, modifier, spell_data["duration"], timbre, 0.8, pitch_shift)
		elif gmm.has_method("play_note_sound"):
			# 回退到普通音符（应用转调）
			gmm.play_note_sound(transposed_note, spell_data["duration"], timbre, 0.8, pitch_shift)

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
			var aim_dir = (player.get_global_mouse_position() - player.global_position).normalized()
			player.velocity -= aim_dir * 150.0  # 向后推

func _cast_single_note(note: int) -> void:
	# 将 MIDI 音符转为白键
	var white_key := _note_to_white_key(note)
	if white_key < 0:
		# 黑键：如果不在和弦缓冲区中，作为修饰符处理
		var black_key := _midi_to_black_key(note)
		if black_key >= 0:
			apply_black_key_modifier(black_key)
		return

	# ★ 单音寂静检查：被寂静的音符伤害降为0，视觉变灰
	var is_silenced: bool = FatigueManager.is_note_silenced(white_key)
	var silence_damage_mult: float = FatigueManager.get_note_silence_damage_multiplier(white_key)
	if is_silenced:
		spell_blocked_by_silence.emit(white_key)
		monotone_silence_triggered.emit({"note": white_key})

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

	# ★ 单音寂静惩罚：伤害降为0
	base_damage *= silence_damage_mult

	# ★ 密度过载伤害衰减
	base_damage *= FatigueManager.get_density_damage_multiplier()

	# 应用增伤 Buff
	if _empower_buff_active and not is_silenced:
		base_damage *= _empower_buff_multiplier
		_empower_buff_active = false
		_empower_buff_multiplier = 1.0

	# ★ 密度过载精准度惩罚
	var accuracy_offset: float = 0.0
	if FatigueManager.is_density_overloaded:
		accuracy_offset = FatigueManager.current_accuracy_penalty
		accuracy_penalized.emit(accuracy_offset)
		noise_overload_triggered.emit({"density": FatigueManager.current_density_damage_multiplier})

	# OPT02: 获取白键的音程度数（用于相对音高系统）
	var pitch_degree: int = MusicData.WHITE_KEY_PITCH_DEGREE.get(white_key, 1)

	var spell_data := {
		"type": "note",
		"note": white_key,
		"white_key": white_key,  # OPT02: 显式传递白键枚举值
		"pitch_degree": pitch_degree,  # OPT02: 音程度数 (1-7)
		"base_octave": 4,  # OPT02: 基础八度 (C4 = MIDI 60)
		"stats": stats,
		"damage": base_damage,
		"speed": stats["spd"] * MusicData.PARAM_CONVERSION["spd_per_point"],
		"duration": stats["dur"] * MusicData.PARAM_CONVERSION["dur_per_point"],
		"size": stats["size"] * MusicData.PARAM_CONVERSION["size_per_point"],
		"color": MusicData.NOTE_COLORS.get(white_key, Color.WHITE),
		"modifier": _consume_modifier(),
		"timbre": timbre,
		"timbre_name": timbre_data.get("name", "合成器"),
		"accuracy_offset": accuracy_offset,
		"is_silenced": is_silenced,
		"density_damage_multiplier": FatigueManager.get_density_damage_multiplier(),
	}

	# ★ 寂静音符颜色变灰
	if is_silenced:
		spell_data["color"] = Color(0.4, 0.4, 0.4, 0.5)

	FatigueManager.record_spell({
		"time": GameManager.game_time,
		"note": white_key,
		"is_chord": false,
	})

	# 播放音符音效（带修饰符效果 + 转调偏移）
	var note_enum: int = MusicData.WHITE_KEY_TO_NOTE.get(white_key, MusicData.Note.C)
	var pitch_shift: int = ModeSystem.get_pitch_shift()  # 转调偏移
	var transposed_note: int = ModeSystem.apply_transpose(note_enum)  # 转调后音符
	spell_data["transposed_note"] = transposed_note
	spell_data["pitch_shift"] = pitch_shift
	var gmm := get_node_or_null("/root/GlobalMusicManager")
	var modifier: int = spell_data.get("modifier", -1)
	if gmm:
		if modifier >= 0 and gmm.has_method("play_note_sound_with_modifier"):
			# 播放带修饰符效果的音符（应用转调）
			gmm.play_note_sound_with_modifier(transposed_note, modifier, spell_data["duration"], timbre, 0.8, pitch_shift)
		elif gmm.has_method("play_note_sound"):
			# 回退到普通音符（应用转调）
			gmm.play_note_sound(transposed_note, spell_data["duration"], timbre, 0.8, pitch_shift)

	spell_cast.emit(spell_data)

func _cast_chord(chord_result: Dictionary) -> void:
	var chord_type: MusicData.ChordType = chord_result["type"]

	# 检查和弦是否已通过局外成长解锁
	if not SaveManager.is_chord_type_available(chord_type):
		return
	
	# ★ Issue #100: 和弦施法设计意图说明
	# 和弦不受单音寂静影响，因为和弦是多个音符的组合，不应被单一音符的寂静状态阻挡。
	# 这是有意设计的机制：鼓励玩家在单音被寂静时使用和弦来维持输出。

	# 检查扩展和弦是否已在局内解锁
	if MusicTheoryEngine.is_extended_chord(chord_type) and not GameManager.extended_chords_unlocked:
		return

	var spell_info = MusicTheoryEngine.get_spell_form_info(chord_type)
	if spell_info.is_empty():
		return

	# 计算和弦伤害（基于根音）
	var root_white_key := _note_to_white_key(chord_result["root"])
	var root_stats := GameManager.get_note_effective_stats(root_white_key) if root_white_key >= 0 else { "dmg": 3.0 }

	var fatigue := FatigueManager.query_fatigue()
	var damage_mult: float = fatigue.get("penalty", {}).get("damage_multiplier", 1.0)
	var chord_multiplier: float = spell_info.get("multiplier", 1.0)

	# ★ 不和谐度处理：不和谐法术直接扣血（生命腐蚀）
	var raw_dissonance = MusicTheoryEngine.get_chord_dissonance(chord_type)
	# 应用调式不和谐度倍率（五声音阶减半）
	var mode_dissonance_mult := ModeSystem.get_dissonance_multiplier()
	var dissonance = raw_dissonance * mode_dissonance_mult

	# v3.1: 通过 FatigueManager 统一接口处理不和谐腐蚀（AFI 联动伤害放大）
	var corrosion_damage := FatigueManager.apply_dissonance_corrosion(raw_dissonance, mode_dissonance_mult)
	if corrosion_damage > 0.0:
		# 布鲁斯被动：不和谐度转化为暴击率
		ModeSystem.on_dissonance_applied(dissonance)
		# ★ 发射不和谐腐蚀信号（供视觉特效管理器监听）
		dissonance_corrosion_triggered.emit({"dissonance": dissonance, "damage": corrosion_damage})

	# 扩展和弦额外疲劳
	var extra_fatigue: float = MusicData.EXTENDED_CHORD_FATIGUE.get(chord_type, 0.0)

	var timbre := _current_timbre
	var timbre_data: Dictionary = MusicData.TIMBRE_ADSR.get(timbre, {})
	var timbre_fatigue_mult: float = MusicData.TIMBRE_FATIGUE_PENALTY.get(
		FatigueManager.current_level, 1.0
	)

	# 计算基础伤害
	var base_damage: float = root_stats["dmg"] * MusicData.PARAM_CONVERSION["dmg_per_point"] * chord_multiplier * damage_mult * timbre_fatigue_mult

	# ★ 密度过载伤害衰减
	base_damage *= FatigueManager.get_density_damage_multiplier()

	# 应用增伤 Buff
	if _empower_buff_active:
		base_damage *= _empower_buff_multiplier
		_empower_buff_active = false
		_empower_buff_multiplier = 1.0

	# ★ 密度过载精准度惩罚
	var accuracy_offset: float = 0.0
	if FatigueManager.is_density_overloaded:
		accuracy_offset = FatigueManager.current_accuracy_penalty
		accuracy_penalized.emit(accuracy_offset)
		noise_overload_triggered.emit({"density": FatigueManager.current_density_damage_multiplier})

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
		"accuracy_offset": accuracy_offset,
		"density_damage_multiplier": FatigueManager.get_density_damage_multiplier(),
	}

	# 记录疲劳事件
	FatigueManager.record_spell({
		"time": GameManager.game_time,
		"note": chord_result["root"],
		"is_chord": true,
		"chord_type": chord_type,
	})

	# 扩展和弦额外疲劳注入
	if extra_fatigue > 0.0:
		FatigueManager.add_external_fatigue(extra_fatigue)

	# 记录和弦进行 (OPT01: 传入根音以供和声指挥官使用)
	var chord_root: int = chord_result.get("root", 0) % 12
	var progression = MusicTheoryEngine.record_chord(chord_type, chord_root)
	if not progression.is_empty():
		chord_data["progression"] = progression
		# 触发和弦进行效果
		_trigger_progression_effect(progression)

	# 播放和弦音效（带和弦形态效果）
	var chord_notes_for_sound: Array = chord_result.get("notes", [])
	var note_enums: Array = []
	for n in chord_notes_for_sound:
		note_enums.append(n % 12)  # 转换为 Note 枚举 (0-11)
	var gmm := get_node_or_null("/root/GlobalMusicManager")
	if gmm:
		if gmm.has_method("play_chord_sound_with_effect"):
			# 播放带和弦形态效果的和弦
			gmm.play_chord_sound_with_effect(note_enums, chord_type, 0.3, timbre)
		elif gmm.has_method("play_chord_sound"):
			# 回退到普通和弦
			gmm.play_chord_sound(note_enums, 0.3, timbre)

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
# 和弦进行效果（完整实现）
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

## T→D: 下一个法术伤害翻倍
func _apply_empower_buff(bonus_mult: float) -> void:
	_empower_buff_active = true
	_empower_buff_multiplier = EMPOWER_BUFF_MULTIPLIER * bonus_mult

## PD→D: 全体冷却缩减
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

func _midi_to_black_key(note: int) -> int:
	var pc := note % 12
	match pc:
		1: return MusicData.BlackKey.CS
		3: return MusicData.BlackKey.DS
		6: return MusicData.BlackKey.FS
		8: return MusicData.BlackKey.GS
		10: return MusicData.BlackKey.AS
		_: return -1

	func _execute_spell(spell_data: Dictionary) -> void:
		# 应用手动施法的时机奖励
		var timing_bonus: float = spell_data.get("timing_bonus", 1.0)
		if timing_bonus != 1.0:
			spell_data["damage"] = spell_data.get("damage", 0.0) * timing_bonus
		
		# ★ Issue #100: 应用寂静惩罚和密度过载惩罚
		var silence_damage_mult: float = spell_data.get("silence_damage_mult", 1.0)
		var density_damage_multiplier: float = spell_data.get("density_damage_multiplier", 1.0)
		spell_data["damage"] = spell_data.get("damage", 0.0) * silence_damage_mult * density_damage_multiplier

		spell_cast.emit(spell_data)

## 获取序列器当前位置
func get_sequencer_position() -> int:
	return _sequencer_position

## 获取序列器数据
func get_sequencer_data() -> Array:
	return sequencer.duplicate(true)

## 重置系统状态（供 GameManager.reset_game 调用）
func reset() -> void:
	# ★ 音符经济：先卸下所有已装备的内容
	for i in range(SEQUENCER_LENGTH):
		_unequip_sequencer_slot(i)
	for i in range(MAX_MANUAL_SLOTS):
		_unequip_manual_slot(i)

	_init_sequencer()
	_init_manual_slots()
	_empower_buff_active = false
	_empower_buff_multiplier = 1.0
	_pending_modifier = -1
	_has_pending_modifier = false
	_chord_buffer.clear()
	_in_half_beat_window = false
	# 重置频谱相位 (Issue #50)
	_current_spectral_phase = 0
	phase_energy = MAX_PHASE_ENERGY

# ============================================================
# 频谱相位系统 (Issue #50 — Resonance Slicing)
# ============================================================

## 切换频谱相位
## phase: 0=全频, 1=高通, 2=低通
func switch_spectral_phase(phase: int) -> void:
	if phase < 0 or phase > 2:
		return
	if phase == _current_spectral_phase:
		return
	# 切换到极端相位需要能量
	if phase != 0:
		if phase_energy < PHASE_SWITCH_COST:
			return  # 能量不足，无法切换
		phase_energy -= PHASE_SWITCH_COST
	_current_spectral_phase = phase
	var phase_name: String = PHASE_NAMES[phase]
	phase_switched.emit(phase_name)

## 快捷切换：切换到高通相位
func switch_to_overtone() -> void:
	switch_spectral_phase(1)

## 快捷切换：切换到低通相位
func switch_to_sub_bass() -> void:
	switch_spectral_phase(2)

## 快捷切换：返回全频相位
func switch_to_fundamental() -> void:
	switch_spectral_phase(0)

## 获取当前相位
func get_current_spectral_phase() -> int:
	return _current_spectral_phase

## 获取当前相位名称
func get_current_phase_name() -> String:
	return PHASE_NAMES[_current_spectral_phase]

## 获取相位能量比例
func get_phase_energy_ratio() -> float:
	return phase_energy / MAX_PHASE_ENERGY

## 每帧更新相位能量（在 _process 中调用）
func _update_phase_energy(delta: float) -> void:
	if _current_spectral_phase == 0:
		# 全频相位：恢复能量，恢复速度与 AFI 负相关
		var afi: float = FatigueManager.current_afi
		var regen_rate: float
		if afi < 0.3:
			regen_rate = 20.0
		elif afi < 0.5:
			regen_rate = 15.0
		elif afi < 0.8:
			regen_rate = 10.0
		elif afi < 1.0:
			regen_rate = 5.0
		else:
			regen_rate = 0.0
		phase_energy = minf(phase_energy + regen_rate * delta, MAX_PHASE_ENERGY)
	else:
		# 极端相位：持续消耗能量
		phase_energy -= PHASE_SUSTAIN_COST * delta
		if phase_energy <= 0.0:
			phase_energy = 0.0
			# 能量耗尽，强制返回全频相位
			switch_to_fundamental()

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

	# 同步到 GlobalMusicManager（内部会级联通知 SynthManager）
	var gmm := get_node_or_null("/root/GlobalMusicManager")
	if gmm and gmm.has_method("set_timbre"):
		gmm.set_timbre(timbre)

	# OPT08: 直接通知 SynthManager 更新音色参数（双保险）
	var sm := get_node_or_null("/root/SynthManager")
	if sm and sm.has_method("update_timbre"):
		sm.update_timbre(timbre)

	timbre_changed.emit(timbre)

## 获取当前音色系别
func get_current_timbre() -> MusicData.TimbreType:
	return _current_timbre

## 获取音色系别信息
## 返回合并后的音色数据（基础 ADSR + OPT08 合成器参数）
func get_timbre_info(timbre: MusicData.TimbreType) -> Dictionary:
	var base_info: Dictionary = MusicData.TIMBRE_ADSR.get(timbre, {})
	# OPT08: 如果 SynthManager 可用，补充合成器参数信息
	var sm := get_node_or_null("/root/SynthManager")
	if sm and sm.has_method("get_synth_params_for_timbre"):
		var synth_info: Dictionary = sm.get_synth_params_for_timbre(timbre)
		if not synth_info.is_empty():
			base_info = base_info.duplicate()
			base_info["synth_params"] = synth_info
	return base_info
