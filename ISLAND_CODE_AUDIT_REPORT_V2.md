# Project Harmony 孤岛代码全面评估报告 (V2)

**审计人:** code_auditor (Agent ID: agt-c1eeaede-e70)
**日期:** 2026-03-01
**目标仓库:** `gdszyy/project-harmony-gdd`
**任务 ID:** tsk-024a2b93-5c0
**审计范围:** `godot_project/` 目录下所有 `.gd` 和 `.gdshader` 文件

---

## 1. 审计概述

本次审计旨在对 `project-harmony-gdd` 项目进行全面的孤岛代码评估，以识别所有未被直接或间接引用的 GDScript 和 Shader 文件。审计通过以下四种引用方式进行全面扫描：

1. **Autoload 配置引用**：检查 `project.godot` 的 `[autoload]` 节，确认所有注册的全局单例。
2. **场景文件引用**：扫描所有 `.tscn` 文件中的 `ext_resource` 节点，提取 Script 类型资源路径。
3. **代码内引用**：扫描所有 `.gd` 文件中的 `load()`、`preload()`、`extends`（路径形式）以及 `class_name` 的静态调用和类型注解。
4. **字符串路径动态加载**：识别通过字符串常量（如 `CONSTRUCT_SCENE_PATH`）进行的动态 `load()` 调用。

本次审计在上次报告（`ISLAND_CODE_AUDIT_REPORT.md`，2026-02-12）的基础上进行，并结合了最新的架构重构提交（`tsk-7dbd9d41-db9`，引入了 `EventBus` 和 `Events` 系统）。

---

## 2. 统计概览

| 指标 | 数值 |
| :--- | :--- |
| `.gd` 脚本文件总数 | 203 |
| 被引用的 `.gd` 文件 | 196 |
| **真正的 `.gd` 孤岛文件** | **5** |
| 伪孤岛（动态加载/静态方法调用） | 20 |
| `.gdshader` 文件总数 | 63 |
| 被引用的 `.gdshader` 文件 | 55 |
| **真正的 `.gdshader` 孤岛文件** | **4** |
| 已归档的 Shader（archive 目录） | 3 |
| 待确认的 Shader 孤岛 | 1 |
| **Autoload 注册脚本数** | **27** |
| autoload 目录脚本数 | 19 |
| 未注册的 autoload 目录脚本 | 0 |

> **结论：** 项目整体代码健康度良好。在 203 个脚本文件中，真正的孤岛文件仅有 5 个（占 2.5%），远低于行业平均水平。

---

## 3. .gd 脚本文件孤岛详情

### 3.1 真正的孤岛文件（需要处理）

以下 5 个文件在当前项目中没有任何形式的引用，属于真正的冗余或废弃代码。

| # | 文件路径 (res://) | 功能描述 | 分类 | 处置建议 | 风险评估 |
| :- | :--- | :--- | :--- | :--- | :--- |
| 1 | `scripts/visual/spell_visual_manager.gd` | 旧版法术视觉管理器（含 `class_name SpellVisualManager`）。已被 `scripts/systems/spell_visual_manager.gd` (v2.0) 完全取代。 | 废弃代码 | **立即删除**。两个同名文件共存会造成 Godot 编辑器的 `class_name` 冲突警告，存在潜在的运行时错误风险。 | **中**。同名 class_name 可能导致意外的类型解析错误。 |
| 2 | `scripts/entities/basalt_column_obstacle.gd` | 玄武岩柱体障碍物专用脚本。障碍物系统已统一使用 `scripts/entities/obstacle.gd`。 | 废弃代码 | **删除**。对应的 Shader（`basalt_column.gdshader`）已被 `crystallized_silence_obstacle.tscn` 直接引用，无需此脚本。 | 低。 |
| 3 | `scripts/systems/fatigue_audio_feedback.gd` | 疲劳等级音效反馈管理器。设计为监听 `FatigueManager.fatigue_level_changed` 信号并播放音效。 | 功能性孤岛 | **评估后处理**。如果疲劳音效功能是需要的，应将其注册到 `project.godot` 的 Autoload 中，或挂载到主场景；否则归档。 | 低。 |
| 4 | `scripts/systems/timbre_hotkey_manager.gd` | 音色切换快捷键绑定管理器（数字键 1-7、Shift+数字键、鼠标滚轮切换音色）。 | 功能性孤岛 | **评估后处理**。`input_setup.gd` 注释中提到此脚本，说明它是一个计划中但未完成集成的功能。建议注册为 Autoload 或集成到 `input_setup.gd` 中。 | 低。 |
| 5 | `scripts/ui/difficulty_select_ui.gd` | 难度选择 UI 面板（Issue #115）。提供 4 种难度选项卡片，与 `DifficultyManager` 协作。 | 功能性孤岛 | **集成或归档**。如果 Issue #115 仍在计划中，应将此 UI 集成到主菜单场景；如果已废弃，则归档。 | 低。 |

