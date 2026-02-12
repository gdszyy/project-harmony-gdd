## difficulty_manager.gd
## 难度选择管理器 (Autoload)
## Issue #115: 游戏流程完善 — 难度选择系统
##
## 功能：
##   1. 提供 4 种难度等级（和声入门 / 标准演奏 / 大师挑战 / 噩梦交响）
##   2. 影响敌人 HP/伤害倍率、波次间隔、Boss 属性
##   3. 与 ChapterManager / EnemySpawner / BossSpawner 协作
##   4. 在主菜单中提供难度选择 UI
##
## 难度参数设计参考 chapter_data.gd 的 difficulty_scaling 模式
extends Node

# ============================================================
# 信号
# ============================================================
signal difficulty_changed(new_difficulty: int)

# ============================================================
# 难度枚举
# ============================================================
enum Difficulty {
	EASY,       ## 和声入门 — 适合新手
	NORMAL,     ## 标准演奏 — 默认难度
	HARD,       ## 大师挑战 — 高难度
	NIGHTMARE,  ## 噩梦交响 — 极限挑战
}

# ============================================================
# 难度配置数据
# ============================================================
const DIFFICULTY_CONFIGS: Dictionary = {
	Difficulty.EASY: {
		"name": "和声入门",
		"name_en": "Harmonic Prelude",
		"description": "适合初次接触的玩家。敌人较弱，节奏宽容。",
		"icon": "♩",
		"color": Color(0.3, 0.8, 0.5),

		# 敌人属性倍率
		"enemy_hp_mult": 0.6,
		"enemy_damage_mult": 0.5,
		"enemy_speed_mult": 0.8,

		# 生成频率
		"spawn_rate_mult": 0.7,
		"wave_interval_mult": 1.4,  ## 波次间隔更长

		# Boss 属性
		"boss_hp_mult": 0.5,
		"boss_damage_mult": 0.5,
		"boss_speed_mult": 0.8,

		# 玩家增益
		"player_hp_mult": 1.3,
		"xp_gain_mult": 1.2,
		"note_drop_mult": 1.3,

		# 疲劳系统
		"fatigue_rate_mult": 0.7,  ## 疲劳积累更慢
		"fatigue_decay_mult": 1.3,  ## 疲劳恢复更快

		# 奖励倍率
		"score_mult": 0.5,
		"resonance_fragment_mult": 0.7,
	},
	Difficulty.NORMAL: {
		"name": "标准演奏",
		"name_en": "Standard Performance",
		"description": "平衡的游戏体验。推荐大多数玩家选择。",
		"icon": "♪",
		"color": Color(0.3, 0.6, 1.0),

		"enemy_hp_mult": 1.0,
		"enemy_damage_mult": 1.0,
		"enemy_speed_mult": 1.0,

		"spawn_rate_mult": 1.0,
		"wave_interval_mult": 1.0,

		"boss_hp_mult": 1.0,
		"boss_damage_mult": 1.0,
		"boss_speed_mult": 1.0,

		"player_hp_mult": 1.0,
		"xp_gain_mult": 1.0,
		"note_drop_mult": 1.0,

		"fatigue_rate_mult": 1.0,
		"fatigue_decay_mult": 1.0,

		"score_mult": 1.0,
		"resonance_fragment_mult": 1.0,
	},
	Difficulty.HARD: {
		"name": "大师挑战",
		"name_en": "Maestro Challenge",
		"description": "为熟练玩家准备。敌人更强，节奏更紧凑。",
		"icon": "♫",
		"color": Color(1.0, 0.6, 0.2),

		"enemy_hp_mult": 1.5,
		"enemy_damage_mult": 1.4,
		"enemy_speed_mult": 1.2,

		"spawn_rate_mult": 1.3,
		"wave_interval_mult": 0.8,

		"boss_hp_mult": 1.6,
		"boss_damage_mult": 1.4,
		"boss_speed_mult": 1.15,

		"player_hp_mult": 0.9,
		"xp_gain_mult": 0.9,
		"note_drop_mult": 0.85,

		"fatigue_rate_mult": 1.2,
		"fatigue_decay_mult": 0.85,

		"score_mult": 1.5,
		"resonance_fragment_mult": 1.3,
	},
	Difficulty.NIGHTMARE: {
		"name": "噩梦交响",
		"name_en": "Nightmare Symphony",
		"description": "极限挑战。只有最优秀的指挥家才能生还。",
		"icon": "𝄞",
		"color": Color(0.9, 0.15, 0.15),

		"enemy_hp_mult": 2.2,
		"enemy_damage_mult": 2.0,
		"enemy_speed_mult": 1.4,

		"spawn_rate_mult": 1.6,
		"wave_interval_mult": 0.6,

		"boss_hp_mult": 2.5,
		"boss_damage_mult": 2.0,
		"boss_speed_mult": 1.3,

		"player_hp_mult": 0.7,
		"xp_gain_mult": 0.8,
		"note_drop_mult": 0.7,

		"fatigue_rate_mult": 1.5,
		"fatigue_decay_mult": 0.7,

		"score_mult": 2.5,
		"resonance_fragment_mult": 2.0,
	},
}

