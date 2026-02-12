## spatial_audio_controller.gd
## OPT06 — 空间音频信息传递控制器 (Spatial Audio for Information Delivery)
##
## 将空间音频从简单的沉浸感增强工具，转变为功能性的非视觉信息通道：
##   - 听音辨位：通过声相 (Panning) 和音色变化精确传达敌人方位和距离
##   - 听音辨状态：通过特殊音频效果 (FX) 即时传达敌人关键状态变化
##   - 降低视觉过载：将部分信息从视觉通道转移到听觉通道
##
## 设计原则：
##   - 信息优先：空间音频首要目的是传递信息，其次才是沉浸感
##   - 直觉映射：音频参数变化与游戏状态建立直觉的、易于学习的映射
##   - 性能友好：音频效果处理不应对帧率产生显著影响
##
## 挂载方式：由 enemy_base.gd 在 _ready() 中动态创建并添加为子节点
## 前置依赖：OPT03（可选，配合效果最佳）
## 关联文档：OPT06_SpatialAudioInformationDelivery.md, Audio_Design_Guide.md
class_name SpatialAudioController
extends Node

# ============================================================
# 信号
# ============================================================
## 当空间音频参数发生显著变化时发出（供调试面板使用）
signal spatial_params_changed(params: Dictionary)
## 当状态音效被应用或移除时发出
signal state_fx_changed(state: String, active: bool)

# ============================================================
# 导出配置 — 距离与衰减
# ============================================================
## 最大听觉距离 (px)，超出此距离的敌人音效将被完全静音
@export var max_hearing_distance: float = 800.0

## 近距阈值 (px) — 0 到此值范围内，LPF 无效果
@export var near_distance: float = 200.0

## 中距阈值 (px) — 近距到此值范围内，LPF 中等效果
@export var mid_distance: float = 500.0

## 远距 LPF 截止频率 (Hz) — 声音模糊、遥远
@export var lpf_min_cutoff: float = 1500.0

## 近距 LPF 截止频率 (Hz) — 声音清晰、明亮（等效于无效果）
@export var lpf_max_cutoff: float = 20000.0

## 远距音高微调上限 — 模拟多普勒效应的微弱暗示
@export var far_pitch_max: float = 1.03

## 远距音高微调起始归一化距离 (0.0-1.0)
@export var pitch_shift_threshold: float = 0.6

# ============================================================
# 导出配置 — 状态音效
# ============================================================
## 是否启用状态音效处理
@export var enable_state_fx: bool = true

## 是否启用距离音色调制
@export var enable_distance_modulation: bool = true

# ============================================================
# 音频总线名称常量
# ============================================================
const ENEMY_BUS_NEAR := "EnemySFX_Near"
const ENEMY_BUS_MID := "EnemySFX_Mid"
const ENEMY_BUS_FAR := "EnemySFX_Far"
const ENEMY_BUS_FALLBACK := "EnemySFX"

# ============================================================
# 距离区间枚举
# ============================================================
enum DistanceZone {
	NEAR,    ## 0 - near_distance: 清晰、明亮
	MID,     ## near_distance - mid_distance: 略显沉闷
	FAR,     ## mid_distance - max_hearing_distance: 模糊、遥远
	OUT,     ## > max_hearing_distance: 超出听觉范围
}

# ============================================================
# 内部状态
# ============================================================
## 宿主敌人节点引用
var _enemy: Node2D = null

## 当前距离区间
var _current_zone: DistanceZone = DistanceZone.NEAR

## 当前归一化距离 [0.0, 1.0]
var _normalized_distance: float = 0.0

## 当前 LPF 截止频率
var _current_lpf_cutoff: float = 20000.0

## 当前音高微调
var _current_pitch_scale: float = 1.0

## 当前声相值 [-1.0, 1.0]
var _current_pan: float = 0.0

## 当前活跃的状态效果名称
var _active_state: String = ""

## 缓存的玩家引用
var _player: Node2D = null

## 更新节流计时器（不需要每帧更新，降低开销）
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.05  ## 每 50ms 更新一次（20Hz）

