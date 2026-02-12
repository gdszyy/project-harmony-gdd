## music_data.gd
## 音乐理论核心数据定义
## 包含音符、和弦、音程等所有乐理相关的静态数据
class_name MusicData

# ============================================================
# 枚举定义
# ============================================================

## 所有12个半音
enum Note {
	C = 0, CS = 1, D = 2, DS = 3, E = 4, F = 5,
	FS = 6, G = 7, GS = 8, A = 9, AS = 10, B = 11
}

## 白键音符（可施放的基础弹体）
enum WhiteKey { C, D, E, F, G, A, B }

## 黑键音符（修饰符 / 和弦构成音）
enum BlackKey { CS, DS, FS, GS, AS }

## 和弦类型
enum ChordType {
	MAJOR,           # 大三和弦
	MINOR,           # 小三和弦
	AUGMENTED,       # 增三和弦
	DIMINISHED,      # 减三和弦
	DOMINANT_7,      # 属七和弦
	DIMINISHED_7,    # 减七和弦
	MAJOR_7,         # 大七和弦
	MINOR_7,         # 小七和弦
	SUSPENDED,       # 挂留和弦
	# 扩展和弦 (需要传说级升级解锁)
	DOMINANT_9,      # 属九和弦
	MAJOR_9,         # 大九和弦
	DIMINISHED_9,    # 减九和弦
	DOMINANT_11,     # 属十一和弦
	DOMINANT_13,     # 属十三和弦
	DIMINISHED_13,   # 减十三和弦
}

## 法术形态
enum SpellForm {
	ENHANCED_PROJECTILE,  # 强化弹体 (大三)
	DOT_PROJECTILE,       # DOT弹体 (小三)
	EXPLOSIVE,            # 爆炸弹体 (增三)
	SHOCKWAVE,            # 冲击波 (减三)
	FIELD,                # 法阵/区域 (属七)
	DIVINE_STRIKE,        # 天降打击 (减七)
	SHIELD_HEAL,          # 护盾/治疗 (大七)
	SUMMON,               # 召唤/构造 (小七)
	CHARGED,              # 蓄力弹体 (挂留)
	STORM_FIELD,          # 风暴区域 (属九)
	HOLY_DOMAIN,          # 圣光领域 (大九)
	ANNIHILATION_RAY,     # 湮灭射线 (减九)
	TIME_RIFT,            # 时空裂隙 (属十一)
	SYMPHONY_STORM,       # 交响风暴 (属十三)
	FINALE,               # 终焉乐章 (减十三)
}

## 黑键修饰符效果
enum ModifierEffect {
	PIERCE,     # 穿透 (C#/Db)
	HOMING,     # 追踪 (D#/Eb)
	SPLIT,      # 分裂 (F#/Gb)
	ECHO,       # 回响 (G#/Ab)
	SCATTER,    # 散射 (A#/Bb)
}

## 和弦功能 (用于和弦进行)
enum ChordFunction {
	TONIC,        # T - 主功能 (稳定)
	PREDOMINANT,  # PD - 下属功能 (准备)
	DOMINANT,     # D - 属功能 (紧张)
}

## 节奏型
enum RhythmPattern {
	EVEN_EIGHTH,    # 均匀八分音符 → 连射
	DOTTED,         # 附点节奏 → 重击
	SYNCOPATED,     # 切分节奏 → 闪避射击
	SWING,          # 摇摆节奏 → 摇摆弹道
	TRIPLET,        # 三连音 → 三连发
	REST,           # 休止符 → 精准蓄力
}

## 疲劳等级
enum FatigueLevel {
	NONE,
	MILD,
	MODERATE,
	SEVERE,
	CRITICAL,
}

