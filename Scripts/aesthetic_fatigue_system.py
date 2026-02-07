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

作者：Manus AI
版本：v1.0
日期：2026年2月7日
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

    # ---- 维度权重（MMI 公式中的 w1, w2, w3 对应） ----
    weight_pitch_entropy: float = 0.30
    """音高熵权重 (w1)：衡量音符选择的多样性。
    对应文档中的 '1 - H_IDyOM' 项。"""

    weight_transition_entropy: float = 0.25
    """转移熵权重 (w2)：衡量音符序列模式的可预测性。
    对应文档中的 'RQA_Lam' 项。"""

    weight_rhythm_entropy: float = 0.20
    """节奏熵权重 (w3)：衡量施法时间间隔的多样性。
    对应文档中的隐空间体积项。"""

    weight_recurrence: float = 0.15
    """递归率权重：衡量短序列模式的重复程度。
    基于 RQA 递归率概念。"""

    weight_chord_diversity: float = 0.10
    """和弦多样性权重：衡量和弦类型的变化程度。
    鼓励玩家探索不同和弦形态。"""

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
    """使用"新"音符时获得的疲劳恢复加成。
    鼓励玩家主动打破单调。"""

    chord_recovery_bonus: float = 0.10
    """成功释放和弦时获得的额外恢复加成。"""

    # ---- n-gram 参数 ----
    ngram_sizes: tuple = (2, 3, 4)
    """用于递归检测的 n-gram 长度。
    2-gram 检测相邻音符对的重复，
    3-gram 和 4-gram 检测更长的模式循环。"""

    # ---- 节奏量化 ----
    rhythm_quantize_bins: int = 8
    """节奏间隔的量化桶数。将连续的时间间隔离散化为有限类别，
    以便计算节奏熵。对应一个小节内的8个可能节拍位置。"""

    rhythm_max_interval: float = 2.0
    """节奏间隔的最大值（秒）。超过此值的间隔被截断。"""


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

    基于文档第三章 3.1 节的定义。熵值越高表示分布越均匀（多样性越高），
    熵值越低表示分布越集中（单调性越高）。

    Args:
        counts: 各类别的出现次数字典
        total: 总事件数

    Returns:
        归一化熵值，范围 [0.0, 1.0]。
        0.0 表示完全确定（只有一种类别），
        1.0 表示完全均匀分布。
    """
    if total <= 1 or len(counts) <= 1:
        return 0.0

    entropy = 0.0
    for count in counts.values():
        if count > 0:
            p = count / total
            entropy -= p * math.log2(p)

    # 归一化：除以最大可能熵 log2(N)
    max_entropy = math.log2(len(counts)) if len(counts) > 1 else 1.0
    return entropy / max_entropy if max_entropy > 0 else 0.0


def weighted_shannon_entropy(events: list[tuple], decay_func, current_time: float) -> float:
    """
    带时间衰减权重的香农熵。

    近期事件的权重更高，远期事件的权重按指数衰减。
    这模拟了人类听觉记忆中"近因效应"（Recency Effect）。

    Args:
        events: [(timestamp, category), ...] 事件列表
        decay_func: 时间衰减函数 f(dt) -> weight
        current_time: 当前时间

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

    基于文档第三章 3.1.3 节的定义。衡量给定当前状态后，
    下一状态的不确定性。转移熵越低，序列越可预测，单调感越强。

    Args:
        sequence: 状态序列
        vocab_size: 状态空间大小

    Returns:
        归一化转移熵，范围 [0.0, 1.0]。
    """
    if len(sequence) < 2:
        return 0.0

    # 构建转移计数矩阵
    trans_counts: dict[tuple, int] = defaultdict(int)
    from_counts: dict = defaultdict(int)

    for i in range(len(sequence) - 1):
        pair = (sequence[i], sequence[i + 1])
        trans_counts[pair] += 1
        from_counts[sequence[i]] += 1

    if not from_counts:
        return 0.0

    # 计算条件熵 H(X_next | X_current)
    cond_entropy = 0.0
    total = len(sequence) - 1

    for (src, dst), count in trans_counts.items():
        p_joint = count / total
        p_cond = count / from_counts[src]
        if p_cond > 0:
            cond_entropy -= p_joint * math.log2(p_cond)

    # 归一化
    max_entropy = math.log2(vocab_size) if vocab_size > 1 else 1.0
    return cond_entropy / max_entropy if max_entropy > 0 else 0.0


def ngram_recurrence_rate(sequence: list, n: int) -> float:
    """
    计算 n-gram 递归率。

    基于文档第五章 RQA 递归率概念。统计序列中重复出现的
    n-gram 模式占总 n-gram 数的比例。递归率越高，重复越严重。

    Args:
        sequence: 状态序列
        n: n-gram 的长度

    Returns:
        递归率，范围 [0.0, 1.0]。
        0.0 表示所有 n-gram 都是唯一的，
        1.0 表示所有 n-gram 完全相同。
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

    # 递归率 = 1 - (唯一模式数 / 总模式数)
    return 1.0 - (unique / total)


