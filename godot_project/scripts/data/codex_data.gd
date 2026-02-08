## codex_data.gd
## 图鉴系统 "谐振法典 (Codex Resonare)" 静态数据定义
## 包含四卷图鉴的所有条目元数据：
##   第一卷：乐理纲要 — 音符、和弦、节奏型、调式
##   第二卷：百相众声 — 音色系别与神韵效果
##   第三卷：失谐魔物 — 敌人、精英、Boss
##   第四卷：神兵乐章 — 法术形态、修饰符、和弦进行
class_name CodexData

# ============================================================
# 图鉴卷枚举
# ============================================================
enum Volume {
	MUSIC_THEORY,      ## 第一卷：乐理纲要
	TIMBRE_GALLERY,    ## 第二卷：百相众声
	BESTIARY,          ## 第三卷：失谐魔物
	SPELL_COMPENDIUM,  ## 第四卷：神兵乐章
}

# ============================================================
# 条目解锁条件类型
# ============================================================
enum UnlockType {
	DEFAULT,           ## 默认解锁
	META_UNLOCK,       ## 通过局外成长（和谐殿堂）解锁
	ENCOUNTER,         ## 遭遇/击败敌人解锁
	CAST_SPELL,        ## 施放对应法术解锁
	KILL_COUNT,        ## 击杀指定数量解锁
	CHAPTER_CLEAR,     ## 通关章节解锁
}

# ============================================================
# 条目稀有度（影响边框颜色和展示效果）
# ============================================================
enum Rarity {
	COMMON,            ## 普通 — 白色
	UNCOMMON,          ## 非凡 — 绿色
	RARE,              ## 稀有 — 蓝色
	EPIC,              ## 史诗 — 紫色
	LEGENDARY,         ## 传说 — 金色
}

const RARITY_COLORS: Dictionary = {
	Rarity.COMMON:    Color(0.7, 0.7, 0.75),
	Rarity.UNCOMMON:  Color(0.3, 0.9, 0.4),
	Rarity.RARE:      Color(0.3, 0.5, 1.0),
	Rarity.EPIC:      Color(0.7, 0.3, 1.0),
	Rarity.LEGENDARY: Color(1.0, 0.85, 0.2),
}

const RARITY_NAMES: Dictionary = {
	Rarity.COMMON:    "普通",
	Rarity.UNCOMMON:  "非凡",
	Rarity.RARE:      "稀有",
	Rarity.EPIC:      "史诗",
	Rarity.LEGENDARY: "传说",
}

