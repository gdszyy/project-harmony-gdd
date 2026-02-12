## audio_event_queue.gd
## 音效事件量化队列 (OPT05: Rez-Style Input Quantization)
##
## 核心设计思想：借鉴《Rez》的"视觉即时、音频量化"机制。
## 无论玩家何时按下按键，视觉效果（弹体发射、粒子特效）立即发生；
## 但关联的音效被自动"延迟"并"吸附"到最近的下一个十六分音符节拍点上播放。
##
## 这使得游戏中所有的音效都自然地对齐到音乐网格上，
## 创造出"人人都是节奏大师"的错觉，极大地提升了音乐性体验。
##
## 量化模式：
##   FULL  — 所有音效严格对齐到十六分音符（默认，最佳音乐体验）
##   SOFT  — 仅当偏差 > 1/32 音符时才量化（高手模式，保留精确输入的即时感）
##   OFF   — 音效即时播放，无量化（无障碍/竞技模式）
##
## 设计参考：
##   - Docs/Optimization_Modules/OPT05_RezStyleInputQuantization.md
class_name AudioEventQueue
extends Node

# ============================================================
# 信号
# ============================================================

## 当一批音效事件在节拍点被处理时发出
## DEPRECATED: Signal emitted but no active consumer connected (Issue #86 audit)
signal events_flushed(event_count: int)

## 当量化模式改变时发出
## DEPRECATED: Signal emitted but no active consumer connected (Issue #86 audit)
signal quantize_mode_changed(new_mode: QuantizeMode)

# ============================================================
# 量化模式
# ============================================================

enum QuantizeMode {
	FULL,   ## 完全量化：所有音效严格对齐到十六分音符
	SOFT,   ## 柔性量化：仅当偏差 > 阈值时才量化
	OFF,    ## 关闭：音效即时播放，无量化
}

# ============================================================
# 配置
# ============================================================

## 当前量化模式
var quantize_mode: QuantizeMode = QuantizeMode.FULL

## 柔性量化阈值（秒）
## 约 1/32 音符 @120BPM ≈ 31.25ms
const SOFT_QUANTIZE_THRESHOLD_SEC: float = 0.03

## 安全阈值：如果事件在队列中停留超过此时间（秒），强制播放
## 防止在 BGM 暂停或异常情况下事件永远不被处理
const MAX_QUEUE_WAIT_SEC: float = 0.5

# ============================================================
# 内部状态
# ============================================================

## 待播放的事件队列
var _queue: Array[AudioEvent] = []

## 对 AudioManager 的引用（在 _ready 中获取）
var _audio_manager: Node = null

## BGM 是否正在播放（决定是否启用量化）
var _bgm_is_playing: bool = false

## 安全计时器：用于在 BGM 未播放时定期刷新队列
var _safety_timer: float = 0.0

# ============================================================
# 统计信息（调试用）
# ============================================================

## 总入队事件数
var _total_enqueued: int = 0

## 总已处理事件数
var _total_processed: int = 0

## 总即时播放事件数（跳过量化）
var _total_immediate: int = 0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 延迟连接信号，确保所有 autoload 单例已初始化
	# （AudioManager 在 BGMManager 之前加载，需要等待 BGMManager 就绪）
	call_deferred("_deferred_connect_signals")

func _deferred_connect_signals() -> void:
	# 连接 BGMManager 的十六分音符时钟信号
	var bgm_mgr := get_node_or_null("/root/BGMManager")
	if bgm_mgr and bgm_mgr.has_signal("sixteenth_tick"):
		if not bgm_mgr.sixteenth_tick.is_connected(_on_sixteenth_tick):
			bgm_mgr.sixteenth_tick.connect(_on_sixteenth_tick)

	# 监听 BGM 状态变化
	if bgm_mgr and bgm_mgr.has_signal("bgm_changed"):
		if not bgm_mgr.bgm_changed.is_connected(_on_bgm_changed):
			bgm_mgr.bgm_changed.connect(_on_bgm_changed)

func _process(delta: float) -> void:
	# 安全机制：如果 BGM 未播放，定期刷新队列
	if not _bgm_is_playing and _queue.size() > 0:
		_safety_timer += delta
		if _safety_timer >= MAX_QUEUE_WAIT_SEC:
			_safety_timer = 0.0
			_flush_queue()

	# 安全机制：检查是否有超时事件
	_check_stale_events()

# ============================================================
# 公共接口
# ============================================================

