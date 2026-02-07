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

# ============================================================
# 静态数据表
# ============================================================

## 白键音符四维参数 (DMG, SPD, DUR, SIZE) 总和恒定为12
const WHITE_KEY_STATS: Dictionary = {
	WhiteKey.C: { "dmg": 3, "spd": 3, "dur": 3, "size": 3, "name": "C", "desc": "均衡型" },
	WhiteKey.D: { "dmg": 2, "spd": 5, "dur": 3, "size": 2, "name": "D", "desc": "极速远程" },
	WhiteKey.E: { "dmg": 2, "spd": 2, "dur": 4, "size": 4, "name": "E", "desc": "大范围持久" },
	WhiteKey.F: { "dmg": 2, "spd": 1, "dur": 5, "size": 4, "name": "F", "desc": "区域控制" },
	WhiteKey.G: { "dmg": 5, "spd": 3, "dur": 2, "size": 2, "name": "G", "desc": "爆发伤害" },
	WhiteKey.A: { "dmg": 4, "spd": 2, "dur": 4, "size": 2, "name": "A", "desc": "持久高伤" },
	WhiteKey.B: { "dmg": 4, "spd": 4, "dur": 2, "size": 2, "name": "B", "desc": "高速高伤" },
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
const CHORD_SPELL_MAP: Dictionary = {
	ChordType.MAJOR:         { "form": SpellForm.ENHANCED_PROJECTILE, "name": "强化弹体", "multiplier": 1.5 },
	ChordType.MINOR:         { "form": SpellForm.DOT_PROJECTILE, "name": "DOT弹体", "multiplier": 1.2 },
	ChordType.AUGMENTED:     { "form": SpellForm.EXPLOSIVE, "name": "爆炸弹体", "multiplier": 1.8 },
	ChordType.DIMINISHED:    { "form": SpellForm.SHOCKWAVE, "name": "冲击波", "multiplier": 2.0 },
	ChordType.DOMINANT_7:    { "form": SpellForm.FIELD, "name": "法阵/区域", "multiplier": 1.0 },
	ChordType.DIMINISHED_7:  { "form": SpellForm.DIVINE_STRIKE, "name": "天降打击", "multiplier": 3.0 },
	ChordType.MAJOR_7:       { "form": SpellForm.SHIELD_HEAL, "name": "护盾/治疗法阵", "multiplier": 0.0 },
	ChordType.MINOR_7:       { "form": SpellForm.SUMMON, "name": "召唤/构造", "multiplier": 0.8 },
	ChordType.SUSPENDED:     { "form": SpellForm.CHARGED, "name": "蓄力弹体", "multiplier": 2.0 },
	# 扩展和弦
	ChordType.DOMINANT_9:    { "form": SpellForm.STORM_FIELD, "name": "风暴区域", "multiplier": 0.5 },
	ChordType.MAJOR_9:       { "form": SpellForm.HOLY_DOMAIN, "name": "圣光领域", "multiplier": 0.0 },
	ChordType.DIMINISHED_9:  { "form": SpellForm.ANNIHILATION_RAY, "name": "湮灭射线", "multiplier": 4.0 },
	ChordType.DOMINANT_11:   { "form": SpellForm.TIME_RIFT, "name": "时空裂隙", "multiplier": 0.6 },
	ChordType.DOMINANT_13:   { "form": SpellForm.SYMPHONY_STORM, "name": "交响风暴", "multiplier": 1.0 },
	ChordType.DIMINISHED_13: { "form": SpellForm.FINALE, "name": "终焉乐章", "multiplier": 5.0 },
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
