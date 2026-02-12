## synth_voice.gd
## 单个合成器声部 (Synth Voice)
##
## OPT08 — 程序化音色合成
## 轻量级减法合成器声部，实时生成波形采样并输出到音频流。
## 使用 AudioStreamGenerator 实现零延迟的实时音频合成。
##
## 信号链路：
##   振荡器 (Oscillator) → 滤波器 (Filter) → 放大器 (Amplifier) → 输出
##        ↑                      ↑                    ↑
##     波形选择              LPF/HPF 包络          ADSR 包络
##
## 性能考量：
##   - 波形生成使用简单数学运算（无 FFT）
##   - 缓冲区大小 50ms，在可接受延迟范围内
##   - 每帧只填充可用帧数，避免过度计算
##
class_name SynthVoice
extends Node

# ============================================================
# 信号
# ============================================================

## 声部播放完成（Release 阶段结束）
signal voice_finished()

# ============================================================
# 常量
# ============================================================

## 合成器采样率
const SAMPLE_RATE: float = 44100.0

## 音频缓冲区长度（秒）
const BUFFER_LENGTH: float = 0.05

## 主音量缩放因子（防止削波）
const MASTER_GAIN: float = 0.3

## 最大泛音数量（性能限制）
const MAX_HARMONICS: int = 8

# ============================================================
# 音频节点
# ============================================================

var _generator: AudioStreamGenerator = null
var _playback: AudioStreamGeneratorPlayback = null
var _player: AudioStreamPlayer2D = null

# ============================================================
# 包络
# ============================================================

var _amp_envelope: ADSREnvelope = null
var _filter_envelope: ADSREnvelope = null

# ============================================================
# 振荡器状态
# ============================================================

## 当前频率 (Hz)
var _frequency: float = 440.0

## 主振荡器相位 (0.0 ~ 1.0)
var _phase: float = 0.0

## 副振荡器相位
var _sub_phase: float = 0.0

## 超级锯齿波各振荡器相位
var _supersaw_phases: Array[float] = []

## 超级锯齿波各振荡器失谐量
var _supersaw_detunes: Array[float] = []

## FM 合成调制器相位
var _fm_mod_phase: float = 0.0

# ============================================================
# 合成器参数（由 play_note 设置）
# ============================================================

var _waveform: int = TimbreSynthPresets.Waveform.SINE
var _sub_waveform: int = TimbreSynthPresets.Waveform.SINE
var _sub_mix: float = 0.0
var _filter_type: int = TimbreSynthPresets.FilterType.NONE
var _filter_cutoff_base: float = 5000.0
var _filter_cutoff_env_amount: float = 3000.0
var _filter_resonance: float = 0.5
var _detune_cents: float = 0.0
var _num_oscillators: int = 1
var _brightness: float = 0.5
var _custom_harmonics: Array = []
var _special_processing: String = "none"

## FM 合成参数
var _fm_ratio: float = 2.0
var _fm_depth: float = 3.0
var _fm_env_amount: float = 2.0

## Bitcrush 参数
var _bitcrush_bits: int = 16
var _bitcrush_rate: int = 44100
var _bitcrush_counter: float = 0.0
var _bitcrush_held_sample: float = 0.0

# ============================================================
# 滤波器状态（一阶 IIR）
# ============================================================

var _filter_prev_sample: float = 0.0
var _filter_band_prev: float = 0.0

# ============================================================
# 声部状态
# ============================================================

## 声部是否正在使用
var _is_playing: bool = false

## 当前音色武器类型（用于特殊处理判断）
var _current_timbre: int = MusicData.ChapterTimbre.NONE

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = SAMPLE_RATE
	_generator.buffer_length = BUFFER_LENGTH

	_player = AudioStreamPlayer2D.new()
	_player.stream = _generator
	_player.bus = "PlayerSFX"
	_player.max_distance = 2000.0
	add_child(_player)

	_amp_envelope = ADSREnvelope.new()
	_filter_envelope = ADSREnvelope.new()

func _process(delta: float) -> void:
	if not _is_playing:
		return

	if _playback == null:
		return

	# 更新包络
	var amp := _amp_envelope.process(delta)
	var filter_mod := _filter_envelope.process(delta)

	# 检查是否播放完成
	if not _amp_envelope.is_active():
		_is_playing = false
		_player.stop()
		voice_finished.emit()
		return

	# 填充音频缓冲区
	var frames_available := _playback.get_frames_available()
	if frames_available <= 0:
		return

	for i in range(frames_available):
		var sample := _generate_sample(filter_mod)
		sample *= amp * MASTER_GAIN

		# 软限幅防止削波
		sample = _soft_clip(sample)

		_playback.push_frame(Vector2(sample, sample))