def quantize_interval(interval: float, num_bins: int, max_val: float) -> int:
    """
    将连续的时间间隔量化到离散的桶中。

    用于节奏熵计算。将施法间隔映射到有限的节拍位置类别。

    Args:
        interval: 时间间隔（秒）
        num_bins: 量化桶数
        max_val: 最大间隔值

    Returns:
        桶索引 (0 ~ num_bins-1)
    """
    clamped = min(interval, max_val)
    normalized = clamped / max_val
    return min(int(normalized * num_bins), num_bins - 1)


# =============================================================================
# 第五部分：核心疲劳计算引擎
# =============================================================================

class AestheticFatigueEngine:
    """
    听感疲劳计算引擎。

    本引擎是 Project Harmony 听感疲劳系统的核心，负责：
    1. 记录玩家的法术施放历史
    2. 实时计算多维度疲劳指标
    3. 融合为统一的疲劳指数 (Aesthetic Fatigue Index, AFI)
    4. 输出疲劳等级和惩罚效果

    计算模型基于文档中的 MMI (Music Monotony Index) 公式：
        AFI = w1·(1 - H_pitch) + w2·(1 - H_transition) + w3·(1 - H_rhythm)
              + w4·RR_ngram + w5·(1 - H_chord)

    其中各项分别对应：
        - 音高熵 (Pitch Entropy)：法术音符选择的多样性
        - 转移熵 (Transition Entropy)：法术序列的可预测性
        - 节奏熵 (Rhythm Entropy)：施法时间间隔的多样性
        - n-gram 递归率 (Recurrence Rate)：短模式的重复程度
        - 和弦多样性 (Chord Diversity)：和弦类型的变化程度
    """

    def __init__(self, config: Optional[FatigueConfig] = None):
        """
        初始化疲劳引擎。

        Args:
            config: 疲劳系统配置。若为 None，使用默认配置。
        """
        self.config = config or FatigueConfig()
        self._history: deque[SpellEvent] = deque(maxlen=self.config.max_history_size)
        self._per_note_fatigue: dict[Note, float] = defaultdict(float)
        self._last_diversity_notes: set[Note] = set()

    # ---- 公开接口 ----

    def record_spell(self, event: SpellEvent) -> "FatigueResult":
        """
        记录一次法术施放并返回当前疲劳状态。

        这是系统的主入口。每次玩家施放法术时调用此方法，
        系统将更新历史记录并重新计算疲劳指数。

        Args:
            event: 法术施放事件

        Returns:
            FatigueResult 对象，包含完整的疲劳分析结果。
        """
        self._history.append(event)
        self._prune_old_events(event.timestamp)
        return self._compute_fatigue(event.timestamp, event.note)

    def query_fatigue(self, current_time: float,
                      target_note: Optional[Note] = None) -> "FatigueResult":
        """
        查询当前疲劳状态（不记录新事件）。

        可用于 UI 显示或 AI 决策参考。

        Args:
            current_time: 当前游戏时间
            target_note: 可选，查询特定音符的疲劳状态

        Returns:
            FatigueResult 对象。
        """
        self._prune_old_events(current_time)
        return self._compute_fatigue(current_time, target_note)

    def get_note_fatigue_map(self, current_time: float) -> dict[Note, float]:
        """
        获取所有音符的个体疲劳值映射。

        可用于 UI 上显示每个法术槽位的疲劳状态。

        Args:
            current_time: 当前游戏时间

        Returns:
            {Note: fatigue_value} 字典，值范围 [0.0, 1.0]。
        """
        self._prune_old_events(current_time)
        result = {}
        for note in Note:
            result[note] = self._compute_note_specific_fatigue(note, current_time)
        return result

    def reset(self):
        """重置疲劳系统（例如关卡切换时）。"""
        self._history.clear()
        self._per_note_fatigue.clear()
        self._last_diversity_notes.clear()

    # ---- 内部计算方法 ----

    def _prune_old_events(self, current_time: float):
        """移除超出时间窗口的旧事件。"""
        cutoff = current_time - self.config.window_duration
        while self._history and self._history[0].timestamp < cutoff:
            self._history.popleft()

    def _decay_weight(self, dt: float) -> float:
        """
        指数时间衰减函数。

        模拟人类听觉记忆的遗忘曲线。事件距今越远，
        其对疲劳的贡献越小。

        w(dt) = 2^(-dt / half_life)

        Args:
            dt: 时间差（秒），dt >= 0

        Returns:
            衰减权重，范围 (0.0, 1.0]。
        """
        if dt <= 0:
            return 1.0
        return math.pow(2.0, -dt / self.config.decay_half_life)

    def _compute_fatigue(self, current_time: float,
                         target_note: Optional[Note] = None) -> "FatigueResult":
        """
        核心疲劳计算流程。

        按照 MMI 公式，分别计算五个维度的疲劳分量，
        然后加权融合为统一的疲劳指数 (AFI)。
        """
        events = list(self._history)
        n = len(events)

        # 边界情况：事件太少，无法产生疲劳
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
        # 疲劳 = 1 - 熵（熵越低，疲劳越高）
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

        # ---- 加权融合：AFI 公式 ----
        cfg = self.config
        afi = (
            cfg.weight_pitch_entropy * pitch_fatigue
            + cfg.weight_transition_entropy * transition_fatigue
            + cfg.weight_rhythm_entropy * rhythm_fatigue
            + cfg.weight_recurrence * recurrence
            + cfg.weight_chord_diversity * chord_fatigue
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
            recurrence, chord_fatigue, current_time
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
        )

        return FatigueResult(
            fatigue_index=afi,
            fatigue_level=level,
            components=components,
            penalty=penalty,
            note_specific_fatigue=note_fatigue,
            recovery_suggestions=suggestions,
        )

    def _compute_rhythm_fatigue(self, events: list[SpellEvent],
                                current_time: float) -> float:
        """
        计算节奏维度的疲劳值。

        将相邻法术的时间间隔量化为离散类别，
        然后计算其加权香农熵。
        """
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
        """
        计算多尺度 n-gram 递归率。

        综合 2-gram、3-gram、4-gram 的递归率，
        取加权平均值。较长的 n-gram 重复权重更高，
        因为它们代表更明显的模式循环。
        """
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
        """
        计算和弦多样性维度的疲劳值。

        统计窗口内使用的和弦类型分布，计算其熵。
        如果玩家只使用单音符而不组合和弦，也会产生一定疲劳。
        """
        chord_events = [(e.timestamp, e.chord_type or "none") for e in events]
        chord_entropy = weighted_shannon_entropy(
            chord_events, self._decay_weight, current_time
        )
        return 1.0 - chord_entropy

    def _compute_note_specific_fatigue(self, note: Note,
                                       current_time: float) -> float:
        """
        计算特定音符的个体疲劳值。

        基于该音符在时间窗口内的使用频率和时间衰减。
        这用于实现"单音符疲劳"——某个特定法术被过度使用。
        """
        events = [e for e in self._history if e.note == note]
        if not events:
            return 0.0

        total_weight = 0.0
        for e in events:
            dt = current_time - e.timestamp
            total_weight += self._decay_weight(dt)

        # 归一化：假设在窗口内使用超过 6 次（衰减后）为满疲劳
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
        """
        根据疲劳等级和惩罚模式计算具体的惩罚效果。
        """
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
        recurrence: float, chord_f: float, current_time: float
    ) -> list[str]:
        """
        基于各维度疲劳值，生成恢复建议。

        这些建议可以显示在游戏 UI 中，引导玩家打破单调。
        """
        suggestions = []

        if pitch_f > 0.5:
            # 找出最少使用的音符
            note_counts = defaultdict(float)
            for e in self._history:
                dt = current_time - e.timestamp
                note_counts[e.note] += self._decay_weight(dt)
            unused = [n for n in WHITE_KEYS if note_counts.get(n, 0) < 0.5]
            if unused:
                names = [NOTE_NAMES[n] for n in list(unused)[:3]]
                suggestions.append(f"尝试使用新音符：{', '.join(names)}")
            else:
                suggestions.append("增加音符选择的多样性")

        if trans_f > 0.5:
            suggestions.append("打破当前的音符序列模式，尝试不同的组合顺序")

        if rhythm_f > 0.5:
            suggestions.append("改变施法节奏，尝试不同的时间间隔")

        if recurrence > 0.5:
            suggestions.append("避免重复相同的法术组合模式")

        if chord_f > 0.5:
            suggestions.append("尝试组合不同类型的和弦")

        return suggestions


