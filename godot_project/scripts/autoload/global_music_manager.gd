## global_music_manager.gd
## 全局音乐管理器 (Autoload)
## 负责背景音乐播放、频谱分析、节拍能量提取、音符/和弦音效播放
extends Node

# ============================================================
# 信号
# ============================================================
signal beat_energy_updated(energy: float)
signal spectrum_updated(low: float, mid: float, high: float)
signal note_played(note: int, timbre: int)       ## 音符播放时发出
signal chord_played(notes: Array, timbre: int)    ## 和弦播放时发出

# ============================================================
# 配置
# ============================================================
## 音频总线名称
const MUSIC_BUS_NAME := "Music"
const SFX_BUS_NAME := "SFX"
const NOTE_BUS_NAME := "Player"  # 音符音效使用 Player 总线

## 频谱分析频率范围
const LOW_FREQ_MIN := 20.0
const LOW_FREQ_MAX := 200.0
const MID_FREQ_MIN := 200.0
const MID_FREQ_MAX := 2000.0
const HIGH_FREQ_MIN := 2000.0
const HIGH_FREQ_MAX := 16000.0

## 能量平滑系数
const ENERGY_SMOOTHING := 0.15

## 音符播放器池大小
const NOTE_POOL_SIZE: int = 12

## 音符最小播放间隔（秒）— 防止同一音符连续触发
const NOTE_COOLDOWN: float = 0.05

# ============================================================
# 状态
# ============================================================
var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance = null
var current_beat_energy: float = 0.0
var _smoothed_energy: float = 0.0
var _low_energy: float = 0.0
var _mid_energy: float = 0.0
var _high_energy: float = 0.0

# ============================================================
# 音符音频系统
# ============================================================

## 音符频率映射 — 引用 MusicData.NOTE_FREQUENCIES
## 见 scripts/data/music_data.gd 中的完整定义

## 音符合成器实例
var _synthesizer: NoteSynthesizer = null

## 当前活跃音色
var _current_timbre: int = MusicData.TimbreType.NONE

## 音符播放器对象池 (AudioStreamPlayer)
var _note_pool: Array[AudioStreamPlayer] = []
var _note_pool_index: int = 0

## 音符冷却记录
var _note_cooldowns: Dictionary = {}

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_audio_buses()
	_init_synthesizer()
	_init_note_pool()

func _process(_delta: float) -> void:
	_update_spectrum_analysis()

# ============================================================
# 音频总线设置
# ============================================================

func _setup_audio_buses() -> void:
	# 确保 Music 总线存在
	var music_bus_idx := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if music_bus_idx == -1:
		AudioServer.add_bus()
		music_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_bus_idx, MUSIC_BUS_NAME)

	# 添加频谱分析器
	var has_analyzer := false
	for i in range(AudioServer.get_bus_effect_count(music_bus_idx)):
		if AudioServer.get_bus_effect(music_bus_idx, i) is AudioEffectSpectrumAnalyzer:
			has_analyzer = true
			spectrum_analyzer = AudioServer.get_bus_effect_instance(music_bus_idx, i)
			break

	if not has_analyzer:
		var analyzer := AudioEffectSpectrumAnalyzer.new()
		analyzer.buffer_length = 0.1
		analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
		AudioServer.add_bus_effect(music_bus_idx, analyzer)
		spectrum_analyzer = AudioServer.get_bus_effect_instance(
			music_bus_idx, AudioServer.get_bus_effect_count(music_bus_idx) - 1
		)

	# 确保 SFX 总线存在
	var sfx_bus_idx := AudioServer.get_bus_index(SFX_BUS_NAME)
	if sfx_bus_idx == -1:
		AudioServer.add_bus()
		sfx_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_bus_idx, SFX_BUS_NAME)

# ============================================================
# 合成器初始化
# ============================================================

func _init_synthesizer() -> void:
	_synthesizer = NoteSynthesizer.new()