## 视口尺寸缓存（用于声相计算）
var _viewport_width: float = 1920.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 获取宿主敌人节点
	_enemy = get_parent() as Node2D
	if _enemy == null:
		push_warning("SpatialAudioController: 父节点不是 Node2D，空间音频将无法工作")
		set_process(false)
		return

	# 缓存玩家引用
	_find_player()

	# 缓存视口宽度
	var viewport := get_viewport()
	if viewport:
		_viewport_width = viewport.get_visible_rect().size.x
		if _viewport_width <= 0.0:
			_viewport_width = 1920.0

func _process(delta: float) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return

	# 节流更新
	_update_timer += delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0

	# 确保玩家引用有效
	if _player == null or not is_instance_valid(_player):
		_find_player()
		if _player == null:
			return

	# 更新空间音频参数
	_update_spatial_params()

# ============================================================
# 核心：空间参数计算
# ============================================================

## 更新所有空间音频参数
func _update_spatial_params() -> void:
	var enemy_pos: Vector2 = _enemy.global_position
	var player_pos: Vector2 = _player.global_position

	# 1. 计算距离
	var distance: float = enemy_pos.distance_to(player_pos)
	_normalized_distance = clampf(distance / max_hearing_distance, 0.0, 1.0)

	# 2. 确定距离区间
	var new_zone: DistanceZone = _calculate_zone(distance)
	_current_zone = new_zone

	# 3. 计算 LPF 截止频率（基于距离的音色调制）
	if enable_distance_modulation:
		_current_lpf_cutoff = _calculate_lpf_cutoff(distance)

	# 4. 计算音高微调
	if enable_distance_modulation:
		_current_pitch_scale = _calculate_pitch_scale()

	# 5. 计算声相值（基于屏幕相对位置）
	_current_pan = _calculate_pan(enemy_pos, player_pos)

## 确定敌人所处的距离区间
func _calculate_zone(distance: float) -> DistanceZone:
	if distance <= near_distance:
		return DistanceZone.NEAR
	elif distance <= mid_distance:
		return DistanceZone.MID
	elif distance <= max_hearing_distance:
		return DistanceZone.FAR
	else:
		return DistanceZone.OUT

## 计算 LPF 截止频率
## 近距 (0-200px): 20000 Hz（无效果，清晰明亮）
## 中距 (200-500px): 8000-4000 Hz（略显沉闷）
## 远距 (500px+): 4000-1500 Hz（模糊遥远）
func _calculate_lpf_cutoff(distance: float) -> float:
	match _current_zone:
		DistanceZone.NEAR:
			return lpf_max_cutoff
		DistanceZone.MID:
			# 中距：从 8000 Hz 线性过渡到 4000 Hz
			var t: float = (distance - near_distance) / (mid_distance - near_distance)
			return lerpf(8000.0, 4000.0, t)
		DistanceZone.FAR:
			# 远距：从 4000 Hz 对数衰减到 lpf_min_cutoff
			var t: float = (distance - mid_distance) / (max_hearing_distance - mid_distance)
			# 使用对数曲线使衰减更自然
			var log_t: float = 1.0 - pow(1.0 - t, 2.0)
			return lerpf(4000.0, lpf_min_cutoff, log_t)
		DistanceZone.OUT:
			return lpf_min_cutoff
	return lpf_max_cutoff

## 计算音高微调
## 仅在远距时微调（模拟声音在空气中传播的物理特性）
func _calculate_pitch_scale() -> float:
	if _normalized_distance > pitch_shift_threshold:
		var t: float = (_normalized_distance - pitch_shift_threshold) / (1.0 - pitch_shift_threshold)
		return lerpf(1.0, far_pitch_max, t)
	return 1.0

## 计算声相值
## 基于敌人相对于玩家的水平位置，映射到 [-1.0, 1.0]
## 使用屏幕空间而非世界空间，确保声相与视觉位置一致
func _calculate_pan(enemy_pos: Vector2, player_pos: Vector2) -> float:
	var relative_x: float = enemy_pos.x - player_pos.x
	# 将相对位置映射到 [-1.0, 1.0]，以半个视口宽度为满幅
	var half_viewport: float = _viewport_width * 0.5
	var pan: float = clampf(relative_x / half_viewport, -1.0, 1.0)
	return pan

