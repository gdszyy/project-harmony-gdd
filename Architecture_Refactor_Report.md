# Architecture Refactor Report — Project Harmony

**任务 ID:** tsk-7dbd9d41-db9
**角色:** architecture_refactor_engineer
**日期:** 2026年3月1日
**状态:** 已完成

---

## 1. 任务概述

本次任务对 Project Harmony 项目进行了全面的技术债务清理和架构解耦优化，涵盖以下五个核心工作领域：

1. 扫描并移除未使用的废弃信号
2. 检查并修复 `project.godot` 中的 Autoload 配置
3. 审查并清理 `scripts/archive/` 目录下的废弃脚本
4. 分析 GameManager 引用并实施 EventBus 解耦迁移（Phase 1）
5. 对照设计文档与代码实现，修复不一致之处

---

## 2. 废弃信号清理

### 2.1. 清理结果

通过全项目 `grep` 扫描，定位并移除了以下废弃信号：

| 文件 | 移除的信号 | 类型 |
| :--- | :--- | :--- |
| `scripts/systems/object_pool.gd` | `pool_expanded` | 声明 + emit（标记为 DEPRECATED） |
| `scripts/systems/object_pool.gd` | `pool_exhausted` | 声明 + emit（标记为 DEPRECATED） |
| `scripts/systems/pool_manager.gd` | `pool_expanded_warning` | 声明 + emit（标记为 DEPRECATED） |
| `scripts/systems/pool_manager.gd` | `pool_stats_updated` | 声明 + emit（无消费者） |
| 其他多个文件 | 多个 DEPRECATED 信号 | 通过自动化脚本批量清理 |

### 2.2. 关于 `upgrade_cancelled`

经全项目搜索确认，`upgrade_cancelled` 信号在代码中**从未被定义或使用**。该信号仅存在于设计文档 `Docs/UI_Design_Module4_CircleOfFifths.md` 中。实际实现中，升级取消逻辑由 `GameManager.resume_game()` 处理，`circle_of_fifths_upgrade_v3.gd` 使用的是 `upgrade_skipped` 信号。已更新文档以反映此差异。

---

## 3. Autoload 配置修复

### 3.1. 修复内容

| 修复项 | 修改前 | 修改后 | 原因 |
| :--- | :--- | :--- | :--- |
| `UIColors` 加载顺序 | 排在第3位 | 移至第1位 | 被其他 Autoload 引用，需最先加载 |
| `SignalBridge` 加载顺序 | 排在中间 | 移至最后 | 依赖所有其他系统，需最后加载 |
| 新增 `EventBus` | 不存在 | 在 `UIColors` 之后、`GameManager` 之前注册 | Phase 1 重构需要 |
| 添加分组注释 | 无注释 | 按功能分组添加注释 | 提升可维护性 |

### 3.2. 最终 Autoload 加载顺序

```ini
[autoload]
; === 基础工具类（无依赖） ===
UIColors="*res://scripts/autoload/ui_colors.gd"
InputSetup="*res://scripts/autoload/input_setup.gd"
; === 事件总线（必须在其他系统之前注册） ===
EventBus="*res://scripts/autoload/event_bus.gd"
; === 核心系统 ===
GameManager="*res://scripts/autoload/game_manager.gd"
...（其他系统）
; === 信号桥接器（最后加载，依赖所有系统） ===
SignalBridge="*res://scripts/autoload/signal_bridge.gd"
```

---

## 4. Archive 清理

### 4.1. 发现的问题

- `godot_project/shaders/archive/` 目录中的着色器文件无代码引用，但缺少 `.gdignore` 文件，可能导致 Godot 编辑器不必要地导入这些文件。
- `boss_spawner.gd` 中仍然硬编码引用了已归档的 `boss_dissonant_conductor.gd` 脚本路径。

### 4.2. 修复措施

| 修复项 | 操作 |
| :--- | :--- |
| `shaders/archive/.gdignore` | 新增文件，防止 Godot 导入归档着色器 |
| `boss_spawner.gd` BOSS_SCENES | 注释掉 `conductor` 条目，添加归档说明 |
| `boss_spawner.gd` 代码生成逻辑 | 重构为通用的 `_spawn_boss_from_code_fallback()` 方法，支持按 boss_key 动态加载脚本，不再硬编码 conductor 路径 |