# =============================================================================
# 第六部分：结果数据结构
# =============================================================================

@dataclass
class FatigueComponents:
    """
    疲劳计算的各维度分量，用于调试和 UI 展示。
    """
    pitch_entropy: float = 1.0
    pitch_fatigue: float = 0.0
    transition_entropy: float = 1.0
    transition_fatigue: float = 0.0
    rhythm_entropy: float = 1.0
    rhythm_fatigue: float = 0.0
    recurrence_rate: float = 0.0
    chord_diversity: float = 1.0
    chord_fatigue: float = 0.0


@dataclass
class PenaltyEffect:
    """
    疲劳惩罚效果。
    """
    damage_multiplier: float = 1.0
    """法术伤害乘数，1.0 为无惩罚。"""

    is_locked: bool = False
    """法术是否被锁定（仅 LOCKOUT 模式）。"""

    global_dissonance: float = 0.0
    """全局不和谐度（仅 GLOBAL_DEBUFF 模式），范围 [0, 1]。"""

    description: str = ""
    """惩罚效果的文字描述。"""


@dataclass
class FatigueResult:
    """
    疲劳计算的完整结果。

    这是 record_spell() 和 query_fatigue() 的返回值，
    包含了游戏逻辑所需的全部信息。
    """
    fatigue_index: float
    """综合疲劳指数 (AFI)，范围 [0.0, 1.0]。"""

    fatigue_level: FatigueLevel
    """疲劳等级。"""

    components: FatigueComponents
    """各维度分量的详细数据。"""

    penalty: PenaltyEffect
    """惩罚效果。"""

    note_specific_fatigue: float
    """目标音符的个体疲劳值。"""

    recovery_suggestions: list[str]
    """恢复建议列表。"""

    def __repr__(self) -> str:
        return (
            f"FatigueResult(\n"
            f"  AFI={self.fatigue_index:.3f}, "
            f"Level={self.fatigue_level.name},\n"
            f"  Components: pitch={self.components.pitch_fatigue:.2f}, "
            f"transition={self.components.transition_fatigue:.2f}, "
            f"rhythm={self.components.rhythm_fatigue:.2f}, "
            f"recurrence={self.components.recurrence_rate:.2f}, "
            f"chord={self.components.chord_fatigue:.2f},\n"
            f"  Penalty: dmg_mult={self.penalty.damage_multiplier:.2f}, "
            f"locked={self.penalty.is_locked}\n"
            f")"
        )


