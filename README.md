# Project Harmony - 游戏设计文档库

**版本：** 2.5.2 (Live Document)
**最后更新：** 2026年2月10日
**最新设计：** [关卡与Boss整合设计文档 v3.0](Docs/关卡与Boss整合设计文档_v3.0.md) — 全七章波次级精确设计，遵循"环境即教程"原则
**最新修复：** [v5.0 代码审查与修复报告](Archive/Reports/BUG_FIX_REPORT_v5.0_2026_02_08.md) — 修复 8 个问题，涵盖护盾系统、受击反馈、和谐殿堂、图鉴解锁

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

## 文档规范

> **文档维护指南：** 所有文档贡献者应遵守 [文档维护规范](DOCUMENTATION_GUIDELINES.md)，包括命名规范、结构规范、归档流程等。该规范确保文档库的一致性和可维护性。

**快速链接：**
- **文档命名规范**：[DOCUMENTATION_GUIDELINES.md#一文档命名规范](DOCUMENTATION_GUIDELINES.md#一文档命名规范)
- **归档流程**：[DOCUMENTATION_GUIDELINES.md#三文档归档流程](DOCUMENTATION_GUIDELINES.md#三文档归档流程)
- **归档索引**：[Archive/INDEX.md](Archive/INDEX.md)

## 仓库结构

```
project-harmony-gdd/
├── GDD.md                  # [核心] 实时主设计文档，包含最新最完整的游戏设计方案
├── README.md               # 本文件，仓库导航与开发规范
├── DOCUMENTATION_GUIDELINES.md  # 文档维护规范（命名、结构、归档流程）
├── Feature_Completeness_Report.md  # 功能完整性检查报告（持续更新）
├── Assets/                 # 当前 GDD 引用的可视化图表
│   ├── black_key_dual_role_v5.png
│   ├── chord_spell_form_v5.png
│   └── generalized_progression_v5.png
├── Docs/                   # 专项设计文档与技术文档
│   ├── 关卡与Boss整合设计文档_v3.0.md  # [最新] v3.0 波次级精确设计
│   ├── AestheticFatigueSystem_Documentation.md
│   ├── ART_IMPLEMENTATION_FRAMEWORK.md  # [v2.0] 美术框架实施方案
│   ├── Art_And_VFX_Direction.md  # [v2.0] 美术与VFX方向
│   ├── Audio_Design_Guide.md
│   ├── Enemy_System_Design.md
│   ├── MetaProgressionSystem_Documentation.md
│   ├── Numerical_Design_Documentation.md
│   ├── ResonanceSlicing_System_Design.md  # 频谱相位系统（共鸣切片）
│   ├── SummoningSystem_Documentation.md
│   ├── TimbreSystem_Documentation.md
│   └── Archive/            # 历史设计文档
│       ├── 关卡与Boss机制设计文档.md (v2.0)
│       ├── Design_Update_Proposal_v1.md
│       ├── Art_Direction_Resonance_Horizon.md
│       ├── Godot_Implementation_Guide.md
│       └── UI_Art_Style_Enhancement_Proposal.md
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
    ├── INDEX.md            # 归档索引（所有归档文档的摘要和导航）
    ├── Reports/            # 实现与修复报告归档
    │   ├── AUDIO_EFFECTS_DESIGN.md
    │   ├── AUDIO_EFFECTS_IMPLEMENTATION_REPORT.md
    │   ├── AUDIO_EFFECTS_PARAMETER_OPTIMIZATION.md
    │   ├── AUDIO_EFFECTS_VERIFICATION.md
    │   ├── MUSIC_OPTIMIZATION_REPORT.md
    │   ├── BUG_FIX_REPORT_2026_02_08.md
    │   ├── BUG_FIX_REPORT_v5.0_2026_02_08.md
    │   ├── IMPLEMENTATION_REPORT_2.1_2.2.md
    │   └── Assessment_And_Implementation_Plan.md
    ├── Boss_DissonantConductor/  # [归档] 失谐指挥家Boss（已由音乐史Boss体系替代）
    ├── Max_Issues_Implementation_Report.md
    ├── fix_report.md
    ├── review_report_round2.md
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
12. **关卡与Boss体系 (v2.3/v3.0)**：基于音乐史演进的七章节结构，每章配有独特场景、敌人和Boss战，通过"风格排斥"系统驱动玩法进化。v3.0 版本提供了波次级精确设计，遵循"环境即教程"、"先安全试错再实战检验"、"辩证否定链"三大原则。
13. **UI与美术风格优化 (v2.4)**：统一视觉语言（全局调色板、色彩规范）、UI动态"多汁感"提升、关键UI主题化重绘（Boss血条、和谐殿堂、谐振法典）、核心玩法视觉反馈强化（5个新Shader + VFX管理器）。
14. **Boss 核心系统补全 (v2.4)**：音乐史七大 Boss (Pythagoras, Guido, Bach, Mozart, Beethoven, Jazz, Noise) 的核心战斗逻辑、阶段系统及专属机制已全部补全。
15. **v5.0 音频与弹体系统强化**：新增 BGM 程序化音乐生成、受击反馈管理器、护盾伤害吸收、召唤物自动攻击、结晶障碍物、Boss 血条 UI 等。
16. **频谱相位系统（共鸣切片）**：核心战斗解谜机制，通过音色相位切换（Attack/Sustain/Release）解锁特殊战术增益，并引入频谱偏移疲劳机制。

详细内容请查阅 **[GDD.md](GDD.md)**、**[数值设计文档](Docs/Numerical_Design_Documentation.md)**、**[局外成长系统文档](Docs/MetaProgressionSystem_Documentation.md)** 和 **[关卡与Boss整合设计文档 v3.0](Docs/关卡与Boss整合设计文档_v3.0.md)**。

---

## 文档整理说明（2026-02-10）

本次整理将历史实现报告和修复报告移入 `Archive/Reports/`，旧版设计文档移入 `Docs/Archive/`，删除了重复的 `Level_And_Boss_Design.md`（已被 v3.0 版本替代）。所有当前活跃的设计文档均保留在根目录和 `Docs/` 目录下，确保仓库结构清晰、易于导航。

**同时建立了文档维护体系：**
- 创建 [Archive/INDEX.md](Archive/INDEX.md) 归档索引，提供所有归档文档的摘要和导航
- 制定 [DOCUMENTATION_GUIDELINES.md](DOCUMENTATION_GUIDELINES.md) 文档维护规范，明确命名、结构、归档流程
- 在 README 中新增“文档规范”章节，为贡献者提供快速入口
