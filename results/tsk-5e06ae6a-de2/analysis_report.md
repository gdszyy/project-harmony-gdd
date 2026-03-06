# Project Harmony: Codex 敌人预览 2D/3D 不一致问题分析报告

## 1. 现状评估与根因分析

### 1.1 游戏整体架构定位
通过查阅《GDD.md》和《美术与VFX方向总文档》，确认 Project Harmony 的核心玩法是 **2D 俯视角 (Top-Down) 幸存者类游戏**。
然而，在渲染架构上，游戏采用了 **混合渲染方案：3D 场景承载 2D 玩法**。
具体来说：
- 游戏逻辑和碰撞检测基于 2D（如 `CharacterBody2D`、`Area2D`）。
- 视觉呈现上，使用了 3D 场景（`Node3D`）和正交投影摄像机（`Camera3D`，Orthographic 模式）。
- 敌人和弹体的批量渲染使用了 `MultiMeshInstance3D`。

### 1.2 敌人实现现状
检查实际的敌人场景文件（如 `enemy_static.tscn`）发现，当前的敌人实现**完全是 2D 的**：
- 根节点为 `CharacterBody2D`。
- 视觉节点为 `Polygon2D`，并挂载了 2D Shader（如 `enemy_static_glitch.gdshader`）。
- 碰撞节点为 `CollisionShape2D`。

这与《美术与VFX方向总文档》中规划的“使用 `MultiMeshInstance3D` 批量渲染”存在差异。目前的敌人实现可能是早期的原型版本，尚未迁移到最终规划的 3D 批量渲染架构。

### 1.3 Codex 预览不一致的根因
在 `codex_ui.gd` 中，敌人的预览区域使用了 `SubViewport` + `Camera3D`，并通过代码硬编码生成了 3D 几何体（如 `BoxMesh`、`SphereMesh`）来模拟敌人的外观。
这种做法导致了两个严重问题：
1. **视觉不一致**：Codex 中展示的 3D 几何体与游戏内实际的 2D 多边形（`Polygon2D`）+ 2D Shader 效果完全不同。
2. **维护成本高**：每次新增或修改敌人，都需要在 `codex_ui.gd` 中手动编写对应的 3D 模型生成代码。

## 2. 修复方案建议

鉴于游戏当前的实际敌人实体（Entity）都是基于 2D 节点（`CharacterBody2D` + `Polygon2D`）实现的，为了确保 Codex 预览与游戏内实际视觉**绝对一致**，最合理且高效的修复方案是：**将 Codex 的敌人预览从 3D 改为 2D**。

### 2.1 具体实施步骤
1. **修改 Codex UI 场景**：
   - 将 `_enemy_preview_camera` 从 `Camera3D` 改为 `Camera2D`。
   - 移除 3D 环境节点（`WorldEnvironment`、`DirectionalLight3D`）。
2. **重构预览逻辑 (`codex_ui.gd`)**：
   - 废弃硬编码生成 3D 模型的代码（如 `_build_static_model` 等）。
   - 根据 `entry_id` 或 `enemy_type`，动态加载对应的敌人场景文件（`.tscn`）。
   - 实例化敌人场景，并将其添加到 `_enemy_preview_viewport` 中。
   - 禁用敌人的逻辑脚本（如移动、攻击等），仅保留视觉表现（`Polygon2D` 和 Shader）。
3. **调整摄像机与缩放**：
   - 调整 `Camera2D` 的位置和缩放，确保敌人居中且大小合适。

这种方案不仅能彻底解决视觉不一致的问题，还能大幅降低未来的维护成本，因为 Codex 将直接复用游戏内的真实资产。
