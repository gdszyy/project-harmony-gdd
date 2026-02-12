# 孤岛代码清理与架构优化审计报告

**仓库:** `gdszyy/project-harmony-gdd`
**Issue:** [#93](https://github.com/gdszyy/project-harmony-gdd/issues/93)
**日期:** 2026-02-12

## 1. 审计概述

本次审计旨在识别并处理项目中未被直接引用（孤岛）的 GDScript 和 Shader 文件，以优化代码结构、移除废弃资产并提升项目可维护性。审计范围包括所有 `.gd` 和 `.gdshader` 文件。

通过对 Autoload、场景文件 (`.tscn`)、资源文件 (`.tres`)、动态加载 (`load`/`preload`) 以及 `class_name` 继承和实例化的全面分析，共识别出 **70 个** 初始孤岛脚本和 **51 个** Shader 文件。经过逐一甄别和分类，最终确认了需要归档的废弃脚本和 Shader。

## 2. 孤岛脚本审计与处置

下表详细列出了所有初始孤岛脚本的分析、分类、处置决策及最终执行状态。

| 文件路径 (res://) | 功能描述 | 分类 | 处置决策 | 执行状态 |
| :--- | :--- | :--- | :--- | :--- |
| **数据容器类 (Data Container)** | | | |
| `scripts/data/music_data.gd` | 核心音乐理论数据结构 | 数据容器 | **保留** (正常) | - |
| `scripts/data/codex_data.gd` | 游戏图鉴数据 | 数据容器 | **保留** (正常) | - |
| `scripts/data/chapter_data.gd` | 章节、波次、敌人配置 | 数据容器 | **保留** (正常) | - |
| `scripts/data/enemy_audio_profile.gd` | 敌人音频配置资源 | 数据容器 | **保留** (正常) | - |
| `scripts/data/summon_audio_profile.gd` | 召唤物音频配置资源 | 数据容器 | **保留** (正常) | - |
| `scripts/data/wave_data.gd` | 剧本波次数据基类 | 数据容器 | **保留** (正常) | - |
| `data/waves/ch1/*.gd` | 第一章的剧本波次数据 | 数据容器 | **保留** (正常) | - |
| `scripts/data/balance_config_v3.gd` | v3.0 数值平衡配置 | 数据容器 | **归档** (过时) | 已移动 |
| **基类 (Base Class)** | | | |
| `scripts/entities/enemy_base.gd` | 敌人实体基类 | 基类 | **保留** (正常) | - |
| `scripts/entities/enemies/boss_base.gd` | Boss 实体基类 | 基类 | **保留** (正常) | - |
| `scripts/entities/enemies/elite_base.gd` | 精英敌人实体基类 | 基类 | **保留** (正常) | - |
| `scripts/visual/visual_enhancer_base.gd` | 视觉增强器基类 | 基类 | **保留** (正常) | - |
| `scripts/entities/abstract_skeleton.gd` | 玩家角色骨架基类 | 基类 | **保留** (正常) | - |
| `scripts/visual/visual_enhancer_3d_base.gd` | 3D 视觉增强器基类 | 基类 | **归档** (未实现) | 已移动 |
| **功能性孤岛 (Functional Island)** | | | |
| `scripts/systems/collision_optimizer.gd` | 碰撞检测优化器 | 功能性 | **保留** (正常) | - |
| `scripts/systems/spatial_hash.gd` | 空间哈希网格实现 | 功能性 | **保留** (正常) | - |
| `scripts/systems/object_pool.gd` | 通用对象池 | 功能性 | **保留** (正常) | - |
| `scripts/systems/pool_manager.gd` | 对象池管理器 | 功能性 | **保留** (正常) | - |
| `scripts/systems/audio_effect_processor.gd` | 音频 DSP 效果处理器 | 功能性 | **保留** (正常) | - |
| `scripts/systems/note_synthesizer.gd` | 音符合成器 | 功能性 | **保留** (正常) | - |
| `scripts/systems/relative_pitch_resolver.gd` | 相对音高解析器 | 功能性 | **保留** (正常) | - |
| `scripts/systems/spatial_audio_controller.gd` | 空间音频控制器 | 功能性 | **保留** (正常) | - |
| `scripts/systems/enemy_audio_controller.gd` | 敌人音频控制器 | 功能性 | **保留** (正常) | - |
| `scripts/audio/audio_event.gd` | 音频事件数据结构 | 功能性 | **保留** (正常) | - |
| `scripts/audio/audio_event_queue.gd` | 音频事件量化队列 | 功能性 | **保留** (正常) | - |
| `scripts/audio/synth/adsr_envelope.gd` | ADSR 包络实现 | 功能性 | **保留** (正常) | - |
| `scripts/audio/synth/synth_voice.gd` | 合成器音源 | 功能性 | **保留** (正常) | - |
| `scripts/audio/synth/timbre_synth_presets.gd` | 音色预设 | 功能性 | **保留** (正常) | - |
| **动态加载脚本 (Dynamically Loaded)** | | | |
| `scripts/entities/modes/*.gd` | 玩家调式脚本 | 动态加载 | **保留** (正常) | - |
| `scripts/entities/enemies/chapter_enemies/*.gd` | 章节特色敌人脚本 | 动态加载 | **保留** (正常) | - |
| `scripts/entities/enemies/elites/*.gd` | 精英敌人脚本 | 动态加载 | **保留** (正常) | - |
| **召唤系统 (Summoning System)** | | | |
| `scripts/entities/summon_construct.gd` | 召唤构造体基类 | 待集成 | **保留** (正常) | - |
| `scripts/entities/harmonic_avatar_manager.gd` | 谐振化身管理器 | 待集成 | **保留** (正常) | - |
| **已归档/过时脚本 (Archived/Obsolete)** | | | |
| `scripts/ui/archive/*.gd` | 旧版 UI 脚本 | 已归档 | **保留** (在 archive) | - |
| `scripts/systems/chapter_visual_manager.gd` | 2D 章节视觉管理器 | **归档** (过时) | 已被 3D 版本替代 | 已移动 |
| `scripts/systems/global_visual_environment.gd`| 2D 全局视觉环境 | **归档** (过时) | 已被 3D 版本替代 | 已移动 |
| `scripts/ui/boss_health_bar.gd` | 旧版 Boss 血条 | **归档** (过时) | 已被 `boss_hp_bar_ui.gd` 替代 | 已移动 |
| `scripts/ui/hp_bar.gd` | 旧版玩家血条 (未使用) | **归档** (过时) | 功能已整合入 `hud.gd` | 已移动 |
| `scripts/autoload/ui_colors.gd` | 全局 UI 颜色 (未注册) | **归档** (过时) | 未在 Autoload 中注册 | 已移动 |
| `scripts/ui/ui_animation_helper.gd` | UI 动画辅助 (未注册) | **归档** (过时) | 未在 Autoload 中注册 | 已移动 |
| `scripts/visual/hit_visual_feedback.gd` | 受击视觉反馈 (未引用) | **归档** (过时) | 功能已整合入 `hit_feedback_manager.gd` | 已移动 |

## 3. 未引用 Shader 审计

对指定的 3 个 Shader 及扫描发现的其他未引用 Shader 进行检查。

| Shader 文件路径 | 功能描述 | 处置决策 | 执行状态 |
| :--- | :--- | :--- | :--- |
| `shaders/lydian_particle.gdshader` | Lydian 调式粒子效果 | **归档** (过时) | 已移动 |
| `shaders/silence_aura.gdshader` | Silence 敌人光环效果 | **归档** (过时) | 已移动 |
| `shaders/chapters/chapter_transition.gdshader` | 章节过渡效果 | **归档** (过时) | 已移动 |
| `shaders/bitcrush_ground_corruption.gdshader` | Bitcrush 蠕虫地面腐蚀效果 | **归档** (过时) | 已移动 |

## 4. 结论

审计工作成功识别并归档了 **9 个** 过时的 `.gd` 脚本和 **4 个** 未使用的 `.gdshader` 文件。大部分初始认定的“孤岛”脚本实际上通过 `class_name` 或字符串路径动态加载的方式被间接引用，属于正常代码结构的一部分。本次清理有助于减少项目冗余，明确了代码的实际依赖关系。
