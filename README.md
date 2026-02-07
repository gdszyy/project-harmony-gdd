# Project Harmony - 游戏设计文档库

**版本：** 2.2 (Live Document)
**最后更新：** 2026年2月7日

---

## 项目简介

**Project Harmony** 是一款将音乐理论与魔法系统深度结合的幸存者类（Survivor-like）肉鸽（Roguelike）游戏。玩家的每一次法术施放和组合都在实时创作一首乐曲，游戏的核心平衡与资源管理完全基于音乐性的内在逻辑。本仓库是该游戏的设计文档库，所有设计决策与迭代过程均在此记录。

## 仓库结构

```
project-harmony-gdd/
├── GDD.md                  # [核心] 实时主设计文档，包含最新最完整的游戏设计方案
├── README.md               # 本文件，仓库导航
├── Assets/                 # 当前 GDD 引用的可视化图表
│   ├── black_key_dual_role_v5.png
│   ├── chord_spell_form_v5.png
│   └── generalized_progression_v5.png
├── Docs/                   # 专项设计文档与技术文档
│   ├── AestheticFatigueSystem_Documentation.md
│   ├── Numerical_Design_Documentation.md    # [v2.1] 含成长系统、扩展和弦、延迟/距离风险
│   ├── MetaProgressionSystem_Documentation.md  # [v2.2 新增] 局外成长系统"和谐殿堂"设计文档
│   ├── Enemy_System_Design.md
│   └── Godot_Implementation_Guide.md
├── BalanceKit/             # 平衡性跑分系统 (v2.2)
│   ├── Methodology.md      # 跑分系统方法论文档
│   ├── balance_scorer.py   # 核心跑分引擎（含局外成长接口预留）
│   ├── generate_report.py  # 可视化报告生成器
│   └── Reports/            # 跑分输出（图表与JSON报告）
│       ├── strategy_comparison.png
│       ├── dps_vs_risk.png
│       ├── fatigue_heatmap.png
│       ├── growth_curve.png
│       ├── chord_dissonance_power.png
│       ├── extended_chord_penalty.png
│       ├── delay_range_analysis.png
│       └── benchmark_results.json
├── Scripts/                # 原型代码与计算模型
│   └── aesthetic_fatigue_system.py
└── Archive/                # 历史版本存档（v1-v5 迭代方案、旧文档及图表）
    ├── Project_Harmony_Proposal_v1.md
    ├── Project_Harmony_Proposal_v2.md
    ├── Project_Harmony_Proposal_v3.md
    ├── Project_Harmony_Proposal_v4.md
    ├── Project_Harmony_Proposal_v5.md
    ├── Numerical_Design_Documentation_v1.md
    ├── Assessment_Report_Density_Fatigue.md
    └── Assets/             # 历史版本图表
```

## 当前设计核心

当前的设计方案构建了一个完全由参数化和乐理规则驱动的生成式法术系统：

1.  **白键法术**：7个白键音符，每个代表一种四维参数（伤害/速度/持续/大小）配比的基础弹体。
2.  **黑键修饰符**：5个黑键，单独使用时为弹体附加修饰效果（穿透/追踪/分裂/回响/散射），也可作为和弦构成音。
3.  **和弦类型 → 法术形态**：和弦的乐理类型（大三/小三/增三/减三/属七等）直接决定法术的表现形式（弹体/爆炸/DOT/法阵/冲击波/天降/护盾/召唤/蓄力）。
4.  **扩展和弦 (5-6音)**：九和弦、十一和弦、十三和弦等高级和弦，提供毁灭性威力但伴随极高风险，需通过传说级升级解锁。
5.  **和弦进行 → 乐段效果**：基于和弦功能转换（T/PD/D）的通用规则触发乐段效果，完整度越高效果越强。
6.  **节奏型 → 行为模式**：编排的节奏型（均匀/附点/切分/摇摆/三连/休止）改变弹体的行为模式。
7.  **单音寂静系统**：三维惩罚模型（单调值/密度值/不和谐值），取代传统冷却机制。
8.  **肉鸽数值成长**：五大类升级（音符属性/疲劳耐受/节奏精通/和弦精通/生存强化），支持多样化Build构建。
9.  **平衡性跑分系统**：自动化的策略评估工具，支持一键验证数值平衡性。
10. **延迟与距离风险系统 (v2.1)**：将法术的延迟和短射程纳入风险评估，验证伤害/范围补偿的合理性。
11. **局外成长系统 (v2.2)**：名为"和谐殿堂"的永久成长系统，包含四大模块（乐器调优/乐理研习/调式风格/声学降噪），已在跑分系统中预留架构接口。

详细内容请查阅 **[GDD.md](GDD.md)**、**[数值设计文档](Docs/Numerical_Design_Documentation.md)** 和 **[局外成长系统文档](Docs/MetaProgressionSystem_Documentation.md)**。
