## timbre_combat_handler.gd
## 音色战斗机制处理器
## 负责管理和处理7种章节音色的核心战斗机制
## 设计原则：防御性编程，所有外部依赖均通过 get_node_or_null 安全获取
## 作为 Autoload 节点挂载到 /root/TimbreCombatHandler
extends Node

# ============================================================
# 信号
# ============================================================

## 情感高潮爆发触发
signal climax_triggered(intensity: float)
## 声部层数变化
signal organ_layers_changed(layers: int)
## 波形切换
signal waveform_changed(new_waveform: int, old_waveform: int)
## 即兴独奏状态变化
signal improvisation_state_changed(is_active: bool)

# ============================================================
# 波形枚举
# ============================================================

enum WaveformType {
	SINE = 0,      ## 正弦波：高穿透
	SQUARE = 1,    ## 方波：高伤害
	SAWTOOTH = 2,  ## 锯齿波：高范围
	TRIANGLE = 3,  ## 三角波：高速度
}

# ============================================================
# 管弦全奏（emotional_crescendo）状态
# ============================================================

## 当前情感强度 [0, 100]
var emotional_intensity: float = 0.0
const MAX_EMOTIONAL_INTENSITY: float = 100.0

## 高潮爆发是否激活
var _is_climax_active: bool = false
## 高潮爆发剩余时间
var _climax_timer: float = 0.0

# ============================================================
# 萨克斯（swing_attack）状态
# ============================================================

## 连续反拍计数
var _saxophone_offbeat_count: int = 0
## 即兴独奏是否激活
var _is_improvising: bool = false
## 即兴独奏剩余时间
var _improvisation_timer: float = 0.0

# ============================================================
# 合成主脑（waveform_morph）状态
# ============================================================

## 当前波形
var current_waveform: WaveformType = WaveformType.SINE
## 上一个波形（用于过渡混合）
var _previous_waveform: WaveformType = WaveformType.SINE
## 是否正在波形过渡
var _is_morphing: bool = false
## 波形过渡剩余时间
var _morph_transition_timer: float = 0.0

# ============================================================
# 管风琴（harmonic_stacking）状态
# ============================================================

## 当前声部层数 [0, 4]
var organ_voice_layers: int = 0
## 声部层消退计时器
var _organ_layer_decay_timer: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 初始化所有状态
	_reset_all_states()

func _process(delta: float) -> void:
	_update_emotional_crescendo(delta)
	_update_swing_attack(delta)
	_update_waveform_morph(delta)
	_update_harmonic_stacking(delta)

# ============================================================
# 状态重置
# ============================================================

func _reset_all_states() -> void:
	emotional_intensity = 0.0
	_is_climax_active = false
	_climax_timer = 0.0
	_saxophone_offbeat_count = 0
	_is_improvising = false
	_improvisation_timer = 0.0
	current_waveform = WaveformType.SINE
	_previous_waveform = WaveformType.SINE
	_is_morphing = false
	_morph_transition_timer = 0.0
	organ_voice_layers = 0
	_organ_layer_decay_timer = 0.0

# ============================================================
# 状态更新（每帧）
# ============================================================

## 管弦全奏：情感强度衰减 + 高潮计时
func _update_emotional_crescendo(delta: float) -> void:
	if _is_climax_active:
		_climax_timer -= delta
		if _climax_timer <= 0.0:
			_is_climax_active = false
			emotional_intensity = 0.0
	else:
		# 不攻击时情感强度缓慢衰减
		var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.TUTTI)
		var decay_rate: float = params.get("emotion_decay_per_sec", 3.0)
		if emotional_intensity > 0.0:
			emotional_intensity = max(0.0, emotional_intensity - decay_rate * delta)

## 萨克斯：即兴独奏计时
func _update_swing_attack(delta: float) -> void:
	if _is_improvising:
		_improvisation_timer -= delta
		if _improvisation_timer <= 0.0:
			_is_improvising = false
			_saxophone_offbeat_count = 0
			improvisation_state_changed.emit(false)

## 合成主脑：波形过渡计时
func _update_waveform_morph(delta: float) -> void:
	if _is_morphing:
		_morph_transition_timer -= delta
		if _morph_transition_timer <= 0.0:
			_is_morphing = false

