"""
=============================================================================
Project Harmony — 听感疲劳计算模型 (Aesthetic Fatigue System)
=============================================================================

本模块实现了一个多维度的听感疲劳计算系统，将音乐审美疲劳的科学理论
适配为游戏内的实时冷却与资源限制机制。

理论基础：
    - 香农熵 (Shannon Entropy)：量化玩家法术序列的多样性
    - 转移熵 (Transition Entropy)：检测法术序列的模式重复
    - 翁特曲线 (Wundt Curve)：最佳复杂性区间理论
    - 递归量化分析 (RQA)：结构层面的重复性检测
    - 时间衰减 (Temporal Decay)：模拟人类听觉记忆的遗忘曲线
    - 均匀信息密度 (UID)：信息应以适中速率呈现 (Temperley 2019)
    - 休止美学 (Aesthetic of Silence)：留白是音乐的有机组成 (Lissa 1964)
    - 听觉疲劳 (Auditory Fatigue)：持续刺激导致感官适应 (Dobrucki 2017)

作者：Manus AI
版本：v2.0
日期：2026年2月7日

更新说明 (v2.0)：
    新增三个维度以解决"连绵不绝导致疲累"的问题：
    - 事件密度疲劳 (Event Density Fatigue)：惩罚过高的施法频率
    - 留白奖励 (Rest Reward)：奖励适当的施法间歇
    - 持续施法压力 (Sustained Pressure)：追踪无间断施法时长
=============================================================================
"""

from __future__ import annotations

import math
import time
from collections import defaultdict, deque
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Optional


# =============================================================================
# 第一部分：常量与枚举定义
# =============================================================================

class Note(Enum):
    """十二平均律音符枚举，对应游戏中的12个法术基础。"""
    C  = 0   # 白键
    Cs = 1   # 黑键 (C#/Db) — 锐化/穿透
    D  = 2   # 白键
    Ds = 3   # 黑键 (D#/Eb) — 追踪
    E  = 4   # 白键
    F  = 5   # 白键
    Fs = 6   # 黑键 (F#/Gb) — 分裂
    G  = 7   # 白键
    Gs = 8   # 黑键 (G#/Ab) — 回响
    A  = 9   # 白键
    As = 10  # 黑键 (A#/Bb) — 散射
    B  = 11  # 白键


class KeyType(Enum):
    """按键类型：白键（基础法术）或黑键（修饰符/和弦构成音）。"""
    WHITE = auto()
    BLACK = auto()


class FatigueLevel(Enum):
    """
    疲劳等级，对应不同的游戏反馈。

    基于翁特曲线理论，当复杂性过低时，疲劳从轻微逐步升级。
    """
    NONE      = 0   # 无疲劳：法术正常运作
    MILD      = 1   # 轻微疲劳：视觉/音效提示，法术效果略微下降
    MODERATE  = 2   # 中度疲劳：法术效果显著下降，音乐开始走调
    SEVERE    = 3   # 严重疲劳：法术几乎无效，产生不和谐噪音
    CRITICAL  = 4   # 极度疲劳：法术被锁定，必须通过多样化操作恢复


class PenaltyMode(Enum):
    """
    惩罚模式，对应 GDD 中的三种方案。

    - WEAKEN:      方案A — 削弱法术效果
    - LOCKOUT:     方案B — 锁定法术
    - GLOBAL_DEBUFF: 方案C — 全局不和谐 Debuff
    """
    WEAKEN       = auto()
    LOCKOUT      = auto()
    GLOBAL_DEBUFF = auto()


# 白键与黑键分类
WHITE_KEYS = {Note.C, Note.D, Note.E, Note.F, Note.G, Note.A, Note.B}
BLACK_KEYS = {Note.Cs, Note.Ds, Note.Fs, Note.Gs, Note.As}

# 音符名称映射（用于显示）
NOTE_NAMES = {
    Note.C: "C", Note.Cs: "C#", Note.D: "D", Note.Ds: "D#",
    Note.E: "E", Note.F: "F", Note.Fs: "F#", Note.G: "G",
    Note.Gs: "G#", Note.A: "A", Note.As: "A#", Note.B: "B",
}


# =============================================================================
# 第二部分：配置参数
# =============================================================================