# =============================================================================
# 第七部分：便捷工厂与预设配置
# =============================================================================

def create_easy_config() -> FatigueConfig:
    """
    简单难度配置。

    疲劳积累较慢，阈值较高，适合新手玩家。
    """
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
    )


def create_normal_config() -> FatigueConfig:
    """
    普通难度配置（默认）。
    """
    return FatigueConfig()


def create_hard_config() -> FatigueConfig:
    """
    困难难度配置。

    疲劳积累更快，阈值更低，要求玩家保持高度多样性。
    """
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
    )


def create_maestro_config() -> FatigueConfig:
    """
    大师难度配置。

    极其严格的疲劳系统，模拟文档中提到的
    "音乐知觉能力较强的听众更容易体验到无聊"的特性。
    """
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
        weight_pitch_entropy=0.25,
        weight_transition_entropy=0.30,
        weight_rhythm_entropy=0.20,
        weight_recurrence=0.15,
        weight_chord_diversity=0.10,
    )


# =============================================================================
# 第八部分：演示与测试
# =============================================================================

def demo_scenario_monotonous():
    """
    演示场景 1：单调的法术使用模式。

    玩家反复使用相同的音符 C，节奏间隔固定。
    预期：疲劳快速上升。
    """
    print("=" * 70)
    print("场景 1：单调模式 — 反复施放 C 音符")
    print("=" * 70)

    engine = AestheticFatigueEngine(create_normal_config())

    for i in range(12):
        t = i * 0.5  # 每 0.5 秒施放一次
        event = SpellEvent(timestamp=t, note=Note.C, beat_position=(i % 4) / 4.0)
        result = engine.record_spell(event)
        print(f"  t={t:5.1f}s | 施放: C  | AFI={result.fatigue_index:.3f} "
              f"| 等级: {result.fatigue_level.name:10s} "
              f"| 伤害乘数: {result.penalty.damage_multiplier:.2f}")

    print()


