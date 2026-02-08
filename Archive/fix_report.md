# Project Harmony GDD — 修复报告

## 概述

本次修复针对项目中 UI 页面和游戏功能的多个关键问题进行了全面排查和修复，共涉及 **7 个文件**、**11 项修复**。所有修改已提交并推送至 GitHub 仓库。

---

## 修复详情

| 编号 | 问题描述 | 涉及文件 | 修复方式 |
|:---:|---|---|---|
| 1 | HUD 节点找不到 `ManualSlots`（错误日志第一条） | `main_game.tscn`, `test_chamber.tscn` | 在两个场景的 HUD 下添加 `ManualSlots`（HBoxContainer）节点 |
| 2 | `GameManager` 缺少 `is_test_mode` 属性（错误日志第二条） | `game_manager.gd` | 添加 `var is_test_mode: bool = false` 属性声明 |
| 3 | `GameManager` 缺少 `damage_multiplier` 属性 | `game_manager.gd` | 添加 `var damage_multiplier: float = 1.0` 属性声明 |
| 4 | `test_chamber.gd` 引用不存在的 `GameManager.fatigue` | `test_chamber.gd` | 改为通过 `FatigueManager.current_afi = 0.0` 重置疲劳度 |
| 5 | `test_chamber.gd` 引用不存在的 `GameManager.bpm` | `test_chamber.gd` | 改为 `GameManager.current_bpm` |
| 6 | `main_game.gd` 暂停动作名称与 `project.godot` 不匹配 | `main_game.gd` | 将 `"pause"` 改为 `"pause_game"` |
| 7 | `main_game.tscn` 中 FatigueFilter 和 PauseMenu 节点有 tab 缩进 | `main_game.tscn` | 移除 tscn 格式中不合规的缩进 |
| 8 | `test_chamber.gd` 调用不存在的 `ModeSystem.select_mode()` | `test_chamber.gd` | 改为 `ModeSystem.apply_mode()` |
| 9 | `hud.gd` 中 `silenced_notes` 数据结构使用错误 | `hud.gd` | 从字典数组中正确提取 note key 列表后再进行 `in` 判断 |
| 10 | `game_manager.gd` 缺少 `timbre_mastery`、`modifier_mastery`、`special` 升级类别处理 | `game_manager.gd` | 在 `apply_upgrade` 的 match 中添加缺失的类别分支和对应处理函数 |
| 11 | `pause_menu.tscn` 的 `load_steps` 值错误（2 → 3） | `pause_menu.tscn` | 修正为与实际外部资源数量一致 |

---

## 额外修复（游戏功能完整性）

除了错误日志中直接报告的两个问题外，还修复了以下游戏逻辑问题：

**test_chamber.gd 中的 God Mode 实现修复**：原代码调用 `_player.set_hp()` 和 `_player.max_hp`，但 `player.gd` 中没有这些方法/属性。改为通过 `GameManager.player_current_hp` 和 `GameManager.player_max_hp` 正确操作。

**test_chamber.gd 中的 set_player_stat("max_hp") 修复**：同上，改为通过 GameManager 设置玩家最大生命值，并正确触发 `player_hp_changed` 信号更新 UI。

**test_chamber.gd 的 _ready() 中设置游戏状态**：添加 `GameManager.current_state = GameManager.GameState.PLAYING`，确保测试场景启动后游戏逻辑（节拍系统、时间计时等）能正常运行。

**game_manager.gd 的 reset_game() 中重置新属性**：在重置方法中添加 `damage_multiplier = 1.0` 和 `is_test_mode = false`，确保从测试场景返回主菜单后状态正确清理。

---

## 修改文件清单

| 文件路径 | 修改类型 |
|---|---|
| `godot_project/scenes/main_game.tscn` | 添加 ManualSlots 节点 + 修复缩进格式 |
| `godot_project/scenes/test_chamber.tscn` | 添加 ManualSlots 节点 |
| `godot_project/scenes/pause_menu.tscn` | 修正 load_steps |
| `godot_project/scripts/autoload/game_manager.gd` | 添加属性 + 升级处理函数 + 重置逻辑 |
| `godot_project/scripts/scenes/main_game.gd` | 修复暂停动作名称 |
| `godot_project/scripts/scenes/test_chamber.gd` | 修复属性引用 + 方法调用 + 游戏逻辑 |
| `godot_project/scripts/ui/hud.gd` | 修复 silenced_notes 数据结构使用 |