---

## 5. EventBus 解耦迁移（Phase 1 实施）

### 5.1. GameManager 依赖分析

对 GameManager 的 465 次引用进行了分类分析：

| 使用类型 | 引用次数 | 涉及文件数 |
| :--- | :---: | :---: |
| 信号连接 (`.connect`) | 82 | 18 |
| 属性读取 (`.game_time`, `.current_bpm` 等) | 171 | 35 |
| 方法调用 (`.reset_game()`, `.damage_player()` 等) | 36 | 12 |
| `has_method` / `has_signal` 检查 | 46 | 15 |
| 信号发射 (`.emit`) | 10 | 5 |

**高耦合文件 Top 5:**

| 文件 | 引用次数 | 耦合类型 |
| :--- | :---: | :--- |
| `scenes/main_game.gd` | 61 | 属性读写 + 方法调用 + 信号连接 |
| `scenes/test_chamber.gd` | 36 | 属性读写 + 方法调用 + 信号连接 |
| `ui/hud.gd` | 31 | 信号连接（11个） + 属性读取 |
| `autoload/signal_bridge.gd` | 25 | 信号桥接 |
| `autoload/spellcraft_system.gd` | 21 | 属性读取 + 信号连接 + 方法调用 |

### 5.2. Phase 1 实施：解耦重置与启动逻辑

**新增文件:**

| 文件 | 说明 |
| :--- | :--- |
| `scripts/autoload/event_bus.gd` | 全局事件总线 Autoload，支持动态信号注册的 publish/subscribe 模式 |
| `scripts/autoload/events.gd` | 事件名称常量定义（`class_name Events`），覆盖游戏生命周期、玩家状态、节拍系统、战斗、法术、章节、Boss、音频共 8 大类 30+ 事件 |

**修改文件（6个子系统迁移到 EventBus 订阅模式）:**

| 文件 | 修改内容 |
| :--- | :--- |
| `game_manager.gd` | `reset_game()` 中的 6 个直接调用替换为 `EventBus.publish(Events.GAME_RESET)`；`start_game()` 中的 3 个直接调用替换为 `EventBus.publish(Events.GAME_STARTED, {...})` |
| `fatigue_manager.gd` | 在 `_ready()` 中订阅 `GAME_RESET` 和 `GAME_STARTED` 事件 |
| `spellcraft_system.gd` | 在 `_ready()` 中订阅 `GAME_RESET` 事件 |
| `note_inventory.gd` | 在 `_ready()` 中订阅 `GAME_RESET` 事件 |
| `mode_system.gd` | 在 `_ready()` 中订阅 `GAME_STARTED`（含 mode 信息）和 `GAME_RESET` 事件 |
| `bgm_manager.gd` | 在 `_connect_signals()` 中订阅 `GAME_STARTED`（含 bpm 信息）和 `GAME_RESET` 事件 |
| `music_theory_engine.gd` | 新增 `_ready()` 方法，订阅 `GAME_RESET` 事件 |

**Phase 1 消除的直接依赖:**

```
GameManager.reset_game() 中移除:
  ✅ NoteInventory.reset()
  ✅ FatigueManager.reset()
  ✅ SpellcraftSystem.reset()
  ✅ MusicTheoryEngine.clear_history()
  ✅ ModeSystem.reset()
  ✅ BGMManager._reset_harmony_conductor()

GameManager.start_game() 中移除:
  ✅ ModeSystem.apply_mode(...)
  ✅ BGMManager.start_bgm(...)
  ✅ FatigueManager.reset()
```

### 5.3. 后续迁移计划（Phase 2-4）

参考 `tasks/tsk-c61b04fa-930/deliverables/EventBus_Architecture_Design.md` 中的完整迁移计划：

| 阶段 | 目标 | 风险等级 | 预期收益 |
| :--- | :--- | :---: | :--- |
| **Phase 2** | 迁移 `SaveManager` 和 `MetaProgressionManager` 的 `game_over` 逻辑 | 中 | 解耦游戏结算逻辑 |
| **Phase 3** | 解耦 `SpellcraftSystem` 对 `GameManager` 的反向依赖（提取 `GameState.gd`） | 中高 | 减少属性读取耦合 |
| **Phase 4** | 全面推广与规范化 | 低 | 建立团队规范，防止耦合回升 |

