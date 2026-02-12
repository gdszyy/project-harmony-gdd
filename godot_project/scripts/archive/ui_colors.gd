## ui_colors.gd
## 全局 UI 色彩规范 (Autoload)
##
## 作为所有 UI 颜色的"单一事实来源"，确保全局视觉一致性。
## 基于 Art_Direction_Resonance_Horizon.md 中的"数字-以太"美学。
## 参见 Docs/UI_Art_Style_Enhancement_Proposal.md
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

## 成功/治疗
const SUCCESS := Color("#4DFF80")

## 危险/伤害
const DANGER := Color("#FF4D4D")

## 警告
const WARNING := Color("#FF8C42")

# ============================================================
# 文本色彩
# ============================================================

## 文本主色
const TEXT_PRIMARY := Color("#EAE6FF")

## 文本次色
const TEXT_SECONDARY := Color("#A098C8")

## 文本暗色 (禁用/锁定)
const TEXT_DIM := Color("#6B668A")

## 文本锁定色
const TEXT_LOCKED := Color("#4A4660")

# ============================================================
# 功能性颜色
# ============================================================

## HP 条
const HP_FULL := Color("#C73B5F")
const HP_LOW := Color("#FF4D4D")
const HP_BG := Color("#141026")

## 护盾
const SHIELD := Color("#4DFFF3")

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
# 音符颜色 (白键 C-B)
# ============================================================

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

## 获取音符颜色
static func get_note_color(note: String) -> Color:
	return NOTE_COLORS.get(note, TEXT_PRIMARY)
