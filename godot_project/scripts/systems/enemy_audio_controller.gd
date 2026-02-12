## enemy_audio_controller.gd
## 敌人音频控制器 — OPT03: 敌人乐器身份与音高维度
##
## 挂载在敌人节点上的音频控制组件。负责在敌人执行行为时，
## 在原始噪音音效之上叠加一个经过音阶锁定的音高层，
## 使敌人成为动态乐曲中一个虽然"脏"但音高正确的声部。
##
## 核心流程:
##   1. 根据 EnemyAudioProfile 的 pitch_strategy 确定目标音高
##   2. 通过 BgmManager.quantize_to_scale() 进行音阶锁定
##   3. 程序化合成音高层 AudioStreamWAV
##   4. 通过 AudioStreamPlayer2D 播放（支持空间化）
##
## 设计参考: OPT03_EnemyMusicalInstrumentIdentity.md
class_name EnemyAudioController
extends Node

# ============================================================
# 常量
# ============================================================
const SAMPLE_RATE: int = 44100
const TWO_PI: float = TAU
const ENEMY_SFX_BUS: String = "EnemySFX"

# ============================================================
# 配置
# ============================================================

## 音频配置资源
var profile: EnemyAudioProfile = null

# ============================================================
# 内部状态
# ============================================================

## 音高层播放器 (2D 空间化)
var _pitch_player: AudioStreamPlayer2D = null

## 持续型音效播放器 (Silence/Wall drone)
var _sustained_player: AudioStreamPlayer2D = null

## 琶音状态 (Pulse 专用)
var _arpeggio_index: int = 0
var _arpeggio_direction: int = 1  ## 1=上行, -1=下行

## BgmManager 引用缓存
var _bgm: Node = null

## 当前持续音高 (用于和声变更时更新)
var _current_sustained_pitch: int = -1

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 创建音高层播放器
	_pitch_player = AudioStreamPlayer2D.new()
	_pitch_player.name = "PitchPlayer"
	_pitch_player.bus = ENEMY_SFX_BUS if AudioServer.get_bus_index(ENEMY_SFX_BUS) >= 0 else "Master"
	_pitch_player.max_distance = 1000.0
	_pitch_player.attenuation = 1.5
	add_child(_pitch_player)

	# 创建持续型播放器
	_sustained_player = AudioStreamPlayer2D.new()
	_sustained_player.name = "SustainedPlayer"
	_sustained_player.bus = _pitch_player.bus
	_sustained_player.max_distance = 1200.0
	_sustained_player.attenuation = 1.0
	add_child(_sustained_player)

	# 缓存 BgmManager 引用
	_bgm = get_node_or_null("/root/BgmManager")

	# 连接和声变更信号（用于持续型音效的实时更新）
	if _bgm and _bgm.has_signal("harmony_context_changed"):
		if not _bgm.harmony_context_changed.is_connected(_on_harmony_changed):
			_bgm.harmony_context_changed.connect(_on_harmony_changed)

func _exit_tree() -> void:
	stop_sustained()
	if _bgm and _bgm.has_signal("harmony_context_changed"):
		if _bgm.harmony_context_changed.is_connected(_on_harmony_changed):
			_bgm.harmony_context_changed.disconnect(_on_harmony_changed)

# ============================================================
# 公共接口
# ============================================================

## 根据敌人类型设置音频配置
func setup_for_enemy_type(type_name: String) -> void:
	match type_name:
		"static":
			profile = EnemyAudioProfile.create_static_profile()
		"silence":
			profile = EnemyAudioProfile.create_silence_profile()
		"screech":
			profile = EnemyAudioProfile.create_screech_profile()
		"pulse":
			profile = EnemyAudioProfile.create_pulse_profile()
		"wall":
			profile = EnemyAudioProfile.create_wall_profile()
		_:
			profile = EnemyAudioProfile.create_static_profile()

	# 设置音高层音量
	if _pitch_player:
		_pitch_player.volume_db = profile.pitch_volume_db
	if _sustained_player:
		_sustained_player.volume_db = profile.pitch_volume_db

	# 如果是持续型，立即启动 drone
	if profile.is_sustained:
		_start_sustained()

## 播放行为音高层
## behavior: "move", "attack", "hit", "death"
func play_behavior_pitch(behavior: String) -> void:
	if profile == null or _bgm == null:
		return

	# 持续型敌人的 move 行为不需要额外触发（已有 drone）
	if profile.is_sustained and behavior == "move":
		return

	# 解析目标音高
	var target_midi: int = _resolve_target_pitch()
	if target_midi < 0:
		return

	# 计算频率
	var frequency: float = _midi_to_freq(target_midi)

	# 根据行为类型调整音效参数
	var duration: float = _get_behavior_duration(behavior)

	# 合成并播放
	var tone: AudioStreamWAV = _synthesize_tone(frequency, duration)
	if tone and _pitch_player:
		_pitch_player.stream = tone
		_pitch_player.play()