## 章节音色武器枚举 (v2.0 — 替代原 TimbreType)
## 每个章节拥有一种专属音色武器，与章节主题深度绑定
enum ChapterTimbre {
	NONE,              # 默认/无音色
	LYRE,              # Ch1 里拉琴 (古希腊)
	ORGAN,             # Ch2 管风琴 (中世纪)
	HARPSICHORD,       # Ch3 羽管键琴 (巴洛克)
	FORTEPIANO,        # Ch4 钢琴 (古典主义)
	TUTTI,             # Ch5 管弦全奏 (浪漫主义)
	SAXOPHONE,         # Ch6 萨克斯 (爵士)
	SYNTHESIZER,       # Ch7 合成主脑 (现代/电子)
}

## 电子乐变体枚举
## 每种章节音色武器都有对应的电子乐变体
enum ElectronicVariant {
	NONE,
	SINE_WAVE_SYNTH,     # Ch1 正弦波合成 (里拉琴变体)
	DRONE_SYNTH,         # Ch2 无人机音合成 (管风琴变体)
	ARPEGGIATOR_SYNTH,   # Ch3 琶音器合成 (羽管键琴变体)
	VELOCITY_PAD,        # Ch4 力度感应垫 (钢琴变体)
	SUPERSAW_SYNTH,      # Ch5 超级锯齿波 (管弦全奏变体)
	FM_SYNTH,            # Ch6 FM合成器 (萨克斯变体)
	GLITCH_ENGINE,       # Ch7 故障引擎 (合成主脑变体)
}

## 章节词条稀有度
enum InscriptionRarity {
	COMMON,    # 普通
	RARE,      # 稀有
	EPIC,      # 史诗
}

## 向后兼容：保留旧版 TimbreType 枚举作为别名
## 新代码应使用 ChapterTimbre
enum TimbreType {
	NONE,           # 默认/无音色 (基础合成器)
	PLUCKED,        # 弹拨系 → 映射到 LYRE/HARPSICHORD
	BOWED,          # 拉弦系 → 映射到 ORGAN/TUTTI
	WIND,           # 吹奏系 → 映射到 SAXOPHONE
	PERCUSSIVE,     # 打击系 → 映射到 FORTEPIANO/SYNTHESIZER
}

# ============================================================
# 静态数据表
# ============================================================

## 白键音符四维参数 (DMG, SPD, DUR, SIZE)
## v3.0: 总和从 12 提升到 13，极化各音符特性
const WHITE_KEY_STATS: Dictionary = {
	WhiteKey.C: { "dmg": 3, "spd": 3, "dur": 3.5, "size": 3.5, "name": "C", "desc": "均衡型" },
	WhiteKey.D: { "dmg": 1.5, "spd": 6, "dur": 3, "size": 2.5, "name": "D", "desc": "极速远程" },
	WhiteKey.E: { "dmg": 1.5, "spd": 2, "dur": 5, "size": 4.5, "name": "E", "desc": "大范围持久" },
	WhiteKey.F: { "dmg": 2, "spd": 0.5, "dur": 6, "size": 4.5, "name": "F", "desc": "区域控制" },
	WhiteKey.G: { "dmg": 6, "spd": 3, "dur": 1.5, "size": 2, "name": "G", "desc": "爆发伤害" },
	WhiteKey.A: { "dmg": 4.5, "spd": 2, "dur": 4, "size": 2.5, "name": "A", "desc": "持久高伤" },
	WhiteKey.B: { "dmg": 4.5, "spd": 4.5, "dur": 2, "size": 2, "name": "B", "desc": "高速高伤" },
}

## 参数到实际值的转换比率
const PARAM_CONVERSION: Dictionary = {
	"dmg_per_point": 10.0,     # 每点 = 10 基础伤害
	"spd_per_point": 200.0,    # 每点 = 200 像素/秒
	"dur_per_point": 0.5,      # 每点 = 0.5 秒
	"size_per_point": 8.0,     # 每点 = 8 像素碰撞半径
}

