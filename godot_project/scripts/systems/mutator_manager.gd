## mutator_manager.gd
## 随机变异器管理器 (Autoload)
## Issue #115: 游戏流程完善 — 每局随机事件/变异器
##
## 功能：
##   1. 每局游戏开始时随机选择 1~3 个变异器
##   2. 变异器影响游戏规则（敌人属性、玩家能力、环境效果等）
##   3. 增加重玩价值和策略多样性
##   4. 支持正面/负面/中性三类变异器
##   5. 与 DifficultyManager 协作，高难度下变异器更多/更强
##
## 设计原则：
##   - 每个变异器都有明确的游戏规则修改
##   - 变异器之间不会产生冲突
##   - 玩家在游戏开始时可以看到当前局的变异器
extends Node

# ============================================================
# 信号
# ============================================================
signal mutators_selected(mutator_ids: Array)
signal mutator_activated(mutator_id: String)
signal mutator_deactivated(mutator_id: String)
signal all_mutators_cleared()

# ============================================================
# 变异器类型枚举
# ============================================================
enum MutatorType {
	POSITIVE,   ## 正面效果（对玩家有利）
	NEGATIVE,   ## 负面效果（增加挑战）
	NEUTRAL,    ## 中性效果（改变玩法但不明确有利/不利）
}

