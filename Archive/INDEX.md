# Archive 归档索引

**最后更新：** 2026年2月10日

本目录包含 Project Harmony 项目的历史文档、旧版本设计方案和已完成的实现报告。所有归档文档均已被新版本替代或已完成其历史使命，但保留以供参考和追溯设计演进过程。

---

## 目录结构

```
Archive/
├── INDEX.md                        # 本文件，归档索引
├── Reports/                        # 实现与修复报告归档
├── Boss_DissonantConductor/        # 旧版Boss设计归档
├── Project_Harmony_Proposal_v1~v5.md  # 历史提案文档
├── Numerical_Design_Documentation_v1.md  # 旧版数值设计
└── 其他历史文档
```

---

## 一、实现与修复报告（Reports/）

### 1.1 音频系统报告（2026-02-09）

| 文档名称 | 版本 | 日期 | 摘要 |
|---------|------|------|------|
| [AUDIO_EFFECTS_DESIGN.md](Reports/AUDIO_EFFECTS_DESIGN.md) | v5.2 | 2026-02-09 | 音频效果器系统设计文档，定义了穿透/追踪/分裂/回响/散射五种黑键效果的音频处理方案 |
| [AUDIO_EFFECTS_IMPLEMENTATION_REPORT.md](Reports/AUDIO_EFFECTS_IMPLEMENTATION_REPORT.md) | - | 2026-02-09 | 音频效果器系统实现报告，记录了 AudioEffectManager 和五种效果器的实现细节 |
| [AUDIO_EFFECTS_PARAMETER_OPTIMIZATION.md](Reports/AUDIO_EFFECTS_PARAMETER_OPTIMIZATION.md) | - | 2026-02-09 | 音频效果器参数优化报告，解决了音调变化、失真和音色纯净度问题 |
| [AUDIO_EFFECTS_VERIFICATION.md](Reports/AUDIO_EFFECTS_VERIFICATION.md) | - | 2026-02-09 | 音频效果器系统验证报告，确认所有效果器正常工作且音调保持不变 |
| [MUSIC_OPTIMIZATION_REPORT.md](Reports/MUSIC_OPTIMIZATION_REPORT.md) | - | 2026-02-09 | 音乐生成系统优化报告，引入 Techno 专用鼓组并缩短音符时长 |

**关键成果：** 完成了音频效果器系统的设计、实现、优化和验证全流程，为法术效果提供了专属音频处理能力。

### 1.2 Bug 修复报告（2026-02-08）

| 文档名称 | 修复问题数 | 日期 | 摘要 |
|---------|-----------|------|------|
| [BUG_FIX_REPORT_2026_02_08.md](Reports/BUG_FIX_REPORT_2026_02_08.md) | 20 | 2026-02-08 | 第一轮Bug修复，涵盖 UI 页面、游戏功能、信号连接、经验值系统等关键领域 |
| [BUG_FIX_REPORT_v5.0_2026_02_08.md](Reports/BUG_FIX_REPORT_v5.0_2026_02_08.md) | 9 | 2026-02-08 | v5.0 代码审查与修复，解决护盾系统、受击反馈、和谐殿堂、图鉴解锁等问题 |

**关键成果：** 共修复 29 个问题，确保 v5.0 版本的核心系统稳定运行。

### 1.3 版本实现报告

| 文档名称 | 版本 | 日期 | 摘要 |
|---------|------|------|------|
| [IMPLEMENTATION_REPORT_2.1_2.2.md](Reports/IMPLEMENTATION_REPORT_2.1_2.2.md) | v2.1/v2.2 | - | 延迟与距离风险系统（v2.1）和局外成长系统"和谐殿堂"（v2.2）的实现报告 |
| [Assessment_And_Implementation_Plan.md](Reports/Assessment_And_Implementation_Plan.md) | - | - | 早期评估与实现计划文档，包含密度疲劳系统的初步设计 |

---

## 二、历史设计提案（v1~v5）

| 文档名称 | 版本 | 核心内容 | 状态 |
|---------|------|---------|------|
| [Project_Harmony_Proposal_v1.md](Project_Harmony_Proposal_v1.md) | v1 | 初始游戏概念，音乐理论与魔法系统结合的基础构想 | 已被 v2 替代 |
| [Project_Harmony_Proposal_v2.md](Project_Harmony_Proposal_v2.md) | v2 | 引入白键/黑键法术系统，和弦类型决定法术形态 | 已被 v3 替代 |
| [Project_Harmony_Proposal_v3.md](Project_Harmony_Proposal_v3.md) | v3 | 新增和弦进行系统，引入乐段效果概念 | 已被 v4 替代 |
| [Project_Harmony_Proposal_v4.md](Project_Harmony_Proposal_v4.md) | v4 | 完善节奏型系统，引入单音寂静三维惩罚模型 | 已被 v5 替代 |
| [Project_Harmony_Proposal_v5.md](Project_Harmony_Proposal_v5.md) | v5 | 整合所有核心机制，形成完整的生成式法术系统 | 已整合进 GDD.md |