## 黑键修饰符映射
const BLACK_KEY_MODIFIERS: Dictionary = {
	BlackKey.CS: { "effect": ModifierEffect.PIERCE, "name": "锐化", "desc": "穿透" },
	BlackKey.DS: { "effect": ModifierEffect.HOMING, "name": "追踪", "desc": "追踪" },
	BlackKey.FS: { "effect": ModifierEffect.SPLIT, "name": "分裂", "desc": "分裂" },
	BlackKey.GS: { "effect": ModifierEffect.ECHO, "name": "回响", "desc": "回响" },
	BlackKey.AS: { "effect": ModifierEffect.SCATTER, "name": "散射", "desc": "散射" },
}

## 和弦类型 → 法术形态映射
## v3.0: 降低基础三和弦倍率，提高七和弦吸引力
const CHORD_SPELL_MAP: Dictionary = {
	ChordType.MAJOR:         { "form": SpellForm.ENHANCED_PROJECTILE, "name": "强化弹体", "multiplier": 1.3 },
	ChordType.MINOR:         { "form": SpellForm.DOT_PROJECTILE, "name": "DOT弹体", "multiplier": 1.1 },
	ChordType.AUGMENTED:     { "form": SpellForm.EXPLOSIVE, "name": "爆炸弹体", "multiplier": 1.6 },
	ChordType.DIMINISHED:    { "form": SpellForm.SHOCKWAVE, "name": "冲击波", "multiplier": 1.8 },
	ChordType.DOMINANT_7:    { "form": SpellForm.FIELD, "name": "法阵/区域", "multiplier": 1.2 },
	ChordType.DIMINISHED_7:  { "form": SpellForm.DIVINE_STRIKE, "name": "天降打击", "multiplier": 2.8 },
	ChordType.MAJOR_7:       { "form": SpellForm.SHIELD_HEAL, "name": "护盾/治疗法阵", "multiplier": 0.0 },
	ChordType.MINOR_7:       { "form": SpellForm.SUMMON, "name": "召唤/构造", "multiplier": 0.9 },
	ChordType.SUSPENDED:     { "form": SpellForm.CHARGED, "name": "蓄力弹体", "multiplier": 1.8 },
	# 扩展和弦
	ChordType.DOMINANT_9:    { "form": SpellForm.STORM_FIELD, "name": "风暴区域", "multiplier": 0.6 },
	ChordType.MAJOR_9:       { "form": SpellForm.HOLY_DOMAIN, "name": "圣光领域", "multiplier": 0.0 },
	ChordType.DIMINISHED_9:  { "form": SpellForm.ANNIHILATION_RAY, "name": "湮灭射线", "multiplier": 3.5 },
	ChordType.DOMINANT_11:   { "form": SpellForm.TIME_RIFT, "name": "时空裂隙", "multiplier": 0.7 },
	ChordType.DOMINANT_13:   { "form": SpellForm.SYMPHONY_STORM, "name": "交响风暴", "multiplier": 1.2 },
	ChordType.DIMINISHED_13: { "form": SpellForm.FINALE, "name": "终焉乐章", "multiplier": 4.5 },
}

## 和弦不和谐度
const CHORD_DISSONANCE: Dictionary = {
	ChordType.MAJOR: 1.0,
	ChordType.MINOR: 2.0,
	ChordType.AUGMENTED: 4.0,
	ChordType.DIMINISHED: 5.0,
	ChordType.DOMINANT_7: 3.0,
	ChordType.DIMINISHED_7: 6.0,
	ChordType.MAJOR_7: 2.0,
	ChordType.MINOR_7: 2.5,
	ChordType.SUSPENDED: 3.5,
	ChordType.DOMINANT_9: 5.0,
	ChordType.MAJOR_9: 3.5,
	ChordType.DIMINISHED_9: 7.5,
	ChordType.DOMINANT_11: 6.0,
	ChordType.DOMINANT_13: 7.0,
	ChordType.DIMINISHED_13: 9.5,
}

