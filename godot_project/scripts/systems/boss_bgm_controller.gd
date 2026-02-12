## boss_bgm_controller.gd
## Boss 战 BGM 变体控制器 (Issue #114)
##
## 职责：
## 1. 在 Boss 战期间接管 BGMManager 的参数，创建紧张感更强的音乐表现
## 2. 利用 OPT04 章节调性演变系统，为每个 Boss 定制独特的音乐参数
## 3. 响应 Boss 阶段切换，动态调整 BPM、强度、节奏型和调式
## 4. Boss 战结束后平滑恢复到章节默认音乐状态
##
## 设计理念：
## Boss 战 BGM 不是独立的音轨，而是在现有程序化合成引擎基础上的"变体"。
## 通过提升 BPM、切换更紧张的节奏型、调整调式色彩，让玩家在音乐层面
## 感受到 Boss 战的压迫感和史诗感。每个 Boss 的音乐参数都与其音乐史背景呼应。
##
## 使用方式：
##   var bgm_ctrl = BossBGMController.new()
##   add_child(bgm_ctrl)
##   bgm_ctrl.enter_boss_bgm("boss_pythagoras")
##   # Boss 击败后
##   bgm_ctrl.exit_boss_bgm()
class_name BossBGMController
extends Node

# ============================================================
# 信号
# ============================================================
signal boss_bgm_started(boss_key: String)
signal boss_bgm_ended()
signal boss_bgm_phase_changed(phase_index: int)

# ============================================================
# 配置
# ============================================================
## BGM 过渡时间（秒）
@export var transition_duration: float = 2.0
## BPM 过渡时间（秒）
@export var bpm_transition_duration: float = 4.0

# ============================================================
# 状态
# ============================================================
var _is_boss_bgm_active: bool = false
var _current_boss_key: String = ""
var _current_phase: int = 0
var _saved_state: Dictionary = {}  ## 保存进入 Boss 战前的 BGM 状态

