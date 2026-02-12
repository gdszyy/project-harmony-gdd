## audio_manager.gd
## 全局音效管理器 (Autoload)
## 统一管理所有游戏音效的播放，包括敌人音效、玩家法术音效、UI 音效。
## 设计哲学：
##   玩家 = 和谐 (Harmony/Music) — 钢琴、合成器和弦，基于乐理
##   敌人 = 噪音 (Noise/Dissonance) — 白噪音、Bitcrush、电流、故障音
##
## 技术要点：
##   - 使用对象池化的 AudioStreamPlayer / AudioStreamPlayer2D 避免资源浪费
##   - 监听敌人信号 (enemy_damaged, enemy_died) 触发对应音效
##   - 敌人量化移动时播放机械卡顿声
##   - 所有音效通过 SFX 总线输出，与 Music 总线分离
##
## OPT05 扩展：Rez 式输入量化错觉 (Rez-Style Input Quantization)
##   - 集成 AudioEventQueue，将游戏音效自动对齐到十六分音符网格
##   - 视觉效果保持即时响应，仅音频被量化延迟
##   - 支持 FULL / SOFT / OFF 三种量化模式
##   - 参见 Docs/Optimization_Modules/OPT05_RezStyleInputQuantization.md
extends Node

# ============================================================
# 信号
# ============================================================
signal sfx_played(sfx_name: String, position: Vector2)

# ============================================================
# 音频总线配置
# ============================================================
const SFX_BUS_NAME := "SFX"
const ENEMY_BUS_NAME := "EnemySFX"
const PLAYER_BUS_NAME := "PlayerSFX"
const UI_BUS_NAME := "UI"

# ============================================================
# 对象池配置
# ============================================================
## 2D 音效播放器池大小 (用于带位置的音效)
const POOL_SIZE_2D: int = 32
## 全局音效播放器池大小 (用于 UI 等无位置音效)
const POOL_SIZE_GLOBAL: int = 8

# ============================================================
# 音量配置 (线性值, 0.0 ~ 1.0)
# ============================================================
var master_volume: float = 1.0
var sfx_volume: float = 0.8
var enemy_sfx_volume: float = 0.7
var player_sfx_volume: float = 0.9
var ui_volume: float = 0.6

# ============================================================
# 敌人音效配置 — "噪音污染 (Noise Pollution)"
# ============================================================
## 每种敌人类型的音效参数配置
## 音效风格：错误的数据、损坏的音频、数字故障
const ENEMY_SFX_CONFIG: Dictionary = {
	"static": {
		"move_pitch_min": 0.8,
		"move_pitch_max": 1.2,
		"move_volume_db": -18.0,
		"hit_pitch_min": 1.5,
		"hit_pitch_max": 2.5,
		"hit_volume_db": -10.0,
		"die_pitch_min": 0.5,
		"die_pitch_max": 1.0,
		"die_volume_db": -6.0,
		"move_sound": "noise_click",       ## 短促数字噪声
		"hit_sound": "bitcrush_short",     ## 位元破碎
		"die_sound": "glitch_burst_small", ## 小型故障爆裂
	},
	"silence": {
		"move_pitch_min": 0.3,
		"move_pitch_max": 0.5,
		"move_volume_db": -20.0,
		"hit_pitch_min": 0.4,
		"hit_pitch_max": 0.8,
		"hit_volume_db": -8.0,
		"die_pitch_min": 0.2,
		"die_pitch_max": 0.4,
		"die_volume_db": -4.0,
		"move_sound": "low_hum",           ## 低沉嗡嗡声
		"hit_sound": "void_impact",        ## 虚空冲击
		"die_sound": "implosion",          ## 内爆音
	},
	"screech": {
		"move_pitch_min": 1.5,
		"move_pitch_max": 2.5,
		"move_volume_db": -14.0,
		"hit_pitch_min": 2.0,
		"hit_pitch_max": 3.5,
		"hit_volume_db": -8.0,
		"die_pitch_min": 1.0,
		"die_pitch_max": 2.0,
		"die_volume_db": -4.0,
		"move_sound": "feedback_whine",    ## 反馈尖叫
		"hit_sound": "bitcrush_sharp",     ## 尖锐位元破碎
		"die_sound": "feedback_explosion", ## 反馈音爆炸
	},
	"pulse": {
		"move_pitch_min": 0.8,
		"move_pitch_max": 1.0,
		"move_volume_db": -16.0,
		"hit_pitch_min": 1.0,
		"hit_pitch_max": 1.5,
		"hit_volume_db": -8.0,
		"die_pitch_min": 0.6,
		"die_pitch_max": 1.2,
		"die_volume_db": -5.0,
		"move_sound": "pulse_tick",        ## 脉冲滴答
		"hit_sound": "digital_crack",      ## 数字裂纹
		"die_sound": "pulse_overload",     ## 脉冲过载
	},
	"wall": {
		"move_pitch_min": 0.3,
		"move_pitch_max": 0.5,
		"move_volume_db": -12.0,
		"hit_pitch_min": 0.5,
		"hit_pitch_max": 0.8,
		"hit_volume_db": -6.0,
		"die_pitch_min": 0.2,
		"die_pitch_max": 0.5,
		"die_volume_db": -2.0,
		"move_sound": "heavy_grind",       ## 沉重研磨
		"hit_sound": "metal_impact",       ## 金属撞击
		"die_sound": "structure_collapse", ## 结构崩塌
	},
}

