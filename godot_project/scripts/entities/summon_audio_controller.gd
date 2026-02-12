## summon_audio_controller.gd
## 召唤物音频控制器 (OPT07 — 召唤系统音乐性深化)
##
## 挂载在每个构造体节点上，负责将构造体的行为转化为
## 真实的、与 BGM 同步的音频事件。每种构造体对应一个
## 明确的音乐声部，拥有独特的音色和节奏模式。
##
## 核心设计：
##   - 声部化：每种召唤物对应一个明确的音乐声部
##   - 节拍严格：所有音频事件严格量化到节拍网格上
##   - 和声一致：有音高的音效经过和声指挥官的音阶锁定
##   - 空间化：音效从战场上的实际位置发出
##
## 参考文档：
##   Docs/Optimization_Modules/OPT07_SummoningSystemMusicality.md
##   Docs/Optimization_Modules/OPT01_GlobalDynamicHarmonyConductor.md
##   Docs/Optimization_Modules/OPT05_RezStyleInputQuantization.md
extends Node2D

# ============================================================
# 信号
# ============================================================
signal audio_triggered(timbre_id: String, frequency: float)
signal audio_sustained_updated(timbre_id: String, chord_notes: Array)

# ============================================================
# 配置
# ============================================================

## 音频配置资源
var audio_profile: SummonAudioProfile = null

# ============================================================
# 内部状态
# ============================================================

## 空间化音频播放器
var _audio_player: AudioStreamPlayer2D = null

## 全局音频播放器（用于非空间化的备用）
var _audio_player_global: AudioStreamPlayer = null

## 琶音序列当前位置
var _arpeggio_index: int = 0

## 是否已激活
var _is_active: bool = false

## 持续型音效的当前和弦音
var _sustained_chord_notes: Array[int] = []

## 持续型音效的播放状态
var _sustained_playing: bool = false

## 程序化合成的采样缓存
var _synth_samples: Dictionary = {}

## 当前和声上下文缓存
var _cached_chord: Dictionary = {}

# ============================================================
# 音色合成参数
# ============================================================

## 采样率
const SAMPLE_RATE: int = 44100
## 默认音效时长（秒）
const DEFAULT_TONE_DURATION: float = 0.15
## Pad 循环时长（秒）
const PAD_LOOP_DURATION: float = 2.0
## 808 Kick 时长（秒）
const SUB_BASS_DURATION: float = 0.3
## Hi-hat 时长（秒）
const HIHAT_DURATION: float = 0.04

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	if audio_profile == null:
		push_warning("SummonAudioController: audio_profile 未设置")
		return
	
	# 创建空间化音频播放器
	_audio_player = AudioStreamPlayer2D.new()
	_audio_player.bus = "SFX_Summon"
	_audio_player.max_distance = 800.0
	_audio_player.attenuation = 1.5
	add_child(_audio_player)
	
	# 根据触发模式连接不同的信号
	_connect_trigger_signals()
	
	# 监听和声变更（用于持续型和琶音型）
	if BgmManager.has_signal("harmony_context_changed"):
		if not BgmManager.harmony_context_changed.is_connected(_on_harmony_changed):
			BgmManager.harmony_context_changed.connect(_on_harmony_changed)
	
	_is_active = true
	
	# 如果是持续型，立即开始播放
	if audio_profile.trigger_mode == SummonAudioProfile.TriggerMode.SUSTAINED:
		_start_sustained_playback()

func _exit_tree() -> void:
	deactivate()

# ============================================================
# 信号连接
# ============================================================

func _connect_trigger_signals() -> void:
	match audio_profile.trigger_mode:
		SummonAudioProfile.TriggerMode.PER_BEAT:
			if BgmManager.has_signal("bgm_beat_synced"):
				BgmManager.bgm_beat_synced.connect(_on_beat)
		
		SummonAudioProfile.TriggerMode.PER_STRONG_BEAT:
			if BgmManager.has_signal("bgm_beat_synced"):
				BgmManager.bgm_beat_synced.connect(_on_beat_strong_only)
		
		SummonAudioProfile.TriggerMode.PER_SIXTEENTH:
			# 连接十六分音符信号
			if BgmManager.has_signal("sixteenth_tick"):
				BgmManager.sixteenth_tick.connect(_on_sixteenth)
			elif BgmManager.has_signal("bgm_beat_synced"):
				# 回退：使用节拍信号模拟（精度降低）
				BgmManager.bgm_beat_synced.connect(_on_beat)
		
		SummonAudioProfile.TriggerMode.ON_EVENT:
			# 事件型：不自动连接，由外部调用 trigger_on_event()
			pass
		
		SummonAudioProfile.TriggerMode.SUSTAINED:
			# 持续型：在 _ready 中已处理
			pass