# ============================================================
# Boss BGM 配置数据
# ============================================================
## 每个 Boss 的 BGM 变体参数
## 利用 OPT04 章节调性系统和 BGMManager 的现有接口
const BOSS_BGM_CONFIGS: Dictionary = {
	# ================================================================
	# 第一章：毕达哥拉斯 — 纯粹的数学秩序，庄严而有力
	# 音乐特征：Ionian 调式，BPM 适度提升，强调 Kick 的数学精确感
	# ================================================================
	"boss_pythagoras": {
		"bpm_offset": 15,         # BPM 提升量
		"intensity": 0.85,        # 高强度但不到极限
		"hihat_pattern": "eighth", # 精确的八分音符
		"ghost_pattern": "default",
		"bass_pattern": "driving", # 驱动型低音
		"kick_volume_boost": 3.0,  # Kick 音量提升 (dB)
		"pad_volume_adjust": -4.0, # Pad 音量降低 (dB)
		"pitch_shift": 0.0,       # 无音调偏移
		"tonality_override": -1,   # -1 = 使用当前章节调性
		"phase_configs": [
			{ "bpm_offset": 15, "intensity": 0.85 },
			{ "bpm_offset": 25, "intensity": 0.95 },
		],
	},

	# ================================================================
	# 第二章：圭多 — 圣咏的庄严与压迫感
	# 音乐特征：Dorian 调式，较慢但沉重，Pad 突出营造教堂回响
	# ================================================================
	"boss_guido": {
		"bpm_offset": 5,
		"intensity": 0.75,
		"hihat_pattern": "offbeat",  # 反拍，模拟圣咏的呼吸感
		"ghost_pattern": "minimal",
		"bass_pattern": "minimal",   # 简约低音，模拟管风琴持续音
		"kick_volume_boost": 2.0,
		"pad_volume_adjust": 4.0,    # Pad 音量提升，营造空间感
		"pitch_shift": -0.02,        # 微微降调，增加庄严感
		"tonality_override": -1,
		"phase_configs": [
			{ "bpm_offset": 5, "intensity": 0.75 },
			{ "bpm_offset": 15, "intensity": 0.9 },
		],
	},

	# ================================================================
	# 第三章：巴赫 — 精密的复调机械
	# 音乐特征：Mixolydian 调式，中高 BPM，所有层全开模拟多声部
	# ================================================================
	"boss_bach": {
		"bpm_offset": 10,
		"intensity": 0.9,
		"hihat_pattern": "sixteenth", # 十六分音符，模拟赋格的密度
		"ghost_pattern": "busy",      # 密集填充，模拟多声部
		"bass_pattern": "walking",    # 行走低音，巴洛克标志
		"kick_volume_boost": 2.0,
		"pad_volume_adjust": -2.0,
		"pitch_shift": 0.0,
		"tonality_override": -1,
		"phase_configs": [
			{ "bpm_offset": 10, "intensity": 0.9, "bass_pattern": "walking" },
			{ "bpm_offset": 20, "intensity": 1.0, "bass_pattern": "driving" },
		],
	},

	# ================================================================
	# 第四章：莫扎特 — 优雅中的紧张
	# 音乐特征：Phrygian 调式（紧张的半音），精致但逐渐失控
	# ================================================================
	"boss_mozart": {
		"bpm_offset": 8,
		"intensity": 0.7,
		"hihat_pattern": "eighth",
		"ghost_pattern": "default",
		"bass_pattern": "default",
		"kick_volume_boost": 1.0,
		"pad_volume_adjust": 0.0,
		"pitch_shift": 0.0,
		"tonality_override": -1,
		"phase_configs": [
			{ "bpm_offset": 8, "intensity": 0.7, "hihat_pattern": "eighth" },    # 呈示部
			{ "bpm_offset": 18, "intensity": 0.85, "hihat_pattern": "sixteenth" }, # 发展部
			{ "bpm_offset": 12, "intensity": 0.8, "hihat_pattern": "eighth" },    # 再现部
		],
	},

	# ================================================================
	# 第五章：贝多芬 — 暴风雨般的狂想
	# 音乐特征：Locrian 调式（极度不和谐），高 BPM，强烈的动态对比
	# ================================================================
	"boss_beethoven": {
		"bpm_offset": 25,
		"intensity": 0.95,
		"hihat_pattern": "sixteenth",
		"ghost_pattern": "busy",
		"bass_pattern": "driving",
		"kick_volume_boost": 4.0,
		"pad_volume_adjust": -6.0,
		"pitch_shift": 0.0,
		"tonality_override": -1,
		"phase_configs": [
			{ "bpm_offset": 20, "intensity": 0.85, "hihat_pattern": "eighth" },   # 月光
			{ "bpm_offset": 35, "intensity": 1.0, "hihat_pattern": "sixteenth" }, # 暴风雨
		],
	},

	# ================================================================
	# 第六章：艾灵顿 — 摇摆与即兴
	# 音乐特征：Blues 调式，摇摆节奏，即兴感强
	# ================================================================
	"boss_jazz": {
		"bpm_offset": 15,
		"intensity": 0.85,
		"hihat_pattern": "shuffle",   # 摇摆节奏
		"ghost_pattern": "busy",      # 密集的鬼音模拟即兴
		"bass_pattern": "walking",    # 行走低音，爵士标志
		"kick_volume_boost": 1.0,
		"pad_volume_adjust": -3.0,
		"pitch_shift": 0.0,
		"tonality_override": -1,
		"phase_configs": [
			{ "bpm_offset": 15, "intensity": 0.85, "hihat_pattern": "shuffle" },
			{ "bpm_offset": 25, "intensity": 0.95, "hihat_pattern": "sixteenth" },
		],
	},

	# ================================================================
	# 第七章：噪音 — 频谱崩溃
	# 音乐特征：Chromatic（全部半音），极高 BPM，混沌的节奏
	# ================================================================
	"boss_noise": {
		"bpm_offset": 30,
		"intensity": 1.0,
		"hihat_pattern": "sixteenth",
		"ghost_pattern": "busy",
		"bass_pattern": "driving",
		"kick_volume_boost": 5.0,
		"pad_volume_adjust": -8.0,
		"pitch_shift": 0.0,
		"tonality_override": -1,
		"phase_configs": [
			{ "bpm_offset": 20, "intensity": 0.9 },   # 正弦波阶段
			{ "bpm_offset": 25, "intensity": 0.95 },  # 方波阶段
			{ "bpm_offset": 30, "intensity": 0.98 },  # 锯齿波阶段
			{ "bpm_offset": 40, "intensity": 1.0 },   # 白噪音阶段
		],
	},
}

# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	# 连接 BossSpawner 信号（如果存在）
	_connect_boss_signals()

func _connect_boss_signals() -> void:
	var spawner := get_tree().get_first_node_in_group("boss_spawner")
	if spawner == null:
		# 延迟重试
		get_tree().create_timer(0.5).timeout.connect(_connect_boss_signals_deferred)
		return
	_bind_spawner_signals(spawner)

func _connect_boss_signals_deferred() -> void:
	var spawner := get_tree().get_first_node_in_group("boss_spawner")
	if spawner:
		_bind_spawner_signals(spawner)

func _bind_spawner_signals(spawner: Node) -> void:
	if spawner.has_signal("boss_fight_started"):
		if not spawner.boss_fight_started.is_connected(_on_boss_fight_started):
			spawner.boss_fight_started.connect(_on_boss_fight_started)
	if spawner.has_signal("boss_fight_ended"):
		if not spawner.boss_fight_ended.is_connected(_on_boss_fight_ended):
			spawner.boss_fight_ended.connect(_on_boss_fight_ended)

