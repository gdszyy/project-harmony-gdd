## synth_manager.gd
## 程序化音色合成器管理器 (Autoload 单例)
##
## OPT08 — 程序化音色合成
## 管理多个 SynthVoice 实例，实现复音管理（Polyphony）。
## 将音色武器的 ADSR 参数实时映射到合成器参数，
## 实现"所听即所见"——音效与弹体行为的深度统一。
##
## 职责：
##   1. 管理声部池（Voice Pool），实现 Round-Robin 分配
##   2. 将章节音色武器参数转换为合成器参数
##   3. 提供统一的 play_note / stop_note 接口
##   4. 支持在程序化合成和预制采样之间切换（降级方案）
##   5. 监听 GameManager 的音色武器变更信号
##
## 用法：
##   # 在 Autoload 中注册后，全局可用：
##   SynthManager.play_synth_note(261.63, Vector2(100, 200))
##   SynthManager.play_synth_note_with_params(440.0, custom_params, Vector2.ZERO)
##
extends Node

# ============================================================
# 信号
# ============================================================

## 合成器音符播放时发出
## DEPRECATED: Signal emitted but no active consumer connected (Issue #86 audit)
signal synth_note_played(frequency: float, timbre: int)

## 合成器音符停止时发出
## DEPRECATED: Signal emitted but no active consumer connected (Issue #86 audit)
signal synth_note_stopped(voice_index: int)

## 合成模式变更
## DEPRECATED: Signal emitted but no active consumer connected (Issue #86 audit)
signal synthesis_mode_changed(enabled: bool)

# ============================================================
# 常量
# ============================================================

## 最大同时发声数（声部池大小）
const MAX_VOICES: int = 8

## 是否默认启用程序化合成
## 设为 false 时回退到预制采样模式（降级方案）
const DEFAULT_SYNTHESIS_ENABLED: bool = true

# ============================================================
# 状态
# ============================================================

## 声部池
var _voices: Array[SynthVoice] = []

## 当前声部分配索引（Round-Robin）
var _voice_index: int = 0

## 程序化合成是否启用
var _synthesis_enabled: bool = DEFAULT_SYNTHESIS_ENABLED

## 当前缓存的合成器参数（避免每次施法都重新计算）
var _cached_synth_params: Dictionary = {}

## 当前缓存的音色武器类型
var _cached_timbre: int = -1

## 当前缓存的电子乐变体
var _cached_variant: int = -1

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 初始化声部池
	for i in range(MAX_VOICES):
		var voice := SynthVoice.new()
		voice.name = "SynthVoice_%d" % i
		voice.voice_finished.connect(_on_voice_finished.bind(i))
		add_child(voice)
		_voices.append(voice)

	# 连接 GameManager 信号（延迟连接，确保 GameManager 已就绪）
	call_deferred("_connect_signals")

	# 初始化默认合成器参数
	_update_cached_params(MusicData.ChapterTimbre.NONE, MusicData.ElectronicVariant.NONE)

func _connect_signals() -> void:
	if Engine.has_singleton("GameManager") or has_node("/root/GameManager"):
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_signal("chapter_timbre_changed"):
			if not gm.chapter_timbre_changed.is_connected(_on_chapter_timbre_changed):
				gm.chapter_timbre_changed.connect(_on_chapter_timbre_changed)

# ============================================================
# 公共接口
# ============================================================

## 播放一个合成音符（使用当前音色武器参数）
## frequency: 音符频率 (Hz)
## position: 空间位置（用于 2D 空间音频）
func play_synth_note(frequency: float, position: Vector2 = Vector2.ZERO) -> void:
	if not _synthesis_enabled:
		return

	var voice := _allocate_voice()
	voice.set_voice_position(position)

	# 使用缓存的合成器参数
	var params := _cached_synth_params.duplicate(true)
	voice.play_note(frequency, params)

	synth_note_played.emit(frequency, _cached_timbre)