## 扩展和弦疲劳代价
const EXTENDED_CHORD_FATIGUE: Dictionary = {
	ChordType.DOMINANT_9: 0.25,
	ChordType.MAJOR_9: 0.15,
	ChordType.DIMINISHED_9: 0.40,
	ChordType.DOMINANT_11: 0.30,
	ChordType.DOMINANT_13: 0.45,
	ChordType.DIMINISHED_13: 0.60,
}

## 节奏型行为修饰
const RHYTHM_MODIFIERS: Dictionary = {
	RhythmPattern.EVEN_EIGHTH: {
		"name": "连射", "size_mod": -1, "count": 2,
		"desc": "弹体大小-1，但每拍发射2个"
	},
	RhythmPattern.DOTTED: {
		"name": "重击", "spd_mod": -1, "dmg_mod": 1, "knockback": true,
		"desc": "飞行速度-1，但伤害+1，并获得击退"
	},
	RhythmPattern.SYNCOPATED: {
		"name": "闪避射击", "dodge_back": true,
		"desc": "发射时，玩家向后微小位移"
	},
	RhythmPattern.SWING: {
		"name": "摇摆弹道", "wave_trajectory": true,
		"desc": "S型/波浪形轨迹飞行"
	},
	RhythmPattern.TRIPLET: {
		"name": "三连发", "dmg_mod_mult": 0.5, "count": 3, "spread": true,
		"desc": "伤害50%，但每拍发射3个扇形弹体"
	},
	RhythmPattern.REST: {
		"name": "精准蓄力", "boost_per_rest": 0.5,
		"desc": "每有一个休止符，小节内其他弹体伤害和大小+0.5"
	},
}

## 音符颜色映射 (HSV Hue值，用于Shader)
const NOTE_COLORS: Dictionary = {
	WhiteKey.C: Color(0.0, 1.0, 0.8),    # 青色
	WhiteKey.D: Color(0.2, 0.6, 1.0),    # 蓝色
	WhiteKey.E: Color(0.0, 0.8, 0.4),    # 绿色
	WhiteKey.F: Color(0.6, 0.2, 0.8),    # 紫色
	WhiteKey.G: Color(1.0, 0.3, 0.1),    # 红橙色
	WhiteKey.A: Color(1.0, 0.8, 0.0),    # 金色
	WhiteKey.B: Color(1.0, 0.4, 0.6),    # 粉色
}

## 和弦音程模板 (半音数)
const CHORD_INTERVALS: Dictionary = {
	ChordType.MAJOR:         [0, 4, 7],
	ChordType.MINOR:         [0, 3, 7],
	ChordType.AUGMENTED:     [0, 4, 8],
	ChordType.DIMINISHED:    [0, 3, 6],
	ChordType.DOMINANT_7:    [0, 4, 7, 10],
	ChordType.DIMINISHED_7:  [0, 3, 6, 9],
	ChordType.MAJOR_7:       [0, 4, 7, 11],
	ChordType.MINOR_7:       [0, 3, 7, 10],
	ChordType.SUSPENDED:     [0, 5, 7],
	ChordType.DOMINANT_9:    [0, 4, 7, 10, 14],
	ChordType.MAJOR_9:       [0, 4, 7, 11, 14],
	ChordType.DIMINISHED_9:  [0, 3, 6, 9, 13],
	ChordType.DOMINANT_11:   [0, 4, 7, 10, 14, 17],
	ChordType.DOMINANT_13:   [0, 4, 7, 10, 14, 17, 21],
	ChordType.DIMINISHED_13: [0, 3, 6, 9, 13, 16, 21],
}

