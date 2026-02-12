## ui_colors.gd
## 全局 UI 色彩规范 (Autoload)
##
## 作为所有 UI 颜色的"单一事实来源"，确保全局视觉一致性。
## 基于 Art_Direction_Resonance_Horizon.md 中的"数字-以太"美学。
## 参见 Docs/UI_Art_Style_Enhancement_Proposal.md
##
## [THEME-01][THEME-02] 统一重构 — 所有 UI 脚本必须引用此文件的常量/方法，
## 禁止在脚本中硬编码 Color() 值。
extends Node

# ============================================================
# 核心调色板
# ============================================================

## 主背景色 (深邃的星空紫)
const PRIMARY_BG := Color("#0A0814")

## 面板/卡片色 (带有细微噪点的深蓝紫)
const PANEL_BG := Color("#141026")

## 面板变体 (略深/略浅)
const PANEL_DARK := Color("#100C20")
const PANEL_LIGHT := Color("#18142C")
const PANEL_LIGHTER := Color("#201A38")
const PANEL_SELECTED := Color("#2A2248")

## 主强调色 (明亮的霓虹紫)
const ACCENT := Color("#9D6FFF")

## 次强调色 (清冷的青色)
const ACCENT_2 := Color("#4DFFF3")

## 金色/传说级
const GOLD := Color("#FFD700")

## 金色高亮
const GOLD_BRIGHT := Color("#FFED4A")

## 成功/治疗
const SUCCESS := Color("#4DFF80")

## 危险/伤害
const DANGER := Color("#FF4D4D")

## 错误红
const ERROR_RED := Color("#FF2244")

## 警告
const WARNING := Color("#FF8C42")

## 信息色 (青)
const INFO := Color("#4DFFF3")

## 谐振青 (用于特殊高亮)
const CYAN := Color("#00E5FF")

# ============================================================
# 文本色彩
# ============================================================

## 文本主色 (晶体白)
const TEXT_PRIMARY := Color("#EAE6FF")

## 文本次色
const TEXT_SECONDARY := Color("#A098C8")

## 文本暗色 (禁用/锁定)
const TEXT_DIM := Color("#6B668A")

## 文本锁定色
const TEXT_LOCKED := Color("#4A4660")

## 文本辅助色 (用于标签、提示等)
const TEXT_HINT := Color("#9D8FBF")

# ============================================================
# 功能性颜色
# ============================================================

## HP 条
const HP_FULL := Color("#C73B5F")
const HP_LOW := Color("#FF4D4D")
const HP_BG := Color("#141026")

## 护盾
const SHIELD := Color("#4DFFF3")

## 暴击
const CRIT := Color("#FF9933")

## 攻击性 (进攻)
const OFFENSE := Color("#FF4444")

## 防御性
const DEFENSE := Color("#4488FF")

## 疲劳等级颜色
const FATIGUE_NONE := Color("#4DFF80")
const FATIGUE_MILD := Color("#FFD700")
const FATIGUE_MODERATE := Color("#FF8C42")
const FATIGUE_SEVERE := Color("#FF4D4D")
const FATIGUE_CRITICAL := Color("#FF0033")

## 稀有度颜色
const RARITY_COMMON := Color("#A098C8")
const RARITY_RARE := Color("#4D8BFF")
const RARITY_EPIC := Color("#9D6FFF")
const RARITY_LEGENDARY := Color("#FFD700")

# ============================================================
# 和弦功能颜色
# ============================================================

## 主功能 (Tonic) — 稳定
const CHORD_TONIC := Color("#4D8BFF")

## 属功能 (Dominant) — 紧张
const CHORD_DOMINANT := Color("#FFD700")

## 下属功能 (Pre-Dominant) — 过渡
const CHORD_PRE_DOMINANT := Color("#9D6FFF")

# ============================================================
# 调式颜色
# ============================================================

const MODE_IONIAN := Color("#9D6FFF")
const MODE_DORIAN := Color("#FF8C42")
const MODE_PENTATONIC := Color("#4DFFF3")
const MODE_BLUES := Color("#FF4D6A")

# ============================================================
# 不谐和度等级颜色
# ============================================================

const DISSONANCE_LOW := Color(0.2, 0.7, 0.4)
const DISSONANCE_MID := Color(1.0, 0.8, 0.0)
const DISSONANCE_HIGH := Color(1.0, 0.2, 0.1)

# ============================================================
# 密度等级颜色
# ============================================================

const DENSITY_SAFE := Color(0.3, 0.6, 1.0)
const DENSITY_WARN := Color(1.0, 0.6, 0.0)
const DENSITY_OVERLOAD := Color(1.0, 0.15, 0.1)

# ============================================================
# 过载等级颜色 (用于 game_mechanics_panel 等)
# ============================================================

const OVERLOAD_COLORS := {
	0: Color(0.0, 0.8, 0.4),
	1: Color(0.7, 0.8, 0.0),
	2: Color(1.0, 0.6, 0.0),
	3: Color(1.0, 0.2, 0.0),
	4: Color(0.8, 0.0, 0.2),
}