# ============================================================
# 节拍回调
# ============================================================

## 每拍触发
func _on_beat(beat_index: int) -> void:
	if not _is_active:
		return
	_trigger_sound()

## 仅强拍触发 (4/4 拍的第 0、2 拍)
func _on_beat_strong_only(beat_index: int) -> void:
	if not _is_active:
		return
	if beat_index % 2 == 0:
		_trigger_sound()

## 十六分音符触发
func _on_sixteenth() -> void:
	if not _is_active:
		return
	_trigger_sound()

## 事件触发（由游戏逻辑调用）
func trigger_on_event() -> void:
	if not _is_active:
		return
	_trigger_sound()

# ============================================================
# 核心：触发音效
# ============================================================

func _trigger_sound() -> void:
	if audio_profile == null or _audio_player == null:
		return
	
	var midi_note: int = _resolve_pitch()
	
	if midi_note < 0:
		# 无音高（纯打击乐）
		_play_percussion_tone(audio_profile.timbre_id)
	else:
		# 有音高
		var frequency: float = _midi_to_frequency(midi_note)
		_play_summon_tone(frequency, audio_profile.timbre_id)
	
	audio_triggered.emit(audio_profile.timbre_id, _midi_to_frequency(midi_note) if midi_note >= 0 else 0.0)

# ============================================================
# 音高解析
# ============================================================

func _resolve_pitch() -> int:
	# 尝试从 BgmManager 获取和声上下文
	var chord: Dictionary = _get_current_chord()
	var scale: Array = _get_current_scale()
	var base: int = audio_profile.base_octave * 12 + 12  # MIDI 基准
	
	match audio_profile.pitch_strategy:
		SummonAudioProfile.PitchStrategy.CHORD_ROOT:
			var root: int = chord.get("root", 0)
			return base + root
		
		SummonAudioProfile.PitchStrategy.CHORD_FIFTH:
			var root: int = chord.get("root", 0)
			var fifth: int = (root + 7) % 12
			# 音阶锁定
			if BgmManager.has_method("quantize_to_scale"):
				fifth = BgmManager.quantize_to_scale(fifth)
			return base + fifth
		
		SummonAudioProfile.PitchStrategy.CHORD_ARPEGGIO:
			var notes: Array = chord.get("notes", [0, 4, 7])
			if notes.is_empty():
				return base
			var note: int = notes[_arpeggio_index % notes.size()]
			_arpeggio_index += 1
			return base + note
		
		SummonAudioProfile.PitchStrategy.CHORD_FULL:
			# 用于 Pad 类型，返回和弦根音（实际播放和弦由持续型处理）
			var root: int = chord.get("root", 0)
			return base + root
		
		SummonAudioProfile.PitchStrategy.SCALE_DESCEND:
			if scale.is_empty():
				return base
			var idx: int = _arpeggio_index % scale.size()
			_arpeggio_index += 1
			return base + scale[scale.size() - 1 - idx]
		
		SummonAudioProfile.PitchStrategy.NO_PITCH:
			return -1  # 无音高
		
		_:
			return base + chord.get("root", 0)

# ============================================================
# 和声上下文查询
# ============================================================

func _get_current_chord() -> Dictionary:
	if BgmManager.has_method("get_current_chord"):
		return BgmManager.get_current_chord()
	# 回退：使用默认 Am 和弦
	return {"root": 9, "type": 0, "notes": [9, 0, 4]}

func _get_current_scale() -> Array:
	if BgmManager.has_method("get_current_scale"):
		return BgmManager.get_current_scale()
	# 回退：A 自然小调
	return [9, 11, 0, 2, 4, 5, 7]

# ============================================================
# 持续型播放
# ============================================================

func _start_sustained_playback() -> void:
	var chord: Dictionary = _get_current_chord()
	var notes: Array = chord.get("notes", [0, 4, 7])
	_sustained_chord_notes.assign(notes)
	
	match audio_profile.timbre_id:
		"pad_drone":
			_play_sustained_pad(notes, audio_profile.base_octave)
		"gate_pulse":
			_play_sustained_gate_pulse(notes, audio_profile.base_octave)
		_:
			_play_sustained_pad(notes, audio_profile.base_octave)
	
	_sustained_playing = true