# ============================================================
# 公共接口
# ============================================================

## 进入 Boss 战 BGM 模式
func enter_boss_bgm(boss_key: String) -> void:
	if _is_boss_bgm_active:
		exit_boss_bgm()

	if not BOSS_BGM_CONFIGS.has(boss_key):
		push_warning("BossBGMController: 未找到 Boss '%s' 的 BGM 配置" % boss_key)
		return

	_current_boss_key = boss_key
	_current_phase = 0
	_is_boss_bgm_active = true

	# 保存当前 BGM 状态
	_save_current_state()

	# 应用 Boss BGM 配置
	var config: Dictionary = BOSS_BGM_CONFIGS[boss_key]
	_apply_boss_bgm_config(config)

	boss_bgm_started.emit(boss_key)
	print("[BossBGM] 进入 Boss BGM: %s" % boss_key)

## 退出 Boss 战 BGM 模式，恢复之前的状态
func exit_boss_bgm() -> void:
	if not _is_boss_bgm_active:
		return

	_is_boss_bgm_active = false

	# 平滑恢复到保存的状态
	_restore_saved_state()

	_current_boss_key = ""
	boss_bgm_ended.emit()
	print("[BossBGM] 退出 Boss BGM")

## 响应 Boss 阶段切换
func on_boss_phase_changed(phase_index: int) -> void:
	if not _is_boss_bgm_active:
		return

	var config: Dictionary = BOSS_BGM_CONFIGS.get(_current_boss_key, {})
	var phase_configs: Array = config.get("phase_configs", [])

	if phase_index < phase_configs.size():
		_current_phase = phase_index
		var phase_config: Dictionary = phase_configs[phase_index]
		_apply_phase_config(config, phase_config)
		boss_bgm_phase_changed.emit(phase_index)
		print("[BossBGM] Boss 阶段切换: %d (%s)" % [phase_index, _current_boss_key])

## 检查 Boss BGM 是否激活
func is_boss_bgm_active() -> bool:
	return _is_boss_bgm_active

# ============================================================
# BGM 参数应用
# ============================================================

func _apply_boss_bgm_config(config: Dictionary) -> void:
	var bgm := _get_bgm_manager()
	if bgm == null:
		return

	# 1. BPM 提升
	var bpm_offset: float = config.get("bpm_offset", 10)
	var target_bpm: float = bgm.get_bgm_bpm() + bpm_offset
	_transition_bpm(target_bpm)

	# 2. 强度提升
	var target_intensity: float = config.get("intensity", 0.9)
	_transition_intensity(target_intensity)

	# 3. 节奏型切换
	var hihat_pattern: String = config.get("hihat_pattern", "sixteenth")
	var ghost_pattern: String = config.get("ghost_pattern", "busy")
	var bass_pattern: String = config.get("bass_pattern", "driving")
	bgm.set_hihat_pattern(hihat_pattern)
	bgm.set_ghost_pattern(ghost_pattern)
	bgm.set_bass_pattern(bass_pattern)

	# 4. 音量调整
	var kick_boost: float = config.get("kick_volume_boost", 3.0)
	var pad_adjust: float = config.get("pad_volume_adjust", -4.0)
	_adjust_layer_volumes(kick_boost, pad_adjust)

	# 5. 音调偏移
	var pitch_shift: float = config.get("pitch_shift", 0.0)
	if pitch_shift != 0.0:
		_apply_pitch_shift(pitch_shift)

	# 6. 调性覆盖（如果指定）
	var tonality_override: int = config.get("tonality_override", -1)
	if tonality_override > 0:
		bgm.set_tonality(tonality_override)

func _apply_phase_config(base_config: Dictionary, phase_config: Dictionary) -> void:
	var bgm := _get_bgm_manager()
	if bgm == null:
		return

	# BPM 变化
	if phase_config.has("bpm_offset"):
		var base_bpm: float = _saved_state.get("bpm", 120.0)
		var target_bpm: float = base_bpm + phase_config["bpm_offset"]
		_transition_bpm(target_bpm)

	# 强度变化
	if phase_config.has("intensity"):
		_transition_intensity(phase_config["intensity"])

	# 节奏型变化
	if phase_config.has("hihat_pattern"):
		bgm.set_hihat_pattern(phase_config["hihat_pattern"])
	if phase_config.has("ghost_pattern"):
		bgm.set_ghost_pattern(phase_config["ghost_pattern"])
	if phase_config.has("bass_pattern"):
		bgm.set_bass_pattern(phase_config["bass_pattern"])

# ============================================================
# 状态保存与恢复
# ============================================================