# ============================================================
# 玩家法术音效配置 — "和谐之力 (Harmony)"
# ============================================================
const PLAYER_SFX_CONFIG: Dictionary = {
	"note_cast": {
		"base_volume_db": -8.0,
		"pitch_variation": 0.05,
	},
	"chord_cast": {
		"base_volume_db": -6.0,
		"pitch_variation": 0.03,
	},
	"perfect_beat": {
		"base_volume_db": -4.0,
		"pitch_variation": 0.0,
	},
	"progression_resolve": {
		"base_volume_db": -3.0,
		"pitch_variation": 0.0,
	},
}

# ============================================================
# 对象池
# ============================================================
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _pool_2d_index: int = 0
var _pool_global: Array[AudioStreamPlayer] = []
var _pool_global_index: int = 0

# ============================================================
# 音效资源缓存
# ============================================================
## 预生成的程序化音效 (AudioStreamWAV)
var _generated_sounds: Dictionary = {}

# ============================================================
# OPT05: 音效量化队列
# ============================================================
var _event_queue: AudioEventQueue = null

# ============================================================
# 冷却系统 (防止音效过度叠加)
# ============================================================
var _sfx_cooldowns: Dictionary = {}
const MIN_SFX_INTERVAL: float = 0.05  ## 同一音效最小间隔 (秒)
const ENEMY_MOVE_SFX_INTERVAL: float = 0.15  ## 敌人移动音效间隔

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_audio_buses()
	_init_audio_pools()
	_generate_procedural_sounds()
	_setup_event_queue()  # OPT05
	_connect_global_signals()

func _process(delta: float) -> void:
	_update_cooldowns(delta)

# ============================================================
# 音频总线设置
# ============================================================

func _setup_audio_buses() -> void:
	# 确保 SFX 主总线存在
	_ensure_bus_exists(SFX_BUS_NAME, "Master")

	# 创建敌人音效子总线 (挂载在 SFX 下)
	_ensure_bus_exists(ENEMY_BUS_NAME, SFX_BUS_NAME)

	# 创建玩家音效子总线 (挂载在 SFX 下)
	_ensure_bus_exists(PLAYER_BUS_NAME, SFX_BUS_NAME)

	# 创建 UI 音效子总线 (挂载在 SFX 下)
	_ensure_bus_exists(UI_BUS_NAME, SFX_BUS_NAME)

func _ensure_bus_exists(bus_name: String, parent_bus_name: String) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, bus_name)

	# 设置父总线
	var parent_idx := AudioServer.get_bus_index(parent_bus_name)
	if parent_idx >= 0:
		AudioServer.set_bus_send(bus_idx, parent_bus_name)

# ============================================================
# 对象池初始化
# ============================================================

func _init_audio_pools() -> void:
	# 2D 音效播放器池 (带空间位置)
	for i in range(POOL_SIZE_2D):
		var player := AudioStreamPlayer2D.new()
		player.bus = SFX_BUS_NAME
		player.max_distance = 1500.0
		player.attenuation = 1.5
		add_child(player)
		_pool_2d.append(player)

	# 全局音效播放器池 (无空间位置)
	for i in range(POOL_SIZE_GLOBAL):
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS_NAME
		add_child(player)
		_pool_global.append(player)

# ============================================================
# 程序化音效生成
# ============================================================
## 使用 AudioStreamWAV 程序化生成各类音效
## 这些音效在游戏启动时一次性生成，运行时直接使用

func _generate_procedural_sounds() -> void:
	# --- 敌人音效：噪音/故障类 ---
	_generated_sounds["noise_click"] = _gen_noise_click()
	_generated_sounds["bitcrush_short"] = _gen_bitcrush(0.08, 4)
	_generated_sounds["bitcrush_sharp"] = _gen_bitcrush(0.06, 2)
	_generated_sounds["glitch_burst_small"] = _gen_glitch_burst(0.15, 0.6)
	_generated_sounds["glitch_burst_large"] = _gen_glitch_burst(0.3, 1.0)
	_generated_sounds["low_hum"] = _gen_low_hum()
	_generated_sounds["void_impact"] = _gen_void_impact()
	_generated_sounds["implosion"] = _gen_implosion()
	_generated_sounds["feedback_whine"] = _gen_feedback_whine()
	_generated_sounds["feedback_explosion"] = _gen_feedback_explosion()
	_generated_sounds["pulse_tick"] = _gen_pulse_tick()
	_generated_sounds["digital_crack"] = _gen_digital_crack()
	_generated_sounds["pulse_overload"] = _gen_pulse_overload()
	_generated_sounds["heavy_grind"] = _gen_heavy_grind()
	_generated_sounds["metal_impact"] = _gen_metal_impact()
	_generated_sounds["structure_collapse"] = _gen_structure_collapse()

	# --- 玩家音效：和谐/音乐类 ---
	_generated_sounds["cast_chime"] = _gen_cast_chime()
	_generated_sounds["chord_resolve"] = _gen_chord_resolve()
	_generated_sounds["perfect_beat_ring"] = _gen_perfect_beat_ring()
	_generated_sounds["progression_fanfare"] = _gen_progression_fanfare()

	# --- 状态音效：寂静/过载/暴击 ---
	_generated_sounds["note_silenced"] = _gen_note_silenced()
	_generated_sounds["density_overload"] = _gen_density_overload()
	_generated_sounds["crit_hit"] = _gen_crit_hit()
	_generated_sounds["rest_cleanse"] = _gen_rest_cleanse()

	# --- UI 音效 ---
	_generated_sounds["ui_click"] = _gen_ui_click()
	_generated_sounds["ui_hover"] = _gen_ui_hover()
	_generated_sounds["ui_confirm"] = _gen_ui_confirm()
	_generated_sounds["ui_cancel"] = _gen_ui_cancel()
	_generated_sounds["level_up"] = _gen_level_up()