## 和弦功能转换效果
const PROGRESSION_EFFECTS: Dictionary = {
	# "D_to_T": 紧张到解决 → 爆发性正面效果
	"D_to_T": { "type": "burst_heal_or_damage", "desc": "爆发治疗或全屏伤害" },
	# "T_to_D": 稳定到紧张 → 蓄力增伤
	"T_to_D": { "type": "empower_next", "desc": "下一个法术伤害翻倍" },
	# "PD_to_D": 准备到紧张 → 加速增幅
	"PD_to_D": { "type": "cooldown_reduction", "desc": "全体冷却缩减" },
}

## 完整度奖励倍率
const COMPLETENESS_BONUS: Dictionary = {
	2: 1.0,
	3: 1.5,
	4: 2.0,
}

# ============================================================
# 章节音色武器系统数据 (v2.0)
# ============================================================

## 跨章节音色疲劳代价（使用非当前章节的音色武器时）
const CROSS_CHAPTER_TIMBRE_FATIGUE: float = 0.03

## 电子乐变体疲劳减免倍率
const ELECTRONIC_VARIANT_FATIGUE_MULT: float = 0.5

## 疲劳对音色效能的影响倍率
const TIMBRE_FATIGUE_PENALTY: Dictionary = {
	FatigueLevel.NONE: 1.0,       # 无衰减
	FatigueLevel.MILD: 1.0,       # 无衰减
	FatigueLevel.MODERATE: 0.8,   # 效能降低20%
	FatigueLevel.SEVERE: 0.5,     # 效能降低50%，词条协同失效
	FatigueLevel.CRITICAL: 0.2,   # 效能降低80%，词条协同失效
}

## 章节词条出现概率（替代普通升级选项）
const INSCRIPTION_APPEAR_CHANCE: float = 0.15

## 章节音色武器 ADSR 包络参数
## attack: 起音时间(秒), decay: 衰减时间(秒),
## sustain: 持续电平(0-1), release: 释放时间(秒)
const CHAPTER_TIMBRE_ADSR: Dictionary = {
	ChapterTimbre.NONE: {
		"attack": 0.01, "decay": 0.1,
		"sustain": 0.6, "release": 0.05,
		"wave_shape": "sine",
		"harmonics": [[1.0, 1.0], [2.0, 0.3], [3.0, 0.1]],
		"name": "默认", "desc": "无音色武器激活",
	},
	ChapterTimbre.LYRE: {
		"attack": 0.08, "decay": 0.20,
		"sustain": 0.60, "release": 0.15,
		"wave_shape": "triangle",
		"harmonics": [[1.0, 1.0], [2.0, 0.5], [3.0, 0.35], [4.0, 0.2], [5.0, 0.1]],
		"name": "里拉琴", "name_en": "Lyre",
		"desc": "纯净的泛音共鸣，基于数学比例的伤害加成",
		"core_mechanic": "harmonic_resonance",
		"chord_interaction": ChordType.DOMINANT_7,
	},
	ChapterTimbre.ORGAN: {
		"attack": 0.15, "decay": 0.0,
		"sustain": 0.90, "release": 0.40,
		"wave_shape": "sawtooth",
		"harmonics": [[1.0, 1.0], [2.0, 0.4], [3.0, 0.25], [4.0, 0.15], [5.0, 0.08]],
		"name": "管风琴", "name_en": "Organ",
		"desc": "持续的和声层叠，多声部叠加攻击",
		"core_mechanic": "harmonic_stacking",
		"chord_interaction": ChordType.MINOR,
	},
	ChapterTimbre.HARPSICHORD: {
		"attack": 0.03, "decay": 0.15,
		"sustain": 0.45, "release": 0.0,
		"wave_shape": "triangle",
		"harmonics": [[1.0, 1.0], [2.0, 0.6], [3.0, 0.4], [4.0, 0.25], [5.0, 0.15], [6.0, 0.08]],
		"name": "羽管键琴", "name_en": "Harpsichord",
		"desc": "精密的对位攻击，多弹道交织",
		"core_mechanic": "counterpoint_weave",
		"chord_interaction": ChordType.AUGMENTED,
	},
	ChapterTimbre.FORTEPIANO: {
		"attack": 0.02, "decay": 0.10,
		"sustain": 0.80, "release": 0.08,
		"wave_shape": "sine",
		"harmonics": [[1.0, 1.0], [2.0, 0.3], [3.0, 0.15], [4.0, 0.08]],
		"name": "钢琴", "name_en": "Fortepiano",
		"desc": "力度动态控制，强弱拍伤害差异化",
		"core_mechanic": "velocity_dynamics",
		"chord_interaction": ChordType.MINOR_7,
	},
	ChapterTimbre.TUTTI: {
		"attack": 0.10, "decay": 0.05,
		"sustain": 0.85, "release": 0.20,
		"wave_shape": "sawtooth",
		"harmonics": [[1.0, 1.0], [2.0, 0.5], [3.0, 0.35], [4.0, 0.25], [5.0, 0.15], [6.0, 0.1]],
		"name": "管弦全奏", "name_en": "Tutti",
		"desc": "情感爆发式攻击，渐强渐弱的伤害曲线",
		"core_mechanic": "emotional_crescendo",
		"chord_interaction": ChordType.DIMINISHED,
	},
	ChapterTimbre.SAXOPHONE: {
		"attack": 0.06, "decay": 0.10,
		"sustain": 0.70, "release": 0.12,
		"wave_shape": "sine",
		"harmonics": [[1.0, 1.0], [2.0, 0.2], [3.0, 0.45], [4.0, 0.1], [5.0, 0.2]],
		"name": "萨克斯", "name_en": "Saxophone",
		"desc": "摇摆节奏攻击，反拍强化",
		"core_mechanic": "swing_attack",
		"chord_interaction": ChordType.MAJOR_7,
	},
	ChapterTimbre.SYNTHESIZER: {
		"attack": 0.01, "decay": 0.05,
		"sustain": 0.75, "release": 0.03,
		"wave_shape": "square",
		"harmonics": [[1.0, 1.0], [3.0, 0.33], [5.0, 0.2], [7.0, 0.14]],
		"name": "合成主脑", "name_en": "Synthesizer",
		"desc": "波形变换攻击，频率操控",
		"core_mechanic": "waveform_morph",
		"chord_interaction": ChordType.DIMINISHED_7,
	},
}