# ============================================================
# 变异器注册表 — 至少 10 种变异器
# ============================================================
const MUTATOR_REGISTRY: Dictionary = {
	# ---- 负面变异器（增加挑战） ----
	"speed_demon": {
		"name": "疾速恶魔",
		"name_en": "Speed Demon",
		"description": "所有敌人移动速度 +25%",
		"icon": "💨",
		"type": MutatorType.NEGATIVE,
		"color": Color(1.0, 0.4, 0.3),
		"effects": {
			"enemy_speed_mult": 1.25,
		},
		"weight": 1.0,  ## 选择权重
		"exclusive_with": [],  ## 互斥变异器
	},
	"armored_horde": {
		"name": "铁甲军团",
		"name_en": "Armored Horde",
		"description": "所有敌人 HP +40%",
		"icon": "🛡",
		"type": MutatorType.NEGATIVE,
		"color": Color(0.8, 0.5, 0.2),
		"effects": {
			"enemy_hp_mult": 1.4,
		},
		"weight": 1.0,
		"exclusive_with": [],
	},
	"relentless_tide": {
		"name": "无尽潮涌",
		"name_en": "Relentless Tide",
		"description": "敌人生成速度 +30%，波次间隔 -20%",
		"icon": "🌊",
		"type": MutatorType.NEGATIVE,
		"color": Color(0.3, 0.5, 0.9),
		"effects": {
			"spawn_rate_mult": 1.3,
			"wave_interval_mult": 0.8,
		},
		"weight": 0.9,
		"exclusive_with": [],
	},
	"fatigue_amplifier": {
		"name": "疲劳放大器",
		"name_en": "Fatigue Amplifier",
		"description": "听感疲劳积累速度 +50%",
		"icon": "😵",
		"type": MutatorType.NEGATIVE,
		"color": Color(0.7, 0.3, 0.7),
		"effects": {
			"fatigue_rate_mult": 1.5,
		},
		"weight": 0.8,
		"exclusive_with": ["fatigue_immunity"],
	},
	"glass_cannon_enemies": {
		"name": "玻璃大炮",
		"name_en": "Glass Cannon Enemies",
		"description": "敌人伤害 +60%，但 HP -30%",
		"icon": "💥",
		"type": MutatorType.NEGATIVE,
		"color": Color(1.0, 0.3, 0.1),
		"effects": {
			"enemy_damage_mult": 1.6,
			"enemy_hp_mult": 0.7,
		},
		"weight": 0.9,
		"exclusive_with": ["armored_horde"],
	},

	# ---- 正面变异器（对玩家有利） ----
	"note_harvest": {
		"name": "音符丰收",
		"name_en": "Note Harvest",
		"description": "音符获取量翻倍",
		"icon": "🎵",
		"type": MutatorType.POSITIVE,
		"color": Color(0.3, 0.9, 0.5),
		"effects": {
			"note_drop_mult": 2.0,
		},
		"weight": 1.0,
		"exclusive_with": [],
	},
	"xp_surge": {
		"name": "经验涌流",
		"name_en": "XP Surge",
		"description": "经验获取量 +50%",
		"icon": "⭐",
		"type": MutatorType.POSITIVE,
		"color": Color(1.0, 0.85, 0.2),
		"effects": {
			"xp_gain_mult": 1.5,
		},
		"weight": 1.0,
		"exclusive_with": [],
	},
	"fatigue_immunity": {
		"name": "永恒新鲜",
		"name_en": "Eternal Freshness",
		"description": "听感疲劳积累速度 -40%，恢复速度 +30%",
		"icon": "🌟",
		"type": MutatorType.POSITIVE,
		"color": Color(0.4, 0.9, 1.0),
		"effects": {
			"fatigue_rate_mult": 0.6,
			"fatigue_decay_mult": 1.3,
		},
		"weight": 0.8,
		"exclusive_with": ["fatigue_amplifier"],
	},

	# ---- 中性变异器（改变玩法） ----
	"tempo_shift": {
		"name": "变速节拍",
		"name_en": "Tempo Shift",
		"description": "BPM 随机在 80~160 之间波动",
		"icon": "🎭",
		"type": MutatorType.NEUTRAL,
		"color": Color(0.8, 0.6, 1.0),
		"effects": {
			"bpm_fluctuation": true,
			"bpm_min": 80.0,
			"bpm_max": 160.0,
			"bpm_change_interval": 30.0,
		},
		"weight": 0.7,
		"exclusive_with": [],
	},
	"mirror_match": {
		"name": "镜像对决",
		"name_en": "Mirror Match",
		"description": "敌人数量 -20%，但每个敌人都有反弹护盾（首次命中无效）",
		"icon": "🪞",
		"type": MutatorType.NEUTRAL,
		"color": Color(0.6, 0.8, 1.0),
		"effects": {
			"spawn_rate_mult": 0.8,
			"enemy_has_shield": true,
		},
		"weight": 0.6,
		"exclusive_with": [],
	},
	"crescendo": {
		"name": "渐强",
		"name_en": "Crescendo",
		"description": "玩家伤害每分钟 +5%，但敌人 HP 也每分钟 +8%",
		"icon": "📈",
		"type": MutatorType.NEUTRAL,
		"color": Color(0.9, 0.7, 0.3),
		"effects": {
			"player_damage_scaling_per_min": 0.05,
			"enemy_hp_scaling_per_min": 0.08,
		},
		"weight": 0.8,
		"exclusive_with": [],
	},
	"dissonance_world": {
		"name": "不和谐世界",
		"name_en": "Dissonance World",
		"description": "不和谐音符伤害 +100%，但和谐音符伤害 -20%",
		"icon": "🔥",
		"type": MutatorType.NEUTRAL,
		"color": Color(1.0, 0.2, 0.5),
		"effects": {
			"dissonance_damage_mult": 2.0,
			"consonance_damage_mult": 0.8,
		},
		"weight": 0.7,
		"exclusive_with": [],
	},
}

# ============================================================
# 配置
# ============================================================
## 每局最少变异器数量
@export var min_mutators: int = 1
## 每局最多变异器数量
@export var max_mutators: int = 2

# ============================================================
# 内部状态
# ============================================================
var _active_mutators: Dictionary = {}  ## mutator_id → config
var _mutator_timers: Dictionary = {}   ## 用于时间相关的变异器效果
var _bpm_fluctuation_timer: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	_process_active_mutators(delta)

# ============================================================
# 公共接口
# ============================================================