# ============================================================
# 音符颜色 (白键 C-B) — 唯一标准定义
# ============================================================

const NOTE_NAMES := ["C", "D", "E", "F", "G", "A", "B"]

const NOTE_COLORS: Dictionary = {
	"C": Color("#FF6B6B"),  # 红
	"D": Color("#FF8C42"),  # 橙
	"E": Color("#FFD700"),  # 黄
	"F": Color("#4DFF80"),  # 绿
	"G": Color("#4DFFF3"),  # 青
	"A": Color("#4D8BFF"),  # 蓝
	"B": Color("#9D6FFF"),  # 紫
}

# ============================================================
# 黑键颜色 (升半音 C#-A#) — 白键暗化变体
# ============================================================

const BLACK_KEY_COLORS: Dictionary = {
	0: Color("#CC5555"),  # C#
	1: Color("#CC7035"),  # D#
	2: Color("#8844FF"),  # F#
	3: Color("#CC3636"),  # G#
	4: Color("#CC6600"),  # A#
}

# ============================================================
# 法术形态颜色 (Spell Form Colors)
# ============================================================

const FORM_COLORS: Dictionary = {
	"enhanced_projectile": Color("#FFD94D"),
	"dot_projectile": Color("#3366CC"),
	"explosive_projectile": Color("#FF6633"),
	"shockwave": Color("#8822BB"),
	"magic_circle": Color("#FFCC00"),
	"celestial_strike": Color("#CC1111"),
	"shield_heal": Color("#33E666"),
	"summon_construct": Color("#2233BB"),
	"charged_projectile": Color("#D9D9F2"),
	"slow_field": Color("#4D4DBB"),
	"generic_blast": Color("#808080"),
}

# ============================================================
# 障碍物类型颜色 (用于 codex_ui 等)
# ============================================================

const HAZARD_COLORS: Dictionary = {
	"static":  Color(0.7, 0.3, 0.3),
	"silence": Color(0.2, 0.1, 0.4),
	"screech": Color(1.0, 0.8, 0.0),
	"pulse":   Color(0.0, 0.5, 1.0),
	"wall":    Color(0.5, 0.5, 0.5),
}

# ============================================================
# 音色象限颜色 (Timbre Wheel)
# ============================================================

const TIMBRE_SYNTH := Color("#4DFFF3")
const TIMBRE_PLUCK := Color("#FF8C42")
const TIMBRE_BOW := Color("#9D6FFF")
const TIMBRE_WIND := Color("#4DFF80")
const TIMBRE_CENTER := Color("#00E6B8")

# ============================================================
# 乐器族群颜色 (用于 debug_panel 等)
# ============================================================

const INSTRUMENT_FAMILY_COLORS := [
	Color(0.0, 1.0, 0.8),   # 合成器
	Color(0.85, 0.75, 0.3),  # 弹拨
	Color(0.8, 0.2, 0.3),   # 拉弦
	Color(0.6, 0.9, 0.7),   # 吹奏
	Color(0.9, 0.9, 0.9),   # 打击
]

# ============================================================
# 和谐殿堂模块颜色 (Hall of Harmony)
# ============================================================

const HALL_MODULE_COLORS := {
	"melody": Color(0.2, 0.8, 1.0),
	"harmony": Color(0.8, 0.4, 1.0),
	"rhythm": Color(1.0, 0.6, 0.2),
	"mastery": Color(0.3, 1.0, 0.5),
}

# ============================================================
# 难度颜色
# ============================================================

const DIFFICULTY_EASY := Color(0.3, 0.9, 0.5)
const DIFFICULTY_NORMAL := Color(0.3, 0.7, 1.0)
const DIFFICULTY_HARD := Color(1.0, 0.6, 0.2)
const DIFFICULTY_EXPERT := Color(1.0, 0.2, 0.2)

# ============================================================
# 彩虹色序列 (用于 debug 等级指示)
# ============================================================

const RAINBOW_SEQUENCE := [
	Color(1.0, 0.3, 0.3),   # 红
	Color(1.0, 0.6, 0.2),   # 橙
	Color(1.0, 1.0, 0.3),   # 黄
	Color(0.3, 1.0, 0.3),   # 绿
	Color(0.3, 0.8, 1.0),   # 青
	Color(0.5, 0.3, 1.0),   # 蓝
	Color(0.9, 0.3, 0.9),   # 紫
]

# ============================================================
# 边框色
# ============================================================

const BORDER_DEFAULT := Color("#2A2040")

# ============================================================
# 遮罩色
# ============================================================

const MASK_COLOR := Color(0.0, 0.0, 0.0, 0.7)



# ============================================================
# 特殊效果颜色
# ============================================================

## 谐振青 (弹幕/特效)
const RESONANCE_CYAN := Color(0.0, 1.0, 0.831)

## 数据橙 (弹幕/特效)
const DATA_ORANGE := Color(1.0, 0.533, 0.0)

## 故障洋红 (弹幕/特效)
const GLITCH_MAGENTA := Color(1.0, 0.0, 0.667)