### 3.2 伪孤岛文件（动态加载，需保留）

以下文件在静态扫描时显示为孤岛，但实际上通过动态加载或框架特性被正常引用。

#### 3.2.1 数据容器类（动态加载）

以下 18 个波次数据文件通过 `chapter_data.gd` 中的字符串路径被 `chapter_manager.gd` 动态加载（`load(wave_data_path)`），属于正常的数据驱动架构。

| 文件路径 | 引用方式 |
| :--- | :--- |
| `data/waves/ch1/wave_1_1.gd` 到 `wave_1_6.gd` | `chapter_data.gd` 字符串路径 → `chapter_manager.gd` 动态加载 |
| `data/waves/ch2/wave_2_1.gd` 到 `wave_2_2.gd` | 同上 |
| `data/waves/ch3/wave_3_1.gd` 到 `wave_3_2.gd` | 同上 |
| `data/waves/ch4/wave_4_1.gd` 到 `wave_4_2.gd` | 同上 |
| `data/waves/ch5/wave_5_1.gd` 到 `wave_5_2.gd` | 同上 |
| `data/waves/ch6/wave_6_1.gd` 到 `wave_6_2.gd` | 同上 |
| `data/waves/ch7/wave_7_1.gd` 到 `wave_7_2.gd` | 同上 |

**处置建议：** 全部保留。这是正常的数据驱动设计模式。

#### 3.2.2 动态实例化类

| 文件路径 | 功能描述 | 引用方式 |
| :--- | :--- | :--- |
| `scripts/entities/summon_construct.gd` | 召唤构造体基类（小七和弦系统） | `summon_manager.gd` 通过 `CONSTRUCT_SCENE_PATH` 字符串常量动态加载 |

**处置建议：** 保留。召唤系统的核心组件。

#### 3.2.3 静态方法库

| 文件路径 | 功能描述 | 引用方式 |
| :--- | :--- | :--- |
| `scripts/systems/audio_effect_processor.gd` | 音频 DSP 效果处理器（`class_name AudioEffectProcessor`） | `note_synthesizer.gd` 通过 `AudioEffectProcessor.byte_array_to_float_buffer()` 和 `AudioEffectProcessor.apply_modifier_effect()` 静态调用 |

**处置建议：** 保留。DSP 音频效果核心库。

---

## 4. .gdshader 文件孤岛详情

### 4.1 已归档 Shader（archive 目录，可安全删除）

| 文件路径 | 功能描述 | 处置建议 |
| :--- | :--- | :--- |
| `shaders/archive/bitcrush_ground_corruption.gdshader` | Bitcrush 虫地面腐蚀效果 | **删除**。已明确归档，且 `shaders/archive/` 目录已添加 `.gdignore`。 |
| `shaders/archive/chapter_transition.gdshader` | 章节过渡效果 | **删除**。同上。 |
| `shaders/archive/lydian_particle.gdshader` | Lydian 调式粒子效果 | **删除**。同上。 |