# ============================================================
# 公共接口
# ============================================================

## 触发一个音符
## frequency: 音符频率 (Hz)
## timbre_params: 完整的合成器参数（来自 TimbreSynthPresets.get_full_params）
func play_note(frequency: float, timbre_params: Dictionary) -> void:
	_frequency = frequency
	_is_playing = true

	# 设置振荡器参数
	_waveform = timbre_params.get("waveform", TimbreSynthPresets.Waveform.SINE)
	_sub_waveform = timbre_params.get("sub_waveform", TimbreSynthPresets.Waveform.SINE)
	_sub_mix = timbre_params.get("sub_mix", 0.0)
	_filter_type = timbre_params.get("filter_type", TimbreSynthPresets.FilterType.NONE)
	_filter_cutoff_base = timbre_params.get("filter_cutoff_base", 5000.0)
	_filter_cutoff_env_amount = timbre_params.get("filter_cutoff_env_amount", 3000.0)
	_filter_resonance = timbre_params.get("filter_resonance", 0.5)
	_detune_cents = timbre_params.get("detune_cents", 0.0)
	_num_oscillators = timbre_params.get("num_oscillators", 1)
	_brightness = timbre_params.get("brightness", 0.5)
	_custom_harmonics = timbre_params.get("custom_harmonics", [[1.0, 1.0]])
	_special_processing = timbre_params.get("special_processing", "none")
	_current_timbre = timbre_params.get("chapter_timbre", MusicData.ChapterTimbre.NONE)

	# FM 合成参数
	_fm_ratio = timbre_params.get("fm_ratio", 2.0)
	_fm_depth = timbre_params.get("fm_depth", 3.0)
	_fm_env_amount = timbre_params.get("fm_env_amount", 2.0)

	# Bitcrush 参数
	_bitcrush_bits = timbre_params.get("bitcrush_bits", 16)
	_bitcrush_rate = timbre_params.get("bitcrush_rate", 44100)
	_bitcrush_counter = 0.0
	_bitcrush_held_sample = 0.0

	# 设置振幅 ADSR 包络
	_amp_envelope.attack_time = timbre_params.get("attack", 0.01)
	_amp_envelope.decay_time = timbre_params.get("decay", 0.1)
	_amp_envelope.sustain_level = timbre_params.get("sustain", 0.7)
	_amp_envelope.release_time = timbre_params.get("release", 0.3)

	# 设置滤波器 ADSR 包络（更快的起音，用于音色塑造）
	_filter_envelope.attack_time = timbre_params.get("attack", 0.01) * 0.5
	_filter_envelope.decay_time = timbre_params.get("decay", 0.1) * 1.5
	_filter_envelope.sustain_level = _brightness
	_filter_envelope.release_time = timbre_params.get("release", 0.3)

	# 触发包络
	_amp_envelope.trigger()
	_filter_envelope.trigger()

	# 重置振荡器相位
	_phase = 0.0
	_sub_phase = 0.0
	_fm_mod_phase = 0.0
	_filter_prev_sample = 0.0
	_filter_band_prev = 0.0

	# 初始化超级锯齿波振荡器
	if _waveform == TimbreSynthPresets.Waveform.SUPERSAW and _num_oscillators > 1:
		_init_supersaw_oscillators()

	# 开始播放
	_player.play()
	_playback = _player.get_stream_playback()

## 停止音符（触发 Release 阶段）
func stop_note() -> void:
	if not _is_playing:
		return
	_amp_envelope.release()
	_filter_envelope.release()

## 强制停止（立即静音）
func force_stop() -> void:
	_is_playing = false
	_amp_envelope.force_stop()
	_filter_envelope.force_stop()
	if _player.playing:
		_player.stop()

## 声部是否正在播放
func is_playing() -> bool:
	return _is_playing

## 设置声部的空间位置（用于 2D 空间音频）
func set_voice_position(pos: Vector2) -> void:
	if _player:
		_player.global_position = pos

# ============================================================
# 波形生成
# ============================================================

## 生成单个采样（含所有合成处理）
func _generate_sample(filter_mod: float) -> float:
	var sample: float = 0.0

	# 根据特殊处理选择不同的合成路径
	match _special_processing:
		"fm_synthesis":
			sample = _generate_fm_sample()
		"spectral_random":
			sample = _generate_spectral_sample()
		_:
			sample = _generate_standard_sample()

	# 应用滤波器
	sample = _apply_filter(sample, filter_mod)

	# 应用 Bitcrush（如果启用）
	if _special_processing == "bitcrush_glitch":
		sample = _apply_bitcrush(sample)

	return sample

