# Project Harmony — Bug 修复报告

**修复日期：** 2026年2月8日  
**修复人员：** Manus AI Agent  
**涉及提交：** 2 个 commits (7f57ca9, cfa23a7)

---

## 修复概述

本次修复分为两轮，共解决 **20 个问题**（11 个来自第一轮，9 个来自第二轮），涵盖 UI 页面、游戏功能完整性、核心模块交叉引用、信号连接、经验值系统等关键领域。所有修复已推送至 GitHub 主分支。

---

## 第一轮修复（基于错误日志）

### 问题来源

用户提供的 Godot 错误日志显示两个直接报告的问题：

1. `hud.gd:19` — Node not found: "ManualSlots"
2. `test_chamber.gd:95` — Invalid assignment of property 'is_test_mode'

### 修复清单

| 问题编号 | 严重程度 | 问题描述 | 修复方案 | 影响文件 |
|---------|---------|---------|---------|---------|
| 1 | 严重 | HUD 节点找不到 "ManualSlots" | 在 `main_game.tscn` 和 `test_chamber.tscn` 的 HUD 下添加 ManualSlots (HBoxContainer) 节点 | `scenes/main_game.tscn`, `scenes/test_chamber.tscn` |
| 2 | 严重 | GameManager 缺少 `is_test_mode` 属性 | 在 `game_manager.gd` 中添加 `is_test_mode: bool` 和 `damage_multiplier: float` 属性声明 | `scripts/autoload/game_manager.gd` |
| 3 | 中等 | test_chamber.gd 引用不存在的属性 | 修复 `GameManager.fatigue`、`GameManager.bpm`、`GameManager.damage_multiplier` 的引用方式 | `scripts/scenes/test_chamber.gd` |
| 4 | 中等 | test_chamber.gd 调用不存在的方法 | 将 `ModeSystem.select_mode` 改为 `ModeSystem.apply_mode` | `scripts/scenes/test_chamber.gd` |
| 5 | 中等 | main_game.gd 暂停动作名称不匹配 | 将 `"pause"` 改为 `"pause_game"` (与 project.godot 一致) | `scripts/scenes/main_game.gd` |
| 6 | 轻微 | main_game.tscn 格式缩进问题 | 修复 FatigueFilter 和 PauseMenu 节点的 tscn 格式缩进 | `scenes/main_game.tscn` |
| 7 | 轻微 | pause_menu.tscn 的 load_steps 错误 | 修正 `load_steps=2` → `load_steps=3` (有3个外部资源) | `scenes/pause_menu.tscn` |
| 8 | 中等 | hud.gd 中 silenced_notes 数据结构使用错误 | 修复 `_update_silence_indicators` 和 `_update_fatigue_filter` 中对 silenced_notes 的使用 (返回的是字典数组，不是 int 数组) | `scripts/ui/hud.gd` |
| 9 | 中等 | test_chamber.gd 中 god_mode 实现错误 | 通过 GameManager 设置 HP，而不是直接调用 player.set_hp | `scripts/scenes/test_chamber.gd` |
| 10 | 中等 | test_chamber.gd 中 set_player_stat 的 max_hp 处理错误 | 通过 GameManager 设置 max_hp | `scripts/scenes/test_chamber.gd` |
| 11 | 严重 | test_chamber 启动时游戏状态未设置 | 在 `_ready()` 中调用 `GameManager.start_game()` 确保游戏状态为 PLAYING | `scripts/scenes/test_chamber.gd` |

### 修复结果

- **修改文件数：** 7 个
- **新增代码行：** 约 50 行
- **删除/修改代码行：** 约 30 行

---

## 第二轮修复（核心模块深度审查）

### 审查范围

对项目所有核心模块进行了全面交叉验证：

- **Autoload 系统：** 11 个 (GameManager, FatigueManager, SpellcraftSystem, ModeSystem 等)
- **实体脚本：** 20+ 个 (player.gd, enemy_base.gd, boss_base.gd, xp_pickup.gd 等)
- **系统脚本：** 5 个 (enemy_spawner.gd, projectile_manager.gd 等)
- **UI 脚本：** 10 个 (hud.gd, sequencer_ui.gd, fatigue_meter.gd 等)
- **场景文件：** 8 个 (.tscn 文件的节点结构、信号连接、资源引用)

### 修复清单