# ============================================================
# 公共接口 — 空间参数查询
# ============================================================

## 获取当前推荐的音频总线名称（基于距离区间）
func get_spatial_bus() -> String:
	match _current_zone:
		DistanceZone.NEAR:
			return ENEMY_BUS_NEAR
		DistanceZone.MID:
			return ENEMY_BUS_MID
		DistanceZone.FAR:
			return ENEMY_BUS_FAR
		DistanceZone.OUT:
			return ENEMY_BUS_FAR
	return ENEMY_BUS_FALLBACK

## 获取当前 LPF 截止频率
func get_lpf_cutoff() -> float:
	return _current_lpf_cutoff

## 获取当前音高微调值
func get_pitch_scale() -> float:
	return _current_pitch_scale

## 获取当前声相值 [-1.0, 1.0]
func get_pan() -> float:
	return _current_pan

## 获取当前距离区间
func get_distance_zone() -> DistanceZone:
	return _current_zone

## 获取当前归一化距离 [0.0, 1.0]
func get_normalized_distance() -> float:
	return _normalized_distance

## 获取是否在听觉范围内
func is_in_hearing_range() -> bool:
	return _current_zone != DistanceZone.OUT

## 获取当前活跃的状态效果
func get_active_state() -> String:
	return _active_state

## 获取完整的空间参数快照（供调试或外部系统使用）
func get_spatial_snapshot() -> Dictionary:
	return {
		"zone": DistanceZone.keys()[_current_zone],
		"normalized_distance": _normalized_distance,
		"lpf_cutoff": _current_lpf_cutoff,
		"pitch_scale": _current_pitch_scale,
		"pan": _current_pan,
		"active_state_fx": _active_state,
		"in_hearing_range": is_in_hearing_range(),
	}

# ============================================================
# 公共接口 — 状态音效管理
# ============================================================

## 应用状态音效
## 当敌人进入特定状态时调用，会影响后续所有音效的播放参数
## @param state: 状态名称 ("stunned", "elite", "charging", "low_health", "shielded")
func apply_state_fx(state: String) -> void:
	if not enable_state_fx:
		return

	# 如果已经是相同状态，不重复应用
	if _active_state == state:
		return

	# 清除旧状态
	if _active_state != "":
		state_fx_changed.emit(_active_state, false)

	_active_state = state
	state_fx_changed.emit(state, true)

## 清除当前状态音效
func clear_state_fx() -> void:
	if _active_state != "":
		var old_state := _active_state
		_active_state = ""
		state_fx_changed.emit(old_state, false)

## 获取当前状态对应的音频效果参数
## 返回一个 Dictionary，包含应用到 AudioStreamPlayer2D 的参数修改
## AudioManager 在播放音效时查询此方法，将效果叠加到播放参数上
func get_state_fx_params() -> Dictionary:
	if _active_state == "":
		return {}

	match _active_state:
		"stunned":
			# 眩晕：镶边效果 — 通过快速音高振荡模拟
			return {
				"pitch_modulation": 0.15,      ## 音高振荡幅度
				"pitch_mod_rate": 3.0,          ## 振荡频率 (Hz)
				"volume_mod": -2.0,             ## 音量微调 (dB)
				"effect_type": "flanger",       ## 效果类型标识
			}
		"elite":
			# 精英/危险：失真效果 — 增加增益和低频
			return {
				"pitch_offset": -0.15,          ## 音高降低（更沉重）
				"volume_mod": 3.0,              ## 音量增大 (dB)
				"effect_type": "distortion",    ## 效果类型标识
			}
		"charging":
			# 蓄力中：上升滤波扫频 — LPF 截止频率渐增
			return {
				"lpf_override": true,           ## 覆盖距离 LPF
				"lpf_sweep_start": 800.0,       ## 扫频起始 (Hz)
				"lpf_sweep_end": 16000.0,       ## 扫频终止 (Hz)
				"volume_mod": 2.0,              ## 音量渐增 (dB)
				"effect_type": "sweep",         ## 效果类型标识
			}
		"low_health":
			# 低血量：颤音效果 — 音量周期性波动
			return {
				"volume_tremolo_depth": 6.0,    ## 颤音深度 (dB)
				"volume_tremolo_rate": 4.0,     ## 颤音频率 (Hz)
				"pitch_offset": 0.05,           ## 音高微升（不稳定感）
				"effect_type": "tremolo",       ## 效果类型标识
			}
		"shielded":
			# 护盾激活：移相效果 — 金属质感
			return {
				"pitch_modulation": 0.08,       ## 轻微音高振荡
				"pitch_mod_rate": 1.5,          ## 较慢的振荡
				"pitch_offset": -0.08,          ## 音高微降（金属感）
				"volume_mod": 1.0,              ## 音量微增
				"effect_type": "phaser",        ## 效果类型标识
			}

	return {}

