"""
=============================================================================
Project Harmony — 平衡性跑分系统 (Balance Scoring System)
=============================================================================

本模块实现了一套自动化的数值平衡性评估框架，用于量化任意法术策略
组合的综合得分，帮助设计师在新增或修改数值时快速验证平衡性。

设计理念：
    - 将每种策略建模为一个"8小节乐段"的施法序列
    - 从 DPS产出、生存风险、疲劳代价 三个维度进行量化评估
    - 通过加权综合得分实现不同策略的横向对比
    - 支持数值成长（肉鸽升级）后的重新评估

方法论：
    综合得分 S = w_dps * S_dps + w_surv * S_survival - w_risk * S_risk
    其中：
        S_dps      = 有效DPS评分（考虑疲劳衰减后的实际输出）
        S_survival = 生存评分（治疗/护盾/闪避贡献）
        S_risk     = 风险评分（不和谐扣血 + 密度过载 + 单调锁定的期望损失）

作者：Manus AI
版本：v1.0
日期：2026年2月7日
=============================================================================
"""

from __future__ import annotations

import math
import json
import copy
from dataclasses import dataclass, field
from typing import Optional
from enum import Enum


# =============================================================================
# 第一部分：基础常量与数据定义
# =============================================================================

# ---- 参数转换比率 ----
DMG_PER_POINT = 10      # 每点伤害参数 = 10基础伤害
SPD_PER_POINT = 200     # 每点速度参数 = 200像素/秒
DUR_PER_POINT = 0.5     # 每点持续参数 = 0.5秒
SIZE_PER_POINT = 8      # 每点大小参数 = 8像素碰撞半径

# ---- 全局节奏参数 ----
DEFAULT_BPM = 120
DEFAULT_BEAT_INTERVAL = 60.0 / DEFAULT_BPM  # 0.5秒

# ---- 玩家基础属性 ----
PLAYER_BASE_HP = 200
PLAYER_HP_REGEN = 1.0   # 每秒
PLAYER_MOVE_SPEED = 250  # 像素/秒


@dataclass
class NoteStats:
    """单个音符的四维属性（含成长加成）。"""
    name: str
    base_dmg: int
    base_spd: int
    base_dur: int
    base_size: int
    # 成长加成（来自肉鸽升级）
    bonus_dmg: float = 0.0
    bonus_spd: float = 0.0
    bonus_dur: float = 0.0
    bonus_size: float = 0.0

    @property
    def total_dmg(self) -> float:
        return self.base_dmg + self.bonus_dmg

    @property
    def total_spd(self) -> float:
        return self.base_spd + self.bonus_spd

    @property
    def total_dur(self) -> float:
        return self.base_dur + self.bonus_dur

    @property
    def total_size(self) -> float:
        return self.base_size + self.bonus_size

    @property
    def actual_damage(self) -> float:
        return self.total_dmg * DMG_PER_POINT

    @property
    def actual_speed(self) -> float:
        return self.total_spd * SPD_PER_POINT

    @property
    def actual_duration(self) -> float:
        return self.total_dur * DUR_PER_POINT

    @property
    def actual_radius(self) -> float:
        return self.total_size * SIZE_PER_POINT

    @property
    def hit_factor(self) -> float:
        """命中因子：基于SIZE和SPD的综合估算。"""
        return min(1.0, (self.total_size * self.total_spd) / 12.0)

    @property
    def effective_dps(self) -> float:
        """有效DPS（不含疲劳惩罚）。"""
        return self.actual_damage * self.hit_factor / DEFAULT_BEAT_INTERVAL

    @property
    def coverage_area(self) -> float:
        """覆盖面积 π*r²。"""
        return math.pi * self.actual_radius ** 2


def create_base_notes() -> dict[str, NoteStats]:
    """创建7个白键音符的基础属性。"""
    return {
        "C": NoteStats("C", 3, 3, 3, 3),
        "D": NoteStats("D", 2, 5, 3, 2),
        "E": NoteStats("E", 2, 2, 4, 4),
        "F": NoteStats("F", 2, 1, 5, 4),
        "G": NoteStats("G", 5, 3, 2, 2),
        "A": NoteStats("A", 4, 2, 4, 2),
        "B": NoteStats("B", 4, 4, 2, 2),
    }


# =============================================================================
# 第二部分：和弦系统（含扩展和弦）
# =============================================================================

@dataclass
class ChordType:
    """和弦类型定义。"""
    name: str
    note_count: int
    base_dissonance: float
    spell_form: str
    dmg_multiplier: float
    fatigue_dissonance: float
    # 特殊效果参数
    dot_total_ratio: float = 0.0       # DOT总伤害比
    explosion_radius_mult: float = 0.0  # 爆炸半径倍率
    explosion_dmg_ratio: float = 0.0    # 爆炸伤害比
    aoe_radius_mult: float = 0.0       # AOE半径倍率
    delay_beats: float = 0.0           # 延迟拍数
    heal_ratio: float = 0.0            # 治疗量（基于根音DMG）
    shield_ratio: float = 0.0          # 护盾量（基于根音DMG）
    summon_duration_mult: float = 0.0  # 召唤物持续时间倍率
    summon_dps_ratio: float = 0.0      # 召唤物DPS比
    zone_duration_mult: float = 0.0    # 区域持续时间倍率
    zone_tick_ratio: float = 0.0       # 区域每跳伤害比
    # 扩展和弦特有
    is_extended: bool = False
    extra_effect: str = ""