# ============================================================
# 状态
# ============================================================
var _current_difficulty: int = Difficulty.NORMAL

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 从存档加载上次选择的难度
	_load_difficulty()

# ============================================================
# 公共接口
# ============================================================

## 设置难度
func set_difficulty(difficulty: int) -> void:
	if difficulty < Difficulty.EASY or difficulty > Difficulty.NIGHTMARE:
		push_warning("DifficultyManager: Invalid difficulty level: %d" % difficulty)
		return

	_current_difficulty = difficulty
	_save_difficulty()
	difficulty_changed.emit(difficulty)

## 获取当前难度
func get_difficulty() -> int:
	return _current_difficulty

## 获取当前难度配置
func get_config() -> Dictionary:
	return DIFFICULTY_CONFIGS.get(_current_difficulty, DIFFICULTY_CONFIGS[Difficulty.NORMAL])

## 获取指定难度的配置
func get_config_for(difficulty: int) -> Dictionary:
	return DIFFICULTY_CONFIGS.get(difficulty, DIFFICULTY_CONFIGS[Difficulty.NORMAL])

## 获取难度名称
func get_difficulty_name() -> String:
	var config: Dictionary = get_config()
	return config.get("name", "标准演奏")

## 获取难度英文名称
func get_difficulty_name_en() -> String:
	var config: Dictionary = get_config()
	return config.get("name_en", "Standard Performance")

## 获取敌人 HP 倍率（综合难度 + 章节缩放）
func get_enemy_hp_multiplier() -> float:
	var config: Dictionary = get_config()
	return config.get("enemy_hp_mult", 1.0)

## 获取敌人伤害倍率
func get_enemy_damage_multiplier() -> float:
	var config: Dictionary = get_config()
	return config.get("enemy_damage_mult", 1.0)

## 获取敌人速度倍率
func get_enemy_speed_multiplier() -> float:
	var config: Dictionary = get_config()
	return config.get("enemy_speed_mult", 1.0)

## 获取生成频率倍率
func get_spawn_rate_multiplier() -> float:
	var config: Dictionary = get_config()
	return config.get("spawn_rate_mult", 1.0)

## 获取波次间隔倍率
func get_wave_interval_multiplier() -> float:
	var config: Dictionary = get_config()
	return config.get("wave_interval_mult", 1.0)

## 获取 Boss HP 倍率
func get_boss_hp_multiplier() -> float:
	var config: Dictionary = get_config()
	return config.get("boss_hp_mult", 1.0)

## 获取 Boss 伤害倍率
func get_boss_damage_multiplier() -> float:
	var config: Dictionary = get_config()
	return config.get("boss_damage_mult", 1.0)

## 获取玩家 HP 倍率
func get_player_hp_multiplier() -> float:
	var config: Dictionary = get_config()
	return config.get("player_hp_mult", 1.0)

## 获取经验获取倍率
func get_xp_gain_multiplier() -> float:
	var config: Dictionary = get_config()
	return config.get("xp_gain_mult", 1.0)

## 获取疲劳积累倍率
func get_fatigue_rate_multiplier() -> float:
	var config: Dictionary = get_config()
	return config.get("fatigue_rate_mult", 1.0)

## 获取疲劳恢复倍率
func get_fatigue_decay_multiplier() -> float:
	var config: Dictionary = get_config()
	return config.get("fatigue_decay_mult", 1.0)

## 获取分数倍率
func get_score_multiplier() -> float:
	var config: Dictionary = get_config()
	return config.get("score_mult", 1.0)

## 获取共鸣碎片倍率
func get_resonance_fragment_multiplier() -> float:
	var config: Dictionary = get_config()
	return config.get("resonance_fragment_mult", 1.0)

## 获取所有难度选项（用于 UI 显示）
func get_all_difficulties() -> Array:
	var result: Array = []
	for diff_key in DIFFICULTY_CONFIGS:
		var config: Dictionary = DIFFICULTY_CONFIGS[diff_key]
		result.append({
			"id": diff_key,
			"name": config.get("name", ""),
			"name_en": config.get("name_en", ""),
			"description": config.get("description", ""),
			"icon": config.get("icon", ""),
			"color": config.get("color", Color.WHITE),
		})
	return result

# ============================================================
# 存档
# ============================================================

func _save_difficulty() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("set_data"):
		save_mgr.set_data("selected_difficulty", _current_difficulty)

func _load_difficulty() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("get_data"):
		var save_data: Dictionary = save_mgr.get_data()
		_current_difficulty = save_data.get("selected_difficulty", Difficulty.NORMAL)