**演进脉络：** v1 基础概念 → v2 法术系统 → v3 和弦进行 → v4 节奏与惩罚 → v5 完整整合 → 当前 GDD

---

## 三、旧版数值设计

| 文档名称 | 版本 | 日期 | 摘要 |
|---------|------|------|------|
| [Numerical_Design_Documentation_v1.md](Numerical_Design_Documentation_v1.md) | v1 | - | 早期数值设计文档，定义了基础的音符属性、和弦伤害和疲劳系统参数 |
| [Assessment_Report_Density_Fatigue.md](Assessment_Report_Density_Fatigue.md) | - | - | 密度疲劳系统评估报告，分析了密度值与留白疲劳的平衡性 |

**当前版本：** [Docs/Numerical_Design_Documentation.md](../Docs/Numerical_Design_Documentation.md)

---

## 四、旧版 Boss 设计

| 目录/文档 | 版本 | 摘要 |
|----------|------|------|
| [Boss_DissonantConductor/](Boss_DissonantConductor/) | 旧版 | 失谐指挥家 Boss 的早期设计，包含机制、阶段和攻击模式 |

**当前版本：** 已被音乐史七大 Boss 体系替代（Pythagoras, Guido, Bach, Mozart, Beethoven, Jazz, Noise），详见 [Docs/关卡与Boss整合设计文档_v3.0.md](../Docs/关卡与Boss整合设计文档_v3.0.md)

---

## 五、早期修复报告

| 文档名称 | 日期 | 摘要 |
|---------|------|------|
| [fix_report.md](fix_report.md) | 2026-02-08 | 第一轮修复报告（早期版本） |
| [review_report_round2.md](review_report_round2.md) | 2026-02-08 | 第二轮审查报告 |

**后续版本：** 已被 Reports/ 目录下的正式修复报告替代

---

## 六、归档文档使用指南

### 6.1 查阅目的
- **追溯设计演进**：了解某个机制从 v1 到当前版本的演变过程
- **参考历史决策**：查看某个设计选择的原始理由和讨论
- **学习实现过程**：研究某个系统的实现报告和优化历程
- **问题排查**：查阅历史修复报告，了解类似问题的解决方案

### 6.2 查阅建议
1. **优先查阅当前文档**：归档文档仅供参考，当前设计以根目录和 Docs/ 下的文档为准
2. **注意版本差异**：归档文档中的数值、机制可能与当前版本不一致
3. **关注演进逻辑**：重点理解"为什么改变"而非"改变了什么"
4. **交叉验证**：如需引用归档内容，请与当前 GDD 交叉验证

### 6.3 不应做的事
- ❌ 直接使用归档文档中的数值或机制（可能已过时）
- ❌ 将归档文档作为实现依据（应以当前文档为准）
- ❌ 在外部引用归档文档而不注明"已归档"状态

---

## 七、归档文档更新记录

| 日期 | 操作 | 文档数量 | 说明 |
|------|------|---------|------|
| 2026-02-10 | 创建 Archive/Reports/ | 9 | 归档音频系统报告、Bug修复报告、实现报告 |
| 2026-02-10 | 创建 INDEX.md | 1 | 创建本索引文档 |
| 2026-02-09 | 归档旧版美术文档 | 3 | 移动到 Docs/Archive/ |
| - | 历史归档 | 多个 | v1~v5 提案、旧版数值设计、早期修复报告等 |

---

## 八、相关链接

- **当前核心文档**：[../GDD.md](../GDD.md)
- **仓库导航**：[../README.md](../README.md)
- **最新关卡设计**：[../Docs/关卡与Boss整合设计文档_v3.0.md](../Docs/关卡与Boss整合设计文档_v3.0.md)
- **当前数值设计**：[../Docs/Numerical_Design_Documentation.md](../Docs/Numerical_Design_Documentation.md)
- **文档维护规范**：[../DOCUMENTATION_GUIDELINES.md](../DOCUMENTATION_GUIDELINES.md)（待创建）

---

**维护说明：** 每次归档操作后，请更新本索引文档的"归档文档更新记录"章节，并补充新归档文档的摘要信息。
