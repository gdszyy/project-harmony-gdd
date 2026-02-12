## timbre_synth_presets.gd
## 章节音色武器的程序化合成器预设
##
## OPT08 — 程序化音色合成
## 定义每种章节音色武器在合成器引擎中的参数预设，
## 包括振荡器波形、滤波器类型、特殊处理和电子乐变体参数。
##
## 设计原则：
##   - 每种音色武器的合成器预设与其 ADSR 参数（定义在 MusicData 中）配合使用
##   - 振荡器波形选择反映乐器的声学特征
##   - 滤波器参数塑造音色的频率特征
##   - 特殊处理为每种音色增加独特的听觉辨识度
##
class_name TimbreSynthPresets
extends RefCounted

# ============================================================
# 振荡器波形枚举
# ============================================================

enum Waveform {
	SINE,       ## 正弦波 — 纯净、基础
	SQUARE,     ## 方波 — 空洞、电子感
	SAWTOOTH,   ## 锯齿波 — 丰富泛音、明亮
	TRIANGLE,   ## 三角波 — 柔和、介于正弦和方波之间
	NOISE,      ## 噪音 — 无音高、打击感
	SUPERSAW,   ## 超级锯齿波 — 多振荡器叠加、厚重
	PULSE,      ## 脉冲波 — 可变占空比的方波
}

# ============================================================
# 滤波器类型枚举
# ============================================================

enum FilterType {
	NONE,           ## 无滤波
	LOW_PASS,       ## 低通滤波器 — 削减高频
	HIGH_PASS,      ## 高通滤波器 — 削减低频
	BAND_PASS,      ## 带通滤波器 — 只保留特定频段
	MULTI_PEAK,     ## 多峰共振滤波器 — 多个共振峰
}

# ============================================================
# 章节音色武器合成器预设
# ============================================================