## 管风琴：声部层消退
func _update_harmonic_stacking(delta: float) -> void:
	if organ_voice_layers > 0:
		_organ_layer_decay_timer -= delta
		if _organ_layer_decay_timer <= 0.0:
			organ_voice_layers = max(0, organ_voice_layers - 1)
			organ_layers_changed.emit(organ_voice_layers)
			# 重置消退计时器（下一层继续消退）
			if organ_voice_layers > 0:
				var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.ORGAN)
				_organ_layer_decay_timer = params.get("layer_decay_time", 3.0)

# ============================================================
# 外部事件响应
# ============================================================

## 玩家攻击时调用（由 SpellcraftSystem 调用）
func on_player_attack(timbre_type: int) -> void:
	if timbre_type == MusicData.ChapterTimbre.NONE:
		return

	# 管弦全奏：攻击增加情感强度
	if timbre_type == MusicData.ChapterTimbre.TUTTI:
		if not _is_climax_active:
			var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.TUTTI)
			var gain: float = params.get("emotion_gain_per_attack", 2.0)
			emotional_intensity = min(MAX_EMOTIONAL_INTENSITY, emotional_intensity + gain)
			if emotional_intensity >= MAX_EMOTIONAL_INTENSITY:
				_trigger_climax()

	# 管风琴：攻击增加声部层
	if timbre_type == MusicData.ChapterTimbre.ORGAN:
		var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.ORGAN)
		var max_layers: int = params.get("max_voice_layers", 4)
		if organ_voice_layers < max_layers:
			organ_voice_layers = min(max_layers, organ_voice_layers + 1)
			organ_layers_changed.emit(organ_voice_layers)
		# 重置消退计时器
		_organ_layer_decay_timer = params.get("layer_decay_time", 3.0)

## 玩家受伤时调用（由 GameManager 或 Player 调用）
func on_player_hurt() -> void:
	# 管弦全奏：受伤大幅增加情感强度
	var spellcraft := get_node_or_null("/root/SpellcraftSystem")
	if spellcraft == null:
		return

	var current_timbre: int = MusicData.ChapterTimbre.NONE
	if spellcraft.has_method("get_current_chapter_timbre"):
		current_timbre = spellcraft.get_current_chapter_timbre()

	if current_timbre == MusicData.ChapterTimbre.TUTTI:
		if not _is_climax_active:
			var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.TUTTI)
			var gain: float = params.get("emotion_gain_per_hit", 15.0)
			emotional_intensity = min(MAX_EMOTIONAL_INTENSITY, emotional_intensity + gain)
			if emotional_intensity >= MAX_EMOTIONAL_INTENSITY:
				_trigger_climax()

## 切换合成主脑波形
func switch_waveform(new_waveform: WaveformType) -> void:
	if current_waveform == new_waveform:
		return

	var old_waveform := current_waveform
	_previous_waveform = current_waveform
	current_waveform = new_waveform
	_is_morphing = true

	var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.SYNTHESIZER)
	_morph_transition_timer = params.get("morph_transition_time", 0.5)

	waveform_changed.emit(int(new_waveform), int(old_waveform))

# ============================================================
# 高潮爆发触发
# ============================================================

func _trigger_climax() -> void:
	_is_climax_active = true
	var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.TUTTI)
	_climax_timer = params.get("climax_duration", 3.0)
	climax_triggered.emit(emotional_intensity)

# ============================================================
# 法术数据应用（由 SpellcraftSystem 调用）
# ============================================================

