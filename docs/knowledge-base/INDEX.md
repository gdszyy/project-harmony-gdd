# Project Harmony 知识库

**版本:** 1.0  
**最后更新:** 2026-02-12  
**状态:** 活跃

---

## 1. 概述

本知识库旨在沉淀项目开发过程中的关键技术决策、疑难问题解决方案和最佳实践，作为 `DOCUMENTATION_INDEX.md` 中宏观设计文档的补充。

知识库中的每一篇文章都应聚焦于一个具体、可复用的技术点，并提供清晰的**问题背景**、**根因分析**和**解决方案**。

## 2. 知识点索引

| 编号 | 标题 | 关键词 | 关联文件/系统 |
| :--- | :--- | :--- | :--- |
| KB-001 | [修复 Godot 4 强类型数组赋值错误](./KB-001_TypedArrayAssignment.md) | `Array[Dictionary]`, `Array`, 类型安全 | `game_manager.gd`, `chapter_data.gd` |
| KB-002 | [统一 Godot 信号参数的最佳实践](./KB-002_SignalSignatureMismatch.md) | `signal`, `emit`, `connect`, 参数不匹配 | `game_manager.gd`, `enemy_base.gd`, `test_chamber.gd` |
| KB-003 | [解决 Godot 4 中 2.5D 渲染遮挡问题](./KB-003_2.5D_Rendering_Occlusion.md) | `SubViewport`, `CanvasLayer`, `Glow`, `blend_mode` | `render_bridge_3d.gd`, `projectile_manager.gd` |
