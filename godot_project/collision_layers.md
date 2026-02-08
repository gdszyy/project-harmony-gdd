# Project Harmony — 碰撞层配置

> 本文件定义 Godot 项目中的碰撞层分配方案。
> 请在 Project Settings → Physics → 2D Physics → Layer Names 中配置。

## 碰撞层分配

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

## 碰撞矩阵

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

## 说明

- **Player** 可以与世界碰撞、被敌人接触、被敌人弹体击中、拾取物品、进入触发区域
- **Enemy** 可以与世界碰撞、接触玩家、被玩家弹体和护盾击中
- **Player Projectile** 与世界和敌人碰撞
- **Enemy Projectile** 与世界、玩家和护盾碰撞（护盾可以阻挡敌人弹体）
- **Shield** 仅与敌人弹体碰撞（保护玩家）
- **Pickup** 仅与玩家碰撞（自动拾取）