func _save_current_state() -> void:
	var bgm := _get_bgm_manager()
	if bgm == null:
		return

	_saved_state = {
		"bpm": bgm.get_bgm_bpm(),
		"intensity": bgm.get_intensity(),
	}

func _restore_saved_state() -> void:
	var bgm := _get_bgm_manager()
	if bgm == null:
		return

	# 平滑恢复 BPM
	var target_bpm: float = _saved_state.get("bpm", 120.0)
	_transition_bpm(target_bpm)

	# 平滑恢复强度
	var target_intensity: float = _saved_state.get("intensity", 0.5)
	_transition_intensity(target_intensity)

	# 恢复默认节奏型（由 _update_layer_mix 自动处理）
	# 重置音调偏移
	_apply_pitch_shift(0.0)

	_saved_state.clear()

# ============================================================
# 平滑过渡
# ============================================================

## BPM 平滑过渡
func _transition_bpm(target_bpm: float) -> void:
	var bgm := _get_bgm_manager()
	if bgm == null:
		return

	var current_bpm: float = bgm.get_bgm_bpm()
	if abs(current_bpm - target_bpm) < 1.0:
		return

	# 使用 Tween 平滑过渡 BPM
	var tween := create_tween()
	tween.tween_method(func(bpm: float):
		if bgm and is_instance_valid(bgm):
			bgm._bpm = bpm
			bgm._update_timing()
	, current_bpm, target_bpm, bpm_transition_duration)

## 强度平滑过渡
func _transition_intensity(target_intensity: float) -> void:
	var bgm := _get_bgm_manager()
	if bgm == null:
		return

	var current_intensity: float = bgm.get_intensity()
	var tween := create_tween()
	tween.tween_method(func(intensity: float):
		if bgm and is_instance_valid(bgm):
			bgm.set_intensity(intensity)
	, current_intensity, target_intensity, transition_duration)

## 音量调整
func _adjust_layer_volumes(kick_boost: float, pad_adjust: float) -> void:
	var bgm := _get_bgm_manager()
	if bgm == null:
		return

	# Kick 音量提升
	var kick_config: Dictionary = bgm._layer_config.get("kick", {})
	var kick_base: float = kick_config.get("volume_db", -6.0)
	bgm.set_layer_volume("kick", kick_base + kick_boost)

	# Pad 音量调整
	var pad_config: Dictionary = bgm._layer_config.get("pad", {})
	var pad_base: float = pad_config.get("volume_db", -16.0)
	bgm.set_layer_volume("pad", pad_base + pad_adjust)

## 音调偏移
func _apply_pitch_shift(shift: float) -> void:
	var bgm := _get_bgm_manager()
	if bgm == null:
		return

	for layer_name in bgm._layer_config:
		var player: AudioStreamPlayer = bgm._layer_config[layer_name]["player"]
		if player:
			var tween := create_tween()
			tween.tween_property(player, "pitch_scale", 1.0 + shift, 1.0)

# ============================================================
# 信号回调
# ============================================================

func _on_boss_fight_started(boss_name: String) -> void:
	# 从 boss_name 反查 boss_key
	var boss_key := _resolve_boss_key(boss_name)
	if not boss_key.is_empty():
		enter_boss_bgm(boss_key)

func _on_boss_fight_ended(_boss_name: String, _victory: bool) -> void:
	exit_boss_bgm()

# ============================================================
# 辅助方法
# ============================================================

func _get_bgm_manager() -> Node:
	return get_node_or_null("/root/BGMManager")

## 从 Boss 显示名称反查 boss_key
func _resolve_boss_key(boss_name: String) -> String:
	var name_to_key: Dictionary = {
		"律动尊者": "boss_pythagoras",
		"毕达哥拉斯": "boss_pythagoras",
		"圣咏宗师": "boss_guido",
		"圭多": "boss_guido",
		"大构建师": "boss_bach",
		"巴赫": "boss_bach",
		"古典完形": "boss_mozart",
		"莫扎特": "boss_mozart",
		"狂想者": "boss_beethoven",
		"贝多芬": "boss_beethoven",
		"摇摆公爵": "boss_jazz",
		"艾灵顿": "boss_jazz",
		"切分行者": "boss_jazz",
		"合成主脑": "boss_noise",
		"噪音": "boss_noise",
	}

	# 精确匹配
	if name_to_key.has(boss_name):
		return name_to_key[boss_name]

	# 模糊匹配
	for key in name_to_key:
		if boss_name.contains(key):
			return name_to_key[key]

	# 直接作为 key 使用
	if BOSS_BGM_CONFIGS.has(boss_name):
		return boss_name

	push_warning("[BossBGM] 无法解析 Boss 名称: %s" % boss_name)
	return ""
