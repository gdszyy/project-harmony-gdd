## bgm_manager.gd
## BGM 管理器 (Autoload)
## 负责背景音乐的加载、播放、循环、BPM 同步和场景切换。
##
## 音乐风格建议 (基于 GDD 与美术指导)：
##   推荐类型：Minimal Techno / Glitch Techno
##   理由：
##     1. 功能性：4/4 拍稳定 Kick 天然适合作为玩家的节拍器
##     2. 美学性：机械感、合成器音色与故障艺术世界观完美契合
##     3. 技术性：Kick 能量集中在 20-200Hz，适合频谱分析驱动视觉
##
## 避免的类型：
##   - 自由爵士 (节拍难以预测)
##   - 变速古典乐 (BPM 不稳定)
##   - Drum & Bass (节奏过于细碎，施法窗口过于频繁)
##
## 技术配置要求：
##   - BGM 必须输出到 "Music" 音频总线
##   - "Music" 总线上必须挂载 AudioEffectSpectrumAnalyzer
##   - BGM 的 Kick 频率应集中在 20-200Hz 区间
##   - BGM 的 BPM 必须与 GameManager.current_bpm 一致
extends Node

# ============================================================
# 信号
# ============================================================
signal bgm_changed(track_name: String)
signal bgm_beat_synced(beat_index: int)
signal bgm_measure_synced(measure_index: int)
signal crossfade_started(from_track: String, to_track: String)
signal crossfade_completed(new_track: String)

# ============================================================
# 配置
# ============================================================
const MUSIC_BUS_NAME := "Music"

## 交叉淡入淡出时间 (秒)
@export var crossfade_duration: float = 2.0
## 默认 BGM 音量 (dB)
@export var default_volume_db: float = -6.0
## 低通滤波器截止频率 (用于暂停/菜单时的闷音效果)
@export var muffled_cutoff_hz: float = 800.0

# ============================================================
# BGM 曲目注册表
# ============================================================
## 每首 BGM 的元数据：BPM、循环点、风格标签等
## 实际音频文件路径在此定义，运行时加载
const BGM_REGISTRY: Dictionary = {
	"menu_ambient": {
		"path": "res://audio/bgm/menu_ambient.ogg",
		"bpm": 0.0,          # 无节拍 (环境音)
		"loop": true,
		"style": "ambient",
		"description": "主菜单环境音 — 低沉的合成器垫音 + 微弱的数字噪声",
	},
	"battle_techno_120": {
		"path": "res://audio/bgm/battle_techno_120.ogg",
		"bpm": 120.0,
		"loop": true,
		"loop_start": 0.0,    # 循环起始点 (秒)
		"style": "minimal_techno",
		"description": "战斗 BGM — 120 BPM Minimal Techno，稳定 4/4 Kick",
	},
	"battle_techno_130": {
		"path": "res://audio/bgm/battle_techno_130.ogg",
		"bpm": 130.0,
		"loop": true,
		"loop_start": 0.0,
		"style": "glitch_techno",
		"description": "高强度战斗 BGM — 130 BPM Glitch Techno",
	},
	"battle_techno_140": {
		"path": "res://audio/bgm/battle_techno_140.ogg",
		"bpm": 140.0,
		"loop": true,
		"loop_start": 0.0,
		"style": "hard_techno",
		"description": "Boss 战 BGM — 140 BPM Hard Techno",
	},
	"game_over_drone": {
		"path": "res://audio/bgm/game_over_drone.ogg",
		"bpm": 0.0,
		"loop": true,
		"style": "dark_ambient",
		"description": "游戏结束 — 低沉的无人机音 + 衰减的回声",
	},
}

# ============================================================
# 播放器节点
# ============================================================
var _player_a: AudioStreamPlayer = null
var _player_b: AudioStreamPlayer = null
var _active_player: AudioStreamPlayer = null

# ============================================================
# 状态
# ============================================================
var _current_track: String = ""
var _is_crossfading: bool = false
var _crossfade_timer: float = 0.0
var _is_muffled: bool = false
var _target_volume_db: float = -6.0