## 播放一个合成音符（使用自定义参数）
## frequency: 音符频率 (Hz)
## timbre_params: 完整的合成器参数字典
## position: 空间位置
func play_synth_note_with_params(frequency: float, timbre_params: Dictionary,
		position: Vector2 = Vector2.ZERO) -> void:
	if not _synthesis_enabled:
		return

	var voice := _allocate_voice()
	voice.set_voice_position(position)
	voice.play_note(frequency, timbre_params)

	var timbre: int = timbre_params.get("chapter_timbre", MusicData.ChapterTimbre.NONE)
	synth_note_played.emit(frequency, timbre)

## 播放一个合成音符（从 MusicData.Note 枚举）
## note: MusicData.Note 枚举值
## octave: 八度 (4 = 中央C所在八度)
## position: 空间位置
func play_synth_note_from_enum(note: int, octave: int = 4,
		position: Vector2 = Vector2.ZERO) -> void:
	var frequency := _note_to_frequency(note, octave)
	play_synth_note(frequency, position)

## 停止所有声部
func stop_all() -> void:
	for voice in _voices:
		voice.stop_note()

## 强制停止所有声部（立即静音）
func force_stop_all() -> void:
	for voice in _voices:
		voice.force_stop()

## 启用/禁用程序化合成
func set_synthesis_enabled(enabled: bool) -> void:
	_synthesis_enabled = enabled
	if not enabled:
		force_stop_all()
	synthesis_mode_changed.emit(enabled)

## 程序化合成是否启用
func is_synthesis_enabled() -> bool:
	return _synthesis_enabled

## 手动更新音色武器参数（当 GameManager 不可用时使用）
func update_timbre(chapter_timbre: int,
		electronic_variant: int = MusicData.ElectronicVariant.NONE) -> void:
	_update_cached_params(chapter_timbre, electronic_variant)

## 获取当前活跃声部数量
func get_active_voice_count() -> int:
	var count := 0
	for voice in _voices:
		if voice.is_playing():
			count += 1
	return count

## 获取指定章节音色武器的完整合成器参数（供外部系统查询）
func get_synth_params_for_timbre(chapter_timbre: int,
		electronic_variant: int = MusicData.ElectronicVariant.NONE) -> Dictionary:
	return TimbreSynthPresets.get_full_params(chapter_timbre, electronic_variant)

# ============================================================
# 声部分配
# ============================================================

## 分配一个声部（Round-Robin 策略）
func _allocate_voice() -> SynthVoice:
	var voice := _voices[_voice_index]
	_voice_index = (_voice_index + 1) % MAX_VOICES

	# 如果该声部正在使用，强制停止以释放
	if voice.is_playing():
		voice.force_stop()

	return voice

# ============================================================
# 参数管理
# ============================================================

## 更新缓存的合成器参数
func _update_cached_params(chapter_timbre: int, electronic_variant: int) -> void:
	if chapter_timbre == _cached_timbre and electronic_variant == _cached_variant:
		return

	_cached_timbre = chapter_timbre
	_cached_variant = electronic_variant
	_cached_synth_params = TimbreSynthPresets.get_full_params(chapter_timbre, electronic_variant)
	_cached_synth_params["chapter_timbre"] = chapter_timbre

# ============================================================
# 音符频率转换
# ============================================================

## 将 MusicData.Note 枚举转换为频率 (Hz)
## 使用十二平均律：f = 440 × 2^((n-69)/12)
## 其中 n = note + (octave + 1) × 12
func _note_to_frequency(note: int, octave: int) -> float:
	# MusicData.Note 枚举: C=0, CS=1, ..., B=11
	# MIDI 音符号: C4 = 60, A4 = 69
	var midi_note := note + (octave + 1) * 12
	return 440.0 * pow(2.0, (float(midi_note) - 69.0) / 12.0)

# ============================================================
# 信号回调
# ============================================================

## GameManager 音色武器变更回调
func _on_chapter_timbre_changed(new_timbre: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	var variant: int = MusicData.ElectronicVariant.NONE
	if gm:
		variant = MusicData.ElectronicVariant.NONE
		if gm.get("is_electronic_variant") and gm.is_electronic_variant:
			variant = MusicData.TIMBRE_TO_VARIANT.get(new_timbre, MusicData.ElectronicVariant.NONE)
	_update_cached_params(new_timbre, variant)

## 声部播放完成回调
func _on_voice_finished(voice_index: int) -> void:
	synth_note_stopped.emit(voice_index)
