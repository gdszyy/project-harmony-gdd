# Project Harmony: 2.5D 混合渲染落地方案

**版本**: 1.0
**作者**: Manus AI
**日期**: 2026-02-11

---

## 1. 概述

本文档旨在详细阐述将 `Project Harmony` 从纯 2D 渲染迁移到 **2.5D 混合渲染** 的技术实现方案。此次重构的核心目标是在不改变现有 2D 游戏逻辑（物理、碰撞、AI）的前提下，引入 3D 渲染管线的视觉优势，如原生辉光 (Glow/Bloom)、体积雾 (Volumetric Fog)、动态光照和更丰富的 3D 粒子效果，从而实现设计文档 `Art_And_VFX_Direction.md` 中定义的“抽象矢量主义”视觉风格。

## 2. 核心架构：2D 逻辑 + 3D 渲染桥接

我们没有选择将所有游戏实体（玩家、敌人、弹幕）从 `CharacterBody2D` 迁移到 `CharacterBody3D`。这种完全 3D 化的方案成本高昂，需要重写所有物理和碰撞逻辑。取而代之，我们设计并实现了一个 **“渲染桥接” (Render Bridge) 架构**。

> **核心理念**：游戏的核心逻辑和物理交互依然在 2D 世界中运行，但渲染过程被“桥接”到一个独立的 3D 场景中，最终通过 `SubViewport` 将 3D 渲染结果叠加回主游戏画面。

这种方法的优势显而易见：
- **低侵入性**：现有的大部分 2D 游戏代码（如 `player.gd`, `enemy_base.gd`）无需修改。
- **性能可控**：将计算密集型的物理模拟保留在更高效的 2D 环境中。
- **视觉飞跃**：完全解锁 Godot 4.x Forward+ 渲染管线的全部视觉能力。

## 3. 关键组件与实现细节

### 3.1. `RenderBridge3D` (render_bridge_3d.gd)

这是新架构的核心。它是一个不依附于任何特定场景节点的 `Node`，在 `main_game` 场景中被实例化。其主要职责包括：

- **构建 3D 场景**：在内部动态创建一个 `SubViewport`，并配置一个独立的 3D 世界。这个世界包含 `Camera3D` (正交投影)、`WorldEnvironment` (负责 Glow, Tonemapping 等) 和 `DirectionalLight3D`。
- **管理渲染层级**：通过一个 `SubViewportContainer` 将 3D 渲染结果绘制到一个独立的 `CanvasLayer` 上，该层位于 2D 游戏实体之上、UI 之下，实现了完美的视觉叠加。
- **实体同步**：
    - **玩家 (Player)**：为玩家创建一个 3D“渲染代理” (`_player_proxy_3d`)，它是一个 `Node3D`，包含一个 `OmniLight3D`（实现玩家发光）和 `GPUParticles3D`（实现拖尾效果）。`RenderBridge3D` 在 `_process` 循环中实时将 2D 玩家的 `global_position` 同步到 3D 代理的位置。
    - **弹幕 (Projectiles)**：实例化 `ProjectileManager3D`，并提供一个 `sync_projectiles` 接口。`main_game` 会调用此接口，将 2D `ProjectileManager` 提供的弹幕数据（位置、旋转、颜色）批量传递给 3D 渲染器。
    - **敌人 (Enemies)**：提供 `register_enemy_proxy` 和 `unregister_enemy_proxy` 方法，允许为特定敌人（如精英怪）创建带光源的 3D 代理，以增强其视觉表现。
- **坐标转换**：提供 `to_3d()` 和 `to_2d()` 方法，用于在 2D 游戏坐标和 3D 世界坐标之间进行转换。
- **视觉效果接口**：暴露 `set_glow_intensity`, `enter_boss_mode` 等方法，接收来自 `GlobalVisualEnvironment3D` 的指令，并直接操作其内部的 `WorldEnvironment`，实现全局视觉效果的统一控制。

### 3.2. `main_game.gd` 与 `main_game.tscn` 的重构

