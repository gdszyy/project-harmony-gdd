# Project Harmony — Max 难度 Issue 实现报告

**分支**: `feat/max-difficulty-issues`
**PR**: [#33](https://github.com/gdszyy/project-harmony-gdd/pull/33)
**日期**: 2026-02-08

---

## 总览

本次实现完成了项目中全部 4 个 **Max 难度** Issue，共新增 **15 个文件**，约 **4900+ 行 GDScript 代码**。所有实现均遵循项目现有架构风格，并与 GDD 设计文档保持一致。

| Issue | 标题 | 新增文件 | 代码行数 | 状态 |
|:---:|:---|:---:|:---:|:---:|
| #6 | 弹体碰撞系统优化 | 2 (+1修改) | ~480 | Closes #6 |
| #25 | 对象池系统与性能优化 | 3 | ~790 | Closes #25 |
| #27 | Boss 敌人设计与实现 | 4 | ~1970 | Closes #27 |
| #31 | 局外成长系统实现 | 3 (+2修改) | ~1690 | Closes #31 |

---

## Issue #6: 弹体碰撞系统优化

### 问题
原有碰撞检测使用 O(n×m) 暴力遍历（每个弹体 × 每个敌人），在大量弹体/敌人场景下性能瓶颈严重。

### 解决方案：空间哈希网格 (Spatial Hash Grid)

**文件清单**：

| 文件 | 说明 |
|:---|:---|
| `scripts/systems/spatial_hash.gd` | 空间哈希网格核心实现 |
| `scripts/systems/collision_optimizer.gd` | 碰撞优化器（集成层） |
| `scripts/systems/projectile_manager.gd` | 修改：集成 CollisionOptimizer |

**核心设计**：
- **SpatialHash**: 将 2D 空间划分为固定大小的网格单元（默认 128px），每个实体根据位置映射到对应单元格。查询时只检查目标位置周围的相邻单元格，将碰撞检测复杂度从 O(n×m) 降低到接近 O(n)。
- **CollisionOptimizer**: 封装空间哈希的构建和查询流程，提供 `find_collisions()` 接口返回碰撞对列表，内置性能统计（检测次数、碰撞数、耗时）。
- **双模式支持**: ProjectileManager 通过 `use_collision_optimizer` 标志切换优化/回退模式，确保兼容性。

---

## Issue #25: 对象池系统与性能优化

### 问题
频繁的 `instantiate()` / `queue_free()` 调用导致 GC 压力和帧率波动，尤其在密集战斗中。

### 解决方案：通用对象池 + 全局池管理器

**文件清单**：

| 文件 | 说明 |
|:---|:---|
| `scripts/systems/object_pool.gd` | 通用对象池 |
| `scripts/systems/pool_manager.gd` | 全局池管理器 (Autoload) |
| `scripts/ui/performance_monitor.gd` | 性能监控 HUD |

**核心设计**：
- **ObjectPool**: 泛型对象池，支持 PackedScene 和脚本两种创建模式。功能包括：预热 (warm-up)、自动扩容、最大容量限制、使用统计追踪、`acquire()` / `release()` 接口。对象通过 `reset()` 方法实现状态重置复用。
- **PoolManager**: 全局单例，预注册 6 种对象池（普通敌人、精英敌人、Boss、经验值拾取物、伤害数字、死亡特效），提供统一的 `acquire_from_pool()` / `release_to_pool()` 接口。
- **PerformanceMonitor**: 开发用性能面板（F3 切换），实时显示 FPS、内存使用、各池状态、碰撞优化统计。

---

## Issue #27: Boss 敌人设计与实现

### 问题
游戏缺少 Boss 战体验，需要设计与音乐系统深度结合的多阶段 Boss。

### 解决方案：多阶段 Boss AI 框架 + "失谐指挥家" Boss

**文件清单**：

| 文件 | 说明 |
|:---|:---|
| `scripts/entities/enemies/boss_base.gd` | Boss 基类 |
| `scripts/entities/enemies/boss_dissonant_conductor.gd` | "失谐指挥家" Boss |
| `scripts/systems/boss_spawner.gd` | Boss 生成管理器 |
| `scripts/ui/boss_health_bar.gd` | Boss 血条 UI |

**Boss 基类 (BossBase)** — 约 600 行：
- **多阶段状态机**: 支持任意数量阶段，每个阶段有独立的 HP 阈值、攻击模式列表、BGM 变体
- **攻击模式管理器**: 加权随机选择、冷却时间、阶段限定、连击系统
- **护盾系统**: 可生成护盾 HP，护盾存在时减免伤害
- **脆弱状态**: 护盾破碎后进入脆弱窗口期，受到额外伤害
- **狂暴模式**: HP 低于阈值时攻速和伤害提升
- **音乐联动**: 阶段切换时通知 BGMManager 切换音轨

**"失谐指挥家" (Dissonant Conductor)** — 约 750 行：
- **第一乐章 "不和谐序曲"**: 指挥棒挥击、不和谐波、召唤小兵
- **第二乐章 "混乱赋格"**: 音符弹幕、赋格追踪、节奏干扰、护盾生成
- **第三乐章 "终章狂想"**: 全屏共鸣、指挥风暴、绝望和弦、终曲
- 每种攻击模式都有独立的弹幕模式、视觉效果和伤害逻辑

**Boss 生成管理器 (BossSpawner)**：
- 每 5 波触发 Boss 战
- Boss 战期间暂停普通敌人生成
- 入场动画（缩放 + 淡入）
- 击败后发放共鸣碎片奖励

**Boss 血条 UI (BossHealthBar)**：
- 屏幕顶部固定显示
- HP 条带延迟伤害动画（红色残影）
- 护盾条叠加显示
- 阶段指示器（当前阶段闪烁）
- 脆弱状态标记
- 入场/退场过渡动画

---

## Issue #31: 局外成长系统实现

### 问题
游戏缺少局外永久成长系统，每局游戏之间没有持续的进度感。

### 解决方案："和谐殿堂" 四大模块 + 共鸣碎片货币

**文件清单**：

| 文件 | 说明 |
|:---|:---|
| `scripts/autoload/meta_progression_manager.gd` | 局外成长管理器 (Autoload) |
| `scripts/ui/hall_of_harmony.gd` | "和谐殿堂" UI |
| `scripts/ui/run_results_screen.gd` | 局结算界面 |
| `scripts/autoload/game_manager.gd` | 修改：集成局外加成 |
| `scripts/autoload/save_manager.gd` | 修改：存档联动 |

### 模块 A: 乐器调优 (Instrument Tuning)

基础属性永久升级，每项可升级多级：

| 升级项 | 效果 | 最大等级 |
|:---|:---|:---:|
| 舞台定力 (Stage Presence) | +10 HP / 级 | 10 |
| 基础声压 (Acoustic Pressure) | +2% 伤害 / 级 | 10 |
| 节拍敏锐度 (Rhythmic Sense) | +15ms 判定窗口 / 级 | 5 |
| 拾音范围 (Pickup Range) | +20px 拾取范围 / 级 | 8 |
| 起拍速度 (Upbeat Velocity) | +3% 投射物速度 / 级 | 8 |

### 模块 B: 乐理研习 (Theory Archives)

解锁型升级，含前置条件树：

| 解锁项 | 效果 | 花费 | 前置 |
|:---|:---|:---:|:---|
| D# 追踪修饰符 | 加入奖励池 | 40 | 无 |
| G# 回响修饰符 | 加入奖励池 | 40 | 无 |
| A# 散射修饰符 | 加入奖励池 | 50 | G# 回响 |
| 紧张度理论 | 解锁减/增三和弦 | 60 | 无 |
| 七和弦解析 | 解锁四种七和弦 | 80 | 紧张度理论 |
| 传说乐章许可 | 提升扩展和弦概率 | 120 | 七和弦解析 |

### 模块 C: 调式风格 (Mode Mastery)

职业/流派选择系统：

| 调式 | 可用音符 | 被动效果 | 解锁花费 |
|:---|:---|:---|:---:|
| 伊奥尼亚 (均衡者) | CDEFGAB | 和谐度 +10% | 免费 |
| 多利亚 (民谣诗人) | C D Eb F G A Bb | 自带回响效果 | 80 |
| 五声音阶 (东方行者) | CDEGA | 基础伤害 +20% | 60 |
| 布鲁斯 (爵士乐手) | C Eb F Gb G Bb | 不和谐→暴击转化 | 100 |

### 模块 D: 声学降噪 (Acoustic Treatment)

疲劳系统缓解升级：

| 升级项 | 效果 | 最大等级 |
|:---|:---|:---:|
| 听觉耐受 | -5% 单调值累积 / 级 | 3 |
| 混响消除 | +10% 密度恢复 / 级 | 3 |
| 绝对音感 | 每跳 -1HP 腐蚀 / 级 | 3 |
| 休止符美学 | +15% 清除效率 / 级 | 3 |

### 局结算系统

每局结束后自动计算共鸣碎片奖励：
- 存活时间：每 30 秒 5 碎片
- 击杀数：每 20 击杀 3 碎片
- Boss 击败：每个 30 碎片
- 等级：每级 2 碎片
- 高和谐度（>0.8）：总量 ×1.5 加成

### 数据持久化

使用 `ConfigFile` 存储到 `user://meta_progression.cfg`，与现有 `SaveManager` 联动。

---

## 架构集成说明

### 新增 Autoload 注册

需要在 Godot 项目设置中注册以下 Autoload：

```
MetaProgressionManager → res://scripts/autoload/meta_progression_manager.gd
PoolManager → res://scripts/systems/pool_manager.gd
```

### 信号连接

- `BossSpawner.boss_fight_started` → 通知 EnemySpawner 暂停生成
- `BossSpawner.boss_fight_ended` → 通知 EnemySpawner 恢复生成
- `MetaProgressionManager.upgrade_purchased` → 刷新 UI
- `GameManager.game_state_changed(GAME_OVER)` → 触发 RunResultsScreen

### 文件依赖关系

```
GameManager ←→ MetaProgressionManager ←→ SaveManager
     ↓                    ↓
ProjectileManager    HallOfHarmony (UI)
     ↓                    
CollisionOptimizer   RunResultsScreen (UI)
     ↓
SpatialHash

EnemySpawner ←→ BossSpawner → BossBase → BossDissonantConductor
                     ↓
               BossHealthBar (UI)

PoolManager → ObjectPool
     ↓
PerformanceMonitor (UI)
```