## 电子乐变体 ADSR 参数（继承原音色参数，仅覆盖视觉/听觉相关字段）
const ELECTRONIC_VARIANT_DATA: Dictionary = {
	ElectronicVariant.NONE: {
		"name": "无", "desc": "未激活电子乐变体",
	},
	ElectronicVariant.SINE_WAVE_SYNTH: {
		"base_timbre": ChapterTimbre.LYRE,
		"name": "Sine Wave Synth", "name_cn": "正弦波合成",
		"desc": "弹体变为纯净的正弦波形",
		"visual": "sine_wave", "audio": "pure_sine",
	},
	ElectronicVariant.DRONE_SYNTH: {
		"base_timbre": ChapterTimbre.ORGAN,
		"name": "Drone Synth", "name_cn": "无人机音合成",
		"desc": "弹体变为低频脉冲波",
		"visual": "low_freq_pulse", "audio": "deep_drone",
	},
	ElectronicVariant.ARPEGGIATOR_SYNTH: {
		"base_timbre": ChapterTimbre.HARPSICHORD,
		"name": "Arpeggiator Synth", "name_cn": "琶音器合成",
		"desc": "弹体变为快速闪烁的像素点阵",
		"visual": "pixel_matrix", "audio": "electronic_arpeggio",
	},
	ElectronicVariant.VELOCITY_PAD: {
		"base_timbre": ChapterTimbre.FORTEPIANO,
		"name": "Velocity Pad", "name_cn": "力度感应垫",
		"desc": "弹体变为压力感应的光块",
		"visual": "pressure_block", "audio": "synth_pad",
	},
	ElectronicVariant.SUPERSAW_SYNTH: {
		"base_timbre": ChapterTimbre.TUTTI,
		"name": "Supersaw Synth", "name_cn": "超级锯齿波",
		"desc": "弹体变为锯齿波形的能量束",
		"visual": "sawtooth_beam", "audio": "thick_supersaw",
	},
	ElectronicVariant.FM_SYNTH: {
		"base_timbre": ChapterTimbre.SAXOPHONE,
		"name": "FM Synth", "name_cn": "FM合成器",
		"desc": "弹体变为频率调制的波形",
		"visual": "fm_waveform", "audio": "metallic_fm",
	},
	ElectronicVariant.GLITCH_ENGINE: {
		"base_timbre": ChapterTimbre.SYNTHESIZER,
		"name": "Glitch Engine", "name_cn": "故障引擎",
		"desc": "弹体变为数据碎片/故障方块",
		"visual": "data_fragment", "audio": "glitch_noise",
	},
}