# ============================================================
# 程序化音效生成器 — 敌人噪音类
# ============================================================

## 短促数字噪声点击 (Static 移动)
func _gen_noise_click() -> AudioStreamWAV:
	var samples := 800  # ~18ms @ 44100Hz
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := 1.0 - t  # 快速衰减
		var noise := randf_range(-1.0, 1.0) * envelope
		var sample := int(clamp(noise * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, 44100)

## 位元破碎音效 (受击)
func _gen_bitcrush(duration: float, bit_depth: int) -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var crush_factor := pow(2, bit_depth)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := (1.0 - t) * (1.0 - t)  # 二次衰减
		var raw := sin(t * 800.0 + randf() * 3.0) + randf_range(-0.5, 0.5)
		# 位元破碎：量化到低位深度
		var crushed := roundf(raw * crush_factor) / crush_factor
		var sample := int(clamp(crushed * envelope * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 故障爆裂音效 (死亡)
func _gen_glitch_burst(duration: float, intensity: float) -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := (1.0 - t * t) * intensity
		# 混合多种噪声源
		var noise := randf_range(-1.0, 1.0)
		var square = sign(sin(t * 1200.0 + randf() * 2.0))
		var glitch = noise * 0.6 + square * 0.4
		# 随机静音段 (模拟数据丢失)
		if randf() < t * 0.3:
			glitch = 0.0
		var sample := int(clamp(glitch * envelope * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 低沉嗡嗡声 (Silence 移动)
func _gen_low_hum() -> AudioStreamWAV:
	var sample_rate := 44100
	var duration := 0.15
	var samples := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := sin(t * PI)  # 平滑升降
		var hum := sin(t * 60.0 * TAU) * 0.5 + sin(t * 90.0 * TAU) * 0.3
		hum += randf_range(-0.1, 0.1)  # 轻微噪声
		var sample := int(clamp(hum * envelope * 32767.0 * 0.5, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 虚空冲击 (Silence 受击)
func _gen_void_impact() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.2 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := exp(-t * 8.0)
		# 低频冲击 + 反向噪声
		var impact := sin(t * 40.0 * TAU) * envelope
		impact -= randf_range(0.0, 0.3) * (1.0 - t)
		var sample := int(clamp(impact * 32767.0 * 0.7, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 内爆音 (Silence 死亡)
func _gen_implosion() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.35 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		# 频率从高到低（内爆感）
		var freq = lerp(2000.0, 30.0, t * t)
		var envelope := (1.0 - t) * 0.8
		var wave := sin(t * freq * TAU / sample_rate * float(i)) * envelope
		wave += randf_range(-0.2, 0.2) * (1.0 - t)
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 反馈尖叫 (Screech 移动)
func _gen_feedback_whine() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.1 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := sin(t * PI) * 0.6
		# 高频正弦 + 谐波 (模拟麦克风反馈)
		var freq := 3000.0 + sin(t * 20.0) * 500.0
		var wave := sin(t * freq * TAU / sample_rate * float(i)) * 0.5
		wave += sin(t * freq * 2.0 * TAU / sample_rate * float(i)) * 0.3
		wave *= envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 反馈音爆炸 (Screech 死亡)
func _gen_feedback_explosion() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.25 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := exp(-t * 5.0)
		# 高频噪声 + 下扫频率
		var freq = lerp(4000.0, 200.0, t)
		var wave := sin(t * freq * TAU / sample_rate * float(i)) * 0.4
		wave += randf_range(-1.0, 1.0) * 0.6
		wave *= envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 脉冲滴答 (Pulse 移动)
func _gen_pulse_tick() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.04 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := exp(-t * 20.0)
		# 短促方波脉冲
		var wave = sign(sin(t * 1000.0 * TAU)) * envelope * 0.5
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 数字裂纹 (Pulse 受击)
func _gen_digital_crack() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.1 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := exp(-t * 10.0)
		# 数字噪声 + 方波
		var wave := randf_range(-1.0, 1.0) * 0.5
		wave += sign(sin(t * 500.0)) * 0.5
		wave *= envelope
		# 随机位翻转 (数字故障)
		if randf() < 0.1:
			wave = -wave
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 脉冲过载 (Pulse 死亡)
func _gen_pulse_overload() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.3 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := (1.0 - t) * (1.0 - t)
		# 快速脉冲序列加速到过载
		var pulse_freq = lerp(200.0, 3000.0, t * t)
		var wave = sign(sin(t * pulse_freq * TAU)) * 0.4
		wave += randf_range(-0.3, 0.3) * t  # 逐渐增加噪声
		wave *= envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 沉重研磨 (Wall 移动)
func _gen_heavy_grind() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.12 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := sin(t * PI) * 0.7
		# 低频锯齿波 + 噪声 (研磨感)
		var saw := fmod(t * 80.0, 1.0) * 2.0 - 1.0
		var noise := randf_range(-0.4, 0.4)
		var wave := (saw * 0.6 + noise * 0.4) * envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 金属撞击 (Wall 受击)
func _gen_metal_impact() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.15 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := exp(-t * 12.0)
		# 金属共振 (多频率叠加)
		var wave := sin(t * 800.0 * TAU) * 0.3
		wave += sin(t * 1200.0 * TAU) * 0.2
		wave += sin(t * 2400.0 * TAU) * 0.15
		wave += randf_range(-0.2, 0.2) * envelope
		wave *= envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 结构崩塌 (Wall 死亡)
func _gen_structure_collapse() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.5 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := (1.0 - t * 0.7) * 0.8
		# 低频隆隆声 + 碎裂噪声
		var rumble := sin(t * 30.0 * TAU) * (1.0 - t) * 0.5
		var debris := randf_range(-1.0, 1.0) * t * 0.4
		# 间歇性撞击
		var impacts := 0.0
		if fmod(t * 15.0, 1.0) < 0.1:
			impacts = randf_range(0.3, 0.8) * (1.0 - t)
		var wave := (rumble + debris + impacts) * envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

# ============================================================
# 程序化音效生成器 — 玩家和谐类
# ============================================================

## 施法音效 (清脆的合成器音)
func _gen_cast_chime() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.15 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := exp(-t * 8.0)
		# 纯净正弦波 + 八度泛音
		var wave := sin(t * 880.0 * TAU) * 0.5
		wave += sin(t * 1760.0 * TAU) * 0.2
		wave += sin(t * 2640.0 * TAU) * 0.1
		wave *= envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 和弦解决音效
func _gen_chord_resolve() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.3 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := exp(-t * 4.0) * 0.8
		# C 大三和弦 (C4-E4-G4)
		var wave := sin(t * 523.25 * TAU) * 0.35  # C5
		wave += sin(t * 659.25 * TAU) * 0.3       # E5
		wave += sin(t * 783.99 * TAU) * 0.25      # G5
		wave *= envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 完美卡拍音效 (明亮的铃声)
func _gen_perfect_beat_ring() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.2 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := exp(-t * 6.0)
		# 高频纯音 + 泛音
		var wave := sin(t * 1760.0 * TAU) * 0.4  # A6
		wave += sin(t * 2637.0 * TAU) * 0.25     # E7
		wave += sin(t * 3520.0 * TAU) * 0.15     # A7
		wave *= envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 和弦进行完成音效 (短小号角)
func _gen_progression_fanfare() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.4 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := sin(t * PI) * 0.7
		# 上行琶音感
		var phase := t * 3.0  # 3个音符
		var freq := 440.0
		if phase < 1.0:
			freq = 523.25  # C5
		elif phase < 2.0:
			freq = 659.25  # E5
		else:
			freq = 783.99  # G5
		var wave := sin(t * freq * TAU) * 0.4
		wave += sin(t * freq * 2.0 * TAU) * 0.15
		wave *= envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

# ============================================================
# 程序化音效生成器 — UI 类
# ============================================================

## UI 点击
func _gen_ui_click() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.03 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := exp(-t * 30.0)
		var wave := sin(t * 2000.0 * TAU) * envelope * 0.5
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## UI 悬停
func _gen_ui_hover() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.02 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := exp(-t * 40.0)
		var wave := sin(t * 3000.0 * TAU) * envelope * 0.3
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## UI 确认
func _gen_ui_confirm() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.15 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := exp(-t * 8.0)
		# 上行双音
		var freq = lerp(800.0, 1200.0, t)
		var wave := sin(t * freq * TAU) * envelope * 0.5
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## UI 取消
func _gen_ui_cancel() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.12 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := exp(-t * 10.0)
		# 下行音
		var freq = lerp(1000.0, 400.0, t)
		var wave := sin(t * freq * TAU) * envelope * 0.4
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 升级音效
func _gen_level_up() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.5 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := sin(t * PI) * 0.6
		# 上行琶音 C-E-G-C
		var freq := 523.25  # C5
		var phase := t * 4.0
		if phase < 1.0:
			freq = 523.25  # C5
		elif phase < 2.0:
			freq = 659.25  # E5
		elif phase < 3.0:
			freq = 783.99  # G5
		else:
			freq = 1046.50 # C6
		var wave := sin(t * freq * TAU) * 0.35
		wave += sin(t * freq * 2.0 * TAU) * 0.15
		wave *= envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

# ============================================================
# 程序化音效生成器 — 状态反馈类
# ============================================================

## 单音寂静音效（低沉的“喔”声 + 消音）
func _gen_note_silenced() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.25 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := exp(-t * 6.0) * 0.5
		# 低沉下行音 + 微小噪声
		var freq = lerp(300.0, 100.0, t)
		var wave := sin(t * freq * TAU) * 0.6
		wave += randf_range(-0.1, 0.1) * (1.0 - t)  # 轻微噪声
		wave *= envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 密度过载音效（电流干扰 + 警告嵼嵼声）
func _gen_density_overload() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.3 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := sin(t * PI) * 0.6
		# 快速振荡的警告音
		var wave := sin(t * 600.0 * TAU) * 0.3
		wave += sin(t * 900.0 * TAU) * 0.2
		# 电流干扰效果
		if fmod(t * 20.0, 1.0) < 0.5:
			wave += randf_range(-0.3, 0.3)
		wave *= envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 暴击音效（布鲁斯调式专用：明亮的金属撞击 + 上行音阶）
func _gen_crit_hit() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.2 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := exp(-t * 5.0) * 0.8
		# 上行音阶 + 泡音
		var freq = lerp(800.0, 2000.0, t * 0.5)
		var wave := sin(t * freq * TAU) * 0.4
		wave += sin(t * freq * 1.5 * TAU) * 0.2  # 泡音
		wave += sin(t * freq * 2.0 * TAU) * 0.15
		wave *= envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

## 休止符清洗音效（柔和的“叮”声 + 上行纯音）
func _gen_rest_cleanse() -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(0.35 * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var envelope := sin(t * PI) * 0.5
		# 柔和上行纯音
		var freq = lerp(440.0, 880.0, t)
		var wave := sin(t * freq * TAU) * 0.4
		wave += sin(t * freq * 2.0 * TAU) * 0.1  # 轻微泡音
		wave *= envelope
		var sample := int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _create_wav(data, sample_rate)

# ============================================================
# WAV 创建工具
# ============================================================

func _create_wav(data: PackedByteArray, sample_rate: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

# ============================================================
# 全局信号连接
# ============================================================

func _connect_global_signals() -> void:
	# 连接 GameManager 信号
	if GameManager.has_signal("level_up"):
		GameManager.level_up.connect(_on_level_up)
	if GameManager.has_signal("player_died"):
		GameManager.player_died.connect(_on_player_died)

	# 连接 SpellcraftSystem 信号 (如果存在)
	if SpellcraftSystem and SpellcraftSystem.has_signal("spell_cast"):
		SpellcraftSystem.spell_cast.connect(_on_spell_cast)
	if SpellcraftSystem and SpellcraftSystem.has_signal("chord_cast"):
		SpellcraftSystem.chord_cast.connect(_on_chord_cast)
	# 连接状态反馈信号
	if SpellcraftSystem and SpellcraftSystem.has_signal("spell_blocked_by_silence"):
		SpellcraftSystem.spell_blocked_by_silence.connect(_on_spell_blocked_by_silence)
	if SpellcraftSystem and SpellcraftSystem.has_signal("accuracy_penalized"):
		SpellcraftSystem.accuracy_penalized.connect(_on_accuracy_penalized)

# ============================================================
# 公共接口 — 敌人音效
# ============================================================

## 播放敌人受击音效
## 由敌人的 enemy_damaged 信号触发
func play_enemy_hit_sfx(enemy_type: String, position: Vector2, damage_amount: float) -> void:
	var config: Dictionary = ENEMY_SFX_CONFIG.get(enemy_type, ENEMY_SFX_CONFIG["static"])
	var sound_name: String = config.get("hit_sound", "bitcrush_short")

	if not _check_cooldown(sound_name + "_hit"):
		return

	var pitch := randf_range(config.get("hit_pitch_min", 1.0), config.get("hit_pitch_max", 2.0))
	var volume_db: float = config.get("hit_volume_db", -10.0)

	# 高伤害时音量更大、音调更低
	if damage_amount > 30.0:
		volume_db += 3.0
		pitch *= 0.8

	_play_2d_sound(sound_name, position, volume_db, pitch, ENEMY_BUS_NAME)

## 播放敌人死亡音效
## 由敌人的 enemy_died 信号触发
func play_enemy_death_sfx(enemy_type: String, position: Vector2) -> void:
	var config: Dictionary = ENEMY_SFX_CONFIG.get(enemy_type, ENEMY_SFX_CONFIG["static"])
	var sound_name: String = config.get("die_sound", "glitch_burst_small")

	var pitch := randf_range(config.get("die_pitch_min", 0.5), config.get("die_pitch_max", 1.0))
	var volume_db: float = config.get("die_volume_db", -6.0)

	_play_2d_sound(sound_name, position, volume_db, pitch, ENEMY_BUS_NAME)

## 播放敌人移动音效 (量化步进时触发)
## 由敌人的 _quantize_timer 触发
func play_enemy_move_sfx(enemy_type: String, position: Vector2) -> void:
	var config: Dictionary = ENEMY_SFX_CONFIG.get(enemy_type, ENEMY_SFX_CONFIG["static"])
	var sound_name: String = config.get("move_sound", "noise_click")

	if not _check_cooldown(sound_name + "_move", ENEMY_MOVE_SFX_INTERVAL):
		return

	var pitch := randf_range(config.get("move_pitch_min", 0.8), config.get("move_pitch_max", 1.2))
	var volume_db: float = config.get("move_volume_db", -18.0)

	_play_2d_sound(sound_name, position, volume_db, pitch, ENEMY_BUS_NAME)

## 播放敌人眩晕音效
func play_enemy_stun_sfx(position: Vector2) -> void:
	_play_2d_sound("digital_crack", position, -8.0, randf_range(0.6, 0.9), ENEMY_BUS_NAME)

# ============================================================
# 公共接口 — 玩家音效
# ============================================================

## 播放法术施放音效
func play_spell_cast_sfx(position: Vector2, is_perfect_beat: bool = false) -> void:
	if is_perfect_beat:
		_play_2d_sound("perfect_beat_ring", position, -4.0, 1.0, PLAYER_BUS_NAME)
	else:
		_play_2d_sound("cast_chime", position, -8.0,
			randf_range(0.95, 1.05), PLAYER_BUS_NAME)

## 播放和弦施放音效
## 增强版：支持多音符同时播放，根据和弦类型生成不同音色
func play_chord_cast_sfx(position: Vector2, chord_data: Dictionary = {}) -> void:
	var notes: Array = chord_data.get("notes", [])
	var timbre: int = chord_data.get("timbre", MusicData.TimbreType.NONE)
	var spell_form = chord_data.get("spell_form", -1)

	# 如果有具体音符数据，使用 NoteSynthesizer 生成和弦音效
	if notes.size() >= 2:
		var synth := NoteSynthesizer.new()
		var chord_wav := synth.generate_chord(notes, timbre, 4, 0.5, 0.7)
		if chord_wav:
			var player := _get_pooled_2d()
			if player:
				player.stream = chord_wav
				player.global_position = position
				player.volume_db = -5.0
				player.pitch_scale = 1.0
				player.bus = PLAYER_BUS_NAME
				player.play()
				sfx_played.emit("chord_synth", position)

	# 根据法术形态播放额外的法术音效
	_play_spell_form_sfx(spell_form, position)

	# 始终播放基础和弦解决音效
	_play_2d_sound("chord_resolve", position, -6.0, 1.0, PLAYER_BUS_NAME)

## 根据法术形态播放对应的特殊音效
func _play_spell_form_sfx(spell_form: int, position: Vector2) -> void:
	if spell_form < 0:
		return
	match spell_form:
		MusicData.SpellForm.EXPLOSIVE:
			# 爆炸：低频冲击
			_play_2d_sound("void_impact", position, -4.0, 0.7, PLAYER_BUS_NAME)
		MusicData.SpellForm.SHOCKWAVE:
			# 冲击波：重低音扩散
			_play_2d_sound("structure_collapse", position, -5.0, 0.5, PLAYER_BUS_NAME)
		MusicData.SpellForm.DIVINE_STRIKE:
			# 天降打击：金属撞击 + 高音铃声
			_play_2d_sound("metal_impact", position, -3.0, 1.2, PLAYER_BUS_NAME)
			_play_2d_sound("perfect_beat_ring", position, -6.0, 0.8, PLAYER_BUS_NAME)
		MusicData.SpellForm.SHIELD_HEAL:
			# 护盾/治疗：柔和的清洗音
			_play_2d_sound("rest_cleanse", position, -4.0, 1.2, PLAYER_BUS_NAME)
		MusicData.SpellForm.FIELD:
			# 法阵：持续的低频嵌套音
			_play_2d_sound("low_hum", position, -6.0, 0.6, PLAYER_BUS_NAME)
		MusicData.SpellForm.SUMMON:
			# 召唤：神秘的铃声
			_play_2d_sound("cast_chime", position, -4.0, 0.7, PLAYER_BUS_NAME)
		MusicData.SpellForm.ANNIHILATION_RAY:
			# 湮灭射线：尖锐的能量释放
			_play_2d_sound("feedback_explosion", position, -3.0, 1.5, PLAYER_BUS_NAME)
		MusicData.SpellForm.FINALE:
			# 终焉乐章：发射全部音效的叠加
			_play_2d_sound("progression_fanfare", position, -2.0, 1.0, PLAYER_BUS_NAME)
			_play_2d_sound("structure_collapse", position, -3.0, 0.4, PLAYER_BUS_NAME)

## 播放和弦进行完成音效
func play_progression_resolve_sfx() -> void:
	_play_global_sound("progression_fanfare", -3.0, 1.0, PLAYER_BUS_NAME)

## 播放玩家受伤音效
func play_player_hit_sfx() -> void:
	_play_global_sound("bitcrush_short", -6.0, randf_range(0.7, 0.9), PLAYER_BUS_NAME)

# ============================================================
# 公共接口 — UI 音效
# ============================================================

## 播放 UI 点击音效
func play_ui_click() -> void:
	_play_global_sound("ui_click", -10.0, 1.0, UI_BUS_NAME)

## 播放 UI 悬停音效
func play_ui_hover() -> void:
	if not _check_cooldown("ui_hover", 0.1):
		return
	_play_global_sound("ui_hover", -14.0, 1.0, UI_BUS_NAME)

## 播放 UI 确认音效
func play_ui_confirm() -> void:
	_play_global_sound("ui_confirm", -8.0, 1.0, UI_BUS_NAME)

## 播放 UI 取消音效
func play_ui_cancel() -> void:
	_play_global_sound("ui_cancel", -10.0, 1.0, UI_BUS_NAME)

## 播放升级音效
func play_level_up_sfx() -> void:
	_play_global_sound("level_up", -4.0, 1.0, UI_BUS_NAME)

# ============================================================
# 公共接口 — 状态反馈音效
# ============================================================

## 播放单音寂静音效
func play_note_silenced_sfx() -> void:
	if not _check_cooldown("note_silenced", 0.3):
		return
	_play_global_sound("note_silenced", -8.0, randf_range(0.8, 1.2), PLAYER_BUS_NAME)

## 播放密度过载音效
func play_density_overload_sfx() -> void:
	if not _check_cooldown("density_overload", 1.0):
		return
	_play_global_sound("density_overload", -6.0, 1.0, PLAYER_BUS_NAME)

## 播放暴击音效（布鲁斯调式）
func play_crit_sfx(position: Vector2) -> void:
	_play_2d_sound("crit_hit", position, -4.0, randf_range(0.9, 1.1), PLAYER_BUS_NAME)

## 播放休止符清洗音效
func play_rest_cleanse_sfx() -> void:
	if not _check_cooldown("rest_cleanse", 0.5):
		return
	_play_global_sound("rest_cleanse", -6.0, 1.0, PLAYER_BUS_NAME)

# ============================================================
# 公共接口 — 注册敌人信号
# ============================================================

## 注册一个敌人实例的信号到音效系统
## 应在敌人 _ready() 时调用
func register_enemy(enemy: Node, enemy_type_name: String) -> void:
	if enemy.has_signal("enemy_damaged"):
		if not enemy.enemy_damaged.is_connected(_on_enemy_damaged):
			enemy.enemy_damaged.connect(
				_on_enemy_damaged.bind(enemy, enemy_type_name)
			)
	if enemy.has_signal("enemy_died"):
		if not enemy.enemy_died.is_connected(_on_enemy_died):
			enemy.enemy_died.connect(
				_on_enemy_died.bind(enemy_type_name)
			)
	if enemy.has_signal("enemy_stunned"):
		if not enemy.enemy_stunned.is_connected(_on_enemy_stunned):
			enemy.enemy_stunned.connect(
				_on_enemy_stunned.bind(enemy)
			)

## 注销敌人信号 (敌人销毁前调用，防止悬空引用)
func unregister_enemy(enemy: Node) -> void:
	if enemy.has_signal("enemy_damaged"):
		if enemy.enemy_damaged.is_connected(_on_enemy_damaged):
			enemy.enemy_damaged.disconnect(_on_enemy_damaged)
	if enemy.has_signal("enemy_died"):
		if enemy.enemy_died.is_connected(_on_enemy_died):
			enemy.enemy_died.disconnect(_on_enemy_died)
	if enemy.has_signal("enemy_stunned"):
		if enemy.enemy_stunned.is_connected(_on_enemy_stunned):
			enemy.enemy_stunned.disconnect(_on_enemy_stunned)

# ============================================================
# 信号回调
# ============================================================

func _on_enemy_damaged(current_hp: float, max_hp: float, damage_amount: float,
		enemy: Node, enemy_type_name: String) -> void:
	if is_instance_valid(enemy):
		play_enemy_hit_sfx(enemy_type_name, enemy.global_position, damage_amount)

func _on_enemy_died(position: Vector2, xp_value: int, enemy_type: String,
		_bound_type_name: String) -> void:
	play_enemy_death_sfx(enemy_type, position)

func _on_enemy_stunned(duration: float, enemy: Node) -> void:
	if is_instance_valid(enemy):
		play_enemy_stun_sfx(enemy.global_position)


func _on_level_up(_new_level: int) -> void:
	play_level_up_sfx()

func _on_player_died() -> void:
	# 播放游戏结束音效
	_play_global_sound("structure_collapse", -2.0, 0.5, SFX_BUS_NAME)

func _on_spell_cast(spell_data: Dictionary) -> void:
	var is_perfect: bool = spell_data.get("is_perfect_beat", false)
	var pos: Vector2 = spell_data.get("position", Vector2.ZERO)
	play_spell_cast_sfx(pos, is_perfect)
	# 布鲁斯暴击音效
	if spell_data.get("is_crit", false):
		play_crit_sfx(pos)

func _on_chord_cast(chord_data: Dictionary) -> void:
	var pos: Vector2 = chord_data.get("position", Vector2.ZERO)
	play_chord_cast_sfx(pos, chord_data)

func _on_spell_blocked_by_silence(_note: int) -> void:
	play_note_silenced_sfx()

func _on_accuracy_penalized(_penalty: float) -> void:
	play_density_overload_sfx()

# ============================================================
# 内部播放函数
# ============================================================

# ============================================================
# OPT05: 量化队列初始化
# ============================================================

func _setup_event_queue() -> void:
	_event_queue = AudioEventQueue.new()
	_event_queue.name = "AudioEventQueue"
	_event_queue.set_audio_manager(self)
	add_child(_event_queue)

# ============================================================
# OPT05: 量化播放公共接口
# ============================================================

## 通过量化队列播放 2D 空间化音效（音频对齐到十六分音符网格）
## 视觉效果应在调用此方法之前或同时触发，保持即时响应
func play_2d_sound_quantized(sound_name: String, position: Vector2,
		volume_db: float, pitch: float, bus: String,
		source_type: AudioEvent.SourceType = AudioEvent.SourceType.OTHER) -> void:
	var event := AudioEvent.new()
	event.sound_id = sound_name
	event.position = position
	event.volume_db = volume_db
	event.pitch = pitch
	event.is_spatial = true
	event.bus_name = bus
	event.source_type = source_type
	event.timestamp_ms = Time.get_ticks_msec()

	if _event_queue:
		_event_queue.enqueue(event)
	else:
		# 回退：如果队列不可用，直接播放
		play_sound_immediate_2d(sound_name, position, volume_db, pitch, bus)

## 通过量化队列播放全局音效（音频对齐到十六分音符网格）
func play_global_sound_quantized(sound_name: String,
		volume_db: float, pitch: float, bus: String,
		source_type: AudioEvent.SourceType = AudioEvent.SourceType.OTHER) -> void:
	var event := AudioEvent.new()
	event.sound_id = sound_name
	event.volume_db = volume_db
	event.pitch = pitch
	event.is_spatial = false
	event.bus_name = bus
	event.source_type = source_type
	event.timestamp_ms = Time.get_ticks_msec()

	if _event_queue:
		_event_queue.enqueue(event)
	else:
		play_sound_immediate_global(sound_name, volume_db, pitch, bus)

## 设置量化模式
## 可通过设置菜单调用：FULL（默认）、SOFT（高手）、OFF（无障碍）
func set_quantize_mode(mode: AudioEventQueue.QuantizeMode) -> void:
	if _event_queue:
		_event_queue.set_quantize_mode(mode)

## 获取当前量化模式
func get_quantize_mode() -> AudioEventQueue.QuantizeMode:
	if _event_queue:
		return _event_queue.quantize_mode
	return AudioEventQueue.QuantizeMode.OFF

## 获取量化系统统计信息（调试用）
func get_quantize_stats() -> Dictionary:
	if _event_queue:
		return _event_queue.get_stats()
	return {}

# ============================================================
# OPT05: 即时播放接口（供 AudioEventQueue 回调使用）
# ============================================================

## 即时播放 2D 空间化音效（不经过量化队列）
func play_sound_immediate_2d(sound_name: String, position: Vector2,
		volume_db: float, pitch: float, bus: String) -> void:
	var stream: AudioStreamWAV = _generated_sounds.get(sound_name)
	if stream == null:
		return

	var player := _get_pooled_2d()
	if player == null:
		return

	player.stream = stream
	player.global_position = position
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.bus = bus
	player.play()

	sfx_played.emit(sound_name, position)

## 即时播放全局音效（不经过量化队列）
func play_sound_immediate_global(sound_name: String,
		volume_db: float, pitch: float, bus: String) -> void:
	var stream: AudioStreamWAV = _generated_sounds.get(sound_name)
	if stream == null:
		return

	var player := _get_pooled_global()
	if player == null:
		return

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.bus = bus
	player.play()

	sfx_played.emit(sound_name, Vector2.ZERO)

# ============================================================
# 内部播放函数（保留原有接口，内部改为走量化路径）
# ============================================================

func _play_2d_sound(sound_name: String, position: Vector2,
		volume_db: float, pitch: float, bus: String) -> void:
	# OPT05: 法术和敌人音效走量化路径
	play_2d_sound_quantized(sound_name, position, volume_db, pitch, bus)

func _play_global_sound(sound_name: String, volume_db: float,
		pitch: float, bus: String) -> void:
	# OPT05: 全局音效走量化路径
	play_global_sound_quantized(sound_name, volume_db, pitch, bus)

# ============================================================
# 对象池获取
# ============================================================

func _get_pooled_2d() -> AudioStreamPlayer2D:
	for i in range(POOL_SIZE_2D):
		var idx := (_pool_2d_index + i) % POOL_SIZE_2D
		if not _pool_2d[idx].playing:
			_pool_2d_index = (idx + 1) % POOL_SIZE_2D
			return _pool_2d[idx]
	# 池满，覆盖最旧的
	_pool_2d_index = (_pool_2d_index + 1) % POOL_SIZE_2D
	return _pool_2d[_pool_2d_index]

func _get_pooled_global() -> AudioStreamPlayer:
	for i in range(POOL_SIZE_GLOBAL):
		var idx := (_pool_global_index + i) % POOL_SIZE_GLOBAL
		if not _pool_global[idx].playing:
			_pool_global_index = (idx + 1) % POOL_SIZE_GLOBAL
			return _pool_global[idx]
	_pool_global_index = (_pool_global_index + 1) % POOL_SIZE_GLOBAL
	return _pool_global[_pool_global_index]

# ============================================================
# 冷却系统
# ============================================================

func _check_cooldown(key: String, interval: float = MIN_SFX_INTERVAL) -> bool:
	var current_time := Time.get_ticks_msec() / 1000.0
	var last_time: float = _sfx_cooldowns.get(key, 0.0)
	if current_time - last_time < interval:
		return false
	_sfx_cooldowns[key] = current_time
	return true

func _update_cooldowns(_delta: float) -> void:
	# 定期清理过期的冷却记录 (每 5 秒)
	if Engine.get_process_frames() % 300 == 0:
		var current_time := Time.get_ticks_msec() / 1000.0
		var keys_to_remove: Array[String] = []
		for key in _sfx_cooldowns:
			if current_time - _sfx_cooldowns[key] > 5.0:
				keys_to_remove.append(key)
		for key in keys_to_remove:
			_sfx_cooldowns.erase(key)

# ============================================================
# 音量控制接口
# ============================================================

## 设置 SFX 主音量 (0.0 ~ 1.0)
func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	var bus_idx := AudioServer.get_bus_index(SFX_BUS_NAME)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(sfx_volume))

## 设置敌人音效音量 (0.0 ~ 1.0)
func set_enemy_sfx_volume(volume: float) -> void:
	enemy_sfx_volume = clamp(volume, 0.0, 1.0)
	var bus_idx := AudioServer.get_bus_index(ENEMY_BUS_NAME)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(enemy_sfx_volume))

## 设置玩家音效音量 (0.0 ~ 1.0)
func set_player_sfx_volume(volume: float) -> void:
	player_sfx_volume = clamp(volume, 0.0, 1.0)
	var bus_idx := AudioServer.get_bus_index(PLAYER_BUS_NAME)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(player_sfx_volume))

## 设置 UI 音效音量 (0.0 ~ 1.0)
func set_ui_volume(volume: float) -> void:
	ui_volume = clamp(volume, 0.0, 1.0)
	var bus_idx := AudioServer.get_bus_index(UI_BUS_NAME)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(ui_volume))