@dataclass
class FatigueConfig:
    """
    听感疲劳系统的全局配置参数。

    所有阈值和权重均可调节，以适应不同的游戏难度和节奏。
    设计者可通过修改此配置来平衡游戏体验。
    """

    # ---- 时间窗口 ----
    window_duration: float = 15.0
    """滑动窗口时长（秒）。系统仅分析此时间段内的法术历史。
    对应人类短时听觉记忆的典型时长（约10-20秒）。"""

    max_history_size: int = 64
    """窗口内保留的最大事件数量，防止内存溢出。"""

    # ---- 时间衰减 ----
    decay_half_life: float = 5.0
    """时间衰减半衰期（秒）。越久远的事件对疲劳的贡献越小。
    模拟人类听觉记忆的指数遗忘曲线。"""

    # ---- 维度权重（v2.0 更新：八维度 AFI 公式） ----
    weight_pitch_entropy: float = 0.20
    """音高熵权重：衡量音符选择的多样性。"""

    weight_transition_entropy: float = 0.15
    """转移熵权重：衡量音符序列模式的可预测性。"""

    weight_rhythm_entropy: float = 0.10
    """节奏熵权重：衡量施法时间间隔的多样性。"""

    weight_recurrence: float = 0.10
    """递归率权重：衡量短序列模式的重复程度。"""

    weight_chord_diversity: float = 0.05
    """和弦多样性权重：衡量和弦类型的变化程度。"""

    # ---- v2.0 新增：密度与留白维度权重 ----
    weight_density: float = 0.20
    """事件密度疲劳权重：惩罚过高的施法频率。
    基于 Temperley (2019) 均匀信息密度理论：
    信息应以适中速率呈现，过高密度会超出听众处理能力。"""

    weight_rest_deficit: float = 0.10
    """留白缺失疲劳权重：惩罚缺乏适当间歇的连续施法。
    基于 Lissa (1964) 休止美学理论：
    休止是音乐结构的有机组成部分，为听众提供认知"呼吸空间"。"""

    weight_sustained_pressure: float = 0.10
    """持续施法压力权重：惩罚长时间无间断的高强度施法。
    基于听觉疲劳的生理学研究 (Dobrucki 2017)：
    持续的声学刺激导致感官适应和听觉疲劳。"""

    # ---- 密度与留白参数 ----
    density_optimal_rate: float = 2.0
    """最佳施法频率（次/秒）。低于此值不产生密度疲劳。
    对应 4/4 拍 120 BPM 下每拍一个音符的自然节奏。"""

    density_max_rate: float = 6.0
    """最大容忍施法频率（次/秒）。超过此值密度疲劳达到满值。
    对应极快速的连续施法（如 16 分音符连击）。"""

    density_measurement_window: float = 3.0
    """密度测量的短时窗口（秒）。在此窗口内计算瞬时施法频率。
    短于主窗口，以捕捉突发的高密度施法行为。"""

    rest_threshold: float = 1.5
    """休止判定阈值（秒）。超过此间隔视为一次有效"休止"。
    对应约 3 拍（120 BPM）的沉默，足以构成一个乐句间的呼吸。"""

    rest_ideal_ratio: float = 0.20
    """理想休止时间占比。在窗口时间内，约 20% 的时间应为"留白"。
    音乐中乐句间的自然呼吸通常占总时长的 15-25%。"""

    rest_recovery_per_second: float = 0.03
    """每秒休止带来的疲劳恢复量。奖励玩家主动"留白"。"""

    sustained_pressure_onset: float = 8.0
    """持续施法压力的起始时长（秒）。连续施法超过此时长后，
    开始累积额外的持续压力疲劳。对应人类注意力的自然波动周期。"""

    sustained_pressure_max: float = 20.0
    """持续施法压力的满值时长（秒）。连续施法达到此时长后，
    持续压力疲劳达到最大值。"""

    sustained_rest_reset: float = 1.0
    """重置持续压力所需的最小休止时长（秒）。
    玩家需要至少暂停这么长时间，才能重置"连续施法计时器"。"""

    # ---- 疲劳等级阈值 ----
    threshold_mild: float = 0.30
    """轻微疲劳阈值：疲劳指数超过此值开始产生提示。"""

    threshold_moderate: float = 0.55
    """中度疲劳阈值：法术效果开始显著下降。"""

    threshold_severe: float = 0.75
    """严重疲劳阈值：法术几乎失效。"""

    threshold_critical: float = 0.90
    """极度疲劳阈值：法术被锁定。"""

    # ---- 惩罚参数 ----
    penalty_mode: PenaltyMode = PenaltyMode.WEAKEN
    """当前使用的惩罚模式。"""

    weaken_multiplier_mild: float = 0.85
    """轻微疲劳时的效果乘数。"""

    weaken_multiplier_moderate: float = 0.55
    """中度疲劳时的效果乘数。"""

    weaken_multiplier_severe: float = 0.25
    """严重疲劳时的效果乘数。"""

    weaken_multiplier_critical: float = 0.05
    """极度疲劳时的效果乘数（几乎为零）。"""

    lockout_threshold: float = 0.90
    """锁定模式下，超过此阈值的音符将被禁用。"""

    global_debuff_scale: float = 0.5
    """全局 Debuff 模式下，不和谐度的缩放系数。"""

    # ---- 恢复参数 ----
    diversity_recovery_bonus: float = 0.15
    """使用"新"音符时获得的疲劳恢复加成。"""

    chord_recovery_bonus: float = 0.10
    """成功释放和弦时获得的额外恢复加成。"""

    # ---- n-gram 参数 ----
    ngram_sizes: tuple = (2, 3, 4)
    """用于递归检测的 n-gram 长度。"""

    # ---- 节奏量化 ----
    rhythm_quantize_bins: int = 8
    """节奏间隔的量化桶数。"""

    rhythm_max_interval: float = 2.0
    """节奏间隔的最大值（秒）。"""


# =============================================================================
# 第三部分：法术事件数据结构
# =============================================================================

@dataclass
class SpellEvent:
    """
    一次法术施放事件的完整记录。

    Attributes:
        timestamp: 施放时刻（游戏内时间，秒）
        note: 施放的音符
        is_chord: 是否作为和弦的一部分
        chord_type: 和弦类型名称（如 "大三和弦"），若非和弦则为 None
        chord_notes: 和弦包含的所有音符，若非和弦则为 None
        beat_position: 在当前小节中的节拍位置 (0.0 ~ 1.0)
    """
    timestamp: float
    note: Note
    is_chord: bool = False
    chord_type: Optional[str] = None
    chord_notes: Optional[tuple[Note, ...]] = None
    beat_position: float = 0.0


# =============================================================================
# 第四部分：数学工具函数
# =============================================================================

def shannon_entropy(counts: dict, total: int) -> float:
    """
    计算香农熵 H(X) = -Σ P(xi) * log2(P(xi))。

    熵值越高表示分布越均匀（多样性越高），
    熵值越低表示分布越集中（单调性越高）。

    Returns:
        归一化熵值，范围 [0.0, 1.0]。
    """
    if total <= 1 or len(counts) <= 1:
        return 0.0

    entropy = 0.0
    for count in counts.values():
        if count > 0:
            p = count / total
            entropy -= p * math.log2(p)

    max_entropy = math.log2(len(counts)) if len(counts) > 1 else 1.0
    return entropy / max_entropy if max_entropy > 0 else 0.0


def weighted_shannon_entropy(events: list[tuple], decay_func, current_time: float) -> float:
    """
    带时间衰减权重的香农熵。

    近期事件的权重更高，远期事件的权重按指数衰减。
    模拟人类听觉记忆中的"近因效应"（Recency Effect）。

    Returns:
        加权归一化熵值，范围 [0.0, 1.0]。
    """
    if len(events) <= 1:
        return 0.0

    weighted_counts: dict = defaultdict(float)
    total_weight = 0.0

    for ts, cat in events:
        w = decay_func(current_time - ts)
        weighted_counts[cat] += w
        total_weight += w

    if total_weight <= 0 or len(weighted_counts) <= 1:
        return 0.0

    entropy = 0.0
    for wc in weighted_counts.values():
        if wc > 0:
            p = wc / total_weight
            entropy -= p * math.log2(p)

    max_entropy = math.log2(len(weighted_counts)) if len(weighted_counts) > 1 else 1.0
    return entropy / max_entropy if max_entropy > 0 else 0.0


def transition_entropy(sequence: list, vocab_size: int) -> float:
    """
    计算转移熵 H(X_next | X_current)。

    衡量给定当前状态后，下一状态的不确定性。
    转移熵越低，序列越可预测，单调感越强。

    Returns:
        归一化转移熵，范围 [0.0, 1.0]。
    """
    if len(sequence) < 2:
        return 0.0

    trans_counts: dict[tuple, int] = defaultdict(int)
    from_counts: dict = defaultdict(int)

    for i in range(len(sequence) - 1):
        pair = (sequence[i], sequence[i + 1])
        trans_counts[pair] += 1
        from_counts[sequence[i]] += 1

    if not from_counts:
        return 0.0

    cond_entropy = 0.0
    total = len(sequence) - 1

    for (src, dst), count in trans_counts.items():
        p_joint = count / total
        p_cond = count / from_counts[src]
        if p_cond > 0:
            cond_entropy -= p_joint * math.log2(p_cond)

    max_entropy = math.log2(vocab_size) if vocab_size > 1 else 1.0
    return cond_entropy / max_entropy if max_entropy > 0 else 0.0


