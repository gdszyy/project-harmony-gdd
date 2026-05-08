# project-harmony-gdd 全局协作规范

本文档是 `project-harmony-gdd` 仓库的 AI 协作入口。任何 Agent 进入本仓库后，应先读取本文档，再按任务范围选择 `.cursor/rules/` 下的模块规范与 `.cursor/rules/auto_index/` 下的代码级索引。仓库的核心目标是维护 **Project Harmony** 的游戏设计、Godot 实现、数值平衡、知识库与辅助服务，使设计文档和可运行实现保持一致。

## 1. 项目事实来源

本项目是音乐理论与魔法系统深度结合的幸存者类肉鸽游戏。协作时必须优先区分“设计真理”“实现状态”和“历史记录”，避免把归档报告误当作当前架构。

| 优先级 | 事实来源 | 用途 | 使用规则 |
|---|---|---|---|
| 1 | `godot_project/TODO.md` | 当前开发状态、完成度、待办项 | 修改代码或设计后必须同步更新，是实现状态的唯一可信来源。 |
| 2 | `GDD.md` | 游戏设计主线、核心机制、系统目标 | 涉及玩法、术语或系统边界时优先对齐。 |
| 3 | `DOCUMENTATION_INDEX.md` 与 `Docs/` | 专项设计、UI、音频、敌人、Boss、数值与 VFX 文档 | 新增或调整设计文档时保持索引可导航。 |
| 4 | `.cursor/rules/*.md` | Agent 协作规范、模块边界、编辑策略 | 修改架构、API、核心逻辑时必须同步更新相关规则。 |
| 5 | `.cursor/rules/auto_index/INDEX.md` | 大文件与函数级入口 | 定位大型源码文件时先查索引，再用搜索命令进入源码。 |

## 2. 快速导航

| 任务类型 | 首读文件 | 后续索引 |
|---|---|---|
| Godot 玩法、战斗、UI、音频、Boss、存档 | `.cursor/rules/godot_project.md` | `.cursor/rules/auto_index/INDEX.md` 与 `godot_project/TODO.md` |
| 服务端、数据库迁移、认知标签、向量检索 | `.cursor/rules/server.md` | `server/README.md` 与 `server/migrations/` |
| 设计文档、GDD、文档归档 | `.cursor/rules/Docs.md` | `DOCUMENTATION_GUIDELINES.md` 与 `DOCUMENTATION_INDEX.md` |
| 美术、图表、概念图、GDD 引用资产 | `.cursor/rules/Assets.md` | `Assets/` 与 `Docs/diagrams/` |
| 原型计算、听感疲劳模型 | `.cursor/rules/Scripts.md` | `Scripts/aesthetic_fatigue_system.py` |
| 数值平衡、跑分、报告生成 | `.cursor/rules/BalanceKit.md` | `BalanceKit/Methodology.md` 与 `BalanceKit/Reports/` |
| 已知坑、Bug 复盘、可复用排错经验 | `.cursor/rules/knowledge-base.md` | `docs/knowledge-base/INDEX.md` |
| 跨模块流程或历史踩坑 | `.cursor/rules/process_insights/index.md` | 相关 `PI-*.md` 洞察文档 |

## 3. 上下文防污染策略

以下目录包含历史方案、任务沉淀或输出结果，Agent 默认不得主动读取，除非用户明确要求追溯历史，或当前任务需要核验历史决策来源。

| 归档区 | 默认策略 | 说明 |
|---|---|---|
| `Archive/` | 跳过 | 历史版本文档、旧实现报告、归档资产。 |
| `Tasks/`, `tasks/` | 跳过 | 旧任务记录或过程资料。 |
| `TaskResults/`, `task-results/`, `task_results/` | 跳过 | 任务输出沉淀。 |
| `Results/`, `results/` | 跳过 | 分析与生成结果，可能不是当前状态。 |

## 4. 全局编辑策略

所有实质性改动都必须遵守 **活文档契约**：如果修改了系统架构、API、核心玩法、关键数据模型或跨模块流程，必须在同一提交中同步更新相应 `.cursor/rules/` 文档、`godot_project/TODO.md` 与必要的设计文档索引。

| 修改规模 | 推荐策略 | 约束 |
|---|---|---|
| 小型修改，少于 20 行 | 精确搜索替换 | 避免重写无关上下文。 |
| 中型修改，20 至 200 行 | 局部重写或追加章节 | 保持周边注释、信号名、资源路径稳定。 |
| 大型修改，超过 200 行 | 先拆分边界，再重写 | 对超过 500 行或函数超过 20 个的文件，先查 `.cursor/rules/auto_index/`。 |
| 巨型函数修改 | 先确认 `@section` 节点 | 文件超过 2000 行且缺少 `@section` 时，不应盲改，应先补结构或请求确认。 |

## 5. 全局禁止行为

不得将 `Archive/`、任务结果目录或旧报告中的内容直接视为当前实现状态。不得在没有同步 `godot_project/TODO.md` 的情况下提交代码或设计状态变更。不得硬编码真实凭证、Token、API Key、数据库密码或个人信息。不得绕过 Godot 信号、Autoload 单例、对象池、MultiMesh 等既有架构直接堆砌重复实现。不得手工编辑 `.cursor/rules/auto_index/` 下的机器生成文件；需要更新时运行代码索引脚本。

## 6. 模块规范索引

| 模块 | 规则文件 | 核心边界 |
|---|---|---|
| 全局架构 | `.cursor/rules/global.md` | 系统全景、事实来源、跨模块契约。 |
| Godot 项目 | `.cursor/rules/godot_project.md` | 可运行游戏实现、Autoload、场景、UI、敌人、音频、VFX。 |
| 服务端 | `.cursor/rules/server.md` | EdgeReader 后端、Go/GORM/MySQL、迁移、向量检索模型。 |
| 文档体系 | `.cursor/rules/Docs.md` | GDD、专项设计、文档索引、归档规范。 |
| 资产体系 | `.cursor/rules/Assets.md` | GDD 图表、视觉概念图、Mermaid 图和 UI 参考图。 |
| 脚本原型 | `.cursor/rules/Scripts.md` | 听感疲劳与其他计算模型原型。 |
| 平衡工具 | `.cursor/rules/BalanceKit.md` | 数值跑分、策略评估、报告生成。 |
| 知识库 | `.cursor/rules/knowledge-base.md` | 已知技术坑、Bug 模式、排错经验。 |

## 7. 流程洞察与代码索引维护

当任务中发现非直观耦合、重复踩坑风险或跨模块流程，应新增或更新 `.cursor/rules/process_insights/`，并同步维护索引文件。涉及代码变更时，提交前必须重新运行代码级索引，使 `.cursor/rules/auto_index/INDEX.md` 与源码保持同步。