# ============================================================
# 公共接口 — 音效播放参数修改器
# ============================================================

## 修改即将播放的音效参数
## AudioManager 在播放敌人音效前调用此方法，获取空间化后的参数
## @param base_volume_db: 原始音量 (dB)
## @param base_pitch: 原始音高
## @param base_bus: 原始音频总线
## @return Dictionary 包含修改后的 volume_db, pitch, bus, pan
func modify_playback_params(base_volume_db: float, base_pitch: float, base_bus: String) -> Dictionary:
	var result := {
		"volume_db": base_volume_db,
		"pitch": base_pitch,
		"bus": base_bus,
		"pan": _current_pan,
		"should_play": is_in_hearing_range(),
	}

	if not is_in_hearing_range():
		return result

	# 1. 应用距离音色调制
	if enable_distance_modulation:
		# 根据距离区间选择总线（总线上已挂载对应的 LPF）
		result["bus"] = get_spatial_bus()

		# 应用音高微调
		result["pitch"] = base_pitch * _current_pitch_scale

		# 距离衰减音量补偿（远距额外衰减）
		if _current_zone == DistanceZone.FAR:
			var far_t: float = (_normalized_distance - (mid_distance / max_hearing_distance))
			far_t = clampf(far_t / (1.0 - mid_distance / max_hearing_distance), 0.0, 1.0)
			result["volume_db"] = base_volume_db - (far_t * 6.0)  # 最多额外衰减 6dB

	# 2. 应用状态音效
	if enable_state_fx and _active_state != "":
		var fx_params := get_state_fx_params()
		if not fx_params.is_empty():
			_apply_state_fx_to_params(result, fx_params)

	return result

## 将状态效果参数叠加到播放参数上
func _apply_state_fx_to_params(result: Dictionary, fx_params: Dictionary) -> void:
	# 音量修改
	if fx_params.has("volume_mod"):
		result["volume_db"] = result["volume_db"] + fx_params["volume_mod"]

	# 音高偏移
	if fx_params.has("pitch_offset"):
		result["pitch"] = result["pitch"] + fx_params["pitch_offset"]

	# 音高调制（模拟镶边/移相）
	if fx_params.has("pitch_modulation"):
		var mod_amount: float = fx_params["pitch_modulation"]
		var mod_rate: float = fx_params.get("pitch_mod_rate", 2.0)
		var time_sec: float = Time.get_ticks_msec() / 1000.0
		var modulation: float = sin(time_sec * mod_rate * TAU) * mod_amount
		result["pitch"] = result["pitch"] + modulation

	# 颤音（音量调制）
	if fx_params.has("volume_tremolo_depth"):
		var depth: float = fx_params["volume_tremolo_depth"]
		var rate: float = fx_params.get("volume_tremolo_rate", 4.0)
		var time_sec: float = Time.get_ticks_msec() / 1000.0
		var tremolo: float = sin(time_sec * rate * TAU) * depth
		result["volume_db"] = result["volume_db"] + tremolo

# ============================================================
# 内部工具
# ============================================================

## 查找玩家节点
func _find_player() -> void:
	var tree := get_tree()
	if tree:
		_player = tree.get_first_node_in_group("player")
