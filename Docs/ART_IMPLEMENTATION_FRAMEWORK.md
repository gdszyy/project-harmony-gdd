# Project Harmony — 美术方案落地框架

**作者：** Manus AI
**版本：** 2.0
**日期：** 2026年2月10日
**状态：** 技术评审稿

---

## 目录

1. [执行摘要](#1-执行摘要)
2. [现有代码全面审计](#2-现有代码全面审计)
3. [美术方案与代码现状差距分析](#3-美术方案与代码现状差距分析)
4. [核心架构决策](#4-核心架构决策)
5. [落地框架总体架构](#5-落地框架总体架构)
6. [支柱一：全局视觉环境系统](#6-支柱一全局视觉环境系统)
7. [支柱二：章节视觉管理器](#7-支柱二章节视觉管理器)
8. [支柱三：实体视觉增强器](#8-支柱三实体视觉增强器)
9. [支柱四：UI 主题与风格系统](#9-支柱四ui-主题与风格系统)
10. [新增 Shader 实现方案](#10-新增-shader-实现方案)
11. [现有 Shader 增强方案](#11-现有-shader-增强方案)
12. [GPUParticles2D 特效方案](#12-gpuparticles2d-特效方案)
13. [场景树重构方案](#13-场景树重构方案)
14. [分步实施路线图](#14-分步实施路线图)
15. [风险评估与缓解策略](#15-风险评估与缓解策略)

---

## 1. 执行摘要

本文档是将《Art_And_VFX_Direction.md》中定义的美术愿景转化为可执行代码的**桥梁文档**。它基于对项目全部 103 个 GDScript 文件（42,804 行）、15 个 Shader 文件（1,161 行）和 13 个场景文件的逐一审计，系统性地识别了美术方案与代码现状之间的 7 个关键差距，并设计了一个以"四大支柱"为核心的落地框架。

**核心结论：** 项目当前的代码基础**远比预期成熟**。弹体渲染的 MultiMesh 架构、信号驱动的系统解耦、完善的对象池基础设施，以及已有的 15 个 Shader，为美术方案的落地提供了坚实的技术基座。最大的差距不在于底层能力的缺失，而在于**视觉管理层的缺位**——现有系统已经发出了正确的信号（如 `chapter_started`, `color_theme_changed`），但没有任何系统在消费这些信号并将其转化为视觉变化。

**核心决策：** 坚持并增强现有的纯 2D 渲染架构，不迁移到 3D。通过引入 `WorldEnvironment` 后处理、新增 6 个章节地面 Shader、创建 3 个新的视觉管理器，在 2D 框架下实现美术方案中 90% 以上的视觉效果。

---

## 2. 现有代码全面审计

### 2.1. 项目规模概览

| 维度 | 数据 | 评价 |
| :--- | :--- | :--- |
| GDScript 文件数 | 103 | 中大型项目，系统覆盖全面 |
| GDScript 总行数 | 42,804 | 代码量充实，非骨架项目 |
| Shader 文件数 | 15 | 覆盖了核心视觉需求 |
| Shader 总行数 | 1,161 | 平均每个 Shader 约 77 行，复杂度适中 |
| 场景文件数 | 13 | 基础场景齐全，但缺少 VFX 专用场景 |
| Autoload 管理器数 | 14 | 架构成熟，系统间解耦良好 |
| 主题资源 | 1（空） | UI 主题化尚未开始 |

### 2.2. 美术相关系统成熟度评估

以下表格对项目中所有与视觉表现直接相关的系统进行逐一评估，采用五星制评分，其中五星表示可直接使用，一星表示需要重写。

| 系统 | 文件 | 行数 | 成熟度 | 关键能力 | 主要不足 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **弹体渲染** | `projectile_manager.gd` | 1,200+ | ★★★★☆ | MultiMeshInstance2D 批量渲染；逻辑/渲染分离；拖尾系统；15 种法术形态视觉 | 未与音色系统关联；拖尾使用 Line2D 而非 Shader |
| **法术视觉** | `spell_visual_manager.gd` | 860 | ★★★★☆ | 覆盖全部 15 种法术形态；施法光环；修饰符视觉；浮动文字 | 全部使用 Polygon2D+Tween 模拟粒子，无真正的粒子系统 |
| **敌人视觉** | `enemy_base.gd` | 529 | ★★★☆☆ | 量化步进移动；故障视觉（HP 关联）；节拍脉冲；受击闪白；死亡动画 | 视觉逻辑与游戏逻辑耦合；无章节差异化 |
| **死亡 VFX** | `death_vfx_manager.gd` | ~400 | ★★★☆☆ | 对象池管理（50 碎片）；5 种敌人差异化特效；音符粒子；Boss 多阶段死亡 | 碎片使用 Polygon2D 而非 GPU 粒子 |
| **受击反馈** | `hit_feedback_manager.gd` | 254 | ★★★★☆ | 屏幕抖动；方向性暗角；低血量脉冲；Hitstop | 完善度高，几乎无需修改 |
| **全屏 VFX** | `vfx_manager.gd` | ~300 | ★★☆☆☆ | 冲击波；调式边框；全屏闪光；Boss 阶段转换 | 缺少章节过渡视觉、Boss 出场动画、环境氛围效果 |
| **玩家视觉** | `player_visual_enhanced.gd` | ~200 | ★★★☆☆ | 正十二面体核心+金环；节拍脉冲；CPUParticles2D | 使用 CPU 粒子而非 GPU 粒子；无音色视觉 |
| **章节管理** | `chapter_manager.gd` | 677 | ★★★☆☆ | 完整状态机；BPM 过渡；色彩主题信号；特殊机制管理 | **信号已定义但无消费者**——这是最关键的差距 |
| **对象池** | `object_pool.gd` | 248 | ★★★★★ | 通用池；预分配+弹性扩容；统计监控 | 无需修改，直接复用 |
| **HUD** | `hud.gd` | ~300 | ★★☆☆☆ | 血条、疲劳度、BPM、施法槽、伤害数字 | 全部硬编码样式，无 Theme 引用；GlobalTheme.tres 为空 |

### 2.3. 现有 Shader 清单与评估

| Shader 文件 | 行数 | 类型 | 当前使用者 | 质量评估 | 增强需求 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `projectile_glow.gdshader` | 31 | canvas_item | MultiMeshInstance2D | ★★★☆☆ 基础发光 | 需增加音色参数、弹体形状变体 |
| `enemy_glitch.gdshader` | 105 | canvas_item | 所有敌人 Polygon2D | ★★★★☆ 完善 | 可增加章节特化参数 |
| `pulsing_grid.gdshader` | 47 | canvas_item | 地面 Ground 节点 | ★★★☆☆ 单一 | 需为每章创建变体 |
| `sacred_geometry.gdshader` | 53 | spatial | 玩家核心 | ★★★☆☆ 基础 | 需增加音色视觉修饰 |
| `event_horizon.gdshader` | 28 | canvas_item | 竞技场边界 | ★★★☆☆ 基础 | 需增加章节色彩参数 |
| `fatigue_filter.gdshader` | 86 | canvas_item | 全屏疲劳滤镜 | ★★★★☆ 完善 | 无需修改 |
| `hit_feedback.gdshader` | 101 | canvas_item | 全屏受击反馈 | ★★★★☆ 完善 | 无需修改 |
| `progression_shockwave.gdshader` | 39 | canvas_item | 和弦冲击波 | ★★★☆☆ 基础 | 可增加和弦功能色彩 |
| `mode_border.gdshader` | 59 | canvas_item | 调式切换边框 | ★★★☆☆ 基础 | 可增加更多调式风格 |
| `boss_hp_bar.gdshader` | 254 | canvas_item | Boss 血条 | ★★★★★ 精致 | 无需修改 |
| `silence_aura.gdshader` | 69 | canvas_item | Silence 敌人光环 | ★★★★☆ 完善 | 无需修改 |
| `crystallized_silence.gdshader` | 163 | canvas_item | 固化静默障碍 | ★★★★☆ 完善 | 无需修改 |
| `bitcrush.gdshader` | 59 | canvas_item | 第七章比特破碎 | ★★★☆☆ 基础 | 可增加更多数字损坏效果 |
| `flowing_energy.gdshader` | 37 | canvas_item | 流动能量效果 | ★★★☆☆ 基础 | 无需修改 |
| `scanline_glow.gdshader` | 30 | canvas_item | 扫描线发光 | ★★★☆☆ 基础 | 无需修改 |

### 2.4. 现有架构优势（必须保留）

项目代码中有几个架构决策非常出色，必须在落地框架中予以保留和强化。

**信号驱动架构。** 系统间通过 Godot 的信号机制解耦，`ChapterManager` 已经定义了 `chapter_started`, `color_theme_changed`, `transition_progress_updated`, `special_mechanic_activated` 等信号，这意味着新的视觉管理器只需"插入"信号链即可工作，无需修改现有系统的任何代码。

**逻辑/渲染分离。** `ProjectileManager` 已经实现了这一模式——弹体的碰撞检测、伤害计算在逻辑层完成，渲染更新在 `_update_rendering()` 中独立处理。这一模式应推广到敌人系统和玩家系统。

**对象池基础设施。** `ObjectPool` 类和 `PoolManager` 单例已经就绪，支持预分配、弹性扩容和统计监控。新增的 GPU 粒子特效和章节环境元素都可以直接使用这一基础设施。

---

## 3. 美术方案与代码现状差距分析

经过逐项对比，我们识别出以下 7 个关键差距，按影响程度从高到低排列：

### 差距一：视觉管理层缺位（影响度：★★★★★）

这是最关键的差距。`ChapterManager` 已经在正确的时机发出了正确的信号（如 `chapter_started`, `color_theme_changed`），但整个项目中**没有任何系统在消费这些信号并将其转化为视觉变化**。这意味着即使章节切换了，地面 Shader、环境色彩、敌人外观都不会发生任何变化。

**根因分析：** 项目的开发重心一直在游戏逻辑层（音乐系统、法术系统、敌人 AI），视觉表现层被推迟了。信号接口已经预留，但消费者尚未实现。

**解决方案：** 创建 `ChapterVisualManager` 和 `GlobalVisualEnvironment` 两个新系统，作为信号的消费者。

### 差距二：后处理效果完全缺失（影响度：★★★★★）

项目中没有 `WorldEnvironment` 节点，没有 `Environment` 资源，没有任何后处理效果。这意味着即使 Shader 输出了 HDR 颜色值（如 `projectile_glow.gdshader` 的 `blend_add` 模式），也不会产生 Bloom/Glow 效果——弹体只是简单地变亮，而不会产生柔和的光晕扩散。

**根因分析：** Godot 4.x 的 2D 后处理需要通过 `WorldEnvironment` 节点配合 `Environment` 资源来实现，这一步骤在项目初期被跳过了。

**解决方案：** 在 `GlobalVisualEnvironment` 中创建并配置 `WorldEnvironment`，启用 Glow、Tonemap 和 Color Adjustment。

### 差距三：章节美术差异化缺失（影响度：★★★★☆）

美术方案为 7 个章节设计了独立的视觉主题（克拉尼图形、教堂玫瑰窗、巴洛克齿轮等），但代码中只有 1 个 `pulsing_grid.gdshader` 被所有章节共用。`ChapterData` 中虽然定义了 `color_theme`，但没有 `ground_shader_path` 或 `env_vfx_path` 等视觉资源路径。

**解决方案：** 为每个章节创建独立的地面 Shader，并在 `ChapterData` 中添加视觉资源配置。

### 差距四：粒子系统原始（影响度：★★★☆☆）

项目中唯一使用真正粒子系统的地方是 `player_visual_enhanced.gd` 中的 `CPUParticles2D`。其余所有"粒子效果"（法术施放、敌人死亡、冲击波碎片）都是通过 `Polygon2D` + `Tween` 动画模拟的。这种方案在功能上可行，但在视觉丰富度和性能上都不如 `GPUParticles2D`。

**解决方案：** 为关键视觉时刻（施法爆发、敌人死亡、Boss 技能）创建预制的 `GPUParticles2D` 场景，通过对象池管理。

### 差距五：音色系统视觉未实现（影响度：★★★☆☆）

`TimbreSystem` 定义了 4 种音色系别（弦乐、管乐、打击、键盘），每种都应有独特的视觉表现（弹体形状、颜色偏移、粒子效果）。但当前弹体的颜色完全由法术形态（`SpellForm`）决定，与音色系统没有任何关联。

**解决方案：** 在 `ProjectileManager` 的渲染更新中加入音色参数，并扩展 `projectile_glow.gdshader` 支持音色视觉修饰。

### 差距六：UI 主题化缺失（影响度：★★☆☆☆）

`GlobalTheme.tres` 是一个空文件。所有 UI 元素的样式都在 GDScript 中通过 `add_theme_*_override()` 硬编码。这导致 UI 风格不统一，且难以进行全局调整。

**解决方案：** 创建完整的 `Theme` 资源体系，包含字体、颜色、StyleBox 定义。

### 差距七：渲染架构差异（影响度：★★☆☆☆）

美术方案建议使用"3D 场景 + 正交投影摄像机"以利用 Godot 的 3D 后处理管线。但项目当前是纯 2D 架构（`Node2D`, `Camera2D`, `CharacterBody2D`）。

**解决方案：** 不迁移到 3D（详见第 4 节的决策论证），而是在 2D 框架下通过 `WorldEnvironment` 实现等效的后处理效果。

---

## 4. 核心架构决策

### 4.1. 决策：坚持 2D 增强方案，不迁移到 3D

经过审慎评估，我们做出以下决策：**不采纳**美术方案中建议的"3D 场景 + 正交投影"方案，而是坚持并增强现有的纯 2D 渲染架构。

| 评估维度 | 3D 迁移方案 | 2D 增强方案（选定） |
| :--- | :--- | :--- |
| **重构成本** | 极高：需重写场景树、摄像机、所有实体的渲染方式 | 低：仅需添加新节点和新 Shader |
| **风险** | 高：可能引入大量回归 Bug | 低：新系统通过信号插入，不修改现有代码 |
| **Glow/Bloom** | 原生支持 | 通过 `WorldEnvironment` 的 `glow` 属性支持 [1] |
| **体积雾** | 原生支持 | 不支持，但可通过全屏 Shader 模拟 |
| **性能** | 3D 管线开销更大 | 2D 管线更轻量 |
| **开发者心智模型** | 需要学习 3D 渲染概念 | 与现有代码习惯一致 |

> **关键发现：** Godot 4.x 的 `WorldEnvironment` 节点在 2D 场景中同样生效 [1]。这意味着 Glow、Tonemap、Color Adjustment 等后处理效果无需迁移到 3D 即可使用。这一发现使得 2D 增强方案的可行性大幅提升。

### 4.2. 决策：视觉逻辑解耦而非重写

对于敌人视觉（`enemy_base.gd` 中约 100 行视觉代码）和玩家视觉（`player_visual_enhanced.gd`），我们选择**解耦**而非**重写**。具体来说，将视觉逻辑从实体脚本中提取到独立的"视觉增强器"组件中，但保留原有的视觉效果逻辑——它们已经经过验证且效果良好。

### 4.3. 决策：渐进式 GPU 粒子替换

不一次性将所有 Polygon2D+Tween 粒子替换为 GPUParticles2D，而是优先替换**视觉影响最大**的 3 个场景：施法爆发、敌人死亡爆炸、Boss 阶段转换。其余效果保留现有实现，在后续迭代中逐步替换。

---

## 5. 落地框架总体架构

### 5.1. 架构概览

落地框架由**四大支柱**组成，每个支柱解决一个或多个差距：

```
┌─────────────────────────────────────────────────────────┐
│                    main_game.tscn                        │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │         GlobalVisualEnvironment (Autoload)       │    │
│  │  ┌──────────────┐  ┌──────────────────────┐     │    │
│  │  │WorldEnviron- │  │ Global Shader Params │     │    │
│  │  │ment (Glow,   │  │ (time, beat, chapter)│     │    │
│  │  │ Tonemap)     │  │                      │     │    │
│  │  └──────────────┘  └──────────────────────┘     │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │         ChapterVisualManager (Node2D)            │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────┐    │    │
│  │  │ Ground   │ │ EnvVFX   │ │ Transition   │    │    │
│  │  │ Shader   │ │ Layer    │ │ Animator     │    │    │
│  │  │ Switcher │ │          │ │              │    │    │
│  │  └──────────┘ └──────────┘ └──────────────┘    │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌───────────────┐  ┌───────────────────────────┐      │
│  │    Player      │  │    Enemies (pooled)        │      │
│  │  ┌───────────┐│  │  ┌─────────────────────┐  │      │
│  │  │PlayerVisual││  │  │EnemyVisualEnhancer  │  │      │
│  │  │Enhancer   ││  │  │(component per enemy) │  │      │
│  │  └───────────┘│  │  └─────────────────────┘  │      │
│  └───────────────┘  └───────────────────────────┘      │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │              HUD (CanvasLayer)                    │    │
│  │         GlobalTheme.tres + StyleBoxes             │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### 5.2. 信号流图

以下展示了新系统如何通过信号与现有系统集成：

```
ChapterManager ──chapter_started──────→ ChapterVisualManager
               ──color_theme_changed──→ GlobalVisualEnvironment
               ──transition_progress──→ ChapterVisualManager
               ──special_mechanic_*───→ ChapterVisualManager
               ──boss_spawned─────────→ VFXManager (增强)
               ──bpm_changed──────────→ GlobalVisualEnvironment

GameManager ───beat_tick──────────────→ GlobalVisualEnvironment
            ───player_hp_changed──────→ HitFeedbackManager (已有)

SpellcraftSystem ──spell_cast─────────→ SpellVisualManager (已有)
                 ──chord_cast─────────→ SpellVisualManager (已有)

TimbreSystem ──timbre_changed─────────→ ProjectileManager (增强)
             ──timbre_changed─────────→ PlayerVisualEnhancer (新增)
```

### 5.3. 文件结构规划

```
godot_project/
├── scripts/
│   ├── systems/
│   │   ├── global_visual_environment.gd   ← 新增 (Autoload)
│   │   ├── chapter_visual_manager.gd      ← 新增
│   │   └── ... (现有系统不变)
│   ├── visual/
│   │   ├── visual_enhancer_base.gd        ← 新增
│   │   ├── player_visual_enhancer.gd      ← 新增
│   │   ├── enemy_visual_enhancer.gd       ← 新增
│   │   └── boss_visual_enhancer.gd        ← 新增
│   └── ...
├── shaders/
│   ├── chapters/
│   │   ├── ch1_chladni_ground.gdshader    ← 新增
│   │   ├── ch2_cathedral_ground.gdshader  ← 新增
│   │   ├── ch3_baroque_ground.gdshader    ← 新增
│   │   ├── ch4_rococo_ground.gdshader     ← 新增
│   │   ├── ch5_romantic_ground.gdshader   ← 新增
│   │   ├── ch6_jazz_ground.gdshader       ← 新增
│   │   ├── ch7_digital_ground.gdshader    ← 新增
│   │   └── chapter_transition.gdshader    ← 新增
│   ├── post_processing/
│   │   └── color_grade.gdshader           ← 新增
│   └── ... (现有 Shader 不变)
├── scenes/
│   ├── vfx/
│   │   ├── cast_burst_particles.tscn      ← 新增
│   │   ├── death_explosion_particles.tscn ← 新增
│   │   ├── boss_phase_particles.tscn      ← 新增
│   │   └── chapter_transition.tscn        ← 新增
│   └── ...
├── themes/
│   ├── GlobalTheme.tres                   ← 重写
│   ├── hud_panel.tres                     ← 新增
│   └── stylebox/
│       ├── panel_dark.tres                ← 新增
│       ├── button_glow.tres               ← 新增
│       └── progress_bar_resonance.tres    ← 新增
└── resources/
    └── environments/
        └── default_env.tres               ← 新增
```

---

## 6. 支柱一：全局视觉环境系统

### 6.1. 系统定位

`GlobalVisualEnvironment` 是整个美术框架的基石。它作为 Autoload 单例运行，负责管理所有全局性的视觉状态——后处理效果、全局 Shader 参数、章节色彩过渡。它的存在使得项目中的每一个 Shader 都能访问到统一的全局状态（如当前节拍相位、章节色彩），从而实现"整个世界随音乐呼吸"的核心美学目标。

### 6.2. 完整实现代码

```gdscript
## global_visual_environment.gd
## 全局视觉环境管理器 (Autoload)
##
## 职责：
## 1. 管理 WorldEnvironment 后处理（Glow, Tonemap, Adjustments）
## 2. 维护全局 Shader 参数（时间、节拍、章节色彩）
## 3. 实现章节间的色彩平滑过渡
## 4. 提供节拍驱动的全局视觉脉冲
extends Node

# ============================================================
# 配置
# ============================================================

## Glow 配置
const GLOW_ENABLED: bool = true
const GLOW_HDR_THRESHOLD: float = 0.8
const GLOW_HDR_SCALE: float = 2.5
const GLOW_INTENSITY: float = 0.8
const GLOW_BLOOM: float = 0.1

## 节拍脉冲配置
const BEAT_GLOW_BOOST: float = 0.3        ## 节拍时刻的 Glow 增量
const BEAT_GLOW_DECAY: float = 4.0        ## Glow 增量衰减速率

## 色彩过渡配置
const COLOR_TRANSITION_DURATION: float = 3.0  ## 色彩过渡时长（秒）

# ============================================================
# 节点引用
# ============================================================
var _world_env: WorldEnvironment = null
var _environment: Environment = null

# ============================================================
# 状态
# ============================================================
var _beat_glow_extra: float = 0.0          ## 节拍驱动的额外 Glow
var _current_chapter_color: Color = Color(0.0, 1.0, 0.8)  ## 当前章节主色
var _target_chapter_color: Color = Color(0.0, 1.0, 0.8)   ## 目标章节主色
var _color_transition_progress: float = 1.0  ## 0.0 = 开始过渡, 1.0 = 过渡完成
var _global_time: float = 0.0
var _beat_phase: float = 0.0               ## 0.0 ~ 1.0，当前节拍相位

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
    _create_world_environment()
    _connect_signals()
    _update_global_shader_params()

func _process(delta: float) -> void:
    _global_time += delta

    # 节拍 Glow 衰减
    if _beat_glow_extra > 0.001:
        _beat_glow_extra = lerp(_beat_glow_extra, 0.0, BEAT_GLOW_DECAY * delta)
    else:
        _beat_glow_extra = 0.0

    # 色彩过渡
    if _color_transition_progress < 1.0:
        _color_transition_progress += delta / COLOR_TRANSITION_DURATION
        _color_transition_progress = minf(_color_transition_progress, 1.0)
        _current_chapter_color = _current_chapter_color.lerp(
            _target_chapter_color,
            _ease_in_out(_color_transition_progress)
        )

    # 更新 Glow
    if _environment and GLOW_ENABLED:
        _environment.glow_intensity = GLOW_INTENSITY + _beat_glow_extra

    # 更新全局 Shader 参数
    _update_global_shader_params()

# ============================================================
# 初始化
# ============================================================

func _create_world_environment() -> void:
    _environment = Environment.new()

    # 背景
    _environment.background_mode = Environment.BG_COLOR
    _environment.background_color = Color(0.01, 0.01, 0.02)

    # Glow / Bloom
    _environment.glow_enabled = GLOW_ENABLED
    _environment.glow_hdr_threshold = GLOW_HDR_THRESHOLD
    _environment.glow_hdr_scale = GLOW_HDR_SCALE
    _environment.glow_intensity = GLOW_INTENSITY
    _environment.glow_bloom = GLOW_BLOOM
    _environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

    # Tonemap
    _environment.tonemap_mode = Environment.TONE_MAP_ACES

    # Adjustments
    _environment.adjustment_enabled = true
    _environment.adjustment_brightness = 1.0
    _environment.adjustment_contrast = 1.1
    _environment.adjustment_saturation = 1.15

    # 创建 WorldEnvironment 节点
    _world_env = WorldEnvironment.new()
    _world_env.environment = _environment
    add_child(_world_env)

func _connect_signals() -> void:
    # 连接章节管理器信号
    if ChapterManager.has_signal("chapter_started"):
        ChapterManager.chapter_started.connect(_on_chapter_started)
    if ChapterManager.has_signal("color_theme_changed"):
        ChapterManager.color_theme_changed.connect(_on_color_theme_changed)

    # 连接节拍信号
    if GameManager.has_signal("beat_tick"):
        GameManager.beat_tick.connect(_on_beat_tick)

# ============================================================
# 全局 Shader 参数
# ============================================================

func _update_global_shader_params() -> void:
    # 使用 Godot 4.x 的全局 Shader 参数
    RenderingServer.global_shader_parameter_set("global_time", _global_time)
    RenderingServer.global_shader_parameter_set("beat_phase", _beat_phase)
    RenderingServer.global_shader_parameter_set(
        "chapter_color",
        Vector3(_current_chapter_color.r, _current_chapter_color.g, _current_chapter_color.b)
    )
    RenderingServer.global_shader_parameter_set("beat_glow_extra", _beat_glow_extra)

# ============================================================
# 信号回调
# ============================================================

func _on_chapter_started(chapter: int, _chapter_name: String) -> void:
    var config := ChapterData.get_chapter_config(chapter)
    var new_color: Color = config.get("color_theme", Color(0.0, 1.0, 0.8))
    _start_color_transition(new_color)

    # 调整环境亮度和对比度
    var brightness: float = config.get("env_brightness", 1.0)
    var contrast: float = config.get("env_contrast", 1.1)
    if _environment:
        var tween := create_tween()
        tween.set_parallel(true)
        tween.tween_property(_environment, "adjustment_brightness", brightness, 2.0)
        tween.tween_property(_environment, "adjustment_contrast", contrast, 2.0)

func _on_color_theme_changed(from_color: Color, to_color: Color, _progress: float) -> void:
    _target_chapter_color = to_color
    if _color_transition_progress >= 1.0:
        _current_chapter_color = from_color
        _color_transition_progress = 0.0

func _on_beat_tick() -> void:
    _beat_glow_extra = BEAT_GLOW_BOOST
    _beat_phase = 0.0

    # 节拍相位将在 _process 中通过时间推进自动更新
    # 这里只需要重置相位

# ============================================================
# 公共接口
# ============================================================

## 获取当前章节主色
func get_chapter_color() -> Color:
    return _current_chapter_color

## 获取当前节拍相位 (0.0 ~ 1.0)
func get_beat_phase() -> float:
    return _beat_phase

## 手动设置 Glow 强度（用于 Boss 战等特殊场景）
func set_glow_override(intensity: float, duration: float = 0.5) -> void:
    if _environment:
        var tween := create_tween()
        tween.tween_property(_environment, "glow_intensity", intensity, duration)

## 恢复默认 Glow
func reset_glow(duration: float = 1.0) -> void:
    if _environment:
        var tween := create_tween()
        tween.tween_property(_environment, "glow_intensity", GLOW_INTENSITY, duration)

## Boss 战模式：增强对比度和饱和度
func enter_boss_mode() -> void:
    if _environment:
        var tween := create_tween()
        tween.set_parallel(true)
        tween.tween_property(_environment, "adjustment_contrast", 1.3, 1.0)
        tween.tween_property(_environment, "adjustment_saturation", 1.3, 1.0)
        tween.tween_property(_environment, "glow_hdr_scale", 3.5, 1.0)

func exit_boss_mode() -> void:
    if _environment:
        var tween := create_tween()
        tween.set_parallel(true)
        tween.tween_property(_environment, "adjustment_contrast", 1.1, 2.0)
        tween.tween_property(_environment, "adjustment_saturation", 1.15, 2.0)
        tween.tween_property(_environment, "glow_hdr_scale", GLOW_HDR_SCALE, 2.0)

# ============================================================
# 工具函数
# ============================================================

func _start_color_transition(target: Color) -> void:
    _target_chapter_color = target
    _color_transition_progress = 0.0

func _ease_in_out(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)  # Smoothstep
```

### 6.3. 全局 Shader 参数注册

在 `project.godot` 中需要注册全局 Shader 参数，以便所有 Shader 都能访问：

```ini
[shader_globals]
global_time = { "type": "float", "value": 0.0 }
beat_phase = { "type": "float", "value": 0.0 }
chapter_color = { "type": "vec3", "value": "Vector3(0, 1, 0.8)" }
beat_glow_extra = { "type": "float", "value": 0.0 }
```

在 Shader 中使用：

```glsl
// 任何 Shader 都可以访问这些全局参数
global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;
global uniform float beat_glow_extra;
```

---

## 7. 支柱二：章节视觉管理器

### 7.1. 系统定位

`ChapterVisualManager` 是实现"七大章节独立美术风格"的核心系统。它作为 `main_game.tscn` 的子节点运行，监听 `ChapterManager` 的信号，动态切换地面 Shader、管理环境特效、实现章节过渡动画。

### 7.2. 完整实现代码

```gdscript
## chapter_visual_manager.gd
## 章节视觉管理器
##
## 职责：
## 1. 根据章节配置动态切换地面 Shader
## 2. 管理章节特有的持续性环境特效
## 3. 实现章节间的视觉过渡动画
## 4. 响应特殊机制的视觉化需求
extends Node2D

# ============================================================
# 配置
# ============================================================

## 章节地面 Shader 路径映射
const CHAPTER_GROUND_SHADERS: Dictionary = {
    0: "res://shaders/chapters/ch1_chladni_ground.gdshader",
    1: "res://shaders/chapters/ch2_cathedral_ground.gdshader",
    2: "res://shaders/chapters/ch3_baroque_ground.gdshader",
    3: "res://shaders/chapters/ch4_rococo_ground.gdshader",
    4: "res://shaders/chapters/ch5_romantic_ground.gdshader",
    5: "res://shaders/chapters/ch6_jazz_ground.gdshader",
    6: "res://shaders/chapters/ch7_digital_ground.gdshader",
}

## 章节色彩方案
const CHAPTER_COLORS: Dictionary = {
    0: { "primary": Color(0.9, 0.85, 0.6), "secondary": Color(0.3, 0.25, 0.15), "accent": Color(1.0, 0.95, 0.7) },
    1: { "primary": Color(0.2, 0.1, 0.4), "secondary": Color(0.6, 0.3, 0.8), "accent": Color(0.9, 0.7, 1.0) },
    2: { "primary": Color(0.7, 0.5, 0.2), "secondary": Color(0.3, 0.2, 0.1), "accent": Color(1.0, 0.8, 0.3) },
    3: { "primary": Color(0.9, 0.7, 0.8), "secondary": Color(0.5, 0.3, 0.5), "accent": Color(1.0, 0.85, 0.9) },
    4: { "primary": Color(0.15, 0.1, 0.3), "secondary": Color(0.5, 0.1, 0.2), "accent": Color(0.8, 0.3, 0.4) },
    5: { "primary": Color(0.1, 0.05, 0.15), "secondary": Color(0.8, 0.5, 0.1), "accent": Color(0.0, 0.8, 1.0) },
    6: { "primary": Color(0.02, 0.02, 0.05), "secondary": Color(0.0, 1.0, 0.3), "accent": Color(1.0, 0.0, 0.5) },
}

## 过渡动画时长
const TRANSITION_DURATION: float = 3.0

# ============================================================
# 节点引用
# ============================================================
var _ground_rect: ColorRect = null
var _ground_material: ShaderMaterial = null
var _env_vfx_container: Node2D = null
var _transition_overlay: ColorRect = null

# ============================================================
# 状态
# ============================================================
var _current_chapter: int = -1
var _is_transitioning: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
    _create_ground_layer()
    _create_env_vfx_container()
    _create_transition_overlay()
    _connect_signals()

func _connect_signals() -> void:
    if ChapterManager.has_signal("chapter_started"):
        ChapterManager.chapter_started.connect(_on_chapter_started)
    if ChapterManager.has_signal("chapter_transition_started"):
        ChapterManager.chapter_transition_started.connect(_on_transition_started)
    if ChapterManager.has_signal("transition_progress_updated"):
        ChapterManager.transition_progress_updated.connect(_on_transition_progress)
    if ChapterManager.has_signal("chapter_transition_completed"):
        ChapterManager.chapter_transition_completed.connect(_on_transition_completed)
    if ChapterManager.has_signal("special_mechanic_activated"):
        ChapterManager.special_mechanic_activated.connect(_on_mechanic_activated)
    if ChapterManager.has_signal("special_mechanic_deactivated"):
        ChapterManager.special_mechanic_deactivated.connect(_on_mechanic_deactivated)
    if ChapterManager.has_signal("boss_spawned"):
        ChapterManager.boss_spawned.connect(_on_boss_spawned)

# ============================================================
# 初始化
# ============================================================

func _create_ground_layer() -> void:
    _ground_rect = ColorRect.new()
    _ground_rect.name = "GroundShaderRect"
    _ground_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _ground_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _ground_rect.z_index = -100  # 确保在最底层
    # 初始使用第一章 Shader（如果存在）
    _load_ground_shader(0)
    add_child(_ground_rect)

func _create_env_vfx_container() -> void:
    _env_vfx_container = Node2D.new()
    _env_vfx_container.name = "EnvVFXContainer"
    _env_vfx_container.z_index = -50  # 在地面之上，实体之下
    add_child(_env_vfx_container)

func _create_transition_overlay() -> void:
    _transition_overlay = ColorRect.new()
    _transition_overlay.name = "TransitionOverlay"
    _transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _transition_overlay.color = Color(0, 0, 0, 0)  # 初始透明
    _transition_overlay.z_index = 90  # 在大多数元素之上
    _transition_overlay.visible = false
    add_child(_transition_overlay)

# ============================================================
# 地面 Shader 管理
# ============================================================

func _load_ground_shader(chapter: int) -> void:
    var shader_path: String = CHAPTER_GROUND_SHADERS.get(chapter, "")
    if shader_path.is_empty():
        # 回退到默认的 pulsing_grid
        shader_path = "res://shaders/pulsing_grid.gdshader"

    var shader = load(shader_path)
    if shader:
        _ground_material = ShaderMaterial.new()
        _ground_material.shader = shader

        # 设置章节色彩参数
        var colors: Dictionary = CHAPTER_COLORS.get(chapter, {})
        if not colors.is_empty():
            _ground_material.set_shader_parameter("primary_color",
                colors.get("primary", Color.WHITE))
            _ground_material.set_shader_parameter("secondary_color",
                colors.get("secondary", Color.GRAY))
            _ground_material.set_shader_parameter("accent_color",
                colors.get("accent", Color.WHITE))

        _ground_rect.material = _ground_material
    else:
        push_warning("ChapterVisualManager: Failed to load shader: %s" % shader_path)

func _crossfade_ground_shader(new_chapter: int, duration: float = 2.0) -> void:
    # 保存旧材质的引用
    var old_material := _ground_material

    # 加载新 Shader
    _load_ground_shader(new_chapter)

    # 如果有旧材质，执行交叉淡入淡出
    if old_material and _ground_material:
        # 新材质从透明开始
        _ground_material.set_shader_parameter("fade_alpha", 0.0)

        var tween := create_tween()
        tween.tween_method(func(t: float):
            if _ground_material:
                _ground_material.set_shader_parameter("fade_alpha", t)
        , 0.0, 1.0, duration)

# ============================================================
# 章节过渡
# ============================================================

func _on_chapter_started(chapter: int, _chapter_name: String) -> void:
    if _current_chapter == chapter:
        return

    var is_first_chapter := _current_chapter == -1
    _current_chapter = chapter

    if is_first_chapter:
        _load_ground_shader(chapter)
    else:
        _crossfade_ground_shader(chapter)

    # 清理旧章节的环境特效
    _clear_env_vfx()

    # 加载新章节的环境特效
    _setup_chapter_env_vfx(chapter)

func _on_transition_started(from_chapter: int, to_chapter: int) -> void:
    _is_transitioning = true
    _transition_overlay.visible = true

    # 过渡动画：先淡入黑幕，切换内容，再淡出
    var tween := create_tween()
    tween.tween_property(_transition_overlay, "color:a", 0.8, TRANSITION_DURATION * 0.4)
    tween.tween_callback(func():
        _crossfade_ground_shader(to_chapter, TRANSITION_DURATION * 0.3)
    )
    tween.tween_property(_transition_overlay, "color:a", 0.0, TRANSITION_DURATION * 0.3)
    tween.tween_callback(func():
        _transition_overlay.visible = false
        _is_transitioning = false
    )

func _on_transition_progress(progress: float) -> void:
    # 可用于驱动额外的过渡效果
    if _ground_material:
        _ground_material.set_shader_parameter("transition_progress", progress)

func _on_transition_completed(_new_chapter: int) -> void:
    _is_transitioning = false
    _transition_overlay.visible = false

# ============================================================
# 环境特效管理
# ============================================================

func _setup_chapter_env_vfx(chapter: int) -> void:
    match chapter:
        0:  # 第一章：毕达哥拉斯 — 浮动几何粒子
            _spawn_floating_geometry_particles()
        1:  # 第二章：中世纪 — 光柱效果
            _spawn_light_shafts()
        2:  # 第三章：巴洛克 — 齿轮装饰
            _spawn_clockwork_decorations()
        3:  # 第四章：洛可可 — 花瓣飘落
            _spawn_petal_particles()
        4:  # 第五章：浪漫主义 — 风暴云层
            _spawn_storm_clouds()
        5:  # 第六章：爵士 — 烟雾效果
            _spawn_smoke_effect()
        6:  # 第七章：数字 — 数据流
            _spawn_data_streams()

func _clear_env_vfx() -> void:
    for child in _env_vfx_container.get_children():
        child.queue_free()

func _spawn_floating_geometry_particles() -> void:
    # 使用 GPUParticles2D 创建浮动的几何粒子
    var particles := GPUParticles2D.new()
    particles.amount = 30
    particles.lifetime = 8.0
    particles.preprocess = 4.0

    var material := ParticleProcessMaterial.new()
    material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    material.emission_box_extents = Vector3(600, 400, 0)
    material.direction = Vector3(0, -1, 0)
    material.spread = 30.0
    material.initial_velocity_min = 5.0
    material.initial_velocity_max = 15.0
    material.gravity = Vector3(0, 0, 0)
    material.scale_min = 0.5
    material.scale_max = 2.0
    material.color = Color(0.9, 0.85, 0.6, 0.3)

    particles.process_material = material
    _env_vfx_container.add_child(particles)

func _spawn_light_shafts() -> void:
    # 第二章：使用半透明 Line2D 模拟光柱
    for i in range(5):
        var shaft := Line2D.new()
        shaft.width = randf_range(20.0, 60.0)
        shaft.default_color = Color(0.6, 0.3, 0.8, 0.08)
        var x := randf_range(-400, 400)
        shaft.add_point(Vector2(x, -500))
        shaft.add_point(Vector2(x + randf_range(-50, 50), 500))
        _env_vfx_container.add_child(shaft)

        # 缓慢摆动动画
        var tween := shaft.create_tween().set_loops()
        tween.tween_property(shaft, "position:x", randf_range(-30, 30), randf_range(4.0, 8.0))
        tween.tween_property(shaft, "position:x", randf_range(-30, 30), randf_range(4.0, 8.0))

func _spawn_clockwork_decorations() -> void:
    # 第三章：旋转的齿轮装饰（使用 Polygon2D）
    for i in range(4):
        var gear := _create_gear_polygon(randf_range(30, 80), randi_range(8, 16))
        gear.color = Color(0.7, 0.5, 0.2, 0.15)
        gear.position = Vector2(randf_range(-500, 500), randf_range(-300, 300))
        _env_vfx_container.add_child(gear)

        var speed := randf_range(0.1, 0.3) * (1 if randi() % 2 == 0 else -1)
        var tween := gear.create_tween().set_loops()
        tween.tween_property(gear, "rotation", gear.rotation + TAU, TAU / abs(speed))

func _spawn_petal_particles() -> void:
    var particles := GPUParticles2D.new()
    particles.amount = 20
    particles.lifetime = 10.0
    particles.preprocess = 5.0

    var material := ParticleProcessMaterial.new()
    material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    material.emission_box_extents = Vector3(800, 50, 0)
    material.direction = Vector3(1, 2, 0)
    material.spread = 45.0
    material.initial_velocity_min = 10.0
    material.initial_velocity_max = 30.0
    material.gravity = Vector3(0, 20, 0)
    material.angular_velocity_min = -90.0
    material.angular_velocity_max = 90.0
    material.scale_min = 0.3
    material.scale_max = 1.0
    material.color = Color(0.9, 0.7, 0.8, 0.4)

    particles.process_material = material
    particles.position = Vector2(0, -400)
    _env_vfx_container.add_child(particles)

func _spawn_storm_clouds() -> void:
    # 第五章：使用多层半透明矩形模拟云层
    for i in range(3):
        var cloud := ColorRect.new()
        cloud.size = Vector2(randf_range(200, 500), randf_range(40, 80))
        cloud.color = Color(0.15, 0.1, 0.3, 0.1 + i * 0.03)
        cloud.position = Vector2(randf_range(-600, 200), randf_range(-400, -200))
        _env_vfx_container.add_child(cloud)

        var tween := cloud.create_tween().set_loops()
        tween.tween_property(cloud, "position:x", cloud.position.x + randf_range(100, 300), randf_range(8.0, 15.0))
        tween.tween_property(cloud, "position:x", cloud.position.x, randf_range(8.0, 15.0))

func _spawn_smoke_effect() -> void:
    var particles := GPUParticles2D.new()
    particles.amount = 15
    particles.lifetime = 6.0
    particles.preprocess = 3.0

    var material := ParticleProcessMaterial.new()
    material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    material.emission_box_extents = Vector3(600, 400, 0)
    material.direction = Vector3(0, -1, 0)
    material.spread = 60.0
    material.initial_velocity_min = 3.0
    material.initial_velocity_max = 8.0
    material.gravity = Vector3(0, -5, 0)
    material.scale_min = 3.0
    material.scale_max = 8.0
    material.color = Color(0.1, 0.05, 0.15, 0.08)

    particles.process_material = material
    _env_vfx_container.add_child(particles)

func _spawn_data_streams() -> void:
    # 第七章：垂直数据流（Matrix 风格）
    for i in range(8):
        var stream := Line2D.new()
        stream.width = 2.0
        stream.default_color = Color(0.0, 1.0, 0.3, 0.3)
        var x := randf_range(-500, 500)
        for j in range(20):
            stream.add_point(Vector2(x, -400 + j * 40))
        _env_vfx_container.add_child(stream)

        # 向下滚动动画
        var tween := stream.create_tween().set_loops()
        tween.tween_property(stream, "position:y", 40.0, randf_range(0.5, 1.5))
        tween.tween_callback(func():
            stream.position.y = 0.0
            stream.modulate.a = randf_range(0.1, 0.5)
        )

# ============================================================
# 特殊机制视觉化
# ============================================================

func _on_mechanic_activated(mechanic_name: String, params: Dictionary) -> void:
    match mechanic_name:
        "swing_grid":
            _activate_swing_grid_visual(params)
        "waveform_warfare":
            _activate_waveform_visual(params)

func _on_mechanic_deactivated(mechanic_name: String) -> void:
    # 清理特殊机制的视觉效果
    pass

func _activate_swing_grid_visual(_params: Dictionary) -> void:
    # 爵士章节的摇摆网格视觉：聚光灯效果
    if _ground_material:
        _ground_material.set_shader_parameter("swing_mode", true)

func _activate_waveform_visual(_params: Dictionary) -> void:
    # 数字章节的波形战争视觉
    if _ground_material:
        _ground_material.set_shader_parameter("waveform_mode", true)

# ============================================================
# Boss 出场视觉
# ============================================================

func _on_boss_spawned(_boss_node: Node) -> void:
    # Boss 出场时的全屏视觉效果
    _transition_overlay.visible = true
    _transition_overlay.color = Color(1, 1, 1, 0)

    var tween := create_tween()
    # 白色闪光
    tween.tween_property(_transition_overlay, "color:a", 0.6, 0.1)
    tween.tween_property(_transition_overlay, "color:a", 0.0, 0.5)
    tween.tween_callback(func():
        _transition_overlay.visible = false
    )

    # 通知 GlobalVisualEnvironment 进入 Boss 模式
    var gve := get_node_or_null("/root/GlobalVisualEnvironment")
    if gve and gve.has_method("enter_boss_mode"):
        gve.enter_boss_mode()

# ============================================================
# 工具函数
# ============================================================

func _create_gear_polygon(radius: float, teeth: int) -> Polygon2D:
    var poly := Polygon2D.new()
    var points := PackedVector2Array()
    var inner_radius := radius * 0.7
    for i in range(teeth * 2):
        var angle := (TAU / (teeth * 2)) * i
        var r := radius if i % 2 == 0 else inner_radius
        points.append(Vector2.from_angle(angle) * r)
    poly.polygon = points
    return poly
```

---

## 8. 支柱三：实体视觉增强器

### 8.1. 系统定位

实体视觉增强器是一套**组件化**的方案，旨在将视觉逻辑从实体的游戏逻辑中解耦出来。每个实体（玩家、敌人、Boss）都可以附加一个视觉增强器组件，该组件负责管理实体的所有视觉表现——Shader 参数更新、粒子效果、动画状态。

### 8.2. 基类实现

```gdscript
## visual_enhancer_base.gd
## 视觉增强器基类
## 所有实体的视觉增强器都继承自此类
class_name VisualEnhancerBase
extends Node

# ============================================================
# 配置
# ============================================================

## 目标视觉节点（Polygon2D 或 Sprite2D）
@export var visual_node_path: NodePath = ""

## 是否启用节拍脉冲
@export var beat_pulse_enabled: bool = true

## 节拍脉冲强度
@export var beat_pulse_scale: float = 0.1

# ============================================================
# 状态
# ============================================================
var _visual_node: CanvasItem = null
var _shader_material: ShaderMaterial = null
var _base_scale: Vector2 = Vector2.ONE
var _beat_pulse_timer: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
    if not visual_node_path.is_empty():
        _visual_node = get_node_or_null(visual_node_path)
    else:
        # 自动查找第一个 CanvasItem 子节点
        for child in get_parent().get_children():
            if child is Polygon2D or child is Sprite2D:
                _visual_node = child
                break

    if _visual_node and _visual_node.material is ShaderMaterial:
        _shader_material = _visual_node.material as ShaderMaterial

    if _visual_node:
        _base_scale = _visual_node.scale

    _connect_beat_signal()

func _process(delta: float) -> void:
    _update_beat_pulse(delta)
    _update_visual(delta)

# ============================================================
# 虚函数（子类重写）
# ============================================================

## 子类重写：每帧视觉更新
func _update_visual(_delta: float) -> void:
    pass

## 子类重写：节拍触发时的视觉响应
func _on_beat_visual() -> void:
    pass

# ============================================================
# 节拍脉冲
# ============================================================

func _connect_beat_signal() -> void:
    if GameManager.has_signal("beat_tick"):
        GameManager.beat_tick.connect(_on_beat_tick)

func _on_beat_tick() -> void:
    if beat_pulse_enabled:
        _beat_pulse_timer = 1.0
    _on_beat_visual()

func _update_beat_pulse(delta: float) -> void:
    if not beat_pulse_enabled or _visual_node == null:
        return

    if _beat_pulse_timer > 0.0:
        _beat_pulse_timer = maxf(_beat_pulse_timer - delta * 4.0, 0.0)
        var pulse := _beat_pulse_timer * beat_pulse_scale
        _visual_node.scale = _base_scale * (1.0 + pulse)
    else:
        _visual_node.scale = _base_scale

# ============================================================
# Shader 参数接口
# ============================================================

func set_shader_param(param_name: String, value: Variant) -> void:
    if _shader_material:
        _shader_material.set_shader_parameter(param_name, value)

func get_shader_param(param_name: String) -> Variant:
    if _shader_material:
        return _shader_material.get_shader_parameter(param_name)
    return null
```

### 8.3. 敌人视觉增强器

```gdscript
## enemy_visual_enhancer.gd
## 敌人视觉增强器
## 从 enemy_base.gd 中解耦出来的视觉逻辑
class_name EnemyVisualEnhancer
extends VisualEnhancerBase

# ============================================================
# 配置
# ============================================================

## 故障效果配置
@export var glitch_base_intensity: float = 0.05
@export var glitch_damage_multiplier: float = 0.5
@export var glitch_flicker_chance: float = 0.02

## 受击闪白配置
@export var hit_flash_duration: float = 0.1
@export var hit_flash_color: Color = Color.WHITE

# ============================================================
# 状态
# ============================================================
var _glitch_intensity: float = 0.0
var _hit_flash_timer: float = 0.0
var _is_stunned: bool = false
var _hp_ratio: float = 1.0
var _enemy_ref: Node = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
    super._ready()
    _enemy_ref = get_parent()

func _update_visual(delta: float) -> void:
    if _enemy_ref == null:
        return

    # 从敌人获取状态
    if _enemy_ref.has_method("get_hp_ratio"):
        _hp_ratio = _enemy_ref.get_hp_ratio()

    # 更新故障强度（HP 越低，故障越强）
    var damage_glitch := (1.0 - _hp_ratio) * glitch_damage_multiplier
    _glitch_intensity = glitch_base_intensity + damage_glitch

    # 随机故障闪烁
    if randf() < glitch_flicker_chance:
        _glitch_intensity += randf_range(0.1, 0.3)

    # 受击闪白衰减
    if _hit_flash_timer > 0.0:
        _hit_flash_timer -= delta
        var flash_ratio := _hit_flash_timer / hit_flash_duration
        if _visual_node:
            _visual_node.modulate = _visual_node.modulate.lerp(Color.WHITE, flash_ratio * 0.5)

    # 更新 Shader 参数
    set_shader_param("glitch_intensity", _glitch_intensity)
    set_shader_param("hp_ratio", _hp_ratio)
    set_shader_param("is_stunned", 1.0 if _is_stunned else 0.0)

## 触发受击闪白
func trigger_hit_flash() -> void:
    _hit_flash_timer = hit_flash_duration
    if _visual_node:
        _visual_node.modulate = hit_flash_color

## 设置眩晕状态
func set_stunned(stunned: bool) -> void:
    _is_stunned = stunned

## 节拍视觉响应
func _on_beat_visual() -> void:
    set_shader_param("beat_energy", 1.0)
    # beat_energy 将在 Shader 中自行衰减
```

### 8.4. 与现有代码的集成方式

将视觉增强器集成到现有系统中，**不需要修改 `enemy_base.gd` 的核心逻辑**。集成步骤如下：

**步骤一：** 在每个敌人场景（如 `enemy_static.tscn`）中添加 `EnemyVisualEnhancer` 节点作为子节点。

**步骤二：** 在 `enemy_base.gd` 中添加一个可选的增强器引用：

```gdscript
# 在 enemy_base.gd 的 _ready() 中添加：
var _visual_enhancer: EnemyVisualEnhancer = null

func _ready() -> void:
    # ... 现有代码 ...
    _visual_enhancer = get_node_or_null("EnemyVisualEnhancer")
```

**步骤三：** 在 `enemy_base.gd` 的 `_update_visual()` 中，如果增强器存在则委托给它：

```gdscript
func _update_visual(delta: float) -> void:
    if _visual_enhancer:
        # 增强器接管视觉更新
        return
    # ... 保留原有视觉代码作为回退 ...
```

这种方式确保了**向后兼容**——如果某个敌人场景没有添加增强器，原有的视觉代码仍然会执行。

---

## 9. 支柱四：UI 主题与风格系统

### 9.1. 主题设计原则

UI 的视觉风格应与游戏的核心美学保持一致：**极简几何 + 发光边缘 + 深色背景**。具体来说，所有 UI 元素应遵循以下原则：背景使用深色半透明（`Color(0.02, 0.02, 0.05, 0.85)`），边框使用 1-2 像素的发光色线条，文字使用等宽字体或几何感字体，颜色跟随当前章节主色。

### 9.2. GlobalTheme.tres 配置

```tres
[gd_resource type="Theme" format=3]

[sub_resource type="StyleBoxFlat" id="panel_dark"]
bg_color = Color(0.02, 0.02, 0.05, 0.85)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0, 0.8, 0.6, 0.5)
corner_radius_top_left = 2
corner_radius_top_right = 2
corner_radius_bottom_right = 2
corner_radius_bottom_left = 2
shadow_color = Color(0, 0.8, 0.6, 0.1)
shadow_size = 4

[sub_resource type="StyleBoxFlat" id="button_normal"]
bg_color = Color(0.05, 0.05, 0.1, 0.9)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0, 0.6, 0.5, 0.6)
corner_radius_top_left = 3
corner_radius_top_right = 3
corner_radius_bottom_right = 3
corner_radius_bottom_left = 3

[sub_resource type="StyleBoxFlat" id="button_hover"]
bg_color = Color(0.08, 0.08, 0.15, 0.95)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0, 1.0, 0.8, 0.8)
corner_radius_top_left = 3
corner_radius_top_right = 3
corner_radius_bottom_right = 3
corner_radius_bottom_left = 3
shadow_color = Color(0, 1.0, 0.8, 0.15)
shadow_size = 6

[sub_resource type="StyleBoxFlat" id="progress_bar_bg"]
bg_color = Color(0.03, 0.03, 0.06, 0.9)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0, 0.5, 0.4, 0.4)

[sub_resource type="StyleBoxFlat" id="progress_bar_fill"]
bg_color = Color(0, 0.8, 0.6, 0.8)
shadow_color = Color(0, 0.8, 0.6, 0.2)
shadow_size = 3

[resource]
default_font_size = 14

Button/styles/normal = SubResource("button_normal")
Button/styles/hover = SubResource("button_hover")
Button/colors/font_color = Color(0.8, 0.9, 0.85, 1)
Button/colors/font_hover_color = Color(1, 1, 1, 1)

PanelContainer/styles/panel = SubResource("panel_dark")

Label/colors/font_color = Color(0.7, 0.8, 0.75, 1)
Label/font_sizes/font_size = 14

ProgressBar/styles/background = SubResource("progress_bar_bg")
ProgressBar/styles/fill = SubResource("progress_bar_fill")
```

---

## 10. 新增 Shader 实现方案

### 10.1. 第一章地面 Shader：克拉尼图形

```glsl
shader_type canvas_item;

// 第一章：毕达哥拉斯 — 克拉尼图形地面
// 模拟金属板上的振动模式，沙粒聚集在节线上

global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;

uniform vec4 primary_color : source_color = vec4(0.9, 0.85, 0.6, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.3, 0.25, 0.15, 1.0);
uniform float pattern_scale : hint_range(1.0, 20.0) = 8.0;
uniform float line_width : hint_range(0.01, 0.1) = 0.03;
uniform float animation_speed : hint_range(0.1, 2.0) = 0.5;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

// 克拉尼图形函数：矩形板的振动模式
float chladni(vec2 uv, float m, float n) {
    return cos(m * 3.14159 * uv.x) * cos(n * 3.14159 * uv.y)
         - cos(n * 3.14159 * uv.x) * cos(m * 3.14159 * uv.y);
}

void fragment() {
    vec2 uv = UV * pattern_scale;
    float t = global_time * animation_speed;

    // 混合多个振动模式
    float mode1 = chladni(uv, 3.0, 2.0 + sin(t * 0.3) * 0.5);
    float mode2 = chladni(uv, 5.0, 3.0 + cos(t * 0.2) * 0.5);
    float pattern = mix(mode1, mode2, sin(t * 0.1) * 0.5 + 0.5);

    // 节线检测（沙粒聚集的位置）
    float line = smoothstep(line_width, 0.0, abs(pattern));

    // 节拍脉冲：节线在节拍时刻发光
    float beat_glow = exp(-beat_phase * 3.0) * 0.5;
    line += beat_glow * smoothstep(line_width * 2.0, 0.0, abs(pattern));

    // 混合颜色
    vec3 bg = secondary_color.rgb;
    vec3 fg = primary_color.rgb;
    vec3 final_color = mix(bg, fg, line);

    // 添加微弱的章节色调
    final_color = mix(final_color, chapter_color, 0.05);

    COLOR = vec4(final_color, fade_alpha);
}
```

### 10.2. 第二章地面 Shader：教堂玫瑰窗

```glsl
shader_type canvas_item;

// 第二章：中世纪 — 教堂玫瑰窗地面
// 模拟哥特式教堂的彩色玻璃窗投影

global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;

uniform vec4 primary_color : source_color = vec4(0.2, 0.1, 0.4, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.6, 0.3, 0.8, 1.0);
uniform vec4 accent_color : source_color = vec4(0.9, 0.7, 1.0, 1.0);
uniform float pattern_scale : hint_range(1.0, 10.0) = 4.0;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec2 uv = (UV - 0.5) * pattern_scale;
    float t = global_time * 0.3;

    // 极坐标
    float r = length(uv);
    float a = atan(uv.y, uv.x);

    // 玫瑰窗的径向对称图案
    float petals = 8.0;
    float petal = abs(sin(a * petals + t));
    float ring = abs(sin(r * 6.0 - t * 0.5));

    // 组合图案
    float pattern = petal * ring;
    pattern = smoothstep(0.3, 0.7, pattern);

    // 彩色玻璃效果：不同区域不同颜色
    vec3 color1 = primary_color.rgb;
    vec3 color2 = secondary_color.rgb;
    vec3 color3 = accent_color.rgb;

    float sector = fract(a / 6.28318 * petals);
    vec3 glass_color = mix(color1, color2, sector);
    glass_color = mix(glass_color, color3, pattern * 0.5);

    // 铅条（分隔线）
    float lead = smoothstep(0.02, 0.0, abs(sin(a * petals)));
    lead += smoothstep(0.02, 0.0, abs(sin(r * 6.0)));
    lead = clamp(lead, 0.0, 1.0);

    vec3 final_color = mix(glass_color * 0.3, vec3(0.01), lead);

    // 节拍时光线增强
    float beat_light = exp(-beat_phase * 4.0) * 0.3;
    final_color += glass_color * beat_light * pattern;

    COLOR = vec4(final_color, fade_alpha);
}
```

### 10.3. 第七章地面 Shader：数字矩阵

```glsl
shader_type canvas_item;

// 第七章：合成主脑·噪音 — 数字矩阵地面
// 模拟数据流、二进制代码和数字损坏

global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;

uniform vec4 primary_color : source_color = vec4(0.0, 1.0, 0.3, 1.0);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.0, 0.5, 1.0);
uniform float grid_size : hint_range(4.0, 32.0) = 16.0;
uniform float scroll_speed : hint_range(0.1, 5.0) = 1.0;
uniform float glitch_amount : hint_range(0.0, 1.0) = 0.3;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

// 伪随机
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    float t = global_time * scroll_speed;

    // 网格化
    vec2 grid_uv = floor(uv * grid_size);
    vec2 cell_uv = fract(uv * grid_size);

    // 每列不同的滚动速度
    float col_speed = hash(vec2(grid_uv.x, 0.0)) * 2.0 + 0.5;
    grid_uv.y = floor(uv.y * grid_size - t * col_speed);

    // 随机"字符"亮度
    float char_val = hash(grid_uv);

    // 列头发光（最新的数据）
    float head_y = fract(t * col_speed / grid_size);
    float head_dist = abs(UV.y - head_y);
    float head_glow = exp(-head_dist * 20.0) * 0.8;

    // 故障效果
    float glitch = 0.0;
    if (glitch_amount > 0.0) {
        float glitch_line = step(0.98, hash(vec2(floor(global_time * 10.0), grid_uv.y)));
        glitch = glitch_line * glitch_amount;
    }

    // 颜色
    vec3 base_color = primary_color.rgb * char_val * 0.3;
    base_color += primary_color.rgb * head_glow;

    // 故障时切换到次要色
    base_color = mix(base_color, secondary_color.rgb * char_val, glitch);

    // 节拍脉冲
    float beat_pulse = exp(-beat_phase * 5.0);
    base_color += primary_color.rgb * beat_pulse * 0.2 * char_val;

    // 扫描线
    float scanline = sin(UV.y * grid_size * 3.14159 * 2.0) * 0.05 + 0.95;
    base_color *= scanline;

    COLOR = vec4(base_color, fade_alpha);
}
```

### 10.4. 章节过渡 Shader

```glsl
shader_type canvas_item;

// 章节过渡 Shader
// 用于 ChapterVisualManager 的过渡覆盖层

uniform float transition_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 from_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 to_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float noise_scale : hint_range(1.0, 20.0) = 8.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV * noise_scale;
    float noise = hash(floor(uv));

    // 基于噪声的渐进式揭示
    float reveal = smoothstep(noise - 0.1, noise + 0.1, transition_progress);

    vec4 color = mix(from_color, to_color, reveal);

    // 过渡边缘发光
    float edge = smoothstep(0.0, 0.05, abs(reveal - 0.5)) ;
    edge = 1.0 - edge;
    color.rgb += vec3(1.0) * edge * 0.5;

    COLOR = color;
}
```

---

## 11. 现有 Shader 增强方案

### 11.1. projectile_glow.gdshader 增强

当前的弹体 Shader 只有基础的发光效果。增强方案是添加**音色视觉修饰**参数：

```glsl
// 在现有 projectile_glow.gdshader 中添加以下 uniform：

// 音色系别参数 (0=无, 1=弦乐, 2=管乐, 3=打击, 4=键盘)
uniform int timbre_family = 0;

// 音色视觉修饰
uniform float timbre_wave_freq : hint_range(0.0, 10.0) = 0.0;  // 弦乐：波纹频率
uniform float timbre_pulse_rate : hint_range(0.0, 5.0) = 0.0;  // 管乐：脉冲速率
uniform float timbre_sharp_factor : hint_range(0.0, 1.0) = 0.0; // 打击：锐利度
uniform float timbre_key_segments : hint_range(0.0, 8.0) = 0.0; // 键盘：分段数

// 在 fragment() 中添加音色修饰逻辑：
// 弦乐系：弹体边缘添加正弦波纹
// 管乐系：弹体亮度随时间脉冲
// 打击系：弹体边缘更锐利（硬边缘）
// 键盘系：弹体呈现分段棱角
```

### 11.2. pulsing_grid.gdshader 增强

为现有的脉冲网格 Shader 添加全局参数支持，使其能够响应章节色彩变化：

```glsl
// 在现有 pulsing_grid.gdshader 中添加：
global uniform vec3 chapter_color;
global uniform float beat_phase;

// 将硬编码的颜色替换为：
// vec4 grid_color = vec4(chapter_color, 1.0);
```

---

## 12. GPUParticles2D 特效方案

### 12.1. 施法爆发粒子

这是视觉影响最大的粒子效果之一。当玩家施放和弦法术时，应在玩家位置产生一次性的粒子爆发。

```gdscript
## 在 SpellVisualManager 中添加 GPUParticles2D 支持

func _create_cast_burst_particles(pos: Vector2, color: Color) -> GPUParticles2D:
    var particles := GPUParticles2D.new()
    particles.emitting = false
    particles.one_shot = true
    particles.amount = 32
    particles.lifetime = 0.6
    particles.explosiveness = 1.0

    var mat := ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    mat.emission_sphere_radius = 5.0
    mat.direction = Vector3(0, 0, 0)
    mat.spread = 180.0
    mat.initial_velocity_min = 80.0
    mat.initial_velocity_max = 200.0
    mat.damping_min = 100.0
    mat.damping_max = 200.0
    mat.scale_min = 1.0
    mat.scale_max = 3.0

    # 颜色渐变：从亮色到透明
    var gradient := Gradient.new()
    gradient.set_color(0, Color(color.r, color.g, color.b, 1.0))
    gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
    var color_ramp := GradientTexture1D.new()
    color_ramp.gradient = gradient
    mat.color_ramp = color_ramp

    particles.process_material = mat
    particles.position = pos
    add_child(particles)
    particles.emitting = true

    # 自动清理
    get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
    return particles
```

### 12.2. 敌人死亡爆炸粒子

替代当前 `death_vfx_manager.gd` 中的 Polygon2D 碎片方案：

```gdscript
func _create_death_particles(pos: Vector2, enemy_color: Color, enemy_type: int) -> GPUParticles2D:
    var particles := GPUParticles2D.new()
    particles.emitting = false
    particles.one_shot = true
    particles.amount = 16 + enemy_type * 4  # 更强的敌人更多碎片
    particles.lifetime = 0.8
    particles.explosiveness = 0.9

    var mat := ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    mat.emission_sphere_radius = 8.0
    mat.direction = Vector3(0, 0, 0)
    mat.spread = 180.0
    mat.initial_velocity_min = 50.0
    mat.initial_velocity_max = 150.0
    mat.gravity = Vector3(0, 50, 0)  # 轻微下坠
    mat.damping_min = 50.0
    mat.damping_max = 100.0
    mat.angular_velocity_min = -360.0
    mat.angular_velocity_max = 360.0
    mat.scale_min = 0.5
    mat.scale_max = 2.0

    var gradient := Gradient.new()
    gradient.set_color(0, enemy_color)
    gradient.set_color(1, Color(enemy_color.r, enemy_color.g, enemy_color.b, 0.0))
    var color_ramp := GradientTexture1D.new()
    color_ramp.gradient = gradient
    mat.color_ramp = color_ramp

    particles.process_material = mat
    particles.position = pos
    add_child(particles)
    particles.emitting = true

    get_tree().create_timer(1.5).timeout.connect(particles.queue_free)
    return particles
```

---

## 13. 场景树重构方案

### 13.1. 重构后的 main_game.tscn 节点树

```
MainGame (Node2D)
├── GlobalVisualEnvironment (已通过 Autoload 自动加载)
│
├── ChapterVisualManager (Node2D)           ← 新增
│   ├── GroundShaderRect (ColorRect)        ← 替代原 Ground 节点
│   ├── EnvVFXContainer (Node2D)            ← 新增：章节环境特效
│   └── TransitionOverlay (ColorRect)       ← 新增：过渡覆盖层
│
├── EventHorizon (Node2D)                   ← 保留
│
├── Player (CharacterBody2D)                ← 保留
│   ├── PlayerVisual (Polygon2D)            ← 保留
│   ├── PlayerVisualEnhancer (Node)         ← 新增：视觉增强器
│   ├── CollisionShape2D                    ← 保留
│   ├── InvincibilityTimer                  ← 保留
│   ├── PickupArea                          ← 保留
│   └── Camera2D                            ← 保留
│
├── EnemySpawner (Node2D)                   ← 保留
│
├── ProjectileManager (Node2D)              ← 保留
│   └── MultiMeshInstance2D                 ← 保留
│
├── SpellVisualManager (Node2D)             ← 保留（已存在但未在场景中）
│
├── DeathVFXManager (Node2D)                ← 保留（已存在但未在场景中）
│
└── HUD (CanvasLayer)                       ← 保留，增加 Theme 引用
    ├── ... (现有 UI 节点)
    └── ...
```

### 13.2. 敌人场景重构示例

以 `enemy_static.tscn` 为例，添加视觉增强器：

```
EnemyStatic (CharacterBody2D)
├── EnemyVisual (Polygon2D)                 ← 保留
├── EnemyVisualEnhancer (Node)              ← 新增
│   └── visual_node_path = "../EnemyVisual"
├── CollisionShape2D                        ← 保留
└── DamageArea (Area2D)                     ← 保留
    └── DamageShape (CollisionShape2D)      ← 保留
```

---

## 14. 分步实施路线图

### 阶段一：全局视觉环境（优先级最高）

| 步骤 | 任务 | 产出物 | 预估工时 |
| :--- | :--- | :--- | :--- |
| 1.1 | 创建 `global_visual_environment.gd` | 脚本文件 | 2h |
| 1.2 | 在 `project.godot` 中注册 Autoload 和全局 Shader 参数 | 配置文件 | 0.5h |
| 1.3 | 测试 Glow/Bloom 效果在现有弹体上的表现 | 截图/视频 | 1h |
| 1.4 | 调优后处理参数 | 参数记录 | 0.5h |

**验收标准：** 弹体发光产生柔和的 Bloom 扩散；节拍时刻全局亮度微弱脉冲；章节切换时色调平滑过渡。

### 阶段二：章节视觉差异化

| 步骤 | 任务 | 产出物 | 预估工时 |
| :--- | :--- | :--- | :--- |
| 2.1 | 创建 `chapter_visual_manager.gd` | 脚本文件 | 3h |
| 2.2 | 创建第一章地面 Shader（克拉尼图形） | Shader 文件 | 2h |
| 2.3 | 创建第二章地面 Shader（教堂玫瑰窗） | Shader 文件 | 2h |
| 2.4 | 创建第七章地面 Shader（数字矩阵） | Shader 文件 | 2h |
| 2.5 | 创建剩余 4 个章节的地面 Shader | Shader 文件 | 4h |
| 2.6 | 实现章节过渡动画 | 过渡 Shader + 脚本 | 2h |
| 2.7 | 实现章节环境特效 | GPUParticles2D 场景 | 3h |

**验收标准：** 每个章节有独特的地面视觉；章节切换时有平滑的过渡动画；环境特效与章节主题匹配。

### 阶段三：实体视觉解耦

| 步骤 | 任务 | 产出物 | 预估工时 |
| :--- | :--- | :--- | :--- |
| 3.1 | 创建 `visual_enhancer_base.gd` | 脚本文件 | 1h |
| 3.2 | 创建 `enemy_visual_enhancer.gd` | 脚本文件 | 2h |
| 3.3 | 修改 `enemy_base.gd` 添加增强器委托 | 代码修改 | 1h |
| 3.4 | 更新所有敌人场景添加增强器节点 | 场景文件 | 2h |
| 3.5 | 创建 `player_visual_enhancer.gd` | 脚本文件 | 2h |

**验收标准：** 所有敌人的视觉效果与重构前完全一致；增强器可独立控制视觉参数。

### 阶段四：音色与粒子增强

| 步骤 | 任务 | 产出物 | 预估工时 |
| :--- | :--- | :--- | :--- |
| 4.1 | 增强 `projectile_glow.gdshader` 支持音色参数 | Shader 修改 | 2h |
| 4.2 | 在 `ProjectileManager` 中传递音色参数 | 代码修改 | 2h |
| 4.3 | 创建施法爆发 GPUParticles2D 场景 | 场景文件 | 2h |
| 4.4 | 创建敌人死亡 GPUParticles2D 场景 | 场景文件 | 2h |
| 4.5 | 集成 GPU 粒子到现有管理器 | 代码修改 | 2h |

**验收标准：** 不同音色的弹体有可辨识的视觉差异；施法和死亡效果使用 GPU 粒子且视觉更丰富。

### 阶段五：UI 主题化

| 步骤 | 任务 | 产出物 | 预估工时 |
| :--- | :--- | :--- | :--- |
| 5.1 | 重写 `GlobalTheme.tres` | 主题资源 | 2h |
| 5.2 | 创建 StyleBox 资源集合 | 资源文件 | 1h |
| 5.3 | 重构 `hud.gd` 使用 Theme 引用 | 代码修改 | 2h |
| 5.4 | 重构其他 UI 脚本 | 代码修改 | 1h |

**验收标准：** 所有 UI 元素风格统一；修改 Theme 资源可全局影响 UI 外观。

---

## 15. 风险评估与缓解策略

| 风险 | 概率 | 影响 | 缓解策略 |
| :--- | :--- | :--- | :--- |
| WorldEnvironment 在 2D 中 Glow 效果不理想 | 中 | 高 | 准备 B 方案：使用全屏 Shader 模拟 Bloom |
| 新增 Shader 导致低端设备性能下降 | 中 | 中 | 每个 Shader 提供 `quality` uniform 控制复杂度；提供 Low/Medium/High 预设 |
| 视觉增强器解耦引入回归 Bug | 低 | 高 | 增强器采用"可选委托"模式，原有代码作为回退 |
| GPU 粒子与 MultiMesh 弹体的 Z-order 冲突 | 中 | 低 | 严格管理 z_index 分层 |
| 7 个章节 Shader 的视觉一致性难以保证 | 中 | 中 | 所有章节 Shader 共享统一的全局参数接口和色彩规范 |

---

## 参考资料

[1]: https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html "Godot 官方文档 — Environment and Post-Processing"
[2]: https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html "Godot 官方文档 — 2D Particle Systems"
[3]: https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html "Godot 官方文档 — Shading Language"
