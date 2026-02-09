## note_synthesizer.gd
## 音符合成器 (Note Synthesizer)
## 基于音色系统 (TimbreSystem) 为每种音色系别生成差异化的音符音效
##
## 设计理念：
##   程序化合成为核心，外部采样加载为扩展。
##   四大音色系别（弹拨/拉弦/吹奏/打击）使用不同的波形、ADSR 包络和泛音结构，
##   模拟真实乐器的音色特征。同时预留采样加载接口，允许替换为真实录音。
##
## 推荐采样来源：
##   - University of Iowa MIS: https://theremin.music.uiowa.edu/mis.html (免费)
##   - Freesound.org: https://freesound.org (CC0 / CC-BY)
##   - Philharmonia Orchestra: https://philharmonia.co.uk/resources/sound-samples/ (免费)
##
## 采样文件命名规范：
##   res://audio/samples/{timbre_type}/{note_name}.wav
##   例如: res://audio/samples/plucked/C4.wav
##         res://audio/samples/bowed/A4.wav
##
class_name NoteSynthesizer
extends RefCounted

# ============================================================
# 常量
# ============================================================

## 采样率
const SAMPLE_RATE: int = 44100

## 默认音符时长（秒）
const DEFAULT_NOTE_DURATION: float = 0.2

## 最大缓存音效数量 (12音符 × 5音色 × 3八度 = 180，实际按需生成)
const MAX_CACHE_SIZE: int = 256

## 音符名称映射 (用于采样文件加载)
const NOTE_NAMES: Dictionary = {
	MusicData.Note.C:  "C",
	MusicData.Note.CS: "Cs",
	MusicData.Note.D:  "D",
	MusicData.Note.DS: "Ds",
	MusicData.Note.E:  "E",
	MusicData.Note.F:  "F",
	MusicData.Note.FS: "Fs",
	MusicData.Note.G:  "G",
	MusicData.Note.GS: "Gs",
	MusicData.Note.A:  "A",
	MusicData.Note.AS: "As",
	MusicData.Note.B:  "B",
}

## 音色系别对应的采样目录名
const TIMBRE_DIR_NAMES: Dictionary = {
	MusicData.TimbreType.NONE:       "default",
	MusicData.TimbreType.PLUCKED:    "plucked",
	MusicData.TimbreType.BOWED:      "bowed",
	MusicData.TimbreType.WIND:       "wind",
	MusicData.TimbreType.PERCUSSIVE: "percussive",
}

## 采样根目录
const SAMPLES_BASE_DIR: String = "res://audio/samples/"

# ============================================================
# 缓存
# ============================================================

## 已生成的音效缓存 { "key": AudioStreamWAV }
## key 格式: "{timbre_type}_{note}_{octave}_{duration_ms}"
var _cache: Dictionary = {}

## 已加载的外部采样 { "key": AudioStreamWAV }
var _sample_cache: Dictionary = {}

## 外部采样是否可用的标记
var _samples_available: Dictionary = {}

# ============================================================
# 公共接口
# ============================================================

## 生成单个音符的音效
## note: MusicData.Note 枚举值
## timbre: MusicData.TimbreType 音色系别
## octave: 八度 (4 = 中央C所在八度)
## duration: 音符时长（秒）
## velocity: 力度 (0.0 ~ 1.0)
func generate_note(note: int, timbre: int = MusicData.TimbreType.NONE,
		octave: int = 4, duration: float = DEFAULT_NOTE_DURATION,
		velocity: float = 0.8) -> AudioStreamWAV:

	var cache_key := _make_cache_key(note, timbre, octave, duration)

	# 优先使用缓存
	if _cache.has(cache_key):
		return _cache[cache_key]

	# 尝试加载外部采样
	var sample := _try_load_sample(note, timbre, octave)
	if sample != null:
		_cache[cache_key] = sample
		return sample

	# 程序化合成
	var wav := _synthesize_note(note, timbre, octave, duration, velocity)
	_cache_put(cache_key, wav)
	return wav

