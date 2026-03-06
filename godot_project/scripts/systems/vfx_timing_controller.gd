## vfx_timing_controller.gd
## VFX 节拍同步引擎 (VFXTimingController)
##
## 负责将所有视觉特效的生命周期精确锚定到 BGM 的时间网格上。
## 实现了基于 BPM 的相对时间单位体系、节拍量化与视觉补偿机制。
## 
## 核心功能：
## 1. 监听 BGMManager 的节拍信号 (sixteenth_tick, bgm_beat_synced, bgm_measure_synced)
## 2. 提供统一的节拍信号供 VFX 系统订阅
## 3. 处理手动输入的节拍量化 (Early/Late 补偿)
## 4. 提供基于 BPM 的时间转换工具函数
extends Node

# ============================================================
# 信号
# ============================================================
## 统一的节拍信号，供所有 VFX 系统订阅
## beat_index: 当前拍号
## is_strong_beat: 是否为强拍 (每小节的第一拍)
signal beat_signal(beat_index: int, is_strong_beat: bool)

## 十六分音符微调信号，用于拖尾波动、修饰符闪烁等
signal tick_signal(tick_index: int)

## 八分音符信号，用于手动施法量化点、和弦持续阶段节拍感
signal eighth_note_signal(eighth_index: int)

## 小节信号，用于和弦进行判定、全屏效果触发
signal measure_signal(measure_index: int)

# ============================================================
# 状态与缓存
# ============================================================
## 待触发的特效队列
var _vfx_queue: Array[Dictionary] = []

## 当前节拍状态
var _current_tick: int = 0
var _current_eighth: int = 0
var _current_beat: int = 0
var _current_measure: int = 0

# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
_connect_bgm_signals()

func _process(delta: float) -> void:
_process_vfx_queue()

# ============================================================
# 信号连接与处理
# ============================================================
func _connect_bgm_signals() -> void:
if BGMManager.has_signal("sixteenth_tick"):
BGMManager.sixteenth_tick.connect(_on_sixteenth_tick)
if BGMManager.has_signal("bgm_beat_synced"):
BGMManager.bgm_beat_synced.connect(_on_beat_synced)
if BGMManager.has_signal("bgm_measure_synced"):
BGMManager.bgm_measure_synced.connect(_on_measure_synced)

func _on_sixteenth_tick(tick_index: int) -> void:
_current_tick = tick_index
tick_signal.emit(tick_index)

# 每两个 tick 是一个八分音符
if tick_index % 2 == 0:
_current_eighth = tick_index / 2
eighth_note_signal.emit(_current_eighth)

func _on_beat_synced(beat_index: int) -> void:
_current_beat = beat_index
# 假设 4/4 拍，每 4 拍一个小节，第 0 拍为强拍
var is_strong_beat = (beat_index % 4 == 0)
beat_signal.emit(beat_index, is_strong_beat)

func _on_measure_synced(measure_index: int) -> void:
_current_measure = measure_index
measure_signal.emit(measure_index)

# ============================================================
# 时间转换工具
# ============================================================
## 获取当前一拍的绝对时间（秒）
func get_beat_duration() -> float:
var bpm = GameManager.get_bpm() if GameManager.has_method("get_bpm") else 120.0
if bpm <= 0:
bpm = 120.0
return 60.0 / bpm

## 将 Beat 单位转换为绝对时间（秒）
func beats_to_seconds(beats: float) -> float:
return beats * get_beat_duration()

## 获取当前一个 Tick (十六分音符) 的绝对时间（秒）
func get_tick_duration() -> float:
return get_beat_duration() / 4.0

## 获取当前一个八分音符的绝对时间（秒）
func get_eighth_note_duration() -> float:
return get_beat_duration() / 2.0

# ============================================================
# 节拍量化与视觉补偿
# ============================================================
## 调度一个特效，处理节拍量化
## vfx_id: 特效唯一标识
## input_time: 玩家输入时间（GameManager.game_time）
## target_beat_time: 目标节拍时间
## callback: 触发时调用的回调函数
func quantize_and_trigger(vfx_id: String, input_time: float, target_beat_time: float, callback: Callable) -> void:
var delay = input_time - target_beat_time
var beat_duration = get_beat_duration()

if delay < 0:
# Early 输入：缓存，在 target_beat_time 触发
_schedule_vfx(vfx_id, target_beat_time, callback, "normal", 0.0)
elif delay < 0.05 * beat_duration:
# 轻微 Late：加速预兆
callback.call("accelerated", delay)
elif delay < 0.1 * beat_duration:
# 较多 Late：跳帧
callback.call("skip_frame", delay)
else:
# 超出容差：对齐到下一个 eighth_note
var next_eighth_time = target_beat_time + get_eighth_note_duration()
_schedule_vfx(vfx_id, next_eighth_time, callback, "normal", 0.0)

func _schedule_vfx(vfx_id: String, trigger_time: float, callback: Callable, compensation_type: String, delay: float) -> void:
_vfx_queue.append({
"id": vfx_id,
"trigger_time": trigger_time,
"callback": callback,
"compensation_type": compensation_type,
"delay": delay
})

func _process_vfx_queue() -> void:
if _vfx_queue.is_empty():
return

var current_time = GameManager.game_time if "game_time" in GameManager else Time.get_ticks_msec() / 1000.0
var i = _vfx_queue.size() - 1

while i >= 0:
var vfx = _vfx_queue[i]
if current_time >= vfx["trigger_time"]:
vfx["callback"].call(vfx["compensation_type"], vfx["delay"])
_vfx_queue.remove_at(i)
i -= 1

# ============================================================
# 疲劳系统集成
# ============================================================
## 获取疲劳状态下的特效时间缩放系数
func get_fatigue_time_scale() -> float:
if not FatigueManager:
return 1.0

var afi = FatigueManager.get_afi() if FatigueManager.has_method("get_afi") else 0.0

if afi < 0.2:
return 1.0 # 无疲劳
elif afi < 0.4:
return 0.5 # 轻度：消散加速 50%
elif afi < 0.6:
return 0.7 # 中度：预兆缩短 30%
elif afi < 0.8:
return 0.3 # 重度：消散加速 70%
else:
# 极度：随机波动
return randf_range(0.5, 1.5)