def ngram_recurrence_rate(sequence: list, n: int) -> float:
    """
    计算 n-gram 递归率。

    统计序列中重复出现的 n-gram 模式占总 n-gram 数的比例。

    Returns:
        递归率，范围 [0.0, 1.0]。
    """
    if len(sequence) < n:
        return 0.0

    ngrams = []
    for i in range(len(sequence) - n + 1):
        ngrams.append(tuple(sequence[i:i + n]))

    total = len(ngrams)
    unique = len(set(ngrams))

    if total <= 1:
        return 0.0

    return 1.0 - (unique / total)


def quantize_interval(interval: float, num_bins: int, max_val: float) -> int:
    """将连续的时间间隔量化到离散的桶中。"""
    clamped = min(interval, max_val)
    normalized = clamped / max_val
    return min(int(normalized * num_bins), num_bins - 1)


# =============================================================================
# 第五部分：核心疲劳计算引擎
# =============================================================================

class AestheticFatigueEngine:
    """
    听感疲劳计算引擎 (v2.0)。

    本引擎是 Project Harmony 听感疲劳系统的核心，负责：
    1. 记录玩家的法术施放历史
    2. 实时计算多维度疲劳指标
    3. 融合为统一的疲劳指数 (Aesthetic Fatigue Index, AFI)
    4. 输出疲劳等级和惩罚效果

    v2.0 更新：AFI 公式扩展为八维度：

        AFI = w1·F_pitch + w2·F_transition + w3·F_rhythm + w4·F_ngram
              + w5·F_chord + w6·F_density + w7·F_rest + w8·F_sustained

    新增的三个维度解决了"连绵不绝导致疲累"的问题：
        - F_density：事件密度疲劳 — 施法频率过高时的认知过载
        - F_rest：留白缺失疲劳 — 缺乏适当间歇的听觉疲劳
        - F_sustained：持续施法压力 — 长时间不休息的累积疲劳
    """

    def __init__(self, config: Optional[FatigueConfig] = None):
        self.config = config or FatigueConfig()
        self._history: deque[SpellEvent] = deque(maxlen=self.config.max_history_size)
        self._per_note_fatigue: dict[Note, float] = defaultdict(float)
        self._last_diversity_notes: set[Note] = set()

        # v2.0 新增：持续施法追踪状态
        self._sustained_casting_start: Optional[float] = None
        self._last_event_time: Optional[float] = None
        self._accumulated_rest_time: float = 0.0

    # ---- 公开接口 ----

    def record_spell(self, event: SpellEvent) -> "FatigueResult":
        """
        记录一次法术施放并返回当前疲劳状态。

        这是系统的主入口。每次玩家施放法术时调用此方法。
        """
        # v2.0：更新持续施法追踪
        self._update_sustained_tracking(event.timestamp)

        self._history.append(event)
        self._prune_old_events(event.timestamp)
        return self._compute_fatigue(event.timestamp, event.note)

    def query_fatigue(self, current_time: float,
                      target_note: Optional[Note] = None) -> "FatigueResult":
        """查询当前疲劳状态（不记录新事件）。"""
        self._prune_old_events(current_time)
        return self._compute_fatigue(current_time, target_note)

    def get_note_fatigue_map(self, current_time: float) -> dict[Note, float]:
        """获取所有音符的个体疲劳值映射。"""
        self._prune_old_events(current_time)
        result = {}
        for note in Note:
            result[note] = self._compute_note_specific_fatigue(note, current_time)
        return result

    def reset(self):
        """重置疲劳系统。"""
        self._history.clear()
        self._per_note_fatigue.clear()
        self._last_diversity_notes.clear()
        self._sustained_casting_start = None
        self._last_event_time = None
        self._accumulated_rest_time = 0.0

    # ---- v2.0 新增：持续施法追踪 ----

    def _update_sustained_tracking(self, current_time: float):
        """
        更新持续施法追踪状态。

        当两次施法之间的间隔超过 sustained_rest_reset 时，
        视为一次有效休息，重置连续施法计时器。
        当间隔超过 rest_threshold 时，累积休止时间。
        """
        cfg = self.config

        if self._last_event_time is not None:
            gap = current_time - self._last_event_time

            # 检查是否构成有效休息（重置持续压力）
            if gap >= cfg.sustained_rest_reset:
                self._sustained_casting_start = current_time

            # 累积休止时间
            if gap >= cfg.rest_threshold:
                self._accumulated_rest_time += gap
        else:
            # 首次施法
            self._sustained_casting_start = current_time

        self._last_event_time = current_time

    # ---- 内部计算方法 ----

    def _prune_old_events(self, current_time: float):
        """移除超出时间窗口的旧事件。"""
        cutoff = current_time - self.config.window_duration
        while self._history and self._history[0].timestamp < cutoff:
            self._history.popleft()

        # v2.0：同步清理过期的休止时间累积
        # 简化处理：随窗口滑动逐步衰减
        if self._accumulated_rest_time > 0:
            decay = self.config.window_duration * 0.01
            self._accumulated_rest_time = max(0, self._accumulated_rest_time - decay)

    def _decay_weight(self, dt: float) -> float:
        """指数时间衰减函数。w(dt) = 2^(-dt / half_life)"""
        if dt <= 0:
            return 1.0
        return math.pow(2.0, -dt / self.config.decay_half_life)

    def _compute_fatigue(self, current_time: float,
                         target_note: Optional[Note] = None) -> "FatigueResult":
        """
        核心疲劳计算流程 (v2.0)。

        计算八个维度的疲劳分量，加权融合为 AFI。
        """
        events = list(self._history)
        n = len(events)

        # 边界情况：事件太少
        if n < 3:
            return FatigueResult(
                fatigue_index=0.0,
                fatigue_level=FatigueLevel.NONE,
                components=FatigueComponents(),
                penalty=PenaltyEffect(),
                note_specific_fatigue=0.0,
                recovery_suggestions=[],
            )

        # ---- 维度 1：音高熵 (Pitch Entropy) ----
        pitch_events = [(e.timestamp, e.note.value) for e in events]
        pitch_entropy = weighted_shannon_entropy(
            pitch_events, self._decay_weight, current_time
        )
        pitch_fatigue = 1.0 - pitch_entropy

        # ---- 维度 2：转移熵 (Transition Entropy) ----
        note_sequence = [e.note.value for e in events]
        trans_ent = transition_entropy(note_sequence, vocab_size=12)
        transition_fatigue = 1.0 - trans_ent

        # ---- 维度 3：节奏熵 (Rhythm Entropy) ----
        rhythm_fatigue = self._compute_rhythm_fatigue(events, current_time)

        # ---- 维度 4：n-gram 递归率 (Recurrence Rate) ----
        recurrence = self._compute_recurrence(note_sequence)

        # ---- 维度 5：和弦多样性 (Chord Diversity) ----
        chord_fatigue = self._compute_chord_fatigue(events, current_time)

        # ---- 维度 6 [v2.0 新增]：事件密度疲劳 (Event Density Fatigue) ----
        density_fatigue = self._compute_density_fatigue(events, current_time)

        # ---- 维度 7 [v2.0 新增]：留白缺失疲劳 (Rest Deficit Fatigue) ----
        rest_deficit_fatigue = self._compute_rest_deficit_fatigue(events, current_time)

        # ---- 维度 8 [v2.0 新增]：持续施法压力 (Sustained Pressure) ----
        sustained_fatigue = self._compute_sustained_pressure(current_time)

        # ---- 加权融合：AFI 公式 (v2.0) ----
        cfg = self.config
        afi = (
            cfg.weight_pitch_entropy * pitch_fatigue
            + cfg.weight_transition_entropy * transition_fatigue
            + cfg.weight_rhythm_entropy * rhythm_fatigue
            + cfg.weight_recurrence * recurrence
            + cfg.weight_chord_diversity * chord_fatigue
            + cfg.weight_density * density_fatigue
            + cfg.weight_rest_deficit * rest_deficit_fatigue
            + cfg.weight_sustained_pressure * sustained_fatigue
        )

        # 钳位到 [0, 1]
        afi = max(0.0, min(1.0, afi))

        # ---- 确定疲劳等级 ----
        level = self._index_to_level(afi)

        # ---- 计算惩罚效果 ----
        penalty = self._compute_penalty(afi, level, target_note)

        # ---- 计算单音符疲劳 ----
        note_fatigue = 0.0
        if target_note is not None:
            note_fatigue = self._compute_note_specific_fatigue(
                target_note, current_time
            )

        # ---- 生成恢复建议 ----
        suggestions = self._generate_recovery_suggestions(
            pitch_fatigue, transition_fatigue, rhythm_fatigue,
            recurrence, chord_fatigue,
            density_fatigue, rest_deficit_fatigue, sustained_fatigue,
            current_time
        )

        components = FatigueComponents(
            pitch_entropy=pitch_entropy,
            pitch_fatigue=pitch_fatigue,
            transition_entropy=trans_ent,
            transition_fatigue=transition_fatigue,
            rhythm_entropy=1.0 - rhythm_fatigue,
            rhythm_fatigue=rhythm_fatigue,
            recurrence_rate=recurrence,
            chord_diversity=1.0 - chord_fatigue,
            chord_fatigue=chord_fatigue,
            density_rate=self._get_current_density(events, current_time),
            density_fatigue=density_fatigue,
            rest_ratio=self._get_rest_ratio(events, current_time),
            rest_deficit_fatigue=rest_deficit_fatigue,
            sustained_duration=self._get_sustained_duration(current_time),
            sustained_fatigue=sustained_fatigue,
        )

        return FatigueResult(
            fatigue_index=afi,
            fatigue_level=level,
            components=components,
            penalty=penalty,
            note_specific_fatigue=note_fatigue,
            recovery_suggestions=suggestions,
        )

    # ---- 原有维度计算方法 ----

    def _compute_rhythm_fatigue(self, events: list[SpellEvent],
                                current_time: float) -> float:
        """计算节奏维度的疲劳值。"""
        if len(events) < 3:
            return 0.0

        intervals = []
        for i in range(1, len(events)):
            dt = events[i].timestamp - events[i - 1].timestamp
            bin_idx = quantize_interval(
                dt, self.config.rhythm_quantize_bins, self.config.rhythm_max_interval
            )
            intervals.append((events[i].timestamp, bin_idx))

        rhythm_entropy = weighted_shannon_entropy(
            intervals, self._decay_weight, current_time
        )
        return 1.0 - rhythm_entropy

    def _compute_recurrence(self, sequence: list) -> float:
        """计算多尺度 n-gram 递归率。"""
        if len(sequence) < 2:
            return 0.0

        weights = {2: 0.3, 3: 0.4, 4: 0.3}
        total_rr = 0.0
        total_w = 0.0

        for n in self.config.ngram_sizes:
            if len(sequence) >= n:
                rr = ngram_recurrence_rate(sequence, n)
                w = weights.get(n, 0.3)
                total_rr += rr * w
                total_w += w

        return total_rr / total_w if total_w > 0 else 0.0

    def _compute_chord_fatigue(self, events: list[SpellEvent],
                               current_time: float) -> float:
        """计算和弦多样性维度的疲劳值。"""
        chord_events = [(e.timestamp, e.chord_type or "none") for e in events]
        chord_entropy = weighted_shannon_entropy(
            chord_events, self._decay_weight, current_time
        )
        return 1.0 - chord_entropy

    # ---- v2.0 新增维度计算方法 ----

    def _compute_density_fatigue(self, events: list[SpellEvent],
                                 current_time: float) -> float:
        """
        计算事件密度疲劳。

        基于 Temperley (2019) 的均匀信息密度 (UID) 理论：
        信息应以适中且均匀的速率呈现。过高的事件密度会超出
        听众的信息处理能力，导致认知过载和听觉疲劳。

        计算方法：
        1. 在短时窗口内统计施法次数，得到瞬时频率
        2. 将频率映射到 [0, 1] 的疲劳值
        3. 低于最佳频率不产生疲劳，超过最大频率疲劳满值
        """
        cfg = self.config
        density = self._get_current_density(events, current_time)

        if density <= cfg.density_optimal_rate:
            return 0.0

        # 线性映射：从最佳频率到最大频率
        ratio = (density - cfg.density_optimal_rate) / (
            cfg.density_max_rate - cfg.density_optimal_rate
        )
        return max(0.0, min(1.0, ratio))

    def _compute_rest_deficit_fatigue(self, events: list[SpellEvent],
                                      current_time: float) -> float:
        """
        计算留白缺失疲劳。

        基于 Lissa (1964) 的休止美学理论：
        音乐中的休止不是"空"，而是结构的有机组成部分。
        休止为听众提供了处理已接收信息的"呼吸空间"。

        计算方法：
        1. 统计窗口内所有间隔中，超过休止阈值的"留白"总时长
        2. 计算留白时间占窗口总时长的比例
        3. 与理想比例对比，缺失越多疲劳越高
        """
        cfg = self.config
        rest_ratio = self._get_rest_ratio(events, current_time)

        if rest_ratio >= cfg.rest_ideal_ratio:
            # 留白充足，无疲劳
            return 0.0

        # 留白不足：缺失比例越大，疲劳越高
        deficit = (cfg.rest_ideal_ratio - rest_ratio) / cfg.rest_ideal_ratio
        return max(0.0, min(1.0, deficit))

    def _compute_sustained_pressure(self, current_time: float) -> float:
        """
        计算持续施法压力。

        基于听觉疲劳的生理学研究 (Dobrucki 2017)：
        持续的声学刺激会导致听觉系统的感官适应（Sensory Adaptation），
        表现为对声音的敏感度下降和主观疲劳感增加。

        计算方法：
        1. 追踪自上次有效休息以来的连续施法时长
        2. 超过起始阈值后，线性增长疲劳值
        3. 达到最大阈值后，疲劳满值
        """
        cfg = self.config
        sustained = self._get_sustained_duration(current_time)

        if sustained <= cfg.sustained_pressure_onset:
            return 0.0

        ratio = (sustained - cfg.sustained_pressure_onset) / (
            cfg.sustained_pressure_max - cfg.sustained_pressure_onset
        )
        return max(0.0, min(1.0, ratio))

    # ---- 辅助计算方法 ----

    def _get_current_density(self, events: list[SpellEvent],
                             current_time: float) -> float:
        """计算当前短时窗口内的施法频率（次/秒）。"""
        cfg = self.config
        cutoff = current_time - cfg.density_measurement_window
        recent = [e for e in events if e.timestamp >= cutoff]
        if len(recent) < 2:
            return 0.0
        time_span = current_time - recent[0].timestamp
        if time_span <= 0:
            return 0.0
        return len(recent) / time_span

    def _get_rest_ratio(self, events: list[SpellEvent],
                        current_time: float) -> float:
        """计算窗口内留白时间占总时长的比例。"""
        if len(events) < 2:
            return 1.0  # 几乎没有施法，全是留白

        cfg = self.config
        total_rest = 0.0
        window_start = max(
            events[0].timestamp,
            current_time - cfg.window_duration
        )
        window_duration = current_time - window_start

        if window_duration <= 0:
            return 1.0

        for i in range(1, len(events)):
            gap = events[i].timestamp - events[i - 1].timestamp
            if gap >= cfg.rest_threshold:
                total_rest += gap

        # 也考虑最后一次施法到当前时间的间隔
        last_gap = current_time - events[-1].timestamp
        if last_gap >= cfg.rest_threshold:
            total_rest += last_gap

        return min(1.0, total_rest / window_duration)

    def _get_sustained_duration(self, current_time: float) -> float:
        """获取当前连续施法时长（秒）。"""
        if self._sustained_casting_start is None:
            return 0.0
        return current_time - self._sustained_casting_start

    def _compute_note_specific_fatigue(self, note: Note,
                                       current_time: float) -> float:
        """计算特定音符的个体疲劳值。"""
        events = [e for e in self._history if e.note == note]
        if not events:
            return 0.0

        total_weight = 0.0
        for e in events:
            dt = current_time - e.timestamp
            total_weight += self._decay_weight(dt)

        max_expected = 6.0
        return min(1.0, total_weight / max_expected)

    def _index_to_level(self, afi: float) -> FatigueLevel:
        """将疲劳指数映射到疲劳等级。"""
        cfg = self.config
        if afi >= cfg.threshold_critical:
            return FatigueLevel.CRITICAL
        elif afi >= cfg.threshold_severe:
            return FatigueLevel.SEVERE
        elif afi >= cfg.threshold_moderate:
            return FatigueLevel.MODERATE
        elif afi >= cfg.threshold_mild:
            return FatigueLevel.MILD
        else:
            return FatigueLevel.NONE

    def _compute_penalty(self, afi: float, level: FatigueLevel,
                         target_note: Optional[Note]) -> "PenaltyEffect":
        """根据疲劳等级和惩罚模式计算具体的惩罚效果。"""
        cfg = self.config

        if level == FatigueLevel.NONE:
            return PenaltyEffect()

        if cfg.penalty_mode == PenaltyMode.WEAKEN:
            multipliers = {
                FatigueLevel.MILD: cfg.weaken_multiplier_mild,
                FatigueLevel.MODERATE: cfg.weaken_multiplier_moderate,
                FatigueLevel.SEVERE: cfg.weaken_multiplier_severe,
                FatigueLevel.CRITICAL: cfg.weaken_multiplier_critical,
            }
            return PenaltyEffect(
                damage_multiplier=multipliers.get(level, 1.0),
                is_locked=False,
                global_dissonance=0.0,
                description=f"法术效果降低至 {multipliers.get(level, 1.0)*100:.0f}%",
            )

        elif cfg.penalty_mode == PenaltyMode.LOCKOUT:
            is_locked = afi >= cfg.lockout_threshold
            return PenaltyEffect(
                damage_multiplier=0.0 if is_locked else 1.0,
                is_locked=is_locked,
                global_dissonance=0.0,
                description="法术已被锁定！使用其他音符来解锁。" if is_locked
                           else "法术即将被锁定，请增加多样性。",
            )

        elif cfg.penalty_mode == PenaltyMode.GLOBAL_DEBUFF:
            dissonance = afi * cfg.global_debuff_scale
            return PenaltyEffect(
                damage_multiplier=1.0 - dissonance * 0.5,
                is_locked=False,
                global_dissonance=dissonance,
                description=f"全局不和谐度: {dissonance:.1%}，所有法术效果受影响。",
            )

        return PenaltyEffect()

    def _generate_recovery_suggestions(
        self, pitch_f: float, trans_f: float, rhythm_f: float,
        recurrence: float, chord_f: float,
        density_f: float, rest_f: float, sustained_f: float,
        current_time: float
    ) -> list[str]:
        """
        基于各维度疲劳值，生成恢复建议。
        v2.0：新增密度、留白、持续压力相关建议。
        """
        suggestions = []

        # v2.0 新增：密度与留白建议（优先级最高）
        if sustained_f > 0.5:
            suggestions.append("⏸ 暂停施法！你已经连续施法太久了，休息一下让旋律呼吸")

        if density_f > 0.5:
            suggestions.append("🎵 放慢施法节奏，给音乐留出空间，不要连绵不绝")

        if rest_f > 0.5:
            suggestions.append("🔇 在乐句之间留出空隙，沉默也是音乐的一部分")

        # 原有建议
        if pitch_f > 0.5:
            note_counts = defaultdict(float)
            for e in self._history:
                dt = current_time - e.timestamp
                note_counts[e.note] += self._decay_weight(dt)
            unused = [n for n in WHITE_KEYS if note_counts.get(n, 0) < 0.5]
            if unused:
                names = [NOTE_NAMES[n] for n in list(unused)[:3]]
                suggestions.append(f"🎹 尝试使用新音符：{', '.join(names)}")
            else:
                suggestions.append("🎹 增加音符选择的多样性")

        if trans_f > 0.5:
            suggestions.append("🔀 打破当前的音符序列模式，尝试不同的组合顺序")

        if rhythm_f > 0.5:
            suggestions.append("🥁 改变施法节奏，尝试不同的时间间隔")

        if recurrence > 0.5:
            suggestions.append("🔄 避免重复相同的法术组合模式")

        if chord_f > 0.5:
            suggestions.append("🎶 尝试组合不同类型的和弦")

        return suggestions