## 标准合成路径（振荡器 + 泛音 + 副振荡器）
func _generate_standard_sample() -> float:
	var sample: float = 0.0
	var increment := _frequency / SAMPLE_RATE

	# 超级锯齿波模式
	if _waveform == TimbreSynthPresets.Waveform.SUPERSAW and _num_oscillators > 1:
		sample = _generate_supersaw_sample()
	else:
		# 主振荡器 + 泛音叠加
		var harmonic_count := mini(_custom_harmonics.size(), MAX_HARMONICS)
		for h_idx in range(harmonic_count):
			var h: Array = _custom_harmonics[h_idx]
			var h_freq_mult: float = h[0]
			var h_amplitude: float = h[1]
			sample += _oscillator(_phase * h_freq_mult, _waveform) * h_amplitude

		# 更新主振荡器相位
		_phase += increment
		if _phase >= 1.0:
			_phase -= floorf(_phase)

	# 副振荡器混合
	if _sub_mix > 0.0:
		var sub_increment := _frequency / SAMPLE_RATE
		if _detune_cents != 0.0:
			sub_increment *= pow(2.0, _detune_cents / 1200.0)
		var sub_sample := _oscillator(_sub_phase, _sub_waveform)
		sample = sample * (1.0 - _sub_mix) + sub_sample * _sub_mix

		_sub_phase += sub_increment
		if _sub_phase >= 1.0:
			_sub_phase -= floorf(_sub_phase)

	return sample

## FM 合成路径
func _generate_fm_sample() -> float:
	var carrier_increment := _frequency / SAMPLE_RATE
	var mod_increment := (_frequency * _fm_ratio) / SAMPLE_RATE

	# 调制器输出
	var mod_signal := sin(_fm_mod_phase * TAU)

	# 调制深度受包络影响
	var current_depth := _fm_depth + _fm_env_amount * _filter_envelope.get_value()

	# 载波频率 = 基频 + 调制器输出 × 调制深度 × 基频
	var modulated_phase := _phase + mod_signal * current_depth * carrier_increment
	var sample := sin(modulated_phase * TAU)

	# 更新相位
	_phase += carrier_increment
	if _phase >= 1.0:
		_phase -= floorf(_phase)
	_fm_mod_phase += mod_increment
	if _fm_mod_phase >= 1.0:
		_fm_mod_phase -= floorf(_fm_mod_phase)

	return sample

## 频谱合成路径（随机泛音）
func _generate_spectral_sample() -> float:
	var sample: float = 0.0
	var increment := _frequency / SAMPLE_RATE

	# 使用自定义泛音 + 随机微调
	var harmonic_count := mini(_custom_harmonics.size(), MAX_HARMONICS)
	for h_idx in range(harmonic_count):
		var h: Array = _custom_harmonics[h_idx]
		var h_freq_mult: float = h[0]
		var h_amplitude: float = h[1]
		# 方波泛音用于数字质感
		sample += _oscillator(_phase * h_freq_mult, TimbreSynthPresets.Waveform.SQUARE) * h_amplitude

	# 叠加噪音成分
	sample = sample * 0.6 + _oscillator(0.0, TimbreSynthPresets.Waveform.NOISE) * 0.4

	_phase += increment
	if _phase >= 1.0:
		_phase -= floorf(_phase)

	return sample

## 超级锯齿波生成（多个失谐振荡器叠加）
func _generate_supersaw_sample() -> float:
	var sample: float = 0.0
	var base_increment := _frequency / SAMPLE_RATE
	var gain := 1.0 / sqrt(float(_num_oscillators))

	for i in range(_supersaw_phases.size()):
		var detune_factor: float = _supersaw_detunes[i]
		var increment := base_increment * detune_factor
		sample += _sawtooth_wave(_supersaw_phases[i]) * gain

		_supersaw_phases[i] += increment
		if _supersaw_phases[i] >= 1.0:
			_supersaw_phases[i] -= floorf(_supersaw_phases[i])

	return sample

## 初始化超级锯齿波振荡器组
func _init_supersaw_oscillators() -> void:
	_supersaw_phases.clear()
	_supersaw_detunes.clear()

	var half := _num_oscillators / 2
	for i in range(_num_oscillators):
		_supersaw_phases.append(randf())  # 随机初始相位
		# 均匀分布失谐量
		var detune_offset := float(i - half) / float(maxi(half, 1))
		var detune_factor := pow(2.0, (_detune_cents * detune_offset) / 1200.0)
		_supersaw_detunes.append(detune_factor)