## 将音色核心机制应用到法术数据字典
## @param spell_data 法术数据（将被修改）
## @param timbre_type 当前章节音色枚举值
func apply_timbre_mechanics_to_spell(spell_data: Dictionary, timbre_type: int) -> void:
	if timbre_type == MusicData.ChapterTimbre.NONE:
		return

	# 防御性检查：确保 CHAPTER_TIMBRE_ADSR 数据存在
	if not MusicData.CHAPTER_TIMBRE_ADSR.has(timbre_type):
		push_warning("TimbreCombatHandler: 未知的章节音色类型 %d" % timbre_type)
		return

	var core_mechanic: String = MusicData.CHAPTER_TIMBRE_ADSR[timbre_type].get("core_mechanic", "")
	if core_mechanic == "":
		return

	spell_data["core_mechanic"] = core_mechanic

	match core_mechanic:
		"harmonic_resonance":
			_apply_lyre_mechanic(spell_data)
		"harmonic_stacking":
			_apply_organ_mechanic(spell_data)
		"counterpoint_weave":
			_apply_harpsichord_mechanic(spell_data)
		"velocity_dynamics":
			_apply_fortepiano_mechanic(spell_data)
		"emotional_crescendo":
			_apply_tutti_mechanic(spell_data)
		"swing_attack":
			_apply_saxophone_mechanic(spell_data)
		"waveform_morph":
			_apply_synthesizer_mechanic(spell_data)
		_:
			push_warning("TimbreCombatHandler: 未知的核心机制 '%s'" % core_mechanic)

# ============================================================
# 各音色法术数据应用（私有）
# ============================================================

## Ch1 里拉琴 — 泛音共鸣
## 记录基础飞行距离，用于命中时的数学比例伤害加成
func _apply_lyre_mechanic(spell_data: Dictionary) -> void:
	var speed: float = spell_data.get("speed", 600.0)
	var duration: float = spell_data.get("duration", 1.5)
	spell_data["base_distance"] = speed * duration
	# spawn_position 在 projectile_manager 中设置（玩家位置）

## Ch2 管风琴 — 和声层叠
## 根据当前声部层数增加伤害和范围；达到最大层时激活圣咏状态
func _apply_organ_mechanic(spell_data: Dictionary) -> void:
	var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.ORGAN)
	var size_bonus: float = params.get("size_per_layer", 0.10)
	var dmg_bonus: float = params.get("damage_per_layer", 0.08)
	var max_layers: int = params.get("max_voice_layers", 4)

	# 防御性：确保 organ_voice_layers 在有效范围内
	var layers: int = clampi(organ_voice_layers, 0, max_layers)

	if layers > 0:
		spell_data["size"] = spell_data.get("size", 24.0) * (1.0 + size_bonus * layers)
		spell_data["damage"] = spell_data.get("damage", 30.0) * (1.0 + dmg_bonus * layers)

	spell_data["organ_layers"] = layers

	# 达到最大层数时激活圣咏状态
	if layers >= max_layers:
		spell_data["is_chanting"] = true

## Ch3 羽管键琴 — 对位交织
## 标记需要生成镜像对位弹体
func _apply_harpsichord_mechanic(spell_data: Dictionary) -> void:
	var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.HARPSICHORD)
	spell_data["needs_counterpoint"] = true
	spell_data["counterpoint_delay"] = params.get("counterpoint_delay", 0.2)

## Ch4 钢琴 — 力度动态
## 根据节拍精准度判定 forte/mezzo/piano 三种力度
func _apply_fortepiano_mechanic(spell_data: Dictionary) -> void:
	var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.FORTEPIANO)

	# 安全获取节拍进度
	var beat_progress: float = 0.5  # 默认中间值（mezzo）
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager != null and game_manager.has_method("get_beat_progress"):
		beat_progress = game_manager.get_beat_progress()

	var timing_window: float = params.get("forte_timing_window", 0.05)
	var is_forte: bool = beat_progress < timing_window or beat_progress > (1.0 - timing_window)
	var is_piano: bool = beat_progress > 0.2 and beat_progress < 0.8

	if is_forte:
		spell_data["velocity_dynamics"] = "forte"
		spell_data["damage"] = spell_data.get("damage", 30.0) * params.get("forte_multiplier", 1.5)
		spell_data["size"] = spell_data.get("size", 24.0) * 1.2
		if params.get("forte_knockback", true):
			spell_data["has_knockback"] = true
	elif is_piano:
		spell_data["velocity_dynamics"] = "piano"
		spell_data["damage"] = spell_data.get("damage", 30.0) * params.get("piano_multiplier", 0.7)
		spell_data["size"] = spell_data.get("size", 24.0) * 0.8
	else:
		spell_data["velocity_dynamics"] = "mezzo"
		spell_data["damage"] = spell_data.get("damage", 30.0) * params.get("mezzo_multiplier", 1.0)

