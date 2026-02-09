## audio_effect_processor.gd
## 音频效果处理器
## 为不同的法术修饰符和和弦形态提供专属的音频DSP效果
##
## 设计理念：
##   通过程序化DSP算法在音符合成阶段直接应用效果器，
##   让音效与视觉效果和游戏机制保持一致。
##
## 支持的效果：
##   - 高通/低通滤波器
##   - 延迟/回声
##   - 混响
##   - 合唱
##   - 音高调制
##   - 失真
##   - 噪声层
##
class_name AudioEffectProcessor
extends RefCounted

# ============================================================
# 常量
# ============================================================

const SAMPLE_RATE: int = 44100

# ============================================================
# 公共接口：修饰符效果
# ============================================================

## 应用修饰符效果到音频缓冲区
static func apply_modifier_effect(
	buffer: Array[float],
	modifier: MusicData.ModifierEffect,
	sample_rate: int = SAMPLE_RATE
) -> void:
	match modifier:
		MusicData.ModifierEffect.PIERCE:
			_apply_pierce_effect(buffer, sample_rate)
		MusicData.ModifierEffect.HOMING:
			_apply_homing_effect(buffer, sample_rate)
		MusicData.ModifierEffect.SPLIT:
			_apply_split_effect(buffer, sample_rate)
		MusicData.ModifierEffect.ECHO:
			_apply_echo_effect(buffer, sample_rate)
		MusicData.ModifierEffect.SCATTER:
			_apply_scatter_effect(buffer, sample_rate)

## 应用和弦形态效果到音频缓冲区
static func apply_chord_form_effect(
	buffer: Array[float],
	chord_type: MusicData.ChordType,
	sample_rate: int = SAMPLE_RATE
) -> void:
	match chord_type:
		MusicData.ChordType.AUGMENTED:
			# 爆炸弹体：失真 + 低音增强
			_apply_distortion(buffer, 0.3, 0.4)
			_apply_sub_bass_boost(buffer, 0.3)
		MusicData.ChordType.DIMINISHED, MusicData.ChordType.DIMINISHED_7:
			# 冲击波：环形调制 + 混响
			_apply_ring_modulation(buffer, 220.0, 0.25, sample_rate)
			_apply_simple_reverb(buffer, 0.8, 0.6, sample_rate)
		MusicData.ChordType.DOMINANT_7:
			# 法阵：柔和音色 + 长混响
			_apply_low_pass_filter(buffer, 2000.0, sample_rate)
			_apply_simple_reverb(buffer, 0.9, 0.7, sample_rate)
		MusicData.ChordType.MAJOR:
			# 强化弹体：压缩 + 泛音增强
			_apply_soft_compression(buffer, 0.6, 3.0)

# ============================================================
# 修饰符效果实现
# ============================================================

## 穿透效果：高通滤波 + 增强Attack
static func _apply_pierce_effect(buffer: Array[float], sample_rate: int) -> void:
	# 高通滤波器，保留高频
	_apply_high_pass_filter(buffer, 2000.0, sample_rate)
	# 增强瞬态冲击
	_apply_transient_boost(buffer, 1.5)
	# 轻微混响，增加穿透感
	_apply_simple_reverb(buffer, 0.2, 0.15, sample_rate)

## 追踪效果：音高调制（LFO）
static func _apply_homing_effect(buffer: Array[float], sample_rate: int) -> void:
	# LFO音高调制，模拟弹体转向时的多普勒效应
	_apply_pitch_lfo(buffer, 4.0, 0.15, sample_rate)
	# 添加轻微颤音
	_apply_vibrato(buffer, 5.5, 0.008, sample_rate)

## 分裂效果：合唱 + 立体声展宽
static func _apply_split_effect(buffer: Array[float], _sample_rate: int) -> void:
	# 合唱效果，模拟多个声部
	_apply_simple_chorus(buffer, 3, 0.02)
	# 注意：立体声展宽需要双声道，这里简化为单声道合唱

## 回响效果：延迟
static func _apply_echo_effect(buffer: Array[float], sample_rate: int) -> void:
	# 延迟效果，模拟回声
	_apply_delay(buffer, 0.3, 0.4, sample_rate)
	# 对延迟部分应用低通滤波，模拟声音在空间中的传播
	_apply_low_pass_filter(buffer, 3000.0, sample_rate)