---

## 6. 文档与代码一致性修复

### 6.1. 已修复的不一致

| 问题 | 修复措施 |
| :--- | :--- |
| `waveform.gdshader` 文件缺失（Module 1 设计文档要求） | 创建 `godot_project/shaders/waveform.gdshader`，实现谐振波形背景动效 |
| Module 4 文档中 `upgrade_cancelled` 信号与代码不一致 | 更新文档，标注为已废弃，说明实际使用 `upgrade_skipped` |

### 6.2. 已确认一致的部分

以下文档在之前的任务中已完成修复（参考 `Docs/Fix_Analysis_DOC.md`）：

- Module 1: `SceneManager.gd` → `UITransitionManager.gd`（已修复）
- Module 2: `sequencer_ring.gd` → `sequencer_ui.gd`（已修复）
- Module 6: `phase_energy_ring.gd` → `phase_energy_bar.gd`（已修复）
- Module 7: `tooltip_controller.gd` → `tooltip_system.gd`（已修复）

### 6.3. 仍存在的双向依赖（待 Phase 2-3 解决）

| 依赖关系 | 当前状态 | 计划解决阶段 |
| :--- | :--- | :--- |
| `FatigueManager` → `GameManager.apply_dissonance_damage()` | 仍为直接调用 | Phase 2（通过 `Events.DISSONANCE_APPLIED` 事件） |
| `SpellcraftSystem` → `GameManager.game_time` / `.current_state` | 仍为直接属性读取 | Phase 3（提取 `GameState.gd`） |
| `main_game.gd` → `GameManager`（61次引用） | 场景脚本，属于合理耦合 | 长期优化 |

---

## 7. 变更文件清单

### 新增文件

| 文件路径 | 说明 |
| :--- | :--- |
| `godot_project/scripts/autoload/event_bus.gd` | 全局事件总线 Autoload |
| `godot_project/scripts/autoload/events.gd` | 事件名称常量定义 |
| `godot_project/shaders/waveform.gdshader` | 主菜单背景谐振波形着色器 |
| `godot_project/shaders/archive/.gdignore` | 防止 Godot 导入归档着色器 |

### 修改文件

| 文件路径 | 修改类型 |
| :--- | :--- |
| `godot_project/project.godot` | Autoload 顺序修复 + 新增 EventBus 注册 |
| `godot_project/scripts/autoload/game_manager.gd` | Phase 1 重构：reset_game/start_game 解耦 |
| `godot_project/scripts/autoload/fatigue_manager.gd` | 添加 EventBus 订阅 + 废弃信号清理 |
| `godot_project/scripts/autoload/spellcraft_system.gd` | 添加 EventBus 订阅 |
| `godot_project/scripts/autoload/note_inventory.gd` | 添加 EventBus 订阅 |
| `godot_project/scripts/autoload/mode_system.gd` | 添加 EventBus 订阅 |
| `godot_project/scripts/autoload/bgm_manager.gd` | 添加 EventBus 订阅 + 回调方法 |
| `godot_project/scripts/autoload/music_theory_engine.gd` | 新增 _ready() + EventBus 订阅 |
| `godot_project/scripts/systems/object_pool.gd` | 移除废弃信号 |
| `godot_project/scripts/systems/pool_manager.gd` | 移除废弃信号 |
| `godot_project/scripts/systems/boss_spawner.gd` | 修复归档 boss 引用 + 重构代码生成逻辑 |
| `Docs/UI_Design_Module4_CircleOfFifths.md` | 修复 upgrade_cancelled 信号说明 |

---

## 8. 验收标准

- [x] `pool_expanded_warning` 和 `upgrade_cancelled` 信号已处理（前者已清理，后者确认从未在代码中存在）
- [x] `project.godot` Autoload 配置已修复（加载顺序优化 + EventBus 注册）
- [x] `scripts/archive/` 和 `shaders/archive/` 已审查清理
- [x] GameManager 解耦 Phase 1 已实施（9个直接调用替换为 EventBus 事件）
- [x] 文档与代码不一致之处已修复（waveform.gdshader 创建 + upgrade_cancelled 文档更新）
- [x] 完整的迁移计划已制定（Phase 2-4 路线图）