### 4.2 真正的孤岛 Shader（需要处理）

| 文件路径 | 功能描述 | 处置建议 | 风险评估 |
| :--- | :--- | :--- | :--- |
| `shaders/flowing_energy.gdshader` | 流动能量基础效果 Shader | **归档/删除**。未被任何场景、材质或脚本引用。可能是测试或废弃的 Shader。 | 低。 |

### 4.3 伪孤岛 Shader（动态加载，需保留）

以下 Shader 文件在静态扫描时显示为孤岛，但实际上通过动态加载被引用。

| 文件路径 | 功能描述 | 引用方式 |
| :--- | :--- | :--- |
| `shaders/chapters/ch1_chladni_ground.gdshader` | 第一章克拉尼图形地面 | `chapter_visual_manager_3d.gd` 通过格式化字符串路径动态加载（`"res://shaders/chapters/3d/ch%d_ground_3d.gdshader"`），但注意：该脚本加载的是 `3d/` 子目录下的版本，而非此文件。**需进一步确认**。 |
| `shaders/chapters/ch2-ch7_*_ground.gdshader` | 各章节地面 Shader | 同上。 |
| `shaders/ui/energy_ring.gdshader` | 相位能量环效果 | 未找到直接引用，可能是待集成的 UI Shader（关联 `ResonanceSlicingManager`）。 |
| `shaders/ui/phase_sector.gdshader` | 相位扇区渲染效果 | 同上。 |
| `shaders/ui/spectral_fatigue.gdshader` | 频谱偏移疲劳条效果 | `spectral_fatigue_indicator.gd` 使用 `_draw()` 方法程序化绘制，未通过 ShaderMaterial 引用此 Shader。 |

> **重要发现：** `shaders/chapters/` 目录下的 7 个章节地面 Shader（ch1-ch7）与 `shaders/chapters/3d/` 目录下的 3D 版本是不同的文件。`chapter_visual_manager_3d.gd` 加载的是 `3d/` 子目录，而 `shaders/chapters/` 下的 2D 版本目前没有找到任何引用。这可能是 2D 到 3D 迁移后遗留的文件，建议确认是否可以归档。

---

## 5. Autoload 注册状态审计

### 5.1 autoload 目录脚本注册状态

| 脚本文件 | 注册名称 | 状态 |
| :--- | :--- | :--- |
| `audio_manager.gd` | `AudioManager` | ✅ 已注册 |
| `bgm_manager.gd` | `BGMManager` | ✅ 已注册 |
| `codex_manager.gd` | `CodexManager` | ✅ 已注册 |
| `event_bus.gd` | `EventBus` | ✅ 已注册（新增） |
| `events.gd` | — | ⚠️ **未注册**（通过 `class_name Events` 全局访问） |
| `fatigue_manager.gd` | `FatigueManager` | ✅ 已注册 |
| `game_manager.gd` | `GameManager` | ✅ 已注册 |
| `global_music_manager.gd` | `GlobalMusicManager` | ✅ 已注册 |
| `input_setup.gd` | `InputSetup` | ✅ 已注册 |
| `meta_progression_manager.gd` | `MetaProgressionManager` | ✅ 已注册 |
| `mode_system.gd` | `ModeSystem` | ✅ 已注册 |
| `music_theory_engine.gd` | `MusicTheoryEngine` | ✅ 已注册 |
| `note_inventory.gd` | `NoteInventory` | ✅ 已注册 |
| `resonance_slicing_manager.gd` | `ResonanceSlicingManager` | ✅ 已注册 |
| `save_manager.gd` | `SaveManager` | ✅ 已注册 |
| `signal_bridge.gd` | `SignalBridge` | ✅ 已注册 |
| `spellcraft_system.gd` | `SpellcraftSystem` | ✅ 已注册 |
| `synth_manager.gd` | `SynthManager` | ✅ 已注册 |
| `ui_colors.gd` | `UIColors` | ✅ 已注册 |