## 合成器预设数据
## 每个预设包含：
##   waveform: 主振荡器波形
##   sub_waveform: 副振荡器波形（可选）
##   sub_mix: 副振荡器混合比例 (0.0-1.0)
##   filter_type: 滤波器类型
##   filter_cutoff_base: 滤波器基础截止频率 (Hz)
##   filter_cutoff_env_amount: 包络调制量 (Hz)
##   filter_resonance: 滤波器共振 (0.0-1.0)
##   detune_cents: 振荡器失谐量 (音分)
##   num_oscillators: 振荡器数量（用于 SUPERSAW 等）
##   special_processing: 特殊处理标识
##   brightness: 默认明亮度 (0.0-1.0)
##   harmonics_mode: 泛音模式
const SYNTH_PRESETS: Dictionary = {
	# --------------------------------------------------------
	# Ch1 — 里拉琴 (Lyre): 正弦波 + 泛音叠加
	# 模拟古希腊里拉琴的纯净泛音共鸣
	# 泛音比例基于毕达哥拉斯音程 (2:1, 3:2, 4:3)
	# --------------------------------------------------------
	MusicData.ChapterTimbre.LYRE: {
		"waveform": Waveform.SINE,
		"sub_waveform": Waveform.SINE,
		"sub_mix": 0.3,
		"filter_type": FilterType.LOW_PASS,
		"filter_cutoff_base": 8000.0,
		"filter_cutoff_env_amount": 4000.0,
		"filter_resonance": 0.2,
		"detune_cents": 0.0,
		"num_oscillators": 1,
		"special_processing": "pythagorean_harmonics",
		"brightness": 0.8,
		"harmonics_mode": "pythagorean",
		## 毕达哥拉斯泛音比例: [频率倍数, 振幅]
		"custom_harmonics": [
			[1.0, 1.0],     # 基频
			[2.0, 0.5],     # 八度 (2:1)
			[1.5, 0.35],    # 纯五度 (3:2)
			[4.0 / 3.0, 0.2],  # 纯四度 (4:3)
			[3.0, 0.1],     # 八度+五度
		],
	},

	# --------------------------------------------------------
	# Ch2 — 管风琴 (Organ): 多层正弦波叠加
	# 模拟管风琴的音栓混合 (Drawbar)
	# 无滤波，直接叠加多个正弦波泛音
	# --------------------------------------------------------
	MusicData.ChapterTimbre.ORGAN: {
		"waveform": Waveform.SINE,
		"sub_waveform": Waveform.SINE,
		"sub_mix": 0.0,
		"filter_type": FilterType.NONE,
		"filter_cutoff_base": 15000.0,
		"filter_cutoff_env_amount": 0.0,
		"filter_resonance": 0.0,
		"detune_cents": 0.0,
		"num_oscillators": 1,
		"special_processing": "organ_drawbar",
		"brightness": 0.7,
		"harmonics_mode": "drawbar",
		## 管风琴音栓泛音 (模拟 Hammond B3 音栓配置)
		## 8' = 基频, 4' = 2x, 2-2/3' = 3x, 2' = 4x, ...
		"custom_harmonics": [
			[1.0, 1.0],     # 8' (基频)
			[2.0, 0.8],     # 4'
			[3.0, 0.6],     # 2-2/3'
			[4.0, 0.5],     # 2'
			[5.0, 0.3],     # 1-3/5'
			[6.0, 0.2],     # 1-1/3'
			[8.0, 0.15],    # 1'
		],
	},

	# --------------------------------------------------------
	# Ch3 — 羽管键琴 (Harpsichord): 锯齿波 + 中截止 LPF
	# 极短 Attack，无 Sustain — 模拟拨弦的瞬态特征
	# --------------------------------------------------------
	MusicData.ChapterTimbre.HARPSICHORD: {
		"waveform": Waveform.SAWTOOTH,
		"sub_waveform": Waveform.TRIANGLE,
		"sub_mix": 0.2,
		"filter_type": FilterType.LOW_PASS,
		"filter_cutoff_base": 4000.0,
		"filter_cutoff_env_amount": 6000.0,
		"filter_resonance": 0.35,
		"detune_cents": 5.0,
		"num_oscillators": 1,
		"special_processing": "pluck_transient",
		"brightness": 0.6,
		"harmonics_mode": "standard",
		"custom_harmonics": [
			[1.0, 1.0],
			[2.0, 0.6],
			[3.0, 0.4],
			[4.0, 0.25],
			[5.0, 0.15],
			[6.0, 0.08],
		],
	},

	# --------------------------------------------------------
	# Ch4 — 钢琴 (Fortepiano): 三角波 + 噪音层
	# 力度影响 Attack 和 Brightness
	# LPF 截止频率随力度动态变化
	# --------------------------------------------------------
	MusicData.ChapterTimbre.FORTEPIANO: {
		"waveform": Waveform.TRIANGLE,
		"sub_waveform": Waveform.NOISE,
		"sub_mix": 0.05,
		"filter_type": FilterType.LOW_PASS,
		"filter_cutoff_base": 5000.0,
		"filter_cutoff_env_amount": 5000.0,
		"filter_resonance": 0.15,
		"detune_cents": 2.0,
		"num_oscillators": 1,
		"special_processing": "velocity_sensitive",
		"brightness": 0.65,
		"harmonics_mode": "piano",
		## 钢琴泛音（含轻微不谐和泛音，模拟琴弦刚性）
		"custom_harmonics": [
			[1.0, 1.0],
			[2.0, 0.3],
			[3.0, 0.15],
			[4.003, 0.08],   # 轻微不谐和
			[5.01, 0.04],    # 轻微不谐和
		],
	},

	# --------------------------------------------------------
	# Ch5 — 管弦全奏 (Tutti): 超级锯齿波 (多振荡器)
	# 渐强渐弱的滤波器包络扫频
	# 多个略微失谐的振荡器叠加产生厚重音色
	# --------------------------------------------------------
	MusicData.ChapterTimbre.TUTTI: {
		"waveform": Waveform.SUPERSAW,
		"sub_waveform": Waveform.SAWTOOTH,
		"sub_mix": 0.0,
		"filter_type": FilterType.LOW_PASS,
		"filter_cutoff_base": 2000.0,
		"filter_cutoff_env_amount": 8000.0,
		"filter_resonance": 0.3,
		"detune_cents": 15.0,
		"num_oscillators": 5,
		"special_processing": "crescendo_sweep",
		"brightness": 0.5,
		"harmonics_mode": "standard",
		"custom_harmonics": [
			[1.0, 1.0],
			[2.0, 0.5],
			[3.0, 0.35],
			[4.0, 0.25],
			[5.0, 0.15],
			[6.0, 0.1],
		],
	},

	# --------------------------------------------------------
	# Ch6 — 铜管/萨克斯 (Brass/Saxophone): 方波 + 带通滤波
	# 模拟铜管的"嘟"到"嘶"的起音过渡
	# --------------------------------------------------------
	MusicData.ChapterTimbre.SAXOPHONE: {
		"waveform": Waveform.SQUARE,
		"sub_waveform": Waveform.SAWTOOTH,
		"sub_mix": 0.25,
		"filter_type": FilterType.BAND_PASS,
		"filter_cutoff_base": 3000.0,
		"filter_cutoff_env_amount": 4000.0,
		"filter_resonance": 0.5,
		"detune_cents": 3.0,
		"num_oscillators": 1,
		"special_processing": "brass_attack",
		"brightness": 0.55,
		"harmonics_mode": "odd_dominant",
		## 铜管/萨克斯泛音（奇数泛音为主）
		"custom_harmonics": [
			[1.0, 1.0],
			[2.0, 0.2],
			[3.0, 0.45],
			[4.0, 0.1],
			[5.0, 0.2],
			[6.0, 0.05],
			[7.0, 0.1],
		],
	},

	# --------------------------------------------------------
	# Ch7 — 频谱合成器 (Spectral Synthesizer): 噪音 + 共振滤波
	# 随机频谱成分，每次施法不同
	# 多峰共振滤波器产生金属/电子质感
	# --------------------------------------------------------
	MusicData.ChapterTimbre.SYNTHESIZER: {
		"waveform": Waveform.NOISE,
		"sub_waveform": Waveform.SQUARE,
		"sub_mix": 0.4,
		"filter_type": FilterType.MULTI_PEAK,
		"filter_cutoff_base": 2000.0,
		"filter_cutoff_env_amount": 6000.0,
		"filter_resonance": 0.7,
		"detune_cents": 0.0,
		"num_oscillators": 1,
		"special_processing": "spectral_random",
		"brightness": 0.4,
		"harmonics_mode": "spectral",
		## 频谱合成泛音（运行时会被随机化）
		"custom_harmonics": [
			[1.0, 1.0],
			[3.0, 0.33],
			[5.0, 0.2],
			[7.0, 0.14],
			[9.0, 0.11],
		],
	},

	# --------------------------------------------------------
	# 默认（无音色武器）
	# --------------------------------------------------------
	MusicData.ChapterTimbre.NONE: {
		"waveform": Waveform.SINE,
		"sub_waveform": Waveform.TRIANGLE,
		"sub_mix": 0.1,
		"filter_type": FilterType.LOW_PASS,
		"filter_cutoff_base": 5000.0,
		"filter_cutoff_env_amount": 3000.0,
		"filter_resonance": 0.2,
		"detune_cents": 0.0,
		"num_oscillators": 1,
		"special_processing": "none",
		"brightness": 0.5,
		"harmonics_mode": "standard",
		"custom_harmonics": [
			[1.0, 1.0],
			[2.0, 0.3],
			[3.0, 0.1],
		],
	},
}