def create_chord_registry() -> dict[str, ChordType]:
    """创建完整的和弦类型注册表（含3/4/5/6音扩展和弦）。"""
    chords = {}

    # ---- 三和弦 (3音) ----
    chords["大三和弦"] = ChordType(
        "大三和弦", 3, 2.00, "强化弹体", 1.5, 0.05)
    chords["小三和弦"] = ChordType(
        "小三和弦", 3, 2.00, "DOT弹体", 0.6, 0.05,
        dot_total_ratio=1.8)
    chords["增三和弦"] = ChordType(
        "增三和弦", 3, 2.00, "爆炸弹体", 0.8, 0.10,
        explosion_radius_mult=3.0, explosion_dmg_ratio=0.5)
    chords["减三和弦"] = ChordType(
        "减三和弦", 3, 4.67, "冲击波", 1.2, 0.20,
        aoe_radius_mult=5.0)
    chords["挂留和弦"] = ChordType(
        "挂留和弦", 3, 1.17, "蓄力弹体", 2.0, 0.02,
        delay_beats=1.0)

    # ---- 七和弦 (4音) ----
    chords["属七和弦"] = ChordType(
        "属七和弦", 4, 3.50, "持续区域", 0.4, 0.15,
        zone_duration_mult=2.0, zone_tick_ratio=0.4)
    chords["减七和弦"] = ChordType(
        "减七和弦", 4, 6.00, "天降打击", 3.0, 0.30,
        delay_beats=2.0)
    chords["大七和弦"] = ChordType(
        "大七和弦", 4, 2.50, "护盾/治疗", 0.0, 0.08,
        heal_ratio=15.0, shield_ratio=20.0)
    chords["小七和弦"] = ChordType(
        "小七和弦", 4, 3.00, "召唤/构造", 0.5, 0.12,
        summon_duration_mult=3.0, summon_dps_ratio=0.5)

    # ---- 九和弦 (5音) ----
    chords["属九和弦"] = ChordType(
        "属九和弦", 5, 5.00, "风暴区域", 0.5, 0.25,
        zone_duration_mult=2.5, zone_tick_ratio=0.6,
        is_extended=True,
        extra_effect="区域内敌人减速30%")
    chords["大九和弦"] = ChordType(
        "大九和弦", 5, 3.50, "圣光领域", 0.0, 0.15,
        heal_ratio=20.0, shield_ratio=25.0,
        is_extended=True,
        extra_effect="领域内队友持续回血(2/秒)")
    chords["小九和弦"] = ChordType(
        "小九和弦", 5, 4.50, "深渊召唤", 0.7, 0.22,
        summon_duration_mult=4.0, summon_dps_ratio=0.7,
        is_extended=True,
        extra_effect="召唤物具有嘲讽效果")
    chords["减九和弦"] = ChordType(
        "减九和弦", 5, 7.50, "湮灭射线", 4.0, 0.40,
        delay_beats=3.0,
        is_extended=True,
        extra_effect="直线贯穿，无视防御")

    # ---- 十一和弦 (5-6音) ----
    chords["属十一和弦"] = ChordType(
        "属十一和弦", 5, 6.00, "时空裂隙", 0.6, 0.30,
        zone_duration_mult=3.0, zone_tick_ratio=0.5,
        is_extended=True,
        extra_effect="区域内时间减速50%（敌人攻速/移速减半）")
    chords["大十一和弦"] = ChordType(
        "大十一和弦", 5, 4.00, "天穹护罩", 0.0, 0.18,
        shield_ratio=35.0,
        is_extended=True,
        extra_effect="护罩存续期间免疫一次致死伤害")

    # ---- 十三和弦 (6-7音) ----
    chords["属十三和弦"] = ChordType(
        "属十三和弦", 6, 7.00, "交响风暴", 1.0, 0.45,
        zone_duration_mult=4.0, zone_tick_ratio=0.8,
        aoe_radius_mult=8.0,
        is_extended=True,
        extra_effect="全屏持续AOE，每跳附加随机元素效果")
    chords["减十三和弦"] = ChordType(
        "减十三和弦", 6, 9.50, "终焉乐章", 5.0, 0.60,
        delay_beats=4.0, aoe_radius_mult=10.0,
        is_extended=True,
        extra_effect="延迟后全屏毁灭打击，施法者自身受到20%最大生命值伤害")

    return chords


# =============================================================================
# 第三部分：数值成长系统
# =============================================================================

class UpgradeCategory(Enum):
    """升级类别。"""
    NOTE_STAT = "音符属性强化"
    FATIGUE_TOLERANCE = "疲劳耐受强化"
    RHYTHM_MASTERY = "节奏精通"
    CHORD_MASTERY = "和弦精通"
    SURVIVAL = "生存强化"


@dataclass
class Upgrade:
    """单个升级项定义。"""
    id: str
    name: str
    category: UpgradeCategory
    description: str
    max_level: int
    # 每级效果（线性叠加）
    effect_per_level: dict[str, float]
    # 稀有度权重（影响出现概率）
    rarity: int = 1  # 1=普通, 2=稀有, 3=史诗, 4=传说