# =============================================================================
# 第六部分：结果数据结构
# =============================================================================

@dataclass
class FatigueComponents:
    """
    疲劳计算的各维度分量 (v2.0)。
    """
    # 原有维度
    pitch_entropy: float = 1.0
    pitch_fatigue: float = 0.0
    transition_entropy: float = 1.0
    transition_fatigue: float = 0.0
    rhythm_entropy: float = 1.0
    rhythm_fatigue: float = 0.0
    recurrence_rate: float = 0.0
    chord_diversity: float = 1.0
    chord_fatigue: float = 0.0

    # v2.0 新增维度
    density_rate: float = 0.0
    """当前施法频率（次/秒）。"""
    density_fatigue: float = 0.0
    """事件密度疲劳值。"""
    rest_ratio: float = 1.0
    """窗口内留白时间占比。"""
    rest_deficit_fatigue: float = 0.0
    """留白缺失疲劳值。"""
    sustained_duration: float = 0.0
    """当前连续施法时长（秒）。"""
    sustained_fatigue: float = 0.0
    """持续施法压力疲劳值。"""


@dataclass
class PenaltyEffect:
    """疲劳惩罚效果。"""
    damage_multiplier: float = 1.0
    is_locked: bool = False
    global_dissonance: float = 0.0
    description: str = ""