# ============================================================
# 基础波形生成器
# ============================================================

## 通用振荡器（根据波形类型生成采样）
func _oscillator(phase: float, waveform: int) -> float:
	match waveform:
		TimbreSynthPresets.Waveform.SINE:
			return sin(phase * TAU)
		TimbreSynthPresets.Waveform.SQUARE:
			return _square_wave(phase)
		TimbreSynthPresets.Waveform.SAWTOOTH:
			return _sawtooth_wave(phase)
		TimbreSynthPresets.Waveform.TRIANGLE:
			return _triangle_wave(phase)
		TimbreSynthPresets.Waveform.NOISE:
			return randf_range(-1.0, 1.0)
		TimbreSynthPresets.Waveform.PULSE:
			return 1.0 if fmod(phase, 1.0) < 0.3 else -1.0
		_:
			return sin(phase * TAU)

## 方波（带限近似，减少混叠）
func _square_wave(phase: float) -> float:
	var p := fmod(phase, 1.0)
	if p < 0.0:
		p += 1.0
	return tanh(sin(p * TAU) * 4.0)

## 锯齿波
func _sawtooth_wave(phase: float) -> float:
	var p := fmod(phase, 1.0)
	if p < 0.0:
		p += 1.0
	return 2.0 * p - 1.0

## 三角波
func _triangle_wave(phase: float) -> float:
	var p := fmod(phase, 1.0)
	if p < 0.0:
		p += 1.0
	return 4.0 * absf(p - 0.5) - 1.0

# ============================================================
# 滤波器
# ============================================================

## 应用滤波器处理
func _apply_filter(sample: float, filter_mod: float) -> float:
	if _filter_type == TimbreSynthPresets.FilterType.NONE:
		return sample

	# 计算当前截止频率（基础 + 包络调制）
	var cutoff := _filter_cutoff_base + _filter_cutoff_env_amount * filter_mod
	cutoff = clampf(cutoff, 20.0, 20000.0)

	# 计算滤波器系数
	var rc := 1.0 / (cutoff * TAU)
	var dt := 1.0 / SAMPLE_RATE
	var alpha := dt / (rc + dt)

	match _filter_type:
		TimbreSynthPresets.FilterType.LOW_PASS:
			# 一阶低通滤波器
			_filter_prev_sample += alpha * (sample - _filter_prev_sample)
			# 共振反馈
			if _filter_resonance > 0.0:
				_filter_prev_sample += _filter_resonance * (_filter_prev_sample - _filter_band_prev)
				_filter_band_prev = _filter_prev_sample
			return _filter_prev_sample

		TimbreSynthPresets.FilterType.HIGH_PASS:
			# 一阶高通滤波器
			var hp := sample - _filter_prev_sample
			_filter_prev_sample += alpha * (sample - _filter_prev_sample)
			return hp

		TimbreSynthPresets.FilterType.BAND_PASS:
			# 简单带通（低通 + 高通组合）
			_filter_prev_sample += alpha * (sample - _filter_prev_sample)
			var bp := sample - _filter_prev_sample
			# 共振增强中心频率
			bp += _filter_resonance * _filter_prev_sample
			_filter_band_prev = bp
			return bp * 2.0  # 增益补偿

		TimbreSynthPresets.FilterType.MULTI_PEAK:
			# 多峰共振滤波器（用于频谱合成器）
			var output := sample * 0.3  # 干信号
			# 模拟多个共振峰
			_filter_prev_sample += alpha * (sample - _filter_prev_sample)
			output += _filter_prev_sample * _filter_resonance * 2.0
			# 第二个共振峰（频率偏移）
			var alpha2 := dt / ((1.0 / (cutoff * 1.5 * TAU)) + dt)
			_filter_band_prev += alpha2 * (sample - _filter_band_prev)
			output += _filter_band_prev * _filter_resonance * 1.5
			return output

	return sample

# ============================================================
# 特殊效果处理
# ============================================================

## Bitcrush 效果（降低位深度和采样率）
func _apply_bitcrush(sample: float) -> float:
	# 降采样
	_bitcrush_counter += float(_bitcrush_rate) / SAMPLE_RATE
	if _bitcrush_counter >= 1.0:
		_bitcrush_counter -= 1.0
		# 降低位深度
		var max_val := pow(2.0, _bitcrush_bits - 1)
		_bitcrush_held_sample = roundf(sample * max_val) / max_val
	return _bitcrush_held_sample

## 软限幅（tanh 近似）
func _soft_clip(sample: float) -> float:
	return tanh(sample)