# ============================================================
# BPM 同步状态
# ============================================================
var _bgm_bpm: float = 0.0
var _beat_timer: float = 0.0
var _beat_interval: float = 0.0
var _bgm_beat_count: int = 0
var _bgm_measure_count: int = 0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_players()
	_connect_signals()

func _process(delta: float) -> void:
	if _is_crossfading:
		_process_crossfade(delta)

	if _bgm_bpm > 0.0 and _active_player and _active_player.playing:
		_process_bgm_beat_sync(delta)

# ============================================================
# 初始化
# ============================================================

func _setup_players() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_a.bus = MUSIC_BUS_NAME
	_player_a.volume_db = default_volume_db
	add_child(_player_a)

	_player_b = AudioStreamPlayer.new()
	_player_b.bus = MUSIC_BUS_NAME
	_player_b.volume_db = -80.0  # 静音
	add_child(_player_b)

	_active_player = _player_a

func _connect_signals() -> void:
	if GameManager.has_signal("game_state_changed"):
		GameManager.game_state_changed.connect(_on_game_state_changed)

# ============================================================
# 公共接口
# ============================================================

## 播放指定 BGM 曲目
func play_bgm(track_name: String, fade_in: bool = true) -> void:
	if track_name == _current_track and _active_player.playing:
		return  # 已在播放

	var track_data: Dictionary = BGM_REGISTRY.get(track_name, {})
	if track_data.is_empty():
		push_warning("BGMManager: 未找到曲目 '%s'" % track_name)
		return

	var audio_path: String = track_data.get("path", "")

	# 尝试加载音频资源
	var stream: AudioStream = _load_audio_stream(audio_path)
	if stream == null:
		push_warning("BGMManager: 无法加载音频 '%s'，使用静音占位" % audio_path)
		# 即使没有音频文件，仍然设置 BPM 同步
		_current_track = track_name
		_bgm_bpm = track_data.get("bpm", 0.0)
		_update_beat_interval()
		bgm_changed.emit(track_name)
		return

	if _current_track != "" and _active_player.playing and fade_in:
		# 交叉淡入淡出
		_start_crossfade(stream, track_data)
	else:
		# 直接播放
		_active_player.stream = stream
		_active_player.volume_db = default_volume_db if not fade_in else -80.0
		_active_player.play()

		if fade_in:
			var tween := create_tween()
			tween.tween_property(_active_player, "volume_db", default_volume_db, 1.0)

	_current_track = track_name
	_bgm_bpm = track_data.get("bpm", 0.0)
	_update_beat_interval()
	bgm_changed.emit(track_name)

## 停止当前 BGM
func stop_bgm(fade_out: bool = true) -> void:
	if not _active_player.playing:
		return

	if fade_out:
		var tween := create_tween()
		tween.tween_property(_active_player, "volume_db", -80.0, 1.5)
		tween.tween_callback(_active_player.stop)
	else:
		_active_player.stop()

	_current_track = ""
	_bgm_bpm = 0.0

## 暂停 BGM (带闷音效果)
func pause_bgm() -> void:
	if _active_player.playing:
		_apply_muffle_effect(true)

## 恢复 BGM
func resume_bgm() -> void:
	_apply_muffle_effect(false)

## 获取当前播放的曲目名称
func get_current_track() -> String:
	return _current_track

## 获取当前 BGM 的 BPM
func get_bgm_bpm() -> float:
	return _bgm_bpm

## 设置 BGM 音量 (0.0 ~ 1.0)
func set_bgm_volume(volume: float) -> void:
	_target_volume_db = linear_to_db(clamp(volume, 0.0, 1.0))
	if _active_player and not _is_crossfading:
		_active_player.volume_db = _target_volume_db