## 生成和弦音效（多个音符叠加）
## notes: MusicData.Note 枚举值数组
## timbre: MusicData.TimbreType 音色系别
## octave: 基础八度
## duration: 和弦时长（秒）
## velocity: 力度
func generate_chord(notes: Array, timbre: int = MusicData.TimbreType.NONE,
		octave: int = 4, duration: float = 0.3,
		velocity: float = 0.7) -> AudioStreamWAV:

	if notes.is_empty():
		return _generate_silence(duration)

	var cache_key := "chord_%d_%s_%d_%d" % [timbre, str(notes), octave, int(duration * 1000)]
	if _cache.has(cache_key):
		return _cache[cache_key]

	# 合成每个音符并混合
	var sample_count := int(duration * SAMPLE_RATE)
	var mix_buffer: Array[float] = []
	mix_buffer.resize(sample_count)
	mix_buffer.fill(0.0)

	var note_count := notes.size()
	var per_note_gain := 1.0 / sqrt(float(note_count))  # 等功率混合

	for note in notes:
		var note_freq := _get_frequency(note, octave)
		var adsr := _get_adsr_params(timbre)
		var harmonics: Array = adsr.get("harmonics", [[1.0, 1.0]])
		var wave_shape: String = adsr.get("wave_shape", "sine")

		for i in range(sample_count):
			var t := float(i) / float(SAMPLE_RATE)
			var env := _calculate_envelope(t, duration, adsr)
			var wave := _generate_waveform(t, note_freq, wave_shape, harmonics, timbre)
			mix_buffer[i] += wave * env * velocity * per_note_gain

	# 添加音色特有的后处理
	_apply_timbre_post_processing(mix_buffer, timbre, duration)

	var wav := _buffer_to_wav(mix_buffer)
	_cache_put(cache_key, wav)
	return wav

## 预生成常用音符（可在 _ready 中调用以减少运行时延迟）
func pregenerate_common_notes(timbre: int = MusicData.TimbreType.NONE) -> void:
	for note in MusicData.NOTE_FREQUENCIES.keys():
		generate_note(note, timbre, 4)

## 清除缓存
func clear_cache() -> void:
	_cache.clear()

## 检查外部采样是否可用
func has_external_samples(timbre: int) -> bool:
	var dir_name: String = TIMBRE_DIR_NAMES.get(timbre, "default")
	var dir_path := SAMPLES_BASE_DIR + dir_name
	return DirAccess.dir_exists_absolute(dir_path)

# ============================================================
# 程序化合成核心
# ============================================================