## 停止持续型音效
func stop_sustained() -> void:
	if _sustained_player and _sustained_player.playing:
		# 淡出
		var tween := create_tween()
		tween.tween_property(_sustained_player, "volume_db", -40.0, 0.3)
		tween.tween_callback(func():
			_sustained_player.stop()
			if profile:
				_sustained_player.volume_db = profile.pitch_volume_db
		)
	_current_sustained_pitch = -1

# ============================================================
# 音高解析 — 根据策略选择目标 MIDI 音高
# ============================================================

func _resolve_target_pitch() -> int:
	if _bgm == null or profile == null:
		return -1

	var base_midi: int = (profile.base_octave + 1) * 12  # 八度起始 MIDI 值
	var scale: Array = _bgm.get_current_scale() if _bgm.has_method("get_current_scale") else []
	var chord: Dictionary = _bgm.get_current_chord() if _bgm.has_method("get_current_chord") else {}
	var chord_notes: Array = chord.get("notes", [])
	var chord_root: int = chord.get("root", 0)  # OPT04: 默认回退 C (Ch1 Ionian)

	match profile.pitch_strategy:
		"random_scale":
			return _resolve_random_scale(base_midi, scale)
		"chord_root":
			return _resolve_chord_root(base_midi, chord_root)
		"chord_fifth":
			return _resolve_chord_fifth(base_midi, chord_root)
		"arpeggio":
			return _resolve_arpeggio(base_midi, chord_notes)
		"chord_approach":
			return _resolve_chord_approach(base_midi, chord_notes, scale)
		_:
			return base_midi

## Static: 随机选择音域内的音阶音
func _resolve_random_scale(base_midi: int, scale: Array) -> int:
	if scale.is_empty():
		return base_midi + randi_range(0, profile.pitch_range - 1)

	var valid_notes: Array[int] = []
	for offset in range(profile.pitch_range):
		var midi: int = base_midi + offset
		var pc: int = midi % 12
		if pc in scale:
			valid_notes.append(midi)

	if valid_notes.is_empty():
		return base_midi

	return valid_notes[randi() % valid_notes.size()]

## Silence: 始终演奏和弦根音
func _resolve_chord_root(base_midi: int, chord_root: int) -> int:
	var target_pc: int = chord_root % 12
	for offset in range(profile.pitch_range):
		var midi: int = base_midi + offset
		if midi % 12 == target_pc:
			return midi
	return base_midi + target_pc

## Wall: 始终演奏和弦五音
func _resolve_chord_fifth(base_midi: int, chord_root: int) -> int:
	var fifth_pc: int = -1
	if _bgm and _bgm.has_method("get_chord_note_for_degree"):
		fifth_pc = _bgm.get_chord_note_for_degree(5)
	if fifth_pc < 0:
		fifth_pc = (chord_root + 7) % 12

	for offset in range(profile.pitch_range):
		var midi: int = base_midi + offset
		if midi % 12 == fifth_pc:
			return midi
	return base_midi + fifth_pc

## Pulse: 琶音序列 — 按模式依次演奏和弦组成音
func _resolve_arpeggio(base_midi: int, chord_notes: Array) -> int:
	if chord_notes.is_empty():
		return base_midi

	var note_count: int = chord_notes.size()
	var current_pc: int = chord_notes[_arpeggio_index % note_count]

	# 推进琶音索引
	match profile.arpeggio_mode:
		"up":
			_arpeggio_index = (_arpeggio_index + 1) % note_count
		"down":
			_arpeggio_index = (_arpeggio_index - 1 + note_count) % note_count
		"up_down":
			_arpeggio_index += _arpeggio_direction
			if _arpeggio_index >= note_count - 1:
				_arpeggio_direction = -1
				_arpeggio_index = note_count - 1
			elif _arpeggio_index <= 0:
				_arpeggio_direction = 1
				_arpeggio_index = 0
		"random":
			_arpeggio_index = randi() % note_count

	for offset in range(profile.pitch_range):
		var midi: int = base_midi + offset
		if midi % 12 == current_pc:
			return midi
	return base_midi + current_pc

## Screech: 经过音→解决到和弦音
func _resolve_chord_approach(base_midi: int, chord_notes: Array, scale: Array) -> int:
	if chord_notes.is_empty():
		return base_midi

	var target_pc: int = chord_notes[randi() % chord_notes.size()]
	var approach_pc: int = (target_pc + profile.approach_offset) % 12

	if _bgm and _bgm.has_method("quantize_to_scale"):
		approach_pc = _bgm.quantize_to_scale(approach_pc)

	for offset in range(profile.pitch_range):
		var midi: int = base_midi + offset
		if midi % 12 == approach_pc:
			return midi
	return base_midi + approach_pc

# ============================================================
# 持续型音效管理 (Silence / Wall drone)
# ============================================================

func _start_sustained() -> void:
	if profile == null or _bgm == null:
		return

	var target_midi: int = _resolve_target_pitch()
	if target_midi < 0:
		return

	_current_sustained_pitch = target_midi
	var frequency: float = _midi_to_freq(target_midi)
	var tone: AudioStreamWAV = _synthesize_sustained_tone(frequency)

	if tone and _sustained_player:
		_sustained_player.stream = tone
		_sustained_player.play()

