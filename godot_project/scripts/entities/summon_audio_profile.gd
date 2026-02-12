## summon_audio_profile.gd
## 召唤物音频配置资源 (OPT07 — 召唤系统音乐性深化)
##
## 为每种构造体定义独立的音色类型、触发模式、音高策略等参数，
## 使召唤物的每一次行动都成为一个真实的、与 BGM 同步的音频事件。
##
## 参考文档：
##   Docs/Optimization_Modules/OPT07_SummoningSystemMusicality.md
##   Docs/SummoningSystem_Documentation.md
##   Docs/Audio_Design_Guide.md
class_name SummonAudioProfile
extends Resource

# ============================================================
# 触发模式枚举
# ============================================================
enum TriggerMode {
	PER_BEAT,         ## 每拍触发（节拍哨塔）
	PER_STRONG_BEAT,  ## 仅强拍触发（重低音炮）
	PER_SIXTEENTH,    ## 每十六分音符触发（高频陷阱）
	ON_EVENT,         ## 由游戏逻辑事件触发（长程棱镜、净化信标）
	SUSTAINED,        ## 持续播放（低频音墙、和声光环）
}

# ============================================================
# 音高策略枚举
# ============================================================
enum PitchStrategy {
	CHORD_ROOT,       ## 和弦根音（节拍哨塔、重低音炮）
	CHORD_ARPEGGIO,   ## 和弦琶音序列（长程棱镜）
	CHORD_FIFTH,      ## 和弦五音（低频音墙）
	SCALE_DESCEND,    ## 下行音阶（净化信标）
	CHORD_FULL,       ## 完整和弦音（和声光环）
	NO_PITCH,         ## 无音高 — 纯打击乐（高频陷阱）
}

# ============================================================
# 导出属性
# ============================================================

## 音色类型标识 — 对应程序化合成的音色名称
@export var timbre_id: String = "pluck"

## 触发模式
@export var trigger_mode: TriggerMode = TriggerMode.PER_BEAT

## 音高策略
@export var pitch_strategy: PitchStrategy = PitchStrategy.CHORD_ROOT

## 基础八度 (MIDI 八度编号，4 = 中央 C 所在八度)
@export_range(1, 7) var base_octave: int = 4

## 音量 (dB)
@export_range(-40.0, 0.0) var volume_db: float = -12.0

## 是否使用空间化播放 (AudioStreamPlayer2D)
@export var use_spatial: bool = true

## 音色描述（用于 UI 显示和调试）
@export var timbre_description: String = ""

# ============================================================
# 预设工厂方法 — 为七种构造体创建默认配置
# ============================================================

## C — 节拍哨塔：清脆、短促的合成器拨弦音
static func create_beat_sentry() -> SummonAudioProfile:
	var profile := SummonAudioProfile.new()
	profile.timbre_id = "pluck"
	profile.trigger_mode = TriggerMode.PER_BEAT
	profile.pitch_strategy = PitchStrategy.CHORD_ROOT
	profile.base_octave = 4
	profile.volume_db = -10.0
	profile.use_spatial = true
	profile.timbre_description = "清脆、短促的合成器拨弦音 (Pluck/Rimshot)"
	return profile

## D — 长程棱镜：上升琶音 + 延迟回声
static func create_long_range_prism() -> SummonAudioProfile:
	var profile := SummonAudioProfile.new()
	profile.timbre_id = "delay_echo"
	profile.trigger_mode = TriggerMode.ON_EVENT
	profile.pitch_strategy = PitchStrategy.CHORD_ARPEGGIO
	profile.base_octave = 4
	profile.volume_db = -12.0
	profile.use_spatial = true
	profile.timbre_description = "上升琶音 + 延迟回声 (Delay Echo)"
	return profile

## E — 低频音墙：节奏性的门限脉冲
static func create_bass_wall() -> SummonAudioProfile:
	var profile := SummonAudioProfile.new()
	profile.timbre_id = "gate_pulse"
	profile.trigger_mode = TriggerMode.SUSTAINED
	profile.pitch_strategy = PitchStrategy.CHORD_FIFTH
	profile.base_octave = 3
	profile.volume_db = -14.0
	profile.use_spatial = true
	profile.timbre_description = "节奏性的门限脉冲 (Gate Pulse)"
	return profile

## F — 净化信标：从高到低的滤波扫频
static func create_cleanse_beacon() -> SummonAudioProfile:
	var profile := SummonAudioProfile.new()
	profile.timbre_id = "denoise_sweep"
	profile.trigger_mode = TriggerMode.ON_EVENT
	profile.pitch_strategy = PitchStrategy.SCALE_DESCEND
	profile.base_octave = 5
	profile.volume_db = -12.0
	profile.use_spatial = true
	profile.timbre_description = "从高到低的滤波扫频 (De-noise Sweep)"
	return profile

## G — 重低音炮：深沉、有冲击力的低频
static func create_sub_bass_cannon() -> SummonAudioProfile:
	var profile := SummonAudioProfile.new()
	profile.timbre_id = "sub_bass_808"
	profile.trigger_mode = TriggerMode.PER_STRONG_BEAT
	profile.pitch_strategy = PitchStrategy.CHORD_ROOT
	profile.base_octave = 2
	profile.volume_db = -8.0
	profile.use_spatial = true
	profile.timbre_description = "深沉、有冲击力的低频 808 Kick (Sub-Bass)"
	return profile

## A — 和声光环：柔和、缓慢演变的和声铺底
static func create_harmony_halo() -> SummonAudioProfile:
	var profile := SummonAudioProfile.new()
	profile.timbre_id = "pad_drone"
	profile.trigger_mode = TriggerMode.SUSTAINED
	profile.pitch_strategy = PitchStrategy.CHORD_FULL
	profile.base_octave = 3
	profile.volume_db = -16.0
	profile.use_spatial = true
	profile.timbre_description = "柔和、缓慢演变的和声铺底 (Pad/Drone)"
	return profile

## B — 高频陷阱：快速的高频节奏序列
static func create_hihat_trap() -> SummonAudioProfile:
	var profile := SummonAudioProfile.new()
	profile.timbre_id = "hihat_pattern"
	profile.trigger_mode = TriggerMode.PER_SIXTEENTH
	profile.pitch_strategy = PitchStrategy.NO_PITCH
	profile.base_octave = 6
	profile.volume_db = -18.0
	profile.use_spatial = true
	profile.timbre_description = "快速的高频节奏序列 (Hi-hat Pattern)"
	return profile

# ============================================================
# 根音索引 → 预设映射
# ============================================================

## 根据根音索引 (0=C ~ 6=B) 获取对应的音频配置
static func get_profile_for_root(root_note_index: int) -> SummonAudioProfile:
	match root_note_index:
		0: return create_beat_sentry()       # C — 节拍哨塔
		1: return create_long_range_prism()   # D — 长程棱镜
		2: return create_bass_wall()          # E — 低频音墙
		3: return create_cleanse_beacon()     # F — 净化信标
		4: return create_sub_bass_cannon()    # G — 重低音炮
		5: return create_harmony_halo()       # A — 和声光环
		6: return create_hihat_trap()         # B — 高频陷阱
		_: return create_beat_sentry()        # 默认
