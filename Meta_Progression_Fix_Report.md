# 局外升级系统修复报告

## 修复概述

本次修复解决了局外升级系统（Meta Progression System）的三大核心问题，使"和谐殿堂"中购买的升级能够在游戏中真正生效。

## 修复前的问题

### 问题 1：双轨数据源

`SaveManager` 和 `MetaProgressionManager` 各自维护了一套独立的局外升级数据：

| 维度 | SaveManager | MetaProgressionManager |
|------|-------------|----------------------|
| 存档路径 | `save_game.cfg` | `meta_progression.cfg` |
| 升级 ID | 自定义 ID 体系 | 独立 ID 体系 |
| 数据定义 | 内置硬编码 | 内置硬编码 |
| 购买接口 | `upgrade_instrument()` 等 | `purchase_instrument_upgrade()` 等 |

**后果**：UI 购买写入 MetaProgressionManager，游戏开始时从 SaveManager 读取 → 购买的升级不生效。

### 问题 2：UI 第三套数据

`hall_of_harmony.gd` 使用了完全不同的升级定义（ID、名称、数值、最大等级全部不同），与后端两套数据均不兼容。

### 问题 3：末端未接入

三项加成虽然有接口但游戏实体未读取：
- **拾音范围**：`player.gd` 未读取 `meta_pickup_range_bonus`
- **节拍判定窗口**：`rhythm_indicator.gd` 未读取 `meta_perfect_window_bonus_ms`
- **休止符美学**：`fatigue_manager.gd` 的 `_apply_rest_cleanse()` 未读取 `meta_rest_efficiency_bonus`

### 问题 4：碎片双重发放

`GameManager.game_over()` 和 `RunResultsScreen.show_results()` 都会触发碎片奖励计算，导致每局结束碎片被发放两次。

---

## 修复内容

### 1. 统一数据源（save_manager.gd 重构）

**策略**：以 `MetaProgressionManager` 为唯一权威数据源，`SaveManager` 改为纯委托层。

**修改文件**：`scripts/autoload/save_manager.gd`

- 移除所有局外升级数据定义（`INSTRUMENT_UPGRADES`、`THEORY_UNLOCKS` 等硬编码常量）
- 移除独立的局外升级存档读写逻辑
- 所有局外升级查询/购买/应用接口改为委托给 `MetaProgressionManager`
- 保留局内进度存档（击杀数、最佳时间、最高等级等）和设置存档功能
- 新增便捷接口：`get_damage_multiplier()`、`get_speed_multiplier()`、`get_pickup_range_bonus()`、`get_timing_window_bonus()`、`get_rest_efficiency_bonus()`、`get_dissonance_resist_multiplier()`

**数据流（修复后）**：
```
hall_of_harmony.gd → MetaProgressionManager.purchase_*() → meta_progression.cfg
GameManager.start_game() → SaveManager.apply_meta_bonuses() → MetaProgressionManager.apply_meta_bonuses()
SpellcraftSystem → SaveManager.get_damage_multiplier() → MetaProgressionManager.get_instrument_bonus()
```

### 2. UI 数据对齐（hall_of_harmony.gd 重写）

**策略**：消除所有硬编码数据定义，从 `MetaProgressionManager` 的常量动态读取。

**修改文件**：`scripts/ui/hall_of_harmony.gd`

- 移除 `TUNING_UPGRADES`、`THEORY_SKILLS`、`MODE_STYLES`、`DENOISE_UPGRADES` 四套硬编码数据
- 四个面板改为遍历 `_meta.INSTRUMENT_UPGRADES`、`_meta.THEORY_UNLOCKS`、`_meta.MODE_CONFIGS`、`_meta.ACOUSTIC_UPGRADES`
- 购买回调直接调用 `_meta.purchase_instrument_upgrade()`、`_meta.purchase_theory_unlock()` 等
- 等级、花费、解锁状态全部从 MetaProgressionManager 实时查询

### 3. 末端加成接入

#### 3a. 拾音范围（player.gd）

**修改文件**：`scripts/entities/player.gd`

- 在 `_ready()` 中调用 `_apply_meta_pickup_range()`
- 新增方法：从 `SaveManager.get_pickup_range_bonus()` 获取加成值，扩大 `PickupArea` 的 `CollisionShape2D` 半径

#### 3b. 节拍判定窗口（rhythm_indicator.gd）

**修改文件**：`scripts/ui/rhythm_indicator.gd`

- 在 `_ready()` 中调用 `_apply_meta_timing_bonus()`
- 新增方法：从 `SaveManager.get_timing_window_bonus()` 获取毫秒加成，转换为比例并叠加到 `perfect_window` 和 `good_window`

#### 3c. 休止符美学（fatigue_manager.gd）

**修改文件**：`scripts/autoload/fatigue_manager.gd`

- 修改 `_apply_rest_cleanse()` 方法
- 从 `GameManager.get_meta("meta_rest_efficiency_bonus")` 读取加成
- 将加成应用为效率倍率：寂静时间减少量和疲劳度减少量均乘以 `(1.0 + bonus)`

#### 3d. 声学降噪直接应用（meta_progression_manager.gd）

**修改文件**：`scripts/autoload/meta_progression_manager.gd`

- `_apply_acoustic_bonuses()` 中的单调值减少和密度恢复改为直接调用 `FatigueManager.apply_resistance_upgrade()`
- 不再仅写入 `GameManager.set_meta()` 而不被消费

### 4. 碎片经济统一

**修改文件**：`scripts/autoload/game_manager.gd`

- `game_over()` 中移除 `_award_resonance_fragments()` 调用
- 碎片奖励统一由 `RunResultsScreen.show_results()` → `MetaProgressionManager.on_run_completed()` 计算并发放
- 保留 `_award_resonance_fragments()` 方法作为回退方案（当 MetaProgressionManager 不可用时）

---

## 修改文件清单

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `scripts/autoload/save_manager.gd` | **重写** | 移除局外数据，改为委托层 |
| `scripts/ui/hall_of_harmony.gd` | **重写** | 消除硬编码，动态读取 MetaProgressionManager |
| `scripts/autoload/meta_progression_manager.gd` | 修改 | 声学降噪直接应用到 FatigueManager |
| `scripts/autoload/game_manager.gd` | 修改 | 移除双重碎片发放 |
| `scripts/entities/player.gd` | 修改 | 接入拾取范围加成 |
| `scripts/ui/rhythm_indicator.gd` | 修改 | 接入节拍判定窗口加成 |
| `scripts/autoload/fatigue_manager.gd` | 修改 | 接入休止符效率加成 |

---

## 验证要点

1. **购买生效**：在和谐殿堂购买"舞台定力"后，下一局游戏 HP 应增加
2. **碎片不重复**：每局结束只发放一次碎片
3. **拾取范围**：购买"拾音范围"后，经验球吸附距离应增大
4. **节拍窗口**：购买"节拍敏锐度"后，Perfect 判定应更宽松
5. **休止符效率**：购买"休止符美学"后，休止符清除负面状态更快
6. **数据持久化**：所有局外升级数据存储在 `meta_progression.cfg`，重启游戏后保留