## Ch5 管弦全奏 — 情感爆发
## 根据情感强度计量条调整伤害和范围；满量时触发高潮爆发
func _apply_tutti_mechanic(spell_data: Dictionary) -> void:
	var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.TUTTI)

	if _is_climax_active:
		# 高潮爆发：最高倍率
		spell_data["damage"] = spell_data.get("damage", 30.0) * params.get("climax_damage_mult", 2.0)
		spell_data["size"] = spell_data.get("size", 24.0) * 1.5
		spell_data["is_climax"] = true
	elif emotional_intensity < params.get("pianissimo_threshold", 30):
		# 极弱：低强度
		spell_data["damage"] = spell_data.get("damage", 30.0) * 0.8
		spell_data["size"] = spell_data.get("size", 24.0) * 0.8
	elif emotional_intensity >= params.get("forte_threshold", 70):
		# 强奏：高强度
		spell_data["damage"] = spell_data.get("damage", 30.0) * params.get("fortissimo_damage_mult", 1.5)
		spell_data["size"] = spell_data.get("size", 24.0) * params.get("fortissimo_size_mult", 1.3)
	# else: 中等强度，保持原始数值
	
	# 触发 VFX 信号
	timbre_vfx_triggered.emit(MusicData.ChapterTimbre.TUTTI, {
		"emotional_intensity": emotional_intensity,
		"is_climax": _is_climax_active
	})

## Ch6 萨克斯 — 摇摆攻击
## 检测反拍触发加成；累积反拍次数触发即兴独奏
func _apply_saxophone_mechanic(spell_data: Dictionary) -> void:
	var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.SAXOPHONE)

	# 安全获取节拍进度
	var beat_progress: float = 0.5
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager != null and game_manager.has_method("get_beat_progress"):
		beat_progress = game_manager.get_beat_progress()

	# 反拍判定：节拍中间区间（0.4~0.6）
	var is_offbeat: bool = beat_progress > 0.4 and beat_progress < 0.6

	if is_offbeat:
		# 反拍加成
		spell_data["damage"] = spell_data.get("damage", 30.0) * (1.0 + params.get("offbeat_damage_bonus", 0.25))
		spell_data["_wave_trajectory"] = true  # S型弹道
		_saxophone_offbeat_count += 1

		# 检查是否触发即兴独奏
		if _saxophone_offbeat_count >= params.get("improvisation_threshold", 3):
			_saxophone_offbeat_count = 0
			_is_improvising = true
			_improvisation_timer = params.get("improvisation_duration", 5.0)
			improvisation_state_changed.emit(true)
	else:
		# 正拍：重置连续计数，添加摇摆延迟
		_saxophone_offbeat_count = 0
		var swing_delay: float = params.get("swing_delay_ratio", 0.33)
		var bpm: float = 120.0
		if game_manager != null and game_manager.get("current_bpm") != null:
			bpm = float(game_manager.current_bpm)
		spell_data["time_alive"] = spell_data.get("time_alive", 0.0) - swing_delay * (60.0 / bpm)

	# 即兴独奏：追踪弹体
	if _is_improvising:
		spell_data["homing"] = true
		spell_data["homing_strength"] = 6.0
		
	# 触发 VFX 信号
	timbre_vfx_triggered.emit(MusicData.ChapterTimbre.SAXOPHONE, {
		"is_offbeat": is_offbeat,
		"is_improvising": _is_improvising
	})

## Ch7 合成主脑 — 波形变换
## 根据当前波形应用不同属性加成；过渡期混合两种波形效果
func _apply_synthesizer_mechanic(spell_data: Dictionary) -> void:
	var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.SYNTHESIZER)
	var bonus: float = params.get("waveform_bonus", 0.30)
	var penalty: float = params.get("waveform_penalty", 0.10)

	# 应用当前波形效果
	_apply_waveform_stats(spell_data, current_waveform, bonus, penalty, params)

	# 过渡期：混合上一个波形效果
	if _is_morphing:
		var blend_ratio: float = params.get("morph_blend_ratio", 0.5)
		# 撤销部分当前效果，添加部分上一个效果
		_apply_waveform_stats(spell_data, current_waveform, -bonus * blend_ratio, -penalty * blend_ratio, params)
		_apply_waveform_stats(spell_data, _previous_waveform, bonus * blend_ratio, penalty * blend_ratio, params)