## 和声变更时更新
func _on_harmony_changed(root: int, type: int, notes: Array) -> void:
	if audio_profile == null:
		return
	
	if audio_profile.trigger_mode == SummonAudioProfile.TriggerMode.SUSTAINED:
		_sustained_chord_notes.assign(notes)
		_update_sustained_sound(notes, audio_profile.base_octave)
	
	# 重置琶音序列
	_arpeggio_index = 0
	
	# 缓存和弦
	_cached_chord = {"root": root, "type": type, "notes": notes}
	
	audio_sustained_updated.emit(audio_profile.timbre_id, notes)

# ============================================================
# 程序化音色合成
# ============================================================

## 播放有音高的召唤物音效
func _play_summon_tone(frequency: float, timbre_id: String) -> void:
	if _audio_player == null:
		return
	
	var stream: AudioStreamWAV = _synthesize_tone(frequency, timbre_id)
	if stream == null:
		return
	
	_audio_player.stream = stream
	_audio_player.volume_db = audio_profile.volume_db
	_audio_player.pitch_scale = 1.0
	_audio_player.play()

## 播放无音高的打击乐音效
func _play_percussion_tone(timbre_id: String) -> void:
	if _audio_player == null:
		return
	
	var stream: AudioStreamWAV = _synthesize_percussion(timbre_id)
	if stream == null:
		return
	
	_audio_player.stream = stream
	_audio_player.volume_db = audio_profile.volume_db
	_audio_player.pitch_scale = randf_range(0.9, 1.1)  # 轻微随机化
	_audio_player.play()

## 播放持续型 Pad 音效
func _play_sustained_pad(notes: Array, octave: int) -> void:
	if _audio_player == null:
		return
	
	var freqs: Array[float] = []
	for note in notes:
		var midi: int = octave * 12 + 12 + (note as int)
		freqs.append(_midi_to_frequency(midi))
	
	var stream: AudioStreamWAV = _synthesize_pad(freqs)
	if stream == null:
		return
	
	_audio_player.stream = stream
	_audio_player.volume_db = audio_profile.volume_db
	_audio_player.play()

## 播放持续型 Gate Pulse 音效
func _play_sustained_gate_pulse(notes: Array, octave: int) -> void:
	if _audio_player == null:
		return
	
	var root_note: int = notes[0] if notes.size() > 0 else 0
	var midi: int = octave * 12 + 12 + root_note
	var frequency: float = _midi_to_frequency(midi)
	
	var stream: AudioStreamWAV = _synthesize_gate_pulse(frequency)
	if stream == null:
		return
	
	_audio_player.stream = stream
	_audio_player.volume_db = audio_profile.volume_db
	_audio_player.play()

## 更新持续型音效
func _update_sustained_sound(notes: Array, octave: int) -> void:
	match audio_profile.timbre_id:
		"pad_drone":
			_play_sustained_pad(notes, octave)
		"gate_pulse":
			_play_sustained_gate_pulse(notes, octave)

# ============================================================
# 音色合成引擎 — 程序化生成各种音色
# ============================================================

## 合成有音高的音色
func _synthesize_tone(frequency: float, timbre_id: String) -> AudioStreamWAV:
	match timbre_id:
		"pluck":
			return _gen_pluck(frequency, DEFAULT_TONE_DURATION)
		"delay_echo":
			return _gen_delay_echo(frequency, DEFAULT_TONE_DURATION * 2.0)
		"denoise_sweep":
			return _gen_sweep(frequency, DEFAULT_TONE_DURATION * 1.5)
		"sub_bass_808":
			return _gen_sub_bass(frequency, SUB_BASS_DURATION)
		_:
			return _gen_pluck(frequency, DEFAULT_TONE_DURATION)

## 合成打击乐音色
func _synthesize_percussion(timbre_id: String) -> AudioStreamWAV:
	match timbre_id:
		"hihat_pattern":
			return _gen_hihat(HIHAT_DURATION)
		_:
			return _gen_hihat(HIHAT_DURATION)

## 合成 Pad 和弦
func _synthesize_pad(frequencies: Array[float]) -> AudioStreamWAV:
	return _gen_pad_chord(frequencies, PAD_LOOP_DURATION)

## 合成 Gate Pulse
func _synthesize_gate_pulse(frequency: float) -> AudioStreamWAV:
	return _gen_gate_pulse(frequency, PAD_LOOP_DURATION)

