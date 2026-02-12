## balance_config_v3.gd
## v3.0 数值平衡配置 (Balance Configuration)
##
## 集中管理所有与法术编辑和升级系统相关的数值参数。
## 将原先分散在 spellcraft_system / game_manager / upgrade_panel 中的硬编码数值
## 统一到此配置文件，便于调参和 A/B 测试。
##
## 修改本文件中的数值即可影响全局平衡，无需修改逻辑代码。
##
class_name BalanceConfigV3

# ============================================================
# A. 白键音符基础参数调整
# ============================================================
## v3.0 变更：提高各音符的区分度，让"偏科"音符更极端
## 四维总和从 12 提高到 13，给予玩家更多操作空间

const WHITE_KEY_STATS_V3: Dictionary = {
	# C: 均衡型 — 保持不变，作为基准线
	0: { "dmg": 3, "spd": 3, "dur": 3.5, "size": 3.5, "name": "C", "desc": "均衡型" },
	# D: 极速远程 — 速度从5→6，但伤害从2→1.5
	1: { "dmg": 1.5, "spd": 6, "dur": 3, "size": 2.5, "name": "D", "desc": "极速远程" },
	# E: 大范围持久 — 持续和范围更极端
	2: { "dmg": 1.5, "spd": 2, "dur": 5, "size": 4.5, "name": "E", "desc": "大范围持久" },
	# F: 区域控制 — 速度极低但持续极长
	3: { "dmg": 2, "spd": 0.5, "dur": 6, "size": 4.5, "name": "F", "desc": "区域控制" },
	# G: 爆发伤害 — 伤害从5→6，但持续极短
	4: { "dmg": 6, "spd": 3, "dur": 1.5, "size": 2, "name": "G", "desc": "爆发伤害" },
	# A: 持久高伤 — 平衡的高伤害选择
	5: { "dmg": 4.5, "spd": 2, "dur": 4, "size": 2.5, "name": "A", "desc": "持久高伤" },
	# B: 高速高伤 — 速度和伤害都高，但范围极小
	6: { "dmg": 4.5, "spd": 4.5, "dur": 2, "size": 2, "name": "B", "desc": "高速高伤" },
}

# ============================================================
# B. 和弦法术倍率调整
# ============================================================
## v3.0 变更：
##   - 降低基础三和弦倍率，让七和弦更有吸引力
##   - 提高扩展和弦的风险/回报比

const CHORD_MULTIPLIER_V3: Dictionary = {
	# 三和弦 (基础)
	"MAJOR": 1.3,           # 从1.5降低，大三不再是无脑选择
	"MINOR": 1.1,           # 从1.2降低，DOT需要时间才能超越
	"AUGMENTED": 1.6,       # 从1.8降低，爆炸范围是核心优势
	"DIMINISHED": 1.8,      # 从2.0降低，冲击波仍然强力
	# 七和弦 (进阶) — 倍率相对提高
	"DOMINANT_7": 1.2,      # 法阵持续伤害，总伤害高
	"DIMINISHED_7": 2.8,    # 从3.0降低，天降打击仍然是高风险高回报
	"MAJOR_7": 0.0,         # 治疗不造成伤害
	"MINOR_7": 0.9,         # 召唤物持续输出
	"SUSPENDED": 1.8,       # 蓄力弹体保持不变
	# 扩展和弦 (传说) — 高风险高回报
	"DOMINANT_9": 0.6,      # 风暴区域持续伤害
	"MAJOR_9": 0.0,         # 圣光领域是治疗
	"DIMINISHED_9": 3.5,    # 从4.0降低，湮灭射线
	"DOMINANT_11": 0.7,     # 时空裂隙
	"DOMINANT_13": 1.2,     # 交响风暴
	"DIMINISHED_13": 4.5,   # 从5.0降低，终焉乐章
}

# ============================================================
# C. 疲劳系统参数调整
# ============================================================
## v3.0 变更：
##   - 降低基础疲劳累积速率，让玩家有更多喘息空间
##   - 增加疲劳衰减速率，鼓励短暂切换后回归