# ============================================================
# 第一卷：乐理纲要 (Music Theory Compendium)
# ============================================================
const VOL1_NOTES: Dictionary = {
	"note_c": {
		"name": "C — 中央之音",
		"subtitle": "均衡型",
		"description": "最基础的音符，四维参数完全均衡（DMG 3 / SPD 3 / DUR 3 / SIZE 3）。如同白纸上的第一笔，C 是所有旋律的起点。它不偏不倚，适合初学者掌握基本节奏。",
		"stats": { "dmg": 3, "spd": 3, "dur": 3, "size": 3 },
		"color": Color(0.0, 1.0, 0.8),
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
	"note_d": {
		"name": "D — 疾风之音",
		"subtitle": "极速远程",
		"description": "以极高的飞行速度著称（SPD 5），牺牲了伤害和碰撞范围换取精准的远程打击能力。D 音符的弹体如同一支利箭，适合狙击远处的高价值目标。",
		"stats": { "dmg": 2, "spd": 5, "dur": 3, "size": 2 },
		"color": Color(0.2, 0.6, 1.0),
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
	"note_e": {
		"name": "E — 大地之音",
		"subtitle": "大范围持久",
		"description": "拥有最大的碰撞范围（SIZE 4）和持久的存活时间（DUR 4），是区域控制的基石。E 音符的弹体缓慢而庞大，如同一面移动的屏障，适合清扫密集的小型敌人。",
		"stats": { "dmg": 2, "spd": 2, "dur": 4, "size": 4 },
		"color": Color(0.0, 0.8, 0.4),
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
	"note_f": {
		"name": "F — 静谧之音",
		"subtitle": "区域控制",
		"description": "极端的持续时间（DUR 5）和大范围（SIZE 4），但飞行速度极低（SPD 1）。F 音符的弹体几乎停留在原地，形成一个持久的伤害区域，是\"地雷\"式战术的核心。",
		"stats": { "dmg": 2, "spd": 1, "dur": 5, "size": 4 },
		"color": Color(0.6, 0.2, 0.8),
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
	"note_g": {
		"name": "G — 雷鸣之音",
		"subtitle": "爆发伤害",
		"description": "拥有最高的单发伤害（DMG 5），是所有音符中的伤害之王。G 音符的弹体虽然存活时间短（DUR 2），但每一击都如同雷霆万钧，是对付精英和 Boss 的利器。",
		"stats": { "dmg": 5, "spd": 3, "dur": 2, "size": 2 },
		"color": Color(1.0, 0.3, 0.1),
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
	"note_a": {
		"name": "A — 恒星之音",
		"subtitle": "持久高伤",
		"description": "兼顾高伤害（DMG 4）和长持续时间（DUR 4），是持续输出的稳定选择。A 音符的弹体如同恒星般持久而有力，适合需要长时间覆盖的战术。",
		"stats": { "dmg": 4, "spd": 2, "dur": 4, "size": 2 },
		"color": Color(1.0, 0.8, 0.0),
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
	"note_b": {
		"name": "B — 流星之音",
		"subtitle": "高速高伤",
		"description": "高伤害（DMG 4）与高速度（SPD 4）的完美结合，是最具攻击性的音符。B 音符的弹体如同流星般迅猛，适合快节奏的攻击风格，但存活时间较短（DUR 2）。",
		"stats": { "dmg": 4, "spd": 4, "dur": 2, "size": 2 },
		"color": Color(1.0, 0.4, 0.6),
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
}

const VOL1_CHORDS: Dictionary = {
	"chord_major": {
		"name": "大三和弦",
		"subtitle": "强化弹体",
		"description": "最基础的和弦，由根音 + 大三度 + 纯五度构成（如 C-E-G）。触发「强化弹体」法术形态：弹体体积和伤害大幅提升，是最直观的火力增强手段。不和谐度极低（1.0），适合频繁使用。",
		"intervals": [0, 4, 7],
		"spell_form": "强化弹体",
		"dissonance": 1.0,
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
	"chord_minor": {
		"name": "小三和弦",
		"subtitle": "DOT弹体",
		"description": "由根音 + 小三度 + 纯五度构成（如 C-Eb-G）。触发「DOT弹体」法术形态：弹体命中后附加持续伤害效果。不和谐度较低（2.0），适合对付高血量目标。",
		"intervals": [0, 3, 7],
		"spell_form": "DOT弹体",
		"dissonance": 2.0,
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
	"chord_augmented": {
		"name": "增三和弦",
		"subtitle": "爆炸弹体",
		"description": "由根音 + 大三度 + 增五度构成（如 C-E-G#）。触发「爆炸弹体」法术形态：弹体命中后产生范围爆炸。不和谐度较高（4.0），但群体清扫能力极强。",
		"intervals": [0, 4, 8],
		"spell_form": "爆炸弹体",
		"dissonance": 4.0,
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "chord_augmented",
	},
	"chord_diminished": {
		"name": "减三和弦",
		"subtitle": "冲击波",
		"description": "由根音 + 小三度 + 减五度构成（如 C-Eb-Gb）。触发「冲击波」法术形态：以玩家为中心释放环形冲击波。不和谐度较高（5.0），但在被包围时极为有效。",
		"intervals": [0, 3, 6],
		"spell_form": "冲击波",
		"dissonance": 5.0,
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "chord_diminished",
	},
	"chord_dominant_7": {
		"name": "属七和弦",
		"subtitle": "法阵/区域",
		"description": "由根音 + 大三度 + 纯五度 + 小七度构成（如 C-E-G-Bb）。触发「法阵」法术形态：在指定位置生成持续伤害区域。不和谐度中等（3.0），是控制战场的核心手段。",
		"intervals": [0, 4, 7, 10],
		"spell_form": "法阵/区域",
		"dissonance": 3.0,
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "chord_seventh",
	},
	"chord_diminished_7": {
		"name": "减七和弦",
		"subtitle": "天降打击",
		"description": "由根音 + 小三度 + 减五度 + 减七度构成（如 C-Eb-Gb-Bbb）。触发「天降打击」法术形态：从天而降的高伤害单体攻击。不和谐度高（6.0），但伤害倍率惊人（3.0x）。",
		"intervals": [0, 3, 6, 9],
		"spell_form": "天降打击",
		"dissonance": 6.0,
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "chord_seventh",
	},
	"chord_major_7": {
		"name": "大七和弦",
		"subtitle": "护盾/治疗",
		"description": "由根音 + 大三度 + 纯五度 + 大七度构成（如 C-E-G-B）。触发「护盾/治疗法阵」法术形态：为玩家提供临时护盾或持续治疗。不和谐度低（2.0），是生存的关键。",
		"intervals": [0, 4, 7, 11],
		"spell_form": "护盾/治疗法阵",
		"dissonance": 2.0,
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "chord_seventh",
	},
	"chord_minor_7": {
		"name": "小七和弦",
		"subtitle": "召唤/构造",
		"description": "由根音 + 小三度 + 纯五度 + 小七度构成（如 C-Eb-G-Bb）。触发「召唤」法术形态：在战场上放置一个自动攻击的构造体。不和谐度较低（2.5），提供持续的战术支援。",
		"intervals": [0, 3, 7, 10],
		"spell_form": "召唤/构造",
		"dissonance": 2.5,
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "chord_seventh",
	},
	"chord_suspended": {
		"name": "挂留和弦",
		"subtitle": "蓄力弹体",
		"description": "由根音 + 纯四度 + 纯五度构成（如 C-F-G）。触发「蓄力弹体」法术形态：蓄力后释放一枚超高伤害弹体。不和谐度中等（3.5），高风险高回报。",
		"intervals": [0, 5, 7],
		"spell_form": "蓄力弹体",
		"dissonance": 3.5,
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "chord_diminished",
	},
}

const VOL1_EXTENDED_CHORDS: Dictionary = {
	"chord_dominant_9": {
		"name": "属九和弦",
		"subtitle": "风暴区域",
		"description": "五音和弦，触发「风暴区域」法术形态：生成一个持续的风暴场，对范围内敌人造成持续伤害并施加减速。需要传说级升级「扩展和弦解锁」。",
		"intervals": [0, 4, 7, 10, 14],
		"spell_form": "风暴区域",
		"dissonance": 5.0,
		"fatigue_cost": 0.25,
		"rarity": Rarity.EPIC,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "extended_chord_chance",
	},
	"chord_major_9": {
		"name": "大九和弦",
		"subtitle": "圣光领域",
		"description": "五音和弦，触发「圣光领域」法术形态：生成一个治疗与增益区域，范围内玩家持续恢复生命值并获得伤害加成。",
		"intervals": [0, 4, 7, 11, 14],
		"spell_form": "圣光领域",
		"dissonance": 3.5,
		"fatigue_cost": 0.15,
		"rarity": Rarity.EPIC,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "extended_chord_chance",
	},
	"chord_diminished_9": {
		"name": "减九和弦",
		"subtitle": "湮灭射线",
		"description": "五音和弦，触发「湮灭射线」法术形态：发射一道贯穿全屏的高伤害射线。伤害倍率极高（4.0x），但不和谐度和疲劳代价同样惊人。",
		"intervals": [0, 3, 6, 9, 13],
		"spell_form": "湮灭射线",
		"dissonance": 7.5,
		"fatigue_cost": 0.40,
		"rarity": Rarity.LEGENDARY,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "extended_chord_chance",
	},
	"chord_dominant_13": {
		"name": "属十三和弦",
		"subtitle": "交响风暴",
		"description": "七音和弦，触发「交响风暴」法术形态：全屏范围的持续伤害风暴。需要极高的操作精度来输入七个音符，是法术系统的巅峰之作。",
		"intervals": [0, 4, 7, 10, 14, 17, 21],
		"spell_form": "交响风暴",
		"dissonance": 7.0,
		"fatigue_cost": 0.45,
		"rarity": Rarity.LEGENDARY,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "extended_chord_chance",
	},
	"chord_diminished_13": {
		"name": "减十三和弦",
		"subtitle": "终焉乐章",
		"description": "七音和弦，触发「终焉乐章」法术形态：消耗大量疲劳度，释放毁灭性的全屏攻击。伤害倍率为所有法术之最（5.0x），但疲劳代价极其沉重（0.60）。这是真正的\"终极奥义\"。",
		"intervals": [0, 3, 6, 9, 13, 16, 21],
		"spell_form": "终焉乐章",
		"dissonance": 9.5,
		"fatigue_cost": 0.60,
		"rarity": Rarity.LEGENDARY,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "extended_chord_chance",
	},
}

const VOL1_RHYTHMS: Dictionary = {
	"rhythm_even_eighth": {
		"name": "均匀八分音符",
		"subtitle": "连射",
		"description": "最基础的节奏型。弹体大小 -1，但每拍发射 2 个弹体。适合需要高频率覆盖的场景，是清扫小型敌人的首选。",
		"effect": "SIZE -1, 每拍 ×2 弹体",
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
	"rhythm_dotted": {
		"name": "附点节奏",
		"subtitle": "重击",
		"description": "附点音符带来的重量感。飞行速度 -1，但伤害 +1 并获得击退效果。适合对付需要控制距离的大型敌人。",
		"effect": "SPD -1, DMG +1, 击退",
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
	"rhythm_syncopated": {
		"name": "切分节奏",
		"subtitle": "闪避射击",
		"description": "打破常规重音位置的节奏。发射时玩家向后微小位移，兼具攻击和闪避功能。适合在密集敌群中保持安全距离。",
		"effect": "发射时后退位移",
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.CAST_SPELL,
	},
	"rhythm_swing": {
		"name": "摇摆节奏",
		"subtitle": "摇摆弹道",
		"description": "爵士风格的不均匀节奏。弹体以 S 型波浪轨迹飞行，增大了有效覆盖面积。适合对付移动速度较快的敌人。",
		"effect": "S 型波浪轨迹",
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.CAST_SPELL,
	},
	"rhythm_triplet": {
		"name": "三连音",
		"subtitle": "三连发",
		"description": "将一拍均分为三等份的节奏。伤害降至 50%，但每拍发射 3 个扇形弹体。覆盖面积极大，是清扫波次的利器。",
		"effect": "DMG ×50%, 每拍 ×3 扇形弹体",
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.CAST_SPELL,
	},
	"rhythm_rest": {
		"name": "休止符",
		"subtitle": "精准蓄力",
		"description": "沉默中蕴含力量。每有一个休止符，同小节内其他弹体的伤害和大小各 +0.5。同时，休止符还能清除部分负面状态，是高级玩家的核心策略工具。",
		"effect": "每休止符: 同小节弹体 DMG/SIZE +0.5",
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.CAST_SPELL,
	},
}

const VOL1_MODES: Dictionary = {
	"mode_ionian": {
		"name": "伊奥尼亚调式",
		"subtitle": "均衡者",
		"description": "自然大调音阶，拥有全部七个白键（C D E F G A B）。没有特殊被动效果，但和谐度最高，不和谐值累积最慢。适合追求稳定输出和全面策略的玩家。",
		"available_keys": "C D E F G A B",
		"passive": "无特殊被动",
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
	"mode_dorian": {
		"name": "多利亚调式",
		"subtitle": "民谣诗人",
		"description": "小调色彩的调式，拥有全部七个白键。被动效果：每 3 次施法自动附加一次「回响」修饰符效果，无需消耗黑键。适合追求持续输出和法术覆盖的玩家。",
		"available_keys": "C D E F G A B",
		"passive": "每 3 次施法自动回响",
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "dorian",
	},
	"mode_pentatonic": {
		"name": "五声音阶",
		"subtitle": "东方行者",
		"description": "仅使用五个音符（C D E G A），移除了 F 和 B。作为补偿，剩余音符的基础伤害提升 20%，且不和谐度减半。适合追求简洁高效、不喜欢复杂和弦操作的玩家。",
		"available_keys": "C D E G A",
		"passive": "伤害 +20%, 不和谐度 ×0.5",
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "pentatonic",
	},
	"mode_blues": {
		"name": "布鲁斯调式",
		"subtitle": "爵士乐手",
		"description": "拥有全部七个白键，但核心被动效果是将不和谐值转化为暴击率（每点不和谐度 +3% 暴击率，上限 30%）。适合高风险高回报的激进玩家，越不和谐越强大。",
		"available_keys": "C D E F G A B",
		"passive": "不和谐度 → 暴击率 (3%/点, 上限30%)",
		"rarity": Rarity.EPIC,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "blues",
	},
}

# ============================================================
# 第二卷：百相众声 (Timbre Gallery)
# ============================================================
const VOL2_TIMBRES: Dictionary = {
	"timbre_none": {
		"name": "合成器",
		"subtitle": "基础音色",
		"description": "默认的合成器音色，无特殊效果。弹体呈现为纯净的几何光体，拖尾为简单的发光轨迹。适合初学者熟悉基础机制。",
		"family": "默认",
		"adsr": "极短起音, 短衰减, 中持续, 极短释放",
		"mechanic": "无特殊机制",
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
	"timbre_plucked": {
		"name": "弹拨系",
		"subtitle": "瞬态爆发",
		"description": "以古筝和琵琶为代表的弹拨类音色。核心机制「瞬态爆发」：弹体在生成后的极短时间内获得一次性的伤害与范围加成，随后迅速衰减。弹体生成时触发小范围冲击波（基础伤害 20%）。",
		"family": "弹拨",
		"adsr": "极短起音(0.005s), 快衰减(0.15s), 低持续(0.2), 无释放",
		"mechanic": "生成时冲击波 + 飞行伤害衰减",
		"instruments": "古筝（流水/分裂）、琵琶（轮指/破盾）",
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.CAST_SPELL,
	},
	"timbre_bowed": {
		"name": "拉弦系",
		"subtitle": "连绵共振",
		"description": "以二胡和大提琴为代表的拉弦类音色。核心机制「连绵共振」：弹体在命中敌人后，在敌人身上留下持续的共振标记，标记期间敌人持续受到额外伤害。弹体的飞行轨迹会留下可见的「弦痕」，短暂存在并对接触的敌人造成微量伤害。",
		"family": "拉弦",
		"adsr": "慢起音(0.08s), 无衰减, 极高持续(0.85), 长释放(0.15s)",
		"mechanic": "共振标记 + 弦痕轨迹",
		"instruments": "二胡（如泣如诉/标记增伤）、大提琴（深沉/减速）",
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.CAST_SPELL,
	},
	"timbre_wind": {
		"name": "吹奏系",
		"subtitle": "气息聚焦",
		"description": "以笛子和长笛为代表的吹奏类音色。核心机制「气息聚焦」：弹体在飞行过程中会逐渐收束，碰撞范围从大变小，但伤害从低变高。适合精准打击远处目标。",
		"family": "吹奏",
		"adsr": "均匀起音(0.04s), 均匀衰减(0.08s), 变化持续(0.65), 短释放(0.06s)",
		"mechanic": "飞行收束 + 远距增伤",
		"instruments": "笛子（清越/穿透）、长笛（柔和/治疗）",
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.CAST_SPELL,
	},
	"timbre_percussive": {
		"name": "打击系",
		"subtitle": "重音冲击",
		"description": "以钢琴和贝斯为代表的打击类音色。核心机制「重音冲击」：弹体在强拍发射时获得额外的伤害和击退加成，弱拍发射则效果减弱。与节拍系统深度绑定，鼓励玩家精准卡拍。",
		"family": "打击",
		"adsr": "瞬时起音(0.002s), 无衰减, 极高持续(0.75), 短释放(0.03s)",
		"mechanic": "强拍增伤 + 弱拍减效",
		"instruments": "钢琴（华彩/连击）、贝斯（低频/震荡）",
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.CAST_SPELL,
	},
}

# ============================================================
# 第三卷：失谐魔物 (Bestiary of Dissonance)
# ============================================================
const VOL3_BASIC_ENEMIES: Dictionary = {
	"enemy_static": {
		"name": "底噪 (Static)",
		"subtitle": "白噪声",
		"description": "最基础的敌人，代表无处不在的背景噪音。数量巨大，直线蜂拥而至。视觉上呈现为小型锯齿碎片，红色调，以 16 FPS 的量化帧率移动。\n\n特殊机制：群体加速 — 附近同类越多，移动越快（最高 1.6x）。",
		"hp": 30,
		"speed": 80,
		"damage": 10,
		"quantized_fps": 16,
		"color": Color(1.0, 0.2, 0.3),
		"mechanic": "群体加速（最高 1.6x）",
		"counter_tip": "利用高 SIZE 弹体（E/F 音符）进行范围清扫，或使用减三和弦冲击波一次性清除大群。",
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
		"kill_milestones": [1, 50, 200, 1000],
	},
	"enemy_silence": {
		"name": "寂静 (Silence)",
		"subtitle": "休止符/黑洞",
		"description": "试图吞噬声音的黑洞，缓慢但不可阻挡。视觉上呈现为深色旋涡，半透明，以极低的 6 FPS 量化帧率移动。\n\n特殊机制：静音光环 — 120px 半径内，玩家每秒增加 0.08 疲劳度，法术伤害降低 40%。击杀奖励：降低 0.1 疲劳度。",
		"hp": 120,
		"speed": 35,
		"damage": 5,
		"quantized_fps": 6,
		"color": Color(0.15, 0.1, 0.25),
		"mechanic": "静音光环（120px, +0.08 疲劳/秒, -40% 伤害）",
		"counter_tip": "优先击杀！使用高 DMG 音符（G/B）远程狙击，避免进入光环范围。击杀后可降低疲劳度。",
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.ENCOUNTER,
		"kill_milestones": [1, 30, 100, 500],
	},
	"enemy_screech": {
		"name": "尖啸 (Screech)",
		"subtitle": "反馈音",
		"description": "刺耳的反馈音，短暂但极具破坏力。视觉上呈现为尖锐三角形，黄白色调，以 20 FPS 的高量化帧率快速移动。\n\n特殊机制：冲刺 — 靠近 200px 时以 3x 速度冲刺。死亡爆发 — 80px 范围内造成 15 伤害 + 0.12 不和谐度，并留下短暂的不和谐区域。",
		"hp": 15,
		"speed": 150,
		"damage": 15,
		"quantized_fps": 20,
		"color": Color(1.0, 0.95, 0.5),
		"mechanic": "冲刺（3x 速度）+ 死亡爆发（15 伤害 + 0.12 不和谐度）",
		"counter_tip": "在其冲刺前远程击杀。注意死亡爆发的范围，保持安全距离。使用高 SPD 音符（D/B）进行远程狙击。",
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.ENCOUNTER,
		"kill_milestones": [1, 30, 100, 500],
	},
	"enemy_pulse": {
		"name": "脉冲 (Pulse)",
		"subtitle": "错误节拍器",
		"description": "错误的节拍器，在不该出现的时间点爆发。视觉上呈现为菱形，电蓝色调，以 10 FPS 的量化帧率移动。\n\n特殊机制：蓄力-释放 — 每 4 拍蓄力，然后冲刺或发射 8 发环形弹幕（交替进行）。死亡时释放半数弱弹幕。",
		"hp": 60,
		"speed": 55,
		"damage": 12,
		"quantized_fps": 10,
		"color": Color(0.2, 0.5, 1.0),
		"mechanic": "蓄力-释放周期（冲刺/弹幕交替）+ 死亡弹幕",
		"counter_tip": "在其蓄力期间集中火力击杀。注意观察蓄力动画，提前走位躲避弹幕。使用护盾/治疗法术应对死亡弹幕。",
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.ENCOUNTER,
		"kill_milestones": [1, 20, 80, 300],
	},
	"enemy_wall": {
		"name": "音墙 (Wall)",
		"subtitle": "砖墙限制器",
		"description": "过度压缩的音墙，将所有动态范围压平。视觉上呈现为巨大多边形，灰紫色调，以极低的 4 FPS 量化帧率缓慢移动。\n\n特殊机制：护盾 — 50 HP 额外护盾层，受击后 3 秒开始恢复。推力 — 60px 内持续推开玩家。地震冲击波 — 每 6 秒释放 150px 范围冲击波。",
		"hp": 200,
		"speed": 25,
		"damage": 15,
		"quantized_fps": 4,
		"color": Color(0.5, 0.35, 0.6),
		"mechanic": "护盾（50 HP）+ 推力（60px）+ 地震冲击波（150px, 每 6 秒）",
		"counter_tip": "持续输出打破护盾，避免让护盾恢复。使用高 DPS 组合（G 音符 + 大三和弦）集中火力。注意躲避周期性的冲击波。",
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.ENCOUNTER,
		"kill_milestones": [1, 15, 50, 200],
	},
}

const VOL3_CHAPTER_ENEMIES: Dictionary = {
	"ch1_grid_static": {
		"name": "网格底噪",
		"subtitle": "第一章 · 数之和谐",
		"description": "毕达哥拉斯时代的特色敌人。与普通底噪不同，网格底噪会按照数学网格阵列排列移动，形成整齐的几何图案。它们代表了毕达哥拉斯对\"数即万物\"的信仰。",
		"chapter": 1,
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"ch1_metronome_pulse": {
		"name": "节拍脉冲",
		"subtitle": "第一章 · 数之和谐",
		"description": "毕达哥拉斯时代的特色敌人。一个严格按照固定节拍行动的脉冲体，其攻击时机完全可预测。它代表了早期音乐理论中对精确数学比例的追求。",
		"chapter": 1,
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"ch2_scribe": {
		"name": "抄谱员",
		"subtitle": "第二章 · 圣咏之光",
		"description": "圭多时代的特色敌人。手持羽毛笔的幽灵抄写员，会在战场上书写\"纽姆谱\"符号，这些符号会变成伤害区域。代表了中世纪音乐记谱法的诞生。",
		"chapter": 2,
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"ch2_choir": {
		"name": "唱诗班",
		"subtitle": "第二章 · 圣咏之光",
		"description": "圭多时代的特色敌人。多个小型敌人组成的合唱团，它们会同步行动并发出和声攻击。当合唱团成员被击杀时，剩余成员的攻击力会增强。",
		"chapter": 2,
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"ch3_counterpoint_crawler": {
		"name": "对位爬虫",
		"subtitle": "第三章 · 赋格迷宫",
		"description": "巴赫时代的特色敌人。成对出现的敌人，一个正向移动，另一个反向移动，形成对位法般的运动模式。击杀一个会让另一个暂时狂暴。",
		"chapter": 3,
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"ch4_minuet_dancer": {
		"name": "小步舞者",
		"subtitle": "第四章 · 古典华章",
		"description": "莫扎特时代的特色敌人。优雅地按照三拍子节奏在战场上旋转跳跃的舞者，其移动轨迹形成复杂的舞步图案，难以预测。",
		"chapter": 4,
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"ch5_crescendo_surge": {
		"name": "渐强浪潮",
		"subtitle": "第五章 · 狂想曲",
		"description": "贝多芬时代的特色敌人。一个不断膨胀的能量体，其体积、速度和伤害随时间持续增长（渐强），直到达到极限后爆发。代表了贝多芬音乐中标志性的渐强手法。",
		"chapter": 5,
		"rarity": Rarity.EPIC,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"ch5_fate_knocker": {
		"name": "命运叩门者",
		"subtitle": "第五章 · 狂想曲",
		"description": "贝多芬时代的特色敌人。以贝多芬第五交响曲的\"命运动机\"（短短短长）为攻击节奏的敌人。每四拍为一个攻击周期：前三拍快速冲刺，第四拍释放重击。",
		"chapter": 5,
		"rarity": Rarity.EPIC,
		"unlock_type": UnlockType.ENCOUNTER,
	},
}

const VOL3_ELITES: Dictionary = {
	"ch1_harmony_guardian": {
		"name": "和谐守卫",
		"subtitle": "第一章精英",
		"description": "毕达哥拉斯的忠实守护者。拥有一个\"和谐护盾\"，只有使用特定音程（纯八度、纯五度、纯四度）的和弦攻击才能有效破盾。代表了毕达哥拉斯学派对\"和谐比例\"的崇拜。",
		"chapter": 1,
		"rarity": Rarity.EPIC,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"ch1_frequency_sentinel": {
		"name": "频率哨兵",
		"subtitle": "第一章精英",
		"description": "守护特定频率的哨兵。会在战场上生成\"共振区域\"，玩家在区域内使用与其频率匹配的音符可获得增伤，使用不匹配的音符则受到惩罚。",
		"chapter": 1,
		"rarity": Rarity.EPIC,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"ch2_cantor_commander": {
		"name": "领唱指挥",
		"subtitle": "第二章精英",
		"description": "唱诗班的指挥者。能够强化范围内所有小型敌人的属性，并指挥它们进行协同攻击。击杀指挥后，被强化的敌人会暂时陷入混乱。",
		"chapter": 2,
		"rarity": Rarity.EPIC,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"ch3_fugue_weaver": {
		"name": "赋格织者",
		"subtitle": "第三章精英",
		"description": "巴赫赋格艺术的具象化。会创造自身的\"镜像分身\"，分身的行为模式与本体形成赋格般的对位关系。只有同时击杀本体和分身才能真正消灭它。",
		"chapter": 3,
		"rarity": Rarity.EPIC,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"ch4_court_kapellmeister": {
		"name": "宫廷乐长",
		"subtitle": "第四章精英",
		"description": "莫扎特时代的宫廷乐队指挥。能够\"指挥\"战场上的敌人按照古典奏鸣曲式（呈示部-发展部-再现部）进行攻击模式的切换，使敌人的行为更加有组织和致命。",
		"chapter": 4,
		"rarity": Rarity.EPIC,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"ch5_symphony_commander": {
		"name": "交响指挥",
		"subtitle": "第五章精英",
		"description": "贝多芬交响乐的具象化。拥有四个\"乐章\"阶段，每个阶段对应不同的攻击模式和弱点。是所有精英中最复杂、最具挑战性的存在。",
		"chapter": 5,
		"rarity": Rarity.LEGENDARY,
		"unlock_type": UnlockType.ENCOUNTER,
	},
}

const VOL3_BOSSES: Dictionary = {
	"boss_pythagoras": {
		"name": "律动尊者 · 毕达哥拉斯",
		"subtitle": "The First Resonator",
		"description": "第一章最终 Boss。宇宙初始和谐的具象化，一个位于场景中心、由多层旋转光环构成的巨大几何体。它本身不进行移动，代表着一种绝对的、静态的完美。\n\n时代特征「绝对频率」：通过震动战场生成克拉尼图形，线条为致命伤害区域，玩家必须站在\"节点\"安全区。\n\n三阶段：序曲 → 共鸣 → 天体乐章",
		"chapter": 1,
		"hp": 3000,
		"phases": ["序曲 (Prelude)", "共鸣 (Resonance)", "天体乐章 (Musica Universalis)"],
		"rarity": Rarity.LEGENDARY,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"boss_guido": {
		"name": "圣咏宗师 · 圭多",
		"subtitle": "The Notation Architect",
		"description": "第二章最终 Boss。记谱法的发明者，战场本身就是他的五线谱。\n\n时代特征「活谱面」：战场上出现五条水平线（五线谱），Boss 在线上书写音符符号，这些符号会变成实体攻击。\n\n三阶段：纽姆记谱 → 四线谱 → 圭多之手",
		"chapter": 2,
		"hp": 5000,
		"phases": ["纽姆记谱", "四线谱", "圭多之手"],
		"rarity": Rarity.LEGENDARY,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"boss_bach": {
		"name": "大构建师 · 巴赫",
		"subtitle": "The Grand Architect",
		"description": "第三章最终 Boss。对位法的终极大师，战斗本身就是一首赋格。\n\n时代特征「赋格引擎」：Boss 的攻击模式遵循严格的赋格结构——主题、答题、对题层层叠加。\n\n三阶段：创意曲 → 赋格 → 恰空",
		"chapter": 3,
		"hp": 8000,
		"phases": ["创意曲 (Invention)", "赋格 (Fugue)", "恰空 (Chaconne)"],
		"rarity": Rarity.LEGENDARY,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"boss_mozart": {
		"name": "古典完形 · 莫扎特",
		"subtitle": "The Classical Perfection",
		"description": "第四章最终 Boss。古典主义的完美化身，优雅而致命。\n\n时代特征「奏鸣曲式」：Boss 战严格遵循奏鸣曲式结构——呈示部、发展部、再现部，每个部分有独特的攻击主题。\n\n三阶段：呈示部 → 发展部 → 再现部",
		"chapter": 4,
		"hp": 12000,
		"phases": ["呈示部 (Exposition)", "发展部 (Development)", "再现部 (Recapitulation)"],
		"rarity": Rarity.LEGENDARY,
		"unlock_type": UnlockType.ENCOUNTER,
	},
	"boss_beethoven": {
		"name": "狂想者 · 贝多芬",
		"subtitle": "The Unchained Tempest",
		"description": "第五章最终 Boss。浪漫主义的先驱，规则的打破者。这是整个游戏的终极挑战。\n\n时代特征「命运交响」：Boss 会主动打破游戏规则——修改 BPM、改变调式、甚至暂时禁用玩家的某些能力。\n\n四阶段：命运 → 月光 → 英雄 → 欢乐颂",
		"chapter": 5,
		"hp": 20000,
		"phases": ["命运 (Fate)", "月光 (Moonlight)", "英雄 (Eroica)", "欢乐颂 (Ode to Joy)"],
		"rarity": Rarity.LEGENDARY,
		"unlock_type": UnlockType.ENCOUNTER,
	},
}

# ============================================================
# 第四卷：神兵乐章 (Spell Compendium)
# ============================================================
const VOL4_MODIFIERS: Dictionary = {
	"modifier_pierce": {
		"name": "锐化 (C#/Db)",
		"subtitle": "穿透修饰符",
		"description": "使弹体获得穿透能力，可以穿过敌人继续飞行（最多穿透 3 个目标）。穿透后伤害不衰减。适合对付成排的敌人。",
		"black_key": "C#",
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
	"modifier_homing": {
		"name": "追踪 (D#/Eb)",
		"subtitle": "追踪修饰符",
		"description": "使弹体获得自动追踪能力，会缓慢转向最近的敌人。追踪强度随飞行距离增加而减弱。适合对付高速移动的敌人（如尖啸）。",
		"black_key": "D#",
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "modifier_homing",
	},
	"modifier_split": {
		"name": "分裂 (F#/Gb)",
		"subtitle": "分裂修饰符",
		"description": "使弹体在飞行一段距离后分裂为 3 个小弹体，呈扇形散开。小弹体继承原弹体 50% 的伤害。适合扩大覆盖范围。",
		"black_key": "F#",
		"rarity": Rarity.COMMON,
		"unlock_type": UnlockType.DEFAULT,
	},
	"modifier_echo": {
		"name": "回响 (G#/Ab)",
		"subtitle": "回响修饰符",
		"description": "使弹体在消失时，在原位置生成一个短暂的回响弹体（持续 0.5 秒），继承原弹体 30% 的伤害和 100% 的碰撞范围。适合增加区域控制能力。",
		"black_key": "G#",
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "modifier_echo",
	},
	"modifier_scatter": {
		"name": "散射 (A#/Bb)",
		"subtitle": "散射修饰符",
		"description": "使弹体在发射时额外生成 2 个散射弹体，呈小角度扇形发射。散射弹体继承原弹体 40% 的伤害。适合近距离大范围覆盖。",
		"black_key": "A#",
		"rarity": Rarity.UNCOMMON,
		"unlock_type": UnlockType.META_UNLOCK,
		"unlock_key": "modifier_scatter",
	},
}

const VOL4_PROGRESSIONS: Dictionary = {
	"prog_d_to_t": {
		"name": "属→主 解决 (D→T)",
		"subtitle": "爆发治疗/全屏伤害",
		"description": "从紧张到解决的和弦进行。当玩家从属功能和弦（如属七和弦）过渡到主功能和弦（如大三和弦）时触发。\n\n效果：若玩家生命值低于 50%，触发爆发治疗（恢复 30 HP）；若高于 50%，触发全屏伤害（50 点基础伤害）。这是最强大的和弦进行效果。",
		"from": "属功能 (D)",
		"to": "主功能 (T)",
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.CAST_SPELL,
	},
	"prog_t_to_d": {
		"name": "主→属 蓄力 (T→D)",
		"subtitle": "下一法术伤害翻倍",
		"description": "从稳定到紧张的和弦进行。当玩家从主功能和弦过渡到属功能和弦时触发。\n\n效果：下一个施放的法术伤害翻倍（2.0x 倍率）。适合在施放高伤害法术前进行\"蓄力\"。",
		"from": "主功能 (T)",
		"to": "属功能 (D)",
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.CAST_SPELL,
	},
	"prog_pd_to_d": {
		"name": "下属→属 加速 (PD→D)",
		"subtitle": "全体冷却缩减",
		"description": "从准备到紧张的和弦进行。当玩家从下属功能和弦过渡到属功能和弦时触发。\n\n效果：所有手动施法槽的冷却时间缩减 50%。适合在需要快速连续施法时使用。",
		"from": "下属功能 (PD)",
		"to": "属功能 (D)",
		"rarity": Rarity.RARE,
		"unlock_type": UnlockType.CAST_SPELL,
	},
}

# ============================================================
# 辅助方法
# ============================================================

## 获取指定卷的所有条目 ID
static func get_volume_entries(volume: Volume) -> Array[String]:
	var result: Array[String] = []
	match volume:
		Volume.MUSIC_THEORY:
			result.append_array(VOL1_NOTES.keys())
			result.append_array(VOL1_CHORDS.keys())
			result.append_array(VOL1_EXTENDED_CHORDS.keys())
			result.append_array(VOL1_RHYTHMS.keys())
			result.append_array(VOL1_MODES.keys())
		Volume.TIMBRE_GALLERY:
			result.append_array(VOL2_TIMBRES.keys())
		Volume.BESTIARY:
			result.append_array(VOL3_BASIC_ENEMIES.keys())
			result.append_array(VOL3_CHAPTER_ENEMIES.keys())
			result.append_array(VOL3_ELITES.keys())
			result.append_array(VOL3_BOSSES.keys())
		Volume.SPELL_COMPENDIUM:
			result.append_array(VOL4_MODIFIERS.keys())
			result.append_array(VOL4_PROGRESSIONS.keys())
	return result

## 根据 ID 查找条目数据（跨所有卷）
static func find_entry(entry_id: String) -> Dictionary:
	# 遍历所有数据表
	for table in [VOL1_NOTES, VOL1_CHORDS, VOL1_EXTENDED_CHORDS, VOL1_RHYTHMS, VOL1_MODES,
				  VOL2_TIMBRES,
				  VOL3_BASIC_ENEMIES, VOL3_CHAPTER_ENEMIES, VOL3_ELITES, VOL3_BOSSES,
				  VOL4_MODIFIERS, VOL4_PROGRESSIONS]:
		if table.has(entry_id):
			return table[entry_id]
	return {}

## 获取指定卷的条目总数
static func get_volume_total(volume: Volume) -> int:
	return get_volume_entries(volume).size()

## 获取所有条目的总数
static func get_total_entries() -> int:
	var total := 0
	for v in Volume.values():
		total += get_volume_total(v)
	return total
