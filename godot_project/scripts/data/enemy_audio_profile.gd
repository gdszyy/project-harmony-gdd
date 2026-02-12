## enemy_audio_profile.gd
## 敌人音频配置资源 — OPT03: 敌人乐器身份与音高维度
##
## 为每种敌人类型定义其"乐器角色"，包括音域、音高选择策略、
## 噪音/音高混合比例等参数。配合 EnemyAudioController 使用，
## 使敌人从纯粹的"噪音源"提升为"有固定音高的打击乐器或合成器"。
##
## 设计参考: OPT03_EnemyMusicalInstrumentIdentity.md
class_name EnemyAudioProfile
extends Resource

# ============================================================
# 乐器角色与音域
# ============================================================

## 乐器角色标识（用于调试和日志）
@export var instrument_role: String = "hi_hat"

## 基础八度 (MIDI 八度编号, 0-8)
@export var base_octave: int = 5

## 音域范围（半音数）
@export var pitch_range: int = 12

## 音高选择策略
@export_enum("random_scale", "chord_root", "chord_approach", "arpeggio", "chord_fifth")
var pitch_strategy: String = "random_scale"

# ============================================================
# 音色与混合
# ============================================================

## 噪音层与音高层的混合比例 (0.0=纯音高, 1.0=纯噪音)
@export_range(0.0, 1.0) var noise_mix: float = 0.7

## 音高层波形类型: 0=正弦, 1=方波, 2=锯齿, 3=三角
@export_range(0, 3) var pitch_waveform: int = 0

## 音高层音量 (dB)
@export_range(-40.0, 0.0) var pitch_volume_db: float = -12.0

# ============================================================
# ADSR 包络
# ============================================================

@export_range(0.001, 0.5) var attack_time: float = 0.005
@export_range(0.01, 1.0) var decay_time: float = 0.05
@export_range(0.0, 1.0) var sustain_level: float = 0.7
@export_range(0.01, 2.0) var release_time: float = 0.05

# ============================================================
# 持续型音效配置 (Silence / Wall)
# ============================================================

## 是否为持续型音效 (drone/pad)
@export var is_sustained: bool = false

## 持续型音效的循环采样时长 (秒)
@export_range(0.5, 4.0) var sustained_loop_duration: float = 2.0

# ============================================================
# 琶音配置 (Pulse 专用)
# ============================================================

@export_range(0.05, 1.0) var arpeggio_step_interval: float = 0.15
@export_enum("up", "down", "up_down", "random") var arpeggio_mode: String = "up"

# ============================================================
# 经过音配置 (Screech 专用)
# ============================================================

@export_range(0.01, 0.5) var approach_glide_time: float = 0.08
@export_range(-3, 3) var approach_offset: int = 1

# ============================================================
# 工厂方法
# ============================================================

## Static (底噪) — 高频打击乐 (Hi-hats)
static func create_static_profile() -> EnemyAudioProfile:
	var p := EnemyAudioProfile.new()
	p.instrument_role = "hi_hat"
	p.base_octave = 5
	p.pitch_range = 12
	p.pitch_strategy = "random_scale"
	p.noise_mix = 0.75
	p.pitch_waveform = 1       # 方波
	p.pitch_volume_db = -15.0
	p.attack_time = 0.002
	p.decay_time = 0.03
	p.sustain_level = 0.0
	p.release_time = 0.02
	p.is_sustained = false
	return p

## Silence (寂静) — 超低频铺底 (Sub-Bass Pad)
static func create_silence_profile() -> EnemyAudioProfile:
	var p := EnemyAudioProfile.new()
	p.instrument_role = "sub_bass_pad"
	p.base_octave = 1
	p.pitch_range = 12
	p.pitch_strategy = "chord_root"
	p.noise_mix = 0.60
	p.pitch_waveform = 0       # 正弦波
	p.pitch_volume_db = -10.0
	p.attack_time = 0.3
	p.decay_time = 0.5
	p.sustain_level = 0.8
	p.release_time = 0.5
	p.is_sustained = true
	p.sustained_loop_duration = 2.0
	return p

## Screech (尖啸) — 独奏主音 (Lead Synth)
static func create_screech_profile() -> EnemyAudioProfile:
	var p := EnemyAudioProfile.new()
	p.instrument_role = "lead_synth"
	p.base_octave = 6
	p.pitch_range = 12
	p.pitch_strategy = "chord_approach"
	p.noise_mix = 0.65
	p.pitch_waveform = 2       # 锯齿波
	p.pitch_volume_db = -8.0
	p.attack_time = 0.001
	p.decay_time = 0.08
	p.sustain_level = 0.5
	p.release_time = 0.1
	p.is_sustained = false
	p.approach_glide_time = 0.08
	p.approach_offset = 1
	return p

## Pulse (脉冲) — 节奏型琶音 (Arpeggiator)
static func create_pulse_profile() -> EnemyAudioProfile:
	var p := EnemyAudioProfile.new()
	p.instrument_role = "arpeggiator"
	p.base_octave = 4
	p.pitch_range = 12
	p.pitch_strategy = "arpeggio"
	p.noise_mix = 0.65
	p.pitch_waveform = 1       # 方波
	p.pitch_volume_db = -12.0
	p.attack_time = 0.003
	p.decay_time = 0.05
	p.sustain_level = 0.6
	p.release_time = 0.04
	p.is_sustained = false
	p.arpeggio_step_interval = 0.15
	p.arpeggio_mode = "up"
	return p

## Wall (音墙) — 和声长音 (Drone)
static func create_wall_profile() -> EnemyAudioProfile:
	var p := EnemyAudioProfile.new()
	p.instrument_role = "drone"
	p.base_octave = 2
	p.pitch_range = 12
	p.pitch_strategy = "chord_fifth"
	p.noise_mix = 0.60
	p.pitch_waveform = 3       # 三角波
	p.pitch_volume_db = -10.0
	p.attack_time = 0.4
	p.decay_time = 0.6
	p.sustain_level = 0.85
	p.release_time = 0.8
	p.is_sustained = true
	p.sustained_loop_duration = 3.0
	return p
