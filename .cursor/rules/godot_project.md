---
description: "godot_project 模块的 Godot 实现架构、编辑边界、状态同步和代码定位规范"
globs: ["godot_project/**/*", ".cursor/rules/auto_index/**/*"]
---

# godot_project 模块规范

## 1. 模块职责

`godot_project/` 是 Project Harmony 的可运行 Godot 4.6 游戏项目，承载战斗系统、音乐理论引擎、UI、音频、敌人、Boss、VFX、场景、资源与开发状态清单。该模块的修改风险最高，因为设计、代码、场景资源和 `TODO.md` 必须保持一致。

| 子域 | 代表路径 | 职责 |
|---|---|---|
| 开发状态 | `godot_project/TODO.md` | 当前实现状态的唯一可信来源。 |
| Autoload 单例 | `godot_project/scripts/autoload/` | 全局状态、音乐理论、疲劳、音频、BGM、存档、Codex、信号桥等核心服务。 |
| 系统脚本 | `godot_project/scripts/systems/` | 弹体、召唤、敌人生成、章节、对象池、VFX、渲染桥、Boss 生成等。 |
| 实体脚本 | `godot_project/scripts/entities/` | 玩家、敌人、Boss、召唤物、弹体相关实体行为。 |
| UI 脚本 | `godot_project/scripts/ui/` | HUD、一体化编曲台、五度圈罗盘、和弦炼成、图鉴、教程、设置等界面。 |
| 场景资源 | `godot_project/scenes/` | Godot 场景、UI 场景、敌人场景、测试场景。 |
| 数据资源 | `godot_project/scripts/data/`, `godot_project/data/` | 章节、音乐数据、图鉴数据、Boss 对话等。 |
| 测试与基准 | `godot_project/scripts/tests/` | 性能基准、系统验证、回归检查。 |

## 2. 核心实现契约

Godot 代码应优先复用现有 Autoload、信号、对象池、MultiMesh 和数据驱动结构，而不是新增平行架构。修改前应查阅 `.cursor/rules/auto_index/INDEX.md`，因为项目中存在多个超过 500 行的大脚本，如 `codex_ui.gd`、`spell_visual_manager.gd`、`projectile_manager.gd`、`circle_of_fifths_upgrade_v3.gd`、`main_game.gd`、`audio_manager.gd`、`bgm_manager.gd`、`spellcraft_system.gd` 与多个 Boss 脚本。

| 系统 | 常见入口 | 注意事项 |
|---|---|---|
| 法术构建 | `spellcraft_system.gd`, `music_data.gd`, `chord_alchemy_panel_v3.gd` | 黑键双重身份、扩展和弦、序列器和法术书必须共同校验。 |
| 听感疲劳 | `fatigue_manager.gd`, `fatigue_filter_controller.gd` | 单调、密度、不和谐、留白奖励和视觉反馈需同步。 |
| 弹体 | `projectile_manager.gd`, `pool_manager.gd`, `spell_visual_manager.gd` | 保持对象池和 MultiMesh 批量渲染，不要为每个弹体创建高成本节点。 |
| 召唤 | `summon_manager.gd`, `summon_construct.gd`, `summon_audio_controller.gd` | 小七和弦触发、音色驱动、共鸣网络和玩家指挥机制要保持连贯。 |
| 敌人与 Boss | `enemy_spawner.gd`, `boss_base.gd`, `boss_*.gd`, 章节敌人脚本 | 章节波次、Boss 对话、Boss BGM、场景文件和 TODO 状态需联动。 |
| UI | `hud.gd`, `codex_ui.gd`, `circle_of_fifths_upgrade_v3.gd`, `sequencer_ui.gd` | UI 信号、拖拽交互、快捷键和数据源必须保持一致。 |
| 音频 | `audio_manager.gd`, `bgm_manager.gd`, `note_synthesizer.gd` | 音频总线、BPM 同步、程序化音效和动态混音不应被绕过。 |

## 3. 编辑规则

修改任何 Godot 代码、场景或资源后，必须核对 `godot_project/TODO.md` 是否需要更新。若修改实现状态、完成度、待办项、缺陷状态或系统说明，则必须同步更新 TODO。涉及设计偏差时，还应更新 `GDD.md` 或对应 `Docs/` 文档。

| 操作 | 必做项 |
|---|---|
| 新增玩法功能 | 更新 TODO 状态，补充相关设计文档或规则文档，检查 UI/音频/VFX 是否有依赖。 |
| 修复 Bug | 记录受影响系统；若发现非直观耦合，新增流程洞察或知识库条目。 |
| 重构大脚本 | 先查 auto_index；超过 2000 行且缺少 `@section` 时，应先补充结构化节点或请求确认。 |
| 修改信号或 Autoload | 全仓搜索调用点，确认场景绑定、信号签名和测试脚本同步。 |
| 修改资源路径 | 同步 `.tscn`、`.tres`、脚本预加载路径和文档引用。 |

## 4. 禁止行为

不得在未查索引的情况下直接重写大型脚本。不得新增与现有 Autoload 重叠的全局单例。不得绕过对象池和批量渲染机制创建大量临时节点。不得只修改代码而不更新 `godot_project/TODO.md`。不得将历史归档中的实现报告视为当前状态。不得手工编辑 `.cursor/rules/auto_index/` 产物。

## 5. 代码定位流程

进入 Godot 源码任务时，先打开 `.cursor/rules/auto_index/INDEX.md`，确认目标大文件是否已有函数索引。定位函数使用 `grep -n "函数名" godot_project/scripts/...`；定位巨型函数内部逻辑使用 `grep -n '@section:节点名'`。若索引缺失或源码刚被大量修改，应运行 code-indexer 全量或单文件更新。