## 章节音色武器 → 电子乐变体映射
const TIMBRE_TO_VARIANT: Dictionary = {
	ChapterTimbre.LYRE: ElectronicVariant.SINE_WAVE_SYNTH,
	ChapterTimbre.ORGAN: ElectronicVariant.DRONE_SYNTH,
	ChapterTimbre.HARPSICHORD: ElectronicVariant.ARPEGGIATOR_SYNTH,
	ChapterTimbre.FORTEPIANO: ElectronicVariant.VELOCITY_PAD,
	ChapterTimbre.TUTTI: ElectronicVariant.SUPERSAW_SYNTH,
	ChapterTimbre.SAXOPHONE: ElectronicVariant.FM_SYNTH,
	ChapterTimbre.SYNTHESIZER: ElectronicVariant.GLITCH_ENGINE,
}

## 章节音色武器核心机制参数
const TIMBRE_MECHANIC_PARAMS: Dictionary = {
	# Ch1 里拉琴 — 泛音共鸣
	ChapterTimbre.LYRE: {
		"resonance_radius": 60.0,        # 共鸣伤害半径 (px)
		"resonance_damage_ratio": 0.15,  # 共鸣伤害比例
		"ratio_bonus_2_1": 0.30,         # 2:1 比例伤害加成
		"ratio_bonus_3_2": 0.20,         # 3:2 比例伤害加成
		"ratio_bonus_4_3": 0.10,         # 4:3 比例伤害加成
	},
	# Ch2 管风琴 — 和声层叠
	ChapterTimbre.ORGAN: {
		"max_voice_layers": 4,           # 最大声部层数
		"size_per_layer": 0.10,          # 每层碰撞范围加成
		"damage_per_layer": 0.08,        # 每层伤害加成
		"layer_decay_time": 3.0,         # 声部层消退时间 (秒)
		"chant_duration": 2.0,           # 圣咏区域持续时间 (秒)
	},
	# Ch3 羽管键琴 — 对位交织
	ChapterTimbre.HARPSICHORD: {
		"counterpoint_delay": 0.2,       # 对位弹体生成延迟 (秒)
		"counterpoint_damage_ratio": 0.5, # 对位弹体伤害比例
		"resonance_bonus": 0.30,         # 对位共鸣额外伤害
	},
	# Ch4 钢琴 — 力度动态
	ChapterTimbre.FORTEPIANO: {
		"forte_multiplier": 1.5,         # forte 伤害倍率
		"mezzo_multiplier": 1.0,         # mezzo 伤害倍率
		"piano_multiplier": 0.7,         # piano 伤害倍率
		"forte_timing_window": 0.05,     # forte 判定窗口 (秒, ±50ms)
		"forte_knockback": true,         # forte 是否附带击退
	},
	# Ch5 管弦全奏 — 情感爆发
	ChapterTimbre.TUTTI: {
		"emotion_gain_per_attack": 2,    # 每次攻击情感增量
		"emotion_gain_per_hit": 15,      # 每次受伤情感增量
		"emotion_decay_per_sec": 3,      # 情感衰减速度 (/秒)
		"pianissimo_threshold": 30,      # pianissimo 阈值
		"forte_threshold": 70,           # forte 阈值
		"fortissimo_damage_mult": 1.5,   # fortissimo 伤害倍率
		"fortissimo_size_mult": 1.3,     # fortissimo 范围倍率
		"climax_damage_mult": 2.0,       # 高潮爆发伤害倍率
		"climax_duration": 3.0,          # 高潮爆发持续时间 (秒)
	},
	# Ch6 萨克斯 — 摇摆攻击
	ChapterTimbre.SAXOPHONE: {
		"swing_delay_ratio": 0.33,       # 摇摆延迟比例
		"offbeat_damage_bonus": 0.25,    # 反拍伤害加成
		"improvisation_threshold": 3,    # 触发即兴独奏的连续反拍次数
		"improvisation_duration": 5.0,   # 即兴独奏持续时间 (秒)
		"improvisation_speed_bonus": 0.30, # 即兴独奏施法速度加成
	},
	# Ch7 合成主脑 — 波形变换
	ChapterTimbre.SYNTHESIZER: {
		"waveform_bonus": 0.30,          # 对应属性加成
		"waveform_penalty": 0.10,        # 其他属性惩罚
		"morph_transition_time": 0.5,    # 变形过渡时间 (秒)
		"morph_blend_ratio": 0.5,        # 过渡期混合比例
		"sine_bonus_attr": "pierce",     # 正弦波加成属性
		"square_bonus_attr": "damage",   # 方波加成属性
		"sawtooth_bonus_attr": "size",   # 锯齿波加成属性
		"triangle_bonus_attr": "speed",  # 三角波加成属性
	},
}