## 腐蚀紫 (弹幕/特效)
const CORRUPT_PURPLE := Color(0.533, 0.0, 1.0)

## 治愈绿 (弹幕/特效)
const HEAL_GREEN := Color(0.4, 1.0, 0.698)

## 疲劳黄 (疲劳条)
const FATIGUE_YELLOW := Color(1.0, 0.875, 0.4)

# ============================================================
# Boss 阶段颜色
# ============================================================

const BOSS_PHASE_COLORS := {
	1: Color(0.0, 1.0, 0.831),    # 谐振青 (毕达哥拉斯)
	2: Color(0.4, 0.15, 0.1),     # 暗红 (圭多)
	3: Color(0.7, 0.55, 0.2),     # 黄铜 (巴赫)
	5: Color(0.85, 0.15, 0.1),    # 橙红 (贝多芬)
	6: Color(0.2, 0.5, 1.0),      # 霓虹蓝 (爵士)
}

const BOSS_RAGE_COLORS := {
	3: Color(0.5, 0.4, 0.15),     # 暗金
	5: Color(1.0, 0.6, 0.15),     # 闪电橙
	6: Color(1.0, 0.3, 0.6),      # 霓虹粉
	7: Color(1.0, 0.0, 0.667),    # 故障洋红
}

# ============================================================
# Boss 对话情感颜色
# ============================================================

const EMOTION_COLORS: Dictionary = {
	"solemn": Color(0.8, 0.75, 0.5),
	"commanding": Color(0.9, 0.8, 0.4),
	"challenge": Color(1.0, 0.4, 0.3),
	"surprised": Color(0.5, 0.8, 1.0),
	"accepting": Color(0.6, 0.9, 0.7),
	"reverent": Color(0.7, 0.6, 1.0),
	"stern": Color(0.5, 0.4, 0.7),
	"enlightened": Color(1.0, 0.95, 0.7),
	"proud": Color(0.8, 0.6, 0.3),
	"respectful": Color(0.6, 0.8, 0.6),
	"blessing": Color(0.9, 0.85, 0.5),
	"elegant": Color(0.9, 0.8, 1.0),
	"disdainful": Color(0.8, 0.5, 0.9),
	"inviting": Color(0.7, 0.9, 1.0),
	"impressed": Color(0.5, 0.9, 0.8),
	"passionate": Color(1.0, 0.5, 0.3),
	"moved": Color(0.6, 0.7, 1.0),
	"encouraging": Color(0.8, 0.9, 0.5),
	"cool": Color(0.3, 0.5, 0.9),
	"serious": Color(0.5, 0.4, 0.6),
	"glitch": Color(0.0, 1.0, 0.5),
	"cold": Color(0.3, 0.3, 0.5),
	"final": Color(0.8, 0.0, 0.3),
	"neutral": Color(0.7, 0.7, 0.7),
}

## 获取情感颜色
static func get_emotion_color(emotion: String) -> Color:
	return EMOTION_COLORS.get(emotion, Color(0.7, 0.7, 0.7))
# ============================================================
# 辅助方法
# ============================================================

## 获取带透明度的颜色
static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)

## 获取稀有度颜色
static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return RARITY_COMMON
		"rare": return RARITY_RARE
		"epic": return RARITY_EPIC
		"legendary": return RARITY_LEGENDARY
		_: return RARITY_COMMON

## 获取疲劳等级颜色
static func get_fatigue_color(level: String) -> Color:
	match level:
		"NONE": return FATIGUE_NONE
		"MILD": return FATIGUE_MILD
		"MODERATE": return FATIGUE_MODERATE
		"SEVERE": return FATIGUE_SEVERE
		"CRITICAL": return FATIGUE_CRITICAL
		_: return FATIGUE_NONE

## 获取音符颜色 (按音名)
static func get_note_color(note_name: String) -> Color:
	return NOTE_COLORS.get(note_name.to_upper(), TEXT_PRIMARY)

## 获取音符颜色 (按整数索引 0-6 → C D E F G A B)
static func get_note_color_by_int(note_index: int) -> Color:
	if note_index >= 0 and note_index < NOTE_NAMES.size():
		return get_note_color(NOTE_NAMES[note_index])
	return TEXT_PRIMARY

## 获取黑键颜色 (按整数索引)
static func get_black_key_color(index: int) -> Color:
	return BLACK_KEY_COLORS.get(index, Color(0.4, 0.4, 0.4))

## 获取法术形态颜色
static func get_form_color(form_name: String) -> Color:
	return FORM_COLORS.get(form_name, TEXT_SECONDARY)

## 获取过载等级颜色
static func get_overload_color(level: int) -> Color:
	return OVERLOAD_COLORS.get(level, DISSONANCE_LOW)

## 获取障碍物颜色
static func get_hazard_color(hazard_type: String) -> Color:
	return HAZARD_COLORS.get(hazard_type, TEXT_DIM)

## 获取和谐殿堂模块颜色
static func get_hall_module_color(module_name: String) -> Color:
	return HALL_MODULE_COLORS.get(module_name, ACCENT)