# ============================================================
# 电子乐变体合成器预设覆盖
# ============================================================

## 电子乐变体对原始预设的参数覆盖
## 保留原音色的核心 ADSR，但替换合成器参数以产生电子乐风格
const ELECTRONIC_OVERRIDES: Dictionary = {
	# Sine Wave Synth (里拉琴变体) — 纯正弦波
	MusicData.ElectronicVariant.SINE_WAVE_SYNTH: {
		"waveform": Waveform.SINE,
		"sub_mix": 0.0,
		"filter_type": FilterType.NONE,
		"special_processing": "pure_sine",
		"custom_harmonics": [[1.0, 1.0]],
	},

	# Drone Synth (管风琴变体) — 持续低频无人机音
	MusicData.ElectronicVariant.DRONE_SYNTH: {
		"waveform": Waveform.SAWTOOTH,
		"sub_waveform": Waveform.SQUARE,
		"sub_mix": 0.3,
		"filter_type": FilterType.LOW_PASS,
		"filter_cutoff_base": 800.0,
		"filter_resonance": 0.6,
		"detune_cents": 20.0,
		"special_processing": "drone_lfo",
	},

	# Arpeggiator Synth (羽管键琴变体) — 电子琶音
	MusicData.ElectronicVariant.ARPEGGIATOR_SYNTH: {
		"waveform": Waveform.SQUARE,
		"sub_mix": 0.15,
		"filter_type": FilterType.LOW_PASS,
		"filter_cutoff_base": 3000.0,
		"filter_cutoff_env_amount": 5000.0,
		"special_processing": "arpeggio_gate",
	},

	# Velocity Pad (钢琴变体) — 合成垫音
	MusicData.ElectronicVariant.VELOCITY_PAD: {
		"waveform": Waveform.SAWTOOTH,
		"sub_waveform": Waveform.TRIANGLE,
		"sub_mix": 0.4,
		"filter_type": FilterType.LOW_PASS,
		"filter_cutoff_base": 2000.0,
		"filter_resonance": 0.4,
		"detune_cents": 12.0,
		"num_oscillators": 3,
		"special_processing": "pad_chorus",
	},

	# Supersaw Synth (管弦全奏变体) — 超级锯齿波
	MusicData.ElectronicVariant.SUPERSAW_SYNTH: {
		"waveform": Waveform.SUPERSAW,
		"sub_mix": 0.0,
		"filter_type": FilterType.LOW_PASS,
		"filter_cutoff_base": 3000.0,
		"filter_cutoff_env_amount": 10000.0,
		"filter_resonance": 0.25,
		"detune_cents": 25.0,
		"num_oscillators": 7,
		"special_processing": "supersaw_unison",
	},

	# FM Synth (萨克斯变体) — FM 合成器
	MusicData.ElectronicVariant.FM_SYNTH: {
		"waveform": Waveform.SINE,
		"sub_waveform": Waveform.SINE,
		"sub_mix": 0.0,
		"filter_type": FilterType.NONE,
		"special_processing": "fm_synthesis",
		## FM 合成专用参数
		"fm_ratio": 2.0,        # 调制器/载波频率比
		"fm_depth": 3.0,        # 调制深度
		"fm_env_amount": 2.0,   # 调制深度包络调制量
	},

	# Glitch Engine (合成主脑变体) — 故障引擎
	MusicData.ElectronicVariant.GLITCH_ENGINE: {
		"waveform": Waveform.NOISE,
		"sub_waveform": Waveform.SQUARE,
		"sub_mix": 0.5,
		"filter_type": FilterType.MULTI_PEAK,
		"filter_cutoff_base": 1500.0,
		"filter_resonance": 0.8,
		"special_processing": "bitcrush_glitch",
		## Bitcrush 参数
		"bitcrush_bits": 4,     # 位深度降低
		"bitcrush_rate": 8000,  # 降采样率
	},
}

