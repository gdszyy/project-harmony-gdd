## bgm_manager.gd
## 程序化 Techno BGM 合成引擎 (Autoload)
##
## 不依赖任何外部音频文件，完全在代码中实时合成多层 Minimal Techno / Glitch Techno
## 鼓点与音轨，与 GameManager 的 BPM 系统完美同步。
##
## 音轨层级 (由低到高)：
##   1. Kick (底鼓)        — 4/4 拍核心节拍器，20-80Hz 正弦衰减
##   2. Bass (低音合成器)   — 低频脉冲线，跟随 Kick 节奏
##   3. Snare/Clap (军鼓)  — 2、4 拍重音，白噪音 + 带通滤波
##   4. Hi-Hat (踩镲)      — 八分/十六分音符律动，高频噪声
##   5. Ghost (幽灵鼓组)   — 低音量填充节奏，增加律动感
##   6. Pad (环境音垫)     — 持续的低频合成器氛围层
##
## 设计哲学：
##   - 每个音轨层有独立的 AudioStreamPlayer，输出到 Music 总线
##   - 所有节奏严格锁定到 GameManager.current_bpm
##   - 支持根据游戏状态动态开关/混合各层
##   - 每层可独立调节音量，实现动态编曲
##   - Kick 能量集中在 20-80Hz，天然适合频谱分析驱动视觉
extends Node

# ============================================================
# 信号
# ============================================================
signal bgm_changed(track_name: String)
signal bgm_beat_synced(beat_index: int)
signal bgm_measure_synced(measure_index: int)
signal layer_toggled(layer_name: String, enabled: bool)
signal intensity_changed(new_intensity: float)
## OPT05: 十六分音符时钟信号，用于音效量化系统 (Rez-Style Input Quantization)
signal sixteenth_tick(sixteenth_index: int)
## OPT01: 全局和声上下文变更信号 — 广播当前和弦根音、类型和音符列表
signal harmony_context_changed(chord_root: int, chord_type: int, chord_notes: Array)

# ============================================================
# 常量
# ============================================================
const MUSIC_BUS_NAME := "Music"
const SAMPLE_RATE := 44100
const TWO_PI := TAU  ## 2 * PI

## 预生成的 one-shot 采样时长 (秒)
## 每个鼓点/音色都是一段短采样，由引擎在节拍时刻触发播放
const KICK_DURATION := 0.25
const SNARE_DURATION := 0.18
const HIHAT_CLOSED_DURATION := 0.06
const HIHAT_OPEN_DURATION := 0.15
const GHOST_DURATION := 0.08
const CLAP_DURATION := 0.15

## Bass 音符持续时间 (拍为单位，运行时根据 BPM 换算)
const BASS_NOTE_BEATS := 0.5

## Pad 采样长度 (秒) — 较长的循环片段
const PAD_LOOP_DURATION := 4.0

# ============================================================
# 音轨层配置
# ============================================================

## 每层的默认音量 (dB) 和启用状态
var _layer_config: Dictionary = {
	"kick":  { "volume_db": -6.0,  "enabled": true,  "player": null },
	"snare": { "volume_db": -8.0,  "enabled": true,  "player": null },
	"hihat": { "volume_db": -14.0, "enabled": true,  "player": null },
	"ghost": { "volume_db": -18.0, "enabled": true,  "player": null },
	"bass":  { "volume_db": -10.0, "enabled": true,  "player": null },
	"pad":   { "volume_db": -16.0, "enabled": true,  "player": null },
}

# ============================================================
# 预生成的采样缓存
# ============================================================
var _samples: Dictionary = {}  ## { "kick": AudioStreamWAV, ... }

# ============================================================
# 节拍调度状态
# ============================================================
var _is_playing: bool = false
var _bpm: float = 120.0
var _beat_interval: float = 0.5  ## 秒/拍
var _sixteenth_interval: float = 0.125  ## 秒/十六分音符

## 主时钟：以十六分音符为最小粒度
var _clock_timer: float = 0.0
var _current_sixteenth: int = 0  ## 0-15 (一小节 = 16 个十六分音符)
var _current_beat: int = 0       ## 全局拍号
var _current_measure: int = 0    ## 全局小节号

## 游戏强度 (0.0 ~ 1.0)，影响音轨层的动态混合
var _intensity: float = 0.5

## 节奏型模式 (可切换不同的 hi-hat / ghost 模式)
var _hihat_pattern: Array[bool] = []
var _ghost_pattern: Array[bool] = []
var _bass_pattern: Array[int] = []  ## 音高索引，-1 = 静音

## Bass 音符频率表 (A小调五声音阶的低八度，适合 Techno)
const BASS_NOTES: Array[float] = [
	55.0,   ## A1
	61.74,  ## B1
	65.41,  ## C2
	73.42,  ## D2
	82.41,  ## E2
]

## Pad 和弦频率组 (Am 和弦的不同转位)
const PAD_CHORDS: Array = [
	[110.0, 130.81, 164.81],  ## Am: A2, C3, E3
	[98.0,  123.47, 146.83],  ## G:  G2, B2, D3
	[87.31, 110.0,  130.81],  ## F:  F2, A2, C3
	[82.41, 103.83, 123.47],  ## Em: E2, G#2, B2
]

# ============================================================
# 暂停/闷音状态
# ============================================================
var _is_muffled: bool = false
@export var muffled_cutoff_hz: float = 800.0

# ============================================================
# OPT01: 和声指挥官状态 (Global Dynamic Harmony Conductor)
# ============================================================

## 当前和弦根音 (MIDI 音高类, 0-11)
var current_chord_root: int = 9  ## A (默认 Am)
## 当前和弦类型
var current_chord_type: int = MusicData.ChordType.MINOR  ## 默认小三和弦
## 当前和弦包含的所有音高类
var current_chord_notes: Array[int] = [9, 0, 4]  ## A, C, E
## 当前全局音阶 (由章节调式决定)
var current_scale: Array[int] = [9, 11, 0, 2, 4, 5, 7]  ## A 自然小调