## 应用单个波形的属性修改
func _apply_waveform_stats(spell_data: Dictionary, wave: WaveformType, bonus: float, penalty: float, params: Dictionary) -> void:
	# 先对所有属性施加惩罚
	spell_data["damage"] = spell_data.get("damage", 30.0) * (1.0 - penalty)
	spell_data["speed"] = spell_data.get("speed", 600.0) * (1.0 - penalty)
	spell_data["size"] = spell_data.get("size", 24.0) * (1.0 - penalty)

	# 再对对应属性施加加成
	match wave:
		WaveformType.SINE:
			# 正弦波：高穿透（恢复伤害惩罚）
			spell_data["damage"] = spell_data.get("damage", 30.0) / (1.0 - penalty)
			spell_data["pierce"] = true
			spell_data["max_pierce"] = spell_data.get("max_pierce", 0) + 2
		WaveformType.SQUARE:
			# 方波：高伤害（恢复伤害惩罚并加成）
			spell_data["damage"] = spell_data.get("damage", 30.0) / (1.0 - penalty) * (1.0 + bonus)
		WaveformType.SAWTOOTH:
			# 锯齿波：高范围（恢复范围惩罚并加成）
			spell_data["size"] = spell_data.get("size", 24.0) / (1.0 - penalty) * (1.0 + bonus)
		WaveformType.TRIANGLE:
			# 三角波：高速度（恢复速度惩罚并加成）
			spell_data["speed"] = spell_data.get("speed", 600.0) / (1.0 - penalty) * (1.0 + bonus)

# ============================================================
# 弹体运行时处理（由 ProjectileManager 调用）
# ============================================================

## 处理弹体每帧的音色机制
## @param proj 弹体数据字典（将被修改）
## @param delta 帧时间
## @param manager ProjectileManager 节点引用
func process_projectile_timbre_mechanics(proj: Dictionary, delta: float, manager: Node) -> void:
	var core_mechanic: String = proj.get("core_mechanic", "")
	if core_mechanic == "":
		return

	match core_mechanic:
		"counterpoint_weave":
			_process_harpsichord_projectile(proj, delta, manager)
		"harmonic_resonance":
			_process_lyre_projectile(proj, delta, manager)
		# 其他机制在弹体飞行时无需特殊处理

## Ch3 羽管键琴：延迟生成对位弹体
func _process_harpsichord_projectile(proj: Dictionary, delta: float, manager: Node) -> void:
	if not proj.get("needs_counterpoint", false):
		return

	var delay: float = proj.get("counterpoint_delay", 0.2)
	if proj.get("time_alive", 0.0) < delay:
		return

	# 标记已处理，防止重复生成
	proj["needs_counterpoint"] = false

	# 获取玩家位置（用于计算镜像）
	var player_pos: Vector2 = Vector2.ZERO
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		player_pos = player.global_position

	# 计算镜像位置
	var offset: Vector2 = proj["position"] - player_pos
	var mirror_pos: Vector2 = player_pos - offset

	var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.HARPSICHORD)
	var dmg_ratio: float = params.get("counterpoint_damage_ratio", 0.5)

	# 复制弹体数据，创建对位弹体
	var counterpoint := proj.duplicate()
	counterpoint["position"] = mirror_pos
	counterpoint["velocity"] = -proj["velocity"]
	counterpoint["damage"] = proj.get("damage", 30.0) * dmg_ratio
	counterpoint["needs_counterpoint"] = false
	counterpoint["is_counterpoint"] = true
	# 对位弹体颜色半透明
	var cp_color: Color = proj.get("color", Color.WHITE)
	cp_color.a *= 0.5
	counterpoint["color"] = cp_color
	# 重置拖尾数据（避免共享引用）
	counterpoint["trail_positions"] = [] as Array[Vector2]

	# 建立父子关联 ID（用于对位共鸣爆发检测）
	var pid: int = proj.get("id", randi())
	proj["id"] = pid
	counterpoint["parent_id"] = pid

	# 防御性检查：manager 必须有 _projectiles 属性
	if manager != null and manager.get("_projectiles") != null:
		manager._projectiles.append(counterpoint)