def create_upgrade_pool() -> list[Upgrade]:
    """创建完整的肉鸽升级池。"""
    pool = []

    # ---- 音符属性强化 ----
    pool.append(Upgrade(
        "note_dmg", "伤害增幅", UpgradeCategory.NOTE_STAT,
        "选择一个音符，其DMG参数+0.5",
        max_level=6, effect_per_level={"dmg": 0.5}, rarity=1))
    pool.append(Upgrade(
        "note_spd", "弹速增幅", UpgradeCategory.NOTE_STAT,
        "选择一个音符，其SPD参数+0.5",
        max_level=6, effect_per_level={"spd": 0.5}, rarity=1))
    pool.append(Upgrade(
        "note_dur", "持久增幅", UpgradeCategory.NOTE_STAT,
        "选择一个音符，其DUR参数+0.5",
        max_level=6, effect_per_level={"dur": 0.5}, rarity=1))
    pool.append(Upgrade(
        "note_size", "范围增幅", UpgradeCategory.NOTE_STAT,
        "选择一个音符，其SIZE参数+0.5",
        max_level=6, effect_per_level={"size": 0.5}, rarity=1))
    pool.append(Upgrade(
        "note_all", "全维强化", UpgradeCategory.NOTE_STAT,
        "选择一个音符，其所有参数+0.25",
        max_level=4, effect_per_level={"dmg": 0.25, "spd": 0.25, "dur": 0.25, "size": 0.25},
        rarity=3))
    pool.append(Upgrade(
        "global_dmg", "全局伤害", UpgradeCategory.NOTE_STAT,
        "所有音符DMG参数+0.3",
        max_level=5, effect_per_level={"global_dmg": 0.3}, rarity=2))

    # ---- 疲劳耐受强化 ----
    pool.append(Upgrade(
        "monotony_tolerance", "单调耐受", UpgradeCategory.FATIGUE_TOLERANCE,
        "单调值累积速率-10%（每次重复累积从+15降低）",
        max_level=5, effect_per_level={"monotony_rate_mult": -0.10}, rarity=2))
    pool.append(Upgrade(
        "density_tolerance", "密度耐受", UpgradeCategory.FATIGUE_TOLERANCE,
        "密度值累积速率-10%",
        max_level=5, effect_per_level={"density_rate_mult": -0.10}, rarity=2))
    pool.append(Upgrade(
        "dissonance_tolerance", "不和谐耐受", UpgradeCategory.FATIGUE_TOLERANCE,
        "不和谐值累积速率-8%",
        max_level=5, effect_per_level={"dissonance_rate_mult": -0.08}, rarity=2))
    pool.append(Upgrade(
        "monotony_decay", "单调消散", UpgradeCategory.FATIGUE_TOLERANCE,
        "单调值自然衰减速率+1/秒",
        max_level=4, effect_per_level={"monotony_decay_bonus": 1.0}, rarity=2))
    pool.append(Upgrade(
        "density_decay", "密度消散", UpgradeCategory.FATIGUE_TOLERANCE,
        "密度值自然衰减速率+0.5/秒",
        max_level=4, effect_per_level={"density_decay_bonus": 0.5}, rarity=2))
    pool.append(Upgrade(
        "dissonance_decay", "不和谐消散", UpgradeCategory.FATIGUE_TOLERANCE,
        "不和谐值自然衰减速率+0.5/秒",
        max_level=4, effect_per_level={"dissonance_decay_bonus": 0.5}, rarity=2))
    pool.append(Upgrade(
        "afi_resistance", "全局疲劳抗性", UpgradeCategory.FATIGUE_TOLERANCE,
        "AFI疲劳等级对单音寂静累积速率的放大系数-0.1",
        max_level=4, effect_per_level={"afi_amplify_reduction": 0.1}, rarity=3))

    # ---- 节奏精通 ----
    pool.append(Upgrade(
        "bpm_boost", "节奏加速", UpgradeCategory.RHYTHM_MASTERY,
        "基础BPM+5（更快的施法节奏）",
        max_level=6, effect_per_level={"bpm_bonus": 5}, rarity=2))
    pool.append(Upgrade(
        "rest_efficiency", "休止精通", UpgradeCategory.RHYTHM_MASTERY,
        "休止符的密度值消减效果+5",
        max_level=4, effect_per_level={"rest_density_reduction_bonus": 5}, rarity=1))
    pool.append(Upgrade(
        "rest_power", "蓄力精通", UpgradeCategory.RHYTHM_MASTERY,
        "休止符对其他弹体的DMG/SIZE加成+0.15",
        max_level=4, effect_per_level={"rest_charge_bonus": 0.15}, rarity=2))
    pool.append(Upgrade(
        "rhythm_diversity", "节奏多样性", UpgradeCategory.RHYTHM_MASTERY,
        "使用不同节奏型时额外获得疲劳恢复-5",
        max_level=3, effect_per_level={"rhythm_fatigue_recovery": 5}, rarity=2))

    # ---- 和弦精通 ----
    pool.append(Upgrade(
        "chord_dmg", "和弦威力", UpgradeCategory.CHORD_MASTERY,
        "所有和弦的伤害倍率+0.1x",
        max_level=5, effect_per_level={"chord_dmg_bonus": 0.1}, rarity=2))
    pool.append(Upgrade(
        "chord_dissonance_resist", "和声控制", UpgradeCategory.CHORD_MASTERY,
        "和弦产生的疲劳不和谐值-10%",
        max_level=5, effect_per_level={"chord_dissonance_mult": -0.10}, rarity=2))
    pool.append(Upgrade(
        "extended_chord_unlock", "扩展和弦解锁", UpgradeCategory.CHORD_MASTERY,
        "解锁5音/6音扩展和弦的使用能力",
        max_level=1, effect_per_level={"extended_chord_enabled": 1}, rarity=4))
    pool.append(Upgrade(
        "progression_power", "进行增幅", UpgradeCategory.CHORD_MASTERY,
        "和弦进行的完整度奖励倍率+0.15x",
        max_level=4, effect_per_level={"progression_bonus": 0.15}, rarity=3))
    pool.append(Upgrade(
        "resolution_mastery", "解决精通", UpgradeCategory.CHORD_MASTERY,
        "D→T解决和弦的不和谐值消减效果+10",
        max_level=3, effect_per_level={"resolution_reduction_bonus": 10}, rarity=2))

    # ---- 生存强化 ----
    pool.append(Upgrade(
        "hp_boost", "生命强化", UpgradeCategory.SURVIVAL,
        "最大生命值+25",
        max_level=8, effect_per_level={"max_hp_bonus": 25}, rarity=1))
    pool.append(Upgrade(
        "hp_regen", "生命恢复", UpgradeCategory.SURVIVAL,
        "每秒生命恢复+0.5",
        max_level=5, effect_per_level={"hp_regen_bonus": 0.5}, rarity=1))
    pool.append(Upgrade(
        "dodge_chance", "闪避本能", UpgradeCategory.SURVIVAL,
        "基础闪避率+3%",
        max_level=5, effect_per_level={"dodge_chance": 0.03}, rarity=2))

    return pool


# =============================================================================
# 第四部分：玩家Build状态
# =============================================================================