- **场景树**：`main_game.tscn` 中新增了一个名为 `RenderBridge3D` 的节点，并为其分配了新创建的 `render_bridge_3d.gd` 脚本。
- **脚本逻辑 (`main_game.gd`)**：
    - 在 `_ready` 函数中，获取 `RenderBridge3D` 节点的引用。
    - 调用 `_render_bridge.set_follow_target(_player)`，让 3D 摄像机跟随玩家。
    - 调用 `_render_bridge.create_player_proxy(_player)`，为玩家创建 3D 渲染代理。
    - 在 `_process` 循环中，新增 `_sync_projectiles_to_3d()` 函数，持续将 2D 弹幕数据同步到 3D 渲染桥。
    - 将原先由 `ChapterVisualManager` (2D) 和其他脚本直接调用的全局视觉效果（如节拍脉冲、Boss 战模式切换），统一通过 `RenderBridge3D` 的接口来实现。

### 3.3. `GlobalVisualEnvironment3D` 的角色转变

原有的 `GlobalVisualEnvironment3D` 脚本被重构，其职责大幅简化。它不再管理任何场景节点（如 Camera 或 WorldEnvironment），而是作为一个纯粹的 **数据与接口中心** (Data and Interface Hub) 的 Autoload 单例存在。

- **新职责**：
    - 维护全局 Shader 参数 (`global_time`, `beat_phase`, `chapter_color`)。
    - 响应 `GameManager` 和 `ChapterManager` 的信号（如节拍、章节切换），并计算出相应的视觉参数（如目标颜色、Glow 强度）。
    - 将视觉指令 **转发** 给 `RenderBridge3D` 执行。
    - 为所有其他脚本（如 `boss_visual_enhancer.gd`）提供一个稳定、统一的视觉控制 API，将底层实现（无论是 2D 还是 3D）完全解耦。

### 3.4. `project.godot` 配置清理

为了消除系统冲突，我们对 `project.godot` 文件中的 `[autoload]` 部分进行了清理：

- **移除了 `GlobalVisualEnvironment` (2D)**：删除了对旧的 2D 视觉管理器 `global_visual_environment.gd` 的自动加载。
- **保留了 `GlobalVisualEnvironment3D`**：保留了重构后的 3D 视觉管理器作为唯一的全局视觉接口。

这一改动确保了所有脚本都通过唯一的 `GlobalVisualEnvironment3D` 来控制视觉效果，避免了双系统并存带来的混乱和 Bug。

### 3.5. 脚本引用修复

我们审查了所有之前引用 `GlobalVisualEnvironment` 的脚本，并将它们统一指向新的 `GlobalVisualEnvironment3D`。这包括：
- `boss_visual_enhancer.gd`
- `player_visual_enhancer.gd`
- `chapter_visual_manager.gd`

现在，当这些脚本调用 `gve.enter_boss_mode()` 时，指令会通过 `GlobalVisualEnvironment3D` 转发给 `RenderBridge3D`，最终作用于 3D 渲染管线，实现了正确的视觉效果。

### 3.6. Bug 修复与功能追加

- **`global_visual_environment.gd` 缩进 Bug**：修复了旧 2D 视觉管理器中一个因函数嵌套错误导致的缩进问题。虽然该文件已被弃用，但修复它有助于保持代码库的整洁。
- **`projectile_manager.gd` 功能追加**：新增了 `get_projectile_render_data()` 方法。此方法遍历所有活跃的 2D 弹体，并返回一个包含其渲染所需数据（位置、旋转、颜色）的数组，供 `RenderBridge3D` 高效地同步到 3D 渲染层。

## 4. 实施成果与后续步骤

通过本次重构，我们成功地将项目切换到了 2.5D 混合渲染架构。现在，游戏在保留原有 2D 玩法和物理逻辑的基础上，获得了媲美原生 3D 游戏的辉光、光照和粒子效果，完全符合美术设计文档的预期。

**后续建议**：
1.  **性能测试**：在不同硬件上对当前版本进行性能分析，特别是 `SubViewport` 的开销和 3D 粒子效果的压力。
2.  **效果微调**：与美术设计师合作，基于新的渲染管线微调 `WorldEnvironment` 中的 Glow、Tonemapping 等参数，以达到最佳视觉效果。
3.  **扩展应用**：利用新的 3D 渲染层，可以轻松实现更多高级视觉效果，例如：
    - **体积雾**：在特定章节（如第六章“数字”）开启 `VolumetricFog`。
    - **3D 地面 Shader**：为 `ChapterVisualManager3D` 中的地面网格编写更复杂的 3D Shader，实现地形起伏、视差滚动等效果。
    - **高级 3D 粒子**：为 Boss 技能或特殊事件创建更华丽的 `GPUParticles3D` 特效。

---
**文档结束**