## Ch1 里拉琴：实时更新飞行距离
func _process_lyre_projectile(proj: Dictionary, _delta: float, _manager: Node) -> void:
	if not proj.has("spawn_position"):
		proj["spawn_position"] = proj["position"]
	proj["travel_distance"] = proj["position"].distance_to(proj["spawn_position"])

# ============================================================
# 弹体命中处理（由 ProjectileManager 调用）
# ============================================================

## 处理弹体命中敌人时的音色机制
## @param proj 命中的弹体数据
## @param enemy_pos 敌人位置
## @param manager ProjectileManager 节点引用
func process_hit_timbre_mechanics(proj: Dictionary, enemy_pos: Vector2, manager: Node) -> void:
	var core_mechanic: String = proj.get("core_mechanic", "")
	if core_mechanic == "":
		return

	match core_mechanic:
		"harmonic_resonance":
			_hit_lyre_mechanic(proj, enemy_pos, manager)
		"harmonic_stacking":
			_hit_organ_mechanic(proj, enemy_pos, manager)
		"counterpoint_weave":
			_hit_harpsichord_mechanic(proj, enemy_pos, manager)
		"velocity_dynamics":
			_hit_fortepiano_mechanic(proj, enemy_pos, manager)
		"emotional_crescendo":
			_hit_tutti_mechanic(proj, enemy_pos, manager)
		# swing_attack 和 waveform_morph 命中时无特殊 AOE 效果

## Ch1 里拉琴：命中时根据飞行距离计算泛音共鸣伤害加成 + 生成 AOE 波纹
func _hit_lyre_mechanic(proj: Dictionary, enemy_pos: Vector2, manager: Node) -> void:
	if manager == null or manager.get("_projectiles") == null:
		return

	var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.LYRE)
	var base_dist: float = proj.get("base_distance", 600.0)
	var travel_dist: float = proj.get("travel_distance", 0.0)

	# 计算数学比例伤害加成
	if base_dist > 0.0:
		var ratio: float = travel_dist / base_dist
		var bonus: float = 0.0

		# 检查是否接近简单整数比（误差容忍 ±0.1）
		if abs(ratio - 2.0) < 0.1:
			bonus = params.get("ratio_bonus_2_1", 0.30)  # 2:1 八度
		elif abs(ratio - 1.5) < 0.1:
			bonus = params.get("ratio_bonus_3_2", 0.20)  # 3:2 纯五度
		elif abs(ratio - 1.33) < 0.1:
			bonus = params.get("ratio_bonus_4_3", 0.10)  # 4:3 纯四度

		if bonus > 0.0:
			proj["damage"] = proj.get("damage", 30.0) * (1.0 + bonus)

	# 生成泛音波纹 AOE
	var resonance := {
		"position": enemy_pos,
		"velocity": Vector2.ZERO,
		"damage": proj.get("damage", 30.0) * params.get("resonance_damage_ratio", 0.15),
		"size": params.get("resonance_radius", 60.0),
		"duration": 0.3,
		"time_alive": 0.0,
		"color": Color(1.0, 0.9, 0.5, 0.6),
		"active": true,
		"is_explosion_effect": true,
		"modifier": -1,
	}
	manager._projectiles.append(resonance)

## Ch2 管风琴：命中时若处于圣咏状态，生成圣咏持续伤害区域
func _hit_organ_mechanic(proj: Dictionary, enemy_pos: Vector2, manager: Node) -> void:
	if manager == null or manager.get("_projectiles") == null:
		return
	if not proj.get("is_chanting", false):
		return

	var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.ORGAN)
	var chant_field := {
		"position": enemy_pos,
		"velocity": Vector2.ZERO,
		"damage": proj.get("damage", 30.0) * 0.2,
		"size": proj.get("size", 24.0) * 1.5,
		"duration": params.get("chant_duration", 2.0),
		"time_alive": 0.0,
		"color": Color(0.8, 0.8, 1.0, 0.4),
		"active": true,
		"is_field": true,
		"field_type": "chant",
		"field_tick_interval": 0.5,
		"field_tick_timer": 0.0,
		"field_tick_count": 0,
		"rotation": 0.0,
		"rotation_speed": 0.5,
		"pulse_phase": 0.0,
		"modifier": -1,
	}
	manager._projectiles.append(chant_field)