## 缓存的待切换和弦 (等待小节边界)
var _pending_chord: Dictionary = {}
## 自动演进倒计时 (小节数)
var _auto_evolve_countdown: int = 2
## 静默阈值: 玩家无和弦输入超过此小节数后触发自动演进
const AUTO_EVOLVE_THRESHOLD: int = 2
## 马尔可夫链转移概率矩阵 (运行时引用)
var _markov_matrix: Dictionary = {}

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_generate_all_samples()
	_setup_players()
	_init_default_patterns()
	_connect_signals()
	_init_harmony_conductor()  ## OPT01: 初始化和声指挥官

func _process(delta: float) -> void:
	if not _is_playing:
		return

	_clock_timer += delta

	# 十六分音符粒度的主时钟
	while _clock_timer >= _sixteenth_interval:
		_clock_timer -= _sixteenth_interval
		_tick_sixteenth()

# ============================================================
# 初始化
# ============================================================

func _setup_players() -> void:
	for layer_name in _layer_config:
		var player := AudioStreamPlayer.new()
		player.bus = MUSIC_BUS_NAME
		player.volume_db = _layer_config[layer_name]["volume_db"]
		player.name = "BGM_" + layer_name
		add_child(player)
		_layer_config[layer_name]["player"] = player

	# Pad 层需要一个额外的循环播放器
	var pad_player: AudioStreamPlayer = _layer_config["pad"]["player"]
	# Pad 使用循环采样，在 start_bgm() 时启动

func _connect_signals() -> void:
	if GameManager.has_signal("game_state_changed"):
		GameManager.game_state_changed.connect(_on_game_state_changed)
	_connect_fatigue_signals()
	# OPT01: 连接和声指挥官信号
	if MusicTheoryEngine.has_signal("chord_identified"):
		MusicTheoryEngine.chord_identified.connect(_on_player_chord_identified)
	bgm_measure_synced.connect(_on_harmony_measure_synced)

func _init_default_patterns() -> void:
	## Hi-Hat 默认模式：八分音符 (每隔一个十六分音符)
	## 索引 0-15 对应一小节的 16 个十六分音符
	_hihat_pattern = [
		true,  false, true,  false,  # 拍 1: x . x .
		true,  false, true,  false,  # 拍 2: x . x .
		true,  false, true,  false,  # 拍 3: x . x .
		true,  false, true,  false,  # 拍 4: x . x .
	]

	## Ghost 鼓组默认模式：off-beat 填充
	_ghost_pattern = [
		false, false, false, true,   # 拍 1: . . . x
		false, false, false, false,  # 拍 2: . . . .
		false, false, false, true,   # 拍 3: . . . x
		false, true,  false, false,  # 拍 4: . x . .
	]

	## Bass 默认模式：每拍一个音符 (十六分音符索引 0, 4, 8, 12)
	## -1 = 静音，0-4 = BASS_NOTES 索引
	_bass_pattern = [
		0,  -1, -1, -1,   # 拍 1: A1
		-1, -1,  2, -1,   # 拍 2: . . C2 .
		0,  -1, -1, -1,   # 拍 3: A1
		-1, -1,  4, -1,   # 拍 4: . . E2 .
	]

# ============================================================
# 采样生成
# ============================================================

func _generate_all_samples() -> void:
	_samples["kick"] = _gen_kick()
	_samples["kick_hard"] = _gen_kick_hard()
	_samples["snare"] = _gen_snare()
	_samples["clap"] = _gen_clap()
	_samples["hihat_closed"] = _gen_hihat_closed()
	_samples["hihat_open"] = _gen_hihat_open()
	_samples["ghost_tap"] = _gen_ghost_tap()
	_samples["ghost_rim"] = _gen_ghost_rim()

	# Bass 音符：为每个音高预生成采样
	for i in range(BASS_NOTES.size()):
		_samples["bass_%d" % i] = _gen_bass_note(BASS_NOTES[i])

	# Pad 和弦：为每个和弦预生成循环采样
	for i in range(PAD_CHORDS.size()):
		_samples["pad_%d" % i] = _gen_pad_chord(PAD_CHORDS[i])

