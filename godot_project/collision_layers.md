# Project Harmony — 碰撞层配置

> 本文件定义 Godot 项目中的碰撞层分配方案。
> 请在 Project Settings → Physics → 2D Physics → Layer Names 中配置。

## 碰撞层分配

### 基础层 (Layer 1-8)

| Layer | 名称 | 用途 |
|-------|------|------|
| 1 | `world` | 世界边界、地形障碍物 |
| 2 | `player` | 玩家角色 (CharacterBody2D) |
| 3 | `enemy` | 敌人实体 |
| 4 | `player_projectile` | 玩家弹体（法术投射物） |
| 5 | `enemy_projectile` | 敌人弹体（噪音攻击） |
| 6 | `pickup` | 拾取物（和声碎片、经验值） |
| 7 | `trigger_zone` | 触发区域（Boss区域、事件触发） |
| 8 | `shield` | 护盾弹体（和弦护盾） |

### 频谱相位层 (Layer 10-16)

频谱相位系统（共鸣切片）使用 Layer 10-16 来实现敌人和弹幕在不同相位下的碰撞行为。当玩家切换相位时，`PhaseManager` 单例将动态修改玩家的 `collision_mask`，使其只与当前相位对应的碰撞层发生交互。

| Layer | 名称 | 用途 |
|-------|------|------|
| 10 | `enemy_normal` | 敌人在全频相位 (Fundamental) 的碰撞体 |
| 11 | `enemy_highpass` | 敌人在高通相位 (Overtone) 的碰撞体 |
| 12 | `enemy_lowpass` | 敌人在低通相位 (Sub-Bass) 的碰撞体 |
| 13 | `bullet_normal` | 弹幕在全频相位 (Fundamental) 的碰撞体 |
| 14 | `bullet_highpass` | 弹幕在高通相位 (Overtone) 的碰撞体 |
| 15 | `bullet_lowpass` | 弹幕在低通相位 (Sub-Bass) 的碰撞体 |
| 16 | `player_phase_interaction` | 玩家用于与相位特定物体交互的层 |

## 碰撞矩阵

### 基础碰撞矩阵

| 实体 | collision_layer | collision_mask |
|------|----------------|----------------|
| Player | 2 | 1, 3, 5, 6, 7 |
| Enemy | 3 | 1, 2, 4, 8 |
| Player Projectile | 4 | 1, 3 |
| Enemy Projectile | 5 | 1, 2, 8 |
| Pickup | 6 | 2 |
| World Boundary | 1 | — |
| Shield | 8 | 5 |
| Trigger Zone | 7 | 2 |

### 相位碰撞矩阵

当频谱相位系统激活时，玩家的 `collision_mask` 将根据当前相位动态切换。以下展示了三种相位下玩家与相位层的交互关系：

| 玩家相位 | 额外 collision_mask | 说明 |
|----------|---------------------|------|
| **全频 (Fundamental)** | 10, 13 | 与全频相位的敌人和弹幕碰撞 |
| **高通 (Overtone)** | 11, 14 | 与高通相位的敌人和弹幕碰撞 |
| **低通 (Sub-Bass)** | 12, 15 | 与低通相位的敌人和弹幕碰撞 |

每个敌人场景将包含三套碰撞体节点，分别放置在对应的相位层上。`PhaseManager` 广播相位切换信号后，敌人脚本将切换对应碰撞体的 `disabled` 属性和视觉节点的 `visible` 属性。

## 说明

- **Player** 可以与世界碰撞、被敌人接触、被敌人弹体击中、拾取物品、进入触发区域
- **Enemy** 可以与世界碰撞、接触玩家、被玩家弹体和护盾击中
- **Player Projectile** 与世界和敌人碰撞
- **Enemy Projectile** 与世界、玩家和护盾碰撞（护盾可以阻挡敌人弹体）
- **Shield** 仅与敌人弹体碰撞（保护玩家）
- **Pickup** 仅与玩家碰撞（自动拾取）
- **相位层** 为敌人和弹幕提供三套独立的碰撞体，玩家通过切换 `collision_mask` 来选择与哪一套交互，从而实现"频率切片"的核心解谜体验
