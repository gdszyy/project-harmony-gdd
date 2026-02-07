## global_music_manager.gd
## 全局音乐管理器 (Autoload)
## 负责背景音乐播放、频谱分析、节拍能量提取
extends Node

# ============================================================
# 信号
# ============================================================
signal beat_energy_updated(energy: float)
signal spectrum_updated(low: float, mid: float, high: float)

# ============================================================
# 配置
# ============================================================
## 音频总线名称
const MUSIC_BUS_NAME := "Music"
const SFX_BUS_NAME := "SFX"

## 频谱分析频率范围
const LOW_FREQ_MIN := 20.0
const LOW_FREQ_MAX := 200.0
const MID_FREQ_MIN := 200.0
const MID_FREQ_MAX := 2000.0
const HIGH_FREQ_MIN := 2000.0
const HIGH_FREQ_MAX := 16000.0

## 能量平滑系数
const ENERGY_SMOOTHING := 0.15

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
# 音符音频 (合成器音色)
# ============================================================
## 音符频率映射 (A4 = 440Hz, 中央C = C4)
const NOTE_FREQUENCIES: Dictionary = {
	MusicData.Note.C:  261.63,
	MusicData.Note.CS: 277.18,
	MusicData.Note.D:  293.66,
	MusicData.Note.DS: 311.13,
	MusicData.Note.E:  329.63,
	MusicData.Note.F:  349.23,
	MusicData.Note.FS: 369.99,
	MusicData.Note.G:  392.00,
	MusicData.Note.GS: 415.30,
	MusicData.Note.A:  440.00,
	MusicData.Note.AS: 466.16,
	MusicData.Note.B:  493.88,
}

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_audio_buses()

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
# 法术音效播放
# ============================================================

## 播放音符音效
func play_note_sound(note: MusicData.Note, duration: float = 0.2) -> void:
	# 通过 AudioManager 播放法术施放音效
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_spell_cast_sfx"):
		var player_node := get_tree().get_first_node_in_group("player")
		var pos := player_node.global_position if player_node else Vector2.ZERO
		audio_mgr.play_spell_cast_sfx(pos, false)

## 播放和弦音效
func play_chord_sound(notes: Array, duration: float = 0.3) -> void:
	# 通过 AudioManager 播放和弦施放音效
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