## 根据游戏阶段自动选择 BGM
func auto_select_bgm_for_state(state: GameManager.GameState) -> void:
	match state:
		GameManager.GameState.MENU:
			play_bgm("menu_ambient")
		GameManager.GameState.PLAYING:
			# 根据当前 BPM 选择对应的战斗 BGM
			var bpm := GameManager.current_bpm
			if bpm <= 125.0:
				play_bgm("battle_techno_120")
			elif bpm <= 135.0:
				play_bgm("battle_techno_130")
			else:
				play_bgm("battle_techno_140")
		GameManager.GameState.GAME_OVER:
			play_bgm("game_over_drone")
		GameManager.GameState.PAUSED:
			pause_bgm()

# ============================================================
# 交叉淡入淡出
# ============================================================

func _start_crossfade(new_stream: AudioStream, track_data: Dictionary) -> void:
	var inactive_player := _player_b if _active_player == _player_a else _player_a

	inactive_player.stream = new_stream
	inactive_player.volume_db = -80.0
	inactive_player.play()

	_is_crossfading = true
	_crossfade_timer = 0.0

	crossfade_started.emit(_current_track, track_data.get("path", ""))

func _process_crossfade(delta: float) -> void:
	_crossfade_timer += delta
	var progress := clamp(_crossfade_timer / crossfade_duration, 0.0, 1.0)

	var inactive_player := _player_b if _active_player == _player_a else _player_a

	# 旧轨道淡出
	_active_player.volume_db = lerp(default_volume_db, -80.0, progress)
	# 新轨道淡入
	inactive_player.volume_db = lerp(-80.0, default_volume_db, progress)

	if progress >= 1.0:
		_active_player.stop()
		_active_player = inactive_player
		_is_crossfading = false
		crossfade_completed.emit(_current_track)

# ============================================================
# BPM 同步
# ============================================================

func _update_beat_interval() -> void:
	if _bgm_bpm > 0.0:
		_beat_interval = 60.0 / _bgm_bpm
	else:
		_beat_interval = 0.0
	_beat_timer = 0.0
	_bgm_beat_count = 0
	_bgm_measure_count = 0

func _process_bgm_beat_sync(delta: float) -> void:
	if _beat_interval <= 0.0:
		return

	_beat_timer += delta
	if _beat_timer >= _beat_interval:
		_beat_timer -= _beat_interval
		_bgm_beat_count += 1
		bgm_beat_synced.emit(_bgm_beat_count)

		# 每 4 拍 = 1 小节
		if _bgm_beat_count % 4 == 0:
			_bgm_measure_count += 1
			bgm_measure_synced.emit(_bgm_measure_count)

# ============================================================
# 闷音效果 (暂停时)
# ============================================================

func _apply_muffle_effect(enable: bool) -> void:
	_is_muffled = enable
	var bus_idx := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if bus_idx == -1:
		return

	if enable:
		# 添加低通滤波器模拟闷音
		var has_filter := false
		for i in range(AudioServer.get_bus_effect_count(bus_idx)):
			if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectLowPassFilter:
				has_filter = true
				break
		if not has_filter:
			var filter := AudioEffectLowPassFilter.new()
			filter.cutoff_hz = muffled_cutoff_hz
			AudioServer.add_bus_effect(bus_idx, filter)
		# 降低音量
		var tween := create_tween()
		tween.tween_method(func(vol: float):
			AudioServer.set_bus_volume_db(bus_idx, vol),
			AudioServer.get_bus_volume_db(bus_idx), -12.0, 0.3)
	else:
		# 移除低通滤波器
		for i in range(AudioServer.get_bus_effect_count(bus_idx) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectLowPassFilter:
				AudioServer.remove_bus_effect(bus_idx, i)
		# 恢复音量
		var tween := create_tween()
		tween.tween_method(func(vol: float):
			AudioServer.set_bus_volume_db(bus_idx, vol),
			AudioServer.get_bus_volume_db(bus_idx), 0.0, 0.3)

# ============================================================
# 音频加载
# ============================================================

func _load_audio_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream

# ============================================================
# 信号回调
# ============================================================

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	auto_select_bgm_for_state(new_state)