## 为新一局随机选择变异器
func roll_mutators() -> Array:
	clear_all_mutators()

	# 根据难度调整变异器数量
	var count := randi_range(min_mutators, max_mutators)
	var diff_mgr := get_node_or_null("/root/DifficultyManager")
	if diff_mgr:
		var difficulty: int = diff_mgr.get_difficulty()
		# 高难度下更多变异器
		if difficulty >= 2:  # HARD
			count = randi_range(min_mutators + 1, max_mutators + 1)
		if difficulty >= 3:  # NIGHTMARE
			count = randi_range(min_mutators + 1, max_mutators + 2)

	# 构建可用变异器池
	var available: Array = []
	for mutator_id in MUTATOR_REGISTRY:
		available.append(mutator_id)

	# 加权随机选择
	var selected: Array = []
	for _i in range(count):
		if available.is_empty():
			break

		var chosen_id: String = _weighted_random_select(available)
		if chosen_id.is_empty():
			break

		selected.append(chosen_id)
		available.erase(chosen_id)

		# 移除互斥变异器
		var config: Dictionary = MUTATOR_REGISTRY.get(chosen_id, {})
		var exclusive: Array = config.get("exclusive_with", [])
		for ex_id in exclusive:
			available.erase(ex_id)

	# 激活选中的变异器
	for mutator_id in selected:
		activate_mutator(mutator_id)

	mutators_selected.emit(selected)
	return selected

## 激活指定变异器
func activate_mutator(mutator_id: String) -> void:
	if not MUTATOR_REGISTRY.has(mutator_id):
		push_warning("MutatorManager: Unknown mutator: %s" % mutator_id)
		return

	var config: Dictionary = MUTATOR_REGISTRY[mutator_id].duplicate(true)
	_active_mutators[mutator_id] = config
	mutator_activated.emit(mutator_id)

	# 显示变异器激活提示
	var hint_mgr := get_node_or_null("/root/TutorialHintManager")
	if hint_mgr and hint_mgr.has_method("show_hint"):
		var name: String = config.get("name", mutator_id)
		var desc: String = config.get("description", "")
		var icon: String = config.get("icon", "")
		hint_mgr.show_hint("%s %s — %s" % [icon, name, desc], 4.0)

## 停用指定变异器
func deactivate_mutator(mutator_id: String) -> void:
	if _active_mutators.has(mutator_id):
		_active_mutators.erase(mutator_id)
		mutator_deactivated.emit(mutator_id)

## 清除所有变异器
func clear_all_mutators() -> void:
	_active_mutators.clear()
	_mutator_timers.clear()
	_bpm_fluctuation_timer = 0.0
	all_mutators_cleared.emit()

## 获取当前活跃的变异器列表
func get_active_mutators() -> Dictionary:
	return _active_mutators

## 获取活跃变异器的 ID 列表
func get_active_mutator_ids() -> Array:
	return _active_mutators.keys()

## 获取变异器信息（用于 UI 显示）
func get_mutator_info(mutator_id: String) -> Dictionary:
	return MUTATOR_REGISTRY.get(mutator_id, {})

## 检查变异器是否激活
func is_mutator_active(mutator_id: String) -> bool:
	return _active_mutators.has(mutator_id)

# ============================================================
# 效果查询接口（供其他系统调用）
# ============================================================

## 获取综合敌人 HP 倍率（所有活跃变异器叠加）
func get_enemy_hp_multiplier() -> float:
	var mult := 1.0
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		mult *= effects.get("enemy_hp_mult", 1.0)
	return mult

## 获取综合敌人速度倍率
func get_enemy_speed_multiplier() -> float:
	var mult := 1.0
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		mult *= effects.get("enemy_speed_mult", 1.0)
	return mult

## 获取综合敌人伤害倍率
func get_enemy_damage_multiplier() -> float:
	var mult := 1.0
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		mult *= effects.get("enemy_damage_mult", 1.0)
	return mult

## 获取综合生成频率倍率
func get_spawn_rate_multiplier() -> float:
	var mult := 1.0
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		mult *= effects.get("spawn_rate_mult", 1.0)
	return mult

## 获取综合波次间隔倍率
func get_wave_interval_multiplier() -> float:
	var mult := 1.0
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		mult *= effects.get("wave_interval_mult", 1.0)
	return mult

