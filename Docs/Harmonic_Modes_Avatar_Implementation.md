# 《Project Harmony》程序化谐振调式化身实现文档

**版本:** 1.0
**日期:** 2026-02-12
**关联议题:** [#59](https://github.com/gdszyy/project-harmony-gdd/issues/59)

---

## 1. 概述

本文档记录了 Issue #59 中定义的"程序化谐振调式化身"(Procedural Harmonic Modes Avatars) 系统的完整实现方案。该系统是游戏"代码即艺术"(Code as Art) 哲学的核心体现，使用纯程序化技术在 Godot 4.x 中创建四种视觉上截然不同的玩家角色化身，不依赖任何外部美术资源。

## 2. 架构总览

系统采用分层架构，由以下核心组件构成：

```
HarmonicAvatarManager (管理器层)
├── AbstractSkeleton (骨骼层)
│   ├── Skeleton3D (指挥家骨架)
│   ├── AnimationPlayer (动画基元库)
│   └── BoneAttachment3D × 8 (骨骼锚点)
└── ModeGeometry (几何层, 四选一)
    ├── IonianMode (mode_id=0)
    ├── LocrianMode (mode_id=1)
    ├── LydianMode (mode_id=2)
    └── PhrygianMode (mode_id=3)
```

统一着色器 `player_mode.gdshader` 通过 `uniform int mode_id` 控制所有调式的视觉差异。

## 3. 文件清单

| 文件路径 | 类型 | 职责 |
| :--- | :--- | :--- |
| `scripts/entities/abstract_skeleton.gd` | GDScript | 抽象"指挥家"骨骼系统，程序化创建 Skeleton3D 和动画基元 |
| `scripts/entities/harmonic_avatar_manager.gd` | GDScript | 调式化身管理器，统一管理骨骼、几何体和调式切换 |
| `scripts/entities/modes/ionian_mode.gd` | GDScript | 爱奥尼亚调式几何体 (三同心环 + 十二面体核心) |
| `scripts/entities/modes/locrian_mode.gd` | GDScript | 洛克里亚调式几何体 (三不闭合弧线 + 毛刺效果) |
| `scripts/entities/modes/lydian_mode.gd` | GDScript | 吕底亚调式 VFX (GPUParticles3D 星云效果) |
| `scripts/entities/modes/phrygian_mode.gd` | GDScript | 弗里几亚调式几何体 (晶体核心 + 刀锋光环) |
| `shaders/player_mode.gdshader` | Shader | 统一空间着色器，处理四种调式的动态视觉变化 |
| `shaders/lydian_particle.gdshader` | Shader | 吕底亚星云粒子着色器，程序化生成彩虹色 |

## 4. 抽象骨骼系统 (`AbstractSkeleton`)

### 4.1. 骨骼层级

```
root (整体位置与朝向)
└── torso (呼吸感与核心律动)
    ├── shoulder_l (左肩)
    │   └── arm_l (左臂)
    │       └── hand_l (左手)
    └── shoulder_r (右肩)
        └── arm_r (右臂)
            └── hand_r (右手)
```

共 8 个骨骼，通过 `Skeleton3D.add_bone()` 程序化创建，无需外部骨骼资源。

### 4.2. 动画基元库

| 类别 | 动画名称 | 描述 | 时长 |
| :--- | :--- | :--- | :--- |
| 姿态 | `Stance_Idle` | 待机，BPM 同步呼吸 | 2.0s (循环) |
| 姿态 | `Stance_Combat` | 战斗准备，双手抬起 | 1.5s (循环) |
| 姿态 | `Stance_Channeling` | 持续施法，双手前伸 | 1.0s (循环) |
| 手势 | `Gesture_Point` | 指向，弹射物施法 | 0.4s |
| 手势 | `Gesture_DrawCircle` | 画圆，AOE 施法 | 0.6s |
| 手势 | `Gesture_Raise` | 高举，召唤施法 | 0.5s |
| 手势 | `Gesture_Push` | 前推，冲击波施法 | 0.35s |
| 手势 | `Gesture_Flick` | 甩动，散射施法 | 0.3s |

### 4.3. 动态修改器

| 修改器 | 描述 | 关联调式 |
| :--- | :--- | :--- |
| `Modifier_Impact` | 受击后仰与回弹 | 全部 |
| `Modifier_Glitch` | 随机跳帧和抽搐 | 洛克里亚 |
| `BPM_Breathing` | BPM 同步呼吸起伏 | 全部 |

## 5. 四种调式实现

### 5.1. 爱奥尼亚式 (Ionian, mode_id=0)

> **关键词：** 精准、平滑、与节拍完美同步

- **几何体：** 三同心 `TorusMesh` 光环 + `ArrayMesh` 正十二面体核心
- **颜色：** Resonant Teal `#00D9BF` + Crystal White `#E6F0FF`
- **着色器效果：** BPM 同步旋转、柔和涟漪施法效果、菲涅尔边缘发光
- **动画特性：** 标准 BPM 同步，`ease-in-out` 曲线，1% 呼吸缩放

### 5.2. 洛克里亚式 (Locrian, mode_id=1)

> **关键词：** 不稳定、抽搐、充满"错误"感

- **几何体：** 三条不闭合管状弧线 (`ArrayMesh`)
- **颜色：** Corrosive Purple `#8B00FF` + Error Red `#FF2020`
- **着色器效果：** 顶点毛刺位移、色差 (Chromatic Aberration)、数字衰变闪烁、扫描线
- **动画特性：** BPM 在 0.8-1.2 间随机波动，突兀的 `linear` 曲线

### 5.3. 吕底亚式 (Lydian, mode_id=2)

> **关键词：** 飘逸、广阔、如星云般流动

- **VFX：** `GPUParticles3D` 环形发射 + 自定义粒子着色器
- **颜色：** 程序化彩虹色 (`hsv_to_rgb` 基于粒子生命周期)
- **着色器效果：** 星云密度噪声、星尘闪烁、施法粒子爆发 (`emit_particles`)
- **动画特性：** 动作幅度 ×1.2，混合时间拉长，惯性拖尾效果

### 5.4. 弗里几亚式 (Phrygian, mode_id=3)

> **关键词：** 迅捷、致命、充满攻击性

- **几何体：** `ArrayMesh` 尖锐晶体簇核心 + `TorusMesh` 刀锋变形光环
- **颜色：** Error Red `#FF2020` + Neon Pink `#FF69B4`
- **着色器效果：** 刀锋顶点变形、威胁性脉动、刺击闪光
- **动画特性：** 动画速度 ×1.5，`Modifier_Stab` 全身刺击

## 6. 统一着色器 (`player_mode.gdshader`)

着色器通过 `uniform int mode_id` 在单个 Shader 中处理所有四种调式的视觉差异：

| Uniform 参数 | 类型 | 描述 | 适用调式 |
| :--- | :--- | :--- | :--- |
| `mode_id` | int | 调式标识 (0-3) | 全部 |
| `primary_color` | vec3 | 主色 | 全部 |
| `secondary_color` | vec3 | 辅色 | 全部 |
| `beat_energy` | float | 节拍能量 | 全部 |
| `bpm_phase` | float | BPM 相位 | 全部 |
| `ripple_intensity` | float | 涟漪强度 | Ionian |
| `glitch_intensity` | float | 毛刺强度 | Locrian |
| `chromatic_aberration` | float | 色差强度 | Locrian |
| `nebula_density` | float | 星云密度 | Lydian |
| `star_brightness` | float | 星尘亮度 | Lydian |
| `blade_sharpness` | float | 刀锋锐度 | Phrygian |
| `stab_offset` | float | 刺击偏移 | Phrygian |
| `threat_pulse` | float | 威胁脉动 | Phrygian |

## 7. 集成接口

### 7.1. 与 CharacterClassManager 集成

`HarmonicAvatarManager` 监听 `CharacterClassManager.class_applied` 信号，自动根据选择的职业切换调式外观。

### 7.2. 与 SpellcraftSystem 集成

管理器监听 `spell_cast`、`chord_cast`、`manual_cast` 信号，自动：
1. 播放对应的骨骼手势动画
2. 触发调式特定的施法视觉效果

### 7.3. 法术类型到手势的映射

| 法术类型 | 骨骼手势 |
| :--- | :--- |
| `projectile` | `Gesture_Point` |
| `aoe` | `Gesture_DrawCircle` |
| `summon` | `Gesture_Raise` |
| `shockwave` | `Gesture_Push` |
| `scatter` | `Gesture_Flick` |

## 8. 后续扩展

1. **AnimationTree 状态机：** 当前使用 AnimationPlayer 直接播放，后续可引入 AnimationTree + StateMachine 实现更复杂的动画混合。
2. **2D/3D 渲染桥接：** 当前游戏主体为 2D，3D 化身可通过 SubViewport 渲染到 Texture2D 后在 2D 场景中显示。
3. **更多调式：** 架构支持扩展更多调式，只需新增 mode_id 和对应的几何体脚本。
4. **IK 系统：** 为手部骨骼添加 IK 约束，实现更精确的指向目标动画。