## 散射效果：混响 + 噪声层
static func _apply_scatter_effect(buffer: Array[float], sample_rate: int) -> void:
	# 混响效果，增强空间感
	_apply_simple_reverb(buffer, 0.6, 0.5, sample_rate)
	# 添加噪声层，模拟散射的混乱感
	_apply_noise_layer(buffer, 0.08)
	# 轻微随机化音量
	_apply_volume_randomization(buffer, 0.15)

# ============================================================
# DSP 算法实现
# ============================================================

## 高通滤波器（一阶RC高通）
static func _apply_high_pass_filter(
	buffer: Array[float],
	cutoff_freq: float,
	sample_rate: int
) -> void:
	if buffer.is_empty():
		return
	
	var rc := 1.0 / (cutoff_freq * TAU)
	var dt := 1.0 / float(sample_rate)
	var alpha := rc / (rc + dt)
	
	var prev_input := buffer[0]
	var prev_output := buffer[0]
	
	for i in range(1, buffer.size()):
		var current_input := buffer[i]
		var output := alpha * (prev_output + current_input - prev_input)
		buffer[i] = output
		prev_input = current_input
		prev_output = output

## 低通滤波器（一阶RC低通）
static func _apply_low_pass_filter(
	buffer: Array[float],
	cutoff_freq: float,
	sample_rate: int
) -> void:
	if buffer.is_empty():
		return
	
	var rc := 1.0 / (cutoff_freq * TAU)
	var dt := 1.0 / float(sample_rate)
	var alpha := dt / (rc + dt)
	
	var prev_output := buffer[0]
	
	for i in range(1, buffer.size()):
		var output := prev_output + alpha * (buffer[i] - prev_output)
		buffer[i] = output
		prev_output = output

## 延迟效果
static func _apply_delay(
	buffer: Array[float],
	delay_time: float,
	feedback: float,
	sample_rate: int
) -> void:
	var delay_samples := int(delay_time * sample_rate)
	if delay_samples >= buffer.size() or delay_samples <= 0:
		return
	
	# 从后向前处理，避免覆盖原始数据
	for i in range(buffer.size() - 1, delay_samples - 1, -1):
		buffer[i] += buffer[i - delay_samples] * feedback

## 简单混响（使用多个延迟线模拟）
static func _apply_simple_reverb(
	buffer: Array[float],
	room_size: float,
	wet: float,
	sample_rate: int
) -> void:
	if buffer.is_empty():
		return
	
	# 使用多个延迟线模拟早期反射
	var delays := [0.029, 0.037, 0.041, 0.043]  # 秒
	var decay := 0.5 * room_size
	
	var reverb_buffer := buffer.duplicate()
	
	for delay_time in delays:
		var delay_samples := int(delay_time * sample_rate)
		if delay_samples >= buffer.size():
			continue
		
		for i in range(delay_samples, buffer.size()):
			reverb_buffer[i] += buffer[i - delay_samples] * decay
	
	# 混合原始信号和混响信号
	for i in range(buffer.size()):
		buffer[i] = buffer[i] * (1.0 - wet) + reverb_buffer[i] * wet

## 合唱效果（简化版）
static func _apply_simple_chorus(
	buffer: Array[float],
	voices: int,
	detune_amount: float
) -> void:
	if buffer.is_empty() or voices <= 1:
		return
	
	var original := buffer.duplicate()
	var inv_voices := 1.0 / float(voices)
	
	# 重置buffer
	for i in range(buffer.size()):
		buffer[i] *= inv_voices
	
	# 添加失谐的声部
	for v in range(1, voices):
		var detune := detune_amount * (v - voices / 2.0)
		for i in range(buffer.size()):
			# 简化版：通过时间偏移模拟音高变化
			var offset := int(i * detune)
			var idx := clampi(i + offset, 0, buffer.size() - 1)
			buffer[i] += original[idx] * inv_voices

## LFO音高调制
static func _apply_pitch_lfo(
	buffer: Array[float],
	lfo_rate: float,
	lfo_depth: float,
	sample_rate: int
) -> void:
	if buffer.is_empty():
		return
	
	var original := buffer.duplicate()
	
	for i in range(buffer.size()):
		var t := float(i) / float(sample_rate)
		# LFO信号（正弦波）
		var lfo := sin(t * lfo_rate * TAU) * lfo_depth
		# 计算采样偏移
		var offset := int(lfo * sample_rate * 0.01)  # 转换为样本偏移
		var idx := clampi(i + offset, 0, buffer.size() - 1)
		buffer[i] = original[idx]

