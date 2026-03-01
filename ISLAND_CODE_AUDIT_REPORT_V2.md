# Project Harmony 孤岛代码全面评估报告

**审计人:** code_auditor
**日期:** 2026-03-01
**目标仓库:** `gdszyy/project-harmony-gdd`

## 1. 审计概述

本次审计旨在对 `project-harmony-gdd` 项目中的所有 GDScript 和 Shader 文件进行全面的引用关系分析，以识别并处理项目中未被直接引用的“孤岛”代码。通过分析场景文件（`.tscn`）、资源文件（`.tres`）、`project.godot` 的 Autoload 配置以及代码内的动态加载和 `class_name` 引用，我们得到了详细的代码依赖拓扑。

### 1.1 统计概览

- **.gd 脚本文件总数:** 201
- **被引用的 .gd 文件:** 196
- **真正的 .gd 孤岛文件:** 5 (占 2.5%)
- **.gdshader 文件总数:** 62
- **被引用的 .gdshader 文件:** 58
- **真正的 .gdshader 孤岛文件:** 4 (占 6.4%)

*(注：相比初步扫描结果，经过深入分析动态字符串路径加载和静态方法调用后，大量被误判为孤岛的文件已被确认为正常引用的文件)*

## 2. 孤岛文件详细列表与处置建议

### 2.1 真正的孤岛文件 (需要处理)

这些文件在当前项目中没有任何形式的引用，属于真正的冗余或废弃代码。

| 文件路径 (res://) | 功能描述 | 分类 | 处置建议 | 风险评估 |
| :--- | :--- | :--- | :--- | :--- |
| `scripts/systems/fatigue_audio_feedback.gd` | 疲劳等级音效反馈管理器。原设计用于监听 FatigueManager 信号播放音效。 | 功能性孤岛 | **归档/删除**。未在 Autoload 注册，也未被任何场景挂载。 | 低。功能似乎未被实际启用或已被整合。 |
| `scripts/systems/timbre_hotkey_manager.gd` | 音色切换快捷键绑定管理器。 | 功能性孤岛 | **归档/删除**。输入处理似乎已整合到 `input_setup.gd` 或其他输入管理器中。 | 低。如果快捷键功能正常工作，说明该独立脚本已被废弃。 |
| `scripts/ui/difficulty_select_ui.gd` | 难度选择 UI 面板 (Issue #115)。 | 功能性孤岛 | **保留并集成**。如果是未完成的功能，应将其集成到主菜单中；如果是废弃设计，则归档。 | 低。 |
| `scripts/visual/spell_visual_manager.gd` | 旧版法术视觉管理器。 | 废弃代码 | **删除**。项目中存在 `scripts/systems/spell_visual_manager.gd` (v2.0)，且被主场景引用。此为遗留文件。 | 低。保留会引起同名类的混淆。 |
| `scripts/entities/basalt_column_obstacle.gd` | 玄武岩柱体障碍物脚本。 | 废弃代码 | **删除**。已被 `scripts/entities/obstacle.gd` 替代。 | 低。 |

### 2.2 伪孤岛文件 (动态加载/隐式引用，需保留)

以下文件在静态扫描时可能显示为孤岛，但实际上通过动态加载或框架特性被引用。

| 文件分类 | 包含文件 | 引用方式 | 处置建议 |
| :--- | :--- | :--- | :--- |
| **数据容器类** | `data/waves/ch1/*.gd` 到 `ch7/*.gd` (共14个) | 通过 `chapter_data.gd` 中的字符串路径动态加载。 | **保留**。属于正常的剧本波次数据。 |
| **动态加载系统** | `scripts/entities/summon_construct.gd` | 通过 `summon_manager.gd` 中的 `CONSTRUCT_SCENE_PATH` 字符串路径加载。 | **保留**。召唤系统的核心组件。 |
| **静态方法库** | `scripts/systems/audio_effect_processor.gd` | 被 `note_synthesizer.gd` 通过 `AudioEffectProcessor.xxx()` 静态调用。 | **保留**。DSP 音频效果核心。 |

### 2.3 Shader 孤岛文件

| Shader 文件路径 | 功能描述 | 处置建议 | 风险评估 |
| :--- | :--- | :--- | :--- |
| `shaders/archive/bitcrush_ground_corruption.gdshader` | 比特破碎虫地面腐蚀效果 | **删除**。已明确放入 archive 目录。 | 无风险。 |
| `shaders/archive/chapter_transition.gdshader` | 章节过渡 Shader | **删除**。已明确放入 archive 目录。 | 无风险。 |
| `shaders/archive/lydian_particle.gdshader` | Lydian 粒子效果 | **删除**。已明确放入 archive 目录。 | 无风险。 |
| `shaders/flowing_energy.gdshader` | 流动能量基础效果 | **归档/删除**。未被任何材质或场景引用。 | 低。可能是测试或废弃的 Shader。 |

*(注：`shaders/chapters/ch1-7_ground.gdshader` 和 `shaders/ui/energy_ring.gdshader` 等经查证均被 3D 渲染桥接器或 UI 场景动态加载，不属于孤岛)*

## 3. 与上次审计 (ISLAND_CODE_AUDIT_REPORT.md) 的对比

1. **新增发现：** 本次扫描发现了上次报告中未提及的 `spell_visual_manager.gd` 重复文件问题（`scripts/visual/` 目录下的旧版遗留）。
2. **状态确认：** 上次报告中提到归档的 9 个 `.gd` 脚本和 4 个 `.gdshader` 文件目前已妥善移至 `archive` 目录，证明之前的清理工作已执行。
3. **架构优化：** 大量“孤岛”实际上是数据驱动架构（如 `wave_data`）和动态实例化系统（如 `summon_construct`）的产物。这表明项目的代码解耦做得较好，但也增加了静态分析的难度。

## 4. 风险评估与建议

### 4.1 核心建议
1. **清理重复文件：** 立即删除 `scripts/visual/spell_visual_manager.gd`，以防与 `scripts/systems/spell_visual_manager.gd` 产生冲突或造成后续开发者的困惑。
2. **处理未注册的系统：** 调查 `fatigue_audio_feedback.gd` 和 `timbre_hotkey_manager.gd`。如果这些功能是需要的，请将它们注册到 `project.godot` 的 Autoload 中；如果已被其他系统取代，请果断删除。
3. **完成未完成的 UI：** `difficulty_select_ui.gd` 似乎是一个开发中或被遗忘的功能。建议在任务跟踪系统中确认其状态。

### 4.2 架构健康度
项目的 Autoload 管理非常健康。所有在 `scripts/autoload/` 目录下的 17 个脚本均已在 `project.godot` 中正确注册，没有遗漏。同时，部分核心系统（如 `chapter_manager.gd`）虽不在 autoload 目录，但也正确注册为全局单例，符合 Godot 的最佳实践。