## ---- Kick (底鼓) ----
## 经典 Techno Kick：正弦波快速下扫 (200Hz → 45Hz) + 指数衰减
## 能量集中在 20-80Hz，为频谱分析提供清晰的低频脉冲
func _gen_kick() -> AudioStreamWAV:
	var samples := int(KICK_DURATION * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in range(samples):
		var t := float(i) / float(samples)
		# 频率包络：指数下扫 200 → 45 Hz
		var freq := 45.0 + 155.0 * exp(-t * 18.0)
		phase += freq / SAMPLE_RATE
		# 振幅包络：快速起音 + 指数衰减
		var amp := exp(-t * 12.0)
		# 轻微的谐波失真增加"冲击感"
		var wave := sin(phase * TWO_PI) * amp
		wave = clamp(wave * 1.3, -1.0, 1.0)  # 软削波
		var sample := int(wave * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data)

## 硬 Kick (用于强拍)
func _gen_kick_hard() -> AudioStreamWAV:
	var samples := int(KICK_DURATION * 1.2 * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in range(samples):
		var t := float(i) / float(samples)
		# 更宽的频率扫描范围
		var freq := 50.0 + 200.0 * exp(-t * 15.0)
		phase += freq / SAMPLE_RATE
		var amp := exp(-t * 10.0) * 1.1
		var wave := sin(phase * TWO_PI) * amp
		# 更强的削波 = 更多谐波 = 更"硬"
		wave = clamp(wave * 1.6, -1.0, 1.0)
		var sample := int(wave * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data)

## ---- Snare (军鼓) ----
## 噪声体 + 低频正弦体，模拟经典 808/909 军鼓
func _gen_snare() -> AudioStreamWAV:
	var samples := int(SNARE_DURATION * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in range(samples):
		var t := float(i) / float(samples)
		# 噪声体 (高频)
		var noise := randf_range(-1.0, 1.0) * exp(-t * 15.0) * 0.55
		# 正弦体 (低频共振)
		phase += 180.0 / SAMPLE_RATE
		var body := sin(phase * TWO_PI) * exp(-t * 25.0) * 0.45
		var wave = clamp(noise + body, -1.0, 1.0)
		var sample := int(wave * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data)

## ---- Clap (拍手) ----
## 多层噪声脉冲叠加，模拟多人拍手的"厚度"
func _gen_clap() -> AudioStreamWAV:
	var samples := int(CLAP_DURATION * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var wave := 0.0
		# 3 个微小偏移的噪声脉冲 (模拟多人拍手)
		for j in range(3):
			var offset := float(j) * 0.008  # 每层偏移 8ms
			var local_t = max(0.0, t - offset)
			if local_t < CLAP_DURATION * 0.8:
				var env := exp(-local_t * 20.0) * 0.35
				wave += randf_range(-1.0, 1.0) * env
		# 带通滤波效果 (简化：通过混合实现中频集中)
		wave = clamp(wave, -1.0, 1.0)
		var sample := int(wave * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data)

## ---- Hi-Hat Closed (闭合踩镲) ----
## 极短的高频噪声脉冲
func _gen_hihat_closed() -> AudioStreamWAV:
	var samples := int(HIHAT_CLOSED_DURATION * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var env := exp(-t * 50.0) * 0.4
		# 高频噪声 + 金属共振
		var noise := randf_range(-1.0, 1.0) * env
		var metal := sin(t * 6000.0 * TWO_PI) * exp(-t * 80.0) * 0.15
		metal += sin(t * 8500.0 * TWO_PI) * exp(-t * 90.0) * 0.1
		var wave = clamp(noise + metal, -1.0, 1.0)
		var sample := int(wave * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data)

## ---- Hi-Hat Open (开放踩镲) ----
## 较长的高频噪声，带有"嘶嘶"的尾音
func _gen_hihat_open() -> AudioStreamWAV:
	var samples := int(HIHAT_OPEN_DURATION * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var env := exp(-t * 12.0) * 0.35
		var noise := randf_range(-1.0, 1.0) * env
		var metal := sin(t * 6000.0 * TWO_PI) * exp(-t * 20.0) * 0.12
		metal += sin(t * 9000.0 * TWO_PI) * exp(-t * 25.0) * 0.08
		var wave = clamp(noise + metal, -1.0, 1.0)
		var sample := int(wave * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data)

## ---- Ghost Tap (幽灵鼓 - 轻拍) ----
## 极轻的鼓面敲击，增加律动的"呼吸感"
func _gen_ghost_tap() -> AudioStreamWAV:
	var samples := int(GHOST_DURATION * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in range(samples):
		var t := float(i) / float(samples)
		var env := exp(-t * 40.0) * 0.25
		phase += 250.0 / SAMPLE_RATE
		var body := sin(phase * TWO_PI) * env * 0.6
		var noise := randf_range(-1.0, 1.0) * env * 0.4
		var wave := body + noise
		var sample := int(clamp(wave, -1.0, 1.0) * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data)

## ---- Ghost Rim (幽灵鼓 - 鼓边) ----
## 短促的"咔"声，金属质感
func _gen_ghost_rim() -> AudioStreamWAV:
	var samples := int(GHOST_DURATION * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var env := exp(-t * 60.0) * 0.3
		# 高频金属 + 极短噪声
		var metal := sin(t * 3500.0 * TWO_PI) * env * 0.5
		metal += sin(t * 5200.0 * TWO_PI) * env * 0.3
		var click := randf_range(-1.0, 1.0) * exp(-t * 100.0) * 0.2
		var wave := metal + click
		var sample := int(clamp(wave, -1.0, 1.0) * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data)

## ---- Bass Note (低音合成器音符) ----
## 方波 + 正弦波混合，带低通滤波包络，经典 Acid/Techno Bass 音色
func _gen_bass_note(freq: float) -> AudioStreamWAV:
	# 根据当前 BPM 计算持续时间，默认半拍
	var duration = BASS_NOTE_BEATS * (60.0 / max(_bpm, 60.0))
	duration = clamp(duration, 0.1, 0.5)
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in range(samples):
		var t := float(i) / float(samples)
		phase += freq / SAMPLE_RATE
		# 振幅包络：快速起音，中速衰减
		var amp = min(1.0, t * 50.0) * exp(-t * 6.0) * 0.7
		# 方波 (基频) + 正弦波 (子低频)
		var square = sign(sin(phase * TWO_PI)) * 0.4
		var sine := sin(phase * TWO_PI) * 0.5
		# 简易低通包络：高次谐波随时间衰减
		var sub := sin(phase * 0.5 * TWO_PI) * 0.1  # 子八度
		var wave = (square + sine + sub) * amp
		# 轻微失真
		wave = clamp(wave * 1.2, -1.0, 1.0)
		var sample := int(wave * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data)

## ---- Pad Chord (环境音垫和弦) ----
## 多个去谐正弦波叠加 + 缓慢的颤音，营造"量化网格"的数字氛围
func _gen_pad_chord(freqs: Array) -> AudioStreamWAV:
	var samples := int(PAD_LOOP_DURATION * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(SAMPLE_RATE)
		var t_norm := float(i) / float(samples)
		var wave := 0.0
		for f_idx in range(freqs.size()):
			var freq: float = freqs[f_idx]
			# 每个声部轻微去谐 (±0.5Hz)，制造"合唱"效果
			var detune := sin(t * (0.3 + f_idx * 0.1)) * 0.5
			# 正弦波 + 轻微锯齿泛音
			wave += sin(t * (freq + detune) * TWO_PI) * 0.2
			wave += sin(t * (freq + detune) * 2.0 * TWO_PI) * 0.05  # 八度泛音
		# 缓慢的颤音 (Tremolo)
		var tremolo := 0.85 + 0.15 * sin(t * 0.5 * TWO_PI)
		wave *= tremolo
		# 淡入淡出包络 (循环友好)
		var fade_in = min(1.0, t_norm * 10.0)
		var fade_out = min(1.0, (1.0 - t_norm) * 10.0)
		wave *= fade_in * fade_out * 0.35
		var sample := int(clamp(wave, -1.0, 1.0) * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var wav := _create_wav(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples
	return wav

# ============================================================
# WAV 创建工具
# ============================================================

func _create_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

# ============================================================
# 公共接口
# ============================================================

## 启动 BGM 合成引擎
func start_bgm(bpm: float = 0.0) -> void:
	if bpm > 0.0:
		_bpm = bpm
	else:
		_bpm = GameManager.current_bpm

	_update_timing()
	_reset_clock()

	# OPT01: 重置和声指挥官状态
	_reset_harmony_conductor()

	# OPT01: 根据当前和弦生成 Bass 和 Pad 采样
	_regenerate_dynamic_bass_sample()
	_regenerate_dynamic_pad_sample()

	# 启动 Pad 循环
	_start_pad_loop()

	_is_playing = true
	bgm_changed.emit("techno_%d" % int(_bpm))
	# OPT01: 广播初始和声上下文
	harmony_context_changed.emit(current_chord_root, current_chord_type, current_chord_notes)

## 停止 BGM
func stop_bgm(fade_out: bool = true) -> void:
	if fade_out:
		var tween := create_tween()
		for layer_name in _layer_config:
			var player: AudioStreamPlayer = _layer_config[layer_name]["player"]
			if player and player.playing:
				tween.parallel().tween_property(player, "volume_db", -80.0, 1.5)
		tween.tween_callback(_stop_all_players)
	else:
		_stop_all_players()

	_is_playing = false

## 暂停 BGM (带闷音效果)
func pause_bgm() -> void:
	_apply_muffle_effect(true)

## 恢复 BGM
func resume_bgm() -> void:
	_apply_muffle_effect(false)

## 设置游戏强度 (0.0 ~ 1.0)
## 影响各音轨层的动态混合：
##   0.0 = 仅 Kick + Pad (菜单/低强度)
##   0.5 = 加入 Hi-Hat + Bass (正常战斗)
##   0.8 = 加入 Snare + Ghost (高强度)
##   1.0 = 全部音轨 + 更硬的 Kick (Boss 战)
func set_intensity(value: float) -> void:
	_intensity = clamp(value, 0.0, 1.0)
	_update_layer_mix()
	intensity_changed.emit(_intensity)

## 获取当前强度
func get_intensity() -> float:
	return _intensity

## 切换指定音轨层的开关
func toggle_layer(layer_name: String, enabled: bool) -> void:
	if _layer_config.has(layer_name):
		_layer_config[layer_name]["enabled"] = enabled
		if not enabled:
			var player: AudioStreamPlayer = _layer_config[layer_name]["player"]
			if player:
				player.stop()
		layer_toggled.emit(layer_name, enabled)

## 设置指定音轨层的音量 (dB)
func set_layer_volume(layer_name: String, volume_db: float) -> void:
	if _layer_config.has(layer_name):
		_layer_config[layer_name]["volume_db"] = volume_db
		var player: AudioStreamPlayer = _layer_config[layer_name]["player"]
		if player:
			player.volume_db = volume_db

## 获取当前 BPM
func get_bgm_bpm() -> float:
	return _bpm

## 获取当前播放状态
func is_playing() -> bool:
	return _is_playing

## 获取当前曲目名称 (兼容旧接口)
func get_current_track() -> String:
	if _is_playing:
		return "techno_%d" % int(_bpm)
	return ""

## 设置 BGM 主音量 (0.0 ~ 1.0)
func set_bgm_volume(volume: float) -> void:
	var bus_idx := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clamp(volume, 0.0, 1.0)))

## 切换 Hi-Hat 节奏型
func set_hihat_pattern(pattern_name: String) -> void:
	match pattern_name:
		"eighth":  # 八分音符 (默认)
			_hihat_pattern = [
				true,  false, true,  false,
				true,  false, true,  false,
				true,  false, true,  false,
				true,  false, true,  false,
			]
		"sixteenth":  # 十六分音符 (高强度)
			_hihat_pattern = [
				true,  true,  true,  true,
				true,  true,  true,  true,
				true,  true,  true,  true,
				true,  true,  true,  true,
			]
		"offbeat":  # 反拍
			_hihat_pattern = [
				false, false, true,  false,
				false, false, true,  false,
				false, false, true,  false,
				false, false, true,  false,
			]
		"shuffle":  # 摇摆
			_hihat_pattern = [
				true,  false, false, true,
				true,  false, false, true,
				true,  false, false, true,
				true,  false, false, true,
			]

## 切换 Ghost 鼓组节奏型
func set_ghost_pattern(pattern_name: String) -> void:
	match pattern_name:
		"default":
			_ghost_pattern = [
				false, false, false, true,
				false, false, false, false,
				false, false, false, true,
				false, true,  false, false,
			]
		"busy":  # 更密集的填充
			_ghost_pattern = [
				false, true,  false, true,
				false, true,  false, false,
				false, true,  false, true,
				false, true,  false, true,
			]
		"minimal":  # 极简
			_ghost_pattern = [
				false, false, false, false,
				false, false, false, true,
				false, false, false, false,
				false, false, false, false,
			]

## 切换 Bass 音型
func set_bass_pattern(pattern_name: String) -> void:
	match pattern_name:
		"default":
			_bass_pattern = [
				0,  -1, -1, -1,
				-1, -1,  2, -1,
				0,  -1, -1, -1,
				-1, -1,  4, -1,
			]
		"driving":  # 驱动型 (更密集)
			_bass_pattern = [
				0,  -1,  0, -1,
				2,  -1,  2, -1,
				0,  -1,  0, -1,
				4,  -1,  3, -1,
			]
		"minimal":  # 极简
			_bass_pattern = [
				0,  -1, -1, -1,
				-1, -1, -1, -1,
				0,  -1, -1, -1,
				-1, -1, -1, -1,
			]
		"walking":  # 行走低音
			_bass_pattern = [
				0,  -1, -1, -1,
				1,  -1, -1, -1,
				2,  -1, -1, -1,
				4,  -1, -1, -1,
			]

## 根据游戏阶段自动配置 BGM
func auto_select_bgm_for_state(state: GameManager.GameState) -> void:
	match state:
		GameManager.GameState.MENU:
			if _is_playing:
				set_intensity(0.15)
				set_hihat_pattern("offbeat")
				set_ghost_pattern("minimal")
				set_bass_pattern("minimal")
			else:
				start_bgm(100.0)
				set_intensity(0.15)
				set_hihat_pattern("offbeat")
				set_ghost_pattern("minimal")
				set_bass_pattern("minimal")
		GameManager.GameState.PLAYING:
			if not _is_playing:
				start_bgm()
			else:
				# 更新 BPM
				_bpm = GameManager.current_bpm
				_update_timing()
			set_intensity(0.5)
			set_hihat_pattern("eighth")
			set_ghost_pattern("default")
			set_bass_pattern("default")
		GameManager.GameState.GAME_OVER:
			set_intensity(0.1)
			set_hihat_pattern("offbeat")
			set_ghost_pattern("minimal")
			set_bass_pattern("minimal")
		GameManager.GameState.PAUSED:
			pause_bgm()

# ============================================================
# 主时钟 — 十六分音符调度器
# ============================================================

func _tick_sixteenth() -> void:
	var step := _current_sixteenth % 16  # 小节内位置 (0-15)
	var beat_in_measure := step / 4       # 当前拍 (0-3)
	var is_downbeat := (step % 4 == 0)    # 是否在拍头

	# ---- Kick: 每拍拍头 (4/4 拍) ----
	if is_downbeat and _layer_config["kick"]["enabled"]:
		var use_hard := (beat_in_measure == 0 and _intensity > 0.7)
		_trigger_sample("kick", "kick_hard" if use_hard else "kick")

	# ---- Snare: 第 2、4 拍 ----
	if is_downbeat and (beat_in_measure == 1 or beat_in_measure == 3):
		if _layer_config["snare"]["enabled"]:
			# 随机选择 snare 或 clap
			var use_clap := (randf() < 0.3 and _intensity > 0.6)
			_trigger_sample("snare", "clap" if use_clap else "snare")

	# ---- Hi-Hat ----
	if step < _hihat_pattern.size() and _hihat_pattern[step]:
		if _layer_config["hihat"]["enabled"]:
			# 偶尔使用 open hi-hat (每 8 步或小节末尾)
			var use_open := (step == 14 and randf() < 0.4)
			_trigger_sample("hihat", "hihat_open" if use_open else "hihat_closed",
				randf_range(0.9, 1.1))

	# ---- Ghost 鼓组 ----
	if step < _ghost_pattern.size() and _ghost_pattern[step]:
		if _layer_config["ghost"]["enabled"]:
			var use_rim := (randf() < 0.4)
			_trigger_sample("ghost", "ghost_rim" if use_rim else "ghost_tap",
				randf_range(0.85, 1.15))

	# ---- Bass ----
	if step < _bass_pattern.size() and _bass_pattern[step] >= 0:
		if _layer_config["bass"]["enabled"]:
			var note_idx: int = _bass_pattern[step]
			# OPT01: 优先使用动态和弦音符采样
			var bass_key := "bass_dynamic_%d" % note_idx
			if _samples.has(bass_key):
				_trigger_sample("bass", bass_key)
			elif note_idx < BASS_NOTES.size():
				_trigger_sample("bass", "bass_%d" % note_idx)

	# ---- 更新计数器 ----
	_current_sixteenth += 1

	if is_downbeat:
		_current_beat += 1
		bgm_beat_synced.emit(_current_beat)

	# OPT05: 发射十六分音符时钟信号，供 AudioEventQueue 使用
	sixteenth_tick.emit(_current_sixteenth)

	if step == 0 and _current_sixteenth > 1:
		_current_measure += 1
		bgm_measure_synced.emit(_current_measure)
		# OPT01: 和声指挥官接管和弦切换，不再使用固定循环
		# 旧逻辑: _update_pad_chord() — 已由 _on_harmony_measure_synced() 替代

# ============================================================
# 采样触发
# ============================================================

func _trigger_sample(layer_name: String, sample_name: String,
		pitch_scale: float = 1.0) -> void:
	var player: AudioStreamPlayer = _layer_config[layer_name]["player"]
	if player == null:
		return

	var stream: AudioStreamWAV = _samples.get(sample_name)
	if stream == null:
		return

	player.stream = stream
	player.pitch_scale = pitch_scale
	player.play()

# ============================================================
# Pad 循环管理
# ============================================================

var _current_pad_index: int = 0

func _start_pad_loop() -> void:
	if not _layer_config["pad"]["enabled"]:
		return
	var player: AudioStreamPlayer = _layer_config["pad"]["player"]
	if player == null:
		return
	# OPT01: 使用动态和弦采样而非固定索引
	var stream: AudioStreamWAV = _samples.get("pad_dynamic")
	if stream == null:
		# 回退到旧的固定采样
		stream = _samples.get("pad_0")
	if stream:
		player.stream = stream
		player.play()

func _update_pad_chord() -> void:
	if not _layer_config["pad"]["enabled"]:
		return
	# 每 4 小节循环切换和弦
	if _current_measure % 4 != 0:
		return
	_current_pad_index = (_current_pad_index + 1) % PAD_CHORDS.size()
	var player: AudioStreamPlayer = _layer_config["pad"]["player"]
	if player == null:
		return
	var stream: AudioStreamWAV = _samples.get("pad_%d" % _current_pad_index)
	if stream:
		# 交叉淡入新和弦
		var tween := create_tween()
		var target_vol: float = _layer_config["pad"]["volume_db"]
		tween.tween_property(player, "volume_db", -40.0, 0.5)
		tween.tween_callback(func():
			player.stream = stream
			player.play()
		)
		tween.tween_property(player, "volume_db", target_vol, 0.5)

# ============================================================
# 动态混合
# ============================================================

## 疲劳等级驱动的BGM动态混音
## 疲劳度越高，音乐越“混乱”：
##   - NONE/MILD: 正常混音
##   - MODERATE: 音调微降，微微失调，加入轻微延迟
##   - SEVERE: 音调明显下降，音量波动，节奏不稳
##   - CRITICAL: 极度失调，闷音效果，节奏崩溃
var _fatigue_mix_timer: float = 0.0
var _fatigue_pitch_offset: float = 0.0
var _fatigue_volume_wobble: float = 0.0

## 根据疲劳等级更新BGM混音参数
func update_fatigue_mix(fatigue_level: int, fatigue_afi: float) -> void:
	_fatigue_mix_timer += 0.016  # 假设60fps

	match fatigue_level:
		MusicData.FatigueLevel.NONE, MusicData.FatigueLevel.MILD:
			# 正常状态：清晰的音乐
			_fatigue_pitch_offset = 0.0
			_fatigue_volume_wobble = 0.0
			_apply_muffle_effect(false)
		MusicData.FatigueLevel.MODERATE:
			# 中度疲劳：轻微失调
			_fatigue_pitch_offset = -0.02 * fatigue_afi
			_fatigue_volume_wobble = sin(_fatigue_mix_timer * 2.0) * 1.0
		MusicData.FatigueLevel.SEVERE:
			# 重度疲劳：明显失调 + 音量波动
			_fatigue_pitch_offset = -0.05 * fatigue_afi
			_fatigue_volume_wobble = sin(_fatigue_mix_timer * 4.0) * 3.0
			# 切换到不稳定的节奏型
			set_hihat_pattern("shuffle")
		MusicData.FatigueLevel.CRITICAL:
			# 临界疲劳：极度失调 + 闷音 + 音量剧烈波动
			_fatigue_pitch_offset = -0.08
			_fatigue_volume_wobble = sin(_fatigue_mix_timer * 6.0) * 5.0
			_apply_muffle_effect(true)
			set_hihat_pattern("shuffle")
			set_ghost_pattern("busy")

	# 应用音调偏移到所有音轨层
	for layer_name in _layer_config:
		var player: AudioStreamPlayer = _layer_config[layer_name]["player"]
		if player:
			player.pitch_scale = 1.0 + _fatigue_pitch_offset
			# 音量波动
			var base_vol: float = _layer_config[layer_name]["volume_db"]
			player.volume_db = base_vol + _fatigue_volume_wobble

## 连接疲劳系统信号
func _connect_fatigue_signals() -> void:
	if FatigueManager and FatigueManager.has_signal("fatigue_level_changed"):
		FatigueManager.fatigue_level_changed.connect(_on_fatigue_level_changed)

func _on_fatigue_level_changed(new_level: MusicData.FatigueLevel) -> void:
	var afi: float = FatigueManager.current_afi if FatigueManager else 0.0
	update_fatigue_mix(new_level, afi)

## 根据 _intensity 值自动调整各层的启用状态和音量
func _update_layer_mix() -> void:
	# Kick: 始终开启，强度影响音量
	_layer_config["kick"]["enabled"] = true
	set_layer_volume("kick", lerp(-12.0, -4.0, _intensity))

	# Pad: 始终开启，低强度时更突出
	_layer_config["pad"]["enabled"] = true
	set_layer_volume("pad", lerp(-12.0, -18.0, _intensity))

	# Hi-Hat: 强度 > 0.2 时开启
	toggle_layer("hihat", _intensity > 0.2)
	if _intensity > 0.2:
		set_layer_volume("hihat", lerp(-18.0, -10.0, _intensity))

	# Bass: 强度 > 0.3 时开启
	toggle_layer("bass", _intensity > 0.3)
	if _intensity > 0.3:
		set_layer_volume("bass", lerp(-14.0, -6.0, _intensity))

	# Snare: 强度 > 0.4 时开启
	toggle_layer("snare", _intensity > 0.4)
	if _intensity > 0.4:
		set_layer_volume("snare", lerp(-12.0, -6.0, _intensity))

	# Ghost: 强度 > 0.5 时开启
	toggle_layer("ghost", _intensity > 0.5)
	if _intensity > 0.5:
		set_layer_volume("ghost", lerp(-20.0, -14.0, _intensity))

	# 高强度时切换更密集的节奏型
	if _intensity > 0.8:
		set_hihat_pattern("sixteenth")
		set_ghost_pattern("busy")
		set_bass_pattern("driving")
	elif _intensity > 0.5:
		set_hihat_pattern("eighth")
		set_ghost_pattern("default")
		set_bass_pattern("default")
	else:
		set_hihat_pattern("offbeat")
		set_ghost_pattern("minimal")
		set_bass_pattern("minimal")

# ============================================================
# 时钟工具
# ============================================================

func _update_timing() -> void:
	_beat_interval = 60.0 / max(_bpm, 30.0)
	_sixteenth_interval = _beat_interval / 4.0

func _reset_clock() -> void:
	_clock_timer = 0.0
	_current_sixteenth = 0
	_current_beat = 0
	_current_measure = 0

func _stop_all_players() -> void:
	for layer_name in _layer_config:
		var player: AudioStreamPlayer = _layer_config[layer_name]["player"]
		if player:
			player.stop()
	_is_playing = false

# ============================================================
# 闷音效果 (暂停时)
# ============================================================

func _apply_muffle_effect(enable: bool) -> void:
	_is_muffled = enable
	var bus_idx := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if bus_idx == -1:
		return

	if enable:
		var has_filter := false
		for i in range(AudioServer.get_bus_effect_count(bus_idx)):
			if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectLowPassFilter:
				has_filter = true
				break
		if not has_filter:
			var filter := AudioEffectLowPassFilter.new()
			filter.cutoff_hz = muffled_cutoff_hz
			AudioServer.add_bus_effect(bus_idx, filter)
		var tween := create_tween()
		tween.tween_method(func(vol: float):
			AudioServer.set_bus_volume_db(bus_idx, vol),
			AudioServer.get_bus_volume_db(bus_idx), -12.0, 0.3)
	else:
		for i in range(AudioServer.get_bus_effect_count(bus_idx) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectLowPassFilter:
				AudioServer.remove_bus_effect(bus_idx, i)
		var tween := create_tween()
		tween.tween_method(func(vol: float):
			AudioServer.set_bus_volume_db(bus_idx, vol),
			AudioServer.get_bus_volume_db(bus_idx), 0.0, 0.3)

# ============================================================
# 外部 BGM 文件播放接口
# ============================================================

## 外部 BGM 播放器
var _external_bgm_player: AudioStreamPlayer = null
var _using_external_bgm: bool = false

## 播放外部 BGM 文件（自动处理淡入淡出）
## track_path: 音频文件路径，如 "res://audio/bgm/bgm_ch1_explore.ogg"
## fade_duration: 淡入淡出时长（秒）
func play_external_bgm(track_path: String, fade_duration: float = 1.0) -> void:
	# 初始化外部播放器
	if _external_bgm_player == null:
		_external_bgm_player = AudioStreamPlayer.new()
		_external_bgm_player.bus = MUSIC_BUS_NAME
		add_child(_external_bgm_player)

	# 加载音频文件
	if not ResourceLoader.exists(track_path):
		push_warning("BGMManager: 外部BGM文件不存在: " + track_path)
		return

	var stream = ResourceLoader.load(track_path)
	if stream == null:
		push_warning("BGMManager: 无法加载外部BGM: " + track_path)
		return

	# 淡出程序化 BGM
	var tween := create_tween()
	var music_bus_idx := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if music_bus_idx >= 0 and _is_playing:
		tween.tween_method(func(vol: float):
			AudioServer.set_bus_volume_db(music_bus_idx, vol),
			AudioServer.get_bus_volume_db(music_bus_idx), -40.0, fade_duration * 0.5)
		tween.tween_callback(func():
			stop_bgm()
			_external_bgm_player.stream = stream
			_external_bgm_player.volume_db = -40.0
			_external_bgm_player.play()
			_using_external_bgm = true
		)
		tween.tween_property(_external_bgm_player, "volume_db", 0.0, fade_duration * 0.5)
		tween.tween_method(func(vol: float):
			AudioServer.set_bus_volume_db(music_bus_idx, vol),
			-40.0, 0.0, 0.1)
	else:
		_external_bgm_player.stream = stream
		_external_bgm_player.volume_db = -40.0
		_external_bgm_player.play()
		_using_external_bgm = true
		tween.tween_property(_external_bgm_player, "volume_db", 0.0, fade_duration)

	bgm_changed.emit(track_path.get_file())

## 停止外部 BGM 并回到程序化 BGM
func stop_external_bgm(fade_duration: float = 1.0) -> void:
	if _external_bgm_player == null or not _using_external_bgm:
		return

	var tween := create_tween()
	tween.tween_property(_external_bgm_player, "volume_db", -40.0, fade_duration)
	tween.tween_callback(func():
		_external_bgm_player.stop()
		_using_external_bgm = false
		# 恢复程序化 BGM
		start_bgm()
	)

# ============================================================
# 信号回调
# ============================================================

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	auto_select_bgm_for_state(new_state)

# ============================================================
# OPT01: 和声指挥官核心逻辑 (Global Dynamic Harmony Conductor)
# ============================================================

## 初始化和声指挥官
func _init_harmony_conductor() -> void:
	# 加载马尔可夫链矩阵 (默认 A 自然小调)
	_markov_matrix = MusicData.MARKOV_MATRIX_A_MINOR
	current_scale = MusicData.SCALE_A_MINOR.duplicate()
	# 初始和弦: Am
	current_chord_root = 9
	current_chord_type = MusicData.ChordType.MINOR
	current_chord_notes = _calculate_chord_notes(current_chord_root, current_chord_type)
	_auto_evolve_countdown = AUTO_EVOLVE_THRESHOLD

## 重置和声指挥官状态 (游戏开始/重启时调用)
func _reset_harmony_conductor() -> void:
	current_chord_root = 9  # A
	current_chord_type = MusicData.ChordType.MINOR
	current_chord_notes = [9, 0, 4]  # Am: A, C, E
	current_scale = MusicData.SCALE_A_MINOR.duplicate()
	_pending_chord = {}
	_auto_evolve_countdown = AUTO_EVOLVE_THRESHOLD
	_markov_matrix = MusicData.MARKOV_MATRIX_A_MINOR

## 响应玩家和弦输入 (由 MusicTheoryEngine.chord_identified 触发)
func _on_player_chord_identified(chord_type: int, root_note: int) -> void:
	# 将和弦切换请求缓存，等待小节边界
	_pending_chord = {
		"root": root_note % 12,
		"type": chord_type,
	}
	# 玩家输入重置自动演进计时
	_auto_evolve_countdown = AUTO_EVOLVE_THRESHOLD
	print("[HarmonyConductor] 玩家和弦缓存: root=%d, type=%d (等待小节同步)" % [root_note % 12, chord_type])

## 小节同步处理 — 和声指挥官的核心调度
func _on_harmony_measure_synced(measure_index: int) -> void:
	if not _is_playing:
		return

	if not _pending_chord.is_empty():
		# 玩家输入的和弦优先 — 立即应用
		_apply_chord_change(_pending_chord["root"], _pending_chord["type"])
		_pending_chord = {}
	else:
		# 自动演进逻辑
		_auto_evolve_countdown -= 1
		if _auto_evolve_countdown <= 0:
			var next_chord := _get_markov_next_chord(current_chord_root)
			_apply_chord_change(next_chord["root"], next_chord["type"])
			# 重置倒计时，但使用略长的间隔避免过于频繁
			_auto_evolve_countdown = AUTO_EVOLVE_THRESHOLD

## 应用和弦切换 — 更新所有声部和全局状态
func _apply_chord_change(root: int, type: int) -> void:
	var old_root := current_chord_root
	current_chord_root = root
	current_chord_type = type
	current_chord_notes = _calculate_chord_notes(root, type)

	# 重新生成 Pad 和 Bass 采样以匹配新和弦
	_regenerate_dynamic_pad_sample()
	_regenerate_dynamic_bass_sample()

	# 交叉淡入新 Pad 采样
	_crossfade_pad_to_dynamic()

	# 广播全局和声上下文变更
	harmony_context_changed.emit(current_chord_root, current_chord_type, current_chord_notes)

	if old_root != root:
		print("[HarmonyConductor] 和弦切换: %s → %s (type=%d)" % [
			_note_name(old_root), _note_name(root), type])

## 计算和弦包含的音高类
func _calculate_chord_notes(root: int, type: int) -> Array[int]:
	var intervals: Array = MusicData.CHORD_INTERVALS.get(type, [0, 4, 7])
	var notes: Array[int] = []
	for interval in intervals:
		notes.append((root + interval) % 12)
	return notes

## 马尔可夫链：根据当前和弦概率性选择下一个和弦
func _get_markov_next_chord(current_root: int) -> Dictionary:
	var transitions = _markov_matrix.get(current_root, {})
	if transitions.is_empty():
		# 如果当前根音不在矩阵中，回到主和弦
		return {"root": current_scale[0], "type": MusicData.ChordType.MINOR}

	var rand := randf()
	var cumulative: float = 0.0
	for next_root in transitions:
		var entry: Dictionary = transitions[next_root]
		cumulative += entry["probability"]
		if rand <= cumulative:
			return {"root": next_root, "type": entry["type"]}

	# 安全回退：返回主和弦
	return {"root": current_scale[0], "type": MusicData.ChordType.MINOR}

# ============================================================
# OPT01: 动态声部采样生成
# ============================================================

## 根据当前和弦重新生成 Pad 采样
func _regenerate_dynamic_pad_sample() -> void:
	var pad_freqs: Array = []
	for note_pc in current_chord_notes:
		# 限制 Pad 最多使用 4 个音 (根三五七)
		if pad_freqs.size() >= 4:
			break
		var freq: float = MusicData.PITCH_CLASS_TO_PAD_FREQ.get(note_pc, 220.0)
		pad_freqs.append(freq)
	_samples["pad_dynamic"] = _gen_pad_chord(pad_freqs)

## 根据当前和弦重新生成 Bass 采样
## Bass 模式使用和弦音符: 索引 0=根音, 1=五音, 2=三音, 3=八度根音, 4=七音(如有)
func _regenerate_dynamic_bass_sample() -> void:
	# 构建 Bass 音符频率表 (基于当前和弦)
	var bass_freqs: Array[float] = []
	# 索引 0: 根音
	bass_freqs.append(MusicData.PITCH_CLASS_TO_BASS_FREQ.get(current_chord_root, 110.0))
	# 索引 1: 五音 (如果和弦有)
	if current_chord_notes.size() >= 3:
		bass_freqs.append(MusicData.PITCH_CLASS_TO_BASS_FREQ.get(current_chord_notes[2], 98.0))
	else:
		bass_freqs.append(bass_freqs[0] * 1.5)  # 纯五度近似
	# 索引 2: 三音
	if current_chord_notes.size() >= 2:
		bass_freqs.append(MusicData.PITCH_CLASS_TO_BASS_FREQ.get(current_chord_notes[1], 82.41))
	else:
		bass_freqs.append(bass_freqs[0])
	# 索引 3: 高八度根音
	bass_freqs.append(bass_freqs[0] * 2.0)
	# 索引 4: 七音 (如果和弦有)
	if current_chord_notes.size() >= 4:
		bass_freqs.append(MusicData.PITCH_CLASS_TO_BASS_FREQ.get(current_chord_notes[3], 110.0))
	else:
		bass_freqs.append(bass_freqs[0])  # 无七音时回退到根音

	# 为每个索引生成采样
	for i in range(bass_freqs.size()):
		_samples["bass_dynamic_%d" % i] = _gen_bass_note(bass_freqs[i])

## 交叉淡入新的 Pad 采样
func _crossfade_pad_to_dynamic() -> void:
	if not _layer_config["pad"]["enabled"]:
		return
	var player: AudioStreamPlayer = _layer_config["pad"]["player"]
	if player == null:
		return
	var stream: AudioStreamWAV = _samples.get("pad_dynamic")
	if stream == null:
		return

	# 交叉淡入淡出
	var tween := create_tween()
	var target_vol: float = _layer_config["pad"]["volume_db"]
	tween.tween_property(player, "volume_db", -40.0, 0.5)
	tween.tween_callback(func():
		player.stream = stream
		player.play()
	)
	tween.tween_property(player, "volume_db", target_vol, 0.5)

# ============================================================
# OPT01: 公共查询 API
# ============================================================

## 供其他系统查询当前和声上下文
func get_current_chord() -> Dictionary:
	return {
		"root": current_chord_root,
		"type": current_chord_type,
		"notes": current_chord_notes,
	}

## 获取当前全局音阶
func get_current_scale() -> Array[int]:
	return current_scale

## 获取和弦中指定度数的音符
## degree: 1=根音, 3=三音, 5=五音, 7=七音
func get_chord_note_for_degree(degree: int) -> int:
	var index := (degree - 1) / 2  # 1→0, 3→1, 5→2, 7→3
	if index < current_chord_notes.size():
		return current_chord_notes[index]
	return current_chord_root

## 音阶锁定：将任意音高吸附到当前音阶最近的音
func quantize_to_scale(pitch_class: int) -> int:
	var min_distance: int = 12
	var closest_note: int = pitch_class
	for scale_note in current_scale:
		var dist := absi((pitch_class - scale_note + 12) % 12)
		if dist > 6:
			dist = 12 - dist
		if dist < min_distance:
			min_distance = dist
			closest_note = scale_note
	return closest_note

## 辅助：音高类转音名
func _note_name(pc: int) -> String:
	const NAMES: Array[String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	if pc >= 0 and pc < 12:
		return NAMES[pc]
	return "?"