# ============================================================
# 具体音色生成函数
# ============================================================

## Pluck / Rimshot — 清脆、短促的合成器拨弦音
func _gen_pluck(freq: float, duration: float) -> AudioStreamWAV:
	var num_samples: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = exp(-t * 20.0)  # 快速衰减
		
		# 基频 + 泛音
		var sample: float = sin(TAU * freq * t) * 0.6
		sample += sin(TAU * freq * 2.0 * t) * 0.25 * exp(-t * 30.0)
		sample += sin(TAU * freq * 3.0 * t) * 0.1 * exp(-t * 40.0)
		
		# 起音噪声（模拟拨弦的瞬态）
		if t < 0.005:
			sample += (randf() * 2.0 - 1.0) * 0.3 * (1.0 - t / 0.005)
		
		sample *= envelope
		sample = clampf(sample, -1.0, 1.0)
		
		var s16: int = int(sample * 32000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	
	return _create_wav(data)

## Delay Echo — 上升琶音 + 延迟回声
func _gen_delay_echo(freq: float, duration: float) -> AudioStreamWAV:
	var num_samples: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	var delay_time: float = 0.08  # 80ms 延迟
	var delay_samples: int = int(SAMPLE_RATE * delay_time)
	
	for i in range(num_samples):
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = exp(-t * 8.0)
		
		# 主音
		var sample: float = sin(TAU * freq * t) * 0.5
		# 上行琶音（频率逐渐升高）
		var arp_freq: float = freq * (1.0 + t * 2.0)
		sample += sin(TAU * arp_freq * t) * 0.3 * exp(-t * 12.0)
		
		# 延迟回声
		if i > delay_samples:
			var echo_t: float = float(i - delay_samples) / SAMPLE_RATE
			sample += sin(TAU * freq * echo_t) * 0.2 * exp(-echo_t * 10.0)
		if i > delay_samples * 2:
			var echo_t2: float = float(i - delay_samples * 2) / SAMPLE_RATE
			sample += sin(TAU * freq * echo_t2) * 0.1 * exp(-echo_t2 * 12.0)
		
		sample *= envelope
		sample = clampf(sample, -1.0, 1.0)
		
		var s16: int = int(sample * 32000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	
	return _create_wav(data)

## De-noise Sweep — 从高到低的滤波扫频
func _gen_sweep(freq: float, duration: float) -> AudioStreamWAV:
	var num_samples: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t: float = float(i) / SAMPLE_RATE
		var progress: float = t / duration
		var envelope: float = (1.0 - progress) * exp(-t * 4.0)
		
		# 频率从高到低扫描
		var sweep_freq: float = freq * (3.0 - progress * 2.5)
		var sample: float = sin(TAU * sweep_freq * t) * 0.4
		
		# 添加噪声成分（模拟滤波扫频）
		sample += (randf() * 2.0 - 1.0) * 0.15 * (1.0 - progress)
		
		sample *= envelope
		sample = clampf(sample, -1.0, 1.0)
		
		var s16: int = int(sample * 32000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	
	return _create_wav(data)

## Sub-Bass 808 — 深沉、有冲击力的低频
func _gen_sub_bass(freq: float, duration: float) -> AudioStreamWAV:
	var num_samples: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = exp(-t * 6.0)
		
		# 808 风格：快速频率下扫
		var sweep: float = freq * (1.0 + 3.0 * exp(-t * 30.0))
		var sample: float = sin(TAU * sweep * t) * 0.8
		
		# 添加谐波失真
		sample += sin(TAU * sweep * 2.0 * t) * 0.15 * exp(-t * 15.0)
		
		# 起音冲击
		if t < 0.01:
			sample += (randf() * 2.0 - 1.0) * 0.4 * (1.0 - t / 0.01)
		
		sample *= envelope
		sample = clampf(sample, -1.0, 1.0)
		
		var s16: int = int(sample * 32000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	
	return _create_wav(data)

## Hi-hat Pattern — 快速的高频噪声
func _gen_hihat(duration: float) -> AudioStreamWAV:
	var num_samples: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = exp(-t * 60.0)  # 极快衰减
		
		# 高频噪声
		var sample: float = (randf() * 2.0 - 1.0) * 0.5
		# 添加金属质感
		sample += sin(TAU * 8000.0 * t) * 0.2
		sample += sin(TAU * 12000.0 * t) * 0.1
		
		sample *= envelope
		sample = clampf(sample, -1.0, 1.0)
		
		var s16: int = int(sample * 32000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	
	return _create_wav(data)

## Pad Chord — 柔和的和声铺底
func _gen_pad_chord(freqs: Array[float], duration: float) -> AudioStreamWAV:
	var num_samples: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t: float = float(i) / SAMPLE_RATE
		
		# 缓慢的淡入淡出包络
		var fade_in: float = minf(t / 0.5, 1.0)
		var fade_out: float = minf((duration - t) / 0.5, 1.0)
		var envelope: float = fade_in * fade_out
		
		var sample: float = 0.0
		for freq_idx in range(freqs.size()):
			var freq: float = freqs[freq_idx]
			# 轻微去谐以增加温暖感
			var detune: float = 1.0 + (freq_idx - freqs.size() * 0.5) * 0.002
			sample += sin(TAU * freq * detune * t) * 0.3
			# 添加缓慢颤音
			sample += sin(TAU * freq * detune * t + sin(t * 3.0) * 0.1) * 0.15
		
		sample /= maxf(freqs.size(), 1.0)
		sample *= envelope
		sample = clampf(sample, -1.0, 1.0)
		
		var s16: int = int(sample * 32000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	
	var wav := _create_wav(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = num_samples
	return wav

## Gate Pulse — 节奏性的门限脉冲
func _gen_gate_pulse(freq: float, duration: float) -> AudioStreamWAV:
	var num_samples: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	# 门限频率（每秒脉冲数，与 BPM 同步）
	var gate_freq: float = 4.0  # 默认 4Hz（每秒 4 个脉冲）
	if BgmManager.has_method("get_bgm_bpm"):
		gate_freq = BgmManager.get_bgm_bpm() / 60.0
	
	for i in range(num_samples):
		var t: float = float(i) / SAMPLE_RATE
		
		# 门限包络：方波门控
		var gate: float = 1.0 if fmod(t * gate_freq, 1.0) < 0.3 else 0.0
		
		# 基频
		var sample: float = sin(TAU * freq * t) * 0.5
		# 添加方波谐波
		sample += sign(sin(TAU * freq * t)) * 0.2
		
		# 整体包络
		var fade_in: float = minf(t / 0.2, 1.0)
		var fade_out: float = minf((duration - t) / 0.3, 1.0)
		
		sample *= gate * fade_in * fade_out
		sample = clampf(sample, -1.0, 1.0)
		
		var s16: int = int(sample * 32000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	
	var wav := _create_wav(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = num_samples
	return wav

# ============================================================
# WAV 工具
# ============================================================

func _create_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

# ============================================================
# MIDI 工具
# ============================================================

## MIDI 音符号 → 频率 (Hz)
func _midi_to_frequency(midi_note: int) -> float:
	return 440.0 * pow(2.0, (midi_note - 69) / 12.0)

# ============================================================
# 停用与清理
# ============================================================

## 停用音频控制器
func deactivate() -> void:
	_is_active = false
	_sustained_playing = false
	
	if _audio_player and is_instance_valid(_audio_player):
		_audio_player.stop()
	
	# 断开信号
	if BgmManager.has_signal("bgm_beat_synced"):
		if BgmManager.bgm_beat_synced.is_connected(_on_beat):
			BgmManager.bgm_beat_synced.disconnect(_on_beat)
		if BgmManager.bgm_beat_synced.is_connected(_on_beat_strong_only):
			BgmManager.bgm_beat_synced.disconnect(_on_beat_strong_only)
	
	if BgmManager.has_signal("sixteenth_tick"):
		if BgmManager.sixteenth_tick.is_connected(_on_sixteenth):
			BgmManager.sixteenth_tick.disconnect(_on_sixteenth)
	
	if BgmManager.has_signal("harmony_context_changed"):
		if BgmManager.harmony_context_changed.is_connected(_on_harmony_changed):
			BgmManager.harmony_context_changed.disconnect(_on_harmony_changed)

## 获取当前是否活跃
func is_audio_active() -> bool:
	return _is_active

## 获取音频配置信息（供 UI/调试使用）
func get_audio_info() -> Dictionary:
	return {
		"timbre_id": audio_profile.timbre_id if audio_profile else "none",
		"trigger_mode": audio_profile.trigger_mode if audio_profile else -1,
		"pitch_strategy": audio_profile.pitch_strategy if audio_profile else -1,
		"is_active": _is_active,
		"arpeggio_index": _arpeggio_index,
		"sustained_playing": _sustained_playing,
	}