def demo_scenario_diverse():
    """
    演示场景 2：多样化的法术使用模式。

    玩家使用多种不同的音符和和弦，节奏有变化。
    预期：疲劳保持在低水平。
    """
    print("=" * 70)
    print("场景 2：多样化模式 — 使用多种音符和和弦")
    print("=" * 70)

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
        print(f"  t={t:5.1f}s | 施放: {name:2s}{chord_str:10s} "
              f"| AFI={result.fatigue_index:.3f} "
              f"| 等级: {result.fatigue_level.name:10s} "
              f"| 伤害乘数: {result.penalty.damage_multiplier:.2f}")

    print()


def demo_scenario_recovery():
    """
    演示场景 3：疲劳积累后的恢复过程。

    玩家先重复使用 C，然后切换到多样化模式。
    预期：疲劳先上升后下降。
    """
    print("=" * 70)
    print("场景 3：恢复过程 — 从单调到多样化")
    print("=" * 70)

    engine = AestheticFatigueEngine(create_normal_config())

    # 阶段 1：单调
    print("  --- 阶段 1：单调施法 ---")
    for i in range(8):
        t = i * 0.5
        event = SpellEvent(timestamp=t, note=Note.C)
        result = engine.record_spell(event)
        print(f"  t={t:5.1f}s | 施放: C  | AFI={result.fatigue_index:.3f} "
              f"| 等级: {result.fatigue_level.name}")

    # 阶段 2：多样化恢复
    print("  --- 阶段 2：多样化恢复 ---")
    recovery_notes = [Note.E, Note.G, Note.A, Note.F, Note.D, Note.B]
    for i, note in enumerate(recovery_notes):
        t = 4.0 + (i + 1) * 0.7
        event = SpellEvent(timestamp=t, note=note)
        result = engine.record_spell(event)
        name = NOTE_NAMES[note]
        print(f"  t={t:5.1f}s | 施放: {name:2s} | AFI={result.fatigue_index:.3f} "
              f"| 等级: {result.fatigue_level.name}")
        if result.recovery_suggestions:
            print(f"           建议: {result.recovery_suggestions[0]}")

    print()


def demo_scenario_penalty_modes():
    """
    演示场景 4：三种惩罚模式的对比。
    """
    print("=" * 70)
    print("场景 4：三种惩罚模式对比")
    print("=" * 70)

    for mode in PenaltyMode:
        config = FatigueConfig(penalty_mode=mode)
        engine = AestheticFatigueEngine(config)

        # 快速积累疲劳
        for i in range(10):
            event = SpellEvent(timestamp=i * 0.4, note=Note.C)
            engine.record_spell(event)

        result = engine.query_fatigue(4.0, Note.C)
        print(f"  模式: {mode.name:15s} | AFI={result.fatigue_index:.3f} "
              f"| {result.penalty.description}")

    print()


def demo_note_fatigue_map():
    """
    演示场景 5：音符疲劳热力图。
    """
    print("=" * 70)
    print("场景 5：音符疲劳热力图")
    print("=" * 70)

    engine = AestheticFatigueEngine(create_normal_config())

    # 模拟偏好 C 和 E 的玩家
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


if __name__ == "__main__":
    print()
    print("╔══════════════════════════════════════════════════════════════════════╗")
    print("║     Project Harmony — 听感疲劳计算模型 (Aesthetic Fatigue System)     ║")
    print("║                          演示与验证                                  ║")
    print("╚══════════════════════════════════════════════════════════════════════╝")
    print()

    demo_scenario_monotonous()
    demo_scenario_diverse()
    demo_scenario_recovery()
    demo_scenario_penalty_modes()
    demo_note_fatigue_map()

    print("=" * 70)
    print("所有演示场景执行完毕。")
    print("=" * 70)
