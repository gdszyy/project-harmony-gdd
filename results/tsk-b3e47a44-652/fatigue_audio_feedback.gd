## fatigue_audio_feedback.gd
## 疲劳等级音效反馈管理器
##
## 当疲劳等级发生变化时，播放对应的音效反馈，
## 使玩家能通过听觉感知疲劳状态变化。
##
## 音效设计：
##   - NONE → MILD:    轻微的低频嗡鸣，提示疲劳开始积累
##   - MILD → MODERATE: 中等强度的警告音，音调略高
##   - MODERATE → SEVERE: 急促的警报音，带有失真效果
##   - SEVERE → CRITICAL: 强烈的危险警报，心跳般的低频脉冲
##   - 任何等级降低:     清脆的解除音效，表示疲劳缓解
##
## 用法：
##   作为 Autoload 或挂载到 CanvasLayer 上
##   自动连接 FatigueManager.fatigue_level_changed 信号
extends Node

# ============================================================
# 信号
# ============================================================
signal fatigue_sfx_played(level: int, is_increase: bool)

# ============================================================
# 配置
# ============================================================

## 音效文件路径映射
## 使用现有的音效资源，通过 pitch_scale 和 volume 差异化
const SFX_PATHS := {
	"fatigue_increase": "res://audio/sfx/player/silence_punish.ogg",
	"fatigue_decrease": "res://audio/sfx/player/rest_cleanse.ogg",
	"fatigue_critical": "res://audio/sfx/player/density_overload.ogg",
	"fatigue_warning": "res://audio/sfx/player/player_hit.ogg",
}

## 各等级的音效参数
const LEVEL_SFX_CONFIG := {
	# MusicData.FatigueLevel.MILD = 1
	1: {
		"sfx": "fatigue_increase",
		"pitch_scale": 1.2,
		"volume_db": -12.0,
		"description": "轻微疲劳提示",
	},
	# MusicData.FatigueLevel.MODERATE = 2
	2: {
		"sfx": "fatigue_increase",
		"pitch_scale": 1.0,
		"volume_db": -8.0,
		"description": "中等疲劳警告",
	},
	# MusicData.FatigueLevel.SEVERE = 3
	3: {
		"sfx": "fatigue_warning",
		"pitch_scale": 0.8,
		"volume_db": -4.0,
		"description": "严重疲劳警报",
	},
	# MusicData.FatigueLevel.CRITICAL = 4
	4: {
		"sfx": "fatigue_critical",
		"pitch_scale": 0.6,
		"volume_db": -2.0,
		"description": "危急疲劳危险警报",
	},
}

## 疲劳缓解音效参数
const DECREASE_SFX_CONFIG := {
	"sfx": "fatigue_decrease",
	"pitch_scale": 1.3,
	"volume_db": -6.0,
	"description": "疲劳缓解",
}

## 音效冷却时间（秒），防止频繁触发
const SFX_COOLDOWN := 0.5

## 危急等级心跳脉冲间隔（秒）
const CRITICAL_PULSE_INTERVAL := 2.0

# ============================================================
# 状态
# ============================================================
var _previous_level: int = 0  # MusicData.FatigueLevel.NONE
var _sfx_cooldown_timer: float = 0.0
var _critical_pulse_timer: float = 0.0
var _is_critical: bool = false