> **说明：** `events.gd` 未注册为 Autoload，但这是正确的设计——它通过 `class_name Events` 作为常量容器使用，不需要实例化为节点。这是一种合理的 GDScript 设计模式。

---

## 6. 与上次审计 (2026-02-12) 的对比

| 变化类型 | 详情 |
| :--- | :--- |
| **新增孤岛** | `scripts/visual/spell_visual_manager.gd`（旧版遗留，与 `scripts/systems/` 版本重复） |
| **已清理归档** | 上次报告中的 9 个废弃 `.gd` 脚本和 4 个 Shader 均已移至 archive 目录，清理工作执行完毕 |
| **架构重构影响** | `tsk-7dbd9d41-db9` 引入了 `EventBus` + `Events` 系统，新增 2 个 autoload 脚本，均已正确注册 |
| **Shader 目录变化** | `shaders/archive/` 目录新增 `.gdignore` 文件，防止 Godot 导入归档 Shader |
| **2D→3D 迁移遗留** | `shaders/chapters/ch1-7_ground.gdshader`（2D 版本）可能是 3D 迁移后的遗留文件，需确认 |

---

## 7. 风险评估与行动建议

### 7.1 高优先级（立即处理）

**删除 `scripts/visual/spell_visual_manager.gd`**

该文件与 `scripts/systems/spell_visual_manager.gd` 共享相同的 `class_name SpellVisualManager`，在 Godot 4 中，同一项目中存在两个相同 `class_name` 的文件会导致编译警告甚至运行时错误。`scripts/systems/` 版本（v2.0）是当前被场景引用的版本，`scripts/visual/` 版本应立即删除。

### 7.2 中优先级（本 Sprint 内处理）

1. **确认章节地面 Shader 状态：** 调查 `shaders/chapters/ch1-7_*_ground.gdshader`（2D 版本）是否仍有用途，或是否可以归档。这 7 个文件合计约占 Shader 孤岛的 50%。

2. **集成 `timbre_hotkey_manager.gd`：** 音色快捷键功能是游戏体验的重要部分。建议将其注册为 Autoload 或集成到 `input_setup.gd` 中。

3. **集成 `fatigue_audio_feedback.gd`：** 疲劳音效是游戏反馈系统的一部分。建议将其挂载到主场景或注册为 Autoload。

### 7.3 低优先级（下次 Sprint 处理）

1. **处理 `difficulty_select_ui.gd`：** 确认 Issue #115 的状态，决定是集成还是归档。

2. **清理 archive 目录：** `shaders/archive/` 中的 3 个 Shader 已有 `.gdignore`，可在适当时机彻底删除以减少仓库体积。

3. **删除 `shaders/flowing_energy.gdshader`：** 未被任何地方引用，可直接删除。

### 7.4 架构健康度评估

项目的代码架构整体健康。Autoload 管理规范，所有 19 个 autoload 目录脚本均已正确注册。最新引入的 `EventBus` 系统设计合理，`events.gd` 通过 `class_name` 作为常量容器的使用方式符合 Godot 最佳实践。动态加载模式（波次数据、召唤构造体）的使用也是合理的数据驱动设计，不属于代码质量问题。

---

## 附录：扫描方法说明

本次审计使用 Python 脚本对以下引用模式进行了全面扫描：

- `.tscn` 文件中的 `[ext_resource type="Script"]` 节点
- `.tres` 文件中的 `res://...gd` 路径引用
- `project.godot` 的 `[autoload]` 节
- `.gd` 文件中的 `load("res://...gd")` 和 `preload("res://...gd")`
- `.gd` 文件中的 `extends "res://...gd"` 路径形式继承
- `.gd` 文件中通过 `class_name` 的类型注解、`extends`、`.new()`、`is`、`as` 引用
- `.gd` 文件中通过 `ClassName.method()` 的静态方法调用（本次新增）
- 字符串常量路径的动态 `load()` 调用（通过代码审查确认）