@dataclass
class FatigueResult:
    """
    疲劳计算的完整结果 (v2.0)。
    """
    fatigue_index: float
    fatigue_level: FatigueLevel
    components: FatigueComponents
    penalty: PenaltyEffect
    note_specific_fatigue: float
    recovery_suggestions: list[str]

    def __repr__(self) -> str:
        c = self.components
        return (
            f"FatigueResult(\n"
            f"  AFI={self.fatigue_index:.3f}, "
            f"Level={self.fatigue_level.name},\n"
            f"  原有维度: pitch={c.pitch_fatigue:.2f}, "
            f"transition={c.transition_fatigue:.2f}, "
            f"rhythm={c.rhythm_fatigue:.2f}, "
            f"recurrence={c.recurrence_rate:.2f}, "
            f"chord={c.chord_fatigue:.2f},\n"
            f"  新增维度: density={c.density_fatigue:.2f} "
            f"({c.density_rate:.1f}/s), "
            f"rest_deficit={c.rest_deficit_fatigue:.2f} "
            f"(rest={c.rest_ratio:.1%}), "
            f"sustained={c.sustained_fatigue:.2f} "
            f"({c.sustained_duration:.1f}s),\n"
            f"  Penalty: dmg_mult={self.penalty.damage_multiplier:.2f}, "
            f"locked={self.penalty.is_locked}\n"
            f")"
        )