const FATIGUE_CONFIG_V3: Dictionary = {
	## 单调疲劳
	"monotony": {
		"base_rate": 0.008,           # 从0.01降低 — 每次重复施法累积
		"threshold_mild": 0.25,       # 轻度阈值
		"threshold_moderate": 0.50,   # 中度阈值
		"threshold_severe": 0.75,     # 重度阈值
		"threshold_critical": 0.90,   # 危险阈值
		"decay_rate": 0.015,          # 从0.01提高 — 切换后衰减更快
		"variety_bonus": 0.02,        # 使用不同音符时额外衰减
	},
	## 不和谐疲劳
	"dissonance": {
		"base_rate": 1.0,             # 每次不和谐和弦累积（乘以和弦不和谐度）
		"decay_rate": 2.0,            # 从1.5提高 — 自然衰减更快
		"threshold_mild": 15.0,
		"threshold_moderate": 30.0,
		"threshold_severe": 50.0,
		"threshold_critical": 70.0,
		"consonance_bonus": 0.5,      # 使用协和和弦时额外衰减
	},
	## 密度疲劳
	"density": {
		"base_rate": 0.005,           # 从0.008降低 — 每个活跃弹体累积
		"decay_rate": 0.02,           # 从0.015提高
		"threshold_mild": 0.30,
		"threshold_moderate": 0.55,
		"threshold_severe": 0.80,
		"threshold_critical": 0.95,
		"rest_bonus": 0.03,           # 休止符额外衰减
	},
}

## 疲劳对效能的影响
const FATIGUE_PENALTY_V3: Dictionary = {
	"none": 1.0,
	"mild": 0.95,        # 从1.0提高惩罚 — 轻度也有微小影响
	"moderate": 0.75,    # 从0.8降低 — 中度惩罚更明显
	"severe": 0.45,      # 从0.5降低
	"critical": 0.15,    # 从0.2降低 — 危险状态几乎无法战斗
}

# ============================================================
# D. 升级数值权重调整
# ============================================================
## v3.0 变更：
##   - 调整各方向升级的出现权重
##   - 确保进攻/防御/核心三方向平衡

const UPGRADE_WEIGHTS_V3: Dictionary = {
	## 方向权重（影响选项池的丰富度）
	"direction_weights": {
		"clockwise": 1.0,       # 进攻方向 — 标准权重
		"current": 0.8,         # 核心方向 — 略低，因为核心升级更强
		"counter_clockwise": 1.0, # 防御方向 — 标准权重
	},

	## 稀有度出现概率
	"rarity_weights": {
		"common": 0.50,    # 50% 概率出现普通
		"rare": 0.35,      # 35% 概率出现稀有
		"epic": 0.12,      # 12% 概率出现史诗
		"legendary": 0.03, # 3% 概率出现传说
	},

	## 升级数值缩放（随等级递增）
	"level_scaling": {
		"stat_per_level": 0.02,    # 每级升级数值增加2%
		"cost_per_level": 1.05,    # 每级费用增加5%
		"max_level_bonus": 0.5,    # 最大等级加成50%
	},

	## 章节词条出现概率
	"inscription_chance": 0.15,    # 15%概率替换一个选项

	## 乐理突破出现概率
	"breakthrough_chance": 0.08,   # 8%概率触发
	"breakthrough_level_min": 3,   # 最低3级才能触发
}

# ============================================================
# E. 节奏系统参数调整
# ============================================================

const RHYTHM_CONFIG_V3: Dictionary = {
	## 节拍对齐窗口（秒）
	"perfect_window": 0.05,    # 完美窗口
	"good_window": 0.12,      # 良好窗口
	"ok_window": 0.20,        # 一般窗口

	## 节拍对齐奖励
	"perfect_bonus": 0.30,    # 完美 +30% 伤害
	"good_bonus": 0.15,       # 良好 +15% 伤害
	"ok_bonus": 0.05,         # 一般 +5% 伤害
	"miss_penalty": -0.10,    # 失误 -10% 伤害

	## BPM 范围
	"bpm_min": 80.0,
	"bpm_max": 200.0,
	"bpm_default": 120.0,
	"bpm_per_chapter": 10.0,  # 每章节 BPM 基础增加
}

# ============================================================
# F. 和弦进行系统参数
# ============================================================

const PROGRESSION_CONFIG_V3: Dictionary = {
	## 功能转换效果倍率
	"D_to_T_burst_mult": 2.0,     # 属→主 爆发倍率
	"T_to_D_empower_mult": 2.0,   # 主→属 增伤倍率
	"PD_to_D_cd_reduction": 0.3,  # 下属→属 冷却缩减30%

	## 完整度奖励
	"completeness_2": 1.0,        # 2音 — 无奖励
	"completeness_3": 1.5,        # 3音 — 50%奖励
	"completeness_4": 2.0,        # 4音 — 100%奖励

	## 和弦功能映射（简化版）
	## 调内和弦 → 功能
	"function_map": {
		"I": "T", "i": "T",
		"ii": "PD", "II": "PD",
		"iii": "T", "III": "T",
		"IV": "PD", "iv": "PD",
		"V": "D", "v": "D",
		"vi": "T", "VI": "T",
		"vii": "D", "VII": "D",
	},
}

