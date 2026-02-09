# Project Harmony 美术框架实施方案

**作者：** Manus AI
**版本：** 1.0
**日期：** 2026年2月10日

---

## 1. 概述与目标

本文档基于对《Art_And_VFX_Direction.md》美术方案与当前 Godot 项目代码现状的全面审计，旨在设计一个**务实、可落地、分阶段**的技术美术框架，以最小的架构重构成本，最大化地实现既定的美术愿景。

**核心目标：** 在保留现有优秀代码架构（信号驱动、逻辑/渲染分离、对象池）的基础上，通过引入新的视觉管理系统和增强现有 Shader，系统性地弥补当前代码与最终美术效果之间的差距。

## 2. 核心架构决策：2D 增强方案

经过评估，我们决定**不采纳**美术方案中建议的"3D场景+正交投影"方案，而是坚持并增强现有的纯 2D 渲染架构。理由如下：

- **成本可控：** 迁移到 3D 意味着对场景树、摄像机、所有实体（玩家、敌人、弹体）的渲染方式进行大规模重构，工作量巨大，风险不可控。
- **效果可替代：** 方案中追求的 Glow/Bloom、体积雾等效果，在 Godot 4.x 的 2D 环境中通过 `WorldEnvironment` 节点和高质量的后处理同样可以实现，且性能开销更低。
- **维护简便：** 纯 2D 架构更符合项目当前的代码习惯和开发者的心智模型。

**落地框架的核心思想：** 将所有与视觉表现强相关的逻辑从现有系统（如 `ChapterManager`, `EnemyBase`）中解耦出来，注入到专门的视觉管理器中。这些管理器将作为美术方案在代码中的直接代理，负责消费信号、管理资源、更新 Shader 参数。

## 3. 落地框架四大支柱

我们将通过引入和强化以下四个核心系统来搭建美术框架：

### 3.1. 全局视觉环境 (`GlobalVisualEnvironment`)

这是整个美术框架的基石，一个全新的 Autoload 单例，负责管理全局的视觉状态。

- **节点结构：** `GlobalVisualEnvironment (CanvasLayer)` -> `WorldEnvironment` -> `Environment`
- **核心职责：**
    1. **后处理管理：** 统一控制 Glow, Bloom, Tonemap, SDFGI, SSAO 等后处理效果的开关和参数。
    2. **章节色彩过渡：** 监听 `ChapterManager` 的 `color_theme_changed` 信号，平滑地在 `Environment` 的 `adjustment_color_correction` 中插值色彩查找表 (LUT)。
    3. **全局 Shader 参数：** 提供一个全局 Uniforms 集合（如 `GLOBAL.time`, `GLOBAL.beat`），供所有 Shader 访问。

### 3.2. 章节视觉管理器 (`ChapterVisualManager`)

一个全新的场景节点，作为 `main_game.tscn` 的子节点，专门负责实现章节间的视觉差异化。

- **节点结构：** `ChapterVisualManager (Node2D)`
- **核心职责：**
    1. **地面 Shader 管理：** 监听 `ChapterManager` 的 `chapter_started` 信号，根据章节配置动态加载并切换地面的 `ShaderMaterial`。
    2. **环境特效管理：** 负责实例化和管理章节特有的持续性环境特效（如第四章的齿轮、第七章的数据流）。
    3. **特殊机制视觉化：** 监听 `ChapterManager` 的 `special_mechanic_activated` 信号，激活对应的视觉效果（如摇摆力场的聚光灯、波形战争的比特破碎区）。

### 3.3. 实体视觉增强器 (`EntityVisualEnhancer`)

这不是一个单一的管理器，而是一套**组件化**的视觉增强方案，附加到现有的实体上（玩家、敌人、Boss）。

- **实现方式：** 创建 `VisualEnhancerBase.gd` 脚本，为不同实体类型派生出子类（如 `PlayerVisualEnhancer`, `EnemyVisualEnhancer`）。
- **核心职责：**
    1. **解耦视觉逻辑：** 将 `enemy_base.gd` 中所有 `_update_visual` 的逻辑（约100行）迁移到 `EnemyVisualEnhancer` 中。
    2. **音色视觉实现：** 监听实体的音色属性变化，并将对应的视觉参数（颜色、纹理、粒子效果）传递给 Shader。
    3. **GPU 粒子集成：** 将 `player_visual_enhanced.gd` 中的 `CPUParticles2D` 替换为 `GPUParticles2D`，并为敌人死亡、Boss 技能等关键时刻创建独立的 `GPUParticles2D` 特效场景。