func _init_note_pool() -> void:
	for i in range(NOTE_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = NOTE_BUS_NAME
		add_child(player)
		_note_pool.append(player)

# ============================================================
# 频谱分析
# ============================================================

func _update_spectrum_analysis() -> void:
	if spectrum_analyzer == null:
		return

	# 获取各频段能量
	var low_mag := spectrum_analyzer.get_magnitude_for_frequency_range(LOW_FREQ_MIN, LOW_FREQ_MAX)
	var mid_mag := spectrum_analyzer.get_magnitude_for_frequency_range(MID_FREQ_MIN, MID_FREQ_MAX)
	var high_mag := spectrum_analyzer.get_magnitude_for_frequency_range(HIGH_FREQ_MIN, HIGH_FREQ_MAX)

	_low_energy = lerp(_low_energy, low_mag.length() * 10.0, ENERGY_SMOOTHING)
	_mid_energy = lerp(_mid_energy, mid_mag.length() * 8.0, ENERGY_SMOOTHING)
	_high_energy = lerp(_high_energy, high_mag.length() * 6.0, ENERGY_SMOOTHING)

	# 节拍能量 (主要来自低频)
	_smoothed_energy = lerp(_smoothed_energy, _low_energy, ENERGY_SMOOTHING)
	current_beat_energy = _smoothed_energy

	beat_energy_updated.emit(current_beat_energy)
	spectrum_updated.emit(_low_energy, _mid_energy, _high_energy)

## 获取节拍能量 (用于驱动视觉效果)
func get_beat_energy() -> float:
	return current_beat_energy

## 获取各频段能量
func get_spectrum() -> Dictionary:
	return {
		"low": _low_energy,
		"mid": _mid_energy,
		"high": _high_energy,
	}

# ============================================================
# 音色管理
# ============================================================

## 设置当前音色系别
func set_timbre(timbre: int) -> void:
	if timbre == _current_timbre:
		return
	_current_timbre = timbre
	# 预生成该音色的常用音符以减少延迟
	if _synthesizer:
		_synthesizer.pregenerate_common_notes(timbre)

## 获取当前音色系别
func get_current_timbre() -> int:
	return _current_timbre

# ============================================================
# 法术音效播放
# ============================================================

## 播放音符音效
## note: MusicData.Note 枚举值
## duration: 音符时长（秒）
## timbre_override: 音色覆盖，-1 表示使用当前音色
## velocity: 力度 (0.0 ~ 1.0)
## pitch_shift: 音高偏移（半音数，用于八度变化）
func play_note_sound(note: int, duration: float = 0.3,
		timbre_override: int = -1, velocity: float = 0.8,
		pitch_shift: int = 0) -> void:

	# 冷却检查
	var cooldown_key := "note_%d" % note
	if not _check_note_cooldown(cooldown_key):
		return

	var timbre := timbre_override if timbre_override >= 0 else _current_timbre
	var octave := 4 + (pitch_shift / 12)

	# 通过合成器生成音效
	if _synthesizer == null:
		_init_synthesizer()

	var wav := _synthesizer.generate_note(note, timbre, octave, duration, velocity)
	if wav == null:
		return

	# 获取播放器并播放
	var player := _get_note_player()
	if player == null:
		return

	player.stream = wav
	player.volume_db = _velocity_to_db(velocity)
	player.pitch_scale = 1.0
	player.play()

	note_played.emit(note, timbre)

	# 同时通知 AudioManager 播放法术施放音效（视觉反馈用）
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_spell_cast_sfx"):
		var player_node := get_tree().get_first_node_in_group("player")
		var pos := player_node.global_position if player_node else Vector2.ZERO
		audio_mgr.play_spell_cast_sfx(pos, false)

## 播放和弦音效
## notes: MusicData.Note 枚举值数组
## duration: 和弦时长（秒）
## timbre_override: 音色覆盖
## velocity: 力度
func play_chord_sound(notes: Array, duration: float = 0.5,
		timbre_override: int = -1, velocity: float = 0.7) -> void:

	if notes.is_empty():
		return

	# 冷却检查
	var cooldown_key := "chord_%s" % str(notes)
	if not _check_note_cooldown(cooldown_key):
		return

	var timbre := timbre_override if timbre_override >= 0 else _current_timbre

	if _synthesizer == null:
		_init_synthesizer()

	var wav := _synthesizer.generate_chord(notes, timbre, 4, duration, velocity)
	if wav == null:
		return

	var player := _get_note_player()
	if player == null:
		return

	player.stream = wav
	player.volume_db = _velocity_to_db(velocity)
	player.pitch_scale = 1.0
	player.play()

	chord_played.emit(notes, timbre)

	# 通知 AudioManager
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_chord_cast_sfx"):
		var player_node := get_tree().get_first_node_in_group("player")
		var pos := player_node.global_position if player_node else Vector2.ZERO
		audio_mgr.play_chord_cast_sfx(pos)

## 播放UI音效
func play_ui_sound(sound_name: String) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr == null:
		return
	match sound_name:
		"click":
			audio_mgr.play_ui_click()
		"hover":
			audio_mgr.play_ui_hover()
		"confirm":
			audio_mgr.play_ui_confirm()
		"cancel":
			audio_mgr.play_ui_cancel()
		"level_up":
			audio_mgr.play_level_up_sfx()

# ============================================================
# 内部工具
# ============================================================

## 从对象池获取可用的音符播放器
func _get_note_player() -> AudioStreamPlayer:
	for i in range(NOTE_POOL_SIZE):
		var idx := (_note_pool_index + i) % NOTE_POOL_SIZE
		if not _note_pool[idx].playing:
			_note_pool_index = (idx + 1) % NOTE_POOL_SIZE
			return _note_pool[idx]
	# 池满，覆盖最旧的
	_note_pool_index = (_note_pool_index + 1) % NOTE_POOL_SIZE
	return _note_pool[_note_pool_index]

## 冷却检查
func _check_note_cooldown(key: String) -> bool:
	var current_time := Time.get_ticks_msec() / 1000.0
	var last_time: float = _note_cooldowns.get(key, 0.0)
	if current_time - last_time < NOTE_COOLDOWN:
		return false
	_note_cooldowns[key] = current_time
	return true

## 力度转分贝
func _velocity_to_db(velocity: float) -> float:
	# velocity 0.0 ~ 1.0 映射到 -24dB ~ 0dB
	velocity = clampf(velocity, 0.01, 1.0)
	return linear_to_db(velocity) * 0.5  # 缩小动态范围