## 合成单个音符
func _synthesize_note(note: int, timbre: int, octave: int,
		duration: float, velocity: float) -> AudioStreamWAV:

	var freq := _get_frequency(note, octave)
	var adsr := _get_adsr_params(timbre)
	var harmonics: Array = adsr.get("harmonics", [[1.0, 1.0]])
	var wave_shape: String = adsr.get("wave_shape", "sine")

	# 计算实际音效时长（包含释放时间）
	var release_time: float = adsr.get("release_time", 0.05)
	var total_duration := duration + release_time
	var sample_count := int(total_duration * SAMPLE_RATE)

	var buffer: Array[float] = []
	buffer.resize(sample_count)

	for i in range(sample_count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := _calculate_envelope(t, duration, adsr)
		var wave := _generate_waveform(t, freq, wave_shape, harmonics, timbre)

		# 应用力度
		buffer[i] = wave * env * velocity

	# 音色特有后处理
	_apply_timbre_post_processing(buffer, timbre, total_duration)

	return _buffer_to_wav(buffer)

## 计算 ADSR 包络
func _calculate_envelope(t: float, note_duration: float, adsr: Dictionary) -> float:
	var attack: float = adsr.get("attack_time", 0.01)
	var decay: float = adsr.get("decay_time", 0.1)
	var sustain: float = adsr.get("sustain_level", 0.6)
	var release: float = adsr.get("release_time", 0.05)

	if t < attack:
		# Attack 阶段：线性上升
		return t / attack if attack > 0.0 else 1.0
	elif t < attack + decay:
		# Decay 阶段：指数衰减到 sustain
		var decay_progress := (t - attack) / decay if decay > 0.0 else 1.0
		return lerp(1.0, sustain, decay_progress * decay_progress)
	elif t < note_duration:
		# Sustain 阶段
		return sustain
	else:
		# Release 阶段：指数衰减到 0
		var release_progress := (t - note_duration) / release if release > 0.0 else 1.0
		release_progress = clampf(release_progress, 0.0, 1.0)
		return sustain * (1.0 - release_progress * release_progress)

## 生成波形（含泛音叠加）
func _generate_waveform(t: float, freq: float, wave_shape: String,
		harmonics: Array, timbre: int) -> float:
	var wave := 0.0

	for h in harmonics:
		var h_freq_mult: float = h[0]
		var h_amplitude: float = h[1]
		var h_freq := freq * h_freq_mult

		match wave_shape:
			"sine":
				wave += sin(t * h_freq * TAU) * h_amplitude
			"triangle":
				wave += _triangle_wave(t * h_freq) * h_amplitude
			"sawtooth":
				wave += _sawtooth_wave(t * h_freq) * h_amplitude
			"square":
				wave += _square_wave(t * h_freq) * h_amplitude

	# 音色特有的波形修饰
	wave = _apply_timbre_character(wave, t, freq, timbre)

	# 软限幅防止削波
	wave = tanh(wave * 0.8)

	return wave

## 三角波
func _triangle_wave(phase: float) -> float:
	var p := fmod(phase, 1.0)
	if p < 0.0:
		p += 1.0
	if p < 0.25:
		return p * 4.0
	elif p < 0.75:
		return 2.0 - p * 4.0
	else:
		return p * 4.0 - 4.0

## 锯齿波
func _sawtooth_wave(phase: float) -> float:
	var p := fmod(phase, 1.0)
	if p < 0.0:
		p += 1.0
	return 2.0 * p - 1.0

## 方波（带带限处理减少混叠）
func _square_wave(phase: float) -> float:
	var p := fmod(phase, 1.0)
	if p < 0.0:
		p += 1.0
	# 使用 tanh 近似带限方波
	return tanh(sin(p * TAU) * 4.0)

# ============================================================
# 音色特征处理
# ============================================================

## 为不同音色系别添加特有的波形修饰
func _apply_timbre_character(wave: float, t: float, freq: float, timbre: int) -> float:
	match timbre:
		MusicData.TimbreType.PLUCKED:
			# 弹拨系：添加瞬态噪声冲击（模拟拨弦瞬间）
			if t < 0.008:
				wave += randf_range(-0.3, 0.3) * (1.0 - t / 0.008)
			# 轻微的弦振动不规则性
			wave *= 1.0 + sin(t * 7.3) * 0.02

		MusicData.TimbreType.BOWED:
			# 拉弦系：添加弓弦摩擦的微颤（vibrato）
			var vibrato_depth := 0.006 * clampf(t * 5.0, 0.0, 1.0)  # 渐入
			var vibrato := sin(t * 5.5 * TAU) * vibrato_depth
			wave *= 1.0 + vibrato
			# 弓压变化产生的音色波动
			wave += sin(t * freq * TAU * 3.01) * 0.03 * clampf(t, 0.0, 1.0)

		MusicData.TimbreType.WIND:
			# 吹奏系：添加气息噪声
			var breath_noise := randf_range(-0.08, 0.08)
			var breath_envelope := clampf(t * 10.0, 0.0, 1.0) * 0.5 + 0.5
			wave += breath_noise * breath_envelope * 0.3
			# 管乐特有的轻微颤音
			wave *= 1.0 + sin(t * 4.8 * TAU) * 0.004

		MusicData.TimbreType.PERCUSSIVE:
			# 打击系：添加锤击瞬态
			if t < 0.003:
				var hammer_noise := randf_range(-0.5, 0.5) * (1.0 - t / 0.003)
				wave += hammer_noise
			# 钢琴式的共振衰减
			wave *= 1.0 + sin(t * freq * 2.003 * TAU) * 0.02 * exp(-t * 3.0)

	return wave

## 音色后处理（应用于整个音效缓冲区）
func _apply_timbre_post_processing(buffer: Array[float], timbre: int,
		_duration: float) -> void:
	var size := buffer.size()
	if size == 0:
		return

	match timbre:
		MusicData.TimbreType.PLUCKED:
			# 弹拨系：应用简单的低通滤波模拟弦的高频衰减
			_apply_simple_lowpass(buffer, 0.15)

		MusicData.TimbreType.BOWED:
			# 拉弦系：轻微的温暖化处理
			_apply_simple_lowpass(buffer, 0.08)

		MusicData.TimbreType.WIND:
			# 吹奏系：不额外滤波，保留气息感的高频
			pass

		MusicData.TimbreType.PERCUSSIVE:
			# 打击系：轻微压缩，增加冲击感
			_apply_soft_compression(buffer, 0.7)

## 简单一阶低通滤波器
func _apply_simple_lowpass(buffer: Array[float], cutoff_factor: float) -> void:
	var prev := buffer[0]
	for i in range(1, buffer.size()):
		buffer[i] = prev + cutoff_factor * (buffer[i] - prev)
		prev = buffer[i]

## 软压缩
func _apply_soft_compression(buffer: Array[float], threshold: float) -> void:
	for i in range(buffer.size()):
		var sample := buffer[i]
		var abs_sample := absf(sample)
		if abs_sample > threshold:
			var excess := abs_sample - threshold
			var compressed := threshold + excess * 0.3
			buffer[i] = compressed * signf(sample)

# ============================================================
# 外部采样加载
# ============================================================

## 尝试加载外部采样文件
func _try_load_sample(note: int, timbre: int, octave: int) -> AudioStreamWAV:
	var dir_name: String = TIMBRE_DIR_NAMES.get(timbre, "default")
	var note_name: String = NOTE_NAMES.get(note, "C")
	var file_name := "%s%d" % [note_name, octave]

	# 检查缓存
	var sample_key := "%s/%s" % [dir_name, file_name]
	if _sample_cache.has(sample_key):
		return _sample_cache[sample_key]

	# 检查是否已知不可用
	if _samples_available.has(sample_key) and not _samples_available[sample_key]:
		return null

	# 尝试加载 .wav 文件
	var wav_path := SAMPLES_BASE_DIR + dir_name + "/" + file_name + ".wav"
	if ResourceLoader.exists(wav_path):
		var loaded = ResourceLoader.load(wav_path)
		if loaded is AudioStreamWAV:
			_sample_cache[sample_key] = loaded
			_samples_available[sample_key] = true
			return loaded

	# 尝试加载 .ogg 文件 (Godot 4 使用 AudioStreamOggVorbis)
	var ogg_path := SAMPLES_BASE_DIR + dir_name + "/" + file_name + ".ogg"
	if ResourceLoader.exists(ogg_path):
		# OGG 文件不是 AudioStreamWAV，需要特殊处理
		# 这里标记为可用但返回 null，让调用者使用 AudioStreamPlayer 直接播放
		_samples_available[sample_key] = true
		# 注意：OGG 采样需要通过 AudioStreamPlayer 播放，不能直接混合
		# 此处返回 null 以回退到程序化合成
		pass

	_samples_available[sample_key] = false
	return null

# ============================================================
# 工具函数
# ============================================================

## 获取音符频率
func _get_frequency(note: int, octave: int) -> float:
	var base_freq: float = MusicData.NOTE_FREQUENCIES.get(note, 261.63)
	# 基准频率是 C4 (octave=4)，按八度调整
	var octave_diff := octave - 4
	return base_freq * pow(2.0, float(octave_diff))

## 获取 ADSR 参数
func _get_adsr_params(timbre: int) -> Dictionary:
	return MusicData.TIMBRE_ADSR.get(timbre, MusicData.TIMBRE_ADSR[MusicData.TimbreType.NONE])

## 生成缓存键
func _make_cache_key(note: int, timbre: int, octave: int, duration: float) -> String:
	return "%d_%d_%d_%d" % [timbre, note, octave, int(duration * 1000)]

## 将浮点缓冲区转换为 AudioStreamWAV
func _buffer_to_wav(buffer: Array[float]) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buffer.size() * 2)
	for i in range(buffer.size()):
		var sample := int(clampf(buffer[i] * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

## 生成静音
func _generate_silence(duration: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	data.fill(0)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

## 缓存管理：LRU 式插入
func _cache_put(key: String, wav: AudioStreamWAV) -> void:
	if _cache.size() >= MAX_CACHE_SIZE:
		# 简单策略：移除最早的条目
		var first_key = _cache.keys()[0]
		_cache.erase(first_key)
	_cache[key] = wav