## 将音效事件加入量化队列
## 根据当前量化模式决定是立即播放还是入队等待
func enqueue(event: AudioEvent) -> void:
	if event == null:
		return

	# 确保时间戳已设置
	if event.timestamp_ms <= 0.0:
		event.timestamp_ms = Time.get_ticks_msec()

	_total_enqueued += 1

	match quantize_mode:
		QuantizeMode.OFF:
			# 直接播放，不入队
			_play_event(event)
			_total_immediate += 1

		QuantizeMode.SOFT:
			# 检查是否接近节拍点
			var time_to_next := _get_time_to_next_sixteenth()
			if time_to_next < SOFT_QUANTIZE_THRESHOLD_SEC:
				# 足够接近节拍点，直接播放
				_play_event(event)
				_total_immediate += 1
			else:
				_queue.append(event)

		QuantizeMode.FULL:
			_queue.append(event)

## 设置量化模式
func set_quantize_mode(mode: QuantizeMode) -> void:
	if quantize_mode != mode:
		quantize_mode = mode
		quantize_mode_changed.emit(mode)

		# 如果切换到 OFF 模式，立即刷新队列中所有待处理事件
		if mode == QuantizeMode.OFF:
			_flush_queue()

## 获取当前队列中的事件数量
func get_queue_size() -> int:
	return _queue.size()

## 获取统计信息（调试用）
func get_stats() -> Dictionary:
	return {
		"total_enqueued": _total_enqueued,
		"total_processed": _total_processed,
		"total_immediate": _total_immediate,
		"current_queue_size": _queue.size(),
		"quantize_mode": QuantizeMode.keys()[quantize_mode],
		"bgm_playing": _bgm_is_playing,
	}

## 清空队列（不播放）
func clear_queue() -> void:
	_queue.clear()

## 设置 AudioManager 引用
func set_audio_manager(manager: Node) -> void:
	_audio_manager = manager

# ============================================================
# 信号回调
# ============================================================

## BGMManager 的十六分音符时钟回调
## 在每个十六分音符节拍点触发，处理队列中所有待播放事件
func _on_sixteenth_tick(_sixteenth_index: int) -> void:
	_bgm_is_playing = true
	_safety_timer = 0.0
	_flush_queue()

## BGM 状态变化回调
func _on_bgm_changed(_track_name: String) -> void:
	_bgm_is_playing = true

# ============================================================
# 内部方法
# ============================================================

## 刷新队列：播放所有待处理事件
func _flush_queue() -> void:
	if _queue.is_empty():
		return

	var count := _queue.size()
	for event in _queue:
		_play_event(event)
	_queue.clear()

	_total_processed += count
	events_flushed.emit(count)

## 检查并处理超时事件
func _check_stale_events() -> void:
	if _queue.is_empty():
		return

	var current_ms := float(Time.get_ticks_msec())
	var max_wait_ms := MAX_QUEUE_WAIT_SEC * 1000.0
	var stale_events: Array[AudioEvent] = []

	for event in _queue:
		if current_ms - event.timestamp_ms > max_wait_ms:
			stale_events.append(event)

	for event in stale_events:
		_play_event(event)
		_queue.erase(event)
		_total_processed += 1

## 实际播放一个音效事件
## 委托给 AudioManager 的内部播放方法
func _play_event(event: AudioEvent) -> void:
	if _audio_manager == null:
		# 尝试通过自动加载获取
		_audio_manager = Engine.get_singleton("AudioManager") if Engine.has_singleton("AudioManager") else null
		if _audio_manager == null:
			# 回退：尝试通过节点树获取
			_audio_manager = get_node_or_null("/root/AudioManager")
		if _audio_manager == null:
			push_warning("AudioEventQueue: AudioManager not found, cannot play event: %s" % event.sound_id)
			return

	if event.is_spatial:
		_audio_manager.play_sound_immediate_2d(
			event.sound_id, event.position,
			event.volume_db, event.pitch, event.bus_name
		)
	else:
		_audio_manager.play_sound_immediate_global(
			event.sound_id,
			event.volume_db, event.pitch, event.bus_name
		)

## 计算距离下一个十六分音符的时间（秒）
func _get_time_to_next_sixteenth() -> float:
	var bgm_mgr := get_node_or_null("/root/BGMManager")
	if bgm_mgr == null:
		return 0.0

	var bpm: float = bgm_mgr._bpm if bgm_mgr._bpm > 0.0 else 120.0
	var sixteenth_interval := 60.0 / (bpm * 4.0)

	# 使用 BGMManager 的内部时钟计算偏移
	# _clock_timer 记录了距离下一个十六分音符的剩余时间
	var elapsed_in_tick: float = bgm_mgr._clock_timer if bgm_mgr else 0.0
	return max(0.0, sixteenth_interval - elapsed_in_tick)
