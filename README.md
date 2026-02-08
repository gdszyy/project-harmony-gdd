# Project Harmony - 游戏设计文档库

**版本：** 2.4.1 (Live Document)
**最后更新：** 2026年2月8日
**最新修复：** [Bug 修复报告 2026-02-08](BUG_FIX_REPORT_2026_02_08.md) — 修复 20 个关键问题，涵盖 UI、游戏功能、信号连接、经验值系统

---

## 项目简介

**Project Harmony** 是一款将音乐理论与魔法系统深度结合的幸存者类（Survivor-like）肉鸽（Roguelike）游戏。玩家的每一次法术施放和组合都在实时创作一首乐曲，游戏的核心平衡与资源管理完全基于音乐性的内在逻辑。本仓库是该游戏的设计文档库，所有设计决策与迭代过程均在此记录。

## 开发规范

> **重要：每次对项目进行修改（无论是新增功能、修复 Bug 还是重构代码），都必须同步更新 `godot_project/TODO.md`。** TODO 清单是项目状态的唯一可信来源（Single Source of Truth），所有开发者在提交代码前必须确保 TODO 中对应条目的状态标记已更新。不遵守此规范将导致团队对项目状态产生误判。

具体要求：
1. **新增功能**：在 TODO 中添加对应条目，标记为 ✅ 已完成，并注明完成日期和文件路径。
2. **部分实现**：将对应条目标记为 🔲 部分完成，并在"现状"中说明已完成和未完成的部分。
3. **重构或删除**：更新受影响条目的描述和状态，必要时添加说明。
4. **归档内容**：被替换或废弃的实现应移入 `Archive/` 目录，并在 TODO 中注明。

## 仓库结构

```
project-harmony-gdd/
├── GDD.md                  # [核心] 实时主设计文档，包含最新最完整的游戏设计方案
├── README.md               # 本文件，仓库导航与开发规范
├── BUG_FIX_REPORT_2026_02_08.md  # [最新] Bug 修复报告 (2026-02-08)
├── Feature_Completeness_Report.md  # 功能完整性检查报告
├── Assets/                 # 当前 GDD 引用的可视化图表
│   ├── black_key_dual_role_v5.png
│   ├── chord_spell_form_v5.png
│   └── generalized_progression_v5.png
├── Docs/                   # 专项设计文档与技术文档
│   ├── AestheticFatigueSystem_Documentation.md
│   ├── Art_Direction_Resonance_Horizon.md
│   ├── Audio_Design_Guide.md
│   ├── Enemy_System_Design.md
│   ├── Godot_Implementation_Guide.md
│   ├── Level_And_Boss_Design.md
│   ├── MetaProgressionSystem_Documentation.md
│   ├── Numerical_Design_Documentation.md
│   ├── SummoningSystem_Documentation.md
│   ├── TimbreSystem_Documentation.md
│   └── UI_Art_Style_Enhancement_Proposal.md  # [v2.4] UI与美术风格优化提案
├── BalanceKit/             # 平衡性跑分系统 (v2.2)
│   ├── Methodology.md
│   ├── balance_scorer.py
│   ├── generate_report.py
│   └── Reports/
├── Scripts/                # 原型代码与计算模型
│   └── aesthetic_fatigue_system.py
├── godot_project/          # Godot 4.6 游戏项目
│   ├── TODO.md             # [关键] 开发任务清单 — 项目状态的唯一可信来源
│   └── ...
└── Archive/                # 历史版本存档
    ├── Boss_DissonantConductor/  # [归档] 失谐指挥家Boss（已由音乐史Boss体系替代）
    ├── Max_Issues_Implementation_Report.md  # [归档] 旧版Issue实现报告
    ├── fix_report.md  # [归档] 第一轮修复报告 (2026-02-08)
    ├── review_report_round2.md  # [归档] 第二轮审查报告 (2026-02-08)
    ├── Project_Harmony_Proposal_v1~v5.md
    ├── Numerical_Design_Documentation_v1.md
    ├── Assessment_Report_Density_Fatigue.md
    └── Assets/
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
12. **关卡与Boss体系 (v2.3)**：基于音乐史演进的七章节结构，每章配有独特场景、敌人和Boss战，通过“风格排斥”系统驱动玩法进化。
13. **UI与美术风格优化 (v2.4)**：统一视觉语言（全局调色板、色彩规范）、UI动态“多汁感”提升、关键UI主题化重绘（Boss血条、和谐殿堂、谐振法典）、核心玩法视觉反馈强化（5个新Shader + VFX管理器）。
14. **Boss 核心系统补全 (v2.4)**：音乐史七大 Boss (Pythagoras, Guido, Bach, Mozart, Beethoven, Jazz, Noise) 的核心战斗逻辑、阶段系统及专属机制已全部补全。

详细内容请查阅 **[GDD.md](GDD.md)**、**[数值设计文档](Docs/Numerical_Design_Documentation.md)**、**[局外成长系统文档](Docs/MetaProgressionSystem_Documentation.md)** 和 **[关卡与Boss设计](Docs/Level_And_Boss_Design.md)**。