@dataclass
class PlayerBuild:
    """
    表示一个玩家的完整Build状态，包含所有升级和数值修正。
    这是跑分系统的核心输入。
    """
    # 音符属性
    notes: dict[str, NoteStats] = field(default_factory=create_base_notes)
    # 全局修正
    global_dmg_bonus: float = 0.0
    chord_dmg_bonus: float = 0.0
    chord_dissonance_mult: float = 1.0  # 和弦不和谐度乘数
    progression_bonus: float = 0.0      # 和弦进行额外倍率
    # 疲劳耐受
    monotony_rate_mult: float = 1.0     # 单调值累积速率乘数
    density_rate_mult: float = 1.0      # 密度值累积速率乘数
    dissonance_rate_mult: float = 1.0   # 不和谐值累积速率乘数
    monotony_decay_rate: float = 5.0    # 单调值自然衰减/秒
    density_decay_rate: float = 3.0     # 密度值自然衰减/秒
    dissonance_decay_rate: float = 2.0  # 不和谐值自然衰减/秒
    afi_amplify_reduction: float = 0.0  # AFI放大系数减免
    # 节奏
    bpm: int = 120
    rest_density_reduction: float = 25.0  # 休止符密度消减
    rest_charge_bonus: float = 0.0        # 休止符蓄力加成
    # 生存
    max_hp: float = 200.0
    hp_regen: float = 1.0
    dodge_chance: float = 0.0
    # 和弦解锁
    extended_chord_enabled: bool = False
    # D→T解决消减
    resolution_reduction: float = 30.0

    @property
    def beat_interval(self) -> float:
        return 60.0 / self.bpm

    def get_note_damage(self, note_name: str) -> float:
        """获取音符的实际伤害（含全局加成）。"""
        note = self.notes[note_name]
        return (note.total_dmg + self.global_dmg_bonus) * DMG_PER_POINT

    def apply_upgrade(self, upgrade: Upgrade, level: int = 1,
                      target_note: Optional[str] = None):
        """应用一个升级到Build上。"""
        for key, val in upgrade.effect_per_level.items():
            total = val * level
            if key == "dmg" and target_note:
                self.notes[target_note].bonus_dmg += total
            elif key == "spd" and target_note:
                self.notes[target_note].bonus_spd += total
            elif key == "dur" and target_note:
                self.notes[target_note].bonus_dur += total
            elif key == "size" and target_note:
                self.notes[target_note].bonus_size += total
            elif key == "global_dmg":
                self.global_dmg_bonus += total
            elif key == "monotony_rate_mult":
                self.monotony_rate_mult = max(0.2, self.monotony_rate_mult + total)
            elif key == "density_rate_mult":
                self.density_rate_mult = max(0.2, self.density_rate_mult + total)
            elif key == "dissonance_rate_mult":
                self.dissonance_rate_mult = max(0.2, self.dissonance_rate_mult + total)
            elif key == "monotony_decay_bonus":
                self.monotony_decay_rate += total
            elif key == "density_decay_bonus":
                self.density_decay_rate += total
            elif key == "dissonance_decay_bonus":
                self.dissonance_decay_rate += total
            elif key == "afi_amplify_reduction":
                self.afi_amplify_reduction += total
            elif key == "bpm_bonus":
                self.bpm += int(total)
            elif key == "rest_density_reduction_bonus":
                self.rest_density_reduction += total
            elif key == "rest_charge_bonus":
                self.rest_charge_bonus += total
            elif key == "chord_dmg_bonus":
                self.chord_dmg_bonus += total
            elif key == "chord_dissonance_mult":
                self.chord_dissonance_mult = max(0.2, self.chord_dissonance_mult + total)
            elif key == "extended_chord_enabled":
                self.extended_chord_enabled = True
            elif key == "progression_bonus":
                self.progression_bonus += total
            elif key == "resolution_reduction_bonus":
                self.resolution_reduction += total
            elif key == "max_hp_bonus":
                self.max_hp += total
            elif key == "hp_regen_bonus":
                self.hp_regen += total
            elif key == "dodge_chance":
                self.dodge_chance = min(0.5, self.dodge_chance + total)


# =============================================================================
# 第五部分：策略模拟器
# =============================================================================

@dataclass
class StrategyAction:
    """策略中的单个动作。"""
    beat: int               # 第几拍（0-based）
    note: str               # 音符名称
    is_chord: bool = False
    chord_type: str = ""    # 和弦类型名称
    is_rest: bool = False   # 是否为休止符
    modifier: str = ""      # 黑键修饰符


@dataclass
class StrategyDefinition:
    """
    一个完整策略的定义。
    策略以8小节（32拍）为一个循环单位。
    """
    name: str
    description: str
    actions: list[StrategyAction]
    # 策略中使用的节奏型
    rhythm_pattern: str = "standard"


@dataclass
class SimulationResult:
    """策略模拟的完整结果。"""
    strategy_name: str
    # DPS维度
    raw_dps: float = 0.0            # 原始DPS（无惩罚）
    effective_dps: float = 0.0      # 有效DPS（含疲劳衰减）
    burst_dps: float = 0.0          # 峰值DPS
    sustained_dps: float = 0.0      # 持续DPS（8小节平均）
    # 生存维度
    total_healing: float = 0.0      # 总治疗量
    total_shielding: float = 0.0    # 总护盾量
    dodge_value: float = 0.0        # 闪避贡献
    survival_score: float = 0.0     # 生存综合评分
    # 风险维度
    dissonance_damage: float = 0.0  # 不和谐扣血总量
    lockout_beats: int = 0          # 被锁定的拍数
    density_penalty_beats: int = 0  # 密度过载的拍数
    risk_score: float = 0.0         # 风险综合评分
    # 疲劳状态
    peak_monotony: float = 0.0
    peak_density: float = 0.0
    peak_dissonance: float = 0.0
    avg_afi: float = 0.0
    # 综合
    composite_score: float = 0.0
    # 详细日志
    beat_log: list[dict] = field(default_factory=list)