# ============================================================
# 工具方法
# ============================================================

## 获取指定章节音色武器的合成器预设
## 如果使用电子乐变体，会将变体覆盖参数合并到基础预设上
static func get_preset(chapter_timbre: int, electronic_variant: int = MusicData.ElectronicVariant.NONE) -> Dictionary:
	var base_preset: Dictionary = SYNTH_PRESETS.get(chapter_timbre, SYNTH_PRESETS[MusicData.ChapterTimbre.NONE]).duplicate(true)

	# 如果有电子乐变体，合并覆盖参数
	if electronic_variant != MusicData.ElectronicVariant.NONE:
		var overrides: Dictionary = ELECTRONIC_OVERRIDES.get(electronic_variant, {})
		for key in overrides:
			base_preset[key] = overrides[key]

	return base_preset

## 获取完整的合成器参数（合并 ADSR + 合成器预设）
static func get_full_params(chapter_timbre: int, electronic_variant: int = MusicData.ElectronicVariant.NONE) -> Dictionary:
	var preset := get_preset(chapter_timbre, electronic_variant)

	# 获取 ADSR 参数
	var adsr: Dictionary = MusicData.CHAPTER_TIMBRE_ADSR.get(
		chapter_timbre, MusicData.CHAPTER_TIMBRE_ADSR[MusicData.ChapterTimbre.NONE]
	)

	# 合并
	var full_params := preset.duplicate(true)
	full_params["attack"] = adsr.get("attack", 0.01)
	full_params["decay"] = adsr.get("decay", 0.1)
	full_params["sustain"] = adsr.get("sustain", 0.7)
	full_params["release"] = adsr.get("release", 0.3)

	return full_params