### 3.4. UI 主题与风格系统 (`Theme & StyleBox`)

完善项目的 UI 视觉体系，使其与游戏的核心美术风格保持一致。

- **实现方式：**
    1. **创建 `GlobalTheme.tres`：** 定义全局的字体、颜色、间距。
    2. **创建 `StyleBox` 集合：** 为按钮、面板、血条等创建一系列 `StyleBoxFlat` 和 `StyleBoxTexture` 资源，实现故障艺术和矢量风格。
    3. **重构 UI 场景：** 将 `hud.gd` 等脚本中硬编码的 UI 样式替换为对 `Theme` 资源的引用。

## 4. 分步实施路线图

| 阶段 | 任务 | 目标 | 涉及文件/系统 | 预估工时 |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **环境与后处理** | 快速提升整体视觉品质，奠定渲染基调 | `GlobalVisualEnvironment.gd`, `main_game.tscn` | 4小时 |
| **2** | **章节视觉差异化** | 实现七大章节的独立美术风格 | `ChapterVisualManager.gd`, 6个新地面Shader | 12小时 |
| **3** | **实体视觉解耦** | 重构敌人和玩家的视觉代码，为后续增强做准备 | `EnemyVisualEnhancer.gd`, `enemy_base.gd`, `player_visual_enhanced.gd` | 8小时 |
| **4** | **音色与粒子增强** | 引入音色视觉和 GPU 粒子，丰富特效层次 | `projectile_glow.gdshader`, `GPUParticles2D` 场景 | 10小时 |
| **5** | **UI 主题化** | 统一 UI 风格，提升沉浸感 | `GlobalTheme.tres`, `StyleBox` 资源, `hud.gd` | 6小时 |

---

## 5. 详细技术方案

### 5.1. GlobalVisualEnvironment 实现细节

1. **创建 `GlobalVisualEnvironment.gd`** 并将其注册为 Autoload。
2. 在 `_ready()` 中，创建 `WorldEnvironment` 节点并设置 `environment` 属性。
3. **配置 `Environment`**：
   - **Glow:** `enabled = true`, `hdr_threshold = 1.0`, `hdr_scale = 2.0`, `glow_map_strength = 0.8`
   - **Tonemap:** `mode = TONEMAP_ACES`
   - **Adjustments:** `enabled = true`
4. **实现 `_on_color_theme_changed` 函数：**
   - 加载两个章节对应的 LUT 纹理。
   - 使用 `Tween` 在 `material.set_shader_parameter("color_correction_texture", ...)` 之间进行平滑过渡（需要自定义一个混合 LUT 的 Shader）。

### 5.2. ChapterVisualManager 实现细节

1. **创建 `ChapterVisualManager.tscn`** 并将其作为实例添加到 `main_game.tscn`。
2. **在 `_ready()` 中，监听 `ChapterManager` 的信号。**
3. **实现 `_on_chapter_started(chapter_config)`：**
   - `var ground_shader = load(chapter_config.ground_shader_path)`
   - `$Ground.material = ground_shader`
   - 动态实例化章节环境特效场景 `load(chapter_config.env_vfx_path).instantiate()`
4. **为每个章节创建地面 Shader**（克拉尼图形、教堂地面、齿轮地面等），并将其路径添加到 `ChapterData`。

### 5.3. EntityVisualEnhancer 实现细节

1. **创建 `EnemyVisualEnhancer.gd`**。
2. 将 `enemy_base.gd` 中 `_update_visual` 的所有代码剪切到 `EnemyVisualEnhancer._process()` 中。
3. 在 `enemy_base.gd` 中，将 `_update_visual(delta)` 替换为 `$VisualEnhancer.update_visual(delta)`。
4. 在 `EnemyVisualEnhancer` 中添加 `set_timbre(timbre_type)` 方法，该方法根据音色类型修改 Shader 的 `uniform` 参数（如 `base_tint`, `particle_color`）。

