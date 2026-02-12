# Project Harmony 文档中心

**版本:** 1.2  
**最后更新:** 2026-02-12 (Issue #94 文档同步更新)  
**状态:** 已定稿

---

## 1. 概述

欢迎来到 Project Harmony 的文档中心。本文档是所有设计、技术和美术文档的顶层索引，旨在帮助团队成员快速找到所需信息，并理解各文档之间的关系。

所有文档都遵循"单一事实来源"（Single Source of Truth）原则。当不同文档提及同一概念时，应以层级更低的专项设计文档为准。例如，`GDD.md` 中对敌人的描述是概览，而 `Docs/Enemy_System_Design.md` 中的描述是详细定义。

## 2. 文档地图

下图展示了核心文档之间的引用关系：

```mermaid
graph TD
    subgraph 顶层设计
        GDD(GDD.md) -- 概览 --> Mechanics(核心机制)
        GDD -- 概览 --> Spellcraft(法术构建)
        GDD -- 概览 --> Enemy(敌人设计)
        GDD -- 概览 --> Progression(成长系统)
    end

    subgraph 专项设计 (Docs/)
        Mechanics --> ResonanceSlicing(ResonanceSlicing_System_Design.md)
        Mechanics --> AestheticFatigue(AestheticFatigueSystem_Documentation.md)
        Spellcraft --> Numerical(Numerical_Design_Documentation.md)
        Enemy --> EnemyDesign(Enemy_System_Design.md)
        Progression --> MetaProgression(MetaProgressionSystem_Documentation.md)
    end

    subgraph 美术与音频 (Docs/)
        ArtDirection(Art_And_VFX_Direction.md) -- 指导 --> ArtImplementation(ART_IMPLEMENTATION_FRAMEWORK.md)
        ArtDirection -- 指导 --> SpellVisual(Spell_Visual_Enhancement_Design.md)
        AudioDesign(Audio_Design_Guide.md)
    end

    subgraph 章节开发计划 (Docs/)
        ChapterPlans(Chapter1~7_Dev_Plan.md) -- 实现 --> EnemyDesign
        ChapterPlans -- 实现 --> BossDesign(关卡与Boss整合设计文档_v3.0.md)
    end

    style GDD fill:#f9f,stroke:#333,stroke-width:2px
    style ArtDirection fill:#ccf,stroke:#333,stroke-width:2px
    style ArtImplementation fill:#cce,stroke:#333,stroke-width:1px
    style ChapterPlans fill:#cfc,stroke:#333,stroke-width:1px
```

## 3. 核心文档清单

### 3.1. 顶层设计

| 文档 | 简介 | 目标读者 |
| :--- | :--- | :--- |
| **GDD.md** | **游戏设计总纲**。定义游戏的核心概念、设计支柱、所有主要系统（法术、敌人、成长等）的概览。**这是所有设计的起点。** | 全体成员 |
| **DOCUMENTATION_GUIDELINES.md** | **文档编写规范**。定义了文档的版本控制、格式、术语等标准。 | 全体成员 |

### 3.2. 系统设计 (位于 `Docs/`)

| 文档 | 简介 | 目标读者 |
| :--- | :--- | :--- |
| **Numerical_Design_Documentation.md** | **数值设计**。定义所有公式、参数、成长曲线和平衡性策略。包含自动化跑分系统的说明。 | 策划、程序 |
| **AestheticFatigueSystem_Documentation.md** | **听感疲劳系统**。详细设计"单音寂静"系统的所有维度、惩罚机制和数值。 | 策划、程序 |
| **ResonanceSlicing_System_Design.md** | **共鸣切片系统**。详细设计三相频谱切换的核心战斗解谜机制。 | 策划、程序、美术 |
| **TimbreSystem_Documentation.md** | **音色系统**。定义四大音色系别的机制、视觉表现和与法术系统的交互。 | 策划、程序、美术 |
| **SummoningSystem_Documentation.md** | **召唤系统**。定义小七和弦召唤物的机制、属性和行为。 | 策划、程序 |
| **MetaProgressionSystem_Documentation.md** | **局外成长系统**。定义"和谐殿堂"的机制、数值边界和解锁项。 | 策划、程序 |

### 3.3. 内容设计 (位于 `Docs/`)

| 文档 | 简介 | 目标读者 |
| :--- | :--- | :--- |
| **Enemy_System_Design.md** | **敌人设计**。定义所有敌人的基础行为、属性、攻击模式和频谱相位形态。 | 策划、程序、美术 |
| **Audio_Design_Guide.md** | **音频设计指南**。定义BGM、玩家音效、敌人音效的设计哲学和技术实现。 | 音频、程序 |
| **关卡与Boss整合设计文档_v3.0.md** | **关卡与Boss设计**。定义七大章节的主题、流程、特殊机制和Boss战设计。 | 策划、程序、美术 |
| **Chapter_Enemy_Procedural_Visual_Spec.md** | **章节敌人程序化视觉规范**。定义章节敌人的程序化视觉生成方案。 | 程序、美术 |
| **Character_Design_Concept.md** | **角色设计概念**。定义角色的视觉设计方向和概念。 | 美术、策划 |

### 3.4. 章节开发计划 (位于 `Docs/`)

每章开发计划基于第一章"随机流+剧本流"混合模型，包含章节时间线、核心系统改造需求、剧本波次设计、Boss战设计和资源清单。

| 文档 | 简介 | 状态 | 目标读者 |
| :--- | :--- | :--- | :--- |
| **Chapter1_Dev_Plan.md** | **第一章：律动尊者·毕达哥拉斯**。垂直切片开发计划，含6个剧本波次和Boss战设计。 | **✅ 已实现** | 策划、程序 |
| **Chapter2_Dev_Plan.md** | **第二章：故障指挥家·艾伦**。Screech/Silence 敌人、信号过载/蓝屏死机Boss战。 | 设计稿 | 策划、程序 |
| **Chapter3_Dev_Plan.md** | **第三章：大构建师·巴赫**。建筑师音墙/反射棱镜、赋格追逐Boss战。 | 设计稿 | 策划、程序 |
| **Chapter4_Dev_Plan.md** | **第四章：摇滚反叛者·莫扎特**。即兴乐手/摇摆弹道、乐句模仿Boss战。 | 设计稿 | 策划、程序 |
| **Chapter5_Dev_Plan.md** | **第五章：印象派织梦师·德彪西**。迷雾/倒影、双形态Boss战。 | 设计稿 | 策划、程序 |
| **Chapter6_Dev_Plan.md** | **第六章：十二音序列破坏者·勋伯格**。音列矩阵/序列敌人、矩阵变形Boss战。 | 设计稿 | 策划、程序 |
| **Chapter7_Dev_Plan.md** | **第七章：合成主脑·斯托克豪森**。频谱相位系统、四乐章最终Boss战。 | 设计稿 | 策划、程序 |

### 3.5. 美术与实现 (位于 `Docs/`)

`Art_And_VFX_Direction.md` 和 `ART_IMPLEMENTATION_FRAMEWORK.md` 是相辅相成的两个文档，共同构成了美术设计的完整蓝图。

| 文档 | 简介 | 目标读者 |
| :--- | :--- | :--- |
| **Art_And_VFX_Direction.md** | **美术圣经 (The "What")**。定义游戏的美学哲学、双极美学体系、全局色彩、章节风格、视觉语言等**顶层艺术方向**。 | 美术、策划、程序 |
| **ART_IMPLEMENTATION_FRAMEWORK.md** | **技术美术蓝图 (The "How")**。将美术方向转化为**可执行的技术方案**。包含代码审计、架构决策、Shader实现、场景重构等。 | 程序、技术美术 |
| **ART_IMPLEMENTATION_2.5D_BRIDGE.md** | **2.5D桥接实现**。定义2.5D视觉效果的技术实现方案。 | 程序、技术美术 |
| **Spell_Visual_Enhancement_Design.md** | **法术视觉增强**。`Art_And_VFX_Direction.md` 的深化扩展，为超过60种法术效果提供细粒度的视觉设计规范。 | 美术、程序 |
| **Harmonic_Modes_Avatar_Implementation.md** | **谐振调式化身实现**。Issue #59 的完整实现文档，定义了四种程序化角色化身的骨骼系统、几何体、着色器和集成接口。 | 程序、技术美术 |
| **Procedural_Scene_Architecture.md** | **程序化场景架构**。定义程序化场景生成的架构设计。 | 程序 |
| **Procedural_Scene_Implementation.md** | **程序化场景实现**。程序化场景的具体实现方案。 | 程序 |

### 3.6. 优化模块 (位于 `Docs/Optimization_Modules/`)

优化模块是对现有系统的增强和深化设计，旨在提升音乐性体验和技术表现。

| 文档 | 简介 | 状态 | 目标读者 |
| :--- | :--- | :--- | :--- |
| **OPT01_GlobalDynamicHarmonyConductor.md** | **全局动态和声指挥家。BGMManager 升级为和声指挥官，支持玩家和弦实时响应、马尔可夫链自动演进、全局和声上下文广播。** | **✅ 已实现** | 程序、音频 |
| **OPT02_RelativePitchSystem.md** | **相对音高系统。RelativePitchResolver 将法术音高从绝对转为相对和弦功能音，确保音效与 BGM 和谐。** | **✅ 已实现** | 程序、音频 |
| **OPT03_EnemyMusicalInstrumentIdentity.md** | **敌人乐器身份**。为每种敌人赋予独特的乐器音色身份。 | 设计稿 | 策划、程序 |
| **OPT04_ChapterTonalityEvolution.md** | **章节调性演化**。定义各章节的音乐调性变化和叙事弧线，从 Ionian → Chromatic 逐步演进。 | **✅ 已实现** | 策划、音频 |
| **OPT05_RezStyleInputQuantization.md** | **Rez 式输入量化错觉**。将游戏音效自动对齐到十六分音符网格，创造"人人都是节奏大师"的错觉。 | **✅ 已实现** | 策划、程序 |
| **OPT06_SpatialAudioInformationDelivery.md** | **空间音频信息传递**。利用空间化音频传递游戏信息。 | 设计稿 | 程序、音频 |
| **OPT07_SummoningSystemMusicality.md** | **召唤系统音乐性深化**。将召唤系统升华为空间化音序器，每种构造体对应独立音乐声部。 | **✅ 已实现** | 策划、程序 |
| **OPT08_ProceduralTimbreSynthesis.md** | **程序化音色合成**。为音色武器系统引入实时减法合成器引擎，实现"所听即所见"。 | **✅ 已实现** | 程序、音频 |

### 3.7. 评估与分析报告

| 文档 | 简介 | 日期 |
| :--- | :--- | :--- |
| **Feature_Completeness_Report.md** | **功能完整性报告 v2.0**。全面评估设计文档与代码实现之间的差距，涵盖法术、疲劳、召唤、音色、敌人等核心系统。 | 2026-02-09 |
| **doc_analysis_report.md** | **文档整理分析报告**。分析文档结构、一致性和组织问题。 | 2026-02-11 |
| **Meta_Progression_Fix_Report.md** | **局外成长修复报告**。记录局外成长系统的问题修复过程。 | — |
| **meta_progression_analysis_report.md** | **局外成长分析报告**。局外成长系统的详细分析。 | — |
| **Archive/GDD_Evaluation_TODO_v2.md** | **GDD评估与待办事项清单 v2（已归档）**。基于 v3.0 设计文档的项目评估，识别波次设计差距和优先级重排。 | 2026-02-10 |

## 4. 项目状态追踪

| 文档 | 简介 | 位置 |
| :--- | :--- | :--- |
| **godot_project/TODO.md** | **开发待办清单（唯一可信来源）**。记录所有系统的实现状态、待办事项和文件变更日志。 | `godot_project/` |
| **ProjectHarmony-项目待办事项.md** | **项目级待办事项**。追踪高层任务、优先级和依赖关系。 | 根目录 |

## 5. 归档

`Archive/` 目录存放所有过时或已完成的文档，例如：
- 旧版本的提案 (`Project_Harmony_Proposal_v1.md` ... `v5.md`)
- 阶段性报告 (`Assessment_Report_Density_Fatigue.md`)
- 已被取代的设计 (`Numerical_Design_Documentation_v1.md`)
- 已完成的评估报告 (`GDD_Evaluation_TODO_v2.md`)

归档目录的内容不应再被引用，仅供历史追溯。

## 6. 知识库

`docs/knowledge-base/` 目录存放开发过程中沉淀的技术解决方案和最佳实践。

| 文档 | 简介 |
| :--- | :--- |
| **[知识库索引](docs/knowledge-base/INDEX.md)** | 包含所有疑难问题解决方案、代码技巧和引擎特性分析。 |