class StrategySimulator:
    """
    策略模拟器：在给定Build下模拟一个策略的8小节执行过程，
    逐拍计算DPS、疲劳累积、惩罚效果。
    """

    # 单音寂静系统参数
    MONOTONY_PER_REPEAT = 15.0
    DENSITY_PER_CAST = 8.0
    MONOTONY_SWITCH_REDUCTION = 20.0
    DISSONANCE_HARMONY_REDUCTION = 15.0

    # 疲劳等级阈值
    MONOTONY_WARN = 40
    MONOTONY_SILENCE = 70
    MONOTONY_LOCK = 90
    DENSITY_MILD = 50
    DENSITY_OVERLOAD = 75
    DENSITY_CRASH = 95
    DISSONANCE_PAIN = 30
    DISSONANCE_CORRODE = 60
    DISSONANCE_DANGER = 85

    # AFI放大系数
    AFI_AMPLIFIERS = {0: 1.0, 1: 1.1, 2: 1.3, 3: 1.6, 4: 2.0}

    # 修饰符伤害倍率
    MODIFIER_MULTIPLIERS = {
        "C#": 2.31, "D#": 1.0, "F#": 2.2, "G#": 2.2, "A#": 1.75
    }

    def __init__(self, build: PlayerBuild, chord_registry: dict[str, ChordType]):
        self.build = build
        self.chords = chord_registry
        # 综合得分权重
        self.w_dps = 0.50
        self.w_survival = 0.25
        self.w_risk = 0.25

    def simulate(self, strategy: StrategyDefinition) -> SimulationResult:
        """模拟一个策略的完整执行。"""
        result = SimulationResult(strategy_name=strategy.name)
        build = self.build

        # 状态变量
        monotony_per_note: dict[str, float] = {}
        density = 0.0
        dissonance = 0.0
        last_note = ""
        total_damage = 0.0
        total_raw_damage = 0.0
        total_beats = len(strategy.actions)
        rest_count_in_measure = 0
        cast_count_in_measure = 0
        unique_notes_used = set()

        # 简化的AFI估算
        afi_level = 0

        for i, action in enumerate(strategy.actions):
            beat_time = i * build.beat_interval
            measure_idx = i // 4
            beat_in_measure = i % 4

            # 每小节开始时重置小节内计数
            if beat_in_measure == 0:
                rest_count_in_measure = 0
                cast_count_in_measure = 0

            beat_info = {
                "beat": i, "time": round(beat_time, 2),
                "action": "", "raw_dmg": 0, "eff_dmg": 0,
                "monotony": 0, "density": round(density, 1),
                "dissonance": round(dissonance, 1),
            }

            if action.is_rest:
                # 休止符处理
                rest_count_in_measure += 1
                density = max(0, density - build.rest_density_reduction)
                beat_info["action"] = "REST"
                beat_info["density"] = round(density, 1)
                result.beat_log.append(beat_info)
                continue

            # ---- 施法处理 ----
            cast_count_in_measure += 1
            note_name = action.note
            unique_notes_used.add(note_name)

            # 计算基础伤害
            base_dmg = build.get_note_damage(note_name)

            # 和弦倍率
            chord_mult = 1.0
            chord_dissonance_add = 0.0
            if action.is_chord and action.chord_type in self.chords:
                chord = self.chords[action.chord_type]
                # 检查扩展和弦是否解锁
                if chord.is_extended and not build.extended_chord_enabled:
                    chord_mult = 1.0  # 未解锁则无效
                else:
                    chord_mult = chord.dmg_multiplier + build.chord_dmg_bonus
                    chord_dissonance_add = chord.fatigue_dissonance * build.chord_dissonance_mult

                    # 治疗/护盾
                    if chord.heal_ratio > 0:
                        heal = (build.notes[note_name].total_dmg + build.global_dmg_bonus) * chord.heal_ratio
                        result.total_healing += heal
                    if chord.shield_ratio > 0:
                        shield = (build.notes[note_name].total_dmg + build.global_dmg_bonus) * chord.shield_ratio
                        result.total_shielding += shield

                    # DOT额外伤害
                    if chord.dot_total_ratio > 0:
                        chord_mult = chord.dot_total_ratio

                    # 区域/召唤的持续伤害
                    if chord.zone_tick_ratio > 0:
                        ticks = chord.zone_duration_mult * build.notes[note_name].total_dur / 0.5
                        chord_mult = chord.zone_tick_ratio * ticks

                    # 召唤物持续伤害
                    if chord.summon_dps_ratio > 0 and chord.zone_tick_ratio == 0:
                        summon_dur = chord.summon_duration_mult * build.notes[note_name].total_dur * DUR_PER_POINT
                        chord_mult = chord.summon_dps_ratio * summon_dur

            # 修饰符倍率
            mod_mult = 1.0
            if action.modifier and action.modifier in self.MODIFIER_MULTIPLIERS:
                mod_mult = self.MODIFIER_MULTIPLIERS[action.modifier]

            # 休止符蓄力加成
            rest_bonus = rest_count_in_measure * (0.5 + build.rest_charge_bonus)
            rest_dmg_add = rest_bonus * DMG_PER_POINT

            raw_dmg = (base_dmg + rest_dmg_add) * chord_mult * mod_mult
            total_raw_damage += raw_dmg

            # ---- 疲劳惩罚计算 ----
            # 1. 单调值
            note_mono = monotony_per_note.get(note_name, 0.0)
            afi_amp = max(1.0, self.AFI_AMPLIFIERS.get(afi_level, 1.0) - build.afi_amplify_reduction)

            if note_name == last_note:
                note_mono += self.MONOTONY_PER_REPEAT * build.monotony_rate_mult * afi_amp
            else:
                # 切换音符降低单调值
                if last_note:
                    old_mono = monotony_per_note.get(last_note, 0)
                    monotony_per_note[last_note] = max(0, old_mono - self.MONOTONY_SWITCH_REDUCTION)
            note_mono = max(0, note_mono - build.monotony_decay_rate * build.beat_interval)
            note_mono = min(100, note_mono)
            monotony_per_note[note_name] = note_mono

            # 单调值惩罚
            mono_dmg_mult = 1.0
            if note_mono >= self.MONOTONY_LOCK:
                mono_dmg_mult = 0.0
                result.lockout_beats += 1
            elif note_mono >= self.MONOTONY_SILENCE:
                mono_dmg_mult = 0.5
            elif note_mono >= self.MONOTONY_WARN:
                mono_dmg_mult = 0.85

            # 2. 密度值
            density += self.DENSITY_PER_CAST * build.density_rate_mult * afi_amp
            density = max(0, density - build.density_decay_rate * build.beat_interval)
            density = min(100, density)

            density_dmg_mult = 1.0
            if density >= self.DENSITY_CRASH:
                density_dmg_mult = 0.6
                result.density_penalty_beats += 1
            elif density >= self.DENSITY_OVERLOAD:
                density_dmg_mult = 0.7
                result.density_penalty_beats += 1
            elif density >= self.DENSITY_MILD:
                density_dmg_mult = 0.9

            # 3. 不和谐值
            if chord_dissonance_add > 0:
                dissonance += chord_dissonance_add * 100 * build.dissonance_rate_mult * afi_amp
                # 不和谐降低单调值
                for n in monotony_per_note:
                    monotony_per_note[n] = max(0, monotony_per_note[n] - 10)
            else:
                # 和谐法术降低不和谐
                dissonance = max(0, dissonance - self.DISSONANCE_HARMONY_REDUCTION)
            dissonance = max(0, dissonance - build.dissonance_decay_rate * build.beat_interval)
            dissonance = min(100, dissonance)

            # 不和谐扣血
            dissonance_hp_loss = 0.0
            density_amplifier = 1.5 if density >= self.DENSITY_OVERLOAD else 1.0
            if dissonance >= self.DISSONANCE_DANGER:
                dissonance_hp_loss = 6.0 * build.beat_interval * density_amplifier
            elif dissonance >= self.DISSONANCE_CORRODE:
                dissonance_hp_loss = 3.0 * build.beat_interval * density_amplifier
            elif dissonance >= self.DISSONANCE_PAIN:
                dissonance_hp_loss = 1.0 * build.beat_interval * density_amplifier
            result.dissonance_damage += dissonance_hp_loss

            # 有效伤害
            eff_dmg = raw_dmg * mono_dmg_mult * density_dmg_mult
            total_damage += eff_dmg

            # 更新峰值
            result.peak_monotony = max(result.peak_monotony, note_mono)
            result.peak_density = max(result.peak_density, density)
            result.peak_dissonance = max(result.peak_dissonance, dissonance)

            last_note = note_name

            beat_info["action"] = f"{note_name}" + (f"[{action.chord_type}]" if action.is_chord else "") + (f"+{action.modifier}" if action.modifier else "")
            beat_info["raw_dmg"] = round(raw_dmg, 1)
            beat_info["eff_dmg"] = round(eff_dmg, 1)
            beat_info["monotony"] = round(note_mono, 1)
            beat_info["density"] = round(density, 1)
            beat_info["dissonance"] = round(dissonance, 1)
            result.beat_log.append(beat_info)

            # 简化AFI估算（基于多样性）
            diversity_ratio = len(unique_notes_used) / 7.0
            afi_level = max(0, int(4 * (1 - diversity_ratio)))

        # ---- 计算综合结果 ----
        total_time = total_beats * build.beat_interval
        result.raw_dps = total_raw_damage / total_time if total_time > 0 else 0
        result.effective_dps = total_damage / total_time if total_time > 0 else 0
        result.sustained_dps = result.effective_dps
        result.burst_dps = max((b["eff_dmg"] for b in result.beat_log if b.get("eff_dmg", 0) > 0), default=0) / build.beat_interval

        # 生存评分 (归一化到0-100)
        heal_score = min(100, (result.total_healing / build.max_hp) * 50)
        shield_score = min(100, (result.total_shielding / build.max_hp) * 50)
        dodge_score = build.dodge_chance * 200
        result.survival_score = min(100, heal_score + shield_score + dodge_score)

        # 风险评分 (归一化到0-100)
        hp_loss_ratio = result.dissonance_damage / build.max_hp
        lockout_ratio = result.lockout_beats / max(1, total_beats)
        density_ratio = result.density_penalty_beats / max(1, total_beats)
        result.risk_score = min(100, (hp_loss_ratio * 40 + lockout_ratio * 40 + density_ratio * 20) * 100)

        # DPS评分 (归一化到0-100, 基准DPS=100)
        dps_score = min(100, (result.effective_dps / 100.0) * 50)

        # 综合得分
        result.composite_score = (
            self.w_dps * dps_score
            + self.w_survival * result.survival_score
            - self.w_risk * result.risk_score
        )

        return result