## 音效播放器池
var _audio_players: Array[AudioStreamPlayer] = []
var _player_index: int = 0
const AUDIO_POOL_SIZE := 4

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 创建音频播放器池
	for i in range(AUDIO_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "FatigueSFX_%d" % i
		player.bus = "SFX"  # 使用 SFX 音频总线
		add_child(player)
		_audio_players.append(player)

	# 延迟连接信号
	call_deferred("_connect_signals")

func _process(delta: float) -> void:
	# 冷却计时
	if _sfx_cooldown_timer > 0:
		_sfx_cooldown_timer -= delta

	# 危急等级心跳脉冲
	if _is_critical:
		_critical_pulse_timer -= delta
		if _critical_pulse_timer <= 0:
			_critical_pulse_timer = CRITICAL_PULSE_INTERVAL
			_play_critical_pulse()

# ============================================================
# 信号连接
# ============================================================

func _connect_signals() -> void:
	var fm := get_node_or_null("/root/FatigueManager")
	if fm:
		if fm.has_signal("fatigue_level_changed"):
			if not fm.fatigue_level_changed.is_connected(_on_fatigue_level_changed):
				fm.fatigue_level_changed.connect(_on_fatigue_level_changed)
		# 也监听 AFI 变化以实现更细粒度的音效反馈
		if fm.has_signal("afi_changed"):
			if not fm.afi_changed.is_connected(_on_afi_changed):
				fm.afi_changed.connect(_on_afi_changed)

# ============================================================
# 信号回调
# ============================================================

func _on_fatigue_level_changed(new_level) -> void:
	# new_level 可能是 MusicData.FatigueLevel 枚举值
	var level_int: int = int(new_level)

	if _sfx_cooldown_timer > 0:
		_previous_level = level_int
		return

	var is_increase: bool = level_int > _previous_level

	if is_increase:
		# 疲劳等级上升
		_play_fatigue_increase_sfx(level_int)
	elif level_int < _previous_level:
		# 疲劳等级下降
		_play_fatigue_decrease_sfx(level_int)

	# 更新危急状态
	_is_critical = (level_int >= 4)  # CRITICAL
	if _is_critical:
		_critical_pulse_timer = CRITICAL_PULSE_INTERVAL

	_previous_level = level_int
	_sfx_cooldown_timer = SFX_COOLDOWN
	fatigue_sfx_played.emit(level_int, is_increase)

func _on_afi_changed(afi_value: float, fatigue_tier: int) -> void:
	# 可用于更细粒度的音效反馈
	# 例如：AFI 接近阈值时播放微弱的预警音
	pass

# ============================================================
# 音效播放
# ============================================================

func _play_fatigue_increase_sfx(level: int) -> void:
	var config: Dictionary = LEVEL_SFX_CONFIG.get(level, {})
	if config.is_empty():
		return

	var sfx_key: String = config.get("sfx", "fatigue_increase")
	var sfx_path: String = SFX_PATHS.get(sfx_key, "")
	if sfx_path.is_empty():
		return

	var pitch: float = config.get("pitch_scale", 1.0)
	var volume: float = config.get("volume_db", -6.0)
	_play_sfx(sfx_path, pitch, volume)

func _play_fatigue_decrease_sfx(_level: int) -> void:
	var sfx_path: String = SFX_PATHS.get(DECREASE_SFX_CONFIG["sfx"], "")
	if sfx_path.is_empty():
		return

	var pitch: float = DECREASE_SFX_CONFIG.get("pitch_scale", 1.3)
	var volume: float = DECREASE_SFX_CONFIG.get("volume_db", -6.0)
	_play_sfx(sfx_path, pitch, volume)

func _play_critical_pulse() -> void:
	# 危急等级的心跳脉冲音效
	var sfx_path: String = SFX_PATHS.get("fatigue_critical", "")
	if sfx_path.is_empty():
		return
	_play_sfx(sfx_path, 0.5, -8.0)

func _play_sfx(path: String, pitch_scale: float = 1.0, volume_db: float = -6.0) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return

	# Round-robin 分配播放器
	var player := _audio_players[_player_index]
	_player_index = (_player_index + 1) % AUDIO_POOL_SIZE

	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.play()

# ============================================================
# 公共接口
# ============================================================

## 手动触发疲劳音效（供外部调用）
func play_fatigue_sfx(level: int, is_increase: bool = true) -> void:
	if is_increase:
		_play_fatigue_increase_sfx(level)
	else:
		_play_fatigue_decrease_sfx(level)

## 重置状态
func reset() -> void:
	_previous_level = 0
	_sfx_cooldown_timer = 0.0
	_critical_pulse_timer = 0.0
	_is_critical = false
