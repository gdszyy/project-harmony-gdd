## audio_event.gd
## 音效事件数据结构 (OPT05: Rez-Style Input Quantization)
##
## 封装一个待播放的音效事件的所有参数。
## 用于 AudioEventQueue 的量化调度系统，实现"视觉即时、音频量化"的错觉。
##
## 设计参考：
##   - Docs/Optimization_Modules/OPT05_RezStyleInputQuantization.md
##   - 《Rez》/ 《Rez Infinite》— 设计灵感来源
class_name AudioEvent
extends RefCounted

# ============================================================
# 事件类型枚举
# ============================================================

## 音效事件的来源类型，决定播放时使用的音频总线和优先级
enum SourceType {
	SPELL,              ## 玩家法术施放音效
	CHORD,              ## 和弦法术音效
	ENEMY_HIT,          ## 敌人受击音效
	ENEMY_DEATH,        ## 敌人死亡音效
	ENEMY_MOVE,         ## 敌人移动音效
	STATUS_FEEDBACK,    ## 状态反馈音效（寂静、过载等）
	PROGRESSION,        ## 和弦进行完成音效
	OTHER,              ## 其他音效
}

# ============================================================
# 事件属性
# ============================================================

## 音效资源标识（对应 AudioManager._generated_sounds 中的 key）
var sound_id: String = ""

## 音高缩放（Godot 的 pitch_scale）
var pitch: float = 1.0

## 音量 (dB)
var volume_db: float = 0.0

## 空间位置（用于 2D 空间化音效）
var position: Vector2 = Vector2.ZERO

## 是否为空间化音效（true = 使用 AudioStreamPlayer2D，false = 使用全局 AudioStreamPlayer）
var is_spatial: bool = false

## 原始输入时间戳（毫秒）
var timestamp_ms: float = 0.0

## 来源类型
var source_type: SourceType = SourceType.OTHER

## 目标音频总线名称
var bus_name: String = "SFX"

## 附加数据（用于和弦等复杂音效的额外参数）
var extra_data: Dictionary = {}

# ============================================================
# 工厂方法
# ============================================================

## 创建一个法术施放音效事件
static func create_spell(sound_id: String, pos: Vector2,
		volume_db: float = -8.0, pitch: float = 1.0,
		bus: String = "PlayerSFX") -> AudioEvent:
	var event := AudioEvent.new()
	event.sound_id = sound_id
	event.position = pos
	event.volume_db = volume_db
	event.pitch = pitch
	event.is_spatial = true
	event.source_type = SourceType.SPELL
	event.bus_name = bus
	event.timestamp_ms = Time.get_ticks_msec()
	return event

## 创建一个和弦法术音效事件
static func create_chord(sound_id: String, pos: Vector2,
		chord_data: Dictionary = {},
		volume_db: float = -6.0, pitch: float = 1.0,
		bus: String = "PlayerSFX") -> AudioEvent:
	var event := AudioEvent.new()
	event.sound_id = sound_id
	event.position = pos
	event.volume_db = volume_db
	event.pitch = pitch
	event.is_spatial = true
	event.source_type = SourceType.CHORD
	event.bus_name = bus
	event.extra_data = chord_data
	event.timestamp_ms = Time.get_ticks_msec()
	return event

## 创建一个敌人音效事件
static func create_enemy(sound_id: String, pos: Vector2,
		source: SourceType = SourceType.ENEMY_HIT,
		volume_db: float = -10.0, pitch: float = 1.0,
		bus: String = "EnemySFX") -> AudioEvent:
	var event := AudioEvent.new()
	event.sound_id = sound_id
	event.position = pos
	event.volume_db = volume_db
	event.pitch = pitch
	event.is_spatial = true
	event.source_type = source
	event.bus_name = bus
	event.timestamp_ms = Time.get_ticks_msec()
	return event

## 创建一个全局（非空间化）音效事件
static func create_global(sound_id: String,
		source: SourceType = SourceType.OTHER,
		volume_db: float = -6.0, pitch: float = 1.0,
		bus: String = "SFX") -> AudioEvent:
	var event := AudioEvent.new()
	event.sound_id = sound_id
	event.volume_db = volume_db
	event.pitch = pitch
	event.is_spatial = false
	event.source_type = source
	event.bus_name = bus
	event.timestamp_ms = Time.get_ticks_msec()
	return event