# =============================================================================
# 第六部分：预定义策略库
# =============================================================================

def create_strategy_library() -> list[StrategyDefinition]:
    """创建预定义的策略库用于跑分对比。"""
    strategies = []

    # ---- 策略1: 纯C spam (最差策略基准) ----
    actions = [StrategyAction(i, "C") for i in range(32)]
    strategies.append(StrategyDefinition(
        "纯C音符Spam", "反复使用同一音符C，不做任何变化", actions))

    # ---- 策略2: 纯G spam (高伤但单调) ----
    actions = [StrategyAction(i, "G") for i in range(32)]
    strategies.append(StrategyDefinition(
        "纯G音符Spam", "反复使用高伤音符G", actions))

    # ---- 策略3: 双音符交替 (C-G) ----
    actions = [StrategyAction(i, "C" if i % 2 == 0 else "G") for i in range(32)]
    strategies.append(StrategyDefinition(
        "C-G双音符交替", "两个音符交替使用", actions))

    # ---- 策略4: 四音符轮换 (C-E-G-A) ----
    notes4 = ["C", "E", "G", "A"]
    actions = [StrategyAction(i, notes4[i % 4]) for i in range(32)]
    strategies.append(StrategyDefinition(
        "四音符轮换(C-E-G-A)", "四个音符循环使用", actions))

    # ---- 策略5: 七音符全轮换 ----
    notes7 = ["C", "D", "E", "F", "G", "A", "B"]
    actions = [StrategyAction(i, notes7[i % 7]) for i in range(32)]
    strategies.append(StrategyDefinition(
        "七音符全轮换", "使用全部七个白键音符循环", actions))

    # ---- 策略6: 和弦为主 (大三和弦轮换) ----
    actions = []
    chord_roots = ["C", "D", "E", "F", "G", "A", "B"]
    for i in range(32):
        if i % 4 == 0:
            root = chord_roots[(i // 4) % 7]
            actions.append(StrategyAction(i, root, True, "大三和弦"))
        else:
            actions.append(StrategyAction(i, notes7[i % 7]))
    strategies.append(StrategyDefinition(
        "大三和弦轮换", "每小节首拍使用大三和弦，其余拍多样化音符", actions))

    # ---- 策略7: 高风险高回报 (减七和弦) ----
    actions = []
    for i in range(32):
        if i % 8 == 0:
            actions.append(StrategyAction(i, "G", True, "减七和弦"))
        elif i % 8 in [1, 2]:
            # 延迟拍（减七需要2拍延迟）
            actions.append(StrategyAction(i, "C", False, "", True))  # 休止
        elif i % 8 == 3:
            # 解决和弦
            actions.append(StrategyAction(i, "C", True, "大三和弦"))
        else:
            actions.append(StrategyAction(i, notes7[i % 7]))
    strategies.append(StrategyDefinition(
        "减七和弦+解决", "每8拍使用一次减七和弦后接解决和弦", actions))

    # ---- 策略8: 带休止符的节奏策略 ----
    actions = []
    for i in range(32):
        if i % 4 == 3:  # 每小节第4拍休止
            actions.append(StrategyAction(i, "", False, "", True))
        else:
            actions.append(StrategyAction(i, notes7[i % 7]))
    strategies.append(StrategyDefinition(
        "三拍+休止", "每小节3拍施法+1拍休止，管理密度", actions))

    # ---- 策略9: 修饰符策略 ----
    actions = []
    mods = ["C#", "F#", "G#", "A#", "D#"]
    for i in range(32):
        note = notes7[i % 7]
        mod = mods[i % 5] if i % 3 == 0 else ""
        actions.append(StrategyAction(i, note, modifier=mod))
    strategies.append(StrategyDefinition(
        "修饰符轮换", "多样化音符+频繁使用修饰符", actions))

    # ---- 策略10: 扩展和弦策略 (5音) ----
    actions = []
    for i in range(32):
        if i % 8 == 0:
            actions.append(StrategyAction(i, "C", True, "属九和弦"))
        elif i % 8 == 4:
            actions.append(StrategyAction(i, "G", True, "大九和弦"))
        elif i % 8 in [2, 6]:
            actions.append(StrategyAction(i, "", False, "", True))  # 休止
        else:
            actions.append(StrategyAction(i, notes7[i % 7]))
    strategies.append(StrategyDefinition(
        "扩展和弦(5音)", "使用5音扩展和弦+休止符管理", actions))

    # ---- 策略11: 终极和弦策略 (6音) ----
    actions = []
    for i in range(32):
        if i % 16 == 0:
            actions.append(StrategyAction(i, "G", True, "属十三和弦"))
        elif i % 16 in [1, 2, 3]:
            actions.append(StrategyAction(i, "", False, "", True))  # 休止恢复
        elif i % 16 == 4:
            actions.append(StrategyAction(i, "C", True, "大三和弦"))  # 解决
        else:
            actions.append(StrategyAction(i, notes7[i % 7]))
    strategies.append(StrategyDefinition(
        "终极和弦(6音)", "使用6音终极和弦+大量休止恢复", actions))

    # ---- 策略12: 混合最优策略 ----
    actions = []
    pattern = [
        ("C", False, "", False, ""),
        ("E", False, "", False, ""),
        ("G", False, "", False, "C#"),
        ("C", True, "大三和弦", False, ""),
        ("A", False, "", False, ""),
        ("D", False, "", False, "F#"),
        ("B", False, "", False, ""),
        ("", False, "", True, ""),   # 休止
        ("F", False, "", False, ""),
        ("G", True, "小三和弦", False, ""),
        ("E", False, "", False, "G#"),
        ("A", True, "大三和弦", False, ""),
        ("D", False, "", False, ""),
        ("C", False, "", False, ""),
        ("B", False, "", False, "A#"),
        ("", False, "", True, ""),   # 休止
    ]
    for i in range(32):
        p = pattern[i % len(pattern)]
        actions.append(StrategyAction(i, p[0], p[1], p[2], p[3], p[4]))
    strategies.append(StrategyDefinition(
        "混合最优策略", "多样化音符+和弦+修饰符+休止的综合策略", actions))

    return strategies


# =============================================================================
# 第七部分：跑分报告生成
# =============================================================================

def run_full_benchmark(build: PlayerBuild = None,
                       strategies: list[StrategyDefinition] = None,
                       chord_registry: dict[str, ChordType] = None,
                       ) -> list[SimulationResult]:
    """
    执行完整的跑分基准测试。

    Args:
        build: 玩家Build状态，默认为初始Build
        strategies: 策略列表，默认为预定义策略库
        chord_registry: 和弦注册表，默认为完整注册表

    Returns:
        按综合得分降序排列的结果列表
    """
    if build is None:
        build = PlayerBuild()
    if strategies is None:
        strategies = create_strategy_library()
    if chord_registry is None:
        chord_registry = create_chord_registry()

    simulator = StrategySimulator(build, chord_registry)
    results = []

    for strategy in strategies:
        result = simulator.simulate(strategy)
        results.append(result)

    # 按综合得分降序排列
    results.sort(key=lambda r: r.composite_score, reverse=True)
    return results


def print_benchmark_report(results: list[SimulationResult], title: str = "跑分报告"):
    """打印格式化的跑分报告。"""
    print(f"\n{'=' * 100}")
    print(f"  {title}")
    print(f"{'=' * 100}")
    print(f"  {'排名':^4} | {'策略名称':^20} | {'有效DPS':^8} | {'原始DPS':^8} | "
          f"{'生存分':^6} | {'风险分':^6} | {'综合得分':^8} | {'峰值单调':^8} | {'峰值密度':^8} | {'峰值不和谐':^10}")
    print(f"  {'-'*4}-+-{'-'*20}-+-{'-'*8}-+-{'-'*8}-+-"
          f"{'-'*6}-+-{'-'*6}-+-{'-'*8}-+-{'-'*8}-+-{'-'*8}-+-{'-'*10}")

    for rank, r in enumerate(results, 1):
        print(f"  {rank:^4} | {r.strategy_name:^20} | {r.effective_dps:^8.1f} | {r.raw_dps:^8.1f} | "
              f"{r.survival_score:^6.1f} | {r.risk_score:^6.1f} | {r.composite_score:^8.1f} | "
              f"{r.peak_monotony:^8.1f} | {r.peak_density:^8.1f} | {r.peak_dissonance:^10.1f}")

    print(f"{'=' * 100}\n")


# =============================================================================
# 第八部分：主执行入口
# =============================================================================

if __name__ == "__main__":
    import sys

    print()
    print("╔══════════════════════════════════════════════════════════════════════════╗")
    print("║     Project Harmony — 平衡性跑分系统 (Balance Scoring System)            ║")
    print("╚══════════════════════════════════════════════════════════════════════════╝")
    print()

    chord_registry = create_chord_registry()
    strategies = create_strategy_library()

    # ---- 场景A: 初始Build (无升级) ----
    print("=" * 100)
    print("  场景A：初始Build（无任何升级）")
    print("=" * 100)
    build_base = PlayerBuild()
    results_base = run_full_benchmark(build_base, strategies, chord_registry)
    print_benchmark_report(results_base, "初始Build跑分报告")

    # ---- 场景B: 中期Build (若干升级) ----
    print("=" * 100)
    print("  场景B：中期Build（约15次升级）")
    print("=" * 100)
    build_mid = PlayerBuild()
    upgrades = create_upgrade_pool()
    upgrade_map = {u.id: u for u in upgrades}
    # 模拟中期升级
    build_mid.apply_upgrade(upgrade_map["note_dmg"], 3, "G")      # G伤害+1.5
    build_mid.apply_upgrade(upgrade_map["note_dmg"], 2, "B")      # B伤害+1.0
    build_mid.apply_upgrade(upgrade_map["global_dmg"], 2)          # 全局伤害+0.6
    build_mid.apply_upgrade(upgrade_map["monotony_tolerance"], 2)  # 单调耐受-20%
    build_mid.apply_upgrade(upgrade_map["density_tolerance"], 1)   # 密度耐受-10%
    build_mid.apply_upgrade(upgrade_map["chord_dmg"], 2)           # 和弦威力+0.2
    build_mid.apply_upgrade(upgrade_map["bpm_boost"], 2)           # BPM+10
    build_mid.apply_upgrade(upgrade_map["hp_boost"], 3)            # 生命+75
    results_mid = run_full_benchmark(build_mid, strategies, chord_registry)
    print_benchmark_report(results_mid, "中期Build跑分报告")

    # ---- 场景C: 后期Build (大量升级+扩展和弦) ----
    print("=" * 100)
    print("  场景C：后期Build（约30次升级，含扩展和弦解锁）")
    print("=" * 100)
    build_late = PlayerBuild()
    build_late.apply_upgrade(upgrade_map["note_dmg"], 5, "G")
    build_late.apply_upgrade(upgrade_map["note_dmg"], 4, "B")
    build_late.apply_upgrade(upgrade_map["note_spd"], 3, "D")
    build_late.apply_upgrade(upgrade_map["note_size"], 3, "E")
    build_late.apply_upgrade(upgrade_map["global_dmg"], 4)
    build_late.apply_upgrade(upgrade_map["monotony_tolerance"], 4)
    build_late.apply_upgrade(upgrade_map["density_tolerance"], 3)
    build_late.apply_upgrade(upgrade_map["dissonance_tolerance"], 3)
    build_late.apply_upgrade(upgrade_map["monotony_decay"], 2)
    build_late.apply_upgrade(upgrade_map["chord_dmg"], 4)
    build_late.apply_upgrade(upgrade_map["chord_dissonance_resist"], 3)
    build_late.apply_upgrade(upgrade_map["extended_chord_unlock"], 1)
    build_late.apply_upgrade(upgrade_map["bpm_boost"], 4)
    build_late.apply_upgrade(upgrade_map["hp_boost"], 5)
    build_late.apply_upgrade(upgrade_map["hp_regen"], 3)
    build_late.apply_upgrade(upgrade_map["progression_power"], 2)
    build_late.apply_upgrade(upgrade_map["resolution_mastery"], 2)
    results_late = run_full_benchmark(build_late, strategies, chord_registry)
    print_benchmark_report(results_late, "后期Build跑分报告")

    # ---- 输出和弦扩展表 ----
    print("\n" + "=" * 100)
    print("  扩展和弦注册表")
    print("=" * 100)
    print(f"  {'和弦类型':^14} | {'音数':^4} | {'不和谐度':^8} | {'法术形态':^12} | {'伤害倍率':^8} | {'疲劳不和谐':^10} | {'扩展':^4} | {'特殊效果':^30}")
    print(f"  {'-'*14}-+-{'-'*4}-+-{'-'*8}-+-{'-'*12}-+-{'-'*8}-+-{'-'*10}-+-{'-'*4}-+-{'-'*30}")
    for name, c in chord_registry.items():
        ext = "是" if c.is_extended else "否"
        extra = c.extra_effect if c.extra_effect else "-"
        print(f"  {name:^14} | {c.note_count:^4} | {c.base_dissonance:^8.2f} | {c.spell_form:^12} | {c.dmg_multiplier:^8.1f}x | {c.fatigue_dissonance:^10.2f} | {ext:^4} | {extra:^30}")

    print("\n所有跑分场景执行完毕。")