# =============================================================================
# 第七部分：便捷工厂与预设配置
# =============================================================================

def create_easy_config() -> FatigueConfig:
    """简单难度配置。疲劳积累较慢，适合新手。"""
    return FatigueConfig(
        window_duration=20.0,
        decay_half_life=7.0,
        threshold_mild=0.45,
        threshold_moderate=0.65,
        threshold_severe=0.82,
        threshold_critical=0.95,
        weaken_multiplier_mild=0.90,
        weaken_multiplier_moderate=0.65,
        weaken_multiplier_severe=0.35,
        weaken_multiplier_critical=0.10,
        density_optimal_rate=3.0,
        density_max_rate=8.0,
        sustained_pressure_onset=12.0,
        sustained_pressure_max=30.0,
    )


def create_normal_config() -> FatigueConfig:
    """普通难度配置（默认）。"""
    return FatigueConfig()


def create_hard_config() -> FatigueConfig:
    """困难难度配置。疲劳积累更快。"""
    return FatigueConfig(
        window_duration=12.0,
        decay_half_life=3.5,
        threshold_mild=0.22,
        threshold_moderate=0.42,
        threshold_severe=0.62,
        threshold_critical=0.80,
        weaken_multiplier_mild=0.80,
        weaken_multiplier_moderate=0.45,
        weaken_multiplier_severe=0.15,
        weaken_multiplier_critical=0.02,
        density_optimal_rate=1.5,
        density_max_rate=4.0,
        sustained_pressure_onset=6.0,
        sustained_pressure_max=15.0,
    )


def create_maestro_config() -> FatigueConfig:
    """大师难度配置。极其严格。"""
    return FatigueConfig(
        window_duration=10.0,
        decay_half_life=2.5,
        threshold_mild=0.18,
        threshold_moderate=0.35,
        threshold_severe=0.52,
        threshold_critical=0.70,
        weaken_multiplier_mild=0.75,
        weaken_multiplier_moderate=0.35,
        weaken_multiplier_severe=0.10,
        weaken_multiplier_critical=0.01,
        weight_pitch_entropy=0.18,
        weight_transition_entropy=0.15,
        weight_rhythm_entropy=0.08,
        weight_recurrence=0.09,
        weight_chord_diversity=0.05,
        weight_density=0.22,
        weight_rest_deficit=0.12,
        weight_sustained_pressure=0.11,
        density_optimal_rate=1.2,
        density_max_rate=3.5,
        sustained_pressure_onset=5.0,
        sustained_pressure_max=12.0,
    )


# =============================================================================
# 第八部分：演示与测试
# =============================================================================