## 颤音效果
static func _apply_vibrato(
	buffer: Array[float],
	rate: float,
	depth: float,
	sample_rate: int
) -> void:
	if buffer.is_empty():
		return
	
	var original := buffer.duplicate()
	
	for i in range(buffer.size()):
		var t := float(i) / float(sample_rate)
		var vibrato := sin(t * rate * TAU) * depth
		var offset := int(vibrato * sample_rate * 0.01)
		var idx := clampi(i + offset, 0, buffer.size() - 1)
		buffer[i] = original[idx]

## 瞬态增强
static func _apply_transient_boost(buffer: Array[float], multiplier: float) -> void:
	if buffer.is_empty():
		return
	
	# 增强前5%的样本（Attack阶段）
	var boost_samples := int(buffer.size() * 0.05)
	for i in range(min(boost_samples, buffer.size())):
		buffer[i] *= multiplier

## 失真效果
static func _apply_distortion(buffer: Array[float], drive: float, mix: float) -> void:
	if buffer.is_empty():
		return
	
	for i in range(buffer.size()):
		var original := buffer[i]
		# 软削波失真
		var distorted := tanh(original * (1.0 + drive * 5.0))
		buffer[i] = lerp(original, distorted, mix)

## 环形调制
static func _apply_ring_modulation(
	buffer: Array[float],
	mod_freq: float,
	mix: float,
	sample_rate: int
) -> void:
	if buffer.is_empty():
		return
	
	for i in range(buffer.size()):
		var t := float(i) / float(sample_rate)
		var modulator := sin(t * mod_freq * TAU)
		var modulated := buffer[i] * modulator
		buffer[i] = lerp(buffer[i], modulated, mix)

## 软压缩
static func _apply_soft_compression(
	buffer: Array[float],
	threshold: float,
	ratio: float
) -> void:
	if buffer.is_empty():
		return
	
	for i in range(buffer.size()):
		var sample := buffer[i]
		var abs_sample := absf(sample)
		
		if abs_sample > threshold:
			var excess := abs_sample - threshold
			var compressed := threshold + excess / ratio
			buffer[i] = compressed * signf(sample)

## 低音增强（添加低八度）
static func _apply_sub_bass_boost(buffer: Array[float], mix: float) -> void:
	if buffer.is_empty():
		return
	
	# 简化版：通过降采样模拟低八度
	for i in range(0, buffer.size(), 2):
		if i + 1 < buffer.size():
			var sub := (buffer[i] + buffer[i + 1]) * 0.5
			buffer[i] = lerp(buffer[i], sub, mix)
			if i + 1 < buffer.size():
				buffer[i + 1] = lerp(buffer[i + 1], sub, mix)

## 噪声层
static func _apply_noise_layer(buffer: Array[float], mix: float) -> void:
	if buffer.is_empty():
		return
	
	for i in range(buffer.size()):
		var noise := randf_range(-1.0, 1.0)
		buffer[i] = lerp(buffer[i], buffer[i] + noise, mix)

## 音量随机化
static func _apply_volume_randomization(buffer: Array[float], variance: float) -> void:
	if buffer.is_empty():
		return
	
	for i in range(buffer.size()):
		var random_gain := 1.0 + randf_range(-variance, variance)
		buffer[i] *= random_gain

# ============================================================
# 工具函数
# ============================================================

## 将PackedByteArray转换为float数组
static func byte_array_to_float_buffer(data: PackedByteArray) -> Array[float]:
	var buffer: Array[float] = []
	buffer.resize(data.size() / 2)
	
	for i in range(buffer.size()):
		var sample_int := int(data[i * 2]) | (int(data[i * 2 + 1]) << 8)
		# 转换为有符号16位整数
		if sample_int >= 32768:
			sample_int -= 65536
		# 归一化到 -1.0 ~ 1.0
		buffer[i] = float(sample_int) / 32768.0
	
	return buffer

## 将float数组转换为PackedByteArray
static func float_buffer_to_byte_array(buffer: Array[float]) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(buffer.size() * 2)
	
	for i in range(buffer.size()):
		var sample := int(clampf(buffer[i] * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	
	return data