# ============================================================
# G. 音色武器参数调整
# ============================================================

const TIMBRE_CONFIG_V3: Dictionary = {
	## 跨章节音色疲劳
	"cross_chapter_fatigue": 0.025,   # 从0.03降低
	## 电子乐变体疲劳减免
	"electronic_fatigue_mult": 0.45,  # 从0.5降低（更多减免）
	## 音色切换冷却（秒）
	"switch_cooldown": 2.0,
	## 音色精通加成上限
	"mastery_cap": 0.5,              # 最多50%加成
}

# ============================================================
# H. 手动施法槽参数
# ============================================================

const MANUAL_SLOT_CONFIG_V3: Dictionary = {
	## 基础冷却时间（秒）
	"base_cooldown": 3.0,
	## 和弦法术冷却倍率
	"chord_cooldown_mult": 1.5,
	## 扩展和弦冷却倍率
	"extended_cooldown_mult": 2.0,
	## 冷却缩减上限
	"max_cdr": 0.5,                  # 最多缩减50%
}

# ============================================================
# I. 序列器参数
# ============================================================

const SEQUENCER_CONFIG_V3: Dictionary = {
	## 小节数
	"measures": 4,
	## 每小节拍数
	"beats_per_measure": 4,
	## 总格数
	"total_cells": 16,
	## 自动循环
	"auto_loop": true,
	## 循环间隔（拍）
	"loop_gap_beats": 0,
	## 空格（休止符）效果
	"rest_regen_per_beat": 1.0,      # 每个休止符恢复1点生命
	"rest_fatigue_decay": 0.005,     # 每个休止符降低疲劳
}

# ============================================================
# J. 局外成长参数
# ============================================================

const META_CONFIG_V3: Dictionary = {
	## 共鸣碎片获取
	"fragments_per_boss": 15,
	"fragments_per_chapter_clear": 30,
	"fragments_per_death": 5,
	"fragments_bonus_no_death": 20,

	## 升级费用缩放
	"cost_base": 10,
	"cost_per_tier": 2.0,           # 每层费用翻倍
	"cost_cap": 200,                # 单个节点最高费用

	## 局外加成上限
	"stat_bonus_cap": 0.30,         # 属性加成最高30%
	"fatigue_resist_cap": 0.40,     # 疲劳抗性最高40%
}

# ============================================================
# 工具方法
# ============================================================

static func get_note_stats(note_key: int) -> Dictionary:
	## 获取v3.0调整后的音符属性
	return WHITE_KEY_STATS_V3.get(note_key, { "dmg": 3, "spd": 3, "dur": 3, "size": 3 })

static func get_chord_multiplier(chord_type: String) -> float:
	## 获取v3.0调整后的和弦倍率
	return CHORD_MULTIPLIER_V3.get(chord_type, 1.0)

static func get_fatigue_penalty(level: String) -> float:
	## 获取v3.0调整后的疲劳惩罚
	return FATIGUE_PENALTY_V3.get(level, 1.0)

static func get_rarity_weight(rarity: String) -> float:
	## 获取稀有度权重
	return UPGRADE_WEIGHTS_V3["rarity_weights"].get(rarity, 0.5)

static func calculate_scaled_value(base_value: float, player_level: int) -> float:
	## 根据玩家等级缩放升级数值
	var scaling: float = UPGRADE_WEIGHTS_V3["level_scaling"]["stat_per_level"]
	var max_bonus: float = UPGRADE_WEIGHTS_V3["level_scaling"]["max_level_bonus"]
	var bonus := min(player_level * scaling, max_bonus)
	return base_value * (1.0 + bonus)

static func calculate_beat_bonus(timing_offset: float) -> float:
	## 根据节拍对齐偏移计算奖励倍率
	var abs_offset := abs(timing_offset)
	if abs_offset <= RHYTHM_CONFIG_V3["perfect_window"]:
		return RHYTHM_CONFIG_V3["perfect_bonus"]
	elif abs_offset <= RHYTHM_CONFIG_V3["good_window"]:
		return RHYTHM_CONFIG_V3["good_bonus"]
	elif abs_offset <= RHYTHM_CONFIG_V3["ok_window"]:
		return RHYTHM_CONFIG_V3["ok_bonus"]
	else:
		return RHYTHM_CONFIG_V3["miss_penalty"]
