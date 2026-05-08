---
description: "Docs 与项目级设计文档的维护、索引、归档和一致性规范"
globs: ["Docs/**/*", "GDD.md", "README.md", "DOCUMENTATION_INDEX.md", "DOCUMENTATION_GUIDELINES.md"]
---

# Docs 模块规范

## 1. 模块职责

`Docs/` 与根目录设计文档共同构成 Project Harmony 的活跃设计文档体系。`GDD.md` 是游戏愿景与核心机制主文档，`DOCUMENTATION_INDEX.md` 是文档导航入口，`DOCUMENTATION_GUIDELINES.md` 规定文档维护方式，`Docs/` 存放音频、敌人、Boss、UI、VFX、优化、数值、频谱相位等专项设计。

| 文档类型 | 代表文件或目录 | 维护规则 |
|---|---|---|
| 主设计 | `GDD.md` | 修改核心玩法、系统定义或术语时更新。 |
| 文档索引 | `DOCUMENTATION_INDEX.md` | 新增、废弃、迁移文档时必须同步更新。 |
| 文档规范 | `DOCUMENTATION_GUIDELINES.md` | 调整文档分类、命名、归档流程时更新。 |
| 专项设计 | `Docs/*.md`, `Docs/**/*.md` | 保持与 Godot 实现和 TODO 状态一致。 |
| 图表与参考 | `Docs/diagrams/`, `Assets/` | 文档引用的图片路径必须可解析。 |

## 2. 设计与实现一致性

文档描述应反映当前设计目标，但实现状态必须以 `godot_project/TODO.md` 为准。若文档宣称某系统“已完成”，应核对 TODO 与相关脚本。若设计文档描述的是目标方案而非已实现状态，应显式使用“设计目标”“计划”“待实现”等措辞。

| 场景 | 必做项 |
|---|---|
| 新增专项设计 | 添加到 `DOCUMENTATION_INDEX.md`，必要时在 `GDD.md` 加引用。 |
| 修改玩法机制 | 同步检查 `GDD.md`、相关 `Docs/`、`godot_project/TODO.md` 和实现脚本。 |
| 废弃旧方案 | 移入 `Archive/` 或在索引中标注归档，不要让旧文档继续作为活跃入口。 |
| 引入图片或图表 | 检查相对路径，必要时更新 `Assets.md` 或 `Docs/diagrams/`。 |

## 3. 归档规则

历史报告、旧路线图、过时任务结果应归档到 `Archive/` 或任务结果目录，默认不进入活跃上下文。归档文档可以保留历史价值，但不得覆盖 `GDD.md`、`DOCUMENTATION_INDEX.md`、`Docs/` 中的当前结论。

## 4. 禁止行为

不得新增孤立文档而不更新索引。不得用历史报告覆盖当前 TODO 状态。不得在设计文档中引用不存在的资源路径。不得混用已实现状态与规划状态。不得删除重要设计文档而不留下迁移说明或归档位置。