| 问题编号 | 严重程度 | 问题描述 | 修复方案 | 影响文件 |
|---------|---------|---------|---------|---------|
| 1 | 严重 | 暂停功能失效 | 删除 `player.gd` 中重复的暂停处理 (与 `main_game.gd` 冲突) | `scripts/entities/player.gd` |
| 2 | 严重 | InvincibilityTimer timeout 信号未连接 | 在 `_ready()` 中添加显式信号连接 | `scripts/entities/player.gd` |
| 3 | 严重 | PickupArea 信号类型错误 | 将 `body_entered` 改为 `area_entered` (xp_pickup 是 Area2D) | `scripts/entities/player.gd` |
| 4 | 中等 | xp_value 属性读取方式不兼容 | 同时兼容属性和 meta 两种方式 | `scripts/entities/player.gd` |
| 5 | 中等 | FatigueManager 缺少 `get_current_fatigue()` 方法 | 添加该方法 | `scripts/autoload/fatigue_manager.gd` |
| 6 | 中等 | enemy_base.gd 缺少 `set_frozen()` 方法 | 添加基于 `_is_stunned` 状态的冻结实现 | `scripts/entities/enemy_base.gd` |
| 7 | 严重 | xp_pickup._collect() 未调用 GameManager.add_xp | 在 `_collect()` 中直接调用 `GameManager.add_xp(xp_value)` | `scripts/entities/xp_pickup.gd` |
| 8 | 严重 | enemy_spawner 经验值重复计算 | 删除 `_on_enemy_died` 和 `_start_pickup_attraction` 中重复的 `add_xp` 调用 | `scripts/systems/enemy_spawner.gd` |
| 9 | 中等 | enemy_spawner 简易 pickup 缺少 xp_value 属性 | 添加 `set("xp_value", value)` 确保兼容 | `scripts/systems/enemy_spawner.gd` |

### 修复结果

- **修改文件数：** 5 个
- **新增代码行：** 约 40 行
- **删除/修改代码行：** 约 20 行

---

## 验证通过的模块

以下模块经审查确认无问题：

- **信号签名匹配：** GameManager, SpellcraftSystem, FatigueManager 的所有信号参数与监听器匹配
- **方法存在性：** AudioManager, GlobalMusicManager, BGMManager, SaveManager 的所有被调用方法均存在
- **场景切换路径：** 所有 `change_scene_to_file` 引用的 .tscn 路径均存在
- **Input Action 名称：** 所有脚本引用的动作名称均在 project.godot 或 input_setup.gd 中定义
- **数据类引用：** MusicData, ChapterData, CodexData 的常量和枚举引用均正确

---

## 关键问题分析

### 1. 暂停功能失效（严重）

**根本原因：** `player.gd` 的 `_unhandled_input` 和 `main_game.gd` 的 `_input` 都处理了 `pause_game` 动作。由于 `_input` 先于 `_unhandled_input` 执行，两者会在同一帧内先暂停再恢复（或反之），导致暂停功能完全失效。

**影响范围：** 所有游戏场景的暂停/恢复功能

**修复方案：** 删除 `player.gd` 中的暂停处理，统一由 `main_game.gd` 处理

### 2. 经验值系统混乱（严重）

**根本原因：** 经验值添加逻辑分散在三个地方：
1. `enemy_spawner._on_enemy_died` 直接调用 `add_xp`
2. `enemy_spawner._start_pickup_attraction` 收集时再次调用 `add_xp`
3. `xp_pickup._collect` 磁吸收集时发出信号但无人连接

导致经验值双倍计算或完全丢失。

**影响范围：** 所有敌人死亡后的经验值获取

**修复方案：** 
- 删除 enemy_spawner 中所有 `add_xp` 调用
- 在 `xp_pickup._collect()` 中统一调用 `add_xp`
- player 的 `area_entered` 作为备用拾取机制

### 3. 信号连接缺失（严重）

**根本原因：** 场景中预置的 Timer 和 Area2D 节点没有在代码中连接信号，导致回调函数永远不会被调用。

**影响范围：** 
- 玩家无敌帧永不解除
- 经验值无法拾取

**修复方案：** 在 `_ready()` 中显式连接所有必要信号

---

## 测试建议

修复后建议进行以下测试：

1. **暂停功能测试：** 在游戏中按 ESC 或 P 键，确认暂停菜单正常弹出且游戏暂停
2. **经验值测试：** 击杀敌人后观察经验值增长，确认数值正常且不重复
3. **无敌帧测试：** 玩家受击后短时间内无法再次受伤，0.5秒后恢复正常
4. **拾取测试：** 靠近经验值球，确认自动吸引和拾取功能正常
5. **测试场景测试：** 启动 test_chamber.tscn，确认所有调试功能正常（生成敌人、god mode、设置属性等）

---

## 附录：修复文件清单

### 第一轮修复文件

1. `godot_project/scripts/autoload/game_manager.gd`
2. `godot_project/scripts/scenes/test_chamber.gd`
3. `godot_project/scripts/scenes/main_game.gd`
4. `godot_project/scripts/ui/hud.gd`
5. `godot_project/scenes/main_game.tscn`
6. `godot_project/scenes/test_chamber.tscn`
7. `godot_project/scenes/pause_menu.tscn`

### 第二轮修复文件

1. `godot_project/scripts/entities/player.gd`
2. `godot_project/scripts/autoload/fatigue_manager.gd`
3. `godot_project/scripts/entities/enemy_base.gd`
4. `godot_project/scripts/entities/xp_pickup.gd`
5. `godot_project/scripts/systems/enemy_spawner.gd`

---

**报告结束**