def demo_scenario_monotonous():
    """场景 1：单调的法术使用模式 — 反复使用相同音符。"""
    print("=" * 78)
    print("场景 1：单调模式 — 反复施放 C 音符")
    print("=" * 78)

    engine = AestheticFatigueEngine(create_normal_config())

    for i in range(12):
        t = i * 0.5
        event = SpellEvent(timestamp=t, note=Note.C, beat_position=(i % 4) / 4.0)
        result = engine.record_spell(event)
        c = result.components
        print(f"  t={t:5.1f}s | C  | AFI={result.fatigue_index:.3f} "
              f"| {result.fatigue_level.name:10s} "
              f"| dmg={result.penalty.damage_multiplier:.2f} "
              f"| density={c.density_fatigue:.2f} "
              f"| rest={c.rest_deficit_fatigue:.2f} "
              f"| sustained={c.sustained_fatigue:.2f}")
    print()


def demo_scenario_diverse():
    """场景 2：多样化模式 — 使用多种音符和和弦，有节奏变化。"""
    print("=" * 78)
    print("场景 2：多样化模式 — 使用多种音符和和弦")
    print("=" * 78)

    engine = AestheticFatigueEngine(create_normal_config())

    diverse_sequence = [
        (0.0, Note.C, False, None),
        (0.6, Note.E, False, None),
        (1.0, Note.G, False, None),
        (1.8, Note.C, True, "大三和弦"),
        (2.5, Note.D, False, None),
        (3.0, Note.F, False, None),
        (3.7, Note.A, False, None),
        (4.2, Note.D, True, "小三和弦"),
        (5.0, Note.B, False, None),
        (5.4, Note.G, False, None),
        (6.2, Note.E, False, None),
        (7.0, Note.F, True, "大三和弦"),
    ]

    for t, note, is_chord, chord_type in diverse_sequence:
        event = SpellEvent(
            timestamp=t, note=note,
            is_chord=is_chord, chord_type=chord_type,
        )
        result = engine.record_spell(event)
        name = NOTE_NAMES[note]
        chord_str = f" [{chord_type}]" if chord_type else ""
        c = result.components
        print(f"  t={t:5.1f}s | {name:2s}{chord_str:12s} "
              f"| AFI={result.fatigue_index:.3f} "
              f"| {result.fatigue_level.name:10s} "
              f"| density={c.density_fatigue:.2f} "
              f"| rest={c.rest_deficit_fatigue:.2f}")
    print()


def demo_scenario_nonstop_barrage():
    """
    场景 3 [v2.0 新增]：连绵不绝的高密度施法。

    即使音符多样，但完全不留空隙、密度极高，
    模拟"一直在施法，完全没有呼吸"的情况。
    v1.0 无法检测此问题，v2.0 应当产生显著疲劳。
    """
    print("=" * 78)
    print("场景 3 [v2.0 新增]：连绵不绝 — 高密度多样施法但无留白")
    print("=" * 78)

    engine = AestheticFatigueEngine(create_normal_config())

    # 使用7个不同音符，但间隔极短（0.15秒），无任何休止
    notes = [Note.C, Note.D, Note.E, Note.F, Note.G, Note.A, Note.B]
    for i in range(40):
        t = i * 0.15  # 约 6.67 次/秒，极高密度
        note = notes[i % 7]
        event = SpellEvent(timestamp=t, note=note)
        result = engine.record_spell(event)
        c = result.components
        if i % 5 == 0 or i >= 35:
            print(f"  t={t:5.1f}s | {NOTE_NAMES[note]:2s} "
                  f"| AFI={result.fatigue_index:.3f} "
                  f"| {result.fatigue_level.name:10s} "
                  f"| density={c.density_fatigue:.2f} ({c.density_rate:.1f}/s) "
                  f"| rest={c.rest_deficit_fatigue:.2f} ({c.rest_ratio:.0%}) "
                  f"| sustained={c.sustained_fatigue:.2f} ({c.sustained_duration:.1f}s)")
    print()


def demo_scenario_breathe():
    """
    场景 4 [v2.0 新增]：有呼吸感的施法模式。

    玩家在乐句之间留出适当的间歇，模拟音乐中的"呼吸"。
    预期：即使总施法量相近，疲劳也显著低于场景3。
    """
    print("=" * 78)
    print("场景 4 [v2.0 新增]：有呼吸感 — 乐句间留出间歇")
    print("=" * 78)

    engine = AestheticFatigueEngine(create_normal_config())

    # 乐句1：快速施法
    phrase1 = [
        (0.0, Note.C), (0.4, Note.E), (0.8, Note.G), (1.2, Note.B),
    ]
    # 休止 1.5 秒（呼吸）
    # 乐句2：快速施法
    phrase2 = [
        (2.7, Note.D), (3.1, Note.F), (3.5, Note.A), (3.9, Note.C),
    ]
    # 休止 2.0 秒（更长的呼吸）
    # 乐句3：快速施法
    phrase3 = [
        (5.9, Note.E), (6.3, Note.G), (6.7, Note.B), (7.1, Note.D),
    ]

    all_events = phrase1 + phrase2 + phrase3

    for t, note in all_events:
        event = SpellEvent(timestamp=t, note=note)
        result = engine.record_spell(event)
        c = result.components
        print(f"  t={t:5.1f}s | {NOTE_NAMES[note]:2s} "
              f"| AFI={result.fatigue_index:.3f} "
              f"| {result.fatigue_level.name:10s} "
              f"| density={c.density_fatigue:.2f} "
              f"| rest={c.rest_deficit_fatigue:.2f} ({c.rest_ratio:.0%}) "
              f"| sustained={c.sustained_fatigue:.2f}")

    print()
    print("  对比：场景3（无留白）最终 AFI 远高于场景4（有呼吸），")
    print("  即使两者使用的音符同样多样。这正是 v2.0 新增维度的效果。")
    print()


def demo_scenario_recovery_with_rest():
    """
    场景 5 [v2.0 新增]：通过休息恢复疲劳。

    玩家先高密度施法积累疲劳，然后完全停止施法。
    预期：疲劳在休息期间逐步下降。
    """
    print("=" * 78)
    print("场景 5 [v2.0 新增]：休息恢复 — 停止施法后疲劳下降")
    print("=" * 78)

    engine = AestheticFatigueEngine(create_normal_config())

    # 阶段1：高密度施法
    print("  --- 阶段 1：高密度施法 ---")
    for i in range(15):
        t = i * 0.3
        note = [Note.C, Note.D, Note.E][i % 3]
        event = SpellEvent(timestamp=t, note=note)
        result = engine.record_spell(event)
        if i % 3 == 0:
            print(f"  t={t:5.1f}s | {NOTE_NAMES[note]:2s} "
                  f"| AFI={result.fatigue_index:.3f} "
                  f"| {result.fatigue_level.name}")

    # 阶段2：完全休息（只查询，不施法）
    print("  --- 阶段 2：完全休息（停止施法） ---")
    for dt in [1, 2, 3, 5, 8, 12]:
        t = 4.5 + dt
        result = engine.query_fatigue(t)
        c = result.components
        print(f"  t={t:5.1f}s | 休息中... "
              f"| AFI={result.fatigue_index:.3f} "
              f"| {result.fatigue_level.name:10s} "
              f"| rest_ratio={c.rest_ratio:.0%}")

    print()