## 和声变更时更新持续型音效
func _on_harmony_changed(_chord_root: int, _chord_type: int, _chord_notes: Array) -> void:
	if profile == null or not profile.is_sustained:
		return
	if not _sustained_player or not _sustained_player.playing:
		return

	var new_midi: int = _resolve_target_pitch()
	if new_midi < 0 or new_midi == _current_sustained_pitch:
		return

	_current_sustained_pitch = new_midi
	var frequency: float = _midi_to_freq(new_midi)
	var new_tone: AudioStreamWAV = _synthesize_sustained_tone(frequency)

	if new_tone:
		var old_vol: float = _sustained_player.volume_db
		var tween := create_tween()
		tween.tween_property(_sustained_player, "volume_db", -30.0, 0.2)
		tween.tween_callback(func():
			_sustained_player.stream = new_tone
			_sustained_player.play()
		)
		tween.tween_property(_sustained_player, "volume_db", old_vol, 0.2)

# ============================================================
# 音高层合成
# ============================================================

## 合成瞬态音高层 (短促音效)
func _synthesize_tone(frequency: float, duration: float) -> AudioStreamWAV:
	if profile == null:
		return null

	var num_samples: int = int(SAMPLE_RATE * duration)
	if num_samples <= 0:
		return null

	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit mono

	var phase: float = 0.0
	var phase_increment: float = frequency / float(SAMPLE_RATE)

	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)

		# 波形生成
		var sample: float = _generate_waveform(phase, profile.pitch_waveform)

		# ADSR 包络
		var envelope: float = _calculate_envelope(t, duration)

		# 应用包络和音量
		sample *= envelope * (1.0 - profile.noise_mix)

		# 转换为 16-bit PCM
		var pcm: int = clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF

		phase += phase_increment
		if phase >= 1.0:
			phase -= 1.0

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

## 合成持续型音高层 (循环采样)
func _synthesize_sustained_tone(frequency: float) -> AudioStreamWAV:
	if profile == null:
		return null

	var duration: float = profile.sustained_loop_duration
	var num_samples: int = int(SAMPLE_RATE * duration)
	if num_samples <= 0:
		return null

	var data := PackedByteArray()
	data.resize(num_samples * 2)

	var phase: float = 0.0
	var phase_increment: float = frequency / float(SAMPLE_RATE)

	# 淡入淡出长度 (避免循环点 click)
	var fade_samples: int = int(SAMPLE_RATE * 0.05)

	for i in range(num_samples):
		var sample: float = _generate_waveform(phase, profile.pitch_waveform)

		var vol: float = (1.0 - profile.noise_mix) * profile.sustain_level
		if i < fade_samples:
			vol *= float(i) / float(fade_samples)
		elif i > num_samples - fade_samples:
			vol *= float(num_samples - i) / float(fade_samples)

		sample *= vol

		var pcm: int = clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF

		phase += phase_increment
		if phase >= 1.0:
			phase -= 1.0

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = fade_samples
	stream.loop_end = num_samples - fade_samples
	return stream

# ============================================================
# 波形生成
# ============================================================

func _generate_waveform(phase: float, waveform_type: int) -> float:
	match waveform_type:
		0:  # 正弦波
			return sin(phase * TWO_PI)
		1:  # 方波
			return 1.0 if phase < 0.5 else -1.0
		2:  # 锯齿波
			return 2.0 * phase - 1.0
		3:  # 三角波
			if phase < 0.25:
				return phase * 4.0
			elif phase < 0.75:
				return 2.0 - phase * 4.0
			else:
				return phase * 4.0 - 4.0
		_:
			return sin(phase * TWO_PI)

# ============================================================
# ADSR 包络
# ============================================================

func _calculate_envelope(t_normalized: float, duration: float) -> float:
	if profile == null:
		return 0.0

	var t: float = t_normalized * duration
	var total_ad: float = profile.attack_time + profile.decay_time
	var sustain_end: float = duration - profile.release_time

	if t < profile.attack_time:
		return t / profile.attack_time if profile.attack_time > 0.0 else 1.0
	elif t < total_ad:
		var decay_progress: float = (t - profile.attack_time) / profile.decay_time if profile.decay_time > 0.0 else 1.0
		return lerp(1.0, profile.sustain_level, decay_progress)
	elif t < sustain_end:
		return profile.sustain_level
	else:
		var release_progress: float = (t - sustain_end) / profile.release_time if profile.release_time > 0.0 else 1.0
		return lerp(profile.sustain_level, 0.0, min(release_progress, 1.0))

# ============================================================
# 工具函数
# ============================================================

func _get_behavior_duration(behavior: String) -> float:
	if profile == null:
		return 0.1
	match behavior:
		"move":
			return profile.attack_time + profile.decay_time + 0.02
		"attack":
			return 0.2
		"hit":
			return 0.15
		"death":
			return 0.4
		_:
			return 0.1

func _midi_to_freq(midi_note: int) -> float:
	return 440.0 * pow(2.0, (midi_note - 69) / 12.0)