# ============================================================
# 向后兼容：保留旧版 ADSR 数据（映射到新系统）
# ============================================================

## 旧版音色切换疲劳代价（已弃用，保留向后兼容）
const TIMBRE_SWITCH_FATIGUE_COST: float = 0.05

## 旧版 ADSR 数据（映射到新的章节音色武器）
const TIMBRE_ADSR: Dictionary = {
	TimbreType.NONE: CHAPTER_TIMBRE_ADSR[ChapterTimbre.NONE],
	TimbreType.PLUCKED: CHAPTER_TIMBRE_ADSR[ChapterTimbre.LYRE],
	TimbreType.BOWED: CHAPTER_TIMBRE_ADSR[ChapterTimbre.ORGAN],
	TimbreType.WIND: CHAPTER_TIMBRE_ADSR[ChapterTimbre.SAXOPHONE],
	TimbreType.PERCUSSIVE: CHAPTER_TIMBRE_ADSR[ChapterTimbre.FORTEPIANO],
}

# ============================================================
# 音频合成数据
# ============================================================

## 12 半音的标准频率 (C4 = 中央C, A4 = 440Hz)
const NOTE_FREQUENCIES: Dictionary = {
	Note.C:  261.63,
	Note.CS: 277.18,
	Note.D:  293.66,
	Note.DS: 311.13,
	Note.E:  329.63,
	Note.F:  349.23,
	Note.FS: 369.99,
	Note.G:  392.00,
	Note.GS: 415.30,
	Note.A:  440.00,
	Note.AS: 466.16,
	Note.B:  493.88,
}

## 白键到 Note 枚举的映射
const WHITE_KEY_TO_NOTE: Dictionary = {
	WhiteKey.C: Note.C,
	WhiteKey.D: Note.D,
	WhiteKey.E: Note.E,
	WhiteKey.F: Note.F,
	WhiteKey.G: Note.G,
	WhiteKey.A: Note.A,
	WhiteKey.B: Note.B,
}