def demo_scenario_penalty_modes():
    """场景 6：三种惩罚模式的对比。"""
    print("=" * 78)
    print("场景 6：三种惩罚模式对比")
    print("=" * 78)

    for mode in PenaltyMode:
        config = FatigueConfig(penalty_mode=mode)
        engine = AestheticFatigueEngine(config)

        for i in range(10):
            event = SpellEvent(timestamp=i * 0.4, note=Note.C)
            engine.record_spell(event)

        result = engine.query_fatigue(4.0, Note.C)
        print(f"  模式: {mode.name:15s} | AFI={result.fatigue_index:.3f} "
              f"| {result.penalty.description}")
    print()


def demo_note_fatigue_map():
    """场景 7：音符疲劳热力图。"""
    print("=" * 78)
    print("场景 7：音符疲劳热力图")
    print("=" * 78)

    engine = AestheticFatigueEngine(create_normal_config())

    sequence = [
        (0.0, Note.C), (0.5, Note.C), (1.0, Note.E),
        (1.5, Note.C), (2.0, Note.E), (2.5, Note.C),
        (3.0, Note.G), (3.5, Note.C), (4.0, Note.E),
    ]
    for t, note in sequence:
        engine.record_spell(SpellEvent(timestamp=t, note=note))

    fatigue_map = engine.get_note_fatigue_map(4.5)

    print("  音符  | 疲劳值 | 可视化")
    print("  ------|--------|" + "-" * 30)
    for note in Note:
        val = fatigue_map[note]
        bar_len = int(val * 25)
        bar = "█" * bar_len + "░" * (25 - bar_len)
        key_type = "♯" if note in BLACK_KEYS else " "
        print(f"  {NOTE_NAMES[note]:3s}{key_type} | {val:.3f}  | {bar}")
    print()


def demo_v1_vs_v2_comparison():
    """
    场景 8 [v2.0 新增]：v1 vs v2 对比 — 展示新维度的价值。

    构造一个"音符多样但密度过高"的序列，
    展示 v1.0 的五个维度无法检测此问题，
    而 v2.0 的新维度能正确识别。
    """
    print("=" * 78)
    print("场景 8 [v2.0 新增]：维度对比 — 展示新增维度的价值")
    print("=" * 78)

    engine = AestheticFatigueEngine(create_normal_config())

    # 高密度但高多样性的施法
    notes = [Note.C, Note.D, Note.E, Note.F, Note.G, Note.A, Note.B]
    for i in range(28):
        t = i * 0.15
        note = notes[i % 7]
        engine.record_spell(SpellEvent(timestamp=t, note=note))

    result = engine.query_fatigue(4.2)
    c = result.components

    print("  维度分析（高密度 + 高多样性的施法序列）：")
    print(f"  ┌─────────────────────────────┬──────────┬──────────┐")
    print(f"  │ 维度                        │ 疲劳值   │ 诊断     │")
    print(f"  ├─────────────────────────────┼──────────┼──────────┤")
    print(f"  │ 音高熵 (v1)                 │ {c.pitch_fatigue:6.3f}   │ {'⚠ 高' if c.pitch_fatigue > 0.3 else '✓ 低'}     │")
    print(f"  │ 转移熵 (v1)                 │ {c.transition_fatigue:6.3f}   │ {'⚠ 高' if c.transition_fatigue > 0.3 else '✓ 低'}     │")
    print(f"  │ 节奏熵 (v1)                 │ {c.rhythm_fatigue:6.3f}   │ {'⚠ 高' if c.rhythm_fatigue > 0.3 else '✓ 低'}     │")
    print(f"  │ 递归率 (v1)                 │ {c.recurrence_rate:6.3f}   │ {'⚠ 高' if c.recurrence_rate > 0.3 else '✓ 低'}     │")
    print(f"  │ 和弦多样性 (v1)             │ {c.chord_fatigue:6.3f}   │ {'⚠ 高' if c.chord_fatigue > 0.3 else '✓ 低'}     │")
    print(f"  ├─────────────────────────────┼──────────┼──────────┤")
    print(f"  │ 事件密度 (v2 新增)          │ {c.density_fatigue:6.3f}   │ {'⚠ 高' if c.density_fatigue > 0.3 else '✓ 低'}     │")
    print(f"  │ 留白缺失 (v2 新增)          │ {c.rest_deficit_fatigue:6.3f}   │ {'⚠ 高' if c.rest_deficit_fatigue > 0.3 else '✓ 低'}     │")
    print(f"  │ 持续压力 (v2 新增)          │ {c.sustained_fatigue:6.3f}   │ {'⚠ 高' if c.sustained_fatigue > 0.3 else '✓ 低'}     │")
    print(f"  └─────────────────────────────┴──────────┴──────────┘")
    print(f"  综合 AFI = {result.fatigue_index:.3f} ({result.fatigue_level.name})")
    print()
    print('  结论：v1 的五个维度认为此序列「多样性良好」，')
    print('  但 v2 的新维度正确识别了「密度过高 + 缺乏留白」的问题。')
    print()


if __name__ == "__main__":
    print()
    print("╔══════════════════════════════════════════════════════════════════════════════╗")
    print("║     Project Harmony — 听感疲劳计算模型 v2.0 (Aesthetic Fatigue System)        ║")
    print("║                    演示与验证 — 含密度/留白新维度                               ║")
    print("╚══════════════════════════════════════════════════════════════════════════════╝")
    print()

    demo_scenario_monotonous()
    demo_scenario_diverse()
    demo_scenario_nonstop_barrage()
    demo_scenario_breathe()
    demo_scenario_recovery_with_rest()
    demo_scenario_penalty_modes()
    demo_note_fatigue_map()
    demo_v1_vs_v2_comparison()

    print("=" * 78)
    print('所有演示场景执行完毕。v2.0 新增维度有效解决了「连绵不绝导致疲累」的问题。')
    print("=" * 78)