## Ch3 羽管键琴：命中时触发对位共鸣爆发
func _hit_harpsichord_mechanic(proj: Dictionary, enemy_pos: Vector2, manager: Node) -> void:
	if manager == null or manager.get("_projectiles") == null:
		return

	# 只有对位弹体或有 parent_id 的弹体才触发共鸣爆发
	var parent_id: int = proj.get("parent_id", proj.get("id", -1))
	if parent_id == -1:
		return

	var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.HARPSICHORD)
	var resonance_bonus: float = params.get("resonance_bonus", 0.30)

	var resonance := {
		"position": enemy_pos,
		"velocity": Vector2.ZERO,
		"damage": proj.get("damage", 30.0) * resonance_bonus,
		"size": proj.get("size", 24.0) * 2.0,
		"duration": 0.2,
		"time_alive": 0.0,
		"color": Color(0.9, 0.7, 0.2, 0.8),
		"active": true,
		"is_explosion_effect": true,
		"modifier": -1,
	}
	manager._projectiles.append(resonance)

## Ch4 钢琴：forte 命中时生成击退冲击波
func _hit_fortepiano_mechanic(proj: Dictionary, enemy_pos: Vector2, manager: Node) -> void:
	if manager == null or manager.get("_projectiles") == null:
		return
	if proj.get("velocity_dynamics", "") != "forte":
		return
	if not proj.get("knockback", false):
		return

	# forte 命中时生成小型冲击波（视觉效果）
	var shockwave := {
		"position": enemy_pos,
		"velocity": Vector2.ZERO,
		"damage": 0.0,  # 纯视觉效果，伤害已在主弹体处理
		"size": 10.0,
		"max_size": 40.0,
		"expand_speed": 300.0,
		"duration": 0.2,
		"time_alive": 0.0,
		"color": Color(1.0, 0.95, 0.7, 0.5),
		"active": true,
		"is_shockwave": true,
		"modifier": -1,
	}
	manager._projectiles.append(shockwave)

## Ch5 管弦全奏：高潮状态命中时生成额外爆发
func _hit_tutti_mechanic(proj: Dictionary, enemy_pos: Vector2, manager: Node) -> void:
	if manager == null or manager.get("_projectiles") == null:
		return
	if not proj.get("is_climax", false):
		return

	# 高潮爆发：额外冲击波
	var params: Dictionary = _get_mechanic_params(MusicData.ChapterTimbre.TUTTI)
	var burst := {
		"position": enemy_pos,
		"velocity": Vector2.ZERO,
		"damage": proj.get("damage", 30.0) * 0.3,
		"size": 10.0,
		"max_size": 100.0,
		"expand_speed": 400.0,
		"duration": 0.4,
		"time_alive": 0.0,
		"color": Color(1.0, 0.5, 0.0, 0.7),
		"active": true,
		"is_shockwave": true,
		"is_aoe": true,
		"modifier": -1,
	}
	manager._projectiles.append(burst)

# ============================================================
# 状态查询接口
# ============================================================

## 获取当前情感强度（0.0 ~ 1.0 归一化）
func get_emotional_intensity_normalized() -> float:
	return emotional_intensity / MAX_EMOTIONAL_INTENSITY

## 是否处于高潮爆发状态
func is_climax_active() -> bool:
	return _is_climax_active

## 是否处于即兴独奏状态
func is_improvising() -> bool:
	return _is_improvising

## 获取当前波形名称
func get_waveform_name() -> String:
	match current_waveform:
		WaveformType.SINE:
			return "sine"
		WaveformType.SQUARE:
			return "square"
		WaveformType.SAWTOOTH:
			return "sawtooth"
		WaveformType.TRIANGLE:
			return "triangle"
	return "unknown"

## 获取当前声部层数
func get_organ_layers() -> int:
	return organ_voice_layers

# ============================================================
# 辅助函数
# ============================================================

## 安全获取音色机制参数
func _get_mechanic_params(timbre: int) -> Dictionary:
	if MusicData == null:
		return {}
	if not MusicData.TIMBRE_MECHANIC_PARAMS.has(timbre):
		return {}
	return MusicData.TIMBRE_MECHANIC_PARAMS[timbre]
