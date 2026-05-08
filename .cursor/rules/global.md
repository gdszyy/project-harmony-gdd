---
description: "project-harmony-gdd 的全局架构、事实来源、跨模块契约与禁止行为"
globs: ["README.md", "GDD.md", "DOCUMENTATION_INDEX.md", "DOCUMENTATION_GUIDELINES.md", "godot_project/TODO.md", ".cursor/rules/**/*.md"]
---

# 全局架构规范

## 1. 系统概述

`project-harmony-gdd` 同时承载 **Project Harmony** 的主设计文档、Godot 4.6 游戏项目、专项设计文档、数值平衡工具、技术知识库以及一个独立的 EdgeReader 后端服务。Project Harmony 的核心设计是将音符、和弦、节奏、音色、相位与听感疲劳转化为战斗系统，使玩家的战斗行为同时构成一段实时音乐创作过程。

| 层级 | 目录或文件 | 当前职责 |
|---|---|---|
| 设计主线 | `GDD.md`, `README.md` | 定义游戏愿景、核心机制、术语和仓库导航。 |
| 活跃设计文档 | `Docs/`, `DOCUMENTATION_INDEX.md` | 维护音频、敌人、Boss、UI、VFX、数值、优化模块等专项设计。 |
| 游戏实现 | `godot_project/` | Godot 项目，包含 Autoload、系统脚本、实体、UI、场景、资源和 TODO。 |
| 数值与模型 | `BalanceKit/`, `Scripts/` | 平衡性跑分、报告生成、听感疲劳模型原型。 |
| 支撑服务 | `server/` | EdgeReader 后端，包含 Go 模型、MySQL 迁移、认知标签和向量检索设计。 |
| 知识与复盘 | `docs/knowledge-base/`, `.cursor/rules/process_insights/` | 记录可复用技术坑和 Agent 过程洞察。 |
| 历史资料 | `Archive/`, `Tasks/`, `Results/` 等 | 默认不读，避免污染当前判断。 |

## 2. 核心机制主线

游戏系统围绕“音乐即编程、听感即平衡、战斗即创作”展开。Godot 实现中的 `SpellcraftSystem`、`MusicTheoryEngine`、`FatigueManager`、`ProjectileManager`、`SummonManager`、`AudioManager` 与 UI 编曲界面共同支撑主循环：玩家在一体化编曲台和战斗 HUD 中配置音符、和弦、节奏型与手动施法槽，系统基于乐理规则生成法术形态、音色反馈、弹体行为、听感疲劳惩罚与战场效果。

| 设计概念 | 实现关注点 | 主要入口 |
|---|---|---|
| 音符经济 | 库存、装备、卸下、永久消耗 | `godot_project/scripts/autoload/`, `godot_project/scripts/ui/` |
| 和弦炼成 | 音程识别、法术书、扩展和弦 | `spellcraft_system.gd`, `music_data.gd`, UI 面板 |
| 听感疲劳 | 单调、密度、不和谐、多维 AFI、视觉滤镜 | `fatigue_manager.gd`, `fatigue_filter_controller.gd` |
| 弹体战斗 | MultiMesh、对象池、修饰符、和弦弹体形态 | `projectile_manager.gd`, `pool_manager.gd` |
| 召唤系统 | 小七和弦触发、共鸣网络、玩家指挥 | `summon_manager.gd`, `summon_construct.gd` |
| 敌人与 Boss | 基础敌人、章节敌人、精英敌人、七大 Boss | `enemy_spawner.gd`, `boss_base.gd`, Boss 脚本 |
| 音频与 BGM | 程序化音效、BPM 同步、动态混音 | `audio_manager.gd`, `bgm_manager.gd` |

## 3. 事实来源与同步规则

`godot_project/TODO.md` 是当前开发状态的唯一可信来源。凡是新增功能、修复 Bug、重构系统、调整设计状态或归档实现，都必须更新该文件。`GDD.md` 定义玩法目标与设计原则；`Docs/` 提供专项设计细节；`.cursor/rules/` 提供 Agent 协作和模块边界。

| 场景 | 必须同步的文件 |
|---|---|
| 修改核心玩法、系统架构、Godot 代码 | `godot_project/TODO.md`, 对应 `.cursor/rules/*.md`, 必要时更新 `GDD.md` 或 `Docs/`。 |
| 新增或废弃设计文档 | `DOCUMENTATION_INDEX.md`, `DOCUMENTATION_GUIDELINES.md` 规定的索引或归档位置。 |
| 修复复杂 Bug 并发现隐蔽耦合 | `.cursor/rules/process_insights/index.md` 与新的或已有的 `PI-*.md`。 |
| 修改大源码文件 | 运行 code-indexer，更新 `.cursor/rules/auto_index/`。 |
| 调整数值模型或平衡报告 | `BalanceKit/Methodology.md` 或相关报告说明。 |

## 4. 归档与历史目录策略

默认不要读取 `Archive/`、`Tasks/`、`tasks/`、`TaskResults/`、`task-results/`、`task_results/`、`Results/`、`results/`。这些目录可以作为历史追溯材料，但不能覆盖 `GDD.md`、`godot_project/TODO.md` 和活跃 `Docs/` 的当前结论。

## 5. 全局禁止行为清单

不得跳过 TODO 同步提交实现变更。不得把历史报告当作当前代码事实。不得在未核验信号签名、Autoload 名称和资源路径的情况下重命名 Godot 节点、场景或全局单例。不得将真实凭证写入文档或代码。不得手工编辑 `.cursor/rules/auto_index/` 机器生成文件。不得在大型 Godot 脚本中无结构地追加逻辑；涉及超过 2000 行文件时，应优先使用既有 `@section` 节点或先补充结构化标记。

## 6. 代码定位规范

进入大文件前应先读取 `.cursor/rules/auto_index/INDEX.md`。索引文件不记录行号，定位时使用函数名或 `@section` 标记搜索源码。若索引缺失或疑似过期，应运行 code-indexer 全量生成。