## 获取综合音符掉落倍率
func get_note_drop_multiplier() -> float:
	var mult := 1.0
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		mult *= effects.get("note_drop_mult", 1.0)
	return mult

## 获取综合经验获取倍率
func get_xp_gain_multiplier() -> float:
	var mult := 1.0
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		mult *= effects.get("xp_gain_mult", 1.0)
	return mult

## 获取综合疲劳积累倍率
func get_fatigue_rate_multiplier() -> float:
	var mult := 1.0
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		mult *= effects.get("fatigue_rate_mult", 1.0)
	return mult

## 获取综合疲劳恢复倍率
func get_fatigue_decay_multiplier() -> float:
	var mult := 1.0
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		mult *= effects.get("fatigue_decay_mult", 1.0)
	return mult

## 检查敌人是否有反弹护盾
func enemies_have_shield() -> bool:
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		if effects.get("enemy_has_shield", false):
			return true
	return false

## 获取不和谐伤害倍率
func get_dissonance_damage_multiplier() -> float:
	var mult := 1.0
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		mult *= effects.get("dissonance_damage_mult", 1.0)
	return mult

## 获取和谐伤害倍率
func get_consonance_damage_multiplier() -> float:
	var mult := 1.0
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		mult *= effects.get("consonance_damage_mult", 1.0)
	return mult

## 获取玩家伤害每分钟缩放
func get_player_damage_scaling_per_min() -> float:
	var total := 0.0
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		total += effects.get("player_damage_scaling_per_min", 0.0)
	return total

## 获取敌人 HP 每分钟缩放
func get_enemy_hp_scaling_per_min() -> float:
	var total := 0.0
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		total += effects.get("enemy_hp_scaling_per_min", 0.0)
	return total

# ============================================================
# 时间相关变异器处理
# ============================================================

func _process_active_mutators(delta: float) -> void:
	# BPM 波动处理
	if _has_effect("bpm_fluctuation"):
		_process_bpm_fluctuation(delta)

	# 渐强效果处理（每分钟缩放）
	var player_scaling: float = get_player_damage_scaling_per_min()
	if player_scaling > 0.0:
		var minutes: float = GameManager.game_time / 60.0
		GameManager.damage_multiplier = 1.0 + player_scaling * minutes

func _process_bpm_fluctuation(delta: float) -> void:
	_bpm_fluctuation_timer += delta

	var interval: float = 30.0
	var bpm_min: float = 80.0
	var bpm_max: float = 160.0

	# 从活跃变异器中获取参数
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		if effects.get("bpm_fluctuation", false):
			interval = effects.get("bpm_change_interval", 30.0)
			bpm_min = effects.get("bpm_min", 80.0)
			bpm_max = effects.get("bpm_max", 160.0)
			break

	if _bpm_fluctuation_timer >= interval:
		_bpm_fluctuation_timer = 0.0
		var new_bpm: float = randf_range(bpm_min, bpm_max)
		var chapter_mgr := get_node_or_null("/root/ChapterManager")
		if chapter_mgr and chapter_mgr.has_method("force_bpm_change"):
			chapter_mgr.force_bpm_change(new_bpm, false)

func _has_effect(effect_key: String) -> bool:
	for mutator_id in _active_mutators:
		var effects: Dictionary = _active_mutators[mutator_id].get("effects", {})
		if effects.has(effect_key) and effects[effect_key]:
			return true
	return false

# ============================================================
# 加权随机选择
# ============================================================

func _weighted_random_select(available_ids: Array) -> String:
	if available_ids.is_empty():
		return ""

	var total_weight: float = 0.0
	for id in available_ids:
		var config: Dictionary = MUTATOR_REGISTRY.get(id, {})
		total_weight += config.get("weight", 1.0)

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0

	for id in available_ids:
		var config: Dictionary = MUTATOR_REGISTRY.get(id, {})
		cumulative += config.get("weight", 1.0)
		if roll <= cumulative:
			return id

	return available_ids[0]
